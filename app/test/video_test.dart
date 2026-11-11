import 'dart:typed_data';

import 'package:even_g1_ha/g1/protocol.dart';
import 'package:even_g1_ha/scouter/scouter_connection.dart';
import 'package:even_g1_ha/scouter/sk_program.dart';
import 'package:even_g1_ha/scouter/sk_protocol.dart';
import 'package:even_g1_ha/scouter/sk_video.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scouter_test.dart' show FakeArms, loadTestFont;

/// A small test picture: a square moving down to the right and diagonal
/// lines (frame [k], 1 bit per pixel).
Uint8List frame(SkVideoEncoder e, int k) {
  final out = Uint8List(e.stride * e.height);
  for (var y = 0; y < e.height; y++) {
    for (var x = 0; x < e.width; x++) {
      final square =
          x - (2 + 3 * k) >= 0 &&
          x - (2 + 3 * k) < 10 &&
          y - (4 + k) >= 0 &&
          y - (4 + k) < 10;
      final line = (x + y + k) % 13 == 0 && y < 20;
      if (square || line) out[y * e.stride + (x >> 3)] |= 0x80 >> (x & 7);
    }
  }
  return out;
}

String hex(List<int> b) =>
    b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();

void main() {
  test('records are the same as ScouterKit\'s VideoEncoder', () {
    // Made by ScouterKit's C++ VideoEncoder from the same frames.
    const want = [
      '03449d7136b6bad30224dd612760ac648f75fb1dea8b2d7007412dc4f7f9b91fb06c0a1c723aa3',
      '004fb0bd164df0f79e225c55cabfe2e833f7cb1cac110e02106157102abe2fdf2695bb97deca59b8',
      '0050518a95c6f7d585025e1d00fdf5dbb7d10ae4f333a5c4',
      '005087f05371a1e65d6500c92a5bd25141bcdd1a402f3620',
      '00507351403c72f0368e6acf0fdcce686bd05ac853c3c6',
      '00500f62a2096f2c1675492cfc43f22605',
    ];
    final e = SkVideoEncoder(40, 24);
    for (var k = 0; k < want.length; k++) {
      expect(hex(e.encode(frame(e, k), redraw: k == 0)!), want[k]);
    }
  });

  test('a record over the limit is not made, the encoder stays', () {
    final e = SkVideoEncoder(40, 24);
    expect(e.encode(frame(e, 0), maxBytes: 4), isNull);
    // Still the first record: reset flag set.
    expect(e.encode(frame(e, 0))!.first & 1, 1);
  });

  test('a frame goes as writes, then SLEEP_UNTIL and VIDEO', () {
    final layout = SkVideoLayout(480, 360);
    expect(layout.stride, 60);
    expect((layout.x, layout.y), (80, 60));
    expect(layout.record + SkVideoLayout.recordMax, lessThan(0x35800));
    final record = Uint8List.fromList(List.generate(700, (i) => i & 0xff));
    final packets = layout.frameCode(record, 123, maxCode: 240);
    expect(packets.length, greaterThan(2));
    for (final p in packets) {
      expect(p.length, lessThanOrEqualTo(240));
    }
    expect(packets.last.contains(SkOp.video), isTrue);
    expect(SkVideoLayout.fit(1144, 756, 480, 360), (480, 317));
  });

  test('the video plays on both arms at the same moments', () async {
    final arms = FakeArms();
    final g1 = ScouterConnection.fake(arms.write, font: loadTestFont());
    arms.connection = g1;
    g1.fakeReady(epoch: arms.epoch);
    await g1.fakeSyncClocks();
    final e = SkVideoEncoder(40, 24);
    var started = 0;
    final end = await g1.playVideo(
      width: 40,
      height: 24,
      fps: 50,
      frames: 6,
      read: (start, count) async => Uint8List.fromList([
        for (var k = start; k < start + count; k++) ...frame(e, k),
      ]),
      onStart: () => started++,
    );
    expect(end, SkVideoEnd.done);
    expect(started, 1);
    expect(g1.videoPlaying, isFalse);
    for (final side in G1Side.values) {
      expect(arms.ops[side]!.where((o) => o == SkOp.video), hasLength(6));
      // Afterwards the program may draw again and the panel is off.
      expect(arms.arenas[side]![SkResident.busy.address], 0);
    }
    // Frame times 20 ms apart, the same host time on both arms.
    final left = arms.sleeps[G1Side.left]!;
    final right = arms.sleeps[G1Side.right]!;
    expect(left, hasLength(6));
    final offset =
        arms.clockOffset[G1Side.right]! - arms.clockOffset[G1Side.left]!;
    for (var k = 0; k < 6; k++) {
      expect(
        ((right[k] - left[k] - offset) & 0xffffffff).toSigned(32).abs(),
        lessThan(2000),
      );
      if (k > 0) {
        expect(((left[k] - left[k - 1]) & 0xffffffff), 20000);
      }
    }
    g1.dispose();
  });

  test('texts wait while a video plays', () async {
    final arms = FakeArms();
    final g1 = ScouterConnection.fake(arms.write, font: loadTestFont());
    arms.connection = g1;
    g1.fakeReady(epoch: arms.epoch);
    await g1.fakeSyncClocks();
    final e = SkVideoEncoder(40, 24);
    var stop = false;
    final playing = g1.playVideo(
      width: 40,
      height: 24,
      fps: 25,
      frames: 100,
      read: (start, count) async => Uint8List.fromList([
        for (var k = start; k < start + count; k++) ...frame(e, k % 6),
      ]),
      stopped: () => stop,
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(g1.videoPlaying, isTrue);
    final before = arms.ops[G1Side.left]!.where((o) => o == SkOp.glyphs);
    expect(await g1.sendText('Hello'), isTrue);
    expect(
      arms.ops[G1Side.left]!.where((o) => o == SkOp.glyphs).length,
      before.length,
    );
    stop = true;
    expect(await playing, SkVideoEnd.stopped);
    g1.dispose();
  });
}
