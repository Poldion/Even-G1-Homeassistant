# Project rules

## Two languages, always

The project is bilingual: **English is the main language, German the second**.
Every change that touches text must update **both** languages in the same
commit:

- **Docs:** `README.md` (English) and `README.de.md` (German); every file in
  `docs/` exists as `NAME.md` (English) and `NAME.de.md` (German).
  `CHANGELOG.md` (English) and `CHANGELOG.de.md` (German) get the same entries.
- **App:** user-visible strings live in `app/lib/l10n/app_en.arb` (template)
  and `app/lib/l10n/app_de.arb`; never hard-code UI text. `flutter gen-l10n`
  must report no untranslated messages (CI checks it).
- **Glasses:** texts drawn on the glasses (status, animations, defaults) come
  from the same ARB files.
- **Integration:** `custom_components/even_g1/translations/en.json` and
  `de.json` have the same keys; texts the integration renders for the glasses
  (agenda, default templates) exist in both languages (`lang.py`).
- **Images:** screenshots and renders with text exist in `docs/images/en/` and
  `docs/images/de/` under the same file names.
- **Designs:** a change to a design, animation or layout is re-rendered and
  checked in both languages.
