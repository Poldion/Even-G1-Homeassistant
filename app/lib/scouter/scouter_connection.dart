import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../g1/g1_connection.dart';
import '../g1/protocol.dart';
import 'sk_asm.dart';
import 'sk_clock.dart';
import 'sk_font.dart';
import 'sk_icons.dart';
import 'sk_link.dart';
import 'sk_program.dart';
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

  /// Offset of the arm's clock, for drawing both eyes at once.
  final SkClock clock = SkClock();

  /// The resident program runs (this session), with the gesture detector.
  bool resident = false;
  bool residentGestures = false;

  /// Icons in the arena of the current session.
  final Set<String> icons = {};

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
  Timer? _clockTimer;
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

  /// Free rows kept below the text block.
  static const textBottom = 16;

  /// Pixel sizes of the bundled font (Departure Mono drawn ×2).
  static const _lineSpacing = 28;
  static const _advance = 14;

  int get _lineHeight => _loadedFont?.lineSpacing ?? _lineSpacing;

  /// Lines from [textTop] down to the panel's bottom (11 at the default
  /// height, instead of Even's 5).
  @override
  int get displayLines =>
      max(1, (SkPanel.height - textBottom - textTop) ~/ _lineHeight);

  /// The font is monospaced: 42 characters on the 640 px line.
  @override
  int get displayColumns => (SkPanel.width - 2 * textLeft) ~/ _advance;

  /// Left edge of the text beside a notification icon.
  static const iconTextLeft = textLeft + SkIcons.size + 12;

  static int _textWidth(String? icon) =>
      SkPanel.width - textLeft - (icon == null ? textLeft : iconTextLeft);

  @override
  Future<List<String>> layoutPages(String text, {String? icon}) async {
    final font = _loadedFont ??= await _fontLoader();
    final lines = wrap(font, text, _textWidth(icon));
    if (lines.isEmpty) return [''];
    final n = displayLines;
    return [
      for (var i = 0; i < lines.length; i += n)
        lines.sublist(i, min(i + n, lines.length)).join('\n'),
    ];
  }

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
    _clockTimer?.cancel();
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
        arm.icons.clear();
        arm.clock.reset();
        arm.resident = false;
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
      await _updateResident(arm);
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
    // The light sensor reports changes while the offset mode needs them.
    if (arm.side == G1Side.right && _offsetLevels != null) {
      mask |= 1 << SkTrigger.light;
    }
    // With the resident program the right arm reports the head's moves
    // itself (NOTIFY), and the program owns the tilt range.
    if (arm.side == G1Side.right && !arm.resident) {
      mask |= 1 << SkTrigger.tilt;
    }
    return mask;
  }

  Future<void> _reportEvents(_SkArm arm) async {
    final mask = _eventMask(arm);
    final r = await _ctrl(arm, SkCtrl.events, [mask & 0xff, mask >> 8]);
    if (r == null || r.status != 0) {
      _debug('${arm.side.code}: EVENTS abgelehnt');
    }
    if (arm.side == G1Side.right && !arm.resident) {
      _headUp = false;
      await _setTiltRange(arm);
    }
  }

  // ---------------------------------------------------------------------------
  // Resident program (SkResident): dashboard on head up, head gestures
  // ---------------------------------------------------------------------------

  bool _dashboardOnHeadUp = false;
  String _dashboardText = '';
  bool _headGestures = false;

  @override
  bool get showsDashboardItself =>
      _dashboardOnHeadUp &&
      _arms.length == 2 &&
      _arms.values.every((a) => a.ready && a.resident);

  @override
  bool get supportsHeadGestures => true;

  bool _wantsResident(_SkArm arm) =>
      _dashboardOnHeadUp || (_headGestures && arm.side == G1Side.right);

  @override
  Future<void> setDashboard({
    required bool onHeadUp,
    required String text,
  }) async {
    final changed = onHeadUp != _dashboardOnHeadUp || text != _dashboardText;
    _dashboardOnHeadUp = onHeadUp;
    _dashboardText = text;
    if (!changed) return;
    for (final arm in _arms.values.where((a) => a.ready)) {
      if (arm.resident == _wantsResident(arm)) {
        if (arm.resident) await _writeDashboard(arm, redraw: true);
      } else {
        await _updateResident(arm);
      }
    }
    notifyListeners();
  }

  @override
  Future<void> setHeadGestures(bool enabled) async {
    if (enabled == _headGestures) return;
    _headGestures = enabled;
    final arm = _arms[G1Side.right];
    if (arm != null && arm.ready) await _updateResident(arm);
  }

  /// Starts, restarts (other variant) or stops the resident program.
  Future<void> _updateResident(_SkArm arm) async {
    final want = _wantsResident(arm);
    final gestures = _headGestures && arm.side == G1Side.right;
    if (!want) {
      if (arm.resident) {
        await _ctrl(arm, SkCtrl.vmStop, const []);
        arm.resident = false;
        _debug('${arm.side.code}: Programm beendet');
        await _reportEvents(arm);
      }
      return;
    }
    if (arm.resident && arm.residentGestures == gestures) {
      await _writeDashboard(arm, redraw: true);
      return;
    }
    final font = _loadedFont ??= await _fontLoader();
    final p = SkResident.build(gestures: gestures);
    final maxCode = arm.link.maxPacket - 2;
    final ok = await arm.link.run([
      ...skUpload(SkResident.pool, p.pool, maxCode),
      ...skUpload(SkResident.code, p.code, maxCode),
      ...skUpload(SkResident.table, p.table, maxCode),
      _residentState(font),
    ]);
    if (!ok || !await _writeDashboard(arm)) {
      _debug('${arm.side.code}: Programm nicht geladen');
      return;
    }
    final t = SkResident.table;
    final r = await _ctrl(arm, SkCtrl.vmStart, [
      t & 0xff,
      t >> 8 & 0xff,
      t >> 16 & 0xff,
      t >> 24 & 0xff,
    ]);
    if (r == null || r.status != 0) {
      _debug('${arm.side.code}: VM_START abgelehnt');
      return;
    }
    arm.resident = true;
    arm.residentGestures = gestures;
    _debug(
      '${arm.side.code}: Programm läuft (${p.code.length} B'
      '${gestures ? ', Kopfgesten' : ''})',
    );
    await _reportEvents(arm);
    notifyListeners();
  }

  /// Host code for the program's settings words.
  Uint8List _residentState(SkFont font) {
    final d = ByteData(40);
    void w(SkW word, int v) =>
        d.setUint32(word.address - SkResident.state, v, Endian.little);
    w(SkResident.angle, _headUpAngle);
    w(
      SkResident.flags,
      (_dashboardOnHeadUp ? SkResident.flagDashboard : 0) |
          (_headGestures ? SkResident.flagGestures : 0),
    );
    w(SkResident.left, textLeft);
    w(SkResident.ascent, font.ascent);
    w(SkResident.rows, min(displayLines, SkResident.maxLines));
    w(SkResident.lineHeight, font.lineSpacing);
    // busy, shown, count, up stay as they are (bytes 0–15 not written).
    final code = SkCode()
      ..write(SkResident.angle.address, d.buffer.asUint8List(16, 24));
    return code.take();
  }

  /// Writes the dashboard's lines into the program's area; with [redraw]
  /// the program draws them again if they are shown (USER0).
  Future<bool> _writeDashboard(_SkArm arm, {bool redraw = false}) async {
    final font = _loadedFont ??= await _fontLoader();
    final maxCode = arm.link.maxPacket - 2;
    final rows = min(displayLines, SkResident.maxLines);
    final lines = wrap(
      font,
      _dashboardText.isEmpty ? 'Home Assistant' : _dashboardText,
      SkPanel.width - 2 * textLeft,
    ).take(rows).toList();
    final text = BytesBuilder();
    final table = ByteData(12 * lines.length);
    var count = 0;
    for (final line in lines) {
      final glyphs = font.encode(line);
      final at = SkResident.text + text.length;
      if (at + glyphs.length > SkResident.textEnd) break;
      text.add(glyphs);
      table
        ..setUint32(
          12 * count,
          textTop + count * font.lineSpacing,
          Endian.little,
        )
        ..setUint32(12 * count + 4, at, Endian.little)
        ..setUint32(12 * count + 8, glyphs.length, Endian.little);
      count++;
    }
    List<int> u32(int v) => [v & 0xff, v >> 8 & 0xff, v >> 16 & 0xff, v >> 24];
    final codes = <Uint8List>[
      // No lines while they change, so the program never draws half of them.
      (SkCode()..write(SkResident.count.address, u32(0))).take(),
      ...skUpload(SkResident.text, text.toBytes(), maxCode),
      ...skUpload(
        SkResident.lines,
        table.buffer.asUint8List(0, 12 * count),
        maxCode,
      ),
      _residentState(font),
    ];
    final last = SkCode()..write(SkResident.count.address, u32(count));
    if (redraw) last.raise(SkTrigger.user0);
    codes.add(last.take());
    return arm.link.run(codes);
  }

  void _onNotify(_SkArm arm, int a, int b) {
    if (a == SkResident.notifyHead) {
      // Both arms see the head move; the right one reports it.
      if (arm.side != G1Side.right) return;
      _headUp = b == 1;
      _emit(arm.side, _headUp ? G1Event.headUp : G1Event.headDown);
      // The program drew the dashboard: the light sensor runs now.
      if (_headUp) _scheduleLightRead();
    } else if (a == SkResident.notifyGesture) {
      if (b == SkResident.nod) _emit(arm.side, G1Event.nod);
      if (b == SkResident.shake) _emit(arm.side, G1Event.headShake);
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
    // The arms' clocks drift by up to ~130 ppm (VM.md §7).
    unawaited(_syncClocks());
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(
      const Duration(minutes: 3),
      (_) => _syncClocks(rounds: 4),
    );
  }

  /// `PING` rounds on both arms for the clock model.
  Future<void> _syncClocks({int rounds = 8}) async {
    for (final arm in _arms.values) {
      for (var i = 0; i < rounds && arm.ready; i++) {
        final sent = SkClock.hostNow();
        final r = await _ctrl(
          arm,
          SkCtrl.ping,
          [sent & 0xff, sent >> 8 & 0xff, sent >> 16 & 0xff, sent >> 24 & 0xff],
          tries: 1,
          timeout: const Duration(milliseconds: 500),
        );
        final received = SkClock.hostNow();
        if (r == null || r.status != 0 || r.body.length < 12) continue;
        final d = ByteData.sublistView(r.body);
        if (d.getUint32(0, Endian.little) != sent) continue;
        arm.clock.add(
          sent: sent,
          armRx: d.getUint32(4, Endian.little),
          armTx: d.getUint32(8, Endian.little),
          received: received,
        );
      }
    }
  }

  /// When both arms should draw: two connection intervals, the clocks'
  /// error and 15 ms for the arm (VM.md §7), at least 40 ms.
  int _drawLeadUs(Iterable<_SkArm> arms) {
    final interval = (_fast || _micOn) ? 15000 : 50000;
    final error = arms.map((a) => a.clock.errorUs).fold(0, max);
    return max(40000, 2 * interval + error + 15000);
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
      case SkEvt.notify when data.length >= 20:
        _onNotify(arm, e.u32(12), e.u32(16));
      case SkEvt.halt when data.length >= 20:
        _debug(
          '${arm.side.code}: Programm angehalten: ${skErrorName(e.u8(15))} '
          '(0x${e.u32(10).toRadixString(16)}, op 0x${e.u8(14).toRadixString(16)})',
        );
        arm.resident = false;
        unawaited(_reportEvents(arm));
        notifyListeners();
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
          // Left long press: Assist, as with Even's firmware; the right one
          // is a gesture of its own (Even's firmware keeps it for QuickNote).
          case SkGesture.longStart:
            _emit(
              arm.side,
              arm.side == G1Side.left
                  ? G1Event.evenAiStart
                  : G1Event.rightHoldStart,
            );
          case SkGesture.longEnd:
            _emit(
              arm.side,
              arm.side == G1Side.left
                  ? G1Event.evenAiStop
                  : G1Event.rightHoldStop,
            );
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
      case SkTrigger.light when arm.side == G1Side.right:
        unawaited(_applyLight(value));
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
    String? icon,
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
    final name = icon == null ? null : _iconName(icon);
    if (name != null) {
      final data = await SkIcons.load(name);
      await Future.wait(arms.map((a) => _uploadIcon(a, name, data)));
    }
    final iconAt = name == null ? null : SkIcons.slot(name, SkArena.icons);
    final synced = arms.length == 2 && arms.every((a) => a.clock.known);
    final codes = textCode(
      font,
      text,
      top: textTop,
      maxCode: maxCode,
      icon: iconAt,
      draw: !synced,
    );
    final results = await Future.wait(arms.map((a) => a.link.run(codes)));
    if (!synced || !results.every((r) => r)) return results.every((r) => r);
    // Both frames are ready: both eyes show them at the same moment.
    final at = SkClock.hostNow() + _drawLeadUs(arms);
    final shown = await Future.wait(
      arms.map((a) => a.link.run([drawAtCode(a.clock.toArm(at))])),
    );
    _scheduleLightRead();
    return shown.every((r) => r);
  }

  /// Host code that waits until [armTime] and shows the frame.
  @visibleForTesting
  static Uint8List drawAtCode(int armTime) {
    final code = SkCode()
      ..sleepUntil(armTime)
      ..draw(
        SkArena.frame,
        SkPanel.stride,
        0,
        0,
        0,
        0,
        SkPanel.width,
        SkPanel.height,
      );
    return code.take();
  }

  static String _iconName(String icon) =>
      SkIcons.names.contains(icon) ? icon : SkIcons.generic;

  /// Uploads an icon into its slot once per session.
  Future<void> _uploadIcon(_SkArm arm, String name, Uint8List data) async {
    if (arm.icons.contains(name)) return;
    final ok = await arm.link.run(
      skUpload(SkIcons.slot(name, SkArena.icons), data, arm.link.maxPacket - 2),
    );
    if (ok) arm.icons.add(name);
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
    int? icon,
    bool draw = true,
  }) {
    final left = icon == null ? textLeft : iconTextLeft;
    final lines = wrap(font, text, SkPanel.width - textLeft - left);
    final maxLines = max(1, (SkPanel.height - top) ~/ font.lineSpacing);
    final packets = <Uint8List>[];
    var code = SkCode();
    void room(int bytes) {
      if (code.length + bytes > maxCode) {
        packets.add(code.take());
        code = SkCode();
      }
    }

    // The app shows something: the resident program draws nothing now
    // (busy = 1, shown = 0).
    code.write(SkResident.busy.address, const [1, 0, 0, 0, 0, 0, 0, 0]);
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
    if (icon != null) {
      // The app's icon beside the text, its top at the first line's top.
      room(skOpSize(12));
      code.blit(
        icon,
        SkIcons.stride,
        SkArena.frame,
        SkPanel.stride,
        textLeft,
        top,
        SkIcons.size,
        SkIcons.size,
      );
    }
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
        left,
        baseline,
        textLevel,
        textAt,
        chunk,
      );
      textAt += chunk;
    }
    if (draw) {
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
    }
    if (code.length > 0) packets.add(code.take());
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
    final code = SkCode()
      ..write(SkResident.busy.address, const [0, 0, 0, 0])
      ..sysWrite(SkProp.panel, 0);
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
  // ---------------------------------------------------------------------------
  // Automatic brightness with an offset
  // ---------------------------------------------------------------------------

  /// Offset in levels while the app runs the automatic brightness itself.
  int? _offsetLevels;
  int? _offsetApplied;
  Timer? _lightTimer;

  @override
  bool get supportsBrightnessOffset => true;

  /// g1v0's automatic brightness has no offset either, but its light sensor
  /// (right arm, measuring while the panel is on, VM.md §6.7) reports when
  /// the light leaves a range: the app then sets stock's level for that light
  /// plus the offset on both eyes, and a new range around the reading.
  @override
  Future<void> setAutoBrightnessOffset(int levels) async {
    final starting = _offsetLevels == null;
    _offsetLevels = levels;
    _offsetApplied = null;
    final right = _arms[G1Side.right];
    if (right == null || !right.ready) return;
    if (starting) {
      final code = SkCode()
        ..sysWrite(SkProp.autoBrightness, 0)
        ..sysWrite(SkProp.lightLo, 0)
        ..sysWrite(SkProp.lightHi, 0x7fffffff);
      await _runOn([code.take()]);
      await _reportEvents(right);
    }
    _scheduleLightRead();
  }

  Future<void> _stopOffset() async {
    if (_offsetLevels == null) return;
    _offsetLevels = null;
    _lightTimer?.cancel();
    final right = _arms[G1Side.right];
    if (right != null && right.ready) await _reportEvents(right);
  }

  /// The sensor converts every 800 ms once the panel is on: read it a
  /// moment after something was drawn.
  void _scheduleLightRead() {
    if (_offsetLevels == null) return;
    _lightTimer?.cancel();
    _lightTimer = Timer(const Duration(milliseconds: 1200), () async {
      final right = _arms[G1Side.right];
      if (right == null || !right.ready || _offsetLevels == null) return;
      final v = await _props(right, const [SkProp.light]);
      if (v != null && v[0] != SkProp.unknown) await _applyLight(v[0]);
    });
  }

  /// Stock's level for an ambient light in lux (VM.md §6.7).
  @visibleForTesting
  static int stockLevel(int lux) {
    if (lux < 50) return lux ~/ 5;
    if (lux < 200) return 10 + (lux - 50) ~/ 10;
    if (lux < 1000) return 25 + (lux - 200) ~/ 50;
    if (lux < 2000) return 41;
    return 42;
  }

  /// [light] in 0.01 lux.
  Future<void> _applyLight(int light) async {
    final offset = _offsetLevels;
    if (offset == null) return;
    final level = (stockLevel(light ~/ 100) + offset).clamp(
      0,
      SkPanel.maxBrightness,
    );
    // A range around the reading: ±25 %, at least ±2 lux.
    final margin = max(light ~/ 4, 200);
    final range = SkCode()
      ..sysWrite(SkProp.lightLo, max(0, light - margin))
      ..sysWrite(SkProp.lightHi, light + margin);
    await _arms[G1Side.right]?.link.run([range.take()]);
    if (level == _offsetApplied) return;
    _offsetApplied = level;
    final code = SkCode()..sysWrite(SkProp.brightness, level);
    await _runOn([code.take()]);
    brightnessPercent = G1Packets.brightnessPercent(level);
    _debug(
      'Auto-Helligkeit: ${light ~/ 100} lx, Stufe ${stockLevel(light ~/ 100)} '
      '${offset >= 0 ? '+' : ''}$offset → $level',
    );
    notifyListeners();
  }

  @override
  Future<bool> setBrightnessLevel(int level, {required bool auto}) async {
    await _stopOffset();
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
    final font = _loadedFont ??= await _fontLoader();
    for (final arm in _arms.values.where((a) => a.ready && a.resident)) {
      await arm.link.run([_residentState(font)]);
    }
    final arm = _arms[G1Side.right];
    if (arm == null || !arm.ready || arm.resident) return true;
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
    // Fewer or more lines fit now (Home Assistant's dashboard follows).
    notifyListeners();
    for (final arm in _arms.values.where((a) => a.ready && a.resident)) {
      await _writeDashboard(arm);
    }
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

  /// Takes the PING rounds of the clock model (tests).
  @visibleForTesting
  Future<void> fakeSyncClocks() => _syncClocks();

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
    _clockTimer?.cancel();
    _lightTimer?.cancel();
    _reconnectTimer?.cancel();
    for (final arm in _arms.values) {
      arm.link.dispose();
    }
    super.dispose();
  }
}
