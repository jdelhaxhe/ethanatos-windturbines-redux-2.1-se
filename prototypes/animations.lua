--- 32-direction rotor and shadow animation prototypes (HD or Low-VRAM LD).
--- Loading phase: data.

local constants = require("lib.constants")
local utils = require("lib.utils")

local low_vram = utils.is_startup_enabled(constants.SETTINGS.LOW_VRAM, false)
local quality_dir = low_vram and "LD" or "HD"

--- Maps a 0..31 direction index to its sprite index (snapped to even steps in Low-VRAM mode).
---@param index integer
---@return integer
local function resolve_rotation_index(index)
  if low_vram then
    return math.floor(index / 2) * 2
  end
  return index
end

--- Builds the 32 shadow animation prototypes shared by all turbine tiers.
---@return table[]
local function build_shadow_animations()
  local prototypes = {}
  local width = low_vram and 400 or 800
  local height = low_vram and 200 or 400
  local scale = low_vram and 4 or 2

  for index = 0, constants.ROTATION_COUNT - 1 do
    local rotation = resolve_rotation_index(index)
    table.insert(prototypes, {
      type = "animation",
      name = "ownly_wind_turbine_shadow_" .. index,
      filename = constants.ASSET_PATH .. quality_dir .. "/shadows/" .. rotation .. ".png",
      width = width,
      height = height,
      frame_count = constants.FRAME_COUNT,
      line_length = 5,
      shift = constants.BLADES_SHADOW_OFFSET,
      animation_speed = 1,
      draw_as_shadow = true,
      scale = scale,
    })
  end

  return prototypes
end

--- Builds the 32 rotor animation prototypes for a single turbine tier.
---@param tier TurbineTierSpec
---@return table[]
local function build_tier_rotor_animations(tier)
  local prototypes = {}
  local width = low_vram and 300 or 600
  local height = low_vram and 400 or 800
  local scale = low_vram and 2 or 1

  for index = 0, constants.ROTATION_COUNT - 1 do
    local rotation = resolve_rotation_index(index)
    table.insert(prototypes, {
      type = "animation",
      name = tier.name .. "_" .. index,
      filename = constants.ASSET_PATH .. quality_dir .. "/mk" .. tier.level .. "/" .. rotation .. ".png",
      width = width,
      height = height,
      frame_count = constants.FRAME_COUNT,
      line_length = 6,
      shift = constants.BLADES_OFFSET,
      animation_speed = 1,
      scale = scale,
    })
  end

  return prototypes
end

data:extend(build_shadow_animations())

for _, tier in ipairs(constants.TIERS) do
  data:extend(build_tier_rotor_animations(tier))
end
