# Technical and Balancing Specification — `ethanatos-windturbines-redux-2.1-se`

## 1. Technical Context
- **Mod Internal Name:** `ethanatos-windturbines-redux-2.1-se`
- **Game:** Factorio 2.1 (`base >= 2.1.0`, `space-age` and `quality` DLCs disabled).
- **Upstream Lineage:**
  - Original mod: `windturbines` (v0.18.11) by **OwnlyMe**.
  - Configurable power fork: `windturbines-2-configurable-power` by **jdelhaxhe / ethanatos**.
  - Factorio 1.1 redux: `windturbines-redux` (v0.19.03, 18 commits) by **Seth401**.
- **Optional Companion Mods:**
  - *Space Exploration* (`(?) space-exploration >= 0.7.0`, audited against `space-exploration_0.7.64` and `space-exploration-postprocess_0.7.8`).
  - *Wind Speed Changing* (`? WindSpeedChanging >= 2.1.2`, audited against `WindSpeedChanging_2.1.2`).

### Preserved Upstream Improvements (`Seth401/windturbines-redux`)
All functional improvements introduced across `Seth401`'s 18 commits are retained and modernized for Factorio 2.1:
- **Runtime-global power & wind controls:** Moving power locking and base power configuration to `runtime-global` settings so players can rebalance wind output without restarting.
- **Built-in wind variation toggle:** Allowing the mod's internal wind variation to be disabled or automatically yielded whenever `WindSpeedChanging` is active.
- **`WindSpeedChanging` awareness:** Normalizing power output against `WindSpeedChanging`'s higher wind-speed range (extended in 2.1 to also normalize animation speed and auto-calibrate from `WindSpeedChanging`'s live settings).
- **Space Exploration placement restriction:** Blocking wind turbine placement in space and adding SE placement restriction tooltips (upgraded from 1.1 collision arrays to 2.1 dictionary `collision_mask.layers`).
- **Dynamic-friendly localization:** Keeping hardcoded power numbers out of entity/technology titles so UI labels remain accurate regardless of configured power settings.
- **Strict local scoping & clean code hygiene:** Eliminating accidental globals and dead debug prints.

## 2. Philosophy and Guiding Principles (Game Design)
- **UPS-conscious runtime design:** Keep `control.lua` strictly minimal, surface-indexed, and interval-driven (`on_nth_tick` with per-surface wind caching rather than per-tick `on_tick` or O(N) `table_size` polling), validating entity and render references (`valid`) to prevent UPS degradation on large multi-surface SE saves.
- **Strict priority of *Space Exploration* progression and physics:** Wind turbines cannot be placed in orbit, asteroid belts/fields, or spaceships (`se_allow_in_space = false` + `space_tile` collision mask), generate `0 W` with stationary rotors on any non-solid SE surface (even if script-placed or when `WindSpeedChanging` modifies space-surface `wind_speed`), and align with SE's science progression without bypassing orbital milestones.
- **Seamless synergy with `WindSpeedChanging >= 2.1.2`:** Rely on `surface.wind_speed` as the single source of truth across all surfaces, automatically pausing internal wind variation and calibrating reference wind speed to `(wsc-min-wind-speed + wsc-max-wind-speed) / 2` when `WindSpeedChanging` is installed, while degrading gracefully to built-in multi-surface wind variation when absent.
- **Comprehensive configurability (`settings.lua`):** Expose per-tier nominal power outputs, wind scaling calibration, peak wind multiplier, runtime update cadence, VRAM optimization, and SE toggles via well-bounded `startup` and `runtime-global` settings.

## 3. Mod Settings (`settings.lua`)

### 3.1 Startup Settings (`startup`)

| Setting Name | Type | Default | Range | Description |
|---|---|---|---|---|
| `wt-low-vram` | `bool-setting` | `false` | — | Uses LD sprites and halves rotational steps (16 instead of 32) to reduce VRAM usage. |
| `wt-se-balancing` | `bool-setting` | `true` | — | When `space-exploration` is active, aligns turbine tech prerequisites, science packs, and Mk3 recipe (`se-aeroframe-pole`) with SE progression. |
| `wt-se-block-in-space` | `bool-setting` | `true` | — | When `space-exploration` is active, blocks placing wind turbines in space/spaceships and forces `0 W` output on non-solid surfaces. |
| `wt-spacing-mk1` | `int-setting` | `18` | `5` – `50` | Minimum center-to-center distance (tiles) between two Wind Turbine Mk1 towers. |
| `wt-spacing-mk2` | `int-setting` | `23` | `5` – `50` | Minimum center-to-center distance (tiles) between two Wind Turbine Mk2 towers. |
| `wt-spacing-mk3` | `int-setting` | `30` | `5` – `50` | Minimum center-to-center distance (tiles) between two Wind Turbine Mk3 towers. |

### 3.2 Runtime-Global Settings (`runtime-global`)

| Setting Name | Type | Default | Range | Description |
|---|---|---|---|---|
| `wt-power-mk1` | `double-setting` | `750.0` | `10.0` – `100000.0` | Nominal electrical output of Wind Turbine Mk1 in kW at reference wind speed. |
| `wt-power-mk2` | `double-setting` | `1500.0` | `10.0` – `200000.0` | Nominal electrical output of Wind Turbine Mk2 in kW at reference wind speed. |
| `wt-power-mk3` | `double-setting` | `3000.0` | `10.0` – `500000.0` | Nominal electrical output of Wind Turbine Mk3 in kW at reference wind speed. |
| `wt-locked-power` | `bool-setting` | `false` | — | Outputs constant nominal power regardless of wind speed (still `0 W` on airless/SE space surfaces). |
| `wt-vary-windspeed` | `bool-setting` | `true` | — | Enables built-in multi-surface wind variation every 5 seconds when `WindSpeedChanging` is not installed. |
| `wt-reference-wind-speed` | `double-setting` | `0.02` | `0.001` – `1.0` | Surface `wind_speed` corresponding to 100% nominal output (overridden automatically when `wt-auto-calibrate-wsc` is enabled with `WindSpeedChanging`). |
| `wt-auto-calibrate-wsc` | `bool-setting` | `true` | — | Automatically derives reference wind speed as `(wsc-min-wind-speed + wsc-max-wind-speed) / 2` when `WindSpeedChanging` is active. |
| `wt-max-wind-multiplier` | `double-setting` | `2.0` | `1.0` – `5.0` | Upper multiplier cap on wind-scaled power output (e.g., `2.0` allows up to 200% nominal power in strong gusts). |
| `wt-update-interval` | `int-setting` | `30` | `5` – `600` | Tick cadence (`on_nth_tick`) for checking surface wind changes and updating turbines (`30` ticks = 0.5s). |

### 3.3 Runtime-Per-User Settings (`runtime-per-user`)

| Setting Name | Type | Default | Range | Description |
|---|---|---|---|---|
| `wt-show-spacing-overlay` | `bool-setting` | `true` | — | Renders tile-aligned ground exclusion zones around existing turbines while holding a wind turbine item or ghost in cursor (0 UPS idle). |

## 4. Prototypes, Entities, and Technologies (`data.lua` / `prototypes/`)

### 4.1 Per-Tier Custom Collision Layers & Spacing Matrix (`prototypes/collision_layers.lua`)
- Declares three dedicated Factorio 2.1 `collision-layer` prototypes: `wt-spacing-for-mk1`, `wt-spacing-for-mk2`, and `wt-spacing-for-mk3`.
- Each turbine tower prototype (`ownly_wind_turbine_build_mkN` and `ownly_wind_turbine_mkN`) carries only its own layer (`wt-spacing-for-mkN`), leaving belts, solar panels, poles, and other structures unaffected and avoiding vanilla's `resource` layer.
- Mixed-tier spacing uses the symmetric **sum-of-radii** rule:
  `D(i, j) = math.ceil((spacing_i + spacing_j) / 2)`
  *(Default matrix: `Mk1–Mk1 = 18`, `Mk1–Mk2 = 21`, `Mk1–Mk3 = 24`, `Mk2–Mk2 = 23`, `Mk2–Mk3 = 27`, `Mk3–Mk3 = 30` tiles center-to-center, scaling by `×1.3` per tier).*
- Beneath each active tier `i` turbine, three hidden spacing entities (`ownly_wind_turbine_spacing_mk{i}_for_mk{j}`, `j = 1..3`) enforce exact Chebyshev separation against each target tier `j` using box half-size `h(i, j) = math.max(0.5, D(i, j) - r_j - 0.5)`.

### 4.2 Entities & Animations (`prototypes/animations.lua`, `prototypes/entities.lua`)
- **Per-tier visual scaling & 3×3 grid alignment:** All sprites, shifts, and render offsets are scaled proportionally around the ground contact origin `(0, 0)` while keeping tower footprints on the same odd `3×3` grid:
  - **Mk1:** `visual_scale = 0.75`, `collision_box = ±1.05`, `selection_box = ±0.75`, `corpse = "medium-remnants"`, `drawing_box_vertical_extension = 18`.
  - **Mk2:** `visual_scale = 1.00`, `collision_box = ±1.20`, `selection_box = ±0.90`, `corpse = "big-remnants"`, `drawing_box_vertical_extension = 24`.
  - **Mk3:** `visual_scale = 1.30`, `collision_box = ±1.45`, `selection_box = ±1.15`, `corpse = "big-remnants"`, `drawing_box_vertical_extension = 32`.
- **Asset paths & VRAM deduplication:** All sprites and icons reference `__ethanatos-windturbines-redux-2.1-se__/graphics/...` with Factorio 2.1 direct sprite definitions (no removed `hr_version` blocks). When `wt-low-vram` is `false`, HD sprites (`600×800` rotor at `1 * s`, `800×400` shadow at `2 * s`) are loaded across 32 rotations (`0..31`); when `true`, LD sprites (`300×400` at `2 * s`, `400×200` at `4 * s`) are loaded across 16 even rotations. Per-tier shadow animations (`ownly_wind_turbine_shadow_mk{N}_{0..31}`) reuse identical PNG paths so Factorio's sprite atlas adds zero extra VRAM.
- **Entity prototypes per tier (`mk1`, `mk2`, `mk3`):**
  1. `ownly_wind_turbine_build_mkN` (`electric-energy-interface`): Scaled build preview/placement entity with `custom_tooltip_fields` displaying configured minimum spacing, replaced immediately on construction by the active tower + spacing blockers + animated rotor/shadow renders.
  2. `ownly_wind_turbine_mkN` (`electric-energy-interface`): Active scaled static tower base (`primary-output`, `input_flow_limit = "0kW"`, `render_no_power_icon = false`, spacing tooltip field).
  3. `ownly_wind_turbine_spacing_mk{i}_for_mk{j}` (`simple-entity-with-force`, `hidden = true`, `selectable_in_game = false`, 9 prototypes): Per-pair spacing blockers using only `{ layers = { ["wt-spacing-for-mk" .. j] = true } }`.

### 4.3 Items, Recipes & Technologies (`prototypes/items.lua`, `prototypes/recipes.lua`, `prototypes/technologies.lua`)
- **Items:** `ownly_wind_turbine_mk1..3` (`subgroup = "energy"`, fallback `order = "d[solar-panel]-z[wind-turbine]-1..3"`, `stack_size = 20`, `place_result = "ownly_wind_turbine_build_mk1..3"`). In `data-final-fixes.lua`, `utils.align_turbines_after_solar_panels` dynamically anchors both items and recipes to the subgroup and `order` immediately following the last solar panel (`... -z[wind-turbine]-1..3`).
- **Recipes (Factorio 2.1 `ingredients` / `results` format, `enabled = false`, `energy_required = 30`):**
  - **Mk1:** 50 `copper-cable`, 50 `plastic-bar`, 40 `steel-plate`, 10 `electronic-circuit`, 100 `concrete` -> 1 `ownly_wind_turbine_mk1`.
  - **Mk2:** 2 `ownly_wind_turbine_mk1`, 5 `advanced-circuit`, 5 `low-density-structure` -> 1 `ownly_wind_turbine_mk2`.
  - **Mk3 (Vanilla):** 2 `ownly_wind_turbine_mk2`, 4 `low-density-structure`, 4 `processing-unit`, 4 `electric-engine-unit` -> 1 `ownly_wind_turbine_mk3`.
  - **Mk3 (SE with `wt-se-balancing = true`):** 2 `ownly_wind_turbine_mk2`, 4 `se-aeroframe-pole`, 4 `processing-unit`, 4 `electric-engine-unit` -> 1 `ownly_wind_turbine_mk3`.
- **Vanilla Technologies (when SE is absent or `wt-se-balancing = false`):**
  - **Mk1:** Prereqs `{ "plastics", "concrete", "logistic-science-pack" }`, 200x (`automation`, `logistic`), `time = 30`.
  - **Mk2:** Prereqs `{ "ownly_wind_turbine_mk1", "low-density-structure", "electric-energy-distribution-1" }`, 350x (`automation`, `logistic`, `chemical`), `time = 30`.
  - **Mk3:** Prereqs `{ "ownly_wind_turbine_mk2", "electric-engine", "processing-unit", "utility-science-pack" }`, 500x (`automation`, `logistic`, `chemical`, `utility`), `time = 30`.
- **SE-Balanced Technologies (`space-exploration` active and `wt-se-balancing = true`):**
  - **Mk1:** Prereqs `{ "plastics", "concrete", "electric-energy-distribution-1" }`, 200x (`automation`, `logistic`), `time = 30`.
  - **Mk2:** Prereqs `{ "ownly_wind_turbine_mk1", "low-density-structure", "se-rocket-science-pack" }`, 350x (`automation`, `logistic`, `chemical`, `se-rocket-science-pack`), `time = 30`.
  - **Mk3:** Prereqs `{ "ownly_wind_turbine_mk2", "electric-engine", "processing-unit", "utility-science-pack", "se-aeroframe-pole" }`, 500x (`automation`, `logistic`, `chemical`, `se-rocket-science-pack`, `space-science-pack`, `utility-science-pack`, `se-astronomic-science-pack-1`), `time = 30`. Aligns Mk2 with Rocket Science and Mk3 with Utility Science & Beryllium Aeroframe Poles (`se-aeroframe-pole`).

## 5. Runtime Mechanics (`control.lua`, `lib/turbine_manager.lua` & `lib/spacing_overlay.lua`)

### 5.1 State Management (`storage`)
- `storage.turbines[unit_number]`: Active turbine record (`base`, `collision_boxes`, `surface_index`, `level`, `orientation`, `turbine_render`, `shadow_render`, `last_speed`, `last_offset`).
- `storage.turbines_by_surface[surface_index][unit_number]`: Surface-partitioned index for O(1) idle skipping and per-surface batch updates.
- `storage.surface_wind[surface_index]`: Cached `{ orientation, effective_wind, wind_ratio, power_multiplier, anim_speed, settings_version }` for change detection.
- `storage.surface_is_solid[surface_index]`: Cached SE surface classification (`true` for `"planet"`/`"moon"` or when SE space blocking is inactive; `false` for non-solid zones).
- `storage.player_overlays[player_index]`: Per-player cursor overlay state (`level`, `surface_index`, `renders[unit_number] = { fill, border }`), present only while a player holds a wind turbine item or ghost.
- Initialized on `on_init`, re-synchronized on `on_load` (registering the configured `on_nth_tick` handler cleanly for MP determinism), and reconciled on `on_configuration_changed` (migrating legacy single spacing boxes and rebuilding renders/overlays to match current tier scales and spacing settings).

### 5.2 Event Lifecycle, Render Objects & Cursor Spacing Overlay
- **Filtered build events:** `on_built_entity`, `on_robot_built_entity`, `script_raised_built`, `script_raised_revive` (with Factorio 2.1 `{{filter = "name", name = ...}}` filters) + `on_entity_cloned`.
- **Filtered removal events:** `on_player_mined_entity`, `on_robot_mined_entity`, `on_entity_died`, `script_raised_destroy` (with name filters).
- **Surface cleanup events:** `on_surface_deleted`, `on_surface_cleared` invalidate surface caches, active overlays, and tracked entries.
- **Cursor overlay events (`lib/spacing_overlay.lua`):** `on_player_cursor_stack_changed`, `on_player_changed_surface`, `on_player_joined_game`, `on_player_left_game`, `on_player_removed`, and per-user `on_runtime_mod_setting_changed` (`wt-show-spacing-overlay`). Renders ground exclusion squares (`half = D(existing, held) - 0.5`) visible only to the holding player, updated incrementally in O(1) as turbines are built or removed, with 0 UPS idle cost.
- **Entity-bound `LuaRenderObject`s:** Rotor (`render_layer = "wires-above"`, offset `{ 0, -10 * s }`) and tier-matched shadow (offset `{ 6 * s, -1 * s }`) target `{ entity = base, offset = ... }` so Factorio automatically cleans up renders if an entity is externally removed. Mutated via Factorio 2.1 properties (`obj.animation`, `obj.animation_speed`, `obj.animation_offset`, `obj.destroy()`).

### 5.3 Wind Speed, Power & Animation Formulas
- **Orientation step (`0..31`):**
  `orientation = (math.floor(surface.wind_orientation * 32 + 0.5) + 16) % 32`
  *(Fixes the legacy `% 31` discontinuity where sprite index 31 was unreachable.)*
- **SE airless/space enforcement:** When `space-exploration` is active and `wt-se-block-in-space = true`, `remote.call("space-exploration", "get_surface_type", { surface_index = idx })` is queried once per surface. Any surface whose type is neither `"planet"` nor `"moon"` is treated as airless (`effective_wind = 0`, `power_production = 0`, `animation_speed = 0`, and excluded from built-in wind variation).
- **Reference wind speed (`ref_wind`):**
  - If `WindSpeedChanging` is active and `wt-auto-calibrate-wsc = true`:
    `ref_wind = math.max(0.001, (wsc_min + wsc_max) / 2)` (default `0.10` with `WindSpeedChanging_2.1.2`).
  - Otherwise: `ref_wind = settings.global["wt-reference-wind-speed"].value` (default `0.02`).
- **Normalized wind ratio & outputs:**
  - `wind_ratio = effective_wind / ref_wind` (`0` on airless/space surfaces).
  - `power_ratio`: `0` on airless/space surfaces; `1.0` if `wt-locked-power = true`; otherwise `math.min(wind_ratio, wt_max_wind_multiplier)`.
  - `nominal_joules_per_tick = tier_power_kw * 1000 / 60`.
  - `actual_joules_per_tick = nominal_joules_per_tick * power_ratio`.
  - `base.power_production = actual_joules_per_tick`.
  - `base.electric_buffer_size = math.max(nominal_joules_per_tick, actual_joules_per_tick)` *(prevents silent clamping of high-wind gusts above 100%)*.
  - `anim_speed = math.min(wind_ratio * 0.44, 1.5)` *(smooth `0.44` frames/tick at 1.0x reference wind, `0` when calm, capped to prevent visual strobing)*.
  - Phase-continuous frame offset on speed change:
    `expected_frame = ((tick * last_speed) + last_offset) % 24`, `new_offset = (expected_frame - ((tick * anim_speed) % 24)) % 24`.
- **Built-in wind variation (`on_nth_tick(300)`):** Runs only when `wt-vary-windspeed = true` and `WindSpeedChanging` / `WindSpeedChanging-Tweaked` are not active. Updates solid/windy surfaces using `math.max(0.001, (wind - 0.002 + math.random() * 0.004) * 0.975 + 0.00052)`.
- **Dynamic update cadence:** `on_nth_tick` registers on `wt-update-interval` (default `30` ticks) and re-registers cleanly when the setting changes at runtime. Surfaces whose wind state has not changed since the previous poll are skipped in O(1).

## 6. Post-SE Overrides (`data-final-fixes.lua` & `prototypes/se_compat.lua`)
- **Space placement enforcement:** Because `"electric-energy-interface"` is not in SE `0.7.64`'s `block_from_space` list (`prototypes/phase-3/space-collision.lua`), `prototypes/se_compat.lua` executes in `data-final-fixes.lua` (when `mods["space-exploration"]` is present and `wt-se-block-in-space = true`) to:
  1. Set `se_allow_in_space = false` on `ownly_wind_turbine_build_mk1..3` and `ownly_wind_turbine_mk1..3`.
  2. Add `[space_layer] = true` (resolving SE's `"space_tile"` collision layer via `space_collision_layer or "space_tile"`) to `collision_mask.layers`.
  3. Append SE's standard `"cannot-be-placed-on"` custom tooltip field via our own `lib/utils.lua` helper (without requiring internal SE modules).
- **SE technology & recipe alignment:** When `mods["space-exploration"]` is present and `wt-se-balancing = true`, updates Mk1/Mk2/Mk3 technology prerequisites/science packs and switches Mk3's structural ingredient to `se-aeroframe-pole` (checked in `data.raw.item`) as specified in Section 4.3.
- **`space-exploration-postprocess` compatibility:** Verified against `space-exploration-postprocess_0.7.8` (`sanity.lua`, `integrity_check.lua`, `tech-tree-prune.lua`). All recipes use 2.1 `ingredients`/`results`, technologies have clean non-redundant prerequisites, no SE technologies are altered, and `space-exploration-postprocess` is intentionally excluded from `info.json` dependencies.

## 7. Technical Architecture Conventions
- **Modularity:** Entry-point files (`settings.lua`, `data.lua`, `data-final-fixes.lua`, `control.lua`) stay thin and delegate to `lib/` (`constants.lua`, `utils.lua`, `turbine_manager.lua`, `spacing_overlay.lua`) and `prototypes/` (`collision_layers.lua`, `animations.lua`, `entities.lua`, `items.lua`, `recipes.lua`, `technologies.lua`, `se_compat.lua`).
- **Data-driven approach:** Tier parameters (power keys, recipes, vanilla & SE tech trees, icon paths, physics constants) are defined in structured tables inside `lib/constants.lua`.
- **Factorio 2.1 API & Lua hygiene:** Zero accidental globals (`local` everywhere), zero deprecated 1.1 fields (`global`, `hr_version`, `.normal`/`.expensive`, `icon_mipmaps`, array `collision_mask`, `recipe.result`, legacy `rendering.set_*`), and LuaLS annotations (`---@param`, `---@return`) on functions.
- **Traceability:** Every behavioral change, setting, or balancing rule implemented in Lua is kept synchronized in `SPEC.md`, `CHANGELOG.md` (*Keep a Changelog*), and Factorio's in-game `changelog.txt`.