--------------------------------------------------------------------------------
-- muteCat CF - PositionGearInfo
-- Logic for positioning and layout of gear info FontStrings on the Character Frame.
--------------------------------------------------------------------------------

local addonName, AddOn = ...
---@class muteCatCF: AceAddon, AceConsole-3.0, AceEvent-3.0
AddOn = LibStub("AceAddon-3.0"):GetAddon(addonName)

---Cache a point on a region to avoid redundant SetPoint calls.
---@param region Region
---@param point string
---@param relativeTo Region|string
---@param relativePoint string
---@param xOffset number
---@param yOffset number
local function SetPointCached(region, point, relativeTo, relativePoint, xOffset, yOffset)
    if not region then return end
    local cache = region.muteCatPointCache
    if not cache then
        cache = {}
        region.muteCatPointCache = cache
    end
    
    yOffset = yOffset or 0
    if cache.point == point
        and cache.relativeTo == relativeTo
        and cache.relativePoint == relativePoint
        and cache.xOffset == xOffset
        and cache.yOffset == yOffset
    then
        return
    end

    region:ClearAllPoints()
    region:SetPoint(point, relativeTo, relativePoint, xOffset, yOffset)
    
    cache.point = point
    cache.relativeTo = relativeTo
    cache.relativePoint = relativePoint
    cache.xOffset = xOffset
    cache.yOffset = yOffset
end

---Update the layout and positioning of all gear info elements for a specific slot.
---@param slot Slot
function AddOn:UpdateSlotLayout(slot)
    local slotID = slot:GetID()
    local profile = self.db.profile
    
    local ilvl = slot.muteCatItemLevel
    local track = slot.muteCatUpgradeTrack
    local gems = slot.muteCatGems
    local ench = slot.muteCatEnchant
    
    local ilvlShown = profile.showiLvl and ilvl and ilvl:IsShown()
    local trackShown = self:ShouldShowUpgradeTrack() and track and track:IsShown()
    local gemsShown = self:ShouldShowGems() and gems and gems:IsShown()
    local enchShown = self:ShouldShowEnchants() and ench and ench:IsShown()
    
    local isLeftSide = slot.IsLeftSide
    local isWeaponSlot = slotID == 16 or slotID == 17
    local baseOffset = (isLeftSide and 1 or -1) * 10
    local weaponXOffset = isWeaponSlot and 1 or 0

    -- Throttling: Use a layout flag to avoid redundant calculations in the same frame
    local now = GetTime()
    if slot._lastMuteCatLayout == now then return end
    slot._lastMuteCatLayout = now

    ----------------------------------------------------------------------------
    -- WEAPON SLOTS (Bottom row: Main-hand, Off-hand, Ranged)
    ----------------------------------------------------------------------------
    if isLeftSide == nil then
        -- 1. Item Level
        if ilvlShown then
            local y = profile.iLvlOnItem and -10 or 10
            SetPointCached(ilvl, "CENTER", slot, "TOP", weaponXOffset, y)
        end

        -- 2. Upgrade Track
        if trackShown then
            local x = (slotID == 16 and -1 or 1) * 40
            SetPointCached(track, "CENTER", slot, "BOTTOM", x, 5)
        end

        -- 3. Enchant
        if enchShown then
            if ilvlShown and not profile.iLvlOnItem then
                SetPointCached(ench, "BOTTOM", ilvl, "TOP", 0, 3)
            else
                local p = slotID == 16 and "RIGHT" or "LEFT"
                local rp = slotID == 16 and "TOPRIGHT" or "TOPLEFT"
                local x = slotID == 16 and -3 or 0
                SetPointCached(ench, p, slot, rp, x, 25)
            end
        end

        -- 4. Gems
        if gemsShown then
             if trackShown then
                local p = (slotID == 16) and "RIGHT" or "LEFT"
                local rp = (slotID == 16) and "LEFT" or "RIGHT"
                local x = (slotID == 16) and -1 or 1
                SetPointCached(gems, p, track, rp, x, 0)
             elseif ilvlShown and not profile.iLvlOnItem then
                SetPointCached(gems, "LEFT", ilvl, "RIGHT", 1, 0)
             else
                SetPointCached(gems, "CENTER", slot, "TOP", weaponXOffset, 10)
             end
        end
        return
    end

    ----------------------------------------------------------------------------
    -- SIDE SLOTS (Left or Right side of the character model)
    ----------------------------------------------------------------------------
    local anchor = isLeftSide and "LEFT" or "RIGHT"
    local slotAnchor = isLeftSide and "RIGHT" or "LEFT"
    local smallGap = isLeftSide and 2 or -2
    local gemGap = isLeftSide and 4 or -4

    -- Row Visibility Status
    local hasTopRow = (ilvlShown and not profile.iLvlOnItem) or trackShown
    local hasBottomRow = enchShown or gemsShown
    
    -- Calculate Vertical Offsets (Standardized centering logic)
    local topRowY = 0
    local bottomRowY = 0
    
    if hasTopRow and hasBottomRow then
        topRowY = 6    -- Push top row up
        bottomRowY = -8 -- Push bottom row down
    elseif hasTopRow then
        topRowY = 0    -- Center top row vertically if it's the only one
    elseif hasBottomRow then
        bottomRowY = 0 -- Center bottom row vertically if it's the only one
    end

    -- 1. Item Level
    if ilvlShown then
        if profile.iLvlOnItem then
            SetPointCached(ilvl, "CENTER", slot, "TOP", 0, -10)
        else
            SetPointCached(ilvl, anchor, slot, slotAnchor, baseOffset, topRowY)
        end
    end

    -- 2. Upgrade Track (Position next to iLvl if available)
    if trackShown then
        if ilvlShown and not profile.iLvlOnItem then
            SetPointCached(track, anchor, ilvl, slotAnchor, smallGap, 0)
        else
            SetPointCached(track, anchor, slot, slotAnchor, baseOffset, topRowY)
        end
    end

    -- 3. Enchant (Standard bottom row start)
    if enchShown then
        SetPointCached(ench, anchor, slot, slotAnchor, baseOffset, bottomRowY)
    end

    -- 4. Gems (Position next to enchant if available)
    if gemsShown then
        if enchShown then
            SetPointCached(gems, anchor, ench, slotAnchor, gemGap, 0)
        else
            -- If no enchant is shown,gems occupy the starting spot of the bottom row
            SetPointCached(gems, anchor, slot, slotAnchor, baseOffset, bottomRowY)
        end
    end
end
