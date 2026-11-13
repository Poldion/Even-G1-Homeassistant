import 'dart:async';

import 'package:flutter/foundation.dart';

import 'protocol.dart';

/// Placeholder for the time in the dashboard (Home Assistant sends it when
/// the app keeps the clock itself): the glasses' program or the app fill in
/// "HH:MM".
const clockToken = '';

/// [text] with the time [now] (default: the current one) for [clockToken].
String withClock(String text, [DateTime? now]) {
  if (!text.contains(clockToken)) return text;
  final t = now ?? DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return text.replaceAll(clockToken, '${two(t.hour)}:${two(t.minute)}');
}

/// How a text is set on the display.
enum G1TextStyle {
  /// Lines as they are.
  plain('plain'),

  /// A frame with bevelled corners around the lines.
  frame('frame'),

  /// Framed, the first line a centred title with a rule below it.
  card('card'),

  /// The first line a centred title with a rule below it, no frame.
  title('title'),

  /// Centred lines in a frame that fits them (Assist status).
  badge('badge'),

  /// Lab design set: corner brackets, the first line inverted on a bar
  /// with hazard stripes.
  lab('lab'),

  /// Lab design set for the Assist status: centred, the first line on a
  /// bar, corner brackets.
  labBadge('lab_badge'),

  /// Lab design set for Assist answers: a terminal window, the first line
  /// (the assistant) on a bar, a block cursor after the text.
  labTerminal('lab_terminal');

  const G1TextStyle(this.id);
  final String id;

  static G1TextStyle fromId(String? id) =>
      values.firstWhere((s) => s.id == id, orElse: () => plain);
}

/// A pair of arms found during a scan.
class G1Pair {
  G1Pair(this.channel);

  final String channel;
  String? leftId;
  String? rightId;
  String? leftName;
  String? rightName;

  bool get complete => leftId != null && rightId != null;
}

/// A gesture of the glasses.
class G1TouchEvent {
  G1TouchEvent(this.side, this.code, this.data);

  final G1Side side;
  final int code;
  final Uint8List data;
}

/// The glasses as the app sees them: both arms, their state, what they can
/// draw and do. The glasses run ScouterKit's g1v0 firmware
/// (ScouterConnection).
abstract class G1Connection extends ChangeNotifier {
  final _events = StreamController<G1TouchEvent>.broadcast();
  final _audio = StreamController<Uint8List>.broadcast();
  final _log = StreamController<String>.broadcast();

  int? batteryLeft;
  int? batteryRight;
  int? batteryCase;

  /// Brightness currently applied by the glasses in percent.
  int? brightnessPercent;
  bool? caseCharging;
  String? wearState;

  /// Gestures of the glasses.
  Stream<G1TouchEvent> get events => _events.stream;

  /// LC3 audio from the right arm's microphone.
  Stream<Uint8List> get audio => _audio.stream;

  /// Lines for the app's log.
  Stream<String> get log => _log.stream;

  @protected
  void emitEvent(G1TouchEvent event) => _events.add(event);

  /// LC3 audio, a multiple of 20 bytes.
  @protected
  void emitAudio(Uint8List lc3) => _audio.add(lc3);

  /// Writes a line to the app log (diagnostics).
  void note(String message) {
    debugPrint('[G1] $message');
    _log.add(message);
  }

  bool get connected;

  /// Connection state for the app.
  String get status;

  /// Name of the firmware, for the app.
  String get firmwareName;

  /// Firmware version of the arms; null while unknown.
  String? get firmwareVersion;

  /// Lines per page and characters per line of the display.
  int get displayLines;
  int get displayColumns;

  /// Splits [text] into the pages the display shows one at a time; with
  /// [icon] (a notification's app icon) beside the text.
  Future<List<String>> layoutPages(String text, {String? icon});

  Future<void> connect(String leftId, String rightId);
  Future<void> disconnect();
  Future<void> refreshBattery();

  /// Switches the microphone (right arm).
  Future<bool> setMic(bool enable);

  /// High connection priority while Assist runs, else balanced.
  Future<void> setFastConnection(bool fast);

  /// Shows one page of text on both eyes, with [icon] beside it and in
  /// [style].
  /// [serverOnline] non-null: [text] is the dashboard, shown with the
  /// connection symbols (the server struck through if false).
  Future<bool> sendText(
    String text, {
    String? icon,
    G1TextStyle style = G1TextStyle.plain,
    String? label,
    bool? serverOnline,
  });

  /// A small label shown with the dashboard (e.g. while a recording runs),
  /// null for none.
  Future<void> setDashboardLabel(String? label) async {}

  /// The arrow of the next turn while a navigation runs (50 × 50 pixels at
  /// 4 bpp), shown with the icon name `navigation`; null when it ended.
  void setNavigationIcon(Uint8List? icon) {}

  /// Switches the display off.
  Future<bool> blankScreen();

  /// The glasses show the Home Assistant dashboard on head up themselves
  /// (the program on the arms), so the app does not draw it.
  bool get showsDashboardItself;

  /// The dashboard to show on head up (kept in the arms).
  Future<void> setDashboard({
    required bool onHeadUp,
    required String text,
    G1TextStyle style = G1TextStyle.plain,
  });

  /// Whether the app reaches Home Assistant; the glasses' own dashboard
  /// shows a status line while it does not.
  Future<void> setHomeAssistantOnline(bool online);

  /// Plays the animation of silent mode switching [on] or off, with [lab]
  /// in the lab design set.
  Future<void> playSilentModeAnimation(bool on, {bool lab = false});

  /// Applies an offset to the automatic brightness (from the light sensor
  /// while the panel is on).
  Future<void> setAutoBrightnessOffset(int levels);

  /// Nodding and shaking the head as gestures.
  Future<void> setHeadGestures(bool enabled);

  /// Brightness in percent and auto mode, null if the glasses do not
  /// answer.
  Future<({int percent, bool auto})?> readBrightness();

  /// Brightness level (0–42) the glasses use now.
  Future<int?> readBrightnessLevel();
  Future<bool> setBrightness(int percent, {required bool auto});
  Future<bool> setBrightnessLevel(int level, {required bool auto});

  Future<bool?> readWearDetection();
  Future<bool> setWearDetection(bool enabled);
  Future<bool> setSilentMode(bool enabled);

  /// Pitch from which the head counts as raised, degrees.
  Future<bool> setHeadUpAngle(int angle);

  @override
  void dispose() {
    _events.close();
    _audio.close();
    _log.close();
    super.dispose();
  }
}
