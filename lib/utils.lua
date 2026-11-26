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

return utils
