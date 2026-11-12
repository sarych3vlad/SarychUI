local FrameVisibility = {}
_G.SarychUI_FrameVisibility = FrameVisibility

local managed = {
	{ name = "PlayerFrame", choice = "player", unit = "player" },
	{ name = "PetFrame", choice = "player", unit = "pet" },
	{ name = "TotemFrame", choice = "player" },
	-- RuneFrame is anchored to PlayerFrame but parented to UIParent in FrameXML.
	{ name = "RuneFrame", choice = "player" },
	{ name = "TargetFrame", choice = "target", unit = "target" },
	{ name = "FocusFrame", choice = "focus", unit = "focus" },
}

local state = {
	enabled = false,
	hidden = false,
	wantedHidden = false,
	selected = {},
	wasShown = {},
	wasPresent = {},
	wasAlpha = {},
	alphaHidden = {},
	guarded = {},
}

local function IsOn(value)
	return value == true or value == 1
end

local function GetSettings()
	local profile = SarychUI and SarychUI.db and SarychUI.db.profile
	local db = profile and profile.modules and profile.modules.frame
	return db, db and db.frameVisibility
end

local function GuardFrame(frame)
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
	local playerWasSelected = state.selected[_G.PlayerFrame] ~= nil
	state.hidden = false
	for frame, spec in pairs(state.selected) do
		if state.alphaHidden[frame] then
			frame:SetAlpha(state.wasAlpha[frame] or 1)
		else
			local unit = spec.unit
			if (unit == "player" and state.wasShown[frame])
				or (unit and unit ~= "player" and UnitExists and UnitExists(unit)
					and (state.wasShown[frame] or not state.wasPresent[frame]))
				or (not unit and state.wasShown[frame]) then
				frame:Show()
			end
		end
	end
	state.selected = {}
	state.wasShown = {}
	state.wasPresent = {}
	state.wasAlpha = {}
	state.alphaHidden = {}
	if playerWasSelected then
		if _G.TotemFrame and _G.TotemFrame_Update
			and not (InCombatLockdown and InCombatLockdown()) then
			_G.TotemFrame_Update()
		end
	end
end

local function SelectionMatches(settings)
	for _, spec in ipairs(managed) do
		local frame = _G[spec.name]
		if frame and (state.selected[frame] ~= nil) ~= IsOn(settings[spec.choice]) then
			return false
		end
	end
	return true
end

local function Hide(settings)
	if state.hidden then return end
	state.selected = {}
	state.wasShown = {}
	state.wasPresent = {}
	state.wasAlpha = {}
	state.alphaHidden = {}
	for _, spec in ipairs(managed) do
		if IsOn(settings[spec.choice]) then
			local frame = _G[spec.name]
			if frame then
				GuardFrame(frame)
				state.selected[frame] = spec
				state.wasShown[frame] = frame:IsShown() and true or false
				state.wasPresent[frame] = spec.unit and UnitExists and UnitExists(spec.unit) and true or false
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

function FrameVisibility.Toggle(silent)
	if not state.enabled then return end
	state.wantedHidden = not state.wantedHidden
	ApplyWanted()
	local bindings = _G.SarychUI_ToggleBindings
	if bindings and bindings.SyncSecureHidden then
		bindings:SyncSecureHidden("frame_visibility", state.hidden)
	end
	local sound = state.wantedHidden and "igMiniMapZoomOut" or "igMiniMapZoomIn"
	if not silent and PlaySound then PlaySound(sound) end
	return sound
end

function FrameVisibility.IsHidden()
	return state.hidden
end

function FrameVisibility.IsPlayerHidden()
	return state.hidden and state.selected[_G.PlayerFrame] ~= nil
end

function FrameVisibility.ApplySettings()
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
			bindings:SetAction("frame_visibility", key, function()
				return FrameVisibility.Toggle(true)
			end)
			if bindings.SetSecureFrames then
				local frames = {}
				for _, spec in ipairs(managed) do
					local frame = _G[spec.name]
					if IsOn(settings[spec.choice]) and frame and frame.IsProtected
						and frame:IsProtected() then
						frames[#frames + 1] = frame
					end
				end
				bindings:SetSecureFrames("frame_visibility", frames, state.hidden)
			end
		else
			bindings:RemoveAction("frame_visibility")
		end
	end
end

function FrameVisibility.Disable()
	state.enabled = false
	state.wantedHidden = false
	ApplyWanted()
	local bindings = _G.SarychUI_ToggleBindings
	if bindings then bindings:RemoveAction("frame_visibility") end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_REGEN_ENABLED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_ENABLED" then
		ApplyWanted()
	else
		FrameVisibility.ApplySettings()
	end
end)
