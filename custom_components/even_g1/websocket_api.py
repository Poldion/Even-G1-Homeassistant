"""Websocket API used by the Even G1 companion app."""

from __future__ import annotations

import asyncio
from collections.abc import AsyncGenerator
import logging
from typing import Any

import voluptuous as vol

from homeassistant.components import assist_pipeline, stt, websocket_api
from homeassistant.components.assist_pipeline import (
    AudioSettings,
    PipelineEvent,
    PipelineEventType,
    PipelineStage,
)
from homeassistant.components.assist_pipeline.error import PipelineError
from homeassistant.components.assist_pipeline.pipeline import PipelineRunValidationError
from homeassistant.core import HomeAssistant, callback

from .const import DOMAIN, GESTURES
from .device import EvenG1ConfigEntry, EvenG1Device

_LOGGER = logging.getLogger(__name__)

# Maximum time for one assist run (recording + answer).
ASSIST_TIMEOUT = 120


@callback
def async_register(hass: HomeAssistant) -> None:
    """Register the websocket commands."""
    websocket_api.async_register_command(hass, ws_devices)
    websocket_api.async_register_command(hass, ws_subscribe)
    websocket_api.async_register_command(hass, ws_update_state)
    websocket_api.async_register_command(hass, ws_gesture)
    websocket_api.async_register_command(hass, ws_assist)
    websocket_api.async_register_command(hass, ws_dashboard)
    websocket_api.async_register_command(hass, ws_assist_run)


def _get_device(
    hass: HomeAssistant,
    connection: websocket_api.ActiveConnection,
    msg: dict[str, Any],
) -> EvenG1Device | None:
    entry: EvenG1ConfigEntry | None = hass.config_entries.async_get_entry(
        msg["entry_id"]
    )
    if entry is None or entry.domain != DOMAIN or not hasattr(entry, "runtime_data"):
        connection.send_error(
            msg["id"], websocket_api.ERR_NOT_FOUND, "Even G1 entry not found"
        )
        return None
    return entry.runtime_data


@websocket_api.websocket_command({vol.Required("type"): f"{DOMAIN}/devices"})
@callback
def ws_devices(
    hass: HomeAssistant, connection: websocket_api.ActiveConnection, msg: dict[str, Any]
) -> None:
    """List the configured glasses so the app can pick one."""
    entries: list[EvenG1ConfigEntry] = hass.config_entries.async_loaded_entries(DOMAIN)
    connection.send_result(
        msg["id"],
        [{"entry_id": entry.entry_id, "name": entry.title} for entry in entries],
    )


@websocket_api.websocket_command(
    {vol.Required("type"): f"{DOMAIN}/subscribe", vol.Required("entry_id"): str}
)
@callback
def ws_subscribe(
    hass: HomeAssistant, connection: websocket_api.ActiveConnection, msg: dict[str, Any]
) -> None:
    """Subscribe to display commands for one pair of glasses."""
    if (device := _get_device(hass, connection, msg)) is None:
        return

    msg_id = msg["id"]

    @callback
    def forward(payload: dict[str, Any]) -> None:
        connection.send_message(websocket_api.event_message(msg_id, payload))

    connection.send_result(msg_id)
    connection.subscriptions[msg_id] = device.async_add_subscriber(forward)


@websocket_api.websocket_command(
    {
        vol.Required("type"): f"{DOMAIN}/update_state",
        vol.Required("entry_id"): str,
        vol.Optional("glasses_connected"): bool,
        vol.Optional("battery_left"): vol.Any(None, vol.All(int, vol.Range(0, 100))),
        vol.Optional("battery_right"): vol.Any(None, vol.All(int, vol.Range(0, 100))),
    }
)
@callback
def ws_update_state(
    hass: HomeAssistant, connection: websocket_api.ActiveConnection, msg: dict[str, Any]
) -> None:
    """Receive state updates from the app."""
    if (device := _get_device(hass, connection, msg)) is None:
        return
    device.async_update_state(
        **{k: v for k, v in msg.items() if k not in ("id", "type", "entry_id")}
    )
    connection.send_result(msg["id"])


@websocket_api.websocket_command(
    {
        vol.Required("type"): f"{DOMAIN}/gesture",
        vol.Required("entry_id"): str,
        vol.Required("gesture"): vol.In(GESTURES),
        vol.Optional("side"): vol.In(["left", "right"]),
        vol.Optional("code"): int,
    }
)
@callback
def ws_gesture(
    hass: HomeAssistant, connection: websocket_api.ActiveConnection, msg: dict[str, Any]
) -> None:
    """Receive a touch bar / head gesture from the app."""
    if (device := _get_device(hass, connection, msg)) is None:
        return
    data = {k: msg[k] for k in ("side", "code") if k in msg}
    device.async_handle_gesture(msg["gesture"], data)
    connection.send_result(msg["id"])


@websocket_api.websocket_command(
    {
        vol.Required("type"): f"{DOMAIN}/assist",
        vol.Required("entry_id"): str,
        vol.Required("query"): str,
        vol.Required("response"): str,
    }
)
@callback
def ws_assist(
    hass: HomeAssistant, connection: websocket_api.ActiveConnection, msg: dict[str, Any]
) -> None:
    """Record an assist interaction done from the glasses."""
    if (device := _get_device(hass, connection, msg)) is None:
        return
    device.async_handle_assist(msg["query"], msg["response"])
    connection.send_result(msg["id"])


@websocket_api.websocket_command(
    {vol.Required("type"): f"{DOMAIN}/dashboard", vol.Required("entry_id"): str}
)
@callback
def ws_dashboard(
    hass: HomeAssistant, connection: websocket_api.ActiveConnection, msg: dict[str, Any]
) -> None:
    """Render the dashboard template (used by the app's preview)."""
    if (device := _get_device(hass, connection, msg)) is None:
        return
    connection.send_result(msg["id"], {"text": device.render_dashboard()})


@websocket_api.websocket_command(
    {
        vol.Required("type"): f"{DOMAIN}/assist_run",
        vol.Required("entry_id"): str,
        vol.Optional("conversation_id"): vol.Any(str, None),
    }
)
@websocket_api.async_response
async def ws_assist_run(
    hass: HomeAssistant, connection: websocket_api.ActiveConnection, msg: dict[str, Any]
) -> None:
    """Run the configured Assist pipeline on audio recorded by the glasses.

    Unlike ``assist_pipeline/run`` this does not use voice activity detection:
    the recording lasts exactly as long as the touch bar is held, so pauses
    while speaking do not cut off the question.

    Protocol: after the result, an ``audio-ready`` event carries the binary
    handler id. The app sends 16 kHz 16 bit mono PCM as binary messages
    prefixed with that id and an empty message (only the id) at the end.
    All pipeline events (``stt-end``, ``intent-end``, ``error``, ...) follow.
    """
    if (device := _get_device(hass, connection, msg)) is None:
        return
    msg_id = msg["id"]

    try:
        pipeline = assist_pipeline.async_get_pipeline(hass, device.pipeline_id)
    except PipelineError as err:
        connection.send_error(msg_id, err.code, err.message)
        return

    audio_queue: asyncio.Queue[bytes] = asyncio.Queue()

    async def stt_stream() -> AsyncGenerator[bytes]:
        while chunk := await audio_queue.get():
            yield chunk

    @callback
    def handle_binary(
        _hass: HomeAssistant, _connection: websocket_api.ActiveConnection, data: bytes
    ) -> None:
        audio_queue.put_nowait(data)

    handler_id, unregister_handler = connection.async_register_binary_handler(
        handle_binary
    )

    query = ""

    @callback
    def send_error(code: str, message: str) -> None:
        connection.send_event(
            msg_id, {"type": "error", "data": {"code": code, "message": message}}
        )

    @callback
    def on_event(event: PipelineEvent) -> None:
        nonlocal query
        connection.send_event(msg_id, event)
        data = event.data or {}
        if event.type == PipelineEventType.STT_END:
            query = (data.get("stt_output") or {}).get("text", "").strip()
        elif event.type == PipelineEventType.INTENT_END:
            response = (
                ((data.get("intent_output") or {}).get("response") or {})
                .get("speech", {})
                .get("plain", {})
                .get("speech", "")
            )
            device.async_handle_assist(query, response.strip())

    async def run() -> None:
        try:
            await assist_pipeline.async_pipeline_from_audio_stream(
                hass,
                context=connection.context(msg),
                event_callback=on_event,
                stt_metadata=stt.SpeechMetadata(
                    language=pipeline.stt_language or pipeline.language,
                    format=stt.AudioFormats.WAV,
                    codec=stt.AudioCodecs.PCM,
                    bit_rate=stt.AudioBitRates.BITRATE_16,
                    sample_rate=stt.AudioSampleRates.SAMPLERATE_16000,
                    channel=stt.AudioChannels.CHANNEL_MONO,
                ),
                stt_stream=stt_stream(),
                pipeline_id=pipeline.id,
                conversation_id=msg.get("conversation_id"),
                device_id=device.device_id,
                start_stage=PipelineStage.STT,
                end_stage=PipelineStage.INTENT,
                audio_settings=AudioSettings(
                    is_vad_enabled=False,
                    auto_gain_dbfs=device.auto_gain,
                    noise_suppression_level=device.noise_suppression,
                ),
            )
        except PipelineError as err:
            send_error(err.code, err.message)
        except PipelineRunValidationError as err:
            # e.g. the pipeline has no speech-to-text engine
            send_error("stt-provider-missing", str(err))
        except Exception as err:
            _LOGGER.exception("Error running assist for %s", device.name)
            send_error("unknown", str(err))

    connection.send_result(msg_id)
    connection.send_event(
        msg_id, {"type": "audio-ready", "data": {"handler_id": handler_id}}
    )
    task = hass.async_create_task(run(), "even_g1 assist")
    # Unsubscribing (or the app disconnecting) cancels the run.
    connection.subscriptions[msg_id] = task.cancel
    try:
        _, pending = await asyncio.wait({task}, timeout=ASSIST_TIMEOUT)
        if pending:
            task.cancel()
            send_error("timeout", "Timeout running the assist pipeline")
    finally:
        unregister_handler()
