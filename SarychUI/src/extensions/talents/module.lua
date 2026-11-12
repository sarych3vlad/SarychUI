local SUI=SarychUI
local extension=SUI:RegisterExtension("talents",{})
local function DB()
    local profile=SUI.db.profile
    profile.modules.talents=profile.modules.talents or {}
    local db=profile.modules.talents
    if not db.migrated then
        local old=profile.addons and profile.addons.Talented or {}
        local tools=profile.modules.tools or {}
        if db.enabled==nil then db.enabled=old.enabled~=false end
        for _,key in ipairs({"skinStyle","dragonflightHeader"}) do if db[key]==nil then db[key]=old[key] end end
        for _,key in ipairs({"enableEasyGlyph","easyGlyphSkipItems"}) do
            if db[key]==nil then db[key]=tools[key] or 0 end
        end
        db.migrated=true
    end
    return db
end
function SUI:IsTalentsEnabled()
    return self.db and self.db.profile and DB().enabled~=false
end
local function Apply()
    local enabled=SUI:IsTalentsEnabled()
    TalentedEnabled=enabled
    if Talented.OnInitialize then Talented:OnInitialize() end
    if enabled then
        if not Talented:IsEnabled() then Talented:Enable() end
    else
        if Talented:IsEnabled() then Talented:Disable() end
        if Talented.base then Talented.base:Hide() end
    end
    SarychUI_EasyGlyph.Apply()
end
function extension:Initialize() DB(); Apply() end
function extension:Enable() Apply() end
function extension:Disable() Apply() end
function extension:RefreshConfig() Apply() end
local function Copy(t)
    local out={}; for k,v in pairs(t) do out[k]=type(v)=="table" and Copy(v) or v end; return out
end
function extension:GetOptions()
    local db=DB()
    local editor=Copy(Talented.options.args.options)
    editor.name="Редактор"; editor.order=2
    editor.handler=Talented; editor.get="GetOption"; editor.set="SetOption"
    editor.hidden=function() return not SUI:IsTalentsEnabled() end
    local glyphs={type="group",name="Символы",order=3,hidden=editor.hidden,args={}}
    for i,row in ipairs({{"enableEasyGlyph","Заменять иконки символов"},{"easyGlyphSkipItems","Не изменять иконки предметов"}}) do
        local key=row[1]
        glyphs.args[key]={type="toggle",name=row[2],order=i,
            get=function() local v=DB()[key]; return v==true or v==1 end,
            set=function(_,v) DB()[key]=v and 1 or 0; SarychUI_EasyGlyph.Apply() end}
    end
    editor.args.skinStyle={type="select",name="Стиль окна",order=16,values={SarychUI="SarychUI",ElvUI="ElvUI"},
        get=function() return DB().skinStyle or "SarychUI" end,
        set=function(_,v) DB().skinStyle=v; if SUI.ShowReloadPopup then SUI:ShowReloadPopup() end end}
    editor.args.dragonflightHeader={type="toggle",name="Шапка в стиле Dragonflight",order=17,
        get=function() return DB().dragonflightHeader==true end,
        set=function(_,v) DB().dragonflightHeader=v; if Talented.ReLayout then Talented:ReLayout() end end}
    local result={type="group",name="Таланты",childGroups="tab",args={
        enabled={type="toggle",name="Включить",order=1,get=function() return SUI:IsTalentsEnabled() end,
            set=function(_,v) DB().enabled=v; Apply(); if SUI.OptionsCore then SUI.OptionsCore:ScheduleSmartRefresh(true) end end},
        editor=editor,glyphs=glyphs,
    }}
    return result
end
function Talented:OpenOptionsFrame()
    if not SUI:IsSarychUIOptionsOpen() then SUI:OpenOptions() end
    local core=SUI.OptionsCore
    local sectionID="sui:extensions"
    local section=core._sections[sectionID]
    if not section then return end
    local pathKey=table.concat(section.path,"/")
    core._twoPaneSelected=core._twoPaneSelected or {}
    core._twoPaneSelected[pathKey]="talents"
    -- SelectSection skips rendering when this section is already visible.
    core._renderedId=nil
    core:SelectSection(sectionID)
end
