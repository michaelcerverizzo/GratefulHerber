local _, ns = ...

-- A curated Classic Era reference, not a complete profession database. Match by
-- output item ID so the learned checklist works on non-English clients too.
ns.Catalog = {
    {name = "Minor Healing Potion", outputID = 118, source = "Alchemy trainer"},
    {name = "Lesser Healing Potion", outputID = 858, source = "Alchemy trainer"},
    {name = "Healing Potion", outputID = 929, source = "Alchemy trainer"},
    {name = "Greater Healing Potion", outputID = 1710, source = "Alchemy trainer"},
    {name = "Superior Healing Potion", outputID = 3928, source = "Alchemy trainer"},
    {name = "Minor Mana Potion", outputID = 2455, source = "Alchemy trainer"},
    {name = "Lesser Mana Potion", outputID = 3385, source = "Alchemy trainer"},
    {name = "Mana Potion", outputID = 3827, source = "Alchemy trainer"},
    {name = "Greater Mana Potion", outputID = 6149, source = "Alchemy trainer"},
    {name = "Elixir of Lion's Strength", outputID = 2454, source = "Alchemy trainer"},
    {name = "Elixir of Minor Defense", outputID = 5997, source = "Alchemy trainer"},
    {name = "Elixir of Defense", outputID = 3389, source = "Alchemy trainer"},
    {name = "Elixir of Fortitude", outputID = 3825, source = "Alchemy trainer"},
    {name = "Elixir of Ogre's Strength", outputID = 3390, source = "Alchemy trainer"},
    {name = "Elixir of Water Breathing", outputID = 5996, source = "Alchemy trainer"},
    {name = "Swiftness Potion", outputID = 2459, source = "Recipe: random world drop"},
    {name = "Free Action Potion", outputID = 5634, source = "Recipe: limited-stock Alchemy vendors in Ironforge / Orgrimmar"},
    {name = "Elixir of Giants", outputID = 9206, source = "Recipe: random world drop"},
    {name = "Elixir of the Mongoose", outputID = 13452, source = "Recipe: high-level world drop"},
    {name = "Invisibility Potion", outputID = 9172, source = "Recipe: random world drop"},
    {name = "Restorative Potion", outputID = 9030, source = "Quest: Badlands Reagent Run II"},
    {name = "Greater Fire Protection Potion", outputID = 13457, source = "Recipe drop: Firebrand Pyromancer, Blackrock Spire"},
    {name = "Greater Frost Protection Potion", outputID = 13456, source = "Recipe drop: Frostmaul giants / preservers, Winterspring"},
    {name = "Greater Nature Protection Potion", outputID = 13458, source = "Recipe drop: Decaying Horror / Rotting Behemoth, Western Plaguelands"},
    {name = "Greater Shadow Protection Potion", outputID = 13459, source = "Recipe drop: Dark Adept / Shadowmage, Eastern Plaguelands"},
    {name = "Greater Arcane Protection Potion", outputID = 13461, source = "Recipe drop: Cobalt Mageweaver, Winterspring"},
    {name = "Flask of the Titans", outputID = 13510, source = "Recipe drop: General Drakkisath, Upper Blackrock Spire"},
    {name = "Flask of Distilled Wisdom", outputID = 13511, source = "Recipe drop: Balnazzar, Stratholme"},
    {name = "Flask of Supreme Power", outputID = 13512, source = "Recipe drop: Ras Frostwhisper, Scholomance"},
    {name = "Flask of Chromatic Resistance", outputID = 13513, source = "Recipe drop: Gyth, Upper Blackrock Spire"},
    {name = "Transmute: Arcanite", outputID = 12360, source = "Recipe vendor: Alchemist Pestlezugg, Gadgetzan"},
    {name = "Philosopher's Stone", outputID = 9149, source = "Recipe vendor: Alchemist Pestlezugg, Gadgetzan"},
}

local transmuteOutputs = {
    [12360] = true, [3577] = true, [6037] = true, [7080] = true,
    [7078] = true, [7076] = true, [7082] = true, [12808] = true, [12803] = true,
}

local function OwnAlchemy()
    if not GetTradeSkillLine or not GetSpellInfo or not GetNumTradeSkills then
        return nil, "Open your Alchemy profession window first."
    end
    local name = GetTradeSkillLine()
    local alchemy = GetSpellInfo(2259)
    if not alchemy or name ~= alchemy then
        return nil, "Open your own Alchemy profession window first."
    end
    if (IsTradeSkillLinked and IsTradeSkillLinked()) or (IsTradeSkillGuild and IsTradeSkillGuild()) then
        return nil, "Use your own Alchemy profession window."
    end
    return true
end

local function CopyRecipe(recipe)
    local copy = {}
    for key, value in pairs(recipe) do
        if key ~= "reagents" then copy[key] = value end
    end
    copy.reagents = {}
    for _, reagent in ipairs(recipe.reagents) do
        copy.reagents[#copy.reagents + 1] = {id = reagent.id, name = reagent.name, count = reagent.count}
    end
    return copy
end

local function WholeNumber(value, minimum, maximum)
    return type(value) == "number" and value == value and value >= minimum and value <= maximum
        and value ~= math.huge and value ~= -math.huge and value == math.floor(value)
end

function ns.ReadRecipe(index)
    local own, reason = OwnAlchemy()
    if not own then return nil, reason end
    if not index or index < 1 or index > GetNumTradeSkills() then
        return nil, "Select an Alchemy recipe first."
    end
    local name, kind = GetTradeSkillInfo(index)
    if not name or kind == "header" then return nil, "Select an Alchemy recipe first." end
    local count = GetTradeSkillNumReagents(index)
    if not count or count < 1 then return nil, "Recipe data is still loading. Try again in a moment." end
    local recipe = {name = name, reagents = {}}
    for i = 1, count do
        local reagentName, _, required = GetTradeSkillReagentInfo(index, i)
        local id = ns.ItemID(GetTradeSkillReagentItemLink(index, i))
        if not id or not reagentName or not required or required < 1 then
            return nil, "Reagent data is still loading. Try again in a moment."
        end
        recipe.reagents[#recipe.reagents + 1] = {id = id, name = reagentName, count = required}
    end
    recipe.link = GetTradeSkillItemLink and GetTradeSkillItemLink(index)
    recipe.outputID = ns.ItemID(recipe.link)
    local minimum, maximum
    if GetTradeSkillNumMade then minimum, maximum = GetTradeSkillNumMade(index) end
    recipe.outputMin = minimum and minimum > 0 and minimum or 1
    recipe.outputMax = maximum and maximum > 0 and maximum or recipe.outputMin
    recipe.seenAt = ns.Now()
    if GetTradeSkillTools then
        local tools = {GetTradeSkillTools(index)}
        recipe.tools, recipe.missingTools = {}, {}
        for i = 1, #tools, 2 do
            if type(tools[i]) == "string" and tools[i] ~= "" then
                local available = tools[i + 1] and true or false
                recipe.tools[#recipe.tools + 1] = {name = tools[i], available = available}
                if not available then recipe.missingTools[#recipe.missingTools + 1] = tools[i] end
            end
        end
        recipe.toolsCheckedAt = ns.Now()
    end
    local remaining = GetTradeSkillCooldown and GetTradeSkillCooldown(index)
    local previous = ns.db.cooldowns[name]
    local knownTransmute = recipe.outputID and transmuteOutputs[recipe.outputID]
    local validRemaining = type(remaining) == "number" and remaining == remaining
        and remaining >= 0 and remaining < math.huge
    -- Some clients return zero for every recipe. Only real cooldown recipes
    -- belong in Encore Timers; an already-ready observation needs no alert.
    if validRemaining and remaining > 0 then
        ns.db.cooldowns[name] = {readyAt = ns.Now() + remaining, seenAt = ns.Now(), hasCooldown = true}
    elseif validRemaining and (knownTransmute or (previous and previous.hasCooldown)) then
        ns.db.cooldowns[name] = {readyAt = ns.Now(), seenAt = ns.Now(), hasCooldown = true, notified = true}
    elseif GetTradeSkillCooldown and knownTransmute and not previous then
        -- A nil duration on an idle transmute is a ready observation. Missing
        -- data must not erase an existing active timer.
        ns.db.cooldowns[name] = {readyAt = ns.Now(), seenAt = ns.Now(), hasCooldown = true, notified = true}
    elseif previous and not previous.hasCooldown and not knownTransmute
        and type(previous.readyAt) == "number" and previous.readyAt <= ns.Now() then
        -- Clean up zero-duration potion entries saved by earlier builds.
        ns.db.cooldowns[name] = nil
    end
    return recipe
end

function ns.SelectedRecipe()
    local own, reason = OwnAlchemy()
    if not own then return nil, reason end
    if not GetTradeSkillSelectionIndex then return nil, "Select an Alchemy recipe first." end
    return ns.ReadRecipe(GetTradeSkillSelectionIndex())
end

function ns.ScanAlchemy()
    local own, reason = OwnAlchemy()
    if not own then return 0, reason end
    local learned, skipped = 0, 0
    for i = 1, GetNumTradeSkills() do
        local _, kind = GetTradeSkillInfo(i)
        if kind and kind ~= "header" then
            local recipe = ns.ReadRecipe(i)
            if recipe then
                ns.db.learned[recipe.name] = CopyRecipe(recipe)
                learned = learned + 1
            else
                skipped = skipped + 1
            end
        end
    end
    ns.db.scanAt = ns.Now()
    ns.db.scanStatus = "Visible recipes only; expand headers and clear filters for a broader scan."
    if skipped > 0 then ns.db.scanStatus = ns.db.scanStatus .. " Some recipe data is still loading." end
    return learned, ns.db.scanStatus
end

function ns.Craftable(recipe)
    local cooldown = ns.db.cooldowns[recipe.name]
    if cooldown and cooldown.readyAt > ns.Now() then return 0, "Cooldown active" end
    if recipe.missingTools and #recipe.missingTools > 0 then
        return 0, "Missing at last scan: " .. table.concat(recipe.missingTools, ", ") .. ". Rescan after moving or changing tools."
    end
    if not recipe.reagents or #recipe.reagents == 0 then return 0 end
    local crafts
    for _, reagent in ipairs(recipe.reagents) do
        local possible = math.floor(ns.Count(reagent.id) / reagent.count)
        crafts = crafts and math.min(crafts, possible) or possible
    end
    return crafts or 0
end

function ns.RecipeCost(recipe)
    local total, missing = 0, 0
    for _, reagent in ipairs(recipe.reagents or {}) do
        local price = ns.db.prices[reagent.id]
        if price and type(price.copper) == "number" then
            total = total + price.copper * reagent.count
        else
            missing = missing + 1
        end
    end
    if missing > 0 then return nil, missing end
    return total, 0
end

function ns.RecipeValue(recipe)
    local price = recipe.outputID and ns.db.prices[recipe.outputID]
    if not price then return nil end
    return price.copper * (recipe.outputMin or 1)
end

function ns.ProfessionCommand(command, argument)
    argument = argument or ""
    if command == "add" or command == "remove" then
        local crafts = tonumber(argument)
        if command == "add" and (not crafts or crafts ~= math.floor(crafts) or crafts < 1 or crafts > 999) then
            ns.Say("Use /gh add N with a whole number from 1 to 999."); return true
        end
        local recipe, reason = ns.SelectedRecipe()
        if not recipe then ns.Say(reason); return true end
        local plan = ns.Plan()
        if command == "remove" then
            plan.recipes[recipe.name] = nil
            ns.Say("Removed " .. recipe.name .. " from the setlist.")
        else
            recipe.crafts = crafts
            plan.recipes[recipe.name] = CopyRecipe(recipe)
            ns.db.learned[recipe.name] = CopyRecipe(recipe)
            ns.Say("Set " .. recipe.name .. " to " .. crafts .. " planned crafts.")
        end
    elseif command == "scan" then
        local count, status = ns.ScanAlchemy()
        ns.Say("Observed " .. count .. " Alchemy recipes. " .. (status or ""))
    elseif command == "price" then
        local idText, priceText = argument:match("^(%d+)%s+(%d+)$")
        local id, copper = tonumber(idText), tonumber(priceText)
        if not WholeNumber(id, 1, 2147483647) or not WholeNumber(copper, 0, 10000000000) then
            ns.Say("Use /gh price ITEMID COPPER (unit price, whole copper, up to 10000000000).")
            return true
        end
        ns.db.prices[id] = {copper = copper, updatedAt = ns.Now()}
        ns.Say("Saved unit price for " .. ns.ItemName(id) .. ": " .. copper .. " copper.")
    elseif command == "unprice" then
        local id = tonumber(argument:match("^(%d+)$"))
        if not WholeNumber(id, 1, 2147483647) then ns.Say("Use /gh unprice ITEMID (1 to 2147483647)."); return true end
        ns.db.prices[id] = nil
        ns.Say("Removed the manual price for " .. ns.ItemName(id) .. ".")
    else
        return false
    end
    return true
end
