-- Transfer options UI: tab under Profiles + export/import dialogs (SarychUI visual).

local CreateFrame = CreateFrame
local UIParent = UIParent
local UISpecialFrames = UISpecialFrames
local tinsert = table.insert
local floor = math.floor
local strtrim, strlower = strtrim, string.lower

local Transfer = SarychUI.Transfer

local WINDOW_WIDTH, WINDOW_HEIGHT = 520, 400
local EDGE = 16
local BOX_TOP = -36
local BOX_HEIGHT = 140
local SCROLL_INSET = 6
local SCROLL_RIGHT = 8
local COLUMN_WIDTH = 244
local CHECK_LINE = 22
local ROWS = 5

local textWindow
local importWindow
local decoded

local function T(text)
	if SarychUI.T then
		return SarychUI:T(text)
	end
	return text
end

local function Theme()
	return SarychUI.OptionsTheme
end

local function ApplyTheme(frame, bgKey)
	local theme = Theme()
	if theme and theme.ApplyFlat then
		theme:ApplyFlat(frame, theme.colors[bgKey or "panelBg"], theme.colors.border)
	end
end

-- Same font objects as OptionsTheme / options widgets (not raw FRIZQT SetFont).
local function ThemeFontKey(key)
	local theme = Theme()
	return (theme and theme.fonts and theme.fonts[key or "normal"]) or "GameFontHighlightSmall"
end

local function MakeFontString(parent, key, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY", ThemeFontKey(key))
	fs:SetJustifyH("LEFT")
	return fs
end

local function MakeButton(parent, label, width)
	local theme = Theme()
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(width or 96, 24)
	ApplyTheme(btn, "buttonBg")
	local fs = MakeFontString(btn, "normal")
	if theme then
		theme:SetTextColor(fs, "title")
	else
		fs:SetTextColor(1, 0.82, 0.2, 1)
	end
	fs:SetPoint("CENTER")
	fs:SetJustifyH("CENTER")
	fs:SetText(label)
	btn.label = fs
	btn:SetScript("OnEnter", function(self)
		ApplyTheme(self, "buttonHover")
	end)
	btn:SetScript("OnLeave", function(self)
		if self:IsEnabled() == 1 then
			ApplyTheme(self, "buttonBg")
		end
	end)
	btn:SetScript("OnEnable", function(self)
		ApplyTheme(self, "buttonBg")
		if theme then
			theme:SetTextColor(self.label, "title")
		end
	end)
	btn:SetScript("OnDisable", function(self)
		ApplyTheme(self, "disabled")
		if self.label then
			self.label:SetTextColor(0.5, 0.5, 0.5, 1)
		end
	end)
	return btn
end

local function SetEnabled(control, enabled)
	if enabled then
		control:Enable()
	else
		control:Disable()
	end
end

local function CreateBaseWindow(name, height)
	local f = CreateFrame("Frame", name, UIParent)
	f:SetSize(WINDOW_WIDTH, height or WINDOW_HEIGHT)
	f:SetPoint("CENTER")
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:Hide()
	ApplyTheme(f, "dialogBg")

	local title = MakeFontString(f, "title")
	local theme = Theme()
	if theme then
		theme:SetTextColor(title, "title")
	else
		title:SetTextColor(1, 0.82, 0.2, 1)
	end
	title:SetPoint("TOPLEFT", EDGE, -14)
	title:SetPoint("TOPRIGHT", -EDGE, -14)
	title:SetJustifyH("LEFT")
	f.heading = title

	f:SetScript("OnShow", function(self)
		if SarychUI.RaiseStaticPopupAboveConfig then
			SarychUI:RaiseStaticPopupAboveConfig(self)
		end
	end)

	tinsert(UISpecialFrames, name)
	return f
end

local function CreateEditBox(parent, topOffset, boxHeight)
	local inset = CreateFrame("Frame", nil, parent)
	ApplyTheme(inset, "inputBg")
	inset:SetPoint("TOPLEFT", EDGE, topOffset)
	inset:SetPoint("TOPRIGHT", -EDGE, topOffset)
	inset:SetHeight(boxHeight)

	local scroll = CreateFrame("ScrollFrame", nil, inset)
	scroll:SetPoint("TOPLEFT", SCROLL_INSET, -SCROLL_INSET)
	scroll:SetPoint("BOTTOMRIGHT", -SCROLL_RIGHT, SCROLL_INSET)

	local box = CreateFrame("EditBox", nil, scroll)
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetMaxLetters(0)
	box:SetWidth(WINDOW_WIDTH - EDGE * 2 - SCROLL_INSET - SCROLL_RIGHT)
	box:SetTextInsets(4, 4, 4, 4)
	box:SetFontObject(ThemeFontKey("normal"))
	box:SetScript("OnEscapePressed", box.ClearFocus)
	box:SetScript("OnTextChanged", function()
		scroll:UpdateScrollChildRect()
	end)
	scroll:SetScrollChild(box)
	scroll:SetScript("OnMouseDown", function()
		box:SetFocus()
	end)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local maxScroll = self:GetVerticalScrollRange() or 0
		local cur = self:GetVerticalScroll() or 0
		self:SetVerticalScroll(math.max(0, math.min(maxScroll, cur - delta * 20)))
	end)

	return inset, box, scroll
end

-----------------------------------------------------------------------
-- Export text window
-----------------------------------------------------------------------
local function EnsureTextWindow()
	if textWindow then
		return textWindow
	end
	local f = CreateBaseWindow("SarychUITransferText", 320)
	local _, box = CreateEditBox(f, BOX_TOP, 220)
	f.box = box

	local close = MakeButton(f, T("ui.options_4ae50d3073"), 96)
	close:SetPoint("BOTTOMRIGHT", -EDGE, EDGE)
	close:SetScript("OnClick", function()
		f:Hide()
	end)

	textWindow = f
	return f
end

function SarychUI:ShowTransferTextWindow(heading, text)
	local f = EnsureTextWindow()
	f.heading:SetText(heading or "")
	f.box:SetText(text or "")
	f:Show()
	f.box:SetFocus()
	f.box:HighlightText()
end

function SarychUI:HideTransferTextWindow()
	if textWindow then
		textWindow:Hide()
	end
end

-----------------------------------------------------------------------
-- Import window with category checks
-----------------------------------------------------------------------
local function selectedCategories(window)
	local selected, labels = {}, {}
	for i, category in ipairs(Transfer.CATEGORIES) do
		local check = window.checks[i]
		local enabled = check.IsEnabled and check:IsEnabled()
		if (enabled == true or enabled == 1) and check:GetChecked() then
			selected[category.key] = true
			labels[#labels + 1] = T(category.label)
		end
	end
	return selected, labels
end

local function updateApply(window)
	local _, labels = selectedCategories(window)
	SetEnabled(window.apply, #labels > 0)
end

local function updateContents(window, text)
	local data, err
	if strtrim(text) ~= "" then
		data, err = Transfer.Decode(text)
	end
	decoded = data

	local summary = window.summary
	local theme = Theme()
	if data then
		summary:SetText(T("ui.options_7bb0a57a41"):format(type(data.character) == "string" and data.character or "?"))
		if theme then
			theme:SetTextColor(summary, "title")
		else
			summary:SetTextColor(1, 0.82, 0, 1)
		end
	elseif err then
		summary:SetText(err)
		summary:SetTextColor(1, 0.3, 0.3, 1)
	else
		summary:SetText(T("ui.options_99275b81e3"))
		if theme then
			theme:SetTextColor(summary, "textDim")
		else
			summary:SetTextColor(0.5, 0.5, 0.5, 1)
		end
	end

	for i, category in ipairs(Transfer.CATEGORIES) do
		local check = window.checks[i]
		local count = data and Transfer.Count(data, category.key)
		check:SetChecked(count ~= nil)
		SetEnabled(check, count ~= nil)
		if count then
			check.label:SetFormattedText("%s (%d)", T(category.label), count)
			if theme then
				theme:SetTextColor(check.label, "text")
			else
				check.label:SetTextColor(1, 1, 1, 1)
			end
		else
			check.label:SetText(T(category.label))
			if theme then
				theme:SetTextColor(check.label, "disabled")
			else
				check.label:SetTextColor(0.5, 0.5, 0.5, 1)
			end
		end
	end
	updateApply(window)
end

local function ResetConfirmPopupLabels()
	local popup = _G.SarychUIReloadPopup
	if popup and popup.accept and popup.accept.label then
		popup.accept.label:SetText(ACCEPT or "OK")
	end
	if popup and popup.cancel and popup.cancel.label then
		popup.cancel.label:SetText(CANCEL or "Cancel")
	end
end

local function ConfirmImport(from, labels, onYes, wipeMacros)
	local msg = T("ui.options_e5723ee98a"):format(
		from,
		table.concat(labels, ", ")
	)
	if wipeMacros then
		msg = msg .. "\n\n|cffffd100" .. T("ui.options_5db35ebed5") .. "|r"
	end
	if SarychUI.ShowReloadPopup then
		SarychUI:ShowReloadPopup(msg, ResetConfirmPopupLabels, function()
			ResetConfirmPopupLabels()
			if onYes then
				onYes()
			end
		end)
		local popup = _G.SarychUIReloadPopup
		if popup and popup.accept and popup.accept.label then
			popup.accept.label:SetText(T("ui.options_768af67762"))
		end
		if popup and popup.cancel and popup.cancel.label then
			popup.cancel.label:SetText(CANCEL or T("ui.options_0ec753be8d"))
		end
	elseif onYes then
		onYes()
	end
end

local equipRemapWindow
local openEquipDropdown

local function QualityColor(quality)
	local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1]
	if c then
		return c.r, c.g, c.b
	end
	if quality == 4 then
		return 0.64, 0.21, 0.93
	end
	return 1, 1, 1
end

local function CloseEquipDropdown()
	if openEquipDropdown and openEquipDropdown.list then
		openEquipDropdown.list:Hide()
	end
	openEquipDropdown = nil
end

local function SetItemLabel(fs, name, quality)
	fs:SetText(name or "")
	local r, g, b = QualityColor(quality)
	fs:SetTextColor(r, g, b, 1)
end

local function EnsureEquipRemapWindow()
	if equipRemapWindow then
		return equipRemapWindow
	end

	local WIDTH, HEIGHT = 620, 420
	local f = CreateFrame("Frame", "SarychUITransferEquipRemap", UIParent)
	f:SetSize(WIDTH, HEIGHT)
	f:SetPoint("CENTER")
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:Hide()
	ApplyTheme(f, "dialogBg")
	tinsert(UISpecialFrames, "SarychUITransferEquipRemap")

	local title = MakeFontString(f, "title")
	title:SetPoint("TOPLEFT", EDGE, -14)
	title:SetPoint("TOPRIGHT", -EDGE, -14)
	title:SetJustifyH("LEFT")
	title:SetText(T("ui.options_d90ac7733f"))
	local theme = Theme()
	if theme then
		theme:SetTextColor(title, "title")
	else
		title:SetTextColor(1, 0.82, 0.2, 1)
	end
	f.heading = title

	local hint = MakeFontString(f, "small")
	hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	hint:SetPoint("TOPRIGHT", -EDGE, -34)
	hint:SetJustifyH("LEFT")
	hint:SetText(T("ui.options_d7159dfedc"))
	if theme then
		theme:SetTextColor(hint, "textDim")
	else
		hint:SetTextColor(0.7, 0.7, 0.7, 1)
	end

	local listHost = CreateFrame("Frame", nil, f)
	ApplyTheme(listHost, "inputBg")
	listHost:SetPoint("TOPLEFT", EDGE, -58)
	listHost:SetPoint("BOTTOMRIGHT", -EDGE, 48)

	local scroll = CreateFrame("ScrollFrame", nil, listHost)
	scroll:SetPoint("TOPLEFT", 6, -6)
	scroll:SetPoint("BOTTOMRIGHT", -22, 6)
	scroll:EnableMouseWheel(true)

	local content = CreateFrame("Frame", nil, scroll)
	content:SetWidth(WIDTH - EDGE * 2 - 36)
	content:SetHeight(1)
	scroll:SetScrollChild(content)
	f.content = content
	f.scroll = scroll
	f.rows = {}

	local slider = CreateFrame("Slider", nil, listHost)
	slider:SetWidth(14)
	slider:SetPoint("TOPRIGHT", -4, -6)
	slider:SetPoint("BOTTOMRIGHT", -4, 6)
	slider:SetOrientation("VERTICAL")
	slider:SetMinMaxValues(0, 1)
	slider:SetValueStep(1)
	slider:SetValue(0)
	ApplyTheme(slider, "buttonBg")
	slider:SetScript("OnValueChanged", function(self, value)
		scroll:SetVerticalScroll(value)
	end)
	scroll:SetScript("OnMouseWheel", function(_, delta)
		local maxScroll = scroll:GetVerticalScrollRange() or 0
		local cur = scroll:GetVerticalScroll() or 0
		local nextVal = math.max(0, math.min(maxScroll, cur - delta * 28))
		scroll:SetVerticalScroll(nextVal)
		slider:SetMinMaxValues(0, maxScroll)
		slider:SetValue(nextVal)
	end)
	f.slider = slider

	local cancel = MakeButton(f, CANCEL or T("ui.options_0ec753be8d"), 96)
	cancel:SetPoint("BOTTOMRIGHT", -EDGE, EDGE)
	cancel:SetScript("OnClick", function()
		CloseEquipDropdown()
		f:Hide()
		if f.onCancel then
			f.onCancel()
		end
	end)

	local ok = MakeButton(f, T("ui.options_3f75368ab9"), 110)
	ok:SetPoint("RIGHT", cancel, "LEFT", -4, 0)
	ok:SetScript("OnClick", function()
		CloseEquipDropdown()
		local remap = {}
		for i = 1, #(f.rowData or {}) do
			local row = f.rowData[i]
			if row and type(row.name) == "string" and type(row.selected) == "string" then
				local from, to = strtrim(row.name), strtrim(row.selected)
				if from ~= "" and to ~= "" and from ~= to then
					remap[from] = to
				end
			end
		end
		f:Hide()
		if f.onContinue then
			f.onContinue(remap)
		end
	end)

	f:SetScript("OnHide", CloseEquipDropdown)
	f:SetScript("OnShow", function(self)
		if SarychUI.RaiseStaticPopupAboveConfig then
			SarychUI:RaiseStaticPopupAboveConfig(self)
		end
	end)

	equipRemapWindow = f
	return f
end

local DROPDOWN_MAX_H = 200
local DROPDOWN_ROW_H = 24
local DROPDOWN_VISIBLE = 6

local function BuildEquipDropdown(rowFrame, rowData)
	local theme = Theme()
	local btn = CreateFrame("Button", nil, rowFrame)
	btn:SetHeight(26)
	btn:SetPoint("LEFT", rowFrame, "CENTER", 8, 0)
	btn:SetPoint("RIGHT", rowFrame, "RIGHT", -8, 0)
	ApplyTheme(btn, "buttonBg")

	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetSize(18, 18)
	icon:SetPoint("LEFT", 4, 0)
	btn.icon = icon

	local label = MakeFontString(btn, "small")
	label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
	label:SetPoint("RIGHT", -16, 0)
	label:SetJustifyH("LEFT")
	btn.label = label

	local arrow = MakeFontString(btn, "small")
	arrow:SetPoint("RIGHT", -5, 0)
	arrow:SetText(SarychUI:T("ui.options_7a38d8cbd2"))
	if theme then
		theme:SetTextColor(arrow, "accent")
	end

	local list = CreateFrame("Frame", nil, UIParent)
	list:SetFrameStrata("TOOLTIP")
	list:SetToplevel(true)
	list:EnableMouse(true)
	list:Hide()
	ApplyTheme(list, "dropdownBg")
	btn.list = list

	local search = CreateFrame("EditBox", nil, list)
	search:SetHeight(20)
	search:SetAutoFocus(false)
	search:SetFontObject(ThemeFontKey("normal"))
	search:SetTextInsets(6, 6, 0, 0)
	search:SetPoint("TOPLEFT", 6, -6)
	search:SetPoint("TOPRIGHT", -6, -6)
	ApplyTheme(search, "inputBg")
	search:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		CloseEquipDropdown()
	end)
	list.search = search

	local scrollHost = CreateFrame("Frame", nil, list)
	scrollHost:SetPoint("TOPLEFT", 4, -30)
	scrollHost:SetPoint("BOTTOMRIGHT", -18, 4)
	list.scrollHost = scrollHost

	local scroll = CreateFrame("ScrollFrame", nil, scrollHost)
	scroll:SetAllPoints()
	scroll:EnableMouseWheel(true)
	list.scroll = scroll

	local content = CreateFrame("Frame", nil, scroll)
	content:SetWidth(1)
	content:SetHeight(1)
	scroll:SetScrollChild(content)
	list.content = content
	list.buttons = {}

	local slider = CreateFrame("Slider", nil, list)
	slider:SetWidth(12)
	slider:SetPoint("TOPRIGHT", -4, -30)
	slider:SetPoint("BOTTOMRIGHT", -4, 4)
	slider:SetOrientation("VERTICAL")
	slider:SetMinMaxValues(0, 1)
	slider:SetValueStep(1)
	slider:SetValue(0)
	ApplyTheme(slider, "buttonBg")
	slider:SetScript("OnValueChanged", function(self, value)
		scroll:SetVerticalScroll(value)
	end)
	scroll:SetScript("OnMouseWheel", function(_, delta)
		local maxScroll = scroll:GetVerticalScrollRange() or 0
		local cur = scroll:GetVerticalScroll() or 0
		local nextVal = math.max(0, math.min(maxScroll, cur - delta * DROPDOWN_ROW_H))
		scroll:SetVerticalScroll(nextVal)
		slider:SetMinMaxValues(0, maxScroll)
		slider:SetValue(nextVal)
	end)
	list.slider = slider

	local emptyHint = MakeFontString(list, "small")
	emptyHint:SetPoint("TOPLEFT", scrollHost, "TOPLEFT", 6, -8)
	emptyHint:SetPoint("TOPRIGHT", scrollHost, "TOPRIGHT", -6, -8)
	emptyHint:SetJustifyH("LEFT")
	emptyHint:Hide()
	if theme then
		theme:SetTextColor(emptyHint, "textDim")
	else
		emptyHint:SetTextColor(0.65, 0.65, 0.65, 1)
	end
	list.emptyHint = emptyHint

	local function RefreshButton()
		local selectedName = rowData.selected or rowData.name
		local selected
		if selectedName == rowData.name then
			selected = {
				name = rowData.name,
				icon = rowData.icon,
				quality = rowData.quality,
			}
		else
			for i = 1, #(rowData.candidates or {}) do
				if rowData.candidates[i].name == selectedName then
					selected = rowData.candidates[i]
					break
				end
			end
		end
		if not selected then
			selected = { name = selectedName, icon = rowData.icon, quality = 1 }
		end
		icon:SetTexture(selected.icon or rowData.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
		SetItemLabel(label, selected.name, selected.quality)
	end

	local function Choose(name)
		rowData.selected = name
		CloseEquipDropdown()
		RefreshButton()
	end

	local function AllEntries()
		local entries = {
			{
				name = rowData.name,
				icon = rowData.icon,
				quality = rowData.quality,
				keep = true,
			},
		}
		for i = 1, #(rowData.candidates or {}) do
			local c = rowData.candidates[i]
			if strlower(c.name) ~= strlower(rowData.name) then
				entries[#entries + 1] = c
			end
		end
		return entries
	end

	local function RebuildList(filter)
		filter = strlower(strtrim(filter or ""))
		for i = 1, #list.buttons do
			list.buttons[i]:Hide()
		end
		local entries = AllEntries()
		local shown = {}
		for i = 1, #entries do
			local entry = entries[i]
			local labelText = entry.keep and (T("ui.options_fd56cc99ca") .. " " .. entry.name) or entry.name
			if filter == "" or strlower(entry.name):find(filter, 1, true) or strlower(labelText):find(filter, 1, true) then
				shown[#shown + 1] = entry
			end
		end

		local width = btn:GetWidth() or 240
		content:SetWidth(math.max(40, width - 28))
		local y = 0
		for i = 1, #shown do
			local entry = shown[i]
			local b = list.buttons[i]
			if not b then
				b = CreateFrame("Button", nil, content)
				b:SetHeight(DROPDOWN_ROW_H)
				ApplyTheme(b, "buttonBg")
				b.icon = b:CreateTexture(nil, "ARTWORK")
				b.icon:SetSize(16, 16)
				b.icon:SetPoint("LEFT", 4, 0)
				b.text = MakeFontString(b, "small")
				b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
				b.text:SetPoint("RIGHT", -4, 0)
				b.text:SetJustifyH("LEFT")
				b:SetScript("OnEnter", function(self)
					ApplyTheme(self, "buttonHover")
				end)
				b:SetScript("OnLeave", function(self)
					ApplyTheme(self, "buttonBg")
				end)
				list.buttons[i] = b
			end
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", 0, -y)
			b:SetPoint("TOPRIGHT", 0, -y)
			b.icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
			local shownName = entry.keep and (T("ui.options_fd56cc99ca") .. ": " .. entry.name) or entry.name
			SetItemLabel(b.text, shownName, entry.quality)
			b:SetScript("OnClick", function()
				Choose(entry.name)
			end)
			b:Show()
			y = y + DROPDOWN_ROW_H
		end
		content:SetHeight(math.max(y, 1))

		local bodyH = math.min(DROPDOWN_MAX_H - 34, math.max(DROPDOWN_ROW_H, (#shown > 0 and #shown or 1) * DROPDOWN_ROW_H))
		if #shown > DROPDOWN_VISIBLE then
			bodyH = DROPDOWN_VISIBLE * DROPDOWN_ROW_H
		end
		list:SetWidth(width)
		list:SetHeight(bodyH + 34)
		scroll:SetVerticalScroll(0)
		local maxScroll = scroll:GetVerticalScrollRange() or 0
		slider:SetMinMaxValues(0, maxScroll)
		slider:SetValue(0)
		if maxScroll > 0 then
			slider:Show()
		else
			slider:Hide()
		end
		if #shown == 0 then
			emptyHint:SetText(
				#(rowData.candidates or {}) == 0
						and T("ui.options_5b9a431345")
					or T("ui.options_1e1b70b17c")
			)
			emptyHint:Show()
		else
			emptyHint:Hide()
		end
	end

	search:SetScript("OnTextChanged", function(self)
		RebuildList(self:GetText())
	end)

	btn:SetScript("OnClick", function()
		if openEquipDropdown == btn and list:IsShown() then
			CloseEquipDropdown()
			return
		end
		CloseEquipDropdown()
		search:SetText("")
		RebuildList("")
		list:ClearAllPoints()
		list:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
		list:Show()
		list:Raise()
		search:SetFocus()
		openEquipDropdown = btn
	end)

	RefreshButton()
	rowFrame.dropdown = btn
	return btn
end

local function PopulateEquipRemapRows(window, rows, keepSelections)
	local preserved = {}
	if keepSelections and type(window.rowData) == "table" then
		for i = 1, #window.rowData do
			local prev = window.rowData[i]
			if prev and prev.name and prev.selected then
				preserved[prev.name] = prev.selected
			end
		end
	end

	local content = window.content
	for i = 1, #(window.rows or {}) do
		window.rows[i]:Hide()
	end
	window.rows = window.rows or {}
	for i = 1, #rows do
		if preserved[rows[i].name] then
			rows[i].selected = preserved[rows[i].name]
		end
	end
	window.rowData = rows

	local ROW_H, GAP = 36, 4
	for i = 1, #rows do
		local data = rows[i]
		local row = window.rows[i]
		if not row then
			row = CreateFrame("Frame", nil, content)
			row:SetHeight(ROW_H)
			ApplyTheme(row, "dropdownBg")

			row.srcIcon = row:CreateTexture(nil, "ARTWORK")
			row.srcIcon:SetSize(28, 28)
			row.srcIcon:SetPoint("LEFT", 8, 0)

			row.srcName = MakeFontString(row, "normal")
			row.srcName:SetPoint("LEFT", row.srcIcon, "RIGHT", 8, 0)
			row.srcName:SetPoint("RIGHT", row, "CENTER", -8, 0)
			row.srcName:SetJustifyH("LEFT")

			window.rows[i] = row
		end
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 0, -((i - 1) * (ROW_H + GAP)))
		row:SetPoint("TOPRIGHT", 0, -((i - 1) * (ROW_H + GAP)))
		row.srcIcon:SetTexture(data.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
		SetItemLabel(row.srcName, data.displayName or data.name, data.quality)
		if row.dropdown then
			row.dropdown:Hide()
			if row.dropdown.list then
				row.dropdown.list:Hide()
			end
			row.dropdown:SetParent(nil)
			row.dropdown = nil
		end
		BuildEquipDropdown(row, data)
		row:Show()
	end

	local total = #rows * (ROW_H + GAP)
	content:SetHeight(math.max(total, 1))
	window.scroll:SetVerticalScroll(0)
	local maxScroll = window.scroll:GetVerticalScrollRange() or 0
	window.slider:SetMinMaxValues(0, maxScroll)
	window.slider:SetValue(0)
end

local function ShowEquipRemapDialog(data, onContinue, onCancel)
	if type(Transfer.BuildEquipRemapRows) ~= "function" then
		if onContinue then
			onContinue({})
		end
		return
	end
	local rows = Transfer.BuildEquipRemapRows(data)
	if #rows == 0 then
		if onContinue then
			onContinue({})
		end
		return
	end
	local f = EnsureEquipRemapWindow()
	f.onContinue = onContinue
	f.onCancel = onCancel
	PopulateEquipRemapRows(f, rows, false)
	f:Show()
	f:Raise()
	-- Warm item cache for icons, but keep whatever the user already picked.
	if f._iconRefresh then
		f._iconRefresh:SetScript("OnUpdate", nil)
	end
	local refresh = f._iconRefresh or CreateFrame("Frame", nil, f)
	f._iconRefresh = refresh
	local waited = 0
	refresh:SetScript("OnUpdate", function(self, elapsed)
		waited = waited + elapsed
		if waited < 0.4 then
			return
		end
		self:SetScript("OnUpdate", nil)
		if not f:IsShown() then
			return
		end
		local refreshed = Transfer.BuildEquipRemapRows(data)
		if #refreshed > 0 then
			PopulateEquipRemapRows(f, refreshed, true)
		end
	end)
end

local function runImport(window, data, selected, equipRemap)
	if Transfer.Import(data, selected, equipRemap) then
		window:Hide()
		if SarychUI.ShowReloadPopup then
			local popup = _G.SarychUIReloadPopup
			if popup and popup.accept and popup.accept.label then
				popup.accept.label:SetText(ACCEPT or "OK")
			end
			SarychUI:ShowReloadPopup(T("ui.options_4f38ea2bfd"))
		else
			SarychUI:Print(T("ui.options_4f38ea2bfd"))
		end
	end
end

local function applyImport(window)
	local data = decoded
	local selected, labels = selectedCategories(window)
	if not data or #labels == 0 then
		return
	end
	local from = type(data.character) == "string" and data.character or "?"
	local needsMacros = selected.macros or selected.actions
	local function afterRemap(remap)
		remap = type(remap) == "table" and remap or {}
		if next(remap) and Transfer.ApplyEquipRemap then
			Transfer.ApplyEquipRemap(data, remap)
		end
		local wipeMacros = selected.macros and Transfer.MacrosWillReplace and Transfer.MacrosWillReplace(data)
		ConfirmImport(from, labels, function()
			runImport(window, data, selected, remap)
		end, wipeMacros)
	end
	if needsMacros then
		ShowEquipRemapDialog(data, afterRemap, function() end)
	else
		afterRemap({})
	end
end

local function createCheck(window, index, category)
	local theme = Theme()
	local row = CreateFrame("Frame", nil, window)
	row:SetSize(COLUMN_WIDTH - 8, CHECK_LINE)
	local column, rowIndex = floor((index - 1) / ROWS), (index - 1) % ROWS
	row:SetPoint("TOPLEFT", window.summary, "BOTTOMLEFT", column * COLUMN_WIDTH, -4 - rowIndex * CHECK_LINE)
	row:EnableMouse(true)

	local box = CreateFrame("Button", nil, row)
	box:SetSize(16, 16)
	box:SetPoint("LEFT", row, "LEFT", 0, 0)
	if theme then
		theme:ApplyFlat(box, theme.colors.inputBg, theme.colors.border)
	else
		ApplyTheme(box, "inputBg")
	end

	local mark = box:CreateTexture(nil, "OVERLAY")
	mark:SetTexture("Interface\\Buttons\\WHITE8X8")
	mark:SetPoint("TOPLEFT", 3, -3)
	mark:SetPoint("BOTTOMRIGHT", -3, 3)
	if theme and theme.colors.checkOn then
		local c = theme.colors.checkOn
		mark:SetVertexColor(c[1], c[2], c[3], 1)
	else
		mark:SetVertexColor(1, 0.82, 0.2, 1)
	end
	mark:Hide()

	local label = MakeFontString(row, "normal")
	label:SetPoint("LEFT", box, "RIGHT", 6, 0)
	label:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	label:SetJustifyH("LEFT")
	label:SetText(T(category.label))
	if theme then
		theme:SetTextColor(label, "text")
	end

	row.box = box
	row.mark = mark
	row.label = label
	row._checked = false
	row._enabled = true

	local function ApplyVisual()
		if row._checked and row._enabled then
			mark:Show()
		else
			mark:Hide()
		end
	end

	function row:GetChecked()
		return self._checked
	end

	function row:SetChecked(checked)
		self._checked = checked and true or false
		ApplyVisual()
	end

	function row:IsEnabled()
		return self._enabled and 1 or 0
	end

	function row:Enable()
		self._enabled = true
		if theme then
			theme:SetTextColor(self.label, "text")
			theme:ApplyFlat(self.box, theme.colors.inputBg, theme.colors.border)
		end
		ApplyVisual()
	end

	function row:Disable()
		self._enabled = false
		self._checked = false
		if theme then
			theme:SetTextColor(self.label, "disabled")
			theme:ApplyFlat(self.box, theme.colors.inputBg, theme.colors.disabled or theme.colors.border)
		else
			self.label:SetTextColor(0.5, 0.5, 0.5, 1)
		end
		ApplyVisual()
	end

	local function Toggle()
		if not row._enabled then
			return
		end
		row:SetChecked(not row._checked)
		updateApply(window)
	end

	box:SetScript("OnClick", Toggle)
	row:SetScript("OnMouseUp", function(_, button)
		if button == "LeftButton" then
			Toggle()
		end
	end)

	SarychUI.OptionsTooltip.BindCheckbox(row)

	return row
end

local function EnsureImportWindow()
	if importWindow then
		return importWindow
	end
	local f = CreateBaseWindow("SarychUITransferImport", WINDOW_HEIGHT)
	f.heading:SetText(T("ui.options_c776efa35b"))

	local close = MakeButton(f, T("ui.options_4ae50d3073"), 96)
	close:SetPoint("BOTTOMRIGHT", -EDGE, EDGE)
	close:SetScript("OnClick", function()
		f:Hide()
	end)

	local applyButton = MakeButton(f, T("ui.options_768af67762"), 96)
	applyButton:SetPoint("RIGHT", close, "LEFT", -4, 0)
	applyButton:SetScript("OnClick", function()
		applyImport(f)
	end)
	f.apply = applyButton

	local inset, box, scroll = CreateEditBox(f, BOX_TOP, BOX_HEIGHT)
	f.box = box
	box:SetScript("OnTextChanged", function(self)
		scroll:UpdateScrollChildRect()
		updateContents(f, self:GetText())
	end)

	local summary = MakeFontString(f, "normal", "ARTWORK")
	summary:SetPoint("TOPLEFT", inset, "BOTTOMLEFT", 4, -10)
	summary:SetPoint("RIGHT", -EDGE, 0)
	summary:SetJustifyH("LEFT")
	f.summary = summary

	f.checks = {}
	for i, category in ipairs(Transfer.CATEGORIES) do
		f.checks[i] = createCheck(f, i, category)
	end

	importWindow = f
	return f
end

local function ShowExport()
	local mod = SarychUI.Transfer
	if not mod or type(mod.Export) ~= "function" then
		SarychUI:Print(T("ui.options_35f1e16c72"))
		return
	end
	local ok, text, err = pcall(mod.Export)
	if not ok then
		SarychUI:Print("|cffff5555" .. T("ui.options_b4ae6378a1") .. "|r " .. tostring(text))
		geterrorhandler()(text)
		return
	end
	if text then
		SarychUI:ShowTransferTextWindow(T("ui.options_0c7574197f"):format(UnitName("player")), text)
	else
		SarychUI:Print(err or T("ui.options_221498e745"))
	end
end

local function ShowImport(initialText)
	local ok, err = pcall(function()
		local f = EnsureImportWindow()
		SarychUI:HideTransferTextWindow()
		local text = type(initialText) == "string" and initialText or ""
		f.box:SetText(text)
		updateContents(f, text)
		f:Show()
		if text == "" then
			f.box:SetFocus()
		else
			f.box:ClearFocus()
			f.box:HighlightText(0, 0)
		end
	end)
	if not ok then
		SarychUI:Print("|cffff5555" .. T("ui.options_bc364e18b9") .. "|r " .. tostring(err))
		geterrorhandler()(err)
	end
end

local CLASS_CIRCLES = [[Interface\TargetingFrame\UI-Classes-Circles]]

local function ClassIconSpec(class)
	local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
	if not coords then
		return nil
	end
	return { texture = CLASS_CIRCLES, coords = coords }
end

local function BuildBuiltinPresetArgs(startOrder)
	local args = {}
	local presets = SarychUI.TransferBuiltinPresets
	if type(presets) ~= "table" or #presets == 0 then
		return args
	end
	args.presetsHeader = {
		type = "header",
		name = T("ui.options_7dc8a1bc9c"),
		order = startOrder,
	}
	for i = 1, #presets do
		local preset = presets[i]
		local name = preset.name or preset.key or ("preset_" .. i)
		local dateText = type(preset.date) == "string" and preset.date ~= "" and preset.date or nil
		local title = "|cffffffff" .. tostring(name) .. "|r"
		if dateText then
			title = title .. "  |cff9a9aa2" .. dateText .. "|r"
		end
		local classIcon = ClassIconSpec(preset.class)
		local specIcon = preset.specIcon
		args["preset_" .. (preset.key or i)] = {
			type = "group",
			name = "",
			order = startOrder + 10 + i,
			inline = true,
			args = {
				summary = {
					type = "description",
					name = title,
					-- Right edge: Import (fit width). Icons sit just left of it.
					suiRightIcon = specIcon,
					suiRightIcon2 = classIcon,
					suiRightIconSize = 24,
					suiRightButton = {
						name = T("ui.options_3f8c55176b"),
						desc = T("ui.options_7adc7732f4"),
						func = function()
							ShowImport(type(preset.code) == "string" and preset.code or "")
						end,
					},
					order = 1,
					width = "full",
					suiFullRow = true,
				},
			},
		}
	end
	return args
end

-----------------------------------------------------------------------
-- AceConfig options group for Profiles > Transfer
-----------------------------------------------------------------------
function SarychUI:BuildTransferOptions()
	local copyArgs = {}
	for i, category in ipairs(Transfer.CATEGORIES) do
		local key = category.key
		copyArgs["cat_" .. key] = {
			type = "toggle",
			order = i,
			name = T(category.label),
			desc = T(category.desc),
			get = function()
				return Transfer.IsExported(key)
			end,
			set = function(_, value)
				Transfer.SetExported(key, value)
			end,
		}
	end
	copyArgs.selectAll = {
		type = "execute",
		order = 100,
		name = T("ui.options_8a0c186748"),
		desc = T("ui.options_5c8bc668e7"),
		suiFullRow = true,
		suiSkipWritableProfile = true,
		func = function()
			local allOn = true
			for _, category in ipairs(Transfer.CATEGORIES) do
				if not Transfer.IsExported(category.key) then
					allOn = false
					break
				end
			end
			for _, category in ipairs(Transfer.CATEGORIES) do
				Transfer.SetExported(category.key, not allOn)
			end
			if SarychUI.NotifyProfileOptionsChanged then
				SarychUI:NotifyProfileOptionsChanged()
			elseif SarychUI.NotifySarychUIOptionsChange then
				SarychUI:NotifySarychUIOptionsChange()
			end
		end,
	}

	local args = {
		desc = {
			type = "description",
			order = 1,
			width = "full",
			name = T("ui.options_1e71b53caa"),
		},
		-- Left half: bordered title+checkboxes+button. Right half: decor icon.
		-- Title "Что скопировать" is drawn inside the left panel above the toggles.
		copyBox = {
			type = "group",
			name = T("ui.options_fcd1d7375c"),
			order = 10,
			inline = true,
			suiTwoCol = true,
			suiDecorRightHalf = true,
			suiPanelDecorIcon = [[Interface\TutorialFrame\UI-TutorialFrame-Spellbook]],
			suiPanelDecorIconSize = 200,
			args = copyArgs,
		},
		-- Export / Import outside the copy panel, one row, equal halves.
		transferActions = {
			type = "group",
			name = "",
			order = 20,
			inline = true,
			suiTwoCol = true,
			args = {
				export = {
					type = "execute",
					order = 1,
					name = T("ui.options_dd5016c829"),
					desc = T("ui.options_4b600e6ece"),
					suiSkipWritableProfile = true,
					func = ShowExport,
				},
				import = {
					type = "execute",
					order = 2,
					name = T("ui.options_3f8c55176b"),
					desc = T("ui.options_4b00f6fc87"),
					suiSkipWritableProfile = true,
					func = function()
						ShowImport("")
					end,
				},
			},
		},
	}

	local presetArgs = BuildBuiltinPresetArgs(30)
	for key, opt in pairs(presetArgs) do
		args[key] = opt
	end

	return {
		type = "group",
		name = T("ui.options_07ec2991ae"),
		order = 2,
		args = args,
	}
end
