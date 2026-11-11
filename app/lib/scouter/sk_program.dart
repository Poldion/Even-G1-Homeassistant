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
/// app shows a text the program draws nothing. The dashboard is drawn band
/// by band through a buffer of its own, so the app's frame stays untouched.
/// Each band ([entryWords] words at [lines]): x and y, the glyphs of its
/// text (address, count; 0 for none), its rectangles (first index and
/// count in [rects], 5 words each: x, y within the band, w, h, level), the
/// frame and rule of a styled dashboard cut to the band, and the text's
/// level.
class SkResident {
  // Arena layout, behind the app's frame (0x10000–0x35800).
  static const table = 0x35800;
  static const pool = 0x35840;
  static const poolWords = 112;
  static const state = 0x35A00;
  static const lines = 0x35B00;
  static const entryWords = 7;
  static const maxEntries = 18;
  static const maxLines = 16;
  static const rects = 0x35D00;
  static const maxRects = 89;
  static const text = 0x36400;
  static const textEnd = labelText;

  /// The recording label's glyphs (small font).
  static const labelText = statusText - labelMax;
  static const labelMax = 64;

  /// The two status lines (no phone, no Home Assistant), [statusMax]
  /// glyph bytes each, at the end of the text area.
  static const statusText = band - 2 * statusMax;
  static const statusMax = 64;
  static const band = 0x37000;
  static const bandRows = 32;
  static const code = 0x39800;
  static const codeEnd = SkArena.smallFont;

  // State words (written by the app unless noted).
  static final busy = SkW.at(state); // 1 while the app shows something
  static final shown = SkW.at(state + 4); // program: dashboard on the panel
  static final count = SkW.at(state + 8); // dashboard lines
  static final up = SkW.at(state + 12); // program: head up
  static final angle = SkW.at(state + 16); // head-up angle, degrees
  static final flags = SkW.at(state + 20); // bit 0 dashboard, bit 1 gestures
  static final left = SkW.at(state + 24); // x of the text
  static final ascent = SkW.at(state + 28); // baseline in the band
  static final rows = SkW.at(state + 32); // bands to draw
  static final lineHeight = SkW.at(state + 36); // band height on the panel
  // The clock (written per arm by the app): the address of the "HH:MM"
  // glyphs in the dashboard's text (0: none), the arm time when the current
  // minute began and that minute of the day. The program counts on by
  // itself, also without the phone, and draws the digits.
  static final clockAt = SkW.at(state + 40);
  static final clockRef = SkW.at(state + 44);
  static final clockMinute = SkW.at(state + 48);
  static const minuteUs = 60000000;
  // Gesture state (program).
  static final _tick = SkW.at(state + 64);
  static final _cool = SkW.at(state + 68);
  static final _signX = SkW.at(state + 72);
  static final _countX = SkW.at(state + 76);
  static final _timeX = SkW.at(state + 80);
  static final _signY = SkW.at(state + 84);
  static final _countY = SkW.at(state + 88);
  static final _timeY = SkW.at(state + 92);
  static final _beat = SkW.at(state + 96);

  // Status line below the dashboard (written by the app): Home Assistant
  // unreachable, the line's y (0: no room), the glyph counts of the two
  // texts; the program keeps which one it shows (0 none, 1 no phone, 2 no
  // Home Assistant).
  static final haOffline = SkW.at(state + 52);
  static final statusY = SkW.at(state + 56);
  static final statusShown = SkW.at(state + 60);
  static final statusN1 = SkW.at(state + 100);
  static final statusN2 = SkW.at(state + 104);

  // The microphone (right arm, written by the app): its stand under the
  // firmware's indicator. The recording label (small font): glyph count (0:
  // none), where it goes, its width and its baseline.
  static final micOn = SkW.at(state + 108);
  static final labelN = SkW.at(state + 112);
  static final labelX = SkW.at(state + 116);
  static final labelY = SkW.at(state + 120);
  static final labelW = SkW.at(state + 124);
  static final labelBase = SkW.at(state + 128);
  static const labelH = 14;

  /// Added to a band's text level: the text is drawn bold.
  static const bold = 16;
  static const labelLevel = 12;
  static const maxLevel = 42;

  // Automatic brightness with an offset (right arm, written by the app):
  // on (1) or off, the offset in levels (signed); the program keeps the
  // level it set. The left arm follows over the arm-to-arm link
  // (AUTO_BRIGHTNESS 1 there, VM.md §6.9).
  static final lightOn = SkW.at(state + 132);
  static final lightOffset = SkW.at(state + 136);
  static final lightLevel = SkW.at(state + 140);

  /// Region of the microphone's stand; the firmware draws its 16 × 16
  /// indicator at (620, 4) on the right arm (VM.md §6.5): the head.
  static const standX = 610, standY = 2, standW = 30, standH = bandRows;
  static const standLevel = 11;

  /// The stand in panel coordinates: a holder around the indicator's lower
  /// half, a stem and a base.
  static const standRects = [
    (614, 10, 2, 14),
    (638, 10, 2, 14),
    (614, 22, 26, 2),
    (626, 24, 3, 7),
    (619, 31, 17, 2),
  ];

  /// Every [watchUs] each arm makes sure its panel is off while the head is
  /// down and the app shows nothing, and the right arm repeats its head
  /// state to the left one, so a missed message or a restart heals itself.
  static const watchUs = 5000000;
  static const statusLevel = 11;

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

  /// Head state over the arm-to-arm link (VM.md §6.9): the right arm
  /// ([peerLeader]) alone follows the tilt and tells the left arm
  /// ([peerFollower]); both show or hide the dashboard [peerLeadUs] after
  /// the decision, so both eyes switch together. [peerNone]: each arm
  /// decides itself (firmware without the link).
  static const peerNone = 0;
  static const peerLeader = 1;
  static const peerFollower = 2;
  static const peerUp = 1;
  static const peerDown = 2;
  static const peerLeadUs = 150000;

  /// The program's code and constant pool; [gestures] adds the detector
  /// (right arm: the gyroscope runs only then).
  static ({Uint8List code, Uint8List pool, Uint8List table}) build({
    required bool gestures,
    int peer = peerNone,
    bool micArm = false,
  }) {
    final a = SkAsm(codeAt: code, poolAt: pool, poolWords: poolWords);
    const r0 = SkW.r(0), r1 = SkW.r(1), r2 = SkW.r(2), r3 = SkW.r(3);
    const r4 = SkW.r(4), r5 = SkW.r(5), r6 = SkW.r(6), r7 = SkW.r(7);
    const r8 = SkW.r(8), r9 = SkW.r(9), r10 = SkW.r(10), r11 = SkW.r(11);
    const r12 = SkW.r(12), r13 = SkW.r(13), r14 = SkW.r(14);
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
    // A restart leaves the panel's image: dark until the head is up.
    a.call('darken');
    a.call('armTimer');
    if (peer == peerFollower) a.end();

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
    if (peer == peerLeader) _tell(a, peerUp);
    a.call('show');
    a.jmp('range');
    a.label('isUp');
    a.sub(r2, r1, a.c(10));
    a.blts(r0, r2, 'goDown'); // pitch < angle - 10
    a.jmp('range');
    a.label('goDown');
    a.mov(up, c0);
    a.notify(a.c(notifyHead), c0);
    if (peer == peerLeader) _tell(a, peerDown);
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

    // USER3: the microphone went on or off, or the app cleared the panel.
    a.label('user3');
    a.call('stand');
    a.end();

    // USER2: Home Assistant became reachable or unreachable.
    a.label('user2');
    a.beq(shown, c0, 'done');
    a.call('statusCheck');
    a.end();

    // USER1: the app set the clock anew.
    a.label('user1');
    a.call('armTimer');
    a.end();

    // armTimer: without the gesture detector the timer fires when the next
    // minute begins (the detector's timer ticks every 20 ms anyway).
    a.label('armTimer');
    if (!gestures) {
      // The next check, or the next minute if that comes first.
      a.sysRead(r0, a.c(SkProp.timeUs));
      a.add(r0, r0, a.c(watchUs));
      a.beq(clockAt, c0, 'armSet');
      a.add(r1, clockRef, a.c(minuteUs));
      a.sub(r2, r1, r0);
      a.bges(r2, c0, 'armSet');
      a.mov(r0, r1);
      a.label('armSet');
      a.sysWrite(a.c(SkProp.timer), r0);
    }
    a.ret();

    // darken: the panel off while the head is down and the app shows
    // nothing (it may still hold an old image).
    a.label('darken');
    a.bne(up, c0, 'ret');
    a.bne(busy, c0, 'ret');
    // With the microphone on the panel stays on anyway: only an image to
    // clear, then the stand again.
    a.beq(micOn, c0, 'darkenOff');
    a.beq(shown, c0, 'ret');
    a.label('darkenOff');
    a.sysWrite(a.c(SkProp.panel), c0);
    a.mov(shown, c0);
    a.jmp('stand');

    // watch: darken, and the right arm repeats its head state.
    a.label('watch');
    a.call('darken');
    if (peer == peerLeader) {
      a.mov(r0, a.c(peerDown));
      a.beq(up, c0, 'beat');
      a.mov(r0, a.c(peerUp));
      a.label('beat');
      a.sysWrite(a.c(SkProp.peerSend), r0);
    }
    // The light, in case a change was missed.
    a.call('light');
    // The status line follows the connection while the dashboard shows.
    a.beq(shown, c0, 'ret');
    a.call('statusCheck');
    a.ret();

    // light: stock's level for the measured light plus the offset, and a
    // new range of ±25 % (at least ±2 lux) around the reading (LIGHT).
    a.label('light');
    if (micArm) {
      a.beq(lightOn, c0, 'ret');
      a.sysRead(r0, a.c(SkProp.light)); // 0.01 lux
      a.beq(r0, a.c(SkProp.unknown), 'ret');
      a.divu(r1, r0, a.c(100)); // lux
      final c50 = a.c(50), c200 = a.c(200), c1000 = a.c(1000);
      a.bgeu(r1, c50, 'l50');
      a.divu(r2, r1, a.c(5));
      a.jmp('lOff');
      a.label('l50');
      a.bgeu(r1, c200, 'l200');
      a.sub(r2, r1, c50);
      a.divu(r2, r2, a.c(10));
      a.add(r2, r2, a.c(10));
      a.jmp('lOff');
      a.label('l200');
      a.bgeu(r1, c1000, 'l1000');
      a.sub(r2, r1, c200);
      a.divu(r2, r2, c50);
      a.add(r2, r2, a.c(25));
      a.jmp('lOff');
      a.label('l1000');
      a.mov(r2, a.c(41));
      a.bltu(r1, a.c(2000), 'lOff');
      a.mov(r2, a.c(maxLevel));
      a.label('lOff');
      a.add(r2, r2, lightOffset);
      a.bges(r2, c0, 'lMin');
      a.mov(r2, c0);
      a.label('lMin');
      a.blts(r2, a.c(maxLevel + 1), 'lMax');
      a.mov(r2, a.c(maxLevel));
      a.label('lMax');
      a.beq(r2, lightLevel, 'lRange');
      a.mov(lightLevel, r2);
      a.sysWrite(a.c(SkProp.brightness), r2);
      a.label('lRange');
      a.divu(r3, r0, a.c(4));
      a.bgeu(r3, c200, 'lMargin');
      a.mov(r3, c200);
      a.label('lMargin');
      a.sub(r4, r0, r3);
      a.bges(r4, c0, 'lLo');
      a.mov(r4, c0);
      a.label('lLo');
      a.add(r5, r0, r3);
      a.sysWrite(a.c(SkProp.lightLo), r4);
      a.sysWrite(a.c(SkProp.lightHi), r5);
    }
    a.ret();

    // LIGHT: the light left its range.
    a.label('lightTrigger');
    a.call('light');
    a.end();

    // tick: a new minute: count on, redraw if the dashboard is shown.
    a.label('tick');
    a.beq(clockAt, c0, 'ret');
    a.sysRead(r9, a.c(SkProp.timeUs));
    a.sub(r10, r9, clockRef);
    a.bltu(r10, a.c(minuteUs), 'ret');
    a.add(clockRef, clockRef, a.c(minuteUs));
    a.add(clockMinute, clockMinute, c1);
    a.bltu(clockMinute, a.c(1440), 'tickShow');
    a.sub(clockMinute, clockMinute, a.c(1440));
    a.label('tickShow');
    a.beq(shown, c0, 'ret');
    a.call('show');
    a.ret();

    // digits: "HH:MM" of clockMinute into the text (glyph i is digit i).
    a.label('digits');
    a.beq(clockAt, c0, 'ret');
    final ten = a.c(10);
    a.divu(r9, clockMinute, a.c(60));
    a.modu(r10, clockMinute, a.c(60));
    a.divu(r11, r9, ten);
    a.st8(clockAt, c0, r11);
    a.modu(r11, r9, ten);
    a.st8(clockAt, c1, r11);
    a.divu(r11, r10, ten);
    a.st8(clockAt, a.c(3), r11);
    a.modu(r11, r10, ten);
    a.st8(clockAt, a.c(4), r11);
    a.ret();

    // show: draws the dashboard, band by band.
    a.label('show');
    a.and(r0, flags, a.c(flagDashboard));
    a.beq(r0, c0, 'ret');
    a.bne(busy, c0, 'ret');
    a.beq(count, c0, 'ret');
    a.call('digits');
    a.mov(r3, c0); // band i
    a.label('line');
    a.mul(r4, r3, a.c(entryWords));
    final table = a.c(lines);
    void next(SkW d) {
      a.ld32(d, table, r4);
      a.add(r4, r4, c1);
    }

    next(r9); // x
    next(r5); // y
    next(r7); // text address
    next(r8); // glyphs
    next(r10); // first rectangle
    next(r11); // rectangles
    next(r14); // text level
    final bandW = a.c(SkPanel.width), stride = a.c(SkPanel.stride);
    final bandAt = a.c(band);
    a.fill(bandAt, stride, c0, c0, bandW, lineHeight, c0);
    a.label('rect');
    a.beq(r11, c0, 'text');
    a.mul(r12, r10, a.c(5));
    final rectTable = a.c(rects);
    for (final d in [r0, r1, r2, r6, r13]) {
      a.ld32(d, rectTable, r12);
      a.add(r12, r12, c1);
    }
    a.fill(bandAt, stride, r0, r1, r2, r6, r13);
    a.add(r10, r10, c1);
    a.sub(r11, r11, c1);
    a.jmp('rect');
    a.label('text');
    a.beq(r8, c0, 'blank');
    // Bold: the glyphs once more, one pixel to the right.
    a.bltu(r14, a.c(bold), 'glyphs');
    a.sub(r14, r14, a.c(bold));
    a.add(r12, r9, c1);
    a.glyphs(
      a.c(SkArena.font),
      bandAt,
      stride,
      r12,
      ascent,
      a.c(2), // MASK
      r14,
      r7,
      r8,
    );
    a.label('glyphs');
    a.glyphs(
      a.c(SkArena.font),
      bandAt,
      stride,
      r9,
      ascent,
      a.c(2), // MASK
      r14,
      r7,
      r8,
    );
    a.label('blank');
    a.draw(bandAt, stride, c0, c0, c0, r5, bandW, lineHeight);
    a.add(r3, r3, c1);
    a.bltu(r3, rows, 'line');
    a.call('status');
    a.call('label');
    a.call('stand');
    a.mov(shown, c1);
    a.label('ret');
    a.ret();

    // statusId: r1 = the status to show: 1 when this arm has no phone
    // (LINK), 2 when the app reports Home Assistant unreachable, else 0.
    a.label('statusId');
    a.mov(r1, c0);
    a.sysRead(r0, a.c(SkProp.hostLink));
    a.bne(r0, c0, 'stHa');
    a.mov(r1, c1);
    a.ret();
    a.label('stHa');
    a.beq(haOffline, c0, 'ret');
    a.mov(r1, a.c(2));
    a.ret();

    // status: draws the status line (empty without a status).
    a.label('status');
    a.call('statusId');
    a.label('stDraw');
    a.mov(statusShown, r1);
    a.beq(statusY, c0, 'ret');
    final sBand = a.c(band), sStride = a.c(SkPanel.stride);
    a.fill(sBand, sStride, c0, c0, a.c(SkPanel.width), lineHeight, c0);
    a.beq(r1, c0, 'stOut');
    a.mov(r2, a.c(statusText));
    a.mov(r3, statusN1);
    a.beq(r1, c1, 'stText');
    a.mov(r2, a.c(statusText + statusMax));
    a.mov(r3, statusN2);
    a.label('stText');
    a.glyphs(
      a.c(SkArena.font),
      sBand,
      sStride,
      left,
      ascent,
      a.c(2), // MASK
      a.c(statusLevel),
      r2,
      r3,
    );
    a.label('stOut');
    a.draw(sBand, sStride, c0, c0, c0, statusY, a.c(SkPanel.width), lineHeight);
    a.ret();

    // label: the recording label in the small font (e.g. on the frame's
    // top line).
    a.label('label');
    a.beq(labelN, c0, 'ret');
    final lb = a.c(band), ls = a.c(SkPanel.stride);
    a.fill(lb, ls, c0, c0, labelW, a.c(labelH), c0);
    a.glyphs(
      a.c(SkArena.smallFont),
      lb,
      ls,
      a.c(4),
      labelBase,
      a.c(2), // MASK
      a.c(labelLevel),
      a.c(labelText),
      labelN,
    );
    a.draw(lb, ls, c0, c0, labelX, labelY, labelW, a.c(labelH));
    a.ret();

    // stand: the microphone's stand under the firmware's indicator (right
    // arm), or its place cleared. Draws only on a panel that is on.
    a.label('stand');
    if (micArm) {
      a.bne(micOn, c0, 'standDraw');
      a.beq(shown, c0, 'ret');
      a.label('standDraw');
      final sb = a.c(band), ss = a.c(SkPanel.stride);
      a.fill(sb, ss, c0, c0, a.c(standW), a.c(standH), c0);
      a.beq(micOn, c0, 'standOut');
      for (final (x, y, w, h) in standRects) {
        a.fill(
          sb,
          ss,
          a.c(x - standX),
          a.c(y - standY),
          a.c(w),
          a.c(h),
          a.c(standLevel),
        );
      }
      a.label('standOut');
      a.draw(
        sb,
        ss,
        c0,
        c0,
        a.c(standX),
        a.c(standY),
        a.c(standW),
        a.c(standH),
      );
    }
    a.ret();

    // statusCheck: redraws the status line if it changed.
    a.label('statusCheck');
    a.call('statusId');
    a.beq(r1, statusShown, 'ret');
    a.jmp('stDraw');

    // hide: the panel off again unless the app shows something.
    a.label('hide');
    a.beq(shown, c0, 'ret');
    a.mov(shown, c0);
    a.bne(busy, c0, 'ret');
    a.sysWrite(a.c(SkProp.panel), c0);
    // The microphone holds the panel on: its stand again.
    a.jmp('stand');

    if (gestures) {
      // TIMER every 20 ms: the gyroscope's rates about x (nodding) and
      // y (shaking the head).
      a.label('timer');
      a.sysRead(r0, a.c(SkProp.timeUs));
      a.add(r0, r0, a.c(periodUs));
      a.sysWrite(a.c(SkProp.timer), r0);
      a.call('tick');
      a.add(_beat, _beat, c1);
      a.bltu(_beat, a.c(watchUs ~/ periodUs), 'noWatch');
      a.mov(_beat, c0);
      a.call('watch');
      a.label('noWatch');
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

    if (!gestures) {
      // TIMER: a new minute (the clock).
      a.label('timer');
      a.call('tick');
      a.call('watch');
      a.call('armTimer');
      a.end();
    }

    if (peer == peerFollower) {
      // PEER: the right arm decided; switch at the same moment.
      a.label('peer');
      a.sysRead(r0, a.c(SkProp.peerMsg));
      a.sysRead(r1, a.c(SkProp.peerTUs));
      a.add(r1, r1, a.c(peerLeadUs));
      a.beq(r0, a.c(peerUp), 'peerUp');
      a.beq(r0, a.c(peerDown), 'peerDown');
      a.end();
      a.label('peerUp');
      a.bne(up, c0, 'peerDone');
      a.mov(up, c1);
      a.sleepUntil(r1);
      a.call('show');
      a.end();
      a.label('peerDown');
      a.beq(up, c0, 'peerDone');
      a.mov(up, c0);
      a.sleepUntil(r1);
      a.call('hide');
      a.label('peerDone');
      a.end();
    }

    // Everything drawn through the band must fit it (the code follows it).
    assert(labelH <= bandRows && standH <= bandRows);
    final bytes = a.build();
    if (code + bytes.length > codeEnd) throw StateError('program too long');
    final t = ByteData(64);
    void entry(int trigger, String label) =>
        t.setUint32(trigger * 4, a.addressOf(label), Endian.little);
    entry(SkTrigger.start, 'start');
    if (peer != peerFollower) entry(SkTrigger.tilt, 'tilt');
    if (peer == peerFollower) entry(SkTrigger.peer, 'peer');
    entry(SkTrigger.user0, 'user0');
    entry(SkTrigger.timer, 'timer');
    entry(SkTrigger.user1, 'user1');
    entry(SkTrigger.user2, 'user2');
    entry(SkTrigger.user3, 'user3');
    if (micArm) entry(SkTrigger.light, 'lightTrigger');
    return (code: bytes, pool: a.pool(), table: t.buffer.asUint8List());
  }

  /// Sends [value] to the left arm and waits [peerLeadUs] from now, the
  /// moment the left arm switches too.
  static void _tell(SkAsm a, int value) {
    const r9 = SkW.r(9);
    a.sysRead(r9, a.c(SkProp.timeUs));
    a.sysWrite(a.c(SkProp.peerSend), a.c(value));
    a.add(r9, r9, a.c(peerLeadUs));
    a.sleepUntil(r9);
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
