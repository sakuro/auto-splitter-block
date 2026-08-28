# Auto Splitter Block

[![Downloads](https://img.shields.io/badge/dynamic/json.svg?label=Downloads&url=https%3A%2F%2Fmods.factorio.com%2Fapi%2Fmods%2Fauto-splitter-block&query=%24.downloads_count)](https://mods.factorio.com/mod/auto-splitter-block)

A Factorio MOD that automatically sets splitter output filters to block the unused side when only one output has a compatible transport entity.

## Features

- When a splitter has a transport entity on only one output side, the other side is automatically blocked using an output filter.
- The filter is cleared when both outputs become occupied or both become empty.
- Responds to placement and removal by players. Optionally also by robots and space platforms (disabled by default).
- Re-evaluates the block filter when a splitter or its output-side transport entity is rotated or flipped.
- Splitters with user-configured filters or connected to circuit networks are left untouched.

## Block Filter Item

The item used for blocking is configurable in MOD settings (startup). Default: No item.

Additional options with optional MODs:

- [Null Item](https://mods.factorio.com/mod/atan-null)
- [Null](https://mods.factorio.com/mod/null) (listed as "Null Item/Entity" on the MOD portal)

By default, the base game's "no-item" item is hidden and cannot be picked from filter UIs manually. Enable "Make 'no item' selectable in filter UIs" in MOD Settings > Startup to unhide it, allowing manual selection in any filter UI in the game (splitters, inserters, logistics requests, etc.), not just this MOD's automatic blocking. Disabled by default since it affects the base game item globally.

## Automated Builds

Entities built by construction robots or space platforms are ignored by default, to avoid overwriting filters set by blueprints (e.g. balancer designs). Space platforms have no manual placement — all platform construction goes through this same automated path, so enabling this is the only way to get auto-blocking working there.

Enable "Enable for automated builds" in MOD Settings > Map when needed, and turn it back off afterward. It's a single value shared by the whole force, not a quick toggle button, because flipping it also affects any other robot construction in progress elsewhere on the map.

## Compatible Transport Entities

- Transport belts (same direction or sideloading, but not opposite)
- Underground belts (inputs: same rules as transport belts; outputs: sideloading only)
- Splitters (same direction only)
- Loaders (same direction only)

All tiers are supported.
