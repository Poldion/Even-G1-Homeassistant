import 'dart:math';
import 'dart:typed_data';

import '../scouter/sk_icons.dart';
import 'navigation.dart';

/// Right at the turn the navigation's arrow beside the text pushes a few
/// times into the direction to take. The glasses' program plays it (label
/// `arrow` in sk_program.dart): one [offsets] frame every 50 ms, the icon
/// cleared where it was and copied (BLIT) where it goes, the last frame
/// back at its place. This class computes the same, so tests and renders
/// show what the glasses draw.
class NavWiggle {
  NavWiggle._(this.x, this.y, this.icon, this.offsets);

  /// The icon's place on the panel (its top left at rest).
  final int x, y;

  /// The icon, [SkIcons.size]² pixels at 4 bpp.
  final Uint8List icon;

  /// Where it is in each frame, relative to its place.
  final List<(int, int)> offsets;

  static const maxFrames = 24;

  /// How far it pushes (pixels) and how often.
  static const reach = 8, pushes = 3;

  /// The wiggle of [icon] at ([x], [y]) for [turn].
  static NavWiggle of(
    NavTurn turn,
    Uint8List icon, {
    required int x,
    required int y,
  }) {
    if (icon.length != SkIcons.bytes) {
      throw ArgumentError('icon of ${icon.length} bytes');
    }
    final offsets = <(int, int)>[];
    if (turn == NavTurn.roundabout) {
      // Round once, counter-clockwise as the traffic goes.
      for (var k = 1; k <= 12; k++) {
        final a = 2 * pi * k / 12;
        offsets.add((
          (-sin(a) * reach * 0.75).round(),
          (-(1 - cos(a)) * reach * 0.75).round(),
        ));
      }
      offsets.add((0, 0));
    } else {
      final (ux, uy) = direction(turn);
      const steps = [0.4, 0.8, 1.0, 0.6, 0.2, 0.0];
      for (var p = 0; p < pushes; p++) {
        for (final t in steps) {
          offsets.add(((ux * reach * t).round(), (uy * reach * t).round()));
        }
      }
    }
    assert(offsets.length <= maxFrames && offsets.last == (0, 0));
    return NavWiggle._(x, y, icon, offsets);
  }

  /// The way [turn] goes on the panel (x right, y down), unit length.
  static (double, double) direction(NavTurn turn) {
    const d = sqrt1_2;
    return switch (turn) {
      NavTurn.left => (-1, 0),
      NavTurn.right => (1, 0),
      NavTurn.slightLeft => (-d, -d),
      NavTurn.slightRight => (d, -d),
      NavTurn.sharpLeft => (-d, d),
      NavTurn.sharpRight => (d, d),
      NavTurn.uTurn => (-d, d),
      _ => (0, -1), // straight on, the destination: ahead
    };
  }

  /// The box (x0, y0, x1, y1, ends included) of frame [k].
  (int, int, int, int) box(int k) {
    final (dx, dy) = offsets[k];
    return (
      x + dx,
      y + dy,
      x + dx + SkIcons.size - 1,
      y + dy + SkIcons.size - 1,
    );
  }

  /// The words the program reads (at [SkResident] `arrowData`).
  Uint8List data() {
    final b = BytesBuilder();
    void w(int v) =>
        b.add([v & 0xff, v >> 8 & 0xff, v >> 16 & 0xff, v >> 24 & 0xff]);
    for (final v in [offsets.length, x, y, 0, 0, 0, 0, 0]) {
      w(v);
    }
    for (var k = 0; k < maxFrames; k++) {
      final (dx, dy) = k < offsets.length ? offsets[k] : (0, 0);
      w(dx);
      w(dy);
    }
    b.add(icon);
    return b.toBytes();
  }

  /// Byte offsets in [data].
  static const offsetsAt = 32;
  static const iconAt = offsetsAt + 8 * maxFrames;
  static const dataMax = iconAt + SkIcons.bytes;

  /// Draws frame [k] as the program does into a 4-bpp panel image
  /// ([panel], 320 bytes per row), after the frame before it: both boxes
  /// cleared, then the icon.
  void drawInto(Uint8List panel, int k) {
    final now = box(k);
    final before = k > 0 ? box(k - 1) : (x, y, x, y);
    final x0 = min(now.$1, before.$1), y0 = min(now.$2, before.$2);
    final x1 = max(now.$3, before.$3), y1 = max(now.$4, before.$4);
    for (var py = y0; py <= y1; py++) {
      for (var px = x0; px <= x1; px++) {
        _set(panel, px, py, 0);
      }
    }
    for (var py = 0; py < SkIcons.size; py++) {
      for (var px = 0; px < SkIcons.size; px++) {
        final b = icon[py * SkIcons.stride + (px >> 1)];
        _set(panel, now.$1 + px, now.$2 + py, px.isEven ? b >> 4 : b & 15);
      }
    }
  }

  static void _set(Uint8List panel, int x, int y, int level) {
    if (x < 0 || y < 0 || x >= 640 || y >= 480) return;
    final i = y * 320 + (x >> 1);
    panel[i] = x.isEven
        ? (panel[i] & 0x0f) | level << 4
        : (panel[i] & 0xf0) | level;
  }
}
