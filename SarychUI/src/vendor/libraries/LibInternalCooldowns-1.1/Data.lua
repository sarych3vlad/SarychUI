local lib = LibStub:GetLibrary("LibInternalCooldowns-1.1")
local data = SarychUI.Data.InternalCooldowns
local spellToItem = data.spellToItem
local enchants = data.enchants
local metas = data.metas
local cooldowns = data.cooldowns
local talents = data.talents

lib.spellToItem = lib.spellToItem or {};
lib.cooldowns = lib.cooldowns or {};
lib.enchants = lib.enchants or {};
lib.metas = lib.metas or {};
lib.talents = lib.talents or {};

local tt, tts = {}, {}
local function merge(t1, t2)
	wipe(tts)
	for _, v in ipairs(t1) do
		tts[v] = true
	end
	for _, v in ipairs(t2) do
		if not tts[v] then
			tinsert(t1, v);
		end
	end
end;

for k, v in pairs(spellToItem) do
	local e = lib.spellToItem[k]
	if e and e ~= v then
		if type(e) == "table" then
			if type(v) ~= "table" then
				wipe(tt)
				tinsert(tt, v)
			end
			merge(e, tt);
		else
			lib.spellToItem[k] = {e, v};
		end
	else
		lib.spellToItem[k] = v;
	end
end;

for k, v in pairs(cooldowns) do
	lib.cooldowns[k] = v
end;

for k, v in pairs(enchants) do
	lib.enchants[k] = v
end;

for k, v in pairs(metas) do
	lib.metas[k] = v
end;

for k, v in pairs(talents) do
	lib.talents[k] = v
end;