import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:even_g1_ha/g1/protocol.dart';
import 'package:even_g1_ha/scouter/scouter_connection.dart';
import 'package:even_g1_ha/scouter/sk_clock.dart';
import 'package:even_g1_ha/scouter/sk_emoji.dart';
import 'package:even_g1_ha/scouter/sk_font.dart';
import 'package:even_g1_ha/scouter/sk_icons.dart';
import 'package:even_g1_ha/scouter/sk_link.dart';
import 'package:even_g1_ha/scouter/sk_program.dart';
import 'package:even_g1_ha/scouter/sk_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

SkFont loadTestFont() =>
    SkFont.parse(File(ScouterConnection.fontAsset).readAsBytesSync())
        .scaled(2, keep: SkFont.textCodepoint);

/// An event as an arm sends it: type, epoch, device time, fields.
Uint8List event(int type, int epoch, List<int> fields) {
  final b = BytesBuilder()
    ..addByte(type)
    ..add(_u32(epoch))
    ..add(_u32(0))
    ..add(fields);
  return b.takeBytes();
}

List<int> _u16(int v) => [v & 0xff, (v >> 8) & 0xff];
List<int> _u32(int v) => [
  v & 0xff,
  (v >> 8) & 0xff,
  (v >> 16) & 0xff,
  (v >> 24) & 0xff,
];

Uint8List ack(int epoch, int rxNext, int execNext, {int credits = 32}) => event(
  SkEvt.ack,
  epoch,
  [..._u16(rxNext), ..._u16(execNext), credits, ..._u32(0)],
);

Uint8List input(int epoch, int trigger, int value) =>
    event(SkEvt.input, epoch, [..._u16(1), trigger, ..._u32(value)]);

Uint8List reply(int epoch, int op, int tag, int status, List<int> body) =>
    event(0x80 | op, epoch, [tag, status, ...body]);

List<int> helloBody({
  required bool left,
  int rxNext = 0,
  int flags = 0x02 | 0x40,
  int board = 0x04,
}) => [
  5, 0, 5, 60, // protocol 5, firmware 0.5.60
  left ? 1 : 0,
  flags,
  board,
  ..._u16(0x01ff),
  ..._u16(640),
  ..._u16(480),
  ..._u32(262144),
  32,
  ..._u16(244),
  ..._u16(rxNext),
  ..._u16(rxNext),
  32,
  ..._u32(1),
  ..._u32(0),
  0,
  0,
];

/// Runs the WRITE and WRITE_RLE instructions of host code on [arena];
/// other instructions are collected in [ops], the times of `SLEEP_UNTIL` in
/// [sleeps].
void execute(
  Uint8List code,
  Uint8List arena,
  List<int> ops, [
  List<int>? sleeps,
]) {
  var i = 0;
  int u24(int at) => code[at] | code[at + 1] << 8 | code[at + 2] << 16;
  while (i < code.length) {
    final op = code[i];
    if (op == SkOp.write) {
      final addr = u24(i + 1);
      final n = code[i + 4];
      arena.setRange(addr, addr + n, code.sublist(i + 5, i + 5 + n));
      i += 5 + n;
    } else if (op == SkOp.writeRle) {
      final addr = u24(i + 1);
      final len = code[i + 4] | code[i + 5] << 8;
      final n = code[i + 6];
      final data = unpackBits(code.sublist(i + 7, i + 7 + n));
      expect(data.length, len);
      arena.setRange(addr, addr + len, data);
      i += 7 + n;
    } else if (op == SkOp.call) {
      ops.add(op);
      i += 4;
    } else {
      if (op == SkOp.sleepUntil) {
        // One escaped operand: the word that holds the time.
        final word = code[i + 2] | code[i + 3] << 8;
        sleeps?.add(
          ByteData.sublistView(arena).getUint32(word * 4, Endian.little),
        );
      }
      final k = switch (op) {
        SkOp.sleepUntil => 1,
        SkOp.raise => 1,
        SkOp.add => 3,
        SkOp.sysRead => 2,
        SkOp.sysWrite => 2,
        SkOp.fill => 7,
        SkOp.blit => 12,
        SkOp.glyphs => 9,
        SkOp.draw => 8,
        SkOp.video => 10,
        _ => throw StateError('op 0x${op.toRadixString(16)}'),
      };
      ops.add(op);
      i += 1 + (k + 1) ~/ 2 + 2 * k;
    }
  }
}

/// Simulated g1v0 arms: answer control requests, ack and run packets.
class FakeArms {
  FakeArms({this.epoch = 7});

  final int epoch;
  late ScouterConnection connection;
  final arenas = {for (final s in G1Side.values) s: Uint8List(SkArena.size)};
  final ops = {for (final s in G1Side.values) s: <int>[]};
  final ctrl = {for (final s in G1Side.values) s: <Uint8List>[]};
  final props = <int, int>{};
  final sleeps = {for (final s in G1Side.values) s: <int>[]};

  /// Each arm's clock runs this far ahead of the host's (µs).
  final clockOffset = {G1Side.left: 5000000, G1Side.right: 123456789};
  bool answerPing = true;
  int micStatus = 0;
  bool acks = true;

  /// CMD packets received (both arms).
  int writes = 0;

  Future<void> write(G1Side side, int channel, Uint8List data) async {
    if (channel == 0) {
      writes++;
      final seq = data[0] | data[1] << 8;
      execute(
        Uint8List.sublistView(data, 2),
        arenas[side]!,
        ops[side]!,
        sleeps[side],
      );
      if (acks) {
        scheduleMicrotask(
          () => connection.receive(side, ack(epoch, seq + 1, seq + 1)),
        );
      }
      return;
    }
    ctrl[side]!.add(data);
    final op = data[0];
    final tag = data[1];
    final left = side == G1Side.left;
    final body = switch (op) {
      SkCtrl.hello => helloBody(left: left),
      SkCtrl.resetSession => [0, 0, ...helloBody(left: left)],
      SkCtrl.events => [data[2], data[3]],
      SkCtrl.props => [
        for (final id in data.sublist(2)) ..._u32(props[id] ?? SkProp.unknown),
      ],
      SkCtrl.mic => [data[2], 20, 5, ..._u16(16000), 10, ..._u16(2000)],
      SkCtrl.ping => [
        ...data.sublist(2, 6),
        ..._u32(SkClock.hostNow() + clockOffset[side]!),
        ..._u32(SkClock.hostNow() + clockOffset[side]!),
      ],
      _ => <int>[],
    };
    if (op == SkCtrl.ping && !answerPing) return;
    final status = op == SkCtrl.mic ? micStatus : 0;
    scheduleMicrotask(
      () => connection.receive(side, reply(epoch, op, tag, status, body)),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('encoding', () {
    test('operands go through the scratch words, escaped', () {
      final code = SkCode()..fill(0x4000, 80, 0, 0, 160, 32, 0);
      final bytes = code.take();
      // WRITE of 7 words to 0x100, then FILL with 7 escapes (VM.md §9.2).
      expect(bytes.sublist(0, 5), [0x01, 0x00, 0x01, 0x00, 28]);
      final fill = bytes.sublist(5 + 28);
      expect(fill.sublist(0, 5), [0x50, 0xff, 0xff, 0xff, 0xf0]);
      expect(fill.sublist(5, 7), [0x40, 0x00]); // word 64 = 0x100
      expect(fill.length, skOpSize(7) - 5 - 28);
      expect(bytes.length, skOpSize(7));
    });

    test('PackBits round trip', () {
      final rnd = Random(1);
      for (final data in [
        Uint8List(1000),
        Uint8List.fromList(List.generate(700, (_) => rnd.nextInt(4))),
        Uint8List.fromList(List.generate(300, (i) => i & 0xff)),
        Uint8List.fromList([1, 1, 2, 2, 2, 3]),
      ]) {
        expect(unpackBits(packBits(data)), data);
      }
      expect(packBits(Uint8List(1000)).length, lessThan(20));
    });

    test('an upload writes the data exactly', () {
      final rnd = Random(2);
      final data = Uint8List.fromList([
        ...List.filled(3000, 0),
        ...List.generate(2000, (_) => rnd.nextInt(256)),
        ...List.filled(500, 0xff),
      ]);
      final packets = skUpload(0x1000, data, 242);
      final arena = Uint8List(SkArena.size);
      for (final p in packets) {
        expect(p.length, lessThanOrEqualTo(242));
        execute(p, arena, []);
      }
      expect(arena.sublist(0x1000, 0x1000 + data.length), data);
    });
  });

  group('font', () {
    test('scaled subset keeps the slots and the German characters', () {
      final font = loadTestFont();
      expect(font.ascent, 22);
      expect(font.lineSpacing, 28);
      expect(font.blob.length, lessThan(SkArena.fontMax));
      expect(font.glyphOf('0'.codeUnitAt(0)), 0);
      expect(font.glyphOf('A'.codeUnitAt(0)), 10);
      expect(font.glyphOf('a'.codeUnitAt(0)), 36);
      for (final c in 'äöüÄÖÜß€°–…„“'.runes) {
        expect(font.glyphOf(c), isNot(font.glyphOf(0xFFFD)), reason: '$c');
      }
      expect(font.advanceOf(font.glyphOf(0x41)), 14);
      // Re-parsing the scaled blob gives the same font.
      final again = SkFont.parse(font.blob);
      expect(again.glyphCount, font.glyphCount);
    });

    test('long lines are wrapped at spaces', () {
      final font = loadTestFont();
      final lines = ScouterConnection.wrap(
        font,
        'Das ist ein ziemlich langer Satz, der nicht in eine Zeile der '
        'Brille passt und deshalb umbrochen wird.',
        592,
      );
      expect(lines.length, 3);
      for (final l in lines) {
        expect(font.width(l), lessThanOrEqualTo(592));
      }
    });
  });

  group('link', () {
    test('runs complete when executed, within the credits', () async {
      final sent = <int>[];
      final link = SkLink((p) async => sent.add(p[0] | p[1] << 8));
      link.start(10, 10, 2, 244);
      final done = link.run([
        Uint8List.fromList([0x33]),
        Uint8List.fromList([0x33]),
        Uint8List.fromList([0x33]),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(sent, [10, 11]);
      link.onAck(12, 12, 2, 0);
      await Future<void>.delayed(Duration.zero);
      expect(sent, [10, 11, 12]);
      link.onAck(13, 13, 2, 0);
      expect(await done, isTrue);
      link.dispose();
    });

    test('an error fails the run', () async {
      final link = SkLink((p) async {});
      link.start(0, 0, 32, 244);
      final done = link.run([
        Uint8List.fromList([0x33]),
      ]);
      link.onError(0);
      expect(await done, isFalse);
      link.dispose();
    });

    test('a hole in the selective ack is sent again', () async {
      final sent = <int>[];
      final link = SkLink((p) async => sent.add(p[0] | p[1] << 8));
      link.start(0, 0, 32, 244);
      unawaited(link.run([for (var i = 0; i < 3; i++) Uint8List(1)]));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      sent.clear();
      // Packet 0 missing, 1 and 2 held.
      link.onAck(0, 0, 32, 0x3);
      expect(sent, [0]);
      link.dispose();
    });
  });

  group('connection', () {
    late FakeArms arms;
    late ScouterConnection g1;

    setUp(() {
      arms = FakeArms();
      g1 = ScouterConnection.fake(arms.write, font: loadTestFont());
      arms.connection = g1;
    });

    tearDown(() => g1.dispose());

    test('setup uploads the font into both arenas', () async {
      arms.props[SkProp.battPct] = 80;
      arms.props[SkProp.inCase] = 0;
      arms.props[SkProp.worn] = 1;
      await g1.fakeSetup();
      expect(g1.connected, isTrue);
      // The font with its empty emoji slots.
      final font = loadTestFont()
          .withSlots(
            SkEmoji.slots,
            advance: SkEmoji.advance,
            slotBytes: SkEmoji.slotBytes,
          )
          .blob;
      for (final side in G1Side.values) {
        expect(
          arms.arenas[side]!.sublist(SkArena.font, SkArena.font + font.length),
          font,
        );
        final ops = arms.ctrl[side]!.map((c) => c[0]).toList();
        expect(ops, containsAllInOrder([SkCtrl.hello, SkCtrl.resetSession]));
      }
      expect(g1.batteryLeft, 80);
      expect(g1.firmwareVersion, 'ScouterKit g1v0 0.5.60');
      expect(g1.wearState, 'worn');
    });

    test('a text is drawn on both arms', () async {
      g1.fakeReady(epoch: arms.epoch);
      expect(await g1.sendText('Hallo Welt\nZweite Zeile'), isTrue);
      for (final side in G1Side.values) {
        expect(arms.ops[side], [
          SkOp.fill,
          SkOp.glyphs,
          SkOp.glyphs,
          SkOp.draw,
        ]);
        final text = arms.arenas[side]!.sublist(SkArena.text, SkArena.text + 5);
        final font = loadTestFont();
        expect(text, font.encode('Hallo'));
      }
    });

    test('pages use the whole panel, not Even\'s 5 lines', () async {
      expect(g1.displayLines, 11);
      expect(g1.displayColumns, 42);
      final text = List.generate(25, (i) => 'Zeile ${i + 1}').join('\n');
      final pages = await g1.layoutPages(text);
      expect(pages, hasLength(3));
      expect(pages.first.split('\n'), hasLength(11));
      expect(pages.last.split('\n'), ['Zeile 23', 'Zeile 24', 'Zeile 25']);
      // A higher text block leaves room for more lines.
      await g1.setDisplayHeight(0);
      expect(g1.displayLines, 14);
    });

    test('a notification shows its app icon beside the text', () async {
      g1.fakeReady(epoch: arms.epoch);
      expect(
        SkIcons.forApp('org.telegram.messenger', 'Telegram'),
        'Telegram_app',
      );
      expect(
        SkIcons.forApp('com.google.android.gm', 'Gmail'),
        'Generic_e-mail',
      );
      expect(SkIcons.forApp('io.github.poldion.even_g1_ha'), SkIcons.generic);
      expect(
        await g1.sendText('Telegram: Anna\nHallo!', icon: 'Telegram_app'),
        isTrue,
      );
      final icon = File('assets/scouter/icons/Telegram_app.4bpp')
          .readAsBytesSync();
      final at = SkIcons.slot('Telegram_app', SkArena.icons);
      for (final side in G1Side.values) {
        expect(
          arms.ops[side],
          containsAllInOrder([SkOp.fill, SkOp.blit, SkOp.draw]),
        );
        expect(arms.arenas[side]!.sublist(at, at + icon.length), icon);
      }
      // Uploaded once per session.
      final writes = arms.ops[G1Side.left]!.length;
      await g1.sendText('Telegram: Bob\nNa?', icon: 'Telegram_app');
      expect(
        arms.ops[G1Side.left]!.length - writes,
        5,
      ); // fill, blit, 2× glyphs, draw
      // Pages are laid out narrower beside the icon.
      final wide = await g1.layoutPages('x ' * 40);
      final narrow = await g1.layoutPages('x ' * 40, icon: 'Telegram_app');
      expect(
        narrow.first.split('\n').length,
        greaterThan(wide.first.split('\n').length),
      );
    });

    test('clock model: offset and error from PING rounds', () {
      final clock = SkClock();
      expect(clock.known, isFalse);
      // Sent at 1000, 200 µs each way, the arm 50 000 µs ahead.
      clock.add(sent: 1000, armRx: 51200, armTx: 51300, received: 1500);
      expect(clock.toArm(2000), 52000);
      expect(clock.errorUs, 200);
      // Across the wrap of the u32 clocks: the same time on both sides.
      clock.reset();
      clock.add(sent: 0xfffffff0, armRx: 0x10, armTx: 0x10, received: 0x30);
      expect(clock.toArm(0x100), 0x100);
      expect(clock.errorUs, 32);
    });

    test('both eyes draw a text at the same moment', () async {
      g1.fakeReady(epoch: arms.epoch);
      await g1.fakeSyncClocks();
      expect(await g1.sendText('Hallo'), isTrue);
      for (final side in G1Side.values) {
        expect(arms.ops[side]!.last, SkOp.draw);
        expect(arms.ops[side]!.reversed.skip(1).first, SkOp.sleepUntil);
      }
      // The same host moment in each arm's clock.
      final l = arms.sleeps[G1Side.left]!.last;
      final r = arms.sleeps[G1Side.right]!.last;
      final diff =
          arms.clockOffset[G1Side.right]! - arms.clockOffset[G1Side.left]!;
      expect(((r - l) & 0xffffffff) - diff, inInclusiveRange(-3000, 3000));
    });

    test('without a clock the text is drawn at once', () async {
      arms.answerPing = false;
      g1.fakeReady(epoch: arms.epoch);
      expect(await g1.sendText('Hallo'), isTrue);
      expect(arms.ops[G1Side.left], isNot(contains(SkOp.sleepUntil)));
    });

    test('nothing is drawn while an arm lies in the case', () async {
      g1.fakeReady(epoch: arms.epoch);
      g1.receive(G1Side.left, input(arms.epoch, SkTrigger.caseState, 0xff01));
      expect(await g1.sendText('Hallo'), isTrue);
      expect(arms.ops[G1Side.left], isEmpty);
      expect(arms.ops[G1Side.right], isNotEmpty);
      expect(g1.wearState, 'case_open');
    });

    test('clearing switches the panels off', () async {
      g1.fakeReady(epoch: arms.epoch);
      expect(await g1.blankScreen(), isTrue);
      // PANEL 0, then USER3: the program redraws the microphone's stand.
      expect(arms.ops[G1Side.left], [SkOp.sysWrite, SkOp.raise]);
    });

    test('touch gestures become the Even events', () async {
      g1.fakeReady(epoch: arms.epoch);
      final events = <int>[];
      final sub = g1.events.listen((e) => events.add(e.code));
      for (final g in [
        SkGesture.longStart,
        SkGesture.longEnd,
        SkGesture.tap,
        SkGesture.doubleTap,
        SkGesture.tripleTap,
        SkGesture.tripleTap,
      ]) {
        g1.receive(G1Side.right, input(arms.epoch, SkTrigger.touch, g));
      }
      await Future<void>.delayed(Duration.zero);
      // The left long press is Assist, the right one a gesture of its own.
      g1.receive(
        G1Side.left,
        input(arms.epoch, SkTrigger.touch, SkGesture.longStart),
      );
      g1.receive(
        G1Side.left,
        input(arms.epoch, SkTrigger.touch, SkGesture.longEnd),
      );
      await Future<void>.delayed(Duration.zero);
      expect(events, [
        G1Event.rightHoldStart,
        G1Event.rightHoldStop,
        G1Event.singleTap,
        G1Event.doubleTap,
        G1Event.silentModeOn,
        G1Event.silentModeOff,
        G1Event.longPressStart,
        G1Event.longPressStop,
      ]);
      expect(
        gestureName(G1Event.rightHoldStart, G1Side.right),
        'long_press_right',
      );
      await sub.cancel();
    });

    test('the resident program is loaded and reports the head', () async {
      g1.fakeReady(epoch: arms.epoch);
      final events = <int>[];
      final sub = g1.events.listen((e) => events.add(e.code));
      await g1.setDashboard(onHeadUp: true, text: '12:00\nWohnzimmer: 21 °C');
      for (final side in G1Side.values) {
        final arena = arms.arenas[side]!;
        final p = SkResident.build(
          gestures: false,
          micArm: side == G1Side.right,
        );
        expect(
          arena.sublist(SkResident.code, SkResident.code + p.code.length),
          p.code,
        );
        final d = ByteData.sublistView(arena);
        // 12 bands: the 9 empty lines below first, the label's place, then
        // the 2 texts.
        final bands = d.getUint32(SkResident.count.address, Endian.little);
        expect(bands, 12);
        expect(d.getUint32(SkResident.rows.address, Endian.little), bands);
        int entry(int i, int word) => d.getUint32(
          SkResident.lines + 4 * (SkResident.entryWords * i + word),
          Endian.little,
        );
        expect(
          [for (var i = 0; i < bands; i++) entry(i, 3) > 0],
          [...List.filled(10, false), true, true],
        );
        expect(entry(10, 1), 140); // y of the first line
        expect(d.getUint32(SkResident.angle.address, Endian.little), 30);
        expect(
          arms.ctrl[side]!.where((c) => c[0] == SkCtrl.vmStart),
          hasLength(1),
        );
      }
      expect(g1.showsDashboardItself, isTrue);
      // The right arm's program reports the head (NOTIFY 1, 1).
      g1.receive(
        G1Side.right,
        event(SkEvt.notify, arms.epoch, [
          ..._u16(1),
          0x03,
          ..._u32(SkResident.notifyHead),
          ..._u32(1),
        ]),
      );
      // A nod (with head gestures on).
      g1.receive(
        G1Side.right,
        event(SkEvt.notify, arms.epoch, [
          ..._u16(2),
          0x01,
          ..._u32(SkResident.notifyGesture),
          ..._u32(SkResident.nod),
        ]),
      );
      await Future<void>.delayed(Duration.zero);
      expect(events, [G1Event.headUp, G1Event.nod]);
      // A text marks the display busy for the program.
      await g1.sendText('Hallo');
      expect(
        ByteData.sublistView(arms.arenas[G1Side.left]!)
            .getUint32(SkResident.busy.address, Endian.little),
        1,
      );
      await g1.blankScreen();
      expect(
        ByteData.sublistView(arms.arenas[G1Side.left]!)
            .getUint32(SkResident.busy.address, Endian.little),
        0,
      );
      // New content while it runs: written and redrawn (USER0).
      arms.ops[G1Side.left]!.clear();
      await g1.setDashboard(onHeadUp: true, text: '12:01');
      expect(arms.ops[G1Side.left], contains(SkOp.raise));
      expect(
        ByteData.sublistView(arms.arenas[G1Side.left]!)
            .getUint32(SkResident.count.address, Endian.little),
        12, // one text band, ten empty ones, the label's place
      );
      // Off again: the program keeps running (clock, status line,
      // microphone) and only stops showing the dashboard.
      await g1.setDashboard(onHeadUp: false, text: '');
      expect(g1.showsDashboardItself, isFalse);
      expect(
        arms.ctrl[G1Side.left]!.where((c) => c[0] == SkCtrl.vmStop),
        isEmpty,
      );
      expect(
        ByteData.sublistView(arms.arenas[G1Side.left]!)
                .getUint32(SkResident.flags.address, Endian.little) &
            SkResident.flagDashboard,
        0,
      );
      await sub.cancel();
    });

    test('emojis go into the font slots of both arms', () async {
      g1.fakeReady(epoch: arms.epoch);
      await g1.sendText('Sonne \u2600\uFE0F und Herz \u2764\uFE0F');
      final font = loadTestFont();
      for (final side in G1Side.values) {
        final d = ByteData.sublistView(arms.arenas[side]!);
        // Slot 0 and 1: entries with a bitmap, 24 pixels wide.
        for (final k in [0, 1]) {
          final e = SkArena.font + 16 + 12 * (font.glyphCount + k);
          expect(d.getUint8(e + 4), greaterThan(0)); // width
          expect(d.getUint8(e + 6), SkEmoji.advance);
        }
      }
      // Sent again: nothing uploaded a second time.
      arms.ops[G1Side.left]!.clear();
      final before = arms.writes;
      await g1.sendText('\u2600');
      expect(arms.writes - before, lessThan(10));
    });

    test('head gestures load the detector on the right arm only', () async {
      g1.fakeReady(epoch: arms.epoch);
      await g1.setHeadGestures(true);
      final right = SkResident.build(gestures: true, micArm: true).code;
      expect(
        arms.arenas[G1Side.right]!.sublist(
          SkResident.code,
          SkResident.code + right.length,
        ),
        right,
      );
      expect(
        arms.ctrl[G1Side.left]!.where((c) => c[0] == SkCtrl.vmStart),
        isEmpty,
      );
    });

    test('brightness offset from the light sensor', () async {
      g1.fakeReady(epoch: arms.epoch);
      expect(ScouterConnection.stockLevel(10), 2);
      expect(ScouterConnection.stockLevel(120), 17);
      expect(ScouterConnection.stockLevel(500), 31);
      expect(ScouterConnection.stockLevel(5000), 42);
      await g1.setAutoBrightnessOffset(8);
      // The right arm now reports the light (EVENTS bit 4).
      final events = arms.ctrl[G1Side.right]!.lastWhere(
        (c) => c[0] == SkCtrl.events,
      );
      expect(events[2] & (1 << SkTrigger.light), isNot(0));
      for (final side in G1Side.values) {
        arms.ops[side]!.clear();
      }
      // 120 lx: stock's level 17, +8.
      g1.receive(G1Side.right, input(arms.epoch, SkTrigger.light, 12000));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(g1.brightnessPercent, G1Brightness.percent(25));
      expect(arms.ops[G1Side.left], contains(SkOp.sysWrite));
      // Manual brightness ends the offset mode.
      await g1.setBrightnessLevel(10, auto: false);
      final after = arms.ctrl[G1Side.right]!.lastWhere(
        (c) => c[0] == SkCtrl.events,
      );
      expect(after[2] & (1 << SkTrigger.light), 0);
    });

    test('head up and down from the pitch', () async {
      g1.fakeReady(epoch: arms.epoch);
      await g1.setHeadUpAngle(30);
      final events = <int>[];
      final sub = g1.events.listen((e) => events.add(e.code));
      g1.receive(G1Side.right, input(arms.epoch, SkTrigger.tilt, 35));
      g1.receive(G1Side.right, input(arms.epoch, SkTrigger.tilt, 25));
      g1.receive(G1Side.right, input(arms.epoch, SkTrigger.tilt, -5));
      await Future<void>.delayed(Duration.zero);
      expect(events, [G1Event.headUp, G1Event.headDown]);
      await sub.cancel();
    });

    test('microphone at 16 kbps, audio from the right arm', () async {
      g1.fakeReady(epoch: arms.epoch);
      final audio = <int>[];
      final sub = g1.audio.listen((a) => audio.add(a.length));
      expect(await g1.setMic(true), isTrue);
      final mic = arms.ctrl[G1Side.right]!.last;
      expect(mic.sublist(0, 1), [SkCtrl.mic]);
      expect(mic.sublist(2), [1, 1]);
      g1.receive(
        G1Side.right,
        event(SkEvt.micData, arms.epoch, [
          ..._u16(0),
          5,
          ...List.filled(100, 1),
        ]),
      );
      await Future<void>.delayed(Duration.zero);
      expect(audio, [100]);
      expect(await g1.setMic(false), isTrue);
      await sub.cancel();
    });

    test('a new epoch sets the arm up again', () async {
      await g1.fakeSetup();
      final before = arms.ctrl[G1Side.left]!.length;
      g1.receive(G1Side.left, ack(arms.epoch + 1, 0, 0));
      expect(g1.connected, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(arms.ctrl[G1Side.left]!.length, greaterThan(before));
    });
  });
}
