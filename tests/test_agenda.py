"""Tests for the dashboard lines built from calendars and to-dos."""

from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from custom_components.even_g1.agenda import AgendaEvent, AgendaTodo, agenda, header

TZ = ZoneInfo("Europe/Berlin")
NOW = datetime(2026, 11, 2, 10, 0, tzinfo=TZ)  # Monday
TODAY = NOW.date()


def at(days: int, hour: int, minute: int = 0) -> datetime:
    """Return a local time relative to today."""
    return datetime.combine(
        TODAY + timedelta(days=days), datetime.min.time(), TZ
    ).replace(hour=hour, minute=minute)


def day(days: int) -> date:
    """Return a date relative to today."""
    return TODAY + timedelta(days=days)


EVENTS = [
    AgendaEvent("Vorbei", at(0, 8), at(0, 9)),
    AgendaEvent("Übermorgen", at(2, 9), at(2, 10)),
    AgendaEvent("Teammeeting", at(1, 9), at(1, 10)),
    AgendaEvent("Urlaub", day(1), day(3)),
    AgendaEvent("Spät-Call mit dem Team aus Hamburg", at(0, 23), at(0, 23, 30)),
    AgendaEvent("Geburtstag Anna", day(0), day(1)),
    AgendaEvent("Nachtschicht", at(-1, 22), at(0, 11)),
]
TODOS = [
    AgendaTodo("Reifenwechsel", day(10)),
    AgendaTodo("Müll raus", day(1)),
    AgendaTodo("Steuererklärung abgeben", day(-2)),
    AgendaTodo("Paket abholen", at(0, 18)),
    AgendaTodo("Anrufen", at(0, 9)),
]


def test_header() -> None:
    """Time and German date, plus the number of hidden entries."""
    assert header(NOW) == "10:00  ·  Mo, 2. Nov"
    assert header(NOW, 3) == "10:00  ·  Mo, 2. Nov  ·  +3"


def test_events_only() -> None:
    """Events of today and tomorrow, all-day first, finished ones dropped."""
    lines, more = agenda(EVENTS, [], NOW, 10)
    assert lines == [
        "» heute  Geburtstag Anna",
        "» bis 11:00  Nachtschicht",
        "» 23:00  Spät-Call mit dem T..",
        "» morgen  Urlaub",
        "» morgen 09:00  Teammeeting",
    ]
    assert more == 0


def test_todos_only() -> None:
    """To-dos sorted by due date; overdue ones are marked."""
    lines, more = agenda([], TODOS, NOW, 4)
    assert lines == [
        "[!] Steuererklärung.. · 31.10.",
        "[!] Anrufen · heute 09:00",
        "[ ] Paket abho.. · heute 18:00",
        "[ ] Müll raus · morgen",
    ]
    assert more == 1


def test_one_slot_kept_for_todos() -> None:
    """Events come first, but at least one to-do is shown."""
    lines, more = agenda(EVENTS, TODOS, NOW, 4)
    assert len(lines) == 4
    assert lines[2].startswith("» 23:00")
    assert lines[3].startswith("[!] Steuer")
    assert more == 2 + 4
    assert agenda(EVENTS, TODOS, NOW, 0) == ([], 10)
    assert agenda([], [], NOW, 4) == ([], 0)


def test_lines_fit_the_display() -> None:
    """No line is longer than 30 characters."""
    lines, _ = agenda(EVENTS, TODOS, NOW, 20)
    assert all(len(line) <= 30 for line in lines)
