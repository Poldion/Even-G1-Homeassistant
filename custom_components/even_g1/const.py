"""Constants for the Even Realities G1 integration."""

from typing import Final

DOMAIN: Final = "even_g1"

CONF_DASHBOARD_TEMPLATE: Final = "dashboard_template"
CONF_DASHBOARD_ENTITIES: Final = "dashboard_entities"
CONF_DASHBOARD_GESTURE: Final = "dashboard_gesture"
CONF_DASHBOARD_CALENDARS: Final = "dashboard_calendars"
CONF_DASHBOARD_TODOS: Final = "dashboard_todos"
CONF_DASHBOARD_STYLE: Final = "dashboard_style"
CONF_LISTENING_TEMPLATE: Final = "listening_template"
CONF_DISPLAY_DURATION: Final = "display_duration"
CONF_ASSIST_PIPELINE: Final = "assist_pipeline"
CONF_SHOW_TRANSCRIPT: Final = "show_transcript"
CONF_AUTO_GAIN: Final = "auto_gain"
CONF_NOISE_SUPPRESSION: Final = "noise_suppression"

DEFAULT_DISPLAY_DURATION: Final = 10
# Default template of versions up to 0.8.0; treated like "no template" so
# existing entries get the built-in layout.
LEGACY_DASHBOARD_TEMPLATE: Final = (
    "{{ now().strftime('%H:%M') }}\n"
    "{% set sun = states.sun.sun %}"
    "{% if sun %}Sonne: {{ sun.state }}{% endif %}"
)
PIPELINE_PREFERRED: Final = "preferred"
DEFAULT_AUTO_GAIN: Final = 0

DEFAULT_NOISE_SUPPRESSION: Final = 0

DASHBOARD_GESTURE_NONE: Final = "none"

# Designs of the dashboard (drawn by ScouterKit; Even's firmware shows text).
DASHBOARD_STYLE_PLAIN: Final = "plain"
DASHBOARD_STYLES: Final = [DASHBOARD_STYLE_PLAIN, "frame", "card", "title", "lab"]

# Design set of the Assist status and the silent mode animation (ScouterKit):
# classic frames, or the lab set (brackets, typed text, scan line).
CONF_DESIGN_SET: Final = "design_set"
DESIGN_SET_CLASSIC: Final = "classic"
DESIGN_SETS: Final = [DESIGN_SET_CLASSIC, "lab"]

# The default text while the touch bar is held (ScouterKit) is in lang.py.

# Gestures reported by the app. These map to the 0xF5 sub commands of the
# G1 BLE protocol (see app/lib/g1/protocol.dart).
GESTURE_SINGLE_TAP_LEFT: Final = "single_tap_left"
GESTURE_SINGLE_TAP_RIGHT: Final = "single_tap_right"
GESTURE_DOUBLE_TAP: Final = "double_tap"
GESTURE_TRIPLE_TAP: Final = "triple_tap"
GESTURE_HEAD_UP: Final = "head_up"
GESTURE_HEAD_DOWN: Final = "head_down"
GESTURE_LONG_PRESS: Final = "long_press"
GESTURE_LONG_PRESS_RELEASE: Final = "long_press_release"
# Only with ScouterKit (g1v0): the right long press, and nodding and shaking
# the head (recognised by a program on the right arm, if switched on).
GESTURE_LONG_PRESS_RIGHT: Final = "long_press_right"
GESTURE_LONG_PRESS_RIGHT_RELEASE: Final = "long_press_right_release"
GESTURE_NOD: Final = "nod"
GESTURE_HEAD_SHAKE: Final = "head_shake"
GESTURE_OTHER: Final = "other"

GESTURES: Final = [
    GESTURE_SINGLE_TAP_LEFT,
    GESTURE_SINGLE_TAP_RIGHT,
    GESTURE_DOUBLE_TAP,
    GESTURE_TRIPLE_TAP,
    GESTURE_HEAD_UP,
    GESTURE_HEAD_DOWN,
    GESTURE_LONG_PRESS,
    GESTURE_LONG_PRESS_RELEASE,
    GESTURE_LONG_PRESS_RIGHT,
    GESTURE_LONG_PRESS_RIGHT_RELEASE,
    GESTURE_NOD,
    GESTURE_HEAD_SHAKE,
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
CMD_SILENT_MODE: Final = "silent_mode"
CMD_RECORDING: Final = "recording"
CMD_WEAR_DETECTION: Final = "wear_detection"
CMD_CONFIG: Final = "config"
CMD_RELOAD: Final = "reload"
CMD_DASHBOARD: Final = "dashboard"
CMD_LISTENING: Final = "listening"

# Where the glasses are (status pushes 0x06/0x07/0x08/0x0B).
WEAR_STATES: Final = ["worn", "not_worn", "case_open", "case_closed"]
