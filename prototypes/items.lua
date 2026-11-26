--- Wind turbine item prototypes for tiers Mk1 through Mk3.
--- Loading phase: data.

local constants = require("lib.constants")

local items = {}
for _, tier in ipairs(constants.TIERS) do
  table.insert(items, {
    type = "item",
    name = tier.name,
    icon = tier.icon,
    icon_size = 144,
    subgroup = "energy",
    order = tier.order,
    place_result = tier.build_name,
    stack_size = 20,
  })
end

data:extend(items)
