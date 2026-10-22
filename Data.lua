local _, ns = ...
ns.Herbs = {
    {2447, "Peacebloom"}, {765, "Silverleaf"}, {2449, "Earthroot"},
    {785, "Mageroyal"}, {2450, "Briarthorn"}, {2452, "Swiftthistle"},
    {2453, "Bruiseweed"}, {3820, "Stranglekelp"}, {3369, "Grave Moss"},
    {3355, "Wild Steelbloom"}, {3356, "Kingsblood"}, {3357, "Liferoot"},
    {3818, "Fadeleaf"}, {3821, "Goldthorn"}, {3358, "Khadgar's Whisker"},
    {3819, "Wintersbite"}, {4625, "Firebloom"}, {8831, "Purple Lotus"},
    {8836, "Arthas' Tears"}, {8838, "Sungrass"}, {8839, "Blindweed"},
    {8845, "Ghost Mushroom"}, {8846, "Gromsblood"}, {13463, "Dreamfoil"},
    {13464, "Golden Sansam"}, {13465, "Mountain Silversage"},
    {13466, "Plaguebloom"}, {13467, "Icecap"}, {13468, "Black Lotus"},
    {8153, "Wildvine"}, {19726, "Bloodvine"},
}
ns.HerbIDs = {}
for _, herb in ipairs(ns.Herbs) do ns.HerbIDs[herb[1]] = true end
ns.state = {session = {loot = {}, started = GetTime(), gathers = 0}, bankOpen = false}

function ns.Now() return time() end
function ns.Say(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffbc93eeGrateful Herber:|r " .. tostring(message))
end
function ns.ItemID(link) return link and tonumber(link:match("item:(%d+)")) end
function ns.ItemName(id, fallback) return GetItemInfo(id) or fallback or ("Item " .. id) end
function ns.Count(id) return GetItemCount(id, false) or 0 end

function ns.Copy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for k, v in pairs(value) do copy[k] = ns.Copy(v) end
    return copy
end
