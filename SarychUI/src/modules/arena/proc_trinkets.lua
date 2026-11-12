-- Enemy proc trinkets for the arena layouts. Equipment cannot be inspected
-- reliably on entering arena, so an icon is learned from its first combat-log proc.
local arena = SarychUI.modules and SarychUI.modules.arena
if not arena then return end

local tracker = {}
arena.ProcTrinkets = tracker
local lib = LibStub and LibStub("LibInternalCooldowns-1.1", true)
local procData = SarychUI.Data.InternalCooldowns
local watcher = CreateFrame("Frame")
local slots, icons, pending = {}, {}, {}
local tick = 0
local warmed = false
local TEST_PROC_TIME, TEST_COOLDOWN_TIME, TEST_READY_TIME = 5, 12, 5
local TEST_CYCLE = TEST_PROC_TIME + TEST_COOLDOWN_TIME + TEST_READY_TIME
local PULSE_SPEED = 2 * math.pi / 1.1

local function DB()
	local modules = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return modules and modules.arena
end

local function Enabled()
	local db = DB()
	return db and db.enabled ~= false
		and (db.frameType == "classic" or db.frameType == "gladius")
		and db.procTrinkets
		and (db.frameType == "gladius"
			and (arena:GetGladiusPrimaryContent() == "procTrinkets"
				or arena:GetGladiusLeftContent() == "procTrinkets"
				or arena:GetGladiusRightContent() == "procTrinkets")
			or db.frameType == "classic"
				and (arena:GetClassicPrimaryContent() == "procTrinkets"
					or arena:GetClassicLeftContent() == "procTrinkets"
					or arena:GetClassicRightContent() == "procTrinkets"))
end

local function IsTesting()
	local db = DB()
	return db and (db.testMode or 0) > 0 and select(2, IsInInstance()) ~= "arena"
end

local function StopTimer(icon)
	if not icon then return end
	CooldownFrame_SetTimer(icon.cooldown, 0, 0, 0)
	if SarychUI_ReleaseCooldown then SarychUI_ReleaseCooldown(icon.cooldown)
	elseif SarychUI_NotifyCooldown then SarychUI_NotifyCooldown(icon.cooldown, 0, 0, 0) end
	icon.timerKey = nil
end

local function NewIcon()
	local icon = CreateFrame("Frame", nil, UIParent)
	icon:SetSize(26, 26)
	icon:SetFrameStrata("MEDIUM")
	icon.texture = icon:CreateTexture(nil, "ARTWORK")
	icon.texture:SetAllPoints()
	icon.texture:SetTexCoord(0, 1, 0, 1)
	icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
	icon.cooldown:SetAllPoints()
	icon.cooldown:SetReverse(false)
	icon.cooldown:SetDrawEdge(true)
	icon.cooldown:SetFrameLevel(icon:GetFrameLevel() + 1)
	-- ActionButtonTemplate: equipped items use this green additive border.
	icon.equippedBorder = icon:CreateTexture(nil, "OVERLAY")
	icon.equippedBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	icon.equippedBorder:SetBlendMode("ADD")
	icon.equippedBorder:SetPoint("CENTER")
	icon.equippedBorder:SetSize(26 * 62 / 36, 26 * 62 / 36)
	icon.equippedBorder:SetVertexColor(0, 1, 0, 0.35)
	icon.procBorder = icon:CreateTexture(nil, "OVERLAY")
	icon.procBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	icon.procBorder:SetBlendMode("ADD")
	icon.procBorder:SetPoint("CENTER")
	icon.procBorder:SetSize(48, 48)
	icon.procBorder:SetVertexColor(1, 0.82, 0.28)
	icon.procBorder:Hide()
	icon:SetScript("OnUpdate", function(self)
		if self.procBorder:IsShown() and self.procStart then
			self.procBorder:SetAlpha(0.65 + 0.35 * math.cos((GetTime() - self.procStart) * PULSE_SPEED))
		end
	end)
	icon:Hide()
	return icon
end

local function Icon(slot, number)
	icons[slot] = icons[slot] or {}
	if not icons[slot][number] then icons[slot][number] = NewIcon() end
	return icons[slot][number]
end

local function HideSlot(slot)
	if not icons[slot] then return end
	for _, icon in ipairs(icons[slot]) do
		StopTimer(icon)
		icon.procBorder:Hide()
		icon:Hide()
	end
end

local function CandidateItem(spellID)
	local spellToItem = lib and lib.spellToItem or procData.spellToItem
	local items = spellToItem[spellID]
	if not items then return nil end
	if type(items) ~= "table" then items = { items } end
	local uncached = false
	for _, itemID in ipairs(items) do
		local equipLoc = select(9, GetItemInfo(itemID))
		if equipLoc == "INVTYPE_TRINKET" then return itemID end
		if not equipLoc then uncached = true end
	end
	return nil, uncached
end

local function FindSlot(guid)
	if not guid then return end
	for slot = 1, 5 do
		if UnitGUID("arena" .. slot) == guid then return slot end
	end
end

local function MatchAura(slot, spellID)
	for index = 1, 40 do
		local name, _, _, _, _, duration, expires, _, _, _, id = UnitAura("arena" .. slot, index, "HELPFUL")
		if not name then break end
		if id == spellID then return expires, duration end
	end
end

local function StateList(slot, guid)
	local entry = slots[slot]
	if not entry or entry.guid ~= guid then
		HideSlot(slot)
		entry = { guid = guid, list = {} }
		slots[slot] = entry
	end
	return entry.list
end

local function RecordProc(slot, guid, spellID, itemID, aura, eventTime)
	local list = StateList(slot, guid)
	local now = GetTime()
	eventTime = eventTime or now
	local state
	for _, candidate in ipairs(list) do
		if candidate.itemID == itemID then state = candidate; break end
	end
	if state and state.startedAt and now < state.startedAt + state.duration - 1 then
		if aura then state.active = true end
		return
	end
	if not state then
		state = { itemID = itemID }
		if #list < 2 then list[#list + 1] = state
		else
			local replace = list[1].startedAt < list[2].startedAt and 1 or 2
			list[replace] = state
		end
	end
	state.spellID = spellID
	state.startedAt = eventTime
	state.duration = tonumber((lib and lib.cooldowns or procData.cooldowns)[spellID]) or 45
	state.active = true
	state.activeUntil = eventTime + (aura and 15 or 1.5)
	state.procStart = eventTime
	state.procDuration = state.activeUntil - eventTime
	state.sawAura = false
	state.itemTexture = select(10, GetItemInfo(itemID))
		or "Interface\\Icons\\inv_jewelry_trinketpvp_02"
	state.procTexture = select(3, GetSpellInfo(spellID)) or state.itemTexture
end

local function ProcEvent(subevent, sourceGUID, destGUID, spellID)
	if not Enabled() or IsTesting() or not spellID then return end
	if subevent == "SPELL_AURA_REMOVED" then
		local slot = FindSlot(destGUID)
		local entry = slot and slots[slot]
		if entry then
			for _, state in ipairs(entry.list) do
				if state.spellID == spellID then state.active = false end
			end
		end
		for _, proc in ipairs(pending) do
			if proc[2] == destGUID and proc[3] == spellID then proc[4] = false end
		end
		return
	end
	local aura = subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH"
	if not aura and subevent ~= "SPELL_DAMAGE" and subevent ~= "SPELL_HEAL"
		and subevent ~= "SPELL_CAST_SUCCESS" then return end
	local guid = aura and destGUID or sourceGUID
	local slot = FindSlot(guid)
	if not slot then return end
	local itemID, uncached = CandidateItem(spellID)
	if itemID then RecordProc(slot, guid, spellID, itemID, aura)
	elseif uncached then
		for _, proc in ipairs(pending) do
			if proc[2] == guid and proc[3] == spellID then return end
		end
		pending[#pending + 1] = { slot, guid, spellID, aura, GetTime() }
	end
end

local function ResolvePending()
	for index = #pending, 1, -1 do
		local proc = pending[index]
		local itemID, uncached = CandidateItem(proc[3])
		if itemID or not uncached or GetTime() - proc[5] > 10 then
			if itemID and UnitGUID("arena" .. proc[1]) == proc[2] then
				RecordProc(proc[1], proc[2], proc[3], itemID, proc[4], proc[5])
			end
			table.remove(pending, index)
		end
	end
end

local function TestList(slot)
	local now = GetTime()
	local db = DB()
	local count = db and math.min(tonumber(db.testMode) or 0, 5) or 0
	if slot > count then return end
	local entry = slots[slot]
	if entry and entry.guid == "test:" .. slot then return entry.list end
	local samples = {
		{ { 71485, 50362, 1 }, { 71605, 50360, 8 } },
		{ { 64713, 45518, 19 } },
		{ { 67703, 47303, 12 }, { 75456, 54590, 2 } },
		{ { 60065, 40684, 20 } },
		{ { 71485, 50362, 14 }, { 71605, 50360, 21 } },
	}
	local list = {}
	for i, sample in ipairs(samples[slot]) do
		local spellID, itemID, offset = unpack(sample)
		local itemTexture = select(10, GetItemInfo(itemID))
			or "Interface\\Icons\\inv_jewelry_trinketpvp_02"
		list[i] = {
			itemID = itemID, spellID = spellID, duration = TEST_COOLDOWN_TIME,
			testStart = now - offset,
			itemTexture = itemTexture,
			procTexture = select(3, GetSpellInfo(spellID)) or itemTexture,
			test = true,
		}
	end
	StateList(slot, "test:" .. slot)
	slots[slot].list = list
	return list
end

local function Position(slot, frame, test, count)
	local db = DB()
	local tr = db.Trinkets or {}
	local gladius = db.frameType == "gladius"
	local primaryProc = (gladius and arena:GetGladiusPrimaryContent()
		or arena:GetClassicPrimaryContent()) == "procTrinkets"
	local leftProc = (gladius and arena:GetGladiusLeftContent()
		or arena:GetClassicLeftContent()) == "procTrinkets"
	local scale = (gladius and 1 or (tonumber(tr.scale) or 1))
		* frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local gap = gladius and 1
		or (tonumber(db.procTrinkets and db.procTrinkets.spacing) or tonumber(tr.spacing) or 5)
	local defaultX = gladius and 6 or 2
	local anchor, offsetX
	local abilities = SarychUI.extensions and SarychUI.extensions.party_abilities
	local settings = arena.GetEnemyAbilitySettings and arena:GetEnemyAbilitySettings(db.frameType)
	local abilityRight = (gladius and arena:GetGladiusRightContent() == "enemyAbilities"
		or not gladius and arena:GetClassicRightContent() == "enemyAbilities")
		and settings and settings.layout and settings.layout.side ~= "LEFT"
	if abilityRight then
		anchor = abilities and abilities.GetArenaRightmostAbilityIcon
			and abilities:GetArenaRightmostAbilityIcon(frame)
		if not anchor then
			local base, x = arena:GetAbilityAnchor(slot, test, "RIGHT")
			anchor = base
			local layout = settings.layout
			local perRow = math.max(1, tonumber(layout.perRow) or 6)
			local reserved = math.min(perRow, 4)
			offsetX = (x or 0) + (tonumber(layout.autoX) or 7)
				+ reserved * ((tonumber(layout.size) or 24) + (tonumber(layout.spacing) or 2))
		end
	else
		anchor, offsetX = arena:GetAbilityAnchor(slot, test, "RIGHT")
		if anchor == frame and offsetX == nil then offsetX = defaultX end
	end
	if not anchor then anchor = frame; offsetX = defaultX end
	local iconEffectiveScale = scale * UIParent:GetEffectiveScale()
	local frameEffectiveScale = frame:GetEffectiveScale()
	local anchorEffectiveScale = anchor:GetEffectiveScale()
	local blockGap = anchor == frame and not abilityRight and offsetX == defaultX and 0 or gap
	local anchorRight = anchor:GetRight()
	local frameRight = frame:GetRight()
	local x = anchorRight and frameRight
		and (anchorRight * anchorEffectiveScale - frameRight * frameEffectiveScale) / iconEffectiveScale
		or 0
	x = x + (tonumber(offsetX) or 0) * anchorEffectiveScale / iconEffectiveScale + blockGap
	-- The ability icon supplies only X. Y follows the trinket/racial icons.
	local prefix = test and "SarychUIArenaTestTrinket" .. slot or "arena" .. slot
	local first = test and _G[prefix .. "Trinket1"] or arena.Trinkets[prefix .. "Trinket1"]
	local second = test and _G[prefix .. "Racial"] or arena.Trinkets[prefix .. "Trinket2"]
	local frameCenterY = select(2, frame:GetCenter())
	local baseline = gladius and 0 or -2
	if frameCenterY then
		local total, found = 0, 0
		for _, standard in pairs({ first = first, second = second }) do
			if standard and standard:IsShown() then
				local centerY = select(2, standard:GetCenter())
				if centerY then
					total = total + centerY * standard:GetEffectiveScale()
					found = found + 1
				end
			end
		end
		if found > 0 then
			baseline = (total / found - frameCenterY * frameEffectiveScale) / iconEffectiveScale
		elseif gladius and frame:GetTop() then
			baseline = (frame:GetTop() - frameCenterY) * frameEffectiveScale
				/ iconEffectiveScale - 41 / 2
		end
	end
	local column = not gladius and db.procTrinkets.layout == "COLUMN" and count > 1
	local width = gladius and 40 or 26
	local height = gladius and 41 or 26
	local leftAnchor = leftProc and arena:GetAbilityAnchor(slot, test, "LEFT")
	for index = 1, count do
		local icon = Icon(slot, index)
		icon:SetSize(width, height)
		icon:SetScale(scale)
		icon:SetFrameStrata(frame:GetFrameStrata())
		icon:SetFrameLevel(frame:GetFrameLevel() + 3)
		icon.cooldown:SetFrameLevel(icon:GetFrameLevel() + 1)
		icon.equippedBorder:SetSize(width * 62 / 36, height * 62 / 36)
		icon.procBorder:SetSize(width * 48 / 26, height * 48 / 26)
		icon:ClearAllPoints()
		if primaryProc then
			if index == 1 then
				if first and first:IsShown() then
					icon:SetPoint("LEFT", first, "RIGHT", gap,
						column and (height + gap) / 2 or 0)
				else
					if gladius then icon:SetPoint("TOPLEFT", frame, "TOPRIGHT", 6, 0)
					else icon:SetPoint("LEFT", frame, "RIGHT", 2,
						baseline + (column and (height + gap) / 2 or 0)) end
				end
			elseif column then
				icon:SetPoint("TOP", Icon(slot, 1), "BOTTOM", 0, -gap)
			else
				icon:SetPoint("LEFT", Icon(slot, index - 1), "RIGHT", gap, 0)
			end
		elseif leftProc and leftAnchor then
			if index == 1 then
				if not gladius then
					icon:SetPoint("RIGHT", frame, "LEFT", -2,
						baseline + (column and (height + gap) / 2 or 0))
				elseif leftAnchor == frame then
					icon:SetPoint("TOPRIGHT", frame, "TOPLEFT", -11, 0)
				else
					icon:SetPoint("RIGHT", leftAnchor, "LEFT", -11, 0)
				end
			elseif column then
				icon:SetPoint("TOP", Icon(slot, 1), "BOTTOM", 0, -gap)
			else
				icon:SetPoint("RIGHT", Icon(slot, index - 1), "LEFT", -gap, 0)
			end
		elseif index == 1 then
			local firstY = baseline + (column and (height + gap) / 2 or 0)
			icon:SetPoint("LEFT", frame, "RIGHT",
				x + (gladius and 5 or 0), firstY)
		elseif column then
			icon:SetPoint("TOP", Icon(slot, 1), "BOTTOM", 0, -gap)
		else
			icon:SetPoint("LEFT", Icon(slot, index - 1), "RIGHT", gap, 0)
		end
	end
end

local function RenderState(icon, state, slot, now, desaturate, procIconMode)
	if icon.spellID ~= state.spellID then
		StopTimer(icon)
		icon.spellID = state.spellID
		icon.currentTexture = nil
	end
	if state.test then
		local elapsed = now - state.testStart
		local cycleStart = state.testStart + math.floor(elapsed / TEST_CYCLE) * TEST_CYCLE
		state.active = now - cycleStart < TEST_PROC_TIME
		state.activeUntil = cycleStart + TEST_PROC_TIME
		state.procStart = cycleStart
		state.procDuration = TEST_PROC_TIME
		state.startedAt = state.activeUntil
		state.duration = TEST_COOLDOWN_TIME
	elseif state.active then
		local expires, auraDuration = MatchAura(slot, state.spellID)
		if expires and expires > now then
			state.activeUntil, state.sawAura = expires, true
			if auraDuration and auraDuration > 0 then
				state.procStart = expires - auraDuration
				state.procDuration = auraDuration
			end
		elseif state.sawAura or now >= state.activeUntil then state.active = false end
	end
	local phase = state.active and "active" or now < state.startedAt + state.duration and "cooldown" or "ready"
	local texture = phase == "active" and procIconMode ~= "ITEM"
		and state.procTexture or state.itemTexture
	if icon.currentTexture ~= texture then
		icon.texture:SetTexture(texture)
		icon.currentTexture = texture
	end
	if phase ~= "ready" then
		local timerStart = phase == "active" and state.procStart or state.startedAt
		local timerDuration = phase == "active" and state.procDuration or state.duration
		local key = phase .. ":" .. timerStart .. ":" .. timerDuration
		if icon.timerKey ~= key then
			CooldownFrame_SetTimer(icon.cooldown, timerStart, timerDuration, 1)
			if SarychUI_NotifyCooldown then
				SarychUI_NotifyCooldown(icon.cooldown, timerStart, timerDuration, 1)
			end
			icon.timerKey = key
		end
	else
		if icon.timerKey then StopTimer(icon) end
	end
	icon.texture:SetDesaturated(phase == "cooldown" and desaturate)
	if phase == "active" then
		icon.equippedBorder:Hide()
		icon.procStart = state.procStart
		if not icon.procBorder:IsShown() then
			icon.procBorder:SetAlpha(1)
			icon.procBorder:Show()
		end
	else
		icon.procBorder:Hide()
		icon.equippedBorder:Show()
	end
	icon:Show()
end

function tracker:Update()
	if not Enabled() then
		for slot = 1, 5 do HideSlot(slot) end
		return
	end
	local test = IsTesting()
	local db = DB()
	if not test and #pending > 0 then ResolvePending() end
	for slot = 1, 5 do
		if not test and slots[slot] and slots[slot].guid == "test:" .. slot then
			HideSlot(slot)
			slots[slot] = nil
		end
		local frame = test and arena:GetVisibleTestFrame(slot) or _G["ArenaEnemyFrame" .. slot]
		local guid = test and "test:" .. slot or UnitGUID("arena" .. slot)
		local list = test and TestList(slot) or (guid and StateList(slot, guid))
		if frame and frame:IsVisible() and guid and list and #list > 0
			and not arena:IsArenaOpponentDead(slot, test) then
			Position(slot, frame, test, #list)
			for index, state in ipairs(list) do
				local icon = Icon(slot, index)
				RenderState(icon, state, slot, GetTime(),
					db.procTrinkets.desaturateOnCooldown == true, db.procTrinkets.procIconMode)
				icon:SetAlpha(frame:GetAlpha())
			end
			for index = #list + 1, 2 do
				local icon = icons[slot] and icons[slot][index]
				if icon then StopTimer(icon); icon:Hide() end
			end
		else HideSlot(slot) end
	end
end

function tracker:Refresh()
	if Enabled() then
		if not warmed then
			warmed = true
			for _, items in pairs(lib and lib.spellToItem or procData.spellToItem) do
				if type(items) == "table" then
					for _, itemID in ipairs(items) do GetItemInfo(itemID) end
				else GetItemInfo(items) end
			end
		end
		watcher:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		watcher:RegisterEvent("GET_ITEM_INFO_RECEIVED")
		watcher:Show()
	else
		watcher:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		watcher:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
		watcher:Hide()
	end
	self:Update()
end

function tracker:Disable()
	watcher:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	watcher:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
	watcher:Hide()
	for slot = 1, 5 do HideSlot(slot); slots[slot] = nil end
	wipe(pending)
end

watcher:SetScript("OnEvent", function(_, event, ...)
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		local _, subevent, sourceGUID, _, _, destGUID, _, _, spellID = ...
		ProcEvent(subevent, sourceGUID, destGUID, spellID)
	elseif event == "GET_ITEM_INFO_RECEIVED" then
		ResolvePending()
	end
end)

watcher:SetScript("OnUpdate", function(_, elapsed)
	tick = tick + elapsed
	if tick < 0.1 then return end
	tick = 0
	tracker:Update()
end)
watcher:Hide()
