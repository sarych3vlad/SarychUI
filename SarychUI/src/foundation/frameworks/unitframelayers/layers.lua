local CompatMath = select(2, ...).Compat.Math
local Round = CompatMath.Round
--######################################################################
--######                   	UnitFrameLayers                      #######
------------------------------------------------------------------------
--######################################################################

local HealComm = SarychUI.UnitFrameLayers.healComm;
local UFL = SarychUI.UnitFrameLayers;

-- Read the shared framework setting.
local function IsEnabled()
	return SarychUI.UnitFrameLayers:IsEnabled()
end

local function ArenaTestIndex(frame)
	if IsInInstance and select(2, IsInInstance()) == "arena" then return end
	local arena = SarychUI and SarychUI.db and SarychUI.db.profile
		and SarychUI.db.profile.modules and SarychUI.db.profile.modules.arena
	if not (arena and (arena.testMode or 0) > 0) then return end
	local testContainer = _G.SarychUIArenaTestContainer
	if not (testContainer and testContainer:IsShown()) then return end
	local name = frame and frame.GetName and frame:GetName()
	local index = name and tonumber(name:match("^ArenaEnemyFrame(%d+)$"))
	if index and index <= arena.testMode then return index end
end

--------------------------------------------------------------------
-- Public color helper used by frame options.
function UpdateHealthBarColor(frame)
	if not IsEnabled() then
		return;
	end
    if not frame or frame.uflSkipColor or not frame.unit or not frame.healthbar then return end

    local isArenaFrame = frame.unit:match("^arena%d+$") and frame.GetName
        and frame:GetName():match("^ArenaEnemyFrame%d+$")
    if isArenaFrame then
        -- Arena has its own color switch. Keep it separate from the general
        -- UFL color option; prediction and loss layers are attached below.
        local arenaDb = SarychUI and SarychUI.db and SarychUI.db.profile
            and SarychUI.db.profile.modules and SarychUI.db.profile.modules.arena
		if arenaDb then
			local kind = arenaDb.frameType == "gladius" and "gladius" or "classic"
			local style = arenaDb.styles and arenaDb.styles[kind]
			if (style and style.classColorHP == false)
				or (not style and arenaDb.classColorHP == false) then return end
		end
        if not UnitIsPlayer(frame.unit) then return end
        local _, class = UnitClass(frame.unit)
        local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if color then UFL:SetBarColor(frame, frame.healthbar, color.r, color.g, color.b) end
        return
    end

    -- General health colors belong to the character-frame module.
    if not UFL:AreUnitFrameColorsEnabled() then return end

    -- Проверяем настройку цвета HP в цвет класса
    local classColorHPEnabled = true  -- По умолчанию включено
    if SarychUI and SarychUI.UnitFrameLayers and SarychUI.UnitFrameLayers:Settings() then
        local val = SarychUI.UnitFrameLayers:Settings().classColorHP
        -- nil или true = включено, false = выключено
        classColorHPEnabled = val ~= false
    end

    -- Если настройка выключена, снимаем блокировку и сразу возвращаем зелёный
    -- (иначе цвет «залипает» до reload)
    if not classColorHPEnabled then
        if UnitIsPlayer(frame.unit) then
            UFL:SetBarColor(frame, frame.healthbar, 0.0, 1.0, 0.0)
        end
        return
    end

    -- Проверяем, подключен ли игрок (для всех юнитов, но только игроки могут быть отключены)
    if not UnitIsConnected(frame.unit) then
        UFL:SetBarColor(frame, frame.healthbar, 0.5, 0.5, 0.5)
        return
    end

    -- Обрабатываем только игроков, для остальных (NPC/мобов) ничего не делаем
    -- Пусть Blizzard сам управляет цветом для не-игроков
    if UnitIsPlayer(frame.unit) then
        local isPlayerFrame = (frame:GetName() == "PlayerFrame")
        local playerClassColorEnabled = false
        
        if isPlayerFrame then
            -- Проверяем настройку для PlayerFrame
            if SarychUI and SarychUI.UnitFrameLayers and SarychUI.UnitFrameLayers:Settings() then
                playerClassColorEnabled = SarychUI.UnitFrameLayers:Settings().playerClassColorHP == true
            end
        end
        
        if isPlayerFrame and playerClassColorEnabled then
            -- Цвет класса для PlayerFrame если включено
            local _, class = UnitClass(frame.unit)
            local color = RAID_CLASS_COLORS[class]
            if color then
                UFL:SetBarColor(frame, frame.healthbar, color.r, color.g, color.b)
            else
                -- Fallback на зеленый, если класс не найден
                UFL:SetBarColor(frame, frame.healthbar, 0.0, 1.0, 0.0)
            end
        elseif isPlayerFrame then
            -- Зеленый цвет для PlayerFrame по умолчанию
            UFL:SetBarColor(frame, frame.healthbar, 0.0, 1.0, 0.0)
        else
            -- Любые другие PLAYER-юниты: всегда цвет класса
            local _, class = UnitClass(frame.unit)
            local color = RAID_CLASS_COLORS[class]
            if color then
                UFL:SetBarColor(frame, frame.healthbar, color.r, color.g, color.b)
            end
        end
    end
end

-- Do not replace the PowerBarColor global. PartyMemberFrame_OnEvent reads it
-- while the handler is still secure.
if PowerBarColor then
	if PowerBarColor["RAGE"] then
		PowerBarColor["RAGE"].fullPowerAnim = true
	end
	if PowerBarColor["ENERGY"] then
		PowerBarColor["ENERGY"].fullPowerAnim = true
	end
end

function GetPowerBarColor(powerType)
	return PowerBarColor[powerType];
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
	local testIndex = ArenaTestIndex(frame)
	local previewData = frame._suiTestData
	local visualUnit = testIndex == 1 and "player" or frame.unit
	local isArenaEnemy = frame.unit and frame.unit:match("^arena%d+$")
	-- Enemy healers do not send us HealComm predictions. Keep absorb layers,
	-- but never draw an estimated incoming-heal bar on enemy arena frames.
	local myIncomingHeal = previewData and maxHealth * previewData.myHeal
		or (isArenaEnemy and 0 or (UFL:GetIncomingHeals(visualUnit, "player") or 0));
	local allIncomingHeal = previewData and maxHealth * previewData.allHeal
		or (isArenaEnemy and 0 or (UFL:GetIncomingHeals(visualUnit) or 0));
	local totalAbsorb = previewData and maxHealth * previewData.absorb
		or (testIndex == 2 and maxHealth * 0.20 or (UFL:GetAbsorbs(visualUnit) or 0));
	local myCurrentHealAbsorb = 0;

	if ( frame.healAbsorbBar ) then
		myCurrentHealAbsorb = previewData and maxHealth * previewData.healAbsorb
			or 0;
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
	if SarychUI and SarychUI.UnitFrameLayers and SarychUI.UnitFrameLayers:Settings() then
		local val = SarychUI.UnitFrameLayers:Settings().classColorHP
		classColorHPEnabled = val ~= false
	end
	-- Вызываем UpdateHealthBarColor только если настройка включена или это игрок
	-- (custom frames keep their own colors: frame.uflSkipColor)
	if not frame.uflSkipColor and (classColorHPEnabled or UnitIsPlayer(frame.unit)) then
		UpdateHealthBarColor(frame)
	end
end

-- Keep gain/loss feedback below the artwork, but draw the full-power pulse
-- above it so the alert remains visible when the resource reaches maximum.
local function UnitFrameLayers_UpdatePlayerPowerFXLevel(bar)
	if not bar or not bar.FeedbackFrame or not bar.FullPowerFrame then
		return
	end
	local barLevel = bar:GetFrameLevel()
	local border = _G.PlayerFrameTexture
	local borderFrame = border and border:GetParent()
	local borderLevel = borderFrame and borderFrame:GetFrameLevel()
	local feedbackLevel = barLevel + 1
	if borderLevel and borderLevel > barLevel then
		feedbackLevel = math.min(feedbackLevel, borderLevel - 1)
	end
	local pulseLevel = math.max(barLevel + 1, borderLevel or 0)
	if bar._uflFeedbackLevel == feedbackLevel and bar._uflPulseLevel == pulseLevel then
		return
	end
	bar._uflFeedbackLevel = feedbackLevel
	bar._uflPulseLevel = pulseLevel
	bar.FeedbackFrame:SetFrameLevel(feedbackLevel)
	bar.FullPowerFrame:SetFrameLevel(pulseLevel)
	bar.FullPowerFrame.SpikeFrame:SetFrameLevel(pulseLevel + 1)
	bar.FullPowerFrame.PulseFrame:SetFrameLevel(pulseLevel + 1)
end

local borderTextures = {
	PlayerFrame = "PlayerFrameTexture",
	TargetFrame = "TargetFrameTextureFrameTexture",
	FocusFrame = "FocusFrameTextureFrameTexture",
	PetFrame = "PetFrameTexture",
}

local function UnitFrameLayers_UpdatePredictionLevel(frame)
	local pred = frame and frame.uflPredictionFrame
	local healthbar = frame and frame.healthbar
	if not pred or not healthbar then return end
	local barLevel = healthbar:GetFrameLevel()
	if frame.manabar then
		barLevel = math.max(barLevel, frame.manabar:GetFrameLevel())
	end
	local borderName = borderTextures[frame:GetName()]
	local border = borderName and _G[borderName]
	local borderFrame = border and border:GetParent()
	local borderLevel = borderFrame and borderFrame:GetFrameLevel()
	local predictionLevel = barLevel + 1
	local glowLevel = barLevel + 2
	if borderLevel and borderLevel > barLevel then
		predictionLevel = math.min(predictionLevel, borderLevel - 1)
		glowLevel = math.max(glowLevel, borderLevel + 1)
	end
	if frame._uflPredictionLevel ~= predictionLevel then
		pred:SetFrameLevel(predictionLevel)
		frame._uflPredictionLevel = predictionLevel
	end
	local glow = frame.uflOverAbsorbFrame
	if glow and frame._uflGlowLevel ~= glowLevel then
		glow:SetFrameLevel(glowLevel)
		frame._uflGlowLevel = glowLevel
	end
end

--------------------------------------------------------------------
-- Public API for custom (non-Blizzard) unit frames, e.g. SarychUI player plate.
-- Requirements: frame has a global name, frame.unit and frame.healthbar (StatusBar).
-- Draw order: loss bar = healthbar level-1; prediction textures stay below
-- the unit-frame artwork. The healthbar must not own its own opaque
-- background (put it on the parent) or the loss bar will be hidden by it.
--------------------------------------------------------------------
function UnitFrameLayers_AttachHealPrediction(frame, skipColor, skipCallback)
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
	local predictionName = name.."UFLPrediction";
	local pred = _G[predictionName] or CreateFrame("Frame", predictionName, frame, "StatusBarHealPredictionTemplate");
	pred:ClearAllPoints();
	pred:SetAllPoints(healthbar);
	frame.uflPredictionFrame = pred;
	frame.uflSkipColor = skipColor ~= false;

	local glowFrame = _G[predictionName.."FrameOverAbsorb"];
	frame.uflOverAbsorbFrame = glowFrame;
	UnitFrameLayers_UpdatePredictionLevel(frame);

	frame.myHealPredictionBar = _G[predictionName.."FrameMyHealPredictionBar"];
	frame.otherHealPredictionBar = _G[predictionName.."FrameOtherHealPredictionBar"];
	frame.totalAbsorbBar = _G[predictionName.."TotalAbsorbBar"];
	frame.totalAbsorbBarOverlay = _G[predictionName.."TotalAbsorbBarOverlay"];
	frame.overAbsorbGlow = _G[predictionName.."FrameOverAbsorbGlow"];
	frame.overHealAbsorbGlow = _G[predictionName.."OverHealAbsorbGlow"];
	frame.healAbsorbBar = _G[predictionName.."HealAbsorbBar"];
	frame.healAbsorbBarLeftShadow = _G[predictionName.."HealAbsorbBarLeftShadow"];
	frame.healAbsorbBarRightShadow = _G[predictionName.."HealAbsorbBarRightShadow"];
	frame.myManaCostPredictionBar = _G[predictionName.."FrameManaCostPredictionBar"];

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

	if not skipCallback then
		SarychUI.UnitFrameLayers.RegisterLibraryCallbacks(frame);
	end

	if ( not frame._suiTestData and not frame.uflNoAnimatedLoss
		and not frame.PlayerFrameHealthBarAnimatedLoss ) then
		local loss = CreateFrame("StatusBar", nil, frame, "PlayerFrameHealthBarAnimatedLossTemplate");
		loss:SetUnitHealthBar(frame.unit, healthbar);
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
	if not enabled and frame._suiResourceGain then frame._suiResourceGain:Hide() end
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

-- Never replace FrameXML's global handler: Blizzard_ArenaUI reads it while
-- constructing secure arena buttons, and an addon-owned value taints OnLoad.
local function UnitFrameLayers_HealthBar_OnUpdate(self, unitFrame)
	if not IsEnabled() then
		return;
	end
	local testIndex = ArenaTestIndex(unitFrame)
	if testIndex and testIndex > 1 then return end
	if ( not self.disconnected and not self.lockValues) or testIndex == 1 then
		local visualUnit = testIndex == 1 and "player" or self.unit
		local currValue = UnitHealth(visualUnit);
		local animatedLossBar = self.AnimatedLossBar;
		local guid = UnitGUID(visualUnit)
		if guid ~= self._uflHealthGUID then
			self._uflHealthGUID = guid
			self._uflPrevHealth = nil
			if animatedLossBar then
				animatedLossBar:CancelAnimation()
				animatedLossBar:UpdateHealthMinMax()
			end
		end
		local oldValue = self._uflPrevHealth
		if ( currValue ~= oldValue and (not self.ignoreNoUnit or guid) ) then
			if animatedLossBar and oldValue ~= nil then
				animatedLossBar:UpdateHealth(currValue, oldValue);
			end
			self._uflPrevHealth = currValue
			if currValue ~= self.currValue then
				self:SetValue(currValue);
				self.currValue = currValue;
				TextStatusBar_UpdateTextString(self);
			end
			UnitFrameHealPredictionBars_Update(unitFrame or self:GetParent());
		end
		if animatedLossBar then
			animatedLossBar:UpdateLossAnimation(currValue);
		end
	end
end

local function UnitFrameLayers_ManaBar_OnUpdate(self, unitFrame)
	if not IsEnabled() then
		return;
	end
	-- Test bars are populated by the arena preview; their arena unit tokens do
	-- not exist outside an arena and would otherwise reset the sample power.
	if ArenaTestIndex(unitFrame or self:GetParent()) then return end
	if ( not self.disconnected and not self.lockValues ) then
		local predictedCost = (unitFrame or self:GetParent()).predictedPowerCost;
		local actualValue = UnitPower(self.unit, self.powerType);
		local currValue = actualValue;
		if (predictedCost) then
			currValue = currValue - Round(predictedCost);
		end
		local oldValue = self._uflPrev;
		if ( oldValue ~= nil and oldValue ~= actualValue and (not self.ignoreNoUnit or UnitGUID(self.unit)) ) then
			if ( self.FeedbackFrame ) then
				local maxValue = self.FeedbackFrame.maxValue or 0;
				if ( maxValue > 0 and math.abs(actualValue - oldValue) / maxValue > 0.1 ) then
					self.FeedbackFrame:StartFeedbackAnim(oldValue, actualValue);
				end
			end
			if ( self.FullPowerFrame and self.FullPowerFrame.active ) then
				self.FullPowerFrame:StartAnimIfFull(oldValue, actualValue);
			end
		end
		self._uflPrev = actualValue;
		if ( currValue ~= self.currValue or self.forceUpdate ) then
			self.forceUpdate = nil;
			if ( not self.ignoreNoUnit or UnitGUID(self.unit) ) then
				self:SetValue(currValue);
				self.currValue = currValue;
				TextStatusBar_UpdateTextString(self);
			end
		end
	end
end

local UnitFrameManaBar_Update
local UnitFrameManaBar_UpdateType

UnitFrameManaBar_Update = function(statusbar, unit)
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
				UFL:SetBarColor(statusbar:GetParent(), statusbar, 0.5, 0.5, 0.5);
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

UnitFrameManaBar_UpdateType = function(manaBar)
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
			if ( info.atlas and SarychUI.Compat.Widgets.SetStatusBarAtlas(manaBar, info.atlas) ) then
				UFL:SetBarColor(unitFrame, manaBar, 1, 1, 1);
				manaBar:GetStatusBarTexture():SetDesaturated(playerDeadOrGhost);
				manaBar:GetStatusBarTexture():SetAlpha(playerDeadOrGhost and 0.5 or 1);
			else
				manaBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
				if ( playerDeadOrGhost ) then
					UFL:SetBarColor(unitFrame, manaBar, 0.6, 0.6, 0.6, 0.5);
				else
					UFL:SetBarColor(unitFrame, manaBar, info.r, info.g, info.b);
				end
			end
		end
		if ( manaBar.FeedbackFrame ) then
			manaBar.FeedbackFrame:Initialize(info, manaBar.unit, powerType);
		end
		if ( manaBar.FullPowerFrame ) then
			manaBar.FullPowerFrame:Initialize(info.fullPowerAnim);
		end
	else
		if ( not altR) then
			-- couldn't find a power token entry...default to indexing by power type or just mana if we don't have that either
			info = PowerBarColor[powerType] or PowerBarColor["MANA"];
		else
			if ( not manaBar.lockColor ) then
					UFL:SetBarColor(unitFrame, manaBar, altR, altG, altB);
			end
		end
	end
	if ( manaBar.powerType ~= powerType or manaBar.powerToken ~= powerToken ) then
		manaBar.powerType = powerType;
		manaBar.powerToken = powerToken;
		if ( manaBar.FullPowerFrame ) then
			manaBar.FullPowerFrame:RemoveAnims();
		end
		if manaBar.FeedbackFrame then
			manaBar.FeedbackFrame:StopFeedbackAnim();
		end
		manaBar.currValue = UnitPower(manaBar.unit, powerType);
		manaBar._uflPrev = manaBar.currValue;
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

-- Own event frame only. A hooksecurefunc on UnitFrame_OnEvent / UnitFrame_Update
-- runs inside PartyMemberFrame_OnEvent and taints the later Show/SetPoint/SetAttribute.
-- Party frames are protected. Parenting a prediction frame to them, or storing
-- bars on the frame, taints PartyMemberFrame_OnEvent for the rest of the session.
local function IsBlizzardPartyFrame(frame)
	local name = frame and frame.GetName and frame:GetName()
	return type(name) == "string" and (name:match("^PartyMemberFrame%d+$") or name:match("^PartyMemberFrame%d+PetFrame$")) and true or false
end

local function RefreshUnitFrameLayers(self, event, ...)
	if not IsEnabled() or not self or IsBlizzardPartyFrame(self) then
		return
	end
	if self.unit and self.unit:match("^arena%d+$") then
		-- Blizzard's arena buttons are protected. Build the visual children only
		-- outside combat and drive them from UFL's own event/update frame.
		if not self.myHealPredictionBar and not (InCombatLockdown and InCombatLockdown()) then
			UnitFrameLayers_AttachHealPrediction(self, false, true)
		end
		if self.myHealPredictionBar then
			UnitFrameLayers_UpdatePredictionLevel(self)
			UnitFrameHealPredictionBars_Update(self)
		end
		UpdateHealthBarColor(self)
		return
	end

	if not self.myHealPredictionBar and self.GetName and self:GetName() and self.healthbar then
		UnitFrameLayers_AttachHealPrediction(self, self.uflSkipColor == true)
	end
	if self.myHealPredictionBar then
		UnitFrameLayers_UpdatePredictionLevel(self)
	end
	if self.unit == "player" and self.manabar and not self.manabar.FeedbackFrame then
		local manaBar = self.manabar
		manaBar.FeedbackFrame = CreateFrame("Frame", nil, manaBar, "BuilderSpenderFrame")
		manaBar.FeedbackFrame:SetAllPoints(manaBar)
		manaBar.FullPowerFrame = CreateFrame("Frame", nil, manaBar, "FullPowerFrameTemplate")
		UnitFrameLayers_UpdatePlayerPowerFXLevel(manaBar)
		UnitFrameManaBar_Update(manaBar, self.unit)
	end

	if self.healthbar and self.healthbar.AnimatedLossBar then
		self.healthbar.AnimatedLossBar:UpdateHealthMinMax()
	end
	UnitFrameHealPredictionBars_UpdateMax(self)
	UnitFrameHealPredictionBars_Update(self)
	if self.unit == "player" then
		UnitFrameManaCostPredictionBars_Update(self)
	end
	UpdateHealthBarColor(self)

	if self.unit == "player" and (event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_SUCCEEDED") then
		local unit = ...
		if unit and UnitIsUnit(unit, "player") then
			local name, _, _, _, startTime, endTime = UnitCastingInfo(unit)
			UnitFrameManaCostPredictionBars_Update(self, event == "UNIT_SPELLCAST_START", startTime, endTime, name)
		end
	end
end


-- Export only the callbacks needed by the event driver.
local UFL = SarychUI.UnitFrameLayers
UFL.RefreshFrame = RefreshUnitFrameLayers
UFL.UpdateHealthBar = UnitFrameLayers_HealthBar_OnUpdate
UFL.UpdateManaBar = UnitFrameLayers_ManaBar_OnUpdate
UFL.UpdatePredictionLevel = UnitFrameLayers_UpdatePredictionLevel
UFL.UpdatePredictionBars = UnitFrameHealPredictionBars_Update
UFL.UpdatePowerFXLevel = UnitFrameLayers_UpdatePlayerPowerFXLevel

UFL.ArenaTestIndex = ArenaTestIndex
