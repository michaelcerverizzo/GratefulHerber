-- Mocked Classic Era integration tests; these do not certify the live game client.
local frames, fontStrings, messages, sounds = {}, {}, {}, {}
local epoch, uptime = 1700000000, 10
local noop = function() end
local function fontString()
    local t = {height=20,text=""}
    for _, method in ipairs({"SetPoint","SetWidth","SetJustifyH","SetJustifyV","SetSpacing",
        "SetTextColor","SetShadowColor","SetShadowOffset","Show","Hide","ClearAllPoints",
        "SetAllPoints","SetAlpha","SetWordWrap","SetNonSpaceWrap","SetFormattedText"}) do t[method]=noop end
    function t:SetText(text) self.text=text or "" end
    function t:GetText() return self.text end
    function t:SetHeight(n) self.height=n end
    function t:GetHeight() return self.height end
    function t:GetStringHeight() return 20 + #self.text/5 end
    function t:GetStringWidth() return #self.text*7 end
    function t:SetFont(path,size,flags) self.font={path,size,flags}; return true end
    function t:GetFont() return "Fonts\\FRIZQT__.TTF",13,"" end
    fontStrings[#fontStrings+1]=t
    return t
end
local function texture()
    local t={}
    for _, method in ipairs({"SetTexture","SetColorTexture","SetPoint","SetSize","SetAllPoints",
        "SetTexCoord","SetVertexColor","SetAlpha","Show","Hide","SetBlendMode","SetDrawLayer"}) do t[method]=noop end
    return t
end
local function frame(kind,name)
    local f={scripts={},events={},shown=false,height=500,width=760,text="",name=name,kind=kind}
    for _, method in ipairs({"SetMovable","EnableMouse","RegisterForDrag","SetClampedToScreen",
        "SetJustifyH","SetJustifyV","SetSpacing","SetScrollChild","StartMoving","StopMovingOrSizing",
        "ClearAllPoints","SetAllPoints","SetBackdrop","SetBackdropColor","SetBackdropBorderColor",
        "SetNormalTexture","SetPushedTexture","SetHighlightTexture","SetDisabledTexture","SetFrameStrata",
        "SetFrameLevel","SetAutoFocus","SetMaxLetters","SetMultiLine","SetTextInsets","SetNumeric",
        "SetHitRectInsets","RegisterForClicks","EnableMouseWheel","SetClipsChildren","SetResizable",
        "SetResizeBounds","SetScale","SetAlpha","SetPropagateKeyboardInput","EnableKeyboard"}) do f[method]=noop end
    function f:SetPoint(...) self.point={...} end
    function f:GetPoint() return "CENTER",nil,"CENTER",0,0 end
    function f:SetSize(w,h) self.width=w;self.height=h end
    function f:SetWidth(n) self.width=n end
    function f:SetHeight(n) self.height=n end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:GetEffectiveScale() return 1 end
    function f:GetFrameLevel() return 1 end
    function f:SetParent(parent) self.parent=parent end
    function f:SetText(text) self.text=text or "" end
    function f:GetText() return self.text end
    function f:GetName() return self.name end
    function f:SetFont(...) return true end
    function f:SetFontObject(...) end
    function f:GetFontString() self.label=self.label or fontString();return self.label end
    function f:CreateFontString() return fontString() end
    function f:CreateTexture() return texture() end
    function f:GetNormalTexture() self.normal=self.normal or texture();return self.normal end
    function f:SetScript(event,callback) self.scripts[event]=callback end
    function f:GetScript(event) return self.scripts[event] end
    function f:HookScript(event,callback)
        local old=self.scripts[event]
        self.scripts[event]=function(...) if old then old(...) end;callback(...) end
    end
    function f:RegisterEvent(event) self.events[event]=true end
    function f:UnregisterEvent(event) self.events[event]=nil end
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown end
    function f:Show() self.shown=true;if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function f:Hide() self.shown=false;if self.scripts.OnHide then self.scripts.OnHide(self) end end
    function f:SetShown(shown) if shown then self:Show() else self:Hide() end end
    function f:SetFocus() self.focus=true end
    function f:ClearFocus() self.focus=false end
    function f:SetCursorPosition(...) end
    function f:SetVerticalScroll(n) self.scroll=n end
    function f:GetVerticalScroll() return self.scroll or 0 end
    function f:GetVerticalScrollRange() return 1000 end
    function f:Enable() self.disabled=false end
    function f:Disable() self.disabled=true end
    function f:SetEnabled(enabled) self.disabled=not enabled end
    frames[#frames+1]=f
    if name then _G[name]=f end
    return f
end
UIParent=frame("Frame","UIParent");UIParent:Show()
Minimap=frame("Frame","Minimap");Minimap:Show()
UISpecialFrames={};SlashCmdList={};SOUNDKIT={READY_CHECK=8960,IG_QUEST_LOG_OPEN=844}
GameFontHighlightSmall=fontString();GameFontNormal=fontString()
DEFAULT_CHAT_FRAME={AddMessage=function(_,text) messages[#messages+1]=text end}
GameTooltip={SetOwner=noop,SetText=noop,AddLine=noop,Show=noop,Hide=noop,ClearLines=noop}
function CreateFrame(kind,name,_,template)
    local f=frame(kind,name)
    if template and template:find("BasicFrameTemplate") then f.TitleText=fontString();f.CloseButton=frame("Button") end
    return f
end
function GetTime() return uptime end
function time() return epoch end
function date(format,stamp) return os.date(format,stamp) end
function UnitName() return "Herbalist" end
function GetRealmName() return "TestRealm" end
function UnitFactionGroup() return "Alliance" end
function UnitGUID() return "Player-1" end
function InCombatLockdown() return false end
function GetMoney() return 100000 end
function GetLocale() return "enUS" end
function GetBuildInfo() return "1.15.8","1","Oct 2026",11508 end
function GetCursorPosition() return 100,100 end
function PlaySound(id,channel) sounds[#sounds+1]={id=id,channel=channel};return true,1 end
function PlaySoundFile(path,channel) sounds[#sounds+1]={path=path,channel=channel};return true,1 end
function StopSound() end
function GetItemIcon() return "Interface\\Icons\\INV_Misc_Herb_01" end
local names={[2447]="Peacebloom",[765]="Silverleaf",[2449]="Earthroot",[3371]="Empty Vial",
    [118]="Potion A",[2454]="Potion B",[12360]="Arcanite Bar",[12359]="Thorium Bar",[12363]="Arcane Crystal"}
function GetItemInfo(id)
    if type(id)=="string" then id=tonumber(id:match("item:(%d+)")) or tonumber(id) end
    return names[id],"item:"..tostring(id),1,1,1,"Trade Goods","Herb",20,"",GetItemIcon()
end
local bags={[0]={{2447,3},{765,4},{3371,5}},[-1]={{2447,7}},[5]={{765,8}}}
NUM_BAG_SLOTS=4;NUM_BANKBAGSLOTS=7;BACKPACK_CONTAINER=0;BANK_CONTAINER=-1
local function containerItems(bag) return bags[bag] or {} end
local function countItems(id,bank)
    local count=0
    for bag,items in pairs(bags) do
        if (bag>=0 and bag<=4) or (bank and (bag==-1 or bag>=5)) then
            for _,item in ipairs(items) do if item[1]==id then count=count+item[2] end end
        end
    end
    return count
end
function GetItemCount(id,bank) return countItems(id,bank) end
function GetContainerNumSlots(bag) return #containerItems(bag)+2 end
function GetContainerItemID(bag,slot) local item=containerItems(bag)[slot];return item and item[1] end
function GetContainerItemInfo(bag,slot)
    local item=containerItems(bag)[slot];if item then return GetItemIcon(),item[2],false,1,false,false,"item:"..item[1] end
end
function GetContainerItemLink(bag,slot) local id=GetContainerItemID(bag,slot);return id and "item:"..id end
function GetContainerNumFreeSlots(bag) return 2,0 end
C_Container={GetContainerNumSlots=GetContainerNumSlots,GetContainerItemID=GetContainerItemID,
    GetContainerItemLink=GetContainerItemLink,GetContainerNumFreeSlots=GetContainerNumFreeSlots,
    GetContainerItemInfo=function(bag,slot)
        local item=containerItems(bag)[slot]
        if item then return {itemID=item[1],stackCount=item[2],hyperlink="item:"..item[1]} end
    end}
local profession,selection,linked="Alchemy",1,false
local recipeData={
    {name="Potion A",output=118,min=1,max=1,reagents={{2447,1},{765,2}}},
    {name="Potion B",output=2454,min=2,max=3,reagents={{2447,2},{2449,1}}},
    {name="Transmute: Arcanite",output=12360,min=1,max=1,reagents={{12359,1},{12363,1}}},
}
local cooldown=3600
function GetSpellInfo(id)
    if id==2259 then return "Alchemy" end
    if id==2366 or id==2368 or id==3570 or id==11993 or id==28695 then return "Herb Gathering" end
end
function GetTradeSkillLine() return profession,100,150 end
function IsTradeSkillLinked() return linked end
function GetNumTradeSkills() return #recipeData end
function GetTradeSkillSelectionIndex() return selection end
function GetTradeSkillInfo(index) local r=recipeData[index];if r then return r.name,"optimal",99,false end end
function GetTradeSkillNumReagents(index) return #recipeData[index].reagents end
function GetTradeSkillReagentInfo(index,i)
    local r=recipeData[index].reagents[i];return names[r[1]],GetItemIcon(),r[2],countItems(r[1])
end
local missingLink=false
function GetTradeSkillReagentItemLink(index,i)
    if missingLink then return nil end
    return "item:"..recipeData[index].reagents[i][1]
end
function GetTradeSkillItemLink(index) return "item:"..recipeData[index].output end
function GetTradeSkillRecipeLink(index) return "spell:"..index end
function GetTradeSkillNumMade(index) return recipeData[index].min,recipeData[index].max end
function GetTradeSkillCooldown(index) return index==3 and cooldown or nil end
function IsTradeSkillReady() return true end
LOOT_ITEM_SELF="You receive loot: %s."
LOOT_ITEM_SELF_MULTIPLE="You receive loot: %sx%d."
local mapID,mapX,mapY=1429,0.25,0.50
C_Map={GetBestMapForUnit=function() return mapID end,
    GetPlayerMapPosition=function() return {GetXY=function() return mapX,mapY end,x=mapX,y=mapY} end,
    GetMapInfo=function() return {name="Elwynn Forest"} end}
local canvas=frame("Frame");canvas:SetSize(1000,700)
WorldMapFrame=frame("Frame","WorldMapFrame")
function WorldMapFrame:GetMapID() return mapID end
function WorldMapFrame:GetCanvas() return canvas end
function hooksecurefunc(target,name,callback)
    if type(target)=="table" then
        local old=target[name]
        target[name]=function(...) if old then old(...) end;return callback(...) end
    end
end
C_Timer={After=function(_,callback) callback() end,NewTicker=function(_,callback) return {Cancel=noop,callback=callback} end}
for _,name in ipairs({"DoTradeSkill","CastSpellByName","CastSpellByID","UseContainerItem","InteractUnit",
    "MoveForwardStart","LootSlot","BuyMerchantItem","SendChatMessage","StartAuction","PlaceAuctionBid"}) do
    _G[name]=function() error("Addon attempted gameplay automation: "..name) end
end

local checks=0
local function check(condition,message) assert(condition,message);checks=checks+1 end
local function fire(event,...)
    local count=#frames
    for i=1,count do local f=frames[i];if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f,event,...) end end
end
local function loadAddon()
    local ns={}
    for line in io.lines("GratefulHerber.toc") do
        local path=line:match("^%s*([^#%s].-%.lua)%s*$")
        if path then assert(loadfile(path))("GratefulHerber",ns) end
    end
    fire("ADDON_LOADED","GratefulHerber")
    return ns
end
-- Preserve a v0.1 plan when the saved-variable schema changes.
GratefulHerberDB={recipes={Legacy={name="Legacy",crafts=2,reagents={{id=2447,name="Peacebloom",count=1}}}}}
local ns=loadAddon()
check(ns.Plan and ns.Plan().recipes.Legacy,"Legacy plan was not migrated")
check(ns.db.settings.sound=="off","Audio must be opt-in")
check(type(ns.Command)=="function","Slash command handler not installed")
check(type(SlashCmdList.GRATEFULHERBER)=="function","Slash command alias not installed")
local command=ns.Command
command("clear")
command("add 2");selection=2;command("add 3")
local function shopping(id)
    for _,row in ipairs(ns.ShoppingList()) do if row.id==id then return row end end
    error("Missing shopping row "..id)
end
check(shopping(2447).needed==8,"Shared reagents must be summed across recipes")
check(shopping(2447).bags==3 and shopping(2447).missing==5,"Bag shortages incorrect")
check(ns.Plan().recipes["Potion B"].crafts==3,"Quantity means crafts, not output items")
command("add 0");command("add 1.5");command("add 1000")
check(ns.Plan().recipes["Potion B"].crafts==3,"Invalid craft quantities modified a plan")
profession="Blacksmithing";command("add 8");profession="Alchemy"
linked=true;command("add 8");linked=false
check(ns.Plan().recipes["Potion B"].crafts==3,"Wrong profession or linked skill changed the plan")
missingLink=true;command("add 8");missingLink=false
check(ns.Plan().recipes["Potion B"].crafts==3,"Incomplete reagent data changed a plan")

command("plan save Raid Night")
command("clear")
command("plan use Default")
check(ns.Plan().recipes["Potion A"]~=nil,"Named plans share mutable recipe data")
command("plan use Raid Night")
check(next(ns.Plan().recipes)==nil,"Named plan selection failed")
command("plan use Default")

ns.state.bankOpen=true;ns.UpdateInventory();ns.state.bankOpen=false
local own=ns.account.characters[ns.charKey]
check(own and own.bankAt and own.bagsAt,"Inventory snapshots lack timestamps")
ns.account.characters["alt"]={name="Alt",realm="TestRealm",faction="Alliance",bags={[2447]=2},bank={[2447]=1},bagsAt=epoch,bankAt=epoch}
ns.account.characters["foreign"]={name="Foreign",realm="OtherRealm",faction="Alliance",bags={[2447]=999},bank={},bagsAt=epoch}
ns.account.characters["enemy"]={name="Enemy",realm="TestRealm",faction="Horde",bags={[2447]=999},bank={},bagsAt=epoch}
command("stash on")
check(shopping(2447).bank==7 and shopping(2447).alts==3,"Stash mixes realms/factions or double-counts this character")
check(shopping(2447).missing==0,"Available stash should cover the shortage")
command("stash off")
check(shopping(2447).missing==5,"Stash toggle did not restore bags-only planning")

command("scan")
check(ns.db.learned["Potion A"] and ns.db.learned["Potion B"],"Alchemy scan missed visible recipes")
check(ns.Craftable(ns.db.learned["Potion A"])==2,"Craftable count did not use limiting reagent")
check(ns.Craftable(ns.db.learned["Transmute: Arcanite"])==0,"Cooldown recipe should not be ready")
check(ns.db.cooldowns["Transmute: Arcanite"].readyAt==epoch+3600,"Cooldown finish time incorrect")
bags[0][#bags[0]+1]={12359,1};bags[0][#bags[0]+1]={12363,1}
check(ns.Craftable(ns.db.learned["Transmute: Arcanite"])==0,"Active cooldown ignored when reagents are available")
cooldown=0;command("scan")
check(ns.Craftable(ns.db.learned["Transmute: Arcanite"])==1,"Ready transmute did not become craftable")
check(ns.db.cooldowns["Potion A"]==nil,"Ordinary potion was added to cooldown timers")
cooldown=3600;command("scan")
local cost=ns.RecipeCost(ns.db.learned["Potion A"])
check(cost==nil,"An unpriced recipe must not appear free")
command("price 2447 100");command("price 765 200");command("price 118 1000")
check(ns.RecipeCost(ns.db.learned["Potion A"])==500,"Reagent cost incorrect")
check(ns.RecipeValue(ns.db.learned["Potion A"])==1000,"Output value incorrect")
command("price 2454 1000")
check(ns.RecipeValue(ns.db.learned["Potion B"])==2000,"Multi-output estimate must use minimum yield")
command("price 2447 -1")
check(ns.db.prices[2447].copper==100,"Negative prices accepted")
command("unprice 765")
check(ns.RecipeCost(ns.db.learned["Potion A"])==nil,"Incomplete prices produced a misleading total")

local herbLink="|Hitem:2447:0|h[Peacebloom]|h|r"
fire("CHAT_MSG_LOOT","Someone receives loot: "..herbLink.."x99.")
check((ns.state.session.loot[2447] or 0)==0,"Another player's loot was counted")
fire("CHAT_MSG_LOOT","You receive loot: "..herbLink.."x3.")
fire("CHAT_MSG_LOOT","You receive loot: "..herbLink..".")
check(ns.state.session.loot[2447]==4,"Personal herb loot counts incorrect")
LOOT_ITEM_SELF_MULTIPLE="Vous recevez : %1$s x%2$d."
fire("CHAT_MSG_LOOT","Vous recevez : "..herbLink.." x2.")
check(ns.state.session.loot[2447]==6,"Positional localized loot format not supported")
LOOT_ITEM_SELF_MULTIPLE="%2$d exemplaires reçus : %1$s."
fire("CHAT_MSG_LOOT","2 exemplaires reçus : "..herbLink..".")
check(ns.state.session.loot[2447]==8,"Reordered localized loot arguments not supported")
uptime=uptime+120;epoch=epoch+120
local stats=ns.SessionStats()
check(stats.total==8 and math.abs(stats.perHour-240)<0.01,"Session rate incorrect")
check(stats.bestPerHour==240,"Personal session record was not saved")
command("reset")
check(ns.SessionStats().total==0,"Reset did not clear session totals")

LOOT_ITEM_SELF_MULTIPLE="You receive loot: %sx%d."
local priorNodes=#ns.account.nodes
fire("UNIT_SPELLCAST_SUCCEEDED","player","cast-1",2366)
fire("CHAT_MSG_LOOT","You receive loot: "..herbLink.."x2.")
check(ns.SessionStats().gathers==1 and #ns.account.nodes==priorNodes+1,"Confirmed gather did not create a historical pin")
fire("UNIT_SPELLCAST_SUCCEEDED","player","cast-2",2366)
fire("CHAT_MSG_LOOT","You receive loot: "..herbLink..".")
check(ns.SessionStats().gathers==2 and #ns.account.nodes==priorNodes+1,"Repeated gathering location was not deduplicated")
fire("UNIT_SPELLCAST_SUCCEEDED","player","cast-3",2366)
uptime=uptime+6;epoch=epoch+6
fire("CHAT_MSG_LOOT","You receive loot: "..herbLink..".")
check(ns.SessionStats().gathers==2,"Expired gathering observation counted unrelated loot")

command("route new Elwynn Tour")
command("route add Peacebloom patch")
mapX=0.5;mapY=0.6;command("route add River bank")
check(#ns.RoutePoints()==2,"Route did not retain waypoints")
command("route next")
check(ns.db.routeIndex==2,"Route advance failed")
command("pin Personal marker")
check(#ns.account.nodes>0,"Manual map pin was not saved")
WorldMapFrame:Show();ns.RefreshMapPins()
local visiblePins=0
for _,f in ipairs(frames) do if f.node and f.shown then visiblePins=visiblePins+1 end end
check(visiblePins>=3,"Current map did not render historical/route pins")
mapID=1431;ns.RefreshMapPins()
local otherMapPins=0
for _,f in ipairs(frames) do if f.node and f.shown then otherMapPins=otherMapPins+1 end end
check(otherMapPins==0,"Map displayed observations from another zone")
mapID=1429;WorldMapFrame:Hide()
command("note Bring extra vials")
check(#ns.db.notes>0,"Zone note was not saved")
local mapAPI=C_Map;C_Map=nil
local ok=pcall(function() command("pin Unsupported map");command("route add No map");ns.RefreshMapPins() end)
check(ok,"Missing map API should not throw")
C_Map=mapAPI

local beforeSounds=#sounds
ns.PlayCue("herb")
check(#sounds==beforeSounds,"Disabled sound still played")
command("sound builtin");ns.PlayCue("herb");ns.PlayCue("herb")
check(#sounds==beforeSounds+1,"Sound must play once and throttle repeats")
uptime=uptime+60;epoch=epoch+60
command("sound custom");ns.PlayCue("herb")
check(sounds[#sounds].path and sounds[#sounds].path:find("Media",1,true),"Custom sound did not use addon media")
command("font 17");check(ns.db.settings.fontSize==17,"Font preference not saved")
command("font 999");check(ns.db.settings.fontSize==17,"Invalid font size accepted")
command("threshold vials 9");check(ns.db.settings.lowVials==9,"Vial threshold not saved")
command("threshold bags 10");check(ns.db.settings.bagSlots==10,"Bag threshold not saved")
check(#ns.PackingWarnings()>0,"Packing list missed low supplies")

-- Frame mocks deliberately keep Frame-only APIs off FontStrings.
if ns.Toggle then ns.Toggle() end
for _,page in ipairs({"Journal","Alchemy","Stash","Routes","Settings"}) do
    if ns.SetPage then ns.SetPage(page) end
    ns.Refresh()
end
check(#fontStrings>0,"Journal UI did not render")
local savedPlan=ns.db.activePlan
local savedCrafts=ns.Plan().recipes["Potion A"].crafts
local reloaded=loadAddon()
check(reloaded.db.activePlan==savedPlan and reloaded.Plan().recipes["Potion A"].crafts==savedCrafts,"Reload lost the saved plan")
check(reloaded.SessionStats().total==0,"Reload retained session-only loot")
check(reloaded.db.settings.fontSize==17 and reloaded.db.settings.sound=="custom","Reload lost preferences")
print("PASS: "..checks.." checks; migration, plans, stash, recipes, prices, loot, routes, audio, preferences, UI")
