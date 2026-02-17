local addonName, AddOn = ...
---@class muteCatCF: AceAddon, AceConsole-3.0, AceEvent-3.0
AddOn = LibStub("AceAddon-3.0"):GetAddon(addonName)
local L = AddOn.L

local DebugPrint = AddOn.DebugPrint
local ColorText = AddOn.ColorText
local MAX_ITEMLEVEL_RETRIES = 6

local function HideRegion(region)
    if region then
        region:Hide()
    end
end

local function ClearItemLevelRetry(self, slotID)
    if self._pendingItemLevelRetry then
        self._pendingItemLevelRetry[slotID] = nil
    end
    if self._itemLevelRetryCount then
        self._itemLevelRetryCount[slotID] = nil
    end
end

---@param self muteCatCF
---@param region Region?
---@return boolean
local function IsPlayerMaxLevelOrHide(self, region)
    if self:IsPlayerMaxLevel() then
        return true
    end
    HideRegion(region)
    return false
end

local function GetTooltipLinesCached(self, itemLink)
    if not itemLink or itemLink == "" then
        return nil
    end

    self._tooltipLineCache = self._tooltipLineCache or {}
    self._tooltipCacheSize = self._tooltipCacheSize or 0
    local cached = self._tooltipLineCache[itemLink]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end

    -- Keep cache bounded to avoid step-wise memory growth on repeated open/close cycles.
    if self._tooltipCacheSize >= 128 then
        self._tooltipLineCache = {}
        self._tooltipCacheSize = 0
    end

    local tooltip = C_TooltipInfo.GetHyperlink(itemLink)
    local lines = tooltip and tooltip.lines or nil
    self._tooltipLineCache[itemLink] = lines or false
    self._tooltipCacheSize = self._tooltipCacheSize + 1
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

local function GetEnchantIDFromLink(itemLink)
    if not itemLink then return nil end
    -- Item Link Structure: item:itemID:enchantID:gemID1:gemID2:gemID3:gemID4:suffixID:uniqueID:linkLevel:specializationID:upgradeTypeID:instanceDifficultyID:numBonusIDs:bonusID1:bonusID2...
    local enchantID = itemLink:match("item:%d+:(%d+):")
    return tonumber(enchantID)
end



---@param trackText string
---@return string|nil
local function GetUpgradeTrackTierColor(self, trackText)
    if not trackText or trackText == "" then
        return nil
    end

    local tier = trackText:match("^%s*([EAVCHM])")
    if not tier then return nil end

    -- Lazy initialization of the lookup table
    if not self._upgradeTrackColorMap then
        self._upgradeTrackColorMap = {
            E = self.HexColorPresets.Priest,
            A = self.HexColorPresets.Priest,
            V = self.HexColorPresets.Uncommon,
            C = self.HexColorPresets.Rare,
            H = self.HexColorPresets.Epic,
            M = self.HexColorPresets.Legendary,
        }
    end

    return self._upgradeTrackColorMap[tier]
end

---Fetches and formats the item level for an item in the defined gear slot (if one exists)
---@param slot Slot The gear slot to get item level for
function AddOn:GetItemLevelBySlot(slot)
    local slotID = slot:GetID()
    local hasItem, item = self:IsItemEquippedInSlot(slot)
    if hasItem then
        local itemLevel = item:GetCurrentItemLevel() or 0

        if itemLevel > 0 then -- positive value indicates item info has loaded
            ClearItemLevelRetry(self, slotID)
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
            self._pendingItemLevelRetry = self._pendingItemLevelRetry or {}
            if self._pendingItemLevelRetry[slotID] then
                return
            end
            self._itemLevelRetryCount = self._itemLevelRetryCount or {}
            local retryCount = (self._itemLevelRetryCount[slotID] or 0) + 1
            self._itemLevelRetryCount[slotID] = retryCount
            if retryCount > MAX_ITEMLEVEL_RETRIES then
                DebugPrint("Item Level retry limit reached for slot", ColorText(slotID, "Heirloom"))
                self._pendingItemLevelRetry[slotID] = nil
                return
            end
            self._pendingItemLevelRetry[slotID] = true
            DebugPrint("Item Level not loaded yet, scheduling retry for slot", ColorText(slotID, "Heirloom"))
            C_Timer.After(0.5, function()
                if self._pendingItemLevelRetry then
                    self._pendingItemLevelRetry[slotID] = nil
                end
                if PaperDollFrame and PaperDollFrame:IsVisible() then
                    self:GetItemLevelBySlot(slot)
                end
            end)
        end
    else
        ClearItemLevelRetry(self, slotID)
    end
end

---Fetches and formats the upgrade track for an item in the defined gear slot (if one exists)
---@param slot Slot The gear slot to get item level for
function AddOn:GetUpgradeTrackBySlot(slot)
    self:EnsureTextReplacementTables()
    if not IsPlayerMaxLevelOrHide(self, slot.muteCatUpgradeTrack) then
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
            if self.db.profile.useCustomColorForUpgradeTrack then
                upgradeColor = self.db.profile.upgradeTrackCustomColor
            else
                -- Prefer deterministic track-tier coloring; fallback to item quality only when no tier is parsed.
                upgradeColor = GetUpgradeTrackTierColor(self, upgradeTrackText)
                if not upgradeColor then
                    local qualityHex = select(4, C_Item.GetItemQualityColor(item:GetItemQuality()))
                    upgradeColor = qualityHex and qualityHex:sub(3) or self.HexColorPresets.Info
                end
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
    if not IsPlayerMaxLevelOrHide(self, slot.muteCatGems) then
        return
    end

    local isCharacterMaxLevel = true
    local hasItem, item = self:IsItemEquippedInSlot(slot)
    local isSocketableSlot = self:IsSocketableSlot(slot)
    local isAuxSocketableSlot = self:IsAuxSocketableSlot(slot)
    if hasItem and (isSocketableSlot or isAuxSocketableSlot) then
        local existingSocketCount = 0
        local gemText = ""
        local isLeftSide = self:GetSlotIsLeftSide(slot)
        local lines = GetTooltipLinesCached(self, item:GetItemLink())
        if lines then
            for _, ttdata in ipairs(lines) do
                if ttdata and ttdata.type and ttdata.type == self.TooltipDataType.Gem then
                    -- Record discovered gem if applicable
                    if ttdata.gemIcon and ttdata.leftText then
                        self:SniffGem(ttdata.gemIcon, ttdata.leftText)
                    end
                    -- Socketed item will have gemIcon variable
                    local gemIconScale = self.db.profile.gemScale or 1
                    local gemIconSize = gemIconScale * 15
                    
                    if ttdata.gemIcon and isLeftSide then
                        DebugPrint("Found Gem Icon on left side slot:", ColorText(slot:GetID(), "Heirloom"), ttdata.gemIcon, self.GetTextureString(ttdata.gemIcon, gemIconSize))
                        gemText = gemText..self.GetTextureString(ttdata.gemIcon, gemIconSize)
                    elseif ttdata.gemIcon then
                        DebugPrint("Found Gem Icon:", ColorText(slot:GetID(), "Heirloom"), ttdata.gemIcon, self.GetTextureString(ttdata.gemIcon, gemIconSize))
                        gemText = self.GetTextureString(ttdata.gemIcon, gemIconSize)..gemText
                    -- Two conditions below check for tinker sockets
                    elseif ttdata.socketType and isLeftSide then
                        DebugPrint("Empty tinker socket for in slot on left side:", ColorText(slot:GetID(), "Heirloom"), self.GetTextureString("Interface/ItemSocketingFrame/UI-EmptySocket-"..ttdata.socketType, gemIconSize))
                        gemText = gemText..self.GetTextureString("Interface/ItemSocketingFrame/UI-EmptySocket-"..ttdata.socketType, gemIconSize)
                    elseif ttdata.socketType then
                        DebugPrint("Empty tinker socket found in slot:", ColorText(slot:GetID(), "Heirloom"), self.GetTextureString("Interface/ItemSocketingFrame/UI-EmptySocket-"..ttdata.socketType, gemIconSize))
                        gemText = self.GetTextureString("Interface/ItemSocketingFrame/UI-EmptySocket-"..ttdata.socketType, gemIconSize)..gemText
                    -- The two conditions below indicate that there is an empty socket on the item
                    elseif isLeftSide then
                        DebugPrint("Empty socket found in slot on left side:", ColorText(slot:GetID(), "Heirloom"), self.GetTextureString(458977, gemIconSize))
                        -- Texture: Interface/ItemSocketingFrame/UI-EmptySocket-Prismatic
                        gemText = gemText..self.GetTextureString(458977, gemIconSize)
                    else
                        DebugPrint("Empty socket found in slot:", ColorText(slot:GetID(), "Heirloom"), self.GetTextureString(458977, gemIconSize))
                        gemText = self.GetTextureString(458977, gemIconSize)..gemText
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
                    gemText = isLeftSide and gemText..self.GetTextureAtlasString("Socket-Prismatic-Closed") or self.GetTextureAtlasString("Socket-Prismatic-Closed")..gemText
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
    if not IsPlayerMaxLevelOrHide(self, slot.muteCatEnchant) then
        return
    end

    local isCharacterMaxLevel = true
    local hasItem, item = self:IsItemEquippedInSlot(slot)
    local isEnchantableSlot = self:IsEnchantableSlot(slot)
    if hasItem and isEnchantableSlot then
        local isEnchanted = false
        local lines = GetTooltipLinesCached(self, item:GetItemLink())
        if lines then
            for _, ttdata in ipairs(lines) do
                if ttdata and ttdata.type and ttdata.type == self.TooltipDataType.Enchant then
                     local texture
                    -- Always prioritize quality rank detection (Tier 1, 2, or 3) from the tooltip text
                    local qualityTier = ttdata.leftText and ttdata.leftText:match("Tier(%d)")
                    local enchIconSize = (self.db.profile.enchScale or 1) * 15 -- Back to standard base size
                    
                    if qualityTier then
                        texture = self.GetTextureAtlasString("Professions-Icon-Quality-Tier" .. qualityTier, enchIconSize)
                        DebugPrint("Enchant quality detected:", ColorText("Tier " .. qualityTier, "Heirloom"))
                    end

                    if not texture then
                        -- Falls kein Qualitätsrang gefunden wurde (Legacy), nutzen wir das Häkchen
                        texture = self.GetTextureString(628564, enchIconSize)
                    end
    
                    local color = self.db.profile.useCustomColorForEnchants and self.db.profile.enchCustomColor or "Uncommon"
                    slot.muteCatEnchant:SetFormattedText(ColorText(texture, color))
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


