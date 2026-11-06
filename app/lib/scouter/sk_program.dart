import 'dart:typed_data';

import 'sk_asm.dart';
import 'sk_protocol.dart';

/// The program this app leaves running on each arm (VM.md §5): it shows the
/// Home Assistant dashboard when the head is raised, without the phone, and
/// on the right arm it can recognise nodding and shaking the head.
///
/// It reports to the app with `NOTIFY a, b`: a = [SkResident.notifyHead]
/// (b 1 up, 0 down) or [SkResident.notifyGesture] (b [SkResident.nod] or
/// [SkResident.shake]).
///
/// The app shares the display with it through [SkResident.busy]: while the
/// app shows a text the program draws nothing. The dashboard is drawn line
/// by line through a band of its own, so the app's frame stays untouched.
class SkResident {
  // Arena layout, behind the app's frame (0x10000–0x35800).
  static const table = 0x35800;
  static const pool = 0x35840;
  static const poolWords = 112;
  static const state = 0x35A00;
  static const lines = 0x35B00;
  static const maxLines = 20;
  static const text = 0x35C00;
  static const textEnd = band;
  static const band = 0x37000;
  static const bandRows = 32;
  static const code = 0x39800;
  static const codeEnd = SkArena.size;

  // State words (written by the app unless noted).
  static final busy = SkW.at(state); // 1 while the app shows something
  static final shown = SkW.at(state + 4); // program: dashboard on the panel
  static final count = SkW.at(state + 8); // dashboard lines
  static final up = SkW.at(state + 12); // program: head up
  static final angle = SkW.at(state + 16); // head-up angle, degrees
  static final flags = SkW.at(state + 20); // bit 0 dashboard, bit 1 gestures
  static final left = SkW.at(state + 24); // x of the text
  static final ascent = SkW.at(state + 28); // baseline in the band
  static final rows = SkW.at(state + 32); // lines to draw (blank ones too)
  static final lineHeight = SkW.at(state + 36); // band height on the panel
  // Gesture state (program).
  static final _tick = SkW.at(state + 64);
  static final _cool = SkW.at(state + 68);
  static final _signX = SkW.at(state + 72);
  static final _countX = SkW.at(state + 76);
  static final _timeX = SkW.at(state + 80);
  static final _signY = SkW.at(state + 84);
  static final _countY = SkW.at(state + 88);
  static final _timeY = SkW.at(state + 92);

  static const flagDashboard = 1;
  static const flagGestures = 2;

  static const notifyHead = 1;
  static const notifyGesture = 2;
  static const nod = 1;
  static const shake = 2;

  /// Gesture detector: sample period, rate threshold (mdps), how long a
  /// swing counts, the pause after a gesture (samples).
  static const periodUs = 20000;
  static const rateMdps = 90000;
  static const window = 20; // 0.4 s
  static const cooldown = 40; // 0.8 s
  static const nodSwings = 2; // down and up
  static const shakeSwings = 3; // left, right, left

  /// The program's code and constant pool; [gestures] adds the detector
  /// (right arm: the gyroscope runs only then).
  static ({Uint8List code, Uint8List pool, Uint8List table}) build({
    required bool gestures,
  }) {
    final a = SkAsm(codeAt: code, poolAt: pool, poolWords: poolWords);
    const r0 = SkW.r(0), r1 = SkW.r(1), r2 = SkW.r(2), r3 = SkW.r(3);
    const r4 = SkW.r(4), r5 = SkW.r(5), r6 = SkW.r(6), r7 = SkW.r(7);
    const r8 = SkW.r(8);
    final c0 = a.c(0), c1 = a.c(1);

    // START: sensors, then the head's state as at a tilt.
    a.label('start');
    if (gestures) {
      a.sysWrite(a.c(SkProp.imuRate), a.c(52));
      a.sysWrite(a.c(SkProp.gyroRate), a.c(52));
      a.sysRead(r0, a.c(SkProp.timeUs));
      a.add(r0, r0, a.c(periodUs));
      a.sysWrite(a.c(SkProp.timer), r0);
    }
    a.mov(up, c0);
    a.mov(shown, c0);

    // TILT: the pitch left its range.
    a.label('tilt');
    a.sysRead(r0, a.c(SkProp.pitch));
    a.beq(r0, a.c(SkProp.unknown), 'range');
    a.mov(r1, angle);
    a.bne(up, c0, 'isUp');
    a.blts(r1, r0, 'goUp'); // angle < pitch
    a.jmp('range');
    a.label('goUp');
    a.mov(up, c1);
    a.notify(a.c(notifyHead), c1);
    a.call('show');
    a.jmp('range');
    a.label('isUp');
    a.sub(r2, r1, a.c(10));
    a.blts(r0, r2, 'goDown'); // pitch < angle - 10
    a.jmp('range');
    a.label('goDown');
    a.mov(up, c0);
    a.notify(a.c(notifyHead), c0);
    a.call('hide');
    // A new range around the state, 10° hysteresis.
    a.label('range');
    a.bne(up, c0, 'rangeUp');
    a.sysWrite(a.c(SkProp.pitchLo), a.c(-90));
    a.sysWrite(a.c(SkProp.pitchHi), angle);
    a.end();
    a.label('rangeUp');
    a.sub(r2, angle, a.c(10));
    a.sysWrite(a.c(SkProp.pitchLo), r2);
    a.sysWrite(a.c(SkProp.pitchHi), a.c(90));
    a.end();

    // USER0: the app changed the dashboard; redraw it while it is shown.
    a.label('user0');
    a.beq(shown, c0, 'done');
    a.call('show');
    a.label('done');
    a.end();

    // show: draws the dashboard, line by line through the band.
    a.label('show');
    a.and(r0, flags, a.c(flagDashboard));
    a.beq(r0, c0, 'ret');
    a.bne(busy, c0, 'ret');
    a.beq(count, c0, 'ret');
    a.mov(r3, c0); // line i
    a.label('line');
    a.mul(r4, r3, a.c(3));
    a.ld32(r5, a.c(lines), r4); // y
    a.add(r6, r4, c1);
    a.ld32(r7, a.c(lines), r6); // text address
    a.add(r6, r4, a.c(2));
    a.ld32(r8, a.c(lines), r6); // glyphs
    final bandW = a.c(SkPanel.width), stride = a.c(SkPanel.stride);
    a.fill(a.c(band), stride, c0, c0, bandW, lineHeight, c0);
    a.bgeu(r3, count, 'blank'); // below the last line: empty
    a.glyphs(
      a.c(SkArena.font),
      a.c(band),
      stride,
      left,
      ascent,
      a.c(2), // MASK
      a.c(15),
      r7,
      r8,
    );
    a.label('blank');
    a.draw(a.c(band), stride, c0, c0, c0, r5, bandW, lineHeight);
    a.add(r3, r3, c1);
    a.bltu(r3, rows, 'line');
    a.mov(shown, c1);
    a.label('ret');
    a.ret();

    // hide: the panel off again unless the app shows something.
    a.label('hide');
    a.beq(shown, c0, 'ret');
    a.mov(shown, c0);
    a.bne(busy, c0, 'ret');
    a.sysWrite(a.c(SkProp.panel), c0);
    a.ret();

    if (gestures) {
      // TIMER every 20 ms: the gyroscope's rates about x (nodding) and
      // y (shaking the head).
      a.label('timer');
      a.sysRead(r0, a.c(SkProp.timeUs));
      a.add(r0, r0, a.c(periodUs));
      a.sysWrite(a.c(SkProp.timer), r0);
      a.add(_tick, _tick, c1);
      a.beq(_cool, c0, 'sample');
      a.sub(_cool, _cool, c1);
      a.end();
      a.label('sample');
      a.sysRead(r1, a.c(SkProp.gyrX));
      a.sysRead(r2, a.c(SkProp.gyrY));
      a.beq(r1, a.c(SkProp.unknown), 'tdone');
      a.beq(r2, a.c(SkProp.unknown), 'tdone');
      // r3 = |gx|, r4 = |gy|
      a.mov(r3, r1);
      a.bges(r3, c0, 'absx');
      a.sub(r3, c0, r3);
      a.label('absx');
      a.mov(r4, r2);
      a.bges(r4, c0, 'absy');
      a.sub(r4, c0, r4);
      a.label('absy');
      _axis(
        a,
        'x',
        rate: r1,
        mag: r3,
        other: r4,
        sign: _signX,
        n: _countX,
        at: _timeX,
      );
      _axis(
        a,
        'y',
        rate: r2,
        mag: r4,
        other: r3,
        sign: _signY,
        n: _countY,
        at: _timeY,
      );
      a.bltu(_countX, a.c(nodSwings), 'noNod');
      a.notify(a.c(notifyGesture), a.c(nod));
      a.jmp('gesture');
      a.label('noNod');
      a.bltu(_countY, a.c(shakeSwings), 'tdone');
      a.notify(a.c(notifyGesture), a.c(shake));
      a.label('gesture');
      a.mov(_cool, a.c(cooldown));
      a.mov(_countX, c0);
      a.mov(_countY, c0);
      a.mov(_signX, c0);
      a.mov(_signY, c0);
      a.label('tdone');
      a.end();
    }

    final bytes = a.build();
    if (code + bytes.length > codeEnd) throw StateError('program too long');
    final t = ByteData(64);
    void entry(int trigger, String label) =>
        t.setUint32(trigger * 4, a.addressOf(label), Endian.little);
    entry(SkTrigger.start, 'start');
    entry(SkTrigger.tilt, 'tilt');
    entry(SkTrigger.user0, 'user0');
    if (gestures) entry(SkTrigger.timer, 'timer');
    return (code: bytes, pool: a.pool(), table: t.buffer.asUint8List());
  }

  /// One axis of the detector: a swing is a rate above [rateMdps] that is
  /// at least twice the other axis'; each change of its direction counts,
  /// and [window] samples without a swing start the count again.
  static void _axis(
    SkAsm a,
    String name, {
    required SkW rate,
    required SkW mag,
    required SkW other,
    required SkW sign,
    required SkW n,
    required SkW at,
  }) {
    const r5 = SkW.r(5), r6 = SkW.r(6), r7 = SkW.r(7);
    final skip = 'skip$name', keep = 'keep$name';
    a.bltu(mag, a.c(rateMdps), skip);
    a.add(r5, other, other);
    a.bltu(mag, r5, skip);
    a.mov(r6, a.c(1));
    a.bges(rate, a.c(0), 'pos$name');
    a.mov(r6, a.c(2));
    a.label('pos$name');
    a.mov(at, _tick);
    a.beq(r6, sign, skip);
    a.mov(sign, r6);
    a.add(n, n, a.c(1));
    a.label(skip);
    a.sub(r7, _tick, at);
    a.bltu(r7, a.c(window), keep);
    a.mov(n, a.c(0));
    a.mov(sign, a.c(0));
    a.label(keep);
  }
}
