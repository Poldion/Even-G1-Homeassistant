import 'dart:io';
import 'dart:typed_data';

import 'package:even_g1_ha/g1/g1_connection.dart';
import 'package:even_g1_ha/l10n/l10n.dart';
import 'package:even_g1_ha/scouter/scouter_connection.dart';
import 'package:even_g1_ha/scouter/sk_anim.dart';
import 'package:even_g1_ha/scouter/sk_asm.dart';
import 'package:even_g1_ha/scouter/sk_emoji.dart';
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
    for (final (name, gestures, peer) in [
      ('left', false, SkResident.peerNone),
      ('right', true, SkResident.peerNone),
      ('peer_left', false, SkResident.peerFollower),
      ('peer_right', true, SkResident.peerLeader),
    ]) {
      final p = SkResident.build(gestures: gestures, peer: peer);
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
        final e = SkResident.lines + 4 * SkResident.entryWords * i;
        w(e, 24);
        w(e + 4, 140 + i * font.lineSpacing);
        w(e + 8, at);
        w(e + 12, g.length);
        w(e + 24, 15);
        at += g.length;
      }
      w(SkResident.count.address, words.length);
      if (dir != null) {
        File('$dir/arena_$name.bin').writeAsBytesSync(arena);
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
    // Examples for the README (made-up content), in both languages.
    const examples = {
      'en':
          '09:41  ·  Sat, Nov 7\nLiving room: 21.5 °C\nOutside: 8 °C, '
          'cloudy\nWashing machine: done\n» today 18:00  Example event\n'
          '» tomorrow 10:00  Another event\n[ ] Example task · today',
      'de':
          '09:41  ·  Sa, 7. Nov\nWohnzimmer: 21,5 °C\nAußen: 8 °C, bewölkt\n'
          'Waschmaschine: fertig\n» heute 18:00  Beispieltermin\n'
          '» morgen 10:00  Noch ein Termin\n[ ] Beispiel-Aufgabe · heute',
    };
    for (final MapEntry(key: lang, value: example) in examples.entries) {
      L10n.apply(lang);
      for (final style in G1TextStyle.values) {
        save(
          'readme_${lang}_${style.id}',
          ScouterConnection.textCode(
            font,
            style == G1TextStyle.badge || style == G1TextStyle.labBadge
                ? tr.coreListening('Jarvis')
                : example,
            maxCode: 242,
            style: style,
          ),
        );
      }
      final answer = {
        'en':
            'Jarvis\nThe washing machine finished ten minutes ago. '
            'The living room is at 21.5 °C, outside it is 8 °C and cloudy.',
        'de':
            'Jarvis\nDie Waschmaschine ist seit zehn Minuten fertig. '
            'Im Wohnzimmer sind es 21,5 °C, draußen 8 °C und bewölkt.',
      }[lang]!;
      save(
        'readme_${lang}_lab_answer',
        ScouterConnection.textCode(
          font,
          answer,
          maxCode: 242,
          style: G1TextStyle.labTerminal,
        ),
      );
      final anims = {
        'sleep': SkAnimation.sleep(font, cx: 320, cy: 196),
        'wake': SkAnimation.wake(font, cx: 320, cy: 196),
        'lab_sleep': SkAnimation.labSleep(font, cx: 320, cy: 196),
        'lab_wake': SkAnimation.labWake(font, cx: 320, cy: 196),
      };
      for (final MapEntry(key: name, value: anim) in anims.entries) {
        save(
          'readme_${lang}_$name',
          anim.code(font, maxCode: 242, start: 1200000),
        );
      }
    }
    L10n.apply('en');
    // The resident program with a card dashboard (as _writeDashboard).
    final p = SkResident.build(gestures: false);
    final image = Uint8List.fromList(arena);
    final d = ByteData.sublistView(image);
    void w(int address, int v) => d.setUint32(address, v, Endian.little);
    image.setRange(SkResident.code, SkResident.code + p.code.length, p.code);
    image.setRange(SkResident.pool, SkResident.pool + p.pool.length, p.pool);
    image.setRange(SkResident.table, SkResident.table + 64, p.table);
    for (final style in [
      G1TextStyle.card,
      G1TextStyle.frame,
      G1TextStyle.lab,
    ]) {
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
        final e = SkResident.lines + 4 * SkResident.entryWords * i;
        w(e, band.x);
        w(e + 4, band.y);
        w(e + 8, g.isEmpty ? 0 : at);
        w(e + 12, g.length);
        w(e + 16, ri);
        w(e + 20, band.rects.length);
        w(e + 24, band.level);
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
      if (style == G1TextStyle.card || style == G1TextStyle.lab) {
        // Recording: the microphone's stand and the label (right arm).
        final small = SkFont.parse(
          File(ScouterConnection.fontAsset).readAsBytesSync(),
        ).scaled(1, keep: SkFont.textCodepoint);
        expect(
          SkArena.smallFont + small.blob.length,
          lessThanOrEqualTo(SkArena.smallFont + SkArena.smallFontMax),
        );
        expect(
          font
              .withSlots(
                SkEmoji.slots,
                advance: SkEmoji.advance,
                slotBytes: SkEmoji.slotBytes,
              )
              .blob
              .length,
          lessThanOrEqualTo(SkArena.fontMax),
        );
        final mic = SkResident.build(gestures: false, micArm: true);
        final img = Uint8List.fromList(image);
        final dm = ByteData.sublistView(img);
        img.setRange(
          SkResident.code,
          SkResident.code + mic.code.length,
          mic.code,
        );
        img.setRange(
          SkResident.pool,
          SkResident.pool + mic.pool.length,
          mic.pool,
        );
        img.setRange(SkResident.table, SkResident.table + 64, mic.table);
        img.setRange(
          SkArena.smallFont,
          SkArena.smallFont + small.blob.length,
          small.blob,
        );
        for (final lang in ['en', 'de']) {
          L10n.apply(lang);
          final text = tr.coreRecordingLabel;
          final g = small.encode(text);
          img.setRange(
            SkResident.labelText,
            SkResident.labelText + g.length,
            g,
          );
          final at = ScouterConnection.dashboardLabelAt(
            font,
            dashboard,
            style,
            top: 140,
            rows: 11,
          );
          void wm(SkW word, int v) =>
              dm.setUint32(word.address, v, Endian.little);
          wm(SkResident.micOn, 1);
          wm(SkResident.labelN, g.length);
          wm(SkResident.labelX, at.x);
          wm(SkResident.labelY, at.y);
          wm(SkResident.labelW, small.width(text) + 8);
          wm(SkResident.labelBase, ScouterConnection.labelBase(small));
          save('resident_mic_${style.id}_$lang', [], Uint8List.fromList(img));
          if (dir != null) {
            File('$dir/label_${style.id}.txt')
                .writeAsStringSync('${at.x} ${at.y}');
          }
        }
        L10n.apply('en');
      }
      if (style == G1TextStyle.card) {
        // The status line (Home Assistant unreachable / no phone).
        for (final lang in ['en', 'de']) {
          L10n.apply(lang);
          final noPhone = font.encode(tr.skStatusNoPhone);
          final noHa = font.encode(tr.skStatusHaOffline);
          image.setRange(
            SkResident.statusText,
            SkResident.statusText + noPhone.length,
            noPhone,
          );
          image.setRange(
            SkResident.statusText + SkResident.statusMax,
            SkResident.statusText + SkResident.statusMax + noHa.length,
            noHa,
          );
          w(SkResident.statusN1.address, noPhone.length);
          w(SkResident.statusN2.address, noHa.length);
          w(
            SkResident.statusY.address,
            ScouterConnection.statusLineY(bands, font.lineSpacing, 140),
          );
          w(SkResident.haOffline.address, 1);
          save('resident_status_$lang', [], Uint8List.fromList(image));
          w(SkResident.haOffline.address, 0);
        }
        L10n.apply('en');
      }
    }
    // Emojis: the font with slots, the emojis of the examples copied in.
    {
      final emoji = SkFont.parse(File(SkEmoji.asset).readAsBytesSync());
      final slotted = font.withSlots(
        SkEmoji.slots,
        advance: SkEmoji.advance,
        slotBytes: SkEmoji.slotBytes,
      );
      final blob = Uint8List.fromList(slotted.blob);
      final bd = ByteData.sublistView(blob);
      var k = 0;
      String fill(String text) {
        final clean = SkEmoji.clean(text);
        for (final cp in clean.runes) {
          if (cp < 0x2190 || slotted.glyphOrNull(cp) != null) continue;
          final g = emoji.glyphOrNull(cp);
          if (g == null) continue;
          final data = emoji.glyphData(g);
          final at = slotted.slotAt(k);
          blob.setRange(at.bitmap, at.bitmap + data.bits.length, data.bits);
          bd
            ..setUint32(at.entry, at.bitmap * 8, Endian.little)
            ..setUint8(at.entry + 4, data.w)
            ..setUint8(at.entry + 5, data.h)
            ..setUint8(at.entry + 6, SkEmoji.advance)
            ..setInt16(at.entry + 8, data.xOff, Endian.little)
            ..setInt16(at.entry + 10, data.yOff, Endian.little);
          slotted.map(cp, slotted.firstSlot + k++);
        }
        return clean;
      }

      final texts = {
        'en':
            '09:41  ·  Sat, Nov 7\n☀️ 8 °C  🌧 30 %\n🏠 Living room: 21.5 °C\n'
            '🔋 Car: 80 %\n» today 18:00  🎉 Example event\n'
            '[ ] 🛒 Example task · today',
        'de':
            '09:41  ·  Sa, 7. Nov\n☀️ 8 °C  🌧 30 %\n🏠 Wohnzimmer: 21,5 °C\n'
            '🔋 Auto: 80 %\n» heute 18:00  🎉 Beispieltermin\n'
            '[ ] 🛒 Beispiel-Aufgabe · heute',
      };
      for (final MapEntry(key: lang, value: t) in texts.entries) {
        final text = fill(t);
        final img = Uint8List.fromList(arena);
        img.setRange(SkArena.font, SkArena.font + blob.length, blob);
        save(
          'emoji_$lang',
          ScouterConnection.textCode(
            slotted,
            text,
            maxCode: 242,
            style: G1TextStyle.card,
          ),
          img,
        );
      }
    }
    // Automatic brightness with an offset on the right arm.
    {
      final p = SkResident.build(gestures: false, micArm: true);
      final img = Uint8List.fromList(image);
      final d = ByteData.sublistView(img);
      img.setRange(SkResident.code, SkResident.code + p.code.length, p.code);
      img.setRange(SkResident.pool, SkResident.pool + p.pool.length, p.pool);
      img.setRange(SkResident.table, SkResident.table + 64, p.table);
      d.setUint32(SkResident.lightOn.address, 1, Endian.little);
      d.setInt32(SkResident.lightOffset.address, 5, Endian.little);
      d.setUint32(SkResident.lightLevel.address, 0xffffffff, Endian.little);
      save('resident_light', [], img);
    }
    // The clock: 14:59 at arm time 1.2 s, the digits in the first line.
    {
      final bands = ScouterConnection.dashboardBands(
        font,
        '00:00  ·  Sat, Nov 7\nLiving room: 21.5 °C',
        G1TextStyle.card,
        top: 140,
        rows: 4,
      );
      var at = SkResident.text, ri = 0, clockAt = 0;
      for (var i = 0; i < bands.length; i++) {
        final band = bands[i];
        final g = band.text == null ? <int>[] : font.encode(band.text!);
        if (band.text != null && clockAt == 0 && band.text!.contains('00:00')) {
          clockAt = at + font.encode(band.text!.split('00:00').first).length;
        }
        image.setRange(at, at + g.length, g);
        final e = SkResident.lines + 4 * SkResident.entryWords * i;
        w(e, band.x);
        w(e + 4, band.y);
        w(e + 8, g.isEmpty ? 0 : at);
        w(e + 12, g.length);
        w(e + 16, ri);
        w(e + 20, band.rects.length);
        w(e + 24, band.level);
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
      w(SkResident.rows.address, bands.length);
      w(SkResident.count.address, bands.length);
      w(SkResident.clockAt.address, clockAt);
      w(SkResident.clockRef.address, 1200000);
      w(SkResident.clockMinute.address, 14 * 60 + 59);
      save('resident_clock', [], Uint8List.fromList(image));
      if (dir != null) File('$dir/clock_at.txt').writeAsStringSync('$clockAt');
    }
  });
}
