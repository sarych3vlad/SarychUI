local SuiTimer = select(2, ...).Compat.Timer
-- SarychUI Arena Module
-- Arena enemy frames positioning, scaling and testing (based on sArena behavior)

local moduleName = "arena"
local module = {}
local RegisterArenaRangeFrames, UnregisterArenaRangeFrames

-- Register module
SarychUI:RegisterModule(moduleName, module)

-- Local references
local L = SarychUI.L

-- Helpers
local function GetDB()
	local root = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return root and root[moduleName]
end

function module:GetGladiusPrimaryContent()
	local db = GetDB()
	if not db then return "none" end
	local choice = db.styles and db.styles.gladius and db.styles.gladius.rightPrimary
	if choice == "racial" or choice == "procTrinkets" or choice == "none" then return choice end
	return db.Trinkets and db.Trinkets.racialEnabled == true and "racial" or "none"
end

function module:GetClassicPrimaryContent()
	local db = GetDB()
	if not db then return "none" end
	local choice = db.styles and db.styles.classic and db.styles.classic.rightPrimary
	if choice == "racial" or choice == "procTrinkets" or choice == "none" then return choice end
	return db.Trinkets and db.Trinkets.racialEnabled == true and "racial" or "none"
end

function module:IsDRShown(kind)
	local db = GetDB()
	if not db then return false end
	local dr = SarychUI.extensions and SarychUI.extensions.diminishings
	if not dr or not dr:IsArenaEnabled() then return false end
	local style = self:GetStyleSettings(kind or db.frameType)
	local choice = style and style.diminishingDisplay
	if choice ~= nil then return choice == "show" end
	return db.diminishingDisplay == "show"
end

function module:GetClassicLeftContent()
	local db = GetDB()
	if not db then return "none" end
	local dr = self.GetDRSettings and self:GetDRSettings("classic")
	if self:IsDRShown("classic") and dr and dr.side ~= "RIGHT" then return "diminishings" end
	local choice = db.styles and db.styles.classic and db.styles.classic.leftContent
	return choice == "procTrinkets" and choice or "none"
end

local function ArenaCooldownsEnabled()
    local tracker = SarychUI.extensions and SarychUI.extensions.party_abilities
    return not tracker or not tracker.IsArenaDisplayEnabled or tracker:IsArenaDisplayEnabled()
end

function module:GetClassicRightContent()
	local db = GetDB()
	if not db then return "none" end
	local dr = self.GetDRSettings and self:GetDRSettings("classic")
	if self:IsDRShown("classic") and dr and dr.side == "RIGHT" then return "diminishings" end
	local choice = db.styles and db.styles.classic and db.styles.classic.rightContent
	if choice == "enemyAbilities" and not ArenaCooldownsEnabled() then return "none" end
	if choice == "enemyAbilities" or choice == "procTrinkets" or choice == "none" then return choice end
	if db.additionalInfo == "enemyAbilities" and ArenaCooldownsEnabled() then return "enemyAbilities" end
	return db.procTrinkets and db.procTrinkets.enabled == true and "procTrinkets" or "none"
end

function module:IsArenaRacialEnabled()
	local db = GetDB()
	if not db then return false end
	if db.frameType == "gladius" then return self:GetGladiusPrimaryContent() == "racial" end
	return self:GetClassicPrimaryContent() == "racial"
end

function module:GetGladiusLeftContent(ignoreCastBar)
	local db = GetDB()
	if not db then return "none" end
	if not ignoreCastBar and db.styles and db.styles.gladius
		and db.styles.gladius.castBarPos == "LEFT" then return "none" end
	local dr = self.GetDRSettings and self:GetDRSettings("gladius")
	if self:IsDRShown("gladius") and dr and dr.side ~= "RIGHT" then
		return "diminishings"
	end
	local choice = db.styles and db.styles.gladius and db.styles.gladius.leftContent
	return choice == "procTrinkets" and choice or "none"
end

function module:GetGladiusRightContent()
	local db = GetDB()
	if not db then return "none" end
	local dr = self.GetDRSettings and self:GetDRSettings("gladius")
	if self:IsDRShown("gladius") and dr and dr.side == "RIGHT" then
		return "diminishings"
	end
	local choice = db.styles and db.styles.gladius and db.styles.gladius.rightContent
	if choice == "enemyAbilities" and not ArenaCooldownsEnabled() then return "none" end
	if choice == "enemyAbilities" or choice == "procTrinkets" or choice == "none" then
		return choice
	end
	if db.additionalInfo == "enemyAbilities" and ArenaCooldownsEnabled() then return "enemyAbilities" end
	return db.procTrinkets and db.procTrinkets.enabled == true and "procTrinkets" or "none"
end

local STYLE_KEYS = {
	scale = true, frameSpacing = true,
	arenaA = true, arenaR = true, arenaX = true, arenaY = true,
}

function module:GetStyleSettings(kind)
	local db = GetDB()
	if not db then return end
	kind = kind or db.frameType
	db.styles = db.styles or {}
	if not db.styles.classic then
		db.styles.classic = {
			scale = db.scale or 1, frameSpacing = db.frameSpacing or 40,
			showSpecText = false,
			arenaA = db.arenaA or "RIGHT", arenaR = db.arenaR or "RIGHT",
			arenaX = db.arenaX or -311, arenaY = db.arenaY or 131,
		}
	end
	if db.styles.classic.showCastShield == nil then db.styles.classic.showCastShield = true end
	if db.styles.classic.showSpecText == nil then db.styles.classic.showSpecText = false end
	if not db.styles.gladius then
		local classic = db.styles.classic
		db.styles.gladius = {
			scale = 1, frameSpacing = db.frameSpacingGladius or 4,
			barWidth = 165, castBarHeight = 18, castTextSize = 10, showSpecText = true,
			castBarPos = "CENTER", showPets = true,
			arenaA = classic.arenaA, arenaR = classic.arenaR,
			arenaX = classic.arenaX, arenaY = classic.arenaY,
		}
	end
	if not db.styles.gladius.barWidth then
		local oldCastWidth = tonumber(db.styles.gladius.castBarWidth)
		db.styles.gladius.barWidth = oldCastWidth
			and (oldCastWidth - 40 + (tonumber(db.styles.gladius.castBarHeight) or 18)) or 165
	end
	if db.styles.gladius.showDarkBackground == nil then db.styles.gladius.showDarkBackground = true end
	if db.styles.gladius.showCastShield == nil then db.styles.gladius.showCastShield = true end
	if db.styles.gladius.showCastShieldIcon == nil then db.styles.gladius.showCastShieldIcon = true end
	if db.styles.gladius.colorProtectedCast == nil then db.styles.gladius.colorProtectedCast = true end
	if db.styles.gladius.castBarPos ~= "LEFT" then db.styles.gladius.castBarPos = "CENTER" end
	db.styles.gladius.castBarHeight = math.max(12, math.min(
		db.styles.gladius.castBarPos == "LEFT" and 40 or 30,
		tonumber(db.styles.gladius.castBarHeight) or 18))
	db.styles.gladius.castTextSize = tonumber(db.styles.gladius.castTextSize) or 10
	if db.styles.gladius.showPets == nil then db.styles.gladius.showPets = true end
	if db.styles.gladius.showSpecText == nil then
		local old = db.styles.gladius.showRaceText
		db.styles.gladius.showSpecText = old == nil or old == true
	end
	return db.styles[kind == "gladius" and "gladius" or "classic"]
end

function module:GetEnemyAbilitySettings(kind)
	local db = GetDB()
	if not db then return end
	kind = kind or db.frameType
	db.enemyAbilities = db.enemyAbilities or {}
	local enemy = db.enemyAbilities
	enemy.byStyle = enemy.byStyle or {}
	local function CopyLayout(source)
		source = source or {}
		return {
			side = source.side or "RIGHT", growth = source.growth or "RIGHT",
			x = source.x or 2, y = source.y or 6,
			autoX = source.autoX or 7, autoY = source.autoY or 0,
			size = source.size or 24, spacing = source.spacing or 5,
			perRow = source.perRow or 5, cooldownEdge = source.cooldownEdge ~= false,
			desaturateOnCooldown = source.desaturateOnCooldown == true,
			largeSingleRow = source.largeSingleRow == true,
		}
	end
	if not enemy.byStyle.classic then
		enemy.byStyle.classic = {
			displayMode = enemy.displayMode or "cooldown",
			anchorMode = "auto",
			layout = CopyLayout(enemy.layout),
		}
	end
	if not enemy.byStyle.gladius then
		enemy.byStyle.gladius = {
			displayMode = "cooldown",
			anchorMode = "auto",
			layout = CopyLayout({autoX = 7, autoY = 0, spacing = 2,
				perRow = 4, size = 29, largeSingleRow = true, cooldownEdge = true}),
		}
	end
	local settings = enemy.byStyle[kind == "gladius" and "gladius" or "classic"]
	settings.anchorMode = "auto"
	if kind ~= "gladius" and settings.layout.side ~= "RIGHT" then
		settings.layout.side = "RIGHT"
		settings.layout.autoX = math.abs(tonumber(settings.layout.autoX) or 7)
		settings.layout._signedAutoX = true
	end
	settings.layout.growth = settings.layout.side == "LEFT" and "LEFT" or "RIGHT"
	if not settings.layout._signedAutoX then
		local offset = math.abs(tonumber(settings.layout.autoX) or 7)
		settings.layout.autoX = settings.layout.side == "LEFT" and -offset or offset
		settings.layout._signedAutoX = true
	end
	return settings
end

local function CopyDRSettings(source)
	local result = {}
	for key, value in pairs(source or {}) do
		if key ~= "byStyle" then
			if type(value) == "table" then
				result[key] = CopyDRSettings(value)
			else
				result[key] = value
			end
		end
	end
	return result
end

function module:GetDRSettings(kind)
	local db = GetDB()
	if not db then return end
	kind = kind or db.frameType
	db.diminishings = db.diminishings or {}
	local settings = db.diminishings
	settings.byStyle = settings.byStyle or {}
	if not settings.byStyle.classic then
		settings.byStyle.classic = CopyDRSettings(settings)
	end
	if not settings.byStyle.gladius then
		settings.byStyle.gladius = CopyDRSettings(settings)
	end
	local cfg = settings.byStyle[kind == "gladius" and "gladius" or "classic"]
	if cfg.side ~= "RIGHT" then cfg.side = "LEFT" end
	if kind ~= "gladius" and cfg.side == "RIGHT" and not cfg.sideOffsets
		and math.abs(tonumber(cfg.y) or 0) > math.max(10, (tonumber(cfg.size) or 24) / 2) then
		-- Older profiles reused the left-side offset when DR moved to the right.
		cfg.sideOffsets = { LEFT = { x = cfg.x, y = cfg.y } }
		cfg.x, cfg.y = 2, 0
	end
	cfg.growth = cfg.side
	return cfg
end

local function GetSetting(key, default)
	local db = GetDB()
	if STYLE_KEYS[key] then
		local style = module:GetStyleSettings()
		if style and style[key] ~= nil then return style[key] end
	end
	if db and db[key] ~= nil then return db[key] end
	return default
end

-- Internal state
local arenaContainer
local eventFrame
local arenaDefaultPosition = nil
local firstArenaFramePosition = nil
local originalArenaFramePositions = {}
local arenaAppearanceUpdateFrame = nil
local arenaTestContainer = nil
local arenaTestFrames = {}
local arenaTestCastbars = {}
local arenaTestPlayerClick = nil
local classicTestPet = nil
local classicTestTicker = nil

-- ============================================
-- sArena Trinkets logic (ported with minimal changes)
-- ============================================

module.Trinkets = CreateFrame("Frame")
local trinketSuffixes = {"Trinket1", "Trinket2"}

function module:RefreshTrinketBorders()
    local preview = SarychUI.ArenaPreview
    if preview and preview.RefreshAll then preview:RefreshAll() end
end

local TrinketData = SarychUI.Data.ArenaTrinkets
local Alliance, Horde = TrinketData.alliance, TrinketData.horde
local racialSpells = TrinketData.racialSpells
local raceTranslation, raceFileToKey = TrinketData.raceTranslation, TrinketData.raceFileToKey

local function ResolveArenaRace(unit)
    if not unit then return "None" end
    local localized, raceFile = UnitRace(unit)
    if raceFile then
        local key = raceFileToKey[raceFile] or (racialSpells[raceFile] and raceFile)
        if key then return key end
    end
    local race = raceTranslation[localized] or localized
    if race and racialSpells[race] then return race end
    return race or "None"
end

function module.Trinkets:GetTrinketTextureByRaceAndFaction(race)
    if Alliance[race] then
        return TrinketData.allianceTexture
    elseif Horde[race] then
        return TrinketData.hordeTexture
    end
end

local function GetArenaIconScale(frame, scale)
    local parentScale = UIParent:GetEffectiveScale()
    local frameScale = frame and frame:GetEffectiveScale()
    if not parentScale or parentScale <= 0 or not frameScale then
        return tonumber(scale) or 1
    end
    return (tonumber(scale) or 1) * frameScale / parentScale
end

local function GladiusIcons()
    local db = GetDB()
    return db and db.frameType == "gladius"
end

local function PlaceArenaIcon(icon, frame, anchorFrame, paired)
    icon:ClearAllPoints()
    if anchorFrame then
        local db = GetDB()
        local tr = db and db.Trinkets or {}
        if not GladiusIcons() and tr.layout == "COLUMN" then
            icon:SetPoint("TOP", anchorFrame, "BOTTOM", 0, -(tonumber(tr.spacing) or 5))
        else
            icon:SetPoint("LEFT", anchorFrame, "RIGHT",
                GladiusIcons() and 1 or (tonumber(tr.spacing) or 5), 0)
        end
    elseif GladiusIcons() then
        icon:SetPoint("TOPLEFT", frame, "TOPRIGHT", 6, 0)
    else
        local db = GetDB()
        local tr = db and db.Trinkets or {}
        if paired and tr.layout == "COLUMN" then
            icon:SetPoint("LEFT", frame, "RIGHT", 2,
                (26 + (tonumber(tr.spacing) or 5)) / 2)
        elseif tr.point then
            icon:SetPoint(tr.point, frame, tr.x, tr.y)
        else
            icon:SetPoint("LEFT", frame, "RIGHT", 2, -2)
        end
    end
end

local function UpdateArenaIconCooldownColor(icon, enabled, now)
	local texture = icon and icon.Icon and icon.Icon.Texture
	if not texture then return end
	local desaturated = enabled and icon._cooldownEnd and icon._cooldownEnd > (now or GetTime()) or false
	if icon._desaturated ~= desaturated then
		texture:SetDesaturated(desaturated)
		icon._desaturated = desaturated
	end
end

function module:UpdateTrinketCooldownColors()
	local db = GetDB()
	local enabled = db and db.Trinkets and db.Trinkets.desaturateOnCooldown == true
	local now = GetTime()
	for index = 1, (MAX_ARENA_ENEMIES or 5) do
		for _, suffix in ipairs({ "Trinket1", "Trinket2" }) do
			UpdateArenaIconCooldownColor(self.Trinkets["arena" .. index .. suffix], enabled, now)
		end
		for _, suffix in ipairs({ "Trinket1", "Racial" }) do
			UpdateArenaIconCooldownColor(_G["SarychUIArenaTestTrinket" .. index .. suffix], enabled, now)
		end
	end
end

function module.Trinkets:CreateTrinketIcon(frame, texture, anchorFrame)
    local db = GetDB(); local tr = db and db.Trinkets or {}
    -- ArenaEnemyFrame is a protected SecureUnitButton.  Even an otherwise
    -- harmless visual child makes its secure click path inherit addon taint on
    -- this client, so FocusUnit from Blizzard's right-click handler is denied.
    -- Keep the cooldown in our own UIParent hierarchy and use the arena frame
    -- only as an anchor.  SetPoint reads its position without modifying it.
    local trinket = CreateFrame("Frame", nil, UIParent)
    trinket._arenaFrame = frame
    trinket:SetFrameLevel(frame:GetFrameLevel() + 3)
    local gladius = GladiusIcons()
    trinket:SetSize(gladius and 40 or 26, gladius and 41 or 26)
    trinket:SetScale(GetArenaIconScale(frame, gladius and 1 or tr.scale))
    PlaceArenaIcon(trinket, frame, anchorFrame)

    trinket.Icon = CreateFrame("Frame", nil, trinket)
    trinket.Icon:SetFrameLevel(trinket:GetFrameLevel() - 1)
    trinket.Icon:SetAllPoints()

    trinket.Icon.Texture = trinket.Icon:CreateTexture(nil, "BORDER")
    trinket.Icon.Texture:SetAllPoints(trinket)
    trinket.Icon.Texture:SetTexture(texture)
    trinket.Icon.Texture:SetTexCoord(0, 1, 0, 1)

    -- Keep the artwork attached to its cooldown. Reparenting an all-points
    -- child to UIParent makes it fill UIParent instead of the 26px icon.
    trinket.Icon:SetAlpha(1)
    trinket:Show()

    -- CooldownFrame_SetTimer hides a Cooldown with no active timer. Keep that
    -- sweep separate from the always-visible icon and its UIParent holder.
    trinket.Cooldown = CreateFrame("Cooldown", nil, trinket, "CooldownFrameTemplate")
    trinket.Cooldown:SetAllPoints(trinket)
    trinket.Cooldown:SetFrameLevel(trinket:GetFrameLevel() + 1)
    trinket.Cooldown:SetAlpha(0.65)
    trinket.Cooldown.__sary_arenaTrinket = true
    if trinket.Cooldown.SetDrawEdge then trinket.Cooldown:SetDrawEdge(true) end
    trinket.Cooldown:Hide()
    return trinket
end

function module.Trinkets:CreateNonHumanIcons(frame, id, race)
    if not racialSpells[race] then return end
    local db = GetDB()
    local tr = db and db.Trinkets or {}
    local trinket1
    if tr.enabled then
        trinket1 = self:CreateTrinketIcon(frame, self:GetTrinketTextureByRaceAndFaction(race))
        self["arena" .. id .. "Trinket1"] = trinket1
    end
    if module:IsArenaRacialEnabled() then
        self["arena" .. id .. "Trinket2"] = self:CreateTrinketIcon(frame, racialSpells[race].icon, trinket1)
    end
    if trinket1 and self["arena" .. id .. "Trinket2"] then
        PlaceArenaIcon(trinket1, frame, nil, true)
    end
end

function module.Trinkets:CreateHumanIcon(frame, id)
    local db = GetDB()
    local tr = db and db.Trinkets or {}
    -- Every Man for Himself replaces the PvP trinket for Humans. Keep it in
    -- the trinket slot even when separate racial icons are disabled.
    if tr.enabled then
        self["arena" .. id .. "Trinket1"] = self:CreateTrinketIcon(frame, racialSpells["Human"].icon)
    end
end

function module.Trinkets:CreateIcon(frame)
    if not frame or not frame.GetID then return end
    local id = frame:GetID()
    if not id then return end
    local unit = "arena" .. id
    local previous = self._iconRace and self._iconRace[id]
    local guid = UnitGUID(unit)
    local priorGUID = self._iconGUID and self._iconGUID[id]
    local existing = self[unit .. "Trinket1"] or self[unit .. "Trinket2"]

    -- Opponent slots exist before the enemy's unit data is available. Never
    -- create a placeholder (or leave an old icon visible) for an empty slot.
    if not UnitExists(unit) or not guid then
        for _, suffix in ipairs(trinketSuffixes) do
            local icon = self[unit .. suffix]
            if icon then icon:Hide() end
        end
        return
    end

    if priorGUID and guid ~= priorGUID then
        self:DeleteTrinketIcons(id)
        previous, existing = nil, nil
    end

    local race = ResolveArenaRace(unit)
    if not racialSpells[race] then
        -- UnitRace may briefly be unavailable for a known opponent.
        if previous and priorGUID == guid then
            race = previous
        else
            return
        end
    end
    local db = GetDB()
    local tr = db and db.Trinkets or {}
    local iconScale = GetArenaIconScale(frame, GladiusIcons() and 1 or tr.scale)
    for _, suffix in ipairs(trinketSuffixes) do
        local icon = self[unit .. suffix]
        if icon and icon:GetScale() ~= iconScale then icon:SetScale(iconScale) end
    end
    local complete = race == "Human"
        and (not tr.enabled or self[unit .. "Trinket1"])
        or race ~= "Human"
        and (not tr.enabled or self[unit .. "Trinket1"])
        and (not module:IsArenaRacialEnabled() or self[unit .. "Trinket2"])
    if previous == race and existing and complete and (not guid or not priorGUID or guid == priorGUID) then
        if guid and not priorGUID then self._iconGUID[id] = guid end
        for _, suffix in ipairs(trinketSuffixes) do
            local icon = self[unit .. suffix]
            if icon and not icon:IsShown() then icon:Show() end
        end
        return
    end

    if previous and previous ~= "Human" and race ~= "Human" and complete then
        local trinket = self[unit .. "Trinket1"]
        local racial = self[unit .. "Trinket2"]
        if trinket then trinket.Icon.Texture:SetTexture(self:GetTrinketTextureByRaceAndFaction(race)) end
        if racial then racial.Icon.Texture:SetTexture(racialSpells[race].icon) end
    else
        if previous or existing then self:DeleteTrinketIcons(id) end
        if race == "Human" then
            self:CreateHumanIcon(frame, id)
        else
            self:CreateNonHumanIcons(frame, id, race)
        end
    end

    self._iconRace = self._iconRace or {}
    self._iconGUID = self._iconGUID or {}
    self._iconRace[id] = race
    self._iconGUID[id] = guid or priorGUID

end

function module.Trinkets:DeleteTrinketIcons(id)
    if id then

        if self._iconRace then self._iconRace[id] = nil end
        if self._iconGUID then self._iconGUID[id] = nil end
        for _, suffix in ipairs(trinketSuffixes) do
            local name = "arena" .. id .. suffix
            if self[name] then
                local trinket = self[name]
                trinket:Hide()
                trinket:ClearAllPoints()
                trinket:SetParent(nil)
                trinket:SetAlpha(0)
                trinket:UnregisterAllEvents()
                if trinket.Icon and trinket.Icon.Texture then
                    trinket.Icon.Texture:SetTexture(nil)
                end
                self[name] = nil
            end
        end
    else
        for i = 1, (MAX_ARENA_ENEMIES or 5) do self:DeleteTrinketIcons(i) end
    end
end

function module.Trinkets:Initialize()
    local db = GetDB()
    if not db then return end
    db.Trinkets = db.Trinkets or { enabled = true, racialEnabled = true, scale = 1 }
    self:RefreshIcons()
end

function module.Trinkets:RefreshIcons()


    self:DeleteTrinketIcons()
    local db = GetDB()
    local tr = db and db.Trinkets or {}
    if select(2, IsInInstance()) ~= "arena" or not (tr.enabled or module:IsArenaRacialEnabled()) then
        self:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        self:UnregisterEvent("UNIT_NAME_UPDATE")
        self:SetScript("OnUpdate", nil)
        return
    end
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self:RegisterEvent("UNIT_NAME_UPDATE")
    self._iconRetryElapsed = 0
    self:SetScript("OnUpdate", function(owner, elapsed)
        owner._iconRetryElapsed = (owner._iconRetryElapsed or 0) + elapsed
        if owner._iconRetryElapsed < 0.5 then return end
        owner._iconRetryElapsed = 0
        for i = 1, (MAX_ARENA_ENEMIES or 5) do
            if UnitExists("arena" .. i) then
                owner:CreateIcon(_G["ArenaEnemyFrame" .. i])
            end
        end
		module:UpdateTrinketCooldownColors()
    end)
    local opponentCount = (type(GetNumArenaOpponents) == "function" and GetNumArenaOpponents()) or 0
    for i = 1, (MAX_ARENA_ENEMIES or 5) do
        if i <= opponentCount or UnitExists("arena" .. i) then
            self:CreateIcon(_G["ArenaEnemyFrame" .. i])
        end
    end
end

function module.Trinkets:ARENA_OPPONENT_UPDATE(unit, updateReason)
    local id = type(unit) == "string" and tonumber(unit:match("^arena(%d+)$"))
    if not id then return end

    local db = GetDB()
    local tr = db and db.Trinkets or {}
    if select(2, IsInInstance()) == "arena" and (tr.enabled or module:IsArenaRacialEnabled()) then
        self:CreateIcon(_G["ArenaEnemyFrame" .. id])
    end
end

function module.Trinkets:UNIT_NAME_UPDATE(unit)
    local id = type(unit) == "string" and tonumber(unit:match("^arena(%d+)$"))
    if id and select(2, IsInInstance()) == "arena" then
        self:CreateIcon(_G["ArenaEnemyFrame" .. id])
    end
end

local function StartArenaTrinketCooldown(icon, duration)
	if not icon or not icon.Cooldown then return end
	local start = GetTime()
	icon._cooldownEnd = start + duration
	CooldownFrame_SetTimer(icon.Cooldown, start, duration, 1)
	if SarychUI_NotifyCooldown then
		SarychUI_NotifyCooldown(icon.Cooldown, start, duration, 1)
	end
	local db = GetDB()
	UpdateArenaIconCooldownColor(icon,
		db and db.Trinkets and db.Trinkets.desaturateOnCooldown == true, start)
end

module.Trinkets:SetScript("OnEvent", function(self, event, ...)
    return self[event] and self[event](self, ...)
end)

function module.Trinkets:UNIT_SPELLCAST_SUCCEEDED(unitID, spell)
    if not unitID or not unitID:match("^arena%d+$") then return end
    local id = tonumber(unitID:match("^arena(%d+)$"))
    if id then self:CreateIcon(_G["ArenaEnemyFrame" .. id]) end
    local race = ResolveArenaRace(unitID)
    local trinketSpellInfo = GetSpellInfo(TrinketData.trinketSpellID)
    local humanSpellInfo = GetSpellInfo(TrinketData.humanSpellID)
    if not spell then return end
    if spell == trinketSpellInfo then
        if self[unitID .. "Trinket1"] then
            local trinket = self[unitID .. "Trinket1"]
            if trinket.Cooldown.SetDrawEdge then trinket.Cooldown:SetDrawEdge(true) end
            StartArenaTrinketCooldown(trinket, 120)
        end
    end
    if race == "Human" and spell == humanSpellInfo then
        if self[unitID .. "Trinket1"] then
            local trinket = self[unitID .. "Trinket1"]
            if trinket.Cooldown.SetDrawEdge then trinket.Cooldown:SetDrawEdge(true) end
            StartArenaTrinketCooldown(trinket, 120)
        end
    end
    if racialSpells[race] and racialSpells[race].id and spell == GetSpellInfo(racialSpells[race].id) then
        if self[unitID .. "Trinket2"] then
            local trinket = self[unitID .. "Trinket2"]
            if trinket.Cooldown.SetDrawEdge then trinket.Cooldown:SetDrawEdge(true) end
            StartArenaTrinketCooldown(trinket, racialSpells[race].cd)
        end
    end
end

function module.Trinkets:PLAYER_ENTERING_WORLD()

    self:RefreshIcons()
end

function module.Trinkets:PLAYER_LEAVING_WORLD()


    self:DeleteTrinketIcons()
end

-- Class color for arena healthbars (ported from sArena)
local function ColorArenaHealthByClass(frame)
	if not frame or not frame.unit then return end
	if not frame.healthbar then return end
	if not UnitIsPlayer(frame.unit) then return end
	local _, class = UnitClass(frame.unit)
	if not class then return end
	local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if not color then return end
	SarychUI.UnitFrameLayers:SetBarColor(frame, frame.healthbar, color.r, color.g, color.b)
end

local function TrySetupHooks()
	-- Do not hooksecurefunc ArenaEnemyFrame_UpdatePlayer. On this client the
	-- C wrapper taints the original body, so Show() at Blizzard_ArenaUI.lua:144
	-- and ArenaEnemyFrames:Show() inside it are blocked in combat.
	if module.ScheduleSecureFramePaint then
		module:ScheduleSecureFramePaint()
	end
	module._hooksDone = true
end

-- Apply class coloring on all arena frames.
function module:ApplyClassColoring()
	if not MAX_ARENA_ENEMIES then return end
	for i = 1, MAX_ARENA_ENEMIES do
		local frame = _G["ArenaEnemyFrame" .. i]
		if frame and frame.healthbar then
			ColorArenaHealthByClass(frame)
		end
	end
end

-- Save original position of first ArenaEnemyFrame (from Blizzard UI)
function module:SaveOriginalArenaFramePosition()
	if not firstArenaFramePosition then
		local firstFrame = _G["ArenaEnemyFrame1"]
		if firstFrame then
			local point, relativeTo, relativePoint, xOfs, yOfs = firstFrame:GetPoint()
			if point then
				firstArenaFramePosition = {
					point = point,
					relativeTo = relativeTo,
					relativePoint = relativePoint,
					xOfs = xOfs,
					yOfs = yOfs
				}
			end
		end
	end
end

-- Calculate default container position based on original ArenaEnemyFrame position
function module:CalculateDefaultContainerPosition()
	-- Если дефолтная позиция уже вычислена, не пересчитываем её
	-- Это гарантирует, что дефолтная позиция остается неизменной
	if arenaDefaultPosition then
		return
	end
	
	if not firstArenaFramePosition then
		self:SaveOriginalArenaFramePosition()
	end
	
	-- Если получили оригинальную позицию, вычисляем позицию контейнера
	if firstArenaFramePosition then
		-- Первый фрейм привязан к контейнеру как "TOP" к "BOTTOM" с offset 0, -8
		-- Используем оригинальную позицию первого фрейма как базу для дефолтной позиции
		
		-- Если первый фрейм привязан к UIParent, используем его позицию как базу
		local relativeTo = firstArenaFramePosition.relativeTo
		if relativeTo == UIParent or (relativeTo and relativeTo.GetName and relativeTo:GetName() == "UIParent") then
			-- Контейнер использует ту же точку привязки и те же координаты
			-- Используем оригинальную позицию первого фрейма как есть (без смещения)
			arenaDefaultPosition = {
				point = firstArenaFramePosition.point,
				relativeTo = UIParent,
				relativePoint = firstArenaFramePosition.relativePoint,
				xOfs = firstArenaFramePosition.xOfs,
				yOfs = firstArenaFramePosition.yOfs
			}
		else
			-- Fallback: используем позицию первого фрейма как есть
			arenaDefaultPosition = {
				point = firstArenaFramePosition.point,
				relativeTo = firstArenaFramePosition.relativeTo,
				relativePoint = firstArenaFramePosition.relativePoint,
				xOfs = firstArenaFramePosition.xOfs,
				yOfs = firstArenaFramePosition.yOfs
			}
		end
	end
end

-- Keep Blizzard's secure buttons anchored only to Blizzard's UIParent.
-- The movable SarychUI frame is a position editor, never an anchor in the
-- ArenaEnemyFrame click hierarchy.
function module:PlaceFirstArenaFrame()
	if not arenaContainer or (InCombatLockdown and InCombatLockdown()) then return end
	local frame = _G["ArenaEnemyFrame1"]
	if not frame then return end
	local x = arenaContainer:GetCenter()
	local y = arenaContainer:GetBottom()
	if not x or not y then return end
	local parentScale = UIParent:GetEffectiveScale()
	local frameScale = frame:GetEffectiveScale()
	if not parentScale or parentScale <= 0 or not frameScale or frameScale <= 0 then return end
	local ratio = frameScale / parentScale
	frame:ClearAllPoints()
	frame:SetPoint("TOP", UIParent, "BOTTOMLEFT", x / ratio, (y - 8) / ratio)
end

function module:ClampArenaToScreen()
	if not arenaContainer or (InCombatLockdown and InCombatLockdown()) then return end
	local drag = SarychUI.DragMode and SarychUI.DragMode:GetFrameData("arenaContainer")
	if drag and drag.isMoving then return end
	local first = _G.ArenaEnemyFrame1
	local last = _G.ArenaEnemyFrame5
	if not first or not last then return end
	local parentScale = UIParent:GetEffectiveScale()
	local scale = first:GetEffectiveScale()
	if not parentScale or parentScale <= 0 or not scale then return end
	local ratio = scale / parentScale
	local left, right = first:GetLeft(), first:GetRight()
	local top, bottom = first:GetTop(), last:GetBottom()
	if not (left and right and top and bottom) then return end
	left, right, top, bottom = left * ratio, right * ratio, top * ratio, bottom * ratio
	local width, height = UIParent:GetWidth(), UIParent:GetHeight()
	local dx, dy = 0, 0
	if right - left > width then
		dx = width / 2 - (left + right) / 2
	elseif left < 0 then dx = -left
	elseif right > width then dx = width - right end
	if top - bottom > height then
		dy = height / 2 - (top + bottom) / 2
	elseif bottom < 0 then dy = -bottom
	elseif top > height then dy = height - top end
	if math.abs(dx) < 0.5 and math.abs(dy) < 0.5 then return end
	local point, _, relativePoint, x, y = arenaContainer:GetPoint()
	if not point then return end
	x, y = (x or 0) + dx, (y or 0) + dy
	arenaContainer:ClearAllPoints()
	arenaContainer:SetPoint(point, UIParent, relativePoint or point, x, y)
	local style = self:GetStyleSettings()
	if style then style.arenaA, style.arenaR, style.arenaX, style.arenaY = point, relativePoint or point, x, y end
	self:PlaceFirstArenaFrame()
end

function module:ApplyFrameSpacing()
	local gap = tonumber(GetSetting("frameSpacing", 40)) or 40
	if gap < 0 then gap = 0 elseif gap > 60 then gap = 60 end
	local db = GetDB()
	if GetSetting("frameType", "classic") == "gladius" then
		local style = self:GetStyleSettings("gladius") or {}
		if style.showPets ~= false then gap = gap + 19 end
	else
		local tr = db and db.Trinkets or {}
		if tr.enabled and self:IsArenaRacialEnabled() and tr.layout == "COLUMN" then
			local iconScale = tonumber(tr.scale) or 1
			local spacing = tonumber(tr.spacing) or 5
			gap = math.max(gap, (52 + spacing) * iconScale / 2 - 16 + 4)
		end
		if db and db.procTrinkets and db.procTrinkets.layout == "COLUMN"
			and (self:GetClassicPrimaryContent() == "procTrinkets"
				or self:GetClassicLeftContent() == "procTrinkets"
				or self:GetClassicRightContent() == "procTrinkets") then
			local iconScale = tonumber(tr.scale) or 1
			local spacing = tonumber(db.procTrinkets.spacing) or tonumber(tr.spacing) or 5
			gap = math.max(gap, (52 + spacing) * iconScale / 2 - 16 + 4)
		end
		if db and (db.testMode or 0) > 0 then gap = gap + 30 end
	end
	if InCombatLockdown and InCombatLockdown() then
		if eventFrame then eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED") end
		return
	end
	for i = 2, 5 do
		local frame = _G["ArenaEnemyFrame" .. i]
		local previous = _G["ArenaEnemyFrame" .. (i - 1)]
		if frame and previous then
			if not originalArenaFramePositions[i] then
				local point, relativeTo, relativePoint, x, y = frame:GetPoint()
				if point then originalArenaFramePositions[i] = { point, relativeTo, relativePoint, x, y } end
			end
			frame:ClearAllPoints()
			frame:SetPoint("TOP", previous, "BOTTOM", 0, -gap)
		end
	end
end

-- Create/ensure Blizzard_ArenaUI and attach frames under our container
function module:InitializeContainer()
	-- ArenaEnemyFrame* and ArenaEnemyFrames are protected.  Never rebuild their
	-- hierarchy from combat (for example when PLAYER_ENTERING_WORLD fires after
	-- reconnecting to an arena).
	if InCombatLockdown and InCombatLockdown() then return end

	-- Do not LoadAddOn("Blizzard_ArenaUI") here.  Frame OnLoad calls
	-- UnitFrame_Initialize, which SetScript's OnEvent.  Doing that from addon
	-- code leaves the handler tainted, so Blizzard's later Show/Hide in combat
	-- is reported as ADDON_ACTION_BLOCKED on SarychUI.  The client loads the
	-- addon itself; we only anchor frames after they already exist.

	-- Сохраняем оригинальную позицию первого фрейма ДО того, как мы его изменим
	if MAX_ARENA_ENEMIES then
		local firstFrame = _G["ArenaEnemyFrame1"]
		if firstFrame and not firstArenaFramePosition then
			self:SaveOriginalArenaFramePosition()
		end
	end

	if not arenaContainer then
		-- This frame is only the movable editor for the position.
		arenaContainer = CreateFrame("Frame", "SarychUIArenaContainer", UIParent)
		arenaContainer:SetSize(200, 1)
		arenaContainer:SetScript("OnUpdate", function(self)
			local drag = SarychUI.DragMode and SarychUI.DragMode:GetFrameData("arenaContainer")
			if not (drag and drag.isMoving) or (InCombatLockdown and InCombatLockdown()) then
				self._suiDragX, self._suiDragY = nil, nil
				return
			end
			local x, y = self:GetCenter(), self:GetBottom()
			if x and y and (x ~= self._suiDragX or y ~= self._suiDragY) then
				self._suiDragX, self._suiDragY = x, y
				module:PlaceFirstArenaFrame()
			end
		end)
		
		-- Вычисляем дефолтную позицию контейнера на основе оригинальной позиции первого фрейма
		self:CalculateDefaultContainerPosition()
		
		-- Устанавливаем контейнер на дефолтную позицию
		if arenaDefaultPosition then
			arenaContainer:SetPoint(
				arenaDefaultPosition.point,
				arenaDefaultPosition.relativeTo,
				arenaDefaultPosition.relativePoint,
				arenaDefaultPosition.xOfs,
				arenaDefaultPosition.yOfs
			)
		else
			-- Fallback: если не удалось получить оригинальную позицию, используем старый подход
			arenaContainer:SetPoint("RIGHT", UIParent, "RIGHT", -311, 131)
			-- Сохраняем как дефолт
			if not arenaDefaultPosition then
				local point, relativeTo, relativePoint, xOfs, yOfs = arenaContainer:GetPoint()
				if point then
					arenaDefaultPosition = {
						point = point,
						relativeTo = relativeTo,
						relativePoint = relativePoint,
						xOfs = xOfs,
						yOfs = yOfs
					}
				end
			end
		end
	end

	if ArenaEnemyFrames then
		ArenaEnemyFrames:SetScale(GetSetting('scale', 1.0))
	end

	-- Keep Blizzard's protected hierarchy intact; only change frame anchors
	-- out of combat. Blizzard still owns their visibility and pet frames.
	self:PlaceFirstArenaFrame()
	self:ApplyFrameSpacing()
	if self.ApplyGladiusStyle then self:ApplyGladiusStyle() end
	self:ClampArenaToScreen()
	if MAX_ARENA_ENEMIES then
		for i = 1, MAX_ARENA_ENEMIES do
			local frame = _G["ArenaEnemyFrame" .. i]
			if frame then
				ColorArenaHealthByClass(frame)
			end
		end
	end

	TrySetupHooks()
end

-- Ensure container position matches DB immediately
function module:ApplyContainerPosition()
    local db = GetDB(); if not db then return end
    if not arenaContainer then return end
    if InCombatLockdown and InCombatLockdown() then return end
    
    -- Проверяем, не происходит ли сейчас drag или только что был drag - если да, не применяем позицию
    -- Это предотвращает перезапись позиции во время drag и сразу после него
    local dragData = SarychUI.DragMode and SarychUI.DragMode:GetFrameData("arenaContainer")
    if dragData and (dragData.isMoving or dragData.justDragged or dragData._settleUpdater) then return end
    
    -- Вычисляем дефолтную позицию если еще не вычислена
    if not arenaDefaultPosition then
        self:CalculateDefaultContainerPosition()
    end
    
    -- Проверяем, являются ли координаты в БД offset (от сброса) или абсолютными (от drag)
    -- Правило: offset ТОЛЬКО если координаты = 0,0 (это сброс)
    -- ВСЕ остальное - абсолютные координаты от drag
	local xOfs = GetSetting("arenaX", -311)
	local yOfs = GetSetting("arenaY", 131)
    local isOffset = (xOfs == 0 and yOfs == 0)
    
    -- Если это offset от дефолта (сброс) - применяем offset
    if isOffset and arenaDefaultPosition then
        local finalX = arenaDefaultPosition.xOfs + 0
        local finalY = arenaDefaultPosition.yOfs + 0
        
        arenaContainer:ClearAllPoints()
        arenaContainer:SetPoint(
            arenaDefaultPosition.point,
            arenaDefaultPosition.relativeTo,
            arenaDefaultPosition.relativePoint,
            finalX,
            finalY
        )
    else
        -- Если это абсолютные координаты (от drag) - применяем напрямую
		local point = GetSetting("arenaA", "RIGHT") or (arenaDefaultPosition and arenaDefaultPosition.point) or 'RIGHT'
		local relativePoint = GetSetting("arenaR", "RIGHT") or (arenaDefaultPosition and arenaDefaultPosition.relativePoint) or 'RIGHT'
        
        if xOfs == nil or yOfs == nil then
            if arenaDefaultPosition then
                point = arenaDefaultPosition.point
                relativePoint = arenaDefaultPosition.relativePoint
                xOfs = arenaDefaultPosition.xOfs
                yOfs = arenaDefaultPosition.yOfs
            else
                point = 'RIGHT'
                relativePoint = 'RIGHT'
                xOfs = -311
                yOfs = 131
            end
        end
        
        arenaContainer:ClearAllPoints()
        arenaContainer:SetPoint(point, UIParent, relativePoint, xOfs, yOfs)
    end
	self:PlaceFirstArenaFrame()
	self:ApplyFrameSpacing()
	self:ClampArenaToScreen()
end

function module:DeleteArenaFrames()
	-- Deliberately empty.  These are Blizzard protected unit buttons.  The old
	-- implementation called Hide() here on every world transition and therefore
	-- tainted their visibility.  Blizzard_ArenaUI later calls Show() in combat
	-- from ArenaEnemyFrame_UpdatePlayer, which produced ADDON_ACTION_BLOCKED.
	-- Blizzard owns their visibility; SarychUI only positions them out of combat.
end

-- Restore arena frames to default Blizzard state
function module:RestoreArenaFrames()
	if not MAX_ARENA_ENEMIES then return end
	if InCombatLockdown() then 
		-- Schedule restore after combat
		SuiTimer.After(0.1, function() self:RestoreArenaFrames() end)
		return
	end
	
	-- Restore first frame to original position if we saved it.  Never force-load
	-- Blizzard_ArenaUI: that taints ArenaEnemyFrame OnEvent for the whole session.
	if firstArenaFramePosition then
		local firstFrame = _G["ArenaEnemyFrame1"]
		if firstFrame then
			firstFrame:ClearAllPoints()
			firstFrame:SetPoint(
				firstArenaFramePosition.point,
				firstArenaFramePosition.relativeTo or UIParent,
				firstArenaFramePosition.relativePoint,
				firstArenaFramePosition.xOfs,
				firstArenaFramePosition.yOfs
			)
		end
	end
	for i = 2, 5 do
		local frame = _G["ArenaEnemyFrame" .. i]
		local position = originalArenaFramePositions[i]
		if frame and position then
			frame:ClearAllPoints()
			frame:SetPoint(position[1], position[2] or UIParent, position[3], position[4], position[5])
		end
	end
	if ArenaEnemyFrames then
		ArenaEnemyFrames:SetScale(1)
	end
	
	-- Remove class color lock from healthbars and let Blizzard update them
	for i = 1, MAX_ARENA_ENEMIES do
		local frame = _G["ArenaEnemyFrame" .. i]
		if frame and frame.healthbar then
			-- Let Blizzard update healthbar
			if UnitFrameHealthBar_Update then
				UnitFrameHealthBar_Update(frame.healthbar, frame.unit)
			end
		end
	end
	
	-- Let Blizzard handle visibility and positioning of remaining frames
	-- Blizzard will show/hide frames based on arena status
end

local TEST_CAST_SPELLS = { 1464, 2060, 133, 116, 403 }
local TEST_CLASSES = { "WARRIOR", "PRIEST", "MAGE", "ROGUE", "SHAMAN" }

function module:GetTestArenaClass(index)
	if index == 1 then return select(2, UnitClass("player")) or TEST_CLASSES[1] end
	return TEST_CLASSES[index]
end

local function EnsureArenaTestFrames()
	if InCombatLockdown and InCombatLockdown() then return false end
	if not _G.ArenaEnemyFrame1 and Arena_LoadUI and securecall then
		-- Load the Blizzard UI through its secure FrameXML entry point.
		securecall("Arena_LoadUI")
	end
	if not _G.ArenaEnemyFrame1 then return false end
	if not arenaTestContainer then
		-- Visibility marker only; the displayed frames remain Blizzard's frames.
		arenaTestContainer = CreateFrame("Frame", "SarychUIArenaTestContainer", UIParent)
		arenaTestContainer:SetSize(1, 1)
		arenaTestContainer:Hide()
	end
	for i = 1, 5 do
		arenaTestFrames[i] = _G["ArenaEnemyFrame" .. i]
	end
	return true
end

function module:GetTestArenaName(index)
	local db = GetDB()
	if db and db.enabled and (db.arenaNumbers == 1 or db.arenaNumbers == true)
		and (db.arenaNumbersArenaFrames == nil or db.arenaNumbersArenaFrames == 1 or db.arenaNumbersArenaFrames == true) then
		return tostring(index)
	end
	return index == 1 and (UnitName("player") or "player") or ("arena" .. index)
end

local function EnsureTestCastbar(id)
	local bar = arenaTestCastbars[id]
	local source = _G["ArenaEnemyFrame" .. id .. "CastingBar"]
	if not source then return end
	local style = GladiusIcons() and module:GetStyleSettings("gladius") or {}
	local castTextSize = math.max(1, math.min(20, tonumber(style.castTextSize) or 10))
	if bar then
		if GladiusIcons() then
			bar:SetFrameStrata("HIGH")
			bar:SetAlpha(1)
			if bar._suiGladiusIcon then bar._suiGladiusIcon:SetAlpha(1) end
		end
		if bar._suiGladiusBackground then
			bar._suiGladiusBackground:SetSize(source:GetWidth() + source:GetHeight(), source:GetHeight())
		end
		if bar._suiGladiusIcon then
			bar._suiGladiusIcon:SetSize(source:GetHeight(), source:GetHeight())
		end
		if bar._suiGladiusSpellText then
			bar._suiGladiusSpellText:SetFont(STANDARD_TEXT_FONT, castTextSize)
			bar._suiGladiusTimeText:SetFont(STANDARD_TEXT_FONT, castTextSize)
		end
		if bar._suiGladiusSpark then
			module:UpdateGladiusSpark(bar)
		end
		return bar
	end

	-- The native bar has no active cast in test mode, so its own scripts hide it.
	-- Draw a sample over its exact geometry without changing those scripts.
	bar = CreateFrame("StatusBar", "SarychUIArenaTestCastingBar" .. id, UIParent)
	bar:SetAllPoints(source)
	bar:SetFrameStrata(GladiusIcons() and "HIGH" or (source:GetFrameStrata() or "MEDIUM"))
	bar:SetFrameLevel((source:GetFrameLevel() or 0) + 1)
	local sourceTexture = source:GetStatusBarTexture()
	bar:SetStatusBarTexture(sourceTexture and sourceTexture:GetTexture()
		or [[Interface\TargetingFrame\UI-StatusBar]])
	local gladius = GladiusIcons()
	bar:SetStatusBarColor(1, gladius and 1 or 0.7, 0)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0.65)
	bar:EnableMouse(false)

	local background = bar:CreateTexture(nil, "BACKGROUND")
	background:SetTexture("Interface\\Buttons\\WHITE8X8")
	if gladius then
		background:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
		background:SetSize(source:GetWidth() + source:GetHeight(), source:GetHeight())
		background:SetVertexColor(0.6, 0.6, 0.6, 1)
		background:SetAlpha(0.3)
		bar._suiGladiusBackground = background
	else
		background:SetAllPoints(bar)
		background:SetVertexColor(0, 0, 0, 0.5)
	end

	local sourceName = source:GetName()
	local sourceBorder = sourceName and _G[sourceName .. "Border"]
	if sourceBorder and GetSetting("frameType", "classic") ~= "gladius" then
		local border = bar:CreateTexture(nil, "OVERLAY")
		border:SetAllPoints(sourceBorder)
		border:SetTexture(sourceBorder:GetTexture())
	end
	local spellName, _, spellIcon = GetSpellInfo(TEST_CAST_SPELLS[id])
	local sourceIcon = sourceName and _G[sourceName .. "Icon"]
	local icon = bar:CreateTexture(nil, "ARTWORK")
	if gladius then
		icon:SetSize(source:GetHeight(), source:GetHeight())
		icon:SetPoint("RIGHT", bar, "LEFT", 0, 0)
		icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
		bar._suiGladiusIcon = icon
	elseif sourceIcon then
		icon:SetAllPoints(sourceIcon)
	else
		icon:SetSize(16, 16)
		icon:SetPoint("RIGHT", bar, "LEFT", -5, 0)
	end
	bar._suiCastIcon = icon
	icon:SetTexture(spellIcon or [[Interface\Icons\Spell_Fire_FlameBolt]])

	local sourceText = sourceName and _G[sourceName .. "Text"]
	local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	if gladius then
		text:SetFont(STANDARD_TEXT_FONT, castTextSize)
		text:SetPoint("LEFT", bar, "LEFT", 5, 1)
		local timeText = bar:CreateFontString(nil, "OVERLAY")
		timeText:SetFont(STANDARD_TEXT_FONT, castTextSize)
		timeText:SetPoint("RIGHT", bar, "RIGHT", -5, 1)
		timeText:SetText("1.5")
		timeText:SetShadowColor(0, 0, 0, 1)
		timeText:SetShadowOffset(1, -1)
		bar._suiGladiusSpellText = text
		bar._suiGladiusTimeText = timeText
	elseif sourceText then
		local font, size, flags = sourceText:GetFont()
		if font then text:SetFont(font, size, flags) end
		text:SetTextColor(sourceText:GetTextColor())
		text:SetJustifyH(sourceText:GetJustifyH())
		text:SetJustifyV(sourceText:GetJustifyV())
		text:SetSize(sourceText:GetWidth(), sourceText:GetHeight())
		local point, relativeTo, relativePoint, x, y = sourceText:GetPoint(1)
		if point then
			text:SetPoint(point, relativeTo == source and bar or (relativeTo or bar), relativePoint, x, y)
		else
			text:SetPoint("TOP", bar, "TOP", 0, 5)
		end
	else
		text:SetSize(185, 16)
		text:SetPoint("TOP", bar, "TOP", 0, 5)
	end
	text:SetText(gladius and (spellName or "Пример заклинания") or (spellName or "Cast"))

	local spark = bar:CreateTexture(nil, "OVERLAY")
	spark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
	spark:SetBlendMode("ADD")
	spark:SetSize(gladius and source:GetHeight() * 2 or 32, gladius and source:GetHeight() * 2 or 32)
	spark:SetPoint("CENTER", bar, "LEFT", source:GetWidth() * 0.65, 0)
	if gladius then
		bar._suiGladiusSpark = spark
		bar:HookScript("OnUpdate", function(self) module:UpdateGladiusSpark(self) end)
		bar:HookScript("OnSizeChanged", function(self) module:UpdateGladiusSpark(self) end)
		module:UpdateGladiusSpark(bar)
	end

	bar:Hide()
	arenaTestCastbars[id] = bar
	return bar
end

local function EnsureTestPlayerClick(frame)
	if arenaTestPlayerClick then return arenaTestPlayerClick end
	local button = CreateFrame("Button", "SarychUIArenaTestPlayerClick", frame,
		"SecureActionButtonTemplate")
	button:SetAllPoints(frame)
	button:SetFrameLevel(frame:GetFrameLevel() + 20)
	button:RegisterForClicks("AnyUp")
	button:SetAttribute("unit", "player")
	button:SetAttribute("type1", "target")
	button:SetAttribute("type2", "focus")
	button:Hide()
	arenaTestPlayerClick = button
	return button
end

local function RestoreClassicTestHealth(frame)
	local bar = frame and frame.healthbar
	if not bar or not bar._suiClassicTestFill then return end
	bar._suiClassicTestFill:Hide()
	if bar._suiClassicTestNative then bar._suiClassicTestNative:SetAlpha(1) end
	local native = bar:GetStatusBarTexture()
	if native then native:SetAlpha(1) end
end

local function ColorClassicTestHealth(frame, class)
	local bar = frame and frame.healthbar
	if not bar then return end
	local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if not color then
		RestoreClassicTestHealth(frame)
		SarychUI.UnitFrameLayers:SetBarColor(frame, bar, 0, 1, 0)
		return
	end
	local native = bar:GetStatusBarTexture()
	if not native then return end
	local fill = bar._suiClassicTestFill
	if not fill then
		fill = bar:CreateTexture(nil, "ARTWORK")
		bar._suiClassicTestFill = fill
	end
	if bar._suiClassicTestNative ~= native then
		if bar._suiClassicTestNative then bar._suiClassicTestNative:SetAlpha(1) end
		fill:ClearAllPoints()
		fill:SetAllPoints(native)
		bar._suiClassicTestNative = native
	end
	local texture = native:GetTexture()
	if fill._suiSourceTexture ~= texture then
		fill:SetTexture(texture)
		fill._suiSourceTexture = texture
	end
	SarychUI.UnitFrameLayers:SetRangeTextureColor(frame, fill,
		color.r, color.g, color.b, 1)
	fill:Show()
	SarychUI.UnitFrameLayers:SetBarColor(frame, bar, color.r, color.g, color.b)
	native:SetAlpha(0)
end

local function UpdateClassicTestVisuals()
	local testing = arenaTestContainer and arenaTestContainer:IsShown() and not GladiusIcons()
	local first = arenaTestFrames[1]
	if not testing or not first or not first:IsVisible() then return end
	-- Use Blizzard's existing arena pet frame and its original artwork.
	local pet = first.petFrame or _G[first:GetName() .. "PetFrame"]
	classicTestPet = pet
	local petExists = UnitExists("pet")
	local maximum = petExists and UnitHealthMax("pet") or 0
	local percent = maximum > 0 and math.floor(UnitHealth("pet") / maximum * 100 + 0.5) or 100
	if pet then
		if not pet:IsShown() then securecall(pet.Show, pet) end
		pet:SetAlpha(1)
		local prefix = pet:GetName()
		local health = pet.healthbar or (prefix and _G[prefix .. "HealthBar"])
		local power = pet.manabar or (prefix and _G[prefix .. "ManaBar"])
		local name = pet.name or (prefix and _G[prefix .. "Name"])
		local portrait = pet.portrait or (prefix and _G[prefix .. "Portrait"])
		if health then
			health:SetMinMaxValues(0, 100)
			health:SetValue(percent)
			health:SetStatusBarColor(0, 1, 0)
		end
		if power then
			local maxPower = petExists and UnitManaMax("pet") or 100
			power:SetMinMaxValues(0, math.max(1, maxPower or 100))
			power:SetValue(petExists and UnitMana("pet") or 35)
		end
		if name then name:SetText((petExists and UnitName("pet")) or "Питомец") end
		if portrait then
			if petExists and SetPortraitTexture then SetPortraitTexture(portrait, "pet")
			elseif portrait.SetTexture then portrait:SetTexture([[Interface\Icons\Ability_Hunter_Pet_Bear]]) end
		end
	end
	if first.healthbar then
		local maxHealth = math.max(1, UnitHealthMax("player") or 1)
		first.healthbar:SetMinMaxValues(0, maxHealth)
		first.healthbar:SetValue(UnitHealth("player") or maxHealth)
	end
	if first.manabar then
		local maxPower = math.max(1, UnitManaMax("player") or 1)
		first.manabar:SetMinMaxValues(0, maxPower)
		first.manabar:SetValue(UnitMana("player") or 0)
	end
	local db = GetDB()
	for i = 1, (db and db.testMode or 0) do
		local frame = arenaTestFrames[i]
		local class = module:GetTestArenaClass(i)
		if frame and frame:IsVisible() then
			if i ~= 5 then ColorClassicTestHealth(frame, class) end
			if i == 5 and frame.healthbar then
				frame.healthbar:SetValue(0)
				if frame.healthbar._suiClassicTestFill then frame.healthbar._suiClassicTestFill:Hide() end
				local native = frame.healthbar:GetStatusBarTexture()
				if native then native:SetAlpha(0) end
			end
		end
	end
end

local classicDeathIcons = {}
local arenaCombatIcons = {}
local classicSpecIcons = {}

function module:HideClassicSpecVisuals()
	for _, icon in pairs(classicSpecIcons) do
		if icon.texture then icon.texture:Hide() end
		if icon._frame then
			icon._frame._suiClassicSpecTexture = nil
			icon._frame._suiClassicPortraitTexture = nil
		end
		icon:Hide()
	end
end

function module:UpdateClassicSpecVisuals()
	local db = GetDB()
	local style = db and db.enabled and db.frameType == "classic"
		and self:GetStyleSettings("classic")
	local inArena = select(2, IsInInstance()) == "arena"
	local testing = not inArena and arenaTestContainer and arenaTestContainer:IsShown()
		and db and (db.testMode or 0) > 0
	local enabled = style and style.showSpecText == true and (inArena or testing)
	local tr = db and db.Trinkets or {}
	local iconColumn = tr.enabled and self:IsArenaRacialEnabled() and tr.layout == "COLUMN"
	for i = 1, (MAX_ARENA_ENEMIES or 5) do
		local frame = _G["ArenaEnemyFrame" .. i]
		local unit = "arena" .. i
		local portrait = frame and (frame.classPortrait
			or (frame.GetName and _G[(frame:GetName() or "") .. "ClassPortrait"]))
		local icon = classicSpecIcons[i]
		local testSlot = testing and i <= db.testMode
		local deadTest = testSlot and self:IsArenaOpponentDead(i, true)
		local shown = style and frame and portrait and frame:IsVisible()
			and (testSlot or (inArena and UnitExists(unit)))
		local spec, class
		if shown then
			if testing then
				class = self:GetTestArenaClass(i)
				if enabled and not deadTest then spec = self:GetTestArenaSpec(i) end
			else
				_, class = UnitClass(unit)
				if enabled then spec = self:GetArenaSpec(unit) end
			end
		end
		local specTexture = spec and class and self:GetArenaSpecIcon(class, spec)
		local texture = specTexture or (class and CLASS_ICON_TCOORDS
			and CLASS_ICON_TCOORDS[class] and [[Interface\TargetingFrame\UI-Classes-Circles]])
		if texture and not icon then
			-- Paint on the portrait's parent, above Blizzard's portrait but inside its border.
			icon = CreateFrame("Frame", nil, UIParent)
			icon:SetFrameStrata("HIGH")
			icon:EnableMouse(false)
			icon.label = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			icon.label:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
			icon.label:SetPoint("BOTTOM", icon, "TOP", 0, 2)
			icon.label:SetWidth(110)
			icon.label:SetJustifyH("CENTER")
			local r, g, b, a = icon.label:GetTextColor()
			SarychUI.UnitFrameLayers:SetTextColor(frame, icon.label, r, g, b, a)
			icon:Hide()
			classicSpecIcons[i] = icon
		end
		if icon then
			if texture then
				if icon._portrait ~= portrait or icon._portraitParent ~= portrait:GetParent() then
					if icon.texture then icon.texture:Hide() end
					icon.texture = portrait:GetParent():CreateTexture(nil, "ARTWORK", nil, 1)
					icon.texture:SetPoint("TOPLEFT", portrait, "TOPLEFT", 2, -2)
					icon.texture:SetPoint("BOTTOMRIGHT", portrait, "BOTTOMRIGHT", -2, 2)
					icon._portraitParent = portrait:GetParent()
					icon._portrait = portrait
					icon._frame = frame
					icon._texture = nil
				end
				-- Follow the native portrait layer: aura tracking lowers it beneath its BORDER icon.
				local layer, sublevel = portrait:GetDrawLayer()
				icon.texture:SetDrawLayer(layer, math.min(7, (sublevel or 0) + 1))
				local textureKey = specTexture and ("spec:" .. specTexture) or ("class:" .. class)
				if icon._texture ~= textureKey then
					if specTexture and SetPortraitToTexture then
						SetPortraitToTexture(icon.texture, specTexture)
					else
						icon.texture:SetTexture(texture)
						if specTexture then icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
						else icon.texture:SetTexCoord(unpack(CLASS_ICON_TCOORDS[class])) end
					end
					icon._texture = textureKey
				end
				icon.texture:Show()
				frame._suiClassicPortraitTexture = icon.texture
				frame._suiClassicSpecTexture = specTexture and icon.texture or nil
				local scale = GetArenaIconScale(frame, 1)
				if icon:GetScale() ~= scale then icon:SetScale(scale) end
				icon:SetSize(portrait:GetWidth(), portrait:GetHeight())
				if icon._anchor ~= portrait then
					icon:ClearAllPoints()
					icon:SetPoint("CENTER", portrait, "CENTER", 0, 0)
					icon._anchor = portrait
				end
				if icon._columnLabel ~= iconColumn then
					icon.label:ClearAllPoints()
					if iconColumn then
						icon.label:SetPoint("BOTTOMRIGHT", icon, "TOPRIGHT", 0, 2)
						icon.label:SetJustifyH("RIGHT")
					else
						icon.label:SetPoint("BOTTOM", icon, "TOP", 0, 2)
						icon.label:SetJustifyH("CENTER")
					end
					icon._columnLabel = iconColumn
				end
				if icon._spec ~= spec then icon.label:SetText(spec or ""); icon._spec = spec end
				if icon:GetAlpha() ~= frame:GetAlpha() then icon:SetAlpha(frame:GetAlpha()) end
				if specTexture then icon:Show() else icon:Hide() end
			else
				if frame then
					frame._suiClassicSpecTexture = nil
					frame._suiClassicPortraitTexture = nil
				end
				if icon.texture then icon.texture:Hide() end
				icon:Hide()
			end
		end
	end
end

function module:HideArenaCombatIndicators()
	for _, icon in pairs(arenaCombatIcons) do
		icon:Hide()
		icon.pulse:Stop()
		icon.glow:SetAlpha(0)
	end
end

function module:UpdateArenaCombatIndicators()
	local db = GetDB()
	local inArena = select(2, IsInInstance()) == "arena"
	local testing = not inArena and arenaTestContainer and arenaTestContainer:IsShown()
		and db and (db.testMode or 0) > 0
	local enabled = db and db.enabled and db.showCombatIndicator == true
		and (inArena or testing)
	local frameDB = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
		and SarychUI.db.profile.modules.frame
	local size = 26 * (tonumber(frameDB and frameDB.combatIndicatorScale) or 0.85)
	for i = 1, (MAX_ARENA_ENEMIES or 5) do
		local icon = arenaCombatIcons[i]
		local frame = _G["ArenaEnemyFrame" .. i]
		local unit = "arena" .. i
		local show = enabled and frame and frame.healthbar and frame:IsVisible()
			and not self:IsArenaOpponentDead(i, testing)
			and (testing or (UnitExists(unit) and UnitAffectingCombat(unit)))
		if show and not icon then
			-- Use the same artwork and pulse as Frames > Combat Indicator.
			icon = CreateFrame("Frame", nil, UIParent)
			icon:SetFrameStrata("HIGH")
			icon:EnableMouse(false)
			icon.texture = icon:CreateTexture(nil, "BORDER")
			icon.texture:SetAllPoints()
			icon.texture:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
			icon.texture:SetTexCoord(0.5, 1, 0, 0.48)
			icon.glow = icon:CreateTexture(nil, "OVERLAY")
			icon.glow:SetAllPoints()
			icon.glow:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
			icon.glow:SetTexCoord(0.5, 1, 0.5, 1)
			icon.glow:SetBlendMode("ADD")
			icon.glow:SetAlpha(0)
			icon.pulse = icon.glow:CreateAnimationGroup()
			icon.pulse:SetLooping("REPEAT")
			local fadeIn = icon.pulse:CreateAnimation("Alpha")
			fadeIn:SetOrder(1)
			fadeIn:SetDuration(0.5)
			fadeIn:SetChange(1)
			local fadeOut = icon.pulse:CreateAnimation("Alpha")
			fadeOut:SetOrder(2)
			fadeOut:SetDuration(0.5)
			fadeOut:SetChange(-1)
			icon:Hide()
			arenaCombatIcons[i] = icon
		end
		if icon then
			if show then
				icon:SetFrameLevel(frame.healthbar:GetFrameLevel() + 4)
				icon:SetSize(size, size)
				local scale = GetArenaIconScale(frame, 1)
				if icon:GetScale() ~= scale then icon:SetScale(scale) end
				if icon._anchor ~= frame.healthbar then
					icon:ClearAllPoints()
					icon:SetPoint("CENTER", frame.healthbar, "CENTER", 0, 0)
					icon._anchor = frame.healthbar
				end
				if icon:GetAlpha() ~= frame:GetAlpha() then icon:SetAlpha(frame:GetAlpha()) end
				if not icon:IsShown() then icon:Show(); icon.pulse:Play() end
			else
				if icon:IsShown() then icon:Hide(); icon.pulse:Stop(); icon.glow:SetAlpha(0) end
			end
		end
	end
end

local function UpdateClassicDeathVisuals()
	local db = GetDB()
	if not db or not db.enabled or db.frameType ~= "classic" then
		for _, icon in pairs(classicDeathIcons) do icon:Hide() end
		return
	end
	local testing = arenaTestContainer and arenaTestContainer:IsShown()
		and (db.testMode or 0) > 0 and select(2, IsInInstance()) ~= "arena"
	for i = 1, (MAX_ARENA_ENEMIES or 5) do
		local frame = _G["ArenaEnemyFrame" .. i]
		local icon = classicDeathIcons[i]
		if frame and frame.healthbar and not icon then
			-- Keep the skull outside the faded arena frame hierarchy.
			icon = CreateFrame("Frame", nil, UIParent)
			icon:SetFrameStrata("HIGH")
			icon:SetFrameLevel(frame.healthbar:GetFrameLevel() + 4)
			icon:SetSize(20, 22)
			icon:SetPoint("CENTER", frame.healthbar, "CENTER", 0, 0)
			icon:EnableMouse(false)
			local skull = icon:CreateTexture(nil, "ARTWORK")
			skull:SetAllPoints()
			skull:SetTexture([[Interface\AddOns\SarychUI\media\arena\TournamentOrganizer.blp]])
			skull:SetTexCoord(0, 0.058, 0.295, 0.359)
			icon:Hide()
			classicDeathIcons[i] = icon
		end
		if icon then
			local dead = frame and frame:IsVisible() and module:IsArenaOpponentDead(i, testing)
			if dead then icon:Show() else icon:Hide() end
		end
	end
end

local function EnsureClassicTestTicker()
	if classicTestTicker then return end
	local ticker = CreateFrame("Frame", nil, UIParent)
	ticker.elapsed = 0
	ticker:SetScript("OnUpdate", function(self, elapsed)
		self.elapsed = self.elapsed + elapsed
		if self.elapsed < 0.1 then return end
		self.elapsed = 0
		UpdateClassicTestVisuals()
		UpdateClassicDeathVisuals()
	end)
	classicTestTicker = ticker
end

function module:HideArenaEnemyFrames()
	local wasTesting = arenaTestContainer and arenaTestContainer:IsShown()
	if arenaTestContainer then arenaTestContainer:Hide() end
	if wasTesting and select(2, IsInInstance()) ~= "arena" and UnregisterArenaRangeFrames then
		UnregisterArenaRangeFrames()
	end
	if self.Diminishings then self.Diminishings:Refresh() end
	if self.ProcTrinkets then self.ProcTrinkets:Refresh() end
	if arenaTestPlayerClick then arenaTestPlayerClick:Hide() end
	self:ResetArenaAppearance()
	for i = 1, 5 do
		if arenaTestFrames[i] then arenaTestFrames[i]:SetAlpha(1) end
		RestoreClassicTestHealth(arenaTestFrames[i])
		if arenaTestCastbars[i] then
			arenaTestCastbars[i]:SetAlpha(1)
			arenaTestCastbars[i]:Hide()
		end
		for _, suffix in ipairs({ "Trinket1", "Racial" }) do
			local icon = _G["SarychUIArenaTestTrinket" .. i .. suffix]
			if icon then icon:SetAlpha(1); icon:Hide() end
		end
	end
	if wasTesting and not (InCombatLockdown and InCombatLockdown()) then
		for i = 1, 5 do
			local frame = arenaTestFrames[i]
			if frame and securecall then
				if ArenaEnemyFrame_UpdatePlayer then securecall("ArenaEnemyFrame_UpdatePlayer", frame) end
				if select(2, IsInInstance()) ~= "arena" then
					securecall(frame.Hide, frame)
				end
			end
		end
		if ArenaEnemyFrames and securecall then
			if select(2, IsInInstance()) == "arena" and ArenaEnemyFrames_UpdateVisible then
				securecall("ArenaEnemyFrames_UpdateVisible")
			else
				securecall(ArenaEnemyFrames.Hide, ArenaEnemyFrames)
			end
		end
	end
	local abilities = SarychUI.extensions and SarychUI.extensions.party_abilities
	if abilities and abilities.RefreshConfig then abilities:RefreshConfig() end
	if SarychUI.DragMode then
		SarychUI.DragMode:RefreshDragOverlay("arenaContainer")
	end
	self:ApplyFrameSpacing()
	UpdateClassicDeathVisuals()
	if GladiusIcons() and self.UpdateGladiusVisuals then self:UpdateGladiusVisuals() end
end

function module:GetVisibleTestFrame(index)
	local frame = arenaTestFrames[index]
	if arenaTestContainer and arenaTestContainer:IsShown() and frame and frame:IsVisible() then
		return frame
	end
end

function module:GetAbilityAnchor(index, test, side)
	if side == "LEFT" then
		local frame = test and self:GetVisibleTestFrame(index) or _G["ArenaEnemyFrame" .. index]
		local db = GetDB()
		if db and db.frameType == "gladius" and frame then
			local name = frame.GetName and frame:GetName()
			return frame.classPortrait or (name and _G[name .. "ClassPortrait"]) or frame
		end
		return frame
	end
	local db = GetDB()
	local tr = db and db.Trinkets or {}
	if db and db.frameType == "gladius" and self:GetGladiusPrimaryContent() == "procTrinkets" then
		local frame = test and self:GetVisibleTestFrame(index) or _G["ArenaEnemyFrame" .. index]
		local count = (tr.enabled and 1 or 0) + 2
		if frame then return frame, 6 + count * 40 + (count - 1) end
	end
	if db and db.frameType == "classic" and self:GetClassicPrimaryContent() == "procTrinkets" then
		local frame = test and self:GetVisibleTestFrame(index) or _G["ArenaEnemyFrame" .. index]
		local prefix = test and "SarychUIArenaTestTrinket" .. index or "arena" .. index
		local first = test and _G[prefix .. "Trinket1"] or self.Trinkets[prefix .. "Trinket1"]
		local scale = tonumber(tr.scale) or 1
		local gap = tonumber(db.procTrinkets and db.procTrinkets.spacing) or tonumber(tr.spacing) or 5
		local width = (db.procTrinkets and db.procTrinkets.layout == "COLUMN" and 26 or 52 + gap) * scale
		if first and first:IsShown() then return first, (gap * scale + width) end
		if frame then return frame, 2 + width end
	end
	local anchor
	local column = db and db.frameType == "classic" and tr.layout == "COLUMN"
	local pairedRacial
	local racialEnabled = self:IsArenaRacialEnabled()
	if tr.enabled and racialEnabled then
		for slot = 1, (MAX_ARENA_ENEMIES or 5) do
			local frame = test and self:GetVisibleTestFrame(slot) or _G["ArenaEnemyFrame" .. slot]
			local prefix = test and "SarychUIArenaTestTrinket" .. slot or "arena" .. slot
			local first = test and _G[prefix .. "Trinket1"] or self.Trinkets[prefix .. "Trinket1"]
			local second = test and _G[prefix .. "Racial"] or self.Trinkets[prefix .. "Trinket2"]
			if frame and (test or UnitExists("arena" .. slot))
				and first and first:IsShown() and second and second:IsShown() then
				pairedRacial = second
				break
			end
		end
	end
	if column and pairedRacial then
		-- Reserve the same column width for every opponent, including Humans.
		local frame = test and self:GetVisibleTestFrame(index) or _G["ArenaEnemyFrame" .. index]
		local scale = tonumber(tr.scale) or 1
		if frame then return frame, 28 * scale, -2 * scale end
	end
	if test then
		if racialEnabled and not (column and tr.enabled) then
			anchor = _G["SarychUIArenaTestTrinket" .. index .. "Racial"]
		end
		if not (anchor and anchor:IsShown()) and tr.enabled then
			anchor = _G["SarychUIArenaTestTrinket" .. index .. "Trinket1"]
		end
		if not (anchor and anchor:IsShown()) and racialEnabled then
			anchor = _G["SarychUIArenaTestTrinket" .. index .. "Racial"]
		end
	else
		local prefix = "arena" .. index
		if racialEnabled and not (column and tr.enabled) then
			anchor = self.Trinkets[prefix .. "Trinket2"]
		end
		if not (anchor and anchor:IsShown()) and tr.enabled then
			anchor = self.Trinkets[prefix .. "Trinket1"]
		end
		if not (anchor and anchor:IsShown()) and racialEnabled then
			anchor = self.Trinkets[prefix .. "Trinket2"]
		end
	end
	if anchor and anchor:IsShown() then
		local first = test and _G["SarychUIArenaTestTrinket" .. index .. "Trinket1"]
			or self.Trinkets["arena" .. index .. "Trinket1"]
		if pairedRacial and anchor == first then
			local frame = test and self:GetVisibleTestFrame(index) or _G["ArenaEnemyFrame" .. index]
			local frameScale = frame and frame:GetEffectiveScale() or 1
			local racialScale = pairedRacial:GetEffectiveScale()
			local spacing = GladiusIcons() and 1 or (tonumber(tr.spacing) or 5)
			return anchor, (pairedRacial:GetWidth() + spacing) * racialScale / frameScale
		end
		return anchor
	end
	return test and self:GetVisibleTestFrame(index) or _G["ArenaEnemyFrame" .. index]
end

function module:UpdateTrinketArrangement()
	for index = 1, MAX_ARENA_ENEMIES or 5 do
		local frame = _G["ArenaEnemyFrame" .. index]
		if frame then
			local prefix = "arena" .. index
			local trinket = self.Trinkets[prefix .. "Trinket1"]
			local racial = self.Trinkets[prefix .. "Trinket2"]
			if trinket then PlaceArenaIcon(trinket, frame, nil,
				racial and racial:IsShown()) end
			if racial then PlaceArenaIcon(racial, frame,
				trinket and trinket:IsShown() and trinket or nil) end
			local testTrinket = _G["SarychUIArenaTestTrinket" .. index .. "Trinket1"]
			local testRacial = _G["SarychUIArenaTestTrinket" .. index .. "Racial"]
			if testTrinket then PlaceArenaIcon(testTrinket, frame, nil,
				testRacial and testRacial:IsShown()) end
			if testRacial then PlaceArenaIcon(testRacial, frame,
				testTrinket and testTrinket:IsShown() and testTrinket or nil) end
		end
	end
	self:ApplyFrameSpacing()
	if self.Diminishings then self.Diminishings:Refresh() end
	if self.ProcTrinkets then self.ProcTrinkets:Refresh() end
	local abilities = SarychUI.extensions and SarychUI.extensions.party_abilities
	if abilities and abilities.Render then abilities:Render() end
	local preview = SarychUI.PartyAbilitiesPreview
	if preview and preview.RefreshAll then preview:RefreshAll() end
end

function module:Test(numOpponents)
	numOpponents = tonumber(numOpponents)
	if not numOpponents or numOpponents < 1 or numOpponents > 5 then return false end
	if InCombatLockdown and InCombatLockdown() then return false end
	if select(2, IsInInstance()) == "arena" then return false end
	if not EnsureArenaTestFrames() or not securecall then return false end

	self:InitializeContainer()
	self:ApplyContainerPosition()
	self:ApplyFrameSpacing()
	if self.ApplyGladiusStyle then self:ApplyGladiusStyle() end
	if ArenaEnemyFrames then securecall(ArenaEnemyFrames.Show, ArenaEnemyFrames) end
	for i = 1, 5 do
		local frame = arenaTestFrames[i]
		local castbar = EnsureTestCastbar(i)
		if frame and i <= numOpponents then
			frame:SetAlpha(1)
			if castbar then castbar:SetAlpha(1) end
			if ArenaEnemyFrame_SetMysteryPlayer then securecall("ArenaEnemyFrame_SetMysteryPlayer", frame) end
			if ArenaEnemyFrame_Unlock then securecall("ArenaEnemyFrame_Unlock", frame) end
			if frame.name then frame.name:SetText(self:GetTestArenaName(i)) end
			local class = self:GetTestArenaClass(i)
			if frame.classPortrait then
				if GetSetting("frameType", "classic") == "gladius" and CLASS_BUTTONS and CLASS_BUTTONS[class] then
					frame.classPortrait:SetTexture([[Interface\Glues\CharacterCreate\UI-CharacterCreate-Classes]])
					frame.classPortrait:SetTexCoord(unpack(CLASS_BUTTONS[class]))
				elseif CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class] then
					frame.classPortrait:SetTexture([[Interface\TargetingFrame\UI-Classes-Circles]])
					frame.classPortrait:SetTexCoord(unpack(CLASS_ICON_TCOORDS[class]))
				end
			end
			if frame.healthbar and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
				local color = RAID_CLASS_COLORS[class]
				SarychUI.UnitFrameLayers:SetBarColor(frame, frame.healthbar, color.r, color.g, color.b)
			end
			if i == 1 then
				local click = EnsureTestPlayerClick(frame)
				click:Show()
			end
			securecall(frame.Show, frame)
			if castbar then
				if GladiusIcons() and i == 5 then castbar:Hide() else castbar:Show() end
			end
		else
			if frame then securecall(frame.Hide, frame) end
			if i == 1 and arenaTestPlayerClick then arenaTestPlayerClick:Hide() end
			if castbar then castbar:Hide() end
			for _, suffix in ipairs({ "Trinket1", "Racial" }) do
				local icon = _G["SarychUIArenaTestTrinket" .. i .. suffix]
				if icon then icon:Hide() end
			end
		end
	end
	arenaTestContainer:Show()
	if not arenaTestFrames[1]:IsVisible() then
		self:HideArenaEnemyFrames()
		return false
	end
	if RegisterArenaRangeFrames then RegisterArenaRangeFrames() end
	if not GladiusIcons() then EnsureClassicTestTicker() end
	UpdateClassicTestVisuals()
	if not GladiusIcons() then UpdateClassicDeathVisuals() end
	local db = GetDB()
	if db and db.Trinkets then self:ShowTestTrinkets(numOpponents, db.Trinkets) end
	local abilities = SarychUI.extensions and SarychUI.extensions.party_abilities
	if abilities and abilities.RefreshConfig then abilities:RefreshConfig() end
	if SarychUI.DragMode then
		SarychUI.DragMode:RefreshDragOverlay("arenaContainer")
	end
	if GladiusIcons() and self.UpdateGladiusVisuals then self:UpdateGladiusVisuals() end
	self:UpdateArenaAppearance()
	if self.Diminishings then self.Diminishings:Refresh() end
	if self.ProcTrinkets then self.ProcTrinkets:Refresh() end
	
	return true
end

local function StartTestIconCooldown(icon, duration)
	if not icon or not icon.Cooldown then return end
	icon._testDuration = duration
	local now = GetTime()
	if icon._cooldownEnd and now < icon._cooldownEnd then return end
	if icon._cooldownEnd then
		icon._cooldownEnd = nil
		icon._testReadyUntil = now + 5
		CooldownFrame_SetTimer(icon.Cooldown, 0, 0, 0)
		if SarychUI_NotifyCooldown then
			SarychUI_NotifyCooldown(icon.Cooldown, 0, 0, 0)
		end
		UpdateArenaIconCooldownColor(icon, false, now)
		return
	end
	if icon._testReadyUntil and now < icon._testReadyUntil then return end
	icon._testReadyUntil = nil
	local start = now - duration * 0.25
	icon._testStart = start
	icon._cooldownEnd = start + duration
	CooldownFrame_SetTimer(icon.Cooldown, start, duration, 1)
	if SarychUI_NotifyCooldown then
		SarychUI_NotifyCooldown(icon.Cooldown, start, duration, 1)
	end
	local db = GetDB()
	UpdateArenaIconCooldownColor(icon,
		db and db.Trinkets and db.Trinkets.desaturateOnCooldown == true, now)
end

-- Show trinket and racial icons for test mode
function module:ShowTestTrinkets(numOpponents, trinketsDB)
	if not trinketsDB then return end
	if InCombatLockdown() then return end
	if not arenaTestContainer or not arenaTestContainer:IsShown() then return end
	
	local trinketsEnabled = trinketsDB.enabled == true
	local racialEnabled = self:IsArenaRacialEnabled()
	local gladius = GladiusIcons()
	local scale = gladius and 1 or (trinketsDB.scale or 1.0)
	
	local hordeTrinketTexture = TrinketData.hordeTexture
	local racialTexture = racialSpells.Orc.icon
	
	for i = 1, numOpponents do
		local frame = arenaTestFrames[i]
		if not frame then break end
		local iconScale = GetArenaIconScale(frame, scale)
		local human = i <= 2
		local showRacial = racialEnabled and not human
		
		-- Handle trinket icon
		local trinket = self:GetOrCreateTestTrinket(frame, i, "Trinket1")
		if trinket then
			trinket:SetSize(gladius and 40 or 26, gladius and 41 or 26)
			PlaceArenaIcon(trinket, frame, nil, trinketsEnabled and showRacial)
			if trinketsEnabled then
				trinket:SetScale(iconScale)
				trinket.Icon.Texture:SetTexture(human and racialSpells.Human.icon or hordeTrinketTexture)
				trinket.Icon:Show()
				trinket:Show()
				StartTestIconCooldown(trinket, 45)
			else
				-- Hide if disabled
				trinket:Hide()
				if trinket.Icon then
					trinket.Icon:Hide()
				end
			end
		end
		
		-- Handle racial icon
		-- Если тринкеты включены, расовая позиционируется справа от тринкета
		-- Если тринкеты выключены, расовая позиционируется на месте тринкета
		local racial = self:GetOrCreateTestTrinket(frame, i, "Racial", nil)
		if racial then
			racial:SetSize(gladius and 40 or 26, gladius and 41 or 26)
			if showRacial then
				racial:SetScale(iconScale)
				racial.Icon.Texture:SetTexture(racialTexture)
				racial.Icon:Show()
				racial:Show()
				StartTestIconCooldown(racial, 90)
				
				-- Перепозиционируем расовую в зависимости от состояния тринкетов
				PlaceArenaIcon(racial, frame, trinketsEnabled and trinket or nil)
			else
				-- Hide if disabled
				racial:Hide()
				if racial.Icon then
					racial.Icon:Hide()
				end
			end
		end
	end
end

-- Get or create test trinket icon
function module:GetOrCreateTestTrinket(frame, id, suffix, anchorFrame)
	if not frame then return nil end
	
	local trinketName = "SarychUIArenaTestTrinket" .. id .. suffix
	local trinket = _G[trinketName]
	
	if not trinket then
		-- Keep preview icons out of Blizzard's protected button hierarchy.
		trinket = CreateFrame("Frame", trinketName, UIParent)
		trinket:SetFrameLevel(frame:GetFrameLevel() + 3)
		trinket:SetSize(26, 26)
		
		-- Position
		if anchorFrame then
			trinket:SetPoint("LEFT", anchorFrame, "RIGHT", 5, 0)
		else
			trinket:SetPoint("LEFT", frame, "RIGHT", 2, -2)
		end
		
		-- Icon frame
		trinket.Icon = CreateFrame("Frame", nil, trinket)
		trinket.Icon:SetFrameLevel(trinket:GetFrameLevel() - 1)
		trinket.Icon:SetAllPoints()
		
		-- Texture
		trinket.Icon.Texture = trinket.Icon:CreateTexture(nil, "BORDER")
		trinket.Icon.Texture:SetAllPoints(trinket)
		trinket.Icon.Texture:SetTexCoord(0, 1, 0, 1)
		trinket.Cooldown = CreateFrame("Cooldown", nil, trinket, "CooldownFrameTemplate")
		trinket.Cooldown:SetAllPoints(trinket)
		trinket.Cooldown:SetFrameLevel(trinket:GetFrameLevel() + 1)
		trinket.Cooldown:SetAlpha(0.65)
		trinket.Cooldown.__sary_arenaTrinket = true
		if trinket.Cooldown.SetDrawEdge then trinket.Cooldown:SetDrawEdge(true) end
		trinket.Cooldown:Hide()
		trinket:SetScript("OnUpdate", function(self, elapsed)
			if self:IsShown() and self._testDuration then
				self._testTick = (self._testTick or 0) + elapsed
				if self._testTick >= 0.2 then
					self._testTick = 0
					StartTestIconCooldown(self, self._testDuration)
				end
			end
		end)
		
		-- Enable mouse for testing
		trinket:EnableMouse(true)
		trinket:SetMovable(true)
	end
	
	return trinket
end

-- ============================================
-- Arena death and combat appearance; range is owned by UnitFrameRange.
-- ============================================

local arenaGUIDBySlot = {}
local deadGUIDBySlot = {}
local deathCastHidden = setmetatable({}, { __mode = "k" })
local DEAD_ALPHA = 0.40
local SOLID_BG = [[Interface\Buttons\WHITE8X8]]
-- EasyGlyph-style strips, but for a rounded rectangle (not a full circle).
local ROUND_STRIPS = 48
local ROUND_CORNER = 5

local function GetArenaClassPortrait(frame)
	return frame and (frame.classPortrait or (frame.GetName and _G[frame:GetName() .. "ClassPortrait"]))
end

local function EnsureUnderlayHolder(frame)
	local holder = frame._suiUnderlayHolder
	if not holder then
		holder = CreateFrame("Frame", nil, UIParent)
		holder:EnableMouse(false)
		frame._suiUnderlayHolder = holder
	end
	holder:SetFrameStrata(frame:GetFrameStrata() or "MEDIUM")
	local level = (frame:GetFrameLevel() or 1) - 1
	if level < 0 then level = 0 end
	holder:SetFrameLevel(level)
	holder:ClearAllPoints()
	holder:SetAllPoints(frame)
	holder:SetAlpha(1)
	holder:Show()
	return holder
end

-- Legacy underlays are hidden when arena appearance refreshes.
local function EnsureBarUnderlay(region, frame, r, g, b)
	if not region or not frame then return end
	local holder = EnsureUnderlayHolder(frame)
	local bg = region._suiBarUnderlay
	if not bg then
		bg = holder:CreateTexture(nil, "BACKGROUND")
		region._suiBarUnderlay = bg
	end
	bg:ClearAllPoints()
	bg:SetAllPoints(region)
	bg:SetTexture(SOLID_BG)
	bg:SetVertexColor(r, g, b, 1)
	bg:SetAlpha(1)
	bg:Show()
	return bg
end

local function HideRoundedUnderlay(region)
	local strips = region and region._suiRoundUnderlay
	if not strips then return end
	for i = 1, #strips do strips[i]:Hide() end
end

local function EnsureRoundedUnderlay(region, frame, r, g, b)
	if not region or not frame then return end
	local holder = EnsureUnderlayHolder(frame)
	local strips = region._suiRoundUnderlay
	if not strips then
		strips = {}
		for i = 1, ROUND_STRIPS do
			strips[i] = holder:CreateTexture(nil, "BACKGROUND")
		end
		region._suiRoundUnderlay = strips
	end
	local width = region:GetWidth() or 0
	local height = region:GetHeight() or 0
	if width <= 0 or height <= 0 then return end
	local radius = math.min(ROUND_CORNER, width / 2, height / 2)
	if region._suiRoundUnderlayW == width and region._suiRoundUnderlayH == height
		and region._suiRoundUnderlayRadius == radius then
		for i = 1, ROUND_STRIPS do
			strips[i]:SetVertexColor(r, g, b, 1)
			strips[i]:SetAlpha(1)
			strips[i]:Show()
		end
		return
	end
	local halfW, halfH = width / 2, height / 2
	local flat = halfH - radius
	for i = 1, ROUND_STRIPS do
		local strip = strips[i]
		local y = ((i - 0.5) / ROUND_STRIPS) * height - halfH
		local halfWidth = halfW
		local ay = math.abs(y)
		if ay > flat then
			local dy = ay - flat
			halfWidth = halfW - radius + math.sqrt(math.max(0, radius * radius - dy * dy))
		end
		strip:ClearAllPoints()
		strip:SetSize(halfWidth * 2, height / ROUND_STRIPS + 0.15)
		strip:SetPoint("CENTER", region, "CENTER", 0, y)
		strip:SetTexture(SOLID_BG)
		strip:SetVertexColor(r, g, b, 1)
		strip:SetAlpha(1)
		strip:Show()
	end
	region._suiRoundUnderlayW = width
	region._suiRoundUnderlayH = height
	region._suiRoundUnderlayRadius = radius
end

local function HideBarUnderlays()
	for i = 1, (MAX_ARENA_ENEMIES or 5) do
		local frame = _G["ArenaEnemyFrame" .. i]
		if frame then
			if frame.healthbar and frame.healthbar._suiBarUnderlay then
				frame.healthbar._suiBarUnderlay:Hide()
			end
			if frame.manabar and frame.manabar._suiBarUnderlay then
				frame.manabar._suiBarUnderlay:Hide()
			end
			local portrait = GetArenaClassPortrait(frame)
			HideRoundedUnderlay(portrait)
			-- Drop leftover full-circle strips from the previous attempt.
			if portrait and portrait._suiCircleUnderlay then
				for i = 1, #portrait._suiCircleUnderlay do
					portrait._suiCircleUnderlay[i]:Hide()
				end
			end
			if frame._suiUnderlayHolder then frame._suiUnderlayHolder:Hide() end
		end
	end
end

local classicFontOriginals = setmetatable({}, { __mode = "k" })
function module:UpdateClassicFontSize(forceOff)
    local db = GetDB()
    local enabled = not forceOff and db and db.enabled and db.frameType == "classic"
    if not enabled then
        for text, font in pairs(classicFontOriginals) do
            text:SetFont(unpack(font))
            classicFontOriginals[text] = nil
        end
        return
    end
    local style = self:GetStyleSettings("classic")
    local size = math.max(6, math.min(20, tonumber(style.fontSize) or 10))
    local function Apply(text)
        if not text or not text.GetFont then return end
        local path, oldSize, flags = text:GetFont()
        if not path then return end
        if not classicFontOriginals[text] then classicFontOriginals[text] = {path, oldSize, flags or ""} end
        if oldSize ~= size then text:SetFont(path, size, flags) end
    end
    for i = 1, MAX_ARENA_ENEMIES or 5 do
        local prefix = "ArenaEnemyFrame" .. i
        local frame = _G[prefix]
        if frame then
            Apply(frame.name or _G[prefix .. "Name"])
            for _, suffix in ipairs({"HealthBar", "ManaBar"}) do
                Apply(_G[prefix .. suffix .. "Text"])
                local bar = _G[prefix .. suffix] or frame[string.lower(suffix)]
                if bar and bar.GetRegions then
                    for _, region in ipairs({bar:GetRegions()}) do Apply(region) end
                end
            end
        end
    end
end

function module:UpdateArenaAppearance()
	if self.UpdateClassicCastShields then self:UpdateClassicCastShields() end
	local db = GetDB()
	if not db or not db.enabled then
		self:UpdateClassicFontSize(true)
		HideBarUnderlays()
		self:UpdateArenaCombatIndicators()
		self:UpdateClassicSpecVisuals()
		return
	end
	local testing = arenaTestContainer and arenaTestContainer:IsShown()
		and (db.testMode or 0) > 0 and select(2, IsInInstance()) ~= "arena"
	local inArena = select(2, IsInInstance()) == "arena"
	if not testing and not inArena then
		HideBarUnderlays()
		self:UpdateArenaCombatIndicators()
		self:UpdateClassicSpecVisuals()
		return
	end
	self:UpdateClassicFontSize()
	HideBarUnderlays()
	for i = 1, (MAX_ARENA_ENEMIES or 5) do
		local frame = _G["ArenaEnemyFrame" .. i]
		if frame then
			local unit = "arena" .. i
			local exists = UnitExists(unit)
			if inArena and exists then
				local guid = UnitGUID(unit)
				if guid then arenaGUIDBySlot[i] = guid end
			end
			local dead = self:IsArenaOpponentDead(i, testing)
			local alpha = dead and DEAD_ALPHA or 1
			local range = SarychUI.UnitFrameRange
			if range then range:SetBaseAlpha(frame, alpha)
			elseif frame:GetAlpha() ~= alpha then frame:SetAlpha(alpha) end
			local effectiveAlpha = frame:GetAlpha()
			local abilities = SarychUI.extensions and SarychUI.extensions.party_abilities
			if abilities and abilities.SyncArenaFrameAppearance then
				abilities:SyncArenaFrameAppearance(frame, effectiveAlpha, dead or not frame:IsVisible())
			end
			if testing then
				local castbar = arenaTestCastbars[i]
				if range then range:ApplyLinkedAlpha(frame, castbar, dead and 0 or 1)
				elseif castbar then castbar:SetAlpha(dead and 0 or effectiveAlpha) end
				for _, suffix in ipairs({ "Trinket1", "Racial" }) do
					local icon = _G["SarychUIArenaTestTrinket" .. i .. suffix]
					if range then range:ApplyLinkedAlpha(frame, icon, dead and 0 or 1)
					elseif icon then icon:SetAlpha(dead and 0 or effectiveAlpha) end
				end
			else
				for _, suffix in ipairs(trinketSuffixes) do
					local icon = self.Trinkets[unit .. suffix]
					if range then range:ApplyLinkedAlpha(frame, icon, dead and 0 or 1)
					elseif icon then icon:SetAlpha(dead and 0 or effectiveAlpha) end
				end
			end
			local cast = _G["ArenaEnemyFrame" .. i .. "CastingBar"]
			if cast then
				if dead then
					deathCastHidden[cast] = true
					if range then range:ApplyLinkedAlpha(frame, cast, 0) else cast:SetAlpha(0) end
				elseif deathCastHidden[cast] then
					if range then range:ApplyLinkedAlpha(frame, cast, 1)
					else cast:SetAlpha(1) end
					deathCastHidden[cast] = nil
				elseif range then range:ApplyLinkedAlpha(frame, cast) end
			end
			local visual = self._gladiusBorders and self._gladiusBorders[i]
			if range and visual then
				range:ApplyLinkedAlpha(frame, visual.target)
				range:ApplyLinkedAlpha(frame, visual.focus)
				range:ApplyLinkedAlpha(frame, visual.death)
				local pet = frame._suiGladiusPet
				if pet then
					range:ApplyLinkedAlpha(frame, pet.target)
					range:ApplyLinkedAlpha(frame, pet.focus)
				end
			end
			local idleBg = frame._suiGladiusCastBackground
			if idleBg then
				local style = self:GetStyleSettings("gladius") or {}
				local backgroundAlpha = dead and 0 or (style.castBarPos == "LEFT" and 0 or 0.3)
				if idleBg:GetAlpha() ~= backgroundAlpha then idleBg:SetAlpha(backgroundAlpha) end
			end
		end
	end
	self:UpdateArenaCombatIndicators()
	self:UpdateClassicSpecVisuals()
end

function module:ResetArenaAppearance()
	if self.UpdateClassicCastShields then self:UpdateClassicCastShields(true) end
	HideBarUnderlays()
	wipe(arenaGUIDBySlot)
	wipe(deadGUIDBySlot)
	for i = 1, (MAX_ARENA_ENEMIES or 5) do
		local frame = _G["ArenaEnemyFrame" .. i]
		if frame then
			if SarychUI.UnitFrameRange then SarychUI.UnitFrameRange:SetBaseAlpha(frame, 1)
			else frame:SetAlpha(1) end
			local abilities = SarychUI.extensions and SarychUI.extensions.party_abilities
			if abilities and abilities.SyncArenaFrameAppearance then
				abilities:SyncArenaFrameAppearance(frame, 1, true)
			end
			if frame._suiGladiusCastBackground then
				local style = self:GetStyleSettings("gladius") or {}
				frame._suiGladiusCastBackground:SetAlpha(style.castBarPos == "LEFT" and 0 or 0.3)
			end
		end
		local cast = _G["ArenaEnemyFrame" .. i .. "CastingBar"]
		if cast and deathCastHidden[cast] then
			cast:SetAlpha(1)
			deathCastHidden[cast] = nil
		end
		for _, suffix in ipairs(trinketSuffixes) do
			local icon = self.Trinkets["arena" .. i .. suffix]
			if icon then icon:SetAlpha(1) end
		end
	end
	self:UpdateArenaCombatIndicators()
	self:UpdateClassicSpecVisuals()
end

function module:IsArenaOpponentDead(index, test)
	index = tonumber(index)
	if not index or index < 1 or index > (MAX_ARENA_ENEMIES or 5) then return false end
	if test then
		local db = GetDB()
		return index == 5 and db and (db.testMode or 0) >= 5 or false
	end
	local unit = "arena" .. index
	local exists = UnitExists(unit)
	local guid = exists and UnitGUID(unit)
	if guid then
		if deadGUIDBySlot[index] and deadGUIDBySlot[index] ~= guid then
			deadGUIDBySlot[index] = nil
		end
		if not UnitIsDeadOrGhost(unit) and UnitHealth(unit) > 0 then
			deadGUIDBySlot[index] = nil
		end
	end
	return (exists and UnitIsDeadOrGhost(unit)) or deadGUIDBySlot[index] ~= nil
end

-- Reused buffer for arena number scans of WorldFrame children.
local worldChildren = {}

local function CollectWorldChildren(...)
	local n = select("#", ...)
	for i = 1, n do
		worldChildren[i] = select(i, ...)
	end
	for i = n + 1, #worldChildren do
		worldChildren[i] = nil
	end
	return n
end

-- Arena-specific death/combat visuals use their own ticker. UnitFrameRange
-- checks distance for all registered frames on one shared ticker.
local arenaRangeRegistered = {}
local arenaRangeOptions = {}

local function GetClassicArenaBorder(frame)
    local name = frame and frame.GetName and frame:GetName()
    if not name then return nil end
    local border = _G[name .. "TextureFrameTexture"] or _G[name .. "Texture"]
    if border then return border end
    local textureFrame = frame.textureFrame or _G[name .. "TextureFrame"]
    if textureFrame then
        for _, region in ipairs({ textureFrame:GetRegions() }) do
            if region.GetTexture and region:GetTexture() then return region end
        end
    end
end

RegisterArenaRangeFrames = function()
	local range = SarychUI.UnitFrameRange
	if not range then return end
	local db = GetDB()
	local testing = db and (db.testMode or 0) > 0 and arenaTestContainer
		and arenaTestContainer:IsShown()
	if select(2, IsInInstance()) ~= "arena" and not testing then return end
	for i = 1, (MAX_ARENA_ENEMIES or 5) do
		local frame = _G["ArenaEnemyFrame" .. i]
		if frame and arenaRangeRegistered[i] ~= frame then
			if arenaRangeRegistered[i] then range:Unregister(arenaRangeRegistered[i]) end
			local options = arenaRangeOptions[i]
			if not options then
				local slot = i
				options = {
					owner = "arena",
					enemy = true,
					colorFade = true,
					colorTextures = function(unitFrame)
						local name = unitFrame.GetName and unitFrame:GetName()
						local portrait = unitFrame.classPortrait or (name and _G[name .. "ClassPortrait"])
						local specIcon = unitFrame.manabar and unitFrame.manabar._suiGladiusSpecIcon
						return portrait, specIcon, unitFrame._suiClassicPortraitTexture,
							GetClassicArenaBorder(unitFrame)
					end,
					wholeFrame = true,
					bar = function(unitFrame)
						return unitFrame.healthbar or unitFrame.healthBar
							or _G[unitFrame:GetName() .. "HealthBar"]
					end,
					enabled = function()
						local db = GetDB()
						return db and db.enabled and db.rangeCheckEnabled ~= false
					end,
					active = function()
						local db = GetDB()
						return select(2, IsInInstance()) == "arena"
							or (db and (db.testMode or 0) > 0 and arenaTestContainer
								and arenaTestContainer:IsShown())
					end,
					testOutside = function()
						local db = GetDB()
						return db and (db.testMode or 0) > 0 and arenaTestContainer
							and arenaTestContainer:IsShown() and (slot == 2 or slot == 4)
					end,
				}
				arenaRangeOptions[i] = options
			end
			range:Register(frame, "arena" .. i, options)
			arenaRangeRegistered[i] = frame
		end
	end
end

UnregisterArenaRangeFrames = function()
	local range = SarychUI.UnitFrameRange
	if range then range:UnregisterOwner("arena") end
	wipe(arenaRangeRegistered)
end

local function InitializeArenaAppearanceUpdate()
	RegisterArenaRangeFrames()
	if arenaAppearanceUpdateFrame then return end
	arenaAppearanceUpdateFrame = CreateFrame("Frame")
	arenaAppearanceUpdateFrame:SetScript("OnUpdate", function(self, elapsed)
		self.updateTime = (self.updateTime or 0) + elapsed
		if self.updateTime < 0.1 then return end
		self.updateTime = 0
		module:UpdateArenaAppearance()
	end)
end

local function CleanupArenaAppearanceUpdate()
	UnregisterArenaRangeFrames()
	if arenaAppearanceUpdateFrame then
		arenaAppearanceUpdateFrame:SetScript("OnUpdate", nil)
		arenaAppearanceUpdateFrame = nil
	end
	module:ResetArenaAppearance()
	if MAX_ARENA_ENEMIES then
		for i = 1, MAX_ARENA_ENEMIES do
			local frame = _G["ArenaEnemyFrame" .. i]
			if frame then frame:SetAlpha(1) end
		end
	end
end

--------------------------------------------------------------------
-- Arena numbers on nameplates (RougeUI ArenaNumbers)
--------------------------------------------------------------------
local ARENA_NAME_UNITS = { "arena1", "arena2", "arena3", "arena4", "arena5" }
local NAMEPLATE_BORDER = "Interface\\Tooltips\\Nameplate-Border"
local NAMEPLATE_FLASH = "Interface\\TargetingFrame\\UI-TargetingFrame-Flash"
local arenaPlateFrame
local activeArenaPlates = {}
local arenaNameToUnit = {}
local arenaPlateChildCount = -1
local arenaNameScanElapsed = 0
local enpNameHooked = false
local arenaNumbersModuleActive = false
-- Never store addon state on Blizzard's protected arena unit buttons.  Even an
-- otherwise harmless custom field can taint a later combat-time visibility
-- update in Blizzard_ArenaUI.  Keep state in our own weak-key table instead.
local blizzardArenaNameState = setmetatable({}, { __mode = "k" })

local function ArenaNumbersOn()
	if not arenaNumbersModuleActive then return false end
	local db = GetDB()
	if not db or not db.enabled then return false end
	return db.arenaNumbers == 1 or db.arenaNumbers == true
end

local function ArenaNameplatesOn()
	if not ArenaNumbersOn() then return false end
	local db = GetDB()
	-- nil means enabled so profiles created before the split keep their old
	-- nameplate behaviour.
	return db.arenaNumbersNameplates == nil
		or db.arenaNumbersNameplates == 1
		or db.arenaNumbersNameplates == true
end

local function ArenaFramesOn()
	if not ArenaNumbersOn() then return false end
	local db = GetDB()
	return db.arenaNumbersArenaFrames == nil
		or db.arenaNumbersArenaFrames == 1
		or db.arenaNumbersArenaFrames == true
end

local function WipeArenaNameMap()
	for k in pairs(arenaNameToUnit) do
		arenaNameToUnit[k] = nil
	end
end

local function RefreshArenaNameMap()
	WipeArenaNameMap()
	if select(2, IsInInstance()) ~= "arena" then return end
	for i = 1, #ARENA_NAME_UNITS do
		local unit = ARENA_NAME_UNITS[i]
		if UnitExists(unit) then
			local name, realm = UnitName(unit)
			if name then
				arenaNameToUnit[name] = unit
				if realm and realm ~= "" then
					arenaNameToUnit[name .. "-" .. realm] = unit
				end
			end
		end
	end
end

local function ArenaIndexForName(name)
	if not name then return nil end
	local unit = arenaNameToUnit[name]
	if not unit and type(name) == "string" then
		unit = arenaNameToUnit[name:match("^([^-]+)")]
	end
	if not unit then return nil end
	return unit:match("^arena(%d+)$")
end

local function ArenaIndexForUnitFrame(frame, name)
    local visibleName = frame and frame.UnitName or name
    if not visibleName then return nil end
    if frame and (frame.UnitType == "ENEMY_NPC" or frame.UnitType == "FRIENDLY_NPC") then return nil end
    local found
    for i = 1, #ARENA_NAME_UNITS do
        local unit = ARENA_NAME_UNITS[i]
        if UnitExists(unit) and UnitIsPlayer(unit) then
            local unitName, realm = UnitName(unit)
            local fullName = realm and realm ~= "" and (unitName .. "-" .. realm) or unitName
            if visibleName == unitName or visibleName == fullName then
                if found then return nil end
                found = tostring(i)
            end
        end
    end
    return found
end

function SarychUI:GetArenaNameplateDisplayName(frame, name)
	if not ArenaNameplatesOn() or select(2, IsInInstance()) ~= "arena" then
		return name
	end
	return ArenaIndexForUnitFrame(frame, name) or name
end

function SarychUI:GetArenaFrameDisplayName(unit, name)
	if not ArenaFramesOn() or select(2, IsInInstance()) ~= "arena" then
		return name
	end
	local num = type(unit) == "string" and unit:match("^arena(%d+)$")
	return num or ArenaIndexForName(name) or name
end

local function IsENPManagedPlate(plate)
	local unitFrame = plate and plate.UnitFrame
	if not unitFrame or not unitFrame.Name then return false end
	local E = _G.SarychUI_ElvUI_NamePlates
	local NP = E and E.GetModule and E:GetModule("NamePlates", true)
	if NP and NP.CreatedPlates and NP.CreatedPlates[plate] then
		return true
	end
	local frameName = unitFrame.GetName and unitFrame:GetName()
	return frameName and frameName:match("^ENP_NamePlate") ~= nil
end

local function RestorePlateName(plate)
	if not plate then return end
	if plate._suiOldName then
		-- ElvUI owns and deliberately hides the original Blizzard FontString.
		-- Showing it here was the source of the centered duplicate number/name.
		if IsENPManagedPlate(plate) then
			plate._suiOldName:Hide()
		else
			plate._suiOldName:SetAlpha(1)
		end
	end
	if plate._suiArenaName then
		plate._suiArenaName:Hide()
		plate._suiArenaName:SetText("")
	end
	plate._suiArenaFormatted = false
	plate._suiLastArenaText = nil
end

local function InitBlizzardPlate(plate)
	if plate._suiArenaInit then return end
	if IsENPManagedPlate(plate) then return end
	local _, border, _, _, _, _, name = plate:GetRegions()
	if not name or not name.GetObjectType or name:GetObjectType() ~= "FontString" then
		return
	end
	plate._suiArenaInit = true
	plate._suiOldName = name
	plate._suiBorder = border
	local fs = plate:CreateFontString(nil, "ARTWORK")
	fs:SetFont(STANDARD_TEXT_FONT, 12, "")
	fs:SetTextColor(1, 1, 1)
	if border then
		fs:SetPoint("BOTTOM", border, "TOP", 0, -15)
	else
		fs:SetPoint("BOTTOM", plate, "TOP", 0, -15)
	end
	fs:Hide()
	plate._suiArenaName = fs
end

local function UpdateBlizzardPlate(plate)
	if IsENPManagedPlate(plate) then
		RestorePlateName(plate)
		activeArenaPlates[plate] = nil
		return
	end
	if not plate._suiArenaInit then
		InitBlizzardPlate(plate)
	end
	if not plate._suiOldName or not plate._suiArenaName then return end

	local rawName = plate._suiOldName:GetText()
	local arenaNum = ArenaNameplatesOn() and select(2, IsInInstance()) == "arena" and ArenaIndexForName(rawName)
	if arenaNum then
		plate._suiOldName:SetAlpha(0)
		if plate._suiLastArenaText ~= arenaNum then
			plate._suiLastArenaText = arenaNum
			plate._suiArenaName:SetText(arenaNum)
		end
		if not plate._suiArenaFormatted then
			plate._suiArenaFormatted = true
			plate._suiArenaName:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
			plate._suiArenaName:ClearAllPoints()
			plate._suiArenaName:SetPoint("BOTTOM", plate, "TOP", 0, -15)
		end
		if not plate._suiArenaName:IsShown() then
			plate._suiArenaName:Show()
		end
	else
		RestorePlateName(plate)
	end
end

local function IsBlizzardNameplate(frame)
	if IsENPManagedPlate(frame) then return false end
	if not frame or frame.GetName and frame:GetName() then
		return false
	end
	local region = select(2, frame:GetRegions())
	if not region or region.GetObjectType and region:GetObjectType() ~= "Texture" then
		return false
	end
	local tex = region.GetTexture and region:GetTexture()
	return tex == NAMEPLATE_BORDER or tex == NAMEPLATE_FLASH
end

local function ApplyENPArenaName(frame)
	if not frame or not frame.Name then return end
	local displayName = SarychUI:GetArenaNameplateDisplayName(frame, frame.UnitName)
	if displayName and displayName ~= frame.Name:GetText() then
		frame.Name:SetText(displayName)
	end
end

local function HookENPArenaNames()
	if enpNameHooked then return end
	local E = _G.SarychUI_ElvUI_NamePlates
	if not E or not E.GetModule then return end
	local NP = E:GetModule("NamePlates", true)
	if not NP or not NP.Update_Name then return end
	enpNameHooked = true
	hooksecurefunc(NP, "Update_Name", function(_, frame)
		ApplyENPArenaName(frame)
	end)
end

local function RefreshENPArenaNames()
	local E = _G.SarychUI_ElvUI_NamePlates
	if not E or not E.GetModule then return end
	local NP = E:GetModule("NamePlates", true)
	if not NP then return end
	if NP.ForEachVisiblePlate and NP.Update_Name then
		NP:ForEachVisiblePlate("Update_Name")
	elseif NP.VisiblePlates then
		for frame in pairs(NP.VisiblePlates) do
			ApplyENPArenaName(frame)
		end
	end
end

local function UpdateAwesomePlates()
	if not SarychUI.Compatibility:IsAwesomeWotlkEnabled() then return end
	local plates = C_NamePlate.GetNamePlates()
	if not plates then return end
	local replace = ArenaNameplatesOn() and select(2, IsInInstance()) == "arena"
	for i = 1, #plates do
		local np = plates[i]
		local uf = np and np.UnitFrame
		if uf then
			local nameFS = uf.name or uf.Name
			local num = replace and ArenaIndexForUnitFrame(uf, uf.UnitName)
			if num and nameFS and nameFS.SetText then
				local current = nameFS:GetText()
				if current and current ~= "" and current ~= num then
					uf._suiArenaOriginalName = current
				end
				nameFS:SetText(num)
				uf._suiArenaNumberApplied = true
			elseif uf._suiArenaNumberApplied and nameFS and nameFS.SetText then
				local original = uf.UnitName or uf._suiArenaOriginalName
				if original then nameFS:SetText(original) end
				uf._suiArenaNumberApplied = nil
				uf._suiArenaOriginalName = nil
			end
		end
	end
end

local function ArenaPlateOnUpdate(_, elapsed)
	if not ArenaNumbersOn() then
		return
	end

	if ArenaNameplatesOn() then
		local childCount = WorldFrame and WorldFrame.GetNumChildren and WorldFrame:GetNumChildren() or 0
		if childCount ~= arenaPlateChildCount then
			arenaPlateChildCount = childCount
			local n = CollectWorldChildren(WorldFrame:GetChildren())
			for i = 1, n do
				local plate = worldChildren[i]
				if plate and not activeArenaPlates[plate] and IsBlizzardNameplate(plate) then
					activeArenaPlates[plate] = true
					InitBlizzardPlate(plate)
				end
			end
		end
	end

	arenaNameScanElapsed = arenaNameScanElapsed + (elapsed or 0)
	if arenaNameScanElapsed >= 1 then
		arenaNameScanElapsed = 0
		RefreshArenaNameMap()
		RefreshENPArenaNames()
	end

	if select(2, IsInInstance()) == "arena" then
		if ArenaNameplatesOn() then
			for plate in pairs(activeArenaPlates) do
				if plate.IsShown and plate:IsShown() then
					UpdateBlizzardPlate(plate)
				end
			end
			UpdateAwesomePlates()
		end
	end
end

local function RestoreAllArenaPlates()
	for plate in pairs(activeArenaPlates) do
		RestorePlateName(plate)
	end
end

local function GetBlizzardArenaName(frame)
	if not frame then return nil end
	if frame.name and frame.name.SetText then return frame.name end
	if frame.Name and frame.Name.SetText then return frame.Name end
	local frameName = frame.GetName and frame:GetName()
	local name = frameName and _G[frameName .. "Name"]
	return name and name.SetText and name or nil
end

local function ApplyBlizzardArenaFrameName(frame)
	if not frame then return end
	local name = GetBlizzardArenaName(frame)
	if not name then return end
	local state = blizzardArenaNameState[frame]
	if not state then
		state = {}
		blizzardArenaNameState[frame] = state
	end
	local frameName = frame.GetName and frame:GetName()
	local unit = frame.unit
	local num = type(unit) == "string" and unit:match("^arena(%d+)$")
	if not num and frameName then
		num = frameName:match("^ArenaEnemyFrame(%d+)$")
		if num then unit = "arena" .. num end
	end
	local db = GetDB()
	if num and db and (tonumber(db.testMode) or 0) > 0
		and select(2, IsInInstance()) ~= "arena" then
		name:SetText(module:GetTestArenaName(tonumber(num)))
		state.numberApplied, state.originalName = nil, nil
		return
	end
	local shouldNumber = ArenaFramesOn()
		and select(2, IsInInstance()) == "arena"
		and num

	if shouldNumber then
		local current = name:GetText()
		if current and current ~= "" and current ~= num then
			state.originalName = current
		end
		name:SetText(num)
		state.numberApplied = true
	elseif state.numberApplied then
		local original = (unit and UnitName(unit)) or state.originalName
		if original then name:SetText(original) end
		state.numberApplied = nil
		state.originalName = nil
	end
end

local function RefreshBlizzardArenaFrameNames()
	for i = 1, (MAX_ARENA_ENEMIES or 5) do
		ApplyBlizzardArenaFrameName(_G["ArenaEnemyFrame" .. i])
	end
end

local function HookBlizzardArenaFrameNames()
	-- Names are applied on our own frame, one tick after Blizzard writes them.
	-- A hook on ArenaEnemyFrame_UpdatePlayer taints its combat Show().
	if module.ScheduleSecureFramePaint then
		module:ScheduleSecureFramePaint()
	end
end

function module:ScheduleSecureFramePaint()
	if InCombatLockdown and InCombatLockdown() and eventFrame then
		eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	end
	if not self._securePaintFrame then
		local paint = CreateFrame("Frame")
		paint:Hide()
		paint:SetScript("OnUpdate", function(frame)
			frame:Hide()
			if not MAX_ARENA_ENEMIES then return end
			local db = GetDB()
			local i
			for i = 1, MAX_ARENA_ENEMIES do
				ColorArenaHealthByClass(_G["ArenaEnemyFrame" .. i])
			end
			RefreshBlizzardArenaFrameNames()
			if self.ApplyGladiusStyle then self:ApplyGladiusStyle() end
		end)
		self._securePaintFrame = paint
	end
	self._securePaintFrame:Show()
end

local function RefreshAllArenaNumberTargets()
	RefreshENPArenaNames()
	UpdateAwesomePlates()
	RefreshBlizzardArenaFrameNames()
end

--------------------------------------------------------------------
-- Hide "Group/Raid" titles (RougeUI HideTitles), only in arena
--------------------------------------------------------------------
local groupTitlesFrame
local groupTitlesHooked = false

local function HideGroupTitlesOn()
	local db = GetDB()
	if not db or not db.enabled then return false end
	return db.hideGroupRaidText == 1 or db.hideGroupRaidText == true
end

local function ShouldHideGroupTitles()
	return HideGroupTitlesOn() and select(2, IsInInstance()) == "arena"
end

local function SetTitleAlpha(frame, alpha)
	if frame and frame.SetAlpha then
		frame:SetAlpha(alpha)
	end
end

local function ApplyGroupTitleVisibility()
	local hide = ShouldHideGroupTitles()
	local alpha = hide and 0 or 1
	SetTitleAlpha(_G.CompactPartyFrameTitle, alpha)
	if CompactPartyFrame then
		SetTitleAlpha(CompactPartyFrame.title, alpha)
	end
	for i = 1, 8 do
		SetTitleAlpha(_G["CompactRaidGroup" .. i .. "Title"], alpha)
	end
	if PlayerFrameGroupIndicator then
		if hide then
			PlayerFrameGroupIndicator:Hide()
		elseif type(PlayerFrame_UpdateGroupIndicator) == "function" then
			PlayerFrame_UpdateGroupIndicator()
		end
	end
end

local function HookGroupTitles()
	if groupTitlesHooked then return end
	groupTitlesHooked = true
	if PlayerFrameGroupIndicator then
		hooksecurefunc(PlayerFrameGroupIndicator, "Show", function(self)
			if ShouldHideGroupTitles() then
				self:Hide()
			end
		end)
	end
	if CompactRaidGroup_GenerateForGroup then
		hooksecurefunc("CompactRaidGroup_GenerateForGroup", function()
			ApplyGroupTitleVisibility()
		end)
	end
	if CompactPartyFrame_Generate then
		hooksecurefunc("CompactPartyFrame_Generate", function()
			ApplyGroupTitleVisibility()
		end)
	end
end

function module:UpdateGroupTitles()
	HookGroupTitles()
	ApplyGroupTitleVisibility()
	if HideGroupTitlesOn() then
		if not groupTitlesFrame then
			groupTitlesFrame = CreateFrame("Frame")
			groupTitlesFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
			groupTitlesFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
			groupTitlesFrame:SetScript("OnEvent", function()
				ApplyGroupTitleVisibility()
			end)
		end
		groupTitlesFrame:Show()
	elseif groupTitlesFrame then
		groupTitlesFrame:Hide()
	end
end

function module:UpdateArenaNameplates()
	HookENPArenaNames()
	HookBlizzardArenaFrameNames()
	RefreshArenaNameMap()
	if ArenaNumbersOn() then
		if not arenaPlateFrame then
			arenaPlateFrame = CreateFrame("Frame")
			arenaPlateFrame:SetScript("OnUpdate", ArenaPlateOnUpdate)
			arenaPlateFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
			arenaPlateFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
			arenaPlateFrame:RegisterEvent("ARENA_OPPONENT_UPDATE")
			arenaPlateFrame:RegisterEvent("UNIT_NAME_UPDATE")
			arenaPlateFrame:SetScript("OnEvent", function(_, event, unit)
				-- Blizzard_ArenaUI can be load-on-demand, so its updater may not
				-- exist yet during SarychUI's initial Enable call.
				HookBlizzardArenaFrameNames()
				if event == "UNIT_NAME_UPDATE" and unit
					and (type(unit) ~= "string" or not unit:match("^arena%d+$")) then
					return
				end
				RefreshArenaNameMap()
				if select(2, IsInInstance()) ~= "arena" then
					RestoreAllArenaPlates()
				end
				RefreshAllArenaNumberTargets()
			end)
		end
		arenaPlateFrame:Show()
		arenaPlateChildCount = -1
		if not ArenaNameplatesOn() then
			RestoreAllArenaPlates()
		end
		RefreshAllArenaNumberTargets()
	else
		if arenaPlateFrame then
			arenaPlateFrame:Hide()
		end
		RestoreAllArenaPlates()
		RefreshAllArenaNumberTargets()
		WipeArenaNameMap()
	end
end

--------------------------------------------------------------------
-- TAB remapping (RougeUI retab): arena/BG TAB -> enemy players, not pets/mobs
--------------------------------------------------------------------
local RETAB_KEY = "TAB"
local RETAB_BUTTON_NAME = "SarychUITabber"
local retabButton
local retabFrame
local retabModuleActive = false

local function RetabOn()
	if not retabModuleActive then return false end
	local db = GetDB()
	if not db or not db.enabled then return false end
	return db.retab == 1 or db.retab == true
end

local function ApplyRetab()
	if InCombatLockdown() then
		if retabFrame then
			retabFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		end
		return
	end
	if not retabButton then return end
	local _, instanceType = IsInInstance()
	if RetabOn() and (instanceType == "arena" or instanceType == "pvp") then
		SetOverrideBindingClick(retabButton, true, RETAB_KEY, RETAB_BUTTON_NAME)
	else
		ClearOverrideBindings(retabButton)
	end
end

function module:UpdateRetab()
	if not retabFrame then
		retabFrame = CreateFrame("Frame")
		retabFrame:SetScript("OnEvent", function(self, event)
			if event == "PLAYER_REGEN_ENABLED" then
				self:UnregisterEvent("PLAYER_REGEN_ENABLED")
			end
			module:UpdateRetab()
		end)
	end
	if InCombatLockdown() then
		retabFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end
	if not retabButton then
		retabButton = CreateFrame("Button", RETAB_BUTTON_NAME, nil, "SecureActionButtonTemplate")
		retabButton:RegisterForClicks("AnyDown")
		retabButton:SetAttribute("type", "macro")
		if SecureHandlerWrapScript then
			SecureHandlerWrapScript(retabButton, "OnClick", retabButton, [[
				if down then
					self:SetAttribute("macrotext","/targetenemyplayer\n/targetlasttarget [noexists]")
				end]])
		end
	end
	if RetabOn() then
		retabFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
		retabFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
		retabFrame:Show()
	else
		retabFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
		retabFrame:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
	end
	ApplyRetab()
end

-- Apply position and scale based on DB and DragMode
function module:ApplySettings()
	if self.ArenaTimers then self.ArenaTimers:Refresh() end
	self:UpdateArenaNameplates()
	self:UpdateGroupTitles()
	self:UpdateRetab()
	local db = GetDB()
	if not db or not db.enabled then return end
	if db.frameType == "classic" then EnsureClassicTestTicker() end
	
	-- Проверяем, не происходит ли сейчас drag или только что был drag - если да, не применяем позицию
	-- Это предотвращает перезапись позиции во время drag и сразу после него
	self:ApplyContainerPosition()
	
	if ArenaEnemyFrames and not (InCombatLockdown and InCombatLockdown()) then
		ArenaEnemyFrames:SetScale(GetSetting("scale", 1.0))
	end
	self:ApplyFrameSpacing()
	if self.ApplyGladiusStyle then self:ApplyGladiusStyle() end
	self:ClampArenaToScreen()
	if self.Diminishings then self.Diminishings:Refresh() end
	if self.ProcTrinkets then self.ProcTrinkets:Refresh() end

	-- Apply class coloring immediately according to setting
	self:ApplyClassColoring()
	
	-- Keep arena appearance and shared range registration current.
	InitializeArenaAppearanceUpdate()
	self:UpdateArenaAppearance()
	
	-- Если тестовый режим активен, обновляем отображение иконок тринкетов
	if db.testMode and db.testMode > 0 and db.Trinkets then
		self:ShowTestTrinkets(db.testMode, db.Trinkets)
		self:UpdateArenaAppearance()
		local abilities = SarychUI.extensions and SarychUI.extensions.party_abilities
		if abilities and abilities.RefreshConfig then abilities:RefreshConfig() end
		if SarychUI.DragMode then SarychUI.DragMode:RefreshDragOverlay("arenaContainer") end
	end
	
	-- Общий режим перемещения и общая сетка.
	local showDrag = db.showDragFrame == 1
	local showGrid = db.showGrid == 1
	
	-- Проверяем что arenaContainer существует
	if not arenaContainer then
		return
	end
	
	-- Вычисляем дефолтную позицию если еще не вычислена
	if not arenaDefaultPosition then
		self:CalculateDefaultContainerPosition()
	end
	
	if SarychUI.DragMode then
		self:RegisterDrag()
		SarychUI.DragMode:EnableEditMode("arenaContainer", showDrag, showDrag, showGrid)
		SarychUI.DragMode:ShowGrid(showGrid and showDrag)
	end
end

-- The container is an unprotected position editor; arena unit buttons stay in
-- Blizzard's protected hierarchy.
local function ArenaDragBounds()
	local parentScale = UIParent:GetEffectiveScale()
	if not parentScale or parentScale <= 0 then return end
	local left, bottom, right, top
	local function Include(frame)
		if not frame then return end
		local l, b, r, t = frame:GetLeft(), frame:GetBottom(), frame:GetRight(), frame:GetTop()
		local scale = frame:GetEffectiveScale()
		if not (l and b and r and t and scale and scale > 0 and r > l and t > b) then return end
		local ratio = scale / parentScale
		l, b, r, t = l * ratio, b * ratio, r * ratio, t * ratio
		left = left and math.min(left, l) or l
		bottom = bottom and math.min(bottom, b) or b
		right = right and math.max(right, r) or r
		top = top and math.max(top, t) or t
	end

	if arenaTestContainer and arenaTestContainer:IsShown() then
		for i = 1, 5 do
			local frame = arenaTestFrames[i]
			if frame and frame:IsVisible() then
				Include(frame)
				if frame._suiGladiusPet and frame._suiGladiusPet:IsShown() then Include(frame._suiGladiusPet) end
				if i == 1 and classicTestPet and classicTestPet:IsShown() then Include(classicTestPet) end
				if arenaTestCastbars[i] and arenaTestCastbars[i]:IsShown() then Include(arenaTestCastbars[i]) end
				for _, suffix in ipairs({ "Trinket1", "Racial" }) do
					local icon = _G["SarychUIArenaTestTrinket" .. i .. suffix]
					if icon and icon:IsShown() then Include(icon) end
				end
			end
		end
	else
		for i = 1, (MAX_ARENA_ENEMIES or 5) do
			local frame = _G["ArenaEnemyFrame" .. i]
			if frame and frame:IsShown() then
				Include(frame)
				if frame._suiGladiusPet and frame._suiGladiusPet:IsShown() then Include(frame._suiGladiusPet) end
			end
		end
	end
	-- Keep the left snap corner fixed; trim only the right edge of the editor.
	return left, bottom, right and right - 20, top
end

function module:RegisterDrag()
	if not arenaContainer or not SarychUI.DragMode
		or SarychUI.DragMode:GetFrameData("arenaContainer") then return end
	SarychUI.DragMode:RegisterFrame("arenaContainer", arenaContainer, {
		dragText = "Арена",
		dragPoint = "TOP",
		dragOffsetX = -24,
		dragOffsetY = 3,
		dragBoundsOffsetY = 12,
		-- Fallback based on five 102x32 preview frames with 20px gaps.
		dragWidth = 82,
		dragHeight = 240,
		getDragBounds = ArenaDragBounds,
		preservePositionOnDisable = true,
		getPoint = function()
			local point, _, relativePoint, x, y = arenaContainer:GetPoint()
			return { point or "RIGHT", UIParent, relativePoint or "RIGHT", x or 0, y or 0 }
		end,
		onPositionChanged = function(point, relativePoint, x, y)
			local db = GetDB(); if not db then return end
			local style = module:GetStyleSettings()
			style.arenaA, style.arenaR, style.arenaX, style.arenaY = point, relativePoint, x, y
			module:PlaceFirstArenaFrame()
			module:ClampArenaToScreen()
			local panel = SarychUI.PositionDragPanel
			if panel and panel.OnDragPosition then
				panel:OnDragPosition("arenaContainer", style.arenaX, style.arenaY, style.arenaA, style.arenaR)
			end
			if db.testMode and db.testMode > 0 then
				local updateFrame = CreateFrame("Frame")
				updateFrame:SetScript("OnUpdate", function(self)
					self:SetScript("OnUpdate", nil)
					if module.Test then module:Test(db.testMode) end
				end)
			end
		end,
	})
end

-- Public API used by options
local deferredScaleFrame

local function ArenaFrameCenter()
	local parentScale = UIParent:GetEffectiveScale()
	if not parentScale or parentScale <= 0 then return end
	for pass = 1, 2 do
		local left, right, top, bottom
		for index = 1, MAX_ARENA_ENEMIES or 5 do
			local frame = _G["ArenaEnemyFrame" .. index]
			if frame and (pass == 2 or frame:IsShown()) then
				local scale = frame:GetEffectiveScale()
				local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
				if scale and l and r and t and b then
					local ratio = scale / parentScale
					l, r, t, b = l * ratio, r * ratio, t * ratio, b * ratio
					left = left and math.min(left, l) or l
					right = right and math.max(right, r) or r
					top = top and math.max(top, t) or t
					bottom = bottom and math.min(bottom, b) or b
				end
			end
		end
		if left and right and top and bottom then
			return (left + right) / 2, (top + bottom) / 2
		end
	end
end

function module:RefreshAttachedArenaScales()
	local db = GetDB()
	if not db then return end
	local tr = db.Trinkets or {}
	for index = 1, MAX_ARENA_ENEMIES or 5 do
		local frame = _G["ArenaEnemyFrame" .. index]
		if frame then
			local scale = GetArenaIconScale(frame, GladiusIcons() and 1 or tr.scale)
			for _, suffix in ipairs({ "Trinket1", "Trinket2" }) do
				local icon = self.Trinkets["arena" .. index .. suffix]
				if icon and icon:GetScale() ~= scale then icon:SetScale(scale) end
			end
			for _, suffix in ipairs({ "Trinket1", "Racial" }) do
				local icon = _G["SarychUIArenaTestTrinket" .. index .. suffix]
				if icon and icon:GetScale() ~= scale then icon:SetScale(scale) end
			end
		end
	end
	if self.Diminishings then self.Diminishings:Refresh() end
	local abilities = SarychUI.extensions and SarychUI.extensions.party_abilities
	if abilities and abilities.Render then abilities:Render() end
end

function module:SetScale(value)
	local db = GetDB(); if not db then return end
	value = tonumber(value) or 1.0
	local style = self:GetStyleSettings()
	style.scale = value
	if InCombatLockdown and InCombatLockdown() then
		if not deferredScaleFrame then
			deferredScaleFrame = CreateFrame("Frame")
			deferredScaleFrame:SetScript("OnEvent", function(frame)
				frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
				module:SetScale(module:GetStyleSettings().scale)
			end)
		end
		deferredScaleFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end
	local beforeX, beforeY = ArenaFrameCenter()
	if ArenaEnemyFrames then ArenaEnemyFrames:SetScale(value) end
	self:PlaceFirstArenaFrame()
	local afterX, afterY = ArenaFrameCenter()
	if beforeX and afterX and arenaContainer then
		local dx, dy = beforeX - afterX, beforeY - afterY
		if math.abs(dx) > 0.01 or math.abs(dy) > 0.01 then
			local point, _, relativePoint, x, y = arenaContainer:GetPoint()
			if point then
				x, y = (x or 0) + dx, (y or 0) + dy
				arenaContainer:ClearAllPoints()
				arenaContainer:SetPoint(point, UIParent, relativePoint or point, x, y)
				style.arenaA, style.arenaR, style.arenaX, style.arenaY = point, relativePoint or point, x, y
				self:PlaceFirstArenaFrame()
			end
		end
	end
	self:RefreshAttachedArenaScales()
	if self.UpdateGladiusVisuals then self:UpdateGladiusVisuals() end
	if SarychUI.DragMode then
		SarychUI.DragMode:RefreshDragOverlay("arenaContainer")
	end
end

-- Lifecycle
function module:Enable()
    local db = GetDB(); if not db or not db.enabled then return end
    if self:SyncArenaCVars() then return end
    if self.ArenaTimers then self.ArenaTimers:Refresh() end
    self:ApplyArenaPointer()
    self:ApplyPvpScoreboardClassNames()
	arenaNumbersModuleActive = true
	retabModuleActive = true
	self:UpdateArenaNameplates()
	self:UpdateGroupTitles()
	self:UpdateRetab()
	if self.StartArenaSpecDetection then self:StartArenaSpecDetection() end
	if self.Diminishings then self.Diminishings:Refresh() end
	
	-- Сбрасываем тестовый режим при загрузке/перезагрузке
	if db.testMode and db.testMode > 0 then
		db.testMode = 0
		-- Do not call Hide() on Blizzard arena unit buttons here.  A reload clears
		-- the preview by itself, while touching protected visibility would taint
		-- the first combat update.
	end
	
    self:InitializeContainer()
	self:RegisterDrag()
	self:ApplySettings()
    
    -- sArena-like trinkets lifecycle
    module.Trinkets:RegisterEvent("PLAYER_ENTERING_WORLD")
    module.Trinkets:RegisterEvent("PLAYER_LEAVING_WORLD")
    module.Trinkets:RegisterEvent("ARENA_OPPONENT_UPDATE")
    module.Trinkets:Initialize()

	if not eventFrame then
		eventFrame = CreateFrame("Frame")
		eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
		eventFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
		eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
			eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
			eventFrame:RegisterEvent("UI_SCALE_CHANGED")
		eventFrame:RegisterEvent("ADDON_LOADED")
		eventFrame:RegisterEvent("ARENA_OPPONENT_UPDATE")
		eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		eventFrame:RegisterEvent("UNIT_NAME_UPDATE")
		eventFrame:SetScript("OnEvent", function(_, event, addonName, updateReason, ...)
			if event == "PLAYER_REGEN_ENABLED" then
				eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
				self:ApplyFrameSpacing()
				if self.ApplyGladiusStyle then self:ApplyGladiusStyle() end
				return
			end
			if event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
				self:ApplyContainerPosition()
				self:ClampArenaToScreen()
				return
			end
			if event == "COMBAT_LOG_EVENT_UNFILTERED" then
				if updateReason == "UNIT_DIED" and select(2, IsInInstance()) == "arena" then
					local destGUID = select(4, ...)
					if destGUID then
						for i = 1, (MAX_ARENA_ENEMIES or 5) do
							local knownGUID = arenaGUIDBySlot[i]
								or (self.Trinkets._iconGUID and self.Trinkets._iconGUID[i])
							if knownGUID == destGUID then deadGUIDBySlot[i] = destGUID end
						end
						self:UpdateArenaAppearance()
						if self.UpdateGladiusVisuals then self:UpdateGladiusVisuals() end
					end
				end
				return
			end
			if event == "ARENA_OPPONENT_UPDATE" then
				self:UpdateArenaAppearance()
				self:ScheduleSecureFramePaint()
				return
			end
			if event == "UNIT_NAME_UPDATE" and type(addonName) == "string" and addonName:match("^arena%d+$") then
				self:ScheduleSecureFramePaint()
				return
			end
			if event == "ADDON_LOADED" then
				if addonName == "Blizzard_ArenaUI" then
					self:InitializeContainer()
					RegisterArenaRangeFrames()
					self:ScheduleSecureFramePaint()
					module.Trinkets:RefreshIcons()
				end
				return
			end
			if event == "PLAYER_ENTERING_WORLD" then
				-- Сбрасываем тестовый режим при входе в мир
				local db = GetDB()
				if arenaTestContainer and arenaTestContainer:IsShown() then
					self:HideArenaEnemyFrames()
				end
				if db and db.testMode and db.testMode > 0 then
					db.testMode = 0
				end
				
				local instanceType = select(2, IsInInstance())
				if instanceType == "arena" then
					wipe(deadGUIDBySlot)
					wipe(arenaGUIDBySlot)
					-- Frames survive zoning.  Re-apply only the out-of-combat hierarchy
					-- and position; never Hide/Show them or call Blizzard's updater.
					self:InitializeContainer()
					InitializeArenaAppearanceUpdate()
					self:UpdateArenaAppearance()
				else
					CleanupArenaAppearanceUpdate()
				end
			elseif event == "PLAYER_LEAVING_WORLD" then
				-- Blizzard_ArenaUI owns protected frame visibility across zoning.
				CleanupArenaAppearanceUpdate()
				self:HideArenaCombatIndicators()
				self:HideClassicSpecVisuals()
			elseif event == "ZONE_CHANGED_NEW_AREA" then
				-- Check if we're still in arena
				local instanceType = select(2, IsInInstance())
				if instanceType ~= "arena" then
					CleanupArenaAppearanceUpdate()
				else
					-- Clear stale arena slot state for new opponents.
					wipe(arenaGUIDBySlot)
					wipe(deadGUIDBySlot)
					InitializeArenaAppearanceUpdate()
					self:UpdateArenaAppearance()
				end
			end
		end)
	end
end

function module:Disable()
    if self.ArenaTimers then self.ArenaTimers:Disable() end
    self:UpdateClassicFontSize(true)
    self:DisableArenaPointer()
	if self.StopArenaSpecDetection then self:StopArenaSpecDetection() end
	if self.Diminishings then self.Diminishings:Refresh() end
	arenaNumbersModuleActive = false
	self:HideArenaEnemyFrames()
	if self.ProcTrinkets then self.ProcTrinkets:Disable() end
	self:HideArenaCombatIndicators()
	self:HideClassicSpecVisuals()
	-- Shared DragMode cleanup.
	if SarychUI.DragMode then
		SarychUI.DragMode:EnableEditMode("arenaContainer", false, false, false)
		SarychUI.DragMode:UnregisterFrame("arenaContainer")
	end
	-- Events
	if eventFrame then
		eventFrame:UnregisterAllEvents()
		eventFrame:SetScript("OnEvent", nil)
		eventFrame = nil
	end
	
	-- Restore arena frames to default Blizzard state before removing container
	self:RestoreArenaFrames()
	
	-- Container
	if arenaContainer then
		arenaContainer:Hide()
		arenaContainer:SetParent(nil)
		arenaContainer = nil
	end
	
	-- Trinkets cleanup
	if module.Trinkets then

		module.Trinkets:DeleteTrinketIcons()
		module.Trinkets:UnregisterAllEvents()
	end
	
	CleanupArenaAppearanceUpdate()
	self:HideArenaCombatIndicators()
	self:HideClassicSpecVisuals()

	if arenaPlateFrame then
		arenaPlateFrame:Hide()
	end
	RestoreAllArenaPlates()
	RefreshAllArenaNumberTargets()
	WipeArenaNameMap()
	if groupTitlesFrame then
		groupTitlesFrame:Hide()
	end
	ApplyGroupTitleVisibility()
	retabModuleActive = false
	if retabFrame then
		retabFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
		retabFrame:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
	end
	ApplyRetab()
end

function module:RefreshConfig()
	self:Disable()
	self:Enable()
end

-- Protected arena buttons can only be restored/reconfigured outside combat.
local lifecycleFrame = CreateFrame("Frame")
function module:ApplyEnabledState()
    if InCombatLockdown() then
        lifecycleFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    lifecycleFrame:UnregisterAllEvents()
    local db = GetDB()
    if db and db.enabled then self:Enable() else self:Disable() end
end
lifecycleFrame:SetScript("OnEvent", function() module:ApplyEnabledState() end)

-- Blizzard 3.3.5 arena options are prerequisites for both frame styles.
local arenaCVars = {
    { "showArenaEnemyFrames", "SHOW_ARENA_ENEMY_FRAMES_TEXT" },
    { "showArenaEnemyCastbar", "SHOW_ARENA_ENEMY_CASTBAR_TEXT" },
    { "showArenaEnemyPets", "SHOW_ARENA_ENEMY_PETS_TEXT" },
}
local settingArenaCVars = false

function module:SyncArenaCVars()
    local db = GetDB()
    if settingArenaCVars or not db or not db.enabled then return false end
    for _, setting in ipairs(arenaCVars) do
        if GetCVar(setting[1]) ~= "1" then
            self:SetEnabled(false)
            if SarychUI.NotifySarychUIOptionsChange then
                SarychUI:NotifySarychUIOptionsChange()
            end
            return true
        end
    end
    return false
end

function module:SetEnabled(value)
    local db = GetDB()
    if not db then return end
    -- Apply the three game options atomically from the observer's perspective.
    settingArenaCVars = true
    for _, setting in ipairs(arenaCVars) do
        SetCVar(setting[1], value and "1" or "0", setting[2])
    end
    settingArenaCVars = false
    db.enabled = value and true or false
    self:ApplyEnabledState()
end

-- Keep this observer separate from the lifecycle's combat deferral frame.
local arenaCVarFrame = CreateFrame("Frame")
arenaCVarFrame:RegisterEvent("CVAR_UPDATE")
arenaCVarFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
arenaCVarFrame:SetScript("OnEvent", function() module:SyncArenaCVars() end)
