local SUI = SarychUI
local extension = {}
SUI.WoWCircle = extension

local defaults = { enabled = true, enableCircleContextMenu = 1,
    ppMessageFixEnabled = 1, spamFilterCombatDifficulty = 1 }
SUI.defaults.profile.modules.wowcircle = defaults
local quickStartDefaults = {
		quickStartCatalog = false,
		quickStartCatalogCleared = false,
		quickStartMiscEnabled = false,
		-- Per-character checkpoints for the applied Quick Start route.
		quickStartProgress = {},
		-- Account-wide Quick Start templates.  They intentionally live in the
		-- global namespace so every character sees the same cloned profiles.
		quickStartSelectedProfile = "__builtin",
		quickStartProfiles = {
			version = 1,
			nextID = 1,
			order = {},
			entries = {},
		},
}
for key, value in pairs(quickStartDefaults) do SUI.defaults.global[key] = value end
if SUI.db and SUI.db.RegisterDefaults then SUI.db:RegisterDefaults(SUI.defaults) end

function extension:GetDB()
    local profile = SUI.db.profile
    profile.modules.wowcircle = profile.modules.wowcircle or {}
    local db = profile.modules.wowcircle
    if not db.migrated then
        local old, chat = profile.modules.tools or {}, profile.modules.chat or {}
        for key, fallback in pairs(defaults) do
            local value = old[key]
            if value == nil then value = chat[key] end
            if value == nil then value = fallback end
            db[key] = value
        end
        db.migrated = true
    end
    return db
end

-- Register after the implementation and option builders have been loaded.
