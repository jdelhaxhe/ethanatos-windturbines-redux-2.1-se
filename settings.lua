--- Startup and runtime-global mod settings definitions.
--- Loading phase: settings.

local constants = require("lib.constants")
local S = constants.SETTINGS

data:extend({
  -- Startup settings
  {
    type = "bool-setting",
    name = S.LOW_VRAM,
    setting_type = "startup",
    default_value = false,
    order = "a-a",
  },
  {
    type = "bool-setting",
    name = S.SE_BALANCING,
    setting_type = "startup",
    default_value = true,
    order = "a-b",
  },
  {
    type = "bool-setting",
    name = S.SE_BLOCK_IN_SPACE,
    setting_type = "startup",
    default_value = true,
    order = "a-c",
  },

  -- Runtime-global power output settings (kW at 1.0x reference wind speed)
  {
    type = "double-setting",
    name = S.POWER_MK1,
    setting_type = "runtime-global",
    default_value = 750.0,
    minimum_value = 10.0,
    maximum_value = 100000.0,
    order = "b-a",
  },
  {
    type = "double-setting",
    name = S.POWER_MK2,
    setting_type = "runtime-global",
    default_value = 1500.0,
    minimum_value = 10.0,
    maximum_value = 200000.0,
    order = "b-b",
  },
  {
    type = "double-setting",
    name = S.POWER_MK3,
    setting_type = "runtime-global",
    default_value = 3000.0,
    minimum_value = 10.0,
    maximum_value = 500000.0,
    order = "b-c",
  },

  -- Runtime-global wind scaling & UPS behavior
  {
    type = "bool-setting",
    name = S.LOCKED_POWER,
    setting_type = "runtime-global",
    default_value = false,
    order = "c-a",
  },
  {
    type = "bool-setting",
    name = S.VARY_WINDSPEED,
    setting_type = "runtime-global",
    default_value = true,
    order = "c-b",
  },
  {
    type = "double-setting",
    name = S.REFERENCE_WIND_SPEED,
    setting_type = "runtime-global",
    default_value = 0.02,
    minimum_value = 0.001,
    maximum_value = 1.0,
    order = "c-c",
  },
  {
    type = "bool-setting",
    name = S.AUTO_CALIBRATE_WSC,
    setting_type = "runtime-global",
    default_value = true,
    order = "c-d",
  },
  {
    type = "double-setting",
    name = S.MAX_WIND_MULTIPLIER,
    setting_type = "runtime-global",
    default_value = 2.0,
    minimum_value = 1.0,
    maximum_value = 5.0,
    order = "c-e",
  },
  {
    type = "int-setting",
    name = S.UPDATE_INTERVAL,
    setting_type = "runtime-global",
    default_value = 30,
    minimum_value = 5,
    maximum_value = 600,
    order = "d-a",
  },
})

