"""Config flow for the Even Realities G1 integration."""

from __future__ import annotations

from typing import Any

import voluptuous as vol

from homeassistant.components import assist_pipeline
from homeassistant.config_entries import ConfigFlow, ConfigFlowResult, OptionsFlow
from homeassistant.const import CONF_NAME
from homeassistant.core import callback
from homeassistant.helpers.selector import (
    BooleanSelector,
    NumberSelector,
    NumberSelectorConfig,
    NumberSelectorMode,
    SelectOptionDict,
    SelectSelector,
    SelectSelectorConfig,
    SelectSelectorMode,
    TemplateSelector,
    TextSelector,
)
from homeassistant.util import slugify

from .const import (
    CONF_ASSIST_PIPELINE,
    CONF_AUTO_GAIN,
    CONF_DASHBOARD_DEPTH,
    CONF_DASHBOARD_GESTURE,
    CONF_DASHBOARD_HEIGHT,
    CONF_DASHBOARD_TEMPLATE,
    CONF_DISPLAY_DURATION,
    CONF_HEAD_UP_ANGLE,
    CONF_NOISE_SUPPRESSION,
    CONF_SHOW_TRANSCRIPT,
    DASHBOARD_GESTURE_NONE,
    DASHBOARD_GESTURES,
    DEFAULT_AUTO_GAIN,
    DEFAULT_DASHBOARD_TEMPLATE,
    DEFAULT_DISPLAY_DURATION,
    DEFAULT_NOISE_SUPPRESSION,
    DOMAIN,
    PIPELINE_PREFERRED,
)

DEFAULT_OPTIONS: dict[str, Any] = {
    CONF_ASSIST_PIPELINE: PIPELINE_PREFERRED,
    CONF_DISPLAY_DURATION: DEFAULT_DISPLAY_DURATION,
    CONF_DASHBOARD_GESTURE: DASHBOARD_GESTURE_NONE,
    CONF_DASHBOARD_TEMPLATE: DEFAULT_DASHBOARD_TEMPLATE,
    CONF_SHOW_TRANSCRIPT: True,
    CONF_AUTO_GAIN: DEFAULT_AUTO_GAIN,
    CONF_NOISE_SUPPRESSION: DEFAULT_NOISE_SUPPRESSION,
}


class EvenG1ConfigFlow(ConfigFlow, domain=DOMAIN):
    """Handle a config flow for Even G1."""

    VERSION = 1

    async def async_step_user(
        self, user_input: dict[str, Any] | None = None
    ) -> ConfigFlowResult:
        """Handle the initial step."""
        if user_input is not None:
            name = user_input[CONF_NAME].strip()
            await self.async_set_unique_id(slugify(name))
            self._abort_if_unique_id_configured()
            return self.async_create_entry(
                title=name, data={}, options=dict(DEFAULT_OPTIONS)
            )

        return self.async_show_form(
            step_id="user",
            data_schema=vol.Schema(
                {vol.Required(CONF_NAME, default="Even G1"): TextSelector()}
            ),
        )

    @staticmethod
    @callback
    def async_get_options_flow(config_entry) -> EvenG1OptionsFlow:
        """Return the options flow."""
        return EvenG1OptionsFlow()


class EvenG1OptionsFlow(OptionsFlow):
    """Options for Even G1."""

    async def async_step_init(
        self, user_input: dict[str, Any] | None = None
    ) -> ConfigFlowResult:
        """Manage the options."""
        if user_input is not None:
            return self.async_create_entry(data=user_input)

        pipelines = [
            SelectOptionDict(value=PIPELINE_PREFERRED, label="preferred"),
            *(
                SelectOptionDict(value=pipeline.id, label=pipeline.name)
                for pipeline in assist_pipeline.async_get_pipelines(self.hass)
            ),
        ]
        options = {**DEFAULT_OPTIONS, **self.config_entry.options}

        schema = vol.Schema(
            {
                vol.Required(
                    CONF_ASSIST_PIPELINE, default=options[CONF_ASSIST_PIPELINE]
                ): SelectSelector(
                    SelectSelectorConfig(
                        options=pipelines,
                        mode=SelectSelectorMode.DROPDOWN,
                        translation_key=CONF_ASSIST_PIPELINE,
                    )
                ),
                vol.Required(
                    CONF_SHOW_TRANSCRIPT, default=options[CONF_SHOW_TRANSCRIPT]
                ): BooleanSelector(),
                vol.Required(
                    CONF_AUTO_GAIN, default=options[CONF_AUTO_GAIN]
                ): NumberSelector(
                    NumberSelectorConfig(
                        min=0,
                        max=31,
                        step=1,
                        unit_of_measurement="dBFS",
                        mode=NumberSelectorMode.SLIDER,
                    )
                ),
                vol.Required(
                    CONF_NOISE_SUPPRESSION, default=options[CONF_NOISE_SUPPRESSION]
                ): NumberSelector(
                    NumberSelectorConfig(
                        min=0, max=4, step=1, mode=NumberSelectorMode.SLIDER
                    )
                ),
                vol.Required(
                    CONF_DISPLAY_DURATION, default=options[CONF_DISPLAY_DURATION]
                ): NumberSelector(
                    NumberSelectorConfig(
                        min=0,
                        max=600,
                        step=1,
                        unit_of_measurement="s",
                        mode=NumberSelectorMode.BOX,
                    )
                ),
                vol.Required(
                    CONF_DASHBOARD_GESTURE, default=options[CONF_DASHBOARD_GESTURE]
                ): SelectSelector(
                    SelectSelectorConfig(
                        options=DASHBOARD_GESTURES,
                        mode=SelectSelectorMode.DROPDOWN,
                        translation_key=CONF_DASHBOARD_GESTURE,
                    )
                ),
                vol.Required(
                    CONF_DASHBOARD_TEMPLATE, default=options[CONF_DASHBOARD_TEMPLATE]
                ): TemplateSelector(),
                # Glasses settings: empty = leave as set in the Even app.
                **{
                    vol.Optional(
                        key,
                        description={"suggested_value": options.get(key)},
                    ): NumberSelector(
                        NumberSelectorConfig(
                            min=low,
                            max=high,
                            step=1,
                            mode=NumberSelectorMode.BOX,
                            **({"unit_of_measurement": unit} if unit else {}),
                        )
                    )
                    for key, low, high, unit in (
                        (CONF_HEAD_UP_ANGLE, 0, 60, "°"),
                        (CONF_DASHBOARD_HEIGHT, 0, 8, None),
                        (CONF_DASHBOARD_DEPTH, 1, 9, None),
                    )
                },
            }
        )
        return self.async_show_form(step_id="init", data_schema=schema)
