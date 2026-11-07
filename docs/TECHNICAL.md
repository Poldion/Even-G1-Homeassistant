# Technical details

**English** | [Deutsch](TECHNICAL.de.md)

## Architecture

```
┌──────────────┐  BLE (2× Nordic UART)  ┌──────────────────┐  Websocket API  ┌──────────────────────────┐
│  Even G1     │ ◄────────────────────► │  Smartphone app  │ ◄─────────────► │ Home Assistant           │
│  L + R arm   │  text, gestures, LC3   │  (Flutter, app/) │  text, gestures,│  + integration even_g1   │
└──────────────┘                        └──────────────────┘  Assist audio   │  + Assist pipeline       │
                                                                             └──────────────────────────┘
```

The glasses only talk Bluetooth with one smartphone. The **app** keeps the
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

## BLE protocol

The basis is the official [EvenDemoApp](https://github.com/even-realities/EvenDemoApp),
extended with findings from [MentraOS](https://github.com/Mentra-Community/MentraOS),
[even-g1-companion](https://github.com/Cheddies1/even-g1-companion) and the
[eveng1 Python SDK](https://github.com/emingenc/even_glasses).

| Command | Meaning |
| --- | --- |
| `0x4E` | Text, text mode `0x71` (5 lines of ~488 px, the app does the paging). Optionally Even AI mode `0x31`/`0x41` |
| `0x0E` | Microphone on/off (right arm) |
| `0xF1` | Microphone audio: LC3, 16 kHz, 10 ms frames, 20 bytes/frame |
| `0xF5` | Events: `00` double tap, `01` tap, `02`/`03` head up/down, `04`/`05` silent mode, `17`/`18` touch bar held/released |
| `0xF5` (status) | `0A` battery glasses, `0F` battery case, `0E` case cable, `06`/`07` put on/taken off, `08`/`0B` in the case open/closed |
| `0x25` | Heartbeat (every 8 s) |
| `0x03` | Silent mode `0C` on / `0A` off |
| `0x08 … 03 <v>` | Even dashboard on head up (`00` show, `02` hide) |
| `0x01 <h> <a>` | Brightness `h` (0–42) and auto brightness `a` (`00`/`01`, light sensor in the right arm); `F5 12 <h>` reports the current level |
| `0x29` | Query brightness (right arm), answer `29 65 <h> <a>` |
| `0x0B` | Activation angle (0–60°) |
| `0x26 08 00 <n> 02 <s> <h> <d>` | Height (0–8) and distance (1–9) of the display; `s` = `01` position preview of the glasses, `00` apply |
| `0x27 <0/1>` / `0x3A` | Wear detection on/off / query (answer `3A C9 <0/1>`); only with it do the glasses report `F5 06`/`07` |
| `0x39` | Query what an arm currently shows (`0x10` = text view); the app uses it to check both arms after every text |
| `0x4B` / `0x04` | Notification / app whitelist (left arm) |

Only part of this is officially documented; the rest comes from community
projects and may differ depending on the firmware.

**Sending to both arms:** as in MentraOS all commands go through a shared
queue. Each packet is written to both arms at the same time (with Bluetooth
acknowledgement) before the next one follows. For texts (`0x4E`) the app
additionally waits, like the official app, for the left arm's answer
(`4E C9`/`CB`, the right one answers later) and resends the packet up to
twice if it is missing or reads `CA`. If an arm rejects a command, the app
log says so (`L/R rejected 0x..`).

**Assist:** while the touch bar is held the firmware shows its own listening
screen (the right arm keeps redrawing it). Afterwards the app shows
"One moment …", the recognized question and the answer on both arms.

## Auto brightness with offset

In auto mode the firmware gradually approaches a fixed table (light sensor in
the right arm → level 0–42, g1-reverse `compute_lux_brightness_bucket`) and
writes the level into the same field that `0x29` reads. There is no offset.
With an offset the app therefore switches auto mode on briefly about every
two minutes while nothing is shown (`01 <level> 01`), reads `0x29` until the
level is the same three times, and then sets `01 <level+offset> 00`. If
something is shown meanwhile it aborts and restores the last level.

## Recordings

The app switches on the right arm's microphone (`0x0E 01`), decodes the LC3
audio to PCM (16 kHz, mono, 16 bit) and writes it into a WAV file in the app's
cache. If no audio arrives for three seconds (e.g. after a lost connection),
the microphone is switched on again. Assist keeps working during a
recording; the microphone then stays on.

When stopping, the app uploads the file to WhisperNotes like its dashboard
does: `POST /api/jobs` (multipart, `file`, `kind=standard`, `recorded_at`),
with `Authorization: Bearer <API key>` if set. WhisperNotes stores the
summary as a note of type `meeting` in the default vault of BasaltNotes; the
title is the date and the file name ("Glasses note …").

The dot on the glasses is a text with 74 spaces and `o` (glyph widths from
MentraOS: a space is 6 px). It is shown instead of the empty text when the
app clears the display.

## Battery

- Bluetooth connection with priority "balanced" (like MentraOS); "high" for
  both arms only during Assist: from holding the touch bar until the answer
  is hidden again (at most 3 minutes).
- Heartbeat every 8 s like the official app, battery query every 5 minutes.
- After each text the display is cleared and the glasses are released with
  `0x18`, so the display turns off.

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
