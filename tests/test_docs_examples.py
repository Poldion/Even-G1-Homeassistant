"""The templates in docs/DASHBOARD.md render without errors."""

from pathlib import Path
import re

from homeassistant.core import HomeAssistant
from homeassistant.helpers.template import Template

DOC = Path(__file__).parent.parent / "docs" / "DASHBOARD.md"

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

VARIABLES = {
    "kopfzeile": "09:41  ·  Sa, 7. Nov",
    "agenda": "» heute 18:00  Beispieltermin",
    "agenda_mehr": 2,
    "assistent": "Jarvis",
}


async def test_doc_templates_render(hass: HomeAssistant) -> None:
    """Every jinja block of the guide renders and fits a ScouterKit line."""
    for entity_id, (state, attributes) in STATES.items():
        hass.states.async_set(entity_id, state, attributes)
    blocks = re.findall(r"```jinja\n(.*?)```", DOC.read_text(), re.S)
    assert len(blocks) >= 8
    for block in blocks:
        text = Template(block, hass).async_render(VARIABLES, parse_result=False)
        assert text.strip(), block
        for line in text.strip().split("\n"):
            assert len(line) <= 42, (line, block)
