/// What the arm program would draw of the navigation's wiggle, from the
/// words the app wrote into an arena (SkResident.arrowData), with the
/// program's own arithmetic (sk_program.dart, label `arrow`).
library;

import 'dart:typed_data';

import 'package:even_g1_ha/navigation/nav_wiggle.dart';
import 'package:even_g1_ha/scouter/scouter_connection.dart';
import 'package:even_g1_ha/scouter/sk_icons.dart';
import 'package:even_g1_ha/scouter/sk_program.dart';

/// A signed 32-bit word of [arena] at [address].
int armWord(Uint8List arena, int address) =>
    ByteData.sublistView(arena).getInt32(address, Endian.little);

/// The problems of the wiggle in [arena] (empty: none): a frame count the
/// table holds, the last frame back at the icon's place, and every frame's
/// icon on the panel and left of the text (ScouterConnection.iconTextLeft).
List<String> wiggleProblems(Uint8List arena) {
  final base = SkResident.arrowData;
  final n = armWord(arena, base), x = armWord(arena, base + 4);
  final y = armWord(arena, base + 8);
  if (n <= 0 || n > NavWiggle.maxFrames) return ['$n frames'];
  final problems = <String>[];
  for (var k = 0; k < n; k++) {
    final dx = armWord(arena, base + NavWiggle.offsetsAt + 8 * k);
    final dy = armWord(arena, base + NavWiggle.offsetsAt + 8 * k + 4);
    final x0 = x + dx, y0 = y + dy;
    final x1 = x0 + SkIcons.size - 1, y1 = y0 + SkIcons.size - 1;
    if (x0 < 0 || y0 < 0 || y1 >= 480) {
      problems.add('frame $k: ($x0, $y0) off the panel');
    }
    if (x1 >= ScouterConnection.iconTextLeft) {
      problems.add('frame $k: reaches the text at $x1');
    }
    if (k == n - 1 && (dx != 0 || dy != 0)) {
      problems.add('ends at ($dx, $dy), not at its place');
    }
  }
  return problems;
}
