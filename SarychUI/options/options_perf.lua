-- SarychUI options open performance diagnostics (opt-in)
-- Enable: _G.SarychUI_DebugOptionsPerf = true  or  /sui perfoptions

local SarychUI = SarychUI
if not SarychUI then
	return
end

local PERF_PREFIX = "|cffffd200SarychUI OptionsPerf:|r"
local SLOW_THRESHOLD_MS = 5

SarychUI.OptionsPerf = SarychUI.OptionsPerf or {
	enabled = false,
	activeSession = nil,
	lastSession = nil,
	flags = {},
}

local Perf = SarychUI.OptionsPerf

local perfEndDriver = CreateFrame("Frame")
perfEndDriver:Hide()

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
	return Perf.enabled == true or _G.SarychUI_DebugOptionsPerf == true
end

function SarychUI:IsOptionsPerfEnabled()
	return IsEnabled()
end

function SarychUI:OptionsPerfLogSkip(stage, extra)
	if not IsEnabled() then
		return
	end
	local session = Perf.activeSession or Perf.lastSession
	if session then
		session.stages[#session.stages + 1] = {
			name = stage,
			ms = 0,
			extra = extra,
		}
	end
end

function SarychUI:OptionsPerfLog(stage, elapsedMs, extra)
	if not IsEnabled() then
		return
	end
	local msg = string.format("%s %s took %.2f ms", PERF_PREFIX, tostring(stage), elapsedMs or 0)
	if extra then
		msg = msg .. " (" .. tostring(extra) .. ")"
	end
	if elapsedMs and elapsedMs >= SLOW_THRESHOLD_MS then
		print(msg)
	end
	local session = Perf.activeSession or Perf.lastSession
	if session then
		session.stages[#session.stages + 1] = {
			name = stage,
			ms = elapsedMs or 0,
			extra = extra,
		}
		if elapsedMs and elapsedMs > (session.slowestMs or 0) then
			session.slowestMs = elapsedMs
			session.slowestStage = stage
		end
	end
	if SarychUI.PerfNoteHeavy and elapsedMs and elapsedMs >= SLOW_THRESHOLD_MS then
		SarychUI:PerfNoteHeavy("options:" .. tostring(stage), elapsedMs)
	end
end

function SarychUI_ProfileOptionsStage(name, fn, ...)
	if type(fn) ~= "function" then
		return fn
	end
	if not IsEnabled() then
		return fn(...)
	end
	local start = NowMs()
	local ok, a, b, c, d, e, f, g, h, i, j = pcall(fn, ...)
	local elapsed = NowMs() - start
	if not ok then
		SarychUI:OptionsPerfLog(name, elapsed, "ERROR")
		error(a, 0)
	end
	SarychUI:OptionsPerfLog(name, elapsed)
	return a, b, c, d, e, f, g, h, i, j
end

function SarychUI:BeginOptionsOpenPerf(source)
	if not IsEnabled() then
		Perf.activeSession = nil
		return
	end
	if Perf.activeSession then
		Perf.activeSession.source = source or Perf.activeSession.source
		return
	end
	Perf._endScheduled = false
	Perf.activeSession = {
		source = source or "unknown",
		startedAt = NowMs(),
		memBeforeKB = MemKB(),
		stages = {},
		slowestMs = 0,
		slowestStage = nil,
		flags = {},
	}
	Perf.flags = Perf.activeSession.flags
	print(string.format("%s begin open (%s) mem=%.1f KB", PERF_PREFIX, source or "?", Perf.activeSession.memBeforeKB))
end

function SarychUI:EndOptionsOpenPerf(note)
	if not IsEnabled() or not Perf.activeSession then
		return
	end
	local session = Perf.activeSession
	session.endedAt = NowMs()
	session.totalMs = session.endedAt - session.startedAt
	session.memAfterKB = MemKB()
	session.memDeltaKB = session.memAfterKB - (session.memBeforeKB or 0)
	session.note = note
	Perf.lastSession = session
	Perf.activeSession = nil

	print(string.format(
		"%s total open took %.2f ms | memory %.1f -> %.1f KB (delta %+.1f KB)%s",
		PERF_PREFIX,
		session.totalMs,
		session.memBeforeKB,
		session.memAfterKB,
		session.memDeltaKB,
		note and (" | " .. note) or ""
	))
end

function SarychUI:ScheduleOptionsOpenPerfEnd(delay, note)
	if not IsEnabled() or not Perf.activeSession then
		return
	end
	Perf._pendingEndNote = note or Perf._pendingEndNote
	local wait = delay or 0.35
	if Perf._endScheduled then
		return
	end
	Perf._endScheduled = true

	local function finishEnd()
		Perf._endScheduled = false
		perfEndDriver:Hide()
		perfEndDriver:SetScript("OnUpdate", nil)
		if Perf.activeSession then
			SarychUI:EndOptionsOpenPerf(Perf._pendingEndNote or "deferred")
		end
		Perf._pendingEndNote = nil
	end

	-- Frame OnUpdate is more reliable than C_Timer on some 3.3.5 clients.
	local elapsed = 0
	perfEndDriver:Show()
	perfEndDriver:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + (dt or 0)
		if elapsed >= wait then
			finishEnd()
		end
	end)
end

function SarychUI:FinalizeOptionsOpenPerfIfNeeded(note)
	if IsEnabled() and Perf.activeSession then
		Perf._endScheduled = false
		self:EndOptionsOpenPerf(note or "finalized")
	end
end

function SarychUI:OptionsPerfFlag(key, value)
	if not IsEnabled() then
		return
	end
	local session = Perf.activeSession or Perf.lastSession
	if session then
		session.flags[key] = value
	end
end

function SarychUI:ToggleOptionsPerfDebug(enable)
	if enable == nil then
		enable = not IsEnabled()
	end
	Perf.enabled = enable and true or false
	_G.SarychUI_DebugOptionsPerf = Perf.enabled
	print(string.format("%s perf debug %s", PERF_PREFIX, Perf.enabled and "ON" or "OFF"))
	return Perf.enabled
end

function SarychUI:PrintOptionsPerfSummary()
	if Perf.activeSession then
		self:FinalizeOptionsOpenPerfIfNeeded("summary")
	end
	local session = Perf.lastSession
	if not session then
		print(PERF_PREFIX .. " no session recorded yet")
		print(PERF_PREFIX .. " Запустите: |cff00ff00/sui perfoptions|r, подождите ~0.5 с, затем |cff00ff00/sui perfoptions summary|r")
		return
	end

	print(PERF_PREFIX .. " === summary ===")
	print(string.format("  source: %s", session.source or "?"))
	if session.totalMs then
		print(string.format("  total: %.2f ms", session.totalMs))
	end
	if session.memDeltaKB then
		print(string.format("  memory delta: %+.1f KB", session.memDeltaKB))
	end

	local stages = session.stages or {}
	table.sort(stages, function(a, b)
		return (a.ms or 0) > (b.ms or 0)
	end)

	print("  top slow stages:")
	local limit = math.min(10, #stages)
	for i = 1, limit do
		local s = stages[i]
		print(string.format("    %2d. %.2f ms  %s%s", i, s.ms or 0, s.name or "?", s.extra and (" (" .. s.extra .. ")") or ""))
	end

	if session.flags and next(session.flags) then
		print("  flags:")
		for k, v in pairs(session.flags) do
			print(string.format("    %s = %s", tostring(k), tostring(v)))
		end
		local scanRan = session.flags.minimapScanManual or session.flags.minimapScanOnOpen
		print(string.format("  minimap button scan on open: %s", scanRan and "yes" or "no (expected)"))
		local fullRebuild = not session.flags.configFrameReused
		print(string.format("  config frame: %s", session.flags.configFrameReused and "reused" or (session.flags.configFrameCreated and "created" or "unchanged")))
		if session.flags.RegisterOptionsTableOnOpen then
			print("  RegisterOptionsTable called on this open: yes")
		else
			print("  RegisterOptionsTable called on this open: no")
		end
		if session.flags.addonOptionsSkipped then
			print("  addon options: skipped (cached)")
		elseif session.flags.addonOptionsRebuilt then
			print("  addon options: rebuilt")
			if session.flags.addonOptionsDirtyReason then
				print(string.format("  addon options dirty reason: %s", session.flags.addonOptionsDirtyReason))
			end
		end
	end
end

function SarychUI:RunOptionsPerfOpen()
	if not self:IsOptionsPerfEnabled() then
		self:ToggleOptionsPerfDebug(true)
	end
	if self.OpenOptions then
		self:OpenOptions()
	elseif self.OpenOptionsPanel then
		self:OpenOptionsPanel()
	end
end
