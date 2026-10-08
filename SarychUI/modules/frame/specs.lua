-- SarychUI Frame Module - talent spec detection + spec icons for unit frame icons.
-- Adapted from FrostAtomUI (Talents + Inspect modules), trimmed to what the
-- player / target / focus icons need:
--   * own spec: read straight from the talent tabs;
--   * other players: one NotifyInspect per unit, result cached by GUID;
--   * hostile players cannot be inspected, so they have no spec (class icon is used).
--
-- API (SarychUI.FrameSpecs):
--   :Get(unit)            -> spec index 1..3 or nil
--   :GetIcon(class, spec) -> icon texture path or nil
--   :SetActive(bool)      -> allow / forbid sending inspect requests
--   :Request(unit)        -> queue an inspect for a unit (no-op while inactive)
--   :Register(fn)         -> fn(guid) is called whenever a spec becomes known

SarychUI = SarychUI or {}
local Specs = SarychUI.FrameSpecs or {}
SarychUI.FrameSpecs = Specs

local CanInspect = CanInspect
local CheckInteractDistance = CheckInteractDistance
local InCombatLockdown = InCombatLockdown
local GetTime = GetTime
local GetSpellInfo = GetSpellInfo
local GetTalentInfo = GetTalentInfo
local GetTalentTabInfo = GetTalentTabInfo
local GetNumTalents = GetNumTalents
local GetNumTalentTabs = GetNumTalentTabs
local GetActiveTalentGroup = GetActiveTalentGroup
local UnitGUID = UnitGUID
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit
local UnitIsPlayer = UnitIsPlayer
local UnitIsVisible = UnitIsVisible
local UnitIsConnected = UnitIsConnected
local UnitCanAttack = UnitCanAttack
local UnitLevel = UnitLevel
local pairs, ipairs, next, wipe = pairs, ipairs, next, wipe

local TICK = 0.1
local SEND_INTERVAL = 1.5
local TIMEOUT = 5
local MAX_RETRIES = 4
local MIN_LEVEL = 10
local CACHE_TIME = 900

-- Units whose spec the frame icons can show.
local WATCHED_UNITS = { "target", "focus" }

--------------------------------------------------------------------
-- Spec icons (tree order = talent tab order)
--------------------------------------------------------------------
local SPEC_ICONS = {
	DEATHKNIGHT = { "Spell_Deathknight_BloodPresence", "Spell_Deathknight_FrostPresence", "Spell_Deathknight_UnholyPresence" },
	DRUID = { "Spell_Nature_StarFall", "Ability_Racial_BearForm", "Spell_Nature_HealingTouch" },
	HUNTER = { "Ability_Hunter_BeastTaming", "Ability_Marksmanship", "Ability_Hunter_SwiftStrike" },
	MAGE = { "Spell_Holy_MagicalSentry", "Spell_Fire_FlameBolt", "Spell_Frost_FrostBolt02" },
	PALADIN = { "Spell_Holy_HolyBolt", "Spell_Holy_DevotionAura", "Spell_Holy_AuraOfLight" },
	PRIEST = { "Spell_Holy_WordFortitude", "Spell_Holy_HolyBolt", "Spell_Shadow_ShadowWordPain" },
	ROGUE = { "Ability_Rogue_Eviscerate", "Ability_BackStab", "Ability_Stealth" },
	SHAMAN = { "Spell_Nature_Lightning", "Spell_Nature_LightningShield", "Spell_Nature_MagicImmunity" },
	WARLOCK = { "Spell_Shadow_DeathCoil", "Spell_Shadow_Metamorphosis", "Spell_Shadow_RainOfFire" },
	WARRIOR = { "Ability_Rogue_Eviscerate", "Ability_Warrior_InnerRage", "Ability_Warrior_DefensiveStance" },
}
for _, icons in pairs(SPEC_ICONS) do
	for i = 1, #icons do
		icons[i] = "Interface\\Icons\\" .. icons[i]
	end
end

-- First-tree talent of every class: used to make sure inspect data belongs to
-- the inspected class and is not a leftover from a previous inspect.
local TREE1_TALENTS = {
	DEATHKNIGHT = 48979, -- Butchery
	DRUID = 16814, -- Starlight Wrath
	HUNTER = 19552, -- Improved Aspect of the Hawk
	MAGE = 11210, -- Arcane Subtlety
	PALADIN = 20205, -- Spiritual Focus
	PRIEST = 14522, -- Unbreakable Will
	ROGUE = 14162, -- Improved Eviscerate
	SHAMAN = 16039, -- Convection
	WARLOCK = 18827, -- Improved Curse of Agony
	WARRIOR = 12282, -- Improved Heroic Strike
}

function Specs:GetIcon(class, spec)
	local icons = class and spec and SPEC_ICONS[class]
	return icons and icons[spec] or nil
end

--------------------------------------------------------------------
-- Talent reading
--------------------------------------------------------------------
-- Returns points spent and the index of the dominant tree (nil on a tie / no points).
local function ReadTrees(isInspect)
	local group = GetActiveTalentGroup and GetActiveTalentGroup(isInspect) or nil
	local numTabs = GetNumTalentTabs and GetNumTalentTabs(isInspect) or 0
	local spent, bestTab, bestPoints = 0, nil, 0
	for tab = 1, numTabs do
		local _, _, points = GetTalentTabInfo(tab, isInspect, nil, group)
		points = points or 0
		spent = spent + points
		if points > bestPoints then
			bestTab, bestPoints = tab, points
		elseif points == bestPoints then
			bestTab = nil
		end
	end
	return spent, bestTab
end

local function TalentsMatchClass(class)
	local id = class and TREE1_TALENTS[class]
	local expected = id and GetSpellInfo(id)
	if not expected then
		return true
	end
	for i = 1, GetNumTalents(1, true) do
		if GetTalentInfo(1, i, true) == expected then
			return true
		end
	end
	return false
end

--------------------------------------------------------------------
-- State
--------------------------------------------------------------------
local cache = {} -- guid -> { spec = n | false, time = t }
local pending = {} -- guid -> true
local retries = {}
local request = {} -- the inspect currently in flight: guid, unit, class, time
local callbacks = {}
local active = false
local lastSend = -SEND_INTERVAL

local queue = CreateFrame("Frame")
queue:Hide()

local function Fire(guid)
	for i = 1, #callbacks do
		callbacks[i](guid)
	end
end

function Specs:Register(fn)
	if type(fn) == "function" then
		callbacks[#callbacks + 1] = fn
	end
end

local function UnitByGUID(guid)
	for i = 1, #WATCHED_UNITS do
		local unit = WATCHED_UNITS[i]
		if UnitGUID(unit) == guid then
			return unit
		end
	end
end

local function Inspectable(unit)
	return UnitExists(unit)
		and UnitIsPlayer(unit)
		and not UnitIsUnit(unit, "player")
		and (UnitLevel(unit) or 0) >= MIN_LEVEL
		and not UnitCanAttack("player", unit)
end

local function Reachable(unit)
	return UnitIsVisible(unit) and UnitIsConnected(unit) and CanInspect(unit) and CheckInteractDistance(unit, 1)
end

--------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------
function Specs:Get(unit)
	if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then
		return nil
	end
	if UnitIsUnit(unit, "player") then
		local _, spec = ReadTrees(false)
		return spec
	end
	local guid = UnitGUID(unit)
	local entry = guid and cache[guid]
	return entry and entry.spec or nil
end

function Specs:Request(unit)
	if not active or not unit or not Inspectable(unit) then
		return
	end
	local guid = UnitGUID(unit)
	local entry = cache[guid]
	if entry and GetTime() - entry.time < CACHE_TIME then
		return
	end
	if request.guid == guid then
		return
	end
	pending[guid] = true
	queue:Show()
end

function Specs:SetActive(state)
	state = state and true or false
	if active == state then
		return
	end
	active = state
	if active then
		for i = 1, #WATCHED_UNITS do
			self:Request(WATCHED_UNITS[i])
		end
	else
		wipe(pending)
		wipe(retries)
	end
end

--------------------------------------------------------------------
-- Inspect queue
--------------------------------------------------------------------
local function Fail(guid)
	local count = (retries[guid] or 0) + 1
	if count > MAX_RETRIES then
		retries[guid] = nil
		pending[guid] = nil
	else
		retries[guid] = count
		pending[guid] = true
		queue:Show()
	end
end

local function Send(now)
	if InCombatLockdown() or (InspectFrame and InspectFrame:IsShown()) then
		return
	end
	if now < lastSend + SEND_INTERVAL then
		return
	end
	for guid in pairs(pending) do
		local unit = UnitByGUID(guid)
		if not unit then
			pending[guid] = nil
			retries[guid] = nil
		elseif Reachable(unit) then
			NotifyInspect(unit)
			return
		end
	end
end

queue:SetScript("OnUpdate", function(self, elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed
	if self.elapsed < TICK then
		return
	end
	self.elapsed = 0
	local now = GetTime()

	if request.guid and now - request.time > TIMEOUT then
		local guid = request.guid
		request.guid = nil
		Fail(guid)
	end

	if active and not request.guid then
		Send(now)
	end

	if not request.guid and not next(pending) then
		self:Hide()
	end
end)

-- Tracks every NotifyInspect (also those sent by other addons / the inspect window),
-- so INSPECT_TALENT_READY can be attributed to the right player.
hooksecurefunc("NotifyInspect", function(unit)
	local guid = unit and UnitGUID(unit)
	if not guid or not UnitIsPlayer(unit) then
		return
	end
	lastSend = GetTime()
	local _, class = UnitClass(unit)
	request.guid, request.unit, request.class, request.time = guid, unit, class, lastSend
	queue:Show()
end)

hooksecurefunc("ClearInspectPlayer", function()
	request.guid = nil
end)

local function OnTalentsReady()
	local guid = request.guid
	if not guid then
		return
	end
	request.guid = nil
	if guid == UnitGUID("player") then
		return
	end
	if not TalentsMatchClass(request.class) then
		Fail(guid)
		return
	end
	local spent, spec = ReadTrees(true)
	if spent <= 0 then
		Fail(guid)
		return
	end
	cache[guid] = { spec = spec or false, time = GetTime() }
	pending[guid] = nil
	retries[guid] = nil
	Fire(guid)
end

--------------------------------------------------------------------
-- Events
--------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("INSPECT_TALENT_READY")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("PLAYER_FOCUS_CHANGED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_TALENT_UPDATE")
events:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
events:SetScript("OnEvent", function(_, event)
	if event == "INSPECT_TALENT_READY" then
		OnTalentsReady()
	elseif event == "PLAYER_TARGET_CHANGED" then
		Specs:Request("target")
	elseif event == "PLAYER_FOCUS_CHANGED" then
		Specs:Request("focus")
	elseif event == "PLAYER_ENTERING_WORLD" then
		wipe(pending)
		wipe(retries)
		request.guid = nil
		for i = 1, #WATCHED_UNITS do
			Specs:Request(WATCHED_UNITS[i])
		end
		Fire(UnitGUID("player"))
	else
		-- PLAYER_TALENT_UPDATE / ACTIVE_TALENT_GROUP_CHANGED: own spec changed.
		Fire(UnitGUID("player"))
	end
end)
