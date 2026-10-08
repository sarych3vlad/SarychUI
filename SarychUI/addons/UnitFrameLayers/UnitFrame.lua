--######################################################################
--######                   	UnitFrameLayers                      #######
------------------------------------------------------------------------
--######################################################################

local LibAbsorb  = LibStub:GetLibrary("AbsorbsMonitor-1.0", true);
local HealComm   = LibStub:GetLibrary("LibHealComm-4.0");

-- Global enabled state
UnitFrameLayersEnabled = UnitFrameLayersEnabled or true;

-- Function to check if addon is enabled
local function IsEnabled()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.UnitFrameLayers then
		return SarychUI.db.profile.addons.UnitFrameLayers.enabled ~= false;
	end
	return UnitFrameLayersEnabled;
end

--------------------------------------------------------------------
-- WeakAuras / external scripts check IsAddOnLoaded("UnitFrameLayers").
-- UFL is embedded in SarychUI, so report as loaded while enabled.
--------------------------------------------------------------------
do
	local _IsAddOnLoaded = IsAddOnLoaded
	function IsAddOnLoaded(name)
		if name == "UnitFrameLayers" and IsEnabled() then
			return true
		end
		return _IsAddOnLoaded(name)
	end

	if type(GetAddOnInfo) == "function" then
		local _GetAddOnInfo = GetAddOnInfo
		function GetAddOnInfo(name)
			if name == "UnitFrameLayers" and IsEnabled() then
				return "UnitFrameLayers", "UnitFrameLayers (SarychUI)", "1.0.1", true, "INSECURE", false
			end
			return _GetAddOnInfo(name)
		end
	end
end

-- Сделаем функцию глобальной, чтобы её можно было вызывать из wrapper.lua
function UpdateHealthBarColor(frame)
	if not IsEnabled() then
		return;
	end
    if not frame or not frame.unit or not frame.healthbar then return end  -- Проверка на nil

    -- Проверяем настройку цвета HP в цвет класса
    local classColorHPEnabled = true  -- По умолчанию включено
    if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.UnitFrameLayers then
        local val = SarychUI.db.profile.addons.UnitFrameLayers.classColorHP
        -- nil или true = включено, false = выключено
        classColorHPEnabled = val ~= false
    end

    -- Если настройка выключена, снимаем блокировку и сразу возвращаем зелёный
    -- (иначе цвет «залипает» до reload)
    if not classColorHPEnabled then
        frame.healthbar.lockColor = nil
        if UnitIsPlayer(frame.unit) then
            frame.healthbar:SetStatusBarColor(0.0, 1.0, 0.0)
        end
        return
    end

    -- Проверяем, подключен ли игрок (для всех юнитов, но только игроки могут быть отключены)
    if not UnitIsConnected(frame.unit) then
        -- Для отключенных игроков устанавливаем серый цвет
        frame.healthbar.lockColor = true
        frame.healthbar:SetStatusBarColor(0.5, 0.5, 0.5)
        return
    end

    -- Обрабатываем только игроков, для остальных (NPC/мобов) ничего не делаем
    -- Пусть Blizzard сам управляет цветом для не-игроков
    if UnitIsPlayer(frame.unit) then
        local isPlayerFrame = (frame:GetName() == "PlayerFrame")
        local playerClassColorEnabled = false
        
        if isPlayerFrame then
            -- Проверяем настройку для PlayerFrame
            if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.UnitFrameLayers then
                playerClassColorEnabled = SarychUI.db.profile.addons.UnitFrameLayers.playerClassColorHP == true
            end
        end
        
        -- Блокируем цвет, чтобы Blizzard не перезаписывал его
        frame.healthbar.lockColor = true
        
        if isPlayerFrame and playerClassColorEnabled then
            -- Цвет класса для PlayerFrame если включено
            local _, class = UnitClass(frame.unit)
            local color = RAID_CLASS_COLORS[class]
            if color then
                frame.healthbar:SetStatusBarColor(color.r, color.g, color.b)
            else
                -- Fallback на зеленый, если класс не найден
                frame.healthbar:SetStatusBarColor(0.0, 1.0, 0.0)
            end
        elseif isPlayerFrame then
            -- Зеленый цвет для PlayerFrame по умолчанию
            frame.healthbar:SetStatusBarColor(0.0, 1.0, 0.0)
        else
            -- Любые другие PLAYER-юниты: всегда цвет класса
            local _, class = UnitClass(frame.unit)
            local color = RAID_CLASS_COLORS[class]
            if color then
                frame.healthbar:SetStatusBarColor(color.r, color.g, color.b)
            end
        end
    else
        -- НЕ игрок: снимаем блокировку и не трогаем цвет
        -- Пусть Blizzard сам управляет цветом для NPC/мобов
        frame.healthbar.lockColor = nil
    end
end

PowerBarColor = PowerBarColor or {};
PowerBarColor["RAGE"].fullPowerAnim = true;
PowerBarColor["ENERGY"].fullPowerAnim = true;

function GetPowerBarColor(powerType)
	return PowerBarColor[powerType];
end

function UnitGetIncomingHeals(unit, healer)
	if not ( unit and HealComm ) then
		return;
	end

	if ( healer ) then
		return HealComm:GetCasterHealAmount(UnitGUID(healer), HealComm.CASTED_HEALS, GetTime() + 5);
	else
		return HealComm:GetHealAmount(UnitGUID(unit), HealComm.ALL_HEALS, GetTime() + 5);
	end
end

function UnitGetTotalAbsorbs(unit)
	if not ( unit and LibAbsorb ) then
		return;
	end

	return LibAbsorb.Unit_Total(UnitGUID(unit));
end

function UnitGetTotalHealAbsorbs(unit) -- there is nothing like this in the WotLK patch
	return;
end

local function UnitFrameUtil_UpdateFillBarBase(frame, realbar, previousTexture, bar, amount, barOffsetXPercent)
	if ( amount == 0 ) then
		bar:Hide();
		if ( bar.overlay ) then
			bar.overlay:Hide();
		end
		return previousTexture;
	end
	local barOffsetX = 0;
	if ( barOffsetXPercent ) then
		local realbarSizeX = realbar:GetWidth();
		barOffsetX = realbarSizeX * barOffsetXPercent;
	end
	bar:SetPoint("TOPLEFT", previousTexture, "TOPRIGHT", barOffsetX, 0);
	bar:SetPoint("BOTTOMLEFT", previousTexture, "BOTTOMRIGHT", barOffsetX, 0);
	local totalWidth, totalHeight = realbar:GetSize();
	local _, totalMax = realbar:GetMinMaxValues();
	
	-- Validate inputs to prevent negative barSize
	if totalMax <= 0 or amount < 0 then
		bar:Hide();
		if ( bar.overlay ) then
			bar.overlay:Hide();
		end
		return previousTexture;
	end
	
	local barSize = (amount / totalMax) * totalWidth;
	
	-- Ensure barSize is not negative
	if barSize < 0 then
		bar:Hide();
		if ( bar.overlay ) then
			bar.overlay:Hide();
		end
		return previousTexture;
	end
	
	bar:SetWidth(barSize);
	bar:Show();

	if ( bar.overlay ) then
		-- Ensure tileSize is valid and barSize is positive
		local tileSize = bar.overlay.tileSize or 32;
		if tileSize > 0 and barSize > 0 then
			bar.overlay:SetTexCoord(0, barSize / tileSize, 0, totalHeight / tileSize);
			bar.overlay:Show();
		else
			bar.overlay:Hide();
		end
	end
	return bar;
end

local function UnitFrameUtil_UpdateFillBar(frame, previousTexture, bar, amount, barOffsetXPercent)
	return UnitFrameUtil_UpdateFillBarBase(frame, frame.healthbar, previousTexture, bar, amount, barOffsetXPercent);
end

local MAX_INCOMING_HEAL_OVERFLOW = 1.0;
local function UnitFrameHealPredictionBars_Update(frame)
	if not IsEnabled() then
		return;
	end
	if ( not frame.myHealPredictionBar ) then
		return;
	end
	-- Custom frames (SarychUI plate) can be switched off at runtime.
	if ( frame.uflDisabled ) then
		return;
	end
	local _, maxHealth = frame.healthbar:GetMinMaxValues();
	local health = frame.healthbar:GetValue();
	if ( maxHealth <= 0 ) then
		return;
	end
	local myIncomingHeal = UnitGetIncomingHeals(frame.unit, "player") or 0;
	local allIncomingHeal = UnitGetIncomingHeals(frame.unit) or 0;
	local totalAbsorb = UnitGetTotalAbsorbs(frame.unit) or 0;
	local myCurrentHealAbsorb = 0;

	if ( frame.healAbsorbBar ) then
		myCurrentHealAbsorb = UnitGetTotalHealAbsorbs(frame.unit) or 0;
		--We don't fill outside the health bar with healAbsorbs.  Instead, an overHealAbsorbGlow is shown.
		if ( health < myCurrentHealAbsorb ) then
			frame.overHealAbsorbGlow:Show();
			myCurrentHealAbsorb = health;
		else
			frame.overHealAbsorbGlow:Hide();
		end
	end
	--See how far we're going over the health bar and make sure we don't go too far out of the frame.
	if ( health - myCurrentHealAbsorb + allIncomingHeal > maxHealth * MAX_INCOMING_HEAL_OVERFLOW ) then
		allIncomingHeal = maxHealth * MAX_INCOMING_HEAL_OVERFLOW - health + myCurrentHealAbsorb;
	end
	local otherIncomingHeal = 0;
	--Split up incoming heals.
	if ( allIncomingHeal >= myIncomingHeal ) then
		otherIncomingHeal = allIncomingHeal - myIncomingHeal;
	else
		myIncomingHeal = allIncomingHeal;
	end
	--We don't fill outside the the health bar with absorbs.  Instead, an overAbsorbGlow is shown.
	local overAbsorb = false;
	if ( health - myCurrentHealAbsorb + allIncomingHeal + totalAbsorb >= maxHealth or health + totalAbsorb >= maxHealth ) then
		if ( totalAbsorb > 0 ) then
			overAbsorb = true;
		end
		if ( allIncomingHeal > myCurrentHealAbsorb ) then
			totalAbsorb = max(0,maxHealth - (health - myCurrentHealAbsorb + allIncomingHeal));
		else
			totalAbsorb = max(0,maxHealth - health);
		end
	end

	if ( overAbsorb ) then
		frame.overAbsorbGlow:Show();
	else
		frame.overAbsorbGlow:Hide();
	end
	local healthTexture = frame.healthbar:GetStatusBarTexture();
	local myCurrentHealAbsorbPercent = 0;
	local healAbsorbTexture = nil;
	if ( frame.healAbsorbBar ) then
		myCurrentHealAbsorbPercent = myCurrentHealAbsorb / maxHealth;
		--If allIncomingHeal is greater than myCurrentHealAbsorb, then the current
		--heal absorb will be completely overlayed by the incoming heals so we don't show it.
		if ( myCurrentHealAbsorb > allIncomingHeal ) then
			local shownHealAbsorb = myCurrentHealAbsorb - allIncomingHeal;
			local shownHealAbsorbPercent = shownHealAbsorb / maxHealth;
			healAbsorbTexture = UnitFrameUtil_UpdateFillBar(frame, healthTexture, frame.healAbsorbBar, shownHealAbsorb, -shownHealAbsorbPercent);
			--If there are incoming heals the left shadow would be overlayed by the incoming heals
			--so it isn't shown.
			if ( allIncomingHeal > 0 ) then
				frame.healAbsorbBarLeftShadow:Hide();
			else
				frame.healAbsorbBarLeftShadow:SetPoint("TOPLEFT", healAbsorbTexture, "TOPLEFT", 0, 0);
				frame.healAbsorbBarLeftShadow:SetPoint("BOTTOMLEFT", healAbsorbTexture, "BOTTOMLEFT", 0, 0);
				frame.healAbsorbBarLeftShadow:Show();
			end
			-- The right shadow is only shown if there are absorbs on the health bar.
			if ( totalAbsorb > 0 ) then
				frame.healAbsorbBarRightShadow:SetPoint("TOPLEFT", healAbsorbTexture, "TOPRIGHT", -8, 0);
				frame.healAbsorbBarRightShadow:SetPoint("BOTTOMLEFT", healAbsorbTexture, "BOTTOMRIGHT", -8, 0);
				frame.healAbsorbBarRightShadow:Show();
			else
				frame.healAbsorbBarRightShadow:Hide();
			end
		else
			frame.healAbsorbBar:Hide();
			frame.healAbsorbBarLeftShadow:Hide();
			frame.healAbsorbBarRightShadow:Hide();
		end
    end
--Show myIncomingHeal on the health bar.
	local incomingHealTexture = UnitFrameUtil_UpdateFillBar(frame, healthTexture, frame.myHealPredictionBar, myIncomingHeal, -myCurrentHealAbsorbPercent);
	--Append otherIncomingHeal on the health bar
	if (myIncomingHeal > 0) then
		incomingHealTexture = UnitFrameUtil_UpdateFillBar(frame, incomingHealTexture, frame.otherHealPredictionBar, otherIncomingHeal);
	else
		incomingHealTexture = UnitFrameUtil_UpdateFillBar(frame, healthTexture, frame.otherHealPredictionBar, otherIncomingHeal, -myCurrentHealAbsorbPercent);
	end
	--Append absorbs to the correct section of the health bar.
	local appendTexture = nil;
	if ( healAbsorbTexture ) then
		--If there is a healAbsorb part shown, append the absorb to the end of that.
		appendTexture = healAbsorbTexture;
	else
		--Otherwise, append the absorb to the end of the the incomingHeals part;
		appendTexture = incomingHealTexture;
	end
	UnitFrameUtil_UpdateFillBar(frame, appendTexture, frame.totalAbsorbBar, totalAbsorb)
	-- Обновляем цвет только если настройка включена или это игрок
	local classColorHPEnabled = true
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.UnitFrameLayers then
		local val = SarychUI.db.profile.addons.UnitFrameLayers.classColorHP
		classColorHPEnabled = val ~= false
	end
	-- Вызываем UpdateHealthBarColor только если настройка включена или это игрок
	-- (custom frames keep their own colors: frame.uflSkipColor)
	if not frame.uflSkipColor and (classColorHPEnabled or UnitIsPlayer(frame.unit)) then
		UpdateHealthBarColor(frame)
	end
end

local function LibEventCallback(self, event, ... )
	if not IsEnabled() then
		return;
	end
	if ( not self.unit ) then
		return;
	end

	local guid = UnitGUID(self.unit);
	if ( not guid ) then
		return;
	end

	local arg1, arg2, arg3, arg4, arg5 = ...;

	-- AbsorbsMonitor-1.0: same events and GUID slots as CompactRaidFrame_HealEx.
	if ( event == "EffectApplied" or event == "EffectUpdated" or event == "EffectRemoved" or
	   event == "UnitUpdated" or event == "UnitCleared" or event == "AreaCreated" or
	   event == "AreaUpdated" or event == "AreaCleared" ) then
		if ( arg1 == guid or arg3 == guid ) then
			UnitFrameHealPredictionBars_Update(self);
		end
		return;
	end

	if ( event == "COMPACT_UNIT_FRAME_UNIT_AURA" and arg1 == guid ) then
		UnitFrameHealPredictionBars_Update(self);
		return;
	end

	if ( arg5 == guid ) then
		if ( event == "HealComm_HealUpdated" or event == "HealComm_HealStarted" or
		   event == "HealComm_HealDelayed" or event == "HealComm_HealStopped" or
		   event == "HealComm_ModifierChanged" or event == "HealComm_GUIDDisappeared" ) then
			UnitFrameHealPredictionBars_Update(self);
		end
		return;
	end

	if ( ... ) then
		for i = 1, select("#", ...) do
			if ( select(i, ...) == guid ) then
				if ( event == "HealComm_HealUpdated" or event == "HealComm_HealStarted" or
				   event == "HealComm_HealDelayed" or event == "HealComm_HealStopped" or
				   event == "HealComm_ModifierChanged" or event == "HealComm_GUIDDisappeared" ) then
					UnitFrameHealPredictionBars_Update(self);
				end
				break;
			end
		end
	end
end

local function UnitFrame_RegisterCallback(self)
	if ( LibAbsorb ) then
		LibAbsorb.RegisterCallback(self, "EffectApplied", LibEventCallback, self);
		LibAbsorb.RegisterCallback(self, "EffectUpdated", LibEventCallback, self);
		LibAbsorb.RegisterCallback(self, "EffectRemoved", LibEventCallback, self);
		LibAbsorb.RegisterCallback(self, "UnitUpdated", LibEventCallback, self);
		LibAbsorb.RegisterCallback(self, "UnitCleared", LibEventCallback, self);
		LibAbsorb.RegisterCallback(self, "AreaCreated", LibEventCallback, self);
		LibAbsorb.RegisterCallback(self, "AreaUpdated", LibEventCallback, self);
		LibAbsorb.RegisterCallback(self, "AreaCleared", LibEventCallback, self);
	end

	HealComm.RegisterCallback(self, "HealComm_HealStarted", LibEventCallback, self);
	HealComm.RegisterCallback(self, "HealComm_HealUpdated", LibEventCallback, self);
	HealComm.RegisterCallback(self, "HealComm_HealDelayed", LibEventCallback, self);
	HealComm.RegisterCallback(self, "HealComm_HealStopped", LibEventCallback, self);
	HealComm.RegisterCallback(self, "HealComm_ModifierChanged", LibEventCallback, self);
	HealComm.RegisterCallback(self, "HealComm_GUIDDisappeared", LibEventCallback, self);
end

local function UnitFrameLayer_Initialize(self, myHealPredictionBar, otherHealPredictionBar, totalAbsorbBar, totalAbsorbBarOverlay,
	overAbsorbGlow, overHealAbsorbGlow, healAbsorbBar, healAbsorbBarLeftShadow, healAbsorbBarRightShadow, myManaCostPredictionBar)

	self.myHealPredictionBar = myHealPredictionBar;
	self.otherHealPredictionBar = otherHealPredictionBar
	self.totalAbsorbBar = totalAbsorbBar;
	self.totalAbsorbBarOverlay = totalAbsorbBarOverlay;
	self.overAbsorbGlow = overAbsorbGlow;
	self.overHealAbsorbGlow = overHealAbsorbGlow;
	self.healAbsorbBar = healAbsorbBar;
	self.healAbsorbBarLeftShadow = healAbsorbBarLeftShadow;
	self.healAbsorbBarRightShadow = healAbsorbBarRightShadow;
	self.myManaCostPredictionBar = myManaCostPredictionBar;

	if ( self.unit == "player" ) then 
		self.myManaCostPredictionBar:ClearAllPoints();

		self:RegisterEvent("UNIT_SPELLCAST_START");
		self:RegisterEvent("UNIT_SPELLCAST_STOP");
		self:RegisterEvent("UNIT_SPELLCAST_FAILED");
		self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED");
	else
		self.myManaCostPredictionBar:Hide();
	end

    self.myHealPredictionBar:ClearAllPoints();

    self.otherHealPredictionBar:ClearAllPoints();

    self.totalAbsorbBar:ClearAllPoints();

    self.totalAbsorbBar.overlay = self.totalAbsorbBarOverlay;
    self.totalAbsorbBarOverlay:SetAllPoints(self.totalAbsorbBar);
    self.totalAbsorbBarOverlay.tileSize = 32;

    self.overAbsorbGlow:ClearAllPoints();
	self.overAbsorbGlow:SetWidth(16);
    self.overAbsorbGlow:SetPoint("TOPLEFT", self.healthbar, "TOPRIGHT", -7, 0);
    self.overAbsorbGlow:SetPoint("BOTTOMLEFT", self.healthbar, "BOTTOMRIGHT",  -7, 0);

    self.healAbsorbBar:ClearAllPoints();
    self.healAbsorbBar:SetTexture("Interface\\RaidFrame\\Absorb-Fill", true, true);

    self.overHealAbsorbGlow:ClearAllPoints();
    self.overHealAbsorbGlow:SetPoint("BOTTOMRIGHT", self.healthbar, "BOTTOMLEFT", 7, 0);
    self.overHealAbsorbGlow:SetPoint("TOPRIGHT", self.healthbar, "TOPLEFT", 7, 0);

    self.healAbsorbBarLeftShadow:ClearAllPoints();

    self.healAbsorbBarRightShadow:ClearAllPoints();

	self:RegisterEvent("UNIT_MAXHEALTH");
    UnitFrame_RegisterCallback(self);

	if ( self.unit == "player" ) then
		self.PlayerFrameHealthBarAnimatedLoss = CreateFrame("StatusBar", nil, self, "PlayerFrameHealthBarAnimatedLossTemplate");
		self.PlayerFrameHealthBarAnimatedLoss:SetUnitHealthBar("player", self.healthbar);
		self.PlayerFrameHealthBarAnimatedLoss:SetFrameLevel(self.healthbar:GetFrameLevel() - 1)

		if ( self.manabar ) then
			self.manabar.FeedbackFrame = CreateFrame("Frame", nil, self.manabar, "BuilderSpenderFrame");
			self.manabar.FeedbackFrame:SetAllPoints();
			self.manabar.FeedbackFrame:SetFrameLevel(self:GetParent():GetFrameLevel() + 2);

			self.manabar.FullPowerFrame = CreateFrame("Frame", nil, self.manabar, "FullPowerFrameTemplate");
			self.manabar:SetScript("OnUpdate", UnitFrameManaBar_OnUpdate);
		end
	end

	UnitFrame_Update(self);
end

--------------------------------------------------------------------
-- Public API for custom (non-Blizzard) unit frames, e.g. SarychUI player plate.
-- Requirements: frame has a global name, frame.unit and frame.healthbar (StatusBar).
-- Draw order: loss bar = healthbar level-1, prediction textures = level+1,
-- over-absorb glow = level+2. The healthbar must not own its own opaque
-- background (put it on the parent) or the loss bar will be hidden by it.
--------------------------------------------------------------------
function UnitFrameLayers_AttachHealPrediction(frame)
	if ( not frame or not frame.unit or not frame.healthbar ) then
		return nil;
	end
	if ( frame.myHealPredictionBar ) then
		return frame.uflPredictionFrame;
	end
	local name = frame:GetName();
	if ( not name ) then
		return nil;
	end

	local healthbar = frame.healthbar;
	local pred = CreateFrame("Frame", nil, frame, "StatusBarHealPredictionTemplate");
	pred:ClearAllPoints();
	pred:SetAllPoints(healthbar);
	pred:SetFrameLevel(healthbar:GetFrameLevel() + 1);
	frame.uflPredictionFrame = pred;
	frame.uflSkipColor = true;

	local glowFrame = _G[name.."FrameOverAbsorb"];
	if ( glowFrame ) then
		glowFrame:SetFrameLevel(healthbar:GetFrameLevel() + 2);
	end

	frame.myHealPredictionBar = _G[name.."FrameMyHealPredictionBar"];
	frame.otherHealPredictionBar = _G[name.."FrameOtherHealPredictionBar"];
	frame.totalAbsorbBar = _G[name.."TotalAbsorbBar"];
	frame.totalAbsorbBarOverlay = _G[name.."TotalAbsorbBarOverlay"];
	frame.overAbsorbGlow = _G[name.."FrameOverAbsorbGlow"];
	frame.overHealAbsorbGlow = _G[name.."OverHealAbsorbGlow"];
	frame.healAbsorbBar = _G[name.."HealAbsorbBar"];
	frame.healAbsorbBarLeftShadow = _G[name.."HealAbsorbBarLeftShadow"];
	frame.healAbsorbBarRightShadow = _G[name.."HealAbsorbBarRightShadow"];
	frame.myManaCostPredictionBar = _G[name.."FrameManaCostPredictionBar"];

	if ( frame.myManaCostPredictionBar ) then
		frame.myManaCostPredictionBar:ClearAllPoints();
		frame.myManaCostPredictionBar:Hide();
	end

	frame.myHealPredictionBar:ClearAllPoints();
	frame.myHealPredictionBar:Hide();
	frame.otherHealPredictionBar:ClearAllPoints();
	frame.otherHealPredictionBar:Hide();

	frame.totalAbsorbBar:ClearAllPoints();
	frame.totalAbsorbBar:Hide();
	frame.totalAbsorbBar.overlay = frame.totalAbsorbBarOverlay;
	frame.totalAbsorbBarOverlay:SetAllPoints(frame.totalAbsorbBar);
	frame.totalAbsorbBarOverlay.tileSize = 32;
	frame.totalAbsorbBarOverlay:Hide();

	frame.overAbsorbGlow:ClearAllPoints();
	frame.overAbsorbGlow:SetWidth(16);
	frame.overAbsorbGlow:SetPoint("TOPLEFT", healthbar, "TOPRIGHT", -7, 0);
	frame.overAbsorbGlow:SetPoint("BOTTOMLEFT", healthbar, "BOTTOMRIGHT", -7, 0);
	frame.overAbsorbGlow:Hide();

	frame.healAbsorbBar:ClearAllPoints();
	frame.healAbsorbBar:SetTexture("Interface\\RaidFrame\\Absorb-Fill", true, true);
	frame.healAbsorbBar:Hide();
	frame.overHealAbsorbGlow:ClearAllPoints();
	frame.overHealAbsorbGlow:SetPoint("BOTTOMRIGHT", healthbar, "BOTTOMLEFT", 7, 0);
	frame.overHealAbsorbGlow:SetPoint("TOPRIGHT", healthbar, "TOPLEFT", 7, 0);
	frame.overHealAbsorbGlow:Hide();
	frame.healAbsorbBarLeftShadow:ClearAllPoints();
	frame.healAbsorbBarLeftShadow:Hide();
	frame.healAbsorbBarRightShadow:ClearAllPoints();
	frame.healAbsorbBarRightShadow:Hide();

	UnitFrame_RegisterCallback(frame);

	if ( frame.unit == "player" and not frame.PlayerFrameHealthBarAnimatedLoss ) then
		local loss = CreateFrame("StatusBar", nil, frame, "PlayerFrameHealthBarAnimatedLossTemplate");
		loss:SetUnitHealthBar("player", healthbar);
		loss:SetFrameLevel(math.max(healthbar:GetFrameLevel() - 1, 0));
		frame.PlayerFrameHealthBarAnimatedLoss = loss;
	end

	UnitFrameHealPredictionBars_Update(frame);
	return pred;
end

function UnitFrameLayers_UpdateHealPrediction(frame)
	if ( frame and frame.myHealPredictionBar ) then
		UnitFrameHealPredictionBars_Update(frame);
	end
end

function UnitFrameLayers_SetHealPredictionEnabled(frame, enabled)
	if ( not frame or not frame.myHealPredictionBar ) then
		return;
	end
	frame.uflDisabled = not enabled;
	if ( enabled ) then
		UnitFrameHealPredictionBars_Update(frame);
		return;
	end
	for _, key in ipairs({ "myHealPredictionBar", "otherHealPredictionBar", "totalAbsorbBar",
		"totalAbsorbBarOverlay", "overAbsorbGlow", "overHealAbsorbGlow", "healAbsorbBar",
		"healAbsorbBarLeftShadow", "healAbsorbBarRightShadow", "myManaCostPredictionBar" }) do
		if ( frame[key] ) then
			frame[key]:Hide();
		end
	end
	if ( frame.PlayerFrameHealthBarAnimatedLoss ) then
		frame.PlayerFrameHealthBarAnimatedLoss:CancelAnimation();
	end
end

function UnitFrameHealthBar_OnUpdate(self)
	if not IsEnabled() then
		return;
	end
	if ( not self.disconnected and not self.lockValues) then
		local currValue = UnitHealth(self.unit);
		local animatedLossBar = self.AnimatedLossBar;
		if ( currValue ~= self.currValue ) then
			if ( not self.ignoreNoUnit or UnitGUID(self.unit) ) then
				if animatedLossBar then
					animatedLossBar:UpdateHealth(currValue, self.currValue);
				end
				self:SetValue(currValue);
				self.currValue = currValue;
				TextStatusBar_UpdateTextString(self);
				UnitFrameHealPredictionBars_Update(self:GetParent());
			end
		end
		if animatedLossBar then
			animatedLossBar:UpdateLossAnimation(currValue);
		end
	end
end

function UnitFrameManaBar_OnUpdate(self)
	if not IsEnabled() then
		return;
	end
	if ( not self.disconnected and not self.lockValues ) then
		local predictedCost = self:GetParent().predictedPowerCost;
		local currValue = UnitPower(self.unit, self.powerType);
		if (predictedCost) then
			currValue = currValue - Round(predictedCost);
		end
		if ( currValue ~= self.currValue or self.forceUpdate ) then
			self.forceUpdate = nil;
			if ( not self.ignoreNoUnit or UnitGUID(self.unit) ) then
				if ( self.FeedbackFrame ) then
					-- Only show anim if change is more than 10%
					local oldValue = self.currValue or 0;
					if ( self.FeedbackFrame.maxValue ~= 0 and math.abs(currValue - oldValue) / self.FeedbackFrame.maxValue > 0.1 ) then
						self.FeedbackFrame:StartFeedbackAnim(oldValue, currValue);
					end
				end
				if ( self.FullPowerFrame and self.FullPowerFrame.active ) then
					self.FullPowerFrame:StartAnimIfFull(self.currValue or 0, currValue);
				end
				self:SetValue(currValue);
				self.currValue = currValue;
				TextStatusBar_UpdateTextString(self);
			end
		end
	end
end

function UnitFrameManaBar_Update(statusbar, unit)
	if not IsEnabled() then
		return;
	end
	if ( not statusbar or statusbar.lockValues ) then
		return;
	end
	if ( unit == statusbar.unit ) then
		-- be sure to update the power type before grabbing the max power!
		UnitFrameManaBar_UpdateType(statusbar);
		local maxValue = UnitPowerMax(unit, statusbar.powerType);
		statusbar:SetMinMaxValues(0, maxValue);
		statusbar.disconnected = not UnitIsConnected(unit);
		if ( statusbar.disconnected ) then
			statusbar:SetValue(maxValue);
			statusbar.currValue = maxValue;
			if ( not statusbar.lockColor ) then
				statusbar:SetStatusBarColor(0.5, 0.5, 0.5);
			end
		else
			local predictedCost = statusbar:GetParent().predictedPowerCost;
			local currValue = UnitPower(unit, statusbar.powerType);
			if (predictedCost) then
				currValue = currValue - predictedCost;
			end
			if ( statusbar.FullPowerFrame ) then
				statusbar.FullPowerFrame:SetMaxValue(maxValue);
			end
			statusbar:SetValue(currValue);
			statusbar.forceUpdate = true;
		end
	end
	TextStatusBar_UpdateTextString(statusbar);
end

local function UnitFrameUtil_UpdateManaFillBar(frame, previousTexture, bar, amount, barOffsetXPercent)
	return UnitFrameUtil_UpdateFillBarBase(frame, frame.manabar, previousTexture, bar, amount, barOffsetXPercent);
end

local function UnitFrameManaCostPredictionBars_Update(frame, isStarting, startTime, endTime, name)
	if not IsEnabled() then
		return;
	end
	if (not frame.manabar or not frame.myManaCostPredictionBar) then
		return;
	end
	local cost = 0;
	if (not isStarting or startTime == endTime) then
        local currentSpell = UnitCastingInfo(frame.unit);
        if(currentSpell and frame.predictedPowerCost) then --if we're currently casting something with a power cost, then whatever cast
		    cost = frame.predictedPowerCost;                 --just finished was allowed while casting, don't reset the original cast
        else
            frame.predictedPowerCost = nil;
        end
	else
		local costTable = GetSpellPowerCost(name);
		for _, costInfo in pairs(costTable) do
			if (costInfo.type == frame.manabar.powerType) then
				cost = costInfo.cost;
				break;
			end
		end
		frame.predictedPowerCost = cost;
	end
	local manaBarTexture = frame.manabar:GetStatusBarTexture();
	UnitFrameManaBar_Update(frame.manabar, frame.unit);
	UnitFrameUtil_UpdateManaFillBar(frame, manaBarTexture, frame.myManaCostPredictionBar, cost);
end

function UnitFrameManaBar_UpdateType(manaBar)
	if not IsEnabled() then
		return;
	end
	if ( not manaBar ) then
		return;
	end
	local unitFrame = manaBar:GetParent();
	local powerType, powerToken, altR, altG, altB = UnitPowerType(manaBar.unit);
	local prefix = _G[powerToken];
	local info = PowerBarColor[powerToken];
	if ( info ) then
		if ( not manaBar.lockColor ) then
			local playerDeadOrGhost = (manaBar.unit == "player" and (UnitIsDead("player") or UnitIsGhost("player")));
			if ( info.atlas ) then
				manaBar:SetStatusBarAtlas(info.atlas);
				manaBar:SetStatusBarColor(1, 1, 1);
				manaBar:GetStatusBarTexture():SetDesaturated(playerDeadOrGhost);
				manaBar:GetStatusBarTexture():SetAlpha(playerDeadOrGhost and 0.5 or 1);
			else
				manaBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
				if ( playerDeadOrGhost ) then
					manaBar:SetStatusBarColor(0.6, 0.6, 0.6, 0.5);
				else
					manaBar:SetStatusBarColor(info.r, info.g, info.b);
				end
			end
			if ( manaBar.FeedbackFrame ) then
				manaBar.FeedbackFrame:Initialize(info, manaBar.unit, powerType);
			end
			if ( manaBar.FullPowerFrame ) then
				manaBar.FullPowerFrame:Initialize(info.fullPowerAnim);
			end
		end
	else
		if ( not altR) then
			-- couldn't find a power token entry...default to indexing by power type or just mana if we don't have that either
			info = PowerBarColor[powerType] or PowerBarColor["MANA"];
		else
			if ( not manaBar.lockColor ) then
				manaBar:SetStatusBarColor(altR, altG, altB);
			end
		end
	end
	if ( manaBar.powerType ~= powerType or manaBar.powerType ~= powerType ) then
		manaBar.powerType = powerType;
		manaBar.powerToken = powerToken;
		if ( manaBar.FullPowerFrame ) then
			manaBar.FullPowerFrame:RemoveAnims();
		end
		if manaBar.FeedbackFrame then
			manaBar.FeedbackFrame:StopFeedbackAnim();
		end
		manaBar.currValue = UnitPower("player", powerType);
		if unitFrame.myManaCostPredictionBar then
			unitFrame.myManaCostPredictionBar:Hide();
		end
		unitFrame.predictedPowerCost = 0;
	end

	-- Update the manabar text
	if ( not unitFrame.noTextPrefix ) then
		SetTextStatusBarTextPrefix(manaBar, prefix);
	end
	TextStatusBar_UpdateTextString(manaBar);
	-- Setup newbie tooltip
	if ( manaBar.unit ~= "pet") then
		if ( unitFrame:GetName() == "PlayerFrame" ) then
			manaBar.tooltipTitle = prefix;
			manaBar.tooltipText = _G["NEWBIE_TOOLTIP_MANABAR_"..powerType];
		else
			manaBar.tooltipTitle = nil;
			manaBar.tooltipText = nil;
		end
	end
end

local function UnitFrameHealPredictionBars_UpdateMax(self)
	if not IsEnabled() then
		return;
	end
	if ( not self.myHealPredictionBar ) then
		return;
	end
	UnitFrameHealPredictionBars_Update(self);
end

hooksecurefunc("UnitFrameHealthBar_Update", function(statusbar, unit)
	if not IsEnabled() then
		return;
	end
	if statusbar.AnimatedLossBar then
		statusbar.AnimatedLossBar:UpdateHealthMinMax();
	end
	local parent = statusbar:GetParent();
	UnitFrameHealPredictionBars_Update(parent);
	-- После стандартной перекраски Blizzard снова ставим цвет класса (live toggle).
	if parent then
		UpdateHealthBarColor(parent);
	end
end);

hooksecurefunc("UnitFrame_Update", function(self, isParty)
	if not IsEnabled() then
		return;
	end
	UnitFrameHealPredictionBars_UpdateMax(self);
	UnitFrameHealPredictionBars_Update(self);
	UnitFrameManaCostPredictionBars_Update(self);
	UpdateHealthBarColor(self);
end);

hooksecurefunc("UnitFrame_OnEvent", function(self, event, ...)
	if not IsEnabled() then
		return;
	end

	if ( not self.myHealPredictionBar ) then
		CreateFrame("Frame", nil, self, "StatusBarHealPredictionTemplate");
		local thisName = self:GetName();

		UnitFrameLayer_Initialize(self, _G[thisName.."FrameMyHealPredictionBar"], _G[thisName.."FrameOtherHealPredictionBar"],
									_G[thisName.."TotalAbsorbBar"], _G[thisName.."TotalAbsorbBarOverlay"],
									_G[thisName.."FrameOverAbsorbGlow"], _G[thisName.."OverHealAbsorbGlow"],
									_G[thisName.."HealAbsorbBar"], _G[thisName.."HealAbsorbBarLeftShadow"],
									_G[thisName.."HealAbsorbBarRightShadow"], _G[thisName.."FrameManaCostPredictionBar"]);
	end

	UnitFrameHealPredictionBars_Update(self);

	if ( event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_SUCCEEDED" ) then
		local unit = ...;
		if ( UnitIsUnit(unit, "player") ) then
			local name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitCastingInfo(unit);
			UnitFrameManaCostPredictionBars_Update(self, event == "UNIT_SPELLCAST_START", startTime, endTime, name);
		end
	end
end)

-- Вспомогательная функция для правильного поиска фреймов по unit
local function GetUnitFrameByUnit(unit)
    if unit == "player" then
        return _G["PlayerFrame"]
    elseif unit == "target" then
        return _G["TargetFrame"]
    elseif unit == "focus" then
        return _G["FocusFrame"]
    elseif unit == "pet" then
        return _G["PetFrame"]
    end
    local n = unit:match("^party(%d+)$")
    if n then
        return _G["PartyMemberFrame"..n]
    end
    return _G[unit.."Frame"] -- запасной вариант, вдруг где-то совпадёт
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
frame:RegisterEvent("UNIT_HEALTH")
frame:RegisterEvent("UNIT_POWER_UPDATE")
frame:RegisterEvent("UNIT_DISPLAYPOWER")

frame:SetScript("OnEvent", function(self, event, unit)
	if not IsEnabled() then
		return;
	end
    if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
        -- Обновляем цвет для всех групповых фреймов
        local units = {"player", "target", "focus", "party1", "party2", "party3", "party4"}
        for _, u in ipairs(units) do
            local f = GetUnitFrameByUnit(u)
            if f then
                -- Вызываем всегда, но функция сама решит по настройкам
                UpdateHealthBarColor(f)
            end
        end
        -- Обновляем полосу ресурса игрока (после смерти/воскрешения)
        local pf = PlayerFrame
        if pf and pf.manabar then
            UnitFrameManaBar_Update(pf.manabar, "player")
        end
    else
        if unit then
            local f = GetUnitFrameByUnit(unit)
            if f then
                -- Вызываем всегда, но функция сама решит по настройкам
                UpdateHealthBarColor(f)
            end
            -- При изменении здоровья игрока (в т.ч. воскрешение) обновляем полосу ресурса
            if unit == "player" and (event == "UNIT_HEALTH" or event == "UNIT_POWER_UPDATE" or event == "UNIT_DISPLAYPOWER") then
                local pf = PlayerFrame
                if pf and pf.manabar then
                    UnitFrameManaBar_Update(pf.manabar, "player")
                end
            end
        end
    end
end)