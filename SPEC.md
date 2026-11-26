# Technical and Balancing Specification — `ethanatos-windturbines-redux-2.1-se`

## 1. Technical Context
- **Game:** Factorio 2.1 (`space-age` and `quality` DLCs disabled).
- **Upstream Lineage:** Forked from `Seth401/windturbines-redux`, derived from `jdelhaxhe/windturbines-2-configurable-power` and original author `AwnlyMe`.
- **Primary Companion Mods:**
  - *Space Exploration* (`space-exploration >= 0.7.0`)
  - *Wind Speed Changing* (`WindSpeedChanging >= 2.1.2`)

## 2. Philosophy and Guiding Principles (Game Design)
- **UPS-conscious runtime design:** Keep runtime logic (`control.lua`) strictly minimal and event/interval-driven (`on_nth_tick` rather than per-tick `on_tick`), caching per-surface wind state and validating entity references (`entity.valid`) to prevent UPS degradation on large multi-surface saves.
- **Preservation of upstream behavior:** Retain core mechanics and graphical/wind-speed animation fixes introduced in `Seth401/windturbines-redux` while eliminating legacy Factorio 1.1 technical debt and latent bugs.
- **Strict priority of *Space Exploration* progression and physics:** Wind turbines must respect SE's atmospheric rules (`se_allow_in_space = false`, zero power generation in orbit or on airless surfaces where `surface.wind_speed == 0`), align with SE's technology tree and science pack tiers, and avoid trivializing early planetary or orbital power progression.
- **Seamless synergy with `WindSpeedChanging` 2.1.2:** Rely on `surface.wind_speed` as the single source of truth for wind conditions across surfaces rather than duplicating weather/wind simulation logic, ensuring clean compatibility whether `WindSpeedChanging` is installed or optional.
- **Comprehensive configurability (`settings.lua`):** Expose all major gameplay, balancing, and performance parameters (nominal power output per turbine tier, wind scaling behavior, runtime polling interval, and SE integration rules) via well-bounded `startup` and `runtime-global` settings with sensible defaults.

## 3. Mod Settings (`settings.lua`)
> *Note: Exact setting names, types, and default values will be finalized after the initial code audit (Section 8).*

### 3.1 Startup Settings (`startup`)
- **Turbine tier nominal power outputs:** Configurable maximum/nominal electrical output (in kW or MW) for each wind turbine tier so players can calibrate wind power relative to SE solar panels and steam engines.
- **Wind speed reference / scaling calibration:** Configurable reference wind speed or power multiplier governing how `surface.wind_speed` maps to actual generator output.
- **Space Exploration balancing & progression toggle (`bool-setting`, default: `true`):** Enables SE-specific recipe ingredients, technology prerequisites/science packs, and planetary placement restrictions (`se_allow_in_space = false`).

### 3.2 Runtime-Global Settings (`runtime-global`)
- **Runtime update interval (`int-setting`, ticks):** Controls the `on_nth_tick` polling cadence for updating turbine power production and animation speed (trading visual smoothness against UPS cost).

## 4. Prototypes, Entities, and Technologies (`data.lua` / `data-updates.lua`)
- **Entities & Graphics:** Wind turbine generator/energy-interface prototypes with wind-responsive rotor animation speed.
- **Recipes & Items:** Crafting costs and subgroups aligned with vanilla/SE electrical production categories.
- **Technologies:** Unlock nodes integrated cleanly into the pre-space/early-space progression without creating orphan branches or bypassing SE milestones.

## 5. Runtime Mechanics (`control.lua`)
- **State management (`storage`):** Track active wind turbines indexed cleanly in Factorio 2.1 `storage` (migrated from legacy `global`), initialized on `on_init` and reconciled on `on_configuration_changed`.
- **Lifecycle tracking:** Register all construction (`on_built_entity`, `on_robot_built_entity`, `script_raised_built`, `script_raised_revive`) and removal (`on_player_mined_entity`, `on_robot_mined_entity`, `on_entity_died`, `script_raised_destroy`) events using Factorio 2.1 entity name filters.
- **Multi-surface power & animation scaling:** Iterate dynamically over tracked entities/surfaces (never hardcoding `"nauvis"`), reading `surface.wind_speed` to scale electrical output and animation speed proportionally (yielding `0` output when `wind_speed == 0`).

## 6. Post-SE Overrides (`data-final-fixes.lua`)
- **Space placement enforcement:** Ensure `se_allow_in_space = false` is preserved on all wind turbine prototypes after SE's `phase-3/space-collision.lua` executes.
- **`space-exploration-postprocess` compatibility:** Ensure modified technologies and recipes pass SE's post-processing checks (`tech-tree-prune.lua`, `sanity.lua`, `integrity_check.lua`) cleanly without adding `space-exploration-postprocess` to `info.json`.

## 7. Technical Architecture Conventions
- **Modularity:** Keep entry-point files (`settings.lua`, `data.lua`, `data-updates.lua`, `data-final-fixes.lua`, `control.lua`) concise and delegate thematic logic to `prototypes/` and `lib/` modules.
- **Data-driven approach:** Define turbine tiers, power curves, and recipe/tech overrides in structured Lua configuration tables rather than duplicated imperative blocks.
- **Factorio 2.1 API compliance:** Zero usage of deprecated `global`, `.normal`/`.expensive` recipe/tech definitions, `icon_mipmaps`, or legacy `collision_mask` arrays.
- **Traceability:** Every behavioral change, setting, or balancing rule implemented in Lua must be documented in `SPEC.md` and logged under `## [Unreleased]` in `CHANGELOG.md` (*Keep a Changelog* format).

## 8. Audit & Balancing Backlog (Pre-Implementation Checklist)
This section tracks the technical audit and design decisions required before implementing the Factorio 2.1 + SE release. Each resolved item will be promoted into Sections 3 through 6.

### 8.1 Upstream Codebase & Bug Audit (`Seth401/windturbines-redux`) — *Pending*
- **Objective:** Inspect all existing Lua/JSON files in `./` to document current turbine tiers, entity types (`electric-energy-interface` vs `generator`), animation speed mechanics, existing settings, and any latent bugs (missing destroy events, invalid entity crashes, accidental globals, or `on_tick` bottlenecks).

### 8.2 Factorio 2.1 API Migration — *Pending*
- **Objective:** Identify every file and line incompatible with Factorio 2.1 (`info.json` `factorio_version` and dependencies, `global` -> `storage`, `script.on_event` filter syntax, prototype property deprecations).

### 8.3 Compatibility with `WindSpeedChanging_2.1.2` — *Pending*
- **Objective:** Inspect `../_sources_mods/WindSpeedChanging_2.1.2/` to verify how the 2.1 port modifies `surface.wind_speed` (whether it updates all surfaces or only `nauvis`, its update frequency, min/max wind bounds, and any remote interfaces/settings). Decide whether `WindSpeedChanging >= 2.1.2` should remain a required dependency or become optional (`? WindSpeedChanging >= 2.1.2`).

### 8.4 Space Exploration Integration & Power Balancing — *Pending*
- **Objective:** Inspect `../_sources_mods/space-exploration/` to verify how SE handles `surface.wind_speed` on planets vs orbit/asteroid fields, confirm `se_allow_in_space = false` enforcement, and calibrate turbine power outputs, recipes, and tech prerequisites against SE's early-game energy curve.

### 8.5 Granular Settings Architecture (`settings.lua`) — *Pending*
- **Objective:** Finalize the complete list of `startup` and `runtime-global` settings (per-tier power outputs, wind scaling curve/multiplier, update interval, SE balancing/space toggles) with safe min/max bounds and locale keys (`locale/en/`).