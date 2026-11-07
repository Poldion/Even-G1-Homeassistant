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

  /// No description provided for @coreAssistNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'No answer'**
  String get coreAssistNoAnswer;

  /// No description provided for @coreAssistUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Assist not available:\n{error}'**
  String coreAssistUnavailable(String error);

  /// No description provided for @coreCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get coreCancelled;

  /// No description provided for @coreChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Keeps the connection to the glasses in the background'**
  String get coreChannelDescription;

  /// No description provided for @coreChannelName.
  ///
  /// In en, this message translates to:
  /// **'Even G1 connection'**
  String get coreChannelName;

  /// No description provided for @coreDisplayCheck.
  ///
  /// In en, this message translates to:
  /// **'Display left: {left}, right: {right}'**
  String coreDisplayCheck(String left, String right);

  /// No description provided for @coreDisplayCheckDiffers.
  ///
  /// In en, this message translates to:
  /// **'{text} – DIFFERENT'**
  String coreDisplayCheckDiffers(String text);

  /// No description provided for @coreDone.
  ///
  /// In en, this message translates to:
  /// **'Done.'**
  String get coreDone;

  /// No description provided for @coreGlassesNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Glasses not connected'**
  String get coreGlassesNotConnected;

  /// No description provided for @coreHaConnected.
  ///
  /// In en, this message translates to:
  /// **'connected (HA {version})'**
  String coreHaConnected(String version);

  /// No description provided for @coreHaConnecting.
  ///
  /// In en, this message translates to:
  /// **'connecting…'**
  String get coreHaConnecting;

  /// No description provided for @coreHaConnectionLost.
  ///
  /// In en, this message translates to:
  /// **'Connection to Home Assistant lost'**
  String get coreHaConnectionLost;

  /// No description provided for @coreHaDisconnected.
  ///
  /// In en, this message translates to:
  /// **'disconnected'**
  String get coreHaDisconnected;

  /// No description provided for @coreHaNotSetUp.
  ///
  /// In en, this message translates to:
  /// **'not set up'**
  String get coreHaNotSetUp;

  /// No description provided for @coreHaRetry.
  ///
  /// In en, this message translates to:
  /// **'disconnected, retrying in {seconds}s'**
  String coreHaRetry(int seconds);

  /// No description provided for @coreHaTokenInvalid.
  ///
  /// In en, this message translates to:
  /// **'Token invalid'**
  String get coreHaTokenInvalid;

  /// No description provided for @coreListening.
  ///
  /// In en, this message translates to:
  /// **'{assistant}\nis listening …'**
  String coreListening(String assistant);

  /// No description provided for @coreLogAnswer.
  ///
  /// In en, this message translates to:
  /// **'Answer: {text}'**
  String coreLogAnswer(String text);

  /// No description provided for @coreLogAssistError.
  ///
  /// In en, this message translates to:
  /// **'Assist error: {error}'**
  String coreLogAssistError(String error);

  /// No description provided for @coreLogAssistStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Assist start failed: {error}'**
  String coreLogAssistStartFailed(String error);

  /// No description provided for @coreLogAssistStarted.
  ///
  /// In en, this message translates to:
  /// **'Assist started'**
  String get coreLogAssistStarted;

  /// No description provided for @coreLogAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio: {error}'**
  String coreLogAudio(String error);

  /// No description provided for @coreLogBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness: {percent} %'**
  String coreLogBrightness(int percent);

  /// No description provided for @coreLogBrightnessAuto.
  ///
  /// In en, this message translates to:
  /// **'Brightness: automatic'**
  String get coreLogBrightnessAuto;

  /// No description provided for @coreLogBrightnessOffset.
  ///
  /// In en, this message translates to:
  /// **'Brightness: automatic, {offset} %'**
  String coreLogBrightnessOffset(String offset);

  /// No description provided for @coreLogConfig.
  ///
  /// In en, this message translates to:
  /// **'Configuration received ({name})'**
  String coreLogConfig(String name);

  /// No description provided for @coreLogDashboardTap.
  ///
  /// In en, this message translates to:
  /// **'Dashboard (tap)'**
  String get coreLogDashboardTap;

  /// No description provided for @coreLogEvenAiOff.
  ///
  /// In en, this message translates to:
  /// **'Answers in text mode'**
  String get coreLogEvenAiOff;

  /// No description provided for @coreLogEvenAiOn.
  ///
  /// In en, this message translates to:
  /// **'Answers in Even AI mode'**
  String get coreLogEvenAiOn;

  /// No description provided for @coreLogHeadGesturesOff.
  ///
  /// In en, this message translates to:
  /// **'Head gestures off'**
  String get coreLogHeadGesturesOff;

  /// No description provided for @coreLogHeadGesturesOn.
  ///
  /// In en, this message translates to:
  /// **'Head gestures on'**
  String get coreLogHeadGesturesOn;

  /// No description provided for @coreLogHeadUpAngle.
  ///
  /// In en, this message translates to:
  /// **'Activation angle: {angle}°'**
  String coreLogHeadUpAngle(int angle);

  /// No description provided for @coreLogHeadUpHide.
  ///
  /// In en, this message translates to:
  /// **'Head up: hide Even dashboard'**
  String get coreLogHeadUpHide;

  /// No description provided for @coreLogHeadUpShow.
  ///
  /// In en, this message translates to:
  /// **'Head up: show Even dashboard'**
  String get coreLogHeadUpShow;

  /// No description provided for @coreLogIntegrationReloaded.
  ///
  /// In en, this message translates to:
  /// **'Integration reloaded, reconnecting'**
  String get coreLogIntegrationReloaded;

  /// No description provided for @coreLogMicFailed.
  ///
  /// In en, this message translates to:
  /// **'Microphone could not be switched on'**
  String get coreLogMicFailed;

  /// No description provided for @coreLogNotification.
  ///
  /// In en, this message translates to:
  /// **'Notification: {app} – {title}'**
  String coreLogNotification(String app, String title);

  /// No description provided for @coreLogNotificationsError.
  ///
  /// In en, this message translates to:
  /// **'Notifications: {error}'**
  String coreLogNotificationsError(String error);

  /// No description provided for @coreLogPosition.
  ///
  /// In en, this message translates to:
  /// **'Display position: height {height}, distance {depth}'**
  String coreLogPosition(int height, int depth);

  /// No description provided for @coreLogPositionPreview.
  ///
  /// In en, this message translates to:
  /// **'Display position: height {height}, distance {depth} (preview)'**
  String coreLogPositionPreview(int height, int depth);

  /// No description provided for @coreLogRecognized.
  ///
  /// In en, this message translates to:
  /// **'Recognized: {text}'**
  String coreLogRecognized(String text);

  /// No description provided for @coreLogRecordingError.
  ///
  /// In en, this message translates to:
  /// **'Recording: {error}'**
  String coreLogRecordingError(String error);

  /// No description provided for @coreLogRecordingMicRestarted.
  ///
  /// In en, this message translates to:
  /// **'Recording: microphone restarted'**
  String get coreLogRecordingMicRestarted;

  /// No description provided for @coreLogRecordingNoGlasses.
  ///
  /// In en, this message translates to:
  /// **'Recording: glasses not connected, microphone follows'**
  String get coreLogRecordingNoGlasses;

  /// No description provided for @coreLogRecordingNotSent.
  ///
  /// In en, this message translates to:
  /// **'Recording not sent: {error}'**
  String coreLogRecordingNotSent(String error);

  /// No description provided for @coreLogRecordingSent.
  ///
  /// In en, this message translates to:
  /// **'Recording sent: {name}'**
  String coreLogRecordingSent(String name);

  /// No description provided for @coreLogRecordingStarted.
  ///
  /// In en, this message translates to:
  /// **'Recording started'**
  String get coreLogRecordingStarted;

  /// No description provided for @coreLogRecordingStopped.
  ///
  /// In en, this message translates to:
  /// **'Recording stopped: {length} (duration {duration})'**
  String coreLogRecordingStopped(String length, String duration);

  /// No description provided for @coreLogRecordingTooShort.
  ///
  /// In en, this message translates to:
  /// **'Recording discarded (too short)'**
  String get coreLogRecordingTooShort;

  /// No description provided for @coreLogShowText.
  ///
  /// In en, this message translates to:
  /// **'Display: {text}'**
  String coreLogShowText(String text);

  /// No description provided for @coreLogSilentDashboardSkipped.
  ///
  /// In en, this message translates to:
  /// **'Silent mode – dashboard not shown'**
  String get coreLogSilentDashboardSkipped;

  /// No description provided for @coreLogSilentNoGlasses.
  ///
  /// In en, this message translates to:
  /// **'Silent mode: glasses not connected'**
  String get coreLogSilentNoGlasses;

  /// No description provided for @coreLogSilentOff.
  ///
  /// In en, this message translates to:
  /// **'Silent mode off'**
  String get coreLogSilentOff;

  /// No description provided for @coreLogSilentOffGlasses.
  ///
  /// In en, this message translates to:
  /// **'Silent mode off (glasses)'**
  String get coreLogSilentOffGlasses;

  /// No description provided for @coreLogSilentOn.
  ///
  /// In en, this message translates to:
  /// **'Silent mode on'**
  String get coreLogSilentOn;

  /// No description provided for @coreLogSilentOnGlasses.
  ///
  /// In en, this message translates to:
  /// **'Silent mode on (glasses)'**
  String get coreLogSilentOnGlasses;

  /// No description provided for @coreLogSilentTextSkipped.
  ///
  /// In en, this message translates to:
  /// **'Silent mode – text not shown'**
  String get coreLogSilentTextSkipped;

  /// No description provided for @coreLogTextDropped.
  ///
  /// In en, this message translates to:
  /// **'Glasses not connected – text dropped'**
  String get coreLogTextDropped;

  /// No description provided for @coreLogWearOff.
  ///
  /// In en, this message translates to:
  /// **'Wear detection off'**
  String get coreLogWearOff;

  /// No description provided for @coreLogWearOn.
  ///
  /// In en, this message translates to:
  /// **'Wear detection on'**
  String get coreLogWearOn;

  /// No description provided for @coreNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'no answer'**
  String get coreNoAnswer;

  /// No description provided for @coreNoHaConnection.
  ///
  /// In en, this message translates to:
  /// **'No connection to Home Assistant'**
  String get coreNoHaConnection;

  /// No description provided for @coreRecordingFileName.
  ///
  /// In en, this message translates to:
  /// **'Glasses note'**
  String get coreRecordingFileName;

  /// No description provided for @coreServiceText.
  ///
  /// In en, this message translates to:
  /// **'Connection active'**
  String get coreServiceText;

  /// No description provided for @coreSttFailed.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition failed.'**
  String get coreSttFailed;

  /// No description provided for @coreSttMissing.
  ///
  /// In en, this message translates to:
  /// **'No speech recognition configured in the Assist pipeline.'**
  String get coreSttMissing;

  /// No description provided for @coreSttNothing.
  ///
  /// In en, this message translates to:
  /// **'I didn\'t catch that.'**
  String get coreSttNothing;

  /// No description provided for @coreThinking.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant\nOne moment …'**
  String get coreThinking;

  /// No description provided for @coreTimeout.
  ///
  /// In en, this message translates to:
  /// **'Timeout'**
  String get coreTimeout;

  /// No description provided for @coreTranscript.
  ///
  /// In en, this message translates to:
  /// **'» {text} «\nOne moment …'**
  String coreTranscript(String text);

  /// No description provided for @coreUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get coreUnknownError;

  /// No description provided for @coreWhisperFailed.
  ///
  /// In en, this message translates to:
  /// **'Sending failed: {error}'**
  String coreWhisperFailed(String error);

  /// No description provided for @coreWhisperNotSetUp.
  ///
  /// In en, this message translates to:
  /// **'WhisperNotes is not set up'**
  String get coreWhisperNotSetUp;

  /// No description provided for @coreWhisperSent.
  ///
  /// In en, this message translates to:
  /// **'Sent to WhisperNotes (job {job})'**
  String coreWhisperSent(String job);

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
