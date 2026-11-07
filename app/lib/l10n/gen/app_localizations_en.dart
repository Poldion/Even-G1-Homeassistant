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
  String g1LogAutoBrightness(int sensor, int level) {
    return 'Auto brightness: sensor $sensor %, set $level %';
  }

  @override
  String get g1LogConnectionFast => 'Connection: fast';

  @override
  String get g1LogConnectionSaving => 'Connection: power saving';

  @override
  String g1LogDisplayMissingLeft(String screen) {
    return 'Left display was missing ($screen) – sent again';
  }

  @override
  String g1LogDisplayMissingRight(String screen) {
    return 'Right display was missing ($screen) – sent again';
  }

  @override
  String get g1LogLeftNoAcks => 'L does not confirm texts – check off';

  @override
  String get g1LogLeftNotConfirmed => 'L: text not confirmed';

  @override
  String get g1LogLeftRejected => 'L: text rejected – sent again';

  @override
  String get g1LogLeftUnanswered => 'L: text unanswered – sent again';

  @override
  String g1LogWearState(String state) {
    return 'State: $state';
  }

  @override
  String get g1StatusConnected => 'connected';

  @override
  String get g1StatusConnecting => 'connecting…';

  @override
  String g1StatusConnectingOne(String side) {
    return 'connecting ($side ready)…';
  }

  @override
  String get g1StatusDisconnected => 'disconnected';

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

  @override
  String get skAnimSleepSubtitle => 'see you soon';

  @override
  String get skAnimSleepTitle => 'Silent mode';

  @override
  String get skAnimWakeSubtitle => 'Silent mode off';

  @override
  String get skAnimWakeTitle => 'I\'m back';

  @override
  String get skLogAnimationOff => 'Animation: silent mode off';

  @override
  String get skLogAnimationOn => 'Animation: silent mode on';

  @override
  String skLogArmReady(String arm, String version) {
    return '$arm arm ready (g1v0 $version)';
  }

  @override
  String skLogArmReadyEncrypted(String arm, String version) {
    return '$arm arm ready (g1v0 $version, encrypted)';
  }

  @override
  String skLogAutoBrightness(int lux, int stock, String offset, int level) {
    return 'Auto brightness: $lux lx, level $stock $offset → $level';
  }

  @override
  String skLogBondFailed(String arm, String error) {
    return 'Pairing $arm: $error';
  }

  @override
  String skLogBonding(String arm) {
    return '$arm arm is being paired (in the case)';
  }

  @override
  String skLogDisplayError(String arm) {
    return '$arm: display error at start';
  }

  @override
  String skLogEncrypted(String arm) {
    return '$arm: connection encrypted';
  }

  @override
  String get skLogEvenCommandSkipped => 'Even command to g1v0 skipped';

  @override
  String skLogEventsRejected(String arm) {
    return '$arm: EVENTS rejected';
  }

  @override
  String skLogFontLoaded(String arm, int bytes, int ms) {
    return '$arm: font loaded ($bytes B, $ms ms)';
  }

  @override
  String get skLogInCase =>
      'Glasses in the charging case – display stays off (disturbs charging)';

  @override
  String skLogMic(String error) {
    return 'Microphone: $error';
  }

  @override
  String get skLogMicNeedsEncryption =>
      'The microphone needs an encrypted (paired) connection';

  @override
  String skLogMicStopped(String arm, int reason) {
    return '$arm: microphone stopped by the glasses ($reason)';
  }

  @override
  String skLogNewSession(String arm) {
    return '$arm arm: new session (restart?), setting up again';
  }

  @override
  String skLogNoAnswerNotBonded(String arm) {
    return '$arm arm does not answer and is not paired: put the glasses into the open charging case to pair them';
  }

  @override
  String skLogNoService(String arm) {
    return '$arm arm: no ScouterKit service – is g1v0 running on this arm?';
  }

  @override
  String skLogNotBonded(String arm) {
    return '$arm arm not paired – put it into the open charging case to pair';
  }

  @override
  String skLogOtherArm(String arm) {
    return '$arm arm reports as the other arm';
  }

  @override
  String skLogPacketError(
    String arm,
    int seq,
    String error,
    String op,
    int detail,
  ) {
    return '$arm: error in packet $seq: $error (op 0x$op, detail $detail)';
  }

  @override
  String skLogProgramHalted(
    String arm,
    String error,
    String address,
    String op,
  ) {
    return '$arm: program halted: $error (0x$address, op 0x$op)';
  }

  @override
  String skLogProgramNotLoaded(String arm) {
    return '$arm: program not loaded';
  }

  @override
  String skLogProgramRunning(String arm, int bytes) {
    return '$arm: program running ($bytes B)';
  }

  @override
  String skLogProgramRunningGestures(String arm, int bytes) {
    return '$arm: program running ($bytes B, head gestures)';
  }

  @override
  String skLogProgramStopped(String arm) {
    return '$arm: program stopped';
  }

  @override
  String skLogProtocol(String arm, int protocol) {
    return '$arm arm speaks protocol $protocol, the app needs 5';
  }

  @override
  String skLogResetupFailed(String arm, String error) {
    return 'Setting up $arm again: $error';
  }

  @override
  String skLogSafeMode(String arm) {
    return '$arm arm in safe mode (after start errors): no display';
  }

  @override
  String skLogVmStartRejected(String arm) {
    return '$arm: VM_START rejected';
  }
}
