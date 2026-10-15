"""Constants for the Even Realities G1 integration."""

from typing import Final

DOMAIN: Final = "even_g1"

CONF_DASHBOARD_TEMPLATE: Final = "dashboard_template"
CONF_DASHBOARD_GESTURE: Final = "dashboard_gesture"
CONF_DISPLAY_DURATION: Final = "display_duration"
CONF_ASSIST_PIPELINE: Final = "assist_pipeline"
CONF_SHOW_TRANSCRIPT: Final = "show_transcript"

DEFAULT_DISPLAY_DURATION: Final = 10
DEFAULT_DASHBOARD_TEMPLATE: Final = (
    "{{ now().strftime('%H:%M') }}\n"
    "{% set sun = states.sun.sun %}"
    "{% if sun %}Sonne: {{ sun.state }}{% endif %}"
)
PIPELINE_PREFERRED: Final = "preferred"

DASHBOARD_GESTURE_NONE: Final = "none"

# Gestures reported by the app. These map to the 0xF5 sub commands of the
# G1 BLE protocol (see app/lib/g1/protocol.dart).
GESTURE_SINGLE_TAP_LEFT: Final = "single_tap_left"
GESTURE_SINGLE_TAP_RIGHT: Final = "single_tap_right"
GESTURE_DOUBLE_TAP: Final = "double_tap"
GESTURE_TRIPLE_TAP: Final = "triple_tap"
GESTURE_HEAD_UP: Final = "head_up"
GESTURE_HEAD_DOWN: Final = "head_down"
GESTURE_WORN: Final = "worn"
GESTURE_REMOVED: Final = "removed"
GESTURE_LONG_PRESS: Final = "long_press"
GESTURE_LONG_PRESS_RELEASE: Final = "long_press_release"
GESTURE_OTHER: Final = "other"

GESTURES: Final = [
    GESTURE_SINGLE_TAP_LEFT,
    GESTURE_SINGLE_TAP_RIGHT,
    GESTURE_DOUBLE_TAP,
    GESTURE_TRIPLE_TAP,
    GESTURE_HEAD_UP,
    GESTURE_HEAD_DOWN,
    GESTURE_WORN,
    GESTURE_REMOVED,
    GESTURE_LONG_PRESS,
    GESTURE_LONG_PRESS_RELEASE,
    GESTURE_OTHER,
]

DASHBOARD_GESTURES: Final = [
    DASHBOARD_GESTURE_NONE,
    GESTURE_SINGLE_TAP_LEFT,
    GESTURE_SINGLE_TAP_RIGHT,
    GESTURE_HEAD_UP,
]

EVENT_GESTURE: Final = f"{DOMAIN}_gesture"
EVENT_ASSIST: Final = f"{DOMAIN}_assist"

SERVICE_SHOW_TEXT: Final = "show_text"
SERVICE_CLEAR: Final = "clear"
SERVICE_SHOW_DASHBOARD: Final = "show_dashboard"

ATTR_DEVICE_ID: Final = "device_id"
ATTR_TITLE: Final = "title"
ATTR_MESSAGE: Final = "message"
ATTR_DURATION: Final = "duration"
ATTR_MODE: Final = "mode"

MODE_SCREEN: Final = "screen"
MODE_NOTIFICATION: Final = "notification"

# Payload "type" values sent from Home Assistant to the app.
CMD_SHOW_TEXT: Final = "show_text"
CMD_CLEAR: Final = "clear"
CMD_CONFIG: Final = "config"
CMD_RELOAD: Final = "reload"
