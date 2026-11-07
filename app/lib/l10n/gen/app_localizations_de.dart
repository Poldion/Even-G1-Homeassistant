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
  String get diagCheckDisplay => 'Anzeige links/rechts prüfen';

  @override
  String get diagClose => 'Schließen';

  @override
  String get diagEvenAi => 'Assist-Antworten im Even-AI-Modus (Test)';

  @override
  String get diagEvenAiSubtitle =>
      'Zeigt Antworten wie die offizielle Even-App an. Ausprobieren, falls ein Auge etwas anderes zeigt als das andere.';

  @override
  String get diagLog => 'Protokoll';

  @override
  String get diagShowOnGlasses => 'Auf Brille anzeigen';

  @override
  String get diagTestText => 'Testtext';

  @override
  String get diagTestTextDefault => 'Hallo von Home Assistant!';

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

  @override
  String uiAnswer(String text) {
    return 'Antwort: $text';
  }

  @override
  String get uiAssistHint =>
      'Linke Touchbar gedrückt halten, sprechen, loslassen.';

  @override
  String uiAssistant(String name) {
    return 'Assistent: $name';
  }

  @override
  String get uiBatteryCase => 'Case';

  @override
  String get uiBatteryLeft => 'Links';

  @override
  String get uiBatteryRight => 'Rechts';

  @override
  String get uiBrightness => 'Helligkeit';

  @override
  String get uiBrightnessAutoHint =>
      'Die Brille regelt die Helligkeit über ihren Lichtsensor. Der Regler verschiebt sie heller oder dunkler.';

  @override
  String uiBrightnessNow(int percent) {
    return ' (gerade $percent %)';
  }

  @override
  String uiBrightnessOffsetEven(String offset, String current) {
    return 'Die App misst etwa alle zwei Minuten, wenn nichts angezeigt wird, den Wert des Lichtsensors und stellt ihn $offset % ein$current.';
  }

  @override
  String uiBrightnessOffsetScouter(String offset, String current) {
    return 'Der Lichtsensor meldet sich, sobald sich die Helligkeit deutlich ändert, solange etwas angezeigt wird; die App stellt dann $offset % gegenüber der Automatik ein$current.';
  }

  @override
  String get uiConnect => 'Verbinden';

  @override
  String uiFirmware(String version) {
    return 'Firmware: $version';
  }

  @override
  String get uiGlassesNotPaired => 'Nicht gekoppelt – siehe Einstellungen';

  @override
  String get uiHaNotSetUp => 'Nicht eingerichtet – siehe Einstellungen';

  @override
  String get uiListening => 'Hört zu …';

  @override
  String get uiOverview => 'Übersicht';

  @override
  String get uiPreferredAssistant => 'bevorzugter Assistent';

  @override
  String get uiPreviewEmpty =>
      'Keine Anzeige der App\n(die Brille zeigt ggf. ihre eigene Oberfläche)';

  @override
  String get uiPreviewTitle => 'Vorschau der Brillenanzeige';

  @override
  String uiQuestion(String text) {
    return 'Frage: $text';
  }

  @override
  String get uiRecording => 'Aufnahme';

  @override
  String get uiRecordingFlow => 'Brillen-Mikrofon → WhisperNotes → BasaltNotes';

  @override
  String uiRecordingPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufnahmen noch nicht gesendet',
      one: '1 Aufnahme noch nicht gesendet',
    );
    return '$_temp0';
  }

  @override
  String uiRecordingRunning(String time) {
    return 'Läuft · $time';
  }

  @override
  String get uiRecordingSetUp => 'WhisperNotes in den Einstellungen eintragen';

  @override
  String get uiRecordingUploading => 'Wird an WhisperNotes gesendet …';

  @override
  String get uiSettings => 'Einstellungen';

  @override
  String get uiSilentMode => 'Ruhemodus';

  @override
  String get uiSilentModeSubtitle =>
      'Keine Texte, Benachrichtigungen oder Dashboards. Assist funktioniert weiter.';

  @override
  String get uiStart => 'Start';

  @override
  String get uiStop => 'Stopp';

  @override
  String get uiWearCaseClosed => 'Im Case (Deckel zu)';

  @override
  String get uiWearCaseOpen => 'Im Case (Deckel offen)';

  @override
  String get uiWearNotWorn => 'Abgesetzt';

  @override
  String get uiWearWorn => 'Getragen';

  @override
  String updateAvailable(String version) {
    return 'Version $version ist verfügbar';
  }

  @override
  String get updateCancel => 'Abbrechen';

  @override
  String get updateChannel => 'Update-Kanal';

  @override
  String get updateChannelPreview => 'Vorabversion';

  @override
  String get updateChannelStable => 'Stabil';

  @override
  String get updateCheck => 'Nach Updates suchen';

  @override
  String get updateCheckFailed => 'Konnte nicht nach Updates suchen.';

  @override
  String get updateDailyCheck =>
      'Die App sucht einmal am Tag beim Start nach neuen Versionen auf GitHub.';

  @override
  String get updateDownloadFailed => 'Das Update konnte nicht geladen werden.';

  @override
  String get updateInstall => 'Installieren';

  @override
  String get updateInstallQuestion =>
      'Jetzt laden und installieren? Deine Einstellungen bleiben erhalten.';

  @override
  String updateInstalled(String version) {
    return 'Installiert: $version';
  }

  @override
  String get updateLater => 'Später';

  @override
  String get updatePreviewQuestion => 'Vorabversionen installieren?';

  @override
  String updatePreviewVersion(String version) {
    return 'Vorabversion $version';
  }

  @override
  String get updatePreviewWarning =>
      'Vorabversionen entstehen bei jeder Änderung am Projekt und sind weniger getestet als die stabilen Versionen.\n\nZurück zum stabilen Kanal geht es mit dem nächsten stabilen Release. Android installiert keine älteren Builds, sonst geht es nur über eine Neuinstallation.';

  @override
  String updateStableVersion(String version) {
    return 'Stabile Version $version';
  }

  @override
  String get updateSwitch => 'Wechseln';

  @override
  String get updateUpToDate => 'Die App ist aktuell.';

  @override
  String get updateVersionUnknown => 'Installierte Version unbekannt';
}
