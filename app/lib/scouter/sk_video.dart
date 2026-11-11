import 'dart:math';
import 'dart:typed_data';

import 'sk_protocol.dart';

/// How a video ended.
enum SkVideoEnd { done, stopped, failed, unavailable }

/// Records for the VM's `VIDEO` instruction (VM.md §3.7): each frame coded
/// against the one before, with the binary range coder and the T.6 modes
/// the arms decode. A port of ScouterKit's `VideoEncoder`
/// (scouter_kit_g1.cpp); its records are byte for byte the same.
class SkVideoEncoder {
  SkVideoEncoder(this.width, this.height)
    : stride = (width + 7) >> 3,
      _prev = Uint8List(((width + 7) >> 3) * height) {
    if (width < 1 ||
        width > SkPanel.width ||
        height < 1 ||
        height > SkPanel.height) {
      throw ArgumentError('video size ${width}x$height');
    }
  }

  /// Size of the decoder's state in the arena.
  static const stateBytes = 1596;

  final int width, height;

  /// Bytes per row of a frame (1 bit per pixel, the leftmost the high bit).
  final int stride;

  Uint8List _prev;
  Uint16List _p = Uint16List(_probs)..fillRange(0, _probs, 2048);
  bool _started = false;

  static const _vMax = 5;
  static const _same = 0, _v0 = 3, _isv = _v0 + 7 * 7 * 6;
  static const _sign = _isv + 7 * 2 * 6, _mag = _sign + 7 * 6;
  static const _pass = _mag + (_vMax - 1) * 7 * 6, _runLen = _pass + 7;
  static const _runBit = _runLen + 2 * 20, _probs = _runBit + 2 * 20 * 4;

  /// The record of the next frame: [frame] holds [height] rows of [stride]
  /// bytes, a set bit is ink (bits past [width] must be 0). [redraw]: the
  /// arm draws every row, not only the changed ones. A record over
  /// [maxBytes] is not made: null, and the encoder stays as it was.
  Uint8List? encode(Uint8List frame, {bool redraw = false, int? maxBytes}) {
    final w = width, nb = stride;
    if (frame.length < nb * height) throw ArgumentError('frame too small');
    final cur = Uint8List.fromList(frame.sublist(0, nb * height));
    final out = <int>[(_started ? 0 : 1) | (redraw ? 2 : 0)];
    final p = _started
        ? Uint16List.fromList(_p)
        : (Uint16List(_probs)..fillRange(0, _probs, 2048));
    final e = _RangeEncoder(p, out);
    final ref = Uint16List(SkPanel.width + 1),
        ct = Uint16List(SkPanel.width + 1);
    final rcode = Uint8List(SkPanel.width + 1);
    final ccode = Uint8List(SkPanel.width + 1);
    final old = Uint8List(SkPanel.width ~/ 8 + 8);
    var nref = 0, prevSame = 2;
    for (var y = 0; y < height; y++) {
      final o = y * nb;
      var same = true;
      for (var k = 0; k < nb; k++) {
        if (_prev[o + k] != cur[o + k]) {
          same = false;
          break;
        }
      }
      final nc = _transitions(cur, o, w, ct);
      e.bit(_same + prevSame, same ? 1 : 0);
      prevSame = same ? 1 : 0;
      if (same) {
        ref.setRange(0, nc, ct);
        rcode.fillRange(0, nc, 0);
        nref = nc;
        continue;
      }
      old.setRange(4, 4 + nb, _prev, o);
      var a0 = -1, colour = 0, pc = 0, j = 0, i = 0;
      for (;;) {
        while (j < nref && ref[j] <= a0) {
          j++;
        }
        final jb = j + ((j & 1) != colour ? 1 : 0);
        final b1 = jb < nref ? ref[jb] : w;
        final b2 = jb + 1 < nref ? ref[jb + 1] : w;
        final ac = _aboveClass(b1, w, jb < nref ? rcode[jb] : 0);
        final tc = b1 < w ? _frameClass(old, b1, colour) : 0;
        final a1 = i < nc ? ct[i] : w, a2 = i + 1 < nc ? ct[i + 1] : w;
        final d = a1 - b1;
        final v0 = _v0 + (pc * 7 + ac) * 6 + tc;
        final isv = _isv + (pc * 2 + (ac != 0 && ac != 6 ? 1 : 0)) * 6 + tc;
        if (b2 < a1) {
          // Pass.
          e.bit(v0, 1);
          e.bit(isv, 0);
          e.bit(_pass + pc, 1);
          a0 = b2;
          pc = 5;
          continue;
        }
        if (d >= -_vMax && d <= _vMax) {
          // Vertical.
          e.bit(v0, d != 0 ? 1 : 0);
          if (d != 0) {
            final m = d.abs();
            e.bit(isv, 1);
            e.bit(_sign + ac * 6 + tc, d < 0 ? 1 : 0);
            for (var k = 1; k < _vMax; k++) {
              e.bit(_mag + ((k - 1) * 7 + ac) * 6 + tc, m > k ? 1 : 0);
              if (m <= k) break;
            }
          }
          if (a1 >= w) break;
          ccode[i++] = d + 8;
          a0 = a1;
          colour ^= 1;
          pc = d == 0
              ? 1
              : d == 1
              ? 2
              : d == -1
              ? 3
              : 4;
          continue;
        }
        // Horizontal.
        e.bit(v0, 1);
        e.bit(isv, 0);
        e.bit(_pass + pc, 0);
        e.run(colour, a1 - max(a0, 0));
        e.run(colour ^ 1, a2 - a1);
        if (a1 >= w) break;
        ccode[i++] = 0;
        if (a2 >= w) break;
        ccode[i++] = 0;
        a0 = a2;
        pc = 6;
      }
      ref.setRange(0, nc, ct);
      rcode.setRange(0, nc, ccode);
      nref = nc;
    }
    e.finish();
    if (maxBytes != null && out.length > maxBytes) return null;
    _started = true;
    _p = p;
    _prev = cur;
    return Uint8List.fromList(out);
  }

  static int _aboveClass(int b1, int w, int code) {
    if (b1 >= w) return 6;
    if (code == 0) return 0;
    return switch (code) {
      8 => 1,
      9 => 2,
      7 => 3,
      _ => code > 8 ? 4 : 5,
    };
  }

  /// The previous frame's row (in [old] after 4 zero bytes) around b1: 1…5
  /// for the leftmost transition of b1's kind at b1 − 2…b1 + 2, 0 for none.
  static int _frameClass(Uint8List old, int b1, int colour) {
    final q = b1 + 29;
    final u = old[q >> 3] << 8 | old[(q >> 3) + 1];
    final px = u >> (10 - (q & 7)) & 63;
    final cand = ((px >> 1) ^ px) & (colour != 0 ? ~px : px) & 31;
    return cand == 0 ? 0 : 6 - cand.bitLength;
  }

  static int _transitions(Uint8List row, int o, int w, Uint16List t) {
    var n = 0, c = 0;
    for (var x = 0; x < w; x++) {
      final p = (row[o + (x >> 3)] >> (7 - (x & 7))) & 1;
      if (p != c) {
        t[n++] = x;
        c = p;
      }
    }
    return n;
  }
}

/// LZMA's range coder without its leading zero byte (VM.md §3.7).
class _RangeEncoder {
  _RangeEncoder(this.p, this.out);

  final Uint16List p;
  final List<int> out;
  int low = 0;
  int range = 0xFFFFFFFF;
  int cache = 0;
  int pending = 0;
  bool first = true;

  void _put(int b) {
    if (first) {
      first = false;
    } else {
      out.add(b & 0xff);
    }
  }

  void _shiftLow() {
    if ((low & 0xFFFFFFFF) < 0xFF000000 || low >> 32 != 0) {
      final carry = low >> 32;
      _put(cache + carry);
      for (; pending > 0; pending--) {
        _put(0xFF + carry);
      }
      cache = (low >> 24) & 0xff;
    } else {
      pending++;
    }
    low = (low & 0x00FFFFFF) << 8;
  }

  void bit(int i, int b) {
    final q = p[i], bound = (range >> 12) * q;
    if (b == 0) {
      range = bound;
      p[i] = q + ((4096 - q) >> 5);
    } else {
      low += bound;
      range -= bound;
      p[i] = q - (q >> 5);
    }
    while (range < 1 << 24) {
      range = (range << 8) & 0xFFFFFFFF;
      _shiftLow();
    }
  }

  void run(int colour, int v) {
    final x = v + 1;
    var nb = 0;
    while (x >> (nb + 1) != 0) {
      nb++;
    }
    for (var k = 0; k <= nb && k < 20; k++) {
      bit(SkVideoEncoder._runLen + 20 * colour + min(k, 19), k < nb ? 1 : 0);
    }
    final int c = SkVideoEncoder._runBit + 80 * colour + 4 * min(nb, 19);
    for (var i = 0; i < nb; i++) {
      bit(c + min(i, 3), (x >> (nb - 1 - i)) & 1);
    }
  }

  /// The shortest code in [low, low + range) once the decoder reads zeros
  /// past the end.
  void finish() {
    for (var k = 1; k <= 4; k++) {
      final m = (1 << (32 - 8 * k)) - 1, v = (low + m) & ~m;
      if (v < low + range) {
        low = v;
        break;
      }
    }
    for (var i = 0; i < 5; i++) {
      _shiftLow();
    }
    while (out.length > 1 && out.last == 0) {
      out.removeLast();
    }
  }
}

/// Where a video goes in the arena while it plays: the app's frame area
/// (0x10000…), free while the app shows nothing else.
class SkVideoLayout {
  SkVideoLayout(this.width, this.height) : stride = ((width + 7) ~/ 8 + 3) & ~3;

  final int width, height;

  /// Bytes per row of the arm's bitmap (a multiple of 4).
  final int stride;

  static const bitmap = SkArena.frame;
  int get state => bitmap + stride * height;
  int get record => (state + SkVideoEncoder.stateBytes + 3) & ~3;

  /// The largest record sent; a frame whose record would be larger is
  /// skipped.
  static const recordMax = 16384;

  /// The panel position that centres the picture.
  int get x => (SkPanel.width - width) ~/ 2;
  int get y => (SkPanel.height - height) ~/ 2;

  /// The largest size of [w] × [h] within [maxW] × [maxH], aspect kept.
  static (int, int) fit(int w, int h, int maxW, int maxH) {
    if (w <= 0 || h <= 0) return (maxW, maxH);
    final s = min(maxW / w, maxH / h);
    return (
      max(1, min(maxW, (w * s).round())),
      max(1, min(maxH, (h * s).round())),
    );
  }

  /// Host code that clears the panel (black, powered on) and the bitmap,
  /// so the first record decodes against an empty picture.
  Uint8List startCode() {
    final code = SkCode()
      ..fill(
        SkArena.frame,
        SkPanel.stride,
        0,
        0,
        SkPanel.width,
        SkPanel.height,
        0,
      )
      ..draw(
        SkArena.frame,
        SkPanel.stride,
        0,
        0,
        0,
        0,
        SkPanel.width,
        SkPanel.height,
      );
    return code.take();
  }

  /// Packets that write [record] and, at the arm's time [armTime], decode
  /// and show it (ink as [level]).
  List<Uint8List> frameCode(
    Uint8List record,
    int armTime, {
    required int maxCode,
    int level = 15,
  }) {
    if (record.length > recordMax) throw ArgumentError('record too large');
    final packets = <Uint8List>[];
    var code = SkCode();
    void room(int bytes) {
      if (code.length + bytes > maxCode) {
        packets.add(code.take());
        code = SkCode();
      }
    }

    var o = 0;
    while (o < record.length) {
      final free = maxCode - code.length - 5;
      if (free < 16) {
        room(maxCode);
        continue;
      }
      final n = min(min(free, 255), record.length - o);
      code.write(this.record + o, record.sublist(o, o + n));
      o += n;
    }
    room(skOpSize(1) + skOpSize(10));
    code
      ..sleepUntil(armTime)
      ..op(SkOp.video, [
        bitmap,
        stride,
        width,
        height,
        x,
        y,
        level,
        this.record,
        record.length,
        state,
      ]);
    packets.add(code.take());
    return packets;
  }
}
