local addonName, AddOn = ...
---@class muteCatCF: AceAddon, AceConsole-3.0, AceEvent-3.0
AddOn = LibStub("AceAddon-3.0"):GetAddon(addonName)

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

local FULL_REFRESH_SLOTS_PER_TICK = 4

local function IsPaperDollVisible()
    return PaperDollFrame and PaperDollFrame:IsVisible()
end

local function HideRegion(region)
    if region then
        region:Hide()
    end
end

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
    },
}


-- Handles special scaling/gear logic for Timerunning/Remix characters (e.g., MoP Remix)
function AddOn:CheckIfTimerunner()
    local timerunningID = PlayerGetTimerunningSeasonID()
    self.IsTimerunner = timerunningID ~= nil
end

function AddOn:ShouldShowGems()
    return self.db.profile.showGems and not self.IsTimerunner and self:IsPlayerMaxLevel()
end

function AddOn:ShouldShowEnchants()
    return self.db.profile.showEnchants and not self.IsTimerunner and self:IsPlayerMaxLevel()
end

function AddOn:ShouldShowUpgradeTrack()
    return self.db.profile.showUpgradeTrack and not self.IsTimerunner and self:IsPlayerMaxLevel()
end

function AddOn:ApplyHeaderStyling()
    if not IsPaperDollVisible() then return end
    self:StyleBlizzardItemLevelClassColor()
    self:StyleCharacterHeaderClassColor()
    self:LayoutCharacterHeaderLevelOnly()
end

function AddOn:QueueHeaderStyling()
    if self._headerStyleQueued then
        return
    end
    self._headerStyleQueued = true
    C_Timer.After(0, function()
        self._headerStyleQueued = false
        if IsPaperDollVisible() then
            self:ApplyHeaderStyling()
        end
    end)
end

local function CaptureFontStringState(fs)
    if not fs then
        return nil, nil
    end
    return fs:IsShown(), fs:GetText()
end

---@param slot Slot
---@return boolean changed
function AddOn:DidSlotVisualStateChange(slot, ilvlShownBefore, ilvlTextBefore, trackShownBefore, trackTextBefore, gemShownBefore, gemTextBefore, enchShownBefore, enchTextBefore)
    local ilvlShownAfter, ilvlTextAfter = CaptureFontStringState(slot.muteCatItemLevel)
    local trackShownAfter, trackTextAfter = CaptureFontStringState(slot.muteCatUpgradeTrack)
    local gemShownAfter, gemTextAfter = CaptureFontStringState(slot.muteCatGems)
    local enchShownAfter, enchTextAfter = CaptureFontStringState(slot.muteCatEnchant)
    return ilvlShownBefore ~= ilvlShownAfter
        or ilvlTextBefore ~= ilvlTextAfter
        or trackShownBefore ~= trackShownAfter
        or trackTextBefore ~= trackTextAfter
        or gemShownBefore ~= gemShownAfter
        or gemTextBefore ~= gemTextAfter
        or enchShownBefore ~= enchShownAfter
        or enchTextBefore ~= enchTextAfter
end

function AddOn:EnableGearEvents()
    if self._gearEventsActive then
        return
    end
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "HandleEquipmentOrSettingsChange")
    self:RegisterEvent("SOCKET_INFO_ACCEPT", "HandleEquipmentOrSettingsChange")
    self._gearEventsActive = true
end

function AddOn:DisableGearEvents()
    if self._gearEventsActive then
        self:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
        self:UnregisterEvent("SOCKET_INFO_ACCEPT")
        self._gearEventsActive = false
    end

    -- Always clear runtime update state when the character frame is not active.
    self._pendingItemLevelRetry = {}
    self._itemLevelRetryCount = {}
    self._pendingSlotUpdates = {}
    self._slotUpdateQueued = false
    self._fullRefreshQueued = false
    self._fullRefreshIndex = 1
    self._fullRefreshAnyChanged = false
end

---@return table<number, Slot> slotsByID
function AddOn:GetGearSlotsByID()
    if self._gearSlotsByID then
        return self._gearSlotsByID
    end

    self._gearSlotsByID = {}
    if self.GearSlots then
        for _, slot in ipairs(self.GearSlots) do
            self._gearSlotsByID[slot:GetID()] = slot
        end
    end
    return self._gearSlotsByID
end

local reusableCtx = {}

---@return table ctx
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

---@param slot Slot
---@param ctx table
function AddOn:UpdateGearSlot(slot, ctx)
    local ilvlShownBefore, ilvlTextBefore = CaptureFontStringState(slot.muteCatItemLevel)
    local trackShownBefore, trackTextBefore = CaptureFontStringState(slot.muteCatUpgradeTrack)
    local gemShownBefore, gemTextBefore = CaptureFontStringState(slot.muteCatGems)
    local enchShownBefore, enchTextBefore = CaptureFontStringState(slot.muteCatEnchant)

    local slotID = slot:GetID()
    local profile = ctx.profile

    if ctx.showItemLevel then
        if not slot.muteCatItemLevel then
            slot.muteCatItemLevel = slot:CreateFontString("muteCatItemLevel"..slotID, "OVERLAY", "GameTooltipText")
        end
        ---@type string, number
        local iFont, iSize = slot.muteCatItemLevel:GetFont()
        slot.muteCatItemLevel:SetFont(iFont, iSize, profile.iLvlOutline or "OUTLINE")
        slot.muteCatItemLevel:Hide()
        slot.muteCatItemLevel:SetTextScale(ctx.iLvlTextScale)

        self:GetItemLevelBySlot(slot)
        self:SetItemLevelPositionBySlot(slot)
    elseif slot.muteCatItemLevel then
        slot.muteCatItemLevel:Hide()
    end

    if ctx.showUpgradeTrack then
        if not slot.muteCatUpgradeTrack then
            slot.muteCatUpgradeTrack = slot:CreateFontString("muteCatUpgradeTrack"..slotID, "OVERLAY", "GameTooltipText")
        end
        ---@type string, number
        local uFont, uSize = slot.muteCatUpgradeTrack:GetFont()
        slot.muteCatUpgradeTrack:SetFont(uFont, uSize, profile.upgradeTrackOutline or "OUTLINE")
        slot.muteCatUpgradeTrack:Hide()
        slot.muteCatUpgradeTrack:SetTextScale(ctx.upgradeTrackTextScale)

        self:GetUpgradeTrackBySlot(slot)
        self:SetUpgradeTrackPositionBySlot(slot)
    elseif slot.muteCatUpgradeTrack then
        slot.muteCatUpgradeTrack:Hide()
    end

    if ctx.showGems then
        if not slot.muteCatGems then
            slot.muteCatGems = slot:CreateFontString("muteCatGems"..slotID, "OVERLAY", "GameTooltipText")
        end
        slot.muteCatGems:Hide()
        slot.muteCatGems:SetTextScale(ctx.gemScale)

        self:GetGemsBySlot(slot)
        self:SetGemsPositionBySlot(slot)
    elseif slot.muteCatGems then
        slot.muteCatGems:Hide()
    end

    if ctx.showEnchants then
        if not slot.muteCatEnchant then
            slot.muteCatEnchant = slot:CreateFontString("muteCatEnchant"..slotID, "OVERLAY", "GameTooltipText")
        end
        ---@type string, number
        local eFont, eSize = slot.muteCatEnchant:GetFont()
        slot.muteCatEnchant:SetFont(eFont, eSize, profile.enchantOutline)
        slot.muteCatEnchant:Hide()
        slot.muteCatEnchant:SetTextScale(ctx.enchTextScale)

        self:GetEnchantmentBySlot(slot)
        self:SetEnchantPositionBySlot(slot)
    elseif slot.muteCatEnchant then
        slot.muteCatEnchant:Hide()
    end


    if ctx.hideShirtTabardInfo and (slot == CharacterShirtSlot or slot == CharacterTabardSlot) then
        HideRegion(slot.muteCatItemLevel)
        HideRegion(slot.muteCatGems)
        HideRegion(slot.muteCatEnchant)
    end

    return self:DidSlotVisualStateChange(slot, ilvlShownBefore, ilvlTextBefore, trackShownBefore, trackTextBefore, gemShownBefore, gemTextBefore, enchShownBefore, enchTextBefore)
end

---@param slotIDs table<number, boolean>
function AddOn:UpdateSelectedGearSlots(slotIDs)
    if not self.GearSlots then
        DebugPrint("Gear slots table not found")
        return
    end
    local slotsByID = self:GetGearSlotsByID()
    local ctx = self:GetGearUpdateContext()
    local anyChanged = false
    for slotID in pairs(slotIDs) do
        local slot = slotsByID[slotID]
        if slot then
            anyChanged = self:UpdateGearSlot(slot, ctx) or anyChanged
        end
    end
    if anyChanged then
        PaperDollFrame_UpdateStats()
        self:QueueHeaderStyling()
    end
end

---@param slotID? number
function AddOn:QueueGearInfoUpdate(slotID)
    if not IsPaperDollVisible() then
        return
    end

    if slotID == nil then
        self:QueueFullGearRefresh()
        return
    end

    self:UpdateSelectedGearSlots({ [slotID] = true })
end

function AddOn:QueueFullGearRefresh()
    if not IsPaperDollVisible() then
        return
    end
    if not self.GearSlots then
        return
    end

    if not self._fullRefreshSlotList or #self._fullRefreshSlotList == 0 then
        self._fullRefreshSlotList = {}
        for _, slot in ipairs(self.GearSlots) do
            self._fullRefreshSlotList[#self._fullRefreshSlotList + 1] = slot:GetID()
        end
    end

    self._fullRefreshIndex = 1
    self._fullRefreshAnyChanged = false

    if self._fullRefreshQueued then
        return
    end

    self._fullRefreshQueued = true
    C_Timer.After(0, function()
        self:ProcessQueuedFullGearRefresh()
    end)
end

function AddOn:ProcessQueuedFullGearRefresh()
    self._fullRefreshQueued = false
    if not IsPaperDollVisible() then
        return
    end

    local slotList = self._fullRefreshSlotList
    local idx = self._fullRefreshIndex or 1
    if not slotList or idx > #slotList then
        if self._fullRefreshAnyChanged then
            PaperDollFrame_UpdateStats()
            self:QueueHeaderStyling()
        end
        return
    end

    local slotsByID = self:GetGearSlotsByID()
    local ctx = self:GetGearUpdateContext()
    local endIdx = math.min(idx + FULL_REFRESH_SLOTS_PER_TICK - 1, #slotList)
    for i = idx, endIdx do
        local slot = slotsByID[slotList[i]]
        if slot then
            self._fullRefreshAnyChanged = self:UpdateGearSlot(slot, ctx) or self._fullRefreshAnyChanged
        end
    end

    self._fullRefreshIndex = endIdx + 1
    if self._fullRefreshIndex <= #slotList then
        self._fullRefreshQueued = true
        C_Timer.After(0, function()
            self:ProcessQueuedFullGearRefresh()
        end)
        return
    end

    if self._fullRefreshAnyChanged then
        PaperDollFrame_UpdateStats()
        self:QueueHeaderStyling()
    end
end

function AddOn:QueueSlotButtonUpdate(slotID)
    if not IsPaperDollVisible() then
        return
    end
    if type(slotID) ~= "number" or slotID <= 0 then
        return
    end

    self._pendingSlotUpdates = self._pendingSlotUpdates or {}
    self._pendingSlotUpdates[slotID] = true

    if self._slotUpdateQueued then
        return
    end

    self._slotUpdateQueued = true
    C_Timer.After(0, function()
        self._slotUpdateQueued = false
        if not IsPaperDollVisible() then
            self._pendingSlotUpdates = {}
            return
        end

        local pending = self._pendingSlotUpdates
        self._pendingSlotUpdates = {}
        if not pending or not next(pending) then
            return
        end

        self:CheckIfTimerunner()
        self:UpdateSelectedGearSlots(pending)
    end)
end

---@param slotID number
---@return boolean
function AddOn:ShouldProcessSlotButtonUpdate(slotID)
    if type(slotID) ~= "number" or slotID <= 0 then
        return false
    end

    self._lastSeenSlotLinks = self._lastSeenSlotLinks or {}
    local currentLink = GetInventoryItemLink("player", slotID) or false
    if self._lastSeenSlotLinks[slotID] == currentLink then
        return false
    end

    self._lastSeenSlotLinks[slotID] = currentLink
    return true
end

function AddOn:ClearTooltipCache()
    self._tooltipLineCache = {}
    self._tooltipCacheSize = 0
end

---@param slotID number
function AddOn:InvalidateTooltipCacheForSlot(slotID)
    if type(slotID) ~= "number" or slotID <= 0 then
        self:ClearTooltipCache()
        return
    end

    local currentLink = GetInventoryItemLink("player", slotID)
    local previousLink = self._lastSeenSlotLinks and self._lastSeenSlotLinks[slotID] or nil
    if previousLink then
        self._tooltipLineCache[previousLink] = nil
    end
    if currentLink then
        self._tooltipLineCache[currentLink] = nil
    end
end

function AddOn:StyleBlizzardItemLevelClassColor()
    local statsPane = _G.CharacterStatsPane
    if not statsPane then return end

    local itemLevelFrame = statsPane.ItemLevelFrame or _G.CharacterStatsPaneItemLevelFrame or _G.PaperDollFrameItemLevelFrame
    if not itemLevelFrame then return end

    local r, g, b = self:GetPlayerClassColorRGB()
    if not r or not g or not b then return end

    local candidates = {
        itemLevelFrame.Value,
        itemLevelFrame.ItemLevel,
        itemLevelFrame.ValueText,
        _G.CharacterStatsPaneItemLevelFrameValue,
    }

    for _, fs in ipairs(candidates) do
        if fs and fs.SetTextColor then
            fs:SetTextColor(r, g, b)
            local fontPath, fontSize = fs:GetFont()
            if fontPath and fontSize then
                fs:SetFont(fontPath, fontSize, "OUTLINE")
            end
        end
    end

    if itemLevelFrame.GetRegions then
        for _, region in ipairs({ itemLevelFrame:GetRegions() }) do
            if region and region.GetObjectType and region:GetObjectType() == "FontString" and region.SetTextColor then
                region:SetTextColor(r, g, b)
                local fontPath, fontSize = region:GetFont()
                if fontPath and fontSize then
                    region:SetFont(fontPath, fontSize, "OUTLINE")
                end
            end
        end
    end
end

function AddOn:StyleCharacterHeaderClassColor()
    local r, g, b = self:GetPlayerClassColorRGB()
    if not r or not g or not b then return end

    local candidates = {
        _G.CharacterFrameTitleText,
        _G.PaperDollFrameTitleText,
        _G.PaperDollFrameTitleManagerPaneTitleText,
        _G.PaperDollFrameTitleManagerPaneCurrentTitle,
    }

    for _, fs in ipairs(candidates) do
        if fs and fs.SetTextColor then
            fs:SetTextColor(r, g, b)
            local fontPath, fontSize = fs:GetFont()
            if fontPath and fontSize then
                fs:SetFont(fontPath, fontSize, "OUTLINE")
            end
        end
    end
end

function AddOn:LayoutCharacterHeaderLevelOnly()
    local titleFS = _G.CharacterFrameTitleText
    if not titleFS then
        local titleCandidates = {
            _G.PaperDollFrameTitleText,
            _G.CharacterFrameTitleManagerPaneTitleText,
            _G.PaperDollFrameTitleManagerPaneTitleText,
        }
        for _, fs in ipairs(titleCandidates) do
            if fs and fs.GetText and fs:GetText() and fs:GetText() ~= "" then
                titleFS = fs
                break
            end
        end
        if not titleFS then
            titleFS = titleCandidates[1]
        end
    end
    if not titleFS then return end

    local hiddenSublineCandidates = {
        _G.CharacterLevelText,
        _G.CharacterFrameTitleManagerPaneLevelText,
        _G.PaperDollFrameTitleManagerPaneLevelText,
        _G.CharacterFrameTitleManagerPaneClassText,
        _G.PaperDollFrameTitleManagerPaneClassText,
        _G.CharacterFrameTitleManagerPaneClassAndLevelText,
        _G.PaperDollFrameTitleManagerPaneClassAndLevelText,
        _G.PaperDollFrameLevelText,
    }
    for _, fs in ipairs(hiddenSublineCandidates) do
        if fs and fs.Hide then
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
        levelFS:SetFont(fontPath, fontSize, "OUTLINE")
    end

    if NORMAL_FONT_COLOR then
        levelFS:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    else
        levelFS:SetTextColor(1, 0.82, 0)
    end

    levelFS:SetText(tostring(UnitLevel("player") or ""))
    local levelWidth = levelFS:GetStringWidth() or 0

    -- Keep both strings inside the title container: shift title right by level width + 3px.
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

        titleFS:ClearAllPoints()
        titleFS:SetPoint(titleFS.muteCatOrigPoint, titleFS.muteCatOrigRelTo, titleFS.muteCatOrigRelPoint, titleFS.muteCatOrigX + levelWidth + 3, titleFS.muteCatOrigY)
    end

    levelFS:ClearAllPoints()
    levelFS:SetPoint("RIGHT", titleFS, "LEFT", -3, 0)
    levelFS:Show()
end

function AddOn:OnInitialize()
    -- Load database
    self.db = LibStub("AceDB-3.0"):New("muteCatCFDB", DBDefaults, true)
    self.IsTimerunner = false
    self._gearEventsActive = false
    self._headerStyleQueued = false
    self._pendingSlotUpdates = {}
    self._slotUpdateQueued = false
    self._fullRefreshQueued = false
    self._fullRefreshSlotList = {}
    self._fullRefreshIndex = 1
    self._fullRefreshAnyChanged = false
    self._tooltipLineCache = {}
    self._tooltipCacheSize = 0
    self._itemLevelRetryCount = {}
    self._lastSeenSlotLinks = {}

    -- Necessary to create DB entries for stat ordering when playing a new class/specialization
    DebugPrint(ColorText(addonName, "Heirloom"), "initialized successfully")

    -- Hook into necessary secure functions
    hooksecurefunc(CharacterFrame, "ShowSubFrame", function(_, subFrame)
        if subFrame == "PaperDollFrame" then
            self:EnableGearEvents()
            self:CheckIfTimerunner()
            self:QueueFullGearRefresh()
            self:QueueHeaderStyling()
        else
            self:DisableGearEvents()
        end
    end)
    hooksecurefunc(CharacterFrame, "Hide", function()
        self:DisableGearEvents()
    end)
    hooksecurefunc(CharacterFrame, "RefreshDisplay", function()
            if not IsPaperDollVisible() then return end
            self:CheckIfTimerunner()
            self:QueueHeaderStyling()
        end)
    hooksecurefunc("PaperDollFrame_UpdateStats", function()
        if not IsPaperDollVisible() then return end
        self:StyleBlizzardItemLevelClassColor()
    end)
    -- Hook removed for CharacterModelScene
    hooksecurefunc("PaperDollItemSlotButton_Update", function(button)
        if not IsPaperDollVisible() then return end
        if not button or not button.GetID then return end
        local slotID = button:GetID()
        if not self:ShouldProcessSlotButtonUpdate(slotID) then
            return
        end
        self:QueueSlotButtonUpdate(slotID)
    end)
end

---Handles changes to equipped gear or AddOn settings when the Character Info window is visible
---@param event string
---@param ... any
function AddOn:HandleEquipmentOrSettingsChange(event, ...)
    if not IsPaperDollVisible() then
        return
    end

    DebugPrint("Changed equipped item or AddOn setting, updating gear information")
    if event == "PLAYER_EQUIPMENT_CHANGED" then
        local slotID = ...
        if type(slotID) == "number" and slotID > 0 then
            self:InvalidateTooltipCacheForSlot(slotID)
            self:QueueGearInfoUpdate(slotID)
            return
        end
    end

    self:ClearTooltipCache()
    self:QueueGearInfoUpdate()
end


