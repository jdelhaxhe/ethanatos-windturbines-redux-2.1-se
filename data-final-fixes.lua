--- Final data-stage overrides for Space Exploration compatibility and UI ordering.
--- Loading phase: data-final-fixes.

local constants = require("lib.constants")
local utils = require("lib.utils")

if mods["space-exploration"] then
  local se_compat = require("prototypes.se_compat")
  se_compat.apply()
end

-- Run after all mods (base, AAI Industry, SE) so wind turbine icons always sit right of solar panels.
utils.align_turbines_after_solar_panels(constants.TIERS)
