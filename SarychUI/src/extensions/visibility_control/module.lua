-- Shared options for the existing frame, minimap and action bar visibility controllers.
local extension = SarychUI:RegisterExtension("visibility_control", {})

function extension:GetDB()
	local profile = SarychUI.db and SarychUI.db.profile
	return profile and profile.modules and profile.modules.visibility_control
end

function extension:IsEnabled()
	local db = self:GetDB()
	return not db or (db.enabled ~= false and db.enabled ~= 0)
end

function extension:RefreshConfig()
	local modules = SarychUI.modules
	if not modules then return end
	for _, spec in ipairs({
		{ "chat", "ApplyChatVisibilitySettings" },
		{ "frame", "ApplyFrameVisibilitySettings" },
		{ "minimap", "ApplyVisibilitySettings" },
		{ "mainmenubar", "ApplyBarVisibilitySettings" },
        { "auras", "ApplyBlacklistVisibilitySettings" },
	}) do
		local module = modules[spec[1]]
		if module and module[spec[2]] then module[spec[2]](module) end
	end
end

extension.Enable = extension.RefreshConfig
