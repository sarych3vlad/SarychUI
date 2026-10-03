local E, L, C, G = select(2, ...):unpack()

G.loginMessage = false
G.notifyNew = false
G.optionPanelScale = 1

C.tooltipID = false


C.Party = {
	["visibility"] = {
		["arena"] = true,
		["pvp"] = false,
		["party"] = true,
		["raid"] = false,
		["scenario"] = false,
		["none"] = false,
		["finder"] = true,
	},
	["groupSize"] = {
		["arena"] = 5,
		["pvp"] = 40,
		["party"] = 10,
		["raid"] = 40,
		["scenario"] = 40,
		["none"] = 40,
	},
	["noneZoneSetting"] = "arena",
	["scenarioZoneSetting"] = "arena",
	["raidGroup"] = {
		["arena"] = true,
		["pvp"] = true,
		["party"] = true,
		["raid"] = true,
		["scenario"] = false,
		["none"] = false,
	},
}

C.Party.arena = {
	["general"] = {
		["showAnchor"] = false,
		["showPlayer"] = false,
		--["showPlayerEx"] = true,
		["showRange"] = false,
		--["zoneSelected"] = false,
	},
	["position"] = {
		["uf"] = "auto",
		["preset"] = "TOPRIGHT",
		["anchor"] = "TOPLEFT",
		["attach"] = "TOPRIGHT",
		["offsetX"] = 4,
		["offsetY"] = 0,
		["layout"] = "horizontal",
		["columns"] = 6,
		["paddingX"] = 3,
		["paddingY"] = 3,
		["sortBy"] = 2,
		["breakPoint"] = "offensive",
		["breakPoint2"] = "other",
		["breakPoint3"] = 35,
		["breakPoint4"] = 10,
		["displayInactive"] = true,
		["growUpward"] = false,
		["maxNumIcons"] = 0,
		["detached"] = false,
		["locked"] = false,
	},
	["icons"] = {
		["showTooltip"] = false,
		["showCounter"] = true,
		["reverse"] = false,
		["desaturateActive"] = false,
		["showForbearanceCounter"] = true,
		["scale"] = 0.80,
		["swipeAlpha"] = 0.8,
		["inactiveAlpha"] = 1,
		["activeAlpha"] = 1,
		["displayBorder"] = true,
		["borderColor"] = { r = 0.0, g = 0.0, b = 0.0 },
	},
	["highlight"] = {
		["glow"] = true,
		["glowBuffs"] = true,
		["glowType"] = "wardrobe",
		["glowBuffTypes"] = {
			["racial"] = false,
			["immunity"] = true,
			["defensive"] = true,
			["tankDefensive"] = true,
			["externalDefensive"] = true,
			["raidDefensive"] = true,
			["heal"] = false,
			["offensive"] = false,
			["counterCC"] = false,
			["freedom"] = false,
			["movement"] = false,
			["raidMovement"] = false,
			["other"] = false,
			["trinket"] = false,
		},
		["glowBorder"] = true,
		["glowBorderCondition"] = 1,
	},
	["priority"] = {
		["pvptrinket"] = 100,
		["racial"] = 95,
		["interrupt"] = 90,
		["dispel"] = 85,
		["cc"] = 80,
		["aoeCC"] = 75,
		["disarm"] = 70,
		["immunity"] = 65,
		["defensive"] = 60,
		["tankDefensive"] = 55,
		["externalDefensive"] = 50,
		["raidDefensive"] = 45,
		["heal"] = 40,
		["offensive"] = 35,
		["counterCC"] = 30,
		["freedom"] = 25,
		["movement"] = 20,
		["raidMovement"] = 15,
		["other"] = 10,
		["taunt"] = 5,
		["trinket"] = 0,
		["consumable"] = 0,
		["custom1"] = 0,
		["custom2"] = 0,
	},
	["frame"] = {
		["pvptrinket"] = 0,
		["racial"] = 0,
		["interrupt"] = 1,
		["dispel"] = 0,
		["cc"] = 0,
		["aoeCC"] = 0,
		["disarm"] = 0,
		["immunity"] = 0,
		["defensive"] = 0,
		["tankDefensive"] = 0,
		["externalDefensive"] = 0,
		["raidDefensive"] = 0,
		["heal"] = 0,
		["offensive"] = 0,
		["counterCC"] = 0,
		["freedom"] = 0,
		["movement"] = 0,
		["raidMovement"] = 0,
		["other"] = 0,
		["taunt"] = 0,
		["trinket"] = 0,
		["consumable"] = 0,
		["custom1"] = 0,
		["custom2"] = 0,
	},
	["spells"] = { ["*"] = false },
	["spellFrame"] = {},
	["spellPriority"] = {},
	["spellGlow"] = { ["*"] = false },
	["manualPos"] = {},
	["extraBars"] = {},

}

for i = 1, 8 do
	local key = E.Party.extraBarKeys[i]
	C.Party.arena.extraBars[key] = {
		["name"] = nil,
		["enabled"] = false,
		["redirect"] = true,
		["unitBar"] = false,
		["locked"] = false,
		["showPlayer"] = true,
		["uf"] = "auto",
		["anchor"] = "TOPRIGHT",
		["attach"] = "TOPLEFT",
		["offsetX"] = 0,
		["offsetY"] = 0,
		["layout"] = "vertical",
		["sortBy"] = i == 1 and 2 or 3,
		["sortDirection"] = "asc",
		["columns"] = 15,
		["scale"] = 0.6,
		["paddingX"] = -1,
		["paddingY"] = -1,
		["showName"] = true,
		["classColor"] = true,
		["nameOfsY"] = 0,
		["truncateIconName"] = 6,
		["growUpward"] = false,
		["growLeft"] = false,
		["progressBar"] = true,
		["nameBar"] = false,
		["textColors"] = {
			["activeColor"] = { r = 1.0, g = 1.0, b = 1.0 },
			["inactiveColor"] = { r = 1.0, g = 1.0, b = 1.0 },
			["rechargeColor"] = { r = 1.0, g = 1.0, b = 1.0 },
			["useClassColor"] = {
				["active"] = false,
				["inactive"] = false,
				["recharge"] = false,
			},
		},
		["barColors"] = {
			["activeColor"] = { r = 1.0, g = 0.0, b = 0.0, a = 1.0 },
			["rechargeColor"] = { r = 1.0, g = 0.7, b = 0.0, a = 1.0 },
			["inactiveColor"] = { r = 0.0, g = 1.0, b = 0.0, a = 1.0 },
			["useClassColor"] = {
				["active"] = true,
				["inactive"] = true,
				["recharge"] = true,
			},
		},
		["bgColors"] = {
			["activeColor"] = { r = 0.0, g = 0.0, b = 0.0, a = 0.5 },
			["rechargeColor"] = { r = 1.0, g = 0.7, b = 0.0, a = 1.0 },
			["inactiveColor"] = { r = 0.0, g = 1.0, b = 0.0, a = 0.5 },
			["useClassColor"] = {
				["active"] = false,
				["inactive"] = false,
				["recharge"] = true,
			},
		},
		["reverseFill"] = true,
		["useIconAlpha"] = false,
		["hideSpark"] = false,
		["hideBorder"] = false,
		["showInterruptedSpell"] = i == 1,
		["statusBarWidth"] = 205,
		["textScale"] = 1.0,
		["textOfsX"] = 3,
		["textOfsY"] = 0,
		["truncateStatusBarName"] = 0,
		["manualPos"] = {},
	}
end

if E.spellDefaults then
	for i = 1, #E.spellDefaults do
		local id = E.spellDefaults[i]
		local sId = tostring(id)
		C.Party.arena.spells[sId] = true
	end
end

if E.interruptDefaults then
	for i = 1, #E.interruptDefaults do
		local id = E.interruptDefaults[i]
		local sId = tostring(id)
		C.Party.arena.spells[sId] = true
	end
end

if E.raidDefaults then
	for i = 1, #E.raidDefaults do
		local id = E.raidDefaults[i]
		local sId = tostring(id)
		C.Party.arena.spells[sId] = true
	end
end

for k in pairs(E.L_CFG_ZONE) do
	if k ~= "arena" then
		C.Party[k] = E:DeepCopy(C.Party.arena)
	end
end
