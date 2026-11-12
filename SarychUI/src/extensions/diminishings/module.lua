-- Diminishing returns extension. Arena owns only its icon placement and size.
local module = SarychUI and SarychUI.modules and SarychUI.modules.arena
if not module then return end

local DRList = LibStub and LibStub("DRList-1.0", true)
local DRSpellCategories = SarychUI.Data.Diminishings.spellCategories

local DR = SarychUI:RegisterExtension("diminishings", {
	slots = {}, unitSlots = {}, guidStates = {}, enabled = false, previewEnabled = false,
})
-- Arena still invokes refreshes when its layout or preview changes.
module.Diminishings = DR

function DR:GetDB()
	local modules = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	local db = modules and modules.diminishings
	-- Older builds saved the preview toggle. It is now session-only.
	if db and db.testMode ~= nil then db.testMode = nil end
	if db and (not db.logicMigrated or not db.appearanceMigrated) then
		local old = module:GetDRSettings()
		if old and not db.logicMigrated then
			if old.duration ~= nil then db.duration = old.duration end
			if old.categories then
				db.categories = db.categories or {}
				for category, enabled in pairs(old.categories) do db.categories[category] = enabled end
			end
		end
		if old and not db.appearanceMigrated then
			for _, key in ipairs({ "showSweep", "cooldownEdge", "pulseLastFive",
				"pulseThreshold", "borderColors" }) do
				if old[key] ~= nil then db[key] = old[key] end
			end
			for _, key in ipairs({ "halfColor", "quarterColor", "immuneColor" }) do
				if old[key] then
					db[key] = { r = old[key].r, g = old[key].g, b = old[key].b }
				end
			end
		end
		db.logicMigrated = true
		db.appearanceMigrated = true
	end
	return db
end

function DR:IsEnabled()
	local db = self:GetDB()
	return db and db.enabled ~= false and DRList ~= nil or false
end

function DR:IsArenaEnabled()
	local db = self:GetDB()
	return db and db.enabled ~= false and db.arena ~= false and DRList ~= nil or false
end

function DR:IsContextAllowed()
	local db = self:GetDB()
	if db and db.displayScope == "all" then return true end
	local _, kind = IsInInstance()
	if kind == "arena" then return true end
	local modules = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	local arena = modules and modules.arena
	return arena and (arena.testMode or 0) > 0 or false
end

local MAX_UNITS = MAX_ARENA_ENEMIES or 5
local BAGS_ATLAS = "Interface\\AddOns\\SarychUI\\media\\compatibility\\Bags"
local GLOW_COORDS = { 0.00390625, 0.15625, 0.699219, 0.851562 } -- bags-glow-white
local FLASH_COORDS = { 0.00390625, 0.355469, 0.00390625, 0.355469 } -- bags-glow-flash
local PREVIEW_ROWS = {
	{ {118, 0.5, 13}, {5782, 0.25, 9}, {408, 0, 18} },
	{ {853, 0, 16}, {19503, 0.5, 6} },
	{ {33786, 0.25, 11}, {15487, 0, 4}, {118, 0.5, 17} },
	{ {5782, 0.5, 14}, {408, 0.25, 7}, {853, 0, 12} },
	{ {19503, 0, 10}, {33786, 0.25, 5} },
}
local function DB()
	local modules = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return modules and modules.arena
end

local function Settings()
	return module:GetDRSettings() or {}
end

local function ColorFor(level, cfg)
	local c = level == 0.5 and cfg.halfColor or level == 0.25 and cfg.quarterColor or cfg.immuneColor
	if c then return c.r or 1, c.g or 1, c.b or 1 end
	if level == 0.5 then return 1, 1, 0 end
	if level == 0.25 then return 1, 0.7, 0 end
	return 1, 0, 0
end

local function PulseIcon(icon)
	local elapsed = GetTime() - icon.warningPulseStart
	-- Smooth 1.1-second cycle, beginning at full opacity when the warning starts.
	local alpha = 0.725 + 0.275 * math.cos(elapsed * (2 * math.pi / 1.1))
	icon:SetAlpha(alpha)
end

local function SetWarningPulse(icon, enabled)
	if enabled then
		if not icon.warningPulseStart then
			icon.warningPulseStart = GetTime()
			icon:SetScript("OnUpdate", PulseIcon)
			icon:SetAlpha(1)
		end
	elseif icon.warningPulseStart then
		icon.warningPulseStart = nil
		icon:SetScript("OnUpdate", nil)
		icon:SetAlpha(1)
	end
end

local function MakeIcon(parent)
	local icon = CreateFrame("Frame", nil, parent)
	icon:SetFrameStrata("HIGH")
	icon.animatedGlow = icon:CreateTexture(nil, "OVERLAY")
	icon.animatedGlow:SetTexture(BAGS_ATLAS)
	icon.animatedGlow:SetTexCoord(unpack(GLOW_COORDS))
	icon.animatedGlow:SetBlendMode("ADD")
	icon.animatedGlow:SetPoint("CENTER", icon, "CENTER", 0, 0)
	icon.animatedGlow:SetAlpha(0)
	icon.glowAnim = icon.animatedGlow:CreateAnimationGroup()
	for order, step in ipairs({ {0, 1, "NONE"}, {1, -0.4, "NONE"},
		{1, 1, "NONE"}, {1, -1, "NONE"} }) do
		local alpha = icon.glowAnim:CreateAnimation("Alpha")
		alpha:SetOrder(order)
		alpha:SetDuration(step[1])
		alpha:SetChange(step[2])
		alpha:SetSmoothing(step[3])
	end
	icon.flash = icon:CreateTexture(nil, "OVERLAY")
	icon.flash:SetTexture(BAGS_ATLAS)
	icon.flash:SetTexCoord(unpack(FLASH_COORDS))
	icon.flash:SetBlendMode("ADD")
	icon.flash:SetPoint("CENTER", icon, "CENTER", 0, 0)
	icon.flash:SetAlpha(0)
	icon.flashAnim = icon.flash:CreateAnimationGroup()
	for order, step in ipairs({ {0, 1, "NONE"}, {1, -1, "OUT"} }) do
		local alpha = icon.flashAnim:CreateAnimation("Alpha")
		alpha:SetOrder(order)
		alpha:SetDuration(step[1])
		alpha:SetChange(step[2])
		alpha:SetSmoothing(step[3])
	end
	icon.texture = icon:CreateTexture(nil, "ARTWORK")
	icon.texture:SetAllPoints(icon)
	icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
	icon.cooldown:SetAllPoints(icon)
	icon.cooldown:SetFrameLevel(icon:GetFrameLevel() + 1)
	icon.cooldown:SetAlpha(0.65)
	icon.cooldown.__sary_arenaDR = true
	icon.cooldown.noCooldownCount = true
	if icon.cooldown.SetDrawEdge then icon.cooldown:SetDrawEdge(false) end
	if icon.cooldown.SetDrawBling then icon.cooldown:SetDrawBling(false) end
	if icon.cooldown.SetHideCountdownNumbers then icon.cooldown:SetHideCountdownNumbers(true) end
	icon.cooldown:Hide()
	-- A square one-pixel border stays above the cooldown; the OmniBar glow is separate.
	icon.borderFrame = CreateFrame("Frame", nil, icon)
	icon.borderFrame:SetAllPoints(icon)
	icon.borderFrame:SetFrameLevel(icon:GetFrameLevel() + 2)
	icon.borderFrame:EnableMouse(false)
	icon.borderStrokes = {}
	local top = icon.borderFrame:CreateTexture(nil, "OVERLAY")
	top:SetTexture("Interface\\Buttons\\WHITE8X8")
	top:SetPoint("TOPLEFT", icon.borderFrame, "TOPLEFT", 0, 0)
	top:SetPoint("TOPRIGHT", icon.borderFrame, "TOPRIGHT", 0, 0)
	top:SetHeight(1)
	icon.borderStrokes[1] = top
	local bottom = icon.borderFrame:CreateTexture(nil, "OVERLAY")
	bottom:SetTexture("Interface\\Buttons\\WHITE8X8")
	bottom:SetPoint("BOTTOMLEFT", icon.borderFrame, "BOTTOMLEFT", 0, 0)
	bottom:SetPoint("BOTTOMRIGHT", icon.borderFrame, "BOTTOMRIGHT", 0, 0)
	bottom:SetHeight(1)
	icon.borderStrokes[2] = bottom
	local left = icon.borderFrame:CreateTexture(nil, "OVERLAY")
	left:SetTexture("Interface\\Buttons\\WHITE8X8")
	left:SetPoint("TOPLEFT", icon.borderFrame, "TOPLEFT", 0, -1)
	left:SetPoint("BOTTOMLEFT", icon.borderFrame, "BOTTOMLEFT", 0, 1)
	left:SetWidth(1)
	icon.borderStrokes[3] = left
	local right = icon.borderFrame:CreateTexture(nil, "OVERLAY")
	right:SetTexture("Interface\\Buttons\\WHITE8X8")
	right:SetPoint("TOPRIGHT", icon.borderFrame, "TOPRIGHT", 0, -1)
	right:SetPoint("BOTTOMRIGHT", icon.borderFrame, "BOTTOMRIGHT", 0, 1)
	right:SetWidth(1)
	icon.borderStrokes[4] = right
	icon:Hide()
	return icon
end

local function EnsureSlot(index)
	local slot = DR.slots[index]
	if slot then return slot end
	local holder = CreateFrame("Frame", nil, UIParent)
	holder:SetFrameStrata("HIGH")
	holder:Hide()
	slot = { holder = holder, icons = {}, categories = {}, order = {}, inOrder = {}, guid = nil }
	for i = 1, 16 do slot.icons[i] = MakeIcon(holder) end
	DR.slots[index] = slot
	return slot
end

local function StopCountdown(icon)
	if icon._cooldownStart then
		if SarychUI_NotifyCooldown then SarychUI_NotifyCooldown(icon.cooldown, 0, 0, 0) end
		if SarychUI_ReleaseCooldown then SarychUI_ReleaseCooldown(icon.cooldown) end
		icon._cooldownStart = nil
	end
	if icon.cooldown:IsShown() then icon.cooldown:Hide() end
end

local function StopGlow(icon)
	SetWarningPulse(icon, false)
	if icon.glowAnim:IsPlaying() then icon.glowAnim:Stop() end
	if icon.flashAnim:IsPlaying() then icon.flashAnim:Stop() end
	icon.animatedGlow:SetAlpha(0)
	icon.flash:SetAlpha(0)
	icon._state = nil
	icon._pulseStart = nil
end

local function ClearSlot(slot)
	if slot.visibleCategories then wipe(slot.visibleCategories) end
	slot.categories = {}
	slot.order = {}
	slot.inOrder = {}
	slot.guid = nil
	slot.previewStates = nil
	for i = 1, #slot.icons do
		StopCountdown(slot.icons[i])
		StopGlow(slot.icons[i])
		slot.icons[i]:Hide()
	end
	slot.holder:Hide()
end

function DR:Reset()
	for i = 1, MAX_UNITS do
		local slot = self.slots[i]
		if slot then ClearSlot(slot) end
	end
	for _, slot in pairs(self.unitSlots) do ClearSlot(slot) end
	self.guidStates = {}
end

function DR:ResetPreview()
	for i = 1, MAX_UNITS do
		local slot = self.slots[i]
		if slot then slot.previewStates = nil end
	end
	for _, slot in pairs(self.unitSlots) do slot.previewStates = nil end
end

local function NextLevel(current)
	if not current then return DRList:NextDR(1) end
	if current == 0.5 then return DRList:NextDR(2) end
	return DRList:NextDR(3)
end

local function VisibleCategories(slot, now, output)
	local logic = DR:GetDB()
	output = output or slot
	local visible = output.visibleCategories or {}
	output.visibleCategories = visible
	wipe(visible)
	for _, category in ipairs(slot.order) do
		local state = slot.categories[category]
		if state and (state.active or (state.expiresAt and state.expiresAt > now))
			and not (logic and logic.categories and logic.categories[category] == false) then
			visible[#visible + 1] = state
		end
	end
	return visible
end

local function PreviewCategories(slot, index, now)
	local logic = DR:GetDB()
	if not slot.previewStates then
		slot.previewStates = {}
		local duration = tonumber(logic and logic.duration) or 18
		for i, entry in ipairs(PREVIEW_ROWS[index] or PREVIEW_ROWS[1]) do
			local spellID, level, remaining = entry[1], entry[2], entry[3]
			local state = { spellID = spellID, level = level,
				category = DRSpellCategories[spellID], pulseStart = now - (i - 1) * 0.2 }
			state.previewRemaining = remaining
			state.startedAt = now - (duration - remaining)
			state.expiresAt = now + remaining
			slot.previewStates[#slot.previewStates + 1] = state
		end
	end
	local visible = slot.visibleCategories or {}
	slot.visibleCategories = visible
	wipe(visible)
	for _, state in ipairs(slot.previewStates) do
		if state.previewRemaining and state.expiresAt <= now then
			state.startedAt = now
			state.expiresAt = now + state.previewRemaining
			state.pulseStart = now
		end
		if state.category and not (logic and logic.categories and logic.categories[state.category] == false) then
			visible[#visible + 1] = state
		end
	end
	return visible
end

local function PaintSlot(slot, visible, count, growth, size, height, spacing, gladius, visual, now)
	for i = 1, #slot.icons do
		local icon = slot.icons[i]
		local state = visible[i]
		if i <= count and state then
			if icon.gladiusTexture ~= gladius then
				if gladius then icon.texture:SetTexCoord(0, 1, 0, 1)
				else icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
				icon.gladiusTexture = gladius
			end
			local layout = icon.layout
			if not layout or layout[1] ~= growth or layout[2] ~= size
				or layout[3] ~= height or layout[4] ~= spacing or layout[5] ~= i then
				layout = layout or {}
				icon.layout = layout
				layout[1], layout[2], layout[3], layout[4], layout[5] = growth, size, height, spacing, i
				icon:SetSize(size, height)
				icon.animatedGlow:SetSize(size * 1.13, height * 1.13)
				icon.flash:SetSize(size * 2.25, height * 2.25)
				icon:ClearAllPoints()
				if growth == "RIGHT" then
					icon:SetPoint("LEFT", slot.holder, "LEFT", (i - 1) * (size + spacing), 0)
				elseif growth == "LEFT" then
					icon:SetPoint("RIGHT", slot.holder, "RIGHT", -(i - 1) * (size + spacing), 0)
				elseif growth == "UP" then
					icon:SetPoint("BOTTOM", slot.holder, "BOTTOM", 0, (i - 1) * (height + spacing))
				else
					icon:SetPoint("TOP", slot.holder, "TOP", 0, -(i - 1) * (height + spacing))
				end
			end
			if icon.spellID ~= state.spellID then
				icon.texture:SetTexture(select(3, GetSpellInfo(state.spellID)))
				icon.spellID = state.spellID
			end
			local r, g, b = 1, 1, 1
			if visual.borderColors ~= false then r, g, b = ColorFor(state.level, visual) end
			if icon.colorR ~= r or icon.colorG ~= g or icon.colorB ~= b then
				for _, stroke in ipairs(icon.borderStrokes) do
					stroke:SetVertexColor(r, g, b, 1)
				end
				icon.animatedGlow:SetVertexColor(r, g, b, 1)
				icon.flash:SetVertexColor(r, g, b, 1)
				icon.colorR, icon.colorG, icon.colorB = r, g, b
			end
			if icon._state ~= state or icon._pulseStart ~= state.pulseStart or not icon:IsShown() then
				icon._state = state
				icon._pulseStart = state.pulseStart or now
				icon.glowAnim:Stop()
				icon.flashAnim:Stop()
				icon.animatedGlow:SetAlpha(0)
				icon.flash:SetAlpha(0)
				icon.glowAnim:Play()
				icon.flashAnim:Play()
			end
			local remaining = state.expiresAt and (state.expiresAt - now)
			local pulseThreshold = tonumber(visual.pulseThreshold) or 5
			SetWarningPulse(icon, visual.pulseLastFive ~= false
				and remaining and remaining > 0 and remaining < pulseThreshold)
			if state.active then
				StopCountdown(icon)
			else
				local duration = state.expiresAt - state.startedAt
				if icon._cooldownStart ~= state.startedAt then
					CooldownFrame_SetTimer(icon.cooldown, state.startedAt, duration, 1)
					icon._cooldownStart = state.startedAt
				end
				local drawEdge = visual.cooldownEdge == true
				if icon.drawEdge ~= drawEdge or icon._edgeStart ~= state.startedAt then
					if icon.cooldown.SetDrawEdge then icon.cooldown:SetDrawEdge(drawEdge) end
					icon.drawEdge = drawEdge
					icon._edgeStart = state.startedAt
				end
				-- The 3.3.5 cooldown draws its edge and sweep in one frame.
				local sweepAlpha = (visual.showSweep ~= false or drawEdge) and 0.65 or 0
				if icon.sweepAlpha ~= sweepAlpha then
					icon.cooldown:SetAlpha(sweepAlpha)
					icon.sweepAlpha = sweepAlpha
				end
				if SarychUI_NotifyCooldown then
					SarychUI_NotifyCooldown(icon.cooldown, state.startedAt, duration, 1)
				end
				if not icon.cooldown:IsShown() then icon.cooldown:Show() end
			end
			if not icon:IsShown() then icon:Show() end
		else
			StopCountdown(icon)
			if icon:IsShown() then StopGlow(icon) end
			if icon:IsShown() then icon:Hide() end
		end
	end
	slot.holder:Show()
end

function DR:Render(index)
	local slot = self.slots[index]
	if not slot then return end
	local db, cfg = DB(), Settings()
	local visual = self:GetDB() or {}
	if not self.arenaActive or not db or not module:IsDRShown() then
		slot.holder:Hide()
		return
	end
	if db.frameType == "gladius" and cfg and cfg.side ~= "RIGHT"
		and module:GetGladiusLeftContent() ~= "diminishings" then
		slot.holder:Hide()
		return
	end
	local preview = db.testMode and db.testMode > 0 and select(2, IsInInstance()) ~= "arena"
	local frame = preview and module:GetVisibleTestFrame(index) or _G["ArenaEnemyFrame" .. index]
	if not frame or not frame:IsVisible() or (not preview and not UnitExists("arena" .. index))
		or (module.IsArenaOpponentDead and module:IsArenaOpponentDead(index, preview)) then
		slot.holder:Hide()
		return
	end
	local frameAlpha = frame.GetEffectiveAlpha and frame:GetEffectiveAlpha() or frame:GetAlpha()
	if slot.holder:GetAlpha() ~= frameAlpha then slot.holder:SetAlpha(frameAlpha) end
	local now = GetTime()
	local visible
	if preview then visible = PreviewCategories(slot, index, now)
	else slot.previewStates = nil; visible = VisibleCategories(slot, now) end
	local count = math.min(#visible, #slot.icons)
	if count == 0 then slot.holder:Hide(); return end
	local gladius = db.frameType == "gladius"
	local frameName = frame.GetName and frame:GetName()
	local portrait = gladius and (frame.classPortrait or (frameName and _G[frameName .. "ClassPortrait"]))
	local side = cfg.side == "RIGHT" and "RIGHT" or "LEFT"
	local growth = side
	local anchor, anchorOffsetX, anchorOffsetY
	if side == "RIGHT" and module.GetAbilityAnchor then
		anchor, anchorOffsetX, anchorOffsetY = module:GetAbilityAnchor(index, preview, "RIGHT")
	else
		anchor = portrait or frame
	end
	anchor = anchor or frame
	local abilitySettings = not gladius and module.GetEnemyAbilitySettings
		and module:GetEnemyAbilitySettings("classic")
	local size = gladius and (portrait and portrait:GetWidth() or 40)
		or (tonumber(abilitySettings and abilitySettings.layout and abilitySettings.layout.size) or 24)
	local height = gladius and (portrait and portrait:GetHeight() or 41) or size
	if size <= 0 then size = 40 end
	if height <= 0 then height = 41 end
	local spacing = tonumber(cfg.spacing) or 3
	local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()
	local frameScale = frame.GetEffectiveScale and frame:GetEffectiveScale()
	if parentScale and parentScale > 0 and frameScale then
		local scale = frameScale / parentScale
		if slot.holderScale ~= scale then
			slot.holder:SetScale(scale)
			slot.holderScale = scale
		end
	end
	local x, y = tonumber(cfg.x) or (side == "LEFT" and -2 or 2), tonumber(cfg.y) or 0
	if side == "RIGHT" then
		x = x + (tonumber(anchorOffsetX) or 0)
		y = y + (tonumber(anchorOffsetY) or 0)
	end
	local layout = slot.layout
	if not layout or layout[1] ~= anchor or layout[2] ~= gladius or layout[3] ~= side
		or layout[4] ~= x or layout[5] ~= y or layout[6] ~= count
		or layout[7] ~= size or layout[8] ~= height or layout[9] ~= spacing then
		layout = layout or {}
		slot.layout = layout
		layout[1], layout[2], layout[3], layout[4], layout[5] = anchor, gladius, side, x, y
		layout[6], layout[7], layout[8], layout[9] = count, size, height, spacing
		slot.holder:SetSize(count * size + (count - 1) * spacing, height)
		slot.holder:ClearAllPoints()
		if gladius then
			slot.holder:SetPoint(side == "LEFT" and "TOPRIGHT" or "TOPLEFT", anchor,
				side == "LEFT" and "TOPLEFT" or "TOPRIGHT", x, y)
		else
			slot.holder:SetPoint(side == "LEFT" and "RIGHT" or "LEFT", anchor, side, x, y)
		end
	end
	PaintSlot(slot, visible, count, growth, size, height, spacing, gladius, visual, now)
end

local FRAME_DEFAULTS = {
	player = { x = 40, y = 20, size = 30, spacing = 3, anchor = "TOPLEFT", growth = "RIGHT" },
	target = { x = -40, y = 20, size = 30, spacing = 3, anchor = "TOPRIGHT", growth = "LEFT" },
	focus = { x = -40, y = 20, size = 30, spacing = 3, anchor = "TOPRIGHT", growth = "LEFT" },
	party = { x = 0, y = 15, size = 20, spacing = 3, anchor = "TOPLEFT", growth = "RIGHT" },
}

local function UnitKind(unit)
	return unit:match("^party") and "party" or unit
end

local function UnitFrame(unit)
	if unit == "player" then return _G.PlayerFrame end
	if unit == "target" then return _G.TargetFrame end
	if unit == "focus" then return _G.FocusFrame end
	local index = tonumber(unit:match("^party(%d+)$"))
	if not index then return nil end
	-- Compact party frames can replace the Blizzard party frames. Prefer the visible
	-- frame whose unit token matches, including raid-style compact party layouts.
	for i = 1, 5 do
		local frame = _G["CompactPartyFrameMember" .. i]
		if frame and frame:IsVisible() and frame.unit == unit then return frame end
	end
	for group = 1, 8 do
		for member = 1, 5 do
			local frame = _G["CompactRaidGroup" .. group .. "Member" .. member]
			if frame and frame:IsVisible() and frame.unit == unit then return frame end
		end
	end
	for i = 1, 40 do
		local frame = _G["CompactRaidFrame" .. i]
		if frame and frame:IsVisible() and frame.unit == unit then return frame end
	end
	return _G["PartyMemberFrame" .. index]
end

local function EnsureUnitSlot(unit)
	local slot = DR.unitSlots[unit]
	if slot then return slot end
	local holder = CreateFrame("Frame", nil, UIParent)
	holder:SetFrameStrata("HIGH")
	holder:Hide()
	slot = { holder = holder, icons = {}, guid = nil }
	for i = 1, 16 do slot.icons[i] = MakeIcon(holder) end
	DR.unitSlots[unit] = slot
	return slot
end

local function AnchorPoint(anchor, growth)
	-- The first icon starts at the selected frame point; growth extends from it.
	if growth == "LEFT" then
		return anchor:find("RIGHT") and anchor or anchor:gsub("LEFT", "RIGHT")
	end
	if growth == "RIGHT" then
		return anchor:find("LEFT") and anchor or anchor:gsub("RIGHT", "LEFT")
	end
	if growth == "UP" then
		return anchor:find("BOTTOM") and anchor or anchor:gsub("TOP", "BOTTOM")
	end
	return anchor:find("TOP") and anchor or anchor:gsub("BOTTOM", "TOP")
end

local FREE_FALLBACK = {
	player = { -350, -140 }, target = { 350, -140 }, focus = { 350, -280 },
	party1 = { -450, 180 }, party2 = { -450, 110 },
	party3 = { -450, 40 }, party4 = { -450, -30 },
}

local function FreeId(unit)
	return "diminishings:" .. unit
end

local function FreeLabel(unit)
	local names = { player = "Игрок", target = "Цель", focus = "Фокус" }
	return names[unit] or ("Группа " .. (unit:match("^party(%d+)$") or unit))
end

local function ShowPreviewLabel(slot, unit, show)
	if not show then
		if slot.previewLabel then slot.previewLabel:Hide() end
		return
	end
	if not slot.previewLabel then
		local label = slot.holder:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		label:SetFont("Interface\\AddOns\\SarychUI\\media\\fonts\\Homespun.ttf", 12, "")
		label:SetTextColor(0.2, 1.0, 0.35, 0.95)
		label:SetJustifyH("LEFT")
		label:SetPoint("BOTTOMLEFT", slot.holder, "TOPLEFT", 0, 5)
		slot.previewLabel = label
	end
	slot.previewLabel:SetText("DR: " .. FreeLabel(unit))
	slot.previewLabel:Show()
end

local function FreeConfig(unit)
	local db = DR:GetDB()
	local kind = UnitKind(unit)
	if not db then return nil end
	db.frames = db.frames or {}
	db.frames[kind] = db.frames[kind] or {}
	local settings = db.frames[kind]
	settings.free = settings.free or {}
	local pos = settings.free[unit]
	if not pos then
		local slot = DR.unitSlots[unit]
		local frame = UnitFrame(unit)
		local source = slot and slot.layout and slot.holder or frame
		local cx, cy = source and source.GetCenter and source:GetCenter()
		local px, py = UIParent:GetCenter()
		local fallback = FREE_FALLBACK[unit] or { 0, 0 }
		pos = { x = cx and px and (cx - px) or fallback[1],
			y = cy and py and (cy - py) or fallback[2], showDragFrame = 0 }
		settings.free[unit] = pos
	end
	return pos
end

function DR:IsFreeMoveActive(unit)
	local db = self:GetDB()
	local kind = UnitKind(unit)
	local settings = db and db.frames and db.frames[kind]
	local pos = settings and settings.free and settings.free[unit]
	return settings and settings.anchor == "NONE" and pos and pos.showDragFrame == 1 or false
end

function DR:ToggleFreeMove(unit)
	local db = self:GetDB()
	local kind = UnitKind(unit)
	local settings = db and db.frames and db.frames[kind]
	if not settings or settings.anchor ~= "NONE" then return end
	local pos = FreeConfig(unit)
	local frameId = FreeId(unit)
	local drag = SarychUI.DragMode
	local panel = SarychUI.PositionDragPanel
	if not drag or not panel or not panel.RegisterFrame then return end
	if pos.showDragFrame == 1 then
		pos.showDragFrame = 0
		panel:Toggle(frameId, false)
		drag:EnableEditMode(frameId, false, false, false)
		self:Refresh()
		return
	end
	pos.showDragFrame = 1
	self:Refresh()
	local slot = EnsureUnitSlot(unit)
	if not drag:GetFrameData(frameId) then
		drag:RegisterFrame(frameId, slot.holder, {
			dragText = "DR: " .. FreeLabel(unit),
			preservePositionOnDisable = true,
			getPoint = function()
				local free = FreeConfig(unit)
				return { "CENTER", UIParent, "CENTER", free.x, free.y }
			end,
			onPositionChanged = function(_, _, x, y)
				local editor = SarychUI.PositionDragPanel
				if editor and editor.OnDragPosition
					and editor:OnDragPosition(frameId, x, y, "CENTER", "CENTER") then return end
				local free = FreeConfig(unit)
				free.x, free.y = x, y
				slot.layout = nil
			end,
		})
	end
	panel:RegisterFrame(frameId, {
		title = "Диминишинги: " .. FreeLabel(unit),
		moduleKey = "diminishings", subKey = "frames." .. kind .. ".free." .. unit,
		xKey = "x", yKey = "y", dragFlag = "showDragFrame",
		defaultX = pos.x, defaultY = pos.y,
		min = -2000, max = 2000, point = "CENTER", relativePoint = "CENTER",
		onClosed = function() DR:Refresh() end,
	})
	panel:Toggle(frameId, true)
end

function DR:StopFreeMoveKind(kind)
	local first = kind == "party" and 1 or 0
	local last = kind == "party" and 4 or 0
	for i = first, last do
		local unit = kind == "party" and ("party" .. i) or kind
		local pos = FreeConfig(unit)
		if pos and pos.showDragFrame == 1 then
			local frameId = FreeId(unit)
			local panel = SarychUI.PositionDragPanel
			if panel and panel.Toggle then panel:Toggle(frameId, false) end
			pos.showDragFrame = 0
			if SarychUI.DragMode then
				SarychUI.DragMode:EnableEditMode(frameId, false, false, false)
			end
		end
	end
end

function DR:RenderUnit(unit)
	local db = self:GetDB()
	local kind = UnitKind(unit)
	if not self.unitActive or not db or db[kind] ~= true then
		local old = self.unitSlots[unit]
		if old then old.holder:Hide() end
		return
	end
	local slot = EnsureUnitSlot(unit)
	local frame = UnitFrame(unit)
	local settings = db.frames and db.frames[kind] or {}
	local detached = settings.anchor == "NONE"
	local editing = self:IsFreeMoveActive(unit)
	local preview = self.unitPreview or editing
	ShowPreviewLabel(slot, unit, self.unitPreview and detached and not editing)
	if not self.unitContextAllowed and not preview then slot.holder:Hide(); return end
	local guid = not preview and UnitGUID(unit)
	if (not detached and (not frame or not frame:IsVisible()
		or (preview and not UnitExists(unit)))) or (not preview and not guid) then
		slot.holder:Hide()
		return
	end
	local now = GetTime()
	local visible
	if preview then
		local index = ({ player = 1, target = 2, focus = 3 })[kind]
			or tonumber(unit:match("^party(%d+)$")) or 1
		visible = PreviewCategories(slot, index, now)
	else
		slot.previewStates = nil
		local state = self.guidStates[guid]
		if not state then slot.holder:Hide(); return end
		visible = VisibleCategories(state, now, slot)
	end
	local count = math.min(#visible, #slot.icons)
	if count == 0 and not editing then slot.holder:Hide(); return end
	local layoutCount = math.max(count, 1)
	local defaults = FRAME_DEFAULTS[kind]
	local size = tonumber(settings.size) or defaults.size
	local spacing = tonumber(settings.spacing) or defaults.spacing
	local growth = settings.growth or defaults.growth
	local anchor = settings.anchor or defaults.anchor
	local x = tonumber(settings.x) or defaults.x
	local y = tonumber(settings.y) or defaults.y
	local vertical = growth == "UP" or growth == "DOWN"
	local width = vertical and size or layoutCount * size + (layoutCount - 1) * spacing
	local height = vertical and layoutCount * size + (layoutCount - 1) * spacing or size
	local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()
	local frameScale = frame and frame.GetEffectiveScale and frame:GetEffectiveScale()
	if detached and slot.holderScale ~= 1 then
		slot.holder:SetScale(1)
		slot.holderScale = 1
	end
	if not detached and parentScale and parentScale > 0 and frameScale then
		local scale = frameScale / parentScale
		if slot.holderScale ~= scale then slot.holder:SetScale(scale); slot.holderScale = scale end
	end
	local free = detached and FreeConfig(unit)
	local attachedPreview = preview and not detached
	local layoutFrame = not detached and frame or nil
	local layoutX, layoutY = detached and free.x or x, detached and free.y or y
	local layout = slot.layout
	if not layout or layout[1] ~= layoutFrame or layout[2] ~= attachedPreview
		or layout[3] ~= anchor or layout[4] ~= growth or layout[5] ~= layoutX
		or layout[6] ~= layoutY or layout[7] ~= size or layout[8] ~= spacing
		or layout[9] ~= layoutCount or layout[10] ~= detached then
		slot.holder:SetSize(width, height)
		local dragData = detached and SarychUI.DragMode and SarychUI.DragMode:GetFrameData(FreeId(unit))
		if not (dragData and dragData.isMoving) then
			layout = layout or {}
			slot.layout = layout
			layout[1], layout[2], layout[3], layout[4] = layoutFrame, attachedPreview, anchor, growth
			layout[5], layout[6], layout[7], layout[8] = layoutX, layoutY, size, spacing
			layout[9], layout[10] = layoutCount, detached
			slot.holder:ClearAllPoints()
			if detached then
				slot.holder:SetPoint("CENTER", UIParent, "CENTER", free.x, free.y)
			elseif attachedPreview then
				slot.holder:SetPoint("BOTTOM", frame, "TOP", x, y)
			else
				slot.holder:SetPoint(AnchorPoint(anchor, growth), frame, anchor, x, y)
			end
		end
	end
	local alpha = (preview or detached) and 1
		or (frame.GetEffectiveAlpha and frame:GetEffectiveAlpha() or frame:GetAlpha())
	if slot.holder:GetAlpha() ~= alpha then slot.holder:SetAlpha(alpha) end
	PaintSlot(slot, visible, count, growth, size, size, spacing, false, db, now)
end

function DR:RenderUnits()
	for _, unit in ipairs({ "player", "target", "focus", "party1", "party2", "party3", "party4" }) do
		self:RenderUnit(unit)
	end
end

function DR:Refresh()
	local db = DB()
	local logic = self:GetDB()
	local allowed = self:IsContextAllowed()
	self.unitContextAllowed = allowed
	self.unitPreview = self.previewEnabled == true
	local editing = false
	for _, unit in ipairs({ "player", "target", "focus", "party1", "party2", "party3", "party4" }) do
		if self:IsFreeMoveActive(unit) then editing = true; break end
	end
	self.arenaActive = allowed and db and db.enabled and self:IsArenaEnabled()
		and module:IsDRShown() or false
	self.unitActive = (allowed or self.unitPreview or editing) and logic and logic.enabled ~= false and
		(logic.player == true or logic.target == true or logic.focus == true or logic.party == true) or false
	self.enabled = self.arenaActive or self.unitActive
	if not self.enabled then self.eventFrame:Hide(); self:Reset(); return end
	if self.arenaActive then
		for i = 1, MAX_UNITS do
			local slot = EnsureSlot(i)
			local guid = UnitGUID("arena" .. i)
			if slot.guid and guid and slot.guid ~= guid then ClearSlot(slot) end
			if guid then slot.guid = guid end
			self:Render(i)
		end
	else
		for i = 1, MAX_UNITS do
			local slot = self.slots[i]
			if slot then slot.holder:Hide() end
		end
	end
	self:RenderUnits()
	self.eventFrame:Show()
end

local function ApplyAura(slot, event, spellID)
	local category = DRSpellCategories[spellID]
	if not category then return end
	local logic = DR:GetDB()
	local now = GetTime()
	local state = slot.categories[category]
	if state and state.expiresAt and state.expiresAt <= now then
		slot.categories[category] = nil
		state = nil
	end
	if event == "SPELL_AURA_REMOVED" then
		if not state or not state.active then return end
		state.active[spellID] = nil
		if not next(state.active) then
			state.active = nil
			state.startedAt = now
			state.expiresAt = now + (tonumber(logic and logic.duration) or 18)
		end
	else
		if not state then
			state = { category = category }
			slot.categories[category] = state
			if not slot.inOrder[category] then
				slot.order[#slot.order + 1] = category
				slot.inOrder[category] = true
			end
		end
		state.level = NextLevel(state.level)
		state.spellID = spellID
		state.pulseStart = now
		state.expiresAt = nil
		state.active = state.active or {}
		state.active[spellID] = true
	end
end

function DR:HandleAura(index, event, spellID)
	ApplyAura(EnsureSlot(index), event, spellID)
	self:Render(index)
end

local eventFrame = CreateFrame("Frame")
DR.eventFrame = eventFrame
eventFrame:Hide()
eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
		DR:Reset()
		DR:Refresh()
		return
	end
	if not DR.enabled then return end
	if event == "ADDON_LOADED" then
		if ... == "Blizzard_ArenaUI" then DR:Refresh() end
		return
	end
	if event == "ARENA_OPPONENT_UPDATE" then
		local unit = ...
		local index = type(unit) == "string" and tonumber(unit:match("^arena(%d+)$"))
		if index and index <= MAX_UNITS then
			local slot = EnsureSlot(index)
			local guid = UnitGUID(unit)
			if slot.guid ~= guid then ClearSlot(slot) end
			slot.guid = guid
			DR:Render(index)
		end
	elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
		local _, subevent, _, _, _, destGUID, _, _, spellID, _, _, auraType = ...
		if subevent == "UNIT_DIED" or subevent == "UNIT_DESTROYED" then
			DR.guidStates[destGUID] = nil
			for i = 1, MAX_UNITS do
				local slot = DR.slots[i]
				if slot and slot.guid == destGUID then ClearSlot(slot) end
			end
			return
		end
		if auraType ~= "DEBUFF" or (subevent ~= "SPELL_AURA_APPLIED"
			and subevent ~= "SPELL_AURA_REFRESH" and subevent ~= "SPELL_AURA_REMOVED") then return end
		if not DRSpellCategories[spellID] then return end
		if DR.unitActive and destGUID then
			local state = DR.guidStates[destGUID]
			if not state and subevent ~= "SPELL_AURA_REMOVED" then
				state = { categories = {}, order = {}, inOrder = {} }
				DR.guidStates[destGUID] = state
			end
			if state then ApplyAura(state, subevent, spellID) end
		end
		if not DR.arenaActive then return end
		for i = 1, MAX_UNITS do
			local unit = "arena" .. i
			local guid = UnitGUID(unit)
			if guid and guid == destGUID then
				local slot = EnsureSlot(i)
				if slot.guid ~= guid then ClearSlot(slot); slot.guid = guid end
				DR:HandleAura(i, subevent, spellID)
				return
			end
		end
	end
end)
eventFrame:SetScript("OnUpdate", function(self, elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed
	if self.elapsed < 0.1 then return end
	self.elapsed = 0
	local now = GetTime()
	for guid, state in pairs(DR.guidStates) do
		local hasCategory = false
		for category, entry in pairs(state.categories) do
			if entry.expiresAt and entry.expiresAt <= now then state.categories[category] = nil
			else hasCategory = true end
		end
		if not hasCategory then DR.guidStates[guid] = nil end
	end
	for i = 1, MAX_UNITS do
		local slot = DR.slots[i]
		if slot then
			for category, state in pairs(slot.categories) do
				if state.expiresAt and state.expiresAt <= now then slot.categories[category] = nil end
			end
			DR:Render(i)
		end
	end
	if DR.unitActive then DR:RenderUnits() end
end)

function DR:Enable()
	if not DRList then return end
	eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	eventFrame:RegisterEvent("ARENA_OPPONENT_UPDATE")
	eventFrame:RegisterEvent("ADDON_LOADED")
	eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:Refresh()
end

function DR:RefreshConfig()
	if self:IsEnabled() then self:Enable() else self:Disable() end
end

function DR:Disable()
	self.previewEnabled = false
	for _, kind in ipairs({ "player", "target", "focus", "party" }) do
		self:StopFreeMoveKind(kind)
	end
	eventFrame:UnregisterAllEvents()
	eventFrame:Hide()
	self.enabled = false
	self.arenaActive = false
	self.unitActive = false
	self.unitPreview = false
	self.unitContextAllowed = false
	self:Reset()
end
