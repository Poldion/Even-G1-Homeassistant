"""Merges lib/l10n/parts/*_en.arb and *_de.arb into app_en.arb / app_de.arb.

Temporary helper while the app is moved to ARB files in parallel; keys of a
part win over the base files.
"""

import json
from pathlib import Path

L10N = Path(__file__).resolve().parent.parent / "lib" / "l10n"

for lang in ("en", "de"):
    base = json.loads((L10N / f"app_{lang}.arb").read_text())
    for part in sorted((L10N / "parts").glob(f"*_{lang}.arb")):
        base.update(json.loads(part.read_text()))
    locale = base.pop("@@locale")
    keys = sorted(k for k in base if not k.startswith("@"))
    out = {"@@locale": locale}
    for k in keys:
        out[k] = base[k]
        if f"@{k}" in base:
            out[f"@{k}"] = base[f"@{k}"]
    (L10N / f"app_{lang}.arb").write_text(
        json.dumps(out, ensure_ascii=False, indent=2) + "\n"
    )
