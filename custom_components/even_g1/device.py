"""Runtime state of one pair of G1 glasses (one config entry)."""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, field
import logging
from typing import Any

from homeassistant.config_entries import ConfigEntry
from homeassistant.core import CALLBACK_TYPE, HomeAssistant, callback
from homeassistant.exceptions import HomeAssistantError, TemplateError
from homeassistant.helpers import device_registry as dr
from homeassistant.helpers.template import Template

from .const import (
    CMD_CLEAR,
    CMD_CONFIG,
    CMD_RELOAD,
    CMD_SHOW_TEXT,
    CONF_ASSIST_PIPELINE,
    CONF_DASHBOARD_GESTURE,
    CONF_DASHBOARD_TEMPLATE,
    CONF_DISPLAY_DURATION,
    CONF_SHOW_TRANSCRIPT,
    DASHBOARD_GESTURE_NONE,
    DEFAULT_DASHBOARD_TEMPLATE,
    DEFAULT_DISPLAY_DURATION,
    DOMAIN,
    EVENT_ASSIST,
    EVENT_GESTURE,
    MODE_SCREEN,
    PIPELINE_PREFERRED,
)

_LOGGER = logging.getLogger(__name__)

type EvenG1ConfigEntry = ConfigEntry[EvenG1Device]


@dataclass
class EvenG1State:
    """State reported by the companion app."""

    glasses_connected: bool = False
    battery_left: int | None = None
    battery_right: int | None = None
    worn: bool | None = None
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

    def app_config(self) -> dict[str, Any]:
        """Return the configuration the app needs."""
        pipeline = self.options.get(CONF_ASSIST_PIPELINE, PIPELINE_PREFERRED)
        return {
            "type": CMD_CONFIG,
            "name": self.name,
            "device_id": self.device_id,
            "display_duration": self.display_duration,
            "assist_pipeline": None if pipeline == PIPELINE_PREFERRED else pipeline,
            "show_transcript": self.options.get(CONF_SHOW_TRANSCRIPT, True),
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
        self._send({"type": CMD_RELOAD})
        self._subscribers.clear()

    @callback
    def async_push_config(self) -> None:
        """Send the current configuration to all connected apps."""
        self._send(self.app_config())

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
    def async_clear(self) -> None:
        """Return the glasses to their dashboard."""
        self._ensure_connected()
        self._send({"type": CMD_CLEAR})

    def render_dashboard(self) -> str:
        """Render the configured dashboard template."""
        template = Template(
            self.options.get(CONF_DASHBOARD_TEMPLATE, DEFAULT_DASHBOARD_TEMPLATE),
            self.hass,
        )
        try:
            return str(template.async_render(parse_result=False)).strip()
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

        dashboard_gesture = self.options.get(
            CONF_DASHBOARD_GESTURE, DASHBOARD_GESTURE_NONE
        )
        if dashboard_gesture != DASHBOARD_GESTURE_NONE and gesture == dashboard_gesture:
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

    @property
    def device_id(self) -> str | None:
        """Return the device registry id."""
        device = dr.async_get(self.hass).async_get_device(
            identifiers={(DOMAIN, self.entry_id)}
        )
        return device.id if device else None
