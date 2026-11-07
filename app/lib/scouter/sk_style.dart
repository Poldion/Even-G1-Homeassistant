import 'dart:math';

import '../g1/g1_connection.dart';
import 'sk_font.dart';
import 'sk_protocol.dart';

/// A filled rectangle on the panel.
class SkRect {
  const SkRect(this.x, this.y, this.w, this.h, this.level);

  final int x, y, w, h, level;

  int get bottom => y + h;

  /// The part within rows [top, top + rows), moved up by [top]; null if
  /// none.
  SkRect? clip(int top, int rows) {
    final y0 = max(y, top), y1 = min(bottom, top + rows);
    if (y1 <= y0 || w <= 0) return null;
    return SkRect(x, y0 - top, w, y1 - y0, level);
  }

  @override
  bool operator ==(Object other) =>
      other is SkRect &&
      other.x == x &&
      other.y == y &&
      other.w == w &&
      other.h == h &&
      other.level == level;

  @override
  int get hashCode => Object.hash(x, y, w, h, level);

  @override
  String toString() => 'SkRect($x, $y, $w × $h, $level)';
}

/// A frame with bevelled corners: [c] pixels cut off each corner, a 2-pixel
/// line of level [border] and the inside filled with [fill] (0: neither).
class SkBox {
  const SkBox(
    this.x,
    this.y,
    this.w,
    this.h, {
    this.c = 8,
    this.border = 11,
    this.fill = 0,
  });

  static const thickness = 2;

  final int x, y, w, h, c, border, fill;

  int get bottom => y + h;

  /// The parameter words of [SkLib.box]: x, y, w, h, c, border, fill.
  List<int> get words => [x, y, w, h, c, border, fill];

  /// The same box as rectangles: the bevels as 1-row steps, matching the
  /// two lines per corner of [SkLib.box] (for the arm's dashboard program,
  /// which draws in bands).
  List<SkRect> rects() {
    final out = <SkRect>[];
    if (fill > 0) {
      out
        ..add(SkRect(x + c, y, w - 2 * c, h, fill))
        ..add(SkRect(x, y + c, w, h - 2 * c, fill));
    }
    if (border == 0) return out;
    const t = thickness;
    final b = border;
    out
      ..add(SkRect(x + c, y, w - 2 * c, t, b))
      ..add(SkRect(x + c, y + h - t, w - 2 * c, t, b))
      ..add(SkRect(x, y + c, t, h - 2 * c, b))
      ..add(SkRect(x + w - t, y + c, t, h - 2 * c, b));
    for (var j = 1; j < c; j++) {
      out
        ..add(SkRect(x + c - j, y + j, 2, 1, b))
        ..add(SkRect(x + w - 2 - c + j, y + j, 2, 1, b))
        ..add(SkRect(x + j, y + h - 1 - c + j, 2, 1, b))
        ..add(SkRect(x + w - 2 - j, y + h - 1 - c + j, 2, 1, b));
    }
    return out;
  }
}

/// A line of text: its glyphs start at [x], its band at [y] (the line's
/// top; the baseline is y + ascent).
class SkTextLine {
  const SkTextLine(this.x, this.y, this.text, {this.level = 15});

  final int x, y;
  final String text;
  final int level;
}

/// Where the lines, the frame and the rule of a styled text go.
class SkLayout {
  SkLayout(this.lines, {this.box, this.rule});

  final List<SkTextLine> lines;
  final SkBox? box;
  final SkRect? rule;

  /// Frame and rule as rectangles.
  List<SkRect> get decor => [...?box?.rects(), ?rule];

  // Frame and rule around the text column (textLeft 24 … 616).
  static const frameX = 8;
  static const pad = 12;
  static const ruleGap = 8;
  static const titleLevel = 15;
  static const ruleLevel = 6;

  /// Lays out [lines] (already wrapped) from [top] down, at most to the
  /// panel's bottom row.
  static SkLayout of(
    SkFont font,
    List<String> lines,
    G1TextStyle style, {
    required int top,
    required int left,
    int bottomLimit = SkPanel.height - 1,
  }) {
    final lh = font.lineSpacing;
    final centre = SkPanel.width ~/ 2;
    int centred(String s) => max(0, centre - font.width(s) ~/ 2);
    final titled = style == G1TextStyle.card || style == G1TextStyle.title;
    final out = <SkTextLine>[];
    var y = top;
    for (var i = 0; i < lines.length; i++) {
      if (y + lh > bottomLimit + 1) break;
      final line = lines[i];
      final x = switch (style) {
        G1TextStyle.badge => centred(line),
        _ when titled && i == 0 => centred(line),
        _ => left,
      };
      out.add(SkTextLine(x, y, line));
      y += lh;
      if (titled && i == 0) y += ruleGap;
    }
    if (style == G1TextStyle.plain || out.isEmpty) return SkLayout(out);
    final end = min(y + 8, bottomLimit + 1);
    SkBox? box;
    final boxTop = max(0, top - pad);
    switch (style) {
      case G1TextStyle.frame || G1TextStyle.card:
        box = SkBox(frameX, boxTop, SkPanel.width - 2 * frameX, end - boxTop);
      case G1TextStyle.badge:
        final w = out.map((l) => font.width(l.text)).reduce(max) + 4 * pad;
        final bw = min(SkPanel.width - 2 * frameX, w + w % 2);
        box = SkBox(centre - bw ~/ 2, boxTop, bw, end - boxTop);
      case _:
    }
    SkRect? rule;
    if (titled && out.length > 1) {
      final ry = top + lh + ruleGap ~/ 2 - 1;
      rule = style == G1TextStyle.card
          ? SkRect(
              frameX + pad,
              ry,
              SkPanel.width - 2 * (frameX + pad),
              2,
              ruleLevel,
            )
          : SkRect(left, ry, SkPanel.width - 2 * left, 2, ruleLevel);
    }
    return SkLayout(out, box: box, rule: rule);
  }
}
