"""Event entity for G1 touch bar gestures."""

from __future__ import annotations

from typing import Any

from homeassistant.components.event import EventEntity
from homeassistant.core import HomeAssistant, callback
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback

from .const import GESTURES
from .device import EvenG1ConfigEntry, EvenG1Device
from .entity import EvenG1Entity


async def async_setup_entry(
    hass: HomeAssistant,
    entry: EvenG1ConfigEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    """Set up the gesture event entity."""
    async_add_entities([EvenG1GestureEvent(entry.runtime_data)])


class EvenG1GestureEvent(EvenG1Entity, EventEntity):
    """Fires when a gesture is detected on the glasses."""

    _attr_event_types = GESTURES

    def __init__(self, device: EvenG1Device) -> None:
        """Initialize."""
        super().__init__(device, "gesture")

    async def async_added_to_hass(self) -> None:
        """Subscribe to gestures."""
        self.async_on_remove(self.device.async_add_gesture_listener(self._on_gesture))

    @callback
    def _on_gesture(self, gesture: str, data: dict[str, Any]) -> None:
        self._trigger_event(gesture, data)
        self.async_write_ha_state()
