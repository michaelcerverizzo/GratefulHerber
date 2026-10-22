local addonName, ns = ...
local events = CreateFrame("Frame")
local initialized, pendingRefresh = false, false

local function RefreshSoon()
    if pendingRefresh or not initialized then return end
    pendingRefresh = true
    local function update()
        pendingRefresh = false
        ns.Refresh()
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.15, update) else update() end
end

function ns.Command(message)
    if not initialized then return end
    local command, arg = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "" then ns.Toggle(); return end
    local handled = ns.CoreCommand(command,arg) or ns.ProfessionCommand(command,arg) or ns.JournalCommand(command,arg)
    if not handled then
        if command == "help" then ns.SetPage("Settings"); ns.Toggle(true)
        elseif command == "page" then
            local name = arg:sub(1,1):upper() .. arg:sub(2):lower()
            if name == "Journal" or name == "Alchemy" or name == "Stash" or name == "Routes" or name == "Settings" then
                ns.SetPage(name); ns.Toggle(true)
            else ns.Say("/gh page journal, alchemy, stash, routes, or settings") end
        elseif command == "journal" or command == "alchemy" or command == "routes" or command == "settings" then
            ns.SetPage(command:sub(1,1):upper() .. command:sub(2)); ns.Toggle(true)
        else ns.Say("/gh opens the journal. /gh help lists commands.") end
    end
    ns.Refresh()
end

events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= addonName or initialized then return end
        ns.Initialize()
        initialized = true
        ns.CreateUI()
        SLASH_GRATEFULHERBER1, SLASH_GRATEFULHERBER2 = "/gh", "/gratefulherber"
        SlashCmdList.GRATEFULHERBER = ns.Command
        for _, name in ipairs({"BAG_UPDATE_DELAYED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED",
            "CHAT_MSG_LOOT", "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "GET_ITEM_INFO_RECEIVED",
            "UNIT_SPELLCAST_SUCCEEDED", "PLAYER_LOGOUT", "PLAYER_ENTERING_WORLD"}) do events:RegisterEvent(name) end
        if WorldMapFrame and WorldMapFrame.HookScript then
            WorldMapFrame:HookScript("OnShow", function() ns.RefreshMapPins() end)
        end
        if WorldMapFrame and WorldMapFrame.OnMapChanged and hooksecurefunc then
            hooksecurefunc(WorldMapFrame,"OnMapChanged",function() ns.RefreshMapPins() end)
        end
        if C_Timer and C_Timer.NewTicker then
            ns.state.ticker = C_Timer.NewTicker(5, function()
                ns.CheckCooldowns(); ns.Refresh(); ns.RefreshMapPins()
            end)
        end
    elseif not initialized then return
    elseif event == "CHAT_MSG_LOOT" then ns.HandleLoot(...)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" then
            ns.RecordGather(spellID)
            local spellName = GetSpellInfo and GetSpellInfo(spellID)
            if spellName and ns.db.learned[spellName] then ns.PlayCue("craft") end
        end
    elseif event == "BANKFRAME_OPENED" then ns.state.bankOpen = true; ns.UpdateInventory()
    elseif event == "BANKFRAME_CLOSED" then ns.state.bankOpen = false; ns.UpdateInventory()
    elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYERBANKSLOTS_CHANGED" then ns.UpdateInventory()
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" then ns.ScanAlchemy()
    elseif event == "PLAYER_LOGOUT" then ns.UpdateInventory(); ns.SessionStats()
    elseif event == "PLAYER_ENTERING_WORLD" then ns.UpdateInventory()
    end
    RefreshSoon()
end)
