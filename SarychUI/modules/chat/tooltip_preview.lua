-- SarychUI Chat — ItemRef tooltip icons sticky preview (item + achievement).

local CreateFrame = CreateFrame
local ipairs = ipairs
local pairs = pairs
local tinsert = table.insert
local GetItemInfo = GetItemInfo
local GetItemIcon = GetItemIcon
local GetAchievementInfo = GetAchievementInfo

SarychUI = SarychUI or {}

local PREVIEW_H = 200

-- Classic WotLK sample items (icon + name fallbacks if GetItemInfo not cached).
local SAMPLE_ITEMS = {
	{ id = 49623, name = "Тёмная Скорбь", quality = 5, icon = "Interface\\Icons\\INV_Axe_113" },
	{ id = 46017, name = "Вал'анир", quality = 5, icon = "Interface\\Icons\\INV_Mace_99" },
	{ id = 19019, name = "Громовая ярость", quality = 5, icon = "Interface\\Icons\\INV_Sword_39" },
	{ id = 17182, name = "Сульфурас", quality = 5, icon = "Interface\\Icons\\INV_Hammer_Unique_Sulfuras" },
	{ id = 22632, name = "Атиеш", quality = 5, icon = "Interface\\Icons\\INV_Staff_Medivh" },
	{ id = 34334, name = "Таласский клинок", quality = 5, icon = "Interface\\Icons\\INV_Weapon_Bow_39" },
}

-- Classic WotLK sample achievements.
local SAMPLE_ACHIEVEMENTS = {
	{ id = 13, name = "Уровень 80", points = 10, icon = "Interface\\Icons\\Achievement_Level_80" },
	{ id = 1658, name = "Защитник Ледяных Пустошей", points = 10, icon = "Interface\\Icons\\Achievement_Dungeon_Icecrown_Forge" },
	{ id = 4530, name = "Падение Короля-лича", points = 10, icon = "Interface\\Icons\\Achievement_Boss_LichKing" },
	{ id = 4602, name = "Слава рейдеру Ледяной Короны", points = 25, icon = "Interface\\Icons\\Achievement_Dungeon_Icecrown_IcecrownEntrance" },
	{ id = 6, name = "Уровень 10", points = 10, icon = "Interface\\Icons\\Achievement_Level_10" },
}

local QUALITY_COLORS = {
	[0] = { 0.62, 0.62, 0.62 },
	[1] = { 1, 1, 1 },
	[2] = { 0.12, 1, 0 },
	[3] = { 0, 0.44, 0.87 },
	[4] = { 0.64, 0.21, 0.93 },
	[5] = { 1, 0.5, 0 },
}

--------------------------------------------------------------------
SarychUI.ChatTooltipPreview = SarychUI.ChatTooltipPreview or {}
local Preview = SarychUI.ChatTooltipPreview
Preview._instances = Preview._instances or {}
Preview._live = Preview._live or {}
Preview._activeKey = nil
Preview._sampleIndex = 1
Preview._achIndex = 1

local function ChatDB()
	local mods = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return mods and mods.chat or {}
end

local function LiveOr(key, fallback)
	local live = Preview._live
	if live[key] ~= nil then
		return live[key]
	end
	local db = ChatDB()
	local v = db[key]
	if v == nil then return fallback end
	return v
end

local function LiveFlag(key, fallback)
	local v = LiveOr(key, fallback)
	return v == 1 or v == true
end

function Preview:SetActiveKey(key)
	self._activeKey = key
	self:RefreshAll()
end

function Preview:SetLiveValue(key, value)
	if key == nil then return end
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
	self:RefreshAll()
end

function Preview:RefreshAll()
	local alive = {}
	for _, inst in ipairs(self._instances) do
		if inst and inst.GetParent and inst:GetParent() and inst.spacer and inst.spacer:GetParent() then
			tinsert(alive, inst)
			if inst.Refresh then inst:Refresh() end
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
			if inst.ClearAllPoints then inst:ClearAllPoints() end
			if inst.SetParent then inst:SetParent(nil) end
		end
	end
	self._instances = {}
end

local function PickSample(list, indexKey)
	local idx = Preview[indexKey] or 1
	if idx < 1 or idx > #list then idx = 1 end
	Preview[indexKey] = (idx % #list) + 1
	return list[idx]
end

local function ResolveItem(sample)
	local name, link, quality, _, _, _, _, _, _, texture = GetItemInfo(sample.id)
	return {
		kind = "item",
		id = sample.id,
		name = name or sample.name,
		quality = quality or sample.quality or 4,
		icon = texture or (GetItemIcon and GetItemIcon(sample.id)) or sample.icon,
		link = link,
		line2 = "Уровень предмета 284",
		line3 = "Уникальный экипируемый",
		showBorder = false,
	}
end

local function ResolveAchievement(sample)
	local name, points, icon
	if GetAchievementInfo then
		local _, n, p, _, _, _, _, _, _, ic = GetAchievementInfo(sample.id)
		name, points, icon = n, p, ic
	end
	return {
		kind = "achievement",
		id = sample.id,
		name = name or sample.name,
		points = points or sample.points or 10,
		icon = icon or sample.icon,
		line2 = "Достижение",
		line3 = (points or sample.points or 10) .. " очков достижений",
		showBorder = true,
		nameColor = { 1, 0.82, 0 },
	}
end

local function MakeTooltipPreview(parent)
	local tip = CreateFrame("Frame", nil, parent)
	tip:SetSize(210, 78)

	local bg = tip:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
	bg:SetVertexColor(0.09, 0.09, 0.12, 0.95)

	local border = CreateFrame("Frame", nil, tip)
	border:SetAllPoints()
	if border.SetBackdrop then
		border:SetBackdrop({
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			edgeSize = 14,
			insets = { left = 3, right = 3, top = 3, bottom = 3 },
		})
		border:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
	end

	local nameFs = tip:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	nameFs:SetPoint("TOPLEFT", 10, -10)
	nameFs:SetPoint("TOPRIGHT", -10, -10)
	nameFs:SetJustifyH("LEFT")
	tip.nameFs = nameFs

	local line2 = tip:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	line2:SetPoint("TOPLEFT", nameFs, "BOTTOMLEFT", 0, -4)
	line2:SetJustifyH("LEFT")
	line2:SetTextColor(1, 1, 1)
	tip.line2 = line2

	local line3 = tip:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	line3:SetPoint("TOPLEFT", line2, "BOTTOMLEFT", 0, -2)
	line3:SetJustifyH("LEFT")
	line3:SetTextColor(1, 1, 1)
	tip.line3 = line3

	-- Same placement as appearance.lua: TOPRIGHT of tip → TOPLEFT, 0.5, -1.5
	local icon = CreateFrame("Frame", nil, tip)
	icon:SetSize(37, 37)
	icon:SetPoint("TOPRIGHT", tip, "TOPLEFT", 0.5, -1.5)
	icon:SetFrameLevel(tip:GetFrameLevel() + 5)

	local iconTex = icon:CreateTexture(nil, "ARTWORK")
	iconTex:SetAllPoints()
	icon.tex = iconTex

	local iconBorder = icon:CreateTexture(nil, "OVERLAY")
	iconBorder:SetTexture("Interface\\AchievementFrame\\UI-Achievement-IconFrame")
	iconBorder:SetTexCoord(0, 0.5625, 0, 0.5625)
	iconBorder:SetPoint("CENTER")
	iconBorder:SetSize(37 + 7.5, 37 + 7.5)
	icon.border = iconBorder

	tip.icon = icon
	return tip
end

local function ApplyTipData(tip, data)
	if not tip or not data then return end
	if data.nameColor then
		tip.nameFs:SetTextColor(data.nameColor[1], data.nameColor[2], data.nameColor[3])
	else
		local q = data.quality or 4
		local c = QUALITY_COLORS[q] or QUALITY_COLORS[4]
		tip.nameFs:SetTextColor(c[1], c[2], c[3])
	end
	tip.nameFs:SetText(data.name or "—")
	tip.line2:SetText(data.line2 or "")
	tip.line3:SetText(data.line3 or "")
	if data.icon then
		tip.icon.tex:SetTexture(data.icon)
	end
	if data.showBorder then
		tip.icon.border:Show()
	else
		tip.icon.border:Hide()
	end
end

local function ApplyIconHighlight(tip, showIcon, active)
	if not tip then return end
	if showIcon then
		tip.icon:Show()
		tip.icon:SetAlpha(1)
		if active then
			tip.icon.tex:SetVertexColor(1, 0.92, 0.35)
			tip.icon.border:SetVertexColor(1, 0.9, 0.3)
		else
			tip.icon.tex:SetVertexColor(1, 1, 1)
			tip.icon.border:SetVertexColor(1, 1, 1)
		end
	else
		tip.icon:Hide()
	end
end

function Preview:Create(parent)
	self:ClearStickyHosts()
	local OW = SarychUI.OptionsWindow
	local T = SarychUI.OptionsTheme

	local spacer = CreateFrame("Frame", nil, parent)
	spacer:SetHeight(PREVIEW_H + 4)

	local stickyParent = (OW and OW.content) or parent
	local host = CreateFrame("Frame", nil, stickyParent)
	host:SetHeight(PREVIEW_H)
	host.spacer = spacer
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

	local stage = CreateFrame("Frame", nil, host)
	stage:SetPoint("TOPLEFT", 10, -8)
	stage:SetPoint("BOTTOMRIGHT", -10, 8)

	local itemTip = MakeTooltipPreview(stage)
	local achTip = MakeTooltipPreview(stage)
	-- Leave room on the left for hanging icons; stack vertically.
	itemTip:SetPoint("TOP", stage, "TOP", 18, -6)
	achTip:SetPoint("TOP", itemTip, "BOTTOM", 0, -16)

	host._itemTip = itemTip
	host._achTip = achTip

	local function RefreshSamples()
		local itemData = ResolveItem(PickSample(SAMPLE_ITEMS, "_sampleIndex"))
		local achData = ResolveAchievement(PickSample(SAMPLE_ACHIEVEMENTS, "_achIndex"))
		host._itemSample = itemData
		host._achSample = achData
		ApplyTipData(itemTip, itemData)
		ApplyTipData(achTip, achData)
	end

	RefreshSamples()

	local function Layout()
		local showIcon = LiveFlag("itemRefIconsEnabled", true)
		local active = Preview._activeKey == "itemRefIconsEnabled"
		ApplyIconHighlight(itemTip, showIcon, active)
		ApplyIconHighlight(achTip, showIcon, active)
		-- Achievement border only when icons are on and sample wants it.
		if showIcon and host._achSample and host._achSample.showBorder then
			achTip.icon.border:Show()
		else
			achTip.icon.border:Hide()
		end
		itemTip.icon.border:Hide()
	end

	local function PinSticky()
		if not spacer:GetParent() or not spacer:IsShown() then
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
		Layout()
	end

	host.Refresh = function()
		PinSticky()
	end

	spacer:SetScript("OnShow", function()
		RefreshSamples()
		PinSticky()
	end)
	spacer:SetScript("OnHide", function() host:Hide() end)

	local scroll = OW and OW.contentScroll
	if scroll and not scroll._suiChatTooltipPinHooked then
		scroll._suiChatTooltipPinHooked = true
		scroll:HookScript("OnVerticalScroll", function()
			Preview:RefreshAll()
		end)
		scroll:HookScript("OnSizeChanged", function()
			Preview:RefreshAll()
		end)
	end

	PinSticky()
	tinsert(self._instances, host)
	return spacer
end
