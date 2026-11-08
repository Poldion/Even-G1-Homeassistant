# Technische Details

[English](TECHNICAL.md) | **Deutsch**

## Aufbau

```
┌──────────────┐  BLE (ScouterKit, 2×)  ┌──────────────────┐  Websocket-API  ┌──────────────────────────┐
│  Even G1     │ ◄────────────────────► │  Smartphone-App  │ ◄─────────────► │ Home Assistant           │
│  L + R Bügel │  Host-Code, Events, LC3│  (Flutter, app/) │  Text, Gesten,  │  + Integration even_g1   │
└──────────────┘                        └──────────────────┘  Assist-Audio   │  + Assist-Pipeline       │
                                                                             └──────────────────────────┘
```

Auf der Brille läuft ScouterKits Firmware g1v0; sie spricht Bluetooth mit
einem Smartphone. Die **App** hält die
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

## Bluetooth-Protokoll

Auf der Brille läuft ScouterKits Firmware g1v0; die App spricht deren
Protokoll 5 (`g1_firmware/docs/VM.md`). Wie die App zeichnet, beide Augen im
Takt hält und welches Programm sie auf den Bügeln laufen lässt, steht in
[SCOUTERKIT.de.md](SCOUTERKIT.de.md#technik). Versionen bis 0.24 sprachen
auch Evens eigenes Protokoll; es ist nicht mehr Teil der App (Branch
`legacy`, Release v0.24.0).

## Aufnahmen

Die App schaltet das Mikrofon des rechten Bügels ein (`MIC`), dekodiert
das LC3-Audio zu PCM (16 kHz, mono, 16 bit) und schreibt es in eine WAV-Datei
im Cache der App. Kommt drei Sekunden lang kein Audio (z. B. nach einem
Verbindungsabbruch), wird das Mikrofon neu eingeschaltet. Assist funktioniert
während einer Aufnahme weiter; das Mikrofon bleibt dann an.

Beim Stoppen lädt die App die Datei wie das Dashboard von WhisperNotes hoch:
`POST /api/jobs` (multipart, `file`, `kind=standard`, `recorded_at`), mit
`Authorization: Bearer <API-Schlüssel>`, falls gesetzt. WhisperNotes legt die
Zusammenfassung als Notiz vom Typ `meeting` im Standard-Vault von BasaltNotes
ab; der Titel ist Datum und Dateiname („Brillen-Notiz …“).

Solange das Mikrofon an ist, zeigt die Firmware selbst ein kleines Quadrat
oben rechts im rechten Auge.

## Akku

- Bluetooth-Verbindung mit Priorität „balanced“; „high“ für beide Bügel nur
  während Assist: vom Gedrückthalten bis die Antwort wieder ausgeblendet ist
  (höchstens 3 Minuten).
- Akkuabfrage alle 5 Minuten.
- Nach jedem Text werden die Anzeigen abgeschaltet (`PANEL` 0); das Programm
  auf den Bügeln schaltet sie auch ab, solange der Kopf unten ist.

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
