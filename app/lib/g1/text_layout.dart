import 'package:flutter/painting.dart';

/// Splits text into lines and screens the way the G1 firmware expects.
///
/// The display is ~488 px wide and shows 5 lines per screen (values from the
/// official demo app).
class G1TextLayout {
  static const double maxWidth = 488;
  static const double fontSize = 21;
  static const int linesPerScreen = 5;

  /// Wraps [text] into display lines.
  static List<String> lines(String text, {double width = maxWidth}) {
    final result = <String>[];
    const style = TextStyle(fontSize: fontSize);
    for (final raw in text.split('\n')) {
      final paragraph = raw.trim();
      if (paragraph.isEmpty) continue;
      final painter = TextPainter(
        text: TextSpan(text: paragraph, style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width);
      var start = 0;
      for (final _ in painter.computeLineMetrics()) {
        final boundary = painter.getLineBoundary(TextPosition(offset: start));
        if (boundary.end <= start) break;
        result.add(paragraph.substring(boundary.start, boundary.end).trim());
        start = boundary.end;
      }
      painter.dispose();
    }
    return result;
  }

  /// Groups lines into screens of [linesPerScreen] lines.
  ///
  /// Short texts are vertically centered like in the official app.
  static List<String> screens(List<String> lines) {
    if (lines.isEmpty) return [''];
    if (lines.length <= linesPerScreen) {
      final padding = switch (lines.length) {
        <= 3 => '\n\n',
        4 => '\n',
        _ => '',
      };
      return ['$padding${lines.map((l) => '$l\n').join()}'];
    }
    return [
      for (var i = 0; i < lines.length; i += linesPerScreen)
        lines
            .sublist(i, (i + linesPerScreen).clamp(0, lines.length))
            .map((l) => '$l\n')
            .join(),
    ];
  }
}
