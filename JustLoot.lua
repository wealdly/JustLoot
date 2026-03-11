-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2024-2025 wealdly
-- Maximum speed auto-loot for WoW Retail 12.0+
local ADDON_VERSION = "1.9.9"

-- Localize frequently called globals for speed
local GetNumLootItems = GetNumLootItems
local LootSlot = LootSlot
local CloseLoot = CloseLoot
local IsModifiedClick = IsModifiedClick
local SetCVar = SetCVar
local GetCVar = GetCVar
local MuteSoundFile = MuteSoundFile
local UnmuteSoundFile = UnmuteSoundFile
local ConfirmLootSlot = ConfirmLootSlot
local ConfirmLootRoll = ConfirmLootRoll
local StaticPopup_Hide = StaticPopup_Hide

local JustLoot = CreateFrame("Frame")
local UIErrorsFrame = UIErrorsFrame
local looting = false

-- Curated File Data IDs for loot sounds (sourced from wago.tools / wowhead).
-- MuteSoundFile/UnmuteSoundFile silences only these during auto-loot,
-- keeping music, ambience, combat SFX, and everything else fully audible.
local LOOT_SOUND_FILES = {
    -- Money
    567413,  -- LootCoinLarge.ogg
    567428,  -- LootCoinSmall.ogg
    -- Generic loot pickup
    567517,  -- uiLootPickupItem.ogg
    -- Item pickup (one per item-type category)
    567542,  -- PickUpRing.ogg
    567543,  -- PickUpBag.ogg
    567544,  -- PickUpWand.ogg
    567545,  -- PickUpBook.ogg
    567546,  -- PickUpFoodGeneric.ogg
    567550,  -- PickUpLargeChain.ogg
    567552,  -- PickUpHerb.ogg
    567554,  -- PickUpMetalLarge.ogg
    567555,  -- PickUpWater_Liquid.ogg
    567558,  -- PickUpWoodLarge.ogg
    567560,  -- PickUpMetalSmall.ogg
    567561,  -- PickUpSmallChain.ogg
    567562,  -- PickUpParchment_Paper.ogg
    567564,  -- PickUpRocks_Ore.ogg
    567565,  -- PickUpCloth_Leather.ogg
    567568,  -- PickUpGems.ogg
    567573,  -- PickUpMeat.ogg
    567576,  -- PickUpWoodSmall.ogg
}

-- Error sounds are ALWAYS muted during auto-loot to prevent stutter from
-- repeated LootSlot failures (bags full, locked corpse, etc.).
-- These are the FileDataIDs behind the relevant SOUNDKITs.
local ERROR_SOUND_FILES = {
    567459,  -- sound/interface/igquestfailed.ogg   (SOUNDKIT 846: UI_ERROR_MESSAGE, SOUNDKIT 847: IG_QUEST_FAILED)
}

local function SetSoundsMuted(fileList, muted)
    local fn = muted and MuteSoundFile or UnmuteSoundFile
    for i = 1, #fileList do
        fn(fileList[i])
    end
end

local LootFrameHooked = false
local OrigLootShow
local lastCount = 0
local stalledTime = 0
local lootElapsed = 0
local LOOT_THROTTLE = 0.05   -- seconds between loot-slot sweeps
local MAX_STALLED_TIME = 0.5 -- give up after 0.5s of no progress

-- Brute-force all slots — LootSlot on unlootable slots is a no-op and errors are suppressed
local function TryLootAll()
    local numItems = GetNumLootItems()
    if numItems == 0 then return false end
    for i = numItems, 1, -1 do
        LootSlot(i)
    end
    return true
end

-- Centralized cleanup — guarantees errors/sounds are always restored
local function StopLooting(self, showFrame)
    self:SetScript("OnUpdate", nil)
    looting = false
    UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
    -- Unmute sounds (no-op if they were never muted)
    SetSoundsMuted(ERROR_SOUND_FILES, false)
    SetSoundsMuted(LOOT_SOUND_FILES, false)
    -- Items remain (stalled) — surface the loot frame for manual handling
    if showFrame and LootFrame then
        OrigLootShow(LootFrame)
    end
end

-- Single reusable OnUpdate handler (avoids closure creation per loot event)
local function OnUpdateHandler(self, elapsed)
    local numItems = GetNumLootItems()
    if numItems == 0 then
        StopLooting(self)
        CloseLoot()
        return
    end

    if numItems >= lastCount then
        stalledTime = stalledTime + elapsed
    else
        stalledTime = 0
        lastCount = numItems
    end

    -- Stop if stuck (unlootable items remain) — show loot frame for manual handling
    if stalledTime >= MAX_STALLED_TIME then
        StopLooting(self, true)
        return
    end

    -- Throttle loot-slot sweeps to avoid hammering the API every frame
    lootElapsed = lootElapsed + elapsed
    if lootElapsed >= LOOT_THROTTLE then
        lootElapsed = 0
        TryLootAll()
    end
end

-- Debug hooks — log PlaySound/PlaySoundFile calls during loot for ID discovery.
-- Enable with /jl debugsounds, then loot something to see which IDs fire.
hooksecurefunc("PlaySound", function(soundKitID, channel)
    if looting and JustLootSettings and JustLootSettings.debugSounds then
        print("|cff00ff00JustLoot|r [sound] PlaySound id=" .. tostring(soundKitID) .. " channel=" .. tostring(channel))
    end
end)
hooksecurefunc("PlaySoundFile", function(soundFile, channel)
    if looting and JustLootSettings and JustLootSettings.debugSounds then
        print("|cff00ff00JustLoot|r [sound] PlaySoundFile file=" .. tostring(soundFile) .. " channel=" .. tostring(channel))
    end
end)

JustLoot:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        if type(JustLootSettings) ~= "table" then
            JustLootSettings = {}
        end
        local defaults = {
            enabled = true,
            autoConfirmBind = true,
            autoConfirmRoll = true,
            muteSounds = true,
            debugSounds = false,
        }
        for k, v in pairs(defaults) do
            if JustLootSettings[k] == nil then
                JustLootSettings[k] = v
            end
        end
        -- Zero delay on built-in auto-loot
        SetCVar("autoLootDefault", 1)
        SetCVar("autoLootRate", 0)
        -- Less mouse travel
        SetCVar("lootUnderMouse", 1)
        -- AoE loot is always on in Retail since MoP (no CVar needed)
    elseif event == "LOOT_READY" then
        if not JustLootSettings or not JustLootSettings.enabled then
            return
        end

        -- Respect the loot key toggle (shift by default disables auto-loot)
        if IsModifiedClick("AUTOLOOTTOGGLE") then
            return
        end

        -- Prevent overlapping loot attempts
        if looting then return end
        looting = true
        stalledTime = 0
        lootElapsed = 0
        lastCount = GetNumLootItems()

        -- Hook LootFrame.Show once to suppress it during auto-loot
        if not LootFrameHooked and LootFrame then
            OrigLootShow = LootFrame.Show
            LootFrame.Show = function(frame, ...)
                if looting then return end
                return OrigLootShow(frame, ...)
            end
            LootFrameHooked = true
        end

        if LootFrame and LootFrame:IsShown() then
            LootFrame:Hide()
        end

        -- Suppress error text and mute error sounds (always — prevents stutter)
        UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
        SetSoundsMuted(ERROR_SOUND_FILES, true)

        -- Loot immediately — first sweep plays natural pickup sounds
        TryLootAll()

        -- Mute loot sounds AFTER the first sweep to debounce retries
        if JustLootSettings.muteSounds then
            SetSoundsMuted(LOOT_SOUND_FILES, true)
        end

        -- Continue on subsequent frames for any stragglers
        if GetNumLootItems() > 0 then
            self:SetScript("OnUpdate", OnUpdateHandler)
        else
            StopLooting(self)
            CloseLoot()
        end
    elseif event == "LOOT_BIND_CONFIRM" then
        if JustLootSettings and JustLootSettings.autoConfirmBind then
            local slot = ...
            if slot then
                ConfirmLootSlot(slot)
                StaticPopup_Hide("LOOT_BIND")
            end
        end
    elseif event == "CONFIRM_LOOT_ROLL" then
        if JustLootSettings and JustLootSettings.autoConfirmRoll then
            local rollID, rollType = ...
            if rollID then
                ConfirmLootRoll(rollID, rollType)
                StaticPopup_Hide("CONFIRM_LOOT_ROLL")
            end
        end
    elseif event == "UI_ERROR_MESSAGE" then
        if looting then
            -- Instantly abort the loot loop on errors like "Inventory is full"
            StopLooting(self, true)
        end
    elseif event == "LOOT_CLOSED" then
        -- Loot window closed externally
        if looting then
            StopLooting(self)
        end
    end
end)

JustLoot:RegisterEvent("PLAYER_LOGIN")
JustLoot:RegisterEvent("LOOT_READY")
JustLoot:RegisterEvent("LOOT_CLOSED")
JustLoot:RegisterEvent("LOOT_BIND_CONFIRM")
JustLoot:RegisterEvent("CONFIRM_LOOT_ROLL")
JustLoot:RegisterEvent("UI_ERROR_MESSAGE")

SLASH_JUSTLOOT1 = "/justloot"
SLASH_JUSTLOOT2 = "/jl"
SlashCmdList["JUSTLOOT"] = function(msg)
    local cmd = strlower(strtrim(msg or ""))

    local function colorBool(v) return v and "|cff00ff00on|r" or "|cffff0000off|r" end

    local toggles = {
        toggle      = { key = "enabled",          label = "auto-loot" },
        autobind    = { key = "autoConfirmBind",   label = "auto-confirm BoP" },
        autoroll    = { key = "autoConfirmRoll",   label = "auto-confirm loot rolls" },
        mutesounds  = { key = "muteSounds",        label = "debounce loot SFX" },
        debugsounds = { key = "debugSounds",       label = "debug sounds" },
    }

    local toggle = toggles[cmd]
    if toggle then
        JustLootSettings[toggle.key] = not JustLootSettings[toggle.key]
        print("|cff00ff00JustLoot|r " .. toggle.label .. ": " .. colorBool(JustLootSettings[toggle.key]))
    elseif cmd == "status" then
        print("|cff00ff00JustLoot v" .. ADDON_VERSION .. "|r")
        print("  Auto-loot:           " .. colorBool(JustLootSettings.enabled))
        print("  Auto-confirm BoP:    " .. colorBool(JustLootSettings.autoConfirmBind))
        print("  Auto-confirm rolls:  " .. colorBool(JustLootSettings.autoConfirmRoll))
        print("  Debounce loot SFX:   " .. colorBool(JustLootSettings.muteSounds))
        print("  Debug sounds:        " .. colorBool(JustLootSettings.debugSounds))
    else
        print("|cff00ff00JustLoot v" .. ADDON_VERSION .. "|r")
        print("|cffFFD700/jl toggle|r   - Enable/disable auto-loot")
        print("|cffFFD700/jl autobind|r - Toggle auto-confirm Bind-on-Pickup")
        print("|cffFFD700/jl autoroll|r - Toggle auto-confirm loot rolls")
        print("|cffFFD700/jl mutesounds|r - Toggle debouncing loot SFX")
        print("|cffFFD700/jl debugsounds|r - Log sounds during loot (ID discovery)")
        print("|cffFFD700/jl status|r   - Show all settings")
    end
end
