import 'dart:math';
import 'dart:typed_data';

/// A step of a turn-by-turn navigation, read from the navigation app's
/// notification (Google Maps): texts and the arrow of the next turn.
class NavUpdate {
  NavUpdate({
    required this.title,
    required this.text,
    this.subText = '',
    this.icon,
  });

  NavUpdate.fromMap(Map<dynamic, dynamic> map)
    : title = map['title'] as String? ?? '',
      text = map['text'] as String? ?? '',
      subText = map['subText'] as String? ?? '',
      icon = map['icon'] as Uint8List?;

  final String title, text, subText;

  /// The app's arrow, [NavArrow.size]² pixels at 4 bpp (null if none).
  final Uint8List? icon;

  static final _distance = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*(km|mi|ft|yd|m)\b',
    caseSensitive: false,
  );

  /// The distance to the turn as the app writes it ("200 m", "1,2 km").
  String? get distance {
    for (final s in [title, text]) {
      final m = _distance.firstMatch(s);
      if (m != null) return m.group(0)!.replaceAll(RegExp(r'\s+'), ' ');
    }
    return null;
  }

  /// The distance in metres, null if there is none.
  int? get meters {
    for (final s in [title, text]) {
      final m = _distance.firstMatch(s);
      if (m == null) continue;
      final v = double.parse(m.group(1)!.replaceAll(',', '.'));
      final f = switch (m.group(2)!.toLowerCase()) {
        'km' => 1000.0,
        'mi' => 1609.344,
        'ft' => 0.3048,
        'yd' => 0.9144,
        _ => 1.0,
      };
      return (v * f).round();
    }
    return null;
  }

  /// What to do, without the distance: the lines of title and text.
  String get instruction {
    final lines = <String>[];
    for (final s in [title, text]) {
      final t = s
          .replaceFirst(_distance, '')
          .replaceAll(RegExp(r'^[\s·,:\-–]+|[\s·,:\-–]+$'), '')
          .trim();
      // "In 200 m": only the word before the distance is left.
      if (t.isEmpty ||
          RegExp(r'^(in|nach)$', caseSensitive: false).hasMatch(t)) {
        continue;
      }
      if (!lines.contains(t)) lines.add(t);
    }
    return lines.join('\n');
  }

  /// The turn, from the instruction's words (English and German).
  NavTurn get turn => NavTurn.of(instruction);
}

/// Kinds of turn, each with an arrow.
enum NavTurn {
  straight,
  slightLeft,
  slightRight,
  left,
  right,
  sharpLeft,
  sharpRight,
  uTurn,
  roundabout,
  destination;

  static bool _has(String s, List<String> words) => words.any(s.contains);

  /// The turn an instruction describes.
  static NavTurn of(String instruction) {
    final s = instruction.toLowerCase();
    final left = _has(s, ['left', 'links']);
    final right = _has(s, ['right', 'rechts']);
    if (_has(s, ['u-turn', 'make a u', 'wenden', 'umkehren'])) return uTurn;
    if (_has(s, ['roundabout', 'kreisverkehr', 'kreisel'])) return roundabout;
    if (_has(s, ['destination', 'arrive', 'ziel', 'angekommen'])) {
      return destination;
    }
    if (_has(s, ['sharp', 'scharf'])) {
      if (left) return sharpLeft;
      if (right) return sharpRight;
    }
    if (_has(s, ['slight', 'keep', 'leicht', 'halten', 'exit', 'ausfahrt'])) {
      if (left) return slightLeft;
      if (right || _has(s, ['exit', 'ausfahrt'])) return slightRight;
    }
    if (left) return NavTurn.left;
    if (right) return NavTurn.right;
    return straight;
  }

  /// The arrow as an emoji (the glasses draw emojis).
  String get emoji => switch (this) {
    straight => '⬆️',
    slightLeft => '↖️',
    slightRight => '↗️',
    left => '⬅️',
    right => '➡️',
    sharpLeft => '↙️',
    sharpRight => '↘️',
    uTurn => '↩️',
    roundabout => '🔄',
    destination => '🏁',
  };
}

/// A turn arrow drawn by the app, for when the navigation app sends none:
/// [size]² pixels at 4 bpp (the left pixel in the high nibble).
class NavArrow {
  static const size = 50;

  static Uint8List icon(NavTurn turn) {
    final px = Float64List(size * size);
    void stroke(List<Point<double>> path, double width) {
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          final p = Point(x + 0.5, y + 0.5);
          for (var i = 0; i + 1 < path.length; i++) {
            final d = _toSegment(p, path[i], path[i + 1]);
            px[y * size + x] = max(
              px[y * size + x],
              (width / 2 + 0.5 - d).clamp(0, 1),
            );
          }
        }
      }
    }

    void head(Point<double> tip, Point<double> from, double len) {
      final dx = tip.x - from.x, dy = tip.y - from.y;
      final l = sqrt(dx * dx + dy * dy);
      final ux = dx / l, uy = dy / l;
      final base = Point(tip.x - ux * len, tip.y - uy * len);
      final a = Point(base.x - uy * len * 0.75, base.y + ux * len * 0.75);
      final b = Point(base.x + uy * len * 0.75, base.y - ux * len * 0.75);
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          if (_inTriangle(Point(x + 0.5, y + 0.5), tip, a, b)) {
            px[y * size + x] = 1;
          }
        }
      }
    }

    Point<double> p(double x, double y) => Point(x, y);
    const w = 7.0, h = 13.0;
    switch (turn) {
      case NavTurn.straight:
        stroke([p(25, 46), p(25, 14)], w);
        head(p(25, 3), p(25, 14), h);
      case NavTurn.left || NavTurn.right:
        final s = turn == NavTurn.right ? 1.0 : -1.0;
        stroke([p(25 - 10 * s, 46), p(25 - 10 * s, 22), p(25 + 8 * s, 22)], w);
        head(p(25 + 21 * s, 22), p(25 + 8 * s, 22), h);
      case NavTurn.slightLeft || NavTurn.slightRight:
        final s = turn == NavTurn.slightRight ? 1.0 : -1.0;
        stroke([p(25 - 6 * s, 46), p(25 - 6 * s, 28), p(25 + 6 * s, 16)], w);
        head(p(25 + 15 * s, 7), p(25 + 6 * s, 16), h);
      case NavTurn.sharpLeft || NavTurn.sharpRight:
        final s = turn == NavTurn.sharpRight ? 1.0 : -1.0;
        stroke([p(25 - 10 * s, 46), p(25 - 10 * s, 10), p(25 + 4 * s, 26)], w);
        head(p(25 + 13 * s, 36), p(25 + 4 * s, 26), h);
      case NavTurn.uTurn:
        stroke([p(33, 46), p(33, 18), p(25, 9), p(17, 18), p(17, 26)], w);
        head(p(17, 38), p(17, 26), h);
      case NavTurn.roundabout:
        final ring = <Point<double>>[
          for (var a = 0.0; a <= 2 * pi + 0.01; a += pi / 16)
            p(25 + 11 * cos(a), 22 + 11 * sin(a)),
        ];
        stroke(ring, 5);
        stroke([p(25, 47), p(25, 33)], w);
        stroke([p(33, 14), p(40, 7)], w);
        head(p(46, 1), p(40, 7), 11);
      case NavTurn.destination:
        stroke([p(14, 47), p(14, 4)], 5);
        for (var y = 0; y < 4; y++) {
          for (var x = 0; x < 4; x++) {
            if ((x + y).isEven) {
              for (var yy = 0; yy < 6; yy++) {
                for (var xx = 0; xx < 7; xx++) {
                  px[(5 + y * 6 + yy) * size + 17 + x * 7 + xx] = 1;
                }
              }
            }
          }
        }
        stroke([p(17, 5), p(44, 5), p(44, 28), p(17, 28)], 2);
    }
    final out = Uint8List(size * size ~/ 2);
    for (var i = 0; i < px.length; i++) {
      final level = (px[i] * 15).round();
      out[i >> 1] |= i.isEven ? level << 4 : level;
    }
    return out;
  }

  static double _toSegment(Point<double> p, Point<double> a, Point<double> b) {
    final dx = b.x - a.x, dy = b.y - a.y;
    final l2 = dx * dx + dy * dy;
    final t = l2 == 0
        ? 0.0
        : (((p.x - a.x) * dx + (p.y - a.y) * dy) / l2).clamp(0.0, 1.0);
    final x = a.x + t * dx - p.x, y = a.y + t * dy - p.y;
    return sqrt(x * x + y * y);
  }

  static bool _inTriangle(
    Point<double> p,
    Point<double> a,
    Point<double> b,
    Point<double> c,
  ) {
    double side(Point<double> u, Point<double> v) =>
        (p.x - v.x) * (u.y - v.y) - (u.x - v.x) * (p.y - v.y);
    final d1 = side(a, b), d2 = side(b, c), d3 = side(c, a);
    final neg = d1 < 0 || d2 < 0 || d3 < 0;
    final pos = d1 > 0 || d2 > 0 || d3 > 0;
    return !(neg && pos);
  }
}

/// Follows a navigation and decides when the glasses show it: at a new
/// step and when the turn comes closer than 500, 200 and 50 m.
class Navigation {
  static const thresholds = [500, 200, 50];

  NavUpdate? current;
  String? _step;
  final _announced = <int>{};

  bool get active => current != null;

  /// Takes an update; true if the glasses should show it now.
  bool update(NavUpdate u) {
    current = u;
    final step =
        '${u.instruction}\u0000${u.icon == null ? '' : _hash(u.icon!)}';
    final m = u.meters;
    if (step != _step) {
      _step = step;
      _announced
        ..clear()
        // Marks already passed: not again for this step.
        ..addAll(thresholds.where((t) => m != null && m <= t * 1.2));
      return true;
    }
    if (m == null) return false;
    for (final t in thresholds) {
      if (m <= t && _announced.add(t)) {
        // The nearer marks count as reached too.
        _announced.addAll(thresholds.where((s) => s > t));
        return true;
      }
    }
    return false;
  }

  void end() {
    current = null;
    _step = null;
    _announced.clear();
  }

  /// The arrow to show: the app's, or one drawn for the turn.
  Uint8List get icon {
    final u = current;
    if (u == null) return NavArrow.icon(NavTurn.straight);
    return u.icon ?? NavArrow.icon(u.turn);
  }

  /// The card beside the arrow: distance, instruction, arrival.
  String get cardText {
    final u = current;
    if (u == null) return '';
    return [
      ?u.distance,
      u.instruction,
      u.subText,
    ].where((s) => s.isNotEmpty).join('\n');
  }

  /// The dashboard while navigating: an emoji arrow with the distance on
  /// its first line (the title of the framed designs).
  String get dashboardText {
    final u = current;
    if (u == null) return '';
    final head = [u.turn.emoji, ?u.distance].join(' ');
    return [
      head,
      u.instruction,
      u.subText,
    ].where((s) => s.isNotEmpty).join('\n');
  }

  static int _hash(Uint8List b) {
    var h = 0;
    for (final v in b) {
      h = (h * 31 + v) & 0x3fffffff;
    }
    return h;
  }
}
