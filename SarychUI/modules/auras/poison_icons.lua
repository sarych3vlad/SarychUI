-- SarychUI Auras: show Rogue poison icons over temporary weapon enchant icons.

local module = SarychUI and SarychUI.GetModule and SarychUI:GetModule("auras")
if not module then return end

local _, playerClass = UnitClass("player")
local isRogue = playerClass == "ROGUE"
local overlays = {}
local scanner

local POISON_ICONS = {
	ruRU = {
		["Калечащий"] = "Interface\\Icons\\ability_poisonsting",
		["Быстродействующий"] = "Interface\\Icons\\ability_poisons",
		["Смертельный"] = "Interface\\Icons\\ability_rogue_dualweild",
		["Нейтрализующий"] = "Interface\\Icons\\inv_misc_herb_16",
		["Анестезирующий"] = "Interface\\Icons\\spell_nature_slowpoison",
		["Дурманящий"] = "Interface\\Icons\\spell_nature_nullifydisease",
	},
	deDE = {
		["Verkrüppel"] = "Interface\\Icons\\ability_poisonsting",
		["Sofort"] = "Interface\\Icons\\ability_poisons",
		["Tödliches"] = "Interface\\Icons\\ability_rogue_dualweild",
		["Wundgift"] = "Interface\\Icons\\inv_misc_herb_16",
		["Beruhigendes"] = "Interface\\Icons\\spell_nature_slowpoison",
		["Gedankenbenebelndes"] = "Interface\\Icons\\spell_nature_nullifydisease",
	},
	frFR = {
		["affaiblissant"] = "Interface\\Icons\\ability_poisonsting",
		["instantané"] = "Interface\\Icons\\ability_poisons",
		["mortel"] = "Interface\\Icons\\ability_rogue_dualweild",
		["douloureux"] = "Interface\\Icons\\inv_misc_herb_16",
		["anesthésiant"] = "Interface\\Icons\\spell_nature_slowpoison",
		["distraction"] = "Interface\\Icons\\spell_nature_nullifydisease",
	},
	esES = {
		["entorpecedor"] = "Interface\\Icons\\ability_poisonsting",
		["instantáneo"] = "Interface\\Icons\\ability_poisons",
		["mortal"] = "Interface\\Icons\\ability_rogue_dualweild",
		["hiriente"] = "Interface\\Icons\\inv_misc_herb_16",
		["anestésico"] = "Interface\\Icons\\spell_nature_slowpoison",
		["mental"] = "Interface\\Icons\\spell_nature_nullifydisease",
	},
	zhTW = {
		["致殘"] = "Interface\\Icons\\ability_poisonsting",
		["速效"] = "Interface\\Icons\\ability_poisons",
		["致命"] = "Interface\\Icons\\ability_rogue_dualweild",
		["致傷"] = "Interface\\Icons\\inv_misc_herb_16",
		["麻醉"] = "Interface\\Icons\\spell_nature_slowpoison",
		["麻痹"] = "Interface\\Icons\\spell_nature_nullifydisease",
	},
	enUS = {
		["Crippling"] = "Interface\\Icons\\ability_poisonsting",
		["Instant"] = "Interface\\Icons\\ability_poisons",
		["Deadly"] = "Interface\\Icons\\ability_rogue_dualweild",
		["Wound"] = "Interface\\Icons\\inv_misc_herb_16",
		["Anesthetic"] = "Interface\\Icons\\spell_nature_slowpoison",
		["Mind"] = "Interface\\Icons\\spell_nature_nullifydisease",
	},
}
POISON_ICONS.esMX = POISON_ICONS.esES

local poisonIcons = POISON_ICONS[GetLocale()] or POISON_ICONS.enUS

local function ModuleDB()
	local modules = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return modules and modules.auras
end

local function Enabled()
	local db = ModuleDB()
	return isRogue and db and db.enabled and (db.showPoisonIcons == 1 or db.showPoisonIcons == true)
end

local function EnsureScanner()
	if scanner then return scanner end
	scanner = CreateFrame("GameTooltip", "SarychUIPoisonEnchantScanner", UIParent, "GameTooltipTemplate")
	scanner:SetOwner(UIParent, "ANCHOR_NONE")
	return scanner
end

local function EnsureOverlays()
	for i = 1, 2 do
		if not overlays[i] then
			local enchantFrame = _G["TempEnchant" .. i]
			local icon = _G["TempEnchant" .. i .. "Icon"]
			if enchantFrame and icon then
				local texture = enchantFrame:CreateTexture(nil, "OVERLAY")
				texture:SetAllPoints(icon)
				texture:Hide()
				overlays[i] = texture
			end
		end
	end
	return overlays[1] ~= nil
end

local function PoisonTextureForSlot(slotId)
	local tip = EnsureScanner()
	tip:ClearLines()
	tip:SetInventoryItem("player", slotId)

	for lineIndex = 1, tip:NumLines() do
		local line = _G["SarychUIPoisonEnchantScannerTextLeft" .. lineIndex]
		local text = line and line:GetText()
		if text then
			for poisonName, texture in pairs(poisonIcons) do
				if string.find(text, poisonName, 1, true)
					or string.find(string.lower(text), string.lower(poisonName), 1, true) then
					return texture
				end
			end
		end
	end
	return nil
end

local function SetOverlay(index, texture)
	local overlay = overlays[index]
	if not overlay then return end
	if texture then
		overlay:SetTexture(texture)
		overlay:Show()
	else
		overlay:SetTexture(nil)
		overlay:Hide()
	end
end

function module:ResetPoisonIcons()
	for i = 1, 2 do
		SetOverlay(i, nil)
	end
end

function module:ApplyPoisonIcons()
	if not Enabled() then
		self:ResetPoisonIcons()
		return
	end
	if not EnsureOverlays() then return end

	local mainHandEnchanted, _, _, offHandEnchanted = GetWeaponEnchantInfo()
	if mainHandEnchanted and offHandEnchanted then
		SetOverlay(1, PoisonTextureForSlot(17))
		SetOverlay(2, PoisonTextureForSlot(16))
	elseif mainHandEnchanted then
		SetOverlay(1, PoisonTextureForSlot(16))
		SetOverlay(2, nil)
	elseif offHandEnchanted then
		SetOverlay(1, PoisonTextureForSlot(17))
		SetOverlay(2, nil)
	else
		self:ResetPoisonIcons()
	end
end

