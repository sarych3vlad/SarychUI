local _, Private = ...

local CreateFrame = CreateFrame
local GetMetaTable = getmetatable
local HookSecureFunc = hooksecurefunc

local EventHandler = CreateFrame("Frame")
local ___Register = EventHandler.RegisterEvent
local ___Unregister = EventHandler.UnregisterEvent

local EVENT_ATLAS = {}
local EVENT_OBJECT = {}
local EVENT_ARCHIVE = {}

local ON = {}
local ON_REG = {}
local ON_UREG = {}

local function EventHandler_Fire(Self, Listener, ...)
	local Event = EVENT_ATLAS[Listener] or Listener
	local Registered = EVENT_OBJECT[Event]
	if ( Registered ) then
		local Trigger = ON[Event]
		if ( Trigger and Trigger("OnEvent", Listener, ...) == false ) then return end

		local Shuffle = 1

		for i=1,#Registered do
			local Obj = Registered[i]

			if ( Obj ) then
				local OnEvent = Obj:GetScript("OnEvent")
				if ( OnEvent ) then
					OnEvent(Obj, Event, ...)
				end

				if ( i ~= Shuffle ) then
					Registered[Shuffle] = Obj
					Registered[i] = nil
				end

				Shuffle = Shuffle + 1
			else
				Registered[i] = nil
			end
		end
	end
end

local function EventHandler_Listener(Event, Func)
	local Archive = EVENT_ARCHIVE[Event]
	if ( Archive[1] ) then
		for i=1,#Archive do
			Func(EventHandler, Archive[i])
		end
	else
		Func(EventHandler, Archive)
	end
end

--[[
	EventHandler: Method Hook(s)
]]

local function Method_RegisterEvent(Self, Event)
	local Archive = EVENT_ARCHIVE[Event]

	if ( Archive ) then
		local Registered = EVENT_OBJECT[Event]
		local RegisteredTotal = 0

		if ( Registered ) then
			RegisteredTotal = #Registered
			for i=1,RegisteredTotal do
				if ( Registered[i] == Self ) then
					return
				end
			end
		else
			local Trigger = ON_REG[Event]
			if ( Trigger and Trigger("OnRegister", Event) == false ) then return end

			Registered = {}
			EVENT_OBJECT[Event] = Registered
			EventHandler_Listener(Event, ___Register)
		end

		Registered[RegisteredTotal+1] = Self
	end
end

local function Method_UnregisterEvent(Self, Event)
	local Registered = EVENT_OBJECT[Event]

	if ( Registered ) then
		local RegisteredTotal, RegisteredIndex = 0

		for i=1,#Registered do
			local Obj = Registered[i]
			if ( Obj ) then
				RegisteredTotal = RegisteredTotal+1

				if ( Obj == Self ) then
					RegisteredIndex = i
					if ( RegisteredTotal > 1 ) then break end
				end
			end
		end

		if ( RegisteredIndex ) then
			if ( RegisteredTotal == 1 ) then
				local Trigger = ON_UREG[Event]
				if ( Trigger and Trigger("OnUnregister", Event) == false ) then return end

				EventHandler_Listener(Event, ___Unregister)
				EVENT_OBJECT[Event] = nil
			else
				Registered[RegisteredIndex] = false
			end
		end
	end
end

local function Method_RegisterUnitEvent(Self, Event, Unit1, Unit2)
	local UnitEventFrame = Self.___UnitEventHandler

	if ( not UnitEventFrame ) then
		UnitEventFrame = CreateFrame("Frame")
		Self.___UnitEventHandler = UnitEventFrame

		UnitEventFrame:SetScript("OnEvent", function(_, Event, ...)
			local Units = UnitEventFrame[Event]
			if ( Units ) then
				local Unit = ...
				if ( Units[1] == Unit or Units[2] == Unit ) then
					local OnEvent = Self:GetScript("OnEvent")
					if ( OnEvent ) then
						OnEvent(Self, Event, ...)
					end
				end
			end
		end)

		HookSecureFunc(Self, "UnregisterEvent", function(_, Event)
			if ( UnitEventFrame[Event] ) then
				UnitEventFrame[Event] = nil
				___Unregister(UnitEventFrame, Event) -- Avoid our hook, call directly.
			end
		end)
	end

	local Units = UnitEventFrame[Event]
	if ( not Units ) then
		Units = {}
		UnitEventFrame[Event] = Units
		UnitEventFrame:RegisterEvent(Event)
	end

	Units[1] = Unit1
	if ( Unit2 ) then
		Units[2] = Unit2
	end
end

local function EventHandler_Register(Type, Event, Callback)
	if ( Type == "OnRegister" ) then
		ON_REG[Event] = Callback
	elseif ( Type == "OnUnregister" ) then
		ON_UREG[Event] = Callback
	elseif ( Type == "OnEvent" ) then
		ON[Event] = Callback
	elseif ( Type == "Event" ) then
		--[[
			Register "Event"
			----------
			arg2 (String): Modern Event
			arg3 (String|Table): Authentic Event
		]]
		local Modern, Event = Event, Callback
		EVENT_ARCHIVE[Modern] = (Event) and Event or Modern
		if ( Event ) then
			if ( Event[1] ) then
				for i=1,#Event do
					EVENT_ATLAS[Event[i]] = Modern
				end
			else
				EVENT_ATLAS[Event] = Modern
			end
		end
	end
end

local FrameMeta = GetMetaTable(EventHandler).__index
local ButtonMeta = GetMetaTable(CreateFrame("Button")).__index
FrameMeta.RegisterUnitEvent = Method_RegisterUnitEvent
ButtonMeta.RegisterUnitEvent = Method_RegisterUnitEvent
HookSecureFunc(FrameMeta, "RegisterEvent", Method_RegisterEvent)
HookSecureFunc(FrameMeta, "UnregisterEvent", Method_UnregisterEvent)
HookSecureFunc(ButtonMeta, "RegisterEvent", Method_RegisterEvent)
HookSecureFunc(ButtonMeta, "UnregisterEvent", Method_UnregisterEvent)
EventHandler:SetScript("OnEvent", EventHandler_Fire)

-- Module
EventHandler.Fire = EventHandler_Fire
EventHandler.Register = EventHandler_Register

-- Private Namespace
Private.EventHandler = EventHandler

--[[

	EventHandler: EventTrace Support

]]

local EventTrace = SlashCmdList.EVENTTRACE
function SlashCmdList.EVENTTRACE(MSG)
	EventTrace(MSG)

	local ETF = _G["EventTraceFrame"]
	local function Start()
		for k in pairs(EVENT_ARCHIVE) do ETF:RegisterEvent(k) end
	end
	Start()
	HookSecureFunc("EventTraceFrame_StartEventCapture", Start)
	HookSecureFunc("EventTraceFrame_StopEventCapture", function()
		for k in pairs(EVENT_ARCHIVE) do ETF:UnregisterEvent(k) end
	end)

	SlashCmdList.EVENTTRACE = EventTrace
end