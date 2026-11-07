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

  /// No description provided for @g1LogAutoBrightness.
  ///
  /// In en, this message translates to:
  /// **'Auto brightness: sensor {sensor} %, set {level} %'**
  String g1LogAutoBrightness(int sensor, int level);

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

  /// No description provided for @g1LogDisplayMissingLeft.
  ///
  /// In en, this message translates to:
  /// **'Left display was missing ({screen}) – sent again'**
  String g1LogDisplayMissingLeft(String screen);

  /// No description provided for @g1LogDisplayMissingRight.
  ///
  /// In en, this message translates to:
  /// **'Right display was missing ({screen}) – sent again'**
  String g1LogDisplayMissingRight(String screen);

  /// No description provided for @g1LogLeftNoAcks.
  ///
  /// In en, this message translates to:
  /// **'L does not confirm texts – check off'**
  String get g1LogLeftNoAcks;

  /// No description provided for @g1LogLeftNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'L: text not confirmed'**
  String get g1LogLeftNotConfirmed;

  /// No description provided for @g1LogLeftRejected.
  ///
  /// In en, this message translates to:
  /// **'L: text rejected – sent again'**
  String get g1LogLeftRejected;

  /// No description provided for @g1LogLeftUnanswered.
  ///
  /// In en, this message translates to:
  /// **'L: text unanswered – sent again'**
  String get g1LogLeftUnanswered;

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

  /// No description provided for @skLogEncrypted.
  ///
  /// In en, this message translates to:
  /// **'{arm}: connection encrypted'**
  String skLogEncrypted(String arm);

  /// No description provided for @skLogEvenCommandSkipped.
  ///
  /// In en, this message translates to:
  /// **'Even command to g1v0 skipped'**
  String get skLogEvenCommandSkipped;

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

  /// No description provided for @skLogVmStartRejected.
  ///
  /// In en, this message translates to:
  /// **'{arm}: VM_START rejected'**
  String skLogVmStartRejected(String arm);
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
