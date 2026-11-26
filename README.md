# Wind Turbines (Redux) — Factorio 2.1 & Space Exploration Port

> **AI-Generated Code Disclaimer:** This Factorio 2.1 & Space Exploration port (`ethanatos-windturbines-redux-2.1-se`) was written entirely with AI assistance. While carefully audited and structured, it may contain bugs or unexpected edge cases—please back up your saves and report any issues you encounter.

## Overview
Adds three tiers of animated wind turbines (**Mk1**, **Mk2**, and **Mk3**) that rotate smoothly into the wind direction across up to 32 headings and generate clean, 24/7 renewable electricity scaled dynamically by each surface's wind speed.

To stay balanced against solar panels, turbines require spacing between neighboring towers, while leaving the ground between towers free for belts, solar panels, poles, or factory buildings.

## Features
- **Factorio 2.1 native port:** Fully updated to Factorio 2.1 APIs (`storage`, `LuaRenderObject`, filtered events, dictionary `collision_mask`, and custom spacing collision layer).
- **UPS-optimized multi-surface runtime:** Tracks turbines per surface with wind-state caching and configurable `on_nth_tick` polling, avoiding unnecessary work when wind is steady or on surfaces without turbines.
- **Three configurable tiers (defaults: `750 kW` / `1500 kW` / `3000 kW`):** Adjust every tier's nominal output live in map settings without restarting.
- **Seamless `WindSpeedChanging >= 2.1.2` integration (optional):** Automatically detects `WindSpeedChanging`, pauses internal wind variation, and calibrates both electrical output and rotor animation speed to `WindSpeedChanging`'s configured min/max wind speed range. Works standalone with built-in multi-surface wind variation when `WindSpeedChanging` is not installed.
- **Space Exploration `>= 0.7.0` support (optional):**
  - Prevents building wind turbines in orbit, asteroid belts/fields, or spaceships (`se_allow_in_space = false` + `space_tile` collision mask & tooltip) and forces `0 W` output on non-solid surfaces.
  - Aligns technology progression with SE (`Mk3` unlocks at Rocket Science Pack + Processing Unit + Low Density Structure for planetary outpost power without bypassing orbital progression).

## Mod Settings Summary

### Startup Settings
- **Low VRAM mode (`wt-low-vram`):** Uses LD sprites and 16 directional steps instead of HD / 32 steps.
- **Space Exploration balancing (`wt-se-balancing`):** Aligns turbine tech prerequisites and science packs with SE when installed (default: `true`).
- **Block wind turbines in space (`wt-se-block-in-space`):** Prevents space placement and forces `0 W` output on airless/space surfaces when SE is installed (default: `true`).

### Map / Runtime-Global Settings
- **Nominal power per tier (`wt-power-mk1`, `wt-power-mk2`, `wt-power-mk3`):** Defaults to `750 kW`, `1500 kW`, `3000 kW`.
- **Locked power output (`wt-locked-power`):** Produces constant nominal power instead of scaling with wind speed (default: `false`).
- **Built-in varying wind speed (`wt-vary-windspeed`):** Gently varies wind speed every 5s when `WindSpeedChanging` is not installed (default: `true`).
- **Reference wind speed (`wt-reference-wind-speed`) & Auto-calibrate for WindSpeedChanging (`wt-auto-calibrate-wsc`):** Calibrates 100% nominal output and animation speed cleanly (auto-calibration enabled by default).
- **Maximum wind power multiplier (`wt-max-wind-multiplier`):** Caps peak gust power output (default: `2.0x`).
- **Runtime update interval (`wt-update-interval`):** Tick cadence for checking wind updates (default: `30` ticks = 0.5s; raise to save UPS on mega-bases).

## Credits & License
- Original mod **Wind Turbines** created by **OwnlyMe**.
- Configurable power concept from **Wind Turbines 2 Configurable Power** by **jdelhaxhe / ethanatos**.
- Factorio 1.1 **Wind Turbines (Redux)** overhaul, SE 0.6 & `WindSpeedChanging` groundwork by **Seth401**.
- Licensed under **CC BY-SA 3.0** (see `LICENSE.md`), excluding the original [Unity Asset Store wind turbine model](https://assetstore.unity.com/packages/3d/props/exterior/wind-turbine-26741) used by **OwnlyMe**.
