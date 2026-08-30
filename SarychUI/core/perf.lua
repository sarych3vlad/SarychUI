-- SarychUI general performance diagnostics (opt-in)
-- Enable: _G.SarychUI_DebugPerf = true  or  /sui perf on

local SarychUI = SarychUI
if not SarychUI then
	return
end

local PERF_PREFIX = "|cffffd200SarychUI Perf:|r"
local SLOW_THRESHOLD_MS = 5

SarychUI.Perf = SarychUI.Perf or {
	enabled = false,
	startupStages = {},
	startupTotalMs = nil,
	loginMemBeforeKB = nil,
	loginMemAfterKB = nil,
	loginMemDeltaKB = nil,
	counters = {},
	lastHeavyStage = nil,
	onUpdateHooks = {},
	eventRegistrations = 0,
	_initialized = false,
}

local Perf = SarychUI.Perf

local function NowMs()
	if debugprofilestop then
		return debugprofilestop()
	end
	return (GetTime and GetTime() or 0) * 1000
end

local function MemKB()
	if collectgarbage then
		return collectgarbage("count")
	end
	return 0
end

local function IsEnabled()
	return Perf.enabled == true or _G.SarychUI_DebugPerf == true
end

function SarychUI:IsPerfEnabled()
	return IsEnabled()
end

function SarychUI:PerfCounter(name, delta)
	local n = Perf.counters[name] or 0
	Perf.counters[name] = n + (delta or 1)
end

function SarychUI:PerfSetCounter(name, value)
	Perf.counters[name] = value
end

function SarychUI:PerfNoteHeavy(stage, elapsedMs)
	if not stage then
		return
	end
	Perf.lastHeavyStage = {
		name = stage,
		ms = elapsedMs or 0,
		at = GetTime and GetTime() or 0,
	}
end

function SarychUI:RegisterPerfOnUpdate(name, frame)
	if not name or not frame then
		return
	end
	Perf.onUpdateHooks[name] = frame
end

function SarychUI:UnregisterPerfOnUpdate(name)
	if name then
		Perf.onUpdateHooks[name] = nil
	end
end

function SarychUI_ProfileStartupStage(name, fn, ...)
	if type(fn) ~= "function" then
		return fn
	end
	local start = NowMs()
	local ok, a, b, c, d, e, f, g, h, i, j = pcall(fn, ...)
	local elapsed = NowMs() - start
	if not ok then
		if IsEnabled() then
			print(string.format("%s %s took %.2f ms (ERROR)", PERF_PREFIX, tostring(name), elapsed))
		end
		error(a, 0)
	end
	Perf.startupStages[#Perf.startupStages + 1] = {
		name = name,
		ms = elapsed,
	}
	if elapsed >= SLOW_THRESHOLD_MS then
		SarychUI:PerfNoteHeavy(name, elapsed)
		if IsEnabled() then
			print(string.format("%s %s took %.2f ms", PERF_PREFIX, tostring(name), elapsed))
		end
	end
	return a, b, c, d, e, f, g, h, i, j
end

function SarychUI:BeginStartupPerf(source)
	Perf._startupBegin = NowMs()
	Perf.loginMemBeforeKB = MemKB()
	Perf.startupStages = {}
	if IsEnabled() then
		print(string.format("%s startup begin (%s) mem=%.1f KB", PERF_PREFIX, source or "?", Perf.loginMemBeforeKB))
	end
end

function SarychUI:EndStartupPerf(note)
	if not Perf._startupBegin then
		return
	end
	Perf.startupTotalMs = NowMs() - Perf._startupBegin
	Perf.loginMemAfterKB = MemKB()
	Perf.loginMemDeltaKB = Perf.loginMemAfterKB - (Perf.loginMemBeforeKB or 0)
	Perf._startupBegin = nil
	if IsEnabled() then
		print(string.format(
			"%s startup total %.2f ms | memory %.1f -> %.1f KB (delta %+.1f KB)%s",
			PERF_PREFIX,
			Perf.startupTotalMs,
			Perf.loginMemBeforeKB or 0,
			Perf.loginMemAfterKB or 0,
			Perf.loginMemDeltaKB or 0,
			note and (" | " .. note) or ""
		))
	end
end

function SarychUI:CountRegisteredEvents()
	local count = 0
	if self.events then
		for _ in pairs(self.events) do
			count = count + 1
		end
	end
	Perf.eventRegistrations = count
	return count
end

function SarychUI:CountActiveOnUpdateHooks()
	local count = 0
	for _, frame in pairs(Perf.onUpdateHooks) do
		if frame and frame.GetScript and frame:GetScript("OnUpdate") then
			count = count + 1
		end
	end
	return count
end

local function SortedStartupStages()
	local stages = {}
	for i = 1, #(Perf.startupStages or {}) do
		stages[i] = Perf.startupStages[i]
	end
	table.sort(stages, function(a, b)
		return (a.ms or 0) > (b.ms or 0)
	end)
	return stages
end

function SarychUI:TogglePerfDebug(enable)
	if enable == nil then
		enable = not IsEnabled()
	end
	Perf.enabled = enable and true or false
	_G.SarychUI_DebugPerf = Perf.enabled
	print(string.format("%s debug %s", PERF_PREFIX, Perf.enabled and "ON" or "OFF"))
	return Perf.enabled
end

function SarychUI:PrintPerfSummary()
	print(PERF_PREFIX .. " === summary ===")

	if Perf.startupTotalMs then
		print(string.format("  startup total: %.2f ms", Perf.startupTotalMs))
	end
	if Perf.loginMemDeltaKB then
		print(string.format("  login memory delta: %+.1f KB", Perf.loginMemDeltaKB))
	end

	local mem = MemKB()
	print(string.format("  current Lua memory: %.1f KB", mem))

	local stages = SortedStartupStages()
	if #stages > 0 then
		print("  top slow startup stages:")
		local limit = math.min(10, #stages)
		for i = 1, limit do
			local s = stages[i]
			print(string.format("    %2d. %.2f ms  %s", i, s.ms or 0, s.name or "?"))
		end
	end

	local optPerf = SarychUI.OptionsPerf
	local optSession = optPerf and (optPerf.lastSession or optPerf.activeSession)
	if optSession and optSession.totalMs then
		print(string.format("  options open last total: %.2f ms", optSession.totalMs))
	elseif optSession and optSession.startedAt then
		print("  options open: сессия активна (ещё не завершена) — /sui perfoptions summary")
	end

	print(string.format("  tracked OnUpdate hooks: %d active / %d registered",
		self:CountActiveOnUpdateHooks(),
		(function()
			local n = 0
			for _ in pairs(Perf.onUpdateHooks) do n = n + 1 end
			return n
		end)()
	))

	self:CountRegisteredEvents()
	print(string.format("  SarychUI core events: %d", Perf.eventRegistrations or 0))

	local c = Perf.counters or {}
	print(string.format("  minimap scan count: %d", c.minimapScan or 0))
	print(string.format("  options rebuild count: %d", c.optionsRebuild or 0))
	print(string.format("  addon options rebuild count: %d", c.addonOptionsRebuild or 0))

	local flags = {}
	if _G.SarychUI_DebugPerf then flags[#flags + 1] = "SarychUI_DebugPerf (startup)" end
	if _G.SarychUI_DebugOptionsPerf then flags[#flags + 1] = "SarychUI_DebugOptionsPerf (open)" end
	if _G.SarychUI_DebugPerf and not _G.SarychUI_DebugOptionsPerf then
		print("  hint: для замера open настроек нужен SarychUI_DebugOptionsPerf → /sui perfoptions")
	end
	if _G.SarychUI_DebugCombatOptions then flags[#flags + 1] = "SarychUI_DebugCombatOptions" end
	if flags[1] then
		print("  active debug flags: " .. table.concat(flags, ", "))
	else
		print("  active debug flags: (none)")
	end

	if Perf.lastHeavyStage then
		print(string.format("  last heavy stage: %s (%.2f ms)",
			Perf.lastHeavyStage.name or "?",
			Perf.lastHeavyStage.ms or 0
		))
	end
end

function SarychUI:RunPerfReport()
	self:TogglePerfDebug(true)
	self:PrintPerfSummary()
	local optPerf = SarychUI.OptionsPerf
	local optSession = optPerf and (optPerf.lastSession or optPerf.activeSession)
	if self.PrintOptionsPerfSummary then
		if optSession then
			self:PrintOptionsPerfSummary()
		else
			print(PERF_PREFIX .. " options open: сессия не записана.")
			print(PERF_PREFIX .. " Для замера открытия настроек: |cff00ff00/sui perfoptions|r (откроет окно и замерит)")
			print(PERF_PREFIX .. " или: |cff00ff00/sui perfoptions on|r → |cff00ff00/sui|r → |cff00ff00/sui perfoptions summary|r")
		end
	end
end
