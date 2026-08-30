-- SarychUI Tools — live preview for loot roll count font styling.

local CreateFrame = CreateFrame
local pairs = pairs
local ipairs = ipairs
local type = type
local tonumber = tonumber
local tostring = tostring
local tinsert = table.insert
local pcall = pcall
local GetItemInfo = GetItemInfo

SarychUI = SarychUI or {}
SarychUI.LootRollPreview = SarychUI.LootRollPreview or {}
local Preview = SarychUI.LootRollPreview

local PREVIEW_H = 108
local SAMPLE_ITEM_ID = 54590
-- Sharpened Twilight Scale (54590) — known WotLK icon path as cache-independent fallback.
local SAMPLE_ITEM_ICON = "Interface\\Icons\\INV_Misc_RubySanctum4"
local ACTIVE_BORDER = { 1, 0.82, 0.2, 1 }
local SAMPLE_COUNTS = {
	need = 2,
	greed = 1,
	disenchant = 1,
	pass = 3,
}

Preview._instances = Preview._instances or {}
Preview._activeKey = nil
Preview._live = Preview._live or {}

local FALLBACK_FONT = "Fonts\\FRIZQT__.TTF"
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

local function GetToolsDB()
	if not SarychUI or not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules then
		return nil
	end
	return SarychUI.db.profile.modules.tools
end

local function ResolveFontPath(fontName)
	if SarychUI and SarychUI.Media and SarychUI.Media.GetFont then
		local path = SarychUI.Media:GetFont(fontName)
		if path and path ~= "" then return path end
	end
	if LSM and fontName then
		local path = LSM:Fetch("font", fontName, true)
		if path and path ~= "" then return path end
	end
	return FALLBACK_FONT
end

local function ResolveOutline(outline)
	if outline == "NONE" or outline == "" or outline == nil then
		return ""
	end
	return outline
end

local function ActiveStyle()
	local db = GetToolsDB() or {}
	local live = Preview._live
	return {
		font = live.font or db.lootRollCountFont or "Friz Quadrata TT",
		fontSize = tonumber(live.fontSize or db.lootRollCountFontSize) or 12,
		fontOutline = live.fontOutline or db.lootRollCountFontOutline or "OUTLINE",
	}
end

function Preview:SetActiveKey(key)
	self._activeKey = key
	self:RefreshAll()
end

function Preview:SetLiveValue(key, value)
	self._live[key] = value
	self._activeKey = key
	self:RefreshAll()
end

function Preview:ClearLiveValue(key)
	if key then
		self._live[key] = nil
	else
		for k in pairs(self._live) do
			self._live[k] = nil
		end
	end
end

function Preview:RefreshAll()
	local alive = {}
	for _, inst in ipairs(self._instances) do
		if inst and inst.GetParent and inst:GetParent() then
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

local function ResolveSampleItem()
	local name, _, quality, _, _, _, _, _, _, texture = GetItemInfo(SAMPLE_ITEM_ID)
	return {
		name = name,
		quality = quality or 4,
		texture = texture or SAMPLE_ITEM_ICON,
	}
end

local function MakeRollButton(parent, texture, count)
	local btn = CreateFrame("Frame", nil, parent)
	btn:SetSize(32, 32)

	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexture(texture)
	btn.icon = icon

	local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	fs:SetPoint("CENTER", btn, "CENTER", 0, 0)
	fs:SetTextColor(1, 0.95, 0.4, 1)
	fs:SetText(tostring(count))
	btn.count = fs

	return btn
end

function Preview:Create(parent)
	self:ClearStickyHosts()
	local T = SarychUI.OptionsTheme

	local host = CreateFrame("Frame", nil, parent)
	host:SetHeight(PREVIEW_H)
	host.spacer = host

	if T and T.ApplyFlat then
		T:ApplyFlat(host, T.colors.panelBg or { 0.07, 0.07, 0.09, 0.97 }, T.colors.borderSoft)
	else
		local bg = host:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetTexture("Interface\\Buttons\\WHITE8X8")
		bg:SetVertexColor(0.07, 0.07, 0.09, 0.97)
	end

	local stage = CreateFrame("Frame", nil, host)
	stage:SetPoint("TOPLEFT", 8, -8)
	stage:SetPoint("BOTTOMRIGHT", -8, 8)

	-- Original Blizzard GroupLootFrameTemplate textures/layout (LootFrame.xml).
	local frame = CreateFrame("Frame", nil, stage)
	frame:SetSize(253, 84)
	frame:SetPoint("CENTER", stage, "CENTER", 0, 0)
	frame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})

	local slotTexture = frame:CreateTexture(nil, "ARTWORK")
	slotTexture:SetTexture("Interface\\Buttons\\UI-EmptySlot")
	slotTexture:SetSize(64, 64)
	slotTexture:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -3)

	local nameFrame = frame:CreateTexture(nil, "ARTWORK")
	nameFrame:SetTexture("Interface\\MerchantFrame\\UI-Merchant-LabelSlots")
	nameFrame:SetSize(128, 64)
	nameFrame:SetPoint("LEFT", slotTexture, "RIGHT", -9, -10)

	local corner = frame:CreateTexture(nil, "OVERLAY")
	corner:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Corner")
	corner:SetSize(32, 32)
	corner:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -7)

	local sample = ResolveSampleItem()

	-- Item icon must sit above UI-EmptySlot (same ARTWORK layer would hide it).
	local itemIcon = frame:CreateTexture(nil, "OVERLAY")
	itemIcon:SetSize(34, 34)
	itemIcon:SetPoint("TOPLEFT", slotTexture, "TOPLEFT", 15, -15)
	itemIcon:SetTexture(sample.texture)
	itemIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	host._itemIcon = itemIcon

	local nameFs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	nameFs:SetSize(90, 30)
	nameFs:SetJustifyH("LEFT")
	nameFs:SetPoint("LEFT", slotTexture, "RIGHT", -5, 5)
	if sample.name and sample.name ~= "" then
		local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[sample.quality]
		nameFs:SetText(sample.name)
		if color then
			nameFs:SetTextColor(color.r, color.g, color.b)
		else
			nameFs:SetTextColor(0.64, 0.21, 0.93)
		end
	else
		nameFs:SetText("Sharpened Twilight Scale")
		nameFs:SetTextColor(0.64, 0.21, 0.93)
	end

	-- Timer bar (visual only)
	local timerBorder = frame:CreateTexture(nil, "OVERLAY")
	timerBorder:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder")
	timerBorder:SetSize(156, 20)
	timerBorder:SetPoint("TOPLEFT", slotTexture, "BOTTOMLEFT", 11, 15)

	local timerBar = frame:CreateTexture(nil, "ARTWORK")
	timerBar:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar")
	timerBar:SetSize(110, 10)
	timerBar:SetPoint("LEFT", timerBorder, "LEFT", 3, -1)
	timerBar:SetVertexColor(1, 1, 0, 1)

	local buttons = {}
	local need = MakeRollButton(frame, "Interface\\Buttons\\UI-GroupLoot-Dice-Up", SAMPLE_COUNTS.need)
	need:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -48, -14)
	buttons.need = need

	local greed = MakeRollButton(frame, "Interface\\Buttons\\UI-GroupLoot-Coin-Up", SAMPLE_COUNTS.greed)
	greed:SetPoint("TOP", need, "BOTTOM", -2, 2)
	buttons.greed = greed

	local disenchant = MakeRollButton(frame, "Interface\\Buttons\\UI-GroupLoot-DE-Up", SAMPLE_COUNTS.disenchant)
	disenchant:SetPoint("LEFT", greed, "RIGHT", 3, 3)
	buttons.disenchant = disenchant

	-- Pass uses the close-button corner in Blizzard UI; show Pass icon with count for preview.
	local pass = MakeRollButton(frame, "Interface\\Buttons\\UI-GroupLoot-Pass-Up", SAMPLE_COUNTS.pass)
	pass:SetSize(24, 24)
	pass:SetPoint("TOPRIGHT", corner, "TOPRIGHT", 2, 2)
	buttons.pass = pass

	host._buttons = buttons

	local function Layout()
		local style = ActiveStyle()
		local fontPath = ResolveFontPath(style.font)
		local outline = ResolveOutline(style.fontOutline)
		local fontSize = style.fontSize
		local active = Preview._activeKey == "fontSize"
			or Preview._activeKey == "font"
			or Preview._activeKey == "fontOutline"

		for _, btn in pairs(buttons) do
			local fs = btn.count
			if fs then
				local ok = pcall(fs.SetFont, fs, fontPath, fontSize, outline)
				if not ok then
					pcall(fs.SetFont, fs, FALLBACK_FONT, fontSize or 12, outline or "OUTLINE")
				end
				if active then
					fs:SetTextColor(ACTIVE_BORDER[1], ACTIVE_BORDER[2], ACTIVE_BORDER[3], 1)
				else
					fs:SetTextColor(1, 0.95, 0.4, 1)
				end
			end
		end
	end

	host.Refresh = Layout
	host:SetScript("OnSizeChanged", Layout)
	host:SetScript("OnShow", Layout)
	host:SetScript("OnUpdate", function(self)
		self:SetScript("OnUpdate", nil)
		Layout()
	end)

	tinsert(Preview._instances, host)
	Layout()
	return host
end
