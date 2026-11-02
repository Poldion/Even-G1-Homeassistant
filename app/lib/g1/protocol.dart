// Even Realities G1 BLE protocol.
//
// Based on the official demo app (github.com/even-realities/EvenDemoApp).
// Each temple ("arm") of the glasses is its own BLE peripheral exposing a
// Nordic UART service. Unless stated otherwise, commands are sent to the
// left arm first and to the right arm after the left one acknowledged.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum G1Side {
  left('L'),
  right('R');

  const G1Side(this.code);
  final String code;
}

class G1Uuids {
  static final service = Guid('6E400001-B5A3-F393-E0A9-E50E24DCCA9E');

  /// Phone -> glasses.
  static final tx = Guid('6E400002-B5A3-F393-E0A9-E50E24DCCA9E');

  /// Glasses -> phone (notify).
  static final rx = Guid('6E400003-B5A3-F393-E0A9-E50E24DCCA9E');
}

class G1Cmd {
  static const brightness = 0x01;
  static const brightnessQuery = 0x29;
  static const silentMode = 0x03;
  static const whitelist = 0x04;
  static const headUpMode = 0x08;
  static const screenState = 0x39;
  static const headUpAngle = 0x0B;
  static const dashboardPosition = 0x26;
  static const mic = 0x0E;
  static const exit = 0x18;
  static const heartbeat = 0x25;
  static const battery = 0x2C;
  static const notification = 0x4B;
  static const text = 0x4E;
  static const micData = 0xF1;
  static const init = 0xF4;
  static const event = 0xF5;
}

class G1Status {
  static const success = 0xC9;
  static const failure = 0xCA;
  static const continueing = 0xCB;
}

/// Upper nibble of the "newscreen" byte of the 0x4E command.
class G1ScreenStatus {
  static const newContent = 0x01;
  static const aiDisplaying = 0x30;
  static const aiComplete = 0x40;
  static const aiManual = 0x50;
  static const aiNetworkError = 0x60;
  static const textShow = 0x70;
}

/// Sub commands of the 0xF5 event sent by the glasses.
///
/// 0x00, 0x01, 0x04/0x05, 0x17 and 0x18 are documented by Even Realities.
/// The others are community findings (as used by MentraOS) and may differ
/// between firmwares; every event is forwarded to Home Assistant with its raw
/// code anyway.
class G1Event {
  static const doubleTap = 0x00;
  static const singleTap = 0x01;

  /// Head raised / lowered. Both arms may report it, only the right one is
  /// used.
  static const headUp = 0x02;
  static const headDown = 0x03;
  static const silentModeOn = 0x04;
  static const silentModeOff = 0x05;
  static const evenAiStart = 0x17;
  static const evenAiStop = 0x18;

  // Status pushes (even-g1-companion HCI captures, firmware 1.6.6). They
  // repeat every few seconds and are not gestures.
  static const worn = 0x06;
  static const notWorn = 0x07;
  static const inCaseOpen = 0x08;
  static const caseCable = 0x09;
  static const glassesBattery = 0x0A; // byte 2: 0..100
  static const inCaseClosed = 0x0B;
  static const caseCharging = 0x0E; // byte 2: 0/1
  static const caseBattery = 0x0F; // byte 2: 0..100
  static const status10 = 0x10;
  static const connected = 0x11;
  static const brightness = 0x12;

  static const statusEvents = {
    worn,
    notWorn,
    inCaseOpen,
    caseCable,
    glassesBattery,
    inCaseClosed,
    caseCharging,
    caseBattery,
    status10,
    connected,
    brightness,
  };
}

/// Screen ids reported by 0x39 (firmware `ui_task_handler`, documented by
/// the even-g1-companion project).
String screenName(int id) => switch (id) {
  0x00 => 'idle',
  0x01 => 'wait',
  0x04 || 0x05 => 'notification',
  0x06 => 'Even dashboard',
  0x07 => 'bitmap',
  0x09 => 'teleprompter',
  0x0a => 'navigation',
  0x0b => 'translate',
  0x0c => 'QuickNote',
  0x10 => 'Even AI / text',
  0x14 => 'Even AI v2',
  _ => '0x${id.toRadixString(16)}',
};

/// Gesture names as understood by the Home Assistant integration, null for
/// status pushes.
String? gestureName(int code, G1Side side) {
  if (G1Event.statusEvents.contains(code)) return null;
  switch (code) {
    case G1Event.doubleTap:
      return 'double_tap';
    case G1Event.singleTap:
      return side == G1Side.left ? 'single_tap_left' : 'single_tap_right';
    case G1Event.headUp:
      return 'head_up';
    case G1Event.headDown:
      return 'head_down';
    case G1Event.silentModeOn:
    case G1Event.silentModeOff:
      return 'triple_tap';
    case G1Event.evenAiStart:
      return 'long_press';
    case G1Event.evenAiStop:
      return 'long_press_release';
    default:
      return 'other';
  }
}

/// Where the glasses are, from the 0x06/0x07/0x08/0x0B status pushes.
String? wearStateName(int code) => switch (code) {
  G1Event.worn => 'worn',
  G1Event.notWorn => 'not_worn',
  G1Event.inCaseOpen => 'case_open',
  G1Event.inCaseClosed => 'case_closed',
  _ => null,
};

class G1Packets {
  /// Maximum payload of one 0x4E packet.
  static const textChunk = 176;

  /// Maximum payload of one 0x4B packet.
  static const notificationChunk = 176;

  static Uint8List micEnable(bool enable) =>
      Uint8List.fromList([G1Cmd.mic, enable ? 1 : 0]);

  static Uint8List exit() => Uint8List.fromList([G1Cmd.exit]);

  static Uint8List init() => Uint8List.fromList([G1Cmd.init, 0x01]);

  /// Start command sent by MentraOS and Gadgetbridge after connecting.
  static Uint8List initDisplay() => Uint8List.fromList([0x4D, 0xFB]);

  static Uint8List battery() => Uint8List.fromList([G1Cmd.battery, 0x01]);

  /// Highest brightness level (0x2A, confirmed by even-g1-companion on
  /// firmware 1.6.6; MentraOS assumes 63).
  static const maxBrightness = 42;

  /// Display brightness in percent (sent as 0–42) and the automatic
  /// brightness of the glasses (light sensor in the right arm).
  static Uint8List brightness(int percent, {required bool auto}) =>
      Uint8List.fromList([
        G1Cmd.brightness,
        (percent.clamp(0, 100) * maxBrightness / 100).round(),
        auto ? 0x01 : 0x00,
      ]);

  /// Brightness as raw level (0–42).
  static Uint8List brightnessLevel(int level, {required bool auto}) =>
      Uint8List.fromList([
        G1Cmd.brightness,
        level.clamp(0, maxBrightness),
        auto ? 0x01 : 0x00,
      ]);

  /// Brightness level of the glasses (0–42) in percent.
  static int brightnessPercent(int level) =>
      (level.clamp(0, maxBrightness) * 100 / maxBrightness).round();

  /// Reads brightness and auto mode (right arm): [0x29, 0x65, level, auto].
  static Uint8List brightnessQuery() =>
      Uint8List.fromList([G1Cmd.brightnessQuery]);

  /// Silent mode on/off (as in the eveng1 Python SDK and MentraOS).
  static Uint8List silentMode(bool enabled) =>
      Uint8List.fromList([G1Cmd.silentMode, enabled ? 0x0C : 0x0A, 0x00]);

  /// What the glasses show when the head is raised (persisted on the
  /// glasses): 0x00 = Even dashboard, 0x02 = nothing (the head up/down
  /// events are still sent). Source: even-g1-companion settings capture.
  static Uint8List headUpMode(int value) => Uint8List.fromList([
    G1Cmd.headUpMode,
    0x06,
    0x00,
    0x00,
    0x03,
    value & 0xff,
  ]);

  /// Asks one arm which screen it shows (0x39). The answer's byte 5 is the
  /// screen id, see [screenName].
  static Uint8List screenState() =>
      Uint8List.fromList([G1Cmd.screenState, 0x04, 0x00, 0x00]);

  /// Angle (0–60°) at which raising the head shows the dashboard.
  static Uint8List headUpAngle(int angle) =>
      Uint8List.fromList([G1Cmd.headUpAngle, angle.clamp(0, 60), 0x01]);

  /// Height (0–8) and depth (1–9) of the display content.
  ///
  /// With [preview] the glasses open their own position preview screen
  /// (state 0x01); state 0x00 closes it and applies the position. The
  /// official app sends 0x00 (even-g1-companion capture
  /// `26 08 00 00 02 00 07 03`); the firmware recomputes the canvas origin of
  /// every screen from these values (g1-reverse `cal_panel_canvas_coord`).
  static Uint8List dashboardPosition(
    int height,
    int depth,
    int counter, {
    bool preview = false,
  }) => Uint8List.fromList([
    G1Cmd.dashboardPosition,
    0x08,
    0x00,
    counter & 0xff,
    0x02,
    preview ? 0x01 : 0x00,
    height.clamp(0, 8),
    depth.clamp(1, 9),
  ]);

  static Uint8List heartbeat(int seq) {
    const length = 6;
    return Uint8List.fromList([
      G1Cmd.heartbeat,
      length & 0xff,
      (length >> 8) & 0xff,
      seq & 0xff,
      0x04,
      seq & 0xff,
    ]);
  }

  /// One screen of text (0x4E) in plain text mode (0x71 = new content +
  /// text show), like MentraOS. The Even AI modes (0x30–0x60) are not used:
  /// they interfere with the Even AI screens of the firmware and made the two
  /// arms show different content. Paging is done by the app.
  ///
  /// [status] can be set to an Even AI status (0x31 displaying, 0x41
  /// complete) to show Assist answers the way the official app does.
  static List<Uint8List> text(
    String text, {
    required int seq,
    int status = G1ScreenStatus.textShow | G1ScreenStatus.newContent,
    int page = 0,
    int pages = 1,
  }) {
    final data = utf8.encode(text.trim().isEmpty ? ' ' : text);
    final total = (data.length / textChunk).ceil();
    return [
      for (var i = 0; i < total; i++)
        Uint8List.fromList([
          G1Cmd.text,
          seq & 0xff,
          total,
          i,
          status,
          0x00, // new_char_pos0
          0x00, // new_char_pos1
          page, // current page (0: paging is done by the app)
          pages, // max page
          ...data.sublist(
            i * textChunk,
            ((i + 1) * textChunk).clamp(0, data.length),
          ),
        ]),
    ];
  }

  /// Regular phone notification (0x4B), sent to the left arm only.
  static List<Uint8List> notification({
    required int msgId,
    required String appIdentifier,
    required String displayName,
    required String title,
    required String message,
    String subtitle = '',
  }) {
    final json = jsonEncode({
      'ncs_notification': {
        'msg_id': msgId,
        'app_identifier': appIdentifier,
        'title': title,
        'subtitle': subtitle,
        'message': message,
        'time_s': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'display_name': displayName,
      },
    });
    return _chunked(
      utf8.encode(json),
      notificationChunk,
      (total, i) => [G1Cmd.notification, msgId & 0xff, total, i],
    );
  }

  /// App whitelist for notifications (0x04), sent to the left arm only.
  static List<Uint8List> whitelist(Map<String, String> apps) {
    final json = jsonEncode({
      'calendar_enable': false,
      'call_enable': false,
      'msg_enable': false,
      'ios_mail_enable': false,
      'app': {
        'list': [
          for (final e in apps.entries) {'id': e.key, 'name': e.value},
        ],
        'enable': true,
      },
    });
    return _chunked(
      utf8.encode(json),
      177,
      (total, i) => [G1Cmd.whitelist, total, i],
    );
  }

  static List<Uint8List> _chunked(
    List<int> data,
    int size,
    List<int> Function(int total, int index) header,
  ) {
    final total = (data.length / size).ceil();
    return [
      for (var i = 0; i < total; i++)
        Uint8List.fromList([
          ...header(total, i),
          ...data.sublist(i * size, ((i + 1) * size).clamp(0, data.length)),
        ]),
    ];
  }
}

/// Parsed glasses name, e.g. "Even G1_45_L_92333".
class G1Name {
  G1Name(this.channel, this.side);

  final String channel;
  final G1Side side;

  static final _pattern = RegExp(r'G\d+_(\d+)_([LR])_');

  static G1Name? parse(String name) {
    final match = _pattern.firstMatch(name);
    if (match == null) return null;
    return G1Name(
      match.group(1)!,
      match.group(2) == 'L' ? G1Side.left : G1Side.right,
    );
  }
}
