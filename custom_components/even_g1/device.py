"""Runtime state of one pair of G1 glasses (one config entry)."""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import datetime, timedelta
import logging
from typing import Any

from homeassistant.components import assist_pipeline
from homeassistant.components.assist_pipeline.error import PipelineError
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import CALLBACK_TYPE, HomeAssistant, callback
from homeassistant.exceptions import HomeAssistantError, TemplateError
from homeassistant.helpers.event import (
    TrackTemplate,
    TrackTemplateResult,
    async_track_state_change_event,
    async_track_template_result,
    async_track_time_change,
    async_track_time_interval,
)
from homeassistant.helpers.template import Template
from homeassistant.util import dt as dt_util

from . import agenda
from .const import (
    CMD_CLEAR,
    CMD_CONFIG,
    CMD_DASHBOARD,
    CMD_RELOAD,
    CMD_SHOW_TEXT,
    CMD_SILENT_MODE,
    CONF_ASSIST_PIPELINE,
    CONF_AUTO_GAIN,
    CONF_DASHBOARD_CALENDARS,
    CONF_DASHBOARD_ENTITIES,
    CONF_DASHBOARD_GESTURE,
    CONF_DASHBOARD_TEMPLATE,
    CONF_DASHBOARD_TODOS,
    CONF_DISPLAY_DURATION,
    CONF_NOISE_SUPPRESSION,
    CONF_SHOW_TRANSCRIPT,
    DASHBOARD_GESTURE_NONE,
    DEFAULT_AUTO_GAIN,
    DEFAULT_DISPLAY_DURATION,
    DEFAULT_NOISE_SUPPRESSION,
    EVENT_ASSIST,
    EVENT_GESTURE,
    GESTURE_HEAD_UP,
    LEGACY_DASHBOARD_TEMPLATE,
    MODE_SCREEN,
    PIPELINE_PREFERRED,
)

_LOGGER = logging.getLogger(__name__)

# One dashboard line per selected entity: "Name: state unit".
_ENTITY_LINE = (
    "{{ state_attr('ENTITY', 'friendly_name') or 'ENTITY' }}: "
    "{{ state_translated('ENTITY') }}"
    "{% if state_attr('ENTITY', 'unit_of_measurement') %} "
    "{{ state_attr('ENTITY', 'unit_of_measurement') }}{% endif %}"
)

# The display shows 5 lines per page: header plus 4 lines.
_PAGE_LINES = 5
_AGENDA_REFRESH = timedelta(minutes=5)


type EvenG1ConfigEntry = ConfigEntry[EvenG1Device]


@dataclass
class EvenG1State:
    """State reported by the companion app."""

    glasses_connected: bool = False
    silent_mode: bool | None = None
    battery_case: int | None = None
    case_charging: bool | None = None
    wear_state: str | None = None
    battery_left: int | None = None
    battery_right: int | None = None
    last_query: str | None = None
    last_response: str | None = None
    extra: dict[str, Any] = field(default_factory=dict)


class EvenG1Device:
    """Bridge between Home Assistant and the companion app of one glasses pair.

    The app keeps a websocket subscription open (``even_g1/subscribe``).
    Display commands are pushed through that subscription, state and gestures
    are reported back through the other ``even_g1/*`` websocket commands.
    """

    def __init__(self, hass: HomeAssistant, entry: EvenG1ConfigEntry) -> None:
        """Initialize."""
        self.hass = hass
        self.entry = entry
        self.state = EvenG1State()
        self._subscribers: dict[int, Callable[[dict[str, Any]], None]] = {}
        self._listeners: list[CALLBACK_TYPE] = []
        self._gesture_listeners: list[Callable[[str, dict[str, Any]], None]] = []
        self._next_subscriber_id = 0
        # Device registry id, set in async_setup_entry.
        self.device_id: str | None = None
        self._dashboard_tracker: Any = None
        self._minute_unsub: CALLBACK_TYPE | None = None
        self.dashboard_text: str = ""
        # Calendars and to-do lists (refreshed in the background).
        self._agenda_events: list[agenda.AgendaEvent] = []
        self._agenda_todos: list[agenda.AgendaTodo] = []
        self._agenda_unsubs: list[CALLBACK_TYPE] = []
        # Shared with the template tracker, updated in place.
        self._dashboard_variables: dict[str, Any] = {}

    @property
    def entry_id(self) -> str:
        """Return the config entry id (used by the app to address us)."""
        return self.entry.entry_id

    @property
    def name(self) -> str:
        """Return the name of the glasses."""
        return self.entry.title

    @property
    def app_connected(self) -> bool:
        """Return True if at least one app instance is subscribed."""
        return bool(self._subscribers)

    @property
    def options(self) -> dict[str, Any]:
        """Return the entry options."""
        return dict(self.entry.options)

    @property
    def display_duration(self) -> int:
        """Return the default display duration in seconds."""
        return int(self.options.get(CONF_DISPLAY_DURATION, DEFAULT_DISPLAY_DURATION))

    @property
    def pipeline_id(self) -> str | None:
        """Return the configured Assist pipeline (None = preferred)."""
        pipeline = self.options.get(CONF_ASSIST_PIPELINE, PIPELINE_PREFERRED)
        return None if pipeline == PIPELINE_PREFERRED else pipeline

    @property
    def auto_gain(self) -> int:
        """Return the automatic gain in dBFS (0 = off)."""
        return int(self.options.get(CONF_AUTO_GAIN, DEFAULT_AUTO_GAIN))

    @property
    def noise_suppression(self) -> int:
        """Return the noise suppression level (0 = off, 4 = max)."""
        return int(self.options.get(CONF_NOISE_SUPPRESSION, DEFAULT_NOISE_SUPPRESSION))

    @property
    def dashboard_gesture(self) -> str:
        """Return the gesture that shows the dashboard."""
        return self.options.get(CONF_DASHBOARD_GESTURE, DASHBOARD_GESTURE_NONE)

    @property
    def dashboard_on_head_up(self) -> bool:
        """Return True if the app shows the dashboard when the head is raised."""
        return self.dashboard_gesture == GESTURE_HEAD_UP

    def app_config(self) -> dict[str, Any]:
        """Return the configuration the app needs."""
        return {
            "type": CMD_CONFIG,
            "name": self.name,
            "device_id": self.device_id,
            "display_duration": self.display_duration,
            "assist_pipeline": self.pipeline_id,
            "show_transcript": self.options.get(CONF_SHOW_TRANSCRIPT, True),
            "assist_pipeline_name": self.pipeline_name,
            "dashboard_on_head_up": self.dashboard_on_head_up,
        }

    @property
    def pipeline_name(self) -> str | None:
        """Return the name of the Assist pipeline the glasses talk to."""
        try:
            return assist_pipeline.async_get_pipeline(self.hass, self.pipeline_id).name
        except PipelineError:
            return None

    @callback
    def async_set_pipeline(self, pipeline_id: str | None) -> None:
        """Select the Assist pipeline (None = preferred)."""
        self.hass.config_entries.async_update_entry(
            self.entry,
            options={
                **self.entry.options,
                CONF_ASSIST_PIPELINE: pipeline_id or PIPELINE_PREFERRED,
            },
        )

    @property
    def _custom_template(self) -> str | None:
        """Return the user's dashboard template, None for the built-in layout."""
        template = self.options.get(CONF_DASHBOARD_TEMPLATE)
        if template is None or template.strip() in ("", LEGACY_DASHBOARD_TEMPLATE):
            return None
        return template

    def dashboard_template_source(self) -> str:
        """Return the Jinja source of the dashboard.

        Built-in layout: time and date, the selected entities as
        "Name: state unit" lines, then appointments and to-dos, all on one
        page. With a custom template: entity lines followed by the template,
        which can use the variables ``kopfzeile``, ``agenda`` and
        ``agenda_mehr``.
        """
        lines = [
            _ENTITY_LINE.replace("ENTITY", entity_id)
            for entity_id in self.options.get(CONF_DASHBOARD_ENTITIES, [])
        ]
        if (template := self._custom_template) is not None:
            return "\n".join([*lines, template])
        return "\n".join(["{{ kopfzeile }}", *lines, "{{ agenda }}"])

    def dashboard_variables(self, now: datetime | None = None) -> dict[str, Any]:
        """Return the variables of the dashboard template."""
        now = now or dt_util.now()
        slots = _PAGE_LINES - 1
        if self._custom_template is None:
            slots -= len(self.options.get(CONF_DASHBOARD_ENTITIES, []))
        lines, more = agenda.agenda(self._agenda_events, self._agenda_todos, now, slots)
        return {
            "kopfzeile": agenda.header(now, more),
            "agenda": "\n".join(lines),
            "agenda_mehr": more,
        }

    # ------------------------------------------------------------------
    # Listeners (entities)
    # ------------------------------------------------------------------

    @callback
    def async_add_listener(self, update_callback: CALLBACK_TYPE) -> CALLBACK_TYPE:
        """Listen for state changes."""
        self._listeners.append(update_callback)

        @callback
        def remove() -> None:
            self._listeners.remove(update_callback)

        return remove

    @callback
    def async_add_gesture_listener(
        self, gesture_callback: Callable[[str, dict[str, Any]], None]
    ) -> CALLBACK_TYPE:
        """Listen for gestures."""
        self._gesture_listeners.append(gesture_callback)

        @callback
        def remove() -> None:
            self._gesture_listeners.remove(gesture_callback)

        return remove

    @callback
    def _notify_listeners(self) -> None:
        for update_callback in list(self._listeners):
            update_callback()

    # ------------------------------------------------------------------
    # App subscriptions
    # ------------------------------------------------------------------

    @callback
    def async_add_subscriber(
        self, send: Callable[[dict[str, Any]], None]
    ) -> CALLBACK_TYPE:
        """Register an app connection that receives display commands."""
        subscriber_id = self._next_subscriber_id
        self._next_subscriber_id += 1
        self._subscribers[subscriber_id] = send
        send(self.app_config())
        if self.dashboard_on_head_up:
            send({"type": CMD_DASHBOARD, "text": self.dashboard_text})
        self._notify_listeners()

        @callback
        def remove() -> None:
            self._subscribers.pop(subscriber_id, None)
            if not self._subscribers:
                self.state.glasses_connected = False
            self._notify_listeners()

        return remove

    @callback
    def async_shutdown(self) -> None:
        """Tell connected apps to resubscribe (entry is being unloaded)."""
        self._stop_dashboard_tracking()
        self._stop_agenda()
        self._send({"type": CMD_RELOAD})
        self._subscribers.clear()

    @callback
    def async_push_config(self) -> None:
        """Send the current configuration to all connected apps."""
        self.async_start_agenda()
        self.async_update_dashboard_tracking()
        self._send(self.app_config())

    # ------------------------------------------------------------------
    # Calendars and to-do lists
    # ------------------------------------------------------------------

    @callback
    def async_start_agenda(self) -> None:
        """Read the selected calendars and to-do lists and keep them fresh."""
        self._stop_agenda()
        calendars = self.options.get(CONF_DASHBOARD_CALENDARS, [])
        todo_lists = self.options.get(CONF_DASHBOARD_TODOS, [])
        self._agenda_events, self._agenda_todos = [], []
        if not calendars and not todo_lists:
            return

        async def refresh(*_: Any) -> None:
            result = await agenda.async_fetch(
                self.hass, calendars, todo_lists, dt_util.now()
            )
            if result is None:
                return
            if result != (self._agenda_events, self._agenda_todos):
                self._agenda_events, self._agenda_todos = result
                self._async_refresh_dashboard()

        @callback
        def schedule_refresh(*_: Any) -> None:
            self.entry.async_create_background_task(
                self.hass, refresh(), f"{self.name} agenda"
            )

        self._agenda_unsubs = [
            async_track_time_interval(self.hass, schedule_refresh, _AGENDA_REFRESH),
            # Calendars switch state when an event starts or ends, to-do
            # lists when items change.
            async_track_state_change_event(
                self.hass, [*calendars, *todo_lists], schedule_refresh
            ),
        ]
        schedule_refresh()

    @callback
    def _stop_agenda(self) -> None:
        for unsub in self._agenda_unsubs:
            unsub()
        self._agenda_unsubs = []

    # ------------------------------------------------------------------
    # Dashboard on head up
    # ------------------------------------------------------------------

    @callback
    def async_update_dashboard_tracking(self) -> None:
        """Keep the rendered dashboard up to date for the head up mode.

        The app shows the dashboard locally as soon as the head is raised, so
        the text is pushed to the app whenever the template result changes
        (not on every head movement). Nothing is sent to the glasses until
        the dashboard is actually shown.
        """
        self._stop_dashboard_tracking()
        if not self.dashboard_on_head_up:
            return

        template = Template(
            self.dashboard_template_source(),
            self.hass,
        )
        self._dashboard_variables.update(self.dashboard_variables())

        @callback
        def updated(_event: Any, updates: list[TrackTemplateResult]) -> None:
            result = updates[-1].result
            if isinstance(result, TemplateError):
                text = f"Template error: {result}"
            else:
                text = str(result).strip()
            if text == self.dashboard_text:
                return
            self.dashboard_text = text
            self._send({"type": CMD_DASHBOARD, "text": text})

        self._dashboard_tracker = async_track_template_result(
            self.hass, [TrackTemplate(template, self._dashboard_variables)], updated
        )
        self._dashboard_tracker.async_refresh()
        # Clock in the header and appointments that end.
        self._minute_unsub = async_track_time_change(
            self.hass, self._async_refresh_dashboard, second=0
        )

    @callback
    def _async_refresh_dashboard(self, *_: Any) -> None:
        """Re-render the tracked dashboard with fresh variables."""
        if self._dashboard_tracker is None:
            return
        self._dashboard_variables.update(self.dashboard_variables())
        self._dashboard_tracker.async_refresh()

    @callback
    def _stop_dashboard_tracking(self) -> None:
        if self._minute_unsub is not None:
            self._minute_unsub()
            self._minute_unsub = None
        if self._dashboard_tracker is not None:
            self._dashboard_tracker.async_remove()
            self._dashboard_tracker = None

    @callback
    def _send(self, payload: dict[str, Any]) -> None:
        for send in list(self._subscribers.values()):
            send(payload)

    def _ensure_connected(self) -> None:
        if not self.app_connected:
            raise HomeAssistantError(
                f"The companion app for {self.name} is not connected to Home Assistant"
            )

    # ------------------------------------------------------------------
    # Commands to the glasses
    # ------------------------------------------------------------------

    @callback
    def async_show_text(
        self,
        message: str,
        title: str | None = None,
        duration: int | None = None,
        mode: str = MODE_SCREEN,
    ) -> None:
        """Show a text on the glasses."""
        self._ensure_connected()
        self._send(
            {
                "type": CMD_SHOW_TEXT,
                "title": title or "",
                "message": message,
                "duration": self.display_duration if duration is None else duration,
                "mode": mode,
            }
        )

    @callback
    def async_set_silent_mode(self, enabled: bool) -> None:
        """Switch the silent mode of the glasses."""
        self._ensure_connected()
        self._send({"type": CMD_SILENT_MODE, "enabled": enabled})
        # Optimistic until the app confirms with update_state.
        self.state.silent_mode = enabled
        self._notify_listeners()

    @callback
    def async_clear(self) -> None:
        """Return the glasses to their dashboard."""
        self._ensure_connected()
        self._send({"type": CMD_CLEAR})

    def render_dashboard(self) -> str:
        """Render the configured dashboard template."""
        template = Template(
            self.dashboard_template_source(),
            self.hass,
        )
        try:
            return str(
                template.async_render(self.dashboard_variables(), parse_result=False)
            ).strip()
        except TemplateError as err:
            _LOGGER.warning("Error rendering dashboard template: %s", err)
            return f"Template error: {err}"

    @callback
    def async_show_dashboard(self, duration: int | None = None) -> None:
        """Render the dashboard template and show it."""
        self.async_show_text(self.render_dashboard(), duration=duration)

    # ------------------------------------------------------------------
    # Reports from the app
    # ------------------------------------------------------------------

    @callback
    def async_update_state(self, **kwargs: Any) -> None:
        """Update state reported by the app."""
        for key, value in kwargs.items():
            if hasattr(self.state, key) and key != "extra":
                setattr(self.state, key, value)
            else:
                self.state.extra[key] = value
        self._notify_listeners()

    @callback
    def async_handle_gesture(self, gesture: str, data: dict[str, Any]) -> None:
        """Handle a gesture reported by the app."""
        event_data = {"device_id": self.device_id, "gesture": gesture, **data}
        self.hass.bus.async_fire(EVENT_GESTURE, event_data)
        for gesture_callback in list(self._gesture_listeners):
            gesture_callback(gesture, data)

        # Head up is handled by the app itself (no round trip to HA).
        if (
            self.dashboard_gesture not in (DASHBOARD_GESTURE_NONE, GESTURE_HEAD_UP)
            and gesture == self.dashboard_gesture
        ):
            self.async_show_dashboard()

    @callback
    def async_handle_assist(self, query: str, response: str) -> None:
        """Record an assist interaction that the app performed."""
        self.state.last_query = query
        self.state.last_response = response
        self.hass.bus.async_fire(
            EVENT_ASSIST,
            {"device_id": self.device_id, "query": query, "response": response},
        )
        self._notify_listeners()
