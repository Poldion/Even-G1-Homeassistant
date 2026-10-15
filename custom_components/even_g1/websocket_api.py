"""Websocket API used by the Even G1 companion app."""

from __future__ import annotations

from typing import Any

import voluptuous as vol

from homeassistant.components import websocket_api
from homeassistant.core import HomeAssistant, callback

from .const import DOMAIN, GESTURES
from .device import EvenG1ConfigEntry, EvenG1Device


@callback
def async_register(hass: HomeAssistant) -> None:
    """Register the websocket commands."""
    websocket_api.async_register_command(hass, ws_devices)
    websocket_api.async_register_command(hass, ws_subscribe)
    websocket_api.async_register_command(hass, ws_update_state)
    websocket_api.async_register_command(hass, ws_gesture)
    websocket_api.async_register_command(hass, ws_assist)
    websocket_api.async_register_command(hass, ws_dashboard)


def _get_device(
    hass: HomeAssistant,
    connection: websocket_api.ActiveConnection,
    msg: dict[str, Any],
) -> EvenG1Device | None:
    entry: EvenG1ConfigEntry | None = hass.config_entries.async_get_entry(
        msg["entry_id"]
    )
    if entry is None or entry.domain != DOMAIN or not hasattr(entry, "runtime_data"):
        connection.send_error(
            msg["id"], websocket_api.ERR_NOT_FOUND, "Even G1 entry not found"
        )
        return None
    return entry.runtime_data


@websocket_api.websocket_command({vol.Required("type"): f"{DOMAIN}/devices"})
@callback
def ws_devices(
    hass: HomeAssistant, connection: websocket_api.ActiveConnection, msg: dict[str, Any]
) -> None:
    """List the configured glasses so the app can pick one."""
    entries: list[EvenG1ConfigEntry] = hass.config_entries.async_loaded_entries(DOMAIN)
    connection.send_result(
        msg["id"],
        [{"entry_id": entry.entry_id, "name": entry.title} for entry in entries],
    )


@websocket_api.websocket_command(
    {vol.Required("type"): f"{DOMAIN}/subscribe", vol.Required("entry_id"): str}
)
@callback
def ws_subscribe(
    hass: HomeAssistant, connection: websocket_api.ActiveConnection, msg: dict[str, Any]
) -> None:
    """Subscribe to display commands for one pair of glasses."""
    if (device := _get_device(hass, connection, msg)) is None:
        return

    msg_id = msg["id"]

    @callback
    def forward(payload: dict[str, Any]) -> None:
        connection.send_message(websocket_api.event_message(msg_id, payload))

    connection.send_result(msg_id)
    connection.subscriptions[msg_id] = device.async_add_subscriber(forward)


@websocket_api.websocket_command(
    {
        vol.Required("type"): f"{DOMAIN}/update_state",
        vol.Required("entry_id"): str,
        vol.Optional("glasses_connected"): bool,
        vol.Optional("battery_left"): vol.Any(None, vol.All(int, vol.Range(0, 100))),
        vol.Optional("battery_right"): vol.Any(None, vol.All(int, vol.Range(0, 100))),
        vol.Optional("worn"): vol.Any(None, bool),
    }
)
@callback
def ws_update_state(
    hass: HomeAssistant, connection: websocket_api.ActiveConnection, msg: dict[str, Any]
) -> None:
    """Receive state updates from the app."""
    if (device := _get_device(hass, connection, msg)) is None:
        return
    device.async_update_state(
        **{k: v for k, v in msg.items() if k not in ("id", "type", "entry_id")}
    )
    connection.send_result(msg["id"])


@websocket_api.websocket_command(
    {
        vol.Required("type"): f"{DOMAIN}/gesture",
        vol.Required("entry_id"): str,
        vol.Required("gesture"): vol.In(GESTURES),
        vol.Optional("side"): vol.In(["left", "right"]),
        vol.Optional("code"): int,
    }
)
@callback
def ws_gesture(
    hass: HomeAssistant, connection: websocket_api.ActiveConnection, msg: dict[str, Any]
) -> None:
    """Receive a touch bar / head gesture from the app."""
    if (device := _get_device(hass, connection, msg)) is None:
        return
    data = {k: msg[k] for k in ("side", "code") if k in msg}
    device.async_handle_gesture(msg["gesture"], data)
    connection.send_result(msg["id"])


@websocket_api.websocket_command(
    {
        vol.Required("type"): f"{DOMAIN}/assist",
        vol.Required("entry_id"): str,
        vol.Required("query"): str,
        vol.Required("response"): str,
    }
)
@callback
def ws_assist(
    hass: HomeAssistant, connection: websocket_api.ActiveConnection, msg: dict[str, Any]
) -> None:
    """Record an assist interaction done from the glasses."""
    if (device := _get_device(hass, connection, msg)) is None:
        return
    device.async_handle_assist(msg["query"], msg["response"])
    connection.send_result(msg["id"])


@websocket_api.websocket_command(
    {vol.Required("type"): f"{DOMAIN}/dashboard", vol.Required("entry_id"): str}
)
@callback
def ws_dashboard(
    hass: HomeAssistant, connection: websocket_api.ActiveConnection, msg: dict[str, Any]
) -> None:
    """Render the dashboard template (used by the app's preview)."""
    if (device := _get_device(hass, connection, msg)) is None:
        return
    connection.send_result(msg["id"], {"text": device.render_dashboard()})
