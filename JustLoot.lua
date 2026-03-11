local addonName, JustLoot = ...

local frame = CreateFrame("Frame", "JustLootFrame", UIParent)
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        print("|cff00ff00JustLoot|r loaded.")
    end
end)
