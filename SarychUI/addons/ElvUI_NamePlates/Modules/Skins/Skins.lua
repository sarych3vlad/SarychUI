--[[
	Minimal Skins module — ports just enough of ElvUI's Skins + Ace3 skinning so the
	standalone options window looks identical to ElvUI's config window.
	Based on ElvUI Modules/Skins/Skins.lua and Modules/Skins/Addons/Ace3.lua (Elv, Bunny).
]]
local E, L = unpack(_G.SarychUI_ElvUI_NamePlates)
local S = E:NewModule("Skins", "AceHook-3.0")

local _G = _G
local unpack, pairs, ipairs, select = unpack, pairs, ipairs, select
local find, format, lower = string.find, string.format, string.lower
local hooksecurefunc = hooksecurefunc

S.ArrowRotation = {
	["up"] = 0,
	["down"] = 3.14,
	["left"] = 1.57,
	["right"] = -1.57,
}

-- Minimal ElvUI Skins API for third-party hooks (e.g. WCollections) and Details AceGUI widgets.
S.skinCallbacks = S.skinCallbacks or {}

function S:AddCallback(name, func)
	if type(func) == "function" then
		self.skinCallbacks[name] = func
	end
end

-----------------------------------------------------------------------
-- Generic skin helpers (ported from ElvUI Skins.lua)
-----------------------------------------------------------------------
function S:SetModifiedBackdrop()
	if self.backdrop then self = self.backdrop end
	self:SetBackdropBorderColor(unpack(E.media.rgbvaluecolor))
end

function S:SetOriginalBackdrop()
	if self.backdrop then self = self.backdrop end
	self:SetBackdropBorderColor(unpack(E.media.bordercolor))
end

function S:HandleButton(button, strip, _, useCreateBackdrop, noSetTemplate)
	if button.isSkinned then return end

	local buttonName = button.GetName and button:GetName()
	if buttonName then
		local left = _G[buttonName.."Left"]
		local middle = _G[buttonName.."Middle"]
		local right = _G[buttonName.."Right"]
		if left then left:SetAlpha(0) end
		if middle then middle:SetAlpha(0) end
		if right then right:SetAlpha(0) end
	end

	if button.Left then button.Left:SetAlpha(0) end
	if button.Middle then button.Middle:SetAlpha(0) end
	if button.Right then button.Right:SetAlpha(0) end

	if button.SetNormalTexture then button:SetNormalTexture("") end
	if button.SetHighlightTexture then button:SetHighlightTexture("") end
	if button.SetPushedTexture then button:SetPushedTexture("") end
	if button.SetDisabledTexture then button:SetDisabledTexture("") end

	if strip then button:StripTextures() end

	if useCreateBackdrop then
		button:CreateBackdrop(nil, true)
	elseif not noSetTemplate then
		button:SetTemplate(nil, true)
	end

	button:HookScript("OnEnter", S.SetModifiedBackdrop)
	button:HookScript("OnLeave", S.SetOriginalBackdrop)

	button.isSkinned = true
end

function S:HandleScrollBar(frame, horizontal)
	if frame.backdrop then return end

	local parent = frame:GetParent()
	local frameName = frame.GetName and frame:GetName()
	local scrollUpButton, scrollDownButton
	local thumb = frame.thumbTexture or (frame.GetThumbTexture and frame:GetThumbTexture()) or (frameName and _G[format("%s%s", frameName, "ThumbTexture")])

	if frameName then
		if not horizontal then
			scrollUpButton = parent.scrollUp or _G[format("%s%s", frameName, "ScrollUpButton")] or _G[format("%s%s", frameName, "UpButton")] or _G[format("%s%s", frameName, "ScrollUp")]
			scrollDownButton = parent.scrollDown or _G[format("%s%s", frameName, "ScrollDownButton")] or _G[format("%s%s", frameName, "DownButton")] or _G[format("%s%s", frameName, "ScrollDown")]
		else
			scrollUpButton = _G[format("%s%s", frameName, "ScrollLeftButton")] or _G[format("%s%s", frameName, "LeftButton")] or _G[format("%s%s", frameName, "ScrollLeft")]
			scrollDownButton = _G[format("%s%s", frameName, "ScrollRightButton")] or _G[format("%s%s", frameName, "RightButton")] or _G[format("%s%s", frameName, "ScrollRight")]
		end
	end

	if not horizontal then frame:Width(18) else frame:Height(18) end

	local frameLevel = frame:GetFrameLevel()
	frame:StripTextures()
	frame:CreateBackdrop()
	frame.backdrop:SetAllPoints()
	frame.backdrop:SetFrameLevel(frameLevel)

	if scrollUpButton then
		if not horizontal then
			scrollUpButton:Point("BOTTOM", frame, "TOP", 0, 1)
			S:HandleNextPrevButton(scrollUpButton, "up")
		else
			scrollUpButton:Point("RIGHT", frame, "LEFT", -1, 0)
			S:HandleNextPrevButton(scrollUpButton, "left")
		end
	end

	if scrollDownButton then
		if not horizontal then
			scrollDownButton:Point("TOP", frame, "BOTTOM", 0, -1)
			S:HandleNextPrevButton(scrollDownButton, "down")
		else
			scrollDownButton:Point("LEFT", frame, "RIGHT", 1, 0)
			S:HandleNextPrevButton(scrollDownButton, "right")
		end
	end

	if thumb and not thumb.backdrop then
		if not horizontal then thumb:Size(18, 22) else thumb:Size(22, 18) end
		thumb:SetTexture()
		thumb:CreateBackdrop(nil, true, true)
		thumb.backdrop:SetFrameLevel(frameLevel + 1)
		thumb.backdrop:SetBackdropColor(0.6, 0.6, 0.6)
		thumb.backdrop:Point("TOPLEFT", thumb, "TOPLEFT", 2, -2)
		thumb.backdrop:Point("BOTTOMRIGHT", thumb, "BOTTOMRIGHT", -2, 2)
		if not frame.thumbTexture then frame.thumbTexture = thumb end
	end
end

function S:HandleEditBox(frame)
	if frame.backdrop then return end

	frame:CreateBackdrop()
	frame.backdrop:SetFrameLevel(frame:GetFrameLevel())

	local EditBoxName = frame.GetName and frame:GetName()
	if EditBoxName then
		if _G[EditBoxName.."Left"] then _G[EditBoxName.."Left"]:SetAlpha(0) end
		if _G[EditBoxName.."Middle"] then _G[EditBoxName.."Middle"]:SetAlpha(0) end
		if _G[EditBoxName.."Right"] then _G[EditBoxName.."Right"]:SetAlpha(0) end
		if _G[EditBoxName.."Mid"] then _G[EditBoxName.."Mid"]:SetAlpha(0) end
	end
end

local handleCloseButtonOnEnter = function(btn) if btn.Texture then btn.Texture:SetVertexColor(unpack(E.media.rgbvaluecolor)) end end
local handleCloseButtonOnLeave = function(btn) if btn.Texture then btn.Texture:SetVertexColor(1, 1, 1) end end

function S:HandleCloseButton(f, point)
	f:StripTextures()

	if f:GetNormalTexture() then f:SetNormalTexture("") f.SetNormalTexture = E.noop end
	if f:GetPushedTexture() then f:SetPushedTexture("") f.SetPushedTexture = E.noop end

	if not f.Texture then
		f.Texture = f:CreateTexture(nil, "OVERLAY")
		f.Texture:Point("CENTER")
		f.Texture:SetTexture(E.Media.Textures.Close)
		f.Texture:Size(12, 12)
		f:HookScript("OnEnter", handleCloseButtonOnEnter)
		f:HookScript("OnLeave", handleCloseButtonOnLeave)
		f:SetHitRectInsets(7, 6, 7, 6)
	end

	if point then
		f:Point("TOPRIGHT", point, "TOPRIGHT", 2, 3)
	end
end

local sliderOnDisable = function(self) self:GetThumbTexture():SetVertexColor(0.6, 0.6, 0.6, 0.8) end
local sliderOnEnable = function(self) self:GetThumbTexture():SetVertexColor(1, 0.82, 0, 0.8) end

function S:HandleSliderFrame(frame)
	local orientation = frame:GetOrientation()

	frame:StripTextures()
	frame:SetTemplate()
	frame:SetThumbTexture(E.Media.Textures.Melli)

	local thumb = frame:GetThumbTexture()
	thumb:SetVertexColor(1, 0.82, 0, 0.8)
	thumb:Size(10)

	frame:HookScript("OnDisable", sliderOnDisable)
	frame:HookScript("OnEnable", sliderOnEnable)

	if orientation == "VERTICAL" then
		frame:Width(12)
	else
		frame:Height(12)
		for i = 1, frame:GetNumRegions() do
			local region = select(i, frame:GetRegions())
			if region and region:IsObjectType("FontString") then
				local point, anchor, anchorPoint, x, y = region:GetPoint()
				if anchorPoint and find(anchorPoint, "BOTTOM") then
					region:Point(point, anchor, anchorPoint, x, y - 4)
				end
			end
		end
	end
end

local defaultArrowColor = {1, 1, 1}
function S:HandleNextPrevButton(btn, arrowDir, color, noBackdrop)
	if btn.isSkinned then return end

	if not arrowDir then
		arrowDir = "down"
		local ButtonName = btn:GetName() and lower(btn:GetName())
		if ButtonName then
			if (find(ButtonName, "left") or find(ButtonName, "prev") or find(ButtonName, "decrement")) then
				arrowDir = "left"
			elseif (find(ButtonName, "right") or find(ButtonName, "next") or find(ButtonName, "increment")) then
				arrowDir = "right"
			elseif (find(ButtonName, "scrollup") or find(ButtonName, "upbutton") or find(ButtonName, "top") or find(ButtonName, "promote")) then
				arrowDir = "up"
			end
		end
	end

	btn:SetHitRectInsets(0, 0, 0, 0)
	btn:StripTextures()
	if not noBackdrop then
		S:HandleButton(btn)
	end

	btn:SetNormalTexture(E.Media.Textures.ArrowUp)
	btn:SetPushedTexture(E.Media.Textures.ArrowUp)
	btn:SetDisabledTexture(E.Media.Textures.ArrowUp)

	local Normal, Disabled, Pushed = btn:GetNormalTexture(), btn:GetDisabledTexture(), btn:GetPushedTexture()

	if noBackdrop then
		btn:Size(20, 20)
		Disabled:SetVertexColor(.5, .5, .5)
		btn.Texture = Normal
		btn:HookScript("OnEnter", handleCloseButtonOnEnter)
		btn:HookScript("OnLeave", handleCloseButtonOnLeave)
	else
		btn:Size(18, 18)
		Disabled:SetVertexColor(.3, .3, .3)
	end

	Normal:SetInside()
	Pushed:SetInside()
	Disabled:SetInside()

	Normal:SetTexCoord(0, 1, 0, 1)
	Pushed:SetTexCoord(0, 1, 0, 1)
	Disabled:SetTexCoord(0, 1, 0, 1)

	Normal:SetRotation(S.ArrowRotation[arrowDir])
	Pushed:SetRotation(S.ArrowRotation[arrowDir])
	Disabled:SetRotation(S.ArrowRotation[arrowDir])

	Normal:SetVertexColor(unpack(color or defaultArrowColor))

	btn.isSkinned = true
end

-----------------------------------------------------------------------
-- Ace3 skinning (ported from ElvUI Modules/Skins/Addons/Ace3.lua)
--
-- Embedded: hooks ONLY AceGUI-3.0-ENP (full isolated lib for ENP options).
-- Shared AceGUI-3.0 (WeakAuras etc.) is never hooked or skinned.
-----------------------------------------------------------------------
local oldRegisterAsWidget, oldRegisterAsContainer
local minorGUI, minorConfigDialog = 1, 1

local function Ace3PrivateEnabled()
	return not E.private or not E.private.skins or not E.private.skins.ace3
		or E.private.skins.ace3.enable ~= false
end

function S:IsElvUINamePlatesOptionsFrame(frame)
	if not frame then return false end
	if rawget(frame, "__SarychUI_ENPOptionsRoot") == true then return true end
	if rawget(frame, "__SarychUIOptionsRoot") == true
		or rawget(frame, "SarychUIOwnedRoot") == true then
		return false
	end
	local f, depth = frame, 0
	while f and depth < 64 do
		if rawget(f, "__SarychUI_ENPOptionsRoot") == true then return true end
		if rawget(f, "__SarychUIOptionsRoot") == true
			or rawget(f, "SarychUIOwnedRoot") == true then
			return false
		end
		f = f.GetParent and f:GetParent() or nil
		depth = depth + 1
	end
	return false
end

local ENP_OPTIONS_APP = "SarychUI_ElvUI_NamePlates"

-- ENP AceGUI pool is fully isolated — safe to skin every widget from that lib.
local function skinEnabled(widget)
	if not Ace3PrivateEnabled() then return false end
	return true
end

function S:MarkENPOptionsRoot(frame)
	if frame then
		frame.__SarychUI_ENPOptionsRoot = true
	end
end

function S:HookAceConfigDialogFeedGroup(ACD)
	if not ACD or ACD._enpSkinFeedHooked then return end
	ACD._enpSkinFeedHooked = true
	local oldFeedGroup = ACD.FeedGroup
	if type(oldFeedGroup) ~= "function" then return end

	ACD.FeedGroup = function(dialog, appName, ...)
		local isENP = (appName == ENP_OPTIONS_APP)
		if isENP and dialog.OpenFrames and dialog.OpenFrames[ENP_OPTIONS_APP] then
			local open = dialog.OpenFrames[ENP_OPTIONS_APP]
			if open and open.frame then
				open.frame.__SarychUI_ENPOptionsRoot = true
			end
		end
		return oldFeedGroup(dialog, appName, ...)
	end
end

function S:Ace3_SkinDropdownPullout()
	if self and self.obj then
		if not Ace3PrivateEnabled() then
			return
		end

		local pullout = self.obj.pullout
		local dropdown = self.obj.dropdown

		if pullout and pullout.frame then
			if pullout.frame.template and pullout.slider and pullout.slider.template then return end
			if not pullout.frame.template then
				pullout.frame:SetTemplate("Default", true)
			end
			if pullout.slider and not pullout.slider.template then
				pullout.slider:SetTemplate("Default")
				pullout.slider:Point("TOPRIGHT", pullout.frame, "TOPRIGHT", -10, -10)
				pullout.slider:Point("BOTTOMRIGHT", pullout.frame, "BOTTOMRIGHT", -10, 10)
				if pullout.slider:GetThumbTexture() then
					pullout.slider:SetThumbTexture(E.Media.Textures.Melli)
					pullout.slider:GetThumbTexture():SetVertexColor(1, 0.82, 0, 0.8)
					pullout.slider:GetThumbTexture():Size(10, 14)
				end
			end
		elseif dropdown then
			dropdown:SetTemplate("Default", true)
			if dropdown.slider then
				dropdown.slider:SetTemplate("Default")
				dropdown.slider:Point("TOPRIGHT", dropdown, "TOPRIGHT", -10, -10)
				dropdown.slider:Point("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", -10, 10)
				if dropdown.slider:GetThumbTexture() then
					dropdown.slider:SetThumbTexture(E.Media.Textures.Melli)
					dropdown.slider:GetThumbTexture():SetVertexColor(1, 0.82, 0, 0.8)
					dropdown.slider:GetThumbTexture():Size(10, 14)
				end
			end
		end
	end
end

function S:Ace3_CheckBoxIsEnableSwitch(widget)
	local text = widget.text and widget.text:GetText()
	if text and S.Ace3_L then
		return (text == S.Ace3_L.Enable) or (text == S.Ace3_L.GREEN_ENABLE) or (text == S.Ace3_L.RED_ENABLE)
	end
end

function S:Ace3_RegisterAsWidget(widget)
	if not skinEnabled(widget) then return oldRegisterAsWidget(self, widget) end

	local TYPE = widget.type
	if TYPE == "CheckBox" then
		local check = widget.check
		local checkbg = widget.checkbg
		local highlight = widget.highlight

		checkbg:CreateBackdrop()
		checkbg.backdrop:SetInside(widget.checkbg, 4, 4)
		checkbg.backdrop:SetFrameLevel(widget.checkbg.backdrop:GetFrameLevel() + 1)
		checkbg:SetTexture()
		checkbg.SetTexture = E.noop

		check:SetParent(checkbg.backdrop)
		highlight:SetTexture()
		highlight.SetTexture = E.noop

		if E.private.skins.checkBoxSkin then
			checkbg.backdrop:SetInside(widget.checkbg, 5, 5)
			check:SetTexture(E.Media.Textures.Melli)
			check.SetTexture = E.noop
			check:SetInside(widget.checkbg.backdrop)

			hooksecurefunc(check, "SetDesaturated", function(chk, value)
				if value == true then chk:SetDesaturated(false) end
			end)

			hooksecurefunc(widget, "SetValue", function(w, value)
				local isSwitch = S:Ace3_CheckBoxIsEnableSwitch(w)
				if value then
					if isSwitch then check:SetVertexColor(0.2, 1.0, 0.2, 1.0)
					else check:SetVertexColor(1, 0.82, 0, 0.8) end
				elseif w.tristate and value == nil then
					check:SetVertexColor(0.6, 0.6, 0.6, 0.8)
				end
			end)
		else
			check:SetOutside(widget.checkbg.backdrop, 3, 3)
		end
	elseif TYPE == "Dropdown" then
		local frame = widget.dropdown
		local button = widget.button
		local text = widget.text
		frame:StripTextures()

		S:HandleNextPrevButton(button, nil, {1, 0.8, 0})

		if not frame.backdrop then frame:CreateBackdrop() end
		frame.backdrop:Point("TOPLEFT", 15, -2)
		frame.backdrop:Point("BOTTOMRIGHT", -21, 0)

		widget.label:ClearAllPoints()
		widget.label:Point("BOTTOMLEFT", frame.backdrop, "TOPLEFT", 2, 0)

		button:ClearAllPoints()
		button:Point("TOPLEFT", frame.backdrop, "TOPRIGHT", -22, -2)
		button:Point("BOTTOMRIGHT", frame.backdrop, "BOTTOMRIGHT", -2, 2)
		button:SetParent(frame.backdrop)

		text:ClearAllPoints()
		text:SetJustifyH("RIGHT")
		text:Point("RIGHT", button, "LEFT", -3, 0)
		text:Point("LEFT", frame.backdrop, "LEFT", 2, 0)
		text:SetParent(frame.backdrop)
	elseif TYPE == "EditBox" then
		local frame = widget.editbox
		local button = widget.button
		S:HandleEditBox(frame)
		S:HandleButton(button)

		button:Point("RIGHT", frame.backdrop, "RIGHT", -2, 0)

		frame.backdrop:Point("TOPLEFT", 0, -2)
		frame.backdrop:Point("BOTTOMRIGHT", -1, 0)
		frame.backdrop:SetParent(widget.frame)
		frame:SetParent(frame.backdrop)
	elseif TYPE == "Button" or TYPE == "Button-ElvUI" then
		local frame = widget.frame
		S:HandleButton(frame, true, nil, true)
		frame.backdrop:SetInside()
		widget.text:SetParent(frame.backdrop)
	elseif TYPE == "Slider" or TYPE == "Slider-ElvUI" then
		local frame = widget.slider
		local editbox = widget.editbox
		local lowtext = widget.lowtext
		local hightext = widget.hightext

		S:HandleSliderFrame(frame)

		editbox:SetTemplate()
		editbox:Height(15)
		editbox:Point("TOP", frame, "BOTTOM", 0, -1)

		lowtext:Point("TOPLEFT", frame, "BOTTOMLEFT", 2, -2)
		hightext:Point("TOPRIGHT", frame, "BOTTOMRIGHT", -2, -2)

		hooksecurefunc(widget, "SetDisabled", function(w, disabled)
			local thumbTex = w.slider:GetThumbTexture()
			if disabled then thumbTex:SetVertexColor(0.6, 0.6, 0.6, 0.8)
			else thumbTex:SetVertexColor(1, 0.82, 0, 0.8) end
		end)
	elseif (TYPE == "ColorPicker" or TYPE == "ColorPicker-ElvUI") then
		local frame = widget.frame
		local colorSwatch = widget.colorSwatch

		if not frame.backdrop then frame:CreateBackdrop() end
		frame.backdrop:Size(24, 16)
		frame.backdrop:ClearAllPoints()
		frame.backdrop:Point("LEFT", frame, "LEFT", 4, 0)
		frame.backdrop:SetBackdropColor(0, 0, 0, 0)
		frame.backdrop.SetBackdropColor = E.noop

		colorSwatch:SetTexture(E.media.blankTex)
		colorSwatch:ClearAllPoints()
		colorSwatch:SetParent(frame.backdrop)
		colorSwatch:SetInside(frame.backdrop)

		if colorSwatch.background then colorSwatch.background:SetTexture(0, 0, 0, 0) end
		if colorSwatch.checkers then
			colorSwatch.checkers:ClearAllPoints()
			colorSwatch.checkers:SetDrawLayer("ARTWORK")
			colorSwatch.checkers:SetParent(frame.backdrop)
			colorSwatch.checkers:SetInside(frame.backdrop)
		end
	elseif TYPE == "LSM30_Font" or TYPE == "LSM30_Sound" or TYPE == "LSM30_Border" or TYPE == "LSM30_Background" or TYPE == "LSM30_Statusbar" then
		local frame = widget.frame
		local button = frame.dropButton
		local text = frame.text

		frame:StripTextures()

		S:HandleNextPrevButton(button, nil, {1, 0.8, 0})

		if not frame.backdrop then
			frame:CreateBackdrop()
		end

		frame.label:ClearAllPoints()
		frame.label:Point("BOTTOMLEFT", frame.backdrop, "TOPLEFT", 2, 0)

		text:ClearAllPoints()
		text:Point("RIGHT", button, "LEFT", -2, 0)
		text:Point("LEFT", frame.backdrop, "LEFT", 2, 0)

		button:ClearAllPoints()
		button:Point("TOPLEFT", frame.backdrop, "TOPRIGHT", -22, -2)
		button:Point("BOTTOMRIGHT", frame.backdrop, "BOTTOMRIGHT", -2, 2)

		frame.backdrop:Point("TOPLEFT", 0, -21)
		frame.backdrop:Point("BOTTOMRIGHT", -4, -1)

		if TYPE == "LSM30_Sound" then
			widget.soundbutton:SetParent(frame.backdrop)
			widget.soundbutton:ClearAllPoints()
			widget.soundbutton:Point("LEFT", frame.backdrop, "LEFT", 2, 0)
		elseif TYPE == "LSM30_Statusbar" then
			widget.bar:SetParent(frame.backdrop)
			widget.bar:ClearAllPoints()
			widget.bar:Point("TOPLEFT", frame.backdrop, "TOPLEFT", 2, -2)
			widget.bar:Point("BOTTOMRIGHT", button, "BOTTOMLEFT", -1, 0)
		end

		button:SetParent(frame.backdrop)
		text:SetParent(frame.backdrop)

		button:HookScript("OnClick", S.Ace3_SkinDropdownPullout)
	elseif TYPE == "Icon" then
		widget.frame:StripTextures()
	elseif TYPE == "Dropdown-Pullout" then
		local pullout = widget
		if pullout.frame then pullout.frame:SetTemplate(nil, true)
		else pullout:SetTemplate(nil, true) end
		if pullout.slider then
			pullout.slider:SetTemplate()
			pullout.slider:SetThumbTexture(E.Media.Textures.White8x8)
			pullout.slider:GetThumbTexture():SetVertexColor(1, .82, 0, 0.8)
		end
	end

	return oldRegisterAsWidget(self, widget)
end

function S:Ace3_RegisterAsContainer(widget)
	if not skinEnabled(widget) then return oldRegisterAsContainer(self, widget) end

	local TYPE = widget.type
	if TYPE == "ScrollFrame" then
		S:HandleScrollBar(widget.scrollbar)
		widget.scrollbar:Point("TOPLEFT", widget.scrollframe, "TOPRIGHT", 8, -16)
		widget.scrollbar:Point("BOTTOMLEFT", widget.scrollframe, "BOTTOMRIGHT", 8, 16)
	elseif TYPE == "InlineGroup" or TYPE == "TreeGroup" or TYPE == "TabGroup" or TYPE == "Frame" or TYPE == "DropdownGroup" or TYPE == "Window" then
		local frame = widget.content:GetParent()
		if TYPE == "Frame" then
			frame:StripTextures()
			for i = 1, frame:GetNumChildren() do
				local child = select(i, frame:GetChildren())
				if child:IsObjectType("Button") and child:GetText() then
					S:HandleButton(child)
				else
					child:StripTextures()
				end
			end
		elseif TYPE == "Window" then
			frame:StripTextures()
			if frame.obj and frame.obj.closebutton then
				S:HandleCloseButton(frame.obj.closebutton)
			end
		end

		if TYPE == "InlineGroup" then
			frame:SetTemplate("Transparent")
			frame.ignoreBackdropColors = true
			frame:SetBackdropColor(0, 0, 0, 0.25)
		else
			frame:SetTemplate("Transparent")
		end

		if TYPE == "TreeGroup" and widget.treeframe then
			widget.treeframe:SetTemplate("Transparent")
			frame:Point("TOPLEFT", widget.treeframe, "TOPRIGHT", 1, 0)

			if not widget._enpRefreshTreeHooked then
				widget._enpRefreshTreeHooked = true
				local oldRefreshTree = widget.RefreshTree
				widget.RefreshTree = function(wdg, scrollToSelection)
					if wdg._enpRefreshingTree then
						return oldRefreshTree(wdg, scrollToSelection)
					end
					wdg._enpRefreshingTree = true
					oldRefreshTree(wdg, scrollToSelection)
					wdg._enpRefreshingTree = nil

					if not wdg.tree then return end
					local status = wdg.status or wdg.localstatus
					if not status then return end

					local offset = status.scrollvalue
					if type(offset) ~= "number" then
						offset = 0
						status.scrollvalue = 0
					end

					local groupstatus = status.groups
					if not groupstatus then return end

					local lines = wdg.lines
					local buttons = wdg.buttons
					if not lines or not buttons then return end

					for btnIndex = 1, #buttons do
						local button = buttons[btnIndex]
						if not button or not button:IsShown() then
							break
						end
						local line = lines[offset + btnIndex]
						if not line or not button.highlight then
							break
						end

						button.highlight:SetTexture(E.Media.Textures.Highlight)
						button.highlight:SetVertexColor(1, 0.82, 0, 0.35)
						button.highlight:SetPoint("TOPLEFT", 0, 0)
						button.highlight:Point("BOTTOMRIGHT", 0, 1)

						button.toggle:SetHighlightTexture("")

						if groupstatus[line.uniquevalue] then
							button.toggle:SetNormalTexture(E.Media.Textures.Minus)
							button.toggle:SetPushedTexture(E.Media.Textures.Minus)
						else
							button.toggle:SetNormalTexture(E.Media.Textures.Plus)
							button.toggle:SetPushedTexture(E.Media.Textures.Plus)
						end
					end
				end
			end
		end

		if TYPE == "TabGroup" then
			local oldCreateTab = widget.CreateTab
			widget.CreateTab = function(wdg, id)
				local tab = oldCreateTab(wdg, id)
				tab:StripTextures()
				tab:CreateBackdrop("Transparent")
				tab.backdrop:Point("TOPLEFT", 10, -3)
				tab.backdrop:Point("BOTTOMRIGHT", -10, 0)
				tab:SetHitRectInsets(10, 10, 3, 0)
				return tab
			end
		end

		if widget.scrollbar then
			S:HandleScrollBar(widget.scrollbar)
			widget.scrollbar:Point("TOPRIGHT", -4, -23)
			widget.scrollbar:Point("BOTTOMRIGHT", -4, 23)
		end
	elseif TYPE == "SimpleGroup" then
		local frame = widget.content:GetParent()
		frame:SetTemplate("Transparent", nil, true)
		frame.ignoreBackdropColors = true
		frame:SetBackdropColor(0, 0, 0, 0.25)
	end

	return oldRegisterAsContainer(self, widget)
end

function S:Ace3_StyleTooltip()
	if not self then return end
	self:SetTemplate("Transparent", nil, true)
end

function S:Ace3_SkinTooltip(lib, minor)
	if not lib or (minor and minor < minorConfigDialog) then return end

	if lib.tooltip and not S:IsHooked(lib.tooltip, "OnShow") then
		S:SecureHookScript(lib.tooltip, "OnShow", S.Ace3_StyleTooltip)
	end

	if lib.popup and not lib.popup.template then
		lib.popup:SetTemplate("Transparent")
		local child = lib.popup.GetChildren and lib.popup:GetChildren()
		if child and child.StripTextures then child:StripTextures() end
		if lib.popup.accept then S:HandleButton(lib.popup.accept, true) end
		if lib.popup.cancel then S:HandleButton(lib.popup.cancel, true) end
	end
end

function S:HookAce3(lib, minor)
	if not lib or (not minor or minor < minorGUI) then return end

	if not S.Ace3_L then
		S.Ace3_L = {
			Enable = L["Enable"],
			GREEN_ENABLE = "|cff33ff33"..L["Enable"].."|r",
			RED_ENABLE = "|cffff3333"..L["Enable"].."|r",
		}
	end

	-- Never hook shared AceGUI-3.0 — that poisons WeakAuras after ENP options.
	if E.embeddedInSarychUI and lib == LibStub("AceGUI-3.0", true) then
		return
	end

	if lib.RegisterAsWidget ~= S.Ace3_RegisterAsWidget then
		oldRegisterAsWidget = lib.RegisterAsWidget
		lib.RegisterAsWidget = S.Ace3_RegisterAsWidget
	end

	if lib.RegisterAsContainer ~= S.Ace3_RegisterAsContainer then
		oldRegisterAsContainer = lib.RegisterAsContainer
		lib.RegisterAsContainer = S.Ace3_RegisterAsContainer
	end

	S:Ace3_SkinTooltip(lib)
end

function S:EnsureAce3Hooks()
	local enp = LibStub and LibStub("AceGUI-3.0-ENP", true)
	if _G.SarychUI_ENP_EnsurePrivateAceGUI then
		enp = _G.SarychUI_ENP_EnsurePrivateAceGUI() or enp
	end

	if E.embeddedInSarychUI then
		if enp then
			E.Libs = E.Libs or {}
			E.Libs.AceGUI = enp
			E.LibsMinor = E.LibsMinor or {}
			E.LibsMinor.AceGUI = (LibStub.minors and LibStub.minors["AceGUI-3.0-ENP"]) or 33
			self:HookAce3(enp, E.LibsMinor.AceGUI)
		end
		local ACD = E.Libs and E.Libs.AceConfigDialog
		if ACD then
			self:HookAceConfigDialogFeedGroup(ACD)
		end
		if type(_G.SarychUI_ENP_RegisterColorPickerElvUI) == "function" then
			_G.SarychUI_ENP_RegisterColorPickerElvUI()
		end
		return
	end

	-- Standalone ElvUI_NamePlates: use public AceGUI like stock ElvUI.
	local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
	if not AceGUI then return end

	local minor = (LibStub.minors and LibStub.minors["AceGUI-3.0"]) or 0
	E.Libs = E.Libs or {}
	E.LibsMinor = E.LibsMinor or {}
	E.Libs.AceGUI = AceGUI
	E.LibsMinor.AceGUI = minor

	self:HookAce3(AceGUI, minor)

	local ACD = E.Libs and E.Libs.AceConfigDialog
	if ACD then
		self:HookAceConfigDialogFeedGroup(ACD)
	end

	if type(_G.SarychUI_ENP_RegisterColorPickerElvUI) == "function" then
		_G.SarychUI_ENP_RegisterColorPickerElvUI()
	end
end

-----------------------------------------------------------------------
-- StaticPopup skinning (scoped via allowlist)
--
-- Blizzard reuses a tiny pool of StaticPopup frames (StaticPopup1 ..
-- STATICPOPUP_NUMDIALOGS) for *every* popup in the game: PvP/duel/group
-- invites, ready check, loot rolls, confirm dialogs, etc. We must NEVER skin
-- those frames globally, otherwise default Blizzard popups start looking like
-- the SarychUI/ElvUI config window.
--
-- Rule: only skin the popup frame that is currently displaying one of *our*
-- dialogs (the reload prompts created by SarychUI / ENP config, and the
-- AceConfig dialogs that belong to the settings UI). Any frame that gets
-- reused for a non-allowlisted Blizzard dialog is restored to its default look.
-----------------------------------------------------------------------
local SKINNED_STATIC_POPUPS = {
	SARYCHUI_RELOAD_UI = true,
	ELVUINP_PRIVATE_RL = true,
	ELVUINP_CONFIG_RL = true,
	ACECONFIGDIALOG30_CONFIRM_DIALOG = true,
	ACECONFIGDIALOG30_VALIDATION_ERROR_DIALOG = true,
}
S.SkinnedStaticPopups = SKINNED_STATIC_POPUPS

local function togglePopupButtonTextures(button, alpha)
	local bname = button.GetName and button:GetName()
	if bname then
		if _G[bname.."Left"] then _G[bname.."Left"]:SetAlpha(alpha) end
		if _G[bname.."Middle"] then _G[bname.."Middle"]:SetAlpha(alpha) end
		if _G[bname.."Right"] then _G[bname.."Right"]:SetAlpha(alpha) end
	end
	if button.Left then button.Left:SetAlpha(alpha) end
	if button.Middle then button.Middle:SetAlpha(alpha) end
	if button.Right then button.Right:SetAlpha(alpha) end
end

local function togglePopupButtons(popup, on)
	local name = popup.GetName and popup:GetName()
	for j = 1, 4 do
		local button = name and _G[name.."Button"..j]
		if button then
			-- One-time setup: hooks + a *toggleable* backdrop frame (useCreateBackdrop)
			-- so the ElvUI skin can be hidden again when the pooled frame is reused.
			if on and not button.__enpPopupSkinned then
				button.__enpPopupSkinned = true
				S:HandleButton(button, nil, nil, true)
			end
			if button.__enpPopupSkinned then
				togglePopupButtonTextures(button, on and 0 or 1)
				if button.backdrop then
					if on then button.backdrop:Show() else button.backdrop:Hide() end
				end
			end
		end
	end
end

function S:ApplyStaticPopupSkin(popup)
	if not popup or not popup.SetTemplate then return end
	if popup.__SarychUISkinnedPopup then return end

	-- Capture the original Blizzard backdrop once so it can be restored if the
	-- pooled frame is later reused by a default dialog.
	if popup.__enpOrigBackdrop == nil then
		popup.__enpOrigBackdrop = popup:GetBackdrop() or false
		popup.__enpOrigBackdropColor = { popup:GetBackdropColor() }
		popup.__enpOrigBackdropBorderColor = { popup:GetBackdropBorderColor() }
	end

	popup:SetTemplate("Transparent")

	local name = popup.GetName and popup:GetName()
	local closeButton = name and _G[name.."CloseButton"]
	if closeButton then
		closeButton:StripTextures()
		S:HandleCloseButton(closeButton, popup)
	end

	togglePopupButtons(popup, true)
	popup.__SarychUISkinnedPopup = true
end

function S:RestoreStaticPopupSkin(popup)
	if not popup or not popup.__SarychUISkinnedPopup then return end

	if popup.__enpOrigBackdrop then
		popup:SetBackdrop(popup.__enpOrigBackdrop)
		if popup.__enpOrigBackdropColor and popup.__enpOrigBackdropColor[1] then
			popup:SetBackdropColor(unpack(popup.__enpOrigBackdropColor))
		end
		if popup.__enpOrigBackdropBorderColor and popup.__enpOrigBackdropBorderColor[1] then
			popup:SetBackdropBorderColor(unpack(popup.__enpOrigBackdropBorderColor))
		end
	else
		popup:SetBackdrop(nil)
	end

	-- Drop the ElvUI template marker so media updates never recolor this frame.
	popup.template = nil
	if E.frames then E.frames[popup] = nil end

	togglePopupButtons(popup, false)
	popup.__SarychUISkinnedPopup = false
end

function S:FindShownStaticPopup(which)
	local popup = StaticPopup_FindVisible and StaticPopup_FindVisible(which)
	if popup then return popup end
	for i = 1, STATICPOPUP_NUMDIALOGS or 4 do
		local candidate = _G["StaticPopup"..i]
		if candidate and candidate:IsShown() and candidate.which == which then
			return candidate
		end
	end
end

function S:StaticPopup_ShowHook(which)
	if not which then return end

	local popup = S:FindShownStaticPopup(which)
	if not popup then return end

	if SKINNED_STATIC_POPUPS[which] then
		S:ApplyStaticPopupSkin(popup)
		if SarychUI and SarychUI.RaiseStaticPopupAboveConfig then
			SarychUI:RaiseStaticPopupAboveConfig(popup)
		end
	else
		-- A default Blizzard dialog is (re)using this pooled frame: strip any
		-- leftover skin from a previous allowlisted dialog.
		S:RestoreStaticPopupSkin(popup)
	end
end

function S:InitializeStaticPopups()
	if hooksecurefunc and not self.staticPopupHooked then
		self.staticPopupHooked = true
		hooksecurefunc("StaticPopup_Show", function(which)
			S:StaticPopup_ShowHook(which)
		end)
	end
end

-- Embedded: hook AceGUI-3.0-ENP only. Re-bind after ADDON_LOADED if needed.
S:EnsureAce3Hooks()
do
	local hookWatcher = CreateFrame("Frame")
	hookWatcher:RegisterEvent("ADDON_LOADED")
	hookWatcher:RegisterEvent("PLAYER_LOGIN")
	hookWatcher:SetScript("OnEvent", function()
		S:EnsureAce3Hooks()
	end)
end
if E.Libs and E.Libs.AceConfigDialog then
	S:Ace3_SkinTooltip(E.Libs.AceConfigDialog, E.LibsMinor and E.LibsMinor.AceConfigDialog)
end
S:InitializeStaticPopups()
