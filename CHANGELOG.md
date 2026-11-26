# Changelog

All notable changes to `ethanatos-windturbines-redux-2.1-se` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Upstream lineage: originally created by **OwnlyMe** (`windturbines`), extended with configurable power by **jdelhaxhe / ethanatos**, and modernized for Factorio 1.1 by **Seth401** (`windturbines-redux`).

## [Unreleased]

### Added
- Finalized technical and balancing specification (`SPEC.md`) for the Factorio 2.1, *Space Exploration* `0.7.64`, and *Wind Speed Changing* `2.1.2` port.
- Added `CHANGELOG.md` following *Keep a Changelog* format and synced Factorio's in-game `changelog.txt`.
- Added modular data-driven core (`lib/constants.lua`, `lib/utils.lua`) and Factorio 2.1 prototypes (`prototypes/collision_layers.lua`, `animations.lua`, `entities.lua`, `items.lua`, `recipes.lua`, `technologies.lua`, `se_compat.lua`).
- Added dedicated Factorio 2.1 `wt-turbine-spacing` collision layer to enforce turbine spacing without polluting vanilla's `resource` layer.
- Added granular `startup` (`wt-low-vram`, `wt-se-balancing`, `wt-se-block-in-space`) and `runtime-global` (`wt-power-mk1..3`, `wt-locked-power`, `wt-vary-windspeed`, `wt-reference-wind-speed`, `wt-auto-calibrate-wsc`, `wt-max-wind-multiplier`, `wt-update-interval`) settings with full English localization (`locale/en/base.cfg`).
- Added `data-final-fixes.lua` Space Exploration `>= 0.7.0` integration enforcing `se_allow_in_space = false`, 2.1 `space_tile` collision mask, self-contained placement restriction tooltips, and SE technology alignment (`se-rocket-science-pack` for Mk3).
- Added modular Factorio 2.1 runtime engine (`lib/turbine_manager.lua`) using `storage`, entity-bound `LuaRenderObject` animations, per-surface wind caching with O(1) idle/unchanged skipping, SE `0.7.64` multi-surface airless detection (`get_surface_type`), and live `WindSpeedChanging >= 2.1.2` auto-calibration.

### Changed
- Updated `info.json` to `ethanatos-windturbines-redux-2.1-se` targeting Factorio `2.1` (`base >= 2.1.0`, `? WindSpeedChanging >= 2.1.2`, `(?) space-exploration >= 0.7.0`).
- Migrated all animations, entities, items, recipes, and technologies to Factorio 2.1 syntax (removed `hr_version`, array `collision_mask`, string `enabled = "false"`, and `recipe.result`; updated asset paths to `__ethanatos-windturbines-redux-2.1-se__`).
- Rewrote `control.lua` as a thin event dispatcher with Factorio 2.1 engine-level entity filters, full build/revive/clone/destroy/surface lifecycle handlers, dynamic `on_nth_tick` registration (`wt-update-interval`), and dynamic electric buffer scaling so high-wind gusts are never clamped.
- Rewrote `README.md` with concise player/operator documentation, settings summary, SE & `WindSpeedChanging` compatibility notes, upstream credits (`OwnlyMe` and `Seth401`), and the AI-generated code disclaimer.

### Fixed
- Fixed a runtime crash when placing wind turbines in Factorio 2.1 (`LuaEntity::minable is read only`): updated `create_collision_box` in `lib/turbine_manager.lua` to write `box.minable_flag = false`.
- Fixed empty technology science pack costs in Factorio 2.1 when Space Exploration tech balancing (`wt-se-balancing`) is enabled: `utils.apply_technology_spec` previously checked only `data.raw.tool`, which filtered out all Factorio 2.1 `type = "item"` science packs; now checks both `data.raw.item` and `data.raw.tool`, preserves existing science packs if validation ever returns empty, adds `"se-rocket-science-pack"` as an explicit Mk3 SE prerequisite, and deep-copies recipe/technology tables from `lib/constants.lua`.
- Fixed legacy wind-orientation modulo bug (`% 31` -> `% 32`) so all 32 directional rotor/shadow sprites are reachable without heading discontinuity (and snapped cleanly to the 16 even rotations in Low-VRAM mode).
- Fixed legacy `control.lua` duplicate `on_entity_died` registration, accidental global `SCRIPT_KILL`, Factorio 1.1 `global`/`created_entity`/`rendering.destroy` usage, and stale state handling across surface clears/deletions and configuration changes.

### Removed
- Removed temporary upstream audit extract `_seth401_diff.tmp` after capturing all `Seth401` improvements in `SPEC.md`.
- Removed legacy Factorio 1.1 root `entities.lua` and incompatible 1.1 `migrations/` scripts (`windturbines2-migration.lua`, `windturbines2-migration-fixAnimation.lua`) ahead of the modular Factorio 2.1 prototype and runtime rewrite.

## [0.19.03] - 2023-02-18 *(Upstream: Seth401)*

### Fixed
- Added a migration to clean up orphaned rendering animations lacking turbine references after upgrading from `windturbines2`.

## [0.19.02] - 2023-02-18 *(Upstream: Seth401)*

### Added
- Added Space Exploration 0.6 support preventing wind turbines from being placed in space.
- Added improved `WindSpeedChanging` wind-speed scaling integration.
- Added drop-in save migration from `windturbines2` and `windturbines2-configurable-power`.

### Changed
- Removed hardcoded power output labels from entity and technology localization strings to match configurable power settings.

## [0.19.01] - 2023-02-13 *(Upstream: Seth401)*

### Added
- Ported original mod to Factorio 1.1 as `windturbines-redux`.
- Added runtime-global configurable base power setting (`ownly_windturbines_base_power`, inspired by `ethanatos` / `jdelhaxhe`).
- Added runtime-global toggle for internal wind-speed variation (`ownly_windturbines_vary_windspeed`).

### Changed
- Moved power-locking setting from startup to `runtime-global` and refactored `control.lua` scoping and event registration.

## [0.18.11] *(Upstream: OwnlyMe)*

### Changed
- Reduced turbine spacing by 3 tiles after re-measuring blade clearances.
- Adjusted collision box so players can squeeze between solar panels and wind turbines.

## [0.17.10] *(Upstream: OwnlyMe)*

### Changed
- Slightly de-randomized wind speeds and removed hard speed caps.

## [0.17.9] *(Upstream: OwnlyMe)*

### Fixed
- Removed 2 leftover debug messages.

## [0.17.8] *(Upstream: OwnlyMe)*

### Fixed
- Fixed turbine top and base sprites not blending seamlessly.

## [0.17.7] *(Upstream: OwnlyMe)*

### Added
- Randomized surface wind speeds between `0.011` and `0.035` (previously fixed at `0.02`).
- Scaled animation speed and electrical power output dynamically with surface wind speed.
- Added a startup setting to lock power output independent of wind speed.

## [0.17.5] *(Upstream: OwnlyMe)*

### Fixed
- Fixed an error when a wind turbine was removed by a script.

### Changed
- Improved runtime performance with large wind parks.

## [0.17.4] *(Upstream: OwnlyMe)*

### Changed
- Hidden auxiliary entities from the map view.

## [0.17.3] *(Upstream: OwnlyMe)*

### Fixed
- Added safety checks to prevent runtime crashes.

## [0.17.2] *(Upstream: OwnlyMe)*

### Fixed
- Made auxiliary sub-entities indestructible to prevent crashes with fire-related mods.
