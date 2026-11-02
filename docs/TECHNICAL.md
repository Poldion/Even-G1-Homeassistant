# Technische Details

## Aufbau

```
┌──────────────┐  BLE (2× Nordic UART)  ┌──────────────────┐  Websocket-API  ┌──────────────────────────┐
│  Even G1     │ ◄────────────────────► │  Smartphone-App  │ ◄─────────────► │ Home Assistant           │
│  L + R Bügel │  Text, Gesten, LC3-Mic │  (Flutter, app/) │  Text, Gesten,  │  + Integration even_g1   │
└──────────────┘                        └──────────────────┘  Assist-Audio   │  + Assist-Pipeline       │
                                                                             └──────────────────────────┘
```

Die Brille spricht nur Bluetooth mit einem Smartphone. Die **App** hält die
Verbindung zu beiden Bügeln, dekodiert das Mikrofon-Audio (LC3 → PCM) und
verbindet sich mit Home Assistant. Die **Integration**
(`custom_components/even_g1`) stellt Aktionen, Entitäten und Events bereit und
schiebt Anzeigebefehle in Echtzeit an die App.

| Pfad | Inhalt |
| --- | --- |
| `custom_components/even_g1/` | Home-Assistant-Integration |
| `app/` | Flutter-App (Android, iOS ohne Benachrichtigungen) |
| `app/packages/lc3_codec/` | FFI-Plugin mit [google/liblc3](https://github.com/google/liblc3) für das Brillen-Mikrofon |
| `tests/` | Tests der Integration (pytest) |
| `app/test/`, `app/test_e2e/` | Tests der App, End-to-End-Test gegen eine echte HA-Instanz |

## BLE-Protokoll

Grundlage ist die offizielle [EvenDemoApp](https://github.com/even-realities/EvenDemoApp),
ergänzt um Erkenntnisse aus [MentraOS](https://github.com/Mentra-Community/MentraOS),
[even-g1-companion](https://github.com/Cheddies1/even-g1-companion) und dem
[eveng1 Python SDK](https://github.com/emingenc/even_glasses).

| Befehl | Bedeutung |
| --- | --- |
| `0x4E` | Text, Textmodus `0x71` (5 Zeilen à ~488 px, Blättern übernimmt die App). Optional Even-AI-Modus `0x31`/`0x41` |
| `0x0E` | Mikrofon an/aus (rechter Bügel) |
| `0xF1` | Mikrofon-Audio: LC3, 16 kHz, 10-ms-Frames, 20 Byte/Frame |
| `0xF5` | Ereignisse: `00` Doppeltippen, `01` Tippen, `02`/`03` Kopf hoch/runter, `04`/`05` Ruhemodus, `17`/`18` Touchbar gehalten/losgelassen |
| `0xF5` (Status) | `0A` Akku Brille, `0F` Akku Case, `0E` Case-Kabel, `06`/`07` auf-/abgesetzt, `08`/`0B` im Case offen/zu |
| `0x25` | Heartbeat (alle 8 s) |
| `0x03` | Ruhemodus `0C` an / `0A` aus |
| `0x08 … 03 <v>` | Even-Dashboard beim Hochschauen (`00` anzeigen, `02` ausblenden) |
| `0x01 <h> <a>` | Helligkeit `h` (0–42) und automatische Helligkeit `a` (`00`/`01`, Lichtsensor im rechten Bügel); `F5 12 <h>` meldet die aktuelle Stufe |
| `0x29` | Helligkeit abfragen (rechter Bügel), Antwort `29 65 <h> <a>` |
| `0x0B` | Aktivierungswinkel (0–60°) |
| `0x26 08 00 <n> 02 <s> <h> <d>` | Höhe (0–8) und Distanz (1–9) der Anzeige; `s` = `01` Positionsvorschau der Brille, `00` übernehmen |
| `0x39` | Abfrage, was ein Bügel gerade anzeigt |
| `0x4B` / `0x04` | Benachrichtigung / App-Whitelist (linker Bügel) |

Nur ein Teil davon ist offiziell dokumentiert; der Rest stammt aus
Community-Projekten und kann je nach Firmware abweichen.

**Senden an beide Bügel:** Wie bei MentraOS laufen alle Befehle über eine
gemeinsame Warteschlange. Jedes Paket wird gleichzeitig an beide Bügel
geschrieben (mit Bluetooth-Bestätigung), bevor das nächste folgt. Lehnt ein
Bügel einen Befehl ab, steht das im App-Protokoll (`L/R rejected 0x..`).

**Assist:** Während die Touchbar gehalten wird, zeigt die Firmware ihre eigene
Zuhör-Anzeige (der rechte Bügel zeichnet sie laufend neu). Danach zeigt die
App „Einen Moment …“, die erkannte Frage und die Antwort auf beiden Bügeln.

## Integration ↔ App

Websocket-Befehle der Integration:

| Befehl | Zweck |
| --- | --- |
| `even_g1/devices` | Brillen-Einträge auflisten |
| `even_g1/subscribe` | Anzeigebefehle, Konfiguration und Dashboard-Text als Push |
| `even_g1/update_state` | Zustand der Brille melden (Verbindung, Akkus, Ruhemodus, Trage-Zustand) |
| `even_g1/gesture` | Geste melden |
| `even_g1/assist_run` | Assist-Pipeline mit Audio aus der Brille ausführen (ohne Sprachende-Erkennung) |
| `even_g1/dashboard` | Dashboard rendern |

Das Dashboard-Template wird in Home Assistant laufend gerendert und nur bei
Änderungen an die App geschickt; beim Hochschauen zeigt die App den zuletzt
erhaltenen Text sofort an.
