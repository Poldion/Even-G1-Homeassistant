import 'dart:io';
import 'dart:typed_data';

import 'package:even_g1_ha/g1/display.dart';
import 'package:even_g1_ha/g1/g1_connection.dart';
import 'package:even_g1_ha/g1/protocol.dart';
import 'package:even_g1_ha/scouter/scouter_connection.dart';
import 'package:even_g1_ha/scouter/sk_anim.dart';
import 'package:even_g1_ha/scouter/sk_font.dart';
import 'package:even_g1_ha/scouter/sk_lib.dart';
import 'package:even_g1_ha/scouter/sk_program.dart';
import 'package:even_g1_ha/scouter/sk_protocol.dart';
import 'package:even_g1_ha/scouter/sk_style.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scouter_test.dart' show FakeArms, execute, loadTestFont;

SkFont _font() =>
    SkFont.parse(File(ScouterConnection.fontAsset).readAsBytesSync())
        .scaled(2, keep: SkFont.textCodepoint);

/// Pixels a list of rectangles sets (later ones win).
Map<(int, int), int> _paint(Iterable<SkRect> rects, {int dy = 0}) {
  final px = <(int, int), int>{};
  for (final r in rects) {
    for (var y = r.y; y < r.y + r.h; y++) {
      for (var x = r.x; x < r.x + r.w; x++) {
        px[(x, y + dy)] = r.level;
      }
    }
  }
  return px;
}

void main() {
  final font = _font();
  const text = '14:32 · Fr 7. Nov\nWohnzimmer: 21,5 °C\nHeute 18:00 Training';

  test('styles place the lines, the frame and the rule', () {
    final lines = text.split('\n');
    final plain = SkLayout.of(
      font,
      lines,
      G1TextStyle.plain,
      top: 140,
      left: 24,
    );
    expect(plain.box, isNull);
    expect(plain.lines.map((l) => (l.x, l.y)), [
      (24, 140),
      (24, 140 + font.lineSpacing),
      (24, 140 + 2 * font.lineSpacing),
    ]);
    final card = SkLayout.of(font, lines, G1TextStyle.card, top: 140, left: 24);
    expect(card.box!.y, 128);
    expect(card.lines.first.x, greaterThan(24)); // centred title
    expect(card.lines[1].y, 140 + font.lineSpacing + SkLayout.ruleGap);
    expect(card.rule, isNotNull);
    expect(card.box!.bottom, card.lines.last.y + font.lineSpacing + 8);
    final badge = SkLayout.of(
      font,
      ['Claude', 'hört zu …'],
      G1TextStyle.badge,
      top: 140,
      left: 24,
    );
    expect(badge.box!.x + badge.box!.w / 2, 320);
    expect(badge.box!.w, lessThan(300));
  });

  test('the bands of the arm program draw exactly the whole design', () {
    for (final style in [
      G1TextStyle.card,
      G1TextStyle.frame,
      G1TextStyle.lab,
    ]) {
      final bands = ScouterConnection.dashboardBands(
        font,
        text,
        style,
        top: 140,
        rows: 11,
      );
      final layout = SkLayout.of(
        font,
        text.split('\n'),
        style,
        top: 140,
        left: 24,
      );
      // Bands drawn in order, each clearing its rows first.
      final drawn = <(int, int), int>{};
      for (final b in bands) {
        drawn.removeWhere(
          (k, _) => k.$2 >= b.y && k.$2 < b.y + font.lineSpacing,
        );
        drawn.addAll(_paint(b.rects, dy: b.y));
      }
      drawn.removeWhere((_, level) => level == 0);
      expect(
        drawn,
        _paint(layout.decor)..removeWhere((_, level) => level == 0),
        reason: style.id,
      );
      // Texts come last, in reading order.
      expect(
        bands.where((b) => b.text != null).map((b) => b.text),
        text.split('\n'),
      );
      expect(
        bands.skipWhile((b) => b.text == null).every((b) => b.text != null),
        isTrue,
      );
      expect(bands.length, lessThanOrEqualTo(SkResident.maxEntries));
      expect(
        bands.fold<int>(0, (n, b) => n + b.rects.length),
        lessThanOrEqualTo(SkResident.maxRects),
      );
    }
  });

  test('a styled text calls the library for its frame', () {
    final ops = <int>[];
    final arena = Uint8List(SkArena.size);
    for (final code in ScouterConnection.textCode(
      font,
      text,
      maxCode: 242,
      style: G1TextStyle.card,
    )) {
      expect(code.length, lessThanOrEqualTo(242));
      execute(code, arena, ops);
    }
    // The frame (box) and the rule (rects).
    expect(ops.where((o) => o == SkOp.call), hasLength(2));
    final box = ByteData.sublistView(
      arena,
      SkLib.boxWords,
      SkLib.boxWords + 28,
    );
    expect(box.getUint32(0, Endian.little), SkLayout.frameX);
    // Plain texts do not.
    ops.clear();
    for (final code in ScouterConnection.textCode(font, text, maxCode: 242)) {
      execute(code, arena, ops);
    }
    expect(ops, isNot(contains(SkOp.call)));
  });

  test('lab: title dark on a bar, brackets, the same in the arm program', () {
    final layout = SkLayout.of(
      font,
      text.split('\n'),
      G1TextStyle.lab,
      top: 140,
      left: 24,
    );
    expect(layout.box, isNull);
    expect(layout.lines.first.level, 0);
    expect(layout.lines[1].level, 15);
    // The bar holds the title: level 12 under its line.
    final bar = layout.fills.first;
    expect(bar.level, SkLayout.barLevel);
    expect(bar.y, lessThanOrEqualTo(140));
    expect(bar.bottom, greaterThanOrEqualTo(140 + font.lineSpacing));
    // Eight bracket arms at the corners.
    expect(
      layout.fills.where((r) => r.level == SkLayout.bracketLevel),
      hasLength(8),
    );
    final bands = ScouterConnection.dashboardBands(
      font,
      text,
      G1TextStyle.lab,
      top: 140,
      rows: 11,
    );
    expect(bands.firstWhere((b) => b.text == text.split('\n').first).level, 0);
  });

  test('lab terminal: assistant on the bar, a cursor after the answer', () {
    final layout = SkLayout.of(
      font,
      ['Jarvis', 'The washing machine is done.'],
      G1TextStyle.labTerminal,
      top: 140,
      left: 24,
    );
    expect(layout.lines.first.level, 0);
    final cursor = layout.fills.last;
    final last = layout.lines.last;
    expect(cursor.x, last.x + font.width(last.text) + 4);
    expect(cursor.y, last.y + 4);
    expect(cursor.level, 15);
  });

  test('answers in the lab set: titled pages in a terminal window', () async {
    final g1 = ScouterConnection.fake(
      (side, channel, data) async {},
      font: font,
    );
    final display = G1Display(g1)..labDesign = true;
    final long = List.generate(25, (i) => 'Line ${i + 1}').join('\n');
    // Not connected: the pages are laid out, nothing is sent.
    await display.showAiAnswer(long, assistant: 'Jarvis');
    final pages = display.debugScreens;
    expect(pages.length, 3); // 10 lines per page below the title
    expect(pages.first.split('\n').first, 'Jarvis  1/3');
    expect(pages.last.split('\n').first, 'Jarvis  3/3');
    expect(pages.first.split('\n'), hasLength(g1.displayLines));
    await display.showAiAnswer('Done.', assistant: 'Jarvis');
    expect(display.debugScreens, ['Jarvis\nDone.']);
    // Classic set: plain, no title.
    display.labDesign = false;
    await display.showAiAnswer('Done.', assistant: 'Jarvis');
    expect(display.debugScreens, ['Done.']);
    g1.dispose();
  });

  test('arm-to-arm link: the right arm decides, the left one follows', () {
    int entry(Uint8List table, int trigger) =>
        ByteData.sublistView(table).getUint32(4 * trigger, Endian.little);
    final leader = SkResident.build(
      gestures: true,
      peer: SkResident.peerLeader,
    );
    final follower = SkResident.build(
      gestures: false,
      peer: SkResident.peerFollower,
    );
    expect(entry(leader.table, SkTrigger.tilt), isNot(0));
    expect(entry(leader.table, SkTrigger.peer), 0);
    expect(entry(follower.table, SkTrigger.tilt), 0);
    expect(entry(follower.table, SkTrigger.peer), isNot(0));
    // Without the link each arm follows the tilt itself.
    final alone = SkResident.build(gestures: false);
    expect(entry(alone.table, SkTrigger.tilt), isNot(0));
    expect(entry(alone.table, SkTrigger.peer), 0);
  });

  test('the library fits its area', () {
    final lib = SkLib.build();
    expect(SkLib.code + lib.code.length, lessThanOrEqualTo(SkLib.codeEnd));
    expect(lib.pool.length, lessThanOrEqualTo(4 * SkLib.poolWords));
    final p = SkResident.build(gestures: true);
    expect(SkResident.code + p.code.length, lessThanOrEqualTo(SkLib.code));
  });

  test('animations: frames at their times, the panel off at the end', () {
    for (final anim in [
      SkAnimation.sleep(font, cx: 320, cy: 196),
      SkAnimation.wake(font, cx: 320, cy: 196),
      SkAnimation.labSleep(font, cx: 320, cy: 196),
      SkAnimation.labWake(font, cx: 320, cy: 196),
    ]) {
      final ops = <int>[], sleeps = <int>[];
      final arena = Uint8List(SkArena.size);
      final codes = anim.code(font, maxCode: 242, start: 5000000);
      for (final code in codes) {
        expect(code.length, lessThanOrEqualTo(242));
        execute(code, arena, ops, sleeps);
      }
      expect(ops.where((o) => o == SkOp.call), hasLength(anim.frames.length));
      expect(
        ByteData.sublistView(arena).getUint32(SkLib.start, Endian.little),
        5000000,
      );
      // Wait words hold the frame offsets (start + offset by ADD).
      expect(ops.last, SkOp.sysWrite);
      expect(anim.durationUs, lessThan(4000000));
      // The region holds every box.
      for (final f in anim.frames) {
        final b = f.box;
        if (b.w == 0) continue; // lab frames draw no box
        expect(b.x >= anim.region.x && b.bottom <= anim.region.bottom, isTrue);
        expect(b.c * 2, lessThanOrEqualTo(b.w));
        expect(b.c * 2, lessThanOrEqualTo(b.h));
      }
    }
  });

  test('silent mode plays the animation on both arms at once', () async {
    final arms = FakeArms();
    final g1 = ScouterConnection.fake(arms.write, font: loadTestFont());
    arms.connection = g1;
    g1.fakeReady(epoch: arms.epoch);
    await g1.fakeSyncClocks();
    await g1.playSilentModeAnimation(true);
    for (final side in G1Side.values) {
      expect(
        arms.ops[side]!.where((o) => o == SkOp.call).length,
        greaterThan(30),
      );
    }
    // The same start in host time on both arms (their clocks differ).
    final left = ByteData.sublistView(arms.arenas[G1Side.left]!)
        .getUint32(SkLib.start, Endian.little);
    final right = ByteData.sublistView(arms.arenas[G1Side.right]!)
        .getUint32(SkLib.start, Endian.little);
    final offset =
        arms.clockOffset[G1Side.right]! - arms.clockOffset[G1Side.left]!;
    expect(
      ((right - left - offset) & 0xffffffff).toSigned(32).abs(),
      lessThan(2000),
    );
    g1.dispose();
  });
}
