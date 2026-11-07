"""The templates in docs/DASHBOARD.md render without errors."""

from pathlib import Path
import re

from homeassistant.core import HomeAssistant
from homeassistant.helpers.template import Template

DOCS = [
    Path(__file__).parent.parent / "docs" / name
    for name in ("DASHBOARD.md", "DASHBOARD.de.md")
]

STATES = {
    "weather.zuhause": ("cloudy", {"temperature": 8.2}),
    "sensor.wohnzimmer_temperatur": ("21.5", {}),
    "sensor.aussen_temperatur": ("8.1", {}),
    "binary_sensor.fenster_kueche": ("on", {"device_class": "window"}),
    "binary_sensor.haustuer": ("on", {"device_class": "door"}),
    "light.flur": ("on", {}),
    "sensor.waschmaschine_status": ("fertig", {}),
    "sensor.handy_akku": ("15", {}),
    "sensor.pv_leistung": ("3420", {}),
    "sensor.netz_leistung": ("-2540", {}),
    "sensor.speicher_ladestand": ("76", {}),
    "sensor.regenwahrscheinlichkeit": ("20", {}),
    "sensor.handy_naechster_wecker": ("2026-11-08T06:30:00+00:00", {}),
    "sensor.fahrzeit_arbeit": ("24", {}),
    "sensor.auto_ladestand": ("80", {}),
    "sensor.auto_reichweite": ("310", {}),
}

# The integration provides English and German names (device.py).
VARIABLES = {
    "header": "09:41  ·  Sat, Nov 7",
    "kopfzeile": "09:41  ·  Sa, 7. Nov",
    "agenda": "» today 18:00  Example appointment",
    "agenda_more": 2,
    "agenda_mehr": 2,
    "assistant": "Jarvis",
    "assistent": "Jarvis",
}


async def test_doc_templates_render(hass: HomeAssistant) -> None:
    """Every jinja block of the guide renders and fits a ScouterKit line."""
    for entity_id, (state, attributes) in STATES.items():
        hass.states.async_set(entity_id, state, attributes)
    for doc in DOCS:
        if not doc.exists():
            continue
        blocks = re.findall(r"```jinja\n(.*?)```", doc.read_text(), re.S)
        assert len(blocks) >= 8, doc
        _render_all(hass, blocks)


def _render_all(hass: HomeAssistant, blocks: list[str]) -> None:
    for block in blocks:
        text = Template(block, hass).async_render(VARIABLES, parse_result=False)
        assert text.strip(), block
        for line in text.strip().split("\n"):
            assert len(line) <= 42, (line, block)
