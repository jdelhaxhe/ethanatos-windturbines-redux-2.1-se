--- Custom Factorio 2.1 collision layer for inter-turbine spacing.
--- Loading phase: data.

local constants = require("lib.constants")

data:extend({
  {
    type = "collision-layer",
    name = constants.SPACING_COLLISION_LAYER,
  },
})
