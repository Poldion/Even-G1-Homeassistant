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
  String get coreDone => 'Erledigt.';

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
  String coreLogDisplayHeight(int height) {
    return 'Anzeigehöhe $height';
  }

  @override
  String get coreLogHeadGesturesOff => 'Kopfgesten aus';

  @override
  String get coreLogHeadGesturesOn => 'Kopfgesten an';

  @override
  String coreLogHeadUpAngle(int angle) {
    return 'Aktivierungswinkel: $angle°';
  }

  @override
  String get coreLogIntegrationReloaded =>
      'Integration neu geladen, verbinde neu';

  @override
  String get coreLogMicFailed => 'Mikrofon konnte nicht aktiviert werden';

  @override
  String get coreLogNavigationEnd => 'Navigation beendet';

  @override
  String get coreLogNavigationStart => 'Navigation gestartet';

  @override
  String coreLogNavigationStep(String step) {
    return 'Navigation: $step';
  }

  @override
  String coreLogNotification(String app, String title) {
    return 'Benachrichtigung: $app – $title';
  }

  @override
  String coreLogNotificationsError(String error) {
    return 'Benachrichtigungen: $error';
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
  String get coreNoHaConnection => 'Keine Verbindung zu Home Assistant';

  @override
  String get coreRecordingFileName => 'Brillen-Notiz';

  @override
  String get coreRecordingLabel => 'BasaltNotes nimmt auf';

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
  String get diagClose => 'Schließen';

  @override
  String get diagLog => 'Protokoll';

  @override
  String get diagShowOnGlasses => 'Auf Brille anzeigen';

  @override
  String get diagTestText => 'Testtext';

  @override
  String get diagTestTextDefault => 'Hallo von Home Assistant!';

  @override
  String get g1LogConnectionFast => 'Verbindung: schnell';

  @override
  String get g1LogConnectionSaving => 'Verbindung: sparsam';

  @override
  String g1LogWearState(String state) {
    return 'Zustand: $state';
  }

  @override
  String get g1StatusConnected => 'verbunden';

  @override
  String get g1StatusConnecting => 'verbinde…';

  @override
  String g1StatusConnectingOne(String side) {
    return 'verbinde ($side bereit)…';
  }

  @override
  String get g1StatusDisconnected => 'getrennt';

  @override
  String get glasses => 'Brille';

  @override
  String get glassesSetAngle => 'Aktivierungswinkel';

  @override
  String get glassesSetAngleHelp =>
      'Ab dieser Kopfneigung schaltet die Brille beim Hochschauen die Anzeige ein.';

  @override
  String glassesSetArms(String left, String right) {
    return 'Links: $left\nRechts: $right';
  }

  @override
  String get glassesSetHeadGestures => 'Kopfgesten';

  @override
  String get glassesSetHeadGesturesHelp =>
      'Nicken und Kopfschütteln als Gesten für Home Assistant. Der Gyrosensor des rechten Bügels läuft dann ständig und braucht etwas mehr Akku.';

  @override
  String get glassesSetHeight => 'Höhe';

  @override
  String get glassesSetHeightHelp =>
      'Wie hoch der Text im Sichtfeld steht. Beim Loslassen zeigt die Brille die neue Position kurz an und übernimmt sie.';

  @override
  String get glassesSetNonePaired => 'Noch keine Brille gekoppelt.';

  @override
  String get glassesSetNotConnected =>
      'Die Brille ist nicht verbunden. Änderungen werden beim nächsten Verbinden übertragen.';

  @override
  String get glassesSetNotSet => 'nicht gesetzt';

  @override
  String glassesSetPaired(String name) {
    return 'Gekoppelt: $name';
  }

  @override
  String get glassesSetScouterHint =>
      'ScouterKit (g1v0): Zum ersten Koppeln die Brille ins offene Ladeetui legen. Außerhalb des Etuis gehorcht sie nur gekoppelten Geräten.';

  @override
  String get glassesSetSearch => 'Nach Brillen suchen';

  @override
  String get glassesSetSearching => 'Suche…';

  @override
  String haSetConnectFailed(String error) {
    return 'Verbindung fehlgeschlagen: $error';
  }

  @override
  String get haSetGlasses => 'Brille in Home Assistant';

  @override
  String get haSetLoad => 'Verbinden & Brillen aus HA laden';

  @override
  String get haSetNoGlasses =>
      'Keine Brille in Home Assistant gefunden. Füge zuerst die Integration \"Even Realities G1\" hinzu.';

  @override
  String get haSetNotInstalled =>
      'Die Integration \"Even Realities G1\" ist in Home Assistant nicht installiert.';

  @override
  String get haSetToken => 'Langlebiges Zugriffstoken';

  @override
  String get haSetTokenHelp => 'HA → Profil → Sicherheit → Token erstellen';

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
  String get notifSetAllow => 'Erlauben';

  @override
  String get notifSetAndroidOnly =>
      'Das Weiterleiten von Handy-Benachrichtigungen ist nur unter Android verfügbar.';

  @override
  String get notifSetApps => 'Apps, deren Benachrichtigungen ankommen:';

  @override
  String get notifSetForward => 'Handy-Benachrichtigungen weiterleiten';

  @override
  String get notifSetNavigation => 'Google-Maps-Navigation';

  @override
  String get notifSetNavigationHelp =>
      'Pfeil und Entfernung auf der Brille: bei jeder neuen Abbiegung und bei 500, 200 und 50 m; beim Hochschauen statt des Dashboards, solange du navigierst.';

  @override
  String get notifSetNoAccess => 'Zugriff auf Benachrichtigungen fehlt';

  @override
  String get notifSetNoAccessHelp =>
      'Erlaube „Even G1 HA“ in den Android-Einstellungen, Benachrichtigungen zu lesen.\nMeldet Android „App wurde Zugriff verweigert“: Einstellungen → Apps → Even G1 HA → ⋮ → „Eingeschränkte Einstellungen zulassen“, dann erneut auf Erlauben tippen.';

  @override
  String get notifSetNoApps =>
      'Apps erscheinen hier, sobald sie eine Benachrichtigung gesendet haben. Neue Apps werden standardmäßig weitergeleitet.';

  @override
  String get recSetIntro =>
      'Aufnahmen mit dem Brillen-Mikrofon gehen an WhisperNotes, werden dort transkribiert und zusammengefasst und landen im Eingang von BasaltNotes, wenn in WhisperNotes unter Einstellungen → BasaltNotes ein Standard-Vault gewählt ist.';

  @override
  String get recSetKey => 'API-Schlüssel (optional)';

  @override
  String get recSetKeyHelp =>
      'Nur nötig, wenn in WhisperNotes einer gesetzt ist.';

  @override
  String get recSetScouterDot =>
      'Während einer Aufnahme zeigt ScouterKit selbst ein kleines Quadrat oben rechts im rechten Auge, solange das Mikrofon an ist. Es lässt sich nicht ausschalten.';

  @override
  String recSetSendPending(int count) {
    return '$count ausstehende senden';
  }

  @override
  String get recSetUrl => 'WhisperNotes-Adresse';

  @override
  String get save => 'Speichern';

  @override
  String get saved => 'Gespeichert';

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
  String get settingsDisplaySubtitle => 'Aktivierungswinkel, Höhe, Kopfgesten';

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
  String get skAnimSleepSubtitle => 'bis gleich';

  @override
  String get skAnimSleepTitle => 'Ruhemodus';

  @override
  String get skAnimWakeSubtitle => 'Ruhemodus aus';

  @override
  String get skAnimWakeTitle => 'Bin wieder da';

  @override
  String get skLabSleepSubtitle => 'Ruhemodus an';

  @override
  String get skLabSleepTitle => 'STANDBY-MODUS';

  @override
  String get skLabWakeSubtitle => 'Ruhemodus aus';

  @override
  String get skLabWakeTitle => 'SYSTEM BEREIT';

  @override
  String get skLogAnimationOff => 'Animation: Ruhemodus aus';

  @override
  String get skLogAnimationOn => 'Animation: Ruhemodus an';

  @override
  String skLogArmReady(String arm, String version) {
    return '$arm arm bereit (g1v0 $version)';
  }

  @override
  String skLogArmReadyEncrypted(String arm, String version) {
    return '$arm arm bereit (g1v0 $version, verschlüsselt)';
  }

  @override
  String skLogAutoBrightness(int lux, int stock, String offset, int level) {
    return 'Auto-Helligkeit: $lux lx, Stufe $stock $offset → $level';
  }

  @override
  String skLogBondFailed(String arm, String error) {
    return 'Koppeln $arm: $error';
  }

  @override
  String skLogBonding(String arm) {
    return '$arm arm wird gekoppelt (im Etui)';
  }

  @override
  String skLogDisplayError(String arm) {
    return '$arm: Anzeigefehler beim Start';
  }

  @override
  String get skLogEmojiReset => 'Emoji-Plätze voll: neu belegt';

  @override
  String skLogEncrypted(String arm) {
    return '$arm: Verbindung verschlüsselt';
  }

  @override
  String skLogEventsRejected(String arm) {
    return '$arm: EVENTS abgelehnt';
  }

  @override
  String skLogFontLoaded(String arm, int bytes, int ms) {
    return '$arm: Schrift geladen ($bytes B, $ms ms)';
  }

  @override
  String get skLogInCase =>
      'Brille im Ladeetui – Anzeige bleibt aus (stört das Laden)';

  @override
  String skLogMic(String error) {
    return 'Mikrofon: $error';
  }

  @override
  String get skLogMicNeedsEncryption =>
      'Mikrofon braucht eine verschlüsselte (gekoppelte) Verbindung';

  @override
  String skLogMicStopped(String arm, int reason) {
    return '$arm: Mikrofon von der Brille beendet ($reason)';
  }

  @override
  String skLogNewSession(String arm) {
    return '$arm arm: neue Sitzung (Neustart?), richte neu ein';
  }

  @override
  String skLogNoAnswerNotBonded(String arm) {
    return '$arm arm antwortet nicht und ist nicht gekoppelt: Brille ins offene Ladeetui legen, dann wird gekoppelt';
  }

  @override
  String skLogNoService(String arm) {
    return '$arm arm: kein ScouterKit-Dienst – läuft g1v0 auf diesem Bügel?';
  }

  @override
  String skLogNotBonded(String arm) {
    return '$arm arm nicht gekoppelt – zum Koppeln ins offene Ladeetui legen';
  }

  @override
  String skLogOffsetOnArms(String offset) {
    return 'Automatische Helligkeit $offset auf der Brille';
  }

  @override
  String skLogOtherArm(String arm) {
    return '$arm arm meldet sich als anderer Bügel';
  }

  @override
  String skLogPacketError(
    String arm,
    int seq,
    String error,
    String op,
    int detail,
  ) {
    return '$arm: Fehler in Paket $seq: $error (op 0x$op, Detail $detail)';
  }

  @override
  String skLogProgramHalted(
    String arm,
    String error,
    String address,
    String op,
  ) {
    return '$arm: Programm angehalten: $error (0x$address, op 0x$op)';
  }

  @override
  String skLogProgramNotLoaded(String arm) {
    return '$arm: Programm nicht geladen';
  }

  @override
  String skLogProgramRunning(String arm, int bytes) {
    return '$arm: Programm läuft ($bytes B)';
  }

  @override
  String skLogProgramRunningGestures(String arm, int bytes) {
    return '$arm: Programm läuft ($bytes B, Kopfgesten)';
  }

  @override
  String skLogProgramStopped(String arm) {
    return '$arm: Programm beendet';
  }

  @override
  String skLogProtocol(String arm, int protocol) {
    return '$arm arm spricht Protokoll $protocol, die App braucht 5';
  }

  @override
  String skLogResetupFailed(String arm, String error) {
    return 'Neueinrichtung $arm: $error';
  }

  @override
  String skLogSafeMode(String arm) {
    return '$arm arm im sicheren Modus (nach Startfehlern): keine Anzeige';
  }

  @override
  String skLogVideo(String width, String height, String fps) {
    return 'Video: $width×$height, $fps Bilder/s';
  }

  @override
  String skLogVideoEnd(String end) {
    return 'Video beendet: $end';
  }

  @override
  String skLogVmStartRejected(String arm) {
    return '$arm: VM_START abgelehnt';
  }

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
  String get updateChannelPreview => 'Beta-Version';

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
  String get updateEvenNoticeBody =>
      'Seit 0.25.0 arbeitet die App nur noch mit Brillen, auf denen die ScouterKit-Firmware läuft. Deine Brille wurde mit Evens Firmware gekoppelt, die nicht mehr unterstützt wird.\n\nMit Evens Firmware installiere 0.24.x, die letzte Version dafür, von der Releases-Seite. Android installiert eine ältere Version erst, nachdem du diese deinstalliert hast; deine Einstellungen gehen dabei verloren.';

  @override
  String get updateEvenNoticeScouterKit => 'Ich nutze ScouterKit';

  @override
  String get updateEvenNoticeTitle => 'Diese Version braucht ScouterKit';

  @override
  String updateHeldBackBody(String version) {
    return 'Ab Version $version unterstützt die App nur noch Brillen mit der ScouterKit-Firmware. Deine Brille läuft mit Evens Firmware, deshalb bleibt die App auf ihrer jetzigen Version, die weiter funktioniert.\n\nDie Unterstützung für Evens Firmware wird nicht mehr weiterentwickelt (Branch „legacy“ auf GitHub). Wechselst du zu ScouterKit, wähle es unter Einstellungen → Brille; dann werden wieder Updates angeboten.';
  }

  @override
  String get updateHeldBackOk => 'OK';

  @override
  String get updateHeldBackTitle => 'Keine Updates mehr für Evens Firmware';

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
  String get updatePreviewQuestion => 'Beta-Builds installieren?';

  @override
  String updatePreviewVersion(String version) {
    return 'Beta-Build $version';
  }

  @override
  String get updatePreviewWarning =>
      'Beta-Builds entstehen bei jeder Änderung am Projekt und sind weniger getestet als die stabilen Versionen.\n\nZurück zum stabilen Kanal geht es mit dem nächsten stabilen Release. Android installiert keine älteren Builds, sonst geht es nur über eine Neuinstallation.';

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

  @override
  String get videoDone => 'Fertig.';

  @override
  String get videoFailed =>
      'Die Brille konnte das Video nicht abspielen. Vielleicht ist ihre ScouterKit-Firmware zu alt für Videos.';

  @override
  String videoInfo(String width, String height, String fps, String duration) {
    return '$width × $height px · $fps Bilder/s · $duration';
  }

  @override
  String get videoIntro =>
      'Spielt ein Video vom Handy auf beiden Augen ab, in Schwarz-Weiß; der Ton kommt vom Handy. Am besten wirken Videos mit starkem Kontrast, etwa Schattenanimationen.';

  @override
  String get videoInvert => 'Invertieren (heller Hintergrund bleibt dunkel)';

  @override
  String get videoNone => 'Kein Video gewählt';

  @override
  String get videoNotConnected => 'Verbinde zuerst die Brille.';

  @override
  String get videoOpenFailed => 'Dieses Video lässt sich nicht öffnen.';

  @override
  String get videoPick => 'Video wählen';

  @override
  String get videoPlay => 'Abspielen';

  @override
  String videoProgress(String time, String total, String skipped) {
    return '$time / $total · $skipped Bilder übersprungen';
  }

  @override
  String get videoStop => 'Stopp';

  @override
  String get videoTitle => 'Video auf der Brille';

  @override
  String get videoUnlocked => 'Du hast den Videoplayer gefunden.';
}
