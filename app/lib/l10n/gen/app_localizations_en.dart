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
  String get glassesSetDepth => 'Distance';

  @override
  String get glassesSetDepthHelp => 'How far away the text appears.';

  @override
  String get glassesSetEvenHint =>
      'The official Even app must be closed, as the glasses connect to only one app at a time.';

  @override
  String get glassesSetHeadGestures => 'Head gestures';

  @override
  String get glassesSetHeadGesturesHelp =>
      'Nodding and shaking the head as gestures for Home Assistant. The gyroscope of the right arm then runs all the time and needs a bit more battery.';

  @override
  String get glassesSetHeadUpMode => 'Even dashboard when looking up';

  @override
  String get glassesSetHeadUpModeHelp =>
      '\"Hide\": when looking up only the Home Assistant dashboard appears (if set up in HA).';

  @override
  String get glassesSetHeight => 'Height';

  @override
  String get glassesSetHeightHelp =>
      'How high the text sits in your field of view. When you let go, the glasses briefly show the new position and apply it.';

  @override
  String get glassesSetHide => 'Hide';

  @override
  String get glassesSetLeaveUnchanged => 'Leave unchanged';

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
  String get glassesSetRestartNote =>
      'Please close and reopen the app, then search for the glasses.';

  @override
  String get glassesSetScouterHint =>
      'ScouterKit (g1v0): For the first pairing put the glasses into the open charging case. Outside the case they obey only paired devices.';

  @override
  String get glassesSetSearch => 'Search for glasses';

  @override
  String get glassesSetSearching => 'Searching…';

  @override
  String get glassesSetShow => 'Show';

  @override
  String get glassesSetWear => 'Wear detection';

  @override
  String get glassesSetWearHelp =>
      'The glasses report whether they are worn (also to Home Assistant: \"Worn\").';

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
  String get notifSetNoAccess => 'Access to notifications missing';

  @override
  String get notifSetNoAccessHelp =>
      'Allow \"Even G1 HA\" to read notifications in the Android settings.\nIf Android reports \"App was denied access\": Settings → Apps → Even G1 HA → ⋮ → \"Allow restricted settings\", then tap Allow again.';

  @override
  String get notifSetNoApps =>
      'Apps appear here once they have sent a notification. New apps are forwarded by default.';

  @override
  String get recSetDot => 'Dot on the glasses';

  @override
  String get recSetDotHelp =>
      'Small dot at the top right while recording and nothing else is shown.';

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
