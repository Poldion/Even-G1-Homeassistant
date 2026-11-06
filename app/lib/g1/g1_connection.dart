import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'protocol.dart';

/// Firmware on the arms.
enum G1Firmware {
  /// Even Realities' own firmware (the official app works with it).
  even('even'),

  /// ScouterKit's g1v0 (github.com/mafik/scouter_kit).
  scouterKit('scouterkit');

  const G1Firmware(this.id);
  final String id;

  static G1Firmware fromId(String? id) =>
      values.firstWhere((f) => f.id == id, orElse: () => even);
}

/// A pair of arms found during a scan.
class G1Pair {
  G1Pair(this.channel, {this.firmware = G1Firmware.even});

  final String channel;
  final G1Firmware firmware;
  String? leftId;
  String? rightId;
  String? leftName;
  String? rightName;

  bool get complete => leftId != null && rightId != null;
}

class G1TouchEvent {
  G1TouchEvent(this.side, this.code, this.data);

  final G1Side side;
  final int code;
  final Uint8List data;
}

class G1Response {
  G1Response(this.side, this.data);

  final G1Side side;
  final Uint8List data;

  int get status => data.length > 1 ? data[1] : -1;
  bool get ok => status == G1Status.success || status == G1Status.continueing;
}

class G1TimeoutException implements Exception {
  G1TimeoutException(this.side, this.cmd);

  final G1Side side;
  final int cmd;

  @override
  String toString() =>
      'No answer from ${side.name} arm for 0x${cmd.toRadixString(16)}';
}

/// One BLE connection to one arm of the glasses.
class _Arm {
  _Arm(this.side, this.device);

  final G1Side side;
  final BluetoothDevice device;
  BluetoothCharacteristic? tx;
  StreamSubscription<List<int>>? rxSub;
  StreamSubscription<BluetoothConnectionState>? stateSub;
  bool ready = false;

  /// Requests waiting for a response with the given command byte.
  final Map<int, Completer<G1Response>> pending = {};

  /// Replaces the BLE write in tests.
  Future<void> Function(Uint8List data)? writeOverride;
}

/// Connection to both arms of a G1 and the request/response handling.
class G1Connection extends ChangeNotifier {
  G1Connection();

  /// Connection with simulated arms for tests: [write] receives every packet
  /// and [receive] feeds data as if it came from the glasses.
  @visibleForTesting
  G1Connection.fake(Future<void> Function(G1Side side, Uint8List data) write) {
    for (final side in G1Side.values) {
      final arm =
          _Arm(side, BluetoothDevice.fromId('00:00:00:00:00:0${side.index}'))
            ..ready = true
            ..writeOverride = (data) => write(side, data);
      if (side == G1Side.left) {
        _left = arm;
      } else {
        _right = arm;
      }
    }
    // The fake glasses do not answer text packets unless a test enables it.
    _leftAcks = false;
  }

  @visibleForTesting
  void receive(G1Side side, Uint8List data) => _onData(_armOrNull(side)!, data);

  _Arm? _left;
  _Arm? _right;
  bool _wanted = false;
  Timer? _heartbeat;
  Timer? _batteryTimer;
  Timer? _reconnectTimer;
  int _heartbeatSeq = 0;
  int _textSeq = 0;

  /// All writes go through one queue, so commands never interleave and both
  /// arms always receive the same packets in the same order (like MentraOS).
  Future<void> _queue = Future.value();

  final _events = StreamController<G1TouchEvent>.broadcast();
  final _audio = StreamController<Uint8List>.broadcast();
  final _log = StreamController<String>.broadcast();

  int? batteryLeft;
  int? batteryRight;
  int? batteryCase;

  /// Firmware version of each arm ("1.6.6"), null until it answered.
  String? firmwareLeft;
  String? firmwareRight;

  /// Firmware version of the glasses for the app, e.g. "Even 1.6.6", or
  /// both when the arms differ; null while unknown.
  String? get firmwareVersion {
    final l = firmwareLeft, r = firmwareRight;
    if (l == null && r == null) return null;
    if (l == r || r == null) return 'Even $l';
    if (l == null) return 'Even $r';
    return 'Even L $l, R $r';
  }

  /// Brightness currently applied by the glasses in percent (pushed with
  /// 0xF5 0x12, also while the automatic brightness changes it).
  int? brightnessPercent;
  bool? caseCharging;
  String? wearState;

  /// Touch bar and other events (0xF5).
  Stream<G1TouchEvent> get events => _events.stream;

  /// LC3 audio from the right arm microphone (200 bytes per packet).
  Stream<Uint8List> get audio => _audio.stream;

  Stream<String> get log => _log.stream;

  bool get connected => (_left?.ready ?? false) && (_right?.ready ?? false);

  String get status {
    if (connected) return 'verbunden';
    if (!_wanted) return 'getrennt';
    final l = _left?.ready ?? false;
    final r = _right?.ready ?? false;
    if (l || r) return 'verbinde (${l ? 'L' : 'R'} bereit)…';
    return 'verbinde…';
  }

  void _debug(String message) {
    debugPrint('[G1] $message');
    _log.add(message);
  }

  /// For other firmwares (subclasses): a touch or status event.
  @protected
  void emitEvent(G1TouchEvent event) => _events.add(event);

  /// For other firmwares (subclasses): LC3 audio, a multiple of 20 bytes.
  @protected
  void emitAudio(Uint8List lc3) => _audio.add(lc3);

  /// True for Even's firmware; false for g1v0 (ScouterKit), which has no
  /// Even dashboard, notification view or Even AI screen.
  bool get evenFirmware => true;

  /// Name of the firmware the app talks to, for the app.
  String get firmwareName => 'Even';

  // ---------------------------------------------------------------------------
  // Scanning
  // ---------------------------------------------------------------------------

  /// Scans for G1 glasses. Emits the list of found pairs.
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
          final parsed = G1Name.parse(name);
          if (parsed == null) continue;
          final pair = pairs.putIfAbsent(
            parsed.channel,
            () => G1Pair(parsed.channel),
          );
          final id = r.device.remoteId.str;
          if (parsed.side == G1Side.left && pair.leftId != id) {
            pair
              ..leftId = id
              ..leftName = name;
            changed = true;
          } else if (parsed.side == G1Side.right && pair.rightId != id) {
            pair
              ..rightId = id
              ..rightName = name;
            changed = true;
          }
        }
        if (changed) controller.add(pairs.values.toList());
      });
      try {
        await FlutterBluePlus.startScan(
          timeout: timeout,
          // BLUETOOTH_SCAN is declared with neverForLocation.
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

  Future<void> connect(String leftId, String rightId) async {
    await disconnect();
    _wanted = true;
    _left = _Arm(G1Side.left, BluetoothDevice.fromId(leftId));
    _right = _Arm(G1Side.right, BluetoothDevice.fromId(rightId));
    notifyListeners();
    await Future.wait([_connectArm(_left!), _connectArm(_right!)]);
  }

  Future<void> disconnect() async {
    _wanted = false;
    _heartbeat?.cancel();
    _batteryTimer?.cancel();
    _reconnectTimer?.cancel();
    for (final arm in [_left, _right]) {
      if (arm == null) continue;
      await arm.stateSub?.cancel();
      await arm.rxSub?.cancel();
      arm.ready = false;
      _failPending(arm);
      try {
        await arm.device.disconnect();
      } catch (_) {}
    }
    _left = null;
    _right = null;
    notifyListeners();
  }

  Future<void> _connectArm(_Arm arm) async {
    arm.stateSub ??= arm.device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected && arm.ready) {
        _debug('${arm.side.name} arm disconnected');
        arm.ready = false;
        _failPending(arm);
        notifyListeners();
        _scheduleReconnect();
      }
    });

    try {
      _debug('connecting ${arm.side.name} arm (${arm.device.remoteId})');
      await arm.device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 20),
        mtu: null,
      );
      if (Platform.isAndroid) {
        await arm.device.requestMtu(251);
        // Balanced like MentraOS, high only during Assist (see
        // setFastConnection).
        await arm.device.requestConnectionPriority(
          connectionPriorityRequest: _fast
              ? ConnectionPriority.high
              : ConnectionPriority.balanced,
        );
      }
      final services = await arm.device.discoverServices();
      final service = services.firstWhere((s) => s.uuid == G1Uuids.service);
      final rx = service.characteristics.firstWhere(
        (c) => c.uuid == G1Uuids.rx,
      );
      arm.tx = service.characteristics.firstWhere((c) => c.uuid == G1Uuids.tx);
      await arm.rxSub?.cancel();
      arm.rxSub = rx.onValueReceived.listen(
        (value) => _onData(arm, Uint8List.fromList(value)),
      );
      await rx.setNotifyValue(true);
      if (Platform.isAndroid) {
        // The official app bonds both arms, the glasses expect it.
        try {
          final bond = await arm.device.bondState.first;
          if (bond != BluetoothBondState.bonded) {
            await arm.device.createBond(timeout: 30);
          }
        } catch (e) {
          _debug('bonding ${arm.side.name} arm: $e');
        }
      }
      arm.ready = true;
      _debug('${arm.side.name} arm ready');
      notifyListeners();
      if (connected) _onBothConnected();
    } catch (e) {
      _debug('connecting ${arm.side.name} arm failed: $e');
      arm.ready = false;
      notifyListeners();
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_wanted || _reconnectTimer?.isActive == true) return;
    _heartbeat?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () async {
      for (final arm in [_left, _right]) {
        if (arm != null && !arm.ready && _wanted) await _connectArm(arm);
      }
    });
  }

  void _onBothConnected() {
    // Same start sequence as the official app / MentraOS.
    unawaited(send([G1Packets.init()]));
    unawaited(send([G1Packets.initDisplay()]));
    unawaited(send([G1Packets.firmwareInfo()]));
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(
      const Duration(seconds: 8),
      (_) => sendHeartbeat(),
    );
    _batteryTimer?.cancel();
    _batteryTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => refreshBattery(),
    );
    refreshBattery();
  }

  void _failPending(_Arm arm) {
    for (final c in arm.pending.values) {
      if (!c.isCompleted) c.completeError(G1TimeoutException(arm.side, -1));
    }
    arm.pending.clear();
  }

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------

  void _onData(_Arm arm, Uint8List data) {
    if (data.isEmpty) return;
    final cmd = data[0];
    if (cmd == G1Cmd.firmwareInfoReply) {
      final version = G1Packets.firmwareVersion(data);
      if (version != null) {
        final old = arm.side == G1Side.left ? firmwareLeft : firmwareRight;
        if (arm.side == G1Side.left) {
          firmwareLeft = version;
        } else {
          firmwareRight = version;
        }
        if (old != version) {
          _debug('${arm.side.code}: Firmware $version');
          notifyListeners();
        }
      }
      return;
    }
    if (cmd == G1Cmd.micData) {
      // [0xF1, seq, 200 bytes LC3]
      if (data.length > 2) _audio.add(Uint8List.sublistView(data, 2));
      return;
    }
    if (cmd == G1Cmd.event && data.length > 1) {
      final code = data[1];
      if (G1Event.statusEvents.contains(code)) {
        _onStatus(arm.side, code, data);
      } else {
        _debug('event ${arm.side.code} 0x${code.toRadixString(16)}');
      }
      _events.add(G1TouchEvent(arm.side, code, data));
      return;
    }
    if (data.length > 1 && data[1] == G1Status.failure) {
      // Makes left/right differences visible in the app log.
      _debug('${arm.side.code} rejected 0x${cmd.toRadixString(16)}');
    }
    final completer = arm.pending.remove(cmd);
    if (completer != null && !completer.isCompleted) {
      completer.complete(G1Response(arm.side, data));
    } else if (cmd != G1Cmd.heartbeat &&
        !(data.length > 1 &&
            (data[1] == G1Status.success || data[1] == G1Status.failure))) {
      // Unsolicited packets (e.g. 0x22 status) for the diagnostics log;
      // plain acknowledgements are left out.
      final bytes = data
          .take(8)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      _debug('${arm.side.code} rx $bytes');
    }
  }

  /// Battery, case and wear status pushed by the glasses.
  void _onStatus(G1Side side, int code, Uint8List data) {
    final value = data.length > 2 ? data[2] : null;
    var changed = false;
    void set<T>(T current, T next, void Function(T) assign) {
      if (current != next) {
        assign(next);
        changed = true;
      }
    }

    switch (code) {
      case G1Event.glassesBattery when value != null && value <= 100:
        if (side == G1Side.left) {
          set(batteryLeft, value, (v) => batteryLeft = v);
        } else {
          set(batteryRight, value, (v) => batteryRight = v);
        }
      case G1Event.caseBattery when value != null && value <= 100:
        set(batteryCase, value, (v) => batteryCase = v);
      case G1Event.brightness when value != null:
        set(
          brightnessPercent,
          G1Packets.brightnessPercent(value),
          (v) => brightnessPercent = v,
        );
      case G1Event.caseCharging when value != null:
        set(caseCharging, value == 1, (v) => caseCharging = v);
      default:
        final state = wearStateName(code);
        if (state != null) {
          set(wearState, state, (v) => wearState = v);
          if (changed) _debug('Zustand: $state');
        }
    }
    if (changed) notifyListeners();
  }

  Future<void> _write(_Arm arm, Uint8List data) async {
    final override = arm.writeOverride;
    if (override != null) return override(data);
    final tx = arm.tx;
    if (tx == null || !arm.ready) {
      throw StateError('${arm.side.name} arm not connected');
    }
    // Write with response: completes when the arm received the packet.
    await tx.write(data, withoutResponse: false, timeout: 3);
  }

  _Arm? _armOrNull(G1Side side) => side == G1Side.left ? _left : _right;

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// Sends packets to the selected arms. Each packet is written to both arms
  /// at the same time and the next packet follows once both received it.
  ///
  /// The glasses' answers are not awaited: waiting for one arm before
  /// writing to the other made both arms show different content when one
  /// arm was busy (e.g. streaming the microphone).
  ///
  /// With [ackLeft] the reply of the left arm (slave) is awaited for every
  /// packet, and the packet is sent to the left arm again if it is missing
  /// or negative. The left arm answers each 0x4E packet right away
  /// (even-g1-companion firmware analysis), the right arm (master) only
  /// later; the official app also waits for these replies.
  Future<bool> send(
    List<Uint8List> packets, {
    bool left = true,
    bool right = true,
    Duration waitAfter = Duration.zero,
    bool ackLeft = false,
  }) {
    return _enqueue(() async {
      var ok = true;
      for (final packet in packets) {
        final leftArm = _left;
        final waitForLeft =
            ackLeft && left && leftArm != null && _leftAcks != false;
        Completer<G1Response>? ack;
        if (waitForLeft) {
          ack = Completer<G1Response>();
          leftArm.pending[packet[0]] = ack;
        }
        final writes = <Future<void>>[
          if (right && _right != null) _write(_right!, packet),
          if (left && _left != null) _write(_left!, packet),
        ];
        final results = await Future.wait(
          writes.map(
            (w) => w.then(
              (_) => true,
              onError: (Object e) {
                _debug('write 0x${packet[0].toRadixString(16)} failed: $e');
                return false;
              },
            ),
          ),
        );
        ok = ok && results.isNotEmpty && results.every((r) => r);
        if (waitForLeft) {
          ok = await _awaitLeftAck(leftArm, packet, ack!) && ok;
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      if (waitAfter > Duration.zero) await Future<void>.delayed(waitAfter);
      return ok;
    });
  }

  /// Whether the left arm answers text packets: null = not known yet,
  /// false = it never did (then the app stops waiting for it).
  bool? _leftAcks;
  int _leftAckMisses = 0;

  /// Tests: the fake glasses do not answer unless a test says so.
  @visibleForTesting
  set leftAcks(bool? value) => _leftAcks = value;
  static const leftAckTimeout = Duration(milliseconds: 300);
  static const leftAckRetries = 2;

  Future<bool> _awaitLeftAck(
    _Arm arm,
    Uint8List packet,
    Completer<G1Response> first,
  ) async {
    final cmd = packet[0];
    var ack = first;
    for (var attempt = 0; ; attempt++) {
      G1Response? reply;
      try {
        reply = await ack.future.timeout(leftAckTimeout);
      } catch (_) {
        // Timeout, or the arm disconnected meanwhile.
        reply = null;
      } finally {
        if (arm.pending[cmd] == ack) arm.pending.remove(cmd);
      }
      final good =
          reply != null &&
          reply.data.length > 1 &&
          reply.data[1] != G1Status.failure;
      if (good) {
        _leftAcks = true;
        _leftAckMisses = 0;
        return true;
      }
      if (reply == null && _leftAcks == null && ++_leftAckMisses >= 3) {
        // This firmware does not answer: do not slow every text down.
        _leftAcks = false;
        _debug('L bestätigt Texte nicht – Prüfung aus');
        return true;
      }
      if (attempt >= leftAckRetries || !arm.ready) {
        _debug('L: Text nicht bestätigt');
        return false;
      }
      _debug(
        'L: Text ${reply == null ? 'unbeantwortet' : 'abgelehnt'} – '
        'erneut gesendet',
      );
      ack = Completer<G1Response>();
      arm.pending[cmd] = ack;
      try {
        await _write(arm, packet);
      } catch (e) {
        _debug('write 0x${cmd.toRadixString(16)} L failed: $e');
      }
    }
  }

  /// Sends [data] to one arm and waits for the response with the same
  /// command byte (only used where the answer carries data).
  Future<G1Response> request(
    G1Side side,
    Uint8List data, {
    Duration timeout = const Duration(milliseconds: 1500),
  }) async {
    final arm = _armOrNull(side);
    if (arm == null) throw StateError('Glasses not connected');
    final cmd = data[0];
    final completer = Completer<G1Response>();
    arm.pending[cmd] = completer;
    try {
      await send(
        [data],
        left: side == G1Side.left,
        right: side == G1Side.right,
      );
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      throw G1TimeoutException(side, cmd);
    } finally {
      if (arm.pending[cmd] == completer) arm.pending.remove(cmd);
    }
  }

  // ---------------------------------------------------------------------------
  // Commands
  // ---------------------------------------------------------------------------

  Future<bool> sendHeartbeat() async {
    if (!connected) return false;
    return send([G1Packets.heartbeat(_heartbeatSeq++)]);
  }

  Future<void> refreshBattery() async {
    for (final side in G1Side.values) {
      try {
        final r = await request(side, G1Packets.battery());
        if (r.data.length > 2 && r.data[2] <= 100) {
          if (side == G1Side.left) {
            batteryLeft = r.data[2];
          } else {
            batteryRight = r.data[2];
          }
        }
      } catch (e) {
        _debug('battery ${side.name}: $e');
      }
    }
    notifyListeners();
  }

  /// Enables or disables the microphone (right arm). Like MentraOS, the next
  /// command waits a moment so the microphone can start.
  /// Switches the microphone (right arm).
  Future<bool> setMic(bool enable) => send(
    [G1Packets.micEnable(enable)],
    left: false,
    waitAfter: Duration(milliseconds: enable ? 300 : 0),
  );

  bool _fast = false;

  /// Connection priority of both arms: balanced normally (like MentraOS;
  /// "high" wakes the radios every 11-15 ms instead of 30-50 ms and costs a
  /// lot of battery), high while Assist listens, works and shows its answer
  /// so both arms get the texts quickly and at the same time.
  Future<void> setFastConnection(bool fast) async {
    if (fast == _fast || !Platform.isAndroid) return;
    _fast = fast;
    _debug(fast ? 'Verbindung: schnell' : 'Verbindung: sparsam');
    for (final arm in [_right, _left]) {
      if (arm == null || !arm.ready || arm.writeOverride != null) continue;
      try {
        await arm.device.requestConnectionPriority(
          connectionPriorityRequest: fast
              ? ConnectionPriority.high
              : ConnectionPriority.balanced,
        );
      } catch (e) {
        _debug('connection priority ${arm.side.name}: $e');
      }
    }
  }

  /// Shows one screen of text on both arms (0x4E, text mode 0x71).
  Future<bool> sendText(
    String text, {
    int status = G1ScreenStatus.textShow | G1ScreenStatus.newContent,
    int page = 0,
    int pages = 1,
    bool left = true,
    bool right = true,
  }) {
    return send(
      G1Packets.text(
        text,
        seq: _textSeq++,
        status: status,
        page: page,
        pages: pages,
      ),
      left: left,
      right: right,
      ackLeft: true,
    );
  }

  /// Empties the display with a blank text, like MentraOS.
  ///
  /// The exit command 0x18 leaves the Even AI surface that 0x4E texts use;
  /// its teardown races in the firmware and sometimes flashes "Even AI is
  /// listening" on the right lens (even-g1-companion,
  /// FINDINGS-evenai-flash-on-clear.md). A blank text has nothing to tear
  /// down.
  Future<bool> blankScreen() => sendText(' ');

  /// Writes a line to the app log (diagnostics).
  void note(String message) => _debug(message);

  /// Which screen the given arm currently shows (0x39), or null.
  Future<int?> readScreenState(G1Side side) async {
    try {
      final r = await request(side, G1Packets.screenState());
      if (r.data.length < 6 || r.data[5] == 0xff) return null;
      return r.data[5];
    } catch (e) {
      _debug('screen state ${side.name}: $e');
      return null;
    }
  }

  /// Brightness in percent and auto mode as set on the glasses, null if the
  /// glasses do not answer.
  Future<({int percent, bool auto})?> readBrightness() async {
    try {
      final r = await request(G1Side.right, G1Packets.brightnessQuery());
      if (r.data.length < 4 || r.data[1] == G1Status.failure) return null;
      return (
        percent: G1Packets.brightnessPercent(r.data[2]),
        auto: r.data[3] == 0x01,
      );
    } catch (e) {
      _debug('brightness: $e');
      return null;
    }
  }

  /// Wear detection setting of the glasses, null if they do not answer.
  Future<bool?> readWearDetection() async {
    try {
      final r = await request(G1Side.right, G1Packets.wearDetectionQuery());
      if (r.data.length < 3 || r.data[1] != G1Status.success) return null;
      return r.data[2] == 0x01;
    } catch (e) {
      _debug('wear detection: $e');
      return null;
    }
  }

  /// Raw brightness level (0–42) currently used by the glasses. With
  /// automatic brightness this is the level chosen from the light sensor.
  Future<int?> readBrightnessLevel() async {
    try {
      final r = await request(G1Side.right, G1Packets.brightnessQuery());
      if (r.data.length < 3 || r.data[1] == G1Status.failure) return null;
      return r.data[2].clamp(0, G1Packets.maxBrightness);
    } catch (e) {
      _debug('brightness: $e');
      return null;
    }
  }

  /// Sends a setting to both arms (like MentraOS, with a short pause).
  Future<bool> sendSetting(Uint8List packet) =>
      send([packet], waitAfter: const Duration(milliseconds: 100));

  // Settings by name, so other firmwares can implement them their own way.

  Future<bool> setBrightness(int percent, {required bool auto}) =>
      sendSetting(G1Packets.brightness(percent, auto: auto));

  /// Brightness as a raw level (0–42).
  Future<bool> setBrightnessLevel(int level, {required bool auto}) =>
      sendSetting(G1Packets.brightnessLevel(level, auto: auto));

  Future<bool> setWearDetection(bool enabled) =>
      sendSetting(G1Packets.wearDetection(enabled));

  Future<bool> setSilentMode(bool enabled) =>
      sendSetting(G1Packets.silentMode(enabled));

  Future<bool> setHeadUpAngle(int angle) =>
      sendSetting(G1Packets.headUpAngle(angle));

  Future<bool> setHeadUpMode(int mode) =>
      sendSetting(G1Packets.headUpMode(mode));

  Future<bool> setDisplayPosition(
    int height,
    int depth,
    int counter, {
    bool preview = false,
  }) => sendSetting(
    G1Packets.dashboardPosition(height, depth, counter, preview: preview),
  );

  /// Returns the glasses to the dashboard.
  Future<bool> exitToDashboard() => send([G1Packets.exit()]);

  Future<bool> sendWhitelist(Map<String, String> apps) => send(
    G1Packets.whitelist(apps),
    right: false,
    waitAfter: const Duration(milliseconds: 100),
  );

  Future<bool> sendNotification(List<Uint8List> packets) =>
      send(packets, right: false);

  @override
  void dispose() {
    disconnect();
    _events.close();
    _audio.close();
    _log.close();
    super.dispose();
  }
}
