# WarbandTD — WoW Addon

## Overview

Tower defense mini-game for World of Warcraft. Players defend a Mythic+ keystone using their warband characters as towers across 3 lanes.

## Stack

- Lua 5.1 (WoW addon sandbox)
- WoW Frame API for UI rendering
- SavedVariables for persistence
- No external dependencies except LibStub

## Architecture

- `Core.lua` — Addon lifecycle, events, slash commands
- `GameState.lua` — Game engine: tick loop, combat, waves, spawning
- `UI.lua` — Frame creation, layout, rendering, frame pools
- `Animations.lua` — Projectiles, damage text, hit flash via AnimationGroup
- `Interaction.lua` — Click handlers, targeting mode, keybinds
- `Data/` — All game data as Lua tables (ported from Flutter app's JSON)
  - `ClassDefs.lua` — 13 WoW classes with passives, actives, ultimates
  - `DungeonDefs.lua` — Dungeon definitions with enemies, bosses, modifiers
  - `BalanceConfig.lua` — All tuning knobs
  - `EffectHandlers.lua` — Tower, enemy, and boss effect processing

## Key Constraints

- **Frames can't be GC'd** — always use object pools for dynamic elements (enemies, damage text, projectiles)
- **No file I/O** — all persistence via SavedVariables
- **No network** — everything runs locally
- **OnUpdate = game loop** — throttle with elapsed time, cap dt at 0.5s
- **Taint** — not a concern since we don't touch secure frames

## Data Sync

Game data originates from `mobile-wow-companion/assets/td/*.json`. Use `scripts/sync_td_data.py` to convert JSON → Lua tables when balance changes.

## Testing

- `/td` — Open the game
- `/td reset` — Reset SavedVariables
- `/td roster` — Show registered characters
- `/reload` — Reload UI to test changes
- Use BugSack + BugGrabber for error capture
