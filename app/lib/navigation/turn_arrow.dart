import 'dart:math';
import 'dart:typed_data';

import 'navigation.dart';

/// A line of the arrow, relative to the arrow's pivot, with its level.
typedef TurnSegment = ({int x0, int y0, int x1, int y1, int level});

/// One picture of the arrow's animation: the arrow turned and scaled
/// (cos and sin × scale, × 4096), moved by (dx, dy), and the panel box its
/// lines then cover (both ends included).
typedef TurnFrame = ({int c, int s, int dx, int dy, (int, int, int, int) box});

/// The navigation's big arrow at the top of the view, above the step's
/// text. With each step it comes closer (small and high to its size,
/// larger the nearer the turn); right at the turn it swings into the
/// direction to take. The glasses' program plays the [frames] itself, one
/// every [SkResident] `arrowPeriodUs` (label `arrow`); this class computes
/// the same lines, so tests and renders show what the glasses draw.
class TurnArrow {
  TurnArrow._(this.cx, this.cy, this.segments, this.frames);

  /// The rows the arrow stays within (the step's text starts below).
  static const top = 6, bottom = 132;

  static const maxSegments = 48;
  static const maxFrames = 20;
  static const outlineLevel = 15;
  static const fillLevel = 6;

  /// The pivot on the panel.
  final int cx, cy;
  final List<TurnSegment> segments;
  final List<TurnFrame> frames;

  /// A segment end ([x], [y] relative to the pivot) in [frame], with the
  /// program's integer arithmetic (DIVS truncates toward zero).
  (int, int) transform(int x, int y, TurnFrame frame) => (
    cx + frame.dx + (x * frame.c + y * frame.s) ~/ 4096,
    cy + frame.dy + (y * frame.c - x * frame.s) ~/ 4096,
  );

  /// The arrow as it comes closer: for a turn [meters] ahead (null:
  /// unknown), from smaller and higher to its size.
  static TurnArrow approach(int? meters) {
    final size = sizeFor(meters);
    return _build([
      for (var k = 0; k <= 7; k++)
        _pose(
          scale: size * (0.55 + 0.45 * _ease(k / 7)),
          dy: -26 * (1 - _ease(k / 7)),
        ),
    ]);
  }

  /// The arrow at the turn: full size, it swings into [turn]'s direction
  /// and moves a little that way; it stays so.
  static TurnArrow at(NavTurn turn) {
    final poses = <_Pose>[];
    void hold(_Pose p, int n) {
      for (var i = 0; i < n; i++) {
        poses.add(p);
      }
    }

    const still = _Pose(1, 0, 0, 0);
    hold(still, 3);
    switch (turn) {
      case NavTurn.straight:
        // Ahead: a push forward, twice.
        for (var r = 0; r < 2; r++) {
          for (var k = 1; k <= 4; k++) {
            poses.add(_pose(scale: 0.88, dy: -12 * sin(k / 4 * pi)));
          }
        }
      case NavTurn.destination:
        // Arrived: it beats twice.
        for (var r = 0; r < 2; r++) {
          for (var k = 1; k <= 4; k++) {
            poses.add(_pose(scale: 1 - 0.25 * sin(k / 4 * pi)));
          }
        }
      case NavTurn.roundabout:
        // Round once, counter-clockwise as the traffic goes.
        for (var k = 1; k <= 10; k++) {
          poses.add(_pose(scale: 0.9, degrees: 36.0 * k));
        }
      default:
        // Visually counter-clockwise is positive: left turns.
        final degrees = switch (turn) {
          NavTurn.slightLeft => 45.0,
          NavTurn.left => 90.0,
          NavTurn.sharpLeft => 135.0,
          NavTurn.slightRight => -45.0,
          NavTurn.right => -90.0,
          NavTurn.sharpRight => -135.0,
          _ => 180.0, // U-turn, by the left
        };
        const steps = 8;
        for (var k = 1; k <= steps; k++) {
          final t = _ease(k / steps);
          final a = degrees * t * pi / 180;
          // Towards where the arrow points (up rotated by a).
          poses.add(
            _pose(
              scale: 0.95,
              degrees: degrees * t,
              dx: -sin(a) * 70 * t,
              dy: -cos(a) * 12 * t,
            ),
          );
        }
    }
    return _build(poses);
  }

  /// The arrow's size for a turn [meters] ahead: larger the nearer.
  static double sizeFor(int? meters) {
    if (meters == null) return 0.75;
    if (meters <= 30) return 1;
    return (1 - (meters - 30) / 470 * 0.4).clamp(0.6, 1.0);
  }

  static double _ease(double t) => t * t * (3 - 2 * t);

  static _Pose _pose({
    required double scale,
    double degrees = 0,
    double dx = 0,
    double dy = 0,
  }) => _Pose(scale, degrees, dx, dy);

  /// The arrow pointing up, [_height] pixels at scale 1: its outline twice
  /// and a fill of lines across.
  static List<TurnSegment> shape() {
    const h = _height / 2;
    const tip = -h, base = -h * 0.2, end = h;
    const head = 36.0, shaft = 14.0;
    final outline = <(double, double)>[
      (0, tip),
      (head, base),
      (shaft, base),
      (shaft, end),
      (-shaft, end),
      (-shaft, base),
      (-head, base),
      (0, tip),
    ];
    final out = <TurnSegment>[];
    void line(double x0, double y0, double x1, double y1, int level) =>
        out.add((
          x0: x0.round(),
          y0: y0.round(),
          x1: x1.round(),
          y1: y1.round(),
          level: level,
        ));
    // The fill first, so the outline is drawn over its ends.
    for (var y = tip + 6; y < end - 2; y += 4) {
      final half = y < base ? head * (y - tip) / (base - tip) - 3 : shaft - 3;
      if (half > 1) line(-half, y, half, y, fillLevel);
    }
    for (final d in [0.0, 1.0]) {
      for (var i = 0; i + 1 < outline.length; i++) {
        final (ax, ay) = outline[i];
        final (bx, by) = outline[i + 1];
        // The second outline one pixel inside.
        final steep = (bx - ax).abs() < (by - ay).abs();
        final ix = steep ? (ax > 0 || bx > 0 ? -d : d) : 0.0;
        final iy = steep ? 0.0 : (ay > 0 ? -d : d);
        line(ax + ix, ay + iy, bx + ix, by + iy, outlineLevel);
      }
    }
    return out;
  }

  static const _height = 104.0;

  static TurnArrow _build(List<_Pose> poses) {
    final segments = shape();
    assert(segments.length <= maxSegments);
    assert(poses.length <= maxFrames);
    const cx = 320, cy = (top + bottom) ~/ 2;
    final frames = <TurnFrame>[];
    for (final p in poses) {
      final a = p.degrees * pi / 180;
      final c = (4096 * p.scale * cos(a)).round();
      final s = (4096 * p.scale * sin(a)).round();
      final dx = p.dx.round(), dy = p.dy.round();
      var x0 = 1 << 30, y0 = 1 << 30, x1 = -(1 << 30), y1 = -(1 << 30);
      final probe = TurnArrow._(cx, cy, const [], const []);
      final f = (c: c, s: s, dx: dx, dy: dy, box: (0, 0, 0, 0));
      for (final seg in segments) {
        for (final (x, y) in [
          probe.transform(seg.x0, seg.y0, f),
          probe.transform(seg.x1, seg.y1, f),
        ]) {
          x0 = min(x0, x);
          y0 = min(y0, y);
          x1 = max(x1, x);
          y1 = max(y1, y);
        }
      }
      if (y0 < top || y1 > bottom || x0 < 0 || x1 >= 640) {
        throw StateError('arrow frame off its area: ($x0, $y0, $x1, $y1)');
      }
      frames.add((c: c, s: s, dx: dx, dy: dy, box: (x0, y0, x1, y1)));
    }
    return TurnArrow._(cx, cy, segments, frames);
  }

  /// The words the program reads (at [SkResident] `arrowData`).
  Uint8List data() {
    final b = BytesBuilder();
    void w(int v) =>
        b.add([v & 0xff, v >> 8 & 0xff, v >> 16 & 0xff, v >> 24 & 0xff]);
    for (final v in [segments.length, cx, cy, frames.length, 0, 0, 0, 0]) {
      w(v);
    }
    for (final f in frames) {
      for (final v in [f.c, f.s, f.dx, f.dy, f.box.$1, f.box.$2, f.box.$3]) {
        w(v);
      }
      w(f.box.$4);
    }
    for (var k = frames.length; k < maxFrames; k++) {
      for (var i = 0; i < 8; i++) {
        w(0);
      }
    }
    for (final s in segments) {
      for (final v in [s.x0, s.y0, s.x1, s.y1, s.level]) {
        w(v);
      }
    }
    return b.toBytes();
  }

  /// Byte offsets in [data].
  static const framesAt = 32, frameBytes = 32;
  static const segmentsAt = framesAt + frameBytes * maxFrames;
  static const dataMax = segmentsAt + 20 * maxSegments;

  /// Draws [frame] as the program does into a 4-bpp panel image ([panel],
  /// 320 bytes per row), after the frame before it: the two boxes cleared,
  /// then the lines.
  void drawInto(Uint8List panel, int frame) {
    final f = frames[frame];
    final before = frame > 0 ? frames[frame - 1].box : (cx, cy, cx, cy);
    final x0 = min(f.box.$1, before.$1), y0 = min(f.box.$2, before.$2);
    final x1 = max(f.box.$3, before.$3), y1 = max(f.box.$4, before.$4);
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        _set(panel, x, y, 0);
      }
    }
    for (final s in segments) {
      final a = transform(s.x0, s.y0, f), b = transform(s.x1, s.y1, f);
      line(panel, a.$1, a.$2, b.$1, b.$2, s.level);
    }
  }

  static void _set(Uint8List panel, int x, int y, int level) {
    if (x < 0 || y < 0 || x >= 640 || y >= 480) return;
    final i = y * 320 + (x >> 1);
    panel[i] = x.isEven
        ? (panel[i] & 0x0f) | level << 4
        : (panel[i] & 0xf0) | level;
  }

  /// LINE as ScouterKit draws it (VM.md §3.6, vm_line): Bresenham with the
  /// ends ordered so that the longer axis increases.
  static void line(Uint8List panel, int x0, int y0, int x1, int y1, int level) {
    final dx = (x1 - x0).abs(), dy = (y1 - y0).abs();
    if (dx >= dy) {
      if (x0 > x1) (x0, y0, x1, y1) = (x1, y1, x0, y0);
      var d = 2 * dy - dx;
      for (var x = x0, y = y0; x <= x1; x++) {
        _set(panel, x, y, level);
        if (d > 0) {
          y += y1 > y0 ? 1 : -1;
          d -= 2 * dx;
        }
        d += 2 * dy;
      }
    } else {
      if (y0 > y1) (x0, y0, x1, y1) = (x1, y1, x0, y0);
      var d = 2 * dx - dy;
      for (var y = y0, x = x0; y <= y1; y++) {
        _set(panel, x, y, level);
        if (d > 0) {
          x += x1 > x0 ? 1 : -1;
          d -= 2 * dy;
        }
        d += 2 * dx;
      }
    }
  }
}

class _Pose {
  const _Pose(this.scale, this.degrees, this.dx, this.dy);

  final double scale, degrees, dx, dy;
}
