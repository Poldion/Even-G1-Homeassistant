// What the app and Home Assistant share about the glasses: the arms, the
// gesture codes the connection reports and the brightness scale.
//
// The glasses run ScouterKit's g1v0 firmware (lib/scouter); the codes below
// keep the numbering of Even's firmware so Home Assistant sees the same
// gestures as before.

enum G1Side {
  left('L'),
  right('R');

  const G1Side(this.code);
  final String code;
}

/// First byte of an event's data (as Even's 0xF5 events had it).
class G1Cmd {
  static const event = 0xF5;
}

/// Gesture codes. 0x00–0x18 are the numbers of Even's firmware, the others
/// this app's own.
class G1Event {
  static const doubleTap = 0x00;
  static const singleTap = 0x01;

  /// Head raised / lowered (the right arm decides).
  static const headUp = 0x02;
  static const headDown = 0x03;

  /// Triple tap: silent mode on / off.
  static const silentModeOn = 0x04;
  static const silentModeOff = 0x05;

  /// Left touch bar held / released (Assist).
  static const longPressStart = 0x17;
  static const longPressStop = 0x18;

  static const rightHoldStart = 0x70;
  static const rightHoldStop = 0x71;
  static const nod = 0x72;
  static const headShake = 0x73;
}

/// Gesture names as understood by the Home Assistant integration.
String? gestureName(int code, G1Side side) {
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
    case G1Event.longPressStart:
      return 'long_press';
    case G1Event.longPressStop:
      return 'long_press_release';
    case G1Event.rightHoldStart:
      return 'long_press_right';
    case G1Event.rightHoldStop:
      return 'long_press_right_release';
    case G1Event.nod:
      return 'nod';
    case G1Event.headShake:
      return 'head_shake';
    default:
      return 'other';
  }
}

/// The brightness scale of the panel (0–42).
class G1Brightness {
  static const max = 42;

  /// Brightness level (0–42) in percent.
  static int percent(int level) => (level.clamp(0, max) * 100 / max).round();

  /// Percent as a level (0–42).
  static int level(int percent) => (percent.clamp(0, 100) * max / 100).round();
}
