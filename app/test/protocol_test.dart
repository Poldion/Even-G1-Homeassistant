import 'package:even_g1_ha/g1/protocol.dart';
import 'package:even_g1_ha/ha/ha_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps gestures', () {
    expect(gestureName(G1Event.singleTap, G1Side.left), 'single_tap_left');
    expect(gestureName(G1Event.singleTap, G1Side.right), 'single_tap_right');
    expect(gestureName(G1Event.longPressStart, G1Side.left), 'long_press');
    expect(
      gestureName(G1Event.longPressStop, G1Side.left),
      'long_press_release',
    );
    expect(gestureName(G1Event.headUp, G1Side.right), 'head_up');
    expect(gestureName(G1Event.headDown, G1Side.right), 'head_down');
    expect(gestureName(G1Event.silentModeOn, G1Side.left), 'triple_tap');
    expect(gestureName(G1Event.nod, G1Side.right), 'nod');
    expect(gestureName(0x42, G1Side.left), 'other');
  });

  test('converts brightness levels and percent', () {
    expect(G1Brightness.percent(42), 100);
    expect(G1Brightness.percent(21), 50);
    expect(G1Brightness.level(100), 42);
    expect(G1Brightness.level(-5), 0);
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
}
