import 'package:flutter/services.dart';

import 'sk_font.dart';

/// Emojis for the glasses: Noto Emoji (SIL Open Font License 1.1),
/// rasterised once to 1-bpp glyphs in a 22-pixel cell (advance 24) and
/// shipped as a font blob. The app copies the emojis a text uses into
/// empty glyph slots of the font on the arms, so `GLYPHS` draws them like
/// any other character.
class SkEmoji {
  static const asset = 'assets/scouter/emoji_22.skf';

  /// Slots in the arms' font, glyph width, bitmap bytes per slot.
  static const slots = 160;
  static const advance = 24;
  static const slotBytes = 61; // 22 × 22 pixels at most

  static Future<SkFont>? _font;

  static Future<SkFont> load() => _font ??= rootBundle
      .load(asset)
      .then(
        (d) => SkFont.parse(
          d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes),
        ),
      );

  /// [text] without what only joins or styles emojis: variation
  /// selectors, the zero-width joiner, skin tones and tag characters.
  static String clean(String text) => String.fromCharCodes(
    text.runes.where(
      (cp) =>
          cp != 0xFE0E &&
          cp != 0xFE0F &&
          cp != 0x200D &&
          !(cp >= 0x1F3FB && cp <= 0x1F3FF) &&
          !(cp >= 0xE0020 && cp <= 0xE007F),
    ),
  );
}
