--------------------------------------------------------------------------------
-- muteCat CF - Constants
-- Core configuration, color presets, and expansion metadata.
--------------------------------------------------------------------------------

local addonName, AddOn = ...
---@class muteCatCF: AceAddon, AceConsole-3.0, AceEvent-3.0
AddOn = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")

-- Localization setup
if not AddOn.L then
    AddOn.L = setmetatable({}, {
        __index = function(t, k)
            rawset(t, k, k)
            return k
        end,
    })
end
local L = AddOn.L

---@class TextReplacement
---@field original string The localization key for the original text to search for
---@field replacement string The replacement abbreviation

---Builds text replacement tables lazily for abbreviation logic.
function AddOn:EnsureTextReplacementTables()
    if self.UpgradeTextReplacements then return end

    ---@type TextReplacement[]
    self.UpgradeTextReplacements = {
        { original = L["Upgrade Level: "], replacement = "" },
        { original = L["Explorer "], replacement = "E" },
        { original = L["Adventurer "], replacement = "A" },
        { original = L["Veteran "], replacement = "V" },
        { original = L["Champion "], replacement = "C" },
        { original = L["Hero "], replacement = "H" },
        { original = L["Myth "], replacement = "M" }
    }
end

---@enum HexColorPresets
---Predefined hexadecimal color codes for various UI elements.
AddOn.HexColorPresets = {
    Poor = "9D9D9D",
    Uncommon = "1EFF00",
    Rare = "0070DD",
    Epic = "A335EE",
    Legendary = "FF8000",
    Artifact = "E6CC80",
    Heirloom = "00CCFF",
    Info = "FFD100",
    PrevSeasonGear = "808080",
    Error = "FF3300",
    
    -- Class Colors
    DeathKnight = "C41E3A",
    DemonHunter = "A330C9",
    Druid = "FF7C0A",
    Evoker = "33937F",
    Hunter = "AAD372",
    Mage = "3FC7EB",
    Monk = "00FF98",
    Paladin = "F48CBA",
    Priest = "FFFFFF",
    Rogue = "FFF468",
    Shaman = "0070DD",
    Warlock = "8788EE",
    Warrior = "C69B6D"
}

---A list of character gear SlotIDs visible in the Character Info window.
AddOn.GearSlotIDs = { 1, 2, 3, 15, 5, 4, 19, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17 }

---@class ExpansionDetails
---@field LevelCap number
---@field SocketableSlots table<number, boolean>
---@field AuxSocketableSlots table<number, boolean>
---@field MaxSocketsPerItem number
---@field MaxAuxSocketsPerItem number
---@field EnchantableSlots table<number, boolean>
---@field HeadEnchantAvailable boolean
---@field ShieldEnchantAvailable boolean
---@field OffhandEnchantAvailable boolean

---@type table<string, ExpansionDetails>
AddOn.ExpansionInfo = {
    Midnight = {
        LevelCap = 90,
        SocketableSlots = {
            [2] = true, -- Neck
            [11] = true, -- Finger0
            [12] = true, -- Finger1
        },
        AuxSocketableSlots = {
            [1] = true, -- Head
            [9] = true, -- Wrist
            [6] = true, -- Waist
            [15] = true, -- Back
        },
        MaxSocketsPerItem = 2,
        MaxAuxSocketsPerItem = 1,
        EnchantableSlots = {
            [1] = true, -- Head
            [15] = true, -- Back
            [5] = true, -- Chest
            [9] = true, -- Wrist
            [7] = true, -- Legs
            [8] = true, -- Feet
            [11] = true, -- Finger0
            [12] = true, -- Finger1
            [16] = true, -- MainHand
            [17] = true, -- SecondaryHand
        },
        HeadEnchantAvailable = false,
        ShieldEnchantAvailable = true,
        OffhandEnchantAvailable = true
    }
}

---@enum TooltipDataType
---Maps internal Blizzard tooltip line types to readable names.
AddOn.TooltipDataType = {
    UpgradeTrack = 42,
    Gem = 3,
    Enchant = 15,
}