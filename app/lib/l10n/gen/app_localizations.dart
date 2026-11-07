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

  /// No description provided for @glassesSetDepth.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get glassesSetDepth;

  /// No description provided for @glassesSetDepthHelp.
  ///
  /// In en, this message translates to:
  /// **'How far away the text appears.'**
  String get glassesSetDepthHelp;

  /// No description provided for @glassesSetEvenHint.
  ///
  /// In en, this message translates to:
  /// **'The official Even app must be closed, as the glasses connect to only one app at a time.'**
  String get glassesSetEvenHint;

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

  /// No description provided for @glassesSetHeadUpMode.
  ///
  /// In en, this message translates to:
  /// **'Even dashboard when looking up'**
  String get glassesSetHeadUpMode;

  /// No description provided for @glassesSetHeadUpModeHelp.
  ///
  /// In en, this message translates to:
  /// **'\"Hide\": when looking up only the Home Assistant dashboard appears (if set up in HA).'**
  String get glassesSetHeadUpModeHelp;

  /// No description provided for @glassesSetHeight.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get glassesSetHeight;

  /// No description provided for @glassesSetHeightHelp.
  ///
  /// In en, this message translates to:
  /// **'How high the text sits in your field of view. When you let go, the glasses briefly show the new position and apply it.'**
  String get glassesSetHeightHelp;

  /// No description provided for @glassesSetHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get glassesSetHide;

  /// No description provided for @glassesSetLeaveUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Leave unchanged'**
  String get glassesSetLeaveUnchanged;

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

  /// No description provided for @glassesSetRestartNote.
  ///
  /// In en, this message translates to:
  /// **'Please close and reopen the app, then search for the glasses.'**
  String get glassesSetRestartNote;

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

  /// No description provided for @glassesSetShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get glassesSetShow;

  /// No description provided for @glassesSetWear.
  ///
  /// In en, this message translates to:
  /// **'Wear detection'**
  String get glassesSetWear;

  /// No description provided for @glassesSetWearHelp.
  ///
  /// In en, this message translates to:
  /// **'The glasses report whether they are worn (also to Home Assistant: \"Worn\").'**
  String get glassesSetWearHelp;

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

  /// No description provided for @recSetDot.
  ///
  /// In en, this message translates to:
  /// **'Dot on the glasses'**
  String get recSetDot;

  /// No description provided for @recSetDotHelp.
  ///
  /// In en, this message translates to:
  /// **'Small dot at the top right while recording and nothing else is shown.'**
  String get recSetDotHelp;

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
