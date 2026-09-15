-- SarychUI Options Interface
-- Main options registration with Ace3 Framework (ShadowedUF_Options style)

local pairs, ipairs, select = pairs, ipairs, select
local tinsert = table.insert
local tsort = table.sort
local strlower = string.lower
local min = math.min
local max = math.max
local pcall = pcall
local type = type
local CreateFrame = CreateFrame
local UIParent = UIParent
local ReloadUI = ReloadUI
local ACCEPT = ACCEPT
local CANCEL = CANCEL
local StaticPopupDialogs = StaticPopupDialogs
local UISpecialFrames = UISpecialFrames
local LibStub = LibStub

local ADDON_NAME = "SarychUI"
local ENP_CONFIG_APP = "SarychUI_ElvUI_NamePlates"
local GLADIUS_CONFIG_APP = "GladiusEx"
local MAPSTER_CONFIG_APP = "Mapster"
local L = SarychUI.L

-- Reload popup helpers (available even when AceConfig is missing)
function SarychUI:RaiseStaticPopupAboveConfig(popup)
	if not popup then return end

	popup:SetFrameStrata("FULLSCREEN_DIALOG")

	local targetLevel = 100
	local function considerFrame(frame)
		if frame and frame.IsShown and frame:IsShown() and frame.GetFrameLevel then
			local frameLevel = frame:GetFrameLevel()
			if frameLevel and (frameLevel + 100) > targetLevel then
				targetLevel = frameLevel + 100
			end
		end
	end

	local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
	if ACD and ACD.OpenFrames then
		for _, open in pairs(ACD.OpenFrames) do
			considerFrame(open and open.frame)
		end
	end

	local engine = _G.SarychUI_ElvUI_NamePlates and _G.SarychUI_ElvUI_NamePlates[1]
	local ACDElv = engine and engine.Libs and engine.Libs.AceConfigDialog
	if ACDElv and ACDElv.OpenFrames then
		for _, open in pairs(ACDElv.OpenFrames) do
			considerFrame(open and open.frame)
		end
	end

	if SarychUIOptionsFrame and SarychUIOptionsFrame.IsShown and SarychUIOptionsFrame:IsShown() then
		considerFrame(SarychUIOptionsFrame)
	end

	popup:SetFrameLevel(targetLevel)
end

-- Cooltip-styled reload dialog (uses vendored SarychUI/media/cooltip textures).
local COOLTIP_BG_TEX = "Interface\\AddOns\\SarychUI\\media\\cooltip\\background"
local COOLTIP_BG = { 0.37, 0.37, 0.37, 0.95 }
local COOLTIP_BORDER = { 0.2, 0.2, 0.2, 1 }
local COOLTIP_ORANGE = { 1, 0.647, 0, 1 }
local reloadPopup

local function GetCooltipFontPath()
	local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
	if LSM and LSM.Fetch then
		local path = LSM:Fetch("font", "Friz Quadrata TT", true)
		if path then
			return path
		end
	end
	return "Fonts\\FRIZQT__.TTF"
end

local function StyleCooltipButton(btn)
	if not btn or not btn.SetBackdrop then return end
	btn:SetBackdrop({
		bgFile = COOLTIP_BG_TEX,
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		tile = true,
		tileSize = 16,
		edgeSize = 1,
		insets = { left = 0, right = 0, top = 0, bottom = 0 },
	})
	btn:SetBackdropColor(0.28, 0.28, 0.28, 0.98)
	btn:SetBackdropBorderColor(COOLTIP_BORDER[1], COOLTIP_BORDER[2], COOLTIP_BORDER[3], COOLTIP_BORDER[4])
end

local function EnsureReloadPopup()
	if reloadPopup then
		return reloadPopup
	end

	local f = CreateFrame("Frame", "SarychUIReloadPopup", UIParent)
	f:SetSize(360, 140)
	f:SetPoint("CENTER")
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:Hide()
	if f.SetBackdrop then
		f:SetBackdrop({
			bgFile = COOLTIP_BG_TEX,
			edgeFile = "Interface\\Buttons\\WHITE8X8",
			tile = true,
			tileSize = 16,
			edgeSize = 1,
			insets = { left = 0, right = 0, top = 0, bottom = 0 },
		})
		f:SetBackdropColor(COOLTIP_BG[1], COOLTIP_BG[2], COOLTIP_BG[3], COOLTIP_BG[4])
		f:SetBackdropBorderColor(COOLTIP_BORDER[1], COOLTIP_BORDER[2], COOLTIP_BORDER[3], COOLTIP_BORDER[4])
	end

	local fontPath = GetCooltipFontPath()
	local title = f:CreateFontString(nil, "OVERLAY")
	title:SetFont(fontPath, 13, "")
	title:SetTextColor(COOLTIP_ORANGE[1], COOLTIP_ORANGE[2], COOLTIP_ORANGE[3], 1)
	title:SetPoint("TOPLEFT", 16, -14)
	title:SetPoint("TOPRIGHT", -16, -14)
	title:SetJustifyH("LEFT")
	title:SetText("SarychUI")
	f.title = title

	local text = f:CreateFontString(nil, "OVERLAY")
	text:SetFont(fontPath, 12, "")
	text:SetTextColor(COOLTIP_ORANGE[1], COOLTIP_ORANGE[2], COOLTIP_ORANGE[3], 1)
	text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
	text:SetWidth(328)
	text:SetJustifyH("LEFT")
	text:SetJustifyV("TOP")
	text:SetNonSpaceWrap(true)
	f.text = text

	local function MakeBtn(label)
		local btn = CreateFrame("Button", nil, f)
		btn:SetSize(110, 24)
		StyleCooltipButton(btn)
		local fs = btn:CreateFontString(nil, "OVERLAY")
		fs:SetFont(fontPath, 12, "")
		fs:SetTextColor(COOLTIP_ORANGE[1], COOLTIP_ORANGE[2], COOLTIP_ORANGE[3], 1)
		fs:SetPoint("CENTER")
		fs:SetText(label)
		btn.label = fs
		btn:SetScript("OnEnter", function(self)
			self:SetBackdropColor(0.42, 0.42, 0.42, 1)
		end)
		btn:SetScript("OnLeave", function(self)
			self:SetBackdropColor(0.28, 0.28, 0.28, 0.98)
		end)
		return btn
	end

	local accept = MakeBtn(ACCEPT or "OK")
	accept:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -8, 14)
	accept:SetScript("OnClick", function()
		f._accepted = true
		local onAccept = f._onAccept
		f._onAccept = nil
		f._onCancel = nil
		f:Hide()
		if type(onAccept) == "function" then
			pcall(onAccept)
		else
			ReloadUI()
		end
	end)
	f.accept = accept

	local cancel = MakeBtn(CANCEL or "Cancel")
	cancel:SetPoint("BOTTOMLEFT", f, "BOTTOM", 8, 14)
	cancel:SetScript("OnClick", function()
		f:Hide()
	end)
	f.cancel = cancel

	f:SetScript("OnShow", function(self)
		self._accepted = nil
		SarychUI:RaiseStaticPopupAboveConfig(self)
	end)

	f:SetScript("OnHide", function(self)
		if self._accepted then
			self._accepted = nil
			self._onCancel = nil
			self._onAccept = nil
			return
		end
		local cb = self._onCancel
		self._onCancel = nil
		self._onAccept = nil
		if type(cb) == "function" then
			pcall(cb)
		end
	end)

	-- Esc closes without reload (triggers OnHide → onCancel).
	tinsert(UISpecialFrames, "SarychUIReloadPopup")

	reloadPopup = f
	return f
end

-- text: message
-- onCancel: optional (Cancel / Esc)
-- onAccept: optional; if nil, Accept runs ReloadUI()
function SarychUI:ShowReloadPopup(text, onCancel, onAccept)
	local msg = text or "Необходимо перезагрузить интерфейс, чтобы применить изменения."
	if self.T then
		msg = self:T(msg)
	end
	local f = EnsureReloadPopup()
	f._onCancel = type(onCancel) == "function" and onCancel or nil
	f._onAccept = type(onAccept) == "function" and onAccept or nil
	f._accepted = nil
	f.text:SetWidth(328)
	f.text:SetText(msg)
	local textH = f.text:GetStringHeight() or 40
	f:SetHeight(max(130, 86 + textH))
	f:Show()
	f:Raise()
end

-- Keep Blizzard StaticPopup definition for any external callers that show it directly.
StaticPopupDialogs["SARYCHUI_RELOAD_UI"] = {
	text = "Необходимо перезагрузить интерфейс, чтобы применить изменения.",
	button1 = ACCEPT,
	button2 = CANCEL,
	OnAccept = function()
		ReloadUI()
	end,
	OnShow = function(popup)
		SarychUI:RaiseStaticPopupAboveConfig(popup)
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 4,
	exclusive = 1,
	showAlert = 1,
}

local function RunAfterFrames(callback, frameCount)
	frameCount = frameCount or 1
	local frame = CreateFrame("Frame")
	local count = 0
	frame:SetScript("OnUpdate", function(self)
		count = count + 1
		if count >= frameCount then
			self:SetScript("OnUpdate", nil)
			callback()
		end
	end)
end

local NAMEPLATES_FADE_OUT = 0.09
local NAMEPLATES_FADE_IN = 0.11

local function FadeNativeFrame(frame, fromAlpha, toAlpha, duration, onFinished)
	if not frame or not frame.SetAlpha then
		if onFinished then onFinished() end
		return
	end

	if not duration or duration <= 0 or fromAlpha == toAlpha then
		frame:SetAlpha(toAlpha)
		if onFinished then onFinished() end
		return
	end

	frame:SetAlpha(fromAlpha)
	local elapsed = 0
	local driver = CreateFrame("Frame")
	if SarychUI.TrackOptionsFadeDriver then
		SarychUI:TrackOptionsFadeDriver(driver)
	end
	driver:SetScript("OnUpdate", function(self, dt)
		elapsed = elapsed + (dt or 0)
		local progress = min(elapsed / duration, 1)
		frame:SetAlpha(fromAlpha + (toAlpha - fromAlpha) * progress)
		if progress >= 1 then
			self:SetScript("OnUpdate", nil)
			self:Hide()
			frame:SetAlpha(toAlpha)
			if toAlpha == 0 and SarychUI.CleanupOptionsUI then
				SarychUI:CleanupOptionsUI()
			end
			if onFinished then onFinished() end
		end
	end)
end

local function GetSarychUIConfigWidget()
	local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
	if not ACD or not ACD.OpenFrames then return end
	return ACD.OpenFrames[ADDON_NAME]
end

local function GetSarychUIConfigNativeFrame()
	local widget = GetSarychUIConfigWidget()
	return widget and widget.frame
end

local function GetENPConfigNativeFrame(ENP)
	local ACDElv = ENP and ENP.Libs and ENP.Libs.AceConfigDialog
	if not ACDElv or not ACDElv.OpenFrames then return end
	local open = ACDElv.OpenFrames[ENP_CONFIG_APP]
	return open and open.frame
end

local function FadeInENPConfig(ENP)
	local nativeFrame = GetENPConfigNativeFrame(ENP)
	if not nativeFrame then return end
	nativeFrame:SetAlpha(0)
	FadeNativeFrame(nativeFrame, 0, 1, NAMEPLATES_FADE_IN)
end

local function GetENPEngine()
	local engine = _G.SarychUI_ElvUI_NamePlates
	if type(engine) == "table" and engine[1] then
		return engine[1]
	end
	if type(_G.ENP) == "table" and (_G.ENP.ForceOpenOptionsUI or _G.ENP.OpenOptionsUI) then
		return _G.ENP
	end
	return nil
end

function SarychUI:CloseOptions()
	self:CloseSarychUIConfig()
end

function SarychUI:CloseSarychUIConfig()
	if self._optionsClosing then
		return
	end
	self._optionsClosing = true

	if self.OptionsCore and self.OptionsCore.Close then
		self.OptionsCore:Close()
	end

	if self.CancelAceConfigDialogPendingRefresh then
		self:CancelAceConfigDialogPendingRefresh(ADDON_NAME)
	end

	if self.CleanupOptionsUI then
		self:CleanupOptionsUI({ forceHideFrame = true, closing = true })
	end

	local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
	if ACD and ACD.OpenFrames and ACD.OpenFrames[ADDON_NAME] then
		local open = ACD.OpenFrames[ADDON_NAME]
		if open and open.frame and open.frame.SetAlpha then
			open.frame:SetAlpha(1)
		end
		ACD:Close(ADDON_NAME)
	end

	self.GUIFrame = nil
	self._optionsClosing = nil

	if self.ScheduleDeferredOptionsCleanup then
		self:ScheduleDeferredOptionsCleanup()
	end
end

function SarychUI:CloseNamePlatesConfig()
	if self.ENPOptionsCore and self.ENPOptionsCore.Close then
		self.ENPOptionsCore:Close()
	end

	local ENP = GetENPEngine()
	if not ENP then return end

	ENP._buildingENPOptionsSkin = nil

	local ACDElv = ENP.Libs and ENP.Libs.AceConfigDialog
	if not ACDElv or not ACDElv.OpenFrames then return end

	local open = ACDElv.OpenFrames[ENP_CONFIG_APP]
	if not open then return end

	if open.frame and open.frame.IsShown and open.frame:IsShown() then
		ACDElv:Close(ENP_CONFIG_APP)
	elseif open.Hide then
		open:Hide()
	else
		ACDElv:Close(ENP_CONFIG_APP)
	end
end

function SarychUI:CloseGladiusExConfig()
	local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
	if not ACD or not ACD.OpenFrames then return end
	if not ACD.OpenFrames[GLADIUS_CONFIG_APP] then return end

	ACD:Close(GLADIUS_CONFIG_APP)
end

function SarychUI:CloseMapsterConfig()
	local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
	if ACD and ACD.OpenFrames and ACD.OpenFrames[MAPSTER_CONFIG_APP] then
		ACD:Close(MAPSTER_CONFIG_APP)
	end

	if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
		HideUIPanel(InterfaceOptionsFrame)
	end
end

function SarychUI:CloseCarboniteConfig()
	local nx = _G.Nx
	if nx and nx.Opt and nx.Opt.Win1 then
		local win = nx.Opt.Win1
		if win.IsShown and win:IsShown() then
			win:Show(false)
		end
	end

	local optsFrm = _G.NxOpts
	if optsFrm and optsFrm.IsShown and optsFrm:IsShown() then
		optsFrm:Hide()
	end

	if nx and nx.Opt and nx.Opt.FSt and nx.Opt.FSt.IsShown and nx.Opt.FSt:IsShown() then
		nx.Opt.FSt:Hide()
	end
end

function SarychUI:EnsureSarychUIConfigVisible()
	local nativeFrame = GetSarychUIConfigNativeFrame()
	if not nativeFrame then
		return
	end
	nativeFrame:SetAlpha(1)
	if nativeFrame.Show then
		nativeFrame:Show()
	end
	if nativeFrame.Raise then
		nativeFrame:Raise()
	end
end

local function EnsureSarychUIConfigVisible()
	SarychUI:EnsureSarychUIConfigVisible()
end

function SarychUI:CloseConfigWindows(exceptApp)
	local except = exceptApp or ""
	if except ~= ADDON_NAME then
		self:CloseSarychUIConfig()
	end
	if except ~= ENP_CONFIG_APP then
		self:CloseNamePlatesConfig()
	end
	if except ~= GLADIUS_CONFIG_APP then
		self:CloseGladiusExConfig()
	end
	if except ~= MAPSTER_CONFIG_APP then
		self:CloseMapsterConfig()
	end
	self:CloseCarboniteConfig()
end

local function GetGladiusExConfigNativeFrame()
	local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
	if not ACD or not ACD.OpenFrames then return end

	local open = ACD.OpenFrames[GLADIUS_CONFIG_APP]
	return open and open.frame
end

local function OpenGladiusExConfigWindow()
	local opened
	if GladiusEx and GladiusEx.ShowOptionsDialog then
		GladiusEx:ShowOptionsDialog()
		opened = true
	else
		local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
		if ACD then
			ACD:Open(GLADIUS_CONFIG_APP)
			opened = true
		end
	end

	if opened then
		local nativeFrame = GetGladiusExConfigNativeFrame()
		if nativeFrame then
			nativeFrame:SetAlpha(0)
			FadeNativeFrame(nativeFrame, 0, 1, NAMEPLATES_FADE_IN)
		end
	end
	return opened
end

local function GetMapsterConfigNativeFrame()
	local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
	if not ACD or not ACD.OpenFrames then return end

	local open = ACD.OpenFrames[MAPSTER_CONFIG_APP]
	return open and open.frame
end

local function OpenMapsterConfigWindow()
	local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
	if not ACD then return false end

	ACD:Open(MAPSTER_CONFIG_APP)

	local nativeFrame = GetMapsterConfigNativeFrame()
	if nativeFrame then
		nativeFrame:SetAlpha(0)
		FadeNativeFrame(nativeFrame, 0, 1, NAMEPLATES_FADE_IN)
	end

	return true
end

function SarychUI:OpenGladiusExConfig()
	RunAfterFrames(function()
		if UnitAffectingCombat and UnitAffectingCombat("player") then
			SarychUI:Print("Options are unavailable in combat.")
			return
		end

		if not GladiusEx and not (LibStub and LibStub("AceConfig-3.0", true)) then
			print("|cffffd200SarychUI:|r GladiusEx not loaded. Try /reload.")
			return
		end

		local nativeFrame = GetSarychUIConfigNativeFrame()
		local function openGladiusExConfig()
			SarychUI:CloseOptions()
			RunAfterFrames(function()
				if not OpenGladiusExConfigWindow() then
					print("|cffffd200SarychUI:|r Failed to open GladiusEx settings.")
				end
			end, 1)
		end

		if nativeFrame and nativeFrame.IsShown and nativeFrame:IsShown() then
			if SarychUI.CleanupOptionsUI then
				SarychUI:CleanupOptionsUI()
			end
			local startAlpha = nativeFrame:GetAlpha()
			if startAlpha <= 0 then startAlpha = 1 end
			FadeNativeFrame(nativeFrame, startAlpha, 0, NAMEPLATES_FADE_OUT, openGladiusExConfig)
		else
			openGladiusExConfig()
		end
	end, 1)
end

local function EnsureENPReady()
	local ENP = GetENPEngine()
	if not ENP then
		print("|cffffd200SarychUI:|r ENP not found (_G.ENP and SarychUI_ElvUI_NamePlates[1] are nil).")
		return
	end

	if not ENP.loginReady then
		ENP.loginReady = true
	end
	if not ENP.initialized and ENP.TryInitialize then
		ENP:TryInitialize()
	end
	if not ENP.initialized then
		print("|cffffd200SarychUI:|r ElvUI NamePlates not initialized. Try /reload.")
		return
	end

	return ENP
end

local function OpenENPConfigWindow(ENP)
	local opened
	SarychUI._NamePlatesConfigFadeIn = true
	-- Prefer ElvUI AceConfigDialog (private AceGUI pool) — not the Cooltip ENPOptionsCore shell.
	if ENP.ForceOpenOptionsUI then
		opened = ENP:ForceOpenOptionsUI()
	elseif ENP.OpenOptionsUI then
		opened = ENP:OpenOptionsUI()
	elseif ENP.ToggleOptionsUI then
		ENP:ToggleOptionsUI()
		opened = true
	else
		SarychUI._NamePlatesConfigFadeIn = nil
		print("|cffffd200SarychUI:|r No ENP open function found.")
		return false
	end
	SarychUI._NamePlatesConfigFadeIn = nil

	if opened then
		FadeInENPConfig(ENP)
	end
	return opened
end

function SarychUI:OpenNamePlatesConfig()
	-- Separate ElvUI NamePlates AceConfig window (ElvUI skin, private AceGUI).
	if UnitAffectingCombat and UnitAffectingCombat("player") then
		self:Print("Options are unavailable in combat.")
		return
	end

	RunAfterFrames(function()
		if UnitAffectingCombat and UnitAffectingCombat("player") then
			SarychUI:Print("Options are unavailable in combat.")
			return
		end

		local ENP = EnsureENPReady()
		if not ENP then return end

		-- Close custom SarychUI options shell if open (separate windows).
		if SarychUI.OptionsCore and SarychUI.OptionsCore.IsOpen and SarychUI.OptionsCore:IsOpen() then
			SarychUI.OptionsCore:Close()
		end
		if SarychUI.ENPOptionsCore and SarychUI.ENPOptionsCore.IsOpen and SarychUI.ENPOptionsCore:IsOpen() then
			SarychUI.ENPOptionsCore:Close()
		end

		local nativeFrame = GetSarychUIConfigNativeFrame()
		local function openNamePlatesConfig()
			SarychUI:CloseOptions()
			RunAfterFrames(function()
				if not OpenENPConfigWindow(ENP) then
					print("|cffffd200SarychUI:|r Failed to open NamePlates settings.")
				end
			end, 1)
		end

		if nativeFrame and nativeFrame.IsShown and nativeFrame:IsShown() then
			if SarychUI.CleanupOptionsUI then
				SarychUI:CleanupOptionsUI()
			end
			local startAlpha = nativeFrame:GetAlpha()
			if startAlpha <= 0 then startAlpha = 1 end
			FadeNativeFrame(nativeFrame, startAlpha, 0, NAMEPLATES_FADE_OUT, openNamePlatesConfig)
		else
			openNamePlatesConfig()
		end
	end, 1)
end

function SarychUI:OpenEmbeddedNamePlatesConfig()
	self:OpenNamePlatesConfig()
end

function SarychUI:OpenMapsterConfig()
	RunAfterFrames(function()
		if UnitAffectingCombat and UnitAffectingCombat("player") then
			SarychUI:Print("Options are unavailable in combat.")
			return
		end

		local nativeFrame = GetSarychUIConfigNativeFrame()
		local function openMapsterConfig()
			SarychUI:CloseOptions()
			RunAfterFrames(function()
				if not OpenMapsterConfigWindow() then
					print("|cffffd200SarychUI:|r Failed to open Mapster settings.")
				end
			end, 1)
		end

		if nativeFrame and nativeFrame.IsShown and nativeFrame:IsShown() then
			if SarychUI.CleanupOptionsUI then
				SarychUI:CleanupOptionsUI()
			end
			local startAlpha = nativeFrame:GetAlpha()
			if startAlpha <= 0 then startAlpha = 1 end
			FadeNativeFrame(nativeFrame, startAlpha, 0, NAMEPLATES_FADE_OUT, openMapsterConfig)
		else
			openMapsterConfig()
		end
	end, 1)
end

function SarychUI:OpenCarboniteConfig()
	RunAfterFrames(function()
		if UnitAffectingCombat and UnitAffectingCombat("player") then
			SarychUI:Print("Options are unavailable in combat.")
			return
		end

		if not (_G.Nx and _G.Nx.Loa) then
			if SarychUI.EnsureExternalCarboniteLoaded and not SarychUI:EnsureExternalCarboniteLoaded() then
				if not (SlashCmdList and SlashCmdList["Carbonite"]) then
					print("|cffffd200SarychUI:|r Carbonite not loaded. Install Carbonite in Interface/AddOns or /reload.")
					return
				end
			end
		end

		local nativeFrame = GetSarychUIConfigNativeFrame()
		local function openCarboniteConfig()
			SarychUI:CloseOptions()
			RunAfterFrames(function()
				if _G.Nx and _G.Nx.Opt and _G.Nx.Opt.Ope then
					_G.Nx.Opt:Ope()
					return
				end
				if SlashCmdList and SlashCmdList["Carbonite"] then
					SlashCmdList["Carbonite"]("options")
					return
				end
				print("|cffffd200SarychUI:|r Failed to open Carbonite settings.")
			end, 1)
		end

		if nativeFrame and nativeFrame.IsShown and nativeFrame:IsShown() then
			if SarychUI.CleanupOptionsUI then
				SarychUI:CleanupOptionsUI()
			end
			local startAlpha = nativeFrame:GetAlpha()
			if startAlpha <= 0 then startAlpha = 1 end
			FadeNativeFrame(nativeFrame, startAlpha, 0, NAMEPLATES_FADE_OUT, openCarboniteConfig)
		else
			openCarboniteConfig()
		end
	end, 1)
end

-- Check if Ace3 libraries are available
local AceConfig = LibStub and LibStub("AceConfig-3.0", true)
local AceConfigDialog = LibStub and LibStub("AceConfigDialog-3.0", true)
local AceDBOptions = LibStub and LibStub("AceDBOptions-3.0", true)

-- If Ace3 not available, skip options interface
if not AceConfig or not AceConfigDialog then
	print("|cffffd200SarychUI:|r Options interface requires full Ace3 libraries.")
	print("|cffffd200SarychUI:|r Please install ShadowedUnitFrames + ShadowedUF_Options for full options UI.")
	print("|cffffd200SarychUI:|r All modules are still working with default settings!")
	return
end

-- Config window size (matches ElvUI / ElvUI_NamePlates_Standalone behaviour)
local function RoundConfigValue(value)
	return math.floor((value or 0) * 100 + 0.5) / 100
end

function SarychUI:GetConfigSize()
	local global = self.db and self.db.global
	local aceGUI = global and global.general and global.general.AceGUI
	local defaults = self.defaults and self.defaults.global and self.defaults.global.general and self.defaults.global.general.AceGUI
	return (aceGUI and aceGUI.width) or (defaults and defaults.width) or 1000,
		(aceGUI and aceGUI.height) or (defaults and defaults.height) or 720
end

function SarychUI:GetConfigDefaultSize()
	local width, height = self:GetConfigSize()
	local maxWidth, maxHeight = UIParent:GetWidth(), UIParent:GetHeight()
	if maxWidth and maxWidth > 0 then width = min(maxWidth - 50, width) end
	if maxHeight and maxHeight > 0 then height = min(maxHeight - 50, height) end
	return width, height
end

function SarychUI:ConfigStopMovingOrSizing(frame)
	if not frame or not frame.obj or not frame.obj.status then return end
	local global = self.db and self.db.global
	if not global then return end
	global.general = global.general or {}
	global.general.AceGUI = global.general.AceGUI or {}
	global.general.AceGUI.width = RoundConfigValue(frame:GetWidth())
	global.general.AceGUI.height = RoundConfigValue(frame:GetHeight())
end

function SarychUI:SetupConfigFrame(frame)
	if SarychUI_ProfileOptionsStage then
		return SarychUI_ProfileOptionsStage("SetupConfigFrame", SarychUI._SetupConfigFrameImpl, SarychUI, frame)
	end
	return SarychUI:_SetupConfigFrameImpl(frame)
end

function SarychUI:_SetupConfigFrameImpl(frame)
	if not frame then return end
	local widget = frame.obj or GetSarychUIConfigWidget()

	if self.GUIFrame and self.GUIFrame == frame then
		if self.MarkSarychUIOwnedRoot then
			self:MarkSarychUIOwnedRoot(frame)
		end
		if widget then
			if SarychUI.EnsureSarychUIConfigFrameTitleHooks then
				SarychUI:EnsureSarychUIConfigFrameTitleHooks(widget)
			end
			if SarychUI.ApplyConfigFrameTitleLayout then
				SarychUI:ApplyConfigFrameTitleLayout(widget)
			end
		end
		if self.OptionsPerfFlag then
			self:OptionsPerfFlag("configFrameReused", true)
		end
		return
	end
	if self.OptionsPerfFlag then
		self:OptionsPerfFlag("configFrameCreated", true)
	end
	self.GUIFrame = frame
	if self.MarkSarychUIOwnedRoot then
		self:MarkSarychUIOwnedRoot(frame)
	end
	if widget then
		if SarychUI.EnsureSarychUIConfigFrameTitleHooks then
			SarychUI:EnsureSarychUIConfigFrameTitleHooks(widget)
		end
		if SarychUI.ApplyConfigFrameTitleLayout then
			SarychUI:ApplyConfigFrameTitleLayout(widget)
		end
	end

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
		hooksecurefunc(frame, "StopMovingOrSizing", function()
			SarychUI:ConfigStopMovingOrSizing(frame)
		end)
	end

	if not frame._sarychCleanupHooked then
		frame._sarychCleanupHooked = true
		frame:HookScript("OnHide", function()
			if SarychUI.OnSarychUIConfigHidden then
				SarychUI:OnSarychUIConfigHidden()
			end
		end)
	end
end

-- Общая функция для закрытия всех режимов редактирования
-- Используется при нажатии ESC и при входе в бой
local function CloseAllEditModes()
	local shouldClose = false
	
	-- 1. Проверяем режим редактирования фреймов (Фреймы > Позиция)
	local frameModule = SarychUI and SarychUI.modules and SarychUI.modules.frame
	if frameModule then
		local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.frame
		if db then
			-- Проверяем режим редактирования
			if db.showPositionDragFrame == 1 then
				db.showPositionDragFrame = 0
				shouldClose = true
			end
			
			-- Проверяем сетку выравнивания
			if db.showPositionGrid == 1 then
				db.showPositionGrid = 0
				shouldClose = true
			end
			
			-- Если что-то было активно, закрываем и обновляем
			if shouldClose then
				if frameModule.ApplyPositionDragMode then
					frameModule:ApplyPositionDragMode()
				end
			end
		end
	end

	-- 1b. Режим редактирования аур персонажа (Ауры)
	local aurasModule = SarychUI and SarychUI.modules and SarychUI.modules.auras
	if aurasModule then
		local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.auras
		if db then
			local aurasClose = false
			if db.showBuffDragFrame == 1 then
				db.showBuffDragFrame = 0
				aurasClose = true
			end
			if db.showBuffGrid == 1 then
				db.showBuffGrid = 0
				aurasClose = true
			end
			if aurasClose then
				shouldClose = true
				if aurasModule.ApplyBuffManagement then
					aurasModule:ApplyBuffManagement()
				end
			end
		end
	end
	
	-- 2. Проверяем режим редактирования арены (Арена > настройки > изменить расположение)
	local arenaModule = SarychUI and SarychUI.modules and SarychUI.modules.arena
	if arenaModule then
		local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.arena
		if db then
			-- Проверяем режим редактирования арены
			if db.showDragFrame == 1 then
				db.showDragFrame = 0
				shouldClose = true
			end
			
			-- Проверяем сетку выравнивания арены
			if db.showGrid == 1 then
				db.showGrid = 0
				shouldClose = true
			end
			
			-- Если что-то было активно, закрываем и обновляем
			if shouldClose then
				if arenaModule.ApplySettings then
					arenaModule:ApplySettings()
				end
			end
		end
	end
	
	-- 3. Проверяем режим редактирования миникарты (Миникарта > Позиция)
	local minimapModule = SarychUI and SarychUI.modules and SarychUI.modules.minimap
	if minimapModule then
		local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.minimap
		if db then
			-- Проверяем режим редактирования миникарты
			if db.showDragFrame == 1 then
				db.showDragFrame = 0
				shouldClose = true
			end
			
			-- Проверяем сетку выравнивания миникарты
			if db.showGrid == 1 then
				db.showGrid = 0
				shouldClose = true
			end
			
			-- Если что-то было активно, закрываем и обновляем
			if shouldClose then
				if minimapModule.ApplySettings then
					minimapModule:ApplySettings()
				end
			end
		end
	end

	-- 3b. Трекер заданий (Инструменты > Dragonflight layout)
	do
		local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.tools
		if db then
			local qtClose = false
			if db.questTrackerShowDragFrame == 1 then
				db.questTrackerShowDragFrame = 0
				qtClose = true
			end
			if db.questTrackerShowGrid == 1 then
				db.questTrackerShowGrid = 0
				qtClose = true
			end
			if qtClose then
				shouldClose = true
				local panel = SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel
				if panel and panel.IsOpen and panel:IsOpen() and panel.GetFrameId and panel:GetFrameId() == "questTracker" then
					panel:Close(false)
				elseif _G.SarychUI_QuestTracker and _G.SarychUI_QuestTracker.ApplyDragMode then
					_G.SarychUI_QuestTracker.ApplyDragMode()
				end
			end
		end
	end
	
	-- 4. Текст боя: свободное перемещение живёт вне окна настроек.
	-- Не закрываем CombatTextDragPanel / combatText*Drag при ESC/закрытии /sui.
	
	-- Если что-то было активно, обновляем опции
	if shouldClose then
		if SarychUI.RefreshConfig then
			SarychUI:RefreshConfig()
		end
		return true
	end
	
	return false
end

-- Экспортируем функцию для использования в других модулях
SarychUI.CloseAllEditModes = CloseAllEditModes

-- Перехватываем CloseSpecialWindows для обработки ESC при активном режиме редактирования
-- Это должно быть сделано ДО того, как AceConfigDialog перехватит эту функцию
local originalCloseSpecialWindows = CloseSpecialWindows
if originalCloseSpecialWindows then
	CloseSpecialWindows = function()
		local shouldClose = CloseAllEditModes()
		
		-- Если режим редактирования был активен, не закрываем окно настроек
		if shouldClose then
			return true
		end
		
		-- Если режим редактирования не активен, вызываем оригинальную функцию
		return originalCloseSpecialWindows()
	end
end

-- Main options table
local options = {
	name = ADDON_NAME,
	type = "group",
	childGroups = "tree",
	args = {
		general = {
			type = "group",
			name = "Общее",
			order = 1,
			childGroups = "tree",
			args = {
				overview = {
					type = "group",
					name = "Информация",
					order = 1,
					args = {
						logoTopSpacer = {
							type = "description",
							name = "\n\n\n\n",
							order = 0.5,
							width = "full",
						},
						logo = {
							type = "description",
							name = "",
							image = "Interface\\AddOns\\SarychUI\\options\\SarychUI.blp",
							imageWidth = 280,
							imageHeight = 280,
							imageAlign = "CENTER",
							order = 1,
						},
						logoBottomSpacer = {
							type = "description",
							name = "\n\n\n\n\n",
							order = 1.5,
							width = "full",
						},
						uiLanguage = {
							type = "select",
							name = "Язык интерфейса",
							desc = "Язык настроек SarychUI. Не зависит от языка клиента WoW. Применяется сразу.",
							order = 2,
							width = 240,
							suiAlign = "CENTER",
							suiLocaleFlags = true,
							values = function()
								local order = SarychUI.GetLocaleDisplayOrder and SarychUI.GetLocaleDisplayOrder() or {}
								local out = { __order = order }
								for _, code in ipairs(order) do
									if SarychUI.GetLocaleDisplayLabel then
										out[code] = SarychUI.GetLocaleDisplayLabel(code)
									else
										local names = SarychUI.GetLocaleDisplayNames and SarychUI.GetLocaleDisplayNames() or {}
										out[code] = names[code] or code
									end
								end
								return out
							end,
							get = function()
								return SarychUI:GetUILocale()
							end,
							set = function(_, value)
								if not SarychUI:SetUILocale(value) then
									return
								end
								if SarychUI.ApplyUILocale then
									SarychUI:ApplyUILocale(value)
								end
								if SarychUI.RebuildLocalizedOptions then
									SarychUI:RebuildLocalizedOptions()
								end
								local OW = SarychUI.OptionsWindow
								if OW and OW.header and OW.header.subtitle then
									OW.header.subtitle:SetText(SarychUI:T("Настройки"))
								end
								if OW and OW.RefreshFooterCredit then
									OW:RefreshFooterCredit()
								end
								-- Rebuild nav + content so labels/tooltips switch immediately.
								local OC = SarychUI.OptionsCore
								if OC then
									if OC.InvalidateStructure then
										OC:InvalidateStructure()
									end
									if OC.EnsureStructure then
										OC:EnsureStructure()
									end
									if OC.Refresh then
										OC:Refresh()
									end
								end
							end,
						},
					},
				},
				quick = {
					type = "group",
					name = "Быстрые настройки Blizzard",
					order = 2,
					args = {
						logoTopSpacer = {
							type = "description",
							name = "\n\n",
							order = 1,
						},
						logo = {
							type = "description",
							name = "",
							image = "Interface\\TUTORIALFRAME\\UI-TutorialFrame-LevelUp.blp",
							imageWidth = 256,
							imageHeight = 256,
							imageAlign = "CENTER",
							order = 2,
						},
						applyQuickSettings = {
							type = "group",
							name = "|TInterface\\CURSOR\\Cast:22:22:0:0|t Применить быстрые настройки оригинального интерфейса",
							order = 3,
							inline = true,
							args = {
								applyButton = {
									type = "execute",
									name = "Применить",
									desc = "Применить QoL-настройки Blizzard.",
									order = 1,
									width = "full",
									suiTooltip = function()
										return SarychUI:GetQuickSettingsTooltipLines()
									end,
									func = function()
										SarychUI:ShowReloadPopup(
											"Применить быстрые настройки Blizzard?\n\nПосле применения потребуется перезагрузка интерфейса (/reload).",
											nil,
											function()
												SarychUI:ApplyQuickSettings()
											end
										)
									end,
								},
								applyGraphicsButton = {
									type = "execute",
									name = "Применить рекомендованные настройки графики",
									desc = "Рекомендуемая графика (цель 2K / 240 Hz). Если монитор слабее — возьмётся его максимум разрешения и герцовки.",
									order = 2,
									width = "full",
									suiTooltip = function()
										return SarychUI:GetQuickGraphicsTooltipLines()
									end,
									func = function()
										SarychUI:ShowReloadPopup(
											"Применить рекомендованные настройки графики?\n\nТребуется полный перезапуск игры (не только /reload).\nЕсли монитор не тянет 2K/240 Hz — будет выставлено максимальное доступное разрешение и герцовка.",
											nil,
											function()
												SarychUI:ApplyQuickGraphicsSettings()
											end
										)
									end,
								},
							},
						},
						warning = {
							type = "description",
							name = "|cFFFFD700Внимание:|r После применения потребуется перезагрузка интерфейса. Для настроек графики требуется полный перезапуск игры.",
							order = 4,
							width = "full",
						},
					},
				},
				profiles = {
					type = "group",
					name = "Профили",
					order = 3,
					args = {},
				},
			},
		},
		
		modules = {
			type = "group",
			name = "Модули",
			order = 2,
			childGroups = "tree",
			args = {
				-- Module options will be added here
			},
		},
		
		addons = {
			type = "group",
			name = "Аддоны",
			order = 3,
			childGroups = "tab",
			args = {
			ported = {
				type = "group",
				name = "Управление",
				order = 1,
				args = {},
			},
			},
		},

		system = {
			type = "group",
			name = "Система",
			order = 4,
			childGroups = "tab",
			args = {
				overview = {
					type = "group",
					name = "Обзор",
					order = 0,
					args = {
						dllHeader = {
							type = "description",
							name = (L["Dll_Detection_Header"] or "Обнаружение DLL"),
							suiSpinner = true,
							order = 1,
							width = "full",
							hidden = function()
								local compat = SarychUI.Compatibility
								-- Hide the searching header once all rows have a final answer
								-- (detected or not_detected) — same as when all three are found.
								return compat and compat.AreAllDllStatusesResolved and compat:AreAllDllStatusesResolved()
							end,
						},
						dllStatus = {
							type = "description",
							name = function()
								local compat = SarychUI.Compatibility
								if not compat then
									return "|cff808080Модуль совместимости не загружен|r"
								end
								return compat:GetDllStatusBlock()
							end,
							order = 2,
							width = "full",
						},
					},
				},
				speedyLoad = {
					type = "group",
					name = "Быстрая загрузка",
					order = 1,
					-- Enable toggle pinned to the right of the tab bar (same pattern as module «Включить»).
					suiTabBarExtra = {
						type = "toggle",
						name = "Включить",
						desc = L["Runtime_SpeedyLoad"] or "Оптимизация экрана загрузки",
						get = function()
							local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.system
							local v = db and db.enableSpeedyLoad
							return v == 1 or v == true
						end,
						set = function(_, val)
							if not SarychUI.db.profile.system then
								SarychUI.db.profile.system = {}
							end
							SarychUI.db.profile.system.enableSpeedyLoad = val and 1 or 0
							local tools = (SarychUI.GetModule and SarychUI:GetModule("tools"))
								or (SarychUI.modules and SarychUI.modules.tools)
							if tools and tools.ApplySpeedyLoad then
								tools:ApplySpeedyLoad()
							end
							if SarychUI.NotifySarychUIOptionsChange then
								SarychUI:NotifySarychUIOptionsChange()
							end
						end,
					},
					args = {
						speedyLoadBox = {
							type = "group",
							name = L["Runtime_SpeedyLoadMode"] or "Режим загрузки",
							order = 1,
							inline = true,
							hidden = function()
								local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.system
								local v = db and db.enableSpeedyLoad
								return not (v == 1 or v == true)
							end,
							args = {
								speedyLoadMode = {
									type = "select",
									name = L["Runtime_SpeedyLoadMode"] or "Режим загрузки",
									order = 1,
									width = "full",
									values = {
										safe = L["Runtime_SpeedyLoadSafe"] or "Безопасный",
										aggressive = L["Runtime_SpeedyLoadAggressive"] or "Агрессивный",
									},
									get = function()
										local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.system
										return (db and db.speedyLoadMode) or "safe"
									end,
									set = function(_, val)
										if not SarychUI.db.profile.system then
											SarychUI.db.profile.system = {}
										end
										SarychUI.db.profile.system.speedyLoadMode = val
										local tools = SarychUI.modules and SarychUI.modules.tools
										if tools and tools.ApplySpeedyLoad then
											tools:ApplySpeedyLoad()
										end
									end,
								},
							},
						},
						speedyLoadNote = {
							type = "description",
							name = "|cFFFFD700Пометка:|r SpeedyLoad ускоряет вход в мир: на время загрузки временно отключает лишние игровые события, затем возвращает их. Агрессивный режим затрагивает больше событий (ауры, сумки, кулдауны) и по умолчанию выключен.",
							order = 2,
							width = "full",
							hidden = function()
								local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.system
								local v = db and db.enableSpeedyLoad
								return not (v == 1 or v == true)
							end,
						},
					},
				},
				luaOptimize = {
					type = "group",
					name = L["Runtime_LuaOptimize"] or "Оптимизация Lua",
					order = 1.5,
					suiTabBarExtra = {
						type = "toggle",
						name = L["Enable"] or "Включить",
						desc = function()
							local runtime = SarychUI.Runtime
							if runtime and runtime:IsBlockedByLuaBoost() then
								return L["Runtime_BlockedByLuaBoost"]
							end
							return L["Runtime_EnableGC_Desc"] or "Умное управление Lua и защита от лишних обновлений StatusBar."
						end,
						disabled = function()
							local runtime = SarychUI.Runtime
							return runtime and runtime:IsBlockedByLuaBoost()
						end,
						get = function()
							local runtime = SarychUI.Runtime
							if runtime and runtime:IsBlockedByLuaBoost() then return false end
							local cfg = SarychUI.db and SarychUI.db.profile
								and SarychUI.db.profile.system and SarychUI.db.profile.system.runtime
							return cfg and cfg.enabled == true
						end,
						set = function(_, value)
							local runtime = SarychUI.Runtime
							if runtime and runtime:IsBlockedByLuaBoost() then return end
							local system = SarychUI.db.profile.system
							if not system.runtime then system.runtime = {} end
							system.runtime.enabled = value and true or false
							if runtime then runtime:Refresh() end
							if SarychUI.NotifySarychUIOptionsChange then
								SarychUI:NotifySarychUIOptionsChange()
							end
						end,
					},
					args = {
						summary = {
							type = "description",
							name = function()
								local runtime = SarychUI.Runtime
								if not runtime then
									return "|cff808080" .. (L["Runtime_NotLoaded"] or "Модуль не загружен") .. "|r"
								end
								if runtime:IsBlockedByLuaBoost() then
									return "|cffff8800" .. (L["Runtime_BlockedByLuaBoost"] or "!LuaBoost управляет оптимизацией Lua.") .. "|r"
								end
								local d = runtime:GetDiagnostics()
								local controllerColor = d.gcController == "SarychUI" and "|cff00ff00"
									or (d.gcController == "DLL" and "|cff55aaff" or "|cffaaaaaa")
								local cacheState
								if not d.gcEnabled then
									cacheState = L["Runtime_UICacheDisabled"] or "отключён"
								elseif d.dllActive then
									cacheState = L["Runtime_UICacheDLL"] or "обрабатывается DLL"
								elseif d.uiCacheActive then
									cacheState = string.format((L["Runtime_UICacheActive"] or "активен, пропущено %d повторов"), d.uiCacheSkipped or 0)
								elseif d.uiCacheEnabled == false then
									cacheState = L["Runtime_UICacheDisabled"] or "отключён"
								else
									cacheState = L["Runtime_UICacheWaiting"] or "ожидает активации"
								end
								return string.format(
									"|cff00ccffSarychUI Runtime v%s|r\n%s: %s%s|r  •  %s: |cffffff00%s|r  •  %s: |cffffff00%.1f MB|r\n%s: |cffffff00%s|r",
									tostring(d.version or "?"),
									L["Runtime_Controller"] or "Контроллер GC", controllerColor, tostring(d.gcController or "?"),
									L["Runtime_Mode"] or "Режим", tostring(d.gcMode or "?"),
									L["Runtime_Memory"] or "Память Lua", d.memoryMB or 0,
									L["Runtime_UICache"] or "Кэш StatusBar", cacheState)
							end,
							order = 1,
							width = "full",
						},
						controls = {
							type = "group",
							name = L["Runtime_Settings"] or "Режим работы",
							order = 5,
							inline = true,
							hidden = function()
								local runtime = SarychUI.Runtime
								if runtime and runtime:IsBlockedByLuaBoost() then return true end
								local cfg = SarychUI.db and SarychUI.db.profile
									and SarychUI.db.profile.system and SarychUI.db.profile.system.runtime
								return not (cfg and cfg.enabled == true)
							end,
							args = {
								preset = {
									type = "select",
									name = L["Runtime_Preset"] or "Профиль GC",
									desc = L["Runtime_Preset_Desc"] or "Готовый баланс плавности и скорости очистки памяти.",
									order = 1,
									width = "full",
									values = {
										light = L["Runtime_Preset_Light"] or "Лёгкий",
										standard = L["Runtime_Preset_Standard"] or "Стандартный",
										heavy = L["Runtime_Preset_Heavy"] or "Тяжёлый",
									},
									get = function()
										local cfg = SarychUI.db.profile.system.runtime
										return (cfg and cfg.preset) or "standard"
									end,
									set = function(_, value)
										if SarychUI.Runtime then
											SarychUI.Runtime:ApplyPreset(value)
										end
									end,
								},
								uiCache = {
									type = "toggle",
									name = L["Runtime_UICache"] or "Кэш повторных обновлений StatusBar",
									desc = L["Runtime_UICache_Desc"] or "Не отправляет движку одинаковые значения полос здоровья, ресурсов и прогресса повторно.",
									order = 2,
									width = "full",
									hidden = function()
										local runtime = SarychUI.Runtime
										return runtime and runtime:IsDllGcActive()
									end,
									get = function()
										local cfg = SarychUI.db.profile.system.runtime
										return not cfg or cfg.uiCacheEnabled ~= false
									end,
									set = function(_, value)
										local cfg = SarychUI.db.profile.system.runtime
										cfg.uiCacheEnabled = value and true or false
										if SarychUI.Runtime then SarychUI.Runtime:Refresh() end
									end,
								},
								note = {
									type = "description",
									name = L["Runtime_AutomaticNote"] or "Шаги для боя, простоя и загрузки выбираются профилем автоматически. Аварийный порог сам повышается, если полная очистка заняла слишком много времени.",
									order = 3,
									width = "full",
								},
							},
						},
						compatStatus = {
							type = "description",
							name = function()
								local compat = SarychUI.Compatibility
								if not compat then
									return (L["WowOptimize_Compat"] or "wow_optimize.dll") .. ": |cff808080не загружен|r"
								end
								local active = compat:IsWowOptimizeActive()
								if not active then
									return (L["WowOptimize_Compat"] or "wow_optimize.dll") .. ": |cffff8800Неактивен|r"
								end
								local mode = compat.GetMode and compat:GetMode() or "auto"
								if mode == "auto" then
									return (L["WowOptimize_Compat"] or "wow_optimize.dll") .. ": |cff00ff00Активен (авто)|r"
								end
								return (L["WowOptimize_Compat"] or "wow_optimize.dll") .. ": |cff00ff00Активен|r"
							end,
							order = 2,
							width = "full",
						},
						compatBox = {
							type = "group",
							name = L["WowOptimize_Mode"] or "Режим совместимости",
							order = 3,
							inline = true,
							args = {
								wowOptimize = {
									type = "select",
									name = L["WowOptimize_Compat"] or "wow_optimize.dll",
									desc = L["WowOptimize_Mode_Desc"] or "Авто — обнаружение по глобалам DLL (LUABOOST_DLL_*). Включено — принудительно. Выключено — обычный SarychUI.",
									order = 1,
									width = "full",
									values = {
										auto = L["WowOptimize_Mode_Auto"] or "Авто",
										enabled = L["WowOptimize_Mode_Enabled"] or "Включено",
										disabled = L["WowOptimize_Mode_Disabled"] or "Выключено",
									},
									get = function()
										local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.compatibility
										return (db and db.wowOptimize) or "auto"
									end,
									set = function(_, value)
										if not SarychUI.db.profile.compatibility then
											SarychUI.db.profile.compatibility = {}
										end
										SarychUI.db.profile.compatibility.wowOptimize = value
										if SarychUI.Compatibility then
											SarychUI.Compatibility:Refresh(true)
										end
										if SarychUI.Runtime and SarychUI.Runtime.Refresh then
											SarychUI.Runtime:Refresh()
										end
										if SarychUI.NotifySarychUIOptionsChange then
											SarychUI:NotifySarychUIOptionsChange()
										end
									end,
								},
							},
						},
						compatNote = {
							type = "description",
							name = "|cFFFFD700Пометка:|r " .. (L["WowOptimize_Compat_Desc"] or "Необязательный режим совместимости с wow_optimize.dll. При активном режиме SarychUI не дублирует GC/combat log fix и смягчает тяжёлые Lua-сканы nameplates и chat bubbles."),
							order = 4,
							width = "full",
						},
					},
				},
			},
		},
	},
}

-- Initialize options
function SarychUI:InitializeOptions()
	local function profile(stage, fn, ...)
		if SarychUI_ProfileStartupStage then
			return SarychUI_ProfileStartupStage(stage, fn, ...)
		end
		if SarychUI_ProfileOptionsStage then
			return SarychUI_ProfileOptionsStage(stage, fn, ...)
		end
		return fn(...)
	end

	if self.BeginOptionsOpenPerf and self.IsOptionsPerfEnabled and self:IsOptionsPerfEnabled() then
		self:BeginOptionsOpenPerf("InitializeOptions")
	end

	-- AceGUI skin/patches: Blizzard Interface Options + ENP AceConfigDialog windows.
	if self.InstallSarychUIOptionsSkinLayer then
		self:InstallSarychUIOptionsSkinLayer()
	end
	if self.InstallAceGUIOptionsWidgetPatches then
		self:InstallAceGUIOptionsWidgetPatches()
	end

	-- Register a getter instead of the table itself: AceConfigRegistry calls it the first
	-- time anything asks for our options, so module/addon trees are not built at login.
	profile("InitializeOptions.RegisterOptionsTable", AceConfig.RegisterOptionsTable, AceConfig, ADDON_NAME, function()
		return SarychUI:BuildOptionsTable()
	end)
	SarychUI._optionsTableRegistered = true
	AceConfigDialog:SetDefaultSize(ADDON_NAME, SarychUI:GetConfigDefaultSize())
	
	-- Add to Blizzard Interface Options
	local optionsFrame = AceConfigDialog:AddToBlizOptions(ADDON_NAME, ADDON_NAME)
	
	-- Скрываем сетку и drag frames при закрытии окна настроек
	if optionsFrame then
		optionsFrame:HookScript("OnHide", function()
			if SarychUI.OnSarychUIConfigHidden then
				SarychUI:OnSarychUIConfigHidden()
			end
		end)
	end
	
	-- Также обрабатываем закрытие через AceConfigDialog.OpenFrames
	
	-- Устанавливаем хук при открытии окна настроек
	if AceConfigDialog then
		local originalOpen = AceConfigDialog.Open
		AceConfigDialog.Open = function(self, appName, ...)
			if appName == ADDON_NAME and SarychUI.IsPlayerInCombat and SarychUI:IsPlayerInCombat() then
				if SarychUI._userOpeningOptions then
					SarychUI._userOpeningOptions = nil
					SarychUI:PrintOptionsUnavailableInCombat()
					SarychUI:DebugCombatOptions("AceConfigDialog.Open user blocked")
					return
				end
				SarychUI:DebugCombatOptions("AceConfigDialog.Open silent blocked", "internal refresh")
				return
			end

			if appName == ADDON_NAME and SarychUI.CloseNamePlatesConfig then
				SarychUI:CloseNamePlatesConfig()
			end
			if appName == ADDON_NAME and SarychUI.CloseGladiusExConfig then
				SarychUI:CloseGladiusExConfig()
			end
			if appName == ADDON_NAME and SarychUI.CloseMapsterConfig then
				SarychUI:CloseMapsterConfig()
			end
			if appName == ADDON_NAME and SarychUI.CloseCarboniteConfig then
				SarychUI:CloseCarboniteConfig()
			end
			if appName == GLADIUS_CONFIG_APP and SarychUI.CloseSarychUIConfig then
				SarychUI:CloseSarychUIConfig()
				if SarychUI.CloseNamePlatesConfig then
					SarychUI:CloseNamePlatesConfig()
				end
			end
			if appName == MAPSTER_CONFIG_APP and SarychUI.CloseSarychUIConfig then
				SarychUI:CloseSarychUIConfig()
				if SarychUI.CloseNamePlatesConfig then
					SarychUI:CloseNamePlatesConfig()
				end
				if SarychUI.CloseGladiusExConfig then
					SarychUI:CloseGladiusExConfig()
				end
			end
			
			local result
			if appName == ADDON_NAME and SarychUI_ProfileOptionsStage then
				result = SarychUI_ProfileOptionsStage("AceConfigDialog.Open(SarychUI)", originalOpen, self, appName, ...)
			else
				result = originalOpen(self, appName, ...)
			end
			if appName == ADDON_NAME then
				-- Ждем кадр, чтобы окно точно создалось
				C_Timer.After(0, function()
					local widget = AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[appName]
					if not widget then return end

					local nativeFrame = widget.frame
					if SarychUI_ProfileOptionsStage then
						SarychUI_ProfileOptionsStage("EnsureSarychUIConfigVisible", EnsureSarychUIConfigVisible)
					else
						EnsureSarychUIConfigVisible()
					end
					if nativeFrame then
						if SarychUI.EnsureSarychUIConfigFrameTitleHooks then
							SarychUI:EnsureSarychUIConfigFrameTitleHooks(widget)
						end
						if SarychUI.ApplyConfigFrameTitleLayout then
							SarychUI:ApplyConfigFrameTitleLayout(widget)
						end
						if not SarychUI.GUIFrame then
							SarychUI:SetupConfigFrame(nativeFrame)
						end
						if SarychUI.SkinOwnedSarychUIConfigTree then
							SarychUI:SkinOwnedSarychUIConfigTree()
						end
					end

					if nativeFrame and not nativeFrame._dragModeHooked then
						nativeFrame._dragModeHooked = true
						
						nativeFrame:HookScript("OnHide", function()
							if SarychUI.OnSarychUIConfigHidden then
								SarychUI:OnSarychUIConfigHidden()
							end
						end)
					end
				end)
			end
			return result
		end

		if not AceConfigDialog._sarychCloseHooked then
			AceConfigDialog._sarychCloseHooked = true
			local originalClose = AceConfigDialog.Close
			AceConfigDialog.Close = function(acd, appName, ...)
				if appName == ADDON_NAME then
					if SarychUI.CancelAceConfigDialogPendingRefresh then
						SarychUI:CancelAceConfigDialogPendingRefresh(ADDON_NAME)
					end
					if SarychUI.CleanupOptionsUI then
						SarychUI:CleanupOptionsUI({ forceHideFrame = true })
					end
				end
				return originalClose(acd, appName, ...)
			end

			local originalCloseAll = AceConfigDialog.CloseAll
			AceConfigDialog.CloseAll = function(acd, ...)
				if SarychUI.CancelAceConfigDialogPendingRefresh then
					SarychUI:CancelAceConfigDialogPendingRefresh(ADDON_NAME)
				end
				if SarychUI.CleanupOptionsUI then
					SarychUI:CleanupOptionsUI({ forceHideFrame = true })
				end
				local result = originalCloseAll(acd, ...)
				if SarychUI.ScheduleDeferredOptionsCleanup then
					SarychUI:ScheduleDeferredOptionsCleanup()
				end
				return result
			end
		end
	end
	
	-- Closing options / Interface Options must not tear down free-move sessions.
	local function hideDragModeElements()
	end

	local function hideDragElements()
		hideDragModeElements()
		if SarychUI.OnSarychUIConfigHidden then
			SarychUI:OnSarychUIConfigHidden()
		end
	end

	-- Never run options cleanup while Blizzard is closing UIPanels (ESC/reload).
	local function scheduleOptionsCleanupAfterCloseAll()
		hideDragModeElements()
		if SarychUI.ScheduleDeferredOptionsCleanup then
			SarychUI:ScheduleDeferredOptionsCleanup()
		elseif SarychUI.OnSarychUIConfigHidden and C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				if SarychUI.IsSarychUIOptionsOpen and SarychUI:IsSarychUIOptionsOpen() then
					return
				end
				SarychUI:OnSarychUIConfigHidden()
			end)
		end
	end
	
	-- Обрабатываем закрытие Interface Options Frame
	if InterfaceOptionsFrame then
		InterfaceOptionsFrame:HookScript("OnHide", hideDragElements)
	end
	
	-- Обрабатываем закрытие через ESC или другие способы
	hooksecurefunc("CloseAllWindows", function()
		scheduleOptionsCleanupAfterCloseAll()
	end)
	
	-- Обрабатываем закрытие через InterfaceOptionsFrame_Cancel
	if InterfaceOptionsFrame_Cancel then
		hooksecurefunc("InterfaceOptionsFrame_Cancel", function()
			hideDragElements()
		end)
	end

	-- Build splash panel (Blizzard Interface > AddOns) like Leatrix
	if optionsFrame and not optionsFrame._splashBuilt then
		optionsFrame._splashBuilt = true
		optionsFrame:Hide()
		optionsFrame:SetScript("OnShow", function(self)
			if self._built then return end
			self._built = true
			-- Hide default category title (e.g., "SarychUI")
			-- Используем кэшированные регионы вместо повторных вызовов API (оптимизация производительности)
			if not self._regionsCache then
				self._regionsCache = {}
				local numRegions = self:GetNumRegions()
				for i = 1, numRegions do
					local r = select(i, self:GetRegions())
					if r then
						tinsert(self._regionsCache, r)
					end
				end
			end
			for _, r in ipairs(self._regionsCache) do
				if r and r.GetObjectType and r:GetObjectType() == "FontString" then
					r:Hide()
				end
			end
			-- Exact style like Leatrix snippet
			local interPanel = CreateFrame("FRAME", nil, self)
			interPanel:SetAllPoints(self)
			interPanel.name = "SarychUI"

			local maintitle = interPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
			maintitle:SetText("Sarych UI")
			maintitle:SetFont(maintitle:GetFont(), 72)
			maintitle:ClearAllPoints()
			maintitle:SetPoint("TOP", 0, -72)

			local expTitle = interPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
			expTitle:SetText("Wrath of the Lich King 3.3.5")
			expTitle:SetFont(expTitle:GetFont(), 32)
			expTitle:ClearAllPoints()
			expTitle:SetPoint("TOP", 0, -152)

			local subTitle = interPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
			subTitle:SetText("Esc > SarychUI")
			subTitle:SetFont(subTitle:GetFont(), 20)
			subTitle:ClearAllPoints()
			subTitle:SetPoint("BOTTOM", 0, 72)

			local slashTitle = interPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
			slashTitle:SetText("/sarychui")
			slashTitle:SetFont(slashTitle:GetFont(), 72)
			slashTitle:ClearAllPoints()
			slashTitle:SetPoint("BOTTOM", subTitle, "TOP", 0, 40)

			local pTex = interPanel:CreateTexture(nil, "BACKGROUND")
			pTex:SetAllPoints()
			pTex:SetTexture("Interface\\GLUES\\Models\\UI_MainMenu\\swordgradient2")
			pTex:SetAlpha(0.2)
			pTex:SetTexCoord(0, 1, 1, 0)
		end)
		optionsFrame:Show()
	end
	
	-- Store frame reference
	self.optionsFrame = optionsFrame

	if self.ScheduleOptionsOpenPerfEnd and self.IsOptionsPerfEnabled and self:IsOptionsPerfEnabled() then
		self:ScheduleOptionsOpenPerfEnd(0.05, "InitializeOptions complete")
	end

	if self.EndStartupPerf then
		self:EndStartupPerf("InitializeOptions complete")
	end
end

-- Fill the registered root table on first demand (first /sui open or first read of the
-- Ace registry). Idempotent: later calls return the already built table.
function SarychUI:BuildOptionsTable()
	if self._optionsTableBuilt then
		return options
	end
	self._optionsTableBuilt = true

	local function profile(stage, fn, ...)
		if SarychUI_ProfileOptionsStage then
			return SarychUI_ProfileOptionsStage(stage, fn, ...)
		end
		if SarychUI_ProfileStartupStage then
			return SarychUI_ProfileStartupStage(stage, fn, ...)
		end
		return fn(...)
	end

	-- Nothing can be listening yet on the first build, so skip the refresh notify.
	self._optionsTableBuilding = true
	profile("BuildOptionsTable.AddModuleOptions", self.AddModuleOptions, self)
	profile("BuildOptionsTable.AddAddOnOptions", self.AddAddOnOptions, self)
	self._optionsTableBuilding = nil

	if AceDBOptions and self.db then
		local profileOpts = profile("BuildOptionsTable.AceDBOptions", AceDBOptions.GetOptionsTable, AceDBOptions, self.db)
		if self.CustomizeProfileOptions then
			self:CustomizeProfileOptions(profileOpts)
		end
		profileOpts.name = "Профили"
		profileOpts.order = 3
		if options.args.general and options.args.general.args then
			options.args.general.args.profiles = profileOpts
		else
			options.args.profiles = profileOpts
		end
	end

	-- Expose root table for custom OptionsCore renderer (data source only).
	self._customOptionsRoot = options
	return options
end

-- Build the options tree and hidden window after login so the first /sui
-- is already laid out. Not a delayed show — Open() still works if this
-- has not finished yet.
function SarychUI:WarmupOptionsUI()
	if self._optionsWarmed then
		return
	end
	if self.IsPlayerInCombat and self:IsPlayerInCombat() then
		self._optionsWarmupPending = true
		return
	end
	self._optionsWarmed = true
	self._optionsWarmupPending = nil
	if self.InitializeOptions and not self._optionsTableRegistered then
		self:InitializeOptions()
	end
	if self.BuildOptionsTable then
		self:BuildOptionsTable()
	end
	if self.EnsureAddOnOptions then
		self:EnsureAddOnOptions()
	end
	local OW = self.OptionsWindow
	if OW and OW.CreateRoot then
		OW:CreateRoot()
	end
	local OC = self.OptionsCore
	if OC and OC.EnsureStructure then
		OC:EnsureStructure()
	end
end

local function ScheduleOptionsWarmup()
	if SarychUI._optionsWarmupScheduled then
		return
	end
	SarychUI._optionsWarmupScheduled = true
	local f = CreateFrame("Frame")
	local elapsed = 0
	f:SetScript("OnUpdate", function(self, dt)
		elapsed = elapsed + (dt or 0)
		-- Wait until the world is up so login hitch is gone, then build once.
		if elapsed < 1.2 then
			return
		end
		self:SetScript("OnUpdate", nil)
		self:Hide()
		if SarychUI.WarmupOptionsUI then
			SarychUI:WarmupOptionsUI()
		end
	end)
end

-- Add module options to the options table
function SarychUI:AddModuleOptions()
	if SarychUI_ProfileOptionsStage then
		return SarychUI_ProfileOptionsStage("AddModuleOptions.total", SarychUI._AddModuleOptionsImpl, SarychUI)
	end
	return self:_AddModuleOptionsImpl()
end

function SarychUI:_AddModuleOptionsImpl()
	local moduleOrder = {
		frame = 10,
		auras = 11,
		minimap = 20,
		map = 22,
		mainmenubar = 30,
		cc = 31,
		floating_text = 32,
		arena = 35,
		chat = 40,
		bags = 65,
		automation = 70,
		health_indicators = 75,
		plates_auras = 80,
		tools = 90,
	}
	
	for name, module in pairs(self.modules) do
		if module.GetOptions then
			local stage = "module.GetOptions:" .. name
			local moduleOpts
			if SarychUI_ProfileOptionsStage then
				moduleOpts = SarychUI_ProfileOptionsStage(stage, module.GetOptions, module)
			else
				moduleOpts = module:GetOptions()
			end
			if self.WrapModuleOptionsWithEnableHeader then
				moduleOpts = self:WrapModuleOptionsWithEnableHeader(name, moduleOpts)
			end
			options.args.modules.args[name] = moduleOpts
			options.args.modules.args[name].order = moduleOrder[name] or 100
		end
	end
end

-- Addon options cache: structure is built once and reused until marked dirty.
SarychUI._addonOptionsBuilt = false
SarychUI._addonOptionsDirty = true
SarychUI._optionsTableRegistered = false

function SarychUI:MarkAddOnOptionsDirty(reason)
	self._addonOptionsDirty = true
	self._addonOptionsBuilt = false
	self._addonOptionsDirtyReason = reason
end

function SarychUI:NotifySarychUIOptionsChange()
	if self.IsPlayerInCombat and self:IsPlayerInCombat() then
		self._pendingOptionsRefresh = true
		self:DebugCombatOptions("NotifySarychUIOptionsChange deferred")
		return
	end
	-- Never rebuild options while a slider/edit is busy — that kills drag capture
	-- and steals edit focus mid-typing (e.g. "-514").
	if self._optionsSliderDragging or self._optionsTextEditing
		or (SarychUI.IsOptionsInteractBusy and SarychUI.IsOptionsInteractBusy()) then
		self._pendingOptionsRefresh = true
		return
	end
	if self.OptionsCore and self.OptionsCore._rendering then
		self._pendingOptionsRefresh = true
		return
	end
	-- Custom /sui window: one coalesced pass decides rebuild vs value sync, so a
	-- value-only commit never orphans cooltip backdrops as on-screen ghosts.
	if self.OptionsCore and self.OptionsCore._open then
		if self.OptionsCore.ScheduleSmartRefresh then
			self.OptionsCore:ScheduleSmartRefresh()
		elseif self.OptionsCore.Refresh then
			self.OptionsCore:Refresh()
		end
		return
	end
	if self.CleanupOptionsUI and self.IsSarychUIOptionsOpen and self:IsSarychUIOptionsOpen() then
		self:CleanupOptionsUI()
	end
	local reg = LibStub and LibStub("AceConfigRegistry-3.0", true)
	if reg and self._optionsTableRegistered then
		reg:NotifyChange(ADDON_NAME)
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				if SarychUI.RefreshSarychUIConfigFrameTitleLayout then
					SarychUI:RefreshSarychUIConfigFrameTitleLayout()
				end
			end)
		elseif SarychUI.RefreshSarychUIConfigFrameTitleLayout then
			SarychUI:RefreshSarychUIConfigFrameTitleLayout()
		end
	end
end

function SarychUI:EnsureAddOnOptions()
	if self._addonOptionsBuilt and not self._addonOptionsDirty then
		if self.IsOptionsPerfEnabled and self:IsOptionsPerfEnabled() then
			if self.OptionsPerfLogSkip then
				self:OptionsPerfLogSkip("AddAddOnOptions", "skipped (cached)")
			end
			if self.OptionsPerfFlag then
				self:OptionsPerfFlag("addonOptionsSkipped", true)
				self:OptionsPerfFlag("RegisterOptionsTableOnOpen", false)
			end
		end
		return false
	end
	self:AddAddOnOptions()
	return true
end

function SarychUI:RefreshAddOnOptions(reason)
	if self.IsPlayerInCombat and self:IsPlayerInCombat() then
		self:MarkAddOnOptionsDirty(reason or "manual")
		self._pendingOptionsRefresh = true
		self:DebugCombatOptions("RefreshAddOnOptions deferred", reason)
		return
	end
	self:MarkAddOnOptionsDirty(reason or "manual")
	self:AddAddOnOptions()
	-- The addon option tables were just replaced, so the page must be redrawn
	-- rather than value-synced against dead tables.
	if self.OptionsCore and self.OptionsCore.InvalidateStructure then
		self.OptionsCore:InvalidateStructure()
	end
	self:NotifySarychUIOptionsChange()
	if self.IsOptionsPerfEnabled and self:IsOptionsPerfEnabled() and self.PrintOptionsPerfSummary then
		self:PrintOptionsPerfSummary()
	end
end

function SarychUI:RebuildModuleOptions(moduleName)
	if self.PerfCounter then
		self:PerfCounter("optionsRebuild", 1)
	end
	local module = self.modules and self.modules[moduleName]
	if not module or not module.GetOptions then
		return false
	end
	local stage = "RebuildModuleOptions:" .. moduleName
	local moduleOpts
	if SarychUI_ProfileOptionsStage then
		moduleOpts = SarychUI_ProfileOptionsStage(stage, module.GetOptions, module)
	else
		moduleOpts = module:GetOptions()
	end
	if self.WrapModuleOptionsWithEnableHeader then
		moduleOpts = self:WrapModuleOptionsWithEnableHeader(moduleName, moduleOpts)
	end
	options.args.modules.args[moduleName] = moduleOpts
	if self.OptionsCore and self.OptionsCore.InvalidateStructure then
		self.OptionsCore:InvalidateStructure()
	end
	self:NotifySarychUIOptionsChange()
	return true
end

-- Add addon options to the options table (always rebuilds; use EnsureAddOnOptions to skip when cached)
function SarychUI:AddAddOnOptions()
	if SarychUI_ProfileOptionsStage then
		return SarychUI_ProfileOptionsStage("AddAddOnOptions.total", SarychUI._AddAddOnOptionsImpl, SarychUI)
	end
	return self:_AddAddOnOptionsImpl()
end

function SarychUI:_AddAddOnOptionsImpl()
	if self.PerfCounter then
		self:PerfCounter("addonOptionsRebuild", 1)
	end
	local addonCount = 0
	local rebuildReason = self._addonOptionsDirtyReason

	-- Clear previous addon option groups before rebuild
	if options.args.addons and options.args.addons.args and options.args.addons.args.ported then
		options.args.addons.args.ported.args = {}
	end

	-- Add ported addons to "Список" tab (sorted by visible name A→Я,
	-- except grouped addons which the two-pane list pins under a header).
	local addonEntries = {}
	local ADDON_LIST_HIDDEN = {
		BaudBag = true,
		GladiusEx = true,
		SarychUI_Bags = true,
	}
	local ADDON_LIST_GROUPS = {
		Mapster = { group = "Карты", rank = 1, order = 1 },
		["!Astrolabe"] = { group = "Карты", rank = 1, order = 2 },
		WDM = { group = "Карты", rank = 1, order = 3 },
		Cromulent = { group = "Карты", rank = 1, order = 4 },
		["!!!ClassicAPI"] = { group = "Системные", rank = 2, order = 1 },
		AddonList = { group = "Системные", rank = 2, order = 2 },
		autolos = { group = "Системные", rank = 2, order = 3 },
		CL_Fix = { group = "Системные", rank = 2, order = 4 },
		FlashWindow = { group = "Системные", rank = 2, order = 5 },
	}

	local function GetAddOnDisplayName(optionGroup, key)
		if type(optionGroup) == "table" and type(optionGroup.name) == "string" and optionGroup.name ~= "" then
			return optionGroup.name
		end
		return key
	end

	if self.addons then
		for name, addon in pairs(self.addons) do
			-- Bags/arena engines stay in Сумки / Арена, not in Аддоны → Список.
			if not ADDON_LIST_HIDDEN[name] then
			addonCount = addonCount + 1
			local optionGroup

			if addon.GetOptions then
				local stage = "addon.GetOptions:" .. name
				if SarychUI_ProfileOptionsStage then
					optionGroup = SarychUI_ProfileOptionsStage(stage, addon.GetOptions, addon)
				else
					optionGroup = addon:GetOptions()
				end
			else
				local author = addon and addon.author or nil
				local version = addon and addon.version or nil
				local descriptionText = ""
				if author or version then
					if author then
						descriptionText = descriptionText .. "Автор: " .. author
					end
					if version then
						if author then
							descriptionText = descriptionText .. "\n"
						end
						descriptionText = descriptionText .. "Версия: " .. version
					end
				end

				optionGroup = {
					type = "group",
					name = (addon and addon.title) or name,
					args = {
						enabled = {
							type = "toggle",
							name = "Включить",
							desc = "Включить/выключить " .. ((addon and addon.title) or name),
							order = 1,
							get = function()
								return self.db.profile.addons[name] and self.db.profile.addons[name].enabled or false
							end,
							set = function(info, value)
								if value and self.CanEnableCoordinatedAddOn then
									local ok, reason = self:CanEnableCoordinatedAddOn(name)
									if not ok then
										if reason then self:Print(reason) end
										return
									end
								end
								if not self.db.profile.addons[name] then
									self.db.profile.addons[name] = {}
								end
								self.db.profile.addons[name].enabled = value
								if value then
									self:EnableAddOn(name)
								else
									self:DisableAddOn(name)
								end
							end,
							disabled = function()
								if self.CanEnableCoordinatedAddOn then
									local ok = self:CanEnableCoordinatedAddOn(name)
									local dbOn = self.db.profile.addons[name] and self.db.profile.addons[name].enabled
									return not ok and not dbOn
								end
								return false
							end,
						},
						description = descriptionText ~= "" and {
							type = "description",
							name = descriptionText,
							order = 2,
							width = "full",
						} or nil,
					},
				}
			end

			tinsert(addonEntries, {
				key = name,
				displayName = GetAddOnDisplayName(optionGroup, name),
				optionGroup = optionGroup,
			})
			local groupInfo = ADDON_LIST_GROUPS[name]
			if groupInfo and type(optionGroup) == "table" then
				optionGroup.suiListGroup = groupInfo.group
				optionGroup.suiListGroupRank = groupInfo.rank
				optionGroup.suiListGroupOrder = groupInfo.order
			end
			end
		end
	end

	tsort(addonEntries, function(a, b)
		local nameA = strlower(a.displayName or "")
		local nameB = strlower(b.displayName or "")
		if nameA ~= nameB then
			return nameA < nameB
		end
		return (a.key or "") < (b.key or "")
	end)

	for index, entry in ipairs(addonEntries) do
		if type(entry.optionGroup) == "table" then
			entry.optionGroup.order = index * 10
			options.args.addons.args.ported.args[entry.key] = entry.optionGroup
		end
	end

	self._addonOptionsBuilt = true
	self._addonOptionsDirty = false
	self._addonOptionsDirtyReason = nil

	if self.OptionsPerfFlag then
		self:OptionsPerfFlag("addonOptionsRebuilt", true)
		self:OptionsPerfFlag("addonOptionsCount", addonCount)
		if rebuildReason then
			self:OptionsPerfFlag("addonOptionsDirtyReason", rebuildReason)
		end
	end

	-- Structure changed in place; NotifyChange refreshes open UI without full RegisterOptionsTable
	if self._optionsTableRegistered and not self._optionsTableBuilding then
		if SarychUI_ProfileOptionsStage then
			SarychUI_ProfileOptionsStage("AceConfigRegistry:NotifyChange", self.NotifySarychUIOptionsChange, self)
		else
			self:NotifySarychUIOptionsChange()
		end
		if self.OptionsPerfFlag then
			self:OptionsPerfFlag("RegisterOptionsTableOnOpen", false)
		end
	end
end

-- Open options (custom OptionsCore only; same path as /sui).
function SarychUI:OpenOptionsPanel()
	if self.OpenOptions then
		self:OpenOptions()
		return
	end
	print("|cffffd200SarychUI:|r OptionsCore не загружен.")
end

-- Create SarychUI button in ESC menu (harmonious integration)
local function CreateSarychUIButton()
	if _G.GameMenuButtonSarychUI then return end
	local SarychUIButton = CreateFrame("Button", "GameMenuButtonSarychUI", GameMenuFrame, "GameMenuButtonTemplate")
	-- Set text with "Sarych" in white and "UI" in gold
	SarychUIButton:SetText("Sarych|cFFFFD100UI|r")
	
	-- Hook to maintain text colors on state changes
	local fontString = SarychUIButton:GetFontString()
	if fontString then
		SarychUIButton:HookScript("OnEnter", function()
			SarychUIButton:SetText("Sarych|cFFFFD100UI|r")
		end)
		SarychUIButton:HookScript("OnLeave", function()
			SarychUIButton:SetText("Sarych|cFFFFD100UI|r")
		end)
		SarychUIButton:HookScript("OnEnable", function()
			SarychUIButton:SetText("Sarych|cFFFFD100UI|r")
		end)
		SarychUIButton:HookScript("OnDisable", function()
			-- Dimmed colors when disabled
			SarychUIButton:SetText("|cFF808080Sarych|r|cFF808000UI|r")
		end)
	end

	SarychUIButton:SetScript("OnClick", function()
		HideUIPanel(GameMenuFrame)
		if SlashCmdList and SlashCmdList["SARYCHUI"] then
			SlashCmdList["SARYCHUI"]()
		elseif SarychUI and SarychUI.OpenOptions then
			SarychUI:OpenOptions()
		end
	end)

	local function LayoutOnShow()
		-- Anchor below AddOns if present, otherwise below Macros
		local anchor = _G["GameMenuButtonAddOns"] or _G["GameMenuButtonMacros"]
		if not anchor then return end
		SarychUIButton:ClearAllPoints()
		SarychUIButton:SetPoint("TOP", anchor, "BOTTOM", 0, -1)

		-- Collect all GameMenu buttons that visually sit at or below the anchor and reflow them under SarychUI
		local children = { GameMenuFrame:GetChildren() }
		local toReflow = {}
		for i = 1, #children do
			local c = children[i]
			if c and c.IsShown and c:IsShown() and c.GetObjectType and c:GetObjectType() == "Button" then
				local name = c.GetName and c:GetName() or ""
				if name:find("^GameMenuButton") and c ~= SarychUIButton and c ~= anchor then
					local cTop = c.GetTop and c:GetTop() or nil
					local aTop = anchor.GetTop and anchor:GetTop() or nil
					if cTop and aTop and cTop <= aTop then
						tinsert(toReflow, c)
					end
				end
			end
		end
		-- Preserve current visual order: sort by Y (top to bottom)
		tsort(toReflow, function(a, b)
			return (a:GetTop() or 0) > (b:GetTop() or 0)
		end)
		local prev = SarychUIButton
		for _, btn in ipairs(toReflow) do
			btn:ClearAllPoints()
			local offsetY = -1
			-- Extra spacing BEFORE Logout (Выход из мира)
			if btn == _G["GameMenuButtonLogout"] then
				offsetY = -12
			end
			-- Extra spacing AFTER Quit (Выход из игры): i.e., before the next button after Quit
			if prev == _G["GameMenuButtonQuit"] then
				offsetY = -12
			end
			btn:SetPoint("TOP", prev, "BOTTOM", 0, offsetY)
			prev = btn
		end

		-- Expand height precisely based on the lowest visible button so nothing clips
		if GameMenuFrame.GetBottom then
			local frameBottom = GameMenuFrame:GetBottom()
			if frameBottom then
				local lowestBottom
				local children = { GameMenuFrame:GetChildren() }
				for i = 1, #children do
					local c = children[i]
					if c and c.IsShown and c:IsShown() and c.GetObjectType and c:GetObjectType() == "Button" then
						local name = c.GetName and c:GetName() or ""
						if name:find("^GameMenuButton") and c.GetBottom then
							local b = c:GetBottom()
							if b then
								lowestBottom = lowestBottom and min(lowestBottom, b) or b
							end
						end
					end
				end
				if lowestBottom then
				local desiredGap = 14
					local bottomGap = lowestBottom - frameBottom
					if bottomGap < desiredGap then
						local delta = (desiredGap - bottomGap)
						GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + delta)
						local background = GameMenuFrame:GetRegions()
						if background and background.SetHeight then
							background:SetHeight(background:GetHeight() + delta)
						end
					end
				end
			end
		end
	end

	if not GameMenuFrame._suiHook then
		GameMenuFrame._suiHook = true
		GameMenuFrame:HookScript("OnShow", LayoutOnShow)
	end
end

-- ============================================================================
-- Quick Settings Application
-- ============================================================================

-- Safe CVar setter
local function SafeSetCVar(name, value)
	local ok, current = pcall(GetCVar, name)
	if ok and current ~= nil then
		SetCVar(name, value)
	end
end

-- Target values for «Быстрые настройки Blizzard» (label, cvar, desired).
local QUICK_SETTING_CVARS = {
	{ "Менеджер экипировки", "equipmentManager", "1" },
	{ "Неймплейты врагов", "nameplateShowEnemies", "1" },
	{ "Цель цели", "showTargetOfTarget", "1" },
	{ "Ошибки скриптов", "scriptErrors", "1" },
	{ "Вспышка края экрана", "screenEdgeFlash", "0" },
	{ "Спам лута", "showLootSpam", "1" },
	{ "Свободные слоты сумок", "displayFreeBagSlots", "1" },
	{ "Фильтр нецензурной лексики", "profanityFilter", "0" },
	{ "Оффлайн в гильдии", "guildShowOffline", "0" },
	{ "Канал набора в гильдию", "guildRecruitmentChannel", "0" },
	{ "Стиль чата", "chatStyle", "classic" },
	{ "Подсказки новичкам", "showNewbieTips", "0" },
	{ "Игровые подсказки", "showGameTips", "0" },
	{ "Фреймы арены", "showArenaEnemyFrames", "1" },
	{ "Все ранги заклинаний", "ShowAllSpellRanks", "0" },
	{ "Цвет класса на неймплейтах", "ShowClassColorInNameplate", "1" },
	{ "Большой фрейм фокуса", "fullSizeFocusFrame", "1" },
	{ "Дальность в рейде", "showRaidRange", "1" },
	{ "Ограничение FPS", "maxFPS", "0" },
	{ "Текст статуса игрока", "playerStatusText", "1" },
	{ "Текст статуса цели", "targetStatusText", "0" },
	{ "Текст статуса питомца", "petStatusText", "1" },
	{ "Превью талантов", "previewTalents", "1" },
	{ "Клик по всему окну чата", "wholeChatWindowClickable", "0" },
	{ "Уровень предмета", "showItemLevel", "1" },
	{ "Автолут", "autoLootDefault", "1" },
	{ "Скрывать группу в рейде", "hidePartyInRaid", "1" },
	{ "Подробные подсказки", "UberTooltips", "1" },
	{ "Обучающие подсказки", "showTutorials", "0" },
	{ "Режим беседы", "conversationMode", "inline" },
	{ "Скорость наклона камеры", "cameraPitchMoveSpeed", "55" },
	{ "Локальное время", "timeMgrUseLocalTime", "1" },
	{ "Предупреждение об угрозе", "threatWarning", "0" },
	{ "Угроза в процентах", "threatShowNumeric", "0" },
	{ "Звуки угрозы", "threatPlaySounds", "0" },
	{ "Отслеживание заданий", "autoQuestWatch", "1" },
	{ "Автообновление заданий", "autoQuestProgress", "1" },
	{ "Цвет сложности заданий", "mapQuestDifficulty", "1" },
	{ "Текст боя", "enableCombatText", "1" },
	{ "FCT: урон цели", "CombatDamage", "1" },
	{ "FCT: периодический урон", "CombatLogPeriodicSpells", "1" },
	{ "FCT: урон питомца", "PetMeleeDamage", "1" },
	{ "FCT: лечение", "CombatHealing", "1" },
	{ "FCT: честь", "fctHonorGains", "1" },
	{ "FCT: мало маны/здоровья", "fctLowManaHealth", "0" },
	{ "FCT: уклонение/парирование", "fctDodgeParryMiss", "0" },
	{ "FCT: снижение урона", "fctDamageReduction", "0" },
	{ "FCT: репутация", "fctRepChanges", "0" },
	{ "FCT: проки", "fctReactives", "0" },
	{ "FCT: ауры", "fctAuras", "0" },
	{ "FCT: серия приёмов", "fctComboPoints", "0" },
	{ "FCT: энергия", "fctEnergyGains", "0" },
	{ "FCT: периодическая энергия", "fctPeriodicEnergyGains", "0" },
	{ "FCT: лечение союзников", "fctFriendlyHealers", "0" },
	{ "FCT: вход в бой", "fctCombatState", "0" },
	{ "FCT: механики заклинаний", "fctSpellMechanics", "0" },
	{ "FCT: механики на других", "fctSpellMechanicsOther", "0" },
	{ "PVP-титул у игрока", "UnitNamePlayerPVPTitle", "0" },
	{ "Имена стражей врага", "UnitNameEnemyGuardianName", "1" },
	{ "Имена тотемов врага", "UnitNameEnemyTotemName", "1" },
	{ "Имена стражей союзников", "UnitNameFriendlyGuardianName", "1" },
	{ "Имена тотемов союзников", "UnitNameFriendlyTotemName", "1" },
	{ "Динамический ракурс", "cameraPivot", "0" },
	{ "Дистанция камеры (factor)", "cameraDistanceMaxFactor", "2" },
	{ "Макс. дистанция камеры", "cameraDistanceMax", "50" },
	{ "Скорость авто-следования", "cameraYawSmoothSpeed", "270" },
	{ "Чувствительность мыши", "mouseSpeed", "1.1" },
	{ "Скорость поворота", "cameraYawMoveSpeed", "110" },
}

-- Display / graphics from author Config.wtf (recommended 2K preset).
-- gxResolution / gxRefresh are filled at apply-time from display caps.
-- gx* / MSAA need a full client restart to take effect.
local QUICK_GRAPHICS_DESIRED_RES = "2560x1440"
local QUICK_GRAPHICS_DESIRED_REFRESH = 240
local QUICK_GRAPHICS_CVARS = {
	{ "Разрешение", "gxResolution", QUICK_GRAPHICS_DESIRED_RES },
	{ "Частота обновления", "gxRefresh", tostring(QUICK_GRAPHICS_DESIRED_REFRESH) },
	{ "VSync", "gxVSync", "0" },
	{ "Оконный режим", "gxWindow", "1" },
	{ "Развернуть окно", "gxMaximize", "1" },
	{ "Блок изменения размера окна", "windowResizeLock", "1" },
	{ "Масштаб UI", "useUiScale", "1" },
	{ "Значение UI scale", "uiScale", "0.74" },
	{ "Фильтрация текстур", "textureFilteringMode", "5" },
	{ "Качество текстур", "componentTextureLevel", "9" },
	{ "Тени", "shadowLevel", "0" },
	{ "Качество внешних теней", "extShadowQuality", "5" },
	{ "Дальность прорисовки", "farclip", "507" },
	{ "Детали окружения", "environmentDetail", "1.5" },
	{ "Блики (specular)", "specular", "1" },
	{ "Проекционные текстуры", "projectedTextures", "1" },
	{ "Плотность погоды", "weatherDensity", "0" },
	{ "Эффект свечения", "ffxGlow", "0" },
	{ "Эффект смерти", "ffxDeath", "0" },
	{ "Сглаживание (MSAA)", "gxMultisample", "8" },
	{ "gxFixLag", "gxFixLag", "0" },
	{ "Дальность травы/земли", "groundEffectDist", "70" },
}

local function ParseResolution(res)
	if type(res) ~= "string" then
		return nil, nil
	end
	local w, h = res:match("^(%d+)%s*[xX]%s*(%d+)$")
	return tonumber(w), tonumber(h)
end

-- Prefer recommended 2K if the client lists it; otherwise the largest available mode.
local function ResolveGraphicsResolution()
	local desired = QUICK_GRAPHICS_DESIRED_RES
	if type(GetScreenResolutions) ~= "function" then
		return desired
	end
	local list = { GetScreenResolutions() }
	if #list == 0 then
		return desired
	end
	for _, res in ipairs(list) do
		if res == desired then
			return desired
		end
	end
	local best, bestArea = list[1], 0
	for _, res in ipairs(list) do
		local w, h = ParseResolution(res)
		if w and h then
			local area = w * h
			if area > bestArea then
				bestArea = area
				best = res
			end
		end
	end
	return best or desired
end

-- Prefer 240 Hz if offered; otherwise the highest refresh the client reports.
local function ResolveGraphicsRefresh()
	local desired = QUICK_GRAPHICS_DESIRED_REFRESH
	if type(GetRefreshRates) == "function" then
		local rates = { GetRefreshRates() }
		local best = 0
		local hasDesired = false
		for _, rate in ipairs(rates) do
			local n = tonumber(rate)
			if n then
				if n == desired then
					hasDesired = true
				end
				if n > best then
					best = n
				end
			end
		end
		if hasDesired then
			return tostring(desired)
		end
		if best > 0 then
			return tostring(best)
		end
	end
	-- No API: ask for recommended; the client usually clamps to the monitor max.
	return tostring(desired)
end

local function GetResolvedGraphicsTargets()
	return {
		gxResolution = ResolveGraphicsResolution(),
		gxRefresh = ResolveGraphicsRefresh(),
	}
end

local function GetGraphicsCVarDesired(cvar, resolved)
	if cvar == "gxResolution" then
		return resolved.gxResolution
	end
	if cvar == "gxRefresh" then
		return resolved.gxRefresh
	end
	for _, entry in ipairs(QUICK_GRAPHICS_CVARS) do
		if entry[2] == cvar then
			return entry[3]
		end
	end
	return nil
end

local function FormatQuickValue(value)
	if value == nil then
		return "?"
	end
	local s = tostring(value)
	if s == "1" or s == "true" then
		return "Вкл"
	end
	if s == "0" or s == "false" then
		return "Выкл"
	end
	return s
end

local function NormalizeQuickValue(value)
	if value == nil then
		return nil
	end
	local s = tostring(value)
	local n = tonumber(s)
	if n then
		-- Compare numerically so "50" == 50 and "2.60" == "2.6".
		return string.format("%.4f", n):gsub("0+$", ""):gsub("%.$", "")
	end
	return string.lower(s)
end

local function CVarDiffers(name, desired)
	local ok, current = pcall(GetCVar, name)
	if not ok or current == nil then
		return false
	end
	return NormalizeQuickValue(current) ~= NormalizeQuickValue(desired)
end

local function GetActionBarDiffLine()
	local want1, want2, want3, want4 = 1, 1, 0, 0
	local cur1 = (SHOW_MULTI_ACTIONBAR_1 and 1) or 0
	local cur2 = (SHOW_MULTI_ACTIONBAR_2 and 1) or 0
	local cur3 = (SHOW_MULTI_ACTIONBAR_3 and 1) or 0
	local cur4 = (SHOW_MULTI_ACTIONBAR_4 and 1) or 0
	if GetActionBarToggles then
		local a, b, c, d = GetActionBarToggles()
		if a ~= nil then cur1 = a and 1 or 0 end
		if b ~= nil then cur2 = b and 1 or 0 end
		if c ~= nil then cur3 = c and 1 or 0 end
		if d ~= nil then cur4 = d and 1 or 0 end
	end
	if cur1 == want1 and cur2 == want2 and cur3 == want3 and cur4 == want4 then
		return nil
	end
	local function bar(v)
		return (v == 1) and "Вкл" or "Выкл"
	end
	return string.format(
		"Панели команд 1-4: %s/%s/%s/%s -> %s/%s/%s/%s",
		bar(cur1), bar(cur2), bar(cur3), bar(cur4),
		bar(want1), bar(want2), bar(want3), bar(want4)
	)
end

-- Tooltip lines for «Применить»: only settings that currently differ.
-- Colors match Details Cooltip Preset 2 (orange body text).
function SarychUI:GetQuickSettingsTooltipLines()
	local ORANGE = { 1, 0.65, 0 }
	local ORANGE_DIM = { 1, 0.55, 0.15 }
	local GREEN = { 0.55, 0.95, 0.45 }
	local lines = {}
	local diffs = {}

	for _, entry in ipairs(QUICK_SETTING_CVARS) do
		local label, cvar, desired = entry[1], entry[2], entry[3]
		local ok, current = pcall(GetCVar, cvar)
		if ok and current ~= nil and CVarDiffers(cvar, desired) then
			diffs[#diffs + 1] = string.format(
				"%s: %s -> %s",
				label,
				FormatQuickValue(current),
				FormatQuickValue(desired)
			)
		end
	end

	local bars = GetActionBarDiffLine()
	if bars then
		diffs[#diffs + 1] = bars
	end

	if #diffs == 0 then
		lines[#lines + 1] = { "Быстрые настройки", ORANGE[1], ORANGE[2], ORANGE[3] }
		lines[#lines + 1] = { "Всё уже применено — менять нечего.", GREEN[1], GREEN[2], GREEN[3] }
		return lines
	end

	lines[#lines + 1] = { "Будут изменены:", ORANGE[1], ORANGE[2], ORANGE[3] }
	local maxShow = 14
	for i = 1, math.min(#diffs, maxShow) do
		lines[#lines + 1] = { diffs[i], ORANGE[1], ORANGE[2], ORANGE[3] }
	end
	if #diffs > maxShow then
		lines[#lines + 1] = {
			string.format("...и ещё %d", #diffs - maxShow),
			ORANGE_DIM[1], ORANGE_DIM[2], ORANGE_DIM[3]
		}
	end
	lines[#lines + 1] = { "Также применятся настройки чата.", ORANGE_DIM[1], ORANGE_DIM[2], ORANGE_DIM[3] }
	return lines
end

function SarychUI:GetQuickGraphicsTooltipLines()
	local ORANGE = { 1, 0.65, 0 }
	local ORANGE_DIM = { 1, 0.55, 0.15 }
	local GREEN = { 0.55, 0.95, 0.45 }
	local lines = {}
	local diffs = {}
	local resolved = GetResolvedGraphicsTargets()

	for _, entry in ipairs(QUICK_GRAPHICS_CVARS) do
		local label, cvar = entry[1], entry[2]
		local desired = GetGraphicsCVarDesired(cvar, resolved)
		local ok, current = pcall(GetCVar, cvar)
		if ok and current ~= nil and CVarDiffers(cvar, desired) then
			diffs[#diffs + 1] = string.format(
				"%s: %s -> %s",
				label,
				FormatQuickValue(current),
				FormatQuickValue(desired)
			)
		end
	end

	if #diffs == 0 then
		lines[#lines + 1] = { "Рекомендованная графика", ORANGE[1], ORANGE[2], ORANGE[3] }
		lines[#lines + 1] = { "Уже совпадает с целевыми значениями.", GREEN[1], GREEN[2], GREEN[3] }
		return lines
	end

	lines[#lines + 1] = { "Будут изменены:", ORANGE[1], ORANGE[2], ORANGE[3] }
	local maxShow = 14
	for i = 1, math.min(#diffs, maxShow) do
		lines[#lines + 1] = { diffs[i], ORANGE[1], ORANGE[2], ORANGE[3] }
	end
	if #diffs > maxShow then
		lines[#lines + 1] = {
			string.format("...и ещё %d", #diffs - maxShow),
			ORANGE_DIM[1], ORANGE_DIM[2], ORANGE_DIM[3]
		}
	end
	lines[#lines + 1] = {
		string.format("Цель: %s @ %s Hz (или макс. монитора).", resolved.gxResolution, resolved.gxRefresh),
		ORANGE_DIM[1], ORANGE_DIM[2], ORANGE_DIM[3]
	}
	lines[#lines + 1] = { "Нужен полный перезапуск игры.", ORANGE_DIM[1], ORANGE_DIM[2], ORANGE_DIM[3] }
	return lines
end

-- Apply quick settings (from sarsettings.default)
function SarychUI:ApplyQuickSettings()
	for _, entry in ipairs(QUICK_SETTING_CVARS) do
		SafeSetCVar(entry[2], entry[3])
	end
	-- Optional on some 3.3.5 builds; grouped with pet damage if present.
	SafeSetCVar("PetSpellDamage", "1")

	-- Action bars (persisted toggles on 3.3.5)
	if SetActionBarToggles then
		SetActionBarToggles(1, 1, 0, 0)
	else
		SHOW_MULTI_ACTIONBAR_1 = 1
		SHOW_MULTI_ACTIONBAR_2 = 1
		SHOW_MULTI_ACTIONBAR_3 = 0
		SHOW_MULTI_ACTIONBAR_4 = 0
	end
	if not InCombatLockdown() and MultiActionBar_Update then
		MultiActionBar_Update()
	end

	-- Camera follow: max zoom-out once (CVars already applied above).
	if MoveViewOutStart and not InCombatLockdown() then
		MoveViewOutStart(50000)
	end

	-- Apply chat settings
	self:ApplyQuickChatSettings()

	-- Notify user
	print("|cffffd200SarychUI:|r Быстрые настройки применены.")

	-- Show reload confirmation popup
	if SarychUI.ShowReloadPopup then
		SarychUI:ShowReloadPopup("Быстрые настройки применены!\n\nДля полного применения изменений рекомендуется выполнить перезагрузку интерфейса.")
	end
end

-- Display / graphics (recommended 2K; clamped to display max).
function SarychUI:ApplyQuickGraphicsSettings()
	local resolved = GetResolvedGraphicsTargets()
	for _, entry in ipairs(QUICK_GRAPHICS_CVARS) do
		local cvar = entry[2]
		SafeSetCVar(cvar, GetGraphicsCVarDesired(cvar, resolved))
	end
	print(string.format(
		"|cffffd200SarychUI:|r Графика применена (%s @ %s Hz). Нужен полный перезапуск игры.",
		tostring(resolved.gxResolution),
		tostring(resolved.gxRefresh)
	))
	if SarychUI.ShowReloadPopup then
		local tpl = (self.T and self:T(
			"Рекомендованные настройки графики применены!\n\nТребуется полный перезапуск игры (закрыть клиент и запустить снова).\nВыбрано: %s @ %s Hz."
		)) or "Рекомендованные настройки графики применены!\n\nТребуется полный перезапуск игры (закрыть клиент и запустить снова).\nВыбрано: %s @ %s Hz."
		-- Already translated template; pass as-is (ShowReloadPopup will T again with no map hit).
		SarychUI:ShowReloadPopup(string.format(
			tpl,
			tostring(resolved.gxResolution),
			tostring(resolved.gxRefresh)
		))
	end
end

-- Apply quick chat settings (from settings.default.chat.lua)
function SarychUI:ApplyQuickChatSettings()
	if not FCF_OpenNewWindow or not ChatFrame_AddMessageGroup then
		return
	end

	local MAX_CHAT_FRAMES = 5

	-- Chat color settings
	local chatColorSettings = {
		{"SYSTEM", 255, 255, 0, "N"},
		{"SAY", 255, 255, 255, "Y"},
		{"PARTY", 170, 170, 255, "Y"},
		{"RAID", 255, 127, 0, "Y"},
		{"GUILD", 64, 255, 64, "Y"},
		{"OFFICER", 64, 192, 64, "Y"},
		{"YELL", 255, 64, 64, "Y"},
		{"WHISPER", 255, 128, 255, "Y"},
		{"WHISPER_FOREIGN", 255, 128, 255, "N"},
		{"WHISPER_INFORM", 255, 128, 255, "Y"},
		{"EMOTE", 255, 128, 64, "Y"},
		{"TEXT_EMOTE", 255, 128, 64, "Y"},
		{"MONSTER_SAY", 255, 255, 159, "N"},
		{"MONSTER_PARTY", 170, 170, 255, "Y"},
		{"MONSTER_YELL", 255, 64, 64, "N"},
		{"MONSTER_WHISPER", 255, 181, 235, "N"},
		{"MONSTER_EMOTE", 255, 128, 64, "N"},
		{"CHANNEL", 255, 192, 192, "N"},
		{"AFK", 255, 128, 255, "Y"},
		{"DND", 255, 128, 255, "Y"},
		{"IGNORED", 255, 0, 0, "N"},
		{"SKILL", 85, 85, 255, "N"},
		{"LOOT", 0, 170, 0, "N"},
		{"MONEY", 255, 255, 0, "N"},
		{"RAID_LEADER", 255, 72, 9, "Y"},
		{"RAID_WARNING", 255, 72, 0, "Y"},
		{"BATTLEGROUND", 255, 127, 0, "Y"},
		{"BATTLEGROUND_LEADER", 255, 219, 183, "Y"},
		{"ACHIEVEMENT", 255, 255, 0, "Y"},
		{"GUILD_ACHIEVEMENT", 64, 255, 64, "Y"},
		{"PARTY_LEADER", 118, 200, 255, "Y"},
		{"CHANNEL1", 255, 192, 192, "Y"},
		{"CHANNEL2", 255, 204, 204, "Y"},
		{"CHANNEL3", 255, 204, 204, "Y"},
		{"CHANNEL4", 255, 204, 204, "Y"},
	}

	-- Configure chat colors
	for _, colorSetting in ipairs(chatColorSettings) do
		local messageType, r, g, b, enableClassColor = unpack(colorSetting)
		if ChangeChatColor then
			ChangeChatColor(messageType, r / 255, g / 255, b / 255)
		end
		if SetChatColorNameByClass then
			if enableClassColor == "Y" then
				SetChatColorNameByClass(messageType, true)
			else
				SetChatColorNameByClass(messageType, false)
			end
		end
	end

	local function LocaleChatString(key, fallback)
		local value = _G[key]
		if type(value) == "string" and value ~= "" then
			return value
		end
		return fallback
	end

	-- Tab titles follow the client locale (Общий / Журнал боя on ruRU).
	-- Channel names come from ChatBar locale, which matches 3.3.5 zone channels.
	local generalTabName = LocaleChatString("GENERAL", "Общий")
	local combatLogTabName = "Журнал"
	local generalChannel = LocaleChatString("CHATBAR_GENERAL", generalTabName)
	local tradeChannel = LocaleChatString("CHATBAR_TRADE", "Торговля")
	local defenseChannel = LocaleChatString("CHATBAR_LOCALDEFENSE", "Оборона")
	local lfgChannel = LocaleChatString("CHATBAR_LFG", LocaleChatString("LOOKING_FOR_GROUP", "Поиск спутников"))

	-- Geometry from Sporta chat-cache. Tabs: Общий, Журнал, General, /w, Loot.
	local chatWindowsSettings = {
		{
			index = 1,
			name = generalTabName,
			size = 13,
			color = {0, 0, 0, 17},
			locked = true,
			shown = true,
			messages = {
				"SYSTEM", "SYSTEM_NOMENU", "SAY", "EMOTE", "YELL", "PARTY",
				"PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING", "BATTLEGROUND",
				"BATTLEGROUND_LEADER", "GUILD", "OFFICER", "MONSTER_SAY", "MONSTER_YELL",
				"MONSTER_EMOTE", "MONSTER_WHISPER", "MONSTER_BOSS_EMOTE", "MONSTER_BOSS_WHISPER",
				"ERRORS", "AFK", "DND", "IGNORED", "BG_HORDE", "BG_ALLIANCE", "BG_NEUTRAL",
				"COMBAT_FACTION_CHANGE", "SKILL", "CHANNEL", "ACHIEVEMENT", "GUILD_ACHIEVEMENT",
				"TARGETICONS", "BN_WHISPER", "BN_WHISPER_INFORM", "BN_CONVERSATION",
				"BN_INLINE_TOAST_ALERT", "OPENING"
			},
			channels = { generalChannel, tradeChannel, defenseChannel },
			position = {"BOTTOMLEFT", 0.018970, 0.160158},
			dimensions = {389.272827, 124.266113}
		},
		{
			index = 2,
			name = combatLogTabName,
			size = 13,
			color = {0, 0, 0, 10},
			locked = true,
			shown = false,
			messages = {
				"OPENING", "TRADESKILLS", "PET_INFO",
				"COMBAT_XP_GAIN", "COMBAT_HONOR_GAIN", "COMBAT_MISC_INFO"
			},
			channels = {},
		},
		{
			index = 3,
			name = "General",
			size = 13,
			color = {15, 15, 15, 33},
			locked = true,
			shown = false,
			messages = {},
			channels = { lfgChannel },
		},
		{
			index = 4,
			name = "/w",
			size = 13,
			color = {0, 0, 0, 12},
			locked = true,
			shown = false,
			messages = {"WHISPER", "CHANNEL"},
			channels = {},
		},
		{
			index = 5,
			name = "Loot",
			size = 13,
			color = {0, 0, 0, 10},
			locked = true,
			shown = false,
			messages = {"SYSTEM", "PARTY_LEADER", "RAID_LEADER", "RAID_WARNING", "LOOT", "MONEY", "COMBAT_MISC_INFO"},
			channels = {},
		}
	}

	local function ClearChatFrameChannels(chatFrame)
		if not chatFrame or not ChatFrame_RemoveChannel then
			return
		end
		local copy = {}
		if type(chatFrame.channelList) == "table" then
			for i = 1, #chatFrame.channelList do
				copy[#copy + 1] = chatFrame.channelList[i]
			end
		end
		for i = 1, #copy do
			ChatFrame_RemoveChannel(chatFrame, copy[i])
		end
	end

	local function CreateChatWindowIfNeeded(index, name)
		local chatFrame = _G["ChatFrame" .. index]
		if not chatFrame then
			if FCF_OpenNewWindow then
				local newChatFrame = FCF_OpenNewWindow(name)
				if newChatFrame then
					if FCF_DockFrame then
						FCF_DockFrame(newChatFrame)
					end
					chatFrame = newChatFrame
				end
			end
		elseif name and name ~= "" and FCF_SetWindowName then
			FCF_SetWindowName(chatFrame, name)
		end
		return chatFrame
	end

	local function ConfigureChatWindow(index, settings)
		local chatFrame = CreateChatWindowIfNeeded(index, settings.name)
		if not chatFrame then return false end

		if FCF_SetChatWindowFontSize then
			FCF_SetChatWindowFontSize(nil, chatFrame, settings.size)
		end
		local r, g, b, a = unpack(settings.color)
		chatFrame:SetBackdropColor(r / 255, g / 255, b / 255, a / 255)

		-- Unlock first: locked frames ignore move/resize.
		if FCF_SetLocked then
			FCF_SetLocked(chatFrame, false)
		end

		if settings.shown then
			if FCF_UnDockFrame then
				FCF_UnDockFrame(chatFrame)
			end
			chatFrame:Show()
		else
			chatFrame:Hide()
		end

		if settings.position and settings.dimensions then
			local point, nx, ny = settings.position[1], settings.position[2], settings.position[3]
			local w, h = settings.dimensions[1], settings.dimensions[2]
			-- Same path as Blizzard chat-cache: write saved coords, then restore.
			if SetChatWindowSavedDimensions then
				SetChatWindowSavedDimensions(chatFrame:GetID(), w, h)
			end
			if SetChatWindowSavedPosition then
				SetChatWindowSavedPosition(chatFrame:GetID(), point, nx, ny)
			end
			if FCF_RestorePositionAndDimensions then
				FCF_RestorePositionAndDimensions(chatFrame)
			else
				local screenW = (GetScreenWidth and GetScreenWidth()) or UIParent:GetWidth()
				local screenH = (GetScreenHeight and GetScreenHeight()) or UIParent:GetHeight()
				chatFrame:ClearAllPoints()
				chatFrame:SetPoint(point, UIParent, point, nx * screenW, ny * screenH)
				chatFrame:SetWidth(w)
				chatFrame:SetHeight(h)
			end
			if chatFrame.SetUserPlaced then
				chatFrame:SetUserPlaced(true)
			end
			if FloatingChatFrame_UpdateBackgroundAnchors then
				FloatingChatFrame_UpdateBackgroundAnchors(chatFrame)
			end
		end

		if FCF_SetLocked and settings.locked then
			FCF_SetLocked(chatFrame, true)
		end

		-- Configure message groups
		if CHAT_CONFIG_CHAT_LEFT and ChatFrame_RemoveMessageGroup then
			for _, group in ipairs(CHAT_CONFIG_CHAT_LEFT) do
				ChatFrame_RemoveMessageGroup(chatFrame, group.type)
			end
		end
		for _, messageGroup in ipairs(settings.messages) do
			if ChatFrame_AddMessageGroup then
				ChatFrame_AddMessageGroup(chatFrame, messageGroup)
			end
		end

		ClearChatFrameChannels(chatFrame)
		if settings.channels then
			for _, channel in ipairs(settings.channels) do
				if channel and channel ~= "" then
					if JoinPermanentChannel then
						JoinPermanentChannel(channel, nil, chatFrame:GetID(), 1)
					end
					if ChatFrame_AddChannel then
						ChatFrame_AddChannel(chatFrame, channel)
					end
				end
			end
		end

		return true
	end

	for i = 3, MAX_CHAT_FRAMES do
		local chatFrame = _G["ChatFrame" .. i]
		if chatFrame and not chatFrame.isDocked and FCF_DockFrame then
			FCF_DockFrame(chatFrame)
		end
		if not chatFrame then
			CreateChatWindowIfNeeded(i, "Новая Вкладка " .. i)
		end
	end

	for _, settings in ipairs(chatWindowsSettings) do
		ConfigureChatWindow(settings.index, settings)
	end

	-- Undock/restore can fight SetPoint once; pin Общий geometry again at the end.
	local main = chatWindowsSettings[1]
	local chatFrame = _G.ChatFrame1 or DEFAULT_CHAT_FRAME
	if chatFrame and main and main.position and main.dimensions then
		if FCF_SetLocked then
			FCF_SetLocked(chatFrame, false)
		end
		local point, nx, ny = main.position[1], main.position[2], main.position[3]
		local w, h = main.dimensions[1], main.dimensions[2]
		if SetChatWindowSavedDimensions then
			SetChatWindowSavedDimensions(chatFrame:GetID(), w, h)
		end
		if SetChatWindowSavedPosition then
			SetChatWindowSavedPosition(chatFrame:GetID(), point, nx, ny)
		end
		if FCF_RestorePositionAndDimensions then
			FCF_RestorePositionAndDimensions(chatFrame)
		else
			local screenW = (GetScreenWidth and GetScreenWidth()) or UIParent:GetWidth()
			local screenH = (GetScreenHeight and GetScreenHeight()) or UIParent:GetHeight()
			chatFrame:ClearAllPoints()
			chatFrame:SetPoint(point, UIParent, point, nx * screenW, ny * screenH)
			chatFrame:SetWidth(w)
			chatFrame:SetHeight(h)
		end
		if chatFrame.SetUserPlaced then
			chatFrame:SetUserPlaced(true)
		end
		if FCF_SetLocked and main.locked then
			FCF_SetLocked(chatFrame, true)
		end
	end
end

-- Initialize options when AddOn is ready
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" and AceConfig and AceConfigDialog then
		SarychUI:InitializeOptions()
		-- Create ESC menu button
		CreateSarychUIButton()
		ScheduleOptionsWarmup()
		self:UnregisterEvent("PLAYER_LOGIN")
	elseif event == "PLAYER_REGEN_ENABLED" then
		if SarychUI._optionsWarmupPending and SarychUI.WarmupOptionsUI then
			SarychUI:WarmupOptionsUI()
		end
	end
end)
