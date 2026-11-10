# Changelog

**English** | [Deutsch](CHANGELOG.de.md)

All notable changes to the app and the integration. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions follow
[Semantic Versioning](https://semver.org/). From 0.8.0 on, app and
integration share the same version number.

## [Unreleased]

### Changed
- The update channel "Preview" is now called "Beta"; its builds are
  beta builds (GitHub release title "Beta-Build vX.Y.Z.N").

## [0.29.0] - 2026-11-10

### Changed
- Releases that only change the app are now published as GitHub
  pre-releases `app-vX.Y.Z` with the APK only. HACS does not offer them, so
  Home Assistant no longer needs an update and a restart for every app
  update. Releases `vX.Y.Z` (app and integration) come only when the
  integration changed. The app's stable channel installs both kinds.
- This version itself is still a normal release, so that installed apps
  find the new updater.

## [0.28.0] - 2026-11-10

### Added
- Emojis on the glasses: texts, notifications, Assist answers and the
  dashboard show about 1400 emojis (Noto Emoji, monochrome) in the line.
  The app copies each emoji a text needs into the font on the arms once.

## [0.27.0] - 2026-11-10

### Changed
- The automatic brightness with an offset runs on the glasses: the right
  arm's program computes the level from its light sensor and the offset, the
  left arm follows over the arm-to-arm link. The phone no longer takes part,
  and the brightness keeps adapting without it. Firmware without the link
  keeps the previous way through the app.

## [0.26.0] - 2026-11-09

### Added
- While the microphone is on (recording or Assist) a small microphone shows
  in the top right corner of the right eye: the firmware's square is its
  head, the app adds holder, stem and base.
- During a recording the dashboard says `BasaltNotes is recording` in small
  letters on the top left of its frame.

### Changed
- The program on the arms always runs (clock, status line, microphone),
  also without the dashboard on head up.

## [0.25.0] - 2026-11-08

### Removed
- Support for Even's own firmware. The app works only with ScouterKit
  (g1v0); Even's firmware is no longer developed further. Glasses with it
  keep 0.24.x (0.24.0 offers them no newer version); the branch `legacy`
  stays as it is.
- With it: the firmware choice, Even's Bluetooth protocol, the Even AI answer
  mode, the recording dot, the Even dashboard on head up, the display
  distance, the display check of both arms and the app's own auto
  brightness measurement.

### Added
- A one-time notice on start for apps that were paired with Even's firmware:
  this version needs ScouterKit, with Even's firmware use 0.24.x.

## [0.24.0] - 2026-11-08

### Changed
- Last version with support for Even's firmware. Even's firmware is no
  longer developed further; from 0.25.0 on the app supports only ScouterKit.
  Glasses with Even's firmware are not offered 0.25.0 or later: the app
  stays on 0.24.x and says why once.

## [0.23.0] - 2026-11-08

### Added
- The dashboard shows a status line when a connection is impaired:
  `! Home Assistant unreachable` (the app cannot reach Home Assistant), and
  with ScouterKit `! No connection to the phone`, which the glasses notice
  by themselves. The line disappears when the connection is back.

## [0.22.1] - 2026-11-08

### Fixed
- ScouterKit: the display sometimes stayed on with the head down. A restart
  of the program on the arms kept the panel's image, and a lost message
  between the arms left the left eye in the old state. Now each arm switches
  its panel off at start and every 5 seconds while the head is down and the
  app shows nothing, and the right arm repeats its head state to the left
  one every 5 seconds.

## [0.22.0] - 2026-11-07

### Added
- The dashboard's clock runs on the glasses. With ScouterKit the program on
  the arms counts the minutes itself and redraws exactly at the full minute,
  on both eyes and also without a connection to the phone. With Even's
  firmware the app fills in the time. Template variable `clock` (German
  `uhr`); the default header uses it.

### Changed
- Home Assistant no longer sends the dashboard every minute for the clock,
  only when its content changes (less Bluetooth traffic).
- The integration accepts state fields of newer apps instead of refusing the
  whole update.

## [0.21.1] - 2026-11-07

### Fixed
- ScouterKit: looking down sometimes left the dashboard on in one eye. Each
  arm decided on its own from its own tilt sensor, and near the threshold
  the two disagreed. Now the right arm alone decides and tells the left arm
  over the glasses' own arm-to-arm link; both eyes switch 150 ms later at the
  same moment. Firmware without that link keeps the old behaviour.

## [0.21.0] - 2026-11-07

### Added
- ScouterKit, lab design set: Assist's answer appears in a terminal window,
  the assistant's name on the bar (with the page number when the answer
  has several pages), the answer below and a block cursor at its end.

### Changed
- The description of the *Design set* option says that the dashboard has
  its own option (*Dashboard design → Lab*).

## [0.20.0] - 2026-11-07

### Added
- ScouterKit: a **lab design set**, inspired by retro lab terminals (no names
  or logos of existing games):
  - Dashboard design *Lab*: corner brackets, the first line dark on a light
    bar with hazard stripes.
  - Option *Design set → Lab* for the Assist status (brackets, the first line
    on a bar) and the silent mode animation: brackets slide in, the text is
    typed with a block cursor, a scan line wipes the card away; waking up, the
    scan line reveals it again.
  - The program on the arms draws the lab dashboard on head up, pixel for
    pixel like the app.

### Fixed
- ScouterKit: the library's working words overlapped the texts of the
  silent mode animation (found with the renderer before any release).

## [0.19.0] - 2026-11-07

### Added
- English and German everywhere. English is the main language.
  - App: all screens, messages, the log and the texts on the glasses (Assist
    status, listening text, silent mode animation). *Settings → Language*:
    system language (default, English unless the phone is German), English
    or Deutsch.
  - Integration: options and entities follow Home Assistant's language, and
    so do the texts it renders for the glasses (header, appointments,
    to-dos, the default listening text).
  - Template variables with English names: `header`, `agenda`,
    `agenda_more`, `assistant` (the German ones still work).
  - Docs: README, changelog and every guide in English and German
    (`*.de.md`), example images in both languages.

### Changed
- The app starts in English unless the phone is set to German.

## [0.18.0] - 2026-11-07

### Added
- ScouterKit: while you hold the left touch bar, the glasses show a text in
  a frame, for example "Claude is listening …". You set the text as a
  template in the integration's options ("Text while listening", variable
  `assistant`). "One moment …" and the recognized question appear in the
  frame too.
- ScouterKit: designs for the dashboard (option "Dashboard design"): plain,
  frame, card (frame with title) and title. The program on the arms draws
  the same design when you look up.
- ScouterKit: animation for silent mode. When switching it on, a card
  "Silent mode" appears, folds into a line and fades out as a dot. When
  switching it off it opens again ("I'm back"). It runs at 30 frames per
  second on both eyes at the same time, whether you switch silent mode on
  the glasses, in the app or in Home Assistant.

### Technical
- A small library in the memory of each arm (`SkLib`) draws frames with
  bevelled corners and the frames of the animation. The app sends the frames
  ahead as packets that wait for their time (`SLEEP_UNTIL`). Checked frame by
  frame with ScouterKit's interpreter.

## [0.17.0] - 2026-11-07

From this version on, the stable versions come from `main` and support both
firmwares. The old state for Even's firmware only stays in the branch
`legacy` (up to 0.16.5).

### Added
- Support for the replacement firmware
  [ScouterKit (g1v0)](https://github.com/mafik/scouter_kit). The app speaks
  its protocol 5. It draws texts with its own font on the 640 × 480 display
  and maps touch bar, microphone, battery, case, wearing, head tilt and
  brightness to the existing features. Notifications appear as text. In the
  charging case the display stays off. You choose the firmware in the
  settings under *Glasses*. Even's firmware stays the default and works
  unchanged. The app flashes nothing. How to install, which risks there are
  and what is missing is described in `docs/SCOUTERKIT.md`.
- Every state of `main` is published as a pre-release `sk-vX.Y.Z.N` in the
  update channel "Preview" (formerly "ScouterKit").
- ScouterKit: texts and the dashboard use the whole display (11 lines of 42
  characters at the default height instead of 5 of 30). The app reports the
  size to Home Assistant, which adapts agenda and dashboard to it.
- ScouterKit: notifications show the app's icon (Pebble's notification icons
  from ScouterKit, Apache License 2.0).
- ScouterKit: both eyes show a text at the same moment. The app knows the
  clock offset of each arm (`PING`) and lets both draw at the same time with
  `SLEEP_UNTIL`.
- ScouterKit: a program on the arms shows the dashboard when you look up by
  itself, without a detour via the phone, and switches the display off again
  when you look down. The app only writes new dashboard lines.
- ScouterKit: head gestures (nod, head shake) as gestures for Home
  Assistant, can be switched on in the settings under *Display &
  activation*. The right arm recognizes them itself from the gyroscope.
- ScouterKit: holding right is a gesture of its own (`long_press_right`,
  `long_press_right_release`) and no longer starts Assist.
- ScouterKit: auto brightness with offset. The light sensor reports when the
  brightness changes noticeably while something is shown; the app then sets
  the auto level plus offset on both eyes.

### Changed
- The update channel "Stable" now installs the releases from `main` with
  ScouterKit support. With Even's firmware (setting "Even" under *Glasses*,
  the default) the app works as before. The app tells the installed channel
  from the version number.
- The integration needs this app version and vice versa: it accepts the new
  display size and the new gestures.
- ScouterKit: the recording dot `o` is gone, because g1v0 itself shows a
  square top right in the right eye while the microphone is on. The check of
  both arms (`0x39`) and the delayed exit command only apply to Even's
  firmware now.

## [0.16.5] - 2026-11-06

### Added
- The overview shows the firmware version of the glasses, for example
  "Firmware: Even 1.6.6", and both versions if the arms differ. The app
  queries it when connecting with `23 74` (even-g1-companion).

## [0.16.4] - 2026-11-06

### Added
- Update channel under *Settings → Updates*: "Stable" (as before) or
  "ScouterKit". The ScouterKit channel installs the experimental version for
  glasses with the replacement firmware ScouterKit (g1v0). Before switching a
  warning appears: you have to flash this firmware yourself, and that cannot
  be undone.

### Changed
- The APK's build number is now the build time in minutes. That way Android
  accepts every newer build of both channels as an update.

## [0.16.3] - 2026-11-03

### Changed
- Fast Bluetooth connection ("high") during the whole Assist request on both
  arms: from holding the touch bar through processing until the answer is
  hidden (at most 3 minutes). Otherwise "balanced". Before, "high" applied
  only to the right arm and only while the microphone was on, so the answer
  arrived at different speeds on the left and right.

## [0.16.2] - 2026-11-03

### Fixed
- Battery life: the Bluetooth connection ran permanently with high priority
  (the radio chips of both arms woke up every 11–15 ms). Now "balanced" as in
  MentraOS; high only while Assist is listening.
- Auto brightness with offset only measures every two minutes.

## [0.16.1] - 2026-11-03

### Fixed
- After an Assist request (or another text) the next hold no longer started
  Assist until silent mode was switched off and on again. Since 0.13.0 the
  glasses stayed on their Even AI screen after the display was cleared. Now
  the app clears the display immediately with an empty text and releases the
  glasses a second later with the exit command `0x18`.

## [0.16.0] - 2026-11-02

### Added
- Wear detection in Home Assistant: binary sensor "Worn" and switch "Wear
  detection", which switches the glasses' detection (`0x27`) on and off. The
  switch is also in the app under *Display & activation*. As long as the app
  has not changed the setting, it reads the glasses' value (`0x3A`).

## [0.15.1] - 2026-11-02

### Fixed
- Left eye stays empty: like the official app, the app now waits for the left
  arm's answer to each text packet and sends it again if it is missing or
  negative (up to twice). The log then says "L: text unanswered – sent
  again".

## [0.15.0] - 2026-11-02

### Added
- Auto brightness with offset: with "Auto" the brightness slider becomes an
  offset (−50 % to +50 %). The firmware knows no offset (a fixed table from
  the light sensor to the level), so about every minute while nothing is
  shown the app briefly measures in the glasses' auto mode, reads the level
  (`0x29`) and sets level + offset.

## [0.14.0] - 2026-11-02

### Added
- Recordings with the glasses' microphone, started in the app (overview) or
  in Home Assistant (`switch.<name>_recording`). When stopped, the recording
  goes to WhisperNotes (`POST /api/jobs`), which transcribes it, summarizes
  it and stores it in BasaltNotes. Recordings not sent are sent again later.
- Small dot in the top right of the glasses while recording.

## [0.13.0] - 2026-11-02

### Fixed
- No more short flash of "Even AI" when the dashboard or a text disappears.
  The app now clears the display with an empty text (like MentraOS) instead
  of the exit command `0x18`, whose teardown in the firmware sometimes shows
  the Even AI screen.
- Dashboard on one eye only: shortly after showing, the app asks both arms
  what they show and sends the text again to an arm that does not show it.
  The log says "Display left missing – sent again".

## [0.12.1] - 2026-11-02

### Fixed
- Height and distance of the display are now applied. When adjusting, the
  app briefly opens the glasses' position preview and closes it afterwards
  with the command the official app sends too (state `00`); before, the
  glasses stayed in preview mode and the sample text interrupted it.
- Brightness: the glasses know the levels 0–42 (not 0–63), the upper part of
  the slider had no effect. With auto brightness the overview shows the level
  the glasses currently use.

## [0.12.0] - 2026-11-02

### Added
- App: brightness of the glasses on the overview, with a slider and a switch
  for auto brightness. Like in MentraOS the setting is sent to the glasses on
  every connection; as long as it was not changed in the app, the app shows
  the glasses' value.

## [0.11.0] - 2026-11-02

### Fixed
- Dashboard by tapping left/right: the app now shows the dashboard itself
  (as when looking up), without a detour via Home Assistant. Tapping again
  closes it. While another text is shown, tapping pages as before.

### Added
- Diagnostics: packets the glasses send on their own appear in the log
  (`L rx …` / `R rx …`).

### Changed
- App and integration must both be on 0.11.0 for the dashboard by tapping.

## [0.10.0] - 2026-11-02

### Added
- App: self-update like BasaltNotes. Once a day the app looks for a new
  version on the releases page (or via *Settings → App update*), downloads
  the APK and starts the installation.

## [0.9.0] - 2026-11-02

### Added
- Integration: calendars and to-do lists selectable in the options. The
  dashboard shows appointments of today and tomorrow and due to-dos, without
  helpers or YAML.
- Integration: built-in dashboard for one page of the glasses with time,
  date, entities, appointments and to-dos.

### Changed
- The dashboard template is optional; empty means the built-in layout. The
  previous default template (time and sun) is replaced by the new layout.

## [0.8.0] - 2026-11-02

### Added
- App: tabs "Overview" and "Settings". The overview shows connection,
  battery left/right and case (including charging), wear state, silent mode,
  Home Assistant with the chosen assistant and a collapsible preview of the
  glasses' display.
- App: activation angle, height and distance of the text and the Even
  dashboard on head up can be set in the app.
- App: test switch "Assist answers in Even AI mode" in diagnostics.
- Integration: entity "Assistant" to choose the Assist pipeline.
- Integration: dashboard entities as lines "Name: state unit" on the glasses
  dashboard.
- Integration: sensors "Case battery", "State" and "Case charging".
- Releases: signed APK and the integration as ZIP on the releases page.

### Changed
- Glasses settings (angle, position, Even dashboard) moved from the
  integration to the app.
- App and integration have a common version number.

### Fixed
- Battery, case and wear status messages of the glasses no longer arrive in
  Home Assistant as gesture "other" every few seconds.
- Release APKs are signed with a fixed key and can be installed as updates.

## [0.7.0] - 2026-11-01

### Added
- Silent mode, switchable in the app, in Home Assistant (`switch`) and with
  a triple tap.
- Forwarding of phone notifications to the glasses (Android).
- Setting "Even dashboard on head up", check of the display per arm.

### Changed
- While the touch bar is held the glasses show their own listening screen;
  question and answer follow after releasing.

## [0.4.0] - 2026-10-20

### Added
- Dashboard on head up, head tilt angle and dashboard position.

### Changed
- Both arms are written at the same time through a shared queue (like
  MentraOS), text always in text mode.
- Assist runs via the integration without end-of-speech detection, with
  automatic gain and noise suppression.

### Fixed
- Loading the integration under Home Assistant 2026.10.

## [0.1.0] - 2026-10-15

### Added
- First version: integration with actions, notify entity, sensors and
  gesture events; Flutter app with BLE connection to the G1, text display and
  Assist via the glasses' microphone.

[Unreleased]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.29.0...HEAD
[0.29.0]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.28.0...v0.29.0
[0.28.0]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.27.0...v0.28.0
[0.27.0]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.26.0...v0.27.0
[0.26.0]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.25.0...v0.26.0
[0.25.0]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.24.0...v0.25.0
[0.24.0]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.23.0...v0.24.0
[0.23.0]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.22.1...v0.23.0
[0.22.1]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.22.0...v0.22.1
[0.22.0]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.21.1...v0.22.0
[0.21.1]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.21.0...v0.21.1
[0.21.0]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.20.0...v0.21.0
[0.20.0]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.19.0...v0.20.0
[0.19.0]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.18.0...v0.19.0
[0.18.0]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.17.0...v0.18.0
[0.17.0]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.16.5...v0.17.0
[0.16.5]: https://github.com/Poldion/Even-G1-Homeassistant/compare/v0.16.4...v0.16.5
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
