-- Shared periodic updates for modules that need a single lightweight OnUpdate.
local Scheduler = { callbacks = {} }
SarychUI.UpdateScheduler = Scheduler

local frame = CreateFrame("Frame")
local function OnUpdate(_, elapsed)
	for _, task in pairs(Scheduler.callbacks) do
		task.elapsed = task.elapsed + (elapsed or 0)
		if task.elapsed >= task.interval then
			task.elapsed = 0
			task.callback(GetTime())
		end
	end
end

function Scheduler:RegisterUpdate(key, interval, callback)
	if not key or type(callback) ~= "function" then return end
	self.callbacks[key] = { interval = math.max(tonumber(interval) or 0.1, 0.01), elapsed = 0, callback = callback }
	frame:SetScript("OnUpdate", OnUpdate)
end

function Scheduler:UnregisterUpdate(key)
	self.callbacks[key] = nil
	if not next(self.callbacks) then frame:SetScript("OnUpdate", nil) end
end

function Scheduler:Shutdown()
	for key in pairs(self.callbacks) do self.callbacks[key] = nil end
	frame:SetScript("OnUpdate", nil)
end
