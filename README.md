# JustLoot

Maximum speed auto-loot addon for World of Warcraft Retail (12.0+).

## Features

- **Instant looting** — OnUpdate-driven retry loop with `autoLootRate=0` clears corpses as fast as the engine allows
- **Early close** — `LOOT_SLOT_CLEARED` event closes the loot window the moment the last item is taken (up to 50ms faster)
- **Sound debounce** — First loot sweep plays natural pickup sounds; retries are silenced to prevent stuttering
- **Error suppression** — UI error messages and sounds hidden during auto-loot (restored on completion)
- **Auto-confirm BoP** — Automatically confirms Bind-on-Pickup loot dialogs
- **Auto-confirm rolls** — Automatically confirms loot roll dialogs
- **Skip key** — Hold your loot toggle key (Shift by default) to bypass auto-loot on demand
- **Stall detection** — Falls back to the default loot frame after 0.5s if items can't be picked up
- **Zero config** — Works out of the box with sensible defaults

## Slash Commands

| Command | Description |
|---------|-------------|
| `/jl` or `/justloot` | Show help |
| `/jl toggle` | Enable/disable auto-loot |
| `/jl autobind` | Toggle auto-confirm Bind-on-Pickup |
| `/jl autoroll` | Toggle auto-confirm loot rolls |
| `/jl mutesounds` | Toggle debouncing loot SFX on retries |
| `/jl debugsounds` | Log sound IDs during loot (for development) |
| `/jl status` | Show all current settings |

## Installation

1. Download and extract into your `Interface/AddOns/` folder
2. The folder should be named `JustLoot`
3. Reload UI or restart WoW

## How It Works

When `LOOT_READY` fires, JustLoot immediately brute-forces all loot slots in a single sweep. If items remain (locked slots, server lag), an OnUpdate handler retries every frame until the corpse is empty or progress stalls for 0.5 seconds. When the last slot is confirmed cleared via `LOOT_SLOT_CLEARED`, the loot window is closed immediately without waiting for the next frame. Error messages and retry sounds are suppressed to keep things clean.

The addon also sets `autoLootDefault=1`, `autoLootRate=0`, and `lootUnderMouse=1` for the fastest possible baseline.

## License

[GPL-3.0-or-later](LICENSE) — Copyright (C) 2024-2026 wealdly
