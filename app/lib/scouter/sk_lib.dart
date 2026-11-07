import 'dart:typed_data';

import 'sk_asm.dart';
import 'sk_protocol.dart';
import 'sk_style.dart';

/// Stored code that host packets `CALL` (VM.md §6.2), uploaded with the
/// font: [box] draws an [SkBox] into the frame, [scene] one frame of an
/// animation.
///
/// It keeps its values in words of its own, not in the registers, which
/// the resident program uses (a packet may run while one of its tasks
/// waits).
class SkLib {
  static const code = 0x3E000;
  static const codeEnd = pool;
  static const pool = 0x3F000;
  static const poolWords = 64;

  /// The box: x, y, w, h, c, border, fill (SkBox.words), then the levels of
  /// the scene's two text lines.
  static const boxWords = 0x3F100;
  static const levels = boxWords + 28;

  /// The scene: the region drawn (x, y, w, h), then per text line x,
  /// baseline, glyph address, glyph count.
  static const region = 0x3F140;
  static const texts = region + 16;

  /// Animation clock: start (arm time), the frame's time.
  static const start = 0x3F180;
  static const at = 0x3F184;

  static const _temps = 0x3F1C0;

  /// Glyph indices of the scene's texts.
  static const text = 0x3F200;
  static const textEnd = 0x3F400;

  static ({Uint8List code, Uint8List pool})? _built;

  static ({Uint8List code, Uint8List pool}) build() => _built ??= _build();

  static ({Uint8List code, Uint8List pool}) _build() {
    final a = SkAsm(codeAt: code, poolAt: pool, poolWords: poolWords);
    SkW word(int address) => SkW.at(address);
    final x = word(boxWords), y = word(boxWords + 4), w = word(boxWords + 8);
    final h = word(boxWords + 12), c = word(boxWords + 16);
    final border = word(boxWords + 20), fill = word(boxWords + 24);
    var next = _temps;
    SkW temp() {
      final t = word(next);
      next += 4;
      return t;
    }

    final xc = temp(), yc = temp(), wi = temp(), hi = temp(), yb = temp();
    final xr = temp(), x1 = temp(), y1 = temp(), xw1 = temp(), xw2 = temp();
    final yh1 = temp(), yh2 = temp(), xwc = temp(), yhc = temp(), c2 = temp();
    final c0 = a.c(0), two = a.c(2);
    final frame = a.c(SkArena.frame), stride = a.c(SkPanel.stride);

    // box: the frame of SkBox (rects() draws the same with steps).
    a.label('box');
    a.add(c2, c, c);
    a.sub(wi, w, c2);
    a.sub(hi, h, c2);
    a.add(xc, x, c);
    a.add(yc, y, c);
    a.beq(fill, c0, 'border');
    a.fill(frame, stride, xc, y, wi, h, fill);
    a.fill(frame, stride, x, yc, w, hi, fill);
    a.label('border');
    a.beq(border, c0, 'ret');
    a.add(yb, y, h);
    a.sub(yb, yb, two);
    a.add(xr, x, w);
    a.sub(xr, xr, two);
    a.fill(frame, stride, xc, y, wi, two, border);
    a.fill(frame, stride, xc, yb, wi, two, border);
    a.fill(frame, stride, x, yc, two, hi, border);
    a.fill(frame, stride, xr, yc, two, hi, border);
    final one = a.c(1);
    a.add(x1, x, one);
    a.add(y1, y, one);
    a.add(xw1, x, w);
    a.sub(xw1, xw1, one);
    a.sub(xw2, xw1, one);
    a.add(yh1, y, h);
    a.sub(yh1, yh1, one);
    a.sub(yh2, yh1, one);
    a.sub(xwc, xw1, c);
    a.sub(yhc, yh1, c);
    a.line(frame, stride, x, yc, xc, y, border);
    a.line(frame, stride, x1, yc, xc, y1, border);
    a.line(frame, stride, xwc, y, xw1, yc, border);
    a.line(frame, stride, xwc, y1, xw2, yc, border);
    a.line(frame, stride, x, yhc, xc, yh1, border);
    a.line(frame, stride, x1, yhc, xc, yh2, border);
    a.line(frame, stride, xw1, yhc, xwc, yh1, border);
    a.line(frame, stride, xw2, yhc, xwc, yh2, border);
    a.label('ret');
    a.ret();

    // scene: clear the region, the box, up to two texts, show the region.
    final rx = word(region), ry = word(region + 4);
    final rw = word(region + 8), rh = word(region + 12);
    a.label('scene');
    a.fill(frame, stride, rx, ry, rw, rh, c0);
    a.call('box');
    for (var i = 0; i < 2; i++) {
      final level = word(levels + 4 * i);
      final t = texts + 16 * i;
      a.beq(level, c0, 'text$i');
      a.glyphs(
        a.c(SkArena.font),
        frame,
        stride,
        word(t),
        word(t + 4),
        a.c(2), // MASK
        level,
        word(t + 8),
        word(t + 12),
      );
      a.label('text$i');
    }
    a.draw(frame, stride, rx, ry, rx, ry, rw, rh);
    a.ret();

    final bytes = a.build();
    if (code + bytes.length > codeEnd) throw StateError('library too long');
    boxAt = a.addressOf('box');
    sceneAt = a.addressOf('scene');
    return (code: bytes, pool: a.pool());
  }

  static int boxAt = code;
  static int sceneAt = code;

  /// Host code that draws [box] into the frame (needs the library).
  static void drawBox(SkCode code, SkBox box) {
    build();
    code
      ..write(boxWords, _u32s(box.words))
      ..call(boxAt);
  }

  static List<int> _u32s(List<int> values) {
    final d = ByteData(values.length * 4);
    for (var i = 0; i < values.length; i++) {
      d.setUint32(i * 4, values[i] & 0xffffffff, Endian.little);
    }
    return d.buffer.asUint8List();
  }

  static List<int> u32s(List<int> values) => _u32s(values);
}
