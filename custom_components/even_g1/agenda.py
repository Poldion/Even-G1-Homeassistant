"""Appointments and to-dos for the glasses dashboard.

The selected calendars and to-do lists are read with the official
``calendar.get_events`` and ``todo.get_items`` actions and turned into short
lines that fit the G1 display (5 lines of about 30 characters per page),
in Home Assistant's language (lang.py).
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
import logging
from typing import Any

from homeassistant.core import HomeAssistant
from homeassistant.exceptions import HomeAssistantError
from homeassistant.util import dt as dt_util

from .lang import EN, Words

_LOGGER = logging.getLogger(__name__)

# Characters per display line that safely fit without wrapping with Even's
# firmware; the app reports the real width (ScouterKit: 42).
LINE_WIDTH = 30


@dataclass(frozen=True)
class AgendaEvent:
    """A calendar event (all-day events use dates, end exclusive)."""

    summary: str
    start: date | datetime
    end: date | datetime

    @property
    def all_day(self) -> bool:
        """Return True for all-day events."""
        return not isinstance(self.start, datetime)

    @property
    def start_date(self) -> date:
        """Return the local start date."""
        return self.start.date() if isinstance(self.start, datetime) else self.start


@dataclass(frozen=True)
class AgendaTodo:
    """An open to-do item with a due date."""

    summary: str
    due: date | datetime

    @property
    def due_date(self) -> date:
        """Return the local due date."""
        return self.due.date() if isinstance(self.due, datetime) else self.due


def _parse(value: Any) -> date | datetime | None:
    """Parse an ISO date or datetime from a service response."""
    if not isinstance(value, str):
        return None
    if "T" in value:
        parsed = dt_util.parse_datetime(value)
        return dt_util.as_local(parsed) if parsed else None
    return dt_util.parse_date(value)


async def async_fetch_events(
    hass: HomeAssistant, entity_ids: list[str], now: datetime
) -> list[AgendaEvent]:
    """Return the events of today and tomorrow."""
    entity_ids = [e for e in entity_ids if hass.states.get(e) is not None]
    if not entity_ids:
        return []
    start = dt_util.start_of_local_day(now)
    response = await hass.services.async_call(
        "calendar",
        "get_events",
        {"start_date_time": start, "end_date_time": start + timedelta(days=2)},
        target={"entity_id": entity_ids},
        blocking=True,
        return_response=True,
    )
    events = []
    for result in (response or {}).values():
        for item in result.get("events", []):
            start_value, end_value = _parse(item.get("start")), _parse(item.get("end"))
            if start_value is None or end_value is None:
                continue
            events.append(
                AgendaEvent(str(item.get("summary") or ""), start_value, end_value)
            )
    return events


async def async_fetch_todos(
    hass: HomeAssistant, entity_ids: list[str]
) -> list[AgendaTodo]:
    """Return the open to-do items that have a due date."""
    entity_ids = [e for e in entity_ids if hass.states.get(e) is not None]
    if not entity_ids:
        return []
    response = await hass.services.async_call(
        "todo",
        "get_items",
        {"status": ["needs_action"]},
        target={"entity_id": entity_ids},
        blocking=True,
        return_response=True,
    )
    todos = []
    for result in (response or {}).values():
        for item in result.get("items", []):
            if (due := _parse(item.get("due"))) is not None:
                todos.append(AgendaTodo(str(item.get("summary") or ""), due))
    return todos


async def async_fetch(
    hass: HomeAssistant, calendars: list[str], todo_lists: list[str], now: datetime
) -> tuple[list[AgendaEvent], list[AgendaTodo]] | None:
    """Fetch events and to-dos, None if Home Assistant refused the request."""
    try:
        return (
            await async_fetch_events(hass, calendars, now),
            await async_fetch_todos(hass, todo_lists),
        )
    except HomeAssistantError as err:
        _LOGGER.debug("Could not read calendars or to-do lists: %s", err)
        return None


def _line(prefix: str, text: str, suffix: str = "", width: int = LINE_WIDTH) -> str:
    """Return one display line; the text is shortened, never the labels."""
    room = width - len(prefix) - len(suffix)
    text = " ".join(text.split())
    if len(text) > room:
        text = text[: max(room - 2, 1)].rstrip() + ".."
    return f"{prefix}{text}{suffix}"


def _day_label(day: date, today: date, w: Words = EN) -> str:
    """Return "today", "tomorrow", a weekday or a date."""
    days = (day - today).days
    if days == 0:
        return w.today
    if days == 1:
        return w.tomorrow
    if 1 < days < 7:
        return w.weekdays[day.weekday()]
    return day.strftime(w.short_date)


def event_lines(
    events: list[AgendaEvent],
    now: datetime,
    width: int = LINE_WIDTH,
    w: Words = EN,
) -> list[str]:
    """Return the lines for today's remaining and tomorrow's events."""
    today = now.date()
    tomorrow = today + timedelta(days=1)

    def sort_key(event: AgendaEvent) -> tuple[date, bool, time]:
        start_time = time.min if event.all_day else event.start.time()  # type: ignore[union-attr]
        return (max(event.start_date, today), not event.all_day, start_time)

    lines = []
    for event in sorted(events, key=sort_key):
        if event.all_day:
            if event.end <= today or event.start > tomorrow:  # type: ignore[operator]
                continue
            label = w.today if event.start <= today else w.tomorrow  # type: ignore[operator]
        else:
            start, end = event.start, event.end
            assert isinstance(start, datetime) and isinstance(end, datetime)
            if end <= now or start.date() > tomorrow:
                continue
            if start <= now:
                label = f"{w.until} {end:%H:%M}"
                if end.date() != today:
                    label = f"{w.until} {_day_label(end.date(), today, w)}"
            elif start.date() == today:
                label = f"{start:%H:%M}"
            else:
                label = f"{w.tomorrow} {start:%H:%M}"
        lines.append(_line(f"» {label}  ", event.summary, width=width))
    return lines


def todo_lines(
    todos: list[AgendaTodo],
    now: datetime,
    width: int = LINE_WIDTH,
    w: Words = EN,
) -> list[str]:
    """Return the lines for to-dos, the most urgent first."""
    today = now.date()

    def sort_key(todo: AgendaTodo) -> tuple[date, time]:
        due_time = todo.due.time() if isinstance(todo.due, datetime) else time.min
        return (todo.due_date, due_time)

    lines = []
    for todo in sorted(todos, key=sort_key):
        if isinstance(todo.due, datetime):
            overdue = todo.due < now
            label = (
                todo.due.strftime(w.short_date)
                if todo.due_date < today
                else f"{_day_label(todo.due_date, today, w)} {todo.due:%H:%M}"
            )
        else:
            overdue = todo.due < today
            label = _day_label(todo.due, today, w)
        lines.append(
            _line("[!] " if overdue else "[ ] ", todo.summary, f" · {label}", width)
        )
    return lines


def agenda(
    events: list[AgendaEvent],
    todos: list[AgendaTodo],
    now: datetime,
    slots: int,
    width: int = LINE_WIDTH,
    w: Words = EN,
) -> tuple[list[str], int]:
    """Return up to ``slots`` lines of at most ``width`` characters and the
    number of entries left out.

    Events come first, but one slot is kept for to-dos if there are any.
    """
    ev_lines = event_lines(events, now, width, w)
    todo_lines_ = todo_lines(todos, now, width, w)
    slots = max(slots, 0)
    n_events = max(min(len(ev_lines), slots - min(len(todo_lines_), 1)), 0)
    n_todos = min(len(todo_lines_), slots - n_events)
    shown = ev_lines[:n_events] + todo_lines_[:n_todos]
    return shown, len(ev_lines) + len(todo_lines_) - len(shown)


def header(
    now: datetime, more: int = 0, w: Words = EN, clock: str | None = None
) -> str:
    """Return "14:35  ·  Mon, Nov 2" (plus "  ·  +N" if entries were left out).

    ``clock`` replaces the time (a placeholder the app fills in).
    """
    day = w.date.format(day=now.day, month=w.months[now.month - 1])
    time = clock if clock is not None else f"{now:%H:%M}"
    text = f"{time}  ·  {w.weekdays[now.weekday()]}, {day}"
    return f"{text}  ·  +{more}" if more else text
