--------------------------------------------------------------------------------
-- muteCat CF - Utils
-- Helper functions for color formatting, text scaling, and slot detection.
--------------------------------------------------------------------------------

local addonName, AddOn = ...
---@class muteCatCF: AceAddon, AceConsole-3.0, AceEvent-3.0
AddOn = LibStub("AceAddon-3.0"):GetAddon(addonName)
local L = AddOn.L

---Resolves the current expansion's level cap based on game version.
---@return number|nil
local function ResolveCurrentLevelCap()
    if type(GetExpansionLevel) ~= "function" or type(GetMaxLevelForExpansionLevel) ~= "function" then
        return nil
    end

    local okLevel, expansionLevel = pcall(GetExpansionLevel)
    if not okLevel or type(expansionLevel) ~= "number" then return nil end

    local okCap, levelCap = pcall(GetMaxLevelForExpansionLevel, expansionLevel)
    if okCap and type(levelCap) == "number" and levelCap > 0 then
        return levelCap
    end

    return nil
end

-- Initialize current expansion context
AddOn.CurrentExpac = AddOn.ExpansionInfo.Midnight
local resolvedLevelCap = ResolveCurrentLevelCap()
if resolvedLevelCap then
    AddOn.CurrentExpac.LevelCap = resolvedLevelCap
end

---Formats text with color syntax for Blizzard's UI.
---@param text string|number The text to be colored
---@param color string Hex code or key from HexColorPresets
---@return string result Formatted text string
function AddOn.ColorText(text, color)
    local hex = AddOn.HexColorPresets[color] or color
    return WrapTextInColorCode(tostring(text), "FF" .. hex)
end

local ColorText = AddOn.ColorText

---Prints a message to the chat frame if debug mode is enabled.
---@vararg any
function AddOn.DebugPrint(...)
    if AddOn.db.profile.debug then
        print(ColorText("[muteCat Debug]", "Heirloom"), ...)
    end
end

---Prints a table's keys and values to chat for debugging.
---@param tbl table
function AddOn.DebugTable(tbl)
    if AddOn.db.profile.debug then
        print(ColorText("[muteCat Debug Table: START]", "Heirloom"))
        for k, v in pairs(tbl) do
            print(k, "=", ColorText(tostring(v), "Info"))
        end
        print(ColorText("[muteCat Debug Table: END]", "Heirloom"))
    end
end

---Sorts and re-indexes a table to remove 'holes' (nil values).
---@param tbl table
function AddOn.CompressTable(tbl)
    local keys = {}
    for k in pairs(tbl) do
        if type(k) == "number" then keys[#keys+1] = k end
    end
    table.sort(keys)

    local n = 1
    for _, oldIndex in ipairs(keys) do
        tbl[n] = tbl[oldIndex]
        if oldIndex ~= n then tbl[oldIndex] = nil end
        n = n + 1
    end
end

---Converts RGB decimals (0.0-1.0) into a hex string.
---@param r number
---@param g number
---@param b number
---@return string
function AddOn.ConvertRGBToHex(r, g, b)
    return string.format("%02X%02X%02X", (r or 1)*255, (g or 1)*255, (b or 1)*255)
end

---Converts a hex string into RGB decimals (0.0-1.0).
---@param hex string
---@return number|nil r, number|nil g, number|nil b
function AddOn.ConvertHexToRGB(hex)
    if not hex or #hex < 6 then return nil, nil, nil end
    local r = tonumber(hex:sub(1,2), 16)
    local g = tonumber(hex:sub(3,4), 16)
    local b = tonumber(hex:sub(5,6), 16)
    
    if not r or not g or not b then
        print(ColorText("muteCat CF:", "Heirloom"), ColorText(L["Invalid hexadecimal color code provided."], "Error"))
        return nil, nil, nil
    end
    return r / 255, g / 255, b / 255
end

---Helper to round a number to the nearest integer.
---@param val number
---@return number
function AddOn.RoundNumber(val)
    return math.floor(val + 0.5)
end

---Checks if the player is at the current level cap.
---@return boolean
function AddOn:IsPlayerMaxLevel()
    if not self.CurrentExpac or not self.CurrentExpac.LevelCap then return false end
    return UnitLevel("player") >= self.CurrentExpac.LevelCap
end

---Returns the player's class token.
---@return string|nil
function AddOn:GetPlayerClassFile()
    if not self._cachedClassFile then
        self._cachedClassFile = select(2, UnitClass("player"))
    end
    return self._cachedClassFile
end

---Returns the player's class color as RGB components.
---@return number|nil r, number|nil g, number|nil b
function AddOn:GetPlayerClassColorRGB()
    if not self._cachedClassColorRGB then
        local classFile = self:GetPlayerClassFile()
        if not classFile then return nil, nil, nil end
        local r, g, b = GetClassColor(classFile)
        if not r then return nil, nil, nil end
        self._cachedClassColorRGB = { r = r, g = g, b = b }
    end
    return self._cachedClassColorRGB.r, self._cachedClassColorRGB.g, self._cachedClassColorRGB.b
end

---Returns the player's class color hex string (with alpha).
---@return string|nil
function AddOn:GetPlayerClassColorHexWithAlpha()
    if not self._cachedClassColorHexWithAlpha then
        local classFile = self:GetPlayerClassFile()
        if not classFile then return nil end
        self._cachedClassColorHexWithAlpha = select(4, GetClassColor(classFile))
    end
    return self._cachedClassColorHexWithAlpha
end

---Wraps a texture ID into a displayable WoW string.
---@param texture number|string
---@param dim? number icon size (default 15)
---@return string
function AddOn.GetTextureString(texture, dim)
    local size = dim or 15
    -- Shift 1px down for better alignment
    return "|T"..texture..":"..size..":"..size..":0:-1|t"
end

---Wraps an atlas name into a displayable WoW string.
---@param atlas string
---@param dim? number icon size (default 15)
---@return string
function AddOn.GetTextureAtlasString(atlas, dim)
    local size = dim or 15
    -- Shift 1px down for better alignment
    return "|A:"..atlas..":"..size..":"..size..":0:-1|a"
end

---Check if an item is equipped in the specified slot.
---@param slot Slot
---@return boolean hasItem, ItemMixin item
function AddOn:IsItemEquippedInSlot(slot)
    local item = self:GetCachedItemMixin(slot:GetID())
    if not item or item:IsItemEmpty() then return false, {} end
    return true, item
end

---Check if the target slot is traditionally socketable.
---@param slot Slot
---@return boolean
function AddOn:IsSocketableSlot(slot)
    if not self.CurrentExpac or not self.CurrentExpac.SocketableSlots then return false end
    local slotID = slot:GetID()
    return self.CurrentExpac.SocketableSlots[slotID] == true or self:IsAuxSocketableSlot(slot)
end

---Check if the target slot supports auxiliary sockets (e.g., Tinker).
---@param slot Slot
---@return boolean
function AddOn:IsAuxSocketableSlot(slot)
    if not self.CurrentExpac or not self.CurrentExpac.AuxSocketableSlots then return false end
    return self.CurrentExpac.AuxSocketableSlots[slot:GetID()] == true
end

---Check if the target slot is enchantable in the current expansion.
---@param slot Slot
---@return boolean
function AddOn:IsEnchantableSlot(slot)
    if not self.CurrentExpac or not self.CurrentExpac.EnchantableSlots then return false end
    local slotID = slot:GetID()
    if not self.CurrentExpac.EnchantableSlots[slotID] then return false end

    -- Item-specific checks (Head, Off-hand)
    local itemID = GetInventoryItemID("player", slotID)
    if not itemID then return true end

    if slotID == 1 then -- Head
        return self.CurrentExpac.HeadEnchantAvailable
    elseif slotID == 17 then -- Secondary Hand
        local itemClassID, itemSubclassID = select(6, C_Item.GetItemInfoInstant(itemID))
        local isShield = itemClassID == 4 and itemSubclassID == 6
        local isOffhand = itemClassID == 4 and itemSubclassID == 0
        if isShield then return self.CurrentExpac.ShieldEnchantAvailable end
        if isOffhand then return self.CurrentExpac.OffhandEnchantAvailable end
    end

    return true
end

---Shorten text using a pattern matching replacement table.
---@param text string
---@param replacementTable TextReplacement[]
---@return string
function AddOn:AbbreviateText(text, replacementTable)
    if not text then return "" end
    if not replacementTable or not next(replacementTable) then return text end
    for _, repl in pairs(replacementTable) do
        text = text:gsub(repl.original, repl.replacement)
    end
    return text
end

