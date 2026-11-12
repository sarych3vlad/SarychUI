--[[
	ElvUI NamePlates — embedded in SarychUI
	Based on ElvUI_NamePlates_Standalone / ElvUI 6.09 NamePlates module.
]]

local ENP_ADDON_NAME = "SarychUI_ElvUI_NamePlates"
local Engine = _G[ENP_ADDON_NAME] or {}
_G[ENP_ADDON_NAME] = Engine

local LibStub = _G.LibStub
local AceAddon, AceAddonMinor = LibStub("AceAddon-3.0")
local CallbackHandler = LibStub("CallbackHandler-1.0")

local AddOn = AceAddon:NewAddon(ENP_ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceHook-3.0")
AddOn.callbacks = AddOn.callbacks or CallbackHandler:New(AddOn)
AddOn.embeddedInSarychUI = true

AddOn.DF = {profile = {}, global = {}}
AddOn.privateVars = {profile = {}}

Engine[1] = AddOn
Engine[2] = Engine[2] or {}
Engine[3] = AddOn.privateVars.profile
Engine[4] = AddOn.DF.profile
Engine[5] = AddOn.DF.global

_G.ENP = AddOn

-- Do not publish the embedded engine as global ElvUI: WCollections and other addons
-- hook ElvUI on ADDON_LOADED and expect the full UI (Skins:AddCallback, ActionBars, …).
-- AceGUI-ElvUI widgets resolve _G.SarychUI_ElvUI_NamePlates directly.
if _G.ElvUI == Engine or (_G.ElvUI and _G.ElvUI[1] == AddOn) then
	_G.ElvUI = nil
end

local E, L = Engine[1], Engine[2]

do
	AddOn.Libs = {}
	AddOn.LibsMinor = {}
	function AddOn:AddLib(name, major, minor)
		if not name then return end
		if type(major) == "table" and type(minor) == "number" then
			self.Libs[name], self.LibsMinor[name] = major, minor
		else
			self.Libs[name], self.LibsMinor[name] = LibStub(major, minor)
		end
	end

	AddOn:AddLib("AceAddon", AceAddon, AceAddonMinor)
	AddOn:AddLib("AceDB", "AceDB-3.0")
	AddOn:AddLib("LSM", "LibSharedMedia-3.0")
	-- Isolated options GUI — never LibStub("AceGUI-3.0") (shared with WeakAuras).
	AddOn:AddLib("AceGUI", "AceGUI-3.0-ENP", true)
	AddOn:AddLib("AceConfig", "AceConfig-3.0-ElvUI", true)
	AddOn:AddLib("AceConfigDialog", "AceConfigDialog-3.0-ElvUI", true)
	AddOn:AddLib("AceConfigRegistry", "AceConfigRegistry-3.0-ElvUI", true)
	AddOn:AddLib("AceConfigCmd", "AceConfigCmd-3.0-ElvUI", true)
	AddOn:AddLib("AceDBOptions", "AceDBOptions-3.0", true)

	AddOn.LSM = AddOn.Libs.LSM
end

setmetatable(L, {__index = function(_, k) return k end})

AddOn.NamePlates = AddOn:NewModule("NamePlates", "AceHook-3.0", "AceEvent-3.0", "AceTimer-3.0")

E.version = "1.00"
E.myLocalizedClass, E.myclass = UnitClass("player")
E.myname = UnitName("player")
E.myrealm = GetRealmName()
E.mylevel = UnitLevel("player")
E.myguid = UnitGUID("player")

E.RegisteredModules = {}
E.ModuleCallbacks = {}
function E:RegisterModule(name, func)
	if self.initialized then
		if func then func() else self:GetModule(name):Initialize() end
	else
		tinsert(self.RegisteredModules, name)
		if func then self.ModuleCallbacks[name] = func end
	end
end

function E:InitializeModules()
	for _, name in ipairs(self.RegisteredModules) do
		local callback = self.ModuleCallbacks[name]
		if callback then
			local ok, err = pcall(callback)
			if not ok then
				self:Print("Error initializing module '"..name.."': "..tostring(err))
			end
		end
	end
end

function E:CheckStandaloneConflict()
	if IsAddOnLoaded and IsAddOnLoaded("ElvUI_NamePlates_Standalone") then
		self.disabledByConflict = true
		self:Print("|cffff0000Integrated NamePlates disabled:|r standalone addon |cff1784d1ElvUI_NamePlates_Standalone|r is loaded. Disable it to use SarychUI NamePlates.")
		return true
	end
	return false
end
