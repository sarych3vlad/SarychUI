--[[
    Aegis Framework
    Copyright (c) 2026 s0high. All rights reserved.

    Restricted proprietary library. See LICENSE for terms.
]]

local Aegis = LibStub("Aegis-2.0");

local type = type;
local GetSpellInfo = GetSpellInfo;

local VERSION = 1;

local function BuildSpellInfoFromLegacy(spellIdentifier)
	if not GetSpellInfo then
		return nil;
	end

	local name, subText, iconID, castTime, minRange, maxRange, spellID = GetSpellInfo(spellIdentifier);
	if not name then
		return nil;
	end

	return {
		name = name,
		subText = subText,
		iconID = iconID,
		iconFileID = iconID,
		castTime = castTime,
		minRange = minRange,
		maxRange = maxRange,
		spellID = spellID or spellIdentifier,
	};
end

local function BuildSpellInfoFromNative(native, spellIdentifier)
	if not native or not native.GetSpellInfo then
		return nil;
	end

	local spellInfo, subText, iconID, castTime, minRange, maxRange, spellID, originalIconID = native.GetSpellInfo(spellIdentifier);
	if type(spellInfo) == "table" then
		return spellInfo;
	end

	if not spellInfo then
		return nil;
	end

	return {
		name = spellInfo,
		subText = subText,
		iconID = iconID,
		iconFileID = iconID,
		castTime = castTime,
		minRange = minRange,
		maxRange = maxRange,
		spellID = spellID or spellIdentifier,
		originalIconID = originalIconID,
	};
end

Aegis:RegisterNamespace("C_Spell", VERSION, function(_, _, namespace, native)
	local C_Spell = namespace or {};
	local useNative = native ~= nil;

	function C_Spell.GetSpellInfo(spellIdentifier)
		if not spellIdentifier then
			return nil;
		end

		if useNative then
			local nativeInfo = BuildSpellInfoFromNative(native, spellIdentifier);
			if nativeInfo then
				return nativeInfo;
			end
		end

		return BuildSpellInfoFromLegacy(spellIdentifier);
	end

	function C_Spell.GetSpellName(spellIdentifier)
		if not spellIdentifier then
			return nil;
		end

		if useNative and native.GetSpellName then
			return native.GetSpellName(spellIdentifier);
		end

		local spellInfo = C_Spell.GetSpellInfo(spellIdentifier);
		return spellInfo and spellInfo.name or nil;
	end

	function C_Spell.GetSpellTexture(spellIdentifier)
		if not spellIdentifier then
			return nil;
		end

		if useNative and native.GetSpellTexture then
			return native.GetSpellTexture(spellIdentifier);
		end

		local spellInfo = C_Spell.GetSpellInfo(spellIdentifier);
		if not spellInfo then
			return nil;
		end

		return spellInfo.iconID or spellInfo.iconFileID or spellInfo.originalIconID;
	end

	return C_Spell;
end, { trustNative = true, wrapNative = true });
