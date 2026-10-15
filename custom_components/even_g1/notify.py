"""Notify entity to show messages on the G1."""

from __future__ import annotations

from homeassistant.components.notify import NotifyEntity, NotifyEntityFeature
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback

from .device import EvenG1ConfigEntry, EvenG1Device
from .entity import EvenG1Entity


async def async_setup_entry(
    hass: HomeAssistant,
    entry: EvenG1ConfigEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    """Set up the notify entity."""
    async_add_entities([EvenG1Notify(entry.runtime_data)])


class EvenG1Notify(EvenG1Entity, NotifyEntity):
    """Show a message on the glasses display."""

    _attr_supported_features = NotifyEntityFeature.TITLE
    _attr_name = None

    def __init__(self, device: EvenG1Device) -> None:
        """Initialize."""
        super().__init__(device, "display")

    async def async_send_message(self, message: str, title: str | None = None) -> None:
        """Show the message on the glasses."""
        self.device.async_show_text(message, title=title)
