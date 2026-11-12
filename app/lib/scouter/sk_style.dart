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
  const SkTextLine(
    this.x,
    this.y,
    this.text, {
    this.level = 15,
    this.bold = false,
  });

  final int x, y;
  final String text;
  final int level;

  /// Drawn twice, the second time one pixel to the right (dark text on
  /// the lab bar, which reads poorly in the thin font).
  final bool bold;
}

/// Where the lines, the frame and the rule of a styled text go.
class SkLayout {
  SkLayout(this.lines, {this.box, this.rule, this.fills = const []});

  final List<SkTextLine> lines;
  final SkBox? box;
  final SkRect? rule;

  /// Further shapes, drawn in order after the box (lab design).
  final List<SkRect> fills;

  /// Frame, rule and shapes as rectangles.
  List<SkRect> get decor => [...?box?.rects(), ?rule, ...fills];

  /// Rule and shapes: what [SkLib.rects] draws after [SkLib.box].
  List<SkRect> get extra => [?rule, ...fills];

  // Lab design set.
  static const barLevel = 12;
  static const bracketLevel = 13;
  static const bracketArm = 28;
  static const bracketThickness = 3;

  /// Corner brackets (L shapes) of the rectangle x, y, w, h.
  static List<SkRect> brackets(
    int x,
    int y,
    int w,
    int h, {
    int arm = bracketArm,
    int t = bracketThickness,
    int level = bracketLevel,
  }) => [
    SkRect(x, y, arm, t, level),
    SkRect(x, y, t, arm, level),
    SkRect(x + w - arm, y, arm, t, level),
    SkRect(x + w - t, y, t, arm, level),
    SkRect(x, y + h - t, arm, t, level),
    SkRect(x, y + h - arm, t, arm, level),
    SkRect(x + w - arm, y + h - t, arm, t, level),
    SkRect(x + w - t, y + h - arm, t, arm, level),
  ];

  /// A bar of level [barLevel] with a dark square at its left and, if
  /// [stripes], five dark slots at its right (hazard stripes).
  static List<SkRect> bar(int x, int y, int w, int h, {bool stripes = true}) =>
      [
        SkRect(x, y, w, h, barLevel),
        SkRect(x + 6, y + (h - 8) ~/ 2, 8, 8, 0),
        if (stripes)
          for (var i = 0; i < 5; i++) SkRect(x + w - 10 - 9 * i, y, 4, h, 0),
      ];

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
    if (style == G1TextStyle.lab ||
        style == G1TextStyle.labBadge ||
        style == G1TextStyle.labTerminal) {
      return _lab(
        font,
        lines,
        style,
        top: top,
        left: left,
        bottomLimit: bottomLimit,
      );
    }
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

  /// Lab design set: the first line dark on a bar, the rest below it,
  /// corner brackets around all (badge: centred and fitted to the text).
  static SkLayout _lab(
    SkFont font,
    List<String> lines,
    G1TextStyle style, {
    required int top,
    required int left,
    required int bottomLimit,
  }) {
    final lh = font.lineSpacing;
    final badge = style == G1TextStyle.labBadge;
    final centre = SkPanel.width ~/ 2;
    final widest = lines.isEmpty ? 0 : lines.map(font.width).reduce(max);
    final w = badge
        ? min(SkPanel.width - 2 * frameX, widest + 4 * pad + 24)
        : SkPanel.width - 2 * frameX;
    final x0 = badge ? centre - w ~/ 2 : frameX;
    final out = <SkTextLine>[];
    var y = top;
    for (var i = 0; i < lines.length; i++) {
      if (y + lh > bottomLimit + 1) break;
      final line = lines[i];
      final x = badge
          ? centre - font.width(line) ~/ 2 + (i == 0 ? 8 : 0)
          : (i == 0 ? left + 16 : left);
      out.add(
        i == 0
            ? SkTextLine(x, y, line, level: 0, bold: true)
            : SkTextLine(x, y, line),
      );
      y += lh;
      if (i == 0) y += ruleGap;
    }
    if (out.isEmpty) return SkLayout(out);
    final end = min(y + 8, bottomLimit + 1);
    final boxTop = max(0, top - pad);
    final inset = badge ? 8 : 10;
    final last = out.last;
    return SkLayout(
      out,
      fills: [
        ...bar(x0 + inset, top - 1, w - 2 * inset, lh + 2, stripes: !badge),
        ...brackets(x0, boxTop, w, end - boxTop),
        // The terminal's block cursor after the last line.
        if (style == G1TextStyle.labTerminal && out.length > 1)
          SkRect(
            min(last.x + font.width(last.text) + 4, SkPanel.width - 24),
            last.y + 4,
            11,
            font.ascent - 2,
            15,
          ),
      ],
    );
  }

  /// Where a small label goes for this layout: on the frame's top line
  /// (after a bracket arm in the lab design), else above the first line.
  /// [h] is the label's height.
  /// Where the connection symbols go: mirrored from [labelAt], at the
  /// top right.
  ({int x, int y}) statusAt({required int left, required int top}) {
    final at = labelAt(SkStatusIcons.height, left: left, top: top);
    return (x: SkPanel.width - at.x - SkStatusIcons.width, y: at.y);
  }

  ({int x, int y}) labelAt(int h, {required int left, required int top}) {
    final frameTop =
        box?.y ?? (fills.isEmpty ? null : fills.map((r) => r.y).reduce(min));
    if (frameTop == null) return (x: left, y: max(0, top - h - 4));
    final lab = box == null;
    return (
      x: lab ? frameX + bracketArm + 6 : frameX + 14,
      y: max(0, frameTop - h ~/ 2 + 1),
    );
  }
}

/// The connection symbols at the dashboard's top right: a phone and a
/// server (Home Assistant), each struck through while its connection is
/// down. Drawn by the glasses' program and, for a dashboard the app shows,
/// by the app.
class SkStatusIcons {
  static const width = 38, height = 18;
  static const level = 11;

  /// Filled rectangles relative to the area: x, y, w, h, ink (else a hole).
  static const phone = [
    (4, 1, 10, 16, true),
    (6, 3, 6, 10, false),
    (8, 14, 2, 2, false),
  ];
  static const server = [
    (20, 1, 14, 7, true),
    (22, 3, 10, 3, false),
    (29, 4, 2, 1, true),
    (20, 10, 14, 7, true),
    (22, 12, 10, 3, false),
    (29, 13, 2, 1, true),
  ];

  /// The stroke through a symbol from x to x + w: dark edges, then the ink
  /// (x0, y0, x1, y1, ink).
  static List<(int, int, int, int, bool)> strike(int x, int w) => [
    for (final (d, ink) in [(1, false), (-2, false), (0, true), (-1, true)])
      (x - 1 + d, height - 1, x + w + d, 0, ink),
  ];

  static final phoneStrike = strike(4, 10);
  static final serverStrike = strike(20, 14);
}
