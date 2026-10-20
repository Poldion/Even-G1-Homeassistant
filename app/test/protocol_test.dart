import 'dart:convert';

import 'package:even_g1_ha/g1/protocol.dart';
import 'package:even_g1_ha/g1/text_layout.dart';
import 'package:even_g1_ha/ha/ha_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses glasses names', () {
    final left = G1Name.parse('Even G1_45_L_92333')!;
    expect(left.channel, '45');
    expect(left.side, G1Side.left);
    expect(G1Name.parse('G1_7_R_1A2B')!.side, G1Side.right);
    expect(G1Name.parse('Some headphones'), isNull);
  });

  test('builds text packets like the official app', () {
    final packets = G1Packets.text(
      'Hallo',
      seq: 3,
      newScreen: 0x71,
      currentPage: 1,
      maxPage: 2,
    );
    expect(packets, hasLength(1));
    expect(packets.first.sublist(0, 9), [0x4E, 3, 1, 0, 0x71, 0, 0, 1, 2]);
    expect(utf8.decode(packets.first.sublist(9)), 'Hallo');

    final long = G1Packets.text(
      'x' * 400,
      seq: 0,
      newScreen: 0x31,
      currentPage: 1,
      maxPage: 1,
    );
    expect(long, hasLength(3));
    expect([for (final p in long) p[3]], [0, 1, 2]);
    expect([for (final p in long) p[2]], [3, 3, 3]);
    expect(long.map((p) => p.length - 9).reduce((a, b) => a + b), 400);
  });

  test('builds heartbeat and mic packets', () {
    expect(G1Packets.heartbeat(5), [0x25, 6, 0, 5, 4, 5]);
    expect(G1Packets.micEnable(true), [0x0E, 1]);
    expect(G1Packets.micEnable(false), [0x0E, 0]);
  });

  test('builds notification packets', () {
    final packets = G1Packets.notification(
      msgId: 7,
      appIdentifier: 'a',
      displayName: 'Home Assistant',
      title: 'T',
      message: 'M' * 300,
    );
    expect(packets.length, greaterThan(1));
    final json = jsonDecode(
      utf8.decode([for (final p in packets) ...p.sublist(4)]),
    );
    expect(json['ncs_notification']['message'], 'M' * 300);
    expect(packets.first.sublist(0, 4), [0x4B, 7, packets.length, 0]);
  });

  test('maps gestures', () {
    expect(gestureName(0x01, G1Side.left), 'single_tap_left');
    expect(gestureName(0x01, G1Side.right), 'single_tap_right');
    expect(gestureName(0x17, G1Side.left), 'long_press');
    expect(gestureName(0x42, G1Side.left), 'other');
    expect(gestureName(0x02, G1Side.right), 'head_up');
    expect(gestureName(0x03, G1Side.right), 'head_down');
    expect(gestureName(0x06, G1Side.left), 'case_removed');
    expect(gestureName(0x07, G1Side.left), 'case_removed');
    expect(gestureName(0x08, G1Side.left), 'case_opened');
    expect(gestureName(0x0B, G1Side.left), 'case_closed');
  });

  test('builds glasses setting packets (as MentraOS)', () {
    expect(G1Packets.headUpAngle(30), [0x0B, 30, 0x01]);
    expect(G1Packets.headUpAngle(90), [0x0B, 60, 0x01]);
    expect(G1Packets.dashboardPosition(3, 5, 7), [
      0x26, 0x08, 0x00, 7, 0x02, 0x01, 3, 5, //
    ]);
    expect(G1Packets.dashboardPosition(20, 0, 0).sublist(6), [8, 1]);
  });

  test('converts Home Assistant URLs', () {
    expect(
      HaClient.websocketUri('http://homeassistant.local:8123').toString(),
      'ws://homeassistant.local:8123/api/websocket',
    );
    expect(
      HaClient.websocketUri('https://ha.example.com/').toString(),
      'wss://ha.example.com/api/websocket',
    );
    expect(
      HaClient.websocketUri('192.168.1.2:8123').toString(),
      'ws://192.168.1.2:8123/api/websocket',
    );
  });

  testWidgets('splits long text into screens of 5 lines', (tester) async {
    final lines = G1TextLayout.lines(
      List.filled(40, 'Wohnzimmer Licht ist an').join(' '),
    );
    expect(lines.length, greaterThan(5));
    final screens = G1TextLayout.screens(lines);
    expect(screens.length, (lines.length / 5).ceil());
    expect('\n'.allMatches(screens.first).length, 5);

    final short = G1TextLayout.screens(G1TextLayout.lines('Kurz'));
    expect(short.single, '\n\nKurz\n');
  });
}
