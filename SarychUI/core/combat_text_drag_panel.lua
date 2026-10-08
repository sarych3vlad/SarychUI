-- SarychUI Position Drag Panel
-- Mini floating editor for free-move (combat text, frames, minimap, auras).

SarychUI = SarychUI or {}
SarychUI.PositionDragPanel = SarychUI.PositionDragPanel or {}
local Panel = SarychUI.PositionDragPanel
-- Back-compat alias used by floating_text / tools.
SarychUI.CombatTextDragPanel = Panel

local CreateFrame = CreateFrame
local UIParent = UIParent
local tonumber = tonumber
local floor = math.floor
local pairs = pairs

local FRAME_MAP = {
	-- Floating text (combat)
	combatTextPlus = {
		title = "+ Текст боя",
		moduleKey = "floating_text",
		xKey = "healPlusX",
		yKey = "healPlusY",
		dragFlag = "combatTextPlusDrag",
		defaultX = -467,
		defaultY = -45,
		min = -1000,
		max = 1000,
		point = "CENTER",
		relativePoint = "CENTER",
		onApply = function()
			local tools = SarychUI and SarychUI.modules and SarychUI.modules.tools
			if tools and tools.ApplyCombatTextAdjust then
				tools:ApplyCombatTextAdjust()
			end
		end,
		notifyPreview = function(xKey, yKey, x, y)
			local preview = SarychUI and SarychUI.CombatTextPreview
			if not preview then return end
			if preview.SetLiveValue then
				if xKey then preview:SetLiveValue(xKey, x) end
				if yKey then preview:SetLiveValue(yKey, y) end
			elseif preview.RefreshAll then
				preview:RefreshAll()
			end
		end,
		clearPreview = function(xKey, yKey)
			local preview = SarychUI and SarychUI.CombatTextPreview
			if not preview then return end
			if preview.ClearLiveValue then
				if xKey then preview:ClearLiveValue(xKey) end
				if yKey then preview:ClearLiveValue(yKey) end
			end
			if preview.RefreshAll then preview:RefreshAll() end
		end,
	},
	combatTextMinus = {
		title = "- Текст боя",
		moduleKey = "floating_text",
		xKey = "healMinusX",
		yKey = "healMinusY",
		dragFlag = "combatTextMinusDrag",
		defaultX = 0,
		defaultY = -50,
		min = -1000,
		max = 1000,
		point = "CENTER",
		relativePoint = "CENTER",
		onApply = function()
			local tools = SarychUI and SarychUI.modules and SarychUI.modules.tools
			if tools and tools.ApplyCombatTextAdjust then
				tools:ApplyCombatTextAdjust()
			end
		end,
		notifyPreview = function(xKey, yKey, x, y)
			local preview = SarychUI and SarychUI.CombatTextPreview
			if not preview then return end
			if preview.SetLiveValue then
				if xKey then preview:SetLiveValue(xKey, x) end
				if yKey then preview:SetLiveValue(yKey, y) end
			elseif preview.RefreshAll then
				preview:RefreshAll()
			end
		end,
		clearPreview = function(xKey, yKey)
			local preview = SarychUI and SarychUI.CombatTextPreview
			if not preview then return end
			if preview.ClearLiveValue then
				if xKey then preview:ClearLiveValue(xKey) end
				if yKey then preview:ClearLiveValue(yKey) end
			end
			if preview.RefreshAll then preview:RefreshAll() end
		end,
	},
	combatTextLess = {
		title = "< Текст боя",
		moduleKey = "floating_text",
		xKey = "healLessX",
		yKey = "healLessY",
		dragFlag = "combatTextLessDrag",
		defaultX = -250,
		defaultY = -30,
		min = -1000,
		max = 1000,
		point = "CENTER",
		relativePoint = "CENTER",
		onApply = function()
			local tools = SarychUI and SarychUI.modules and SarychUI.modules.tools
			if tools and tools.ApplyCombatTextAdjust then
				tools:ApplyCombatTextAdjust()
			end
		end,
		notifyPreview = function(xKey, yKey, x, y)
			local preview = SarychUI and SarychUI.CombatTextPreview
			if not preview then return end
			if preview.SetLiveValue then
				if xKey then preview:SetLiveValue(xKey, x) end
				if yKey then preview:SetLiveValue(yKey, y) end
			elseif preview.RefreshAll then
				preview:RefreshAll()
			end
		end,
		clearPreview = function(xKey, yKey)
			local preview = SarychUI and SarychUI.CombatTextPreview
			if not preview then return end
			if preview.ClearLiveValue then
				if xKey then preview:ClearLiveValue(xKey) end
				if yKey then preview:ClearLiveValue(yKey) end
			end
			if preview.RefreshAll then preview:RefreshAll() end
		end,
	},

	-- Frames
	playerFrame = {
		title = "Фрейм игрока",
		moduleKey = "frame",
		xKey = "playerFrameX",
		yKey = "playerFrameY",
		dragFlag = "showPlayerDragFrame",
		defaultX = -514,
		defaultY = 200,
		min = -2000,
		max = 2000,
		point = "CENTER",
		relativePoint = "CENTER",
		onApply = function()
			local m = SarychUI and SarychUI:GetModule("frame", true)
			if m and m.ApplySettings then m:ApplySettings() end
		end,
	},
	targetFrame = {
		title = "Фрейм цели",
		moduleKey = "frame",
		xKey = "targetFrameX",
		yKey = "targetFrameY",
		dragFlag = "showTargetDragFrame",
		defaultX = -240,
		defaultY = 200,
		min = -2000,
		max = 2000,
		point = "CENTER",
		relativePoint = "CENTER",
		onApply = function()
			local m = SarychUI and SarychUI:GetModule("frame", true)
			if m and m.ApplySettings then m:ApplySettings() end
		end,
	},
	focusFrame = {
		title = "Фрейм фокуса",
		moduleKey = "frame",
		xKey = "focusFrameX",
		yKey = "focusFrameY",
		dragFlag = "showFocusDragFrame",
		defaultX = 350,
		defaultY = -150,
		min = -2000,
		max = 2000,
		point = "CENTER",
		relativePoint = "CENTER",
		onApply = function()
			local m = SarychUI and SarychUI:GetModule("frame", true)
			if m and m.ApplySettings then m:ApplySettings() end
		end,
	},

	-- Minimap
	minimap = {
		title = "Миникарта",
		moduleKey = "minimap",
		xKey = "offsetX",
		yKey = "offsetY",
		aKey = "minimapA",
		rKey = "minimapR",
		alsoX = { "minimapX", "minimapSavedX" },
		alsoY = { "minimapY", "minimapSavedY" },
		alsoA = { "minimapSavedA" },
		alsoR = { "minimapSavedR" },
		dragFlag = "showDragFrame",
		defaultX = -5,
		defaultY = -5,
		defaultA = "TOPRIGHT",
		defaultR = "TOPRIGHT",
		min = -500,
		max = 500,
		point = "TOPRIGHT",
		relativePoint = "TOPRIGHT",
		onApply = function()
			local m = SarychUI and SarychUI:GetModule("minimap", true)
			if m and m.ApplySettings then m:ApplySettings() end
		end,
	},

	-- Auras (player buffs)
	buffFrame = {
		title = "Ауры персонажа",
		moduleKey = "auras",
		xKey = "buffFrameX",
		yKey = "buffFrameY",
		aKey = "buffFrameA",
		rKey = "buffFrameR",
		dragFlag = "showBuffDragFrame",
		gridFlag = "showBuffGrid",
		defaultX = -205,
		defaultY = -13,
		defaultA = "TOPRIGHT",
		defaultR = "TOPRIGHT",
		min = -2000,
		max = 2000,
		point = "TOPRIGHT",
		relativePoint = "TOPRIGHT",
		onApply = function()
			local m = SarychUI and SarychUI:GetModule("auras", true)
			if m and m.ApplyBuffManagement then m:ApplyBuffManagement() end
		end,
	},

	-- Player resources (nested module DB: plate / runes / …)
	playerPlate = {
		title = "Панель игрока",
		moduleKey = "player_resources",
		subKey = "plate",
		xKey = "x",
		yKey = "y",
		aKey = "point",
		rKey = "relativePoint",
		dragFlag = "showDragFrame",
		gridFlag = "showGrid",
		alwaysPosition = true,
		defaultX = 0,
		defaultY = -120,
		defaultA = "CENTER",
		defaultR = "CENTER",
		min = -800,
		max = 800,
		onApply = function()
			local m = SarychUI and SarychUI.modules and SarychUI.modules.player_resources
			if m and m.RefreshPlate then m:RefreshPlate() end
		end,
	},
	playerShield = {
		title = "Индикатор щита",
		moduleKey = "player_resources",
		subKey = "shield",
		xKey = "x",
		yKey = "y",
		aKey = "point",
		rKey = "relativePoint",
		dragFlag = "showDragFrame",
		gridFlag = "showGrid",
		requireEnabled = "enabled",
		alwaysPosition = true,
		defaultX = -98,
		defaultY = -120,
		defaultA = "CENTER",
		defaultR = "CENTER",
		min = -800,
		max = 800,
		onApply = function()
			local m = SarychUI and SarychUI.modules and SarychUI.modules.player_resources
			if m and m.RefreshShield then m:RefreshShield() end
		end,
	},
	playerRunes = {
		title = "Руны",
		moduleKey = "player_resources",
		subKey = "runes",
		xKey = "x",
		yKey = "y",
		aKey = "point",
		rKey = "relativePoint",
		dragFlag = "showDragFrame",
		gridFlag = "showGrid",
		requireEnabled = "enabled",
		alwaysPosition = true,
		defaultX = 0,
		defaultY = -294,
		defaultA = "CENTER",
		defaultR = "CENTER",
		min = -800,
		max = 800,
		onApply = function()
			local m = SarychUI and SarychUI.modules and SarychUI.modules.player_resources
			if m and m.RefreshRunes then m:RefreshRunes() end
		end,
	},
	playerTotems = {
		title = "Тотемы",
		moduleKey = "player_resources",
		subKey = "totems",
		xKey = "x",
		yKey = "y",
		aKey = "point",
		rKey = "relativePoint",
		dragFlag = "showDragFrame",
		gridFlag = "showGrid",
		requireEnabled = "enabled",
		alwaysPosition = true,
		defaultX = 0,
		defaultY = -294,
		defaultA = "CENTER",
		defaultR = "CENTER",
		min = -800,
		max = 800,
		onApply = function()
			local m = SarychUI and SarychUI.modules and SarychUI.modules.player_resources
			if m and m.RefreshTotems then m:RefreshTotems() end
		end,
	},
	-- Quest tracker (tools / Dragonflight layout)
	questTracker = {
		title = "Трекер заданий",
		moduleKey = "tools",
		xKey = "questTrackerX",
		yKey = "questTrackerY",
		dragFlag = "questTrackerShowDragFrame",
		gridFlag = "questTrackerShowGrid",
		defaultX = 0,
		defaultY = -260,
		min = -600,
		max = 0,
		point = "TOPRIGHT",
		relativePoint = "TOPRIGHT",
		-- DB stores no-bars base; frame uses base - CONTAINER_OFFSET_X.
		resolveFramePosition = function(x, y)
			local barX = tonumber(CONTAINER_OFFSET_X) or 0
			return (tonumber(x) or 0) - barX, tonumber(y) or -260
		end,
		onApply = function()
			if _G.SarychUI_QuestTracker and _G.SarychUI_QuestTracker.Refresh then
				_G.SarychUI_QuestTracker.Refresh()
			else
				local m = SarychUI and (SarychUI:GetModule("tools", true) or (SarychUI.modules and SarychUI.modules.tools))
				if m and m.RefreshQuestTracker then
					m:RefreshQuestTracker()
				end
			end
		end,
	},
}

-- FrostAtomUI action bars (mainmenubar module, barMode = "frostatom").
-- Config: modules.mainmenubar.frostatom.<key> (extra bars: .extraBars.barN).
do
	local FA_KEYS = {
		{ "bar1", "frostatom.bar1", "BOTTOM", 0, 32 },
		{ "bar2", "frostatom.bar2", "BOTTOM", 0, 216 },
		{ "bar3", "frostatom.bar3", "BOTTOM", 0, 260 },
		{ "bar4", "frostatom.bar4", "BOTTOM", 0, 304 },
		{ "bar5", "frostatom.bar5", "BOTTOM", 0, 120 },
		{ "bar6", "frostatom.bar6", "RIGHT", -662, -424 },
		{ "bar7", "frostatom.extraBars.bar7", "CENTER", 0, 0 },
		{ "bar8", "frostatom.extraBars.bar8", "CENTER", 0, -40 },
		{ "bar9", "frostatom.extraBars.bar9", "CENTER", 0, -80 },
		{ "bar10", "frostatom.extraBars.bar10", "CENTER", 0, -120 },
		{ "stance", "frostatom.stance", "BOTTOMLEFT", -230, 166, "BOTTOM" },
		{ "pet", "frostatom.pet", "BOTTOM", 68, 116 },
		{ "totemBar", "frostatom.totemBar", "BOTTOM", -150, 154 },
		{ "vehicleExit", "frostatom.vehicleExit", "BOTTOM", 250, 116 },
		{ "microMenu", "frostatom.microMenu", "BOTTOMRIGHT", -45, 3 },
		{ "bagButton", "frostatom.bagButton", "BOTTOMRIGHT", -10, 5 },
	}
	local FA_TITLES = {
		bar1 = "Панель команд 1", bar2 = "Панель команд 2", bar3 = "Панель команд 3",
		bar4 = "Панель команд 4", bar5 = "Панель команд 5", bar6 = "Панель команд 6",
		bar7 = "Панель команд 7", bar8 = "Панель команд 8", bar9 = "Панель команд 9",
		bar10 = "Панель команд 10",
		stance = "Панель стоек", pet = "Панель питомца", totemBar = "Панель тотемов",
		vehicleExit = "Выход из транспорта", microMenu = "Микроменю", bagButton = "Кнопка сумки",
	}
	for _, def in ipairs(FA_KEYS) do
		local key, subKey, point, dx, dy, relPoint = def[1], def[2], def[3], def[4], def[5], def[6]
		FRAME_MAP["faBar_" .. key] = {
			title = FA_TITLES[key] or key,
			moduleKey = "mainmenubar",
			subKey = subKey,
			xKey = "x",
			yKey = "y",
			aKey = "point",
			rKey = "relativePoint",
			dragFlag = "showDragFrame",
			gridFlag = "showGrid",
			alwaysPosition = true,
			defaultX = dx,
			defaultY = dy,
			defaultA = point,
			defaultR = relPoint or point,
			min = -1600,
			max = 1600,
			onApply = function()
				local FA = SarychUI and SarychUI.FrostAtomBars
				if FA and FA.Refresh then
					FA.Refresh(key)
				end
			end,
		}
	end
	FRAME_MAP["faBar_playerCastbar"] = {
		title = "Полоса каста",
		moduleKey = "mainmenubar",
		subKey = "frostatom.playerCastbar",
		xKey = "x",
		yKey = "y",
		aKey = "point",
		rKey = "relativePoint",
		dragFlag = "showDragFrame",
		gridFlag = "showGrid",
		alwaysPosition = true,
		defaultX = 0,
		defaultY = 0,
		defaultA = "BOTTOM",
		defaultR = "BOTTOM",
		min = -1600,
		max = 1600,
		point = "BOTTOM",
		relativePoint = "BOTTOM",
		resolveFramePosition = function(x, y)
			local FA = SarychUI and SarychUI.FrostAtomBars
			local dx, dy = 0, 95
			if FA and FA.GetPlayerCastbarDefault then
				dx, dy = FA.GetPlayerCastbarDefault()
			end
			return (tonumber(x) or 0) + dx, (tonumber(y) or 0) + dy
		end,
		fromFramePosition = function(x, y)
			local FA = SarychUI and SarychUI.FrostAtomBars
			local dx, dy = 0, 95
			if FA and FA.GetPlayerCastbarDefault then
				dx, dy = FA.GetPlayerCastbarDefault()
			end
			return (tonumber(x) or 0) - dx, (tonumber(y) or 0) - dy
		end,
		onApply = function()
			local FA = SarychUI and SarychUI.FrostAtomBars
			if FA and FA.Refresh then
				FA.Refresh("playerCastbar")
			end
		end,
	}
end

local session = nil -- { frameId, snapshot, draft, gridWasOn }

local function ModuleDB(moduleKey)
	local mods = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return mods and mods[moduleKey]
end

local function ConfigDB(meta)
	local db = meta and ModuleDB(meta.moduleKey)
	if not db then
		return nil
	end
	if meta.subKey then
		-- Dotted sub keys walk nested tables ("frostatom.extraBars.bar7").
		local t = db
		for part in string.gmatch(meta.subKey, "[^%.]+") do
			t = t and t[part]
			if type(t) ~= "table" then
				return nil
			end
		end
		return t
	end
	return db
end

local function Clamp(v, lo, hi)
	v = tonumber(v) or 0
	if v < lo then return lo end
	if v > hi then return hi end
	return floor(v + 0.5)
end

local function ApplyTheme(frame, bg, border)
	local T = SarychUI and SarychUI.OptionsTheme
	if T and T.ApplyFlat then
		T:ApplyFlat(frame, bg or T.colors.panelBg, border or T.colors.border)
		return
	end
	if not frame.SetBackdrop then return end
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		tile = false,
		edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 },
	})
	bg = bg or { 0.09, 0.09, 0.10, 0.97 }
	border = border or { 0.32, 0.32, 0.35, 1 }
	frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
	frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
end

local function SoftRefreshOptions()
	if not (SarychUI and SarychUI.OptionsCore and SarychUI.OptionsCore._open) then
		return
	end
	if SarychUI.IsOptionsInteractBusy and SarychUI.IsOptionsInteractBusy() then
		SarychUI._pendingOptionsRefresh = true
		return
	end
	-- Prefer lightweight value sync so drag doesn't rebuild the whole /sui page.
	if SarychUI.SyncOpenOptionsValues then
		SarychUI:SyncOpenOptionsValues()
		return
	end
	if SarychUI.OptionsCore.Refresh then
		SarychUI.OptionsCore:Refresh()
	end
end

local function SetAnchorPosition(frameId, meta, x, y, point, relativePoint)
	if not (SarychUI and SarychUI.DragMode and SarychUI.DragMode.SetFramePosition) then
		return
	end
	point = point or meta.point or "CENTER"
	relativePoint = relativePoint or meta.relativePoint or point
	if meta.resolveFramePosition then
		x, y = meta.resolveFramePosition(x, y)
	end
	SarychUI.DragMode:SetFramePosition(frameId, point, relativePoint, x, y)
end

local function NotifyPreview(meta, x, y)
	if meta and meta.notifyPreview then
		meta.notifyPreview(meta.xKey, meta.yKey, x, y)
	end
end

local function ClearPreview(meta)
	if meta and meta.clearPreview then
		meta.clearPreview(meta.xKey, meta.yKey)
	end
end

local function AnyOtherDragActive(exceptId)
	for id, meta in pairs(FRAME_MAP) do
		if id ~= exceptId and meta.dragFlag and meta.moduleKey then
			local db = ConfigDB(meta)
			local flag = db and db[meta.dragFlag]
			if flag == 1 or flag == true then
				return true
			end
		end
	end
	return false
end

local function WriteDraftToDB(meta, draft, commitGrid)
	local db = ConfigDB(meta)
	if not db then return end
	db[meta.xKey] = draft.x
	db[meta.yKey] = draft.y
	if meta.aKey then
		db[meta.aKey] = draft.point or meta.defaultA or meta.point
	end
	if meta.rKey then
		db[meta.rKey] = draft.relativePoint or meta.defaultR or meta.relativePoint
	end
	if meta.alsoX then
		for i = 1, #meta.alsoX do
			db[meta.alsoX[i]] = draft.x
		end
	end
	if meta.alsoY then
		for i = 1, #meta.alsoY do
			db[meta.alsoY[i]] = draft.y
		end
	end
	if meta.alsoA and draft.point then
		for i = 1, #meta.alsoA do
			db[meta.alsoA[i]] = draft.point
		end
	end
	if meta.alsoR and draft.relativePoint then
		for i = 1, #meta.alsoR do
			db[meta.alsoR[i]] = draft.relativePoint
		end
	end
	if commitGrid and meta.gridFlag then
		-- leave grid flag as-is; cleared on close
	end
end

local function LiveSyncDraftToOptions(meta, draft)
	if not meta or not draft then
		return
	end
	WriteDraftToDB(meta, draft)
	if SarychUI and SarychUI.SyncOpenOptionsValues then
		SarychUI:SyncOpenOptionsValues()
	else
		SoftRefreshOptions()
	end
end

--------------------------------------------------------------------
-- UI
--------------------------------------------------------------------
local root

local function RaisePanel(f)
	if not f then return end
	f:SetFrameStrata("TOOLTIP")
	f:SetFrameLevel(500)
	f:SetToplevel(true)
	if f.Raise then f:Raise() end
end

local function EnsureUI()
	if root then
		RaisePanel(root)
		return root
	end

	local f = CreateFrame("Frame", "SarychUI_PositionDragPanel", UIParent)
	f:SetSize(260, 196)
	f:SetPoint("TOP", UIParent, "TOP", 0, -80)
	RaisePanel(f)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) self:StartMoving() end)
	f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	f:SetScript("OnShow", function(self) RaisePanel(self) end)
	f:Hide()
	ApplyTheme(f)

	local close = CreateFrame("Button", nil, f)
	close:SetSize(22, 22)
	close:SetPoint("TOPRIGHT", -8, -8)
	ApplyTheme(close, { 0.16, 0.16, 0.18, 1 }, { 0.24, 0.24, 0.26, 1 })
	local closeFs = close:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	closeFs:SetPoint("CENTER", 1, 0)
	closeFs:SetText("X")
	close:SetScript("OnEnter", function(self)
		ApplyTheme(self, { 0.22, 0.22, 0.25, 1 }, { 0.95, 0.78, 0.15, 1 })
	end)
	close:SetScript("OnLeave", function(self)
		ApplyTheme(self, { 0.16, 0.16, 0.18, 1 }, { 0.24, 0.24, 0.26, 1 })
	end)
	f.closeBtn = close

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 10, -10)
	title:SetPoint("RIGHT", close, "LEFT", -6, 0)
	title:SetJustifyH("LEFT")
	title:SetText("Позиция")
	f.title = title

	local function MakeSlider(width, lo, hi, step)
		local slider = CreateFrame("Slider", nil, f)
		slider:SetSize(width, 16)
		slider:SetOrientation("HORIZONTAL")
		slider:SetMinMaxValues(lo, hi)
		slider:SetValueStep(step)
		local thumb = slider:CreateTexture(nil, "OVERLAY")
		thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
		thumb:SetSize(8, 14)
		thumb:SetVertexColor(0.95, 0.82, 0.20, 1)
		slider:SetThumbTexture(thumb)
		slider.thumb = thumb
		local track = slider:CreateTexture(nil, "BACKGROUND")
		track:SetTexture("Interface\\Buttons\\WHITE8X8")
		track:SetHeight(3)
		track:SetPoint("LEFT", slider, "LEFT", 0, 0)
		track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
		track:SetVertexColor(0.28, 0.28, 0.32, 1)
		return slider
	end

	local function MakeRow(labelText, y)
		local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		label:SetPoint("TOPLEFT", 10, y)
		label:SetWidth(18)
		label:SetJustifyH("LEFT")
		label:SetText(labelText)

		local edit = CreateFrame("EditBox", nil, f)
		edit:SetSize(70, 20)
		edit:SetPoint("LEFT", label, "RIGHT", 6, 0)
		edit:SetAutoFocus(false)
		edit:SetFontObject(GameFontHighlightSmall)
		edit:SetTextInsets(4, 4, 0, 0)
		edit:SetNumeric(false)
		ApplyTheme(edit, { 0.06, 0.06, 0.07, 1 }, { 0.24, 0.24, 0.26, 1 })

		local slider = MakeSlider(130, -2000, 2000, 1)
		slider:SetPoint("LEFT", edit, "RIGHT", 8, 0)

		return label, edit, slider
	end

	local _, xEdit, xSlider = MakeRow("X", -34)
	local _, yEdit, ySlider = MakeRow("Y", -60)
	f.xEdit, f.xSlider = xEdit, xSlider
	f.yEdit, f.ySlider = yEdit, ySlider

	local gridBtn = CreateFrame("Button", nil, f)
	gridBtn:SetSize(16, 16)
	gridBtn:SetPoint("TOPLEFT", 10, -90)
	ApplyTheme(gridBtn, { 0.06, 0.06, 0.07, 1 }, { 0.32, 0.32, 0.35, 1 })
	local check = gridBtn:CreateTexture(nil, "OVERLAY")
	check:SetTexture("Interface\\Buttons\\WHITE8X8")
	check:SetPoint("TOPLEFT", 3, -3)
	check:SetPoint("BOTTOMRIGHT", -3, 3)
	check:SetVertexColor(0.95, 0.82, 0.20, 1)
	check:Hide()
	gridBtn.check = check

	local gridLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	gridLabel:SetPoint("LEFT", gridBtn, "RIGHT", 6, 0)
	gridLabel:SetText("Сетка выравнивания")
	f.gridBtn = gridBtn

	-- Шаг сетки (общая настройка SarychUI.DragMode, как в FrostAtomUI).
	local gridLo, gridHi, gridStep = 8, 128, 4
	if SarychUI.DragMode and SarychUI.DragMode.GetGridSizeRange then
		gridLo, gridHi, gridStep = SarychUI.DragMode:GetGridSizeRange()
	end

	local stepLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	stepLabel:SetPoint("TOPLEFT", 10, -116)
	stepLabel:SetJustifyH("LEFT")
	stepLabel:SetText("Шаг сетки")

	local stepEdit = CreateFrame("EditBox", nil, f)
	stepEdit:SetSize(40, 20)
	stepEdit:SetPoint("LEFT", stepLabel, "RIGHT", 6, 0)
	stepEdit:SetAutoFocus(false)
	stepEdit:SetFontObject(GameFontHighlightSmall)
	stepEdit:SetTextInsets(4, 4, 0, 0)
	stepEdit:SetNumeric(true)
	stepEdit:SetMaxLetters(3)
	ApplyTheme(stepEdit, { 0.06, 0.06, 0.07, 1 }, { 0.24, 0.24, 0.26, 1 })

	local stepSlider = MakeSlider(100, gridLo, gridHi, gridStep)
	stepSlider:SetPoint("LEFT", stepEdit, "RIGHT", 8, 0)
	stepSlider:SetPoint("RIGHT", f, "RIGHT", -12, 0)
	f.stepLabel, f.stepEdit, f.stepSlider = stepLabel, stepEdit, stepSlider

	local function SyncGridStep()
		if not SarychUI.DragMode then return end
		local on = SarychUI.DragMode:IsGridVisible() and true or false
		local size = SarychUI.DragMode.GetGridSize and SarychUI.DragMode:GetGridSize() or 32
		f._suppressStep = true
		stepSlider:SetValue(size)
		stepEdit:SetText(tostring(size))
		f._suppressStep = false
		local alpha = on and 1 or 0.4
		stepLabel:SetAlpha(alpha)
		stepEdit:SetAlpha(alpha)
		stepSlider:SetAlpha(alpha)
		stepEdit:EnableMouse(on)
		stepSlider:EnableMouse(on)
		if not on then
			stepEdit:ClearFocus()
		end
	end
	f.SyncGridStep = SyncGridStep

	local function CommitGridStep(raw)
		if f._suppressStep or not SarychUI.DragMode or not SarychUI.DragMode.SetGridSize then return end
		local n = tonumber(raw)
		if not n then
			SyncGridStep()
			return
		end
		SarychUI.DragMode:SetGridSize(n)
		SyncGridStep()
	end

	stepSlider:SetScript("OnValueChanged", function(_, value)
		if f._suppressStep then return end
		CommitGridStep(value)
	end)
	stepEdit:SetScript("OnEnterPressed", function(self)
		CommitGridStep(self:GetText())
		self:ClearFocus()
	end)
	stepEdit:SetScript("OnEditFocusLost", function(self)
		CommitGridStep(self:GetText())
	end)
	stepEdit:SetScript("OnEscapePressed", function(self)
		SyncGridStep()
		self:ClearFocus()
	end)

	local function MakeButton(text, x)
		local btn = CreateFrame("Button", nil, f)
		btn:SetSize(110, 24)
		btn:SetPoint("BOTTOMLEFT", x, 10)
		ApplyTheme(btn, { 0.16, 0.16, 0.18, 1 }, { 0.24, 0.24, 0.26, 1 })
		local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		fs:SetPoint("CENTER")
		fs:SetText(text)
		btn:SetScript("OnEnter", function(self)
			ApplyTheme(self, { 0.22, 0.22, 0.25, 1 }, { 0.95, 0.78, 0.15, 1 })
		end)
		btn:SetScript("OnLeave", function(self)
			ApplyTheme(self, { 0.16, 0.16, 0.18, 1 }, { 0.24, 0.24, 0.26, 1 })
		end)
		return btn
	end

	f.applyBtn = MakeButton("Применить", 12)
	f.resetBtn = MakeButton("Сброс", 138)

	local kids = { f.xEdit, f.xSlider, f.yEdit, f.ySlider, f.gridBtn, f.stepEdit, f.stepSlider, f.applyBtn, f.resetBtn, f.closeBtn }
	for i = 1, #kids do
		local k = kids[i]
		if k and k.SetFrameLevel then
			k:SetFrameLevel((f:GetFrameLevel() or 500) + 10 + i)
		end
	end

	f._suppress = false

	local function SyncEditsFromDraft()
		if not session then return end
		local meta = FRAME_MAP[session.frameId]
		local lo = (meta and meta.min) or -1000
		local hi = (meta and meta.max) or 1000
		f._suppress = true
		xSlider:SetMinMaxValues(lo, hi)
		ySlider:SetMinMaxValues(lo, hi)
		local x = session.draft.x
		local y = session.draft.y
		xSlider:SetValue(x)
		ySlider:SetValue(y)
		xEdit:SetText(tostring(x))
		yEdit:SetText(tostring(y))
		local gridOn = SarychUI.DragMode and SarychUI.DragMode:IsGridVisible()
		if gridOn then check:Show() else check:Hide() end
		f._suppress = false
		SyncGridStep()
	end
	f.SyncEditsFromDraft = SyncEditsFromDraft

	local function CommitAxis(which, raw)
		if not session or f._suppress then return end
		local meta = FRAME_MAP[session.frameId]
		local lo = (meta and meta.min) or -1000
		local hi = (meta and meta.max) or 1000
		local n = Clamp(raw, lo, hi)
		if which == "x" then
			session.draft.x = n
		else
			session.draft.y = n
		end
		Panel:SetDraft(session.draft.x, session.draft.y, true)
		SyncEditsFromDraft()
	end

	xSlider:SetScript("OnValueChanged", function(_, value)
		if f._suppress or not session then return end
		local meta = FRAME_MAP[session.frameId]
		local lo = (meta and meta.min) or -1000
		local hi = (meta and meta.max) or 1000
		session.draft.x = Clamp(value, lo, hi)
		xEdit:SetText(tostring(session.draft.x))
		Panel:SetDraft(session.draft.x, session.draft.y, true)
	end)
	ySlider:SetScript("OnValueChanged", function(_, value)
		if f._suppress or not session then return end
		local meta = FRAME_MAP[session.frameId]
		local lo = (meta and meta.min) or -1000
		local hi = (meta and meta.max) or 1000
		session.draft.y = Clamp(value, lo, hi)
		yEdit:SetText(tostring(session.draft.y))
		Panel:SetDraft(session.draft.x, session.draft.y, true)
	end)

	local function BindEdit(edit, which)
		edit:SetScript("OnEnterPressed", function(self)
			CommitAxis(which, self:GetText())
			self:ClearFocus()
		end)
		edit:SetScript("OnEditFocusLost", function(self)
			CommitAxis(which, self:GetText())
		end)
		edit:SetScript("OnEscapePressed", function(self)
			SyncEditsFromDraft()
			self:ClearFocus()
		end)
	end
	BindEdit(xEdit, "x")
	BindEdit(yEdit, "y")

	gridBtn:SetScript("OnClick", function()
		if not SarychUI or not SarychUI.DragMode then return end
		local on = not SarychUI.DragMode:IsGridVisible()
		SarychUI.DragMode:ShowGrid(on)
		if on then check:Show() else check:Hide() end
		SyncGridStep()
	end)

	f.applyBtn:SetScript("OnClick", function()
		Panel:Close(true)
	end)
	f.resetBtn:SetScript("OnClick", function()
		Panel:Reset()
	end)
	f.closeBtn:SetScript("OnClick", function()
		Panel:Cancel()
	end)

	-- ESC closes without keeping in-progress drag (same as the X).
	if UISpecialFrames then
		table.insert(UISpecialFrames, f:GetName())
	end
	f:SetScript("OnHide", function()
		if session and not session._closing then
			Panel:Cancel()
		end
	end)

	root = f
	return f
end

--------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------
function Panel:IsOpen()
	return session ~= nil
end

function Panel:GetFrameId()
	return session and session.frameId or nil
end

function Panel:GetDraft()
	if not session then return nil end
	return session.draft.x, session.draft.y, session.draft.point, session.draft.relativePoint
end

function Panel:SetDraft(x, y, fromUI, point, relativePoint, skipAnchor)
	if not session then return end
	local meta = FRAME_MAP[session.frameId]
	if not meta then return end
	local lo = meta.min or -1000
	local hi = meta.max or 1000
	session.draft.x = Clamp(x, lo, hi)
	session.draft.y = Clamp(y, lo, hi)
	if point then session.draft.point = point end
	if relativePoint then session.draft.relativePoint = relativePoint end
	-- Live-write DB so /sui sliders track drag immediately.
	LiveSyncDraftToOptions(meta, session.draft)
	-- skipAnchor: free-move already SetPoint'd in DragMode - re-anchoring jumps.
	if not skipAnchor then
		SetAnchorPosition(session.frameId, meta, session.draft.x, session.draft.y, session.draft.point, session.draft.relativePoint)
		-- Quest tracker also re-pins WatchFrame after the anchor moves.
		if session.frameId == "questTracker" and meta.onApply then
			meta.onApply()
		end
	end
	NotifyPreview(meta, session.draft.x, session.draft.y)
	if not fromUI and root and root.SyncEditsFromDraft then
		root.SyncEditsFromDraft()
	end
end

function Panel:Reset()
	if not session then return end
	self:SetDraft(session.snapshot.x, session.snapshot.y, false, session.snapshot.point, session.snapshot.relativePoint)
end

-- Close without keeping drag changes (X / ESC).
function Panel:Cancel()
	if not session then
		if root then root:Hide() end
		return
	end
	self:Reset()
	self:Close(false)
end

function Panel:Open(frameId)
	local meta = FRAME_MAP[frameId]
	if not meta then return end

	if session and session.frameId == frameId then
		local ui = EnsureUI()
		ui:Show()
		ui.SyncEditsFromDraft()
		return
	end

	if session and session.frameId and session.frameId ~= frameId then
		self:Close(false)
	end

	local db = ConfigDB(meta) or {}
	local x = tonumber(db[meta.xKey])
	if x == nil then x = meta.defaultX end
	local y = tonumber(db[meta.yKey])
	if y == nil then y = meta.defaultY end
	local point = (meta.aKey and db[meta.aKey]) or meta.defaultA or meta.point or "CENTER"
	local relativePoint = (meta.rKey and db[meta.rKey]) or meta.defaultR or meta.relativePoint or point

	local gridWasOn = false
	if SarychUI and SarychUI.DragMode and SarychUI.DragMode.IsGridVisible then
		gridWasOn = SarychUI.DragMode:IsGridVisible() and true or false
		SarychUI.DragMode:ShowGrid(true)
	end

	session = {
		frameId = frameId,
		snapshot = { x = x, y = y, point = point, relativePoint = relativePoint },
		draft = { x = x, y = y, point = point, relativePoint = relativePoint },
		gridWasOn = gridWasOn,
	}

	local ui = EnsureUI()
	ui.title:SetText((SarychUI and SarychUI.T and SarychUI:T(meta.title)) or meta.title)
	ui:Show()
	RaisePanel(ui)
	ui.SyncEditsFromDraft()
	SetAnchorPosition(frameId, meta, x, y, point, relativePoint)
	if frameId == "questTracker" and meta.onApply then
		meta.onApply()
	end
	NotifyPreview(meta, x, y)
end

function Panel:Close(commit)
	if not session or session._closing then
		if root and not session then root:Hide() end
		return
	end
	session._closing = true

	local meta = FRAME_MAP[session.frameId]
	local frameId = session.frameId
	local snap = session.snapshot
	local draft = session.draft

	local db = meta and ConfigDB(meta)

	-- Draft is already live-written on every SetDraft. Close always keeps the
	-- current position; Reset is the explicit revert to Open-time snapshot.
	-- `commit` kept for API compatibility (Apply / toggle-off both keep coords).
	if meta and db then
		WriteDraftToDB(meta, draft, true)
		if meta.onApply then meta.onApply() end
		ClearPreview(meta)
	elseif meta and snap then
		SetAnchorPosition(frameId, meta, snap.x, snap.y, snap.point, snap.relativePoint)
		ClearPreview(meta)
	end
	commit = commit -- API compat (unused: live-sync already committed)

	if db and meta then
		db[meta.dragFlag] = 0
		if meta.gridFlag then
			db[meta.gridFlag] = 0
		end
		-- Frames: also clear legacy shared flags
		if meta.moduleKey == "frame" then
			db.showPositionDragFrame = 0
			db.showPositionGrid = 0
		end
		if meta.moduleKey == "minimap" then
			db.showGrid = 0
		end
	end

	if SarychUI.DragMode and SarychUI.DragMode.EnableEditMode then
		-- For frames, keep positioning enabled but hide this drag chrome.
		if meta and meta.moduleKey == "frame" then
			local posOn = db and (db.changePositions == 1)
			SarychUI.DragMode:EnableEditMode(frameId, posOn and true or false, false, false)
		elseif meta and meta.moduleKey == "minimap" then
			local posOn = db and (db.positioningEnabled == 1)
			SarychUI.DragMode:EnableEditMode(frameId, posOn and true or false, false, false)
		elseif meta and meta.moduleKey == "auras" then
			local posOn = db and (db.manageBuffs == 1)
			SarychUI.DragMode:EnableEditMode(frameId, posOn and true or false, false, false)
		elseif meta and meta.moduleKey == "tools" and frameId == "questTracker" then
			local posOn = db and db.questTrackerStyle == "dragonflight" and db.questTrackerDragonflightPosition ~= false
			SarychUI.DragMode:EnableEditMode(frameId, posOn and true or false, false, false)
			if posOn and _G.SarychUI_QuestTracker and _G.SarychUI_QuestTracker.Refresh then
				_G.SarychUI_QuestTracker.Refresh()
			end
		elseif meta and meta.moduleKey == "player_resources" and meta.subKey then
			local posOn = meta.alwaysPosition and true or (db and (db[meta.positionFlag or "positioningEnabled"] == 1))
			if meta.requireEnabled and db and db[meta.requireEnabled] ~= 1 then
				posOn = false
			end
			SarychUI.DragMode:EnableEditMode(frameId, posOn and true or false, false, false)
			if meta.onApply then
				meta.onApply()
			end
		elseif meta and meta.moduleKey == "mainmenubar" then
			-- FrostAtomUI bars: position is always applied from config; just
			-- drop the drag chrome and re-layout.
			SarychUI.DragMode:EnableEditMode(frameId, false, false, false)
			if meta.onApply then
				meta.onApply()
			end
		else
			SarychUI.DragMode:EnableEditMode(frameId, false, false, false)
		end
	end
	local data = SarychUI.DragMode and SarychUI.DragMode:GetFrameData(frameId)
	if data and data.dragFrame then
		data.dragFrame:Hide()
	end

	if SarychUI and SarychUI.DragMode then
		if not AnyOtherDragActive(frameId) then
			SarychUI.DragMode:ShowGrid(false)
		end
	end

	session = nil
	if root then root:Hide() end
	SoftRefreshOptions()
end

function Panel:OnDragPosition(frameId, x, y, point, relativePoint)
	if not session or session.frameId ~= frameId then return false end
	local meta = FRAME_MAP[frameId]
	if meta and meta.fromFramePosition then
		x, y = meta.fromFramePosition(x, y)
	end
	self:SetDraft(x, y, false, point, relativePoint, true)
	return true
end

-- Shared helper for options: toggle free-move for a registered DragMode frame.
function Panel:Toggle(frameId, enabled)
	if not SarychUI or not SarychUI.DragMode then return end
	local meta = FRAME_MAP[frameId]
	if not meta then return end

	if enabled then
		if self:IsOpen() and self:GetFrameId() ~= frameId then
			self:Close(false)
		end
		self:Open(frameId)
		SarychUI.DragMode:EnableEditMode(frameId, true, true, true)
	else
		if self:IsOpen() and self:GetFrameId() == frameId then
			self:Close(false)
			return
		end
		SarychUI.DragMode:EnableEditMode(frameId, false, false, false)
		local data = SarychUI.DragMode:GetFrameData(frameId)
		if data and data.dragFrame then data.dragFrame:Hide() end
	end
end
