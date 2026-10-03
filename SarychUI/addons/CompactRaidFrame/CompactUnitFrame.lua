--Widget Handlers
local OPTION_TABLE_NONE = {};
BOSS_DEBUFF_SIZE_INCREASE = 9;
CUF_READY_CHECK_DECAY_TIME = 11;
DISTANCE_THRESHOLD_SQUARED = 250*250;
CUF_NAME_SECTION_SIZE = 15;
CUF_AURA_BOTTOM_OFFSET = 2;

local _, playerClassFilename = UnitClass("player");
local UnitInRange = C_UnitInRange;
local UnitGroupRolesAssigned = C_UnitGroupRolesAssigned;

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
    self:RegisterEvent("UNIT_PORTRAIT_UPDATE");
    self:RegisterEvent("PARTY_MEMBER_ENABLE");
    self:RegisterEvent("PARTY_MEMBER_DISABLE");
    self:RegisterEvent("PLAYER_TARGET_CHANGED");
    self:RegisterEvent("PLAYER_REGEN_ENABLED");
    self:RegisterEvent("PLAYER_REGEN_DISABLED");
    self:RegisterEvent("PLAYER_ROLES_ASSIGNED");
    self:RegisterEvent("UNIT_PET");
    self:RegisterEvent("READY_CHECK");
    self:RegisterEvent("READY_CHECK_FINISHED");
    self:RegisterEvent("READY_CHECK_CONFIRM");
    self:RegisterEvent("INCOMING_RESURRECT_CHANGED");
    self:RegisterEvent("UNIT_FLAGS");
    self:RegisterEvent("UNIT_ENTERED_VEHICLE");
    self:RegisterEvent("UNIT_EXITED_VEHICLE");
    -- also see CompactUnitFrame_UpdateUnitEvents for more events

    CompactUnitFrame_UpdateUnitEvents(self);

    self.maxBuffs = 0;
    self.maxDebuffs = 0;
    self.maxDispelDebuffs = 0;
    CompactUnitFrame_SetOptionTable(self, OPTION_TABLE_NONE);

    if not self.disableMouse then
        CompactUnitFrame_SetUpClicks(self);
    end
end

function CompactUnitFrame_OnEvent(self, event, ...)
    local arg1 = ...;
    if ( event == self.updateAllEvent and (not self.updateAllFilter or self.updateAllFilter(self, event, ...)) ) then
        CompactUnitFrame_UpdateAll(self);
    elseif ( event == "PLAYER_ENTERING_WORLD" ) then
        CompactUnitFrame_UpdateAll(self);
    elseif ( event == "PLAYER_TARGET_CHANGED" ) then
        CompactUnitFrame_UpdateSelectionHighlight(self);
        CompactUnitFrame_UpdateName(self);
        CompactUnitFrame_UpdateHealthBorder(self);
    elseif ( event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" ) then
        CompactUnitFrame_UpdateAuras(self); --We filter differently based on whether the player is in Combat, so we need to update when that changes.
    elseif ( event == "READY_CHECK" ) then
        CompactUnitFrame_UpdateReadyCheck(self);
    elseif ( event == "READY_CHECK_FINISHED" ) then
        CompactUnitFrame_FinishReadyCheck(self);
    else
        local unitMatches = arg1 == self.unit or arg1 == self.displayedUnit;
        if ( unitMatches ) then
            if ( event == "UNIT_MAXHEALTH" ) then
                CompactUnitFrame_UpdateMaxHealth(self);
                CompactUnitFrame_SetHealthDirty(self);
                CompactUnitFrame_SetHealPredictionDirty(self);
            elseif ( event == "UNIT_HEALTH" ) then
                CompactUnitFrame_SetHealthDirty(self);
                CompactUnitFrame_UpdateStatusText(self);
                CompactUnitFrame_SetHealPredictionDirty(self);
            elseif ( event == "UNIT_MAXMANA" ) then
                CompactUnitFrame_UpdateMaxPower(self);
                CompactUnitFrame_UpdatePower(self);
            elseif ( event == "UNIT_RAGE" or event == "UNIT_MANA" or event == "UNIT_RUNIC_POWER" or event == "UNIT_ENERGY" ) then
                CompactUnitFrame_UpdatePower(self);
            elseif ( event == "UNIT_DISPLAYPOWER" or event == "UNIT_POWER_BAR_SHOW" or event == "UNIT_POWER_BAR_HIDE" ) then
                CompactUnitFrame_UpdateMaxPower(self);
                CompactUnitFrame_UpdatePower(self);
                CompactUnitFrame_UpdatePowerColor(self);
            elseif ( event == "UNIT_NAME_UPDATE" or event == "UNIT_PORTRAIT_UPDATE" or (event == "UNIT_MODEL_CHANGED" and UnitCreatureFamily(self.unit)) ) then
                CompactUnitFrame_UpdateName(self);
                CompactUnitFrame_UpdateHealthColor(self);   --This may signify that we now have the unit's class (the name cache entry has been received).
                CompactUnitFrame_UpdatePowerColor(self);

                if ( event == "UNIT_MODEL_CHANGED" ) then
                    CompactUnitFrame_UpdateMaxHealth(self);  --This may signify that the unit is a new pet who replaced an old pet, and needs a health update
                    CompactUnitFrame_SetHealthDirty(self);
                    CompactUnitFrame_SetHealPredictionDirty(self);
                    CompactUnitFrame_UpdateStatusText(self);
                end
            elseif ( event == "UNIT_LEVEL" ) then
                CompactUnitFrame_UpdateHealthColor(self);
                CompactUnitFrame_UpdatePowerColor(self);
            elseif ( event == "UNIT_AURA" ) then
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
                CompactUnitFrame_SetHealPredictionDirty(self);
            elseif ( event == "UNIT_PET" ) then
                CompactUnitFrame_UpdateAll(self);
            elseif ( event == "READY_CHECK_CONFIRM" ) then
                CompactUnitFrame_UpdateReadyCheck(self);
            elseif ( event == "INCOMING_RESURRECT_CHANGED" ) then
                CompactUnitFrame_UpdateCenterStatusIcon(self);
            elseif ( event == "UNIT_ABSORB_AMOUNT_CHANGED" ) then
                CompactUnitFrame_SetHealPredictionDirty(self);
            elseif ( event == "UNIT_HEAL_ABSORB_AMOUNT_CHANGED" ) then
                CompactUnitFrame_SetHealPredictionDirty(self);
            elseif ( event == "PLAYER_FLAGS_CHANGED" ) then
                CompactUnitFrame_UpdateStatusText(self);
            elseif ( event == "UNIT_FLAGS" ) then
                CompactUnitFrame_UpdateCenterStatusIcon(self);
            elseif ( event == "PLAYER_ROLES_ASSIGNED" ) then
                CompactUnitFrame_UpdateRoleIcon(self);
            end
        elseif ( event == "PARTY_MEMBER_ENABLE" or event == "PARTY_MEMBER_DISABLE" ) then
            local partyIndex = tonumber(arg1);
            if ( partyIndex and self.unit == "party"..partyIndex ) then
                CompactUnitFrame_UpdateHealthColor(self);
                CompactUnitFrame_UpdateMaxPower(self);
                CompactUnitFrame_UpdatePower(self);
                CompactUnitFrame_UpdatePowerColor(self);
                CompactUnitFrame_UpdateStatusText(self);
            end
        end
        if ( unitMatches or arg1 == "player" ) then
            if ( event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" ) then
                CompactUnitFrame_UpdateAll(self);
            end
        end
    end
end

function CompactUnitFrame_SetAurasDirty(self)
    self.aurasDirty = true;
    CompactUnitFrame_CheckNeedsUpdate(self);
end

function CompactUnitFrame_SetHealthDirty(self)
    self.healthDirty = true;
    CompactUnitFrame_CheckNeedsUpdate(self);
end

function CompactUnitFrame_SetHealPredictionDirty(self)
    self.healPredictionDirty = true;
    CompactUnitFrame_CheckNeedsUpdate(self);
end

function CompactUnitFrame_CheckNeedsUpdate(self)
    -- Performance optimization to reduce UI update time in large raids:
    -- Avoid having OnUpdate registered unless absolutely necessary to process some deferred or periodic event.
    -- If the frame specifies a custom OnUpdate, assume they always want it called (for now).
    local needsUpdate = self.OnUpdate or self.onUpdateFrame ~= nil or self.rangeCheck ~= nil or self.readyCheckDecay ~= nil or self.aurasDirty or self.healthDirty or self.healPredictionDirty;
    if ( needsUpdate ~= self.needsUpdate ) then
        local onUpdate = self.OnUpdate or CompactUnitFrame_OnUpdate;
        self:SetScript("OnUpdate", needsUpdate and onUpdate or nil);
        self.needsUpdate = needsUpdate;
    end
end

--DEBUG FIXME - We should really try to avoid having OnUpdate on every frame. An event when going in/out of range would be greatly preferred.
function CompactUnitFrame_OnUpdate(self, elapsed)
    if self.onUpdateFrame then
        --PLEEEEEASE FIX ME. This makes me very very sad. (Unfortunately, there isn't a great way to deal with the lack of "raid1targettarget" events though)
        if self.displayedUnit then
            if self.onUpdateFrame > .5 or self.onUpdateFrame == 0 then
                CompactUnitFrame_UpdateAll(self)
                self.onUpdateFrame = 0;
            end
            self.onUpdateFrame = self.onUpdateFrame + elapsed;
        end
    else
        if self.readyCheckDecay then
            CompactUnitFrame_CheckReadyCheckDecay(self, elapsed);
        end

        if self.aurasDirty then
            if self.displayedUnit then
                CompactUnitFrame_UpdateAuras(self);
            end
            self.aurasDirty = nil;
        end

        -- This is frequent and expensive, update once per frame at most.
        if self.healthDirty then
            CompactUnitFrame_UpdateHealth(self);
            self.healthDirty = nil;
        end

        -- This is frequent and expensive, update once per frame at most.
        if self.healPredictionDirty then
            CompactUnitFrame_UpdateHealPrediction(self);
            self.healPredictionDirty = nil;
        end

        -- This is added as an alternative to events in later expansions, it will cause OnUpdate to always fire.
        if self.rangeCheck then
            self.rangeCheck = self.rangeCheck + elapsed;
            if self.rangeCheck > .5 then
                CompactUnitFrame_UpdateInRange(self);
                -- Class, power type and online-state often arrive after the first roster paint in LFD.
                CompactUnitFrame_UpdateHealthColor(self);
                CompactUnitFrame_UpdateMaxPower(self);
                CompactUnitFrame_UpdatePower(self);
                CompactUnitFrame_UpdatePowerColor(self);
                --CompactUnitFrame_UpdateDistance(self);
                self.rangeCheck = 0;
            end
        end
    end

    CompactUnitFrame_CheckNeedsUpdate(self);
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

        frame.aurasDirty = nil;
        frame.healthDirty = nil;
        frame.healPredictionDirty = nil;
        frame.needsUpdate = nil;
        frame.onUpdateFrame = nil;

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

function CompactUnitFrame_SetUpdateAllOnUpdate(self)
    self.onUpdateFrame = self.onUpdateFrame or 0;
    CompactUnitFrame_CheckNeedsUpdate(self);
end

--Things you'll have to set up to get everything looking right:
--1. Frame size
--2. Health/Mana bar positions
--3. Health/Mana bar textures (also, optionally, background textures)
--4. Name position
--5. Buff/Debuff/Dispellable positions
--6. Call CompactUnitFrame_SetMaxBuffs, _SetMaxDebuffs, and _SetMaxDispelDebuffs. (If you're setting it to greater than the default, make sure to create new buff/debuff frames and position them.)
--7. Selection highlight position and texture.
--8. Aggro highlight position and texture
--9. Role icon position
function CompactUnitFrame_SetUpFrame(frame, func)
    func(frame);
    CompactUnitFrame_UpdateAll(frame);
end

function CompactUnitFrame_SetOptionTable(frame, optionTable)
    frame.optionTable = optionTable;
    CompactUnitFrame_SetAurasDirty(frame);
    --CompactUnitFrame_UpdateAll(frame);
end

function CompactUnitFrame_RegisterEvents(frame)
    local onEventHandler = frame.OnEvent or CompactUnitFrame_OnEvent;
    frame:SetScript("OnEvent", onEventHandler);

    --CompactUnitFrame_UpdateUnitEvents(frame);

    CompactUnitFrame_CheckNeedsUpdate(frame);
end

function CompactUnitFrame_UpdateUnitEvents(frame)
    frame:RegisterEvent("UNIT_MAXHEALTH");
    frame:RegisterEvent("UNIT_HEALTH");
    frame:RegisterEvent("UNIT_MAXMANA");
    frame:RegisterEvent("UNIT_RAGE");
    frame:RegisterEvent("UNIT_MANA");
    frame:RegisterEvent("UNIT_ENERGY");
    frame:RegisterEvent("UNIT_RUNIC_POWER");
    frame:RegisterEvent("UNIT_AURA");
    frame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE");
    frame:RegisterEvent("UNIT_THREAT_LIST_UPDATE");
    frame:RegisterEvent("PLAYER_FLAGS_CHANGED");
    frame:RegisterEvent("UNIT_LEVEL");
    frame:RegisterEvent("UNIT_MODEL_CHANGED"); -- Tsoukie: We use this to attempt to solve pet inconsistency on 3.3.5a.
    --frame:RegisterEvent("UNIT_HEAL_PREDICTION");
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

function CompactUnitFrame_SetMenuFunc(frame, menuFunc)
    UIDropDownMenu_Initialize(frame.dropDown, menuFunc, "MENU");
    frame.menu = function()
        ToggleDropDownMenu(1, nil, frame.dropDown, frame:GetName(), 0, 0);
    end
end

function CompactUnitFrame_SetMaxBuffs(frame, numBuffs)
    frame.maxBuffs = numBuffs;
    CompactUnitFrame_SetAurasDirty(frame);
end

function CompactUnitFrame_SetMaxDebuffs(frame, numDebuffs)
    frame.maxDebuffs = numDebuffs;
    CompactUnitFrame_SetAurasDirty(frame);
end

function CompactUnitFrame_SetMaxDispelDebuffs(frame, numDispelDebuffs)
    frame.maxDispelDebuffs = numDispelDebuffs;
    CompactUnitFrame_SetAurasDirty(frame);
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
    if ( frame.unitExists ) then
        CompactUnitFrame_UpdateMaxHealth(frame);
        CompactUnitFrame_UpdateHealth(frame);
        CompactUnitFrame_UpdateHealthColor(frame);
        CompactUnitFrame_UpdateMaxPower(frame);
        CompactUnitFrame_UpdatePower(frame);
        CompactUnitFrame_UpdatePowerColor(frame);
        CompactUnitFrame_UpdateName(frame);
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
    end
end

function CompactUnitFrame_UpdateInVehicle(frame)
    --[[local shouldTargetVehicle = UnitHasVehicleUI(frame.unit);
    local unitVehicleToken;

    if ( shouldTargetVehicle ) then
         local raidID = UnitInRaid(frame.unit);
         if ( raidID and not UnitTargetsVehicleInRaidUI(frame.unit) ) then
             shouldTargetVehicle = false;
         end
     end

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
    end]]
end

function CompactUnitFrame_UpdateVisible(frame)
    if ( UnitExists(frame.unit) or UnitExists(frame.displayedUnit) ) then
        if ( not frame.unitExists ) then
            frame.newUnit = true;
        end
        frame.unitExists = true;

        -- Enable range check, disabled for player.
        if UnitIsUnit(frame.unit, "player") then
            frame.rangeCheck = nil;
        else
            frame.rangeCheck = frame.rangeCheck or 0;
        end
    else
        frame.unitExists = nil;
        frame.rangeCheck = nil;
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
            if ( (frame.optionTable.allowClassColorsForNPCs or UnitIsPlayer(frame.unit)) and classColor and frame.optionTable.useClassColors ) then
                -- Use class colors for players if class color option is turned on
                r, g, b = classColor.r, classColor.g, classColor.b;
            elseif ( CompactUnitFrame_IsTapDenied(frame) ) then
                -- Use grey if not a player and can't get tap on unit
                r, g, b = 0.9, 0.9, 0.9;
            elseif ( frame.optionTable.colorHealthBySelection ) then
                -- Use color based on the type of unit (neutral, etc.)
                --[[if ( frame.optionTable.considerSelectionInCombatAsHostile and CompactUnitFrame_IsPlayerAttacking(frame.displayedUnit)) then
                    r, g, b = 1.0, 0.0, 0.0;
                else]]
                    r, g, b = UnitSelectionColor(frame.unit, frame.optionTable.colorHealthWithExtendedColors);
                --end
            elseif ( UnitIsFriend("player", frame.unit) ) then
                r, g, b = 0.0, 1.0, 0.0;
            else
                r, g, b = 1.0, 0.0, 0.0;
            end
        end
    end

    local oldR, oldG, oldB = frame.healthBar:GetStatusBarColor();
    if ( r ~= oldR or g ~= oldG or b ~= oldB ) then
        frame.healthBar:SetStatusBarColor(r, g, b);

        if (frame.optionTable.colorHealthWithExtendedColors) then
            frame.ignoreParentAlpha.selectionHighlight:SetVertexColor(r, g, b);
        else
            frame.ignoreParentAlpha.selectionHighlight:SetVertexColor(1, 1, 1);
        end
    end
end

function CompactUnitFrame_UpdateMaxHealth(frame)
    local maxHealth = UnitHealthMax(frame.displayedUnit);

    if ( maxHealth == 0 ) then
        maxHealth = .1;
    end

    if ( frame.optionTable.smoothHealthUpdates ) then
        frame.healthBar:SetMinMaxSmoothedValue(0, maxHealth);
    else
        frame.healthBar:SetMinMaxValues(0, maxHealth);
    end
end

function CompactUnitFrame_UpdateHealth(frame)
    local health = UnitHealth(frame.displayedUnit);

    if ( health == 0 and not UnitIsConnected(frame.displayedUnit) ) then
        health = .1;
    end

    if ( frame.optionTable.smoothHealthUpdates ) then
        if ( frame.newUnit ) then
            frame.healthBar:ResetSmoothedValue(health);
            frame.newUnit = false;
        else
            frame.healthBar:SetSmoothedValue(health);
        end
    else
        frame.healthBar:SetValue(health);
    end
end

local function CompactUnitFrame_GetDisplayedPowerID(frame)
    return (UnitPowerType(frame.displayedUnit));
end

function CompactUnitFrame_UpdateMaxPower(frame)
    if frame.powerBar then
        local maxPower = UnitPowerMax(frame.displayedUnit, CompactUnitFrame_GetDisplayedPowerID(frame));

        if ( maxPower == 0 ) then
            maxPower = .1;
        end

        frame.powerBar:SetMinMaxValues(0, maxPower);
    end
end

function CompactUnitFrame_UpdatePower(frame)
    if frame.powerBar then
        local power = UnitPower(frame.displayedUnit, CompactUnitFrame_GetDisplayedPowerID(frame))

        if ( power == 0 and not UnitIsConnected(frame.displayedUnit) ) then
            power = .1;
        end

        frame.powerBar:SetValue(power);
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
        local powerType, powerToken, altR, altG, altB = UnitPowerType(frame.displayedUnit);
        local prefix = _G[powerToken];
        local info = PowerBarColor[powerToken];
        if ( info ) then
                r, g, b = info.r, info.g, info.b;
        else
            if ( not altR) then
                -- couldn't find a power token entry...default to indexing by power type or just mana if we don't have that either
                info = PowerBarColor[powerType] or PowerBarColor["MANA"];
                r, g, b = info.r, info.g, info.b;
            else
                r, g, b = altR, altG, altB;
            end
        end
    end
    frame.powerBar:SetStatusBarColor(r, g, b);
end

function ShouldShowName(frame)
    if ( frame.optionTable.displayName ) then
        local failedRequirement = false;
        if ( frame.optionTable.displayNameByPlayerNameRules ) then
            if ( UnitShouldDisplayName(frame.unit) ) then
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

function CompactUnitFrame_UpdateName(frame)
    if frame.UpdateNameOverride and frame:UpdateNameOverride() then
        return;
    end

    if ( not ShouldShowName(frame) ) then
        frame.name:Hide();
    else
        local name = GetUnitName(frame.unit, true);
        if ( false and name ) then -- C_Commentator.IsSpectating()
            local overrideName = nil -- C_Commentator.GetPlayerOverrideName(name);
            if overrideName then
                name = overrideName;
            end
        end

        frame.name:SetText(name);

        if ( CompactUnitFrame_IsTapDenied(frame) ) then
            -- Use grey if not a player and can't get tap on unit
            frame.name:SetVertexColor(0.5, 0.5, 0.5);
        elseif ( frame.optionTable.colorNameBySelection ) then
            --[[if ( frame.optionTable.considerSelectionInCombatAsHostile and CompactUnitFrame_IsPlayerAttacking(frame.displayedUnit)) then
                frame.name:SetVertexColor(1.0, 0.0, 0.0);
            else]]
                frame.name:SetVertexColor(UnitSelectionColor(frame.unit, frame.optionTable.colorNameWithExtendedColors));
            --end
        else
            -- If not coloring by selection, then default to white.
            frame.name:SetVertexColor(1.0, 1.0, 1.0);
        end

        frame.name:Show();
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
    if ( not frame.aggroHighlight ) then
        return;
    end
    if ( not frame.optionTable.displayAggroHighlight ) then
        if ( not frame.optionTable.playLoseAggroHighlight ) then
           frame.aggroHighlight:Hide();
        end
        return;
    end

    local status = UnitThreatSituation(frame.displayedUnit);
    if ( status and status > 0 ) then
        frame.aggroHighlight:SetVertexColor(GetThreatStatusColor(status));
        frame.aggroHighlight:Show();
    else
        frame.aggroHighlight:Hide();
    end
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

    -- Locked target outline
    if frame.optionTable.selectedBorderColor and UnitIsUnit(frame.displayedUnit, "target") then
        SetBorderColor(frame, frame.optionTable.selectedBorderColor:GetRGBA());
        return;
    end

    if frame.optionTable.defaultBorderColor then
        SetBorderColor(frame, frame.optionTable.defaultBorderColor:GetRGBA());
        return;
    end
end

function CompactUnitFrame_UpdateInRange(frame)
    if ( not frame.optionTable.fadeOutOfRange ) then
        return;
    end

    local inRange, checkedRange = UnitInRange(frame.displayedUnit); --If we weren't able to check the range for some reason, we'll just treat them as in-range (for example, enemy units)
    if ( checkedRange and not inRange ) then
        frame.healthBar:SetAlpha(0.55);
    else
        frame.healthBar:SetAlpha(1);
    end
end

function CompactUnitFrame_UpdateDistance(frame)
    local distance, checkedDistance = UnitDistanceSquared(frame.displayedUnit);

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

--WARNING: This function is very similar to the function UnitFrameHealPredictionBars_Update in UnitFrame.lua.
--If you are making changes here, it is possible you may want to make changes there as well.
local MAX_INCOMING_HEAL_OVERFLOW = 1.05;
function CompactUnitFrame_UpdateHealPrediction(frame)
    local _, maxHealth = frame.healthBar:GetMinMaxValues();
    local health = frame.healthBar:GetValue();

    if ( maxHealth <= 0 ) then
        return;
    end

    if ( not frame.optionTable.displayHealPrediction ) then
        frame.myHealPrediction:Hide();
        frame.otherHealPrediction:Hide();
        frame.totalAbsorb:Hide();
        frame.totalAbsorbOverlay:Hide();
        frame.overAbsorbGlow:Hide();
        frame.myHealAbsorb:Hide();
        frame.myHealAbsorbLeftShadow:Hide();
        frame.myHealAbsorbRightShadow:Hide();
        frame.overHealAbsorbGlow:Hide();
        return;
    end

    local myIncomingHeal = UnitGetIncomingHeals(frame.displayedUnit, "player") or 0;
    local allIncomingHeal = UnitGetIncomingHeals(frame.displayedUnit) or 0;
    local totalAbsorb = UnitGetTotalAbsorbs(frame.displayedUnit) or 0;

    if ( totalAbsorb < 0 ) then
        totalAbsorb = 0; -- BugFix (3.3.5a): TexCoord out of range (AbsorbMonitor-1.0)
    end

    --We don't fill outside the health bar with healAbsorbs.  Instead, an overHealAbsorbGlow is shown.
    local myCurrentHealAbsorb = UnitGetTotalHealAbsorbs(frame.displayedUnit) or 0;
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
        bar.overlay:SetTexCoord(0, barSize / bar.overlay.tileSize, 0, totalHeight / bar.overlay.tileSize);
        bar.overlay:Show();
    end
    return bar;
end

function CompactUnitFrame_UpdateRoleIcon(frame)
    if frame.onUpdateFrame or not ( frame.roleIcon and frame.unit ) then
        return;
    end

    local size = frame.roleIcon:GetHeight(); --We keep the height so that it carries from the set up, but we decrease the width to 1 to allow room for things anchored to the role (e.g. name).
    if ( UnitInVehicle(frame.unit) and UnitHasVehicleUI(frame.unit) ) then
        frame.roleIcon:SetTexture("Interface\\Vehicles\\UI-Vehicles-Raid-Icon");
        frame.roleIcon:SetTexCoord(0, 1, 0, 1);
        frame.roleIcon:Show();
        frame.roleIcon:SetSize(size, size);
    else
        local raidRoleIcon = frame.optionTable.displayRaidRoleIcon;
        local raidID = (raidRoleIcon) and UnitInRaid(frame.unit);
        local role = (raidID) and select(10, GetRaidRosterInfo(raidID+1));
        if ( role ) then
            frame.roleIcon:SetTexture("Interface\\GroupFrame\\UI-Group-"..role.."Icon");
            frame.roleIcon:SetTexCoord(0, 1, 0, 1);
            frame.roleIcon:Show();
            frame.roleIcon:SetSize(size, size);
        else
            local role = UnitGroupRolesAssigned(frame.unit);
            if ( frame.optionTable.displayRoleIcon and (role == "TANK" or role == "HEALER" or role == "DAMAGER") ) then
                frame.roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES");
                frame.roleIcon:SetTexCoord(GetTexCoordsForRoleSmallCircle(role));
                frame.roleIcon:Show();
                frame.roleIcon:SetSize(size, size);
            else
                frame.roleIcon:Hide();
                frame.roleIcon:SetSize(1, size);
            end
        end
    end
end

function CompactUnitFrame_UpdateReadyCheck(frame)
    if ( not frame.ignoreParentAlpha.readyCheckIcon or frame.optionTable.hideReadyCheckIcon or frame.readyCheckDecay and GetReadyCheckTimeLeft() <= 0 ) then
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
    if ( not frame.ignoreParentAlpha.readyCheckIcon or frame.optionTable.hideReadyCheckIcon )  then
        return;
    end
    if ( frame:IsVisible() ) then
        frame.readyCheckDecay = CUF_READY_CHECK_DECAY_TIME;
        CompactUnitFrame_CheckNeedsUpdate(frame);

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
        if ( frame.optionTable.displayInOtherGroup and UnitInOtherParty(frame.unit) ) then
            frame.centerStatusIcon.texture:SetTexture("Interface\\LFGFrame\\LFG-Eye");
            frame.centerStatusIcon.texture:SetTexCoord(0.125, 0.25, 0.25, 0.5);
            frame.centerStatusIcon.border:SetTexture("Interface\\Common\\RingBorder");
            frame.centerStatusIcon.border:Show();
            frame.centerStatusIcon.tooltip = PARTY_IN_PUBLIC_GROUP_MESSAGE;
            frame.centerStatusIcon:Show();
        elseif ( frame.optionTable.displayIncomingResurrect and UnitHasIncomingResurrection(frame.unit) ) then
            frame.centerStatusIcon.texture:SetTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Raid-Icon-Rez");
            frame.centerStatusIcon.texture:SetTexCoord(0, 1, 0, 1);
            frame.centerStatusIcon.border:Hide();
            frame.centerStatusIcon.tooltip = nil;
            frame.centerStatusIcon:Show();
        elseif ( frame.optionTable.displayInOtherPhase and frame.inDistance and (not UnitInPhase(frame.unit)) ) then
            frame.centerStatusIcon.texture:SetTexture("Interface\\LFGFrame\\LFG-Eye");
            frame.centerStatusIcon.texture:SetTexCoord(0.125, 0.25, 0.25, 0.5);
            frame.centerStatusIcon.border:Show();
            frame.centerStatusIcon.tooltip = PARTY_PHASED_MESSAGE;
            frame.centerStatusIcon:Show();
        else
            frame.centerStatusIcon:Hide();
        end
    end
end

--Other internal functions
function CompactUnitFrame_UpdateAuras(frame)
    if ( not frame.onUpdateFrame ) then
        CompactUnitFrame_UpdateBuffs(frame);
        CompactUnitFrame_UpdateDebuffs(frame);
        CompactUnitFrame_UpdateDispellableDebuffs(frame);
    end
end

function CompactUnitFrame_UpdateBuffs(frame)
    if ( not frame.buffFrames or not frame.optionTable.displayBuffs ) then
        CompactUnitFrame_HideAllBuffs(frame);
        return;
    end

    local index = 1;
    local frameNum = 1;
    local filter = nil;
    while ( frameNum <= frame.maxBuffs ) do
        local buffName = UnitBuff(frame.displayedUnit, index, filter);
        if ( buffName ) then
            if ( CompactUnitFrame_UtilShouldDisplayBuff(frame.displayedUnit, index, filter) and not CompactUnitFrame_UtilIsBossAura(frame.displayedUnit, index, filter, true) ) then
                local buffFrame = frame.buffFrames[frameNum];
                CompactUnitFrame_UtilSetBuff(buffFrame, frame.displayedUnit, index, filter);
                frameNum = frameNum + 1;
            end
        else
            break;
        end
        index = index + 1;
    end
    for i=frameNum, frame.maxBuffs do
        local buffFrame = frame.buffFrames[i];
        buffFrame:Hide();
    end
end

function CompactUnitFrame_UpdateDebuffs(frame)
    if ( not frame.debuffFrames or not frame.optionTable.displayDebuffs ) then
        CompactUnitFrame_HideAllDebuffs(frame);
        return;
    end

    local index = 1;
    local frameNum = 1;
    local filter = nil;
    local maxDebuffs = frame.maxDebuffs;
--[[
    --Show both Boss buffs & debuffs in the debuff location
    --First, we go through all the debuffs looking for any boss flagged ones.
    while ( frameNum <= maxDebuffs ) do
        local debuffName = UnitDebuff(frame.displayedUnit, index, filter);
        if ( debuffName ) then
            if ( CompactUnitFrame_UtilIsBossAura(frame.displayedUnit, index, filter, false) ) then
                local debuffFrame = frame.debuffFrames[frameNum];
                CompactUnitFrame_UtilSetDebuff(debuffFrame, frame.displayedUnit, index, filter, true, false);
                frameNum = frameNum + 1;
                --Boss debuffs are about twice as big as normal debuffs, so display one less.
                local bossDebuffScale = (debuffFrame.baseSize + BOSS_DEBUFF_SIZE_INCREASE)/debuffFrame.baseSize
                maxDebuffs = maxDebuffs - (bossDebuffScale - 1);
            end
        else
            break;
        end
        index = index + 1;
    end

    --Then we go through all the buffs looking for any boss flagged ones.
    index = 1;
    while ( frameNum <= maxDebuffs ) do
        local debuffName = UnitBuff(frame.displayedUnit, index, filter);
        if ( debuffName ) then
            if ( CompactUnitFrame_UtilIsBossAura(frame.displayedUnit, index, filter, true) ) then
                local debuffFrame = frame.debuffFrames[frameNum];
                CompactUnitFrame_UtilSetDebuff(debuffFrame, frame.displayedUnit, index, filter, true, true);
                frameNum = frameNum + 1;
                --Boss debuffs are about twice as big as normal debuffs, so display one less.
                local bossDebuffScale = (debuffFrame.baseSize + BOSS_DEBUFF_SIZE_INCREASE)/debuffFrame.baseSize
                maxDebuffs = maxDebuffs - (bossDebuffScale - 1);
            end
        else
            break;
        end
        index = index + 1;
    end
]]
    --Now we go through the debuffs with a priority (e.g. Weakened Soul and Forbearance)
    index = 1;
    while ( frameNum <= maxDebuffs ) do
        local debuffName = UnitDebuff(frame.displayedUnit, index, filter);
        if ( debuffName ) then
            if ( CompactUnitFrame_UtilIsPriorityDebuff(frame.displayedUnit, index, filter) ) then
                local debuffFrame = frame.debuffFrames[frameNum];
                CompactUnitFrame_UtilSetDebuff(debuffFrame, frame.displayedUnit, index, filter, false, false);
                frameNum = frameNum + 1;
            end
        else
            break;
        end
        index = index + 1;
    end

    if ( frame.optionTable.displayOnlyDispellableDebuffs ) then
        filter = "RAID";
    end

    index = 1;
    --Now, we display all normal debuffs.
    if ( frame.optionTable.displayNonBossDebuffs ) then
        while ( frameNum <= maxDebuffs ) do
            local debuffName = UnitDebuff(frame.displayedUnit, index, filter);
            if ( debuffName ) then
                if ( CompactUnitFrame_UtilShouldDisplayDebuff(frame.displayedUnit, index, filter) and not CompactUnitFrame_UtilIsBossAura(frame.displayedUnit, index, filter, false) and
                    not CompactUnitFrame_UtilIsPriorityDebuff(frame.displayedUnit, index, filter)) then
                    local debuffFrame = frame.debuffFrames[frameNum];
                    CompactUnitFrame_UtilSetDebuff(debuffFrame, frame.displayedUnit, index, filter, false, false);
                    frameNum = frameNum + 1;
                end
            else
                break;
            end
            index = index + 1;
        end
    end

    for i=frameNum, frame.maxDebuffs do
        local debuffFrame = frame.debuffFrames[i];
        debuffFrame:Hide();
    end
end

local dispellableDebuffTypes = { Magic = true, Curse = true, Disease = true, Poison = true};
function CompactUnitFrame_UpdateDispellableDebuffs(frame)
    if ( not frame.dispelDebuffFrames or not frame.optionTable.displayDispelDebuffs ) then
        CompactUnitFrame_HideAllDispelDebuffs(frame);
        return;
    end

    --Clear what we currently have.
    for debuffType, display in pairs(dispellableDebuffTypes) do
        if ( display ) then
            frame["hasDispel"..debuffType] = false;
        end
    end

    local index = 1;
    local frameNum = 1;
    local filter = "RAID";  --Only dispellable debuffs.
    while ( frameNum <= frame.maxDispelDebuffs ) do
        local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId = UnitDebuff(frame.displayedUnit, index, filter);
        if ( dispellableDebuffTypes[debuffType] and not frame["hasDispel"..debuffType] ) then
            frame["hasDispel"..debuffType] = true;
            local dispellDebuffFrame = frame.dispelDebuffFrames[frameNum];
            CompactUnitFrame_UtilSetDispelDebuff(dispellDebuffFrame, debuffType, index)
            frameNum = frameNum + 1;
        elseif ( not name ) then
            break;
        end
        index = index + 1;
    end
    for i=frameNum, frame.maxDispelDebuffs do
        local dispellDebuffFrame = frame.dispelDebuffFrames[i];
        dispellDebuffFrame:Hide();
    end
end

--Utility Functions
function CompactUnitFrame_UtilShouldDisplayBuff(unit, index, filter)
    local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId = UnitBuff(unit, index, filter);

    local hasCustom, alwaysShowMine, showForMySpec = SpellGetVisibilityInfo(spellId, UnitAffectingCombat("player") and "RAID_INCOMBAT" or "RAID_OUTOFCOMBAT");

    if ( hasCustom ) then
        return showForMySpec or (alwaysShowMine and (unitCaster == "player" or unitCaster == "pet" or unitCaster == "vehicle"));
    else
        local selfBuff, canApplyAura = SpellIsSelfBuff(spellId)
        return (unitCaster == "player" or unitCaster == "pet" or unitCaster == "vehicle") and canApplyAura and not selfBuff;
    end
end

function CompactUnitFrame_HideAllBuffs(frame)
    if frame.buffFrames then
        for i=1, #frame.buffFrames do
            frame.buffFrames[i]:Hide();
        end
    end
end

function CompactUnitFrame_UpdateCooldownFrame(frame, expirationTime, duration)
    local enabled = expirationTime and expirationTime ~= 0;
    if enabled then
        local startTime = expirationTime - duration;
        CooldownFrame_Set(frame.cooldown, startTime, duration, true);
    else
        CooldownFrame_Clear(frame.cooldown);
    end
end

function CompactUnitFrame_UtilSetBuff(buffFrame, unit, index, filter)
    local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId, canApplyAura = UnitBuff(unit, index, filter);
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
    CompactUnitFrame_UpdateCooldownFrame(buffFrame, expirationTime, duration);
    buffFrame:Show();
end

function CompactUnitFrame_UtilShouldDisplayDebuff(unit, index, filter)
    local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId, canApplyAura, isBossAura = UnitDebuff(unit, index, filter);

    local hasCustom, alwaysShowMine, showForMySpec = SpellGetVisibilityInfo(spellId, UnitAffectingCombat("player") and "RAID_INCOMBAT" or "RAID_OUTOFCOMBAT");
    if ( hasCustom ) then
        return showForMySpec or (alwaysShowMine and (unitCaster == "player" or unitCaster == "pet" or unitCaster == "vehicle") );   --Would only be "mine" in the case of something like forbearance.
    else
        return true;
    end
end

function CompactUnitFrame_UtilIsBossAura(unit, index, filter, checkAsBuff)
    -- make sure you are using the correct index here!  allAurasIndex ~= debuffIndex
    local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId, canApplyAura, isBossAura;
    --[[if (checkAsBuff) then
        name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId, canApplyAura, isBossAura = UnitBuff(unit, index, filter);
        return (spellId == 23333 or spellId == 23335 or spellId == 34976); -- PvP Flags
    else
        -- name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId, canApplyAura, isBossAura = UnitDebuff(unit, index, filter);
    end]]
    return isBossAura;
end

function CompactUnitFrame_UtilIsPriorityDebuff(unit, index, filter)
    local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId, canApplyAura, isBossDebuff = UnitDebuff(unit, index, filter);

    if ( playerClassFilename == "PALADIN" ) then
        if ( spellId == 25771 ) then  --Forbearance
            return true;
        end
    elseif ( playerClassFilename == "PRIEST" ) then
        if ( spellId == 6788 ) then --Weakened Soul
        return true;
        end
    end

    return false;
end

function CompactUnitFrame_HideAllDebuffs(frame)
    if frame.debuffFrames then
        for i=1, #frame.debuffFrames do
            frame.debuffFrames[i]:Hide();
        end
    end
end

function CompactUnitFrame_UtilSetDebuff(debuffFrame, unit, index, filter, isBossAura, isBossBuff)
    -- make sure you are using the correct index here!
    --isBossAura says make this look large.
    --isBossBuff looks in HELPFULL auras otherwise it looks in HARMFULL ones
    local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId;
    if (isBossBuff) then
        name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId = UnitBuff(unit, index, filter);
    else
        name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId = UnitDebuff(unit, index, filter);
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
    CompactUnitFrame_UpdateCooldownFrame(debuffFrame, expirationTime, duration);

    local color = DebuffTypeColor[debuffType] or DebuffTypeColor["none"];
    debuffFrame.border:SetVertexColor(color.r, color.g, color.b);

    debuffFrame.isBossBuff = isBossBuff;
    if ( isBossAura ) then
        local size = min(debuffFrame.baseSize + BOSS_DEBUFF_SIZE_INCREASE, debuffFrame.maxHeight);
        debuffFrame:SetSize(size, size);
    else
        debuffFrame:SetSize(debuffFrame.baseSize, debuffFrame.baseSize);
    end

    debuffFrame:Show();
end

function CompactUnitFrame_UtilSetDispelDebuff(dispellDebuffFrame, debuffType, index)
    dispellDebuffFrame:Show();
    dispellDebuffFrame.icon:SetTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Raid-Icon-Debuff"..debuffType);
    dispellDebuffFrame:SetID(index);
end

function CompactUnitFrame_HideAllDispelDebuffs(frame)
    if frame.dispelDebuffFrames then
        for i=1, #frame.dispelDebuffFrames do
            frame.dispelDebuffFrames[i]:Hide();
        end
    end
end

--Dropdown
local secureFocus
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
        secureFocus = true;
        UnitPopup_ShowMenu(self, menu, unit, name, id);
        secureFocus = nil;
    end
end

local function CompactUnitFrameDropDown_SecureFocus()
    if ( secureFocus ) then
        local menuActive = UnitPopupMenus[UIDROPDOWNMENU_INIT_MENU.which];
        local menuShown = UnitPopupShown[1]
        for i=1,#menuActive do
            local value = menuActive[i];
            if ( value == "SET_FOCUS" and menuShown[i] == 1 ) then
                UnitPopupShown[1][i] = 0;
                break
            end
        end
    end
end
hooksecurefunc("UnitPopup_HideButtons", CompactUnitFrameDropDown_SecureFocus)

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
    displayRoleIcon = true,
    displayRaidRoleIcon = true,
    displayDispelDebuffs = true,
    displayBuffs = true,
    displayDebuffs = true,
    displayOnlyDispellableDebuffs = false,
    displayNonBossDebuffs = true,
    healthText = "none",
    displayIncomingResurrect = true,
    displayInOtherGroup = false,
    displayInOtherPhase = false,
    displayReadyCheck = true,

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

    frame.background:SetTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Raid-Bar-Hp-Bg");
    frame.background:SetTexCoord(0, 1, 0, 0.53125);
    frame.healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1);
    frame.healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1 + powerBarUsedHeight);
    frame.healthBar:SetStatusBarTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Raid-Bar-Hp-Fill", "BORDER");
    frame.healthBar:SetFrameLevel(frame:GetFrameLevel());

    if ( frame.powerBar ) then
        if ( options.displayPowerBar ) then
            if ( options.displayBorder ) then
                frame.powerBar:SetPoint("TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, -2);
            else
                frame.powerBar:SetPoint("TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, 0);
            end
            frame.powerBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1);
            frame.powerBar:SetStatusBarTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Raid-Bar-Resource-Fill", "BORDER");
            frame.powerBar.background:SetTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Raid-Bar-Resource-Background");
            frame.powerBar:Show();
            frame.powerBar:SetParent(frame.healthBar);
        else
            frame.powerBar:Hide();
        end
    end

    frame.myHealPrediction:ClearAllPoints();
    frame.myHealPrediction:SetTexture(1,1,1);
    frame.myHealPrediction:SetGradient("VERTICAL", 8/255, 93/255, 72/255, 11/255, 136/255, 105/255);
    frame.myHealAbsorb:ClearAllPoints();
    frame.myHealAbsorb:SetTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Absorb-Fill", true, true);
    frame.myHealAbsorbLeftShadow:ClearAllPoints();
    frame.myHealAbsorbRightShadow:ClearAllPoints();
    frame.otherHealPrediction:ClearAllPoints();
    frame.otherHealPrediction:SetTexture(1,1,1);
    frame.otherHealPrediction:SetGradient("VERTICAL", 11/255, 53/255, 43/255, 21/255, 89/255, 72/255);
    frame.totalAbsorb:ClearAllPoints();
    frame.totalAbsorb:SetTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Shield-Fill");
    frame.totalAbsorb.overlay = frame.totalAbsorbOverlay;
    frame.totalAbsorbOverlay:SetTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Shield-Overlay", true, true);    --Tile both vertically and horizontally
    frame.totalAbsorbOverlay:SetAllPoints(frame.totalAbsorb);
    frame.totalAbsorbOverlay.tileSize = 32;
    frame.overAbsorbGlow:ClearAllPoints();
    frame.overAbsorbGlow:SetTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Shield-Overshield");
    frame.overAbsorbGlow:SetBlendMode("ADD");
    frame.overAbsorbGlow:SetPoint("BOTTOMLEFT", frame.healthBar, "BOTTOMRIGHT", -7, 0);
    frame.overAbsorbGlow:SetPoint("TOPLEFT", frame.healthBar, "TOPRIGHT", -7, 0);
    frame.overAbsorbGlow:SetWidth(16);
    frame.overHealAbsorbGlow:ClearAllPoints();
    frame.overHealAbsorbGlow:SetTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Absorb-Overabsorb");
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
    CompactUnitFrame_SetMaxDispelDebuffs(frame, 3);

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
        frame.buffFrames[i]:SetFrameLevel(9);
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
        frame.debuffFrames[i]:SetFrameLevel(9);
    end

    frame.dispelDebuffFrames[1]:SetPoint("TOPRIGHT", -3, -2);
    for i=1, #frame.dispelDebuffFrames do
        if ( i > 1 ) then
            frame.dispelDebuffFrames[i]:SetPoint("RIGHT", frame.dispelDebuffFrames[i - 1], "LEFT", 0, 0);
        end
        frame.dispelDebuffFrames[i]:SetSize(12, 12);
        frame.dispelDebuffFrames[i]:SetParent(frame.healthBar);
    end

    frame.ignoreParentAlpha.selectionHighlight:SetTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Raid-FrameHighlights");
    frame.ignoreParentAlpha.selectionHighlight:SetTexCoord(unpack(texCoords["Raid-TargetFrame"]));
    frame.ignoreParentAlpha.selectionHighlight:SetAllPoints(frame);

    frame.aggroHighlight:SetTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Raid-FrameHighlights");
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
        frame.horizTopBorder:SetTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Raid-HSeparator");
        frame.horizTopBorder:SetHeight(8);
        frame.horizTopBorder:Show();

        frame.horizBottomBorder:ClearAllPoints();
        frame.horizBottomBorder:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 1);
        frame.horizBottomBorder:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, 1);
        frame.horizBottomBorder:SetTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Raid-HSeparator");
        frame.horizBottomBorder:SetHeight(8);
        frame.horizBottomBorder:Show();

        frame.vertLeftBorder:ClearAllPoints();
        frame.vertLeftBorder:SetPoint("TOPRIGHT", frame, "TOPLEFT", 7, 0);
        frame.vertLeftBorder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 7, 0);
        frame.vertLeftBorder:SetTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Raid-VSeparator");
        frame.vertLeftBorder:SetWidth(8);
        frame.vertLeftBorder:Show();

        frame.vertRightBorder:ClearAllPoints();
        frame.vertRightBorder:SetPoint("TOPLEFT", frame, "TOPRIGHT", -1, 0);
        frame.vertRightBorder:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", -1, 0);
        frame.vertRightBorder:SetTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Raid-VSeparator");
        frame.vertRightBorder:SetWidth(8);
        frame.vertRightBorder:Show();

        if ( options.displayPowerBar ) then
            frame.horizDivider:ClearAllPoints();
            frame.horizDivider:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 1 + powerBarUsedHeight);
            frame.horizDivider:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, 1 + powerBarUsedHeight);
            frame.horizDivider:SetTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Raid-HSeparator");
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
end

DefaultCompactMiniFrameOptions = {
    displaySelectionHighlight = true,
    displayAggroHighlight = true,
    displayName = true,
    fadeOutOfRange = true,
    --displayStatusText = true,
    --displayDispelDebuffs = true,
    displayReadyCheck = false,
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
    frame.background:SetTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Raid-Bar-Hp-Bg");
    frame.background:SetTexCoord(0, 1, 0, 0.53125);
    frame.healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1);
    frame.healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1);
    frame.healthBar:SetStatusBarTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Raid-Bar-Hp-Fill", "BORDER");
    frame.healthBar:SetFrameLevel(frame:GetFrameLevel());

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

    frame.myHealPrediction:ClearAllPoints();
    frame.myHealPrediction:SetTexture(1,1,1);
    frame.myHealPrediction:SetGradient("VERTICAL", 8/255, 93/255, 72/255, 11/255, 136/255, 105/255);
    frame.myHealAbsorb:ClearAllPoints();
    frame.myHealAbsorb:SetTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Absorb-Fill", true, true);
    frame.myHealAbsorbLeftShadow:ClearAllPoints();
    frame.myHealAbsorbRightShadow:ClearAllPoints();
    frame.otherHealPrediction:ClearAllPoints();
    frame.otherHealPrediction:SetTexture(1,1,1);
    frame.otherHealPrediction:SetGradient("VERTICAL", 3/255, 72/255, 5/255, 2/255, 101/255, 18/255);
    frame.totalAbsorb:ClearAllPoints();
    frame.totalAbsorb:SetTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Shield-Fill");
    frame.totalAbsorb.overlay = frame.totalAbsorbOverlay;
    frame.totalAbsorbOverlay:SetTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Shield-Overlay", true, true);    --Tile both vertically and horizontally
    frame.totalAbsorbOverlay:SetAllPoints(frame.totalAbsorb);
    frame.totalAbsorbOverlay.tileSize = 32;
    frame.overAbsorbGlow:ClearAllPoints();
    frame.overAbsorbGlow:SetTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Shield-Overshield");
    frame.overAbsorbGlow:SetBlendMode("ADD");
    frame.overAbsorbGlow:SetPoint("BOTTOMLEFT", frame.healthBar, "BOTTOMRIGHT", -7, 0);
    frame.overAbsorbGlow:SetPoint("TOPLEFT", frame.healthBar, "TOPRIGHT", -7, 0);
    frame.overAbsorbGlow:SetWidth(16);
    frame.overHealAbsorbGlow:ClearAllPoints();
    frame.overHealAbsorbGlow:SetTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Absorb-Overabsorb");
    frame.overHealAbsorbGlow:SetBlendMode("ADD");
    frame.overHealAbsorbGlow:SetPoint("BOTTOMRIGHT", frame.healthBar, "BOTTOMLEFT", 7, 0);
    frame.overHealAbsorbGlow:SetPoint("TOPRIGHT", frame.healthBar, "TOPLEFT", 7, 0);
    frame.overHealAbsorbGlow:SetWidth(16);

    frame.name:SetPoint("LEFT", 5, 1);
    frame.name:SetPoint("RIGHT", -3, 1);
    frame.name:SetHeight(12);
    frame.name:SetJustifyH("LEFT");

    frame.ignoreParentAlpha.selectionHighlight:SetTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Raid-FrameHighlights");
    frame.ignoreParentAlpha.selectionHighlight:SetTexCoord(unpack(texCoords["Raid-TargetFrame"]));
    frame.ignoreParentAlpha.selectionHighlight:SetAllPoints(frame);

    frame.aggroHighlight:SetTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Raid-FrameHighlights");
    frame.aggroHighlight:SetTexCoord(unpack(texCoords["Raid-AggroFrame"]));
    frame.aggroHighlight:SetAllPoints(frame);

    if ( options.displayBorder ) then
        frame.horizTopBorder:ClearAllPoints();
        frame.horizTopBorder:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, -7);
        frame.horizTopBorder:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, -7);
        frame.horizTopBorder:SetTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Raid-HSeparator");
        frame.horizTopBorder:SetHeight(8);
        frame.horizTopBorder:Show();

        frame.horizBottomBorder:ClearAllPoints();
        frame.horizBottomBorder:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 1);
        frame.horizBottomBorder:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, 1);
        frame.horizBottomBorder:SetTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Raid-HSeparator");
        frame.horizBottomBorder:SetHeight(8);
        frame.horizBottomBorder:Show();

        frame.vertLeftBorder:ClearAllPoints();
        frame.vertLeftBorder:SetPoint("TOPRIGHT", frame, "TOPLEFT", 7, 0);
        frame.vertLeftBorder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 7, 0);
        frame.vertLeftBorder:SetTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Raid-VSeparator");
        frame.vertLeftBorder:SetWidth(8);
        frame.vertLeftBorder:Show();

        frame.vertRightBorder:ClearAllPoints();
        frame.vertRightBorder:SetPoint("TOPLEFT", frame, "TOPRIGHT", -1, 0);
        frame.vertRightBorder:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", -1, 0);
        frame.vertRightBorder:SetTexture("Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\RaidFrame\\Raid-VSeparator");
        frame.vertRightBorder:SetWidth(8);
        frame.vertRightBorder:Show();
    else
        frame.horizTopBorder:Hide();
        frame.horizBottomBorder:Hide();
        frame.vertLeftBorder:Hide();
        frame.vertRightBorder:Hide();
    end

    CompactUnitFrame_SetOptionTable(frame, DefaultCompactMiniFrameOptions)
end

function CompactAuraTemplate_OnLeave(self)
    if ( self.icon or self.tooltip ) then
        GameTooltip:Hide();
    end
end
