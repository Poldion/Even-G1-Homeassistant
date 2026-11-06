import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:even_g1_ha/g1/protocol.dart';
import 'package:even_g1_ha/scouter/scouter_connection.dart';
import 'package:even_g1_ha/scouter/sk_font.dart';
import 'package:even_g1_ha/scouter/sk_icons.dart';
import 'package:even_g1_ha/scouter/sk_link.dart';
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
/// other instructions are collected in [ops].
void execute(Uint8List code, Uint8List arena, List<int> ops) {
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
    } else {
      final k = switch (op) {
        SkOp.sysWrite => 2,
        SkOp.fill => 7,
        SkOp.blit => 12,
        SkOp.glyphs => 9,
        SkOp.draw => 8,
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
  int micStatus = 0;
  bool acks = true;

  Future<void> write(G1Side side, int channel, Uint8List data) async {
    if (channel == 0) {
      final seq = data[0] | data[1] << 8;
      execute(Uint8List.sublistView(data, 2), arenas[side]!, ops[side]!);
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
      _ => <int>[],
    };
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
      final font = loadTestFont().blob;
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
      await g1.setDisplayPosition(0, 5, 0);
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
      expect(arms.ops[G1Side.left], [SkOp.sysWrite]);
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
      expect(events, [
        G1Event.evenAiStart,
        G1Event.evenAiStop,
        G1Event.singleTap,
        G1Event.doubleTap,
        G1Event.silentModeOn,
        G1Event.silentModeOff,
      ]);
      await sub.cancel();
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
