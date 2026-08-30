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
		defaultX = -200,
		defaultY = -70,
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
		defaultY = 0,
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

local session = nil -- { frameId, snapshot, draft, gridWasOn }

local function ModuleDB(moduleKey)
	local mods = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return mods and mods[moduleKey]
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
			local db = ModuleDB(meta.moduleKey)
			local flag = db and db[meta.dragFlag]
			if flag == 1 or flag == true then
				return true
			end
		end
	end
	return false
end

local function WriteDraftToDB(meta, draft, commitGrid)
	local db = ModuleDB(meta.moduleKey)
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
	f:SetSize(260, 168)
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

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 10, -10)
	title:SetPoint("TOPRIGHT", -10, -10)
	title:SetJustifyH("LEFT")
	title:SetText("Позиция")
	f.title = title

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

		local slider = CreateFrame("Slider", nil, f)
		slider:SetSize(130, 16)
		slider:SetPoint("LEFT", edit, "RIGHT", 8, 0)
		slider:SetOrientation("HORIZONTAL")
		slider:SetMinMaxValues(-2000, 2000)
		slider:SetValueStep(1)
		local thumb = slider:CreateTexture(nil, "OVERLAY")
		thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
		thumb:SetSize(8, 14)
		thumb:SetVertexColor(0.95, 0.82, 0.20, 1)
		slider:SetThumbTexture(thumb)
		local track = slider:CreateTexture(nil, "BACKGROUND")
		track:SetTexture("Interface\\Buttons\\WHITE8X8")
		track:SetHeight(3)
		track:SetPoint("LEFT", slider, "LEFT", 0, 0)
		track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
		track:SetVertexColor(0.28, 0.28, 0.32, 1)

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

	local kids = { f.xEdit, f.xSlider, f.yEdit, f.ySlider, f.gridBtn, f.applyBtn, f.resetBtn }
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
	end)

	f.applyBtn:SetScript("OnClick", function()
		Panel:Close(true)
	end)
	f.resetBtn:SetScript("OnClick", function()
		Panel:Reset()
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
	-- skipAnchor: free-move already SetPoint'd in DragMode — re-anchoring jumps.
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

	local db = ModuleDB(meta.moduleKey) or {}
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
	ui.title:SetText(meta.title)
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

	local db = meta and ModuleDB(meta.moduleKey)

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
