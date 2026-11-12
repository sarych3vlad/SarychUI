-- SarychUI Options Widgets - custom controls (no AceGUI visuals).
local SUI = SarychUI
local T = SUI.OptionsTheme
SUI.OptionsWidgets = SUI.OptionsWidgets or {}
local W = SUI.OptionsWidgets

local CreateFrame = SarychUI.OptionsPool and SarychUI.OptionsPool.CreateFrame or CreateFrame
local pairs = pairs
local ipairs = ipairs
local type = type
local tostring = tostring
local tonumber = tonumber
local floor = math.floor
local math = math
local pcall = pcall
local tinsert = table.insert
local sort = table.sort
local UIParent = UIParent

-- EditBox has no :Enable()/:Disable() methods on the 3.3.5 client.  Those
-- methods previously came from LootClicker's global widget-metatable patch,
-- which cannot be loaded without tainting Blizzard protected unit frames.
local function SetEditBoxEnabled(edit, enabled)
	if not edit then return end
	enabled = enabled and true or false
	if not enabled and edit.HasFocus and edit:HasFocus() then
		edit:ClearFocus()
	end
	if edit._suiInputEnabled ~= enabled then
		edit._suiInputEnabled = enabled
		edit:EnableMouse(enabled)
		if edit.EnableKeyboard then edit:EnableKeyboard(enabled) end
	end
end

local function SafeCall(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a, b, c = pcall(fn, ...)
	if ok then
		return a, b, c
	end
	return nil
end

local function TUI(text)
	if type(text) ~= "string" or text == "" then
		return text
	end
	if SUI and SUI.T then
		return SUI:T(text)
	end
	return text
end

-- Non-interactive updater while a slider is dragged.
-- IMPORTANT: do NOT show an EnableMouse fullscreen capture mid-click - on 3.3.5
-- that steals focus and makes IsMouseButtonDown / phantom MouseUp end the drag
-- while LMB is still held. Release is handled by OnDragStop / OnMouseUp on the hit.
local function GetSliderUpdater()
	if W._sliderUpdater then
		return W._sliderUpdater
	end
	local f = CreateFrame("Frame", "SarychUIOptionsSliderUpdater", UIParent, nil, "widgets:1")
	f:Hide()
	W._sliderUpdater = f
	return f
end

local FlushPendingOptionsValueSync

local function FlushPendingOptionsRefresh()
	if not SUI._pendingOptionsRefresh then
		return
	end
	if SUI._optionsSliderDragging or SUI._optionsTextEditing then
		return
	end
	-- Nested rebuild while RenderCurrentContent/ClearContent is live tears the window.
	if SUI.OptionsCore and SUI.OptionsCore._rendering then
		return
	end
	-- Clear first so NotifySarychUIOptionsChange does not re-defer.
	SUI._pendingOptionsRefresh = nil
	if SUI.NotifySarychUIOptionsChange then
		SUI:NotifySarychUIOptionsChange()
	end
end

-- Focus-lost on 3.3.5 often fires while ClearContent is destroying the edit box.
-- Flush on the next frame so navigation/rebuild is not re-entered mid-render.
local function ScheduleFlushAfterEdit()
	if W._flushAfterEditScheduled then
		return
	end
	W._flushAfterEditScheduled = true
	local f = W._flushAfterEditFrame or CreateFrame("Frame", nil, nil, nil, "widgets:2")
	W._flushAfterEditFrame = f
	f:SetScript("OnUpdate", function(self)
		self:SetScript("OnUpdate", nil)
		W._flushAfterEditScheduled = nil
		if SUI.OptionsCore and SUI.OptionsCore._rendering then
			return
		end
		FlushPendingOptionsRefresh()
		FlushPendingOptionsValueSync()
	end)
end

local function BeginOptionsTextEdit()
	SUI._optionsTextEditing = true
end

local function EndOptionsTextEdit()
	SUI._optionsTextEditing = nil
	ScheduleFlushAfterEdit()
end

-- Defined below, but the drag updater calls it.
local EndOptionsSliderDrag

local function BeginOptionsSliderDrag(row, onTick, onStop)
	SUI._optionsSliderDragging = true
	SUI._optionsSliderDragRow = row
	local f = GetSliderUpdater()
	f:Show()
	f:SetScript("OnUpdate", function()
		if not row._dragging then
			EndOptionsSliderDrag()
			return
		end
		-- Widget destroyed (tab switch / full rebuild) - end cleanly.
		if not row.GetParent or not row:GetParent() then
			if onStop then
				onStop()
			end
			return
		end
		if onTick then
			onTick()
		end
		-- Never poll IsMouseButtonDown here. On some 3.3.5 / ClassicAPI builds it
		-- false-negatives and ends the drag while LMB is still held.
	end)
	-- Retire old mouse-eating capture if a previous build created one.
	local legacy = W._sliderCapture
	if legacy then
		legacy:SetScript("OnUpdate", nil)
		legacy:SetScript("OnMouseUp", nil)
		legacy:EnableMouse(false)
		legacy:Hide()
	end
end

function EndOptionsSliderDrag(releasing)
	local f = W._sliderUpdater
	if f then
		f:SetScript("OnUpdate", nil)
		f:Hide()
	end
	local legacy = W._sliderCapture
	if legacy then
		legacy:SetScript("OnUpdate", nil)
		legacy:SetScript("OnMouseUp", nil)
		legacy:EnableMouse(false)
		legacy:Hide()
	end
	SUI._optionsSliderDragging = nil
	SUI._optionsSliderDragRow = nil
	if releasing then return end
	FlushPendingOptionsRefresh()
	if SUI._pendingOptionsValueSync and SUI.SyncOpenOptionsValues then
		SUI:SyncOpenOptionsValues()
	end
end

function SUI.IsOptionsTextEditing()
	return SUI._optionsTextEditing and true or false
end

function SUI.IsOptionsInteractBusy()
	return (SUI._optionsSliderDragging or SUI._optionsTextEditing) and true or false
end

-- Looping preview OnUpdate only while the host is shown (active tab).
-- Leaving the tab hides/destroys the host -> animation stops immediately.
function SUI.BindOptionsPreviewAnim(host, onUpdate)
	if not host or type(onUpdate) ~= "function" then
		return
	end
	host._suiPreviewAnim = onUpdate
	local function sync()
		if host:IsShown() and host._suiPreviewAnim then
			host:SetScript("OnUpdate", function(self, elapsed)
				if SUI._optionsSliderDragging then
					return
				end
				if not self:IsShown() then
					return
				end
				local fn = self._suiPreviewAnim
				if fn then
					fn(self, elapsed)
				end
			end)
		else
			host:SetScript("OnUpdate", nil)
		end
	end
	-- Rebinding only swaps the tick fn - never stack OnShow/OnHide hooks.
	if not host._suiPreviewAnimBound then
		host._suiPreviewAnimBound = true
		host:HookScript("OnShow", sync)
		host:HookScript("OnHide", sync)
	end
	sync()
end

function SUI.IsOptionsSliderDragging()
	return SUI._optionsSliderDragging and true or false
end

-- Lightweight re-read of open /sui widget values (no full page rebuild).
-- Used by drag-mode so X/Y sliders track the frame immediately.
local function SyncWidgetTree(frame)
	if not frame then
		return
	end
	if type(frame._suiGetDisabled) == "function" and type(frame.SetDisabled) == "function" then
		SafeCall(frame.SetDisabled, frame, frame._suiGetDisabled())
	end
	-- Every widget that can re-read its own value does so here: checkbox, slider,
	-- dropdown, input, color, keybinding, dynamic labels. Each Refresh already
	-- bails out while its own control is busy (focus / drag / waiting for a key).
	if type(frame.Refresh) == "function" then
		if not (frame._dragging or (frame.edit and frame.edit.HasFocus and frame.edit:HasFocus())) then
			SafeCall(frame.Refresh, frame)
		end
	end
	local children = { frame:GetChildren() }
	for i = 1, #children do
		SyncWidgetTree(children[i])
	end
end

function SUI:SyncOpenOptionsValues()
	if not self.OptionsCore or not self.OptionsCore._open then
		return
	end
	if self._optionsSliderDragging or self._optionsTextEditing then
		self._pendingOptionsValueSync = true
		return
	end
	self._pendingOptionsValueSync = nil
	local child = self.OptionsWindow and self.OptionsWindow.contentChild
	if child then
		SyncWidgetTree(child)
	end
end

local function SyncExternalWidget(frame, syncKey)
	if not frame then return false end
	if frame._suiExternalSyncKey == syncKey and type(frame.RefreshExternal) == "function" then
		SafeCall(frame.RefreshExternal, frame)
		return true
	end
	local children = { frame:GetChildren() }
	for i = 1, #children do
		if SyncExternalWidget(children[i], syncKey) then
			return true
		end
	end
	return false
end

-- Refresh one value changed outside /sui (for example a minimap-button drag).
-- Unlike the ordinary refresh pass, this intentionally replaces a focused
-- edit value because the external gesture is the user's newer input method.
function SUI:SyncOpenOptionValue(syncKey)
	if not syncKey or not self.OptionsCore or not self.OptionsCore._open then
		return false
	end
	local child = self.OptionsWindow and self.OptionsWindow.contentChild
	return child and SyncExternalWidget(child, syncKey) or false
end

FlushPendingOptionsValueSync = function()
	if SUI._pendingOptionsValueSync and SUI.SyncOpenOptionsValues then
		SUI:SyncOpenOptionsValues()
	end
end

-- Apply a module's live (in-game) settings after an options change.
-- Preview widgets update separately; this is what actually changes the UI.
function SUI.ApplyLiveModule(mod)
	if type(mod) == "string" then
		mod = SUI.GetModule and SUI:GetModule(mod, true) or (SUI.modules and SUI.modules[mod])
	end
	if not mod then
		return
	end
	if type(mod.ApplySettings) == "function" then
		mod:ApplySettings()
	elseif type(mod.ApplyAllSettings) == "function" then
		mod:ApplyAllSettings()
	elseif type(mod.RefreshConfig) == "function" then
		mod:RefreshConfig()
	end
end

-- Cheap live apply on mounted preview instances (LayoutLive / RefreshStyle / Refresh).
function SUI.ApplyOptionsPreviewLive(preview, key, value)
	if not preview then
		return
	end
	if preview._live and key ~= nil then
		preview._live[key] = value
	end
	if key ~= nil then
		preview._activeKey = key
	end
	local list = preview._instances
	if type(list) ~= "table" then
		return
	end
	for i = 1, #list do
		local inst = list[i]
		if inst and inst.GetParent and inst:GetParent() then
			if inst.LayoutLive then
				inst:LayoutLive(key)
			elseif inst.RefreshStyle then
				inst:RefreshStyle()
			elseif inst.RefreshLayout then
				inst:RefreshLayout()
			elseif inst.Refresh then
				inst:Refresh()
			end
		end
	end
end

-- Preview modules that options sliders/checkboxes may notify.
local OPTION_PREVIEW_NAMES = {
	"PlatesAurasLayoutPreview",
	"NameplateDistancePreview",
	"LootRollPreview",
	"CooldownTextPreview",
	"GcdCooldownPreview",
	"ErrorFilterPreview",
	"SysMsgPreview",
	"BossEmotePreview",
	"FrameHitPreview",
	"CombatTextPreview",
	"ArenaPreview",
	"ArenaNumbersPreview",
	"ArenaGroupTitlesPreview",
	"AurasPreview",
	"MinimapPreview",
	"CombatIndicatorPreview",
	"FramePvpPreview",
	"ChatTooltipPreview",
}

local function PreviewIsMounted(preview)
	if not preview then return false end
	local list = preview._instances
	if type(list) ~= "table" then return false end
	for i = 1, #list do
		local inst = list[i]
		if inst and inst.GetParent and inst:GetParent() then
			return true
		end
	end
	return false
end

-- Prefer unique key ownership when several previews happen to be mounted.
local function PreviewNameForKey(key)
	if type(key) ~= "string" then return nil end
	if key == "itemRefIconsEnabled" then return "ChatTooltipPreview" end
	if key:find("^combatIndicator") then return "CombatIndicatorPreview" end
	if key == "enableFocusComboPoints" then return "CombatIndicatorPreview" end
	if key:find("^heal") then return "CombatTextPreview" end
	if key == "errorSysMsgOffsetY" then return "SysMsgPreview" end
	if key:find("^error") then return "ErrorFilterPreview" end
	if key:find("^raidBossEmote") then return "BossEmotePreview" end
	if key:find("^ICON_SIZE_")
		or key == "CentrY" or key == "CastX" or key == "CastY"
		or key == "PlayerOffsetY" or key == "RightX" or key == "RightY"
		or key == "OtherX" or key == "OtherY"
		or key == "MAX_PLAYER_AURAS" or key == "spacing"
		or key:find("^center%.") or key:find("^player%.") or key:find("^right%.")
	then
		return "PlatesAurasLayoutPreview"
	end
	if key:find("PVP") or key:find("^pvp") or key:find("^classIcon") or key == "portrait3D"
		or key == "hideFrameLevel" or key == "hidePlayerRestState" or key == "hideLeaderIcon"
		or key:find("^nameBackground") or key:find("^classColored") then
		return "FramePvpPreview"
	end
	if key == "hideFocusAuras" or key == "hideTargetAuras" or key == "hideTargetOfTargetAuras" or key == "enableDispelHighlight"
		or key == "changeFrameAuraSize" or key:find("^frameAura") then
		return "AurasPreview"
	end
	if key:find("^trinkets") then return "ArenaPreview" end
	if key:find("^arenaNumbers") then return "ArenaNumbersPreview" end
	if key == "hideGroupRaidText" then return "ArenaNumbersPreview" end
	if key == "fontSizeSmall" or key == "fontSizeMedium" or key == "fontSizeLarge" then
		return "CooldownTextPreview"
	end
	if key == "offsetX" or key == "offsetY" or key == "shadowX" or key == "shadowY" then
		return "NameplateDistancePreview"
	end
	return nil
end

local function DeliverPreview(preview, key, value, live)
	if not preview then return end
	if live then
		-- Prefer targeted live path (moves only the dragged control).
		if preview.SetLiveValue then
			preview:SetLiveValue(key, value)
		else
			SUI.ApplyOptionsPreviewLive(preview, key, value)
		end
	else
		if preview.SetActiveKey then
			preview:SetActiveKey(key)
		elseif preview.RefreshAll then
			preview:RefreshAll()
		end
	end
end

-- Notify only mounted preview(s) for this options page - not every preview module.
function W:NotifyOptionPreview(key, value, live)
	if not key then return end

	local mounted = {}
	for i = 1, #OPTION_PREVIEW_NAMES do
		local name = OPTION_PREVIEW_NAMES[i]
		local preview = SUI[name]
		if PreviewIsMounted(preview) then
			mounted[#mounted + 1] = { name = name, preview = preview }
		end
	end

	if #mounted == 0 then
		return
	end

	if #mounted == 1 then
		DeliverPreview(mounted[1].preview, key, value, live)
		-- Cooldown text + GCD previews share the same CC tab.
		if mounted[1].name == "CooldownTextPreview" and PreviewIsMounted(SUI.GcdCooldownPreview) then
			DeliverPreview(SUI.GcdCooldownPreview, key, value, live)
		end
		return
	end

	local preferred = PreviewNameForKey(key)
	if preferred then
		local hit = false
		for i = 1, #mounted do
			if mounted[i].name == preferred then
				DeliverPreview(mounted[i].preview, key, value, live)
				hit = true
				break
			end
		end
		if hit then
			if preferred == "CooldownTextPreview" and PreviewIsMounted(SUI.GcdCooldownPreview) then
				DeliverPreview(SUI.GcdCooldownPreview, key, value, live)
			end
			return
		end
	end

	for i = 1, #mounted do
		DeliverPreview(mounted[i].preview, key, value, live)
	end
end

local function MakeLabel(parent, text, font)
	local fs = parent:CreateFontString(nil, "OVERLAY", font or T.fonts.normal)
	fs:SetJustifyH("LEFT")
	fs:SetText(text or "")
	T:SetTextColor(fs, "text")
	return fs
end

-- Same gold hover as Talented owned menus / Blizzard UIDropDownMenu.
local DROPDOWN_HL = [[Interface\QuestFrame\UI-QuestTitleHighlight]]

local function EnsureDropdownItemHighlight(item)
	if not item then return end
	local hl = item._suiDropHl
	if not hl then
		hl = item:CreateTexture(nil, "BACKGROUND")
		hl:SetTexture(DROPDOWN_HL)
		hl:SetBlendMode("ADD")
		hl:SetAllPoints(item)
		hl:SetAlpha(0.8)
		item._suiDropHl = hl
	end
	return hl
end

local function DropdownItem_OnEnter(self)
	local hl = EnsureDropdownItemHighlight(self)
	if hl then hl:Show() end
end

local function DropdownItem_OnLeave(self)
	SUI.OptionsTooltip.Hide()
	if self._suiDropHl then
		self._suiDropHl:Hide()
	end
	if self.SetBackdrop then
		self:SetBackdrop(nil)
	end
end

function W:Spacer(parent, height)
	local f = CreateFrame("Frame", nil, parent, nil, "widgets:3")
	f:SetHeight(height or 8)
	f:SetWidth(1)
	return f
end

-- Compact spinning icon (same textures as bag-sort spinner) + label.
function W:SpinnerLabel(parent, text)
	local f = CreateFrame("Frame", nil, parent, nil, "widgets:4")
	f:SetHeight(22)

	local size = 16
	local SPINNER_TEX_FRAME = "Interface\\AddOns\\SarychUI\\media\\components\\modules\\bags\\engine\\Media\\Textures\\StreamFrame.blp"
	local SPINNER_TEX_CIRCLE = "Interface\\AddOns\\SarychUI\\media\\components\\modules\\bags\\engine\\Media\\Textures\\StreamCircle.blp"
	local SPINNER_TEX_SPARK = "Interface\\AddOns\\SarychUI\\media\\components\\modules\\bags\\engine\\Media\\Textures\\StreamSpark.blp"

	local icon = CreateFrame("Frame", nil, f, nil, "widgets:5")
	icon:SetSize(size, size)
	icon:SetPoint("LEFT", f, "LEFT", 0, 0)

	local framing = icon:CreateTexture(nil, "ARTWORK")
	framing:SetTexture(SPINNER_TEX_FRAME)
	framing:SetAllPoints()

	local circle = icon:CreateTexture(nil, "ARTWORK")
	circle:SetTexture(SPINNER_TEX_CIRCLE)
	circle:SetVertexColor(1, 0.82, 0)
	circle:SetAllPoints()
	local circleAnim = circle:CreateAnimationGroup()
	circleAnim:SetLooping("REPEAT")
	local circleRot = circleAnim:CreateAnimation("Rotation")
	circleRot:SetDuration(1)
	circleRot:SetDegrees(-360)

	local spark = icon:CreateTexture(nil, "OVERLAY")
	spark:SetTexture(SPINNER_TEX_SPARK)
	spark:SetAllPoints()
	local sparkAnim = spark:CreateAnimationGroup()
	sparkAnim:SetLooping("REPEAT")
	local sparkRot = sparkAnim:CreateAnimation("Rotation")
	sparkRot:SetDuration(1)
	sparkRot:SetDegrees(-360)

	local fs = MakeLabel(f, text, T.fonts.title)
	T:SetTextColor(fs, "title")
	fs:SetPoint("LEFT", icon, "RIGHT", 6, 0)
	fs:SetPoint("RIGHT", f, "RIGHT", 0, 0)
	f.label = fs
	f.icon = icon

	f:SetScript("OnShow", function()
		circleAnim:Play()
		sparkAnim:Play()
	end)
	f:SetScript("OnHide", function()
		circleAnim:Stop()
		sparkAnim:Stop()
	end)
	if f:IsVisible() then
		circleAnim:Play()
		sparkAnim:Play()
	end
	return f
end

function W:Description(parent, text)
	local f = CreateFrame("Frame", nil, parent, nil, "widgets:6")
	local fs = MakeLabel(f, text, T.fonts.small)
	T:SetTextColor(fs, "textDim")
	fs:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	fs:SetJustifyH("LEFT")
	fs:SetJustifyV("TOP")
	fs:SetWordWrap(true)
	if fs.SetNonSpaceWrap then
		fs:SetNonSpaceWrap(true)
	end
	f.label = fs

	-- Measure wrapped height for a known width (panel may not fire OnSizeChanged yet).
	-- No extra internal padding - parent panel/section pad keeps even insets.
	f.MeasureHeight = function(self, width)
		local w = width or self:GetWidth()
		-- Ignore bogus tiny widths from pre-layout frames (causes huge wrap).
		if not w or w < 80 then
			w = 400
		end
		w = math.max(40, w - 2)
		fs:SetWidth(w)
		local h = fs:GetStringHeight() or 14
		self:SetHeight(math.max(14, h))
		return self:GetHeight()
	end

	local function BubbleHeightChange(self)
		-- Relayout ClearAllPoints orphans an open dropdown anchored to a child button.
		if W.IsDropdownOpen and W:IsDropdownOpen() then
			return
		end
		local p = self:GetParent()
		while p do
			if p._relayoutInline then
				p:_relayoutInline()
			end
			if p._onContentHeightChanged then
				p:_onContentHeightChanged()
				break
			end
			p = p:GetParent()
		end
	end

	f.SetDynamicText = function(self, text)
		text = text or ""
		if fs:GetText() == text then return end
		fs:SetText(text)
		local before = self:GetHeight() or 0
		self:MeasureHeight(self:GetWidth())
		if math.abs((self:GetHeight() or 0) - before) > 0.5 then
			BubbleHeightChange(self)
		end
	end

	f:SetScript("OnSizeChanged", function(self, width)
		if self._measureLock then return end
		-- Skip pre-layout tiny widths - they produce huge wrap that sticks until reselect.
		if width and width < 80 then
			return
		end
		self._measureLock = true
		local before = self:GetHeight() or 0
		self:MeasureHeight(width)
		local after = self:GetHeight() or 0
		self._measureLock = nil
		if math.abs(after - before) > 0.5 then
			BubbleHeightChange(self)
		end
	end)
	f:SetHeight(20)
	return f
end

-- Description with a SUI-framed icon and a single-line caption on the right.
local function ResolveIconSpec(spec)
	if type(spec) == "table" then
		return spec.texture or spec.path or spec[1], spec.coords or spec.texCoord
	end
	if type(spec) == "string" and spec ~= "" then
		return spec, nil
	end
	return nil, nil
end

local function ApplyIconTexture(tex, frame, spec)
	local path, coords = ResolveIconSpec(spec)
	if path then
		tex:SetTexture(path)
		if coords then
			tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		else
			tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		end
		tex:SetVertexColor(1, 1, 1, 1)
		frame:Show()
		return true
	end
	tex:SetTexture(nil)
	frame:Hide()
	return false
end

-- text + optional right-side button / icons (1–2) / label.
-- Layout (right → left): [button?] [primary icon] [secondary icon] [right text?] … [name]
-- iconPath / icon2Path may be a texture string or { texture = "...", coords = {l,r,t,b} }.
-- rightButton = { text=, onClick=, tooltipFn= } — width fits label.
function W:DescriptionRightIcon(parent, text, iconPath, iconSize, rightText, icon2Path, rightButton)
	local f = CreateFrame("Frame", nil, parent, nil, "widgets:7")
	iconSize = tonumber(iconSize) or 24
	local GAP = 8
	local BTN_H = 24

	local function MakeIconSlot()
		local frame = CreateFrame("Frame", nil, f, nil, "widgets:8")
		frame:SetSize(iconSize, iconSize)
		T:ApplyFlat(frame, T.colors.inputBg, T.colors.borderSoft)
		local tex = frame:CreateTexture(nil, "ARTWORK")
		tex:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
		tex:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
		tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		return frame, tex
	end

	local actionBtn
	if type(rightButton) == "table" and (rightButton.text or rightButton.name) then
		actionBtn = W:Button(f, rightButton.text or rightButton.name, rightButton.onClick, rightButton.tooltipFn)
		actionBtn:SetHeight(BTN_H)
	end

	local iconFrame, icon = MakeIconSlot()
	local icon2Frame, icon2 = MakeIconSlot()
	icon2Frame:Hide()

	local rightLabel = MakeLabel(f, rightText, T.fonts.normal)
	rightLabel:SetJustifyH("RIGHT")
	rightLabel:SetJustifyV("MIDDLE")

	local fs = MakeLabel(f, text, T.fonts.normal)
	fs:SetJustifyH("LEFT")
	fs:SetJustifyV("MIDDLE")

	local function FitButtonWidth()
		if not actionBtn then
			return 0
		end
		local tw = 0
		if actionBtn.label and actionBtn.label.GetStringWidth then
			tw = actionBtn.label:GetStringWidth() or 0
		end
		local w = math.max(48, math.ceil(tw + 18))
		actionBtn:SetWidth(w)
		return w
	end

	local function LayoutSideText()
		local reserve = 0
		local rightAnchor = f
		local rightPoint = "RIGHT"
		local rightOffset = 0

		if actionBtn then
			local bw = FitButtonWidth()
			actionBtn:ClearAllPoints()
			actionBtn:SetPoint("RIGHT", f, "RIGHT", 0, 0)
			reserve = reserve + bw + GAP
			rightAnchor = actionBtn
			rightPoint = "LEFT"
			rightOffset = -GAP
		end

		local hasPrimary = iconFrame:IsShown()
		local hasSecondary = icon2Frame:IsShown()
		if hasPrimary then
			iconFrame:ClearAllPoints()
			iconFrame:SetPoint("RIGHT", rightAnchor, rightPoint, rightOffset, 0)
			reserve = reserve + iconSize + GAP
			rightAnchor = iconFrame
			rightPoint = "LEFT"
			rightOffset = -GAP
		end
		if hasSecondary then
			icon2Frame:ClearAllPoints()
			icon2Frame:SetPoint("RIGHT", rightAnchor, rightPoint, rightOffset, 0)
			reserve = reserve + iconSize + GAP
			rightAnchor = icon2Frame
			rightPoint = "LEFT"
			rightOffset = -GAP
		end

		local txt = rightLabel:GetText() or ""
		if txt ~= "" then
			rightLabel:Show()
			rightLabel:ClearAllPoints()
			rightLabel:SetPoint("RIGHT", rightAnchor, rightPoint, rightOffset, 0)
			rightLabel:SetWidth(1000)
			local rightW = rightLabel:GetStringWidth() or 0
			if rightW < 1 then
				rightW = 1
			end
			rightLabel:SetWidth(rightW)
			reserve = reserve + rightW + GAP
		else
			rightLabel:Hide()
		end

		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -3)
		fs:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -reserve, 3)
	end

	f.label = fs
	f.rightLabel = rightLabel
	f.iconFrame = iconFrame
	f.icon = icon
	f.icon2Frame = icon2Frame
	f.icon2 = icon2
	f.actionBtn = actionBtn

	f.SetDynamicText = function(self, value)
		fs:SetText(value or "")
		LayoutSideText()
	end
	f.SetDynamicRightText = function(self, value)
		rightLabel:SetText(value or "")
		LayoutSideText()
	end
	f.SetDynamicIcon = function(self, path)
		ApplyIconTexture(icon, iconFrame, path)
		LayoutSideText()
	end
	f.SetDynamicIcon2 = function(self, path)
		ApplyIconTexture(icon2, icon2Frame, path)
		LayoutSideText()
	end
	f.MeasureHeight = function(self)
		LayoutSideText()
		local textH = (fs:GetStringHeight() or 12) + 6
		local sideH = iconSize + 2
		if actionBtn then
			sideH = math.max(sideH, BTN_H)
		end
		self:SetHeight(math.max(sideH, textH))
		return self:GetHeight()
	end
	f:SetHeight(math.max(iconSize + 2, actionBtn and BTN_H or 0))
	f:SetDynamicIcon(iconPath)
	f:SetDynamicIcon2(icon2Path)
	LayoutSideText()
	return f
end

function W:Panel(parent)
	local f = CreateFrame("Frame", nil, parent, nil, "widgets:9")
	T:ApplyFlat(f, T.colors.panelBg, T.colors.borderSoft)
	f._contentPad = (T.sizes and T.sizes.panelPad) or 8
	return f
end

local ShowCooltip, HideCooltip = SUI.OptionsTooltip.Show, SUI.OptionsTooltip.Hide
W.ShowCooltip, W.HideCooltip = ShowCooltip, HideCooltip

function W:Header(parent, text, tooltipFn, iconPath, helpIcon)
	local f = CreateFrame("Frame", nil, parent, nil, "widgets:10")
	f:SetHeight(22)
	local labelAnchor = f
	local labelRelative = "LEFT"
	local labelOffsetX = 0

	if type(iconPath) == "string" and iconPath ~= "" then
		local iconSize = 16
		local icon = f:CreateTexture(nil, "ARTWORK")
		icon:SetSize(iconSize, iconSize)
		icon:SetPoint("LEFT", f, "LEFT", 0, 0)
		icon:SetTexture(iconPath)
		icon:SetTexCoord(0, 1, 0, 1)
		icon:SetVertexColor(1.0, 0.82, 0.0)
		f.icon = icon
		labelAnchor = icon
		labelRelative = "RIGHT"
		labelOffsetX = 6
	end

	local fs = MakeLabel(f, text, T.fonts.title)
	T:SetTextColor(fs, "title")
	fs:SetPoint("LEFT", labelAnchor, labelRelative, labelOffsetX, 0)
	f.label = fs

	return f
end

function W:Button(parent, text, onClick, tooltipFn, nameFn)
	local btn = CreateFrame("Button", nil, parent, nil, "widgets:11")
	btn:SetHeight(T.sizes.buttonHeight)
	btn:SetWidth(T.sizes.buttonWidth)
	T:ApplyFlat(btn, T.colors.buttonBg, T.colors.borderSoft)
	local fs = MakeLabel(btn, text, T.fonts.normal)
	fs:SetPoint("CENTER")
	btn.label = fs
	if type(nameFn) == "function" then
		btn._suiValueWidget = true
		btn._nameFn = nameFn
		btn.Refresh = function(self)
			local n = SafeCall(self._nameFn)
			if n ~= nil and self.label then
				self.label:SetText(tostring(n))
			end
		end
	end
	btn:SetScript("OnEnter", function(self)
		if self._disabled then return end
		T:ApplyFlat(self, T.colors.buttonHover, T.colors.accent)

	end)
	btn:SetScript("OnLeave", function(self)
		T:ApplyFlat(self, T.colors.buttonBg, T.colors.borderSoft)
		HideCooltip()
	end)
	btn:SetScript("OnClick", function(self)
		if self._disabled then return end
		HideCooltip()
		if onClick then onClick(self) end
	end)
	btn.SetDisabled = function(self, disabled)
		self._disabled = disabled and true or false
		if disabled then
			T:SetTextColor(self.label, "disabled")
		else
			T:SetTextColor(self.label, "text")
		end
	end
	return btn
end

-- Left button fills leftover width; right button sizes to its label.
function W:ButtonPair(parent, leftText, leftClick, leftTooltip, leftNameFn, rightText, rightClick, rightTooltip, rightMinWidth, rightNameFn)
	local row = CreateFrame("Frame", nil, parent, nil, "widgets:12")
	local buttonHeight = T.sizes.buttonHeight
	local gap = 8
	local rowGap = T.sizes.rowGap or 4
	row:SetHeight(buttonHeight)
	local left = W:Button(row, leftText, leftClick, leftTooltip, leftNameFn)
	local right = W:Button(row, rightText, rightClick, rightTooltip, rightNameFn)
	left:SetPoint("LEFT", row, "LEFT", 0, 0)
	right:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	row.left = left
	row.right = right
	row._suiValueWidget = true
	local function LabelWidth(button)
		local label = button.label
		if not label or not label.GetStringWidth then return 0 end
		label:ClearAllPoints()
		label:SetPoint("CENTER", button, "CENTER", 0, 0)
		local width = label:GetStringWidth() or 0
		label:ClearAllPoints()
		label:SetPoint("LEFT", button, "LEFT", 8, 0)
		label:SetPoint("RIGHT", button, "RIGHT", -8, 0)
		label:SetJustifyH("CENTER")
		label:SetWordWrap(false)
		return width
	end

	row.MeasureHeight = function(self, width)
		width = width or self:GetWidth() or 200
		local rw = math.max(rightMinWidth or 72, math.ceil(LabelWidth(right) + 18))
		local lw = math.max(80, math.ceil(LabelWidth(left) + 18))
		left:ClearAllPoints()
		right:ClearAllPoints()
		if lw + gap + rw > width then
			left:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
			left:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
			right:SetPoint("TOPLEFT", left, "BOTTOMLEFT", 0, -rowGap)
			right:SetPoint("TOPRIGHT", left, "BOTTOMRIGHT", 0, -rowGap)
			self:SetHeight(buttonHeight * 2 + rowGap)
			return buttonHeight * 2 + rowGap
		end
		left:SetPoint("LEFT", self, "LEFT", 0, 0)
		left:SetPoint("RIGHT", right, "LEFT", -gap, 0)
		right:SetPoint("RIGHT", self, "RIGHT", 0, 0)
		right:SetWidth(rw)
		self:SetHeight(buttonHeight)
		return buttonHeight
	end

	row.Refresh = function(self)
		if left.Refresh then
			left:Refresh()
		end
		if right.Refresh then
			right:Refresh()
		end
	end

	row.SetDisabled = function(self, disabled)
		if left.SetDisabled then
			left:SetDisabled(disabled)
		end
		if right.SetDisabled then
			right:SetDisabled(disabled)
		end
	end

	return row
end

function W:Checkbox(parent, text, get, set, tooltipFn, helpIcon, previewKey)
	local row = CreateFrame("Frame", nil, parent, nil, "widgets:13")
	row:SetHeight(T.sizes.rowH or 22)
	row:EnableMouse(true)
	row._previewKey = previewKey

	local box = CreateFrame("Button", nil, row, nil, "widgets:14")
	box:SetSize(16, 16)
	box:SetPoint("LEFT", row, "LEFT", 0, 0)
	T:ApplyFlat(box, T.colors.inputBg, T.colors.border)

	local check = box:CreateTexture(nil, "OVERLAY")
	check:SetTexture("Interface\\Buttons\\WHITE8X8")
	check:SetPoint("TOPLEFT", 3, -3)
	check:SetPoint("BOTTOMRIGHT", -3, 3)
	local c = T.colors.checkOn
	check:SetVertexColor(c[1], c[2], c[3], 1)
	check:Hide()
	box.check = check

	local label = MakeLabel(row, text)
	label:SetPoint("LEFT", box, "RIGHT", 6, 0)

	row.box = box
	row.label = label
	row._checked = false

	local function ApplyVisual(on)
		row._checked = on and true or false
		if on then check:Show() else check:Hide() end
	end

	local function NotifyPreview(value, live)
		W:NotifyOptionPreview(row._previewKey, value, live)
	end

	local function OnEnterControl()
        NotifyPreview(nil, false)
    end

	local function OnLeaveRow()
		HideCooltip()
		local key = row._previewKey
		if key then
			local tipPreview = SUI.ChatTooltipPreview
			if tipPreview and tipPreview.SetActiveKey then
				tipPreview:SetActiveKey(nil)
			end
			local pvpPreview = SUI.FramePvpPreview
			if pvpPreview and pvpPreview.SetActiveKey then
				pvpPreview:SetActiveKey(nil)
			end
			local combatIndPreview = SUI.CombatIndicatorPreview
			if combatIndPreview and combatIndPreview.SetActiveKey then
				combatIndPreview:SetActiveKey(nil)
			end
			local arenaNumPreview = SUI.ArenaNumbersPreview
			if arenaNumPreview and arenaNumPreview.SetActiveKey then
				arenaNumPreview:SetActiveKey(nil)
			end
			local groupTitlesPreview = SUI.ArenaGroupTitlesPreview
			if groupTitlesPreview and groupTitlesPreview.SetActiveKey then
				groupTitlesPreview:SetActiveKey(nil)
			end
		end
	end

	-- Optional help icon next to the title (opt-in via helpIcon / suiHelpIcon).
	-- helpIcon: true | texture path string | { path = "...", color = {r,g,b[,a]} }
	if helpIcon and tooltipFn then
		local help = CreateFrame("Button", nil, row, nil, "widgets:15")
		help:SetSize(14, 14)
		help:SetPoint("LEFT", label, "RIGHT", 4, 0)
		help:EnableMouse(true)
		local helpTex = help:CreateTexture(nil, "ARTWORK")
		helpTex:SetAllPoints()
		local helpPath = "Interface\\GossipFrame\\AvailableQuestIcon"
		local helpColor = nil
		if type(helpIcon) == "string" and helpIcon ~= "" then
			helpPath = helpIcon
		elseif type(helpIcon) == "table" then
			if type(helpIcon.path) == "string" and helpIcon.path ~= "" then
				helpPath = helpIcon.path
			end
			if type(helpIcon.color) == "table" then
				helpColor = helpIcon.color
			end
		end
		helpTex:SetTexture(helpPath)
		if helpColor then
			helpTex:SetVertexColor(helpColor[1] or 1, helpColor[2] or 1, helpColor[3] or 1, helpColor[4] or 1)
		end
		help:SetScript("OnEnter", function(self)
			OnEnterControl()
		end)
		help:SetScript("OnLeave", function()
			OnLeaveRow()
		end)
		row.help = help
	else
		label:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	end

	box:SetScript("OnEnter", OnEnterControl)
	box:SetScript("OnLeave", OnLeaveRow)

	row.Refresh = function(self)
		local v = SafeCall(get)
		ApplyVisual(v and true or false)
	end

	local function Toggle()
		if row._disabled then
			return
		end
		local newVal = not row._checked
		ApplyVisual(newVal)
		SafeCall(set, newVal)
		-- Re-sync from get: set handlers may reject or apply partially.
		row:Refresh()
		NotifyPreview(row._checked, true)
	end

	box:SetScript("OnClick", function()
		Toggle()
	end)

	-- Whole row is clickable (label + padding), not only the 16px box.
	row:SetScript("OnMouseUp", function(self, button)
		if button ~= "LeftButton" or row._disabled then
			return
		end
		-- Ignore if the click landed on the box button (it already handled OnClick).
		if GetMouseFocus() == box then
			return
		end
		Toggle()
	end)

	row.SetDisabled = function(self, disabled)
		self._disabled = disabled and true or false
		T:SetTextColor(label, disabled and "disabled" or "text")
		local border = disabled and T.colors.disabled or T.colors.border
		T:ApplyFlat(box, T.colors.inputBg, border)
		if disabled then
			ApplyVisual(false)
		else
			self:Refresh()
		end
	end

	SUI.OptionsTooltip.BindCheckbox(row)
	row:Refresh()
	return row
end

function W:ColorPicker(parent, text, get, set, hasAlpha, tooltipFn, previewKey)
	local row = CreateFrame("Frame", nil, parent, nil, "widgets:16")
	if SUI.OptionsPool then
		SUI.OptionsPool:OnRelease(row, function()
			if ColorPickerFrame and ColorPickerFrame._suiOwner == row then
				ColorPickerFrame._suiOwner = nil
				ColorPickerFrame._suiOnHide = nil
				ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = nil, nil, nil
				HideUIPanel(ColorPickerFrame)
			end
		end)
	end
	row:SetHeight(T.sizes.rowH or 22)
	row:EnableMouse(true)
	row._hasAlpha = hasAlpha and true or false
	row._previewKey = previewKey

	local label = MakeLabel(row, text)
	label:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.label = label

	local swatch = CreateFrame("Button", nil, row, nil, "widgets:17")
	swatch:SetSize(22, 16)
	swatch:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	T:ApplyFlat(swatch, T.colors.inputBg, T.colors.border)
	local fill = swatch:CreateTexture(nil, "ARTWORK")
	fill:SetPoint("TOPLEFT", 2, -2)
	fill:SetPoint("BOTTOMRIGHT", -2, 2)
	fill:SetTexture("Interface\\Buttons\\WHITE8X8")
	swatch.fill = fill
	row.swatch = swatch

	local function ApplyColor(r, g, b, a)
		if r == nil then r = 1 end
		if g == nil then g = 1 end
		if b == nil then b = 1 end
		if a == nil then a = 1 end
		row._r, row._g, row._b, row._a = r, g, b, a
		fill:SetVertexColor(row._r, row._g, row._b, row._hasAlpha and row._a or 1)
	end

	row.Refresh = function(self)
		local ok, r, g, b, a = pcall(get)
		if not ok or type(r) ~= "number" then
			r, g, b, a = 1, 1, 1, 1
		end
		ApplyColor(r, g, b, a)
	end

	local function NotifyPreview(value, live)
		if row._previewKey then
			W:NotifyOptionPreview(row._previewKey, value, live)
		end
	end

	local function ColorCallback(r, g, b, a, confirmed)
		if not row._hasAlpha then
			a = 1
		end
		ApplyColor(r, g, b, a)
		if row._previewKey then
			NotifyPreview({ r, g, b, a }, true)
			SafeCall(set, r, g, b, a)
		elseif confirmed then
			SafeCall(set, r, g, b, a)
		end
	end

	swatch:SetScript("OnClick", function()
		if row._disabled then return end
		if not ColorPickerFrame then return end
		HideUIPanel(ColorPickerFrame)
		ColorPickerFrame._suiOwner = row
		ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")

		local cr, cg, cb, ca = row._r or 1, row._g or 1, row._b or 1, (row._a == nil) and 1 or row._a
		local cancelled = false

		local function CurrentAlpha()
			if row._hasAlpha and OpacitySliderFrame then
				return 1 - (OpacitySliderFrame:GetValue() or 0)
			end
			return 1
		end

		ColorPickerFrame.func = function()
			local r, g, b = ColorPickerFrame:GetColorRGB()
			ColorCallback(r, g, b, CurrentAlpha(), false)
		end

		ColorPickerFrame.hasOpacity = row._hasAlpha
		if row._hasAlpha then
			ColorPickerFrame.opacity = 1 - (ca or 0)
			ColorPickerFrame.opacityFunc = function()
				local r, g, b = ColorPickerFrame:GetColorRGB()
				ColorCallback(r, g, b, CurrentAlpha(), false)
			end
		else
			ColorPickerFrame.opacityFunc = nil
		end

		ColorPickerFrame:SetColorRGB(cr, cg, cb)
		ColorPickerFrame.cancelFunc = function()
			cancelled = true
			ColorCallback(cr, cg, cb, ca, true)
		end
		-- WotLK has OK/Cancel. Apply on close unless Cancel already restored.
		ColorPickerFrame._suiOnHide = function()
			if cancelled then return end
			local r, g, b = ColorPickerFrame:GetColorRGB()
			ColorCallback(r, g, b, CurrentAlpha(), true)
		end
		if not ColorPickerFrame._suiHideHooked then
			ColorPickerFrame._suiHideHooked = true
			ColorPickerFrame:HookScript("OnHide", function()
				local fn = ColorPickerFrame._suiOnHide
				ColorPickerFrame._suiOnHide = nil
				if fn then fn() end
				if ColorPickerFrame._suiOwner then
					ColorPickerFrame._suiOwner = nil
					ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = nil, nil, nil
				end
			end)
		end

		ShowUIPanel(ColorPickerFrame)
	end)
	swatch:SetScript("OnEnter", function(self)
		NotifyPreview(nil, false)
	end)
	swatch:SetScript("OnLeave", function()
		HideCooltip()
		if row._previewKey then
			local pvpPreview = SUI.FramePvpPreview
			if pvpPreview and pvpPreview.SetActiveKey then
				pvpPreview:SetActiveKey(nil)
			end
		end
	end)

	row.SetDisabled = function(self, disabled)
		self._disabled = disabled and true or false
		T:SetTextColor(label, disabled and "disabled" or "text")
		local border = disabled and T.colors.disabled or T.colors.border
		T:ApplyFlat(swatch, T.colors.inputBg, border)
	end

	row:Refresh()
	return row
end

function W:Slider(parent, text, minV, maxV, step, get, set, previewKey, tooltipFn, liveApply)
	minV = tonumber(minV) or 0
	maxV = tonumber(maxV) or 100
	step = tonumber(step) or 1
	if step <= 0 then step = 1 end

	local row = CreateFrame("Frame", nil, parent, nil, "widgets:18")
	if SUI.OptionsPool then
		SUI.OptionsPool:OnRelease(row, function()
			if SUI._optionsSliderDragRow == row then EndOptionsSliderDrag(true) end
		end)
	end
	row:SetHeight(34)
	row._suiValueWidget = true
	row._previewKey = previewKey
	-- Default: ordinary slider - drag applies immediately. Opt out with suiLiveApply=false.
	if liveApply == false then
		row._liveApply = false
	else
		row._liveApply = true
	end

	local label = MakeLabel(row, text)
	label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	local titleWidth = label:GetStringWidth() or 0

	-- On 3.3.5 the scroll child does not paint native EditBox text correctly.
	-- Keep the EditBox on UIParent from creation so focus and selection survive.
	local editW = 56
	local ac = T.colors.accent
	local box = CreateFrame("Frame", nil, row, nil, "widgets:19")
	box:SetSize(editW, 16)
	box:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
	box:SetFrameLevel((row:GetFrameLevel() or 0) + 6)
	T:ApplyFlat(box, T.colors.inputBg, T.colors.borderSoft)
	local valueFS = box:CreateFontString(nil, "OVERLAY", T.fonts.small)
	valueFS:SetPoint("LEFT", box, "LEFT", 2, 0)
	valueFS:SetPoint("RIGHT", box, "RIGHT", -4, 0)
	valueFS:SetJustifyH("RIGHT")
	valueFS:SetWordWrap(false)
	valueFS:SetTextColor(ac[1], ac[2], ac[3], 1)
	row.valueText = valueFS

	label:SetJustifyH("LEFT")
	label:SetWordWrap(false)
	local function PlaceHelpAfterLabel()
		if titleWidth <= 0 then
			label:SetWidth(1000)
			titleWidth = label:GetStringWidth() or 0
		end
		local rowWidth = row:GetWidth() or 0
		local reserve = editW + 6
		local available = rowWidth > reserve and rowWidth - reserve or titleWidth
		label:SetWidth(math.max(1, math.min(titleWidth, available)))
	end

	local edit = CreateFrame("EditBox", nil, UIParent, nil, "widgets:20", row)
	row.edit = edit
	edit:SetAllPoints(box)
	edit:SetFrameStrata("FULLSCREEN_DIALOG")
	edit:SetAutoFocus(false)
	edit:SetFontObject(T.fonts.small)
	edit:SetJustifyH("RIGHT")
	edit:SetTextInsets(2, 4, 0, 0)
	edit:SetNumeric(false)
	edit:SetTextColor(ac[1], ac[2], ac[3], 0)
	-- The FontString shows the idle value; focused editing uses native text and selection.
	if edit.SetHighlightColor then
		edit:SetHighlightColor(ac[1], ac[2], ac[3], 0.25)
	end
	edit:SetScript("OnTextChanged", function(self)
		valueFS:SetText(self:GetText() or "")
	end)

	-- Visual Slider only - native thumb drag on 3.3.5 snaps back when capture
	-- is lost (scroll/parent). All interaction goes through an overlay hit button.
	local slider = CreateFrame("Slider", nil, row, nil, "widgets:21")
	slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
	slider:SetPoint("RIGHT", box, "LEFT", -6, 0)
	slider:SetHeight(12)
	slider:SetOrientation("HORIZONTAL")
	slider:SetMinMaxValues(minV, maxV)
	slider:SetValueStep(step)
	slider:EnableMouse(false)
	T:ApplyFlat(slider, T.colors.inputBg, T.colors.borderSoft)

	local thumb = slider:CreateTexture(nil, "OVERLAY")
	thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
	thumb:SetSize(8, 14)
	thumb:SetVertexColor(ac[1], ac[2], ac[3], 1)
	slider:SetThumbTexture(thumb)

	local hit = CreateFrame("Button", nil, row, nil, "widgets:22")
	hit:SetAllPoints(slider)
	hit:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
	hit:EnableMouse(true)
	hit:SetFrameLevel((slider:GetFrameLevel() or 0) + 2)

	local function Round(v)
		return floor(v / step + 0.5) * step
	end

	local function Clamp(v)
		if v < minV then return minV end
		if v > maxV then return maxV end
		return v
	end

	local function FormatValue(v)
		-- Avoid long floats like 1.2000000001 for common steps.
		if step >= 1 then
			return tostring(floor(v + 0.00001))
		end
		local s = string.format("%.4f", v):gsub("0+$", ""):gsub("%.$", "")
		return s
	end

	local function NotifyPreview(value, live)
		W:NotifyOptionPreview(row._previewKey, value, live)
	end

	row._pending = nil

	local function SetVisual(v, skipEdit)
		row._suppress = true
		slider:SetValue(v)
		-- Must be AND: never clobber the edit box while the user is typing.
		if (not skipEdit) and (not edit:HasFocus()) then
			edit:SetText(FormatValue(v))
		end
		row._suppress = nil
	end

	local function ValueFromCursor()
		local x = GetCursorPosition()
		local scale = slider:GetEffectiveScale() or 1
		if scale == 0 then scale = 1 end
		x = x / scale
		local left = slider:GetLeft()
		local width = slider:GetWidth()
		if not left or not width or width <= 0 then
			return row._pending or minV
		end
		local pct = (x - left) / width
		if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
		return Clamp(Round(minV + (maxV - minV) * pct))
	end

	row.Refresh = function(self)
		if row._dragging or edit:HasFocus() then
			return
		end
		local v = tonumber(SafeCall(get)) or minV
		v = Clamp(Round(v))
		SetVisual(v)
	end

	row.RefreshExternal = function(self)
		row._externalSync = true
		if edit:HasFocus() then
			edit:ClearFocus()
		end
		row._externalSync = nil
		local v = tonumber(SafeCall(get)) or minV
		v = Clamp(Round(v))
		SetVisual(v)
	end

	local function IsIncompleteNumber(raw)
		if not raw or raw == "" then
			return true
		end
		-- Allow typing "-", "-.", ".", "514." before the value is complete.
		return raw:match("^[%-]?%.?$") ~= nil or raw:match("^[%-]?%d+%.$") ~= nil
	end

	local function CommitTyped()
		if row._committing or row._dragging then return end
		row._committing = true
		local raw = edit:GetText()
		raw = raw and raw:gsub(",", ".") or ""
		raw = raw:gsub("%s+", "")
		if IsIncompleteNumber(raw) then
			-- Focus lost on incomplete input -> revert, do not fight the user mid-type.
			local v = tonumber(SafeCall(get)) or minV
			v = Clamp(Round(v))
			edit:SetText(FormatValue(v))
			row._committing = nil
			return
		end
		local n = tonumber(raw)
		if not n then
			local v = tonumber(SafeCall(get)) or minV
			v = Clamp(Round(v))
			edit:SetText(FormatValue(v))
			row._committing = nil
			return
		end
		n = Clamp(Round(n))
		SetVisual(n)
		SafeCall(set, n)
		row._committing = nil
	end

	local function StopDrag()
		if not row._dragging then
			EndOptionsSliderDrag()
			return
		end
		local v = row._pending
		row._pending = nil
		row._dragging = nil
		row._liveDirty = nil
		EndOptionsSliderDrag()
		if v ~= nil then
			SafeCall(set, v)
		end
	end

	-- Ordinary slider: thumb -> preview every step; set() ~30/sec so heavy
	-- ApplySettings cannot stall the drag. Final set() always runs on mouse-up.
	local LIVE_APPLY_INTERVAL = 0.03
	local function LiveApplyPending()
		if not row._liveApply or row._pending == nil then return end
		local now = GetTime()
		if row._lastLiveAt and (now - row._lastLiveAt) < LIVE_APPLY_INTERVAL then
			row._liveDirty = true
			return
		end
		row._lastLiveAt = now
		row._liveDirty = nil
		SafeCall(set, row._pending)
	end

	local function ApplyDragValue(v)
		if v == nil then return end
		if row._pending == v then
			return
		end
		SetVisual(v)
		row._pending = v
		NotifyPreview(v, true)
		if row._liveApply then
			LiveApplyPending()
		end
	end

	local function DragOnUpdate()
		if not row._dragging then
			return
		end
		ApplyDragValue(ValueFromCursor())
		-- Flush throttled set() so the real frame keeps up while dragging.
		if row._liveApply and row._liveDirty then
			LiveApplyPending()
		end
	end

	-- RegisterForDrag -> OnDragStop fires on release even outside the hit rect.
	hit:RegisterForDrag("LeftButton")
	hit:SetScript("OnMouseDown", function(_, button)
		if row._disabled or button ~= "LeftButton" then return end
		if edit:HasFocus() then
			edit:ClearFocus()
		end
		row._dragging = true
		ApplyDragValue(ValueFromCursor())
		BeginOptionsSliderDrag(row, DragOnUpdate, StopDrag)
	end)
	hit:SetScript("OnMouseUp", function(_, button)
		if button and button ~= "LeftButton" then return end
		StopDrag()
	end)
	hit:SetScript("OnDragStop", function()
		StopDrag()
	end)
	-- Do NOT StopDrag on OnHide: live-apply set() can reflow/hide parents for a
	-- frame and was aborting the drag while LMB was still held.

	local function NotifyPreviewEnter()
		if row._dragging and row._pending ~= nil then
			NotifyPreview(row._pending, true)
		else
			NotifyPreview(nil, false)
		end
	end
	hit:SetScript("OnEnter", NotifyPreviewEnter)

	-- Native OnValueChanged is unused for input (mouse disabled); keep guard anyway.
	slider:SetScript("OnValueChanged", function()
		-- no-op: visuals are driven only by SetVisual / Refresh
	end)

	edit:SetScript("OnEditFocusGained", function()
		valueFS:Hide()
		edit:SetTextColor(ac[1], ac[2], ac[3], 1)
		BeginOptionsTextEdit()
	end)
	edit:SetScript("OnEnterPressed", function()
		CommitTyped()
		edit:ClearFocus()
	end)
	edit:SetScript("OnEditFocusLost", function()
		if not row._externalSync and not (row._disabled or row._committing or row._dragging) then
			CommitTyped()
		end
		edit:SetTextColor(ac[1], ac[2], ac[3], 0)
		valueFS:Show()
		EndOptionsTextEdit()
	end)
	edit:SetScript("OnEscapePressed", function(self)
		if row._dragging then return end
		local v = tonumber(SafeCall(get)) or minV
		v = Clamp(Round(v))
		edit:SetText(FormatValue(v))
		self:ClearFocus()
	end)

	row.SetDisabled = function(self, disabled)
		self._disabled = disabled
		if disabled then
			if row._dragging then
				StopDrag()
			end
			hit:Disable()
			SetEditBoxEnabled(edit, false)
			T:SetTextColor(label, "disabled")
			valueFS:SetTextColor(0.45, 0.45, 0.45, 1)
			edit:SetTextColor(0.45, 0.45, 0.45, 0)
		else
			hit:Enable()
			SetEditBoxEnabled(edit, true)
			T:SetTextColor(label, "text")
			valueFS:SetTextColor(ac[1], ac[2], ac[3], 1)
			edit:SetTextColor(ac[1], ac[2], ac[3], edit:HasFocus() and 1 or 0)
		end
	end

	local function RefreshShownValue()
		if row._dragging or edit:HasFocus() or row._sizing then return end
		row._sizing = true
		row:Refresh()
		row._sizing = nil
	end
	-- SetText while the row is still being placed does not draw. Reapply once
	-- the edit box is actually on screen (glow-type changes rebuild this page).
	edit:SetScript("OnShow", RefreshShownValue)
	row:SetScript("OnSizeChanged", function(_, width)
		if not width or width < 20 then return end
		PlaceHelpAfterLabel()
		RefreshShownValue()
	end)
	row:SetScript("OnShow", function()
		if edit:GetParent() ~= UIParent then edit:SetParent(UIParent) end
		edit:Show()
		PlaceHelpAfterLabel()
	end)
	row:SetScript("OnHide", function()
		row._externalSync = true
		if edit:HasFocus() then edit:ClearFocus() end
		row._externalSync = nil
		edit:Hide()
		edit:SetParent(nil)
	end)
	PlaceHelpAfterLabel()
	row:Refresh()
	return row
end

function W:Input(parent, text, get, set)
	local row = CreateFrame("Frame", nil, parent, nil, "widgets:23")
	row:SetHeight(34)

	local label = MakeLabel(row, text)
	label:SetPoint("TOPLEFT", 0, 0)

	local edit = CreateFrame("EditBox", nil, row, nil, "widgets:24")
	edit:SetAutoFocus(false)
	edit:SetHeight(T.sizes.controlH or 20)
	edit:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
	edit:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	edit:SetFontObject(T.fonts.normal)
	T:ApplyFlat(edit, T.colors.inputBg, T.colors.borderSoft)
	edit:SetTextInsets(6, 6, 0, 0)

	row.Refresh = function(self)
		if edit:HasFocus() then
			return
		end
		local v = SafeCall(get)
		edit:SetText(v ~= nil and tostring(v) or "")
	end

	local function Commit()
		SafeCall(set, edit:GetText())
		edit:ClearFocus()
	end

	edit:SetScript("OnEditFocusGained", function()
		BeginOptionsTextEdit()
	end)
	edit:SetScript("OnEnterPressed", Commit)
	edit:SetScript("OnEditFocusLost", function()
		EndOptionsTextEdit()
	end)
	edit:SetScript("OnEscapePressed", function(self)
		row:Refresh()
		self:ClearFocus()
	end)

	row.SetDisabled = function(self, disabled)
		SetEditBoxEnabled(edit, not disabled)
		T:SetTextColor(label, disabled and "disabled" or "text")
	end

	row:Refresh()
	return row
end

-- Details-like create profile: edit box + Save button on the same row.
-- Empty/nil text -> single-line input + button (no label above).
-- clearOnSave (default true): wipe the box after commit (add-to-list / new name).
-- Pass false to keep/show the saved value (settings fields with OK).
function W:InputWithButton(parent, text, buttonText, get, set, clearOnSave)
	if clearOnSave == nil then clearOnSave = true end
	local row = CreateFrame("Frame", nil, parent, nil, "widgets:25")
	local hasLabel = type(text) == "string" and text:gsub("%s+", "") ~= ""

	local label
	if hasLabel then
		row:SetHeight(34)
		label = MakeLabel(row, text)
		label:SetPoint("TOPLEFT", 0, 0)
	else
		row:SetHeight(T.sizes.controlH or 20)
	end

	local btnW = 90
	local btn = CreateFrame("Button", nil, row, nil, "widgets:26")
	btn:SetHeight(T.sizes.controlH or 20)
	btn:SetWidth(btnW)
	T:ApplyFlat(btn, T.colors.buttonBg, T.colors.borderSoft)
	local btnLabel = MakeLabel(btn, buttonText or TUI("ui.options_4864057d62"), T.fonts.normal)
	btnLabel:SetPoint("CENTER")
	btn.label = btnLabel
	function row:SetLabels(labelText, actionText)
		if label then label:SetText(labelText) end
		btnLabel:SetText(actionText)
	end

	local edit = CreateFrame("EditBox", nil, row, nil, "widgets:27")
	edit:SetAutoFocus(false)
	edit:SetHeight(T.sizes.controlH or 20)
	if hasLabel then
		edit:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
	else
		edit:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	end
	edit:SetPoint("RIGHT", row, "RIGHT", -(btnW + 4), 0)
	edit:SetFontObject(T.fonts.normal)
	T:ApplyFlat(edit, T.colors.inputBg, T.colors.borderSoft)
	edit:SetTextInsets(6, 6, 0, 0)

	btn:SetPoint("LEFT", edit, "RIGHT", 4, 0)
	btn:SetPoint("TOP", edit, "TOP", 0, 0)

	row.Refresh = function(self)
		if edit:HasFocus() then
			return
		end
		local v = SafeCall(get)
		edit:SetText(v ~= nil and tostring(v) or "")
	end

	local function Commit()
		local value = edit:GetText()
		SUI._optionsTextEditing = nil
		SafeCall(set, value)
		if clearOnSave then
			edit:SetText("")
		else
			row:Refresh()
		end
		edit:ClearFocus()
	end

	btn:SetScript("OnEnter", function(self)
		if self._disabled then return end
		T:ApplyFlat(self, T.colors.buttonHover, T.colors.accent)
	end)
	btn:SetScript("OnLeave", function(self)
		T:ApplyFlat(self, T.colors.buttonBg, T.colors.borderSoft)
	end)
	btn:SetScript("OnClick", function(self)
		if self._disabled then return end
		Commit()
	end)

	edit:SetScript("OnEditFocusGained", function()
		BeginOptionsTextEdit()
	end)
	edit:SetScript("OnEnterPressed", Commit)
	edit:SetScript("OnEditFocusLost", function()
		EndOptionsTextEdit()
	end)
	edit:SetScript("OnEscapePressed", function(self)
		row:Refresh()
		self:ClearFocus()
	end)

	row.SetDisabled = function(self, disabled)
		if disabled then
			SetEditBoxEnabled(edit, false)
			btn._disabled = true
			T:SetTextColor(btn.label, "disabled")
		else
			SetEditBoxEnabled(edit, true)
			btn._disabled = false
			T:SetTextColor(btn.label, "text")
		end
		if label then
			T:SetTextColor(label, disabled and "disabled" or "text")
		end
	end

	row:Refresh()
	return row
end

-- Two independent drafts committed together by one button (empty fields allowed).
function W:PairedInputWithButton(parent, text, secondText, get, set)
	local row = CreateFrame("Frame", nil, parent, nil, "widgets:28")
	row:SetHeight(36)
	local firstLabel, secondLabel = MakeLabel(row, text), MakeLabel(row, secondText)
	local first, second = CreateFrame("EditBox", nil, row, nil, "widgets:29"), CreateFrame("EditBox", nil, row, nil, "widgets:30")
	local button = CreateFrame("Button", nil, row, nil, "widgets:31")
	row.inputs, row.button = {first, second}, button
	firstLabel:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	first:SetPoint("TOPLEFT", firstLabel, "BOTTOMLEFT", 0, -2)
	second:SetPoint("LEFT", first, "RIGHT", 8, 0)
	secondLabel:SetPoint("BOTTOMLEFT", second, "TOPLEFT", 0, 2)
	button:SetPoint("LEFT", second, "RIGHT", 8, 0)
	button:SetHeight(T.sizes.controlH or 20)
	T:ApplyFlat(button, T.colors.buttonBg, T.colors.borderSoft)
	local savedText = TUI("ui.options.saved")
	button.label = MakeLabel(button, savedText, T.fonts.normal)
	local buttonWidth = math.max(46, button.label:GetStringWidth() + 16)
	button:SetWidth(buttonWidth)
	button.label:SetText("OK")
	button.label:SetPoint("CENTER")
	local dirty, disabled = false, false
	function row:Refresh()
		if dirty or first:HasFocus() or second:HasFocus() then return end
		local values = SafeCall(get) or {}
		first:SetText(values[1] or "")
		second:SetText(values[2] or "")
	end
	local function Commit()
		if disabled then return end
		local values = {first:GetText(), second:GetText()}
		SafeCall(set, values)
		dirty = false
		first:ClearFocus(); second:ClearFocus()
		row:Refresh()
		button.label:SetText(savedText)
		row.savedRemaining = 1
		row:SetScript("OnUpdate", function(self, elapsed)
			self.savedRemaining = self.savedRemaining - elapsed
			if self.savedRemaining <= 0 then
				button.label:SetText("OK")
				self:SetScript("OnUpdate", nil)
			end
		end)
	end
	for _, edit in ipairs(row.inputs) do
		edit:SetAutoFocus(false)
		edit:SetHeight(T.sizes.controlH or 20)
		edit:SetFontObject(T.fonts.normal)
		edit:SetTextInsets(6, 6, 0, 0)
		T:ApplyFlat(edit, T.colors.inputBg, T.colors.borderSoft)
		edit:SetScript("OnTextChanged", function(_, user) if user then dirty = true end end)
		edit:SetScript("OnEditFocusGained", BeginOptionsTextEdit)
		edit:SetScript("OnEditFocusLost", EndOptionsTextEdit)
		edit:SetScript("OnEnterPressed", Commit)
		edit:SetScript("OnTabPressed", function(self)
			self:ClearFocus()
			if self == first then second:SetFocus() else first:SetFocus() end
		end)
		edit:SetScript("OnEscapePressed", function()
			first:ClearFocus(); second:ClearFocus(); dirty = false; row:Refresh()
		end)
	end
	button:SetScript("OnClick", Commit)
	row:SetScript("OnHide", function(self)
		self:SetScript("OnUpdate", nil)
		button.label:SetText("OK")
	end)
	button:SetScript("OnEnter", function()
		if not disabled then T:ApplyFlat(button, T.colors.buttonHover, T.colors.accent) end
	end)
	button:SetScript("OnLeave", function() T:ApplyFlat(button, T.colors.buttonBg, T.colors.borderSoft) end)
	function row:SetDisabled(value)
		disabled = value and true or false
		for _, edit in ipairs(self.inputs) do SetEditBoxEnabled(edit, not disabled) end
		for _, label in ipairs({firstLabel, secondLabel, button.label}) do
			T:SetTextColor(label, disabled and "disabled" or "text")
		end
	end
	row:SetScript("OnSizeChanged", function(self)
		local available = math.max(40, self:GetWidth() - buttonWidth - 16)
		first:SetWidth(available * .65)
		second:SetWidth(available * .35)
	end)
	row:Refresh()
	return row
end

-- Simple dropdown: button + floating list (UIParent).
local openDropdown

function W:IsDropdownOpen()
	return openDropdown ~= nil and openDropdown.list and openDropdown.list:IsShown()
end

local dropdownRefreshQueue = {}
local dropdownRefreshFrame
local function RunDropdownRefresh(self)
    local pending = dropdownRefreshQueue
    dropdownRefreshQueue = {}
    self:SetScript("OnUpdate", nil)
    for _, core in ipairs(pending) do
        if core._open and not W:IsDropdownOpen() then
            SUI._pendingOptionsRefresh = nil
            SafeCall(core.SmartRefresh or core.Refresh, core)
        end
    end
end

local function FlushDeferredOptionsRefresh()
	local OC = SUI.OptionsCore
	if not OC then
		return
	end
	-- A set() made from the open list defers its refresh; closing is the retry point.
	if not OC._refreshAfterDropdown and not SUI._pendingOptionsRefresh then
		return
	end
	OC._refreshAfterDropdown = nil
	if OC._open then
		-- Next frame: avoid re-entrancy from ClearContent -> CloseOpenDropdown.
		dropdownRefreshFrame = dropdownRefreshFrame or CreateFrame("Frame", nil, nil, nil, "widgets:32")
		dropdownRefreshQueue[#dropdownRefreshQueue + 1] = OC
		dropdownRefreshFrame:SetScript("OnUpdate", RunDropdownRefresh)
	end
end

local function OpenDropdownList(row, list, anchor)
	W:CloseOpenDropdown({ suppressRefresh = true })
	if not list or not anchor then
		return false
	end
    -- The popup lives on UIParent, so hiding its owner does not hide it.
    -- Release it before the next page measures its controls.
    if not row._suiDropdownHideHook then
        row._suiDropdownHideHook = true
        row:HookScript("OnHide", function(self)
            if openDropdown == self then W:CloseOpenDropdown() end
        end)
    end
	list:SetParent(UIParent)
	list:SetFrameStrata("FULLSCREEN_DIALOG")
	list:SetFrameLevel(500)
	list:ClearAllPoints()
	-- Open upwards when there is not enough room below the anchor.
	local bottom = anchor:GetBottom()
	local scale = anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
	if bottom and bottom * scale < list:GetHeight() + 8 then
		list:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 2)
	else
		list:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
	end
	local w = anchor:GetWidth() or 0
	if w < 40 then
		w = (T.sizes and T.sizes.controlMaxW) or 320
	end
	list:SetWidth(w)
	list:Show()
	list:Raise()
	openDropdown = row
	return true
end

function W:CloseOpenDropdown(opts)
	opts = opts or {}
	if openDropdown then
		if openDropdown.list then
			openDropdown.list:Hide()
			openDropdown.list:SetScript("OnUpdate", nil)
		end
		openDropdown = nil
	end
	-- ClearContent already rebuilds the page - don't schedule another Refresh.
	if opts.fromClearContent then
		if SUI.OptionsCore then
			SUI.OptionsCore._refreshAfterDropdown = nil
		end
		return
	end
	if opts.suppressRefresh then return end
	FlushDeferredOptionsRefresh()
end

-- One-row: select (left) + edit box + action button (right).
function W:SelectInputButton(parent, selectLabel, valuesFn, getType, setType, inputLabel, getInput, setInput, buttonText, onDraft)
	local row = CreateFrame("Frame", nil, parent, nil, "widgets:33")
	row:SetHeight(40)

	local typeW = 150
	local btnW = 90
	local gap = 6

	local typeLabel = MakeLabel(row, selectLabel or TUI("ui.type_d4a6795c"))
	typeLabel:SetPoint("TOPLEFT", 0, 0)

	local typeBtn = CreateFrame("Button", nil, row, nil, "widgets:34")
	typeBtn:SetHeight(T.sizes.controlH or 20)
	typeBtn:SetWidth(typeW)
	typeBtn:SetPoint("TOPLEFT", typeLabel, "BOTTOMLEFT", 0, -2)
	T:ApplyFlat(typeBtn, T.colors.buttonBg, T.colors.borderSoft)
	local typeText = MakeLabel(typeBtn, "")
	typeText:SetPoint("LEFT", 6, 0)
	typeText:SetPoint("RIGHT", -16, 0)
	local typeArrow = MakeLabel(typeBtn, "v", T.fonts.small)
	typeArrow:SetPoint("RIGHT", -4, 0)
	T:SetTextColor(typeArrow, "accent")

	local idLabel = MakeLabel(row, inputLabel or "ID")
	idLabel:SetPoint("TOPLEFT", typeLabel, "TOPRIGHT", gap + 20, 0)

	local addBtn = CreateFrame("Button", nil, row, nil, "widgets:35")
	addBtn:SetHeight(T.sizes.controlH or 20)
	addBtn:SetWidth(btnW)
	T:ApplyFlat(addBtn, T.colors.buttonBg, T.colors.borderSoft)
	local addLabel = MakeLabel(addBtn, buttonText or TUI("ui.options_559a87f7cc"), T.fonts.normal)
	addLabel:SetPoint("CENTER")
	addBtn.label = addLabel

	local edit = CreateFrame("EditBox", nil, row, nil, "widgets:36")
	edit:SetAutoFocus(false)
	edit:SetHeight(T.sizes.controlH or 20)
	edit:SetPoint("TOPLEFT", typeBtn, "TOPRIGHT", gap, 0)
	edit:SetPoint("RIGHT", row, "RIGHT", -(btnW + gap), 0)
	edit:SetFontObject(T.fonts.normal)
	T:ApplyFlat(edit, T.colors.inputBg, T.colors.borderSoft)
	edit:SetTextInsets(6, 6, 0, 0)

	addBtn:SetPoint("LEFT", edit, "RIGHT", gap, 0)
	addBtn:SetPoint("TOP", edit, "TOP", 0, 0)

	idLabel:ClearAllPoints()
	idLabel:SetPoint("BOTTOMLEFT", edit, "TOPLEFT", 0, 2)

	local list = CreateFrame("Frame", nil, UIParent, nil, "widgets:37", row)
	list:SetFrameStrata("FULLSCREEN_DIALOG")
	list:SetFrameLevel(60)
	list:SetWidth(typeW)
	T:ApplyFlat(list, T.colors.dropdownBg or T.colors.navBg, T.colors.accent)
	list:Hide()
	list:EnableMouse(true)

	local function ResolveValues()
		local v = valuesFn
		if type(v) == "function" then
			local ok, res = pcall(v)
			v = (ok and type(res) == "table") and res or {}
		elseif type(v) ~= "table" then
			v = {}
		end
		return v
	end

	local function LabelFor(key, map)
		if key == nil then return "-" end
		if type(map) == "table" and map[key] ~= nil then
			return tostring(map[key])
		end
		return tostring(key)
	end

	local function RefreshType()
		local map = ResolveValues()
		local cur = SafeCall(getType)
		typeText:SetText(LabelFor(cur, map))
	end

	local function CloseList()
		W:CloseOpenDropdown()
	end

	local function OpenList()
		if openDropdown == row and list:IsShown() then
			CloseList()
			return
		end
		local map = ResolveValues()
		local keys = {}
		local seen = {}
		if type(map.__order) == "table" then
			for _, key in ipairs(map.__order) do
				if map[key] ~= nil then tinsert(keys, key); seen[key] = true end
			end
		end
		local rest = {}
		for key in pairs(map) do
			if key ~= "__order" and not seen[key] then tinsert(rest, key) end
		end
		sort(rest, function(a, b)
			return tostring(LabelFor(a, map)) < tostring(LabelFor(b, map))
		end)
		for _, key in ipairs(rest) do tinsert(keys, key) end
		local y = -4
		list._items = list._items or {}
		for _, item in ipairs(list._items) do
			item:Hide()
		end
		for i, key in ipairs(keys) do
			local item = list._items[i]
			if not item then
				item = CreateFrame("Button", nil, list, nil, "widgets:38")
				item:SetHeight(20)
				local fs = MakeLabel(item, "", T.fonts.small)
				fs:SetPoint("LEFT", 4, 0)
				fs:SetPoint("RIGHT", -4, 0)
				item.label = fs
				list._items[i] = item
			end
			item:ClearAllPoints()
			item:SetPoint("TOPLEFT", 4, y)
			item:SetPoint("TOPRIGHT", -4, y)
			item.label:SetText(LabelFor(key, map))
			item._value = key
			EnsureDropdownItemHighlight(item):Hide()
			item:SetScript("OnEnter", DropdownItem_OnEnter)
			item:SetScript("OnLeave", DropdownItem_OnLeave)
			item:SetScript("OnClick", function(self)
				SafeCall(setType, self._value)
				RefreshType()
				CloseList()
			end)
			item:Show()
			y = y - 20
		end
		list:SetHeight(math.max(28, -y + 4))
		row.list = list
		OpenDropdownList(row, list, typeBtn)
	end

	typeBtn:SetScript("OnClick", function()
		if row._disabled then return end
		OpenList()
	end)
	typeBtn:SetScript("OnEnter", function(self)
		if row._disabled then return end
		T:ApplyFlat(self, T.colors.buttonHover, T.colors.accent)
	end)
	typeBtn:SetScript("OnLeave", function(self)
		T:ApplyFlat(self, T.colors.buttonBg, T.colors.borderSoft)
	end)

	row.edit = edit

	row.Refresh = function(self)
		RefreshType()
		if edit:HasFocus() then
			return
		end
		local v = row._draft
		if v == nil then
			v = SafeCall(getInput)
		end
		edit:SetText(v ~= nil and tostring(v) or "")
	end

	local function RememberDraft(text)
		row._draft = text or ""
		if type(onDraft) == "function" then
			SafeCall(onDraft, row._draft)
		end
	end

	local function Commit()
		local value = edit:GetText()
		row._draft = nil
		-- Drop the typing guard first so Add/Enter can rebuild the spell list now.
		SUI._optionsTextEditing = nil
		SafeCall(setInput, value)
		edit:SetText("")
		edit:ClearFocus()
	end

	edit:SetScript("OnTextChanged", function(self, userInput)
		if not userInput then
			return
		end
		RememberDraft(self:GetText())
	end)
	edit:SetScript("OnEditFocusGained", function()
		BeginOptionsTextEdit()
	end)
	edit:SetScript("OnEditFocusLost", function()
		RememberDraft(edit:GetText())
		EndOptionsTextEdit()
	end)

	addBtn:SetScript("OnEnter", function(self)
		if self._disabled then return end
		T:ApplyFlat(self, T.colors.buttonHover, T.colors.accent)
	end)
	addBtn:SetScript("OnLeave", function(self)
		T:ApplyFlat(self, T.colors.buttonBg, T.colors.borderSoft)
	end)
	addBtn:SetScript("OnClick", function(self)
		if self._disabled then return end
		Commit()
	end)
	edit:SetScript("OnEnterPressed", Commit)
	edit:SetScript("OnEscapePressed", function(self)
		row._draft = nil
		local v = SafeCall(getInput)
		edit:SetText(v ~= nil and tostring(v) or "")
		self:ClearFocus()
	end)

	row.SetDisabled = function(self, disabled)
		self._disabled = disabled and true or false
		if disabled then
			SetEditBoxEnabled(edit, false)
			addBtn._disabled = true
			T:SetTextColor(addLabel, "disabled")
			T:SetTextColor(typeText, "disabled")
		else
			SetEditBoxEnabled(edit, true)
			addBtn._disabled = false
			T:SetTextColor(addLabel, "text")
			T:SetTextColor(typeText, "text")
		end
		T:SetTextColor(typeLabel, disabled and "disabled" or "text")
		T:SetTextColor(idLabel, disabled and "disabled" or "text")
	end

	row.list = list
	row:Refresh()
	return row
end

local activeKeybinding

local ignoreKeys = {
	["BUTTON1"] = true,
	["BUTTON2"] = true,
	["UNKNOWN"] = true,
	["LSHIFT"] = true,
	["LCTRL"] = true,
	["LALT"] = true,
	["RSHIFT"] = true,
	["RCTRL"] = true,
	["RALT"] = true,
}

local function CancelKeybindingCapture(row)
	if not row then return end
	row.waitingForKey = nil
	if row.button then
		row.button:EnableKeyboard(false)
		if row.button.UnlockHighlight then
			row.button:UnlockHighlight()
		end
	end
	if row.msgframe then
		row.msgframe:Hide()
	end
	if activeKeybinding == row then
		activeKeybinding = nil
	end
end

function W:CancelActiveKeybinding()
	if activeKeybinding then
		CancelKeybindingCapture(activeKeybinding)
	end
end

function W:Keybinding(parent, text, get, set, tooltipFn)
	local row = CreateFrame("Frame", nil, parent, nil, "widgets:39")
	local hasLabel = type(text) == "string" and text ~= ""
	row:SetHeight(hasLabel and 44 or 24)
	row.type = "Keybinding"

	local label
	if hasLabel then
		label = MakeLabel(row, text)
		label:SetPoint("TOPLEFT", 0, 0)
		label:SetPoint("TOPRIGHT", 0, 0)
		label:SetJustifyH("LEFT")
	end
	row.label = label

	local button = CreateFrame("Button", nil, row, nil, "widgets:40")
	button:SetHeight(24)
	if label then
		button:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
	else
		button:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	end
	button:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	T:ApplyFlat(button, T.colors.buttonBg, T.colors.borderSoft)
	button:EnableMouse(true)
	button:RegisterForClicks("AnyDown")
	button:EnableKeyboard(false)

	local btnText = MakeLabel(button, "")
	btnText:SetPoint("LEFT", 8, 0)
	btnText:SetPoint("RIGHT", -8, 0)
	btnText:SetJustifyH("CENTER")
	button.label = btnText
	row.button = button

	local msgframe = CreateFrame("Frame", nil, UIParent, nil, "widgets:41", row)
	msgframe:SetHeight(30)
	msgframe:SetFrameStrata("FULLSCREEN_DIALOG")
	msgframe:SetFrameLevel(1000)
	T:ApplyFlat(msgframe, { 0, 0, 0, 0.92 }, T.colors.borderSoft)
	local msg = MakeLabel(msgframe, TUI("ui.options_c80378b10a"))
	msg:SetPoint("LEFT", 8, 0)
	msg:SetPoint("RIGHT", -8, 0)
	msgframe.msg = msg
	msgframe:Hide()
	row.msgframe = msgframe

	local function FormatKey(key)
		if not key or key == "" then
			return TUI("ui.options_bd93263625")
		end
		return tostring(key)
	end

	local function ApplyKeyVisual(key)
		local shown = FormatKey(key)
		btnText:SetText(shown)
		if not key or key == "" then
			T:SetTextColor(btnText, "textDim")
		else
			T:SetTextColor(btnText, "text")
		end
	end

	local function FinishCapture(keyPressed)
		CancelKeybindingCapture(row)
		if row._disabled then return end
		ApplyKeyVisual(keyPressed)
		if set then
			set(keyPressed ~= "" and keyPressed or nil)
		end
	end

	local function OnKeyDown(_, key)
		if not row.waitingForKey then return end
		local keyPressed = key
		if keyPressed == "ESCAPE" then
			keyPressed = ""
		else
			if ignoreKeys[keyPressed] then return end
			if IsShiftKeyDown() then
				keyPressed = "SHIFT-" .. keyPressed
			end
			if IsControlKeyDown() then
				keyPressed = "CTRL-" .. keyPressed
			end
			if IsAltKeyDown() then
				keyPressed = "ALT-" .. keyPressed
			end
		end
		FinishCapture(keyPressed)
	end

	local function OnMouseDown(_, buttonName)
		if buttonName == "LeftButton" or buttonName == "RightButton" then
			return
		elseif buttonName == "MiddleButton" then
			buttonName = "BUTTON3"
		elseif buttonName == "Button4" then
			buttonName = "BUTTON4"
		elseif buttonName == "Button5" then
			buttonName = "BUTTON5"
		end
		OnKeyDown(nil, buttonName)
	end

	button:SetScript("OnClick", function(_, clickButton)
		if row._disabled then return end
		HideCooltip()
		if clickButton ~= "LeftButton" and clickButton ~= "RightButton" then
			return
		end
		if row.waitingForKey then
			CancelKeybindingCapture(row)
			return
		end
		W:CancelActiveKeybinding()
		W:CloseOpenDropdown()
		row.waitingForKey = true
		activeKeybinding = row
		button:EnableKeyboard(true)
		msgframe:ClearAllPoints()
		msgframe:SetPoint("BOTTOM", button, "TOP", 0, 4)
		msgframe:SetWidth(math.max(280, (button:GetWidth() or 200) + 20))
		msgframe:Show()
	end)
	button:SetScript("OnKeyDown", OnKeyDown)
	button:SetScript("OnMouseDown", OnMouseDown)
	button:SetScript("OnEnter", function(self)
		if row._disabled then return end
		T:ApplyFlat(self, T.colors.buttonHover, T.colors.accent)
	end)
	button:SetScript("OnLeave", function(self)
		T:ApplyFlat(self, T.colors.buttonBg, T.colors.borderSoft)
		HideCooltip()
	end)
	row:SetScript("OnHide", function()
		CancelKeybindingCapture(row)
	end)

	row.SetDisabled = function(self, disabled)
		self._disabled = disabled and true or false
		if disabled then
			CancelKeybindingCapture(self)
			button:Disable()
			if label then T:SetTextColor(label, "disabled") end
			T:SetTextColor(btnText, "disabled")
		else
			button:Enable()
			if label then T:SetTextColor(label, "text") end
			ApplyKeyVisual(get and get() or nil)
		end
	end

	row.Refresh = function(self)
		if self.waitingForKey then return end
		ApplyKeyVisual(get and get() or nil)
	end

	row:Refresh()
	return row
end

function W:Dropdown(parent, text, values, get, set, placeholder, flagPathFn, inlineLabel)
	local row = CreateFrame("Frame", nil, parent, nil, "widgets:42")
	local hasLabel = type(text) == "string" and text ~= ""
	local sideLabel = hasLabel and inlineLabel and true or false
	row:SetHeight((hasLabel and not sideLabel) and 40 or 22)
	placeholder = placeholder or "-"
	if type(flagPathFn) ~= "function" then
		flagPathFn = nil
	end

	local label
	if hasLabel then
		label = MakeLabel(row, text)
		if sideLabel then
			label:SetPoint("LEFT", row, "LEFT", 0, 0)
			label:SetWidth((T.sizes and T.sizes.inlineLabelW) or 120)
			label:SetJustifyH("LEFT")
		else
			label:SetPoint("TOPLEFT", 0, 0)
		end
	end
	row.label = label

	local btn = CreateFrame("Button", nil, row, nil, "widgets:43")
	btn:SetHeight(22)
	if label and sideLabel then
		btn:SetPoint("LEFT", label, "RIGHT", 8, 0)
		btn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	elseif label then
		btn:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
		btn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	else
		btn:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
		btn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	end
	T:ApplyFlat(btn, T.colors.buttonBg, T.colors.borderSoft)

	local flagIcon = btn:CreateTexture(nil, "OVERLAY")
	flagIcon:SetSize(12, 8)
	flagIcon:SetPoint("LEFT", 6, 0)
	flagIcon:Hide()
	btn.flagIcon = flagIcon

	local btnText = MakeLabel(btn, "")
	btnText:SetPoint("LEFT", 8, 0)
	btnText:SetPoint("RIGHT", -18, 0)

	local arrow = MakeLabel(btn, "v", T.fonts.small)
	arrow:SetPoint("RIGHT", -6, 0)
	T:SetTextColor(arrow, "accent")

	local function ApplyFlag(tex, key)
		if not tex then
			return false
		end
		local path = flagPathFn and key and flagPathFn(key) or nil
		if type(path) == "string" and path ~= "" then
			tex:SetTexture(path)
			tex:Show()
			return true
		end
		tex:SetTexture(nil)
		tex:Hide()
		return false
	end

	local list = CreateFrame("Frame", nil, UIParent, nil, "widgets:44", row)
	list:SetFrameStrata("FULLSCREEN_DIALOG")
	list:SetFrameLevel(60)
	list:SetWidth((T.sizes and T.sizes.controlMaxW) or 320)
	T:ApplyFlat(list, T.colors.dropdownBg or T.colors.navBg, T.colors.accent)
	list:Hide()
	list:EnableMouse(true)
	row.list = list
	row.btn = btn

	local listScroll = CreateFrame("ScrollFrame", nil, list, nil, "widgets:45")
	listScroll:SetPoint("TOPLEFT", 4, -4)
	listScroll:SetPoint("BOTTOMRIGHT", -20, 4)
	local listContent = CreateFrame("Frame", nil, listScroll, nil, "widgets:46")
	listContent:SetWidth(((T.sizes and T.sizes.controlMaxW) or 320) - 24)
	listContent:SetHeight(1)
	listScroll:SetScrollChild(listContent)
	local listSlider = CreateFrame("Slider", nil, list, nil, "widgets:47")
	listSlider:SetWidth(12)
	listSlider:SetPoint("TOPRIGHT", -4, -5)
	listSlider:SetPoint("BOTTOMRIGHT", -4, 5)
	listSlider:SetOrientation("VERTICAL")
	listSlider:SetMinMaxValues(0, 1)
	listSlider:SetValueStep(1)
	T:ApplyFlat(listSlider, T.colors.scrollTrack or T.colors.inputBg, T.colors.borderSoft)
	local listThumb = listSlider:CreateTexture(nil, "OVERLAY")
	listThumb:SetTexture("Interface\\Buttons\\WHITE8X8")
	listThumb:SetSize(10, 24)
	local thumbColor = T.colors.scrollThumb or T.colors.buttonBg
	listThumb:SetVertexColor(thumbColor[1], thumbColor[2], thumbColor[3], thumbColor[4] or 1)
	listSlider:SetThumbTexture(listThumb)
	listSlider:SetScript("OnEnter", function()
		local color = T.colors.scrollThumbHover or T.colors.buttonHover
		listThumb:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
	end)
	listSlider:SetScript("OnLeave", function()
		local color = T.colors.scrollThumb or T.colors.buttonBg
		listThumb:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
	end)
	listSlider:SetScript("OnValueChanged", function(_, value)
		listScroll:SetVerticalScroll(value)
	end)
	local function ScrollList(_, delta)
		local maxScroll = listScroll:GetVerticalScrollRange() or 0
		local nextValue = math.max(0, math.min(maxScroll, (listScroll:GetVerticalScroll() or 0) - delta * 44))
		listSlider:SetValue(nextValue)
	end
	list:EnableMouseWheel(true)
	list:SetScript("OnMouseWheel", ScrollList)
	listScroll:EnableMouseWheel(true)
	listScroll:SetScript("OnMouseWheel", ScrollList)

	local function SyncListWidth()
		local w = btn:GetWidth() or 0
		if w < 40 then
			w = row:GetWidth() or 0
		end
		if w < 40 then
			w = (T.sizes and T.sizes.controlMaxW) or 320
		end
		list:SetWidth(w)
		listContent:SetWidth(math.max(1, w - (listSlider:IsShown() and 24 or 8)))
		return w
	end

	-- Keep dropdown list width in sync with control width.
	row:SetScript("OnSizeChanged", function()
		SyncListWidth()
	end)

	local function ResolveValues()
		local v = values
		if type(v) == "function" then
			local ok, res = pcall(v)
			if ok and type(res) == "table" then
				v = res
			else
				v = {}
			end
		elseif type(v) ~= "table" then
			v = {}
		end
		return v
	end

	local function LabelFor(key, map)
		if key == nil then
			return placeholder
		end
		if type(map) == "table" and map[key] ~= nil then
			return tostring(map[key])
		end
		return tostring(key)
	end

	row.Refresh = function(self)
		local map = ResolveValues()
		local cur = SafeCall(get)
		local hasFlag = false
		if cur == nil or cur == false then
			btnText:SetText(placeholder)
			T:SetTextColor(btnText, "textDim")
			hasFlag = ApplyFlag(flagIcon, nil)
		else
			btnText:SetText(LabelFor(cur, map))
			T:SetTextColor(btnText, "text")
			hasFlag = ApplyFlag(flagIcon, cur)
		end
		btnText:ClearAllPoints()
		if hasFlag then
			btnText:SetPoint("LEFT", flagIcon, "RIGHT", 6, 0)
		else
			btnText:SetPoint("LEFT", 8, 0)
		end
		btnText:SetPoint("RIGHT", -18, 0)
	end

	local function RebuildList()
		if list._buttons then
			for _, b in pairs(list._buttons) do
				b:Hide()
			end
		end
		list._buttons = list._buttons or {}
		local map = ResolveValues()
		local y = -4
		local i = 0
		local keys = {}
		-- Support both hash maps {name=name} and array lists {1="Default"}.
		-- Optional map.__order = { "key1", "key2", ... } preserves dropdown order.
		if type(map) == "table" then
			if type(map.__order) == "table" then
				for _, k in ipairs(map.__order) do
					if k ~= nil and map[k] ~= nil then
						keys[#keys + 1] = k
					end
				end
			else
				local hasStringKeys
				for k, v in pairs(map) do
					if type(k) == "string" and k ~= "__order" and v ~= nil then
						hasStringKeys = true
						keys[#keys + 1] = k
					end
				end
				if not hasStringKeys then
					for _, v in ipairs(map) do
						if v ~= nil then
							keys[#keys + 1] = v
						end
					end
				else
					table.sort(keys, function(a, b)
						return tostring(LabelFor(a, map)) < tostring(LabelFor(b, map))
					end)
				end
			end
		end
		if #keys == 0 then
			local item = list._buttons[1]
			if not item then
				item = CreateFrame("Button", nil, listContent, nil, "widgets:48")
				item:SetHeight(22)
				local icon = item:CreateTexture(nil, "OVERLAY")
				icon:SetSize(12, 8)
				icon:SetPoint("LEFT", 6, 0)
				icon:Hide()
				item.flagIcon = icon
				local ifs = MakeLabel(item, "")
				ifs:SetPoint("LEFT", 8, 0)
				item.label = ifs
				list._buttons[1] = item
			end
			item:Show()
			item:ClearAllPoints()
			item:SetPoint("TOPLEFT", listContent, "TOPLEFT", 0, y + 4)
			item:SetPoint("TOPRIGHT", listContent, "TOPRIGHT", 0, y + 4)
			item.label:SetText(TUI("ui.options_7b3261fc86"))
			T:SetTextColor(item.label, "textDim")
			if item.flagIcon then
				item.flagIcon:Hide()
			end
			item._value = nil
			item:SetScript("OnClick", function()
				W:CloseOpenDropdown()
			end)
			item:SetScript("OnEnter", nil)
			item:SetScript("OnLeave", nil)
			list:SetHeight(30)
			listContent:SetHeight(22)
			listSlider:Hide()
			listScroll:ClearAllPoints()
			listScroll:SetPoint("TOPLEFT", 4, -4)
			listScroll:SetPoint("BOTTOMRIGHT", -4, 4)
			return
		end
		for _, key in ipairs(keys) do
			i = i + 1
			local item = list._buttons[i]
			if not item then
				item = CreateFrame("Button", nil, listContent, nil, "widgets:49")
				item:SetHeight(22)
				local icon = item:CreateTexture(nil, "OVERLAY")
				icon:SetSize(12, 8)
				icon:SetPoint("LEFT", 6, 0)
				icon:Hide()
				item.flagIcon = icon
				local ifs = MakeLabel(item, "")
				ifs:SetPoint("LEFT", 8, 0)
				ifs:SetPoint("RIGHT", -8, 0)
				item.label = ifs
				list._buttons[i] = item
			end
			item:Show()
			item:ClearAllPoints()
			item:SetPoint("TOPLEFT", listContent, "TOPLEFT", 0, y + 4)
			item:SetPoint("TOPRIGHT", listContent, "TOPRIGHT", 0, y + 4)
			item.label:SetText(LabelFor(key, map))
			T:SetTextColor(item.label, "text")
			local hasFlag = ApplyFlag(item.flagIcon, key)
			item.label:ClearAllPoints()
			if hasFlag then
				item.label:SetPoint("LEFT", item.flagIcon, "RIGHT", 6, 0)
			else
				item.label:SetPoint("LEFT", 8, 0)
			end
			item.label:SetPoint("RIGHT", -8, 0)
			item._value = key
			item:SetScript("OnClick", function(self)
				SafeCall(set, self._value)
				W:CloseOpenDropdown()
				row:Refresh()
			end)
			item:EnableMouseWheel(true)
			item:SetScript("OnMouseWheel", ScrollList)
			EnsureDropdownItemHighlight(item):Hide()
			item:SetScript("OnEnter", DropdownItem_OnEnter)
			item:SetScript("OnLeave", DropdownItem_OnLeave)
			y = y - 22
		end
		local contentHeight = math.max(22, i * 22)
		local maxHeight = math.min(8 + 11 * 22, (UIParent:GetHeight() or 600) * 0.45)
		local height = math.max(30, math.min(8 + contentHeight, maxHeight))
		list:SetHeight(height)
		listContent:SetHeight(contentHeight)
		listScroll:SetVerticalScroll(0)
		listSlider:SetMinMaxValues(0, math.max(0, contentHeight - (height - 8)))
		listSlider:SetValue(0)
		local scrollable = 8 + contentHeight > height
		if scrollable then listSlider:Show() else listSlider:Hide() end
		listScroll:ClearAllPoints()
		listScroll:SetPoint("TOPLEFT", 4, -4)
		listScroll:SetPoint("BOTTOMRIGHT", scrollable and -20 or -4, 4)
	end

	btn:SetScript("OnClick", function()
		if row._disabled then return end
		if openDropdown == row and list:IsShown() then
			W:CloseOpenDropdown()
			return
		end
		RebuildList()
		SyncListWidth()
		OpenDropdownList(row, list, btn)
	end)

	row.SetDisabled = function(self, disabled)
		self._disabled = disabled and true or false
		if label then
			T:SetTextColor(label, disabled and "disabled" or "text")
		end
		T:SetTextColor(btnText, disabled and "disabled" or "textDim")
		T:SetTextColor(arrow, disabled and "disabled" or "accent")
		if flagIcon then
			flagIcon:SetVertexColor(1, 1, 1, disabled and 0.45 or 1)
		end
		if disabled then
			W:CloseOpenDropdown()
			T:ApplyFlat(btn, T.colors.panelBg, T.colors.borderSoft)
		else
			T:ApplyFlat(btn, T.colors.buttonBg, T.colors.borderSoft)
			self:Refresh()
		end
	end

	row:Refresh()
	return row
end

-- Select dropdown + action button on one row (e.g. nameplate type + Settings).
-- Optional label on top; dropdown and button share the same baseline.
function W:SelectWithButton(parent, selectLabel, values, get, set, buttonText, onClick, buttonTooltipFn, buttonHiddenFn)
	local row = CreateFrame("Frame", nil, parent, nil, "widgets:50")
	row._buttonHiddenFn = buttonHiddenFn

	local hasLabel = type(selectLabel) == "string" and selectLabel:gsub("%s+", "") ~= ""
	local label
	if hasLabel then
		label = MakeLabel(row, selectLabel)
		label:SetPoint("TOPLEFT", 0, 0)
		row:SetHeight(40)
	else
		row:SetHeight(22)
	end

	local actionBtn = self:Button(row, buttonText or TUI("ui.settings_985b5e0f"), onClick, buttonTooltipFn)
	actionBtn:SetWidth(120)
	actionBtn:SetHeight(22)
	actionBtn:ClearAllPoints()
	if hasLabel then
		actionBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -16)
	else
		actionBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
	end

	local drop = self:Dropdown(row, "", values, get, set)
	drop:ClearAllPoints()
	drop:SetHeight(22)
	if hasLabel then
		drop:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
		drop:SetPoint("TOPRIGHT", actionBtn, "TOPLEFT", -8, 0)
	else
		drop:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
		drop:SetPoint("TOPRIGHT", actionBtn, "TOPLEFT", -8, 0)
	end
	if drop.btn then
		drop.btn:ClearAllPoints()
		drop.btn:SetPoint("TOPLEFT", drop, "TOPLEFT", 0, 0)
		drop.btn:SetPoint("BOTTOMRIGHT", drop, "BOTTOMRIGHT", 0, 0)
	end

	local function SyncButtonVisibility()
		local hide = false
		if type(row._buttonHiddenFn) == "function" then
			local ok, res = pcall(row._buttonHiddenFn)
			hide = ok and res and true or false
		end
		if hide then
			actionBtn:Hide()
			drop:ClearAllPoints()
			if hasLabel then
				drop:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
				drop:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -16)
			else
				drop:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
				drop:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
			end
		else
			actionBtn:Show()
			drop:ClearAllPoints()
			if hasLabel then
				drop:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
				drop:SetPoint("TOPRIGHT", actionBtn, "TOPLEFT", -8, 0)
			else
				drop:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
				drop:SetPoint("TOPRIGHT", actionBtn, "TOPLEFT", -8, 0)
			end
		end
	end

	row.Refresh = function(self)
		if drop.Refresh then drop:Refresh() end
		SyncButtonVisibility()
	end
	row.SetDisabled = function(self, disabled)
		if drop.SetDisabled then drop:SetDisabled(disabled) end
		if actionBtn.SetDisabled then actionBtn:SetDisabled(disabled) end
		if label then
			T:SetTextColor(label, disabled and "disabled" or "text")
		end
	end

	row.drop = drop
	row.actionBtn = actionBtn
	row:Refresh()
	return row
end

function W:SelectWithColor(parent, selectLabel, values, get, set, getColor, setColor, hasAlpha, colorTooltipFn, colorHiddenFn, colorPreviewKey, selectPreviewKey)
	local row = CreateFrame("Frame", nil, parent, nil, "widgets:51")
	row._colorHiddenFn = colorHiddenFn
	row:SetHeight(22)

	local colorRow = self:ColorPicker(row, "", getColor, setColor, hasAlpha and true or false, colorTooltipFn, colorPreviewKey)
	colorRow:SetHeight(22)
	colorRow:SetWidth(28)
	colorRow:ClearAllPoints()
	colorRow:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
	if colorRow.label then
		colorRow.label:Hide()
	end

	local drop = self:Dropdown(row, "", values, get, function(value)
		set(value)
		if selectPreviewKey then
			W:NotifyOptionPreview(selectPreviewKey, value, true)
		end
		if row.Refresh then row:Refresh() end
	end)
	drop:ClearAllPoints()
	drop:SetHeight(22)
	drop:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	drop:SetPoint("TOPRIGHT", colorRow, "TOPLEFT", -8, 0)
	if drop.btn then
		drop.btn:ClearAllPoints()
		drop.btn:SetPoint("TOPLEFT", drop, "TOPLEFT", 0, 0)
		drop.btn:SetPoint("BOTTOMRIGHT", drop, "BOTTOMRIGHT", 0, 0)
		if selectPreviewKey then
			drop.btn:SetScript("OnEnter", function()
				W:NotifyOptionPreview(selectPreviewKey, nil, false)
			end)
			drop.btn:SetScript("OnLeave", function()
				local pvpPreview = SUI.FramePvpPreview
				if pvpPreview and pvpPreview.SetActiveKey then
					pvpPreview:SetActiveKey(nil)
				end
			end)
		end
	end

	local function SyncColorVisibility()
		local hide = false
		if type(row._colorHiddenFn) == "function" then
			local ok, res = pcall(row._colorHiddenFn)
			hide = ok and res and true or false
		end
		if hide then
			colorRow:Hide()
			drop:ClearAllPoints()
			drop:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
			drop:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
		else
			colorRow:Show()
			drop:ClearAllPoints()
			drop:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
			drop:SetPoint("TOPRIGHT", colorRow, "TOPLEFT", -8, 0)
		end
		if drop.btn then
			drop.btn:ClearAllPoints()
			drop.btn:SetPoint("TOPLEFT", drop, "TOPLEFT", 0, 0)
			drop.btn:SetPoint("BOTTOMRIGHT", drop, "BOTTOMRIGHT", 0, 0)
		end
	end

	row.Refresh = function(self)
		if drop.Refresh then drop:Refresh() end
		if colorRow.Refresh then colorRow:Refresh() end
		SyncColorVisibility()
	end
	row.SetDisabled = function(self, disabled)
		if drop.SetDisabled then drop:SetDisabled(disabled) end
		if colorRow.SetDisabled then colorRow:SetDisabled(disabled) end
	end

	row.drop = drop
	row.colorRow = colorRow
	row:Refresh()
	return row
end

-- Compact list row: optional icon + label + optional right action button.
-- Pass buttonText = false/nil and no onClick to hide the button (fixed rows).
function W:CompactListRow(parent, labelText, buttonText, onClick, iconTexture)
	local row = CreateFrame("Frame", nil, parent, nil, "widgets:52")
	local rowH = math.max(T.sizes.controlH or 20, 22)
	row:SetHeight(rowH)

	local rightAnchor = row
	local rightPoint = "RIGHT"
	local rightOffset = 0
	if buttonText ~= false and buttonText ~= nil then
		local btnW = 80
		local btn = self:Button(row, buttonText or TUI("ui.delete_be99b136"), onClick)
		btn:SetWidth(btnW)
		btn:SetHeight(T.sizes.controlH or 20)
		btn:ClearAllPoints()
		btn:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
		row.button = btn
		rightAnchor = btn
		rightPoint = "LEFT"
		rightOffset = -8
	end

	local iconSize = 18
	local leftPad = 0
	if iconTexture and iconTexture ~= "" then
		local icon = row:CreateTexture(nil, "ARTWORK")
		icon:SetSize(iconSize, iconSize)
		icon:SetPoint("LEFT", row, "LEFT", 0, 0)
		icon:SetTexture(iconTexture)
		row.icon = icon
		leftPad = iconSize + 6
	end

	local fs = MakeLabel(row, labelText or "")
	fs:SetPoint("LEFT", row, "LEFT", leftPad, 0)
	fs:SetPoint("RIGHT", rightAnchor, rightPoint, rightOffset, 0)
	fs:SetJustifyH("LEFT")
	row.label = fs
	return row
end

function W:Unsupported(parent, typeName)
	return self:Description(parent, "|cffff8080Unsupported option type:|r " .. tostring(typeName))
end

-- Shared by the window and nested component panes.
function W:Scrollbar(parent, scroll, metrics, onScroll)
    local bar = CreateFrame("Slider", nil, parent, nil, "widgets:53")
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(T.sizes.scrollbarW)
    bar:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", T.sizes.scrollbarW + T.sizes.scrollbarGap, 0)
    bar:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", T.sizes.scrollbarW + T.sizes.scrollbarGap, 0)
    bar:SetMinMaxValues(0, 0)
    bar:SetValueStep(1)
    T:ApplyFlat(bar, T.colors.scrollTrack, T.colors.border)
    bar:SetThumbTexture(T.textures.flat)
    local thumb = bar:GetThumbTexture()
    thumb:SetWidth(T.sizes.scrollbarW)
    thumb:SetVertexColor(unpack(T.colors.scrollThumb))
    local updating = false
    local function Update()
        if updating then return end
        updating = true
        local view, height, maximum = metrics()
        view, height = math.max(0, view or 0), math.max(0, height or 0)
        maximum = math.max(0, maximum or (height - view))
        if maximum <= 1 then maximum = 0 end
        bar:SetMinMaxValues(0, maximum)
        thumb:SetHeight(math.min(view, math.max(20, view * view / math.max(1, height))))
        local previous = scroll:GetVerticalScroll() or 0
        local value = math.max(0, math.min(maximum, previous))
        bar:SetValue(value)
        if scroll:GetVerticalScroll() ~= value then scroll:SetVerticalScroll(value) end
        if maximum > 0 then bar:Show() else bar:Hide() end
        updating = false
        if previous ~= value and onScroll then onScroll(value) end
    end
    bar:SetScript("OnValueChanged", function(_, value)
        if updating then return end
        scroll:SetVerticalScroll(value)
        if onScroll then onScroll(value) end
    end)
    scroll:HookScript("OnScrollRangeChanged", Update)
    scroll:HookScript("OnSizeChanged", Update)
    scroll:HookScript("OnVerticalScroll", function(_, value)
        if math.abs(bar:GetValue() - value) > 0.5 then bar:SetValue(value) end
    end)
    bar:EnableMouseWheel(true)
    bar:SetScript("OnMouseWheel", function(_, delta)
        local lo, hi = bar:GetMinMaxValues()
        bar:SetValue(math.max(lo, math.min(hi, bar:GetValue() - delta * T.sizes.scrollStep)))
    end)
    bar:Hide()
    return bar, Update
end
