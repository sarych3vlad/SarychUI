local E, L, V, P, G = unpack(_G.SarychUI_ElvUI_NamePlates) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local NP = E:GetModule("NamePlates")
local CreateFrame = CreateFrame

--[[
	Aura display over nameplates is intentionally REMOVED in this standalone addon
	(no buff/debuff icons, no aura filters, no LibAuraInfo, no aura options).

	The ported ElvUI NamePlates core still references Buffs/Debuffs containers and
	calls the aura construct/configure/update routines. To keep that code error-free
	without bringing back any aura functionality, ConstructElement_Auras returns a
	permanently hidden, empty container frame and the configure/update routines are
	no-ops. Nothing is ever anchored, created, or shown.

	The StyleFilter engine's buff/debuff trigger branches are also dormant: they are
	guarded by `frame.Buffs and trigger.buffs.names` and the aura trigger options have
	been removed, so those code paths never run.
]]
function NP:ConstructElement_Auras(parent)
	local container = CreateFrame("Frame", nil, parent)
	container:Hide()
	container.anchoredIcons = 0
	return container
end
function NP:Configure_Auras() end
function NP:UpdateElement_Auras() end
