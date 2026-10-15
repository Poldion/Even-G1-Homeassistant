"""The Even Realities G1 integration.

Home Assistant cannot talk to the G1 glasses directly: they are BLE devices
paired with a phone. The companion app (see ``app/`` in the repository) keeps
the BLE connection and connects to Home Assistant through the websocket API.
This integration provides the server side of that bridge: services and a
notify entity to show text on the glasses, entities for the glasses state and
an event entity for touch bar gestures.
"""

from __future__ import annotations

import voluptuous as vol

from homeassistant.const import Platform
from homeassistant.core import HomeAssistant, ServiceCall, callback
from homeassistant.exceptions import ServiceValidationError
from homeassistant.helpers import config_validation as cv, device_registry as dr
from homeassistant.helpers.typing import ConfigType

from . import websocket_api
from .const import (
    ATTR_DEVICE_ID,
    ATTR_DURATION,
    ATTR_MESSAGE,
    ATTR_MODE,
    ATTR_TITLE,
    DOMAIN,
    MODE_NOTIFICATION,
    MODE_SCREEN,
    SERVICE_CLEAR,
    SERVICE_SHOW_DASHBOARD,
    SERVICE_SHOW_TEXT,
)
from .device import EvenG1ConfigEntry, EvenG1Device

PLATFORMS: list[Platform] = [
    Platform.BINARY_SENSOR,
    Platform.EVENT,
    Platform.NOTIFY,
    Platform.SENSOR,
]

CONFIG_SCHEMA = cv.config_entry_only_config_schema(DOMAIN)

_DEVICE_SCHEMA = {vol.Optional(ATTR_DEVICE_ID): vol.All(cv.ensure_list, [cv.string])}

SHOW_TEXT_SCHEMA = vol.Schema(
    {
        **_DEVICE_SCHEMA,
        vol.Required(ATTR_MESSAGE): cv.string,
        vol.Optional(ATTR_TITLE): cv.string,
        vol.Optional(ATTR_DURATION): vol.All(
            vol.Coerce(int), vol.Range(min=0, max=3600)
        ),
        vol.Optional(ATTR_MODE, default=MODE_SCREEN): vol.In(
            [MODE_SCREEN, MODE_NOTIFICATION]
        ),
    }
)
CLEAR_SCHEMA = vol.Schema(_DEVICE_SCHEMA)
SHOW_DASHBOARD_SCHEMA = vol.Schema(
    {
        **_DEVICE_SCHEMA,
        vol.Optional(ATTR_DURATION): vol.All(
            vol.Coerce(int), vol.Range(min=0, max=3600)
        ),
    }
)


async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    """Set up the integration (websocket API and services)."""
    websocket_api.async_register(hass)

    @callback
    def targets(call: ServiceCall) -> list[EvenG1Device]:
        entries: list[EvenG1ConfigEntry] = hass.config_entries.async_loaded_entries(
            DOMAIN
        )
        if not (device_ids := call.data.get(ATTR_DEVICE_ID)):
            devices = [entry.runtime_data for entry in entries]
        else:
            registry = dr.async_get(hass)
            devices = []
            for device_id in device_ids:
                device = registry.async_get(device_id)
                match = next(
                    (
                        entry.runtime_data
                        for entry in entries
                        if device and entry.entry_id in device.config_entries
                    ),
                    None,
                )
                if match is None:
                    raise ServiceValidationError(
                        f"Device {device_id} is not a configured Even G1"
                    )
                devices.append(match)
        if not devices:
            raise ServiceValidationError("No Even G1 glasses configured")
        return devices

    async def show_text(call: ServiceCall) -> None:
        for device in targets(call):
            device.async_show_text(
                call.data[ATTR_MESSAGE],
                title=call.data.get(ATTR_TITLE),
                duration=call.data.get(ATTR_DURATION),
                mode=call.data[ATTR_MODE],
            )

    async def clear(call: ServiceCall) -> None:
        for device in targets(call):
            device.async_clear()

    async def show_dashboard(call: ServiceCall) -> None:
        for device in targets(call):
            device.async_show_dashboard(duration=call.data.get(ATTR_DURATION))

    hass.services.async_register(DOMAIN, SERVICE_SHOW_TEXT, show_text, SHOW_TEXT_SCHEMA)
    hass.services.async_register(DOMAIN, SERVICE_CLEAR, clear, CLEAR_SCHEMA)
    hass.services.async_register(
        DOMAIN, SERVICE_SHOW_DASHBOARD, show_dashboard, SHOW_DASHBOARD_SCHEMA
    )
    return True


async def async_setup_entry(hass: HomeAssistant, entry: EvenG1ConfigEntry) -> bool:
    """Set up Even G1 from a config entry."""
    entry.runtime_data = EvenG1Device(hass, entry)

    dr.async_get(hass).async_get_or_create(
        config_entry_id=entry.entry_id,
        identifiers={(DOMAIN, entry.entry_id)},
        manufacturer="Even Realities",
        model="G1",
        name=entry.title,
    )

    await hass.config_entries.async_forward_entry_setups(entry, PLATFORMS)
    entry.async_on_unload(entry.add_update_listener(_async_options_updated))
    return True


async def _async_options_updated(hass: HomeAssistant, entry: EvenG1ConfigEntry) -> None:
    """Push changed options to the app."""
    entry.runtime_data.async_push_config()


async def async_unload_entry(hass: HomeAssistant, entry: EvenG1ConfigEntry) -> bool:
    """Unload a config entry."""
    entry.runtime_data.async_shutdown()
    return await hass.config_entries.async_unload_platforms(entry, PLATFORMS)
