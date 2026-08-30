-- Equipence bootstrap for SarychUI embedding
-- Cursor-like valve: core in TOC; runtime off until AceDB enables it.

SarychUI_EquipencePath = "Interface\\AddOns\\SarychUI\\addons\\Equipence\\"
EquipenceEnabled = false

function SarychUI_IsStandaloneEquipenceEnabled()
	if not GetNumAddOns or not GetAddOnInfo then
		return false
	end
	for i = 1, GetNumAddOns() do
		local name, _, _, enabled, loadable = GetAddOnInfo(i)
		if name == "Equipence" and enabled and loadable then
			return true
		end
	end
	return false
end

function SarychUI_ApplyEquipenceRuntime(enable)
	EquipenceEnabled = enable and true or false
	if enable then
		if SarychUI_InitEmbeddedEquipence then
			SarychUI_InitEmbeddedEquipence()
		end
	else
		local engine = _G.EquipenceEngine
		local controllers = engine and engine.Controllers
		if controllers then
			local character = controllers.CharacterController
			if character then
				if character.UnregisterAllEvents then
					character:UnregisterAllEvents()
				end
				if character.Hide then
					character:Hide()
				end
			end
			local inspection = controllers.InspectionController
			if inspection then
				if inspection.UnregisterAllEvents then
					inspection:UnregisterAllEvents()
				end
				if inspection.Hide then
					inspection:Hide()
				end
			end
		end
	end
end
