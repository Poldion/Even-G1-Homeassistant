import 'dart:async';
import 'dart:typed_data';

import 'package:even_g1_ha/g1/display.dart';
import 'package:even_g1_ha/g1/g1_connection.dart';
import 'package:even_g1_ha/g1/protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<(G1Side, List<int>)> writes;
  late Map<G1Side, Completer<void>?> blockers;
  late G1Connection g1;

  setUp(() {
    // Each connection gets its own list, so checks still running from an
    // earlier test do not end up in this one.
    final log = <(G1Side, List<int>)>[];
    final block = <G1Side, Completer<void>?>{
      G1Side.left: null,
      G1Side.right: null,
    };
    writes = log;
    blockers = block;
    g1 = G1Connection.fake((side, data) async {
      log.add((side, data));
      await block[side]?.future;
    });
  });

  test(
    'text goes to both arms without waiting for the glasses answer',
    () async {
      // Neither arm ever answers with 0xC9: the old implementation sent the
      // text to the left arm, waited for its answer and only then (maybe) to
      // the right arm.
      expect(await g1.sendText('Hallo'), isTrue);
      final sides = writes.where((w) => w.$2[0] == G1Cmd.text).map((w) => w.$1);
      expect(sides, containsAll([G1Side.left, G1Side.right]));
    },
  );

  test('packets keep their order on both arms', () async {
    // The right arm is slow (e.g. busy streaming the microphone).
    blockers[G1Side.right] = Completer<void>();
    final first = g1.sendText('A');
    final second = g1.sendText('B');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    // B must not reach the left arm before A reached the right arm.
    expect(writes.where((w) => w.$2[0] == G1Cmd.text), hasLength(2));
    blockers[G1Side.right]!.complete();
    await Future.wait([first, second]);

    String textOf(List<int> packet) => String.fromCharCodes(packet.sublist(9));
    for (final side in G1Side.values) {
      expect(
        writes.where((w) => w.$1 == side).map((w) => textOf(w.$2)).toList(),
        ['A', 'B'],
      );
    }
  });

  test('microphone command only goes to the right arm', () async {
    await g1.setMic(true);
    expect(writes.single.$1, G1Side.right);
    expect(writes.single.$2, [0x0E, 0x01]);
  });

  test('battery request waits for the answer of that arm', () async {
    final result = g1.request(G1Side.left, G1Packets.battery());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(writes.single.$1, G1Side.left);
    g1.receive(G1Side.left, Uint8List.fromList([0x2C, 0x66, 87]));
    expect((await result).data[2], 87);
  });

  test('reads the screen state of one arm (byte 5)', () async {
    final result = g1.readScreenState(G1Side.right);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(writes.single.$1, G1Side.right);
    expect(writes.single.$2, [0x39, 0x04, 0x00, 0x00]);
    g1.receive(
      G1Side.right,
      Uint8List.fromList([0x39, 0x04, 0x00, 0x00, 0x00, 0x10]),
    );
    expect(await result, 0x10);
  });

  test('assist screens and answers use the text mode on both arms', () async {
    final display = G1Display(g1);
    await display.showAiStatus('Home Assistant\nIch höre zu …');
    await display.showAiAnswer('Das Licht ist an.');
    final texts = writes.where((w) => w.$2[0] == G1Cmd.text).toList();
    expect(texts, hasLength(4));
    expect(texts.every((w) => w.$2[4] == 0x71), isTrue);
    expect(texts.where((w) => w.$1 == G1Side.left), hasLength(2));
    expect(texts.where((w) => w.$1 == G1Side.right), hasLength(2));
  });

  test('a text the left arm rejects or misses is sent to it again', () async {
    final log = <(G1Side, List<int>)>[];
    var leftReplies = [G1Status.failure, null, G1Status.success];
    late G1Connection glasses;
    glasses = G1Connection.fake((side, data) async {
      log.add((side, data));
      if (side == G1Side.left && data[0] == G1Cmd.text) {
        final status = leftReplies.removeAt(0);
        if (status != null) {
          scheduleMicrotask(
            () => glasses.receive(
              G1Side.left,
              Uint8List.fromList([G1Cmd.text, status, data[1]]),
            ),
          );
        }
      }
    })..leftAcks = null;
    expect(await glasses.sendText('Hallo'), isTrue);
    final texts = log.where((w) => w.$2[0] == G1Cmd.text).toList();
    // rejected, unanswered, accepted: three times to the left arm ...
    expect(texts.where((w) => w.$1 == G1Side.left), hasLength(3));
    // ... once to the right arm.
    expect(texts.where((w) => w.$1 == G1Side.right), hasLength(1));
    leftReplies = [];
  });

  test('a text missing on one arm is sent to that arm again', () async {
    final display = G1Display(g1);
    await display.showText('Dashboard');
    writes.clear();
    await Future<void>.delayed(
      G1Display.verifyDelay + const Duration(milliseconds: 20),
    );
    // Left arm still shows the Even dashboard (0x06) ...
    expect(writes.single.$1, G1Side.left);
    expect(writes.single.$2, [0x39, 0x04, 0x00, 0x00]);
    g1.receive(
      G1Side.left,
      Uint8List.fromList([0x39, 0x04, 0x00, 0x00, 0x00, 0x06]),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    // ... so the text is sent to the left arm only.
    final resend = writes.where((w) => w.$2[0] == G1Cmd.text).toList();
    expect(resend.single.$1, G1Side.left);
    // The right arm shows the text.
    g1.receive(
      G1Side.right,
      Uint8List.fromList([0x39, 0x04, 0x00, 0x00, 0x00, 0x10]),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(writes.where((w) => w.$2[0] == G1Cmd.text), hasLength(1));
    display.onDismissed();
  });

  test('clearing blanks the display, then releases the glasses', () async {
    final display = G1Display(g1)..verifyBothArms = false;
    await display.showText('Hallo');
    writes.clear();
    await display.clear();
    // Blank text right away ...
    expect(writes.any((w) => w.$2[0] == G1Cmd.exit), isFalse);
    expect(writes.where((w) => w.$2[0] == G1Cmd.text), hasLength(2));
    // ... and the exit command a moment later, so the next long press
    // starts Assist again.
    await Future<void>.delayed(
      G1Display.releaseDelay + const Duration(milliseconds: 50),
    );
    expect(writes.where((w) => w.$2[0] == G1Cmd.exit), hasLength(2));
  });

  test('a new text cancels the release of the glasses', () async {
    final display = G1Display(g1)..verifyBothArms = false;
    await display.showText('Hallo');
    await display.clear();
    await display.showText('Neu');
    writes.clear();
    await Future<void>.delayed(
      G1Display.releaseDelay + const Duration(milliseconds: 50),
    );
    expect(writes.any((w) => w.$2[0] == G1Cmd.exit), isFalse);
    display.onDismissed();
  });

  test('optional Even AI mode uses 0x31 and pages', () async {
    final display = G1Display(g1)..evenAiAnswers = true;
    await display.showAiAnswer('Licht im Wohnzimmer ist an.');
    final texts = writes.where((w) => w.$2[0] == G1Cmd.text).toList();
    expect(texts, hasLength(2)); // both arms
    expect(texts.every((w) => w.$2[4] == 0x31), isTrue);
    expect(texts.first.$2.sublist(7, 9), [1, 1]); // page 1 of 1
    display.onDismissed();
  });
}
