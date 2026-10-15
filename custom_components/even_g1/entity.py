"""Base entity for Even G1."""

from __future__ import annotations

from homeassistant.helpers.device_registry import DeviceInfo
from homeassistant.helpers.entity import Entity

from .const import DOMAIN
from .device import EvenG1Device


class EvenG1Entity(Entity):
    """Base entity bound to one pair of glasses."""

    _attr_has_entity_name = True
    _attr_should_poll = False

    def __init__(self, device: EvenG1Device, key: str) -> None:
        """Initialize."""
        self.device = device
        self._attr_unique_id = f"{device.entry_id}_{key}"
        self._attr_translation_key = key
        self._attr_device_info = DeviceInfo(identifiers={(DOMAIN, device.entry_id)})

    async def async_added_to_hass(self) -> None:
        """Subscribe to state updates."""
        self.async_on_remove(self.device.async_add_listener(self.async_write_ha_state))
