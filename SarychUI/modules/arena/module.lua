-- SarychUI Arena Module
-- Arena enemy frames positioning, scaling and testing (based on sArena behavior)

local moduleName = "arena"
local module = {}

-- Register module
SarychUI:RegisterModule(moduleName, module)

-- Local references
local L = SarychUI.L

-- Local drag mode для arena
-- Загружается из modules\arena\drag_mode.lua (добавлен в TOC перед module.lua)
local ArenaDragMode = SarychUI_ArenaDragMode

-- Helpers
local function GetDB()
	local root = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return root and root[moduleName]
end

local function GetSetting(key, default)
	local db = GetDB()
	if db and db[key] ~= nil then return db[key] end
	return default
end

local GLADIUS_ADDON = "GladiusEx"

function module:IsGladiusExMode()
	if SarychUI and SarychUI.GetActiveFeatureOwner then
		return SarychUI:GetActiveFeatureOwner("arena") == "gladiusex"
	end
	if SarychUI and SarychUI.IsAddOnEnabled then
		return SarychUI:IsAddOnEnabled(GLADIUS_ADDON)
	end
	local addons = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons
	return addons and addons[GLADIUS_ADDON] and addons[GLADIUS_ADDON].enabled == true
end

-- Internal state
local arenaContainer
local eventFrame
local arenaDefaultPosition = nil
local firstArenaFramePosition = nil
local distanceAlphaUpdateFrame = nil
-- Cache for nameplate lookups by GUID
local nameplateCache = {}
local nameplateCacheTime = {}

-- ============================================
-- sArena Trinkets logic (ported with minimal changes)
-- ============================================

module.Trinkets = CreateFrame("Frame")

local Alliance = {
    ["Human"] = "Human",
    ["Dwarf"] = "Dwarf",
    ["Night Elf"] = "Night Elf",
    ["Gnome"] = "Gnome",
    ["Draenei"] = "Draenei",
}

local Horde = {
    ["Orc"] = "Orc",
    ["Undead"] = "Undead",
    ["Tauren"] = "Tauren",
    ["Troll"] = "Troll",
    ["Blood Elf"] = "Blood Elf",
}

local racialSpells = {
    ["Human"] = {id = 59752, icon = "Interface\\Icons\\Spell_Shadow_Charm", cd = 120},
    ["Orc"] = {id = 20572, icon = "Interface\\Icons\\racial_orc_berserkerstrength", cd = 120},
    ["Dwarf"] = {id = 20594, icon = "Interface\\Icons\\spell_shadow_unholystrength", cd = 120},
    ["Night Elf"] = {id = 58984, icon = "Interface\\Icons\\ability_ambush", cd = 120},
    ["Undead"] = {id = 7744, icon = "Interface\\Icons\\spell_shadow_raisedead", cd = 120},
    ["Tauren"] = {id = 20549, icon = "Interface\\Icons\\ability_warstomp", cd = 120},
    ["Gnome"] = {id = 20589, icon = "Interface\\Icons\\ability_rogue_trip", cd = 105},
    ["Troll"] = {id = 26297, icon = "Interface\\Icons\\racial_troll_berserk", cd = 180},
    ["Blood Elf"] = {id = 28730, icon = "Interface\\Icons\\spell_shadow_teleport", cd = 120},
    ["Draenei"] = {id = 28880, icon = "Interface\\Icons\\spell_holy_holyprotection", cd = 180},
    ["None"] = {id = nil, icon = "Interface\\Icons\\inv_misc_questionmark", cd = 0},
}

-- Localized UnitRace() names → racialSpells keys (fallback when raceFile unavailable)
local raceTranslation = {
    ["Человек"] = "Human",
    ["Орк"] = "Orc",
    ["Дворф"] = "Dwarf",
    ["Ночная эльфийка"] = "Night Elf",
    ["Ночной эльф"] = "Night Elf",
    ["Нежить"] = "Undead",
    ["Таурен"] = "Tauren",
    ["Гном"] = "Gnome",
    ["Тролль"] = "Troll",
    ["Эльф крови"] = "Blood Elf",
    ["Эльфийка крови"] = "Blood Elf",
    ["Дреней"] = "Draenei",
}

-- UnitRace() raceFile tokens (locale-independent) → racialSpells keys
local raceFileToKey = {
    Human = "Human",
    Orc = "Orc",
    Dwarf = "Dwarf",
    NightElf = "Night Elf",
    Scourge = "Undead",
    Tauren = "Tauren",
    Gnome = "Gnome",
    Troll = "Troll",
    BloodElf = "Blood Elf",
    Draenei = "Draenei",
}

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
        return "Interface\\Icons\\inv_jewelry_trinketpvp_01"
    elseif Horde[race] then
        return "Interface\\Icons\\inv_jewelry_trinketpvp_02"
    else
        return "Interface\\Icons\\inv_misc_questionmark"
    end
end

function module.Trinkets:CreateTrinketIcon(frame, texture, anchorFrame)
    local db = GetDB(); local tr = db and db.Trinkets or {}
    local trinket = CreateFrame("Cooldown", nil, frame)
    trinket:SetFrameLevel(frame:GetFrameLevel() + 3)
    trinket:SetSize(26, 26)
    trinket:SetScale(tr.scale or 1)

    if anchorFrame then
        trinket:SetPoint("LEFT", anchorFrame, "RIGHT", 5, 0)
    else
        if tr.point then
            trinket:SetPoint(tr.point, frame, tr.x, tr.y)
        else
            trinket:SetPoint("LEFT", frame, "RIGHT", 2, -2)
        end
    end

    trinket.Icon = CreateFrame("Frame", nil, trinket)
    trinket.Icon:SetFrameLevel(trinket:GetFrameLevel() - 1)
    trinket.Icon:SetAllPoints()

    trinket.Icon.Texture = trinket.Icon:CreateTexture(nil, "BORDER")
    trinket.Icon.Texture:SetAllPoints()
    trinket.Icon.Texture:SetTexture(texture)
    trinket.Icon.Texture:SetTexCoord(0, 1, 0, 1)

    if not tr.enabled then
        trinket.Icon:Hide()
    end

    -- AlwaysShow behavior
    if tr.alwaysShow then
        trinket.Icon:SetParent(trinket:GetParent())
        trinket.Icon:SetScale(tr.scale or 1)
        trinket.Icon:SetFrameLevel(trinket:GetFrameLevel() - 1)
    else
        trinket.Icon:SetParent(trinket)
        trinket.Icon:SetScale(1)
        trinket.Icon:SetFrameLevel(trinket:GetFrameLevel() - 1)
    end

    UIFrameFadeIn(trinket.Icon, 0.2, 0, 1)
    trinket:Show()
    -- Enable edge draw for cooldown sweep border
    if trinket.SetDrawEdge then trinket:SetDrawEdge(true) end
    return trinket
end

function module.Trinkets:CreateNonHumanIcons(frame, id, race)
    if not racialSpells[race] then race = "None" end
    local trinket1Texture = self:GetTrinketTextureByRaceAndFaction(race)
    local trinket1 = self:CreateTrinketIcon(frame, trinket1Texture)
    local trinket2 = self:CreateTrinketIcon(frame, racialSpells[race].icon, trinket1)
    self["arena" .. id .. "Trinket1"] = trinket1
    self["arena" .. id .. "Trinket2"] = trinket2
end

function module.Trinkets:CreateHumanIcon(frame, id)
    local trinket4 = self:CreateTrinketIcon(frame, racialSpells["Human"].icon)
    self["arena" .. id .. "Trinket4"] = trinket4
end

function module.Trinkets:CreateIcon(frame)
    local id = frame:GetID()
    local function setupIcons()
        local race = ResolveArenaRace(frame.unit)
        self:DeleteTrinketIcons(id)
        if race == "Human" then
            self:CreateHumanIcon(frame, id)
        else
            self:CreateNonHumanIcons(frame, id, race)
        end
    end
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.updateTime = (self.updateTime or 0) + elapsed
        if self.updateTime >= 0.3 then
            setupIcons()
            self:SetScript("OnUpdate", nil)
        end
    end)
end

function module.Trinkets:DeleteTrinketIcons(id)
    if id then
        for _, suffix in ipairs({"Trinket1", "Trinket2", "Trinket3", "Trinket4"}) do
            local name = "arena" .. id .. suffix
            if self[name] then
                local trinket = self[name]
                trinket:SetScript("OnUpdate", nil)
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
        if MAX_ARENA_ENEMIES then
            for i = 1, MAX_ARENA_ENEMIES do self:DeleteTrinketIcons(i) end
        end
    end
end

function module.Trinkets:Initialize()
    local db = GetDB(); db.Trinkets = db.Trinkets or { enabled = true, scale = 1, alwaysShow = true }
    if not MAX_ARENA_ENEMIES then return end
    for i = 1, MAX_ARENA_ENEMIES do
        local ArenaFrame = _G["ArenaEnemyFrame" .. i]
        if ArenaFrame then self:CreateIcon(ArenaFrame) end
    end
end

module.Trinkets:SetScript("OnEvent", function(self, event, ...)
    return self[event] and self[event](self, ...)
end)

function module.Trinkets:UNIT_SPELLCAST_SUCCEEDED(unitID, spell)
    if not unitID or not unitID:match("^arena%d+$") then return end
    local race = ResolveArenaRace(unitID)
    local trinketSpellInfo = GetSpellInfo(42292)
    local humanSpellInfo = GetSpellInfo(59752)
    if not spell then return end
    if spell == trinketSpellInfo then
        if self[unitID .. "Trinket1"] then
            local trinket = self[unitID .. "Trinket1"]
            if trinket.SetDrawEdge then trinket:SetDrawEdge(true) end
            CooldownFrame_SetTimer(trinket, GetTime(), 120, 1)
        end
    end
    if race == "Human" and spell == humanSpellInfo then
        if self[unitID .. "Trinket4"] then
            local trinket = self[unitID .. "Trinket4"]
            if trinket.SetDrawEdge then trinket:SetDrawEdge(true) end
            CooldownFrame_SetTimer(trinket, GetTime(), 120, 1)
        end
    end
    if racialSpells[race] and racialSpells[race].id and spell == GetSpellInfo(racialSpells[race].id) then
        if self[unitID .. "Trinket2"] then
            local trinket = self[unitID .. "Trinket2"]
            if trinket.SetDrawEdge then trinket:SetDrawEdge(true) end
            CooldownFrame_SetTimer(trinket, GetTime(), racialSpells[race].cd, 1)
        end
    end
end

function module.Trinkets:PLAYER_ENTERING_WORLD()
    local instanceType = select(2, IsInInstance())
    local db = GetDB(); local tr = db and db.Trinkets or {}
    if tr.enabled and instanceType == "arena" then
        self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        self:DeleteTrinketIcons()
        for i = 1, MAX_ARENA_ENEMIES do
            self:CreateIcon(_G["ArenaEnemyFrame" .. i])
        end
    elseif self:IsEventRegistered("UNIT_SPELLCAST_SUCCEEDED") then
        self:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    end
end

function module.Trinkets:PLAYER_LEAVING_WORLD()
    self:DeleteTrinketIcons()
end

-- Class color for arena healthbars (ported from sArena)
local function ColorArenaHealthByClass(frame)
	if not frame or not frame.unit then return end
	if not frame.healthbar then return end
	-- respect setting
	local db = GetDB(); if not (db == nil or db.classColorHP == nil or db.classColorHP == true) then return end
	if not UnitIsPlayer(frame.unit) then return end
	local _, class = UnitClass(frame.unit)
	if not class then return end
	local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if not color then return end
	frame.healthbar.lockColor = true
	frame.healthbar:SetStatusBarColor(color.r, color.g, color.b)
end

local function TrySetupHooks()
	if module._hooksDone then return end
	if not hooksecurefunc then return end
	local updated = false
	if type(_G.ArenaEnemyFrame_UpdatePlayer) == "function" and not module._hookedArenaUpdate then
		hooksecurefunc("ArenaEnemyFrame_UpdatePlayer", function(frame)
			ColorArenaHealthByClass(frame)
		end)
		module._hookedArenaUpdate = true
		updated = true
	end
	if type(_G.UnitFrameHealthBar_Update) == "function" and not module._hookedUFHB then
		hooksecurefunc("UnitFrameHealthBar_Update", function(bar)
			if not bar then return end
			local owner = bar:GetParent()
			if not owner or not owner.GetName then return end
			local name = owner:GetName()
			if name and name:match("^ArenaEnemyFrame%d+$") then
				ColorArenaHealthByClass(owner)
			end
		end)
		module._hookedUFHB = true
		updated = true
	end
	if updated then module._hooksDone = true end
end

-- Apply or reset class coloring on all arena frames based on setting
function module:ApplyClassColoring()
	if not MAX_ARENA_ENEMIES then return end
	local db = GetDB()
	local enabled = (db == nil or db.classColorHP == nil or db.classColorHP == true)
	for i = 1, MAX_ARENA_ENEMIES do
		local frame = _G["ArenaEnemyFrame" .. i]
		if frame and frame.healthbar then
			if enabled then
				ColorArenaHealthByClass(frame)
			else
				frame.healthbar.lockColor = nil
				if UnitFrameHealthBar_Update then
					UnitFrameHealthBar_Update(frame.healthbar, frame.unit)
				end
			end
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

-- Create/ensure Blizzard_ArenaUI and attach frames under our container
function module:InitializeContainer()
	if not IsAddOnLoaded("Blizzard_ArenaUI") then
		pcall(LoadAddOn, "Blizzard_ArenaUI")
	end

	-- Сохраняем оригинальную позицию первого фрейма ДО того, как мы его изменим
	if MAX_ARENA_ENEMIES then
		local firstFrame = _G["ArenaEnemyFrame1"]
		if firstFrame and not firstArenaFramePosition then
			self:SaveOriginalArenaFramePosition()
		end
	end

	if not arenaContainer then
		arenaContainer = CreateFrame("Frame", "SarychUIArenaContainer", UIParent)
		arenaContainer:SetSize(200, 1)
		
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

	arenaContainer:SetScale(GetSetting('scale', 1.0))

	-- Parent Blizzard arena frames to our container and position first frame like sArena
	if MAX_ARENA_ENEMIES then
		for i = 1, MAX_ARENA_ENEMIES do
			local frame = _G["ArenaEnemyFrame" .. i]
			local pet = _G["ArenaEnemyFrame" .. i .. "PetFrame"]
			if frame then
				frame:SetParent(arenaContainer)
				if i == 1 then
					frame:ClearAllPoints()
					frame:SetPoint("TOP", arenaContainer, "BOTTOM", 0, -8)
				end
				ArenaEnemyFrame_UpdatePlayer(frame, true)
				ColorArenaHealthByClass(frame)
			end
			if pet then
				pet:SetParent(arenaContainer)
			end
		end
	end

	TrySetupHooks()
end

-- Ensure container position matches DB immediately
function module:ApplyContainerPosition()
    local db = GetDB(); if not db then return end
    if not arenaContainer then return end
    
    -- Проверяем, не происходит ли сейчас drag или только что был drag - если да, не применяем позицию
    -- Это предотвращает перезапись позиции во время drag и сразу после него
    if ArenaDragMode then
        if ArenaDragMode:IsMoving() or ArenaDragMode:JustDragged() then
            return
        end
    end
    
    -- Вычисляем дефолтную позицию если еще не вычислена
    if not arenaDefaultPosition then
        self:CalculateDefaultContainerPosition()
    end
    
    -- Проверяем, являются ли координаты в БД offset (от сброса) или абсолютными (от drag)
    -- Правило: offset ТОЛЬКО если координаты = 0,0 (это сброс)
    -- ВСЕ остальное - абсолютные координаты от drag
    local xOfs = db.arenaX
    local yOfs = db.arenaY
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
        local point = db.arenaA or (arenaDefaultPosition and arenaDefaultPosition.point) or 'RIGHT'
        local relativePoint = db.arenaR or (arenaDefaultPosition and arenaDefaultPosition.relativePoint) or 'RIGHT'
        
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
end

function module:DeleteArenaFrames()
	if not MAX_ARENA_ENEMIES then return end
	for i = 1, MAX_ARENA_ENEMIES do
		local frame = _G["ArenaEnemyFrame" .. i]
		local pet = _G["ArenaEnemyFrame" .. i .. "PetFrame"]
		if frame then
			frame:Hide()
			frame:SetParent(nil)
		end
		if pet then
			pet:Hide()
			pet:SetParent(nil)
		end
	end
end

-- Restore arena frames to default Blizzard state
function module:RestoreArenaFrames()
	if not MAX_ARENA_ENEMIES then return end
	if InCombatLockdown() then 
		-- Schedule restore after combat
		C_Timer.After(0.1, function() self:RestoreArenaFrames() end)
		return
	end
	
	-- Ensure Blizzard_ArenaUI is loaded
	if not IsAddOnLoaded("Blizzard_ArenaUI") then
		pcall(LoadAddOn, "Blizzard_ArenaUI")
	end
	
	-- Restore all frames to UIParent first
	for i = 1, MAX_ARENA_ENEMIES do
		local frame = _G["ArenaEnemyFrame" .. i]
		local pet = _G["ArenaEnemyFrame" .. i .. "PetFrame"]
		if frame then
			frame:SetParent(UIParent)
		end
		if pet then
			pet:SetParent(UIParent)
		end
	end
	
	-- Restore first frame to original position if we saved it
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
	
	-- Remove class color lock from healthbars and let Blizzard update them
	for i = 1, MAX_ARENA_ENEMIES do
		local frame = _G["ArenaEnemyFrame" .. i]
		if frame and frame.healthbar then
			frame.healthbar.lockColor = nil
			-- Let Blizzard update healthbar
			if UnitFrameHealthBar_Update then
				UnitFrameHealthBar_Update(frame.healthbar, frame.unit)
			end
		end
	end
	
	-- Let Blizzard handle visibility and positioning of remaining frames
	-- Blizzard will show/hide frames based on arena status
end

function module:HideArenaEnemyFrames()
	if InCombatLockdown() then return end
	if ArenaEnemyBackground then ArenaEnemyBackground:Hide() end
	if not MAX_ARENA_ENEMIES then return end
	for i = 1, MAX_ARENA_ENEMIES do
		local frame = _G["ArenaEnemyFrame" .. i]
		if frame then
			ArenaEnemyFrame_OnEvent(frame, "ARENA_OPPONENT_UPDATE", frame.unit, "cleared")
			local pet = _G["ArenaEnemyFrame" .. i .. "PetFrame"]
			if pet then pet:Hide() end
			ArenaEnemyFrame_UpdatePlayer(frame)
		end
		
		-- Hide test trinket icons
		for _, suffix in ipairs({"Trinket1", "Racial"}) do
			local trinketName = "SarychUIArenaTestTrinket" .. i .. suffix
			local trinket = _G[trinketName]
			if trinket then
				trinket:Hide()
				if trinket.Icon then
					trinket.Icon:Hide()
				end
			end
		end
	end
end

function module:Test(numOpponents)
	if self:IsGladiusExMode() then return end
	if InCombatLockdown() then return end
	numOpponents = tonumber(numOpponents)
	if not numOpponents or numOpponents < 1 or numOpponents > 5 then return end
    -- Ensure container is at the latest saved position before visualizing tests
    self:ApplyContainerPosition()
	self:HideArenaEnemyFrames()
	local showPets = (SHOW_ARENA_ENEMY_PETS == "1")
	local instanceType = select(2, IsInInstance())
	for i = 1, numOpponents do
		local frame = _G["ArenaEnemyFrame" .. i]
		if frame then
			if instanceType ~= "pvp" then
				frame:SetPoint("RIGHT", frame:GetParent(), "RIGHT", -2, 0)
			else
				frame:SetPoint("RIGHT", frame:GetParent(), "RIGHT", -18, 0)
			end
			ArenaEnemyFrame_SetMysteryPlayer(frame)
		end
		if showPets then
			local pet = _G["ArenaEnemyFrame" .. i .. "PetFrame"]
			if pet then
				pet:Show()
				local tex = _G["ArenaEnemyFrame" .. i .. "PetFramePortrait"]
				if tex then tex:SetTexture("Interface\\CharacterFrame\\TempPortrait") end
			end
		end
	end
	if (GetCVarBool and GetCVarBool("showPartyBackground")) or SHOW_PARTY_BACKGROUND == "1" then
		if ArenaEnemyBackground and _G["ArenaEnemyFrame" .. numOpponents .. "PetFrame"] then
			ArenaEnemyBackground:Show()
			ArenaEnemyBackground:SetPoint("BOTTOMLEFT", "ArenaEnemyFrame" .. numOpponents .. "PetFrame", "BOTTOMLEFT", -15, -10)
		end
	end
	
	-- Show trinket and racial icons in test mode (with delay to ensure frames are set up)
	local db = GetDB()
	if db and db.Trinkets then
		local updateFrame = CreateFrame("Frame")
		local checkCount = 0
		updateFrame:SetScript("OnUpdate", function(self, elapsed)
			checkCount = checkCount + 1
			if checkCount >= 2 then
				self:SetScript("OnUpdate", nil)
				if module.ShowTestTrinkets then
					module:ShowTestTrinkets(numOpponents, db.Trinkets)
				end
			end
		end)
	end
end

-- Show trinket and racial icons for test mode
function module:ShowTestTrinkets(numOpponents, trinketsDB)
	if not trinketsDB then return end
	if InCombatLockdown() then return end
	
	local trinketsEnabled = trinketsDB.enabled == true
	local racialEnabled = trinketsDB.racialEnabled == true
	local scale = trinketsDB.scale or 1.0
	
	-- Test race (using Orc for example)
	local testRace = "Orc"
	local trinketTexture = "Interface\\Icons\\inv_jewelry_trinketpvp_02" -- Horde trinket
	local racialTexture = "Interface\\Icons\\racial_orc_berserkerstrength" -- Orc racial
	
	for i = 1, numOpponents do
		local frame = _G["ArenaEnemyFrame" .. i]
		if not frame then break end
		
		-- Handle trinket icon
		local trinket = self:GetOrCreateTestTrinket(frame, i, "Trinket1")
		if trinket then
			if trinketsEnabled then
				trinket:SetScale(scale)
				trinket.Icon.Texture:SetTexture(trinketTexture)
				trinket.Icon:Show()
				trinket:Show()
				trinket:SetCooldown(0, -1)
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
			if racialEnabled then
				racial:SetScale(scale)
				racial.Icon.Texture:SetTexture(racialTexture)
				racial.Icon:Show()
				racial:Show()
				racial:SetCooldown(0, -1)
				
				-- Перепозиционируем расовую в зависимости от состояния тринкетов
				racial:ClearAllPoints()
				if trinketsEnabled and trinket then
					-- Тринкеты включены - расовая справа от тринкета
					racial:SetPoint("LEFT", trinket, "RIGHT", 5, 0)
				else
					-- Тринкеты выключены - расовая на месте тринкета
					racial:SetPoint("LEFT", frame, "RIGHT", 2, -2)
				end
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
		trinket = CreateFrame("Cooldown", trinketName, frame)
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
		trinket.Icon.Texture:SetAllPoints()
		trinket.Icon.Texture:SetTexCoord(0, 1, 0, 1)
		
		-- Enable mouse for testing
		trinket:EnableMouse(true)
		trinket:SetMovable(true)
	end
	
	return trinket
end

-- ============================================
-- Distance-based alpha transparency
-- ============================================

-- Helper function to check if AwesomeWotlk mode is enabled
local function UseAwesomeWotlk()
	local db = GetDB()
	return db and db.useAwesomeWotlk == true
end

-- Helper function to check if autolos is enabled
local function IsAutolosEnabled()
	-- Check global variable first
	if _G.autolosEnabled == false then
		return false
	end
	
	-- Check SarychUI database
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.autolos then
		return SarychUI.db.profile.addons.autolos.enabled ~= false
	end
	
	-- Default to true if autolosEnabled is not explicitly false
	return (_G.autolosEnabled ~= false)
end

-- Reused buffer so WorldFrame walks call GetChildren() once per scan instead of
-- once per index (these run up to 10x/sec).
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

-- Helper function to check if autolos is working (has nameplates with range property)
local function IsAutolosWorking()
	if not IsAutolosEnabled() then
		return false
	end
	
	-- Check if there are any nameplates with range property (autolos sets this)
	local numChildren = CollectWorldChildren(WorldFrame:GetChildren())
	for i = 1, numChildren do
		local frame = worldChildren[i]
		if frame and frame.range and frame.guid then
			-- Found at least one nameplate with range property, autolos is working
			return true
		end
	end
	
	return false
end

-- Helper function to get nameplate by GUID (with caching)
local function GetNamePlateByGUID(guid)
	if not guid then return nil end
	
	-- Check cache first (cache is valid for 0.5 seconds)
	local cacheEntry = nameplateCache[guid]
	local cacheTime = nameplateCacheTime[guid]
	local currentTime = GetTime()
	
	if cacheEntry and cacheTime and (currentTime - cacheTime) < 0.5 then
		-- Verify cached nameplate is still valid
		if cacheEntry.range or (cacheEntry.UnitFrame and cacheEntry.UnitFrame.unit) then
			return cacheEntry
		else
			-- Cache entry is invalid, remove it
			nameplateCache[guid] = nil
			nameplateCacheTime[guid] = nil
		end
	end
	
	-- Cache miss or expired, search for nameplate
	local nameplate = nil
	
	-- Try C_NamePlate if AwesomeWotlk is enabled
	if UseAwesomeWotlk() and C_NamePlate then
		-- C_NamePlate doesn't have GetNamePlateByGUID, so we need to iterate
		local nameplates = C_NamePlate.GetNamePlates()
		if nameplates then
			for _, np in ipairs(nameplates) do
				if np and np.UnitFrame and np.UnitFrame.unit then
					local nameplateGUID = UnitGUID(np.UnitFrame.unit)
					if nameplateGUID == guid then
						nameplate = np
						break
					end
				end
			end
		end
	end
	
	-- Fallback: search through WorldFrame children (like autolos does)
	if not nameplate then
		local numChildren = CollectWorldChildren(WorldFrame:GetChildren())
		for i = 1, numChildren do
			local frame = worldChildren[i]
			if frame and frame.guid and frame.guid == guid and frame.range then
				nameplate = frame
				break
			end
		end
	end
	
	-- Update cache if nameplate found
	if nameplate then
		nameplateCache[guid] = nameplate
		nameplateCacheTime[guid] = currentTime
	end
	
	return nameplate
end

-- Clear nameplate cache
local function ClearNameplateCache()
	nameplateCache = {}
	nameplateCacheTime = {}
end

-- Function to get distance value from nameplate (1 if > 40, 0 if <= 40)
local function GetDistanceValue(nameplate)
	if not nameplate then return 1 end -- Default to 1 (far) if no nameplate
	
	local range = nil
	
	-- Try to get range from nameplate
	if nameplate.range then
		-- Direct range property (from autolos)
		range = nameplate.range
	elseif nameplate.UnitFrame and nameplate.UnitFrame.unit then
		-- For C_NamePlate, we might need to check if range is available
		-- In WoW 3.3.5, nameplates have range property set by the game
		-- Check if the frame has range property
		if nameplate.UnitFrame.range then
			range = nameplate.UnitFrame.range
		end
	end
	
	-- If range is 0 or nil, consider it as "not available" (default to 1)
	if not range or range == 0 then
		return 1
	end
	
	-- Return 1 if > 40, 0 if <= 40
	return (range > 40) and 1 or 0
end

-- Function to update arena frame alpha based on distance
local function UpdateArenaFrameDistanceAlpha()
	local db = GetDB()
	if not db or not db.enabled then return end
	if not db.useAwesomeWotlk or not db.distanceAlpha then return end
	
	-- Cheap gates first: outside an arena there is nothing to update, and the
	-- autolos probe below walks every WorldFrame child.
	local instanceType = select(2, IsInInstance())
	if instanceType ~= "arena" then return end
	
	if not MAX_ARENA_ENEMIES then return end
	
	-- Check if autolos is enabled and working
	if not IsAutolosEnabled() or not IsAutolosWorking() then return end
	
	-- Update each arena frame
	for i = 1, MAX_ARENA_ENEMIES do
		local frame = _G["ArenaEnemyFrame" .. i]
		if frame and frame.unit and UnitExists(frame.unit) then
			local arenaGUID = UnitGUID(frame.unit)
			if arenaGUID then
				local nameplate = GetNamePlateByGUID(arenaGUID)
				local distanceValue = GetDistanceValue(nameplate)
				
				-- If distanceValue == 0 (<= 40 yards), set alpha to 1.0 (fully opaque)
				-- If distanceValue == 1 (> 40 yards), set alpha to 0.5 (50% transparent)
				local targetAlpha = (distanceValue == 0) and 1.0 or 0.5
				frame:SetAlpha(targetAlpha)
			else
				-- If no GUID, default to full opacity
				frame:SetAlpha(1.0)
			end
		end
	end
end

-- Initialize distance alpha update frame
local function InitializeDistanceAlphaUpdate()
	if distanceAlphaUpdateFrame then return end
	
	-- Clear cache when initializing
	ClearNameplateCache()
	
	distanceAlphaUpdateFrame = CreateFrame("Frame")
	distanceAlphaUpdateFrame:SetScript("OnUpdate", function(self, elapsed)
		self.updateTime = (self.updateTime or 0) + elapsed
		-- Update every 0.1 seconds (10 times per second)
		if self.updateTime >= 0.1 then
			self.updateTime = 0
			UpdateArenaFrameDistanceAlpha()
		end
	end)
end

-- Cleanup distance alpha update frame
local function CleanupDistanceAlphaUpdate()
	if distanceAlphaUpdateFrame then
		distanceAlphaUpdateFrame:SetScript("OnUpdate", nil)
		distanceAlphaUpdateFrame = nil
	end
	
	-- Clear cache when cleaning up
	ClearNameplateCache()
	
	-- Reset all arena frame alphas to 1.0
	if MAX_ARENA_ENEMIES then
		for i = 1, MAX_ARENA_ENEMIES do
			local frame = _G["ArenaEnemyFrame" .. i]
			if frame then
				frame:SetAlpha(1.0)
			end
		end
	end
end

-- Apply position and scale based on DB and DragMode
function module:ApplySettings()
	if self:IsGladiusExMode() then return end
	local db = GetDB()
	if not db or not db.enabled then return end
	
	-- Проверяем, не происходит ли сейчас drag или только что был drag - если да, не применяем позицию
	-- Это предотвращает перезапись позиции во время drag и сразу после него
	local shouldApplyPosition = true
	if ArenaDragMode then
		if ArenaDragMode:IsMoving() or ArenaDragMode:JustDragged() then
			shouldApplyPosition = false
		end
	end
	
	-- Применяем позицию только если не происходит drag
	if shouldApplyPosition then
		self:ApplyContainerPosition()
	end
	
	if arenaContainer then
		arenaContainer:SetScale(db.scale or 1.0)
	end

	-- Apply class coloring immediately according to setting
	self:ApplyClassColoring()
	
	-- Initialize or cleanup distance alpha update based on settings
	if db.useAwesomeWotlk and db.distanceAlpha then
		InitializeDistanceAlphaUpdate()
	else
		CleanupDistanceAlphaUpdate()
	end
	
	-- Если тестовый режим активен, обновляем отображение иконок тринкетов
	if db.testMode and db.testMode > 0 and db.Trinkets then
		local updateFrame = CreateFrame("Frame")
		updateFrame:SetScript("OnUpdate", function(self)
			self:SetScript("OnUpdate", nil)
			if module.ShowTestTrinkets then
				module:ShowTestTrinkets(db.testMode, db.Trinkets)
			end
		end)
	end
	
	-- Используем локальный ArenaDragMode или fallback на глобальный
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
	
	-- Пробуем использовать локальный ArenaDragMode
	if ArenaDragMode and arenaContainer then
		-- Включаем/отключаем режим редактирования
		if showDrag then
			ArenaDragMode:Enable(arenaContainer, {
				dragText = "Арена",
				dragPoint = "TOPRIGHT",
				dragOffsetX = 0,
				dragOffsetY = 2.5,
				dragWidth = 280,
				dragHeight = 225,
			}, showDrag, showGrid, function(point, relativePoint, xOfs, yOfs)
				-- Callback при изменении позиции
				local db = GetDB(); if not db then return end
				
				-- Сохраняем абсолютные координаты как есть
				db.arenaA = point
				db.arenaR = relativePoint
				db.arenaX = xOfs
				db.arenaY = yOfs
				
				-- If test mode is active, re-run to reflect new anchor instantly
				if db.testMode and db.testMode > 0 then
					local updateFrame = CreateFrame("Frame")
					updateFrame:SetScript("OnUpdate", function(self)
						self:SetScript("OnUpdate", nil)
						if module.Test then
							module:Test(db.testMode)
						end
					end)
				end
			end)
		else
			ArenaDragMode:Disable(arenaContainer)
		end
		
		ArenaDragMode:ShowGrid(showGrid and showDrag)
	else
		-- Fallback на глобальный DragMode если локальный не загрузился
		if SarychUI.DragMode then
			-- Регистрируем фрейм если еще не зарегистрирован
			if not SarychUI.DragMode:GetFrameData("arenaContainer") then
				self:RegisterDrag()
			end
			
			SarychUI.DragMode:EnableEditMode("arenaContainer", showDrag, showDrag, showGrid)
			SarychUI.DragMode:ShowGrid(showGrid and showDrag)
		end
	end
end

-- Register container in DragMode system (legacy - используется локальный ArenaDragMode)
function module:RegisterDrag()
	-- Локальный ArenaDragMode инициализируется в ApplySettings
	-- Эта функция оставлена для совместимости
	if not arenaContainer then return end
	
	-- Вычисляем дефолтную позицию если еще не вычислена
	if not arenaDefaultPosition then
		self:CalculateDefaultContainerPosition()
	end
end

-- Public API used by options
function module:SetScale(value)
	local db = GetDB(); if not db then return end
	value = tonumber(value) or 1.0
	db.scale = value
	if arenaContainer then
		arenaContainer:SetScale(value)
	end
end

-- Lifecycle
function module:Enable()
	if self:IsGladiusExMode() then return end
	local db = GetDB(); if not db or not db.enabled then return end
	
	-- Сбрасываем тестовый режим при загрузке/перезагрузке
	if db.testMode and db.testMode > 0 then
		db.testMode = 0
		-- Скрываем тестовые фреймы
		if self.HideArenaEnemyFrames then
			self:HideArenaEnemyFrames()
		end
	end
	
    self:InitializeContainer()
	self:RegisterDrag()
	self:ApplySettings()
    
    -- sArena-like trinkets lifecycle
    module.Trinkets:RegisterEvent("PLAYER_ENTERING_WORLD")
    module.Trinkets:RegisterEvent("PLAYER_LEAVING_WORLD")
    module.Trinkets:Initialize()

	if not eventFrame then
		eventFrame = CreateFrame("Frame")
		eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
		eventFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
		eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
		eventFrame:SetScript("OnEvent", function(_, event)
			if event == "PLAYER_ENTERING_WORLD" then
				-- Сбрасываем тестовый режим при входе в мир
				local db = GetDB()
				if db and db.testMode and db.testMode > 0 then
					db.testMode = 0
					if module.HideArenaEnemyFrames then
						module:HideArenaEnemyFrames()
					end
				end
				
				local instanceType = select(2, IsInInstance())
				if instanceType == "arena" then
					self:DeleteArenaFrames()
					self:InitializeContainer()
				else
					-- Cleanup distance alpha when leaving arena
					CleanupDistanceAlphaUpdate()
				end
			elseif event == "PLAYER_LEAVING_WORLD" then
				self:DeleteArenaFrames()
				CleanupDistanceAlphaUpdate()
			elseif event == "ZONE_CHANGED_NEW_AREA" then
				-- Check if we're still in arena
				local instanceType = select(2, IsInInstance())
				if instanceType ~= "arena" then
					CleanupDistanceAlphaUpdate()
				else
					-- Clear cache when entering arena (new opponents)
					ClearNameplateCache()
				end
			end
		end)
	end
end

function module:Disable()
	-- DragMode cleanup (локальный ArenaDragMode)
	if ArenaDragMode and arenaContainer then
		ArenaDragMode:Disable(arenaContainer)
	end
	-- Fallback на глобальный DragMode
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
	
	-- Cleanup distance alpha update
	CleanupDistanceAlphaUpdate()
end

function module:RefreshConfig()
	self:Disable()
	self:Enable()
end


