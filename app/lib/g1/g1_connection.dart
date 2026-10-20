import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'protocol.dart';

/// A pair of arms found during a scan.
class G1Pair {
  G1Pair(this.channel);

  final String channel;
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
        await arm.device.requestConnectionPriority(
          connectionPriorityRequest: ConnectionPriority.high,
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
    if (cmd == G1Cmd.micData) {
      // [0xF1, seq, 200 bytes LC3]
      if (data.length > 2) _audio.add(Uint8List.sublistView(data, 2));
      return;
    }
    if (cmd == G1Cmd.event && data.length > 1) {
      _debug('event ${arm.side.code} 0x${data[1].toRadixString(16)}');
      _events.add(G1TouchEvent(arm.side, data[1], data));
      return;
    }
    if (data.length > 1 && data[1] == G1Status.failure) {
      // Makes left/right differences visible in the app log.
      _debug('${arm.side.code} rejected 0x${cmd.toRadixString(16)}');
    }
    final completer = arm.pending.remove(cmd);
    if (completer != null && !completer.isCompleted) {
      completer.complete(G1Response(arm.side, data));
    }
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
  Future<bool> send(
    List<Uint8List> packets, {
    bool left = true,
    bool right = true,
    Duration waitAfter = Duration.zero,
  }) {
    return _enqueue(() async {
      var ok = true;
      for (final packet in packets) {
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
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      if (waitAfter > Duration.zero) await Future<void>.delayed(waitAfter);
      return ok;
    });
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
  Future<bool> setMic(bool enable) => send(
    [G1Packets.micEnable(enable)],
    left: false,
    waitAfter: Duration(milliseconds: enable ? 300 : 0),
  );

  /// Shows one screen of text on both arms (0x4E, text mode 0x71).
  Future<bool> sendText(String text) {
    return send(G1Packets.text(text, seq: _textSeq++));
  }

  /// Sends a setting to both arms (like MentraOS, with a short pause).
  Future<bool> sendSetting(Uint8List packet) =>
      send([packet], waitAfter: const Duration(milliseconds: 100));

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
