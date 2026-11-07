// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Even G1 für Home Assistant';

  @override
  String get glasses => 'Brille';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageSetting => 'Sprache';

  @override
  String languageSystem(String language) {
    return 'System ($language)';
  }

  @override
  String get settingsAppUpdate => 'App-Update';

  @override
  String get settingsAppUpdateSubtitle =>
      'Version und neue Versionen von GitHub';

  @override
  String get settingsDiagnostics => 'Diagnose';

  @override
  String get settingsDiagnosticsSubtitle =>
      'Testanzeige, Anzeige prüfen, Protokoll';

  @override
  String get settingsDisplay => 'Anzeige & Aktivierung';

  @override
  String get settingsDisplaySubtitle =>
      'Aktivierungswinkel, Höhe, Distanz, Even-Dashboard';

  @override
  String get settingsNoGlassesPaired => 'Noch keine Brille gekoppelt';

  @override
  String get settingsNotSetUp => 'Nicht eingerichtet';

  @override
  String get settingsNotifications => 'Benachrichtigungen';

  @override
  String get settingsNotificationsOff => 'Weiterleitung aus';

  @override
  String get settingsNotificationsOn =>
      'Handy-Benachrichtigungen werden weitergeleitet';

  @override
  String get settingsPairGlasses => 'Brille koppeln';

  @override
  String get settingsRecordings => 'Aufnahmen';

  @override
  String get settingsWhisperNotSetUp => 'WhisperNotes nicht eingerichtet';
}
