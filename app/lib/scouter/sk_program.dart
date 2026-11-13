import 'dart:typed_data';

import 'sk_asm.dart';
import 'sk_protocol.dart';
import 'sk_style.dart';

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
  static const labelText = band - labelMax;
  static const labelMax = 64;

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
  static final _headBeat = SkW.at(state + 148);
  // Composing the dashboard in the frame (program): a band's address and
  // the rows drawn.
  static final _dst = SkW.at(state + 152);
  static final _minY = SkW.at(state + 156);
  static final _maxY = SkW.at(state + 160);
  // Both eyes (program): the right arm repeats "down" this many more
  // times; the left arm's time of the last message from the right one.
  static final _downBeats = SkW.at(state + 164);
  static final _lastBeat = SkW.at(state + 168);
  // Automatic brightness (right arm, program): the smoothed level (× 16)
  // and the time of the last reading.
  static final _lightAvg = SkW.at(state + 172);
  static final _lightAt = SkW.at(state + 176);
  // When the sensor's first reading after the panel came on arrived (0:
  // the panel was off).
  static final _lightWarm = SkW.at(state + 180);
  // Head up pending since (0: none) and the recent rotation (program).
  static final _pendingUp = SkW.at(state + 184);
  static final _rotation = SkW.at(state + 188);

  // Connection symbols at the dashboard's top right (written by the app):
  // Home Assistant unreachable, where they go (y 0: nowhere); the program
  // keeps which state it shows (0 both connected, 1 no phone, 2 no Home
  // Assistant).
  static final haOffline = SkW.at(state + 52);
  static final statusY = SkW.at(state + 56);
  static final statusShown = SkW.at(state + 60);
  static final statusX = SkW.at(state + 100);
  static final statusGround = SkW.at(state + 104); // the symbols' ground level
  static final statusInk = SkW.at(state + 144); // and their ink

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

  /// While the dashboard shows, each arm checks the pitch itself this
  /// often: a missed or late TILT never leaves the panel on.
  static const headCheckUs = 400000;

  /// While the head is up the right arm repeats "up" at every check; the
  /// left arm switches off when it heard nothing for this long (the right
  /// arm gone). After "down" the right arm repeats it [downBeats] times.
  static const followerTimeoutUs = 1500000;

  /// Automatic brightness: each reading moves the smoothed level a third
  /// of the way; the panel's level moves at most [lightStep] per reading
  /// (every [headCheckUs] while the panel is on). After [lightFreshUs]
  /// without a reading the first one counts at once.
  static const lightStep = 3;

  /// The logarithmic curve, level = 2 + 10 · log10(lux): its slope per
  /// eighth of log2 of the reading, × 256 (10 · log10(2) / 8 · 256 ≈ 96),
  /// and what is subtracted (10 · log10(100) − 2 for the reading's 0.01 lux).
  static const logScale = 96;
  static const logShift = 18;
  static const lightFreshUs = 2000000;

  /// The sensor runs only while the panel is on (VM.md §6.7) and converts
  /// every 800 ms: readings within this time after the first one are
  /// dropped (an old value or a conversion that started dark).
  static const lightWarmUs = 900000;
  static const downBeats = 3;

  static const flagDashboard = 1;
  static const flagGestures = 2;

  /// With the head gestures (gyroscope on): the dashboard comes only if
  /// the head really turned.
  static const flagGyroCheck = 4;

  /// The head must stay up this long before the dashboard comes: a bump or
  /// braking tilts the measured pitch only briefly.
  static const upDelayUs = 250000;

  /// Gyroscope check: the rotation about the nodding axis in about the last
  /// second (millidegrees, decaying) must reach this.
  static const rotationMdeg = 5000;

  static const notifyHead = 1;
  static const notifyGesture = 2;

  /// A new brightness: b = the light (0.01 lux, low 24 bits) and the level
  /// (high 8 bits), for the app's log.
  static const notifyLight = 3;
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
    a.call('head');
    a.end();

    // head: up or down by the pitch, then a new range around the state.
    a.label('head');
    a.sysRead(r0, a.c(SkProp.pitch));
    a.beq(r0, a.c(SkProp.unknown), 'range');
    a.mov(r1, angle);
    a.bne(up, c0, 'isUp');
    a.blts(r1, r0, 'upMaybe'); // angle < pitch
    // Below again: no head up pending.
    a.mov(_pendingUp, c0);
    a.jmp('range');
    // Up only if it stays up for upDelayUs (and, with the gyroscope check,
    // the head turned); meanwhile TILT is silent and the timer checks.
    a.label('upMaybe');
    a.sysRead(r6, a.c(SkProp.timeUs));
    a.bne(_pendingUp, c0, 'upPending');
    a.mov(_pendingUp, r6);
    a.bne(_pendingUp, c0, 'upWait');
    a.mov(_pendingUp, c1);
    a.label('upWait');
    a.sysWrite(a.c(SkProp.pitchLo), a.c(-90));
    a.sysWrite(a.c(SkProp.pitchHi), a.c(90));
    a.call('armTimer');
    a.ret();
    a.label('upPending');
    a.sub(r7, r6, _pendingUp);
    a.bltu(r7, a.c(upDelayUs), 'ret');
    if (gestures) {
      a.and(r7, flags, a.c(flagGyroCheck));
      a.beq(r7, c0, 'goUp');
      a.bgeu(_rotation, a.c(rotationMdeg), 'goUp');
      // Tilted, but the head did not turn (braking, a bump): wait on.
      a.mov(_pendingUp, r6);
      a.ret();
    }
    a.label('goUp');
    a.mov(_pendingUp, c0);
    a.mov(up, c1);
    a.notify(a.c(notifyHead), c1);
    if (peer == peerLeader) _tell(a, peerUp);
    a.call('show');
    // Checks the pitch again soon (TIMER).
    a.call('armTimer');
    a.jmp('range');
    a.label('isUp');
    a.sub(r2, r1, a.c(10));
    a.blts(r0, r2, 'goDown'); // pitch < angle - 10
    a.jmp('range');
    a.label('goDown');
    a.mov(up, c0);
    if (peer == peerLeader) a.mov(_downBeats, a.c(downBeats));
    a.notify(a.c(notifyHead), c0);
    if (peer == peerLeader) _tell(a, peerDown);
    a.call('hide');
    // A new range around the state, 10° hysteresis. TILT fires only when
    // the pitch leaves the range: if it is outside already (the head moved
    // while the dashboard was drawn), decide again now.
    a.label('range');
    a.bne(up, c0, 'rangeUp');
    a.sysWrite(a.c(SkProp.pitchLo), a.c(-90));
    a.sysWrite(a.c(SkProp.pitchHi), angle);
    a.sysRead(r0, a.c(SkProp.pitch));
    a.beq(r0, a.c(SkProp.unknown), 'ret');
    a.blts(angle, r0, 'head'); // angle < pitch: up after all
    a.ret();
    a.label('rangeUp');
    a.sub(r2, angle, a.c(10));
    a.sysWrite(a.c(SkProp.pitchLo), r2);
    a.sysWrite(a.c(SkProp.pitchHi), a.c(90));
    a.sysRead(r0, a.c(SkProp.pitch));
    a.beq(r0, a.c(SkProp.unknown), 'ret');
    a.blts(r0, r2, 'head'); // pitch < angle - 10: down after all
    a.ret();

    // headCheck: while up, the pitch itself; the head went down without a
    // TILT: down now. The right arm repeats its state to the left one; the
    // left arm switches off when the right one went silent.
    a.label('headCheck');
    if (peer == peerFollower) {
      a.beq(up, c0, 'ret');
      a.sysRead(r0, a.c(SkProp.timeUs));
      a.sub(r0, r0, _lastBeat);
      a.bltu(r0, a.c(followerTimeoutUs), 'ret');
      a.mov(up, c0);
      a.jmp('hide');
    } else {
      // A head up pending: decide now (the delay may be over).
      a.bne(up, c0, 'hcIsUp');
      a.bne(_pendingUp, c0, 'head');
      a.label('hcIsUp');
      if (peer == peerLeader) {
        a.bne(up, c0, 'hcBeat');
        a.beq(_downBeats, c0, 'ret');
        a.sub(_downBeats, _downBeats, c1);
        a.sysWrite(a.c(SkProp.peerSend), a.c(peerDown));
        a.ret();
        a.label('hcBeat');
        a.sysWrite(a.c(SkProp.peerSend), a.c(peerUp));
      } else {
        a.beq(up, c0, 'ret');
      }
      a.sysRead(r0, a.c(SkProp.pitch));
      a.beq(r0, a.c(SkProp.unknown), 'ret');
      a.sub(r2, angle, a.c(10));
      a.bges(r0, r2, 'ret');
      a.jmp('head');
    }

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
      // The next check (soon while the head is up), or the next minute if
      // that comes first.
      a.sysRead(r0, a.c(SkProp.timeUs));
      a.beq(_pendingUp, c0, 'armNoPend');
      // Head up pending: check again right after the delay.
      a.add(r0, r0, a.c(upDelayUs ~/ 4));
      a.jmp('armSet');
      a.label('armNoPend');
      a.add(r0, r0, a.c(watchUs));
      a.bne(up, c0, 'armSoon');
      if (peer == peerLeader) {
        a.bne(_downBeats, c0, 'armSoon');
      }
      // The panel is on for the app: the light is read often then too.
      if (micArm) {
        a.beq(lightOn, c0, 'armClock');
        a.bne(busy, c0, 'armSoon');
      }
      a.jmp('armClock');
      a.label('armSoon');
      a.sub(r0, r0, a.c(watchUs - headCheckUs));
      a.label('armClock');
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
      a.beq(r0, a.c(SkProp.unknown), 'lCold');
      // Warming up: the first readings after the panel came on are dropped.
      a.sysRead(r6, a.c(SkProp.timeUs));
      a.bne(_lightWarm, c0, 'lWarm');
      a.mov(_lightWarm, r6);
      a.bne(_lightWarm, c0, 'ret');
      a.mov(_lightWarm, c1);
      a.ret();
      a.label('lWarm');
      a.sub(r7, r6, _lightWarm);
      a.bltu(r7, a.c(lightWarmUs), 'ret');
      a.divu(r1, r0, a.c(100)); // lux
      a.bne(lightOn, c1, 'lLog');
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
      a.jmp('lOff');
      // lightOn 2: the logarithmic curve, the same step for every tenfold
      // light: level = 2 + 10 · log10(lux) (1 lux 2, 10 lux 12, 100 lux 22,
      // 1000 lux 32, 10,000 lux 42). log2 of the reading (0.01 lux) in
      // eighths: halve it to 8…15, count the halvings.
      a.label('lLog');
      a.mov(r3, r0);
      a.mov(r4, c0);
      a.label('lLog2');
      a.bltu(r3, a.c(16), 'lLog3');
      a.divu(r3, r3, a.c(2));
      a.add(r4, r4, c1);
      a.jmp('lLog2');
      a.label('lLog3');
      // r2 = 8 · log2(reading) = 8 · (r4 + 3) + (r3 − 8)
      a.mul(r2, r4, a.c(8));
      a.add(r2, r2, r3);
      a.add(r2, r2, a.c(16));
      // level = 10 · log10(reading / 100) + 2 = r2 · 0.376 − 18
      a.mul(r2, r2, a.c(logScale));
      a.add(r2, r2, a.c(128));
      a.divu(r2, r2, a.c(256));
      a.sub(r2, r2, a.c(logShift));
      a.label('lOff');
      a.add(r2, r2, lightOffset);
      a.bges(r2, c0, 'lMin');
      a.mov(r2, c0);
      a.label('lMin');
      a.blts(r2, a.c(maxLevel + 1), 'lMax');
      a.mov(r2, a.c(maxLevel));
      a.label('lMax');
      // Smoothing: the sensor sits on the arm and jumps with every turn of
      // the head. r2 = this reading's level, r8 = it × 16.
      a.mul(r8, r2, a.c(16));
      a.sysRead(r6, a.c(SkProp.timeUs));
      a.sub(r7, r6, _lightAt);
      a.mov(_lightAt, r6);
      a.bltu(r7, a.c(lightFreshUs), 'lSmooth');
      // The first reading after a pause counts at once.
      a.mov(_lightAvg, r8);
      a.mov(r9, r2);
      a.jmp('lSet');
      a.label('lSmooth');
      a.bltu(r8, _lightAvg, 'lFall');
      a.sub(r9, r8, _lightAvg);
      a.add(r9, r9, a.c(2));
      a.divu(r9, r9, a.c(3));
      a.add(_lightAvg, _lightAvg, r9);
      a.jmp('lLevel');
      a.label('lFall');
      a.sub(r9, _lightAvg, r8);
      a.add(r9, r9, a.c(2));
      a.divu(r9, r9, a.c(3));
      a.sub(_lightAvg, _lightAvg, r9);
      a.label('lLevel');
      a.add(r9, _lightAvg, a.c(8));
      a.divu(r9, r9, a.c(16));
      // A dead band: one level off is no reason to change.
      a.add(r7, lightLevel, c1);
      a.bltu(r7, r9, 'lMove');
      a.add(r7, r9, c1);
      a.bltu(r7, lightLevel, 'lMove');
      a.jmp('lRange');
      a.label('lMove');
      // At most lightStep levels per reading: a fade, not a jump.
      a.add(r7, lightLevel, a.c(lightStep));
      a.bgeu(r7, r9, 'lUp');
      a.mov(r9, r7);
      a.label('lUp');
      a.blts(lightLevel, a.c(lightStep), 'lSet');
      a.sub(r7, lightLevel, a.c(lightStep));
      a.bgeu(r9, r7, 'lSet');
      a.mov(r9, r7);
      a.label('lSet');
      a.beq(r9, lightLevel, 'lRange');
      a.mov(lightLevel, r9);
      a.sysWrite(a.c(SkProp.brightness), r9);
      // For the app's log: the light that led to it.
      a.and(r7, r0, a.c(0xffffff));
      a.mul(r8, r9, a.c(0x1000000));
      a.or(r7, r7, r8);
      a.notify(a.c(notifyLight), r7);
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
    if (micArm) {
      // The panel is off: the sensor too.
      a.label('lCold');
      a.mov(_lightWarm, c0);
      a.ret();
    }

    // LIGHT: the light left its range.
    a.label('lightTrigger');
    a.call('light');
    a.end();

    // tick: a new minute: count on, redraw if the dashboard is shown.
    a.label('tick');
    a.beq(clockAt, c0, 'ret');
    a.sysRead(r9, a.c(SkProp.timeUs));
    a.sub(r10, r9, clockRef);
    // Signed: a minute start a little ahead (clock error) is no minute.
    a.blts(r10, a.c(minuteUs), 'ret');
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
    // All bands into the app's frame (free while the app shows nothing),
    // then one DRAW: the dashboard appears at once, not band by band.
    a.mov(_minY, a.c(SkPanel.height));
    a.mov(_maxY, c0);
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
    final bandAt = _dst;
    a.mul(_dst, r5, stride);
    a.add(_dst, _dst, a.c(SkArena.frame));
    a.bgeu(r5, _minY, 'minOk');
    a.mov(_minY, r5);
    a.label('minOk');
    a.add(r0, r5, lineHeight);
    a.bgeu(_maxY, r0, 'maxOk');
    a.mov(_maxY, r0);
    a.label('maxOk');
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
    a.add(r3, r3, c1);
    a.bltu(r3, rows, 'line');
    a.bgeu(_minY, _maxY, 'drawn');
    a.sub(r0, _maxY, _minY);
    a.draw(a.c(SkArena.frame), stride, c0, _minY, c0, _minY, bandW, r0);
    a.label('drawn');
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
    final sw = a.c(SkStatusIcons.width), sh = a.c(SkStatusIcons.height);
    final ink = statusInk, ground = statusGround;
    a.fill(sBand, sStride, c0, c0, sw, sh, ground);
    for (final (x, y, w, h, on) in [
      ...SkStatusIcons.phone,
      ...SkStatusIcons.server,
    ]) {
      a.fill(sBand, sStride, a.c(x), a.c(y), a.c(w), a.c(h), on ? ink : ground);
    }
    void strike(List<(int, int, int, int, bool)> lines) {
      for (final (x0, y0, x1, y1, on) in lines) {
        a.line(
          sBand,
          sStride,
          a.c(x0),
          a.c(y0),
          a.c(x1),
          a.c(y1),
          on ? ink : ground,
        );
      }
    }

    // No phone: both struck through (Home Assistant is out of reach too).
    a.beq(r1, c0, 'stOut');
    strike(SkStatusIcons.serverStrike);
    a.bne(r1, c1, 'stOut');
    strike(SkStatusIcons.phoneStrike);
    a.label('stOut');
    a.draw(sBand, sStride, c0, c0, statusX, statusY, sw, sh);
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
      // The rotation about the nodding axis: + |gx| × 20 ms, decaying by a
      // fiftieth per tick (about one second).
      a.sysRead(r1, a.c(SkProp.gyrX));
      a.beq(r1, a.c(SkProp.unknown), 'rotDone');
      a.bges(r1, c0, 'rotAbs');
      a.sub(r1, c0, r1);
      a.label('rotAbs');
      a.divu(r1, r1, a.c(1000 ~/ (periodUs ~/ 1000)));
      a.divu(r2, _rotation, a.c(50));
      a.sub(_rotation, _rotation, r2);
      a.add(_rotation, _rotation, r1);
      a.label('rotDone');
      a.beq(_pendingUp, c0, 'noPend');
      a.call('head');
      a.label('noPend');
      a.add(_beat, _beat, c1);
      a.bltu(_beat, a.c(watchUs ~/ periodUs), 'noWatch');
      a.mov(_beat, c0);
      a.call('watch');
      a.label('noWatch');
      a.add(_headBeat, _headBeat, c1);
      a.bltu(_headBeat, a.c(headCheckUs ~/ periodUs), 'noHead');
      a.mov(_headBeat, c0);
      a.call('headCheck');
      a.call('light');
      a.label('noHead');
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
      // TIMER: a new minute (the clock), the watch, and while the head is
      // up its check.
      a.label('timer');
      a.call('headCheck');
      a.call('tick');
      a.call('watch');
      a.call('armTimer');
      a.end();
    }

    if (peer == peerFollower) {
      // PEER: the right arm decided; switch at the same moment.
      a.label('peer');
      a.sysRead(r0, a.c(SkProp.timeUs));
      a.mov(_lastBeat, r0);
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
      a.call('armTimer');
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
