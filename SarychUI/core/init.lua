-- SarychUI Core Initialization
-- Main initialization file for SarychUI AddOn

local pairs = pairs
local gsub = string.gsub

local ADDON_NAME = "SarychUI"
local VERSION = "1.0.0"

-- Check for required libraries (LibStub is embedded in SarychUI/libs/)
local LibStub = _G.LibStub
if not LibStub then
	error("SarychUI: LibStub not loaded! Check that libs/load-libs.xml is loading correctly.")
	return
end

-- Create main AddOn object (no AceAddon dependency)
SarychUI = {
	name = ADDON_NAME,
	version = VERSION,
	modules = {},
	moduleList = {},
}

-- Shared help-icon for options that activate while Alt is held.
SarychUI.DOTA_ALT_HELP_ICON = {
	path = "Interface\\AddOns\\SarychUI\\media\\dota_logo_white",
	color = { 1.0, 0.12, 0.12 },
}

-- Chat colors (matches BlizzMove: |cffffd200SarychUI:|r …)
SarychUI.CHAT_GOLD = "|cffffd200"
SarychUI.CHAT_PREFIX = SarychUI.CHAT_GOLD .. "SarychUI:|r"

function SarychUI:GetScopedChatPrefix(scope)
	if scope and scope ~= "" then
		return self.CHAT_GOLD .. "SarychUI " .. scope .. ":|r"
	end
	return self.CHAT_PREFIX
end

function SarychUI:Print(...)
	print(self.CHAT_PREFIX, ...)
end

function SarychUI:Printf(fmt, ...)
	print(self.CHAT_PREFIX .. " " .. string.format(fmt, ...))
end

-- Add basic event handling
SarychUI.eventFrame = CreateFrame("Frame")
SarychUI.events = {}

function SarychUI:RegisterEvent(event, callback)
	self.events[event] = callback or event
	self.eventFrame:RegisterEvent(event)
end

function SarychUI:UnregisterEvent(event)
	self.eventFrame:UnregisterEvent(event)
	self.events[event] = nil
end

SarychUI.eventFrame:SetScript("OnEvent", function(frame, event, ...)
	local handler = SarychUI.events[event]
	if handler then
		if type(handler) == "string" and SarychUI[handler] then
			SarychUI[handler](SarychUI, event, ...)
		elseif type(handler) == "function" then
			handler(SarychUI, event, ...)
		end
	end
end)

-- Add chat command handling
function SarychUI:RegisterChatCommand(command, callback)
	SlashCmdList[command:upper()] = function(msg)
		if type(callback) == "string" and SarychUI[callback] then
			SarychUI[callback](SarychUI, msg)
		elseif type(callback) == "function" then
			callback(SarychUI, msg)
		end
	end
	_G["SLASH_"..command:upper().."1"] = "/"..command
end

-- Local references (do not replace the Locale.lua L proxy with a plain table)
if not SarychUI._lProxyInstalled then
	local L = {}
	SarychUI.L = L
end

-- Version info
SarychUI.version = VERSION
SarychUI.name = ADDON_NAME

-- Module registry
SarychUI.modules = {}
SarychUI.moduleList = {}

SarychUI._pendingOptionsRefresh = false

function SarychUI:IsPlayerInCombat()
	return UnitAffectingCombat and UnitAffectingCombat("player") and true or false
end

function SarychUI:IsSarychUIConfigOpen()
	local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
	if not ACD or not ACD.OpenFrames then
		return false
	end
	local open = ACD.OpenFrames[ADDON_NAME]
	if not open then
		return false
	end
	if open.IsShown then
		return open:IsShown()
	end
	if open.frame and open.frame.IsShown then
		return open.frame:IsShown()
	end
	return true
end

function SarychUI:PrintOptionsUnavailableInCombat()
	self:Print("Параметры недоступны в бою.")
end

function SarychUI:DebugCombatOptions(context, detail)
	if not _G.SarychUI_DebugCombatOptions then
		return
	end
	local stack = debugstack and debugstack(2, 8, 0) or "?"
	print(string.format(
		"|cffffd200SarychUI CombatOptions:|r %s | configOpen=%s | pending=%s",
		tostring(context),
		tostring(self:IsSarychUIConfigOpen()),
		tostring(self._pendingOptionsRefresh)
	))
	if detail then
		print("|cffffd200SarychUI CombatOptions:|r " .. tostring(detail))
	end
	print(stack)
end

function SarychUI:ProcessPendingOptionsRefresh()
	if self._pendingProfileRefresh then
		self._pendingProfileRefresh = nil
		self._pendingOptionsRefresh = nil
		if self.OnProfileChanged then
			self:OnProfileChanged()
		elseif self.ApplyCurrentProfile then
			self:ApplyCurrentProfile({
				source = "ProcessPendingOptionsRefresh",
				refreshPlates = true,
				reason = "deferred profile switch",
				fullProfileApply = true,
				applyAddons = true,
			})
		end
		return
	end
	if not self._pendingOptionsRefresh then
		return
	end
	self._pendingOptionsRefresh = nil
	if not self:IsSarychUIConfigOpen() then
		self:DebugCombatOptions("ProcessPendingOptionsRefresh skipped", "config closed")
		return
	end
	self:DebugCombatOptions("ProcessPendingOptionsRefresh", "applying")
	if self.EnsureAddOnOptions then
		self:EnsureAddOnOptions()
	end
	local reg = LibStub and LibStub("AceConfigRegistry-3.0", true)
	if reg then
		reg:NotifyChange(ADDON_NAME)
	end
end

local function profileStartup(stage, fn, ...)
	if SarychUI_ProfileStartupStage then
		return SarychUI_ProfileStartupStage(stage, fn, ...)
	end
	return fn(...)
end

-- Initialize function
function SarychUI:OnInitialize()
	if self.BeginStartupPerf then
		self:BeginStartupPerf("OnInitialize")
	end

	-- Load saved variables
	local AceDB = LibStub("AceDB-3.0", true)
	if AceDB then
		-- nil defaultProfile = per-character ("Name - Realm"). Do NOT pass true:
		-- AceDB treats true as a shared "Default" profile for every character.
		-- While always-use is on, new characters join the shared profile directly.
		self.db = profileStartup("OnInitialize.AceDB", function()
			local defaultProfile
			if SarychUI.GetAlwaysUseProfileEnabled and SarychUI:GetAlwaysUseProfileEnabled() then
				defaultProfile = SarychUI.GetAlwaysUseProfileName and SarychUI:GetAlwaysUseProfileName()
				if type(defaultProfile) ~= "string" or defaultProfile == "" then
					defaultProfile = nil
				end
			end
			return AceDB:New("SarychUIDB", SarychUI:GetDefaults(), defaultProfile)
		end)
		
		if self.RegisterProfileCallbacks then
			self:RegisterProfileCallbacks()
		end

		if self.EnsureBuiltinProfiles then
			profileStartup("OnInitialize.EnsureBuiltinProfiles", self.EnsureBuiltinProfiles, self)
		end

		-- Shared profile only while "use on all characters" is on (any character can toggle it).
		if self.ApplyAlwaysUseProfileOnLogin then
			profileStartup("OnInitialize.ApplyAlwaysUseProfileOnLogin", self.ApplyAlwaysUseProfileOnLogin, self)
		elseif type(SarychUIDB) == "table" and type(SarychUIDB.profileKeys) == "table" then
			SarychUIDB.profileKeys["*"] = nil
		end

		if self.SyncLegacyProfileStorage then
			self:SyncLegacyProfileStorage()
		end
	else
		-- Fallback to simple table if AceDB not available
		if not SarychUIDB then
			SarychUIDB = self:GetDefaults()
		end
		self.db = {
			profile = SarychUIDB.profile or SarychUIDB
		}
		self:Print("|cffff0000AceDB-3.0 не найден!|r Используется упрощённая база данных.")
	end
	
	-- Ensure profile exists
	if not self.db.profile then
		self.db.profile = self:GetDefaults().profile
	end
	
	
	-- Register chat commands
	self:RegisterChatCommand("sarychui", "ChatCommand")
	self:RegisterChatCommand("sui", "ChatCommand")
	
	if self.ResolveFeatureConflicts then
		profileStartup("OnInitialize.ResolveFeatureConflicts", self.ResolveFeatureConflicts, self)
	end

	-- Initialize modules
	profileStartup("OnInitialize.InitializeModules", self.InitializeModules, self)

	if self.Compatibility then
		profileStartup("OnInitialize.Compatibility", self.Compatibility.Refresh, self.Compatibility, true)
	end
	
	-- Initialize addons
	if self.InitializeAddOns then
		profileStartup("OnInitialize.InitializeAddOns", self.InitializeAddOns, self)
	end
end

-- Enable function
function SarychUI:OnEnable()
	-- Initialize Alt Mode utility
	if self.AltMode then
		profileStartup("OnEnable.AltMode", self.AltMode.Initialize, self.AltMode)
	end

	-- Builtin templates must not stay active after login (name is available now).
	if self.EnsureWritableProfile then
		profileStartup("OnEnable.EnsureWritableProfile", self.EnsureWritableProfile, self, true)
	end
	
	if self.ApplyFeatureCoordination then
		profileStartup("OnEnable.ApplyFeatureCoordination", self.ApplyFeatureCoordination, self, { startup = true })
	end

	-- Enable all registered modules
	for name, module in pairs(self.modules) do
		if module.Enable and self.db.profile.modules[name].enabled then
			profileStartup("OnEnable.module:" .. name, module.Enable, module)
		end
	end

	-- SpeedyLoad is a system setting (Система), independent of the tools module toggle.
	local tools = self.modules and self.modules.tools
	if tools and tools.ApplySpeedyLoad then
		profileStartup("OnEnable.SpeedyLoad", tools.ApplySpeedyLoad, tools)
	end

	if self.Runtime and self.Runtime.Refresh then
		profileStartup("OnEnable.Runtime", self.Runtime.Refresh, self.Runtime)
	end
	
	-- Enable all registered addons that are enabled in settings
	if self.EnableAddOns then
		profileStartup("OnEnable.EnableAddOns", self.EnableAddOns, self)
	end

	-- InitializeOptions (PLAYER_LOGIN) finishes startup profiling when AceConfig is available.
	local AceConfig = LibStub and LibStub("AceConfig-3.0", true)
	if not AceConfig and self.EndStartupPerf then
		self:EndStartupPerf("OnEnable (no AceConfig)")
	end
end

-- Disable function
function SarychUI:OnDisable()
	-- Disable all modules
	for name, module in pairs(self.modules) do
		if module.Disable then
			module:Disable()
		end
	end
	if self.Runtime and self.Runtime.Shutdown then
		self.Runtime:Shutdown()
	end
end

-- Initialize all modules
function SarychUI:InitializeModules()
	for name, module in pairs(self.modules) do
		if module.Initialize then
			module:Initialize()
		end
	end
end

-- Refresh configuration after ordinary settings changes.
function SarychUI:RefreshConfig()
	if self.ApplyCurrentProfile then
		self:ApplyCurrentProfile({
			source = "RefreshConfig",
			refreshPlates = false,
			reason = "settings refresh",
			fullProfileApply = false,
		})
	end
end

-- Chat command handler
function SarychUI:ChatCommand(input)
	input = input or ""
	if type(input) == "string" then
		input = gsub(input, "^%s*(.-)%s*$", "%1") -- trim
	end
	
	if input == "" or input == "config" or input == "options" then
		-- Open options panel (custom Details-like core)
		self:OpenOptions()
	elseif input == "refreshoptions" or input:match("^refreshoptions") then
		if self.RefreshAddOnOptions then
			self:RefreshAddOnOptions("manual command")
			print("|cffffd200SarychUI:|r Addon options пересобраны.")
		else
			print("|cffffd200SarychUI:|r Refresh options недоступен.")
		end
	elseif input == "reset" then
		-- Reset to defaults
		if self.db and self.db.ResetProfile then
			self.db:ResetProfile()
			if self.MarkAddOnOptionsDirty then
				self:MarkAddOnOptionsDirty("profile reset")
			end
			print("|cffffd200SarychUI:|r Профиль сброшен на настройки по умолчанию.")
		else
			print("|cffffd200SarychUI:|r Сброс недоступен без AceDB.")
		end
	elseif input == "perfsummary" or input:match("^perfsummary") then
		if SarychUI.PrintPerfSummary then
			SarychUI:PrintPerfSummary()
		end
		if SarychUI.PrintOptionsPerfSummary then
			SarychUI:PrintOptionsPerfSummary()
		end
	elseif input == "perfoptions" or input:match("^perfoptions") then
		if input:match("%f[%w]off%f[%w]") or input:match("%f[%w]summary%f[%w]") then
			if SarychUI.FinalizeOptionsOpenPerfIfNeeded then
				SarychUI:FinalizeOptionsOpenPerfIfNeeded("perfoptions summary")
			end
			if SarychUI.PrintOptionsPerfSummary then
				SarychUI:PrintOptionsPerfSummary()
			end
			if input:match("%f[%w]off%f[%w]") and SarychUI.ToggleOptionsPerfDebug then
				SarychUI:ToggleOptionsPerfDebug(false)
			end
		elseif input:match("%f[%w]on%f[%w]") then
			if SarychUI.ToggleOptionsPerfDebug then
				SarychUI:ToggleOptionsPerfDebug(true)
			end
		elseif SarychUI.RunOptionsPerfOpen then
			SarychUI:RunOptionsPerfOpen()
		else
			print("|cffffd200SarychUI:|r options perf module not loaded.")
		end
	elseif input == "perf" or input:match("^perf%s") then
		if input:match("%f[%w]off%f[%w]") then
			if SarychUI.TogglePerfDebug then
				SarychUI:TogglePerfDebug(false)
			end
			if SarychUI.ToggleOptionsPerfDebug then
				SarychUI:ToggleOptionsPerfDebug(false)
			end
		elseif input:match("%f[%w]open%f[%w]") then
			if SarychUI.RunOptionsPerfOpen then
				SarychUI:RunOptionsPerfOpen()
			end
		elseif input:match("%f[%w]on%f[%w]") then
			if SarychUI.TogglePerfDebug then
				SarychUI:TogglePerfDebug(true)
			end
			if SarychUI.ToggleOptionsPerfDebug then
				SarychUI:ToggleOptionsPerfDebug(true)
			end
			print("|cffffd200SarychUI Perf:|r startup + options perf ON. Откройте |cff00ff00/sui|r или |cff00ff00/sui perf open|r")
		elseif input:match("%f[%w]summary%f[%w]") then
			if SarychUI.PrintPerfSummary then
				SarychUI:PrintPerfSummary()
			end
			if SarychUI.PrintOptionsPerfSummary then
				SarychUI:PrintOptionsPerfSummary()
			end
		elseif SarychUI.RunPerfReport then
			SarychUI:RunPerfReport()
		else
			print("|cffffd200SarychUI:|r perf module not loaded.")
		end
	elseif input == "minimapbuttonsdebug" or input:match("^minimapbuttonsdebug") then
		local mm = self:GetModule("minimap")
		if mm and mm.DebugMinimapButtonsScan then
			local verbose = input:match("verbose") ~= nil
			mm:DebugMinimapButtonsScan(verbose)
		else
			print("|cffffd200SarychUI:|r Модуль миникарты не загружен.")
		end
	elseif input == "conflicts" or input == "конфликты" then
		if self.PrintConflictsReport then
			self:PrintConflictsReport()
		else
			print("|cffffd200SarychUI:|r coordinator module not loaded.")
		end
	elseif input == "status" or input == "статус" then
		if self.PrintConflictsReport then
			self:PrintConflictsReport()
		end
		print("|cffffd200SarychUI|r v"..VERSION.." - Статус модулей:")
		for name, module in pairs(self.modules) do
			local modDb = self.db.profile.modules[name]
			local enabled = modDb and modDb.enabled
			local status = enabled and "|cff00ff00включён|r" or "|cffff0000отключён|r"
			print("  "..name..": "..status)
		end
		if self.Compatibility then
			print("  wow_optimize: "..self.Compatibility:GetStatusText())
		end
	else
		-- Show help
		print("|cffffd200SarychUI|r v"..VERSION.." - Доступные команды:")
		print("  |cff00ff00/sarychui|r - Открыть настройки (требуется Ace3)")
		print("  |cff00ff00/sarychui status|r - Статус модулей и координации")
		print("  |cff00ff00/sui conflicts|r - Отчёт координации функций")
		print("  |cff00ff00/sarychui reset|r - Сбросить профиль")
		print("  |cff00ff00/sui perf|r - Startup-отчёт (не замеряет open настроек!)")
		print("  |cff00ff00/sui perfoptions|r - Замер открытия настроек (вкл. perf + открыть окно)")
		print("  |cff00ff00/sui perf open|r - То же: замер + открыть /sui")
		print("  |cff00ff00/sui perfsummary|r - Startup + options summary")
		print("  |cff00ff00/sui refreshoptions|r - Пересобрать addon options вручную")
		print("  |cff00ff00/sarychui help|r - Эта справка")
	end
end


-- Open options panel
function SarychUI:OpenOptions()
	if self:IsPlayerInCombat() then
		self:PrintOptionsUnavailableInCombat()
		return
	end

	if self.IsSarychUIOptionsOpen and self:IsSarychUIOptionsOpen() then
		if self.CloseSarychUIConfig then
			self:CloseSarychUIConfig()
		end
		return
	end

	local perfOn = self.IsOptionsPerfEnabled and self:IsOptionsPerfEnabled()
	if perfOn and self.BeginOptionsOpenPerf then
		self:BeginOptionsOpenPerf("OpenOptions")
	end

	local function profile(stage, fn)
		if SarychUI_ProfileOptionsStage then
			return SarychUI_ProfileOptionsStage(stage, fn)
		end
		return fn()
	end

	if self.EnsureAddOnOptions then
		profile("EnsureAddOnOptions", function()
			self:EnsureAddOnOptions()
		end)
	end

	profile("CloseOtherConfigWindows", function()
		self:CloseNamePlatesConfig()
		self:CloseGladiusExConfig()
		if self.CloseMapsterConfig then
			self:CloseMapsterConfig()
		end
		if self.CloseCarboniteConfig then
			self:CloseCarboniteConfig()
		end
	end)

	if self.OptionsCore and self.OptionsCore.Open then
		self.OptionsCore:Open()
		if perfOn and self.ScheduleOptionsOpenPerfEnd then
			self:ScheduleOptionsOpenPerfEnd(0.15, "post-open (+150ms)")
		end
		return
	end

	print("|cffffd200SarychUI:|r OptionsCore не загружен. Проверьте файлы options/.")
end

-- Get defaults (defined in defaults.lua)
function SarychUI:GetDefaults()
	return SarychUI.defaults or {}
end

-- Initialize addon on ADDON_LOADED event
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_REGEN_DISABLED") -- Вход в бой
initFrame:RegisterEvent("PLAYER_REGEN_ENABLED") -- Выход из боя

local loaded = false
local loggedIn = false

initFrame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
		loaded = true
		if not SarychUI.initialized then
			SarychUI:OnInitialize()
			SarychUI.initialized = true
		end
		if loggedIn and not SarychUI.enabled then
			SarychUI:OnEnable()
			SarychUI.enabled = true
		end
	elseif event == "PLAYER_LOGIN" then
		loggedIn = true
		if loaded and not SarychUI.enabled then
			SarychUI:OnEnable()
			SarychUI.enabled = true
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		-- Вход в бой - закрываем окно настроек, drag mode и сетку
		-- Вызываем синхронно, как в WeakAuras, чтобы закрыть сразу
		
		-- 1. Проверяем режим редактирования фреймов (Фреймы > Позиция)
		local frameModule = SarychUI and SarychUI.modules and SarychUI.modules.frame
		if frameModule then
			local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.frame
			if db then
				-- Проверяем и закрываем режим редактирования
				if db.showPositionDragFrame == 1 then
					db.showPositionDragFrame = 0
				end
				
				-- Проверяем и закрываем сетку выравнивания
				if db.showPositionGrid == 1 then
					db.showPositionGrid = 0
				end
				
				-- Закрываем режимы редактирования
				if frameModule.ApplyPositionDragMode then
					frameModule:ApplyPositionDragMode()
				end
			end
		end

		-- 1b. Режим редактирования аур персонажа (Ауры)
		local aurasModule = SarychUI and SarychUI.modules and SarychUI.modules.auras
		if aurasModule then
			local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.auras
			if db then
				if db.showBuffDragFrame == 1 then
					db.showBuffDragFrame = 0
				end
				if db.showBuffGrid == 1 then
					db.showBuffGrid = 0
				end
				if aurasModule.ApplyBuffManagement then
					aurasModule:ApplyBuffManagement()
				end
			end
		end
		
		-- 2. Проверяем режим редактирования арены (Арена > настройки > изменить расположение)
		local arenaModule = SarychUI and SarychUI.modules and SarychUI.modules.arena
		if arenaModule then
			local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.arena
			if db then
				-- Проверяем и закрываем режим редактирования арены
				if db.showDragFrame == 1 then
					db.showDragFrame = 0
				end
				
				-- Проверяем и закрываем сетку выравнивания арены
				if db.showGrid == 1 then
					db.showGrid = 0
				end
				
				-- Закрываем режимы редактирования
				if arenaModule.ApplySettings then
					arenaModule:ApplySettings()
				end
			end
		end
		
		-- 3. Проверяем режим редактирования миникарты (Миникарта > Позиция)
		local minimapModule = SarychUI and SarychUI.modules and SarychUI.modules.minimap
		if minimapModule then
			local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.minimap
			if db then
				-- Проверяем и закрываем режим редактирования миникарты
				if db.showDragFrame == 1 then
					db.showDragFrame = 0
				end
				
				-- Проверяем и закрываем сетку выравнивания миникарты
				if db.showGrid == 1 then
					db.showGrid = 0
				end
				
				-- Закрываем режимы редактирования
				if minimapModule.ApplySettings then
					minimapModule:ApplySettings()
				end
			end
		end
		
		-- 4. Текст боя: не гасим свободное перемещение при входе в бой через этот путь
		-- вместе с закрытием окна — сессия живёт до Применить/Сброс/выключения кнопки.
		-- (Боевой cleanup ниже всё ещё может закрыть окно настроек.)
		
		-- Не трогаем активный combat-text drag / сетку при закрытии настроек из боя.
		
		-- Закрываем окно настроек (без NotifyChange / AceConfigDialog:Open в бою)
		if SarychUI.CloseSarychUIConfig then
			SarychUI:CloseSarychUIConfig()
		elseif SarychUI.CloseOptions then
			SarychUI:CloseOptions()
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if SarychUI.ProcessPendingOptionsRefresh then
			SarychUI:ProcessPendingOptionsRefresh()
		end
	end
end)

-- ElvUI-style loading spinner (bag sort, Postal Open All, etc.)
do
	local SPINNER_TEX_FRAME = "Interface\\AddOns\\SarychUI\\addons\\SarychUI_Bags\\Media\\Textures\\StreamFrame.blp"
	local SPINNER_TEX_CIRCLE = "Interface\\AddOns\\SarychUI\\addons\\SarychUI_Bags\\Media\\Textures\\StreamCircle.blp"
	local SPINNER_TEX_SPARK = "Interface\\AddOns\\SarychUI\\addons\\SarychUI_Bags\\Media\\Textures\\StreamSpark.blp"
	local SPINNER_ICON_MAX = 32
	local spinners = setmetatable({}, { __mode = "k" })

	local function GetSpinnerIconSize(parent)
		if not parent or not parent.GetWidth then
			return 24
		end
		local w, h = parent:GetWidth(), parent:GetHeight()
		if w and h and w > 0 and h > 0 then
			return math.min(SPINNER_ICON_MAX, math.floor(math.min(w, h) * 0.85))
		end
		return 24
	end

	local function SetSpinnerIconSize(frame, size)
		frame.Framing:SetSize(size, size)
		frame.Circle:SetSize(size, size)
		frame.Spark:SetSize(size, size)
	end

	local function StopSpinnerAnim(frame)
		if not frame then
			return
		end
		if frame.Circle and frame.Circle.Anim then
			frame.Circle.Anim:Stop()
		end
		if frame.Spark and frame.Spark.Anim then
			frame.Spark.Anim:Stop()
		end
	end

	local function HideSpinnerFrame(frame)
		if not frame then
			return
		end
		frame:Hide()
		StopSpinnerAnim(frame)
	end

	local function EnsureSpinner(parent)
		if spinners[parent] then
			return spinners[parent]
		end
		if not parent then
			return nil
		end

		local frame = CreateFrame("Frame", nil, parent)
		frame:EnableMouse(true)
		frame:Hide()

		frame.Background = frame:CreateTexture(nil, "BACKGROUND")
		frame.Background:SetTexture(0, 0, 0, 0.5)
		frame.Background:SetAllPoints()

		frame.Framing = frame:CreateTexture(nil, "ARTWORK")
		frame.Framing:SetTexture(SPINNER_TEX_FRAME)
		frame.Framing:SetPoint("CENTER")

		frame.Circle = frame:CreateTexture(nil, "ARTWORK")
		frame.Circle:SetTexture(SPINNER_TEX_CIRCLE)
		frame.Circle:SetVertexColor(1, 0.82, 0)
		frame.Circle:SetPoint("CENTER")

		frame.Circle.Anim = frame.Circle:CreateAnimationGroup()
		frame.Circle.Anim:SetLooping("REPEAT")
		frame.Circle.Anim.Rotation = frame.Circle.Anim:CreateAnimation("Rotation")
		frame.Circle.Anim.Rotation:SetDuration(1)
		frame.Circle.Anim.Rotation:SetDegrees(-360)

		frame.Spark = frame:CreateTexture(nil, "OVERLAY")
		frame.Spark:SetTexture(SPINNER_TEX_SPARK)
		frame.Spark:SetPoint("CENTER")

		frame.Spark.Anim = frame.Spark:CreateAnimationGroup()
		frame.Spark.Anim:SetLooping("REPEAT")
		frame.Spark.Anim.Rotation = frame.Spark.Anim:CreateAnimation("Rotation")
		frame.Spark.Anim.Rotation:SetDuration(1)
		frame.Spark.Anim.Rotation:SetDegrees(-360)

		spinners[parent] = frame
		SetSpinnerIconSize(frame, GetSpinnerIconSize(parent))
		return frame
	end

	function SarychUI:ShowSpinnerOn(parent)
		if not parent then
			return
		end

		local frame = EnsureSpinner(parent)
		if not frame then
			return
		end

		SetSpinnerIconSize(frame, GetSpinnerIconSize(parent))
		frame:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 0) + 60)
		frame:ClearAllPoints()
		frame:SetAllPoints(parent)
		frame:Show()
		frame.Circle.Anim.Rotation:Play()
		frame.Spark.Anim.Rotation:Play()
	end

	function SarychUI:HideSpinner(parent)
		if parent then
			HideSpinnerFrame(spinners[parent])
			return
		end

		for _, frame in pairs(spinners) do
			HideSpinnerFrame(frame)
		end
	end
end

