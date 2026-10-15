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
  static const whitelist = 0x04;
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
/// The others are community findings and may differ between firmwares; every
/// event is forwarded to Home Assistant with its raw code anyway.
class G1Event {
  static const doubleTap = 0x00;
  static const singleTap = 0x01;
  static const headUp = 0x02;
  static const headDown = 0x03;
  static const silentModeOn = 0x04;
  static const silentModeOff = 0x05;
  static const worn = 0x06;
  static const removed = 0x07;
  static const evenAiStart = 0x17;
  static const evenAiStop = 0x18;
}

/// Gesture names as understood by the Home Assistant integration.
String gestureName(int code, G1Side side) {
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
    case G1Event.worn:
      return 'worn';
    case G1Event.removed:
      return 'removed';
    case G1Event.evenAiStart:
      return 'long_press';
    case G1Event.evenAiStop:
      return 'long_press_release';
    default:
      return 'other';
  }
}

class G1Packets {
  /// Maximum payload of one 0x4E packet.
  static const textChunk = 191;

  /// Maximum payload of one 0x4B packet.
  static const notificationChunk = 176;

  static Uint8List micEnable(bool enable) =>
      Uint8List.fromList([G1Cmd.mic, enable ? 1 : 0]);

  static Uint8List exit() => Uint8List.fromList([G1Cmd.exit]);

  static Uint8List init() => Uint8List.fromList([G1Cmd.init, 0x01]);

  static Uint8List battery() => Uint8List.fromList([G1Cmd.battery, 0x01]);

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

  /// Text / Even AI result (0x4E). Returns the packets for one screen.
  static List<Uint8List> text(
    String text, {
    required int seq,
    required int newScreen,
    required int currentPage,
    required int maxPage,
    int pos = 0,
  }) {
    final data = utf8.encode(text);
    final total = data.isEmpty ? 1 : (data.length / textChunk).ceil();
    return [
      for (var i = 0; i < total; i++)
        Uint8List.fromList([
          G1Cmd.text,
          seq & 0xff,
          total,
          i,
          newScreen,
          (pos >> 8) & 0xff,
          pos & 0xff,
          currentPage,
          maxPage,
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
