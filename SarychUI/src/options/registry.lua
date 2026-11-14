local SuiTimer = select(2, ...).Compat.Timer
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
local StaticPopupDialogs = StaticPopupDialogs
local UISpecialFrames = UISpecialFrames
local LibStub = LibStub

local ADDON_NAME = "SarychUI"
local ENP_CONFIG_APP = "SarychUI_ElvUI_NamePlates"
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
	title:SetText(SarychUI:T("ui.options_60b22f8754"))
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

	local accept = MakeBtn(SarychUI.L["UI_Accept"])
	accept:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -8, 14)
	accept:SetScript("OnClick", function()
		f._accepted = true
		local onAccept = f._onAccept
		f._onAccept = nil
		f._onCancel = nil
		f:Hide()
		if type(onAccept) == "function" then
			local ok, err = pcall(onAccept)
			if not ok then
				geterrorhandler()(err)
			end
		else
			ReloadUI()
		end
	end)
	f.accept = accept

	local cancel = MakeBtn(SarychUI:T("ui.options_0ec753be8d"))
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

	-- Esc closes without reload (triggers OnHide -> onCancel).
	tinsert(UISpecialFrames, "SarychUIReloadPopup")

	reloadPopup = f
	return f
end

-- text: message
-- onCancel: optional (Cancel / Esc)
-- onAccept: optional; if nil, Accept runs ReloadUI()
function SarychUI:ShowReloadPopup(text, onCancel, onAccept)
	local msg = text or SarychUI:T("ui.options_842b8d48e3")
	if self.T then
		msg = self:T(msg)
	end
	local f = EnsureReloadPopup()
	f.title:SetText(self:T("ui.options_60b22f8754"))
	f.accept.label:SetText(self.L["UI_Accept"])
	f.cancel.label:SetText(self:T("ui.options_0ec753be8d"))
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

local function RunAfterFrames(callback, frameCount)
	frameCount = frameCount or 1
	if SarychUI.OptionsPool then
		SarychUI.OptionsPool:After(callback, "run", frameCount, callback)
		return
	end
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
	local driver = frame._suiOptionsFadeDriver or CreateFrame("Frame")
	frame._suiOptionsFadeDriver = driver
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
	driver:Show()
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
	-- Closing /sui schedules a deferred cleanup which cancels SarychUI fade
	-- drivers. Do not leave the separate ENP window at alpha 0 while that
	-- cleanup is racing with its first frame.
	if nativeFrame.SetAlpha then
		nativeFrame:SetAlpha(1)
	end
	if nativeFrame.Show then
		nativeFrame:Show()
	end
	if nativeFrame.Raise then
		nativeFrame:Raise()
	end
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
	if self.AuraTrackingOptionsCore then self.AuraTrackingOptionsCore:Close() end
	self:CloseSarychUIConfig()
end

function SarychUI:CloseSarychUIConfig()
	if self._optionsClosing then
		return
	end
	self._optionsClosing = true
	local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
	local legacyOpen = ACD and ACD.OpenFrames and ACD.OpenFrames[ADDON_NAME]
	local needsDeferredCleanup = legacyOpen or self.GUIFrame

	if self.OptionsCore and self.OptionsCore.Close then
		self.OptionsCore:Close()
	end

	if self.CancelAceConfigDialogPendingRefresh then
		self:CancelAceConfigDialogPendingRefresh(ADDON_NAME)
	end

	if self.CleanupOptionsUI then
		self:CleanupOptionsUI({ forceHideFrame = true, closing = true })
	end

	if legacyOpen then
		local open = legacyOpen
		if open and open.frame and open.frame.SetAlpha then
			open.frame:SetAlpha(1)
		end
		ACD:Close(ADDON_NAME)
	end

	self.GUIFrame = nil
	self._optionsClosing = nil

	if needsDeferredCleanup and self.ScheduleDeferredOptionsCleanup then
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
	if except ~= MAPSTER_CONFIG_APP then
		self:CloseMapsterConfig()
	end
	self:CloseCarboniteConfig()
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
	-- Prefer ElvUI AceConfigDialog (private AceGUI pool) - not the Cooltip ENPOptionsCore shell.
	if ENP.ForceOpenOptionsUI then
		opened = ENP:ForceOpenOptionsUI()
	elseif ENP.OpenOptionsUI then
		opened = ENP:OpenOptionsUI()
	elseif ENP.ToggleOptionsUI then
		ENP:ToggleOptionsUI()
		opened = true
	else
		print("|cffffd200SarychUI:|r No ENP open function found.")
		return false
	end

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
	if self.OpenOptions then
		self:OpenOptions()
	end
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

		return
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
			if db.showDebuffDragFrame == 1 then
				db.showDebuffDragFrame = 0
				aurasClose = true
			end
			if db.showDebuffGrid == 1 then
				db.showDebuffGrid = 0
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

	-- 3a. Ресурсы игрока (свободное перемещение)
	do
		local prModule = SarychUI and SarychUI.modules and SarychUI.modules.player_resources
		local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.player_resources
		if db and prModule then
			local panel = SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel
			local subs = { "plate", "shield", "runes", "totems" }
			local dragIds = {
				plate = "playerPlate",
				shield = "playerShield",
				runes = "playerRunes",
				totems = "playerTotems",
			}
			for i = 1, #subs do
				local sub = db[subs[i]]
				if sub and sub.showDragFrame == 1 then
					sub.showDragFrame = 0
					sub.showGrid = 0
					shouldClose = true
					local frameId = dragIds[subs[i]]
					if panel and panel.IsOpen and panel:IsOpen() and panel.GetFrameId and panel:GetFrameId() == frameId then
						panel:Close(false)
					end
				end
			end
			if shouldClose and prModule.Refresh then
				prModule:Refresh()
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

	-- 3c. Диминишинги без крепления.
	do
		local dr = SarychUI and SarychUI.extensions and SarychUI.extensions.diminishings
		if dr and dr.IsFreeMoveActive and dr.StopFreeMoveKind then
			for _, kind in ipairs({ "player", "target", "focus", "party" }) do
				local active = kind == "party" and (dr:IsFreeMoveActive("party1")
					or dr:IsFreeMoveActive("party2") or dr:IsFreeMoveActive("party3")
					or dr:IsFreeMoveActive("party4")) or dr:IsFreeMoveActive(kind)
				if active then
					dr:StopFreeMoveKind(kind)
					shouldClose = true
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
			name = "ui.general_b250a3d6",
			order = 1,
			childGroups = "tree",
			args = {
				overview = {
					type = "group",
					name = "ui.options_e2a01094ae",
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
							image = "Interface\\AddOns\\SarychUI\\media\\components\\options\\SarychUI.blp",
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
							name = "ui.options_d9396e7d7f",
							desc = "ui.options_c26ec5a93b",
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
									OW.header.subtitle:SetText(SarychUI:T("ui.settings_985b5e0f"))
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
						thanks = {
							type = "description",
							name = function()
								if L and L["SarychUI Thanks"] then
									return L["SarychUI Thanks"]
								end
								return SarychUI:T("ui.options_0237dd33bb")
							end,
							order = 3,
							width = "full",
						},
						icecrownArt = {
							type = "description", name = "", order = 99, width = "full",
							image = "Interface\\LFGFrame\\UI-LFG-BACKGROUND-IcecrownCitadel.blp",
							imageWidth = 256, imageHeight = 128,
							suiFadedImage = true, suiImageCorner = "BOTTOMRIGHT",
							suiImageBackground = true,
						},
					},
				},
				quick = {
					type = "group",
					name = "ui.options_37bddc37d4",
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
							name = "ui.options_410b48fb2b",
							order = 3,
							inline = true,
							args = {
								applyButton = {
									type = "execute",
									name = "ui.options_768af67762",
									desc = "ui.options_120af381ae",
									order = 1,
									width = "full",
									suiExpandDetails = {
										name = function() return SarychUI._quickSettingsExpanded and "v" or ">" end,
										func = function()
											SarychUI._quickSettingsExpanded = not SarychUI._quickSettingsExpanded
											local core = SarychUI._activeOptionsCore or SarychUI.OptionsCore
											if core and core.Refresh then core:Refresh() end
										end,
									},
									suiTooltip = function()
										return SarychUI:GetQuickSettingsTooltipLines()
									end,
									func = function()
										SarychUI:ApplyQuickSettings()
									end,
								},
								quickStatus = {
									type = "description",
									name = function() return SarychUI:GetQuickSettingsStatusText() end,
									hidden = function() return not SarychUI._quickSettingsExpanded end,
									order = 1.5,
									width = "full",
								},
								reloadQuickButton = {
									type = "execute",
									name = "ui.reload_da28911d",
									order = 1.6,
									width = "full",
									hidden = function() return not SarychUI:QuickSettingsHasPendingReload() end,
									func = function() ReloadUI() end,
								},
								applyGraphicsButton = {
									type = "execute",
									name = "ui.options_3239e48220",
									desc = "ui.options_49c5974bd6",
									order = 2,
									width = "full",
									suiTooltip = function()
										return SarychUI:GetQuickGraphicsTooltipLines()
									end,
									func = function()
										SarychUI:ShowReloadPopup(
											SarychUI:T("ui.options_cc9962f4e7"),
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
							name = "ui.options_759983dd1e",
							order = 4,
							width = "full",
						},
					},
				},
				profiles = {
					type = "group",
					name = "ui.options_df9bc7ac5c",
					order = 3,
					args = {},
				},
			},
		},
		
		modules = {
			type = "group",
			name = "ui.options_09017097da",
			order = 2,
			childGroups = "tree",
			args = {
				-- Module options will be added here
			},
		},
		
		extensions = {
			type = "group",
			name = function() return SarychUI.L["Extensions_Title"] end,
			order = 2.5,
			args = { registered = { type = "group", name = "", order = 1, args = {} } },
		},

		addons = {
			type = "group",
			name = "ui.options_e9cc690fa7",
			order = 3,
			childGroups = "tab",
			args = {
			ported = {
				type = "group",
				name = "ui.control_a4bba03c",
				order = 1,
				args = {},
			},
			},
		},

		system = {
			type = "group",
			name = function() return L["System"] or SarychUI:T("ui.options_3ac98f278c") end,
			order = 4,
			childGroups = "tab",
			args = {
				overview = {
					type = "group",
					name = function() return L["System_Overview"] or SarychUI:T("ui.options_39c6387206") end,
					order = 0,
					args = {
						dllHeader = {
							type = "description",
							name = function() return (L["Dll_Detection_Header"] or SarychUI:T("ui.options_563cc7cb28")) end,
							suiSpinner = true,
							order = 1,
							width = "full",
							hidden = function()
								local compat = SarychUI.Compatibility
								-- Hide the searching header once DLL presence checks have a final answer.
								return compat and compat.AreAllDllStatusesResolved and compat:AreAllDllStatusesResolved()
							end,
						},
						dllStatus = {
							type = "description",
							name = function()
								local compat = SarychUI.Compatibility
								if not compat then
									return SarychUI:T("ui.options_49222e8642")
								end
								return compat:GetDllStatusBlock()
							end,
							order = 2,
							width = "full",
						},
						lockdownDebugBox = {
							type = "group",
							name = function() return L["Lockdown_Debug_Group"] or SarychUI:T("ui.options_1440a9e1cf") end,
							order = 3,
							inline = true,
							args = {
								lockdownErrorSearch = {
									type = "toggle",
									name = function() return L["Lockdown_Debug_Enable"] or SarychUI:T("ui.enable_a54eaf37") end,
									desc = function() return L["Lockdown_Debug_Desc"] or SarychUI:T("ui.options_11f75c40e1") end,
									order = 1,
									width = "full",
									get = function()
										if SarychUI.IsLockdownErrorSearchEnabled then
											return SarychUI:IsLockdownErrorSearchEnabled()
										end
										local system = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.system
										return system and (system.lockdownErrorSearch == true or system.lockdownErrorSearch == 1) or false
									end,
									set = function(_, value)
										if SarychUI.SetLockdownErrorSearchEnabled then
											SarychUI:SetLockdownErrorSearchEnabled(value)
										else
											SarychUI.db.profile.system = SarychUI.db.profile.system or {}
											SarychUI.db.profile.system.lockdownErrorSearch = value and true or false
										end
									end,
								},
								lockdownDebugNote = {
									type = "description",
									name = function() return L["Lockdown_Debug_Note"] or SarychUI:T("ui.options_4e476f60d3") end,
									order = 2,
									width = "full",
								},
							},
						},
						combatOpenBox = {
							type = "group",
							name = function() return L["Options_InCombat_Group"] or SarychUI:T("ui.options_e079664747") end,
							order = 4,
							inline = true,
							args = {
								allowOptionsInCombat = {
									type = "toggle",
									name = function() return L["Options_InCombat_Enable"] or SarychUI:T("ui.options_616bb19d6c") end,
									desc = function() return L["Options_InCombat_Desc"] or SarychUI:T("ui.options_817e2d8feb") end,
									order = 1,
									width = "full",
									get = function()
										if SarychUI.AllowOptionsInCombat then
											return SarychUI:AllowOptionsInCombat()
										end
										local system = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.system
										return system and (system.allowOptionsInCombat == true or system.allowOptionsInCombat == 1) or false
									end,
									set = function(_, value)
										SarychUI.db.profile.system = SarychUI.db.profile.system or {}
										SarychUI.db.profile.system.allowOptionsInCombat = value and true or false
									end,
								},
								allowOptionsInCombatNote = {
									type = "description",
									name = function() return L["Options_InCombat_Note"] or SarychUI:T("ui.options_c1016ef34b") end,
									order = 2,
									width = "full",
								},
							},
						},
					},
				},
			},
		},
	},
}

local function IsAwesomeWotlkDetected()
	local compat = SarychUI and SarychUI.Compatibility
	if not compat then
		return false
	end
	if compat.GetDllDetectionState then
		return compat:GetDllDetectionState("awesome_wotlk") == "detected"
	end
	if compat.DetectAwesomeWotlkDll then
		return compat:DetectAwesomeWotlkDll()
	end
	return false
end

-- System has a single page; render its controls directly without an Overview tab.
options.args.system.args = options.args.system.args.overview.args
options.args.system.childGroups = nil
options.args.system.args.optionsKeybindBox = {
	type = "group",
	name = function() return L["Options_Keybind_Group"] end,
	order = 6,
	inline = true,
	args = {
		enabled = {
			type = "toggle",
			name = function() return L["Options_Keybind_Enable"] end,
			order = 1,
			width = "full",
			get = function()
				local system = SarychUI.db.profile.system
				return system.optionsKeybindEnabled == true or system.optionsKeybindEnabled == 1
			end,
			set = function(_, value)
				SarychUI.db.profile.system.optionsKeybindEnabled = value and true or false
				SarychUI:ApplyOptionsKeybinding()
			end,
		},
		key = {
			type = "keybinding",
			name = function() return L["Options_Keybind_Key"] end,
			desc = function() return L["Options_Keybind_Desc"] end,
			order = 2,
			width = "full",
			disabled = function()
				local system = SarychUI.db.profile.system
				return system.optionsKeybindEnabled ~= true and system.optionsKeybindEnabled ~= 1
			end,
			get = function() return SarychUI.db.profile.system.optionsKeybind end,
			set = function(_, value)
				SarychUI.db.profile.system.optionsKeybind = value or ""
				SarychUI:ApplyOptionsKeybinding()
			end,
		},
	},
}
options.args.system.args.useAwesomeWotlk = {
	type = "group",
	name = "ui.use_awesomewotlk_0cb182c4",
	order = 5,
	inline = true,
	args = {
		notDetectedNotice = {
			type = "description",
			name = "ui.cffff4444awesomewotlk_not_detected_r_cff808080st_3db2ae3e",
			order = 0,
			width = "full",
			hidden = function()
				return IsAwesomeWotlkDetected()
			end,
		},
		enabled = {
			type = "toggle",
			name = "ui.enable_awesomewotlk_support_682ef994",
			desc = "ui.bypasses_client_api_limits_more_stable_accurate__38c7c541",
			order = 1,
			width = "full",
			disabled = function()
				return not IsAwesomeWotlkDetected()
			end,
			get = function()
				return SarychUI.db.profile.modules.plates_auras.useAwesomeWotlk == true
			end,
			set = function(info, value)
				if not IsAwesomeWotlkDetected() then
					return
				end
				local db = SarychUI.db.profile.modules.plates_auras
				local previous = db.useAwesomeWotlk and true or false
				value = value and true or false
				if previous == value then
					return
				end
				db.useAwesomeWotlk = value
				if value then
					if _G.sarPlatesAuras_SetNameplateDistance and _G.sarPlatesAuras_SetNameplateDistance(42) then
						print(SarychUI:T("ui.options_03beab3cbc"))
					else
						print(SarychUI:T("ui.options_da0e32bf22"))
					end
				end
				SarychUI:ShowReloadPopup(SarychUI:T("ui.options_63eefdecf4"), function()
					db.useAwesomeWotlk = previous
					local owner = SarychUI:GetModule("plates_auras")
					if owner and owner.ApplySettings then owner:ApplySettings() end
					local core = SarychUI._activeOptionsCore or SarychUI.OptionsCore
					if core and core.Refresh then core:Refresh() end
				end)
			end,
		},
		modeHint = {
			type = "description",
			name = "ui.cffffd700note_r_applying_this_requires_a_ui_relo_a728615e",
			order = 4,
			width = "full",
			hidden = function() return not SarychUI.db.profile.modules.plates_auras.enabled end,
		},

	},
}


-- Initialize options
function SarychUI:InitializeOptions()

	-- AceGUI skin/patches: Blizzard Interface Options + ENP AceConfigDialog windows.
	if self.InstallSarychUIOptionsSkinLayer then
		self:InstallSarychUIOptionsSkinLayer()
	end
	if self.InstallAceGUIOptionsWidgetPatches then
		self:InstallAceGUIOptionsWidgetPatches()
	end

	-- Register a getter instead of the table itself: AceConfigRegistry calls it the first
	-- time anything asks for our options, so module/addon trees are not built at login.
	AceConfig.RegisterOptionsTable(AceConfig, ADDON_NAME, function()
		return SarychUI:BuildOptionsTable()
	end)
	SarychUI._optionsTableRegistered = true
	AceConfigDialog:SetDefaultSize(ADDON_NAME, SarychUI:GetConfigDefaultSize())
	
	-- This category is only a splash page. An AceConfig container can populate
	-- its options tree during registration, before our OnShow is installed.
	local optionsFrame = CreateFrame("Frame")
	optionsFrame.name = ADDON_NAME
	optionsFrame:Hide()
	
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
			if appName == ADDON_NAME and SarychUI.IsOptionsBlockedByCombat and SarychUI:IsOptionsBlockedByCombat() then
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
			if appName == ADDON_NAME and SarychUI.CloseMapsterConfig then
				SarychUI:CloseMapsterConfig()
			end
			if appName == ADDON_NAME and SarychUI.CloseCarboniteConfig then
				SarychUI:CloseCarboniteConfig()
			end
			if appName == MAPSTER_CONFIG_APP and SarychUI.CloseSarychUIConfig then
				SarychUI:CloseSarychUIConfig()
				if SarychUI.CloseNamePlatesConfig then
					SarychUI:CloseNamePlatesConfig()
				end
			end
			
			local result
				result = originalOpen(self, appName, ...)
			if appName == ADDON_NAME then
				-- Ждем кадр, чтобы окно точно создалось
				SuiTimer.After(0, function()
					local widget = AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[appName]
					if not widget then return end

					local nativeFrame = widget.frame
						EnsureSarychUIConfigVisible()
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
		elseif SarychUI.OnSarychUIConfigHidden and SuiTimer and SuiTimer.After then
			SuiTimer.After(0, function()
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
			maintitle:SetText(SarychUI:T("ui.options_2474d90d99"))
			maintitle:SetFont(maintitle:GetFont(), 72)
			maintitle:ClearAllPoints()
			maintitle:SetPoint("TOP", 0, -72)

			local expTitle = interPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
			expTitle:SetText(SarychUI:T("ui.options_15176d7660"))
			expTitle:SetFont(expTitle:GetFont(), 32)
			expTitle:ClearAllPoints()
			expTitle:SetPoint("TOP", 0, -152)

			local subTitle = interPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
			subTitle:SetText(SarychUI:T("ui.options_54606067f3"))
			subTitle:SetFont(subTitle:GetFont(), 20)
			subTitle:ClearAllPoints()
			subTitle:SetPoint("BOTTOM", 0, 72)

			local slashTitle = interPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
			slashTitle:SetText(SarychUI:T("ui.options_7f546200ed"))
			slashTitle:SetFont(slashTitle:GetFont(), 72)
			slashTitle:ClearAllPoints()
			slashTitle:SetPoint("BOTTOM", subTitle, "TOP", 0, 40)

			local pTex = interPanel:CreateTexture(nil, "BACKGROUND")
			pTex:SetAllPoints()
			pTex:SetTexture("Interface\\GLUES\\Models\\UI_MainMenu\\swordgradient2")
			pTex:SetAlpha(0.2)
			pTex:SetTexCoord(0, 1, 1, 0)
		end)
	end
	
	-- Store frame reference
	self.optionsFrame = optionsFrame
	-- Register only after the splash handler exists: Blizzard may show the
	-- selected category immediately when its options window is already open.
	InterfaceOptions_AddCategory(optionsFrame)

end

-- Fill the registered root table on first demand (first /sui open or first read of the
-- Ace registry). Idempotent: later calls return the already built table.
function SarychUI:BuildOptionsTable()
	if self._optionsTableBuilt then
		return options
	end
	self._optionsTableBuilt = true

	-- Nothing can be listening yet on the first build, so skip the refresh notify.
	self._optionsTableBuilding = true
	self.AddModuleOptions(self)
	self.AddExtensionOptions(self)
	self.AddAddOnOptions(self)
	self._optionsTableBuilding = nil

	if AceDBOptions and self.db then
		local profileOpts = AceDBOptions.GetOptionsTable(AceDBOptions, self.db)
		if self.CustomizeProfileOptions then
			self:CustomizeProfileOptions(profileOpts)
		end
		profileOpts.name = self:T("ui.options_df9bc7ac5c")
		profileOpts.order = 3
		if options.args.general and options.args.general.args then
			options.args.general.args.profiles = profileOpts
		else
			options.args.profiles = profileOpts
		end
	end

	-- Expose root table for custom OptionsCore renderer (data source only).
	self._customOptionsRoot = options
	if self.RefreshQuickStartCatalogOptions then
		self:RefreshQuickStartCatalogOptions()
	end
	return options
end

-- Build the options tree and hidden window after login so the first /sui
-- is already laid out. Not a delayed show - Open() still works if this
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

	return self:_AddModuleOptionsImpl()
end

local moduleOrder = {
	frame = 10,
	auras = 11,
	minimap = 20,
	map = 22,
	mainmenubar = 30,
	castbar = 30.25,
	floating_text = 32,
	group_frames = 33,
	arena = 35,
	chat = 40,
	bags = 65,
	automation = 70,
	health_indicators = 75,
	plates_auras = 80,
}

function SarychUI:GetModuleOptionsOrder(moduleName)
	return moduleOrder[moduleName] or 100
end

function SarychUI:_AddModuleOptionsImpl()
	for name, module in pairs(self.modules) do
		if module.GetOptions and not module.isExtension then
			local stage = "module.GetOptions:" .. name
			local moduleOpts
				moduleOpts = module:GetOptions()
			if self.WrapModuleOptionsWithEnableHeader then
				moduleOpts = self:WrapModuleOptionsWithEnableHeader(name, moduleOpts)
			end
			options.args.modules.args[name] = moduleOpts
			options.args.modules.args[name].order = self:GetModuleOptionsOrder(name)
		end
	end
end

-- Addon options cache: structure is built once and reused until marked dirty.
function SarychUI:AddExtensionOptions()
	local target = options.args.extensions and options.args.extensions.args.registered.args
	if not target then return end
	for key in pairs(target) do target[key] = nil end
	local entries = {}
	for key, extension in pairs(self.extensions or {}) do
		if extension.GetOptions then
			local group = extension:GetOptions()
			if key == "aura_tracking" or key == "party_abilities" then
				-- Extensions use the two-pane renderer's title-row toggle.
				local general = group.args and group.args.general
				local enable = group.args.enabled or (general and general.args and general.args.enabled)
				if not enable and key == "party_abilities" then
					-- The cooldown options builder can replace its general group.
					enable = { type = "toggle",
						get = function() return self.db.profile.modules.party_abilities.masterEnabled ~= false end,
						set = function(_, value)
							self.db.profile.modules.party_abilities.masterEnabled = value and true or false
							extension:RefreshConfig()
						end }
				end
				if enable then
					if general and general.args then general.args.enabled = nil end
				local originalSet = enable.set
				enable.set = function(info, value)
					originalSet(info, value)
					-- Body opacity and its input blocker are built only when the
					-- detail pane is rendered, so value sync alone is insufficient.
					if self.OptionsCore then self.OptionsCore:ScheduleSmartRefresh(true) end
				end
				enable.name = SarychUI:T("ui.enable_a54eaf37")
				group.args.enabled = enable
				group.suiBodyDisabled = function() return not enable.get() end
				end
			end
			local label = group.name
			if type(label) == "function" then label = label() end
			entries[#entries + 1] = { key = key, group = group, label = label or key }
		end
	end
	table.sort(entries, function(a, b) return a.label < b.label end)
	for index, entry in ipairs(entries) do
		entry.group.order = index * 10
		target[entry.key] = entry.group
	end
end

function SarychUI:RefreshExtensionOptions()
	self:AddExtensionOptions()
	if self.OptionsCore and self.OptionsCore.InvalidateStructure then self.OptionsCore:InvalidateStructure() end
	self:NotifySarychUIOptionsChange()
end

SarychUI._addonOptionsBuilt = false
SarychUI._addonOptionsDirty = true
SarychUI._optionsTableRegistered = false

function SarychUI:MarkAddOnOptionsDirty(reason)
	self._addonOptionsDirty = true
	self._addonOptionsBuilt = false
	self._addonOptionsDirtyReason = reason
end

function SarychUI:NotifySarychUIOptionsChange()
	self._componentStateRevision = (self._componentStateRevision or 0) + 1
	if self.IsPlayerInCombat and self:IsPlayerInCombat() then
		self._pendingOptionsRefresh = true
		self:DebugCombatOptions("NotifySarychUIOptionsChange deferred")
		return
	end
	-- Never rebuild options while a slider/edit is busy - that kills drag capture
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
		if SuiTimer and SuiTimer.After then
			SuiTimer.After(0, function()
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

end

function SarychUI:RebuildModuleOptions(moduleName)

	local module = self.modules and self.modules[moduleName]
	if not module or not module.GetOptions then
		return false
	end
	local stage = "RebuildModuleOptions:" .. moduleName
	local moduleOpts
		moduleOpts = module:GetOptions()
	if self.WrapModuleOptionsWithEnableHeader then
		moduleOpts = self:WrapModuleOptionsWithEnableHeader(moduleName, moduleOpts)
	end
	moduleOpts.order = self:GetModuleOptionsOrder(moduleName)
	options.args.modules.args[moduleName] = moduleOpts
	if self.OptionsCore and self.OptionsCore.InvalidateStructure then
		self.OptionsCore:InvalidateStructure()
	end
	self:NotifySarychUIOptionsChange()
	return true
end

-- Add addon options to the options table (always rebuilds; use EnsureAddOnOptions to skip when cached)
function SarychUI:AddAddOnOptions()

	return self:_AddAddOnOptionsImpl()
end

local addonPurpose = {
    InspectEquip = "ui.addon_purpose.inspectequip",
    Clique = "ui.addon_purpose.clique",
    Auctionator = "ui.addon_purpose.auctionator",
    BASpammer = "ui.addon_purpose.baspammer",
    Postal = "ui.addon_purpose.postal",
    Purgeatory = "ui.addon_purpose.purgeatory",
    RaidRoll = "ui.addon_purpose.raidroll",
    SnowfallKeyPress = "ui.addon_purpose.snowfall",
    TrufiGCD = "ui.addon_purpose.trufigcd",
}

function SarychUI:_AddAddOnOptionsImpl()

	local addonCount = 0
	local rebuildReason = self._addonOptionsDirtyReason

	-- Clear previous addon option groups before rebuild
	if options.args.addons and options.args.addons.args and options.args.addons.args.ported then
		options.args.addons.args.ported.args = {}
	end

	-- Add ported addons to "Список" tab (sorted by visible name A->Я,
	-- except grouped addons which the two-pane list pins under a header).
	local addonEntries = {}

	local function GetAddOnDisplayName(optionGroup, key)
		if type(optionGroup) == "table" and type(optionGroup.name) == "string" and optionGroup.name ~= "" then
			return optionGroup.name
		end
		return key
	end

	if self.addons then
		for name, addon in pairs(self.addons) do
			addonCount = addonCount + 1
			local optionGroup

			if addon.GetOptions then
				local stage = "addon.GetOptions:" .. name
					optionGroup = addon:GetOptions()
			else
				local author = addon and addon.author or nil
				local version = addon and addon.version or nil
				local descriptionText = ""
				if author or version then
					if author then
						descriptionText = descriptionText .. SarychUI:T("ui.options_d8cfdbaf40") .. author
					end
					if version then
						if author then
							descriptionText = descriptionText .. "\n"
						end
						descriptionText = descriptionText .. SarychUI:T("ui.options_b4392165db") .. version
					end
				end

				optionGroup = {
					type = "group",
					name = (addon and addon.title) or name,
					args = {
						enabled = {
							type = "toggle",
							name = "ui.enable_a54eaf37",
							desc = SarychUI:T("ui.options_42d65049e5") .. ((addon and addon.title) or name),
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

            if addonPurpose[name] and optionGroup then
                optionGroup.suiPurpose = addonPurpose[name]
            end

			-- Some embedded addons only create their settings on first enable.
			-- Rebuild after the runtime setter, including wrappers which bypass
			-- EnableAddOn/DisableAddOn and manage their own lifecycle.
			local enable = optionGroup and optionGroup.args and optionGroup.args.enabled
			if enable and type(enable.set) == "function" and not enable._suiRefreshAfterToggle then
				local setEnabled = enable.set
				enable.set = function(info, value)
					local result = setEnabled(info, value)
					self:RefreshAddOnOptions("toggle:" .. name)
					return result
				end
				enable._suiRefreshAfterToggle = true
			end

			tinsert(addonEntries, {
				key = name,
				displayName = GetAddOnDisplayName(optionGroup, name),
				optionGroup = optionGroup,
			})

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

	-- Structure changed in place; NotifyChange refreshes open UI without full RegisterOptionsTable
	if self._optionsTableRegistered and not self._optionsTableBuilding then
			self:NotifySarychUIOptionsChange()

	end
end

-- Open options (custom OptionsCore only; same path as /sui).
function SarychUI:OpenOptionsPanel()
	if self.OpenOptions then
		self:OpenOptions()
		return
	end
	print(SarychUI:T("ui.options_5b52170266"))
end

-- Create SarychUI button in ESC menu (harmonious integration)
local function CreateSarychUIButton()
	if _G.GameMenuButtonSarychUI then return end
	local SarychUIButton = CreateFrame("Button", "GameMenuButtonSarychUI", GameMenuFrame, "GameMenuButtonTemplate")
	-- Set text with "Sarych" in white and "UI" in gold
	SarychUIButton:SetText(SarychUI:T("ui.options_fca7a3b209"))
	
	-- Hook to maintain text colors on state changes
	local fontString = SarychUIButton:GetFontString()
	if fontString then
		SarychUIButton:HookScript("OnEnter", function()
			SarychUIButton:SetText(SarychUI:T("ui.options_fca7a3b209"))
		end)
		SarychUIButton:HookScript("OnLeave", function()
			SarychUIButton:SetText(SarychUI:T("ui.options_fca7a3b209"))
		end)
		SarychUIButton:HookScript("OnEnable", function()
			SarychUIButton:SetText(SarychUI:T("ui.options_fca7a3b209"))
		end)
		SarychUIButton:HookScript("OnDisable", function()
			-- Dimmed colors when disabled
			SarychUIButton:SetText(SarychUI:T("ui.options_ad88005250"))
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
		return true
	end
	return false
end

-- Target values for «Быстрые настройки Blizzard» (label, cvar, desired).
local QUICK_SETTING_CVARS = {
	{ "timingMethod", "timingMethod", "2" },
	{ "dbCompress", "dbCompress", "0" },
	{ "ui.options_5466437179", "equipmentManager", "1" },
	{ "ui.options_e7691c3322", "nameplateShowEnemies", "1" },
	{ "ui.options_aceb0a24a3", "showTargetOfTarget", "1" },
	{ "ui.options_437c969a95", "scriptErrors", "1" },
	{ "ui.options_03dc50b062", "screenEdgeFlash", "0" },
	{ "ui.options_ae2c4d3893", "showLootSpam", "1" },
	{ "ui.options_29b8cf406a", "displayFreeBagSlots", "1" },
	{ "ui.options_e873992ae7", "profanityFilter", "0" },
	{ "ui.options_e523c10e4c", "guildShowOffline", "0" },
	{ "ui.options_8faf2c5ed6", "guildRecruitmentChannel", "0" },
	{ "ui.options_4ffb2735a8", "chatStyle", "classic" },
	{ "ui.options_b15d8007b1", "showNewbieTips", "0" },
	{ "ui.options_a84c8ac31f", "showGameTips", "0" },
	{ "ui.options_d1d17b2bc4", "showArenaEnemyFrames", "1" },
	{ "ui.options_537f03be70", "ShowAllSpellRanks", "0" },
	{ "ui.options_ff5279b1ed", "ShowClassColorInNameplate", "1" },
	{ "ui.options_f73a79ad11", "fullSizeFocusFrame", "1" },
	{ "ui.options_fc8fff203b", "showRaidRange", "1" },
	{ "ui.options_be0dfc507f", "maxFPS", "0" },
	{ "ui.options_c9b7fd7316", "playerStatusText", "1" },
	{ "ui.options_3759560c0d", "targetStatusText", "0" },
	{ "ui.options_d96efa4549", "petStatusText", "1" },
	{ "ui.options_957cb35039", "previewTalents", "1" },
	{ "ui.options_eea338ccfd", "wholeChatWindowClickable", "0" },
	{ "ui.options_b270ecfb9c", "showItemLevel", "1" },
	{ "ui.options_52ce916042", "autoLootDefault", "1" },
	{ "ui.options_5b49df008e", "hidePartyInRaid", "1" },
	{ "ui.options_87abd89467", "UberTooltips", "1" },
	{ "ui.options_d49394f817", "showTutorials", "0" },
	{ "ui.options_bd82571f6d", "conversationMode", "inline" },
	{ "ui.options_67af3f0899", "cameraPitchMoveSpeed", "55" },
	{ "ui.options_fd3c7adc0f", "timeMgrUseLocalTime", "1" },
	{ "ui.options_f965874864", "threatWarning", "0" },
	{ "ui.options_416909893e", "threatShowNumeric", "0" },
	{ "ui.options_6bf98b1482", "threatPlaySounds", "0" },
	{ "ui.options_38afab5e2f", "autoQuestWatch", "1" },
	{ "ui.options_bae988aeb7", "autoQuestProgress", "1" },
	{ "ui.options_c61d9d85eb", "mapQuestDifficulty", "1" },
	{ "ui.combat_text_3528d535", "enableCombatText", "1" },
	{ "ui.options_1032a4669c", "CombatDamage", "1" },
	{ "ui.options_5bd76a7cbe", "CombatLogPeriodicSpells", "1" },
	{ "ui.options_d346c578c1", "PetMeleeDamage", "1" },
	{ "ui.options_94cac84450", "CombatHealing", "1" },
	{ "ui.options_8e08756016", "fctHonorGains", "1" },
	{ "ui.options_23ab9970cd", "fctLowManaHealth", "0" },
	{ "ui.options_a8c641c9b5", "fctDodgeParryMiss", "0" },
	{ "ui.options_5a4746491c", "fctDamageReduction", "0" },
	{ "ui.options_a3c9cb4535", "fctRepChanges", "0" },
	{ "ui.options_810ec35abd", "fctReactives", "0" },
	{ "ui.options_c0ee5a20be", "fctAuras", "0" },
	{ "ui.options_cd9552622f", "fctComboPoints", "0" },
	{ "ui.options_10a8f737a1", "fctEnergyGains", "0" },
	{ "ui.options_6d5c18a830", "fctPeriodicEnergyGains", "0" },
	{ "ui.options_510e8d8941", "fctFriendlyHealers", "0" },
	{ "ui.options_95f90139e8", "fctCombatState", "0" },
	{ "ui.options_c755ea535d", "fctSpellMechanics", "0" },
	{ "ui.options_cf6df6cdc5", "fctSpellMechanicsOther", "0" },
	{ "ui.options_43574b1251", "UnitNamePlayerPVPTitle", "0" },
	{ "ui.options_c3a08f6226", "UnitNameEnemyGuardianName", "1" },
	{ "ui.options_ba7790174a", "UnitNameEnemyTotemName", "1" },
	{ "ui.options_fa2ac9119b", "UnitNameFriendlyGuardianName", "1" },
	{ "ui.options_078a0923d9", "UnitNameFriendlyTotemName", "1" },
	{ "ui.options_c5975222f7", "cameraPivot", "0" },
	{ "ui.options_ecf0b43eee", "cameraDistanceMaxFactor", "2" },
	{ "ui.options_eb003ed19c", "cameraDistanceMax", "50" },
	{ "ui.options_5beb5123c9", "cameraYawSmoothSpeed", "270" },
	{ "ui.options_5aca953ef2", "mouseSpeed", "1.1" },
	{ "ui.options_18a0f6c77c", "cameraYawMoveSpeed", "110" },
}

local QUICK_SETTING_DIRECT_SET = {
	timingMethod = true,
	dbCompress = true,
}

-- These settings are initialized by the client or Blizzard UI at load time.
local QUICK_SETTING_RELOAD = {
	showArenaEnemyFrames = true,
	enableCombatText = true,
}

-- Display / graphics from author Config.wtf (recommended 2K preset).
-- gxResolution / gxRefresh are filled at apply-time from display caps.
-- gx* / MSAA need a full client restart to take effect.
local QUICK_GRAPHICS_DESIRED_RES = "2560x1440"
local QUICK_GRAPHICS_DESIRED_REFRESH = 240
local QUICK_GRAPHICS_CVARS = {
	{ "ui.options_b70e318770", "gxResolution", QUICK_GRAPHICS_DESIRED_RES },
	{ "ui.options_cef6777d02", "gxRefresh", tostring(QUICK_GRAPHICS_DESIRED_REFRESH) },
	{ "VSync", "gxVSync", "0" },
	{ "ui.options_6ca4134b77", "gxWindow", "1" },
	{ "ui.options_f4a658dbae", "gxMaximize", "1" },
	{ "ui.options_7533c54277", "windowResizeLock", "1" },
	{ "ui.options_b660a1f443", "useUiScale", "1" },
	{ "ui.options_39b7171510", "uiScale", "0.74" },
	{ "ui.options_95e86949de", "textureFilteringMode", "5" },
	{ "ui.options_7b0ca375f6", "componentTextureLevel", "9" },
	{ "ui.options_b385d32872", "shadowLevel", "0" },
	{ "ui.options_2294dab1c9", "extShadowQuality", "5" },
	{ "ui.options_e29bbbd4ed", "farclip", "507" },
	{ "ui.options_0e3d6c29ac", "environmentDetail", "1.5" },
	{ "ui.options_bc793516c9", "specular", "1" },
	{ "ui.options_cc67b074f0", "projectedTextures", "1" },
	{ "ui.options_488be023f6", "weatherDensity", "0" },
	{ "ui.options_5e32cbca72", "ffxGlow", "0" },
	{ "ui.options_d0137705b1", "ffxDeath", "0" },
	{ "ui.options_50d5195bba", "gxMultisample", "8" },
	{ "gxFixLag", "gxFixLag", "0" },
	{ "ui.options_68784af8ce", "groundEffectDist", "70" },
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
		return SarychUI:T("ui.options_a60b4b83b2")
	end
	if s == "0" or s == "false" then
		return SarychUI:T("ui.options_622574d516")
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
		return (v == 1) and SarychUI:T("ui.options_a60b4b83b2") or SarychUI:T("ui.options_622574d516")
	end
	return SarychUI:T(
		"ui.options_c1a3f165f3",
		bar(cur1), bar(cur2), bar(cur3), bar(cur4),
		bar(want1), bar(want2), bar(want3), bar(want4)
	)
end

-- Tooltip lines for «Применить»: show only differences and pending reloads.
-- Colors match Details Cooltip Preset 2 (orange body text).
function SarychUI:GetQuickSettingsTooltipLines()
	local ORANGE = { 1, 0.65, 0 }
	local ORANGE_DIM = { 1, 0.55, 0.15 }
	local GREEN = { 0.55, 0.95, 0.45 }
	local lines = {}
	local diffs = {}
	local waiting = {}
	local pending = self._quickSettingsPendingReload or {}

	for _, entry in ipairs(QUICK_SETTING_CVARS) do
		local label, cvar, desired = entry[1], entry[2], entry[3]
		local ok, current = pcall(GetCVar, cvar)
		if pending[cvar] == desired then
			waiting[#waiting + 1] = QUICK_SETTING_DIRECT_SET[cvar] and cvar or self:T(label)
		elseif QUICK_SETTING_DIRECT_SET[cvar] then
			if not ok or current == nil or NormalizeQuickValue(current) ~= NormalizeQuickValue(desired) then
				diffs[#diffs + 1] = string.format(
					"%s: %s -> %s", cvar, ok and current ~= nil and tostring(current) or "?", desired
				)
			end
		elseif ok and current ~= nil and CVarDiffers(cvar, desired) then
			diffs[#diffs + 1] = string.format(
				"%s: %s -> %s",
				self:T(label),
				FormatQuickValue(current),
				FormatQuickValue(desired)
			)
		end
	end

	local bars = GetActionBarDiffLine()
	if bars then
		diffs[#diffs + 1] = bars
	end

	if #diffs == 0 and #waiting == 0 then
		lines[#lines + 1] = { self:T("ui.options_c010fba212"), ORANGE[1], ORANGE[2], ORANGE[3] }
		lines[#lines + 1] = { self:T("ui.options_ff77f5ad58"), GREEN[1], GREEN[2], GREEN[3] }
		return lines
	end

	if #diffs > 0 then
		lines[#lines + 1] = { self:T("ui.options_16dcc5cecc"), ORANGE[1], ORANGE[2], ORANGE[3] }
	end
	local maxShow = 14
	for i = 1, math.min(#diffs, maxShow) do
		lines[#lines + 1] = { diffs[i], ORANGE[1], ORANGE[2], ORANGE[3] }
	end
	if #diffs > maxShow then
		lines[#lines + 1] = {
			self:T("ui.options_2bbef6a29f", #diffs - maxShow),
			ORANGE_DIM[1], ORANGE_DIM[2], ORANGE_DIM[3]
		}
	end
	if #waiting > 0 then
		lines[#lines + 1] = { self:T("ui.options_4e8e254ff5"), ORANGE_DIM[1], ORANGE_DIM[2], ORANGE_DIM[3] }
		for _, label in ipairs(waiting) do
			lines[#lines + 1] = { label, ORANGE_DIM[1], ORANGE_DIM[2], ORANGE_DIM[3] }
		end
	end
	return lines
end

function SarychUI:QuickSettingsHasPendingReload()
	return next(self._quickSettingsPendingReload or {}) ~= nil
end

function SarychUI:GetQuickSettingsStatusText()
	local lines = {}
	local pending = self._quickSettingsPendingReload or {}
	for _, entry in ipairs(QUICK_SETTING_CVARS) do
		local label, cvar, desired = entry[1], entry[2], entry[3]
		local ok, current = pcall(GetCVar, cvar)
		local name = QUICK_SETTING_DIRECT_SET[cvar] and cvar or self:T(label)
		local actual = ok and current ~= nil and tostring(current) or "?"
		local target = desired
		if not QUICK_SETTING_DIRECT_SET[cvar] then
			actual = FormatQuickValue(ok and current or nil)
			target = FormatQuickValue(desired)
		end
		local status, color
		if pending[cvar] == desired then
			status, color = SarychUI:T("ui.options_4ec12ac1a0"), "ffffd200"
		elseif not ok or current == nil then
			status, color = SarychUI:T("ui.options_949ac1f255"), "ffff6666"
		elseif NormalizeQuickValue(current) ~= NormalizeQuickValue(desired) then
			status, color = SarychUI:T("ui.options_1411ab93fb"), "ffff6666"
		else
			status = nil
		end
		if status then
			lines[#lines + 1] = string.format("|c%s%s|r  %s: %s -> %s", color, status, name, actual, target)
		end
	end

	local petOk, petCurrent = pcall(GetCVar, "PetSpellDamage")
	if petOk and petCurrent ~= nil and NormalizeQuickValue(petCurrent) ~= "1" then
		lines[#lines + 1] = string.format(SarychUI:T("ui.options_13105eecba"), FormatQuickValue(petCurrent))
	end

	local bars = GetActionBarDiffLine()
	if bars then
		lines[#lines + 1] = SarychUI:T("ui.options_7a30889e28") .. bars
	end
	if #lines == 0 then
		return SarychUI:T("ui.options_f35b81bdbf")
	end
	return table.concat(lines, "\n")
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
				self:T(label),
				FormatQuickValue(current),
				FormatQuickValue(desired)
			)
		end
	end

	if #diffs == 0 then
		lines[#lines + 1] = { self:T("ui.options_60ec33456d"), ORANGE[1], ORANGE[2], ORANGE[3] }
		lines[#lines + 1] = { self:T("ui.options_a8d48a15bf"), GREEN[1], GREEN[2], GREEN[3] }
		return lines
	end

	lines[#lines + 1] = { self:T("ui.options_16dcc5cecc"), ORANGE[1], ORANGE[2], ORANGE[3] }
	local maxShow = 14
	for i = 1, math.min(#diffs, maxShow) do
		lines[#lines + 1] = { diffs[i], ORANGE[1], ORANGE[2], ORANGE[3] }
	end
	if #diffs > maxShow then
		lines[#lines + 1] = {
			self:T("ui.options_2bbef6a29f", #diffs - maxShow),
			ORANGE_DIM[1], ORANGE_DIM[2], ORANGE_DIM[3]
		}
	end
	lines[#lines + 1] = {
		self:T("ui.options_138070db39", resolved.gxResolution, resolved.gxRefresh),
		ORANGE_DIM[1], ORANGE_DIM[2], ORANGE_DIM[3]
	}
	lines[#lines + 1] = { self:T("ui.options_45920515fc"), ORANGE_DIM[1], ORANGE_DIM[2], ORANGE_DIM[3] }
	return lines
end

-- Apply quick settings (from sarsettings.default)
function SarychUI:ApplyQuickSettings()
	local pending = self._quickSettingsPendingReload or {}
	self._quickSettingsPendingReload = pending
	for _, entry in ipairs(QUICK_SETTING_CVARS) do
		local cvar, desired = entry[2], entry[3]
		local wasOk, previous = pcall(GetCVar, cvar)
		local changed = not wasOk or previous == nil or NormalizeQuickValue(previous) ~= NormalizeQuickValue(desired)
		local setOk
		if QUICK_SETTING_DIRECT_SET[entry[2]] then
			local ok, err = pcall(SetCVar, entry[2], entry[3])
			setOk = ok
			if not ok then
				geterrorhandler()(err)
			end
		else
			setOk = SafeSetCVar(entry[2], entry[3])
		end
		if QUICK_SETTING_RELOAD[cvar] and changed and setOk then
			pending[cvar] = desired
		end
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

	-- Apply our explicit layout without restoring Blizzard's default channels.
	self:ApplyQuickChatSettings()

	-- Notify user
	print(self:T("ui.options_88a23baa62"))
	local core = self._activeOptionsCore or self.OptionsCore
	if core and core.Refresh then core:Refresh() end

end

-- Display / graphics (recommended 2K; clamped to display max).
function SarychUI:ApplyQuickGraphicsSettings()
	local resolved = GetResolvedGraphicsTargets()
	for _, entry in ipairs(QUICK_GRAPHICS_CVARS) do
		local cvar = entry[2]
		SafeSetCVar(cvar, GetGraphicsCVarDesired(cvar, resolved))
	end
	print(self:T(
		"ui.options_b5e9487019",
		tostring(resolved.gxResolution),
		tostring(resolved.gxRefresh)
	))
	if SarychUI.ShowReloadPopup then
		local tpl = (self.T and self:T(
			"ui.options_32cb8f2f21"
		)) or SarychUI:T("ui.options_32cb8f2f21")
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
	-- ChatBar supplies the join request; only the client can resolve its name/ID.
	local generalTabName = LocaleChatString("GENERAL", SarychUI:T("ui.options_c45fe0a494"))
	local combatLogTabName = SarychUI:T("ui.options_67ade741ae")
	local lfgChannel = LocaleChatString("CHATBAR_LFG", LocaleChatString("LOOKING_FOR_GROUP", SarychUI:T("ui.options_c74925ddb2")))
	local chatModule = self:GetModule("chat")
	local function IsLFGChannel(name)
		return name == lfgChannel or (chatModule and chatModule.GetChannelStorageKey
			and chatModule:GetChannelStorageKey(name) == "LookingForGroup")
	end
	local function JoinedLFGName()
		local channels = GetChannelList and { GetChannelList() } or {}
		for i = 2, #channels, 2 do
			if IsLFGChannel(channels[i]) then return channels[i] end
		end
	end
	local joinedLFG = JoinedLFGName()
	if joinedLFG then
		lfgChannel = joinedLFG
	elseif EnumerateServerChannels then
		for _, name in ipairs({ EnumerateServerChannels() }) do
			if IsLFGChannel(name) then lfgChannel = name; break end
		end
	end

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
		},
		{
			index = 3,
			name = "General",
			size = 13,
			color = {15, 15, 15, 33},
			locked = true,
			shown = false,
			messages = {},
		},
		{
			index = 4,
			name = "/w",
			size = 13,
			color = {0, 0, 0, 12},
			locked = true,
			shown = false,
			messages = {"WHISPER", "CHANNEL"},
		},
		{
			index = 5,
			name = "Loot",
			size = 13,
			color = {0, 0, 0, 10},
			locked = true,
			shown = false,
			messages = {"SYSTEM", "PARTY_LEADER", "RAID_LEADER", "RAID_WARNING", "LOOT", "MONEY", "COMBAT_MISC_INFO"},
		}
	}

	local function ClearChatFrameMessageGroups(chatFrame)
		if ChatFrame_RemoveAllMessageGroups then
			ChatFrame_RemoveAllMessageGroups(chatFrame)
		elseif ChatFrame_RemoveMessageGroup and type(chatFrame.messageTypeList) == "table" then
			local copy = {}
			for i = 1, #chatFrame.messageTypeList do
				copy[i] = chatFrame.messageTypeList[i]
			end
			for _, messageGroup in ipairs(copy) do
				ChatFrame_RemoveMessageGroup(chatFrame, messageGroup)
			end
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
		-- A docked, inactive tab is still an open saved window. Hide() only
		-- controls its current visibility; saved shown=false means closed.
		if SetChatWindowShown then
			SetChatWindowShown(chatFrame:GetID(), 1)
		end

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

		-- Reset every category (including Loot/Money), then add this tab's groups.
		ClearChatFrameMessageGroups(chatFrame)
		for _, messageGroup in ipairs(settings.messages) do
			if ChatFrame_AddMessageGroup then
				ChatFrame_AddMessageGroup(chatFrame, messageGroup)
			end
		end


		return chatFrame
	end

	for i = 3, MAX_CHAT_FRAMES do
		local chatFrame = _G["ChatFrame" .. i]
		if chatFrame and not chatFrame.isDocked and FCF_DockFrame then
			FCF_DockFrame(chatFrame)
		end
		if not chatFrame then
			CreateChatWindowIfNeeded(i, SarychUI:T("ui.options_16eb80a596") .. i)
		end
	end

	local configuredFrames = {}
	local general
	for _, settings in ipairs(chatWindowsSettings) do
		local frame = ConfigureChatWindow(settings.index, settings)
		if frame then
			configuredFrames[#configuredFrames + 1] = frame
			if settings.index == 3 then general = frame end
		end
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
	local function ClearWindowChannels(frame)
		-- RemoveAllChannels reads the Lua cache; refresh native saved state first.
		if ChatFrame_RegisterForChannels and GetChatWindowChannels then
			ChatFrame_RegisterForChannels(frame, GetChatWindowChannels(frame:GetID()))
		end
		if ChatFrame_RemoveAllChannels then ChatFrame_RemoveAllChannels(frame) end
	end
	-- Clear the target BEFORE joining, so we cannot erase a pending native join.
	for _, frame in ipairs(configuredFrames) do ClearWindowChannels(frame) end
	if general and ChatFrame_AddChannel then
		local ok = joinedLFG ~= nil
		local returnedName
		if not ok and JoinPermanentChannel then
			local result, zoneOrError, name = pcall(JoinPermanentChannel, lfgChannel, nil, general:GetID(), 1)
			ok, returnedName = result, name
			if not result and geterrorhandler then geterrorhandler()(zoneOrError) end
		end
		if ok then
			-- Blizzard's JOIN_CHANNEL popup calls AddChannel independently of
			-- join return values. The native API decides whether it can subscribe.
			local name = JoinedLFGName()
			if not name then
				name = type(returnedName) == "string" and returnedName ~= "" and returnedName or lfgChannel
			end
			ChatFrame_AddChannel(general, name)
		end
	end
	-- Some clients also attach the main tab during join. Only clear OTHER
	-- preset windows afterward; the new General subscription must survive.
	for _, frame in ipairs(configuredFrames) do
		if frame ~= general then ClearWindowChannels(frame) end
	end
	if general and ChatFrame_RegisterForChannels and GetChatWindowChannels then
		ChatFrame_RegisterForChannels(general, GetChatWindowChannels(general:GetID()))
	end
	if FCFDock_SelectWindow and GENERAL_CHAT_DOCK and _G.ChatFrame1 then
		FCFDock_SelectWindow(GENERAL_CHAT_DOCK, _G.ChatFrame1)
	end
	self:RestoreQuickChatTabNames()
	if LootHistory_UpdateLootTabButton then
		LootHistory_UpdateLootTabButton()
	end
end

-- Migrate legacy tab titles without changing the user's channel selections.
local quickChatWatch = CreateFrame("Frame")
function SarychUI:RestoreQuickChatTabNames()
    if not GetChatWindowInfo then return end
    local names = {
        ["ui.options_9239ee2cda"] = "General",
        ["ui.options_71a0bcb014"] = "/w",
        ["ui.options_e8fef4b91c"] = "Loot",
    }
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local frame = _G["ChatFrame" .. i]
        local name = GetChatWindowInfo(i)
        if i == 3 and name == self:T("ui.options_9239ee2cda") then
            name = "ui.options_9239ee2cda"
        end
        if frame and names[name] and FCF_SetWindowName then
            FCF_SetWindowName(frame, names[name])
        end
    end
end
quickChatWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
quickChatWatch:SetScript("OnEvent", function()
    SarychUI:RestoreQuickChatTabNames()
end)

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
