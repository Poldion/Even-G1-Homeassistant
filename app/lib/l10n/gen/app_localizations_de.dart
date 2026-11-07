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
  String g1LogAutoBrightness(int sensor, int level) {
    return 'Auto-Helligkeit: Sensor $sensor %, gesetzt $level %';
  }

  @override
  String get g1LogConnectionFast => 'Verbindung: schnell';

  @override
  String get g1LogConnectionSaving => 'Verbindung: sparsam';

  @override
  String g1LogDisplayMissingLeft(String screen) {
    return 'Anzeige links fehlte ($screen) – erneut gesendet';
  }

  @override
  String g1LogDisplayMissingRight(String screen) {
    return 'Anzeige rechts fehlte ($screen) – erneut gesendet';
  }

  @override
  String get g1LogLeftNoAcks => 'L bestätigt Texte nicht – Prüfung aus';

  @override
  String get g1LogLeftNotConfirmed => 'L: Text nicht bestätigt';

  @override
  String get g1LogLeftRejected => 'L: Text abgelehnt – erneut gesendet';

  @override
  String get g1LogLeftUnanswered => 'L: Text unbeantwortet – erneut gesendet';

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
  String get skAnimSleepSubtitle => 'bis gleich';

  @override
  String get skAnimSleepTitle => 'Ruhemodus';

  @override
  String get skAnimWakeSubtitle => 'Ruhemodus aus';

  @override
  String get skAnimWakeTitle => 'Bin wieder da';

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
  String skLogEncrypted(String arm) {
    return '$arm: Verbindung verschlüsselt';
  }

  @override
  String get skLogEvenCommandSkipped => 'Even-Befehl an g1v0 übersprungen';

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
  String skLogVmStartRejected(String arm) {
    return '$arm: VM_START abgelehnt';
  }
}
