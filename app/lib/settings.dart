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

  bool get haConfigured =>
      haUrl.isNotEmpty && haToken.isNotEmpty && entryId.isNotEmpty;

  bool get glassesConfigured => leftId.isNotEmpty && rightId.isNotEmpty;
}
