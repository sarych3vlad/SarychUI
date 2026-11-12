-- TrufiGCD wrapper for SarychUI
-- Cursor-like valve: enable immediately; disable + /reload clears Blizzard Mods entry.

local ADDON_NAME = "TrufiGCD"

local wrapper = {
	name = ADDON_NAME,
	title = "TrufiGCD",
	author = "stevemyz",
	version = "1.0",
	loaded = true,
	enabled = false,
}

local function GetRuntimeEnabledFromDB()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons[ADDON_NAME] then
		return SarychUI.db.profile.addons[ADDON_NAME].enabled == true
	end
	return false
end

local function SetRuntimeEnabledInDB(enable)
	if not SarychUI or not SarychUI.db or not SarychUI.db.profile then return end
	SarychUI.db.profile.addons = SarychUI.db.profile.addons or {}
	if not SarychUI.db.profile.addons[ADDON_NAME] then
		SarychUI.db.profile.addons[ADDON_NAME] = {}
	end
	SarychUI.db.profile.addons[ADDON_NAME].enabled = enable and true or false
end

local function IsStandaloneTrufiGCDEnabled()
	if SarychUI_IsStandaloneTrufiGCDEnabled then
		return SarychUI_IsStandaloneTrufiGCDEnabled()
	end
	if not GetAddOnInfo then return false end
	local _, _, _, enabled, loadable = GetAddOnInfo("TrufiGCD")
	return loadable and enabled and true or false
end

local function ApplyTrufiGCDRuntime(enable)
	if SarychUI_ApplyTrufiGCDRuntime then
		SarychUI_ApplyTrufiGCDRuntime(enable)
	else
		TrufiGCDEnabled = enable and true or false
		if enable and TrufiGCDTryInitialize then
			TrufiGCDTryInitialize()
		end
	end
end

function wrapper:IsRuntimeEnabled()
	if IsStandaloneTrufiGCDEnabled() then
		return false
	end
	return GetRuntimeEnabledFromDB()
end

function wrapper:SetRuntimeEnabled(enable)
	if IsStandaloneTrufiGCDEnabled() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия TrufiGCD.|r Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI.")
		end
		return false
	end

	SetRuntimeEnabledInDB(enable)
	wrapper.enabled = enable and true or false
	ApplyTrufiGCDRuntime(enable)
	return true
end

function wrapper:Initialize()
	wrapper.enabled = GetRuntimeEnabledFromDB()

	if IsStandaloneTrufiGCDEnabled() then
		wrapper.enabled = false
		ApplyTrufiGCDRuntime(false)
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия TrufiGCD.|r Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI.")
		end
		return
	end

	ApplyTrufiGCDRuntime(wrapper.enabled)
end

function wrapper:Enable()
	if not GetRuntimeEnabledFromDB() then
		return false
	end
	wrapper.enabled = true
	ApplyTrufiGCDRuntime(true)
	return true
end

function wrapper:Disable()
	wrapper.enabled = false
	SetRuntimeEnabledInDB(false)
	ApplyTrufiGCDRuntime(false)
	return true
end

function SarychUI_OpenTrufiGCDConfig()
    if not SarychUI:IsSarychUIOptionsOpen() then SarychUI:OpenOptions() end
    local core=SarychUI.OptionsCore
    core._addonListSelected=ADDON_NAME; core:SelectSection("sui:addons")
end
local function Refresh() if SarychUI.RefreshConfig then SarychUI:RefreshConfig() end end
local movingIndex
local function DragID(index) return "TrufiGCDQueue"..index end
function SarychUI_StopTrufiGCDDrag()
    if not movingIndex then return end
    local panel=SarychUI.PositionDragPanel
    if panel and panel:IsOpen() and panel:GetFrameId()==DragID(movingIndex) then
        panel:Close(true)
        return
    end
    local drag=SarychUI.DragMode
    if drag then drag:EnableEditMode(DragID(movingIndex),false,false,false); drag:ShowGrid(false) end
    movingIndex=nil
    Refresh()
end
local function RegisterDrag(index,name)
    local drag=SarychUI.DragMode
    if not drag or not TrGCDQueueFr or not TrGCDQueueFr[index] then return end
    local id=DragID(index)
    local frame=TrGCDQueueFr[index]
    frame:SetScript("OnDragStart",nil); frame:SetScript("OnDragStop",nil)
    drag:RegisterPositionEditor(id,frame,{
        title="TrufiGCD — "..name,
        getConfig=function() return TrGCDQueueOpt[index] end,
        onApply=function()
            local cfg=TrGCDQueueOpt[index]
            local saved=TrufiGCDChSave.TrGCDQueueFr[index]
            saved.point,saved.relativePoint,saved.x,saved.y=cfg.point,cfg.relativePoint,cfg.x,cfg.y
        end,
        onClosed=function() movingIndex=nil; Refresh() end,
    })
    local cfg=TrGCDQueueOpt[index]
    cfg.relativePoint=cfg.relativePoint or cfg.point
    return drag,id
end
local function ToggleDrag(index,name)
    local wasMoving=movingIndex==index
    SarychUI_StopTrufiGCDDrag()
    if wasMoving then return end
    local drag,id=RegisterDrag(index,name)
    if not drag then return end
    movingIndex=index
    TrGCDQueueFr[index]:Show()
    TrGCDQueueOpt[index].moving=1
    drag:TogglePositionEditor(id,true)
    Refresh()
end
local function ResetPosition(index,name)
    SarychUI_StopTrufiGCDDrag()
    local drag,id=RegisterDrag(index,name)
    local cfg=TrGCDQueueOpt[index]
    cfg.point,cfg.relativePoint,cfg.x,cfg.y="CENTER","CENTER",0,0
    local saved=TrufiGCDChSave.TrGCDQueueFr[index]
    saved.point,saved.relativePoint,saved.x,saved.y="CENTER","CENTER",0,0
    if drag then drag:SetFramePosition(id,"CENTER","CENTER",0,0) end
    Refresh()
end
local function Group(name,order) return {type="group",name=name,order=order,args={}} end
local function Action(name,order,func) return {type="execute",name=name,order=order,func=function() func(); Refresh() end} end
function wrapper:GetOptions()
    local root=Group("TrufiGCD",18); root.childGroups="tab"
    root.args.enabled={type="toggle",name="Включить",order=1,get=function() return wrapper:IsRuntimeEnabled() end,
        set=function(_,v) wrapper:SetRuntimeEnabled(v) end}
    if not TrGCDQueueOpt or not TrGCDGUI then return root end
    local general=Group("Основное",2); root.args.general=general
    local settings=Group("",1); settings.inline=true; general.args.settings=settings
    for i,row in ipairs({{"ModScroll","Движение иконок"},{"TooltipEnable","Подсказки"},{"TooltipStopMove","Останавливать иконки при наведении"},{"TooltipSpellID","Показывать ID заклинания в чате"}}) do
        local key=row[1]
        settings.args[key]={type="toggle",name=row[2],order=i,get=function() return TrufiGCDChSave[key] end,set=function(_,v) TrufiGCDChSave[key]=v end}
    end
    settings.args.save=Action("Сохранить настройки в общий слот",6,TrGCDSaveSettings)
    settings.args.load=Action("Загрузить из общего слота",7,TrGCDLoadSettings)
    settings.args.defaults=Action("Сбросить настройки",8,function() TrGCDRestoreDefaultSettings(); TrGCDUploadViewSetting() end)
    local zones=Group("Зоны",3); root.args.zones=zones
    for i,row in ipairs({{"World","Открытый мир",1},{"PvE","Подземелья",2},{"Raid","Рейды",5},{"Arena","Арены",3},{"Bg","Поля боя",4}}) do
        local key,index=row[1],row[3]
        zones.args[key]={type="toggle",name=row[2],order=i,get=function() return TrufiGCDChSave.EnableIn[key] end,
            set=function(_,v) TrufiGCDChSave.EnableIn[key]=v; TrGCDCheckToEnableAddon(index) end}
    end
    local frames=Group("Рамки",4); frames.childGroups="tab"; root.args.frames=frames
    local function FrameOptions(index,name,order)
        local tab=Group(name,order); local box=Group("",1); box.inline=true; tab.args.settings=box
        local function Hidden() return not TrGCDQueueOpt[index].enable end
        box.args.enabled={type="toggle",name="Включить",order=1,get=function() return TrGCDQueueOpt[index].enable end,
            set=function(_,v) if not v and movingIndex==index then SarychUI_StopTrufiGCDDrag() end; if v~=TrGCDQueueOpt[index].enable then TrGCDCheckEnableClick(index) end; Refresh() end}
        box.args.direction={type="select",name="Направление",order=2,hidden=Hidden,values={Left="Влево",Right="Вправо",Up="Вверх",Down="Вниз"},
            get=function() return TrGCDQueueOpt[index].fade end,set=function(_,v) TrGCDFadeMenuWasCheck(index,v) end}
        for i,row in ipairs({{"size","Размер иконок",10,100,TrGCDSpSizeChanged},{"width","Количество иконок",1,8,TrGCDSpWidthChanged}}) do
            local key,callback=row[1],row[5]
            box.args[key]={type="range",name=row[2],order=i+2,min=row[3],max=row[4],step=1,hidden=Hidden,
                get=function() return TrGCDQueueOpt[index][key] end,set=function(_,v) callback(index,v) end}
        end
        box.args.move={type="execute",order=5,hidden=Hidden,
            name=function() return "Свободное перемещение"..(SarychUI.DragMode:IsPositionEditorOpen(DragID(index)) and " |cff00ff00(вкл)|r" or "") end,
            func=function() ToggleDrag(index,name) end,
            suiResetDefaults=function() ResetPosition(index,name) end}
        return tab
    end
    frames.args.player=FrameOptions(1,"Игрок",1); frames.args.target=FrameOptions(11,"Цель",2); frames.args.focus=FrameOptions(12,"Фокус",3)
    for _,row in ipairs({{"party","Группа",4,1,4},{"arena","Арена",5,5,5}}) do
        local group=Group(row[2],row[3]); group.childGroups="tab"; frames.args[row[1]]=group
        for i=1,row[5] do group.args["unit"..i]=FrameOptions(row[4]+i,row[2].." "..i,i) end
    end
    local blacklist=Group("Чёрный список",5); root.args.blacklist=blacklist
    local selected
    blacklist.args.add={type="input",name="Название или ID заклинания",order=1,suiSaveButton="Добавить",get=function() return "" end,
        set=function(_,v)
            v=v:match("^%s*(.-)%s*$")
            if v~="" and #TrGCDBL<60 then table.insert(TrGCDBL,tonumber(v) or v); TrufiGCDChSave.TrGCDBL=TrGCDBL; Refresh() end
        end}
    blacklist.args.list={type="select",name="Заклинания",order=2,values=function()
        local values={__order={}}; for i,v in ipairs(TrGCDBL) do values[i]=(GetSpellInfo(v) or tostring(v)).." ("..v..")"; table.insert(values.__order,i) end; return values end,
        get=function() return selected end,set=function(_,v) selected=v end}
    blacklist.args.remove=Action("Удалить выбранное",3,function() if selected then table.remove(TrGCDBL,selected); selected=nil end end)
    blacklist.args.defaults=Action("Сбросить список",4,TrGCDBLDefaultSetting)
    blacklist.args.save=Action("Сохранить список в общий слот",5,TrGCDBLSaveSetting)
    blacklist.args.load=Action("Загрузить список из общего слота",6,function()
        if TrufiGCDGlSave and TrufiGCDGlSave.TrGCDBL then
            wipe(TrGCDBL); for _,v in ipairs(TrufiGCDGlSave.TrGCDBL) do table.insert(TrGCDBL,v) end
        end
    end)
    for key,group in pairs(root.args) do if key~="enabled" then group.hidden=function() return not wrapper:IsRuntimeEnabled() end end end
    return root
end

local function RegisterWrapper()
	if SarychUI and SarychUI.RegisterAddOn then
		SarychUI:RegisterAddOn(ADDON_NAME, wrapper)
		return true
	end
	return false
end

if not RegisterWrapper() then
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("ADDON_LOADED")
	frame:RegisterEvent("PLAYER_LOGIN")
	frame:SetScript("OnEvent", function(self, event, addonName)
		if event == "ADDON_LOADED" and addonName == "SarychUI" then
			if RegisterWrapper() then
				self:UnregisterEvent("ADDON_LOADED")
			end
		elseif event == "PLAYER_LOGIN" then
			if RegisterWrapper() then
				self:UnregisterEvent("PLAYER_LOGIN")
			end
		end
	end)
end

return wrapper
