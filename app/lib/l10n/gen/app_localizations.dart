import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Even G1 for Home Assistant'**
  String get appTitle;

  /// No description provided for @diagCheckDisplay.
  ///
  /// In en, this message translates to:
  /// **'Check left/right display'**
  String get diagCheckDisplay;

  /// No description provided for @diagClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get diagClose;

  /// No description provided for @diagEvenAi.
  ///
  /// In en, this message translates to:
  /// **'Assist answers in Even AI mode (test)'**
  String get diagEvenAi;

  /// No description provided for @diagEvenAiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shows answers like the official Even app. Try it if one eye shows something different from the other.'**
  String get diagEvenAiSubtitle;

  /// No description provided for @diagLog.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get diagLog;

  /// No description provided for @diagShowOnGlasses.
  ///
  /// In en, this message translates to:
  /// **'Show on glasses'**
  String get diagShowOnGlasses;

  /// No description provided for @diagTestText.
  ///
  /// In en, this message translates to:
  /// **'Test text'**
  String get diagTestText;

  /// No description provided for @diagTestTextDefault.
  ///
  /// In en, this message translates to:
  /// **'Hello from Home Assistant!'**
  String get diagTestTextDefault;

  /// No description provided for @glasses.
  ///
  /// In en, this message translates to:
  /// **'Glasses'**
  String get glasses;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get languageGerman;

  /// No description provided for @languageSetting.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSetting;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System ({language})'**
  String languageSystem(String language);

  /// No description provided for @settingsAppUpdate.
  ///
  /// In en, this message translates to:
  /// **'App update'**
  String get settingsAppUpdate;

  /// No description provided for @settingsAppUpdateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Version and new versions from GitHub'**
  String get settingsAppUpdateSubtitle;

  /// No description provided for @settingsDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get settingsDiagnostics;

  /// No description provided for @settingsDiagnosticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Test text, check display, log'**
  String get settingsDiagnosticsSubtitle;

  /// No description provided for @settingsDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display & activation'**
  String get settingsDisplay;

  /// No description provided for @settingsDisplaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Activation angle, height, distance, Even dashboard'**
  String get settingsDisplaySubtitle;

  /// No description provided for @settingsNoGlassesPaired.
  ///
  /// In en, this message translates to:
  /// **'No glasses paired yet'**
  String get settingsNoGlassesPaired;

  /// No description provided for @settingsNotSetUp.
  ///
  /// In en, this message translates to:
  /// **'Not set up'**
  String get settingsNotSetUp;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsNotificationsOff.
  ///
  /// In en, this message translates to:
  /// **'Forwarding off'**
  String get settingsNotificationsOff;

  /// No description provided for @settingsNotificationsOn.
  ///
  /// In en, this message translates to:
  /// **'Phone notifications are forwarded'**
  String get settingsNotificationsOn;

  /// No description provided for @settingsPairGlasses.
  ///
  /// In en, this message translates to:
  /// **'Pair glasses'**
  String get settingsPairGlasses;

  /// No description provided for @settingsRecordings.
  ///
  /// In en, this message translates to:
  /// **'Recordings'**
  String get settingsRecordings;

  /// No description provided for @settingsWhisperNotSetUp.
  ///
  /// In en, this message translates to:
  /// **'WhisperNotes not set up'**
  String get settingsWhisperNotSetUp;

  /// No description provided for @uiAnswer.
  ///
  /// In en, this message translates to:
  /// **'Answer: {text}'**
  String uiAnswer(String text);

  /// No description provided for @uiAssistHint.
  ///
  /// In en, this message translates to:
  /// **'Hold the left touch bar, speak, release.'**
  String get uiAssistHint;

  /// No description provided for @uiAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant: {name}'**
  String uiAssistant(String name);

  /// No description provided for @uiBatteryCase.
  ///
  /// In en, this message translates to:
  /// **'Case'**
  String get uiBatteryCase;

  /// No description provided for @uiBatteryLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get uiBatteryLeft;

  /// No description provided for @uiBatteryRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get uiBatteryRight;

  /// No description provided for @uiBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get uiBrightness;

  /// No description provided for @uiBrightnessAutoHint.
  ///
  /// In en, this message translates to:
  /// **'The glasses set the brightness with their light sensor. The slider makes it brighter or darker.'**
  String get uiBrightnessAutoHint;

  /// No description provided for @uiBrightnessNow.
  ///
  /// In en, this message translates to:
  /// **' (currently {percent} %)'**
  String uiBrightnessNow(int percent);

  /// No description provided for @uiBrightnessOffsetEven.
  ///
  /// In en, this message translates to:
  /// **'About every two minutes, while nothing is shown, the app reads the light sensor and sets it {offset} %{current}.'**
  String uiBrightnessOffsetEven(String offset, String current);

  /// No description provided for @uiBrightnessOffsetScouter.
  ///
  /// In en, this message translates to:
  /// **'The light sensor reports whenever the brightness changes noticeably while something is shown; the app then sets {offset} % relative to the automatic level{current}.'**
  String uiBrightnessOffsetScouter(String offset, String current);

  /// No description provided for @uiConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get uiConnect;

  /// No description provided for @uiFirmware.
  ///
  /// In en, this message translates to:
  /// **'Firmware: {version}'**
  String uiFirmware(String version);

  /// No description provided for @uiGlassesNotPaired.
  ///
  /// In en, this message translates to:
  /// **'Not paired – see Settings'**
  String get uiGlassesNotPaired;

  /// No description provided for @uiHaNotSetUp.
  ///
  /// In en, this message translates to:
  /// **'Not set up – see Settings'**
  String get uiHaNotSetUp;

  /// No description provided for @uiListening.
  ///
  /// In en, this message translates to:
  /// **'Listening …'**
  String get uiListening;

  /// No description provided for @uiOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get uiOverview;

  /// No description provided for @uiPreferredAssistant.
  ///
  /// In en, this message translates to:
  /// **'preferred assistant'**
  String get uiPreferredAssistant;

  /// No description provided for @uiPreviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing shown by the app\n(the glasses may show their own screen)'**
  String get uiPreviewEmpty;

  /// No description provided for @uiPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Preview of the glasses display'**
  String get uiPreviewTitle;

  /// No description provided for @uiQuestion.
  ///
  /// In en, this message translates to:
  /// **'Question: {text}'**
  String uiQuestion(String text);

  /// No description provided for @uiRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get uiRecording;

  /// No description provided for @uiRecordingFlow.
  ///
  /// In en, this message translates to:
  /// **'Glasses microphone → WhisperNotes → BasaltNotes'**
  String get uiRecordingFlow;

  /// No description provided for @uiRecordingPending.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 recording not sent yet} other{{count} recordings not sent yet}}'**
  String uiRecordingPending(int count);

  /// No description provided for @uiRecordingRunning.
  ///
  /// In en, this message translates to:
  /// **'Running · {time}'**
  String uiRecordingRunning(String time);

  /// No description provided for @uiRecordingSetUp.
  ///
  /// In en, this message translates to:
  /// **'Enter WhisperNotes in the settings'**
  String get uiRecordingSetUp;

  /// No description provided for @uiRecordingUploading.
  ///
  /// In en, this message translates to:
  /// **'Sending to WhisperNotes …'**
  String get uiRecordingUploading;

  /// No description provided for @uiSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get uiSettings;

  /// No description provided for @uiSilentMode.
  ///
  /// In en, this message translates to:
  /// **'Silent mode'**
  String get uiSilentMode;

  /// No description provided for @uiSilentModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'No texts, notifications or dashboards. Assist keeps working.'**
  String get uiSilentModeSubtitle;

  /// No description provided for @uiStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get uiStart;

  /// No description provided for @uiStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get uiStop;

  /// No description provided for @uiWearCaseClosed.
  ///
  /// In en, this message translates to:
  /// **'In the case (lid closed)'**
  String get uiWearCaseClosed;

  /// No description provided for @uiWearCaseOpen.
  ///
  /// In en, this message translates to:
  /// **'In the case (lid open)'**
  String get uiWearCaseOpen;

  /// No description provided for @uiWearNotWorn.
  ///
  /// In en, this message translates to:
  /// **'Taken off'**
  String get uiWearNotWorn;

  /// No description provided for @uiWearWorn.
  ///
  /// In en, this message translates to:
  /// **'Worn'**
  String get uiWearWorn;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available'**
  String updateAvailable(String version);

  /// No description provided for @updateCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get updateCancel;

  /// No description provided for @updateChannel.
  ///
  /// In en, this message translates to:
  /// **'Update channel'**
  String get updateChannel;

  /// No description provided for @updateChannelPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get updateChannelPreview;

  /// No description provided for @updateChannelStable.
  ///
  /// In en, this message translates to:
  /// **'Stable'**
  String get updateChannelStable;

  /// No description provided for @updateCheck.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get updateCheck;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check for updates.'**
  String get updateCheckFailed;

  /// No description provided for @updateDailyCheck.
  ///
  /// In en, this message translates to:
  /// **'The app looks for new versions on GitHub once a day when it starts.'**
  String get updateDailyCheck;

  /// No description provided for @updateDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'The update could not be downloaded.'**
  String get updateDownloadFailed;

  /// No description provided for @updateInstall.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get updateInstall;

  /// No description provided for @updateInstallQuestion.
  ///
  /// In en, this message translates to:
  /// **'Download and install now? Your settings are kept.'**
  String get updateInstallQuestion;

  /// No description provided for @updateInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed: {version}'**
  String updateInstalled(String version);

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updatePreviewQuestion.
  ///
  /// In en, this message translates to:
  /// **'Install preview versions?'**
  String get updatePreviewQuestion;

  /// No description provided for @updatePreviewVersion.
  ///
  /// In en, this message translates to:
  /// **'Preview {version}'**
  String updatePreviewVersion(String version);

  /// No description provided for @updatePreviewWarning.
  ///
  /// In en, this message translates to:
  /// **'Preview versions are built with every change to the project and are tested less than the stable versions.\n\nYou get back to the stable channel with the next stable release. Android does not install older builds; otherwise only a reinstall helps.'**
  String get updatePreviewWarning;

  /// No description provided for @updateStableVersion.
  ///
  /// In en, this message translates to:
  /// **'Stable version {version}'**
  String updateStableVersion(String version);

  /// No description provided for @updateSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get updateSwitch;

  /// No description provided for @updateUpToDate.
  ///
  /// In en, this message translates to:
  /// **'The app is up to date.'**
  String get updateUpToDate;

  /// No description provided for @updateVersionUnknown.
  ///
  /// In en, this message translates to:
  /// **'Installed version unknown'**
  String get updateVersionUnknown;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
