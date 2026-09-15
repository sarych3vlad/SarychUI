-- SarychUI Options Renderer — AceConfig option tables → custom widgets.
local SUI = SarychUI
local W = SUI.OptionsWidgets
local T = SUI.OptionsTheme
SUI.OptionsRenderer = SUI.OptionsRenderer or {}
local R = SUI.OptionsRenderer

local type = type
local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local tonumber = tonumber
local tinsert = table.insert
local sort = table.sort
local concat = table.concat
local wipe = wipe or function(t)
	for k in pairs(t) do
		t[k] = nil
	end
	return t
end
local select = select
local pcall = pcall
local next = next
local math = math
local CreateFrame = CreateFrame
local UIParent = UIParent
local GetCursorPosition = GetCursorPosition
local StaticPopupDialogs = StaticPopupDialogs
local StaticPopup_Show = StaticPopup_Show
local ACCEPT = ACCEPT
local CANCEL = CANCEL

R.unsupportedTypes = R.unsupportedTypes or {}

local function Safe(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a = pcall(fn, ...)
	if ok then return a end
	return nil
end

local function ResolveName(opt, info)
	if not opt then return "" end
	local n = opt.name
	if type(n) == "function" then
		-- AceConfig name callbacks expect the info table (e.g. current profile).
		n = Safe(n, info)
	end
	n = n and tostring(n) or ""
	if n ~= "" and SarychUI and SarychUI.T then
		n = SarychUI:T(n)
	end
	return n
end

local function TUI(text)
	if type(text) ~= "string" or text == "" then
		return text
	end
	if SarychUI and SarychUI.T then
		return SarychUI:T(text)
	end
	return text
end

local function MakeTooltip(opt, info)
	if type(opt.suiTooltip) == "function" then
		return function()
			return TUI(opt.suiTooltip())
		end
	end
	if type(opt.desc) == "function" then
		return function()
			return TUI(Safe(opt.desc, info))
		end
	end
	if type(opt.desc) == "string" and opt.desc ~= "" then
		local text = TUI(opt.desc)
		return function()
			return text
		end
	end
end

local function MakeInfo(path, opt, handler)
	-- Minimal AceConfig-like info table for get/set handlers.
	local info = {}
	for i, key in ipairs(path) do
		info[i] = key
	end
	info[#path] = path[#path]
	info.options = opt
	info.arg = opt and opt.arg
	info.type = opt and opt.type
	info.option = opt
	info.handler = handler or (opt and opt.handler)
	return info
end

local function ResolveHandlerMethod(opt, info, field)
	local v = opt and opt[field]
	if type(v) == "function" then
		return v
	end
	if type(v) == "string" then
		local h = (info and info.handler) or (opt and opt.handler)
		if h and type(h[v]) == "function" then
			return function(...)
				return h[v](h, ...)
			end
		end
	end
	return nil
end

-- AceConfig walks parent groups for inherited get/set/func/values.
local function ResolveInheritedMethod(opt, info, field)
	local fn = ResolveHandlerMethod(opt, info, field)
	if fn then return fn end
	local root = SUI._activeAceOptionsRoot
	if not root or type(info) ~= "table" or #info < 1 then
		return nil
	end
	local node = root
	local chain = { root }
	for i = 1, #info - 1 do
		local key = info[i]
		node = node and node.args and node.args[key]
		if not node then break end
		tinsert(chain, node)
	end
	for i = #chain, 1, -1 do
		fn = ResolveHandlerMethod(chain[i], info, field)
		if fn then return fn end
	end
	return nil
end

local function NotifyActiveCoreChanged()
	local core = SUI._activeOptionsCore or SUI.OptionsCore
	if core and core.OnSettingChanged then
		core:OnSettingChanged()
	end
end

local function CallGet(opt, info)
	local core = SUI._activeOptionsCore or SUI.OptionsCore
	if core and core._perf then
		core._perf.getCalls = (core._perf.getCalls or 0) + 1
	end
	local fn = ResolveInheritedMethod(opt, info, "get")
	if fn then
		return Safe(fn, info)
	end
	return nil
end

local function CallGetColor(opt, info)
	local fn = ResolveInheritedMethod(opt, info, "get")
	if not fn then
		return 1, 1, 1, 1
	end
	local ok, r, g, b, a = pcall(fn, info)
	if not ok then
		return 1, 1, 1, 1
	end
	return r or 1, g or 1, b or 1, a or 1
end

local function CallSet(opt, info, value)
	if (not opt or not opt.suiSkipWritableProfile) and SUI.EnsureWritableProfile then
		SUI:EnsureWritableProfile()
	end
	local fn = ResolveInheritedMethod(opt, info, "set")
	if fn then
		Safe(fn, info, value)
		NotifyActiveCoreChanged()
	end
end

local function CallSetColor(opt, info, r, g, b, a)
	if SUI.EnsureWritableProfile then
		SUI:EnsureWritableProfile()
	end
	local fn = ResolveInheritedMethod(opt, info, "set")
	if fn then
		pcall(fn, info, r, g, b, a)
		NotifyActiveCoreChanged()
	end
end

local function ResolveValues(opt, info)
	local v = opt and opt.values
	local tbl
	if type(v) == "table" then
		tbl = v
	elseif type(v) == "function" then
		local ok, res = pcall(v, info)
		if ok and type(res) == "table" then
			tbl = res
		end
	end
	if not tbl then
		local fn = ResolveInheritedMethod(opt, info, "values")
		if fn then
			local ok, res = pcall(fn, info)
			if ok and type(res) == "table" then
				tbl = res
			end
		end
	end
	-- LSM dialogControl fallback when values table missing.
	if (not tbl or not next(tbl)) and opt and opt.dialogControl and LibStub then
		local LSM = LibStub("LibSharedMedia-3.0", true)
		local mediaType
		local dc = opt.dialogControl
		if dc == "LSM30_Font" then mediaType = "font"
		elseif dc == "LSM30_Statusbar" then mediaType = "statusbar"
		elseif dc == "LSM30_Border" then mediaType = "border"
		elseif dc == "LSM30_Background" then mediaType = "background"
		elseif dc == "LSM30_Sound" then mediaType = "sound"
		end
		if LSM and mediaType and LSM.HashTable then
			tbl = LSM:HashTable(mediaType)
		elseif AceGUIWidgetLSMlists and mediaType and AceGUIWidgetLSMlists[mediaType] then
			tbl = AceGUIWidgetLSMlists[mediaType]
		end
	end
	if type(tbl) ~= "table" then
		return {}
	end
	local out = {}
	for key, label in pairs(tbl) do
		if key ~= "__order" then
			if type(label) == "string" then
				out[key] = TUI(label)
			else
				out[key] = label
			end
		end
	end
	if type(tbl.__order) == "table" then
		out.__order = tbl.__order
	end
	return out
end

local function CallFunc(opt, info)
	local fn = ResolveInheritedMethod(opt, info, "func")
	if fn then
		Safe(fn, info)
	end
end

-- Canonical hidden evaluation without side effects (OptionsCore re-checks with it).
local function EvalHidden(opt, info)
	if not opt then return true end
	local h = opt.hidden
	if type(h) == "function" then
		return Safe(h, info) and true or false
	end
	if type(h) == "string" then
		local fn = ResolveHandlerMethod(opt, info, "hidden")
		if fn then
			return Safe(fn, info) and true or false
		end
	end
	return h and true or false
end
R.EvalHidden = EvalHidden

-- Dynamic hidden checks made while rendering are recorded, so a later setting
-- change can tell "the page must be rebuilt" from "only values/disabled moved".
local function IsHidden(opt, info)
	local hidden = EvalHidden(opt, info)
	if type(opt) == "table" then
		local h = opt.hidden
		if type(h) == "function" or type(h) == "string" then
			local core = SUI._activeOptionsCore or SUI.OptionsCore
			if core and core.WatchHidden then
				core:WatchHidden(opt, info, hidden)
			end
		end
	end
	return hidden
end

local function IsDisabled(opt, info)
	if not opt then return false end
	local d = opt.disabled
	if type(d) == "function" then
		return Safe(d, info) and true or false
	end
	if type(d) == "string" then
		local fn = ResolveHandlerMethod(opt, info, "disabled")
		if fn then
			return Safe(fn, info) and true or false
		end
	end
	if d then return true end
	-- Inherit disabled from parent groups (AceConfig behavior).
	local root = SUI._activeAceOptionsRoot
	if root and type(info) == "table" and #info >= 1 then
		local node = root
		for i = 1, #info - 1 do
			node = node and node.args and node.args[info[i]]
			if not node then break end
			local pd = node.disabled
			if type(pd) == "function" then
				if Safe(pd, info) then return true end
			elseif type(pd) == "string" then
				local fn = ResolveHandlerMethod(node, info, "disabled")
				if fn and Safe(fn, info) then return true end
			elseif pd then
				return true
			end
		end
	end
	return false
end

local function BindDisabled(widget, opt, info)
	if not widget or not widget.SetDisabled then
		return
	end
	widget._suiGetDisabled = function()
		return IsDisabled(opt, info)
	end
	widget:SetDisabled(widget._suiGetDisabled())
end

-- Callback-driven names (status lines, counters, current profile) must follow a
-- setting change without a full page rebuild.
local function BindDynamicName(widget, opt, info)
	if not widget or type(opt) ~= "table" or type(opt.name) ~= "function" then
		return
	end
	if type(widget.SetDynamicText) ~= "function" and not widget.label then
		return
	end
	widget._suiValueWidget = true
	widget.Refresh = function(self)
		local text = ResolveName(opt, info)
		if type(text) == "string" then
			text = text:gsub("^[%s\r\n]+", ""):gsub("[%s\r\n]+$", "")
		end
		if type(self.SetDynamicText) == "function" then
			self:SetDynamicText(text)
		elseif self.label then
			self.label:SetText(text)
		end
	end
end

local function SortedKeys(args)
	local list = {}
	if type(args) ~= "table" then return list end
	for k, v in pairs(args) do
		if type(v) == "table" and v.type then
			tinsert(list, { key = k, order = tonumber(v.order) or 100, opt = v })
		end
	end
	sort(list, function(a, b)
		if a.order == b.order then
			return tostring(a.key) < tostring(b.key)
		end
		return a.order < b.order
	end)
	return list
end

local function ResolveContentWidth()
	local OW = SUI.OptionsWindow
	if OW and OW.GetScrollPixelWidth then
		local expected = OW:GetScrollPixelWidth()
		if OW.contentScroll then
			local w = OW.contentScroll:GetWidth()
			if w and w > 80 then
				return w
			end
		end
		if OW.contentChild then
			local w = OW.contentChild:GetWidth()
			if w and w > 80 then
				return w
			end
		end
		return expected
	end
	if OW and OW.contentScroll then
		local w = OW.contentScroll:GetWidth()
		if w and w > 80 then
			return w
		end
	end
	if OW and OW.contentChild then
		local w = OW.contentChild:GetWidth()
		if w and w > 80 then
			return w
		end
	end
	if OW and OW.root then
		local rootW = OW.root:GetWidth()
		local navW = (T and T.sizes and T.sizes.navW) or 200
		if rootW and rootW > navW + 100 then
			return rootW - navW - 24
		end
	end
	local winW = (T and T.sizes and T.sizes.windowW) or 900
	local navW = (T and T.sizes and T.sizes.navW) or 200
	return math.max(400, winW - navW - 24)
end

local function ResolveTwoPaneRightWidth(shellOrParent)
	local listW = (T and T.sizes and T.sizes.addonListW) or 200
	local parentW = shellOrParent and shellOrParent:GetWidth()
	if (not parentW or parentW < listW + 80) and shellOrParent and shellOrParent.GetParent then
		local p = shellOrParent:GetParent()
		parentW = p and p:GetWidth()
	end
	if not parentW or parentW < listW + 80 then
		parentW = ResolveContentWidth()
	end
	return math.max(200, parentW - listW - 4)
end

-- Remeasure wrapped text, restack children top→bottom, return content bottom + count.
-- When parent._suiTwoCol is set, pack consecutive half-width widgets two-per-row.
-- When parent._suiThreeCol is set, pack consecutive third-width widgets three-per-row.
local function RemeasureWrappedChildren(parent, padX)
	if SUI.OptionsWidgets and SUI.OptionsWidgets.IsDropdownOpen and SUI.OptionsWidgets:IsDropdownOpen() then
		return parent:GetHeight() or 0, 0
	end
	padX = padX or 0
	local gap = (T and T.sizes and T.sizes.rowGap) or 4
	local colGap = 10
	local pw = parent:GetWidth() or 0
	if pw < 80 then
		pw = ResolveContentWidth()
		parent:SetWidth(pw)
	end
	local innerW = math.max(80, pw - padX * 2)
	local children = { parent:GetChildren() }
	local list = {}
	for _, child in ipairs(children) do
		if child and child:IsShown() and not child._suiSkipRelayout then
			local _, _, _, _, cy = child:GetPoint(1)
			tinsert(list, { frame = child, y = cy or 0 })
		end
	end
	sort(list, function(a, b)
		-- TOPLEFT y is negative downward; higher on screen = larger y (closer to 0).
		if a.y ~= b.y then
			return a.y > b.y
		end
		local _, _, _, ax = a.frame:GetPoint(1)
		local _, _, _, bx = b.frame:GetPoint(1)
		return (ax or 0) < (bx or 0)
	end)

	local threeCol = parent._suiThreeCol and true or false
	local twoCol = (not threeCol) and parent._suiTwoCol and true or false
	local halfW = math.floor((innerW - colGap) / 2)
	local thirdW = math.floor((innerW - colGap * 2) / 3)
	if halfW < 120 then
		twoCol = false
	end
	if thirdW < 90 then
		threeCol = false
	end

	local y = nil
	local count = 0
	local i = 1
	while i <= #list do
		local child = list[i].frame
		if child.MeasureHeight then
			local cw = child._fixedWidth
			if not cw or cw <= 0 then
				if threeCol and child._suiThird then
					cw = thirdW
				elseif twoCol and child._suiHalf then
					cw = halfW
				else
					cw = innerW
				end
				child:SetWidth(cw)
			end
			child:MeasureHeight(cw)
		elseif child._relayoutInline then
			child:_relayoutInline()
		end

		if not y then
			y = list[i].y
		end

		local nextItem = list[i + 1]
		local nextChild = nextItem and nextItem.frame
		local thirdItem = list[i + 2]
		local thirdChild = thirdItem and thirdItem.frame
		local trio = threeCol and child._suiThird and nextChild and nextChild._suiThird and thirdChild and thirdChild._suiThird
		local pair = (not trio) and twoCol and child._suiHalf and nextChild and nextChild._suiHalf

		child:ClearAllPoints()
		if trio then
			local rowH = child:GetHeight() or 0
			for col = 0, 2 do
				local f = list[i + col].frame
				local x = padX + col * (thirdW + colGap)
				if f.MeasureHeight then
					f:SetWidth(thirdW)
					f:MeasureHeight(thirdW)
				end
				f._fixedWidth = thirdW
				f._suiThird = true
				f:ClearAllPoints()
				f:SetWidth(thirdW)
				f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
				rowH = math.max(rowH, f:GetHeight() or 0)
			end
			y = y - rowH - gap
			count = count + 3
			i = i + 3
		elseif pair then
			if nextChild.MeasureHeight then
				nextChild:SetWidth(halfW)
				nextChild:MeasureHeight(halfW)
			end
			child._fixedWidth = halfW
			nextChild._fixedWidth = halfW
			child:SetWidth(halfW)
			nextChild:SetWidth(halfW)
			child:SetPoint("TOPLEFT", parent, "TOPLEFT", padX, y)
			nextChild:ClearAllPoints()
			nextChild:SetPoint("TOPLEFT", parent, "TOPLEFT", padX + halfW + colGap, y)
			local h = math.max(child:GetHeight() or 0, nextChild:GetHeight() or 0)
			y = y - h - gap
			count = count + 2
			i = i + 2
		else
			local fixed = child._fixedWidth
			if child._alignCenter and fixed and fixed > 0 then
				child:SetWidth(fixed)
				child:SetPoint("TOP", parent, "TOP", 0, y)
			else
				child:SetPoint("TOPLEFT", parent, "TOPLEFT", padX, y)
				if fixed and fixed > 0 and not child._suiHalf and not child._suiThird then
					child:SetWidth(fixed)
				else
					child._fixedWidth = nil
					child._suiHalf = nil
					child._suiThird = nil
					child:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -padX, y)
					child:SetWidth(innerW)
				end
			end
			local h = child:GetHeight() or 0
			y = y - h - gap
			count = count + 1
			i = i + 1
		end
	end

	local bottom = 0
	if count > 0 then
		-- Strip trailing gap: y is already past last child + gap.
		bottom = -y - gap
	end
	return bottom, count, gap
end

function R:LayoutChild(parent, widget, y, padX)
	if not widget then return y end
	padX = padX or 0
	widget:ClearAllPoints()
	local fixed = widget._fixedWidth
	local availW
	if fixed and fixed > 0 then
		widget:SetWidth(fixed)
		availW = fixed
		if widget._alignCenter then
			widget:SetPoint("TOP", parent, "TOP", 0, y)
		else
			widget:SetPoint("TOPLEFT", parent, "TOPLEFT", padX, y)
		end
	else
		widget:SetPoint("TOPLEFT", parent, "TOPLEFT", padX, y)
		widget:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -padX, y)
		local pw = parent:GetWidth()
		if not pw or pw < padX * 2 + 80 then
			pw = ResolveContentWidth()
			parent:SetWidth(pw)
		end
		availW = math.max(80, pw - padX * 2)
		widget:SetWidth(availW)
	end
	-- Descriptions wrap only after width is known — measure now so parents get real height.
	if widget.MeasureHeight and availW then
		widget:MeasureHeight(availW)
	end
	local h = widget:GetHeight() or 22
	local gap = (T and T.sizes and T.sizes.rowGap) or 4
	return y - h - gap
end

local function ResolveControlWidth(opt)
	if not opt then return nil end
	local w = opt.width
	if w == "full" then
		return nil -- stretch
	end
	if type(w) == "number" and w > 1 then
		return w
	end
	-- Compact width only when explicitly requested (Profiles section).
	if opt.suiCompact then
		return (T and T.sizes and T.sizes.controlMaxW) or 320
	end
	return nil -- default: full content width
end

local function AttachPanelDecorIcon(panel, decorPath, pad)
	if type(decorPath) == "function" then
		local ok, value = pcall(decorPath)
		decorPath = ok and value or nil
	end
	if type(decorPath) ~= "string" or decorPath == "" then
		return
	end

	local decor = CreateFrame("Frame", nil, panel)
	decor:SetFrameLevel((panel:GetFrameLevel() or 1) + 3)
	decor._suiSkipRelayout = true
	local tex = decor:CreateTexture(nil, "ARTWORK")
	tex:SetAllPoints()
	tex:SetTexture(decorPath)
	tex:SetTexCoord(0, 1, 0, 1)
	panel._suiDecorIcon = decor
	panel._placeDecorIcon = function(self)
		local host = self._suiDecorIcon
		if not host then return end
		local pw = self:GetWidth() or 0
		local ph = self:GetHeight() or 0
		if pw < 80 or ph < 40 then
			host:Hide()
			return
		end
		local leftW = (T and T.sizes and T.sizes.controlMaxW) or 320
		local emptyLeft = pad + leftW + 12
		local emptyRight = pw - pad
		if emptyRight - emptyLeft < 48 then
			emptyLeft = pw * 0.5
			emptyRight = pw - pad
		end
		local emptyW = math.max(48, emptyRight - emptyLeft)
		local size = math.floor(math.min(emptyW, ph - pad * 2) * 0.62)
		size = math.max(64, math.min(size, 160))
		local cx = (emptyLeft + emptyRight) * 0.5
		local cy = -ph * 0.5
		host:ClearAllPoints()
		host:SetSize(size, size)
		host:SetPoint("CENTER", self, "TOPLEFT", cx, cy)
		host:Show()
	end
	panel:_placeDecorIcon()
end

local function ApplyConfirm(opt, info, proceed)
	local c = opt.confirm
	if not c then
		proceed()
		return
	end
	local msg
	if type(c) == "function" then
		local ok, res = pcall(c, info)
		if ok and type(res) == "string" then
			msg = res
		elseif ok and res == false then
			proceed()
			return
		elseif ok and res == true then
			msg = opt.confirmText or "Подтвердить действие?"
		else
			msg = opt.confirmText or "Подтвердить действие?"
		end
	elseif c == true then
		msg = opt.confirmText or "Подтвердить действие?"
	else
		proceed()
		return
	end

	-- Prefer Cooltip-styled confirm (same as reload / quick settings).
	if SUI.ShowReloadPopup then
		SUI:ShowReloadPopup(TUI(msg), nil, proceed)
		return
	end

	if not StaticPopupDialogs then
		proceed()
		return
	end
	StaticPopupDialogs["SARYCHUI_OPTIONS_CONFIRM"] = StaticPopupDialogs["SARYCHUI_OPTIONS_CONFIRM"] or {
		text = "Подтвердить действие?",
		button1 = ACCEPT or "OK",
		button2 = CANCEL or "Отмена",
		OnAccept = function(self)
			local data = self and self.data
			if data and data.fn then
				data.fn()
			end
		end,
		timeout = 0,
		whileDead = 1,
		hideOnEscape = 1,
		preferredIndex = 3,
		exclusive = 1,
		showAlert = 1,
	}
	StaticPopupDialogs["SARYCHUI_OPTIONS_CONFIRM"].text = msg
	local popup = StaticPopup_Show("SARYCHUI_OPTIONS_CONFIRM")
	if popup then
		popup.data = { fn = proceed }
		if SUI.RaiseStaticPopupAboveConfig then
			SUI:RaiseStaticPopupAboveConfig(popup)
		end
	else
		proceed()
	end
end

function R:RenderControl(parent, key, opt, path, y, padX, handler)
	padX = padX or 0
	handler = handler or (opt and opt.handler)
	local info = MakeInfo(path, opt, handler)
	if not opt or IsHidden(opt, info) then
		return y
	end

	local name = ResolveName(opt, info)
	local t = opt.type
	local widget
	local compactW = ResolveControlWidth(opt)

	if t == "toggle" then
		widget = W:Checkbox(parent, name, function()
			return CallGet(opt, info)
		end, function(value)
			CallSet(opt, info, value)
		end, MakeTooltip(opt, info), opt.suiHelpIcon, opt.suiPreviewKey)
		-- toggles stay readable full-row
		compactW = nil
	elseif t == "color" then
		widget = W:ColorPicker(parent, name, function()
			return CallGetColor(opt, info)
		end, function(r, g, b, a)
			CallSetColor(opt, info, r, g, b, a)
		end, opt.hasAlpha and true or false, MakeTooltip(opt, info))
		compactW = nil
	elseif t == "range" then
		widget = W:Slider(parent, name, opt.min, opt.max, opt.bigStep or opt.step, function()
			return CallGet(opt, info)
		end, function(value)
			CallSet(opt, info, value)
		end, opt.suiPreviewKey, MakeTooltip(opt, info), opt.suiLiveApply)
	elseif t == "select" then
		local flagPathFn = nil
		if type(opt.suiFlagPathFn) == "function" then
			flagPathFn = opt.suiFlagPathFn
		elseif opt.suiLocaleFlags then
			flagPathFn = function(code)
				return SarychUI.GetLocaleFlagPath and SarychUI.GetLocaleFlagPath(code) or nil
			end
		end
		widget = W:Dropdown(parent, name, function()
			return ResolveValues(opt, info)
		end, function()
			return CallGet(opt, info)
		end, function(value)
			ApplyConfirm(opt, info, function()
				CallSet(opt, info, value)
			end)
		end, TUI(opt.suiPlaceholder or opt.placeholder), flagPathFn)
	elseif t == "input" then
		if opt.suiSaveButton and W.InputWithButton then
			-- suiKeepInput: keep shown value after OK (settings). Default clears (add-to-list).
			widget = W:InputWithButton(parent, name, TUI(tostring(opt.suiSaveButton)), function()
				return CallGet(opt, info)
			end, function(value)
				CallSet(opt, info, value)
			end, not opt.suiKeepInput)
		else
			widget = W:Input(parent, name, function()
				return CallGet(opt, info)
			end, function(value)
				CallSet(opt, info, value)
			end)
		end
	elseif t == "keybinding" then
		widget = W:Keybinding(parent, name, function()
			return CallGet(opt, info)
		end, function(value)
			CallSet(opt, info, value)
		end, MakeTooltip(opt, info))
		compactW = nil
	elseif t == "execute" then
		widget = W:Button(parent, name, function()
			ApplyConfirm(opt, info, function()
				CallFunc(opt, info)
			end)
		end, MakeTooltip(opt, info), function()
			return ResolveName(opt, info)
		end)
		if compactW then
			widget:SetWidth(compactW)
		elseif opt.width == "full" then
			-- Stretch to content width (e.g. Быстрые настройки → Применить).
			compactW = nil
		else
			widget:SetWidth(180)
			compactW = 180
		end
	elseif t == "description" then
		if opt.suiLayoutPreview and SUI.PlatesAurasLayoutPreview and SUI.PlatesAurasLayoutPreview.Create then
			widget = SUI.PlatesAurasLayoutPreview:Create(parent, opt.suiLayoutPreview, opt.suiLayoutPreviewNotice)
			compactW = nil
		elseif (opt.suiDistancePreview or opt.suiLayoutPreview == "distance")
			and (SUI.NameplateDistancePreview or SarychUI.NameplateDistancePreview) then
			local DistPreview = SUI.NameplateDistancePreview or SarychUI.NameplateDistancePreview
			if DistPreview and DistPreview.Create then
				widget = DistPreview:Create(parent, opt.suiDistancePreviewNotice)
				compactW = nil
			else
				widget = W:Description(parent, "|cffff8080Distance preview unavailable|r")
			end
		elseif opt.suiLootRollPreview
			and (SUI.LootRollPreview or SarychUI.LootRollPreview) then
			local LootPreview = SUI.LootRollPreview or SarychUI.LootRollPreview
			if LootPreview and LootPreview.Create then
				widget = LootPreview:Create(parent)
				compactW = nil
			else
				widget = W:Description(parent, "|cffff8080Loot roll preview unavailable|r")
			end
		elseif opt.suiCooldownTextPreview
			and (SUI.CooldownTextPreview or SarychUI.CooldownTextPreview) then
			local CdPreview = SUI.CooldownTextPreview or SarychUI.CooldownTextPreview
			if CdPreview and CdPreview.Create then
				widget = CdPreview:Create(parent)
				compactW = nil
			else
				widget = W:Description(parent, "|cffff8080Cooldown preview unavailable|r")
			end
		elseif opt.suiGcdCooldownPreview
			and (SUI.GcdCooldownPreview or SarychUI.GcdCooldownPreview) then
			local GcdPreview = SUI.GcdCooldownPreview or SarychUI.GcdCooldownPreview
			if GcdPreview and GcdPreview.Create then
				widget = GcdPreview:Create(parent)
				compactW = nil
			else
				widget = W:Description(parent, "|cffff8080GCD preview unavailable|r")
			end
		elseif opt.suiActionBarTextPreview
			and (SUI.ActionBarTextPreview or SarychUI.ActionBarTextPreview) then
			local AbPreview = SUI.ActionBarTextPreview or SarychUI.ActionBarTextPreview
			if AbPreview and AbPreview.Create then
				widget = AbPreview:Create(parent)
				compactW = nil
			else
				widget = W:Description(parent, "|cffff8080Action bar preview unavailable|r")
			end
		elseif opt.suiActionBarColorPreview
			and (SUI.ActionBarColorPreview or SarychUI.ActionBarColorPreview) then
			local ColorPreview = SUI.ActionBarColorPreview or SarychUI.ActionBarColorPreview
			if ColorPreview and ColorPreview.Create then
				widget = ColorPreview:Create(parent)
				compactW = nil
			else
				widget = W:Description(parent, "|cffff8080Color preview unavailable|r")
			end
		elseif opt.suiActionBarAppearancePreview
			and (SUI.ActionBarAppearancePreview or SarychUI.ActionBarAppearancePreview) then
			local AppPreview = SUI.ActionBarAppearancePreview or SarychUI.ActionBarAppearancePreview
			if AppPreview and AppPreview.Create then
				widget = AppPreview:Create(parent)
				compactW = nil
			else
				widget = W:Description(parent, "|cffff8080Appearance preview unavailable|r")
			end
		elseif opt.suiActionBarTransparencyPreview
			and (SUI.ActionBarTransparencyPreview or SarychUI.ActionBarTransparencyPreview) then
			local TrPreview = SUI.ActionBarTransparencyPreview or SarychUI.ActionBarTransparencyPreview
			if TrPreview and TrPreview.Create then
				widget = TrPreview:Create(parent)
				compactW = nil
			else
				widget = W:Description(parent, "|cffff8080Transparency preview unavailable|r")
			end
		elseif opt.suiActionBarBarsPreview
			and (SUI.ActionBarBarsPreview or SarychUI.ActionBarBarsPreview) then
			local BarsPreview = SUI.ActionBarBarsPreview or SarychUI.ActionBarBarsPreview
			if BarsPreview and BarsPreview.Create then
				widget = BarsPreview:Create(parent)
				compactW = nil
			else
				widget = W:Description(parent, "|cffff8080Bars preview unavailable|r")
			end
		elseif opt.suiErrorFilterPreview
			and (SUI.ErrorFilterPreview or SarychUI.ErrorFilterPreview) then
			local ErrPreview = SUI.ErrorFilterPreview or SarychUI.ErrorFilterPreview
			if ErrPreview and ErrPreview.Create then
				widget = ErrPreview:Create(parent)
				compactW = nil
			else
				widget = W:Description(parent, "|cffff8080Error preview unavailable|r")
			end
		elseif opt.suiSysMsgPreview
			and (SUI.SysMsgPreview or SarychUI.SysMsgPreview) then
			local SysPreview = SUI.SysMsgPreview or SarychUI.SysMsgPreview
			if SysPreview and SysPreview.Create then
				widget = SysPreview:Create(parent)
				compactW = nil
			else
				widget = W:Description(parent, "|cffff8080SysMsg preview unavailable|r")
			end
		elseif opt.suiBossEmotePreview
			and (SUI.BossEmotePreview or SarychUI.BossEmotePreview) then
			local BossPreview = SUI.BossEmotePreview or SarychUI.BossEmotePreview
			if BossPreview and BossPreview.Create then
				widget = BossPreview:Create(parent)
				compactW = nil
			else
				widget = W:Description(parent, "|cffff8080Boss emote preview unavailable|r")
			end
		elseif opt.suiFrameHitPreview
			and (SUI.FrameHitPreview or SarychUI.FrameHitPreview) then
			local HitPreview = SUI.FrameHitPreview or SarychUI.FrameHitPreview
			if HitPreview and HitPreview.Create then
				widget = HitPreview:Create(parent)
				compactW = nil
			else
				widget = W:Description(parent, "|cffff8080Frame hit preview unavailable|r")
			end
		elseif opt.suiArenaPreview
			and (SUI.ArenaPreview or SarychUI.ArenaPreview) then
			local ArenaPreview = SUI.ArenaPreview or SarychUI.ArenaPreview
			if ArenaPreview and ArenaPreview.Create then
				widget = ArenaPreview:Create(parent)
				compactW = nil
			else
				widget = W:Description(parent, "|cffff8080Arena preview unavailable|r")
			end
		elseif opt.suiAurasPreview
			and (SUI.AurasPreview or SarychUI.AurasPreview) then
			local AurasPreview = SUI.AurasPreview or SarychUI.AurasPreview
			if AurasPreview and AurasPreview.Create then
				widget = AurasPreview:Create(parent)
				compactW = nil
			else
				widget = W:Description(parent, "|cffff8080Auras preview unavailable|r")
			end
		elseif opt.suiMinimapPreview
			and (SUI.MinimapPreview or SarychUI.MinimapPreview) then
			local MinimapPreview = SUI.MinimapPreview or SarychUI.MinimapPreview
			if MinimapPreview and MinimapPreview.Create then
				widget = MinimapPreview:Create(parent)
				compactW = nil
			else
				widget = W:Description(parent, "|cffff8080Minimap preview unavailable|r")
			end
		elseif opt.suiCombatIndicatorPreview
			and (SUI.CombatIndicatorPreview or SarychUI.CombatIndicatorPreview) then
			local CombatIndPreview = SUI.CombatIndicatorPreview or SarychUI.CombatIndicatorPreview
			if CombatIndPreview and CombatIndPreview.Create then
				widget = CombatIndPreview:Create(parent)
				compactW = nil
			else
				widget = W:Description(parent, "|cffff8080Combat indicator preview unavailable|r")
			end
		elseif opt.suiFramePvpPreview
			and (SUI.FramePvpPreview or SarychUI.FramePvpPreview) then
			local PvpPreview = SUI.FramePvpPreview or SarychUI.FramePvpPreview
			if PvpPreview and PvpPreview.Create then
				widget = PvpPreview:Create(parent)
				compactW = nil
			else
				widget = W:Description(parent, "|cffff8080PVP preview unavailable|r")
			end
		elseif opt.suiChatTooltipPreview
			and (SUI.ChatTooltipPreview or SarychUI.ChatTooltipPreview) then
			local TipPreview = SUI.ChatTooltipPreview or SarychUI.ChatTooltipPreview
			if TipPreview and TipPreview.Create then
				widget = TipPreview:Create(parent)
				compactW = nil
			else
				widget = W:Description(parent, "|cffff8080Chat tooltip preview unavailable|r")
			end
		elseif opt.suiCombatTextPreview
			and (SUI.CombatTextPreview or SarychUI.CombatTextPreview) then
			local CombatPreview = SUI.CombatTextPreview or SarychUI.CombatTextPreview
			if CombatPreview and CombatPreview.Create then
				widget = CombatPreview:Create(parent)
				compactW = nil
			else
				widget = W:Description(parent, "|cffff8080Combat text preview unavailable|r")
			end
		elseif opt.suiCastbarTimerPreview
			and (SUI.CastbarTimerPreview or SarychUI.CastbarTimerPreview) then
			local CastPreview = SUI.CastbarTimerPreview or SarychUI.CastbarTimerPreview
			if CastPreview and CastPreview.Create then
				widget = CastPreview:Create(parent)
				compactW = nil
			else
				widget = W:Description(parent, "|cffff8080Castbar preview unavailable|r")
			end
		elseif opt.suiCountdownTimerPreview
			and (SUI.CountdownTimerPreview or SarychUI.CountdownTimerPreview) then
			local CdwnPreview = SUI.CountdownTimerPreview or SarychUI.CountdownTimerPreview
			if CdwnPreview and CdwnPreview.Create then
				widget = CdwnPreview:Create(parent)
				compactW = nil
			else
				widget = W:Description(parent, "|cffff8080Countdown preview unavailable|r")
			end
		else
			local text = name
			if text == "" and type(opt.name) == "function" then
				text = tostring(Safe(opt.name, info) or "")
				text = TUI(text)
			end
			-- Trim leading/trailing blank lines so panel padding stays even.
			if type(text) == "string" then
				text = text:gsub("^[%s\r\n]+", ""):gsub("[%s\r\n]+$", "")
			end
			if opt.image then
				local iw = opt.imageWidth or 64
				local ih = opt.imageHeight or 64
				local align = tostring(opt.imageAlign or "LEFT"):upper()
				local centerInContent = opt.imageCenterInContent and true or false
				local imgFrame = CreateFrame("Frame", nil, parent)
				local hostH = ih
				if centerInContent then
					local OW = SUI.OptionsWindow
					local viewportH = (OW and OW.contentScroll and OW.contentScroll:GetHeight()) or 0
					if viewportH > ih then
						hostH = viewportH
					end
				end
				imgFrame:SetHeight(hostH)
				local tex = imgFrame:CreateTexture(nil, "ARTWORK")
				tex:SetTexture(opt.image)
				tex:SetSize(iw, ih)
				if align == "CENTER" or centerInContent then
					local yOff = centerInContent and 56 or 0
					tex:SetPoint("CENTER", imgFrame, "CENTER", 0, yOff)
				elseif align == "RIGHT" then
					tex:SetPoint("RIGHT", imgFrame, "RIGHT", 0, 0)
				else
					tex:SetPoint("LEFT", imgFrame, "LEFT", 0, 0)
				end
				if text ~= "" then
					widget = W:Description(parent, text)
					y = self:LayoutChild(parent, widget, y, padX)
				end
				if centerInContent then
					imgFrame:ClearAllPoints()
					imgFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
					imgFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
					imgFrame:SetHeight(hostH)
					parent:SetHeight(hostH)
					return -hostH
				end
				y = self:LayoutChild(parent, imgFrame, y, padX)
				return y
			end
			if opt.suiSpinner then
				widget = W:SpinnerLabel(parent, text)
			else
				widget = W:Description(parent, text)
			end
			BindDynamicName(widget, opt, info)
			compactW = nil
		end
	elseif t == "header" then
		local tipFn
		if type(opt.desc) == "function" then
			tipFn = function()
				return Safe(opt.desc, info)
			end
		elseif type(opt.desc) == "string" and opt.desc ~= "" then
			tipFn = function()
				return opt.desc
			end
		end
		widget = W:Header(parent, name, tipFn)
		BindDynamicName(widget, opt, info)
		compactW = nil
	elseif t == "group" then
		local childHandler = opt.handler or handler
		-- Inline groups render children; non-inline are usually nav sections.
		local isInline = opt.inline or opt.dialogInline or opt.guiInline
		-- Compact list row: label + optional remove button on one line.
		if isInline and opt.suiCompactListRow and W.CompactListRow then
			local labelOpt = opt.args and (opt.args.idLabel or opt.args.label or opt.args.text)
			local buttonOpt = opt.args and (opt.args.removeBtn or opt.args.button or opt.args.execute)
			if labelOpt then
				local labelInfo = MakeInfo(path, labelOpt, childHandler)
				local labelText = ResolveName(labelOpt, labelInfo)
				if labelText == "" and type(labelOpt.name) == "function" then
					labelText = tostring(Safe(labelOpt.name, labelInfo) or "")
				end
				local iconTexture = opt.icon or (labelOpt and labelOpt.icon)
				if type(iconTexture) == "function" then
					iconTexture = Safe(iconTexture, labelInfo)
				end
				local buttonText, onClick
				if buttonOpt and not IsHidden(buttonOpt, MakeInfo(path, buttonOpt, childHandler)) then
					local buttonPath = {}
					for i = 1, #path do buttonPath[i] = path[i] end
					for k, v in pairs(opt.args) do
						if v == buttonOpt then tinsert(buttonPath, k) end
					end
					local buttonInfo = MakeInfo(buttonPath, buttonOpt, childHandler)
					buttonText = ResolveName(buttonOpt, buttonInfo)
					onClick = function()
						ApplyConfirm(buttonOpt, buttonInfo, function()
							CallFunc(buttonOpt, buttonInfo)
						end)
					end
				else
					buttonText = false
				end
				widget = W:CompactListRow(parent, labelText, buttonText, onClick, iconTexture)
				y = self:LayoutChild(parent, widget, y, padX)
				return y
			end
		end
		if isInline and opt.suiOneRowAdd then
			-- Compact one-row: type select + ID input + Add button.
			local typeOpt = opt.args and (opt.args.spellType or opt.args.type)
			local idOpt = opt.args and (opt.args.spellID or opt.args.id or opt.args.input)
			if typeOpt and idOpt and W.SelectInputButton then
				if name and name ~= "" then
					local header = W:Header(parent, name)
					y = self:LayoutChild(parent, header, y, padX)
				end
				local typePath, idPath = {}, {}
				for i = 1, #path do
					typePath[i] = path[i]
					idPath[i] = path[i]
				end
				for k, v in pairs(opt.args) do
					if v == typeOpt then tinsert(typePath, k) end
					if v == idOpt then tinsert(idPath, k) end
				end
				local typeInfo = MakeInfo(typePath, typeOpt, childHandler)
				local idInfo = MakeInfo(idPath, idOpt, childHandler)
				local onDraft
				if type(idOpt.suiOnDraft) == "function" then
					onDraft = function(text)
						idOpt.suiOnDraft(text)
					end
				end
				widget = W:SelectInputButton(
					parent,
					ResolveName(typeOpt, typeInfo),
					function() return ResolveValues(typeOpt, typeInfo) end,
					function() return CallGet(typeOpt, typeInfo) end,
					function(value) CallSet(typeOpt, typeInfo, value) end,
					ResolveName(idOpt, idInfo),
					function() return CallGet(idOpt, idInfo) end,
					function(value) CallSet(idOpt, idInfo, value) end,
					tostring(idOpt.suiSaveButton or "Добавить"),
					onDraft
				)
				y = self:LayoutChild(parent, widget, y, padX)
				return y
			end
		end
		if isInline then
			local showHeader = type(name) == "string" and name:gsub("%s+", "") ~= ""
			local sorted = SortedKeys(opt.args)
			local childHandler = opt.handler or handler

			if showHeader then
				local tipFn
				if type(opt.desc) == "function" then
					tipFn = function()
						return Safe(opt.desc, MakeInfo(path, opt, childHandler))
					end
				elseif type(opt.desc) == "string" and opt.desc ~= "" then
					tipFn = function()
						return opt.desc
					end
				end
				local header = W:Header(parent, name, tipFn, opt.suiHeaderIcon, opt.suiHelpIcon)
				y = self:LayoutChild(parent, header, y)
			end
			local panel = W:Panel(parent)
			panel:SetHeight(10)
			panel._suiTwoCol = opt.suiTwoCol and true or false
			panel._suiThreeCol = opt.suiThreeCol and true or false
			local pad = (T and T.sizes and T.sizes.panelPad) or 8
			local gap = (T and T.sizes and T.sizes.rowGap) or 4
			local colGap = 10
			-- Give panel a provisional width so wrapped descriptions measure correctly.
			local parentW = parent:GetWidth()
			if parentW and parentW > 40 then
				panel:SetWidth(parentW)
			end
			local innerY = -pad
			local rendered = 0
			local pendingRow = {}
			local panelInnerW = math.max(80, (panel:GetWidth() or parentW or 400) - pad * 2)
			local halfW = math.floor((panelInnerW - colGap) / 2)
			local thirdW = math.floor((panelInnerW - colGap * 2) / 3)
			local canThreeCol = panel._suiThreeCol and thirdW >= 90
			local canTwoCol = (not canThreeCol) and panel._suiTwoCol and halfW >= 120
			local rowCols = canThreeCol and 3 or (canTwoCol and 2 or 1)
			local colW = canThreeCol and thirdW or halfW

			local function FlushPendingRow()
				local n = #pendingRow
				if n == 0 then return end
				if n >= rowCols and rowCols > 1 then
					local rowH = 0
					for col = 1, rowCols do
						local widget = pendingRow[col]
						local x = pad + (col - 1) * (colW + colGap)
						widget._fixedWidth = colW
						if canThreeCol then
							widget._suiThird = true
						else
							widget._suiHalf = true
						end
						widget:ClearAllPoints()
						widget:SetWidth(colW)
						widget:SetPoint("TOPLEFT", panel, "TOPLEFT", x, innerY)
						rowH = math.max(rowH, widget:GetHeight() or 34)
					end
					innerY = innerY - rowH - gap
					rendered = rendered + rowCols
				else
					for _, widget in ipairs(pendingRow) do
						widget._fixedWidth = nil
						widget._suiHalf = nil
						widget._suiThird = nil
						innerY = self:LayoutChild(panel, widget, innerY, pad)
						rendered = rendered + 1
					end
				end
				wipe(pendingRow)
			end

			local function BuildInlineWidget(eOpt, eInfo, eName)
				local tipFn
				if type(eOpt.suiTooltip) == "function" then
					tipFn = eOpt.suiTooltip
				elseif type(eOpt.desc) == "function" then
					tipFn = function() return Safe(eOpt.desc, eInfo) end
				elseif type(eOpt.desc) == "string" and eOpt.desc ~= "" then
					tipFn = function() return eOpt.desc end
				end
				local widget
				if eOpt.type == "range" then
					widget = W:Slider(panel, eName, eOpt.min, eOpt.max, eOpt.bigStep or eOpt.step, function()
						return CallGet(eOpt, eInfo)
					end, function(value)
						CallSet(eOpt, eInfo, value)
					end, eOpt.suiPreviewKey, tipFn, eOpt.suiLiveApply)
				elseif eOpt.type == "select" then
					local eFlagPathFn = nil
					if type(eOpt.suiFlagPathFn) == "function" then
						eFlagPathFn = eOpt.suiFlagPathFn
					elseif eOpt.suiLocaleFlags then
						eFlagPathFn = function(code)
							return SarychUI.GetLocaleFlagPath and SarychUI.GetLocaleFlagPath(code) or nil
						end
					end
					widget = W:Dropdown(panel, eName, function()
						return ResolveValues(eOpt, eInfo)
					end, function()
						return CallGet(eOpt, eInfo)
					end, function(value)
						ApplyConfirm(eOpt, eInfo, function()
							CallSet(eOpt, eInfo, value)
						end)
					end, eOpt.suiPlaceholder or eOpt.placeholder, eFlagPathFn)
				elseif eOpt.type == "input" then
					if eOpt.suiSaveButton and W.InputWithButton then
						widget = W:InputWithButton(panel, eName, tostring(eOpt.suiSaveButton), function()
							return CallGet(eOpt, eInfo)
						end, function(value)
							CallSet(eOpt, eInfo, value)
						end, not eOpt.suiKeepInput)
					else
						widget = W:Input(panel, eName, function()
							return CallGet(eOpt, eInfo)
						end, function(value)
							CallSet(eOpt, eInfo, value)
						end)
					end
				end
				if widget then
					BindDisabled(widget, eOpt, eInfo)
				end
				return widget
			end

			-- Select + settings button inside the bordered panel (same level as other controls).
			if opt.suiSelectWithButton and W.SelectWithButton then
				local selectOpt = opt.args and (opt.args.indicatorType or opt.args.mode or opt.args.mapType or opt.args.frameType or opt.args.select or opt.args.choose)
				local buttonOpt = opt.args and (opt.args.openSettings or opt.args.openElvUISettings or opt.args.button or opt.args.applyProfile)
				if selectOpt and buttonOpt then
					local selectPath, buttonPath = {}, {}
					for i = 1, #path do
						selectPath[i] = path[i]
						buttonPath[i] = path[i]
					end
					for k, v in pairs(opt.args) do
						if v == selectOpt then tinsert(selectPath, k) end
						if v == buttonOpt then tinsert(buttonPath, k) end
					end
					local selectInfo = MakeInfo(selectPath, selectOpt, childHandler)
					local buttonInfo = MakeInfo(buttonPath, buttonOpt, childHandler)
					local buttonTooltipFn
					if type(buttonOpt.desc) == "function" then
						buttonTooltipFn = function() return Safe(buttonOpt.desc, buttonInfo) end
					elseif type(buttonOpt.desc) == "string" and buttonOpt.desc ~= "" then
						buttonTooltipFn = function() return buttonOpt.desc end
					end
					local rowWidget = W:SelectWithButton(
						panel,
						ResolveName(selectOpt, selectInfo),
						function() return ResolveValues(selectOpt, selectInfo) end,
						function() return CallGet(selectOpt, selectInfo) end,
						function(value) CallSet(selectOpt, selectInfo, value) end,
						ResolveName(buttonOpt, buttonInfo),
						function()
							ApplyConfirm(buttonOpt, buttonInfo, function()
								CallFunc(buttonOpt, buttonInfo)
							end)
						end,
						buttonTooltipFn,
						function()
							return IsHidden(buttonOpt, buttonInfo)
						end
					)
					if selectOpt.suiCompact then
						rowWidget._fixedWidth = (T and T.sizes and T.sizes.controlMaxW) or 320
					end
					if rowWidget.actionBtn and opt.args.applyProfile == buttonOpt then
						rowWidget.actionBtn:SetWidth(90)
					end
					BindDisabled(rowWidget, selectOpt, selectInfo)
					innerY = self:LayoutChild(panel, rowWidget, innerY, pad)
					rendered = rendered + 1
					local skip = {}
					for k, v in pairs(opt.args) do
						if v == selectOpt or v == buttonOpt then
							skip[k] = true
						end
					end
					for _, entry in ipairs(sorted) do
						if not skip[entry.key] then
							local childPath = {}
							for i = 1, #path do childPath[i] = path[i] end
							tinsert(childPath, entry.key)
							local before = innerY
							innerY = self:RenderControl(panel, entry.key, entry.opt, childPath, innerY, pad, childHandler)
							if innerY ~= before then
								rendered = rendered + 1
							end
						end
					end
					panel._relayoutInline = function(self)
						if self._relayoutLock then return end
						self._relayoutLock = true
						local bottom, count = RemeasureWrappedChildren(self, pad)
						local h = (count > 0) and math.max(pad * 2, bottom + pad) or (pad * 2)
						if math.abs((self:GetHeight() or 0) - h) > 0.5 then
							self:SetHeight(h)
						end
						if self._placeDecorIcon then
							self:_placeDecorIcon()
						end
						self._relayoutLock = nil
					end
					if rendered > 0 then
						panel:SetHeight(math.max(pad * 2, -innerY - gap + pad))
					else
						panel:SetHeight(pad * 2)
					end
					AttachPanelDecorIcon(panel, opt.suiPanelDecorIcon, pad)
					panel:SetScript("OnSizeChanged", function(self)
						self:_relayoutInline()
					end)
					y = self:LayoutChild(parent, panel, y)
					panel:_relayoutInline()
					return y
				end
			end

			for _, entry in ipairs(sorted) do
				local childPath = {}
				for i = 1, #path do childPath[i] = path[i] end
				tinsert(childPath, entry.key)
				local eOpt = entry.opt
				local packable = rowCols > 1 and eOpt and not eOpt.suiFullRow
					and (eOpt.type == "range" or eOpt.type == "select" or eOpt.type == "input")
				if packable then
					local eInfo = MakeInfo(childPath, eOpt, childHandler)
					if not IsHidden(eOpt, eInfo) then
						local widget = BuildInlineWidget(eOpt, eInfo, ResolveName(eOpt, eInfo))
						if widget then
							tinsert(pendingRow, widget)
							if #pendingRow >= rowCols then
								FlushPendingRow()
							end
						end
					end
				else
					FlushPendingRow()
					local before = innerY
					innerY = self:RenderControl(panel, entry.key, entry.opt, childPath, innerY, pad, childHandler)
					if innerY ~= before then
						rendered = rendered + 1
					end
				end
			end
			FlushPendingRow()
			-- After width settles (anchors / OnSizeChanged), remeasure wrapped text
			-- and grow the bordered panel to fit.
			panel._relayoutInline = function(self)
				if self._relayoutLock then return end
				self._relayoutLock = true
				local bottom, count = RemeasureWrappedChildren(self, pad)
				local h
				if count > 0 then
					h = math.max(pad * 2, bottom + pad)
				else
					h = pad * 2
				end
				if math.abs((self:GetHeight() or 0) - h) > 0.5 then
					self:SetHeight(h)
				end
				if self._placeDecorIcon then
					self:_placeDecorIcon()
				end
				self._relayoutLock = nil
			end
			if rendered > 0 then
				panel:SetHeight(math.max(pad * 2, -innerY - gap + pad))
			else
				panel:SetHeight(pad * 2)
			end

			-- Decorative icon centered in the empty right half (e.g. Profiles).
			AttachPanelDecorIcon(panel, opt.suiPanelDecorIcon, pad)

			panel:SetScript("OnSizeChanged", function(self)
				self:_relayoutInline()
			end)
			y = self:LayoutChild(parent, panel, y)
			panel:_relayoutInline()
			return y
		else
			-- Non-inline nested group: show as header + children in content
			local header = W:Header(parent, name)
			y = self:LayoutChild(parent, header, y)
			local pad = (T and T.sizes and T.sizes.contentPad) or 4
			local sorted = SortedKeys(opt.args)
			for _, entry in ipairs(sorted) do
				local childPath = {}
				for i = 1, #path do childPath[i] = path[i] end
				tinsert(childPath, entry.key)
				y = self:RenderControl(parent, entry.key, entry.opt, childPath, y, pad, childHandler)
			end
			return y
		end
	elseif t == "multiselect" then
		local values = ResolveValues(opt, info)
		local getFn = ResolveInheritedMethod(opt, info, "get")
		local setFn = ResolveInheritedMethod(opt, info, "set")
		local host = CreateFrame("Frame", nil, parent)
		local titleFS = host:CreateFontString(nil, "OVERLAY", T and T.fonts and T.fonts.normal or "GameFontNormal")
		titleFS:SetPoint("TOPLEFT", 0, 0)
		titleFS:SetText(name or "")
		if T and T.SetTextColor then T:SetTextColor(titleFS, "title") end
		local keys = {}
		for k in pairs(values) do
			if k ~= "__order" then tinsert(keys, k) end
		end
		if type(values.__order) == "table" then
			local orderMap = {}
			for i, k in ipairs(values.__order) do orderMap[k] = i end
			sort(keys, function(a, b)
				local oa, ob = orderMap[a] or 9999, orderMap[b] or 9999
				if oa == ob then return tostring(a) < tostring(b) end
				return oa < ob
			end)
		else
			sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		end
		local yMS = -22
		local colW = tonumber(opt.customWidth) or 180
		local cols = math.max(1, math.floor(220 / math.max(40, colW / 2)))
		if #keys <= 8 then cols = math.min(4, #keys) end
		local col = 0
		local rowY = yMS
		local maxBottom = 22
		for _, mkey in ipairs(keys) do
			local label = values[mkey]
			local cb = W:Checkbox(host, label, function()
				if not getFn then return false end
				return Safe(getFn, info, mkey) and true or false
			end, function(value)
				if setFn then
					Safe(setFn, info, mkey, value)
				end
				local core = SUI._activeOptionsCore
				if core and core.Refresh then
					core:Refresh()
				else
					NotifyActiveCoreChanged()
				end
			end, MakeTooltip(opt, info))
			cb:ClearAllPoints()
			cb:SetPoint("TOPLEFT", host, "TOPLEFT", col * (colW + 8), rowY)
			cb:SetWidth(colW)
			col = col + 1
			if col >= cols then
				col = 0
				rowY = rowY - 26
			end
			maxBottom = math.max(maxBottom, -rowY + 26)
		end
		if col > 0 then
			maxBottom = math.max(maxBottom, -rowY + 26)
		end
		host:SetHeight(maxBottom + 4)
		widget = host
		compactW = nil
	else
		R.unsupportedTypes[t] = (R.unsupportedTypes[t] or 0) + 1
		widget = W:Unsupported(parent, t .. " (" .. tostring(key) .. ")")
	end

	if widget then
		if compactW then
			widget._fixedWidth = compactW
		end
		if opt.suiAlign == "CENTER" or opt.suiAlign == "center" then
			widget._alignCenter = true
			-- Center label + control inside the fixed-width row.
			if widget.label then
				widget.label:ClearAllPoints()
				widget.label:SetJustifyH("CENTER")
				widget.label:SetPoint("TOP", widget, "TOP", 0, 0)
				if compactW then
					widget.label:SetWidth(compactW)
				end
			end
			if widget.btn then
				widget.btn:ClearAllPoints()
				if widget.label then
					widget.btn:SetPoint("TOP", widget.label, "BOTTOM", 0, -2)
				else
					widget.btn:SetPoint("TOP", widget, "TOP", 0, 0)
				end
				if compactW then
					widget.btn:SetWidth(compactW)
				end
			end
		end
		BindDisabled(widget, opt, info)
		y = self:LayoutChild(parent, widget, y, padX)
	end
	return y
end

function R:RenderSection(parent, sectionOpt, path)
	if not parent then return end
	if SUI.OptionsCore and SUI.OptionsCore._perf then
		SUI.OptionsCore._perf.created = (SUI.OptionsCore._perf.created or 0)
	end
	local contentPad = (T and T.sizes and T.sizes.contentPad) or 4
	local y = -contentPad
	local sectionHandler = sectionOpt and sectionOpt.handler
	if not sectionOpt then
		local d = W:Description(parent, "Секция не найдена.")
		self:LayoutChild(parent, d, y, contentPad)
		parent:SetHeight(40)
		return
	end

	-- When rendering a tabbed section's body, skip nested non-inline groups
	-- (they are shown as tabs). Render only leaf controls + inline groups.
	local sorted = SortedKeys(sectionOpt.args)
	local rendered = 0
	local hasContentTabs = false
	local activeCore = SUI._activeOptionsCore or SUI.OptionsCore
	if activeCore and activeCore.GetTabGroups then
		hasContentTabs = #(activeCore:GetTabGroups(sectionOpt)) > 0
	elseif sectionOpt.childGroups == "tab" or sectionOpt.childGroups == "tabs" then
		hasContentTabs = true
	end
	local skipTreeChildren = sectionOpt.childGroups == "tree"
	if #sorted == 0 then
		local d = W:Description(parent, ResolveName(sectionOpt) ~= "" and ResolveName(sectionOpt) or "Нет настроек в этой секции.")
		y = self:LayoutChild(parent, d, y, contentPad)
	else
		for _, entry in ipairs(sorted) do
			local opt = entry.opt
			-- Skip non-inline groups when parent is shown via tabs/subtabs or tree nav.
			local optInline = opt.inline or opt.dialogInline or opt.guiInline
			if opt.type == "group" and not optInline and (hasContentTabs or skipTreeChildren) then
				-- skip — rendered as tab/subtab content or left-nav section
			else
				local childPath = {}
				for i = 1, #(path or {}) do childPath[i] = path[i] end
				tinsert(childPath, entry.key)
				y = self:RenderControl(parent, entry.key, opt, childPath, y, contentPad, sectionHandler)
				rendered = rendered + 1
			end
		end
		if rendered == 0 and not skipTreeChildren then
			-- Fallback: render all (e.g. tab content that is itself a group of controls)
			for _, entry in ipairs(sorted) do
				local childPath = {}
				for i = 1, #(path or {}) do childPath[i] = path[i] end
				tinsert(childPath, entry.key)
				y = self:RenderControl(parent, entry.key, entry.opt, childPath, y, contentPad, sectionHandler)
			end
		end
	end
	-- Remeasure wrapped descriptions now that parent width is final.
	-- Height = content bottom (includes top pad via first child) + matching bottom pad.
	local bottom = RemeasureWrappedChildren(parent, contentPad)
	local fromLayout = -y + contentPad
	-- Strip trailing rowGap from LayoutChild chain (same as Remeasure).
	local gap = (T and T.sizes and T.sizes.rowGap) or 4
	if rendered > 0 or fromLayout > contentPad then
		fromLayout = fromLayout - gap
	end
	parent:SetHeight(math.max(contentPad * 2, fromLayout, bottom + contentPad))
	if SUI.OptionsCore and SUI.OptionsCore._perf then
		SUI.OptionsCore._perf.created = (SUI.OptionsCore._perf.created or 0) + rendered
	end
end

-----------------------------------------------------------------------
-- Two-pane lists: left names / right settings (Аддоны → Список, Миникарта → Кнопки).
-----------------------------------------------------------------------
local function PathKey(path)
	if not path or #path == 0 then return "root" end
	local parts = {}
	for i = 1, #path do
		parts[i] = tostring(path[i])
	end
	return concat(parts, "/")
end

local function CollectTwoPaneEntries(groupOpt)
	local list = {}
	local shared = {}
	if not groupOpt or type(groupOpt.args) ~= "table" then
		return list, shared
	end
	for k, v in pairs(groupOpt.args) do
		if type(v) == "table" and v.type then
			-- ENP stays a separate window (/enp); bags/arena engines live in their modules.
			if k == "ElvUI_NamePlates" or k == "BaudBag" or k == "GladiusEx" or k == "SarychUI_Bags" then
				-- skip
			elseif v.type == "group" and not v.inline and not v.dialogInline and not v.guiInline and not IsHidden(v, MakeInfo({ k }, v)) then
				local info = MakeInfo({ k }, v)
				local icon = v.icon
				if type(icon) == "function" then
					icon = Safe(icon, info)
				end
				tinsert(list, {
					key = k,
					order = tonumber(v.order) or 100,
					opt = v,
					label = ResolveName(v, info),
					icon = icon,
					listGroup = v.suiListGroup,
					listGroupRank = tonumber(v.suiListGroupRank),
					listGroupOrder = tonumber(v.suiListGroupOrder),
				})
			elseif not IsHidden(v, MakeInfo({ k }, v)) then
				-- Shared controls above the two-pane (headers, toggles, buttons…).
				tinsert(shared, {
					key = k,
					order = tonumber(v.order) or 100,
					opt = v,
				})
			end
		end
	end
	sort(list, function(a, b)
		local ga, gb = a.listGroup, b.listGroup
		if not ga and gb then
			return true
		end
		if ga and not gb then
			return false
		end
		if ga and gb then
			local ra = a.listGroupRank or 100
			local rb = b.listGroupRank or 100
			if ra ~= rb then
				return ra < rb
			end
			if ga ~= gb then
				return ga < gb
			end
			local oa = a.listGroupOrder or a.order or 100
			local ob = b.listGroupOrder or b.order or 100
			if oa ~= ob then
				return oa < ob
			end
		end
		local la = tostring(a.label or a.key):lower()
		local lb = tostring(b.label or b.key):lower()
		if la == lb then
			return tostring(a.key) < tostring(b.key)
		end
		return la < lb
	end)
	sort(shared, function(a, b)
		if a.order == b.order then
			return tostring(a.key) < tostring(b.key)
		end
		return a.order < b.order
	end)
	return list, shared
end

local function StyleAddonListButton(btn, active)
	btn._active = active and true or false
	if active then
		T:ApplyFlat(btn, T.colors.navActive, T.colors.accent)
		T:SetTextColor(btn.label, "title")
	else
		btn:SetBackdrop(nil)
		T:SetTextColor(btn.label, "text")
	end
end

local function GetNestedTabGroups(opt)
	-- Local copy of OptionsCore:GetTabGroups so right-pane tabs stay self-contained.
	if not opt or type(opt.args) ~= "table" then return {} end
	local groups = {}
	for k, v in pairs(opt.args) do
		local isInline = v.inline or v.dialogInline or v.guiInline
		if type(v) == "table" and v.type == "group" and not isInline and not IsHidden(v, MakeInfo({ k }, v)) then
			tinsert(groups, {
				key = k,
				order = tonumber(v.order) or 100,
				opt = v,
				label = ResolveName(v),
			})
		end
	end
	sort(groups, function(a, b)
		if a.order == b.order then
			return tostring(a.key) < tostring(b.key)
		end
		return a.order < b.order
	end)
	if #groups < 1 then return {} end
	if opt.childGroups == "tab" or #groups >= 2 then
		return groups
	end
	return {}
end

local function StyleLocalTab(btn, active)
	btn._active = active and true or false
	if active then
		T:ApplyFlat(btn, T.colors.tabActive, T.colors.accent)
		T:SetTextColor(btn.label, "title")
	else
		T:ApplyFlat(btn, T.colors.tabBg, T.colors.borderSoft)
		T:SetTextColor(btn.label, "textDim")
	end
end

-- Two-pane detail redraws on its own (left-list click, nested tabs), so it keeps
-- a separate hidden snapshot instead of piggybacking on the page one.
function R:RenderAddonDetail(detailHost, addonOpt, addonPath, addonKey)
	local core = SUI._activeOptionsCore or SUI.OptionsCore
	local token = core and core.BeginHiddenCapture and core:BeginHiddenCapture()
	local ok, err = pcall(self._RenderAddonDetail, self, detailHost, addonOpt, addonPath, addonKey)
	if core and core.EndHiddenCapture then
		core:EndHiddenCapture(token)
	end
	if not ok then
		geterrorhandler()(err)
	end
end

function R:_RenderAddonDetail(detailHost, addonOpt, addonPath, addonKey)
	-- Clear previous detail by recreating body (avoids GetChildren unpack).
	local old = detailHost._body
	if old then
		old:Hide()
		old:SetParent(nil)
		detailHost._body = nil
	end
	detailHost:SetScript("OnUpdate", nil)

	-- detailHost may sit inside a ScrollFrame; climb to the right pane that owns title/enable.
	local right = detailHost:GetParent()
	while right and not right._enableHost and not right._addonListSyncHeights do
		right = right:GetParent()
	end
	local shell = right and right:GetParent()
	local rightW = ResolveTwoPaneRightWidth(shell or right)
	local liveRightW = right and right:GetWidth()
	if liveRightW and liveRightW > 120 then
		rightW = liveRightW
	elseif right then
		right:SetWidth(rightW)
	end
	local scrollW = (T and T.sizes and T.sizes.addonListScrollW) or 8
	local hostW = math.max(160, rightW - scrollW - 16)
	detailHost:SetWidth(hostW)

	-- Place root "Включить" on the title row (right-aligned), not in the body.
	local enableHost = right and right._enableHost
	local titleLabel = right and right._titleLabel
	local titleParent = titleLabel and titleLabel:GetParent()
	local function RefreshTitleLayout()
		if right and right._setTitleIcon then
			local icon = addonOpt and addonOpt.icon
			if type(icon) == "function" then
				icon = Safe(icon)
			end
			right._setTitleIcon(icon)
		elseif titleLabel and titleParent then
			titleLabel:ClearAllPoints()
			titleLabel:SetPoint("LEFT", titleParent, "LEFT", 0, 0)
			if enableHost and enableHost:IsShown() then
				titleLabel:SetPoint("RIGHT", enableHost, "LEFT", -8, 0)
			else
				titleLabel:SetPoint("RIGHT", titleParent, "RIGHT", 0, 0)
			end
		end
	end
	if enableHost then
		local oldEnable = enableHost._widget
		if oldEnable then
			oldEnable:Hide()
			oldEnable:SetParent(nil)
			enableHost._widget = nil
		end
		enableHost:Hide()
		RefreshTitleLayout()
	end

	local enableOpt = addonOpt and addonOpt.args and addonOpt.args.enabled
	if enableOpt and enableOpt.type == "toggle" and enableHost then
		local enablePath = {}
		for i = 1, #(addonPath or {}) do
			enablePath[i] = addonPath[i]
		end
		tinsert(enablePath, "enabled")
		local enableInfo = MakeInfo(enablePath, enableOpt, addonOpt.handler)
		if not IsHidden(enableOpt, enableInfo) then
			local enableName = ResolveName(enableOpt, enableInfo)
			local tooltipFn
			if type(enableOpt.suiTooltip) == "function" then
				tooltipFn = enableOpt.suiTooltip
			elseif type(enableOpt.desc) == "function" then
				tooltipFn = function()
					return Safe(enableOpt.desc, enableInfo)
				end
			elseif type(enableOpt.desc) == "string" and enableOpt.desc ~= "" then
				tooltipFn = function()
					return enableOpt.desc
				end
			end
			local widget = W:Checkbox(enableHost, enableName or "Включить", function()
				return CallGet(enableOpt, enableInfo)
			end, function(value)
				CallSet(enableOpt, enableInfo, value)
			end, tooltipFn)
			BindDisabled(widget, enableOpt, enableInfo)
			local needW = 16 + 6 + ((widget.label and widget.label:GetStringWidth()) or 60) + 4
			needW = math.max(80, needW)
			enableHost:SetWidth(needW)
			widget:ClearAllPoints()
			widget:SetPoint("TOPLEFT", enableHost, "TOPLEFT", 0, 0)
			widget:SetPoint("BOTTOMRIGHT", enableHost, "BOTTOMRIGHT", 0, 0)
			enableHost._widget = widget
			enableHost:Show()
			RefreshTitleLayout()
		end
	end

	-- Shallow copy args without enabled so body doesn't duplicate the toggle.
	local bodyOpt = addonOpt
	if enableOpt and enableHost and enableHost._widget then
		bodyOpt = {}
		for k, v in pairs(addonOpt) do
			bodyOpt[k] = v
		end
		bodyOpt.args = {}
		for k, v in pairs(addonOpt.args) do
			if k ~= "enabled" then
				bodyOpt.args[k] = v
			end
		end
	end

	local body = CreateFrame("Frame", nil, detailHost)
	body:SetPoint("TOPLEFT", 0, 0)
	body:SetPoint("TOPRIGHT", 0, 0)
	body:SetWidth(hostW)
	detailHost._body = body

	local function RefreshDetailHeights()
		if not body or not body:IsShown() then return end
		if body._heightLock then return end
		body._heightLock = true
		-- Re-sync widths if right pane finally got a real size after first paint.
		local r = right
		local liveW = r and r:GetWidth()
		if liveW and liveW > 120 then
			local sw = (T and T.sizes and T.sizes.addonListScrollW) or 8
			local nextHostW = math.max(160, liveW - sw - 16)
			if math.abs((detailHost:GetWidth() or 0) - nextHostW) > 1 then
				detailHost:SetWidth(nextHostW)
				body:SetWidth(nextHostW)
				hostW = nextHostW
			end
		end
		local contentPad = (T and T.sizes and T.sizes.contentPad) or 4
		local h
		local tabBar = body._tabBar
		local contentFrame = body._contentFrame
		if tabBar and contentFrame and contentFrame._inner then
			local tabH = T.sizes.tabH or 24
			local inner = contentFrame._inner
			inner:SetWidth(hostW)
			contentFrame:SetWidth(hostW)
			local innerBottom = RemeasureWrappedChildren(inner, contentPad)
			local ih = math.max(contentPad * 2, inner:GetHeight() or 0, innerBottom + contentPad)
			inner:SetHeight(ih)
			contentFrame:SetHeight(ih)
			h = ih + tabH + 6
		else
			local bottom = RemeasureWrappedChildren(body, contentPad)
			h = math.max(contentPad * 2, bottom + contentPad)
		end
		body:SetHeight(h)
		detailHost:SetHeight(math.max(contentPad * 2, h))
		if r and r._addonListSyncHeights then
			r._addonListSyncHeights()
		end
		body._heightLock = nil
	end
	body._onContentHeightChanged = RefreshDetailHeights
	detailHost._onContentHeightChanged = RefreshDetailHeights

	-- One-shot deferred remeasure: first open often has width=0 until next frame.
	detailHost:SetScript("OnUpdate", function(self)
		self:SetScript("OnUpdate", nil)
		RefreshDetailHeights()
	end)

	local tabs = GetNestedTabGroups(bodyOpt)

	if #tabs > 0 then
		local OC = SUI.OptionsCore
		OC._addonListTabState = OC._addonListTabState or {}
		local saved = addonKey and OC._addonListTabState[addonKey]
		local active = tabs[1]
		for _, tab in ipairs(tabs) do
			if tab.key == saved then
				active = tab
				break
			end
		end
		if addonKey then
			OC._addonListTabState[addonKey] = active.key
		end

		local tabBar = CreateFrame("Frame", nil, body)
		tabBar:SetPoint("TOPLEFT", 4, -2)
		tabBar:SetPoint("TOPRIGHT", -4, -2)
		tabBar:SetHeight(T.sizes.tabH or 24)
		body._tabBar = tabBar

		local x = 0
		local tabH = T.sizes.tabH or 24
		local tabButtons = {}
		local contentFrame = CreateFrame("Frame", nil, body)
		contentFrame:SetPoint("TOPLEFT", 0, -(tabH + 6))
		contentFrame:SetPoint("TOPRIGHT", 0, -(tabH + 6))
		contentFrame:SetWidth(hostW)
		body._contentFrame = contentFrame

		local function ShowTab(tab)
			if not tab then return end
			if contentFrame._activeKey == tab.key and contentFrame._inner then
				return
			end
			if addonKey and OC then
				OC._addonListTabState[addonKey] = tab.key
			end
			contentFrame._activeKey = tab.key
			for _, b in ipairs(tabButtons) do
				StyleLocalTab(b, b.tabKey == tab.key)
			end
			local oldC = contentFrame._inner
			if oldC then
				oldC:Hide()
				oldC:SetParent(nil)
				contentFrame._inner = nil
			end
			local inner = CreateFrame("Frame", nil, contentFrame)
			inner:SetPoint("TOPLEFT", 0, 0)
			inner:SetPoint("TOPRIGHT", 0, 0)
			inner:SetWidth(hostW)
			inner._onContentHeightChanged = RefreshDetailHeights
			contentFrame._inner = inner
			local tabPath = {}
			for i = 1, #(addonPath or {}) do
				tabPath[i] = addonPath[i]
			end
			tinsert(tabPath, tab.key)
			local core = SUI._activeOptionsCore or SUI.OptionsCore
			local token = core and core.BeginHiddenCapture and core:BeginHiddenCapture()
			self:RenderSection(inner, tab.opt, tabPath)
			if core and core.EndHiddenCapture then
				core:EndHiddenCapture(token)
			end
			RefreshDetailHeights()
		end

		for _, tab in ipairs(tabs) do
			local tabKey = tab.key
			local btn = CreateFrame("Button", nil, tabBar)
			btn:SetHeight(tabH)
			btn:RegisterForClicks("LeftButtonDown")
			local fs = btn:CreateFontString(nil, "OVERLAY", T.fonts.small)
			fs:SetPoint("LEFT", 8, 0)
			fs:SetPoint("RIGHT", -8, 0)
			fs:SetJustifyH("CENTER")
			fs:SetText(tab.label or tabKey)
			btn.label = fs
			btn.tabKey = tabKey
			local w = math.max(70, (fs:GetStringWidth() or 40) + 20)
			btn:SetWidth(w)
			btn:SetPoint("TOPLEFT", tabBar, "TOPLEFT", x, 0)
			StyleLocalTab(btn, tabKey == active.key)
			btn:SetScript("OnEnter", function(self)
				if self._active then return end
				T:ApplyFlat(self, T.colors.navHover, T.colors.borderSoft)
			end)
			btn:SetScript("OnLeave", function(self)
				StyleLocalTab(self, self._active)
			end)
			btn:SetScript("OnClick", function(self)
				local key = self.tabKey
				if not key then return end
				local chosen
				for i = 1, #tabs do
					if tabs[i].key == key then
						chosen = tabs[i]
						break
					end
				end
				if chosen then
					ShowTab(chosen)
				end
			end)
			tinsert(tabButtons, btn)
			x = x + w + 2
		end

		ShowTab(active)
		return
	end

	self:RenderSection(body, bodyOpt, addonPath)
	RefreshDetailHeights()
end

function R:RenderTwoPaneAddonList(parent, groupOpt, path)
	if not parent then return end
	local OC = SUI.OptionsCore
	local OW = SUI.OptionsWindow
	local listW = (T and T.sizes and T.sizes.addonListW) or 200
	local itemH = (T and T.sizes and T.sizes.navItemH) or 22
	local contentPad = (T and T.sizes and T.sizes.contentPad) or 4
	local pathKey = PathKey(path)
	local isAddonPorted = pathKey == "addons/ported"

	local entries, shared = CollectTwoPaneEntries(groupOpt)

	-- Shared controls (refresh, toggles…) above the two-pane split.
	local yTop = -contentPad
	if #shared > 0 then
		for _, entry in ipairs(shared) do
			local childPath = {}
			for i = 1, #(path or {}) do childPath[i] = path[i] end
			tinsert(childPath, entry.key)
			yTop = self:RenderControl(parent, entry.key, entry.opt, childPath, yTop, contentPad)
		end
		yTop = yTop - 6
	end

	if #entries == 0 then
		local d = W:Description(parent, "Нет элементов в списке.")
		self:LayoutChild(parent, d, yTop, contentPad)
		parent:SetHeight(math.max(40, -yTop + 40))
		return
	end

	-- Runtime selection (compat: Аддоны → Список still uses _addonListSelected).
	OC._twoPaneSelected = OC._twoPaneSelected or {}
	OC._twoPaneScroll = OC._twoPaneScroll or {}
	local selected = OC._twoPaneSelected[pathKey]
	if isAddonPorted then
		selected = OC._addonListSelected or selected
	end
	local found
	for _, e in ipairs(entries) do
		if e.key == selected then
			found = e
			break
		end
	end
	if not found then
		found = entries[1]
		selected = found.key
	end
	OC._twoPaneSelected[pathKey] = selected
	if isAddonPorted then
		OC._addonListSelected = selected
	end

	local shell = CreateFrame("Frame", nil, parent)
	shell:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yTop)
	shell:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yTop)
	-- Force a known width before children measure wrapped text.
	local contentW = ResolveContentWidth()
	local parentW = parent:GetWidth()
	if parentW and parentW > 80 then
		contentW = parentW
	else
		parent:SetWidth(contentW)
	end
	shell:SetWidth(contentW)

	local scrollW = (T and T.sizes and T.sizes.addonListScrollW) or 8
	local left = CreateFrame("Frame", nil, shell)
	left:SetPoint("TOPLEFT", 0, 0)
	left:SetWidth(listW)
	left:EnableMouse(true)
	T:ApplyFlat(left, T.colors.navBg, T.colors.borderSoft)

	local listScroll = CreateFrame("ScrollFrame", "SarychUIAddonListScroll", left)
	listScroll:SetPoint("TOPLEFT", 2, -2)
	listScroll:SetPoint("BOTTOMLEFT", 2, 2)
	listScroll:SetPoint("RIGHT", left, "RIGHT", -(scrollW + 4), 0)
	listScroll:EnableMouse(true)

	local listChild = CreateFrame("Frame", nil, listScroll)
	listChild:SetWidth(math.max(40, listW - scrollW - 12))
	listChild:SetHeight(1)
	listScroll:SetScrollChild(listChild)

	local listContentH = #entries * itemH + 4

	local sbTrack = CreateFrame("Button", "SarychUIAddonListScrollBar", left)
	sbTrack:SetWidth(scrollW)
	sbTrack:SetPoint("TOPRIGHT", left, "TOPRIGHT", -2, -2)
	sbTrack:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", -2, 2)
	sbTrack:EnableMouse(true)
	T:ApplyFlat(sbTrack, T.colors.scrollTrack or T.colors.inputBg, T.colors.borderSoft)

	local sbThumb = CreateFrame("Button", nil, sbTrack)
	sbThumb:SetWidth(scrollW)
	sbThumb:SetHeight(24)
	sbThumb:SetPoint("TOP", sbTrack, "TOP", 0, 0)
	sbThumb:EnableMouse(true)
	sbThumb:RegisterForDrag("LeftButton")
	T:ApplyFlat(sbThumb, T.colors.scrollThumb or T.colors.buttonBg, T.colors.accent)

	local function GetViewportH()
		local viewportH = 200
		if OW and OW.contentScroll then
			local vis = OW.contentScroll:GetHeight() or 0
			if vis > 40 then
				viewportH = vis
			end
		end
		-- Space already used above this two-pane (add-spell row, inline type tabs,
		-- or shared controls rendered inside the two-pane parent).
		local usedAbove = math.abs(yTop or 0)
		if parent and OW and OW.contentChild and parent ~= OW.contentChild then
			local top = parent:GetTop()
			local childTop = OW.contentChild:GetTop()
			if top and childTop then
				usedAbove = usedAbove + math.max(0, childTop - top)
			else
				local _, _, _, _, py = parent:GetPoint(1)
				if type(py) == "number" then
					usedAbove = usedAbove + math.abs(py)
				end
			end
		end
		if usedAbove > 0 and viewportH > usedAbove + 40 then
			viewportH = viewportH - usedAbove
		end
		return math.max(120, viewportH)
	end

	local function UpdateScrollbarThumb()
		if listScroll.UpdateScrollChildRect then
			listScroll:UpdateScrollChildRect()
		end
		local viewH = listScroll:GetHeight() or 0
		if viewH < 1 then
			viewH = math.max(1, (left:GetHeight() or GetViewportH()) - 4)
		end
		local contentH = math.max(listContentH or 0, 1)
		local max = listScroll:GetVerticalScrollRange() or 0
		if max <= 0 then
			max = math.max(0, contentH - viewH)
		end
		-- Show immediately when content exceeds viewport (don't wait for first wheel).
		if contentH <= viewH + 1 and max <= 0 then
			sbTrack:Hide()
			sbThumb:Hide()
			return
		end
		sbTrack:Show()
		sbThumb:Show()
		local trackH = sbTrack:GetHeight() or viewH
		if trackH < 1 then trackH = viewH end
		if trackH < 1 then trackH = 1 end
		local ratio = viewH / math.max(contentH, 1)
		local thumbH = math.max(18, trackH * ratio)
		if thumbH > trackH then thumbH = trackH end
		sbThumb:SetHeight(thumbH)
		local cur = listScroll:GetVerticalScroll() or 0
		local travel = math.max(0, trackH - thumbH)
		local y = 0
		if max > 0 and travel > 0 then
			y = (cur / max) * travel
		elseif contentH > viewH and travel > 0 then
			y = (cur / math.max(1, contentH - viewH)) * travel
		end
		sbThumb:ClearAllPoints()
		sbThumb:SetPoint("TOP", sbTrack, "TOP", 0, -y)
	end

	local function SetAddonListScroll(offset, syncThumb)
		if listScroll.UpdateScrollChildRect then
			listScroll:UpdateScrollChildRect()
		end
		local max = listScroll:GetVerticalScrollRange() or 0
		if max <= 0 then
			local viewH = listScroll:GetHeight() or 1
			max = math.max(0, listContentH - viewH)
		end
		if offset < 0 then offset = 0 end
		if offset > max then offset = max end
		listScroll:SetVerticalScroll(offset)
		OC._twoPaneScroll[pathKey] = offset
		if isAddonPorted then
			OC._addonListScroll = offset
		end
		if syncThumb ~= false then
			UpdateScrollbarThumb()
		end
		return offset
	end

	local function LayoutLeftPane()
		local viewportH = GetViewportH()
		left:ClearAllPoints()
		left:SetPoint("TOPLEFT", shell, "TOPLEFT", 0, 0)
		left:SetPoint("BOTTOMLEFT", shell, "BOTTOMLEFT", 0, 0)
		left:SetWidth(listW)
		left:SetHeight(viewportH)
		left:SetFrameLevel((shell:GetFrameLevel() or 1) + 5)
		UpdateScrollbarThumb()
	end

	local function ScrollAddonList(delta)
		local cur = listScroll:GetVerticalScroll() or 0
		local max = listScroll:GetVerticalScrollRange() or 0
		if max <= 0 then
			local viewH = listScroll:GetHeight() or 1
			max = math.max(0, listContentH - viewH)
		end
		if max > 0 then
			SetAddonListScroll(cur - delta * itemH, true)
			return true
		end
		return false
	end

	sbThumb:SetScript("OnEnter", function(self)
		T:ApplyFlat(self, T.colors.scrollThumbHover or T.colors.buttonHover, T.colors.accent)
	end)
	sbThumb:SetScript("OnLeave", function(self)
		if not self._dragging then
			T:ApplyFlat(self, T.colors.scrollThumb or T.colors.buttonBg, T.colors.accent)
		end
	end)
	sbThumb:SetScript("OnMouseDown", function(self)
		self._dragging = true
		T:ApplyFlat(self, T.colors.scrollThumbHover or T.colors.buttonHover, T.colors.accent)
	end)
	sbThumb:SetScript("OnMouseUp", function(self)
		self._dragging = false
		T:ApplyFlat(self, T.colors.scrollThumb or T.colors.buttonBg, T.colors.accent)
	end)
	sbThumb:SetScript("OnDragStart", function(self)
		self._dragging = true
		self:SetScript("OnUpdate", function(thumb)
			local trackH = sbTrack:GetHeight() or 1
			local thumbH = thumb:GetHeight() or 18
			local travel = math.max(0, trackH - thumbH)
			local max = listScroll:GetVerticalScrollRange() or 0
			if max <= 0 then
				local viewH = listScroll:GetHeight() or 1
				max = math.max(0, listContentH - viewH)
			end
			if travel <= 0 or max <= 0 then return end
			local scale = UIParent:GetEffectiveScale() or 1
			local _, cursorY = GetCursorPosition()
			cursorY = cursorY / scale
			local top = sbTrack:GetTop() or cursorY
			local rel = top - cursorY - (thumbH * 0.5)
			if rel < 0 then rel = 0 end
			if rel > travel then rel = travel end
			SetAddonListScroll((rel / travel) * max, true)
		end)
	end)
	sbThumb:SetScript("OnDragStop", function(self)
		self._dragging = false
		self:SetScript("OnUpdate", nil)
		T:ApplyFlat(self, T.colors.scrollThumb or T.colors.buttonBg, T.colors.accent)
	end)
	sbTrack:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" then return end
		local trackH = self:GetHeight() or 1
		local thumbH = sbThumb:GetHeight() or 18
		local travel = math.max(0, trackH - thumbH)
		local max = listScroll:GetVerticalScrollRange() or 0
		if max <= 0 then
			local viewH = listScroll:GetHeight() or 1
			max = math.max(0, listContentH - viewH)
		end
		if travel <= 0 or max <= 0 then return end
		local scale = UIParent:GetEffectiveScale() or 1
		local _, cursorY = GetCursorPosition()
		cursorY = cursorY / scale
		local top = self:GetTop() or cursorY
		local rel = top - cursorY - (thumbH * 0.5)
		if rel < 0 then rel = 0 end
		if rel > travel then rel = travel end
		SetAddonListScroll((rel / travel) * max, true)
	end)
	sbTrack:EnableMouseWheel(true)
	sbTrack:SetScript("OnMouseWheel", function(_, delta)
		ScrollAddonList(delta)
	end)
	sbThumb:EnableMouseWheel(true)
	sbThumb:SetScript("OnMouseWheel", function(_, delta)
		ScrollAddonList(delta)
	end)

	left:EnableMouseWheel(true)
	left:SetScript("OnMouseWheel", function(_, delta)
		ScrollAddonList(delta)
	end)
	listScroll:EnableMouseWheel(true)
	listScroll:SetScript("OnMouseWheel", function(_, delta)
		ScrollAddonList(delta)
	end)

	local right = CreateFrame("Frame", nil, shell)
	local rightW = ResolveTwoPaneRightWidth(shell)
	right:SetPoint("TOPLEFT", shell, "TOPLEFT", listW + 4, 0)
	right:SetPoint("TOPRIGHT", shell, "TOPRIGHT", 0, 0)
	right:SetWidth(rightW)
	right:EnableMouse(true)
	T:ApplyFlat(right, T.colors.panelBg, T.colors.borderSoft)

	local titleRowH = (T.sizes and T.sizes.rowH) or 22
	local titleRow = CreateFrame("Frame", nil, right)
	titleRow:SetPoint("TOPLEFT", 8, -4)
	titleRow:SetPoint("TOPRIGHT", -(scrollW + 10), -4)
	titleRow:SetHeight(titleRowH)

	local titleIconSize = math.max(14, titleRowH - 4)
	local titleIcon = titleRow:CreateTexture(nil, "ARTWORK")
	titleIcon:SetSize(titleIconSize, titleIconSize)
	titleIcon:SetPoint("LEFT", titleRow, "LEFT", 0, 0)
	titleIcon:Hide()

	local title = titleRow:CreateFontString(nil, "OVERLAY", T.fonts.title)
	title:SetPoint("LEFT", titleRow, "LEFT", 0, 0)
	title:SetPoint("RIGHT", titleRow, "RIGHT", -120, 0)
	title:SetJustifyH("LEFT")
	T:SetTextColor(title, "title")
	title:SetText(found.label or found.key)

	local enableHost = CreateFrame("Frame", nil, titleRow)
	enableHost:SetPoint("RIGHT", titleRow, "RIGHT", 0, 0)
	enableHost:SetHeight(titleRowH)
	enableHost:SetWidth(120)
	right._enableHost = enableHost
	right._titleLabel = title
	right._titleIcon = titleIcon
	right._titleIconSize = titleIconSize

	local function SetTitleIcon(tex)
		local icon = right._titleIcon
		local label = right._titleLabel
		if not icon or not label then return end
		local parent = label:GetParent()
		local size = right._titleIconSize or 16
		if tex then
			if type(tex) == "number" then
				icon:SetTexture(tex)
			else
				icon:SetTexture(tostring(tex))
			end
			icon:Show()
			label:ClearAllPoints()
			label:SetPoint("LEFT", parent, "LEFT", size + 6, 0)
			if enableHost:IsShown() then
				label:SetPoint("RIGHT", enableHost, "LEFT", -8, 0)
			else
				label:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
			end
		else
			icon:Hide()
			label:ClearAllPoints()
			label:SetPoint("LEFT", parent, "LEFT", 0, 0)
			if enableHost:IsShown() then
				label:SetPoint("RIGHT", enableHost, "LEFT", -8, 0)
			else
				label:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
			end
		end
	end
	right._setTitleIcon = SetTitleIcon
	SetTitleIcon(found.icon)

	-- Right detail: own scroll + scrollbar (same style as left spell list).
	local rightScroll = CreateFrame("ScrollFrame", nil, right)
	rightScroll:SetPoint("TOPLEFT", 4, -(titleRowH + 8))
	rightScroll:SetPoint("BOTTOMLEFT", 4, 4)
	rightScroll:SetPoint("RIGHT", right, "RIGHT", -(scrollW + 8), 0)
	rightScroll:EnableMouse(true)

	local detailHost = CreateFrame("Frame", nil, rightScroll)
	detailHost:SetWidth(math.max(160, rightW - scrollW - 16))
	detailHost:SetHeight(1)
	rightScroll:SetScrollChild(detailHost)

	local rightSbTrack = CreateFrame("Button", nil, right)
	rightSbTrack:SetWidth(scrollW)
	rightSbTrack:SetPoint("TOPRIGHT", right, "TOPRIGHT", -2, -(titleRowH + 8))
	rightSbTrack:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", -2, 4)
	rightSbTrack:EnableMouse(true)
	T:ApplyFlat(rightSbTrack, T.colors.scrollTrack or T.colors.inputBg, T.colors.borderSoft)

	local rightSbThumb = CreateFrame("Button", nil, rightSbTrack)
	rightSbThumb:SetWidth(scrollW)
	rightSbThumb:SetHeight(24)
	rightSbThumb:SetPoint("TOP", rightSbTrack, "TOP", 0, 0)
	rightSbThumb:EnableMouse(true)
	rightSbThumb:RegisterForDrag("LeftButton")
	T:ApplyFlat(rightSbThumb, T.colors.scrollThumb or T.colors.buttonBg, T.colors.accent)

	OC._twoPaneDetailScroll = OC._twoPaneDetailScroll or {}
	local detailContentH = 1

	local function UpdateRightScrollbarThumb()
		if rightScroll.UpdateScrollChildRect then
			rightScroll:UpdateScrollChildRect()
		end
		local viewH = rightScroll:GetHeight() or 0
		if viewH < 1 then
			viewH = math.max(1, (right:GetHeight() or GetViewportH()) - titleRowH - 12)
		end
		local contentH = math.max(detailContentH or 0, 1)
		local max = rightScroll:GetVerticalScrollRange() or 0
		if max <= 0 then
			max = math.max(0, contentH - viewH)
		end
		if contentH <= viewH + 1 and max <= 0 then
			rightSbTrack:Hide()
			rightSbThumb:Hide()
			return
		end
		rightSbTrack:Show()
		rightSbThumb:Show()
		local trackH = rightSbTrack:GetHeight() or viewH
		if trackH < 1 then trackH = viewH end
		if trackH < 1 then trackH = 1 end
		local ratio = viewH / math.max(contentH, 1)
		local thumbH = math.max(18, trackH * ratio)
		if thumbH > trackH then thumbH = trackH end
		rightSbThumb:SetHeight(thumbH)
		local cur = rightScroll:GetVerticalScroll() or 0
		local travel = math.max(0, trackH - thumbH)
		local yOff = 0
		if max > 0 and travel > 0 then
			yOff = (cur / max) * travel
		elseif contentH > viewH and travel > 0 then
			yOff = (cur / math.max(1, contentH - viewH)) * travel
		end
		rightSbThumb:ClearAllPoints()
		rightSbThumb:SetPoint("TOP", rightSbTrack, "TOP", 0, -yOff)
	end

	local function SetRightDetailScroll(offset, syncThumb)
		if rightScroll.UpdateScrollChildRect then
			rightScroll:UpdateScrollChildRect()
		end
		local max = rightScroll:GetVerticalScrollRange() or 0
		if max <= 0 then
			local viewH = rightScroll:GetHeight() or 1
			max = math.max(0, detailContentH - viewH)
		end
		if offset < 0 then offset = 0 end
		if offset > max then offset = max end
		rightScroll:SetVerticalScroll(offset)
		OC._twoPaneDetailScroll[pathKey] = offset
		if syncThumb ~= false then
			UpdateRightScrollbarThumb()
		end
		return offset
	end

	local function ScrollRightDetail(delta)
		local cur = rightScroll:GetVerticalScroll() or 0
		local max = rightScroll:GetVerticalScrollRange() or 0
		if max <= 0 then
			local viewH = rightScroll:GetHeight() or 1
			max = math.max(0, detailContentH - viewH)
		end
		if max > 0 then
			SetRightDetailScroll(cur - delta * 28, true)
			return true
		end
		return false
	end

	rightSbThumb:SetScript("OnEnter", function(self)
		T:ApplyFlat(self, T.colors.scrollThumbHover or T.colors.buttonHover, T.colors.accent)
	end)
	rightSbThumb:SetScript("OnLeave", function(self)
		if not self._dragging then
			T:ApplyFlat(self, T.colors.scrollThumb or T.colors.buttonBg, T.colors.accent)
		end
	end)
	rightSbThumb:SetScript("OnMouseDown", function(self)
		self._dragging = true
		T:ApplyFlat(self, T.colors.scrollThumbHover or T.colors.buttonHover, T.colors.accent)
	end)
	rightSbThumb:SetScript("OnMouseUp", function(self)
		self._dragging = false
		T:ApplyFlat(self, T.colors.scrollThumb or T.colors.buttonBg, T.colors.accent)
	end)
	rightSbThumb:SetScript("OnDragStart", function(self)
		self._dragging = true
		self:SetScript("OnUpdate", function(thumb)
			local trackH = rightSbTrack:GetHeight() or 1
			local thumbH = thumb:GetHeight() or 18
			local travel = math.max(0, trackH - thumbH)
			local max = rightScroll:GetVerticalScrollRange() or 0
			if max <= 0 then
				local viewH = rightScroll:GetHeight() or 1
				max = math.max(0, detailContentH - viewH)
			end
			if travel <= 0 or max <= 0 then return end
			local scale = UIParent:GetEffectiveScale() or 1
			local _, cursorY = GetCursorPosition()
			cursorY = cursorY / scale
			local top = rightSbTrack:GetTop() or cursorY
			local rel = top - cursorY - (thumbH * 0.5)
			if rel < 0 then rel = 0 end
			if rel > travel then rel = travel end
			SetRightDetailScroll((rel / travel) * max, true)
		end)
	end)
	rightSbThumb:SetScript("OnDragStop", function(self)
		self._dragging = false
		self:SetScript("OnUpdate", nil)
		T:ApplyFlat(self, T.colors.scrollThumb or T.colors.buttonBg, T.colors.accent)
	end)
	rightSbTrack:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" then return end
		local trackH = self:GetHeight() or 1
		local thumbH = rightSbThumb:GetHeight() or 18
		local travel = math.max(0, trackH - thumbH)
		local max = rightScroll:GetVerticalScrollRange() or 0
		if max <= 0 then
			local viewH = rightScroll:GetHeight() or 1
			max = math.max(0, detailContentH - viewH)
		end
		if travel <= 0 or max <= 0 then return end
		local scale = UIParent:GetEffectiveScale() or 1
		local _, cursorY = GetCursorPosition()
		cursorY = cursorY / scale
		local top = self:GetTop() or cursorY
		local rel = top - cursorY - (thumbH * 0.5)
		if rel < 0 then rel = 0 end
		if rel > travel then rel = travel end
		SetRightDetailScroll((rel / travel) * max, true)
	end)
	rightSbTrack:EnableMouseWheel(true)
	rightSbTrack:SetScript("OnMouseWheel", function(_, delta)
		ScrollRightDetail(delta)
	end)
	rightSbThumb:EnableMouseWheel(true)
	rightSbThumb:SetScript("OnMouseWheel", function(_, delta)
		ScrollRightDetail(delta)
	end)
	rightScroll:EnableMouseWheel(true)
	rightScroll:SetScript("OnMouseWheel", function(_, delta)
		ScrollRightDetail(delta)
	end)
	right:EnableMouseWheel(true)
	right:SetScript("OnMouseWheel", function(_, delta)
		ScrollRightDetail(delta)
	end)
	detailHost:EnableMouseWheel(true)
	detailHost:SetScript("OnMouseWheel", function(_, delta)
		ScrollRightDetail(delta)
	end)

	local function WireDetailMouseWheel(frame)
		if not frame then return end
		frame:EnableMouseWheel(true)
		frame:SetScript("OnMouseWheel", function(_, delta)
			ScrollRightDetail(delta)
		end)
	end

	local buttons = {}

	local function LayoutRightPane()
		local viewportH = GetViewportH()
		right:ClearAllPoints()
		right:SetPoint("TOPLEFT", shell, "TOPLEFT", listW + 4, 0)
		right:SetPoint("BOTTOMRIGHT", shell, "BOTTOMRIGHT", 0, 0)
		right:SetHeight(viewportH)
		right:SetFrameLevel((shell:GetFrameLevel() or 1) + 5)
		UpdateRightScrollbarThumb()
	end

	local function SyncHeights()
		local dh = detailHost:GetHeight() or 40
		detailContentH = math.max(1, dh)
		detailHost:SetHeight(detailContentH)
		if rightScroll.UpdateScrollChildRect then
			rightScroll:UpdateScrollChildRect()
		end

		-- Both panes fill remaining viewport; only their inner scrolls move.
		local viewportH = GetViewportH()
		shell:SetHeight(viewportH)
		parent:SetHeight(math.max(40, -yTop + viewportH + 8))

		-- Clamp the outer content child to the scroll viewport so the page
		-- itself cannot scroll — only the spell list / detail panes do.
		if OW and OW.contentScroll and OW.contentChild then
			local scrollH = OW.contentScroll:GetHeight() or 0
			if scrollH > 40 then
				OW.contentChild:SetHeight(scrollH)
			end
			OW.contentScroll:SetVerticalScroll(0)
			if OW.SetContentScrollLocked then
				OW:SetContentScrollLocked(true)
			end
		end

		listChild:SetHeight(math.max(1, listContentH))
		if listScroll.UpdateScrollChildRect then
			listScroll:UpdateScrollChildRect()
		end

		LayoutLeftPane()
		LayoutRightPane()
		local savedScroll = OC._twoPaneScroll[pathKey]
		if isAddonPorted and OC._addonListScroll then
			savedScroll = OC._addonListScroll
		end
		SetAddonListScroll(savedScroll or 0, true)
		SetRightDetailScroll(OC._twoPaneDetailScroll[pathKey] or 0, true)
	end
	right._addonListSyncHeights = SyncHeights

	shell:SetScript("OnUpdate", function(self)
		if not self:IsVisible() then return end
		local viewportH = GetViewportH()
		if self._lastViewportH ~= viewportH then
			self._lastViewportH = viewportH
			shell:SetHeight(viewportH)
			parent:SetHeight(math.max(40, -yTop + viewportH + 8))
			if OW and OW.contentScroll and OW.contentChild then
				local scrollH = OW.contentScroll:GetHeight() or 0
				if scrollH > 40 then
					OW.contentChild:SetHeight(scrollH)
				end
				OW.contentScroll:SetVerticalScroll(0)
			end
			LayoutLeftPane()
			LayoutRightPane()
		end
		if not self._scrollbarPrimed then
			self._scrollbarPrimed = true
			UpdateScrollbarThumb()
			UpdateRightScrollbarThumb()
		end
	end)

	local function SelectAddon(entry, force)
		if not entry then return end
		if not force and selected == entry.key and detailHost._body then
			return
		end
		OC._twoPaneSelected[pathKey] = entry.key
		if isAddonPorted then
			OC._addonListSelected = entry.key
		end
		selected = entry.key
		found = entry
		title:SetText(entry.label or entry.key)
		if right._setTitleIcon then
			right._setTitleIcon(entry.icon)
		end
		for _, btn in ipairs(buttons) do
			StyleAddonListButton(btn, btn.addonKey == entry.key)
		end
		local addonPath = {}
		for i = 1, #(path or {}) do
			addonPath[i] = path[i]
		end
		tinsert(addonPath, entry.key)
		local rw = right:GetWidth()
		if not rw or rw < 120 then
			rw = ResolveTwoPaneRightWidth(shell)
			right:SetWidth(rw)
		end
		local detailW = math.max(160, rw - scrollW - 16)
		detailHost:SetWidth(detailW)
		OC._twoPaneDetailScroll[pathKey] = 0
		self:RenderAddonDetail(detailHost, entry.opt, addonPath, entry.key)
		WireDetailMouseWheel(detailHost)
		WireDetailMouseWheel(detailHost._body)
		if detailHost._body and detailHost._body._contentFrame then
			WireDetailMouseWheel(detailHost._body._contentFrame)
			WireDetailMouseWheel(detailHost._body._contentFrame._inner)
		end
		SyncHeights()
	end

	local y = 0
	local lastGroup
	for _, entry in ipairs(entries) do
		if entry.listGroup and entry.listGroup ~= lastGroup then
			lastGroup = entry.listGroup
			if y > 0 then
				y = y + 6
			end
			local hdr = listChild:CreateFontString(nil, "OVERLAY", T.fonts.small)
			hdr:SetHeight(math.max(16, itemH - 4))
			hdr:SetPoint("TOPLEFT", listChild, "TOPLEFT", 6, -y)
			hdr:SetPoint("TOPRIGHT", listChild, "TOPRIGHT", -4, -y)
			hdr:SetJustifyH("LEFT")
			hdr:SetText(entry.listGroup)
			T:SetTextColor(hdr, "title")
			y = y + (itemH - 2)
		end
		local btn = CreateFrame("Button", nil, listChild)
		btn:SetHeight(itemH)
		btn:SetPoint("TOPLEFT", listChild, "TOPLEFT", 0, -y)
		btn:SetPoint("TOPRIGHT", listChild, "TOPRIGHT", 0, -y)

		local iconPad = 6
		if entry.icon then
			local icon = btn:CreateTexture(nil, "ARTWORK")
			local iconSize = math.max(12, itemH - 6)
			icon:SetSize(iconSize, iconSize)
			icon:SetPoint("LEFT", 4, 0)
			local tex = entry.icon
			if type(tex) == "number" then
				icon:SetTexture(tex)
			else
				icon:SetTexture(tostring(tex))
			end
			btn.icon = icon
			iconPad = 4 + iconSize + 4
		end

		local fs = btn:CreateFontString(nil, "OVERLAY", T.fonts.nav)
		fs:SetPoint("LEFT", iconPad, 0)
		fs:SetPoint("RIGHT", -4, 0)
		fs:SetJustifyH("LEFT")
		fs:SetText(entry.label or entry.key)
		btn.label = fs
		btn.addonKey = entry.key
		btn.entry = entry
		btn:RegisterForClicks("LeftButtonDown")
		StyleAddonListButton(btn, entry.key == selected)
		btn:SetScript("OnEnter", function(self)
			if self._active then return end
			T:ApplyFlat(self, T.colors.navHover, T.colors.borderSoft)
		end)
		btn:SetScript("OnLeave", function(self)
			StyleAddonListButton(self, self._active)
		end)
		btn:SetScript("OnClick", function(self)
			SelectAddon(self.entry, false)
		end)
		btn:EnableMouseWheel(true)
		btn:SetScript("OnMouseWheel", function(_, delta)
			ScrollAddonList(delta)
		end)
		tinsert(buttons, btn)
		y = y + itemH
	end
	listChild:SetHeight(math.max(1, y + 4))
	listContentH = y + 4

	SelectAddon(found, true)
end

function R:GetUnsupportedReport()
	local lines = {}
	for t, count in pairs(self.unsupportedTypes) do
		tinsert(lines, t .. " x" .. tostring(count))
	end
	sort(lines)
	return lines
end
