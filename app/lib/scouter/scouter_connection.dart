import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../g1/g1_connection.dart';
import '../g1/protocol.dart';
import 'sk_font.dart';
import 'sk_link.dart';
import 'sk_protocol.dart';

/// One arm running g1v0.
class _SkArm {
  _SkArm(this.side, this.device);

  final G1Side side;
  final BluetoothDevice? device;
  BluetoothCharacteristic? cmd;
  BluetoothCharacteristic? ctrl;
  StreamSubscription<List<int>>? evtSub;
  StreamSubscription<BluetoothConnectionState>? stateSub;
  late final SkLink link;
  bool ready = false;
  bool settingUp = false;
  bool probing = false;
  int mtu = 23;

  /// Epoch of the arm's session (VM.md §6.2); null before the first.
  int? epoch;

  /// The session [epoch] has this app's font in its arena.
  bool fontLoaded = false;
  SkHello? hello;

  int tag = 0;
  final Map<int, Completer<SkEvent>> replies = {};
  Future<void> writes = Future.value();

  /// Replaces the BLE writes in tests: channel 0 = CMD, 1 = CTRL.
  Future<void> Function(int channel, Uint8List data)? writeOverride;

  int? battery;
  int? inCase;
  int? worn;
  int? caseLid;
}

/// Connection to G1 glasses whose arms run ScouterKit's g1v0 firmware
/// (github.com/mafik/scouter_kit) instead of Even's.
///
/// Offers what the app uses from [G1Connection]: texts are drawn with the
/// font in [fontAsset] (uploaded into each arm's memory once per session),
/// TouchBar gestures arrive as the same events as with Even's firmware
/// (long press = Assist, triple tap = silent mode, which the app keeps
/// itself), the right arm's microphone streams LC3 like Even's.
///
/// While an arm lies in the charging case nothing is drawn on it: lit pixels
/// disturb the case's charging link (VM.md §6.6, the library's PanelPolicy).
class ScouterConnection extends G1Connection {
  ScouterConnection({Future<SkFont> Function()? font})
    : _fontLoader = font ?? loadFont;

  /// Connection with simulated arms for tests: [write] receives every write
  /// (channel 0 = CMD, 1 = CTRL), [receive] feeds events.
  @visibleForTesting
  ScouterConnection.fake(
    Future<void> Function(G1Side side, int channel, Uint8List data) write, {
    required SkFont font,
  }) : _fontLoader = (() async => font) {
    _fake = true;
    for (final side in G1Side.values) {
      final arm = _newArm(side, null)
        ..writeOverride = (channel, data) => write(side, channel, data);
      _arms[side] = arm;
    }
  }

  static const fontAsset = 'assets/scouter/departure_mono_11.skf';

  static Future<SkFont>? _font;

  /// Departure Mono, 11 px drawn ×2 (22 px, 28 px per line, 14 px per
  /// character), only the characters [SkFont.textCodepoint] needs.
  static Future<SkFont> loadFont() => _font ??= rootBundle
      .load(fontAsset)
      .then(
        (d) =>
            SkFont.parse(d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes))
                .scaled(2, keep: SkFont.textCodepoint),
      );

  final Future<SkFont> Function() _fontLoader;
  SkFont? _loadedFont;
  bool _fake = false;
  bool _disposed = false;
  final Map<G1Side, _SkArm> _arms = {};
  bool _wanted = false;
  Timer? _reconnectTimer;
  Timer? _probeTimer;
  Timer? _batteryTimer;
  Timer? _micTimer;
  bool _micOn = false;
  bool _fast = false;
  bool _silent = false;
  bool _headUp = false;
  int _headUpAngle = 30;
  bool _caseNoted = false;

  /// Top of the text block on the panel, from the display height (0–8).
  int textTop = 140;

  static const textLeft = 24;
  static const textLevel = 15;

  @override
  bool get evenFirmware => false;

  @override
  String get firmwareName => 'ScouterKit (g1v0)';

  String? _armVersion(G1Side side) => _arms[side]?.hello?.version;

  /// Firmware of the arms, e.g. "ScouterKit g1v0 0.5.60", both when the arms
  /// differ.
  @override
  String? get firmwareVersion {
    final l = _armVersion(G1Side.left), r = _armVersion(G1Side.right);
    if (l == null && r == null) return null;
    if (l == r || r == null) return 'ScouterKit g1v0 $l';
    if (l == null) return 'ScouterKit g1v0 $r';
    return 'ScouterKit g1v0 L $l, R $r';
  }

  @override
  bool get connected => _arms.length == 2 && _arms.values.every((a) => a.ready);

  @override
  String get status {
    if (connected) return 'verbunden';
    if (!_wanted && !_fake) return 'getrennt';
    final l = _arms[G1Side.left]?.ready ?? false;
    final r = _arms[G1Side.right]?.ready ?? false;
    if (l || r) return 'verbinde (${l ? 'L' : 'R'} bereit)…';
    return 'verbinde…';
  }

  void _debug(String message) => note(message);

  _SkArm _newArm(G1Side side, BluetoothDevice? device) {
    final arm = _SkArm(side, device);
    arm.link = SkLink(
      (packet) => _writeChannel(arm, 0, packet),
      log: (m) => _debug('${side.code}: $m'),
    );
    return arm;
  }

  // ---------------------------------------------------------------------------
  // Scanning
  // ---------------------------------------------------------------------------

  /// Scans for arms advertising as `G1v0_L` / `G1v0_R`, grouped by the pair
  /// ID of their scan response.
  static Stream<List<G1Pair>> scan({
    Duration timeout = const Duration(seconds: 15),
  }) {
    final pairs = <String, G1Pair>{};
    final controller = StreamController<List<G1Pair>>();
    late StreamSubscription<List<ScanResult>> sub;

    controller.onListen = () async {
      sub = FlutterBluePlus.onScanResults.listen((results) {
        var changed = false;
        for (final r in results) {
          final name = r.advertisementData.advName.isNotEmpty
              ? r.advertisementData.advName
              : r.device.platformName;
          final ad = SkAdvert.parse(name, r.advertisementData.manufacturerData);
          if (ad == null) continue;
          final key = ad.pairId.isEmpty ? '?' : ad.pairId;
          final pair = pairs.putIfAbsent(
            key,
            () => G1Pair(key, firmware: G1Firmware.scouterKit),
          );
          final id = r.device.remoteId.str;
          final label = ad.safeMode ? '$name (sicherer Modus)' : name;
          if (ad.left && pair.leftId != id) {
            pair
              ..leftId = id
              ..leftName = label;
            changed = true;
          } else if (!ad.left && pair.rightId != id) {
            pair
              ..rightId = id
              ..rightName = label;
            changed = true;
          }
        }
        if (changed) controller.add(pairs.values.toList());
      });
      try {
        await FlutterBluePlus.startScan(
          timeout: timeout,
          withServices: [SkUuids.service],
          androidCheckLocationServices: false,
        );
        await FlutterBluePlus.isScanning.where((s) => !s).first;
      } catch (e) {
        controller.addError(e);
      }
      await sub.cancel();
      await controller.close();
    };
    controller.onCancel = () async {
      await FlutterBluePlus.stopScan();
      await sub.cancel();
    };
    return controller.stream;
  }

  // ---------------------------------------------------------------------------
  // Connection handling
  // ---------------------------------------------------------------------------

  @override
  Future<void> connect(String leftId, String rightId) async {
    await disconnect();
    _wanted = true;
    _arms[G1Side.left] = _newArm(G1Side.left, BluetoothDevice.fromId(leftId));
    _arms[G1Side.right] = _newArm(
      G1Side.right,
      BluetoothDevice.fromId(rightId),
    );
    notifyListeners();
    await Future.wait(_arms.values.map(_connectArm));
  }

  @override
  Future<void> disconnect() async {
    _wanted = false;
    _reconnectTimer?.cancel();
    _probeTimer?.cancel();
    _batteryTimer?.cancel();
    _micTimer?.cancel();
    _micOn = false;
    for (final arm in _arms.values) {
      await arm.stateSub?.cancel();
      await arm.evtSub?.cancel();
      _armDown(arm);
      arm.link.dispose();
      try {
        await arm.device?.disconnect();
      } catch (_) {}
    }
    if (!_fake) _arms.clear();
    notifyListeners();
  }

  void _armDown(_SkArm arm) {
    arm.ready = false;
    arm.settingUp = false;
    arm.probing = false;
    arm.link.down();
    for (final c in arm.replies.values) {
      if (!c.isCompleted) c.completeError(TimeoutException('link down'));
    }
    arm.replies.clear();
  }

  Future<void> _connectArm(_SkArm arm) async {
    final device = arm.device;
    if (device == null) return;
    arm.stateSub ??= device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected &&
          (arm.ready || arm.settingUp)) {
        _debug('${arm.side.name} arm disconnected');
        _armDown(arm);
        notifyListeners();
        _scheduleReconnect();
      }
    });
    try {
      _debug('connecting ${arm.side.name} arm (${device.remoteId})');
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 20),
        mtu: null,
      );
      if (Platform.isAndroid) {
        await device.requestMtu(247);
        await device.requestConnectionPriority(
          connectionPriorityRequest: _priority(arm),
        );
      }
      arm.mtu = device.mtuNow;
      final services = await device.discoverServices();
      final service = services.where((s) => s.uuid == SkUuids.service);
      if (service.isEmpty) {
        _debug(
          '${arm.side.name} arm: kein ScouterKit-Dienst – läuft g1v0 auf '
          'diesem Bügel?',
        );
        throw StateError('no g1v0 service');
      }
      final chars = service.first.characteristics;
      arm.cmd = chars.firstWhere((c) => c.uuid == SkUuids.cmd);
      arm.ctrl = chars.firstWhere((c) => c.uuid == SkUuids.ctrl);
      final evt = chars.firstWhere((c) => c.uuid == SkUuids.evt);
      await arm.evtSub?.cancel();
      arm.evtSub = evt.onValueReceived.listen(
        (v) => _onEvent(arm, Uint8List.fromList(v)),
      );
      await evt.setNotifyValue(true);
      await _setup(arm);
    } catch (e) {
      _debug('connecting ${arm.side.name} arm failed: $e');
      _armDown(arm);
      notifyListeners();
      _scheduleReconnect();
    }
  }

  ConnectionPriority _priority(_SkArm arm) =>
      _fast || (_micOn && arm.side == G1Side.right)
      ? ConnectionPriority.high
      : ConnectionPriority.balanced;

  void _scheduleReconnect() {
    if (!_wanted || _reconnectTimer?.isActive == true) return;
    _reconnectTimer = Timer(const Duration(seconds: 5), () async {
      for (final arm in _arms.values) {
        if (!arm.ready && !arm.settingUp && _wanted) {
          try {
            await arm.device?.disconnect();
          } catch (_) {}
          await _connectArm(arm);
        }
      }
    });
  }

  /// HELLO, the session (a new one uploads the font), the reported events
  /// and the arm's state.
  Future<void> _setup(_SkArm arm) async {
    if (arm.settingUp) return;
    arm.settingUp = true;
    try {
      final reply = await _ctrl(arm, SkCtrl.hello, const []);
      if (reply == null || reply.status != 0 || reply.body.length < 35) {
        await _explainNoAnswer(arm);
        throw StateError('no HELLO');
      }
      final hello = SkHello(reply.body);
      if (hello.protocol != 5) {
        _wanted = false;
        _debug(
          '${arm.side.name} arm spricht Protokoll ${hello.protocol}, '
          'die App braucht 5',
        );
        throw StateError('protocol ${hello.protocol}');
      }
      arm.hello = hello;
      if (hello.left != (arm.side == G1Side.left)) {
        _debug('${arm.side.name} arm meldet sich als anderer Bügel');
      }
      if (hello.safeMode) {
        _debug(
          '${arm.side.name} arm im sicheren Modus (nach Startfehlern): '
          'keine Anzeige',
        );
      }
      await _ensureBond(arm, hello);

      final maxPacket = min(min(hello.maxPacket, arm.mtu - 3), 244);
      if (arm.epoch == reply.epoch && arm.fontLoaded) {
        // Same session: arena and window as the arm left them.
        arm.link.start(hello.rxNext, hello.execNext, hello.credits, maxPacket);
      } else {
        final reset = await _ctrl(arm, SkCtrl.resetSession, const [1]);
        if (reset == null || reset.status != 0 || reset.body.length < 37) {
          throw StateError('RESET_SESSION failed');
        }
        final h = SkHello(Uint8List.sublistView(reset.body, 2));
        arm.epoch = reset.epoch;
        arm.fontLoaded = false;
        arm.link.reset();
        arm.link.start(h.rxNext, h.execNext, h.credits, maxPacket);
        final font = _loadedFont ??= await _fontLoader();
        final t0 = DateTime.now();
        final ok = await arm.link.run(
          skUpload(SkArena.font, font.blob, maxPacket - 2),
        );
        if (!ok) throw StateError('font upload failed');
        arm.fontLoaded = true;
        _debug(
          '${arm.side.code}: Schrift geladen (${font.blob.length} B, '
          '${DateTime.now().difference(t0).inMilliseconds} ms)',
        );
      }
      await _reportEvents(arm);
      await _readState(arm);
      arm.ready = true;
      _debug(
        '${arm.side.name} arm ready (g1v0 ${hello.version}'
        '${hello.encrypted ? ', verschlüsselt' : ''})',
      );
      notifyListeners();
      if (connected) _onBothConnected();
    } finally {
      arm.settingUp = false;
    }
  }

  /// Out of the case an arm obeys only a bonded, encrypted host and ignores
  /// everything else, so a missing answer usually means a missing bond.
  Future<void> _explainNoAnswer(_SkArm arm) async {
    final device = arm.device;
    if (device == null || !Platform.isAndroid) return;
    final bond = await device.bondState.first;
    if (bond != BluetoothBondState.bonded) {
      _debug(
        '${arm.side.name} arm antwortet nicht und ist nicht gekoppelt: '
        'Brille ins offene Ladeetui legen, dann wird gekoppelt',
      );
    }
  }

  /// Bonds only while the arm says it is bondable (in the charging case):
  /// a refused pairing attempt costs the arm's oldest bond (VM.md §6.1).
  Future<void> _ensureBond(_SkArm arm, SkHello hello) async {
    final device = arm.device;
    if (device == null || !Platform.isAndroid) return;
    final bond = await device.bondState.first;
    if (bond == BluetoothBondState.bonded) return;
    if (!hello.bondable) {
      _debug(
        '${arm.side.name} arm nicht gekoppelt – zum Koppeln ins offene '
        'Ladeetui legen',
      );
      return;
    }
    _debug('${arm.side.name} arm wird gekoppelt (im Etui)');
    try {
      await device.createBond(timeout: 30);
    } catch (e) {
      _debug('Koppeln ${arm.side.name}: $e');
    }
  }

  int _eventMask(_SkArm arm) {
    var mask =
        1 << SkTrigger.touch |
        1 << SkTrigger.wear |
        1 << SkTrigger.battery |
        1 << SkTrigger.caseState;
    if (arm.side == G1Side.right) mask |= 1 << SkTrigger.tilt;
    return mask;
  }

  Future<void> _reportEvents(_SkArm arm) async {
    final mask = _eventMask(arm);
    final r = await _ctrl(arm, SkCtrl.events, [mask & 0xff, mask >> 8]);
    if (r == null || r.status != 0) {
      _debug('${arm.side.code}: EVENTS abgelehnt');
    }
    if (arm.side == G1Side.right) {
      _headUp = false;
      await _setTiltRange(arm);
    }
  }

  Future<bool> _setTiltRange(_SkArm arm) {
    final code = SkCode();
    if (_headUp) {
      code
        ..sysWrite(SkProp.pitchLo, _headUpAngle - 10)
        ..sysWrite(SkProp.pitchHi, 90);
    } else {
      code
        ..sysWrite(SkProp.pitchLo, -90)
        ..sysWrite(SkProp.pitchHi, _headUpAngle);
    }
    return arm.link.run([code.take()]);
  }

  static const _stateProps = [
    SkProp.battPct,
    SkProp.inCase,
    SkProp.worn,
    SkProp.caseLid,
    SkProp.caseCharging,
    SkProp.caseBattPct,
    SkProp.brightness,
  ];

  Future<void> _readState(_SkArm arm) async {
    final values = await _props(arm, _stateProps);
    if (values == null) return;
    int? known(int v, int max) => v == SkProp.unknown || v > max ? null : v;
    arm.battery = known(values[0], 100);
    arm.inCase = known(values[1], 1);
    arm.worn = known(values[2], 1);
    arm.caseLid = known(values[3], 1);
    final caseCharging = known(values[4], 1);
    final caseBattery = known(values[5], 100);
    if (caseCharging != null) this.caseCharging = caseCharging == 1;
    if (caseBattery != null) batteryCase = caseBattery;
    final level = known(values[6], SkPanel.maxBrightness);
    if (level != null && arm.side == G1Side.right) {
      brightnessPercent = G1Packets.brightnessPercent(level);
    }
    _applyArmState();
  }

  void _applyArmState() {
    batteryLeft = _arms[G1Side.left]?.battery ?? batteryLeft;
    batteryRight = _arms[G1Side.right]?.battery ?? batteryRight;
    final arms = _arms.values;
    String? state;
    final inCase = arms.where((a) => a.inCase == 1);
    if (inCase.isNotEmpty) {
      state = inCase.any((a) => a.caseLid == 1) ? 'case_closed' : 'case_open';
    } else if (arms.any((a) => a.worn == 1)) {
      state = 'worn';
    } else if (arms.any((a) => a.worn == 0)) {
      state = 'not_worn';
    }
    if (state != null && state != wearState) {
      wearState = state;
      _debug('Zustand: $state');
    }
    if (inCase.isEmpty) _caseNoted = false;
    notifyListeners();
  }

  void _onBothConnected() {
    _probeTimer?.cancel();
    _probeTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _probe(),
    );
    _batteryTimer?.cancel();
    _batteryTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => refreshBattery(),
    );
  }

  /// Packets wait but no ACK came for a while: the last one may be lost, so
  /// the window is asked for with HELLO (VM.md §6.2).
  Future<void> _probe() async {
    for (final arm in _arms.values) {
      if (!arm.ready || arm.probing || !arm.link.waiting) continue;
      if (DateTime.now().difference(arm.link.lastHeard) <
          const Duration(milliseconds: 400)) {
        continue;
      }
      arm.probing = true;
      try {
        final r = await _ctrl(arm, SkCtrl.hello, const []);
        if (r == null || r.status != 0 || r.body.length < 35) continue;
        if (r.epoch != arm.epoch) {
          _resync(arm);
          continue;
        }
        final h = SkHello(r.body);
        arm.link.onAck(h.rxNext, h.execNext, h.credits, 0);
      } finally {
        arm.probing = false;
      }
    }
  }

  /// The arm started a new session (a reboot): its memory is gone.
  void _resync(_SkArm arm) {
    if (arm.settingUp) return;
    _debug('${arm.side.name} arm: neue Sitzung (Neustart?), richte neu ein');
    arm.ready = false;
    arm.fontLoaded = false;
    arm.link.down();
    notifyListeners();
    unawaited(
      _setup(arm).catchError((Object e) {
        _debug('Neueinrichtung ${arm.side.name}: $e');
        _scheduleReconnect();
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Writes, control requests, events
  // ---------------------------------------------------------------------------

  Future<void> _writeChannel(_SkArm arm, int channel, Uint8List data) {
    final override = arm.writeOverride;
    if (override != null) return override(channel, data);
    final char = channel == 0 ? arm.cmd : arm.ctrl;
    if (char == null) return Future.error(StateError('not connected'));
    // One write at a time per arm.
    final result = arm.writes.then(
      (_) => char.write(data, withoutResponse: true, timeout: 3),
    );
    arm.writes = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// Sends a control request and waits for its reply; tries again with a
  /// new tag after a timeout. Null without a reply.
  Future<SkEvent?> _ctrl(
    _SkArm arm,
    int op,
    List<int> body, {
    Duration timeout = const Duration(milliseconds: 1000),
    int tries = 3,
  }) async {
    for (var i = 0; i < tries; i++) {
      arm.tag = arm.tag % 255 + 1;
      final tag = arm.tag;
      final completer = Completer<SkEvent>();
      arm.replies[tag] = completer;
      try {
        await _writeChannel(arm, 1, Uint8List.fromList([op, tag, ...body]));
        final reply = await completer.future.timeout(timeout);
        if (reply.replyOp == op) return reply;
      } catch (e) {
        if (e is! TimeoutException) {
          _debug('CTRL 0x${op.toRadixString(16)}: $e');
        }
      } finally {
        arm.replies.remove(tag);
      }
    }
    return null;
  }

  /// Reads properties (at most 12).
  Future<List<int>?> _props(_SkArm arm, List<int> ids) async {
    final r = await _ctrl(arm, SkCtrl.props, ids);
    if (r == null || r.status != 0 || r.body.length < ids.length * 4) {
      return null;
    }
    final d = ByteData.sublistView(r.body);
    return [
      for (var i = 0; i < ids.length; i++) d.getUint32(i * 4, Endian.little),
    ];
  }

  /// Feeds an event as if it came from the arm (tests).
  @override
  void receive(G1Side side, Uint8List data) {
    final arm = _arms[side];
    if (arm != null) _onEvent(arm, data);
  }

  void _onEvent(_SkArm arm, Uint8List data) {
    if (data.length < 9) return;
    final e = SkEvent(data);
    if (e.isReply) {
      final c = arm.replies[e.tag];
      if (c != null && !c.isCompleted) c.complete(e);
      return;
    }
    if (arm.ready && arm.epoch != null && e.epoch != arm.epoch) {
      _resync(arm);
      return;
    }
    switch (e.type) {
      case SkEvt.ack when data.length >= 18:
        arm.link.onAck(e.u16(9), e.u16(11), e.u8(13), e.u32(14));
      case SkEvt.error when data.length >= 22:
        _debug(
          '${arm.side.code}: Fehler in Paket ${e.u16(9)}: '
          '${skErrorName(e.u8(13))} (op 0x${e.u8(12).toRadixString(16)}, '
          'Detail ${e.u32(14)})',
        );
        arm.link.onError(e.u16(9));
      case SkEvt.notice when data.length >= 10:
        _onNotice(arm, e.u8(9), Uint8List.sublistView(data, 10));
      case SkEvt.micData when data.length >= 12:
        if (arm.side == G1Side.right && data.length > 12) {
          emitAudio(Uint8List.sublistView(data, 12));
        }
      case SkEvt.input when data.length >= 16:
        _onInput(arm, e.u8(11), e.u32(12));
    }
  }

  void _onNotice(_SkArm arm, int kind, Uint8List body) {
    switch (kind) {
      case 4:
        _debug('${arm.side.code}: Verbindung verschlüsselt');
      case 5:
        final reason = body.isEmpty ? 0 : body[0];
        _debug('${arm.side.code}: Mikrofon von der Brille beendet ($reason)');
      case 3:
        _debug('${arm.side.code}: Anzeigefehler beim Start');
    }
  }

  void _emit(G1Side side, int code) => emitEvent(
    G1TouchEvent(side, code, Uint8List.fromList([G1Cmd.event, code])),
  );

  void _onInput(_SkArm arm, int trigger, int value) {
    switch (trigger) {
      case SkTrigger.touch:
        switch (value) {
          case SkGesture.tap:
            _emit(arm.side, G1Event.singleTap);
          case SkGesture.doubleTap:
            _emit(arm.side, G1Event.doubleTap);
          case SkGesture.tripleTap:
            // g1v0 has no silent mode: the app keeps it.
            _silent = !_silent;
            _emit(
              arm.side,
              _silent ? G1Event.silentModeOn : G1Event.silentModeOff,
            );
          case SkGesture.longStart:
            _emit(arm.side, G1Event.evenAiStart);
          case SkGesture.longEnd:
            _emit(arm.side, G1Event.evenAiStop);
        }
      case SkTrigger.wear:
        arm.worn = value > 1 ? null : value;
        _applyArmState();
      case SkTrigger.battery:
        if (value <= 100) arm.battery = value;
        _applyArmState();
      case SkTrigger.caseState:
        arm.inCase = value & 1;
        arm.caseLid = (value >> 1) & 1;
        if (arm.inCase == 1) {
          caseCharging = (value >> 2) & 1 == 1;
          final pct = (value >> 8) & 0xff;
          if (pct <= 100) batteryCase = pct;
        }
        _applyArmState();
      case SkTrigger.tilt when arm.side == G1Side.right:
        final pitch = value.toSigned(32);
        final up = pitch > _headUpAngle;
        final down = pitch < _headUpAngle - 10;
        if (!_headUp && up) {
          _headUp = true;
          _emit(arm.side, G1Event.headUp);
        } else if (_headUp && down) {
          _headUp = false;
          _emit(arm.side, G1Event.headDown);
        } else {
          return;
        }
        unawaited(_setTiltRange(arm));
    }
  }

  // ---------------------------------------------------------------------------
  // Commands
  // ---------------------------------------------------------------------------

  @override
  Future<bool> send(
    List<Uint8List> packets, {
    bool left = true,
    bool right = true,
    Duration waitAfter = Duration.zero,
    bool ackLeft = false,
  }) async {
    _debug('Even-Befehl an g1v0 übersprungen');
    return false;
  }

  @override
  Future<G1Response> request(
    G1Side side,
    Uint8List data, {
    Duration timeout = const Duration(milliseconds: 1500),
  }) => Future.error(G1TimeoutException(side, data.isEmpty ? -1 : data[0]));

  @override
  Future<bool> sendHeartbeat() async => connected;

  @override
  Future<void> refreshBattery() async {
    for (final arm in _arms.values) {
      if (!arm.ready) continue;
      final v = await _props(arm, const [SkProp.battPct]);
      if (v != null && v[0] <= 100) arm.battery = v[0];
    }
    _applyArmState();
  }

  Iterable<_SkArm> _targets({bool left = true, bool right = true}) => _arms
      .values
      .where((a) => a.ready && (a.side == G1Side.left ? left : right));

  /// Runs the same host code on the selected arms.
  Future<bool> _runOn(
    List<Uint8List> codes, {
    bool left = true,
    bool right = true,
  }) async {
    final arms = _targets(left: left, right: right).toList();
    if (arms.isEmpty) return false;
    final results = await Future.wait(arms.map((a) => a.link.run(codes)));
    return results.every((r) => r);
  }

  @override
  Future<bool> sendText(
    String text, {
    int status = G1ScreenStatus.textShow | G1ScreenStatus.newContent,
    int page = 0,
    int pages = 1,
    bool left = true,
    bool right = true,
  }) async {
    final font = _loadedFont ??= await _fontLoader();
    final arms = _targets(left: left, right: right).where((a) {
      if (a.inCase != 1) return true;
      if (!_caseNoted) {
        _caseNoted = true;
        _debug('Brille im Ladeetui – Anzeige bleibt aus (stört das Laden)');
      }
      return false;
    }).toList();
    if (arms.isEmpty) return _targets(left: left, right: right).isNotEmpty;
    final maxCode = arms.map((a) => a.link.maxPacket).reduce(min) - 2;
    final codes = textCode(font, text, top: textTop, maxCode: maxCode);
    final results = await Future.wait(arms.map((a) => a.link.run(codes)));
    return results.every((r) => r);
  }

  /// Host code that draws [text] (lines split at '\n', wrapped to the panel)
  /// into the arena's frame and shows it, in packets of at most [maxCode]
  /// bytes.
  @visibleForTesting
  static List<Uint8List> textCode(
    SkFont font,
    String text, {
    int top = 140,
    required int maxCode,
  }) {
    final lines = wrap(font, text, SkPanel.width - 2 * textLeft);
    final maxLines = max(1, (SkPanel.height - top) ~/ font.lineSpacing);
    final packets = <Uint8List>[];
    var code = SkCode();
    void room(int bytes) {
      if (code.length + bytes > maxCode) {
        packets.add(code.take());
        code = SkCode();
      }
    }

    room(skOpSize(7));
    code.fill(
      SkArena.frame,
      SkPanel.stride,
      0,
      0,
      SkPanel.width,
      SkPanel.height,
      0,
    );
    var textAt = SkArena.text;
    for (var i = 0; i < min(lines.length, maxLines); i++) {
      final glyphs = font.encode(lines[i]);
      if (glyphs.isEmpty) continue;
      if (textAt + glyphs.length > SkArena.text + SkArena.textSize) break;
      final baseline = top + font.ascent + i * font.lineSpacing;
      // The glyph indices and the GLYPHS that draws them, in one packet.
      final chunk = min(glyphs.length, maxCode - skOpSize(9) - 5);
      room(5 + chunk + skOpSize(9));
      code.write(textAt, glyphs.sublist(0, chunk));
      code.glyphs(
        SkArena.font,
        SkArena.frame,
        SkPanel.stride,
        textLeft,
        baseline,
        textLevel,
        textAt,
        chunk,
      );
      textAt += chunk;
    }
    room(skOpSize(8));
    code.draw(
      SkArena.frame,
      SkPanel.stride,
      0,
      0,
      0,
      0,
      SkPanel.width,
      SkPanel.height,
    );
    packets.add(code.take());
    return packets;
  }

  /// Splits [text] into lines at most [width] pixels wide (at spaces where
  /// possible). Empty lines are kept (vertical spacing).
  static List<String> wrap(SkFont font, String text, int width) {
    final out = <String>[];
    final raw = text.split('\n');
    while (raw.isNotEmpty && raw.last.trim().isEmpty) {
      raw.removeLast();
    }
    for (final line in raw) {
      var rest = line.trimRight();
      if (rest.isEmpty) {
        out.add('');
        continue;
      }
      while (rest.isNotEmpty) {
        if (font.width(rest) <= width) {
          out.add(rest);
          break;
        }
        // Longest prefix that fits.
        final runes = rest.runes.toList();
        var fit = 0;
        var w = 0;
        while (fit < runes.length) {
          w += font.advanceOf(font.glyphOf(runes[fit]));
          if (w > width) break;
          fit++;
        }
        var cut = fit;
        final space = String.fromCharCodes(runes.sublist(0, fit))
            .lastIndexOf(' ');
        if (space > 0) {
          cut = String.fromCharCodes(runes.sublist(0, space)).runes.length;
        }
        if (cut == 0) cut = max(1, fit);
        out.add(String.fromCharCodes(runes.sublist(0, cut)).trimRight());
        rest = String.fromCharCodes(runes.sublist(cut)).trimLeft();
      }
    }
    return out;
  }

  /// Switches the panels off: a black but lit panel still costs ≈ 4.6 mA
  /// (VM.md §6.6). The next text powers them on again (≈ 71 ms).
  @override
  Future<bool> blankScreen() {
    final code = SkCode()..sysWrite(SkProp.panel, 0);
    return _runOn([code.take()]);
  }

  /// g1v0 has no dashboard to return to.
  @override
  Future<bool> exitToDashboard() async => true;

  @override
  Future<int?> readScreenState(G1Side side) async => null;

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  /// Even settings that g1v0 does not have are ignored.
  @override
  Future<bool> sendSetting(Uint8List packet) async => true;

  @override
  Future<bool> sendWhitelist(Map<String, String> apps) async => true;

  @override
  Future<bool> sendNotification(List<Uint8List> packets) async => false;

  @override
  Future<bool> setBrightness(int percent, {required bool auto}) =>
      setBrightnessLevel(
        (percent.clamp(0, 100) * SkPanel.maxBrightness / 100).round(),
        auto: auto,
      );

  /// The light sensor is on the right arm; with automatic brightness the
  /// left arm follows the right one over the arm-to-arm link (VM.md §6.7).
  @override
  Future<bool> setBrightnessLevel(int level, {required bool auto}) async {
    final l = level.clamp(0, SkPanel.maxBrightness);
    final code = SkCode();
    if (auto) {
      code
        ..sysWrite(SkProp.peerLink, 1)
        ..sysWrite(SkProp.brightness, l)
        ..sysWrite(SkProp.autoBrightness, 1);
    } else {
      code
        ..sysWrite(SkProp.autoBrightness, 0)
        ..sysWrite(SkProp.brightness, l);
    }
    final ok = await _runOn([code.take()]);
    brightnessPercent = G1Packets.brightnessPercent(l);
    notifyListeners();
    return ok;
  }

  @override
  Future<({int percent, bool auto})?> readBrightness() async {
    final arm = _arms[G1Side.right];
    if (arm == null || !arm.ready) return null;
    final v = await _props(arm, const [
      SkProp.brightness,
      SkProp.autoBrightness,
    ]);
    if (v == null || v[0] > SkPanel.maxBrightness) return null;
    return (percent: G1Packets.brightnessPercent(v[0]), auto: v[1] == 1);
  }

  @override
  Future<int?> readBrightnessLevel() async {
    final arm = _arms[G1Side.right];
    if (arm == null || !arm.ready) return null;
    final v = await _props(arm, const [SkProp.brightness]);
    if (v == null || v[0] > SkPanel.maxBrightness) return null;
    return v[0];
  }

  /// g1v0 always detects wear; there is nothing to switch.
  @override
  Future<bool> setWearDetection(bool enabled) async => true;

  @override
  Future<bool?> readWearDetection() async => true;

  /// g1v0 has no silent mode: the app keeps it (triple tap toggles it).
  @override
  Future<bool> setSilentMode(bool enabled) async {
    _silent = enabled;
    return true;
  }

  @override
  Future<bool> setHeadUpAngle(int angle) async {
    _headUpAngle = angle.clamp(0, 60);
    final arm = _arms[G1Side.right];
    if (arm == null || !arm.ready) return true;
    return _setTiltRange(arm);
  }

  /// No Even dashboard on g1v0.
  @override
  Future<bool> setHeadUpMode(int mode) async => true;

  /// The height (0–8) moves the text block; the distance has no
  /// counterpart.
  @override
  Future<bool> setDisplayPosition(
    int height,
    int depth,
    int counter, {
    bool preview = false,
  }) async {
    textTop = 60 + height.clamp(0, 8) * 20;
    return true;
  }

  // ---------------------------------------------------------------------------
  // Microphone and link
  // ---------------------------------------------------------------------------

  /// The right arm's microphone at 16 kbps: 20-byte LC3 frames of 10 ms as
  /// with Even's firmware. The arm holds it for a lease of 2 s, renewed here
  /// every 0.8 s (VM.md §6.5); it needs an encrypted link.
  @override
  Future<bool> setMic(bool enable) async {
    final arm = _arms[G1Side.right];
    if (arm == null || !arm.ready) return false;
    if (!enable) {
      _micTimer?.cancel();
      _micOn = false;
      final r = await _ctrl(arm, SkCtrl.mic, const [0, 0]);
      unawaited(_updatePriority());
      return r != null && r.status == 0;
    }
    _micOn = true;
    unawaited(_updatePriority());
    final ok = await _renewMic(arm);
    _micTimer?.cancel();
    _micTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (_micOn && arm.ready) unawaited(_renewMic(arm));
    });
    return ok;
  }

  Future<bool> _renewMic(_SkArm arm) async {
    final r = await _ctrl(arm, SkCtrl.mic, const [1, 1], tries: 1);
    if (r == null) return false;
    if (r.status != 0) {
      _debug('Mikrofon: ${skErrorName(r.status)}');
      if (r.status == 12) {
        _debug('Mikrofon braucht eine verschlüsselte (gekoppelte) Verbindung');
      }
      return false;
    }
    return true;
  }

  @override
  Future<void> setFastConnection(bool fast) async {
    if (fast == _fast) return;
    _fast = fast;
    _debug(fast ? 'Verbindung: schnell' : 'Verbindung: sparsam');
    await _updatePriority();
  }

  Future<void> _updatePriority() async {
    if (!Platform.isAndroid || _fake) return;
    for (final arm in _arms.values) {
      final device = arm.device;
      if (device == null || !arm.ready) continue;
      try {
        await device.requestConnectionPriority(
          connectionPriorityRequest: _priority(arm),
        );
      } catch (e) {
        _debug('connection priority ${arm.side.name}: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Tests
  // ---------------------------------------------------------------------------

  /// Marks the fake arms as set up with [epoch] (tests).
  @visibleForTesting
  void fakeReady({int epoch = 1, int maxPacket = 244}) {
    for (final arm in _arms.values) {
      arm
        ..epoch = epoch
        ..fontLoaded = true
        ..ready = true;
      arm.link.start(0, 0, SkLink.window, maxPacket);
    }
    notifyListeners();
  }

  /// Runs the setup of both fake arms (tests).
  @visibleForTesting
  Future<void> fakeSetup() => Future.wait(_arms.values.map((a) => _setup(a)));

  /// Async work (a disconnect, a setup) may finish after [dispose].
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _wanted = false;
    _probeTimer?.cancel();
    _batteryTimer?.cancel();
    _micTimer?.cancel();
    _reconnectTimer?.cancel();
    for (final arm in _arms.values) {
      arm.link.dispose();
    }
    super.dispose();
  }
}
