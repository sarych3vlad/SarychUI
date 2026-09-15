--[[
	ClassicAPI 1.27 moved the widget method injection into WidgetAPI.lua, which SarychUI
	does not load (the widget layer comes from SharedExtendedMethods.lua instead).
	Without it, frames calling RegisterEvent("GROUP_ROSTER_UPDATE") and friends would
	never receive the emulated events, so the same hooks are installed here.
]]

local _, Private = ...

local PCall = pcall
local CreateFrame = CreateFrame
local GetMetaTable = getmetatable
local HookSecureFunc = hooksecurefunc

local EventHandler = Private.EventHandler

--[[ EventHandler: Widget Method Injection ]]

-- Frame types of 3.3.5 that can register events. Each has its own metatable.
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

local POST_HOOK = {
	"RegisterEvent",
	"UnregisterEvent",
	"RegisterAllEvents",
	"UnregisterAllEvents",
}

local METHOD = {
	RegisterUnitEvent = EventHandler.RegisterUnitEvent,
	RegisterEventCallback = EventHandler.RegisterEventCallback,
	RegisterUnitEventCallback = EventHandler.RegisterUnitEventCallback,
	UnregisterEventCallback = EventHandler.UnregisterEventCallback,
	UnregisterUnitEventCallback = EventHandler.UnregisterUnitEventCallback,
}

local Processed = {}

for i = 1, #WIDGET_TYPE do
	local Success, Object = PCall(CreateFrame, WIDGET_TYPE[i])
	local Metatable = Success and Object and GetMetaTable(Object).__index

	if ( Metatable and not Processed[Metatable] ) then
		Processed[Metatable] = true

		if ( Object.Hide ) then Object:Hide() end

		for Method, Function in pairs(METHOD) do
			Metatable[Method] = Function
		end

		for j = 1, #POST_HOOK do
			local Method = POST_HOOK[j]
			if ( Metatable[Method] ) then
				HookSecureFunc(Metatable, Method, EventHandler[Method])
			end
		end
	end
end
