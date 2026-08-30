-- Blocks embedded SarychUI addon copies from re-registering global AceGUI/AceConfig.
-- External addons (WeakAuras, Postal standalone, etc.) are not affected.

local EMBEDDED_ACE_MAJORS = {
	["AceGUI-3.0"] = true,
	["AceConfig-3.0"] = true,
	["AceConfigDialog-3.0"] = true,
	["AceConfigRegistry-3.0"] = true,
	["AceConfigCmd-3.0"] = true,
	["AceDBOptions-3.0"] = true,
}

local EMBEDDED_PATH_MARKERS = {
	"\\SarychUI\\addons\\",
	"/SarychUI/addons/",
}

-- Grabs the whole relevant stack in one debugstack call. Walking it level by level
-- meant up to 24 debugstack calls (each of which rebuilds a traceback string) per
-- guarded library registration, which is measurable during login.
local function IsEmbeddedAceLoad()
	local stack = debugstack(2, 24, 0)
	if not stack or stack == "" then
		return false
	end
	for i = 1, #EMBEDDED_PATH_MARKERS do
		if stack:find(EMBEDDED_PATH_MARKERS[i], 1, true) then
			return true
		end
	end
	return false
end

local libStub = LibStub
if not libStub or libStub._sarychAceEmbedGuardInstalled then
	return
end
libStub._sarychAceEmbedGuardInstalled = true

local originalNewLibrary = libStub.NewLibrary
function libStub:NewLibrary(major, minor)
	if EMBEDDED_ACE_MAJORS[major] and IsEmbeddedAceLoad() then
		return nil
	end
	return originalNewLibrary(self, major, minor)
end
