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
| `0x27 <0/1>` / `0x3A` | Trageerkennung an/aus / abfragen (Antwort `3A C9 <0/1>`); nur mit ihr meldet die Brille `F5 06`/`07` |
| `0x39` | Abfrage, was ein Bügel gerade anzeigt (`0x10` = Textanzeige); die App prüft damit nach jedem Text beide Bügel |
| `0x4B` / `0x04` | Benachrichtigung / App-Whitelist (linker Bügel) |

Nur ein Teil davon ist offiziell dokumentiert; der Rest stammt aus
Community-Projekten und kann je nach Firmware abweichen.

**Senden an beide Bügel:** Wie bei MentraOS laufen alle Befehle über eine
gemeinsame Warteschlange. Jedes Paket wird gleichzeitig an beide Bügel
geschrieben (mit Bluetooth-Bestätigung), bevor das nächste folgt. Bei Texten
(`0x4E`) wartet die App wie die offizielle App zusätzlich auf die Antwort des
linken Bügels (`4E C9`/`CB`, der rechte antwortet erst später) und schickt das
Paket bis zu zweimal erneut, wenn sie fehlt oder `CA` lautet. Lehnt ein
Bügel einen Befehl ab, steht das im App-Protokoll (`L/R rejected 0x..`).

**Assist:** Während die Touchbar gehalten wird, zeigt die Firmware ihre eigene
Zuhör-Anzeige (der rechte Bügel zeichnet sie laufend neu). Danach zeigt die
App „Einen Moment …“, die erkannte Frage und die Antwort auf beiden Bügeln.

## Automatische Helligkeit mit Offset

Die Firmware nähert die Helligkeit im Auto-Modus schrittweise einer festen
Tabelle an (Lichtsensor im rechten Bügel → Stufe 0–42, g1-reverse
`compute_lux_brightness_bucket`) und schreibt die Stufe in dasselbe Feld, das
`0x29` liest. Einen Offset gibt es nicht. Mit Offset schaltet die App daher
etwa alle zwei Minuten, wenn nichts angezeigt wird, kurz den Auto-Modus ein
(`01 <stufe> 01`), liest `0x29`, bis die Stufe dreimal gleich ist, und setzt
dann `01 <stufe+offset> 00`. Wird währenddessen etwas angezeigt, bricht sie ab
und stellt die letzte Stufe wieder her.

## Aufnahmen

Die App schaltet das Mikrofon des rechten Bügels ein (`0x0E 01`), dekodiert
das LC3-Audio zu PCM (16 kHz, mono, 16 bit) und schreibt es in eine WAV-Datei
im Cache der App. Kommt drei Sekunden lang kein Audio (z. B. nach einem
Verbindungsabbruch), wird das Mikrofon neu eingeschaltet. Assist funktioniert
während einer Aufnahme weiter; das Mikrofon bleibt dann an.

Beim Stoppen lädt die App die Datei wie das Dashboard von WhisperNotes hoch:
`POST /api/jobs` (multipart, `file`, `kind=standard`, `recorded_at`), mit
`Authorization: Bearer <API-Schlüssel>`, falls gesetzt. WhisperNotes legt die
Zusammenfassung als Notiz vom Typ `meeting` im Standard-Vault von BasaltNotes
ab; der Titel ist Datum und Dateiname („Brillen-Notiz …“).

Der Punkt auf der Brille ist ein Text mit 74 Leerzeichen und `o` (Glyphenbreiten
aus MentraOS: Leerzeichen 6 px). Er wird statt des leeren Textes gezeigt,
wenn die App die Anzeige leert.

## Akku

- Bluetooth-Verbindung mit Priorität „balanced“ (wie MentraOS); „high“ nur,
  solange Assist zuhört.
- Heartbeat alle 8 s wie die offizielle App, Akkuabfrage alle 5 Minuten.
- Nach jedem Text wird die Anzeige geleert und die Brille mit `0x18`
  freigegeben, damit das Display ausgeht.

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
