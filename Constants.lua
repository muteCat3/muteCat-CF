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

---Builds text replacement tables lazily to reduce login/reload CPU spikes.
function AddOn:EnsureTextReplacementTables()
    if self.EnchantTextReplacements and self.UpgradeTextReplacements and self.DKEnchantAbbr then
        return
    end

    ---@enum DKEnchantAbbr
    self.DKEnchantAbbr = {
        Razorice = L["Razorice"],
        Sanguination = L["Sang"],
        Spellwarding = L["Spellward"],
        Apocalypse = L["Apoc"],
        FallenCrusader = L["Fall Crus"],
        StoneskinGargoyle = L["Stnskn Garg"],
        UnendingThirst = L["Unend Thirst"]
    }

    ---@type TextReplacement[]
    self.EnchantTextReplacements = {
        { original = "%%", replacement = "%%%%" }, -- Required for proper string formatting (% is a special character in formatting)
        { original = "+", replacement = "" }, -- Removes the '+' that usually prefixes enchantment text
        { original = L["Enchanted: "], replacement = "" },
        { original = L["Radiant Critical Strike"], replacement = L["Rad Crit"] },
        { original = L["Radiant Haste"], replacement = L["Rad Hst"] },
        { original = L["Radiant Mastery"], replacement = L["Rad Mast"] },
        { original = L["Radiant Versatility"], replacement = L["Rad Vers"] },
        { original = L["Cursed Critical Strike"], replacement = L["Curs Crit"] },
        { original = L["Cursed Haste"], replacement = L["Curs Hst"] },
        { original = L["Cursed Mastery"], replacement = L["Curs Mast"] },
        { original = L["Cursed Versatility"], replacement = L["Curs Vers"] },
        { original = L["Whisper of Armored Avoidance"], replacement = L["Arm Avoid"] },
        { original = L["Whisper of Armored Leech"], replacement = L["Arm Leech"] },
        { original = L["Whisper of Armored Speed"], replacement = L["Arm Spd"] },
        { original = L["Whisper of Silken Avoidance"], replacement = L["Silk Avoid"] },
        { original = L["Whisper of Silken Leech"], replacement = L["Silk Leech"] },
        { original = L["Whisper of Silken Speed"], replacement = L["Silk Spd"] },
        { original = L["Chant of Armored Avoidance"], replacement = L["Arm Avoid"] },
        { original = L["Chant of Armored Leech"], replacement = L["Arm Leech"] },
        { original = L["Chant of Armored Speed"], replacement = L["Arm Spd"] },
        { original = L["Scout's March"], replacement = L["Sco March"] },
        { original = L["Defender's March"], replacement = L["Def March"] },
        { original = L["Cavalry's March"], replacement = L["Cav March"] },
        { original = L["Stormrider's Agility"], replacement = L["Agi"] },
        { original = L["Council's Intellect"], replacement = L["Int"] },
        { original = L["Crystalline Radiance"], replacement = L["Crys Rad"] },
        { original = L["Oathsworn's Strength"], replacement = L["Oath Str"] },
        { original = L["Chant of Winged Grace"], replacement = L["Wing Grc"] },
        { original = L["Chant of Leeching Fangs"], replacement = L["Leech Fang"] },
        { original = L["Chant of Burrowing Rapidity"], replacement = L["Burr Rap"] },
        { original = L["Authority of Air"], replacement = L["Auth Air"] },
        { original = L["Authority of Fiery Resolve"], replacement = L["Fire Res"] },
        { original = L["Authority of Radiant Power"], replacement = L["Rad Pow"] },
        { original = L["Authority of the Depths"], replacement = L["Auth Deps"] },
        { original = L["Authority of Storms"], replacement = L["Auth Storm"] },
        { original = L["Oathsworn's Tenacity"], replacement = L["Oath Ten"] },
        { original = L["Stonebound Artistry"], replacement = L["Stn Art"] },
        { original = L["Stormrider's Fury"], replacement = L["Fury"] },
        { original = L["Council's Guile"], replacement = L["Guile"] },
        { original = L["Lesser Twilight Devastation"], replacement = L["Lssr Twi Dev"] },
        { original = L["Greater Twilight Devastation"], replacement = L["Grtr Twi Dev"] },
        { original = L["Lesser Void Ritual"], replacement = L["Lssr Void Rit"] },
        { original = L["Greater Void Ritual"], replacement = L["Grtr Void Rit"] },
        { original = L["Lesser Twisted Appendage"], replacement = L["Lssr Twst App"] },
        { original = L["Greater Twisted Appendage"], replacement = L["Grtr Twst App"] },
        { original = L["Lesser Echoing Void"], replacement = L["Lssr Echo Void"] },
        { original = L["Greater Echoing Void"], replacement = L["Grtr Echo Void"] },
        { original = L["Lesser Gushing Wound"], replacement = L["Lssr Gush Wnd"] },
        { original = L["Greater Gushing Wound"], replacement = L["Grtr Gush Wnd"] },
        { original = L["Lesser Infinite Stars"], replacement = L["Lssr Inf Star"] },
        { original = L["Greater Infinite Stars"], replacement = L["Grtr Inf Star"] },
        { original = L["Rune of the Fallen Crusader"], replacement = self.DKEnchantAbbr.FallenCrusader },
        { original = L["Rune of Razorice"], replacement = self.DKEnchantAbbr.Razorice },
        { original = L["Rune of Sanguination"], replacement = self.DKEnchantAbbr.Sanguination },
        { original = L["Rune of Spellwarding"], replacement = self.DKEnchantAbbr.Spellwarding },
        { original = L["Rune of the Apocalypse"], replacement = self.DKEnchantAbbr.Apocalypse },
        { original = L["Rune of the Stoneskin Gargoyle"], replacement = self.DKEnchantAbbr.StoneskinGargoyle },
        { original = L["Rune of Unending Thirst"], replacement = self.DKEnchantAbbr.UnendingThirst },
        { original = L["Stamina"], replacement = L["Stam"] },
        { original = L["Intellect"], replacement = L["Int"] },
        { original = L["Strength"], replacement = L["Str"] },
        { original = L["Agility"], replacement = L["Agi"] },
        { original = L["Speed"], replacement = L["Spd"] },
        { original = L["Avoidance"], replacement = L["Avoid"] },
        { original = L["Armor"], replacement = L["Arm"] },
        { original = L["Haste"], replacement = L["Hst"] },
        { original = L["Damage"], replacement = L["Dmg"] },
        { original = L["Mastery"], replacement = L["Mast"] },
        { original = L["Critical Strike"], replacement = L["Crit"] },
        { original = L["Versatility"], replacement = L["Vers"] },
        { original = L["Deftness"], replacement = L["Deft"] },
        { original = L["Finesse"], replacement = L["Fin"] },
        { original = L["Ingenuity"], replacement = L["Ing"] },
        { original = L["Perception"], replacement = L["Perc"] },
        { original = L["Resourcefulness"], replacement = L["Rsrc"] },
        { original = L["Absorption"], replacement = L["Absorb"] },
    }

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
    TheWarWithin = {
        LevelCap = 80,
        SocketableSlots = {
            CharacterNeckSlot,
            CharacterFinger0Slot,
            CharacterFinger1Slot
        },
        AuxSocketableSlots = {
            CharacterHeadSlot,
            CharacterWristSlot,
            CharacterWaistSlot,
            CharacterBackSlot -- Reshii Wraps in TWW S3
        },
        MaxSocketsPerItem = 2,
        MaxAuxSocketsPerItem = 1,
        MaxEmbellishments = 2,
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
        HeadEnchantAvailable = false,
        ShieldEnchantAvailable = false,
        OffhandEnchantAvailable = false
    }
}

---@enum TooltipDataType
AddOn.TooltipDataType = {
    UpgradeTrack = 42,
    Gem = 3,
    Enchant = 15,
}