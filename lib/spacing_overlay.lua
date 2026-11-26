--- Cursor-held spacing zone overlay rendered as a uniform disjoint union on ground (0 UPS idle).
--- Loading phase: control.

local constants = require("lib.constants")
local S = constants.SETTINGS

local GEOM_EPS = 1e-6

---@class OverlayRect
---@field x1 double
---@field y1 double
---@field x2 double
---@field y2 double

---@class OverlaySegment
---@field x1 double
---@field y1 double
---@field x2 double
---@field y2 double

---@class PlayerOverlayState
---@field level uint8
---@field surface_index uint32
---@field renders LuaRenderObject[]

local M = {}

--- Ensures overlay tracking table exists in Factorio 2.1 `storage`.
local function ensure_storage()
  storage.player_overlays = storage.player_overlays or {}
end

--- Safely destroys either a single LuaRenderObject or a legacy nested array of render objects.
---@param entry any
local function destroy_render_entry(entry)
  if not entry then
    return
  end
  if type(entry) == "table" and entry.valid == nil then
    for i = 1, #entry do
      local obj = entry[i]
      if obj and obj.valid then
        obj.destroy()
      end
    end
  elseif entry.valid then
    entry.destroy()
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

--- Returns sorted unique numeric values deduplicated within `GEOM_EPS`.
---@param values double[]
---@return double[]
local function sort_unique(values)
  table.sort(values)
  local unique = {}
  for i = 1, #values do
    local v = values[i]
    if #unique == 0 or (v - unique[#unique]) > GEOM_EPS then
      unique[#unique + 1] = v
    end
  end
  return unique
end

--- Merges overlapping or touching 1D intervals `[x1, x2]` into strictly disjoint spans.
---@param intervals table[]
---@return table[]
local function merge_intervals(intervals)
  if #intervals <= 1 then
    return intervals
  end

  table.sort(intervals, function(a, b)
    if math.abs(a[1] - b[1]) > GEOM_EPS then
      return a[1] < b[1]
    end
    return a[2] < b[2]
  end)

  local merged = { { intervals[1][1], intervals[1][2] } }
  for i = 2, #intervals do
    local cur = merged[#merged]
    local nxt = intervals[i]
    if nxt[1] <= cur[2] + GEOM_EPS then
      if nxt[2] > cur[2] then
        cur[2] = nxt[2]
      end
    else
      merged[#merged + 1] = { nxt[1], nxt[2] }
    end
  end

  return merged
end

--- Checks whether point `x` lies inside any sorted disjoint interval.
---@param intervals table[]
---@param x double
---@return boolean
local function intervals_contain(intervals, x)
  for i = 1, #intervals do
    local span = intervals[i]
    if x >= span[1] - GEOM_EPS and x <= span[2] + GEOM_EPS then
      return true
    end
    if span[1] > x + GEOM_EPS then
      return false
    end
  end
  return false
end

--- Emits merged horizontal outer-contour segments along `y` where coverage flips (`above XOR below`).
---@param y double
---@param above table[]
---@param below table[]
---@param edges OverlaySegment[]
local function append_horizontal_edges(y, above, below, edges)
  local xs = {}
  for i = 1, #above do
    xs[#xs + 1] = above[i][1]
    xs[#xs + 1] = above[i][2]
  end
  for i = 1, #below do
    xs[#xs + 1] = below[i][1]
    xs[#xs + 1] = below[i][2]
  end
  xs = sort_unique(xs)

  local seg_start = nil
  for i = 1, #xs - 1 do
    local mid = (xs[i] + xs[i + 1]) * 0.5
    local is_boundary = (intervals_contain(above, mid) ~= intervals_contain(below, mid))
    if is_boundary then
      seg_start = seg_start or xs[i]
    elseif seg_start then
      edges[#edges + 1] = { x1 = seg_start, y1 = y, x2 = xs[i], y2 = y }
      seg_start = nil
    end
  end
  if seg_start then
    edges[#edges + 1] = { x1 = seg_start, y1 = y, x2 = xs[#xs], y2 = y }
  end
end

--- Quantizes a world coordinate into a stable integer key for strip-to-strip merging.
---@param value double
---@return integer
local function coord_key(value)
  return math.floor(value * 1000 + 0.5)
end

--- Collects raw exclusion rectangles for all valid turbines on `surface_index` relative to `held_level`.
---@param surface_index uint32
---@param held_level uint8
---@return OverlayRect[]
local function collect_surface_rects(surface_index, held_level)
  local surface_turbines = storage.turbines_by_surface and storage.turbines_by_surface[surface_index]
  if not surface_turbines then
    return {}
  end

  local spacings = constants.get_all_tier_spacings()
  local rects = {}

  for unit_number in pairs(surface_turbines) do
    local record = storage.turbines and storage.turbines[unit_number]
    if record and record.base and record.base.valid then
      local pair_spacing = constants.get_pair_spacing(record.level, held_level, spacings)
      -- Subtract 1.5 tiles (the 3x3 pillar half-width) so valid placements sit cleanly outside the highlight.
      local half = math.max(0.5, pair_spacing - 1.5)
      local pos = record.base.position
      rects[#rects + 1] = {
        x1 = pos.x - half,
        y1 = pos.y - half,
        x2 = pos.x + half,
        y2 = pos.y + half,
      }
    end
  end

  return rects
end

--- Flushes all remaining open geometry records from `active_map` into `output`.
---@param active_map table<string|integer, table>
---@param output table[]
local function flush_active_map(active_map, output)
  for _, entry in pairs(active_map) do
    output[#output + 1] = entry
  end
end

--- Advances open fill rects and vertical outer edges across one strip `[y_top, y_bot]`.
---@param spans table[]
---@param y_top double
---@param y_bot double
---@param active_rects table<string, OverlayRect>
---@param active_v_edges table<integer, OverlaySegment>
---@param fill_rects OverlayRect[]
---@param edges OverlaySegment[]
---@return table<string, OverlayRect>, table<integer, OverlaySegment>
local function advance_strip(spans, y_top, y_bot, active_rects, active_v_edges, fill_rects, edges)
  local next_rects = {}
  local next_v_edges = {}

  for i = 1, #spans do
    local x1, x2 = spans[i][1], spans[i][2]
    local rkey = coord_key(x1) .. ":" .. coord_key(x2)
    local prev_rect = active_rects[rkey]
    if prev_rect then
      prev_rect.y2 = y_bot
      next_rects[rkey] = prev_rect
      active_rects[rkey] = nil
    else
      next_rects[rkey] = { x1 = x1, y1 = y_top, x2 = x2, y2 = y_bot }
    end

    for _, bx in ipairs({ x1, x2 }) do
      local vkey = coord_key(bx)
      local prev_edge = active_v_edges[vkey]
      if prev_edge then
        prev_edge.y2 = y_bot
        next_v_edges[vkey] = prev_edge
        active_v_edges[vkey] = nil
      else
        next_v_edges[vkey] = { x1 = bx, y1 = y_top, x2 = bx, y2 = y_bot }
      end
    end
  end

  flush_active_map(active_rects, fill_rects)
  flush_active_map(active_v_edges, edges)
  return next_rects, next_v_edges
end

--- Sweeps horizontal strips across `rects` to compute disjoint merged fill rects and outer contour lines.
---@param rects OverlayRect[]
---@return OverlayRect[], OverlaySegment[]
local function build_union_geometry(rects)
  if #rects == 0 then
    return {}, {}
  end

  -- 1. Partition vertical space into elementary horizontal strips between unique y boundaries.
  local ys = {}
  for i = 1, #rects do
    ys[#ys + 1] = rects[i].y1
    ys[#ys + 1] = rects[i].y2
  end
  ys = sort_unique(ys)

  local strip_intervals = {}
  local fill_rects = {}
  local edges = {}
  local active_rects = {}
  local active_v_edges = {}

  -- 2. Merge covered x-spans per strip and extend matching fill rects and vertical edges downward.
  for s = 1, #ys - 1 do
    local y_top, y_bot = ys[s], ys[s + 1]
    local raw_spans = {}
    for i = 1, #rects do
      local r = rects[i]
      if r.y1 <= y_top + GEOM_EPS and r.y2 >= y_bot - GEOM_EPS then
        raw_spans[#raw_spans + 1] = { r.x1, r.x2 }
      end
    end

    local spans = merge_intervals(raw_spans)
    strip_intervals[s] = spans
    active_rects, active_v_edges = advance_strip(
      spans, y_top, y_bot, active_rects, active_v_edges, fill_rects, edges
    )
  end

  flush_active_map(active_rects, fill_rects)
  flush_active_map(active_v_edges, edges)

  -- 3. Emit horizontal outer-contour edges along every strip boundary (internal overlaps cancel out).
  local empty = {}
  for k = 1, #ys do
    append_horizontal_edges(ys[k], strip_intervals[k - 1] or empty, strip_intervals[k] or empty, edges)
  end

  return fill_rects, edges
end

--- Renders disjoint fill rectangles and outer-contour lines on `surface` for `player_index`.
---@param player_index uint32
---@param surface LuaSurface
---@param fill_rects OverlayRect[]
---@param edges OverlaySegment[]
---@return LuaRenderObject[]
local function draw_union_overlay(player_index, surface, fill_rects, edges)
  local renders = {}
  local target_players = { player_index }

  for i = 1, #fill_rects do
    local r = fill_rects[i]
    renders[#renders + 1] = rendering.draw_rectangle({
      color = constants.OVERLAY_FILL_COLOR,
      filled = true,
      left_top = { r.x1, r.y1 },
      right_bottom = { r.x2, r.y2 },
      surface = surface,
      players = target_players,
      draw_on_ground = true,
    })
  end

  for i = 1, #edges do
    local e = edges[i]
    renders[#renders + 1] = rendering.draw_line({
      color = constants.OVERLAY_BORDER_COLOR,
      width = constants.OVERLAY_BORDER_WIDTH,
      from = { e.x1, e.y1 },
      to = { e.x2, e.y2 },
      surface = surface,
      players = target_players,
      draw_on_ground = true,
    })
  end

  return renders
end

--- Destroys all active spacing overlay renders belonging to `player_index`.
---@param player_index uint32
function M.clear_player_overlay(player_index)
  ensure_storage()
  local state = storage.player_overlays[player_index]
  if not state then
    return
  end

  for _, entry in pairs(state.renders) do
    destroy_render_entry(entry)
  end
  storage.player_overlays[player_index] = nil
end

--- Recomputes and displays the uniform union spacing overlay for `player`.
---@param player LuaPlayer?
---@param force boolean?
function M.refresh_player_overlay(player, force)
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
  if not force and existing and existing.level == held_level and existing.surface_index == surface_index then
    return
  end

  M.clear_player_overlay(player_index)

  local rects = collect_surface_rects(surface_index, held_level)
  local fill_rects, edges = build_union_geometry(rects)
  local renders = draw_union_overlay(player_index, surface, fill_rects, edges)

  storage.player_overlays[player_index] = {
    level = held_level,
    surface_index = surface_index,
    renders = renders,
  }
end

--- Rebuilds overlays for any players currently holding a wind turbine on `surface_index`.
---@param surface_index uint32
local function rebuild_surface_overlays(surface_index)
  ensure_storage()
  if next(storage.player_overlays) == nil then
    return
  end

  local affected_players = nil
  for player_index, state in pairs(storage.player_overlays) do
    if state.surface_index == surface_index then
      affected_players = affected_players or {}
      affected_players[#affected_players + 1] = player_index
    end
  end

  if not affected_players then
    return
  end

  for i = 1, #affected_players do
    local player = game.get_player(affected_players[i])
    if player and player.valid then
      M.refresh_player_overlay(player, true)
    else
      M.clear_player_overlay(affected_players[i])
    end
  end
end

--- Refreshes active overlays on the turbine's surface when a new turbine is added.
---@param record TurbineRecord
function M.on_turbine_added(record)
  if record and record.surface_index then
    rebuild_surface_overlays(record.surface_index)
  end
end

--- Refreshes active overlays on the turbine's surface when a turbine is removed.
---@param _unit_number uint32
---@param surface_index uint32
function M.on_turbine_removed(_unit_number, surface_index)
  if surface_index then
    rebuild_surface_overlays(surface_index)
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
      M.refresh_player_overlay(player, true)
    end
  end
end

--- Handles player cursor or surface change events.
---@param event EventData.on_player_cursor_stack_changed|EventData.on_player_changed_surface|EventData.on_player_joined_game
function M.on_player_state_changed(event)
  local player = game.get_player(event.player_index)
  if player and player.valid then
    M.refresh_player_overlay(player, false)
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
    M.refresh_player_overlay(player, true)
  end
end

return M