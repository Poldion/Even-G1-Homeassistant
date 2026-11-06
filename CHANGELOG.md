# Changelog

Alle nennenswerten Änderungen an App und Integration. Das Format folgt
[Keep a Changelog](https://keepachangelog.com/de/1.1.0/), die Versionen
[Semantic Versioning](https://semver.org/lang/de/). App und Integration
tragen ab 0.8.0 dieselbe Versionsnummer.

## [Unreleased]

## [0.16.4] - 2026-11-06

### Added
- Update-Kanal unter *Einstellungen → Updates*: „Stabil“ (wie bisher) oder
  „ScouterKit“. Der ScouterKit-Kanal installiert die experimentelle Version
  für Brillen mit der Ersatz-Firmware ScouterKit (g1v0). Vor dem Wechsel
  erscheint eine Warnung: Diese Firmware muss man selbst aufspielen, und das
  lässt sich nicht rückgängig machen.

### Changed
- Die Build-Nummer der APK ist jetzt die Bauzeit in Minuten. So nimmt Android
  jeden neueren Build beider Kanäle als Update an.

## [0.16.3] - 2026-11-03

### Changed
- Schnelle Bluetooth-Verbindung („high“) während der ganzen Assist-Anfrage
  auf beiden Bügeln: vom Gedrückthalten über die Bearbeitung bis die Antwort
  ausgeblendet ist (höchstens 3 Minuten). Sonst „balanced“. Vorher galt
  „high“ nur für den rechten Bügel und nur solange das Mikrofon an war, die
  Antwort kam dadurch links und rechts unterschiedlich schnell an.

## [0.16.2] - 2026-11-03

### Fixed
- Akkulaufzeit: Die Bluetooth-Verbindung lief dauerhaft mit hoher Priorität
  (die Funkchips beider Bügel wachten alle 11–15 ms auf). Jetzt „balanced“
  wie bei MentraOS; hoch nur, solange Assist zuhört.
- Automatische Helligkeit mit Offset misst nur noch alle zwei Minuten.

## [0.16.1] - 2026-11-03

### Fixed
- Nach einer Assist-Anfrage (oder einem anderen Text) startete das nächste
  Gedrückthalten Assist nicht mehr, bis der Ruhemodus aus- und wieder
  eingeschaltet wurde. Seit 0.13.0 blieb die Brille nach dem Leeren der
  Anzeige auf ihrem Even-AI-Bildschirm. Jetzt leert die App die Anzeige
  sofort mit einem leeren Text und gibt die Brille eine Sekunde später mit
  dem Beenden-Befehl `0x18` frei.

## [0.16.0] - 2026-11-02

### Added
- Trageerkennung in Home Assistant: Binärsensor „Getragen“ und Schalter
  „Trageerkennung“, der die Erkennung der Brille (`0x27`) ein- und
  ausschaltet. Der Schalter ist auch in der App unter *Anzeige & Aktivierung*.
  Solange die App die Einstellung nicht geändert hat, liest sie den Wert der
  Brille aus (`0x3A`).

## [0.15.1] - 2026-11-02

### Fixed
- Linkes Auge bleibt leer: Wie die offizielle App wartet die App jetzt auf
  die Antwort des linken Bügels zu jedem Textpaket und schickt es erneut,
  wenn sie fehlt oder negativ ist (bis zu zweimal). Im Protokoll steht dann
  „L: Text unbeantwortet – erneut gesendet“.

## [0.15.0] - 2026-11-02

### Added
- Automatische Helligkeit mit Offset: Bei „Auto“ wird der Helligkeitsregler
  zum Offset (−50 % bis +50 %). Die Firmware kennt keinen Offset (feste
  Tabelle vom Lichtsensor zur Stufe), daher misst die App etwa jede Minute,
  wenn nichts angezeigt wird, kurz im Auto-Modus der Brille, liest die Stufe
  aus (`0x29`) und setzt Stufe + Offset.

## [0.14.0] - 2026-11-02

### Added
- Aufnahmen mit dem Brillen-Mikrofon, gestartet in der App (Übersicht) oder
  in Home Assistant (`switch.<name>_aufnahme`). Beim Stoppen geht die
  Aufnahme an WhisperNotes (`POST /api/jobs`), das sie transkribiert,
  zusammenfasst und in BasaltNotes ablegt. Nicht gesendete Aufnahmen werden
  später erneut gesendet.
- Kleiner Punkt oben rechts auf der Brille, solange aufgenommen wird.

## [0.13.0] - 2026-11-02

### Fixed
- Kein kurzes Aufblitzen von „Even AI“ mehr, wenn das Dashboard oder ein Text
  verschwindet. Die App leert die Anzeige jetzt mit einem leeren Text (wie
  MentraOS) statt mit dem Beenden-Befehl `0x18`, dessen Abbau in der Firmware
  manchmal den Even-AI-Bildschirm zeigt.
- Dashboard nur auf einem Auge: Kurz nach dem Anzeigen fragt die App beide
  Bügel, was sie zeigen, und schickt den Text an einen Bügel, der ihn nicht
  zeigt, noch einmal. Das steht im Protokoll als „Anzeige links fehlte –
  erneut gesendet“.

## [0.12.1] - 2026-11-02

### Fixed
- Höhe und Distanz der Anzeige werden jetzt übernommen. Die App öffnet beim
  Einstellen kurz die Positionsvorschau der Brille und schließt sie danach
  mit dem Befehl, den auch die offizielle App sendet (Zustand `00`); vorher
  blieb die Brille im Vorschaumodus und der Beispieltext unterbrach ihn.
- Helligkeit: Die Brille kennt die Stufen 0–42 (nicht 0–63), der obere Teil
  des Reglers hatte keine Wirkung. Bei automatischer Helligkeit zeigt die
  Übersicht die Stufe, die die Brille gerade nutzt.

## [0.12.0] - 2026-11-02

### Added
- App: Helligkeit der Brille auf der Übersicht, mit Regler und Schalter für
  die automatische Helligkeit. Die Einstellung wird wie bei MentraOS bei
  jeder Verbindung an die Brille geschickt; solange sie in der App nicht
  geändert wurde, zeigt die App den Wert der Brille an.

## [0.11.0] - 2026-11-02

### Fixed
- Dashboard per Tippen links/rechts: Die App zeigt das Dashboard jetzt selbst
  an (wie beim Hochschauen), ohne Umweg über Home Assistant. Erneutes Tippen
  schließt es. Wird gerade ein anderer Text angezeigt, blättert Tippen wie
  bisher.

### Added
- Diagnose: Pakete, die die Brille von sich aus schickt, erscheinen im
  Protokoll (`L rx …` / `R rx …`).

### Changed
- App und Integration müssen für das Dashboard per Tippen beide auf 0.11.0
  sein.

## [0.10.0] - 2026-11-02

### Added
- App: Selbst-Update wie bei BasaltNotes. Die App sucht einmal am Tag auf
  der Releases-Seite nach einer neuen Version (oder per *Einstellungen →
  App-Update*), lädt die APK und startet die Installation.

## [0.9.0] - 2026-11-02

### Added
- Integration: Kalender und To-do-Listen in den Optionen auswählbar. Das
  Dashboard zeigt Termine von heute und morgen sowie fällige To-dos, ohne
  Helfer oder YAML.
- Integration: Standard-Dashboard für eine Seite der Brille mit Uhrzeit,
  Datum, Entitäten, Terminen und To-dos.

### Changed
- Das Dashboard-Template ist optional; leer bedeutet Standard-Layout. Das
  bisherige Standard-Template (Uhrzeit und Sonne) wird durch das neue Layout
  ersetzt.

## [0.8.0] - 2026-11-02

### Added
- App: Tabs „Übersicht“ und „Einstellungen“. Die Übersicht zeigt Verbindung,
  Akku links/rechts und Case (inkl. Laden), Trage-Zustand, Ruhemodus,
  Home Assistant mit gewähltem Assistenten und eine einklappbare Vorschau der
  Brillenanzeige.
- App: Aktivierungswinkel, Höhe und Distanz des Textes sowie das
  Even-Dashboard beim Hochschauen sind in der App einstellbar.
- App: Testschalter „Assist-Antworten im Even-AI-Modus“ in der Diagnose.
- Integration: Entität „Assistent“ zur Auswahl der Assist-Pipeline.
- Integration: Dashboard-Entitäten als Zeilen „Name: Zustand Einheit“ auf
  dem Brillen-Dashboard.
- Integration: Sensoren „Akku Case“, „Zustand“ und „Case lädt“.
- Releases: signierte APK und Integration als ZIP auf der Releases-Seite.

### Changed
- Brilleneinstellungen (Winkel, Position, Even-Dashboard) wurden von der
  Integration in die App verschoben.
- App und Integration haben eine gemeinsame Versionsnummer.

### Fixed
- Akku-, Case- und Trage-Statusmeldungen der Brille landen nicht mehr alle
  paar Sekunden als Geste „other“ in Home Assistant.
- Release-APKs sind mit einem festen Schlüssel signiert und lassen sich als
  Update installieren.

## [0.7.0] - 2026-11-01

### Added
- Ruhemodus, schaltbar in App, Home Assistant (`switch`) und per Dreifachtippen.
- Weiterleitung von Handy-Benachrichtigungen an die Brille (Android).
- Einstellung „Even-Dashboard beim Hochschauen“, Prüfung der Anzeige je Bügel.

### Changed
- Während die Touchbar gehalten wird, zeigt die Brille ihre eigene
  Zuhör-Anzeige; Frage und Antwort folgen nach dem Loslassen.

## [0.4.0] - 2026-10-20

### Added
- Dashboard beim Hochschauen, Kopfneigungswinkel und Dashboard-Position.

### Changed
- Beide Bügel werden gleichzeitig über eine gemeinsame Warteschlange
  beschrieben (wie MentraOS), Text immer im Textmodus.
- Assist läuft über die Integration ohne Sprachende-Erkennung, mit
  automatischer Verstärkung und Rauschunterdrückung.

### Fixed
- Laden der Integration unter Home Assistant 2026.10.

## [0.1.0] - 2026-10-15

### Added
- Erste Version: Integration mit Aktionen, Notify-Entität, Sensoren und
  Gesten-Events; Flutter-App mit BLE-Verbindung zur G1, Textanzeige und
  Assist über das Brillen-Mikrofon.

[Unreleased]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.16.4...HEAD
[0.16.4]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.16.3...v0.16.4
[0.16.3]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.16.2...v0.16.3
[0.16.2]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.16.1...v0.16.2
[0.16.1]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.16.0...v0.16.1
[0.16.0]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.15.1...v0.16.0
[0.15.1]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.15.0...v0.15.1
[0.15.0]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.14.0...v0.15.0
[0.14.0]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.13.0...v0.14.0
[0.13.0]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.12.1...v0.13.0
[0.12.1]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.12.0...v0.12.1
[0.12.0]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.11.0...v0.12.0
[0.11.0]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.10.0...v0.11.0
[0.10.0]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/Poldion/Even-G1-Homeassistant/releases/tag/v0.8.0
[0.7.0]: https://github.com/Poldion/Even-G1-Homeassistant/commits/f545428
[0.4.0]: https://github.com/Poldion/Even-G1-Homeassistant/commits/f4d4c19
[0.1.0]: https://github.com/Poldion/Even-G1-Homeassistant/commits/c536e2b
