local addonName, AddOn = ...
---@class muteCatCF: AceAddon, AceConsole-3.0, AceEvent-3.0
AddOn = LibStub("AceAddon-3.0"):GetAddon(addonName)
local L = AddOn.L

local function ResolveCurrentLevelCap()
    if type(GetExpansionLevel) ~= "function" or type(GetMaxLevelForExpansionLevel) ~= "function" then
        return nil
    end

    local okLevel, expansionLevel = pcall(GetExpansionLevel)
    if not okLevel or type(expansionLevel) ~= "number" then
        return nil
    end

    local okCap, levelCap = pcall(GetMaxLevelForExpansionLevel, expansionLevel)
    if okCap and type(levelCap) == "number" and levelCap > 0 then
        return levelCap
    end

    return nil
end

AddOn.CurrentExpac = AddOn.ExpansionInfo.Midnight
local resolvedLevelCap = ResolveCurrentLevelCap()
if resolvedLevelCap then
    AddOn.CurrentExpac.LevelCap = resolvedLevelCap
end

---Formats `text` to be displayed in a specific color in-game. If the argument is a valid entry in the `HexColorPresets` table, that value will be used.
---Alternatively, a color's hexadecimal code can be provided for the `color` argument instead.
---@param text string|number The text to display
---@param color string The color to display the text in.
---@return string result A formatted string wrapped in syntax to display `text` in the `color` desired at full opacity
---@see HexColorPresets for a list of predefined colors such as class colors, item quality, etc.
function AddOn.ColorText(text, color)
    if AddOn.HexColorPresets[color] then
        return WrapTextInColorCode(tostring(text), "FF"..AddOn.HexColorPresets[color])
    end

    return WrapTextInColorCode(tostring(text), "FF"..color)
end

local ColorText = AddOn.ColorText

---Prints the desired text if the AddOn is in debugging mode. This is just a wrapper around the standard `print` function.
---@vararg string|number
---@see print
function AddOn.DebugPrint(...)
    if AddOn.db.profile.debug then
		print(ColorText("[muteCat Debug]", "Heirloom"), ...)
	end
end
local DebugPrint = AddOn.DebugPrint

---Prints the contents of a Lua table as key-value pairs if the AddOn is in debugging mode.
---@param tbl table The table to print key-value pairs for
function AddOn.DebugTable(tbl)
    if AddOn.db.profile.debug then
        print(ColorText("[muteCat Debug Table: START]", "Heirloom"))
        for k, v in pairs(tbl) do
            print(k, "=", ColorText(v, "Info"))
        end
        print(ColorText("[muteCat Debug Table: END]", "Heirloom"))
    end
end

---Removes gaps in indicies of a table if values are `nil`. This modifies the `table` provided in the `tbl` argument and does not return a new one.
---@param tbl table The table to compress indicies for
function AddOn.CompressTable(tbl)
    -- collect all numeric indices
    local keys = {}
    for k in pairs(tbl) do
        if type(k) == "number" then
            keys[#keys+1] = k
        end
    end
    table.sort(keys)

    -- re-assign values to 1..n, clear old elements
    local n = 1
    for _, oldIndex in ipairs(keys) do
        tbl[n] = tbl[oldIndex]
        if oldIndex ~= n then
            tbl[oldIndex] = nil
        end
        n = n + 1
    end
end

---Converts color values for red, green, and blue into their corresponding hexadecimal code
---@param r number The red value for the color expressed as a decimal between `0` and `255`
---@param g number The green value for the color expressed as a decimal between `0` and `255`
---@param b number The blue value for the color expressed as a decimal between `0` and `255`
---@return string hexadecimal The corresponding hexadecimal code for the provided red, green, and blue decimal values at full opacity without the leading '#' character
function AddOn.ConvertRGBToHex(r, g, b)
    return string.format("%02X%02X%02X", r*255, g*255, b*255)
end

---Converts a hexadecimal code (without the leading '#' character) into its corresponding red, green, and blue decimal values
---@param hex string The hex code to convert to RGB values
---@return number|nil red The red value for the color expressed as a decimal between `0` and `255`. Returns `nil` if the supplied hex code is invalid
---@return number|nil green The green value for the color expressed as a decimal between `0` and `255`. Returns `nil` if the supplied hex code is invalid
---@return number|nil blue The blue value for the color expressed as a decimal between `0` and `255`. Returns `nil` if the supplied hex code is invalid
function AddOn.ConvertHexToRGB(hex)
    if tonumber("0x"..hex:sub(1,2)) == nil or tonumber("0x"..hex:sub(3,4)) == nil or tonumber("0x"..hex:sub(5,6)) == nil then
        print(ColorText("muteCat CF:", "Heirloom"), ColorText(L["Invalid hexadecimal color code provided."], "Error"))
        return nil, nil, nil
    end
    return tonumber("0x"..hex:sub(1,2)) / 255,
        tonumber("0x"..hex:sub(3,4)) / 255,
        tonumber("0x"..hex:sub(5,6)) / 255
end

---Utility function to round numbers
---@param val number The number to round
---@return number number The provided number rounded to the nearest whole number
function AddOn.RoundNumber(val)
    return math.floor(val + 0.5)
end

---Indicates whether the player has reached the current expansion level cap.
---@return boolean result `true` when the player is max level, `false` otherwise
function AddOn:IsPlayerMaxLevel()
    if not self.CurrentExpac or not self.CurrentExpac.LevelCap then
        return false
    end
    return UnitLevel("player") >= self.CurrentExpac.LevelCap
end

---Returns the player's class file token, cached after first lookup.
---@return string|nil classFile
function AddOn:GetPlayerClassFile()
    if not self._cachedClassFile then
        self._cachedClassFile = select(2, UnitClass("player"))
    end
    return self._cachedClassFile
end

---Returns the player's class color (RGB), cached after first lookup.
---@return number|nil r
---@return number|nil g
---@return number|nil b
function AddOn:GetPlayerClassColorRGB()
    if not self._cachedClassColorRGB then
        local classFile = self:GetPlayerClassFile()
        if not classFile then
            return nil, nil, nil
        end
        local r, g, b = GetClassColor(classFile)
        if not r or not g or not b then
            return nil, nil, nil
        end
        self._cachedClassColorRGB = { r = r, g = g, b = b }
    end

    return self._cachedClassColorRGB.r, self._cachedClassColorRGB.g, self._cachedClassColorRGB.b
end

---Returns the player's class color (hex with alpha), cached after first lookup.
---@return string|nil colorHexWithAlpha
function AddOn:GetPlayerClassColorHexWithAlpha()
    if not self._cachedClassColorHexWithAlpha then
        local classFile = self:GetPlayerClassFile()
        if not classFile then
            return nil
        end
        self._cachedClassColorHexWithAlpha = select(4, GetClassColor(classFile))
    end
    return self._cachedClassColorHexWithAlpha
end

---Formats `texture` to be displayed in-game using square dimensions
---@param texture number the ID for the texture to render
---@param dim? number The value to be used for the height & width of the texture. Default value is `15`
---@return string text A formatted string wrapped in syntax to display `texture`
function AddOn.GetTextureString(texture, dim)
    local size = 15
    if dim and type(dim) == "number" then
        size = dim
    end
    return "|T"..texture..":"..size..":"..size.."|t"
end

---Formats `atlas` to be displayed in-game using square dimensions. This differs from `GetTextureString` in that atlases use filenames rather than ID numbers to render
---@param atlas string the filename or atlas alias for the texture to render
---@param dim? number The value to be used for the height & width of the texture. Default value is `15`
---@return string text A formatted string wrapped in syntax to display `atlas`
function AddOn.GetTextureAtlasString(atlas, dim)
    local size = 15
    if dim and type(dim) == "number" then
        size = dim
    end
    return "|A:"..atlas..":"..size..":"..size.."|a"
end

---Creates a blank entry to display a space or create separation between items in the AddOn options menu
---@param order number The position of the blank entry in the immediate parent object
---@param width? number A specified width for the spacer if a full line is not desired
---@return { type: "description", name: " ", order: number, width: number? } spacer A table entry for showing a blank space between option elements
function AddOn.CreateOptionsSpacer(order, width)
    return {
        type = "description",
        name = " ",
        order = order,
        width = width
    }
end

---@class muteCatDurabilityBar: StatusBar
---@field percent number

---@class Slot: Frame
---@field IsLeftSide boolean|nil Indicates whether the equipment slot is on the left, right, or bottom of the character model in the default Character Info window
---@field muteCatItemLevel? FontString
---@field muteCatUpgradeTrack? FontString
---@field muteCatGems? FontString
---@field muteCatEnchant? FontString
---@field muteCatDurability? FontString
---@field muteCatDurabilityBarBg? StatusBar
---@field muteCatDurabilityBar? muteCatDurabilityBar
---@field muteCatEmbellishmentTexture? Texture
---@field muteCatEmbellishmentShadow? Texture

---Indicates whether an item is equipped in a particular gear slot or not
---@param slot Slot The gear slot to check for an equipped item
---@return boolean hasItem `true` if the slot has an item equipped in it, `false` otherwise
---@return ItemMixin item The equipped item. When `hasItem` is `false`, this is always an empty table
function AddOn:IsItemEquippedInSlot(slot)
    local item = Item:CreateFromEquipmentSlot(slot:GetID())
    return not item:IsItemEmpty(), item:IsItemEmpty() and {} or item
end

---Indicates whether an item equipped in a particular gear slot can have a gem socket added to it
---@param slot Slot The gear slot to check for socketable equipment
---@return boolean result `true` if the item can have a socket, `false` otherwise
function AddOn:IsSocketableSlot(slot)
    if self.CurrentExpac and self.CurrentExpac.SocketableSlots then
        for _, gearSlot in ipairs(self.CurrentExpac.SocketableSlots) do
            if slot == gearSlot then
                DebugPrint("Slot", ColorText(slot:GetID(), "Heirloom"), "is socketable")
                return true
            end
        end
    elseif self:IsAuxSocketableSlot(slot) then
        return true
    else
        DebugPrint(ColorText("SocketableSlots not found in expansion info table", "Error"))
    end
    return false
end

---Indicates whether an item equipped in a particular gear slot can have a gem socket added to it via auxillary methods (example: S.A.D. in The War Within)
---@param slot Slot The gear slot to check for socketable equipment
---@return boolean result `true` if the item can have a socket via auxillary methods, `false` otherwise
function AddOn:IsAuxSocketableSlot(slot)
    if self.CurrentExpac and self.CurrentExpac.AuxSocketableSlots then
        for _, gearSlot in ipairs(self.CurrentExpac.AuxSocketableSlots) do
            if slot == gearSlot then
                DebugPrint("Slot", ColorText(slot:GetID(), "Heirloom"), "is socketable (aux)")
                return true
            end
        end
    else
        DebugPrint(ColorText("AuxSocketableSlots not found in expansion info table", "Error"))
    end
    return false
end

---Indicates whether an item equipped in a particular gear slot can be enchanted or not
---@param slot Slot The gear slot to check for enchantable equipment
---@return boolean result `true` if the item can be enchanted, `false` otherwise
function AddOn:IsEnchantableSlot(slot)
    if self.CurrentExpac and self.CurrentExpac.EnchantableSlots then
        for _, gearSlot in ipairs(self.CurrentExpac.EnchantableSlots) do
            if slot == gearSlot and slot == CharacterHeadSlot and GetInventoryItemID("player", slot:GetID()) then
                return self.CurrentExpac.HeadEnchantAvailable
            elseif slot == gearSlot and slot == CharacterSecondaryHandSlot and GetInventoryItemID("player", slot:GetID()) then
                local itemClassID, itemSubclassID = select(6, C_Item.GetItemInfoInstant(GetInventoryItemID("player", slot:GetID())))
                local isShield = itemClassID == 4 and itemSubclassID == 6
                local isOffhand = itemClassID == 4 and itemSubclassID == 0
                if isShield and self.CurrentExpac.ShieldEnchantAvailable then
                    return true
                elseif isShield then
                    return false
                elseif isOffhand and self.CurrentExpac.OffhandEnchantAvailable then
                    return true
                elseif isOffhand then
                    return false
                end
            end
            if slot == gearSlot then
                DebugPrint("Slot", ColorText(slot:GetID(), "Heirloom"), "is enchantable")
                return true
            end
        end
    else
        DebugPrint(ColorText("EnchantableSlots not found in expansion info table", "Error"))
    end
    return false
end

---Indicates whether a gear slot is positioned to the left of the character model in the default Character Info window or not
---@param slot Slot The gear slot to check
---@return boolean|nil result Returns `nil` if the slot is for a weapon or off-hand item, `true` if the slot is to the left of the character model, and `false` otherwise
function AddOn:GetSlotIsLeftSide(slot)
    return slot.IsLeftSide
end

---Abbreviates `text` using the provided `replacementTable`
---@param text string The text to abbreviate
---@param replacementTable TextReplacement[] A table containing mappings for how to replace text
---@return string abbreviation The abbreviated version of `text` as per the entries in `replacementTable`
function AddOn:AbbreviateText(text, replacementTable)
    if not text then return "" end
    if not replacementTable or next(replacementTable) == nil then return text end
    local abbreviation = text
    for _, repl in pairs(replacementTable) do
        abbreviation = abbreviation:gsub(repl.original, repl.replacement)
    end
    return abbreviation
end

