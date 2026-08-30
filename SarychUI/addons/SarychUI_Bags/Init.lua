--[[ SarychUI Bags — embedded engine ]]

local EBG_ADDON_NAME = "SarychUI_Bags"
local Engine = _G[EBG_ADDON_NAME] or {}
_G[EBG_ADDON_NAME] = Engine
-- Compat alias for older references.
_G.SarychUI_ElvUI_Bags = Engine

local LibStub = _G.LibStub
local AceAddon, AceAddonMinor = LibStub("AceAddon-3.0")
local CallbackHandler = LibStub("CallbackHandler-1.0")

local AddOn = AceAddon:NewAddon(EBG_ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceHook-3.0")
AddOn.callbacks = AddOn.callbacks or CallbackHandler:New(AddOn)
AddOn.embeddedInSarychUI = true

AddOn.DF = { profile = {}, global = {} }
AddOn.privateVars = { profile = {} }

Engine[1] = AddOn
Engine[2] = Engine[2] or {}
Engine[3] = AddOn.privateVars.profile
Engine[4] = AddOn.DF.profile
Engine[5] = AddOn.DF.global

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
	AddOn:AddLib("ItemSearch", "LibItemSearch-1.2-ElvUI", true)
end

setmetatable(L, { __index = function(_, k) return k end })

AddOn.Bags = AddOn:NewModule("Bags", "AceHook-3.0", "AceEvent-3.0", "AceTimer-3.0")
AddOn.Skins = AddOn:NewModule("Skins")
AddOn.Tooltip = AddOn:NewModule("Tooltip")

E.version = "1.00"
E.myLocalizedClass, E.myclass = UnitClass("player")
E.myname = UnitName("player")
E.myrealm = GetRealmName()
E.mylevel = UnitLevel("player")
E.myguid = UnitGUID("player")
E.myfaction = UnitFactionGroup("player")

E.private = Engine[3]
E.db = Engine[4]
E.global = Engine[5]

E.RegisteredModules = {}
E.ModuleCallbacks = {}
function E:RegisterModule(name, func)
	if self.initialized then
		if func then func() else self:GetModule(name):Initialize() end
	else
		table.insert(self.RegisteredModules, name)
		if func then self.ModuleCallbacks[name] = func end
	end
end

function E:InitializeModules()
	for _, name in ipairs(self.RegisteredModules) do
		local callback = self.ModuleCallbacks[name]
		if callback then
			local ok, err = pcall(callback)
			if not ok then
				self:Print("Error initializing module '" .. name .. "': " .. tostring(err))
			end
		end
	end
end

function E:CheckElvUIConflict()
	if IsAddOnLoaded and IsAddOnLoaded("ElvUI") then
		self.disabledByConflict = true
		self:Print("|cffff0000SarychUI Bags disabled:|r full |cff1784d1ElvUI|r addon is loaded. Use ElvUI bags or disable ElvUI.")
		return true
	end
	return false
end

-- Anchor panels for bag/bank movers (minimal Layout stub)
if not _G.RightChatPanel then
	local panel = CreateFrame("Frame", "SUIRightChatPanel", UIParent)
	panel:SetSize(1, 1)
	panel:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -4, 4)
	_G.RightChatPanel = panel
end
if not _G.LeftChatPanel then
	local panel = CreateFrame("Frame", "SUILeftChatPanel", UIParent)
	panel:SetSize(1, 1)
	panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 4, 4)
	_G.LeftChatPanel = panel
end
