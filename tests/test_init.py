"""Tests for the Even G1 integration."""

from datetime import timedelta

import pytest
from pytest_homeassistant_custom_component.common import MockConfigEntry

from custom_components.even_g1.const import (
    CONF_DASHBOARD_GESTURE,
    CONF_DASHBOARD_TEMPLATE,
    DOMAIN,
    EVENT_GESTURE,
)
from homeassistant import config_entries
from homeassistant.core import HomeAssistant, ServiceCall, SupportsResponse
from homeassistant.data_entry_flow import FlowResultType
from homeassistant.exceptions import HomeAssistantError
from homeassistant.util import dt as dt_util


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
    assert event["assist_pipeline_name"]


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

    device_id = entry.runtime_data.device_id
    await hass.services.async_call(
        DOMAIN,
        "show_text",
        {
            "device_id": device_id,
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
    config = (await client.receive_json())["event"]
    assert config["dashboard_gesture"] == "single_tap_right"
    # The app shows the dashboard itself on a tap, so it gets the text.
    dashboard = (await client.receive_json())["event"]
    assert dashboard == {"type": "dashboard", "text": "2 Lampen an"}

    await client.send_json_auto_id(
        {
            "type": "even_g1/update_state",
            "entry_id": entry.entry_id,
            "glasses_connected": True,
            "battery_left": 80,
            "battery_right": 75,
        }
    )
    assert (await client.receive_json())["success"]
    assert hass.states.get("sensor.even_g1_battery_left").state == "80"
    assert hass.states.get("sensor.even_g1_battery_right").state == "75"
    assert hass.states.get("binary_sensor.even_g1_glasses_connected").state == "on"

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
    assert (await client.receive_json())["success"]
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


async def test_dashboard_on_head_up(
    hass: HomeAssistant, entry: MockConfigEntry, hass_ws_client
) -> None:
    """The rendered dashboard is pushed to the app whenever it changes."""
    hass.states.async_set("sensor.temperature", "21")
    hass.config_entries.async_update_entry(
        entry,
        options={
            **entry.options,
            CONF_DASHBOARD_GESTURE: "head_up",
            CONF_DASHBOARD_TEMPLATE: "Temp {{ states('sensor.temperature') }}",
        },
    )
    await hass.async_block_till_done()

    client = await hass_ws_client(hass)
    await client.send_json_auto_id(
        {"type": "even_g1/subscribe", "entry_id": entry.entry_id}
    )
    assert (await client.receive_json())["success"]
    config = (await client.receive_json())["event"]
    assert config["dashboard_on_head_up"] is True
    assert (await client.receive_json())["event"] == {
        "type": "dashboard",
        "text": "Temp 21",
    }

    hass.states.async_set("sensor.temperature", "22")
    await hass.async_block_till_done()
    assert (await client.receive_json())["event"] == {
        "type": "dashboard",
        "text": "Temp 22",
    }

    # Head up is shown by the app itself: HA does not push a text.
    await client.send_json_auto_id(
        {
            "type": "even_g1/gesture",
            "entry_id": entry.entry_id,
            "gesture": "head_up",
            "side": "right",
        }
    )
    assert (await client.receive_json())["success"]

    # Switching the mode off stops the updates.
    hass.config_entries.async_update_entry(
        entry, options={**entry.options, CONF_DASHBOARD_GESTURE: "none"}
    )
    await hass.async_block_till_done()
    assert (await client.receive_json())["event"]["dashboard_on_head_up"] is False
    hass.states.async_set("sensor.temperature", "23")
    await hass.async_block_till_done()
    await client.send_json_auto_id({"type": "ping"})
    assert (await client.receive_json())["type"] == "pong"


async def test_silent_mode_switch(
    hass: HomeAssistant, entry: MockConfigEntry, hass_ws_client
) -> None:
    """The silent mode switch sends a command to the app and follows its state."""
    assert hass.states.get("switch.even_g1_silent_mode").state == "unavailable"

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
            "silent_mode": False,
        }
    )
    assert (await client.receive_json())["success"]
    assert hass.states.get("switch.even_g1_silent_mode").state == "off"

    await hass.services.async_call(
        "switch",
        "turn_on",
        {"entity_id": "switch.even_g1_silent_mode"},
        blocking=True,
    )
    assert (await client.receive_json())["event"] == {
        "type": "silent_mode",
        "enabled": True,
    }
    assert hass.states.get("switch.even_g1_silent_mode").state == "on"

    # Triple tap on the glasses switches it off again (reported by the app).
    await client.send_json_auto_id(
        {
            "type": "even_g1/update_state",
            "entry_id": entry.entry_id,
            "silent_mode": False,
        }
    )
    assert (await client.receive_json())["success"]
    assert hass.states.get("switch.even_g1_silent_mode").state == "off"


async def test_recording_switch(
    hass: HomeAssistant, entry: MockConfigEntry, hass_ws_client
) -> None:
    """The recording switch starts and stops a recording in the app."""
    assert hass.states.get("switch.even_g1_recording").state == "unavailable"

    client = await hass_ws_client(hass)
    await client.send_json_auto_id(
        {"type": "even_g1/subscribe", "entry_id": entry.entry_id}
    )
    await client.receive_json()
    await client.receive_json()
    await client.send_json_auto_id(
        {"type": "even_g1/update_state", "entry_id": entry.entry_id, "recording": False}
    )
    assert (await client.receive_json())["success"]
    assert hass.states.get("switch.even_g1_recording").state == "off"

    await hass.services.async_call(
        "switch", "turn_on", {"entity_id": "switch.even_g1_recording"}, blocking=True
    )
    assert (await client.receive_json())["event"] == {
        "type": "recording",
        "enabled": True,
    }
    assert hass.states.get("switch.even_g1_recording").state == "on"

    await hass.services.async_call(
        "switch", "turn_off", {"entity_id": "switch.even_g1_recording"}, blocking=True
    )
    assert (await client.receive_json())["event"] == {
        "type": "recording",
        "enabled": False,
    }
    assert hass.states.get("switch.even_g1_recording").state == "off"


async def test_wear_detection(
    hass: HomeAssistant, entry: MockConfigEntry, hass_ws_client
) -> None:
    """Worn sensor follows the wear state; the switch toggles detection."""
    client = await hass_ws_client(hass)
    await client.send_json_auto_id(
        {"type": "even_g1/subscribe", "entry_id": entry.entry_id}
    )
    await client.receive_json()
    await client.receive_json()
    assert hass.states.get("binary_sensor.even_g1_worn").state == "unknown"

    await client.send_json_auto_id(
        {
            "type": "even_g1/update_state",
            "entry_id": entry.entry_id,
            "glasses_connected": True,
            "wear_detection": True,
            "wear_state": "worn",
        }
    )
    assert (await client.receive_json())["success"]
    assert hass.states.get("binary_sensor.even_g1_worn").state == "on"
    assert hass.states.get("switch.even_g1_wear_detection").state == "on"

    await client.send_json_auto_id(
        {
            "type": "even_g1/update_state",
            "entry_id": entry.entry_id,
            "wear_state": "case_open",
        }
    )
    assert (await client.receive_json())["success"]
    assert hass.states.get("binary_sensor.even_g1_worn").state == "off"

    await hass.services.async_call(
        "switch",
        "turn_off",
        {"entity_id": "switch.even_g1_wear_detection"},
        blocking=True,
    )
    assert (await client.receive_json())["event"] == {
        "type": "wear_detection",
        "enabled": False,
    }
    # Without wear detection the state is not known.
    assert hass.states.get("binary_sensor.even_g1_worn").state == "unknown"


async def test_display_size(
    hass: HomeAssistant, entry: MockConfigEntry, hass_ws_client
) -> None:
    """The dashboard uses the lines the app reports for its display."""
    device = entry.runtime_data
    assert device.page_lines == 5
    assert device.line_width == 30

    client = await hass_ws_client(hass)
    await client.send_json_auto_id(
        {
            "type": "even_g1/update_state",
            "entry_id": entry.entry_id,
            "display_lines": 11,
            "display_columns": 42,
        }
    )
    assert (await client.receive_json())["success"]
    assert device.page_lines == 11
    assert device.line_width == 42


async def test_status_sensors(
    hass: HomeAssistant, entry: MockConfigEntry, hass_ws_client
) -> None:
    """Battery, case and wear status reported by the app."""
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
            "battery_case": 62,
            "case_charging": True,
            "wear_state": "case_open",
        }
    )
    assert (await client.receive_json())["success"]
    assert hass.states.get("sensor.even_g1_case_battery").state == "62"
    assert hass.states.get("binary_sensor.even_g1_case_charging").state == "on"
    assert hass.states.get("sensor.even_g1_state").state == "case_open"


async def test_dashboard_entities(
    hass: HomeAssistant, entry: MockConfigEntry, hass_ws_client
) -> None:
    """Selected entities become "Name: state unit" lines of the dashboard."""
    hass.states.async_set(
        "sensor.living_room",
        "21.5",
        {"friendly_name": "Wohnzimmer", "unit_of_measurement": "°C"},
    )
    hass.states.async_set("lock.front_door", "locked", {"friendly_name": "Haustür"})
    options = {
        **entry.options,
        "dashboard_entities": ["sensor.living_room", "lock.front_door"],
        CONF_DASHBOARD_GESTURE: "head_up",
    }
    options.pop(CONF_DASHBOARD_TEMPLATE, None)
    hass.config_entries.async_update_entry(entry, options=options)
    await hass.async_block_till_done()

    client = await hass_ws_client(hass)
    await client.send_json_auto_id(
        {"type": "even_g1/subscribe", "entry_id": entry.entry_id}
    )
    await client.receive_json()
    await client.receive_json()
    dashboard = (await client.receive_json())["event"]
    assert dashboard["type"] == "dashboard"
    lines = dashboard["text"].splitlines()
    assert " · " in lines[0]  # time and date
    assert lines[1] == "Wohnzimmer: 21.5 °C"
    assert lines[2].startswith("Haustür: ")
    assert len(lines) == 3


async def test_dashboard_agenda(
    hass: HomeAssistant, entry: MockConfigEntry, hass_ws_client
) -> None:
    """Appointments and to-dos of the selected lists appear on the dashboard."""
    now = dt_util.now()
    later = now + timedelta(hours=1)
    if later.date() != now.date():
        later = now + timedelta(minutes=1)
    calls: list[dict] = []

    async def get_events(call: ServiceCall) -> dict:
        calls.append(dict(call.data))
        return {
            "calendar.familie": {
                "events": [
                    {
                        "start": later.isoformat(),
                        "end": (later + timedelta(minutes=1)).isoformat(),
                        "summary": "Zahnarzt",
                    },
                    {
                        "start": (now - timedelta(days=3)).isoformat(),
                        "end": (now - timedelta(days=2)).isoformat(),
                        "summary": "Vorbei",
                    },
                ]
            }
        }

    async def get_items(call: ServiceCall) -> dict:
        return {
            "todo.haushalt": {
                "items": [
                    {"summary": "Ohne Datum", "status": "needs_action"},
                    {
                        "summary": "Müll raus",
                        "status": "needs_action",
                        "due": (now.date() + timedelta(days=1)).isoformat(),
                    },
                ]
            }
        }

    hass.services.async_register(
        "calendar", "get_events", get_events, supports_response=SupportsResponse.ONLY
    )
    hass.services.async_register(
        "todo", "get_items", get_items, supports_response=SupportsResponse.ONLY
    )
    hass.config.language = "de"
    hass.states.async_set("calendar.familie", "off")
    hass.states.async_set("todo.haushalt", "2")
    hass.config_entries.async_update_entry(
        entry,
        options={
            **entry.options,
            CONF_DASHBOARD_GESTURE: "head_up",
            "dashboard_calendars": ["calendar.familie"],
            "dashboard_todos": ["todo.haushalt"],
        },
    )
    await hass.async_block_till_done()
    assert calls and calls[0]["entity_id"] == ["calendar.familie"]

    client = await hass_ws_client(hass)
    await client.send_json_auto_id(
        {"type": "even_g1/subscribe", "entry_id": entry.entry_id}
    )
    await client.receive_json()
    await client.receive_json()
    lines = (await client.receive_json())["event"]["text"].splitlines()
    assert lines == [
        lines[0],
        f"» {later:%H:%M}  Zahnarzt",
        "[ ] Müll raus · morgen",
    ]
    assert "+" not in lines[0]


async def test_assistant_select(
    hass: HomeAssistant, entry: MockConfigEntry, hass_ws_client
) -> None:
    """The assistant can be switched with the select entity."""
    client = await hass_ws_client(hass)
    await client.send_json_auto_id(
        {
            "type": "assist_pipeline/pipeline/create",
            "conversation_engine": "conversation.home_assistant",
            "conversation_language": "de",
            "language": "de",
            "name": "Jarvis",
            "stt_engine": None,
            "stt_language": None,
            "tts_engine": None,
            "tts_language": None,
            "tts_voice": None,
            "wake_word_entity": None,
            "wake_word_id": None,
        }
    )
    pipeline_id = (await client.receive_json())["result"]["id"]
    await hass.services.async_call(
        "homeassistant",
        "update_entity",
        {"entity_id": "select.even_g1_assistant"},
        blocking=True,
    )

    state = hass.states.get("select.even_g1_assistant")
    assert state.state == "preferred"
    assert "Jarvis" in state.attributes["options"]

    await client.send_json_auto_id(
        {"type": "even_g1/subscribe", "entry_id": entry.entry_id}
    )
    await client.receive_json()
    await client.receive_json()

    await hass.services.async_call(
        "select",
        "select_option",
        {"entity_id": "select.even_g1_assistant", "option": "Jarvis"},
        blocking=True,
    )
    await hass.async_block_till_done()
    assert entry.options["assist_pipeline"] == pipeline_id
    assert hass.states.get("select.even_g1_assistant").state == "Jarvis"
    config = (await client.receive_json())["event"]
    assert config["assist_pipeline"] == pipeline_id
    assert config["assist_pipeline_name"] == "Jarvis"


async def test_listening_text_and_style(
    hass: HomeAssistant, entry: MockConfigEntry, hass_ws_client
) -> None:
    """The app gets the listening text and the dashboard design."""
    client = await hass_ws_client(hass)
    await client.send_json_auto_id(
        {"type": "even_g1/subscribe", "entry_id": entry.entry_id}
    )
    await client.receive_json()
    config = (await client.receive_json())["event"]
    assert config["listening_text"] == "Home Assistant\nis listening …"
    assert config["dashboard_style"] == "plain"

    hass.config_entries.async_update_entry(
        entry,
        options={
            **entry.options,
            "listening_template": "{{ 'Ich höre' }}",
            "dashboard_style": "card",
        },
    )
    await hass.async_block_till_done()
    config = (await client.receive_json())["event"]
    assert config["dashboard_style"] == "card"
    listening = (await client.receive_json())["event"]
    assert listening == {"type": "listening", "text": "Ich höre"}
