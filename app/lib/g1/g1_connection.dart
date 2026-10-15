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

  /// Serializes requests: the glasses answer with the command byte only, so
  /// only one request per command and arm may be in flight.
  Future<void> _lock = Future.value();
  final Map<int, Completer<G1Response>> pending = {};

  Future<T> locked<T>(Future<T> Function() action) {
    final result = _lock.then((_) => action());
    _lock = result.then((_) {}, onError: (_) {});
    return result;
  }
}

/// Connection to both arms of a G1 and the request/response handling.
class G1Connection extends ChangeNotifier {
  G1Connection();

  _Arm? _left;
  _Arm? _right;
  bool _wanted = false;
  Timer? _heartbeat;
  Timer? _batteryTimer;
  Timer? _reconnectTimer;
  int _heartbeatSeq = 0;
  int _textSeq = 0;

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
        await FlutterBluePlus.startScan(timeout: timeout);
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
      await _write(arm, G1Packets.init());
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
    final completer = arm.pending.remove(cmd);
    if (completer != null && !completer.isCompleted) {
      completer.complete(G1Response(arm.side, data));
    }
  }

  Future<void> _write(_Arm arm, Uint8List data) async {
    final tx = arm.tx;
    if (tx == null || !arm.ready) {
      throw StateError('${arm.side.name} arm not connected');
    }
    await tx.write(data, withoutResponse: true);
  }

  _Arm _arm(G1Side side) {
    final arm = side == G1Side.left ? _left : _right;
    if (arm == null) throw StateError('Glasses not connected');
    return arm;
  }

  /// Sends [data] to one arm and waits for the response with the same command.
  Future<G1Response> request(
    G1Side side,
    Uint8List data, {
    Duration timeout = const Duration(milliseconds: 1500),
  }) {
    final arm = _arm(side);
    final cmd = data[0];
    return arm.locked(() async {
      final completer = Completer<G1Response>();
      arm.pending[cmd] = completer;
      try {
        await _write(arm, data);
        return await completer.future.timeout(timeout);
      } on TimeoutException {
        throw G1TimeoutException(side, cmd);
      } finally {
        if (arm.pending[cmd] == completer) arm.pending.remove(cmd);
      }
    });
  }

  /// Sends a list of packets to one arm, each one must be acknowledged.
  Future<bool> requestList(
    G1Side side,
    List<Uint8List> packets, {
    Duration timeout = const Duration(milliseconds: 1500),
  }) async {
    for (final packet in packets) {
      final response = await request(side, packet, timeout: timeout);
      if (!response.ok) return false;
    }
    return true;
  }

  /// Sends packets to the left arm, then (after its ack) to the right arm.
  Future<bool> sendBoth(
    List<Uint8List> packets, {
    Duration timeout = const Duration(milliseconds: 1500),
    int retries = 2,
  }) async {
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        if (await requestList(G1Side.left, packets, timeout: timeout) &&
            await requestList(G1Side.right, packets, timeout: timeout)) {
          return true;
        }
      } on G1TimeoutException catch (e) {
        _debug('$e (attempt ${attempt + 1})');
      }
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Commands
  // ---------------------------------------------------------------------------

  Future<bool> sendHeartbeat() async {
    if (!connected) return false;
    final packet = G1Packets.heartbeat(_heartbeatSeq++);
    try {
      await request(G1Side.left, packet);
      await request(G1Side.right, packet);
      return true;
    } catch (e) {
      _debug('heartbeat failed: $e');
      return false;
    }
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

  /// Enables or disables the microphone (right arm).
  Future<bool> setMic(bool enable) async {
    try {
      final r = await request(G1Side.right, G1Packets.micEnable(enable));
      return r.status == G1Status.success;
    } catch (e) {
      _debug('mic ${enable ? 'on' : 'off'} failed: $e');
      return false;
    }
  }

  /// Sends one screen of text (0x4E).
  Future<bool> sendText(
    String text, {
    required int newScreen,
    required int currentPage,
    required int maxPage,
  }) {
    final packets = G1Packets.text(
      text,
      seq: _textSeq++,
      newScreen: newScreen,
      currentPage: currentPage,
      maxPage: maxPage,
    );
    return sendBoth(packets, retries: 3);
  }

  /// Returns the glasses to the dashboard.
  Future<bool> exitToDashboard() => sendBoth([G1Packets.exit()]);

  Future<bool> sendWhitelist(Map<String, String> apps) async {
    try {
      return await requestList(G1Side.left, G1Packets.whitelist(apps));
    } catch (e) {
      _debug('whitelist failed: $e');
      return false;
    }
  }

  Future<bool> sendNotification(List<Uint8List> packets) async {
    try {
      return await requestList(G1Side.left, packets);
    } catch (e) {
      _debug('notification failed: $e');
      return false;
    }
  }

  @override
  void dispose() {
    disconnect();
    _events.close();
    _audio.close();
    _log.close();
    super.dispose();
  }
}
