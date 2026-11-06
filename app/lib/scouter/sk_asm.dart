import 'dart:typed_data';

/// An operand: an arena word (VM.md §2.1). Words 0–14 are the registers
/// r0–r14 and take a nibble; every other word is escaped (nibble 15 and a
/// u16 word index).
class SkW {
  const SkW(this.index) : assert(index >= 0 && index < 0x10000);

  /// Register rN.
  const SkW.r(int n) : assert(n >= 0 && n < 15), index = n;

  /// The word at a byte [address] (a multiple of 4).
  SkW.at(int address) : assert(address % 4 == 0), index = address ~/ 4;

  final int index;

  bool get isRegister => index < 15;
  int get address => index * 4;

  @override
  String toString() =>
      isRegister ? 'r$index' : '[0x${address.toRadixString(16)}]';
}

/// Opcodes of program code (VM.md §2.2).
class SkAsmOp {
  static const copy = 0x03;
  static const mov = 0x10;
  static const add = 0x11;
  static const sub = 0x12;
  static const mul = 0x13;
  static const divu = 0x14;
  static const modu = 0x15;
  static const divs = 0x16;
  static const and = 0x18;
  static const or = 0x19;
  static const ld32 = 0x20;
  static const ld8 = 0x22;
  static const st32 = 0x24;
  static const st8 = 0x26;
  static const jmp = 0x30;
  static const call = 0x31;
  static const ret = 0x32;
  static const end = 0x33;
  static const halt = 0x34;
  static const beq = 0x35;
  static const bne = 0x36;
  static const bltu = 0x37;
  static const bgeu = 0x38;
  static const blts = 0x39;
  static const bges = 0x3A;
  static const raise = 0x42;
  static const notify = 0x43;
  static const sysRead = 0x44;
  static const sysWrite = 0x45;
  static const fill = 0x50;
  static const glyphs = 0x52;
  static const draw = 0x53;
}

/// Assembles program code for an arm (VM.md §2) at a fixed arena address:
/// labels for jumps and branches, and a constant pool (the protocol has no
/// immediate values) that the host writes together with the code.
class SkAsm {
  SkAsm({required this.codeAt, required this.poolAt, this.poolWords = 112});

  /// Arena address of the first instruction.
  final int codeAt;

  /// Arena address of the constant pool.
  final int poolAt;
  final int poolWords;

  final BytesBuilder _b = BytesBuilder(copy: false);
  final Map<String, int> _labels = {};
  final List<(int offset, String label)> _fixups = [];
  final Map<int, int> _pool = {};

  /// Arena address of the next instruction.
  int get here => codeAt + _b.length;

  /// The pool word that holds [value] (added to the pool on first use).
  SkW c(int value) {
    final v = value & 0xffffffff;
    final i = _pool.putIfAbsent(v, () {
      if (_pool.length >= poolWords) {
        throw StateError('constant pool full');
      }
      return _pool.length;
    });
    return SkW.at(poolAt + 4 * i);
  }

  void label(String name) {
    if (_labels.containsKey(name)) throw StateError('label $name twice');
    _labels[name] = here;
  }

  /// Address of a label (after [build]).
  int addressOf(String name) => _labels[name]!;

  void _u16(int v) => _b.add([v & 0xff, (v >> 8) & 0xff]);
  void _u24(int v) => _b.add([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff]);

  /// opcode, operand nibbles, literal target, escapes (VM.md §2.1).
  void _op(int opcode, List<SkW> operands, {String? target}) {
    _b.addByte(opcode);
    for (var i = 0; i < operands.length; i += 2) {
      final hi = operands[i].isRegister ? operands[i].index : 15;
      final lo = i + 1 < operands.length
          ? (operands[i + 1].isRegister ? operands[i + 1].index : 15)
          : 0;
      _b.addByte(hi << 4 | lo);
    }
    if (target != null) {
      _fixups.add((_b.length, target));
      _u24(0);
    }
    for (final w in operands) {
      if (!w.isRegister) _u16(w.index);
    }
  }

  void mov(SkW d, SkW a) => _op(SkAsmOp.mov, [d, a]);
  void add(SkW d, SkW a, SkW b) => _op(SkAsmOp.add, [d, a, b]);
  void sub(SkW d, SkW a, SkW b) => _op(SkAsmOp.sub, [d, a, b]);
  void mul(SkW d, SkW a, SkW b) => _op(SkAsmOp.mul, [d, a, b]);
  void divs(SkW d, SkW a, SkW b) => _op(SkAsmOp.divs, [d, a, b]);
  void and(SkW d, SkW a, SkW b) => _op(SkAsmOp.and, [d, a, b]);
  void or(SkW d, SkW a, SkW b) => _op(SkAsmOp.or, [d, a, b]);

  /// d = the u32 element i of base (address base + 4i).
  void ld32(SkW d, SkW base, SkW i) => _op(SkAsmOp.ld32, [d, base, i]);
  void st32(SkW base, SkW i, SkW a) => _op(SkAsmOp.st32, [base, i, a]);

  void jmp(String target) => _op(SkAsmOp.jmp, const [], target: target);
  void call(String target) => _op(SkAsmOp.call, const [], target: target);
  void ret() => _b.addByte(SkAsmOp.ret);
  void end() => _b.addByte(SkAsmOp.end);
  void halt() => _b.addByte(SkAsmOp.halt);

  void beq(SkW a, SkW b, String t) => _op(SkAsmOp.beq, [a, b], target: t);
  void bne(SkW a, SkW b, String t) => _op(SkAsmOp.bne, [a, b], target: t);
  void bltu(SkW a, SkW b, String t) => _op(SkAsmOp.bltu, [a, b], target: t);
  void bgeu(SkW a, SkW b, String t) => _op(SkAsmOp.bgeu, [a, b], target: t);
  void blts(SkW a, SkW b, String t) => _op(SkAsmOp.blts, [a, b], target: t);
  void bges(SkW a, SkW b, String t) => _op(SkAsmOp.bges, [a, b], target: t);

  void raise(SkW t) => _op(SkAsmOp.raise, [t]);
  void notify(SkW a, SkW b) => _op(SkAsmOp.notify, [a, b]);
  void sysRead(SkW d, SkW p) => _op(SkAsmOp.sysRead, [d, p]);
  void sysWrite(SkW p, SkW a) => _op(SkAsmOp.sysWrite, [p, a]);

  void fill(SkW dst, SkW stride, SkW x, SkW y, SkW w, SkW h, SkW level) =>
      _op(SkAsmOp.fill, [dst, stride, x, y, w, h, level]);

  void glyphs(
    SkW font,
    SkW dst,
    SkW stride,
    SkW x,
    SkW y,
    SkW mode,
    SkW level,
    SkW text,
    SkW n,
  ) => _op(SkAsmOp.glyphs, [font, dst, stride, x, y, mode, level, text, n]);

  void draw(
    SkW src,
    SkW srcStride,
    SkW srcX,
    SkW srcY,
    SkW dstX,
    SkW dstY,
    SkW w,
    SkW h,
  ) => _op(SkAsmOp.draw, [src, srcStride, srcX, srcY, dstX, dstY, w, h]);

  /// The code with every label resolved.
  Uint8List build() {
    final code = _b.toBytes();
    for (final (offset, name) in _fixups) {
      final at = _labels[name];
      if (at == null) throw StateError('no label $name');
      code[offset] = at & 0xff;
      code[offset + 1] = (at >> 8) & 0xff;
      code[offset + 2] = (at >> 16) & 0xff;
    }
    return code;
  }

  /// The constant pool as bytes (word i at [poolAt] + 4i).
  Uint8List pool() {
    final out = ByteData(_pool.length * 4);
    _pool.forEach((value, i) => out.setUint32(i * 4, value, Endian.little));
    return out.buffer.asUint8List();
  }
}
