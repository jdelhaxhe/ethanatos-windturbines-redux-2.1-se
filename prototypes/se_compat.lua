--- Space Exploration 0.7+ compatibility overrides (space blocking & tech progression).
--- Loading phase: data-final-fixes.

local constants = require("lib.constants")
local utils = require("lib.utils")

local se_compat = {}

--- Enforces space placement restriction on all wind turbine entity prototypes.
--- SE's phase-3/space-collision.lua does not include "electric-energy-interface" in
--- block_from_space, so we must set se_allow_in_space = false and add SE's space_tile
--- collision layer explicitly in Factorio 2.1 dictionary format.
local function apply_space_placement_restrictions()
  local eei_table = data.raw["electric-energy-interface"]
  if not eei_table then
    return
  end

  -- Resolve SE's space collision layer name cleanly without hard-requiring internal modules.
  local space_layer = _G.space_collision_layer or "space_tile"
  local has_space_layer = data.raw["collision-layer"] and data.raw["collision-layer"][space_layer]

  for _, tier in ipairs(constants.TIERS) do
    for _, entity_name in ipairs({ tier.build_name, tier.name }) do
      local prototype = eei_table[entity_name]
      if prototype then
        prototype.se_allow_in_space = false
        if has_space_layer then
          utils.add_collision_layer(prototype, space_layer)
          utils.add_se_space_restriction_tooltip(prototype)
        end
      end
    end
  end
end

--- Aligns wind turbine technology prerequisites and science packs with SE 0.7 progression.
local function apply_se_technology_balancing()
  for _, tier in ipairs(constants.TIERS) do
    utils.apply_technology_spec(tier.name, tier.se_tech)
  end
end

--- Applies Space Exploration recipe overrides (e.g., `se-aeroframe-pole` on Mk3)
--- when all required SE items exist in `data.raw.item`.
local function apply_se_recipe_overrides()
  local recipes = data.raw and data.raw.recipe
  local items = data.raw and data.raw.item
  if not (recipes and items) then
    return
  end

  for _, tier in ipairs(constants.TIERS) do
    if tier.se_ingredients and recipes[tier.name] then
      local all_exist = true
      for _, ingredient in ipairs(tier.se_ingredients) do
        if not items[ingredient.name] then
          all_exist = false
          break
        end
      end
      if all_exist then
        recipes[tier.name].ingredients = utils.deep_copy(tier.se_ingredients)
      end
    end
  end
end

--- Entry point executed from data-final-fixes.lua when space-exploration is active.
function se_compat.apply()
  if not mods["space-exploration"] then
    return
  end

  if utils.is_startup_enabled(constants.SETTINGS.SE_BLOCK_IN_SPACE, true) then
    apply_space_placement_restrictions()
  end

  if utils.is_startup_enabled(constants.SETTINGS.SE_BALANCING, true) then
    apply_se_technology_balancing()
    apply_se_recipe_overrides()
  end
end

return se_compat
