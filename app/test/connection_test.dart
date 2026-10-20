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
    writes = [];
    blockers = {G1Side.left: null, G1Side.right: null};
    g1 = G1Connection.fake((side, data) async {
      writes.add((side, data));
      await blockers[side]?.future;
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
}
