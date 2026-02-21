--------------------------------------------------------------------------------
-- muteCat CF - RetrieveGearInfo
-- Core logic for scanning equipment tooltips and extracting iLvl, Gems, and Enchants.
--------------------------------------------------------------------------------

local addonName, AddOn = ...
---@class muteCatCF: AceAddon, AceConsole-3.0, AceEvent-3.0
AddOn = LibStub("AceAddon-3.0"):GetAddon(addonName)
local L = AddOn.L

-- Localization & Utilities
local DebugPrint = AddOn.DebugPrint
local ColorText = AddOn.ColorText

-- Optimization: Localize Blizzard Globals for performance in frequent update loops
local C_Item = _G.C_Item
local C_TooltipInfo = _G.C_TooltipInfo
local C_Timer = _G.C_Timer
local PaperDollFrame = _G.PaperDollFrame
local GetAverageItemLevel = _G.GetAverageItemLevel
local select = _G.select
local tonumber = _G.tonumber
local tostring = _G.tostring
local ipairs = _G.ipairs

-- Internal Constants
local MAX_ITEMLEVEL_RETRIES = 6

---Hides a UI region if it is currently shown.
---@param region Region?
local function HideRegion(region)
    if region and region.IsShown and region:IsShown() then
        region:Hide()
    end
end

---Clears the retry state for a specific slot ID.
---@param self muteCatCF
---@param slotID number
local function ClearItemLevelRetry(self, slotID)
    if self._pendingItemLevelRetry then self._pendingItemLevelRetry[slotID] = nil end
    if self._itemLevelRetryCount then self._itemLevelRetryCount[slotID] = nil end
end

---Checks if the player is at max level, otherwise hides the provided region.
---@param self muteCatCF
---@param region Region?
---@return boolean
local function IsPlayerMaxLevelOrHide(self, region)
    if self:IsPlayerMaxLevel() then return true end
    HideRegion(region)
    return false
end

---Retrieves and caches tooltip lines for a given item link.
---@param self muteCatCF
---@param itemLink string
---@return table|nil
local function GetTooltipLinesCached(self, itemLink)
    if not itemLink or itemLink == "" then return nil end

    self._tooltipLineCache = self._tooltipLineCache or {}
    self._tooltipCacheSize = self._tooltipCacheSize or 0
    local cached = self._tooltipLineCache[itemLink]
    if cached ~= nil then return cached ~= false and cached or nil end

    -- Purge cache if it gets too large (avoid memory leaks)
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

---Checks if a tooltip line indicates an upgrade track.
---@param text string?
---@return boolean
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

---Checks if an item is at its maximum upgrade progress.
---@param text string?
---@return boolean
local function IsMaxUpgradeTrackProgress(text)
    if not text or text == "" then return false end
    local current, max = text:match("(%d+)%s*/%s*(%d+)")
    if not current or not max then return false end
    return tonumber(current) == tonumber(max) and tonumber(max) > 0
end

---Extracts the enchantment ID from an item link using native Midnight patterns.
---@param itemLink string?
---@return number|nil
local function GetEnchantIDFromLink(itemLink)
    if not itemLink then return nil end
    local enchantID = itemLink:match("item:%d+:(%d+):")
    return tonumber(enchantID)
end

---Returns the hex color code for a specific upgrade track tier.
---@param self muteCatCF
---@param trackText string?
---@return string|nil
local function GetUpgradeTrackTierColor(self, trackText)
    if not trackText or trackText == "" then return nil end

    local tier = trackText:match("^%s*([EAVCHM])")
    if not tier then return nil end

    -- Lazy load color map
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

--------------------------------------------------------------------------------
-- Public API Functions
--------------------------------------------------------------------------------

---Retrieves and processes the item level for a slot.
---@param slot Slot
function AddOn:GetItemLevelBySlot(slot)
    local slotID = slot:GetID()
    local hasItem, item = self:IsItemEquippedInSlot(slot)
    if hasItem then
        local itemLevel = item:GetCurrentItemLevel() or 0

        if itemLevel > 0 then
            ClearItemLevelRetry(self, slotID)
            local iLvlText = tostring(itemLevel)
            
            -- Color Logic
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
                if classHexWithAlpha then iLvlText = "|c"..classHexWithAlpha..iLvlText.."|r" end
            elseif self.db.profile.useCustomColorForILvl then
                iLvlText = ColorText(iLvlText, self.db.profile.iLvlCustomColor)
            end

            -- Apply to Frame
            if slot.muteCatItemLevel:GetText() ~= iLvlText then
                slot.muteCatItemLevel:SetFormattedText(iLvlText)
            end
            if not slot.muteCatItemLevel:IsShown() then slot.muteCatItemLevel:Show() end
        else
            -- Async retry if item level is not yet available (Blizzard data delay)
            self._pendingItemLevelRetry = self._pendingItemLevelRetry or {}
            if self._pendingItemLevelRetry[slotID] then return end
            
            self._itemLevelRetryCount = self._itemLevelRetryCount or {}
            local retryCount = (self._itemLevelRetryCount[slotID] or 0) + 1
            self._itemLevelRetryCount[slotID] = retryCount
            
            if retryCount > MAX_ITEMLEVEL_RETRIES then
                self._pendingItemLevelRetry[slotID] = nil
                return
            end
            
            self._pendingItemLevelRetry[slotID] = true
            C_Timer.After(0.5, function()
                if self._pendingItemLevelRetry then self._pendingItemLevelRetry[slotID] = nil end
                if PaperDollFrame:IsVisible() then self:GetItemLevelBySlot(slot) end
            end)
        end
    else
        ClearItemLevelRetry(self, slotID)
    end
end

---Retrieves and processes the upgrade track info for a slot.
---@param slot Slot
function AddOn:GetUpgradeTrackBySlot(slot)
    self:EnsureTextReplacementTables()
    if not IsPlayerMaxLevelOrHide(self, slot.muteCatUpgradeTrack) then return end

    local hasItem, item = self:IsItemEquippedInSlot(slot)
    if hasItem then
        local upgradeTrackText = ""
        local itemLink = item:GetItemLink()
        if not itemLink then return end
        
        local lines = GetTooltipLinesCached(self, itemLink)
        if lines then
            for _, ttdata in ipairs(lines) do
                local leftText = ttdata and ttdata.leftText
                if leftText and IsUpgradeTrackLine(leftText) then
                    upgradeTrackText = self:AbbreviateText(leftText, self.UpgradeTextReplacements)
                    break
                end
            end
        end

        local isMaxed = IsMaxUpgradeTrackProgress(upgradeTrackText)
        if upgradeTrackText ~= "" and not isMaxed then
            local upgradeColor
            if self.db.profile.useCustomColorForUpgradeTrack then
                upgradeColor = self.db.profile.upgradeTrackCustomColor
            else
                upgradeColor = GetUpgradeTrackTierColor(self, upgradeTrackText)
                if not upgradeColor then
                    local qualityHex = select(4, C_Item.GetItemQualityColor(item:GetItemQuality()))
                    upgradeColor = qualityHex and qualityHex:sub(3) or self.HexColorPresets.Info
                end
            end
            
            local formattedText = ColorText(upgradeTrackText, upgradeColor)
            if slot.muteCatUpgradeTrack:GetText() ~= formattedText then
                slot.muteCatUpgradeTrack:SetFormattedText(formattedText)
            end
            if not slot.muteCatUpgradeTrack:IsShown() then slot.muteCatUpgradeTrack:Show() end
        else
            HideRegion(slot.muteCatUpgradeTrack)
        end
    else
        HideRegion(slot.muteCatUpgradeTrack)
    end
end

---Retrieves and processes gem/socket information for a slot.
---@param slot Slot
function AddOn:GetGemsBySlot(slot)
    if not IsPlayerMaxLevelOrHide(self, slot.muteCatGems) then return end

    local hasItem, item = self:IsItemEquippedInSlot(slot)
    local isSocketableSlot = self:IsSocketableSlot(slot)
    local isAuxSocketableSlot = self:IsAuxSocketableSlot(slot)

    if hasItem and (isSocketableSlot or isAuxSocketableSlot) then
        local gemText = ""
        local isLeftSide = slot.IsLeftSide
        local gemIconSize = (self.db.profile.gemScale or 1) * 15
        local existingSocketCount = 0
        local itemLink = item:GetItemLink()
        if not itemLink then return end
        
        local lines = GetTooltipLinesCached(self, itemLink)
        if lines then
            for _, ttdata in ipairs(lines) do
                if ttdata and ttdata.type == self.TooltipDataType.Gem then
                    if ttdata.gemIcon and ttdata.leftText then
                        self:SniffGem(ttdata.gemIcon, ttdata.leftText)
                    end
                    
                    local texture
                    if ttdata.gemIcon then
                        texture = self.GetTextureString(ttdata.gemIcon, gemIconSize)
                    elseif ttdata.socketType then
                        texture = self.GetTextureString("Interface/ItemSocketingFrame/UI-EmptySocket-"..ttdata.socketType, gemIconSize)
                    else
                        texture = self.GetTextureString(458977, gemIconSize) -- Generic empty socket
                    end
                    
                    gemText = isLeftSide and (gemText..texture) or (texture..gemText)
                    existingSocketCount = existingSocketCount + 1
                end
            end
        end

        -- Check for missing sockets on priority slots (Hals, Ringe)
        local showGems = self:ShouldShowGems()
        local slotID = slot:GetID()
        local isPrioritySocketSlot = (slotID == 2 or slotID == 11 or slotID == 12)

        if showGems and self.db.profile.showMissingGems and isPrioritySocketSlot then
            local maxExpected = self.CurrentExpac.MaxSocketsPerItem or 2
            if existingSocketCount < maxExpected then
                local texture = self.GetTextureAtlasString("Socket-Prismatic-Closed", gemIconSize)
                for i = 1, maxExpected - existingSocketCount do
                    gemText = isLeftSide and (gemText..texture) or (texture..gemText)
                end
            end
        end

        if gemText ~= "" then
            if slot.muteCatGems:GetText() ~= gemText then
                slot.muteCatGems:SetFormattedText(gemText)
            end
            if not slot.muteCatGems:IsShown() then slot.muteCatGems:Show() end
        else
            HideRegion(slot.muteCatGems)
        end
    else
        HideRegion(slot.muteCatGems)
    end
end

---Retrieves and processes enchantment information for a slot.
---@param slot Slot
function AddOn:GetEnchantmentBySlot(slot)
    if not IsPlayerMaxLevelOrHide(self, slot.muteCatEnchant) then return end

    local hasItem, item = self:IsItemEquippedInSlot(slot)
    local isEncSlot = self:IsEnchantableSlot(slot)
    
    if hasItem and isEncSlot then
        local itemLink = item:GetItemLink()
        if not itemLink then return end
        
        local enchantID = GetEnchantIDFromLink(itemLink)
        local texture
        local size = (self.db.profile.enchScale or 1) * 15

        -- Strategy 1: Use LibEnchantData (Midnight 12.0.1+ & DK Runes)
        if enchantID and self.LibEnchantData then
            local spellID = self.LibEnchantData:GetSpellID(enchantID)
            if spellID then
                texture = C_Spell.GetSpellTexture(spellID)
                if texture then
                    texture = self.GetTextureString(texture, size)
                end
            end
        end

        -- Strategy 2: Fallback to Tooltip "Quality Tier" icons (Legacy/Other Expansions)
        if not texture then
            local lines = GetTooltipLinesCached(self, itemLink)
            if lines then
                for _, ttdata in ipairs(lines) do
                    if ttdata and ttdata.type == self.TooltipDataType.Enchant then
                        local tier = ttdata.leftText and ttdata.leftText:match("Tier(%d)")
                        local qualityTier = tonumber(tier)
                        if qualityTier and qualityTier > 0 then
                            texture = self.GetTextureAtlasString("Professions-Icon-Quality-Tier" .. qualityTier, size)
                            break
                        elseif ttdata.leftText and ttdata.leftText:find(L["Enchanted"]) then
                            -- Generic enchanted string detection if no tier icon found
                            texture = self.GetTextureString(628564, size) -- Default Scroll
                        end
                    end
                end
            end
        end

        -- Strategy 3: Generic Placeholder for known Enchant IDs without Spell Mapping
        if not texture and (enchantID and enchantID > 0) then
            texture = self.GetTextureString(628564, size) -- Default Scroll
        end

        if texture then
            local color = self.db.profile.useCustomColorForEnchants and self.db.profile.enchCustomColor or "Uncommon"
            local formattedText = ColorText(texture, color)
            
            if slot.muteCatEnchant:GetText() ~= formattedText then
                slot.muteCatEnchant:SetFormattedText(formattedText)
            end
            if not slot.muteCatEnchant:IsShown() then slot.muteCatEnchant:Show() end
            return
        end

        -- Strategy 4: Show Missing Enchant Warning
        if self.db.profile.showMissingEnchants then
            local missingTexture = self.GetTextureString(523826)
            if slot.muteCatEnchant:GetText() ~= missingTexture then
                slot.muteCatEnchant:SetFormattedText(missingTexture)
            end
            if not slot.muteCatEnchant:IsShown() then slot.muteCatEnchant:Show() end
        else
            HideRegion(slot.muteCatEnchant)
        end
    else
        HideRegion(slot.muteCatEnchant)
    end
end
