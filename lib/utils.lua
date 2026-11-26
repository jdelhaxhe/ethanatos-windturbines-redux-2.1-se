--- Shared helper utilities for prototype manipulation and Space Exploration compatibility.
--- Loading phase: data, data-updates, data-final-fixes.

local utils = {}

--- Creates a deep copy of a Lua table or primitive value so prototype tables
--- never share mutable references with shared configuration constants.
---@generic T
---@param value T
---@return T
function utils.deep_copy(value)
  if type(value) ~= "table" then
    return value
  end
  local copy = {}
  for k, v in pairs(value) do
    copy[utils.deep_copy(k)] = utils.deep_copy(v)
  end
  return copy
end

--- Checks whether a science pack prototype exists in `data.raw`.
--- Factorio 2.1 migrated vanilla science packs from `type = "tool"` (`data.raw.tool`)
--- to `type = "item"` (`data.raw.item`), while some modded packs may still use `tool`.
---@param pack_name string
---@return boolean
function utils.science_pack_exists(pack_name)
  if not (data and data.raw and pack_name) then
    return false
  end
  if data.raw.item and data.raw.item[pack_name] then
    return true
  end
  if data.raw.tool and data.raw.tool[pack_name] then
    return true
  end
  return false
end

--- Safely reads a boolean startup setting with a fallback default.
---@param setting_name string
---@param default_value boolean
---@return boolean
function utils.is_startup_enabled(setting_name, default_value)
  if settings and settings.startup and settings.startup[setting_name] then
    return settings.startup[setting_name].value == true
  end
  return default_value
end

--- Ensures a prototype has a Factorio 2.1 dictionary-format collision mask.
---@param prototype table
---@return table
function utils.ensure_collision_mask(prototype)
  if type(prototype.collision_mask) ~= "table" then
    prototype.collision_mask = { layers = {} }
  elseif type(prototype.collision_mask.layers) ~= "table" then
    prototype.collision_mask.layers = {}
  end
  return prototype.collision_mask
end

--- Adds a collision layer flag to a prototype's 2.1 collision mask.
---@param prototype table
---@param layer_name string
function utils.add_collision_layer(prototype, layer_name)
  if not prototype or not layer_name then
    return
  end
  local mask = utils.ensure_collision_mask(prototype)
  mask.layers[layer_name] = true
end

--- Appends or updates a custom tooltip field by key without duplicating entries.
---@param prototype table
---@param tooltip_field table
function utils.add_custom_tooltip_field(prototype, tooltip_field)
  if not prototype or not tooltip_field or not tooltip_field.key then
    return
  end
  prototype.custom_tooltip_fields = prototype.custom_tooltip_fields or {}
  for index, existing in ipairs(prototype.custom_tooltip_fields) do
    if existing.key == tooltip_field.key then
      prototype.custom_tooltip_fields[index] = tooltip_field
      return
    end
  end
  table.insert(prototype.custom_tooltip_fields, tooltip_field)
end

--- Adds Space Exploration's standard "Cannot be placed on: Space platform, Spaceship"
--- tooltip without requiring SE's internal data_util module.
---@param prototype table
function utils.add_se_space_restriction_tooltip(prototype)
  if not prototype then
    return
  end
  local disallowed = {
    "space-exploration.comma_separate",
    { "space-exploration.collision_mask_space_platform" },
    { "space-exploration.collision_mask_spaceship" },
  }
  utils.add_custom_tooltip_field(prototype, {
    key = "cannot-be-placed-on",
    name = "",
    value = { "space-exploration.cannot_be_placed_on_line", disallowed },
    order = 0,
  })
end

--- Applies prerequisites and research unit costs to an existing technology prototype,
--- filtering out any prerequisite that does not exist in data.raw.technology.
---@param tech_name string
---@param tech_spec TurbineTechSpec
function utils.apply_technology_spec(tech_name, tech_spec)
  if not (data.raw.technology and data.raw.technology[tech_name]) then
    return
  end

  local tech = data.raw.technology[tech_name]
  local valid_prerequisites = {}
  for _, prereq in ipairs(tech_spec.prerequisites) do
    if data.raw.technology[prereq] then
      table.insert(valid_prerequisites, prereq)
    end
  end

  local valid_ingredients = {}
  for _, ingredient in ipairs(tech_spec.ingredients) do
    local pack_name = ingredient[1]
    if utils.science_pack_exists(pack_name) then
      table.insert(valid_ingredients, { pack_name, ingredient[2] })
    end
  end

  tech.prerequisites = valid_prerequisites
  -- Never wipe an existing technology's science packs to an empty list if validation fails.
  local final_ingredients = #valid_ingredients > 0
    and valid_ingredients
    or (tech.unit and utils.deep_copy(tech.unit.ingredients) or {})
  tech.unit = {
    count = tech_spec.count,
    time = tech_spec.time,
    ingredients = final_ingredients,
  }
end

--- Checks whether a recipe produces at least one item in `target_items`.
---@param recipe table
---@param target_items table<string, boolean>
---@return boolean
local function recipe_produces_any(recipe, target_items)
  if type(recipe.results) ~= "table" then
    return false
  end
  for _, result in ipairs(recipe.results) do
    local result_name = result.name or result[1]
    if result_name and target_items[result_name] then
      return true
    end
  end
  return false
end

--- Finds solar panel item names and the highest `order` string in `target_subgroup`.
---@param items table<string, table>
---@param target_subgroup string
---@param default_order string
---@return table<string, boolean>, string
local function collect_solar_panel_items(items, target_subgroup, default_order)
  local solar_entities = data.raw["solar-panel"] or {}
  local solar_item_names = { ["solar-panel"] = true }
  local last_order = default_order

  for item_name, item in pairs(items) do
    if not item.hidden and (item.subgroup or "other") == target_subgroup then
      if item_name == "solar-panel" or (item.place_result and solar_entities[item.place_result]) then
        solar_item_names[item_name] = true
        local order = item.order or ""
        if order > last_order then
          last_order = order
        end
      end
    end
  end

  return solar_item_names, last_order
end

--- Resolves the crafting subgroup and highest `order` among solar panel recipes.
---@param recipes table<string, table>
---@param solar_item_names table<string, boolean>
---@param item_subgroup string
---@param last_item_order string
---@return string, string
local function resolve_last_solar_recipe_order(recipes, solar_item_names, item_subgroup, last_item_order)
  local solar_recipe = recipes["solar-panel"]
  local target_subgroup = (solar_recipe and solar_recipe.subgroup) or item_subgroup
  local last_order = (solar_recipe and solar_recipe.order) or last_item_order

  for recipe_name, recipe in pairs(recipes) do
    if not recipe.hidden and (recipe_name == "solar-panel" or recipe_produces_any(recipe, solar_item_names)) then
      local effective_subgroup = recipe.subgroup or item_subgroup
      if effective_subgroup == target_subgroup then
        local effective_order = recipe.order or last_item_order
        if effective_order > last_order then
          last_order = effective_order
        end
      end
    end
  end

  return target_subgroup, last_order
end

--- Places wind turbine items and recipes immediately to the right of solar panels
--- in the crafting/item UI, even when overhaul mods reorder or regroup solar panels.
---@param tiers TurbineTierSpec[]
function utils.align_turbines_after_solar_panels(tiers)
  local items = data.raw and data.raw.item
  if not items then
    return
  end

  local solar_item = items["solar-panel"]
  local target_item_subgroup = (solar_item and solar_item.subgroup) or "energy"
  local fallback_order = (solar_item and solar_item.order) or "d[solar-panel]-a[solar-panel]"

  local solar_item_names, last_item_order = collect_solar_panel_items(
    items,
    target_item_subgroup,
    fallback_order
  )

  local recipes = data.raw.recipe or {}
  local target_recipe_subgroup, last_recipe_order = resolve_last_solar_recipe_order(
    recipes,
    solar_item_names,
    target_item_subgroup,
    last_item_order
  )

  for _, tier in ipairs(tiers) do
    local tier_item = items[tier.name]
    if tier_item then
      tier_item.subgroup = target_item_subgroup
      tier_item.order = last_item_order .. "-z[wind-turbine]-" .. tier.level
    end

    local tier_recipe = recipes[tier.name]
    if tier_recipe then
      tier_recipe.subgroup = target_recipe_subgroup
      tier_recipe.order = last_recipe_order .. "-z[wind-turbine]-" .. tier.level
    end
  end
end

return utils
