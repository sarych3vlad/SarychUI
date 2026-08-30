-- Owner-scoped AceGUI enhancements ported from improved library versions.
-- Nothing here runs unless SarychUI:IsSarychUIOwned(frame) is true.

local function ResizeOwnedFrameTitleBar(widget)
	if not widget or not widget.titletext then
		return
	end
	local _, titlebg = widget.titletext:GetPoint(1)
	if not titlebg then
		_, titlebg = widget.titletext:GetPoint()
	end
	if titlebg and titlebg.SetWidth then
		titlebg:SetWidth((widget.titletext:GetWidth() or 0) + 10)
	end
end

function SarychUI:InstallOwnedFrameEnhancements(widget)
	if not widget or widget._sarychFrameEnhancementsInstalled then
		return
	end
	if not self:IsSarychUIOwned(widget.frame) then
		return
	end
	widget._sarychFrameEnhancementsInstalled = true
	ResizeOwnedFrameTitleBar(widget)
end

local function EnsureOwnedDropdownButtonCover(widget)
	if widget.button_cover or not widget.frame or not widget.button then
		return widget.button_cover
	end
	local button_cover = CreateFrame("Button", nil, widget.frame)
	widget.button_cover = button_cover
	button_cover.obj = widget
	button_cover:SetPoint("TOPLEFT", widget.frame, "BOTTOMLEFT", 0, 25)
	button_cover:SetPoint("BOTTOMRIGHT", widget.frame, "BOTTOMRIGHT")
	local toggle = widget.button:GetScript("OnClick")
	if toggle then
		button_cover:SetScript("OnClick", toggle)
	end
	return button_cover
end

local function InstallOwnedDropdownHoverHighlight(widget)
	local function onEnter(this)
		local obj = this.obj
		if not obj or not SarychUI:IsSarychUIOwned(obj.frame) then
			return
		end
		if obj.button and obj.button.LockHighlight then
			obj.button:LockHighlight()
		end
		obj:Fire("OnEnter")
	end

	local function onLeave(this)
		local obj = this.obj
		if not obj or not SarychUI:IsSarychUIOwned(obj.frame) then
			return
		end
		if obj.button and obj.button.UnlockHighlight then
			obj.button:UnlockHighlight()
		end
		obj:Fire("OnLeave")
	end

	if widget.button then
		widget.button:SetScript("OnEnter", onEnter)
		widget.button:SetScript("OnLeave", onLeave)
	end

	local cover = EnsureOwnedDropdownButtonCover(widget)
	if cover then
		cover:SetScript("OnEnter", onEnter)
		cover:SetScript("OnLeave", onLeave)
	end
end

local function ApplyOwnedDropdownLabelLayout(widget, text)
	if not widget.dropdown then
		return
	end
	if text and text ~= "" then
		widget.dropdown:SetPoint("TOPLEFT", widget.frame, "TOPLEFT", -15, -14)
		if widget.SetHeight then
			widget:SetHeight(40)
		else
			widget.frame:SetHeight(40)
		end
		widget.alignoffset = 26
	else
		widget.dropdown:SetPoint("TOPLEFT", widget.frame, "TOPLEFT", -15, 0)
		if widget.SetHeight then
			widget:SetHeight(26)
		else
			widget.frame:SetHeight(26)
		end
		widget.alignoffset = 12
	end
end

function SarychUI:InstallOwnedDropdownEnhancements(widget)
	if not widget or widget._sarychDropdownEnhancementsInstalled then
		return
	end
	if not self:IsSarychUIOwned(widget.frame) then
		return
	end
	widget._sarychDropdownEnhancementsInstalled = true

	InstallOwnedDropdownHoverHighlight(widget)

	if widget.SetLabel then
		local originalSetLabel = widget.SetLabel
		widget.SetLabel = function(self, text)
			if not SarychUI:IsSarychUIOwned(self.frame) then
				return originalSetLabel(self, text)
			end
			if text and text ~= "" then
				self.label:SetText(text)
				self.label:Show()
			else
				self.label:SetText("")
				self.label:Hide()
			end
			ApplyOwnedDropdownLabelLayout(self, text)
		end
	end

	if widget.SetDisabled then
		local originalSetDisabled = widget.SetDisabled
		widget.SetDisabled = function(self, disabled)
			originalSetDisabled(self, disabled)
			if not SarychUI:IsSarychUIOwned(self.frame) then
				return
			end
			if self.button_cover then
				if disabled then
					self.button_cover:Disable()
				else
					self.button_cover:Enable()
				end
			end
		end
	end

	if widget.dropdown and widget.label then
		ApplyOwnedDropdownLabelLayout(widget, widget.label:GetText())
	end
end

function SarychUI:InstallOwnedCheckBoxEnhancements(widget)
	if not widget or widget._sarychCheckBoxEnhancementsInstalled then
		return
	end
	if not self:IsSarychUIOwned(widget.frame) then
		return
	end
	widget._sarychCheckBoxEnhancementsInstalled = true

	if widget.SetDisabled then
		local originalSetDisabled = widget.SetDisabled
		widget.SetDisabled = function(self, disabled)
			originalSetDisabled(self, disabled)
			if not SarychUI:IsSarychUIOwned(self.frame) then
				return
			end
			if self.desc then
				if disabled then
					self.desc:SetTextColor(0.5, 0.5, 0.5)
				else
					self.desc:SetTextColor(1, 1, 1)
				end
			end
		end
	end

	if widget.SetDescription then
		local originalSetDescription = widget.SetDescription
		widget.SetDescription = function(self, desc)
			originalSetDescription(self, desc)
			if not SarychUI:IsSarychUIOwned(self.frame) then
				return
			end
			if self.desc then
				self.desc:SetPoint("RIGHT", self.frame, "RIGHT", -30, 0)
				if desc and desc ~= "" then
					local height = self.desc.GetStringHeight and self.desc:GetStringHeight() or self.desc:GetHeight()
					self:SetHeight(28 + height)
				end
			end
		end
	end
end

function SarychUI:InstallOwnedButtonEnhancements(widget)
	if not widget or widget._sarychButtonEnhancementsInstalled then
		return
	end
	if not self:IsSarychUIOwned(widget.frame) then
		return
	end
	widget._sarychButtonEnhancementsInstalled = true

	if widget.SetAutoWidth then
		return
	end

	widget.autoWidth = widget.autoWidth or false

	widget.SetAutoWidth = function(self, autoWidth)
		self.autoWidth = autoWidth
		if self.autoWidth and self.text and self.SetWidth then
			self:SetWidth(self.text:GetStringWidth() + 30)
		end
	end

	if widget.SetText then
		local originalSetText = widget.SetText
		widget.SetText = function(self, text)
			originalSetText(self, text)
			if SarychUI:IsSarychUIOwned(self.frame) and self.autoWidth and self.SetWidth and self.text then
				self:SetWidth(self.text:GetStringWidth() + 30)
			end
		end
	end
end

function SarychUI:InstallOwnedEditBoxEnhancements(widget)
	if not widget or widget._sarychEditBoxEnhancementsInstalled then
		return
	end
	if not self:IsSarychUIOwned(widget.frame) then
		return
	end
	widget._sarychEditBoxEnhancementsInstalled = true

	if widget.editbox and widget.editbox.HookScript and not widget.editbox._sarychOwnedReleaseClearFocus then
		widget.editbox._sarychOwnedReleaseClearFocus = true
		local originalOnRelease = widget.OnRelease
		widget.OnRelease = function(self)
			if SarychUI:IsSarychUIOwned(self.frame) and self.editbox and self.editbox.ClearFocus then
				self.editbox:ClearFocus()
			end
			if originalOnRelease then
				originalOnRelease(self)
			end
		end
	end
end
