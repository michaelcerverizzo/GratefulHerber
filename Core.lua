local _, ns = ...
local soundPaths = {
    herb = "Interface\\AddOns\\GratefulHerber\\Media\\herb.ogg",
    craft = "Interface\\AddOns\\GratefulHerber\\Media\\craft.ogg",
    ready = "Interface\\AddOns\\GratefulHerber\\Media\\ready.ogg",
}

local function ValidName(name)
    return type(name) == "string" and #name > 0 and #name <= 40 and not name:find("[|\r\n]")
end

function ns.Initialize()
    GratefulHerberDB = GratefulHerberDB or {}
    GratefulHerberAccount = GratefulHerberAccount or {}
    ns.db, ns.account = GratefulHerberDB, GratefulHerberAccount
    local db, account = ns.db, ns.account
    db.plans = db.plans or {Default = {recipes = db.recipes or {}}}
    db.recipes = nil
    db.activePlan = db.activePlan or "Default"
    if not db.plans[db.activePlan] then
        db.activePlan = "Default"
        db.plans.Default = db.plans.Default or {recipes = {}}
    end
    db.learned, db.cooldowns, db.prices, db.notes = db.learned or {}, db.cooldowns or {}, db.prices or {}, db.notes or {}
    db.settings = db.settings or {}
    local defaults = {fontSize = 13, sound = "off", stash = false, lowVials = 5, bagSlots = 5, minimap = true}
    for key, value in pairs(defaults) do if db.settings[key] == nil then db.settings[key] = value end end
    account.characters, account.nodes, account.routes, account.best = account.characters or {}, account.nodes or {}, account.routes or {}, account.best or {}
    ns.playerName = UnitName("player") or "Player"
    ns.realm = GetRealmName() or "Realm"
    ns.faction = UnitFactionGroup("player") or "Neutral"
    ns.charKey = ns.realm .. "|" .. ns.faction .. "|" .. ns.playerName
    account.characters[ns.charKey] = account.characters[ns.charKey] or {bags = {}, bank = {}}
    local char = account.characters[ns.charKey]
    char.name, char.realm, char.faction = ns.playerName, ns.realm, ns.faction
    db.schema = 2
    ns.UpdateInventory()
end

function ns.Plan() return ns.db.plans[ns.db.activePlan] end

local function ContainerSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) or 0 end
    return GetContainerNumSlots and GetContainerNumSlots(bag) or 0
end
local function ContainerItem(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then return info.itemID or ns.ItemID(info.hyperlink), info.stackCount or 0 end
    elseif GetContainerItemInfo then
        local _, count, _, _, _, _, link, _, _, id = GetContainerItemInfo(bag, slot)
        return id or ns.ItemID(link), count or 0
    end
end

function ns.UpdateInventory()
    if not ns.account then return end
    local char = ns.account.characters[ns.charKey]
    local bags = {}
    local function Scan(bag, counts)
        for slot = 1, ContainerSlots(bag) do
            local id, count = ContainerItem(bag, slot)
            if id then counts[id] = (counts[id] or 0) + count end
        end
    end
    for bag = 0, NUM_BAG_SLOTS or 4 do Scan(bag, bags) end
    char.bags, char.bagsAt = bags, ns.Now()
    if ns.state.bankOpen then
        local bank = {}
        Scan(BANK_CONTAINER or -1, bank)
        for bag = (NUM_BAG_SLOTS or 4) + 1, (NUM_BAG_SLOTS or 4) + (NUM_BANKBAGSLOTS or 7) do Scan(bag, bank) end
        char.bank, char.bankAt = bank, ns.Now()
    end
end

function ns.StashCounts(id)
    local bank, alts = 0, 0
    for key, char in pairs(ns.account.characters) do
        if char.realm == ns.realm and char.faction == ns.faction then
            if key == ns.charKey then
                bank = (char.bank or {})[id] or 0
            else
                alts = alts + ((char.bags or {})[id] or 0) + ((char.bank or {})[id] or 0)
            end
        end
    end
    return bank, alts
end

function ns.ShoppingList()
    local totals, result = {}, {}
    for _, recipe in pairs(ns.Plan().recipes) do
        for _, reagent in ipairs(recipe.reagents) do
            local row = totals[reagent.id] or {id = reagent.id, name = reagent.name, needed = 0}
            row.needed = row.needed + reagent.count * recipe.crafts
            totals[reagent.id] = row
        end
    end
    for _, row in pairs(totals) do
        row.bags = ns.Count(row.id)
        row.bank, row.alts = ns.StashCounts(row.id)
        local available = row.bags + (ns.db.settings.stash and (row.bank + row.alts) or 0)
        row.missing = math.max(0, row.needed - available)
        result[#result + 1] = row
    end
    table.sort(result, function(a,b) return a.name < b.name end)
    return result
end

function ns.PackingWarnings()
    local warnings, free = {}, 0
    local freeFunc = C_Container and C_Container.GetContainerNumFreeSlots or GetContainerNumFreeSlots
    if freeFunc then
        for bag = 0, NUM_BAG_SLOTS or 4 do
            local slots, family = freeFunc(bag)
            -- Specialized herb bags cannot hold vials or ordinary loot.
            if not family or family == 0 then free = free + (slots or 0) end
        end
        if free <= ns.db.settings.bagSlots then warnings[#warnings + 1] = free .. " general bag slots free." end
    end
    local vialIDs, planned = {[3371] = true, [3372] = true, [8925] = true, [18256] = true}, {}
    for _, row in ipairs(ns.ShoppingList()) do
        if row.missing > 0 then warnings[#warnings + 1] = "Need " .. row.missing .. " " .. ns.ItemName(row.id,row.name) .. "." end
        if vialIDs[row.id] then planned[row.id] = true end
    end
    local any = false
    for id in pairs(planned) do
        any = true
        if ns.Count(id) < ns.db.settings.lowVials then
            warnings[#warnings + 1] = "Low " .. ns.ItemName(id) .. ": " .. ns.Count(id) .. " in bags."
        end
    end
    if not any and ns.Count(3371) < ns.db.settings.lowVials then
        warnings[#warnings + 1] = "Empty Vials: " .. ns.Count(3371) .. " in bags (reminder threshold " .. ns.db.settings.lowVials .. ")."
    end
    return warnings
end

function ns.PlayCue(kind, force)
    if not ns.db or ns.db.settings.sound == "off" then return false end
    local now = GetTime()
    if not force and ns.state.lastSound and now - ns.state.lastSound < 8 then return false end
    local played = false
    if ns.db.settings.sound == "builtin" and PlaySound then
        played = PlaySound((SOUNDKIT and SOUNDKIT.READY_CHECK) or 8960, "SFX")
    elseif ns.db.settings.sound == "custom" and PlaySoundFile then
        played = PlaySoundFile(soundPaths[kind] or soundPaths.herb, "SFX")
    end
    ns.state.lastSound = now
    return played and true or false
end

function ns.CheckCooldowns()
    if not ns.db then return end
    for name, cooldown in pairs(ns.db.cooldowns) do
        if cooldown.readyAt and cooldown.readyAt <= ns.Now() and not cooldown.notified then
            cooldown.notified = true
            ns.Say(name .. " should be ready. Open Alchemy to refresh.")
            ns.PlayCue("ready")
        end
    end
end

function ns.CoreCommand(command, arg)
    if command == "clear" then
        ns.Plan().recipes = {}; ns.Say("Active setlist cleared.")
    elseif command == "plan" then
        local action, name = arg:match("^(%S+)%s*(.-)$")
        if action == "list" then
            local names = {}; for key in pairs(ns.db.plans) do names[#names+1] = key end; table.sort(names)
            ns.Say("Setlists: " .. table.concat(names, ", ") .. ". Active: " .. ns.db.activePlan)
        elseif (action == "save" or action == "new") and ValidName(name) then
            if ns.db.plans[name] then ns.Say("That setlist already exists. Use it or choose another name.")
            else
                ns.db.plans[name] = action == "save" and ns.Copy(ns.Plan()) or {recipes = {}}
                ns.db.activePlan = name; ns.Say("Active setlist: " .. name)
            end
        elseif action == "use" and ns.db.plans[name] then
            ns.db.activePlan = name; ns.Say("Active setlist: " .. name)
        elseif action == "delete" and ns.db.plans[name] then
            if name == ns.db.activePlan then ns.Say("Switch to another setlist before deleting this one.")
            else ns.db.plans[name] = nil; ns.Say("Deleted setlist: " .. name) end
        else ns.Say("/gh plan new NAME, save NAME, use NAME, delete NAME, or list. Names: 1–40 characters.") end
    elseif command == "stash" then
        if arg == "on" or arg == "off" then ns.db.settings.stash = arg == "on"
        else ns.Say("Use /gh stash on or /gh stash off.") end
    elseif command == "sound" then
        if arg == "off" or arg == "builtin" or arg == "custom" then
            ns.db.settings.sound = arg; ns.Say("Sound: " .. arg)
        elseif arg == "test" then
            if ns.db.settings.sound == "off" then ns.Say("Select builtin or custom sound first.")
            else ns.PlayCue("herb", true) end
        else ns.Say("/gh sound off, builtin, custom, or test") end
    elseif command == "font" then
        local size = tonumber(arg)
        if size and size >= 11 and size <= 20 and size == math.floor(size) then ns.db.settings.fontSize = size
        else ns.Say("Use /gh font 11 through 20.") end
    elseif command == "threshold" then
        local kind, value = arg:match("^(%S+)%s+(%d+)$"); value = tonumber(value)
        if (kind == "vials" or kind == "bags") and value and value <= 100 then
            ns.db.settings[kind == "vials" and "lowVials" or "bagSlots"] = value
        else ns.Say("/gh threshold vials N or /gh threshold bags N (0–100)") end
    elseif command == "minimap" then
        if arg == "on" or arg == "off" then
            ns.db.settings.minimap = arg == "on"
            if ns.minimapButton then ns.minimapButton:SetShown(ns.db.settings.minimap) end
        else ns.Say("/gh minimap on or off") end
    else return false end
    return true
end
