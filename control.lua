--- Control stage entry point: event filter wiring and dynamic `on_nth_tick` registration.
--- Loading phase: control.

local constants = require("lib.constants")
local spacing_overlay = require("lib.spacing_overlay")
local turbine_manager = require("lib.turbine_manager")

local S = constants.SETTINGS
local WIND_VARIATION_INTERVAL = constants.WIND_VARIATION_INTERVAL

--- Builds Factorio 2.1 engine-level entity event filters for build and removal events.
---@return LuaEntityEventFilter[], LuaEntityEventFilter[]
local function build_entity_filters()
  local build_filters = {}
  local removal_filters = {}

  for _, tier in ipairs(constants.TIERS) do
    build_filters[#build_filters + 1] = { filter = "name", name = tier.build_name }
    build_filters[#build_filters + 1] = { filter = "name", name = tier.name }
    removal_filters[#removal_filters + 1] = { filter = "name", name = tier.name }
  end

  return build_filters, removal_filters
end

--- Dynamically registers `on_nth_tick` handlers using `wt-update-interval` and wind variation settings.
--- Called identically in `on_init`, `on_load`, `on_configuration_changed`, and setting updates for MP determinism.
local function register_tick_handlers()
  -- Clear existing nth-tick handlers first so changing intervals never leaves stale timers behind.
  script.on_nth_tick(nil)

  local update_interval = settings.global[S.UPDATE_INTERVAL].value
  local vary_enabled = turbine_manager.should_vary_wind_speed()

  if vary_enabled and update_interval == WIND_VARIATION_INTERVAL then
    -- Factorio allows only one handler per tick cadence; combine both when intervals coincide.
    script.on_nth_tick(update_interval, function()
      turbine_manager.vary_wind_speed()
      turbine_manager.update_turbines()
    end)
    return
  end

  if vary_enabled then
    script.on_nth_tick(WIND_VARIATION_INTERVAL, turbine_manager.vary_wind_speed)
  end

  script.on_nth_tick(update_interval, turbine_manager.update_turbines)
end

local build_filters, removal_filters = build_entity_filters()

-- Lifecycle hooks
script.on_init(function()
  turbine_manager.on_init()
  register_tick_handlers()
end)

script.on_load(function()
  register_tick_handlers()
end)

script.on_configuration_changed(function()
  turbine_manager.on_configuration_changed()
  register_tick_handlers()
end)

-- Filtered build & revive events
script.on_event(defines.events.on_built_entity, turbine_manager.on_entity_built, build_filters)
script.on_event(defines.events.on_robot_built_entity, turbine_manager.on_entity_built, build_filters)
script.on_event(defines.events.script_raised_built, turbine_manager.on_entity_built, build_filters)
script.on_event(defines.events.script_raised_revive, turbine_manager.on_entity_built, build_filters)

-- `on_entity_cloned` does not accept entity filters in Factorio 2.1; guarded in O(1) inside handler.
script.on_event(defines.events.on_entity_cloned, turbine_manager.on_entity_cloned)

-- Filtered removal events
script.on_event(defines.events.on_player_mined_entity, turbine_manager.on_entity_removed, removal_filters)
script.on_event(defines.events.on_robot_mined_entity, turbine_manager.on_entity_removed, removal_filters)
script.on_event(defines.events.on_entity_died, turbine_manager.on_entity_removed, removal_filters)
script.on_event(defines.events.script_raised_destroy, turbine_manager.on_entity_removed, removal_filters)

-- Surface cleanup events
script.on_event(defines.events.on_surface_deleted, turbine_manager.on_surface_invalidated)
script.on_event(defines.events.on_surface_cleared, turbine_manager.on_surface_invalidated)

-- Player cursor spacing overlay events (0 UPS when no turbine is held)
script.on_event(defines.events.on_player_cursor_stack_changed, spacing_overlay.on_player_state_changed)
script.on_event(defines.events.on_player_changed_surface, spacing_overlay.on_player_state_changed)
script.on_event(defines.events.on_player_joined_game, spacing_overlay.on_player_state_changed)
script.on_event(defines.events.on_player_left_game, spacing_overlay.on_player_left)
script.on_event(defines.events.on_player_removed, spacing_overlay.on_player_left)

-- Live runtime setting synchronization
script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  spacing_overlay.on_player_setting_changed(event.player_index, event.setting)
  if turbine_manager.on_runtime_mod_setting_changed(event) then
    register_tick_handlers()
  end
end)
