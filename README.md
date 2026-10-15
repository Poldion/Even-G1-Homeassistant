# Even Realities G1 ↔ Home Assistant

Verbindet die Smart-Glasses **Even Realities G1** mit **Home Assistant**:

- 📟 **Texte aus Home Assistant auf der Brille anzeigen**: per Aktion, Notify-Entität oder Automation (z. B. „Waschmaschine fertig“, „Haustür offen“, Wetter oder ein eigenes Dashboard-Template)
- 🎙️ **Home Assistant Assist per Brille**: **linke Touchbar gedrückt halten**, sprechen, loslassen. Die Frage geht über das Brillen-Mikrofon an deine Assist-Pipeline, die Antwort erscheint auf dem Display. Rückfragen innerhalb von 5 Minuten setzen dieselbe Unterhaltung fort.
- 👆 **Gesten als Trigger**: Tippen links/rechts, Doppeltippen, Kopf heben, Brille auf-/absetzen usw. als Event-Entität für Automationen
- 🔋 **Sensoren**: Akku links/rechts, verbunden, getragen, letzte Frage/Antwort

```
┌──────────────┐  BLE (2× Nordic UART)  ┌──────────────────┐  Websocket-API  ┌──────────────────────────┐
│  Even G1     │ ◄────────────────────► │  Smartphone-App  │ ◄─────────────► │ Home Assistant           │
│  L + R Bügel │  Text, Gesten, LC3-Mic │  (Flutter, app/) │  Text, Gesten,  │  + Integration even_g1   │
└──────────────┘                        └──────────────────┘  Assist-Audio   │  + Assist-Pipeline       │
                                                                             └──────────────────────────┘
```

Die Brille kann nur über Bluetooth mit einem Smartphone reden. Die **App** hält deshalb die
Bluetooth-Verbindung zu beiden Bügeln, dekodiert das Mikrofon-Audio (LC3 → PCM) und spricht mit
Home Assistant. Die **Custom Integration** (`custom_components/even_g1`) ist die Schnittstelle auf
der Home-Assistant-Seite: Sie stellt Aktionen, Entitäten und Events bereit und schiebt Anzeigebefehle
in Echtzeit an die App.

## Inhalt des Repositorys

| Pfad | Inhalt |
| --- | --- |
| `custom_components/even_g1/` | Home-Assistant-Integration (HACS-kompatibel) |
| `app/` | Flutter-App für Android (und iOS) |
| `app/packages/lc3_codec/` | FFI-Plugin mit [google/liblc3](https://github.com/google/liblc3) zum Dekodieren des Brillen-Mikrofons |
| `tests/` | Tests der Integration (pytest) |
| `app/test_e2e/` | End-to-End-Test App ↔ echte Home-Assistant-Instanz |

## Installation

### 1. Integration in Home Assistant

**Über HACS:** HACS → Integrationen → ⋮ → *Benutzerdefinierte Repositories* →
`https://github.com/poldion/even-g1-homeassistant` als *Integration* hinzufügen → „Even Realities G1“ installieren → Home Assistant neu starten.

**Manuell:** Den Ordner `custom_components/even_g1` nach `<config>/custom_components/even_g1` kopieren und Home Assistant neu starten.

Danach: *Einstellungen → Geräte & Dienste → Integration hinzufügen → „Even Realities G1“* und einen Namen für die Brille vergeben.

### 2. App auf dem Smartphone

- **Android:** Die APK wird von GitHub Actions gebaut: *Actions → App → letzter Lauf → Artifact `even-g1-ha-apk`* (bei Tags `v*` hängt sie zusätzlich am Release). Alternativ selbst bauen: `cd app && flutter build apk --release`.
- **iOS:** `cd app && flutter build ios` auf einem Mac mit Xcode (eigene Signierung nötig).

### 3. Einrichten

1. In Home Assistant: *Profil → Sicherheit → Langlebige Zugriffstoken → Token erstellen*.
2. **Die offizielle Even-App schließen** (bzw. in den Einstellungen die Bluetooth-Verbindung der Brille trennen). Die G1 verbindet sich immer nur mit einer App.
3. In der App: ⚙️ → URL (z. B. `http://homeassistant.local:8123`) und Token eintragen → *Verbinden & Brillen aus HA laden* → Brille auswählen → *Speichern*.
4. *Nach Brillen suchen* → deine G1 antippen (beide Bügel werden über ihre Kanalnummer zusammen erkannt). Auf Android ggf. die Kopplungsanfragen bestätigen.
5. Unter Android läuft die App mit einer dauerhaften Benachrichtigung als Vordergrunddienst weiter, wenn sie im Hintergrund ist. Für einen stabilen Betrieb die Akku-Optimierung für die App deaktivieren.

### 4. Assist konfigurieren

In der Integration unter *Konfigurieren* wählst du die **Assist-Pipeline** (Standard: bevorzugte Pipeline).
Die Pipeline braucht eine **Spracherkennung (STT)**, z. B. *Home Assistant Cloud*, *Whisper* oder *Speech-to-Phrase*.
Sprachausgabe (TTS) wird nicht genutzt, da die Brille keinen Lautsprecher hat.

Weitere Optionen:

| Option | Bedeutung |
| --- | --- |
| Erkannte Frage anzeigen | Zeigt nach dem Loslassen kurz `» erkannte Frage «` an |
| Standard-Anzeigedauer | Sekunden bis die Brille wieder zum Dashboard wechselt (0 = bis Doppeltippen) |
| Dashboard-Geste | Geste, die das Dashboard-Template anzeigt (z. B. *Einfaches Tippen rechts* oder *Kopf gehoben*) |
| Dashboard-Template | Jinja-Template, das für die Dashboard-Geste bzw. `even_g1.show_dashboard` gerendert wird |

## Bedienung an der Brille

| Geste | Aktion |
| --- | --- |
| Linke Touchbar **gedrückt halten** | Assist: sprechen, solange gedrückt (max. 30 s) |
| Tippen links / rechts | Bei mehrseitigen Texten: Seite zurück / vor |
| Doppeltippen | Anzeige schließen, laufende Assist-Anfrage abbrechen |
| Konfigurierte Dashboard-Geste | Dashboard-Template anzeigen |

## Home Assistant: Aktionen, Entitäten, Events

### Aktionen

```yaml
# Text im Vollbild anzeigen (lange Texte werden automatisch auf Seiten verteilt)
action: even_g1.show_text
data:
  title: Waschmaschine
  message: Die Wäsche ist fertig.
  duration: 15          # optional, Sekunden; 0 = bis Doppeltippen
  mode: screen          # oder "notification" (normale Benachrichtigung der Brille)
  # device_id: ...      # optional, sonst an alle Brillen

# Zurück zum Dashboard der Brille
action: even_g1.clear

# Dashboard-Template rendern und anzeigen
action: even_g1.show_dashboard
```

Zusätzlich gibt es eine **Notify-Entität** (`notify.<name>`), nutzbar mit `notify.send_message`:

```yaml
action: notify.send_message
target:
  entity_id: notify.even_g1
data:
  title: Haustür
  message: Die Haustür ist seit 5 Minuten offen.
```

### Entitäten

| Entität | Beschreibung |
| --- | --- |
| `binary_sensor.<name>_app_verbunden` | App ist mit HA verbunden |
| `binary_sensor.<name>_brille_verbunden` | Beide Bügel sind per Bluetooth verbunden |
| `binary_sensor.<name>_getragen` | Brille wird getragen (sofern von der Firmware gemeldet) |
| `sensor.<name>_akku_links` / `_akku_rechts` | Akkustand der Bügel |
| `sensor.<name>_letzte_frage` / `_letzte_antwort` | Letzte Assist-Interaktion (voller Text im Attribut `full_text`) |
| `event.<name>_geste` | Gesten-Event (`event_type`: `single_tap_left`, `single_tap_right`, `double_tap`, `triple_tap`, `head_up`, `head_down`, `worn`, `removed`, `long_press`, `long_press_release`, `other`) |

### Events

- `even_g1_gesture` mit `device_id`, `gesture`, `side`, `code` (Roh-Code des Protokolls)
- `even_g1_assist` mit `device_id`, `query`, `response`

### Beispiel-Automationen

```yaml
# Wetter anzeigen, wenn rechts getippt wird
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
          message: >
            {{ state_attr('weather.home', 'temperature') }} °C,
            {{ states('weather.home') }}
          duration: 8

  # Benachrichtigung bei offenem Fenster
  - alias: G1 – Fenster offen
    triggers:
      - trigger: state
        entity_id: binary_sensor.fenster_bad
        to: "on"
        for: "00:10:00"
    actions:
      - action: even_g1.show_text
        data:
          message: Das Badfenster ist seit 10 Minuten offen.
          mode: notification
```

Beispiel für ein Dashboard-Template:

```jinja
{{ now().strftime('%H:%M') }} · {{ states('sensor.outdoor_temperature') }} °C
Licht an: {{ states.light | selectattr('state', 'eq', 'on') | list | count }}
{% if is_state('binary_sensor.haustuer', 'on') %}⚠ Haustür offen{% endif %}
```

## Technische Details

- **Protokoll:** Die App spricht das BLE-Protokoll aus der offiziellen [EvenDemoApp](https://github.com/even-realities/EvenDemoApp): Text über `0x4E` (5 Zeilen à ~488 px pro Seite, zuerst links, dann rechts nach Bestätigung), Mikrofon über `0x0E`, Audio über `0xF1` (LC3, 16 kHz, 10-ms-Frames, 20 Byte/Frame), Touch-Events über `0xF5` (`0x17` = Assist-Start, `0x18` = Ende), Heartbeat `0x25` alle 8 s.
- **Assist:** Die App nutzt den Websocket-Befehl `assist_pipeline/run` (Stufen `stt` → `intent`) und streamt das dekodierte PCM-Audio als Binärnachrichten. Die Gerätezuordnung (`device_id`) wird mitgeschickt, damit Befehle wie „Licht an“ den Bereich der Brille berücksichtigen können.
- **Integration ↔ App:** Websocket-Befehle `even_g1/devices`, `even_g1/subscribe` (Anzeigebefehle und Konfiguration als Push), `even_g1/update_state`, `even_g1/gesture`, `even_g1/assist`, `even_g1/dashboard`.

## Hinweise & Grenzen

- Die Gesten-Codes für Kopf heben/senken und Auf-/Absetzen sowie die Akku-Abfrage (`0x2C`) stammen nicht aus der offiziellen Dokumentation, sondern aus Community-Analysen, und können je nach Firmware abweichen. Unbekannte Codes kommen als `other` mit `code` in Home Assistant an.
- Die Home-Assistant-Spracherkennung beendet die Aufnahme bei längeren Sprechpausen eventuell vor dem Loslassen der Touchbar (Voice Activity Detection).
- Benachrichtigungen im Modus `notification` setzen eine App-Whitelist auf der Brille. Die offizielle Even-App überschreibt diese beim nächsten Verbinden wieder.
- Die BLE-Bibliothek [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus) ist für private/nicht-kommerzielle Nutzung frei (`License.nonprofit`).
- Dies ist kein offizielles Produkt von Even Realities.

## Entwicklung

```sh
# Integration testen
pip install -r requirements_test.txt
pytest

# App
cd app
flutter pub get
flutter analyze && flutter test

# LC3-Decoder (Host-Build)
cd app/packages/lc3_codec
cmake -S src -B build && cmake --build build
LC3_CODEC_LIBRARY=build/liblc3_codec.so flutter test

# End-to-End gegen eine laufende HA-Instanz mit der Integration
cd app
HA_URL=http://localhost:8123 HA_TOKEN=... HA_STT_ENGINE=stt.dein_stt flutter test test_e2e
```
