// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Even G1 für Home Assistant';

  @override
  String get glasses => 'Brille';

  @override
  String get glassesSetAngle => 'Aktivierungswinkel';

  @override
  String get glassesSetAngleHelp =>
      'Ab dieser Kopfneigung schaltet die Brille beim Hochschauen die Anzeige ein.';

  @override
  String glassesSetArms(String left, String right) {
    return 'Links: $left\nRechts: $right';
  }

  @override
  String get glassesSetDepth => 'Distanz';

  @override
  String get glassesSetDepthHelp => 'Wie weit entfernt der Text wirkt.';

  @override
  String get glassesSetEvenHint =>
      'Die offizielle Even-App muss geschlossen sein, da sich die Brille nur mit einer App gleichzeitig verbindet.';

  @override
  String get glassesSetHeadGestures => 'Kopfgesten';

  @override
  String get glassesSetHeadGesturesHelp =>
      'Nicken und Kopfschütteln als Gesten für Home Assistant. Der Gyrosensor des rechten Bügels läuft dann ständig und braucht etwas mehr Akku.';

  @override
  String get glassesSetHeadUpMode => 'Even-Dashboard beim Hochschauen';

  @override
  String get glassesSetHeadUpModeHelp =>
      '„Ausblenden“: Beim Hochschauen erscheint nur das Home-Assistant-Dashboard (falls in HA eingestellt).';

  @override
  String get glassesSetHeight => 'Höhe';

  @override
  String get glassesSetHeightHelp =>
      'Wie hoch der Text im Sichtfeld steht. Beim Loslassen zeigt die Brille die neue Position kurz an und übernimmt sie.';

  @override
  String get glassesSetHide => 'Ausblenden';

  @override
  String get glassesSetLeaveUnchanged => 'Unverändert lassen';

  @override
  String get glassesSetNonePaired => 'Noch keine Brille gekoppelt.';

  @override
  String get glassesSetNotConnected =>
      'Die Brille ist nicht verbunden. Änderungen werden beim nächsten Verbinden übertragen.';

  @override
  String get glassesSetNotSet => 'nicht gesetzt';

  @override
  String glassesSetPaired(String name) {
    return 'Gekoppelt: $name';
  }

  @override
  String get glassesSetRestartNote =>
      'Bitte die App schließen und neu öffnen, dann nach der Brille suchen.';

  @override
  String get glassesSetScouterHint =>
      'ScouterKit (g1v0): Zum ersten Koppeln die Brille ins offene Ladeetui legen. Außerhalb des Etuis gehorcht sie nur gekoppelten Geräten.';

  @override
  String get glassesSetSearch => 'Nach Brillen suchen';

  @override
  String get glassesSetSearching => 'Suche…';

  @override
  String get glassesSetShow => 'Anzeigen';

  @override
  String get glassesSetWear => 'Trageerkennung';

  @override
  String get glassesSetWearHelp =>
      'Die Brille meldet, ob sie getragen wird (auch an Home Assistant: „Getragen“).';

  @override
  String haSetConnectFailed(String error) {
    return 'Verbindung fehlgeschlagen: $error';
  }

  @override
  String get haSetGlasses => 'Brille in Home Assistant';

  @override
  String get haSetLoad => 'Verbinden & Brillen aus HA laden';

  @override
  String get haSetNoGlasses =>
      'Keine Brille in Home Assistant gefunden. Füge zuerst die Integration \"Even Realities G1\" hinzu.';

  @override
  String get haSetNotInstalled =>
      'Die Integration \"Even Realities G1\" ist in Home Assistant nicht installiert.';

  @override
  String get haSetToken => 'Langlebiges Zugriffstoken';

  @override
  String get haSetTokenHelp => 'HA → Profil → Sicherheit → Token erstellen';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageSetting => 'Sprache';

  @override
  String languageSystem(String language) {
    return 'System ($language)';
  }

  @override
  String get notifSetAllow => 'Erlauben';

  @override
  String get notifSetAndroidOnly =>
      'Das Weiterleiten von Handy-Benachrichtigungen ist nur unter Android verfügbar.';

  @override
  String get notifSetApps => 'Apps, deren Benachrichtigungen ankommen:';

  @override
  String get notifSetForward => 'Handy-Benachrichtigungen weiterleiten';

  @override
  String get notifSetNoAccess => 'Zugriff auf Benachrichtigungen fehlt';

  @override
  String get notifSetNoAccessHelp =>
      'Erlaube „Even G1 HA“ in den Android-Einstellungen, Benachrichtigungen zu lesen.\nMeldet Android „App wurde Zugriff verweigert“: Einstellungen → Apps → Even G1 HA → ⋮ → „Eingeschränkte Einstellungen zulassen“, dann erneut auf Erlauben tippen.';

  @override
  String get notifSetNoApps =>
      'Apps erscheinen hier, sobald sie eine Benachrichtigung gesendet haben. Neue Apps werden standardmäßig weitergeleitet.';

  @override
  String get recSetDot => 'Punkt auf der Brille';

  @override
  String get recSetDotHelp =>
      'Kleiner Punkt oben rechts, solange aufgenommen wird und nichts anderes angezeigt wird.';

  @override
  String get recSetIntro =>
      'Aufnahmen mit dem Brillen-Mikrofon gehen an WhisperNotes, werden dort transkribiert und zusammengefasst und landen im Eingang von BasaltNotes, wenn in WhisperNotes unter Einstellungen → BasaltNotes ein Standard-Vault gewählt ist.';

  @override
  String get recSetKey => 'API-Schlüssel (optional)';

  @override
  String get recSetKeyHelp =>
      'Nur nötig, wenn in WhisperNotes einer gesetzt ist.';

  @override
  String get recSetScouterDot =>
      'Während einer Aufnahme zeigt ScouterKit selbst ein kleines Quadrat oben rechts im rechten Auge, solange das Mikrofon an ist. Es lässt sich nicht ausschalten.';

  @override
  String recSetSendPending(int count) {
    return '$count ausstehende senden';
  }

  @override
  String get recSetUrl => 'WhisperNotes-Adresse';

  @override
  String get save => 'Speichern';

  @override
  String get saved => 'Gespeichert';

  @override
  String get settingsAppUpdate => 'App-Update';

  @override
  String get settingsAppUpdateSubtitle =>
      'Version und neue Versionen von GitHub';

  @override
  String get settingsDiagnostics => 'Diagnose';

  @override
  String get settingsDiagnosticsSubtitle =>
      'Testanzeige, Anzeige prüfen, Protokoll';

  @override
  String get settingsDisplay => 'Anzeige & Aktivierung';

  @override
  String get settingsDisplaySubtitle =>
      'Aktivierungswinkel, Höhe, Distanz, Even-Dashboard';

  @override
  String get settingsNoGlassesPaired => 'Noch keine Brille gekoppelt';

  @override
  String get settingsNotSetUp => 'Nicht eingerichtet';

  @override
  String get settingsNotifications => 'Benachrichtigungen';

  @override
  String get settingsNotificationsOff => 'Weiterleitung aus';

  @override
  String get settingsNotificationsOn =>
      'Handy-Benachrichtigungen werden weitergeleitet';

  @override
  String get settingsPairGlasses => 'Brille koppeln';

  @override
  String get settingsRecordings => 'Aufnahmen';

  @override
  String get settingsWhisperNotSetUp => 'WhisperNotes nicht eingerichtet';
}
