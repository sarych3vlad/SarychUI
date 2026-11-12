-- BigDebuffs by Jordon
-- Backported and general improvements by Konjunktur and Friskes
-- Spell list and minor improvements by Apparent and Friskes

-- Global enabled state
BigDebuffsEnabled = BigDebuffsEnabled or true;

-- Function to check if addon is enabled
local function IsEnabled()
	if BigDebuffsEnabled == false then return false end
	local extension = SarychUI and SarychUI.extensions and SarychUI.extensions.aura_tracking
	if extension and not extension:IsEnabled() then return false end
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.BigDebuffs then
		return SarychUI.db.profile.addons.BigDebuffs.enabled ~= false;
	end
	return BigDebuffsEnabled;
end

BigDebuffs = LibStub("AceAddon-3.0"):NewAddon("BigDebuffs", "AceEvent-3.0", "AceHook-3.0", "AceTimer-3.0")
BigDebuffs:SetEnabledState(false)
local L = LibStub("AceLocale-3.0"):GetLocale("BigDebuffs")
local timerAppearance = {
	compactUnits = true,
	baseColor = {1, 1, 1, 1},
	minuteSuffix = L["m"],
	hourSuffix = L["h"],
}
local SML = LibStub:GetLibrary("LibSharedMedia-3.0")

--Lua functions
local _G = _G
local select, unpack, pairs, type, ceil = select, unpack, pairs, type, ceil
local tinsert, gsub = table.insert, string.gsub

--WoW API / Variables
local CreateFrame = CreateFrame
local IsInInstance = IsInInstance
local UnitGUID = UnitGUID
local GetTime = GetTime
local UIParent = UIParent
local InCombatLockdown = InCombatLockdown
local LoadAddOn = LoadAddOn
local GetAddOnMetadata = GetAddOnMetadata
local GetSpellInfo = GetSpellInfo
local SetPortraitToTexture = SetPortraitToTexture
local AuraTracking = SarychUI.AuraTracking
local UnitDebuff, UnitBuff = AuraTracking.UnitDebuff, AuraTracking.UnitBuff
local UnitAura = AuraTracking.UnitAura
local GetUnitName = GetUnitName

local InArena = function() return (select(2,IsInInstance() ) == "arena") end

local function IsGladiusArenaUnit(unit)
	if not unit or not unit:match("^arena%d+$") then return false end
	local modules = SarychUI and SarychUI.db and SarychUI.db.profile
		and SarychUI.db.profile.modules
	local arena = modules and modules.arena
	return arena and arena.enabled and arena.frameType == "gladius"
end

local defaults = {
	profile = {
		unitFrames = {
			enabled = true,
			circleCooldown = true,
			hideCDanimation = false,
			drawEdge = true,
			customTimer = true,     -- Изменено на true
			hideBorder = false,
			interruptIcon = true,
			timeThreshold = 5,
			customTimerSize = 3.3,
			font = "Friz Quadrata TT",
			outline = "OUTLINE",

			player = {
				enabled = true,
				inArena = false,
				duplicatePlayer = true,
				anchor = "auto",   -- Изменено на "auto"
				size = 44,
				alpha = 1,
				immunities = true,
				cc = true,
				silence = true,
				interrupts = true,
				roots = true,
				disarm = true,
				buffs_defensive = true,  -- Изменено на true
				buffs_offensive = true,  -- Изменено на true
				buffs_other = true,      -- Изменено на true
				snare = true,            -- Изменено на true
			},
			playerFAKE = {
				enabled = false,        -- Добавлено
				inArena = false,        -- Добавлено
				anchor = "auto",        -- Добавлено
				size = 44,              -- Добавлено
				alpha = 1,              -- Добавлено
				immunities = true,      -- Добавлено
				cc = true,              -- Добавлено
				silence = true,         -- Добавлено
				interrupts = true,      -- Добавлено
				roots = true,           -- Добавлено
				disarm = true,          -- Добавлено
				buffs_defensive = true, -- Добавлено
				buffs_offensive = true, -- Добавлено
				buffs_other = true,     -- Добавлено
				snare = true,           -- Добавлено
			},
			pet = {
				enabled = true,
				inArena = false,
				anchor = "auto",  -- Изменено на "auto"
				position = {
					"TOPLEFT",
					nil,
					"TOPLEFT",
					231.2065903962022,
					-188.9598644181945,
				},
				size = 55.5,
				alpha = 1,

				immunities = false,
				cc = true,
				silence = false,
				interrupts = false,
				roots = true,
				disarm = false,
				buffs_defensive = false,
				buffs_offensive = false,
				buffs_other = false,
				snare = true,
			},
			target = {
				enabled = true,
				inArena = false,
				enabledtargettarget = true,
				anchor = "auto",
				size = 50,
				alpha = 1,

				immunities = true,
				cc = true,
				silence = true,
				interrupts = true,
				roots = true,
				disarm = true,
				buffs_defensive = true,  -- Изменено на true
				buffs_offensive = true,  -- Изменено на true
				buffs_other = true,      -- Изменено на true
				snare = true,            -- Изменено на true
			},
			targettarget = {
				enabled = true,         -- Добавлено
				inArena = false,        -- Добавлено
				anchor = "auto",        -- Добавлено
				size = 50,              -- Добавлено
				alpha = 1,              -- Добавлено
				immunities = true,      -- Добавлено
				cc = true,              -- Добавлено
				silence = true,         -- Добавлено
				interrupts = true,      -- Добавлено
				roots = true,           -- Добавлено
				disarm = true,          -- Добавлено
				buffs_defensive = true, -- Добавлено
				buffs_offensive = true, -- Добавлено
				buffs_other = true,     -- Добавлено
				snare = true,           -- Добавлено
			},
			focus = {
				enabled = true,
				inArena = false,
				enabledfocustarget = true,
				anchor = "auto",
				size = 50,
				alpha = 1,

				immunities = true,
				cc = true,
				silence = true,
				interrupts = true,
				roots = true,
				disarm = true,
				buffs_defensive = true,  -- Изменено на true
				buffs_offensive = true,  -- Изменено на true
				buffs_other = true,      -- Изменено на true
				snare = true,            -- Изменено на true
			},
			focustarget = {
				enabled = true,         -- Добавлено
				inArena = false,        -- Добавлено
				anchor = "auto",        -- Добавлено
				size = 50,              -- Добавлено
				alpha = 1,              -- Добавлено
				immunities = true,      -- Добавлено
				cc = true,              -- Добавлено
				silence = true,         -- Добавлено
				interrupts = true,      -- Добавлено
				roots = true,           -- Добавлено
				disarm = true,          -- Добавлено
				buffs_defensive = true, -- Добавлено
				buffs_offensive = true, -- Добавлено
				buffs_other = true,     -- Добавлено
				snare = true,           -- Добавлено
			},
			party = {
				enabled = true,
				inArena = true,
				anchor = "auto",
				size = 50,
				alpha = 1,

				immunities = true,
				cc = true,
				silence = true,
				interrupts = true,
				roots = true,
				disarm = true,
				buffs_defensive = false,
				buffs_offensive = false,
				buffs_other = false,
				snare = false,
			},
			partypet = {
				enabled = true,         -- Изменено на true
				inArena = true,
				anchor = "auto",
				size = 50,
				alpha = 1,

				immunities = true,
				cc = true,
				silence = true,
				interrupts = true,
				roots = true,
				disarm = true,
				buffs_defensive = true, -- Изменено на true
				buffs_offensive = true, -- Изменено на true
				buffs_other = true,     -- Изменено на true
				snare = true,           -- Изменено на true
			},
			arena = {
				enabled = true,
				anchor = "auto",
				size = 50,
				alpha = 1,

				immunities = true,
				cc = true,
				silence = true,
				interrupts = true,
				roots = true,
				disarm = true,
				buffs_defensive = true, -- Изменено на true
				buffs_offensive = true, -- Изменено на true
				buffs_other = true,     -- Изменено на true
				snare = true,           -- Изменено на true
			},
			arenapet = {
				enabled = true,
				anchor = "auto",
				size = 50,
				alpha = 1,

				immunities = true,
				cc = true,
				silence = true,
				interrupts = true,
				roots = true,
				disarm = true,
				buffs_defensive = false,
				buffs_offensive = false,
				buffs_other = false,
				snare = false,
			},
		},
		priority = {
			immunities = 65,
			cc = 70,
			silence = 60,
			interrupts = 55,
			roots = 50,
			disarm = 45,
			buffs_defensive = 40,
			buffs_offensive = 35,
			buffs_other = 30,
			snare = 25,
		},
		spells = {
			[33786] = {
				priority = 100,
				customPriority = true,
			},
		},
	},
}

BigDebuffs.Spells = SarychUI.Data.AuraTracking:CreateView("bigDebuffs")
-- Match only explicit spell IDs/rank links. Unrelated effects can share a
-- localized name (e.g. enchant proc 59620 and druid Berserk 50334).

local units = {
	"player",
	"playerFAKE",
	"pet",
	"target",
	"targettarget",
	"focus",
	"focustarget",
	"party1",
	"party2",
	"party3",
	"party4",
	"partypet1",
	"partypet2",
	"partypet3",
	"partypet4",
	"arena1",
	"arena2",
	"arena3",
	"arena4",
	"arena5",
	"arenapet1",
	"arenapet2",
	"arenapet3",
	"arenapet4",
	"arenapet5",
}

local GetAnchor = {
    ElvUIFrames = function(anchor)
        local anchors, unit = BigDebuffs.anchors
        for u,configAnchor in pairs(anchors.ElvUI.units) do
            if anchor == configAnchor then
                unit = u
                break
            end
        end
        if unit and unit:match("party") then
            local unitGUID = UnitGUID(unit)
            for i = 1,5,1 do
                local elvUIFrame = _G["ElvUF_PartyGroup1UnitButton"..i]
                if elvUIFrame and elvUIFrame:IsVisible() and elvUIFrame.unit then
                    if unitGUID == UnitGUID(elvUIFrame.unit) then
                        return elvUIFrame
                    end
                end
            end
            return
        end
        return _G[anchor]
    end,
	ShadowedUnitFrames = function(anchor)
		local frame = _G[anchor]
		if not frame then return end
		if frame.portrait and frame.portrait:IsShown() then
			return frame.portrait, frame
		else
			return frame, frame, true
		end
	end,
	XPerl = function(anchor)
		local frame = _G[anchor]
		if not frame then return end
		if frame:IsShown() then
			return frame, frame
		else
			frame = frame:GetParent()
			return frame, frame, true
		end
	end,
}

local anchors = {
	["ElvUI"] = {
		func = GetAnchor.ElvUIFrames,
		noPortrait = true,
		alignLeft = true,
		units = {
			player       = "ElvUF_Player",
			playerFAKE   = "ElvUF_Player",
			pet          = "ElvUF_Pet",
			target       = "ElvUF_Target",
			targettarget = "ElvUF_TargetTarget",
			focus        = "ElvUF_Focus",
			focustarget  = "ElvUF_FocusTarget",
			party1       = "ElvUF_PartyGroup1UnitButton1",
			party2       = "ElvUF_PartyGroup1UnitButton2",
			party3       = "ElvUF_PartyGroup1UnitButton3",
			party4       = "ElvUF_PartyGroup1UnitButton4",
			arena1       = "ElvUF_Arena1",
			arena2       = "ElvUF_Arena2",
			arena3       = "ElvUF_Arena3",
			arena4       = "ElvUF_Arena4",
			arena5       = "ElvUF_Arena5",
		},
	},
	["Shadowed Unit Frames"] = {
		func = GetAnchor.ShadowedUnitFrames,
		alignLeft = true,
		units = {
			player       = "SUFUnitplayer",
			playerFAKE   = "SUFUnitplayer",
			pet          = "SUFUnitpet",
			target       = "SUFUnittarget",
			targettarget = "SUFUnittargettarget",
			focus        = "SUFUnitfocus",
			focustarget  = "SUFUnitfocustarget",
			party1       = "SUFHeaderpartyUnitButton1",
			party2       = "SUFHeaderpartyUnitButton2",
			party3       = "SUFHeaderpartyUnitButton3",
			party4       = "SUFHeaderpartyUnitButton4",
			partypet1    = "SUFChildpartypet1",
			partypet2    = "SUFChildpartypet2",
			partypet3    = "SUFChildpartypet3",
			partypet4    = "SUFChildpartypet4",
			arena1       = "SUFHeaderarenaUnitButton1",
			arena2       = "SUFHeaderarenaUnitButton2",
			arena3       = "SUFHeaderarenaUnitButton3",
			arena4       = "SUFHeaderarenaUnitButton4",
			arena5       = "SUFHeaderarenaUnitButton5",
			arenapet1    = "SUFChildarenapet1",
			arenapet2    = "SUFChildarenapet2",
			arenapet3    = "SUFChildarenapet3",
			arenapet4    = "SUFChildarenapet4",
			arenapet5    = "SUFChildarenapet5",
		},
	},
	["XPerl"] = {
		func = GetAnchor.XPerl,
		alignLeft = true,
		units = {
			player       = "XPerl_PlayerportraitFrame",
			playerFAKE   = "XPerl_PlayerportraitFrame",
			pet          = "XPerl_Player_PetportraitFrame",
			target       = "XPerl_TargetportraitFrame",
			targettarget = "Xperl_TargetTarget", -- Не имеет портрета
			focus        = "XPerl_FocusportraitFrame",
			focustarget  = "Xperl_FocusTarget", -- Не имеет портрета
			party1       = "XPerl_party1portraitFrame",
			party2       = "XPerl_party2portraitFrame",
			party3       = "XPerl_party3portraitFrame",
			party4       = "XPerl_party4portraitFrame",
		},
	},
	["Gladius"] = { -- просто так прицепиться не выйдет, необходимо создавать фреймы в самом гладиусе.
		units = {
			arena1    = "GladiusButtonFrame1ClassIcon",
			arena2    = "GladiusButtonFrame2ClassIcon",
			arena3    = "GladiusButtonFrame3ClassIcon",
			arena4    = "GladiusButtonFrame4ClassIcon",
			arena5    = "GladiusButtonFrame5ClassIcon",
			arenapet1 = "GladiusPetButtonFrame1petIcon",
			arenapet2 = "GladiusPetButtonFrame2petIcon",
			arenapet3 = "GladiusPetButtonFrame3petIcon",
			arenapet4 = "GladiusPetButtonFrame4petIcon",
			arenapet5 = "GladiusPetButtonFrame5petIcon",
		},
	},
	["Blizzard"] = {
		units = {
			player       = "PlayerPortrait",
			playerFAKE   = "PlayerPortrait",
			pet          = "PetPortrait",
			target       = "TargetFramePortrait",
			targettarget = "TargetFrameToTPortrait",
			focus        = "FocusFramePortrait",
			focustarget  = "FocusFrameToTPortrait",
			party1       = "PartyMemberFrame1Portrait",
			party2       = "PartyMemberFrame2Portrait",
			party3       = "PartyMemberFrame3Portrait",
			party4       = "PartyMemberFrame4Portrait",
			partypet1    = "PartyMemberFrame1PetFramePortrait",
			partypet2    = "PartyMemberFrame2PetFramePortrait",
			partypet3    = "PartyMemberFrame3PetFramePortrait",
			partypet4    = "PartyMemberFrame4PetFramePortrait",
			arena1       = "ArenaEnemyFrame1ClassPortrait",
			arena2       = "ArenaEnemyFrame2ClassPortrait",
			arena3       = "ArenaEnemyFrame3ClassPortrait",
			arena4       = "ArenaEnemyFrame4ClassPortrait",
			arena5       = "ArenaEnemyFrame5ClassPortrait",
			arenapet1    = "ArenaEnemyFrame1PetFramePortrait",
			arenapet2    = "ArenaEnemyFrame2PetFramePortrait",
			arenapet3    = "ArenaEnemyFrame3PetFramePortrait",
			arenapet4    = "ArenaEnemyFrame4PetFramePortrait",
			arenapet5    = "ArenaEnemyFrame5PetFramePortrait",
		},
	},
}
BigDebuffs.anchors = anchors

local function FillProfile(target, source)
	for key, value in pairs(source) do
		if type(value) == "table" then
			if target[key] == nil then target[key] = {} end
			if type(target[key]) == "table" then FillProfile(target[key], value) end
		elseif target[key] == nil then target[key] = value end
	end
	return target
end

function BigDebuffs:UseSUIProfile()
	local db = SarychUI.db
	if not db or not db.profile or not self.db then return end
	local profile = db.profile.auraTracking
	if not profile then
		profile = {}
		-- Import the previously active settings once; new SUI profiles use defaults.
		if not db.global.auraTrackingMigrated then FillProfile(profile, self.db.profile) end
		db.profile.auraTracking = profile
	end
	FillProfile(profile, defaults.profile)
	db.global.auraTrackingMigrated = true
	self.db.profile = profile
	if self.UnitFrames then self:Refresh() end
end

function BigDebuffs:OnInitialize()
	-- База данных должна создаваться всегда, чтобы настройки сохранялись
	self.db = LibStub("AceDB-3.0"):New("BigDebuffsDB", defaults, true)
	self:UseSUIProfile()

	self.frames = {}
	self.UnitFrames = {}
	if IsEnabled() then
		self:SetupOptions()
	end
end

function BigDebuffs:Refresh()
	for unit, frame in pairs(self.UnitFrames) do
		frame:Hide()
		frame.current = nil
		self:AttachUnitFrame(unit)
		self:UNIT_AURA(nil, unit)
	end
end

--[[local unitsToUpdate = {}
function BigDebuffs:PLAYER_REGEN_ENABLED()
	for unit, _ in pairs(unitsToUpdate) do
		self:AttachUnitFrame(unit)
	end
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	unitsToUpdate = {}
end]]

local function ShowUnitFrameIcon(frame)
	frame.icon:Show()
end

local function HideUnitFrameIcon(frame)
	frame.icon:Hide()
end

local function AttachUnitFrameIcon(frame)
	-- Use a distinct frame level, not texture sublevels, for the portrait
	-- overlay on the 3.3.5 client. Keep ownership/alpha on the BD frame.
	frame.icon:SetParent(frame)
	frame.icon:ClearAllPoints()
	frame.icon:SetAllPoints(frame)
	frame.icon:SetDrawLayer("ARTWORK", 2)
	frame.icon:SetAlpha(1)
	frame.icon:SetVertexColor(1, 1, 1)
	if frame:IsVisible() then ShowUnitFrameIcon(frame) else HideUnitFrameIcon(frame) end
end

local function SetPortraitOverlayLevel(frame)
	local parent = frame.anchor:GetParent()
	local level = parent:GetFrameLevel() + 1
	frame:SetFrameLevel(level)
	-- Target/focus artwork starts only one level above its portrait. Reserve
	-- space once, without accumulating levels on refresh or changing portraits.
	local name = parent:GetName()
	local texture = name and (_G[name .. "TextureFrameTexture"] or _G[name .. "Texture"])
	local border = texture and texture:GetParent()
	if border and border ~= parent and border:GetFrameLevel() < level + 4 then
		border:SetFrameLevel(level + 4)
	end
end

local function SetUnitFrameCooldownLevels(frame)
	-- One fixed stack: icon, swipe, edge, timer, then Blizzard artwork.
	local level = frame:GetFrameLevel()
	frame.cooldownContainer:SetFrameLevel(level)
	frame.CircleCooldown:SetFrameLevel(level)
	for _, key in ipairs({ "Cooldown", "Edge", "Bling", "TimerText" }) do
		frame.CircleCooldown[key]:SetFrameLevel(level + 1)
	end
	frame.CircleCooldown.Edge:SetFrameLevel(level + 2)
	frame.cooldown:SetFrameLevel(level + 1)
	frame.timerFrame:SetFrameLevel(level + 3)
end

function BigDebuffs:AttachUnitFrame(unit)

	if InCombatLockdown() then return end

	--[[if InCombatLockdown() then
		unitsToUpdate[unit] = true
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end]]

	local frame = self.UnitFrames[unit]
	local frameName = "BigDebuffs" .. unit .. "UnitFrame"

	if not frame then
		frame = CreateFrame("Button", frameName, UIParent, "BigDebuffsUnitFrameTemplate")
		frame.icon = _G[frameName .. "Icon"]

		frame.cooldownContainer = CreateFrame("Button", frameName .. "CooldownContainer", frame)
		self.UnitFrames[unit] = frame

		frame.CircleCooldown = CreateFrame("Frame", frameName .. "CircleCooldown", frame, "CircleCooldownFrameTemplate")
		frame.CircleCooldown:SetParent(frame.cooldownContainer)
		frame.CircleCooldown:SetFrameLevel(frame.cooldownContainer:GetParent():GetFrameLevel() + 1)
		frame.CircleCooldown:SetDrawBling(false) -- отключение анимации вспышки после завершения кд
		frame.CircleCooldown:SetAllPoints()

		-- Restore the icon's visibility when the overlay is reused.
		frame:HookScript("OnShow", ShowUnitFrameIcon)
		frame:HookScript("OnHide", HideUnitFrameIcon)
		frame.cooldownContainer:SetPoint("CENTER")

		frame.cooldown:SetParent(frame.cooldownContainer)
		frame.cooldown:SetFrameLevel(frame.cooldownContainer:GetParent():GetFrameLevel() + 1)
		frame.cooldown:SetAllPoints()

		frame.timerFrame = CreateFrame("Frame", nil, frame)
		frame.timerFrame:SetAllPoints(frame)
		frame.timerFrame:EnableMouse(false)
		frame.timer = frame.timerFrame:CreateFontString(nil, "OVERLAY")
		frame.timer:SetPoint("CENTER", frame, "CENTER")
		frame.timer:SetJustifyH("CENTER")  -- Добавлено выравнивание по центру
		frame:SetScript("OnUpdate", self.OnUpdate)

		frame:RegisterForDrag("LeftButton")
		frame:SetMovable(true)

		frame.unit = unit
	end

	local config = self.db.profile.unitFrames
	local configUnit = self.db.profile.unitFrames[unit:gsub("%d", "")]

	config["playerFAKE"].enabled = config["player"].duplicatePlayer
	if config["player"].anchor == "auto" then
		config["playerFAKE"].enabled = false
	end
	config["playerFAKE"].inArena = config["player"].inArena
	config["playerFAKE"].anchor = "auto"
	config["playerFAKE"].size = config["player"].size
	config["playerFAKE"].alpha = config["player"].alpha
	config["playerFAKE"].immunities = config["player"].immunities
	config["playerFAKE"].cc = config["player"].cc
	config["playerFAKE"].silence = config["player"].silence
	config["playerFAKE"].interrupts = config["player"].interrupts
	config["playerFAKE"].roots = config["player"].roots
	config["playerFAKE"].disarm = config["player"].disarm
	config["playerFAKE"].buffs_defensive = config["player"].buffs_defensive
	config["playerFAKE"].buffs_offensive = config["player"].buffs_offensive
	config["playerFAKE"].buffs_other = config["player"].buffs_other
	config["playerFAKE"].snare = config["player"].snare

	config["targettarget"].enabled = config["target"].enabledtargettarget
	if not config["target"].enabled then
		config["targettarget"].enabled = false
	end
	config["targettarget"].inArena = config["target"].inArena
	config["targettarget"].anchor = "auto"
	config["targettarget"].size = config["target"].size
	config["targettarget"].alpha = config["target"].alpha
	config["targettarget"].immunities = config["target"].immunities
	config["targettarget"].cc = config["target"].cc
	config["targettarget"].silence = config["target"].silence
	config["targettarget"].interrupts = config["target"].interrupts
	config["targettarget"].roots = config["target"].roots
	config["targettarget"].disarm = config["target"].disarm
	config["targettarget"].buffs_defensive = config["target"].buffs_defensive
	config["targettarget"].buffs_offensive = config["target"].buffs_offensive
	config["targettarget"].buffs_other = config["target"].buffs_other
	config["targettarget"].snare = config["target"].snare

	config["focustarget"].enabled = config["focus"].enabledfocustarget
	if not config["focus"].enabled then
		config["focustarget"].enabled = false
	end
	config["focustarget"].inArena = config["focus"].inArena
	config["focustarget"].anchor = "auto"
	config["focustarget"].size = config["focus"].size
	config["focustarget"].alpha = config["focus"].alpha
	config["focustarget"].immunities = config["focus"].immunities
	config["focustarget"].cc = config["focus"].cc
	config["focustarget"].silence = config["focus"].silence
	config["focustarget"].interrupts = config["focus"].interrupts
	config["focustarget"].roots = config["focus"].roots
	config["focustarget"].disarm = config["focus"].disarm
	config["focustarget"].buffs_defensive = config["focus"].buffs_defensive
	config["focustarget"].buffs_offensive = config["focus"].buffs_offensive
	config["focustarget"].buffs_other = config["focus"].buffs_other
	config["focustarget"].snare = config["focus"].snare

	local drawEdge = config.drawEdge and true or false
	frame.cooldown:SetDrawEdge(drawEdge)
	frame.CircleCooldown:SetDrawEdge(drawEdge)

	frame.cooldown.noCooldownCount = true
	frame.CircleCooldown.noCooldownCount = true

	frame:EnableMouse(self.test)
	frame.cooldownContainer:EnableMouse(self.test)

	_G[frameName .. "Name"]:SetFont("Fonts\\FRIZQT__.ttf", 11, "OUTLINE")
	_G[frameName .. "Name"]:SetText(self.test and not frame.anchor and unit)
	_G[frameName .. "Name"]:SetPoint("BOTTOM", 0, 4)
	_G[frameName .. "Name"]:SetWidth(frame:GetWidth() )

	frame.anchor = nil
	frame.blizzard = nil
	frame.elvui = nil
	frame.suf = nil
	frame.xperl = nil

	if config.outline == "" then
		frame.timer:SetShadowOffset(0.8, -0.8)
	else
		frame.timer:SetShadowOffset(0, 0)
	end

	frame:SetAlpha(configUnit.alpha)

	if configUnit.anchor == "auto" then
		-- Find a frame to attach to
		for k,v in pairs(anchors) do
			local anchor, parent, noPortrait
			if v.units[unit] then
				if v.func then
					anchor, parent, noPortrait = v.func(v.units[unit])
				else
					anchor = _G[v.units[unit]]
				end

				if anchor then
					frame.anchor, frame.parent, frame.noPortrait = anchor, parent, noPortrait
					if v.noPortrait then frame.noPortrait = true end
					frame.alignLeft = v.alignLeft
					frame.blizzard = k == "Blizzard"
					frame.elvui = k == "ElvUI"
					frame.suf = k == "Shadowed Unit Frames"
					frame.xperl = k == "XPerl"
					if not frame.blizzard or not frame.elvui or not frame.suf or not frame.xperl then break end
				end
			end
		end
	end

	if frame.anchor then

		if frame.anchor:GetHeight() ~= 0 then
			frame.timer:SetFont(SML:Fetch(SML.MediaType.FONT, config.font), frame.anchor:GetHeight() / config.customTimerSize, config.outline)
		end

		if frame.blizzard then
			-- Blizzard Frame
			frame.icon:SetTexCoord(0, 1, 0, 1)

			-- Отключает цифры хила/урона на портретах игрока и питомца при закреплении на фрейме
			if unit == "player" or config["playerFAKE"].enabled == true then
				PlayerHitIndicator.Show = function() end
			elseif unit == "pet" then
				PetHitIndicator.Show = function() end
			end

			frame:SetParent(frame.anchor:GetParent() )
			-- Portrait < aura < decorative frame artwork.
			SetPortraitOverlayLevel(frame)

			frame.cooldownContainer:SetFrameLevel(frame:GetFrameLevel())
			frame.cooldownContainer:SetSize(frame.anchor:GetWidth(), frame.anchor:GetHeight() )
		else
			if config.hideBorder then
				frame.icon:SetTexCoord(0.075, 0.925, 0.075, 0.925)
			else
				frame.icon:SetTexCoord(0, 1, 0, 1)
			end

			frame:SetParent(frame.parent and frame.parent or frame.anchor)
			frame:SetFrameLevel(45)

			frame.cooldownContainer:SetFrameLevel(frame:GetFrameLevel() )

			if frame.noPortrait then
				frame.cooldownContainer:SetSize(frame.anchor:GetHeight(), frame.anchor:GetHeight() )
			else
				frame.cooldownContainer:SetSize(frame.anchor:GetWidth(), frame.anchor:GetHeight() )
			end
		end

		frame:ClearAllPoints()

		if frame.noPortrait then
			-- No portrait, so attach to the side
			if frame.alignLeft then
				frame:SetPoint("TOPRIGHT", frame.anchor, "TOPLEFT")
			else
				frame:SetPoint("TOPLEFT", frame.anchor, "TOPRIGHT")
			end

			local height = frame.anchor:GetHeight()

			if frame.elvui and unit == "target" or unit == "targettarget"
			or unit == "focus" or unit == "focustarget" then
				frame:SetPoint("TOPRIGHT", frame.anchor, "TOPRIGHT", height, 0)
			end

			if frame.suf and unit == "target" or unit == "targettarget"
			or unit == "focus" or unit == "focustarget" then
				frame:SetPoint("TOPRIGHT", frame.anchor, "TOPRIGHT", height, 0)
			end

			if frame.xperl and unit == "target" or unit == "targettarget"
			or unit == "focus" or unit == "focustarget" then
				frame:SetPoint("TOPRIGHT", frame.anchor, "TOPRIGHT", height, 0)
			end

			frame:SetSize(height, height)
		else
			frame:SetAllPoints(frame.anchor)
		end

	else
		-- Manual
		if config.hideBorder then
			frame.icon:SetTexCoord(0.075, 0.925, 0.075, 0.925)
		else
			frame.icon:SetTexCoord(0, 1, 0, 1)
		end

		frame:SetParent(UIParent)
		frame:ClearAllPoints()

		frame:SetFrameLevel(45)
		frame:SetSize(configUnit.size, configUnit.size)

		frame.cooldownContainer:SetFrameLevel(45)
		frame.cooldownContainer:SetSize(frame:GetWidth(), frame:GetHeight() )

		frame.timer:SetFont(SML:Fetch(SML.MediaType.FONT, config.font), frame:GetHeight() / config.customTimerSize, config.outline)

		if not config[unit] then config[unit] = {} end

		if config[unit].position then
			frame:SetPoint(unpack(config[unit].position))
		else
			-- No saved position, anchor to the blizzard position.
			-- Do not LoadAddOn("Blizzard_ArenaUI"): that taints arena OnEvent.
			local relativeFrame = _G[anchors.Blizzard.units[unit]] or UIParent
			frame:SetPoint("CENTER", relativeFrame, "CENTER")
		end
	end
	AttachUnitFrameIcon(frame)
	SetUnitFrameCooldownLevels(frame)
end

function BigDebuffs:SaveUnitFramePosition(frame)
	self.db.profile.unitFrames[frame.unit].position = { frame:GetPoint() }
end

function BigDebuffs:Test()
	self.test = not self.test
	self:Refresh()
end

local TestDebuffs = {}

function BigDebuffs:InsertTestDebuff(spellID)
	local texture = select(3, GetSpellInfo(spellID))
	tinsert(TestDebuffs, {spellID, texture})
end

local function UnitDebuffTest(unit, index)
	local debuff = TestDebuffs[index]
	if not debuff then return end
	return GetSpellInfo(debuff[1]), nil, debuff[2], 0, "Magic", 30, GetTime() + 30, nil, nil, nil, debuff[1]
end

function BigDebuffs:OnDisable()
    self:CancelAllTimers()
    AuraTracking:Unsubscribe("BigDebuffs")
    AuraTracking:UnsubscribeCombat("BigDebuffs")
    self:UnregisterAllEvents()
    self:UnhookAll()
    self.test = nil
    for _, frame in pairs(self.UnitFrames or {}) do
        frame:Hide()
        frame.current = nil
    end
end

function BigDebuffs:OnEnable()
	if not IsEnabled() then
		self:Disable()
		return;
	end
	self:RegisterEvent("PLAYER_FOCUS_CHANGED")
	self:RegisterEvent("PLAYER_TARGET_CHANGED")
	self:RegisterEvent("UNIT_TARGET")
	self:RegisterEvent("UNIT_PET")
	self:RegisterEvent("PARTY_MEMBERS_CHANGED")
	self:RegisterEvent("ARENA_OPPONENT_UPDATE")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	AuraTracking:Subscribe("BigDebuffs", function(unit)
		if IsEnabled() then self:UNIT_AURA("UNIT_AURA", unit) end
	end)
	AuraTracking:SubscribeCombat("BigDebuffs", function(...)
		if IsEnabled() then self:COMBAT_LOG_EVENT_UNFILTERED("COMBAT_LOG_EVENT_UNFILTERED", ...) end
	end)
	self:RegisterEvent("UNIT_SPELLCAST_FAILED")

	self.interrupts = {}


	if #TestDebuffs == 0 then self:InsertTestDebuff(10890) end
	self:PLAYER_ENTERING_WORLD()
	self:Refresh()
end

local CreateStancesTable = true
function BigDebuffs:PLAYER_ENTERING_WORLD()
	for i = 1, #units do
		self:AttachUnitFrame(units[i])
	end

	if CreateStancesTable then
		self.stances = {}
	end
	CreateStancesTable = false
end

-- For unit frames
function BigDebuffs:GetAuraPriority(name, id, unit)
	local record, resolved = AuraTracking:ResolveSpell(self.Spells, id)
	if not record then return end
	id = record.parent or resolved -- Check for parent spellID

	-- Make sure category is enabled
	if not self.db.profile.unitFrames[unit:gsub("%d", "")][self.Spells[id].type] then return end

	-- Check for user set
	if self.db.profile.spells[id] then
		if self.db.profile.spells[id].unitFrames and self.db.profile.spells[id].unitFrames == 0 then return end
		if self.db.profile.spells[id].priority then return self.db.profile.spells[id].priority end
	end

	if self.Spells[id].nounitFrames and (not self.db.profile.spells[id] or not self.db.profile.spells[id].unitFrames) then
		return
	end

	return self.db.profile.priority[self.Spells[id].type] or 0
end

function BigDebuffs:GetUnitFromGUID(guid)
	for _, unit in pairs(units) do
		if UnitGUID(unit) == guid then
			return unit
		end
	end
	return nil
end

function BigDebuffs:UNIT_SPELLCAST_FAILED(_, unit, spellName, _, _)
	if not self.interrupts then
		return;
	end
	self.spellName = spellName
	local guid = UnitGUID(unit)
	if not guid then
		return;
	end
	if self.interrupts[guid] == nil then
		self.interrupts[guid] = {}
		BigDebuffs:CancelTimer(self.interrupts[guid].timer)
		self.interrupts[guid].timer = BigDebuffs:ScheduleTimer(self.ClearInterruptGUID, 30, self, guid)
	end
	self.interrupts[guid].failed = GetTime()
end

local hpally = {} -- List of Holy Paladins found
local rshaman = {} -- List of Resto Shamans found

local Penance, _, PenanceIcon = GetSpellInfo(53007) -- Исповедь
local ArcaneMissiles, _, ArcaneMissilesIcon = GetSpellInfo(42846) -- Чародейские стрелы

function BigDebuffs:COMBAT_LOG_EVENT_UNFILTERED(_, ...)
	local _, subEvent, sourceGUID, _, _, destGUID, _, _, spellid, _ = ...

	local spelldata = self.Spells[spellid]

	if subEvent ~= "SPELL_CAST_SUCCESS" and subEvent ~= "SPELL_INTERRUPT"
	and subEvent ~= "SPELL_AURA_APPLIED" and subEvent ~= "SPELL_AURA_REMOVED" then
		return
	end

	if subEvent == "SPELL_CAST_SUCCESS" and spelldata then
		if spellid == 2457 or spellid == 2458 or spellid == 71 then
			self:UpdateStance(sourceGUID, spellid)
		end
	end

	if subEvent == "SPELL_AURA_APPLIED" and spelldata
	or subEvent == "SPELL_AURA_REMOVED" and spelldata then
		self:UNIT_AURA(nil, "targettarget")
		self:UNIT_AURA(nil, "focustarget")
	end

	if subEvent == "SPELL_CAST_SUCCESS" then
		local _, _, _, Name, _, _, _, _, spellId, _, _ = ...

		-- Detect Restoration Shaman according to used Spells (Riptide & Earth Shield)
		if spellId == 61295 or spellId == 61299 or spellId == 61300 or spellId == 61301 or spellId == 974
		or spellId == 32593 or spellId == 32594 or spellId == 49283 or spellId == 49284 then
			for i = 0, 1000 do
				if rshaman[i] == Name then -- Check whether Shaman has already been detected
					break
				elseif rshaman[i] == nil then -- Reached end of the List, adding Shaman
					rshaman[i] = Name
					break
				end
			end

		-- Detect Holy Paladin according to used Spells (Holy Shock & Beacon of Light)
		elseif spellId == 20473 or spellId == 48825 or spellId == 48824 or spellId == 33072
		or spellId == 27174 or spellId == 20930 or spellId == 20929 or spellId == 53563 then
			for i = 0, 1000 do
				if hpally[i] == Name then -- Check whether Paladin has already been detected
					break
				elseif hpally[i] == nil then -- Reached end of the List, adding Paladin
					hpally[i] = Name
					break
				end
			end
		end
	end

	if spelldata == nil or spelldata.parent or spelldata.type ~= "interrupts" then return end

	local duration = spelldata.duration
	if not duration then return end

	-- SPELL_INTERRUPT doesn't fire for some channeled spells
	if subEvent == "SPELL_INTERRUPT" then
		--                 кого кикнули        чем кикнули              что кикнули
		local _, _, _, _, _, unitGUID, _, _, InterruptSpellID, _, _, InterruptedSpellID, _, _ = ...

		local _, _, InterruptedIcon = GetSpellInfo(InterruptedSpellID)

		local changedDuration = BigDebuffs.GetDuration(unitGUID, duration)

		self:UpdateInterrupt(nil, unitGUID, InterruptSpellID, changedDuration, InterruptedIcon)
	end

	-- UnitChannelingInfo and event orders are not the same in WotLK as later expansions, UnitChannelingInfo will always return
	-- nil @ the time of this event (independent of whether something was kicked or not).
	-- We have to track UNIT_SPELLCAST_FAILED for spell failure of the target at the (approx.) same time as we interrupted
	-- this "could" be wrong if the interrupt misses with a <0.01 sec failure window (which depending on server tickrate might
	-- not even be possible)
	if subEvent == "SPELL_CAST_SUCCESS" and self.interrupts and not (self.interrupts[destGUID] and self.interrupts[destGUID].failed
	and GetTime() - self.interrupts[destGUID].failed < 0.0009) then return end -- если будет отображать фейк кик то необходимо уменьшить число
																			  -- если не будет отображать кик впринципе то необходимо увеличить число
	if self.spellName ~= Penance and self.spellName ~= ArcaneMissiles then return end

	local InterruptedIcon
	if self.spellName == Penance then
		InterruptedIcon = PenanceIcon
	elseif self.spellName == ArcaneMissiles then
		InterruptedIcon = ArcaneMissilesIcon
	end

	local changedDuration = BigDebuffs.GetDuration(destGUID, duration)

	self:UpdateInterrupt(nil, destGUID, spellid, changedDuration, InterruptedIcon)
end

function BigDebuffs.GetDuration(GUID, duration)
	local changedDuration

	if GUID == UnitGUID("player") then
		changedDuration = duration * BigDebuffs.GetModifier("player")
	end
	if GUID == UnitGUID("pet") then
		changedDuration = duration * BigDebuffs.GetModifier("pet")
	end
	if GUID == UnitGUID("target") then
		changedDuration = duration * BigDebuffs.GetModifier("target")
	end
	if GUID == UnitGUID("focus") then
		changedDuration = duration * BigDebuffs.GetModifier("focus")
	end
	if GUID == UnitGUID("party1") then
		changedDuration = duration * BigDebuffs.GetModifier("party1")
	end
	if GUID == UnitGUID("partypet1") then
		changedDuration = duration * BigDebuffs.GetModifier("partypet1")
	end
	if GUID == UnitGUID("party2") then
		changedDuration = duration * BigDebuffs.GetModifier("party2")
	end
	if GUID == UnitGUID("partypet2") then
		changedDuration = duration * BigDebuffs.GetModifier("partypet2")
	end
	if GUID == UnitGUID("party3") then
		changedDuration = duration * BigDebuffs.GetModifier("party3")
	end
	if GUID == UnitGUID("partypet3") then
		changedDuration = duration * BigDebuffs.GetModifier("partypet3")
	end
	if GUID == UnitGUID("party4") then
		changedDuration = duration * BigDebuffs.GetModifier("party4")
	end
	if GUID == UnitGUID("partypet4") then
		changedDuration = duration * BigDebuffs.GetModifier("partypet4")
	end
	if GUID == UnitGUID("arena1") then
		changedDuration = duration * BigDebuffs.GetModifier("arena1")
	end
	if GUID == UnitGUID("arenapet1") then
		changedDuration = duration * BigDebuffs.GetModifier("arenapet1")
	end
	if GUID == UnitGUID("arena2") then
		changedDuration = duration * BigDebuffs.GetModifier("arena2")
	end
	if GUID == UnitGUID("arenapet2") then
		changedDuration = duration * BigDebuffs.GetModifier("arenapet2")
	end
	if GUID == UnitGUID("arena3") then
		changedDuration = duration * BigDebuffs.GetModifier("arena3")
	end
	if GUID == UnitGUID("arenapet3") then
		changedDuration = duration * BigDebuffs.GetModifier("arenapet3")
	end
	if GUID == UnitGUID("arena4") then
		changedDuration = duration * BigDebuffs.GetModifier("arena4")
	end
	if GUID == UnitGUID("arenapet4") then
		changedDuration = duration * BigDebuffs.GetModifier("arenapet4")
	end
	if GUID == UnitGUID("arena5") then
		changedDuration = duration * BigDebuffs.GetModifier("arena5")
	end
	if GUID == UnitGUID("arenapet5") then
		changedDuration = duration * BigDebuffs.GetModifier("arenapet5")
	end

	return changedDuration
end

function BigDebuffs.GetModifier(unitid)
	local modifier = 1

	for i = 1, 40 do
		local _, _, _, _, _, _, _, unitCaster, _, _, spellId = UnitAura(unitid, i)

		-- all Paladin Auras max Rank
		if spellId == 19746 or spellId == 48942 or spellId == 48947 or spellId == 48945
		or spellId == 48943 or spellId == 54043 or spellId == 32223 then

			for index = 0, 1000 do
				if unitCaster ~= nil then -- игнорим nil
					if hpally[index] == GetUnitName(unitCaster) then -- Probably imp. Concentration Aura
						if modifier > 0.7 then
							modifier = 0.7
						end
						break
					-- The Paladin casting the Aura hasn't been detected as a Holy Paladin, so probably no imp. Concentration Aura
					elseif hpally[index] == nil then
						break
					end
				end
			end

		elseif spellId == 14743 then -- Matyrdom Rank1
			if modifier > 0.9 then
				modifier = 0.9
			end

		elseif spellId == 27828 then -- Matyrdom Rank2
			if modifier > 0.8 then
				modifier = 0.8
			end
		end
	end

	for index = 0, 1000 do
		if GetUnitName(unitid) == rshaman[index] then -- Interrupted Target is a Resto Shaman, so probably has 3/3 Focused Mind
			if modifier > 0.7 then
				modifier = 0.7
			end
		end
	end

	return modifier
end

function BigDebuffs:UpdateStance(guid, spellid)
	if self.stances[guid] == nil then
		self.stances[guid] = {}
	else
		self:CancelTimer(self.stances[guid].timer)
	end

	self.stances[guid].stance = spellid
	self.stances[guid].timer = self:ScheduleTimer(self.ClearStanceGUID, 180, self, guid)

	local unit = self:GetUnitFromGUID(guid)
	if unit then
		self:UNIT_AURA(nil, unit)
	end
end

function BigDebuffs:ClearStanceGUID(guid)
	local unit = self:GetUnitFromGUID(guid)
	if unit == nil then
		self.stances[guid] = nil
	else
		self.stances[guid].timer = BigDebuffs:ScheduleTimer(self.ClearStanceGUID, 180, self, guid)
	end
end

function BigDebuffs:UpdateInterrupt(unit, guid, spellid, duration, InterruptedIcon)
	if not self.interrupts or not guid then
		return;
	end
	local t = GetTime()
	-- new interrupt
	if spellid and duration ~= nil then
		if self.interrupts[guid] == nil then self.interrupts[guid] = {} end
		BigDebuffs:CancelTimer(self.interrupts[guid].timer)
		self.interrupts[guid].timer = BigDebuffs:ScheduleTimer(self.ClearInterruptGUID, 30, self, guid)
		self.interrupts[guid][spellid] = { started = t, duration = duration, icon = InterruptedIcon }
	-- old interrupt expiring
	elseif spellid and duration == nil then
		if self.interrupts[guid] and self.interrupts[guid][spellid] and
				t > self.interrupts[guid][spellid].started + self.interrupts[guid][spellid].duration then
			self.interrupts[guid][spellid] = nil
		end
	end

	if unit == nil then
		unit = self:GetUnitFromGUID(guid)
	end

	if unit then
		for i = 1, #units do
			self:UNIT_AURA(nil, units[i])
		end
	end
	-- clears the interrupt after end of duration
	if duration then
		-- если иконка кика не будет исчезать тогда необходимо добавить ещё времени к duration
		BigDebuffs:ScheduleTimer(self.UpdateInterrupt, duration + 0.05, self, unit, guid, spellid)
	end
end

function BigDebuffs:ClearInterruptGUID(guid)
	if not self.interrupts or not guid then
		return;
	end
	self.interrupts[guid] = nil
end

function BigDebuffs:GetInterruptFor(unit)
	if not self.interrupts then
		return;
	end
	local guid = UnitGUID(unit)
	if not guid then
		return;
	end
	local interrupts = self.interrupts[guid]

	if interrupts == nil then return end

	local name, spellid, InterruptIcon, duration, endsAt, InterruptedIcon

	-- iterate over all interrupt spellids to find the one of highest duration
	for ispellid, intdata in pairs(interrupts) do
		if type(ispellid) == "number" then
			local tmpstartedAt = intdata.started
			local dur = intdata.duration
			local intdataicon = intdata.icon
			local tmpendsAt = tmpstartedAt + dur
			if GetTime() > tmpendsAt then
				self.interrupts[guid][ispellid] = nil
			elseif endsAt == nil or tmpendsAt > endsAt then
				endsAt = tmpendsAt
				duration = dur
				InterruptedIcon = intdataicon
				name, _, InterruptIcon = GetSpellInfo(ispellid)
				spellid = ispellid
			end
		end
	end

	if name then
		if self.db.profile.unitFrames.interruptIcon then
			return name, spellid, InterruptedIcon, duration, endsAt
		else
			return name, spellid, InterruptIcon, duration, endsAt
		end
	end
end

function BigDebuffs:UNIT_AURA(event, unit)
	if not IsEnabled() then
		return;
	end

	if not self.db.profile.unitFrames.enabled
	or not unit -- игнорим nil
	or not self.db.profile.unitFrames[unit:gsub("%d", "")] -- игнорим юнитов которых нет в нашей таблице
	or not self.db.profile.unitFrames[unit:gsub("%d", "")].enabled
	or not self.test and self.db.profile.unitFrames[unit:gsub("%d", "")].inArena and not InArena()
	then return end

	if unit == "player" then
		self:UNIT_AURA(nil, "playerFAKE")
	end

	self:AttachUnitFrame(unit)

	local frame = self.UnitFrames[unit]
	if not frame then return end

	if unit == "playerFAKE" then
		unit = gsub(unit, "%u", "")
	end

	local UnitDebuff = BigDebuffs.test and UnitDebuffTest or UnitDebuff

	local now = GetTime()
	local left, priority, duration, expires, icon, isAura, interrupt = 0, 0

	for i = 1, 40 do
		-- Check debuffs
		local n,_, ico, _,_, d, e, caster, _,_, id = UnitDebuff(unit, i)
		if id then
			--if id == 605 and unit == "pet" then return end -- дебафф от МК на питомце не нужен

			if AuraTracking:ResolveSpell(self.Spells, id) then
				local p = self:GetAuraPriority(n, id, unit)

				-- if unit == 'player'
				-- and self.db.profile.unitFrames[unit:gsub("%d", "")].reduceSnare
				-- and self.db.profile.unitFrames[unit:gsub("%d", "")].anchor == "manual" then

				-- 	if self.Spells[id].type == 'snare'
				-- 	or self.Spells[id].parent ~= nil
				-- 	and self.Spells[self.Spells[id].parent].type == 'snare' then

				-- 		-- if spellType == 'Magic' then
				-- 		-- 	print('Magic')
				-- 		-- elseif spellType == 'Disease' then
				-- 		-- 	print('Disease')
				-- 		-- elseif not spellType then
				-- 		-- 	print('Physic')
				-- 		-- end

				-- 		local frame_size = self.db.profile.unitFrames[unit:gsub("%d", "")].size / 1.466
				-- 		local frame = self.UnitFrames[unit]
				-- 		frame:SetSize(frame_size, frame_size)
				-- 		frame.cooldownContainer:SetSize(frame_size, frame_size)
				-- 	else
				-- 		local frame_size = self.db.profile.unitFrames[unit:gsub("%d", "")].size
				-- 		local frame = self.UnitFrames[unit]
				-- 		frame:SetSize(frame_size, frame_size)
				-- 		frame.cooldownContainer:SetSize(frame_size, frame_size)
				-- 	end
				-- end

				if p and p > priority or p == priority and e - now > left then
					left = e - now
					duration = d
					isAura = true
					priority = p
					expires = e
					icon = ico
				end
			end
		else
			break
		end
	end

	for i = 1, 40 do
		-- Check buffs
		local n,_, ico, _,_, d, e, _,_,_, id = UnitBuff(unit, i)
		if id then
			if id == 605 then return end -- бафф от МК не нужен

			if AuraTracking:ResolveSpell(self.Spells, id) then
				local p = self:GetAuraPriority(n, id, unit)
				if p and p >= priority then
					if p and p > priority or p == priority and e - now > left then
						left = e - now
						duration = d
						isAura = true
						priority = p
						expires = e
						icon = ico
					end
				end
			end
		else
			break
		end
	end

	local n, id, ico, d, e = self:GetInterruptFor(unit)
	if n then
		local p = self:GetAuraPriority(n, id, unit)
		if p and p > priority or p == priority and e - now > left then
			left = e - now
			duration = d
			isAura = true
			priority = p
			expires = e
			icon = ico
		end
	end

	-- need to always look for a stance (if we only look for it once a player
	-- changes stance we will never get back to it again once other auras fade)
	local guid = UnitGUID(unit)
	if self.stances[guid] then
		local stanceId = self.stances[guid].stance
		if stanceId and self.Spells[stanceId] then
			n, _, ico = GetSpellInfo(stanceId)
			local p = self:GetAuraPriority(n, stanceId, unit)
			if p and p >= priority then
				left = 0
				duration = 0
				isAura = true
				priority = p
				expires = 0
				icon = ico
			end
		end
	end

	if isAura then

		--if frame.current ~= icon then

			if frame.blizzard then
				-- Blizzard Frame

				-- фикс кривых рук близзов
				if BigDebuffsplayerUnitFrame.blizzard then
					BigDebuffsplayerUnitFrame:ClearAllPoints()
					BigDebuffsplayerUnitFrame:SetPoint("CENTER", PlayerPortrait, "CENTER", 0.5, -0.7)
					BigDebuffsplayerUnitFrame:SetSize(PlayerPortrait:GetHeight(), PlayerPortrait:GetWidth() )
				end
				if BigDebuffsplayerFAKEUnitFrame.blizzard then
					BigDebuffsplayerFAKEUnitFrame:ClearAllPoints()
					BigDebuffsplayerFAKEUnitFrame:SetPoint("CENTER", PlayerPortrait, "CENTER", 0.5, -0.7)
					BigDebuffsplayerFAKEUnitFrame:SetSize(PlayerPortrait:GetHeight(), PlayerPortrait:GetWidth() )
				end
				if BigDebuffspetUnitFrame.blizzard then
					BigDebuffspetUnitFrame:ClearAllPoints()
					BigDebuffspetUnitFrame:SetPoint("CENTER", PetPortrait, "CENTER", -1.4, -0.5)
					BigDebuffspetUnitFrame:SetSize(PetPortrait:GetHeight() + 1.5, PetPortrait:GetWidth() + 1.5)
				end
				if BigDebuffstargetUnitFrame.blizzard then
					BigDebuffstargetUnitFrame:ClearAllPoints()
					BigDebuffstargetUnitFrame:SetPoint("CENTER", TargetFramePortrait, "CENTER", -0.4, -0.7)
					BigDebuffstargetUnitFrame:SetSize(TargetFramePortrait:GetHeight(), TargetFramePortrait:GetWidth() )
				end
				if BigDebuffstargettargetUnitFrame.blizzard then
					BigDebuffstargettargetUnitFrame:ClearAllPoints()
					BigDebuffstargettargetUnitFrame:SetPoint("CENTER", TargetFrameToTPortrait, "CENTER", -0.1, -0.5)
					BigDebuffstargettargetUnitFrame:SetSize(TargetFrameToTPortrait:GetHeight() + 4.2, TargetFrameToTPortrait:GetWidth() + 4.2)
				end
				if BigDebuffsfocusUnitFrame.blizzard then
					BigDebuffsfocusUnitFrame:ClearAllPoints()
					BigDebuffsfocusUnitFrame:SetPoint("CENTER", FocusFramePortrait, "CENTER", -0.4, -0.7)
					BigDebuffsfocusUnitFrame:SetSize(FocusFramePortrait:GetHeight(), FocusFramePortrait:GetWidth() )
				end
				if BigDebuffsfocustargetUnitFrame.blizzard then
					BigDebuffsfocustargetUnitFrame:ClearAllPoints()
					BigDebuffsfocustargetUnitFrame:SetPoint("CENTER", FocusFrameToTPortrait, "CENTER", -0.1, -0.5)
					BigDebuffsfocustargetUnitFrame:SetSize(FocusFrameToTPortrait:GetHeight() + 4.2, FocusFrameToTPortrait:GetWidth() + 4.2)
				end
				if BigDebuffsparty1UnitFrame.blizzard then
					BigDebuffsparty1UnitFrame:ClearAllPoints()
					BigDebuffsparty1UnitFrame:SetPoint("CENTER", PartyMemberFrame1Portrait, "CENTER", -0.7, -1.3)
					BigDebuffsparty1UnitFrame:SetSize(PartyMemberFrame1Portrait:GetHeight() + 1.5, PartyMemberFrame1Portrait:GetWidth() + 1.5)
				end
				if BigDebuffspartypet1UnitFrame.blizzard then
					BigDebuffspartypet1UnitFrame:ClearAllPoints()
					BigDebuffspartypet1UnitFrame:SetPoint("CENTER", PartyMemberFrame1PetFramePortrait, "CENTER", 0.5, -1.1)
					BigDebuffspartypet1UnitFrame:SetSize(PartyMemberFrame1PetFramePortrait:GetHeight() + 1, PartyMemberFrame1PetFramePortrait:GetWidth() + 1)
				end
				if BigDebuffsparty2UnitFrame.blizzard then
					BigDebuffsparty2UnitFrame:ClearAllPoints()
					BigDebuffsparty2UnitFrame:SetPoint("CENTER", PartyMemberFrame2Portrait, "CENTER", -0.7, -1.3)
					BigDebuffsparty2UnitFrame:SetSize(PartyMemberFrame2Portrait:GetHeight() + 1.5, PartyMemberFrame2Portrait:GetWidth() + 1.5)
				end
				if BigDebuffspartypet2UnitFrame.blizzard then
					BigDebuffspartypet2UnitFrame:ClearAllPoints()
					BigDebuffspartypet2UnitFrame:SetPoint("CENTER", PartyMemberFrame2PetFramePortrait, "CENTER", 0.5, -1.1)
					BigDebuffspartypet2UnitFrame:SetSize(PartyMemberFrame2PetFramePortrait:GetHeight() + 1, PartyMemberFrame2PetFramePortrait:GetWidth() + 1)
				end
				if BigDebuffsparty3UnitFrame.blizzard then
					BigDebuffsparty3UnitFrame:ClearAllPoints()
					BigDebuffsparty3UnitFrame:SetPoint("CENTER", PartyMemberFrame3Portrait, "CENTER", -0.7, -1.3)
					BigDebuffsparty3UnitFrame:SetSize(PartyMemberFrame3Portrait:GetHeight() + 1.5, PartyMemberFrame3Portrait:GetWidth() + 1.5)
				end
				if BigDebuffspartypet3UnitFrame.blizzard then
					BigDebuffspartypet3UnitFrame:ClearAllPoints()
					BigDebuffspartypet3UnitFrame:SetPoint("CENTER", PartyMemberFrame3PetFramePortrait, "CENTER", 0.5, -1.1)
					BigDebuffspartypet3UnitFrame:SetSize(PartyMemberFrame3PetFramePortrait:GetHeight() + 1, PartyMemberFrame3PetFramePortrait:GetWidth() + 1)
				end
				if BigDebuffsparty4UnitFrame.blizzard then
					BigDebuffsparty4UnitFrame:ClearAllPoints()
					BigDebuffsparty4UnitFrame:SetPoint("CENTER", PartyMemberFrame4Portrait, "CENTER", -0.7, -1.3)
					BigDebuffsparty4UnitFrame:SetSize(PartyMemberFrame4Portrait:GetHeight() + 1.5, PartyMemberFrame4Portrait:GetWidth() + 1.5)
				end
				if BigDebuffspartypet4UnitFrame.blizzard then
					BigDebuffspartypet4UnitFrame:ClearAllPoints()
					BigDebuffspartypet4UnitFrame:SetPoint("CENTER", PartyMemberFrame4PetFramePortrait, "CENTER", 0.5, -1.1)
					BigDebuffspartypet4UnitFrame:SetSize(PartyMemberFrame4PetFramePortrait:GetHeight() + 1, PartyMemberFrame4PetFramePortrait:GetWidth() + 1)
				end
				if BigDebuffsarena1UnitFrame.blizzard and not IsGladiusArenaUnit("arena1") then
					BigDebuffsarena1UnitFrame:ClearAllPoints()
					BigDebuffsarena1UnitFrame:SetPoint("CENTER", ArenaEnemyFrame1ClassPortrait, "CENTER", 0.4, 1.3)
					BigDebuffsarena1UnitFrame:SetSize(ArenaEnemyFrame1ClassPortrait:GetHeight() - 4, ArenaEnemyFrame1ClassPortrait:GetWidth() - 4)
				end
				if BigDebuffsarenapet1UnitFrame.blizzard then
					BigDebuffsarenapet1UnitFrame:ClearAllPoints()
					BigDebuffsarenapet1UnitFrame:SetPoint("CENTER", ArenaEnemyFrame1PetFramePortrait, "CENTER", -1, -1.3)
					BigDebuffsarenapet1UnitFrame:SetSize(ArenaEnemyFrame1PetFramePortrait:GetHeight() + 1.5, ArenaEnemyFrame1PetFramePortrait:GetWidth() + 1.5)
				end
				if BigDebuffsarena2UnitFrame.blizzard and not IsGladiusArenaUnit("arena2") then
					BigDebuffsarena2UnitFrame:ClearAllPoints()
					BigDebuffsarena2UnitFrame:SetPoint("CENTER", ArenaEnemyFrame2ClassPortrait, "CENTER", 0.4, 1.3)
					BigDebuffsarena2UnitFrame:SetSize(ArenaEnemyFrame2ClassPortrait:GetHeight() - 4, ArenaEnemyFrame2ClassPortrait:GetWidth() - 4)
				end
				if BigDebuffsarenapet2UnitFrame.blizzard then
					BigDebuffsarenapet2UnitFrame:ClearAllPoints()
					BigDebuffsarenapet2UnitFrame:SetPoint("CENTER", ArenaEnemyFrame2PetFramePortrait, "CENTER", -1, -1.3)
					BigDebuffsarenapet2UnitFrame:SetSize(ArenaEnemyFrame2PetFramePortrait:GetHeight() + 1.5, ArenaEnemyFrame2PetFramePortrait:GetWidth() + 1.5)
				end
				if BigDebuffsarena3UnitFrame.blizzard and not IsGladiusArenaUnit("arena3") then
					BigDebuffsarena3UnitFrame:ClearAllPoints()
					BigDebuffsarena3UnitFrame:SetPoint("CENTER", ArenaEnemyFrame3ClassPortrait, "CENTER", 0.4, 1.3)
					BigDebuffsarena3UnitFrame:SetSize(ArenaEnemyFrame3ClassPortrait:GetHeight() - 4, ArenaEnemyFrame3ClassPortrait:GetWidth() - 4)
				end
				if BigDebuffsarenapet3UnitFrame.blizzard then
					BigDebuffsarenapet3UnitFrame:ClearAllPoints()
					BigDebuffsarenapet3UnitFrame:SetPoint("CENTER", ArenaEnemyFrame3PetFramePortrait, "CENTER", -1, -1.3)
					BigDebuffsarenapet3UnitFrame:SetSize(ArenaEnemyFrame3PetFramePortrait:GetHeight() + 1.5, ArenaEnemyFrame3PetFramePortrait:GetWidth() + 1.5)
				end
				if BigDebuffsarena4UnitFrame.blizzard and not IsGladiusArenaUnit("arena4") then
					BigDebuffsarena4UnitFrame:ClearAllPoints()
					BigDebuffsarena4UnitFrame:SetPoint("CENTER", ArenaEnemyFrame4ClassPortrait, "CENTER", 0.4, 1.3)
					BigDebuffsarena4UnitFrame:SetSize(ArenaEnemyFrame4ClassPortrait:GetHeight() - 4, ArenaEnemyFrame4ClassPortrait:GetWidth() - 4)
				end
				if BigDebuffsarenapet4UnitFrame.blizzard then
					BigDebuffsarenapet4UnitFrame:ClearAllPoints()
					BigDebuffsarenapet4UnitFrame:SetPoint("CENTER", ArenaEnemyFrame4PetFramePortrait, "CENTER", -1, -1.3)
					BigDebuffsarenapet4UnitFrame:SetSize(ArenaEnemyFrame4PetFramePortrait:GetHeight() + 1.5, ArenaEnemyFrame4PetFramePortrait:GetWidth() + 1.5)
				end
				if BigDebuffsarena5UnitFrame.blizzard and not IsGladiusArenaUnit("arena5") then
					BigDebuffsarena5UnitFrame:ClearAllPoints()
					BigDebuffsarena5UnitFrame:SetPoint("CENTER", ArenaEnemyFrame5ClassPortrait, "CENTER", 0.4, 1.3)
					BigDebuffsarena5UnitFrame:SetSize(ArenaEnemyFrame5ClassPortrait:GetHeight() - 4, ArenaEnemyFrame5ClassPortrait:GetWidth() - 4)
				end
				if BigDebuffsarenapet5UnitFrame.blizzard then
					BigDebuffsarenapet5UnitFrame:ClearAllPoints()
					BigDebuffsarenapet5UnitFrame:SetPoint("CENTER", ArenaEnemyFrame5PetFramePortrait, "CENTER", -1, -1.3)
					BigDebuffsarenapet5UnitFrame:SetSize(ArenaEnemyFrame5PetFramePortrait:GetHeight() + 1.5, ArenaEnemyFrame5PetFramePortrait:GetWidth() + 1.5)
				end

				if IsGladiusArenaUnit(unit) then
					-- The Gladius class portrait is square; use the full aura icon.
					frame:ClearAllPoints()
					frame:SetPoint("TOPLEFT", frame.anchor, "TOPLEFT", 0, 0)
					frame:SetSize(frame.anchor:GetWidth(), frame.anchor:GetHeight())
					frame.cooldownContainer:SetSize(frame:GetWidth(), frame:GetHeight())
					frame.icon:ClearAllPoints()
					frame.icon:SetAllPoints(frame)
					local normal = frame:GetNormalTexture()
					if normal then normal:Hide() end
					frame.icon:SetTexture(icon)
					frame.icon:SetTexCoord(0, 1, 0, 1)
				else
					SetPortraitToTexture(frame.icon, icon)
				end

				-- Adapt
				if frame.anchor and Adapt and Adapt.portraits[frame.anchor] then
					Adapt.portraits[frame.anchor].modelLayer:SetFrameStrata("BACKGROUND")
				end
			else
				frame.icon:SetTexture(icon)
			end
		--end

		if duration > 0.2 then

			if self.db.profile.unitFrames.circleCooldown and frame.blizzard
				and not IsGladiusArenaUnit(unit) then
				frame.CircleCooldown:SetCooldown(expires - duration, duration)
				frame.cooldown:Hide()
			else
				frame.cooldown:SetCooldown(expires - duration, duration)
				frame.CircleCooldown:Hide()
			end

			-- Скрываем анимацию кд, что бы альфа применилась сетаем её после сеткулдаун
			if self.db.profile.unitFrames.hideCDanimation then
				frame.cooldown:SetAlpha(0)
				frame.CircleCooldown:SetAlpha(0)
			else
				frame.cooldown:SetAlpha(0.85)
				frame.CircleCooldown:SetAlpha(1)
			end

			if self.db.profile.unitFrames.customTimer then
				frame.timeEnd = (expires - duration) + duration
			else
				frame.timeEnd = GetTime()
			end

			frame.cooldownContainer:Show()
		else
			frame.timeEnd = GetTime()
			frame.cooldownContainer:Hide()
		end

		frame:Show()
		ShowUnitFrameIcon(frame)
		frame.current = icon
	else
		-- Adapt
		if frame.anchor and frame.blizzard and Adapt and Adapt.portraits[frame.anchor] then
			Adapt.portraits[frame.anchor].modelLayer:SetFrameStrata("LOW")
		end
		local hadAura = frame.current ~= nil
		frame:Hide()
		frame.current = nil
		-- Refresh once when the overlay is removed, including model changes
		-- during boss phases. Do not rebuild portraits on every UNIT_AURA.
		local portraits = SarychUI.modules.frame
		if hadAura and frame.blizzard and portraits and portraits.UpdateClassIconPortraits then
			portraits:UpdateClassIconPortraits(true, unit)
		end
	end
end

function BigDebuffs:OnUpdate()
	if not IsEnabled() then
		return;
	end
	timerAppearance.decimalThreshold = BigDebuffs.db.profile.unitFrames.timeThreshold or 5
	SarychUI.modules.cc:UpdateNativeTimerText(self.timer, (self.timeEnd or 0) - GetTime(), timerAppearance)
end

function BigDebuffs:PLAYER_FOCUS_CHANGED()
	self:UNIT_AURA(nil, "focus")
	self:UNIT_AURA(nil, "focustarget")
end

function BigDebuffs:PLAYER_TARGET_CHANGED()
	self:UNIT_AURA(nil, "target")
	self:UNIT_AURA(nil, "targettarget")
end

local function IsEventOwner(unit, owner)
	return not unit or unit == owner or UnitIsUnit(unit, owner)
end

function BigDebuffs:UNIT_TARGET(event, unit)
	if IsEventOwner(unit, "target") then self:UNIT_AURA(nil, "targettarget") end
	if IsEventOwner(unit, "focus") then self:UNIT_AURA(nil, "focustarget") end
end

function BigDebuffs:UNIT_PET(event, unit)
	if IsEventOwner(unit, "player") then self:UNIT_AURA(nil, "pet") end
	for i=1, 5 do
		if IsEventOwner(unit, "arena"..i) then self:UNIT_AURA(nil, "arenapet"..i) end
	end
end

function BigDebuffs:PARTY_MEMBERS_CHANGED()
	for i = 1, #units do
		self:UNIT_AURA(nil, units[i])
	end
end
BigDebuffs.ARENA_OPPONENT_UPDATE = BigDebuffs.PARTY_MEMBERS_CHANGED

SLASH_BigDebuffs1 = "/bd"
SLASH_BigDebuffs2 = "/big"
SLASH_BigDebuffs3 = "/bigdebuff"
SLASH_BigDebuffs4 = "/bigdebuffs"
SlashCmdList.BigDebuffs = function(msg)
	SarychUI.extensions.aura_tracking:OpenSettings()
end
