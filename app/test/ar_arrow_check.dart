/// What the arm program would draw of the navigation's AR arrow, from the
/// words the app wrote into an arena (SkResident.arrowData): the program's
/// own arithmetic (sk_program.dart, label `arrow`), checked against what
/// must hold whatever the head does.
library;

import 'dart:typed_data';

import 'package:even_g1_ha/navigation/ar_arrow.dart';
import 'package:even_g1_ha/scouter/sk_program.dart';
import 'package:even_g1_ha/scouter/sk_protocol.dart';

/// A signed 32-bit word of [arena] at [address].
int armWord(Uint8List arena, int address) =>
    ByteData.sublistView(arena).getInt32(address, Endian.little);

/// i32 arithmetic as the VM does it.
int _i32(int v) => v.toSigned(32);

/// DIVS: truncates toward zero.
int _divs(int a, int b) => _i32(a) ~/ b;

/// The problems of the arrow in [arena] (empty: none): every line end at
/// every roll the program follows and every pitch lies on the panel, below
/// [textBottom] (the first row free of text) and within the rows the arrow
/// was given; the boxes the program clears and checks are the lines' true
/// boxes; levels and counts are what LINE and the tables allow.
List<String> arrowProblems(Uint8List arena, {required int textBottom}) {
  final base = SkResident.arrowData;
  int d(int offset) => armWord(arena, base + offset);
  final problems = <String>[];
  final n = d(0), cx = d(4), cy = d(8), top = d(12), bottom = d(16);
  final gain = d(20), pitchAdd = d(24);
  if (n <= 0 || n > ArArrow.maxSegments) problems.add('$n segments');
  if (base + ArArrow.segmentsAt + 20 * n > SkResident.arrowDataEnd) {
    problems.add('the segments run past the arrow\'s area');
  }
  if (top < textBottom) {
    problems.add('top $top above the text\'s end $textBottom');
  }
  if (bottom >= SkPanel.height) problems.add('bottom $bottom off the panel');
  if (problems.isNotEmpty) return problems;
  final segments = [
    for (var i = 0; i < n; i++)
      [
        for (var k = 0; k < 5; k++)
          armWord(arena, base + ArArrow.segmentsAt + 20 * i + 4 * k),
      ],
  ];
  for (final s in segments) {
    if (s[4] < 0 || s[4] > 15) problems.add('level ${s[4]}');
  }
  for (var r = 0; r < ArArrow.rolls; r++) {
    final sin = armWord(arena, base + ArArrow.sinAt + 4 * r);
    final cos = armWord(arena, base + ArArrow.cosAt + 4 * r);
    (int, int) turn(int x, int y, int shift) => (
      _divs(x * cos + y * sin, 4096) + cx,
      _divs(y * cos - x * sin, 4096) + cy + shift,
    );
    final box = [
      for (var k = 0; k < 4; k++)
        armWord(arena, base + ArArrow.boxesAt + 16 * r + 4 * k),
    ];
    // The box the program uses is the lines' own (at shift 0).
    var x0 = 1 << 30, y0 = 1 << 30, x1 = -(1 << 30), y1 = -(1 << 30);
    for (final s in segments) {
      for (final (x, y) in [turn(s[0], s[1], 0), turn(s[2], s[3], 0)]) {
        if (x < x0) x0 = x;
        if (y < y0) y0 = y;
        if (x > x1) x1 = x;
        if (y > y1) y1 = y;
      }
    }
    if ([x0, y0, x1, y1].join(',') != box.join(',')) {
      problems.add(
        'roll index $r: box $box, the lines span ($x0, $y0, $x1, '
        '$y1)',
      );
    }
    for (final pitch in [
      for (var p = -90; p <= 90; p += 3) p,
      SkProp.unknown,
    ]) {
      // The shift as the program computes it, kept within top and bottom.
      var shift = pitch == SkProp.unknown ? 0 : (pitch + pitchAdd) * gain;
      if (shift < top - box[1]) shift = top - box[1];
      if (shift > bottom - box[3]) shift = bottom - box[3];
      for (final s in segments) {
        for (final (x, y) in [
          turn(s[0], s[1], shift),
          turn(s[2], s[3], shift),
        ]) {
          if (x < 0 || x >= SkPanel.width || y < top || y > bottom) {
            problems.add(
              'roll index $r, pitch $pitch: ($x, $y) outside '
              '0…${SkPanel.width - 1} × $top…$bottom',
            );
            return problems;
          }
        }
      }
    }
  }
  return problems;
}

/// The line ends the program draws for the arrow in [arena] at a head
/// [pitch] (degrees or [SkProp.unknown]) and [roll] (degrees or
/// [SkProp.unknown]), in its own arithmetic.
List<(int, int)> programPoints(Uint8List arena, int pitch, int roll) {
  final base = SkResident.arrowData;
  int d(int offset) => armWord(arena, base + offset);
  var r = roll == SkProp.unknown ? 0 : roll;
  r = r.clamp(-ArArrow.rollMax, ArArrow.rollMax) + ArArrow.rollMax;
  final box = [
    for (var k = 0; k < 4; k++)
      armWord(arena, base + ArArrow.boxesAt + 16 * r + 4 * k),
  ];
  var shift = pitch == SkProp.unknown ? 0 : (pitch + d(24)) * d(20);
  if (shift < d(12) - box[1]) shift = d(12) - box[1];
  if (shift > d(16) - box[3]) shift = d(16) - box[3];
  final sin = armWord(arena, base + ArArrow.sinAt + 4 * r);
  final cos = armWord(arena, base + ArArrow.cosAt + 4 * r);
  return [
    for (var i = 0; i < d(0); i++)
      for (final k in [0, 2])
        () {
          final x = armWord(arena, base + ArArrow.segmentsAt + 20 * i + 4 * k);
          final y = armWord(
            arena,
            base + ArArrow.segmentsAt + 20 * i + 4 * k + 4,
          );
          return (
            _divs(x * cos + y * sin, 4096) + d(4),
            _divs(y * cos - x * sin, 4096) + d(8) + shift,
          );
        }(),
  ];
}
