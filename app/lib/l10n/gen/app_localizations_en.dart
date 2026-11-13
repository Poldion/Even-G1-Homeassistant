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
  String get coreDone => 'Done.';

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
  String get coreLogHeadGesturesOff => 'Head gestures off';

  @override
  String get coreLogHeadGesturesOn => 'Head gestures on';

  @override
  String coreLogHeadUpAngle(int angle) {
    return 'Activation angle: $angle°';
  }

  @override
  String get coreLogIntegrationReloaded => 'Integration reloaded, reconnecting';

  @override
  String get coreLogMicFailed => 'Microphone could not be switched on';

  @override
  String get coreLogNavigationEnd => 'Navigation ended';

  @override
  String get coreLogNavigationStart => 'Navigation started';

  @override
  String coreLogNavigationStep(String step) {
    return 'Navigation: $step';
  }

  @override
  String coreLogNotification(String app, String title) {
    return 'Notification: $app – $title';
  }

  @override
  String coreLogNotificationsError(String error) {
    return 'Notifications: $error';
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
  String get coreNoHaConnection => 'No connection to Home Assistant';

  @override
  String get coreRecordingFileName => 'Glasses note';

  @override
  String get coreRecordingLabel => 'BasaltNotes is recording';

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
  String coreThinking(String assistant) {
    return '$assistant\nOne moment …';
  }

  @override
  String get coreTimeout => 'Timeout';

  @override
  String coreTranscript(String assistant, String text) {
    return '$assistant\n» $text «\nOne moment …';
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
  String get diagClose => 'Close';

  @override
  String get diagLog => 'Log';

  @override
  String get diagShowOnGlasses => 'Show on glasses';

  @override
  String get diagTestText => 'Test text';

  @override
  String get diagTestTextDefault => 'Hello from Home Assistant!';

  @override
  String get g1LogConnectionFast => 'Connection: fast';

  @override
  String get g1LogConnectionSaving => 'Connection: power saving';

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
  String get glassesSetAngle => 'Activation angle';

  @override
  String get glassesSetAngleHelp =>
      'From this head tilt the glasses switch the display on when you look up.';

  @override
  String glassesSetArms(String left, String right) {
    return 'Left: $left\nRight: $right';
  }

  @override
  String get glassesSetGyroCheck => 'Ignore jolts when looking up';

  @override
  String get glassesSetGyroCheckHelp =>
      'Only with head gestures: the dashboard comes only when the gyroscope saw your head turn, not when the car brakes or goes over a bump. A very slow look up may then not count.';

  @override
  String get glassesSetHeadGestures => 'Head gestures';

  @override
  String get glassesSetHeadGesturesHelp =>
      'Nodding and shaking the head as gestures for Home Assistant. The gyroscope of the right arm then runs all the time and needs a bit more battery.';

  @override
  String get glassesSetNonePaired => 'No glasses paired yet.';

  @override
  String get glassesSetNotConnected =>
      'The glasses are not connected. Changes are sent the next time they connect.';

  @override
  String get glassesSetNotSet => 'not set';

  @override
  String glassesSetPaired(String name) {
    return 'Paired: $name';
  }

  @override
  String get glassesSetScouterHint =>
      'ScouterKit (g1v0): For the first pairing put the glasses into the open charging case. Outside the case they obey only paired devices.';

  @override
  String get glassesSetSearch => 'Search for glasses';

  @override
  String get glassesSetSearching => 'Searching…';

  @override
  String haSetConnectFailed(String error) {
    return 'Connection failed: $error';
  }

  @override
  String get haSetGlasses => 'Glasses in Home Assistant';

  @override
  String get haSetLoad => 'Connect & load glasses from HA';

  @override
  String get haSetNoGlasses =>
      'No glasses found in Home Assistant. Add the \"Even Realities G1\" integration first.';

  @override
  String get haSetNotInstalled =>
      'The \"Even Realities G1\" integration is not installed in Home Assistant.';

  @override
  String get haSetToken => 'Long-lived access token';

  @override
  String get haSetTokenHelp => 'HA → Profile → Security → Create token';

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
  String get notifSetAllow => 'Allow';

  @override
  String get notifSetAndroidOnly =>
      'Forwarding phone notifications is only available on Android.';

  @override
  String get notifSetApps => 'Apps whose notifications arrive:';

  @override
  String get notifSetForward => 'Forward phone notifications';

  @override
  String get notifSetNavigation => 'Google Maps navigation';

  @override
  String get notifSetNavigationHelp =>
      'Arrow and distance on the glasses: at each new turn and at 500, 200 and 50 m; on head-up instead of the dashboard while you navigate.';

  @override
  String get notifSetNoAccess => 'Access to notifications missing';

  @override
  String get notifSetNoAccessHelp =>
      'Allow \"Even G1 HA\" to read notifications in the Android settings.\nIf Android reports \"App was denied access\": Settings → Apps → Even G1 HA → ⋮ → \"Allow restricted settings\", then tap Allow again.';

  @override
  String get notifSetNoApps =>
      'Apps appear here once they have sent a notification. New apps are forwarded by default.';

  @override
  String get recSetIntro =>
      'Recordings with the glasses microphone go to WhisperNotes, are transcribed and summarised there and end up in the BasaltNotes inbox if a default vault is chosen in WhisperNotes under Settings → BasaltNotes.';

  @override
  String get recSetKey => 'API key (optional)';

  @override
  String get recSetKeyHelp => 'Only needed if one is set in WhisperNotes.';

  @override
  String get recSetScouterDot =>
      'During a recording ScouterKit itself shows a small square at the top right of the right eye while the microphone is on. It cannot be switched off.';

  @override
  String recSetSendPending(int count) {
    return 'Send $count pending';
  }

  @override
  String get recSetUrl => 'WhisperNotes address';

  @override
  String get save => 'Save';

  @override
  String get saved => 'Saved';

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
  String get settingsDisplaySubtitle => 'Activation angle, head gestures';

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
  String get skLabSleepSubtitle => 'silent mode on';

  @override
  String get skLabSleepTitle => 'ENTERING STANDBY';

  @override
  String get skLabWakeSubtitle => 'silent mode off';

  @override
  String get skLabWakeTitle => 'SYSTEM ONLINE';

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
  String get skLogEmojiReset => 'Emoji slots full: starting over';

  @override
  String skLogEncrypted(String arm) {
    return '$arm: connection encrypted';
  }

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
  String skLogLight(String lux, String level) {
    return 'Light $lux lux → brightness level $level';
  }

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
  String skLogOffsetOnArms(String offset) {
    return 'Automatic brightness $offset on the glasses';
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
  String skLogVideo(String width, String height, String fps) {
    return 'Video: $width×$height, $fps frames/s';
  }

  @override
  String skLogVideoEnd(String end) {
    return 'Video ended: $end';
  }

  @override
  String skLogVmStartRejected(String arm) {
    return '$arm: VM_START rejected';
  }

  @override
  String uiAnswer(String text) {
    return 'Answer: $text';
  }

  @override
  String get uiAssistHint => 'Hold the left touch bar, speak, release.';

  @override
  String uiAssistant(String name) {
    return 'Assistant: $name';
  }

  @override
  String get uiBatteryCase => 'Case';

  @override
  String get uiBatteryLeft => 'Left';

  @override
  String get uiBatteryRight => 'Right';

  @override
  String get uiBrightness => 'Brightness';

  @override
  String get uiBrightnessAutoHint =>
      'The glasses set the brightness with their light sensor. The slider makes it brighter or darker.';

  @override
  String get uiBrightnessLog => 'Even curve (logarithmic)';

  @override
  String get uiBrightnessLogHint =>
      'Every tenfold change of the light gives the same step in brightness, close to how the eye sees it. Off: the original curve of the glasses.';

  @override
  String uiBrightnessNow(int percent) {
    return ' (currently $percent %)';
  }

  @override
  String uiBrightnessOffsetScouter(String offset, String current) {
    return 'The glasses set $offset % relative to the automatic level$current.';
  }

  @override
  String get uiConnect => 'Connect';

  @override
  String uiFirmware(String version) {
    return 'Firmware: $version';
  }

  @override
  String get uiGlassesNotPaired => 'Not paired – see Settings';

  @override
  String get uiHaNotSetUp => 'Not set up – see Settings';

  @override
  String get uiListening => 'Listening …';

  @override
  String get uiOverview => 'Overview';

  @override
  String get uiPreferredAssistant => 'preferred assistant';

  @override
  String get uiPreviewEmpty =>
      'Nothing shown by the app\n(the glasses may show their own screen)';

  @override
  String get uiPreviewTitle => 'Preview of the glasses display';

  @override
  String uiQuestion(String text) {
    return 'Question: $text';
  }

  @override
  String get uiRecording => 'Recording';

  @override
  String get uiRecordingFlow =>
      'Glasses microphone → WhisperNotes → BasaltNotes';

  @override
  String uiRecordingPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recordings not sent yet',
      one: '1 recording not sent yet',
    );
    return '$_temp0';
  }

  @override
  String uiRecordingRunning(String time) {
    return 'Running · $time';
  }

  @override
  String get uiRecordingSetUp => 'Enter WhisperNotes in the settings';

  @override
  String get uiRecordingUploading => 'Sending to WhisperNotes …';

  @override
  String get uiSettings => 'Settings';

  @override
  String get uiSilentMode => 'Silent mode';

  @override
  String get uiSilentModeSubtitle =>
      'No texts, notifications or dashboards. Assist keeps working.';

  @override
  String get uiStart => 'Start';

  @override
  String get uiStop => 'Stop';

  @override
  String get uiWearCaseClosed => 'In the case (lid closed)';

  @override
  String get uiWearCaseOpen => 'In the case (lid open)';

  @override
  String get uiWearNotWorn => 'Taken off';

  @override
  String get uiWearWorn => 'Worn';

  @override
  String updateAvailable(String version) {
    return 'Version $version is available';
  }

  @override
  String get updateCancel => 'Cancel';

  @override
  String get updateChannel => 'Update channel';

  @override
  String get updateChannelPreview => 'Beta';

  @override
  String get updateChannelStable => 'Stable';

  @override
  String get updateCheck => 'Check for updates';

  @override
  String get updateCheckFailed => 'Could not check for updates.';

  @override
  String get updateDailyCheck =>
      'The app looks for new versions on GitHub once a day when it starts.';

  @override
  String get updateDownloadFailed => 'The update could not be downloaded.';

  @override
  String get updateEvenNoticeBody =>
      'Since 0.25.0 the app works only with glasses that run the ScouterKit firmware. Your glasses were paired with Even\'s firmware, which is no longer supported.\n\nWith Even\'s firmware, install 0.24.x, the last version for it, from the releases page. Android installs an older version only after uninstalling this one; your settings are lost then.';

  @override
  String get updateEvenNoticeScouterKit => 'I use ScouterKit';

  @override
  String get updateEvenNoticeTitle => 'This version needs ScouterKit';

  @override
  String updateHeldBackBody(String version) {
    return 'Version $version and later support only glasses with the ScouterKit firmware. Your glasses run Even\'s firmware, so this app stays on its current version, which keeps working.\n\nSupport for Even\'s firmware is no longer developed (branch \"legacy\" on GitHub). If you switch to ScouterKit, choose it under Settings → Glasses; then updates are offered again.';
  }

  @override
  String get updateHeldBackOk => 'OK';

  @override
  String get updateHeldBackTitle => 'No more updates for Even\'s firmware';

  @override
  String get updateInstall => 'Install';

  @override
  String get updateInstallQuestion =>
      'Download and install now? Your settings are kept.';

  @override
  String updateInstalled(String version) {
    return 'Installed: $version';
  }

  @override
  String get updateLater => 'Later';

  @override
  String get updatePreviewQuestion => 'Install beta builds?';

  @override
  String updatePreviewVersion(String version) {
    return 'Beta build $version';
  }

  @override
  String get updatePreviewWarning =>
      'Beta builds are built with every change to the project and are tested less than the stable versions.\n\nYou get back to the stable channel with the next stable release. Android does not install older builds; otherwise only a reinstall helps.';

  @override
  String updateStableVersion(String version) {
    return 'Stable version $version';
  }

  @override
  String get updateSwitch => 'Switch';

  @override
  String get updateUpToDate => 'The app is up to date.';

  @override
  String get updateVersionUnknown => 'Installed version unknown';

  @override
  String get videoDone => 'Done.';

  @override
  String get videoFailed =>
      'The glasses could not play the video. Their ScouterKit firmware may be too old for videos.';

  @override
  String videoInfo(String width, String height, String fps, String duration) {
    return '$width × $height px · $fps frames/s · $duration';
  }

  @override
  String get videoIntro =>
      'Plays a video from your phone on both eyes, in black and white; the sound comes from the phone. Videos with strong contrast work best, such as shadow animations.';

  @override
  String get videoInvert => 'Invert (a light background stays dark)';

  @override
  String get videoNone => 'No video chosen';

  @override
  String get videoNotConnected => 'Connect the glasses first.';

  @override
  String get videoOpenFailed => 'This video cannot be opened.';

  @override
  String get videoPick => 'Choose video';

  @override
  String get videoPlay => 'Play';

  @override
  String videoProgress(String time, String total, String skipped) {
    return '$time / $total · $skipped frames skipped';
  }

  @override
  String get videoStop => 'Stop';

  @override
  String get videoTitle => 'Video on the glasses';

  @override
  String get videoUnlocked => 'You found the video player.';
}
