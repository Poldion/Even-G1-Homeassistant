/// What the arm program would draw of the navigation's arrow, from the
/// words the app wrote into an arena (SkResident.arrowData), with the
/// program's own arithmetic (sk_program.dart, label `arrow`).
library;

import 'dart:typed_data';

import 'package:even_g1_ha/navigation/turn_arrow.dart';
import 'package:even_g1_ha/scouter/sk_program.dart';

/// A signed 32-bit word of [arena] at [address].
int armWord(Uint8List arena, int address) =>
    ByteData.sublistView(arena).getInt32(address, Endian.little);

/// The problems of the arrow in [arena] (empty: none): every line end of
/// every frame lies within the arrow's rows, above the text ([textTop])
/// and on the panel, inside the box the program clears; levels and counts
/// are what LINE and the tables allow.
List<String> arrowProblems(Uint8List arena, {required int textTop}) {
  final base = SkResident.arrowData;
  int d(int offset) => armWord(arena, base + offset);
  final problems = <String>[];
  final n = d(0), cx = d(4), cy = d(8), frames = d(12);
  if (n <= 0 || n > TurnArrow.maxSegments) problems.add('$n segments');
  if (frames <= 0 || frames > TurnArrow.maxFrames) {
    problems.add('$frames frames');
  }
  if (problems.isNotEmpty) return problems;
  final segments = [
    for (var i = 0; i < n; i++)
      [
        for (var k = 0; k < 5; k++)
          armWord(arena, base + TurnArrow.segmentsAt + 20 * i + 4 * k),
      ],
  ];
  for (final s in segments) {
    if (s[4] < 0 || s[4] > 15) problems.add('level ${s[4]}');
  }
  for (var k = 0; k < frames; k++) {
    final f = [
      for (var i = 0; i < 8; i++)
        armWord(
          arena,
          base + TurnArrow.framesAt + TurnArrow.frameBytes * k + 4 * i,
        ),
    ];
    final (c, s, dx, dy) = (f[0], f[1], f[2], f[3]);
    final box = f.sublist(4);
    if (box[0] < 0 || box[2] >= 640 || box[1] < 0 || box[3] >= textTop) {
      problems.add('frame $k: box $box off its area');
    }
    for (final seg in segments) {
      for (final (x, y) in [(seg[0], seg[1]), (seg[2], seg[3])]) {
        final px = cx + dx + ((x * c + y * s).toSigned(32) ~/ 4096);
        final py = cy + dy + ((y * c - x * s).toSigned(32) ~/ 4096);
        if (px < box[0] || px > box[2] || py < box[1] || py > box[3]) {
          problems.add('frame $k: ($px, $py) outside its box $box');
        }
      }
    }
  }
  return problems;
}
