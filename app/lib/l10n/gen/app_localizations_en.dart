// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Even G1 for Home Assistant';

  @override
  String get glasses => 'Glasses';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageSetting => 'Language';

  @override
  String languageSystem(String language) {
    return 'System ($language)';
  }

  @override
  String get settingsAppUpdate => 'App update';

  @override
  String get settingsAppUpdateSubtitle =>
      'Version and new versions from GitHub';

  @override
  String get settingsDiagnostics => 'Diagnostics';

  @override
  String get settingsDiagnosticsSubtitle => 'Test text, check display, log';

  @override
  String get settingsDisplay => 'Display & activation';

  @override
  String get settingsDisplaySubtitle =>
      'Activation angle, height, distance, Even dashboard';

  @override
  String get settingsNoGlassesPaired => 'No glasses paired yet';

  @override
  String get settingsNotSetUp => 'Not set up';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsNotificationsOff => 'Forwarding off';

  @override
  String get settingsNotificationsOn => 'Phone notifications are forwarded';

  @override
  String get settingsPairGlasses => 'Pair glasses';

  @override
  String get settingsRecordings => 'Recordings';

  @override
  String get settingsWhisperNotSetUp => 'WhisperNotes not set up';
}
