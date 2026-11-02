"""Select entity for the Assist pipeline used by the glasses."""

from __future__ import annotations

from datetime import timedelta

from homeassistant.components import assist_pipeline
from homeassistant.components.select import SelectEntity
from homeassistant.const import EntityCategory
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback

from .device import EvenG1ConfigEntry, EvenG1Device
from .entity import EvenG1Entity

PREFERRED_LABEL = "preferred"
SCAN_INTERVAL = timedelta(minutes=1)


async def async_setup_entry(
    hass: HomeAssistant,
    entry: EvenG1ConfigEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    """Set up the select entity."""
    async_add_entities([EvenG1AssistantSelect(entry.runtime_data)])


class EvenG1AssistantSelect(EvenG1Entity, SelectEntity):
    """Which Assist pipeline (assistant) answers when the touch bar is held."""

    _attr_entity_category = EntityCategory.CONFIG
    # Refresh the list of assistants now and then (new pipelines).
    _attr_should_poll = True

    def __init__(self, device: EvenG1Device) -> None:
        """Initialize."""
        super().__init__(device, "assistant")

    def _pipelines(self) -> dict[str, str]:
        """Return pipeline name -> id (names are what the user sees)."""
        return {
            pipeline.name: pipeline.id
            for pipeline in assist_pipeline.async_get_pipelines(self.hass)
        }

    @property
    def options(self) -> list[str]:
        """Return the selectable assistants."""
        return [PREFERRED_LABEL, *self._pipelines()]

    @property
    def current_option(self) -> str | None:
        """Return the selected assistant."""
        pipeline_id = self.device.pipeline_id
        if pipeline_id is None:
            return PREFERRED_LABEL
        for name, candidate in self._pipelines().items():
            if candidate == pipeline_id:
                return name
        return None

    async def async_select_option(self, option: str) -> None:
        """Select an assistant."""
        self.device.async_set_pipeline(
            None if option == PREFERRED_LABEL else self._pipelines()[option]
        )
