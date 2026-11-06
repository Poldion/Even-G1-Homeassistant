import 'package:flutter/services.dart';

/// Notification icons for ScouterKit (g1v0): Pebble's notification icons,
/// 50 × 50 at 4 bpp, as converted by ScouterKit (assets/scouter/icons,
/// Apache License 2.0, see the NOTICE there).
class SkIcons {
  static const size = 50;
  static const stride = size ~/ 2;
  static const bytes = stride * size;
  static const generic = 'Generic_notification';

  /// Every bundled icon, in a fixed order (its slot in the arena).
  static const names = [
    'Alarm_clock',
    'Calendar',
    'Discord',
    'Element',
    'Facebook_messenger_notification',
    'Generic_SMS',
    'Generic_confirmation',
    'Generic_e-mail',
    'Generic_notification',
    'Generic_reminder',
    'Generic_warning',
    'Generic_weather',
    'Incoming_call',
    'Missed_call',
    'Music_event',
    'News_event',
    'Settings',
    'Signal',
    'Slack',
    'Steam',
    'Teams',
    'Telegram_app',
    'Viber',
    'WeChat',
    'WhatsApp_notification',
    'Zoom',
  ];

  /// Words of an Android package or app name that pick an icon, the first
  /// match wins (after ScouterKit's go/examples/g1/icons.go).
  static const _words = <(String, List<String>)>[
    ('Telegram_app', ['telegram']),
    ('WhatsApp_notification', ['whatsapp']),
    ('Signal', ['signal', 'securesms']),
    ('Discord', ['discord']),
    ('Element', ['element', 'vector', 'riot']),
    ('Slack', ['slack']),
    ('Teams', ['teams']),
    ('Zoom', ['zoom']),
    ('Steam', ['steam']),
    ('Viber', ['viber']),
    ('WeChat', ['wechat', 'mm']),
    ('Facebook_messenger_notification', ['messenger', 'orca']),
    ('Missed_call', ['missed']),
    ('Incoming_call', ['call', 'calls', 'phone', 'dialer', 'telecom']),
    ('Calendar', ['calendar', 'kalender', 'appointment']),
    ('Generic_reminder', ['reminder', 'reminders', 'todo', 'tasks', 'keep']),
    (
      'Generic_e-mail',
      [
        'mail',
        'email',
        'gm',
        'outlook',
        'thunderbird',
        'k9',
        'fairemail',
        'proton',
        'tutanota',
      ],
    ),
    ('Alarm_clock', ['alarm', 'deskclock', 'clock', 'timer']),
    (
      'Music_event',
      ['music', 'spotify', 'audio', 'podcast', 'podcasts', 'deezer', 'tidal'],
    ),
    ('Generic_weather', ['weather', 'wetter']),
    ('News_event', ['news', 'rss', 'feedly', 'reader']),
    (
      'Generic_SMS',
      [
        'sms',
        'mms',
        'messaging',
        'messages',
        'message',
        'chat',
        'im',
        'threema',
        'matrix',
      ],
    ),
    ('Settings', ['settings', 'update', 'vending', 'packageinstaller']),
    ('Generic_warning', ['warning', 'battery', 'security']),
  ];

  /// The icon for a notification of [package] / [appName]; the generic one
  /// when nothing matches.
  static String forApp(String package, [String appName = '']) {
    final words = '$package $appName'
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.isNotEmpty)
        .toSet();
    for (final (icon, keys) in _words) {
      if (keys.any(words.contains)) return icon;
    }
    return generic;
  }

  /// Arena address of [name]'s slot.
  static int slot(String name, int base) {
    final i = names.indexOf(name);
    return base + (i < 0 ? names.indexOf(generic) : i) * bytes;
  }

  static final Map<String, Future<Uint8List>> _cache = {};

  /// The bitmap of [name] (the generic one for an unknown name).
  static Future<Uint8List> load(String name) {
    final n = names.contains(name) ? name : generic;
    return _cache[n] ??= rootBundle
        .load('assets/scouter/icons/$n.4bpp')
        .then((d) => d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes));
  }
}
