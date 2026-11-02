import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A newer release on GitHub.
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.apkUrl,
    required this.notes,
  });

  final String version;
  final String apkUrl;
  final String notes;
}

/// Looks for newer releases on GitHub and installs them (Android).
///
/// Same approach as the BasaltNotes app: the release API is checked at most
/// once a day on start or on request, the APK is downloaded with the Android
/// DownloadManager and handed to the system installer. Android only accepts
/// it as an update if it is signed with the same key.
class AppUpdater {
  static const _latestRelease =
      'https://api.github.com/repos/Poldion/Even-G1-Homeassistant/releases/latest';
  static const downloadPrefix =
      'https://github.com/Poldion/Even-G1-Homeassistant/releases/download/';
  static const _channel = MethodChannel('even_g1/updater');
  static const _lastCheckKey = 'update_last_check';
  static const checkInterval = Duration(days: 1);

  static bool get supported => Platform.isAndroid;

  /// Version of the installed app, e.g. "0.9.0".
  static Future<String> currentVersion() async =>
      await _channel.invokeMethod<String>('version') ?? '';

  /// True if [candidate] is a higher version than [current] ("1.10.0" > "1.9.2").
  static bool isNewer(String candidate, String current) {
    List<int> parts(String v) => v
        .replaceFirst(RegExp(r'^v'), '')
        .split('+')
        .first
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
    final a = parts(candidate), b = parts(current);
    for (var i = 0; i < (a.length > b.length ? a.length : b.length); i++) {
      final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  /// Reads an update from a GitHub release (JSON of the releases API).
  static AppUpdate? parseRelease(Map<String, dynamic> release) {
    final tag = release['tag_name'];
    if (tag is! String || release['draft'] == true || release['prerelease'] == true) {
      return null;
    }
    for (final asset in (release['assets'] as List? ?? const [])) {
      final name = asset['name'], url = asset['browser_download_url'];
      if (name is String &&
          url is String &&
          name.endsWith('.apk') &&
          url.startsWith(downloadPrefix)) {
        return AppUpdate(
          version: tag.replaceFirst(RegExp(r'^v'), ''),
          apkUrl: url,
          notes: (release['body'] as String? ?? '').split('\n---').first.trim(),
        );
      }
    }
    return null;
  }

  /// Returns the latest release if it is newer than the installed app.
  static Future<AppUpdate?> check() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(Uri.parse(_latestRelease));
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, 'EvenG1HA');
      final response = await request.close().timeout(const Duration(seconds: 15));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final update = parseRelease(jsonDecode(body) as Map<String, dynamic>);
      if (update == null) return null;
      return isNewer(update.version, await currentVersion()) ? update : null;
    } finally {
      client.close();
    }
  }

  /// True if the daily check is due (and records it).
  static Future<bool> dailyCheckDue() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = prefs.getInt(_lastCheckKey) ?? 0;
    if (now - last < checkInterval.inMilliseconds) return false;
    await prefs.setInt(_lastCheckKey, now);
    return true;
  }

  /// Downloads the APK and opens the installer when done.
  static Future<bool> install(AppUpdate update) async =>
      await _channel.invokeMethod<bool>('install', {'url': update.apkUrl}) ??
      false;
}
