"""Sensors for Even G1."""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass
from typing import Any

from homeassistant.components.sensor import (
    SensorDeviceClass,
    SensorEntity,
    SensorEntityDescription,
    SensorStateClass,
)
from homeassistant.const import PERCENTAGE
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback

from .device import EvenG1ConfigEntry, EvenG1Device, EvenG1State
from .entity import EvenG1Entity

MAX_STATE_LENGTH = 255


@dataclass(frozen=True, kw_only=True)
class EvenG1SensorDescription(SensorEntityDescription):
    """Describes an Even G1 sensor."""

    value_fn: Callable[[EvenG1State], Any]
    attributes_fn: Callable[[EvenG1State], dict[str, Any]] | None = None


def _truncate(value: str | None) -> str | None:
    if value is None or len(value) <= MAX_STATE_LENGTH:
        return value
    return value[: MAX_STATE_LENGTH - 1] + "…"


SENSORS: tuple[EvenG1SensorDescription, ...] = (
    EvenG1SensorDescription(
        key="battery_left",
        device_class=SensorDeviceClass.BATTERY,
        native_unit_of_measurement=PERCENTAGE,
        state_class=SensorStateClass.MEASUREMENT,
        value_fn=lambda state: state.battery_left,
    ),
    EvenG1SensorDescription(
        key="battery_right",
        device_class=SensorDeviceClass.BATTERY,
        native_unit_of_measurement=PERCENTAGE,
        state_class=SensorStateClass.MEASUREMENT,
        value_fn=lambda state: state.battery_right,
    ),
    EvenG1SensorDescription(
        key="last_query",
        value_fn=lambda state: _truncate(state.last_query),
        attributes_fn=lambda state: {"full_text": state.last_query},
    ),
    EvenG1SensorDescription(
        key="last_response",
        value_fn=lambda state: _truncate(state.last_response),
        attributes_fn=lambda state: {"full_text": state.last_response},
    ),
)


async def async_setup_entry(
    hass: HomeAssistant,
    entry: EvenG1ConfigEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    """Set up the sensors."""
    async_add_entities(
        EvenG1Sensor(entry.runtime_data, description) for description in SENSORS
    )


class EvenG1Sensor(EvenG1Entity, SensorEntity):
    """Sensor for a value reported by the app."""

    entity_description: EvenG1SensorDescription

    def __init__(
        self, device: EvenG1Device, description: EvenG1SensorDescription
    ) -> None:
        """Initialize."""
        super().__init__(device, description.key)
        self.entity_description = description

    @property
    def native_value(self) -> Any:
        """Return the value."""
        return self.entity_description.value_fn(self.device.state)

    @property
    def extra_state_attributes(self) -> dict[str, Any] | None:
        """Return extra attributes."""
        if self.entity_description.attributes_fn is None:
            return None
        return self.entity_description.attributes_fn(self.device.state)
