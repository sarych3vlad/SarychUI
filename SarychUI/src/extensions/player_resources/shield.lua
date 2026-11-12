-- Warrior equipped shield icon (FrostAtomUI ShieldIndicator).

local moduleName = "player_resources"
local module = SarychUI and SarychUI.modules and SarychUI.modules[moduleName]
if not module then return end

if module.PLAYER_CLASS ~= "WARRIOR" then
	function module:RefreshShield() end
	function module:DisableShield() end
	return
end

local OFFHAND_SLOT = 17
local icon, texture

local function Update()
	if not icon then return end
	local link = module:Flag("shield", "enabled", false) and GetInventoryItemLink("player", OFFHAND_SLOT)
	local equipLoc = link and select(9, GetItemInfo(link))
	if equipLoc == "INVTYPE_SHIELD" then
		texture:SetTexture(GetInventoryItemTexture("player", OFFHAND_SLOT))
		icon:Show()
	else
		icon:Hide()
	end
end

local function Ensure()
	if icon then return end
	icon = CreateFrame("Frame", "SarychUIShieldIndicator", UIParent)
	texture = icon:CreateTexture(nil, "BORDER")
	texture:SetAllPoints()
	local border = icon:CreateTexture(nil, "ARTWORK")
	border:SetTexture([[Interface\Buttons\UI-Quickslot2]])
	border:SetPoint("TOPLEFT", -8, 8)
	border:SetPoint("BOTTOMRIGHT", 8, -8)
	module:RegisterDrag("playerShield", icon, "shield", "Индикатор щита")
	local ev = CreateFrame("Frame")
	ev:RegisterEvent("PLAYER_ENTERING_WORLD")
	ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	ev:SetScript("OnEvent", function(_, event, slot)
		if event == "PLAYER_EQUIPMENT_CHANGED" and slot ~= OFFHAND_SLOT then
			return
		end
		Update()
	end)
	module._shieldEvents = ev
end

function module:RefreshShield()
	if not module:Flag("shield", "enabled", false) then
		self:DisableShield()
		return
	end
	Ensure()
	local size = module:Num("shield", "size", 34)
	icon:SetSize(size, size)
	module:ApplyPoint(icon, "shield")
	Update()
	module:UpdateDrag("playerShield", "shield")
end

function module:DisableShield()
	module:StopDrag("playerShield")
	if icon then
		icon:Hide()
	end
end
