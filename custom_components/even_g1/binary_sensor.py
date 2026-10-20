"""Binary sensors for Even G1."""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass

from homeassistant.components.binary_sensor import (
    BinarySensorDeviceClass,
    BinarySensorEntity,
    BinarySensorEntityDescription,
)
from homeassistant.const import EntityCategory
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback

from .device import EvenG1ConfigEntry, EvenG1Device
from .entity import EvenG1Entity


@dataclass(frozen=True, kw_only=True)
class EvenG1BinarySensorDescription(BinarySensorEntityDescription):
    """Describes an Even G1 binary sensor."""

    value_fn: Callable[[EvenG1Device], bool | None]


BINARY_SENSORS: tuple[EvenG1BinarySensorDescription, ...] = (
    EvenG1BinarySensorDescription(
        key="app_connected",
        device_class=BinarySensorDeviceClass.CONNECTIVITY,
        entity_category=EntityCategory.DIAGNOSTIC,
        value_fn=lambda device: device.app_connected,
    ),
    EvenG1BinarySensorDescription(
        key="glasses_connected",
        device_class=BinarySensorDeviceClass.CONNECTIVITY,
        value_fn=lambda device: device.app_connected and device.state.glasses_connected,
    ),
)


async def async_setup_entry(
    hass: HomeAssistant,
    entry: EvenG1ConfigEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    """Set up the binary sensors."""
    async_add_entities(
        EvenG1BinarySensor(entry.runtime_data, description)
        for description in BINARY_SENSORS
    )


class EvenG1BinarySensor(EvenG1Entity, BinarySensorEntity):
    """Binary sensor for a value reported by the app."""

    entity_description: EvenG1BinarySensorDescription

    def __init__(
        self, device: EvenG1Device, description: EvenG1BinarySensorDescription
    ) -> None:
        """Initialize."""
        super().__init__(device, description.key)
        self.entity_description = description

    @property
    def is_on(self) -> bool | None:
        """Return the state."""
        return self.entity_description.value_fn(self.device)
