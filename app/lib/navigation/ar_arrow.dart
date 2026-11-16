import 'dart:math';
import 'dart:typed_data';

import 'navigation.dart';

/// A line of the arrow, relative to the arrow's pivot, with its level.
typedef ArSegment = ({int x0, int y0, int x1, int y1, int level});

/// The navigation's turn arrow as if painted on the street ahead: a band
/// from your feet to the turn and around it, in perspective, closer and
/// larger the nearer the turn is (stage 1). The glasses' program moves it
/// with the head's pitch and turns it against the head's roll, so it stays
/// roughly on the street (stage 2, [SkResident] `arrow`).
///
/// The program draws the [segments] as lines, each end transformed by
/// [transform]; this class computes the same, so tests and renders show
/// exactly what the glasses draw.
class ArArrow {
  ArArrow._(this.cx, this.cy, this.segments, this.boxes, this.top, this.bottom);

  /// The head's roll is followed up to ±[rollMax] degrees.
  static const rollMax = 10;
  static const rolls = 2 * rollMax + 1;

  /// Pixels per degree of pitch; the arrow is at rest at [pitchRest]
  /// (looking slightly down, as when walking).
  static const gain = 3;
  static const pitchRest = -10;

  static const maxSegments = 64;
  static const outlineLevel = 15;
  static const chevronLevel = 7;
  static const ringLevel = 11;

  /// sin and cos of −[rollMax]…[rollMax] degrees, × 4096.
  static final sinTable = [
    for (var r = -rollMax; r <= rollMax; r++)
      (4096 * sin(r * pi / 180)).round(),
  ];
  static final cosTable = [
    for (var r = -rollMax; r <= rollMax; r++)
      (4096 * cos(r * pi / 180)).round(),
  ];

  /// The pivot on the panel (the arrow turns around it).
  final int cx, cy;
  final List<ArSegment> segments;

  /// Per roll (index roll + [rollMax]): the panel box (x0, y0, x1, y1, ends
  /// included) of the arrow at shift 0.
  final List<(int, int, int, int)> boxes;

  /// The rows the arrow stays within whatever the head does: it never
  /// covers the text above nor leaves the panel.
  final int top, bottom;

  /// A panel point of a segment end ([x], [y] relative to the pivot) at
  /// [roll] degrees (−[rollMax]…[rollMax]) and [shift] pixels down, with the
  /// program's integer arithmetic (DIVS truncates toward zero).
  (int, int) transform(int x, int y, int roll, int shift) {
    final s = sinTable[roll + rollMax], c = cosTable[roll + rollMax];
    return (cx + (x * c + y * s) ~/ 4096, cy + shift + (y * c - x * s) ~/ 4096);
  }

  /// The shift for a head [pitch] at [roll] (−[rollMax]…[rollMax]), as the
  /// program computes it: within [top] and [bottom] at that roll.
  int shiftFor(int pitch, int roll) {
    final b = boxes[roll + rollMax];
    var s = (pitch - pitchRest) * gain;
    if (s < top - b.$2) s = top - b.$2;
    if (s > bottom - b.$4) s = bottom - b.$4;
    return s;
  }

  /// The roll the program follows for a head [roll].
  static int rollFor(int roll) => roll.clamp(-rollMax, rollMax);

  /// The arrow for [turn], the turn [meters] ahead (null: unknown), drawn
  /// between [top] and [bottom] (panel rows, both included); null if there
  /// is no room for it.
  static ArArrow? build(
    NavTurn turn,
    int? meters, {
    required int top,
    int bottom = 477,
    int width = 640,
  }) {
    final zt = turnDepth(meters);
    final ground = _ground(turn, zt);
    // Perspective from a little behind the eye: (u, v), v = 0 at the
    // nearest point, growing ahead. Then scaled into the room above the
    // bottom: a near turn makes a short band, so a larger arrow.
    (double, double) uv(double x, double z) =>
        (x / (z + _back), 1 / (_z0 + _back) - 1 / (z + _back));
    var u0 = 0.0, u1 = 0.0, v1 = 0.0;
    for (final l in ground.lines) {
      for (final (x, z) in [(l.$1, l.$2), (l.$3, l.$4)]) {
        final (u, v) = uv(x, z);
        u0 = min(u0, u);
        u1 = max(u1, u);
        v1 = max(v1, v);
      }
    }
    final base = bottom - _room;
    final height = base - top - _upRoom;
    final maxWidth = width - 2 * _side;
    // Half the width each side of the middle: the band's start stays there.
    final halfU = max(-u0, u1);
    var sy = height / v1;
    var sx = sy * _wide;
    if (sx * 2 * halfU > maxWidth) {
      final k = maxWidth / (sx * 2 * halfU);
      sx *= k;
      sy *= k;
    }
    if (bottom - top < _minRows) return null;
    for (var scale = 1.0; scale > 0.3; scale *= 0.92) {
      final arrow = _project(
        ground,
        uv,
        sx * scale,
        sy * scale,
        base,
        top,
        bottom,
        width,
        // Small enough at last: it fits, if with little room to move.
        fits: scale < 0.4,
      );
      if (arrow != null) return arrow;
    }
    return null;
  }

  /// How far ahead the turn is drawn (m): nearer as it comes closer.
  static double turnDepth(int? meters) {
    if (meters == null) return 6.5;
    if (meters <= 30) return 3.5;
    return min(9, 3.5 + meters / 60);
  }

  /// Rows kept free below the arrow at rest: it moves down when you look
  /// up.
  static const _room = 30;

  /// The nearest point of the band (m).
  static const _z0 = 1.5;

  /// The view from further back than the eye, and wider than tall: a
  /// milder perspective, so the turn far ahead stays readable.
  static const _back = 5.0, _wide = 0.7;

  /// Fewer rows than this: no arrow.
  static const _minRows = 90;

  /// Rows kept free above the arrow (it moves up when you look down) and
  /// columns at the sides.
  static const _upRoom = 40, _side = 30;

  /// Half the band's width, the head's half width and length (m).
  static const _half = 0.6, _headHalf = 1.3, _headLength = 1.5;

  static ArArrow? _project(
    _Ground g,
    (double, double) Function(double x, double z) uv,
    double sx,
    double sy,
    int base,
    int top,
    int bottom,
    int width, {
    bool fits = false,
  }) {
    (double, double) screen(double x, double z) {
      final (u, v) = uv(x, z);
      return (width / 2 + sx * u, base - sy * v);
    }

    final lines = <(double, double, double, double, int)>[];
    for (final l in g.lines) {
      final a = screen(l.$1, l.$2), b = screen(l.$3, l.$4);
      lines.add((a.$1, a.$2, b.$1, b.$2, l.$5));
    }
    var minY = double.infinity, maxY = -double.infinity;
    var minX = double.infinity, maxX = -double.infinity;
    for (final l in lines) {
      minX = min(minX, min(l.$1, l.$3));
      maxX = max(maxX, max(l.$1, l.$3));
      minY = min(minY, min(l.$2, l.$4));
      maxY = max(maxY, max(l.$2, l.$4));
    }
    final cx = ((minX + maxX) / 2).round(), cy = ((minY + maxY) / 2).round();
    final segments = <ArSegment>[];
    for (final l in lines) {
      final s = (
        x0: l.$1.round() - cx,
        y0: l.$2.round() - cy,
        x1: l.$3.round() - cx,
        y1: l.$4.round() - cy,
        level: l.$5,
      );
      segments.add(s);
      if (s.level == outlineLevel) {
        // The outline twice: one pixel across the line.
        final steep = (s.x1 - s.x0).abs() < (s.y1 - s.y0).abs();
        segments.add((
          x0: s.x0 + (steep ? 1 : 0),
          y0: s.y0 + (steep ? 0 : 1),
          x1: s.x1 + (steep ? 1 : 0),
          y1: s.y1 + (steep ? 0 : 1),
          level: s.level,
        ));
      }
    }
    if (segments.length > maxSegments) {
      // Chevrons first, then the doubled outline go.
      segments.removeWhere((s) => s.level == chevronLevel);
    }
    if (segments.length > maxSegments) segments.length = maxSegments;
    final probe = ArArrow._(cx, cy, segments, const [], top, bottom);
    final boxes = <(int, int, int, int)>[];
    for (var r = -rollMax; r <= rollMax; r++) {
      var x0 = 1 << 30, y0 = 1 << 30, x1 = -(1 << 30), y1 = -(1 << 30);
      for (final s in segments) {
        for (final (px, py) in [
          probe.transform(s.x0, s.y0, r, 0),
          probe.transform(s.x1, s.y1, r, 0),
        ]) {
          x0 = min(x0, px);
          y0 = min(y0, py);
          x1 = max(x1, px);
          y1 = max(y1, py);
        }
      }
      boxes.add((x0, y0, x1, y1));
    }
    final left = boxes.map((b) => b.$1).reduce(min);
    final right = boxes.map((b) => b.$3).reduce(max);
    if (left < 0 || right >= width) return null;
    // At every roll the arrow fits between top and bottom.
    for (final b in boxes) {
      if (b.$4 - b.$2 > bottom - top) return null;
    }
    final arrow = ArArrow._(cx, cy, segments, boxes, top, bottom);
    if (fits) return arrow;
    // Upright, room to move both ways from rest.
    final b = boxes[rollMax];
    if (top - b.$2 > -30 || bottom - b.$4 < 12) return null;
    return arrow;
  }

  /// The words the program reads (at [SkResident] `arrowData`).
  Uint8List data() {
    final b = BytesBuilder();
    void w(int v) =>
        b.add([v & 0xff, v >> 8 & 0xff, v >> 16 & 0xff, v >> 24 & 0xff]);
    for (final v in [
      segments.length,
      cx,
      cy,
      top,
      bottom,
      gain,
      -pitchRest,
      0,
    ]) {
      w(v);
    }
    sinTable.forEach(w);
    w(0);
    cosTable.forEach(w);
    w(0);
    for (final (x0, y0, x1, y1) in boxes) {
      w(x0);
      w(y0);
      w(x1);
      w(y1);
    }
    for (final s in segments) {
      w(s.x0);
      w(s.y0);
      w(s.x1);
      w(s.y1);
      w(s.level);
    }
    return b.toBytes();
  }

  /// Byte offsets in [data].
  static const sinAt = 32, cosAt = sinAt + 4 * (rolls + 1);
  static const boxesAt = cosAt + 4 * (rolls + 1);
  static const segmentsAt = boxesAt + 16 * rolls;
  static const dataMax = segmentsAt + 20 * maxSegments;

  /// Draws the arrow as the program does into a 4-bpp panel image ([frame],
  /// 320 bytes per row) for a head at [pitch] and [roll] degrees.
  void drawInto(Uint8List frame, {int pitch = pitchRest, int roll = 0}) {
    final r = rollFor(roll), shift = shiftFor(pitch, r);
    for (final s in segments) {
      final a = transform(s.x0, s.y0, r, shift);
      final b = transform(s.x1, s.y1, r, shift);
      line(frame, a.$1, a.$2, b.$1, b.$2, s.level);
    }
  }

  /// LINE as ScouterKit draws it (VM.md §3.6), into a 640 × 480 4-bpp
  /// image.
  static void line(Uint8List frame, int x0, int y0, int x1, int y1, int level) {
    void set(int x, int y) {
      if (x < 0 || y < 0 || x >= 640 || y >= 480) return;
      final i = y * 320 + (x >> 1);
      frame[i] = x.isEven
          ? (frame[i] & 0x0f) | level << 4
          : (frame[i] & 0xf0) | level;
    }

    // Bresenham as ScouterKit's vm_line: the ends ordered so that the
    // longer axis increases.
    final dx = (x1 - x0).abs(), dy = (y1 - y0).abs();
    if (dx >= dy) {
      if (x0 > x1) (x0, y0, x1, y1) = (x1, y1, x0, y0);
      var d = 2 * dy - dx;
      for (var x = x0, y = y0; x <= x1; x++) {
        set(x, y);
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
        set(x, y);
        if (d > 0) {
          x += x1 > x0 ? 1 : -1;
          d -= 2 * dy;
        }
        d += 2 * dx;
      }
    }
  }

  /// The arrow's lines on the ground (x right, z ahead, m) and their levels.
  static _Ground _ground(NavTurn turn, double zt) {
    final g = _Ground();
    const l = 2.4;
    final s = switch (turn) {
      NavTurn.right || NavTurn.slightRight || NavTurn.sharpRight => 1.0,
      _ => -1.0,
    };
    switch (turn) {
      case NavTurn.straight:
        g.band([(0, _z0), (0, zt + 2.5)], head: true);
      case NavTurn.left || NavTurn.right:
        g.band([(0, _z0), (0, zt), (s * l, zt)], head: true);
      case NavTurn.slightLeft || NavTurn.slightRight:
        g.band([(0, _z0), (0, zt), (s * 1.9, zt + 1.9)], head: true);
      case NavTurn.sharpLeft || NavTurn.sharpRight:
        g.band([(0, _z0), (0, zt + 1), (s * 1.9, zt + 1 - 1.5)], head: true);
      case NavTurn.uTurn:
        const r = 1.0;
        g.band([
          (0, _z0),
          (0, zt),
          for (var a = 1; a < 8; a++)
            (-r + r * cos(a * pi / 8), zt + r * sin(a * pi / 8)),
          (-2 * r, zt),
          (-2 * r, zt - 1.6),
        ], head: true);
      case NavTurn.roundabout:
        const r = 1.3;
        g.band([(0, _z0), (0, zt - r)], head: false);
        g.ring(0, zt, r);
        g.band([(0, zt + r), (0, zt + r + 2.2)], head: true);
      case NavTurn.destination:
        g.band([(0, _z0), (0, zt)], head: false);
        // A finish line: a grid across the street.
        for (var k = 0; k < 3; k++) {
          g.line(-1.2, zt + 0.4 * k, 1.2, zt + 0.4 * k, outlineLevel);
        }
        for (var k = 0; k <= 4; k++) {
          final x = -1.2 + 0.6 * k;
          g.line(x, zt, x, zt + 0.8, ringLevel);
        }
    }
    // Chevrons along the approach.
    final end = turn == NavTurn.straight ? zt + 1.4 : zt - 1;
    for (var z = _z0 + 0.7, n = 0; z + 0.5 < end && n < 3; z += 1.3, n++) {
      g.line(-0.28, z, 0, z + 0.4, chevronLevel);
      g.line(0, z + 0.4, 0.28, z, chevronLevel);
    }
    return g;
  }
}

/// Lines on the ground: (x0, z0, x1, z1, level).
class _Ground {
  final lines = <(double, double, double, double, int)>[];

  void line(double x0, double z0, double x1, double z1, int level) =>
      lines.add((x0, z0, x1, z1, level));

  /// A band along [path], closed at the start, with an arrow head at the
  /// end or closed there too.
  void band(List<(double, double)> path, {required bool head}) {
    const half = ArArrow._half;
    final left = <(double, double)>[], right = <(double, double)>[];
    for (var i = 0; i < path.length; i++) {
      final p = path[i];
      final a = path[max(0, i - 1)], b = path[min(path.length - 1, i + 1)];
      // The direction there and its normal; a mitre at corners.
      var (dx, dz) = (b.$1 - a.$1, b.$2 - a.$2);
      final len = sqrt(dx * dx + dz * dz);
      dx /= len;
      dz /= len;
      var k = 1.0;
      if (i > 0 && i < path.length - 1) {
        final (ux, uz) = _unit(p.$1 - a.$1, p.$2 - a.$2);
        final cosHalf = (dx * ux + dz * uz);
        k = 1 / max(0.5, cosHalf);
      }
      // Left of the direction (x right, z ahead): (−dz, dx).
      left.add((p.$1 - dz * half * k, p.$2 + dx * half * k));
      right.add((p.$1 + dz * half * k, p.$2 - dx * half * k));
    }
    void poly(List<(double, double)> pts) {
      for (var i = 0; i + 1 < pts.length; i++) {
        line(
          pts[i].$1,
          pts[i].$2,
          pts[i + 1].$1,
          pts[i + 1].$2,
          ArArrow.outlineLevel,
        );
      }
    }

    final end = path.last, before = path[path.length - 2];
    final (ux, uz) = _unit(end.$1 - before.$1, end.$2 - before.$2);
    if (!head) {
      poly([...left.reversed, ...right]);
      poly([left.last, right.last]);
      return;
    }
    // The band stops at the head's base; the head reaches past the end.
    const hh = ArArrow._headHalf, hl = ArArrow._headLength;
    final base = (end.$1 - ux * hl * 0.4, end.$2 - uz * hl * 0.4);
    final tip = (end.$1 + ux * hl * 0.6, end.$2 + uz * hl * 0.6);
    final bl = (base.$1 - uz * half, base.$2 + ux * half);
    final br = (base.$1 + uz * half, base.$2 - ux * half);
    final wl = (base.$1 - uz * hh, base.$2 + ux * hh);
    final wr = (base.$1 + uz * hh, base.$2 - ux * hh);
    poly([
      ...left.sublist(0, left.length - 1).reversed.toList().reversed,
      bl,
      wl,
      tip,
      wr,
      br,
      ...right.sublist(0, right.length - 1).reversed,
      left.first,
    ]);
  }

  /// A ring of [r] around (x, z).
  void ring(double x, double z, double r) {
    const n = 14;
    for (var i = 0; i < n; i++) {
      final a = 2 * pi * i / n, b = 2 * pi * (i + 1) / n;
      line(
        x + r * cos(a),
        z + r * sin(a),
        x + r * cos(b),
        z + r * sin(b),
        ArArrow.ringLevel,
      );
    }
  }

  static (double, double) _unit(double x, double z) {
    final l = sqrt(x * x + z * z);
    return (x / l, z / l);
  }
}
