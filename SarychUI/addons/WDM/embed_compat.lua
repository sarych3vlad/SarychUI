-- Embedded WDM path helpers (SarychUI)
local EMBED_ROOT = "Interface\\AddOns\\SarychUI\\addons\\WDM"

function WDM_GetAddonPath()
	return EMBED_ROOT
end

function WDM_GetTexturePath(name)
	return EMBED_ROOT .. "\\textures\\" .. name
end
