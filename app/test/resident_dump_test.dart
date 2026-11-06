import 'dart:io';
import 'dart:typed_data';

import 'package:even_g1_ha/scouter/scouter_connection.dart';
import 'package:even_g1_ha/scouter/sk_font.dart';
import 'package:even_g1_ha/scouter/sk_program.dart';
import 'package:even_g1_ha/scouter/sk_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

/// Writes an arena image with the resident program for ScouterKit's VM
/// interpreter (a local check, only with `SK_DUMP=directory`).
void main() {
  final dir = Platform.environment['SK_DUMP'];
  test('dump the resident program', () {
    final font = SkFont.parse(
      File(ScouterConnection.fontAsset).readAsBytesSync(),
    ).scaled(2, keep: SkFont.textCodepoint);
    for (final gestures in [false, true]) {
      final p = SkResident.build(gestures: gestures);
      final arena = Uint8List(SkArena.size);
      final d = ByteData.sublistView(arena);
      arena.setRange(SkArena.font, SkArena.font + font.blob.length, font.blob);
      arena.setRange(SkResident.code, SkResident.code + p.code.length, p.code);
      arena.setRange(SkResident.pool, SkResident.pool + p.pool.length, p.pool);
      arena.setRange(SkResident.table, SkResident.table + 64, p.table);
      void w(int address, int v) => d.setUint32(address, v, Endian.little);
      w(SkResident.angle.address, 30);
      w(SkResident.flags.address, 3);
      w(SkResident.left.address, 24);
      w(SkResident.ascent.address, font.ascent);
      w(SkResident.rows.address, 3);
      w(SkResident.lineHeight.address, font.lineSpacing);
      var at = SkResident.text;
      final words = ['Hallo', 'Welt'];
      for (var i = 0; i < words.length; i++) {
        final g = font.encode(words[i]);
        arena.setRange(at, at + g.length, g);
        w(SkResident.lines + 12 * i, 140 + i * font.lineSpacing);
        w(SkResident.lines + 12 * i + 4, at);
        w(SkResident.lines + 12 * i + 8, g.length);
        at += g.length;
      }
      w(SkResident.count.address, words.length);
      if (dir != null) {
        File('$dir/arena_${gestures ? 'right' : 'left'}.bin')
            .writeAsBytesSync(arena);
      }
      expect(p.code.length, lessThan(SkResident.codeEnd - SkResident.code));
    }
  });
}
