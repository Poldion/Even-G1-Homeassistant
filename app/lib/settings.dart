import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persistent app settings.
class Settings {
  Settings._(this._prefs);

  final SharedPreferences _prefs;

  static Future<Settings> load() async =>
      Settings._(await SharedPreferences.getInstance());

  String get haUrl => _prefs.getString('ha_url') ?? '';
  set haUrl(String v) => _prefs.setString('ha_url', v.trim());

  String get haToken => _prefs.getString('ha_token') ?? '';
  set haToken(String v) => _prefs.setString('ha_token', v.trim());

  /// Config entry id of the even_g1 integration entry.
  String get entryId => _prefs.getString('entry_id') ?? '';
  set entryId(String v) => _prefs.setString('entry_id', v);

  String get entryName => _prefs.getString('entry_name') ?? '';
  set entryName(String v) => _prefs.setString('entry_name', v);

  String get leftId => _prefs.getString('left_id') ?? '';
  set leftId(String v) => _prefs.setString('left_id', v);

  String get rightId => _prefs.getString('right_id') ?? '';
  set rightId(String v) => _prefs.setString('right_id', v);

  String get glassesName => _prefs.getString('glasses_name') ?? '';
  set glassesName(String v) => _prefs.setString('glasses_name', v);

  /// Forward phone notifications to the glasses.
  bool get forwardNotifications =>
      _prefs.getBool('forward_notifications') ?? true;
  set forwardNotifications(bool v) =>
      _prefs.setBool('forward_notifications', v);

  /// Apps that posted notifications: package -> {name, enabled}.
  Map<String, NotificationApp> get notificationApps {
    final raw = _prefs.getString('notification_apps');
    if (raw == null) return {};
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return json.map(
      (k, v) => MapEntry(
        k,
        NotificationApp(
          (v as Map)['name'] as String? ?? k,
          v['enabled'] as bool? ?? true,
        ),
      ),
    );
  }

  set notificationApps(Map<String, NotificationApp> apps) => _prefs.setString(
    'notification_apps',
    jsonEncode(
      apps.map((k, v) => MapEntry(k, {'name': v.name, 'enabled': v.enabled})),
    ),
  );

  // Glasses display settings. null = not set by this app (the glasses keep
  // what the Even app configured).
  int? _optInt(String key) {
    final v = _prefs.getInt(key);
    return v == null || v < 0 ? null : v;
  }

  void _setOptInt(String key, int? v) => _prefs.setInt(key, v ?? -1);

  /// Head up angle (0–60°) at which the glasses wake the display.
  int? get headUpAngle => _optInt('head_up_angle');
  set headUpAngle(int? v) => _setOptInt('head_up_angle', v);

  /// Height (0–8) of the display content.
  int? get displayHeight => _optInt('display_height');
  set displayHeight(int? v) => _setOptInt('display_height', v);

  /// Distance (1–9) of the display content.
  int? get displayDepth => _optInt('display_depth');
  set displayDepth(int? v) => _setOptInt('display_depth', v);

  /// What the glasses show on head up: 0 = Even dashboard, 2 = nothing.
  int? get headUpMode => _optInt('head_up_mode');
  set headUpMode(int? v) => _setOptInt('head_up_mode', v);

  /// Display brightness in percent.
  int? get brightness => _optInt('brightness');
  set brightness(int? v) => _setOptInt('brightness', v);

  /// Offset of the automatic brightness in percent (-50..50, 0 = off).
  int get brightnessOffset => _prefs.getInt('brightness_offset') ?? 0;
  set brightnessOffset(int v) => _prefs.setInt('brightness_offset', v);

  /// Automatic brightness of the glasses.
  bool? get autoBrightness => switch (_optInt('auto_brightness')) {
    null => null,
    final v => v == 1,
  };
  set autoBrightness(bool? v) =>
      _setOptInt('auto_brightness', v == null ? null : (v ? 1 : 0));

  /// WhisperNotes server for recordings, e.g. http://192.168.1.10:8000.
  String get whisperUrl => _prefs.getString('whisper_url') ?? '';
  set whisperUrl(String v) => _prefs.setString('whisper_url', v.trim());

  /// API key of WhisperNotes (empty if it is open in the home network).
  String get whisperApiKey => _prefs.getString('whisper_api_key') ?? '';
  set whisperApiKey(String v) => _prefs.setString('whisper_api_key', v.trim());

  /// Small dot on the glasses while recording.
  bool get recordingDot => _prefs.getBool('recording_dot') ?? true;
  set recordingDot(bool v) => _prefs.setBool('recording_dot', v);

  /// Experimental: Assist answers in the Even AI mode of the official app.
  bool get evenAiAnswers => _prefs.getBool('even_ai_answers') ?? false;
  set evenAiAnswers(bool v) => _prefs.setBool('even_ai_answers', v);

  /// Preview of the glasses display expanded on the overview.
  bool get showPreview => _prefs.getBool('show_preview') ?? false;
  set showPreview(bool v) => _prefs.setBool('show_preview', v);

  bool get haConfigured =>
      haUrl.isNotEmpty && haToken.isNotEmpty && entryId.isNotEmpty;

  bool get glassesConfigured => leftId.isNotEmpty && rightId.isNotEmpty;
}

class NotificationApp {
  NotificationApp(this.name, this.enabled);

  final String name;
  final bool enabled;
}
