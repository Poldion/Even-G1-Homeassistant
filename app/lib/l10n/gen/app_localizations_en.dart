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
  String get diagCheckDisplay => 'Check left/right display';

  @override
  String get diagClose => 'Close';

  @override
  String get diagEvenAi => 'Assist answers in Even AI mode (test)';

  @override
  String get diagEvenAiSubtitle =>
      'Shows answers like the official Even app. Try it if one eye shows something different from the other.';

  @override
  String get diagLog => 'Log';

  @override
  String get diagShowOnGlasses => 'Show on glasses';

  @override
  String get diagTestText => 'Test text';

  @override
  String get diagTestTextDefault => 'Hello from Home Assistant!';

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
  String uiBrightnessNow(int percent) {
    return ' (currently $percent %)';
  }

  @override
  String uiBrightnessOffsetEven(String offset, String current) {
    return 'About every two minutes, while nothing is shown, the app reads the light sensor and sets it $offset %$current.';
  }

  @override
  String uiBrightnessOffsetScouter(String offset, String current) {
    return 'The light sensor reports whenever the brightness changes noticeably while something is shown; the app then sets $offset % relative to the automatic level$current.';
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
  String get updateChannelPreview => 'Preview';

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
  String get updatePreviewQuestion => 'Install preview versions?';

  @override
  String updatePreviewVersion(String version) {
    return 'Preview $version';
  }

  @override
  String get updatePreviewWarning =>
      'Preview versions are built with every change to the project and are tested less than the stable versions.\n\nYou get back to the stable channel with the next stable release. Android does not install older builds; otherwise only a reinstall helps.';

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
}
