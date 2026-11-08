import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which builds the app updates to.
enum UpdateChannel {
  /// Releases (vX.Y.Z) from the main branch.
  stable('stable'),

  /// Pre-releases (sk-vX.Y.Z.N): every push to the main branch. The id and
  /// tag prefix date from when they were the ScouterKit builds.
  preview('scouterkit');

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
    this.heldBack = false,
  });

  final String version;
  final String apkUrl;
  final String notes;
  final UpdateChannel channel;

  /// The build comes from another channel than the installed app.
  final bool switchesChannel;

  /// Not offered: from [AppUpdater.scouterKitOnlyFrom] on the app supports
  /// only ScouterKit, and these glasses run Even's firmware.
  final bool heldBack;
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

  /// The first version without Even's firmware: glasses that run it stay on
  /// the last version before (the legacy branch is not developed further).
  static const scouterKitOnlyFrom = '0.25.0';

  /// The glasses run Even's firmware: stored by versions up to 0.24 that
  /// paired such glasses.
  static Future<bool> evenFirmware() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('glasses_firmware') == 'even';
  }

  /// [update] for glasses with Even's firmware: held back from
  /// [scouterKitOnlyFrom] on.
  static AppUpdate holdBackForEven(AppUpdate update, {required bool even}) {
    if (!even || isNewer(scouterKitOnlyFrom, update.version)) return update;
    return AppUpdate(
      version: update.version,
      apkUrl: update.apkUrl,
      notes: update.notes,
      channel: update.channel,
      switchesChannel: update.switchesChannel,
      heldBack: true,
    );
  }

  /// Tag prefix of the pre-releases.
  static const previewTagPrefix = 'sk-v';
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

  /// The channel a version belongs to: pre-releases have four parts
  /// ("0.17.0.12"), releases three.
  static UpdateChannel channelOf(String version) =>
      version.split('+').first.split('.').length > 3
      ? UpdateChannel.preview
      : UpdateChannel.stable;

  /// The channel chosen in the app (the installed build's until changed).
  static Future<UpdateChannel> channel() async {
    final prefs = await SharedPreferences.getInstance();
    return UpdateChannel.fromId(prefs.getString(_channelKey)) ??
        channelOf(supported ? await currentVersion() : '');
  }

  static Future<void> setChannel(UpdateChannel channel) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_channelKey, channel.id);
  }

  /// Reads an update from a GitHub release (JSON of the releases API).
  /// Stable: releases vX.Y.Z; preview: pre-releases sk-vX.Y.Z.N.
  /// [installed] is the channel of the installed build.
  static AppUpdate? parseRelease(
    Map<String, dynamic> release, {
    UpdateChannel channel = UpdateChannel.stable,
    UpdateChannel installed = UpdateChannel.stable,
  }) {
    final tag = release['tag_name'];
    if (tag is! String || release['draft'] == true) return null;
    final prerelease = release['prerelease'] == true;
    final String version;
    if (channel == UpdateChannel.stable) {
      if (prerelease || tag.startsWith(previewTagPrefix)) return null;
      version = tag.replaceFirst(RegExp(r'^v'), '');
    } else {
      if (!prerelease || !tag.startsWith(previewTagPrefix)) return null;
      version = tag.substring(previewTagPrefix.length);
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
          switchesChannel: channel != installed,
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
    final current = await currentVersion();
    final installed = channelOf(current);
    final stable = channel == UpdateChannel.stable;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(
        Uri.parse(stable ? _latestRelease : _releases),
      );
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, 'EvenG1HA');
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final json = jsonDecode(body);
      AppUpdate? update;
      if (json is Map<String, dynamic>) {
        update = parseRelease(json, channel: channel, installed: installed);
      } else if (json is List) {
        // Newest first.
        for (final r in json.whereType<Map<String, dynamic>>()) {
          update = parseRelease(r, channel: channel, installed: installed);
          if (update != null) break;
        }
      }
      if (update == null) return null;
      update = holdBackForEven(update, even: await evenFirmware());
      if (update.switchesChannel) return update;
      return isNewer(update.version, current) ? update : null;
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
