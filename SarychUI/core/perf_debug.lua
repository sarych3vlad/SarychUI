-- SarychUI frametime diagnostics (temporary, opt-in)
-- Enable in game with: /sperf on

local SarychUI = SarychUI
local strlower = strlower or string.lower
local strlen = strlen or string.len
local strsub = strsub or string.sub

SarychUI_PerfDebug = SarychUI_PerfDebug or false

local BUFFER_SIZE = 100
local FREEZE_WARN = 0.05
local FREEZE_SEVERE = 0.10
local AUTO_DUMP_LINES = 15
local MANUAL_DUMP_LINES = 35
local FREEZE_PRINT_INTERVAL = 0.75

local buffer = {}
local bufferIndex = 0
local bufferCount = 0
local lastFreezePrint = 0

local detector = CreateFrame("Frame")

local function NowMs()
	if debugprofilestop then
		return debugprofilestop()
	end
	if GetTime then
		return GetTime() * 1000
	end
	return 0
end

local function Chat(msg)
	if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage(msg)
	elseif print then
		print(msg)
	end
end

local function SafeText(value)
	if value == nil then
		return ""
	end
	local text = tostring(value)
	if strlen and strlen(text) > 120 then
		return strsub(text, 1, 117) .. "..."
	end
	return text
end

local function PerfLog(source, action, detail)
	if not SarychUI_PerfDebug then
		return
	end

	bufferIndex = bufferIndex + 1
	if bufferIndex > BUFFER_SIZE then
		bufferIndex = 1
	end
	if bufferCount < BUFFER_SIZE then
		bufferCount = bufferCount + 1
	end

	local entry = buffer[bufferIndex]
	if not entry then
		entry = {}
		buffer[bufferIndex] = entry
	end

	entry.t = NowMs()
	entry.source = source or "?"
	entry.action = action or "?"
	entry.detail = SafeText(detail)
end

local function FormatEntry(entry)
	if not entry then
		return nil
	end
	if entry.detail and entry.detail ~= "" then
		return string.format("  %.0fms  %s  %s  %s", entry.t or 0, tostring(entry.source or "?"), tostring(entry.action or "?"), entry.detail)
	end
	return string.format("  %.0fms  %s  %s", entry.t or 0, tostring(entry.source or "?"), tostring(entry.action or "?"))
end

local function Dump(limit)
	limit = limit or MANUAL_DUMP_LINES
	if bufferCount == 0 then
		Chat("|cffffd200[SarychUI PERF]|r log is empty")
		return
	end

	if limit > bufferCount then
		limit = bufferCount
	end

	Chat(string.format("|cffffd200[SarychUI PERF]|r last %d/%d entries:", limit, bufferCount))

	local start = bufferIndex - limit + 1
	while start <= 0 do
		start = start + BUFFER_SIZE
	end

	for i = 1, limit do
		local idx = start + i - 1
		while idx > BUFFER_SIZE do
			idx = idx - BUFFER_SIZE
		end
		local line = FormatEntry(buffer[idx])
		if line then
			Chat(line)
		end
	end
end

local function Clear()
	bufferIndex = 0
	bufferCount = 0
	for i = 1, BUFFER_SIZE do
		buffer[i] = nil
	end
	Chat("|cffffd200[SarychUI PERF]|r log cleared")
end

local function OnUpdate(_, elapsed)
	if not SarychUI_PerfDebug then
		return
	end
	if not elapsed or elapsed <= FREEZE_WARN then
		return
	end

	local now = GetTime and GetTime() or 0
	if (now - lastFreezePrint) < FREEZE_PRINT_INTERVAL then
		return
	end
	lastFreezePrint = now

	local level = elapsed >= FREEZE_SEVERE and "|cffff3333SEVERE|r" or "|cffffff00WARN|r"
	Chat(string.format("|cffffd200[SarychUI PERF]|r %s frame %.1f ms at %.2f", level, elapsed * 1000, now))
	Dump(AUTO_DUMP_LINES)
end

local function SetEnabled(enabled)
	SarychUI_PerfDebug = enabled and true or false
	if SarychUI_PerfDebug then
		lastFreezePrint = 0
		detector:SetScript("OnUpdate", OnUpdate)
		Chat("|cffffd200[SarychUI PERF]|r ON")
	else
		detector:SetScript("OnUpdate", nil)
		Chat("|cffffd200[SarychUI PERF]|r OFF")
	end
end

local function Slow(source, action, startMs, detail, thresholdMs)
	if not SarychUI_PerfDebug or not startMs then
		return
	end
	local elapsed = NowMs() - startMs
	if elapsed >= (thresholdMs or 3) then
		if detail and detail ~= "" then
			PerfLog(source, action, string.format("%.2f ms | %s", elapsed, tostring(detail)))
		else
			PerfLog(source, action, string.format("%.2f ms", elapsed))
		end
	end
	return elapsed
end

SarychUI_PerfLog = PerfLog
SarychUI_PerfSlow = Slow
SarychUI_PerfNow = NowMs
SarychUI_PerfDump = Dump
SarychUI_PerfClear = Clear

if SarychUI then
	SarychUI.PerfLog = PerfLog
	SarychUI.PerfSlow = Slow
	SarychUI.PerfNow = NowMs
	SarychUI.PerfDump = Dump
	SarychUI.PerfClear = Clear
	SarychUI.SetFramePerfDebug = SetEnabled
end

SLASH_SARYCHUIPERF1 = "/sperf"
SlashCmdList["SARYCHUIPERF"] = function(msg)
	msg = (msg and strlower(msg)) or ""
	if msg == "on" then
		Clear()
		SetEnabled(true)
	elseif msg == "off" then
		SetEnabled(false)
	elseif msg == "dump" then
		Dump(MANUAL_DUMP_LINES)
	elseif msg == "clear" then
		Clear()
	elseif msg == "" or msg == "help" then
		Chat("|cffffd200[SarychUI PERF]|r /sperf on | off | dump | clear")
	else
		Chat("|cffffd200[SarychUI PERF]|r unknown command. Use /sperf help")
	end
end
