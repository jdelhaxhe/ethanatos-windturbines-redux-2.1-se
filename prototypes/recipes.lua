--- Wind turbine recipe prototypes using Factorio 2.1 ingredients/results syntax.
--- Loading phase: data.

local constants = require("lib.constants")
local utils = require("lib.utils")

local recipes = {}
for _, tier in ipairs(constants.TIERS) do
  table.insert(recipes, {
    type = "recipe",
    name = tier.name,
    energy_required = 30,
    enabled = false,
    ingredients = utils.deep_copy(tier.ingredients),
    results = {
      { type = "item", name = tier.name, amount = 1 },
    },
  })
end

data:extend(recipes)
