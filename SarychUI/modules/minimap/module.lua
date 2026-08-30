-- SarychUI Minimap Module
-- Full sarMinimap integration

local max, rad, cos, sin = math.max, math.rad, math.cos, math.sin

local moduleName = "minimap"
local module = {}

-- Register module
SarychUI:RegisterModule(moduleName, module)

-- Embed Ace libs into this module (safer hooks/timers scoping)
LibStub("AceTimer-3.0"):Embed(module)
LibStub("AceHook-3.0"):Embed(module)

-- Local references
local L = SarychUI.L
local db

-- Module state
local offsetX, offsetY
local areButtonsVisible = false
local isAnimatingShow = false
local mouseWatchTicker -- AceTimer handle (ticker)
local pendingHideTimer -- AceTimer handle (one-shot)
local iconTicker -- AceTimer handle для периодического позиционирования иконок

local DEBUG_MINIMAP_BUTTONS = false
local DEBUG_MINIMAP_BUTTONS_PERF = false
local DEBUG_MINIMAP_BUTTONS_LAYOUT = false
local DEBUG_MINIMAP_WORLD_BUTTON = false

local managedButtonsList = {}
local managedButtonsListDirty = true
local mouseWatchHooksInstalled = false
local layoutPending = false
local layoutForcePending = false

local carboniteCaptureTimer
local carboniteHooksInstalled
local zoneRefreshFrame
local zoneRefreshPending

local DEFAULT_ICON_SETTINGS = {
	managed = true,
	shown = true,
	angle = 225,
	radius = 82,
	scale = 1.0,
}

-- Дефолтные углы для известных кнопок (LibDBIcon-имя или полный buttonID)
local ADDON_BUTTON_ANGLE_DEFAULTS = {
	DBM = 40,
	Details = 130,
	AtlasLoot = 190,
	Collections = 300,
	Transmogrify = 320,
	WeakAuras = 60,
	TransmorpherMinimapButton = 340,
}

local function GetDefaultAngleForButton(buttonID)
	if not buttonID then
		return DEFAULT_ICON_SETTINGS.angle
	end
	local libName = buttonID:match("^LibDBIcon10_(.+)$")
	if libName and ADDON_BUTTON_ANGLE_DEFAULTS[libName] then
		return ADDON_BUTTON_ANGLE_DEFAULTS[libName]
	end
	if ADDON_BUTTON_ANGLE_DEFAULTS[buttonID] then
		return ADDON_BUTTON_ANGLE_DEFAULTS[buttonID]
	end
	return DEFAULT_ICON_SETTINGS.angle
end

local function BuildDefaultIconSettings(buttonID)
	return {
		managed = DEFAULT_ICON_SETTINGS.managed,
		shown = DEFAULT_ICON_SETTINGS.shown,
		angle = GetDefaultAngleForButton(buttonID),
		radius = DEFAULT_ICON_SETTINGS.radius,
		scale = DEFAULT_ICON_SETTINGS.scale,
	}
end

function module:GetDefaultIconSettings(buttonID)
	return BuildDefaultIconSettings(buttonID)
end

local MINIMAP_BUTTON_IGNORE_EXACT = {
	QuestieFrameGroup = true,
	MinimapBackdrop = true,
	MinimapPing = true,
}

local MINIMAP_BUTTON_IGNORE_PATTERNS = {
	"^QuestieFrame%d+$",
	"^QuestieFrame%d+Glow$",
	"^GatherNote",
	"^GatherMatePin",
	"^MobMapMinimapDot_",
	"^CartographerNotesPOI",
	"^RecipeRadarMinimapIcon",
	"^NauticusMiniIcon",
}

local lastMinimapButtonScanStats = nil

-- Стандартные кнопки Blizzard: управляются вкладкой «Внешний вид», не «Кнопки аддонов»
local BLIZZARD_MINIMAP_BUTTONS = {
	MiniMapWorldMapButton = true,
	MiniMapTracking = true,
	MiniMapMailFrame = true,
	MiniMapBattlefieldFrame = true,
	MiniMapLFGFrame = true,
	MiniMapVoiceChatFrame = true,
	MinimapZoomIn = true,
	MinimapZoomOut = true,
	GameTimeFrame = true,
	TimeManagerClockButton = true,
	QueueStatusMinimapButton = true,
}

local function IsBlizzardMinimapButton(frameName)
	if not frameName then
		return false
	end
	if BLIZZARD_MINIMAP_BUTTONS[frameName] then
		return true
	end
	if frameName:match("^Minimap") or frameName:match("^MiniMap") then
		return true
	end
	return false
end

-- Store original functions
local originalGameTimeFrameShow = nil
local originalTimeManagerClockButtonShow = nil
local originalMiniMapTrackingShow = nil
local originalMiniMapWorldMapButtonShow = nil
local worldMapButtonHookInstalled = false
local carboniteMBSUHookInstalled = false
local worldMapButtonReapplyTimer

-- Helper functions
local function MinimapChatPrefix(scope)
	if SarychUI and SarychUI.GetScopedChatPrefix then
		return SarychUI:GetScopedChatPrefix(scope)
	end
	return "|cffffd200SarychUI " .. scope .. ":|r"
end

local function DebugMinimapButtons(msg)
	if DEBUG_MINIMAP_BUTTONS then
		print(MinimapChatPrefix("MinimapButtons") .. " " .. msg)
	end
end

local function PerfNow()
	return debugprofilestop()
end

local function PerfLog(stage, startTime)
	if DEBUG_MINIMAP_BUTTONS_PERF and startTime then
		print(string.format("%s %s: %.2f ms", MinimapChatPrefix("MinimapButtons Perf"), stage, PerfNow() - startTime))
	end
end

local function DebugLayout(msg)
	if DEBUG_MINIMAP_BUTTONS_LAYOUT then
		print(MinimapChatPrefix("MinimapButtons Layout") .. " " .. msg)
	end
end

local function ClearButtonLayoutCache(button, buttonID)
	if not button then
		return
	end
	button.__SarychUILastAngle = nil
	button.__SarychUILastRadius = nil
	button.__SarychUILastScale = nil
	button.__SarychUILastPosX = nil
	button.__SarychUILastPosY = nil
	button.__SarychUILastShown = nil
	if buttonID then
		DebugLayout("cache cleared id=" .. module:GetButtonDisplayName(buttonID))
	end
end

local function DebugWorldMapButton(msg)
	if DEBUG_MINIMAP_WORLD_BUTTON then
		print(MinimapChatPrefix("Minimap") .. " " .. msg)
	end
end

local function DisableButtonDrag(button)
	if not button or button._SarychUIDragDisabled then
		return
	end
	if button.SetMovable then
		pcall(button.SetMovable, button, false)
	end
	if button.SetUserPlaced then
		pcall(button.SetUserPlaced, button, false)
	end
	if button.RegisterForDrag then
		pcall(button.RegisterForDrag, button)
	end
	if button.SetScript then
		button:SetScript("OnDragStart", nil)
		button:SetScript("OnDragStop", nil)
	end
	button._SarychUIDragDisabled = true
end

local function EnsureAddonButtonsDB()
	if not db then return nil end
	db.addonButtons = db.addonButtons or { icons = {} }
	db.addonButtons.icons = db.addonButtons.icons or {}
	return db.addonButtons.icons
end

local function IsIgnoredMinimapButtonID(buttonID)
	if not buttonID or buttonID == "" then
		return true
	end
	if MINIMAP_BUTTON_IGNORE_EXACT[buttonID] then
		return true
	end
	for i = 1, #MINIMAP_BUTTON_IGNORE_PATTERNS do
		if buttonID:match(MINIMAP_BUTTON_IGNORE_PATTERNS[i]) then
			return true
		end
	end
	return false
end

function module:IsIgnoredMinimapButtonID(buttonID)
	return IsIgnoredMinimapButtonID(buttonID)
end

local function IsQuestieMapPinFrame(frame, frameName)
	if not frame then
		return false
	end
	frameName = frameName or (frame.GetName and frame:GetName())
	if frameName and frameName:match("^QuestieFrame%d+") then
		return true
	end
	if frame.frameId ~= nil then
		return true
	end
	if frame.data and frame.texture and frameName and frameName:match("^Questie") then
		return true
	end
	return false
end

local function FrameHasButtonVisual(frame)
	if frame.GetNormalTexture then
		local tex = frame:GetNormalTexture()
		if tex and tex.GetTexture and tex:GetTexture() then
			return true
		end
	end
	if frame.icon and frame.icon.GetTexture and frame.icon:GetTexture() then
		return true
	end
	if frame.texture and frame.texture.GetTexture and frame.texture:GetTexture() then
		return true
	end
	if frame.CreateTexture and frame.GetNumRegions then
		for i = 1, frame:GetNumRegions() do
			local region = select(i, frame:GetRegions())
			if region and region.GetObjectType and region:GetObjectType() == "Texture" then
				if region.GetTexture and region:GetTexture() then
					return true
				end
			end
		end
	end
	return false
end

local function IsValidAddonMinimapButton(frame)
	if not frame or not frame.GetName or not frame.GetParent then
		return false, "no_frame"
	end

	local frameName = frame:GetName()
	if not frameName or frameName == "" then
		return false, "unnamed"
	end
	if IsBlizzardMinimapButton(frameName) then
		return false, "blizzard"
	end
	if IsIgnoredMinimapButtonID(frameName) then
		return false, "blacklist"
	end
	if frame:GetParent() ~= Minimap then
		return false, "parent"
	end
	if IsQuestieMapPinFrame(frame, frameName) then
		return false, "questie_pin"
	end

	local isLibDBIcon = frameName:match("^LibDBIcon10_") ~= nil
	local objType = frame.GetObjectType and frame:GetObjectType() or ""
	if objType ~= "Button" and not isLibDBIcon then
		return false, "not_button"
	end

	if not isLibDBIcon and frameName ~= "NXMiniMapBut" then
		local w = (frame.GetWidth and frame:GetWidth()) or 0
		local h = (frame.GetHeight and frame:GetHeight()) or 0
		if w < 12 or h < 12 or w > 64 or h > 64 then
			return false, "size"
		end
		if not FrameHasButtonVisual(frame) and not (frame.GetScript and frame:GetScript("OnClick")) then
			return false, "no_visual"
		end
	end

	return true, "ok"
end

function module:GetStableMinimapButtonKey(frame)
	if not frame or not frame.GetName then
		return nil
	end
	return frame:GetName()
end

local function RegisterAddonButtonIcon(icons, buttonID, stats, source)
	if IsIgnoredMinimapButtonID(buttonID) then
		stats.skippedBlacklist = stats.skippedBlacklist + 1
		return false
	end

	if stats.seenKeys[buttonID] then
		stats.skippedDuplicate = stats.skippedDuplicate + 1
		return false
	end

	stats.seenKeys[buttonID] = source or "unknown"
	if not icons[buttonID] then
		icons[buttonID] = BuildDefaultIconSettings(buttonID)
		stats.added = stats.added + 1
		DebugMinimapButtons("Registered button: " .. buttonID .. " (" .. (source or "?") .. ")")
	end
	stats.registered = stats.registered + 1
	return true
end

local function ScanLibDBIconButtons(icons, stats)
	local lib = LibStub and LibStub("LibDBIcon-1.0", true)
	if not lib or not lib.objects then
		return
	end

	for name, button in pairs(lib.objects) do
		if button and button.GetName then
			local buttonID = button:GetName() or ("LibDBIcon10_" .. name)
			stats.scanned = stats.scanned + 1
			stats.candidates = stats.candidates + 1
			RegisterAddonButtonIcon(icons, buttonID, stats, "LibDBIcon")
		end
	end
end

function module:CleanupAddonButtonIcons()
	if self.InvalidateAddonButtonIconOptionsCache then
		self:InvalidateAddonButtonIconOptionsCache()
	end

	local icons = EnsureAddonButtonsDB()
	if not icons then
		return { removed = 0 }
	end

	local removed = 0
	for buttonID in pairs(icons) do
		local remove = false
		if IsBlizzardMinimapButton(buttonID) or IsIgnoredMinimapButtonID(buttonID) then
			remove = true
		elseif buttonID:match("^QuestieFrame") then
			remove = true
		else
			local frame = _G[buttonID]
			if frame then
				local valid = IsValidAddonMinimapButton(frame)
				if not valid then
					remove = true
				end
			elseif buttonID:match("^Questie") then
				remove = true
			end
		end
		if remove then
			icons[buttonID] = nil
			removed = removed + 1
		end
	end

	return { removed = removed }
end

local function PurgeBlacklistedIconSettings()
	module:CleanupAddonButtonIcons()
end

function module:GetButtonDisplayName(buttonID)
	if buttonID == "NXMiniMapBut" then
		return "Carbonite"
	end
	local libName = buttonID:match("^LibDBIcon10_(.+)$")
	if libName then
		return libName
	end
	return buttonID
end

function module:IsBlizzardMinimapButton(frameName)
	return IsBlizzardMinimapButton(frameName)
end

local function GetButtonSettings(buttonID)
	if IsBlizzardMinimapButton(buttonID) then
		return nil
	end
	local icons = EnsureAddonButtonsDB()
	if not icons then return nil end
	if not icons[buttonID] then
		icons[buttonID] = BuildDefaultIconSettings(buttonID)
	end
	return icons[buttonID]
end

-- Проверка, является ли фрейм управляемой кнопкой аддона на миникарте
local function IsManagedMinimapButton(frame)
	return IsValidAddonMinimapButton(frame)
end

local function IsAddonMinimapButton(frame)
	return IsManagedMinimapButton(frame)
end

local function IsButtonManagedBySarychUI(frame)
	if not IsManagedMinimapButton(frame) then
		return false
	end
	local buttonID = frame:GetName()
	local cfg = buttonID and GetButtonSettings(buttonID)
	return cfg and cfg.managed == true
end

local function ShouldParticipateInAutoHide(frame)
	if not IsButtonManagedBySarychUI(frame) then
		return false
	end
	local buttonID = frame:GetName()
	local cfg = GetButtonSettings(buttonID)
	return cfg and cfg.shown ~= false
end

local function GetSetting(key, default)
	if not db then return default end
	return db[key] ~= nil and db[key] or default
end

function module:ApplyWorldMapButtonVisibility()
	if not MiniMapWorldMapButton then
		return
	end

	self:InstallWorldMapButtonGuard()

	if not originalMiniMapWorldMapButtonShow then
		originalMiniMapWorldMapButtonShow = MiniMapWorldMapButton.Show
	end

	local hide = GetSetting("hideWorldMapButton", 1) == 1
	DebugWorldMapButton("ApplyWorldMapButtonVisibility hide=" .. tostring(hide))

	if hide then
		MiniMapWorldMapButton:Hide()
		MiniMapWorldMapButton.Show = function() end
	else
		if originalMiniMapWorldMapButtonShow then
			MiniMapWorldMapButton.Show = originalMiniMapWorldMapButtonShow
		else
			MiniMapWorldMapButton.Show = nil
		end
		MiniMapWorldMapButton:Show()
	end
end

function module:InstallWorldMapButtonGuard()
	if worldMapButtonHookInstalled or not MiniMapWorldMapButton then
		return
	end
	worldMapButtonHookInstalled = true

	if not originalMiniMapWorldMapButtonShow then
		originalMiniMapWorldMapButtonShow = MiniMapWorldMapButton.Show
	end

	hooksecurefunc(MiniMapWorldMapButton, "Show", function(self)
		if self.__SarychUIHiding then
			return
		end
		if GetSetting("hideWorldMapButton", 1) == 1 then
			DebugWorldMapButton("MiniMapWorldMapButton Show intercepted, hiding again")
			self.__SarychUIHiding = true
			self:Hide()
			self.__SarychUIHiding = nil
		end
	end)
end

function module:InstallCarboniteWorldMapButtonHook()
	if carboniteMBSUHookInstalled then
		return
	end
	local Nx = _G.Nx
	if not Nx or not Nx.Map or not Nx.Map.MBSU then
		return
	end
	carboniteMBSUHookInstalled = true
	hooksecurefunc(Nx.Map, "MBSU", function()
		module:ApplyWorldMapButtonVisibility()
	end)
end

function module:ScheduleWorldMapButtonReapply(reason)
	DebugWorldMapButton("Carbonite loaded, reapply world map button visibility" .. (reason and (" (" .. reason .. ")") or ""))
	self:InstallCarboniteWorldMapButtonHook()
	self:ApplyWorldMapButtonVisibility()

	if worldMapButtonReapplyTimer then
		self:CancelTimer(worldMapButtonReapplyTimer)
		worldMapButtonReapplyTimer = nil
	end

	local delays = { 0.5, 1.0, 2.0 }
	local step = 1
	local function scheduleNext()
		if step > #delays then
			worldMapButtonReapplyTimer = nil
			return
		end
		worldMapButtonReapplyTimer = self:ScheduleTimer(function()
			module:ApplyWorldMapButtonVisibility()
			step = step + 1
			scheduleNext()
		end, delays[step])
	end
	scheduleNext()
end

-- Надёжная проверка «курсор над миникартой»
local function IsCursorOverFrame(f)
	if not f or not f.IsVisible or not f:IsVisible() then return false end
	if f.IsMouseOver then
		local ok, over = pcall(f.IsMouseOver, f, 0,0,0,0)
		if ok then return over end
	end
	-- геометрический фолбэк
	local cx, cy = GetCursorPosition()
	local scale = (f.GetEffectiveScale and f:GetEffectiveScale()) or UIParent:GetEffectiveScale()
	cx, cy = cx/scale, cy/scale
	local L, R = f:GetLeft(), f:GetRight()
	local B, T = f:GetBottom(), f:GetTop()
	if not L or not R or not B or not T then return false end
	return cx >= L and cx <= R and cy >= B and cy <= T
end

local function IsOverMinimap()
	return IsCursorOverFrame(Minimap)
		or IsCursorOverFrame(_G.MinimapBackdrop)
		or IsCursorOverFrame(_G.MinimapCluster)
end

-- Кэш детей миникарты (оптимизация производительности)
local minimapChildrenCache = nil

-- Функция для получения кэшированных детей миникарты
local function GetMinimapChildren()
	if not minimapChildrenCache then
		RefreshMinimapChildrenCache()
	end
	return minimapChildrenCache
end

-- Функция для обновления кэша детей миникарты
function RefreshMinimapChildrenCache()
	if Minimap then
		minimapChildrenCache = { Minimap:GetChildren() }
	else
		minimapChildrenCache = {}
	end
	managedButtonsListDirty = true
end

local function InvalidateManagedButtonsList()
	managedButtonsListDirty = true
end

-- Реестр управляемых кнопок (обновляется при scan/layout и при смене зоны)
local function RebuildManagedButtonsList()
	wipe(managedButtonsList)
	local seen = {}

	local icons = EnsureAddonButtonsDB()
	if icons then
		for buttonID in pairs(icons) do
			if not IsBlizzardMinimapButton(buttonID) then
				local button = _G[buttonID]
				if button and ShouldParticipateInAutoHide(button) and not seen[button] then
					seen[button] = true
					managedButtonsList[#managedButtonsList + 1] = button
				end
			end
		end
	end

	for _, child in ipairs(GetMinimapChildren()) do
		if ShouldParticipateInAutoHide(child) and not seen[child] then
			seen[child] = true
			managedButtonsList[#managedButtonsList + 1] = child
		end
	end

	managedButtonsListDirty = false
end

local function GetManagedButtons()
	if managedButtonsListDirty or #managedButtonsList == 0 then
		RefreshMinimapChildrenCache()
		RebuildManagedButtonsList()
	end
	return managedButtonsList
end

-- Проверка, находится ли курсор над кнопками аддонов
local function IsOverAddonButtons()
	for _, button in ipairs(GetManagedButtons()) do
		if IsCursorOverFrame(button) then
			return true
		end
	end
	return false
end

-- Объявляем функции HideMinimapButtons и ShowMinimapButtons заранее, чтобы они были доступны в замыканиях
local HideMinimapButtons, ShowMinimapButtons

-- Безопасные функции фейда (защита от отсутствия UIFrameFade*)
local function SafeFadeOut(frame, t, from, to)
	if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(frame) end
	if UIFrameFadeOut then
		UIFrameFadeOut(frame, t, from, to)
	else
		frame:SetAlpha(to or 0)
	end
end

local function SafeFadeIn(frame, t, from, to)
	if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(frame) end
	if UIFrameFadeIn then
		UIFrameFadeIn(frame, t, from, to)
	else
		frame:SetAlpha(to or 1)
	end
end

-- Хелперы наблюдения за курсором (AceTimer + AceHook)
local armHide, cancelPending

local function StopMouseWatch()
	if mouseWatchTicker then module:CancelTimer(mouseWatchTicker); mouseWatchTicker = nil end
	if pendingHideTimer then module:CancelTimer(pendingHideTimer); pendingHideTimer = nil end
	if mouseWatchHooksInstalled then
		module:UnhookAll()
		mouseWatchHooksInstalled = false
		for _, button in ipairs(GetManagedButtons()) do
			button.__SarychUIMouseHooked = nil
		end
	end
end

local function InstallButtonMouseHooks()
	for _, button in ipairs(GetManagedButtons()) do
		if button.HookScript and not button.__SarychUIMouseHooked then
			button.__SarychUIMouseHooked = true
			module:SecureHookScript(button, "OnEnter", function()
				if areButtonsVisible then cancelPending() end
			end)
			module:SecureHookScript(button, "OnLeave", function()
				if areButtonsVisible then armHide() end
			end)
		end
	end
end

local function EnsureMouseWatchHooks()
	if mouseWatchHooksInstalled then
		return
	end
	mouseWatchHooksInstalled = true

	local hideDelay = GetSetting('hideDelay', 0.5)

	armHide = function()
		if pendingHideTimer then module:CancelTimer(pendingHideTimer) end
		pendingHideTimer = module:ScheduleTimer(function()
			if areButtonsVisible and not IsOverMinimap() and not IsOverAddonButtons() then
				HideMinimapButtons()
			end
		end, hideDelay)
	end

	cancelPending = function()
		if pendingHideTimer then module:CancelTimer(pendingHideTimer); pendingHideTimer = nil end
	end

	for _, fr in next, { Minimap, _G.MinimapBackdrop, _G.MinimapCluster } do
		if fr and fr.HookScript then
			module:SecureHookScript(fr, "OnEnter", function()
				if areButtonsVisible then cancelPending() end
			end)
			module:SecureHookScript(fr, "OnLeave", function()
				if areButtonsVisible then armHide() end
			end)
		end
	end

	InstallButtonMouseHooks()
end

local function StartMouseWatch()
	EnsureMouseWatchHooks()
	if mouseWatchTicker then
		return
	end
	mouseWatchTicker = module:ScheduleRepeatingTimer(function()
		if not areButtonsVisible or isAnimatingShow then return end
		if IsOverMinimap() or IsOverAddonButtons() then
			cancelPending()
		else
			if not pendingHideTimer then armHide() end
		end
	end, 0.2)
end

local function StoreOriginalFunctions()
	-- Store original GameTimeFrame Show function
	if GameTimeFrame and not originalGameTimeFrameShow then
		originalGameTimeFrameShow = GameTimeFrame.Show
	end
	
	-- Store original TimeManagerClockButton Show function
	if TimeManagerClockButton and not originalTimeManagerClockButtonShow then
		originalTimeManagerClockButtonShow = TimeManagerClockButton.Show
	end
	
	-- Store original MiniMapTracking Show function
	if MiniMapTracking and not originalMiniMapTrackingShow then
		originalMiniMapTrackingShow = MiniMapTracking.Show
	end
end

local function ApplyCalendarSettings()
	if not GameTimeFrame then 
		-- Try to find GameTimeFrame by name if it exists but not accessible
		GameTimeFrame = _G["GameTimeFrame"]
		if not GameTimeFrame then return end
	end
	
	-- Always store original function first
	StoreOriginalFunctions()
	
	if GetSetting('hideCalendar', 1) == 1 then
		-- Hide calendar
		GameTimeFrame:Hide()
		GameTimeFrame.Show = function() end
	else
		-- Show calendar - restore original function and show
		if originalGameTimeFrameShow then
			GameTimeFrame.Show = originalGameTimeFrameShow
		else
			GameTimeFrame.Show = nil
		end
		-- Force show the frame multiple times to ensure it appears
		GameTimeFrame:Show()
		GameTimeFrame:SetAlpha(1)
		GameTimeFrame:SetShown(true)
	end
end

-- Подготовка кнопки: один раз Show(), далее только alpha/EnableMouse (без Show/Hide при toggle)
local function PrepareManagedButtonForAutoHide(button)
	if not button then return end
	if not button:IsShown() then
		button:Show()
	end
	if button.__SarychUIAutoHidePrepared then
		return
	end
	button.__SarychUIAutoHidePrepared = true
	button.__SarychUILastShown = false
end

local function SetManagedButtonRuntimeVisible(button, visible, fadeTime)
	if not button then return end
	PrepareManagedButtonForAutoHide(button)

	if button.__SarychUILastShown == visible and not isAnimatingShow then
		return
	end

	local a = button:GetAlpha() or 0
	if visible then
		if button.EnableMouse then button:EnableMouse(true) end
		if button.Enable then button:Enable() end
		if fadeTime > 0 and a < 1 then
			SafeFadeIn(button, fadeTime, max(0, a), 1)
		else
			button:SetAlpha(1)
		end
	else
		if button.EnableMouse then button:EnableMouse(false) end
		if button.Disable then button:Disable() end
		if fadeTime > 0 and a > 0 then
			SafeFadeOut(button, fadeTime, a, 0)
		else
			button:SetAlpha(0)
		end
	end
	button.__SarychUILastShown = visible
end

local function DisableMinimapButton(button)
	PrepareManagedButtonForAutoHide(button)
	button:SetAlpha(0)
	button:EnableMouse(false)
	if button.Disable then button:Disable() end
	button.__SarychUILastShown = false
end

local function EnableMinimapButton(button)
	PrepareManagedButtonForAutoHide(button)
	button:SetAlpha(1)
	button:EnableMouse(true)
	if button.Enable then button:Enable() end
	button.__SarychUILastShown = true
end

HideMinimapButtons = function()
	local totalStart = PerfNow()
	PerfLog("click received", totalStart)

	InvalidateManagedButtonsList()

	local fadeTime = GetSetting('fadeTime', 0.1)
	isAnimatingShow = false
	areButtonsVisible = false

	if PlaySound then
		PlaySound("UChatScrollButton")
	end

	local hideStart = PerfNow()
	for _, button in ipairs(GetManagedButtons()) do
		SetManagedButtonRuntimeVisible(button, false, fadeTime)
	end
	PerfLog("show/hide buttons", hideStart)

	if fadeTime > 0 then
		C_Timer.After(fadeTime + 0.05, function()
			for _, button in ipairs(GetManagedButtons()) do
				if not areButtonsVisible then
					button:SetAlpha(0)
					if button.EnableMouse then button:EnableMouse(false) end
					if button.Disable then button:Disable() end
					button.__SarychUILastShown = false
				end
			end
		end)
	end

	PerfLog("total", totalStart)
end

ShowMinimapButtons = function()
	local totalStart = PerfNow()
	PerfLog("click received", totalStart)

	InvalidateManagedButtonsList()

	local fadeTime = GetSetting('fadeTime', 0.1)
	isAnimatingShow = true
	areButtonsVisible = true

	if PlaySound then
		PlaySound("UChatScrollButton")
	end

	local showStart = PerfNow()
	for _, button in ipairs(GetManagedButtons()) do
		SetManagedButtonRuntimeVisible(button, true, fadeTime)
	end
	PerfLog("show/hide buttons", showStart)

	local watchStart = PerfNow()
	StartMouseWatch()
	PerfLog("mouse watch", watchStart)

	if fadeTime > 0 then
		C_Timer.After(fadeTime + 0.1, function()
			for _, button in ipairs(GetManagedButtons()) do
				if areButtonsVisible then
					button:SetAlpha(1)
					button.__SarychUILastShown = true
				end
			end
			isAnimatingShow = false
		end)
	else
		isAnimatingShow = false
	end

	PerfLog("total", totalStart)
end

local function InstallMinimapMouseHandler()
	if not Minimap then return end

	Minimap:SetScript("OnMouseUp", function(self, btn)
		if btn == "LeftButton" then
			if IsShiftKeyDown() and GetSetting('leftClickEnabled', 1) == 1 then
				Minimap_OnClick(self)
			else
				if GetSetting('buttonsEnabled', 1) == 1 then
					if areButtonsVisible then
						HideMinimapButtons()
					elseif not isAnimatingShow then
						ShowMinimapButtons()
					end
				end
			end
		elseif btn == "RightButton" and GetSetting('rightClickEnabled', 1) == 1 then
			ToggleCalendar()
		elseif btn == "MiddleButton" and GetSetting('middleClickEnabled', 1) == 1 then
			ToggleDropDownMenu(1, nil, MiniMapTrackingDropDown, self)
		end
	end)
end

local function HandleMinimapWorldChanged()
	if not db or not db.enabled then return end

	isAnimatingShow = false
	if pendingHideTimer then module:CancelTimer(pendingHideTimer); pendingHideTimer = nil end

	RefreshMinimapChildrenCache()

	if GetSetting('buttonsEnabled', 1) == 1 then
		areButtonsVisible = false
		StopMouseWatch()
		InstallMinimapMouseHandler()
	end

	if zoneRefreshPending then return end
	zoneRefreshPending = true
	C_Timer.After(0.3, function()
		zoneRefreshPending = false
		if not db or not db.enabled then return end

		RefreshMinimapChildrenCache()
		module:ApplyAddonButtonLayout(true)

		if GetSetting('buttonsEnabled', 1) == 1 then
			isAnimatingShow = false
			areButtonsVisible = false
			for _, button in ipairs(GetManagedButtons()) do
				DisableMinimapButton(button)
			end
			InstallMinimapMouseHandler()
		end
	end)
end

local function EnsureZoneRefreshListener()
	if zoneRefreshFrame then return end
	zoneRefreshFrame = CreateFrame("Frame")
	zoneRefreshFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	zoneRefreshFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	zoneRefreshFrame:RegisterEvent("ZONE_CHANGED")
	zoneRefreshFrame:SetScript("OnEvent", function()
		HandleMinimapWorldChanged()
	end)
end

local function StopZoneRefreshListener()
	if not zoneRefreshFrame then return end
	zoneRefreshFrame:UnregisterAllEvents()
	zoneRefreshFrame:SetScript("OnEvent", nil)
	zoneRefreshFrame = nil
	zoneRefreshPending = false
end


local function SetupMinimap()
	-- Безопасно включи мышь и хитбокс
	if Minimap.EnableMouse then Minimap:EnableMouse(true) end
	if Minimap.SetHitRectInsets then Minimap:SetHitRectInsets(0,0,0,0) end
	
	-- Hide border
	if GetSetting('hideBorder', 1) == 1 then
		MinimapBorderTop:Hide()
	else
		MinimapBorderTop:Show()
	end
	
	-- Hide zoom buttons
	if GetSetting('hideZoomButtons', 1) == 1 then
		MinimapZoomIn:Hide()
		MinimapZoomOut:Hide()
	else
		MinimapZoomIn:Show()
		MinimapZoomOut:Show()
	end
	
	-- Hide world map button (SarychUI «Внешний вид» — единственный источник управления)
	module:ApplyWorldMapButtonVisibility()
	
	-- Hide clock
	if GetSetting('hideClock', 0) == 1 then
		if TimeManagerClockButton then
			StoreOriginalFunctions()
			TimeManagerClockButton:Hide()
			TimeManagerClockButton.Show = function() end
		end
	else
		if TimeManagerClockButton then
			if originalTimeManagerClockButtonShow then
				TimeManagerClockButton.Show = originalTimeManagerClockButtonShow
			else
				TimeManagerClockButton.Show = nil
			end
			TimeManagerClockButton:Show()
		end
	end
	
	-- Move zone text
	if GetSetting('moveZoneText', 1) == 1 then
		local zoneTextOffsetX = GetSetting('zoneTextOffsetX', 0)
		local zoneTextOffsetY = GetSetting('zoneTextOffsetY', 4)
		MinimapZoneText:ClearAllPoints()
		MinimapZoneText:SetPoint("TOPLEFT", "MinimapZoneTextButton", "TOPLEFT", zoneTextOffsetX, zoneTextOffsetY)
	else
		MinimapZoneText:ClearAllPoints()
		MinimapZoneText:SetPoint("TOPLEFT", "MinimapZoneTextButton", "TOPLEFT", 0, 0)
	end
	
	-- Hide tracking
	if GetSetting('hideTracking', 1) == 1 then
		StoreOriginalFunctions()
		MiniMapTracking:Hide()
		MiniMapTracking.Show = function() end
	else
		if originalMiniMapTrackingShow then
			MiniMapTracking.Show = originalMiniMapTrackingShow
		else
			MiniMapTracking.Show = nil
		end
		MiniMapTracking:Show()
	end
	
	-- Hide calendar
	ApplyCalendarSettings()
	
	-- Mouse wheel zoom
	if GetSetting('wheelEnabled', 1) == 1 then
		Minimap:EnableMouseWheel(true)
		Minimap:SetScript("OnMouseWheel", function(self, z)
			local currentZoom = Minimap:GetZoom()
			if z > 0 and currentZoom < 5 then
				Minimap:SetZoom(currentZoom + 1)
			elseif z < 0 and currentZoom > 0 then
				Minimap:SetZoom(currentZoom - 1)
			end
		end)
	else
		Minimap:EnableMouseWheel(false)
		Minimap:SetScript("OnMouseWheel", nil)
	end
	
	-- Mouse clicks
	InstallMinimapMouseHandler()
	
	-- Управление кнопками аддонов (автоскрытие по клику)
	if GetSetting('buttonsEnabled', 1) == 1 then
		StopMouseWatch()
		isAnimatingShow = false
		for _, button in ipairs(GetManagedButtons()) do
			DisableMinimapButton(button)
		end
		areButtonsVisible = false
	else
		StopMouseWatch()
		isAnimatingShow = false
		areButtonsVisible = true
	end
end

local function ResetMinimapToDefaults()
    local defaults = SarychUI and SarychUI.defaults and SarychUI.defaults.profile and SarychUI.defaults.profile.modules and SarychUI.defaults.profile.modules.minimap
    local defA = (defaults and defaults.minimapA) or "TOPRIGHT"
    local defR = (defaults and defaults.minimapR) or "TOPRIGHT"
    local defX = (defaults and defaults.minimapX) or 0
    local defY = (defaults and defaults.minimapY) or 0
    -- apply immediately
    MinimapCluster.ignoreFramePositionManager = false
    if MinimapCluster.SetUserPlaced then pcall(MinimapCluster.SetUserPlaced, MinimapCluster, false) end
    MinimapCluster:ClearAllPoints()
    MinimapCluster:SetPoint(defA, UIParent, defR, defX, defY)
end

local function SaveCurrentCustomPosition()
    if not db then return end
    db.minimapSavedA = db.minimapA or "TOPRIGHT"
    db.minimapSavedR = db.minimapR or "TOPRIGHT"
    db.minimapSavedX = db.minimapX ~= nil and db.minimapX or (db.offsetX or 0)
    db.minimapSavedY = db.minimapY ~= nil and db.minimapY or (db.offsetY or 0)
end

local function MoveMinimap()
    if GetSetting('positioningEnabled', 0) == 1 then
        local point = GetSetting('minimapA', "TOPRIGHT")
        local relPoint = GetSetting('minimapR', "TOPRIGHT")
        local x = GetSetting('minimapX', GetSetting('offsetX', 0))
        local y = GetSetting('minimapY', GetSetting('offsetY', 0))
        MinimapCluster:ClearAllPoints()
        MinimapCluster:SetPoint(point, UIParent, relPoint, x, y)
    else
        -- Restore Blizzard-managed position (real-time)
        MinimapCluster.ignoreFramePositionManager = false
        if MinimapCluster.SetUserPlaced then pcall(MinimapCluster.SetUserPlaced, MinimapCluster, false) end
        MinimapCluster:ClearAllPoints()
        -- Prefer our defaults explicitly to avoid layout races
        ResetMinimapToDefaults()
    end
end

local function ApplyButtonPosition(button, cfg, force, buttonID)
	if not button or not cfg or not Minimap or not cfg.managed then
		return
	end

	if button:GetParent() ~= Minimap then
		button:SetParent(Minimap)
	end
	if button.SetFrameStrata then
		button:SetFrameStrata("LOW")
	end

	local angle = cfg.angle or DEFAULT_ICON_SETTINGS.angle
	local radius = cfg.radius or DEFAULT_ICON_SETTINGS.radius
	local scale = cfg.scale or DEFAULT_ICON_SETTINGS.scale

	if button.SetIgnoreParentScale then
		pcall(button.SetIgnoreParentScale, button, true)
	end

	local radians = rad(angle)
	local x = cos(radians) * radius
	local y = sin(radians) * radius

	local needsScale = force or button.__SarychUILastScale ~= scale
	local needsPosition = force
		or button.__SarychUILastAngle ~= angle
		or button.__SarychUILastRadius ~= radius
		or button.__SarychUILastPosX ~= x
		or button.__SarychUILastPosY ~= y

	if needsScale then
		if button.SetScale then
			button:SetScale(scale)
		end
		button.__SarychUILastScale = scale
	end

	if needsPosition then
		button:ClearAllPoints()
		button:SetPoint("CENTER", Minimap, "CENTER", x, y)
		button.__SarychUILastAngle = angle
		button.__SarychUILastRadius = radius
		button.__SarychUILastPosX = x
		button.__SarychUILastPosY = y
	end

	if button.db then
		button.db.minimapPos = nil
	end

	DisableButtonDrag(button)
	if button.icon and button.icon ~= button and button.icon.SetScript then
		DisableButtonDrag(button.icon)
	end

	if button.EnableMouse then
		button:EnableMouse(true)
	end

	if DEBUG_MINIMAP_BUTTONS_LAYOUT and buttonID and (needsScale or needsPosition) then
		DebugLayout(string.format(
			"apply id=%s angle=%s radius=%s scale=%s x=%.1f y=%.1f",
			module:GetButtonDisplayName(buttonID), tostring(angle), tostring(radius), tostring(scale), x, y
		))
	end
end

local function ApplySingleButtonLayout(buttonID, button, force)
	local cfg = GetButtonSettings(buttonID)
	if not cfg then
		return
	end

	if not button then
		button = _G[buttonID]
	end
	if not button then
		return
	end

	if force then
		ClearButtonLayoutCache(button, buttonID)
	end

	if not cfg.managed then
		button._SarychUIDragDisabled = nil
		return
	end

	if cfg.shown == false then
		DisableMinimapButton(button)
		return
	end

	ApplyButtonPosition(button, cfg, force, buttonID)

	if GetSetting("buttonsEnabled", 1) == 1 then
		if areButtonsVisible then
			EnableMinimapButton(button)
		else
			DisableMinimapButton(button)
		end
	else
		EnableMinimapButton(button)
	end
end

local function ApplyAddonButtonLayoutNow(force)
	if not db or not db.enabled or not Minimap then
		return
	end

	if force then
		DebugLayout("force refresh requested")
	end

	local layoutStart = PerfNow()
	EnsureAddonButtonsDB()
	RefreshMinimapChildrenCache()

	for buttonID, cfg in pairs(db.addonButtons.icons) do
		if not IsBlizzardMinimapButton(buttonID) then
			local button = _G[buttonID]
			if button then
				ApplySingleButtonLayout(buttonID, button, force)
			end
		end
	end

	for _, child in ipairs(GetMinimapChildren()) do
		if IsManagedMinimapButton(child) then
			local buttonID = child:GetName()
			if buttonID then
				GetButtonSettings(buttonID)
				ApplySingleButtonLayout(buttonID, child, force)
			end
		end
	end

	RebuildManagedButtonsList()
	if mouseWatchHooksInstalled then
		InstallButtonMouseHooks()
	end
	PerfLog("apply layout", layoutStart)
end

function module:ApplyAddonButtonLayout(force)
	if force then
		layoutForcePending = true
	end
	if layoutPending then
		return
	end
	layoutPending = true
	C_Timer.After(0, function()
		layoutPending = false
		local doForce = layoutForcePending
		layoutForcePending = false
		ApplyAddonButtonLayoutNow(doForce)
	end)
end

function module:ScanAddonMinimapButtons()
	if not db or not db.enabled then
		return lastMinimapButtonScanStats
	end

	if SarychUI and SarychUI.PerfCounter then
		SarychUI:PerfCounter("minimapScan", 1)
	end

	local scanStart = PerfNow()
	self:CleanupAddonButtonIcons()
	local icons = EnsureAddonButtonsDB()
	if not icons then
		return nil
	end

	RefreshMinimapChildrenCache()
	local stats = {
		scanned = 0,
		candidates = 0,
		registered = 0,
		added = 0,
		skippedDuplicate = 0,
		skippedBlacklist = 0,
		skippedInvalid = 0,
		seenKeys = {},
	}

	ScanLibDBIconButtons(icons, stats)

	for _, child in ipairs(GetMinimapChildren()) do
		stats.scanned = stats.scanned + 1
		local valid, reason = IsValidAddonMinimapButton(child)
		if valid then
			stats.candidates = stats.candidates + 1
			local buttonID = child:GetName()
			if buttonID then
				RegisterAddonButtonIcon(icons, buttonID, stats, "frame-scan")
			end
		elseif reason == "blacklist" or reason == "questie_pin" then
			stats.skippedBlacklist = stats.skippedBlacklist + 1
		else
			stats.skippedInvalid = stats.skippedInvalid + 1
		end
	end

	if _G.NXMiniMapBut then
		stats.candidates = stats.candidates + 1
		RegisterAddonButtonIcon(icons, "NXMiniMapBut", stats, "carbonite")
	end

	lastMinimapButtonScanStats = stats
	PerfLog("scan buttons", scanStart)
	DebugMinimapButtons(string.format(
		"Scan complete: registered=%d added=%d dup=%d blacklist=%d invalid=%d",
		stats.registered, stats.added, stats.skippedDuplicate, stats.skippedBlacklist, stats.skippedInvalid
	))
	layoutPending = false
	layoutForcePending = false
	ApplyAddonButtonLayoutNow(true)
	return stats
end

function module:DebugMinimapButtonsScan(verbose)
	DEBUG_MINIMAP_BUTTONS = true
	local cleanup = self:CleanupAddonButtonIcons()
	local stats = self:ScanAddonMinimapButtons() or {}
	local questieFrames = {}

	local function inspectFrame(frame)
		if not frame or not frame.GetName then
			return
		end
		local name = frame:GetName()
		if not name or not name:match("Questie") then
			return
		end
		local valid, reason = IsValidAddonMinimapButton(frame)
		questieFrames[#questieFrames + 1] = {
			name = name,
			type = (frame.GetObjectType and frame:GetObjectType()) or "?",
			parent = frame:GetParent() and frame:GetParent():GetName() or "?",
			w = (frame.GetWidth and frame:GetWidth()) or 0,
			h = (frame.GetHeight and frame:GetHeight()) or 0,
			visible = (frame.IsShown and frame:IsShown()) or false,
			hasOnClick = frame.GetScript and frame:GetScript("OnClick") ~= nil,
			frameId = frame.frameId,
			reason = valid and "added" or reason,
		}
	end

	if Minimap then
		for _, child in ipairs({ Minimap:GetChildren() }) do
			inspectFrame(child)
		end
		local group = _G.QuestieFrameGroup
		if group and group.GetChildren then
			for _, child in ipairs({ group:GetChildren() }) do
				inspectFrame(child)
			end
		end
	end

	print(MinimapChatPrefix("MinimapButtons") .. " scan debug")
	print(string.format(
		"  scanned=%d candidates=%d registered=%d added=%d duplicate=%d blacklist=%d invalid=%d cleanup_removed=%d",
		stats.scanned or 0,
		stats.candidates or 0,
		stats.registered or 0,
		stats.added or 0,
		stats.skippedDuplicate or 0,
		stats.skippedBlacklist or 0,
		stats.skippedInvalid or 0,
		cleanup and cleanup.removed or 0
	))
	print("  Questie-related frames:")
	if #questieFrames == 0 then
		print("    (none on Minimap / QuestieFrameGroup)")
	else
		for i = 1, #questieFrames do
			local f = questieFrames[i]
			print(string.format(
				"    %s type=%s parent=%s %dx%d visible=%s onClick=%s frameId=%s -> %s",
				f.name, f.type, f.parent, f.w, f.h, tostring(f.visible), tostring(f.hasOnClick),
				tostring(f.frameId), f.reason
			))
		end
	end

	if verbose then
		local icons = EnsureAddonButtonsDB()
		if icons then
			print("  Saved addon button keys:")
			for buttonID in pairs(icons) do
				print("    " .. buttonID)
			end
		end
	end

	return stats, questieFrames
end

local function EnsureCarboniteOnMinimap(button)
	if not button or not Minimap then
		return
	end
	if button:GetParent() ~= Minimap then
		button:SetParent(Minimap)
		button:SetFrameStrata("LOW")
		if Minimap.GetFrameLevel then
			button:SetFrameLevel(Minimap:GetFrameLevel() + 5)
		end
	end
end

local function InstallCarboniteMinimapHooks()
	if carboniteHooksInstalled then
		return
	end
	local Nx = _G.Nx
	if not Nx or not Nx.NXMiniMapBut then
		return
	end

	if Nx.NXMiniMapBut.Mov then
		local origMov = Nx.NXMiniMapBut.Mov
		Nx.NXMiniMapBut.Mov = function(self, x, y)
			local cfg = db and db.addonButtons and db.addonButtons.icons and db.addonButtons.icons.NXMiniMapBut
			if cfg and cfg.managed then
				return
			end
			return origMov(self, x, y)
		end
	end

	if Nx.NXMiniMapBut.Ini then
		local origIni = Nx.NXMiniMapBut.Ini
		Nx.NXMiniMapBut.Ini = function(self, ...)
			origIni(self, ...)
			if module.CaptureCarboniteMinimapButton then
				C_Timer.After(0, function()
					module:CaptureCarboniteMinimapButton()
				end)
			end
		end
	end

	if Nx.Map and Nx.Map.Doc and Nx.Map.Doc.MOI then
		local origMOI = Nx.Map.Doc.MOI
		Nx.Map.Doc.MOI = function(self, ...)
			origMOI(self, ...)
			if module.CaptureCarboniteMinimapButton then
				C_Timer.After(0, function()
					module:CaptureCarboniteMinimapButton()
				end)
			end
		end
	end

	carboniteHooksInstalled = true
end


local minimapPingHooked = false

local function Fix_MinimapPing()
	if minimapPingHooked or not MinimapPing or not MinimapPing.HookScript then
		return
	end
	minimapPingHooked = true
	MinimapPing:HookScript("OnUpdate", function(self, elapsed)
		if self.fadeOut or (self.timer or 0) > MINIMAPPING_FADE_TIMER then
			Minimap_SetPing(Minimap:GetPingPosition())
		end
	end)
end

-- Initialize module
function module:Initialize()
	db = self.addon.db.profile.modules[moduleName]
	if not db then return end

	EnsureAddonButtonsDB()

	-- migrate legacy group settings
	db.addonButtonsPosition = nil
	db.addonButtonsDirection = nil
	db.addonButtonsSpacing = nil
	db.addonButtonsScale = nil
	db.addonButtonsLayout = nil
	db.iconPositions = nil
	PurgeBlacklistedIconSettings()
end

-- Enable module
function module:Enable()
	-- Обновляем кэш детей миникарты при включении модуля
	RefreshMinimapChildrenCache()
	if not db or not db.enabled then return end
	
	StopMouseWatch() -- останавливаем наблюдение при включении модуля
	
	offsetX = GetSetting('offsetX', 0)
	offsetY = GetSetting('offsetY', 0)
	
	SetupMinimap()
	MoveMinimap()
	Fix_MinimapPing()

	if C_Timer and C_Timer.After then
		C_Timer.After(0.3, function()
			if module.ScanAddonMinimapButtons then
				module:ScanAddonMinimapButtons()
			end
		end)
	else
		self:ScanAddonMinimapButtons()
	end
	self:InstallCarboniteWorldMapButtonHook()
	self:ApplyWorldMapButtonVisibility()
	EnsureZoneRefreshListener()
	
	-- Регистрируем событие для позиционирования новых иконок
	local iconPositionFrame = CreateFrame("Frame")
	iconPositionFrame:RegisterEvent("ADDON_LOADED")
	iconPositionFrame:SetScript("OnEvent", function(self, event, addonName)
		if event == "ADDON_LOADED" then
			RefreshMinimapChildrenCache()
			C_Timer.After(0.5, function()
				module:ApplyAddonButtonLayout(true)
				if addonName == "Carbonite" and module.TryCaptureCarboniteMinimapButton then
					module:TryCaptureCarboniteMinimapButton()
				end
			end)
		end
	end)
	
	-- Также позиционируем иконки периодически для новых загруженных аддонов
	if iconTicker then module:CancelTimer(iconTicker); iconTicker = nil end
	iconTicker = module:ScheduleRepeatingTimer(function()
		if not db or not db.enabled then return end
		module:ApplyAddonButtonLayout(false)
		local btn = _G.NXMiniMapBut
		if btn and _G.SarychUI_IsCarboniteRuntimeEnabled and SarychUI_IsCarboniteRuntimeEnabled() then
			local icons = db.addonButtons and db.addonButtons.icons
			if not (icons and icons.NXMiniMapBut and btn.__SarychUIAutoHidePrepared) then
				module:CaptureCarboniteMinimapButton()
			end
		end
	end, 5)
	
	-- Register with Drag Mode system
    if SarychUI.DragMode and MinimapCluster then
        -- Register only once
        local alreadyRegistered = SarychUI.DragMode.GetFrameData and SarychUI.DragMode:GetFrameData("minimap") ~= nil
        if not alreadyRegistered then
            SarychUI.DragMode:RegisterFrame("minimap", MinimapCluster, {
            dragPoint = "TOPRIGHT",
			dragOffsetX = 0,
			dragOffsetY = 0,
			dragWidth = 200,
			dragHeight = 200,
			dragText = "Миникарта",
			scaleFrame = MinimapCluster,
			interceptSetPoint = true,
			getPoint = function()
                return {
                    GetSetting('minimapA', "TOPRIGHT"),
                    UIParent,
                    GetSetting('minimapR', "TOPRIGHT"),
                    GetSetting('minimapX', GetSetting('offsetX', 0)),
                    GetSetting('minimapY', GetSetting('offsetY', 0))
                }
			end,
			getScale = function()
				return 1.0
			end,
			onPositionChanged = function(point, relativePoint, xOfs, yOfs)
                local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
                if panel and panel.IsOpen and panel:IsOpen() and panel.OnDragPosition then
                    if panel:OnDragPosition("minimap", xOfs, yOfs, point, relativePoint) then
                        return
                    end
                end
                SarychUI.db.profile.modules[moduleName].minimapA = point
                SarychUI.db.profile.modules[moduleName].minimapR = relativePoint
                SarychUI.db.profile.modules[moduleName].minimapX = xOfs
                SarychUI.db.profile.modules[moduleName].minimapY = yOfs
                -- Keep legacy offsets in sync for slider UI
                SarychUI.db.profile.modules[moduleName].offsetX = xOfs
                SarychUI.db.profile.modules[moduleName].offsetY = yOfs
                -- Update saved custom position
                SarychUI.db.profile.modules[moduleName].minimapSavedA = point
                SarychUI.db.profile.modules[moduleName].minimapSavedR = relativePoint
                SarychUI.db.profile.modules[moduleName].minimapSavedX = xOfs
                SarychUI.db.profile.modules[moduleName].minimapSavedY = yOfs
				MoveMinimap()
			end
            })
        end
		-- Apply edit mode state from settings
		local enabled = GetSetting('positioningEnabled', 0) == 1
		local showDragFrame = GetSetting('showDragFrame', 0) == 1
		local showGrid = GetSetting('showGrid', 0) == 1
		SarychUI.DragMode:EnableEditMode("minimap", enabled, showDragFrame, showGrid)
		SarychUI.DragMode:ShowGrid(showGrid and enabled)
	end
	
	-- Delayed calendar initialization
	if not GameTimeFrame then
		-- Wait for GameTimeFrame to be created
		local frame = CreateFrame("Frame")
		frame:RegisterEvent("ADDON_LOADED")
		frame:SetScript("OnEvent", function(self, event, addonName)
			if addonName == "Blizzard_Calendar" or GameTimeFrame then
				ApplyCalendarSettings()
				self:UnregisterEvent("ADDON_LOADED")
				self:SetScript("OnEvent", nil)
			end
		end)
	else
		ApplyCalendarSettings()
	end
end

-- Disable module
function module:Disable()
	StopMouseWatch()
	StopZoneRefreshListener()
	isAnimatingShow = false
	areButtonsVisible = false
	self:ReleaseCarboniteMinimapButton()
	if iconTicker then module:CancelTimer(iconTicker); iconTicker = nil end
	if worldMapButtonReapplyTimer then module:CancelTimer(worldMapButtonReapplyTimer); worldMapButtonReapplyTimer = nil end
	
	-- Restore defaults
	MinimapBorderTop:Show()
	MinimapZoomIn:Show()
	MinimapZoomOut:Show()
	if MiniMapWorldMapButton then
		if originalMiniMapWorldMapButtonShow then
			MiniMapWorldMapButton.Show = originalMiniMapWorldMapButtonShow
		else
			MiniMapWorldMapButton.Show = nil
		end
		MiniMapWorldMapButton:Show()
	end
	
	if TimeManagerClockButton then
		if originalTimeManagerClockButtonShow then
			TimeManagerClockButton.Show = originalTimeManagerClockButtonShow
		else
			TimeManagerClockButton.Show = nil
		end
		TimeManagerClockButton:Show()
	end
	
	MinimapZoneText:ClearAllPoints()
	MinimapZoneText:SetPoint("TOPLEFT", "MinimapZoneTextButton", "TOPLEFT", 0, 0)
	
	if originalMiniMapTrackingShow then
		MiniMapTracking.Show = originalMiniMapTrackingShow
	else
		MiniMapTracking.Show = nil
	end
	MiniMapTracking:Show()
	
	if GameTimeFrame then
		if originalGameTimeFrameShow then
			GameTimeFrame.Show = originalGameTimeFrameShow
		else
			GameTimeFrame.Show = nil
		end
		GameTimeFrame:Show()
	end
	
	Minimap:EnableMouseWheel(false)
	Minimap:SetScript("OnMouseWheel", nil)
	Minimap:SetScript("OnMouseUp", Minimap_OnClick)
	
	for _, button in ipairs(GetManagedButtons()) do
		EnableMinimapButton(button)
	end
	
	-- Restore to our defined defaults
    ResetMinimapToDefaults()
	-- Extra safeguard: do a delayed reset to win races with Blizzard layout
	if C_Timer and C_Timer.After then
		C_Timer.After(0, ResetMinimapToDefaults)
		C_Timer.After(0.1, ResetMinimapToDefaults)
	end
	
	-- Unregister from Drag Mode system
    if SarychUI.DragMode then
        -- Ensure edit mode and grid are disabled before unregistering
        SarychUI.DragMode:EnableEditMode("minimap", false, false, false)
        SarychUI.DragMode:ShowGrid(false)
        SarychUI.DragMode:UnregisterFrame("minimap")
	end
end

-- Refresh configuration
function module:RefreshConfig()
	db = self.addon.db.profile.modules[moduleName]
	self:Disable()
	self:Enable()
	
	-- Force calendar update after refresh
	if db and db.enabled then
		ApplyCalendarSettings()
	end
end

-- Apply settings (for options UI)
function module:ApplySettings()
	if not db or not db.enabled then return end
	StopMouseWatch() -- останавливаем наблюдение при применении настроек
	SetupMinimap()
    MoveMinimap()
	
	-- Позиционирование иконок аддонов (настройки — немедленно, с force)
	layoutPending = false
	layoutForcePending = false
	ApplyAddonButtonLayoutNow(true)
	if _G.NXMiniMapBut and _G.SarychUI_IsCarboniteRuntimeEnabled and SarychUI_IsCarboniteRuntimeEnabled() then
		self:CaptureCarboniteMinimapButton()
	end
	ApplyCalendarSettings()
    if SarychUI.DragMode then
		local enabled = GetSetting('positioningEnabled', 0) == 1
		local showDragFrame = GetSetting('showDragFrame', 0) == 1
		local showGrid = GetSetting('showGrid', 0) == 1
        if enabled then
            -- Ensure frame is registered (Enable() registers it)
            -- If there is a saved custom position and current is missing, restore it
            if (db.minimapA == nil or db.minimapR == nil or db.minimapX == nil or db.minimapY == nil)
                and db.minimapSavedA and db.minimapSavedR and db.minimapSavedX ~= nil and db.minimapSavedY ~= nil then
                db.minimapA = db.minimapSavedA
                db.minimapR = db.minimapSavedR
                db.minimapX = db.minimapSavedX
                db.minimapY = db.minimapSavedY
                db.offsetX = db.minimapSavedX
                db.offsetY = db.minimapSavedY
            end
            SarychUI.DragMode:EnableEditMode("minimap", true, showDragFrame, showGrid)
            SarychUI.DragMode:SetFramePosition("minimap",
                GetSetting('minimapA', "TOPRIGHT"),
                GetSetting('minimapR', "TOPRIGHT"),
                GetSetting('minimapX', GetSetting('offsetX', 0)),
                GetSetting('minimapY', GetSetting('offsetY', 0)))
            SarychUI.DragMode:ShowGrid(showGrid)
        else
            -- Disable edit mode; keep registration to avoid lifecycle churn
            SarychUI.DragMode:EnableEditMode("minimap", false, false, false)
            SarychUI.DragMode:ShowGrid(false)
            -- Unregister so intercepts don't block Blizzard manager
            if SarychUI.DragMode.GetFrameData and SarychUI.DragMode:GetFrameData("minimap") then
                SarychUI.DragMode:UnregisterFrame("minimap")
            end
            -- Before resetting to defaults, preserve current custom position
            SaveCurrentCustomPosition()
            -- Restore to our defined defaults immediately
            ResetMinimapToDefaults()
        end
	end
end

function module:CaptureCarboniteMinimapButton()
	if not db or not db.enabled then
		return false
	end
	if not (_G.SarychUI_IsCarboniteRuntimeEnabled and SarychUI_IsCarboniteRuntimeEnabled()) then
		return false
	end

	local btn = _G.NXMiniMapBut
	if not btn then
		DebugMinimapButtons("Carbonite button not found, retry")
		return false
	end

	DebugMinimapButtons("Carbonite button found, registered in managed group")

	local Nx = _G.Nx
	local cfg = GetButtonSettings("NXMiniMapBut")
	if cfg and cfg.managed and Nx and Nx.GGO then
		local opt = Nx:GGO()
		if opt and opt["MapMMButOwn"] then
			opt["MapMMButOwn"] = false
		end
	end

	InstallCarboniteMinimapHooks()
	if cfg and cfg.managed then
		EnsureCarboniteOnMinimap(btn)
	end

	local cfg = GetButtonSettings("NXMiniMapBut")
	if cfg and cfg.managed then
		if btn.NXDrag then
			btn.NXDrag = false
		end
		DebugMinimapButtons("Carbonite drag disabled")
	end

	RefreshMinimapChildrenCache()
	ApplySingleButtonLayout("NXMiniMapBut", btn, true)
	RebuildManagedButtonsList()
	if mouseWatchHooksInstalled then
		InstallButtonMouseHooks()
	end
	DebugMinimapButtons("Carbonite position applied")
	return true
end

function module:TryCaptureCarboniteMinimapButton(retries, delay)
	retries = retries or 12
	delay = delay or 0.5

	if carboniteCaptureTimer then
		self:CancelTimer(carboniteCaptureTimer)
		carboniteCaptureTimer = nil
	end

	local attempt = 0
	local function tryCapture()
		attempt = attempt + 1
		if self:CaptureCarboniteMinimapButton() then
			return
		end
		if attempt < retries and _G.SarychUI_IsCarboniteRuntimeEnabled and SarychUI_IsCarboniteRuntimeEnabled() then
			DebugMinimapButtons("Carbonite button not found, retry")
			carboniteCaptureTimer = self:ScheduleTimer(tryCapture, delay)
		end
	end

	tryCapture()
end

function module:ReleaseCarboniteMinimapButton()
	if carboniteCaptureTimer then
		self:CancelTimer(carboniteCaptureTimer)
		carboniteCaptureTimer = nil
	end
end

-- Вызывается аддонами с собственной кнопкой миникарты (не LibDBIcon), после создания фрейма
function module:SyncAddonMinimapIcons()
	if not db or not db.enabled then return end
	RefreshMinimapChildrenCache()
	self:ApplyAddonButtonLayout(true)
	if _G.NXMiniMapBut and _G.SarychUI_IsCarboniteRuntimeEnabled and SarychUI_IsCarboniteRuntimeEnabled() then
		self:CaptureCarboniteMinimapButton()
	end
end

-- Принудительное применение layout одной кнопки (из options UI)
function module:OnAddonButtonSettingChanged(buttonID, field, value)
	if not db or not db.enabled then
		return
	end

	DebugLayout(string.format(
		"setting changed id=%s field=%s value=%s",
		self:GetButtonDisplayName(buttonID), tostring(field), tostring(value)
	))

	layoutPending = false
	layoutForcePending = false
	ApplySingleButtonLayout(buttonID, nil, true)

	if field == "managed" or field == "shown" then
		RebuildManagedButtonsList()
		if mouseWatchHooksInstalled then
			InstallButtonMouseHooks()
		end
	end

	if buttonID == "NXMiniMapBut" and _G.SarychUI_IsCarboniteRuntimeEnabled and SarychUI_IsCarboniteRuntimeEnabled() then
		self:CaptureCarboniteMinimapButton()
	end
end

-- Состояние видимости как у остальных иконок (автоскрытие по клику на миникарту)
function module:ApplyInitialStateToAddonMinimapButton(btn)
	if not db or not db.enabled or not btn then return end
	local buttonID = btn:GetName()
	if not buttonID then return end
	ApplySingleButtonLayout(buttonID, btn, true)
end
