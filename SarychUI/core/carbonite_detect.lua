-- External Carbonite detection only (no embedded copy inside SarychUI).

local CARBONITE_ADDON = "Carbonite"

local function GetCarboniteAddOnInfo()
	if not GetAddOnInfo then
		return nil
	end
	return GetAddOnInfo(CARBONITE_ADDON)
end

function SarychUI:IsExternalCarboniteInstalled()
	local name, _, _, _, loadable = GetCarboniteAddOnInfo()
	return name ~= nil and loadable == true
end

function SarychUI:IsExternalCarboniteEnabled()
	local _, _, _, enabled, loadable = GetCarboniteAddOnInfo()
	return loadable == true and enabled == true
end

function SarychUI:IsExternalCarboniteLoaded()
	if IsAddOnLoaded and IsAddOnLoaded(CARBONITE_ADDON) then
		return _G.Nx ~= nil
	end
	return _G.Nx ~= nil
end

function SarychUI:IsExternalCarboniteAvailable()
	return self:IsExternalCarboniteInstalled() and self:IsExternalCarboniteEnabled()
end

function SarychUI:EnsureExternalCarboniteLoaded()
	if self:IsExternalCarboniteLoaded() then
		return true
	end
	if not self:IsExternalCarboniteAvailable() then
		return false
	end
	if LoadAddOn then
		local ok = LoadAddOn(CARBONITE_ADDON)
		return ok and self:IsExternalCarboniteLoaded()
	end
	return false
end

function SarychUI:SanitizeMapType(mapType)
	mapType = mapType or "mapster"
	if mapType == "carbonite" and not self:IsExternalCarboniteAvailable() then
		return "mapster"
	end
	if mapType ~= "classic" and mapType ~= "mapster" and mapType ~= "carbonite" then
		return "mapster"
	end
	return mapType
end

function SarychUI_IsCarboniteRuntimeEnabled()
	if not SarychUI or not SarychUI.GetMapMode then
		return false
	end
	if SarychUI:GetMapMode() ~= "carbonite" then
		return false
	end
	if not SarychUI:IsExternalCarboniteAvailable() then
		return false
	end
	return SarychUI:IsExternalCarboniteLoaded()
end
