local BarVisibility = {}
_G.SarychUI_BarVisibility = BarVisibility

local managed = {
	{ name = "ShapeshiftBarFrame", group = "stance" },
	{ name = "SarychUI_DragonStanceBar", group = "stance" },
	{ name = "PetActionBarFrame", group = "pet" },
	{ name = "SarychUI_DragonPetBar", group = "pet" },
}

local auxiliaryFrames = {
	bags = {
		"MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot",
		"CharacterBag2Slot", "CharacterBag3Slot", "KeyRingButton",
	},
	micro = {
		"SarychUIMicroMenu", "CharacterMicroButton", "SpellbookMicroButton",
		"TalentMicroButton", "AchievementMicroButton", "QuestLogMicroButton",
		"SocialsMicroButton", "PVPMicroButton", "LFDMicroButton",
		"MainMenuMicroButton", "HelpMicroButton", "ParagonMicroButton",
		"CollectionsMicroButton", "StoreMicroButton",
	},
}

local state = {
	enabled = false,
	hidden = false,
	wantedHidden = false,
	selected = {},
	wasShown = {},
	wasAlpha = {},
	alphaHidden = {},
	guarded = {},
}

local function IsOn(value)
	return value == 1 or value == true
end

local function GetSettings(field)
	local profile = SarychUI and SarychUI.db and SarychUI.db.profile
	local db = profile and profile.modules and profile.modules.mainmenubar
	return db, db and db[field or "barVisibility"]
end

local function Guard(frame)
	if not frame or state.guarded[frame] then return end
	state.guarded[frame] = true
	frame:HookScript("OnShow", function(self)
		if state.hidden and state.selected[self] then
			if state.alphaHidden[self] then self:SetAlpha(0)
			else self:Hide() end
		end
	end)
end

local function Restore()
	if not state.hidden then return end
	local restoreStance, restorePet = false, false
	state.hidden = false
	for frame, group in pairs(state.selected) do
		if group == "stance" then restoreStance = true end
		if group == "pet" then restorePet = true end
		if state.alphaHidden[frame] then
			frame:SetAlpha(state.wasAlpha[frame] or 1)
		elseif state.wasShown[frame] then
			frame:Show()
		end
	end
	state.selected = {}
	state.wasShown = {}
	state.wasAlpha = {}
	state.alphaHidden = {}
	if (restoreStance or restorePet) and not (InCombatLockdown and InCombatLockdown()) then
		local module = SarychUI and SarychUI.modules and SarychUI.modules.mainmenubar
		local dragon = module and module.DragonStyle
		if dragon and dragon.active and dragon.UpdatePetAndStance then
			dragon:UpdatePetAndStance()
		else
			if restoreStance and _G.ShapeshiftBar_Update then
				_G.ShapeshiftBar_Update()
			end
			if restorePet and _G.PetActionBarFrame and _G.PetActionBar_Update then
				_G.PetActionBar_Update(_G.PetActionBarFrame)
				if _G.PetActionBarFrame.showgrid == 0 then
					if _G.PetHasActionBar and _G.PetHasActionBar()
						and _G.UnitIsVisible and _G.UnitIsVisible("pet") then
						if _G.ShowPetActionBar then _G.ShowPetActionBar(true) end
					else
						_G.PetActionBarFrame:Hide()
					end
				end
			end
		end
	end
end

local function SelectionMatches(settings)
	for _, entry in ipairs(managed) do
		local frame = _G[entry.name]
		if frame and (state.selected[frame] ~= nil) ~= IsOn(settings[entry.group]) then
			return false
		end
	end
	return true
end

local function Hide(settings)
	if state.hidden then return end
	state.selected = {}
	state.wasShown = {}
	state.wasAlpha = {}
	state.alphaHidden = {}
	for _, entry in ipairs(managed) do
		if IsOn(settings[entry.group]) then
			local frame = _G[entry.name]
			if frame then
				Guard(frame)
				state.selected[frame] = entry.group
				state.wasShown[frame] = frame:IsShown() and true or false
				if frame.IsProtected and frame:IsProtected() then
					state.alphaHidden[frame] = true
					state.wasAlpha[frame] = frame:GetAlpha()
				end
			end
		end
	end
	state.hidden = true
	for frame in pairs(state.selected) do
		if state.alphaHidden[frame] then frame:SetAlpha(0)
		else frame:Hide() end
	end
end

local function ApplyWanted()
	local _, settings = GetSettings()
	if state.wantedHidden and state.enabled and settings then
		if not state.hidden or not SelectionMatches(settings) then
			Restore()
			Hide(settings)
		else
			for frame in pairs(state.selected) do
				if state.alphaHidden[frame] then frame:SetAlpha(0)
				elseif frame:IsShown() then frame:Hide() end
			end
		end
	else
		Restore()
	end
end

function BarVisibility.Toggle(silent)
	if not state.enabled then return end
	state.wantedHidden = not state.wantedHidden
	ApplyWanted()
	local bindings = _G.SarychUI_ToggleBindings
	if bindings and bindings.SyncSecureHidden then
		bindings:SyncSecureHidden("bar_visibility", state.hidden)
	end
	local sound = state.wantedHidden and "igMiniMapZoomOut" or "igMiniMapZoomIn"
	if not silent and PlaySound then PlaySound(sound) end
	return sound
end

function BarVisibility.IsHidden()
	return state.hidden
end

local function CreateAuxiliaryVisibility(group, field, actionID)
	local frames = auxiliaryFrames[group]
	local aux = {
		enabled = false, hidden = false, wantedHidden = false,
		selected = {}, wasShown = {}, wasAlpha = {}, alphaHidden = {}, guarded = {},
	}

	local function GuardFrame(frame)
		if aux.guarded[frame] then return end
		aux.guarded[frame] = true
		frame:HookScript("OnShow", function(self)
			if aux.hidden and aux.selected[self] then
				if aux.alphaHidden[self] then self:SetAlpha(0)
				else self:Hide() end
			end
		end)
	end

	local function RestoreFrames()
		if not aux.hidden then return end
		aux.hidden = false
		for frame in pairs(aux.selected) do
			if aux.alphaHidden[frame] then
				frame:SetAlpha(aux.wasAlpha[frame] or 1)
			elseif aux.wasShown[frame] then
				frame:Show()
			end
		end
		aux.selected, aux.wasShown = {}, {}
		aux.wasAlpha, aux.alphaHidden = {}, {}
	end

	local function HideFrames()
		aux.selected, aux.wasShown = {}, {}
		aux.wasAlpha, aux.alphaHidden = {}, {}
		for _, name in ipairs(frames) do
			local frame = _G[name]
			if frame then
				GuardFrame(frame)
				aux.selected[frame] = true
				aux.wasShown[frame] = frame:IsShown() and true or false
				if frame.IsProtected and frame:IsProtected() then
					aux.alphaHidden[frame] = true
					aux.wasAlpha[frame] = frame:GetAlpha()
				end
			end
		end
		aux.hidden = true
		for frame in pairs(aux.selected) do
			if aux.alphaHidden[frame] then frame:SetAlpha(0)
			else frame:Hide() end
		end
	end

	function aux:ApplyWanted()
		if self.wantedHidden and self.enabled then
			if not self.hidden then HideFrames()
			else
				for frame in pairs(self.selected) do
					if self.alphaHidden[frame] then frame:SetAlpha(0)
					elseif frame:IsShown() then frame:Hide() end
				end
			end
		else
			RestoreFrames()
		end
	end

	function aux:Toggle(silent)
		if not self.enabled then return end
		self.wantedHidden = not self.wantedHidden
		self:ApplyWanted()
		local bindings = _G.SarychUI_ToggleBindings
		if bindings and bindings.SyncSecureHidden then
			bindings:SyncSecureHidden(actionID, self.hidden)
		end
		local sound = self.wantedHidden and "igMiniMapZoomOut" or "igMiniMapZoomIn"
		if not silent and PlaySound then PlaySound(sound) end
		return sound
	end

	function aux:ApplySettings()
		local db, settings = GetSettings(field)
		local bindings = _G.SarychUI_ToggleBindings
		local key = bindings and bindings:NormalizeKey(settings and settings.key)
		local extension = SarychUI.extensions and SarychUI.extensions.visibility_control
		self.enabled = (not extension or extension:IsEnabled())
			and db and IsOn(db.enabled) and settings and IsOn(settings.enabled) and key ~= nil
		if not self.enabled then self.wantedHidden = false end
		self:ApplyWanted()
		if not bindings then return end
		if self.enabled then
			bindings:SetAction(actionID, key, function() return self:Toggle(true) end)
			if bindings.SetSecureFrames then
				local secureFrames = {}
				for _, name in ipairs(frames) do
					local frame = _G[name]
					if frame and frame.IsProtected and frame:IsProtected() then
						secureFrames[#secureFrames + 1] = frame
					end
				end
				bindings:SetSecureFrames(actionID, secureFrames, self.hidden)
			end
		else
			bindings:RemoveAction(actionID)
		end
	end

	function aux:Disable()
		self.enabled, self.wantedHidden = false, false
		self:ApplyWanted()
		local bindings = _G.SarychUI_ToggleBindings
		if bindings then bindings:RemoveAction(actionID) end
	end

	return aux
end

local bagsVisibility = CreateAuxiliaryVisibility("bags", "bagsVisibility", "bags_visibility")
local microVisibility = CreateAuxiliaryVisibility("micro", "microVisibility", "micro_visibility")

function BarVisibility.IsGroupHidden(group)
	if group == "bags" then return bagsVisibility.hidden end
	if group == "micro" then return microVisibility.hidden end
	if not state.hidden then return false end
	for _, selectedGroup in pairs(state.selected) do
		if selectedGroup == group then return true end
	end
	return false
end

function BarVisibility.ApplySettings()
	local db, settings = GetSettings()
	local bindings = _G.SarychUI_ToggleBindings
	local key = bindings and bindings:NormalizeKey(settings and settings.key)
	local extension = SarychUI.extensions and SarychUI.extensions.visibility_control
	state.enabled = (not extension or extension:IsEnabled())
		and db and IsOn(db.enabled) and settings and IsOn(settings.enabled) and key ~= nil
	if not state.enabled then state.wantedHidden = false end
	ApplyWanted()
	if bindings then
		if state.enabled then
			bindings:SetAction("bar_visibility", key, function()
				return BarVisibility.Toggle(true)
			end)
			if bindings.SetSecureFrames then
				local frames = {}
				for _, entry in ipairs(managed) do
					local frame = _G[entry.name]
					if IsOn(settings[entry.group]) and frame and frame.IsProtected
						and frame:IsProtected() then
						frames[#frames + 1] = frame
					end
				end
				bindings:SetSecureFrames("bar_visibility", frames, state.hidden)
			end
		else
			bindings:RemoveAction("bar_visibility")
		end
	end
	bagsVisibility:ApplySettings()
	microVisibility:ApplySettings()
end

function BarVisibility.Disable()
	state.enabled = false
	state.wantedHidden = false
	ApplyWanted()
	local bindings = _G.SarychUI_ToggleBindings
	if bindings then bindings:RemoveAction("bar_visibility") end
	bagsVisibility:Disable()
	microVisibility:Disable()
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("PLAYER_REGEN_ENABLED")
boot:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_ENABLED" then
		ApplyWanted()
		bagsVisibility:ApplyWanted()
		microVisibility:ApplyWanted()
	else
		BarVisibility.ApplySettings()
	end
end)
