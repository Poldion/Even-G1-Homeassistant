"""Tests for the Even G1 integration."""

import pytest
from pytest_homeassistant_custom_component.common import MockConfigEntry

from custom_components.even_g1.const import (
    CONF_DASHBOARD_GESTURE,
    CONF_DASHBOARD_TEMPLATE,
    DOMAIN,
    EVENT_GESTURE,
)
from homeassistant import config_entries
from homeassistant.core import HomeAssistant
from homeassistant.data_entry_flow import FlowResultType
from homeassistant.exceptions import HomeAssistantError
from homeassistant.helpers import device_registry as dr


async def test_config_flow(hass: HomeAssistant) -> None:
    """Test creating an entry."""
    result = await hass.config_entries.flow.async_init(
        DOMAIN, context={"source": config_entries.SOURCE_USER}
    )
    assert result["type"] is FlowResultType.FORM
    result = await hass.config_entries.flow.async_configure(
        result["flow_id"], {"name": "Meine G1"}
    )
    assert result["type"] is FlowResultType.CREATE_ENTRY
    assert result["title"] == "Meine G1"
    await hass.async_block_till_done()

    result = await hass.config_entries.flow.async_init(
        DOMAIN, context={"source": config_entries.SOURCE_USER}
    )
    result = await hass.config_entries.flow.async_configure(
        result["flow_id"], {"name": "Meine G1"}
    )
    assert result["type"] is FlowResultType.ABORT


async def test_options_flow(
    hass: HomeAssistant, entry: MockConfigEntry, hass_ws_client
) -> None:
    """Test the options flow pushes new config to the app."""
    client = await hass_ws_client(hass)
    await client.send_json_auto_id(
        {"type": "even_g1/subscribe", "entry_id": entry.entry_id}
    )
    assert (await client.receive_json())["success"]
    assert (await client.receive_json())["event"]["display_duration"] == 10

    result = await hass.config_entries.options.async_init(entry.entry_id)
    assert result["type"] is FlowResultType.FORM
    result = await hass.config_entries.options.async_configure(
        result["flow_id"],
        {
            "assist_pipeline": "preferred",
            "show_transcript": False,
            "display_duration": 25,
            "dashboard_gesture": "none",
            "dashboard_template": "Hallo",
        },
    )
    assert result["type"] is FlowResultType.CREATE_ENTRY
    await hass.async_block_till_done()
    event = (await client.receive_json())["event"]
    assert event["type"] == "config"
    assert event["display_duration"] == 25
    assert event["show_transcript"] is False


async def test_show_text_requires_app(
    hass: HomeAssistant, entry: MockConfigEntry
) -> None:
    """Showing text without a connected app raises."""
    with pytest.raises(HomeAssistantError):
        await hass.services.async_call(
            DOMAIN, "show_text", {"message": "Hallo"}, blocking=True
        )


async def test_subscribe_and_show_text(
    hass: HomeAssistant, entry: MockConfigEntry, hass_ws_client
) -> None:
    """Test the app receives display commands."""
    client = await hass_ws_client(hass)

    await client.send_json_auto_id({"type": "even_g1/devices"})
    msg = await client.receive_json()
    assert msg["result"] == [{"entry_id": entry.entry_id, "name": "Even G1"}]

    await client.send_json_auto_id(
        {"type": "even_g1/subscribe", "entry_id": entry.entry_id}
    )
    assert (await client.receive_json())["success"]
    config = (await client.receive_json())["event"]
    assert config["type"] == "config"
    assert config["assist_pipeline"] is None

    assert hass.states.get("binary_sensor.even_g1_app_connected").state == "on"

    device = dr.async_get(hass).async_get_device(identifiers={(DOMAIN, entry.entry_id)})
    await hass.services.async_call(
        DOMAIN,
        "show_text",
        {
            "device_id": device.id,
            "title": "Tür",
            "message": "Haustür offen",
            "duration": 5,
        },
        blocking=True,
    )
    event = (await client.receive_json())["event"]
    assert event == {
        "type": "show_text",
        "title": "Tür",
        "message": "Haustür offen",
        "duration": 5,
        "mode": "screen",
    }

    await hass.services.async_call(
        "notify",
        "send_message",
        {"entity_id": "notify.even_g1", "title": "T", "message": "M"},
        blocking=True,
    )
    event = (await client.receive_json())["event"]
    assert event["title"] == "T"
    assert event["message"] == "M"
    assert event["duration"] == 10

    await hass.services.async_call(DOMAIN, "clear", {}, blocking=True)
    assert (await client.receive_json())["event"] == {"type": "clear"}


async def test_state_and_gestures(
    hass: HomeAssistant, entry: MockConfigEntry, hass_ws_client
) -> None:
    """Test state updates, gestures and assist reports."""
    hass.config_entries.async_update_entry(
        entry,
        options={
            **entry.options,
            CONF_DASHBOARD_GESTURE: "single_tap_right",
            CONF_DASHBOARD_TEMPLATE: "{{ 1 + 1 }} Lampen an",
        },
    )
    await hass.async_block_till_done()

    client = await hass_ws_client(hass)
    await client.send_json_auto_id(
        {"type": "even_g1/subscribe", "entry_id": entry.entry_id}
    )
    await client.receive_json()
    await client.receive_json()

    await client.send_json_auto_id(
        {
            "type": "even_g1/update_state",
            "entry_id": entry.entry_id,
            "glasses_connected": True,
            "battery_left": 80,
            "battery_right": 75,
            "worn": True,
        }
    )
    assert (await client.receive_json())["success"]
    assert hass.states.get("sensor.even_g1_battery_left").state == "80"
    assert hass.states.get("sensor.even_g1_battery_right").state == "75"
    assert hass.states.get("binary_sensor.even_g1_glasses_connected").state == "on"
    assert hass.states.get("binary_sensor.even_g1_worn").state == "on"

    events = []
    hass.bus.async_listen(EVENT_GESTURE, events.append)
    await client.send_json_auto_id(
        {
            "type": "even_g1/gesture",
            "entry_id": entry.entry_id,
            "gesture": "single_tap_right",
            "side": "right",
            "code": 1,
        }
    )
    # Dashboard is pushed because of the configured gesture
    msg = await client.receive_json()
    if "event" in msg:
        dashboard, result = msg, await client.receive_json()
    else:
        result, dashboard = msg, await client.receive_json()
    assert result["success"]
    assert dashboard["event"]["message"] == "2 Lampen an"
    await hass.async_block_till_done()
    assert events[0].data["gesture"] == "single_tap_right"
    assert events[0].data["side"] == "right"
    state = hass.states.get("event.even_g1_gesture")
    assert state.attributes["event_type"] == "single_tap_right"

    await client.send_json_auto_id(
        {
            "type": "even_g1/assist",
            "entry_id": entry.entry_id,
            "query": "Mach das Licht an",
            "response": "Licht eingeschaltet",
        }
    )
    assert (await client.receive_json())["success"]
    assert hass.states.get("sensor.even_g1_last_question").state == "Mach das Licht an"
    assert hass.states.get("sensor.even_g1_last_answer").state == "Licht eingeschaltet"

    await client.send_json_auto_id(
        {"type": "even_g1/dashboard", "entry_id": entry.entry_id}
    )
    assert (await client.receive_json())["result"] == {"text": "2 Lampen an"}

    # Unsubscribing marks the app as disconnected
    await hass.config_entries.async_unload(entry.entry_id)
    await hass.async_block_till_done()
    assert (await client.receive_json())["event"] == {"type": "reload"}


async def test_unknown_entry(
    hass: HomeAssistant, entry: MockConfigEntry, hass_ws_client
) -> None:
    """Test addressing an unknown entry."""
    client = await hass_ws_client(hass)
    await client.send_json_auto_id({"type": "even_g1/subscribe", "entry_id": "nope"})
    msg = await client.receive_json()
    assert not msg["success"]
    assert msg["error"]["code"] == "not_found"
