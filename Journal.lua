local _, ns = ...

local mapPins = {}
local gatherSpells = {[2366] = true, [2368] = true, [3570] = true, [11993] = true, [28695] = true}
local lastMap, lastCanvas, lastWidth, lastHeight

local function Clock()
    return GetTime and GetTime() or ns.Now()
end

local function Session()
    ns.state.session = ns.state.session or {loot = {}, started = Clock(), gathers = 0}
    return ns.state.session
end

local function CleanLabel(value, fallback)
    value = tostring(value or ""):gsub("|", ""):gsub("[\r\n]", " ")
    value = value:match("^%s*(.-)%s*$")
    return value ~= "" and value:sub(1, 100) or fallback
end

function ns.CurrentPosition()
    if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then return nil end
    local mapID = C_Map.GetBestMapForUnit("player")
    local point = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not point or not point.GetXY then return nil end
    local x, y = point:GetXY()
    if not x or not y or x <= 0 or y <= 0 or x > 1 or y > 1 then return nil end
    local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return {mapID = mapID, x = x, y = y, zone = info and info.name or "Unknown zone"}
end

local function AddNode(point, label, kind, itemID)
    local nodes = ns.account.nodes
    if kind == "gather" then
        for _, node in ipairs(nodes) do
            if node.mapID == point.mapID and node.itemID == itemID and node.kind == kind
                and math.abs(node.x - point.x) < 0.005 and math.abs(node.y - point.y) < 0.005 then
                node.at = ns.Now()
                node.visits = (node.visits or 1) + 1
                return node
            end
        end
    end
    local node = {mapID = point.mapID, x = point.x, y = point.y, zone = point.zone,
        label = label, at = ns.Now(), kind = kind, itemID = itemID, visits = 1}
    nodes[#nodes + 1] = node
    if #nodes > 1500 then table.remove(nodes, 1) end
    return node
end

function ns.RecordGather(spellID)
    local valid = gatherSpells[spellID]
    if not valid and GetSpellInfo and spellID then
        local name, herbName = GetSpellInfo(spellID), GetSpellInfo(2366)
        valid = name and herbName and name == herbName
    end
    if not valid then return end
    -- A successful cast alone is not proof that herb loot was received.
    ns.PendingGather = {position = ns.CurrentPosition(), at = Clock(), counted = false}
end

local patternCache = {}
local function FormatPattern(format)
    if type(format) ~= "string" then return nil end
    if patternCache[format] then return patternCache[format] end
    local parts, arguments, index, sequence = {"^"}, {}, 1, 0
    while index <= #format do
        local tail = format:sub(index)
        if tail:sub(1, 2) == "%%" then
            parts[#parts + 1] = "%%"
            index = index + 2
        else
            local position, kind = tail:match("^%%(%d+)%$([sd])")
            local consumed
            if position then
                consumed = #position + 3
            else
                kind = tail:match("^%%([sd])")
                if kind then sequence = sequence + 1; position = sequence; consumed = 2 end
            end
            if kind then
                parts[#parts + 1] = kind == "d" and "(%d+)" or "(.-)"
                arguments[#arguments + 1] = tonumber(position)
                index = index + consumed
            else
                local char = format:sub(index, index)
                parts[#parts + 1] = char:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
                index = index + 1
            end
        end
    end
    parts[#parts + 1] = "$"
    local result = {pattern = table.concat(parts), arguments = arguments}
    patternCache[format] = result
    return result
end

local function ParseLoot(message, format)
    local compiled = FormatPattern(format)
    if not compiled then return nil end
    local captured = {message:match(compiled.pattern)}
    if #captured == 0 then return nil end
    local arguments = {}
    for i, value in ipairs(captured) do arguments[compiled.arguments[i]] = value end
    return arguments[1], tonumber(arguments[2]) or 1
end

function ns.HandleLoot(message)
    if type(message) ~= "string" then return false end
    local link, quantity = ParseLoot(message, LOOT_ITEM_SELF_MULTIPLE)
    if not link then link, quantity = ParseLoot(message, LOOT_ITEM_SELF) end
    local id = ns.ItemID(link)
    if not id or not ns.HerbIDs[id] or quantity < 1 then return false end
    local session = Session()
    session.loot[id] = (session.loot[id] or 0) + quantity
    local pending = ns.PendingGather
    if pending and Clock() - pending.at >= 0 and Clock() - pending.at <= 5 then
        if not pending.counted then
            session.gathers = (session.gathers or 0) + 1
            pending.counted = true
        end
        if pending.position then
            AddNode(pending.position, ns.ItemName(id), "gather", id)
            ns.RefreshMapPins()
        end
    elseif pending then
        ns.PendingGather = nil
    end
    ns.PlayCue("herb")
    return true
end

function ns.SessionStats()
    local session = Session()
    local total = 0
    for _, count in pairs(session.loot) do total = total + count end
    local elapsed = math.max(0, Clock() - session.started)
    local perHour = elapsed > 0 and total * 3600 / elapsed or 0
    local best = ns.account.best
    if elapsed >= 60 and perHour > (best.perHour or 0) then
        best.perHour, best.at, best.total, best.elapsed = perHour, ns.Now(), total, elapsed
    end
    return {total = total, elapsed = elapsed, perHour = perHour,
        bestPerHour = best.perHour or 0, gathers = session.gathers or 0}
end

function ns.RoutePoints()
    local route = ns.db.activeRoute and ns.account.routes[ns.db.activeRoute]
    return route and route.points or {}
end

function ns.RouteCurrent()
    local points = ns.RoutePoints()
    if #points == 0 then return nil, 0, 0 end
    local index = math.max(1, math.min(#points, ns.db.routeIndex or 1))
    return points[index], index, #points
end

local function RouteMessage()
    local point, index, total = ns.RouteCurrent()
    if not point then ns.Say("This route has no waypoints yet. Use /gh route add LABEL."); return end
    ns.Say(string.format("%s — %d/%d: %s, %s %.1f, %.1f. Travel there manually.",
        ns.db.activeRoute, index, total, point.label, point.zone or ("Map " .. point.mapID),
        point.x * 100, point.y * 100))
end

function ns.JournalCommand(command, argument)
    argument = argument or ""
    if command == "pin" then
        local point = ns.CurrentPosition()
        if not point then ns.Say("Your map position is unavailable here."); return true end
        AddNode(point, CleanLabel(argument, "Personal herb note"), "manual")
        ns.Say("Historical map note saved at your current location.")
        ns.RefreshMapPins()
    elseif command == "route" then
        local action, text = argument:match("^(%S*)%s*(.-)%s*$")
        action, text = action:lower(), CleanLabel(text, "")
        if action == "new" then
            if text == "" then ns.Say("Use /gh route new NAME."); return true end
            if ns.account.routes[text] then ns.Say("That route already exists. Use /gh route use NAME."); return true end
            ns.account.routes[text] = {points = {}}
            ns.db.activeRoute, ns.db.routeIndex = text, 1
            ns.Say("Created route " .. text .. ". Add a waypoint with /gh route add LABEL.")
        elseif action == "use" then
            if not ns.account.routes[text] then ns.Say("Unknown route. Create one with /gh route new NAME."); return true end
            ns.db.activeRoute, ns.db.routeIndex = text, 1
            RouteMessage()
        elseif action == "add" then
            local route = ns.db.activeRoute and ns.account.routes[ns.db.activeRoute]
            if not route then ns.Say("Create or select a route first."); return true end
            if #route.points >= 100 then ns.Say("Each route can contain up to 100 waypoints."); return true end
            local point = ns.CurrentPosition()
            if not point then ns.Say("Your map position is unavailable here."); return true end
            point.label, point.at, point.kind = CleanLabel(text, "Waypoint " .. (#route.points + 1)), ns.Now(), "route"
            route.points[#route.points + 1] = point
            ns.Say("Waypoint saved to " .. ns.db.activeRoute .. ".")
        elseif action == "next" then
            local points = ns.RoutePoints()
            if #points > 0 then ns.db.routeIndex = ((ns.db.routeIndex or 1) % #points) + 1 end
            RouteMessage()
        elseif action == "delete" then
            if not ns.account.routes[text] then ns.Say("Unknown route."); return true end
            ns.account.routes[text] = nil
            if ns.db.activeRoute == text then ns.db.activeRoute, ns.db.routeIndex = nil, 1 end
            ns.Say("Deleted route " .. text .. ".")
        else
            ns.Say("/gh route new NAME, add LABEL, use NAME, next, or delete NAME")
        end
        ns.RefreshMapPins()
    elseif command == "note" then
        local text = CleanLabel(argument, "")
        if text == "" then ns.Say("Use /gh note TEXT to save a zone note."); return true end
        local point = ns.CurrentPosition()
        ns.db.notes[#ns.db.notes + 1] = {text = text, at = ns.Now(), mapID = point and point.mapID,
            zone = point and point.zone or (GetZoneText and GetZoneText() or "Unknown zone")}
        if #ns.db.notes > 100 then table.remove(ns.db.notes, 1) end
        ns.Say("Zone note saved.")
    elseif command == "reset" then
        ns.SessionStats()
        ns.state.session = {loot = {}, started = Clock(), gathers = 0}
        ns.PendingGather = nil
        ns.Say("Session loot totals and timer reset.")
    else
        return false
    end
    return true
end

local function MakePin(canvas)
    local pin = CreateFrame("Button", nil, canvas)
    pin:SetSize(14, 14)
    local icon = pin:CreateTexture(nil, "OVERLAY")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\Icons\\INV_Misc_Herb_01")
    pin.icon = icon
    pin:SetScript("OnEnter", function(self)
        if not GameTooltip or not self.node then return end
        local node = self.node
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(node.label or "Herb observation")
        GameTooltip:AddLine(string.format("%.1f, %.1f", node.x * 100, node.y * 100), 1, 1, 1)
        GameTooltip:AddLine(node.kind == "route" and "Personal route waypoint" or
            "Historical observation; node availability unknown", 0.8, 0.7, 1, true)
        if node.at and date then GameTooltip:AddLine("Saved: " .. date("%Y-%m-%d %H:%M", node.at), 0.7, 0.7, 0.7) end
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return pin
end

function ns.RefreshMapPins()
    for _, pin in ipairs(mapPins) do pin:Hide() end
    local world = WorldMapFrame
    if not world or not world.IsShown or not world:IsShown() or not world.GetMapID or not world.GetCanvas then return end
    local canvas, mapID = world:GetCanvas(), world:GetMapID()
    if not canvas or not mapID or not canvas.GetWidth or not canvas.GetHeight then return end
    local width, height = canvas:GetWidth(), canvas:GetHeight()
    if width <= 0 or height <= 0 then return end
    lastCanvas, lastMap, lastWidth, lastHeight = canvas, mapID, width, height
    local count = 0
    local function Show(point, isRoute)
        if point.mapID ~= mapID then return end
        count = count + 1
        local pin = mapPins[count]
        if not pin then pin = MakePin(canvas); mapPins[count] = pin end
        pin:SetParent(canvas)
        pin.node = point
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", canvas, "TOPLEFT", point.x * width, -point.y * height)
        pin:SetSize(isRoute and 18 or 13, isRoute and 18 or 13)
        pin.icon:SetVertexColor(isRoute and 1 or 0.75, isRoute and 0.85 or 0.65, isRoute and 0.35 or 1)
        pin:SetFrameLevel((canvas:GetFrameLevel() or 0) + (isRoute and 30 or 20))
        pin:Show()
    end
    for _, node in ipairs(ns.account.nodes) do Show(node, false) end
    for _, point in ipairs(ns.RoutePoints()) do Show(point, true) end
end

-- World map navigation often happens independently of addon UI refreshes.
local mapWatcher = CreateFrame("Frame")
local elapsed = 0
mapWatcher:SetScript("OnUpdate", function(_, seconds)
    elapsed = elapsed + seconds
    if elapsed < 0.5 then return end
    elapsed = 0
    local world = WorldMapFrame
    if not ns.account or not world or not world.IsShown or not world:IsShown() then return end
    if not world.GetMapID or not world.GetCanvas then return end
    local canvas = world:GetCanvas()
    if world:GetMapID() ~= lastMap or canvas ~= lastCanvas or
        (canvas and (canvas:GetWidth() ~= lastWidth or canvas:GetHeight() ~= lastHeight)) then
        ns.RefreshMapPins()
    end
end)
