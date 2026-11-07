"""Texts the integration renders for the glasses, in English and German.

The language follows Home Assistant's (Settings → System → General):
German for "de…", English for everything else. Every entry must exist in
both languages.
"""

from __future__ import annotations

from dataclasses import dataclass

from homeassistant.core import HomeAssistant


@dataclass(frozen=True)
class Words:
    """Words and formats of one language."""

    weekdays: tuple[str, ...]
    months: tuple[str, ...]
    today: str
    tomorrow: str
    until: str
    # Header: "{time}  ·  {weekday}, {date}"; date from day and month.
    date: str
    # Short date of a due day that is a week or more away.
    short_date: str
    listening: str


EN = Words(
    weekdays=("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"),
    months=(
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec",
    ),  # fmt: skip
    today="today",
    tomorrow="tomorrow",
    until="until",
    date="{month} {day}",
    short_date="%m/%d",
    listening="{{ assistant }}\nis listening …",
)

DE = Words(
    weekdays=("Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"),
    months=(
        "Jan",
        "Feb",
        "März",
        "Apr",
        "Mai",
        "Juni",
        "Juli",
        "Aug",
        "Sep",
        "Okt",
        "Nov",
        "Dez",
    ),  # fmt: skip
    today="heute",
    tomorrow="morgen",
    until="bis",
    date="{day}. {month}",
    short_date="%d.%m.",
    listening="{{ assistant }}\nhört zu …",
)


def words(language: str | None) -> Words:
    """Return the words for a language code such as "de" or "en-GB"."""
    return DE if (language or "").lower().startswith("de") else EN


def hass_words(hass: HomeAssistant) -> Words:
    """Return the words for Home Assistant's language."""
    return words(hass.config.language)
