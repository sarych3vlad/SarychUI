local E = select(2, ...):unpack()

local P, CM, CD = E.Party, E.Comm, E.Cooldowns
local pairs, type, min = pairs, type, min
local UnitHealth = UnitHealth
local C_Timer_After = C_Timer.After
local band = bit.band
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local COMBATLOG_OBJECT_REACTION_FRIENDLY = COMBATLOG_OBJECT_REACTION_FRIENDLY

local groupInfo = P.groupInfo
local userGUID = E.userGUID

local minionGUIDS = {}

function CD:Enable()
	if self.isEnabled then
		return
	end
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:RegisterEvent("UNIT_PET")
	self:SetScript("OnEvent", function(self, event, ...)
		self[event](self, ...)
	end)
	self.isEnabled = true
end

function CD:Disable()
	if not self.isEnabled then
		return
	end
	self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:UnregisterEvent("UNIT_PET")
	wipe(minionGUIDS)
	self.isEnabled = false
end

local mt = {
	__index = function(t, k)
		t[k] = {}
		return t[k]
	end
}

local registeredEvents = setmetatable({}, mt)

local function RemoveHighlightByCLEU(info, srcGUID, spellID, destGUID)
	if P.isHighlightEnabled and destGUID == srcGUID then
		local icon = info.glowIcons[spellID]
		if icon then
			icon:RemoveHighlight()
			icon:SetCooldownElements()
			icon:SetOpacity()
			icon:SetColorSaturation()
		end
	end
end

function CD:RegisterRemoveHighlightByCLEU(spellID)
	local func = registeredEvents["SPELL_AURA_REMOVED"][spellID]
	if not func then
		registeredEvents["SPELL_AURA_REMOVED"][spellID] = RemoveHighlightByCLEU
	elseif func ~= RemoveHighlightByCLEU then
		registeredEvents["SPELL_AURA_REMOVED"][spellID] = function(...)
			func(...)
			RemoveHighlightByCLEU(...)
		end
	end
end

local function StartCdOnAuraRemoved(info, srcGUID, spellID, destGUID)
	if srcGUID == destGUID then
		spellID = E.spell_auraremoved_cdstart_preactive[spellID]
		local icon = info.spellIcons[spellID]
		if icon then
			RemoveHighlightByCLEU(info, srcGUID, spellID, destGUID)
			icon:StartCooldown()
		end
	end
end

-- Forbearance (Paladin)
local forbearanceIDs = E.isBCC and {
	[1022] = 0,
	[5599] = 0,
	[10278] = 0,
	[498] = 60,
	[5573] = 60,
	[642] = 60,
	[1020] = 60,
	[31884] = 60,
} or E.isWOTLKC and {
	[1022] = 0,
	[633] = 0,
	[498] = 120,
	[642] = 120,
	[31884] = 30,
} or {
	[1022] = 0,
	[204018] = 0,
	[642] = 30,
	[633] = 0,
}

registeredEvents["SPELL_AURA_REMOVED"][25771] = function(_,_,_, destGUID)
	local destInfo = groupInfo[destGUID]
	if destInfo then
		for id in pairs(forbearanceIDs) do
			local icon = destInfo.preactiveIcons[id]
			if icon then
				destInfo.preactiveIcons[id] = nil
				icon:SetColorSaturation()
				if icon.statusBar then
					icon.statusBar:SetColors()
				end
			end
		end
	end
end

registeredEvents["SPELL_AURA_APPLIED"][25771] = function(_,_,_, destGUID)
	if not E.db.icons.showForbearanceCounter then
		return
	end
	local destInfo = groupInfo[destGUID]
	if destInfo then
		for id in pairs(forbearanceIDs) do
			if id ~= 642 or not destInfo.talentData[146956] then
				local icon = destInfo.spellIcons[id]
				if icon then
					destInfo.preactiveIcons[id] = icon
					icon:SetColorSaturation()
					if icon.statusBar then
						icon.statusBar:SetColors()
					end
				end
			end
		end
	end
end

-- Nature's Guardian (Shaman)
registeredEvents["SPELL_HEAL"][31616] = function(info)
	local icon = info.spellIcons[30884]
	if icon then
		icon:StartCooldown()
	end
end

-- Reincarnation (Shaman)
registeredEvents["SPELL_CAST_SUCCESS"][21169] = function(info)
	local icon = info.spellIcons[20608]
	if icon then
		icon:StartCooldown()
	end
end

-- Interrupt Extras
local playerInterrupts = {
	[1766] = true, -- Kick
	[6552] = true, -- Pummel
	[19244] = true, -- Spell Lock
	[57994] = true, -- Wind Shear
	[47528] = true, -- Mind Freeze
	[2139] = true, -- Counterspell
	[34490] = true, -- Silencing Shot
	[47476] = true, -- Strangulate
	[15487] = true, -- Silence
	[16979] = true, -- Feral Charge - Bear
	[31935] = true, -- Avenger's Shield
	[8042] = true, -- Earth Shock
}

local function AppendInterruptExtras(info, spellID, extraSpellId)
	local icon = info.spellIcons[E.spellcast_merged[spellID] or spellID]
	local statusBar = icon and icon.type == "interrupt" and icon.statusBar
	if statusBar then
		local frame = icon:GetParent():GetParent()
		if frame.index == 1 then
			if frame.db.showInterruptedSpell then
				local extraSpellTexture = C_Spell.GetSpellTexture(extraSpellId)
				if extraSpellTexture then
					icon.icon:SetTexture(extraSpellTexture)
					icon.tooltipID = extraSpellId
					if not E.db.icons.showTooltip and icon.isPassThrough then
						icon:EnableMouse(true)
					end
				end
			end
		end
	end
end

-- Healthstones
local spell_healthstone = {
-- WotLK
	[47875] = true,
	[47876] = true,
	[47877] = true,
}

local function StartHealthstone(info, srcGUID, spellID)
	local icon = info.spellIcons[spellID] or info:AddOnCast(spellID, 5509)
	if icon then
		icon:StartCooldown()
	end
end

--[[

	WOTLK ONLY

]]
if E.isWOTLKC then

	-- Hex (Shaman)(Warmane: SPELL_CAST_SUCCESS Missing)
	registeredEvents["SPELL_AURA_APPLIED"][51514] = function(info, _, spellID)
		local icon = info.spellIcons[spellID]
		if icon then
			icon:StartCooldown()
		end
	end
	registeredEvents["SPELL_MISSED"][51514] = registeredEvents["SPELL_AURA_APPLIED"][51514]

	-- Guardian Spirit (Priest)
	local onGSRemoval = function(srcGUID, spellID, destGUID)
		local info = groupInfo[srcGUID]
		if info then
			if info.auras.wasSavedByGS then
				info.auras.wasSavedByGS = nil
			else
				local icon = info.spellIcons[47788]
				if icon and info.talentData[63231] then
					icon:StartCooldown(60)
				end
			end
			RemoveHighlightByCLEU(info, srcGUID, spellID, destGUID)
		end
	end

	registeredEvents["SPELL_AURA_REMOVED"][47788] = function(info, srcGUID, spellID, destGUID)
		local icon = info.spellIcons[47788]
		if icon then
			C_Timer_After(0.1, function() onGSRemoval(srcGUID, spellID, destGUID) end)
		end
	end

	registeredEvents["SPELL_HEAL"][48153] = function(info)
		if info.spellIcons[47788] then
			info.auras.wasSavedByGS = true
		end
	end
else
--[[

	TBC/CLASSIC ONLY

]]

	-- Bloodlust
	registeredEvents["SPELL_AURA_APPLIED"][2825] = function(_,_,_, destGUID)
		local destInfo = groupInfo[destGUID]
		if destInfo then
			destInfo.auras.mult_lust = true
			for id in pairs(E.spell_cdmod_by_haste) do
				local icon = destInfo.spellIcons[id]
				if icon and icon.active then
					icon:UpdateCooldown(0, 0.7)
				end
			end
		end
	end

	registeredEvents["SPELL_AURA_REMOVED"][2825] = function(info, srcGUID, spellID, destGUID)
		local destInfo = groupInfo[destGUID]
		if destInfo then
			destInfo.auras.mult_lust = nil
			for id in pairs(E.spell_cdmod_by_haste) do
				local icon = destInfo.spellIcons[id]
				if icon and icon.active then
					icon:UpdateCooldown(0, 1/0.7)
				end
			end
		end
		RemoveHighlightByCLEU(info, srcGUID, spellID, destGUID)
	end

	registeredEvents["SPELL_AURA_APPLIED"][32182] = registeredEvents["SPELL_AURA_APPLIED"][2825]
	registeredEvents["SPELL_AURA_REMOVED"][32182] = registeredEvents["SPELL_AURA_REMOVED"][2825]
end

setmetatable(registeredEvents, nil)

local function UpdateDeadStatus(destInfo)
	if UnitHealth(destInfo.unit) > 1 then
		return
	end
	destInfo.isDead = true
	destInfo.isDeadOrOffline = true
	destInfo:UpdateColorScheme()
end

function CD:COMBAT_LOG_EVENT_UNFILTERED(...)
	local _, event, _, srcGUID, _, srcFlags, _, destGUID, _, _, _, spellID, _, _, extraSpellId = CombatLogGetCurrentEventInfo(...)

	srcGUID = minionGUIDS[srcGUID] or srcGUID

	local info = groupInfo[srcGUID]
	if info then
		local func = registeredEvents[event] and registeredEvents[event][spellID]
		if func then
			func(info, srcGUID, spellID, destGUID)
			return
		end

		if event == "SPELL_CAST_SUCCESS" then
			if spell_healthstone[spellID] then
				StartHealthstone(info, srcGUID, spellID)
			elseif E.spellcast_all[spellID] then
				info:ProcessSpell(spellID)
			end
		elseif event == "SPELL_AURA_APPLIED" then
			if E.spell_auraapplied_processspell[spellID] then
				info:ProcessSpell(spellID)
			end

			if E.spellcast_all[spellID] then
				info:ProcessAura(spellID)
			end
		elseif event == "SPELL_AURA_REMOVED" then
			local cdstart_preactive = E.spell_auraremoved_cdstart_preactive[spellID]
			if cdstart_preactive and cdstart_preactive > 0 then
				StartCdOnAuraRemoved(info, srcGUID, spellID, destGUID)
			elseif E.spell_highlighted[spellID] then
				RemoveHighlightByCLEU(info, srcGUID, spellID, destGUID)
			end
		elseif event == "SPELL_INTERRUPT" and playerInterrupts[spellID] then
			AppendInterruptExtras(info, spellID, extraSpellId)
		end

		return
	end

	if band(srcFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY) == 0 then
		local destInfo = groupInfo[destGUID]
		if destInfo and event == "UNIT_DIED" then
			UpdateDeadStatus(destInfo)
		end
	end
end

function CD:UNIT_PET(unit)
	local unitPet = E.UNIT_TO_PET[unit]
	if not unitPet then
		return
	end

	local guid = UnitGUID(unit)
	local info = groupInfo[guid]
	if info and (info.class == "WARLOCK" or info.class == "HUNTER" or (info.class == "DEATHKNIGHT" and info.talentData[52143])) then
		local petGUID = info.petGUID
		if petGUID then
			minionGUIDS[petGUID] = nil
		end
		petGUID = UnitGUID(unitPet)
		if petGUID then
			minionGUIDS[petGUID] = guid
		end
		info.petGUID = petGUID
	end
end

E.forbearanceIDs = forbearanceIDs
CD.minionGUIDS = minionGUIDS
