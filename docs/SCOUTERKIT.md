# ScouterKit (g1v0)

**English** | [Deutsch](SCOUTERKIT.de.md)

[ScouterKit](https://github.com/mafik/scouter_kit) is a free replacement
firmware (`g1v0`) for the two arms of the Even G1. Since 0.25.0 the app
works only with g1v0. Glasses with Even's own firmware need app 0.24.x, the
last version for it; it is no longer developed further.

> **Read all of this before you install anything.** Flashing g1v0 cannot be
> undone, and a mistake can brick an arm. The app itself flashes nothing:
> installing is done with ScouterKit's tools, step by step by hand.

## What changes compared to Even's firmware

| | Even firmware | g1v0 (ScouterKit) |
| --- | --- | --- |
| Official Even app | yes | **no** |
| Even dashboard, Even AI, translation, navigation | yes | no |
| Notifications | the glasses' own display | as a text of the app, with the app's icon |
| Display | 576 × 136 px, 5 lines of ~30 characters | 640 × 480 px, text drawn by the app, 11 lines of 42 characters (default height) |
| Both eyes at the same time | not guaranteed | yes, both draw at the same moment |
| Assist (hold the touch bar), microphone | yes | yes (right arm, LC3 16 kbit/s as before) |
| Tap, double tap | yes | yes |
| Hold right | firmware (QuickNote) | its own gesture for Home Assistant |
| Nod, shake the head | no | yes, can be switched on (gyroscope of the right arm) |
| Triple tap = silent mode | firmware | the app keeps the silent mode |
| Look up (dashboard) | firmware | a program on the arms shows the dashboard itself |
| Wear detection | can be switched on/off | always on |
| Brightness, auto brightness | yes | yes (left follows the right light sensor), with an offset |
| Recording | no indicator | the firmware's square top right in the right eye while the microphone is on |
| Display height and distance | both | height (moves the text block) |
| Updates | via the Even app | only via ScouterKit's tools |

While an arm lies in the charging case the app draws nothing on it: lit
pixels disturb the case's charging link (VM.md §6.6).

## Risks (from ScouterKit's guide, as of 2026-11-05)

- **No way back to your current firmware.** You can only go back to Even's
  public 1.6.6 (or 1.5.6, 1.3.6). Restoring was rehearsed in the emulator and
  on a development board, **not on real glasses**. Even's CJK fonts and demo
  images are lost in the process.
- **An image that does not start Bluetooth bricks the arm.** It can then only
  be rescued by opening it and rewriting it through the debug port. That
  erases the bootloader and the factory settings. Only install images that
  passed ScouterKit's emulator tests (`scripts/gate.sh`).
- **Power loss during the first ~20 s** after confirming: only install with
  charged arms in the case, the case on a USB power supply.
- The project is **very young**: it was published on 2026-11-05 and developed
  on a single pair of glasses (both arms with Even 1.6.3). It was hardly
  tested while wearing the glasses.
- The **warranty** is probably void.
- In the charging case an arm accepts commands and firmware from **any**
  Bluetooth device nearby (as with Even). Outside the case it only obeys
  paired devices.

Points of no return, in this order: (1) pairing the PC with the arms (the
phone loses its pairing), (2) confirming the installation on the left arm,
(3) the same on the right.

## Before

1. **Note your firmware version.** In the Even app under Settings → About the
   glasses. If it is newer than 1.6.6, it is gone for good after the switch.
2. **Fully charge** both arms and the case.
3. Install the app (0.25.0 or later). It works only with g1v0; with Even's
   firmware it does not connect.

## What you need

- A **Linux computer with Bluetooth LE**, tested with BlueZ 5.82. Windows and
  WSL do not work because WSL has no Bluetooth. It works for example with an
  Ubuntu live USB stick on a PC with Bluetooth, a Raspberry Pi 4/5 or a Linux
  laptop.
- To build the image: rootless podman, git, curl and about 4 GB of space.
  Building also works on another Linux computer or in WSL2. You then copy the
  finished image `app_update.bin` to the computer with Bluetooth.
- Python 3.10 or newer with `bleak`, `Pillow` and `pyserial`.

## Install (following ScouterKit's `g1_firmware/README.md`)

The commands run in ScouterKit's `g1_firmware/` folder. Their current guide
is authoritative. Read it before every step, because the project changes
quickly.

```bash
git clone https://github.com/mafik/scouter_kit && cd scouter_kit/g1_firmware
python3 -m venv .venv && .venv/bin/pip install -r ../tools/requirements.txt
scripts/setup.sh build            # once: container, NCS, Even's 1.6.6 images
scripts/build.sh 0.5.60           # version as in ScouterKit's guide
scripts/setup.sh emulator         # once
scripts/gate.sh 0.5.60 all        # ALL tests must pass
```

Then, **one arm after the other, left first**:

1. Glasses in the case, lid open, case on USB. Bluetooth on the phone off.
2. `bluetoothctl`: `agent NoInputNoOutput`, `default-agent`, `pairable on`,
   `scan le` until `Even G1_NN_L_…` appears (note the address), `scan off`,
   `pair LEFT_ADDRESS`, `quit`.
3. Check, nothing is changed:
   `.venv/bin/python flash.py --ble LEFT_ADDRESS --stock list`
4. Install:
   `.venv/bin/python flash.py --ble LEFT_ADDRESS --stock --side L install work/build/g1v0-v0560/zephyr/app_update.bin`
   The tool uploads the image (Even keeps running, cancelling here has no
   consequences yet) and then asks for `yes`. **Only this `yes` is final.**
   Do not take the arm out of the case afterwards. It shows up as `G1v0_L`
   with a **new address**.
5. Pair the PC again (in the case): `bluetoothctl pairable on`, then
   `.venv/bin/python ../tools/arm_pair.py NEW_ADDRESS`.
6. Check: `.venv/bin/python ../tools/g1host.py --ble NEW_ADDRESS hello`
   shows `"proto": 5`. With `... grid --label LEFT --verify` a test grid
   appears in the left lens.
7. Right arm: steps 2–6 with `--side R` and `--label RIGHT`.

One arm with g1v0 next to one with Even's firmware is not supported. Do
both, or restore the first one.

## Connect with the app

1. Put the glasses in the **open charging case** and *Search for glasses*.
   The arms are called `G1v0_L` / `G1v0_R`. Tap the pair.
2. The app pairs the arms only while they are in the case. An arm stores
   three pairings, the PC and the phone both fit.
3. On the first connection after every restart of the arms the app loads its
   font into the arms' memory, which takes a few seconds. The diagnostics log
   shows `Font loaded`.

## Back to Even's firmware

```bash
scripts/fetch_stock.sh 1.6.6
.venv/bin/python flash.py --ble NEW_LEFT_ADDRESS --side L restore 1.6.6
```

Then restore the right arm the same way. Then remove the pairings on the PC
(`bluetoothctl remove ADDRESS`) and pair the glasses again in the Even app.
With Even's firmware this app needs version 0.24.x (uninstall the newer one
first; Android does not install older versions over newer ones).

## Troubleshooting (short version)

- **The arm does not show up after installing:** leave it in the case on USB
  for a few minutes. The bootloader repeats an interrupted copy, a watchdog
  restarts it.
- **It is called `G1v0S_L` / `G1v0S_R`:** it is in safe mode (after three
  failed starts). The display is off, updates work. See ScouterKit's guide
  under *Recovery*.
- **The app does not connect outside the case:** the arm is not paired with
  the phone. Put the glasses in the open case and connect again.
- **The microphone does not work:** g1v0 requires an encrypted connection,
  that is a pairing, also in the case.

## Program on the arms

If the dashboard on head up is set in Home Assistant (or head gestures are
on), the app loads a small program into each arm when connecting and starts
it (`VM_START`, VM.md §5). It lives in the area behind the frame buffer
(`0x35800`–`0x40000`) and runs in RAM only; after a restart of the arm it is
gone, and the app loads it again.

- **Look up** (`TILT`): the program draws the dashboard lines that the app
  wrote into it before, line by line through a band of its own, and shows
  them. When you look down it switches the display off. It draws nothing
  while the app itself shows something (`busy`). It redraws new content on a
  `USER0` from the app if the dashboard is visible. The right arm reports the
  head with `NOTIFY 1, 1/0`.
- **Clock** (`TIMER`, `USER1`): the app writes where the dashboard's
  `HH:MM` digits are, the arm time when the current minute began and which
  minute of the day it is. The program counts on at each full minute (also
  without the phone), writes the digits (glyphs 0–9) and redraws if the
  dashboard is shown. The app sets the time again after each clock sync
  (every 3 minutes).
- **Emojis**: the font on the arms has 160 empty glyph slots after its own
  glyphs. When a text contains an emoji, the app copies its 1-bit glyph
  (Noto Emoji, 22 px, from `app/assets/scouter/emoji_22.skf`) into a free
  slot on both arms (about 75 bytes) and encodes the emoji with that glyph,
  so `GLYPHS` draws it in the line, in the app's texts and in the program's
  dashboard alike. When the slots run full they are filled anew.
- **Microphone and label** (`USER3`, right arm): while the microphone is on
  the program draws a stand (holder, stem, base) under the 16 × 16 square
  that the firmware draws at (620, 4) (VM.md §6.5, it cannot be changed or
  hidden), also after a `PANEL` = 0, which the microphone keeps from
  switching the panel off. A label in the font at its own size (11 px,
  uploaded with the 22-px font) stands on the frame's top line while a
  recording runs.
- **Connection symbols**: a phone and a server at the dashboard's top
  right (mirrored from the recording label), drawn with `FILL`; `LINE`
  strikes the server through while the app reports Home Assistant
  unreachable (`USER2`), and both while the arm's own `LINK` is 0. It
  checks again every 5 s.
- **Watch** (every 5 s): each arm switches its panel off while the head is
  down and the app shows nothing (also right after a restart, which keeps
  the panel's image), and the right arm repeats its head state to the left
  one. A lost message or a restart heals itself within 5 seconds.
- **Head check** (every 0.4 s while the dashboard shows): `TILT` fires only
  when the pitch *leaves* its range, so a head that went down while the
  dashboard was being drawn would never fire. After setting a new range the
  program therefore reads the pitch again and decides at once, and while
  the head is up each arm reads the pitch itself; below the angle minus the
  hysteresis (left arm: 10° more, the right one decides) the dashboard goes
  off.
- **Both eyes together** (arm-to-arm link, VM.md §6.9): only the right arm
  follows the tilt. On a change it sends `PEER_SEND` 1 (up) or 2 (down) to
  the left arm and switches 150 ms later; the left arm's `PEER` handler
  switches at the sender's time plus the same 150 ms (`PEER_T_US`). Two arms
  with their own sensors no longer disagree near the threshold. Firmware
  without the link (`HELLO` triggers bit 9 clear): each arm decides itself.
- **Head gestures** (right arm, `TIMER` every 20 ms): gyroscope at 52 Hz. A
  swing counts from 90 °/s and if it is at least twice as fast as around the
  other axis; two changes of direction around the x axis within 0.4 s are a
  nod, three around the y axis a head shake (`NOTIFY 2, 1/2`).
- The program was checked with ScouterKit's interpreter (`src/vm`): looking
  up and down, a busy display, nodding, shaking the head, slow and diagonal
  movements.

## Designs and animations

Together with the font the app loads a small library into each arm
(`app/lib/scouter/sk_lib.dart`, `0x3E000`–`0x3F400`). Packets call it with
`CALL`:

- `box` draws a frame with bevelled corners (two pixels wide) into the frame
  buffer. The dashboard designs, the text while listening and the Assist
  status messages are made from it. The program on the arms draws the same
  frames band by band from rectangles; both ways give the same image in the
  interpreter.
- `scene` draws one frame of an animation: clear a region, the frame, up to
  two text lines, then show only that region (`DRAW`, about 10 ms). The app
  sends all frames ahead as packets that wait for their time in the clock of
  the respective arm with `SLEEP_UNTIL`. That way both eyes run at 30 frames
  per second at the same time, independent of the radio link (VM.md §7). One
  frame costs about 70 bytes.
- `rects` draws a list of rectangles. The scene draws a static list (the
  lab set's brackets and bar) before its box and a dynamic one (cursor, scan
  line, a dark mask) after its texts; a frame can also show only the first
  bytes of a text (typing). The lab dashboard's dark title is text of level
  0 on a light bar (`GLYPHS` in `MASK` mode), in the app and in the program on
  the arms alike.

## Technical details

The app speaks ScouterKit's protocol 5 (`g1_firmware/docs/VM.md`):

- Service `f3da4d59-…4400`: `CMD` (packets with commands), `CTRL` (control
  requests), `EVT` (events).
- Packets have a sequence number. The app sends at most as many as the arm
  has granted (32). It resends gaps that the selective acknowledgement
  reports, and packets unacknowledged after a timeout (RFC 6298)
  (`app/lib/scouter/sk_link.dart`).
- Text: once per session the app loads the font *Departure Mono* (OFL
  license, 11 px, doubled to 22 px, Latin characters and punctuation only,
  422 characters in about 16 KB) into the memory of each arm. Per text `FILL`
  clears the frame buffer, `GLYPHS` draws each line and `DRAW` shows the image
  at once. Hiding switches the display off completely with `PANEL` = 0,
  because even a black display that is switched on draws power.
- Events: touch bar, wearing, battery and case arrive as `INPUT`. The right
  arm reports the head tilt as soon as it leaves a range the app sets.
- Microphone: `MIC` at 16 kbit/s. The arms release it after 2 s by
  themselves, so the app renews the grant every 0.8 s.
- Both eyes at the same time: the app measures the clock offset of each arm
  with `PING` (every 3 minutes), prepares the image on both and then sends
  each `SLEEP_UNTIL T` + `DRAW`, with `T` in the arm's clock (VM.md §7).
- Brightness with offset, on the glasses: the right arm's program handles
  `LIGHT` itself. When the light leaves the range ±25 % (at least ±2 lux)
  around the last reading, it computes stock's level from the firmware's
  table, adds the offset, clamps it to 0–42, writes `BRIGHTNESS` and sets the
  next range; the watch repeats it every 5 s. The left arm runs
  `AUTO_BRIGHTNESS` = 1 and takes the right arm's level over their link
  (VM.md §6.9). No phone is needed. Firmware without the link: the app does
  it from the `LIGHT` events as before.
- A new *epoch* means the arm restarted and its memory is empty. The app then
  sets it up again and loads the font again.
