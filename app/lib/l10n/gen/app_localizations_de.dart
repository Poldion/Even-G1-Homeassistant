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
  String get coreAssistNoAnswer => 'Keine Antwort';

  @override
  String coreAssistUnavailable(String error) {
    return 'Assist nicht verfügbar:\n$error';
  }

  @override
  String get coreCancelled => 'Abgebrochen';

  @override
  String get coreChannelDescription =>
      'Hält die Verbindung zur Brille im Hintergrund';

  @override
  String get coreChannelName => 'Even G1 Verbindung';

  @override
  String coreDisplayCheck(String left, String right) {
    return 'Anzeige links: $left, rechts: $right';
  }

  @override
  String coreDisplayCheckDiffers(String text) {
    return '$text – UNTERSCHIEDLICH';
  }

  @override
  String get coreDone => 'Erledigt.';

  @override
  String get coreGlassesNotConnected => 'Brille nicht verbunden';

  @override
  String coreHaConnected(String version) {
    return 'verbunden (HA $version)';
  }

  @override
  String get coreHaConnecting => 'verbinde…';

  @override
  String get coreHaConnectionLost => 'Verbindung zu Home Assistant verloren';

  @override
  String get coreHaDisconnected => 'getrennt';

  @override
  String get coreHaNotSetUp => 'nicht eingerichtet';

  @override
  String coreHaRetry(int seconds) {
    return 'getrennt, neuer Versuch in ${seconds}s';
  }

  @override
  String get coreHaTokenInvalid => 'Token ungültig';

  @override
  String coreListening(String assistant) {
    return '$assistant\nhört zu …';
  }

  @override
  String coreLogAnswer(String text) {
    return 'Antwort: $text';
  }

  @override
  String coreLogAssistError(String error) {
    return 'Assist-Fehler: $error';
  }

  @override
  String coreLogAssistStartFailed(String error) {
    return 'Assist-Start fehlgeschlagen: $error';
  }

  @override
  String get coreLogAssistStarted => 'Assist gestartet';

  @override
  String coreLogAudio(String error) {
    return 'Audio: $error';
  }

  @override
  String coreLogBrightness(int percent) {
    return 'Helligkeit: $percent %';
  }

  @override
  String get coreLogBrightnessAuto => 'Helligkeit: automatisch';

  @override
  String coreLogBrightnessOffset(String offset) {
    return 'Helligkeit: automatisch, $offset %';
  }

  @override
  String coreLogConfig(String name) {
    return 'Konfiguration erhalten ($name)';
  }

  @override
  String get coreLogDashboardTap => 'Dashboard (Tippen)';

  @override
  String get coreLogEvenAiOff => 'Antworten im Textmodus';

  @override
  String get coreLogEvenAiOn => 'Antworten im Even-AI-Modus';

  @override
  String get coreLogHeadGesturesOff => 'Kopfgesten aus';

  @override
  String get coreLogHeadGesturesOn => 'Kopfgesten an';

  @override
  String coreLogHeadUpAngle(int angle) {
    return 'Aktivierungswinkel: $angle°';
  }

  @override
  String get coreLogHeadUpHide => 'Hochschauen: Even-Dashboard ausblenden';

  @override
  String get coreLogHeadUpShow => 'Hochschauen: Even-Dashboard anzeigen';

  @override
  String get coreLogIntegrationReloaded =>
      'Integration neu geladen, verbinde neu';

  @override
  String get coreLogMicFailed => 'Mikrofon konnte nicht aktiviert werden';

  @override
  String coreLogNotification(String app, String title) {
    return 'Benachrichtigung: $app – $title';
  }

  @override
  String coreLogNotificationsError(String error) {
    return 'Benachrichtigungen: $error';
  }

  @override
  String coreLogPosition(int height, int depth) {
    return 'Anzeigeposition: Höhe $height, Distanz $depth';
  }

  @override
  String coreLogPositionPreview(int height, int depth) {
    return 'Anzeigeposition: Höhe $height, Distanz $depth (Vorschau)';
  }

  @override
  String coreLogRecognized(String text) {
    return 'Erkannt: $text';
  }

  @override
  String coreLogRecordingError(String error) {
    return 'Aufnahme: $error';
  }

  @override
  String get coreLogRecordingMicRestarted => 'Aufnahme: Mikrofon neu gestartet';

  @override
  String get coreLogRecordingNoGlasses =>
      'Aufnahme: Brille nicht verbunden, Mikrofon folgt';

  @override
  String coreLogRecordingNotSent(String error) {
    return 'Aufnahme nicht gesendet: $error';
  }

  @override
  String coreLogRecordingSent(String name) {
    return 'Aufnahme gesendet: $name';
  }

  @override
  String get coreLogRecordingStarted => 'Aufnahme gestartet';

  @override
  String coreLogRecordingStopped(String length, String duration) {
    return 'Aufnahme beendet: $length (Dauer $duration)';
  }

  @override
  String get coreLogRecordingTooShort => 'Aufnahme verworfen (zu kurz)';

  @override
  String coreLogShowText(String text) {
    return 'Anzeige: $text';
  }

  @override
  String get coreLogSilentDashboardSkipped =>
      'Ruhemodus – Dashboard nicht angezeigt';

  @override
  String get coreLogSilentNoGlasses => 'Ruhemodus: Brille nicht verbunden';

  @override
  String get coreLogSilentOff => 'Ruhemodus aus';

  @override
  String get coreLogSilentOffGlasses => 'Ruhemodus aus (Brille)';

  @override
  String get coreLogSilentOn => 'Ruhemodus an';

  @override
  String get coreLogSilentOnGlasses => 'Ruhemodus an (Brille)';

  @override
  String get coreLogSilentTextSkipped => 'Ruhemodus – Text nicht angezeigt';

  @override
  String get coreLogTextDropped => 'Brille nicht verbunden – Text verworfen';

  @override
  String get coreLogWearOff => 'Trageerkennung aus';

  @override
  String get coreLogWearOn => 'Trageerkennung an';

  @override
  String get coreNoAnswer => 'keine Antwort';

  @override
  String get coreNoHaConnection => 'Keine Verbindung zu Home Assistant';

  @override
  String get coreRecordingFileName => 'Brillen-Notiz';

  @override
  String get coreServiceText => 'Verbindung aktiv';

  @override
  String get coreSttFailed => 'Spracherkennung fehlgeschlagen.';

  @override
  String get coreSttMissing =>
      'Keine Spracherkennung in der Assist-Pipeline konfiguriert.';

  @override
  String get coreSttNothing => 'Ich habe nichts verstanden.';

  @override
  String get coreThinking => 'Home Assistant\nEinen Moment …';

  @override
  String get coreTimeout => 'Zeitüberschreitung';

  @override
  String coreTranscript(String text) {
    return '» $text «\nEinen Moment …';
  }

  @override
  String get coreUnknownError => 'Unbekannter Fehler';

  @override
  String coreWhisperFailed(String error) {
    return 'Senden fehlgeschlagen: $error';
  }

  @override
  String get coreWhisperNotSetUp => 'WhisperNotes ist nicht eingerichtet';

  @override
  String coreWhisperSent(String job) {
    return 'Gesendet an WhisperNotes (Job $job)';
  }

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
