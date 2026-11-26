--- Wind turbine entity prototypes (per-pair spacing blockers, build preview, and active tower).
--- Loading phase: data.

local constants = require("lib.constants")
local utils = require("lib.utils")

local low_vram = utils.is_startup_enabled(constants.SETTINGS.LOW_VRAM, false)
local quality_dir = low_vram and "LD" or "HD"
local tier_spacings = constants.get_all_tier_spacings()

--- Returns a fresh Factorio 2.1 tower collision mask including the tier's spacing layer.
---@param tier TurbineTierSpec
---@return table
local function make_tower_collision_mask(tier)
  return {
    layers = {
      object = true,
      player = true,
      water_tile = true,
      [tier.spacing_layer] = true,
    },
  }
end

--- Builds the custom tooltip field showing a turbine tier's configured minimum spacing.
---@param tier_spacing integer
---@return table
local function make_spacing_tooltip_field(tier_spacing)
  return {
    key = "wt-turbine-spacing",
    name = { "wt-tooltip.spacing-label" },
    value = { "wt-tooltip.spacing-value", tostring(tier_spacing) },
    order = 10,
  }
end

--- Builds an invisible spacing blocker placed under a `source_tier` turbine to block
--- placement of `target_tier` turbines closer than the symmetric sum-of-radii distance.
---@param source_tier TurbineTierSpec
---@param target_tier TurbineTierSpec
---@return table
local function build_spacing_entity(source_tier, target_tier)
  local half_size = constants.get_spacing_box_half_size(source_tier.level, target_tier.level, tier_spacings)

  return {
    type = "simple-entity-with-force",
    name = constants.spacing_box_name(source_tier.level, target_tier.level),
    localised_name = { "entity-name.ownly_wind_turbine_spacing_box" },
    icon = constants.ASSET_PATH .. "transparent32.png",
    icon_size = 32,
    hidden = true,
    flags = {
      "placeable-neutral",
      "not-on-map",
      "not-blueprintable",
      "not-deconstructable",
      "not-flammable",
    },
    order = "s-e-w-f",
    max_health = 500,
    corpse = "small-remnants",
    collision_box = constants.make_square_box(half_size),
    collision_mask = {
      layers = {
        [target_tier.spacing_layer] = true,
      },
    },
    selection_box = { { -0.9, -0.9 }, { 0.9, 0.9 } },
    selectable_in_game = false,
    render_layer = "wires-above",
    picture = {
      filename = constants.ASSET_PATH .. "transparent32.png",
      width = 32,
      height = 32,
    },
  }
end

--- Builds the placement-preview entity swapped to the active turbine on build.
---@param tier TurbineTierSpec
---@param tier_spacing integer
---@return table
local function build_preview_entity(tier, tier_spacing)
  local scale = tier.visual_scale
  local body_w = low_vram and 300 or 600
  local body_h = low_vram and 400 or 800
  local body_scale = (low_vram and 2 or 1) * scale
  local shadow_w = low_vram and 400 or 800
  local shadow_h = low_vram and 200 or 400
  local shadow_scale = (low_vram and 4 or 2) * scale

  local prototype = {
    type = "electric-energy-interface",
    name = tier.build_name,
    icon = tier.icon,
    icon_size = 144,
    order = tier.order,
    flags = { "placeable-neutral", "player-creation" },
    minable = { mining_time = 0.5, result = tier.name },
    max_health = 500,
    corpse = tier.corpse,
    resistances = {
      { type = "physical", percent = 10 },
    },
    collision_box = constants.make_square_box(tier.collision_half_size),
    selection_box = constants.make_square_box(tier.selection_half_size),
    drawing_box_vertical_extension = math.ceil(constants.BASE_DRAWING_BOX_VERTICAL_EXTENSION * scale),
    collision_mask = make_tower_collision_mask(tier),
    energy_source = {
      type = "electric",
      usage_priority = "primary-output",
      input_flow_limit = "0kW",
      render_no_power_icon = false,
    },
    energy_production = "0kW",
    energy_usage = "0kW",
    animations = {
      layers = {
        {
          filename = constants.ASSET_PATH .. quality_dir .. "/mk" .. tier.level .. "/build_dummy.png",
          width = body_w,
          height = body_h,
          frame_count = constants.FRAME_COUNT,
          line_length = 6,
          shift = constants.scale_offset(constants.MAIN_OFFSET, scale),
          animation_speed = 0.4,
          scale = body_scale,
        },
        {
          filename = constants.ASSET_PATH .. quality_dir .. "/shadows/" .. constants.DEFAULT_ORIENTATION .. ".png",
          width = shadow_w,
          height = shadow_h,
          frame_count = constants.FRAME_COUNT,
          line_length = 5,
          shift = constants.scale_offset(constants.SHADOW_OFFSET, scale),
          animation_speed = 0.4,
          draw_as_shadow = true,
          scale = shadow_scale,
        },
      },
    },
    working_sound = {
      sound = {
        filename = "__base__/sound/train-wheels.ogg",
        volume = 0.6,
      },
      match_speed_to_activity = true,
    },
  }

  utils.add_custom_tooltip_field(prototype, make_spacing_tooltip_field(tier_spacing))
  return prototype
end

--- Builds the active turbine tower entity driven by control.lua.
---@param tier TurbineTierSpec
---@param tier_spacing integer
---@return table
local function build_active_entity(tier, tier_spacing)
  local scale = tier.visual_scale
  local body_w = low_vram and 300 or 600
  local body_h = low_vram and 400 or 800
  local body_scale = (low_vram and 2 or 1) * scale

  local prototype = {
    type = "electric-energy-interface",
    name = tier.name,
    icon = tier.icon,
    icon_size = 144,
    order = tier.order,
    flags = { "placeable-neutral", "player-creation" },
    minable = { mining_time = 0.5, result = tier.name },
    placeable_by = { item = tier.name, count = 1 },
    max_health = 500,
    corpse = tier.corpse,
    resistances = {
      { type = "physical", percent = 10 },
    },
    collision_box = constants.make_square_box(tier.collision_half_size),
    selection_box = constants.make_square_box(tier.selection_half_size),
    drawing_box_vertical_extension = math.ceil(constants.BASE_DRAWING_BOX_VERTICAL_EXTENSION * scale),
    collision_mask = make_tower_collision_mask(tier),
    energy_source = {
      type = "electric",
      usage_priority = "primary-output",
      input_flow_limit = "0kW",
      render_no_power_icon = false,
    },
    energy_production = "0kW",
    energy_usage = "0kW",
    picture = {
      filename = constants.ASSET_PATH .. quality_dir .. "/mk" .. tier.level .. "/base.png",
      width = body_w,
      height = body_h,
      shift = constants.scale_offset(constants.MAIN_OFFSET, scale),
      scale = body_scale,
    },
    working_sound = {
      sound = {
        filename = "__base__/sound/train-wheels.ogg",
        volume = 0.6,
      },
      match_speed_to_activity = true,
    },
  }

  utils.add_custom_tooltip_field(prototype, make_spacing_tooltip_field(tier_spacing))
  return prototype
end

local entities = {}
for _, source_tier in ipairs(constants.TIERS) do
  local tier_spacing = tier_spacings[source_tier.level]
  for _, target_tier in ipairs(constants.TIERS) do
    table.insert(entities, build_spacing_entity(source_tier, target_tier))
  end
  table.insert(entities, build_preview_entity(source_tier, tier_spacing))
  table.insert(entities, build_active_entity(source_tier, tier_spacing))
end

data:extend(entities)
