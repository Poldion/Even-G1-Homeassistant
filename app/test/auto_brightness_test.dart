import 'dart:async';
import 'dart:typed_data';

import 'package:even_g1_ha/g1/auto_brightness.dart';
import 'package:even_g1_ha/g1/g1_connection.dart';
import 'package:even_g1_ha/g1/protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('measures the sensor level in auto mode and adds the offset', () async {
    final writes = <List<int>>[];
    late G1Connection g1;
    g1 = G1Connection.fake((side, data) async {
      if (side != G1Side.right) return;
      writes.add(data);
      if (data[0] == G1Cmd.brightnessQuery) {
        // The light sensor of the glasses chose level 10.
        scheduleMicrotask(
          () => g1.receive(
            G1Side.right,
            Uint8List.fromList([0x29, 0x65, 10, 0x01]),
          ),
        );
      }
    });
    var idle = true;
    final auto = AutoBrightness(g1, idle: () => idle, log: (_) {})
      ..readInterval = const Duration(milliseconds: 10);

    auto.start(8);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final settings = writes.where((w) => w[0] == G1Cmd.brightness).toList();
    expect(settings.first, [0x01, 21, 0x01]); // measure in auto mode
    expect(settings.last, [0x01, 18, 0x00]); // sensor 10 + offset 8, manual
    expect(auto.sensorLevel, 10);

    // A new offset is applied right away from the known sensor level.
    writes.clear();
    auto.start(-4);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(writes.where((w) => w[0] == G1Cmd.brightness).single, [
      0x01,
      6,
      0x00,
    ]);

    // While something is shown, nothing is measured.
    idle = false;
    auto.restart();
    writes.clear();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(writes, isEmpty);
    auto.stop();
  });
}
