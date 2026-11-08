// ScouterKit G1 protocol, version 5 (github.com/mafik/scouter_kit,
// g1_firmware/docs/VM.md). Only what this app needs: host code for drawing
// text and writing properties, control requests and the events.
//
// The arms run the g1v0 firmware instead of Even's. Each arm is a small VM
// with a 256 KiB arena; the host sends instructions in numbered packets.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class SkUuids {
  static final service = Guid('f3da4d59-277a-4fc9-a1ed-41c9c22d4400');

  /// Host code packets (write without response).
  static final cmd = Guid('f3da4d59-277a-4fc9-a1ed-41c9c22d4401');

  /// Control requests (write without response).
  static final ctrl = Guid('f3da4d59-277a-4fc9-a1ed-41c9c22d4402');

  /// Events (notify).
  static final evt = Guid('f3da4d59-277a-4fc9-a1ed-41c9c22d4403');
}

/// Opcodes (VM.md §2.2), only those valid in host code.
class SkOp {
  static const write = 0x01;
  static const writeRle = 0x02;
  static const add = 0x11;
  static const call = 0x31;
  static const sleepUntil = 0x40;
  static const raise = 0x42;
  static const sysRead = 0x44;
  static const sysWrite = 0x45;
  static const fill = 0x50;
  static const blit = 0x51;
  static const glyphs = 0x52;
  static const draw = 0x53;
  static const end = 0x33;
}

/// Control requests (VM.md §6.4).
class SkCtrl {
  static const hello = 0x01;
  static const ping = 0x02;
  static const status = 0x03;
  static const resetSession = 0x04;
  static const link = 0x05;
  static const props = 0x0A;
  static const vmStart = 0x10;
  static const vmStop = 0x11;
  static const vmStatus = 0x12;
  static const mic = 0x13;
  static const events = 0x14;
}

/// Event types (VM.md §6.3).
class SkEvt {
  static const ack = 0x01;
  static const error = 0x02;
  static const halt = 0x03;
  static const notify = 0x04;
  static const notice = 0x05;
  static const micData = 0x06;
  static const input = 0x07;
  static const ctrlReply = 0x80;
}

/// Properties (VM.md §2.5).
class SkProp {
  static const timeUs = 0x00;
  static const hostLink = 0x04;
  static const battPct = 0x11;
  static const charge = 0x12;
  static const inCase = 0x13;
  static const worn = 0x14;
  static const pitch = 0x1B;
  static const light = 0x1C;
  static const brightness = 0x20;
  static const panel = 0x21;
  static const timer = 0x22;
  static const pitchLo = 0x24;
  static const pitchHi = 0x25;
  static const lightLo = 0x26;
  static const lightHi = 0x27;
  static const imuRate = 0x28;
  static const gyrX = 0x30;
  static const gyrY = 0x31;
  static const gyroRate = 0x33;
  static const caseLid = 0x35;
  static const caseCharging = 0x36;
  static const caseBattPct = 0x37;
  static const autoBrightness = 0x38;
  static const peerLink = 0x39;
  static const peerSend = 0x3A;
  static const peerMsg = 0x3B;
  static const peerTUs = 0x3C;

  /// Read for a value the arm does not have.
  static const unknown = 0x80000000;
}

/// Triggers (VM.md §5.2), also the `INPUT` event's trigger IDs.
class SkTrigger {
  static const start = 0;
  static const timer = 1;
  static const tilt = 3;
  static const light = 4;
  static const battery = 5;
  static const caseState = 6;
  static const wear = 7;
  static const touch = 8;
  static const peer = 9;
  static const user0 = 12;
  static const user1 = 13;
  static const user2 = 14;
}

/// `TOUCH_GESTURE` values (VM.md §2.5).
class SkGesture {
  static const tap = 1;
  static const doubleTap = 2;
  static const tripleTap = 3;
  static const longStart = 4;
  static const longEnd = 5;
}

/// Error codes of `ERROR`, `HALT` and control replies (VM.md §1).
String skErrorName(int code) => switch (code) {
  0 => 'ok',
  1 => 'malformed',
  2 => 'invalid op',
  3 => 'arena',
  4 => 'format',
  5 => 'argument',
  6 => 'window',
  7 => 'safe mode',
  8 => 'font',
  9 => 'stack',
  10 => 'budget',
  11 => 'panel',
  12 => 'mic',
  13 => 'asset',
  _ => 'error $code',
};

class SkPanel {
  static const width = 640;
  static const height = 480;

  /// Bytes per row of a 4-bpp bitmap as wide as the panel.
  static const stride = width ~/ 2;
  static const maxBrightness = 42;
}

/// Where this app keeps its data in an arm's arena.
class SkArena {
  static const size = 262144;

  /// Scratch words for instruction operands (64 words).
  static const params = 0x0100;

  /// Glyph indices of the lines drawn by one packet.
  static const text = 0x0200;
  static const textSize = 0x0E00;

  /// The font blob.
  static const font = 0x1000;
  static const fontMax = icons - font;

  /// Notification icons (50 × 50, 4 bpp, 1250 bytes each), uploaded when
  /// first used.
  static const icons = 0x8000;
  static const iconsEnd = frame;

  /// The 4-bpp frame (640 × 480 = 153 600 bytes).
  static const frame = 0x10000;
}

/// Builds host code. All operands are arena words (the protocol has no
/// immediate values), so each instruction writes its operand values to the
/// scratch words first and names them by escape (nibble 15 + u16 index).
class SkCode {
  final _b = BytesBuilder(copy: false);

  int get length => _b.length;
  Uint8List take() => _b.takeBytes();

  void _u16(int v) => _b.add([v & 0xff, (v >> 8) & 0xff]);
  void _u24(int v) => _b.add([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff]);

  /// `WRITE`: [data] (at most 255 bytes) to [address].
  void write(int address, List<int> data) {
    assert(data.length <= 255);
    _b.addByte(SkOp.write);
    _u24(address);
    _b.addByte(data.length);
    _b.add(data);
  }

  /// `WRITE_RLE`: [packed] (PackBits, at most 255 bytes) decodes to the
  /// [length] bytes at [address].
  void writeRle(int address, int length, List<int> packed) {
    assert(packed.length <= 255);
    _b.addByte(SkOp.writeRle);
    _u24(address);
    _u16(length);
    _b.addByte(packed.length);
    _b.add(packed);
  }

  /// An instruction whose operands are [values], passed through the scratch
  /// words.
  void op(int opcode, List<int> values) {
    final words = ByteData(values.length * 4);
    for (var i = 0; i < values.length; i++) {
      words.setUint32(i * 4, values[i] & 0xffffffff, Endian.little);
    }
    write(SkArena.params, words.buffer.asUint8List());
    instruction(opcode, [
      for (var i = 0; i < values.length; i++) SkArena.params ~/ 4 + i,
    ]);
  }

  /// An instruction whose operands are the arena words [wordIndices]
  /// (all escaped).
  void instruction(int opcode, List<int> wordIndices) {
    _b.addByte(opcode);
    for (var i = 0; i < wordIndices.length; i += 2) {
      // Two escape nibbles per byte, an odd count padded with 0.
      _b.addByte(i + 1 < wordIndices.length ? 0xff : 0xf0);
    }
    for (final w in wordIndices) {
      _u16(w);
    }
  }

  /// `CALL`: runs the stored code at [target] as part of this packet
  /// (VM.md §6.2).
  void call(int target) {
    _b.addByte(SkOp.call);
    _u24(target);
  }

  /// `RAISE`: sets trigger [t] pending (hands work to the program).
  void raise(int t) => op(SkOp.raise, [t]);

  /// `SLEEP_UNTIL`: wait until the arm's device time [t] (at most 2 s).
  void sleepUntil(int t) => op(SkOp.sleepUntil, [t]);

  void sysWrite(int property, int value) =>
      op(SkOp.sysWrite, [property, value]);

  void fill(int dst, int stride, int x, int y, int w, int h, int level) =>
      op(SkOp.fill, [dst, stride, x, y, w, h, level]);

  /// `GLYPHS` with the `MASK` mode (text).
  void glyphs(
    int font,
    int dst,
    int stride,
    int x,
    int baseline,
    int level,
    int text,
    int n,
  ) => op(SkOp.glyphs, [font, dst, stride, x, baseline, 2, level, text, n]);

  /// `BLIT` of a 4-bpp source with the `COPY` mode.
  void blit(
    int src,
    int srcStride,
    int dst,
    int dstStride,
    int dstX,
    int dstY,
    int w,
    int h,
  ) => op(SkOp.blit, [
    src,
    srcStride,
    0,
    0,
    dst,
    dstStride,
    dstX,
    dstY,
    w,
    h,
    0,
    15,
  ]);

  void draw(
    int src,
    int srcStride,
    int srcX,
    int srcY,
    int dstX,
    int dstY,
    int w,
    int h,
  ) => op(SkOp.draw, [src, srcStride, srcX, srcY, dstX, dstY, w, h]);
}

/// Size of an operand-passing instruction built by [SkCode.op].
int skOpSize(int operands) =>
    5 + 4 * operands + 1 + (operands + 1) ~/ 2 + 2 * operands;

/// PackBits (VM.md §2.4): header h as i8, 0…127 copies h + 1 bytes,
/// -127…-1 repeats the next byte 1 - h times.
Uint8List packBits(List<int> data) {
  final out = BytesBuilder(copy: false);
  var i = 0;
  while (i < data.length) {
    var run = 1;
    while (i + run < data.length && run < 128 && data[i + run] == data[i]) {
      run++;
    }
    if (run >= 3) {
      out.add([(1 - run) & 0xff, data[i]]);
      i += run;
      continue;
    }
    // Literal bytes up to the next run of 3 or more.
    final start = i;
    while (i < data.length && i - start < 128) {
      if (i + 2 < data.length &&
          data[i] == data[i + 1] &&
          data[i] == data[i + 2]) {
        break;
      }
      i++;
    }
    out.addByte(i - start - 1);
    out.add(data.sublist(start, i));
  }
  return out.takeBytes();
}

/// Decodes PackBits (for tests).
Uint8List unpackBits(List<int> packed) {
  final out = BytesBuilder(copy: false);
  var i = 0;
  while (i < packed.length) {
    final h = packed[i++].toSigned(8);
    if (h >= 0) {
      out.add(packed.sublist(i, i + h + 1));
      i += h + 1;
    } else if (h != -128) {
      out.add(List.filled(1 - h, packed[i++]));
    }
  }
  return out.takeBytes();
}

/// Packets that write [data] to [address], split to [maxCode] bytes of host
/// code each; PackBits where it is shorter.
List<Uint8List> skUpload(int address, Uint8List data, int maxCode) {
  final packets = <Uint8List>[];
  final code = SkCode();
  void flush() {
    if (code.length > 0) packets.add(code.take());
  }

  var offset = 0;
  while (offset < data.length) {
    final room = maxCode - code.length;
    if (room < 16) {
      flush();
      continue;
    }
    // Try a RLE chunk: take as many source bytes as fit in 255 packed bytes.
    var len = (data.length - offset).clamp(0, 8192);
    Uint8List packed = packBits(data.sublist(offset, offset + len));
    final limit = (room - 7).clamp(0, 255);
    while (packed.length > limit && len > 1) {
      len = len * limit ~/ packed.length;
      if (len < 1) len = 1;
      packed = packBits(data.sublist(offset, offset + len));
    }
    final plain = (room - 5).clamp(0, 255);
    if (packed.length <= limit && len > plain) {
      code.writeRle(address + offset, len, packed);
      offset += len;
    } else {
      final n = plain.clamp(1, data.length - offset);
      code.write(address + offset, data.sublist(offset, offset + n));
      offset += n;
    }
  }
  flush();
  return packets;
}

ByteData _view(Uint8List b) => ByteData.sublistView(b);

/// `HELLO` body (VM.md §6.4).
class SkHello {
  SkHello(Uint8List body)
    : protocol = body[0],
      version = '${body[1]}.${body[2]}.${body[3]}',
      left = body[4] == 1,
      flags = body[5],
      board = body[6],
      triggers = _view(body).getUint16(7, Endian.little),
      maxPacket = _view(body).getUint16(18, Endian.little),
      rxNext = _view(body).getUint16(20, Endian.little),
      execNext = _view(body).getUint16(22, Endian.little),
      credits = body[24];

  static const size = 35;

  final int protocol;
  final String version;
  final bool left;
  final int flags;
  final int board;
  final int triggers;
  final int maxPacket;
  final int rxNext;
  final int execNext;
  final int credits;

  bool get safeMode => flags & 0x01 != 0;
  bool get panelOk => flags & 0x02 != 0;
  bool get encrypted => flags & 0x40 != 0;
  bool get inCase => flags & 0x80 != 0;
  bool get bondable => board & 0x02 != 0;
  bool get microphone => board & 0x04 != 0;
}

/// One event from `EVT`.
class SkEvent {
  SkEvent(this.data)
    : type = data[0],
      epoch = data.length >= 9 ? _view(data).getUint32(1, Endian.little) : 0;

  final Uint8List data;
  final int type;
  final int epoch;

  bool get valid => data.length >= 9;
  int u8(int offset) => data[offset];
  int u16(int offset) => _view(data).getUint16(offset, Endian.little);
  int u32(int offset) => _view(data).getUint32(offset, Endian.little);
  int i32(int offset) => _view(data).getInt32(offset, Endian.little);

  // Control replies: 0x80 + op, tag, status, body.
  bool get isReply => type & 0x80 != 0 && data.length >= 11;
  int get replyOp => type & 0x7f;
  int get tag => data[9];
  int get status => data[10];
  Uint8List get body => Uint8List.sublistView(data, 11);
}

/// A pair of g1v0 arms found by a scan: the scan response carries
/// manufacturer data for company 0xFFFF (format, flags, pair ID).
class SkAdvert {
  SkAdvert(this.left, this.pairId, {this.safeMode = false});

  final bool left;
  final String pairId;
  final bool safeMode;

  static final _name = RegExp(r'^G1v0(S?)_([LR])$');

  static SkAdvert? parse(String name, Map<int, List<int>> manufacturer) {
    final m = _name.firstMatch(name);
    if (m == null) return null;
    final left = m.group(2) == 'L';
    var pairId = '';
    final data = manufacturer[0xFFFF];
    if (data != null && data.length > 2 && data[0] == 1) {
      pairId = ascii.decode(data.sublist(2), allowInvalid: true);
    }
    return SkAdvert(left, pairId, safeMode: m.group(1) == 'S');
  }
}
