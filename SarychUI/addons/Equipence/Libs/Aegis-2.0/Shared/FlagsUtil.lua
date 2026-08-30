--[[
    Aegis Framework
    Copyright (c) 2026 s0high. All rights reserved.

    Restricted proprietary library. See LICENSE for terms.
]]

local Aegis = LibStub("Aegis-2.0");

local VERSION = 2;

local bit = bit;
local floor = math.floor;
local pairs = pairs;
local select = select;
local type = type;

local function NormalizeMask(mask)
	if (type(mask) ~= "number" or mask <= 0) then
		return 0;
	end

	return floor(mask);
end

Aegis:RegisterNamespace("FlagsUtil", VERSION, function(_, _, namespace, native)
	local FlagsUtil = namespace or {};

	local function CreateMask(...)
		local mask = 0;
		for index = 1, select("#", ...) do
			mask = bit.bor(mask, NormalizeMask(select(index, ...)));
		end

		return mask;
	end

	local function CreateMaskFromTable(flagsTable)
		local mask = 0;
		for _, flagValue in pairs(flagsTable) do
			mask = bit.bor(mask, NormalizeMask(flagValue));
		end

		return mask;
	end

	local function MakeFlags(...)
		local flags = {};
		local flag = 1;

		for index = 1, select("#", ...) do
			flags[select(index, ...)] = flag;
			flag = bit.lshift(flag, 1);
		end

		return flags;
	end

	local function IsSet(bitMask, flagOrMask)
		bitMask = NormalizeMask(bitMask);
		flagOrMask = NormalizeMask(flagOrMask);
		if flagOrMask == 0 then
			return false;
		end

		return bit.band(bitMask, flagOrMask) == flagOrMask;
	end

	local function IsAnySet(bitMask, mask)
		return bit.band(NormalizeMask(bitMask), NormalizeMask(mask)) ~= 0;
	end

	local function IsAnythingSet(bitMask)
		return NormalizeMask(bitMask) ~= 0;
	end

	local function Combine(lhsFlagOrMask, rhsFlagOrMask, shouldSet)
		if shouldSet == nil then
			shouldSet = true;
		end

		lhsFlagOrMask = NormalizeMask(lhsFlagOrMask);
		rhsFlagOrMask = NormalizeMask(rhsFlagOrMask);

		if shouldSet then
			return bit.bor(lhsFlagOrMask, rhsFlagOrMask);
		end

		return bit.band(lhsFlagOrMask, bit.bnot(rhsFlagOrMask));
	end

	FlagsUtil.CreateMask = CreateMask;
	FlagsUtil.CreateMaskFromTable = CreateMaskFromTable;
	FlagsUtil.MakeFlags = MakeFlags;
	FlagsUtil.IsSet = IsSet;
	FlagsUtil.IsAnySet = IsAnySet;
	FlagsUtil.IsAnythingSet = IsAnythingSet;
	FlagsUtil.Combine = Combine;

	return FlagsUtil;
end);