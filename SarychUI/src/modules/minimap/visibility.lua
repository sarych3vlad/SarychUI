local MinimapVisibility = {}
_G.SarychUI_MinimapVisibility = MinimapVisibility

local State = {
	enabled = false,
	hidden = false,
	hooked = false,
}

local function IsEnabledValue(value)
	return value == true or value == 1
end

local function GetMinimapDB()
	local profile = SarychUI and SarychUI.db and SarychUI.db.profile
	local modules = profile and profile.modules
	return modules and modules.minimap or nil
end

local function IsVisibilityEnabled()
	local minimap = GetMinimapDB()
	local visibility = minimap and minimap.minimapVisibility
	return minimap and IsEnabledValue(minimap.enabled)
		and visibility and IsEnabledValue(visibility.enabled)
end

local function EnsureClusterHook()
	if State.hooked or not _G.MinimapCluster then
		return
	end
	State.hooked = true
	MinimapCluster:HookScript("OnShow", function(self)
		if State.hidden then
			self:Hide()
		end
	end)
end

function MinimapVisibility.Hide()
	if State.hidden or not _G.MinimapCluster then
		return
	end
	EnsureClusterHook()
	State.hidden = true
	MinimapCluster:Hide()
end

function MinimapVisibility.Show()
	if not State.hidden or not _G.MinimapCluster then
		return
	end
	State.hidden = false
	MinimapCluster:Show()
end

function MinimapVisibility.Toggle(silent)
	if not State.enabled then
		return
	end

	local sound
	if State.hidden then
		sound = "igMiniMapZoomIn"
		if not silent and PlaySound then PlaySound(sound) end
		MinimapVisibility.Show()
	else
		sound = "igMiniMapZoomOut"
		if not silent and PlaySound then PlaySound(sound) end
		MinimapVisibility.Hide()
	end
	return sound
end

function MinimapVisibility.IsHidden()
	return State.hidden
end

function MinimapVisibility.ApplySettings()
	local minimap = GetMinimapDB()
	local visibility = minimap and minimap.minimapVisibility
	local bindings = _G.SarychUI_ToggleBindings
	local key = bindings and bindings:NormalizeKey(visibility and visibility.key) or nil
	local extension = SarychUI.extensions and SarychUI.extensions.visibility_control

	State.enabled = (not extension or extension:IsEnabled()) and IsVisibilityEnabled() and key ~= nil
	if not State.enabled and State.hidden then
		MinimapVisibility.Show()
	end

	EnsureClusterHook()
	if bindings then
		if State.enabled then
			bindings:SetAction("minimap_visibility", key, function()
				return MinimapVisibility.Toggle(true)
			end)
		else
			bindings:RemoveAction("minimap_visibility")
		end
	end
end

function MinimapVisibility.Disable()
	State.enabled = false
	if State.hidden then
		MinimapVisibility.Show()
	end
	local bindings = _G.SarychUI_ToggleBindings
	if bindings then
		bindings:RemoveAction("minimap_visibility")
	end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self, event, addon)
	if event == "ADDON_LOADED" and addon == "SarychUI" then
		self:SetScript("OnUpdate", function(frame)
			frame:SetScript("OnUpdate", nil)
			MinimapVisibility.ApplySettings()
		end)
	elseif event == "PLAYER_LOGIN" then
		MinimapVisibility.ApplySettings()
	end
end)
