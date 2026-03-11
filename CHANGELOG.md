# Changelog

All notable changes to JustLoot will be documented in this file.

## [1.9.8] - 2025-06-26

### Changed
- Sound debounce: first loot sweep plays natural pickup sounds, only retries are silenced
- Consolidated mute/unmute into single `SetSoundsMuted()` helper
- Table-driven settings defaults and slash command toggles
- Added 3 missing loot sound FileDataIDs (LootCoinLarge, uiLootPickupItem, PickUpBag)

### Fixed
- Corrected error sound FileDataIDs (were pointing to wrong .ogg files)
