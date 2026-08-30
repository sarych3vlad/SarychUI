--[[
	Built-in skins for RaidRoll (no ElvUI / ElvUI_AddOnSkins required).
	Styles:
	  ElvUI    — flat WHITE8X8 plate (mirrors ElvUI_AddOnSkins/raidRoll.lua)
	  SarychUI — Cooltip grain chrome matching SarychUI options window
	Skipped automatically if ElvUI_AddOnSkins is actively skinning RaidRoll.
]]

local MEDIA = "Interface\\AddOns\\SarychUI\\addons\\RaidRoll\\Media\\"
local BLANK = [[Interface\BUTTONS\WHITE8X8]]
local COOLTIP_BG = "Interface\\AddOns\\SarychUI\\media\\cooltip\\background"
local TEX_CLOSE = MEDIA .. "Close.tga"
local TEX_HIGHLIGHT = MEDIA .. "Highlight.tga"
local TEX_MELLI = MEDIA .. "Melli.tga"
local FONT_ELVUI = MEDIA .. "PTSansNarrow.ttf"
local FONT_SARYCH = "Fonts\\FRIZQT__.TTF"

local BORDER = {0, 0, 0, 1}
local BACKDROP = {0.1, 0.1, 0.1, 1}
local BACKDROP_FADE = {0.06, 0.06, 0.06, 0.8}
local VALUE = {1, 0.82, 0}

local ELVUI_BORDER = {0, 0, 0, 1}
local ELVUI_BACKDROP = {0.1, 0.1, 0.1, 1}
local ELVUI_BACKDROP_FADE = {0.06, 0.06, 0.06, 0.8}
local ELVUI_VALUE = {1, 0.82, 0}

local COOLTIP_BD = {
	bgFile = COOLTIP_BG,
	edgeFile = BLANK,
	tile = true,
	tileSize = 16,
	edgeSize = 1,
	insets = {left = 0, right = 0, top = 0, bottom = 0},
}

local FONT_PATH = FONT_ELVUI
local FONT_SIZE = 12
local FONT_STYLE = "OUTLINE"
local MULT = 1

local function GetElvUI()
	if ElvUI and ElvUI[1] then
		return ElvUI[1]
	end
end

local function ShouldSkip()
	local E = GetElvUI()
	if IsAddOnLoaded and IsAddOnLoaded("ElvUI_AddOnSkins") and E then
		-- Only skip when AddOnSkins will actually skin RaidRoll
		if not E.private or not E.private.addOnSkins or E.private.addOnSkins.RaidRoll ~= false then
			return true
		end
	end
	return false
end

local function GetSkinStyle()
	local addons = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons
	local style = addons and addons.RaidRoll and addons.RaidRoll.skinStyle
	if style == "ElvUI" then
		return "ElvUI"
	end
	return "SarychUI"
end

local function GetTheme()
	return SarychUI and SarychUI.OptionsTheme
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

local function ApplyThemeFlat(frame, bgKey, borderKey)
	local T = GetTheme()
	if not T or not T.ApplyFlat or not frame then return false end
	local bg = (T.colors and T.colors[bgKey or "buttonBg"]) or BACKDROP
	local border = (T.colors and T.colors[borderKey or "borderSoft"]) or BORDER
	T:ApplyFlat(frame, bg, border)
	return true
end

-- Exact default from ElvUI Settings/Global.lua → G.general.UIScale
-- ElvUI applies this via UIParent:SetScale(scale); AddOnSkins does NOT SetScale RaidRoll.
local ELVUI_DEFAULT_UISCALE = 0.7111111111111111

local function GetElvUIScale()
	local E = GetElvUI()
	if E and E.global and E.global.general and type(E.global.general.UIScale) == "number" then
		return E.global.general.UIScale
	end
	-- Account-wide saved vars if ElvUI was used before
	if ElvDB and ElvDB.global and ElvDB.global.general and type(ElvDB.global.general.UIScale) == "number" then
		return ElvDB.global.general.UIScale
	end
	return ELVUI_DEFAULT_UISCALE
end

local function RefreshMedia()
	FONT_SIZE = 12
	MULT = 1

	local style = GetSkinStyle()
	if style == "SarychUI" then
		FONT_PATH = FONT_SARYCH
		FONT_STYLE = ""
		local T = GetTheme()
		local c = T and T.colors
		if c then
			CopyColor(BORDER, c.border, ELVUI_BORDER)
			CopyColor(BACKDROP, c.headerBg or c.buttonBg, ELVUI_BACKDROP)
			CopyColor(BACKDROP_FADE, c.contentBg or c.panelBg or c.rootBg, ELVUI_BACKDROP_FADE)
			CopyColor(VALUE, c.accent or c.title, ELVUI_VALUE)
		else
			CopyColor(BORDER, {0.20, 0.20, 0.20, 1})
			CopyColor(BACKDROP, {0.28, 0.28, 0.28, 1})
			CopyColor(BACKDROP_FADE, {0.34, 0.34, 0.34, 0.60})
			CopyColor(VALUE, {0.95, 0.78, 0.15, 1})
		end
		MULT = 1
		return
	end

	-- ElvUI style
	FONT_PATH = FONT_ELVUI
	FONT_STYLE = "OUTLINE"
	CopyColor(BORDER, ELVUI_BORDER)
	CopyColor(BACKDROP, ELVUI_BACKDROP)
	CopyColor(BACKDROP_FADE, ELVUI_BACKDROP_FADE)
	CopyColor(VALUE, ELVUI_VALUE)

	local E = GetElvUI()
	if E then
		if E.media and E.media.normFont then
			FONT_PATH = E.media.normFont
		elseif E.Media and E.Media.Fonts and E.Media.Fonts.PTSansNarrow then
			FONT_PATH = E.Media.Fonts.PTSansNarrow
		end
		if E.db and E.db.general then
			FONT_SIZE = E.db.general.fontSize or FONT_SIZE
			FONT_STYLE = E.db.general.fontStyle or FONT_STYLE
		end
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
	end

	if not E or not E.mult then
		-- Same formula as ElvUI PixelPerfect.lua
		local scale = UIParent:GetScale() or 1
		local screenHeight = GetScreenHeight() or 1080
		local pixel, ratio = 1, 768 / screenHeight
		MULT = (pixel / scale) - ((pixel - ratio) / scale)
		if MULT <= 0 then MULT = 1 end
	end
end

local function Scale(x)
	local mult = MULT
	if not mult or mult <= 0 then mult = 1 end
	if not x then return 0 end
	local v = mult * math.floor(x / mult + 0.5)
	if v < 0.1 and x > 0 then v = mult end -- never return 0 for positive sizes (edgeSize crash)
	return v
end

local function RawSetFont(fs, font, fontSize, fontStyle)
	if not fs then return end
	-- Prefer metatable SetFont to avoid recursion into our hooks
	local mt = getmetatable(fs)
	local idx = mt and mt.__index
	local setFont = (type(idx) == "table" and idx.SetFont) or fs.SetFont
	if type(setFont) ~= "function" then return end
	local ok = pcall(setFont, fs, font, fontSize, fontStyle)
	if not ok then
		-- fallback to Blizzard font if custom file fails
		pcall(setFont, fs, "Fonts\\FRIZQT__.TTF", fontSize or 12, fontStyle or "OUTLINE")
	end
end

local function FontTemplate(fs, font, fontSize, fontStyle)
	if not fs then return end
	font = font or FONT_PATH
	fontSize = fontSize or FONT_SIZE
	fontStyle = fontStyle or FONT_STYLE
	if type(fontSize) ~= "number" or fontSize < 1 then fontSize = 12 end

	RawSetFont(fs, font, fontSize, fontStyle)
	if fontStyle == "NONE" or fontStyle == "" then
		local s = (MULT and MULT > 0) and MULT or 1
		fs:SetShadowOffset(s, -s / 2)
		fs:SetShadowColor(0, 0, 0, 1)
	else
		fs:SetShadowOffset(0, 0)
		fs:SetShadowColor(0, 0, 0, 0)
	end
end

local function ApplyFontToFrame(frame, depth)
	if not frame then return end
	depth = (depth or 0) + 1
	if depth > 25 then return end -- safety against cyclic parent/child graphs

	if frame.GetNumRegions then
		for i = 1, frame:GetNumRegions() do
			local region = select(i, frame:GetRegions())
			if region and region.IsObjectType and region:IsObjectType("FontString") then
				FontTemplate(region)
			end
		end
	end

	if frame.GetFontString then
		local fs = frame:GetFontString()
		if fs then FontTemplate(fs) end
	end

	local name = frame.GetName and frame:GetName()
	if name and _G[name.."Text"] then
		FontTemplate(_G[name.."Text"])
	end

	if frame.GetNumChildren then
		for i = 1, frame:GetNumChildren() do
			local child = select(i, frame:GetChildren())
			if child then
				ApplyFontToFrame(child, depth)
			end
		end
	end
end

local function HookRollerFonts()
	if GetLocale() == "zhCN" then return end
	for i = 1, 5 do
		local fs = _G["RR_Roller"..i]
		if fs and not fs.rrFontHooked then
			fs.rrFontHooked = true
			-- ElvUI pattern: clear SetFont while applying, avoid recursion crash
			local function updateFont(self, font, size, flag)
				self.SetFont = nil
				FontTemplate(self, nil, nil, flag or FONT_STYLE)
				self.SetFont = updateFont
			end
			fs.SetFont = updateFont
			FontTemplate(fs)
		end
	end
end

local function ApplyWindowScale(frame)
	if not frame then return end
	local userPct = 100
	if RaidRoll_DB and type(RaidRoll_DB["Scale"]) == "number" then
		userPct = RaidRoll_DB["Scale"]
	end
	if userPct < 1 then userPct = 1 end
	if userPct > 200 then userPct = 200 end

	-- With ElvUI: same as AddOnSkins — only RaidRoll slider; UIParent already has ElvUI UIScale
	if GetElvUI() and IsAddOnLoaded("ElvUI") then
		frame:SetScale(userPct / 100)
		return
	end

	-- Without ElvUI: absolute size = ElvUI UIScale (default 0.7111111111111111)
	local parentScale = UIParent:GetScale() or 1
	if parentScale <= 0 then parentScale = 1 end
	local elvScale = GetElvUIScale()
	local finalScale = (userPct / 100) * (elvScale / parentScale)
	if finalScale < 0.2 then finalScale = 0.2 end
	if finalScale > 3 then finalScale = 3 end
	frame:SetScale(finalScale)
end

local SetTemplate -- forward decl

local BLIZZ_TOOLTIP_BACKDROP = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 16,
	insets = {left = 5, right = 5, top = 5, bottom = 5},
}

local function FixCheckboxLabels()
	if not RAIDROLL_LOCALE then return end
	local catch = _G["RaidRoll_Catch_AllText"]
	local allow = _G["RaidRoll_Allow_AllText"]
	local extra = _G["RaidRollCheckBox_ExtraRollsText"]
	if catch then
		catch:SetText(RAIDROLL_LOCALE["Catch_Unannounced_Rolls"] or "Catch Unannounced Rolls")
		catch:SetAlpha(1)
		catch:Show()
		FontTemplate(catch)
	end
	if allow then
		allow:SetText(RAIDROLL_LOCALE["Allow_all_rolls"] or "Allow all rolls (e.g. 1-50)")
		allow:SetAlpha(1)
		allow:Show()
		FontTemplate(allow)
	end
	if extra then
		extra:SetText(RAIDROLL_LOCALE["Allow_Extra_Rolls"] or "Allow Extra Rolls")
		extra:SetAlpha(1)
		extra:Show()
		FontTemplate(extra)
	end
end

local function TextWidth(fs)
	if not fs then return 0 end
	if fs.GetStringWidth then
		local w = fs:GetStringWidth()
		if w and w > 0 then return w end
	end
	return 0
end

local function ButtonTextWidth(btn)
	if not btn then return 0 end
	local fs = btn.GetFontString and btn:GetFontString()
	local w = TextWidth(fs)
	if w <= 0 and btn.GetText then
		-- fallback estimate ~7px per char at 12pt
		local t = btn:GetText() or ""
		w = string.len(t) * 7
	end
	return w
end

local LayoutRollColumns -- forward decl (used by LayoutBottomPanel)

-- SarychUI: no in-window title; close clipped to main window corner; list starts higher.
local RR_STOCK_HEIGHT = 155

-- Y for # / Name / Roll headers (and slider aligned just above them)
local function GetListHeaderY()
	if GetSkinStyle() == "SarychUI" then
		return Scale(-14)
	end
	return Scale(-30)
end

local function EnsureRollFrameHeight()
	-- Drop the old list/button gap pad; keep clearly user-resized taller frames.
	if not RR_RollFrame or ShouldSkip() then return end
	if GetSkinStyle() ~= "SarychUI" then return end
	local h = RR_RollFrame:GetHeight() or RR_STOCK_HEIGHT
	if h <= RR_STOCK_HEIGHT + Scale(40) then
		RR_RollFrame:SetHeight(RR_STOCK_HEIGHT)
	end
end

local function HideRaidRollWindowTitle()
	if GetSkinStyle() ~= "SarychUI" then return end
	if Raid_Roll_Name then
		Raid_Roll_Name:Hide()
		Raid_Roll_Name:SetAlpha(0)
	end
	if Raid_Roll_Name_String then
		Raid_Roll_Name_String:Hide()
		Raid_Roll_Name_String:SetAlpha(0)
		Raid_Roll_Name_String:SetText("")
	end
end

-- Slider height = visible 5-row list only (not the taller window / button chrome)
local function SyncRaidRollSlider()
	if not RaidRoll_Slider_ID or not RR_RollFrame then return end
	local headerY = GetListHeaderY()
	local sliderY = headerY + Scale(5) -- stock: header -30, slider -25
	RaidRoll_Slider_ID:ClearAllPoints()
	RaidRoll_Slider_ID:SetPoint("TOPRIGHT", RR_RollFrame, "TOPRIGHT", Scale(-5), sliderY)

	local head = _G["RR_Rolled"] or _G["RR_RollerName"] or _G["RR_RollerPos"]
	local last = _G["RR_Rolled5"] or _G["RR_Roller5"] or _G["RR_RollerPos5"]
	if head and last and head.GetTop and last.GetBottom then
		local sh = head:GetTop() - last:GetBottom()
		if sh and sh >= Scale(40) then
			RaidRoll_Slider_ID:SetHeight(sh)
			return
		end
	end
	-- Stock: 155 - 75 = 80 for the five roller lines
	RaidRoll_Slider_ID:SetHeight(Scale(80))
end

-- Adaptive layout: A + Award/Announce row on main window
local function LayoutMainActionButtons()
	if not RR_RollFrame then return 0 end
	local announce = RR_Roll_5SecAndAnnounce
	local winnerBtn = RaidRoll_AnnounceWinnerButton
	if not announce then return 0 end

	local gap = Scale(4)
	local pad = Scale(10)
	local h = Scale(20)
	local aw = ButtonTextWidth(announce) + Scale(18)
	if aw < Scale(110) then aw = Scale(110) end
	announce:SetHeight(h)
	announce:SetWidth(aw)
	announce:ClearAllPoints()

	local rowW = aw
	if winnerBtn and winnerBtn:IsShown() then
		local ww = Scale(22)
		winnerBtn:SetWidth(ww)
		winnerBtn:SetHeight(h)
		winnerBtn:ClearAllPoints()
		-- Center the pair: [A][Announce...]
		announce:SetPoint("BOTTOM", RR_RollFrame, "BOTTOM", (ww + gap) / 2, Scale(31))
		winnerBtn:SetPoint("RIGHT", announce, "LEFT", -gap, 0)
		rowW = ww + gap + aw
	else
		announce:SetPoint("BOTTOM", RR_RollFrame, "BOTTOM", 0, Scale(31))
	end

	return rowW + pad * 2
end

-- Nav row: [R] [<<<] [Новый ID] [>>>] [v] — size New ID to text (RU overflows 50px)
local function LayoutNavButtons()
	if not RR_RollFrame then return 0 end

	local gap = Scale(4)
	local h = Scale(20)
	local y = Scale(8)
	local last = RR_Last
	local clear = RR_Clear
	local nextBtn = RR_Next
	local roll = RR_Roll_RollButton
	local opt = RaidRoll_OptionButton
	if not (last and clear and nextBtn) then return 0 end

	local lastW = ButtonTextWidth(last) + Scale(14)
	if lastW < Scale(34) then lastW = Scale(34) end
	local clearW = ButtonTextWidth(clear) + Scale(16)
	if clearW < Scale(50) then clearW = Scale(50) end
	local nextW = ButtonTextWidth(nextBtn) + Scale(14)
	if nextW < Scale(34) then nextW = Scale(34) end
	local rollW = Scale(20)
	local optW = Scale(20)

	last:SetHeight(h)
	clear:SetHeight(h)
	nextBtn:SetHeight(h)
	last:SetWidth(lastW)
	clear:SetWidth(clearW)
	nextBtn:SetWidth(nextW)

	-- Center on New ID, chain neighbors
	clear:ClearAllPoints()
	clear:SetPoint("BOTTOM", RR_RollFrame, "BOTTOM", 0, y)
	last:ClearAllPoints()
	last:SetPoint("RIGHT", clear, "LEFT", -gap, 0)
	nextBtn:ClearAllPoints()
	nextBtn:SetPoint("LEFT", clear, "RIGHT", gap, 0)

	if roll then
		roll:SetWidth(rollW)
		roll:SetHeight(h)
		roll:ClearAllPoints()
		roll:SetPoint("RIGHT", last, "LEFT", -gap, 0)
	end
	if opt then
		opt:SetWidth(optW)
		opt:SetHeight(optW)
		opt:ClearAllPoints()
		opt:SetPoint("LEFT", nextBtn, "RIGHT", gap, 0)
	end

	local rowW = lastW + gap + clearW + gap + nextW
	if roll then rowW = rowW + rollW + gap end
	if opt then rowW = rowW + optW + gap end
	return rowW + Scale(20)
end

-- Adaptive layout for bottom options panel + sync main window width
local function LayoutBottomPanel()
	if not RR_Frame or not RR_RollFrame then return end

	HideRaidRollWindowTitle()
	EnsureRollFrameHeight()

	local pad = Scale(10)
	local gap = Scale(6)
	local checkSize = Scale(20)
	local btnH = Scale(18)
	local rowPad = Scale(4) -- text padding after checkbox
	-- Skinned checkbox has ~4px backdrop inset; shift left so the visible box
	-- lines up with Clear Marks / Options button left edge
	local checkLeft = pad - Scale(4)

	local checks = {
		{box = RaidRoll_Catch_All, y = 75},
		{box = RaidRoll_Allow_All, y = 60},
		{box = RaidRollCheckBox_ExtraRolls, y = 45},
	}

	local needW = Scale(180)

	for _, row in ipairs(checks) do
		local box = row.box
		if box then
			box:ClearAllPoints()
			box:SetPoint("BOTTOMLEFT", RR_Frame, "BOTTOMLEFT", checkLeft, Scale(row.y))
			local name = box:GetName()
			local label = name and _G[name.."Text"]
			local lw = TextWidth(label)
			local rowW = checkLeft + checkSize + rowPad + lw + pad
			if rowW > needW then needW = rowW end
		end
	end

	-- Clear Marks / Clear Rolls — size to text, place in one row
	local clear1, clear2 = Raid_Roll_ClearSymbols, Raid_Roll_ClearRolls
	if clear1 and clear2 then
		local w1 = ButtonTextWidth(clear1) + Scale(16)
		local w2 = ButtonTextWidth(clear2) + Scale(16)
		if w1 < Scale(70) then w1 = Scale(70) end
		if w2 < Scale(70) then w2 = Scale(70) end

		clear1:SetHeight(btnH)
		clear2:SetHeight(btnH)
		clear1:SetWidth(w1)
		clear2:SetWidth(w2)
		clear1:ClearAllPoints()
		clear2:ClearAllPoints()
		clear1:SetPoint("BOTTOMLEFT", RR_Frame, "BOTTOMLEFT", pad, Scale(30))
		clear2:SetPoint("LEFT", clear1, "RIGHT", gap, 0)

		local rowW = pad + w1 + gap + w2 + pad
		if rowW > needW then needW = rowW end
	end

	-- Options button
	local opt = RaidRoll_ExtraOptionButton
	if opt then
		local ow = ButtonTextWidth(opt) + Scale(16)
		if ow < Scale(70) then ow = Scale(70) end
		opt:SetHeight(btnH)
		opt:SetWidth(ow)
		opt:ClearAllPoints()
		opt:SetPoint("BOTTOMLEFT", RR_Frame, "BOTTOMLEFT", pad, Scale(10))
		local rowW = pad + ow + pad
		if rowW > needW then needW = rowW end
	end

	-- Main window: A + Award/Announce (must not overlap)
	local actionW = LayoutMainActionButtons()
	if actionW > needW then needW = actionW end

	-- Nav row: size "Новый ID" / New ID to actual text width
	local navW = LayoutNavButtons()
	if navW > needW then needW = navW end

	if RR_RollFrame:GetWidth() and RR_RollFrame:GetWidth() > needW then
		-- don't shrink below user ExtraWidth layout, but never stay narrower than content
		needW = RR_RollFrame:GetWidth()
		-- unless content needs more:
		if actionW > needW then needW = actionW end
	end

	RR_Frame:SetWidth(needW)
	RR_Frame:ClearAllPoints()
	RR_Frame:SetPoint("TOP", RR_RollFrame, "BOTTOM", 0, Scale(1))

	if RR_RollFrame:GetWidth() < needW then
		RR_RollFrame:SetWidth(needW)
	end

	LayoutRollColumns()
end

-- Name / Rank / Roll / Group columns follow the actual frame width
LayoutRollColumns = function()
	if not RR_RollFrame then return end
	local W = RR_RollFrame:GetWidth() or 215
	-- leave room for vertical slider on the right
	local padR = Scale(22)
	local headerY = GetListHeaderY()

	local showGroup = false
	local showRank = false
	local g0 = _G["RR_Group0"]
	local r0 = _G["Raid_Roll_Rank_String0"]
	if g0 and g0.IsShown and g0:IsShown() then showGroup = true end
	if r0 and r0.IsShown and r0:IsShown() then showRank = true end
	local db = RaidRoll_DBPC and RaidRoll_DBPC[UnitName("player")]
	if db then
		if db["RR_ShowGroupNumber"] then showGroup = true end
		if db["RR_Show_Ranks"] then showRank = true end
	end

	local groupX, rollX
	if showGroup then
		groupX = W - padR - Scale(18)
		rollX = groupX - Scale(42)
	else
		rollX = W - padR - Scale(36)
	end

	-- Column headers (# / Name / Rank / Roll / Group)
	local posHeader = _G["RR_RollerPos"]
	if posHeader then
		posHeader:ClearAllPoints()
		posHeader:SetPoint("TOPLEFT", RR_RollFrame, "TOPLEFT", Scale(10), headerY)
	end
	local nameHeader = _G["RR_RollerName"]
	if nameHeader then
		nameHeader:ClearAllPoints()
		nameHeader:SetPoint("TOPLEFT", RR_RollFrame, "TOPLEFT", Scale(30), headerY)
	end

	local rolled = _G["RR_Rolled"]
	if rolled then
		rolled:ClearAllPoints()
		rolled:SetPoint("TOPLEFT", RR_RollFrame, "TOPLEFT", rollX, headerY)
	end
	if showGroup and g0 then
		g0:ClearAllPoints()
		g0:SetPoint("TOPLEFT", RR_RollFrame, "TOPLEFT", groupX, headerY)
	end

	-- Rank sits between Name and Roll
	if showRank and Raid_Roll_Rank then
		local rankX = Scale(105)
		local maxRankX = rollX - Scale(55)
		if rankX > maxRankX then rankX = math.max(Scale(90), maxRankX) end
		Raid_Roll_Rank:ClearAllPoints()
		Raid_Roll_Rank:SetPoint("TOPLEFT", RR_RollFrame, "TOPLEFT", rankX, headerY)
		local rankW = math.max(Scale(40), rollX - rankX - Scale(4))
		for i = 0, 5 do
			local rs = _G["Raid_Roll_Rank_String"..i]
			if rs and rs.SetWidth then
				rs:SetWidth(rankW)
			end
		end
	end

	-- Exact ElvUI_AddOnSkins/Skins/Addons/raidRoll.lua SetSymbol layout
	for i = 1, 5 do
		local f = _G["Raid_Roll_SetSymbol"..i]
		local pos = _G["RR_RollerPos"..i]
		local rolledRow = _G["RR_Rolled"..i]
		if f and pos and rolledRow then
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", pos, "TOPRIGHT", Scale(-15), Scale(-1))
			-- ElvUI uses +45; slightly less so it doesn't touch the slider
			f:SetPoint("BOTTOMRIGHT", rolledRow, "BOTTOMLEFT", Scale(40), Scale(-1))
			local highlight = f:GetHighlightTexture()
			if not highlight then
				f:SetHighlightTexture(TEX_HIGHLIGHT)
				highlight = f:GetHighlightTexture()
			end
			if highlight then
				highlight:SetTexture(TEX_HIGHLIGHT)
				highlight:SetVertexColor(0.9, 0.9, 0.9, 0.35)
			end
		end
	end

	SyncRaidRollSlider()
end

-- Only for RaidRoll help tips (R button etc). Never leave item tooltips skinned.
local function StyleRaidRollHelpTooltip(tt)
	if not tt or ShouldSkip() then return end
	RefreshMedia()
	SetTemplate(tt, "Transparent")
	tt.rrHelpTipStyled = true
end

local function RestoreItemTooltip(tt)
	if not tt or not tt.rrHelpTipStyled then return end
	tt:SetBackdrop(BLIZZ_TOOLTIP_BACKDROP)
	local bg = TOOLTIP_DEFAULT_BACKGROUND_COLOR
	local bd = TOOLTIP_DEFAULT_COLOR
	if bg then
		tt:SetBackdropColor(bg.r, bg.g, bg.b)
	else
		tt:SetBackdropColor(0.09, 0.09, 0.19)
	end
	if bd then
		tt:SetBackdropBorderColor(bd.r, bd.g, bd.b)
	else
		tt:SetBackdropBorderColor(1, 1, 1)
	end
	tt.rrHelpTipStyled = nil
end

local function StripTextures(frame)
	if not frame then return end
	if frame.GetNumRegions then
		local n = frame:GetNumRegions()
		for i = 1, n do
			local region = select(i, frame:GetRegions())
			if region and region.IsObjectType and region:IsObjectType("Texture") then
				region:SetTexture(nil)
				region:SetAlpha(0)
			end
		end
	end
	if frame.SetNormalTexture then frame:SetNormalTexture("") end
	if frame.SetPushedTexture then frame:SetPushedTexture("") end
	if frame.SetDisabledTexture then frame:SetDisabledTexture("") end
	if frame.SetHighlightTexture then frame:SetHighlightTexture("") end
end

SetTemplate = function(frame, template)
	if not frame then return end
	local br, bg, bb, ba = unpack(BACKDROP)
	local er, eg, eb, ea = unpack(BORDER)
	if template == "Transparent" then
		br, bg, bb, ba = unpack(BACKDROP_FADE)
	end

	if GetSkinStyle() == "SarychUI" then
		local T = GetTheme()
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
	frame:SetBackdropColor(br, bg, bb, ba)
	frame:SetBackdropBorderColor(er, eg, eb, ea)
	frame.rrSkinned = true
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
	if not button or button.rrSkinned then return end

	local name = button.GetName and button:GetName()
	if name then
		local left = _G[name.."Left"]
		local middle = _G[name.."Middle"]
		local right = _G[name.."Right"]
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

	if GetSkinStyle() == "SarychUI" then
		ApplyThemeFlat(button, "buttonBg", "borderSoft")
	else
		SetTemplate(button, "Default")
	end
	button:HookScript("OnEnter", SetModifiedBackdrop)
	button:HookScript("OnLeave", SetOriginalBackdrop)

	local fs = button:GetFontString()
	if fs then FontTemplate(fs) end

	button.rrSkinned = true
end

local function HandleCheckBox(frame)
	if not frame or frame.rrSkinned then return end

	-- Strip only checkbox textures; keep FontString label intact
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
		bd:SetPoint("TOPLEFT", frame, "TOPLEFT", Scale(4), Scale(-4))
		bd:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", Scale(-4), Scale(4))
		SetTemplate(bd, "Default")
		local level = frame:GetFrameLevel()
		if level and level > 0 then
			bd:SetFrameLevel(level - 1)
		else
			bd:SetFrameLevel(0)
		end
		frame.backdrop = bd
	end

	if frame.SetCheckedTexture then
		frame:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
		local checked = frame:GetCheckedTexture()
		if checked then
			checked:SetAlpha(1)
			checked:ClearAllPoints()
			checked:SetPoint("TOPLEFT", frame.backdrop, "TOPLEFT", Scale(-4), Scale(4))
			checked:SetPoint("BOTTOMRIGHT", frame.backdrop, "BOTTOMRIGHT", Scale(4), Scale(-4))
		end
	end
	if frame.SetDisabledCheckedTexture then
		frame:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
	end

	local name = frame:GetName()
	local label = name and _G[name.."Text"]
	if label then
		label:SetAlpha(1)
		label:Show()
		-- Keep label above skinned box
		if label.SetDrawLayer then label:SetDrawLayer("OVERLAY") end
		FontTemplate(label)
	end

	frame.rrSkinned = true
end

local function HandleCloseButton(f, point)
	if not f or f.rrSkinned then return end
	StripTextures(f)
	if f.SetNormalTexture then f:SetNormalTexture("") end
	if f.SetPushedTexture then f:SetPushedTexture("") end
	if f.SetHighlightTexture then f:SetHighlightTexture("") end
	if f.SetDisabledTexture then f:SetDisabledTexture("") end

	if GetSkinStyle() == "SarychUI" then
		-- Same as SarychUI options: 22×22 Cooltip plate + FontString "X"
		f:SetSize(Scale(22), Scale(22))
		f:SetHitRectInsets(0, 0, 0, 0)
		ApplyThemeFlat(f, "buttonBg", "borderSoft")

		if not f.rrCloseX then
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
			f.rrCloseX = x
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
			f.Texture:SetWidth(Scale(12))
			f.Texture:SetHeight(Scale(12))
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
			-- Outside the Cooltip plate, flush to the right edge
			f:SetPoint("TOPLEFT", point, "TOPRIGHT", Scale(1), Scale(-6))
		else
			f:SetPoint("TOPRIGHT", point, "TOPRIGHT", Scale(2), Scale(3))
		end

	end
	f.rrSkinned = true
end

local function HandleSliderFrame(frame)
	if not frame or frame.rrSkinned then return end
	StripTextures(frame)
	SetTemplate(frame, "Default")
	frame:SetThumbTexture(TEX_MELLI)
	local thumb = frame:GetThumbTexture()
	if thumb then
		thumb:SetVertexColor(VALUE[1], VALUE[2], VALUE[3], 0.8)
		thumb:SetWidth(Scale(10))
		thumb:SetHeight(Scale(10))
	end
	local orientation = frame:GetOrientation()
	if orientation == "VERTICAL" then
		frame:SetWidth(Scale(12))
	else
		frame:SetHeight(Scale(12))
	end
	frame.rrSkinned = true
end

local function RePoint(frame, ...)
	local n = select("#", ...)
	local a1, a2, a3, a4, a5 = ...
	-- Scale numeric offsets (last 1–2 args), matching ElvUI Point()
	if n >= 5 and type(a5) == "number" then
		a5 = Scale(a5)
		a4 = Scale(a4)
	elseif n >= 4 and type(a4) == "number" then
		a4 = Scale(a4)
		if type(a3) == "number" then a3 = Scale(a3) end
	elseif n >= 3 and type(a3) == "number" then
		a3 = Scale(a3)
		if type(a2) == "number" then a2 = Scale(a2) end
	end
	frame:ClearAllPoints()
	frame:SetPoint(a1, a2, a3, a4, a5)
end

local function SkinRaidRoll()
	if ShouldSkip() then return end
	if not RR_RollFrame then return end
	if not RR_Roll_RollButton then return end

	RefreshMedia()

	if not RR_RollFrame.rrSkinnedMain then
		SetTemplate(RR_RollFrame, "Transparent")
		if RR_NAME_FRAME then
			SetTemplate(RR_NAME_FRAME, "Default")
		end

		HideRaidRollWindowTitle()
		if RR_Close_Button then
			HandleCloseButton(RR_Close_Button, RR_RollFrame)
		end

		if RaidRoll_Slider_ID then
			RaidRoll_Slider_ID:SetHitRectInsets(0, 0, 0, 0)
			HandleSliderFrame(RaidRoll_Slider_ID)
		end

		HandleButton(RaidRoll_AnnounceWinnerButton)
		HandleButton(RR_Roll_5SecAndAnnounce)
		HandleButton(RR_Roll_RollButton)
		HandleButton(RR_Last)
		HandleButton(RR_Clear)
		HandleButton(RR_Next)
		HandleButton(RaidRoll_OptionButton)
		-- Nav / action rows are laid out in LayoutBottomPanel()

		if RR_Frame then
			SetTemplate(RR_Frame, "Transparent")
			RePoint(RR_Frame, "TOP", RR_RollFrame, "BOTTOM", 0, 1)

			local rrframeLevel = RR_Frame:GetFrameLevel()
			if RaidRoll_Catch_All then RaidRoll_Catch_All:SetFrameLevel(rrframeLevel + 2) end
			if RaidRoll_Allow_All then RaidRoll_Allow_All:SetFrameLevel(rrframeLevel + 2) end
			if RaidRollCheckBox_ExtraRolls then RaidRollCheckBox_ExtraRolls:SetFrameLevel(rrframeLevel + 2) end
		end

		HandleCheckBox(RaidRoll_Catch_All)
		HandleCheckBox(RaidRoll_Allow_All)
		HandleCheckBox(RaidRollCheckBox_ExtraRolls)

		HandleButton(Raid_Roll_ClearSymbols)
		HandleButton(Raid_Roll_ClearRolls)
		HandleButton(RaidRoll_ExtraOptionButton)

		RR_RollFrame.rrSkinnedMain = true
	end

	-- Fonts + scale: re-apply (safe to run more than once)
	ApplyFontToFrame(RR_RollFrame)
	ApplyFontToFrame(RR_Frame)
	ApplyFontToFrame(RR_NAME_FRAME)
	HookRollerFonts()
	FixCheckboxLabels()
	LayoutBottomPanel()
	ApplyWindowScale(RR_RollFrame)
	-- Re-layout after scale so string widths match final fonts
	LayoutBottomPanel()
end

local function SkinLootTracker()
	if ShouldSkip() then return end
	if not RR_LOOT_FRAME then return end
	if not RR_Loot_LinkLootButton then return end

	RefreshMedia()

	if not RR_LOOT_FRAME.rrSkinnedLoot then
		SetTemplate(RR_LOOT_FRAME, "Transparent")

		if RaidRoll_Loot_Slider_ID then
			HandleSliderFrame(RaidRoll_Loot_Slider_ID)
		end

		HandleButton(RR_Loot_LinkLootButton)
		HandleButton(RR_Loot_ButtonClear)
		HandleButton(RR_Loot_ButtonFirst)
		HandleButton(RR_Loot_ButtonPrev)
		HandleButton(RR_Loot_ButtonNext)
		HandleButton(RR_Loot_ButtonLast)

		for i = 1, 4 do
			local a1 = _G["RR_Loot_Announce_1_Button_"..i]
			local a2 = _G["RR_Loot_Announce_2_Button_"..i]
			local a3 = _G["RR_Loot_Announce_3_Button_"..i]
			local rr = _G["RR_Loot_RaidRollButton_"..i]
			if a1 then a1:Show(); HandleButton(a1) end
			if a2 then a2:Show(); HandleButton(a2) end
			if a3 then a3:Show(); HandleButton(a3) end
			if rr then rr:Show(); HandleButton(rr) end
		end

		for i = 1, RR_LOOT_FRAME:GetNumChildren() do
			local child = select(i, RR_LOOT_FRAME:GetChildren())
			if child and child:IsObjectType("Button") and child:GetName() == "Close_Button" then
				HandleCloseButton(child, RR_LOOT_FRAME)
				break
			end
		end

		RR_LOOT_FRAME.rrSkinnedLoot = true
	end

	ApplyFontToFrame(RR_LOOT_FRAME)
	ApplyWindowScale(RR_LOOT_FRAME)
end

local function TrySkinAll()
	if ShouldSkip() then return end
	local ok, err = pcall(function()
		RefreshMedia()
		SkinRaidRoll()
		SkinLootTracker()
	end)
	if not ok and DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff5555RaidRoll skin error:|r "..tostring(err))
	end
end

local function HookScaleSlider()
	if not RaidRoll_Scale_Slider or RaidRoll_Scale_Slider.rrScaleHooked then return end
	RaidRoll_Scale_Slider.rrScaleHooked = true
	RaidRoll_Scale_Slider:HookScript("OnValueChanged", function()
		if ShouldSkip() then return end
		ApplyWindowScale(RR_RollFrame)
		ApplyWindowScale(RR_LOOT_FRAME)
	end)
end

local function HookTooltips()
	if GameTooltip and not GameTooltip.rrRaidRollTipHooked then
		GameTooltip.rrRaidRollTipHooked = true
		GameTooltip:HookScript("OnHide", function(tt)
			RestoreItemTooltip(tt)
		end)
		GameTooltip:HookScript("OnShow", function(tt)
			-- Item/spell tips must keep default Blizzard textures
			if tt.GetItem and tt:GetItem() then
				RestoreItemTooltip(tt)
			end
		end)
	end
	if type(hooksecurefunc) == "function" and type(RR_MouseOverTooltip) == "function" and not _G.RR_MouseOverTooltip_SkinHooked then
		_G.RR_MouseOverTooltip_SkinHooked = true
		hooksecurefunc("RR_MouseOverTooltip", function()
			if ShouldSkip() then return end
			-- Help tip only (R / checkboxes) — never item compare tips
			StyleRaidRollHelpTooltip(GameTooltip)
			if GameTooltip and not GameTooltip:IsShown() then
				GameTooltip:Show()
			end
		end)
	end
end

-- Apply after RaidRoll builds its dynamic frames
if type(hooksecurefunc) == "function" then
	if type(RR_ExtraFrame_Options) == "function" then
		hooksecurefunc("RR_ExtraFrame_Options", function()
			TrySkinAll()
			HookTooltips()
		end)
	end
	if type(Setup_RR_Panel) == "function" then
		hooksecurefunc("Setup_RR_Panel", function()
			TrySkinAll()
			HookScaleSlider()
			HookTooltips()
			-- Setup_RR_Panel resets SetScale(user/100); re-apply Elv compensation after it
			ApplyWindowScale(RR_RollFrame)
			ApplyWindowScale(RR_LOOT_FRAME)
			FixCheckboxLabels()
			LayoutBottomPanel()
		end)
	end
	-- Re-flow when ranks/width options change or options panel toggles
	if type(RaidRoll_CheckButton_Update) == "function" then
		hooksecurefunc("RaidRoll_CheckButton_Update", LayoutBottomPanel)
	end
	if type(RaidRoll_CheckButton_Update_Panel) == "function" then
		hooksecurefunc("RaidRoll_CheckButton_Update_Panel", LayoutBottomPanel)
	end
	if type(RR_Roll_Options_Toggle) == "function" then
		hooksecurefunc("RR_Roll_Options_Toggle", LayoutBottomPanel)
	end
	if type(RR_RollFrame_SortOutSize) == "function" then
		hooksecurefunc("RR_RollFrame_SortOutSize", LayoutBottomPanel)
	end
	-- A button show/hide + Award text changes here
	if type(RR_Update_Name_Frame) == "function" then
		hooksecurefunc("RR_Update_Name_Frame", LayoutBottomPanel)
	end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("VARIABLES_LOADED")
boot:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == "RaidRoll_LootTracker" or arg1 == "RaidRoll" or arg1 == "SarychUI" then
			TrySkinAll()
			HookTooltips()
		end
	else
		TrySkinAll()
		HookScaleSlider()
		HookTooltips()
		FixCheckboxLabels()
		if not self.retried then
			self.retried = true
			local t = 0
			self:SetScript("OnUpdate", function(frame, elapsed)
				t = t + elapsed
				if t > 0.5 then
					frame:SetScript("OnUpdate", nil)
					TrySkinAll()
					HookScaleSlider()
					HookTooltips()
					FixCheckboxLabels()
				end
			end)
		end
	end
end)
