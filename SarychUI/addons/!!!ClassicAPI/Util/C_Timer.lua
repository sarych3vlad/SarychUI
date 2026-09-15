if ( C_Timer ) then return end

local _G = _G
local Type = type
local PCall = pcall
local Ceil = math.ceil
local SetMetaTable = setmetatable
local CallErrorHandler = CallErrorHandler

local C_Timer = CreateFrame("Frame")
local Registry = SetMetaTable({}, { __mode = "k" }) -- Maps Public Proxy -> Internal Timer
local Pool = {}

-- Looping animation groups accumulate elapsed time toward their duration, resetting on loop.
-- Near 2048s, float32 precision drops enough that tiny deltas (<~0.000122s) can get lost.
-- That precision loss is rare, but if it happens, the animation can stall and potentially
-- freeze the client. Splitting intervals into 30-minute chunks avoids the 2048s boundary
-- without affecting standard non-looping timers.
local MAX_CHUNK_DURATION = 1800

local function Release(Timer)
	Timer.Chunk = nil
	Timer.Proxy = nil
	Timer.Callback = nil
	Timer.Iteration = nil
	Timer.ChunkTotal = nil
	Pool[#Pool + 1] = Timer
end

local function Cancel(Proxy)
	local Timer = Registry[Proxy]
	if ( Timer ) then
		Timer:Stop()
		Release(Timer)
		Registry[Proxy] = nil
	end
end

local TimerPrototype = {
	Cancel = Cancel,
	IsCancelled = function(Proxy) return Registry[Proxy] == nil end
} TimerPrototype.__index = TimerPrototype

local function OnFinished(Timer)
	local Chunk = Timer.Chunk
	if ( Chunk ) then
		if ( Chunk > 1 ) then
			Timer.Chunk = Chunk - 1
			return
		end

		Timer.Chunk = Timer.ChunkTotal
	end

	local Success, Err = PCall(Timer.Callback, Timer.Proxy)
	if ( not Success ) then
		CallErrorHandler(Err)
	end

	if ( Timer.Callback ) then
		local Iteration = Timer.Iteration

		if ( Iteration ) then
			if ( Iteration == 1 ) then
				Cancel(Timer.Proxy)
			else
				Timer.Iteration = Iteration - 1
			end
		elseif ( not Timer.Proxy ) then
			Release(Timer)
		end
	end
end

local function Create(Duration, Callback, Iteration, Cancellable)
	local Timer
	local TimerIndex = #Pool
	local Looping = Cancellable and (not Iteration or Iteration > 1)

	if ( TimerIndex > 0 ) then
		Timer = Pool[TimerIndex]
		Pool[TimerIndex] = nil
	else
		local AG = C_Timer:CreateAnimationGroup()
		Timer = AG:CreateAnimation()
		Timer:SetScript("OnFinished", OnFinished)
	end

	if ( Cancellable ) then
		local Proxy = SetMetaTable({}, TimerPrototype)
		Registry[Proxy] = Timer
		Timer.Proxy = Proxy
		Timer.Iteration = Iteration
	end

	if ( Looping and Duration > MAX_CHUNK_DURATION ) then
		local ChunkTotal = Ceil(Duration / MAX_CHUNK_DURATION)
		Timer.Chunk = ChunkTotal
		Timer.ChunkTotal = ChunkTotal
		Duration = Duration / ChunkTotal
	end

	Timer.Callback = Callback
	Timer:GetParent():SetLooping(Looping and "REPEAT" or "NONE")
	Timer:SetDuration(Duration > 0 and Duration or .01)
	Timer:Play()

	return Timer.Proxy
end

function C_Timer.After(Duration, Callback, _)
	if ( Type(Duration) ~= "number" ) then
		Duration, Callback = Callback, _
	end

	Create(Duration, Callback)
end

function C_Timer.NewTimer(Duration, Callback, _)
	if ( Type(Duration) ~= "number" ) then
		Duration, Callback = Callback, _
	end

	return Create(Duration, Callback, 1, true)
end

function C_Timer.NewTicker(Duration, Callback, Iteration, _)
	if ( Type(Duration) ~= "number" ) then
		Duration, Callback, Iteration = Callback, Iteration, _
	end

	return Create(Duration, Callback, Iteration, true)
end

-- Global
_G.C_Timer = C_Timer
C_Timer._version = 2 -- Defined to avoid overwriting by other implementations.