local addonName, AddOn = ...
---@class muteCatCF: AceAddon, AceConsole-3.0, AceEvent-3.0
AddOn = LibStub("AceAddon-3.0"):GetAddon(addonName)

local DebugPrint = AddOn.DebugPrint

---@param region Region
---@param point string
---@param relativeTo Region|Frame
---@param relativePoint string
---@param xOffset number
---@param yOffset number
local function SetPointCached(region, point, relativeTo, relativePoint, xOffset, yOffset)
    if not region then return end
    local cache = region.muteCatPointCache
    if cache
        and cache.point == point
        and cache.relativeTo == relativeTo
        and cache.relativePoint == relativePoint
        and cache.xOffset == xOffset
        and cache.yOffset == yOffset
    then
        return
    end

    region:ClearAllPoints()
    region:SetPoint(point, relativeTo, relativePoint, xOffset, yOffset)
    if not cache then
        cache = {}
        region.muteCatPointCache = cache
    end
    cache.point = point
    cache.relativeTo = relativeTo
    cache.relativePoint = relativePoint
    cache.xOffset = xOffset
    cache.yOffset = yOffset
end

---Set item level text position in the Character Info window
---@param slot Slot The gear slot to set item level position for
function AddOn:SetItemLevelPositionBySlot(slot)
    local isWeaponSlot = slot == CharacterMainHandSlot or slot == CharacterSecondaryHandSlot
    local weaponXOffset = isWeaponSlot and 1 or 0

    if self.db.profile.iLvlOnItem then
        SetPointCached(slot.muteCatItemLevel, "CENTER", slot, "TOP", weaponXOffset, -10)
    elseif slot.IsLeftSide == nil then
        SetPointCached(slot.muteCatItemLevel, "CENTER", slot, "TOP", weaponXOffset, 10)
    else
        SetPointCached(slot.muteCatItemLevel, slot.IsLeftSide and "LEFT" or "RIGHT", slot, slot.IsLeftSide and "RIGHT" or "LEFT", (slot.IsLeftSide and 1 or -1) * 10, 0)
    end
end


---Set upgrade track text position in the Character Info window
---@param slot Slot The gear slot to set upgrade tracks position for
function AddOn:SetUpgradeTrackPositionBySlot(slot)
    local itemLevelShown = self.db.profile.showiLvl and not self.db.profile.iLvlOnItem and slot.muteCatItemLevel and slot.muteCatItemLevel:IsShown()
    local itemLevelShownOnItem = self.db.profile.showiLvl and self.db.profile.iLvlOnItem and slot.muteCatItemLevel and slot.muteCatItemLevel:IsShown()
    local isMainHand = slot == CharacterMainHandSlot
    local yOffset = (slot == CharacterHandsSlot or slot == CharacterLegsSlot or slot == CharacterWristSlot) and 1 or 0

    if slot.IsLeftSide == nil then
        SetPointCached(slot.muteCatUpgradeTrack, "CENTER", slot, "BOTTOM", (isMainHand and -1 or 1) * 40, 5)
    elseif itemLevelShownOnItem then
        SetPointCached(slot.muteCatUpgradeTrack, slot.IsLeftSide and "LEFT" or "RIGHT", slot, slot.IsLeftSide and "RIGHT" or "LEFT", (slot.IsLeftSide and 1 or -1) * 10, yOffset)
    elseif itemLevelShown then
        SetPointCached(slot.muteCatUpgradeTrack, slot.IsLeftSide and "LEFT" or "RIGHT", slot.muteCatItemLevel, slot.IsLeftSide and "RIGHT" or "LEFT", slot.IsLeftSide and 1.5 or -1.5, yOffset)
    else
        SetPointCached(slot.muteCatUpgradeTrack, slot.IsLeftSide and "LEFT" or "RIGHT", slot, slot.IsLeftSide and "RIGHT" or "LEFT", (slot.IsLeftSide and 1 or -1) * 10, yOffset)
    end
end


---Set gems text position in the Character Info window
---@param slot Slot The gear slot to set gems position for
function AddOn:SetGemsPositionBySlot(slot)
    local itemLevelShown = self.db.profile.showiLvl and not self.db.profile.iLvlOnItem and slot.muteCatItemLevel and slot.muteCatItemLevel:IsShown()
    local itemLevelShownOnItem = self.db.profile.showiLvl and self.db.profile.iLvlOnItem and slot.muteCatItemLevel and slot.muteCatItemLevel:IsShown()
    local upgradeTrackShown = self:ShouldShowUpgradeTrack() and slot.muteCatUpgradeTrack and slot.muteCatUpgradeTrack:IsShown()
    local enchantShown = self:ShouldShowEnchants() and slot.muteCatEnchant and slot.muteCatEnchant:IsShown()
    local isMainHand = slot == CharacterMainHandSlot

    -- Gems on weapon/shield/off-hand slots (not possible as far as I am aware, but you never know)
    if enchantShown and slot.IsLeftSide ~= nil then
        SetPointCached(slot.muteCatGems, slot.IsLeftSide and "LEFT" or "RIGHT", slot.muteCatEnchant, slot.IsLeftSide and "RIGHT" or "LEFT", slot.IsLeftSide and 4 or -4, 0)
    elseif itemLevelShown and slot.IsLeftSide ~= nil and slot.muteCatGems and slot.muteCatGems:IsShown() then
        SetPointCached(slot.muteCatItemLevel, slot.IsLeftSide and "LEFT" or "RIGHT", slot, slot.IsLeftSide and "RIGHT" or "LEFT", (slot.IsLeftSide and 1 or -1) * 10, slot.muteCatItemLevel:GetHeight() / 1.5)
        SetPointCached(slot.muteCatGems, slot.IsLeftSide and "LEFT" or "RIGHT", slot, slot.IsLeftSide and "RIGHT" or "LEFT", (slot.IsLeftSide and 1 or -1) * 10, (slot.muteCatItemLevel:GetHeight() / 1.5) * -1)
    elseif upgradeTrackShown and slot.IsLeftSide == nil then
        SetPointCached(slot.muteCatGems, isMainHand and "RIGHT" or "LEFT", slot.muteCatUpgradeTrack, isMainHand and "LEFT" or "RIGHT", isMainHand and -1 or 1, 0)
    elseif upgradeTrackShown then
        SetPointCached(slot.muteCatGems, slot.IsLeftSide and "LEFT" or "RIGHT", slot.muteCatUpgradeTrack, slot.IsLeftSide and "RIGHT" or "LEFT", slot.IsLeftSide and 2 or -2, 0)
    elseif itemLevelShownOnItem and slot.IsLeftSide == nil then
        SetPointCached(slot.muteCatGems, "CENTER", slot, "BOTTOM", (isMainHand and -1 or 1) * 40, 5)
    elseif itemLevelShownOnItem then
        SetPointCached(slot.muteCatGems, slot.IsLeftSide and "LEFT" or "RIGHT", slot, slot.IsLeftSide and "RIGHT" or "LEFT", (slot.IsLeftSide and 1 or -1) * 10, 0)
    elseif itemLevelShown and slot.IsLeftSide == nil then
        SetPointCached(slot.muteCatGems, "LEFT", slot.muteCatItemLevel, "RIGHT", 1, 0)
    elseif itemLevelShown then
        SetPointCached(slot.muteCatGems, slot.IsLeftSide and "LEFT" or "RIGHT", slot.muteCatItemLevel, slot.IsLeftSide and "RIGHT" or "LEFT", slot.IsLeftSide and 2 or -2, 0)
    elseif slot.IsLeftSide == nil then
        SetPointCached(slot.muteCatGems, "CENTER", slot, "TOP", 0, 10)
    else
        SetPointCached(slot.muteCatGems, slot.IsLeftSide and "LEFT" or "RIGHT", slot, slot.IsLeftSide and "RIGHT" or "LEFT", (slot.IsLeftSide and 1 or -1) * 10, 0)
    end
end


---Set enchant text position in the Character Info window
---@param slot Slot The gear slot to set enchant position for
function AddOn:SetEnchantPositionBySlot(slot)
    local isSocketableSlot = self:IsSocketableSlot(slot) or self:IsAuxSocketableSlot(slot)
    local isEnchantableSlot = self:IsEnchantableSlot(slot)
    local itemLevelShown = self.db.profile.showiLvl and not self.db.profile.iLvlOnItem and slot.muteCatItemLevel and slot.muteCatItemLevel:IsShown()
    local itemLevelShownOnItem = self.db.profile.showiLvl and self.db.profile.iLvlOnItem and slot.muteCatItemLevel and slot.muteCatItemLevel:IsShown()
    local upgradeTrackShown = self:ShouldShowUpgradeTrack() and slot.muteCatUpgradeTrack and slot.muteCatUpgradeTrack:IsShown()
    local gemsShown = self:ShouldShowGems() and slot.muteCatGems and slot.muteCatGems:IsShown()
    if itemLevelShown and slot.IsLeftSide ~= nil and isEnchantableSlot then
        -- Adjust positioning for slots that have both item level and enchants visible
        DebugPrint("ilvl and enchant visible")
        SetPointCached(slot.muteCatItemLevel, slot.IsLeftSide and "LEFT" or "RIGHT", slot, slot.IsLeftSide and "RIGHT" or "LEFT", (slot.IsLeftSide and 1 or -1) * 10, slot.muteCatItemLevel:GetHeight() / 1.5)
        SetPointCached(slot.muteCatEnchant, slot.IsLeftSide and "LEFT" or "RIGHT", slot, slot.IsLeftSide and "RIGHT" or "LEFT", (slot.IsLeftSide and 1 or -1) * 10, (slot.muteCatItemLevel:GetHeight() / 1.5) * -1)
    elseif upgradeTrackShown and slot.IsLeftSide ~= nil and isEnchantableSlot then
        -- Adjust positioning for slots that have both upgrade track and enchants visible
        DebugPrint("upgrade track and enchant visible in slot", slot:GetID())
        SetPointCached(slot.muteCatUpgradeTrack, slot.IsLeftSide and "LEFT" or "RIGHT", slot, slot.IsLeftSide and "RIGHT" or "LEFT", (slot.IsLeftSide and 1 or -1) * 10, slot.muteCatUpgradeTrack:GetHeight() / 1.5)
        SetPointCached(slot.muteCatEnchant, slot.IsLeftSide and "LEFT" or "RIGHT", slot, slot.IsLeftSide and "RIGHT" or "LEFT", (slot.IsLeftSide and 1 or -1) * 10, (slot.muteCatUpgradeTrack:GetHeight() / 1.5) * -1)
    elseif (not self.db.profile.showiLvl or itemLevelShownOnItem) and gemsShown and slot.IsLeftSide ~= nil and isSocketableSlot and isEnchantableSlot then
        SetPointCached(slot.muteCatEnchant, slot.IsLeftSide and "LEFT" or "RIGHT", slot, slot.IsLeftSide and "RIGHT" or "LEFT", (slot.IsLeftSide and 1 or -1) * 10, 0)
    elseif slot.IsLeftSide == nil then
        if slot.muteCatItemLevel and slot.muteCatItemLevel:IsShown() then
            SetPointCached(slot.muteCatEnchant, "BOTTOM", slot.muteCatItemLevel, "TOP", 0, 3)
        else
            SetPointCached(slot.muteCatEnchant, slot == CharacterMainHandSlot and "RIGHT" or "LEFT", slot, slot == CharacterMainHandSlot and "TOPRIGHT" or "TOPLEFT", slot == CharacterMainHandSlot and -3 or 0, 25)
        end
    else
        SetPointCached(slot.muteCatEnchant, slot.IsLeftSide and "LEFT" or "RIGHT", slot, slot.IsLeftSide and "RIGHT" or "LEFT", (slot.IsLeftSide and 1 or -1) * 10, 0)
    end

    -- Re-anchor gems after enchant placement because gems are positioned earlier in the update flow.
    if gemsShown and isEnchantableSlot and slot.IsLeftSide ~= nil and slot.muteCatEnchant and slot.muteCatEnchant:IsShown() and slot.muteCatGems and slot.muteCatGems:IsShown() then
        SetPointCached(slot.muteCatGems, slot.IsLeftSide and "LEFT" or "RIGHT", slot.muteCatEnchant, slot.IsLeftSide and "RIGHT" or "LEFT", slot.IsLeftSide and 4 or -4, 0)
    end
end


