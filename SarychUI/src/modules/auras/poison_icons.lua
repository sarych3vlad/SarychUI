-- SarychUI Auras: show poison and shaman imbue icons over temporary weapon enchants.

local module = SarychUI and SarychUI.GetModule and SarychUI:GetModule("auras")
if not module then return end

local _, playerClass = UnitClass("player")
local isRogue = playerClass == "ROGUE"
local isShaman = playerClass == "SHAMAN"
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

-- The tooltip shows an enchant name (often without "Weapon") and its rank,
-- rather than a spell ID. Match by name so one entry covers lower ranks too.
local SHAMAN_IMBUES = {
	{ id = 10399, enUS = "Rockbiter", ruRU = "Камнедробител" },
	{ id = 58790, enUS = "Flametongue", ruRU = "Язык пламени" },
	{ id = 58796, enUS = "Frostbrand", ruRU = "Ледяное клеймо" },
	{ id = 58804, enUS = "Windfury", ruRU = "Неистовство ветра" },
	{ id = 51994, enUS = "Earthliving", ruRU = "Жизнь земли" },
}

local function ContainsName(text, name)
	return name and name ~= "" and
		(string.find(text, name, 1, true)
			or string.find(string.lower(text), string.lower(name), 1, true))
end

local function ShamanTextureForText(text)
	local locale = GetLocale()
	for _, imbue in ipairs(SHAMAN_IMBUES) do
		local spellName, _, texture = GetSpellInfo(imbue.id)
		if texture and (ContainsName(text, spellName)
			or ContainsName(text, imbue[locale])
			or ContainsName(text, imbue.enUS)) then
			return texture
		end
	end
	return nil
end

local function ModuleDB()
	local modules = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return modules and modules.auras
end

local function Enabled()
	local db = ModuleDB()
	return (isRogue or isShaman) and db and db.enabled
		and (db.showPoisonIcons == 1 or db.showPoisonIcons == true)
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
			if isRogue then
				for poisonName, texture in pairs(poisonIcons) do
					if ContainsName(text, poisonName) then
						return texture
					end
				end
			elseif isShaman then
				local texture = ShamanTextureForText(text)
				if texture then return texture end
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

