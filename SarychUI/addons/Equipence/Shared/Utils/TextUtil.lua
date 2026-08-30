--[[
    Equipence
    Copyright (c) 2026 s0high. All rights reserved.

    Source-available proprietary software. See LICENSE for terms.
]]

--@class Engine<ns>
local Engine = select(2, ...);

--@natives<lua>
local strtrim = strtrim;

-- TextUtil provides small text normalization helpers shared by tooltip and item text parsing.
--

--@class Utils<shared>
local TextUtil = {};

function TextUtil.EscapePattern(text)
	return (text:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"));
end

function TextUtil.StripColorCodes(text)
	if not text then
		return nil;
	end

	text = text:gsub("|c%x%x%x%x%x%x%x%x", "");
	text = text:gsub("|r", "");
	return text;
end

function TextUtil.NormalizeTooltipText(text)
	if not text then
		return nil;
	end

	text = TextUtil.StripColorCodes(text);
	text = strtrim(text);

	if text == "" then
		return nil;
	end

	return text;
end

Engine.Shared.Utils.TextUtil = TextUtil;
