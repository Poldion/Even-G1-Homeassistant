# Entwicklung

[English](DEVELOPMENT.md) | **Deutsch**

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

# LC3-Decoder (Host-Build)
cd app/packages/lc3_codec
cmake -S src -B build && cmake --build build
LC3_CODEC_LIBRARY=build/liblc3_codec.so flutter test

# End-to-End gegen eine laufende HA-Instanz mit der Integration
cd app
HA_URL=http://localhost:8123 HA_TOKEN=... HA_STT_ENGINE=stt.dein_stt flutter test test_e2e
```

Die Integration wird in CI gegen die älteste unterstützte und die neueste
Home-Assistant-Version getestet (`.github/workflows/integration.yml`).

## Was ein Push auslöst

| Geändert | Workflow | Ergebnis |
| --- | --- | --- |
| `README.md`, `CHANGELOG.md`, `docs/` (außer `DASHBOARD.md`), `.claude/` | – | nichts |
| `docs/DASHBOARD.md` | Integration | Test der Beispiel-Templates |
| `custom_components/`, `tests/` | Integration | Tests, kein Release |
| `app/test/` und andere App-Dateien | App | Analyse, Tests, APK als Artefakt (kein Release) |
| `app/lib/`, `app/assets/`, `app/android/`, `pubspec.*` auf `main` | App, Preview build | zusätzlich Vorabversion `sk-vX.Y.Z.N` |
| – | Release | nur von Hand (*Actions → Release → Run workflow*) |

Steht `[skip ci]` in der Commit-Nachricht, läuft bei diesem Push gar kein
Workflow (eingebaute Funktion von GitHub).

## Versionen und Releases

App und Integration tragen dieselbe Version nach
[Semantic Versioning](https://semver.org/lang/de/):

- `app/pubspec.yaml`: `version: X.Y.Z+N` (`N` bei jeder Veröffentlichung erhöhen)
- `custom_components/even_g1/manifest.json`: `"version": "X.Y.Z"`
- `CHANGELOG.md` und `CHANGELOG.de.md`: Änderungen unter `## [Unreleased]`
  sammeln, auf Englisch und Deutsch

Release erstellen:

1. In beiden Changelogs `[Unreleased]` in `## [X.Y.Z] - JJJJ-MM-TT` umbenennen,
   ein neues leeres `[Unreleased]` darüber anlegen und die Links unten
   ergänzen.
2. Versionen in `pubspec.yaml` und `manifest.json` setzen, committen.
3. Tag `vX.Y.Z` erstellen und pushen (`git tag vX.Y.Z && git push origin vX.Y.Z`)
   oder unter *Actions → Release → Run workflow* den Branch wählen; dann legt
   der Workflow den Tag selbst an.

Der Workflow `.github/workflows/release.yml` prüft, dass Tag, App,
Integration und Changelog übereinstimmen, baut die signierte APK und legt das
Release mit `even-g1-ha-vX.Y.Z.apk`, `even_g1-vX.Y.Z.zip` und den Notizen aus
dem (englischen) Changelog an.

## Signierung der APK

Android installiert ein Update nur, wenn es mit demselben Schlüssel signiert
ist. Der Schlüssel liegt als Repository-Secrets vor:

- `ANDROID_KEYSTORE_BASE64`: Keystore (PKCS12, Alias `even-g1-ha`) als Base64
- `ANDROID_KEYSTORE_PASSWORD`: Passwort von Keystore und Schlüssel

Ohne diese Secrets signieren die normalen CI-Builds mit einem wechselnden
Testschlüssel (nur zum Testen); der Release-Workflow bricht ab.
