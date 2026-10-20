"""Tests for running Assist with audio from the glasses."""

import asyncio
from collections.abc import AsyncIterable

import pytest
from pytest_homeassistant_custom_component.common import (
    MockConfigEntry,
    MockModule,
    MockPlatform,
    mock_config_flow,
    mock_integration,
    mock_platform,
)

from custom_components.even_g1.const import CONF_ASSIST_PIPELINE
from homeassistant.components import stt
from homeassistant.config_entries import ConfigEntry, ConfigFlow
from homeassistant.const import Platform
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback

TEST_DOMAIN = "test_stt"
SECOND = 16000 * 2  # bytes of 16 kHz 16 bit mono PCM


class FakeSTT(stt.SpeechToTextEntity):
    """Counts the audio it receives and returns a fixed text."""

    _attr_name = "Fake"
    _attr_unique_id = "fake_stt"

    def __init__(self) -> None:
        """Initialize."""
        self.received = 0

    supported_languages = ["en"]
    supported_formats = [stt.AudioFormats.WAV]
    supported_codecs = [stt.AudioCodecs.PCM]
    supported_bit_rates = [stt.AudioBitRates.BITRATE_16]
    supported_sample_rates = [stt.AudioSampleRates.SAMPLERATE_16000]
    supported_channels = [stt.AudioChannels.CHANNEL_MONO]

    async def async_process_audio_stream(
        self, metadata: stt.SpeechMetadata, stream: AsyncIterable[bytes]
    ) -> stt.SpeechResult:
        """Consume the whole stream."""
        async for chunk in stream:
            self.received += len(chunk)
        return stt.SpeechResult("what time is it", stt.SpeechResultState.SUCCESS)


class FakeFlow(ConfigFlow):
    """Config flow of the fake STT integration."""


@pytest.fixture
async def fake_stt(hass: HomeAssistant) -> FakeSTT:
    """Set up a fake STT entity."""
    entity = FakeSTT()

    async def setup_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
        await hass.config_entries.async_forward_entry_setups(entry, [Platform.STT])
        return True

    async def setup_stt(
        hass: HomeAssistant,
        entry: ConfigEntry,
        async_add_entities: AddConfigEntryEntitiesCallback,
    ) -> None:
        async_add_entities([entity])

    mock_integration(hass, MockModule(TEST_DOMAIN, async_setup_entry=setup_entry))
    mock_platform(hass, f"{TEST_DOMAIN}.stt", MockPlatform(async_setup_entry=setup_stt))
    mock_platform(hass, f"{TEST_DOMAIN}.config_flow")
    with mock_config_flow(TEST_DOMAIN, FakeFlow):
        stt_entry = MockConfigEntry(domain=TEST_DOMAIN)
        stt_entry.add_to_hass(hass)
        assert await hass.config_entries.async_setup(stt_entry.entry_id)
        await hass.async_block_till_done()
    return entity


async def test_assist_run(
    hass: HomeAssistant, entry: MockConfigEntry, fake_stt: FakeSTT, hass_ws_client
) -> None:
    """Audio is streamed to STT without VAD and the answer is recorded."""
    client = await hass_ws_client(hass)
    await client.send_json_auto_id(
        {
            "type": "assist_pipeline/pipeline/create",
            "conversation_engine": "conversation.home_assistant",
            "conversation_language": "en",
            "language": "en",
            "name": "Test",
            "stt_engine": "stt.fake",
            "stt_language": "en",
            "tts_engine": None,
            "tts_language": None,
            "tts_voice": None,
            "wake_word_entity": None,
            "wake_word_id": None,
        }
    )
    pipeline_id = (await client.receive_json())["result"]["id"]
    hass.config_entries.async_update_entry(
        entry, options={**entry.options, CONF_ASSIST_PIPELINE: pipeline_id}
    )
    await hass.async_block_till_done()

    await client.send_json_auto_id(
        {"type": "even_g1/assist_run", "entry_id": entry.entry_id}
    )
    assert (await client.receive_json())["success"]
    ready = (await client.receive_json())["event"]
    assert ready["type"] == "audio-ready"
    prefix = bytes([ready["data"]["handler_id"]])

    # Speech, a two second pause, more speech: the pause must not end the
    # recording (which HA's voice activity detection would do).
    audio = (
        b"\x10\x20" * (SECOND // 2) + bytes(2 * SECOND) + b"\x10\x20" * (SECOND // 2)
    )
    for i in range(0, len(audio), 3200):
        await client.send_bytes(prefix + audio[i : i + 3200])
    await client.send_bytes(prefix)

    events = []
    while True:
        event = (await client.receive_json())["event"]
        events.append(event)
        if event["type"] in ("intent-end", "error"):
            break
    types = [e["type"] for e in events]
    assert "error" not in types, events
    assert types[0] == "run-start"
    assert "stt-end" in types

    assert fake_stt.received == len(audio)
    speech = events[-1]["data"]["intent_output"]["response"]["speech"]["plain"][
        "speech"
    ]
    assert speech
    await hass.async_block_till_done()
    assert hass.states.get("sensor.even_g1_last_question").state == "what time is it"
    assert hass.states.get("sensor.even_g1_last_answer").state == speech


async def test_assist_run_without_stt(
    hass: HomeAssistant, entry: MockConfigEntry, hass_ws_client
) -> None:
    """A pipeline without STT reports an error event."""
    client = await hass_ws_client(hass)
    await client.send_json_auto_id(
        {"type": "even_g1/assist_run", "entry_id": entry.entry_id}
    )
    assert (await client.receive_json())["success"]
    async with asyncio.timeout(5):
        event = (await client.receive_json())["event"]
    assert event["type"] == "error", event
    assert event["data"]["code"] == "stt-provider-missing"
