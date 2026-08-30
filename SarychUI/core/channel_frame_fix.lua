--[[
	WoWCircle / WotLK clients often stub voice chat APIs with booleans or strings.
	ChannelFrame.lua then crashes in ChannelPulloutRoster_*:
	'for' initial/limit must be a number
]]

local wrappedNumericGlobals = {}
local wrappedFunctions = {}

local function ToNumber(value, fallback)
	fallback = fallback or 0
	if value == nil then
		return fallback
	end
	if type(value) == "number" then
		return value
	end
	if type(value) == "boolean" then
		return value and 1 or 0
	end
	return tonumber(value) or fallback
end

local function WrapNumericGlobal(name)
	if wrappedNumericGlobals[name] then
		return
	end

	local orig = _G[name]
	if type(orig) ~= "function" then
		return
	end

	local wrapper = function(...)
		return ToNumber(orig(...))
	end
	wrappedNumericGlobals[name] = true
	_G[name] = wrapper
end

local function SafeTableLength(tbl)
	if type(tbl) ~= "table" then
		return 0
	end
	return ToNumber(#tbl, 0)
end

local function SanitizeChannelPulloutRoster(roster)
	if type(roster) ~= "table" then
		return
	end
	if type(roster.buttons) ~= "table" then
		roster.buttons = {}
	end
	if type(roster.members) ~= "table" then
		roster.members = {}
	end
	if type(roster.freeButtons) ~= "table" then
		roster.freeButtons = {}
	end
	roster.offset = ToNumber(roster.offset, 0)
end

local function SafeChannelPulloutRoster_Update(roster)
	roster = roster or _G.rosterFrame
	SanitizeChannelPulloutRoster(roster)
	if not roster then
		return
	end

	local nameIndex = 1
	local buttonCount = SafeTableLength(roster.buttons)
	local options = _G.CHANNELPULLOUT_OPTIONS or {}
	local emptyData = _G.CHANNEL_EMPTY_DATA
	if type(emptyData) ~= "table" then
		emptyData = { UnitName("player") or "", false, false, false }
		_G.CHANNEL_EMPTY_DATA = emptyData
	end

	local gray = _G.GRAY_FONT_COLOR_CODE or "|cff808080"
	local noSessions = _G.NO_VOICE_SESSIONS or "No channel"

	if not options.session then
		emptyData[nameIndex] = gray .. noSessions
		if buttonCount >= 1 and roster.buttons[1] then
			_G.ChannelPulloutRoster_DrawButton(roster.buttons[1], emptyData)
		end
		for i = 2, buttonCount do
			_G.ChannelPulloutRoster_DrawButton(roster.buttons[i], nil)
		end
		return
	end

	if SafeTableLength(roster.members) == 0 then
		emptyData[nameIndex] = UnitName("player") or ""
		if buttonCount >= 1 and roster.buttons[1] then
			_G.ChannelPulloutRoster_DrawButton(roster.buttons[1], emptyData)
		end
		for i = 2, buttonCount do
			_G.ChannelPulloutRoster_DrawButton(roster.buttons[i], nil)
		end
		return
	end

	local offset = ToNumber(roster.offset, 0)
	for i = 1, buttonCount do
		_G.ChannelPulloutRoster_DrawButton(roster.buttons[i], roster.members[i + offset])
	end
end

local function WrapFunction(name, handler)
	if wrappedFunctions[name] then
		return
	end
	if type(_G[name]) ~= "function" then
		return
	end

	local orig = _G[name]
	local wrapper = handler(orig)
	wrappedFunctions[name] = true
	_G[name] = wrapper
end

local function ApplyChannelFrameFixes()
	WrapNumericGlobal("GetNumVoiceSessions")
	WrapNumericGlobal("GetNumVoiceSessionMembersBySessionID")

	WrapFunction("ChannelPulloutRoster_GetSessionInfo", function(orig)
		return function(roster)
			SanitizeChannelPulloutRoster(roster or _G.rosterFrame)
			if _G.CHANNELPULLOUT_OPTIONS and _G.CHANNELPULLOUT_OPTIONS.session ~= nil then
				local session = ToNumber(_G.CHANNELPULLOUT_OPTIONS.session, _G.CHANNELPULLOUT_OPTIONS.session)
				if type(session) == "number" then
					_G.CHANNELPULLOUT_OPTIONS.session = session
				end
			end
			return orig(roster)
		end
	end)

	WrapFunction("ChannelPulloutRoster_Populate", function(orig)
		return function(roster, templateName, maxButtons)
			SanitizeChannelPulloutRoster(roster or _G.rosterFrame)
			if maxButtons ~= nil then
				maxButtons = ToNumber(maxButtons, nil)
				if type(maxButtons) ~= "number" then
					maxButtons = nil
				end
			end
			return orig(roster, templateName, maxButtons)
		end
	end)

	WrapFunction("ChannelPulloutRoster_Update", function(_orig)
		return function(roster)
			return SafeChannelPulloutRoster_Update(roster)
		end
	end)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event)
	ApplyChannelFrameFixes()
	if event == "PLAYER_LOGIN" then
		self:UnregisterEvent("PLAYER_LOGIN")
	end
end)

ApplyChannelFrameFixes()
