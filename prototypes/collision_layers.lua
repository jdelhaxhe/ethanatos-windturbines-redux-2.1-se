--- Custom Factorio 2.1 per-tier collision layers for symmetric inter-turbine spacing.
--- Loading phase: data.

local constants = require("lib.constants")

local layers = {}
for _, tier in ipairs(constants.TIERS) do
  table.insert(layers, {
    type = "collision-layer",
    name = tier.spacing_layer,
  })
end

data:extend(layers)
