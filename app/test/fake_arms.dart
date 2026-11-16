/// Simulated ScouterKit arms for tests: they run the app's host code on
/// their arenas and answer control requests like g1v0 0.5.60.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:even_g1_ha/g1/protocol.dart';
import 'package:even_g1_ha/scouter/scouter_connection.dart';
import 'package:even_g1_ha/scouter/sk_assets.dart';
import 'package:even_g1_ha/scouter/sk_clock.dart';
import 'package:even_g1_ha/scouter/sk_font.dart';
import 'package:even_g1_ha/scouter/sk_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

SkFont loadTestFont() =>
    SkFont.parse(File(ScouterConnection.fontAsset).readAsBytesSync())
        .scaled(2, keep: SkFont.textCodepoint);

/// An event as an arm sends it: type, epoch, device time, fields.
Uint8List event(int type, int epoch, List<int> fields) {
  final b = BytesBuilder()
    ..addByte(type)
    ..add(u32(epoch))
    ..add(u32(0))
    ..add(fields);
  return b.takeBytes();
}

List<int> u16(int v) => [v & 0xff, (v >> 8) & 0xff];
List<int> u32(int v) => [
  v & 0xff,
  (v >> 8) & 0xff,
  (v >> 16) & 0xff,
  (v >> 24) & 0xff,
];

Uint8List ack(int epoch, int rxNext, int execNext, {int credits = 32}) => event(
  SkEvt.ack,
  epoch,
  [...u16(rxNext), ...u16(execNext), credits, ...u32(0)],
);

Uint8List input(int epoch, int trigger, int value) =>
    event(SkEvt.input, epoch, [...u16(1), trigger, ...u32(value)]);

Uint8List reply(int epoch, int op, int tag, int status, List<int> body) =>
    event(0x80 | op, epoch, [tag, status, ...body]);

List<int> helloBody({
  required bool left,
  int rxNext = 0,
  int flags = 0x02 | 0x40,
  int board = 0x04,
}) => [
  5, 0, 5, 60, // protocol 5, firmware 0.5.60
  left ? 1 : 0,
  flags,
  board,
  ...u16(0x01ff),
  ...u16(640),
  ...u16(480),
  ...u32(262144),
  32,
  ...u16(244),
  ...u16(rxNext),
  ...u16(rxNext),
  32,
  ...u32(1),
  ...u32(0),
  0,
  0,
];

/// Runs the WRITE and WRITE_RLE instructions of host code on [arena];
/// other instructions are collected in [ops], the times of `SLEEP_UNTIL` in
/// [sleeps].
void execute(
  Uint8List code,
  Uint8List arena,
  List<int> ops, [
  List<int>? sleeps,
  Map<String, Uint8List>? store,
]) {
  var i = 0;
  int u24(int at) => code[at] | code[at + 1] << 8 | code[at + 2] << 16;
  while (i < code.length) {
    final op = code[i];
    if (op == SkOp.write) {
      final addr = u24(i + 1);
      final n = code[i + 4];
      arena.setRange(addr, addr + n, code.sublist(i + 5, i + 5 + n));
      i += 5 + n;
    } else if (op == SkOp.writeRle) {
      final addr = u24(i + 1);
      final len = code[i + 4] | code[i + 5] << 8;
      final n = code[i + 6];
      final data = unpackBits(code.sublist(i + 7, i + 7 + n));
      expect(data.length, len);
      arena.setRange(addr, addr + len, data);
      i += 7 + n;
    } else if (op == SkOp.call) {
      ops.add(op);
      i += 4;
    } else {
      if (op == SkOp.assetLoad) {
        // id, dst, off, n from the scratch words; copies the stored asset.
        final d = ByteData.sublistView(arena);
        int word(int k) => d.getUint32(
          (code[i + 3 + 2 * k] | code[i + 4 + 2 * k] << 8) * 4,
          Endian.little,
        );
        final id = SkAssets.hex(arena.sublist(word(0), word(0) + 16));
        final body = store?[id];
        if (body == null) throw StateError('asset $id not stored');
        final dst = word(1), off = word(2), n = word(3);
        arena.setRange(dst, dst + n, body.sublist(off, off + n));
      }
      if (op == SkOp.sleepUntil) {
        // One escaped operand: the word that holds the time.
        final word = code[i + 2] | code[i + 3] << 8;
        sleeps?.add(
          ByteData.sublistView(arena).getUint32(word * 4, Endian.little),
        );
      }
      final k = switch (op) {
        SkOp.sleepUntil => 1,
        SkOp.raise => 1,
        SkOp.add => 3,
        SkOp.sysRead => 2,
        SkOp.sysWrite => 2,
        SkOp.fill => 7,
        SkOp.blit => 12,
        SkOp.glyphs => 9,
        SkOp.draw => 8,
        SkOp.line => 7,
        SkOp.video => 10,
        SkOp.assetLoad => 4,
        _ => throw StateError('op 0x${op.toRadixString(16)}'),
      };
      ops.add(op);
      i += 1 + (k + 1) ~/ 2 + 2 * k;
    }
  }
}

/// Simulated g1v0 arms: answer control requests, ack and run packets.
class FakeArms {
  FakeArms({this.epoch = 7});

  final int epoch;
  late ScouterConnection connection;
  final arenas = {for (final s in G1Side.values) s: Uint8List(SkArena.size)};
  final ops = {for (final s in G1Side.values) s: <int>[]};
  final ctrl = {for (final s in G1Side.values) s: <Uint8List>[]};
  final props = <int, int>{};
  final sleeps = {for (final s in G1Side.values) s: <int>[]};

  /// Each arm's clock runs this far ahead of the host's (µs).
  final clockOffset = {G1Side.left: 5000000, G1Side.right: 123456789};
  bool answerPing = true;
  int micStatus = 0;
  bool acks = true;

  /// CMD packets received (both arms).
  int writes = 0;

  /// VM_STATUS: the program's state (1 running) and its timer.
  /// A late answer to "microphone on".
  Duration? micOnDelay;

  int vmState = 1;
  bool timerArmed = true;
  int pending = 0;

  /// The asset store (VM.md §6.10), off unless a test turns it on.
  bool storeOn = false;
  final stored = {for (final s in G1Side.values) s: <String, Uint8List>{}};

  Future<void> write(G1Side side, int channel, Uint8List data) async {
    if (channel == 0) {
      writes++;
      final seq = data[0] | data[1] << 8;
      execute(
        Uint8List.sublistView(data, 2),
        arenas[side]!,
        ops[side]!,
        sleeps[side],
        stored[side],
      );
      if (acks) {
        scheduleMicrotask(
          () => connection.receive(side, ack(epoch, seq + 1, seq + 1)),
        );
      }
      return;
    }
    ctrl[side]!.add(data);
    final op = data[0];
    final tag = data[1];
    final left = side == G1Side.left;
    final body = switch (op) {
      SkCtrl.hello => helloBody(left: left),
      SkCtrl.resetSession => [0, 0, ...helloBody(left: left)],
      SkCtrl.events => [data[2], data[3]],
      SkCtrl.props => [
        for (final id in data.sublist(2)) ...u32(props[id] ?? SkProp.unknown),
      ],
      SkCtrl.mic => [data[2], 20, 5, ...u16(16000), 10, ...u16(2000)],
      SkCtrl.assetInfo => [
        ...List.filled(12, 0),
        stored[side]!.length,
        0,
        0,
        storeOn ? 1 : 0,
        ...u32(0),
      ],
      SkCtrl.assetList => [
        stored[side]!.length,
        data[2],
        for (final e in stored[side]!.entries.skip(data[2]).take(7)) ...[
          for (var i = 0; i < 32; i += 2)
            int.parse(e.key.substring(i, i + 2), radix: 16),
          ...u32(0),
          ...u32(e.value.length),
          ...u32(0),
          4,
          0,
          0,
          0,
        ],
      ],
      SkCtrl.vmStatus => [
        vmState,
        0xff,
        pending & 0xff,
        pending >> 8,
        ...List.filled(24, 0),
        timerArmed ? 1 : 0,
        0,
        0,
        0,
      ],
      SkCtrl.assetPut => _put(side, data),
      SkCtrl.assetDelete => _delete(side, data),
      SkCtrl.ping => [
        ...data.sublist(2, 6),
        ...u32(SkClock.hostNow() + clockOffset[side]!),
        ...u32(SkClock.hostNow() + clockOffset[side]!),
      ],
      _ => <int>[],
    };
    if (op == SkCtrl.ping && !answerPing) return;
    final notice = _job.remove(side);
    if (notice != null) {
      scheduleMicrotask(
        () => connection.receive(side, event(SkEvt.notice, epoch, notice)),
      );
    }
    final status = op == SkCtrl.mic ? micStatus : 0;
    void answer() =>
        connection.receive(side, reply(epoch, op, tag, status, body));
    if (op == SkCtrl.mic && data[2] == 1 && micOnDelay != null) {
      // The arm answers a switch-on late (a busy link).
      Future<void>.delayed(micOnDelay!, answer);
    } else {
      scheduleMicrotask(answer);
    }
  }

  /// The NOTICE 8 of the job just started on each arm.
  final _job = <G1Side, List<int>>{};

  List<int> _put(G1Side side, Uint8List data) {
    final id = data.sublist(2, 18);
    final d = ByteData.sublistView(data);
    final address = d.getUint32(18, Endian.little);
    final size = d.getUint32(22, Endian.little);
    final hex = SkAssets.hex(id);
    if (stored[side]!.containsKey(hex)) return [1];
    final body = Uint8List.fromList(
      arenas[side]!.sublist(address, address + size),
    );
    final ok = SkAssets.hex(SkAssets.id(body)) == hex;
    if (ok) stored[side]![hex] = body;
    _job[side] = [8, 1, ok ? 0 : 13, ...id];
    return [0];
  }

  List<int> _delete(G1Side side, Uint8List data) {
    final id = data.sublist(2, 18);
    stored[side]!.remove(SkAssets.hex(id));
    _job[side] = [8, 2, 0, ...id];
    return [];
  }
}
