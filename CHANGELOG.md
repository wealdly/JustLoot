# Changelog

All notable changes to JustLoot will be documented in this file.

## [1.9.11] - 2026-05-04

### Changed
- TOC interface version updated to 12.0.5 (120005)

### Improved
- Added `LOOT_SLOT_CLEARED` event handler: resets stall timer on server confirmation and closes loot immediately when last item is taken (eliminates up to 50ms delay on close)
- `StopLooting` now safely falls back to `LootFrame:Show()` when hook is uninitialized

### Fixed
- Removed unused `GetCVar` local

## [1.9.9] - 2026-03-11

### Added
- GitHub CI/CD: tag-triggered CurseForge deploy via BigWigs Packager
- README.md with features, commands, and installation instructions
- .pkgmeta for BigWigs Packager configuration

## [1.9.8] - 2025-06-26

### Changed
- Sound debounce: first loot sweep plays natural pickup sounds, only retries are silenced
- Consolidated mute/unmute into single `SetSoundsMuted()` helper
- Table-driven settings defaults and slash command toggles
- Added 3 missing loot sound FileDataIDs (LootCoinLarge, uiLootPickupItem, PickUpBag)

### Fixed
- Corrected error sound FileDataIDs (were pointing to wrong .ogg files)
