--- Base wind turbine technology prototypes (SE adjustments run in data-final-fixes).
--- Loading phase: data.

local constants = require("lib.constants")

local technologies = {}
for _, tier in ipairs(constants.TIERS) do
  local tech_spec = tier.vanilla_tech
  table.insert(technologies, {
    type = "technology",
    name = tier.name,
    icon = tier.icon,
    icon_size = 144,
    prerequisites = tech_spec.prerequisites,
    effects = {
      {
        type = "unlock-recipe",
        recipe = tier.name,
      },
    },
    unit = {
      count = tech_spec.count,
      ingredients = tech_spec.ingredients,
      time = tech_spec.time,
    },
  })
end

data:extend(technologies)
