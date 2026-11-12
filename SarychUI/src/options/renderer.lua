-- SarychUI Options Renderer - AceConfig option tables -> custom widgets.
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
local CreateFrame = SarychUI.OptionsPool and SarychUI.OptionsPool.CreateFrame or CreateFrame
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

local function TTip(value)
	if SarychUI and SarychUI.TLines then
		return SarychUI:TLines(value)
	end
	if type(value) == "string" then
		return TUI(value)
	end
	return value
end

local function WrapTip(fn)
	if type(fn) ~= "function" then
		return fn
	end
	return function(...)
		return TTip(fn(...))
	end
end

local function MakeTooltip(opt, info)
	if type(opt.suiTooltip) == "function" then
		return WrapTip(opt.suiTooltip)
	end
	if type(opt.desc) == "function" then
		return function()
			return TTip(Safe(opt.desc, info))
		end
	end
	if type(opt.desc) == "string" and opt.desc ~= "" then
		local src = opt.desc
		return function()
			return TTip(src)
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
	SUI._componentStateRevision = (SUI._componentStateRevision or 0) + 1
	local core = SUI._activeOptionsCore or SUI.OptionsCore
	if core and core.OnSettingChanged then
		core:OnSettingChanged()
	end
end

local function CallGet(opt, info)
	local core = SUI._activeOptionsCore or SUI.OptionsCore

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
	if r == nil then r = 1 end
	if g == nil then g = 1 end
	if b == nil then b = 1 end
	if a == nil then a = 1 end
	return r, g, b, a
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
	local OW = SUI._activeOptionsWindow or SUI.OptionsWindow
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

-- Remeasure wrapped text, restack children top->bottom, return content bottom + count.
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

		-- Content-sized buttons share one row without stretching to column width.
		if child._suiFitText then
			local fitRow = {}
			fitRow._startX = padX
			fitRow._startY = y
			fitRow._gap = colGap
			local j = i
			while j <= #list and list[j].frame._suiFitText do
				local f = list[j].frame
				fitRow[#fitRow + 1] = f
				f._suiFitRow = fitRow
				f._suiHalf = nil
				f._suiThird = nil
				j = j + 1
			end
			if child.FitToText then child:FitToText() end
			local rowH = 0
			for k = 1, #fitRow do
				rowH = math.max(rowH, fitRow[k]:GetHeight() or 24)
			end
			y = y - rowH - gap
			count = count + (j - i)
			i = j
		else

		local nextItem = list[i + 1]
		local nextChild = nextItem and nextItem.frame
		local thirdItem = list[i + 2]
		local thirdChild = thirdItem and thirdItem.frame
		local trio = threeCol and child._suiThird and nextChild and nextChild._suiThird and thirdChild and thirdChild._suiThird
		local pair = (not trio) and twoCol and child._suiHalf and nextChild and nextChild._suiHalf
		local keptPair = child._suiKeepRow and nextChild and nextChild._suiKeepRow == child._suiKeepRow

		child:ClearAllPoints()
		if keptPair then
			local firstW = child._fixedWidth or halfW
			local secondW = nextChild._fixedWidth or halfW
            if nextChild._suiTrailingFit then
                secondW = math.max(24, math.ceil((nextChild.label:GetStringWidth() or 0) + 20))
                firstW = math.max(80, (parent:GetWidth() or 0) - padX * 2 - colGap - secondW)
                child._fixedWidth, nextChild._fixedWidth = firstW, secondW
            end
			child:SetWidth(firstW)
			nextChild:SetWidth(secondW)
			if child.MeasureHeight then child:MeasureHeight(firstW) end
			if nextChild.MeasureHeight then nextChild:MeasureHeight(secondW) end
			child:SetPoint("TOPLEFT", parent, "TOPLEFT", padX, y)
			nextChild:ClearAllPoints()
			nextChild:SetPoint("TOPLEFT", parent, "TOPLEFT", padX + firstW + colGap, y)
			y = y - math.max(child:GetHeight() or 0, nextChild:GetHeight() or 0) - gap
			count = count + 2
			i = i + 2
		elseif trio then
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
			elseif fixed and fixed > 0 then
				-- Keep the value box inside this column. Stretching a half-width
				-- slider to the panel's right edge hides it past the scroll clip.
				child:SetWidth(fixed)
				child:SetPoint("TOPLEFT", parent, "TOPLEFT", padX, y)
			else
				child:SetPoint("TOPLEFT", parent, "TOPLEFT", padX, y)
				child:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -padX, y)
				child:SetWidth(innerW)
			end
			local h = child:GetHeight() or 0
			y = y - h - gap
			count = count + 1
			i = i + 1
		end
		end -- _suiFitText else
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
	-- Descriptions wrap only after width is known - measure now so parents get real height.
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

	local decor = CreateFrame("Frame", nil, panel, nil, "renderer:1")
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
		local emptyLeft, emptyRight
		if self._suiDecorRightThird then
			-- Icon lives in the right third; content (2 cols) uses the left 2/3.
			local colGap = 10
			emptyLeft = pad + math.floor((pw - pad * 2) * 2 / 3) + colGap
			emptyRight = pw - pad
		else
			local leftW = (T and T.sizes and T.sizes.controlMaxW) or 320
			emptyLeft = pad + leftW + 12
			emptyRight = pw - pad
			if emptyRight - emptyLeft < 48 then
				emptyLeft = pw * 0.5
				emptyRight = pw - pad
			end
		end
		local emptyW = math.max(48, emptyRight - emptyLeft)
		local size = math.floor(math.min(emptyW, ph - pad * 2) * 0.62)
		size = math.max(48, math.min(size, self._suiDecorRightThird and 120 or 160))
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
			msg = opt.confirmText or SarychUI:T("ui.options_e8335efc2d")
		else
			msg = opt.confirmText or SarychUI:T("ui.options_e8335efc2d")
		end
	elseif c == true then
		msg = opt.confirmText or SarychUI:T("ui.options_e8335efc2d")
	elseif type(c) == "string" then
		msg = c
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
		text = SarychUI:T("ui.options_e8335efc2d"),
		button1 = ACCEPT or "OK",
		button2 = CANCEL or SarychUI:T("ui.options_0ec753be8d"),
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

-- Fade all four sides using native 3.3.5a one-axis texture gradients.
local function PaintFadedIllustration(host, path, width, height)
    local rows = 16
    local edgeX = width * 0.1875
    local centerW = width - edgeX * 2
    for row = 0, rows - 1 do
        local top, bottom = row / rows, (row + 1) / rows
        local fromTop = (row + 0.5) / 6
        local fromBottom = (rows - row - 0.5) / 6
        local alpha = 0.72 * math.min(1, fromTop, fromBottom)
        for segment = 1, 3 do
            local x = segment == 1 and 0 or (segment == 2 and edgeX or width - edgeX)
            local segmentW = segment == 2 and centerW or edgeX
            local tex = host:CreateTexture(nil, "ARTWORK")
            tex:SetSize(segmentW, height / rows)
            tex:SetPoint("TOPLEFT", host, "TOPLEFT", x, -row * height / rows)
            tex:SetTexture(path)
            tex:SetTexCoord(x / width, (x + segmentW) / width, top, bottom)
            if segment == 1 then
                tex:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 0, 1, 1, 1, alpha)
            elseif segment == 3 then
                tex:SetGradientAlpha("HORIZONTAL", 1, 1, 1, alpha, 1, 1, 1, 0)
            else
                tex:SetAlpha(alpha)
            end
        end
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
		end, opt.hasAlpha and true or false, MakeTooltip(opt, info), opt.suiPreviewKey)
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
		end, TUI(opt.suiPlaceholder or opt.placeholder), flagPathFn, opt.suiInlineLabel and true or false)
	elseif t == "input" then
		if opt.suiPairedInputLabel and W.PairedInputWithButton then
			local second = type(opt.suiPairedInputLabel) == "function"
				and Safe(opt.suiPairedInputLabel, info) or opt.suiPairedInputLabel
			widget = W:PairedInputWithButton(parent, name, TUI(second),
				function() return CallGet(opt, info) end,
				function(value) CallSet(opt, info, value) end)
		elseif opt.suiSaveButton and W.InputWithButton then
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
		if type(opt.suiExpandDetails) == "table" and W.ButtonPair then
			local expand = opt.suiExpandDetails
			widget = W:ButtonPair(
				parent,
				name,
				function()
					ApplyConfirm(opt, info, function() CallFunc(opt, info) end)
				end,
				MakeTooltip(opt, info),
				function() return ResolveName(opt, info) end,
				TUI(type(expand.name) == "function" and expand.name() or expand.name or ">"),
				function() if type(expand.func) == "function" then expand.func() end end,
				function() return TTip("ui.options_c05431ad5a") end,
				28,
				function() return TUI(type(expand.name) == "function" and expand.name() or expand.name or ">") end
			)
			compactW = nil
		elseif type(opt.suiResetDefaults) == "function" and W.ButtonPair then
			widget = W:ButtonPair(
				parent,
				name,
				function()
					ApplyConfirm(opt, info, function()
						CallFunc(opt, info)
					end)
				end,
				MakeTooltip(opt, info),
				function()
					return ResolveName(opt, info)
				end,
				TUI("ui.options_469631cb16"),
				function()
					Safe(opt.suiResetDefaults, info)
				end,
				function()
					return TTip("ui.options_4beb283d7e")
				end
			)
			compactW = nil
		else
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
				-- Stretch to content width (e.g. Быстрые настройки -> Применить).
				compactW = nil
			else
				widget:SetWidth(180)
				compactW = 180
			end
		end
	elseif t == "description" then
		if opt.suiStickyBottom and SUI.OptionsWindow and SUI.OptionsWindow.SetContentBottomNote then
			local text = name
			if text == "" and type(opt.name) == "function" then
				text = tostring(Safe(opt.name, info) or "")
				text = TUI(text)
			end
			if type(text) == "string" then
				text = text:gsub("^[%s\r\n]+", ""):gsub("[%s\r\n]+$", "")
			end
			SUI.OptionsWindow:SetContentBottomNote(text)
			return y
		elseif opt.suiRightIcon and W.DescriptionRightIcon then
			local function ResolveRightIcon()
				if type(opt.suiRightIcon) == "function" then
					return Safe(opt.suiRightIcon, info)
				end
				return opt.suiRightIcon
			end
			local function ResolveRightIcon2()
				if type(opt.suiRightIcon2) == "function" then
					return Safe(opt.suiRightIcon2, info)
				end
				return opt.suiRightIcon2
			end
			local function ResolveRightText()
				if type(opt.suiRightText) == "function" then
					return Safe(opt.suiRightText, info)
				end
				return opt.suiRightText
			end
			local rightButton
			if type(opt.suiRightButton) == "table" then
				local rb = opt.suiRightButton
				local btnTip
				if type(rb.desc) == "function" then
					btnTip = function() return TTip(Safe(rb.desc, info)) end
				elseif type(rb.desc) == "string" and rb.desc ~= "" then
					local src = rb.desc
					btnTip = function() return TTip(src) end
				end
				rightButton = {
					text = rb.name and TUI(tostring(rb.name)) or nil,
					tooltipFn = btnTip,
					onClick = function()
						if type(rb.func) == "function" then
							ApplyConfirm(rb, info, function()
								Safe(rb.func, info)
							end)
						end
					end,
				}
			end
			widget = W:DescriptionRightIcon(parent, name, ResolveRightIcon(), opt.suiRightIconSize, ResolveRightText(), ResolveRightIcon2(), rightButton)
			widget._suiValueWidget = true
			widget.Refresh = function(self)
				self:SetDynamicText(ResolveName(opt, info))
				self:SetDynamicIcon(ResolveRightIcon())
				if self.SetDynamicIcon2 then
					self:SetDynamicIcon2(ResolveRightIcon2())
				end
				self:SetDynamicRightText(ResolveRightText())
			end
			compactW = nil
		elseif SUI.OptionsPreviews:Resolve(opt) then
            widget = SUI.OptionsPreviews:Create(parent, opt)
            compactW = nil
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
				if opt.suiImageCorner == "BOTTOMRIGHT" or opt.suiImageCorner == "TOPRIGHT" then
					local OW = SUI._activeOptionsWindow or SUI.OptionsWindow
					if OW and OW.content then
						local image = OW._pageCornerImage
						if not image or image:GetParent() ~= OW.content or image._suiPath ~= opt.image then
							if image then image:Hide() end
							image = CreateFrame("Frame", nil, OW.content, nil, "renderer:2")
							OW._pageCornerImage = image
							image._suiPath = opt.image
							image:SetSize(iw, ih)
							PaintFadedIllustration(image, opt.image, iw, ih)
						end
						image:ClearAllPoints()
						if opt.suiImageCorner == "TOPRIGHT" then
							image:SetPoint("TOPRIGHT", OW.content, "TOPRIGHT", 16, 0)
						else
							image:SetPoint("BOTTOMRIGHT", OW.content, "BOTTOMRIGHT", -16, 16)
						end
						image:SetFrameLevel(OW.content:GetFrameLevel()
							+ ((opt.suiImageCorner == "TOPRIGHT" or opt.suiImageBackground) and 0 or 2))
						image:Show()
					end
					return y
				end
				local align = tostring(opt.imageAlign or "LEFT"):upper()
				local centerInContent = opt.imageCenterInContent and true or false
				local imgFrame = CreateFrame("Frame", nil, parent, nil, "renderer:3")
				local hostH = ih
				if centerInContent then
					local OW = SUI._activeOptionsWindow or SUI.OptionsWindow
					local viewportH = (OW and OW.contentScroll and OW.contentScroll:GetHeight()) or 0
					if viewportH > ih then
						hostH = viewportH
					end
				end
				imgFrame:SetHeight(hostH)
				local image = opt.suiFadedImage and CreateFrame("Frame", nil, imgFrame, nil, "renderer:4")
					or imgFrame:CreateTexture(nil, "ARTWORK")
				image:SetSize(iw, ih)
				if opt.suiFadedImage then
					PaintFadedIllustration(image, opt.image, iw, ih)
				else
					image:SetTexture(opt.image)
				end
				function imgFrame:SetDisabled(disabled)
					self:SetAlpha(disabled and 0.45 or 1)
				end
				BindDisabled(imgFrame, opt, info)
				if align == "CENTER" or centerInContent then
					local yOff = centerInContent and 56 or 0
					image:SetPoint("CENTER", imgFrame, "CENTER", 0, yOff)
				elseif align == "RIGHT" then
					image:SetPoint("RIGHT", imgFrame, "RIGHT", 0, 0)
				else
					image:SetPoint("LEFT", imgFrame, "LEFT", 0, 0)
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
				return TTip(Safe(opt.desc, info))
			end
		elseif type(opt.desc) == "string" and opt.desc ~= "" then
			local src = opt.desc
			tipFn = function()
				return TTip(src)
			end
		end
		widget = W:Header(parent, name, tipFn)
		BindDynamicName(widget, opt, info)
		compactW = nil
	elseif t == "group" then
		local childHandler = opt.handler or handler
		-- Inline groups render children; non-inline are usually nav sections.
		local isInline = opt.inline or opt.dialogInline or opt.guiInline
		-- Small independent settings panels arranged side by side.
		if isInline and opt.suiColumnGroups then
			local row = CreateFrame("Frame", nil, parent, nil, "renderer:5")
			local columns = {}
			local gap = 10
			row:SetWidth(math.max(100, (parent:GetWidth() or 400) - (padX or 0) * 2))
			for _, entry in ipairs(SortedKeys(opt.args)) do
				local childPath = {}
				for i = 1, #path do childPath[i] = path[i] end
				tinsert(childPath, entry.key)
				local childInfo = MakeInfo(childPath, entry.opt, childHandler)
				if not IsHidden(entry.opt, childInfo) then
					columns[#columns + 1] = {entry = entry, path = childPath}
				end
			end
			if #columns == 0 then row:Hide(); return y end
			local width = (row:GetWidth() - gap * (#columns - 1)) / #columns
			for i, column in ipairs(columns) do
				local frame = CreateFrame("Frame", nil, row, nil, "renderer:6")
				column.frame = frame
				frame:SetWidth(width)
				frame:SetPoint("TOPLEFT", row, "TOPLEFT", (i - 1) * (width + gap), 0)
				local bottom = self:RenderControl(frame, column.entry.key, column.entry.opt, column.path, 0, 0, childHandler)
				frame:SetHeight(math.max(1, -bottom))
			end
			local function LayoutColumns()
				if row._layoutLock then return end
				row._layoutLock = true
				local columnWidth = (row:GetWidth() - gap * (#columns - 1)) / #columns
				local height = 1
				for i, column in ipairs(columns) do
					local frame = column.frame
					frame:SetWidth(columnWidth)
					frame:ClearAllPoints()
					frame:SetPoint("TOPLEFT", row, "TOPLEFT", (i - 1) * (columnWidth + gap), 0)
					local bottom = RemeasureWrappedChildren(frame, 0)
					frame:SetHeight(math.max(1, bottom))
					height = math.max(height, frame:GetHeight())
				end
				row:SetHeight(height)
				row._layoutLock = nil
			end
			row:SetScript("OnSizeChanged", LayoutColumns)
			LayoutColumns()
			y = self:LayoutChild(parent, row, y, padX)
			LayoutColumns()
			return y
		end
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
					TUI(tostring(idOpt.suiSaveButton or SarychUI:T("ui.options_559a87f7cc"))),
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
			local decorSplit = opt.suiDecorRightHalf and opt.suiPanelDecorIcon and true or false

			local headerTipFn
			if showHeader then
				if type(opt.desc) == "function" then
					headerTipFn = function()
						return TTip(Safe(opt.desc, MakeInfo(path, opt, childHandler)))
					end
				elseif type(opt.desc) == "string" and opt.desc ~= "" then
					local src = opt.desc
					headerTipFn = function()
						return TTip(src)
					end
				end
				-- Decorated split: title goes inside the left checkbox panel, not above the outer frame.
				if not decorSplit then
					local header = W:Header(parent, name, headerTipFn, opt.suiHeaderIcon, opt.suiHelpIcon)
					local action = opt.suiHeaderAction
					if action and action.type == "execute" then
						local actionInfo = MakeInfo(path, action, childHandler)
						local button = W:Button(header, ResolveName(action, actionInfo), function()
							ApplyConfirm(action, actionInfo, function() CallFunc(action, actionInfo) end)
						end, nil, function() return ResolveName(action, actionInfo) end)
						button:SetWidth(math.max(60, button.label:GetStringWidth() + 20))
						if opt.suiHeaderActionAdjacent then
							button:SetPoint("LEFT", header.label, "RIGHT", 10, 0)
						else
							button:SetPoint("RIGHT", header, "RIGHT", 0, 0)
							header.label:SetPoint("RIGHT", button, "LEFT", -10, 0)
						end
						header:SetHeight(math.max(header:GetHeight(), button:GetHeight()))
						header.label:SetJustifyH("LEFT")
						BindDisabled(button, action, actionInfo)
					end
					y = self:LayoutChild(parent, header, y)
				end
			end

			-- Outer frame: decor icon on the left; title + checkbox panel on the right.
			if decorSplit then
				local pad = (T and T.sizes and T.sizes.panelPad) or 8
				local gap = (T and T.sizes and T.sizes.rowGap) or 4
				local colGap = 10
				local parentW = parent:GetWidth() or 400
				local outer = W:Panel(parent)
				outer:SetHeight(10)
				if parentW > 40 then
					outer:SetWidth(parentW)
				end

				local title
				local titleH = 0
				if showHeader then
					title = W:Header(outer, name, headerTipFn, opt.suiHeaderIcon, opt.suiHelpIcon)
					title._suiSkipRelayout = true
					titleH = title:GetHeight() or 22
				end

				local leftPanel = W:Panel(outer)
				leftPanel:SetPoint("TOPRIGHT", outer, "TOPRIGHT", -pad, -pad)

				local decorPath = opt.suiPanelDecorIcon
				if type(decorPath) == "function" then
					local ok, value = pcall(decorPath)
					decorPath = ok and value or nil
				end
				local decor = CreateFrame("Frame", nil, outer, nil, "renderer:7")
				decor._suiSkipRelayout = true
				local decorTex = decor:CreateTexture(nil, "ARTWORK")
				decorTex:SetAllPoints()
				if type(decorPath) == "string" then
					decorTex:SetTexture(decorPath)
				end
				outer._suiDecorIcon = decor
				outer._suiLeftPanel = leftPanel
				outer._suiDecorTitle = title

				local function LayoutSplit()
					local ow = outer:GetWidth() or parentW or 400
					local innerW = math.max(160, ow - pad * 2)
					local half = math.max(110, math.floor((innerW - colGap) / 2))
					local contentLeft = pad + half + colGap
					local titleTop = -pad
					if title then
						title:ClearAllPoints()
						title:SetWidth(half)
						title:SetPoint("TOPLEFT", outer, "TOPLEFT", contentLeft, titleTop)
						titleTop = titleTop - titleH - gap
					end
					leftPanel:ClearAllPoints()
					leftPanel:SetPoint("TOPLEFT", outer, "TOPLEFT", contentLeft, titleTop)
					leftPanel:SetPoint("BOTTOMRIGHT", outer, "BOTTOMRIGHT", -pad, pad)
					leftPanel:SetWidth(half)
					local sizeCap = tonumber(opt.suiPanelDecorIconSize) or 200
					local iconSize = math.max(96, math.min(math.floor(half * 0.85), sizeCap))
					decor:ClearAllPoints()
					decor:SetSize(iconSize, iconSize)
					-- Center in the left half, aligned to the checkbox panel.
					decor:SetPoint("CENTER", leftPanel, "LEFT", -(half * 0.5 + colGap), 0)
					decor:Show()
				end

				local innerY = -pad
				local pendingRow = {}
				local leftHalf = math.max(110, math.floor(((outer:GetWidth() or parentW) - pad * 2 - colGap) / 2))
				local leftInnerW = math.max(90, leftHalf - pad * 2)
				local colW = math.floor((leftInnerW - colGap) / 2)
				local rowCols = 2
				if colW < 72 then
					rowCols = 1
					colW = leftInnerW
				end

				local function FlushPendingRow()
					local n = #pendingRow
					if n == 0 then return end
					local rowH = 0
					local cols = math.min(n, rowCols)
					for col = 1, cols do
						local widget = pendingRow[col]
						local x = pad + (col - 1) * (colW + colGap)
						widget._fixedWidth = colW
						widget:ClearAllPoints()
						widget:SetWidth(colW)
						widget:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", x, innerY)
						rowH = math.max(rowH, widget:GetHeight() or 22)
					end
					innerY = innerY - rowH - gap
					wipe(pendingRow)
				end

				local function BuildSplitWidget(eOpt, eInfo, eName)
					local tipFn
					if type(eOpt.desc) == "function" then
						tipFn = function() return TTip(Safe(eOpt.desc, eInfo)) end
					elseif type(eOpt.desc) == "string" and eOpt.desc ~= "" then
						local src = eOpt.desc
						tipFn = function() return TTip(src) end
					end
					local widget
					if eOpt.type == "toggle" then
						widget = W:Checkbox(leftPanel, eName, function()
							return CallGet(eOpt, eInfo)
						end, function(value)
							CallSet(eOpt, eInfo, value)
						end, tipFn, eOpt.suiHelpIcon, eOpt.suiPreviewKey)
					elseif eOpt.type == "execute" then
						widget = W:Button(leftPanel, eName, function()
							ApplyConfirm(eOpt, eInfo, function()
								CallFunc(eOpt, eInfo)
							end)
						end, tipFn, function()
							return ResolveName(eOpt, eInfo)
						end)
					end
					if widget then
						BindDisabled(widget, eOpt, eInfo)
					end
					return widget
				end

				for _, entry in ipairs(sorted) do
					local childPath = {}
					for i = 1, #path do childPath[i] = path[i] end
					tinsert(childPath, entry.key)
					local eOpt = entry.opt
					local eInfo = MakeInfo(childPath, eOpt, childHandler)
					if not IsHidden(eOpt, eInfo) then
						if eOpt.type == "toggle" and rowCols > 1 and not eOpt.suiFullRow then
							local widget = BuildSplitWidget(eOpt, eInfo, ResolveName(eOpt, eInfo))
							if widget then
								tinsert(pendingRow, widget)
								if #pendingRow >= rowCols then
									FlushPendingRow()
								end
							end
						else
							FlushPendingRow()
							local widget = BuildSplitWidget(eOpt, eInfo, ResolveName(eOpt, eInfo))
							if widget then
								local spanW = leftInnerW
								widget._fixedWidth = spanW
								widget:ClearAllPoints()
								widget:SetWidth(spanW)
								widget:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", pad, innerY)
								innerY = innerY - (widget:GetHeight() or 24) - gap
							end
						end
					end
				end
				FlushPendingRow()

				local leftH = math.max(pad * 2, -innerY - gap + pad)
				leftPanel:SetHeight(leftH)
				local titleBlock = (title and (titleH + gap) or 0)
				outer:SetHeight(leftH + titleBlock + pad * 2)
				outer._relayoutInline = function(self)
					if self._relayoutLock then return end
					self._relayoutLock = true
					LayoutSplit()
					self._relayoutLock = nil
				end
				outer:SetScript("OnSizeChanged", function(self)
					self:_relayoutInline()
				end)
				y = self:LayoutChild(parent, outer, y, padX)
				LayoutSplit()
				return y
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
			local contentW = panelInnerW
			local halfW = math.floor((contentW - colGap) / 2)
			local thirdW = math.floor((panelInnerW - colGap * 2) / 3)
			local canThreeCol = panel._suiThreeCol and thirdW >= 90
			local canTwoCol = (not canThreeCol) and panel._suiTwoCol and halfW >= 100
			local rowCols = opt.suiFitButtonRow or (canThreeCol and 3 or (canTwoCol and 2 or 1))
			local colW = canThreeCol and thirdW or halfW
			panel._suiContentW = contentW

			local function FlushPendingRow()
				local n = #pendingRow
				if n == 0 then return end
				local allFit = true
				for col = 1, n do
					if not pendingRow[col]._suiFitText then
						allFit = false
						break
					end
				end
                if n == 2 and pendingRow[2]._suiTrailingFit then
                    local slider, button = pendingRow[1], pendingRow[2]
                    local buttonW = math.max(24, math.ceil((button.label:GetStringWidth() or 0) + 20))
                    local sliderW = math.max(80, contentW - colGap - buttonW)
                    local keepRow = {}
                    for col, widget in ipairs(pendingRow) do
                        local width = col == 1 and sliderW or buttonW
                        widget._suiKeepRow = keepRow
                        widget._suiHalf, widget._suiThird = nil, nil
                        widget._fixedWidth = width
                        widget:SetWidth(width)
                        widget:ClearAllPoints()
                        widget:SetPoint("TOPLEFT", panel, "TOPLEFT", pad + (col == 2 and sliderW + colGap or 0), innerY)
                    end
                    innerY = innerY - math.max(slider:GetHeight() or 34, button:GetHeight() or 24) - gap
                    rendered = rendered + 2
                elseif allFit then
					local fitRow = {}
					fitRow._startX = pad
					fitRow._startY = innerY
					fitRow._gap = colGap
					for col = 1, n do
						local widget = pendingRow[col]
						fitRow[col] = widget
						widget._suiFitRow = fitRow
						widget._suiHalf = nil
						widget._suiThird = nil
					end
					if pendingRow[1].FitToText then
						pendingRow[1]:FitToText()
					end
					local rowH = 0
					for col = 1, n do
						rowH = math.max(rowH, pendingRow[col]:GetHeight() or 24)
					end
					innerY = innerY - rowH - gap
					rendered = rendered + n
				elseif n >= rowCols and rowCols > 1 then
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
					-- Partial last row: keep column width so the icon third stays free.
					local rowH = 0
					local keepRow = (n > 1 and rowCols > 1) and {} or nil
					for col = 1, n do
						local widget = pendingRow[col]
						widget._suiKeepRow = keepRow
						local ratioTotal = n == 2 and pendingRow[1]._suiWidthRatio and pendingRow[2]._suiWidthRatio
							and (pendingRow[1]._suiWidthRatio + pendingRow[2]._suiWidthRatio)
						local x = ratioTotal and (pad + (col == 2 and (contentW - colGap) * pendingRow[1]._suiWidthRatio / ratioTotal + colGap or 0))
							or (pad + (col - 1) * (colW + colGap))
						local w = ratioTotal and ((contentW - colGap) * widget._suiWidthRatio / ratioTotal)
							or ((rowCols > 1) and colW or nil)
						widget._suiHalf = nil
						widget._suiThird = nil
						if w then
							widget._fixedWidth = w
							widget:ClearAllPoints()
							widget:SetWidth(w)
							widget:SetPoint("TOPLEFT", panel, "TOPLEFT", x, innerY)
							rowH = math.max(rowH, widget:GetHeight() or 24)
						else
							widget._fixedWidth = nil
							innerY = self:LayoutChild(panel, widget, innerY, pad)
							rowH = 0
						end
						rendered = rendered + 1
					end
					if rowH > 0 then
						innerY = innerY - rowH - gap
					end
				end
				wipe(pendingRow)
			end

			local function BuildInlineWidget(eOpt, eInfo, eName)
				local tipFn
				if type(eOpt.suiTooltip) == "function" then
					tipFn = WrapTip(eOpt.suiTooltip)
				elseif type(eOpt.desc) == "function" then
					tipFn = function() return TTip(Safe(eOpt.desc, eInfo)) end
				elseif type(eOpt.desc) == "string" and eOpt.desc ~= "" then
					local src = eOpt.desc
					tipFn = function() return TTip(src) end
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
					end, eOpt.suiPlaceholder or eOpt.placeholder, eFlagPathFn, eOpt.suiInlineLabel and true or false)
				elseif eOpt.type == "input" then
					if eOpt.suiPairedInputLabel and W.PairedInputWithButton then
						local second = type(eOpt.suiPairedInputLabel) == "function"
							and Safe(eOpt.suiPairedInputLabel, eInfo) or eOpt.suiPairedInputLabel
						widget = W:PairedInputWithButton(panel, eName, TUI(second),
							function() return CallGet(eOpt, eInfo) end,
							function(value) CallSet(eOpt, eInfo, value) end)
					elseif eOpt.suiSaveButton and W.InputWithButton then
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
				elseif eOpt.type == "execute" then
					widget = W:Button(panel, eName, function()
						ApplyConfirm(eOpt, eInfo, function()
							CallFunc(eOpt, eInfo)
						end)
					end, tipFn, function()
						return ResolveName(eOpt, eInfo)
					end)
					if eOpt.suiFitText and widget then
						widget._suiFitText = true
						local function MeasureFitWidth(btn)
							local tw = 0
							if btn.label and btn.label.GetStringWidth then
								tw = btn.label:GetStringWidth() or 0
							end
							return math.max(24, math.ceil(tw + 20))
						end
						widget.FitToText = function(self)
							local w = MeasureFitWidth(self)
							self:SetWidth(w)
							self._fixedWidth = w
							local row = self._suiFitRow
							if not row or self._suiFitRelayouting then return end
							self._suiFitRelayouting = true
							local parent = self:GetParent()
							local x = row._startX or 0
							local y = row._startY
							if y == nil then
								local _, _, _, _, fy = self:GetPoint(1)
								y = fy or 0
							end
							local gap = row._gap or 10
							for i = 1, #row do
								local f = row[i]
								local fw = MeasureFitWidth(f)
								f:SetWidth(fw)
								f._fixedWidth = fw
								f:ClearAllPoints()
								f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
								x = x + fw + gap
							end
							self._suiFitRelayouting = nil
						end
						local oldRefresh = widget.Refresh
						widget.Refresh = function(self)
							if oldRefresh then oldRefresh(self) end
							self:FitToText()
						end
						widget:FitToText()
					end
				elseif eOpt.type == "toggle" then
					widget = W:Checkbox(panel, eName, function()
						return CallGet(eOpt, eInfo)
					end, function(value)
						CallSet(eOpt, eInfo, value)
					end, tipFn, eOpt.suiHelpIcon, eOpt.suiPreviewKey)
					if widget and eOpt.suiRowHeight then
						widget:SetHeight(eOpt.suiRowHeight)
					end
				end
				if widget then
					widget._suiExternalSyncKey = eOpt.suiExternalSyncKey
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
						buttonTooltipFn = function() return TTip(Safe(buttonOpt.desc, buttonInfo)) end
					elseif type(buttonOpt.desc) == "string" and buttonOpt.desc ~= "" then
						local src = buttonOpt.desc
						buttonTooltipFn = function() return TTip(src) end
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

			if opt.suiSelectWithColor and W.SelectWithColor then
				local selectOpt = opt.args and (opt.args.mode or opt.args.select or opt.args.choose)
				local colorOpt = opt.args and (opt.args.color or opt.args.nameBackgroundColor)
				if selectOpt and colorOpt then
					local selectPath, colorPath = {}, {}
					for i = 1, #path do
						selectPath[i] = path[i]
						colorPath[i] = path[i]
					end
					for k, v in pairs(opt.args) do
						if v == selectOpt then tinsert(selectPath, k) end
						if v == colorOpt then tinsert(colorPath, k) end
					end
					local selectInfo = MakeInfo(selectPath, selectOpt, childHandler)
					local colorInfo = MakeInfo(colorPath, colorOpt, childHandler)
					local colorTooltipFn
					if type(colorOpt.desc) == "function" then
						colorTooltipFn = function() return TTip(Safe(colorOpt.desc, colorInfo)) end
					elseif type(colorOpt.desc) == "string" and colorOpt.desc ~= "" then
						local src = colorOpt.desc
						colorTooltipFn = function() return TTip(src) end
					end
					local skip = {}
					for k, v in pairs(opt.args) do
						if v == selectOpt or v == colorOpt then
							skip[k] = true
						end
					end
					local selectOrder = tonumber(selectOpt.order) or 0
					local beforeSelect, afterSelect = {}, {}
					for _, entry in ipairs(sorted) do
						if not skip[entry.key] then
							if (tonumber(entry.opt.order) or 0) < selectOrder then
								tinsert(beforeSelect, entry)
							else
								tinsert(afterSelect, entry)
							end
						end
					end
					local function RenderInlineEntries(list)
						for _, entry in ipairs(list) do
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
					RenderInlineEntries(beforeSelect)
					if not IsHidden(selectOpt, selectInfo) then
						local rowWidget = W:SelectWithColor(
							panel,
							ResolveName(selectOpt, selectInfo),
							function() return ResolveValues(selectOpt, selectInfo) end,
							function() return CallGet(selectOpt, selectInfo) end,
							function(value) CallSet(selectOpt, selectInfo, value) end,
							function() return CallGetColor(colorOpt, colorInfo) end,
							function(r, g, b, a) CallSetColor(colorOpt, colorInfo, r, g, b, a) end,
							colorOpt.hasAlpha and true or false,
							colorTooltipFn,
							function()
								return IsHidden(colorOpt, colorInfo)
							end,
							colorOpt.suiPreviewKey,
							selectOpt.suiPreviewKey
						)
						BindDisabled(rowWidget, selectOpt, selectInfo)
						innerY = self:LayoutChild(panel, rowWidget, innerY, pad)
						rendered = rendered + 1
					end
					RenderInlineEntries(afterSelect)
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
				-- Fit-text executes pack on one content-sized row even without Two/ThreeCol.
				local packable = eOpt and not eOpt.suiFullRow and not eOpt.suiSpanTwoCols
					and (eOpt.type == "range" or eOpt.type == "select" or eOpt.type == "input"
						or eOpt.type == "execute" or eOpt.type == "toggle")
					and (rowCols > 1 or eOpt.suiFitText)
				if packable then
					local eInfo = MakeInfo(childPath, eOpt, childHandler)
					if not IsHidden(eOpt, eInfo) then
						if #pendingRow > 0 then
							local pendingFit = pendingRow[1]._suiFitText and true or false
							local nextFit = eOpt.suiFitText and true or false
							if pendingFit ~= nextFit then
								FlushPendingRow()
							end
						end
						local widget = BuildInlineWidget(eOpt, eInfo, ResolveName(eOpt, eInfo))
						if widget then
                            widget._suiTrailingFit = eOpt.suiTrailingFit and eOpt.type == "execute" or nil
							widget._suiWidthRatio = eOpt.suiWidthRatio
							tinsert(pendingRow, widget)
							if eOpt.suiRowBreakAfter then
								FlushPendingRow()
							elseif widget._suiFitText then
								-- Keep collecting; flush at end or when type switches.
							elseif #pendingRow >= rowCols then
								FlushPendingRow()
							end
						end
					end
				elseif eOpt and eOpt.suiSpanTwoCols then
					-- Full-row control limited to the two content columns (left 2/3).
					FlushPendingRow()
					local eInfo = MakeInfo(childPath, eOpt, childHandler)
					if not IsHidden(eOpt, eInfo) then
						local widget = BuildInlineWidget(eOpt, eInfo, ResolveName(eOpt, eInfo))
						if not widget then
							local before = innerY
							innerY = self:RenderControl(panel, entry.key, entry.opt, childPath, innerY, pad, childHandler)
							if innerY ~= before then
								rendered = rendered + 1
							end
						else
							local spanW = contentW
							widget._fixedWidth = spanW
							widget:ClearAllPoints()
							widget:SetWidth(spanW)
							widget:SetPoint("TOPLEFT", panel, "TOPLEFT", pad, innerY)
							innerY = innerY - (widget:GetHeight() or 24) - gap
							rendered = rendered + 1
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
					h = math.max(tonumber(opt.suiMinHeight) or 0, pad * 2, bottom + pad)
				else
					h = math.max(tonumber(opt.suiMinHeight) or 0, pad * 2)
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
				panel:SetHeight(math.max(tonumber(opt.suiMinHeight) or 0, pad * 2, -innerY - gap + pad))
			else
				panel:SetHeight(math.max(tonumber(opt.suiMinHeight) or 0, pad * 2))
			end

			-- Decorative icon centered in the empty right half/third (e.g. Profiles / Transfer).
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
		local host = CreateFrame("Frame", nil, parent, nil, "renderer:8")
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
		widget._suiExternalSyncKey = opt.suiExternalSyncKey
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

	local contentPad = (T and T.sizes and T.sizes.contentPad) or 4
	local y = -contentPad
	local sectionHandler = sectionOpt and sectionOpt.handler
	if not sectionOpt then
		local d = W:Description(parent, TUI("ui.options_371c933b13"))
		self:LayoutChild(parent, d, y, contentPad)
		parent:SetHeight(40)
		return
	end
	if sectionOpt.suiPageBackground then
		local window = SUI.OptionsWindow
		local anchor = window and window.tabBar
		if anchor then
			local art = window._pageBackgroundArt
			if not art then
				art = CreateFrame("Frame", nil, window.root, nil, "renderer:9")
				window._pageBackgroundArt = art
				art:SetSize(256, 128)
				PaintFadedIllustration(art, sectionOpt.suiPageBackground, 256, 128)
			end
			art:ClearAllPoints()
			art:SetPoint("TOP", anchor, "TOP", 0, 0)
			art:SetFrameLevel(math.max(0, anchor:GetFrameLevel() - 1))
			art:Show()
		end
		y = y - 96
	end
	if sectionOpt.suiGroupFramesSettings then
		local args = sectionOpt.args or {}
		local function ChildPath(key)
			local result = {}
			for i = 1, #(path or {}) do result[i] = path[i] end
			tinsert(result, key)
			return result
		end
		local totalW = math.max(420, (parent:GetWidth() or ResolveContentWidth()) - contentPad * 2)
		local gap = 10
		local mainOpt = args.mainBlock
		if mainOpt then
			local header = W:Header(parent, ResolveName(mainOpt, MakeInfo(ChildPath("mainBlock"), mainOpt, sectionHandler)))
			header:SetWidth(totalW)
			local toggleOpt = mainOpt.args and mainOpt.args.raidStyleParty
			if toggleOpt then
				local togglePath = ChildPath("mainBlock")
				tinsert(togglePath, "raidStyleParty")
				local toggleInfo = MakeInfo(togglePath, toggleOpt, sectionHandler)
				local toggle = W:Checkbox(header, ResolveName(toggleOpt, toggleInfo),
					function() return CallGet(toggleOpt, toggleInfo) end,
					function(value) CallSet(toggleOpt, toggleInfo, value) end,
					MakeTooltip(toggleOpt, toggleInfo))
				local labelWidth = toggle.label and toggle.label:GetStringWidth() or 190
				toggle:SetWidth(math.ceil(labelWidth + 26))
				toggle:SetPoint("RIGHT", header, "RIGHT", 0, 0)
				BindDisabled(toggle, toggleOpt, toggleInfo)
			end
			y = self:LayoutChild(parent, header, y, contentPad)
			local untitled = {}
			for key, value in pairs(mainOpt) do untitled[key] = value end
			untitled.name = ""
			if toggleOpt then
				untitled.args = {}
				for key, value in pairs(mainOpt.args) do
					if key ~= "raidStyleParty" then untitled.args[key] = value end
				end
			end
			mainOpt = untitled
		end
		local row = CreateFrame("Frame", nil, parent, nil, "renderer:10")
		row:SetWidth(totalW)
		local left = CreateFrame("Frame", nil, row, nil, "renderer:11")
		local right = CreateFrame("Frame", nil, row, nil, "renderer:12")
		local leftW = math.floor((totalW - gap) * 2 / 3)
		left:SetWidth(leftW)
		right:SetWidth(totalW - gap - leftW)
		left:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
		right:SetPoint("TOPLEFT", left, "TOPRIGHT", gap, 0)
		local leftY = self:RenderControl(left, "mainBlock", mainOpt,
			ChildPath("mainBlock"), 0, 0, sectionHandler)
		local rightY = self:RenderControl(right, "autoBlock", args.autoBlock,
			ChildPath("autoBlock"), 0, 0, sectionHandler)
		rightY = self:RenderControl(right, "resetPosition", args.resetPosition,
			ChildPath("resetPosition"), rightY, 0, sectionHandler)
		left:SetHeight(math.max(1, -leftY))
		right:SetHeight(math.max(1, -rightY))
		row:SetHeight(math.max(left:GetHeight(), right:GetHeight()))
		y = self:LayoutChild(parent, row, y, contentPad)
        if args.cooldowns then
            y = self:RenderControl(parent, "cooldowns", args.cooldowns,
                ChildPath("cooldowns"), y, contentPad, sectionHandler)
        end
        if args.auraBlacklist then
            y = self:RenderControl(parent, "auraBlacklist", args.auraBlacklist,
                ChildPath("auraBlacklist"), y, contentPad, sectionHandler)
        end
        if args.castbars then
            y = self:RenderControl(parent, "castbars", args.castbars,
                ChildPath("castbars"), y, contentPad, sectionHandler)
        end
		local bottom = RemeasureWrappedChildren(parent, contentPad)
		parent:SetHeight(math.max(contentPad * 2, bottom + contentPad))
		return
	end
	if sectionOpt.suiArenaSettingsSplit and sectionOpt.args then
		local args = sectionOpt.args
		local display = args.displayBox and args.displayBox.args or {}
		local moved = { castBarPos = true, showSpecText = true, showPets = true,
			diminishingDisplay = true, rightPrimary = true, additionalInfo = true }
		local function ChildPath(...)
			local result = {}
			for i = 1, #(path or {}) do result[i] = path[i] end
			for i = 1, select("#", ...) do tinsert(result, select(i, ...)) end
			return result
		end
		local split = CreateFrame("Frame", nil, parent, nil, "renderer:13")
		local parentW = parent:GetWidth()
		local splitW = math.max(300, (parentW and parentW > 300 and parentW or ResolveContentWidth()) - contentPad * 2)
		local columnGap = 10
		local leftW = math.floor((splitW - columnGap) / 3)
		local rightW = splitW - leftW - columnGap
		split:SetWidth(splitW)
		local left = CreateFrame("Frame", nil, split, nil, "renderer:14")
		left:SetWidth(leftW)
		local right = CreateFrame("Frame", nil, split, nil, "renderer:15")
		right:SetWidth(rightW)
		right:SetPoint("TOPLEFT", split, "TOPLEFT", 0, 0)
		left:SetPoint("TOPLEFT", right, "TOPRIGHT", columnGap, 0)
		local preview = SUI.ArenaPreview and SUI.ArenaPreview.Create and SUI.ArenaPreview:Create(right)
		if preview then
			preview:SetWidth(rightW)
			preview:SetPoint("TOPLEFT", right, "TOPLEFT", 0, 0)
		end
		right:SetHeight(preview and preview:GetHeight() or 0)

		local leftDisplay = {}
		for key, value in pairs(args.trinketsBox or {}) do leftDisplay[key] = value end
		leftDisplay.suiMinHeight = math.max(0, (right:GetHeight() or 0) - 22
			- ((T and T.sizes and T.sizes.rowGap) or 4))
		leftDisplay.args = {}
		for key, value in pairs(args.trinketsBox and args.trinketsBox.args or {}) do
			leftDisplay.args[key] = value
		end
		for key, order in pairs({ showPets = 2.5, showSpecText = 4, castBarPos = 6,
			diminishingDisplay = 7, rightPrimary = 8, additionalInfo = 9 }) do
			if display[key] then
				local option = {}
				for optionKey, optionValue in pairs(display[key]) do option[optionKey] = optionValue end
				option.order = order
				leftDisplay.args[key] = option
			end
		end
		local leftY = self:RenderControl(left, "trinketsBox", leftDisplay,
			ChildPath("trinketsBox"), 0, 0, sectionHandler)
		local rowGap = (T and T.sizes and T.sizes.rowGap) or 4
		local alignedHeight = math.max(preview and preview:GetHeight() or 0, -leftY - rowGap)
		left:SetHeight(alignedHeight)
		if preview then preview:SetHeight(alignedHeight) end
		right:SetHeight(alignedHeight)
		split:SetHeight(math.max(left:GetHeight() or 0, right:GetHeight() or 0))
		y = self:LayoutChild(parent, split, y, contentPad)

		if args.procTrinketsBlock then
			y = self:RenderControl(parent, "procTrinketsBlock", args.procTrinketsBlock,
				ChildPath("procTrinketsBlock"), y, contentPad, sectionHandler)
		end
		if args.appearanceToggles then
			y = self:RenderControl(parent, "appearanceToggles", args.appearanceToggles,
				ChildPath("appearanceToggles"), y, contentPad, sectionHandler)
		end

		local remainingDisplay = {}
		for key, value in pairs(args.displayBox or {}) do remainingDisplay[key] = value end
		remainingDisplay.name = SarychUI:T("ui.appearance_c407960b")
		remainingDisplay.suiTwoCol = true
		remainingDisplay.args = {}
		for key, value in pairs(display) do
			if not moved[key] then
				if key == "castBarHeight" or key == "castBarHeightLeft" or key == "castTextSize" then
					remainingDisplay.args[key] = value
				else
					local fullRow = {}
					for optionKey, optionValue in pairs(value) do fullRow[optionKey] = optionValue end
					fullRow.suiFullRow = true
					remainingDisplay.args[key] = fullRow
				end
			end
		end
		y = self:RenderControl(parent, "displayBox", remainingDisplay,
			ChildPath("displayBox"), y, contentPad, sectionHandler)
		for _, entry in ipairs(SortedKeys(args)) do
			if entry.key ~= "arenaPreview" and entry.key ~= "displayBox"
				and entry.key ~= "trinketsBox" and entry.key ~= "appearanceToggles"
				and entry.key ~= "procTrinketsBlock" then
				y = self:RenderControl(parent, entry.key, entry.opt,
					ChildPath(entry.key), y, contentPad, sectionHandler)
			end
		end
		local bottom = RemeasureWrappedChildren(parent, contentPad)
		parent:SetHeight(math.max(contentPad * 2, bottom + contentPad))
		return
	end
	-- When rendering a tabbed section's body, skip nested non-inline groups
	-- (they are shown as tabs). Render only leaf controls + inline groups.
	local sorted = SortedKeys(sectionOpt.args)
    local sectionParent
    local needsBlock = #sorted > 0
    for _, entry in ipairs(sorted) do
        local option = entry.opt
        if option.type == "group" or option.image or SUI.OptionsPreviews:Resolve(option) then
            needsBlock = false
            break
        end
    end
    if needsBlock then
        sectionParent = parent
        parent = W:Panel(sectionParent)
        parent:SetPoint("TOPLEFT", sectionParent, "TOPLEFT", contentPad, -contentPad)
        parent:SetPoint("TOPRIGHT", sectionParent, "TOPRIGHT", -contentPad, -contentPad)
        contentPad = parent._contentPad
        y = -contentPad
    end
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
		local d = W:Description(parent, ResolveName(sectionOpt) ~= "" and ResolveName(sectionOpt) or TUI("ui.options_9311f01f9f"))
		y = self:LayoutChild(parent, d, y, contentPad)
	else
		for _, entry in ipairs(sorted) do
			local opt = entry.opt
			-- Skip non-inline groups when parent is shown via tabs/subtabs or tree nav.
			local optInline = opt.inline or opt.dialogInline or opt.guiInline
			if opt.type == "group" and not optInline and (hasContentTabs or skipTreeChildren) then
				-- skip - rendered as tab/subtab content or left-nav section
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
    if sectionParent then
        sectionParent:SetHeight(parent:GetHeight() + 2 * ((T.sizes and T.sizes.contentPad) or 4))
    end

end

-----------------------------------------------------------------------
-- Two-pane lists: left names / right settings (Аддоны -> Список, Миникарта -> Кнопки).
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
			if k == "ElvUI_NamePlates" or k == "SarychUI_Bags" then
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
				-- Shared controls above the two-pane (headers, toggles, buttons...).
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
		T:SetTextColor(btn.label, btn._componentDisabled and "disabled" or "title")
	else
		btn:SetBackdrop(nil)
		T:SetTextColor(btn.label, btn._componentDisabled and "disabled" or "text")
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
	W:CloseOpenDropdown({ fromClearContent = true })
	-- Return the previous detail subtree before acquiring its replacement.
	local old = detailHost._body
	if old then
		old:Hide()
		old:SetParent(nil); if SarychUI.OptionsPool then SarychUI.OptionsPool:Release(old) end
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
	local scrollW = T.sizes.scrollbarW
	local hostW = math.max(160, rightW - scrollW - T.sizes.scrollbarGap - T.sizes.pageInset * 2)
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
		if enableHost._extra then
			enableHost._extra:Hide()
			enableHost._extra:SetParent(nil); if SarychUI.OptionsPool then SarychUI.OptionsPool:Release(enableHost._extra) end
			enableHost._extra = nil
		end
		local oldEnable = enableHost._widget
		if oldEnable then
			oldEnable:Hide()
			oldEnable:SetParent(nil); if SarychUI.OptionsPool then SarychUI.OptionsPool:Release(oldEnable) end
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
				tooltipFn = WrapTip(enableOpt.suiTooltip)
			elseif type(enableOpt.desc) == "function" then
				tooltipFn = function()
					return TTip(Safe(enableOpt.desc, enableInfo))
				end
			elseif type(enableOpt.desc) == "string" and enableOpt.desc ~= "" then
				local src = enableOpt.desc
				tooltipFn = function()
					return TTip(src)
				end
			end
			local widget = W:Checkbox(enableHost, enableName or TUI("ui.enable_a54eaf37"), function()
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
	local titleExtraShown = false
	local titleToggleWidth = enableHost and enableHost:GetWidth()
	local function RefreshTitleExtra(extra)
		if not (enableHost and enableHost._widget) then return end
		if enableHost._extra then
			enableHost._extra:Hide()
			enableHost._extra:SetParent(nil); if SarychUI.OptionsPool then SarychUI.OptionsPool:Release(enableHost._extra) end
			enableHost._extra = nil
		end
		titleExtraShown = false
		local toggle = enableHost._widget
		toggle:ClearAllPoints()
		toggle:SetWidth(titleToggleWidth)
		toggle:SetPoint("RIGHT", enableHost, "RIGHT", 0, 0)
		enableHost:SetWidth(titleToggleWidth)
		if type(extra) == "table" and extra.type == "execute" then
			local extraInfo = MakeInfo(addonPath, extra, addonOpt.handler)
			if not IsHidden(extra, extraInfo) then
				local button
				button = W:Button(enableHost, ResolveName(extra, extraInfo), function()
					ApplyConfirm(extra, extraInfo, function() CallFunc(extra, extraInfo) end)
					if button.Refresh then button:Refresh() end
				end, MakeTooltip(extra, extraInfo), function() return ResolveName(extra, extraInfo) end)
				button:SetWidth(110)
				button:SetPoint("LEFT", enableHost, "LEFT", 0, 0)
				BindDisabled(button, extra, extraInfo)
				enableHost:SetWidth(titleToggleWidth + 118)
				enableHost._extra = button
				titleExtraShown = true
			end
		end
		RefreshTitleLayout()
	end
	RefreshTitleExtra(addonOpt and addonOpt.suiTabBarExtra)
	-- Shallow copy args without controls moved into the title row.
	local bodyOpt = addonOpt
	if enableHost and enableHost._widget then
		bodyOpt = {}
		for k, v in pairs(addonOpt) do
			bodyOpt[k] = v
		end
		bodyOpt.args = {}
		for k, v in pairs(addonOpt.args) do
			if not (k == "enabled" and enableHost and enableHost._widget) then
				bodyOpt.args[k] = v
			end
		end
	end

	local body = CreateFrame("Frame", nil, detailHost, nil, "renderer:16")
	body:SetPoint("TOPLEFT", 0, 0)
	body:SetPoint("TOPRIGHT", 0, 0)
	body:SetWidth(hostW)
	local bodyDisabled = type(bodyOpt.suiBodyDisabled) == "function" and bodyOpt.suiBodyDisabled()
	local titleOnly = bodyOpt.args and not next(bodyOpt.args)
	if titleLabel then
		titleLabel:SetAlpha(titleOnly and bodyDisabled and 0.45 or 1)
	end
	if bodyDisabled then body:SetAlpha(0.45) end
	detailHost._body = body

	local function RefreshDetailHeights()
		if not body or not body:IsShown() then return end
		if body._heightLock then return end
		body._heightLock = true
		-- Re-sync widths if right pane finally got a real size after first paint.
		-- The scroll frame clips its child, so a host wider than the viewport
		-- hides the numeric boxes anchored to the right edge of each slider.
		local r = right
		local scroll = detailHost:GetParent()
		local viewW = scroll and scroll.GetWidth and scroll:GetWidth()
		local liveW = r and r:GetWidth()
		local nextHostW
		if viewW and viewW > 80 then
			nextHostW = viewW
		elseif liveW and liveW > 120 then
			local sw = T.sizes.scrollbarW
			nextHostW = math.max(160, liveW - sw - T.sizes.scrollbarGap - T.sizes.pageInset * 2)
		end
		if nextHostW and math.abs((detailHost:GetWidth() or 0) - nextHostW) > 1 then
			detailHost:SetWidth(nextHostW)
			body:SetWidth(nextHostW)
			hostW = nextHostW
			local function ReleaseWide(frame)
				if not frame or not frame.GetChildren then return end
				local kids = { frame:GetChildren() }
				for i = 1, #kids do
					local child = kids[i]
					if child and not child._suiSkipRelayout then
						if child._fixedWidth and child._fixedWidth > nextHostW - 8 then
							child._fixedWidth = nil
						end
						ReleaseWide(child)
					end
				end
			end
			ReleaseWide(body)
		end
		local contentPad = (T and T.sizes and T.sizes.contentPad) or 4
		local h
		local tabBar = body._tabBar
		local contentFrame = body._contentFrame
		if tabBar and contentFrame and contentFrame._inner then
			local tabH = body._layoutTabs and body._layoutTabs(hostW) or (T.sizes.tabH or 24)
			local intro = body._tabIntro
			local introH = 0
			if intro then
				intro:SetWidth(math.max(80, hostW))
				introH = intro:MeasureHeight(math.max(80, hostW)) + 8
			end
			local inner = contentFrame._inner
			inner:SetWidth(hostW)
			contentFrame:SetWidth(hostW)
			if inner._subtabBody then
				local subtabH = inner._layoutSubtabs and inner._layoutSubtabs(hostW)
					or (T.sizes.tabH or 24)
				local subBody = inner._subtabBody
				subBody:SetWidth(hostW)
				local subBottom = RemeasureWrappedChildren(subBody, contentPad)
				local subH = math.max(contentPad * 2, subBody:GetHeight() or 0,
					subBottom + contentPad)
				subBody:SetHeight(subH)
				if inner._subtabHost then inner._subtabHost:SetHeight(subH) end
				inner:SetHeight(subtabH + T.sizes.tabContentGap + subH)
			end
			local innerBottom = RemeasureWrappedChildren(inner, contentPad)
			local ih = math.max(contentPad * 2, inner:GetHeight() or 0, innerBottom + contentPad)
			inner:SetHeight(ih)
			contentFrame:SetHeight(ih)
			h = ih + tabH + T.sizes.tabContentGap + introH
		else
			local bottom = RemeasureWrappedChildren(body, contentPad)
			h = math.max(contentPad * 2, bottom + contentPad)
		end
		body:SetHeight(h)
		detailHost._fitH = math.max(contentPad * 2, h)
		detailHost:SetHeight(detailHost._fitH)
		if r and r._addonListSyncHeights then
			r._addonListSyncHeights()
		end
		body._heightLock = nil
	end
	body._onContentHeightChanged = RefreshDetailHeights
	detailHost._onContentHeightChanged = RefreshDetailHeights
	local function FinishDisabledBody()
		if not bodyDisabled then return end
		local function DisableChildren(parent)
			for _, child in ipairs({ parent:GetChildren() }) do
				if child.SetDisabled then
					child._suiGetDisabled = function() return true end
					child:SetDisabled(true)
				end
				DisableChildren(child)
			end
		end
		DisableChildren(body)
		local blocker = CreateFrame("Button", nil, body, nil, "renderer:17")
		blocker:SetAllPoints(body)
		blocker:SetFrameLevel(body:GetFrameLevel() + 100)
		blocker:EnableMouse(true)
	end

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

		local intro
		local introText = bodyOpt.suiPurpose or bodyOpt.suiTabIntro
        if type(introText) == "string" and introText ~= "" then
            intro = W:Description(body, TUI(introText))
			intro:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -2)
			intro:SetPoint("TOPRIGHT", body, "TOPRIGHT", -4, -2)
			intro:MeasureHeight(math.max(80, hostW))
			body._tabIntro = intro
		end

		local tabBar = CreateFrame("Frame", nil, body, nil, "renderer:18")
		if intro then
			tabBar:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -8)
			tabBar:SetPoint("TOPRIGHT", intro, "BOTTOMRIGHT", 0, -8)
		else
			tabBar:SetPoint("TOPLEFT", 0, 0)
			tabBar:SetPoint("TOPRIGHT", 0, 0)
		end
		tabBar:SetHeight(T.sizes.tabH or 24)
		body._tabBar = tabBar

        local extraWidth = 0
        local extra = bodyOpt.suiTabBarExtra
        if not titleExtraShown and type(extra) == "table" and extra.type == "execute" then
            local extraInfo = MakeInfo(addonPath, extra)
            if not IsHidden(extra, extraInfo) then
                local button
                button = W:Button(tabBar, ResolveName(extra, extraInfo), function()
                    ApplyConfirm(extra, extraInfo, function() CallFunc(extra, extraInfo) end)
                    if button and button.Refresh then button:Refresh() end
                end, MakeTooltip(extra, extraInfo), function() return ResolveName(extra, extraInfo) end)
                extraWidth = 130
                button:SetWidth(extraWidth - 6)
                button:SetHeight(T.sizes.tabH or 24)
                button:SetPoint("TOPRIGHT", tabBar, "TOPRIGHT", 0, 0)
                BindDisabled(button, extra, extraInfo)
            end
        end

		local x = 0
		local tabH = T.sizes.tabH or 24
		local tabButtons = {}
		local contentFrame = CreateFrame("Frame", nil, body, nil, "renderer:19")
		contentFrame:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -T.sizes.tabContentGap)
		contentFrame:SetPoint("TOPRIGHT", tabBar, "BOTTOMRIGHT", 0, -T.sizes.tabContentGap)
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
			W:CloseOpenDropdown({ fromClearContent = true })
			contentFrame._activeKey = tab.key
			RefreshTitleExtra(tab.opt.suiTabBarExtra or bodyOpt.suiTabBarExtra)
			for _, b in ipairs(tabButtons) do
				StyleLocalTab(b, b.tabKey == tab.key)
			end
			local oldC = contentFrame._inner
			if oldC then
				oldC:Hide()
				oldC:SetParent(nil); if SarychUI.OptionsPool then SarychUI.OptionsPool:Release(oldC) end
				contentFrame._inner = nil
			end
			local inner = CreateFrame("Frame", nil, contentFrame, nil, "renderer:20")
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
			if tab.opt and tab.opt.suiTwoPane then
				self:RenderTwoPaneAddonList(inner, tab.opt, tabPath, detailHost:GetParent())
			else
				local subtabs = tab.opt and tab.opt.childGroups == "tab"
					and GetNestedTabGroups(tab.opt) or {}
				if #subtabs > 0 then
					local stateKey = addonKey and (addonKey .. "/" .. tab.key)
					local savedSubtab = stateKey and OC._addonListTabState[stateKey]
					local selected = subtabs[1]
					for _, subtab in ipairs(subtabs) do
						if subtab.key == savedSubtab then selected = subtab; break end
					end
					local subtabBar = CreateFrame("Frame", nil, inner, nil, "renderer:21")
					subtabBar:SetPoint("TOPLEFT", inner, "TOPLEFT", 0, 0)
					subtabBar:SetPoint("TOPRIGHT", inner, "TOPRIGHT", 0, 0)
					local subtabH = T.sizes.tabH or 24
					subtabBar:SetHeight(subtabH)
					local buttons = {}
					local subHost = CreateFrame("Frame", nil, inner, nil, "renderer:22")
					subHost:SetPoint("TOPLEFT", subtabBar, "BOTTOMLEFT", 0, -T.sizes.tabContentGap)
					subHost:SetPoint("TOPRIGHT", subtabBar, "BOTTOMRIGHT", 0, -T.sizes.tabContentGap)
					subHost:SetWidth(hostW)
					inner._subtabHost = subHost
					inner._subtabBody = subHost
					local function LayoutSubtabs(width)
						local available = math.max(70, (width or hostW))
						local row, rowX = 1, 0
						for _, button in ipairs(buttons) do
							local w = math.min(button._preferredWidth, available)
							if rowX > 0 and rowX + w > available then row = row + 1; rowX = 0 end
							button:SetWidth(w)
							button:ClearAllPoints()
							button:SetPoint("TOPLEFT", subtabBar, "TOPLEFT", rowX,
								-(row - 1) * (subtabH + 2))
							rowX = rowX + w + 2
						end
						local height = row * subtabH + (row - 1) * 2
						subtabBar:SetHeight(height)
						return height
					end
					inner._layoutSubtabs = LayoutSubtabs
					local function ShowSubtab(subtab)
						W:CloseOpenDropdown({ fromClearContent = true })
						if stateKey then OC._addonListTabState[stateKey] = subtab.key end
						for _, button in ipairs(buttons) do
							StyleLocalTab(button, button.tabKey == subtab.key)
						end
						local oldSub = subHost._inner
						if oldSub then oldSub:Hide(); oldSub:SetParent(nil); if SarychUI.OptionsPool then SarychUI.OptionsPool:Release(oldSub) end end
						local subBody = CreateFrame("Frame", nil, subHost, nil, "renderer:23")
                        local inset = 0
                        subBody:SetPoint("TOPLEFT", subHost, "TOPLEFT", inset, 0)
                        subBody:SetPoint("TOPRIGHT", subHost, "TOPRIGHT", -inset, 0)
                        subBody:SetWidth(hostW - 2 * inset)
						subBody._onContentHeightChanged = RefreshDetailHeights
						subHost._inner = subBody
						inner._subtabBody = subBody
						local subPath = {}
						for i = 1, #tabPath do subPath[i] = tabPath[i] end
						tinsert(subPath, subtab.key)
						self:RenderSection(subBody, subtab.opt, subPath)
						RefreshDetailHeights()
					end
					for _, subtab in ipairs(subtabs) do
						local button = CreateFrame("Button", nil, subtabBar, nil, "renderer:24")
						button:SetHeight(subtabH)
						button:RegisterForClicks("LeftButtonDown")
						local label = button:CreateFontString(nil, "OVERLAY", T.fonts.small)
						label:SetPoint("LEFT", 8, 0)
						label:SetPoint("RIGHT", -8, 0)
						label:SetJustifyH("CENTER")
						label:SetText(subtab.label or subtab.key)
						button.label = label
						button.tabKey = subtab.key
						button._preferredWidth = math.max(70, (label:GetStringWidth() or 40) + 20)
						if bodyDisabled then button:Disable() end
						button:SetScript("OnClick", function() ShowSubtab(subtab) end)
						tinsert(buttons, button)
					end
					LayoutSubtabs(hostW)
					ShowSubtab(selected)
				else
					self:RenderSection(inner, tab.opt, tabPath)
				end
			end
			if core and core.EndHiddenCapture then
				core:EndHiddenCapture(token)
			end
			RefreshDetailHeights()
		end

		for _, tab in ipairs(tabs) do
			local tabKey = tab.key
			local btn = CreateFrame("Button", nil, tabBar, nil, "renderer:25")
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
			btn._preferredWidth = w
			btn:SetPoint("TOPLEFT", tabBar, "TOPLEFT", x, 0)
			StyleLocalTab(btn, tabKey == active.key)
			if bodyDisabled then btn:Disable() end
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
		if bodyOpt.suiWrapTabs or extraWidth > 0 then
			body._layoutTabs = function(width)
				local available = math.max(70, (width or hostW) - extraWidth)
				local row, rowX = 1, 0
				local rowGap = T.sizes.tabRowGap
				for _, btn in ipairs(tabButtons) do
					local w = math.min(btn._preferredWidth, available)
					if rowX > 0 and rowX + w > available then
						row = row + 1
						rowX = 0
					end
					btn:SetWidth(w)
					btn:ClearAllPoints()
					btn:SetPoint("TOPLEFT", tabBar, "TOPLEFT", rowX, -(row - 1) * (tabH + rowGap))
					rowX = rowX + w + rowGap
				end
				local height = row * tabH + (row - 1) * rowGap
				tabBar:SetHeight(height)
				return height
			end
			body._layoutTabs(hostW)
		end

		ShowTab(active)
		FinishDisabledBody()
		return
	end

    if titleOnly and not bodyOpt.suiPurpose then
        body:SetHeight(1)
    elseif type(bodyOpt.suiPurpose) == "string" and bodyOpt.suiPurpose ~= "" then
        -- Keep the purpose line outside the framed settings panel.
        local intro = W:Description(body, TUI(bodyOpt.suiPurpose))
        intro:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -2)
        intro:SetPoint("TOPRIGHT", body, "TOPRIGHT", -4, -2)
        intro:MeasureHeight(math.max(80, hostW))
        if not titleOnly then
            local settingsHost = CreateFrame("Frame", nil, body, nil, "renderer:26")
            settingsHost:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", -4, -8)
            settingsHost:SetPoint("TOPRIGHT", intro, "BOTTOMRIGHT", 4, -8)
            settingsHost:SetWidth(hostW)
            self:RenderSection(settingsHost, bodyOpt, addonPath)
        end
    else
        self:RenderSection(body, bodyOpt, addonPath)
    end
	RefreshDetailHeights()
	FinishDisabledBody()
end

function R:RenderTwoPaneAddonList(parent, groupOpt, path, nestedViewport)
	if not parent then return end
	local OC = SUI.OptionsCore
	local OW = SUI._activeOptionsWindow or SUI.OptionsWindow
	local listW = (T and T.sizes and T.sizes.addonListW) or 200
	local itemH = (T and T.sizes and T.sizes.navItemH) or 22
	local contentPad = (T and T.sizes and T.sizes.contentPad) or 4
	local pathKey = PathKey(path)
	local initialDetailScroll = OC._twoPaneDetailScroll and OC._twoPaneDetailScroll[pathKey] or 0
	local initialListScroll = OC._twoPaneScroll and OC._twoPaneScroll[pathKey] or 0
	local isAddonPorted = pathKey == "src/vendor/addons/ported"

	local entries, shared = CollectTwoPaneEntries(groupOpt)

	-- Shared controls (refresh, toggles...) above the two-pane split.
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

	if #entries == 0 and not groupOpt.suiKeepEmptyTwoPane then
		local d = W:Description(parent, TUI("ui.options_f94668d82f"))
		self:LayoutChild(parent, d, yTop, contentPad)
		parent:SetHeight(math.max(40, -yTop + 40))
		return
	end

	-- Runtime selection (compat: Аддоны -> Список still uses _addonListSelected).
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
		found = entries[1] or { key = "__empty", label = TUI("ui.options_e4e2658c7c"),
			opt = { type = "group", args = {} } }
		selected = found.key
	end
	OC._twoPaneSelected[pathKey] = selected
	if isAddonPorted then
		OC._addonListSelected = selected
	end

	local shell = CreateFrame("Frame", nil, parent, nil, "renderer:27")
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

	local scrollW = T.sizes.scrollbarW
	local left = CreateFrame("Frame", nil, shell, nil, "renderer:28")
	left:SetPoint("TOPLEFT", 0, 0)
	left:SetWidth(listW)
	left:EnableMouse(true)
	T:ApplyFlat(left, T.colors.navBg, T.colors.borderSoft)

	local listScroll = CreateFrame("ScrollFrame", nil, left, nil, "renderer:29")
	listScroll:SetPoint("TOPLEFT", 2, -2)
	listScroll:SetPoint("BOTTOMLEFT", 2, 2)
	listScroll:SetPoint("RIGHT", left, "RIGHT", -(scrollW + 4), 0)
	listScroll:EnableMouse(true)

	local listChild = CreateFrame("Frame", nil, listScroll, nil, "renderer:30")
	listChild:SetWidth(math.max(40, listW - scrollW - 12))
	listChild:SetHeight(1)
	listScroll:SetScrollChild(listChild)

	local listContentH = #entries * itemH + 4


	local function GetViewportH()
		local viewportH = 200
		if nestedViewport then
			local vis = (nestedViewport:GetHeight() or 0) - ((T.sizes and T.sizes.tabH) or 24) - 6
			if vis > 40 then viewportH = vis end
		elseif OW and OW.contentScroll then
			local vis = OW.contentScroll:GetHeight() or 0
			if vis > 40 then
				viewportH = vis
			end
		end
		-- Space already used above this two-pane (add-spell row, inline type tabs,
		-- or shared controls rendered inside the two-pane parent).
		local usedAbove = math.abs(yTop or 0)
		if not nestedViewport and parent and OW and OW.contentChild and parent ~= OW.contentChild then
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

	local function ListMetrics()
		local paneH = left:GetHeight() or 0
		local viewH = paneH > 1 and (paneH - 4) or (listScroll:GetHeight() or 0)
		if viewH < 1 then
			viewH = math.max(1, GetViewportH() - 4)
		end
		-- Tracked content height, not the scroll child: on 3.3.5 the child
		-- rect stays taller than the rows, so a bar showed with nothing to scroll.
		local contentH = listContentH or 0
		if contentH < 1 then
			contentH = listChild:GetHeight() or 0
		end
		local overflow = contentH - viewH
		if overflow < 4 then overflow = 0 end
		return viewH, contentH, overflow
	end

    local sbTrack, UpdateListBar = W:Scrollbar(left, listScroll, ListMetrics, function(value)
        OC._twoPaneScroll[pathKey] = value
        if isAddonPorted then OC._addonListScroll = value end
    end)
    local function UpdateScrollbarThumb()
        local _, _, overflow = ListMetrics()
        local inset = 2 + (overflow > 0 and (scrollW + T.sizes.scrollbarGap) or 0)
        listScroll:SetPoint("RIGHT", left, "RIGHT", -inset, 0)
        listChild:SetWidth(math.max(40, (left:GetWidth() or listW) - inset - 2))
        UpdateListBar()
    end

	local function SetAddonListScroll(offset, syncThumb)
		local _, _, max = ListMetrics()
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
		local _, _, max = ListMetrics()
		if max > 0 then
			SetAddonListScroll(cur - delta * T.sizes.scrollStep, true)
			return true
		end
		return false
	end


	left:EnableMouseWheel(true)
	left:SetScript("OnMouseWheel", function(_, delta)
		ScrollAddonList(delta)
	end)
	listScroll:EnableMouseWheel(true)
	listScroll:SetScript("OnMouseWheel", function(_, delta)
		ScrollAddonList(delta)
	end)

	local right = CreateFrame("Frame", nil, shell, nil, "renderer:31")
	local rightW = ResolveTwoPaneRightWidth(shell)
	right:SetPoint("TOPLEFT", shell, "TOPLEFT", listW + 4, 0)
	right:SetPoint("TOPRIGHT", shell, "TOPRIGHT", 0, 0)
	right:SetWidth(rightW)
	right:EnableMouse(true)
	T:ApplyFlat(right, T.colors.panelBg, T.colors.borderSoft)

	local titleRowH = (T.sizes and T.sizes.rowH) or 22
	local detailPad = T.sizes.pageInset
	local titleRow = CreateFrame("Frame", nil, right, nil, "renderer:32")
	titleRow:SetPoint("TOPLEFT", detailPad, -detailPad)
	titleRow:SetPoint("TOPRIGHT", -(scrollW + detailPad), -detailPad)
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

	local enableHost = CreateFrame("Frame", nil, titleRow, nil, "renderer:33")
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
	local rightScroll = CreateFrame("ScrollFrame", nil, right, nil, "renderer:34")
	rightScroll:SetPoint("TOPLEFT", detailPad, -(titleRowH + detailPad * 2))
	rightScroll:SetPoint("BOTTOMLEFT", detailPad, detailPad)
	rightScroll:SetPoint("RIGHT", right, "RIGHT", -(scrollW + detailPad), 0)
	rightScroll:EnableMouse(true)

	local detailHost = CreateFrame("Frame", nil, rightScroll, nil, "renderer:35")
	detailHost:SetWidth(math.max(160, rightW - scrollW - T.sizes.scrollbarGap - T.sizes.pageInset * 2))
	detailHost:SetHeight(1)
	rightScroll:SetScrollChild(detailHost)


	OC._twoPaneDetailScroll = OC._twoPaneDetailScroll or {}
	local detailContentH = 1

	local function RightMetrics()
		local chrome = titleRowH + detailPad * 3
		local paneH = right:GetHeight() or 0
		local viewH = paneH > 1 and (paneH - chrome) or (rightScroll:GetHeight() or 0)
		if viewH < 1 then
			viewH = math.max(1, GetViewportH() - chrome)
		end
		local contentH = detailHost._fitH or detailContentH or 0
		if contentH < 1 then
			contentH = detailHost:GetHeight() or 0
		end
		local overflow = contentH - viewH
		if overflow < 4 then overflow = 0 end
		return viewH, contentH, overflow
	end

    local rightSbTrack, UpdateDetailBar = W:Scrollbar(right, rightScroll, RightMetrics, function(value)
        OC._twoPaneDetailScroll[pathKey] = value
    end)
    local function UpdateRightScrollbarThumb()
        local _, _, overflow = RightMetrics()
        local inset = detailPad + (overflow > 0 and (scrollW + T.sizes.scrollbarGap) or 0)
        rightScroll:SetPoint("RIGHT", right, "RIGHT", -inset, 0)
        titleRow:SetPoint("TOPRIGHT", -inset, -detailPad)
        UpdateDetailBar()
    end

	local function SetRightDetailScroll(offset, syncThumb)
		local _, _, max = RightMetrics()
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
		local _, _, max = RightMetrics()
		if max > 0 then
			SetRightDetailScroll(cur - delta * T.sizes.scrollStep, true)
			return true
		end
		return false
	end

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
		-- Layout can clamp the live scroll before the new height is available.
		local detailOffset = OC._twoPaneDetailScroll[pathKey] or 0
		local listOffset = OC._twoPaneScroll[pathKey] or 0
		local dh = detailHost._fitH or detailHost:GetHeight() or 40
		detailContentH = math.max(1, dh)
		detailHost:SetHeight(detailContentH)
		if rightScroll.UpdateScrollChildRect then
			rightScroll:UpdateScrollChildRect()
		end

		-- Both panes fill remaining viewport; only their inner scrolls move.
		local viewportH = GetViewportH()
		shell:SetHeight(viewportH)
		parent:SetHeight(math.max(40, -yTop + viewportH))

		-- Clamp the outer content child to the scroll viewport so the page
		-- itself cannot scroll - only the spell list / detail panes do.
		if not nestedViewport and OW and OW.contentScroll and OW.contentChild then
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
		local savedScroll = listOffset
		if isAddonPorted and OC._addonListScroll then
			savedScroll = OC._addonListScroll
		end
		SetAddonListScroll(savedScroll or 0, true)
		SetRightDetailScroll(detailOffset, true)
	end
	right._addonListSyncHeights = SyncHeights

	shell:HookScript("OnShow", function(self) self._componentRevision = nil end)
	shell:SetScript("OnUpdate", function(self)
		if not self:IsVisible() then return end
        local revision = SUI._componentStateRevision or 0
        local profile = SUI.db and SUI.db.profile
        if self._componentRevision ~= revision or self._componentProfile ~= profile then
            self._componentRevision, self._componentProfile = revision, profile
            for _, button in ipairs(buttons) do
                if button.RefreshComponentState then button:RefreshComponentState() end
            end
        end
		local detailWidth = rightScroll:GetWidth()
		if detailWidth and detailWidth > 80 and self._lastDetailWidth ~= detailWidth then
			self._lastDetailWidth = detailWidth
			if detailHost._body and detailHost._body._layoutTabs
				and detailHost._onContentHeightChanged then
				detailHost:_onContentHeightChanged()
			end
		end
		local viewportH = GetViewportH()
		if self._lastViewportH ~= viewportH then
			self._lastViewportH = viewportH
			shell:SetHeight(viewportH)
			parent:SetHeight(math.max(40, -yTop + viewportH))
			if not nestedViewport and OW and OW.contentScroll and OW.contentChild then
				local scrollH = OW.contentScroll:GetHeight() or 0
				if scrollH > 40 then
					OW.contentChild:SetHeight(scrollH)
				end
				OW.contentScroll:SetVerticalScroll(0)
			end
			LayoutLeftPane()
			LayoutRightPane()
		end
		UpdateScrollbarThumb()
		UpdateRightScrollbarThumb()
	end)

	local function SelectAddon(entry, force)
		if not entry then return end
		if not force and selected == entry.key and detailHost._body then
			return
		end
		if entry.opt and type(entry.opt.suiOnSelect) == "function" then
			Safe(entry.opt.suiOnSelect, entry.key)
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
		local detailW = math.max(160, rw - scrollW - T.sizes.scrollbarGap - T.sizes.pageInset * 2)
		detailHost:SetWidth(detailW)
		-- Rebuilding the same selection must retain its position. A user
		-- selecting another entry starts that entry at the top.
		OC._twoPaneDetailScroll[pathKey] = force and initialDetailScroll or 0
		if force then OC._twoPaneScroll[pathKey] = initialListScroll end
		self:RenderAddonDetail(detailHost, entry.opt, addonPath, entry.key)
		-- Height callbacks during construction can temporarily report an empty body.
		OC._twoPaneDetailScroll[pathKey] = force and initialDetailScroll or 0
		if force then OC._twoPaneScroll[pathKey] = initialListScroll end
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
	if #entries == 0 then
		local empty = listChild:CreateFontString(nil, "OVERLAY", T.fonts.small)
		empty:SetPoint("TOPLEFT", listChild, "TOPLEFT", 8, -8)
		empty:SetPoint("TOPRIGHT", listChild, "TOPRIGHT", -8, -8)
		empty:SetJustifyH("LEFT")
		empty:SetText(TUI("ui.options_e4e2658c7c"))
	end
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
			hdr:SetText(TUI(entry.listGroup))
			T:SetTextColor(hdr, "title")
			y = y + (itemH - 2)
		end
		local btn = CreateFrame("Button", nil, listChild, nil, "renderer:36")
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
        if path and (path[1] == "extensions" or path[1] == "addons") then
            local enabled = entry.opt.args and entry.opt.args.enabled
            if enabled and enabled.type == "toggle" then
                local enablePath = {}
                for i = 1, #path do enablePath[i] = path[i] end
                tinsert(enablePath, entry.key)
                tinsert(enablePath, "enabled")
                local info = MakeInfo(enablePath, enabled, entry.opt.handler)
                btn.RefreshComponentState = function(self)
                    local value = CallGet(enabled, info)
                    local disabled = value == false or value == 0
                    if self._componentDisabled ~= disabled then
                        self._componentDisabled = disabled
                        StyleAddonListButton(self, self._active)
                    end
                end
                btn.Refresh = btn.RefreshComponentState
                btn:RefreshComponentState()
            end
        end
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
