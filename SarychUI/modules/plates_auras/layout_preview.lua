-- SarychUI Plates Auras — live layout preview for options (sizes / positions).
-- Sticky mock nameplate matching in-game anchors; active slider slot is highlighted yellow.

local CreateFrame = CreateFrame
local pairs = pairs
local ipairs = ipairs
local type = type
local tonumber = tonumber
local tostring = tostring
local tinsert = table.insert
local pcall = pcall
local math_max = math.max
local math_min = math.min
local math_floor = math.floor

SarychUI = SarychUI or {}
SarychUI.PlatesAurasLayoutPreview = SarychUI.PlatesAurasLayoutPreview or {}
local Preview = SarychUI.PlatesAurasLayoutPreview

local PREVIEW_H = 210
local NOTICE_H = 18
local PLATE_W = 128
local PLATE_H = 12
local DIM_A = 0.40
local ACTIVE_A = 1
local ACTIVE_BORDER = { 1, 0.82, 0.2, 1 }
local DIM_BORDER = { 0.35, 0.35, 0.38, 0.7 }
local SLOT_FILL = { 0.12, 0.12, 0.14, 0.95 }
local ACTIVE_FILL = { 0.32, 0.26, 0.06, 0.98 }

local SAMPLE_ICONS = {
	control = "Interface\\Icons\\Spell_Nature_Polymorph",
	cast = "Interface\\Icons\\Spell_Shadow_PsychicScream",
	mobility = "Interface\\Icons\\Ability_Rogue_Trip",
	other = "Interface\\Icons\\Spell_Holy_DivineProtection",
	player = "Interface\\Icons\\Ability_Warrior_Charge",
}

-- Maps option keys to which slot(s) to highlight.
local KEY_TO_SLOT = {
	ICON_SIZE_CONTROL = "control",
	ICON_SIZE_CAST = "cast",
	ICON_SIZE_MOBILITY = "mobility",
	ICON_SIZE_OTHER = "other",
	ICON_SIZE_PLAYER = "player",
	ICON_SIZE_PLAYER_WIDTH = "player",
	ICON_SIZE_PLAYER_HEIGHT = "player",
	MAX_PLAYER_AURAS = "player",
	spacing = "player",
	CentrY = "center",
	CastX = "cast",
	CastY = "cast",
	PlayerOffsetY = "player",
	RightX = "right",
	RightY = "right",
	OtherX = "other",
	OtherY = "other",
	alpha = "all",
	scale = "all",
	-- ElvUI responsive scale (center) / proportional offset keys.
	["center.enabled"] = "center",
	["center.factor"] = "center",
	["center.maxBonus"] = "center",
	["center.offsetMode"] = "center",
	["center.widthFactor"] = "center",
	["center.heightFactor"] = "center",
	["player.offsetMode"] = "player",
	["player.widthFactor"] = "player",
	["player.heightFactor"] = "player",
	["player.altRight"] = "player",
	["right.offsetMode"] = "right",
	["right.widthFactor"] = "right",
	["right.heightFactor"] = "right",
}

-- Preview simulates an enlarged ElvUI plate so center growth / proportional offsets show.
local PREVIEW_ELVUI_PLATE_SCALE = 1.3

local RESPONSIVE_SCALE_DEFAULTS = {
	center = { enabled = true, factor = 0.55, maxBonus = 0.20 },
}

Preview._instances = Preview._instances or {}
Preview._activeKey = nil
Preview._live = Preview._live or {}

local function Module()
	return SarychUI and SarychUI.GetModule and SarychUI:GetModule("plates_auras")
end

local function DisplayProfile()
	local mod = Module()
	if mod and mod.EnsureProfiles then
		mod:EnsureProfiles()
	end
	if mod and mod.GetActiveDisplayProfile then
		return mod:GetActiveDisplayProfile()
	end
	return nil
end

local function ReadSizes()
	local p = DisplayProfile()
	return (p and p.sizes) or {}
end

local function ReadPositions()
	local p = DisplayProfile()
	return (p and p.positions) or {}
end

local function ReadDisplay()
	local p = DisplayProfile()
	return (p and p.display) or {}
end

local function ReadPlayerSpacing()
	local p = DisplayProfile()
	local layout = p and p.layout and p.layout.player
	return (layout and layout.spacing) or 2
end

local function IsElvUIPreviewMode()
	local mod = Module()
	return mod and mod.GetActiveProfileMode and mod:GetActiveProfileMode() == "elvui"
end

local function ReadLayoutSlot(slotName)
	local p = DisplayProfile()
	local layout = p and p.layout and p.layout[slotName]
	return layout or {}
end

local function ReadResponsiveScale(slotName)
	local p = DisplayProfile()
	local cfg = p and p.plateResponsiveScale and p.plateResponsiveScale[slotName]
	local defaults = RESPONSIVE_SCALE_DEFAULTS[slotName] or {}
	if type(cfg) ~= "table" then
		return {
			enabled = defaults.enabled,
			factor = defaults.factor,
			maxBonus = defaults.maxBonus,
		}
	end
	local enabled = cfg.enabled
	if enabled == nil then enabled = defaults.enabled end
	local factor = cfg.factor
	if factor == nil then factor = defaults.factor end
	local maxBonus = cfg.maxBonus
	if maxBonus == nil then maxBonus = defaults.maxBonus end
	return {
		enabled = enabled,
		factor = factor,
		maxBonus = maxBonus,
	}
end

local function LiveOrSlot(slotName, key, fallback)
	local compound = tostring(slotName) .. "." .. tostring(key)
	local live = Preview._live[compound]
	if live ~= nil then
		return live
	end
	return fallback
end

local function LiveOr(key, fallback)
	local live = Preview._live[key]
	if live ~= nil then
		return live
	end
	return fallback
end

local function Num(v, default)
	v = tonumber(v)
	if v == nil then return default end
	return v
end

-- Checkbox widgets push 1/0 (and 0 is truthy in Lua). Only true/1 count as on.
local function FlagOn(v)
	return v == true or v == 1
end

local function ResponsiveBonus(slotName, plateScale)
	local defaults = RESPONSIVE_SCALE_DEFAULTS[slotName] or {}
	local cfg = ReadResponsiveScale(slotName)
	local enabled = LiveOrSlot(slotName, "enabled", cfg.enabled)
	if enabled == nil then
		enabled = defaults.enabled
	end
	if enabled == false then
		return 0
	end
	local factor = Num(LiveOrSlot(slotName, "factor", cfg.factor), defaults.factor or 0)
	local maxBonus = Num(LiveOrSlot(slotName, "maxBonus", cfg.maxBonus), defaults.maxBonus or 0)
	local delta = math_max(0, (plateScale or 1) - 1)
	return math_min(maxBonus, delta * factor)
end

local function ProportionalExtra(slotName, plateW, plateH)
	local slot = ReadLayoutSlot(slotName)
	local mode = LiveOrSlot(slotName, "offsetMode", slot.offsetMode)
	-- Toggle widgets push boolean live values; profile stores "proportional"/"fixed".
	local proportional = (mode == "proportional") or (mode == true)
	if not proportional then
		return 0, 0
	end
	local wf = Num(LiveOrSlot(slotName, "widthFactor", slot.widthFactor), 0)
	local hf = Num(LiveOrSlot(slotName, "heightFactor", slot.heightFactor), 0)
	return plateW * wf, plateH * hf
end

local function IsActive(slotName)
	local key = Preview._activeKey
	if not key then return false end
	local mapped = KEY_TO_SLOT[key]
	if mapped == "all" then return true end
	if mapped == "center" then
		return slotName == "control" or slotName == "cast" or slotName == "center"
	end
	if mapped == "right" then
		return slotName == "mobility" or slotName == "other" or slotName == "right"
	end
	return mapped == slotName
end

local function ApplySlotStyle(frame, active)
	if not frame then return end
	if frame.bg then
		local f = active and ACTIVE_FILL or SLOT_FILL
		frame.bg:SetVertexColor(f[1], f[2], f[3], f[4])
	end
	if frame.border then
		local b = active and ACTIVE_BORDER or DIM_BORDER
		frame.border:SetVertexColor(b[1], b[2], b[3], b[4])
	end
	if frame.icon then
		frame.icon:SetDesaturated(not active)
		frame.icon:SetAlpha(active and 1 or 0.55)
	end
	if frame.label then
		if active then
			frame.label:SetTextColor(1, 0.82, 0.2, 1)
		else
			frame.label:SetTextColor(0.65, 0.65, 0.68, 0.75)
		end
	end
end

local function ApplySquareIcon(icon)
	if not icon then return end
	icon:ClearAllPoints()
	icon:SetPoint("TOPLEFT", 1, -1)
	icon:SetPoint("BOTTOMRIGHT", -1, 1)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
end

-- Match in-game CreateAuraIcon crop for rectangular player strip icons.
local function ApplyPlayerIconCrop(icon, size, width, height)
	if not icon then return end
	size = math_max(1, size or 28)
	width = math_max(1, width or size)
	height = math_max(1, height or (size * 0.67))
	icon:ClearAllPoints()
	icon:SetSize(width, height)
	icon:SetPoint("CENTER", icon:GetParent(), "CENTER", 0, 0)
	local imageScale = 1.17
	local cropAmount = (imageScale - 1) / (2 * imageScale)
	local cropTop = (size - height) / (2 * size)
	if cropTop < 0 then cropTop = 0 end
	if cropTop > 0.45 then cropTop = 0.45 end
	local cropBottom = 1 - cropTop
	local finalCropTop = cropTop + cropAmount
	local finalCropBottom = cropBottom - cropAmount
	local finalCropLeft = cropAmount
	local finalCropRight = 1 - cropAmount
	icon:SetTexCoord(finalCropLeft, finalCropRight, finalCropTop, finalCropBottom)
end

local function MakeSlot(parent, iconPath, labelText)
	local f = CreateFrame("Frame", nil, parent)
	f:SetFrameLevel((parent:GetFrameLevel() or 1) + 2)

	local border = f:CreateTexture(nil, "BACKGROUND")
	border:SetPoint("TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", 1, -1)
	border:SetTexture("Interface\\Buttons\\WHITE8X8")
	border:SetVertexColor(DIM_BORDER[1], DIM_BORDER[2], DIM_BORDER[3], DIM_BORDER[4])
	f.border = border

	local bg = f:CreateTexture(nil, "ARTWORK")
	bg:SetAllPoints()
	bg:SetTexture("Interface\\Buttons\\WHITE8X8")
	bg:SetVertexColor(SLOT_FILL[1], SLOT_FILL[2], SLOT_FILL[3], SLOT_FILL[4])
	f.bg = bg

	local icon = f:CreateTexture(nil, "OVERLAY")
	icon:SetTexture(iconPath or "Interface\\Icons\\INV_Misc_QuestionMark")
	ApplySquareIcon(icon)
	f.icon = icon

	if labelText then
		local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		fs:SetPoint("BOTTOM", f, "TOP", 0, 1)
		fs:SetText(labelText)
		fs:SetTextColor(0.65, 0.65, 0.68, 0.75)
		f.label = fs
	end
	return f
end

function Preview:SetActiveKey(key)
	self._activeKey = key
	if SarychUI and SarychUI.ApplyOptionsPreviewLive then
		SarychUI.ApplyOptionsPreviewLive(self, key, self._live[key])
	else
		self:RefreshAll()
	end
end

function Preview:SetLiveValue(key, value)
	if key == nil then return end
	self._live[key] = value
	self._activeKey = key
	if SarychUI and SarychUI.ApplyOptionsPreviewLive then
		SarychUI.ApplyOptionsPreviewLive(self, key, value)
	else
		for _, inst in ipairs(self._instances) do
			if inst and inst.LayoutLive then
				inst:LayoutLive(key)
			elseif inst and inst.RefreshLayout then
				inst:RefreshLayout()
			end
		end
	end
end

function Preview:ClearLiveValue(key)
	if key then
		self._live[key] = nil
	else
		for k in pairs(self._live) do
			self._live[k] = nil
		end
	end
	if SarychUI and SarychUI.IsOptionsSliderDragging and SarychUI.IsOptionsSliderDragging() then
		return
	end
	self:RefreshAll()
end

function Preview:RefreshAll()
	local alive = {}
	for _, inst in ipairs(self._instances) do
		if inst and inst.GetParent and inst:GetParent() and inst.spacer and inst.spacer:GetParent() then
			tinsert(alive, inst)
			if inst.Refresh then
				inst:Refresh()
			end
		elseif inst then
			if inst.Hide then inst:Hide() end
			if inst.SetParent then inst:SetParent(nil) end
		end
	end
	self._instances = alive
end

function Preview:ClearStickyHosts()
	for _, inst in ipairs(self._instances) do
		if inst then
			if inst.SetBackdrop then
				inst:SetBackdrop(nil)
			end
			if inst.Hide then inst:Hide() end
			if inst.SetParent then inst:SetParent(nil) end
		end
	end
	self._instances = {}
end

function Preview:Create(parent, tab, noticeText)
	-- Drop previous sticky hosts from other tabs / remounts.
	self:ClearStickyHosts()
	tab = tab or "sizes"
	local T = SarychUI.OptionsTheme
	local OW = SarychUI.OptionsWindow

	-- Spacer stays in the scroll child so content doesn't jump under the sticky preview.
	local spacer = CreateFrame("Frame", nil, parent)
	spacer:SetHeight(PREVIEW_H + 6)

	-- Sticky host lives on the content panel (outside the scroll child), flush to top.
	local stickyParent = (OW and OW.content) or parent
	local host = CreateFrame("Frame", nil, stickyParent)
	host:SetHeight(PREVIEW_H)
	host._previewTab = tab
	host.spacer = spacer
	if type(noticeText) == "function" then
		host._noticeTextFn = noticeText
		local ok, text = pcall(noticeText)
		noticeText = (ok and text) or ""
	end
	host:SetFrameStrata((stickyParent.GetFrameStrata and stickyParent:GetFrameStrata()) or "DIALOG")
	host:SetFrameLevel((stickyParent:GetFrameLevel() or 1) + 40)

	if T and T.ApplyFlat then
		T:ApplyFlat(host, T.colors.panelBg or { 0.07, 0.07, 0.09, 0.97 }, T.colors.borderSoft)
	else
		local bg = host:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetTexture("Interface\\Buttons\\WHITE8X8")
		bg:SetVertexColor(0.07, 0.07, 0.09, 0.97)
	end

	local notice = host:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	notice:SetPoint("TOPLEFT", 8, -5)
	notice:SetPoint("TOPRIGHT", -8, -5)
	notice:SetJustifyH("LEFT")
	notice:SetText(tostring(noticeText or ""))
	host._notice = notice

	local stage = CreateFrame("Frame", nil, host)
	stage:SetPoint("TOPLEFT", 6, -(NOTICE_H + 4))
	stage:SetPoint("BOTTOMRIGHT", -6, 6)

	-- Mock nameplate (classic health bar look).
	local plate = CreateFrame("Frame", nil, stage)
	plate:SetSize(PLATE_W, PLATE_H)
	plate:SetFrameLevel((stage:GetFrameLevel() or 1) + 1)
	local plateEdge = plate:CreateTexture(nil, "BACKGROUND")
	plateEdge:SetPoint("TOPLEFT", -1, 1)
	plateEdge:SetPoint("BOTTOMRIGHT", 1, -1)
	plateEdge:SetTexture("Interface\\Buttons\\WHITE8X8")
	plateEdge:SetVertexColor(0, 0, 0, 0.85)
	local plateBg = plate:CreateTexture(nil, "ARTWORK")
	plateBg:SetAllPoints()
	plateBg:SetTexture("Interface\\Buttons\\WHITE8X8")
	plateBg:SetVertexColor(0.12, 0.72, 0.12, 0.95)

	-- Mirror in-game hierarchy: centerContainer / mobilityContainer / playerFrame.
	local centerContainer = CreateFrame("Frame", nil, stage)
	centerContainer:SetFrameLevel((stage:GetFrameLevel() or 1) + 3)
	local control = MakeSlot(centerContainer, SAMPLE_ICONS.control, "CC")
	local cast = MakeSlot(centerContainer, SAMPLE_ICONS.cast, "Cast")

	local mobilityContainer = CreateFrame("Frame", nil, stage)
	mobilityContainer:SetFrameLevel((stage:GetFrameLevel() or 1) + 3)
	local other = MakeSlot(mobilityContainer, SAMPLE_ICONS.other, "Other")
	local mobility = MakeSlot(mobilityContainer, SAMPLE_ICONS.mobility, "Mob")

	-- Sibling of centerContainer under stage (mirrors in-game unitFrame parenting).
	local playerFrame = CreateFrame("Frame", nil, stage)
	playerFrame:SetFrameLevel((stage:GetFrameLevel() or 1) + 3)
	local playerSlots = {}
	for i = 1, 8 do
		playerSlots[i] = MakeSlot(playerFrame, SAMPLE_ICONS.player)
	end

	local function Layout()
		local sizes = ReadSizes()
		local pos = ReadPositions()
		local disp = ReadDisplay()
		local scale = Num(LiveOr("scale", disp.scale), 1)
		local alpha = Num(LiveOr("alpha", disp.alpha), 1)
		local elvuiMode = IsElvUIPreviewMode()
		local altRight = FlagOn(LiveOrSlot("player", "altRight", ReadLayoutSlot("player").altRight))
		-- In ElvUI mode preview shows the plate as if targeted, so responsive/proportional
		-- sliders produce a visible change (same idea as in-game targetScale).
		local plateScale = elvuiMode and PREVIEW_ELVUI_PLATE_SCALE or 1
		local plateW = PLATE_W * plateScale
		local plateH = PLATE_H * plateScale
		-- Center can grow with plate; player strip stays at base size.
		local centerMult = 1 + (elvuiMode and ResponsiveBonus("center", plateScale) or 0)

		local szControl = Num(LiveOr("ICON_SIZE_CONTROL", sizes.ICON_SIZE_CONTROL), 46) * centerMult
		local szCast = Num(LiveOr("ICON_SIZE_CAST", sizes.ICON_SIZE_CAST), 46) * centerMult
		local szMob = Num(LiveOr("ICON_SIZE_MOBILITY", sizes.ICON_SIZE_MOBILITY), 30) * scale
		local szOther = Num(LiveOr("ICON_SIZE_OTHER", sizes.ICON_SIZE_OTHER), 30) * scale
		local szPlayer = Num(LiveOr("ICON_SIZE_PLAYER", sizes.ICON_SIZE_PLAYER), 28)
		local pw = Num(LiveOr("ICON_SIZE_PLAYER_WIDTH", sizes.ICON_SIZE_PLAYER_WIDTH), 30)
		local ph = Num(LiveOr("ICON_SIZE_PLAYER_HEIGHT", sizes.ICON_SIZE_PLAYER_HEIGHT), 20)
		if pw < 8 then pw = szPlayer end
		if ph < 8 then ph = math_max(8, szPlayer * 0.67) end
		-- Default: strip frame is square-base * 0.67, icon cropped to width/height.
		-- Alt right: whole square icons, like the Mob/Other slots.
		local playerFrameW = szPlayer
		local playerFrameH = altRight and szPlayer or (szPlayer * 0.67)

		local maxPlayer = math_floor(Num(LiveOr("MAX_PLAYER_AURAS", sizes.MAX_PLAYER_AURAS), 6) + 0.5)
		maxPlayer = math_max(0, math_min(8, maxPlayer))
		local spacing = Num(LiveOr("spacing", ReadPlayerSpacing()), 2)

		local centrY = Num(LiveOr("CentrY", pos.CentrY), 47)
		local playerOffY = Num(LiveOr("PlayerOffsetY", pos.PlayerOffsetY), -7)
		local rightX = Num(LiveOr("RightX", pos.RightX), 5)
		local rightY = Num(LiveOr("RightY", pos.RightY), -10)
		local centerExtraX, centerExtraY = 0, 0
		local playerExtraX, playerExtraY = 0, 0
		local rightExtraX, rightExtraY = 0, 0
		if elvuiMode then
			centerExtraX, centerExtraY = ProportionalExtra("center", plateW, plateH)
			playerExtraX, playerExtraY = ProportionalExtra("player", plateW, plateH)
			rightExtraX, rightExtraY = ProportionalExtra("right", plateW, plateH)
		end
		-- Same drop CC/cast use in-game when the player strip is not under them.
		-- Classic hardcodes 30; ElvUI uses layout.center.noPlayerLift.
		local centerDrop = 0
		if altRight then
			if elvuiMode then
				centerDrop = Num(ReadLayoutSlot("center").noPlayerLift, 30)
			else
				centerDrop = 30
			end
		end
		-- CastX/CastY/OtherX/OtherY exist in options DB but classic layout packs
		-- icons inside containers (gap 4). Keep them for highlight only.

		local stageW = stage:GetWidth() or 400
		local stageH = stage:GetHeight() or (PREVIEW_H - 28)
		if stageW < 80 then stageW = 400 end
		if stageH < 40 then stageH = PREVIEW_H - 28 end

		-- Place plate in the lower-middle of the stage (room above for CentrY).
		-- Alt right stacks player icons upward on the right, so drop the mock lower
		-- and leave it more room; everything stays relative to the plate either way.
		local plateX = stageW * (altRight and 0.36 or 0.42)
		local plateY = stageH * (altRight and 0.80 or 0.62)

		plate:ClearAllPoints()
		plate:SetSize(plateW, plateH)
		plate:SetPoint("CENTER", stage, "TOPLEFT", plateX, -plateY)

		-- centerContainer: CENTER of plate TOP + CentrY (in-game).
		-- Preview uses 1:1 offsets; clamp so icons stay inside the stage.
		local centerW = szControl + szCast + 4
		local centerH = math_max(szControl, szCast)
		centerContainer:SetScale(scale)
		centerContainer:ClearAllPoints()
		centerContainer:SetSize(centerW, centerH)
		centerContainer:SetPoint("CENTER", plate, "TOP", centerExtraX, centrY + centerExtraY - centerDrop)

		control:ClearAllPoints()
		control:SetSize(szControl, szControl)
		control:SetPoint("LEFT", centerContainer, "LEFT", 0, 0)

		cast:ClearAllPoints()
		cast:SetSize(szCast, szCast)
		cast:SetPoint("RIGHT", centerContainer, "RIGHT", 0, 0)

		-- mobilityContainer: LEFT of plate RIGHT + RightX/RightY.
		-- In-game when both shown: Other then Mobility (left -> right), gap 4.
		local rightW = szOther + szMob + 4
		local rightH = math_max(szOther, szMob)
		mobilityContainer:ClearAllPoints()
		mobilityContainer:SetSize(rightW, rightH)
		mobilityContainer:SetPoint("LEFT", plate, "RIGHT", rightX + rightExtraX, rightY + rightExtraY)

		other:ClearAllPoints()
		other:SetSize(szOther, szOther)
		other:SetPoint("LEFT", mobilityContainer, "LEFT", 0, 0)

		mobility:ClearAllPoints()
		mobility:SetSize(szMob, szMob)
		mobility:SetPoint("LEFT", other, "RIGHT", 4, 0)

		-- playerFrame: TOP of centerContainer BOTTOM + PlayerOffsetY.
		-- Growth bonus is in pixel sizes; SetScale only carries display.scale (like in-game).
		local showPlayer = maxPlayer > 0
		if showPlayer then
			playerFrame:Show()
			playerFrame:SetScale(scale)
			playerFrame:ClearAllPoints()

			if altRight then
				-- Mirrors the in-game alternative shape: a two-column block hanging off
				-- the right container. The preview always draws the mob/other icons, so
				-- it shows the lifted case.
				playerFrame:SetSize(math_max(2 * playerFrameW + spacing, 1), playerFrameH)
				playerFrame:SetPoint("BOTTOMLEFT", mobilityContainer, "TOPLEFT", 0, spacing)
			else
				local rowW = maxPlayer * playerFrameW + math_max(0, maxPlayer - 1) * spacing
				playerFrame:SetSize(math_max(rowW, 1), playerFrameH)
				playerFrame:SetPoint("TOP", centerContainer, "BOTTOM", playerExtraX, playerOffY + playerExtraY)
			end

			local totalWidth = (maxPlayer - 1) * (playerFrameW + spacing)
			local startX = -totalWidth / 2
			for i = 1, 8 do
				local slot = playerSlots[i]
				if i <= maxPlayer then
					slot:Show()
					slot:ClearAllPoints()
					slot:SetSize(playerFrameW, playerFrameH)
					if altRight then
						local column = (i - 1) % 2
						local row = math_floor((i - 1) / 2)
						slot:SetPoint("BOTTOMLEFT", playerFrame, "BOTTOMLEFT",
							column * (playerFrameW + spacing), row * (playerFrameH + spacing))
						ApplySquareIcon(slot.icon)
					else
						slot:SetPoint("CENTER", playerFrame, "CENTER", startX + (i - 1) * (playerFrameW + spacing), 0)
						ApplyPlayerIconCrop(slot.icon, szPlayer, pw, ph)
					end
				else
					slot:Hide()
				end
			end
		else
			playerFrame:Hide()
		end

		-- Highlight + dim.
		ApplySlotStyle(control, IsActive("control"))
		ApplySlotStyle(cast, IsActive("cast"))
		ApplySlotStyle(mobility, IsActive("mobility"))
		ApplySlotStyle(other, IsActive("other"))
		local playerActive = IsActive("player")
		for i = 1, maxPlayer do
			ApplySlotStyle(playerSlots[i], playerActive)
		end

		local layerA = math_max(0.25, math_min(1, alpha))
		local function SlotAlpha(name)
			return (IsActive(name) and ACTIVE_A or DIM_A) * layerA
		end
		control:SetAlpha(SlotAlpha("control"))
		cast:SetAlpha(SlotAlpha("cast"))
		mobility:SetAlpha(SlotAlpha("mobility"))
		other:SetAlpha(SlotAlpha("other"))
		for i = 1, maxPlayer do
			playerSlots[i]:SetAlpha((playerActive and ACTIVE_A or DIM_A) * layerA)
		end
		-- Soft-dim whole containers when their group isn't active.
		centerContainer:SetAlpha(1)
		mobilityContainer:SetAlpha(1)
		playerFrame:SetAlpha(1)
	end

	local function PinSticky()
		if not spacer:GetParent() then
			host:Hide()
			return
		end
		if not spacer:IsShown() then
			host:Hide()
			return
		end
		host:Show()
		local scroll = OW and OW.contentScroll
		if scroll and stickyParent == (OW and OW.content) then
			host:SetParent(stickyParent)
			host:ClearAllPoints()
			host:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
			host:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, 0)
			host:SetHeight(PREVIEW_H)
			host:SetFrameLevel((stickyParent:GetFrameLevel() or 1) + 40)
		else
			host:SetParent(parent)
			host:ClearAllPoints()
			host:SetPoint("TOPLEFT", spacer, "TOPLEFT", 0, 0)
			host:SetPoint("TOPRIGHT", spacer, "TOPRIGHT", 0, 0)
		end
		if host._notice and type(host._noticeTextFn) == "function" then
			local ok, text = pcall(host._noticeTextFn)
			if ok and text then
				host._notice:SetText(tostring(text))
			end
		end
	end

	host.LayoutLive = function()
		Layout()
	end
	host.RefreshLayout = Layout
	host.PinOnly = function()
		-- Re-pin without full icon rebuild on scroll.
		if not spacer:GetParent() or not spacer:IsShown() then
			host:Hide()
			return
		end
		host:Show()
		local scrollFrame = OW and OW.contentScroll
		if scrollFrame and stickyParent == (OW and OW.content) then
			host:SetParent(stickyParent)
			host:ClearAllPoints()
			host:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
			host:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 0, 0)
			host:SetHeight(PREVIEW_H)
			host:SetFrameLevel((stickyParent:GetFrameLevel() or 1) + 40)
		end
	end
	host.Refresh = function()
		PinSticky()
		Layout()
	end

	host:SetScript("OnSizeChanged", function()
		Layout()
	end)
	host:SetScript("OnShow", function()
		PinSticky()
		Layout()
	end)

	-- Keep sticky aligned when the options scroll viewport moves/resizes.
	local scroll = OW and OW.contentScroll
	if scroll then
		if not scroll._suiPreviewPinHooked then
			scroll._suiPreviewPinHooked = true
			scroll:HookScript("OnVerticalScroll", function()
				for _, inst in ipairs(Preview._instances) do
					if inst and inst.PinOnly then inst:PinOnly() end
				end
			end)
			scroll:HookScript("OnSizeChanged", function()
				for _, inst in ipairs(Preview._instances) do
					if inst and inst.PinOnly then inst:PinOnly() end
				end
			end)
		end
	end

	-- One-shot deferred layout (width often 0 on first paint).
	host:SetScript("OnUpdate", function(self)
		self:SetScript("OnUpdate", nil)
		PinSticky()
		Layout()
	end)

	spacer:SetScript("OnHide", function()
		host:Hide()
	end)
	spacer:SetScript("OnShow", function()
		host:Show()
		PinSticky()
		Layout()
	end)

	tinsert(Preview._instances, host)
	PinSticky()
	Layout()

	-- Spacer reserves scroll-child height so content starts below the sticky preview.
	return spacer
end
