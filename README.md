# Auto Splitter Block

A Factorio 2.0 MOD that automatically sets splitter output filters to block the unused side when only one output has a compatible transport entity.

## Features

- When a splitter has a transport entity on only one output side, the other side is automatically blocked using an output filter.
- The filter is cleared when both outputs become occupied or both become empty.
- Responds to placement and removal by players, robots, and space platforms.
- Splitters with user-configured filters or connected to circuit networks are left untouched.

## Block Filter Item

The item used for blocking is configurable in MOD settings (startup).

- Default: Deconstruction planner
- With [Null Item](https://mods.factorio.com/mod/atan-null) installed: Null item (default)

## Compatible Transport Entities

- Transport belts (same direction or sideloading, but not opposite)
- Underground belts (same rules as transport belts)
- Splitters (same direction only)
- Loaders (same direction only)

All tiers are supported.
