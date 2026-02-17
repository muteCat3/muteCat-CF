local addonName, AddOn = ...
---@class muteCatCF: AceAddon, AceConsole-3.0, AceEvent-3.0
AddOn = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
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
---@field original string The localization key for the original text to search for when abbreviating text
---@field replacement string The localization key for the abbreviation for the original text

---Builds text replacement tables lazily.
function AddOn:EnsureTextReplacementTables()
    if self.UpgradeTextReplacements then
        return
    end

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

---A list of character gear slots visible in the Character Info window
---@type Slot[]
AddOn.GearSlots = {
    CharacterHeadSlot,
    CharacterNeckSlot,
    CharacterShoulderSlot,
    CharacterBackSlot,
    CharacterChestSlot,
    CharacterShirtSlot,
    CharacterTabardSlot,
    CharacterWristSlot,
    CharacterHandsSlot,
    CharacterWaistSlot,
    CharacterLegsSlot,
    CharacterFeetSlot,
    CharacterFinger0Slot,
    CharacterFinger1Slot,
    CharacterTrinket0Slot,
    CharacterTrinket1Slot,
    CharacterMainHandSlot,
    CharacterSecondaryHandSlot
}

---@class ExpansionDetails
---@field LevelCap number The maximum reachable level for the expansion
---@field SocketableSlots Slot[] A list of gear slots that can have a gem socket added to it in the expansion.
---@field AuxSocketableSlots Slot[] A list of gear slots that can have a gem socket added to it via auxillary methods in the expansion (example: S.A.D. in _The War Within_).
---@field MaxSocketsPerItem number The maximum number of sockets an item can have
---@field MaxAuxSocketsPerItem number The maximum number of sockets items that can be socketed via auxillary methods can have
---@field EnchantableSlots Slot[] A list of gear slots that can be enchanted in the expansion.
---@field HeadEnchantAvailable boolean Indicates whether or not a head enchant from the expansion is currently available in-game
---@field ShieldEnchantAvailable boolean Indicates whether or not a shield enchant from the expansion is currently available in-game
---@field OffhandEnchantAvailable boolean Indicates whether or not an off-hand enchant from the expansion is currently available in-game

---@type table<string, ExpansionDetails>
---@see Frame for generic definition along without common functions and variables available for all Frames
AddOn.ExpansionInfo = {
    Midnight = {
        LevelCap = 90,
        SocketableSlots = {
            CharacterNeckSlot,
            CharacterFinger0Slot,
            CharacterFinger1Slot
        },
        AuxSocketableSlots = {
            CharacterHeadSlot,
            CharacterWristSlot,
            CharacterWaistSlot,
            CharacterBackSlot
        },
        MaxSocketsPerItem = 2,
        MaxAuxSocketsPerItem = 1,
        EnchantableSlots = {
            CharacterHeadSlot,
            CharacterBackSlot,
            CharacterChestSlot,
            CharacterWristSlot,
            CharacterLegsSlot,
            CharacterFeetSlot,
            CharacterFinger0Slot,
            CharacterFinger1Slot,
            CharacterMainHandSlot,
            CharacterSecondaryHandSlot
        },
        HeadEnchantAvailable = true,
        ShieldEnchantAvailable = true,
        OffhandEnchantAvailable = true
    }
}

---@enum TooltipDataType
AddOn.TooltipDataType = {
    UpgradeTrack = 42,
    Gem = 3,
    Enchant = 15,
}