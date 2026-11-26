--- Runtime turbine lifecycle, multi-surface wind caching, and power/animation scaling.
--- Loading phase: control.

local constants = require("lib.constants")
local S = constants.SETTINGS

local ROTATION_COUNT = constants.ROTATION_COUNT
local FRAME_COUNT = constants.FRAME_COUNT
local DEFAULT_ORIENTATION = constants.DEFAULT_ORIENTATION
local BASE_ANIMATION_SPEED = constants.BASE_ANIMATION_SPEED
local MAX_ANIMATION_SPEED = constants.MAX_ANIMATION_SPEED
local WIND_EPSILON = constants.WIND_EPSILON

---@class TurbineRecord
---@field base LuaEntity
---@field collision_box LuaEntity?
---@field surface_index uint32
---@field level uint8
---@field orientation uint8
---@field turbine_render LuaRenderObject?
---@field shadow_render LuaRenderObject?
---@field last_speed double
---@field last_offset double

---@class SurfaceWindCache
---@field orientation uint8
---@field effective_wind double
---@field wind_ratio double
---@field power_multiplier double
---@field anim_speed double
---@field settings_version uint32

---@class RuntimeConfig
---@field power_watts table<uint8, double>
---@field locked_power boolean
---@field max_wind_multiplier double
---@field reference_wind_speed double
---@field low_vram boolean
---@field se_block_in_space boolean
---@field settings_version uint32

---@type table<uint8, TurbineTierSpec>
local TIER_BY_LEVEL = {}
---@type table<string, uint8>
local BUILD_LEVEL_BY_NAME = {}
---@type table<string, uint8>
local ACTIVE_LEVEL_BY_NAME = {}
---@type table<string, boolean>
local COLLISION_BOX_NAMES = {}
---@type string[]
local ACTIVE_TURBINE_NAMES = {}
---@type string[]
local BUILD_TURBINE_NAMES = {}
---@type string[]
local COLLISION_BOX_NAME_LIST = {}

for _, tier in ipairs(constants.TIERS) do
  TIER_BY_LEVEL[tier.level] = tier
  BUILD_LEVEL_BY_NAME[tier.build_name] = tier.level
  ACTIVE_LEVEL_BY_NAME[tier.name] = tier.level
  COLLISION_BOX_NAMES[tier.collision_box_name] = true
  ACTIVE_TURBINE_NAMES[#ACTIVE_TURBINE_NAMES + 1] = tier.name
  BUILD_TURBINE_NAMES[#BUILD_TURBINE_NAMES + 1] = tier.build_name
  COLLISION_BOX_NAME_LIST[#COLLISION_BOX_NAME_LIST + 1] = tier.collision_box_name
end

---@type table<string, boolean>
local POWER_OR_WIND_SETTINGS = {
  [S.POWER_MK1] = true,
  [S.POWER_MK2] = true,
  [S.POWER_MK3] = true,
  [S.LOCKED_POWER] = true,
  [S.REFERENCE_WIND_SPEED] = true,
  [S.AUTO_CALIBRATE_WSC] = true,
  [S.MAX_WIND_MULTIPLIER] = true,
  ["wsc-min-wind-speed"] = true,
  ["wsc-max-wind-speed"] = true,
}

---@type table<string, boolean>
local TICK_SCHEDULE_SETTINGS = {
  [S.UPDATE_INTERVAL] = true,
  [S.VARY_WINDSPEED] = true,
}

local M = {}

--- Ensures all persistent Factorio 2.1 `storage` tables exist.
local function ensure_storage()
  storage.turbines = storage.turbines or {}
  storage.turbines_by_surface = storage.turbines_by_surface or {}
  storage.surface_wind = storage.surface_wind or {}
  storage.surface_is_solid = storage.surface_is_solid or {}
  storage.settings_version = storage.settings_version or 1
end

--- Checks whether an external wind-changing mod is installed.
---@return boolean
local function is_external_wind_mod_active()
  return script.active_mods["WindSpeedChanging"] ~= nil
    or script.active_mods["WindSpeedChanging-Tweaked"] ~= nil
end

--- Resolves the reference wind speed corresponding to 100% nominal turbine output.
---@return double
local function get_reference_wind_speed()
  if script.active_mods["WindSpeedChanging"] and settings.global[S.AUTO_CALIBRATE_WSC].value then
    local wsc_min = settings.global["wsc-min-wind-speed"]
    local wsc_max = settings.global["wsc-max-wind-speed"]
    if wsc_min and wsc_max then
      return math.max(0.001, (wsc_min.value + wsc_max.value) / 2)
    end
  end
  return math.max(0.001, settings.global[S.REFERENCE_WIND_SPEED].value)
end

--- Reads the active startup and runtime-global settings needed for wind/power math.
---@return RuntimeConfig
local function read_runtime_config()
  local power_watts = {}
  for _, tier in ipairs(constants.TIERS) do
    power_watts[tier.level] = settings.global[tier.power_setting].value * 1000
  end

  return {
    power_watts = power_watts,
    locked_power = settings.global[S.LOCKED_POWER].value,
    max_wind_multiplier = settings.global[S.MAX_WIND_MULTIPLIER].value,
    reference_wind_speed = get_reference_wind_speed(),
    low_vram = settings.startup[S.LOW_VRAM].value,
    se_block_in_space = settings.startup[S.SE_BLOCK_IN_SPACE].value,
    settings_version = storage.settings_version or 1,
  }
end

--- Converts surface wind orientation [0, 1) to a discrete sprite index in [0, 31].
---@param wind_orientation double
---@param low_vram boolean
---@return uint8
local function compute_orientation(wind_orientation, low_vram)
  -- Modulo 32 fixes the legacy `% 31` discontinuity where sprite index 31 was unreachable.
  local orientation = (math.floor(wind_orientation * ROTATION_COUNT + 0.5) + DEFAULT_ORIENTATION) % ROTATION_COUNT
  if low_vram then
    -- Low-VRAM mode only loads the 16 even rotation animations (0, 2, ..., 30).
    orientation = orientation - (orientation % 2)
  end
  return orientation
end

--- Builds the rotor animation prototype name for a tier and discrete orientation.
---@param level uint8
---@param orientation uint8
---@return string
local function rotor_animation_name(level, orientation)
  return "ownly_wind_turbine_mk" .. level .. "_" .. orientation
end

--- Builds the shadow animation prototype name for a discrete orientation.
---@param orientation uint8
---@return string
local function shadow_animation_name(orientation)
  return "ownly_wind_turbine_shadow_" .. orientation
end

--- Determines whether a surface is a solid planetary/lunar surface under SE rules.
--- Result is cached per surface and invalidated on surface deletion/clearing or config changes.
---@param surface_index uint32
---@param se_block_in_space boolean
---@return boolean
local function is_surface_solid(surface_index, se_block_in_space)
  if not se_block_in_space then
    return true
  end

  local cached = storage.surface_is_solid[surface_index]
  if cached ~= nil then
    return cached
  end

  local se_interface = remote.interfaces["space-exploration"]
  if not (se_interface and se_interface["get_surface_type"]) then
    storage.surface_is_solid[surface_index] = true
    return true
  end

  local surface_type = remote.call("space-exploration", "get_surface_type", {
    surface_index = surface_index,
  })
  local is_solid = (surface_type == "planet" or surface_type == "moon")
  storage.surface_is_solid[surface_index] = is_solid
  return is_solid
end

--- Computes normalized wind, power multiplier, and rotor animation speed for a surface.
---@param surface LuaSurface
---@param config RuntimeConfig
---@return SurfaceWindCache
local function compute_surface_wind_state(surface, config)
  local is_solid = is_surface_solid(surface.index, config.se_block_in_space)
  local effective_wind = is_solid and math.max(0, surface.wind_speed) or 0
  local orientation = compute_orientation(surface.wind_orientation, config.low_vram)
  local wind_ratio = effective_wind / config.reference_wind_speed

  -- Airless and SE non-solid surfaces always force 0 W output and stationary rotors.
  local power_multiplier = 0.0
  local anim_speed = 0.0
  if is_solid and effective_wind > 0 then
    power_multiplier = config.locked_power and 1.0 or math.min(wind_ratio, config.max_wind_multiplier)
    anim_speed = math.min(wind_ratio * BASE_ANIMATION_SPEED, MAX_ANIMATION_SPEED)
  end

  return {
    orientation = orientation,
    effective_wind = effective_wind,
    wind_ratio = wind_ratio,
    power_multiplier = power_multiplier,
    anim_speed = anim_speed,
    settings_version = config.settings_version,
  }
end

--- Safely destroys a Factorio 2.1 LuaRenderObject if it still exists.
---@param render_obj LuaRenderObject?
local function destroy_render(render_obj)
  if render_obj and render_obj.valid then
    render_obj.destroy()
  end
end

--- Creates the hidden 33x33 spacing collision box anchored at the turbine center.
---@param surface LuaSurface
---@param position MapPosition
---@param force ForceID
---@param level uint8
---@return LuaEntity?
local function create_collision_box(surface, position, force, level)
  local tier = TIER_BY_LEVEL[level]
  local box = surface.create_entity({
    name = tier.collision_box_name,
    position = position,
    force = force,
    raise_built = false,
    create_build_effect_smoke = false,
  })
  if box and box.valid then
    box.destructible = false
    -- Factorio 2.0/2.1 made `LuaEntity::minable` read-only; use `minable_flag` for runtime writes.
    box.minable_flag = false
  end
  return box
end

--- Draws entity-bound rotor and shadow LuaRenderObjects for an active turbine.
---@param base LuaEntity
---@param level uint8
---@param orientation uint8
---@param anim_speed double
---@param anim_offset double
---@return LuaRenderObject, LuaRenderObject
local function create_renders(base, level, orientation, anim_speed, anim_offset)
  local turbine_render = rendering.draw_animation({
    animation = rotor_animation_name(level, orientation),
    target = { entity = base, offset = constants.RENDER_TURBINE_OFFSET },
    surface = base.surface,
    animation_speed = anim_speed,
    animation_offset = anim_offset,
    render_layer = "wires-above",
  })

  local shadow_render = rendering.draw_animation({
    animation = shadow_animation_name(orientation),
    target = { entity = base, offset = constants.RENDER_SHADOW_OFFSET },
    surface = base.surface,
    animation_speed = anim_speed,
    animation_offset = anim_offset,
  })

  return turbine_render, shadow_render
end

--- Applies electrical buffer size and per-tick power production to a turbine entity.
---@param record TurbineRecord
---@param wind_state SurfaceWindCache
---@param config RuntimeConfig
local function apply_turbine_power(record, wind_state, config)
  local base = record.base
  local nominal_watts = config.power_watts[record.level]
  local actual_watts = nominal_watts * wind_state.power_multiplier

  -- Expand the electric buffer for gusts above 100% so Factorio never clamps peak output.
  base.electric_buffer_size = math.max(nominal_watts, actual_watts) / 60
  base.power_production = actual_watts / 60
end

--- Ensures a valid turbine record still owns valid collision box and render objects.
---@param record TurbineRecord
---@param wind_state SurfaceWindCache
local function ensure_record_attachments(record, wind_state)
  local base = record.base
  if not (record.collision_box and record.collision_box.valid) then
    record.collision_box = create_collision_box(base.surface, base.position, base.force, record.level)
  end

  local turbine_valid = record.turbine_render and record.turbine_render.valid
  local shadow_valid = record.shadow_render and record.shadow_render.valid
  if not (turbine_valid and shadow_valid) then
    destroy_render(record.turbine_render)
    destroy_render(record.shadow_render)
    local turbine_render, shadow_render = create_renders(
      base,
      record.level,
      wind_state.orientation,
      wind_state.anim_speed,
      record.last_offset
    )
    record.turbine_render = turbine_render
    record.shadow_render = shadow_render
    record.orientation = wind_state.orientation
    record.last_speed = wind_state.anim_speed
  end
end

--- Mutates rotor/shadow render orientation and phase-continuous animation speed.
---@param record TurbineRecord
---@param wind_state SurfaceWindCache
---@param tick uint32
local function apply_turbine_visuals(record, wind_state, tick)
  local turbine_render = record.turbine_render
  local shadow_render = record.shadow_render
  if not (turbine_render and turbine_render.valid and shadow_render and shadow_render.valid) then
    return
  end

  -- 1. Update heading sprites only when the discrete orientation step changed.
  if record.orientation ~= wind_state.orientation then
    turbine_render.animation = rotor_animation_name(record.level, wind_state.orientation)
    shadow_render.animation = shadow_animation_name(wind_state.orientation)
    record.orientation = wind_state.orientation
  end

  -- 2. Update animation speed with a phase-continuous frame offset to prevent blade snapping.
  if math.abs(record.last_speed - wind_state.anim_speed) > WIND_EPSILON then
    local expected_frame = ((tick * record.last_speed) + record.last_offset) % FRAME_COUNT
    local new_frame = (tick * wind_state.anim_speed) % FRAME_COUNT
    local new_offset = (expected_frame - new_frame) % FRAME_COUNT

    turbine_render.animation_speed = wind_state.anim_speed
    turbine_render.animation_offset = new_offset
    shadow_render.animation_speed = wind_state.anim_speed
    shadow_render.animation_offset = new_offset

    record.last_speed = wind_state.anim_speed
    record.last_offset = new_offset
  end
end

--- Removes a turbine record, destroys its renders and collision box, and prunes empty surface maps.
---@param unit_number uint32
local function cleanup_turbine_record(unit_number)
  local record = storage.turbines[unit_number]
  if not record then
    return
  end

  destroy_render(record.turbine_render)
  destroy_render(record.shadow_render)

  if record.collision_box and record.collision_box.valid then
    record.collision_box.destroy({ raise_destroy = false })
  end

  local surface_index = record.surface_index
  local surface_turbines = storage.turbines_by_surface[surface_index]
  if surface_turbines then
    surface_turbines[unit_number] = nil
    if next(surface_turbines) == nil then
      storage.turbines_by_surface[surface_index] = nil
      storage.surface_wind[surface_index] = nil
    end
  end

  storage.turbines[unit_number] = nil
end

--- Registers an active `ownly_wind_turbine_mkN` entity, attaching its box, renders, and power state.
---@param base LuaEntity
---@param level uint8
local function register_active_turbine(base, level)
  if not (base and base.valid and base.unit_number) then
    return
  end

  ensure_storage()
  local unit_number = base.unit_number
  if storage.turbines[unit_number] then
    return
  end

  -- 1. Compute immediate surface wind state so newly built turbines match local wind on tick 0.
  local surface = base.surface
  local surface_index = surface.index
  local config = read_runtime_config()
  local wind_state = compute_surface_wind_state(surface, config)

  -- 2. Create spacing collision box and entity-bound rotor/shadow animations.
  local collision_box = create_collision_box(surface, base.position, base.force, level)
  local turbine_render, shadow_render = create_renders(
    base,
    level,
    wind_state.orientation,
    wind_state.anim_speed,
    0
  )

  ---@type TurbineRecord
  local record = {
    base = base,
    collision_box = collision_box,
    surface_index = surface_index,
    level = level,
    orientation = wind_state.orientation,
    turbine_render = turbine_render,
    shadow_render = shadow_render,
    last_speed = wind_state.anim_speed,
    last_offset = 0,
  }

  -- 3. Index in `storage` and apply initial power/buffer settings.
  storage.turbines[unit_number] = record
  local surface_turbines = storage.turbines_by_surface[surface_index]
  local is_first_on_surface = (surface_turbines == nil)
  if is_first_on_surface then
    surface_turbines = {}
    storage.turbines_by_surface[surface_index] = surface_turbines
  end
  surface_turbines[unit_number] = true

  -- Only seed the cache for the first turbine so pre-existing turbines are never skipped.
  if is_first_on_surface then
    storage.surface_wind[surface_index] = wind_state
  end

  apply_turbine_power(record, wind_state, config)
end

--- Replaces a placed `ownly_wind_turbine_build_mkN` proxy entity with the active turbine tower.
---@param entity LuaEntity
---@param level uint8
local function replace_build_entity(entity, level)
  local tier = TIER_BY_LEVEL[level]
  local surface = entity.surface
  local position = entity.position
  local force = entity.force
  local quality = entity.quality
  local last_user = entity.last_user
  local health_ratio = entity.get_health_ratio()

  entity.destroy({ raise_destroy = false })

  local base = surface.create_entity({
    name = tier.name,
    position = position,
    force = force,
    quality = quality,
    raise_built = false,
    create_build_effect_smoke = false,
  })
  if not (base and base.valid) then
    return
  end

  if last_user and last_user.valid then
    base.last_user = last_user
  end
  if health_ratio and health_ratio < 1 and base.max_health > 0 then
    base.health = math.max(1, base.max_health * health_ratio)
  end

  register_active_turbine(base, level)
end

--- Updates all turbines on one surface if wind or settings changed since the previous poll.
---@param surface LuaSurface
---@param surface_index uint32
---@param surface_turbines table<uint32, boolean>
---@param config RuntimeConfig
---@param tick uint32
local function update_surface_turbines(surface, surface_index, surface_turbines, config, tick)
  -- 1. Compare current wind and settings version against per-surface cache for O(1) skipping.
  local wind_state = compute_surface_wind_state(surface, config)
  local cached = storage.surface_wind[surface_index]
  local settings_changed = (not cached) or (cached.settings_version ~= config.settings_version)
  local orientation_changed = (not cached) or (cached.orientation ~= wind_state.orientation)
  local wind_changed = (not cached) or (math.abs(cached.effective_wind - wind_state.effective_wind) > WIND_EPSILON)

  if not settings_changed and not orientation_changed and not wind_changed then
    return
  end

  storage.surface_wind[surface_index] = wind_state

  -- 2. Batch-update valid turbines on this surface and defer stale cleanup until after iteration.
  local stale_units = nil
  for unit_number in pairs(surface_turbines) do
    local record = storage.turbines[unit_number]
    if not (record and record.base and record.base.valid) then
      stale_units = stale_units or {}
      stale_units[#stale_units + 1] = unit_number
    else
      ensure_record_attachments(record, wind_state)
      apply_turbine_visuals(record, wind_state, tick)
      if wind_changed or settings_changed then
        apply_turbine_power(record, wind_state, config)
      end
    end
  end

  if stale_units then
    for i = 1, #stale_units do
      cleanup_turbine_record(stale_units[i])
    end
  end
end

--- Rebuilds surface index and removes invalid records during configuration reconciliation.
local function reconcile_tracked_records()
  storage.turbines_by_surface = {}

  local stale_units = {}
  for unit_number, record in pairs(storage.turbines) do
    if not (record.base and record.base.valid) then
      stale_units[#stale_units + 1] = unit_number
    else
      local surface_index = record.base.surface.index
      record.surface_index = surface_index
      -- Force orientation re-evaluation in case `wt-low-vram` changed across save load.
      record.orientation = 255

      local surface_turbines = storage.turbines_by_surface[surface_index]
      if not surface_turbines then
        surface_turbines = {}
        storage.turbines_by_surface[surface_index] = surface_turbines
      end
      surface_turbines[unit_number] = true
    end
  end

  for i = 1, #stale_units do
    cleanup_turbine_record(stale_units[i])
  end
end

--- Scans a surface to register untracked turbines and clean up orphaned spacing collision boxes.
---@param surface LuaSurface
local function reconcile_surface_entities(surface)
  -- 1. Convert any lingering build-proxy entities into active turbines.
  local build_entities = surface.find_entities_filtered({ name = BUILD_TURBINE_NAMES })
  for i = 1, #build_entities do
    local entity = build_entities[i]
    if entity.valid then
      local level = BUILD_LEVEL_BY_NAME[entity.name]
      if level then
        replace_build_entity(entity, level)
      end
    end
  end

  -- 2. Register any untracked active turbine towers.
  local active_entities = surface.find_entities_filtered({ name = ACTIVE_TURBINE_NAMES })
  for i = 1, #active_entities do
    local entity = active_entities[i]
    if entity.valid and entity.unit_number and not storage.turbines[entity.unit_number] then
      local level = ACTIVE_LEVEL_BY_NAME[entity.name]
      if level then
        register_active_turbine(entity, level)
      end
    end
  end

  -- 3. Remove orphaned collision boxes not referenced by any tracked turbine on this surface.
  local owned_boxes = {}
  local surface_turbines = storage.turbines_by_surface[surface.index]
  if surface_turbines then
    for unit_number in pairs(surface_turbines) do
      local record = storage.turbines[unit_number]
      if record and record.collision_box and record.collision_box.valid and record.collision_box.unit_number then
        owned_boxes[record.collision_box.unit_number] = true
      end
    end
  end

  local all_boxes = surface.find_entities_filtered({ name = COLLISION_BOX_NAME_LIST })
  for i = 1, #all_boxes do
    local box = all_boxes[i]
    if box.valid and (not box.unit_number or not owned_boxes[box.unit_number]) then
      box.destroy({ raise_destroy = false })
    end
  end
end

--- Initializes mod `storage` tables on new game or first load.
function M.on_init()
  ensure_storage()
end

--- Reconciles persistent state, SE surface caches, and settings after mod/game updates.
function M.on_configuration_changed()
  ensure_storage()

  -- Invalidate caches so SE surface types and startup/runtime settings are re-evaluated cleanly.
  storage.surface_is_solid = {}
  storage.surface_wind = {}
  storage.settings_version = (storage.settings_version or 0) + 1

  reconcile_tracked_records()

  for _, surface in pairs(game.surfaces) do
    if surface.valid then
      reconcile_surface_entities(surface)
    end
  end

  -- Clear wind cache after entity reconciliation so every tracked turbine receives a full sync pass.
  storage.surface_wind = {}
  M.update_turbines()
end

--- Handles built and revived wind turbine entities.
---@param event EventData.on_built_entity|EventData.on_robot_built_entity|EventData.script_raised_built|EventData.script_raised_revive
function M.on_entity_built(event)
  local entity = event.entity
  if not (entity and entity.valid) then
    return
  end

  local build_level = BUILD_LEVEL_BY_NAME[entity.name]
  if build_level then
    replace_build_entity(entity, build_level)
    return
  end

  local active_level = ACTIVE_LEVEL_BY_NAME[entity.name]
  if active_level then
    register_active_turbine(entity, active_level)
  end
end

--- Handles cloned entities (e.g., SE spaceship transitions or area cloning).
---@param event EventData.on_entity_cloned
function M.on_entity_cloned(event)
  local destination = event.destination
  if not (destination and destination.valid) then
    return
  end

  -- Destroy cloned spacing boxes; the cloned turbine creates its own tracked box cleanly.
  if COLLISION_BOX_NAMES[destination.name] then
    destination.destroy({ raise_destroy = false })
    return
  end

  local build_level = BUILD_LEVEL_BY_NAME[destination.name]
  if build_level then
    replace_build_entity(destination, build_level)
    return
  end

  local active_level = ACTIVE_LEVEL_BY_NAME[destination.name]
  if active_level then
    register_active_turbine(destination, active_level)
  end
end

--- Handles mined, killed, or script-destroyed wind turbine entities.
---@param event EventData.on_player_mined_entity|EventData.on_robot_mined_entity|EventData.on_entity_died|EventData.script_raised_destroy
function M.on_entity_removed(event)
  local entity = event.entity
  if not (entity and entity.valid and entity.unit_number) then
    return
  end

  if storage.turbines[entity.unit_number] then
    cleanup_turbine_record(entity.unit_number)
  end
end

--- Cleans up surface caches and tracked turbines when a surface is deleted or cleared.
---@param event EventData.on_surface_deleted|EventData.on_surface_cleared
function M.on_surface_invalidated(event)
  ensure_storage()
  local surface_index = event.surface_index

  local surface_turbines = storage.turbines_by_surface[surface_index]
  if surface_turbines then
    local units = {}
    for unit_number in pairs(surface_turbines) do
      units[#units + 1] = unit_number
    end
    for i = 1, #units do
      cleanup_turbine_record(units[i])
    end
  end

  storage.turbines_by_surface[surface_index] = nil
  storage.surface_wind[surface_index] = nil
  storage.surface_is_solid[surface_index] = nil
end

--- Reacts to runtime-global setting changes (including WindSpeedChanging live calibration).
---@param event EventData.on_runtime_mod_setting_changed
---@return boolean needs_tick_reregister True when `on_nth_tick` handlers must be updated.
function M.on_runtime_mod_setting_changed(event)
  ensure_storage()
  local setting_name = event.setting

  if POWER_OR_WIND_SETTINGS[setting_name] then
    storage.settings_version = (storage.settings_version or 0) + 1
    M.update_turbines()
  end

  return TICK_SCHEDULE_SETTINGS[setting_name] == true
end

--- Returns whether built-in multi-surface wind variation should run.
---@return boolean
function M.should_vary_wind_speed()
  return (not is_external_wind_mod_active()) and settings.global[S.VARY_WINDSPEED].value
end

--- Applies built-in gentle wind speed variation across solid windy surfaces every 5 seconds.
function M.vary_wind_speed()
  if not M.should_vary_wind_speed() then
    return
  end

  ensure_storage()
  local se_block_in_space = settings.startup[S.SE_BLOCK_IN_SPACE].value

  for _, surface in pairs(game.surfaces) do
    if surface.valid and surface.wind_speed > 0 and is_surface_solid(surface.index, se_block_in_space) then
      local wind = surface.wind_speed
      surface.wind_speed = math.max(0.001, (wind - 0.002 + math.random() * 0.004) * 0.975 + 0.00052)
    end
  end
end

--- Polls surfaces with active turbines and updates only surfaces whose wind or settings changed.
function M.update_turbines()
  ensure_storage()

  -- O(1) idle early exit when zero wind turbines exist anywhere in the save.
  if next(storage.turbines_by_surface) == nil then
    return
  end

  local config = read_runtime_config()
  local tick = game.tick
  local invalid_surfaces = nil

  for surface_index, surface_turbines in pairs(storage.turbines_by_surface) do
    local surface = game.get_surface(surface_index)
    if not (surface and surface.valid) then
      invalid_surfaces = invalid_surfaces or {}
      invalid_surfaces[#invalid_surfaces + 1] = surface_index
    else
      update_surface_turbines(surface, surface_index, surface_turbines, config, tick)
    end
  end

  if invalid_surfaces then
    for i = 1, #invalid_surfaces do
      M.on_surface_invalidated({ surface_index = invalid_surfaces[i] })
    end
  end
end

return M
