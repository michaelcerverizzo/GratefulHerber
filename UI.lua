local _, ns = ...

local window, body, content, scroll, commandBox, subtitle
local page = "Journal"
local tabs = {}
local gold, purple, muted = "|cffffd780", "|cffc9a0ef", "|cffb0a999"
local pages = {"Journal", "Alchemy", "Stash", "Routes", "Settings"}

local function SortedValues(values, compare)
    local result = {}
    for key, value in pairs(values or {}) do result[#result + 1] = {key = key, value = value} end
    table.sort(result, compare or function(a, b) return tostring(a.key) < tostring(b.key) end)
    return result
end

local function Section(lines, title)
    if #lines > 0 then lines[#lines + 1] = "" end
    lines[#lines + 1] = gold .. title .. "|r"
end

local function Icon(id)
    local texture = GetItemIcon and GetItemIcon(id)
    if not texture and GetItemInfo then texture = select(10, GetItemInfo(id)) end
    return texture and ("|T" .. texture .. ":16:16:0:0|t ") or ""
end

local function Duration(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    if seconds >= 86400 then return string.format("%dd %dh", math.floor(seconds / 86400), math.floor(seconds % 86400 / 3600)) end
    if seconds >= 3600 then return string.format("%dh %dm", math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)) end
    return string.format("%dm %ds", math.floor(seconds / 60), seconds % 60)
end

local function Timestamp(value)
    if not value then return "not checked yet" end
    return Duration(ns.Now() - value) .. " ago"
end

local function Money(copper)
    if copper == nil then return "prices needed" end
    local sign = copper < 0 and "-" or ""
    copper = math.floor(math.abs(copper) + 0.5)
    return string.format("%s%dg %ds %dc", sign, math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100)
end

local function Journal(lines)
    local stats = ns.SessionStats and ns.SessionStats() or {}
    Section(lines, "SET BREAK STATS")
    lines[#lines + 1] = string.format("%d herbs looted  ·  %s  ·  %.1f herbs/hour", stats.total or 0,
        Duration(stats.elapsed), stats.perHour or 0)
    lines[#lines + 1] = string.format("Confirmed gathering events: %d  ·  Best session rate: %.1f/hour", stats.gathers or 0, stats.bestPerHour or 0)
    lines[#lines + 1] = muted .. "Loot totals include herbs from any source. Best rates use sessions of at least one minute.|r"
    Section(lines, "HERBALISM JOURNAL  —  bags / looted this session")
    local any = false
    for _, herb in ipairs(ns.Herbs or {}) do
        local owned = ns.Count(herb[1])
        local looted = ns.state.session.loot[herb[1]] or 0
        if owned > 0 or looted > 0 then
            any = true
            lines[#lines + 1] = string.format("%s%s: %d / +%d", Icon(herb[1]), ns.ItemName(herb[1], herb[2]), owned, looted)
        end
    end
    if not any then lines[#lines + 1] = "Your next gathering trip starts here." end
    Section(lines, "PACKING LIST")
    local warnings = ns.PackingWarnings and ns.PackingWarnings() or {}
    for _, warning in ipairs(warnings) do lines[#lines + 1] = "! " .. warning end
    if #warnings == 0 then lines[#lines + 1] = "Supplies look good for your configured thresholds." end
    Section(lines, "ALCHEMY SETLIST  —  " .. (ns.db.activePlan or "Default"))
    local recipes = SortedValues(ns.Plan().recipes)
    for _, entry in ipairs(recipes) do
        lines[#lines + 1] = string.format("%s: %d planned crafts", entry.value.name or entry.key, entry.value.crafts or 0)
    end
    if #recipes == 0 then lines[#lines + 1] = "Select an Alchemy recipe, then enter: add 5" end
    Section(lines, "SHOPPING LIST  —  needed / bags / bank / alts / missing")
    local shopping = ns.ShoppingList()
    for _, item in ipairs(shopping) do
        local color = item.missing > 0 and "|cffffbb66" or "|cffb1e0b5"
        lines[#lines + 1] = string.format("%s%s: %d / %d / %d / %d / %s%d %s|r", Icon(item.id),
            ns.ItemName(item.id, item.name), item.needed, item.bags or 0, item.bank or 0, item.alts or 0,
            color, item.missing, item.missing > 0 and "NEEDED" or "READY")
    end
    if #shopping == 0 then lines[#lines + 1] = "Add recipes to build a combined reagent list." end
    lines[#lines + 1] = muted .. (ns.db.settings.stash and "Bank and alt snapshots count toward shortages; verify their freshness on Stash." or "Shortages currently use bags only. Enable stash counts to include saved stock.") .. "|r"
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Commands: add 5 · remove · clear · reset · plan save Raid Night"
end

local function Alchemy(lines)
    Section(lines, "READY FOR THE SHOW  —  craftable from your bags")
    local learned, ready = SortedValues(ns.db.learned), 0
    for _, entry in ipairs(learned) do
        local count = ns.Craftable and ns.Craftable(entry.value) or 0
        if count > 0 then
            ready = ready + 1
            lines[#lines + 1] = string.format("%s%s: %d crafts available", entry.value.outputID and Icon(entry.value.outputID) or "", entry.value.name or entry.key, count)
        end
    end
    if ready == 0 then lines[#lines + 1] = #learned == 0 and "Open your Alchemy window and press Scan recipes." or "No scanned recipes are currently craftable from your bags." end
    lines[#lines + 1] = muted .. "Only visible recipes in your own Alchemy window are scanned. Expand headers and clear filters first. You craft through WoW.|r"
    lines[#lines + 1] = muted .. "Availability uses reagents, recorded cooldowns, and last-scanned tools or stations. Rescan after moving or changing tools; check your profession window.|r"
    Section(lines, "ENCORE TIMERS")
    local cooldowns = SortedValues(ns.db.cooldowns)
    for _, entry in ipairs(cooldowns) do
        local remaining = math.max(0, (entry.value.readyAt or 0) - ns.Now())
        lines[#lines + 1] = string.format("%s: %s  (%s)", entry.key, remaining > 0 and Duration(remaining) or "READY", "checked " .. Timestamp(entry.value.seenAt))
    end
    if #cooldowns == 0 then lines[#lines + 1] = "Scan Alchemy while a transmute cooldown is active to record its timer." end
    Section(lines, "TICKET PRICE  —  manually entered prices")
    local planned = SortedValues(ns.Plan().recipes)
    for _, entry in ipairs(planned) do
        local cost = ns.RecipeCost and ns.RecipeCost(entry.value)
        local value = ns.RecipeValue and ns.RecipeValue(entry.value)
        local margin = cost ~= nil and value ~= nil and value - cost or nil
        lines[#lines + 1] = string.format("%s: %s per craft · output %s · margin %s", entry.value.name or entry.key, Money(cost), Money(value), Money(margin))
    end
    if #planned == 0 then lines[#lines + 1] = "Add a planned recipe to compare its reagent cost and output value." end
    lines[#lines + 1] = muted .. "Gross estimates exclude Auction House deposits and cuts; output uses minimum recipe yield.|r"
    for _, entry in ipairs(SortedValues(ns.db.prices)) do
        lines[#lines + 1] = string.format("%s [%s]: %s each · updated %s", ns.ItemName(entry.key), entry.key, Money(entry.value.copper), Timestamp(entry.value.updatedAt))
    end
    Section(lines, "RECIPE SONGBOOK  —  curated Classic Era collection")
    local knownOutputs = {}
    for _, entry in ipairs(learned) do if entry.value.outputID then knownOutputs[entry.value.outputID] = true end end
    for _, recipe in ipairs(ns.Catalog or {}) do
        lines[#lines + 1] = string.format("%s %s%s — %s", knownOutputs[recipe.outputID] and "[LEARNED]" or "[NOT RECORDED]",
            recipe.outputID and Icon(recipe.outputID) or "", recipe.name, recipe.source or "")
    end
    lines[#lines + 1] = muted .. "This reference is not exhaustive. Not recorded can mean unlearned, filtered out, or not scanned yet.|r"
    Section(lines, "SAVED SETLISTS")
    for _, entry in ipairs(SortedValues(ns.db.plans)) do
        local count = 0
        for _ in pairs(entry.value.recipes or {}) do count = count + 1 end
        lines[#lines + 1] = string.format("%s%s · %d recipes", entry.key == ns.db.activePlan and "> " or "", entry.key, count)
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Commands: scan · price ITEMID COPPER · unprice ITEMID"
    lines[#lines + 1] = "plan new Raid Night · plan save Raid Night · plan use Raid Night · plan delete Raid Night"
end

local function Stash(lines)
    Section(lines, "BACKSTAGE STASH")
    lines[#lines + 1] = "Use saved bank and alt stock in shopping shortages: " .. (ns.db.settings.stash and "ON" or "OFF")
    lines[#lines + 1] = muted .. "Snapshots update when a character is played and its bank is visited. They are not live inventory.|r"
    local own = ns.account.characters[ns.charKey]
    local any = false
    for _, entry in ipairs(SortedValues(ns.account.characters)) do
        local character = entry.value
        if not own or (character.realm == own.realm and character.faction == own.faction) then
            any = true
            Section(lines, string.format("%s — %s%s", character.name or entry.key, character.realm or "", entry.key == ns.charKey and " (you)" or ""))
            lines[#lines + 1] = "Bags checked " .. Timestamp(character.bagsAt) .. " · Bank checked " .. Timestamp(character.bankAt)
            local shown = 0
            for _, herb in ipairs(ns.Herbs or {}) do
                local bags, bank = (character.bags or {})[herb[1]] or 0, (character.bank or {})[herb[1]] or 0
                if bags > 0 or bank > 0 then
                    shown = shown + 1
                    lines[#lines + 1] = string.format("%s%s: %d bags / %d bank", Icon(herb[1]), ns.ItemName(herb[1], herb[2]), bags, bank)
                end
            end
            if shown == 0 then lines[#lines + 1] = "No herbs in this saved snapshot." end
        end
    end
    if not any then lines[#lines + 1] = "No inventory snapshots recorded yet." end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Only characters on this realm and faction contribute to your shortages."
    lines[#lines + 1] = "Commands: stash on · stash off"
end

local function PointLabel(point)
    return string.format("%s — map %s, %.1f / %.1f", point.label or "Waypoint", point.mapID or "?", (point.x or 0) * 100, (point.y or 0) * 100)
end

local function Routes(lines)
    Section(lines, "TOUR PLANNER")
    lines[#lines + 1] = "Active route: " .. (ns.db.activeRoute or "none")
    local points = ns.RoutePoints and ns.RoutePoints() or {}
    for i, point in ipairs(points) do
        lines[#lines + 1] = string.format("%s%d. %s", i == (ns.db.routeIndex or 1) and "> " or "", i, PointLabel(point))
    end
    if #points == 0 then lines[#lines + 1] = "Create a named route, then add waypoints as you travel." end
    lines[#lines + 1] = muted .. "Waypoints guide your trip. You steer, interact, and gather yourself.|r"
    Section(lines, "SAVED TOURS")
    for _, entry in ipairs(SortedValues(ns.account.routes)) do
        lines[#lines + 1] = string.format("%s · %d waypoints", entry.key, #(entry.value.points or {}))
    end
    Section(lines, "SCARLET BEGONIAS JOURNAL")
    local nodes = ns.account.nodes or {}
    lines[#lines + 1] = string.format("%d saved observations and manual pins. Open the world map to view marks for its current zone.", #nodes)
    lines[#lines + 1] = muted .. "Historical observations do not indicate current node availability. Gather positions are approximate.|r"
    for i = #nodes, math.max(1, #nodes - 19), -1 do
        local node = nodes[i]
        lines[#lines + 1] = PointLabel(node) .. " · " .. Timestamp(node.at)
    end
    Section(lines, "ZONE NOTES")
    for _, note in ipairs(ns.db.notes or {}) do
        lines[#lines + 1] = string.format("%s — %s", note.zone or ("Map " .. (note.mapID or "?")), note.text or "")
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Commands: route new Evening Tour · route add Riverbank · route next"
    lines[#lines + 1] = "route use Evening Tour · route delete Evening Tour · pin Favorite patch"
    lines[#lines + 1] = "note Check the north side of the lake"
end

local function Settings(lines)
    local settings = ns.db.settings
    Section(lines, "STAGE LIGHTS")
    lines[#lines + 1] = "Purple and gold journal with built-in item artwork. Shortages use words as well as color."
    lines[#lines + 1] = string.format("Text size: %d  ·  Change with: font 11 through font 20", settings.fontSize or 13)
    Section(lines, "OPTIONAL SOUND FLAIR")
    lines[#lines + 1] = "Current sound mode: " .. (settings.sound or "off")
    lines[#lines + 1] = "off: silent · builtin: WoW UI chime · custom: bundled original musical cues"
    lines[#lines + 1] = "You may replace Media/herb.ogg, craft.ogg, and ready.ogg with authorized short clips."
    lines[#lines + 1] = "Restart WoW after replacing files. Sound cues are throttled."
    lines[#lines + 1] = "Use audio you created or have permission to use. No Grateful Dead recordings are bundled."
    lines[#lines + 1] = "Commands: sound off · sound builtin · sound custom · sound test"
    Section(lines, "PACKING REMINDERS")
    lines[#lines + 1] = string.format("Low vial threshold: %d  ·  Low free bag slots: %d", settings.lowVials or 5, settings.bagSlots or 5)
    lines[#lines + 1] = "Commands: threshold vials 5 · threshold bags 5"
    Section(lines, "QUICK HELP")
    lines[#lines + 1] = "Enter commands below, with or without /gh. Open or close the journal with /gh or the minimap leaf."
    lines[#lines + 1] = "Commands: page journal · page alchemy · page stash · page routes · page settings"
    lines[#lines + 1] = "Alchemy: select a recipe in your own Alchemy window, then add 5. Quantities mean crafts."
    lines[#lines + 1] = "Plans stay until you adjust them. Crafting does not automatically reduce the active plan."
    lines[#lines + 1] = "Bank and alt stock are last-seen snapshots. Price estimates use your manual copper-per-item prices."
    lines[#lines + 1] = "Drag the title area to move this window. Escape closes it."
end

local renderers = {Journal = Journal, Alchemy = Alchemy, Stash = Stash, Routes = Routes, Settings = Settings}

function ns.Refresh()
    if not window or not ns.db or not window:IsShown() then return end
    local lines = {}
    renderers[page](lines)
    local path, _, flags = body:GetFont()
    body:SetFont(path or STANDARD_TEXT_FONT, ns.db.settings.fontSize or 13, flags)
    body:SetText(table.concat(lines, "\n"))
    local height = body:GetStringHeight() + 24
    body:SetHeight(height)
    content:SetHeight(height)
    subtitle:SetText("A long, strange gathering trip  ·  " .. page)
    for name, button in pairs(tabs) do
        button:SetEnabled(name ~= page)
    end
    if ns.RefreshMapPins then ns.RefreshMapPins() end
end

function ns.SetPage(name)
    if not renderers[name] then return end
    page = name
    if scroll then scroll:SetVerticalScroll(0) end
    ns.Refresh()
end

function ns.Toggle(forceShown)
    if not window then return end
    if forceShown == true then window:Show()
    elseif forceShown == false then window:Hide()
    elseif window:IsShown() then window:Hide() else window:Show() end
end

local function Tooltip(owner, title, description)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title)
    GameTooltip:AddLine(description, 1, 1, 1, true)
    GameTooltip:Show()
end

local function Button(parent, label, width, action)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetText(label)
    button:SetScript("OnClick", action)
    return button
end

function ns.CreateUI()
    window = CreateFrame("Frame", "GratefulHerberFrame", UIParent, "BasicFrameTemplateWithInset")
    ns.panel = window
    window:SetSize(760, 600)
    local position = ns.db.window
    if position and position.point then
        window:SetPoint(position.point, UIParent, position.relativePoint or position.point, position.x or 0, position.y or 0)
    else
        window:SetPoint("CENTER")
    end
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", function(self) self:StartMoving() end)
    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        ns.db.window = {point = point, relativePoint = relativePoint, x = x, y = y}
    end)
    window.TitleText:SetText("Grateful Herber")
    window.TitleText:SetTextColor(1, 0.84, 0.5)
    local background = CreateFrame("Frame", nil, window, BackdropTemplateMixin and "BackdropTemplate" or nil)
    background:SetPoint("TOPLEFT", 5, -25)
    background:SetPoint("BOTTOMRIGHT", -5, 5)
    if background.SetBackdrop then
        background:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = {left = 4, right = 4, top = 4, bottom = 4}})
        background:SetBackdropColor(0.055, 0.035, 0.07, 0.97)
        background:SetBackdropBorderColor(0.55, 0.36, 0.65, 1)
    end
    background:SetFrameLevel(window:GetFrameLevel())
    subtitle = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    subtitle:SetPoint("TOPLEFT", 20, -35)
    subtitle:SetTextColor(0.79, 0.63, 0.94)
    for i, name in ipairs(pages) do
        local button = Button(window, name, 138, function() ns.SetPage(name) end)
        button:SetPoint("TOPLEFT", 20 + (i - 1) * 143, -57)
        tabs[name] = button
    end
    local scanButton = Button(window, "Scan recipes", 130, function() ns.Command("scan") end)
    scanButton:SetPoint("TOPLEFT", 20, -88)
    local addButton = Button(window, "Plan selected x5", 140, function() ns.Command("add 5") end)
    addButton:SetPoint("LEFT", scanButton, "RIGHT", 8, 0)
    local stashButton = Button(window, "Toggle stash counts", 155, function()
        ns.Command(ns.db.settings.stash and "stash off" or "stash on")
    end)
    stashButton:SetPoint("LEFT", addButton, "RIGHT", 8, 0)
    local soundButton = Button(window, "Test sound", 110, function() ns.Command("sound test") end)
    soundButton:SetPoint("LEFT", stashButton, "RIGHT", 8, 0)
    scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 24, -123)
    scroll:SetPoint("BOTTOMRIGHT", -38, 67)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(682, 1)
    body = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOPLEFT", 0, -2)
    body:SetWidth(682)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetSpacing(5)
    scroll:SetScrollChild(content)
    local commandLabel = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    commandLabel:SetPoint("BOTTOMLEFT", 24, 47)
    commandLabel:SetText("Command  ·  e.g. add 5, plan save Raid Night, or route new Evening Tour")
    commandBox = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
    commandBox:SetSize(608, 26)
    commandBox:SetPoint("BOTTOMLEFT", 30, 17)
    commandBox:SetAutoFocus(false)
    commandBox:SetMaxLetters(180)
    local function RunCommand()
        local command = commandBox:GetText() or ""
        command = command:gsub("^%s*/gratefulherber%s*", ""):gsub("^%s*/gh%s*", "")
        if command ~= "" then ns.Command(command) end
        commandBox:ClearFocus()
    end
    commandBox:SetScript("OnEnterPressed", RunCommand)
    commandBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local runButton = Button(window, "Run", 75, RunCommand)
    runButton:SetPoint("LEFT", commandBox, "RIGHT", 12, 0)
    window:SetScript("OnShow", ns.Refresh)
    table.insert(UISpecialFrames, "GratefulHerberFrame")
    window:Hide()

    if Minimap then
        local minimapButton = CreateFrame("Button", "GratefulHerberMinimapButton", Minimap)
        ns.minimapButton = minimapButton
        minimapButton:SetSize(31, 31)
        minimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -7, 7)
        minimapButton:SetFrameStrata("MEDIUM")
        local texture = minimapButton:CreateTexture(nil, "BACKGROUND")
        texture:SetTexture("Interface\\Icons\\INV_Misc_Herb_01")
        texture:SetPoint("TOPLEFT", 5, -5)
        texture:SetPoint("BOTTOMRIGHT", -5, 5)
        local border = minimapButton:CreateTexture(nil, "OVERLAY")
        border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        border:SetSize(54, 54)
        border:SetPoint("TOPLEFT")
        minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        minimapButton:SetScript("OnClick", ns.Toggle)
        minimapButton:SetScript("OnEnter", function(self) Tooltip(self, "Grateful Herber", "Open your herbalism journal and Alchemy setlists.") end)
        minimapButton:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        minimapButton:SetShown(ns.db.settings.minimap ~= false)
    end
end
