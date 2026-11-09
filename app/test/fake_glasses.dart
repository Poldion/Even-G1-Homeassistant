import 'dart:typed_data';

import 'package:even_g1_ha/g1/g1_connection.dart';
import 'package:even_g1_ha/g1/protocol.dart';

/// Glasses for widget and unit tests: always answer, draw nothing, record
/// the texts sent.
class FakeGlasses extends G1Connection {
  FakeGlasses({this.isConnected = true});

  bool isConnected;
  final texts = <String>[];
  bool? mic;

  /// A gesture as if it came from the glasses.
  void gesture(G1Side side, int code) =>
      emitEvent(G1TouchEvent(side, code, Uint8List.fromList([0xF5, code])));

  @override
  bool get connected => isConnected;
  @override
  String get status => isConnected ? 'connected' : 'disconnected';
  @override
  String get firmwareName => 'ScouterKit (g1v0)';
  @override
  String? get firmwareVersion => null;
  @override
  int get displayLines => 11;
  @override
  int get displayColumns => 42;
  @override
  bool get showsDashboardItself => false;

  @override
  Future<List<String>> layoutPages(String text, {String? icon}) async {
    final lines = text.split('\n');
    return [
      for (var i = 0; i < lines.length; i += displayLines)
        lines.skip(i).take(displayLines).join('\n'),
    ];
  }

  @override
  Future<void> connect(String leftId, String rightId) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> refreshBattery() async {}
  @override
  Future<bool> setMic(bool enable) async {
    mic = enable;
    return true;
  }

  @override
  Future<void> setFastConnection(bool fast) async {}
  @override
  Future<bool> sendText(
    String text, {
    String? icon,
    G1TextStyle style = G1TextStyle.plain,
    String? label,
  }) async {
    texts.add(text);
    return true;
  }

  @override
  Future<bool> blankScreen() async => true;
  @override
  Future<void> setDashboard({
    required bool onHeadUp,
    required String text,
    G1TextStyle style = G1TextStyle.plain,
  }) async {}
  @override
  Future<void> setHomeAssistantOnline(bool online) async {}
  @override
  Future<void> playSilentModeAnimation(bool on, {bool lab = false}) async {}
  @override
  Future<void> setAutoBrightnessOffset(int levels) async {}
  @override
  Future<void> setHeadGestures(bool enabled) async {}
  @override
  Future<({int percent, bool auto})?> readBrightness() async => null;
  @override
  Future<int?> readBrightnessLevel() async => null;
  @override
  Future<bool> setBrightness(int percent, {required bool auto}) async => true;
  @override
  Future<bool> setBrightnessLevel(int level, {required bool auto}) async =>
      true;
  @override
  Future<bool?> readWearDetection() async => true;
  @override
  Future<bool> setWearDetection(bool enabled) async => true;
  @override
  Future<bool> setSilentMode(bool enabled) async => true;
  @override
  Future<bool> setHeadUpAngle(int angle) async => true;
  @override
  Future<bool> setDisplayHeight(int height) async => true;
}
