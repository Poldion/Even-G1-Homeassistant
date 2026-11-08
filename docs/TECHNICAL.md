# Technical details

**English** | [Deutsch](TECHNICAL.de.md)

## Architecture

```
┌──────────────┐  BLE (ScouterKit, 2×)  ┌──────────────────┐  Websocket API  ┌──────────────────────────┐
│  Even G1     │ ◄────────────────────► │  Smartphone app  │ ◄─────────────► │ Home Assistant           │
│  L + R arm   │  host code, events,LC3 │  (Flutter, app/) │  text, gestures,│  + integration even_g1   │
└──────────────┘                        └──────────────────┘  Assist audio   │  + Assist pipeline       │
                                                                             └──────────────────────────┘
```

The glasses run ScouterKit's g1v0 firmware and talk Bluetooth with one
smartphone. The **app** keeps the
connection to both arms, decodes the microphone audio (LC3 → PCM) and
connects to Home Assistant. The **integration** (`custom_components/even_g1`)
provides actions, entities and events and pushes display commands to the app
in real time.

| Path | Content |
| --- | --- |
| `custom_components/even_g1/` | Home Assistant integration |
| `app/` | Flutter app (Android, iOS without notifications) |
| `app/packages/lc3_codec/` | FFI plugin with [google/liblc3](https://github.com/google/liblc3) for the glasses' microphone |
| `tests/` | Tests of the integration (pytest) |
| `app/test/`, `app/test_e2e/` | Tests of the app, end-to-end test against a real HA instance |

## Bluetooth protocol

The glasses run ScouterKit's g1v0 firmware; the app speaks its protocol 5
(`g1_firmware/docs/VM.md`). How the app draws, keeps both eyes in step and
which program it runs on the arms is described in
[SCOUTERKIT.md](SCOUTERKIT.md#technical-details). Versions up to 0.24 also spoke Even's
own protocol; it is no longer part of the app (branch `legacy`, release
v0.24.0).

## Recordings

The app switches on the right arm's microphone (`MIC`), decodes the LC3
audio to PCM (16 kHz, mono, 16 bit) and writes it into a WAV file in the app's
cache. If no audio arrives for three seconds (e.g. after a lost connection),
the microphone is switched on again. Assist keeps working during a
recording; the microphone then stays on.

When stopping, the app uploads the file to WhisperNotes like its dashboard
does: `POST /api/jobs` (multipart, `file`, `kind=standard`, `recorded_at`),
with `Authorization: Bearer <API key>` if set. WhisperNotes stores the
summary as a note of type `meeting` in the default vault of BasaltNotes; the
title is the date and the file name ("Glasses note …").

While the microphone is on, the firmware itself shows a small square in the
top right corner of the right eye.

## Battery

- Bluetooth connection with priority "balanced"; "high" for both arms only
  during Assist: from holding the touch bar until the answer is hidden again
  (at most 3 minutes).
- Battery query every 5 minutes.
- After each text the panels are switched off (`PANEL` 0); the program on
  the arms switches them off as well while the head is down.

## Integration ↔ app

Websocket commands of the integration:

| Command | Purpose |
| --- | --- |
| `even_g1/devices` | List the glasses entries |
| `even_g1/subscribe` | Display commands, configuration and dashboard text as push |
| `even_g1/update_state` | Report the glasses' state (connection, batteries, silent mode, wear state) |
| `even_g1/gesture` | Report a gesture |
| `even_g1/assist_run` | Run the Assist pipeline with audio from the glasses (without end-of-speech detection) |
| `even_g1/dashboard` | Render the dashboard |

The dashboard template is rendered continuously in Home Assistant and only
sent to the app on changes; when you look up the app shows the last received
text immediately.
