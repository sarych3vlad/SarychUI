-- Narrow metadata shim for embedded Postal inside SarychUI.
-- Postal queries GetAddOnMetadata("Postal", ...), but "Postal" is not a standalone addon in embedded mode.

local _GetAddOnMetadata = GetAddOnMetadata

function GetAddOnMetadata(addon, field)
	if addon ~= "Postal" then
		return _GetAddOnMetadata(addon, field)
	end

	if field == "Version" then
		return _G.SarychUI_POSTAL_EMBEDDED_VERSION or "3.3.2"
	end
	if field == "Title" then
		return _G.SarychUI_POSTAL_EMBEDDED_TITLE or "Postal"
	end
	if field == "Notes" or field == "Notes-ruRU" then
		return _G.SarychUI_POSTAL_EMBEDDED_NOTES or "Postal: Enhanced Mailbox support"
	end

	-- Optional extension point for custom metadata in SarychUI.toc.
	local value = _GetAddOnMetadata("SarychUI", "X-Postal-" .. tostring(field or ""))
	if value ~= nil then
		return value
	end

	return nil
end
