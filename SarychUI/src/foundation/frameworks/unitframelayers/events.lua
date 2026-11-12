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
    local arenaIndex = unit:match("^arena(%d+)$")
    if arenaIndex then
        return _G["ArenaEnemyFrame" .. arenaIndex]
    end
    local n = unit:match("^party(%d+)$")
    if n then
        return _G["PartyMemberFrame"..n]
    end
    return _G[unit.."Frame"] -- запасной вариант, вдруг где-то совпадёт
end

local UFL = SarychUI.UnitFrameLayers
local IsEnabled = function() return UFL:IsEnabled() end
local RefreshUnitFrameLayers = function(...) return UFL.RefreshFrame(...) end
local UnitFrameLayers_HealthBar_OnUpdate = function(...) return UFL.UpdateHealthBar(...) end
local UnitFrameLayers_ManaBar_OnUpdate = function(...) return UFL.UpdateManaBar(...) end
local UnitFrameLayers_UpdatePredictionLevel = function(...) return UFL.UpdatePredictionLevel(...) end
local UnitFrameHealPredictionBars_Update = function(...) return UFL.UpdatePredictionBars(...) end
local UnitFrameLayers_UpdatePlayerPowerFXLevel = function(...) return UFL.UpdatePowerFXLevel(...) end
local ArenaTestIndex = UFL.ArenaTestIndex
local LibAbsorb = UFL.absorbMonitor
local HealComm = UFL.healComm

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
			UFL:Update(self);
		end
		return;
	end

	if ( event == "COMPACT_UNIT_FRAME_UNIT_AURA" and arg1 == guid ) then
		UFL:Update(self);
		return;
	end

	if ( arg5 == guid ) then
		if ( event == "HealComm_HealUpdated" or event == "HealComm_HealStarted" or
		   event == "HealComm_HealDelayed" or event == "HealComm_HealStopped" or
		   event == "HealComm_ModifierChanged" or event == "HealComm_GUIDDisappeared" ) then
			UFL:Update(self);
		end
		return;
	end

	if ( ... ) then
		for i = 1, select("#", ...) do
			if ( select(i, ...) == guid ) then
				if ( event == "HealComm_HealUpdated" or event == "HealComm_HealStarted" or
				   event == "HealComm_HealDelayed" or event == "HealComm_HealStopped" or
				   event == "HealComm_ModifierChanged" or event == "HealComm_GUIDDisappeared" ) then
					UFL:Update(self);
				end
				break;
			end
		end
	end
end

function UFL.RegisterLibraryCallbacks(self)
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


local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
frame:RegisterEvent("ARENA_OPPONENT_UPDATE")
frame:RegisterEvent("UNIT_NAME_UPDATE")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("UNIT_HEALTH")
frame:RegisterEvent("UNIT_MAXHEALTH")
frame:RegisterEvent("UNIT_MANA")
frame:RegisterEvent("UNIT_RAGE")
frame:RegisterEvent("UNIT_ENERGY")
frame:RegisterEvent("UNIT_RUNIC_POWER")
frame:RegisterEvent("UNIT_DISPLAYPOWER")
frame:RegisterEvent("UNIT_SPELLCAST_START")
frame:RegisterEvent("UNIT_SPELLCAST_STOP")
frame:RegisterEvent("UNIT_SPELLCAST_FAILED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

local healthColorPending = false
local healthColorAll = false
local healthColorUnits = {}
local layeredUnits = {"player", "target", "focus", "pet",
    "arena1", "arena2", "arena3", "arena4", "arena5"}
local colorUnits = {"player", "target", "focus", "pet", "party1", "party2", "party3", "party4",
    "arena1", "arena2", "arena3", "arena4", "arena5"}
local arenaPredictionElapsed = 0
local arenaTestLossElapsed = 0
local arenaTestHealthSamples = { 82, 61, 44, 77, 0 }
frame:SetScript("OnUpdate", function(_, elapsed)
	arenaPredictionElapsed = arenaPredictionElapsed + (elapsed or 0)
	arenaTestLossElapsed = arenaTestLossElapsed + (elapsed or 0)
	local refreshArenaPrediction = arenaPredictionElapsed >= 0.1
	if refreshArenaPrediction then arenaPredictionElapsed = 0 end
	if UFL.SyncResourcePredictionState then UFL:SyncResourcePredictionState() end
	-- Run the extra animation and prediction work from our own frame.  Blizzard
	-- keeps its original OnUpdate scripts on every protected unit button.
	if IsEnabled() then
		for _, unit in ipairs(layeredUnits) do
			local unitFrame = GetUnitFrameByUnit(unit)
			if unitFrame and unitFrame.IsVisible and not unitFrame:IsVisible() then
				if not unitFrame._uflVisualSuspended then
					unitFrame._uflVisualSuspended = true
					local health, power = unitFrame.healthbar, unitFrame.manabar
					if health then
						health._uflPrevHealth, health.currValue = nil, nil
						if health.AnimatedLossBar then health.AnimatedLossBar:CancelAnimation() end
					end
					if power then
						power._uflPrev, power.currValue = nil, nil
						if power.FeedbackFrame then power.FeedbackFrame:StopFeedbackAnim() end
					end
				end
			elseif unitFrame then
				if unitFrame._uflVisualSuspended then
					unitFrame._uflVisualSuspended = nil
					local health, power = unitFrame.healthbar, unitFrame.manabar
					-- Events can update cached values while hidden; start fresh on reveal.
					if health then health._uflPrevHealth, health.currValue = nil, nil end
					if power then power._uflPrev, power.currValue = nil, nil end
					RefreshUnitFrameLayers(unitFrame, "UFL_VISUAL_RESUME", unit)
				end
				local testIndex = unit:match("^arena%d+$") and ArenaTestIndex(unitFrame)
				if unit:match("^arena%d+$") and not unitFrame.myHealPredictionBar
					and not (InCombatLockdown and InCombatLockdown()) then
					RefreshUnitFrameLayers(unitFrame, "UFL_ARENA_SETUP", unit)
				end
				local healthbar = unitFrame.healthbar
				local loss = unitFrame.PlayerFrameHealthBarAnimatedLoss
				if healthbar and unit:match("^arena%d+$") and unitFrame._uflArenaTestIndex ~= testIndex then
					unitFrame._uflArenaTestIndex = testIndex
					healthbar._uflHealthGUID, healthbar._uflPrevHealth = nil, nil
					if loss then
						loss:CancelAnimation()
						loss:SetUnitHealthBar(testIndex == 1 and "player" or unit, healthbar)
						loss:UpdateHealthMinMax()
						loss:SetDuration(testIndex == 2 and 1.0 or 0.25)
						loss:SetStartDelay(testIndex == 2 and 0 or 0.1)
					end
				end
				if testIndex and testIndex > 1 and healthbar then
					-- Both arena styles show the fifth test opponent as dead.
					local sample = arenaTestHealthSamples[testIndex]
					healthbar:SetMinMaxValues(0, 100)
					healthbar:SetValue(sample)
					if loss then
						loss:SetMinMaxValues(0, 100)
						if testIndex == 2 then
							if arenaTestLossElapsed >= 3 then
								loss:UpdateHealth(sample, 100)
							end
							loss:UpdateLossAnimation(sample)
						end
					end
				end
				if healthbar and healthbar.unit then UnitFrameLayers_HealthBar_OnUpdate(healthbar, unitFrame) end
				if unitFrame.myHealPredictionBar then UnitFrameLayers_UpdatePredictionLevel(unitFrame) end
				if refreshArenaPrediction and unit:match("^arena%d+$") and unitFrame.myHealPredictionBar then
					UnitFrameHealPredictionBars_Update(unitFrame)
				end
				local manabar = unitFrame.manabar
				if manabar and manabar.unit then
					if unit == "player" then UnitFrameLayers_UpdatePlayerPowerFXLevel(manabar) end
					UnitFrameLayers_ManaBar_OnUpdate(manabar, unitFrame)
				end
			end
		end
		if arenaTestLossElapsed >= 3 then arenaTestLossElapsed = 0 end
	end
	if not healthColorPending then
		return
	end
	healthColorPending = false
	for _, u in ipairs(colorUnits) do
		if healthColorAll or healthColorUnits[u] then
			UpdateHealthBarColor(GetUnitFrameByUnit(u))
		end
		local n = u:match("^party(%d+)$")
		if n and (healthColorAll or healthColorUnits["partypet"..n]) then
			UpdateHealthBarColor(_G["PartyMemberFrame"..n.."PetFrame"])
		end
	end
	healthColorAll = false
	wipe(healthColorUnits)
end)

frame:SetScript("OnEvent", function(self, event, unit)
	if not IsEnabled() then
		return
	end
	healthColorPending = true
	local roster = event == "PLAYER_ENTERING_WORLD" or event == "PARTY_MEMBERS_CHANGED" or event == "GROUP_ROSTER_UPDATE"
		or event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED"
		or event == "ARENA_OPPONENT_UPDATE" or event == "PLAYER_REGEN_ENABLED"
	if roster or not unit then
		healthColorAll = true
	elseif not healthColorAll then
		for _, candidate in ipairs(colorUnits) do
			if candidate == unit or UnitIsUnit(candidate, unit) then healthColorUnits[candidate] = true end
			local n = candidate:match("^party(%d+)$")
			local pet = n and ("partypet" .. n)
			if pet and (pet == unit or UnitIsUnit(pet, unit)) then healthColorUnits[pet] = true end
		end
	end
	for registered, registeredUnit in pairs(UFL.frames) do
		if roster or registeredUnit == unit then
			if registered._suiLayerUpdater then
				UFL:Update(registered)
			elseif not registered.myHealPredictionBar and not (InCombatLockdown and InCombatLockdown()) then
				UFL:Register(registered, registeredUnit)
			else
				UFL:Update(registered)
			end
		end
	end
	if roster then
		if UFL.RefreshPartyOverlays then UFL:RefreshPartyOverlays() end
		for _, u in ipairs(colorUnits) do
			local f = GetUnitFrameByUnit(u)
			if f then
				RefreshUnitFrameLayers(f, event, u)
			end
		end
		local pf = PlayerFrame
		if pf and pf.manabar then
			UnitFrameManaBar_Update(pf.manabar, "player")
		end
	elseif unit then
		local f = GetUnitFrameByUnit(unit)
		if f then
			RefreshUnitFrameLayers(f, event, unit)
		end
		if unit == "player" then
			local pf = PlayerFrame
			if pf and pf.manabar then
				UnitFrameManaBar_Update(pf.manabar, "player")
			end
		end
	end
end)
