# Even Realities G1 für Home Assistant

[![Release](https://img.shields.io/github/v/release/Poldion/Even-G1-Homeassistant)](https://github.com/Poldion/Even-G1-Homeassistant/releases/latest)
[![Integration](https://github.com/Poldion/Even-G1-Homeassistant/actions/workflows/integration.yml/badge.svg)](https://github.com/Poldion/Even-G1-Homeassistant/actions/workflows/integration.yml)
[![App](https://github.com/Poldion/Even-G1-Homeassistant/actions/workflows/app.yml/badge.svg)](https://github.com/Poldion/Even-G1-Homeassistant/actions/workflows/app.yml)

Verbindet die Smart-Glasses **Even Realities G1** mit **Home Assistant**: Texte
und ein eigenes Dashboard auf der Brille anzeigen, mit deinem Assistenten
sprechen und die Brille in Automationen nutzen. Dazu gehören eine
**Android-App**, die die Brille per Bluetooth verbindet, und eine
**Home-Assistant-Integration**.

Die App arbeitet mit Evens eigener Firmware oder – experimentell – mit der
freien Ersatz-Firmware **[ScouterKit (g1v0)](https://github.com/mafik/scouter_kit)**,
die das ganze Display und alle Sensoren der Brille freigibt (siehe
[Firmware](#firmware-even-oder-scouterkit)).

## Funktionen

- **Texte auf der Brille** per Aktion, Notify-Entität oder Automation, z. B. „Waschmaschine fertig“
- **Assist:** linke Touchbar gedrückt halten, sprechen, loslassen; die Antwort deines Assistenten erscheint auf der Brille
- **Dashboard für die Brille** mit Uhrzeit, Datum, Entitäten, Terminen und To-dos auf einer Seite, auf Wunsch beim Hochschauen
- **Aufnahmen** mit dem Brillen-Mikrofon, gestartet in der App oder in Home Assistant; [WhisperNotes](https://github.com/Poldion/WhisperNotes) transkribiert und fasst zusammen, die Zusammenfassung landet in [BasaltNotes](https://github.com/Poldion/BasaltNotes)
- **Handy-Benachrichtigungen** auf der Brille, pro App wählbar
- **Ruhemodus**, Akku von Brille und Case, Trage-Zustand und Gesten als Entitäten
- **Mit ScouterKit zusätzlich:** Texte auf dem ganzen Display (11 statt 5 Zeilen), beide Augen exakt gleichzeitig, App-Symbole bei Benachrichtigungen, Dashboard beim Hochschauen direkt von der Brille (ohne Handy), Nicken und Kopfschütteln als Gesten, Helligkeits-Offset zur Automatik

## Firmware: Even oder ScouterKit

| | Even-Firmware | [ScouterKit (g1v0)](https://github.com/mafik/scouter_kit) |
| --- | --- | --- |
| Status | Werksfirmware, stabil | experimentell, sehr junges Projekt |
| Offizielle Even-App und ihre Funktionen | ja | nein |
| Anzeige | 576 × 136 px, 5 Zeilen à ~30 Zeichen | 640 × 480 px, 11 Zeilen à 42 Zeichen |
| Beide Augen gleichzeitig | nicht garantiert | ja |
| Dashboard beim Hochschauen | über das Handy | ein Programm auf der Brille zeigt es selbst |
| Gesten | Touchbar, Kopf heben | zusätzlich rechts gedrückt halten, Nicken, Kopfschütteln |
| Branch / Releases | [`legacy`](https://github.com/Poldion/Even-G1-Homeassistant/tree/legacy), Releases `vX.Y.Z` | [`main`](https://github.com/Poldion/Even-G1-Homeassistant/tree/main), Vorabversionen `sk-vX.Y.Z.N` |

**ScouterKit** ist eine freie Ersatz-Firmware von
[mafik/scouter_kit](https://github.com/mafik/scouter_kit) (MIT-Lizenz). Sie
ersetzt Evens Firmware auf beiden Bügeln und macht jeden Bügel zu einer kleinen
programmierbaren Maschine; die App spricht deren Protokoll 5. Die App selbst
spielt keine Firmware auf: Das geschieht mit den Werkzeugen von ScouterKit an
einem Linux-Rechner, Schritt für Schritt nach deren
[Anleitung](https://github.com/mafik/scouter_kit/tree/main/g1_firmware).

> **Achtung:** Das Aufspielen lässt sich nicht ungeschehen machen (zurück geht
> nur zu Evens öffentlicher 1.6.6), ein Fehler kann einen Bügel unbrauchbar
> machen, und die Garantie erlischt vermutlich. Lies vorher
> [docs/SCOUTERKIT.md](docs/SCOUTERKIT.md) und die Anleitung von ScouterKit
> ganz.

## Installation

### Integration

**HACS:** *HACS → ⋮ → Benutzerdefinierte Repositories* →
`https://github.com/Poldion/Even-G1-Homeassistant` als *Integration* hinzufügen,
„Even Realities G1“ installieren, Home Assistant neu starten.

**Manuell:** `even_g1-vX.Y.Z.zip` von der
[Releases-Seite](https://github.com/Poldion/Even-G1-Homeassistant/releases/latest)
nach `config/custom_components/even_g1/` entpacken und Home Assistant neu
starten.

Danach *Einstellungen → Geräte & Dienste → Integration hinzufügen →
„Even Realities G1“*.

### App (Android)

`even-g1-ha-vX.Y.Z.apk` von der
[Releases-Seite](https://github.com/Poldion/Even-G1-Homeassistant/releases/latest)
auf dem Handy herunterladen und installieren. Danach aktualisiert sich die
App selbst: Sie sucht einmal am Tag nach einer neuen Version (oder unter
*Einstellungen → App-Update*) und installiert sie auf Nachfrage. Beim ersten
Update fragt Android einmalig, ob die App Apps installieren darf. Die
Einstellungen bleiben erhalten.

App und Integration sollten dieselbe Version haben.

**Für ScouterKit:** In der App unter *Einstellungen → App-Update* den
Update-Kanal **ScouterKit** wählen; er installiert die Vorabversionen
`even-g1-ha-sk-v….apk` aus diesem Branch. Danach unter *Einstellungen → Brille*
**ScouterKit** wählen und die Brille im offenen Ladeetui koppeln
(Details in [docs/SCOUTERKIT.md](docs/SCOUTERKIT.md)).

## Einrichtung

1. In Home Assistant ein Token erstellen: *Profil → Sicherheit → Langlebige Zugriffstoken*.
2. Die offizielle Even-App schließen; die Brille verbindet sich nur mit einer App.
3. In der App unter *Einstellungen → Home Assistant* URL und Token eintragen, *Verbinden & Brillen aus HA laden*, Brille wählen, *Speichern*.
4. Unter *Einstellungen → Brille koppeln* nach Brillen suchen und deine G1 antippen.
5. Optional *Einstellungen → Benachrichtigungen → Erlauben*. Meldet Android „App wurde Zugriff verweigert“: *Android-Einstellungen → Apps → Even G1 HA → ⋮ → Eingeschränkte Einstellungen zulassen*, dann erneut erlauben.
6. Für stabilen Betrieb im Hintergrund die Akku-Optimierung für die App deaktivieren.

## Bedienung

### An der Brille

| Geste | Aktion |
| --- | --- |
| Linke Touchbar gedrückt halten | Assist: sprechen, solange gedrückt (max. 30 s) |
| Tippen links / rechts | Seite zurück / vor |
| Doppeltippen | Anzeige schließen, Assist abbrechen |
| Dreifachtippen | Ruhemodus an/aus |
| Hochschauen | Home-Assistant-Dashboard (wenn als Dashboard-Geste gewählt) |
| Rechte Touchbar gedrückt halten | nur ScouterKit: Geste `long_press_right` für eigene Automationen |
| Nicken / Kopfschütteln | nur ScouterKit, unter *Anzeige & Aktivierung → Kopfgesten*: Gesten `nod` / `head_shake` |

### In der App

- **Übersicht:** Verbindung, Akku links/rechts und Case, Trage-Zustand, Ruhemodus, Helligkeit (Regler, Automatik mit Offset), Home Assistant und Assistent, optionale Vorschau der Brillenanzeige.
- **Einstellungen:** Home Assistant, Brille koppeln, *Anzeige & Aktivierung* (Aktivierungswinkel, Höhe, Distanz, Even-Dashboard beim Hochschauen), Benachrichtigungen, Diagnose.

### In Home Assistant

Optionen unter *Integration → Konfigurieren*:

| Option | Bedeutung |
| --- | --- |
| Assistent | Welche Assist-Pipeline antwortet (auch über die Entität „Assistent“) |
| Erkannte Frage anzeigen | Zeigt nach dem Loslassen die erkannte Frage |
| Automatische Verstärkung / Rauschunterdrückung | Hilft bei leiser Sprache bzw. lauter Umgebung |
| Standard-Anzeigedauer | Sekunden bis zum Ausblenden (0 = bis Doppeltippen) |
| Dashboard-Geste | Kopf gehoben, Tippen links oder rechts |
| Dashboard-Entitäten | Zeilen „Name: Zustand Einheit“ auf dem Brillen-Dashboard |
| Kalender | Termine von heute (noch nicht vorbei) und morgen |
| To-do-Listen | Offene To-dos mit Fälligkeitsdatum, die dringendsten zuerst |
| Eigenes Dashboard-Template | Leer lassen für das Standard-Layout; sonst Jinja-Template unter den Entitäten |

Das Standard-Dashboard passt auf eine Seite der Brille (5 Zeilen):

```
14:35  ·  Mo, 2. Nov  ·  +2
» heute  Geburtstag Anna
» 15:00  Zahnarzt
» morgen 09:00  Teammeeting
[ ] Müll raus · morgen
```

Erste Zeile Uhrzeit und Datum, `+2` heißt: zwei weitere Einträge passen
nicht mehr drauf. Termine (`»`) kommen zuerst, mindestens eine Zeile bleibt
für To-dos (`[ ]`, überfällig `[!]`). Ohne Einträge steht dort nur Uhrzeit und
Datum. In eigenen Templates stehen die Variablen `kopfzeile`, `agenda` und
`agenda_mehr` zur Verfügung.

Die Assist-Pipeline braucht eine Spracherkennung (z. B. *Home Assistant
Cloud* oder *Whisper*); *Speech-to-Phrase* versteht nur feste Befehle.
Damit beim Hochschauen nur das Home-Assistant-Dashboard erscheint, in der App
*Even-Dashboard beim Hochschauen* auf *Ausblenden* stellen.

### Aufnahmen (WhisperNotes → BasaltNotes)

1. In der App unter *Einstellungen → Aufnahmen* die Adresse von WhisperNotes
   eintragen (z. B. `http://192.168.1.10:8000`), bei Bedarf den API-Schlüssel.
2. In WhisperNotes unter *Einstellungen → BasaltNotes* die Verbindung und einen
   **Standard-Vault** einrichten.
3. Aufnahme starten: auf der Übersicht der App mit *Start* oder in Home
   Assistant mit `switch.<name>_aufnahme`. Solange aufgenommen wird, zeigt die
   Brille oben rechts einen kleinen Punkt (`o`), wenn nichts anderes angezeigt
   wird; abschaltbar in den Einstellungen.
4. Beim Stoppen schickt die App die Aufnahme an WhisperNotes. Dort wird sie
   transkribiert und zusammengefasst; die Zusammenfassung kommt als Notiz in
   den Eingang von BasaltNotes. Ohne Verbindung bleibt die Aufnahme in der App
   und wird später gesendet.

Bitte nur mit Einverständnis aller Anwesenden aufnehmen.

## Home-Assistant-Referenz

### Aktionen

```yaml
action: even_g1.show_text
data:
  title: Waschmaschine
  message: Die Wäsche ist fertig.
  duration: 15          # optional, Sekunden; 0 = bis Doppeltippen
  mode: screen          # oder "notification"
```

`even_g1.clear` schließt die Anzeige, `even_g1.show_dashboard` zeigt das
Dashboard. Außerdem gibt es `notify.<name>` für `notify.send_message`.

### Entitäten

| Entität | Beschreibung |
| --- | --- |
| `select.<name>_assistent` | Assistent der Brille |
| `switch.<name>_ruhemodus` | Ruhemodus |
| `switch.<name>_aufnahme` | Aufnahme mit dem Brillen-Mikrofon; beim Ausschalten geht sie an WhisperNotes |
| `sensor.<name>_akku_links` / `_akku_rechts` / `_akku_case` | Akkustand |
| `binary_sensor.<name>_case_ladt` | Case hängt am Ladekabel |
| `binary_sensor.<name>_getragen` | Brille wird getragen (braucht die Trageerkennung) |
| `switch.<name>_trageerkennung` | Trageerkennung der Brille an/aus (auch in der App unter *Anzeige & Aktivierung*) |
| `sensor.<name>_zustand` | `worn`, `not_worn`, `case_open`, `case_closed` |
| `binary_sensor.<name>_brille_verbunden` / `_app_verbunden` | Verbindungen |
| `sensor.<name>_letzte_frage` / `_letzte_antwort` | Letzte Assist-Interaktion |
| `event.<name>_geste` | `single_tap_left`, `single_tap_right`, `double_tap`, `triple_tap`, `head_up`, `head_down`, `long_press`, `long_press_release`, `other`; mit ScouterKit zusätzlich `long_press_right`, `long_press_right_release`, `nod`, `head_shake` |

Events: `even_g1_gesture` (`device_id`, `gesture`, `side`, `code`) und
`even_g1_assist` (`device_id`, `query`, `response`).

### Beispiele

```yaml
automation:
  - alias: G1 – Wetter bei Tippen rechts
    triggers:
      - trigger: state
        entity_id: event.even_g1_geste
        attribute: event_type
        to: single_tap_right
    actions:
      - action: even_g1.show_text
        data:
          title: Wetter
          message: "{{ state_attr('weather.home', 'temperature') }} °C"
          duration: 8

  - alias: G1 – Ruhemodus nachts
    triggers:
      - trigger: time
        at: "22:30:00"
    actions:
      - action: switch.turn_on
        target:
          entity_id: switch.even_g1_ruhemodus
```

## Hinweise

- Teile des Bluetooth-Protokolls stammen aus Community-Projekten und können je nach Firmware abweichen, siehe [docs/TECHNICAL.md](docs/TECHNICAL.md).
- Die Bluetooth-Bibliothek [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus) ist nur für nicht-kommerzielle Nutzung frei.
- Kein offizielles Produkt von Even Realities.
- ScouterKit ist ein Projekt von Dritten ([mafik/scouter_kit](https://github.com/mafik/scouter_kit)) und nicht Teil dieses Repositorys. Fragen zur Firmware selbst gehören dorthin.

## Danksagung und Lizenzen Dritter

- [ScouterKit](https://github.com/mafik/scouter_kit) (MIT): Firmware g1v0, Protokoll 5 und VM, deren Interpreter die Programme dieser App lokal geprüft hat.
- Benachrichtigungssymbole: Pebbles Symbole aus [PebbleOS](https://github.com/coredevices/PebbleOS) und [pebble-dev/iconography](https://github.com/pebble-dev/iconography), wie ScouterKit sie umwandelt (Apache License 2.0, siehe `app/assets/scouter/icons/NOTICE`).
- Schrift [Departure Mono](https://departuremono.com/) von Helena Zhang (SIL Open Font License 1.1, `app/assets/scouter/DepartureMono-LICENSE.txt`).
- Protokollwissen zur Even-Firmware aus [MentraOS](https://github.com/Mentra-Community/MentraOS), [even-g1-companion](https://github.com/Cheddies1/even-g1-companion), [g1-reverse](https://github.com/FreedomCoder-dev/g1-reverse) und dem [EvenDemoApp-Wiki](https://github.com/JohnRThomas/EvenDemoApp/wiki/Even-Realities-G1-BLE-Protocol).

## Weitere Dokumentation

- [Änderungen](CHANGELOG.md)
- [Technische Details und Protokoll](docs/TECHNICAL.md)
- [ScouterKit (g1v0) statt Even-Firmware](docs/SCOUTERKIT.md) · [Firmware-Repository](https://github.com/mafik/scouter_kit)
- [Entwicklung, Tests und Releases](docs/DEVELOPMENT.md)
