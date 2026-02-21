--------------------------------------------------------------------------------
-- muteCat CF - Main Module
-- Displays gear information (iLvl, Upgrade Track, Gems, Enchants) in the
-- default Blizzard Character Frame.
--------------------------------------------------------------------------------

local addonName, AddOn = ...
---@class muteCatCF: AceAddon, AceConsole-3.0, AceEvent-3.0
AddOn = LibStub("AceAddon-3.0"):GetAddon(addonName)

-- Cache frequently used colors and util functions
local ColorText = AddOn.ColorText
local DebugPrint = AddOn.DebugPrint

-- Optimization: Localize Blizzard Globals
local C_Timer = _G.C_Timer
local PaperDollFrame = _G.PaperDollFrame
local CharacterFrame = _G.CharacterFrame
local GetAverageItemLevel = _G.GetAverageItemLevel
local UnitLevel = _G.UnitLevel
local GetInventoryItemLink = _G.GetInventoryItemLink
local PaperDollFrame_UpdateStats = _G.PaperDollFrame_UpdateStats
local PlayerGetTimerunningSeasonID = _G.PlayerGetTimerunningSeasonID
local GetTime = _G.GetTime

-- Configuration Constants
local FULL_REFRESH_SLOTS_PER_TICK = 4

---Checks if the PaperDollFrame is currently visible
---@return boolean
local function IsPaperDollVisible()
    return PaperDollFrame and PaperDollFrame:IsVisible()
end

---Hides a specific UI region
---@param region Region?
local function HideRegion(region)
    if region and region.IsShown and region:IsShown() then
        region:Hide()
    end
end

-- Default Database Settings
local DBDefaults = {
    profile = {
        showiLvl = true,
        showUpgradeTrack = true,
        showGems = true,
        showEnchants = true,
        debug = false,
        iLvlScale = 1,
        iLvlOutline = "OUTLINE",
        useQualityColorForILvl = true,
        useClassColorForILvl = false,
        useGradientColorsForILvl = false,
        useCustomColorForILvl = false,
        iLvlCustomColor = AddOn.HexColorPresets.Priest,
        upgradeTrackScale = 1,
        upgradeTrackOutline = "OUTLINE",
        useQualityScaleColorsForUpgradeTrack = false,
        useCustomColorForUpgradeTrack = false,
        upgradeTrackCustomColor = AddOn.HexColorPresets.Priest,
        gemScale = 1,
        showMissingGems = true,
        missingGemsMaxLevelOnly = true,
        enchScale = 1,
        enchantOutline = "OUTLINE",
        showMissingEnchants = true,
        missingEnchantsMaxLevelOnly = true,
        useCustomColorForEnchants = false,
        enchCustomColor = AddOn.HexColorPresets.Uncommon,
        iLvlOnItem = false,
        hideShirtTabardInfo = false,
        discoveredGems = {},
        tooltipCache = {}, -- Persistent session cache
    },
}

--------------------------------------------------------------------------------
-- Core Logic Functions
--------------------------------------------------------------------------------

---Check if the player is currently a MoP Remix 'Timerunner'
function AddOn:CheckIfTimerunner()
    local timerunningID = PlayerGetTimerunningSeasonID()
    self.IsTimerunner = timerunningID ~= nil
end

---Determine if gem information should be displayed
---@return boolean
function AddOn:ShouldShowGems()
    return self.db.profile.showGems and not self.IsTimerunner and self:IsPlayerMaxLevel()
end

---Determine if enchantment information should be displayed
---@return boolean
function AddOn:ShouldShowEnchants()
    return self.db.profile.showEnchants and not self.IsTimerunner and self:IsPlayerMaxLevel()
end

---Determine if upgrade track information should be displayed
---@return boolean
function AddOn:ShouldShowUpgradeTrack()
    return self.db.profile.showUpgradeTrack and not self.IsTimerunner and self:IsPlayerMaxLevel()
end

---Apply custom styling to character header and item level display
function AddOn:ApplyHeaderStyling()
    if not IsPaperDollVisible() then return end
    self:StyleBlizzardItemLevelClassColor()
    self:StyleCharacterHeaderClassColor()
    self:LayoutCharacterHeaderLevelOnly()
end

-- Static callback to avoid closure allocation
local function HeaderStyleCallback()
    AddOn._headerStyleQueued = false
    if IsPaperDollVisible() then
        AddOn:ApplyHeaderStyling()
    end
end

---Queue header restyling to the next frame
function AddOn:QueueHeaderStyling()
    if self._headerStyleQueued then return end
    self._headerStyleQueued = true
    C_Timer.After(0, HeaderStyleCallback)
end

---Capture the current state of a FontString for change detection
---@param fs FontString?
---@return boolean|nil shown, string|nil text
local function CaptureFontStringState(fs)
    if not fs then return nil, nil end
    return fs:IsShown(), fs:GetText()
end

---Detection logic to see if slot visual state actually changed
---@param slot Slot
---@return boolean
function AddOn:DidSlotVisualStateChange(slot, ilvlShownBefore, ilvlTextBefore, trackShownBefore, trackTextBefore, gemShownBefore, gemTextBefore, enchShownBefore, enchTextBefore)
    local ilvlShownAfter, ilvlTextAfter = CaptureFontStringState(slot.muteCatItemLevel)
    local trackShownAfter, trackTextAfter = CaptureFontStringState(slot.muteCatUpgradeTrack)
    local gemShownAfter, gemTextAfter = CaptureFontStringState(slot.muteCatGems)
    local enchShownAfter, enchTextAfter = CaptureFontStringState(slot.muteCatEnchant)
    
    return ilvlShownBefore ~= ilvlShownAfter
        or (ilvlShownAfter and ilvlTextBefore ~= ilvlTextAfter)
        or trackShownBefore ~= trackShownAfter
        or (trackShownAfter and trackTextBefore ~= trackTextAfter)
        or gemShownBefore ~= gemShownAfter
        or (gemShownAfter and gemTextBefore ~= gemTextAfter)
        or enchShownBefore ~= enchShownAfter
        or (enchShownAfter and enchTextBefore ~= enchTextAfter)
end

--------------------------------------------------------------------------------
-- Event Management
--------------------------------------------------------------------------------

---Enable equipment monitoring
function AddOn:EnableGearEvents()
    if self._gearEventsActive then return end
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "HandleEquipmentOrSettingsChange")
    self:RegisterEvent("SOCKET_INFO_ACCEPT", "HandleEquipmentOrSettingsChange")
    self._gearEventsActive = true
end

---Disable equipment monitoring and clear temporary state
function AddOn:DisableGearEvents()
    if self._gearEventsActive then
        self:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
        self:UnregisterEvent("SOCKET_INFO_ACCEPT")
        self._gearEventsActive = false
    end

    -- Cancel any active refresh tickers
    if self._fullRefreshTicker then
        self._fullRefreshTicker:Cancel()
        self._fullRefreshTicker = nil
    end
    if self._slotUpdateTicker then
        self._slotUpdateTicker:Cancel()
        self._slotUpdateTicker = nil
    end

    self._pendingItemLevelRetry = {}
    self._itemLevelRetryCount = {}
    self._pendingSlotUpdates = {}
    self._itemMixinCache = {}
    self._slotUpdateQueued = false
    self._fullRefreshQueued = false
    self._fullRefreshIndex = 1
end

---Handle equipment changes or setting updates by queuing refreshes.
---@param event string
---@param slotID number?
function AddOn:HandleEquipmentOrSettingsChange(event, slotID)
    self._equipmentChangedSinceLastRefresh = true
    if slotID and type(slotID) == "number" then
        self:InvalidateTooltipCacheForSlot(slotID)
        self:QueueSlotButtonUpdate(slotID)
        -- Ensure batched state and header logic stay in sync for rapid multi-slot changes.
        self:QueueFullGearRefresh()
    else
        self:ClearTooltipCache()
        self:QueueFullGearRefresh()
    end
end

--------------------------------------------------------------------------------
-- Gear Info Processing
--------------------------------------------------------------------------------

---Get or create a cached ItemMixin for a slot
---@param slotID number
---@return ItemMixin
function AddOn:GetCachedItemMixin(slotID)
    self._itemMixinCache = self._itemMixinCache or {}
    local item = self._itemMixinCache[slotID]
    if not item then
        item = Item:CreateFromEquipmentSlot(slotID)
        self._itemMixinCache[slotID] = item
    end
    return item
end

---Get a map of GearSlots indexed by their SlotID
---@return table<number, Slot>
function AddOn:GetGearSlotsByID()
    if self._gearSlotsByID then return self._gearSlotsByID end

    self._gearSlotsByID = {}
    if self.GearSlots then
        for _, slot in ipairs(self.GearSlots) do
            self._gearSlotsByID[slot:GetID()] = slot
        end
    end
    return self._gearSlotsByID
end

-- Reusable context table for updates to minimize GC pressure
local reusableCtx = {}

---Construct a context object for gear slot updates
---@return table
function AddOn:GetGearUpdateContext()
    local profile = self.db.profile
    self._equippedAvgItemLevel = profile.useGradientColorsForILvl and select(2, GetAverageItemLevel()) or nil

    wipe(reusableCtx)
    reusableCtx.profile = profile
    reusableCtx.showItemLevel = profile.showiLvl
    reusableCtx.showUpgradeTrack = self:ShouldShowUpgradeTrack()
    reusableCtx.showGems = self:ShouldShowGems()
    reusableCtx.showEnchants = self:ShouldShowEnchants()

    reusableCtx.hideShirtTabardInfo = profile.hideShirtTabardInfo
    reusableCtx.iLvlTextScale = (profile.iLvlScale and profile.iLvlScale > 0) and profile.iLvlScale or 1
    reusableCtx.upgradeTrackTextScale = ((profile.upgradeTrackScale and profile.upgradeTrackScale > 0) and profile.upgradeTrackScale or 1) * 0.9
    reusableCtx.gemScale = (profile.gemScale and profile.gemScale > 0) and profile.gemScale or 1
    reusableCtx.enchTextScale = ((profile.enchScale and profile.enchScale > 0) and profile.enchScale or 1) * 0.9
    
    return reusableCtx
end

---Perform a full update for a single gear slot
---@param slot Slot
---@param ctx table update context
---@return boolean changed whether visual state changed
function AddOn:UpdateGearSlot(slot, ctx)
    local slotID = slot:GetID()
    local itemLink = GetInventoryItemLink("player", slotID) or "empty"
    local now = GetTime()

    -- Deduplication: Avoid double-processing if NOTHING changed
    if slot._lastMuteCatLink == itemLink then
        return false 
    end
    
    -- If link has actually changed, reset state
    slot._lastMuteCatLink = itemLink
    slot._lastMuteCatUpdate = now

    local ilvlShownBefore, ilvlTextBefore = CaptureFontStringState(slot.muteCatItemLevel)
    local trackShownBefore, trackTextBefore = CaptureFontStringState(slot.muteCatUpgradeTrack)
    local gemShownBefore, gemTextBefore = CaptureFontStringState(slot.muteCatGems)
    local enchShownBefore, enchTextBefore = CaptureFontStringState(slot.muteCatEnchant)

    local profile = ctx.profile

    -- 1. Item Level
    if ctx.showItemLevel then
        if not slot.muteCatItemLevel then
            slot.muteCatItemLevel = slot:CreateFontString("muteCatItemLevel"..slotID, "OVERLAY", "GameTooltipText")
        end
        
        local outline = profile.iLvlOutline or "OUTLINE"
        if slot.muteCatItemLevel.lastOutline ~= outline or slot.muteCatItemLevel.lastScale ~= ctx.iLvlTextScale then
            local iFont, iSize = slot.muteCatItemLevel:GetFont()
            slot.muteCatItemLevel:SetFont(iFont, iSize, outline)
            slot.muteCatItemLevel:SetTextScale(ctx.iLvlTextScale)
            slot.muteCatItemLevel.lastOutline = outline
            slot.muteCatItemLevel.lastScale = ctx.iLvlTextScale
        end

        self:GetItemLevelBySlot(slot)
    elseif slot.muteCatItemLevel and slot.muteCatItemLevel:IsShown() then
        slot.muteCatItemLevel:Hide()
    end

    -- 2. Upgrade Track
    if ctx.showUpgradeTrack then
        if not slot.muteCatUpgradeTrack then
            slot.muteCatUpgradeTrack = slot:CreateFontString("muteCatUpgradeTrack"..slotID, "OVERLAY", "GameTooltipText")
        end
        
        local outline = profile.upgradeTrackOutline or "OUTLINE"
        if slot.muteCatUpgradeTrack.lastOutline ~= outline or slot.muteCatUpgradeTrack.lastScale ~= ctx.upgradeTrackTextScale then
            local uFont, uSize = slot.muteCatUpgradeTrack:GetFont()
            slot.muteCatUpgradeTrack:SetFont(uFont, uSize, outline)
            slot.muteCatUpgradeTrack:SetTextScale(ctx.upgradeTrackTextScale)
            slot.muteCatUpgradeTrack.lastOutline = outline
            slot.muteCatUpgradeTrack.lastScale = ctx.upgradeTrackTextScale
        end

        self:GetUpgradeTrackBySlot(slot)
    elseif slot.muteCatUpgradeTrack and slot.muteCatUpgradeTrack:IsShown() then
        slot.muteCatUpgradeTrack:Hide()
    end

    -- 3. Gems
    if ctx.showGems then
        if not slot.muteCatGems then
            slot.muteCatGems = slot:CreateFontString("muteCatGems"..slotID, "OVERLAY", "GameTooltipText")
        end
        if slot.muteCatGems.lastScale ~= ctx.gemScale then
            slot.muteCatGems:SetTextScale(ctx.gemScale)
            slot.muteCatGems.lastScale = ctx.gemScale
        end

        self:GetGemsBySlot(slot)
    elseif slot.muteCatGems and slot.muteCatGems:IsShown() then
        slot.muteCatGems:Hide()
    end

    -- 4. Enchants
    if ctx.showEnchants then
        if not slot.muteCatEnchant then
            slot.muteCatEnchant = slot:CreateFontString("muteCatEnchant"..slotID, "OVERLAY", "GameTooltipText")
        end
        
        local outline = profile.enchantOutline or "OUTLINE"
        if slot.muteCatEnchant.lastOutline ~= outline or slot.muteCatEnchant.lastScale ~= ctx.enchTextScale then
            local eFont, eSize = slot.muteCatEnchant:GetFont()
            slot.muteCatEnchant:SetFont(eFont, eSize, outline)
            slot.muteCatEnchant:SetTextScale(ctx.enchTextScale)
            slot.muteCatEnchant.lastOutline = outline
            slot.muteCatEnchant.lastScale = ctx.enchTextScale
        end

        self:GetEnchantmentBySlot(slot)
    elseif slot.muteCatEnchant and slot.muteCatEnchant:IsShown() then
        slot.muteCatEnchant:Hide()
    end

    -- Hide specific info for Shirt/Tabard if configured
    if ctx.hideShirtTabardInfo and (slotID == 4 or slotID == 19) then
        HideRegion(slot.muteCatItemLevel)
        HideRegion(slot.muteCatGems)
        HideRegion(slot.muteCatEnchant)
    end

    -- Re-position elements
    self:UpdateSlotLayout(slot)

    return self:DidSlotVisualStateChange(slot, ilvlShownBefore, ilvlTextBefore, trackShownBefore, trackTextBefore, gemShownBefore, gemTextBefore, enchShownBefore, enchTextBefore)
end

---Update a specific set of gear slots
---@param slotIDs table<number, boolean>
function AddOn:UpdateSelectedGearSlots(slotIDs)
    if not IsPaperDollVisible() then return end

    local slotsByID = self:GetGearSlotsByID()
    local ctx = self:GetGearUpdateContext()

    for slotID in pairs(slotIDs) do
        local slot = slotsByID[slotID]
        if slot then
            self:UpdateGearSlot(slot, ctx)
        end
    end
end

---Queue a gear info update for a specific slot or all slots
---@param slotID number?
function AddOn:QueueGearInfoUpdate(slotID)
    if not IsPaperDollVisible() then return end

    if slotID == nil then
        self:QueueFullGearRefresh()
        return
    end

    self:UpdateSelectedGearSlots({ [slotID] = true })
end

---Queue a full refresh of all equipment slots
function AddOn:QueueFullGearRefresh()
    if not IsPaperDollVisible() or not self.GearSlots then return end

    -- Throttle full refreshes to once per second unless equipment changed
    local now = GetTime()
    if self._lastFullRefreshTime and (now - self._lastFullRefreshTime < 1.0) and not self._equipmentChangedSinceLastRefresh then
        return
    end
    self._lastFullRefreshTime = now
    self._equipmentChangedSinceLastRefresh = false

    if not self._fullRefreshSlotList or #self._fullRefreshSlotList == 0 then
        self._fullRefreshSlotList = {}
        for _, slot in ipairs(self.GearSlots) do
            self._fullRefreshSlotList[#self._fullRefreshSlotList + 1] = slot:GetID()
        end
    end

    self._fullRefreshIndex = 1
    if self._fullRefreshQueued then return end

    self._fullRefreshQueued = true
    -- Use a properly tracked ticker to avoid stacking
    if self._fullRefreshTicker then self._fullRefreshTicker:Cancel() end
    self._fullRefreshTicker = C_Timer.NewTimer(0, function() self:ProcessQueuedFullGearRefresh() end)
end

---Execute the queued full refresh in batches to avoid CPU spikes
function AddOn:ProcessQueuedFullGearRefresh()
    self._fullRefreshTicker = nil
    if not IsPaperDollVisible() then 
        self._fullRefreshQueued = false
        return 
    end

    local slotList = self._fullRefreshSlotList
    local idx = self._fullRefreshIndex or 1
    if not slotList or idx > #slotList then
        self._fullRefreshQueued = false
        self:QueueHeaderStyling()
        return
    end

    local slotsByID = self:GetGearSlotsByID()
    local ctx = self:GetGearUpdateContext()
    local endIdx = math.min(idx + FULL_REFRESH_SLOTS_PER_TICK - 1, #slotList)

    for i = idx, endIdx do
        local slotID = slotList[i]
        local slot = slotsByID[slotID]
        if slot then self:UpdateGearSlot(slot, ctx) end
    end

    self._fullRefreshIndex = endIdx + 1
    if self._fullRefreshIndex <= #slotList then
        -- Continue the chain
        self._fullRefreshTicker = C_Timer.NewTimer(0.01, function() self:ProcessQueuedFullGearRefresh() end)
    else
        self._fullRefreshQueued = false
        self:QueueHeaderStyling()
    end
end

---Queue a slot button update for a specific slot
---@param slotID number
function AddOn:QueueSlotButtonUpdate(slotID)
    if not IsPaperDollVisible() or not slotID then return end

    self._pendingSlotUpdates = self._pendingSlotUpdates or {}
    self._pendingSlotUpdates[slotID] = true

    if self._slotUpdateQueued then return end

    self._slotUpdateQueued = true
    
    if self._slotUpdateTicker then self._slotUpdateTicker:Cancel() end
    self._slotUpdateTicker = C_Timer.NewTimer(0.1, function()
        self._slotUpdateTicker = nil
        self._slotUpdateQueued = false
        if not IsPaperDollVisible() then
            self._pendingSlotUpdates = {}
            return
        end

        local pending = self._pendingSlotUpdates
        self._pendingSlotUpdates = {}
        if not pending or not next(pending) then return end

        self:CheckIfTimerunner()
        self:UpdateSelectedGearSlots(pending)
    end)
end

--------------------------------------------------------------------------------
-- Tooltip Cache Management
--------------------------------------------------------------------------------

---Clear the entire tooltip line cache
function AddOn:ClearTooltipCache()
    self._tooltipLineCache = {}
    self._tooltipCacheSize = 0
end

---Invalidate the tooltip cache for a specific slot
---@param slotID number
function AddOn:InvalidateTooltipCacheForSlot(slotID)
    if type(slotID) ~= "number" or slotID <= 0 then
        self:ClearTooltipCache()
        return
    end

    local slots = self:GetGearSlotsByID()
    local slot = slots and slots[slotID]
    if slot and slot._lastMuteCatLink then
        self._tooltipLineCache[slot._lastMuteCatLink] = nil
    end

    local currentLink = GetInventoryItemLink("player", slotID)
    if currentLink then self._tooltipLineCache[currentLink] = nil end
end

-- Reusable table for candidates to avoid per-call allocation
local _itemLevelCandidates = {}

---Applies class color and outline to Blizzard's default item level display.
function AddOn:StyleBlizzardItemLevelClassColor()
    local statsPane = _G.CharacterStatsPane
    if not statsPane then return end

    local itemLevelFrame = statsPane.ItemLevelFrame or _G.CharacterStatsPaneItemLevelFrame or _G.PaperDollFrameItemLevelFrame
    if not itemLevelFrame then return end

    local r, g, b = self:GetPlayerClassColorRGB()
    if not r or not g or not b then return end

    wipe(_itemLevelCandidates)
    _itemLevelCandidates[1] = itemLevelFrame.Value
    _itemLevelCandidates[2] = itemLevelFrame.ItemLevel
    _itemLevelCandidates[3] = itemLevelFrame.ValueText
    _itemLevelCandidates[4] = itemLevelFrame.AvgItemLevel
    _itemLevelCandidates[5] = _G.CharacterStatsPaneItemLevelFrameValue
    _itemLevelCandidates[6] = _G.CharacterStatsPaneItemLevelFrameValueText
    _itemLevelCandidates[7] = _G.CharacterStatsPaneItemLevelFrameItemLevel

    for i = 1, 7 do
        local fs = _itemLevelCandidates[i]
        if fs and fs.SetTextColor then
            fs:SetTextColor(r, g, b)
            local fontPath, fontSize, fontOutline = fs:GetFont()
            if fontPath and fontSize and fontOutline ~= "OUTLINE" then
                fs:SetFont(fontPath, fontSize, "OUTLINE")
            end
        end
    end
end

local _headerTitleCandidates = {}
---Applies class color and outline to the character frame title.
function AddOn:StyleCharacterHeaderClassColor()
    local r, g, b = self:GetPlayerClassColorRGB()
    if not r or not g or not b then return end

    wipe(_headerTitleCandidates)
    _headerTitleCandidates[1] = _G.CharacterFrameTitleText
    _headerTitleCandidates[2] = _G.PaperDollFrameTitleText

    for i = 1, 2 do
        local fs = _headerTitleCandidates[i]
        if fs and fs.SetTextColor then
            local cr, cg, cb = fs:GetTextColor()
            if math.abs(cr - r) > 0.01 or math.abs(cg - g) > 0.01 or math.abs(cb - b) > 0.01 then
                fs:SetTextColor(r, g, b)
            end
            local fontPath, fontSize, fontOutline = fs:GetFont()
            if fontPath and fontSize and fontOutline ~= "OUTLINE" then
                fs:SetFont(fontPath, fontSize, "OUTLINE")
            end
        end
    end
end

local _titleLookupCandidates = {}
local _hiddenSublineCandidates = {}

---Adjusts the character header to show only the player's level next to the title.
function AddOn:LayoutCharacterHeaderLevelOnly()
    local titleFS = _G.CharacterFrameTitleText
    if not titleFS then
        wipe(_titleLookupCandidates)
        _titleLookupCandidates[1] = _G.PaperDollFrameTitleText
        _titleLookupCandidates[2] = _G.CharacterFrameTitleManagerPaneTitleText
        _titleLookupCandidates[3] = _G.PaperDollFrameTitleManagerPaneTitleText
        
        for i = 1, 3 do
            local fs = _titleLookupCandidates[i]
            if fs and fs.GetText and fs:GetText() and fs:GetText() ~= "" then
                titleFS = fs
                break
            end
        end
    end
    if not titleFS then return end

    wipe(_hiddenSublineCandidates)
    _hiddenSublineCandidates[1] = _G.CharacterLevelText
    _hiddenSublineCandidates[2] = _G.CharacterFrameTitleManagerPaneLevelText
    _hiddenSublineCandidates[3] = _G.PaperDollFrameTitleManagerPaneLevelText
    _hiddenSublineCandidates[4] = _G.CharacterFrameTitleManagerPaneClassText
    _hiddenSublineCandidates[5] = _G.PaperDollFrameTitleManagerPaneClassText
    _hiddenSublineCandidates[6] = _G.CharacterFrameTitleManagerPaneClassAndLevelText
    _hiddenSublineCandidates[7] = _G.PaperDollFrameTitleManagerPaneClassAndLevelText
    _hiddenSublineCandidates[8] = _G.PaperDollFrameLevelText
    for i = 1, 8 do
        local fs = _hiddenSublineCandidates[i]
        if fs and fs.IsShown and fs:IsShown() then
            fs:Hide()
        end
    end

    if not self.muteCatHeaderLevelText then
        local parent = _G.CharacterFrameTitleText and _G.CharacterFrameTitleText:GetParent() or _G.CharacterFrame
        self.muteCatHeaderLevelText = parent:CreateFontString("muteCatHeaderLevelText", "OVERLAY", "GameFontNormal")
        self.muteCatHeaderLevelText:SetDrawLayer("OVERLAY", 7)
    end

    local levelFS = self.muteCatHeaderLevelText
    local fontPath, fontSize = titleFS:GetFont()
    if fontPath and fontSize then
        local lFont, lSize, lOutline = levelFS:GetFont()
        if lFont ~= fontPath or lSize ~= fontSize or lOutline ~= "OUTLINE" then
            levelFS:SetFont(fontPath, fontSize, "OUTLINE")
        end
    end

    local nr, ng, nb = 1, 0.82, 0
    if NORMAL_FONT_COLOR then
        nr, ng, nb = NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b
    end
    local cr, cg, cb = levelFS:GetTextColor()
    if math.abs(cr - nr) > 0.01 or math.abs(cg - ng) > 0.01 or math.abs(cb - nb) > 0.01 then
        levelFS:SetTextColor(nr, ng, nb)
    end

    local lvl = tostring(UnitLevel("player") or "")
    if levelFS:GetText() ~= lvl then
        levelFS:SetText(lvl)
    end
    
    local levelWidth = levelFS:GetStringWidth() or 0

    local point, relTo, relPoint, x, y = titleFS:GetPoint(1)
    if point and relTo and relPoint then
        local baseX = x or 0
        if titleFS.muteCatOrigX == nil then
            titleFS.muteCatOrigX = baseX
            titleFS.muteCatOrigY = y or 0
            titleFS.muteCatOrigPoint = point
            titleFS.muteCatOrigRelTo = relTo
            titleFS.muteCatOrigRelPoint = relPoint
        end

        local targetX = titleFS.muteCatOrigX + levelWidth + 3
        if math.abs(x - targetX) > 0.5 then
            titleFS:ClearAllPoints()
            titleFS:SetPoint(titleFS.muteCatOrigPoint, titleFS.muteCatOrigRelTo, titleFS.muteCatOrigRelPoint, targetX, titleFS.muteCatOrigY)
        end
    end

    levelFS:ClearAllPoints()
    levelFS:SetPoint("RIGHT", titleFS, "LEFT", -3, 0)
    if not levelFS:IsShown() then levelFS:Show() end
end

function AddOn:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("muteCatCFDB", DBDefaults, true)
    self.IsTimerunner = false
    self._gearEventsActive = false
    self._headerStyleQueued = false
    self._pendingSlotUpdates = {}
    self._slotUpdateQueued = false
    self._fullRefreshQueued = false
    self._fullRefreshSlotList = {}
    self._fullRefreshIndex = 1
    self._tooltipLineCache = {}
    self._tooltipCacheSize = 0
    self._itemLevelRetryCount = {}

    self.LibEnchantData = LibStub("LibEnchantData-MIDNIGHT-1.0", true)

    -- Populate GearSlots dynamically after Blizzard UI is loaded
    self.GearSlots = {}
    local slotNames = {
        [1] = "CharacterHeadSlot", [2] = "CharacterNeckSlot", [3] = "CharacterShoulderSlot",
        [4] = "CharacterShirtSlot", [5] = "CharacterChestSlot", [6] = "CharacterWaistSlot",
        [7] = "CharacterLegsSlot", [8] = "CharacterFeetSlot", [9] = "CharacterWristSlot",
        [10] = "CharacterHandsSlot", [11] = "CharacterFinger0Slot", [12] = "CharacterFinger1Slot",
        [13] = "CharacterTrinket0Slot", [14] = "CharacterTrinket1Slot", [15] = "CharacterBackSlot",
        [16] = "CharacterMainHandSlot", [17] = "CharacterSecondaryHandSlot", [19] = "CharacterTabardSlot",
    }
    for _, id in ipairs(self.GearSlotIDs) do
        local name = slotNames[id]
        local frame = name and _G[name]
        if frame then
            table.insert(self.GearSlots, frame)
        end
    end

    -- ShowSubFrame: Blizzard passes sometimes the FRAME OBJECT, sometimes a string name
    hooksecurefunc(CharacterFrame, "ShowSubFrame", function(_, subFrame)
        if subFrame == PaperDollFrame or subFrame == "PaperDollFrame" then
            -- OnShow hook handles initialization to avoid double-firing
        else
            self:DisableGearEvents()
        end
    end)
    
    -- Reliable backup: PaperDollFrame:OnShow fires whenever the panel becomes visible
    if PaperDollFrame and not self._paperDollOnShowHooked then
        PaperDollFrame:HookScript("OnShow", function()
            self:EnableGearEvents()
            self:CheckIfTimerunner()
            self:QueueFullGearRefresh()
            self:QueueHeaderStyling()
        end)
        PaperDollFrame:HookScript("OnHide", function()
            self:DisableGearEvents()
        end)
        self._paperDollOnShowHooked = true
    end

    hooksecurefunc(CharacterFrame, "Hide", function()
        self:DisableGearEvents()
    end)

    -- RefreshDisplay: Only restyle header when paper doll is actually visible
    hooksecurefunc(CharacterFrame, "RefreshDisplay", function()
        if not IsPaperDollVisible() then return end
        self:QueueHeaderStyling()
    end)

    -- Hook PaperDollFrame_UpdateStats to ensure colors are applied when stats refresh
    if _G.PaperDollFrame_UpdateStats then
        hooksecurefunc("PaperDollFrame_UpdateStats", function()
            if IsPaperDollVisible() then
                -- stats refresh can be frequent, so we only queue header styling
                self:QueueHeaderStyling()
            end
        end)
    end
end
