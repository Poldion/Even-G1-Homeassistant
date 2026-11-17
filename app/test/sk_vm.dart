/// A small ScouterKit VM for tests (VM.md §2, §3): it runs the app's host
/// packets and the resident program's handlers on an arena, with a panel
/// that DRAW copies into. Enough of the instruction set for the text card,
/// the navigation's bar and the wiggle (label `arrow` in sk_program.dart);
/// GLYPHS draws nothing here (the text's place is checked by rectangles),
/// an instruction it does not know fails the test.
library;

import 'dart:typed_data';

import 'package:even_g1_ha/scouter/sk_protocol.dart';

/// A DRAW the panel received: who sent it, its rectangle on the panel.
typedef SkVmDraw = ({bool program, int x, int y, int w, int h, int at});

class SkVm {
  SkVm(this.arena);

  final Uint8List arena;

  /// What the wearer sees (4 bpp, [SkPanel.stride] bytes per row).
  final panel = Uint8List(SkPanel.stride * SkPanel.height);

  /// The device time (µs), as SYS_READ TIME_US reads it.
  int now = 1000000;

  /// The timer the program armed last (SYS_WRITE TIMER), null if none.
  int? timer;

  /// Triggers raised and not yet handled.
  final pending = <int>[];

  /// Every DRAW, in order.
  final draws = <SkVmDraw>[];

  /// The FILLs into the frame (x, y, w, h, level), in order.
  final fills = <(int, int, int, int, int)>[];

  /// The panel right after the last DRAW of host code (the app's text).
  Uint8List? hostPanel;

  /// The time of each SLEEP_UNTIL.
  final sleeps = <int>[];

  ByteData get _d => ByteData.sublistView(arena);
  int word(int index) => _d.getUint32(index * 4, Endian.little);
  void setWord(int index, int v) =>
      _d.setUint32(index * 4, v & 0xffffffff, Endian.little);
  static int _s(int v) => v.toSigned(32);

  /// Runs one host packet (its code, without the sequence number).
  void runHost(Uint8List code) => _run(code, 0, program: false);

  /// Handles the pending triggers with the program's table.
  void handlePending() {
    while (pending.isNotEmpty) {
      final t = pending.removeAt(0);
      final entry = _d.getUint32(_table + 4 * t, Endian.little);
      if (entry == 0) continue;
      _run(arena, entry, program: true);
    }
  }

  /// The program's handler of trigger [t], now.
  void trigger(int t) {
    pending.add(t);
    handlePending();
  }

  static const _table = 0x35800;

  int _k(int op) => switch (op) {
    0x03 => 3,
    0x04 => 4,
    0x10 => 2,
    >= 0x11 && <= 0x1d => 3,
    >= 0x20 && <= 0x27 => 3,
    >= 0x35 && <= 0x3a => 2,
    0x40 || 0x42 => 1,
    0x43 || 0x44 || 0x45 => 2,
    0x50 || 0x54 => 7,
    0x51 => 12,
    0x52 => 9,
    0x53 => 8,
    _ => 0,
  };

  void _run(Uint8List mem, int pc, {required bool program}) {
    // The call stack; -1 returns from stored code to the packet.
    final stack = <int>[];
    var host = !program;
    var at = pc;
    var budget = 200000;
    while (true) {
      if (--budget == 0) {
        throw StateError('runs away at 0x${at.toRadixString(16)}');
      }
      final m = host ? mem : arena;
      if (host && at >= m.length) return;
      final op = m[at];
      int u24(int i) => m[i] | m[i + 1] << 8 | m[i + 2] << 16;
      if (op == SkOp.write) {
        final addr = u24(at + 1), n = m[at + 4];
        arena.setRange(addr, addr + n, m.sublist(at + 5, at + 5 + n));
        at += 5 + n;
        continue;
      }
      if (op == SkOp.writeRle) {
        final addr = u24(at + 1), len = m[at + 4] | m[at + 5] << 8;
        final n = m[at + 6];
        final data = unpackBits(m.sublist(at + 7, at + 7 + n));
        if (data.length != len) throw StateError('WRITE_RLE of $len bytes');
        arena.setRange(addr, addr + len, data);
        at += 7 + n;
        continue;
      }
      if (op == 0x30 || op == 0x31) {
        final target = u24(at + 1);
        if (op == 0x31) stack.add(host ? -1 - (at + 4) : at + 4);
        if (host) host = false;
        at = target;
        continue;
      }
      if (op == 0x32) {
        if (stack.isEmpty) throw StateError('RET with an empty stack');
        final back = stack.removeLast();
        if (back < 0) {
          host = true;
          at = -1 - back;
        } else {
          at = back;
        }
        continue;
      }
      if (op == 0x33) return; // END
      final k = _k(op);
      if (k == 0) {
        throw StateError(
          'op 0x${op.toRadixString(16)} at 0x${at.toRadixString(16)}',
        );
      }
      final nib = <int>[];
      var i = at + 1;
      for (var j = 0; j < k; j += 2) {
        nib.add(m[i] >> 4);
        if (j + 1 < k) nib.add(m[i] & 15);
        i++;
      }
      int? target;
      if (op >= 0x35 && op <= 0x3a) {
        target = u24(i);
        i += 3;
      }
      final w = <int>[];
      for (final n in nib) {
        if (n == 15) {
          w.add(m[i] | m[i + 1] << 8);
          i += 2;
        } else {
          w.add(n);
        }
      }
      final v = [for (final x in w) word(x)];
      at = i;
      switch (op) {
        case 0x03:
          arena.setRange(v[0], v[0] + v[2], arena.sublist(v[1], v[1] + v[2]));
        case 0x10:
          setWord(w[0], v[1]);
        case 0x11:
          setWord(w[0], v[1] + v[2]);
        case 0x12:
          setWord(w[0], v[1] - v[2]);
        case 0x13:
          setWord(w[0], v[1] * v[2]);
        case 0x14:
          setWord(w[0], v[2] == 0 ? 0 : v[1] ~/ v[2]);
        case 0x15:
          setWord(w[0], v[2] == 0 ? v[1] : v[1] % v[2]);
        case 0x16:
          setWord(w[0], v[2] == 0 ? 0 : (_s(v[1]) / _s(v[2])).truncate());
        case 0x18:
          setWord(w[0], v[1] & v[2]);
        case 0x19:
          setWord(w[0], v[1] | v[2]);
        case 0x1b:
          setWord(w[0], v[1] << (v[2] & 31));
        case 0x1c:
          setWord(w[0], v[1] >> (v[2] & 31));
        case 0x20:
          setWord(w[0], _d.getUint32(v[1] + 4 * v[2], Endian.little));
        case 0x22:
          setWord(w[0], arena[v[1] + v[2]]);
        case 0x24:
          _d.setUint32(v[0] + 4 * v[1], v[2], Endian.little);
        case 0x26:
          arena[v[0] + v[1]] = v[2] & 0xff;
        case >= 0x35 && <= 0x3a:
          final a = v[0], b = v[1];
          final go = switch (op) {
            0x35 => a == b,
            0x36 => a != b,
            0x37 => a < b,
            0x38 => a >= b,
            0x39 => _s(a) < _s(b),
            _ => _s(a) >= _s(b),
          };
          if (go) at = target!;
        case 0x40:
          sleeps.add(v[0]);
        case 0x42:
          pending.add(v[0]);
        case 0x43:
          break;
        case 0x44:
          setWord(w[0], v[1] == SkProp.timeUs ? now : _prop(v[1]));
        case 0x45:
          if (v[0] == SkProp.timer) timer = v[1];
        case 0x50:
          _fill(v[0], v[1], _s(v[2]), _s(v[3]), v[4], v[5], v[6]);
        case 0x51:
          _blit(v);
        case 0x52:
          break; // GLYPHS: the text is not drawn here.
        case 0x53:
          _draw(v, program: !host);
        case 0x54:
          break;
        default:
          throw StateError('op 0x${op.toRadixString(16)}');
      }
    }
  }

  /// Properties a program may read: worn, out of the case, head level.
  int _prop(int id) => switch (id) {
    SkProp.inCase => 0,
    SkProp.worn => 1,
    _ => 0x80000000,
  };

  static int _get(Uint8List m, int base, int stride, int x, int y) {
    final b = m[base + y * stride + (x >> 1)];
    return x.isEven ? b >> 4 : b & 15;
  }

  static void _put(Uint8List m, int base, int stride, int x, int y, int l) {
    final i = base + y * stride + (x >> 1);
    m[i] = x.isEven ? (m[i] & 0x0f) | l << 4 : (m[i] & 0xf0) | l;
  }

  void _fill(int dst, int stride, int x, int y, int w, int h, int level) {
    if (dst == SkArena.frame) fills.add((x, y, w, h, level));
    final width = stride * 2;
    for (var py = y; py < y + h; py++) {
      for (var px = x; px < x + w; px++) {
        if (px < 0 || py < 0 || px >= width) continue;
        if (dst + py * stride + (px >> 1) >= arena.length) continue;
        _put(arena, dst, stride, px, py, level);
      }
    }
  }

  void _blit(List<int> v) {
    final [src, ss, sx, sy, dst, ds, dx, dy, w, h, mode, level] = v;
    if (mode != 0 || level != 15) throw StateError('BLIT mode $mode/$level');
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final px = _s(dx) + x, py = _s(dy) + y;
        if (px < 0 || py < 0 || px >= ds * 2) continue;
        _put(arena, dst, ds, px, py, _get(arena, src, ss, sx + x, sy + y));
      }
    }
  }

  void _draw(List<int> v, {required bool program}) {
    _drawPanel(v, program: program);
    if (!program) hostPanel = Uint8List.fromList(panel);
  }

  void _drawPanel(List<int> v, {required bool program}) {
    final [src, ss, sx, sy, dx, dy, w, h] = v;
    draws.add((program: program, x: _s(dx), y: _s(dy), w: w, h: h, at: now));
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final px = _s(dx) + x, py = _s(dy) + y;
        if (px < 0 || py < 0 || px >= SkPanel.width || py >= SkPanel.height) {
          continue;
        }
        _put(
          panel,
          0,
          SkPanel.stride,
          px,
          py,
          _get(arena, src, ss, sx + x, sy + y),
        );
      }
    }
  }
}
