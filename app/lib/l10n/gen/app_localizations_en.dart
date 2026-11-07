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
  String get coreAssistNoAnswer => 'No answer';

  @override
  String coreAssistUnavailable(String error) {
    return 'Assist not available:\n$error';
  }

  @override
  String get coreCancelled => 'Cancelled';

  @override
  String get coreChannelDescription =>
      'Keeps the connection to the glasses in the background';

  @override
  String get coreChannelName => 'Even G1 connection';

  @override
  String coreDisplayCheck(String left, String right) {
    return 'Display left: $left, right: $right';
  }

  @override
  String coreDisplayCheckDiffers(String text) {
    return '$text – DIFFERENT';
  }

  @override
  String get coreDone => 'Done.';

  @override
  String get coreGlassesNotConnected => 'Glasses not connected';

  @override
  String coreHaConnected(String version) {
    return 'connected (HA $version)';
  }

  @override
  String get coreHaConnecting => 'connecting…';

  @override
  String get coreHaConnectionLost => 'Connection to Home Assistant lost';

  @override
  String get coreHaDisconnected => 'disconnected';

  @override
  String get coreHaNotSetUp => 'not set up';

  @override
  String coreHaRetry(int seconds) {
    return 'disconnected, retrying in ${seconds}s';
  }

  @override
  String get coreHaTokenInvalid => 'Token invalid';

  @override
  String coreListening(String assistant) {
    return '$assistant\nis listening …';
  }

  @override
  String coreLogAnswer(String text) {
    return 'Answer: $text';
  }

  @override
  String coreLogAssistError(String error) {
    return 'Assist error: $error';
  }

  @override
  String coreLogAssistStartFailed(String error) {
    return 'Assist start failed: $error';
  }

  @override
  String get coreLogAssistStarted => 'Assist started';

  @override
  String coreLogAudio(String error) {
    return 'Audio: $error';
  }

  @override
  String coreLogBrightness(int percent) {
    return 'Brightness: $percent %';
  }

  @override
  String get coreLogBrightnessAuto => 'Brightness: automatic';

  @override
  String coreLogBrightnessOffset(String offset) {
    return 'Brightness: automatic, $offset %';
  }

  @override
  String coreLogConfig(String name) {
    return 'Configuration received ($name)';
  }

  @override
  String get coreLogDashboardTap => 'Dashboard (tap)';

  @override
  String get coreLogEvenAiOff => 'Answers in text mode';

  @override
  String get coreLogEvenAiOn => 'Answers in Even AI mode';

  @override
  String get coreLogHeadGesturesOff => 'Head gestures off';

  @override
  String get coreLogHeadGesturesOn => 'Head gestures on';

  @override
  String coreLogHeadUpAngle(int angle) {
    return 'Activation angle: $angle°';
  }

  @override
  String get coreLogHeadUpHide => 'Head up: hide Even dashboard';

  @override
  String get coreLogHeadUpShow => 'Head up: show Even dashboard';

  @override
  String get coreLogIntegrationReloaded => 'Integration reloaded, reconnecting';

  @override
  String get coreLogMicFailed => 'Microphone could not be switched on';

  @override
  String coreLogNotification(String app, String title) {
    return 'Notification: $app – $title';
  }

  @override
  String coreLogNotificationsError(String error) {
    return 'Notifications: $error';
  }

  @override
  String coreLogPosition(int height, int depth) {
    return 'Display position: height $height, distance $depth';
  }

  @override
  String coreLogPositionPreview(int height, int depth) {
    return 'Display position: height $height, distance $depth (preview)';
  }

  @override
  String coreLogRecognized(String text) {
    return 'Recognized: $text';
  }

  @override
  String coreLogRecordingError(String error) {
    return 'Recording: $error';
  }

  @override
  String get coreLogRecordingMicRestarted => 'Recording: microphone restarted';

  @override
  String get coreLogRecordingNoGlasses =>
      'Recording: glasses not connected, microphone follows';

  @override
  String coreLogRecordingNotSent(String error) {
    return 'Recording not sent: $error';
  }

  @override
  String coreLogRecordingSent(String name) {
    return 'Recording sent: $name';
  }

  @override
  String get coreLogRecordingStarted => 'Recording started';

  @override
  String coreLogRecordingStopped(String length, String duration) {
    return 'Recording stopped: $length (duration $duration)';
  }

  @override
  String get coreLogRecordingTooShort => 'Recording discarded (too short)';

  @override
  String coreLogShowText(String text) {
    return 'Display: $text';
  }

  @override
  String get coreLogSilentDashboardSkipped =>
      'Silent mode – dashboard not shown';

  @override
  String get coreLogSilentNoGlasses => 'Silent mode: glasses not connected';

  @override
  String get coreLogSilentOff => 'Silent mode off';

  @override
  String get coreLogSilentOffGlasses => 'Silent mode off (glasses)';

  @override
  String get coreLogSilentOn => 'Silent mode on';

  @override
  String get coreLogSilentOnGlasses => 'Silent mode on (glasses)';

  @override
  String get coreLogSilentTextSkipped => 'Silent mode – text not shown';

  @override
  String get coreLogTextDropped => 'Glasses not connected – text dropped';

  @override
  String get coreLogWearOff => 'Wear detection off';

  @override
  String get coreLogWearOn => 'Wear detection on';

  @override
  String get coreNoAnswer => 'no answer';

  @override
  String get coreNoHaConnection => 'No connection to Home Assistant';

  @override
  String get coreRecordingFileName => 'Glasses note';

  @override
  String get coreServiceText => 'Connection active';

  @override
  String get coreSttFailed => 'Speech recognition failed.';

  @override
  String get coreSttMissing =>
      'No speech recognition configured in the Assist pipeline.';

  @override
  String get coreSttNothing => 'I didn\'t catch that.';

  @override
  String get coreThinking => 'Home Assistant\nOne moment …';

  @override
  String get coreTimeout => 'Timeout';

  @override
  String coreTranscript(String text) {
    return '» $text «\nOne moment …';
  }

  @override
  String get coreUnknownError => 'Unknown error';

  @override
  String coreWhisperFailed(String error) {
    return 'Sending failed: $error';
  }

  @override
  String get coreWhisperNotSetUp => 'WhisperNotes is not set up';

  @override
  String coreWhisperSent(String job) {
    return 'Sent to WhisperNotes (job $job)';
  }

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
