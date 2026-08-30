-- InspectEquip bootstrap for SarychUI embedding

InspectEquipEnabled = false

function SarychUI_IsStandaloneInspectEquipEnabled()
	if not GetNumAddOns or not GetAddOnInfo then
		return false
	end
	for i = 1, GetNumAddOns() do
		local name, _, _, enabled, loadable = GetAddOnInfo(i)
		if name == "InspectEquip" and enabled and loadable then
			return true
		end
	end
	return false
end
