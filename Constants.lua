local addonName, AddOn = ...
---@class muteCatCF: AceAddon, AceConsole-3.0, AceEvent-3.0
AddOn = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName, true)

---@enum DKEnchantAbbr
AddOn.DKEnchantAbbr = {
    Razorice = L["Razorice"],
    Sanguination = L["Sang"],
    Spellwarding = L["Spellward"],
    Apocalypse = L["Apoc"],
    FallenCrusader = L["Fall Crus"],
    StoneskinGargoyle = L["Stnskn Garg"],
    UnendingThirst = L["Unend Thirst"]
}

---@class TextReplacement
---@field original string The localization key for the original text to search for when abbreviating text
---@field replacement string The localization key for the abbreviation for the original text

---A list of tables containing text replacement patterns for enchants
---@type TextReplacement[]
AddOn.EnchantTextReplacements = {
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
    { original = L["Rune of the Fallen Crusader"], replacement = AddOn.DKEnchantAbbr.FallenCrusader },
    { original = L["Rune of Razorice"], replacement = AddOn.DKEnchantAbbr.Razorice },
    { original = L["Rune of Sanguination"], replacement = AddOn.DKEnchantAbbr.Sanguination },
    { original = L["Rune of Spellwarding"], replacement = AddOn.DKEnchantAbbr.Spellwarding },
    { original = L["Rune of the Apocalypse"], replacement = AddOn.DKEnchantAbbr.Apocalypse },
    { original = L["Rune of the Stoneskin Gargoyle"], replacement = AddOn.DKEnchantAbbr.StoneskinGargoyle },
    { original = L["Rune of Unending Thirst"], replacement = AddOn.DKEnchantAbbr.UnendingThirst },
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

---A list of tables containing text replacement patterns for enchants that are specific to the ptBR locale.
---Intended for replacement after language-agnostic replacements are completed
---@type TextReplacement[]
AddOn.ptbrEnchantTextReplacements = {
    { original = "Evasão", replacement = L["Avoid"] },
    { original = "de ", replacement = "" },
    { original = "da ", replacement = "" },
    { original = "do ", replacement = "" },
}

---A list of tables containing text replacement patterns for enchants that are specific to the frFR locale.
---Intended for replacement after language-agnostic replacements are completed
---@type TextReplacement[]
AddOn.frfrEnchantTextReplacements = {
    { original = "à la ", replacement = "" },
    { original = "à l’", replacement = "" },
    { original = "au score de ", replacement = "" },
}

---A list of tables containing text replacement patterns for upgrade tracks
---@type TextReplacement[]
AddOn.UpgradeTextReplacements = {
    { original = L["Upgrade Level: "], replacement = "" },
    { original = L["Explorer "], replacement = "E" },
    { original = L["Adventurer "], replacement = "A" },
    { original = L["Veteran "], replacement = "V" },
    { original = L["Champion "], replacement = "C" },
    { original = L["Hero "], replacement = "H" },
    { original = L["Myth "], replacement = "M" }
}

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

---@enum SpecOptionKeys
AddOn.SpecOptionKeys = {
    [250] = L["Blood"],
    [251] = L["Frost"],
    [252] = L["Unholy"],
    [577] = L["Havoc"],
    [581] = L["Vengeance"],
    [102] = L["Balance"],
    [103] = L["Feral"],
    [104] = L["Guardian"],
    [105] = L["Restoration"],
    [1467] = L["Devastation"],
    [1468] = L["Preservation"],
    [1473] = L["Augmentation"],
    [253] = L["Beast Mastery"],
    [254] = L["Marksmanship"],
    [255] = L["Survival"],
    [62] = L["Arcane"],
    [63] = L["Fire"],
    [64] = L["Frost"],
    [268] = L["Brewmaster"],
    [270] = L["Mistweaver"],
    [269] = L["Windwalker"],
    [65] = L["Holy"],
    [66] = L["Protection"],
    [70] = L["Retribution"],
    [256] = L["Discipline"],
    [257] = L["Holy"],
    [258] = L["Shadow"],
    [259] = L["Assassination"],
    [260] = L["Outlaw"],
    [261] = L["Subtlety"],
    [262] = L["Elemental"],
    [263] = L["Enhancement"],
    [264] = L["Restoration"],
    [265] = L["Affliction"],
    [266] = L["Demonology"],
    [267] = L["Destruction"],
    [71] = L["Arms"],
    [72] = L["Fury"],
    [73] = L["Protection"],
}

---@enum DefaultStatOrder
AddOn.DefaultStatOrder = {
    ["Critical Strike"] = 1,
    ["Haste"] = 2,
    ["Mastery"] = 3,
    ["Versatility"] = 4,
    ["Leech"] = 5,
    ["Avoidance"] = 6,
    ["Speed"] = 7
}

---@enum DefaultTankStatOrder
AddOn.DefaultTankStatOrder = {
    ["Dodge"] = 8,
    ["Parry"] = 9,
    ["Block"] = 10
}

---@enum TooltipDataType
AddOn.TooltipDataType = {
    UpgradeTrack = 42,
    Gem = 3,
    Enchant = 15,

}

---@class (exact) RaceGender
---@field Male string The atlas alias for the icon corresponding to a male of the associated race
---@field Female string The atlas alias for the icon corresponding to a female of the associated race

---@type table<string, RaceGender>
AddOn.RaceIcons = {
    Human = {
        Male = "RaceIcon128-Human-Male",
        Female = "RaceIcon128-Human-Female"
    },
    Dwarf = {
        Male = "RaceIcon128-Dwarf-Male",
        Female = "RaceIcon128-Dwarf-Female"
    },
    NightElf = {
        Male = "RaceIcon128-NightElf-Male",
        Female = "RaceIcon128-NightElf-Female"
    },
    Gnome = {
        Male = "RaceIcon128-Gnome-Male",
        Female = "RaceIcon128-Gnome-Female"
    },
    Draenei = {
        Male = "RaceIcon128-Draenei-Male",
        Female = "RaceIcon128-Draenei-Female"
    },
    Worgen = {
        Male = "RaceIcon128-Worgen-Male",
        Female = "RaceIcon128-Worgen-Female"
    },
    VoidElf = {
        Male = "RaceIcon128-VoidElf-Male",
        Female = "RaceIcon128-VoidElf-Female"
    },
    LightforgedDraenei = {
        Male = "RaceIcon128-Lightforged-Male",
        Female = "RaceIcon128-Lightforged-Female"
    },
    DarkIronDwarf = {
        Male = "RaceIcon128-DarkIronDwarf-Male",
        Female = "RaceIcon128-DarkIronDwarf-Female"
    },
    KulTiran = {
        Male = "RaceIcon128-KulTiran-Male",
        Female = "RaceIcon128-KulTiran-Female"
    },
    Mechagnome = {
        Male = "RaceIcon128-Mechagnome-Male",
        Female = "RaceIcon128-Mechagnome-Female"
    },
    Orc = {
        Male = "RaceIcon128-Orc-Male",
        Female = "RaceIcon128-Orc-Female"
    },
    Undead = {
        Male = "RaceIcon128-Undead-Male",
        Female = "RaceIcon128-Undead-Female"
    },
    Tauren = {
        Male = "RaceIcon128-Tauren-Male",
        Female = "RaceIcon128-Tauren-Female"
    },
    Troll = {
        Male = "RaceIcon128-Troll-Male",
        Female = "RaceIcon128-Troll-Female"
    },
    BloodElf = {
        Male = "RaceIcon128-BloodElf-Male",
        Female = "RaceIcon128-BloodElf-Female"
    },
    Goblin = {
        Male = "RaceIcon128-Goblin-Male",
        Female = "RaceIcon128-Goblin-Female"
    },
    Nightborne = {
        Male = "RaceIcon128-Nightborne-Male",
        Female = "RaceIcon128-Nightborne-Female"
    },
    HighmountainTauren = {
        Male = "RaceIcon128-Highmountain-Male",
        Female = "RaceIcon128-Highmountain-Female"
    },
    MagharOrc = {
        Male = "RaceIcon128-MagharOrc-Male",
        Female = "RaceIcon128-MagharOrc-Female"
    },
    ZandalariTroll = {
        Male = "RaceIcon128-Zandalari-Male",
        Female = "RaceIcon128-Zandalari-Female"
    },
    Vulpera = {
        Male = "RaceIcon128-Vulpera-Male",
        Female = "RaceIcon128-Vulpera-Female"
    },
    Pandaren = {
        Male = "RaceIcon128-Pandaren-Male",
        Female = "RaceIcon128-Pandaren-Female"
    },
    Dracthyr = {
        Male = "RaceIcon128-Dracthyr-Male",
        Female = "RaceIcon128-Dracthyr-Female"
    },
    Earthen = {
        Male = "RaceIcon128-Earthen-Male",
        Female = "RaceIcon128-Earthen-Female"
    }
}

---@enum ClassIcons
AddOn.ClassIcons = {
    DeathKnight = "ClassIcon-DeathKnight",
    DemonHunter = "ClassIcon-DemonHunter",
    Druid = "ClassIcon-Druid",
    Evoker = "ClassIcon-Evoker",
    Hunter = "ClassIcon-Hunter",
    Mage = "ClassIcon-Mage",
    Monk = "ClassIcon-Monk",
    Paladin = "ClassIcon-Paladin",
    Priest = "ClassIcon-Priest",
    Rogue = "ClassIcon-Rogue",
    Shaman = "ClassIcon-Shaman",
    Warlock = "ClassIcon-Warlock",
    Warrior = "ClassIcon-Warrior"
}

---@class OutlineOption
---@field key string The localization key for the dropdown option
---@field value string The value for text outline to pass to `SetFont()`

---@type OutlineOption[]
AddOn.OutlineOptions = {
    { key = "None", value = "" },
    { key = "Monochrome", value = "MONOCHROME" },
    { key = "Regular", value = "OUTLINE" },
    { key = "Thick", value = "THICKOUTLINE" },
}

