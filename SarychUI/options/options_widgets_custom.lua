-- SarychUI Options Widgets — custom controls (no AceGUI visuals).
local SUI = SarychUI
local T = SUI.OptionsTheme
SUI.OptionsWidgets = SUI.OptionsWidgets or {}
local W = SUI.OptionsWidgets

local CreateFrame = CreateFrame
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

-- Non-interactive updater while a slider is dragged.
-- IMPORTANT: do NOT show an EnableMouse fullscreen capture mid-click — on 3.3.5
-- that steals focus and makes IsMouseButtonDown / phantom MouseUp end the drag
-- while LMB is still held. Release is handled by OnDragStop / OnMouseUp on the hit.
local function GetSliderUpdater()
	if W._sliderUpdater then
		return W._sliderUpdater
	end
	local f = CreateFrame("Frame", "SarychUIOptionsSliderUpdater", UIParent)
	f:Hide()
	W._sliderUpdater = f
	return f
end

local function FlushPendingOptionsRefresh()
	if not SUI._pendingOptionsRefresh then
		return
	end
	if SUI._optionsSliderDragging or SUI._optionsTextEditing then
		return
	end
	-- Clear first so NotifySarychUIOptionsChange does not re-defer.
	SUI._pendingOptionsRefresh = nil
	if SUI.NotifySarychUIOptionsChange then
		SUI:NotifySarychUIOptionsChange()
	end
end

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
		-- Widget destroyed (tab switch / full rebuild) — end cleanly.
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

local function EndOptionsSliderDrag()
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
-- Leaving the tab hides/destroys the host → animation stops immediately.
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
	-- Rebinding only swaps the tick fn — never stack OnShow/OnHide hooks.
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
	if frame._suiValueWidget and type(frame.Refresh) == "function" then
		-- Skip the widget the user is actively editing.
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

local function FlushPendingOptionsValueSync()
	if SUI._pendingOptionsValueSync and SUI.SyncOpenOptionsValues then
		SUI:SyncOpenOptionsValues()
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
	if key:find("PVP") or key:find("^pvp") or key:find("^classIconPortraits") then
		return "FramePvpPreview"
	end
	if key:find("^trinkets") then return "ArenaPreview" end
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

-- Notify only mounted preview(s) for this options page — not every preview module.
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
	if self._suiDropHl then
		self._suiDropHl:Hide()
	end
	if self.SetBackdrop then
		self:SetBackdrop(nil)
	end
end

function W:Spacer(parent, height)
	local f = CreateFrame("Frame", nil, parent)
	f:SetHeight(height or 8)
	f:SetWidth(1)
	return f
end

-- Compact spinning icon (same textures as bag-sort spinner) + label.
function W:SpinnerLabel(parent, text)
	local f = CreateFrame("Frame", nil, parent)
	f:SetHeight(22)

	local size = 16
	local SPINNER_TEX_FRAME = "Interface\\AddOns\\SarychUI\\addons\\SarychUI_Bags\\Media\\Textures\\StreamFrame.blp"
	local SPINNER_TEX_CIRCLE = "Interface\\AddOns\\SarychUI\\addons\\SarychUI_Bags\\Media\\Textures\\StreamCircle.blp"
	local SPINNER_TEX_SPARK = "Interface\\AddOns\\SarychUI\\addons\\SarychUI_Bags\\Media\\Textures\\StreamSpark.blp"

	local icon = CreateFrame("Frame", nil, f)
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
	local f = CreateFrame("Frame", nil, parent)
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
	-- No extra internal padding — parent panel/section pad keeps even insets.
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

	f:SetScript("OnSizeChanged", function(self, width)
		if self._measureLock then return end
		-- Skip pre-layout tiny widths — they produce huge wrap that sticks until reselect.
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

function W:Panel(parent)
	local f = CreateFrame("Frame", nil, parent)
	T:ApplyFlat(f, T.colors.panelBg, T.colors.borderSoft)
	f._contentPad = (T.sizes and T.sizes.panelPad) or 8
	return f
end

-- Details Cooltip Preset(2)-like floating tooltip (own frame, not GameTooltip).
-- Textures are vendored under SarychUI/media/cooltip so Details is not required.
local COOLTIP_BG_TEX = (T.textures and T.textures.cooltipBg) or "Interface\\AddOns\\SarychUI\\media\\cooltip\\background"
local COOLTIP_BG = { 0.37, 0.37, 0.37, 0.95 }
local COOLTIP_BORDER = { 0.2, 0.2, 0.2, 1 }
local COOLTIP_ORANGE = { 1, 0.647, 0, 1 }
local COOLTIP_WIDTH = 220
local COOLTIP_PAD = 8
local COOLTIP_LINE_H = 16

local cooltipFrame

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

local function EnsureCooltip()
	if cooltipFrame then
		return cooltipFrame
	end
	local f = CreateFrame("Frame", "SarychUIOptionsCooltip", UIParent)
	f:SetFrameStrata("TOOLTIP")
	f:SetFrameLevel(500)
	f:SetClampedToScreen(true)
	f:EnableMouse(false)
	f:Hide()
	-- Exact Details Cooltip Preset(2) backdrop (local copy).
	local bd = {
		bgFile = COOLTIP_BG_TEX,
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		tile = true,
		tileSize = 16,
		edgeSize = 1,
		insets = { left = 0, right = 0, top = 0, bottom = 0 },
	}
	if f.SetBackdrop then
		f:SetBackdrop(bd)
		f:SetBackdropColor(COOLTIP_BG[1], COOLTIP_BG[2], COOLTIP_BG[3], COOLTIP_BG[4])
		f:SetBackdropBorderColor(COOLTIP_BORDER[1], COOLTIP_BORDER[2], COOLTIP_BORDER[3], COOLTIP_BORDER[4])
	end
	f.lines = {}
	f.fontPath = GetCooltipFontPath()
	cooltipFrame = f
	return f
end

local function HideCooltip()
	if cooltipFrame then
		cooltipFrame:Hide()
	end
end

local function ShowCooltip(anchor, lines)
	if not anchor or type(lines) ~= "table" or #lines == 0 then
		HideCooltip()
		return
	end
	local f = EnsureCooltip()
	for _, fs in pairs(f.lines) do
		fs:Hide()
	end
	local y = -COOLTIP_PAD
	local maxW = COOLTIP_WIDTH - COOLTIP_PAD * 2
	local count = 0
	for i = 1, #lines do
		local line = lines[i]
		local text, r, g, b
		if type(line) == "table" then
			text = tostring(line[1] or "")
			r = line[2] or COOLTIP_ORANGE[1]
			g = line[3] or COOLTIP_ORANGE[2]
			b = line[4] or COOLTIP_ORANGE[3]
		else
			text = tostring(line)
			r, g, b = COOLTIP_ORANGE[1], COOLTIP_ORANGE[2], COOLTIP_ORANGE[3]
		end
		if text ~= "" then
			count = count + 1
			local fs = f.lines[count]
			if not fs then
				fs = f:CreateFontString(nil, "OVERLAY")
				fs:SetJustifyH("LEFT")
				fs:SetJustifyV("TOP")
				fs:SetNonSpaceWrap(true)
				f.lines[count] = fs
			end
			fs:SetFont(f.fontPath or "Fonts\\FRIZQT__.TTF", 12, "")
			fs:SetTextColor(r, g, b, 1)
			fs:SetWidth(maxW)
			fs:SetText(text)
			fs:ClearAllPoints()
			fs:SetPoint("TOPLEFT", f, "TOPLEFT", COOLTIP_PAD, y)
			fs:Show()
			local h = fs:GetStringHeight() or COOLTIP_LINE_H
			y = y - h - 4
		end
	end
	if count == 0 then
		HideCooltip()
		return
	end
	f:SetWidth(COOLTIP_WIDTH)
	f:SetHeight(math.max(28, -y + COOLTIP_PAD))
	f:ClearAllPoints()
	f:SetPoint("BOTTOM", anchor, "TOP", 0, 6)
	f:Show()
end

W.HideCooltip = function()
	HideCooltip()
end

function W:Header(parent, text, tooltipFn, iconPath, helpIcon)
	local f = CreateFrame("Frame", nil, parent)
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

	-- Optional help icon with hover tooltip (when desc / tooltipFn is set).
	if tooltipFn then
		f._tooltipFn = tooltipFn
		local help = CreateFrame("Button", nil, f)
		help:SetSize(14, 14)
		help:SetPoint("LEFT", fs, "RIGHT", 4, 0)
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
			local tipFn = f._tooltipFn
			if not tipFn then return end
			local ok, lines = pcall(tipFn)
			if not ok or not lines then return end
			if type(lines) == "string" and lines ~= "" then
				lines = { { lines, COOLTIP_ORANGE[1], COOLTIP_ORANGE[2], COOLTIP_ORANGE[3] } }
			end
			if type(lines) == "table" then
				ShowCooltip(self, lines)
			end
		end)
		help:SetScript("OnLeave", function()
			HideCooltip()
		end)
		f.help = help
	end

	return f
end

function W:Button(parent, text, onClick, tooltipFn)
	local btn = CreateFrame("Button", nil, parent)
	btn:SetHeight(24)
	btn:SetWidth(120)
	T:ApplyFlat(btn, T.colors.buttonBg, T.colors.borderSoft)
	local fs = MakeLabel(btn, text, T.fonts.normal)
	fs:SetPoint("CENTER")
	btn.label = fs
	btn:SetScript("OnEnter", function(self)
		if self._disabled then return end
		T:ApplyFlat(self, T.colors.buttonHover, T.colors.accent)
		if tooltipFn then
			local ok, lines = pcall(tooltipFn)
			if ok then
				if type(lines) == "string" and lines ~= "" then
					lines = { { lines, COOLTIP_ORANGE[1], COOLTIP_ORANGE[2], COOLTIP_ORANGE[3] } }
				end
				if type(lines) == "table" then
					ShowCooltip(self, lines)
				end
			end
		end
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

function W:Checkbox(parent, text, get, set, tooltipFn, helpIcon, previewKey)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(T.sizes.rowH or 22)
	row:EnableMouse(true)
	row._previewKey = previewKey

	local box = CreateFrame("Button", nil, row)
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
	row._tooltipFn = tooltipFn

	local function ApplyVisual(on)
		row._checked = on and true or false
		if on then check:Show() else check:Hide() end
	end

	local function NotifyPreview(value, live)
		W:NotifyOptionPreview(row._previewKey, value, live)
	end

	local function ShowTip(anchor)
		local tipFn = row._tooltipFn
		if not tipFn then return end
		local ok, lines = pcall(tipFn)
		if not ok or not lines then return end
		if type(lines) == "string" and lines ~= "" then
			lines = { { lines, COOLTIP_ORANGE[1], COOLTIP_ORANGE[2], COOLTIP_ORANGE[3] } }
		end
		if type(lines) == "table" then
			ShowCooltip(anchor, lines)
		end
	end

	local function OnEnterRow(anchor)
		NotifyPreview(nil, false)
		ShowTip(anchor)
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
		end
	end

	-- Optional help icon next to the title (opt-in via helpIcon / suiHelpIcon).
	-- helpIcon: true | texture path string | { path = "...", color = {r,g,b[,a]} }
	if helpIcon and tooltipFn then
		local help = CreateFrame("Button", nil, row)
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
			OnEnterRow(self)
		end)
		help:SetScript("OnLeave", function()
			OnLeaveRow()
		end)
		row.help = help
		row:SetScript("OnEnter", function(self)
			OnEnterRow(self.box or self)
		end)
		row:SetScript("OnLeave", function()
			OnLeaveRow()
		end)
	else
		label:SetPoint("RIGHT", row, "RIGHT", 0, 0)
		box:SetScript("OnEnter", function(self)
			OnEnterRow(self)
		end)
		box:SetScript("OnLeave", function()
			OnLeaveRow()
		end)
		row:SetScript("OnEnter", function(self)
			OnEnterRow(self.box or self)
		end)
		row:SetScript("OnLeave", function()
			OnLeaveRow()
		end)
	end

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

	row.SetTooltip = function(self, fn)
		self._tooltipFn = fn
	end

	row:Refresh()
	return row
end

function W:ColorPicker(parent, text, get, set, hasAlpha, tooltipFn)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(T.sizes.rowH or 22)
	row:EnableMouse(true)
	row._hasAlpha = hasAlpha and true or false
	row._tooltipFn = tooltipFn

	local label = MakeLabel(row, text)
	label:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.label = label

	local swatch = CreateFrame("Button", nil, row)
	swatch:SetSize(22, 16)
	swatch:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	T:ApplyFlat(swatch, T.colors.inputBg, T.colors.border)
	local fill = swatch:CreateTexture(nil, "ARTWORK")
	fill:SetPoint("TOPLEFT", 2, -2)
	fill:SetPoint("BOTTOMRIGHT", -2, 2)
	fill:SetTexture("Interface\\Buttons\\WHITE8X8")
	swatch.fill = fill
	row.swatch = swatch

	local function ShowTip(anchor)
		local tipFn = row._tooltipFn
		if not tipFn then return end
		local ok, lines = pcall(tipFn)
		if not ok or not lines then return end
		if type(lines) == "string" and lines ~= "" then
			lines = { { lines, COOLTIP_ORANGE[1], COOLTIP_ORANGE[2], COOLTIP_ORANGE[3] } }
		end
		if type(lines) == "table" then
			ShowCooltip(anchor, lines)
		end
	end

	local function ApplyColor(r, g, b, a)
		row._r, row._g, row._b, row._a = r or 1, g or 1, b or 1, a or 1
		fill:SetVertexColor(row._r, row._g, row._b, row._hasAlpha and row._a or 1)
	end

	row.Refresh = function(self)
		local ok, r, g, b, a = pcall(get)
		if not ok or type(r) ~= "number" then
			r, g, b, a = 1, 1, 1, 1
		end
		ApplyColor(r, g, b, a)
	end

	local function ColorCallback(r, g, b, a, confirmed)
		if not row._hasAlpha then
			a = 1
		end
		ApplyColor(r, g, b, a)
		if confirmed then
			SafeCall(set, r, g, b, a)
		end
	end

	swatch:SetScript("OnClick", function()
		if row._disabled then return end
		if not ColorPickerFrame then return end
		HideUIPanel(ColorPickerFrame)
		ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")

		local cr, cg, cb, ca = row._r or 1, row._g or 1, row._b or 1, row._a or 1
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
			end)
		end

		ShowUIPanel(ColorPickerFrame)
	end)
	swatch:SetScript("OnEnter", function(self)
		ShowTip(self)
	end)
	swatch:SetScript("OnLeave", function()
		HideCooltip()
	end)
	row:SetScript("OnEnter", function(self)
		ShowTip(self.swatch or self)
	end)
	row:SetScript("OnLeave", function()
		HideCooltip()
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

	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(34)
	row._suiValueWidget = true
	row._previewKey = previewKey
	row._tooltipFn = tooltipFn
	-- Default: ordinary slider — drag applies immediately. Opt out with suiLiveApply=false.
	if liveApply == false then
		row._liveApply = false
	else
		row._liveApply = true
	end

	local label = MakeLabel(row, text)
	label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)

	-- Small "?" next to the title; hover shows the option description.
	if tooltipFn then
		local help = CreateFrame("Button", nil, row)
		help:SetSize(14, 14)
		help:SetPoint("LEFT", label, "RIGHT", 4, 0)
		help:EnableMouse(true)
		local helpTex = help:CreateTexture(nil, "ARTWORK")
		helpTex:SetAllPoints()
		helpTex:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
		help:SetScript("OnEnter", function(self)
			local tipFn = row._tooltipFn
			if not tipFn then return end
			local ok, lines = pcall(tipFn)
			if not ok or not lines then return end
			if type(lines) == "string" and lines ~= "" then
				lines = { { lines, COOLTIP_ORANGE[1], COOLTIP_ORANGE[2], COOLTIP_ORANGE[3] } }
			end
			if type(lines) == "table" then
				ShowCooltip(self, lines)
			end
		end)
		help:SetScript("OnLeave", function()
			HideCooltip()
		end)
		row.help = help
	end

	-- Editable numeric value (type + Enter / focus loss).
	local editW = 52
	local edit = CreateFrame("EditBox", nil, row)
	row.edit = edit
	edit:SetAutoFocus(false)
	edit:SetHeight(16)
	edit:SetWidth(editW)
	edit:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
	edit:SetFontObject(T.fonts.small)
	edit:SetJustifyH("RIGHT")
	edit:SetTextInsets(4, 4, 0, 0)
	edit:SetNumeric(false)
	T:ApplyFlat(edit, T.colors.inputBg, T.colors.borderSoft)
	local ac = T.colors.accent
	edit:SetTextColor(ac[1], ac[2], ac[3], 1)

	-- Visual Slider only — native thumb drag on 3.3.5 snaps back when capture
	-- is lost (scroll/parent). All interaction goes through an overlay hit button.
	local slider = CreateFrame("Slider", nil, row)
	slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
	slider:SetPoint("RIGHT", edit, "LEFT", -6, 0)
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

	local hit = CreateFrame("Button", nil, row)
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
			-- Focus lost on incomplete input → revert, do not fight the user mid-type.
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

	-- Ordinary slider: thumb → preview every step; set() ~30/sec so heavy
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

	-- RegisterForDrag → OnDragStop fires on release even outside the hit rect.
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
	row:SetScript("OnEnter", NotifyPreviewEnter)

	-- Native OnValueChanged is unused for input (mouse disabled); keep guard anyway.
	slider:SetScript("OnValueChanged", function()
		-- no-op: visuals are driven only by SetVisual / Refresh
	end)

	edit:SetScript("OnEditFocusGained", function()
		SUI._optionsTextEditing = true
	end)
	edit:SetScript("OnEnterPressed", function()
		CommitTyped()
		edit:ClearFocus()
	end)
	edit:SetScript("OnEditFocusLost", function()
		SUI._optionsTextEditing = nil
		if row._disabled or row._committing or row._dragging then
			FlushPendingOptionsRefresh()
			FlushPendingOptionsValueSync()
			return
		end
		CommitTyped()
		FlushPendingOptionsRefresh()
		FlushPendingOptionsValueSync()
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
			edit:Disable()
			T:SetTextColor(label, "disabled")
			edit:SetTextColor(0.45, 0.45, 0.45, 1)
		else
			hit:Enable()
			edit:Enable()
			T:SetTextColor(label, "text")
			edit:SetTextColor(ac[1], ac[2], ac[3], 1)
		end
	end

	row:Refresh()
	return row
end

function W:Input(parent, text, get, set)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(34)

	local label = MakeLabel(row, text)
	label:SetPoint("TOPLEFT", 0, 0)

	local edit = CreateFrame("EditBox", nil, row)
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
		SUI._optionsTextEditing = true
	end)
	edit:SetScript("OnEnterPressed", Commit)
	edit:SetScript("OnEditFocusLost", function()
		SUI._optionsTextEditing = nil
		FlushPendingOptionsRefresh()
	end)
	edit:SetScript("OnEscapePressed", function(self)
		row:Refresh()
		self:ClearFocus()
	end)

	row.SetDisabled = function(self, disabled)
		if disabled then edit:Disable() else edit:Enable() end
		T:SetTextColor(label, disabled and "disabled" or "text")
	end

	row:Refresh()
	return row
end

-- Details-like create profile: edit box + Save button on the same row.
-- Empty/nil text → single-line input + button (no label above).
-- clearOnSave (default true): wipe the box after commit (add-to-list / new name).
-- Pass false to keep/show the saved value (settings fields with OK).
function W:InputWithButton(parent, text, buttonText, get, set, clearOnSave)
	if clearOnSave == nil then clearOnSave = true end
	local row = CreateFrame("Frame", nil, parent)
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
	local btn = CreateFrame("Button", nil, row)
	btn:SetHeight(T.sizes.controlH or 20)
	btn:SetWidth(btnW)
	T:ApplyFlat(btn, T.colors.buttonBg, T.colors.borderSoft)
	local btnLabel = MakeLabel(btn, buttonText or "Сохранить", T.fonts.normal)
	btnLabel:SetPoint("CENTER")
	btn.label = btnLabel

	local edit = CreateFrame("EditBox", nil, row)
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
		SUI._optionsTextEditing = true
	end)
	edit:SetScript("OnEnterPressed", Commit)
	edit:SetScript("OnEditFocusLost", function()
		SUI._optionsTextEditing = nil
		FlushPendingOptionsRefresh()
	end)
	edit:SetScript("OnEscapePressed", function(self)
		row:Refresh()
		self:ClearFocus()
	end)

	row.SetDisabled = function(self, disabled)
		if disabled then
			edit:Disable()
			btn._disabled = true
			T:SetTextColor(btn.label, "disabled")
		else
			edit:Enable()
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

-- Simple dropdown: button + floating list (UIParent).
local openDropdown

function W:IsDropdownOpen()
	return openDropdown ~= nil and openDropdown.list and openDropdown.list:IsShown()
end

local function FlushDeferredOptionsRefresh()
	local OC = SUI.OptionsCore
	if not OC or not OC._refreshAfterDropdown then
		return
	end
	OC._refreshAfterDropdown = nil
	if OC._open and OC.Refresh then
		-- Next frame: avoid re-entrancy from ClearContent → CloseOpenDropdown.
		local f = CreateFrame("Frame")
		f:SetScript("OnUpdate", function(self)
			self:SetScript("OnUpdate", nil)
			if OC._open and OC.Refresh and not W:IsDropdownOpen() then
				OC:Refresh()
			end
		end)
	end
end

local function OpenDropdownList(row, list, anchor)
	W:CloseOpenDropdown()
	if not list or not anchor then
		return false
	end
	list:SetParent(UIParent)
	list:SetFrameStrata("FULLSCREEN_DIALOG")
	list:SetFrameLevel(500)
	list:ClearAllPoints()
	-- Relative anchor (not GetLeft): follows the button without per-frame ClearAllPoints.
	list:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
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
	-- ClearContent already rebuilds the page — don't schedule another Refresh.
	if opts.fromClearContent then
		if SUI.OptionsCore then
			SUI.OptionsCore._refreshAfterDropdown = nil
		end
		return
	end
	FlushDeferredOptionsRefresh()
end

-- One-row: select (left) + edit box + action button (right).
function W:SelectInputButton(parent, selectLabel, valuesFn, getType, setType, inputLabel, getInput, setInput, buttonText)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(40)

	local typeW = 150
	local btnW = 90
	local gap = 6

	local typeLabel = MakeLabel(row, selectLabel or "Тип")
	typeLabel:SetPoint("TOPLEFT", 0, 0)

	local typeBtn = CreateFrame("Button", nil, row)
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

	local addBtn = CreateFrame("Button", nil, row)
	addBtn:SetHeight(T.sizes.controlH or 20)
	addBtn:SetWidth(btnW)
	T:ApplyFlat(addBtn, T.colors.buttonBg, T.colors.borderSoft)
	local addLabel = MakeLabel(addBtn, buttonText or "Добавить", T.fonts.normal)
	addLabel:SetPoint("CENTER")
	addBtn.label = addLabel

	local edit = CreateFrame("EditBox", nil, row)
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

	local list = CreateFrame("Frame", nil, UIParent)
	list:SetFrameStrata("FULLSCREEN_DIALOG")
	list:SetFrameLevel(60)
	list:SetWidth(typeW)
	T:ApplyFlat(list, T.colors.navBg, T.colors.accent)
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
		if key == nil then return "—" end
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
		for k in pairs(map) do
			tinsert(keys, k)
		end
		sort(keys, function(a, b)
			return tostring(LabelFor(a, map)) < tostring(LabelFor(b, map))
		end)
		local y = -4
		local children = { list:GetChildren() }
		for _, c in ipairs(children) do
			c:Hide()
			c:SetParent(nil)
		end
		for _, key in ipairs(keys) do
			local item = CreateFrame("Button", nil, list)
			item:SetHeight(20)
			item:SetPoint("TOPLEFT", 4, y)
			item:SetPoint("TOPRIGHT", -4, y)
			local fs = MakeLabel(item, LabelFor(key, map), T.fonts.small)
			fs:SetPoint("LEFT", 4, 0)
			fs:SetPoint("RIGHT", -4, 0)
			EnsureDropdownItemHighlight(item):Hide()
			item:SetScript("OnEnter", DropdownItem_OnEnter)
			item:SetScript("OnLeave", DropdownItem_OnLeave)
			item:SetScript("OnClick", function()
				SafeCall(setType, key)
				RefreshType()
				CloseList()
			end)
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

	row.Refresh = function(self)
		RefreshType()
		local v = SafeCall(getInput)
		edit:SetText(v ~= nil and tostring(v) or "")
	end

	local function Commit()
		local value = edit:GetText()
		SafeCall(setInput, value)
		edit:SetText("")
		edit:ClearFocus()
	end

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
		row:Refresh()
		self:ClearFocus()
	end)

	row.SetDisabled = function(self, disabled)
		self._disabled = disabled and true or false
		if disabled then
			edit:Disable()
			addBtn._disabled = true
			T:SetTextColor(addLabel, "disabled")
			T:SetTextColor(typeText, "disabled")
		else
			edit:Enable()
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
	local row = CreateFrame("Frame", nil, parent)
	local hasLabel = type(text) == "string" and text ~= ""
	row:SetHeight(hasLabel and 44 or 24)
	row.type = "Keybinding"
	row._tooltipFn = tooltipFn

	local label
	if hasLabel then
		label = MakeLabel(row, text)
		label:SetPoint("TOPLEFT", 0, 0)
		label:SetPoint("TOPRIGHT", 0, 0)
		label:SetJustifyH("LEFT")
	end
	row.label = label

	local button = CreateFrame("Button", nil, row)
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

	local msgframe = CreateFrame("Frame", nil, UIParent)
	msgframe:SetHeight(30)
	msgframe:SetFrameStrata("FULLSCREEN_DIALOG")
	msgframe:SetFrameLevel(1000)
	T:ApplyFlat(msgframe, { 0, 0, 0, 0.92 }, T.colors.borderSoft)
	local msg = MakeLabel(msgframe, "Нажмите клавишу для назначения. ESC — сбросить. Повторный клик — отмена.")
	msg:SetPoint("LEFT", 8, 0)
	msg:SetPoint("RIGHT", -8, 0)
	msgframe.msg = msg
	msgframe:Hide()
	row.msgframe = msgframe

	local function FormatKey(key)
		if not key or key == "" then
			return NOT_BOUND or "Не назначено"
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

	local function ShowTip(anchor)
		local tipFn = row._tooltipFn
		if not tipFn then return end
		local ok, lines = pcall(tipFn)
		if not ok or not lines then return end
		if type(lines) == "string" and lines ~= "" then
			lines = { { lines, COOLTIP_ORANGE[1], COOLTIP_ORANGE[2], COOLTIP_ORANGE[3] } }
		end
		if type(lines) == "table" then
			ShowCooltip(anchor, lines)
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
		ShowTip(self)
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

function W:Dropdown(parent, text, values, get, set, placeholder, flagPathFn)
	local row = CreateFrame("Frame", nil, parent)
	local hasLabel = type(text) == "string" and text ~= ""
	row:SetHeight(hasLabel and 40 or 22)
	placeholder = placeholder or "—"
	if type(flagPathFn) ~= "function" then
		flagPathFn = nil
	end

	local label
	if hasLabel then
		label = MakeLabel(row, text)
		label:SetPoint("TOPLEFT", 0, 0)
	end
	row.label = label

	local btn = CreateFrame("Button", nil, row)
	btn:SetHeight(22)
	if label then
		btn:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
	else
		btn:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	end
	btn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
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

	local list = CreateFrame("Frame", nil, UIParent)
	list:SetFrameStrata("FULLSCREEN_DIALOG")
	list:SetFrameLevel(60)
	list:SetWidth((T.sizes and T.sizes.controlMaxW) or 320)
	T:ApplyFlat(list, T.colors.navBg, T.colors.accent)
	list:Hide()
	list:EnableMouse(true)
	row.list = list
	row.btn = btn

	local function SyncListWidth()
		local w = btn:GetWidth() or 0
		if w < 40 then
			w = row:GetWidth() or 0
		end
		if w < 40 then
			w = (T.sizes and T.sizes.controlMaxW) or 320
		end
		list:SetWidth(w)
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
				item = CreateFrame("Button", nil, list)
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
			item:SetPoint("TOPLEFT", list, "TOPLEFT", 4, y)
			item:SetPoint("TOPRIGHT", list, "TOPRIGHT", -4, y)
			item.label:SetText("Нет доступных профилей")
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
			return
		end
		for _, key in ipairs(keys) do
			i = i + 1
			local item = list._buttons[i]
			if not item then
				item = CreateFrame("Button", nil, list)
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
			item:SetPoint("TOPLEFT", list, "TOPLEFT", 4, y)
			item:SetPoint("TOPRIGHT", list, "TOPRIGHT", -4, y)
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
			EnsureDropdownItemHighlight(item):Hide()
			item:SetScript("OnEnter", DropdownItem_OnEnter)
			item:SetScript("OnLeave", DropdownItem_OnLeave)
			y = y - 22
		end
		list:SetHeight(math.max(30, 8 + i * 22))
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
	local row = CreateFrame("Frame", nil, parent)
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

	local actionBtn = self:Button(row, buttonText or "Настройки", onClick, buttonTooltipFn)
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

-- Compact list row: optional icon + label + optional right action button.
-- Pass buttonText = false/nil and no onClick to hide the button (fixed rows).
function W:CompactListRow(parent, labelText, buttonText, onClick, iconTexture)
	local row = CreateFrame("Frame", nil, parent)
	local rowH = math.max(T.sizes.controlH or 20, 22)
	row:SetHeight(rowH)

	local rightAnchor = row
	local rightPoint = "RIGHT"
	local rightOffset = 0
	if buttonText ~= false and buttonText ~= nil then
		local btnW = 80
		local btn = self:Button(row, buttonText or "Удалить", onClick)
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
