--- Wind turbine entity prototypes (spacing blocker, build preview, and active tower).
--- Loading phase: data.

local constants = require("lib.constants")
local utils = require("lib.utils")

local low_vram = utils.is_startup_enabled(constants.SETTINGS.LOW_VRAM, false)
local quality_dir = low_vram and "LD" or "HD"

--- Returns a fresh Factorio 2.1 tower collision mask including the custom spacing layer.
---@return table
local function make_tower_collision_mask()
  return {
    layers = {
      object = true,
      player = true,
      water_tile = true,
      [constants.SPACING_COLLISION_LAYER] = true,
    },
  }
end

--- Builds the hidden 33x33 spacing entity placed beneath each turbine tower.
---@param tier TurbineTierSpec
---@return table
local function build_spacing_entity(tier)
  return {
    type = "simple-entity-with-force",
    name = tier.collision_box_name,
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
    collision_box = constants.SPACING_COLLISION_BOX,
    collision_mask = {
      layers = {
        [constants.SPACING_COLLISION_LAYER] = true,
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
---@return table
local function build_preview_entity(tier)
  local body_w = low_vram and 300 or 600
  local body_h = low_vram and 400 or 800
  local body_scale = low_vram and 2 or 1
  local shadow_w = low_vram and 400 or 800
  local shadow_h = low_vram and 200 or 400
  local shadow_scale = low_vram and 4 or 2

  return {
    type = "electric-energy-interface",
    name = tier.build_name,
    icon = tier.icon,
    icon_size = 144,
    order = tier.order,
    flags = { "placeable-neutral", "player-creation" },
    minable = { mining_time = 0.5, result = tier.name },
    max_health = 500,
    corpse = "medium-remnants",
    resistances = {
      { type = "physical", percent = 10 },
    },
    collision_box = constants.COLLISION_BOX,
    selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } },
    collision_mask = make_tower_collision_mask(),
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
          shift = constants.MAIN_OFFSET,
          animation_speed = 0.4,
          scale = body_scale,
        },
        {
          filename = constants.ASSET_PATH .. quality_dir .. "/shadows/" .. constants.DEFAULT_ORIENTATION .. ".png",
          width = shadow_w,
          height = shadow_h,
          frame_count = constants.FRAME_COUNT,
          line_length = 5,
          shift = constants.SHADOW_OFFSET,
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
end

--- Builds the active turbine tower entity driven by control.lua.
---@param tier TurbineTierSpec
---@return table
local function build_active_entity(tier)
  local body_w = low_vram and 300 or 600
  local body_h = low_vram and 400 or 800
  local body_scale = low_vram and 2 or 1

  return {
    type = "electric-energy-interface",
    name = tier.name,
    icon = tier.icon,
    icon_size = 144,
    order = tier.order,
    flags = { "placeable-neutral", "player-creation" },
    minable = { mining_time = 0.5, result = tier.name },
    placeable_by = { item = tier.name, count = 1 },
    max_health = 500,
    corpse = "big-remnants",
    resistances = {
      { type = "physical", percent = 10 },
    },
    collision_box = constants.COLLISION_BOX,
    selection_box = { { -0.9, -0.9 }, { 0.9, 0.9 } },
    collision_mask = make_tower_collision_mask(),
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
      shift = constants.MAIN_OFFSET,
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
end

for _, tier in ipairs(constants.TIERS) do
  data:extend({
    build_spacing_entity(tier),
    build_preview_entity(tier),
    build_active_entity(tier),
  })
end
