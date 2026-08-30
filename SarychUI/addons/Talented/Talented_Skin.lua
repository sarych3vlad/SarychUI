--[[
	Built-in skins for Talented (no ElvUI / ElvUI_AddOnSkins required).
	Styles:
	  ElvUI    — flat WHITE8X8 plate (mirrors ElvUI_AddOnSkins/talented.lua)
	  SarychUI — Cooltip grain chrome matching SarychUI options window
	Skipped if ElvUI_AddOnSkins is actively skinning Talented.
]]

local MEDIA = "Interface\\AddOns\\SarychUI\\addons\\Talented\\Media\\"
local BLANK = [[Interface\BUTTONS\WHITE8X8]]
local COOLTIP_BG = "Interface\\AddOns\\SarychUI\\media\\cooltip\\background"
local TEX_CLOSE = MEDIA .. "Close.tga"
local TEX_HIGHLIGHT = MEDIA .. "Highlight.tga"
local TEX_MELLI = MEDIA .. "Melli.tga"
-- Default WoW UI font (not ElvUI PT Sans Narrow)
local FONT_DEFAULT = "Fonts\\FRIZQT__.TTF"

local L = LibStub and LibStub("AceLocale-3.0", true) and LibStub("AceLocale-3.0"):GetLocale("Talented")

local TEX_COORDS = {0.08, 0.92, 0.08, 0.92}
local FULL_TEX_COORDS = {0, 1, 0, 1}

-- Runtime colors (filled by RefreshMedia for the active style)
local BORDER = {0, 0, 0, 1}
local BACKDROP = {0.1, 0.1, 0.1, 1}
local BACKDROP_FADE = {0.06, 0.06, 0.06, 0.8}
local VALUE = {1, 0.82, 0}
local TREE_HEADER_FILL = {0.12, 0.12, 0.12, 1}
local TREE_FILL = {0.08, 0.08, 0.08, 1}

-- ElvUI-style defaults (restored when style = ElvUI)
local ELVUI_BORDER = {0, 0, 0, 1}
local ELVUI_BACKDROP = {0.1, 0.1, 0.1, 1}
local ELVUI_BACKDROP_FADE = {0.06, 0.06, 0.06, 0.8}
local ELVUI_VALUE = {1, 0.82, 0}
local ELVUI_TREE_HEADER_FILL = {0.12, 0.12, 0.12, 1}
local ELVUI_TREE_FILL = {0.08, 0.08, 0.08, 1}

local COOLTIP_BD = {
	bgFile = COOLTIP_BG,
	edgeFile = BLANK,
	tile = true,
	tileSize = 16,
	edgeSize = 1,
	insets = {left = 0, right = 0, top = 0, bottom = 0},
}

local FONT_PATH = FONT_DEFAULT
local FONT_SIZE = 10 -- labels / tabs / general chrome
local BUTTON_FONT_SIZE = 11 -- Actions, Templates, Edit, tabs, …
-- ElvUI_AddOnSkins/talented.lua only uses OUTLINE on rank/target numbers.
-- Everything else stays like GameFontNormal (no outline, soft shadow).
local FONT_STYLE = ""
local MULT = 1

local function noop() end

local function GetElvUI()
	if ElvUI and ElvUI[1] then
		return ElvUI[1]
	end
end

local function ShouldSkip()
	local E = GetElvUI()
	if IsAddOnLoaded and IsAddOnLoaded("ElvUI_AddOnSkins") and E then
		if not E.private or not E.private.addOnSkins or E.private.addOnSkins.Talented ~= false then
			return true
		end
	end
	return false
end

local function GetSkinStyle()
	local addons = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons
	local style = addons and addons.Talented and addons.Talented.skinStyle
	if style == "ElvUI" then
		return "ElvUI"
	end
	return "SarychUI"
end

local function CopyColor(dst, src, fallback)
	if type(src) == "table" then
		dst[1] = src[1] or (fallback and fallback[1]) or 0
		dst[2] = src[2] or (fallback and fallback[2]) or 0
		dst[3] = src[3] or (fallback and fallback[3]) or 0
		dst[4] = src[4] or (fallback and fallback[4]) or 1
	elseif fallback then
		dst[1], dst[2], dst[3], dst[4] = fallback[1], fallback[2], fallback[3], fallback[4] or 1
	end
end

-- ElvUI Core/Math.lua → E:Round(num, 5)
local function Round5(num)
	return math.floor(num * 100000 + 0.5) / 100000
end

-- ElvUI Core/PixelPerfect.lua → E:PixelBestSize() (Install "Auto Scale")
local function PixelBestSize()
	local height = GetScreenHeight() or 1080
	if height < 1 then height = 1080 end
	local scale = Round5(768 / height)
	if scale < 0.4 then scale = 0.4 end
	if scale > 1.15 then scale = 1.15 end
	return scale
end

-- Base scale ElvUI would use on UIParent
local function GetElvUIScale()
	local E = GetElvUI()
	if E and E.global and E.global.general and type(E.global.general.UIScale) == "number" then
		return E.global.general.UIScale
	end
	if ElvDB and ElvDB.global and ElvDB.global.general and type(ElvDB.global.general.UIScale) == "number" then
		return ElvDB.global.general.UIScale
	end
	return PixelBestSize()
end

-- ElvUI_AddOnSkins/talented.lua does NOT SetScale the frame — size comes from
-- UIParent:SetScale(UIScale). Talented itself resets via SetScale(db.profile.scale)
-- on every SetClass, which was wiping our scale (felt like "nothing changes").
local TALENTED_SCALE_MULT = 0.96

local function GetTalentedUIScale()
	local scale = Round5(GetElvUIScale() * TALENTED_SCALE_MULT)
	if scale < 0.4 then scale = 0.4 end
	if scale > 1.15 then scale = 1.15 end
	return scale
end

local function RawSetScale(frame, scale)
	if not frame then return end
	local mt = getmetatable(frame)
	local idx = mt and mt.__index
	local setScale = type(idx) == "table" and idx.SetScale
	if type(setScale) == "function" then
		setScale(frame, scale)
	end
end

local function ComputeFrameScale()
	local parentScale = UIParent:GetScale() or 1
	if parentScale <= 0 then parentScale = 1 end
	local userScale = 1
	if Talented and Talented.db and Talented.db.profile and type(Talented.db.profile.scale) == "number" then
		userScale = Talented.db.profile.scale
	end
	-- effective ≈ ElvUI UIScale * MULT * Talented slider, relative to current UIParent
	local finalScale = Round5((GetTalentedUIScale() / parentScale) * userScale)
	if finalScale < 0.2 then finalScale = 0.2 end
	if finalScale > 3 then finalScale = 3 end
	return finalScale
end

local function ApplyFrameScale(frame)
	if not frame then return end

	if not frame.talentedScaleLocked then
		frame.talentedScaleLocked = true
		-- Ignore Talented's SetScale(profile.scale) resets; always keep our PP scale
		frame.SetScale = function(self)
			RawSetScale(self, ComputeFrameScale())
		end
		frame:HookScript("OnShow", function(self)
			RawSetScale(self, ComputeFrameScale())
		end)
	end

	RawSetScale(frame, ComputeFrameScale())
end

local function RefreshMedia()
	FONT_PATH = FONT_DEFAULT
	FONT_SIZE = 10
	FONT_STYLE = ""
	-- Keep 1px offsets like ElvUI when UIParent is already scaled; do not invent MULT.
	MULT = 1

	local style = GetSkinStyle()
	if style == "SarychUI" then
		local T = SarychUI and SarychUI.OptionsTheme
		local c = T and T.colors
		if c then
			CopyColor(BORDER, c.border, ELVUI_BORDER)
			CopyColor(BACKDROP, c.headerBg or c.buttonBg, ELVUI_BACKDROP)
			CopyColor(BACKDROP_FADE, c.contentBg or c.panelBg or c.rootBg, ELVUI_BACKDROP_FADE)
			CopyColor(VALUE, c.accent or c.title, ELVUI_VALUE)
			CopyColor(TREE_HEADER_FILL, c.headerBg or c.navBg, ELVUI_TREE_HEADER_FILL)
			CopyColor(TREE_FILL, c.panelBg or c.contentBg, ELVUI_TREE_FILL)
		else
			-- Theme not ready yet — Cooltip-like fallbacks matching options_theme.lua
			CopyColor(BORDER, {0.20, 0.20, 0.20, 1})
			CopyColor(BACKDROP, {0.28, 0.28, 0.28, 1})
			CopyColor(BACKDROP_FADE, {0.34, 0.34, 0.34, 0.60})
			CopyColor(VALUE, {0.95, 0.78, 0.15, 1})
			CopyColor(TREE_HEADER_FILL, {0.28, 0.28, 0.28, 1})
			CopyColor(TREE_FILL, {0.32, 0.32, 0.32, 0.55})
		end
		return
	end

	-- ElvUI style (default)
	CopyColor(BORDER, ELVUI_BORDER)
	CopyColor(BACKDROP, ELVUI_BACKDROP)
	CopyColor(BACKDROP_FADE, ELVUI_BACKDROP_FADE)
	CopyColor(VALUE, ELVUI_VALUE)
	CopyColor(TREE_HEADER_FILL, ELVUI_TREE_HEADER_FILL)
	CopyColor(TREE_FILL, ELVUI_TREE_FILL)

	local E = GetElvUI()
	if E then
		-- Keep FrizQT; do not adopt ElvUI normFont / PT Sans Narrow
		if E.mult then
			MULT = E.mult
		end
		if E.media and E.media.bordercolor then
			BORDER[1], BORDER[2], BORDER[3] = E.media.bordercolor[1] or 0, E.media.bordercolor[2] or 0, E.media.bordercolor[3] or 0
			BORDER[4] = 1
		end
		if E.media and E.media.backdropcolor then
			BACKDROP[1], BACKDROP[2], BACKDROP[3] = E.media.backdropcolor[1] or 0.1, E.media.backdropcolor[2] or 0.1, E.media.backdropcolor[3] or 0.1
			BACKDROP[4] = 1
		end
		if E.media and E.media.backdropfadecolor then
			BACKDROP_FADE[1] = E.media.backdropfadecolor[1] or 0.06
			BACKDROP_FADE[2] = E.media.backdropfadecolor[2] or 0.06
			BACKDROP_FADE[3] = E.media.backdropfadecolor[3] or 0.06
			BACKDROP_FADE[4] = E.media.backdropfadecolor[4] or 0.8
		end
		if E.media and E.media.rgbvaluecolor then
			VALUE[1], VALUE[2], VALUE[3] = E.media.rgbvaluecolor[1], E.media.rgbvaluecolor[2], E.media.rgbvaluecolor[3]
			VALUE[4] = 1
		end
		if E.TexCoords then
			TEX_COORDS[1], TEX_COORDS[2], TEX_COORDS[3], TEX_COORDS[4] = unpack(E.TexCoords)
		end
	end
end

local function Scale(x)
	local mult = MULT
	if not mult or mult <= 0 then mult = 1 end
	if not x then return 0 end
	local v = mult * math.floor(x / mult + 0.5)
	if v < 0.1 and x > 0 then v = mult end
	return v
end

local function RawSetFont(fs, font, fontSize, fontStyle)
	if not fs then return end
	local mt = getmetatable(fs)
	local idx = mt and mt.__index
	local setFont = (type(idx) == "table" and idx.SetFont) or fs.SetFont
	if type(setFont) ~= "function" then return end
	local ok = pcall(setFont, fs, font, fontSize, fontStyle)
	if not ok then
		pcall(setFont, fs, "Fonts\\FRIZQT__.TTF", fontSize or FONT_SIZE or 10, fontStyle or "")
	end
end

local function FontTemplate(fs, font, fontSize, fontStyle)
	if not fs then return end
	font = font or FONT_PATH
	fontSize = fontSize or FONT_SIZE
	if fontStyle == nil then fontStyle = FONT_STYLE end
	if type(fontSize) ~= "number" or fontSize < 1 then fontSize = FONT_SIZE or 10 end

	RawSetFont(fs, font, fontSize, fontStyle)
	-- Match ElvUI Toolkit FontTemplate: shadow only when no outline
	if fontStyle == "NONE" or fontStyle == "" or not fontStyle then
		local s = (MULT and MULT > 0) and MULT or 1
		fs:SetShadowOffset(s, -s / 2)
		fs:SetShadowColor(0, 0, 0, 1)
	else
		fs:SetShadowOffset(0, 0)
		fs:SetShadowColor(0, 0, 0, 0)
	end
end

local function Kill(object)
	if not object then return end
	if object.UnregisterAllEvents then
		object:UnregisterAllEvents()
	end
	object.Show = object.Hide
	object:Hide()
end

local function StripTextures(frame, onlyTextures)
	if not frame then return end
	if frame.GetNumRegions then
		for i = 1, frame:GetNumRegions() do
			local region = select(i, frame:GetRegions())
			if region and region.IsObjectType and region:IsObjectType("Texture") then
				region:SetTexture(nil)
				region:SetAlpha(0)
			end
		end
	end
	if onlyTextures then return end
	if frame.SetNormalTexture then frame:SetNormalTexture("") end
	if frame.SetPushedTexture then frame:SetPushedTexture("") end
	if frame.SetDisabledTexture then frame:SetDisabledTexture("") end
	if frame.SetHighlightTexture then frame:SetHighlightTexture("") end
end

local function SetInside(obj, anchor, xOffset, yOffset)
	if not obj then return end
	anchor = anchor or obj:GetParent()
	xOffset = xOffset or 1
	yOffset = yOffset or 1
	obj:ClearAllPoints()
	obj:SetPoint("TOPLEFT", anchor, "TOPLEFT", xOffset, -yOffset)
	obj:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -xOffset, yOffset)
end

local function SetOutside(obj, anchor, xOffset, yOffset)
	if not obj then return end
	anchor = anchor or obj:GetParent()
	xOffset = xOffset or 1
	yOffset = yOffset or 1
	obj:ClearAllPoints()
	obj:SetPoint("TOPLEFT", anchor, "TOPLEFT", -xOffset, yOffset)
	obj:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", xOffset, -yOffset)
end

local function SetTemplate(frame, template)
	if not frame then return end
	local br, bg, bb, ba = unpack(BACKDROP)
	local er, eg, eb, ea = unpack(BORDER)
	if template == "Transparent" then
		br, bg, bb, ba = unpack(BACKDROP_FADE)
	end

	if GetSkinStyle() == "SarychUI" then
		-- Cooltip grain chrome (same as SarychUI options window)
		local T = SarychUI and SarychUI.OptionsTheme
		local bd = (T and T.Backdrop and T:Backdrop()) or COOLTIP_BD
		frame:SetBackdrop(bd)
	else
		local edge = Scale(1)
		if not edge or edge < 1 then edge = 1 end
		frame:SetBackdrop({
			bgFile = BLANK,
			edgeFile = BLANK,
			tile = false,
			tileSize = 0,
			edgeSize = edge,
			insets = {left = 0, right = 0, top = 0, bottom = 0},
		})
	end
	frame:SetBackdropColor(br, bg, bb, ba or 1)
	frame:SetBackdropBorderColor(er, eg, eb, ea or 1)
end

local function CreateBackdrop(frame, template)
	if not frame then return end
	if frame.backdrop then return frame.backdrop end

	local parent = (frame.IsObjectType and frame:IsObjectType("Texture") and frame:GetParent()) or frame
	local backdrop = CreateFrame("Frame", nil, parent)
	frame.backdrop = backdrop
	SetOutside(backdrop, frame)
	SetTemplate(backdrop, template or "Default")

	local level = parent.GetFrameLevel and parent:GetFrameLevel()
	if level and level > 0 then
		backdrop:SetFrameLevel(level - 1)
	else
		backdrop:SetFrameLevel(0)
	end
	return backdrop
end

-- WotLK: SetTexture(r,g,b,a) is unreliable — use blank + vertex color
local function StyleButton(button, noHover, noPushed, noChecked)
	if not button then return end

	if button.SetHighlightTexture and not button.hover and not noHover then
		local hover = button:CreateTexture(nil, "HIGHLIGHT")
		SetInside(hover, button, 1, 1)
		hover:SetTexture(BLANK)
		hover:SetVertexColor(1, 1, 1, 0.3)
		button:SetHighlightTexture(hover)
		button.hover = hover
	end

	if button.SetPushedTexture and not button.pushed and not noPushed then
		local pushed = button:CreateTexture(nil, "ARTWORK")
		SetInside(pushed, button, 1, 1)
		pushed:SetTexture(BLANK)
		pushed:SetVertexColor(0.9, 0.8, 0.1, 0.3)
		button:SetPushedTexture(pushed)
		button.pushed = pushed
	end

	if button.SetCheckedTexture and not button.checked and not noChecked then
		local checked = button:CreateTexture(nil, "OVERLAY")
		SetInside(checked, button, 1, 1)
		checked:SetTexture(BLANK)
		checked:SetVertexColor(1, 1, 1, 0.3)
		button:SetCheckedTexture(checked)
		button.checked = checked
	end
end

local function GetTheme()
	return SarychUI and SarychUI.OptionsTheme
end

local function ApplyThemeFlat(frame, bgKey, borderKey)
	local T = GetTheme()
	if not T or not T.ApplyFlat or not frame then return false end
	local bg = (T.colors and T.colors[bgKey or "buttonBg"]) or BACKDROP
	local border = (T.colors and T.colors[borderKey or "borderSoft"]) or BORDER
	T:ApplyFlat(frame, bg, border)
	return true
end

local function SetModifiedBackdrop(self)
	if GetSkinStyle() == "SarychUI" and ApplyThemeFlat(self, "buttonHover", "accent") then
		return
	end
	if self.GetBackdropBorderColor then
		self:SetBackdropBorderColor(VALUE[1], VALUE[2], VALUE[3], 1)
	end
end

local function SetOriginalBackdrop(self)
	if GetSkinStyle() == "SarychUI" and ApplyThemeFlat(self, "buttonBg", "borderSoft") then
		return
	end
	if self.GetBackdropBorderColor then
		self:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], BORDER[4] or 1)
	end
end

local function HandleButton(button)
	if not button or button.talentedSkinned then return end

	if button.left then Kill(button.left) end
	if button.middle then Kill(button.middle) end
	if button.right then Kill(button.right) end

	if button.SetNormalTexture then button:SetNormalTexture("") end
	if button.SetHighlightTexture then button:SetHighlightTexture("") end
	if button.SetPushedTexture then button:SetPushedTexture("") end
	if button.SetDisabledTexture then button:SetDisabledTexture("") end

	if GetSkinStyle() == "SarychUI" then
		ApplyThemeFlat(button, "buttonBg", "borderSoft")
	else
		SetTemplate(button, "Default")
	end
	button:HookScript("OnEnter", SetModifiedBackdrop)
	button:HookScript("OnLeave", SetOriginalBackdrop)

	local fs = button.GetFontString and button:GetFontString()
	if fs then FontTemplate(fs, nil, BUTTON_FONT_SIZE, "") end

	button.talentedSkinned = true
end

-- Match SarychUI options Dropdown trigger: left text + gold "v" arrow.
local function StyleDropdownTrigger(button)
	if not button then return end
	HandleButton(button)
	if GetSkinStyle() ~= "SarychUI" then return end

	if not button.talentedDropArrow then
		local T = GetTheme()
		local font = (T and T.fonts and T.fonts.small) or "GameFontHighlightSmall"
		local arrow = button:CreateFontString(nil, "OVERLAY", font)
		arrow:SetPoint("RIGHT", -6, 0)
		arrow:SetText("v")
		if T and T.SetTextColor then
			T:SetTextColor(arrow, "accent")
		else
			arrow:SetTextColor(VALUE[1], VALUE[2], VALUE[3], 1)
		end
		button.talentedDropArrow = arrow
	end

	local fs = button.GetFontString and button:GetFontString()
	if fs then
		FontTemplate(fs, nil, BUTTON_FONT_SIZE, "")
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", 8, 0)
		fs:SetPoint("RIGHT", button.talentedDropArrow, "LEFT", -4, 0)
		fs:SetJustifyH("LEFT")
		local T = GetTheme()
		if T and T.SetTextColor then
			T:SetTextColor(fs, "text")
		end
	end

	local w = button.GetTextWidth and button:GetTextWidth()
	if w then
		button:SetWidth(math.max(100, w + 34))
	end
	button:SetHeight(22)
end

local function StyleButtonText(button)
	if not button then return end
	local fs = button.GetFontString and button:GetFontString()
	if fs then FontTemplate(fs, nil, BUTTON_FONT_SIZE, "") end
end

local function HandleEditBox(frame)
	if not frame or frame.backdrop then return end

	if frame.DisableDrawLayer then
		frame:DisableDrawLayer("BACKGROUND")
	end

	if frame.GetNumRegions then
		for i = 1, frame:GetNumRegions() do
			local region = select(i, frame:GetRegions())
			if region and region.IsObjectType and region:IsObjectType("Texture") then
				region:SetAlpha(0)
			end
		end
	end

	CreateBackdrop(frame, "Default")
	if frame.backdrop then
		frame.backdrop:SetFrameLevel(frame:GetFrameLevel())
	end
	FontTemplate(frame, nil, nil, "")
end

local function FixCheckBoxLayers(frame)
	if not frame then return end
	local level = frame:GetFrameLevel() or 1
	if frame.backdrop then
		if level > 0 then
			frame.backdrop:SetFrameLevel(level - 1)
		else
			frame.backdrop:SetFrameLevel(0)
		end
	end
	local checked = frame.GetCheckedTexture and frame:GetCheckedTexture()
	if checked then
		checked:SetDrawLayer("OVERLAY")
		checked:SetAlpha(1)
		if frame.backdrop then
			checked:ClearAllPoints()
			checked:SetPoint("TOPLEFT", frame.backdrop, "TOPLEFT", -1, 1)
			checked:SetPoint("BOTTOMRIGHT", frame.backdrop, "BOTTOMRIGHT", 1, -1)
		end
	end
end

-- ElvUI checkBoxSkin style (Melli check inside Default box)
local function HandleCheckBox(frame)
	if not frame then return end
	if frame.talentedSkinned then
		FixCheckBoxLayers(frame)
		return
	end

	-- Strip only textures; keep FontString label
	if frame.GetNumRegions then
		for i = 1, frame:GetNumRegions() do
			local region = select(i, frame:GetRegions())
			if region and region.IsObjectType and region:IsObjectType("Texture") then
				region:SetTexture(nil)
				region:SetAlpha(0)
			end
		end
	end
	if frame.SetNormalTexture then frame:SetNormalTexture("") end
	if frame.SetPushedTexture then frame:SetPushedTexture("") end
	if frame.SetHighlightTexture then frame:SetHighlightTexture("") end

	if not frame.backdrop then
		local bd = CreateFrame("Frame", nil, frame)
		bd:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
		bd:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
		SetTemplate(bd, "Default")
		frame.backdrop = bd
	end

	if frame.SetCheckedTexture then
		frame:SetCheckedTexture(TEX_MELLI)
		local checked = frame:GetCheckedTexture()
		if checked then
			checked:SetVertexColor(VALUE[1], VALUE[2], VALUE[3], 1)
		end
	end
	if frame.SetDisabledCheckedTexture then
		frame:SetDisabledCheckedTexture(TEX_MELLI)
		local disabled = frame:GetDisabledCheckedTexture()
		if disabled then
			disabled:SetVertexColor(0.6, 0.6, 0.6, 0.8)
			if frame.backdrop then
				SetInside(disabled, frame.backdrop, 0, 0)
			end
		end
	elseif frame.SetDisabledTexture then
		frame:SetDisabledTexture("")
	end

	FixCheckBoxLayers(frame)

	if frame.label then
		frame.label:SetAlpha(1)
		frame.label:Show()
		if frame.label.SetDrawLayer then frame.label:SetDrawLayer("OVERLAY") end
		FontTemplate(frame.label, nil, nil, "")
		-- Old Ui.lua uses width 400 — that covers the box when docked right
		frame.label:SetHeight(20)
		frame.label:SetWidth(170)
	end

	if frame.SetNormalTexture then
		hooksecurefunc(frame, "SetNormalTexture", function(checkbox, path)
			if path and path ~= "" then
				checkbox:SetNormalTexture("")
			end
		end)
	end

	frame.talentedSkinned = true
end

local function HandleCloseButton(f, point)
	if not f or f.talentedSkinned then return end
	StripTextures(f)
	if f.SetNormalTexture then f:SetNormalTexture("") end
	if f.SetPushedTexture then f:SetPushedTexture("") end
	if f.SetHighlightTexture then f:SetHighlightTexture("") end
	if f.SetDisabledTexture then f:SetDisabledTexture("") end

	if GetSkinStyle() == "SarychUI" then
		-- Same as options_window.lua: 22×22 Cooltip plate + FontString "X"
		f:SetSize(18, 18)
		f:SetHitRectInsets(0, 0, 0, 0)
		ApplyThemeFlat(f, "buttonBg", "borderSoft")

		if not f.talentedCloseX then
			local T = GetTheme()
			local font = (T and T.fonts and T.fonts.normal) or "GameFontHighlightSmall"
			local x = f:CreateFontString(nil, "OVERLAY", font)
			x:SetPoint("CENTER", 1, 0)
			x:SetText("X")
			if T and T.SetTextColor then
				T:SetTextColor(x, "text")
			else
				x:SetTextColor(0.92, 0.92, 0.92, 1)
			end
			f.talentedCloseX = x
		end

		f:HookScript("OnEnter", function(btn)
			ApplyThemeFlat(btn, "buttonHover", "accent")
		end)
		f:HookScript("OnLeave", function(btn)
			ApplyThemeFlat(btn, "buttonBg", "borderSoft")
		end)
	else
		if not f.Texture then
			f.Texture = f:CreateTexture(nil, "OVERLAY")
			f.Texture:SetPoint("CENTER")
			f.Texture:SetTexture(TEX_CLOSE)
			f.Texture:SetWidth(12)
			f.Texture:SetHeight(12)
			f:HookScript("OnEnter", function(btn)
				if btn.Texture then btn.Texture:SetVertexColor(VALUE[1], VALUE[2], VALUE[3]) end
			end)
			f:HookScript("OnLeave", function(btn)
				if btn.Texture then btn.Texture:SetVertexColor(1, 1, 1) end
			end)
			f:SetHitRectInsets(7, 6, 7, 6)
		end
	end

	if point then
		f:ClearAllPoints()
		if GetSkinStyle() == "SarychUI" then
			f:SetPoint("RIGHT", point, "RIGHT", -10, -1)
		else
			f:SetPoint("TOPRIGHT", point, "TOPRIGHT", 2, 3)
		end
	end
	f.talentedSkinned = true
end

-- ElvUI crops icon edges; SarychUI keeps full coords + default Quickslot chrome.
local function ApplyIconTexCoords(tex)
	if not tex or not tex.SetTexCoord then return end
	if GetSkinStyle() == "SarychUI" then
		tex:SetTexCoord(FULL_TEX_COORDS[1], FULL_TEX_COORDS[2], FULL_TEX_COORDS[3], FULL_TEX_COORDS[4])
	else
		tex:SetTexCoord(TEX_COORDS[1], TEX_COORDS[2], TEX_COORDS[3], TEX_COORDS[4])
	end
end

local function CleanTalentButtonChrome(button)
	if not button then return end

	-- Drop any dark SetTemplate / leftover CreateBackdrop plate
	if button.backdrop then
		Kill(button.backdrop)
		button.backdrop = nil
	end
	if button.SetBackdrop then
		button:SetBackdrop(nil)
	end
	if button.SetBackdropColor then
		button:SetBackdropColor(0, 0, 0, 0)
	end
	if button.SetBackdropBorderColor then
		button:SetBackdropBorderColor(0, 0, 0, 0)
	end

	if button.slot then
		button.slot:SetTexture(nil)
		button.slot:SetAlpha(0)
		Kill(button.slot)
	end
	if button.rank and button.rank.texture then
		button.rank.texture:SetTexture(nil)
		button.rank.texture:SetAlpha(0)
		Kill(button.rank.texture)
	end

	-- StyleButton BLANK squares on ARTWORK were showing as dark plates
	if button.hover then
		button.hover:SetTexture(nil)
		button.hover:Hide()
		button.hover = nil
	end
	if button.pushed then
		button.pushed:SetTexture(nil)
		button.pushed:Hide()
		button.pushed = nil
	end
	if button.checked then
		button.checked:SetTexture(nil)
		button.checked:Hide()
		button.checked = nil
	end

	if button.SetNormalTexture then button:SetNormalTexture("") end
	if button.SetPushedTexture then button:SetPushedTexture("") end
	if button.SetDisabledTexture then button:SetDisabledTexture("") end

	-- Only keep the talent icon; strip Quickslot / EmptySlot / blank plates
	local icon = button.texture
	if button.GetNumRegions then
		for i = 1, button:GetNumRegions() do
			local region = select(i, button:GetRegions())
			if region and region.IsObjectType and region:IsObjectType("Texture") and region ~= icon then
				region:SetTexture(nil)
				region:SetAlpha(0)
				region:Hide()
			end
		end
	end

	-- Light ADD highlight only (no solid square)
	if button.SetHighlightTexture then
		button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		local hl = button:GetHighlightTexture()
		if hl then
			hl:ClearAllPoints()
			hl:SetAllPoints(button)
			hl:SetBlendMode("ADD")
			hl:SetAlpha(1)
		end
	end

	if button.DisableDrawLayer then
		button:DisableDrawLayer("BACKGROUND")
	end
end

local function SkinTalentButton(button)
	if not button then return end

	-- Always clean — pool reuse / old skins may still carry dark chrome
	CleanTalentButtonChrome(button)

	if button.isSkinned then
		if button.texture then
			button.texture:Show()
			button.texture:SetAlpha(1)
			button.texture:SetDrawLayer("ARTWORK")
			SetInside(button.texture, button, 0, 0)
			ApplyIconTexCoords(button.texture)
		end
		return
	end

	if button.SetNormalTexture then
		button.SetNormalTexture = noop
	end

	if button.texture then
		button.texture:Show()
		button.texture:SetAlpha(1)
		button.texture:SetDrawLayer("ARTWORK")
		SetInside(button.texture, button, 0, 0)
		ApplyIconTexCoords(button.texture)
	end

	if button.rank then
		FontTemplate(button.rank, nil, 10, "OUTLINE")
		button.rank:ClearAllPoints()
		button.rank:SetPoint("CENTER", button, "BOTTOMRIGHT", 2, 0)
	end

	button.isSkinned = true
end

local function SkinButtonTarget(button, target)
	if not target or target.isSkinned then return end

	FontTemplate(target, nil, 10, "OUTLINE")
	target:ClearAllPoints()
	target:SetPoint("CENTER", button, "TOPRIGHT", 2, 0)
	if target.texture then
		Kill(target.texture)
	end
	target.isSkinned = true
end

-- Solid fill instead of Blizzard TalentFrame tile art (full column, no gaps).
-- TREE_FILL / TREE_HEADER_FILL are declared above and updated in RefreshMedia.

local function ApplyTreeSolidBackground(tree)
	if not tree then return end

	for _, key in ipairs({"topleft", "topright", "bottomleft", "bottomright"}) do
		local tex = tree[key]
		if tex then
			tex:SetTexture(nil)
			tex:SetAlpha(0)
			if not tex.talentedBgDisabled then
				tex.SetTexture = noop
				tex.talentedBgDisabled = true
			end
		end
	end

	-- One continuous plate under header + talents (avoids the "hole" under the header)
	local fill = tree.talentedSolidBg
	if not fill then
		fill = tree:CreateTexture(nil, "BACKGROUND")
		tree.talentedSolidBg = fill
	end
	if GetSkinStyle() == "SarychUI" then
		fill:SetTexture(COOLTIP_BG)
	else
		fill:SetTexture(BLANK)
	end
	fill:ClearAllPoints()
	fill:SetAllPoints(tree)
	fill:SetVertexColor(TREE_FILL[1], TREE_FILL[2], TREE_FILL[3], TREE_FILL[4])
	fill:Show()
end

-- Fallback icons when GetTalentTabInfo isn't available (other class / pets)
local TREE_ICONS = {
	WarriorArms = "Interface\\Icons\\Ability_Rogue_Ambush",
	WarriorFury = "Interface\\Icons\\Ability_Warrior_InnerRage",
	WarriorProtection = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
	PaladinHoly = "Interface\\Icons\\Spell_Holy_HolyBolt",
	PaladinProtection = "Interface\\Icons\\Spell_Holy_DevotionAura",
	PaladinCombat = "Interface\\Icons\\Spell_Holy_AuraOfLight",
	HunterBeastMastery = "Interface\\Icons\\Ability_Hunter_BeastTaming",
	HunterMarksmanship = "Interface\\Icons\\Ability_Marksmanship",
	HunterSurvival = "Interface\\Icons\\Ability_Hunter_SwiftStrike",
	RogueAssassination = "Interface\\Icons\\Ability_Rogue_Eviscerate",
	RogueCombat = "Interface\\Icons\\Ability_BackStab",
	RogueSubtlety = "Interface\\Icons\\Ability_Stealth",
	PriestDiscipline = "Interface\\Icons\\Spell_Holy_WordFortitude",
	PriestHoly = "Interface\\Icons\\Spell_Holy_HolyBolt",
	PriestShadow = "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
	DeathKnightBlood = "Interface\\Icons\\Spell_Deathknight_BloodPresence",
	DeathKnightFrost = "Interface\\Icons\\Spell_Deathknight_FrostPresence",
	DeathKnightUnholy = "Interface\\Icons\\Spell_Deathknight_UnholyPresence",
	ShamanElementalCombat = "Interface\\Icons\\Spell_Nature_Lightning",
	ShamanEnhancement = "Interface\\Icons\\Spell_Nature_LightningShield",
	ShamanRestoration = "Interface\\Icons\\Spell_Nature_MagicImmunity",
	MageArcane = "Interface\\Icons\\Spell_Holy_MagicalSentry",
	MageFire = "Interface\\Icons\\Spell_Fire_FireBolt02",
	MageFrost = "Interface\\Icons\\Spell_Frost_FrostBolt02",
	WarlockCurses = "Interface\\Icons\\Spell_Shadow_DeathCoil",
	WarlockSummoning = "Interface\\Icons\\Spell_Shadow_Metamorphosis",
	WarlockDestruction = "Interface\\Icons\\Spell_Shadow_RainOfFire",
	DruidBalance = "Interface\\Icons\\Spell_Nature_StarFall",
	DruidFeralCombat = "Interface\\Icons\\Ability_Racial_BearForm",
	DruidRestoration = "Interface\\Icons\\Spell_Nature_HealingTouch",
	HunterPetCunning = "Interface\\Icons\\Ability_Druid_Dash",
	HunterPetTenacity = "Interface\\Icons\\Ability_Physical_Taunt",
	HunterPetFerocity = "Interface\\Icons\\Ability_Druid_Swipe",
}

-- LFG roles per talent tree (WotLK). String = one role; table = several possible roles.
local TREE_ROLES = {
	WarriorArms = "DAMAGER",
	WarriorFury = "DAMAGER",
	WarriorProtection = "TANK",
	PaladinHoly = "HEALER",
	PaladinProtection = "TANK",
	PaladinCombat = "DAMAGER",
	HunterBeastMastery = "DAMAGER",
	HunterMarksmanship = "DAMAGER",
	HunterSurvival = "DAMAGER",
	RogueAssassination = "DAMAGER",
	RogueCombat = "DAMAGER",
	RogueSubtlety = "DAMAGER",
	PriestDiscipline = "HEALER",
	PriestHoly = "HEALER",
	PriestShadow = "DAMAGER",
	DeathKnightBlood = {"TANK", "DAMAGER"},
	DeathKnightFrost = {"TANK", "DAMAGER"},
	DeathKnightUnholy = "DAMAGER",
	ShamanElementalCombat = "DAMAGER",
	ShamanEnhancement = "DAMAGER",
	ShamanRestoration = "HEALER",
	MageArcane = "DAMAGER",
	MageFire = "DAMAGER",
	MageFrost = "DAMAGER",
	WarlockCurses = "DAMAGER",
	WarlockSummoning = "DAMAGER",
	WarlockDestruction = "DAMAGER",
	DruidBalance = "DAMAGER",
	DruidFeralCombat = {"TANK", "DAMAGER"},
	DruidRestoration = "HEALER",
	HunterPetCunning = "DAMAGER",
	HunterPetTenacity = "TANK",
	HunterPetFerocity = "DAMAGER",
}

local ROLE_TEX = [[Interface\LFGFrame\UI-LFG-ICON-PORTRAITROLES]]
local ROLE_COORDS = {
	TANK = {0, 19 / 64, 22 / 64, 41 / 64},
	HEALER = {20 / 64, 39 / 64, 1 / 64, 20 / 64},
	DAMAGER = {20 / 64, 39 / 64, 22 / 64, 41 / 64},
}
local ROLE_ICON_SIZE = 16
local ROLE_ICON_GAP = 2
local MAX_TREE_ROLES = 3

local function NormalizeTreeRoles(entry)
	if type(entry) == "string" then
		return {entry}
	end
	if type(entry) == "table" then
		local list = {}
		for i = 1, #entry do
			local role = entry[i]
			if type(role) == "string" and ROLE_COORDS[role] then
				list[#list + 1] = role
			end
		end
		return list
	end
	return nil
end

local function EnsureRoleIcons(header, count)
	if not header.roles then
		header.roles = {}
	end
	-- Migrate legacy single role texture into the roles array
	if header.role then
		if not header.roles[1] then
			header.roles[1] = header.role
		elseif header.role ~= header.roles[1] then
			header.role:Hide()
		end
		header.role = nil
	end
	for i = 1, count do
		if not header.roles[i] then
			header.roles[i] = header:CreateTexture(nil, "ARTWORK")
		end
	end
	for i = count + 1, #header.roles do
		header.roles[i]:Hide()
	end
end

local function LayoutRoleIcons(header, roleCount)
	roleCount = roleCount or 0
	local clearSlot = 18
	local rightPad = clearSlot + 2
	local prev
	for i = 1, roleCount do
		local tex = header.roles[i]
		tex:SetSize(ROLE_ICON_SIZE, ROLE_ICON_SIZE)
		tex:ClearAllPoints()
		if i == 1 then
			tex:SetPoint("RIGHT", header, "RIGHT", -rightPad, 0)
		else
			tex:SetPoint("RIGHT", prev, "LEFT", -ROLE_ICON_GAP, 0)
		end
		prev = tex
	end
	return prev -- leftmost role icon, or nil
end

local function UpdateTreeHeader(tree, class, tab, points, isPrimary)
	local header = tree and tree.talentedHeader
	if not header then return end

	local info = class and Talented.tabdata[class] and Talented.tabdata[class][tab]
	local bg = info and info.background
	local name = (info and info.name) or ""
	local icon = (info and info.icon) or (bg and TREE_ICONS[bg])
	local roles = NormalizeTreeRoles(bg and TREE_ROLES[bg])

	if header.icon then
		if icon then
			header.icon:SetTexture(icon)
			ApplyIconTexCoords(header.icon)
			header.icon:Show()
		else
			header.icon:Hide()
		end
	end

	if header.title then
		header.title:SetText(name)
		if isPrimary then
			header.title:SetTextColor(VALUE[1], VALUE[2], VALUE[3])
		else
			header.title:SetTextColor(0.9, 0.9, 0.9)
		end
	end

	if header.points then
		header.points:SetText(tostring(points or 0))
		if isPrimary then
			header.points:SetTextColor(VALUE[1], VALUE[2], VALUE[3])
		else
			header.points:SetTextColor(1, 1, 1)
		end
	end

	local roleCount = roles and #roles or 0
	if roleCount > MAX_TREE_ROLES then roleCount = MAX_TREE_ROLES end
	EnsureRoleIcons(header, roleCount)
	local leftmostRole = LayoutRoleIcons(header, roleCount)
	for i = 1, roleCount do
		local role = roles[i]
		local tex = header.roles[i]
		local coords = ROLE_COORDS[role]
		tex:SetTexture(ROLE_TEX)
		tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		tex:Show()
	end

	if header.points then
		header.points:ClearAllPoints()
		if leftmostRole then
			header.points:SetPoint("RIGHT", leftmostRole, "LEFT", -14, 0)
		else
			header.points:SetPoint("RIGHT", header, "RIGHT", -(18 + 2 + 14), 0)
		end
	end

	-- Gold border marks the primary (highest-point) tree
	if isPrimary then
		header:SetBackdropBorderColor(VALUE[1], VALUE[2], VALUE[3], 1)
	else
		header:SetBackdropBorderColor(0, 0, 0, 0)
	end

	tree.talentedIsPrimary = isPrimary and true or nil
end

local function EnsureTreeHeader(tree)
	if not tree then return end

	local headerH = Talented.TREE_HEADER_HEIGHT or 30
	local iconSize = headerH - 6
	if iconSize < 16 then iconSize = 16 end

	if tree.name then
		tree.name:Hide()
		tree.name.Show = tree.name.Hide
	end

	local header = tree.talentedHeader
	if not header then
		header = CreateFrame("Frame", nil, tree)
		tree.talentedHeader = header
		header.roles = {}

		local icon = header:CreateTexture(nil, "ARTWORK")
		icon:SetPoint("LEFT", header, "LEFT", 4, 0)
		header.icon = icon

		local title = header:CreateFontString(nil, "OVERLAY")
		title:SetJustifyH("LEFT")
		if title.SetWordWrap then
			title:SetWordWrap(false)
		elseif title.SetNonSpaceWrap then
			title:SetNonSpaceWrap(false)
		end
		header.title = title

		local points = header:CreateFontString(nil, "OVERLAY")
		points:SetJustifyH("RIGHT")
		points:SetTextColor(1, 1, 1)
		header.points = points
	end

	-- Match tree column width; inset 1px so it sits inside the column border
	header:ClearAllPoints()
	header:SetHeight(headerH)
	header:SetPoint("TOPLEFT", tree, "TOPLEFT", 1, -1)
	header:SetPoint("TOPRIGHT", tree, "TOPRIGHT", -1, -1)
	SetTemplate(header, "Default")
	header:SetBackdropColor(TREE_HEADER_FILL[1], TREE_HEADER_FILL[2], TREE_HEADER_FILL[3], TREE_HEADER_FILL[4])
	-- Border color set in UpdateTreeHeader (gold for primary tree)
	if not header.talentedIsPrimary then
		header:SetBackdropBorderColor(0, 0, 0, 0)
	end
	header:SetFrameLevel((tree:GetFrameLevel() or 0) + 6)

	header.icon:SetSize(iconSize, iconSize)
	header.icon:ClearAllPoints()
	header.icon:SetPoint("LEFT", header, "LEFT", 4, 0)
	ApplyIconTexCoords(header.icon)

	-- Default layout: one role slot until UpdateTreeHeader fills actual roles
	EnsureRoleIcons(header, 1)
	local leftmostRole = LayoutRoleIcons(header, 1)
	if header.roles[1] then header.roles[1]:Hide() end

	FontTemplate(header.points, nil, 11, "")
	header.points:SetJustifyH("RIGHT")
	header.points:ClearAllPoints()
	if leftmostRole then
		header.points:SetPoint("RIGHT", leftmostRole, "LEFT", -14, 0)
	else
		header.points:SetPoint("RIGHT", header, "RIGHT", -(18 + 2 + 14), 0)
	end

	FontTemplate(header.title, nil, 11, "")
	header.title:ClearAllPoints()
	header.title:SetPoint("LEFT", header.icon, "RIGHT", 6, 0)
	header.title:SetPoint("RIGHT", header.points, "LEFT", -10, 0)

	if tree.clear then
		tree.clear:SetParent(header)
		tree.clear:SetSize(18, 18)
		tree.clear:ClearAllPoints()
		tree.clear:SetPoint("RIGHT", header, "RIGHT", -2, 0)
		tree.clear:SetFrameLevel(header:GetFrameLevel() + 1)
	end

	return header
end

local function EnsureTreeBorder(tree)
	-- Column border removed — only the header keeps an outline (gold for primary)
	if not tree then return end
	local border = tree.talentedBorder
	if border then
		border:Hide()
		border:SetBackdrop(nil)
	end
end

local function SkinTalentFrame(tree)
	if not tree then return end

	ApplyTreeSolidBackground(tree)
	EnsureTreeHeader(tree)
	EnsureTreeBorder(tree)

	if tree.isSkinned then return end

	-- Clear-tree button: CancelButton art is a dark plate on the BG — strip to icon-only
	if tree.clear and not tree.clear.talentedClearSkinned then
		local clear = tree.clear
		if clear.SetBackdrop then clear:SetBackdrop(nil) end
		StripTextures(clear)
		if clear.SetNormalTexture then clear:SetNormalTexture("") end
		if clear.SetPushedTexture then clear:SetPushedTexture("") end
		if clear.SetHighlightTexture then clear:SetHighlightTexture("") end
		if not clear.Texture then
			clear.Texture = clear:CreateTexture(nil, "OVERLAY")
			clear.Texture:SetPoint("CENTER")
			clear.Texture:SetTexture(TEX_CLOSE)
			clear.Texture:SetWidth(12)
			clear.Texture:SetHeight(12)
		end
		clear:SetHitRectInsets(4, 4, 4, 4)
		clear.talentedClearSkinned = true
	end
	tree.isSkinned = true
end

local TITLE_BAR_H = 28
local TOOLBAR_H = 28
-- QuestTracker.BLP atlas slices — same clean header + footer line as bags.
local DF_HEADER = [[Interface\AddOns\SarychUI\media\textures\questtracker\QuestTracker.BLP]]
local DF_TEX_W, DF_TEX_H = 1024, 512
local DF_HDR = { l = 36, r = 566, t = 328, b = 376 }   -- clean gold rails; 2px crop off bottom
local DF_LINE = { l = 21, r = 656, t = 384, b = 395 }   -- thin fade underline
local DF_TITLE_BAR_H = 24

local function IsDragonflightHeaderEnabled()
	local addons = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons
	local cfg = addons and addons.Talented
	if cfg and cfg.dragonflightHeader == false then
		return false
	end
	return true
end

local function GetTitleBarH()
	if IsDragonflightHeaderEnabled() then
		return DF_TITLE_BAR_H
	end
	return TITLE_BAR_H
end

local function SetDfSlice(tex, slice)
	tex:SetTexture(DF_HEADER)
	tex:SetTexCoord(slice.l / DF_TEX_W, slice.r / DF_TEX_W, slice.t / DF_TEX_H, slice.b / DF_TEX_H)
end

local function ApplyDragonflightTitleHeader(titleBar)
	if not titleBar then return end
	local tex = titleBar.talentedDfHeader
	if not IsDragonflightHeaderEnabled() then
		if tex then tex:Hide() end
		return
	end
	if not tex then
		tex = titleBar:CreateTexture(nil, "ARTWORK")
		titleBar.talentedDfHeader = tex
	end

	-- Fill the title bar flush (full DF crop; toolbar edge stripped separately).
	SetDfSlice(tex, DF_HDR)
	tex:ClearAllPoints()
	tex:SetPoint("TOPLEFT", titleBar, "TOPLEFT", 0, 0)
	tex:SetPoint("BOTTOMRIGHT", titleBar, "BOTTOMRIGHT", 0, -1)
	tex:SetAlpha(1)
	tex:Show()

	-- Hide plate fill/border so only the DF strip shows (no gray gap / seam line).
	if titleBar.SetBackdrop then
		local bd = titleBar:GetBackdrop()
		if bd then
			bd.edgeFile = nil
			bd.edgeSize = 0
			titleBar:SetBackdrop(bd)
		end
	end
	if titleBar.SetBackdropColor then
		titleBar:SetBackdropColor(0, 0, 0, 0)
	end
	if titleBar.SetBackdropBorderColor then
		titleBar:SetBackdropBorderColor(0, 0, 0, 0)
	end
	if not titleBar.talentedDfHeaderHooked then
		titleBar.talentedDfHeaderHooked = true
		titleBar:HookScript("OnSizeChanged", function(self)
			if self.talentedDfHeaderRelayout then return end
			self.talentedDfHeaderRelayout = true
			ApplyDragonflightTitleHeader(self)
			self.talentedDfHeaderRelayout = nil
		end)
	end
end

local function ApplyDragonflightToolbarLine(toolBar)
	if not toolBar then return end
	local line = toolBar.talentedDfToolbarLine
	if not IsDragonflightHeaderEnabled() then
		if line then line:Hide() end
		return
	end
	if not line then
		line = toolBar:CreateTexture(nil, "OVERLAY")
		toolBar.talentedDfToolbarLine = line
	end
	SetDfSlice(line, DF_LINE)
	line:ClearAllPoints()
	line:SetPoint("BOTTOMLEFT", toolBar, "BOTTOMLEFT", 0, 0)
	line:SetPoint("BOTTOMRIGHT", toolBar, "BOTTOMRIGHT", 0, 0)
	line:SetHeight(2)
	line:SetAlpha(0.5)
	line:Show()
	if not toolBar.talentedDfToolbarLineHooked then
		toolBar.talentedDfToolbarLineHooked = true
		toolBar:HookScript("OnSizeChanged", function(self)
			if self.talentedDfToolbarRelayout then return end
			self.talentedDfToolbarRelayout = true
			ApplyDragonflightToolbarLine(self)
			self.talentedDfToolbarRelayout = nil
		end)
	end
end

-- Glyph art 323×349 (+backdrop rim). Wide pads so nothing crops the texture edges.
local GLYPH_ART_W, GLYPH_ART_H = 323, 349
local GLYPH_BD = 3 -- backdrop rim around the art
local GLYPH_PAD_X, GLYPH_PAD_TOP, GLYPH_PAD_BOTTOM = 20, 22, 36
-- Right-side summary: 3 major + 3 minor (icon + name)
local GLYPH_PANEL_W = 220
local GLYPH_PANEL_GAP = 12
-- Placeholder socket lists for row creation only — real major/minor comes from gtype
local GLYPH_SUMMARY_ROW_COUNT = 3
local GLYPH_CONTENT_W = GLYPH_ART_W + GLYPH_BD * 2 + GLYPH_PAD_X * 2 + GLYPH_PANEL_GAP + GLYPH_PANEL_W
local GLYPH_CONTENT_H = GLYPH_PAD_TOP + GLYPH_ART_H + GLYPH_BD * 2 + GLYPH_PAD_BOTTOM
local GLYPH_WINDOW_W = GLYPH_CONTENT_W
local GLYPH_WINDOW_H = TITLE_BAR_H + GLYPH_CONTENT_H -- base; runtime uses GetTitleBarH()

local EnsureBottomTabs, SelectMainTab, SkinGlyphFrame, SyncPointsLeftFooter, SkinSpecTabs
local UpdateEditModeButtonState -- forward decl
local EnsureGlyphSummaryPanel, RefreshGlyphSummary, LayoutGlyphArtLeft

-- Two absolute footer sizes (window height = body + footer)
local FOOTER_NONE = 10   -- no "points left" label
local FOOTER_POINTS = 30 -- with "points left" / activate button
local FOOTER_CONTENT_Y = 15 -- shared vertical center (from bottom) for points + activate
local POINTS_LEFT_FONT = 11

local function RawSetHeight(frame, height)
	if not frame or not height then return end
	local mt = getmetatable(frame)
	local idx = mt and mt.__index
	local setHeight = type(idx) == "table" and idx.SetHeight
	if type(setHeight) == "function" then
		setHeight(frame, height)
	else
		frame:SetHeight(height)
	end
end

local function ResolveBodyHeight(frame)
	-- Never derive body from current GetHeight() — that desyncs and "sticks"
	if frame.talentedBodyHeight and frame.talentedBodyHeight > 1 then
		return frame.talentedBodyHeight
	end
	local chrome = (frame.talentedChromeHeight or 0) + 4
	local view = frame.view
	if view and view.elements then
		local treeH = 0
		for _, obj in pairs(view.elements) do
			if type(obj) == "table" and obj.topleft and obj.tab and obj.GetHeight then
				local h = obj:GetHeight() or 0
				if h > treeH then treeH = h end
			end
		end
		if treeH > 1 then
			return chrome + treeH
		end
	end
	if frame.talentedSlimHeight and frame.talentedSlimHeight > FOOTER_NONE then
		return frame.talentedSlimHeight - FOOTER_NONE
	end
	return nil
end

local function Loc(key, fallback)
	if L and L[key] then return L[key] end
	return fallback
end

local function FinishEditLabel()
	local locale = GetLocale and GetLocale() or "enUS"
	if locale == "ruRU" then return "Завершить" end
	if locale == "deDE" then return "Fertig" end
	if locale == "frFR" then return "Terminé" end
	return "Done"
end

local function SizeToolbarButton(btn)
	if not btn then return end
	StyleButtonText(btn)
	local w = btn:GetTextWidth()
	if w then
		btn:SetWidth(math.max(72, w + 22))
	end
	btn:SetHeight(22)
end

local function SyncEditModeButton(frame)
	local btn = frame and frame.bedit
	if not btn or not btn:IsShown() then return end

	local editing = Talented and Talented.mode == "edit"
	local label
	if editing then
		label = FinishEditLabel()
		if GetSkinStyle() == "SarychUI" then
			ApplyThemeFlat(btn, "buttonHover", "accent")
		else
			btn:SetBackdropBorderColor(VALUE[1], VALUE[2], VALUE[3], 1)
		end
	else
		label = btn.talentedIdleText or Loc("Edit template", "Edit template")
		if GetSkinStyle() == "SarychUI" then
			ApplyThemeFlat(btn, "buttonBg", "borderSoft")
		else
			btn:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], BORDER[4] or 1)
		end
	end

	btn:SetText(label)
	SizeToolbarButton(btn)
	local fs = btn:GetFontString()
	if fs then
		if editing then
			fs:SetTextColor(VALUE[1], VALUE[2], VALUE[3])
		else
			fs:SetTextColor(1, 0.82, 0)
		end
	end
end

local function MakeToolbarTextButton(frame, key)
	local btn = CreateFrame("Button", nil, frame)
	btn:SetHeight(22)
	btn:SetNormalFontObject(GameFontNormal)
	btn:SetHighlightFontObject(GameFontHighlight)
	btn:SetDisabledFontObject(GameFontDisable)
	HandleButton(btn)
	btn:HookScript("OnEnter", function(self)
		if self.tooltip then
			GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
			GameTooltip:SetText(self.tooltip, nil, nil, nil, nil, 1)
		end
	end)
	btn:HookScript("OnLeave", function(self)
		if GameTooltip:IsOwned(self) then
			GameTooltip:Hide()
		end
	end)
	frame[key] = btn
	return btn
end

local function EnsureEditModeButton(frame)
	if not frame then return end

	-- Hide old checkbox completely
	if frame.checkbox then
		Kill(frame.checkbox)
		if frame.checkbox.label then
			Kill(frame.checkbox.label)
		end
	end

	local btn = frame.bedit
	if not btn then
		btn = MakeToolbarTextButton(frame, "bedit")
		btn:SetScript("OnClick", function()
			if not Talented then return end
			local template = Talented.template
			local entering = Talented.mode ~= "edit"
			if entering and template and not template.talentGroup and Talented.SnapshotTemplateEdit then
				Talented:SnapshotTemplateEdit(template)
			elseif not entering and template then
				template.talentedEditSnapshot = nil
			end
			Talented:SetMode(entering and "edit" or "view")
			if frame.view then
				UpdateEditModeButtonState(frame.view)
			else
				SyncEditModeButton(frame)
			end
		end)
		btn:HookScript("OnLeave", function()
			SyncEditModeButton(frame)
		end)
	end

	if not frame.blearn then
		local learn = MakeToolbarTextButton(frame, "blearn")
		learn:SetText(Loc("Learn", "Learn"))
		learn:SetScript("OnClick", function(self)
			if not Talented then return end
			local template = Talented.template
			if template and not template.talentGroup then
				if Talented.ConfirmApplyTemplate then
					Talented:ConfirmApplyTemplate()
				end
			elseif Talented.ConfirmLearnTalentPreview then
				Talented:ConfirmLearnTalentPreview()
			end
		end)
		SizeToolbarButton(learn)
	end

	if not frame.breset then
		local reset = MakeToolbarTextButton(frame, "breset")
		reset:SetText(Loc("Reset", "Reset"))
		reset:SetScript("OnClick", function()
			if not Talented or not Talented.template then return end
			local template = Talented.template
			if template.talentGroup then
				Talented:ResetTalentPreview(template)
			elseif Talented.RestoreTemplateEditSnapshot then
				Talented:RestoreTemplateEditSnapshot(template)
			end
			if frame.view then
				UpdateEditModeButtonState(frame.view)
			end
		end)
		SizeToolbarButton(reset)
	end

	return btn
end

-- Edit = custom templates only. Live specs = Learn/Reset when preview is dirty.
-- Template edit mode also shows Apply + Reset left of Done.
function UpdateEditModeButtonState(view)
	local frame = view and view.frame
	if not frame then return end
	EnsureEditModeButton(frame)
	local btn = frame.bedit
	local learn = frame.blearn
	local reset = frame.breset
	if not btn then return end

	local template = view.template
	local activate = frame.bactivate
	if not template then
		btn:Hide()
		if learn then learn:Hide() end
		if reset then reset:Hide() end
		if activate then activate:Hide() end
		return
	end

	local isLive = template.talentGroup ~= nil
	local isActiveLive = isLive and (
		template.pet or template.talentGroup == GetActiveTalentGroup()
	)
	local dirty = isActiveLive and Talented.IsTalentPreviewDirty and Talented:IsTalentPreviewDirty(template)
	local editingTemplate = (not isLive) and Talented.mode == "edit"
	local templateDirty = editingTemplate and Talented.IsTemplateEditDirty and Talented:IsTemplateEditDirty(template)

	local function PlaceFooterActivate(show)
		if not activate then return end
		if not show then
			activate:Hide()
			return
		end
		-- Button in footer ⇒ always use the tall footer (same as points-left)
		frame.talentedFooterExpanded = true
		local y = FOOTER_CONTENT_Y
		activate:ClearAllPoints()
		activate:SetPoint("CENTER", frame, "BOTTOM", 0, y)
		activate:SetFrameLevel((frame:GetFrameLevel() or 0) + 2)
		local tw = activate:GetTextWidth()
		if tw and tw > 0 then
			activate:SetSize(tw + 40, 22)
		end
		activate:Show()
		SyncPointsLeftFooter(frame, true)
	end

	if isLive then
		btn:Hide()
		if isActiveLive then
			if activate then
				activate.talentedIsApply = nil
				activate:Hide()
			end
			if learn then
				if dirty then learn:Show() else learn:Hide() end
				learn:SetText(Loc("Learn", "Learn"))
				learn.tooltip = Loc("Confirm and learn the selected talents.", "Confirm and learn the selected talents.")
				SizeToolbarButton(learn)
			end
			if reset then
				if dirty then reset:Show() else reset:Hide() end
				reset:SetText(Loc("Reset", "Reset"))
				reset.tooltip = Loc("Reset preliminary talent allocation.", "Reset preliminary talent allocation.")
				SizeToolbarButton(reset)
			end
		else
			if learn then learn:Hide() end
			if reset then reset:Hide() end
			if activate then
				activate.talentedIsApply = nil
				activate.talentGroup = template.talentGroup
				activate:SetText(TALENT_SPEC_ACTIVATE)
				PlaceFooterActivate(true)
			end
		end
	else
		btn:Show()
		btn.talentedIdleText = Loc("Edit template", "Edit template")
		btn.tooltip = Loc("Toggle edition of the template.", "Toggle edition of the template.")
		SyncEditModeButton(frame)
		local canApply = Talented.CanApplyTemplate and Talented:CanApplyTemplate(template)
		-- Footer: Apply template when it can be learned onto the active spec
		if activate then
			if canApply then
				activate.talentedIsApply = true
				activate.talentGroup = nil
				activate:SetText(Loc("Apply template", "Apply template"))
				PlaceFooterActivate(true)
			else
				activate.talentedIsApply = nil
				activate:Hide()
			end
		end
		-- Toolbar: Reset while dirty; Apply while dirty and can learn now
		if learn then
			if templateDirty and canApply then
				learn:Show()
				learn:SetText(Loc("Apply", "Apply"))
				learn.tooltip = Loc("Apply this template to your talents.", "Apply this template to your talents.")
				SizeToolbarButton(learn)
			else
				learn:Hide()
			end
		end
		if reset then
			if templateDirty then
				reset:Show()
				reset:SetText(Loc("Reset", "Reset"))
				reset.tooltip = Loc("Reset template changes from this edit.", "Reset template changes from this edit.")
				SizeToolbarButton(reset)
			else
				reset:Hide()
			end
		end
	end

	-- Rightmost = Done/Edit; then Reset; then Apply/Learn
	local toolBar = frame.talentedToolBar
	local anchorParent = toolBar or frame
	local function PlaceRight(b, prev)
		if not b or not b:IsShown() then return prev end
		b:SetParent(anchorParent)
		b:SetFrameLevel((anchorParent:GetFrameLevel() or 0) + 2)
		b:ClearAllPoints()
		if prev then
			b:SetPoint("RIGHT", prev, "LEFT", -6, 0)
		else
			b:SetPoint("RIGHT", anchorParent, "RIGHT", -6, 0)
		end
		return b
	end
	local prev
	prev = PlaceRight(btn, prev)
	prev = PlaceRight(reset, prev)
	prev = PlaceRight(learn, prev)
end

local function LayoutMainChrome(frame, tabs)
	if not frame then return end
	tabs = tabs or 3

	local titleH = GetTitleBarH()
	local titleBar = frame.talentedTitleBar
	if not titleBar then
		titleBar = CreateFrame("Frame", nil, frame)
		frame.talentedTitleBar = titleBar

		local title = titleBar:CreateFontString(nil, "OVERLAY")
		title:SetJustifyH("CENTER")
		frame.talentedTitle = title

		local toolBar = CreateFrame("Frame", nil, frame)
		frame.talentedToolBar = toolBar
	end
	local toolBar = frame.talentedToolBar

	titleBar:ClearAllPoints()
	titleBar:SetHeight(titleH)
	titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	SetTemplate(titleBar, "Default")
	titleBar:SetFrameLevel((frame:GetFrameLevel() or 0) + 6)
	ApplyDragonflightTitleHeader(titleBar)

	if frame.talentedTitle then
		-- Soft title like WatchFrame header (no OUTLINE).
		FontTemplate(frame.talentedTitle, nil, 12, "")
		if frame.talentedActiveTab == 2 then
			frame.talentedTitle:SetText(_G.GLYPHS or "Glyphs")
		else
			frame.talentedTitle:SetText(_G.TALENTS or "Talents")
		end
		frame.talentedTitle:SetTextColor(VALUE[1], VALUE[2], VALUE[3])
		frame.talentedTitle:ClearAllPoints()
		frame.talentedTitle:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
	end

	if frame.close then
		if not frame.close.talentedSkinned then
			HandleCloseButton(frame.close, titleBar)
		end
		-- Keep a ref to the host: after SetParent(titleBar), GetParent() is the header
		frame.close.talentedHost = frame
		frame.close:SetParent(titleBar)
		frame.close:ClearAllPoints()
		if GetSkinStyle() == "SarychUI" then
			frame.close:SetSize(18, 18)
			-- Match bags: DF header art hangs slightly under the bar.
			frame.close:SetPoint("RIGHT", titleBar, "RIGHT", -10, -1)
		else
			frame.close:SetPoint("RIGHT", titleBar, "RIGHT", -4, -1)
		end
		frame.close:SetFrameLevel(titleBar:GetFrameLevel() + 1)
		frame.close.OnClick = function(self)
			HideUIPanel(self.talentedHost or frame)
		end
		frame.close:SetScript("OnClick", function(self, button)
			if button == "LeftButton" then
				HideUIPanel(self.talentedHost or frame)
			elseif Talented and Talented.OpenLockMenu then
				Talented:OpenLockMenu(self, self.talentedHost or frame)
			end
		end)
	end

	toolBar:ClearAllPoints()
	toolBar:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
	toolBar:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
	SetTemplate(toolBar, "Transparent")
	-- Keep fill, strip edge so the top seam border cannot draw.
	if toolBar.SetBackdrop then
		local bd = toolBar:GetBackdrop()
		if bd then
			local bgR, bgG, bgB, bgA = toolBar:GetBackdropColor()
			bd.edgeFile = nil
			bd.edgeSize = 0
			toolBar:SetBackdrop(bd)
			toolBar:SetBackdropColor(bgR, bgG, bgB, bgA or 1)
		end
	end
	if toolBar.SetBackdropBorderColor then
		toolBar:SetBackdropBorderColor(0, 0, 0, 0)
	end
	toolBar:SetFrameLevel((frame:GetFrameLevel() or 0) + 6)

	local bactions, bmode = frame.bactions, frame.bmode
	if bactions then bactions:SetParent(toolBar) end
	if bmode then bmode:SetParent(toolBar) end

	-- Glyphs moved to bottom tabs — remove toolbar button
	if frame.bglyphs then
		Kill(frame.bglyphs)
	end

	if bactions then bactions:ClearAllPoints() end
	if bmode then bmode:ClearAllPoints() end

	toolBar:SetHeight(TOOLBAR_H)
	if bactions then bactions:SetPoint("LEFT", toolBar, "LEFT", 6, 0) end
	if bmode and bactions then bmode:SetPoint("LEFT", bactions, "RIGHT", 8, 0) end

	-- Edit / Learn / Reset toolbar buttons
	EnsureEditModeButton(frame)
	if frame.view then
		UpdateEditModeButtonState(frame.view)
	end

	frame.talentedChromeHeight = titleH + (toolBar:GetHeight() or TOOLBAR_H)
	if frame.talentedDfFooterLine then
		frame.talentedDfFooterLine:Hide()
	end
	ApplyDragonflightToolbarLine(toolBar)

	EnsureBottomTabs(frame)
	if SkinSpecTabs then SkinSpecTabs() end

	-- Glyph tab has no toolbar: keep window height in sync when title bar height changes.
	if frame.talentedActiveTab == 2 then
		frame:SetSize(GLYPH_WINDOW_W, titleH + GLYPH_CONTENT_H)
	end
end

local function StyleBottomTab(tab, selected)
	if not tab then return end
	if selected then
		tab:SetBackdropBorderColor(VALUE[1], VALUE[2], VALUE[3], 1)
		tab:SetBackdropColor(BACKDROP[1], BACKDROP[2], BACKDROP[3], 1)
		if tab.text then
			tab.text:SetTextColor(VALUE[1], VALUE[2], VALUE[3])
		end
	else
		tab:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], BORDER[4] or 1)
		tab:SetBackdropColor(BACKDROP_FADE[1], BACKDROP_FADE[2], BACKDROP_FADE[3], BACKDROP_FADE[4] or 0.8)
		if tab.text then
			tab.text:SetTextColor(0.7, 0.7, 0.7)
		end
	end
end

local function SizeBottomTab(tab)
	if not tab or not tab.text then return end
	FontTemplate(tab.text, nil, BUTTON_FONT_SIZE, "")
	local w = tab.text:GetStringWidth() or 60
	-- Extra padding so RU labels ("Таланты" / "Символы") never crowd neighbors
	tab:SetWidth(math.max(100, w + 36))
end

local function CreateBottomTab(parent, label)
	local tab = CreateFrame("Button", nil, parent)
	tab:SetHeight(24)
	SetTemplate(tab, "Default")
	local text = tab:CreateFontString(nil, "OVERLAY")
	FontTemplate(text, nil, BUTTON_FONT_SIZE, "")
	text:SetPoint("CENTER", 0, 0)
	text:SetText(label)
	tab.text = text
	SizeBottomTab(tab)
	tab:HookScript("OnEnter", function(self)
		if parent.talentedActiveTab ~= self.tabIndex then
			self:SetBackdropBorderColor(VALUE[1], VALUE[2], VALUE[3], 0.7)
		end
	end)
	tab:HookScript("OnLeave", function(self)
		StyleBottomTab(self, parent.talentedActiveTab == self.tabIndex)
	end)
	return tab
end

SyncPointsLeftFooter = function(frame, forceShow)
	if not frame then return end
	-- Glyphs tab uses its own fixed window size
	if frame.talentedActiveTab == 2 then return end

	-- Tall footer if: forced, points-left text, OR Apply/Activate button is visible
	local act = frame.bactivate
	local pl = frame.pointsleft
	local expanded = false
	if forceShow then
		expanded = true
	elseif frame.talentedFooterExpanded then
		expanded = true
	elseif frame.talentedShowPointsLeft then
		expanded = true
	elseif act and act:IsShown() then
		expanded = true
	elseif pl and pl:IsShown() then
		expanded = true
	end
	frame.talentedFooterExpanded = expanded
	local footer = expanded and FOOTER_POINTS or FOOTER_NONE

	-- Expose sizes so core Update can apply the same numbers
	frame.talentedFooterNone = FOOTER_NONE
	frame.talentedFooterPoints = FOOTER_POINTS

	-- Same vertical center for points label + activate/apply button
	local midY = expanded and FOOTER_CONTENT_Y or 5
	local text = pl and pl.text
	if text then
		FontTemplate(text, nil, POINTS_LEFT_FONT, "")
		text:SetJustifyH("RIGHT")
		text:ClearAllPoints()
		text:SetPoint("RIGHT", frame, "BOTTOMRIGHT", -14, midY)
		if frame.talentedShowPointsLeft then
			text:SetTextColor(VALUE[1], VALUE[2], VALUE[3])
		end
	end
	if pl then
		pl:SetFrameLevel((frame:GetFrameLevel() or 0) + 2)
		pl:ClearAllPoints()
		pl:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
		pl:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
		pl:SetHeight(footer)
	end
	if act then
		act:ClearAllPoints()
		act:SetPoint("CENTER", frame, "BOTTOM", 0, midY)
		act:SetFrameLevel((frame:GetFrameLevel() or 0) + 2)
	end

	local body = ResolveBodyHeight(frame)
	if not body or body < 1 then return end

	local targetH = body + footer
	local curH = frame:GetHeight() or 0
	if frame.talentedFooterState ~= footer or math.abs(curH - targetH) > 0.5 then
		RawSetHeight(frame, targetH)
		frame.talentedFooterState = footer
		frame.talentedFooterPad = footer
		frame.talentedTalentW = frame:GetWidth()
		frame.talentedTalentH = targetH
	end
end

local function SetTalentTreesShown(frame, shown)
	local view = frame.view
	if view and view.elements then
		for _, obj in pairs(view.elements) do
			if type(obj) == "table" and obj.Hide and obj.topleft then
				if shown then obj:Show() else obj:Hide() end
			end
		end
	end
	if Talented and Talented.tabs then
		if shown then Talented.tabs:Show() else Talented.tabs:Hide() end
	end
	if shown and view then
		UpdateEditModeButtonState(view)
	else
		if frame.bedit then frame.bedit:Hide() end
		if frame.blearn then frame.blearn:Hide() end
		if frame.breset then frame.breset:Hide() end
	end
	if frame.bactivate and not shown then
		frame.bactivate:Hide()
	end
	if frame.pointsleft and not shown then
		frame.pointsleft:Hide()
	end
end

LayoutGlyphArtLeft = function(g)
	if not g or not g.background then return end
	g.background:SetWidth(GLYPH_ART_W)
	g.background:SetHeight(GLYPH_ART_H)
	g.background:ClearAllPoints()
	-- Art on the left; summary panel occupies the right side
	g.background:SetPoint("TOPLEFT", g, "TOPLEFT", GLYPH_PAD_X + GLYPH_BD, -(GLYPH_PAD_TOP + GLYPH_BD))
	if g.background.backdrop then
		g.background.backdrop:Show()
		g.background.backdrop:ClearAllPoints()
		g.background.backdrop:SetPoint("TOPLEFT", g.background, "TOPLEFT", -GLYPH_BD, GLYPH_BD)
		g.background.backdrop:SetPoint("BOTTOMRIGHT", g.background, "BOTTOMRIGHT", GLYPH_BD, -GLYPH_BD)
	end
	if g.glow then
		g.glow:ClearAllPoints()
		g.glow:SetAllPoints(g.background)
	end
end

local function MakeGlyphSummaryRow(parent, iconSize)
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(math.max(iconSize + 6, 36))
	row:EnableMouse(true)

	local iconBg = CreateFrame("Frame", nil, row)
	iconBg:SetSize(iconSize + 2, iconSize + 2)
	iconBg:SetPoint("LEFT", row, "LEFT", 0, 0)
	SetTemplate(iconBg, "Default")
	row.iconBg = iconBg

	local icon = iconBg:CreateTexture(nil, "ARTWORK")
	SetInside(icon, iconBg, 1, 1)
	ApplyIconTexCoords(icon)
	row.icon = icon

	local name = row:CreateFontString(nil, "OVERLAY")
	FontTemplate(name, nil, FONT_SIZE, "")
	name:SetJustifyH("LEFT")
	name:SetPoint("LEFT", iconBg, "RIGHT", 8, 0)
	name:SetPoint("RIGHT", row, "RIGHT", -2, 0)
	if name.SetNonSpaceWrap then
		name:SetNonSpaceWrap(false)
	end
	row.name = name

	row:SetScript("OnEnter", function(self)
		if not self.socketID then return end
		local host = _G.TalentedGlyphs
		local group = host and host.group or GetActiveTalentGroup()
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetGlyph(self.socketID, group)
		GameTooltip:Show()
		if self.iconBg and self.iconBg.SetBackdropBorderColor then
			self.iconBg:SetBackdropBorderColor(VALUE[1], VALUE[2], VALUE[3], 1)
		end
	end)
	row:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
		if self.iconBg and self.iconBg.SetBackdropBorderColor then
			self.iconBg:SetBackdropBorderColor(unpack(BORDER))
		end
	end)
	row:SetScript("OnClick", function(self)
		local host = _G.TalentedGlyphs
		local glyph = host and host.glyphs and host.glyphs[self.socketID]
		if glyph and glyph.Click then
			glyph:Click("LeftButton")
		end
	end)

	-- Subtle hover backdrop on the whole row
	SetTemplate(row, "Transparent")
	row:SetBackdropColor(0, 0, 0, 0)
	row:SetBackdropBorderColor(0, 0, 0, 0)

	return row
end

local function MakeGlyphSummarySection(parent, title, rowCount, iconSize)
	local section = CreateFrame("Frame", nil, parent)
	local header = section:CreateFontString(nil, "OVERLAY")
	FontTemplate(header, nil, BUTTON_FONT_SIZE, "")
	header:SetTextColor(VALUE[1], VALUE[2], VALUE[3])
	header:SetJustifyH("LEFT")
	header:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
	header:SetText(title)
	section.header = header

	section.rows = {}
	local prev = header
	for i = 1, rowCount do
		local row = MakeGlyphSummaryRow(section, iconSize)
		row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, i == 1 and -8 or -4)
		row:SetPoint("RIGHT", section, "RIGHT", 0, 0)
		section.rows[i] = row
		prev = row
	end

	section:SetHeight(22 + (rowCount * (math.max(iconSize + 6, 36) + 4)) + 4)
	return section
end

-- WotLK: enabled, glyphType, spell, icon
-- Some clients/patches: enabled, glyphType, tooltipIndex, spell, icon
local function ReadGlyphSocket(socketID, group)
	local enabled, gtype, a, b, c = GetGlyphSocketInfo(socketID, group)
	local spell, icon
	if c ~= nil then
		spell, icon = b, c
	else
		spell, icon = a, b
	end
	return enabled, gtype, spell, icon
end

EnsureGlyphSummaryPanel = function(frame)
	if not frame or frame.talentedGlyphSummary then return frame and frame.talentedGlyphSummary end

	local panel = CreateFrame("Frame", nil, frame)
	panel:SetWidth(GLYPH_PANEL_W)
	SetTemplate(panel, "Transparent")
	panel:SetFrameLevel((frame:GetFrameLevel() or 0) + 4)

	local majorTitle = _G.MAJOR_GLYPH or Loc("Major Glyphs", "Major Glyphs")
	local minorTitle = _G.MINOR_GLYPH or Loc("Minor Glyphs", "Minor Glyphs")

	local major = MakeGlyphSummarySection(panel, majorTitle, GLYPH_SUMMARY_ROW_COUNT, 36)
	major:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -12)
	major:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -12)
	panel.major = major

	local minor = MakeGlyphSummarySection(panel, minorTitle, GLYPH_SUMMARY_ROW_COUNT, 28)
	minor:SetPoint("TOPLEFT", major, "BOTTOMLEFT", 0, -16)
	minor:SetPoint("TOPRIGHT", major, "BOTTOMRIGHT", 0, -16)
	panel.minor = minor

	frame.talentedGlyphSummary = panel
	return panel
end

RefreshGlyphSummary = function(frame)
	frame = frame or _G.TalentedGlyphs
	if not frame then return end
	local panel = frame.talentedGlyphSummary or EnsureGlyphSummaryPanel(frame)
	if not panel then return end

	local group = frame.group or GetActiveTalentGroup()
	local emptyText = Loc("Empty", _G.EMPTY or "Empty")
	local lockedText = _G.LOCKED or "Locked"
	local numSockets = (GetNumGlyphSockets and GetNumGlyphSockets()) or 6

	-- Bucket by API glyphType (1 = major, 2 = minor) — never by hardcoded socket IDs
	local majors, minors = {}, {}
	for id = 1, numSockets do
		local enabled, gtype, spell, icon = ReadGlyphSocket(id, group)
		local entry = { id = id, enabled = enabled, spell = spell, icon = icon }
		if gtype == 2 then
			minors[#minors + 1] = entry
		else
			majors[#majors + 1] = entry
		end
	end

	local function FillSection(section, list)
		if not section or not section.rows then return end
		for i, row in ipairs(section.rows) do
			local entry = list[i]
			if not entry then
				row.socketID = nil
				row:Hide()
			else
				row:Show()
				row.socketID = entry.id
				if not entry.enabled then
					row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
					ApplyIconTexCoords(row.icon)
					row.icon:SetDesaturated(true)
					row.icon:SetVertexColor(0.45, 0.45, 0.45)
					row.name:SetText(lockedText)
					row.name:SetTextColor(0.5, 0.5, 0.5)
				elseif not entry.spell then
					row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
					ApplyIconTexCoords(row.icon)
					row.icon:SetDesaturated(true)
					row.icon:SetVertexColor(0.55, 0.55, 0.55)
					row.name:SetText(emptyText)
					row.name:SetTextColor(0.6, 0.6, 0.6)
				else
					local spellName = GetSpellInfo(entry.spell)
					row.icon:SetTexture(entry.icon or "Interface\\Spellbook\\UI-Glyph-Rune1")
					ApplyIconTexCoords(row.icon)
					row.icon:SetDesaturated(false)
					row.icon:SetVertexColor(1, 1, 1)
					row.name:SetText(spellName or ("#" .. tostring(entry.spell)))
					row.name:SetTextColor(1, 0.82, 0)
				end
			end
		end
	end

	FillSection(panel.major, majors)
	FillSection(panel.minor, minors)
end

local function LayoutGlyphSummaryPanel(g)
	local panel = EnsureGlyphSummaryPanel(g)
	if not panel then return end
	panel:ClearAllPoints()
	if g.background then
		panel:SetPoint("TOPLEFT", g.background, "TOPRIGHT", GLYPH_PANEL_GAP + GLYPH_BD, GLYPH_BD)
		panel:SetPoint("BOTTOMLEFT", g.background, "BOTTOMRIGHT", GLYPH_PANEL_GAP + GLYPH_BD, -GLYPH_BD)
	else
		panel:SetPoint("TOPRIGHT", g, "TOPRIGHT", -GLYPH_PAD_X, -GLYPH_PAD_TOP)
		panel:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", -GLYPH_PAD_X, GLYPH_PAD_BOTTOM)
	end
	panel:SetWidth(GLYPH_PANEL_W)
	panel:Show()
	RefreshGlyphSummary(g)
end

local function HookGlyphSummaryRefresh(frame)
	if not frame or frame.talentedGlyphSummaryHooked then return end
	if frame.Update then
		hooksecurefunc(frame, "Update", function(self)
			RefreshGlyphSummary(self)
		end)
	end
	if frame.glyphs then
		for _, glyph in ipairs(frame.glyphs) do
			if glyph.Update then
				hooksecurefunc(glyph, "Update", function()
					RefreshGlyphSummary(frame)
				end)
			end
		end
	end
	frame.talentedGlyphSummaryHooked = true
end

local function EmbedGlyphFrame(host)
	if not Talented then return end
	Talented:CreateGlyphFrame()
	local g = _G.TalentedGlyphs
	if not g then return end

	if not g.talentedSkinnedMain then
		SkinGlyphFrame()
	end

	if not g.talentedEmbedded then
		g.talentedEmbedded = true
		g:SetParent(host)
		-- Child of already-scaled host — keep relative scale 1 (avoid double ApplyFrameScale)
		g.talentedScaleLocked = nil
		RawSetScale(g, 1)
		g:SetFrameStrata(host:GetFrameStrata() or "DIALOG")
		g:SetFrameLevel((host:GetFrameLevel() or 0) + 3)
		if g.close then g.close:Hide() end
		if g.title then g.title:Hide() end
		if g.portrait then g.portrait:Hide() end
		if g.SetBackdrop then g:SetBackdrop(nil) end
		if g.backdrop then
			g.backdrop:Hide()
			g.backdrop:SetAlpha(0)
		end
		-- Clear Blizzard scrollbar/bottom chrome insets (0,30,0,70)
		g:SetHitRectInsets(0, 0, 0, 0)
		if UISpecialFrames then
			for i = #UISpecialFrames, 1, -1 do
				if UISpecialFrames[i] == "TalentedGlyphs" then
					table.remove(UISpecialFrames, i)
				end
			end
		end
	end

	-- Fixed content size; host window is resized to match in SelectMainTab
	local top = host.talentedTitleBar or host.talentedToolBar or host
	g:ClearAllPoints()
	g:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
	g:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT", 0, 0)
	g:SetHeight(GLYPH_CONTENT_H)
	RawSetScale(g, 1)

	LayoutGlyphArtLeft(g)
	LayoutGlyphSummaryPanel(g)

	if g.checkbox then
		g.checkbox:ClearAllPoints()
		g.checkbox:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", GLYPH_PAD_X, 10)
	end

	g:Show()
	if g.Update then g:Update() end
	RefreshGlyphSummary(g)
	return g
end

local function IsPetTalentFrame(frame)
	local view = frame and frame.view
	if view and view.pet then
		return true
	end
	local template = (view and view.template) or (Talented and Talented.template)
	local class = template and template.class
	if class and not RAID_CLASS_COLORS[class] then
		return true
	end
	return false
end

SelectMainTab = function(frame, tabIndex)
	if not frame then return end
	tabIndex = tabIndex or 1
	-- Pets have no glyphs — never switch to the Glyphs tab
	if tabIndex == 2 and IsPetTalentFrame(frame) then
		tabIndex = 1
	end
	local prev = frame.talentedActiveTab or 1
	frame.talentedActiveTab = tabIndex

	local tabTalents = frame.talentedTabTalents
	local tabGlyphs = frame.talentedTabGlyphs
	StyleBottomTab(tabTalents, tabIndex == 1)
	StyleBottomTab(tabGlyphs, tabIndex == 2)

	if frame.talentedTitle then
		if tabIndex == 1 then
			frame.talentedTitle:SetText(_G.TALENTS or "Talents")
		else
			frame.talentedTitle:SetText(_G.GLYPHS or "Glyphs")
		end
	end

	-- Toolbar only relevant for talents
	if frame.talentedToolBar then
		if tabIndex == 1 then
			frame.talentedToolBar:Show()
		else
			frame.talentedToolBar:Hide()
		end
	end

	if tabIndex == 1 then
		local g = _G.TalentedGlyphs
		if g then g:Hide() end
		-- Restore talent width only when leaving Glyphs. OnShow also calls this with
		-- prev==1 and must NOT overwrite SetClass sizing with a stale pet/glyph cache.
		if prev == 2 and frame.talentedTalentW then
			frame:SetWidth(frame.talentedTalentW)
		end
		SetTalentTreesShown(frame, true)
		local view = frame.view
		-- UpdateView requires a template — skip during early CreateBaseFrame
		if view and view.template and Talented.UpdateView then
			Talented:UpdateView()
		elseif view then
			UpdateEditModeButtonState(view)
			SyncPointsLeftFooter(frame, frame.talentedFooterExpanded)
		else
			SyncPointsLeftFooter(frame, frame.talentedFooterExpanded)
		end
	else
		-- Remember talent size before shrinking to glyph fit
		if prev ~= 2 then
			frame.talentedTalentW = frame:GetWidth()
			frame.talentedTalentH = frame:GetHeight()
		end
		frame:SetSize(GLYPH_WINDOW_W, GetTitleBarH() + GLYPH_CONTENT_H)
		SetTalentTreesShown(frame, false)
		EmbedGlyphFrame(frame)
	end
end

EnsureBottomTabs = function(frame)
	if not frame then return end

	if not frame.talentedTabTalents then
		local tabTalents = CreateBottomTab(frame, _G.TALENTS or "Talents")
		tabTalents.tabIndex = 1
		tabTalents:SetScript("OnClick", function()
			SelectMainTab(frame, 1)
			PlaySound("igCharacterInfoTab")
		end)
		frame.talentedTabTalents = tabTalents

		local tabGlyphs = CreateBottomTab(frame, _G.GLYPHS or "Glyphs")
		tabGlyphs.tabIndex = 2
		tabGlyphs:SetScript("OnClick", function()
			if IsPetTalentFrame(frame) then return end
			SelectMainTab(frame, 2)
			PlaySound("igCharacterInfoTab")
		end)
		frame.talentedTabGlyphs = tabGlyphs
	end

	local tabTalents = frame.talentedTabTalents
	local tabGlyphs = frame.talentedTabGlyphs
	SizeBottomTab(tabTalents)
	SizeBottomTab(tabGlyphs)
	tabTalents:ClearAllPoints()
	tabGlyphs:ClearAllPoints()
	-- Custom solid tabs need a real gap (Blizzard tab templates use negative overlap for art)
	tabTalents:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 10, 1)
	tabGlyphs:SetPoint("LEFT", tabTalents, "RIGHT", 4, 0)
	tabTalents:SetFrameLevel((frame:GetFrameLevel() or 0) + 8)
	tabGlyphs:SetFrameLevel((frame:GetFrameLevel() or 0) + 8)

	if not frame.talentedActiveTab then
		frame.talentedActiveTab = 1
	end

	-- Pet templates: no Glyphs and only one view — hide both bottom tabs
	local pet = IsPetTalentFrame(frame)
	if pet then
		if tabTalents then tabTalents:Hide() end
		if tabGlyphs then tabGlyphs:Hide() end
		if frame.talentedActiveTab == 2 then
			frame.talentedActiveTab = 1
			SelectMainTab(frame, 1)
		end
	else
		if tabTalents then tabTalents:Show() end
		if tabGlyphs then tabGlyphs:Show() end
	end

	StyleBottomTab(tabTalents, frame.talentedActiveTab == 1)
	StyleBottomTab(tabGlyphs, frame.talentedActiveTab == 2)
end

local function HookBaseFrameSetTabSize(frame)
	if not frame or frame.talentedSetTabSizeHooked then return end
	frame.SetTabSize = function(self, tabs)
		LayoutMainChrome(self, tabs)
	end
	frame.talentedSetTabSizeHooked = true
end

-- Spec tab icons: dedicated ARTWORK texture (CheckButton NormalTexture vanishes when checked)
local function SyncSpecTabVisual(tab)
	if not tab then return end

	-- Keep solid backdrop fill (do NOT DisableDrawLayer BACKGROUND — that kills SetBackdrop)
	if tab.SetBackdropColor then
		local br, bg, bb, ba = unpack(BACKDROP)
		tab:SetBackdropColor(br, bg, bb, ba)
	end

	local icon = tab.talentedIcon
	if not icon then
		icon = tab:CreateTexture(nil, "ARTWORK")
		icon:SetDrawLayer("ARTWORK", 1)
		SetInside(icon, tab, 2, 2)
		tab.talentedIcon = icon
	end
	ApplyIconTexCoords(icon)

	local src = tab.texture
	local path = src and src.GetTexture and src:GetTexture()
	if path and path ~= "" then
		tab.talentedIconPath = path
		icon:SetTexture(path)
	elseif tab.talentedIconPath then
		icon:SetTexture(tab.talentedIconPath)
	end
	icon:SetAlpha(1)
	icon:Show()

	-- Hide engine textures without clearing the file on tab.texture
	if src then
		src:SetAlpha(0)
		src:Hide()
	end
	if tab.pushed then tab.pushed:Hide() end
	if tab.checked then
		tab.checked:SetTexture(nil)
		tab.checked:Hide()
	end
	local checked = tab.GetCheckedTexture and tab:GetCheckedTexture()
	if checked then
		checked:SetTexture(nil)
		checked:SetAlpha(0)
		checked:Hide()
	end

	-- Selected = gold border
	if tab.GetChecked and tab:GetChecked() then
		tab:SetBackdropBorderColor(VALUE[1], VALUE[2], VALUE[3], 1)
	else
		tab:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], BORDER[4] or 1)
	end
end

SkinSpecTabs = function()
	if not Talented or not Talented.tabs or not TalentedFrame then return end

	local host = TalentedFrame
	-- Align with tree column headers (below title + toolbar)
	local yOff = -((host.talentedChromeHeight or (GetTitleBarH() + TOOLBAR_H)) + 4)
	Talented.tabs:ClearAllPoints()
	Talented.tabs:SetPoint("TOPLEFT", host, "TOPRIGHT", -1, yOff)
	Talented.tabs:SetParent(host)
	Talented.tabs:Show()
	Talented.tabs:SetFrameLevel((host:GetFrameLevel() or 0) + 10)

	for _, name in ipairs({"spec1", "spec2", "petspec1"}) do
		local tab = Talented.tabs[name]
		if tab then
			-- Allow re-skin if an older pass disabled BACKGROUND (killed backdrop fill)
			if tab.EnableDrawLayer then
				tab:EnableDrawLayer("BACKGROUND")
			end

			if not tab.isSkinned then
				-- Hide Blizzard SpellBook tab art only — keep BACKGROUND for SetBackdrop fill
				if tab.GetNumRegions then
					for i = 1, tab:GetNumRegions() do
						local region = select(i, tab:GetRegions())
						if region and region.IsObjectType and region:IsObjectType("Texture") then
							local tex = region.GetTexture and region:GetTexture()
							if tex and type(tex) == "string" and tex:find("SpellBook%-SkillLineTab") then
								region:SetTexture(nil)
								region:SetAlpha(0)
								region:Hide()
							end
						end
					end
				end

				SetTemplate(tab, "Default")
				-- Hover only — no pushed/checked overlays covering the icon
				StyleButton(tab, nil, true, true)
				if tab.SetCheckedTexture then tab:SetCheckedTexture("") end
				if tab.SetPushedTexture then tab:SetPushedTexture("") end
				if tab.SetNormalTexture then tab:SetNormalTexture("") end
				if tab.SetDisabledTexture then tab:SetDisabledTexture("") end

				if not tab.talentedIconHook then
					local origUpdate = tab.Update
					if origUpdate then
						tab.Update = function(self, ...)
							origUpdate(self, ...)
							SyncSpecTabVisual(self)
						end
					end
					tab:HookScript("OnClick", function(self)
						local parent = self:GetParent()
						if parent then
							for _, n in ipairs({"spec1", "spec2", "petspec1"}) do
								SyncSpecTabVisual(parent[n])
							end
						else
							SyncSpecTabVisual(self)
						end
					end)
					tab:HookScript("OnMouseDown", function(self)
						SyncSpecTabVisual(self)
					end)
					tab:HookScript("OnMouseUp", function(self)
						SyncSpecTabVisual(self)
					end)
					tab.talentedIconHook = true
				end
				tab.isSkinned = true
			else
				-- Re-apply solid plate if a prior session left tabs hollow
				SetTemplate(tab, "Default")
			end
			tab:SetFrameLevel((Talented.tabs:GetFrameLevel() or 0) + 1)
			SyncSpecTabVisual(tab)
		end
	end

	if not Talented.tabs.talentedCheckHook and Talented.tabs.UpdateCheck then
		local origCheck = Talented.tabs.UpdateCheck
		Talented.tabs.UpdateCheck = function(self, template, ...)
			origCheck(self, template, ...)
			for _, n in ipairs({"spec1", "spec2", "petspec1"}) do
				SyncSpecTabVisual(self[n])
			end
		end
		Talented.tabs.talentedCheckHook = true
	end

	if Talented.tabs.Update then
		Talented.tabs:Update()
	end
	if Talented.template and Talented.tabs.UpdateCheck then
		Talented.tabs:UpdateCheck(Talented.template)
	end

	Talented.tabs.talentedSkinned = true
end

local function SkinBaseFrame(frame)
	if not frame or frame.talentedSkinnedMain then return end

	RefreshMedia()
	StripTextures(frame, true)
	if frame.SetBackdrop then
		-- clear blizzard tutorial backdrop regions only; SetTemplate replaces
	end
	SetTemplate(frame, "Transparent")
	ApplyFrameScale(frame)

	-- Header chrome: drop level / points counter and selected template name
	if frame.points then Kill(frame.points) end
	if frame.editname then Kill(frame.editname) end
	if frame.targetname then Kill(frame.targetname) end

	StyleDropdownTrigger(frame.bactions)
	StyleDropdownTrigger(frame.bmode)
	HandleButton(frame.bactivate)
	if frame.bglyphs then Kill(frame.bglyphs) end

	if Talented.__HookMenuToggleButton then
		Talented.__HookMenuToggleButton(frame.bactions)
		Talented.__HookMenuToggleButton(frame.bmode)
	end

	if frame.bactivate then
		frame.bactivate:ClearAllPoints()
		frame.bactivate:SetPoint("CENTER", frame, "BOTTOM", 0, FOOTER_CONTENT_Y)
		if not frame.bactivate.talentedApplyHook then
			frame.bactivate:SetScript("OnClick", function(self)
				if self.talentedIsApply then
					if Talented and Talented.ConfirmApplyTemplate then
						Talented:ConfirmApplyTemplate()
					end
				elseif self.talentGroup then
					SetActiveTalentGroup(self.talentGroup)
				end
			end)
			frame.bactivate.talentedApplyHook = true
		end
	end

	if frame.checkbox then
		Kill(frame.checkbox)
		if frame.checkbox.label then Kill(frame.checkbox.label) end
	end
	EnsureEditModeButton(frame)

	HookBaseFrameSetTabSize(frame)
	LayoutMainChrome(frame, 3)
	EnsureBottomTabs(frame)
	-- Always open on Talents tab
	SelectMainTab(frame, 1)

	frame.talentedFooterNone = FOOTER_NONE
	frame.talentedFooterPoints = FOOTER_POINTS

	if not frame.talentedForceTalentsTab then
		frame:HookScript("OnShow", function(self)
			-- Size/class first (updates talentedTalentW), then switch to Talents tab
			if Talented and not Talented.talentedSkipActiveOnShow then
				if Talented.OpenActiveSpec then
					Talented:OpenActiveSpec()
				end
			end
			if Talented then
				Talented.talentedSkipActiveOnShow = nil
			end
			SelectMainTab(self, 1)
			EnsureBottomTabs(self)
			if SkinSpecTabs then SkinSpecTabs() end
			SyncPointsLeftFooter(self, self.talentedFooterExpanded)
		end)
		frame.talentedForceTalentsTab = true
	end

	SyncPointsLeftFooter(frame, frame.talentedFooterExpanded)

	frame.talentedSkinnedMain = true
end

SkinGlyphFrame = function()
	local frame = _G.TalentedGlyphs
	if not frame or frame.talentedSkinnedMain then return end

	RefreshMedia()
	-- Do not ApplyFrameScale here: when embedded, host already carries UI scale

	CreateBackdrop(frame, "Transparent")
	if frame.backdrop then
		-- No Blizzard scrollbar gutter (-32 right / +76 bottom)
		frame.backdrop:ClearAllPoints()
		frame.backdrop:SetAllPoints(frame)
		frame.backdrop:Hide()
		frame.backdrop:SetAlpha(0)
	end
	frame:SetHitRectInsets(0, 0, 0, 0)

	if frame.close then
		HandleCloseButton(frame.close)
		frame.close:Hide()
	end

	if frame.title then
		frame.title:ClearAllPoints()
		frame.title:SetPoint("TOP", frame, "TOP", 0, -15)
		FontTemplate(frame.title, nil, nil, "")
		frame.title:Hide()
	end

	if frame.portrait then
		frame.portrait:Hide()
	end

	if frame.background then
		frame.background:SetDrawLayer("ARTWORK")
		frame.background:SetTexCoord(0.041015625, 0.65625, 0.140625, 0.8046875)
		CreateBackdrop(frame.background, "Default")
		LayoutGlyphArtLeft(frame)
	end

	if frame.glow and frame.background then
		frame.glow:SetDrawLayer("OVERLAY")
		frame.glow:SetTexCoord(0.05859375, 0.673828125, 0.06640625, 0.73046875)
	end

	local glyphBGScale = 1.0253968
	local glyphPositions = {
		{"CENTER", -1, 126},
		{"CENTER", -1, -119},
		{"TOPLEFT", 8, -62},
		{"BOTTOMRIGHT", -10, 70},
		{"TOPRIGHT", -8, -62},
		{"BOTTOMLEFT", 7, 70},
	}

	local glyphFrameLevel = frame:GetFrameLevel() + 1
	local anchor = (frame.background and frame.background.backdrop) or frame.background or frame
	-- Re-home sparkles to art (wide host shifts frame center). Start at art CENTER.
	local art = frame.background or frame
	local sparkleOffsets = {
		{0, 83},
		{0, -83},
		{-72, 43},
		{74, -45},
		{72, 43},
		{-74, -45},
	}

	if frame.glyphs then
		for glyphID, glyph in ipairs(frame.glyphs) do
			glyph:SetFrameLevel(glyphFrameLevel)
			glyph:SetWidth(90)
			glyph:SetHeight(90)
			glyph:SetScale(glyphBGScale)

			local point, x, y = unpack(glyphPositions[glyphID])
			glyph:ClearAllPoints()
			-- ElvUI Point(point, backdrop, x, y) → SetPoint(point, relativeTo, xOfs, yOfs)
			glyph:SetPoint(point, anchor, x, y)

			local sparkle = glyph.sparkle
			local off = sparkleOffsets[glyphID]
			if sparkle and off then
				sparkle:SetDrawLayer("OVERLAY")
				sparkle:ClearAllPoints()
				sparkle:SetPoint("CENTER", art, "CENTER", 0, 0)
				if sparkle.anim and sparkle.anim.translation then
					sparkle.anim.translation:SetOffset(off[1], off[2])
				end
			end
		end
	end

	if frame.checkbox then
		HandleCheckBox(frame.checkbox)
		frame.checkbox:ClearAllPoints()
		frame.checkbox:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", GLYPH_PAD_X, 8)
	end

	EnsureGlyphSummaryPanel(frame)
	LayoutGlyphSummaryPanel(frame)
	HookGlyphSummaryRefresh(frame)

	frame.talentedSkinnedMain = true
end

---------------------------------------------------------------------------
-- Owned Talented menus (Actions / Templates / Lock).
-- Private frames on UIParent — never touch shared DropDownList1/2.
-- Chrome: Cooltip (SarychUI) / SetTemplate (ElvUI). Hover: Blizzard gold HL.
---------------------------------------------------------------------------

local MENU_ROW_H = 16
local MENU_PAD = 3
local MENU_MIN_W = 160
-- Same close delay as FrameXML UIDropDownMenu (UIDROPDOWNMENU_SHOW_TIME).
local MENU_SHOW_TIME = (UIDROPDOWNMENU_SHOW_TIME and tonumber(UIDROPDOWNMENU_SHOW_TIME)) or 2
local MENU_HL = [[Interface\QuestFrame\UI-QuestTitleHighlight]]
local MENU_CHECK = [[Interface\Buttons\UI-CheckBox-Check]]

local privateMenus = {} -- [1], [2]
local privateAnchor = nil
local privateSubOwner = nil -- level-1 row that opened the submenu
local privateShowTimer = nil
local privateIsCounting = nil
local PopulatePrivateMenu -- forward decl

local SyncPrivateMenuEscape -- forward decl

local function ClosePrivateMenus()
	for i = 1, 2 do
		local m = privateMenus[i]
		if m then
			m:Hide()
			m:SetScript("OnUpdate", nil)
		end
	end
	if privateSubOwner and privateSubOwner.hl then
		privateSubOwner.hl:Hide()
	end
	privateAnchor = nil
	privateSubOwner = nil
	privateShowTimer = nil
	privateIsCounting = nil
	if SyncPrivateMenuEscape then
		SyncPrivateMenuEscape()
	end
end

local function PrivateMenuMouseOver()
	for i = 1, 2 do
		local m = privateMenus[i]
		if m and m:IsShown() and m:IsMouseOver() then
			return true
		end
	end
	if privateAnchor and privateAnchor.IsMouseOver and privateAnchor:IsMouseOver() then
		return true
	end
	-- Parent arrow row still counts while its submenu is open (bridge / overlap).
	if privateSubOwner and privateSubOwner:IsShown() and privateSubOwner:IsMouseOver() then
		return true
	end
	return false
end

local function StopPrivateMenuCounting()
	privateIsCounting = nil
	privateShowTimer = MENU_SHOW_TIME
end

local function StartPrivateMenuCounting()
	privateShowTimer = MENU_SHOW_TIME
	privateIsCounting = true
end

local function EnsurePrivateMenuCloser(menu)
	if not menu or menu._closerHooked then return end
	menu._closerHooked = true
	menu:SetScript("OnUpdate", function(self, elapsed)
		if PrivateMenuMouseOver() then
			StopPrivateMenuCounting()
			return
		end
		if not privateIsCounting then
			StartPrivateMenuCounting()
		end
		privateShowTimer = (privateShowTimer or MENU_SHOW_TIME) - (elapsed or 0)
		if privateShowTimer < 0 then
			ClosePrivateMenus()
		end
	end)
end

local function ApplyPrivateMenuChrome(frame)
	if not frame then return end
	if GetSkinStyle() == "SarychUI" then
		local T = GetTheme()
		if T and T.ApplyFlat then
			local menuBg = (T.colors and (T.colors.headerBg or T.colors.buttonBg)) or {0.28, 0.28, 0.28, 0.95}
			local border = (T.colors and T.colors.accent) or VALUE
			T:ApplyFlat(frame, menuBg, border)
			return
		end
	end
	SetTemplate(frame, "Transparent")
end

local function EnsurePrivateMenu(level)
	level = level or 1
	local menu = privateMenus[level]
	if menu then return menu end

	menu = CreateFrame("Frame", "TalentedSarychMenu" .. level, UIParent)
	menu:SetFrameStrata("FULLSCREEN_DIALOG")
	menu:SetFrameLevel(100 + level * 10)
	menu:SetClampedToScreen(true)
	menu:EnableMouse(true)
	menu:Hide()
	menu.level = level
	menu.rows = {}
	privateMenus[level] = menu

	menu:SetScript("OnHide", function(self)
		if self.level == 1 then
			local sub = privateMenus[2]
			if sub then sub:Hide() end
			if privateAnchor and privateMenus[1] == self then
				privateAnchor = nil
			end
			privateSubOwner = nil
			self:SetScript("OnUpdate", nil)
		elseif self.level == 2 then
			if privateSubOwner and privateSubOwner.hl then
				privateSubOwner.hl:Hide()
			end
			privateSubOwner = nil
		end
		-- ESC hid this frame via UISpecialFrames — re-target the next ESC level
		if SyncPrivateMenuEscape then
			SyncPrivateMenuEscape()
		end
	end)

	return menu
end

local function HidePrivateSubmenu()
	local sub = privateMenus[2]
	if sub then sub:Hide() end
	privateSubOwner = nil
	if SyncPrivateMenuEscape then
		SyncPrivateMenuEscape()
	end
end

local function StylePrivateRowText(fs, info, inactive)
	if not fs then return end
	FontTemplate(fs, nil, BUTTON_FONT_SIZE - 1, "")
	local T = GetTheme()
	local isTitle = info and (info.isTitle or info.separator)
	local c
	if isTitle and not info.separator then
		c = (T and T.colors and T.colors.accent) or VALUE
	elseif inactive then
		c = (T and T.colors and T.colors.disabled) or {0.45, 0.45, 0.45, 1}
	else
		c = (T and T.colors and T.colors.text) or {0.92, 0.92, 0.92, 1}
	end
	fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

local function AcquirePrivateRow(menu, index)
	local row = menu.rows[index]
	if row then return row end

	row = CreateFrame("Button", nil, menu)
	row:SetHeight(MENU_ROW_H)
	row:RegisterForClicks("LeftButtonUp")

	local hl = row:CreateTexture(nil, "BACKGROUND")
	hl:SetTexture(MENU_HL)
	hl:SetBlendMode("ADD")
	hl:SetAllPoints(row)
	hl:SetAlpha(0.8)
	hl:Hide()
	row.hl = hl

	local check = row:CreateTexture(nil, "ARTWORK")
	check:SetTexture(MENU_CHECK)
	check:SetSize(12, 12)
	check:SetPoint("LEFT", 3, 0)
	check:Hide()
	row.check = check

	local arrow = row:CreateFontString(nil, "OVERLAY")
	FontTemplate(arrow, nil, BUTTON_FONT_SIZE - 1, "")
	arrow:SetPoint("RIGHT", -6, 0)
	arrow:SetText(">")
	arrow:Hide()
	row.arrow = arrow

	local text = row:CreateFontString(nil, "OVERLAY")
	FontTemplate(text, nil, BUTTON_FONT_SIZE - 1, "")
	text:SetJustifyH("LEFT")
	text:SetPoint("LEFT", 22, 0)
	text:SetPoint("RIGHT", -18, 0)
	row.text = text

	local sep = row:CreateTexture(nil, "ARTWORK")
	sep:SetTexture(BLANK)
	sep:SetHeight(1)
	sep:SetPoint("LEFT", 8, 0)
	sep:SetPoint("RIGHT", -8, 0)
	sep:SetVertexColor(1, 1, 1, 0.15)
	sep:Hide()
	row.sep = sep

	row:SetScript("OnEnter", function(self)
		-- Any row (incl. disabled) stops the close timer — same idea as Blizzard InvisibleButton.
		StopPrivateMenuCounting()
		if self._separator then return end

		local parentMenu = self:GetParent()
		local level = parentMenu and parentMenu.level or 1

		-- Level 2: only highlight; never tear down the open submenu.
		if level >= 2 then
			if not self._inactive then
				self.hl:Show()
			end
			return
		end

		local disabled = self._info and self._info.disabled
		local canOpenSub = self._hasArrow and self._menuList and not disabled
		if canOpenSub then
			if privateSubOwner and privateSubOwner ~= self and privateSubOwner.hl then
				privateSubOwner.hl:Hide()
			end
			self.hl:Show()
			privateSubOwner = self
			PopulatePrivateMenu(2, self._menuList, self)
			return
		end

		if privateSubOwner and privateSubOwner ~= self then
			if privateSubOwner.hl then privateSubOwner.hl:Hide() end
		end
		HidePrivateSubmenu()

		if self._inactive then
			return
		end
		self.hl:Show()
	end)
	row:SetScript("OnLeave", function(self)
		-- Keep parent highlight while moving into its open submenu.
		if privateSubOwner == self and privateMenus[2] and privateMenus[2]:IsShown() then
			return
		end
		self.hl:Hide()
	end)
	row:SetScript("OnClick", function(self)
		if self._separator then return end
		if self._info and self._info.disabled then return end

		local parentMenu = self:GetParent()
		local level = parentMenu and parentMenu.level or 1

		if level == 1 and self._hasArrow and self._menuList then
			StopPrivateMenuCounting()
			if privateSubOwner and privateSubOwner ~= self and privateSubOwner.hl then
				privateSubOwner.hl:Hide()
			end
			privateSubOwner = self
			self.hl:Show()
			PopulatePrivateMenu(2, self._menuList, self)
			return
		end
		if self._inactive then return end
		local info = self._info
		if info and type(info.func) == "function" then
			local checked = info.checked
			if type(checked) == "function" then
				checked = checked(self)
			end
			self.checked = checked
			info.func(self, info.arg1, info.arg2)
		end
		if not (info and info.keepShownOnClick) then
			ClosePrivateMenus()
		end
	end)

	menu.rows[index] = row
	return row
end

PopulatePrivateMenu = function(level, menuList, anchor)
	if type(menuList) ~= "table" or not anchor then return end
	level = level or 1
	local menu = EnsurePrivateMenu(level)
	ApplyPrivateMenuChrome(menu)

	if level == 1 then
		HidePrivateSubmenu()
	end

	local count = 0
	local maxTextW = 0
	for i = 1, #menuList do
		local info = menuList[i]
		if info and (info.text or info.separator) then
			count = count + 1
			local row = AcquirePrivateRow(menu, count)
			row:Show()
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", menu, "TOPLEFT", MENU_PAD, -MENU_PAD - (count - 1) * MENU_ROW_H)
			row:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -MENU_PAD, -MENU_PAD - (count - 1) * MENU_ROW_H)

			row._info = info
			row._menuList = info.menuList
			row._hasArrow = info.hasArrow and type(info.menuList) == "table"
			row._separator = info.separator and true or false
			local inactive = row._separator
				or info.disabled
				or info.isTitle
				or info.notClickable
				or false
			row._inactive = inactive and true or false

			if row._separator then
				row.text:SetText("")
				row.check:Hide()
				row.arrow:Hide()
				row.sep:Show()
				row.hl:Hide()
			else
				row.sep:Hide()
				local label = info.text or ""
				if info.colorCode and type(info.colorCode) == "string" then
					row.text:SetText(info.colorCode .. label .. "|r")
					row.text:SetTextColor(1, 1, 1, inactive and 0.55 or 1)
				else
					row.text:SetText(label)
					StylePrivateRowText(row.text, info, inactive)
				end

				local checked = info.checked
				if type(checked) == "function" then
					checked = checked(row)
				end
				if checked and not info.notCheckable then
					row.check:Show()
				else
					row.check:Hide()
				end

				if row._hasArrow then
					row.arrow:Show()
					local T = GetTheme()
					local ac = (T and T.colors and T.colors.accent) or VALUE
					row.arrow:SetTextColor(ac[1], ac[2], ac[3], inactive and 0.35 or 1)
				else
					row.arrow:Hide()
				end

				local tw = row.text:GetStringWidth() or 0
				if tw > maxTextW then maxTextW = tw end
			end
		end
	end

	for i = count + 1, #menu.rows do
		menu.rows[i]:Hide()
	end

	if count == 0 then
		menu:Hide()
		return
	end

	local width = math.max(MENU_MIN_W, maxTextW + 54)
	if level == 1 and privateAnchor and privateAnchor.GetWidth then
		local aw = privateAnchor:GetWidth() or 0
		if aw > width then width = aw end
	end
	menu:SetSize(width, MENU_PAD * 2 + count * MENU_ROW_H)

	menu:ClearAllPoints()
	if level == 1 then
		menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, 2)
	else
		-- Overlap parent row so the cursor never hits empty space (Blizzard does this).
		menu:SetPoint("TOPLEFT", anchor, "TOPRIGHT", -4, 4)
	end
	menu:Show()
	StopPrivateMenuCounting()
	EnsurePrivateMenuCloser(privateMenus[1] or menu)
	SyncPrivateMenuEscape()
end

local function ShowPrivateMenu(menuList, anchor)
	if ShouldSkip() or not menuList or not anchor then return end
	-- Never use shared EasyMenu lists for SarychUI/ElvUI owned chrome
	if HideDropDownMenu then
		HideDropDownMenu(1)
	end
	privateAnchor = anchor
	PopulatePrivateMenu(1, menuList, anchor)
	SyncPrivateMenuEscape()
end

local function IsPrivateMenuOpenFor(frame)
	return frame
		and privateAnchor == frame
		and privateMenus[1]
		and privateMenus[1]:IsShown()
end

-- ESC via UISpecialFrames only — never wrap ToggleGameMenu (causes taint:
-- "AddOn tried to call protected function").
-- While a private menu is open, park TalentedFrame so the first ESC closes
-- the menu (submenu first if open), not the whole window.
local privateParkedSpecial = {} -- names we removed from UISpecialFrames
local privateEscInList = {} -- names we added

local function UISpecialFrames_Remove(name)
	if not UISpecialFrames or not name then return false end
	for i = #UISpecialFrames, 1, -1 do
		if UISpecialFrames[i] == name then
			table.remove(UISpecialFrames, i)
			return true
		end
	end
	return false
end

local function UISpecialFrames_Add(name)
	if not UISpecialFrames or not name then return end
	for i = 1, #UISpecialFrames do
		if UISpecialFrames[i] == name then return end
	end
	UISpecialFrames[#UISpecialFrames + 1] = name
end

SyncPrivateMenuEscape = function()
	local main = privateMenus[1]
	local sub = privateMenus[2]
	local mainOpen = main and main:IsShown()
	local subOpen = sub and sub:IsShown()

	if not mainOpen and not subOpen then
		for name in pairs(privateParkedSpecial) do
			UISpecialFrames_Add(name)
			privateParkedSpecial[name] = nil
		end
		for name in pairs(privateEscInList) do
			UISpecialFrames_Remove(name)
			privateEscInList[name] = nil
		end
		return
	end

	local park = { "TalentedFrame" }
	local host = Talented and (Talented.base or TalentedFrame)
	if host and host.GetName then
		local hn = host:GetName()
		if hn and hn ~= "TalentedFrame" then
			park[#park + 1] = hn
		end
	end
	for _, name in ipairs(park) do
		if not privateParkedSpecial[name] and UISpecialFrames_Remove(name) then
			privateParkedSpecial[name] = true
		end
	end

	-- Topmost open menu only (submenu → then root), like DropDownList levels
	if subOpen then
		if privateEscInList["TalentedSarychMenu1"] then
			UISpecialFrames_Remove("TalentedSarychMenu1")
			privateEscInList["TalentedSarychMenu1"] = nil
		end
		UISpecialFrames_Add("TalentedSarychMenu2")
		privateEscInList["TalentedSarychMenu2"] = true
	else
		if privateEscInList["TalentedSarychMenu2"] then
			UISpecialFrames_Remove("TalentedSarychMenu2")
			privateEscInList["TalentedSarychMenu2"] = nil
		end
		UISpecialFrames_Add("TalentedSarychMenu1")
		privateEscInList["TalentedSarychMenu1"] = true
	end
end

local function HookDropDownMenus()
	if not Talented or Talented.__talentedDropDownHooks then return end
	Talented.__talentedDropDownHooks = true

	local origClose = Talented.CloseMenu
	function Talented:CloseMenu()
		ClosePrivateMenus()
		SyncPrivateMenuEscape()
		if type(origClose) == "function" then
			origClose(self)
		elseif HideDropDownMenu then
			HideDropDownMenu(1)
		end
	end

	-- Safe: runs after Blizzard closes its own lists, no ToggleGameMenu replace
	if type(CloseDropDownMenus) == "function" then
		hooksecurefunc("CloseDropDownMenus", function()
			ClosePrivateMenus()
			SyncPrivateMenuEscape()
		end)
	end

	local function HookMenuToggleButton(btn)
		if not btn or btn.talentedToggleHooked then return end
		btn:HookScript("OnMouseDown", function(self, button)
			if button and button ~= "LeftButton" then return end
			if IsPrivateMenuOpenFor(self) then
				Talented:CloseMenu()
				self.talentedIgnoreClick = true
			end
		end)
		btn.talentedToggleHooked = true
	end

	Talented.__HookMenuToggleButton = HookMenuToggleButton

	local function WrapOwnedMenu(orig, builder)
		return function(self, frame, ...)
			if ShouldSkip() then
				return orig(self, frame, ...)
			end
			if frame and frame.talentedIgnoreClick then
				frame.talentedIgnoreClick = nil
				return
			end
			if IsPrivateMenuOpenFor(frame) then
				self:CloseMenu()
				return
			end
			local menuList = builder(self, frame, ...)
			if type(menuList) == "table" then
				ShowPrivateMenu(menuList, frame)
			else
				orig(self, frame, ...)
			end
		end
	end

	if Talented.OpenActionMenu then
		Talented.OpenActionMenu = WrapOwnedMenu(Talented.OpenActionMenu, function(self)
			return self:MakeActionMenu()
		end)
	end
	if Talented.OpenTemplateMenu then
		Talented.OpenTemplateMenu = WrapOwnedMenu(Talented.OpenTemplateMenu, function(self)
			return self:MakeTemplateMenu()
		end)
	end
	if Talented.OpenLockMenu then
		local origLock = Talented.OpenLockMenu
		Talented.OpenLockMenu = function(self, frame, parent)
			if ShouldSkip() then
				return origLock(self, frame, parent)
			end
			if frame and frame.talentedIgnoreClick then
				frame.talentedIgnoreClick = nil
				return
			end
			if IsPrivateMenuOpenFor(frame) then
				self:CloseMenu()
				return
			end
			-- Mirror Ui.lua OpenLockMenu data, then show owned menu
			local menu = self:GetNamedMenu("LockFrame")
			local entry = menu[1]
			if not entry then
				entry = {
					text = (L and L["Lock frame"]) or "Lock frame",
					func = function(e, f)
						Talented:SetFrameLock(f, not e.checked)
					end
				}
				menu[1] = entry
			end
			entry.arg1 = parent
			entry.checked = self:GetFrameLock(parent)
			ShowPrivateMenu(menu, frame)
		end
	end
end

local function ApplyHooks()
	if not Talented or Talented.__talentedSkinHooks then return end
	Talented.__talentedSkinHooks = true

	local origCreate = Talented.CreateBaseFrame
	if origCreate then
		function Talented:CreateBaseFrame(...)
			local frame = origCreate(self, ...)
			if not ShouldSkip() then
				SkinBaseFrame(frame or TalentedFrame)
				SkinSpecTabs()
			end
			return frame
		end
	end

	local origMakeButton = Talented.MakeButton
	if origMakeButton then
		function Talented:MakeButton(parent)
			local button = origMakeButton(self, parent)
			if not ShouldSkip() then
				RefreshMedia()
				SkinTalentButton(button)
			end
			return button
		end
	end

	local origGetTarget = Talented.GetButtonTarget
	if origGetTarget then
		function Talented:GetButtonTarget(button)
			local target = origGetTarget(self, button)
			if not ShouldSkip() then
				RefreshMedia()
				SkinButtonTarget(button, target)
			end
			return target
		end
	end

	local origMakeTree = Talented.MakeTalentFrame
	if origMakeTree then
		function Talented:MakeTalentFrame(parent, width, height)
			local tree = origMakeTree(self, parent, width, height)
			if not ShouldSkip() then
				SkinTalentFrame(tree)
			end
			return tree
		end
	end

	-- Update() re-Shows rank/slot border textures — scrub chrome after each refresh
	local viewProto = Talented.TalentView and Talented.TalentView.__index
	if viewProto and viewProto.Update and not viewProto.__talentedSkinUpdateHook then
		local origUpdate = viewProto.Update
		function viewProto:Update(...)
			origUpdate(self, ...)
			if ShouldSkip() then return end
			local elements = self.elements
			if not elements then return end
			local class = self.template and self.template.class
			local treeFrames = {}
			local tabPoints = {}
			for _, obj in pairs(elements) do
				if type(obj) == "table" and obj.texture and obj.rank then
					CleanTalentButtonChrome(obj)
					if obj.texture then
						obj.texture:Show()
						obj.texture:SetAlpha(1)
						obj.texture:SetDrawLayer("ARTWORK")
						ApplyIconTexCoords(obj.texture)
					end
				elseif type(obj) == "table" and obj.topleft and obj.tab then
					ApplyTreeSolidBackground(obj)
					EnsureTreeHeader(obj)
					EnsureTreeBorder(obj)
					local points = 0
					local tab = obj.tab
					if class and self.template and self.template[tab] then
						for _, rank in pairs(self.template[tab]) do
							if type(rank) == "number" then
								points = points + rank
							end
						end
					end
					tabPoints[tab] = points
					treeFrames[#treeFrames + 1] = obj
				end
			end
			-- Primary = unique highest-point tree (same rule as Talented point string)
			local primaryTab, maxPoints = nil, -1
			for tab, points in pairs(tabPoints) do
				if points > maxPoints then
					primaryTab, maxPoints = tab, points
				end
			end
			if maxPoints <= 0 then
				primaryTab = nil
			else
				local tied = 0
				for _, points in pairs(tabPoints) do
					if points == maxPoints then
						tied = tied + 1
					end
				end
				if tied > 1 then
					primaryTab = nil
				end
			end
			for _, obj in ipairs(treeFrames) do
				local isPrimary = (obj.tab == primaryTab)
				if obj.talentedHeader then
					obj.talentedHeader.talentedIsPrimary = isPrimary
				end
				UpdateTreeHeader(obj, class, obj.tab, tabPoints[obj.tab] or 0, isPrimary)
			end
			UpdateEditModeButtonState(self)
			if self.frame then
				if self.frame.talentedActiveTab == 2 then
					-- Stay on Glyphs during updates while that tab is active
					SelectMainTab(self.frame, 2)
				else
					EnsureBottomTabs(self.frame)
					SyncPointsLeftFooter(self.frame, self.frame.talentedFooterExpanded)
				end
			end
		end
		viewProto.__talentedSkinUpdateHook = true
	end

	if Talented.SetMode and not Talented.__talentedSkinSetModeHook then
		local origSetMode = Talented.SetMode
		function Talented:SetMode(mode, ...)
			local prev = self.mode
			origSetMode(self, mode, ...)
			if not ShouldSkip() and self.base then
				local template = self.template
				if mode == "edit" and prev ~= "edit" and template and not template.talentGroup then
					if self.SnapshotTemplateEdit then
						self:SnapshotTemplateEdit(template)
					end
				elseif mode ~= "edit" and template then
					template.talentedEditSnapshot = nil
				end
				if self.base.view then
					UpdateEditModeButtonState(self.base.view)
				else
					SyncEditModeButton(self.base)
				end
			end
		end
		Talented.__talentedSkinSetModeHook = true
	end

	-- Glyphs open inside TalentedFrame via bottom tab (not a separate window)
	local function OpenGlyphsInMainFrame()
		if ShouldSkip() then return end
		Talented:CreateBaseFrame()
		local host = Talented.base or _G.TalentedFrame
		if not host then return end
		if not host:IsShown() then
			Talented:Update()
			ShowUIPanel(host)
		end
		if not host.talentedSkinnedMain then
			SkinBaseFrame(host)
		end
		EnsureBottomTabs(host)
		SelectMainTab(host, 2)
	end

	if Talented.CreateGlyphFrame then
		hooksecurefunc(Talented, "CreateGlyphFrame", function()
			if not ShouldSkip() then
				SkinGlyphFrame()
			end
		end)
	end
	if Talented.OpenGlyphFrame then
		Talented.OpenGlyphFrame = function(self)
			OpenGlyphsInMainFrame()
		end
	end
	if Talented.ToggleGlyphFrame then
		Talented.ToggleGlyphFrame = function(self)
			local host = self.base or _G.TalentedFrame
			if host and host:IsShown() and host.talentedActiveTab == 2 then
				SelectMainTab(host, 1)
				return
			end
			OpenGlyphsInMainFrame()
		end
	end
	Talented.USE_GLYPH = Talented.OpenGlyphFrame

	local origAlt = Talented.MakeAlternateView
	if origAlt then
		function Talented:MakeAlternateView(...)
			local frame = origAlt(self, ...)
			if not ShouldSkip() and frame then
				RefreshMedia()
				StripTextures(frame, true)
				SetTemplate(frame, "Transparent")
				ApplyFrameScale(frame)
				if frame.close then
					HandleCloseButton(frame.close, frame)
				end
			end
			return frame
		end
	end

	HookDropDownMenus()

	if not ShouldSkip() then
		if TalentedFrame then
			SkinBaseFrame(TalentedFrame)
			SkinSpecTabs()
		end
		if TalentedGlyphs then
			SkinGlyphFrame()
		end
	end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event, name)
	if event == "ADDON_LOADED" then
		if name == "Talented" or name == "SarychUI" then
			if ShouldSkip() then
				self:UnregisterAllEvents()
				return
			end
			ApplyHooks()
		end
	elseif event == "PLAYER_LOGIN" then
		if ShouldSkip() then
			self:UnregisterAllEvents()
			return
		end
		ApplyHooks()
		self:UnregisterAllEvents()
	end
end)

if not ShouldSkip() and Talented then
	RefreshMedia()
	ApplyHooks()
end
