local addonName, AddOn = ...
---@class muteCatCF: AceAddon, AceConsole-3.0, AceEvent-3.0
AddOn = LibStub("AceAddon-3.0"):GetAddon(addonName)
local L = LibStub("AceLocale-3.0"):GetLocale(addonName, true)

local DebugPrint = AddOn.DebugPrint
local ColorText = AddOn.ColorText

local function GetTooltipLinesCached(self, itemLink)
    if not itemLink or itemLink == "" then
        return nil
    end

    self._tooltipLineCache = self._tooltipLineCache or {}
    local cached = self._tooltipLineCache[itemLink]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end

    local tooltip = C_TooltipInfo.GetHyperlink(itemLink)
    local lines = tooltip and tooltip.lines or nil
    self._tooltipLineCache[itemLink] = lines or false
    return lines
end

local function IsUpgradeTrackLine(text)
    if not text or text == "" then return false end
    return text:find(L["Upgrade Level: "], 1, true)
        or text:find(L["Explorer "], 1, true)
        or text:find(L["Adventurer "], 1, true)
        or text:find(L["Veteran "], 1, true)
        or text:find(L["Champion "], 1, true)
        or text:find(L["Hero "], 1, true)
        or text:find(L["Myth "], 1, true)
end

local function IsMaxUpgradeTrackProgress(text)
    if not text or text == "" then return false end
    local current, max = text:match("(%d+)%s*/%s*(%d+)")
    if not current or not max then return false end
    return tonumber(current) == tonumber(max) and tonumber(max) > 0
end

---Fetches and formats the item level for an item in the defined gear slot (if one exists)
---@param slot Slot The gear slot to get item level for
function AddOn:GetItemLevelBySlot(slot)
    local hasItem, item = self:IsItemEquippedInSlot(slot)
    if hasItem then
        local itemLevel = item:GetCurrentItemLevel()
        if itemLevel > 0 then -- positive value indicates item info has loaded
            local iLvlText = tostring(itemLevel)
            if self.db.profile.useGradientColorsForILvl then
                local equippedItemLevel = self._equippedAvgItemLevel or select(2, GetAverageItemLevel())
                local color = (itemLevel < equippedItemLevel - 10 and "Error"
                    or itemLevel > equippedItemLevel + 10 and "Uncommon"
                    or "Info")
                iLvlText = ColorText(iLvlText, color)
            elseif self.db.profile.useQualityColorForILvl then
                local qualityHex = select(4, C_Item.GetItemQualityColor(item:GetItemQuality()))
                iLvlText = "|c"..qualityHex..iLvlText.."|r"
            elseif self.db.profile.useClassColorForILvl then
                local classHexWithAlpha = self:GetPlayerClassColorHexWithAlpha()
                if classHexWithAlpha then
                    iLvlText = "|c"..classHexWithAlpha..iLvlText.."|r"
                end
            elseif self.db.profile.useCustomColorForILvl then
                iLvlText = ColorText(iLvlText, self.db.profile.iLvlCustomColor)
            end

            DebugPrint("Item Level text for slot", ColorText(slot:GetID(), "Heirloom"), "=", iLvlText)
            slot.muteCatItemLevel:SetFormattedText(iLvlText)
            slot.muteCatItemLevel:Show()
        else
            DebugPrint("Item Level less than 0 found, retry self:GetItemLevelBySlot for slot", ColorText(slot:GetID(), "Heirloom"))
            C_Timer.After(0.5, function() self:GetItemLevelBySlot(slot) end)
        end
    end
end

---Fetches and formats the upgrade track for an item in the defined gear slot (if one exists)
---@param slot Slot The gear slot to get item level for
function AddOn:GetUpgradeTrackBySlot(slot)
    local isCharacterMaxLevel = self:IsPlayerMaxLevel()
    if not isCharacterMaxLevel then
        if slot.muteCatUpgradeTrack then slot.muteCatUpgradeTrack:Hide() end
        return
    end

    local hasItem, item = self:IsItemEquippedInSlot(slot)
    if hasItem then
        local upgradeTrackText = ""
        local lines = GetTooltipLinesCached(self, item:GetItemLink())
        if lines then
            for _, ttdata in ipairs(lines) do
                local leftText = ttdata and ttdata.leftText
                local isUpgradeTrack = leftText and IsUpgradeTrackLine(leftText)
                if ttdata and isUpgradeTrack then
                    local upgradeText = ttdata.leftText
                    upgradeText = self:AbbreviateText(upgradeText, self.UpgradeTextReplacements)
                    upgradeTrackText = upgradeText
                    DebugPrint("Upgrade track for item", ColorText(slot:GetID(), "Heirloom"), "=", upgradeText)
                    break
                end
            end
        end

        if upgradeTrackText ~= "" and not IsMaxUpgradeTrackProgress(upgradeTrackText) then
            local upgradeColor
            if self.db.profile.useQualityScaleColorsForUpgradeTrack then
                if upgradeTrackText:match("E") or upgradeTrackText:match("A") then
                    upgradeColor = self.HexColorPresets.Priest
                elseif upgradeTrackText:match("V") then
                    upgradeColor = self.HexColorPresets.Uncommon
                elseif upgradeTrackText:match("C") then
                    upgradeColor = self.HexColorPresets.Rare
                elseif upgradeTrackText:match("H") then
                    upgradeColor = self.HexColorPresets.Epic
                elseif upgradeTrackText:match("M") then
                    upgradeColor = self.HexColorPresets.Legendary
                else
                    local qualityHex = select(4, C_Item.GetItemQualityColor(item:GetItemQuality()))
                    upgradeColor = qualityHex and qualityHex:sub(3) or self.HexColorPresets.Info
                end
            elseif self.db.profile.useCustomColorForUpgradeTrack then
                upgradeColor = self.db.profile.upgradeTrackCustomColor
            else
                local qualityHex = select(4, C_Item.GetItemQualityColor(item:GetItemQuality()))
                upgradeColor = qualityHex and qualityHex:sub(3) or self.HexColorPresets.Info
            end
            slot.muteCatUpgradeTrack:SetFormattedText(ColorText(upgradeTrackText, upgradeColor))
            slot.muteCatUpgradeTrack:Show()
        end
    end
end

---Fetches and formats the gems currently socketed for an item in the defined gear slot (if one exists).
---If sockets are empty/can be addded to the item and the option to show missing sockets is enabled, these will also be indicated in the formatted text.
---@param slot Slot The gear slot to get gem information for
function AddOn:GetGemsBySlot(slot)
    local isCharacterMaxLevel = self:IsPlayerMaxLevel()
    if not isCharacterMaxLevel then
        if slot.muteCatGems then slot.muteCatGems:Hide() end
        return
    end

    local hasItem, item = self:IsItemEquippedInSlot(slot)
    local isSocketableSlot = self:IsSocketableSlot(slot)
    local isAuxSocketableSlot = self:IsAuxSocketableSlot(slot)
    if hasItem and (isSocketableSlot or isAuxSocketableSlot) then
        local existingSocketCount = 0
        local gemText = ""
        local IsLeftSide = self:GetSlotIsLeftSide(slot)
        local lines = GetTooltipLinesCached(self, item:GetItemLink())
        if lines then
            for _, ttdata in ipairs(lines) do
                if ttdata and ttdata.type and ttdata.type == self.TooltipDataType.Gem then
                    -- Socketed item will have gemIcon variable
                    if ttdata.gemIcon and IsLeftSide then
                        DebugPrint("Found Gem Icon on left side slot:", ColorText(slot:GetID(), "Heirloom"), ttdata.gemIcon, self.GetTextureString(ttdata.gemIcon))
                        gemText = gemText..self.GetTextureString(ttdata.gemIcon)
                    elseif ttdata.gemIcon then
                        DebugPrint("Found Gem Icon:", ColorText(slot:GetID(), "Heirloom"), ttdata.gemIcon, self.GetTextureString(ttdata.gemIcon))
                        gemText = self.GetTextureString(ttdata.gemIcon)..gemText
                    -- Two conditions below check for tinker sockets
                    elseif ttdata.socketType and IsLeftSide then
                        DebugPrint("Empty tinker socket for in slot on left side:", ColorText(slot:GetID(), "Heirloom"), self.GetTextureString("Interface/ItemSocketingFrame/UI-EmptySocket-"..ttdata.socketType))
                        gemText = gemText..self.GetTextureString("Interface/ItemSocketingFrame/UI-EmptySocket-"..ttdata.socketType)
                    elseif ttdata.socketType then
                        DebugPrint("Empty tinker socket found in slot:", ColorText(slot:GetID(), "Heirloom"), self.GetTextureString("Interface/ItemSocketingFrame/UI-EmptySocket-"..ttdata.socketType))
                        gemText = self.GetTextureString("Interface/ItemSocketingFrame/UI-EmptySocket-"..ttdata.socketType)..gemText
                    -- The two conditions below indicate that there is an empty socket on the item
                    elseif IsLeftSide then
                        DebugPrint("Empty socket found in slot on left side:", ColorText(slot:GetID(), "Heirloom"), self.GetTextureString(458977))
                        -- Texture: Interface/ItemSocketingFrame/UI-EmptySocket-Prismatic
                        gemText = gemText..self.GetTextureString(458977)
                    else
                        DebugPrint("Empty socket found in slot:", ColorText(slot:GetID(), "Heirloom"), self.GetTextureString(458977))
                        gemText = self.GetTextureString(458977)..gemText
                    end
                    existingSocketCount = existingSocketCount + 1
                end
            end
        end

        -- Indicates slots that can have sockets added to them
        local showGems = self:ShouldShowGems()
        if showGems and self.db.profile.showMissingGems and isSocketableSlot and existingSocketCount < self.CurrentExpac.MaxSocketsPerItem then
            if (self.db.profile.missingGemsMaxLevelOnly and isCharacterMaxLevel) or not self.db.profile.missingGemsMaxLevelOnly then
                for i = 1, self.CurrentExpac.MaxSocketsPerItem - existingSocketCount, 1 do
                    DebugPrint("Slot", ColorText(slot:GetID(), "Heirloom"), "can add", i, i == 1 and "socket" or "sockets")
                    gemText = IsLeftSide and gemText..self.GetTextureAtlasString("Socket-Prismatic-Closed") or self.GetTextureAtlasString("Socket-Prismatic-Closed")..gemText
                end
            end
        end
        if gemText ~= "" then
            slot.muteCatGems:SetFormattedText(gemText)
            slot.muteCatGems:Show()
        end
    end
end

---Fetches and formats the enchant details for an item in the defined gear slot (if one exists).
---If an item that can be enchanted isn't and the option to show missing enchants is enabled, this will also be indicated in the formatted text.
---@param slot Slot The gear slot to get gem information for
function AddOn:GetEnchantmentBySlot(slot)
    local isCharacterMaxLevel = self:IsPlayerMaxLevel()
    if not isCharacterMaxLevel then
        if slot.muteCatEnchant then slot.muteCatEnchant:Hide() end
        return
    end

    local hasItem, item = self:IsItemEquippedInSlot(slot)
    local isEnchantableSlot = self:IsEnchantableSlot(slot)
    if hasItem and isEnchantableSlot then
        local isEnchanted = false
        local locale = GetLocale()
        local lines = GetTooltipLinesCached(self, item:GetItemLink())
        if lines then
            for _, ttdata in ipairs(lines) do
                if ttdata and ttdata.type and ttdata.type == self.TooltipDataType.Enchant then
                    DebugPrint("Item in slot", ColorText(slot:GetID(), "Heirloom"), "is enchanted")
                    local enchText = ttdata.leftText
                    DebugPrint("Original enchantment text:", ColorText(enchText, "Uncommon"))
                    enchText = self:AbbreviateText(enchText, self.EnchantTextReplacements)
                    -- Perform locale replacements specific to ptBR to further shorten and fix some abbreviations
                    if locale == "ptBR" then enchText = self:AbbreviateText(enchText, self.ptbrEnchantTextReplacements)
                    elseif locale == "frFR" then enchText = self:AbbreviateText(enchText, self.frfrEnchantTextReplacements) end
                    -- Trim enchant text to remove leading and trailing whitespace
                    -- strtrim is a Blizzard-provided global utility function
                    enchText = strtrim(enchText)
                    -- Resize any textures in the enchantment text
                    local texture = enchText:match("|A:(.-):")
                    -- If no texture is found, the enchant could be an older/DK one.
                    -- If DK enchant, set texture based on the icon shown for each enchant in Runeforging
                    if not texture then
                        local textureID
                        if enchText == self.DKEnchantAbbr.Razorice then
                            textureID = 135842 -- Interface/Icons/Spell_Frost_FrostArmor
                        elseif enchText == self.DKEnchantAbbr.Sanguination then
                            textureID = 1778226 -- Interface/Icons/Ability_Argus_DeathFod
                        elseif enchText == self.DKEnchantAbbr.Spellwarding then
                            textureID = 425952 -- Interface/Icons/Spell_Fire_TwilightFireward
                        elseif enchText == self.DKEnchantAbbr.Apocalypse then
                            textureID = 237535 -- Interface/Icons/Spell_DeathKnight_Thrash_Ghoul
                        elseif enchText == self.DKEnchantAbbr.FallenCrusader then
                            textureID = 135957 -- Interface/Icons/Spell_Holy_RetributionAura
                        elseif enchText == self.DKEnchantAbbr.StoneskinGargoyle then
                            textureID = 237480 -- Interface/Icons/Inv_Sword_130
                        elseif enchText == self.DKEnchantAbbr.UnendingThirst then
                            textureID = 3163621 -- Interface/Icons/Spell_NZInsanity_Bloodthirst
                        else
                            textureID = 628564 -- Interface/Scenarios/ScenarioIcon-Check
                        end
                        texture = self.GetTextureString(textureID)
                        enchText = texture
                    else
                        enchText = self.GetTextureAtlasString(texture)
                    end
                    DebugPrint("Abbreviated enchantment text:", ColorText(enchText, "Uncommon"))
    
                    if self.db.profile.useCustomColorForEnchants then
                        slot.muteCatEnchant:SetFormattedText(ColorText(enchText, self.db.profile.enchCustomColor))
                    else
                        slot.muteCatEnchant:SetFormattedText(ColorText(enchText, "Uncommon"))
                    end
                    slot.muteCatEnchant:Show()
                    isEnchanted = true
                    break
                end
            end
        end

        if not isEnchanted and isEnchantableSlot and self.db.profile.showMissingEnchants then
            if (self.db.profile.missingEnchantsMaxLevelOnly and isCharacterMaxLevel) or not self.db.profile.missingEnchantsMaxLevelOnly then
                slot.muteCatEnchant:SetFormattedText(self.GetTextureString(523826))
                slot.muteCatEnchant:Show()
            end
        end
    end
end

---Fetches and formats embellishment details for an item in the defined gear slot (if one exists and is embellished)
---@param slot Slot The gear slot to get gem information for
function AddOn:ShowEmbellishmentBySlot(slot)
    if slot.muteCatEmbellishmentTexture then slot.muteCatEmbellishmentTexture:Hide() end
    if slot.muteCatEmbellishmentShadow then slot.muteCatEmbellishmentShadow:Hide() end
    local hasItem, item = self:IsItemEquippedInSlot(slot)
    if hasItem then
        local lines = GetTooltipLinesCached(self, item:GetItemLink())
        if lines then
            for _, ttdata in ipairs(lines) do
                if ttdata and ttdata.leftText:find("Embellished") then
                    -- Create shadow layer (semi-transparent black)
                    if not slot.muteCatEmbellishmentShadow then
                        slot.muteCatEmbellishmentShadow = slot:CreateTexture("muteCatEmbellishmentShadow"..slot:GetID(), "ARTWORK")
                    end
                    slot.muteCatEmbellishmentShadow:ClearAllPoints()
                    slot.muteCatEmbellishmentShadow:SetAllPoints(slot)
                    slot.muteCatEmbellishmentShadow:SetTexture("Interface/Buttons/WHITE8x8")
                    slot.muteCatEmbellishmentShadow:SetVertexColor(0, 0, 0, 0.3)
                    slot.muteCatEmbellishmentShadow:Show()

                    -- Main embellishment star (top layer)
                    if not slot.muteCatEmbellishmentTexture then
                        DebugPrint("Creating embellishment texture in slot", ColorText(slot:GetID(), "Heirloom"))
                        slot.muteCatEmbellishmentTexture = slot:CreateTexture("muteCatEmbellishmentTexture"..slot:GetID(), "OVERLAY")
                    end
                    slot.muteCatEmbellishmentTexture:SetSize(25, 25)
                    slot.muteCatEmbellishmentTexture:ClearAllPoints()
                    if self.db.profile.showiLvl and self.db.profile.iLvlOnItem then
                        slot.muteCatEmbellishmentTexture:SetPoint("BOTTOMLEFT", slot, "BOTTOMLEFT", 2, -7)
                    else
                        slot.muteCatEmbellishmentTexture:SetPoint("TOPLEFT", slot, "TOPLEFT", 0, 0)
                    end
                    slot.muteCatEmbellishmentTexture:SetTexture("Interface/LootFrame/Toast-Star")
                    slot.muteCatEmbellishmentTexture:SetVertexColor(0, 1, 0.6, 1)
                    DebugPrint("Showing embellishments enabled, embellishment found on slot |cFF00ccff"..slot:GetID().."|r")
                    slot.muteCatEmbellishmentTexture:Show()
                    break
                end
            end
        else
            DebugPrint("Tooltip information could not be obtained for slot |cFFc00ccff"..slot:GetID().."|r")
        end
    else
        DebugPrint("No item equipped in slot |cFF00ccff"..slot:GetID().."|r")
    end
end

