--- Final data-stage overrides for Space Exploration compatibility.
--- Loading phase: data-final-fixes.

if mods["space-exploration"] then
  local se_compat = require("prototypes.se_compat")
  se_compat.apply()
end
