local addonName, AddOn = ...
---@class muteCatCF: AceAddon, AceConsole-3.0, AceEvent-3.0
AddOn = LibStub("AceAddon-3.0"):GetAddon(addonName)

local DebugPrint = AddOn.DebugPrint

-- Known Midnight Gem keywords to identify them in tooltip text
local MidnightGemKeywords = {
    ["Sangri"] = true,
    ["Garnet"] = true,
    ["Harendar"] = true,
    ["Peridot"] = true,
    ["Ammani"] = true,
    ["Lapis"] = true,
    ["Tenibbrris"] = true,
    ["Amethyst"] = true,
    ["Everong"] = true,
    ["Eversong"] = true,
    ["Diamond"] = true,
}

---Sniffs for new gems in tooltips and records their icon/name mapping
---@param iconID number The FileDataID of the gem icon
---@param gemName string The display name of the gem from the tooltip
function AddOn:SniffGem(iconID, gemName)
    if not iconID or not gemName or gemName == "" then return end
    
    -- Check if we already know this icon
    if self.db.profile.discoveredGems[iconID] then return end
    
    -- Heuristic check: Is this a Midnight gem?
    local isMidnight = false
    for keyword in pairs(MidnightGemKeywords) do
        if gemName:find(keyword) then
            isMidnight = true
            break
        end
    end
    
    if isMidnight then
        self.db.profile.discoveredGems[iconID] = {
            name = gemName,
            discovered = date("%Y-%m-%d %H:%M:%S"),
            isMidnight = true
        }
        DebugPrint("New Midnight Gem discovered!", AddOn.ColorText(gemName, "Heirloom"), "(Icon ID: " .. iconID .. ")")
    end
end

---Attempts to get the localized name or extra info for a gem based on its icon ID
---@param iconID number
---@return string|nil name
function AddOn:GetGemInfoByIcon(iconID)
    local data = self.db.profile.discoveredGems[iconID]
    return data and data.name or nil
end
