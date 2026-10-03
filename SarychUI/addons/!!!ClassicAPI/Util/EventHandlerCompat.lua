--[[
	3.3.5 RegisterEvent errors on unknown retail events (GROUP_ROSTER_UPDATE, etc).
	ClassicAPI 1.28 WidgetAPI post-hooks RegisterEvent, so the native call still runs first
	and aborts CompactRaidFrame OnLoad. Wrap RegisterEvent so emulated events reach
	EventHandler even when the client rejects the name.
]]

local _, Private = ...

local PCall = pcall
local CreateFrame = CreateFrame
local GetMetaTable = getmetatable

local EventHandler = Private.EventHandler

local WIDGET_TYPE = {
	"Frame",
	"Button",
	"CheckButton",
	"Cooldown",
	"EditBox",
	"GameTooltip",
	"MessageFrame",
	"Model",
	"PlayerModel",
	"ScrollFrame",
	"ScrollingMessageFrame",
	"SimpleHTML",
	"Slider",
	"StatusBar",
}

local Processed = {}

for i = 1, #WIDGET_TYPE do
	local Success, Object = PCall(CreateFrame, WIDGET_TYPE[i])
	local Metatable = Success and Object and GetMetaTable(Object).__index

	if ( Metatable and not Processed[Metatable] ) then
		Processed[Metatable] = true

		if ( Object.Hide ) then Object:Hide() end

		local NativeRegister = Metatable.RegisterEvent
		local NativeUnregister = Metatable.UnregisterEvent
		local NativeRegisterAll = Metatable.RegisterAllEvents
		local NativeUnregisterAll = Metatable.UnregisterAllEvents

		if ( NativeRegister ) then
			Metatable.RegisterEvent = function(Self, Event)
				EventHandler.RegisterEvent(Self, Event)
				PCall(NativeRegister, Self, Event)
			end
		end

		if ( NativeUnregister ) then
			Metatable.UnregisterEvent = function(Self, Event)
				EventHandler.UnregisterEvent(Self, Event)
				PCall(NativeUnregister, Self, Event)
			end
		end

		if ( NativeRegisterAll ) then
			Metatable.RegisterAllEvents = function(Self)
				EventHandler.RegisterAllEvents(Self)
				PCall(NativeRegisterAll, Self)
			end
		end

		if ( NativeUnregisterAll ) then
			Metatable.UnregisterAllEvents = function(Self)
				EventHandler.UnregisterAllEvents(Self)
				PCall(NativeUnregisterAll, Self)
			end
		end
	end
end
