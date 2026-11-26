--- Shared constants and data-driven tier definitions.
--- Loading phase: settings, data, data-final-fixes, control.

local MOD_NAME = "ethanatos-windturbines-redux-2.1-se"
local ASSET_PATH = "__" .. MOD_NAME .. "__/graphics/"

local function pack(name)
  return { name, 1 }
end

local constants = {
  MOD_NAME = MOD_NAME,
  ASSET_PATH = ASSET_PATH,

  -- Dedicated 2.1 collision layer enforcing inter-turbine spacing without touching vanilla "resource".
  SPACING_COLLISION_LAYER = "wt-turbine-spacing",

  ROTATION_COUNT = 32,
  FRAME_COUNT = 24,
  DEFAULT_ORIENTATION = 16,
  -- 0.02 vanilla Nauvis wind * 22 legacy multiplier = 0.44 frames/tick at 1.0x reference wind.
  BASE_ANIMATION_SPEED = 0.44,
  MAX_ANIMATION_SPEED = 1.5,
  WIND_VARIATION_INTERVAL = 300,
  WIND_EPSILON = 1e-5,

  -- Geometry and sprite offsets preserved from upstream OwnlyMe / Seth401 graphics
  COLLISION_BOX = { { -1.2, -1.2 }, { 1.2, 1.2 } },
  SPACING_COLLISION_BOX = { { -16.5, -16.5 }, { 16.5, 16.5 } },
  MAIN_OFFSET = { 0.15, -11 },
  SHADOW_OFFSET = { 9.5, -3.6 },
  BLADES_OFFSET = { 0.15, -1 },
  BLADES_SHADOW_OFFSET = { 3.5, -2.6 },
  RENDER_TURBINE_OFFSET = { 0, -10 },
  RENDER_SHADOW_OFFSET = { 6, -1 },

  SETTINGS = {
    LOW_VRAM = "wt-low-vram",
    SE_BALANCING = "wt-se-balancing",
    SE_BLOCK_IN_SPACE = "wt-se-block-in-space",
    POWER_MK1 = "wt-power-mk1",
    POWER_MK2 = "wt-power-mk2",
    POWER_MK3 = "wt-power-mk3",
    LOCKED_POWER = "wt-locked-power",
    VARY_WINDSPEED = "wt-vary-windspeed",
    REFERENCE_WIND_SPEED = "wt-reference-wind-speed",
    AUTO_CALIBRATE_WSC = "wt-auto-calibrate-wsc",
    MAX_WIND_MULTIPLIER = "wt-max-wind-multiplier",
    UPDATE_INTERVAL = "wt-update-interval",
  },
}

---@class TurbineTechSpec
---@field prerequisites string[]
---@field count uint32
---@field time double
---@field ingredients table[]

---@class TurbineTierSpec
---@field level uint8
---@field name string
---@field build_name string
---@field collision_box_name string
---@field icon string
---@field order string
---@field power_setting string
---@field default_power_kw double
---@field ingredients table[]
---@field vanilla_tech TurbineTechSpec
---@field se_tech TurbineTechSpec

---@type TurbineTierSpec[]
constants.TIERS = {
  {
    level = 1,
    name = "ownly_wind_turbine_mk1",
    build_name = "ownly_wind_turbine_build_mk1",
    collision_box_name = "ownly_wind_turbine_collision_box_mk1",
    icon = ASSET_PATH .. "mk1_icon.png",
    order = "d[solar-panel]-z[wind-turbine]-1",
    power_setting = constants.SETTINGS.POWER_MK1,
    default_power_kw = 750.0,
    ingredients = {
      { type = "item", name = "plastic-bar", amount = 40 },
      { type = "item", name = "steel-plate", amount = 50 },
      { type = "item", name = "copper-cable", amount = 120 },
      { type = "item", name = "electronic-circuit", amount = 25 },
    },
    vanilla_tech = {
      prerequisites = { "plastics", "logistic-science-pack" },
      count = 200,
      time = 30,
      ingredients = { pack("automation-science-pack"), pack("logistic-science-pack") },
    },
    se_tech = {
      prerequisites = { "plastics", "electric-energy-distribution-1" },
      count = 200,
      time = 30,
      ingredients = { pack("automation-science-pack"), pack("logistic-science-pack") },
    },
  },
  {
    level = 2,
    name = "ownly_wind_turbine_mk2",
    build_name = "ownly_wind_turbine_build_mk2",
    collision_box_name = "ownly_wind_turbine_collision_box_mk2",
    icon = ASSET_PATH .. "mk2_icon.png",
    order = "d[solar-panel]-z[wind-turbine]-2",
    power_setting = constants.SETTINGS.POWER_MK2,
    default_power_kw = 1500.0,
    ingredients = {
      { type = "item", name = "ownly_wind_turbine_mk1", amount = 3 },
      { type = "item", name = "electric-engine-unit", amount = 10 },
      { type = "item", name = "advanced-circuit", amount = 25 },
    },
    vanilla_tech = {
      prerequisites = { "ownly_wind_turbine_mk1", "electric-engine", "electric-energy-distribution-1" },
      count = 350,
      time = 30,
      ingredients = {
        pack("automation-science-pack"),
        pack("logistic-science-pack"),
        pack("chemical-science-pack"),
      },
    },
    se_tech = {
      prerequisites = { "ownly_wind_turbine_mk1", "electric-engine" },
      count = 350,
      time = 30,
      ingredients = {
        pack("automation-science-pack"),
        pack("logistic-science-pack"),
        pack("chemical-science-pack"),
      },
    },
  },
  {
    level = 3,
    name = "ownly_wind_turbine_mk3",
    build_name = "ownly_wind_turbine_build_mk3",
    collision_box_name = "ownly_wind_turbine_collision_box_mk3",
    icon = ASSET_PATH .. "mk3_icon.png",
    order = "d[solar-panel]-z[wind-turbine]-3",
    power_setting = constants.SETTINGS.POWER_MK3,
    default_power_kw = 3000.0,
    ingredients = {
      { type = "item", name = "ownly_wind_turbine_mk2", amount = 3 },
      { type = "item", name = "low-density-structure", amount = 50 },
      { type = "item", name = "processing-unit", amount = 25 },
    },
    vanilla_tech = {
      prerequisites = { "ownly_wind_turbine_mk2", "low-density-structure", "utility-science-pack" },
      count = 500,
      time = 30,
      ingredients = {
        pack("automation-science-pack"),
        pack("logistic-science-pack"),
        pack("chemical-science-pack"),
        pack("utility-science-pack"),
      },
    },
    -- SE Option A: unlocks Mk3 with processing-unit + se-rocket-science-pack for planetary outposts.
    se_tech = {
      prerequisites = {
        "ownly_wind_turbine_mk2",
        "low-density-structure",
        "processing-unit",
        "se-rocket-science-pack",
      },
      count = 500,
      time = 30,
      ingredients = {
        pack("automation-science-pack"),
        pack("logistic-science-pack"),
        pack("chemical-science-pack"),
        pack("se-rocket-science-pack"),
      },
    },
  },
}

---@type table<string, uint8>
constants.TURBINE_LEVEL_BY_NAME = {}
for _, tier in ipairs(constants.TIERS) do
  constants.TURBINE_LEVEL_BY_NAME[tier.build_name] = tier.level
  constants.TURBINE_LEVEL_BY_NAME[tier.name] = tier.level
end

return constants
