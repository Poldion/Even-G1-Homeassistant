# Development

**English** | [Deutsch](DEVELOPMENT.de.md)

## Tests

```sh
# Integration
pip install -r requirements_test.txt
python scripts/install_ha_test_requirements.py
pytest

# App
cd app
flutter pub get
flutter analyze && flutter test

# LC3 decoder (host build)
cd app/packages/lc3_codec
cmake -S src -B build && cmake --build build
LC3_CODEC_LIBRARY=build/liblc3_codec.so flutter test

# End to end against a running HA instance with the integration
cd app
HA_URL=http://localhost:8123 HA_TOKEN=... HA_STT_ENGINE=stt.your_stt flutter test test_e2e
```

CI tests the integration against the oldest supported and the newest Home
Assistant version (`.github/workflows/integration.yml`).

### Program and app in agreement

The glasses' program shows the dashboard on head up only while the app
shows nothing (`busy` = 0), the dashboard is on (`flags`) and it has lines
(`count` > 0). A word left wrong keeps the dashboard away until the app
restarts. `app/test/consistency_test.dart` plays random sequences of
everything the app reacts to (notifications, texts, taps, head movements,
Assist, microphone, silent mode, the video player, settings from Home
Assistant, the minute check) through the real `Bridge` and `ScouterConnection` against simulated
arms (`app/test/fake_arms.dart`, with fake time) and checks these words
after every step. A failure names the seed and the last steps.

A new feature that draws on the glasses, switches something on them or
writes the program's words gets an entry in `_Scenario.actions` (and, if
it adds a state, a rule in `check`). Before relying on a new rule, break
the code on purpose once and see the test fail.

## Texts in two languages

English is the main language, German the second (see `CLAUDE.md`). App texts
live in `app/lib/l10n/app_en.arb` (template) and `app_de.arb`; widgets and
other code read them through `tr` (`app/lib/l10n/l10n.dart`). After changing
them run `mkdir -p build && flutter gen-l10n` in `app/` and commit
`lib/l10n/gen`; CI fails on untranslated messages. The integration's texts
are in `translations/en.json` and `de.json`, the texts it renders for the
glasses in `lang.py`. Docs exist as `NAME.md` and `NAME.de.md`, images under
`docs/images/en/` and `docs/images/de/`.

## What a push triggers

| Changed | Workflow | Result |
| --- | --- | --- |
| `README.md`, `CHANGELOG.md`, `docs/` (except `DASHBOARD.md`), `.claude/` | – | nothing |
| `docs/DASHBOARD.md` | Integration | test of the example templates |
| `custom_components/`, `tests/` | Integration | tests, no release |
| `app/test/` and other app files | App | analysis, tests, APK as artifact (no release) |
| `app/lib/`, `app/assets/`, `app/android/`, `pubspec.*` on `main` | App, Beta build | additionally a beta build `sk-vX.Y.Z.N` (pre-release) |
| – | Release | only by hand (*Actions → Release → Run workflow*) |

If the commit message contains `[skip ci]`, no workflow runs for that push
(a built-in GitHub feature).

## Versions and releases

App and integration share one version following
[Semantic Versioning](https://semver.org/):

- `app/pubspec.yaml`: `version: X.Y.Z+N` (increase `N` with every release)
- `custom_components/even_g1/manifest.json`: `"version": "X.Y.Z"`
- `CHANGELOG.md` and `CHANGELOG.de.md`: collect changes under
  `## [Unreleased]`, in English and German

Create a release:

1. In both changelogs rename `[Unreleased]` to `## [X.Y.Z] - YYYY-MM-DD`,
   add a new empty `[Unreleased]` above it and extend the links at the
   bottom.
2. Set the versions in `pubspec.yaml` and `manifest.json`, commit.
3. Create and push the tag `vX.Y.Z` (`git tag vX.Y.Z && git push origin vX.Y.Z`)
   or choose the branch under *Actions → Release → Run workflow*; then the
   workflow creates the tag itself.

The workflow `.github/workflows/release.yml` checks that tag, app,
integration and changelog agree, builds the signed APK and creates the
release with the notes from the (English) changelog, of one of two kinds
(input *kind*, default *auto*):

- **integration** – `vX.Y.Z` with `even-g1-ha-vX.Y.Z.apk` and
  `even_g1-vX.Y.Z.zip`; HACS offers it as an update.
- **app** – pre-release `app-vX.Y.Z` with `even-g1-ha-app-vX.Y.Z.apk` only;
  HACS ignores pre-releases, the app's stable channel installs it.

*auto* chooses *integration* if anything under `custom_components/` changed
since the last `vX.Y.Z` release (the version in `manifest.json` aside), else
*app*. The version stays one number for both.

## App icon

The icon (green glasses on a near-black ground, a house in the left lens,
display lines in the right one; the
status bar icon in white) is generated: change `scripts/make_app_icon.py`,
then run `python3 scripts/make_app_icon.py app/android/app/src/main/res
preview.png` (needs Pillow) and commit the files in `res/`.

## Signing the APK

Android only installs an update if it is signed with the same key. The key
is stored as repository secrets:

- `ANDROID_KEYSTORE_BASE64`: keystore (PKCS12, alias `even-g1-ha`) as Base64
- `ANDROID_KEYSTORE_PASSWORD`: password of keystore and key

Without these secrets the normal CI builds sign with a changing test key
(for testing only); the release workflow aborts.
