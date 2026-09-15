local E, L, V, P, G = unpack(_G.SarychUI_ElvUI_NamePlates) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local AceDB = E.Libs.AceDB

--Lua functions
local pairs, ipairs, type, unpack = pairs, ipairs, type, unpack
local floor = math.floor
local min = math.min
local tinsert = table.insert
local gsub = string.gsub
--WoW API
local CreateFrame = CreateFrame
local UIParent = UIParent
local hooksecurefunc = hooksecurefunc
local GetNumTalentTabs = GetNumTalentTabs
local GetTalentTabInfo = GetTalentTabInfo
local ReloadUI = ReloadUI
local StaticPopup_Show = StaticPopup_Show
local StaticPopupDialogs = StaticPopupDialogs

-----------------------------------------------------------------------
-- Core tables expected by the toolkit / module code
-----------------------------------------------------------------------
E.frames = {}
E.unitFrameElements = {}
E.texts = {}
E.statusBars = {}
E.snapBars = {}

E.TexCoords = {0, 1, 0, 1}

E.InversePoints = {
	TOP = "BOTTOM",
	BOTTOM = "TOP",
	TOPLEFT = "BOTTOMLEFT",
	TOPRIGHT = "BOTTOMRIGHT",
	LEFT = "RIGHT",
	RIGHT = "LEFT",
	BOTTOMLEFT = "TOPLEFT",
	BOTTOMRIGHT = "TOPRIGHT",
	CENTER = "CENTER"
}

E.HealingClasses = {
	PALADIN = 1,
	SHAMAN = 3,
	DRUID = 3,
	PRIEST = {1, 2}
}

E.ClassRole = {
	PALADIN = {[0] = "Melee", [1] = "Caster", [2] = "Tank", [3] = "Melee"},
	PRIEST = "Caster",
	WARLOCK = "Caster",
	WARRIOR = {[0] = "Melee", [1] = "Melee", [2] = "Melee", [3] = "Tank"},
	HUNTER = "Melee",
	SHAMAN = {[0] = "Caster", [1] = "Caster", [2] = "Melee", [3] = "Caster"},
	ROGUE = "Melee",
	MAGE = "Caster",
	DEATHKNIGHT = {[0] = "Melee", [1] = "Tank", [2] = "Melee", [3] = "Melee"},
	DRUID = {[0] = "Caster", [1] = "Caster", [2] = "Melee", [3] = "Caster"}
}

E.PriestColors = {r = 0.99, g = 0.99, b = 0.99}

-- Minimal role detection (ported/simplified from ElvUI Core/API.lua) so the
-- StyleFilter "role" trigger works without bringing in the full talent/spec system.
function E:GetPlayerRole()
	if UnitGroupRolesAssigned then
		local isTank, isHealer, isDamage = UnitGroupRolesAssigned("player")
		if isTank then return "TANK" elseif isHealer then return "HEALER" elseif isDamage then return "DAMAGER" end
	end

	-- Fallback: derive from spent talent points + class role mapping.
	local maxPoints, specIdx = 0, 0
	for i = 1, (GetNumTalentTabs and GetNumTalentTabs() or 3) do
		local _, _, pointsSpent = GetTalentTabInfo(i)
		if pointsSpent and pointsSpent > maxPoints then
			maxPoints = pointsSpent
			specIdx = i - 1
		end
	end

	if E.HealingClasses[E.myclass] ~= nil then
		local heals = E.HealingClasses[E.myclass]
		if heals == specIdx or (type(heals) == "table" and (heals[1] == specIdx or heals[2] == specIdx)) then
			return "HEALER"
		end
	end

	local role = E.ClassRole[E.myclass]
	if type(role) == "table" then role = role[specIdx] end
	if role == "Tank" then return "TANK" end
	return "DAMAGER"
end

E.UIParent = UIParent
E.HiddenFrame = CreateFrame("Frame")
E.HiddenFrame:Hide()
E.noop = function() end

-- Escape Lua pattern magic characters (ported from ElvUI Init.lua); used by the
-- Style Filter options to match filter list entries.
do
	local arg2, arg3 = "([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1"
	function E:EscapeString(str)
		return gsub(str, arg2, arg3)
	end
end

-- Minimal StaticPopup wrapper. The ported NamePlates options call
-- E:StaticPopup_Show("PRIVATE_RL") to prompt for a UI reload when the per-character
-- "Enable" toggle changes. We register our own dialog and translate the popup id.
StaticPopupDialogs.ELVUINP_PRIVATE_RL = {
	text = L["You need to reload the UI to apply your changes."],
	button1 = ACCEPT,
	button2 = CANCEL,
	OnAccept = function() ReloadUI() end,
	OnShow = function(self)
		if SarychUI and SarychUI.RaiseStaticPopupAboveConfig then
			SarychUI:RaiseStaticPopupAboveConfig(self)
		else
			self:SetFrameStrata("FULLSCREEN_DIALOG")
			self:SetFrameLevel(1000)
		end
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 4,
	exclusive = 1,
	showAlert = 1,
}

StaticPopupDialogs.ELVUINP_CONFIG_RL = {
	text = L["One or more of the changes you have made require a ReloadUI."] or L["You need to reload the UI to apply your changes."],
	button1 = ACCEPT,
	button2 = CANCEL,
	OnAccept = function() ReloadUI() end,
	OnShow = function(self)
		if SarychUI and SarychUI.RaiseStaticPopupAboveConfig then
			SarychUI:RaiseStaticPopupAboveConfig(self)
		else
			self:SetFrameStrata("FULLSCREEN_DIALOG")
			self:SetFrameLevel(1000)
		end
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 4,
	exclusive = 1,
	showAlert = 1,
}

function E:StaticPopup_Show(name, ...)
	if name == "PRIVATE_RL" then name = "ELVUINP_PRIVATE_RL"
	elseif name == "CONFIG_RL" then name = "ELVUINP_CONFIG_RL" end
	local dialog = StaticPopup_Show(name, ...)
	if dialog and SarychUI and SarychUI.RaiseStaticPopupAboveConfig then
		SarychUI:RaiseStaticPopupAboveConfig(dialog)
	end
	return dialog
end

-----------------------------------------------------------------------
-- Pixel / scaling helpers (simplified from ElvUI PixelPerfect)
-----------------------------------------------------------------------
E.PixelMode = true
-- Simple, robust pixel sizing: 1px borders. Good enough for nameplates and avoids
-- the retail-only GetPhysicalScreenSize API which does not exist on 3.3.5.
E.mult = 1
E.Spacing = E.PixelMode and 0 or E.mult
E.Border = E.PixelMode and E.mult or (E.mult * 2)

function E:Scale(x)
	local m = E.mult
	return m * floor(x / m + 0.5)
end

-----------------------------------------------------------------------
-- Misc helpers
-----------------------------------------------------------------------
function E:CopyTable(current, default)
	if type(current) ~= "table" then current = {} end
	if type(default) == "table" then
		for option, value in pairs(default) do
			if type(value) == "table" then
				current[option] = E:CopyTable(current[option], value)
			else
				current[option] = value
			end
		end
	end
	return current
end

function E:CheckClassColor(r, g, b)
	return false
end

-----------------------------------------------------------------------
-- Role detection (used by threat coloring)
-----------------------------------------------------------------------
function E:CheckRole()
	local role = "Melee"
	local talentTree

	if GetNumTalentTabs and GetNumTalentTabs() then
		local maxPoints = -1
		for i = 1, GetNumTalentTabs() do
			local _, _, pointsSpent = GetTalentTabInfo(i)
			if pointsSpent and pointsSpent > maxPoints then
				maxPoints = pointsSpent
				talentTree = i
			end
		end
	end

	local class = self.ClassRole[self.myclass]
	if type(class) == "string" then
		role = class
	elseif type(class) == "table" and talentTree then
		role = class[talentTree - 1] or "Melee"
	end

	self.Role = role
end

-----------------------------------------------------------------------
-- Options window
-----------------------------------------------------------------------
local APP = "SarychUI_ElvUI_NamePlates"

-- Window size matching ElvUI (clamped to the current screen size).
function E:GetConfigDefaultSize()
	local width = (self.global and self.global.general and self.global.general.AceGUI and self.global.general.AceGUI.width) or 1000
	local height = (self.global and self.global.general and self.global.general.AceGUI and self.global.general.AceGUI.height) or 720
	local maxWidth, maxHeight = UIParent:GetWidth(), UIParent:GetHeight()
	if maxWidth and maxWidth > 0 then width = min(maxWidth - 50, width) end
	if maxHeight and maxHeight > 0 then height = min(maxHeight - 50, height) end
	return width, height
end

-- Save the window size when the user resizes/moves it, so it persists like ElvUI.
function E:ConfigStopMovingOrSizing()
	if self.obj and self.obj.status and E.global and E.global.general and E.global.general.AceGUI then
		E.global.general.AceGUI.width = E:Round(self:GetWidth(), 2)
		E.global.general.AceGUI.height = E:Round(self:GetHeight(), 2)
	end
end

function E:ApplyConfigGUIFrame()
	local ACD = self.Libs.AceConfigDialog
	if not ACD then return end

	local open = ACD.OpenFrames and ACD.OpenFrames[APP]
	local frame = open and open.frame
	if frame then
		frame.__SarychUI_ENPOptionsRoot = true
		local S = self:GetModule("Skins", true)
		if S and S.MarkENPOptionsRoot then
			S:MarkENPOptionsRoot(frame)
		end
		if not frame._enpOptionsHideHooked then
			frame._enpOptionsHideHooked = true
			frame:HookScript("OnHide", function()
				E._buildingENPOptionsSkin = nil
			end)
		end
	end
	if frame and not self.GUIFrame then
		self.GUIFrame = frame
		local maxWidth, maxHeight = UIParent:GetWidth(), UIParent:GetHeight()
		if frame.SetMinResize then frame:SetMinResize(600, 500) end
		if frame.SetMaxResize then frame:SetMaxResize((maxWidth or 1024) - 50, (maxHeight or 768) - 50) end

		local w, h = self:GetConfigDefaultSize()
		local status = frame.obj and (frame.obj.status or frame.obj.localstatus)
		if status then
			status.width, status.height = w, h
			if frame.obj.ApplyStatus then
				frame.obj:ApplyStatus()
			end
		end

		if hooksecurefunc then
			hooksecurefunc(frame, "StopMovingOrSizing", E.ConfigStopMovingOrSizing)
		end
	end
end

local function ENPOpenFrameIsShown(ACD)
	local open = ACD and ACD.OpenFrames and ACD.OpenFrames[APP]
	if not open then return false end
	local frame = open.frame
	return frame and frame.IsShown and frame:IsShown()
end

local function ClearENPStaleConfigFrame(self, ACD)
	local open = ACD.OpenFrames and ACD.OpenFrames[APP]
	if not open then
		self.GUIFrame = nil
		return
	end
	if ENPOpenFrameIsShown(ACD) then
		return
	end

	if open.Hide then
		open:Hide()
	end
	ACD.OpenFrames[APP] = nil
	self.GUIFrame = nil
end

function E:ForceOpenOptionsUI()
	local ACD = self.Libs.AceConfigDialog
	if not ACD then
		self:Print("AceConfigDialog not available; options cannot be shown.")
		return false
	end

	if not self.loginReady then
		self.loginReady = true
	end
	if not self.initialized and self.TryInitialize then
		self:TryInitialize()
	end
	if not self.initialized then
		self:Print("NamePlates options are not ready yet.")
		return false
	end

	-- Ensure private AceGUI + ElvUI skin hooks (never touches shared AceGUI when embedded).
	local Skins = self:GetModule("Skins", true)
	if Skins and Skins.EnsureAce3Hooks then
		Skins:EnsureAce3Hooks()
	end
	if _G.SarychUI_ENP_EnsurePrivateAceGUI then
		_G.SarychUI_ENP_EnsurePrivateAceGUI()
	end

	local reg = self.Libs.AceConfigRegistry
	if self.RegisterOptions and reg and not reg:GetOptionsTable(APP) then
		self:RegisterOptions()
	end
	if not reg or not reg:GetOptionsTable(APP) then
		self:Print("NamePlates options not registered (APP: " .. tostring(APP) .. ").")
		return false
	end

	local open = ACD.OpenFrames and ACD.OpenFrames[APP]
	if open and ENPOpenFrameIsShown(ACD) then
		self._buildingENPOptionsSkin = true
		if open.frame then
			open.frame.__SarychUI_ENPOptionsRoot = true
		end
		if open.Show then
			open:Show()
		end
		self:ApplyConfigGUIFrame()
		self._buildingENPOptionsSkin = nil
		return true
	end

	ClearENPStaleConfigFrame(self, ACD)

	local engine = _G.SarychUI_ElvUI_NamePlates
	local hadElvUI = _G.ElvUI
	if not hadElvUI and engine then
		_G.ElvUI = engine
	end

	self._buildingENPOptionsSkin = true
	local ok, err = pcall(ACD.Open, ACD, APP)
	self._buildingENPOptionsSkin = nil
	if not hadElvUI then
		_G.ElvUI = nil
	end

	if not ok then
		self:Print("Error opening NamePlates options: " .. tostring(err))
		return false
	end

	self:ApplyConfigGUIFrame()

	open = ACD.OpenFrames and ACD.OpenFrames[APP]
	if open and open.frame then
		open.frame.__SarychUI_ENPOptionsRoot = true
	end
	if open and open.Show then
		local fadeIn = SarychUI and SarychUI._NamePlatesConfigFadeIn
		if fadeIn and open.frame and open.frame.SetAlpha then
			open.frame:SetAlpha(0)
		end
		open:Show()
	end

	if ENPOpenFrameIsShown(ACD) then
		return true
	end

	self:Print("Failed to open NamePlates options (APP: " .. tostring(APP) .. ").")
	return false
end

function E:OpenOptionsUI()
	return self:ForceOpenOptionsUI()
end

function E:ToggleOptionsUI()
	local ACD = self.Libs.AceConfigDialog
	if not ACD then
		self:Print("AceConfigDialog not available; options cannot be shown.")
		return
	end

	if ENPOpenFrameIsShown(ACD) then
		ACD:Close(APP)
		self._buildingENPOptionsSkin = nil
		return
	end

	ClearENPStaleConfigFrame(self, ACD)
	self:ForceOpenOptionsUI()
end

-----------------------------------------------------------------------
-- Profile handling
-----------------------------------------------------------------------
function E:RefreshConfig()
	self.db = self.data.profile
	self.global = self.data.global
	self.private = self.privateData.profile

	local NP = self:GetModule("NamePlates", true)
	if NP and NP.Initialized then
		NP.db = self.db.nameplates
		self:ApplySarychUINameplateProductDefaults(false)
		NP:ConfigureAll()
	end

	-- keep aura/number formatting in sync
	self:BuildPrefixValues()
end

function E:ResetNameplatesToDefault()
	self.data:ResetProfile()
end

-----------------------------------------------------------------------
-- Saved variable migration (standalone -> SarychUI embedded)
-----------------------------------------------------------------------
local function MigrateSavedVariables()
	if not _G.SarychUIElvNamePlatesDB and _G.ElvUINamePlatesStandaloneDB then
		_G.SarychUIElvNamePlatesDB = _G.ElvUINamePlatesStandaloneDB
	end
	if not _G.SarychUIElvNamePlatesPrivateDB and _G.ElvUINamePlatesStandalonePrivateDB then
		_G.SarychUIElvNamePlatesPrivateDB = _G.ElvUINamePlatesStandalonePrivateDB
	end
end

-----------------------------------------------------------------------
-- Initialization (runs at PLAYER_LOGIN when enabled)
-----------------------------------------------------------------------
function E:TryInitialize()
	if not self.loginReady or self.disabledByConflict or self.initialized then return end
	if self:CheckStandaloneConflict() then return end
	self:Initialize()
end

function E:Initialize()
	MigrateSavedVariables()

	-- Databases
	self.data = AceDB:New("SarychUIElvNamePlatesDB", {profile = P, global = G})
	self.privateData = AceDB:New("SarychUIElvNamePlatesPrivateDB", {profile = V})

	self.data.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
	self.data.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
	self.data.RegisterCallback(self, "OnProfileReset", "RefreshConfig")

	self.db = self.data.profile
	self.global = self.data.global
	self.private = self.privateData.profile

	-- Keep Engine[3..5] referencing live tables for any code reading V/P/G as live
	-- (module code reads E.db / E.private / E.global, defaults P/G stay as templates)

	self:UpdateMedia()
	self:BuildPrefixValues()
	self:CheckRole()

	self:SyncNamePlatesRuntimeFromSarychUI()

	self.initialized = true
	self:InitializeModules()
	self:ApplySarychUINameplateProductDefaults(false)

	if self.RegisterOptions then
		self:RegisterOptions()
	end

	-- Slash commands
	self:RegisterChatCommand("enp", "ToggleOptionsUI")
	self:RegisterChatCommand("elvnp", "ToggleOptionsUI")
	self:RegisterChatCommand("elvnameplates", "ToggleOptionsUI")

	if not self.embeddedInSarychUI then
		self:Print("loaded. Type |cff1784d1/enp|r to open NamePlates options.")
	end
end

function E:SyncNamePlatesRuntimeFromSarychUI()
	if not self.embeddedInSarychUI or not SarychUI or not SarychUI.db then return end
	local addonDb = SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.ElvUI_NamePlates
	if not addonDb then return end
	local enabled = addonDb.enabled ~= false
	self.private = self.private or self.privateData and self.privateData.profile
	if self.private then
		self.private.nameplates = self.private.nameplates or {}
		self.private.nameplates.enable = enabled
	end
end

function E:ApplySarych2KNameplateDefaults(force)
	return self:ApplySarychUINameplateProductDefaults(force)
end

local NAMEPLATE_PRODUCT_DEFAULTS_REV = 1

local function ApplyNameplateProductDefaultsToTable(np, force)
	if type(np) ~= "table" then
		return false
	end
	if not force and np._suiProductDefaultsRev == NAMEPLATE_PRODUCT_DEFAULTS_REV then
		return false
	end

	local plateSize = np.plateSize
	if type(plateSize) == "table" then
		plateSize.friendlyIncludeName = true
		plateSize.enemyIncludeName = true
	end

	local units = np.units
	if type(units) == "table" then
		local function setCastIconLeft(unit)
			local unitDb = units[unit]
			local castbar = unitDb and unitDb.castbar
			if type(castbar) == "table" then
				castbar.iconPosition = "LEFT"
			end
		end
		setCastIconLeft("ENEMY_PLAYER")
		setCastIconLeft("ENEMY_NPC")
	end

	np._suiProductDefaultsRev = NAMEPLATE_PRODUCT_DEFAULTS_REV
	return true
end

function E:ApplySarychUINameplateProductDefaults(force)
	local changed = false
	if self.db and type(self.db.nameplates) == "table" then
		if ApplyNameplateProductDefaultsToTable(self.db.nameplates, force) then
			changed = true
		end
	end

	local profiles = self.data and self.data.profiles
	if type(profiles) == "table" then
		for _, profile in pairs(profiles) do
			if type(profile) == "table" and type(profile.nameplates) == "table" then
				if ApplyNameplateProductDefaultsToTable(profile.nameplates, force) then
					changed = true
				end
			end
		end
	end

	local sv = _G.SarychUIElvNamePlatesDB
	if type(sv) == "table" and type(sv.profiles) == "table" then
		for _, profile in pairs(sv.profiles) do
			if type(profile) == "table" and type(profile.nameplates) == "table" then
				if ApplyNameplateProductDefaultsToTable(profile.nameplates, force) then
					changed = true
				end
			end
		end
	end

	if changed and self.initialized then
		local NP = self:GetModule("NamePlates", true)
		if NP and NP.Initialized and NP.ConfigureAll then
			NP:ConfigureAll()
		end
	end
	return changed
end

function E:IsNamePlatesRuntimeEnabled()
	if not self.private or not self.private.nameplates then return false end
	return self.private.nameplates.enable == true
end

function E:StartNamePlatesRuntime()
	if not self.initialized then return end
	self.private = self.private or self.privateData and self.privateData.profile
	if not self.private then return end
	self.private.nameplates = self.private.nameplates or {}
	self.private.nameplates.enable = true

	local NP = self:GetModule("NamePlates", true)
	if NP and not NP.Initialized and NP.Initialize then
		NP:Initialize()
	end
end

function E:ShutdownRuntime()
	local NP = self:GetModule("NamePlates", true)
	if NP and NP.Initialized then
		if NP.UnregisterCastEvents and NP.CreatedPlates then
			for plate in pairs(NP.CreatedPlates) do
				local unitFrame = plate and plate.UnitFrame
				if unitFrame and unitFrame.isEventsRegistered then
					NP:UnregisterCastEvents(unitFrame)
				end
			end
		end
		if NP.UnregisterCastEvents and NP.VisiblePlates then
			for unitFrame in pairs(NP.VisiblePlates) do
				if unitFrame and unitFrame.isEventsRegistered then
					NP:UnregisterCastEvents(unitFrame)
				end
			end
		end
		if NP.Frame then NP.Frame:SetScript("OnUpdate", nil) end
		if NP.UnregisterAllEvents then NP:UnregisterAllEvents() end
		NP.Initialized = false
	end
	if self.GUIFrame then
		local ACD = self.Libs and self.Libs.AceConfigDialog
		if ACD and ACD.Close then ACD:Close(APP) end
	end
end

E.Shutdown = E.ShutdownRuntime

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
	E.myLocalizedClass, E.myclass = UnitClass("player")
	E.mylevel = UnitLevel("player")
	E.myguid = UnitGUID("player")
	E.loginReady = true
	E:TryInitialize()
end)
