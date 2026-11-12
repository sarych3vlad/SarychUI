-- Native Party Abilities extension. Other players' cooldowns are estimates from observed casts.
local SUI = SarychUI
local Glow = SUI.PlatesAurasGlow
local BAGS_ATLAS = "Interface\\AddOns\\SarychUI\\media\\cooldowns\\omnibar\\Bags"
local BLUE_GLOW_COORDS = { 0.542969, 0.695312, 0.164062, 0.316406 }
local FLASH_COORDS = { 0.00390625, 0.355469, 0.00390625, 0.355469 }
local extension = SUI:RegisterExtension("party_abilities", {})
local eventFrame = CreateFrame("Frame")
local units, active, icons = {}, {}, {}
local arenaAppearanceByFrame = setmetatable({}, { __mode = "k" })
local arenaLastSeen = {}
local arenaPetOwners = {}
local arenaDeadGUID = {}
local learnedDurations, talentRetry = {}, {}
local enemyWitnessed = {}
local enemySpecHints = {}
local liveAuras = {}
local detachedEnemies = {}
local function Detached()
    local db = SUI.db and SUI.db.profile.modules.party_abilities
    return db and db.enemyMode == "standalone"
end
local enabled, elapsed = false, 0
local trackingEvents = false
local lastDB
local talentLib = LibStub and LibStub("LibGroupTalents-1.0", true)
local specFramework = SUI.UnitSpecialization
local cooldownCommPrefix = "SUI_PACD"
local AbilityData = SUI.Data.PartyAbilities
local EnemyData = SUI.Data.EnemyAbilities
local resetters = AbilityData.resetters
local shared = AbilityData.shared
local linkedUse = AbilityData.linkedUse

local function DB()
	return SUI.db and SUI.db.profile and SUI.db.profile.modules and SUI.db.profile.modules.party_abilities
end

local function ApplyItemMeta(data, id)
	local meta = AbilityData.items and AbilityData.items[id]
	if not data or not meta then return end
	data.item = meta.item
	data.trinket = meta.trinket and true or nil
	data.itemName = meta.name
	data.icon = meta.icon or data.icon
	if meta.item then GetItemInfo(meta.item) end
end

local function SpellRecord(class, index, entry)
	local tab, talentIndex = entry[3], entry[4]
	local data = {
		class = class, cooldown = entry[2],
		talent = tab and true or nil, talentTab = tab, talentIndex = talentIndex,
		faction = entry[5], race = entry[6], excludeRace = entry[7], icon = entry[8],
		order = index * 10, enabled = true, glowWhen = "cooldown",
	}
	ApplyItemMeta(data, entry[1])
	return data
end

local function ApplyGlowDefaults(db)
	if db.glowDefaultsVersion == 1 then return end
	for id, defaults in pairs(AbilityData.glowDefaults or {}) do
		local data = db.spells[id]
		if data then
			if data.highlight == nil then
				for key, value in pairs(defaults) do
					-- Each profile owns its color; never share the defaults table.
					if type(value) == "table" then
						data[key] = { unpack(value) }
					else data[key] = value end
				end
			elseif data.glowWhen == "ready" then
				-- Convert the reference setup once, preserving other custom glows.
				local matches = true
				for _, key in ipairs({ "highlight", "glowType", "useGlowColor", "highlightColor",
					"glowLines", "glowFrequency", "glowDuration", "glowLength", "glowThickness",
					"glowXOffset", "glowYOffset", "glowScale", "glowBorder" }) do
					local saved, value = data[key], defaults[key]
					if type(value) == "table" and type(saved) == "table" then
						for i = 1, 4 do if saved[i] ~= value[i] then matches = false end end
					elseif saved ~= value then matches = false end
				end
				if matches then data.glowWhen = "active" end
			end
		end
	end
	db.glowDefaultsVersion = 1
end

local function Seed(db)
	if not db then return end
	db.spells = db.spells or {}
	for _, id in ipairs({ 308726, 310773, 310787, 316161, 316465, 90101, 90105, 90108, 90110, 90112, 90113, 90115 }) do
		db.spells[id] = nil
	end
	local refreshList = (db.spellListVersion or 0) < 3
	for class, list in pairs(AbilityData.presets) do
		local fill = refreshList or not db.seeded or (class == "OTHER" and not db.otherSeeded)
		if fill then
			for index, entry in ipairs(list) do
				local id = entry[1]
				local data = db.spells[id]
				if not data then
					db.spells[id] = SpellRecord(class, index, entry)
				else
					data.class = class
					if entry[3] then
						data.talent, data.talentTab, data.talentIndex = true, entry[3], entry[4]
					end
					if class == "OTHER" then
						data.race, data.excludeRace, data.icon = entry[6], entry[7], entry[8] or data.icon
					end
					ApplyItemMeta(data, id)
				end
			end
		end
	end
	if refreshList then
		for id, data in pairs(db.spells) do ApplyItemMeta(data, id) end
	end
	db.seeded = true
	db.otherSeeded = true
	db.spellListVersion = 3
    -- Roll back the experimental imported catalog, including saved seeded entries.
    -- Keep a recoverable copy because users may have edited imported records.
    if not db.importedCatalogRolledBack then
        for id, data in pairs(db.spells) do
            if data.enemyOnly then
                db.importedCatalogBackup = db.importedCatalogBackup or {}
                db.importedCatalogBackup[id] = data
                db.spells[id] = nil
            end
        end
        db.importedCatalogRolledBack = true
    end

	-- Older custom entries received an arbitrary 60-second default. Repair the
	-- reported Life Tap spell/effect once; preserve other explicit durations.
	if not db.lifeTapCooldownFixed then
		for _, id in ipairs({ 63321, 57946 }) do
			local data = db.spells[id]
			if data and tonumber(data.cooldown) == 60 then data.cooldown = 0 end
		end
		db.lifeTapCooldownFixed = true
	end

	ApplyGlowDefaults(db)
end

function extension:ResetSpellDefaults()
	local db = DB()
	if not db then return end
	local previous = db.spells or {}
	local baseline = { spells = {} }
	Seed(baseline)
	for id, data in pairs(baseline.spells) do
		local saved = previous[id]
		if saved then
			for _, key in ipairs({ "cooldown", "order", "enabled", "size", "highlight",
				"glowType", "glowWhen", "highlightColor", "useGlowColor", "glowLines", "glowFrequency", "glowDuration",
				"glowLength", "glowThickness", "glowXOffset", "glowYOffset", "glowScale", "glowBorder" }) do
				if saved[key] ~= nil then data[key] = saved[key] end
			end
		end
	end
	db.spells = baseline.spells
	db.seeded, db.otherSeeded, db.spellListVersion = true, true, 3
	active = {}
end

function extension:GetDB()
	local db = DB()

	Seed(db)
	if db and not db.displayMigrated then
		db.contexts = db.contexts or {}
		local old = db.content
		if old == "arena" or old == "party" or old == "raid" then
			for _, key in ipairs({ "arena", "group", "raid" }) do db.contexts[key] = false end
			db.contexts[old == "party" and "group" or old] = true
		elseif old == "cooldown" then
			db.displayMode = "cooldown"
		end
		for _, data in pairs(db.spells) do
			if data.show == "combat" or data.show == "outOfCombat" then data.show = "always" end
		end
		db.content = nil
		db.displayMigrated = true
	end
	if db and not db.worldRemoved then
		db.contexts = db.contexts or {}
		if db.contexts.world and db.contexts.arena == false
			and db.contexts.group == false and db.contexts.raid == false then
			db.contexts.group, db.contexts.raid = true, true
		end
		db.contexts.world = nil
		for _, data in pairs(db.spells) do
			if data.show == "world" then data.show = "always" end
		end
		db.worldRemoved = true
	end
	if db and not db.scaleRemoved then
		for _, layout in pairs(db.layouts or {}) do
			local scale = tonumber(layout.scale) or 1
			if scale ~= 1 then
				layout.size = math.floor((tonumber(layout.size) or 24) * scale + 0.5)
				layout.spacing = math.floor((tonumber(layout.spacing) or 2) * scale + 0.5)
				layout.x = math.floor((tonumber(layout.x) or 0) * scale + 0.5)
				layout.y = math.floor((tonumber(layout.y) or 0) * scale + 0.5)
			end
			layout.scale = nil
		end
		db.scaleRemoved = true
	end
	if db and not db.spellShowRemoved then
		for _, data in pairs(db.spells) do data.show = nil end
		db.spellShowRemoved = true
	end
	return db
end

function extension:GetLayoutKind()
	local wrapper = SUI.modules and SUI.modules.group_frames
	local available = wrapper and wrapper.IsRuntimeEnabled and wrapper:IsRuntimeEnabled()
	if available == nil then available = CompactRaidFrameEnabled ~= false and CUF_CVar ~= nil end
	if not available then return "blizzard" end
	if (GetNumRaidMembers and GetNumRaidMembers() or 0) > 0 then return "compact" end
	if CUF_CVar and CUF_CVar.GetCVarBool and CUF_CVar:GetCVarBool("useCompactPartyFrames") then
		return "compact"
	end
	return "blizzard"
end

local function IsInGroup()
	return (GetNumRaidMembers and GetNumRaidMembers() or 0) > 0
		or (GetNumPartyMembers and GetNumPartyMembers() or 0) > 0
end

local function ContentMode()
	local _, kind = IsInInstance()
	return kind or "none"
end

local function EnemySettings()
    if Detached() then return { displayMode = "cooldown", layout = {} } end
	local arena = SUI.modules and SUI.modules.arena
	local modules = SUI.db and SUI.db.profile and SUI.db.profile.modules
	local db = modules and modules.arena
	if not db or db.enabled == false then return end
	return arena and arena.GetEnemyAbilitySettings and arena:GetEnemyAbilitySettings()
end

local function EnemySelected(db)
	if not db then return false end
	if db.frameType == "gladius" then
		local arenaModule = SUI.modules and SUI.modules.arena
		return arenaModule and arenaModule.GetGladiusRightContent
			and arenaModule:GetGladiusRightContent() == "enemyAbilities"
	end
	local arenaModule = SUI.modules and SUI.modules.arena
	return arenaModule and arenaModule.GetClassicRightContent
		and arenaModule:GetClassicRightContent() == "enemyAbilities"
end

local function EnemyAllowed()
    if Detached() then return true end
	local settings = EnemySettings()
	local arena = SUI.db and SUI.db.profile and SUI.db.profile.modules and SUI.db.profile.modules.arena
	return settings and EnemySelected(arena)
		and (ContentMode() == "arena" or (arena.testMode or 0) > 0)
end

local function ContextFlags()
	local kind = ContentMode()
	local raid = (GetNumRaidMembers and GetNumRaidMembers() or 0) > 0
	local party = (GetNumPartyMembers and GetNumPartyMembers() or 0) > 0
	if kind == "arena" then return { arena = true } end
	return {
		raid = kind == "raid" or raid,
		group = kind == "party" or (party and not raid),
	}
end

local function GroupPreview()
    local group = SUI.modules and SUI.modules.group_frames
    local db = DB()
    return group and group.testCount and group.GetCooldownPreviewFrames
        and group:GetCooldownPreviewFrames(db and db.contexts or {})
end

local function Allowed(db)
    local preview = GroupPreview()
    if preview then return next(preview) ~= nil end
	if not IsInGroup() then return false end
	local flags = ContextFlags()
	local contexts = db.contexts or {}
	for key in pairs(flags) do
		if flags[key] and contexts[key] ~= false then return true end
	end
	return false
end

local function AddUnit(token, enemy)
	if not UnitExists(token) then return end
	local guid = UnitGUID(token)
	local _, class = UnitClass(token)
	local _, race = UnitRace(token)
	if guid and class then units[guid] = { token = token, class = class, race = race, enemy = enemy } end
end

local function Roster()
	local old = units
	units = {}
	wipe(arenaPetOwners)
	if (GetNumRaidMembers and GetNumRaidMembers() or 0) > 0 then
		for i = 1, GetNumRaidMembers() do AddUnit("raid" .. i) end
	elseif IsInGroup() then
		AddUnit("player")
		for i = 1, 4 do AddUnit("party" .. i) end
	end
    for guid, sample in pairs(GroupPreview() or {}) do
        units[guid] = sample
    end
	if EnemyAllowed() then
		for i = 1, 5 do
			local token = "arena" .. i
			local guid = UnitGUID(token)
			local _, class = UnitClass(token)
			local _, race = UnitRace(token)
			if guid and class then
				arenaLastSeen[i] = { guid = guid, class = class, race = race }
			end
			local known = arenaLastSeen[i]
			if known then
				units[known.guid] = { token = token, class = known.class,
					race = known.race, enemy = true }
				local petGUID = UnitGUID("arenapet" .. i)
				if petGUID then arenaPetOwners[petGUID] = known.guid end
			end
		end
		local arenaModule = SUI.modules and SUI.modules.arena
		if arenaModule and arenaModule.GetVisibleTestFrame then
			for i = 1, 5 do
				if arenaModule:GetVisibleTestFrame(i) then
					local class = arenaModule.GetTestArenaClass and arenaModule:GetTestArenaClass(i)
					if class then
						units["sui:arena-test:" .. i] = { token = "arena" .. i, class = class,
							race = i <= 2 and "Human" or "Orc", enemy = true, test = true }
					end
				end
			end
		end
	else
		wipe(arenaLastSeen)
		wipe(arenaDeadGUID)
		wipe(enemyWitnessed)
		wipe(enemySpecHints)
	end
    if Detached() then
        for guid, member in pairs(detachedEnemies) do
            if GetTime() - (member.seen or 0) < 1800 then units[guid] = units[guid] or member
            else detachedEnemies[guid] = nil end
        end
    end
	-- Unit tokens can briefly disappear during combat/zone transitions. Keep
	-- cooldowns by GUID until they expire, even if the roster is momentarily empty.
	local now = GetTime()
	for guid, spells in pairs(active) do
		if not units[guid] then
			if type(guid) == "string" and guid:match("^sui:arena%-test:") then
				active[guid] = nil
			else
				for id, state in pairs(spells) do
					if not state.start or not state.duration or state.start + state.duration <= now then
						spells[id] = nil
					end
				end
				if not next(spells) then active[guid] = nil end
			end
		end
	end
	for guid in pairs(learnedDurations) do if not units[guid] then learnedDurations[guid] = nil end end
	for guid in pairs(talentRetry) do if not units[guid] then talentRetry[guid] = nil end end
	-- Queue inspection as soon as the party is known, before anyone casts.
	if specFramework then
		local now = GetTime()
		for guid, member in pairs(units) do
			if not member.enemy and not member.test and guid ~= UnitGUID("player") and (talentRetry[guid] or 0) <= now then
				if specFramework:RequestAllyTalents(guid) then
					talentRetry[guid] = nil
				else
					talentRetry[guid] = now + 1
				end
			end
		end
	end
	for guid in pairs(old) do if not units[guid] then
		for key, icon in pairs(icons) do if icon.guid == guid then icon:Hide(); Glow.Stop(icon) end end
	end end
end

local function FrameMap()
	local map = {}
    for guid, sample in pairs(GroupPreview() or {}) do
        map[guid] = { sample.frame, sample.kind }
    end
	if EnemyAllowed() and not Detached() then
		local arenaModule = SUI.modules and SUI.modules.arena
		for i = 1, 5 do
			local testFrame = arenaModule and arenaModule.GetVisibleTestFrame and arenaModule:GetVisibleTestFrame(i)
			if testFrame then map["sui:arena-test:" .. i] = { testFrame, "arena" } end
			local frame = _G["ArenaEnemyFrame" .. i]
			local guid = UnitGUID("arena" .. i) or (arenaLastSeen[i] and arenaLastSeen[i].guid)
			if frame and frame:IsVisible() and guid and units[guid] then
				map[guid] = { frame, "arena" }
			end
		end
	end
	-- Compact frames take priority when both layouts exist.
	for i = 1, 40 do
		local frame = _G["CompactRaidFrame" .. i]
		if frame and frame:IsVisible() and frame.unit then
			local guid = UnitGUID(frame.unit)
			if guid and units[guid] and not map[guid] then map[guid] = { frame, "compact" } end
		end
	end
	for group = 1, 8 do
		for member = 1, 5 do
			local frame = _G["CompactRaidGroup" .. group .. "Member" .. member]
			if frame and frame:IsVisible() and frame.unit then
				local guid = UnitGUID(frame.unit)
				if guid and units[guid] and not map[guid] then map[guid] = { frame, "compact" } end
			end
		end
	end
	for i = 1, 5 do
		local frame = _G["CompactPartyFrameMember" .. i]
		if frame and frame:IsVisible() and frame.unit then
			local guid = UnitGUID(frame.unit)
			if guid and units[guid] and not map[guid] then map[guid] = { frame, "compact" } end
		end
	end
	for i = 1, 4 do
		local frame = _G["PartyMemberFrame" .. i]
		local guid = UnitGUID("party" .. i)
		if frame and frame:IsVisible() and guid and units[guid] and not map[guid] then
			map[guid] = { frame, "blizzard" }
		end
	end
	return map
end

function extension:PrepareIcon(icon)
	if not icon or icon._paChrome then return end
	icon._paChrome = true
	local border = icon:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	border:SetBlendMode("ADD")
	border:SetAlpha(0)
	border:Hide()
	border:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	border:SetPoint("CENTER", icon.texture or icon, "CENTER", 0.4, 0.5)
	icon.border = border
	icon.UpdateBorderSize = function()
		local width, height = icon:GetWidth(), icon:GetHeight()
		if not width or width < 1 then return end
		border:SetSize(width * 1.67, (height and height > 1 and height or width) * 1.67)
	end
	if Glow and Glow.Install then Glow.Install(icon) end
end

local function InstallOmniBarAppear(icon)
	if icon.omniAppearGlow then return end
	local glow = icon:CreateTexture(nil, "OVERLAY", nil, 1)
	glow:SetTexture(BAGS_ATLAS)
	glow:SetTexCoord(unpack(BLUE_GLOW_COORDS))
	glow:SetBlendMode("ADD")
	glow:SetPoint("CENTER", icon, "CENTER")
	glow:SetAlpha(0)
	local glowAnim = glow:CreateAnimationGroup()
	for order, step in ipairs({ {0, 1, "NONE"}, {1, -0.4, "NONE"},
		{1, 1, "NONE"}, {1, -1, "NONE"} }) do
		local alpha = glowAnim:CreateAnimation("Alpha")
		alpha:SetOrder(order)
		alpha:SetDuration(step[1])
		alpha:SetChange(step[2])
		alpha:SetSmoothing(step[3])
	end
	local flash = icon:CreateTexture(nil, "OVERLAY", nil, 2)
	flash:SetTexture(BAGS_ATLAS)
	flash:SetTexCoord(unpack(FLASH_COORDS))
	flash:SetBlendMode("ADD")
	flash:SetPoint("CENTER", icon, "CENTER")
	flash:SetAlpha(0)
	local flashAnim = flash:CreateAnimationGroup()
	for order, step in ipairs({ {0, 1, "NONE"}, {1, -1, "OUT"} }) do
		local alpha = flashAnim:CreateAnimation("Alpha")
		alpha:SetOrder(order)
		alpha:SetDuration(step[1])
		alpha:SetChange(step[2])
		alpha:SetSmoothing(step[3])
	end
	icon.omniAppearGlow, icon.omniAppearFlash = glow, flash
	icon.omniAppearGlowAnim, icon.omniAppearFlashAnim = glowAnim, flashAnim
end

local function PlayOmniBarAppear(icon)
	InstallOmniBarAppear(icon)
	local width, height = icon:GetWidth(), icon:GetHeight()
	icon.omniAppearGlow:SetSize(width * 39 / 36, height * 39 / 36)
	icon.omniAppearFlash:SetSize(width * 90 / 36, height * 90 / 36)
	icon.omniAppearGlowAnim:Stop()
	icon.omniAppearFlashAnim:Stop()
	icon.omniAppearGlow:SetAlpha(0)
	icon.omniAppearFlash:SetAlpha(0)
	icon.omniAppearGlowAnim:Play()
	icon.omniAppearFlashAnim:Play()
end

local function NewIcon(key, guid)
	local icon = CreateFrame("Frame", nil, UIParent)
	icon.guid = guid
	icon.texture = icon:CreateTexture(nil, "ARTWORK")
	icon.texture:SetAllPoints(icon)
	icon.texture:SetTexCoord(0, 1, 0, 1)
	icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
	icon.cooldown:SetAllPoints(icon)
	icon.cooldown:SetAlpha(0.65)
	icon.cooldown.__sary_partyAbility = true
	icon.pendingText = icon:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	icon.pendingText:SetPoint("CENTER")
	icon.pendingText:SetText("…")
	icon.pendingText:Hide()
	extension:PrepareIcon(icon)
	icon:SetScript("OnHide", function(self)
		self._procIntroPlayed = nil
		if self.omniAppearGlowAnim then self.omniAppearGlowAnim:Stop() end
		if self.omniAppearFlashAnim then self.omniAppearFlashAnim:Stop() end
		if self.omniAppearGlow then self.omniAppearGlow:SetAlpha(0) end
		if self.omniAppearFlash then self.omniAppearFlash:SetAlpha(0) end
	end)
	icon:SetScript("OnUpdate", function(self)
		if not self._cooldownEnd or GetTime() < self._cooldownEnd then return end
		self._cooldownEnd = nil
		self.texture:SetDesaturated(false)
		self.texture:SetVertexColor(1, 1, 1)
		extension:SetIconTimer(self, nil)
		self.cooldown:Hide()
	end)
	icon:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		local data = self.spellData
		if data and data.item then
			GameTooltip:SetHyperlink("item:" .. data.item)
		else
			GameTooltip:SetHyperlink("spell:" .. self.spellID)
		end
		GameTooltip:Show()
	end)
	icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
	icon:Hide()
	if key then icons[key] = icon end
	return icon
end

function extension:CreateStandaloneIcon()
    return NewIcon(nil, nil)
end
function extension:AnimateStandaloneIcon(icon) PlayOmniBarAppear(icon) end

local function MatchSpell(spellID, spellName, class, db)
	local direct = db.spells[spellID]
	if direct and (direct.class == class or direct.class == "OTHER") then return spellID, direct end
	if not spellName then return end
	for id, data in pairs(db.spells) do
		if (data.class == class or data.class == "OTHER") and GetSpellInfo(id) == spellName then return id, data end
	end
end

local presetCooldowns = {}
for _, list in pairs(AbilityData.presets or {}) do
	for _, entry in ipairs(list) do presetCooldowns[entry[1]] = entry[2] end
end

local enemySpells, enemySpellsDB
local function EnemySpells(db)
	if enemySpellsDB == db and enemySpells then return enemySpells end
	enemySpells, enemySpellsDB = {}, db
	for id, record in pairs(EnemyData.Catalog) do
		local savedID = db.spells[id] and id or (id == 20066 and db.spells[66008] and 66008)
			or record.presetID
		local saved = savedID and db.spells[savedID]
		local custom = saved and tonumber(saved.cooldown)
			and tonumber(saved.cooldown) ~= (presetCooldowns[savedID] or record.base)
		local data = {
			class = record.class, cooldown = custom and tonumber(saved.cooldown) or record.base,
			order = saved and saved.order or record.order, enabled = not saved or saved.enabled ~= false,
			race = record.race, excludeRace = record.excludeRace, racial = record.racial,
			icon = record.icon,
			glowWhen = saved and saved.glowWhen or "cooldown",
			_enemyRecord = record, _customCooldown = custom and true or nil,
		}
		for _, key in ipairs({ "size", "highlight", "glowType", "highlightColor", "useGlowColor",
			"glowLines", "glowFrequency", "glowDuration", "glowLength", "glowThickness", "glowXOffset",
			"glowYOffset", "glowScale", "glowBorder" }) do
			if saved and saved[key] ~= nil then data[key] = saved[key] end
		end
		enemySpells[id] = data
	end
    for id, saved in pairs(db.spells or {}) do
        local canonical = EnemyData.Aliases[id] or id
        if not enemySpells[canonical] and not EnemyData.Catalog[canonical] then
            local copy = {}
            for key, value in pairs(saved) do copy[key] = value end
            enemySpells[canonical] = copy
        end
    end
	return enemySpells
end

local function EnemyMatchSpell(spellID, spellName, class, db)
	local id = EnemyData.Aliases[spellID] or spellID
	local record = EnemySpells(db)[id]
	if record and (record.class == class or record.class == "OTHER") then
		return id, record
	end
	if not spellName then return end
	for candidate, info in pairs(EnemySpells(db)) do
		if (info.class == class or info.class == "OTHER") and GetSpellInfo(candidate) == spellName then
			return candidate, EnemySpells(db)[candidate]
		end
	end
end

local function EnemyDuration(data, member)
	if data._customCooldown then return data.cooldown end
	local record = data._enemyRecord
	if not record or not record.bySpec then return data.cooldown end
	local spec = member and member.spec
	if spec then return record.bySpec[spec] or record.base end
	return record.fallback or record.base
end

local function EnemySpec(member, guid)
	if member.test then
		local index = tonumber(member.token and member.token:match("^arena(%d+)$"))
		return index and specFramework and specFramework:GetTestArenaSpec(index)
	end
	local current = specFramework and specFramework.GetEnemySpecByGUID
		and specFramework:GetEnemySpecByGUID(guid)
	if current then return current end
	local api = _G.ArenaNotesAPI
	local hint = member.token and api and api.ready and api.GetSpec and api:GetSpec(member.token)
	if type(hint) ~= "table" or (hint.guid and hint.guid ~= guid)
		or (hint.classToken and hint.classToken ~= member.class) then return enemySpecHints[guid] end
	local spec = hint.specKey
	if type(spec) ~= "string" then return enemySpecHints[guid] end
	spec = spec:gsub("^" .. member.class .. "_", "")
	if member.class == "PALADIN" and spec:upper() == "PREG" then
		enemySpecHints[guid] = "Preg"
		return "Preg"
	end
	local order = EnemyData.SpecOrder[member.class]
	for _, name in ipairs(order or {}) do
		if name == spec or name:upper() == spec:upper() then
			enemySpecHints[guid] = name
			return name
		end
	end
	return enemySpecHints[guid]
end

local function CooldownDuration(guid, id, data)
	local configured = tonumber(data and data.cooldown) or 0
	local rule = AbilityData.cooldownRules and AbilityData.cooldownRules[id]
	if not rule or configured ~= presetCooldowns[id] then return configured end
	-- Keep ATT's preset estimate until the relevant inspect data arrives.
	if rule.talents and not (talentLib and talentLib.GetGUIDTalents and talentLib:GetGUIDTalents(guid)) then
		return configured
	end
	-- Inspect exposes teammates' talents, but their glyphs are only available
	-- when they also sync LibGroupTalents. Missing glyphs must not hide talents.
	local glyphsKnown = not rule.glyphs or (talentLib and talentLib.GetGUIDGlyphs and talentLib:GetGUIDGlyphs(guid))
		or (UnitGUID and guid == UnitGUID("player"))
	if rule.glyphs and not glyphsKnown and not rule.talents then return configured end
	local duration = glyphsKnown and rule.base or (rule.unknownGlyphBase or configured)
	for _, modifier in ipairs(rule.talents or {}) do
		local talentName = GetSpellInfo(modifier[1])
		local rank = talentLib and talentLib.GUIDHasTalent and talentName
			and tonumber(talentLib:GUIDHasTalent(guid, talentName)) or 0
		if modifier.percents then
			duration = duration * (1 + (modifier.percents[math.min(rank, #modifier.percents - 1) + 1] or 0))
		else
			if modifier.percent then duration = duration * (1 + modifier.percent * rank) end
			if modifier.seconds then duration = duration + modifier.seconds * rank end
		end
	end
	for _, modifier in ipairs(glyphsKnown and rule.glyphs or {}) do
		if talentLib and talentLib.GUIDHasGlyph then
			for _, glyphID in ipairs(modifier.ids) do
				if talentLib:GUIDHasGlyph(guid, glyphID) then
					if modifier.percent then duration = duration * (1 + modifier.percent) end
					if modifier.seconds then duration = duration + modifier.seconds end
					break
				end
			end
		end
	end
	return math.max(0.5, duration)
end

local function ModifierDataKnown(guid, id, data)
	local rule = AbilityData.cooldownRules and AbilityData.cooldownRules[id]
	if not rule or tonumber(data.cooldown) ~= presetCooldowns[id] then return true end
	if rule.talents and not (talentLib and talentLib.GetGUIDTalents and talentLib:GetGUIDTalents(guid)) then return false end
	if rule.glyphs and not (talentLib and talentLib.GetGUIDGlyphs and talentLib:GetGUIDGlyphs(guid))
		and guid ~= UnitGUID("player") then return false end
	return true
end

function extension:RefreshActiveDurations(guid)
	local db = self:GetDB()
	if not db or not db.spells then return end
	for memberGUID, spells in pairs(active) do
		if not guid or memberGUID == guid then
			local member = units[memberGUID]
			if member and member.enemy then member.spec = EnemySpec(member, memberGUID) end
			for id, state in pairs(spells) do
				local data = member and member.enemy and EnemySpells(db)[id] or db.spells[id]
				if data and not state.shared and not state.native then
					state.duration = member and member.enemy and EnemyDuration(data, member)
						or CooldownDuration(memberGUID, id, data)
					if state.pendingUntil and ModifierDataKnown(memberGUID, id, data) then state.pendingUntil = nil end
				end
			end
		end
	end
end

local function SyncPlayerCooldown(guid, id, data, state, now)
	if not state or state.shared or not GetSpellCooldown or not UnitGUID
		or guid ~= UnitGUID("player") or tonumber(data.cooldown) ~= presetCooldowns[id] then return end
	local start, duration = GetSpellCooldown(id)
	if not start or not duration or start <= 0 or duration <= 2 then
		local spellName = GetSpellInfo(id)
		if spellName then start, duration = GetSpellCooldown(spellName) end
	end
	-- Ignore the global cooldown and a previous cast's timer. The game's own
	-- active cooldown includes talents, glyphs, gear and other local modifiers.
	if start and duration and start > 0 and duration > 2
		and start + duration > now and start >= state.start - 3 then
		state.start, state.duration, state.native, state.playerNative = start, duration, true, true
		if SendAddonMessage and (state.sentDuration ~= duration or state.sentStart ~= start) then
			local channel = (GetNumRaidMembers and GetNumRaidMembers() or 0) > 0 and "RAID" or "PARTY"
			SendAddonMessage(cooldownCommPrefix,
				"C|" .. guid .. "|" .. id .. "|" .. duration .. "|" .. math.max(0, now - start), channel)
			state.sentDuration, state.sentStart = duration, start
		end
	elseif state.playerNative and duration == 0 and now > state.start + 0.5 then
		-- A confirmed native cooldown was reset. Do not keep its old estimate.
		state.duration = 0
	end
end

local function SyncOwnCooldowns(now)
	local guid = UnitGUID and UnitGUID("player")
	local db = DB()
	local spells = guid and active[guid]
	if not spells or not db or not db.spells then return end
	for id, state in pairs(spells) do
		local data = db.spells[id]
		if data then SyncPlayerCooldown(guid, id, data, state, now) end
	end
end

local function ReceiveCooldown(prefix, message, sender)
	if prefix ~= cooldownCommPrefix or type(message) ~= "string" or type(sender) ~= "string" then return end
	local guid, idText, durationText, ageText = message:match("^C|([^|]+)|(%d+)|([%d%.]+)|([%d%.]+)$")
	local id, duration, age = tonumber(idText), tonumber(durationText), tonumber(ageText)
	local member = guid and units[guid]
	if not member or member.enemy or member.test or not id or not duration or not age
		or duration <= 2 or duration > 3600 or age < 0 or age > duration then return end
	local name = UnitName(member.token)
	if not name or (sender ~= name and sender:match("^[^-]+") ~= name) then return end
	local db = DB()
	local data = db and db.spells and db.spells[id]
	if not data or data.enabled == false or (data.class ~= member.class and data.class ~= "OTHER")
		or tonumber(data.cooldown) ~= presetCooldowns[id] then return end
	local now = GetTime()
	local start = now - age
	active[guid] = active[guid] or {}
	local state = active[guid][id]
	if state and state.start > start + 1 then return end
	learnedDurations[guid] = learnedDurations[guid] or {}
	learnedDurations[guid][id] = duration
	if not state or (state.displayed and start > state.start + 3) then
		state = {}
		active[guid][id] = state
	end
	-- A verified message from the caster supersedes our estimate even if the
	-- icon has already been drawn. Do not leave this cast on a known-wrong timer.
	state.start, state.duration, state.native = start, duration, true
	state.pendingUntil = nil
	extension:Render()
end

local function ObservedCooldown(guid, id, data, now)
	local member = units[guid]
	if member and member.enemy then
		return { start = now, duration = EnemyDuration(data, member), enemyEstimate = true,
			pendingAura = EnemyData.StartOnAuraRemoved[id] and true or nil }
	end
	local learned = tonumber(data.cooldown) == presetCooldowns[id]
		and learnedDurations[guid] and learnedDurations[guid][id]
	local state = { start = now, duration = learned or CooldownDuration(guid, id, data), native = learned and true or nil }
	if not learned and member and not member.enemy and guid ~= UnitGUID("player")
		and not ModifierDataKnown(guid, id, data) then
		-- Allow the inspect result or the caster's exact cooldown message to
		-- arrive before the timer is drawn for the first time.
		state.pendingUntil = now + 0.8
	end
	return state
end

function extension:Observe(guid, spellID, spellName)
	if not enabled or not units[guid] then return end
	local db = self:GetDB()
	local member = units[guid]
	if member.enemy and not member.test and specFramework and specFramework.ObserveEnemyCast then
		specFramework:ObserveEnemyCast(guid, spellID, spellName)
		member.spec = EnemySpec(member, guid)
	end
	local id, data
	if member.enemy then id, data = EnemyMatchSpell(spellID, spellName, member.class, db)
	else id, data = MatchSpell(spellID, spellName, member.class, db) end
	local now = GetTime()
	if id and data and data.enabled ~= false then
		if member.enemy then
			enemyWitnessed[guid] = enemyWitnessed[guid] or {}
			enemyWitnessed[guid][id] = true
		end
		active[guid] = active[guid] or {}
		local prior = active[guid][id]
		if not prior or (not prior.native and now - prior.start > 0.4)
			or (prior.native and now - prior.start > 3) then
			active[guid][id] = ObservedCooldown(guid, id, data, now)
		end
	end
	for _, group in ipairs(member.enemy and EnemyData.shared or shared) do
		local matched = false
		for _, memberID in ipairs(group) do
			if spellID == memberID or (member.enemy and EnemyData.Aliases[spellID] == memberID)
				or (spellName and GetSpellInfo(memberID) == spellName) then matched = true; break end
		end
		if matched then
			for configuredID, configured in pairs(member.enemy and EnemySpells(db) or db.spells) do
				if configured.class == member.class and configured.enabled ~= false then
					for _, memberID in ipairs(group) do
						if GetSpellInfo(configuredID) == GetSpellInfo(memberID) then
							active[guid] = active[guid] or {}
								local prior = active[guid][configuredID]
								if not prior or now - prior.start > 0.4 then
									active[guid][configuredID] = ObservedCooldown(guid, configuredID, configured, now)
								end
							break
						end
					end
				end
			end
			break
		end
	end

	local resets = (member.enemy and EnemyData.resetters or resetters)[member.enemy and (EnemyData.Aliases[spellID] or spellID) or spellID]
	if resets and active[guid] then
		for _, resetID in ipairs(resets) do
			local resetName = GetSpellInfo(resetID)
			for trackedID in pairs(active[guid]) do
				if trackedID == resetID or (resetName and GetSpellInfo(trackedID) == resetName) then
					active[guid][trackedID] = nil
				end
			end
		end
	end
	if spellID == 14185 and active[guid] and talentLib and talentLib.GUIDHasGlyph
		and talentLib:GUIDHasGlyph(guid, 56819) then
		-- Glyph of Preparation also resets Kick and Dismantle.
		active[guid][1766] = nil
		active[guid][51722] = nil
	end
	local link = member and not member.enemy and linkedUse[member.race]
	if link then
		local found = false
		for index = 1, #link do
			if link[index] == spellID or link[index] == id then found = true break end
		end
		if found then
			local spells = self:GetDB().spells
			active[guid] = active[guid] or {}
			for index = 1, #link do
				local linkedID = link[index]
				if linkedID ~= id and linkedID ~= spellID and spells[linkedID] then
					local prior = active[guid][linkedID]
					local remain = prior and (prior.start + prior.duration - now) or 0
					if remain < link.cooldown then
						active[guid][linkedID] = { start = now, duration = link.cooldown, shared = true }
					end
				end
			end
		end
	end
	self:Render()
end

function extension:EnemyAuraRemoved(guid, spellID)
	local id = EnemyData.Aliases[spellID] or spellID
	local state = active[guid] and active[guid][id]
	local member = units[guid]
	local db = DB()
	local data = db and EnemySpells(db)[id]
	if not state or not state.pendingAura or not member or not data then return end
	state.pendingAura = nil
	state.start = GetTime()
	state.duration = EnemyDuration(data, member)
	self:Render()
end

local function ShouldShow(data, remaining, displayMode, activeEffect)
	if data.enabled == false then return false end
	if displayMode == "cooldown" then return remaining > 0 end
	if displayMode == "cooldown_active" then return remaining > 0 or activeEffect and true or false end
	return true
end

local function TestCooldownState(guid, id, data, now)
	local duration = math.max(0, tonumber(data.cooldown) or 0)
	active[guid] = active[guid] or {}
	local state = active[guid][id]
	if not state then
		state = { start = now - duration * 0.25, duration = duration }
		active[guid][id] = state
	end
	return state
end

local function HasTalent(member, guid, id, data)
	-- A witnessed cast is stronger evidence than an inspection result that may
	-- arrive late or be incomplete for another party member.
	if active[guid] and active[guid][id] then return true end
	if specFramework then
		return specFramework:HasTalent(member.token, guid, id, data.talentTab, data.talentIndex) == true
	end
	-- Until inspection succeeds, a witnessed cast is the only reliable evidence.
	return active[guid] and active[guid][id] ~= nil
end

local TRINKET_SLOT_1, TRINKET_SLOT_2 = 13, 14
local lastInspect = {}

local function TrinketEquipped(unit, data, spellID)
	if not unit or not (data.item or data.trinket) then return true end
	local spellName = GetSpellInfo(spellID)
	local seen = false
	for slot = TRINKET_SLOT_1, TRINKET_SLOT_2 do
		local itemID = GetInventoryItemID(unit, slot)
		if itemID then
			seen = true
			if data.item and itemID == data.item then return true end
			if spellName and GetItemSpell(itemID) == spellName then return true end
		end
	end
	if not seen and not UnitIsUnit(unit, "player") and CanInspect and CanInspect(unit) then
		local guid = UnitGUID(unit)
		local now = GetTime()
		if guid and (lastInspect[guid] or 0) + 10 < now then
			lastInspect[guid] = now
			NotifyInspect(unit)
		end
	end
	return false
end

function extension:EntryLabel(id, data)
	data = data or {}
	if data.item then
		local name = GetItemInfo(data.item)
		if name and name ~= "" then return name end
	end
	local spell = GetSpellInfo(id)
	if spell and spell ~= "" then return spell end
	if data.itemName and data.itemName ~= "" then return data.itemName end
	return "ID " .. tostring(id)
end

function extension:EntryIcon(id, data)
	data = data or {}
	if data.item then
		local icon = select(10, GetItemInfo(data.item))
		if icon then return icon end
	end
	return select(3, GetSpellInfo(id)) or data.icon
end

local function AbilityAvailable(member, guid, id, data)
    if not member.enemy and data.enemyOnly then return false end
    if member.test and not member.enemy then return data.class == member.class end
	if data.faction and UnitFactionGroup and (member.test and (member.race == "Human" and "Alliance" or "Horde")
		or UnitFactionGroup(member.token)) ~= data.faction then return false end
	if data.race and member.race ~= data.race then return false end
	if data.excludeRace and member.race == data.excludeRace then return false end
	if member.enemy then
		local record = data._enemyRecord
		if record and member.spec and not (enemyWitnessed[guid] and enemyWitnessed[guid][id]) then
			if record.notSpec == member.spec then return false end
			if record.specs then
				local allowed = false
				for _, spec in ipairs(record.specs) do
					if spec == member.spec or (member.spec == "Preg"
						and (spec == "Protection" or spec == "Retribution")) then
						allowed = true; break
					end
				end
				if not allowed then return false end
			end
		end
		return true
	end
	if (data.item or data.trinket) and not member.enemy and not TrinketEquipped(member.token, data, id) then return false end
	if not data.talent then return true end
	if member.enemy then return true end
	return HasTalent(member, guid, id, data)
end

local function RaiseIcon(icon, frame)
	extension:PrepareIcon(icon)
	local layerFrame = frame.GetFrameLevel and frame or frame.GetParent and frame:GetParent()
	local strata = layerFrame and layerFrame.GetFrameStrata and layerFrame:GetFrameStrata()
	if strata and icon:GetFrameStrata() ~= strata then icon:SetFrameStrata(strata) end
	local level = (layerFrame and layerFrame.GetFrameLevel and layerFrame:GetFrameLevel() or 0) + 20
	if icon:GetFrameLevel() ~= level then
		icon:SetFrameLevel(level)
		icon._glowDirty = true
	end
	if icon.cooldown and icon.cooldown.SetFrameLevel then
		icon.cooldown:SetFrameLevel((icon:GetFrameLevel() or level) + 1)
	end
	if icon.UpdateBorderSize then icon:UpdateBorderSize() end
end

local function AuraMatters(member, spellID, spellName)
	local db = DB()
	if not member or not db or not db.spells then return false end
	for id, data in pairs(db.spells) do
		if data.enabled ~= false and (data.class == member.class or data.class == "OTHER") then
			if not spellID and not spellName then return true end
			if spellID and id == spellID then return true end
			if spellName and spellName ~= "" and GetSpellInfo(id) == spellName then return true end
		end
	end
	return false
end

local function MarkAura(guid, spellID, spellName, present)
	if not guid then return end
	local set = liveAuras[guid]
	if present then
		set = set or {}
		liveAuras[guid] = set
		if spellID then set[spellID] = true end
		if spellName and spellName ~= "" then set[spellName] = true end
	elseif set then
		if spellID then set[spellID] = nil end
		if spellName and spellName ~= "" then set[spellName] = nil end
	end
end

local function AuraSet(unit, guid)
	local set = {}
	local function Scan(method)
		if not unit or not method then return end
		for index = 1, 40 do
			local name, _, _, _, _, duration, expiration, caster, _, _, spellID = method(unit, index)
			if not name then break end
			-- Receiving an effect does not mean this member used the ability.
			if caster and guid and UnitGUID(caster) == guid then
			local aura = true
			if duration and duration > 0 and expiration and expiration > GetTime() then
				aura = { start = expiration - duration, duration = duration, expiration = expiration }
			end
			set[name] = aura
			if spellID then set[spellID] = aura end
			end
		end
	end
	local tracking = SUI.AuraTracking
	Scan(tracking and tracking.UnitBuff or UnitBuff)
	Scan(tracking and tracking.UnitDebuff or UnitDebuff)
	local extra = guid and liveAuras[guid]
	if extra then
		for key, on in pairs(extra) do
			if on and not set[key] then set[key] = true end
		end
	end
	return set
end

local function GlowNow(data, spellID, remaining, auras)
	local highlight = data.highlight
	if highlight == nil or highlight == false or highlight == 0 then return false end
	local when = data.glowWhen or "cooldown"
	if when == "always" then return true end
	if when == "ready" then return remaining <= 0 end
	if when == "active" then
		local name = GetSpellInfo(spellID)
		return auras and (auras[spellID] or (name and auras[name])) and true or false
	end
	return remaining > 0
end

local function ArenaReferenceIconSize(member, frame)
	local arenaDB = SUI.db and SUI.db.profile and SUI.db.profile.modules
		and SUI.db.profile.modules.arena
	local trinkets = arenaDB and arenaDB.Trinkets or {}
	local gladius = arenaDB and arenaDB.frameType == "gladius"
	local arenaModule = SUI.modules and SUI.modules.arena
	local index = tonumber(member.token and member.token:match("^arena(%d+)$"))
	local icon
	if index and member.test then
		local prefix = "SarychUIArenaTestTrinket" .. index
		local racial = _G[prefix .. "Racial"]
		local trinket = _G[prefix .. "Trinket1"]
		icon = racial and racial:IsShown() and racial or trinket and trinket:IsShown() and trinket
	elseif index and arenaModule and arenaModule.Trinkets then
		local prefix = "arena" .. index
		local racial = arenaModule.Trinkets[prefix .. "Trinket2"]
		local trinket = arenaModule.Trinkets[prefix .. "Trinket1"]
		icon = racial and racial:IsShown() and racial or trinket and trinket:IsShown() and trinket
	end
	local frameScale = frame:GetEffectiveScale()
	if not frameScale or frameScale <= 0 then frameScale = UIParent:GetEffectiveScale() or 1 end
	if icon then
		local ratio = (icon:GetEffectiveScale() or frameScale) / frameScale
		return icon:GetWidth() * ratio, icon:GetHeight() * ratio
	end
	local size = gladius and 40 or (26 * (tonumber(trinkets.scale) or 1))
	return size, gladius and 41 or size
end

local function Position(icon, frame, layout, index, data, cellSize, autoAnchor, rowCount, centerRows,
	forcedWidth, forcedHeight, anchorOffsetX, anchorOffsetY)
	local parent = icon:GetParent()
	local parentScale = parent and parent.GetEffectiveScale and parent:GetEffectiveScale()
	local frameScale = frame and frame.GetEffectiveScale and frame:GetEffectiveScale()
	local scale = centerRows and parentScale and parentScale > 0 and frameScale
		and frameScale / parentScale or 1
	if icon:GetScale() ~= scale then icon:SetScale(scale) end
	local side = layout.side or "RIGHT"
	local point = side == "LEFT" and "RIGHT" or side == "RIGHT" and "LEFT"
		or side == "TOP" and "BOTTOM" or "TOP"
	local dx, dy = 0, 0
	local size = forcedWidth or tonumber(data.size) or tonumber(layout.size) or 24
	local height = forcedHeight or size
	cellSize = cellSize or math.max(size, height)
	local spacing = tonumber(layout.spacing) or 2
	local perRow = math.max(1, tonumber(layout.perRow) or 6)
	local col, row = (index - 1) % perRow, math.floor((index - 1) / perRow)
	local growth = layout.growth or "RIGHT"
	if autoAnchor then
		local left = side == "LEFT"
		point, side = left and "RIGHT" or "LEFT", left and "LEFT" or "RIGHT"
		local step = cellSize + spacing
		if growth == "RIGHT" or growth == "LEFT" then
			dx = col * step * (growth == "LEFT" and -1 or 1)
			dy = (((rowCount or 1) - 1) / 2 - row) * step
		else
			dx = row * step * (left and -1 or 1)
			dy = col * step * (growth == "DOWN" and -1 or 1)
		end
		frame = autoAnchor
	elseif growth == "RIGHT" then dx, dy = col * (cellSize + spacing), -row * (cellSize + spacing)
	elseif growth == "LEFT" then dx, dy = -col * (cellSize + spacing), -row * (cellSize + spacing)
	elseif growth == "UP" then dx, dy = row * (cellSize + spacing), col * (cellSize + spacing)
	else dx, dy = row * (cellSize + spacing), -col * (cellSize + spacing) end
	if centerRows and not autoAnchor and (growth == "RIGHT" or growth == "LEFT") then
		dy = dy + ((rowCount or 1) - 1) * (cellSize + spacing) / 2
	end
	local x, y = (tonumber(autoAnchor and layout.autoX or layout.x) or (autoAnchor and 7 or 0)) + dx,
		(tonumber(autoAnchor and layout.autoY or layout.y) or 0) + dy
	if autoAnchor and (layout.side or "RIGHT") == "LEFT" then
		x = (tonumber(layout.autoX) or -7) + dx
	end
	if autoAnchor then
		x = x + (anchorOffsetX or 0)
		y = y + (anchorOffsetY or 0)
	end
	RaiseIcon(icon, frame)
	if icon._anchor == frame and icon._point == point and icon._side == side
		and icon._x == x and icon._y == y and icon._size == size
		and icon._height == height then return end
	icon._anchor, icon._point, icon._side = frame, point, side
	icon._x, icon._y, icon._size, icon._height = x, y, size, height
	icon:SetSize(size, height)
	RaiseIcon(icon, frame)
	if icon.glowing and Glow.Fit then Glow.Fit(icon) end
	icon:ClearAllPoints()
	icon:SetPoint(point, frame, side, x, y)
end

function extension:PositionIcon(icon, frame, layout, index, data, cellSize, autoAnchor, rowCount, centerRows,
	forcedWidth, forcedHeight, anchorOffsetX, anchorOffsetY)
	Position(icon, frame, layout, index, data, cellSize, autoAnchor, rowCount, centerRows,
		forcedWidth, forcedHeight, anchorOffsetX, anchorOffsetY)
end

function extension:GetArenaRightmostAbilityIcon(frame)
	local rightmost, edge
	for _, icon in pairs(icons) do
		if icon._arenaFrame == frame and icon:IsShown() then
			local right = icon:GetRight()
			if right and (not edge or right > edge) then
				rightmost, edge = icon, right
			end
		end
	end
	return rightmost
end

function extension:ApplyIconAppearance(icon, layout)
	local drawEdge = layout.cooldownEdge == true
	if icon.cooldown.SetDrawEdge and icon._drawEdge ~= drawEdge then
		icon._drawEdge = drawEdge
		if icon.timerStart and icon.timerDuration then
			CooldownFrame_SetTimer(icon.cooldown, icon.timerStart, icon.timerDuration, 1)
			if SarychUI_NotifyCooldown then SarychUI_NotifyCooldown(icon.cooldown, icon.timerStart, icon.timerDuration, 1) end
		end
		icon.cooldown:SetDrawEdge(drawEdge)
	end
end

-- Ability icons live under UIParent to avoid tainting Blizzard's secure arena
-- buttons. Mirror the arena frame's appearance as soon as it changes.
function extension:SyncArenaFrameAppearance(frame, alpha, hidden)
	if not frame then return end
	hidden = hidden and true or false
	local previous = arenaAppearanceByFrame[frame]
	if previous and previous.alpha == alpha and previous.hidden == hidden then return end
	arenaAppearanceByFrame[frame] = { alpha = alpha, hidden = hidden }
	for _, icon in pairs(icons) do
		if icon._arenaFrame == frame then
			if hidden then
				icon:Hide()
				if icon.glowing then Glow.Stop(icon); icon.glowing = nil end
			elseif icon:GetAlpha() ~= alpha then
				icon:SetAlpha(alpha)
			end
		end
	end
	if previous and previous.hidden and not hidden and enabled then self:Render() end
end

function extension:Render()
    if self.Standalone then self.Standalone:Refresh() end
	local db = self:GetDB()
	local partyAllowed = db and db.enabled ~= false and Allowed(db)
	local enemyAllowed = EnemyAllowed()
	if not enabled or not db or (not partyAllowed and not enemyAllowed) then
		for _, icon in pairs(icons) do icon:Hide(); Glow.Stop(icon); icon.glowing = nil end
		return
	end
	local seen = {}
	local now = GetTime()
	local frames = FrameMap()
	for guid, member in pairs(units) do
		if member.enemy then member.spec = EnemySpec(member, guid) end
		local target = frames[guid]
		local frame, kind = target and target[1], target and target[2]
		local showMember = member.enemy and enemyAllowed or (not member.enemy and partyAllowed)
		local enemyDead = false
		if member.enemy then
			if not Detached() and arenaDeadGUID[guid] and UnitExists(member.token)
				and UnitGUID(member.token) == guid
				and not UnitIsDeadOrGhost(member.token)
				and UnitHealth(member.token) > 0 then
				arenaDeadGUID[guid] = nil
			end
			local index = tonumber(member.token and member.token:match("^arena(%d+)$"))
			local arenaModule = SUI.modules and SUI.modules.arena
			enemyDead = not member.test and arenaDeadGUID[guid] or false
			if not enemyDead then
				enemyDead = index and arenaModule and arenaModule.IsArenaOpponentDead
					and arenaModule:IsArenaOpponentDead(index, member.test) or false
			end
		end
		if frame and showMember and (member.enemy or db.showPlayer ~= false or (member.test and not member.player) or not UnitIsUnit(member.token, "player"))
			and not enemyDead
			and (member.test or not UnitIsDeadOrGhost or not UnitIsDeadOrGhost(member.token)) then
			local auras = member.test and {} or AuraSet(member.token, guid)
			local list = {}
			local enemyDisplayMode = member.enemy and ((EnemySettings() or {}).displayMode or "all")
			for id, data in pairs(member.enemy and EnemySpells(db) or db.spells or {}) do
				local known = GetSpellInfo(id) or data.item or data.trinket or data.icon
				if (data.class == member.class or data.class == "OTHER") and known
					and (not member.enemy or not (data.racial or data.trinket))
					and AbilityAvailable(member, guid, id, data) then
					local state = active[guid] and active[guid][id]
					if state and not member.test then
						if member.enemy and state.enemyEstimate and not state.shared then
							state.duration = EnemyDuration(data, member)
						else
							SyncPlayerCooldown(guid, id, data, state, now)
						end
					end
					if member.test and data.enabled ~= false then
						state = TestCooldownState(guid, id, data, now)
					end
					local remaining = state and not state.pendingAura
						and math.max(0, state.start + state.duration - now) or 0
					local activeEffect = not member.enemy and (auras[id] or auras[GetSpellInfo(id)])
					local aura = activeEffect
					if type(aura) ~= "table" or aura.expiration <= now then aura = nil end
					local mode = member.enemy and enemyDisplayMode or db.displayMode
					if ShouldShow(data, remaining, mode, activeEffect)
						or (member.enemy and state and state.pendingAura and data.enabled ~= false) then
						list[#list + 1] = { id = id, data = data, state = state, remaining = remaining, aura = aura }
					end
				end
			end
			table.sort(list, function(a, b)
				local ao, bo = tonumber(a.data.order) or 100, tonumber(b.data.order) or 100
				return ao == bo and a.id < b.id or ao < bo
			end)
			if member.test and member.token == "arena1" then
				for index = #list, 4, -1 do list[index] = nil end
			elseif member.test and member.token == "arena2" then
				for index = #list, 6, -1 do list[index] = nil end
			end
			local layout = kind == "arena" and ((EnemySettings() or {}).layout or {})
				or (db.layouts and db.layouts[kind] or {})
			local perRow = math.max(1, tonumber(layout.perRow) or 6)
			local largeWidth, largeHeight
			if member.enemy and kind == "arena" and layout.largeSingleRow == true
				and #list > 0 and #list <= perRow then
				largeWidth, largeHeight = ArenaReferenceIconSize(member, frame)
			end
			local cellSize = tonumber(layout.size) or 24
			if largeWidth then
				cellSize = math.max(largeWidth, largeHeight)
			else
				for _, item in ipairs(list) do cellSize = math.max(cellSize, tonumber(item.data.size) or 0) end
			end
			local autoAnchor, anchorOffsetX, anchorOffsetY
			if member.enemy then
				local arenaModule = SUI.modules and SUI.modules.arena
				local index = tonumber(member.token and member.token:match("^arena(%d+)$"))
				if arenaModule and arenaModule.GetAbilityAnchor and index then
					autoAnchor, anchorOffsetX, anchorOffsetY = arenaModule:GetAbilityAnchor(index, member.test, layout.side)
				end
			end
			local rowCount = math.ceil(#list / perRow)
			for index, item in ipairs(list) do
				local key = guid .. ":" .. item.id
				local icon = icons[key] or NewIcon(key, guid)
				local appearing = not icon:IsShown()
				icon._arenaFrame = member.enemy and frame or nil
				seen[key] = true
				local tex = extension:EntryIcon(item.id, item.data)
				if icon.spellID ~= item.id or icon._tex ~= tex then
					icon.spellID = item.id
					icon.spellData = item.data
					icon._tex = tex
					icon.texture:SetTexture(tex)
				end
				Position(icon, frame, layout, index, item.data, cellSize, autoAnchor, rowCount,
					member.enemy, largeWidth, largeHeight, anchorOffsetX, anchorOffsetY)
				local alpha = member.enemy and frame:GetAlpha() or 1
				if icon:GetAlpha() ~= alpha then icon:SetAlpha(alpha) end
				self:ApplyIconAppearance(icon, layout)
				local desaturated = member.enemy and enemyDisplayMode == "all"
					and layout.desaturateOnCooldown == true
					and item.remaining > 0
				icon.texture:SetDesaturated(desaturated)
				SUI.WidgetAPI.SetShown(icon.pendingText, item.state and item.state.pendingAura)
				self:ApplyAbilityTimer(icon, item.state, item.remaining, item.aura, now)
				local glowNow = GlowNow(item.data, item.id, item.remaining, auras)
				local sameGlow = icon.glowing and icon.glowData == item.data and not icon._glowDirty
				if glowNow and not sameGlow then
					if icon.UpdateBorderSize then icon:UpdateBorderSize() end
					-- Conditions may toggle while the icon remains visible (ready,
					-- cooldown, active aura). Play the proc intro once per appearance.
					Glow.Start(icon, item.data, icon._procIntroPlayed)
					if item.data.glowType == "proc" then icon._procIntroPlayed = true end
					icon.glowing, icon.glowData, icon._glowDirty = true, item.data, nil
				elseif not glowNow and icon.glowing then
					Glow.Stop(icon)
					icon.glowing, icon.glowData = nil, nil
				end
				icon:Show()
				if appearing and member.enemy and kind == "arena" and enemyDisplayMode == "cooldown"
					and item.remaining > 0 and not (item.state.pendingUntil and item.state.pendingUntil > now) then
					PlayOmniBarAppear(icon)
				end
			end
		end
	end
	for key, icon in pairs(icons) do
		if not seen[key] then icon:Hide(); if icon.glowing then Glow.Stop(icon); icon.glowing = nil end end
	end
end

-- An observed active effect temporarily uses the same widget as its cooldown.
-- The cooldown state continues running underneath; removing/expiring the aura
-- restores the original cooldown, not a new full-length timer.
function extension:ApplyAbilityTimer(icon, state, remaining, aura, now)
	if aura then
		icon.texture:SetVertexColor(1, 1, 1)
		self:SetIconTimer(icon, aura.start, aura.duration, true)
	elseif state and state.pendingAura then
		icon._cooldownEnd = nil
		icon.texture:SetVertexColor(0.7, 0.7, 0.7)
		self:SetIconTimer(icon, nil)
	elseif state and state.pendingUntil and state.pendingUntil > now then
		icon._cooldownEnd = nil
		icon.texture:SetVertexColor(0.7, 0.7, 0.7)
		self:SetIconTimer(icon, nil)
	elseif remaining > 0 then
		state.displayed = true
		icon._cooldownEnd = state.start + state.duration
		icon.texture:SetVertexColor(1, 1, 1)
		self:SetIconTimer(icon, state.start, state.duration)
	else
		icon._cooldownEnd = nil
		icon.texture:SetVertexColor(1, 1, 1)
		self:SetIconTimer(icon, nil)
	end
end

-- One bridge to the native cooldown and SUI countdown text for every icon view.
function extension:SetIconTimer(icon, start, duration, reverse)
    if not start or not duration or duration <= 0 then start, duration = nil, nil end
    icon._cooldownEnd = start and start + duration or nil
    reverse = reverse == true
    if icon.timerReverse ~= reverse then
        if icon.cooldown.SetReverse then icon.cooldown:SetReverse(reverse) end
        icon.timerReverse = reverse
    end
    -- The text module can be disabled/re-enabled while this swipe keeps running.
    -- Refresh its state even when the native cooldown does not need restarting.
    local enabled = start and 1 or 0
    if SarychUI_NotifyCooldown then SarychUI_NotifyCooldown(icon.cooldown, start or 0, duration or 0, enabled) end
    if icon.timerStart == start and icon.timerDuration == duration then
        if start and icon.cooldown.Show then icon.cooldown:Show()
        elseif not start and icon.cooldown.Hide then icon.cooldown:Hide() end
        return
    end
    CooldownFrame_SetTimer(icon.cooldown, start or 0, duration or 0, enabled)
    icon.timerStart, icon.timerDuration = start, duration
end

function extension:GetEnemyCooldownSnapshot(result)
    local db = self:GetDB()
    result = result or {}
    local now, count, changed = GetTime(), 0, false
    local spells = EnemySpells(db)
    for guid, member in pairs(units) do
        if member.enemy and not member.test and not arenaDeadGUID[guid] then
            member.spec = EnemySpec(member, guid)
            for id, state in pairs(active[guid] or {}) do
                local data = spells[id]
                if data and data.enabled ~= false then
                    if state.enemyEstimate and not state.shared then state.duration = EnemyDuration(data, member) end
                    if state.pendingAura or (state.start and state.duration and state.start + state.duration > now) then
                        count = count + 1
                        local entry = result[count]
                        if not entry then entry = {}; result[count] = entry; changed = true end
                        local name = member.name or (member.token and UnitName(member.token)) or member.class
                        local texture = self:EntryIcon(id, data)
                        if entry.guid ~= guid or entry.id ~= id or entry.name ~= name or entry.class ~= member.class
                            or entry.start ~= state.start or entry.duration ~= state.duration
                            or entry.pending ~= state.pendingAura or entry.texture ~= texture or entry.data ~= data then
                            changed = true
                        end
                        if entry.guid ~= guid or entry.id ~= id then entry.key = guid .. ":" .. id end
                        entry.guid, entry.id, entry.name, entry.class = guid, id, name, member.class
                        entry.start, entry.duration, entry.pending = state.start, state.duration, state.pendingAura
                        entry.texture, entry.data = texture, data
                    end
                end
            end
        end
    end
    for i = #result, count + 1, -1 do result[i] = nil; changed = true end
    return result, changed
end

function extension:RefreshConfig()
	if DB() and DB().masterEnabled == false then self:Disable(); return end
	enemySpells, enemySpellsDB = nil, nil
	local db = self:GetDB()
	local arena = SUI.db and SUI.db.profile and SUI.db.profile.modules
		and SUI.db.profile.modules.arena
	local enemySelected = Detached() or (arena and arena.enabled ~= false and EnemySelected(arena))
	if lastDB and lastDB ~= db then active = {} end
	lastDB = db
	if db and (db.enabled ~= false or enemySelected) then self:Enable() else self:Disable() end
	if enabled then
		self:RefreshActiveDurations()
		for _, icon in pairs(icons) do
			-- Reapply settings without ending an active glow animation.
			icon._glowDirty = true
		end
		Roster(); self:Render()
	end
end

local function UpdateTick()
	local db = DB()
	local tracking = enabled and ((db and db.enabled ~= false and (IsInGroup() or GroupPreview())) or EnemyAllowed())
	if tracking ~= trackingEvents then
		trackingEvents = tracking
		if tracking then
			eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		else
			eventFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			eventFrame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		end
	end
	if not tracking then
		eventFrame:SetScript("OnUpdate", nil)
		return
	end
	eventFrame:SetScript("OnUpdate", function(_, delta)
		elapsed = elapsed + delta
		if elapsed < 0.5 then return end
		elapsed = 0
		if specFramework then
			local now = GetTime()
			for guid, retryAt in pairs(talentRetry) do
				if retryAt <= now then
					if specFramework:RequestAllyTalents(guid) then talentRetry[guid] = nil
					else talentRetry[guid] = now + 5 end
				end
			end
		end
		if GroupPreview() then Roster() end
		SyncOwnCooldowns(GetTime())
		extension:Render()
	end)
end

function extension:RefreshGroupFrames()
    self:RefreshConfig()
    UpdateTick()
end

function extension:OnTalentUpdate(_, guid)
	if guid and units[guid] then
		-- Talent inspection can finish seconds after a cast. It updates which
		-- abilities are available, but must not erase observed cooldowns.
		learnedDurations[guid] = nil
		talentRetry[guid] = nil
		self:RefreshActiveDurations(guid)
		self:Render()
	end
end

function extension:OnGlyphUpdate(_, guid)
	if guid and units[guid] then
		learnedDurations[guid] = nil
		self:RefreshActiveDurations(guid)
		self:Render()
	end
end

function extension:Enable()
	if DB() and DB().masterEnabled == false then return end
	if enabled then return end
	enabled = true
	for _, name in ipairs({ "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
		"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_TALENT_UPDATE", "UNIT_NAME_UPDATE",
		"UNIT_FACTION", "UNIT_PET", "ARENA_OPPONENT_UPDATE", "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED",
		"INSPECT_TALENT_READY", "CHAT_MSG_ADDON" }) do
		eventFrame:RegisterEvent(name)
	end
	if SUI.AuraTracking then
		SUI.AuraTracking:Subscribe("party_abilities", function(unit)
			eventFrame:GetScript("OnEvent")(eventFrame, "UNIT_AURA", unit)
		end)
	else
		eventFrame:RegisterEvent("UNIT_AURA")
	end
	if RegisterAddonMessagePrefix then RegisterAddonMessagePrefix(cooldownCommPrefix) end
	if talentLib and talentLib.RegisterCallback then
		talentLib.RegisterCallback(self, "LibGroupTalents_Update", "OnTalentUpdate")
		talentLib.RegisterCallback(self, "LibGroupTalents_GlyphUpdate", "OnGlyphUpdate")
	end
	Roster()
	UpdateTick()
	self:Render()
end

function extension:Disable()
	if self.Standalone then
		self.Standalone.testing = false
		self.Standalone:SetEditing(false)
		for _, host in pairs(self.Standalone.hosts) do host:Hide() end
		for _, widget in pairs(self.Standalone.widgets) do widget:Hide() end
	end
	if not enabled then return end
	enabled = false
	eventFrame:UnregisterAllEvents()
	if SUI.AuraTracking then SUI.AuraTracking:Unsubscribe("party_abilities") end
	trackingEvents = false
	if talentLib and talentLib.UnregisterCallback then
		talentLib.UnregisterCallback(self, "LibGroupTalents_Update")
		talentLib.UnregisterCallback(self, "LibGroupTalents_GlyphUpdate")
	end
	eventFrame:SetScript("OnUpdate", nil)
	for _, icon in pairs(icons) do icon:Hide(); Glow.Stop(icon); icon.glowing = nil end
end

function extension:Initialize() self:RefreshConfig() end

eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "CHAT_MSG_ADDON" then
		local prefix, message, _, sender = ...
		ReceiveCooldown(prefix, message, sender)
	elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
		local _, subevent, sourceGUID, sourceName, sourceFlags, destGUID, _, _, spellID, spellName = ...
        if Detached() and sourceGUID and sourceFlags and bit.band(sourceFlags, COMBATLOG_OBJECT_REACTION_HOSTILE or 64) ~= 0
            and bit.band(sourceFlags, 0x00000400 + 0x00001000 + 0x00002000) ~= 0 then
            local _, class = GetPlayerInfoByGUID(sourceGUID)
            local canonical = EnemyData.Aliases[spellID] or spellID
            local record = EnemySpells(DB())[canonical]
            class = class or (record and record.class ~= "OTHER" and record.class)
            if class then
                local member = units[sourceGUID] or detachedEnemies[sourceGUID] or { enemy = true }
                if subevent == "SPELL_CAST_SUCCESS" then arenaDeadGUID[sourceGUID] = nil end
                member.class, member.name, member.seen = class, sourceName, GetTime()
                for _, token in ipairs({"target", "focus", "arena1", "arena2", "arena3", "arena4", "arena5"}) do
                    if UnitGUID(token) == sourceGUID then member.token = token; break end
                end
                detachedEnemies[sourceGUID], units[sourceGUID] = member, member
            end
        end
		if subevent == "UNIT_DIED" and destGUID then
			liveAuras[destGUID] = nil
			if units[destGUID] and units[destGUID].enemy then arenaDeadGUID[destGUID] = true end
			extension:Render()
		elseif subevent == "SPELL_CAST_SUCCESS" and sourceGUID
			and (units[sourceGUID] or arenaPetOwners[sourceGUID]) then
			extension:Observe(arenaPetOwners[sourceGUID] or sourceGUID, spellID, spellName)
		elseif subevent == "SPELL_AURA_REMOVED" and destGUID and units[destGUID]
			and units[destGUID].enemy and EnemyData.StartOnAuraRemoved[EnemyData.Aliases[spellID] or spellID] then
			extension:EnemyAuraRemoved(destGUID, spellID)
		elseif destGUID and sourceGUID == destGUID and units[destGUID]
			and AuraMatters(units[destGUID], spellID, spellName) then
			if subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" or subevent == "SPELL_AURA_APPLIED_DOSE" then
				MarkAura(destGUID, spellID, spellName, true)
				extension:Render()
			elseif subevent == "SPELL_AURA_REMOVED" then
				MarkAura(destGUID, spellID, spellName, false)
				extension:Render()
			end
		end
	elseif event == "UNIT_AURA" then
		local unit = ...
		local guid = unit and UnitGUID(unit)
		local member = guid and units[guid]
		if member and AuraMatters(member) then
			liveAuras[guid] = nil
			extension:Render()
		end
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		local unit, spellName, _, _, spellID = ...
		local guid = unit and UnitGUID(unit)
		local ownerGUID = guid and (arenaPetOwners[guid] or guid)
		if ownerGUID and units[ownerGUID] then extension:Observe(ownerGUID, spellID, spellName) end
	elseif event == "GET_ITEM_INFO_RECEIVED" then
		local itemID = ...
		local db = DB()
		local relevant = false
		if itemID and db and db.spells then
			for _, data in pairs(db.spells) do
				if data.item == itemID then
					relevant = true
					local name = GetItemInfo(itemID)
					if name and name ~= "" then data.itemName = name end
				end
			end
		end
		if relevant then
			extension:Render()
			if SUI.NotifySarychUIOptionsChange then SUI:NotifySarychUIOptionsChange() end
		end
	else
		if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
			wipe(arenaLastSeen)
            for guid, member in pairs(detachedEnemies) do active[guid] = nil end
            wipe(detachedEnemies)
			wipe(arenaDeadGUID)
			wipe(enemyWitnessed)
			wipe(enemySpecHints)
		end
		if event ~= "PLAYER_REGEN_DISABLED" and event ~= "PLAYER_REGEN_ENABLED" then
			Roster()
		end
		if event == "PLAYER_TALENT_UPDATE" then
			extension:RefreshActiveDurations(UnitGUID("player"))
		end
		UpdateTick()
		extension:Render()
	end
end)
