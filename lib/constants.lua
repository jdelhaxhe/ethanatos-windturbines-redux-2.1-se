--- Shared constants, geometry helpers, and data-driven tier definitions.
--- Loading phase: settings, data, data-final-fixes, control.

local MOD_NAME = "ethanatos-windturbines-redux-2.1-se"
local ASSET_PATH = "__" .. MOD_NAME .. "__/graphics/"

local function pack(name)
  return { name, 1 }
end

local constants = {
  MOD_NAME = MOD_NAME,
  ASSET_PATH = ASSET_PATH,

  ROTATION_COUNT = 32,
  FRAME_COUNT = 24,
  DEFAULT_ORIENTATION = 16,
  -- 0.02 vanilla Nauvis wind * 22 legacy multiplier = 0.44 frames/tick at 1.0x reference wind.
  BASE_ANIMATION_SPEED = 0.44,
  MAX_ANIMATION_SPEED = 1.5,
  WIND_VARIATION_INTERVAL = 300,
  WIND_EPSILON = 1e-5,

  -- Reference (1.0x scale) sprite and render offsets from upstream OwnlyMe / Seth401 graphics.
  -- Scaled per tier via `constants.scale_offset(offset, tier.visual_scale)` so the tower base
  -- stays anchored at world origin (0, 0) for every tier.
  MAIN_OFFSET = { 0.15, -11 },
  SHADOW_OFFSET = { 9.5, -3.6 },
  BLADES_OFFSET = { 0.15, -1 },
  BLADES_SHADOW_OFFSET = { 3.5, -2.6 },
  RENDER_TURBINE_OFFSET = { 0, -10 },
  RENDER_SHADOW_OFFSET = { 6, -1 },
  -- Reference vertical drawing extension at 1.0x scale to avoid tall-tower pop-in at screen bottom.
  BASE_DRAWING_BOX_VERTICAL_EXTENSION = 24,

  -- Subtle premultiplied-alpha colors for the ground spacing overlay (Factorio LuaRendering uses
  -- premultiplied RGBA, so RGB values are multiplied by `a` to avoid neon additive glow).
  OVERLAY_FILL_COLOR = { r = 0.108, g = 0.012, b = 0.012, a = 0.12 },
  OVERLAY_BORDER_COLOR = { r = 0.475, g = 0.075, b = 0.075, a = 0.50 },
  OVERLAY_BORDER_WIDTH = 2,

  SETTINGS = {
    LOW_VRAM = "wt-low-vram",
    SE_BALANCING = "wt-se-balancing",
    SE_BLOCK_IN_SPACE = "wt-se-block-in-space",
    SPACING_MK1 = "wt-spacing-mk1",
    SPACING_MK2 = "wt-spacing-mk2",
    SPACING_MK3 = "wt-spacing-mk3",
    POWER_MK1 = "wt-power-mk1",
    POWER_MK2 = "wt-power-mk2",
    POWER_MK3 = "wt-power-mk3",
    LOCKED_POWER = "wt-locked-power",
    VARY_WINDSPEED = "wt-vary-windspeed",
    REFERENCE_WIND_SPEED = "wt-reference-wind-speed",
    AUTO_CALIBRATE_WSC = "wt-auto-calibrate-wsc",
    MAX_WIND_MULTIPLIER = "wt-max-wind-multiplier",
    UPDATE_INTERVAL = "wt-update-interval",
    SHOW_SPACING_OVERLAY = "wt-show-spacing-overlay",
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
---@field spacing_layer string
---@field icon string
---@field order string
---@field visual_scale double
---@field collision_half_size double
---@field selection_half_size double
---@field corpse string
---@field spacing_setting string
---@field default_spacing uint32
---@field power_setting string
---@field default_power_kw double
---@field ingredients table[]
---@field se_ingredients table[]?
---@field vanilla_tech TurbineTechSpec
---@field se_tech TurbineTechSpec

---@type TurbineTierSpec[]
constants.TIERS = {
  {
    level = 1,
    name = "ownly_wind_turbine_mk1",
    build_name = "ownly_wind_turbine_build_mk1",
    spacing_layer = "wt-spacing-for-mk1",
    icon = ASSET_PATH .. "mk1_icon.png",
    order = "d[solar-panel]-z[wind-turbine]-1",
    visual_scale = 0.75,
    -- All tiers keep collision half-sizes in (1.0, 1.5] so every tower snaps to the same 3x3 odd grid.
    collision_half_size = 1.05,
    selection_half_size = 0.75,
    corpse = "medium-remnants",
    spacing_setting = constants.SETTINGS.SPACING_MK1,
    default_spacing = 18,
    power_setting = constants.SETTINGS.POWER_MK1,
    default_power_kw = 750.0,
    ingredients = {
      { type = "item", name = "copper-cable", amount = 50 },
      { type = "item", name = "plastic-bar", amount = 50 },
      { type = "item", name = "steel-plate", amount = 40 },
      { type = "item", name = "electronic-circuit", amount = 10 },
      { type = "item", name = "concrete", amount = 100 },
    },
    vanilla_tech = {
      prerequisites = { "plastics", "concrete", "logistic-science-pack" },
      count = 200,
      time = 30,
      ingredients = { pack("automation-science-pack"), pack("logistic-science-pack") },
    },
    se_tech = {
      prerequisites = { "plastics", "concrete", "electric-energy-distribution-1" },
      count = 200,
      time = 30,
      ingredients = { pack("automation-science-pack"), pack("logistic-science-pack") },
    },
  },
  {
    level = 2,
    name = "ownly_wind_turbine_mk2",
    build_name = "ownly_wind_turbine_build_mk2",
    spacing_layer = "wt-spacing-for-mk2",
    icon = ASSET_PATH .. "mk2_icon.png",
    order = "d[solar-panel]-z[wind-turbine]-2",
    visual_scale = 1.00,
    collision_half_size = 1.20,
    selection_half_size = 0.90,
    corpse = "big-remnants",
    spacing_setting = constants.SETTINGS.SPACING_MK2,
    default_spacing = 23,
    power_setting = constants.SETTINGS.POWER_MK2,
    default_power_kw = 1500.0,
    ingredients = {
      { type = "item", name = "ownly_wind_turbine_mk1", amount = 2 },
      { type = "item", name = "advanced-circuit", amount = 5 },
      { type = "item", name = "low-density-structure", amount = 5 },
    },
    vanilla_tech = {
      prerequisites = { "ownly_wind_turbine_mk1", "low-density-structure", "electric-energy-distribution-1" },
      count = 350,
      time = 30,
      ingredients = {
        pack("automation-science-pack"),
        pack("logistic-science-pack"),
        pack("chemical-science-pack"),
      },
    },
    se_tech = {
      prerequisites = { "ownly_wind_turbine_mk1", "low-density-structure", "se-rocket-science-pack" },
      count = 350,
      time = 30,
      ingredients = {
        pack("automation-science-pack"),
        pack("logistic-science-pack"),
        pack("chemical-science-pack"),
        pack("se-rocket-science-pack"),
      },
    },
  },
  {
    level = 3,
    name = "ownly_wind_turbine_mk3",
    build_name = "ownly_wind_turbine_build_mk3",
    spacing_layer = "wt-spacing-for-mk3",
    icon = ASSET_PATH .. "mk3_icon.png",
    order = "d[solar-panel]-z[wind-turbine]-3",
    visual_scale = 1.30,
    collision_half_size = 1.45,
    selection_half_size = 1.15,
    corpse = "big-remnants",
    spacing_setting = constants.SETTINGS.SPACING_MK3,
    default_spacing = 30,
    power_setting = constants.SETTINGS.POWER_MK3,
    default_power_kw = 3000.0,
    ingredients = {
      { type = "item", name = "ownly_wind_turbine_mk2", amount = 2 },
      { type = "item", name = "low-density-structure", amount = 4 },
      { type = "item", name = "processing-unit", amount = 4 },
      { type = "item", name = "electric-engine-unit", amount = 4 },
    },
    se_ingredients = {
      { type = "item", name = "ownly_wind_turbine_mk2", amount = 2 },
      { type = "item", name = "se-aeroframe-pole", amount = 4 },
      { type = "item", name = "processing-unit", amount = 4 },
      { type = "item", name = "electric-engine-unit", amount = 4 },
    },
    vanilla_tech = {
      prerequisites = { "ownly_wind_turbine_mk2", "electric-engine", "processing-unit", "utility-science-pack" },
      count = 500,
      time = 30,
      ingredients = {
        pack("automation-science-pack"),
        pack("logistic-science-pack"),
        pack("chemical-science-pack"),
        pack("utility-science-pack"),
      },
    },
    -- SE Option A: unlocks Mk3 alongside utility science & beryllium aeroframe poles.
    se_tech = {
      prerequisites = {
        "ownly_wind_turbine_mk2",
        "electric-engine",
        "processing-unit",
        "utility-science-pack",
        "se-aeroframe-pole",
      },
      count = 500,
      time = 30,
      ingredients = {
        pack("automation-science-pack"),
        pack("logistic-science-pack"),
        pack("chemical-science-pack"),
        pack("se-rocket-science-pack"),
        pack("space-science-pack"),
        pack("utility-science-pack"),
        pack("se-astronomic-science-pack-1"),
      },
    },
  },
}

---@type table<uint8, TurbineTierSpec>
constants.TIER_BY_LEVEL = {}
---@type table<string, uint8>
constants.TURBINE_LEVEL_BY_NAME = {}
---@type table<string, uint8>
constants.TURBINE_LEVEL_BY_ITEM = {}

for _, tier in ipairs(constants.TIERS) do
  constants.TIER_BY_LEVEL[tier.level] = tier
  constants.TURBINE_LEVEL_BY_NAME[tier.build_name] = tier.level
  constants.TURBINE_LEVEL_BY_NAME[tier.name] = tier.level
  constants.TURBINE_LEVEL_BY_ITEM[tier.name] = tier.level
end

--- Builds the prototype name for the invisible spacing box placed under a `source_level`
--- turbine to enforce minimum center-to-center distance against `target_level` turbines.
---@param source_level uint8
---@param target_level uint8
---@return string
function constants.spacing_box_name(source_level, target_level)
  return "ownly_wind_turbine_spacing_mk" .. source_level .. "_for_mk" .. target_level
end

--- Scales a 2D `{ x, y }` sprite or render offset by `scale`.
---@param offset double[]
---@param scale double
---@return double[]
function constants.scale_offset(offset, scale)
  return { offset[1] * scale, offset[2] * scale }
end

--- Builds a centered square BoundingBox `{ { -h, -h }, { h, h } }`.
---@param half_size double
---@return table
function constants.make_square_box(half_size)
  return { { -half_size, -half_size }, { half_size, half_size } }
end

--- Reads the configured minimum same-tier spacing (in tiles) for a tier from startup settings.
---@param tier TurbineTierSpec
---@return integer
function constants.get_tier_spacing(tier)
  if settings and settings.startup and settings.startup[tier.spacing_setting] then
    return settings.startup[tier.spacing_setting].value
  end
  return tier.default_spacing
end

--- Returns a map `{ [level] = spacing_tiles }` for all tiers from startup settings.
---@return table<uint8, integer>
function constants.get_all_tier_spacings()
  local spacings = {}
  for _, tier in ipairs(constants.TIERS) do
    spacings[tier.level] = constants.get_tier_spacing(tier)
  end
  return spacings
end

--- Computes the symmetric center-to-center minimum spacing between two tiers using
--- the sum-of-radii rule: `ceil((D_a + D_b) / 2)`.
---@param level_a uint8
---@param level_b uint8
---@param spacings table<uint8, integer>
---@return integer
function constants.get_pair_spacing(level_a, level_b, spacings)
  return math.ceil((spacings[level_a] + spacings[level_b]) / 2)
end

--- Computes the exact half-size of the spacing box placed under `source_level` to block
--- `target_level` at Chebyshev distances `< D` while allowing placement at `>= D`.
---@param source_level uint8
---@param target_level uint8
---@param spacings table<uint8, integer>
---@return double
function constants.get_spacing_box_half_size(source_level, target_level, spacings)
  local target_tier = constants.TIER_BY_LEVEL[target_level]
  local pair_spacing = constants.get_pair_spacing(source_level, target_level, spacings)
  -- Midpoint `h + r_target = D - 0.5` sits cleanly halfway between blocked (D - 1) and allowed (D).
  return math.max(0.5, pair_spacing - target_tier.collision_half_size - 0.5)
end

return constants
