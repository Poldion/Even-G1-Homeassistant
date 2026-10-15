"""Fixtures for Even G1 tests."""

import pytest
from pytest_homeassistant_custom_component.common import MockConfigEntry

from custom_components.even_g1.config_flow import DEFAULT_OPTIONS
from custom_components.even_g1.const import DOMAIN
from homeassistant.core import HomeAssistant
from homeassistant.setup import async_setup_component


@pytest.fixture(autouse=True)
async def setup_core(hass: HomeAssistant, enable_custom_integrations) -> None:
    """Enable custom integrations and set up the core integration."""
    assert await async_setup_component(hass, "homeassistant", {})


@pytest.fixture
async def entry(hass: HomeAssistant) -> MockConfigEntry:
    """Set up a config entry."""
    entry = MockConfigEntry(
        domain=DOMAIN,
        title="Even G1",
        unique_id="even_g1",
        options=dict(DEFAULT_OPTIONS),
    )
    entry.add_to_hass(hass)
    assert await hass.config_entries.async_setup(entry.entry_id)
    await hass.async_block_till_done()
    return entry
