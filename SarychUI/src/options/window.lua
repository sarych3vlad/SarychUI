-- SarychUI Options Window - Details-like shell (root / header / nav / content / footer).
local SUI = SarychUI
local T = SUI.OptionsTheme
SUI.OptionsWindow = SUI.OptionsWindow or {}
local OW = SUI.OptionsWindow

local CreateFrame = SarychUI.OptionsPool and SarychUI.OptionsPool.CreateFrame or CreateFrame
local UIParent = UIParent
local tinsert = table.insert
local pairs = pairs
local type = type
local ipairs = ipairs
local pcall = pcall
local tostring = tostring
local math = math

local DEFAULT_FRAME_NAME = "SarychUIOptionsFrame"

function OW:GetFrameName()
	return self.frameName or DEFAULT_FRAME_NAME
end

function OW:GetBoundCore()
	if type(self.getCore) == "function" then
		return self.getCore()
	end
	return SUI.OptionsCore
end

function OW:GetPositionStore()
	if not SUI.db or not SUI.db.global then return nil end
	local g = SUI.db.global
	g.general = g.general or {}
	local key = self.positionKey or "optionsWindow"
	g.general[key] = g.general[key] or {}
	return g.general[key]
end

function OW:IsCreated()
	return self.root ~= nil
end

function OW:GetRoot()
	return self.root
end

function OW:CreateRoot()
	if self.root then
		return self.root
	end

	local frameName = self:GetFrameName()
	local sz = T.sizes
	local root = CreateFrame("Frame", frameName, UIParent, nil, "window:1")
	root:SetSize(sz.windowW, sz.windowH)
	root:SetPoint("CENTER")
	root:SetFrameStrata("DIALOG")
	root:SetToplevel(true)
	root:SetMovable(true)
	root:EnableMouse(true)
	root:SetClampedToScreen(false)
	root:Hide()
	T:ApplyFlat(root, T.colors.rootBg, T.colors.border)
	if self.markENPRoot then
		root.__SarychUI_ENPOptionsRoot = true
	end

	tinsert(UISpecialFrames, frameName)

	local window = self
	root:SetScript("OnHide", function()
		if PlaySound then
			PlaySound("UChatScrollButton")
		end
		local core = window.GetBoundCore and window:GetBoundCore()
		if core then
			core._open = false
		end
		if SUI.OptionsWidgets then
			if SUI.OptionsWidgets.CloseOpenDropdown then
				SUI.OptionsWidgets:CloseOpenDropdown()
			end
			if SUI.OptionsWidgets.CancelActiveKeybinding then
				SUI.OptionsWidgets:CancelActiveKeybinding()
			end
		end
		-- Cancel an in-progress drag so the next open doesn't inherit a stuck move.
		if root.IsMoving and root:IsMoving() then
			root:StopMovingOrSizing()
		end
	end)

	-- Drag only from the header (CreateHeader). Root-level RegisterForDrag
	-- fought the header drag and caused occasional jumps / double StartMoving.
	self.root = root
	self:CreateHeader()
	self:CreateNav()
	self:CreateContent()
	self:CreateFooter()
	self:RestorePosition()
	return root
end

function OW:CreateHeader()
	local root = self.root
	local window = self
	local h = CreateFrame("Frame", nil, root, nil, "window:2")
	h:SetPoint("TOPLEFT", 1, -1)
	h:SetPoint("TOPRIGHT", -1, -1)
	h:SetHeight(T.sizes.headerH)
	T:ApplyFlat(h, T.colors.headerBg, T.colors.borderSoft)
	h:EnableMouse(true)
	h:RegisterForDrag("LeftButton")
	h:SetScript("OnDragStart", function()
		if root.IsMoving and root:IsMoving() then
			return
		end
		root:StartMoving()
	end)
	h:SetScript("OnDragStop", function()
		root:StopMovingOrSizing()
		window:SavePosition()
	end)

	local title = h:CreateFontString(nil, "OVERLAY", T.fonts.title)
	title:SetPoint("LEFT", 14, 0)
	title:SetText(self.windowTitle or "SarychUI")
	T:SetTextColor(title, "title")
	h.title = title

	local subtitle = h:CreateFontString(nil, "OVERLAY", T.fonts.small)
	subtitle:SetPoint("LEFT", title, "RIGHT", 10, 0)
	local sub = self.windowSubtitle
		or ((SarychUI and SarychUI.T and SarychUI:T("ui.settings_985b5e0f")) or SarychUI:T("ui.settings_985b5e0f"))
	subtitle:SetText(sub)
	T:SetTextColor(subtitle, "textDim")
	h.subtitle = subtitle

	local close = CreateFrame("Button", nil, h, nil, "window:3")
	close:SetSize(22, 22)
	close:SetPoint("RIGHT", -10, 0)
	T:ApplyFlat(close, T.colors.buttonBg, T.colors.borderSoft)
	local x = close:CreateFontString(nil, "OVERLAY", T.fonts.normal)
	x:SetPoint("CENTER", 1, 0)
	x:SetText(SarychUI:T("ui.options_c032adc1ff"))
	T:SetTextColor(x, "text")
	close:SetScript("OnClick", function()
		local core = window:GetBoundCore()
		if core and core.Close then
			core:Close()
		else
			root:Hide()
		end
	end)
	close:SetScript("OnEnter", function(btn)
		T:ApplyFlat(btn, T.colors.buttonHover, T.colors.accent)
	end)
	close:SetScript("OnLeave", function(btn)
		T:ApplyFlat(btn, T.colors.buttonBg, T.colors.borderSoft)
	end)

	self.header = h
end

function OW:CreateNav()
	local root = self.root
	local nav = CreateFrame("Frame", nil, root, nil, "window:4")
	nav:SetPoint("TOPLEFT", root, "TOPLEFT", 1, -(T.sizes.headerH + 1))
	nav:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 1, T.sizes.footerH + 1)
	nav:SetWidth(T.sizes.navW)
	T:ApplyFlat(nav, T.colors.navBg, T.colors.borderSoft)

	local scroll = CreateFrame("ScrollFrame", nil, nav, nil, "window:5")
	scroll:SetPoint("TOPLEFT", 4, -4)
	scroll:SetPoint("BOTTOMRIGHT", -4, 4)

	local child = CreateFrame("Frame", nil, scroll, nil, "window:6")
	child:SetWidth(T.sizes.navW - 12)
	child:SetHeight(1)
	scroll:SetScrollChild(child)

	-- Mouse wheel
	nav:EnableMouseWheel(true)
	nav:SetScript("OnMouseWheel", function(_, delta)
		local cur = scroll:GetVerticalScroll() or 0
		local max = scroll:GetVerticalScrollRange() or 0
		local next = cur - delta * T.sizes.scrollStep
		if next < 0 then next = 0 end
		if next > max then next = max end
		scroll:SetVerticalScroll(next)
	end)

	self.nav = nav
	self.navScroll = scroll
	self.navChild = child
	self.navButtons = {}
end

-- Pixel sizes from the theme so first open does not wait a frame for GetWidth().
function OW:GetContentPixelWidth()
	local sz = T.sizes
	local winW = sz.windowW or 900
	if self.root then
		local rw = self.root:GetWidth()
		if rw and rw > 200 then
			winW = rw
		end
	end
	return math.max(200, winW - (sz.navW or 200) - 3)
end

function OW:GetTabBarPixelWidth()
	local bar = self.tabBar
	if bar then
		local w = bar:GetWidth()
		if w and w > 80 then
			return w
		end
	end
	return math.max(80, self:GetContentPixelWidth() - 2 * T.sizes.pageInset)
end

function OW:GetScrollPixelWidth()
	return math.max(80, self:GetContentPixelWidth() - 2 * T.sizes.pageInset)
end

function OW:CreateContent()
	local window = self
	local root = self.root
	local sz = T.sizes
	local content = CreateFrame("Frame", nil, root, nil, "window:7")
	content:SetPoint("TOPLEFT", root, "TOPLEFT", sz.navW + 2, -(sz.headerH + 1))
	content:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -1, sz.footerH + 1)
	local contentW = self:GetContentPixelWidth()
	content:SetWidth(contentW)
	T:ApplyFlat(content, T.colors.contentBg, T.colors.borderSoft)

	-- Section title removed globally (nav already shows the section name).
	local sectionTitle = content:CreateFontString(nil, "OVERLAY", T.fonts.title)
	sectionTitle:Hide()
	self.sectionTitle = sectionTitle
	self._titleVisible = false

	-- Tab bar at top of content (hidden when no tabs).
	-- Frame level above the scroll so wrapped tabs are clickable, not eaten by content.
	local tabBar = CreateFrame("Frame", nil, content, nil, "window:8")
	tabBar:SetPoint("TOPLEFT", T.sizes.pageInset, -T.sizes.pageInset)
	tabBar:SetPoint("TOPRIGHT", -T.sizes.pageInset, -T.sizes.pageInset)
	tabBar:SetWidth(math.max(80, contentW - 2 * sz.pageInset))
	tabBar:SetHeight(sz.tabH)
	tabBar:SetFrameLevel((content:GetFrameLevel() or 1) + 12)
	tabBar:EnableMouse(false)
	tabBar:Hide()
	self.tabBar = tabBar
	self.tabButtons = {}

	-- Second-level subtab bar under main tabs (height grows when tabs wrap).
	local subTabBar = CreateFrame("Frame", nil, content, nil, "window:9")
	subTabBar:SetPoint("TOPLEFT", T.sizes.pageInset, -(sz.pageInset + sz.tabH + sz.tabRowGap))
	subTabBar:SetPoint("TOPRIGHT", -T.sizes.pageInset, -(sz.pageInset + sz.tabH + sz.tabRowGap))
	subTabBar:SetWidth(math.max(80, contentW - 2 * sz.pageInset))
	subTabBar:SetHeight(sz.tabH)
	subTabBar:SetFrameLevel((content:GetFrameLevel() or 1) + 12)
	subTabBar:EnableMouse(false)
	subTabBar:Hide()
	self.subTabBar = subTabBar
	self.subTabButtons = {}

	local scroll = CreateFrame("ScrollFrame", nil, content, nil, "window:10")
	scroll:SetPoint("TOPLEFT", T.sizes.pageInset, -T.sizes.pageInset)
	scroll:SetPoint("BOTTOMRIGHT", -T.sizes.pageInset, T.sizes.pageInset + (self._contentBottomInset or 0))
	scroll:SetFrameLevel((content:GetFrameLevel() or 1) + 1)
	self._scrollTopWithTabs = -(sz.pageInset + sz.tabH + sz.tabContentGap)
	self._scrollTopWithSubTabs = -(sz.pageInset + sz.tabH + sz.tabRowGap + sz.tabH + sz.tabContentGap)
	self._scrollTopNoTabs = -sz.pageInset
	self._scrollTopNoTitle = -sz.pageInset
	self._tabBarRows = 1
	self._subTabBarRows = 1
	self._subTabBarH = sz.tabH

	local child = CreateFrame("Frame", nil, scroll, nil, "window:11")
	child:SetWidth(math.max(80, contentW - 2 * sz.pageInset))
	child:SetHeight(1)
	scroll:SetScrollChild(child)

	content:EnableMouseWheel(true)
	content:SetScript("OnMouseWheel", function(_, delta)
		if window._contentScrollLocked then
			return
		end
		local cur = scroll:GetVerticalScroll() or 0
		local max = scroll:GetVerticalScrollRange() or 0
		local next = cur - delta * T.sizes.scrollStep
		if next < 0 then next = 0 end
		if next > max then next = max end
		scroll:SetVerticalScroll(next)
	end)

	scroll:SetScript("OnSizeChanged", function(self, width)
		local c = window.contentChild
		if not c then return end
		local w = width
		if not w or w < 80 then
			w = window:GetScrollPixelWidth()
		end
		c:SetWidth(math.max(100, w))
	end)

	self.content = content
	self.contentScroll = scroll
	self.contentChild = child
    child:SetScript("OnSizeChanged", function()
        if self.UpdateContentScrollbar then self.UpdateContentScrollbar() end
    end)
    if self.UpdateContentScrollbar then self.UpdateContentScrollbar() end
	self._contentScrollLocked = false
	self:EnableContentScrollbar()
end

-- Every options window owns a scrollbar; visibility follows its content height.
function OW:EnableContentScrollbar()
	if self.contentScrollbar then return end
	local scroll, window = self.contentScroll, self
    local bar, Update = SUI.OptionsWidgets:Scrollbar(self.content, scroll, function()
        local height = window.contentChild and window.contentChild:GetHeight() or 0
        local view = scroll:GetHeight() or 0
        return view, height, window._contentScrollLocked and 0 or math.max(0, height - view)
    end)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(_, delta)
		local handler = window.content:GetScript("OnMouseWheel")
		if handler then handler(window.content, delta) end
	end)
	self.contentScrollbar, self.UpdateContentScrollbar = bar, Update
	Update()
end

function OW:SetContentScrollLocked(locked)
	self._contentScrollLocked = locked and true or false
	local scroll = self.contentScroll
	local content = self.content
	if not scroll then return end
	if self._contentScrollLocked then
		scroll:SetVerticalScroll(0)
		if content then
			content:EnableMouseWheel(false)
		end
		scroll:EnableMouseWheel(false)
	else
		if content then
			content:EnableMouseWheel(true)
		end
		scroll:EnableMouseWheel(true)
	end
	if self.UpdateContentScrollbar then self.UpdateContentScrollbar() end
end

local function StyleTabButton(btn, active, isSub)
	btn._active = active and true or false
	if active then
		T:ApplyFlat(btn, T.colors.tabActive, T.colors.accent)
		T:SetTextColor(btn.label, "title")
	else
		T:ApplyFlat(btn, isSub and T.colors.panelBg or T.colors.tabBg, T.colors.borderSoft)
		T:SetTextColor(btn.label, "textDim")
	end
end

local function FillTabBar(bar, buttons, tabs, activeKey, onSelect, isSub, rightReserve)
	if not tabs or #tabs == 0 then
		for _, b in pairs(buttons) do
			b:Hide()
		end
		bar:Hide()
		return 0, 1
	end
	bar:Show()
	local x = 0
	local row = 0
	local h = T.sizes.tabH or 24
	local gap = T.sizes.tabButtonGap
	local barW = bar:GetWidth() or 0
	if barW < 80 and OW.GetTabBarPixelWidth then
		barW = OW:GetTabBarPixelWidth()
		bar:SetWidth(barW)
	end
	if barW < 80 then
		barW = (OW.GetContentPixelWidth and OW:GetContentPixelWidth() or 680) - 2 * T.sizes.pageInset
		bar:SetWidth(barW)
	end
	rightReserve = rightReserve or 0
	local maxW = math.max(80, barW - rightReserve)
	local used = {}

	for i, tab in ipairs(tabs) do
		local tabKey = tab.key
		local btn = buttons[i]
		if not btn then
			btn = CreateFrame("Button", nil, bar, nil, "window:12")
			btn:SetHeight(h)
			btn:RegisterForClicks("LeftButtonDown")
			local fs = btn:CreateFontString(nil, "OVERLAY", T.fonts.small)
			fs:SetPoint("LEFT", 8, 0)
			fs:SetPoint("RIGHT", -8, 0)
			fs:SetJustifyH("CENTER")
			btn.label = fs
			buttons[i] = btn
		end
		used[btn] = true
		btn:SetParent(bar)
		btn:Show()
		local label = tab.label
		if not label and tab.opt then
			label = tab.opt.name
			if type(label) == "function" then
				local ok, v = pcall(label)
				label = ok and v or tabKey
			end
		end
		label = tostring(label or tabKey)
		if SarychUI and SarychUI.T then
			label = SarychUI:T(label)
		end
		btn.label:SetText(label)
		local w = math.max(isSub and 60 or 70, (btn.label:GetStringWidth() or 40) + 2 * T.sizes.tabTextPad)
		-- Don't let a single tab exceed the row width.
		if w > maxW then
			w = maxW
		end
		btn:SetWidth(w)
		if x > 0 and (x + w) > maxW then
			row = row + 1
			x = 0
		end
		btn:ClearAllPoints()
		btn:SetPoint("TOPLEFT", bar, "TOPLEFT", x, -(row * (h + T.sizes.tabRowGap)))
		btn.tabKey = tabKey
		StyleTabButton(btn, tabKey == activeKey, isSub)
		btn:SetScript("OnEnter", function(self)
			if self._active then return end
			T:ApplyFlat(self, T.colors.navHover, T.colors.borderSoft)
		end)
		btn:SetScript("OnLeave", function(self)
			StyleTabButton(self, self._active, isSub)
		end)
		-- LeftButtonDown + self.tabKey: Lua 5.1 loop closures all saw the last tab,
		-- and MouseUp clicks were lost when layout hid/moved the button mid-press.
		btn:SetScript("OnClick", function(self)
			local key = self.tabKey
			if onSelect and key then
				onSelect(key)
			end
		end)
		x = x + w + gap
	end
	for _, b in pairs(buttons) do
		if not used[b] then
			b:Hide()
			b.tabKey = nil
		end
	end
	local rows = row + 1
	bar:SetHeight(rows * h + math.max(0, rows - 1) * T.sizes.tabRowGap)
	return #tabs, rows
end

function OW:ClearTabBarNotice()
	local fs = self._tabBarNotice
	if fs then
		fs:SetText("")
		fs:Hide()
	end
end

-- Left-side notice on the tab bar (e.g. "Модуль выключен...") when tabs are hidden.
function OW:SetTabBarNotice(text)
	local bar = self.tabBar
	if not bar then return end
	local fs = self._tabBarNotice
	if not fs then
		fs = bar:CreateFontString(nil, "OVERLAY", T.fonts.title or "GameFontNormal")
		self._tabBarNotice = fs
	end
	text = tostring(text or "")
	if SUI.T then text = SUI:T(text) end
	if text == "" then
		fs:SetText("")
		fs:Hide()
		return
	end
	fs:ClearAllPoints()
	fs:SetPoint("LEFT", bar, "LEFT", 4, 0)
	local reserve = self._tabBarExtraW or 0
	if reserve > 0 then
		fs:SetPoint("RIGHT", bar, "RIGHT", -(reserve + 8), 0)
	else
		fs:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
	end
	fs:SetJustifyH("LEFT")
	fs:SetJustifyV("MIDDLE")
	T:SetTextColor(fs, "textDim")
	fs:SetText(text)
	fs:Show()
end

function OW:ClearTabBarExtra()
	self:ClearTabBarNotice()
	local extras = self._tabBarExtraWidgets
	if extras then
		for _, widget in ipairs(extras) do
			widget:Hide()
			widget:SetParent(nil); if SarychUI.OptionsPool then SarychUI.OptionsPool:Release(widget) end
		end
	end
	local legacy = self._tabBarExtraWidget
	if legacy then
		legacy:Hide()
		legacy:SetParent(nil); if SarychUI.OptionsPool then SarychUI.OptionsPool:Release(legacy) end
	end
	self._tabBarExtraWidgets = nil
	self._tabBarExtraWidget = nil
	self._tabBarExtraW = 0
end

local function NormalizeTabBarExtras(optOrList)
	local list = {}
	if type(optOrList) ~= "table" then
		return list
	end
	-- Array of toggles: suiTabBarExtras = { enable, testMode, ... }
	if optOrList[1] and type(optOrList[1]) == "table" then
		for _, item in ipairs(optOrList) do
			if type(item) == "table" and (item.type == "toggle" or item.type == "execute") then
				tinsert(list, item)
			end
		end
		return list
	end
	-- Single toggle (legacy suiTabBarExtra) or a table with .type
	if optOrList.type == "toggle" or optOrList.type == "execute" then
		tinsert(list, optOrList)
	elseif type(optOrList.suiTabBarExtras) == "table" then
		return NormalizeTabBarExtras(optOrList.suiTabBarExtras)
	elseif type(optOrList.suiTabBarExtra) == "table" then
		return NormalizeTabBarExtras(optOrList.suiTabBarExtra)
	end
	return list
end

-- Optional controls pinned to the right of the main tab bar
-- (e.g. Включить + Тестовый режим). Accepts one toggle or a list.
function OW:SetTabBarExtra(optOrList)
	self:ClearTabBarExtra()
	if not optOrList or not self.tabBar then
		return 0
	end
	local W = SUI.OptionsWidgets
	if not W or not W.Checkbox then
		return 0
	end

	local extras = NormalizeTabBarExtras(optOrList)
	if #extras == 0 then
		return 0
	end

	-- Drop hidden extras (e.g. Тестовый режим while the module is off).
	local visible = {}
	for _, opt in ipairs(extras) do
		local hide = opt.hidden
		local isHidden = false
		if type(hide) == "function" then
			local ok, v = pcall(hide)
			isHidden = ok and v and true or false
		elseif hide then
			isHidden = true
		end
		if not isHidden then
			tinsert(visible, opt)
		end
	end
	extras = visible
	if #extras == 0 then
		return 0
	end

	local widgets = {}
	local totalW = 0
	local gap = T.sizes.tabExtraGap
	local anchor = self.tabBar
	local relative = "TOPRIGHT"
	local offsetX = 0

	-- First extra (Включить) at far right; later extras (Тестовый режим) to its left.
	for i = 1, #extras do
		local opt = extras[i]
		local name = opt.name
		if type(name) == "function" then
			local ok, v = pcall(name)
			name = ok and v or "..."
		end
		name = tostring(name or "")
		if SarychUI and SarychUI.T then
			name = SarychUI:T(name)
		end
		local get = opt.get
		local set = opt.set
		local disabled = opt.disabled
		local descFn
		if type(opt.desc) == "function" then
			descFn = function()
				local d = opt.desc()
				if SarychUI and SarychUI.T then
					return SarychUI:T(d)
				end
				return d
			end
		elseif type(opt.desc) == "string" then
			local descText = (SarychUI and SarychUI.T and SarychUI:T(opt.desc)) or opt.desc
			descFn = function()
				return descText
			end
		end
		local widget
		if opt.type == "execute" then
			widget = W:Button(self.tabBar, name, function(button)
				if opt.func then opt.func(button) end
				self:SetTabBarExtra(optOrList)
			end, descFn, function()
				local text = type(opt.name) == "function" and opt.name() or opt.name
				return SarychUI:T(tostring(text or ""))
			end)
		else
		widget = W:Checkbox(self.tabBar, name, function()
			if type(get) == "function" then
				local ok, v = pcall(get)
				return ok and v
			end
			return false
		end, function(value)
			if type(set) == "function" then
				pcall(set, nil, value)
			end
		end, descFn)
		end
		local needW = 16 + 6 + ((widget.label and widget.label:GetStringWidth()) or 60) + 4
		needW = math.max(80, needW)
		widget:ClearAllPoints()
		widget:SetPoint("TOPRIGHT", anchor, relative, offsetX, 0)
		widget:SetWidth(needW)
		widget:SetHeight(T.sizes.tabH or 22)
		if widget.SetDisabled and type(disabled) == "function" then
			local ok, d = pcall(disabled)
			widget:SetDisabled(ok and d)
		elseif widget.SetDisabled and disabled then
			widget:SetDisabled(true)
		end
		tinsert(widgets, widget)
		totalW = totalW + needW + ((i < #extras) and gap or 0)
		anchor = widget
		relative = "TOPLEFT"
		offsetX = -gap
	end

	self._tabBarExtraWidgets = widgets
	self._tabBarExtraWidget = widgets[1]
	self._tabBarExtraW = totalW + 8
	return self._tabBarExtraW
end

function OW:HideSubTabs()
	if self.subTabBar then
		self.subTabBar:Hide()
		self.subTabBar:SetHeight(T.sizes.tabH or 24)
	end
	if self.subTabButtons then
		for _, b in pairs(self.subTabButtons) do
			b:Hide()
		end
	end
	self._subTabBarRows = 1
	self._subTabBarH = T.sizes.tabH or 24
end

function OW:HideTabs()
	if self.tabBar then
		self.tabBar:Hide()
		self.tabBar:SetHeight(T.sizes.tabH or 24)
	end
	if self.tabButtons then
		for _, b in pairs(self.tabButtons) do
			b:Hide()
		end
	end
	self._tabBarNoticeText = nil
	self:ClearTabBarExtra()
	self:HideSubTabs()
	self._tabBarRows = 1
	if self.contentScroll then
		self.contentScroll:ClearAllPoints()
		self.contentScroll:SetPoint("TOPLEFT", T.sizes.pageInset, self._scrollTopNoTabs or -T.sizes.pageInset)
		self.contentScroll:SetPoint("BOTTOMRIGHT", -T.sizes.pageInset, T.sizes.pageInset + (self._contentBottomInset or 0))
	end
end

function OW:ApplyContentScrollTop(hasTabs, hasSubTabs)
	if not self.contentScroll then return end
	local tabH = T.sizes.tabH or 24
	local top
	if hasSubTabs then
		local mainH = (self.tabBar and self.tabBar:IsShown() and self.tabBar:GetHeight()) or tabH
		if mainH < tabH then mainH = tabH end
		local subH = self._subTabBarH or tabH
		top = -(T.sizes.pageInset + mainH + T.sizes.tabRowGap + subH + T.sizes.tabContentGap)
	elseif hasTabs then
		local mainH = (self.tabBar and self.tabBar:IsShown() and self.tabBar:GetHeight()) or tabH
		if mainH < tabH then mainH = tabH end
		top = -(T.sizes.pageInset + mainH + T.sizes.tabContentGap)
	else
		top = self._scrollTopNoTabs or -T.sizes.pageInset
	end
	self.contentScroll:ClearAllPoints()
	self.contentScroll:SetPoint("TOPLEFT", T.sizes.pageInset, top)
	self.contentScroll:SetPoint("BOTTOMRIGHT", -T.sizes.pageInset, T.sizes.pageInset + (self._contentBottomInset or 0))
end

function OW:ClearContentBottomNote(skipScrollUpdate)
	local host = self.contentBottomNote
	if host then
		host:SetScript("OnSizeChanged", nil)
		host:Hide()
		host:ClearAllPoints()
		host:SetParent(nil); if SarychUI.OptionsPool then SarychUI.OptionsPool:Release(host) end
	end
	self.contentBottomNote = nil
	self._contentBottomInset = 0

	if not skipScrollUpdate and self.contentScroll and self.ApplyContentScrollTop then
		self:ApplyContentScrollTop(
			self.tabBar and self.tabBar:IsShown(),
			self.subTabBar and self.subTabBar:IsShown()
		)
	end
end

function OW:SetContentBottomNote(text)
	if not self.content then return end
	self:ClearContentBottomNote(true)

	local host = CreateFrame("Frame", nil, self.content, nil, "window:13")
	host:SetPoint("BOTTOMLEFT", self.content, "BOTTOMLEFT", T.sizes.pageInset, T.sizes.pageInset)
	host:SetPoint("BOTTOMRIGHT", self.content, "BOTTOMRIGHT", -T.sizes.pageInset, T.sizes.pageInset)
	host:SetFrameLevel((self.content:GetFrameLevel() or 1) + 14)
	T:ApplyFlat(host, T.colors.panelBg or T.colors.contentBg, T.colors.borderSoft)

	local label = host:CreateFontString(nil, "OVERLAY", T.fonts.small)
	label:SetPoint("TOPLEFT", host, "TOPLEFT", 8, -6)
	label:SetJustifyH("LEFT")
	label:SetJustifyV("TOP")
	label:SetWordWrap(true)
	if label.SetNonSpaceWrap then
		label:SetNonSpaceWrap(true)
	end
	label:SetText(text or "")
	T:SetTextColor(label, "textDim")
	host.label = label

	local window = self
	local function MeasureNote(self, width)
		if self._suiMeasuring then return end
		if not width or width < 80 then
			width = (window.content and window.content:GetWidth() or 420) - 2 * T.sizes.pageInset
		end
		self._suiMeasuring = true
		label:SetWidth(math.max(40, width - 16))
		local height = math.max(26, (label:GetStringHeight() or 14) + 12)
		self:SetHeight(height)
		window._contentBottomInset = height + 8
		window:ApplyContentScrollTop(
			window.tabBar and window.tabBar:IsShown(),
			window.subTabBar and window.subTabBar:IsShown()
		)
		self._suiMeasuring = nil
	end

	host:SetScript("OnSizeChanged", function(self, width)
		MeasureNote(self, width)
	end)
	self.contentBottomNote = host
	MeasureNote(host, host:GetWidth())
	host:Show()
end

function OW:SetTabs(tabs, activeKey, onSelect, tabBarExtraOpt)
	local bar = self.tabBar
	if not bar then return end
	self.tabButtons = self.tabButtons or {}
	self._lastTabs = tabs
	self._lastTabActiveKey = activeKey
	self._lastTabOnSelect = onSelect
	self._lastTabBarExtraOpt = tabBarExtraOpt

	local hasExtras = false
	if type(tabBarExtraOpt) == "table" then
		if tabBarExtraOpt.type == "toggle" or tabBarExtraOpt.type == "execute" or (tabBarExtraOpt[1] and type(tabBarExtraOpt[1]) == "table") then
			hasExtras = true
		elseif tabBarExtraOpt.suiTabBarExtras or tabBarExtraOpt.suiTabBarExtra then
			hasExtras = true
		end
	end

	-- No tabs and no right-side toggles -> hide the whole bar.
	if (not tabs or #tabs == 0) and not hasExtras then
		self:HideTabs()
		return
	end

	local reserve = self:SetTabBarExtra(tabBarExtraOpt)
	local function LayoutMainTabs()
		if self._tabLayoutLock then
			return
		end
		self._tabLayoutLock = true
		if self._lastTabs and #self._lastTabs > 0 then
			self._tabBarNoticeText = nil
			self:ClearTabBarNotice()
			local _, rows = FillTabBar(bar, self.tabButtons, self._lastTabs, self._lastTabActiveKey, self._lastTabOnSelect, false, reserve or self._tabBarExtraW or 0)
			self._tabBarRows = rows or 1
		else
			-- Module disabled: keep the bar for enable/test toggles only.
			for _, b in pairs(self.tabButtons) do
				b:Hide()
			end
			bar:Show()
			self._tabBarRows = 1
			bar:SetHeight(T.sizes.tabH or 24)
			if self._tabBarNoticeText then
				self:SetTabBarNotice(self._tabBarNoticeText)
			end
		end
		self._tabLayoutLock = nil
	end

	LayoutMainTabs()
	if self._tabBarExtraWidgets then
		local extraLevel = (bar:GetFrameLevel() or 1) + 30
		for i = 1, #self._tabBarExtraWidgets do
			local extra = self._tabBarExtraWidgets[i]
			if extra and extra.SetFrameLevel then
				extra:SetFrameLevel(extraLevel)
			end
		end
	end
	bar:SetScript("OnSizeChanged", function(selfBar, w)
		if not w or w < 1 then
			w = selfBar:GetWidth()
		end
		if selfBar._lastLayoutW and w and math.abs(selfBar._lastLayoutW - w) < 1 then
			return
		end
		selfBar._lastLayoutW = w
		LayoutMainTabs()
		if self.ApplyContentScrollTop then
			self:ApplyContentScrollTop(true, self.subTabBar and self.subTabBar:IsShown())
		end
	end)

	-- Subtabs may still be shown by SetSubTabs; anchor under the real main tab height.
	self:HideSubTabs()
	if self.subTabBar then
		local mainH = bar:GetHeight() or (T.sizes.tabH or 24)
		self.subTabBar:ClearAllPoints()
		self.subTabBar:SetPoint("TOPLEFT", T.sizes.pageInset, -(T.sizes.pageInset + mainH + T.sizes.tabRowGap))
		self.subTabBar:SetPoint("TOPRIGHT", -T.sizes.pageInset, -(T.sizes.pageInset + mainH + T.sizes.tabRowGap))
	end
	self:ApplyContentScrollTop(true, false)
end

function OW:SetSubTabs(tabs, activeKey, onSelect)
	local bar = self.subTabBar
	if not bar then return end
	self.subTabButtons = self.subTabButtons or {}
	self._lastSubTabs = tabs
	self._lastSubTabActiveKey = activeKey
	self._lastSubTabOnSelect = onSelect

	if not tabs or #tabs == 0 then
		self:HideSubTabs()
		bar:SetScript("OnSizeChanged", nil)
		self:ApplyContentScrollTop(self.tabBar and self.tabBar:IsShown(), false)
		return
	end

	local function LayoutSubTabs()
		if self._subTabLayoutLock then
			return
		end
		self._subTabLayoutLock = true
		local _, rows = FillTabBar(bar, self.subTabButtons, self._lastSubTabs, self._lastSubTabActiveKey, self._lastSubTabOnSelect, true, 0)
		self._subTabBarRows = rows or 1
		self._subTabBarH = bar:GetHeight() or (T.sizes.tabH or 24)
		self:ApplyContentScrollTop(true, true)
		self._subTabLayoutLock = nil
	end

	LayoutSubTabs()
	bar:SetScript("OnSizeChanged", function(selfBar, w)
		if not self._lastSubTabs or #self._lastSubTabs == 0 then
			return
		end
		if not w or w < 1 then
			w = selfBar:GetWidth()
		end
		if selfBar._lastLayoutW and w and math.abs(selfBar._lastLayoutW - w) < 1 then
			return
		end
		selfBar._lastLayoutW = w
		LayoutSubTabs()
	end)
end

-- Subtabs rendered inside the scroll content (below a header block), not under the main tab bar.
-- Returns the used height so the caller can place content below.
function OW:RenderInlineSubTabs(parent, y, tabs, activeKey, onSelect)
	if not parent or not tabs or #tabs == 0 then
		return 0
	end
	local bar = CreateFrame("Frame", nil, parent, nil, "window:14")
	bar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
	bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
	local pw = parent:GetWidth()
	if not pw or pw < 40 then
		pw = (OW.GetScrollPixelWidth and OW:GetScrollPixelWidth()) or 680
		parent:SetWidth(pw)
	end
	bar:SetWidth(pw)
	local buttons = {}
	-- Inline tabs live inside the scroll child, so ClearContent destroys them.
	-- Capture the key on click, then switch next frame. Do not coalesce via a
	-- shared pending slot - that swallowed clicks when ClearContent raced OnUpdate.
	local wrappedSelect = onSelect
	if type(onSelect) == "function" then
		wrappedSelect = function(tabKey)
			if not tabKey or tabKey == activeKey then
				return
			end
			if SUI.OptionsPool then
				SUI.OptionsPool:After(bar, "select", 1, function() onSelect(tabKey) end)
				return
			end
			local f = CreateFrame("Frame", nil, nil, nil, "window:15")
			f:SetScript("OnUpdate", function(self)
				self:SetScript("OnUpdate", nil)
				onSelect(tabKey)
			end)
		end
	end
	local _, rows = FillTabBar(bar, buttons, tabs, activeKey, wrappedSelect, true, 0)
	local h = bar:GetHeight() or ((T.sizes.tabH or 24) * (rows or 1))
	bar:SetHeight(h)
	return h
end

function OW:CreateFooter()
	local root = self.root
	local f = CreateFrame("Frame", nil, root, nil, "window:16")
	f:SetPoint("BOTTOMLEFT", 1, 1)
	f:SetPoint("BOTTOMRIGHT", -1, 1)
	f:SetHeight(T.sizes.footerH)
	T:ApplyFlat(f, T.colors.footerBg or T.colors.headerBg, T.colors.borderSoft)

	local fc = T.colors.footerCredit or { 0.42, 0.42, 0.45, 0.55 }

	-- Left: Discord invite (Details-style selectable EditBox + backdrop).
	local DISCORD_URL = "https://discord.gg/X9ErMKUHVQ"
	local discordLabel = f:CreateFontString(nil, "OVERLAY", T.fonts.small)
	discordLabel:SetPoint("LEFT", 8, 0)
	discordLabel:SetText(SarychUI:T("ui.options_9b150cc85e"))
	discordLabel:SetTextColor(0.75, 0.75, 0.75, 1)
	discordLabel:SetAlpha(0.4)

	local discordEdit = CreateFrame("EditBox", nil, f, nil, "window:17")
	discordEdit:SetAutoFocus(false)
	discordEdit:SetHeight(18)
	discordEdit:SetWidth(200)
	discordEdit:SetPoint("LEFT", discordLabel, "RIGHT", 2, 0)
	discordEdit:SetFontObject(T.fonts.small)
	discordEdit:SetJustifyH("LEFT")
	discordEdit:SetTextInsets(4, 4, 0, 0)
	discordEdit:SetText(DISCORD_URL)
	discordEdit:SetTextColor(1, 1, 1, 1)
	discordEdit:SetCursorPosition(0)
	discordEdit:SetAlpha(0.4)
	if discordEdit.SetBackdrop then
		discordEdit:SetBackdrop({
			bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
			edgeFile = [[Interface\Buttons\WHITE8X8]],
			tile = true,
			tileSize = 64,
			edgeSize = 1,
			insets = { left = 0, right = 0, top = 0, bottom = 0 },
		})
		discordEdit:SetBackdropColor(1, 1, 1, 0.7)
		discordEdit:SetBackdropBorderColor(1, 1, 1, 0)
	end
	discordEdit:SetScript("OnEditFocusGained", function(self)
		self:HighlightText()
	end)
	discordEdit:SetScript("OnEditFocusLost", function(self)
		self:HighlightText(0, 0)
		self:SetText(DISCORD_URL)
		self:SetCursorPosition(0)
	end)
	discordEdit:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	discordEdit:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	discordEdit:SetScript("OnTextChanged", function(self, userInput)
		if userInput then
			self:SetText(DISCORD_URL)
			self:HighlightText()
		end
	end)

	local credit = f:CreateFontString(nil, "OVERLAY", T.fonts.small)
	credit:SetPoint("RIGHT", -12, 0)
	credit:SetTextColor(fc[1], fc[2], fc[3], fc[4] or 1)

	self.footer = f
	self.footerDiscord = discordEdit
	self.footerCredit = credit
	self:RefreshFooterCredit()
end

function OW:RefreshFooterCredit()
	local credit = self.footerCredit
	if not credit then
		return
	end
    local ver = (SUI and SUI.version) or "1.4.1A"
	local author = (SarychUI and SarychUI.T and SarychUI:T("ui.options_416f697182")) or SarychUI:T("ui.options_416f697182")
	credit:SetText(author .. SarychUI:T("ui.options_0b5a27f988") .. tostring(ver))
end

function OW:ClearNav()
	if not self.navButtons then return end
	for _, btn in pairs(self.navButtons) do
		btn:Hide()
		btn:SetParent(nil); if SarychUI.OptionsPool then SarychUI.OptionsPool:Release(btn) end
	end
	self.navButtons = {}
end

local function NavTextColor(btn, highlighted)
    local key = btn.sectionId and btn.sectionId:match("^sui:modules/([^/]+)$")
    local profile = SUI.db and SUI.db.profile
    local cfg = key and profile and profile.modules and profile.modules[key]
    if cfg and (cfg.enabled == false or cfg.enabled == 0) then return "disabled" end
    if highlighted then return "title" end
    return (btn.depth or 0) > 0 and "textDim" or "text"
end

function OW:AddNavItem(id, label, depth, onClick, helpTip)
	depth = depth or 0
	local itemH = T.sizes.navItemH or 22
	local btn = CreateFrame("Button", nil, self.navChild, nil, "window:18")
	btn:SetHeight(itemH)
	btn:SetPoint("TOPLEFT", self.navChild, "TOPLEFT", 2, -((#self.navButtons) * itemH))
	btn:SetPoint("TOPRIGHT", self.navChild, "TOPRIGHT", -2, -((#self.navButtons) * itemH))

	local fs = btn:CreateFontString(nil, "OVERLAY", T.fonts.nav)
	fs:SetPoint("LEFT", 8 + depth * 10, 0)
	fs:SetJustifyH("LEFT")
	fs:SetText((SarychUI and SarychUI.T and SarychUI:T(label)) or label or id)
	T:SetTextColor(fs, depth > 0 and "textDim" or "text")
	btn.label = fs
	btn.sectionId = id
	btn.depth = depth
	T:SetTextColor(fs, NavTextColor(btn, false))
	btn:RegisterForClicks("LeftButtonDown")

	fs:SetPoint("RIGHT", -4, 0)

	btn:SetScript("OnEnter", function(self)
		if self._active then return end
		T:SetTextColor(self.label, NavTextColor(self, true))
	end)
	btn:SetScript("OnLeave", function(self)
		if self._active then
			T:SetTextColor(self.label, NavTextColor(self, true))
		else
			T:SetTextColor(self.label, NavTextColor(self, false))
		end
	end)
	btn:SetScript("OnClick", function(self)
		local sid = self.sectionId
		if onClick and sid then
			onClick(sid)
		end
	end)

	tinsert(self.navButtons, btn)
	self.navChild:SetHeight(math.max(1, #self.navButtons * itemH + 4))
	if self == OW and self.root then
		local needed = self.navChild:GetHeight() + T.sizes.headerH + T.sizes.footerH + 10
		local screenH = UIParent:GetHeight()
		local limit = screenH and screenH > 100 and screenH - 32 or T.sizes.windowH
		self.root:SetHeight(math.min(limit, math.max(T.sizes.windowH, needed)))
	end
	return btn
end

function OW:SetActiveNav(id)
	for _, btn in pairs(self.navButtons) do
		local active = btn.sectionId == id
		btn._active = active
		if active then
			T:ApplyFlat(btn, T.colors.navActive, T.colors.accent)
			T:SetTextColor(btn.label, NavTextColor(btn, true))
		else
			btn:SetBackdrop(nil)
			T:SetTextColor(btn.label, NavTextColor(btn, false))
		end
	end
end

function OW:ClearContent()
	local scroll = self.contentScroll
	if not scroll then return end
	SUI._optionsTextEditing = nil
	-- The hovered widget dies without OnLeave, so its tooltip would linger.
	if SUI.OptionsWidgets and SUI.OptionsWidgets.HideCooltip then
		SUI.OptionsWidgets.HideCooltip()
	end

	self._inlineSubTabPending = nil
	if self.ClearContentBottomNote then
		self:ClearContentBottomNote()
	end
	if self.SetContentScrollLocked then
		self:SetContentScrollLocked(false)
	end
	-- Tear down sticky / animated previews before orphaning the scroll child,
	-- otherwise OnUpdate hosts can linger on screen as UI "ghosts".
	local previewBuckets = {
		SUI.PlatesAurasLayoutPreview,
		SUI.NameplateDistancePreview,
		SUI.CombatTextPreview,
		SUI.ErrorFilterPreview,
		SUI.SysMsgPreview,
		SUI.BossEmotePreview,
		SUI.FrameHitPreview,
		SUI.ArenaPreview,
		SUI.ArenaNumbersPreview,
		SUI.ArenaGroupTitlesPreview,
		SUI.AurasPreview,
		SUI.PartyAbilitiesPreview,
		SUI.MinimapPreview,
		SUI.CombatIndicatorPreview,
		SUI.FramePvpPreview,
		SUI.ChatTooltipPreview,
		SUI.LootRollPreview,
		SUI.CooldownTextPreview,
		SUI.GcdCooldownPreview,
		SUI.CastbarTimerPreview,
		SUI.CountdownTimerPreview,
		SUI.ActionBarTextPreview,
		SUI.ActionBarColorPreview,
		SUI.ActionBarAppearancePreview,
		SUI.ActionBarTransparencyPreview,
		SUI.ActionBarBarsPreview,
	}
	for i = 1, #previewBuckets do
		local bucket = previewBuckets[i]
		if bucket and bucket.ClearStickyHosts then
			bucket:ClearStickyHosts()
		end
	end

	-- Return the old subtree to the private pool. The ownership list avoids
	-- GetChildren/unpack and the next acquisition reuses the scroll child.
	local old = self.contentChild
	if old then
		old:SetScript("OnUpdate", nil)
		old:SetScript("OnSizeChanged", nil)
		if old.SetBackdrop then
			old:SetBackdrop(nil)
		end
		old:Hide()
		old:ClearAllPoints()
		old:SetParent(nil); if SarychUI.OptionsPool then SarychUI.OptionsPool:Release(old) end
	end

	local child = CreateFrame("Frame", nil, scroll, nil, "window:19")
	local width = scroll:GetWidth()
	if not width or width < 80 then
		width = self:GetScrollPixelWidth()
	end
	child:SetWidth(math.max(200, width))
	child:SetHeight(1)
	scroll:SetScrollChild(child)
	scroll:SetVerticalScroll(0)
	self.contentChild = child
    child:SetScript("OnSizeChanged", function()
        if self.UpdateContentScrollbar then self.UpdateContentScrollbar() end
    end)
    if self.UpdateContentScrollbar then self.UpdateContentScrollbar() end

	if SUI.OptionsWidgets then
		if SUI.OptionsWidgets.CloseOpenDropdown then
			SUI.OptionsWidgets:CloseOpenDropdown({ fromClearContent = true })
		end
		if SUI.OptionsWidgets.CancelActiveKeybinding then
			SUI.OptionsWidgets:CancelActiveKeybinding()
		end
	end
end

function OW:SetSectionTitle(text)
	-- Title strip removed; nav label is enough.
	if self.sectionTitle then
		self.sectionTitle:SetText("")
		self.sectionTitle:Hide()
	end
end

function OW:SetSectionTitleVisible(visible)
	-- Always hidden: section name lives in the left nav only.
	self._titleVisible = false
	if self.sectionTitle then
		self.sectionTitle:SetText("")
		self.sectionTitle:Hide()
	end
end

function OW:SavePosition()
	local root = self.root
	if not root then return end
	local store = self ~= OW and self:GetPositionStore() or nil

	-- Anchor to UIParent BOTTOMLEFT in screen coords so restore never depends
	-- on a transient relative frame left behind by StartMoving().
	local left = root:GetLeft()
	local bottom = root:GetBottom()
	if not left or not bottom then return end
	root:ClearAllPoints()
	root:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
	if root.SetUserPlaced then root:SetUserPlaced(self ~= OW) end

	if store then
		store.point = "BOTTOMLEFT"
		store.relativePoint = "BOTTOMLEFT"
		store.x = left
		store.y = bottom
	end
end

function OW:RestorePosition()
	if self == OW then return end
	local root = self.root
	if not root then return end
	local ow = self:GetPositionStore()
	if not ow or not ow.point then return end
	root:ClearAllPoints()
	-- Prefer absolute BOTTOMLEFT coords when available (new saves).
	if ow.point == "BOTTOMLEFT" and ow.relativePoint == "BOTTOMLEFT" and ow.x and ow.y then
		root:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", ow.x, ow.y)
	else
		root:SetPoint(ow.point, UIParent, ow.relativePoint or ow.point, ow.x or 0, ow.y or 0)
	end
	if root.SetUserPlaced then
		root:SetUserPlaced(true)
	end
end

-- Second shell (ENP, etc.): same widgets/chrome, separate frame + core binding.
function SUI.CreateOptionsWindowInstance(spec)
	spec = spec or {}
	local inst = {}
	-- Inherit methods only: a second window must not reuse the main window's
	-- root, content, navigation pool or scroll state after it has been opened.
	setmetatable(inst, { __index = function(_, key)
		local value = OW[key]
		if type(value) == "function" then return value end
	end })
	inst.frameName = spec.frameName
	inst.windowTitle = spec.title
	inst.windowSubtitle = spec.subtitle
	inst.positionKey = spec.positionKey
	inst.getCore = spec.getCore
	inst.markENPRoot = spec.markENPRoot and true or false
	return inst
end

function OW:Show()
	self:CreateRoot()
	local wasShown = self.root:IsShown()
	if self == OW and not wasShown then
		-- Main SUI options always start from the centre on every open.
		local general = SUI.db and SUI.db.global and SUI.db.global.general
		if general then general.optionsWindow = nil end
		self.root:ClearAllPoints()
		self.root:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		if self.root.SetUserPlaced then self.root:SetUserPlaced(false) end
	end
	self.root:Show()
	self.root:Raise()
	if not wasShown and PlaySound then
		PlaySound("UChatScrollButton")
	end
end

function OW:Hide()
	if self.root then
		self.root:Hide()
	end
	if SUI.OptionsWidgets then
		if SUI.OptionsWidgets.CloseOpenDropdown then
			SUI.OptionsWidgets:CloseOpenDropdown()
		end
		if SUI.OptionsWidgets.CancelActiveKeybinding then
			SUI.OptionsWidgets:CancelActiveKeybinding()
		end
	end
end

function OW:IsShown()
	return self.root and self.root:IsShown()
end
