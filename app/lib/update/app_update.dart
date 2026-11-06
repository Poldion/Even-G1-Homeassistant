import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which builds the app updates to.
enum UpdateChannel {
  /// Releases (vX.Y.Z) from the legacy branch (Even's firmware).
  stable('stable'),

  /// Pre-releases (sk-vX.Y.Z.N) from the main branch, for glasses with
  /// the ScouterKit (g1v0) firmware.
  scouterKit('scouterkit');

  const UpdateChannel(this.id);
  final String id;

  static UpdateChannel? fromId(String? id) {
    for (final c in values) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// A newer release on GitHub.
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.apkUrl,
    required this.notes,
    this.channel = UpdateChannel.stable,
    this.switchesChannel = false,
  });

  final String version;
  final String apkUrl;
  final String notes;
  final UpdateChannel channel;

  /// The build comes from another channel than the installed app.
  final bool switchesChannel;
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
  static const _releases =
      'https://api.github.com/repos/Poldion/Even-G1-Homeassistant/releases?per_page=30';

  /// Channel of this build.
  static const buildChannel = UpdateChannel.scouterKit;

  /// Tag prefix of the ScouterKit pre-releases.
  static const scouterKitTagPrefix = 'sk-v';
  static const _channelKey = 'update_channel';
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

  /// The channel chosen in the app (this build's channel until changed).
  static Future<UpdateChannel> channel() async {
    final prefs = await SharedPreferences.getInstance();
    return UpdateChannel.fromId(prefs.getString(_channelKey)) ?? buildChannel;
  }

  static Future<void> setChannel(UpdateChannel channel) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_channelKey, channel.id);
  }

  /// Reads an update from a GitHub release (JSON of the releases API).
  /// Stable: releases vX.Y.Z; ScouterKit: pre-releases sk-vX.Y.Z.N.
  static AppUpdate? parseRelease(
    Map<String, dynamic> release, {
    UpdateChannel channel = UpdateChannel.stable,
  }) {
    final tag = release['tag_name'];
    if (tag is! String || release['draft'] == true) return null;
    final prerelease = release['prerelease'] == true;
    final String version;
    if (channel == UpdateChannel.stable) {
      if (prerelease || tag.startsWith(scouterKitTagPrefix)) return null;
      version = tag.replaceFirst(RegExp(r'^v'), '');
    } else {
      if (!prerelease || !tag.startsWith(scouterKitTagPrefix)) return null;
      version = tag.substring(scouterKitTagPrefix.length);
    }
    for (final asset in (release['assets'] as List? ?? const [])) {
      final name = asset['name'], url = asset['browser_download_url'];
      if (name is String &&
          url is String &&
          name.endsWith('.apk') &&
          url.startsWith(downloadPrefix)) {
        return AppUpdate(
          version: version,
          channel: channel,
          switchesChannel: channel != buildChannel,
          apkUrl: url,
          notes: (release['body'] as String? ?? '').split('\n---').first.trim(),
        );
      }
    }
    return null;
  }

  /// Returns the latest release of the chosen channel if it is newer than
  /// the installed app, or any if the installed app is from another channel.
  static Future<AppUpdate?> check() async {
    final channel = await AppUpdater.channel();
    final stable = channel == UpdateChannel.stable;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(
        Uri.parse(stable ? _latestRelease : _releases),
      );
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, 'EvenG1HA');
      final response = await request.close().timeout(const Duration(seconds: 15));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final json = jsonDecode(body);
      AppUpdate? update;
      if (json is Map<String, dynamic>) {
        update = parseRelease(json, channel: channel);
      } else if (json is List) {
        // Newest first.
        for (final r in json.whereType<Map<String, dynamic>>()) {
          update = parseRelease(r, channel: channel);
          if (update != null) break;
        }
      }
      if (update == null) return null;
      if (update.switchesChannel) return update;
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
