-- Totem spell / pulse data (from FrostAtomUI TotemData).

local moduleName = "player_resources"
local module = SarychUI and SarychUI.modules and SarychUI.modules[moduleName]
if not module then return end

local GetSpellInfo = GetSpellInfo
local match, tonumber = string.match, tonumber
local RANK_SUFFIXES = { "", " II", " III", " IV", " V", " VI", " VII", " VIII", " IX", " X" }

local TOTEMS = {
	{ 1, 300, 8227, 5950, 8249, 6012, 10526, 7423, 16387, 10557, 25557, 15485, 58649, 31132, 58652, 31158, 58656, 31133 },
	{ 1, 300, 8181, 5926, 10478, 7412, 10479, 7413, 25560, 15486, 58741, 31171, 58745, 31172 },
	{ 1, 21, 8190, 5929, 10585, 7464, 10586, 7465, 10587, 7466, 25552, 15484, 58731, 31166, 58734, 31167 },
	{ 1, 30, 3599, 2523 },
	{ 1, 35, 6363, 3902 },
	{ 1, 40, 6364, 3903 },
	{ 1, 45, 6365, 3904 },
	{ 1, 50, 10437, 7400 },
	{ 1, 55, 10438, 7402 },
	{ 1, 60, 25533, 15480, 58699, 31162, 58703, 31164, 58704, 31165 },
	{ 1, 300, 30706, 17539, 57720, 30652, 57721, 30653, 57722, 30654 },
	{ 1, 120, 2894, 15439 },
	{ 2, 120, 2062, 15430 },
	{ 2, 45, 2484, 2630 },
	{ 2, 15, 5730, 3579, 6390, 3911, 6391, 3912, 6392, 3913, 10427, 7398, 10428, 7399, 25525, 15478, 58580, 31120, 58581, 31121, 58582, 31122 },
	{ 2, 300, 8071, 5873, 8154, 5919, 8155, 5920, 10406, 7366, 10407, 7367, 10408, 7368, 25508, 15470, 25509, 15474, 58751, 31175, 58753, 31176 },
	{ 2, 300, 8075, 5874, 8160, 5921, 8161, 5922, 10442, 7403, 25361, 15464, 25528, 15479, 57622, 30647, 58643, 31129 },
	{ 2, 300, 8143, 5913 },
	{ 3, 300, 8170, 5924 },
	{ 3, 300, 8184, 5927, 10537, 7424, 10538, 7425, 25563, 15487, 58737, 31169, 58739, 31170 },
	{ 3, 300, 5394, 3527, 6375, 3906, 6377, 3907, 10462, 3908, 10463, 3909, 25567, 15488, 58755, 31181, 58756, 31182, 58757, 31185 },
	{ 3, 300, 5675, 3573, 10495, 7414, 10496, 7415, 10497, 7416, 25570, 15489, 58771, 31186, 58773, 31189, 58774, 31190 },
	{ 3, 13, 16190, 10467 },
	{ 4, 45, 8177, 5925 },
	{ 4, 300, 10595, 7467, 10600, 7468, 10601, 7469, 25574, 15490, 58746, 31173, 58749, 31174 },
	{ 4, 300, 6495, 3968 },
	{ 4, 300, 8512, 6112 },
	{ 4, 300, 3738, 15447 },
}

local PULSES = {
	[8190] = { 2, 8187, 10579, 10580, 10581, 25550, 58732, 58735 },
	[2484] = { 3, 3600 },
	[5730] = { 2, 5729, 6393, 6394, 6395, 10423, 10424, 25512 },
	[8143] = { 3, 8146 },
	[8170] = { 3, 8171 },
	[5394] = { 2, 52041, 52046, 52047, 52048, 52049, 52050, 58759, 58760, 58761, 52042 },
	[16190] = { 3, 39610, 39609 },
}

local data = {
	TICK_EVENTS = {
		SPELL_CAST_SUCCESS = true,
		SPELL_DAMAGE = true,
		SPELL_MISSED = true,
		SPELL_HEAL = true,
		SPELL_ENERGIZE = true,
		SPELL_AURA_APPLIED = true,
		SPELL_AURA_REFRESH = true,
		SPELL_DISPEL = true,
	},
	spells = {},
	byEntry = {},
	byName = {},
	tickSpells = {},
}
module.TotemData = data

for i = 1, #TOTEMS do
	local row = TOTEMS[i]
	local pulseRow = PULSES[row[3]]
	local pulse
	if pulseRow then
		pulse = { period = pulseRow[1], ticks = {} }
		for j = 2, #pulseRow do
			pulse.ticks[pulseRow[j]] = true
			data.tickSpells[pulseRow[j]] = true
		end
	end
	for j = 3, #row, 2 do
		local spellId, entry = row[j], row[j + 1]
		local name, rank, icon = GetSpellInfo(spellId)
		if name then
			data.spells[spellId] = { slot = row[1], duration = row[2], icon = icon, pulse = pulse }
			if entry then
				data.byEntry[entry] = spellId
			end
			local digits = rank and match(rank, "%d+")
			data.byName[name .. (digits and RANK_SUFFIXES[tonumber(digits)] or "")] = spellId
			-- GetTotemInfo returns the base name without rank suffix on many clients.
			if not data.byName[name] then
				data.byName[name] = spellId
			end
		end
	end
end

if GetLocale() == "ruRU" then
	local RU_NAMES = {
		["Тотем сопротивления льду"] = { 8181, 10478, 10479, 25560, 58741, 58745 },
		["Тотем сопротивления огню"] = { 8184, 10537, 10538, 25563, 58737, 58739 },
		["Тотем сопротивления силам природы"] = { 10595, 10600, 10601, 25574, 58746, 58749 },
	}
	for name, ranks in pairs(RU_NAMES) do
		for rank = 1, #ranks do
			data.byName[name .. RANK_SUFFIXES[rank]] = ranks[rank]
			if not data.byName[name] then
				data.byName[name] = ranks[rank]
			end
		end
	end
end
