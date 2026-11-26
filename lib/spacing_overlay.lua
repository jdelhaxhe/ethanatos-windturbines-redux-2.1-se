--- Cursor-held spacing zone overlay rendered on ground for individual players (0 UPS idle).
--- Loading phase: control.

local constants = require("lib.constants")
local S = constants.SETTINGS

---@class PlayerOverlayState
---@field level uint8
---@field surface_index uint32
---@field renders table<uint32, LuaRenderObject[]>

local M = {}

--- Ensures overlay tracking table exists in Factorio 2.1 `storage`.
local function ensure_storage()
  storage.player_overlays = storage.player_overlays or {}
end

--- Safely destroys a pair of fill/border LuaRenderObjects.
---@param render_pair LuaRenderObject[]?
local function destroy_render_pair(render_pair)
  if not render_pair then
    return
  end
  for i = 1, #render_pair do
    local obj = render_pair[i]
    if obj and obj.valid then
      obj.destroy()
    end
  end
end

--- Resolves the held item name from either a real cursor stack or a Factorio 2.1 ghost cursor.
---@param player LuaPlayer
---@return string?
local function get_cursor_item_name(player)
  local stack = player.cursor_stack
  if stack and stack.valid_for_read then
    return stack.name
  end

  local ghost = player.cursor_ghost
  if ghost and ghost.name then
    if type(ghost.name) == "string" then
      return ghost.name
    end
    return ghost.name.name
  end

  return nil
end

--- Returns the turbine tier level (1..3) held by `player` when the overlay setting is enabled.
---@param player LuaPlayer
---@return uint8?
local function get_desired_overlay_level(player)
  if not (player and player.valid and player.connected) then
    return nil
  end

  local player_settings = settings.get_player_settings(player)
  local toggle = player_settings and player_settings[S.SHOW_SPACING_OVERLAY]
  if toggle and not toggle.value then
    return nil
  end

  local item_name = get_cursor_item_name(player)
  if not item_name then
    return nil
  end

  return constants.TURBINE_LEVEL_BY_ITEM[item_name]
end

--- Draws the tile-aligned exclusion rectangle for one existing turbine relative to `held_level`.
---@param player_index uint32
---@param base LuaEntity
---@param turbine_level uint8
---@param held_level uint8
---@param spacings table<uint8, integer>
---@return LuaRenderObject[]
local function draw_turbine_zone(player_index, base, turbine_level, held_level, spacings)
  local pair_spacing = constants.get_pair_spacing(turbine_level, held_level, spacings)
  -- Covers all blocked tile centers `[pos - (D - 1), pos + (D - 1)]` cleanly to exact tile borders.
  local half = pair_spacing - 0.5
  local left_top = { entity = base, offset = { -half, -half } }
  local right_bottom = { entity = base, offset = { half, half } }
  local target_players = { player_index }

  local fill = rendering.draw_rectangle({
    color = constants.OVERLAY_FILL_COLOR,
    filled = true,
    left_top = left_top,
    right_bottom = right_bottom,
    surface = base.surface,
    players = target_players,
    draw_on_ground = true,
  })

  local border = rendering.draw_rectangle({
    color = constants.OVERLAY_BORDER_COLOR,
    width = constants.OVERLAY_BORDER_WIDTH,
    filled = false,
    left_top = left_top,
    right_bottom = right_bottom,
    surface = base.surface,
    players = target_players,
    draw_on_ground = true,
  })

  return { fill, border }
end

--- Destroys all active spacing overlay renders belonging to `player_index`.
---@param player_index uint32
function M.clear_player_overlay(player_index)
  ensure_storage()
  local state = storage.player_overlays[player_index]
  if not state then
    return
  end

  for _, render_pair in pairs(state.renders) do
    destroy_render_pair(render_pair)
  end
  storage.player_overlays[player_index] = nil
end

--- Recomputes and displays the spacing overlay for `player` based on their cursor and surface.
---@param player LuaPlayer?
function M.refresh_player_overlay(player)
  if not (player and player.valid) then
    return
  end

  ensure_storage()
  local player_index = player.index
  local held_level = get_desired_overlay_level(player)
  local surface = player.surface

  if not (held_level and surface and surface.valid) then
    M.clear_player_overlay(player_index)
    return
  end

  local surface_index = surface.index
  local existing = storage.player_overlays[player_index]
  if existing and existing.level == held_level and existing.surface_index == surface_index then
    return
  end

  M.clear_player_overlay(player_index)

  local renders = {}
  local surface_turbines = storage.turbines_by_surface and storage.turbines_by_surface[surface_index]
  if surface_turbines then
    local spacings = constants.get_all_tier_spacings()
    for unit_number in pairs(surface_turbines) do
      local record = storage.turbines and storage.turbines[unit_number]
      if record and record.base and record.base.valid then
        renders[unit_number] = draw_turbine_zone(player_index, record.base, record.level, held_level, spacings)
      end
    end
  end

  storage.player_overlays[player_index] = {
    level = held_level,
    surface_index = surface_index,
    renders = renders,
  }
end

--- Incrementally adds one newly built turbine's exclusion zone to players holding a turbine on its surface.
---@param record TurbineRecord
function M.on_turbine_added(record)
  ensure_storage()
  if next(storage.player_overlays) == nil then
    return
  end
  if not (record and record.base and record.base.valid and record.base.unit_number) then
    return
  end

  local unit_number = record.base.unit_number
  local spacings = nil

  for player_index, state in pairs(storage.player_overlays) do
    if state.surface_index == record.surface_index then
      spacings = spacings or constants.get_all_tier_spacings()
      destroy_render_pair(state.renders[unit_number])
      state.renders[unit_number] = draw_turbine_zone(
        player_index,
        record.base,
        record.level,
        state.level,
        spacings
      )
    end
  end
end

--- Incrementally removes one turbine's exclusion zone from active player overlays.
---@param unit_number uint32
---@param surface_index uint32
function M.on_turbine_removed(unit_number, surface_index)
  ensure_storage()
  if next(storage.player_overlays) == nil then
    return
  end

  for _, state in pairs(storage.player_overlays) do
    if state.surface_index == surface_index and state.renders[unit_number] then
      destroy_render_pair(state.renders[unit_number])
      state.renders[unit_number] = nil
    end
  end
end

--- Clears overlays attached to a deleted or cleared surface.
---@param surface_index uint32
function M.on_surface_invalidated(surface_index)
  ensure_storage()
  local affected_players = nil

  for player_index, state in pairs(storage.player_overlays) do
    if state.surface_index == surface_index then
      affected_players = affected_players or {}
      affected_players[#affected_players + 1] = player_index
    end
  end

  if affected_players then
    for i = 1, #affected_players do
      M.clear_player_overlay(affected_players[i])
    end
  end
end

--- Rebuilds overlays for all connected players (used after `on_configuration_changed`).
function M.refresh_all_players()
  ensure_storage()
  local stale_players = {}
  for player_index in pairs(storage.player_overlays) do
    stale_players[#stale_players + 1] = player_index
  end
  for i = 1, #stale_players do
    M.clear_player_overlay(stale_players[i])
  end

  for _, player in pairs(game.connected_players) do
    if player.valid then
      M.refresh_player_overlay(player)
    end
  end
end

--- Handles player cursor or surface change events.
---@param event EventData.on_player_cursor_stack_changed|EventData.on_player_changed_surface
function M.on_player_state_changed(event)
  local player = game.get_player(event.player_index)
  if player and player.valid then
    M.refresh_player_overlay(player)
  end
end

--- Handles player disconnect or removal events.
---@param event EventData.on_player_left_game|EventData.on_player_removed
function M.on_player_left(event)
  M.clear_player_overlay(event.player_index)
end

--- Handles live changes to the per-user `wt-show-spacing-overlay` setting.
---@param player_index uint32?
---@param setting_name string
function M.on_player_setting_changed(player_index, setting_name)
  if setting_name ~= S.SHOW_SPACING_OVERLAY or not player_index then
    return
  end
  local player = game.get_player(player_index)
  if player and player.valid then
    M.refresh_player_overlay(player)
  end
end

return M