-- SnowfallKeyPress wrapper for SarychUI

local ADDON_NAME = "SnowfallKeyPress"

local wrapper = {
	name = ADDON_NAME,
	title = "SnowfallKeyPress",
	author = "Snowfall",
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

local function IsStandaloneSnowfallKeyPressEnabled()
	if SarychUI_IsStandaloneSnowfallKeyPressEnabled then
		return SarychUI_IsStandaloneSnowfallKeyPressEnabled()
	end
	if not GetAddOnInfo then return false end
	local _, _, _, enabled, loadable = GetAddOnInfo("SnowfallKeyPress")
	return loadable and enabled and true or false
end

local function ApplySnowfallKeyPressRuntime(enable)
	if SnowfallKeyPress_ApplyEmbeddedRuntime then
		SnowfallKeyPress_ApplyEmbeddedRuntime(enable)
	else
		SnowfallKeyPressEnabled = enable and true or false
		if enable then
			if SnowfallKeyPressSV then
				SnowfallKeyPressSV.enable = true
			end
		elseif SnowfallKeyPressSV then
			SnowfallKeyPressSV.enable = false
		end
	end

	if enable then
		local FA = SarychUI and SarychUI.FrostAtomBars
		local actionBar = FA and FA.ActionBar
		if actionBar and actionBar.initialized and actionBar.RefreshOverrideBindings then
			actionBar:RefreshOverrideBindings()
		end
	end
end

function wrapper:IsRuntimeEnabled()
	if IsStandaloneSnowfallKeyPressEnabled() then
		return false
	end
	return GetRuntimeEnabledFromDB()
end

function wrapper:SetRuntimeEnabled(enable)
	if IsStandaloneSnowfallKeyPressEnabled() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия SnowfallKeyPress.|r Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI.")
		end
		return false
	end

	SetRuntimeEnabledInDB(enable)
	wrapper.enabled = enable and true or false
	ApplySnowfallKeyPressRuntime(enable)
	return true
end

function wrapper:Initialize()
	wrapper.enabled = GetRuntimeEnabledFromDB()

	if IsStandaloneSnowfallKeyPressEnabled() then
		wrapper.enabled = false
		ApplySnowfallKeyPressRuntime(false)
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия SnowfallKeyPress.|r Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI.")
		end
		return
	end

	if wrapper.enabled then
		ApplySnowfallKeyPressRuntime(true)
	else
		ApplySnowfallKeyPressRuntime(false)
	end
end

function wrapper:Enable()
	if not GetRuntimeEnabledFromDB() then
		return false
	end
	wrapper.enabled = true
	ApplySnowfallKeyPressRuntime(true)
	return true
end

function wrapper:Disable()
	wrapper.enabled = false
	SetRuntimeEnabledInDB(false)
	ApplySnowfallKeyPressRuntime(false)
	return true
end

function SarychUI_OpenSnowfallKeyPressConfig()
    if not SarychUI then return false end
    if not (SarychUI.IsSarychUIOptionsOpen and SarychUI:IsSarychUIOptionsOpen()) then SarychUI:OpenOptions() end
    local core=SarychUI.OptionsCore
    if core then core._addonListSelected=ADDON_NAME; core:SelectSection("sui:addons") end
    return true
end

function wrapper:OpenConfig()
    return SarychUI_OpenSnowfallKeyPressConfig()
end

local selectedKey=""
local function Refresh()
    if SarychUI.RefreshConfig then SarychUI:RefreshConfig() end
end
local function ChangeKey(add, all)
    SnowfallKeyPress_ChangeKey(selectedKey,add,all)
    Refresh()
end
local function NoKey() return selectedKey=="" end
function wrapper:GetOptions()
    return {type="group",name=ADDON_NAME,order=17,args={
        enabled={type="toggle",name="Включить",order=1,
            get=function() return wrapper:IsRuntimeEnabled() end,
            set=function(_,value) wrapper:SetRuntimeEnabled(value) end},
        settings={type="group",name="",inline=true,suiTwoCol=true,order=2,
            hidden=function() return not wrapper:IsRuntimeEnabled() end,args={
                keys={type="select",name="Добавленные клавиши и сочетания",order=1,width="full",suiFullRow=true,
                    values=function()
                        local values={__order={}}
                        for _,key in ipairs(SnowfallKeyPressSV and SnowfallKeyPressSV.keys or {}) do
                            values[key]=key; table.insert(values.__order,key)
                        end
                        return values
                    end,
                    get=function() return selectedKey end,
                    set=function(_,value) selectedKey=value or ""; Refresh() end},
                key={type="keybinding",name="Выберите клавишу или сочетание",order=2,width="full",suiFullRow=true,
                    get=function() return selectedKey end,
                    set=function(_,value) selectedKey=value or ""; Refresh() end},
                add={type="execute",name="Добавить сочетание",order=3,disabled=NoKey,
                    func=function() ChangeKey(true,false) end},
                addAll={type="execute",name="Добавить все варианты",desc="Добавить клавишу без модификатора и со всеми сочетаниями Alt, Ctrl и Shift.",order=4,disabled=NoKey,
                    func=function() ChangeKey(true,true) end},
                remove={type="execute",name="Удалить сочетание",order=5,disabled=NoKey,
                    func=function() ChangeKey(false,false) end},
                removeAll={type="execute",name="Удалить все варианты",desc="Удалить клавишу без модификатора и со всеми сочетаниями Alt, Ctrl и Shift.",order=6,disabled=NoKey,
                    func=function() ChangeKey(false,true) end},
                clear={type="execute",name="Очистить список",order=7,
                    func=function() SnowfallKeyPress_ResetKeys(true); Refresh() end},
                defaults={type="execute",name="Сбросить по умолчанию",order=8,
                    func=function() SnowfallKeyPress_ResetKeys(false); Refresh() end},
                animation={type="toggle",name="Анимация нажатия",order=9,suiFullRow=true,
                    get=function() return SnowfallKeyPressSV and SnowfallKeyPressSV.animation==true end,
                    set=function(_,value) if SnowfallKeyPressSV then SnowfallKeyPressSV.animation=value end end},
            }},
    }}
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
