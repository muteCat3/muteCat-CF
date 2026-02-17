local MAJOR, MINOR = "LibEnchantData-MIDNIGHT-1.0", 1
local lib = LibStub:NewLibrary(MAJOR, MINOR)

if not lib then return end

-- Base de données interne
local enchantData = {
-- --- LEG ENCHANTS (Jambières) ---
    [7935] = 1229442, -- Sunfire Silk Spellthread
    [7937] = 1229454, -- Arcanoweave Spellthread
    [7939] = 1229457, -- Bright Linen Spellthread
    [8159] = 1243976, -- Forest Hunter's Armor Kit
    [8161] = 1243978, -- Thalassian Scout Armor Kit
    [8163] = 1243980, -- Blood Knight's Armor Kit

    -- --- CHEST ENCHANTS (Torse) ---
    [7957] = 1236054, -- Mark of Nalorakk
    [7985] = 1236068, -- Mark of the Rootwarden
    [7987] = 1236069, -- Mark of the Worldsoul
    [8013] = 1236082, -- Mark of the Magister

    -- --- HELM ENCHANTS (Tête) ---
    [7959] = 1236055, -- Enchant Helm - Hex of Leeching
    [7961] = 1236056, -- Enchant Helm - Empowered Hex of Leeching
    [7989] = 1236070, -- Enchant Helm - Blessing of Speed
    [7991] = 1236071, -- Enchant Helm - Empowered Blessing of Speed
    [8015] = 1236083, -- Enchant Helm - Rune of Avoidance
    [8017] = 1236084, -- Enchant Helm - Empowered Rune of Avoidance

    -- --- BOOTS ENCHANTS (Bottes) ---
    [7963] = 1236057, -- Lynx's Dexterity
    [7993] = 1236072, -- Shaladrassil's Roots
    [8019] = 1236085, -- Farstrider's Hunt

    -- --- RING ENCHANTS (Anneau) ---
    [7965] = 1236058, -- Enchant Ring - Amani Mastery
    [7967] = 1236059, -- Enchant Ring - Eyes of the Eagle
    [7969] = 1236060, -- Enchant Ring - Zul'jin's Mastery
    [7995] = 1236073, -- Enchant Ring - Nature's Wrath
    [7997] = 1236074, -- Enchant Ring - Nature's Fury
    [8021] = 1236086, -- Enchant Ring - Thalassian Haste
    [8023] = 1236087, -- Enchant Ring - Thalassian Versatility
    [8025] = 1236088, -- Enchant Ring - Silvermoon's Alacrity
    [8027] = 1236089, -- Enchant Ring - Silvermoon's Tenacity

    -- --- SHOULDER ENCHANTS (Épaules) ---
    [7971] = 1236061, -- Enchant Shoulders - Flight of the Eagle
    [7973] = 1236062, -- Enchant Shoulders - Akil'zon's Celerity
    [7999] = 1236075, -- Enchant Shoulders - Nature's Grace
    [8001] = 1236076, -- Enchant Shoulders - Amirdrassil's Grace
    [8029] = 1236090, -- Enchant Shoulders - Thalassian Recovery
    [8031] = 1236091, -- Enchant Shoulders - Silvermoon's Mending

    -- --- WEAPON ENCHANTS (Armes) ---
    [7979] = 1236065, -- Enchant Weapon - Strength of Halazzi
    [7981] = 1236066, -- Enchant Weapon - Jan'alai's Precision
    [7983] = 1236067, -- Enchant Weapon - Berserker's Rage
    [8007] = 1236079, -- Enchant Weapon - Worldsoul Cradle
    [8009] = 1236080, -- Enchant Weapon - Worldsoul Aegis
    [8011] = 1236081, -- Enchant Weapon - Worldsoul Tenacity
    [8037] = 1236094, -- Enchant Weapon - Flames of the Sin'dorei
    [8039] = 1236095, -- Enchant Weapon - Acuity of the Ren'dorei
    [8041] = 1236097, -- Enchant Weapon - Arcane Mastery

    -- --- PROFESSION TOOL ENCHANTS (Outils) ---
    [7975] = 1236063, -- Enchant Tool - Amani Perception
    [7977] = 1236064, -- Enchant Tool - Amani Resourcefulness
    [8003] = 1236077, -- Enchant Tool - Haranir Finesse 
    [8005] = 1236078, -- Enchant Tool - Haranir Multicrafting
    [8033] = 1236092, -- Enchant Tool - Sin'dorei Deftness
    [8035] = 1236093, -- Enchant Tool - Ren'dorei Ingenuity

    -- --- DEATH KNIGHT RUNES (Evergreen) ---
    [3368] = 53344,    -- Rune of the Fallen Crusader
    [3369] = 53341,    -- Rune of Cinderglacier
    [3370] = 53343,    -- Rune of Razorice
    [3847] = 62158,    -- Rune of the Stoneskin Gargoyle
    [6241] = 327361,   -- Rune of the Apocalypse
    [6242] = 327362,   -- Rune of Unending Thirst
    [6243] = 327363,   -- Rune of Spellwarding
    [6244] = 327364,   -- Rune of Sanguination
    [6245] = 327365,   -- Rune of Hysteria
    }

-- --- API Publique de la Librairie ---

-- Retourne le Spell ID associé à un Enchant ID
-- @param enchantID (number) : L'ID de l'enchantement sur l'item
-- @return spellID (number|nil)
function lib:GetSpellID(enchantID)
    return enchantData[enchantID]
end

-- Retourne le premier Enchant ID trouvé pour un Spell ID donné (Recherche inversée)
-- Note : Comme 3 rangs partagent souvent le même SpellID, cela retournera n'importe lequel des rangs (souvent le R1).
-- @param spellID (number)
-- @return enchantID (number|nil)
function lib:GetEnchantID(spellID)
    for eid, sid in pairs(enchantData) do
        if sid == spellID then
            return eid
        end
    end
    return nil
end

-- Retourne toute la table des données (pour itération)
function lib:GetAllEnchants()
    return enchantData
end