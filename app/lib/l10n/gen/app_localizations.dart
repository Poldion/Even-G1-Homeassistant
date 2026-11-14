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

  /// No description provided for @coreDone.
  ///
  /// In en, this message translates to:
  /// **'Done.'**
  String get coreDone;

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

  /// No description provided for @coreLogNavigationEnd.
  ///
  /// In en, this message translates to:
  /// **'Navigation ended'**
  String get coreLogNavigationEnd;

  /// No description provided for @coreLogNavigationStart.
  ///
  /// In en, this message translates to:
  /// **'Navigation started'**
  String get coreLogNavigationStart;

  /// No description provided for @coreLogNavigationStep.
  ///
  /// In en, this message translates to:
  /// **'Navigation: {step}'**
  String coreLogNavigationStep(String step);

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

  /// No description provided for @coreRecordingLabel.
  ///
  /// In en, this message translates to:
  /// **'BasaltNotes is recording'**
  String get coreRecordingLabel;

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
  /// **'{assistant}\nOne moment …'**
  String coreThinking(String assistant);

  /// No description provided for @coreTimeout.
  ///
  /// In en, this message translates to:
  /// **'Timeout'**
  String get coreTimeout;

  /// No description provided for @coreTranscript.
  ///
  /// In en, this message translates to:
  /// **'{assistant}\n» {text} «\nOne moment …'**
  String coreTranscript(String assistant, String text);

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

  /// No description provided for @diagClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get diagClose;

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

  /// No description provided for @g1LogConnectionFast.
  ///
  /// In en, this message translates to:
  /// **'Connection: fast'**
  String get g1LogConnectionFast;

  /// No description provided for @g1LogConnectionSaving.
  ///
  /// In en, this message translates to:
  /// **'Connection: power saving'**
  String get g1LogConnectionSaving;

  /// No description provided for @g1LogWearState.
  ///
  /// In en, this message translates to:
  /// **'State: {state}'**
  String g1LogWearState(String state);

  /// No description provided for @g1StatusConnected.
  ///
  /// In en, this message translates to:
  /// **'connected'**
  String get g1StatusConnected;

  /// No description provided for @g1StatusConnecting.
  ///
  /// In en, this message translates to:
  /// **'connecting…'**
  String get g1StatusConnecting;

  /// No description provided for @g1StatusConnectingOne.
  ///
  /// In en, this message translates to:
  /// **'connecting ({side} ready)…'**
  String g1StatusConnectingOne(String side);

  /// No description provided for @g1StatusDisconnected.
  ///
  /// In en, this message translates to:
  /// **'disconnected'**
  String get g1StatusDisconnected;

  /// No description provided for @glasses.
  ///
  /// In en, this message translates to:
  /// **'Glasses'**
  String get glasses;

  /// No description provided for @glassesSetAngle.
  ///
  /// In en, this message translates to:
  /// **'Activation angle'**
  String get glassesSetAngle;

  /// No description provided for @glassesSetAngleHelp.
  ///
  /// In en, this message translates to:
  /// **'From this head tilt the glasses switch the display on when you look up.'**
  String get glassesSetAngleHelp;

  /// No description provided for @glassesSetArms.
  ///
  /// In en, this message translates to:
  /// **'Left: {left}\nRight: {right}'**
  String glassesSetArms(String left, String right);

  /// No description provided for @glassesSetGyroCheck.
  ///
  /// In en, this message translates to:
  /// **'Ignore jolts when looking up'**
  String get glassesSetGyroCheck;

  /// No description provided for @glassesSetGyroCheckHelp.
  ///
  /// In en, this message translates to:
  /// **'Only with head gestures: the dashboard comes only when the gyroscope saw your head turn, not when the car brakes or goes over a bump. A very slow look up may then not count.'**
  String get glassesSetGyroCheckHelp;

  /// No description provided for @glassesSetHeadGestures.
  ///
  /// In en, this message translates to:
  /// **'Head gestures'**
  String get glassesSetHeadGestures;

  /// No description provided for @glassesSetHeadGesturesHelp.
  ///
  /// In en, this message translates to:
  /// **'Nodding and shaking the head as gestures for Home Assistant. The gyroscope of the right arm then runs all the time and needs a bit more battery.'**
  String get glassesSetHeadGesturesHelp;

  /// No description provided for @glassesSetNonePaired.
  ///
  /// In en, this message translates to:
  /// **'No glasses paired yet.'**
  String get glassesSetNonePaired;

  /// No description provided for @glassesSetNotConnected.
  ///
  /// In en, this message translates to:
  /// **'The glasses are not connected. Changes are sent the next time they connect.'**
  String get glassesSetNotConnected;

  /// No description provided for @glassesSetNotSet.
  ///
  /// In en, this message translates to:
  /// **'not set'**
  String get glassesSetNotSet;

  /// No description provided for @glassesSetPaired.
  ///
  /// In en, this message translates to:
  /// **'Paired: {name}'**
  String glassesSetPaired(String name);

  /// No description provided for @glassesSetScouterHint.
  ///
  /// In en, this message translates to:
  /// **'ScouterKit (g1v0): For the first pairing put the glasses into the open charging case. Outside the case they obey only paired devices.'**
  String get glassesSetScouterHint;

  /// No description provided for @glassesSetSearch.
  ///
  /// In en, this message translates to:
  /// **'Search for glasses'**
  String get glassesSetSearch;

  /// No description provided for @glassesSetSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get glassesSetSearching;

  /// No description provided for @haSetConnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed: {error}'**
  String haSetConnectFailed(String error);

  /// No description provided for @haSetGlasses.
  ///
  /// In en, this message translates to:
  /// **'Glasses in Home Assistant'**
  String get haSetGlasses;

  /// No description provided for @haSetLoad.
  ///
  /// In en, this message translates to:
  /// **'Connect & load glasses from HA'**
  String get haSetLoad;

  /// No description provided for @haSetNoGlasses.
  ///
  /// In en, this message translates to:
  /// **'No glasses found in Home Assistant. Add the \"Even Realities G1\" integration first.'**
  String get haSetNoGlasses;

  /// No description provided for @haSetNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'The \"Even Realities G1\" integration is not installed in Home Assistant.'**
  String get haSetNotInstalled;

  /// No description provided for @haSetToken.
  ///
  /// In en, this message translates to:
  /// **'Long-lived access token'**
  String get haSetToken;

  /// No description provided for @haSetTokenHelp.
  ///
  /// In en, this message translates to:
  /// **'HA → Profile → Security → Create token'**
  String get haSetTokenHelp;

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

  /// No description provided for @notifSetAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get notifSetAllow;

  /// No description provided for @notifSetAndroidOnly.
  ///
  /// In en, this message translates to:
  /// **'Forwarding phone notifications is only available on Android.'**
  String get notifSetAndroidOnly;

  /// No description provided for @notifSetApps.
  ///
  /// In en, this message translates to:
  /// **'Apps whose notifications arrive:'**
  String get notifSetApps;

  /// No description provided for @notifSetForward.
  ///
  /// In en, this message translates to:
  /// **'Forward phone notifications'**
  String get notifSetForward;

  /// No description provided for @notifSetNavigation.
  ///
  /// In en, this message translates to:
  /// **'Google Maps navigation'**
  String get notifSetNavigation;

  /// No description provided for @notifSetNavigationHelp.
  ///
  /// In en, this message translates to:
  /// **'Arrow and distance on the glasses: at each new turn and at 500, 200 and 50 m; on head-up instead of the dashboard while you navigate.'**
  String get notifSetNavigationHelp;

  /// No description provided for @notifSetNoAccess.
  ///
  /// In en, this message translates to:
  /// **'Access to notifications missing'**
  String get notifSetNoAccess;

  /// No description provided for @notifSetNoAccessHelp.
  ///
  /// In en, this message translates to:
  /// **'Allow \"Even G1 HA\" to read notifications in the Android settings.\nIf Android reports \"App was denied access\": Settings → Apps → Even G1 HA → ⋮ → \"Allow restricted settings\", then tap Allow again.'**
  String get notifSetNoAccessHelp;

  /// No description provided for @notifSetNoApps.
  ///
  /// In en, this message translates to:
  /// **'Apps appear here once they have sent a notification. New apps are forwarded by default.'**
  String get notifSetNoApps;

  /// No description provided for @recSetIntro.
  ///
  /// In en, this message translates to:
  /// **'Recordings with the glasses microphone go to WhisperNotes, are transcribed and summarised there and end up in the BasaltNotes inbox if a default vault is chosen in WhisperNotes under Settings → BasaltNotes.'**
  String get recSetIntro;

  /// No description provided for @recSetKey.
  ///
  /// In en, this message translates to:
  /// **'API key (optional)'**
  String get recSetKey;

  /// No description provided for @recSetKeyHelp.
  ///
  /// In en, this message translates to:
  /// **'Only needed if one is set in WhisperNotes.'**
  String get recSetKeyHelp;

  /// No description provided for @recSetScouterDot.
  ///
  /// In en, this message translates to:
  /// **'During a recording ScouterKit itself shows a small square at the top right of the right eye while the microphone is on. It cannot be switched off.'**
  String get recSetScouterDot;

  /// No description provided for @recSetSendPending.
  ///
  /// In en, this message translates to:
  /// **'Send {count} pending'**
  String recSetSendPending(int count);

  /// No description provided for @recSetUrl.
  ///
  /// In en, this message translates to:
  /// **'WhisperNotes address'**
  String get recSetUrl;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

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
  /// **'Activation angle, head gestures'**
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

  /// No description provided for @skAnimSleepSubtitle.
  ///
  /// In en, this message translates to:
  /// **'see you soon'**
  String get skAnimSleepSubtitle;

  /// No description provided for @skAnimSleepTitle.
  ///
  /// In en, this message translates to:
  /// **'Silent mode'**
  String get skAnimSleepTitle;

  /// No description provided for @skAnimWakeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Silent mode off'**
  String get skAnimWakeSubtitle;

  /// No description provided for @skAnimWakeTitle.
  ///
  /// In en, this message translates to:
  /// **'I\'m back'**
  String get skAnimWakeTitle;

  /// No description provided for @skLabSleepSubtitle.
  ///
  /// In en, this message translates to:
  /// **'silent mode on'**
  String get skLabSleepSubtitle;

  /// No description provided for @skLabSleepTitle.
  ///
  /// In en, this message translates to:
  /// **'ENTERING STANDBY'**
  String get skLabSleepTitle;

  /// No description provided for @skLabWakeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'silent mode off'**
  String get skLabWakeSubtitle;

  /// No description provided for @skLabWakeTitle.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM ONLINE'**
  String get skLabWakeTitle;

  /// No description provided for @skLogAnimationOff.
  ///
  /// In en, this message translates to:
  /// **'Animation: silent mode off'**
  String get skLogAnimationOff;

  /// No description provided for @skLogAnimationOn.
  ///
  /// In en, this message translates to:
  /// **'Animation: silent mode on'**
  String get skLogAnimationOn;

  /// No description provided for @skLogArmLinked.
  ///
  /// In en, this message translates to:
  /// **'{arm} arm connected and set up in {ms} ms'**
  String skLogArmLinked(String arm, int ms);

  /// No description provided for @skLogArmLost.
  ///
  /// In en, this message translates to:
  /// **'{arm} arm lost the connection; the phone reconnects as soon as it is in reach'**
  String skLogArmLost(String arm);

  /// No description provided for @skLogArmReady.
  ///
  /// In en, this message translates to:
  /// **'{arm} arm ready (g1v0 {version})'**
  String skLogArmReady(String arm, String version);

  /// No description provided for @skLogArmReadyEncrypted.
  ///
  /// In en, this message translates to:
  /// **'{arm} arm ready (g1v0 {version}, encrypted)'**
  String skLogArmReadyEncrypted(String arm, String version);

  /// No description provided for @skLogAutoBrightness.
  ///
  /// In en, this message translates to:
  /// **'Auto brightness: {lux} lx, level {stock} {offset} → {level}'**
  String skLogAutoBrightness(int lux, int stock, String offset, int level);

  /// No description provided for @skLogBondFailed.
  ///
  /// In en, this message translates to:
  /// **'Pairing {arm}: {error}'**
  String skLogBondFailed(String arm, String error);

  /// No description provided for @skLogBonding.
  ///
  /// In en, this message translates to:
  /// **'{arm} arm is being paired (in the case)'**
  String skLogBonding(String arm);

  /// No description provided for @skLogDisplayError.
  ///
  /// In en, this message translates to:
  /// **'{arm}: display error at start'**
  String skLogDisplayError(String arm);

  /// No description provided for @skLogEmojiReset.
  ///
  /// In en, this message translates to:
  /// **'Emoji slots full: starting over'**
  String get skLogEmojiReset;

  /// No description provided for @skLogEncrypted.
  ///
  /// In en, this message translates to:
  /// **'{arm}: connection encrypted'**
  String skLogEncrypted(String arm);

  /// No description provided for @skLogEventsRejected.
  ///
  /// In en, this message translates to:
  /// **'{arm}: EVENTS rejected'**
  String skLogEventsRejected(String arm);

  /// No description provided for @skLogFontLoaded.
  ///
  /// In en, this message translates to:
  /// **'{arm}: font loaded ({bytes} B, {ms} ms)'**
  String skLogFontLoaded(String arm, int bytes, int ms);

  /// No description provided for @skLogInCase.
  ///
  /// In en, this message translates to:
  /// **'Glasses in the charging case – display stays off (disturbs charging)'**
  String get skLogInCase;

  /// No description provided for @skLogLight.
  ///
  /// In en, this message translates to:
  /// **'Light {lux} lux → brightness level {level}'**
  String skLogLight(String lux, String level);

  /// No description provided for @skLogMic.
  ///
  /// In en, this message translates to:
  /// **'Microphone: {error}'**
  String skLogMic(String error);

  /// No description provided for @skLogMicNeedsEncryption.
  ///
  /// In en, this message translates to:
  /// **'The microphone needs an encrypted (paired) connection'**
  String get skLogMicNeedsEncryption;

  /// No description provided for @skLogMicStopped.
  ///
  /// In en, this message translates to:
  /// **'{arm}: microphone stopped by the glasses ({reason})'**
  String skLogMicStopped(String arm, int reason);

  /// No description provided for @skLogMtuRetry.
  ///
  /// In en, this message translates to:
  /// **'{arm} arm: no answer to the packet size, asking again'**
  String skLogMtuRetry(String arm);

  /// No description provided for @skLogNewSession.
  ///
  /// In en, this message translates to:
  /// **'{arm} arm: new session (restart?), setting up again'**
  String skLogNewSession(String arm);

  /// No description provided for @skLogNoAnswerNotBonded.
  ///
  /// In en, this message translates to:
  /// **'{arm} arm does not answer and is not paired: put the glasses into the open charging case to pair them'**
  String skLogNoAnswerNotBonded(String arm);

  /// No description provided for @skLogNoService.
  ///
  /// In en, this message translates to:
  /// **'{arm} arm: no ScouterKit service – is g1v0 running on this arm?'**
  String skLogNoService(String arm);

  /// No description provided for @skLogNotBonded.
  ///
  /// In en, this message translates to:
  /// **'{arm} arm not paired – put it into the open charging case to pair'**
  String skLogNotBonded(String arm);

  /// No description provided for @skLogOffsetOnArms.
  ///
  /// In en, this message translates to:
  /// **'Automatic brightness {offset} on the glasses'**
  String skLogOffsetOnArms(String offset);

  /// No description provided for @skLogOtherArm.
  ///
  /// In en, this message translates to:
  /// **'{arm} arm reports as the other arm'**
  String skLogOtherArm(String arm);

  /// No description provided for @skLogPacketError.
  ///
  /// In en, this message translates to:
  /// **'{arm}: error in packet {seq}: {error} (op 0x{op}, detail {detail})'**
  String skLogPacketError(
    String arm,
    int seq,
    String error,
    String op,
    int detail,
  );

  /// No description provided for @skLogProgramHalted.
  ///
  /// In en, this message translates to:
  /// **'{arm}: program halted: {error} (0x{address}, op 0x{op})'**
  String skLogProgramHalted(
    String arm,
    String error,
    String address,
    String op,
  );

  /// No description provided for @skLogProgramNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'{arm}: program not loaded'**
  String skLogProgramNotLoaded(String arm);

  /// No description provided for @skLogProgramRunning.
  ///
  /// In en, this message translates to:
  /// **'{arm}: program running ({bytes} B)'**
  String skLogProgramRunning(String arm, int bytes);

  /// No description provided for @skLogProgramRunningGestures.
  ///
  /// In en, this message translates to:
  /// **'{arm}: program running ({bytes} B, head gestures)'**
  String skLogProgramRunningGestures(String arm, int bytes);

  /// No description provided for @skLogProgramStopped.
  ///
  /// In en, this message translates to:
  /// **'{arm}: program stopped'**
  String skLogProgramStopped(String arm);

  /// No description provided for @skLogProtocol.
  ///
  /// In en, this message translates to:
  /// **'{arm} arm speaks protocol {protocol}, the app needs 5'**
  String skLogProtocol(String arm, int protocol);

  /// No description provided for @skLogResetupFailed.
  ///
  /// In en, this message translates to:
  /// **'Setting up {arm} again: {error}'**
  String skLogResetupFailed(String arm, String error);

  /// No description provided for @skLogSafeMode.
  ///
  /// In en, this message translates to:
  /// **'{arm} arm in safe mode (after start errors): no display'**
  String skLogSafeMode(String arm);

  /// No description provided for @skLogVideo.
  ///
  /// In en, this message translates to:
  /// **'Video: {width}×{height}, {fps} frames/s'**
  String skLogVideo(String width, String height, String fps);

  /// No description provided for @skLogVideoEnd.
  ///
  /// In en, this message translates to:
  /// **'Video ended: {end}'**
  String skLogVideoEnd(String end);

  /// No description provided for @skLogVmStartRejected.
  ///
  /// In en, this message translates to:
  /// **'{arm}: VM_START rejected'**
  String skLogVmStartRejected(String arm);

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

  /// No description provided for @uiBrightnessLog.
  ///
  /// In en, this message translates to:
  /// **'Even curve (logarithmic)'**
  String get uiBrightnessLog;

  /// No description provided for @uiBrightnessLogHint.
  ///
  /// In en, this message translates to:
  /// **'Every tenfold change of the light gives the same step in brightness, close to how the eye sees it. Off: the original curve of the glasses.'**
  String get uiBrightnessLogHint;

  /// No description provided for @uiBrightnessNow.
  ///
  /// In en, this message translates to:
  /// **' (currently {percent} %)'**
  String uiBrightnessNow(int percent);

  /// No description provided for @uiBrightnessOffsetScouter.
  ///
  /// In en, this message translates to:
  /// **'The glasses set {offset} % relative to the automatic level{current}.'**
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
  /// **'Beta'**
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

  /// No description provided for @updateEvenNoticeBody.
  ///
  /// In en, this message translates to:
  /// **'Since 0.25.0 the app works only with glasses that run the ScouterKit firmware. Your glasses were paired with Even\'s firmware, which is no longer supported.\n\nWith Even\'s firmware, install 0.24.x, the last version for it, from the releases page. Android installs an older version only after uninstalling this one; your settings are lost then.'**
  String get updateEvenNoticeBody;

  /// No description provided for @updateEvenNoticeScouterKit.
  ///
  /// In en, this message translates to:
  /// **'I use ScouterKit'**
  String get updateEvenNoticeScouterKit;

  /// No description provided for @updateEvenNoticeTitle.
  ///
  /// In en, this message translates to:
  /// **'This version needs ScouterKit'**
  String get updateEvenNoticeTitle;

  /// No description provided for @updateHeldBackBody.
  ///
  /// In en, this message translates to:
  /// **'Version {version} and later support only glasses with the ScouterKit firmware. Your glasses run Even\'s firmware, so this app stays on its current version, which keeps working.\n\nSupport for Even\'s firmware is no longer developed (branch \"legacy\" on GitHub). If you switch to ScouterKit, choose it under Settings → Glasses; then updates are offered again.'**
  String updateHeldBackBody(String version);

  /// No description provided for @updateHeldBackOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get updateHeldBackOk;

  /// No description provided for @updateHeldBackTitle.
  ///
  /// In en, this message translates to:
  /// **'No more updates for Even\'s firmware'**
  String get updateHeldBackTitle;

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
  /// **'Install beta builds?'**
  String get updatePreviewQuestion;

  /// No description provided for @updatePreviewVersion.
  ///
  /// In en, this message translates to:
  /// **'Beta build {version}'**
  String updatePreviewVersion(String version);

  /// No description provided for @updatePreviewWarning.
  ///
  /// In en, this message translates to:
  /// **'Beta builds are built with every change to the project and are tested less than the stable versions.\n\nYou get back to the stable channel with the next stable release. Android does not install older builds; otherwise only a reinstall helps.'**
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

  /// No description provided for @videoDone.
  ///
  /// In en, this message translates to:
  /// **'Done.'**
  String get videoDone;

  /// No description provided for @videoFailed.
  ///
  /// In en, this message translates to:
  /// **'The glasses could not play the video. Their ScouterKit firmware may be too old for videos.'**
  String get videoFailed;

  /// No description provided for @videoInfo.
  ///
  /// In en, this message translates to:
  /// **'{width} × {height} px · {fps} frames/s · {duration}'**
  String videoInfo(String width, String height, String fps, String duration);

  /// No description provided for @videoIntro.
  ///
  /// In en, this message translates to:
  /// **'Plays a video from your phone on both eyes, in black and white; the sound comes from the phone. Videos with strong contrast work best, such as shadow animations.'**
  String get videoIntro;

  /// No description provided for @videoInvert.
  ///
  /// In en, this message translates to:
  /// **'Invert (a light background stays dark)'**
  String get videoInvert;

  /// No description provided for @videoNone.
  ///
  /// In en, this message translates to:
  /// **'No video chosen'**
  String get videoNone;

  /// No description provided for @videoNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Connect the glasses first.'**
  String get videoNotConnected;

  /// No description provided for @videoOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'This video cannot be opened.'**
  String get videoOpenFailed;

  /// No description provided for @videoPick.
  ///
  /// In en, this message translates to:
  /// **'Choose video'**
  String get videoPick;

  /// No description provided for @videoPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get videoPlay;

  /// No description provided for @videoProgress.
  ///
  /// In en, this message translates to:
  /// **'{time} / {total} · {skipped} frames skipped'**
  String videoProgress(String time, String total, String skipped);

  /// No description provided for @videoStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get videoStop;

  /// No description provided for @videoTitle.
  ///
  /// In en, this message translates to:
  /// **'Video on the glasses'**
  String get videoTitle;

  /// No description provided for @videoUnlocked.
  ///
  /// In en, this message translates to:
  /// **'You found the video player.'**
  String get videoUnlocked;
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
