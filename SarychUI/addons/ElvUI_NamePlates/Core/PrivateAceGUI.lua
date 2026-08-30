-- Thin binder: ElvUI NamePlates options use AceGUI-3.0-ENP only (never shared AceGUI-3.0).

local function EnsurePrivateAceGUI()
	local gui = LibStub and LibStub("AceGUI-3.0-ENP", true)
	if gui and _G.ENP then
		_G.ENP.Libs = _G.ENP.Libs or {}
		_G.ENP.Libs.AceGUI = gui
	end
	return gui
end

_G.SarychUI_ENP_EnsurePrivateAceGUI = EnsurePrivateAceGUI

if _G.ENP then
	EnsurePrivateAceGUI()
end
