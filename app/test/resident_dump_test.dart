import 'dart:io';
import 'dart:typed_data';

import 'package:even_g1_ha/g1/g1_connection.dart';
import 'package:even_g1_ha/scouter/scouter_connection.dart';
import 'package:even_g1_ha/scouter/sk_anim.dart';
import 'package:even_g1_ha/scouter/sk_font.dart';
import 'package:even_g1_ha/scouter/sk_lib.dart';
import 'package:even_g1_ha/scouter/sk_program.dart';
import 'package:even_g1_ha/scouter/sk_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

/// Writes an arena image with the resident program for ScouterKit's VM
/// interpreter (a local check, only with `SK_DUMP=directory`).
void main() {
  dumpDesigns();
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
        final e = SkResident.lines + 24 * i;
        w(e, 24);
        w(e + 4, 140 + i * font.lineSpacing);
        w(e + 8, at);
        w(e + 12, g.length);
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

/// Arena and host packets of the designs and animations for the renderer
/// (scratchpad vmtest/render.c), only with `SK_DUMP=directory`.
void dumpDesigns() {
  final dir = Platform.environment['SK_DUMP'];
  test('dump designs and animations', () {
    final font = SkFont.parse(
      File(ScouterConnection.fontAsset).readAsBytesSync(),
    ).scaled(2, keep: SkFont.textCodepoint);
    final lib = SkLib.build();
    final arena = Uint8List(SkArena.size);
    arena.setRange(SkArena.font, SkArena.font + font.blob.length, font.blob);
    arena.setRange(SkLib.code, SkLib.code + lib.code.length, lib.code);
    arena.setRange(SkLib.pool, SkLib.pool + lib.pool.length, lib.pool);
    void save(String name, List<Uint8List> codes, [Uint8List? image]) {
      if (dir == null) return;
      final b = BytesBuilder();
      for (final c in codes) {
        expect(c.length, lessThanOrEqualTo(242));
        b.add([c.length & 0xff, c.length >> 8]);
        b.add(c);
      }
      File('$dir/$name.pkt').writeAsBytesSync(b.takeBytes());
      File('$dir/$name.arena').writeAsBytesSync(image ?? arena);
    }

    const dashboard =
        '14:32 · Fr 7. Nov\nWohnzimmer: 21,5 °C\nWaschmaschine: fertig\n'
        'Heute 18:00 Training\nMorgen 09:30 Zahnarzt\n[ ] Müll rausbringen';
    for (final style in G1TextStyle.values) {
      save(
        'text_${style.id}',
        ScouterConnection.textCode(
          font,
          style == G1TextStyle.badge ? 'Claude\nhört zu …' : dashboard,
          maxCode: 242,
          style: style,
        ),
      );
    }
    for (final on in [true, false]) {
      final anim = on
          ? SkAnimation.sleep(font, cx: 320, cy: 196)
          : SkAnimation.wake(font, cx: 320, cy: 196);
      save(
        on ? 'sleep' : 'wake',
        anim.code(font, maxCode: 242, start: 1200000),
      );
    }
    // Examples for the README (made-up content).
    const example =
        '09:41  ·  Sa, 7. Nov\nWohnzimmer: 21,5 °C\nAußen: 8 °C, bewölkt\n'
        'Waschmaschine: fertig\n» heute 18:00  Beispieltermin\n'
        '» morgen 10:00  Noch ein Termin\n[ ] Beispiel-Aufgabe · heute';
    for (final style in G1TextStyle.values) {
      save(
        'readme_${style.id}',
        ScouterConnection.textCode(
          font,
          style == G1TextStyle.badge ? 'Jarvis\nhört zu …' : example,
          maxCode: 242,
          style: style,
        ),
      );
    }
    // The resident program with a card dashboard (as _writeDashboard).
    final p = SkResident.build(gestures: false);
    final image = Uint8List.fromList(arena);
    final d = ByteData.sublistView(image);
    void w(int address, int v) => d.setUint32(address, v, Endian.little);
    image.setRange(SkResident.code, SkResident.code + p.code.length, p.code);
    image.setRange(SkResident.pool, SkResident.pool + p.pool.length, p.pool);
    image.setRange(SkResident.table, SkResident.table + 64, p.table);
    for (final style in [G1TextStyle.card, G1TextStyle.frame]) {
      final bands = ScouterConnection.dashboardBands(
        font,
        dashboard,
        style,
        top: 140,
        rows: 11,
      );
      var at = SkResident.text, ri = 0;
      for (var i = 0; i < bands.length; i++) {
        final band = bands[i];
        final g = band.text == null ? <int>[] : font.encode(band.text!);
        image.setRange(at, at + g.length, g);
        final e = SkResident.lines + 24 * i;
        w(e, band.x);
        w(e + 4, band.y);
        w(e + 8, g.isEmpty ? 0 : at);
        w(e + 12, g.length);
        w(e + 16, ri);
        w(e + 20, band.rects.length);
        for (final r in band.rects) {
          final ra = SkResident.rects + 20 * ri++;
          w(ra, r.x);
          w(ra + 4, r.y);
          w(ra + 8, r.w);
          w(ra + 12, r.h);
          w(ra + 16, r.level);
        }
        at += g.length;
      }
      expect(ri, lessThanOrEqualTo(SkResident.maxRects));
      expect(bands.length, lessThanOrEqualTo(SkResident.maxEntries));
      w(SkResident.angle.address, 30);
      w(SkResident.flags.address, 1);
      w(SkResident.ascent.address, font.ascent);
      w(SkResident.rows.address, bands.length);
      w(SkResident.lineHeight.address, font.lineSpacing);
      w(SkResident.count.address, bands.length);
      save('resident_${style.id}', [], Uint8List.fromList(image));
    }
  });
}
