import 'dart:math';
import 'dart:typed_data';

import 'sk_font.dart';
import 'sk_lib.dart';
import 'sk_program.dart';
import 'sk_protocol.dart';
import 'sk_style.dart';

/// One frame: the box and the levels of the two texts, [atUs] after the
/// start.
class SkAnimFrame {
  const SkAnimFrame(this.atUs, this.box, [this.level1 = 0, this.level2 = 0]);

  final int atUs;
  final SkBox box;
  final int level1, level2;
}

/// A short animation that the arms play by themselves: the app sends all
/// frames ahead as packets that wait for their time (`SLEEP_UNTIL`) and
/// draw a region with [SkLib.scene], so both eyes play it at exact times.
class SkAnimation {
  SkAnimation(this.region, this.texts, this.frames, {this.endUs});

  /// Panel region redrawn each frame.
  final SkRect region;

  /// Up to two text lines (x, baseline in [SkTextLine.y]).
  final List<SkTextLine> texts;
  final List<SkAnimFrame> frames;

  /// When the panel goes off again (after the last frame if null).
  final int? endUs;

  static const frameUs = 33333; // 30 frames/s

  // The card: bevelled frame with two lines.
  static const cardW = 300, cardH = 96, cardC = 10;
  static const border = 11;

  static double _easeOut(double t) => 1 - pow(1 - t, 3).toDouble();
  static double _easeIn(double t) => t * t * t;
  static int _lerp(num a, num b, double t) => (a + (b - a) * t).round();

  /// A box of w × h centred at (cx, cy), bevels no larger than it allows.
  static SkBox _box(int cx, int cy, int w, int h, int border, int fill) {
    w = max(2, w + w % 2);
    h = max(2, h + h % 2);
    // A filled box keeps small bevels: its corners stay unfilled.
    final c = max(0, min(fill > 0 ? 3 : cardC, min(w, h) ~/ 2 - 1));
    return SkBox(
      cx - w ~/ 2,
      cy - h ~/ 2,
      w,
      h,
      c: c,
      border: border,
      fill: fill,
    );
  }

  static List<SkTextLine> _texts(
    SkFont font,
    String title,
    String subtitle,
    int cx,
    int cy,
  ) {
    final lh = font.lineSpacing;
    final top = cy - lh + 2;
    return [
      SkTextLine(cx - font.width(title) ~/ 2, top + font.ascent, title),
      SkTextLine(
        cx - font.width(subtitle) ~/ 2,
        top + lh + font.ascent,
        subtitle,
      ),
    ];
  }

  static SkRect _region(int cx, int cy) =>
      SkRect(cx - cardW ~/ 2 - 4, cy - cardH ~/ 2 - 4, cardW + 8, cardH + 8, 0);

  /// The card appears, then folds into a line, the line into a dot, and
  /// the dot fades: the glasses go quiet.
  static SkAnimation sleep(SkFont font, {required int cx, required int cy}) {
    final f = <SkAnimFrame>[];
    var t = 0;
    void add(SkBox box, [int l1 = 0, int l2 = 0]) {
      f.add(SkAnimFrame(t, box, l1, l2));
      t += frameUs;
    }

    for (var i = 0; i <= 7; i++) {
      final p = _easeOut(i / 7);
      add(
        _box(
          cx,
          cy,
          _lerp(40, cardW, p),
          _lerp(6, cardH, p),
          _lerp(4, border, p),
          0,
        ),
      );
    }
    final card = _box(cx, cy, cardW, cardH, border, 0);
    for (var i = 1; i <= 6; i++) {
      add(card, _lerp(0, 15, i / 6), _lerp(0, 7, i / 6));
    }
    t += 900000; // hold
    for (var i = 1; i <= 5; i++) {
      add(card, _lerp(15, 0, i / 5), _lerp(7, 0, i / 5));
    }
    for (var i = 1; i <= 9; i++) {
      final p = _easeIn(i / 9);
      add(
        _box(
          cx,
          cy,
          cardW,
          _lerp(cardH, 2, p),
          _lerp(border, 15, p),
          _lerp(0, 9, p),
        ),
      );
    }
    for (var i = 1; i <= 9; i++) {
      final p = _easeIn(i / 9);
      add(_box(cx, cy, _lerp(cardW, 8, p), 2, 15, _lerp(9, 15, p)));
    }
    for (var i = 1; i <= 7; i++) {
      final l = _lerp(15, 0, i / 7);
      add(_box(cx, cy, 8, 4, l, l));
    }
    return SkAnimation(
      _region(cx, cy),
      _texts(font, 'Ruhemodus', 'bis gleich', cx, cy),
      f,
    );
  }

  /// A dot lights up, opens into a line and the line into the card: the
  /// glasses are back.
  static SkAnimation wake(SkFont font, {required int cx, required int cy}) {
    final f = <SkAnimFrame>[];
    var t = 0;
    void add(SkBox box, [int l1 = 0, int l2 = 0]) {
      f.add(SkAnimFrame(t, box, l1, l2));
      t += frameUs;
    }

    for (var i = 1; i <= 6; i++) {
      final l = _lerp(0, 15, i / 6);
      add(_box(cx, cy, 8, 4, l, l));
    }
    for (var i = 1; i <= 9; i++) {
      final p = _easeOut(i / 9);
      add(_box(cx, cy, _lerp(8, cardW, p), 2, 15, _lerp(15, 9, p)));
    }
    for (var i = 1; i <= 9; i++) {
      final p = _easeOut(i / 9);
      add(
        _box(
          cx,
          cy,
          cardW,
          _lerp(2, cardH, p),
          _lerp(15, border, p),
          _lerp(9, 0, p),
        ),
      );
    }
    final card = _box(cx, cy, cardW, cardH, border, 0);
    for (var i = 1; i <= 6; i++) {
      add(card, _lerp(0, 15, i / 6), _lerp(0, 7, i / 6));
    }
    t += 1200000; // hold
    for (var i = 1; i <= 8; i++) {
      final p = i / 8;
      add(
        _box(cx, cy, cardW, cardH, _lerp(border, 0, p), 0),
        _lerp(15, 0, p),
        _lerp(7, 0, p),
      );
    }
    return SkAnimation(
      _region(cx, cy),
      _texts(font, 'Bin wieder da', 'Ruhemodus aus', cx, cy),
      f,
    );
  }

  int get durationUs => endUs ?? frames.last.atUs + frameUs;

  /// Host code for one arm. [start] is the first frame's time in that
  /// arm's clock; without it each arm starts [leadUs] after it reads the
  /// first packet.
  List<Uint8List> code(
    SkFont font, {
    required int maxCode,
    int? start,
    int leadUs = 150000,
  }) {
    SkLib.build();
    final packets = <Uint8List>[];
    var code = SkCode();
    void room(int bytes) {
      if (code.length + bytes > maxCode) {
        packets.add(code.take());
        code = SkCode();
      }
    }

    // The app's texts and the dashboard program draw nothing meanwhile.
    code.write(SkResident.busy.address, const [1, 0, 0, 0, 0, 0, 0, 0]);
    // Texts and the scene's fixed words.
    final glyphs = BytesBuilder();
    final words = <int>[region.x, region.y, region.w, region.h];
    for (var i = 0; i < 2; i++) {
      final line = i < texts.length ? texts[i] : null;
      final g = line == null ? const <int>[] : font.encode(line.text);
      words.addAll([
        line?.x ?? 0,
        line?.y ?? 0,
        SkLib.text + glyphs.length,
        g.length,
      ]);
      glyphs.add(g);
    }
    final g = glyphs.toBytes();
    if (SkLib.text + g.length > SkLib.textEnd) throw StateError('text');
    for (var o = 0; o < g.length; o += 200) {
      room(5 + 200);
      code.write(SkLib.text + o, g.sublist(o, min(g.length, o + 200)));
    }
    room(5 + 4 * words.length);
    code.write(SkLib.region, SkLib.u32s(words));
    room(2 * skOpSize(2));
    code.sysWrite(SkProp.panel, 1);
    final startWord = SkLib.start ~/ 4, atWord = SkLib.at ~/ 4;
    const param = SkArena.params ~/ 4;
    if (start != null) {
      code.write(SkLib.start, SkLib.u32s([start]));
    } else {
      code
        ..write(SkArena.params, SkLib.u32s([SkProp.timeUs]))
        ..instruction(SkOp.sysRead, [startWord, param])
        ..write(SkArena.params, SkLib.u32s([leadUs]))
        ..instruction(SkOp.add, [startWord, startWord, param]);
    }
    void waitFor(int us) {
      code
        ..write(SkArena.params, SkLib.u32s([us]))
        ..instruction(SkOp.add, [atWord, startWord, param])
        ..instruction(SkOp.sleepUntil, [atWord]);
    }

    const waitSize = 9 + 9 + 4;
    for (final frame in frames) {
      room(5 + 36 + waitSize + 4);
      code.write(
        SkLib.boxWords,
        SkLib.u32s([...frame.box.words, frame.level1, frame.level2]),
      );
      waitFor(frame.atUs);
      code.call(SkLib.sceneAt);
    }
    room(waitSize + 13 + skOpSize(2));
    waitFor(durationUs);
    code
      ..write(SkResident.busy.address, const [0, 0, 0, 0])
      ..sysWrite(SkProp.panel, 0);
    packets.add(code.take());
    return packets;
  }
}
