local UFL = SarychUI.UnitFrameLayers
--Widget Handlers
local OPTION_TABLE_NONE = {};
BOSS_DEBUFF_SIZE_INCREASE = 18;
CUF_READY_CHECK_DECAY_TIME = 11;
DISTANCE_THRESHOLD_SQUARED = 250*250;
CUF_NAME_SECTION_SIZE = 15;
CUF_AURA_BOTTOM_OFFSET = 2;

function CompactUnitFrame_OnLoad(self)
    -- Names are required for concatenation of compact unit frame names. Search for
    -- Name.."HealthBar" for examples. This is ignored by nameplates.
    if not self.ignoreCUFNameRequirement and not self:GetName() then
        self:Hide();
        error("CompactUnitFrames must have a name");
    end
    self:RegisterEvent("PLAYER_ENTERING_WORLD");
    self:RegisterEvent("UNIT_DISPLAYPOWER");
    self:RegisterEvent("UNIT_POWER_BAR_SHOW");
    self:RegisterEvent("UNIT_POWER_BAR_HIDE");
    self:RegisterEvent("UNIT_NAME_UPDATE");
    self:RegisterEvent("PLAYER_TARGET_CHANGED");
    self:RegisterEvent("RAID_TARGET_UPDATE");
    self:RegisterEvent("PLAYER_REGEN_ENABLED");
    self:RegisterEvent("PLAYER_REGEN_DISABLED");
    self:RegisterEvent("PLAYER_ROLES_ASSIGNED");
    self:RegisterEvent("UNIT_ENTERED_VEHICLE");
    self:RegisterEvent("UNIT_EXITED_VEHICLE");
    self:RegisterEvent("UNIT_PET");
    self:RegisterEvent("READY_CHECK");
    self:RegisterEvent("READY_CHECK_FINISHED");
    self:RegisterEvent("READY_CHECK_CONFIRM");
    self:RegisterEvent("PARTY_MEMBER_DISABLE");
    self:RegisterEvent("PARTY_MEMBER_ENABLE");
    self:RegisterEvent("UNIT_OTHER_PARTY_CHANGED");
    self:RegisterEvent("UNIT_FLAGS");
    self:RegisterEvent("PARTY_MEMBERS_CHANGED");

    -- also see CompactUnitFrame_UpdateUnitEvents for more events
    self.maxBuffs = 0;
    self.maxDebuffs = 0;
    self.raidTargetIcon = self.healthBar:CreateTexture(nil, "OVERLAY");
    self.raidTargetIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons");
    self.raidTargetIcon:SetSize(16, 16);
    self.raidTargetIcon:SetPoint("CENTER", self.healthBar, "CENTER", 0, 0);
    self.raidTargetIcon:Hide();
    CompactUnitFrame_SetOptionTable(self, OPTION_TABLE_NONE);
    CompactUnitFrame_RegisterCallback(self);

    if not self.disableMouse then
        CompactUnitFrame_SetUpClicks(self);
    end
end

function CompactUnitFrame_OnEvent(self, event, ...)
    if CompactRaidFrameEnabled == false then return end
    local arg1, arg2, arg3, arg4 = ...;
    if ( event == self.updateAllEvent and (not self.updateAllFilter or self.updateAllFilter(self, event, ...)) ) then
        CompactUnitFrame_UpdateAll(self);
    elseif ( event == "PLAYER_ENTERING_WORLD" ) then
        CompactUnitFrame_UpdateAll(self);
    elseif ( event == "PLAYER_TARGET_CHANGED" ) then
        CompactUnitFrame_UpdateSelectionHighlight(self);
        CompactUnitFrame_UpdateName(self);
        CompactUnitFrame_UpdateWidgetsOnlyMode(self);
        CompactUnitFrame_UpdateHealthBorder(self);
        CompactUnitFrame_UpdateWidgetSet(self);
    elseif ( event == "RAID_TARGET_UPDATE" ) then
        CompactUnitFrame_UpdateRaidTargetIcon(self);
    elseif ( event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" ) then
        CompactUnitFrame_UpdateAuras(self); --We filter differently based on whether the player is in Combat, so we need to update when that changes.
    elseif ( event == "PLAYER_ROLES_ASSIGNED" ) then
        CompactUnitFrame_UpdateRoleIcon(self);
    elseif ( event == "READY_CHECK" ) then
        CompactUnitFrame_UpdateReadyCheck(self);
    elseif ( event == "READY_CHECK_FINISHED" ) then
        CompactUnitFrame_FinishReadyCheck(self);
    elseif ( event == "PARTY_MEMBERS_CHANGED" ) then
        CompactUnitFrame_UpdateAll(self);
    elseif ( event == "PARTY_MEMBER_DISABLE" or event == "PARTY_MEMBER_ENABLE" ) then	--Alternate power info may now be available.
        CompactUnitFrame_UpdateMaxPower(self);
        CompactUnitFrame_UpdatePower(self);
        CompactUnitFrame_UpdatePowerColor(self);
        CompactUnitFrame_UpdateHealthColor(self);
        CompactUnitFrame_UpdateStatusText(self);
    else

        local unitMatches = arg1 == self.unit or arg1 == self.displayedUnit;
        if ( unitMatches ) then
            if ( event == "UNIT_MAXHEALTH" ) then
                CompactUnitFrame_UpdateMaxHealth(self);
                CompactUnitFrame_UpdateHealth(self);
                CompactUnitFrame_UpdateHealPrediction(self);
            elseif ( event == "UNIT_HEALTH" ) then
                CompactUnitFrame_UpdateHealth(self);
                CompactUnitFrame_UpdateStatusText(self);
                CompactUnitFrame_UpdateHealPrediction(self);
                CompactUnitFrame_UpdateCenterStatusIcon(self);
            elseif ( event == "UNIT_RAGE" or event == "UNIT_MANA" or event == "UNIT_RUNIC_POWER" or event == "UNIT_ENERGY" ) then
                CompactUnitFrame_UpdateMaxPower(self);
                CompactUnitFrame_UpdatePower(self);
            elseif ( event == "UNIT_MAXMANA" ) then --Might want to set the health/mana to max as well so it's easily visible? This happens unless the player is out of AOI.
                CompactUnitFrame_UpdateMaxPower(self);
                CompactUnitFrame_UpdatePower(self);
                CompactUnitFrame_UpdatePowerColor(self);
                CompactUnitFrame_UpdateHealthColor(self);
                CompactUnitFrame_UpdateStatusText(self);
            elseif ( event == "UNIT_DISPLAYPOWER" or event == "UNIT_POWER_BAR_SHOW" or event == "UNIT_POWER_BAR_HIDE" ) then
                CompactUnitFrame_UpdateMaxPower(self);
                CompactUnitFrame_UpdatePower(self);
                CompactUnitFrame_UpdatePowerColor(self);
            elseif ( event == "UNIT_NAME_UPDATE" ) then
                CompactUnitFrame_UpdateName(self);
                CompactUnitFrame_UpdateHealth(self);        --This may signify that the unit is a new pet who replaced an old pet, and needs a health update
                CompactUnitFrame_UpdateHealthColor(self);   --This may signify that we now have the unit's class (the name cache entry has been received).
            elseif ( event == "COMPACT_UNIT_FRAME_UNIT_AURA" ) then
                CompactUnitFrame_UpdateAuras(self);
            elseif ( event == "UNIT_THREAT_SITUATION_UPDATE" ) then
                CompactUnitFrame_UpdateAggroHighlight(self);
                CompactUnitFrame_UpdateHealthBorder(self);
            elseif ( event == "UNIT_THREAT_LIST_UPDATE" ) then
                if ( self.optionTable.considerSelectionInCombatAsHostile ) then
                    CompactUnitFrame_UpdateHealthColor(self);
                    CompactUnitFrame_UpdateName(self);
                end
                CompactUnitFrame_UpdateHealthBorder(self);
            elseif ( event == "UNIT_HEAL_PREDICTION" ) then
                CompactUnitFrame_UpdateHealPrediction(self);
            elseif ( event == "UNIT_PET" ) then
                CompactUnitFrame_UpdateAll(self);
            elseif ( event == "READY_CHECK_CONFIRM" ) then
                CompactUnitFrame_UpdateReadyCheck(self);
            elseif ( event == "INCOMING_RESURRECT_CHANGED" ) then
                CompactUnitFrame_UpdateCenterStatusIcon(self);
            elseif ( event == "UNIT_OTHER_PARTY_CHANGED" ) then
                CompactUnitFrame_UpdateCenterStatusIcon(self);
            elseif ( event == "UNIT_ABSORB_AMOUNT_CHANGED" ) then
                CompactUnitFrame_UpdateHealPrediction(self);
            elseif ( event == "UNIT_HEAL_ABSORB_AMOUNT_CHANGED" ) then
                CompactUnitFrame_UpdateHealPrediction(self);
            elseif ( event == "PLAYER_FLAGS_CHANGED" ) then
                CompactUnitFrame_UpdateStatusText(self);
            elseif ( event == "UNIT_FLAGS" ) then
                CompactUnitFrame_UpdateCenterStatusIcon(self);
            end
        end
        if ( unitMatches or arg1 == "player" ) then
            if ( event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" ) then
                CompactUnitFrame_UpdateAll(self);
            end
        end
    end
end

-- Distance icons and ready-check decay still use the compact frame's ticker.
-- Range brightness is updated by UnitFrameRange's single shared ticker.
function CompactUnitFrame_OnUpdate(self, elapsed)
    if CompactRaidFrameEnabled == false then return end
    CompactUnitFrame_UpdateDistance(self);
    CompactUnitFrame_CheckReadyCheckDecay(self, elapsed);
end

--Externally accessed functions
function CompactUnitFrame_SetUnit(frame, unit)
    if ( unit ~= frame.unit or frame.hideCastbar ~= frame.optionTable.hideCastbar ) then
        frame.unit = unit;
        frame.displayedUnit = unit; --May differ from unit if unit is in a vehicle.
        frame.inVehicle = false;
        frame.readyCheckStatus = nil
        frame.readyCheckDecay = nil;
        frame.isTanking = nil;
        frame.hideCastbar = frame.optionTable.hideCastbar;
        frame.healthBar.healthBackground = nil;
        frame:SetAttribute("unit", unit);

        if ( unit ) then
            CompactUnitFrame_RegisterEvents(frame);
        else
            CompactUnitFrame_UnregisterEvents(frame);
        end

        if ( unit and not frame.optionTable.hideCastbar ) then
            if ( frame.castBar ) then
                CastingBarFrame_SetUnit(frame.castBar, unit, false, true);
            end
        else
            if ( frame.castBar ) then
                CastingBarFrame_SetUnit(frame.castBar, nil, nil, nil);
            end
        end
        CompactUnitFrame_UpdateAll(frame);
    end
end
--PLEEEEEASE FIX ME. This makes me very very sad. (Unfortunately, there isn't a great way to deal with the lack of "raid1targettarget" events though)
function CompactUnitFrame_SetUpdateAllOnUpdate(self, doUpdate)
    if ( doUpdate ) then
        if ( not self.onUpdateFrame ) then
            self.onUpdateFrame = CreateFrame("Frame")   --Need to use this so UpdateAll is called even when the frame is hidden.
            self.onUpdateFrame.func = function(updateFrame, elapsed) if ( self.displayedUnit ) then CompactUnitFrame_UpdateAll(self) end end;
        end
        self.onUpdateFrame:SetScript("OnUpdate", self.onUpdateFrame.func);
    else
        if ( self.onUpdateFrame ) then
            self.onUpdateFrame:SetScript("OnUpdate", nil);
        end
    end
end
--Things you'll have to set up to get everything looking right:
--1. Frame size
--2. Health/Mana bar positions
--3. Health/Mana bar textures (also, optionally, background textures)
--4. Name position
--5. Buff/Debuff/Dispellable positions
--6. Call CompactUnitFrame_SetMaxBuffs and _SetMaxDebuffs. (If increasing either, create and position more aura frames.)
--7. Selection highlight position and texture.
--8. Aggro highlight position and texture
--9. Role icon position
function CompactUnitFrame_SetUpFrame(frame, func)
    func(frame);
    CompactUnitFrame_UpdateAll(frame);
end

function CompactUnitFrame_SetOptionTable(frame, optionTable)
    frame.optionTable = optionTable;
    --CompactUnitFrame_UpdateAll(frame);
end

function CompactUnitFrame_RegisterEvents(frame)
    local onEventHandler = frame.OnEvent or CompactUnitFrame_OnEvent;
    frame:SetScript("OnEvent", onEventHandler);

    CompactUnitFrame_UpdateUnitEvents(frame);

    local onUpdate = frame.OnUpdate or CompactUnitFrame_OnUpdate;
    frame:SetScript("OnUpdate", onUpdate);
end

function CompactUnitFrame_UpdateUnitEvents(frame)
    frame:RegisterEvent("UNIT_MAXMANA");
    frame:RegisterEvent("UNIT_MAXHEALTH");
    frame:RegisterEvent("UNIT_HEALTH");
    frame:RegisterEvent("UNIT_RAGE");
    frame:RegisterEvent("UNIT_MANA");
    frame:RegisterEvent("UNIT_ENERGY");
    frame:RegisterEvent("UNIT_RUNIC_POWER");
    frame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE");
    frame:RegisterEvent("UNIT_THREAT_LIST_UPDATE");
    frame:RegisterEvent("UNIT_HEAL_PREDICTION");
    frame:RegisterEvent("PLAYER_FLAGS_CHANGED");
end

function CompactUnitFrame_UnregisterEvents(frame)
    frame:SetScript("OnEvent", nil);
    frame:SetScript("OnUpdate", nil);
end

function CompactUnitFrame_SetUpClicks(frame)
    frame:SetAttribute("*type1", "target");
    frame:SetAttribute("*type2", "menu");
    --NOTE: Make sure you also change the CompactAuraTemplate. (It has to be registered for clicks to be able to pass them through.)
    frame:RegisterForClicks("LeftButtonDown", "RightButtonUp");
    CompactUnitFrame_SetMenuFunc(frame, CompactUnitFrameDropDown_Initialize);
end

local AttachSecureFocusMenuButton

function CompactUnitFrame_SetMenuFunc(frame, menuFunc)
    UIDropDownMenu_Initialize(frame.dropDown, menuFunc, "MENU");
    frame.menu = function()
        ToggleDropDownMenu(1, nil, frame.dropDown, frame:GetName(), 0, 0);
        if AttachSecureFocusMenuButton then
            AttachSecureFocusMenuButton(frame.unit);
        end
    end
end

function CompactUnitFrame_SetMaxBuffs(frame, numBuffs)
    frame.maxBuffs = numBuffs;
end

function CompactUnitFrame_SetMaxDebuffs(frame, numDebuffs)
    frame.maxDebuffs = numDebuffs;
end


function CompactUnitFrame_SetUpdateAllEvent(frame, updateAllEvent, updateAllFilter)
    if ( frame.updateAllEvent ) then
        frame:UnregisterEvent(frame.updateAllEvent);
    end
    frame.updateAllEvent = updateAllEvent;
    frame.updateAllFilter = updateAllFilter;
    frame:RegisterEvent(updateAllEvent);
end
--Internally accessed functions
--Update Functions
function CompactUnitFrame_UpdateAll(frame)
    -- CompactUnitFrame_UpdateInVehicle(frame);
    CompactUnitFrame_UpdateVisible(frame);
    CompactUnitFrame_UpdateRaidTargetIcon(frame);
    if ( UnitExists(frame.displayedUnit) ) then
        CompactUnitFrame_UpdateMaxHealth(frame);
        CompactUnitFrame_UpdateHealth(frame);
        CompactUnitFrame_UpdateHealthColor(frame);
        CompactUnitFrame_UpdateMaxPower(frame);
        CompactUnitFrame_UpdatePower(frame);
        CompactUnitFrame_UpdatePowerColor(frame);
        CompactUnitFrame_UpdateName(frame);
        CompactUnitFrame_UpdateWidgetsOnlyMode(frame);
        CompactUnitFrame_UpdateSelectionHighlight(frame);
        CompactUnitFrame_UpdateAggroHighlight(frame);
        CompactUnitFrame_UpdateHealthBorder(frame);
        CompactUnitFrame_UpdateInRange(frame);
        CompactUnitFrame_UpdateStatusText(frame);
        CompactUnitFrame_UpdateHealPrediction(frame);
        CompactUnitFrame_UpdateRoleIcon(frame);
        CompactUnitFrame_UpdateReadyCheck(frame);
        CompactUnitFrame_UpdateAuras(frame);
        CompactUnitFrame_UpdateCenterStatusIcon(frame);
        CompactUnitFrame_UpdateWidgetSet(frame);
    end
end

function CompactUnitFrame_UpdateRaidTargetIcon(frame)
    local icon = frame.raidTargetIcon;
    if not icon then return end
    local index;
    if frame._suiTestData and frame._suiTestIndex and frame._suiTestIndex > 1 then
        if frame._suiTestIndex == 2 then index = 1;
        elseif frame._suiTestIndex % 5 == 0 then index = 8; end
    elseif frame.unit and UnitExists(frame.displayedUnit or frame.unit) then
        index = GetRaidTargetIndex(frame.displayedUnit or frame.unit);
    end
    if index and index >= 1 and index <= 8 then
        SetRaidTargetIconTexture(icon, index);
        icon:Show();
    else
        icon:Hide();
    end
end

--! SOMEBODY FIX ME!!! SOMEBODY FIX ME!!! SOMEBODY FIX ME!!! SOMEBODY FIX ME!!!
function CompactUnitFrame_UpdateInVehicle(frame)
    local shouldTargetVehicle = UnitHasVehicleUI(frame.unit);
    local unitVehicleToken;

    --! UnitTargetsVehicleInRaidUI returns false in any states. I don't understand why
    -- if ( shouldTargetVehicle ) then
    --     local raidID = UnitInRaid(frame.unit);
    --     if ( raidID and not UnitTargetsVehicleInRaidUI(frame.unit) ) then
    --         shouldTargetVehicle = false;
    --     end
    -- end

    if ( shouldTargetVehicle ) then
        local prefix, id, suffix = string.match(frame.unit, "([^%d]+)([%d]*)(.*)");
        unitVehicleToken = prefix.."pet"..id..suffix;

        if ( frame.unit == "player" ) then
            unitVehicleToken = "vehicle";
        end
        if ( not UnitExists(unitVehicleToken) ) then
            shouldTargetVehicle = false;
        end
    end

    if ( shouldTargetVehicle ) then
        if ( not frame.hasValidVehicleDisplay ) then
            frame.hasValidVehicleDisplay = true;
            frame.displayedUnit = unitVehicleToken;
            frame:SetAttribute("unit", frame.displayedUnit);
            CompactUnitFrame_RegisterEvents(frame);
        end
    else
        if ( frame.hasValidVehicleDisplay ) then
            frame.hasValidVehicleDisplay = false;
            frame.displayedUnit = frame.unit;
            frame:SetAttribute("unit", frame.displayedUnit);
            CompactUnitFrame_UpdateUnitEvents(frame);
        end
    end
end

function CompactUnitFrame_UpdateVisible(frame)
    if ( UnitExists(frame.unit) or UnitExists(frame.displayedUnit) ) then
        if ( not frame.unitExists ) then
            frame.newUnit = true;
        end
        frame.unitExists = true;
        -- RegisterUnitWatch and the visibility state driver already show the
        -- secure button. A Lua Show() here is blocked once combat starts.
        if not InCombatLockdown() then
            frame:Show();
        end
    else
        CompactUnitFrame_ClearWidgetSet(frame);
        frame.unitExists = false;
        if not InCombatLockdown() then
            frame:Hide();
        end
    end
end

function CompactUnitFrame_IsTapDenied(frame)
    return frame.optionTable.greyOutWhenTapDenied and not UnitPlayerControlled(frame.unit) and UnitIsTapped(frame.unit);
end

local function IsOnThreatList(threatStatus)
    return threatStatus ~= nil;
end

function CompactUnitFrame_IsOnThreatListWithPlayer(unit)
    local _, threatStatus = UnitDetailedThreatSituation("player", unit);
    return IsOnThreatList(threatStatus);
end

function CompactUnitFrame_UpdateHealthColor(frame)
    local r, g, b;
    if ( not UnitIsConnected(frame.unit) ) then
        --Color it gray
        r, g, b = 0.5, 0.5, 0.5;
    else
        if ( frame.optionTable.healthBarColorOverride ) then
            local healthBarColorOverride = frame.optionTable.healthBarColorOverride;
            r, g, b = healthBarColorOverride.r, healthBarColorOverride.g, healthBarColorOverride.b;
        else 
            --Try to color it by class.
            local localizedClass, englishClass = UnitClass(frame.unit);
            local classColor = RAID_CLASS_COLORS[englishClass];
            --debug
            --classColor = RAID_CLASS_COLORS["PRIEST"];
            if ( (frame.optionTable.allowClassColorsForNPCs or UnitIsPlayer(frame.unit)) and classColor and frame.optionTable.useClassColors ) then
                -- Use class colors for players if class color option is turned on
                r, g, b = classColor.r, classColor.g, classColor.b;
            elseif ( CompactUnitFrame_IsTapDenied(frame) ) then
                -- Use grey if not a player and can't get tap on unit
                r, g, b = 0.9, 0.9, 0.9;
            elseif ( frame.optionTable.colorHealthBySelection ) then
                -- Use color based on the type of unit (neutral, etc.)
                if ( frame.optionTable.considerSelectionInCombatAsHostile and CompactUnitFrame_IsOnThreatListWithPlayer(frame.displayedUnit) ) then
                    r, g, b = 1.0, 0.0, 0.0;
                elseif ( UnitIsPlayer(frame.displayedUnit) and UnitIsFriend("player", frame.displayedUnit) ) then
                    -- We don't want to use the selection color for friendly player nameplates because
                    -- it doesn't show player health clearly enough.
                    r, g, b = 0.667, 0.667, 1.0;
                else
                    r, g, b = UnitSelectionColor(frame.unit, frame.optionTable.colorHealthWithExtendedColors);
                end
            elseif ( UnitIsFriend("player", frame.unit) ) then
                r, g, b = 0.0, 1.0, 0.0;
            else
                r, g, b = 1.0, 0.0, 0.0;
            end
        end
    end
    SarychUI.UnitFrameLayers:SetBarColor(frame, frame.healthBar, r, g, b);
    if (frame.optionTable.colorHealthWithExtendedColors) then
        frame.ignoreParentAlpha.selectionHighlight:SetVertexColor(r, g, b);
    else
        frame.ignoreParentAlpha.selectionHighlight:SetVertexColor(1, 1, 1);
    end
    frame.healthBar.r, frame.healthBar.g, frame.healthBar.b = r, g, b;
end

function CompactUnitFrame_UpdateMaxHealth(frame)
    local groups = SarychUI.modules and SarychUI.modules.group_frames;
    if groups and groups.UpdateFullHealthMuted then groups:UpdateFullHealthMuted(frame); end
    local maxHealth = UnitIsConnected(frame.unit) and UnitHealthMax(frame.displayedUnit) or 1;
    if ( frame.optionTable.smoothHealthUpdates ) then
        frame.healthBar:SetMinMaxSmoothedValue(0, maxHealth);
    else
        frame.healthBar:SetMinMaxValues(0, maxHealth);
    end
    CompactUnitFrame_UpdateHealPrediction(frame);
end

function CompactUnitFrame_UpdateHealth(frame)
    local groups = SarychUI.modules and SarychUI.modules.group_frames;
    if groups and groups.UpdateFullHealthMuted then groups:UpdateFullHealthMuted(frame); end
    local health = UnitIsConnected(frame.unit) and UnitHealth(frame.displayedUnit) or 1;
    if ( frame.optionTable.smoothHealthUpdates ) then
        if ( frame.newUnit ) then
            frame.healthBar:ResetSmoothedValue(health);
            frame.newUnit = false;
        else
            frame.healthBar:SetSmoothedValue(health);
        end
    else
        SarychUI.Compat.PixelUtil.SetStatusBarValue(frame.healthBar, health);
    end
end

local function CompactUnitFrame_GetDisplayedPowerID(frame)
    return (UnitPowerType(frame.displayedUnit));
end

function CompactUnitFrame_UpdateMaxPower(frame)
    if frame.powerBar then
        frame.powerBar:SetMinMaxValues(0, UnitPowerMax(frame.displayedUnit, CompactUnitFrame_GetDisplayedPowerID(frame)));
    end
end

function CompactUnitFrame_UpdatePower(frame)
    if frame.powerBar then
        SarychUI.Compat.PixelUtil.SetStatusBarValue(frame.powerBar, UnitPower(frame.displayedUnit, CompactUnitFrame_GetDisplayedPowerID(frame)));
    end
end

function CompactUnitFrame_UpdatePowerColor(frame)
    if not frame.powerBar then
        return;
    end
    local r, g, b;
    if ( not UnitIsConnected(frame.unit) ) then
        --Color it gray
        r, g, b = 0.5, 0.5, 0.5;
    else
        --Set it to the proper power type color.
        local barInfo = nil --GetUnitPowerBarInfo(frame.unit);
        if ( barInfo and barInfo.showOnRaid ) then
            r, g, b = 0.7, 0.7, 0.6;
        else
            local powerType, powerToken, altR, altG, altB = UnitPowerType(frame.displayedUnit);
        if not powerToken then
            powerToken = ({
                [0] = "MANA",
                [1] = "RAGE",
                [2] = "FOCUS",
                [3] = "ENERGY",
                [4] = "HAPPINESS",
                [5] = "RUNES",
                [6] = "RUNIC_POWER",
            })[powerType];
        end
        local info = (powerToken and PowerBarColor[powerToken]) or PowerBarColor[powerType] or PowerBarColor["MANA"];
        if ( info ) then
            r, g, b = info.r, info.g, info.b;
        elseif ( altR ) then
            r, g, b = altR, altG, altB;
        else
            r, g, b = 0, 0, 1;
        end
        end
    end
    SarychUI.UnitFrameLayers:SetBarColor(frame, frame.powerBar, r, g, b);

end

function ShouldShowName(frame)
    if SarychUI.Compat.UnitNameplateShowsWidgetsOnly(frame.unit) then
        return false;
    end
    if ( frame.optionTable.displayName ) then
        local failedRequirement = false;
        if ( frame.optionTable.displayNameByPlayerNameRules ) then
            if ( SarychUI.Compat.UnitShouldDisplayName(frame.unit) ) then
                return true;
            end
            failedRequirement = true;
        end
        if ( frame.optionTable.displayNameWhenSelected ) then
            if ( UnitIsUnit(frame.unit, "target") ) then
                return true;
            end
            failedRequirement = true;
        end
        return not failedRequirement;
    end
    return false;
end

function CompactUnitFrame_UpdateWidgetsOnlyMode(frame)
    local inWidgetsOnlyMode = nil --UnitNameplateShowsWidgetsOnly(frame.unit);
    SarychUI.Compat.Widgets.SetShown(frame.healthBar, not inWidgetsOnlyMode and not frame.hideHealthbar);
    if frame.castBar and not frame.optionTable.hideCastbar then
        if inWidgetsOnlyMode then
            CastingBarFrame_SetUnit(frame.castBar, nil, nil, nil);
            frame.hideCastbar = true;
        else
            CastingBarFrame_SetUnit(frame.castBar, frame.unit, false, true);
        end
    end
    if frame.BuffFrame then
        SarychUI.Compat.Widgets.SetShown(frame.BuffFrame, not inWidgetsOnlyMode);
    end
    if frame.ClassificationFrame then
        SarychUI.Compat.Widgets.SetShown(frame.ClassificationFrame, not inWidgetsOnlyMode);
    end
    if frame.RaidTargetFrame then
        SarychUI.Compat.Widgets.SetShown(frame.RaidTargetFrame, not inWidgetsOnlyMode);
    end
    if frame.WidgetContainer then
        frame.WidgetContainer:ClearAllPoints();
        if inWidgetsOnlyMode then
            SarychUI.Compat.PixelUtil.SetPoint(frame.WidgetContainer, "BOTTOM", frame, "BOTTOM", 0, 0);
        else
            SarychUI.Compat.PixelUtil.SetPoint(frame.WidgetContainer, "TOP", frame.castBar, "BOTTOM", 0, 0);
        end
    end
end

function CompactUnitFrame_UpdateName(frame)
    if frame.UpdateNameOverride and frame:UpdateNameOverride() then
        return;
    end
    if ( not ShouldShowName(frame) ) then
        frame.overlay.name:Hide();
    else
        local name = GetUnitName(frame.unit, true);
        frame.overlay.name:SetText(name);
        if ( CompactUnitFrame_IsTapDenied(frame) ) then
            -- Use grey if not a player and can't get tap on unit
            SarychUI.UnitFrameLayers:SetTextColor(frame, frame.overlay.name, 0.5, 0.5, 0.5, nil, true);
        elseif ( frame.optionTable.colorNameBySelection ) then
            if ( frame.optionTable.considerSelectionInCombatAsHostile and CompactUnitFrame_IsOnThreatListWithPlayer(frame.displayedUnit) ) then
                SarychUI.UnitFrameLayers:SetTextColor(frame, frame.overlay.name, 1.0, 0.0, 0.0, nil, true);
            else
                local nameR, nameG, nameB = UnitSelectionColor(frame.unit,
                    frame.optionTable.colorNameWithExtendedColors);
                SarychUI.UnitFrameLayers:SetTextColor(frame, frame.overlay.name,
                    nameR, nameG, nameB, nil, true);
            end
        end
        frame.overlay.name:Show();
    end
end

function CompactUnitFrame_UpdateSelectionHighlight(frame)
    if ( not frame.optionTable.displaySelectionHighlight ) then
        frame.ignoreParentAlpha.selectionHighlight:Hide();
        return;
    end
    if ( UnitIsUnit(frame.displayedUnit, "target") ) then
        frame.ignoreParentAlpha.selectionHighlight:Show();
    else
        frame.ignoreParentAlpha.selectionHighlight:Hide();
    end
end

function CompactUnitFrame_UpdateAggroHighlight(frame)
    if ( not frame.optionTable.displayAggroHighlight ) then
        if ( not frame.optionTable.playLoseAggroHighlight ) then
            frame.overlay.aggroHighlight:Hide();
        end
        return;
    end
    local status = UnitThreatSituation(frame.displayedUnit);
    if ( status and status > 0 ) then
        frame.overlay.aggroHighlight:SetVertexColor(GetThreatStatusColor(status));
        frame.overlay.aggroHighlight:Show();
    else
        frame.overlay.aggroHighlight:Hide();
    end
end

local function IsPlayerEffectivelyTank()
    local assignedRole = SarychUI.Compat.UnitGroupRoles("player") ;
    if ( assignedRole == "NONE" ) then
        local spec = GetActiveTalentGroup();
        return spec and SarychUI.Compat.GetSpecializationRole(spec) == "TANK";
    end
    return assignedRole == "TANK";
end

local function SetBorderColor(frame, r, g, b, a)
    frame.healthBar.border:SetVertexColor(r, g, b, a);
    if frame.castBar and frame.castBar.border then
        frame.castBar.border:SetVertexColor(r, g, b, a);
    end
end

function CompactUnitFrame_UpdateHealthBorder(frame)
    if frame.UpdateHealthBorderOverride and frame:UpdateHealthBorderOverride() then
        return;
    end
    if frame.optionTable.selectedBorderColor and UnitIsUnit(frame.displayedUnit, "target") then
        SetBorderColor(frame, frame.optionTable.selectedBorderColor:GetRGBA());
        return;
    end
    if frame.optionTable.tankBorderColor and SarychUI.Compat.IsInGroup() and IsPlayerEffectivelyTank() then
        local isTanking, threatStatus = UnitDetailedThreatSituation("player", frame.displayedUnit);
        local showTankingColor = (not isTanking) and IsOnThreatList(threatStatus) and SarychUI.Compat.IsInGroup();
        if showTankingColor then
            SetBorderColor(frame, frame.optionTable.tankBorderColor:GetRGBA());
            return;
        end
    end
    if frame.optionTable.defaultBorderColor then
        SetBorderColor(frame, frame.optionTable.defaultBorderColor:GetRGBA());
        return;
    end
end

function CompactUnitFrame_UpdateInRange(frame)
    if SarychUI.UnitFrameRange then SarychUI.UnitFrameRange:Update(frame) end
end

function CompactUnitFrame_UpdateDistance(frame)
    local distance, checkedDistance = SarychUI.Compat.GetMapDistanceEstimate(frame.displayedUnit, true);
    if ( checkedDistance ) then
        local inDistance = distance < DISTANCE_THRESHOLD_SQUARED;
        if ( inDistance ~= frame.inDistance ) then
            frame.inDistance = inDistance;
            CompactUnitFrame_UpdateCenterStatusIcon(frame);
        end
    end
end

function CompactUnitFrame_UpdateStatusText(frame)
    if ( not frame.statusText ) then
        return;
    end
    if ( not frame.optionTable.displayStatusText ) then
        frame.statusText:Hide();
        return;
    end
    if ( not UnitIsConnected(frame.unit) ) then
        frame.statusText:SetText(PLAYER_OFFLINE)
        frame.statusText:Show();
    elseif ( UnitIsDeadOrGhost(frame.displayedUnit) ) then
        frame.statusText:SetText(DEAD);
        frame.statusText:Show();
    elseif ( frame.optionTable.healthText == "health" ) then
        frame.statusText:SetText(UnitHealth(frame.displayedUnit));
        frame.statusText:Show();
    elseif ( frame.optionTable.healthText == "losthealth" ) then
        local healthLost = UnitHealthMax(frame.displayedUnit) - UnitHealth(frame.displayedUnit);
        if ( healthLost > 0 ) then
            frame.statusText:SetFormattedText(LOST_HEALTH, healthLost);
            frame.statusText:Show();
        else
            frame.statusText:Hide();
        end
    elseif ( (frame.optionTable.healthText == "perc") and (UnitHealthMax(frame.displayedUnit) > 0) ) then
        local perc = math.ceil(100 * (UnitHealth(frame.displayedUnit)/UnitHealthMax(frame.displayedUnit)));
        frame.statusText:SetFormattedText("%d%%", perc);
        frame.statusText:Show();
    else
        frame.statusText:Hide();
    end
end

local fakeIndex = 1;
local fakeSetup = {
    {
        myHeal = 1000,
        allHeal = 1500,
        absorb = 1200,
        healAbsorb = 0,
        healthMult = .5;
    },
    {
        myHeal = 2500,
        allHeal = 5000,
        absorb = 2000,
        healAbsorb = 12000,
        healthMult = .5;
    }
};
--WARNING: This function is very similar to the function UnitFrameHealPredictionBars_Update in UnitFrame.lua.
--If you are making changes here, it is possible you may want to make changes there as well.
local MAX_INCOMING_HEAL_OVERFLOW = 1.05;
function CompactUnitFrame_UpdateHealPrediction(frame)
    --if not frame.fakeIndex then
    --  frame.fakeIndex = fakeIndex;
    --  fakeIndex = fakeIndex + 1;
    --  if fakeIndex > #fakeSetup then
    --      fakeIndex = 1;
    --  end
    --end
    --local fake = fakeSetup[frame.fakeIndex];
    local _, maxHealth = frame.healthBar:GetMinMaxValues();
    local health = frame.healthBar:GetValue();
    --health = maxHealth * fake.healthMult;
    --PixelUtil.SetStatusBarValue(frame.healthBar, health);
    if ( maxHealth <= 0 ) then
        return;
    end
    if ( not frame.optionTable.displayHealPrediction or
        (frame._suiTestData and not SarychUI.UnitFrameLayers:IsEnabled()) ) then
        frame.overlay.myHealPrediction:Hide();
        frame.overlay.otherHealPrediction:Hide();
        frame.overlay.totalAbsorb:Hide();
        frame.overlay.totalAbsorbOverlay:Hide();
        frame.overlay.overAbsorbGlow:Hide();
        frame.overlay.myHealAbsorb:Hide();
        frame.overlay.myHealAbsorbLeftShadow:Hide();
        frame.overlay.myHealAbsorbRightShadow:Hide();
        frame.overlay.overHealAbsorbGlow:Hide();
        return;
    end

    local test = frame._suiTestData;
    local myIncomingHeal = test and maxHealth * test.myHeal or UFL:GetIncomingHeals(frame.displayedUnit, "player") or 0;
    --myIncomingHeal = fake.myHeal;
    local allIncomingHeal = test and maxHealth * test.allHeal or UFL:GetIncomingHeals(frame.displayedUnit) or 0;
    local totalAbsorb = test and maxHealth * test.absorb or UFL:GetAbsorbs(frame.displayedUnit) or 0;
    --We don't fill outside the health bar with healAbsorbs.  Instead, an overHealAbsorbGlow is shown.
    local myCurrentHealAbsorb = test and maxHealth * test.healAbsorb or 0;
    if ( health < myCurrentHealAbsorb ) then
        frame.overHealAbsorbGlow:Show();
        myCurrentHealAbsorb = health;
    else
        frame.overHealAbsorbGlow:Hide();
    end
    local customOptions = frame.customOptions;
    local maxHealOverflowRatio = customOptions and customOptions.maxHealOverflowRatio or MAX_INCOMING_HEAL_OVERFLOW;
    --See how far we're going over the health bar and make sure we don't go too far out of the frame.
    if ( health - myCurrentHealAbsorb + allIncomingHeal > maxHealth * maxHealOverflowRatio ) then
        allIncomingHeal = maxHealth * maxHealOverflowRatio - health + myCurrentHealAbsorb;
    end
    local otherIncomingHeal = 0;
    --Split up incoming heals.
    if ( allIncomingHeal >= myIncomingHeal ) then
        otherIncomingHeal = allIncomingHeal - myIncomingHeal;
    else
        myIncomingHeal = allIncomingHeal;
    end
    local overAbsorb = false;
    --We don't fill outside the the health bar with absorbs.  Instead, an overAbsorbGlow is shown.
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
    local healthTexture = frame.healthBar:GetStatusBarTexture();
    local myCurrentHealAbsorbPercent = myCurrentHealAbsorb / maxHealth;
    local healAbsorbTexture = nil;
    --If allIncomingHeal is greater than myCurrentHealAbsorb, then the current
    --heal absorb will be completely overlayed by the incoming heals so we don't show it.
    if ( myCurrentHealAbsorb > allIncomingHeal ) then
        local shownHealAbsorb = myCurrentHealAbsorb - allIncomingHeal;
        local shownHealAbsorbPercent = shownHealAbsorb / maxHealth;
        healAbsorbTexture = CompactUnitFrameUtil_UpdateFillBar(frame, healthTexture, frame.myHealAbsorb, shownHealAbsorb, -shownHealAbsorbPercent);
        --If there are incoming heals the left shadow would be overlayed by the incoming heals
        --so it isn't shown.
        if ( allIncomingHeal > 0 ) then
            frame.myHealAbsorbLeftShadow:Hide();
        else
            frame.myHealAbsorbLeftShadow:SetPoint("TOPLEFT", healAbsorbTexture, "TOPLEFT", 0, 0);
            frame.myHealAbsorbLeftShadow:SetPoint("BOTTOMLEFT", healAbsorbTexture, "BOTTOMLEFT", 0, 0);
            frame.myHealAbsorbLeftShadow:Show();
        end
        -- The right shadow is only shown if there are absorbs on the health bar.
        if ( totalAbsorb > 0 ) then
            frame.myHealAbsorbRightShadow:SetPoint("TOPLEFT", healAbsorbTexture, "TOPRIGHT", -8, 0);
            frame.myHealAbsorbRightShadow:SetPoint("BOTTOMLEFT", healAbsorbTexture, "BOTTOMRIGHT", -8, 0);
            frame.myHealAbsorbRightShadow:Show();
        else
            frame.myHealAbsorbRightShadow:Hide();
        end
    else
        frame.myHealAbsorb:Hide();
        frame.myHealAbsorbRightShadow:Hide();
        frame.myHealAbsorbLeftShadow:Hide();
    end
    --Show myIncomingHeal on the health bar.
    local incomingHealsTexture = CompactUnitFrameUtil_UpdateFillBar(frame, healthTexture, frame.myHealPrediction, myIncomingHeal, -myCurrentHealAbsorbPercent);
    --Append otherIncomingHeal on the health bar.
    incomingHealsTexture = CompactUnitFrameUtil_UpdateFillBar(frame, incomingHealsTexture, frame.otherHealPrediction, otherIncomingHeal);
    --Appen absorbs to the correct section of the health bar.
    local appendTexture = nil;
    if ( healAbsorbTexture ) then
        --If there is a healAbsorb part shown, append the absorb to the end of that.
        appendTexture = healAbsorbTexture;
    else
        --Otherwise, append the absorb to the end of the the incomingHeals part;
        appendTexture = incomingHealsTexture;
    end
    CompactUnitFrameUtil_UpdateFillBar(frame, appendTexture, frame.totalAbsorb, totalAbsorb)
end

--WARNING: This function is very similar to the function UnitFrameUtil_UpdateFillBar in UnitFrame.lua.
--If you are making changes here, it is possible you may want to make changes there as well.
function CompactUnitFrameUtil_UpdateFillBar(frame, previousTexture, bar, amount, barOffsetXPercent)
    local totalWidth, totalHeight = frame.healthBar:GetSize();

    if ( totalWidth == 0 or amount == 0 ) then
        bar:Hide();
        if ( bar.overlay ) then
            bar.overlay:Hide();
        end
        return previousTexture;
    end

    local barOffsetX = 0;
    if ( barOffsetXPercent ) then
        barOffsetX = totalWidth * barOffsetXPercent;
    end

    bar:SetPoint("TOPLEFT", previousTexture, "TOPRIGHT", barOffsetX, 0);
    bar:SetPoint("BOTTOMLEFT", previousTexture, "BOTTOMRIGHT", barOffsetX, 0);

    local _, totalMax = frame.healthBar:GetMinMaxValues();

    local barSize = (amount / totalMax) * totalWidth;
    bar:SetWidth(barSize);
    bar:Show();

    if ( bar.overlay ) then
        bar.overlay:SetTexCoord(0, SarychUI.Compat.ApplyCoordFix(barSize / bar.overlay.tileSize), 0, SarychUI.Compat.ApplyCoordFix(totalHeight / bar.overlay.tileSize));
        bar.overlay:Show();
    end
    return bar;
end

function CompactUnitFrame_UpdateRoleIcon(frame)
    if not ( frame.roleIcon and frame.unit ) then
        return;
    end

    local size = frame.roleIcon:GetHeight(); --We keep the height so that it carries from the set up, but we decrease the width to 1 to allow room for things anchored to the role (e.g. name).
    local raidID = UnitInRaid(frame.unit) and UnitInRaid(frame.unit) + 1;
    if ( UnitInVehicle(frame.unit) and UnitHasVehicleUI(frame.unit) ) then
        frame.roleIcon:SetTexture("Interface\\Vehicles\\UI-Vehicles-Raid-Icon");
        frame.roleIcon:SetTexCoord(0, 1, 0, 1);
        frame.roleIcon:Show();
        frame.roleIcon:SetSize(size, size);
    elseif ( frame.optionTable.displayRaidRoleIcon and raidID and select(10, GetRaidRosterInfo(raidID)) ) then
        local role = select(10, GetRaidRosterInfo(raidID));
        frame.roleIcon:SetTexture("Interface\\GroupFrame\\UI-Group-"..role.."Icon");
        frame.roleIcon:SetTexCoord(0, 1, 0, 1);
        frame.roleIcon:Show();
        frame.roleIcon:SetSize(size, size);
    else
        local role = SarychUI.Compat.UnitGroupRoles(frame.unit);
        if ( frame.optionTable.displayRoleIcon and (role == "TANK" or role == "HEALER" or role == "DAMAGER") ) then
            frame.roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES");
            frame.roleIcon:SetTexCoord(SarychUI.Compat.GetTexCoordsForRoleSmallCircle(role));
            frame.roleIcon:Show();
            frame.roleIcon:SetSize(size, size);
        else
            frame.roleIcon:Hide();
            frame.roleIcon:SetSize(1, size);
        end
    end
end

function CompactUnitFrame_UpdateReadyCheck(frame)
    if ( not frame.ignoreParentAlpha.readyCheckIcon or frame.readyCheckDecay and GetReadyCheckTimeLeft() <= 0 ) then
        return;
    end
    local readyCheckStatus = GetReadyCheckStatus(frame.unit);
    frame.readyCheckStatus = readyCheckStatus;
    if ( readyCheckStatus == "ready" ) then
        frame.ignoreParentAlpha.readyCheckIcon:SetTexture(READY_CHECK_READY_TEXTURE);
        frame.ignoreParentAlpha.readyCheckIcon:Show();
    elseif ( readyCheckStatus == "notready" ) then
        frame.ignoreParentAlpha.readyCheckIcon:SetTexture(READY_CHECK_NOT_READY_TEXTURE);
        frame.ignoreParentAlpha.readyCheckIcon:Show();
    elseif ( readyCheckStatus == "waiting" ) then
        frame.ignoreParentAlpha.readyCheckIcon:SetTexture(READY_CHECK_WAITING_TEXTURE);
        frame.ignoreParentAlpha.readyCheckIcon:Show();
    else
        frame.ignoreParentAlpha.readyCheckIcon:Hide();
    end
end

function CompactUnitFrame_FinishReadyCheck(frame)
    if ( not frame.ignoreParentAlpha.readyCheckIcon)  then
        return;
    end
    if ( frame:IsVisible() ) then
        frame.readyCheckDecay = CUF_READY_CHECK_DECAY_TIME;
        if ( frame.readyCheckStatus == "waiting" ) then --If you haven't responded, you are not ready.
            frame.ignoreParentAlpha.readyCheckIcon:SetTexture(READY_CHECK_NOT_READY_TEXTURE);
            frame.ignoreParentAlpha.readyCheckIcon:Show();
        end
    else
        CompactUnitFrame_UpdateReadyCheck(frame);
    end
end

function CompactUnitFrame_CheckReadyCheckDecay(frame, elapsed)
    if ( frame.readyCheckDecay ) then
        if ( frame.readyCheckDecay > 0 ) then
            frame.readyCheckDecay = frame.readyCheckDecay - elapsed;
        else
            frame.readyCheckDecay = nil;
            CompactUnitFrame_UpdateReadyCheck(frame);
        end
    end
end

function CompactUnitFrame_UpdateCenterStatusIcon(frame)
    if ( frame.centerStatusIcon ) then
        if ( frame.optionTable.displayInOtherGroup and SarychUI.Compat.UnitInOtherParty(frame.unit) ) then
            frame.centerStatusIcon.texture:SetTexture("Interface\\LFGFrame\\LFG-Eye");
            frame.centerStatusIcon.texture:SetTexCoord(0.125, 0.25, 0.25, 0.5);
            frame.centerStatusIcon.border:SetTexture("Interface\\Common\\RingBorder");
            frame.centerStatusIcon.border:Show();
            frame.centerStatusIcon.tooltip = PARTY_IN_PUBLIC_GROUP_MESSAGE;
            frame.centerStatusIcon:Show();
        elseif ( frame.optionTable.displayIncomingResurrect and SarychUI.Compat.UnitHasIncomingResurrection(frame.unit) ) then
            frame.centerStatusIcon.texture:SetTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Raid-Icon-Rez");
            frame.centerStatusIcon.texture:SetTexCoord(0, 1, 0, 1);
            frame.centerStatusIcon.border:Hide();
            frame.centerStatusIcon.tooltip = nil;
            frame.centerStatusIcon:Show();
        elseif ( frame.optionTable.displayIncomingSummon and SarychUI.Compat.C_IncomingSummon.HasIncomingSummon(frame.unit) ) then
            local status = SarychUI.Compat.C_IncomingSummon.IncomingSummonStatus(frame.unit);
            if(status == SarychUI.Compat.Enum.SummonStatus.Pending) then
                SarychUI.Compat.Widgets.SetAtlas(frame.centerStatusIcon.texture, "Raid-Icon-SummonPending");
                frame.centerStatusIcon.texture:SetTexCoord(0, 1, 0, 1);
                frame.centerStatusIcon.border:Hide();
                frame.centerStatusIcon.tooltip = INCOMING_SUMMON_TOOLTIP_SUMMON_PENDING;
                frame.centerStatusIcon:Show();
            elseif( status == SarychUI.Compat.Enum.SummonStatus.Accepted ) then
                SarychUI.Compat.Widgets.SetAtlas(frame.centerStatusIcon.texture, "Raid-Icon-SummonAccepted");
                frame.centerStatusIcon.texture:SetTexCoord(0, 1, 0, 1);
                frame.centerStatusIcon.border:Hide();
                frame.centerStatusIcon.tooltip = INCOMING_SUMMON_TOOLTIP_SUMMON_ACCEPTED;
                frame.centerStatusIcon:Show();
            elseif( status == SarychUI.Compat.Enum.SummonStatus.Declined ) then
                SarychUI.Compat.Widgets.SetAtlas(frame.centerStatusIcon.texture, "Raid-Icon-SummonDeclined");
                frame.centerStatusIcon.texture:SetTexCoord(0, 1, 0, 1);
                frame.centerStatusIcon.border:Hide();
                frame.centerStatusIcon.tooltip = INCOMING_SUMMON_TOOLTIP_SUMMON_DECLINED;
                frame.centerStatusIcon:Show();
            end
        else
            if not frame.inDistance and frame.optionTable.displayInOtherPhase then
                local phaseReason = SarychUI.Compat.UnitPhaseReason(frame.unit);
                if phaseReason then
                    frame.centerStatusIcon.texture:SetTexture("Interface\\TargetingFrame\\UI-PhasingIcon");
                    frame.centerStatusIcon.texture:SetTexCoord(0.15625, 0.84375, 0.15625, 0.84375);
                    frame.centerStatusIcon.border:Hide();
                    frame.centerStatusIcon.tooltip = SarychUI.Compat.PartyUtil.GetPhasedReasonString(phaseReason, frame.unit);
                    frame.centerStatusIcon:Show();
                    return;
                end
            end
            frame.centerStatusIcon:Hide();
        end
    end
end

function CompactUnitFrame_UpdateWidgetSet(frame)
    if not frame.WidgetContainer then
        return;
    end
    local widgetSetID = UnitWidgetSet(frame.unit);
    frame.WidgetContainer:RegisterForWidgetSet(widgetSetID, DefaultWidgetLayout, nil, frame.unit);
end

function CompactUnitFrame_ClearWidgetSet(frame)
    if frame.WidgetContainer then
        frame.WidgetContainer:UnregisterForWidgetSet();
    end
end
--Other internal functions
do
    local function SetDebuffsHelper(debuffFrames, frameNum, maxDebuffs, filter, isBossAura, isBossBuff, auras)
        if auras then
            for i = 1,#auras do
                local aura = auras[i];
                if frameNum > maxDebuffs then
                    break;
                end
                local debuffFrame = debuffFrames[frameNum];
                local index, name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, nameplateShowPersonal, spellId = aura[1], aura[2], aura[3], aura[4], aura[5], aura[6], aura[7], aura[8], aura[9], aura[10], aura[11];
                local unit = nil;
                CompactUnitFrame_UtilSetDebuff(debuffFrame, unit, index, filter, isBossAura, isBossBuff, name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, nameplateShowPersonal, spellId);
                frameNum = frameNum + 1;
                if isBossAura then
                    --Boss auras are about twice as big as normal debuffs, so we may need to display fewer buffs
                    local bossDebuffScale = (debuffFrame.baseSize + BOSS_DEBUFF_SIZE_INCREASE)/debuffFrame.baseSize;
                    maxDebuffs = maxDebuffs - (bossDebuffScale - 1);
                end
            end
        end
        return frameNum, maxDebuffs;
    end

    local function NumElements(arr)
        return arr and #arr or 0;
    end

    -- Keep the normal buff and debuff display, without the separate dispel icons.
    local function CompactUnitFrame_UpdateAurasInternal(frame)
        local doneWithBuffs = not frame.buffFrames or not frame.optionTable.displayBuffs or frame.maxBuffs == 0;
        local doneWithDebuffs = not frame.debuffFrames or not frame.optionTable.displayDebuffs or frame.maxDebuffs == 0;
        local numUsedBuffs = 0;
        local numUsedDebuffs = 0;
        local displayOnlyDispellableDebuffs = frame.optionTable.displayOnlyDispellableDebuffs;
        -- The following is the priority order for debuffsSetAtlas
        local bossDebuffs, bossBuffs, priorityDebuffs, exceptionDebuffs, nonBossDebuffs, nonBossRaidDebuffs;
        local index = 1;
        local batchCount = frame.maxDebuffs;

        if not doneWithDebuffs then
            SarychUI.Compat.AuraUtil.ForEachAura(frame.displayedUnit, "HARMFUL", batchCount, function(...)
                local owner = SarychUI.modules and SarychUI.modules.group_frames
                if owner and owner:IsAuraBlacklisted(select(10, ...), "HARMFUL") then return false end
                if CompactUnitFrame_Util_IsBossAura(...) then
                    if not bossDebuffs then
                        bossDebuffs = {};
                    end
                    tinsert(bossDebuffs, {select(13, ...), ...});
                    numUsedDebuffs = numUsedDebuffs + 1;
                    if numUsedDebuffs == frame.maxDebuffs then
                        doneWithDebuffs = true;
                        return true;
                    end
                elseif displayOnlyDispellableDebuffs and owner and owner:IsDispelFilterException(select(10, ...)) then
                    exceptionDebuffs = exceptionDebuffs or {};
                    tinsert(exceptionDebuffs, {select(13, ...), ...});
                elseif CompactUnitFrame_Util_IsPriorityDebuff(...) then
                    if not priorityDebuffs then
                        priorityDebuffs = {};
                    end
                    tinsert(priorityDebuffs, {select(13, ...), ...});
                elseif not displayOnlyDispellableDebuffs and CompactUnitFrame_Util_ShouldDisplayDebuff(...) then
                    if not nonBossDebuffs then
                        nonBossDebuffs = {};
                    end
                    tinsert(nonBossDebuffs, {select(13, ...), ...});
                end
                index = index + 1;
                return false;
            end);
        end
        if not doneWithBuffs or not doneWithDebuffs then
            index = 1;
            batchCount = math.max(frame.maxDebuffs, frame.maxBuffs);
            SarychUI.Compat.AuraUtil.ForEachAura(frame.displayedUnit, "HELPFUL", batchCount, function(...)
                local owner = SarychUI.modules and SarychUI.modules.group_frames
                if owner and owner:IsAuraBlacklisted(select(10, ...), "HELPFUL") then return false end
                if CompactUnitFrame_Util_IsBossAura(...) then
                    -- Boss Auras are considered Debuffs for our purposes.
                    if not doneWithDebuffs then
                        if not bossBuffs then
                            bossBuffs = {};
                        end
                        tinsert(bossBuffs, {select(13, ...), ...});
                        numUsedDebuffs = numUsedDebuffs + 1;
                        if numUsedDebuffs == frame.maxDebuffs then
                            doneWithDebuffs = true;
                        end
                    end
                elseif CompactUnitFrame_UtilShouldDisplayBuff(...) then
                    if not doneWithBuffs then
                        numUsedBuffs = numUsedBuffs + 1;
                        local buffFrame = frame.buffFrames[numUsedBuffs];
                        CompactUnitFrame_UtilSetBuff(buffFrame, select(13, ...), ...);
                        if numUsedBuffs == frame.maxBuffs then
                            doneWithBuffs = true;
                        end
                    end
                end
                index = index + 1;
                return doneWithBuffs and doneWithDebuffs;
            end);
        end

        numUsedDebuffs = math.min(frame.maxDebuffs, numUsedDebuffs + NumElements(priorityDebuffs));
        if numUsedDebuffs == frame.maxDebuffs then
            doneWithDebuffs = true;
        end

        if not doneWithDebuffs and displayOnlyDispellableDebuffs then
            batchCount = frame.maxDebuffs;
            index = 1;
            SarychUI.Compat.AuraUtil.ForEachAura(frame.displayedUnit, "HARMFUL|RAID", batchCount, function(...)
                local owner = SarychUI.modules and SarychUI.modules.group_frames
                if owner and owner:IsAuraBlacklisted(select(10, ...), "HARMFUL|RAID") then return false end
                if not doneWithDebuffs and displayOnlyDispellableDebuffs then
                    if CompactUnitFrame_Util_ShouldDisplayDebuff(...) and not CompactUnitFrame_Util_IsBossAura(...)
                        and (not CompactUnitFrame_Util_IsPriorityDebuff(...)
                            or (owner and owner:IsDispelFilterException(select(10, ...)))) then
                        if not nonBossRaidDebuffs then
                            nonBossRaidDebuffs = {};
                        end
                        tinsert(nonBossRaidDebuffs, {select(13, ...), ...});
                        numUsedDebuffs = numUsedDebuffs + 1;
                        if numUsedDebuffs == frame.maxDebuffs then
                            doneWithDebuffs = true;
                        end
                    end
                end
                index = index + 1;
                return doneWithDebuffs;
            end);
        end

        local frameNum = 1;
        local maxDebuffs = frame.maxDebuffs;
        do
            local isBossAura = true;
            local isBossBuff = false;
            frameNum, maxDebuffs = SetDebuffsHelper(frame.debuffFrames, frameNum, maxDebuffs, "HARMFUL", isBossAura, isBossBuff, bossDebuffs);
        end
        do
            local isBossAura = true;
            local isBossBuff = true;
            frameNum, maxDebuffs = SetDebuffsHelper(frame.debuffFrames, frameNum, maxDebuffs, "HELPFUL", isBossAura, isBossBuff, bossBuffs);
        end
        do
            local isBossAura = true;
            local isBossBuff = false;
            frameNum, maxDebuffs = SetDebuffsHelper(frame.debuffFrames, frameNum, maxDebuffs, "HARMFUL", isBossAura, isBossBuff, priorityDebuffs);
        end
        do
            local isBossAura = false;
            local isBossBuff = false;
            frameNum, maxDebuffs = SetDebuffsHelper(frame.debuffFrames, frameNum, maxDebuffs, "HARMFUL|RAID", isBossAura, isBossBuff, nonBossRaidDebuffs);
        end
        do
            local isBossAura = false;
            local isBossBuff = false;
            frameNum, maxDebuffs = SetDebuffsHelper(frame.debuffFrames, frameNum, maxDebuffs, "HARMFUL", isBossAura, isBossBuff, nonBossDebuffs);
        end

        -- Dispellable effects take the leftmost available slots. Exceptions
        -- only fill remaining slots, and must not repeat a dispellable effect.
        if exceptionDebuffs then
            local dispellable = {};
            for _, aura in ipairs(nonBossRaidDebuffs or {}) do dispellable[aura[11]] = true; end
            local remaining = {};
            for _, aura in ipairs(exceptionDebuffs) do
                if not dispellable[aura[11]] then tinsert(remaining, aura); end
            end
            frameNum, maxDebuffs = SetDebuffsHelper(frame.debuffFrames, frameNum, maxDebuffs,
                "HARMFUL", false, false, remaining);
        end

        numUsedDebuffs = frameNum - 1;
        CompactUnitFrame_HideAllBuffs(frame, numUsedBuffs + 1);
        CompactUnitFrame_HideAllDebuffs(frame, numUsedDebuffs + 1);
    end

    function CompactUnitFrame_UpdateAuras(frame)
        if frame._suiTestData then
            local testModule = SarychUI and SarychUI.modules and SarychUI.modules.group_frames;
            if testModule and testModule.PaintTestAuras then
                testModule:PaintTestAuras(frame);
                return;
            end
        end
        CompactUnitFrame_UpdateAurasInternal(frame);
    end
end

--Utility Functions
function CompactUnitFrame_UtilShouldDisplayBuff(...)
    local name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId, canApplyAura = ...;
    local hasCustom, alwaysShowMine, showForMySpec = SarychUI.Compat.SpellGetVisibilityInfo(spellId, UnitAffectingCombat("player") and "RAID_INCOMBAT" or "RAID_OUTOFCOMBAT");
    if ( hasCustom ) then
        return showForMySpec or (alwaysShowMine and (unitCaster == "player" or unitCaster == "pet" or unitCaster == "vehicle"));
    else
        return (unitCaster == "player" or unitCaster == "pet" or unitCaster == "vehicle") and canApplyAura and not SarychUI.Compat.SpellIsSelfBuff(spellId);
    end
end

function CompactUnitFrame_HideAllBuffs(frame, startingIndex)
    if frame.buffFrames then
        for i=startingIndex or 1, #frame.buffFrames do
            frame.buffFrames[i]:Hide();
        end
    end
end

function CompactUnitFrame_HideAllDebuffs(frame, startingIndex)
    if frame.debuffFrames then
        for i=startingIndex or 1, #frame.debuffFrames do
            frame.debuffFrames[i]:Hide();
        end
    end
end


function CompactUnitFrame_UtilSetBuff(buffFrame, index, ...)
    local name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId, canApplyAura = ...;
    buffFrame.icon:SetTexture(icon);
    if ( count > 1 ) then
        local countText = count;
        if ( count >= 100 ) then
            countText = BUFF_STACKS_OVERFLOW;
        end
        buffFrame.count:Show();
        buffFrame.count:SetText(countText);
    else
        buffFrame.count:Hide();
    end
    buffFrame:SetID(index);
    local enabled = expirationTime and expirationTime ~= 0;
    if enabled then
        local startTime = expirationTime - duration;
        CooldownFrame_SetTimer(buffFrame.cooldown, startTime, duration, 1);
        if SarychUI_NotifyCooldown then SarychUI_NotifyCooldown(buffFrame.cooldown, startTime, duration, 1) end
    else
        SarychUI.Compat.CooldownFrame_Clear(buffFrame.cooldown);
    end
    buffFrame:SetFrameStrata("MEDIUM");
    buffFrame:Show();
end

function CompactUnitFrame_Util_ShouldDisplayDebuff(...)
    local name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId, canApplyAura, isBossAura = ...;
    local hasCustom, alwaysShowMine, showForMySpec = SarychUI.Compat.SpellGetVisibilityInfo(spellId, UnitAffectingCombat("player") and "RAID_INCOMBAT" or "RAID_OUTOFCOMBAT");
    if ( hasCustom ) then
        return showForMySpec or (alwaysShowMine and (unitCaster == "player" or unitCaster == "pet" or unitCaster == "vehicle") );   --Would only be "mine" in the case of something like forbearance.
    else
        return true;
    end
end

function CompactUnitFrame_Util_IsBossAura(...)
    return select(12, ...);
end

do
    local _, classFilename = UnitClass("player");
    if ( classFilename == "PALADIN" ) then
        CompactUnitFrame_Util_IsPriorityDebuff = function(...)
            local spellId = select(10, ...);
            local isForbearance = (spellId == 25771);
            return isForbearance or SarychUI.Compat.SpellIsPriorityAura(spellId);
        end
    else
        CompactUnitFrame_Util_IsPriorityDebuff = function(...)
            local spellId = select(10, ...);
            return SarychUI.Compat.SpellIsPriorityAura(spellId);
        end
    end
end

function CompactUnitFrame_UtilSetDebuff(debuffFrame, unit, index, filter, isBossAura, isBossBuff, ...)
    -- make sure you are using the correct index here!
    --isBossAura says make this look large.
    --isBossBuff looks in HELPFULL auras otherwise it looks in HARMFULL ones
    local name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId = ...;
    if name == nil then
        -- for backwards compatibility - this functionality will be removed in a future update
        if unit then
            if (isBossBuff) then
                name, _, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId = UnitBuff(unit, index, filter);
            else
                name, _, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId = UnitDebuff(unit, index, filter);
            end
        else
            return;
        end
    end
    debuffFrame.filter = filter;
    debuffFrame.icon:SetTexture(icon);
    if ( count > 1 ) then
        local countText = count;
        if ( count >= 100 ) then
            countText = BUFF_STACKS_OVERFLOW;
        end
        debuffFrame.count:Show();
        debuffFrame.count:SetText(countText);
    else
        debuffFrame.count:Hide();
    end
    debuffFrame:SetID(index);
    -- Re-evaluate on every assignment: pooled slots can switch from CC to a
    -- regular debuff. Preserve the actual aura duration, including DR.
    debuffFrame.cooldown.__sary_controlAura = SarychUI.Compat.SpellIsPriorityAura
        and SarychUI.Compat.SpellIsPriorityAura(spellId) or false;
    local enabled = expirationTime and expirationTime ~= 0;
    if enabled then
        local startTime = expirationTime - duration;
        CooldownFrame_SetTimer(debuffFrame.cooldown, startTime, duration, 1);
        if SarychUI_NotifyCooldown then SarychUI_NotifyCooldown(debuffFrame.cooldown, startTime, duration, 1) end
    else
        SarychUI.Compat.CooldownFrame_Clear(debuffFrame.cooldown);
    end
    local color = DebuffTypeColor[debuffType] or DebuffTypeColor["none"];
    debuffFrame.border:SetVertexColor(color.r, color.g, color.b);
    debuffFrame.isBossBuff = isBossBuff;
    if ( isBossAura ) then
        local size = min(debuffFrame.baseSize + BOSS_DEBUFF_SIZE_INCREASE, debuffFrame.maxHeight);
        debuffFrame:SetSize(size, size);
    else
        debuffFrame:SetSize(debuffFrame.baseSize, debuffFrame.baseSize);
    end
    debuffFrame:SetFrameStrata("MEDIUM");
    debuffFrame:Show();
end

--Dropdown
local compactFocusMenuButton
AttachSecureFocusMenuButton = function(unit)
    if not unit or (InCombatLockdown and InCombatLockdown()) then return end
    local list = _G.DropDownList1
    if not list or not list:IsShown() then return end
    if compactFocusMenuButton then compactFocusMenuButton:Hide() end

    local focusItem
    for i = 1, list.numButtons or 0 do
        local button = _G["DropDownList1Button" .. i]
        if button and button.value == "SET_FOCUS" and button:IsShown() then
            focusItem = button
            break
        end
    end
    if not focusItem then return end

    if not compactFocusMenuButton then
        -- No protected parent or anchor in the shared dropdown hierarchy.
        compactFocusMenuButton = CreateFrame("Button", "SarychUICompactRaidSecureFocusMenuButton", UIParent, "SecureActionButtonTemplate")
        compactFocusMenuButton:SetFrameStrata("FULLSCREEN_DIALOG")
        compactFocusMenuButton:RegisterForClicks("AnyUp")
        compactFocusMenuButton:SetAttribute("type1", "focus")
        compactFocusMenuButton:EnableMouse(true)
        RegisterStateDriver(compactFocusMenuButton, "visibility", "[combat] hide")

        local hover = compactFocusMenuButton:CreateTexture(nil, "OVERLAY")
        hover:SetAllPoints(compactFocusMenuButton)
        hover:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        hover:SetBlendMode("ADD")
        hover:Hide()
        compactFocusMenuButton.hover = hover

        compactFocusMenuButton:SetScript("OnEnter", function(self)
            if not self.focusItem or (InCombatLockdown and InCombatLockdown()) then return end
            self.hover:Show()
            UIDropDownMenu_StopCounting(list)
        end)
        compactFocusMenuButton:SetScript("OnLeave", function(self)
            if InCombatLockdown and InCombatLockdown() then return end
            self.hover:Hide()
            UIDropDownMenu_StartCounting(list)
            GameTooltip:Hide()
        end)
        compactFocusMenuButton:SetScript("OnUpdate", function(self)
            if not list:IsShown() and not (InCombatLockdown and InCombatLockdown()) then
                self:Hide()
            end
        end)
        compactFocusMenuButton:HookScript("OnClick", function(self)
            if self.focusItem and not self.focusItem.noClickSound then
                PlaySound("UChatScrollButton")
            end
            CloseDropDownMenus()
        end)
    end

    local left, top = focusItem:GetLeft(), focusItem:GetTop()
    if not left or not top then return end
    local scale = focusItem:GetEffectiveScale() / UIParent:GetEffectiveScale()
    compactFocusMenuButton.focusItem = focusItem
    compactFocusMenuButton:SetAttribute("unit", unit)
    compactFocusMenuButton.hover:Hide()
    compactFocusMenuButton:ClearAllPoints()
    compactFocusMenuButton:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * scale, top * scale)
    compactFocusMenuButton:SetSize(focusItem:GetWidth() * scale, focusItem:GetHeight() * scale)
    compactFocusMenuButton:SetFrameLevel(focusItem:GetFrameLevel() + 1)
    compactFocusMenuButton:Show()
end

function CompactUnitFrameDropDown_Initialize(self)
    local unit = self:GetParent().unit;
    if ( not unit ) then
        return;
    end
    local menu;
    local name;
    local id = nil;
    if ( UnitIsUnit(unit, "player") ) then
        menu = "SELF";
    elseif ( UnitIsUnit(unit, "vehicle") ) then
        -- NOTE: vehicle check must come before pet check for accuracy's sake because
        -- a vehicle may also be considered your pet
        menu = "VEHICLE";
    elseif ( UnitIsUnit(unit, "pet") ) then
        menu = "PET";
    elseif ( UnitIsPlayer(unit) ) then
        id = UnitInRaid(unit);
        if ( id ) then
            menu = "RAID_PLAYER";
        elseif ( UnitInParty(unit) ) then
            menu = "PARTY";
        else
            menu = "PLAYER";
        end
    else
        menu = "TARGET";
        name = RAID_TARGET_ICON;
    end
    if ( menu ) then
        UnitPopup_ShowMenu(self, menu, unit, name, id);
        if InCombatLockdown and InCombatLockdown() then
            local list = _G.DropDownList1
            if list then
                for i = 1, list.numButtons or 0 do
                    local button = _G["DropDownList1Button" .. i]
                    if button and button.value == "SET_FOCUS" then
                        button:Disable()
                        break
                    end
                end
            end
        end
    end
end
------The default setup function
local texCoords = {
    ["Raid-AggroFrame"] = {  0.00781250, 0.55468750, 0.00781250, 0.27343750 },
    ["Raid-TargetFrame"] = { 0.00781250, 0.55468750, 0.28906250, 0.55468750 },
}

DefaultCompactUnitFrameOptions = {
    useClassColors = true,
    displaySelectionHighlight = true,
    displayAggroHighlight = true,
    displayName = true,
    fadeOutOfRange = true,
    displayStatusText = true,
    displayHealPrediction = true,
    displayRoleIcon = true,
    displayRaidRoleIcon = true,
    displayBuffs = true,
    displayDebuffs = true,
    displayOnlyDispellableDebuffs = true,
    displayNonBossDebuffs = true,
    healthText = "perc",
    displayIncomingResurrect = true,
    displayIncomingSummon = true,
    displayInOtherGroup = true,
    displayInOtherPhase = true,

    --If class colors are enabled also show the class colors for npcs in your raid frames or
    --raid-frame-style party frames.
    allowClassColorsForNPCs = true,
}

local NATIVE_UNIT_FRAME_HEIGHT = 36;
local NATIVE_UNIT_FRAME_WIDTH = 72;

DefaultCompactUnitFrameSetupOptions = {
    displayPowerBar = true,
    height = NATIVE_UNIT_FRAME_HEIGHT,
    width = NATIVE_UNIT_FRAME_WIDTH,
    displayBorder = true,
}

local compactBarColorQueue, compactBarColorTicker;

local function QueueCompactUnitFrameColors(frame)
    if not frame then
        return;
    end
    compactBarColorQueue = compactBarColorQueue or {};
    compactBarColorQueue[frame] = 4;
    if not compactBarColorTicker then
        compactBarColorTicker = CreateFrame("Frame");
        compactBarColorTicker:Hide();
        compactBarColorTicker:SetScript("OnUpdate", function(self)
            local pending = false;
            for unitFrame, ticks in pairs(compactBarColorQueue) do
                if unitFrame.healthBar then
                    unitFrame.healthBar.r, unitFrame.healthBar.g, unitFrame.healthBar.b = nil, nil, nil;
                end
                if unitFrame.unit or unitFrame.displayedUnit then
                    CompactUnitFrame_UpdateHealthColor(unitFrame);
                    CompactUnitFrame_UpdatePowerColor(unitFrame);
                end
                if ticks > 1 then
                    compactBarColorQueue[unitFrame] = ticks - 1;
                    pending = true;
                else
                    compactBarColorQueue[unitFrame] = nil;
                end
            end
            if not pending then
                self:Hide();
            end
        end);
    end
    compactBarColorTicker:Show();
end

function DefaultCompactUnitFrameSetup(frame)
    local options = DefaultCompactUnitFrameSetupOptions;
    local componentScale = min(options.height / NATIVE_UNIT_FRAME_HEIGHT, options.width / NATIVE_UNIT_FRAME_WIDTH); 

    frame:SetAlpha(1);

    frame:SetSize(options.width, options.height);
    frame.overlay:SetParent(frame.healthBar);

    local powerBarHeight = 8;
    local powerBarUsedHeight = options.displayPowerBar and powerBarHeight or 0;



    frame.myHealPrediction = frame.overlay.myHealPrediction;
    frame.otherHealPrediction = frame.overlay.otherHealPrediction;
    frame.totalAbsorb = frame.overlay.totalAbsorb;

    frame.totalAbsorbOverlay = frame.overlay.totalAbsorbOverlay;

    frame.name = frame.overlay.name;
    frame.statusText = frame.overlay.statusText;
    frame.roleIcon = frame.overlay.roleIcon;

    frame.aggroHighlight = frame.overlay.aggroHighlight;
    frame.myHealAbsorb = frame.overlay.myHealAbsorb;

    frame.myHealAbsorbLeftShadow = frame.overlay.myHealAbsorbLeftShadow;
    frame.myHealAbsorbRightShadow = frame.overlay.myHealAbsorbRightShadow;

    frame.overAbsorbGlow = frame.overlay.overAbsorbGlow;

    frame.overHealAbsorbGlow = frame.overlay.overHealAbsorbGlow;

    frame.background:SetTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Raid-Bar-Hp-Bg");
    frame.background:SetTexCoord(0, 1, 0, 0.53125);
    frame.healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1);

    frame.healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1 + powerBarUsedHeight);

    frame.healthBar:SetStatusBarTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Raid-Bar-Hp-Fill");
    frame.healthBar:SetFrameLevel(frame:GetFrameLevel());
    if ( frame.powerBar ) then
        if ( options.displayPowerBar ) then
            if ( options.displayBorder ) then
                frame.powerBar:SetPoint("TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, -2);
            else
                frame.powerBar:SetPoint("TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, 0);
            end
            frame.powerBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1);
            frame.powerBar:SetStatusBarTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Raid-Bar-Resource-Fill");
            frame.powerBar.background:SetTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Raid-Bar-Resource-Background");
            frame.powerBar:Show();
            frame.powerBar:SetParent(frame.healthBar);
        else
            frame.powerBar:Hide();
        end
    end

    frame.myHealPrediction:ClearAllPoints();
    frame.myHealPrediction:SetTexture(1,1,1);
    SarychUI.UnitFrameLayers:SetRangeGradient(frame, frame.myHealPrediction,
        "VERTICAL", 8/255, 93/255, 72/255, 11/255, 136/255, 105/255);
    frame.myHealAbsorb:ClearAllPoints();
    frame.myHealAbsorb:SetTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Absorb-Fill", true, true);
    frame.myHealAbsorbLeftShadow:ClearAllPoints();
    frame.myHealAbsorbRightShadow:ClearAllPoints();
    frame.otherHealPrediction:ClearAllPoints();
    frame.otherHealPrediction:SetTexture(1,1,1);
    SarychUI.UnitFrameLayers:SetRangeGradient(frame, frame.otherHealPrediction,
        "VERTICAL", 11/255, 53/255, 43/255, 21/255, 89/255, 72/255);
    frame.totalAbsorb:ClearAllPoints();
    frame.totalAbsorb:SetTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Shield-Fill");
    frame.totalAbsorb.overlay = frame.totalAbsorbOverlay;
    frame.totalAbsorbOverlay:SetTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Shield-Overlay", true, true);    --Tile both vertically and horizontally
    frame.totalAbsorbOverlay:SetAllPoints(frame.totalAbsorb);
    frame.totalAbsorbOverlay.tileSize = 32;
    frame.overAbsorbGlow:ClearAllPoints();
    frame.overAbsorbGlow:SetTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Shield-Overshield");
    frame.overAbsorbGlow:SetBlendMode("ADD");
    frame.overAbsorbGlow:SetPoint("BOTTOMLEFT", frame.healthBar, "BOTTOMRIGHT", -7, 0);
    frame.overAbsorbGlow:SetPoint("TOPLEFT", frame.healthBar, "TOPRIGHT", -7, 0);
    frame.overAbsorbGlow:SetWidth(16);
    frame.overHealAbsorbGlow:ClearAllPoints();
    frame.overHealAbsorbGlow:SetTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Absorb-Overabsorb");
    frame.overHealAbsorbGlow:SetBlendMode("ADD");
    frame.overHealAbsorbGlow:SetPoint("BOTTOMRIGHT", frame.healthBar, "BOTTOMLEFT", 7, 0);
    frame.overHealAbsorbGlow:SetPoint("TOPRIGHT", frame.healthBar, "TOPLEFT", 7, 0);
    frame.overHealAbsorbGlow:SetWidth(16);

    frame.roleIcon:ClearAllPoints();
    frame.roleIcon:SetPoint("TOPLEFT", 3, -2);
    frame.roleIcon:SetSize(12, 12);

    frame.name:SetPoint("TOPLEFT", frame.roleIcon, "TOPRIGHT", 0, -1);
    frame.name:SetPoint("TOPRIGHT", -3, -3);
    frame.name:SetJustifyH("LEFT");

    local NATIVE_FONT_SIZE = 12;
    local fontName, fontSize, fontFlags = frame.statusText:GetFont();
    frame.statusText:SetFont(fontName, NATIVE_FONT_SIZE * componentScale, fontFlags);
    frame.statusText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 3, options.height / 3 - 2);
    frame.statusText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, options.height / 3 - 2);
    frame.statusText:SetHeight(12 * componentScale);

    local readyCheckSize = 15 * componentScale;
    frame.ignoreParentAlpha.readyCheckIcon:ClearAllPoints();
    frame.ignoreParentAlpha.readyCheckIcon:SetPoint("BOTTOM", frame, "BOTTOM", 0, options.height / 3 - 4);
    frame.ignoreParentAlpha.readyCheckIcon:SetSize(readyCheckSize, readyCheckSize);

    local buffSize = 11 * componentScale;

    CompactUnitFrame_SetMaxBuffs(frame, 3);
    CompactUnitFrame_SetMaxDebuffs(frame, 3);

    local buffPos, buffRelativePoint, buffOffset = "BOTTOMRIGHT", "BOTTOMLEFT", CUF_AURA_BOTTOM_OFFSET + powerBarUsedHeight;
    frame.buffFrames[1]:ClearAllPoints();
    frame.buffFrames[1]:SetPoint(buffPos, frame, "BOTTOMRIGHT", -3, buffOffset);

    for i=1, #frame.buffFrames do
        if ( i > 1 ) then
            frame.buffFrames[i]:ClearAllPoints();
            frame.buffFrames[i]:SetPoint(buffPos, frame.buffFrames[i - 1], buffRelativePoint, 0, 0);
        end
        frame.buffFrames[i]:SetSize(buffSize, buffSize);
        frame.buffFrames[i]:SetParent(frame.healthBar);
    end

    local debuffPos, debuffRelativePoint, debuffOffset = "BOTTOMLEFT", "BOTTOMRIGHT", CUF_AURA_BOTTOM_OFFSET + powerBarUsedHeight;
    frame.debuffFrames[1]:ClearAllPoints();
    frame.debuffFrames[1]:SetPoint(debuffPos, frame, "BOTTOMLEFT", 3, debuffOffset);
    for i=1, #frame.debuffFrames do
        if ( i > 1 ) then
            frame.debuffFrames[i]:ClearAllPoints();
            frame.debuffFrames[i]:SetPoint(debuffPos, frame.debuffFrames[i - 1], debuffRelativePoint, 0, 0);
        end
        frame.debuffFrames[i].baseSize = buffSize;
        frame.debuffFrames[i].maxHeight = options.height - powerBarUsedHeight - CUF_AURA_BOTTOM_OFFSET - CUF_NAME_SECTION_SIZE;
        frame.debuffFrames[i]:SetSize(11, 11);
        frame.debuffFrames[i]:SetParent(frame.healthBar);
    end

    frame.ignoreParentAlpha.selectionHighlight:SetTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Raid-FrameHighlights");
    frame.ignoreParentAlpha.selectionHighlight:SetTexCoord(unpack(texCoords["Raid-TargetFrame"]));
    frame.ignoreParentAlpha.selectionHighlight:SetAllPoints(frame);

    frame.aggroHighlight:SetTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Raid-FrameHighlights");
    frame.aggroHighlight:SetTexCoord(unpack(texCoords["Raid-AggroFrame"]));
    frame.aggroHighlight:SetAllPoints(frame);

    frame.centerStatusIcon:ClearAllPoints();
    frame.centerStatusIcon:SetPoint("CENTER", frame, "BOTTOM", 0, options.height / 3 + 2);
    frame.centerStatusIcon:SetSize(buffSize * 2, buffSize * 2);
    frame.centerStatusIcon:SetParent(frame.healthBar);

    if ( options.displayBorder ) then
        frame.horizTopBorder:ClearAllPoints();
        frame.horizTopBorder:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, -7);
        frame.horizTopBorder:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, -7);
        frame.horizTopBorder:SetTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Raid-HSeparator");
        frame.horizTopBorder:SetHeight(8);
        frame.horizTopBorder:Show();
        frame.horizBottomBorder:ClearAllPoints();
        frame.horizBottomBorder:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 1);
        frame.horizBottomBorder:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, 1);
        frame.horizBottomBorder:SetTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Raid-HSeparator");
        frame.horizBottomBorder:SetHeight(8);
        frame.horizBottomBorder:Show();
        frame.vertLeftBorder:ClearAllPoints();
        frame.vertLeftBorder:SetPoint("TOPRIGHT", frame, "TOPLEFT", 7, 0);
        frame.vertLeftBorder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 7, 0);
        frame.vertLeftBorder:SetTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Raid-VSeparator");
        frame.vertLeftBorder:SetWidth(8);
        frame.vertLeftBorder:Show();
        frame.vertRightBorder:ClearAllPoints();
        frame.vertRightBorder:SetPoint("TOPLEFT", frame, "TOPRIGHT", -1, 0);
        frame.vertRightBorder:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", -1, 0);
        frame.vertRightBorder:SetTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Raid-VSeparator");
        frame.vertRightBorder:SetWidth(8);
        frame.vertRightBorder:Show();
        if ( options.displayPowerBar ) then
            frame.horizDivider:ClearAllPoints();
            frame.horizDivider:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 1 + powerBarUsedHeight);
            frame.horizDivider:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, 1 + powerBarUsedHeight);
            frame.horizDivider:SetTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Raid-HSeparator");
            frame.horizDivider:SetHeight(8);
            frame.horizDivider:Show();
        else
            frame.horizDivider:Hide();
        end
    else
        frame.horizTopBorder:Hide();
        frame.horizBottomBorder:Hide();
        frame.vertLeftBorder:Hide();
        frame.vertRightBorder:Hide();
        frame.horizDivider:Hide();
    end 
    CompactUnitFrame_SetOptionTable(frame, DefaultCompactUnitFrameOptions)
    if frame.healthBar then
        frame.healthBar.r, frame.healthBar.g, frame.healthBar.b = nil, nil, nil
    end
    if frame.unit or frame.displayedUnit then
        CompactUnitFrame_UpdateHealthColor(frame)
        CompactUnitFrame_UpdatePowerColor(frame)
    end
    QueueCompactUnitFrameColors(frame)
end

DefaultCompactMiniFrameOptions = {
    displaySelectionHighlight = true,
    displayAggroHighlight = true,
    displayName = true,
    fadeOutOfRange = true,
    displayStatusText = true,
    displayHealPrediction = true,
}

DefaultCompactMiniFrameSetUpOptions = {
    height = 18,
    width = 72,
    displayBorder = true,
}

function DefaultCompactMiniFrameSetup(frame)
    local options = DefaultCompactMiniFrameSetUpOptions;

    frame:SetAlpha(1);
    frame:SetSize(options.width, options.height);
    frame.overlay:SetParent(frame.healthBar)

    frame.myHealPrediction = frame.overlay.myHealPrediction;
    frame.otherHealPrediction = frame.overlay.otherHealPrediction;
    frame.totalAbsorb = frame.overlay.totalAbsorb;

    frame.totalAbsorbOverlay = frame.overlay.totalAbsorbOverlay;

    frame.name = frame.overlay.name;
    frame.statusText = frame.overlay.statusText;
    frame.roleIcon = frame.overlay.roleIcon;

    frame.aggroHighlight = frame.overlay.aggroHighlight;
    frame.myHealAbsorb = frame.overlay.myHealAbsorb;

    frame.myHealAbsorbLeftShadow = frame.overlay.myHealAbsorbLeftShadow;
    frame.myHealAbsorbRightShadow = frame.overlay.myHealAbsorbRightShadow;
    frame.overAbsorbGlow = frame.overlay.overAbsorbGlow;

    frame.overHealAbsorbGlow = frame.overlay.overHealAbsorbGlow;

    frame.background:SetTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Raid-Bar-Hp-Bg");
    frame.background:SetTexCoord(0, 1, 0, 0.53125);
    frame.healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1);
    frame.healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1);
    frame.healthBar:SetStatusBarTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Raid-Bar-Hp-Fill");
    frame.healthBar:SetFrameLevel(frame:GetFrameLevel());

    frame.myHealPrediction:ClearAllPoints();
    frame.myHealPrediction:SetTexture(1,1,1);
    SarychUI.UnitFrameLayers:SetRangeGradient(frame, frame.myHealPrediction,
        "VERTICAL", 8/255, 93/255, 72/255, 11/255, 136/255, 105/255);
    frame.myHealAbsorb:ClearAllPoints();
    frame.myHealAbsorb:SetTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Absorb-Fill", true, true);
    frame.myHealAbsorbLeftShadow:ClearAllPoints();
    frame.myHealAbsorbRightShadow:ClearAllPoints();
    frame.otherHealPrediction:ClearAllPoints();
    frame.otherHealPrediction:SetTexture(1,1,1);
    SarychUI.UnitFrameLayers:SetRangeGradient(frame, frame.otherHealPrediction,
        "VERTICAL", 3/255, 72/255, 5/255, 2/255, 101/255, 18/255);
    frame.totalAbsorb:ClearAllPoints();
    frame.totalAbsorb:SetTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Shield-Fill");
    frame.totalAbsorb.overlay = frame.totalAbsorbOverlay;
    frame.totalAbsorbOverlay:SetTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Shield-Overlay", true, true);    --Tile both vertically and horizontally
    frame.totalAbsorbOverlay:SetAllPoints(frame.totalAbsorb);
    frame.totalAbsorbOverlay.tileSize = 32;
    frame.overAbsorbGlow:ClearAllPoints();
    frame.overAbsorbGlow:SetTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Shield-Overshield");
    frame.overAbsorbGlow:SetBlendMode("ADD");
    frame.overAbsorbGlow:SetPoint("BOTTOMLEFT", frame.healthBar, "BOTTOMRIGHT", -7, 0);
    frame.overAbsorbGlow:SetPoint("TOPLEFT", frame.healthBar, "TOPRIGHT", -7, 0);
    frame.overAbsorbGlow:SetWidth(16);
    frame.overHealAbsorbGlow:ClearAllPoints();
    frame.overHealAbsorbGlow:SetTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Absorb-Overabsorb");
    frame.overHealAbsorbGlow:SetBlendMode("ADD");
    frame.overHealAbsorbGlow:SetPoint("BOTTOMRIGHT", frame.healthBar, "BOTTOMLEFT", 7, 0);
    frame.overHealAbsorbGlow:SetPoint("TOPRIGHT", frame.healthBar, "TOPLEFT", 7, 0);
    frame.overHealAbsorbGlow:SetWidth(16);

    frame.name:SetPoint("LEFT", 5, 1);
    frame.name:SetPoint("RIGHT", -3, 1);
    frame.name:SetHeight(12);
    frame.name:SetJustifyH("LEFT");

    frame.ignoreParentAlpha.selectionHighlight:SetTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Raid-FrameHighlights");
    frame.ignoreParentAlpha.selectionHighlight:SetTexCoord(unpack(texCoords["Raid-TargetFrame"]));
    frame.ignoreParentAlpha.selectionHighlight:SetAllPoints(frame);

    frame.aggroHighlight:SetTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Raid-FrameHighlights");
    frame.aggroHighlight:SetTexCoord(unpack(texCoords["Raid-AggroFrame"]));
    frame.aggroHighlight:SetAllPoints(frame);

    if ( options.displayBorder ) then
        frame.horizTopBorder:ClearAllPoints();
        frame.horizTopBorder:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, -7);
        frame.horizTopBorder:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, -7);
        frame.horizTopBorder:SetTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Raid-HSeparator");
        frame.horizTopBorder:SetHeight(8);
        frame.horizTopBorder:Show();

        frame.horizBottomBorder:ClearAllPoints();
        frame.horizBottomBorder:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 1);
        frame.horizBottomBorder:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, 1);
        frame.horizBottomBorder:SetTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Raid-HSeparator");
        frame.horizBottomBorder:SetHeight(8);
        frame.horizBottomBorder:Show();

        frame.vertLeftBorder:ClearAllPoints();
        frame.vertLeftBorder:SetPoint("TOPRIGHT", frame, "TOPLEFT", 7, 0);
        frame.vertLeftBorder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 7, 0);
        frame.vertLeftBorder:SetTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Raid-VSeparator");
        frame.vertLeftBorder:SetWidth(8);
        frame.vertLeftBorder:Show();

        frame.vertRightBorder:ClearAllPoints();
        frame.vertRightBorder:SetPoint("TOPLEFT", frame, "TOPRIGHT", -1, 0);
        frame.vertRightBorder:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", -1, 0);
        frame.vertRightBorder:SetTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Raid-VSeparator");
        frame.vertRightBorder:SetWidth(8);
        frame.vertRightBorder:Show();
    else
        frame.horizTopBorder:Hide();
        frame.horizBottomBorder:Hide();
        frame.vertLeftBorder:Hide();
        frame.vertRightBorder:Hide();
    end
    CompactUnitFrame_SetOptionTable(frame, DefaultCompactMiniFrameOptions)
    if frame.healthBar then
        frame.healthBar.r, frame.healthBar.g, frame.healthBar.b = nil, nil, nil
    end
    if frame.unit or frame.displayedUnit then
        CompactUnitFrame_UpdateHealthColor(frame)
    end
    QueueCompactUnitFrameColors(frame)
end
