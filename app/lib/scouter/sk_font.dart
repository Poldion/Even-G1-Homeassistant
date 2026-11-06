import 'dart:typed_data';

/// A ScouterKit font blob (VM.md §4.2): 1-bpp glyphs the arm draws with
/// `GLYPHS`. The app ships Departure Mono at 11 px and draws it scaled ×2.
class SkFont {
  SkFont._(
    this.blob,
    this._index,
    this.ascent,
    this.descent,
    this.lineSpacing,
    this._advances,
  );

  /// Parses a blob.
  factory SkFont.parse(Uint8List blob) {
    final d = ByteData.sublistView(blob);
    if (blob.length < 16 ||
        blob[0] != 0x53 ||
        blob[1] != 0x4B ||
        blob[2] != 0x46 ||
        blob[3] != 1) {
      throw const FormatException('not a ScouterKit font blob');
    }
    final n = d.getUint16(8, Endian.little);
    final index = <int, int>{};
    final advances = Uint8List(n);
    for (var i = 0; i < n; i++) {
      final cp = d.getUint32(16 + 12 * n + 4 * i, Endian.little);
      advances[i] = blob[16 + 12 * i + 6];
      // Glyphs < 62 without their character hold codepoint 0.
      if (cp != 0 || i == 0) index.putIfAbsent(cp, () => i);
    }
    return SkFont._(blob, index, blob[12], blob[13], blob[14], advances);
  }

  final Uint8List blob;
  final Map<int, int> _index;
  final int ascent;
  final int descent;
  final int lineSpacing;
  final Uint8List _advances;

  int get glyphCount => _advances.length;

  /// Glyph index of a character: U+FFFD or '?' for a missing one.
  int glyphOf(int codepoint) =>
      _index[codepoint] ?? _index[0xFFFD] ?? _index[0x3F] ?? 0;

  int advanceOf(int glyph) => _advances[glyph];

  /// Glyph indices of [text], as LEB128 varints (the `GLYPHS` text).
  Uint8List encode(String text) {
    final out = BytesBuilder(copy: false);
    for (final rune in text.runes) {
      var g = glyphOf(rune);
      while (g >= 0x80) {
        out.addByte((g & 0x7f) | 0x80);
        g >>= 7;
      }
      out.addByte(g);
    }
    return out.takeBytes();
  }

  /// Width of [text] in pixels.
  int width(String text) {
    var w = 0;
    for (final rune in text.runes) {
      w += advanceOf(glyphOf(rune));
    }
    return w;
  }

  /// The same font with every pixel [factor] × [factor] times as large, and
  /// only the glyphs whose codepoints [keep] accepts (and the 62 slots of
  /// `0`–`9`, `A`–`Z`, `a`–`z`, which keep their indices).
  SkFont scaled(int factor, {bool Function(int codepoint)? keep}) {
    final src = ByteData.sublistView(blob);
    final n = glyphCount;
    final kept = <int>[];
    for (var i = 0; i < n; i++) {
      final cp = src.getUint32(16 + 12 * n + 4 * i, Endian.little);
      if (i < 62 || keep == null || keep(cp)) kept.add(i);
    }
    final m = kept.length;
    // Bitmaps of the scaled glyphs.
    final bits = <Uint8List>[];
    final dims = <List<int>>[];
    for (final i in kept) {
      final e = 16 + 12 * i;
      final off = src.getUint32(e, Endian.little);
      final w = blob[e + 4];
      final h = blob[e + 5];
      final sw = w * factor;
      final sh = h * factor;
      final out = Uint8List((sw * sh + 7) ~/ 8);
      for (var y = 0; y < sh; y++) {
        for (var x = 0; x < sw; x++) {
          final bit = off + (y ~/ factor) * w + (x ~/ factor);
          if (blob[bit >> 3] & (0x80 >> (bit & 7)) != 0) {
            final o = y * sw + x;
            out[o >> 3] |= 0x80 >> (o & 7);
          }
        }
      }
      bits.add(out);
      dims.add([sw, sh]);
    }
    final header = 16 + 16 * m;
    var size = header;
    for (final b in bits) {
      size += b.length;
    }
    final out = Uint8List(size);
    final d = ByteData.sublistView(out);
    out.setRange(0, 4, [0x53, 0x4B, 0x46, 1]);
    d.setUint32(4, size, Endian.little);
    d.setUint16(8, m, Endian.little);
    d.setUint16(10, 0, Endian.little); // no kerning (a monospaced font)
    out[12] = (ascent * factor).clamp(0, 255);
    out[13] = (descent * factor).clamp(0, 255);
    out[14] = (lineSpacing * factor).clamp(0, 255);
    var pos = header;
    for (var j = 0; j < m; j++) {
      final i = kept[j];
      final e = 16 + 12 * i;
      final o = 16 + 12 * j;
      final hasBitmap = dims[j][0] > 0 && dims[j][1] > 0;
      d.setUint32(o, hasBitmap ? pos * 8 : 0, Endian.little);
      out[o + 4] = dims[j][0].clamp(0, 255);
      out[o + 5] = dims[j][1].clamp(0, 255);
      out[o + 6] = (blob[e + 6] * factor).clamp(0, 255);
      d.setInt16(
        o + 8,
        src.getInt16(e + 8, Endian.little) * factor,
        Endian.little,
      );
      d.setInt16(
        o + 10,
        src.getInt16(e + 10, Endian.little) * factor,
        Endian.little,
      );
      d.setUint32(
        16 + 12 * m + 4 * j,
        src.getUint32(16 + 12 * n + 4 * i, Endian.little),
        Endian.little,
      );
      out.setRange(pos, pos + bits[j].length, bits[j]);
      pos += bits[j].length;
    }
    return SkFont.parse(out);
  }

  /// The characters this app shows: Latin up to U+024F, general
  /// punctuation, currency and arrows, the replacement character.
  static bool textCodepoint(int cp) =>
      (cp >= 0x20 && cp <= 0x24F) ||
      (cp >= 0x2010 && cp <= 0x205E) ||
      (cp >= 0x20A0 && cp <= 0x20BF) ||
      (cp >= 0x2190 && cp <= 0x21FF) ||
      cp == 0xFFFD;
}
