--- **AceTimer-3.0** provides a central facility for registering timers.
-- AceTimer supports one-shot timers and repeating timers. All timers are stored in an efficient
-- data structure that allows easy dispatching and fast rescheduling. Timers can be registered
-- or canceled at any time, even from within a running timer, without conflict or large overhead.\\
-- AceTimer is currently limited to firing timers at a frequency of 0.01s as this is what the WoW timer API
-- restricts us to.
--
-- All `:Schedule` functions will return a handle to the current timer, which you will need to store if you
-- need to cancel the timer you just registered.
--
-- **AceTimer-3.0** can be embeded into your addon, either explicitly by calling AceTimer:Embed(MyAddon) or by
-- specifying it as an embeded library in your AceAddon. All functions will be available on your addon object
-- and can be accessed directly, without having to explicitly call AceTimer itself.\\
-- It is recommended to embed AceTimer, otherwise you'll have to specify a custom `self` on all calls you
-- make into AceTimer.
-- @class file
-- @name AceTimer-3.0
-- @release $Id: AceTimer-3.0.lua 0000 2026-09-15 04:25:00Z tsoukie $

local MAJOR, MINOR = "AceTimer-3.0", 1070 -- Bump minor on changes
local AceTimer, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not AceTimer then return end -- No upgrade needed
AceTimer.activeTimers = AceTimer.activeTimers or {} -- Active timer list
local activeTimers = AceTimer.activeTimers -- Upvalue our private data

-- Lua APIs
local type, unpack, next, error, select = type, unpack, next, error, select
-- WoW APIs
local GetTime, C_TimerNewTimer, C_TimerNewTicker = GetTime, C_Timer.NewTimer, C_Timer.NewTicker

local function dispatch(timer)
	if not activeTimers[timer] or timer:IsCancelled() then return end

	if timer.looping then
		timer.ends = GetTime() + timer.delay
	else
		activeTimers[timer] = nil
	end

	if type(timer.func) == "string" then
		-- We manually set the unpack count to prevent issues with an arg set that contains nil and ends with nil
		-- e.g. local t = {1, 2, nil, 3, nil} print(#t) will result in 2, instead of 5. This fixes said issue.
		timer.object[timer.func](timer.object, unpack(timer, 1, timer.argsCount))
	else
		timer.func(unpack(timer, 1, timer.argsCount))
	end
end

local function new(self, loop, func, delay, ...)
	if delay < 0.01 then
		delay = 0.01 -- Restrict to the lowest time that the C_Timer API allows us
	end

	local argsCount = select("#", ...)
	local timer = loop and C_TimerNewTicker(delay, dispatch) or C_TimerNewTimer(delay, dispatch)
	timer.object = self
	timer.func = func
	timer.looping = loop
	timer.argsCount = argsCount
	timer.delay = delay
	timer.ends = GetTime() + delay

	for i = 1, argsCount do
		timer[i] = select(i, ...)
	end

	activeTimers[timer] = true

	return timer
end

--- Schedule a new one-shot timer.
-- The timer will fire once in `delay` seconds, unless canceled before.
-- @param callback Callback function for the timer pulse (funcref or method name).
-- @param delay Delay for the timer, in seconds.
-- @param ... An optional, unlimited amount of arguments to pass to the callback function.
-- @usage
-- MyAddOn = LibStub("AceAddon-3.0"):NewAddon("MyAddOn", "AceTimer-3.0")
--
-- function MyAddOn:OnEnable()
--   self:ScheduleTimer("TimerFeedback", 5)
-- end
--
-- function MyAddOn:TimerFeedback()
--   print("5 seconds passed")
-- end
function AceTimer:ScheduleTimer(func, delay, ...)
	if not func or not delay then
		error(MAJOR..": ScheduleTimer(callback, delay, args...): 'callback' and 'delay' must have set values.", 2)
	end
	if type(func) == "string" then
		if type(self) ~= "table" then
			error(MAJOR..": ScheduleTimer(callback, delay, args...): 'self' - must be a table.", 2)
		elseif not self[func] then
			error(MAJOR..": ScheduleTimer(callback, delay, args...): Tried to register '"..func.."' as the callback, but it doesn't exist in the module.", 2)
		end
	end
	return new(self, nil, func, delay, ...)
end

--- Schedule a repeating timer.
-- The timer will fire every `delay` seconds, until canceled.
-- @param callback Callback function for the timer pulse (funcref or method name).
-- @param delay Delay for the timer, in seconds.
-- @param ... An optional, unlimited amount of arguments to pass to the callback function.
-- @usage
-- MyAddOn = LibStub("AceAddon-3.0"):NewAddon("MyAddOn", "AceTimer-3.0")
--
-- function MyAddOn:OnEnable()
--   self.timerCount = 0
--   self.testTimer = self:ScheduleRepeatingTimer("TimerFeedback", 5)
-- end
--
-- function MyAddOn:TimerFeedback()
--   self.timerCount = self.timerCount + 1
--   print(("%d seconds passed"):format(5 * self.timerCount))
--   -- run 30 seconds in total
--   if self.timerCount == 6 then
--     self:CancelTimer(self.testTimer)
--   end
-- end
function AceTimer:ScheduleRepeatingTimer(func, delay, ...)
	if not func or not delay then
		error(MAJOR..": ScheduleRepeatingTimer(callback, delay, args...): 'callback' and 'delay' must have set values.", 2)
	end
	if type(func) == "string" then
		if type(self) ~= "table" then
			error(MAJOR..": ScheduleRepeatingTimer(callback, delay, args...): 'self' - must be a table.", 2)
		elseif not self[func] then
			error(MAJOR..": ScheduleRepeatingTimer(callback, delay, args...): Tried to register '"..func.."' as the callback, but it doesn't exist in the module.", 2)
		end
	end
	return new(self, true, func, delay, ...)
end

--- Cancels a timer with the given id, registered by the same addon object as used for `:ScheduleTimer`
-- Both one-shot and repeating timers can be canceled with this function, as long as the `id` is valid
-- and the timer has not fired yet or was canceled before.
-- @param id The id of the timer, as returned by `:ScheduleTimer` or `:ScheduleRepeatingTimer`
function AceTimer:CancelTimer(id)
	if not activeTimers[id] then
		return false
	end

	activeTimers[id] = nil

	if not id:IsCancelled() then
		id:Cancel()
		return true
	end

	return false
end

--- Cancels all timers registered to the current addon object ('self')
function AceTimer:CancelAllTimers()
	for k in next, activeTimers do
		if k.object == self then
			AceTimer.CancelTimer(self, k)
		end
	end
end

--- Returns the time left for a timer with the given id, registered by the current addon object ('self').
-- This function will return 0 when the id is invalid.
-- @param id The id of the timer, as returned by `:ScheduleTimer` or `:ScheduleRepeatingTimer`
-- @return The time left on the timer.
function AceTimer:TimeLeft(id)
	if not activeTimers[id] then
		return 0
	else
		local remaining = id.ends - GetTime()
		return remaining > 0 and remaining or 0
	end
end


-- ---------------------------------------------------------------------
-- Upgrading

if oldminor and oldminor < MINOR then
	-- Kill any legacy OnUpdate or Events from older versions
	if AceTimer.frame then
		AceTimer.frame:SetScript("OnUpdate", nil)
		AceTimer.frame:SetScript("OnEvent", nil)
		AceTimer.frame:UnregisterAllEvents()
		AceTimer.frame = nil
	end

	-- Convert ancient hash-bucket timers (< v10) into activeTimers
	if AceTimer.selfs then
		AceTimer.activeTimers = AceTimer.activeTimers or {}
		for object, timers in next, AceTimer.selfs do
			for handle, timer in next, timers do
				if type(timer) == "table" and timer.callback then
					AceTimer.activeTimers[handle] = timer
				end
			end
		end
	end

	local oldTimers = AceTimer.activeTimers
	AceTimer.activeTimers = {}
	activeTimers = AceTimer.activeTimers

	if oldTimers then
		for handle, timer in next, oldTimers do
			if type(timer) == "table" and not timer.cancelled then
				local callback = timer.func or timer.callback

				if callback then
					local newTimer
					local argsCount = timer.argsCount or (timer.args and #timer.args) or 0
					local args = timer.args or timer

					-- Determine remaining delay
					local delay = timer.delay

					-- Handle Animation-based timers (< v17)
					if type(timer.GetDuration) == "function" then
						timer:GetParent():Stop()
						if not timer.looping then
							delay = timer:GetDuration() - timer:GetElapsed()
						end
					elseif not timer.looping then
						if timer.ends then
							delay = timer.ends - GetTime()
						elseif timer.when then
							delay = timer.when - GetTime()
						end
					end

					delay = (type(delay) == "number" and delay > 0.01) and delay or 0.01

					-- Reschedule
					if timer.looping or (timer.delay and not timer.when) then
						newTimer = AceTimer.ScheduleRepeatingTimer(timer.object, callback, delay, unpack(args, 1, argsCount))
					else
						newTimer = AceTimer.ScheduleTimer(timer.object, callback, delay, unpack(args, 1, argsCount))
					end

					-- Forward legacy table handle calls to C_Timer method
					if type(handle) == "table" then
						handle.cancelled = true
						handle.Cancel = function() AceTimer:CancelTimer(newTimer) end
					end
				end
			end
		end
	end

	-- Clean up dead structure fields from legacy versions
	AceTimer.selfs = nil
	AceTimer.hash = nil
	AceTimer.debug = nil
	AceTimer.inactiveTimers = nil
	AceTimer.hashCompatTable = nil
end

-- ---------------------------------------------------------------------
-- Embed handling

AceTimer.embeds = AceTimer.embeds or {}

local mixins = {
	"ScheduleTimer", "ScheduleRepeatingTimer",
	"CancelTimer", "CancelAllTimers",
	"TimeLeft"
}

function AceTimer:Embed(target)
	AceTimer.embeds[target] = true
	for _,v in next, mixins do
		target[v] = AceTimer[v]
	end
	return target
end

-- AceTimer:OnEmbedDisable(target)
-- target (object) - target object that AceTimer is embedded in.
--
-- cancel all timers registered for the object
function AceTimer:OnEmbedDisable(target)
	target:CancelAllTimers()
end

for addon in next, AceTimer.embeds do
	AceTimer:Embed(addon)
end