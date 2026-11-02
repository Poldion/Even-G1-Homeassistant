"""Switches for silent mode, recordings and wear detection of the G1."""

from __future__ import annotations

from typing import Any

from homeassistant.components.switch import SwitchEntity
from homeassistant.const import EntityCategory
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback

from .device import EvenG1ConfigEntry, EvenG1Device
from .entity import EvenG1Entity


async def async_setup_entry(
    hass: HomeAssistant,
    entry: EvenG1ConfigEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    """Set up the switch."""
    async_add_entities(
        [
            EvenG1SilentModeSwitch(entry.runtime_data),
            EvenG1RecordingSwitch(entry.runtime_data),
            EvenG1WearDetectionSwitch(entry.runtime_data),
        ]
    )


class EvenG1SilentModeSwitch(EvenG1Entity, SwitchEntity):
    """Silent mode: the glasses show nothing on their own and the app does
    not push texts, notifications or the dashboard."""

    def __init__(self, device: EvenG1Device) -> None:
        """Initialize."""
        super().__init__(device, "silent_mode")

    @property
    def available(self) -> bool:
        """Only switchable while the app and glasses are connected."""
        return self.device.app_connected and self.device.state.glasses_connected

    @property
    def is_on(self) -> bool | None:
        """Return the silent mode state."""
        return self.device.state.silent_mode

    async def async_turn_on(self, **kwargs: Any) -> None:
        """Enable silent mode."""
        self.device.async_set_silent_mode(True)

    async def async_turn_off(self, **kwargs: Any) -> None:
        """Disable silent mode."""
        self.device.async_set_silent_mode(False)


class EvenG1RecordingSwitch(EvenG1Entity, SwitchEntity):
    """Recording with the glasses microphone; the app sends it to
    WhisperNotes when it is switched off."""

    def __init__(self, device: EvenG1Device) -> None:
        """Initialize."""
        super().__init__(device, "recording")

    @property
    def available(self) -> bool:
        """Switchable while the app is connected."""
        return self.device.app_connected

    @property
    def is_on(self) -> bool | None:
        """Return True while recording."""
        return self.device.state.recording

    async def async_turn_on(self, **kwargs: Any) -> None:
        """Start recording."""
        self.device.async_set_recording(True)

    async def async_turn_off(self, **kwargs: Any) -> None:
        """Stop recording and send it to WhisperNotes."""
        self.device.async_set_recording(False)


class EvenG1WearDetectionSwitch(EvenG1Entity, SwitchEntity):
    """Wear detection of the glasses: needed for the worn/not worn state."""

    _attr_entity_category = EntityCategory.CONFIG

    def __init__(self, device: EvenG1Device) -> None:
        """Initialize."""
        super().__init__(device, "wear_detection")

    @property
    def available(self) -> bool:
        """Only switchable while the app and glasses are connected."""
        return self.device.app_connected and self.device.state.glasses_connected

    @property
    def is_on(self) -> bool | None:
        """Return the wear detection state."""
        return self.device.state.wear_detection

    async def async_turn_on(self, **kwargs: Any) -> None:
        """Enable wear detection."""
        self.device.async_set_wear_detection(True)

    async def async_turn_off(self, **kwargs: Any) -> None:
        """Disable wear detection."""
        self.device.async_set_wear_detection(False)
