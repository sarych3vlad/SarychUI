-- SarychUI.Runtime - native Lua runtime services for WoW 3.3.5a.
--
-- One frame owns the cached clock, periodic dispatcher, runtime backends, and
-- optional diagnostics.  SarychUI stays fully standalone unless
-- wow_optimize.dll is positively identified.  Ownership is selected per
-- capability: the DLL gets only the engine work it actually exposes, while
-- every missing capability keeps its SarychUI fallback.

local pairs, ipairs, type, tostring, tonumber, next = pairs, ipairs, type, tostring, tonumber, next
local floor, min, max = math.floor, math.min, math.max
local format, lower = string.format, string.lower
local tinsert, tsort = table.insert, table.sort
local CreateFrame, GetTime = CreateFrame, GetTime
local pcall, select = pcall, select
local getmetatable, setmetatable = getmetatable, setmetatable
local geterrorhandler = geterrorhandler
local collectgarbage = collectgarbage
local debug_getinfo = debug and debug.getinfo
local debugprofilestart, debugprofilestop = debugprofilestart, debugprofilestop
local UnitAffectingCombat = UnitAffectingCombat
local hooksecurefunc = hooksecurefunc
local wipe = wipe or function(t) for k in pairs(t) do t[k] = nil end end

local Runtime = {
	VERSION = "3.3.0",
	WOW_OPTIMIZE_NOT_FOUND = "WOW_OPTIMIZE_NOT_FOUND",
	WOW_OPTIMIZE_SUPPORTED = "WOW_OPTIMIZE_SUPPORTED",
	WOW_OPTIMIZE_INCOMPATIBLE = "WOW_OPTIMIZE_INCOMPATIBLE",
	backend = "standalone",
	backends = {},
	_initialized = false,
	_enabled = false,
	_coreFrame = nil,
	_eventFrame = nil,
	_handlers = {},
	_eventsBound = false,

	_cachedTime = 0,
	_frameNumber = 0,
	_inCombat = false,
	_isIdle = false,
	_isLoading = false,
	_lastActivity = 0,

	_updateCallbacks = {},
	_updateCount = 0,
	_nextDispatchAt = 0,
	_dispatchGeneration = 0,
	_dispatchStats = { calls = 0, errors = 0, frames = 0, wakeups = 0, skippedFrames = 0 },
	_throttles = {},
	_throttleStats = { allowed = 0, blocked = 0 },

	_pools = {},
	_poolOwners = setmetatable({}, { __mode = "k" }),
	_poolAvailable = 0,
	_poolStats = { acquired = 0, released = 0, created = 0, rejected = 0 },

	_gcOwnsLua = false,
	_gcLastMemoryCheck = 0,
	_gcLastRestop = 0,
	_gcStats = {
		steps = 0,
		burstSteps = 0,
		delegatedSteps = 0,
		fullCollects = 0,
		delegatedFullCollects = 0,
		emergencyGC = 0,
		freedMB = 0,
		lastFullMs = 0,
	},
	_adaptiveThresholdMB = nil,
	_backendImpl = nil,
	_backendLastProbe = 0,
	_backendProbeDeadline = 0,
	_backendSwitches = 0,
	_dllGcOwner = false,
	_dllObserverLast = 0,
	_dllObserverPolls = 0,
	_dllObserverSkipped = 0,
	_dll = {
		state = "WOW_OPTIMIZE_NOT_FOUND",
		detected = false,
		version = nil,
		reason = "not_found",
		gcActive = false,
	},

	_frameStats = {
		lastMs = 0,
		averageMs = 0,
		minMs = 0,
		maxMs = 0,
		fps = 0,
		samples = 0,
		windowElapsed = 0,
		windowFrames = 0,
		updates = 0,
	},
	_fpsProfile = { active = false, samples = {}, count = 0 },
	_eventProfile = { active = false, counts = {}, startTime = 0, duration = 10 },
	_memoryProfile = nil,

	_speedy = {
		available = type(GetFramesRegisteredForEvent) == "function",
		frame = nil,
		tracked = {},
		occurred = {},
		suppressed = false,
		listenUnregister = false,
		hooked = false,
		priorityReady = false,
		stats = { cycles = 0, suppressed = 0, restored = 0, occurred = 0 },
	},
}

SarychUI.Runtime = Runtime

local PRESETS = {
	light = {
		frameStepKB = 20,
		combatStepKB = 5,
		idleStepKB = 80,
		loadingStepKB = 150,
		fullCollectThresholdMB = 150,
		idleTimeout = 15,
	},
	standard = {
		frameStepKB = 50,
		combatStepKB = 15,
		idleStepKB = 150,
		loadingStepKB = 300,
		fullCollectThresholdMB = 300,
		idleTimeout = 15,
	},
	heavy = {
		frameStepKB = 100,
		combatStepKB = 30,
		idleStepKB = 300,
		loadingStepKB = 500,
		fullCollectThresholdMB = 500,
		idleTimeout = 20,
	},
}

local SPEEDY_SAFE_EVENTS = {
	"SPELLS_CHANGED",
	"SPELL_UPDATE_USABLE",
	"ACTIONBAR_SLOT_CHANGED",
	"USE_GLYPH",
	"PLAYER_TALENT_UPDATE",
	"PET_TALENT_UPDATE",
	"WORLD_MAP_UPDATE",
	"UPDATE_WORLD_STATES",
	"UPDATE_FACTION",
	"CRITERIA_UPDATE",
	"RECEIVED_ACHIEVEMENT_LIST",
}

local SPEEDY_AGGRESSIVE_EXTRA = {
	"ACTIONBAR_UPDATE_STATE",
	"ACTIONBAR_UPDATE_USABLE",
	"ACTIONBAR_UPDATE_COOLDOWN",
	"SPELL_UPDATE_COOLDOWN",
	"UNIT_AURA",
	"UNIT_INVENTORY_CHANGED",
	"BAG_UPDATE",
	"QUEST_LOG_UPDATE",
	"COMPANION_UPDATE",
	"PET_BAR_UPDATE",
	"TRADE_SKILL_UPDATE",
	"MERCHANT_UPDATE",
}

local ACTIVITY_EVENTS = {
	"PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING",
	"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED",
	"CHAT_MSG_SAY", "CHAT_MSG_PARTY", "CHAT_MSG_RAID",
	"CHAT_MSG_GUILD", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
	"LOOT_OPENED", "BAG_UPDATE", "ACTIONBAR_UPDATE_STATE",
	"MERCHANT_SHOW", "AUCTION_HOUSE_SHOW", "BANKFRAME_OPENED",
	"MAIL_SHOW", "QUEST_DETAIL",
}

local BURST_EVENTS = {
	"LFG_PROPOSAL_SHOW",
	"LFG_PROPOSAL_SUCCEEDED",
	"LFG_COMPLETION_REWARD",
	"ACHIEVEMENT_EARNED",
	"CHAT_MSG_LOOT",
}

local function RuntimeDB()
	local profile = SarychUI and SarychUI.db and SarychUI.db.profile
	local system = profile and profile.system
	return system and system.runtime
end

local function SystemDB()
	local profile = SarychUI and SarychUI.db and SarychUI.db.profile
	return profile and profile.system
end

local function LText(key, fallback)
	local L = SarychUI and SarychUI.L
	return (L and L[key]) or fallback or key
end

local function Chat(text)
	if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage(text)
	elseif print then
		print(text)
	end
end

local function Prefix()
	if SarychUI and SarychUI.GetScopedChatPrefix then
		return SarychUI:GetScopedChatPrefix("Runtime")
	end
	return "|cff00ccffSarychUI Runtime:|r"
end

local function ReportError(err)
	Runtime._dispatchStats.errors = Runtime._dispatchStats.errors + 1
	if geterrorhandler then
		geterrorhandler()(err)
	end
end

local function DebugPrint(message)
	local cfg = RuntimeDB()
	if cfg and cfg.debug then
		Chat(Prefix() .. " " .. tostring(message))
	end
end

-- -------------------------------------------------------------------------
-- Runtime backend detection and adapters
-- -------------------------------------------------------------------------

local DLL_GC_API = {
	"LuaBoostC_IsLoaded",
	"LuaBoostC_GetStats",
	"LuaBoostC_GCMemory",
	"LuaBoostC_SetCombat",
	"LuaBoostC_GCStep",
	"LuaBoostC_GCCollect",
}

local function IsDLLTrue(value)
	return value ~= nil and value ~= false and value ~= 0
		and value ~= "0" and value ~= "false" and value ~= "FALSE"
end

local function IsNativeFunction(value)
	if type(value) ~= "function" or type(debug_getinfo) ~= "function" then return false end
	local ok, info = pcall(debug_getinfo, value, "S")
	return ok and info and info.what == "C" or false
end

local function HasWowOptimizeMarker()
	if _G.LUABOOST_DLL_LOADED ~= nil
		or _G.LUABOOST_DLL_GC_ACTIVE ~= nil
		or _G.LUABOOST_DLL_LUA_ALLOC ~= nil
		or _G.LUABOOST_DLL_FASTPATH_ACTIVE ~= nil
		or _G.LUABOOST_DLL_UICACHE_ACTIVE ~= nil
		or _G.LUABOOST_DLL_VERSION ~= nil then
		return true
	end
	-- LuaBoost installs Lua fallbacks with the same names.  A native closure is
	-- accepted as a marker, while a plain Lua function is deliberately ignored.
	return IsNativeFunction(_G.LuaBoostC_IsLoaded)
		or IsNativeFunction(_G.LuaBoostC_GetStats)
		or IsNativeFunction(_G.LuaBoostC_GetUIStats)
		or IsNativeFunction(_G.LuaBoostC_GetFastPathStats)
		or IsNativeFunction(_G.LuaBoostC_GetApiStats)
end

local function ProbeWowOptimize()
	local info = {
		state = Runtime.WOW_OPTIMIZE_NOT_FOUND,
		detected = false,
		version = _G.LUABOOST_DLL_VERSION and tostring(_G.LUABOOST_DLL_VERSION) or nil,
		latestVersion = _G.LUABOOST_DLL_LATEST_VERSION and tostring(_G.LUABOOST_DLL_LATEST_VERSION) or nil,
		reason = "not_found",
		gcActive = false,
		allocator = "WoW default",
		missing = {},
		capabilities = {
			gc = false,
			gcStats = false,
			gcStep = false,
			gcCollect = false,
			combatSignal = false,
			allocator = false,
			fastPath = false,
			uiCache = false,
		},
	}
	if not HasWowOptimizeMarker() then return info end

	info.detected = true
	info.state = Runtime.WOW_OPTIMIZE_INCOMPATIBLE
	info.reason = "not_loaded"
	if type(_G.LUABOOST_DLL_LUA_ALLOC) == "string" and _G.LUABOOST_DLL_LUA_ALLOC ~= "" then
		info.allocator = _G.LUABOOST_DLL_LUA_ALLOC
		info.capabilities.allocator = true
	elseif IsDLLTrue(_G.LUABOOST_DLL_LUA_ALLOC) then
		info.allocator = "mimalloc"
		info.capabilities.allocator = true
	end

	if _G.LUABOOST_DLL_LOADED ~= nil and not IsDLLTrue(_G.LUABOOST_DLL_LOADED) then
		return info
	end

	for i = 1, #DLL_GC_API do
		local apiName = DLL_GC_API[i]
		if type(_G[apiName]) ~= "function" then
			info.missing[#info.missing + 1] = apiName
		end
	end

	local loaded = IsDLLTrue(_G.LUABOOST_DLL_LOADED)
	if type(_G.LuaBoostC_IsLoaded) == "function" then
		local loadedOK, loadedResult = pcall(_G.LuaBoostC_IsLoaded)
		if loadedOK and IsDLLTrue(loadedResult) then loaded = true end
	end
	if not loaded
		and not info.capabilities.allocator
		and not IsDLLTrue(_G.LUABOOST_DLL_GC_ACTIVE)
		and not IsDLLTrue(_G.LUABOOST_DLL_FASTPATH_ACTIVE)
		and not IsDLLTrue(_G.LUABOOST_DLL_UICACHE_ACTIVE)
		and not IsNativeFunction(_G.LuaBoostC_GetUIStats)
		and not IsNativeFunction(_G.LuaBoostC_GetFastPathStats)
		and not IsNativeFunction(_G.LuaBoostC_GetApiStats) then
		return info
	end

	info.capabilities.gc = IsDLLTrue(_G.LUABOOST_DLL_GC_ACTIVE)
	info.capabilities.gcStep = type(_G.LuaBoostC_GCStep) == "function"
	info.capabilities.gcCollect = type(_G.LuaBoostC_GCCollect) == "function"
	info.capabilities.combatSignal = type(_G.LuaBoostC_SetCombat) == "function"
	info.capabilities.fastPath = IsDLLTrue(_G.LUABOOST_DLL_FASTPATH_ACTIVE)
	info.capabilities.uiCache = IsDLLTrue(_G.LUABOOST_DLL_UICACHE_ACTIVE)

	if type(_G.LuaBoostC_GetStats) == "function" then
		local statsOK, memoryKB, steps, fullCollects, pause, stepMul, combat, mode, idle, loading = pcall(_G.LuaBoostC_GetStats)
		if statsOK and type(memoryKB) == "number" then
			info.capabilities.gcStats = true
			info.stats = {
				memoryKB = memoryKB,
				steps = tonumber(steps) or 0,
				fullCollects = tonumber(fullCollects) or 0,
				pause = tonumber(pause) or 0,
				stepMul = tonumber(stepMul) or 0,
				combat = combat and true or false,
				mode = mode and tostring(mode) or "unknown",
				idle = idle and true or false,
				loading = loading and true or false,
			}
		end
	end

	info.state = Runtime.WOW_OPTIMIZE_SUPPORTED
	info.reason = #info.missing > 0 and "supported_partial" or "supported"
	info.gcActive = info.capabilities.gc
	return info
end

local StandaloneBackend = { id = "standalone", label = "SarychUI Standalone" }
local WowOptimizeBackend = { id = "wow_optimize", label = "wow_optimize.dll" }

function StandaloneBackend:ApplySettings()
	return true
end

function StandaloneBackend:SyncState()
	return true
end

function StandaloneBackend:StepGC(runtime, amountKB)
	collectgarbage("step", amountKB)
	runtime._gcStats.steps = runtime._gcStats.steps + 1
	return true
end

function StandaloneBackend:ForceGC(runtime, reason, emergency)
	local before = collectgarbage("count")
	if debugprofilestart then debugprofilestart() end
	collectgarbage("collect")
	collectgarbage("collect")
	local elapsedMs = debugprofilestop and debugprofilestop() or 0
	local after = collectgarbage("count")
	local freed = max(0, (before - after) / 1024)
	runtime._gcStats.fullCollects = runtime._gcStats.fullCollects + 1
	runtime._gcStats.freedMB = runtime._gcStats.freedMB + freed
	runtime._gcStats.lastFullMs = elapsedMs
	if emergency then runtime._gcStats.emergencyGC = runtime._gcStats.emergencyGC + 1 end
	if runtime:IsStandaloneGcEnabled() then collectgarbage("stop") end
	DebugPrint(format("full GC (%s): freed %.1f MB in %.1f ms", tostring(reason or "manual"), freed, elapsedMs))
	return true, freed, elapsedMs
end

function StandaloneBackend:GetGCState(runtime)
	return {
		owner = runtime:IsStandaloneGcEnabled() and "SarychUI" or "Blizzard",
		mode = runtime:GetGcMode(),
		stepKB = runtime:GetCurrentStepKB(),
		localStepping = runtime:IsStandaloneGcEnabled(),
		observer = false,
		steps = runtime._gcStats.steps,
		fullCollects = runtime._gcStats.fullCollects,
		emergencyGC = runtime._gcStats.emergencyGC,
	}
end

function WowOptimizeBackend:ApplySettings(runtime, cfg)
	if not cfg then return false end
	_G.LUABOOST_ADDON_STEP_NORMAL = tonumber(cfg.frameStepKB) or 0
	_G.LUABOOST_ADDON_STEP_COMBAT = tonumber(cfg.combatStepKB) or 0
	_G.LUABOOST_ADDON_STEP_IDLE = tonumber(cfg.idleStepKB) or 0
	_G.LUABOOST_ADDON_STEP_LOADING = tonumber(cfg.loadingStepKB) or 0
	return self:SyncState(runtime)
end

function WowOptimizeBackend:SyncState(runtime)
	_G.LUABOOST_ADDON_COMBAT = runtime._inCombat and true or false
	_G.LUABOOST_ADDON_IDLE = runtime._isIdle and true or false
	_G.LUABOOST_ADDON_LOADING = runtime._isLoading and true or false
	if type(_G.LuaBoostC_SetCombat) == "function" then
		pcall(_G.LuaBoostC_SetCombat, runtime._inCombat and true or false)
	end
	return true
end

function WowOptimizeBackend:StepGC(runtime, amountKB)
	if type(_G.LuaBoostC_GCStep) ~= "function" then return false end
	local ok = pcall(_G.LuaBoostC_GCStep, amountKB)
	if ok then runtime._gcStats.delegatedSteps = runtime._gcStats.delegatedSteps + 1 end
	return ok
end

function WowOptimizeBackend:ForceGC(runtime, reason, emergency)
	if type(_G.LuaBoostC_GCCollect) ~= "function" then return false, "api" end
	local before = collectgarbage("count")
	if debugprofilestart then debugprofilestart() end
	local ok = pcall(_G.LuaBoostC_GCCollect)
	local elapsedMs = debugprofilestop and debugprofilestop() or 0
	if not ok then return false, "dll_error" end
	local after = collectgarbage("count")
	local freed = max(0, (before - after) / 1024)
	runtime._gcStats.delegatedFullCollects = runtime._gcStats.delegatedFullCollects + 1
	runtime._gcStats.freedMB = runtime._gcStats.freedMB + freed
	runtime._gcStats.lastFullMs = elapsedMs
	if emergency then runtime._gcStats.emergencyGC = runtime._gcStats.emergencyGC + 1 end
	DebugPrint(format("DLL GC (%s): freed %.1f MB in %.1f ms", tostring(reason or "manual"), freed, elapsedMs))
	return true, freed, elapsedMs
end

function WowOptimizeBackend:GetGCState(runtime)
	local info = runtime._dll
	local stats = info and info.stats or {}
	if type(_G.LuaBoostC_GetStats) == "function" then
		local ok, memoryKB, steps, fullCollects, pause, stepMul, combat, mode, idle, loading = pcall(_G.LuaBoostC_GetStats)
		if ok and type(memoryKB) == "number" then
			stats = {
				memoryKB = memoryKB,
				steps = tonumber(steps) or 0,
				fullCollects = tonumber(fullCollects) or 0,
				pause = tonumber(pause) or 0,
				stepMul = tonumber(stepMul) or 0,
				combat = combat and true or false,
				mode = mode and tostring(mode) or runtime:GetGcMode(),
				idle = idle and true or false,
				loading = loading and true or false,
			}
			info.stats = stats
		end
	end
	return {
		owner = "wow_optimize.dll",
		mode = stats.mode or runtime:GetGcMode(),
		stepKB = runtime:GetCurrentStepKB(),
		localStepping = false,
		observer = true,
		steps = stats.steps or 0,
		fullCollects = stats.fullCollects or 0,
		emergencyGC = nil,
		memoryKB = stats.memoryKB,
		pause = stats.pause,
		stepMul = stats.stepMul,
	}
end

Runtime.backends.standalone = StandaloneBackend
Runtime.backends.wow_optimize = WowOptimizeBackend
Runtime._backendImpl = StandaloneBackend

function Runtime:GetBackend()
	return self.backend or "standalone"
end

function Runtime:GetBackendLabel()
	return (self._backendImpl and self._backendImpl.label) or StandaloneBackend.label
end

function Runtime:DoesDLLOwnGC()
	return self._dllGcOwner == true
end

function Runtime:GetGCBackend()
	return self:DoesDLLOwnGC() and WowOptimizeBackend or StandaloneBackend
end

function Runtime:GetDLLState()
	self:RefreshBackend(false)
	return self._dll and self._dll.state or self.WOW_OPTIMIZE_NOT_FOUND
end

function Runtime:GetDLLInfo()
	self:RefreshBackend(false)
	return self._dll
end

function Runtime:HasDLL()
	return self:GetDLLState() == self.WOW_OPTIMIZE_SUPPORTED
end

function Runtime:IsDLLDetected()
	return self:GetDLLState() ~= self.WOW_OPTIMIZE_NOT_FOUND
end

function Runtime:_NotifyBackendChanged()
	local compat = SarychUI and SarychUI.Compatibility
	if compat and compat.InvalidateDllStatusCache then compat:InvalidateDllStatusCache() end
	if compat and compat.NotifyDllStatusUi then compat:NotifyDllStatusUi() end
end

function Runtime:_ApplyBackendSettings()
	local cfg = RuntimeDB()
	if self._backendImpl and self._backendImpl.ApplySettings then
		return self._backendImpl:ApplySettings(self, cfg)
	end
	return false
end

function Runtime:SyncBackendState()
	if self._backendImpl and self._backendImpl.SyncState then
		return self._backendImpl:SyncState(self)
	end
	return false
end

function Runtime:RefreshBackend(force)
	local now = self._cachedTime > 0 and self._cachedTime or GetTime()
	if not force and self._backendLastProbe > 0 and (now - self._backendLastProbe) < 0.5 then
		return self.backend
	end
	self._backendLastProbe = now
	local previousState = self._dll and self._dll.state
	local previousBackend = self.backend
	local previousDllGC = self._dllGcOwner == true
	local previousCapabilities = self._dll and self._dll.capabilities or {}
	local info = ProbeWowOptimize()
	self._dll = info
	local target = info.state == self.WOW_OPTIMIZE_SUPPORTED and "wow_optimize" or "standalone"
	self.backend = target
	self._backendImpl = self.backends[target]

	local dllOwnsGC = target == "wow_optimize" and info.capabilities and info.capabilities.gc == true
	local capabilityChanged = previousCapabilities.gc ~= info.capabilities.gc
		or previousCapabilities.allocator ~= info.capabilities.allocator
		or previousCapabilities.fastPath ~= info.capabilities.fastPath
		or previousCapabilities.uiCache ~= info.capabilities.uiCache
	self._dllGcOwner = dllOwnsGC and true or false
	if previousBackend ~= target then
		self._backendSwitches = self._backendSwitches + 1
		DebugPrint("backend -> " .. target)
	end
	if dllOwnsGC then
		-- Ownership is handed over without restarting Lua GC: an active DLL GC
		-- already owns the stopped collector and its adaptive stepping.
		self._gcOwnsLua = false
	elseif previousDllGC then
		-- The DLL relinquished a collector that was already stopped.  Treat it
		-- as locally owned for one transition so disabled standalone GC can
		-- restart Blizzard GC, while enabled standalone GC keeps it stopped.
		self._gcOwnsLua = true
		self:ApplyGcOwnership()
	elseif previousBackend ~= target then
		self:ApplyGcOwnership()
	end
	if self.RefreshUICacheOwnership then self:RefreshUICacheOwnership() end

	if previousBackend ~= target or previousState ~= info.state or capabilityChanged then
		self:_ApplyBackendSettings()
		self:_NotifyBackendChanged()
	end
	return target
end

function Runtime:SetGCSettings(settings)
	local cfg = RuntimeDB()
	if not cfg or type(settings) ~= "table" then return false end
	local numeric = {
		frameStepKB = { 0, 500 }, combatStepKB = { 0, 200 },
		idleStepKB = { 0, 1000 }, loadingStepKB = { 0, 1500 },
		fullCollectThresholdMB = { 100, 1000 }, idleTimeout = { 5, 60 },
	}
	for key, limits in pairs(numeric) do
		if settings[key] ~= nil then
			cfg[key] = max(limits[1], min(limits[2], tonumber(settings[key]) or cfg[key] or limits[1]))
		end
	end
	if settings.gcEnabled ~= nil then cfg.gcEnabled = settings.gcEnabled and true or false end
	if settings.emergencyGCEnabled ~= nil then cfg.emergencyGCEnabled = settings.emergencyGCEnabled and true or false end
	if settings.preset ~= nil then cfg.preset = tostring(settings.preset) end
	self._adaptiveThresholdMB = nil
	self:NormalizeConfig()
	self:_ApplyBackendSettings()
	self:ApplyGcOwnership()
	return true
end

function Runtime:GetDb()
	return RuntimeDB()
end

function Runtime:NormalizeConfig()
	local cfg = RuntimeDB()
	if not cfg then return end

	local aliases = { weak = "light", mid = "standard", strong = "heavy" }
	if aliases[cfg.preset] then
		cfg.preset = aliases[cfg.preset]
	end
	if not PRESETS[cfg.preset] and cfg.preset ~= "custom" then
		cfg.preset = "standard"
	end

	if cfg.enabled == nil then cfg.enabled = true end
	if cfg.gcEnabled == nil then cfg.gcEnabled = true end
	if cfg.emergencyGCEnabled == nil then cfg.emergencyGCEnabled = true end
	if cfg.tablePoolEnabled == nil then cfg.tablePoolEnabled = true end
	if cfg.sharedThrottleEnabled == nil then cfg.sharedThrottleEnabled = true end
	if cfg.cachedTimeEnabled == nil then cfg.cachedTimeEnabled = true end
	if cfg.uiCacheEnabled == nil then cfg.uiCacheEnabled = true end
	if cfg.poolMax == nil then cfg.poolMax = 300 end
	cfg.poolMax = max(25, min(1000, floor(tonumber(cfg.poolMax) or 300)))

	local base = PRESETS[cfg.preset] or PRESETS.standard
	for key, value in pairs(base) do
		if cfg[key] == nil then cfg[key] = value end
	end
end

function Runtime:ApplyPreset(name)
	local cfg = RuntimeDB()
	local preset = PRESETS[name]
	if not cfg or not preset then return false end
	for key, value in pairs(preset) do
		cfg[key] = value
	end
	cfg.preset = name
	self._adaptiveThresholdMB = nil
	self:_ApplyBackendSettings()
	return true
end

function Runtime:MarkCustomPreset()
	local cfg = RuntimeDB()
	if cfg then
		cfg.preset = "custom"
		self._adaptiveThresholdMB = nil
		self:_ApplyBackendSettings()
	end
end

-- -------------------------------------------------------------------------
-- Cached time / frame number
-- -------------------------------------------------------------------------

function Runtime:GetTimeCached()
	local cfg = RuntimeDB()
	if cfg and cfg.cachedTimeEnabled == false then
		return GetTime()
	end
	if self._cachedTime > 0 then
		return self._cachedTime
	end
	return GetTime()
end

function Runtime:GetFrameNumber()
	return self._frameNumber
end

function SarychUI:GetTimeCached()
	return Runtime:GetTimeCached()
end

function SarychUI:GetFrameNumberCached()
	return Runtime:GetFrameNumber()
end

-- -------------------------------------------------------------------------
-- Shared throttle
-- -------------------------------------------------------------------------

function Runtime:Throttle(id, interval, now)
	if type(id) ~= "string" then return false end
	local cfg = RuntimeDB()
	if cfg and cfg.sharedThrottleEnabled == false then
		self._throttleStats.allowed = self._throttleStats.allowed + 1
		return true
	end
	now = now or self:GetTimeCached()
	interval = max(0, tonumber(interval) or 0)
	local last = self._throttles[id]
	if not last or (now - last) >= interval then
		self._throttles[id] = now
		self._throttleStats.allowed = self._throttleStats.allowed + 1
		return true
	end
	self._throttleStats.blocked = self._throttleStats.blocked + 1
	return false
end

function Runtime:ResetThrottle(id)
	if id then
		self._throttles[id] = nil
	else
		wipe(self._throttles)
	end
end

-- -------------------------------------------------------------------------
-- Named table pool
-- -------------------------------------------------------------------------

local function PoolBucket(tag)
	tag = tag or "shared"
	local bucket = Runtime._pools[tag]
	if not bucket then
		bucket = { tables = {}, count = 0, acquired = 0, released = 0, created = 0 }
		Runtime._pools[tag] = bucket
	end
	return bucket, tag
end

function Runtime:AcquireTable(tag)
	local stats = self._poolStats
	stats.acquired = stats.acquired + 1
	local cfg = RuntimeDB()
	if cfg and cfg.tablePoolEnabled == false then
		stats.created = stats.created + 1
		return {}
	end

	local bucket, normalizedTag = PoolBucket(tag)
	bucket.acquired = bucket.acquired + 1
	local value
	if bucket.count > 0 then
		value = bucket.tables[bucket.count]
		bucket.tables[bucket.count] = nil
		bucket.count = bucket.count - 1
		self._poolAvailable = self._poolAvailable - 1
	else
		value = {}
		bucket.created = bucket.created + 1
		stats.created = stats.created + 1
	end
	self._poolOwners[value] = normalizedTag
	return value
end

function Runtime:ReleaseTable(value, tag)
	if type(value) ~= "table" or getmetatable(value) then
		self._poolStats.rejected = self._poolStats.rejected + 1
		return false
	end
	local cfg = RuntimeDB()
	if cfg and cfg.tablePoolEnabled == false then
		return false
	end
	local limit = (cfg and cfg.poolMax) or 300
	if self._poolAvailable >= limit then
		self._poolOwners[value] = nil
		self._poolStats.rejected = self._poolStats.rejected + 1
		return false
	end

	local owner = self._poolOwners[value]
	local bucket, normalizedTag = PoolBucket(tag or owner)
	wipe(value)
	bucket.count = bucket.count + 1
	bucket.tables[bucket.count] = value
	bucket.released = bucket.released + 1
	self._poolOwners[value] = normalizedTag
	self._poolAvailable = self._poolAvailable + 1
	self._poolStats.released = self._poolStats.released + 1
	return true
end

function Runtime:GetPoolStats()
	local stats = self._poolStats
	return stats.acquired, stats.released, stats.created, self._poolAvailable, stats.rejected
end

function Runtime:GetPoolBreakdown()
	local rows = {}
	for tag, bucket in pairs(self._pools) do
		rows[#rows + 1] = {
			tag = tag,
			available = bucket.count,
			acquired = bucket.acquired,
			released = bucket.released,
			created = bucket.created,
		}
	end
	tsort(rows, function(a, b) return a.acquired > b.acquired end)
	return rows
end

-- -------------------------------------------------------------------------
-- Single OnUpdate dispatcher
-- -------------------------------------------------------------------------

function Runtime:GetUpdateCount()
	return self._updateCount
end

function Runtime:RegisterUpdate(id, interval, callback)
	if type(id) ~= "string" or type(callback) ~= "function" then
		return false
	end
	interval = max(0, tonumber(interval) or 0)
	local data = self._updateCallbacks[id]
	if data then
		data.interval = interval
		data.fn = callback
		data.enabled = true
		self._dispatchGeneration = self._dispatchGeneration + 1
		self._nextDispatchAt = 0
		return true
	end
	self._updateCallbacks[id] = {
		interval = interval,
		last = 0,
		fn = callback,
		enabled = true,
		calls = 0,
		errors = 0,
	}
	self._updateCount = self._updateCount + 1
	self._dispatchGeneration = self._dispatchGeneration + 1
	self._nextDispatchAt = 0
	self:EnsureCoreFrame()
	return true
end

function Runtime:UnregisterUpdate(id)
	if self._updateCallbacks[id] then
		self._updateCallbacks[id] = nil
		self._updateCount = max(0, self._updateCount - 1)
		self._dispatchGeneration = self._dispatchGeneration + 1
		self._nextDispatchAt = 0
		return true
	end
	return false
end

function Runtime:GetDispatcherRows()
	local rows = {}
	for id, data in pairs(self._updateCallbacks) do
		rows[#rows + 1] = {
			id = id,
			interval = data.interval,
			calls = data.calls or 0,
			errors = data.errors or 0,
		}
	end
	tsort(rows, function(a, b)
		if a.interval == b.interval then return a.id < b.id end
		return a.interval < b.interval
	end)
	return rows
end

local function DispatchUpdates(now, elapsed)
	if Runtime._updateCount <= 0 then return end
	local stats = Runtime._dispatchStats
	stats.frames = stats.frames + 1
	if Runtime._nextDispatchAt > 0 and now < Runtime._nextDispatchAt then
		stats.skippedFrames = stats.skippedFrames + 1
		return
	end
	stats.wakeups = stats.wakeups + 1
	local generation = Runtime._dispatchGeneration
	local ids = Runtime:AcquireTable("dispatcher")
	local count = 0
	for id in pairs(Runtime._updateCallbacks) do
		count = count + 1
		ids[count] = id
	end
	local nextDue
	for i = 1, count do
		local data = Runtime._updateCallbacks[ids[i]]
		if data and data.enabled then
			if data.interval <= 0 or (now - data.last) >= data.interval then
				data.last = now
				data.calls = (data.calls or 0) + 1
				stats.calls = stats.calls + 1
				local ok, err = pcall(data.fn, now, elapsed)
				if not ok then
					data.errors = (data.errors or 0) + 1
					ReportError(err)
				end
			end
			if Runtime._updateCallbacks[ids[i]] == data and data.enabled then
				local dueAt = data.interval <= 0 and now or (data.last + data.interval)
				if not nextDue or dueAt < nextDue then nextDue = dueAt end
			end
		end
	end
	Runtime:ReleaseTable(ids, "dispatcher")
	if generation == Runtime._dispatchGeneration then
		Runtime._nextDispatchAt = nextDue or 0
	end
end

-- -------------------------------------------------------------------------
-- StatusBar redundant-update guard
-- -------------------------------------------------------------------------

local statusCache = setmetatable({}, { __mode = "k" })
local statusOriginals, statusWrappers = {}, {}
local statusMeta
local statusReady = false
local statusStats = {
	skipped = 0, passed = 0, hooked = 0, active = false,
	valueSkipped = 0, valuePassed = 0,
	rangeSkipped = 0, rangePassed = 0,
	colorSkipped = 0, colorPassed = 0,
}
local K_VALUE, K_MIN, K_MAX = 1, 2, 3
local K_R, K_G, K_B, K_A = 4, 5, 6, 7
local K_VALUE_SET, K_RANGE_SET, K_COLOR_SET = 8, 9, 10

local function StatusEntry(widget)
	local cached = statusCache[widget]
	if not cached then
		cached = Runtime:AcquireTable("statusbar")
		statusCache[widget] = cached
	end
	return cached
end

function Runtime:GetThrashGuardStats()
	local widgets = 0
	for _ in pairs(statusCache) do widgets = widgets + 1 end
	return statusStats.skipped, statusStats.passed, statusStats.hooked, statusStats.active, widgets, statusStats
end

function Runtime:InvalidateWidget(widget)
	local cached = widget and statusCache[widget]
	if cached then
		statusCache[widget] = nil
		self:ReleaseTable(cached, "statusbar")
	end
end

function Runtime:InstallThrashGuard()
	if statusStats.active then return true end
	local cfg = RuntimeDB()
	if not cfg or cfg.enabled == false or cfg.uiCacheEnabled == false then return false end

	local probe = CreateFrame("StatusBar")
	local meta = getmetatable(probe)
	probe:Hide()
	if not meta or not meta.__index then return false end
	statusMeta = meta.__index
	local hooked = 0

	if type(statusMeta.SetValue) == "function" then
		local original = statusMeta.SetValue
		statusOriginals.SetValue = original
		local wrapper = function(widget, value)
			if not statusReady or type(value) ~= "number" then return original(widget, value) end
			local cached = statusCache[widget]
			if cached and cached[K_VALUE_SET] and cached[K_VALUE] == value then
				statusStats.skipped = statusStats.skipped + 1
				statusStats.valueSkipped = statusStats.valueSkipped + 1
				return
			end
			cached = cached or StatusEntry(widget)
			cached[K_VALUE], cached[K_VALUE_SET] = value, true
			statusStats.passed = statusStats.passed + 1
			statusStats.valuePassed = statusStats.valuePassed + 1
			return original(widget, value)
		end
		if pcall(function() statusMeta.SetValue = wrapper end) then
			statusWrappers.SetValue = wrapper
			hooked = hooked + 1
		end
	end

	if type(statusMeta.SetMinMaxValues) == "function" then
		local original = statusMeta.SetMinMaxValues
		statusOriginals.SetMinMaxValues = original
		local wrapper = function(widget, lowValue, highValue)
			if not statusReady then return original(widget, lowValue, highValue) end
			local cached = statusCache[widget]
			if cached and cached[K_RANGE_SET] and cached[K_MIN] == lowValue and cached[K_MAX] == highValue then
				statusStats.skipped = statusStats.skipped + 1
				statusStats.rangeSkipped = statusStats.rangeSkipped + 1
				return
			end
			cached = cached or StatusEntry(widget)
			cached[K_MIN], cached[K_MAX], cached[K_RANGE_SET] = lowValue, highValue, true
			cached[K_VALUE_SET] = nil
			statusStats.passed = statusStats.passed + 1
			statusStats.rangePassed = statusStats.rangePassed + 1
			return original(widget, lowValue, highValue)
		end
		if pcall(function() statusMeta.SetMinMaxValues = wrapper end) then
			statusWrappers.SetMinMaxValues = wrapper
			hooked = hooked + 1
		end
	end

	if type(statusMeta.SetStatusBarColor) == "function" then
		local original = statusMeta.SetStatusBarColor
		statusOriginals.SetStatusBarColor = original
		local wrapper = function(widget, r, g, b, a)
			if not statusReady then return original(widget, r, g, b, a) end
			local cached = statusCache[widget]
			if cached and cached[K_COLOR_SET] and cached[K_R] == r and cached[K_G] == g
				and cached[K_B] == b and cached[K_A] == a then
				statusStats.skipped = statusStats.skipped + 1
				statusStats.colorSkipped = statusStats.colorSkipped + 1
				return
			end
			cached = cached or StatusEntry(widget)
			cached[K_R], cached[K_G], cached[K_B], cached[K_A] = r, g, b, a
			cached[K_COLOR_SET] = true
			statusStats.passed = statusStats.passed + 1
			statusStats.colorPassed = statusStats.colorPassed + 1
			return original(widget, r, g, b, a)
		end
		if pcall(function() statusMeta.SetStatusBarColor = wrapper end) then
			statusWrappers.SetStatusBarColor = wrapper
			hooked = hooked + 1
		end
	end

	statusStats.hooked = hooked
	statusStats.active = hooked > 0
	statusReady = statusStats.active
	return statusStats.active
end

function Runtime:UninstallThrashGuard()
	statusReady = false
	if statusMeta then
		for method, wrapper in pairs(statusWrappers) do
			if statusMeta[method] == wrapper then
				statusMeta[method] = statusOriginals[method]
			end
		end
	end
	for widget, cached in pairs(statusCache) do
		statusCache[widget] = nil
		self:ReleaseTable(cached, "statusbar")
	end
	wipe(statusOriginals)
	wipe(statusWrappers)
	statusMeta = nil
	statusStats.hooked = 0
	statusStats.active = false
end

function Runtime:IsDLLUICacheActive()
	if self:GetBackend() ~= "wow_optimize" then return false end
	if IsDLLTrue(_G.LUABOOST_DLL_UICACHE_ACTIVE) then return true end
	if type(_G.LuaBoostC_GetUIStats) == "function" then
		local ok, _, _, active = pcall(_G.LuaBoostC_GetUIStats)
		if ok and active then return true end
	end
	return false
end

function Runtime:RefreshUICacheOwnership()
	local cfg = RuntimeDB()
	if not self._enabled or not cfg or cfg.enabled == false or cfg.uiCacheEnabled == false then
		self:UninstallThrashGuard()
		return "disabled"
	end
	if self:IsDLLUICacheActive() then
		self:UninstallThrashGuard()
		return "wow_optimize"
	end
	self:InstallThrashGuard()
	return self:GetBackend() == "wow_optimize" and "sarychui_fallback" or "sarychui"
end

-- -------------------------------------------------------------------------
-- Smart GC manager
-- -------------------------------------------------------------------------

function Runtime:IsStandaloneGcEnabled()
	local cfg = RuntimeDB()
	return not self:DoesDLLOwnGC()
		and self._enabled and cfg and cfg.enabled ~= false and cfg.gcEnabled ~= false
end

function Runtime:IsGcEnabled()
	if self:DoesDLLOwnGC() then return true end
	return self:IsStandaloneGcEnabled()
end

function Runtime:GetGcController()
	if self:DoesDLLOwnGC() then return "wow_optimize.dll" end
	return self:IsStandaloneGcEnabled() and "SarychUI" or "Blizzard"
end

function Runtime:GetGcMode()
	if self._isLoading then return "loading" end
	if self._inCombat then return "combat" end
	if self._isIdle then return "idle" end
	return "normal"
end

function Runtime:GetCurrentStepKB()
	local cfg = RuntimeDB()
	if not cfg then return 0 end
	if self._isLoading then return tonumber(cfg.loadingStepKB) or 0 end
	if self._inCombat then return tonumber(cfg.combatStepKB) or 0 end
	if self._isIdle then return tonumber(cfg.idleStepKB) or 0 end
	return tonumber(cfg.frameStepKB) or 0
end

function Runtime:GetMemoryMB()
	return collectgarbage("count") / 1024
end

function Runtime:MarkActivity()
	self._lastActivity = self:GetTimeCached()
	if self._isIdle then
		self._isIdle = false
		DebugPrint("idle -> normal")
		self:SyncBackendState()
	end
end

function Runtime:ApplyGcOwnership()
	if self:DoesDLLOwnGC() then
		-- The DLL controls the collector.  Do not restart or stop it here.
		self._gcOwnsLua = false
		return
	end
	if self:IsStandaloneGcEnabled() then
		if not self._gcOwnsLua then collectgarbage("stop") end
		self._gcOwnsLua = true
	elseif self._gcOwnsLua then
		collectgarbage("restart")
		self._gcOwnsLua = false
	end
end

function Runtime:StepGC(amountKB, burst)
	if not self._enabled then return false end
	local amount = floor(tonumber(amountKB) or 0)
	if amount <= 0 then return false end
	if not self:DoesDLLOwnGC() and not self:IsStandaloneGcEnabled() then return false end
	local backend = self:GetGCBackend()
	local ok = backend and backend:StepGC(self, amount) or false
	if not ok then return false end
	if burst then self._gcStats.burstSteps = self._gcStats.burstSteps + 1 end
	return true
end

function Runtime:ForceGC(reason, emergency)
	if self._inCombat or (UnitAffectingCombat and UnitAffectingCombat("player")) then
		return false, "combat"
	end
	local backend = self:GetGCBackend()
	if not backend or not backend.ForceGC then return false, "backend" end
	return backend:ForceGC(self, reason, emergency)
end

function Runtime:ForceFullCollect(reason, emergency)
	return self:ForceGC(reason, emergency)
end

local function UpdateSmartGC(now, elapsed)
	local cfg = RuntimeDB()
	if not cfg then return end

	if not Runtime._isIdle and not Runtime._inCombat and not Runtime._isLoading then
		local timeout = tonumber(cfg.idleTimeout) or 15
		if (now - Runtime._lastActivity) >= timeout then
			Runtime._isIdle = true
			Runtime:SyncBackendState()
			DebugPrint("idle mode")
		end
	end

	-- A compatible DLL owns adaptive stepping and emergency collection.  The
	-- Lua manager remains an observer and only publishes runtime state.
	if Runtime:DoesDLLOwnGC() then return end
	if not Runtime:IsStandaloneGcEnabled() then return end

	if (now - Runtime._gcLastRestop) >= 5 then
		Runtime._gcLastRestop = now
		collectgarbage("stop")
	end

	if cfg.emergencyGCEnabled ~= false and (now - Runtime._gcLastMemoryCheck) >= 1 then
		Runtime._gcLastMemoryCheck = now
		local memoryKB = collectgarbage("count")
		local thresholdMB = Runtime._adaptiveThresholdMB or tonumber(cfg.fullCollectThresholdMB) or 300
		if memoryKB > thresholdMB * 1024 and not Runtime._inCombat and not Runtime._isLoading and elapsed < 0.033 then
			local ok, _, elapsedMs = Runtime:ForceGC("emergency", true)
			if ok and elapsedMs and elapsedMs > 50 and thresholdMB < 1000 then
				Runtime._adaptiveThresholdMB = min(1000, thresholdMB + 20)
			end
			return
		end
	end

	Runtime:StepGC(Runtime:GetCurrentStepKB(), false)
end

-- -------------------------------------------------------------------------
-- SpeedyLoad
-- -------------------------------------------------------------------------

function Runtime:IsSpeedyLoadEnabled()
	local system = SystemDB()
	return system and (system.enableSpeedyLoad == true or system.enableSpeedyLoad == 1) or false
end

function Runtime:GetSpeedyLoadMode()
	local system = SystemDB()
	return system and system.speedyLoadMode == "aggressive" and "aggressive" or "safe"
end

function Runtime:GetSpeedyEventList()
	local list = self:AcquireTable("speedy-list")
	for i = 1, #SPEEDY_SAFE_EVENTS do list[#list + 1] = SPEEDY_SAFE_EVENTS[i] end
	if self:GetSpeedyLoadMode() == "aggressive" then
		for i = 1, #SPEEDY_AGGRESSIVE_EXTRA do list[#list + 1] = SPEEDY_AGGRESSIVE_EXTRA[i] end
	end
	return list
end

function Runtime:EnsureSpeedyFrame()
	local speedy = self._speedy
	if not speedy.available or speedy.frame then return speedy.frame end
	local frame = CreateFrame("Frame")
	speedy.frame = frame
	frame:SetScript("OnEvent", function(_, event)
		if speedy.tracked[event] then
			if not speedy.occurred[event] then
				speedy.occurred[event] = true
				speedy.stats.occurred = speedy.stats.occurred + 1
			end
			frame:UnregisterEvent(event)
		end
	end)
	return frame
end

function Runtime:InstallSpeedyUnregisterHook()
	local speedy = self._speedy
	if speedy.hooked or not speedy.available then return end
	local frame = self:EnsureSpeedyFrame()
	local meta = frame and getmetatable(frame)
	if not meta or not meta.__index or not hooksecurefunc then return end
	local ok = pcall(hooksecurefunc, meta.__index, "UnregisterEvent", function(target, event)
		if speedy.listenUnregister then
			local frames = speedy.tracked[event]
			if frames then frames[target] = nil end
		end
	end)
	if ok then speedy.hooked = true end
end

function Runtime:EnsureSpeedyPriority()
	local speedy = self._speedy
	if speedy.priorityReady or not speedy.available or not self:IsSpeedyLoadEnabled() then return end
	local eventFrame = self._eventFrame
	if not eventFrame then return end
	local frames = { GetFramesRegisteredForEvent("PLAYER_ENTERING_WORLD") }
	for i = 1, #frames do
		local frame = frames[i]
		if frame and frame ~= eventFrame and frame.UnregisterEvent then
			pcall(frame.UnregisterEvent, frame, "PLAYER_ENTERING_WORLD")
		end
	end
	pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_ENTERING_WORLD")
	for i = 1, #frames do
		local frame = frames[i]
		if frame and frame ~= eventFrame and frame.RegisterEvent then
			pcall(frame.RegisterEvent, frame, "PLAYER_ENTERING_WORLD")
		end
	end
	speedy.priorityReady = true
end

function Runtime:SuppressSpeedyLoad()
	local speedy = self._speedy
	if not speedy.available or not self:IsSpeedyLoadEnabled() or speedy.suppressed then return 0 end
	local speedyFrame = self:EnsureSpeedyFrame()
	if not speedyFrame then return 0 end

	wipe(speedy.tracked)
	wipe(speedy.occurred)
	local eventList = self:GetSpeedyEventList()
	local count = 0
	for i = 1, #eventList do
		local event = eventList[i]
		local trackedFrames = {}
		speedy.tracked[event] = trackedFrames
		local registered = { GetFramesRegisteredForEvent(event) }
		for j = 1, #registered do
			local frame = registered[j]
			if frame and frame ~= speedyFrame and frame.UnregisterEvent then
				local ok = pcall(frame.UnregisterEvent, frame, event)
				if ok then
					trackedFrames[frame] = true
					count = count + 1
				end
			end
		end
		pcall(speedyFrame.RegisterEvent, speedyFrame, event)
	end
	self:ReleaseTable(eventList, "speedy-list")
	speedy.suppressed = true
	speedy.listenUnregister = true
	speedy.stats.cycles = speedy.stats.cycles + 1
	speedy.stats.suppressed = speedy.stats.suppressed + count
	DebugPrint(format("SpeedyLoad suppressed %d registrations", count))
	return count
end

function Runtime:RestoreSpeedyLoad()
	local speedy = self._speedy
	if not speedy.suppressed then return 0 end
	speedy.listenUnregister = false
	speedy.suppressed = false
	local count = 0
	for event, frames in pairs(speedy.tracked) do
		if speedy.frame then pcall(speedy.frame.UnregisterEvent, speedy.frame, event) end
		for frame in pairs(frames) do
			if frame and frame.RegisterEvent then
				pcall(frame.RegisterEvent, frame, event)
				count = count + 1
			end
		end
		wipe(frames)
	end
	wipe(speedy.tracked)
	wipe(speedy.occurred)
	speedy.stats.restored = speedy.stats.restored + count
	DebugPrint(format("SpeedyLoad restored %d registrations", count))
	return count
end

function Runtime:SchedulePostLoadWork()
	local system = SystemDB()
	if not system then return end
	if system.speedyLoadPostGC ~= false and self:IsGcEnabled() then
		self:StepGC(max(tonumber(RuntimeDB().loadingStepKB) or 300, 300), true)
	end
	if system.speedyLoadRefreshUI == false then return end

	local pass = 0
	self:RegisterUpdate("runtime.speedy.postload", 0.25, function()
		pass = pass + 1
		if type(UnitFramePortrait_Update) == "function" then
			local frames = { PlayerFrame, PetFrame, TargetFrame, FocusFrame, TargetFrameToT, FocusFrameToT }
			for i = 1, #frames do
				if frames[i] then pcall(UnitFramePortrait_Update, frames[i]) end
			end
		end
		if pass >= 3 then Runtime:UnregisterUpdate("runtime.speedy.postload") end
	end)
end

function Runtime:RefreshSpeedyLoad()
	local speedy = self._speedy
	if not speedy.available then return false end
	if self:IsSpeedyLoadEnabled() then
		self:EnsureSpeedyFrame()
		self:InstallSpeedyUnregisterHook()
		self:EnsureSpeedyPriority()
	else
		self:RestoreSpeedyLoad()
	end
	return true
end

function Runtime:GetSpeedyDiagnostics()
	local speedy = self._speedy
	return {
		available = speedy.available,
		enabled = self:IsSpeedyLoadEnabled(),
		mode = self:GetSpeedyLoadMode(),
		eventCount = #SPEEDY_SAFE_EVENTS + (self:GetSpeedyLoadMode() == "aggressive" and #SPEEDY_AGGRESSIVE_EXTRA or 0),
		suppressedNow = speedy.suppressed,
		cycles = speedy.stats.cycles,
		suppressed = speedy.stats.suppressed,
		restored = speedy.stats.restored,
		occurred = speedy.stats.occurred,
	}
end

-- -------------------------------------------------------------------------
-- Diagnostics: FPS/frametime, events, addon memory, OnUpdate frames
-- -------------------------------------------------------------------------

local function UpdateFrameStats(elapsed)
	local seconds = max(0, elapsed or 0)
	local ms = seconds * 1000
	local stats = Runtime._frameStats
	stats.lastMs = ms
	stats.samples = stats.samples + 1
	if stats.samples == 1 then
		stats.averageMs, stats.minMs, stats.maxMs = ms, ms, ms
		stats.fps = ms > 0 and 1000 / ms or 0
	else
		if ms < stats.minMs then stats.minMs = ms end
		if ms > stats.maxMs then stats.maxMs = ms end
	end
	stats.windowElapsed = stats.windowElapsed + seconds
	stats.windowFrames = stats.windowFrames + 1
	if stats.windowElapsed >= 0.25 then
		local windowMs = stats.windowElapsed * 1000 / max(1, stats.windowFrames)
		stats.averageMs = stats.updates == 0 and windowMs or (stats.averageMs * 0.75 + windowMs * 0.25)
		stats.fps = stats.windowElapsed > 0 and stats.windowFrames / stats.windowElapsed or 0
		stats.windowElapsed = 0
		stats.windowFrames = 0
		stats.updates = stats.updates + 1
	end
end

function Runtime:StartFPSProfile(duration)
	local profile = self._fpsProfile
	wipe(profile.samples)
	profile.count = 0
	profile.duration = max(3, min(30, tonumber(duration) or 10))
	profile.startTime = self:GetTimeCached()
	profile.active = true
	profile.result = nil
	Chat(Prefix() .. " " .. LText("Runtime_Diag_FPSStarted", "FPS/frametime capture started for 10 seconds."))
	return true
end

function Runtime:StopFPSProfile(printResult)
	local profile = self._fpsProfile
	if not profile.active and not profile.count then return nil end
	profile.active = false
	local count = profile.count or #profile.samples
	if count <= 0 then return nil end
	tsort(profile.samples)
	local total = 0
	for i = 1, count do total = total + profile.samples[i] end
	local averageMs = total / count
	local slowCount = max(1, floor(count * 0.01 + 0.5))
	local slowTotal = 0
	for i = count - slowCount + 1, count do slowTotal = slowTotal + profile.samples[i] end
	local slowMs = slowTotal / slowCount
	profile.result = {
		duration = self:GetTimeCached() - (profile.startTime or self:GetTimeCached()),
		frames = count,
		averageMs = averageMs,
		averageFPS = averageMs > 0 and 1000 / averageMs or 0,
		onePercentLow = slowMs > 0 and 1000 / slowMs or 0,
		minMs = profile.samples[1] or 0,
		maxMs = profile.samples[count] or 0,
	}
	if printResult ~= false then self:PrintFPSProfile() end
	return profile.result
end

function Runtime:PrintFPSProfile()
	local result = self._fpsProfile.result
	if not result then
		Chat(Prefix() .. " " .. LText("Runtime_Diag_NoFPS", "No FPS capture result yet."))
		return
	end
	Chat(Prefix() .. " " .. LText("Runtime_Diag_FPSResult", "FPS / frametime result"))
	Chat(format("  avg %.1f FPS (%.2f ms) | 1%% low %.1f FPS | min/max %.2f/%.2f ms | %d frames",
		result.averageFPS, result.averageMs, result.onePercentLow, result.minMs, result.maxMs, result.frames))
end

function Runtime:StartEventProfile(duration)
	local profile = self._eventProfile
	if not profile.frame then
		profile.frame = CreateFrame("Frame")
		profile.frame:SetScript("OnEvent", function(_, event)
			if profile.active then profile.counts[event] = (profile.counts[event] or 0) + 1 end
		end)
	end
	wipe(profile.counts)
	profile.startTime = self:GetTimeCached()
	profile.duration = max(3, min(30, tonumber(duration) or 10))
	profile.active = true
	profile.result = nil
	profile.frame:RegisterAllEvents()
	self:RegisterUpdate("runtime.diag.events", 0.25, function(now)
		if not profile.active or (now - profile.startTime) >= profile.duration then
			Runtime:StopEventProfile(true)
		end
	end)
	Chat(Prefix() .. " " .. LText("Runtime_Diag_EventsStarted", "Event frequency capture started for 10 seconds."))
	return true
end

function Runtime:StopEventProfile(printResult)
	local profile = self._eventProfile
	if profile.frame then profile.frame:UnregisterAllEvents() end
	self:UnregisterUpdate("runtime.diag.events")
	local elapsed = max(0.1, self:GetTimeCached() - (profile.startTime or self:GetTimeCached()))
	profile.active = false
	local rows, total = {}, 0
	for event, count in pairs(profile.counts) do
		rows[#rows + 1] = { event = event, count = count, rate = count / elapsed }
		total = total + count
	end
	tsort(rows, function(a, b) return a.count > b.count end)
	profile.result = { elapsed = elapsed, total = total, rows = rows }
	if printResult ~= false then self:PrintEventProfile() end
	return profile.result
end

function Runtime:PrintEventProfile(limit)
	local result = self._eventProfile.result
	if not result then
		Chat(Prefix() .. " " .. LText("Runtime_Diag_NoEvents", "No event profile result yet."))
		return
	end
	limit = min(tonumber(limit) or 15, #result.rows)
	Chat(Prefix() .. " " .. format(LText("Runtime_Diag_EventsResult", "Event frequency (%.1f sec)"), result.elapsed))
	for i = 1, limit do
		local row = result.rows[i]
		Chat(format("  %2d. %-30s %6d  (%.1f/sec)", i, row.event, row.count, row.rate))
	end
	Chat(format("  total: %d events (%.0f/sec), %d types", result.total, result.total / result.elapsed, #result.rows))
end

local function SnapshotAddonMemory()
	local snapshot = {}
	if type(UpdateAddOnMemoryUsage) ~= "function" or type(GetAddOnMemoryUsage) ~= "function" then
		return snapshot
	end
	UpdateAddOnMemoryUsage()
	local addonCount = GetNumAddOns and GetNumAddOns() or 0
	for i = 1, addonCount do
		local name = GetAddOnInfo(i)
		if name and IsAddOnLoaded and IsAddOnLoaded(i) then
			snapshot[name] = GetAddOnMemoryUsage(i) or 0
		end
	end
	return snapshot
end

function Runtime:StartMemoryProfile(duration)
	if self._memoryProfile and self._memoryProfile.active then return false end
	local seconds = max(10, min(120, tonumber(duration) or 30))
	self._memoryProfile = {
		active = true,
		startTime = self:GetTimeCached(),
		duration = seconds,
		snapshot = SnapshotAddonMemory(),
	}
	self:RegisterUpdate("runtime.diag.memory", 1, function(now)
		local profile = Runtime._memoryProfile
		if profile and profile.active and (now - profile.startTime) >= profile.duration then
			Runtime:StopMemoryProfile(true)
		end
	end)
	Chat(Prefix() .. " " .. format(LText("Runtime_Diag_MemoryStarted", "Addon memory scan started for %d seconds."), seconds))
	return true
end

function Runtime:StopMemoryProfile(printResult)
	local profile = self._memoryProfile
	if not profile then return nil end
	self:UnregisterUpdate("runtime.diag.memory")
	profile.active = false
	local elapsed = max(0.1, self:GetTimeCached() - profile.startTime)
	local current = SnapshotAddonMemory()
	local rows = {}
	for name, value in pairs(current) do
		local delta = value - (profile.snapshot[name] or 0)
		if delta > 1 then
			rows[#rows + 1] = { name = name, delta = delta, rate = delta / elapsed, memory = value }
		end
	end
	tsort(rows, function(a, b) return a.delta > b.delta end)
	profile.result = { elapsed = elapsed, rows = rows }
	if printResult ~= false then self:PrintMemoryProfile() end
	return profile.result
end

function Runtime:PrintMemoryProfile(limit)
	local profile = self._memoryProfile
	local result = profile and profile.result
	if not result then
		Chat(Prefix() .. " " .. LText("Runtime_Diag_NoMemory", "No addon memory scan result yet."))
		return
	end
	limit = min(tonumber(limit) or 15, #result.rows)
	Chat(Prefix() .. " " .. format(LText("Runtime_Diag_MemoryResult", "Addon memory growth (%.0f sec)"), result.elapsed))
	for i = 1, limit do
		local row = result.rows[i]
		Chat(format("  %2d. %-25s +%.0f KB (%.1f KB/sec) | %.1f MB", i, row.name, row.delta, row.rate, row.memory / 1024))
	end
	if #result.rows == 0 then Chat("  " .. LText("Runtime_Diag_NoGrowth", "No measurable memory growth.")) end
end

function Runtime:ScanOnUpdateFrames()
	local rows = {}
	if type(EnumerateFrames) ~= "function" then return rows, "unavailable" end
	local frame, scanned = nil, 0
	repeat
		frame = EnumerateFrames(frame)
		if frame then
			scanned = scanned + 1
			local script = frame.GetScript and frame:GetScript("OnUpdate")
			if script then
				local name = frame.GetName and frame:GetName()
				rows[#rows + 1] = {
					name = name or tostring(frame),
					shown = frame.IsShown and frame:IsShown() or false,
				}
			end
		end
	until not frame or scanned >= 20000
	tsort(rows, function(a, b)
		if a.shown ~= b.shown then return a.shown end
		return lower(a.name or "") < lower(b.name or "")
	end)
	self._lastOnUpdateScan = { at = self:GetTimeCached(), rows = rows, scanned = scanned }
	return rows
end

function Runtime:PrintOnUpdateList(limit)
	local rows, err = self:ScanOnUpdateFrames()
	if err then
		Chat(Prefix() .. " " .. LText("Runtime_Diag_OnUpdateUnavailable", "EnumerateFrames is unavailable on this client."))
		return
	end
	limit = min(tonumber(limit) or 30, #rows)
	Chat(Prefix() .. " " .. format(LText("Runtime_Diag_OnUpdateResult", "Active OnUpdate frames: %d"), #rows))
	for i = 1, limit do
		local row = rows[i]
		Chat(format("  %2d. %s %s", i, row.shown and "|cff00ff00shown|r" or "|cff888888hidden|r", row.name))
	end
	local dispatcherRows = self:GetDispatcherRows()
	Chat(format("  SarychUI dispatcher: %d callbacks", #dispatcherRows))
	for i = 1, min(15, #dispatcherRows) do
		local row = dispatcherRows[i]
		Chat(format("    %-32s every %.2fs (%d calls)", row.id, row.interval, row.calls))
	end
end

-- -------------------------------------------------------------------------
-- Event routing and lifecycle
-- -------------------------------------------------------------------------

local function RegisterHandler(event, handler)
	local list = Runtime._handlers[event]
	if not list then
		list = {}
		Runtime._handlers[event] = list
		if Runtime._eventFrame then
			local ok = pcall(Runtime._eventFrame.RegisterEvent, Runtime._eventFrame, event)
			if not ok then
				Runtime._handlers[event] = nil
				return false
			end
		end
	end
	list[#list + 1] = handler
	return true
end

function Runtime:EnsureEventFrame()
	if self._eventFrame then return end
	local frame = CreateFrame("Frame")
	self._eventFrame = frame
	frame:SetScript("OnEvent", function(_, event, ...)
		local handlers = Runtime._handlers[event]
		if not handlers then return end
		for i = 1, #handlers do
			local ok, err = pcall(handlers[i], event, ...)
			if not ok then ReportError(err) end
		end
	end)
end

function Runtime:EnsureCoreFrame()
	if self._coreFrame then return end
	local frame = CreateFrame("Frame")
	self._coreFrame = frame
	frame:SetScript("OnUpdate", function(_, elapsed)
		Runtime:OnUpdate(elapsed)
	end)
	if SarychUI and SarychUI.RegisterPerfOnUpdate then
		SarychUI:RegisterPerfOnUpdate("runtime.dispatcher", frame)
	end
end

function Runtime:OnUpdate(elapsed)
	self._frameNumber = self._frameNumber + 1
	self._cachedTime = GetTime()
	UpdateFrameStats(elapsed)

	local fps = self._fpsProfile
	if fps.active then
		fps.count = fps.count + 1
		fps.samples[fps.count] = max(0, (elapsed or 0) * 1000)
		if (self._cachedTime - fps.startTime) >= fps.duration or fps.count >= 4000 then
			self:StopFPSProfile(true)
		end
	end

	DispatchUpdates(self._cachedTime, elapsed or 0)
	if not self._dllGcOwner then
		UpdateSmartGC(self._cachedTime, elapsed or 0)
	elseif (self._cachedTime - self._dllObserverLast) >= 0.25 then
		self._dllObserverLast = self._cachedTime
		self._dllObserverPolls = self._dllObserverPolls + 1
		UpdateSmartGC(self._cachedTime, elapsed or 0)
	else
		self._dllObserverSkipped = self._dllObserverSkipped + 1
	end
end

function Runtime:OnCombatEvent(event)
	if event == "PLAYER_REGEN_DISABLED" then
		self:MarkActivity()
		self._inCombat = true
		self:SyncBackendState()
	elseif event == "PLAYER_REGEN_ENABLED" then
		self._inCombat = false
		self:MarkActivity()
		self:SyncBackendState()
		self:StepGC(128, true)
	end
end

function Runtime:OnBurstEvent()
	if not self._inCombat then self:StepGC(128, true) end
end

function Runtime:OnLoadingEvent(event)
	if event == "PLAYER_LEAVING_WORLD" or event == "LOADING_SCREEN_ENABLED" then
		if not self._isLoading then
			self._isLoading = true
			self._isIdle = false
			self:SyncBackendState()
			self:SuppressSpeedyLoad()
		end
	elseif event == "PLAYER_ENTERING_WORLD" or event == "LOADING_SCREEN_DISABLED" then
		local wasLoading = self._isLoading
		self:RestoreSpeedyLoad()
		self._isLoading = false
		self:MarkActivity()
		self:SyncBackendState()
		if wasLoading then self:SchedulePostLoadWork() end
	end
end

function Runtime:BindEvents()
	if self._eventsBound then return end
	self:EnsureEventFrame()
	RegisterHandler("PLAYER_REGEN_DISABLED", function(event) Runtime:OnCombatEvent(event) end)
	RegisterHandler("PLAYER_REGEN_ENABLED", function(event) Runtime:OnCombatEvent(event) end)
	RegisterHandler("PLAYER_LEAVING_WORLD", function(event) Runtime:OnLoadingEvent(event) end)
	RegisterHandler("PLAYER_ENTERING_WORLD", function(event) Runtime:OnLoadingEvent(event) end)
	RegisterHandler("LOADING_SCREEN_ENABLED", function(event) Runtime:OnLoadingEvent(event) end)
	RegisterHandler("LOADING_SCREEN_DISABLED", function(event) Runtime:OnLoadingEvent(event) end)
	for i = 1, #ACTIVITY_EVENTS do RegisterHandler(ACTIVITY_EVENTS[i], function() Runtime:MarkActivity() end) end
	for i = 1, #BURST_EVENTS do RegisterHandler(BURST_EVENTS[i], function() Runtime:OnBurstEvent() end) end
	self._eventsBound = true
end

function Runtime:Enable()
	self._enabled = true
	self:ApplyGcOwnership()
	self:RefreshUICacheOwnership()
end

function Runtime:Disable()
	self._enabled = false
	self:UninstallThrashGuard()
	self:ApplyGcOwnership()
	self._isIdle = false
end

function Runtime:Refresh()
	self:NormalizeConfig()
	self:RefreshBackend(true)
	self:_ApplyBackendSettings()
	local cfg = RuntimeDB()
	if cfg and cfg.enabled ~= false then self:Enable() else self:Disable() end
	self:RefreshSpeedyLoad()
end

function Runtime:Initialize()
	if self._initialized then return end
	self._initialized = true
	self:EnsureCoreFrame()
	self:EnsureEventFrame()
	self:BindEvents()
	self._cachedTime = GetTime()
	self._lastActivity = self._cachedTime
	self._inCombat = UnitAffectingCombat and UnitAffectingCombat("player") and true or false
	self:RefreshBackend(true)
	self:Refresh()
	self._backendProbeDeadline = self._cachedTime + 8
	self:RegisterUpdate("runtime.backend.probe", 0.5, function(now)
		Runtime:RefreshBackend(true)
		if now >= Runtime._backendProbeDeadline then
			Runtime:UnregisterUpdate("runtime.backend.probe")
			-- A detected DLL may intentionally expose only some capabilities.
			-- That is a stable hybrid backend, not a failed GC probe.  Continue
			-- polling only while the DLL itself has not appeared yet.
			if Runtime:GetBackend() ~= "wow_optimize" then
				Runtime:RegisterUpdate("runtime.backend.monitor", 5, function()
					Runtime:RefreshBackend(true)
					if Runtime:GetBackend() == "wow_optimize" then
						Runtime:UnregisterUpdate("runtime.backend.monitor")
					end
				end)
			end
		end
	end)
end

function Runtime:Shutdown()
	self:RestoreSpeedyLoad()
	if self._eventProfile.active then self:StopEventProfile(false) end
	if self._memoryProfile and self._memoryProfile.active then self:StopMemoryProfile(false) end
	for id in pairs(self._updateCallbacks) do self._updateCallbacks[id] = nil end
	self._updateCount = 0
	self._nextDispatchAt = 0
	wipe(self._throttles)
	self:Disable()
	if self._coreFrame then
		self._coreFrame:SetScript("OnUpdate", nil)
		self._coreFrame = nil
	end
	if self._eventFrame then
		self._eventFrame:UnregisterAllEvents()
		self._eventFrame:SetScript("OnEvent", nil)
		self._eventFrame = nil
	end
end

function Runtime:GetGCState()
	self:RefreshBackend(false)
	local backend = self:GetGCBackend()
	if backend and backend.GetGCState then
		return backend:GetGCState(self)
	end
	return StandaloneBackend:GetGCState(self)
end

function Runtime:GetMemoryState()
	self:RefreshBackend(false)
	local state = {
		luaMB = collectgarbage("count") / 1024,
		allocator = "WoW default",
		workingSetMB = tonumber(_G.LUABOOST_DLL_MEM_WORKING_SET_MB),
		commitMB = tonumber(_G.LUABOOST_DLL_MEM_COMMIT_MB),
		largestFreeMB = tonumber(_G.LUABOOST_DLL_MEM_LARGEST_FREE_MB),
	}
	if self:GetBackend() == "wow_optimize" then
		state.allocator = (self._dll and self._dll.allocator) or "mimalloc"
		if type(_G.LuaBoostC_GCMemory) == "function" then
			local ok, memoryKB = pcall(_G.LuaBoostC_GCMemory)
			if ok and type(memoryKB) == "number" and memoryKB > 0 then
				state.dllLuaMB = memoryKB / 1024
			end
		end
		if not state.dllLuaMB and self._dll and self._dll.stats and self._dll.stats.memoryKB then
			state.dllLuaMB = self._dll.stats.memoryKB / 1024
		end
	end
	return state
end

function Runtime:GetDLLDiagnostics()
	local result = {
		uiCacheAvailable = _G.LUABOOST_DLL_UICACHE_ACTIVE ~= nil or type(_G.LuaBoostC_GetUIStats) == "function",
		uiCacheSkipped = tonumber(_G.LUABOOST_DLL_UICACHE_SKIPPED) or 0,
		uiCachePassed = tonumber(_G.LUABOOST_DLL_UICACHE_PASSED) or 0,
		uiCacheActive = IsDLLTrue(_G.LUABOOST_DLL_UICACHE_ACTIVE),
		fastPathAvailable = _G.LUABOOST_DLL_FASTPATH_ACTIVE ~= nil or type(_G.LuaBoostC_GetFastPathStats) == "function",
		fastPathHits = tonumber(_G.LUABOOST_DLL_FASTPATH_HITS) or 0,
		fastPathFallbacks = tonumber(_G.LUABOOST_DLL_FASTPATH_FALLBACKS) or 0,
		fastPathActive = IsDLLTrue(_G.LUABOOST_DLL_FASTPATH_ACTIVE),
		apiAvailable = type(_G.LuaBoostC_GetApiStats) == "function",
		apiHits = 0, apiMisses = 0, apiFast = 0, apiFallback = 0, apiActive = false,
		gcMs = tonumber(_G.LUABOOST_DLL_GC_MS),
	}
	if self:GetBackend() ~= "wow_optimize" then return result end
	if type(_G.LuaBoostC_GetUIStats) == "function" then
		local ok, skipped, passed, active = pcall(_G.LuaBoostC_GetUIStats)
		if ok then
			result.uiCacheSkipped = tonumber(skipped) or 0
			result.uiCachePassed = tonumber(passed) or 0
			result.uiCacheActive = result.uiCacheActive or (active and true or false)
		end
	end
	if type(_G.LuaBoostC_GetFastPathStats) == "function" then
		local ok, hits, fallbacks, active = pcall(_G.LuaBoostC_GetFastPathStats)
		if ok then
			result.fastPathHits = tonumber(hits) or 0
			result.fastPathFallbacks = tonumber(fallbacks) or 0
			result.fastPathActive = result.fastPathActive or (active and true or false)
		end
	end
	if type(_G.LuaBoostC_GetApiStats) == "function" then
		local ok, hits, misses, fast, fallback, active = pcall(_G.LuaBoostC_GetApiStats)
		if ok then
			result.apiHits = tonumber(hits) or 0
			result.apiMisses = tonumber(misses) or 0
			result.apiFast = tonumber(fast) or 0
			result.apiFallback = tonumber(fallback) or 0
			result.apiActive = active and true or false
		end
	end
	return result
end

function Runtime:GetDiagnostics()
	self:RefreshBackend(false)
	local cfg = RuntimeDB()
	local acquired, released, created, available, rejected = self:GetPoolStats()
	local skipped, passed, hooks, cacheActive, widgets, cacheStats = self:GetThrashGuardStats()
	local speedy = self:GetSpeedyDiagnostics()
	local gc = self:GetGCState()
	local memory = self:GetMemoryState()
	local dllDiag = self:GetDLLDiagnostics()
	local dllOwnsUICache = self:GetBackend() == "wow_optimize" and dllDiag.uiCacheActive
	local dllConnected = self:GetBackend() == "wow_optimize"
	if dllOwnsUICache then
		skipped, passed = dllDiag.uiCacheSkipped, dllDiag.uiCachePassed
		cacheActive, hooks, widgets = dllDiag.uiCacheActive, 0, 0
	end
	local uiCacheOwner = "SarychUI"
	if dllConnected then
		uiCacheOwner = dllDiag.uiCacheActive and "wow_optimize.dll" or "SarychUI fallback"
	end
	local allocatorOwner = dllConnected and self._dll and self._dll.capabilities
		and self._dll.capabilities.allocator and "wow_optimize.dll" or "WoW"
	local fastPathOwner = dllConnected and dllDiag.fastPathActive
		and "wow_optimize.dll" or "SarychUI Runtime"
	local cacheTotal = skipped + passed
	return {
		version = self.VERSION,
		backend = self:GetBackend(),
		backendLabel = self:GetBackendLabel(),
		backendSwitches = self._backendSwitches,
		dllDetected = self._dll and self._dll.detected or false,
		dllState = self._dll and self._dll.state or self.WOW_OPTIMIZE_NOT_FOUND,
		dllVersion = self._dll and self._dll.version,
		dllLatestVersion = self._dll and self._dll.latestVersion,
		dllReason = self._dll and self._dll.reason,
		dllMissing = self._dll and self._dll.missing or {},
		dllCapabilities = self._dll and self._dll.capabilities or {},
		memoryMB = memory.luaMB,
		dllMemoryMB = memory.dllLuaMB,
		allocator = memory.allocator,
		allocatorOwner = allocatorOwner,
		fastPathOwner = fastPathOwner,
		workingSetMB = memory.workingSetMB,
		commitMB = memory.commitMB,
		largestFreeMB = memory.largestFreeMB,
		gcEnabled = self:IsGcEnabled(),
		gcController = gc.owner,
		gcOwner = gc.owner,
		gcObserver = gc.observer,
		sarychGcStepping = gc.localStepping,
		gcMode = gc.mode,
		frameStepKB = gc.stepKB,
		emergencyThresholdMB = self._adaptiveThresholdMB or (cfg and cfg.fullCollectThresholdMB) or 300,
		steps = gc.steps or 0,
		sarychSteps = self._gcStats.steps,
		delegatedSteps = self._gcStats.delegatedSteps,
		burstSteps = self._gcStats.burstSteps,
		emergencyGC = gc.emergencyGC or self._gcStats.emergencyGC,
		fullCollects = gc.fullCollects or 0,
		sarychFullCollects = self._gcStats.fullCollects,
		delegatedFullCollects = self._gcStats.delegatedFullCollects,
		freedMB = self._gcStats.freedMB,
		lastFullMs = self._gcStats.lastFullMs,
		dllPause = gc.pause,
		dllStepMul = gc.stepMul,
		dllGcMs = dllDiag.gcMs,
		dllFastPathAvailable = dllDiag.fastPathAvailable,
		dllFastPathActive = dllDiag.fastPathActive,
		dllFastPathHits = dllDiag.fastPathHits,
		dllFastPathFallbacks = dllDiag.fastPathFallbacks,
		dllApiActive = dllDiag.apiActive,
		dllUICacheAvailable = dllDiag.uiCacheAvailable,
		dllUICacheActive = dllDiag.uiCacheActive,
		updateCount = self._updateCount,
		dispatchCalls = self._dispatchStats.calls,
		dispatchErrors = self._dispatchStats.errors,
		dispatchFrames = self._dispatchStats.frames,
		dispatchWakeups = self._dispatchStats.wakeups,
		dispatchSkippedFrames = self._dispatchStats.skippedFrames,
		dispatchSkipRate = self._dispatchStats.frames > 0 and (self._dispatchStats.skippedFrames / self._dispatchStats.frames * 100) or 0,
		dllObserverPolls = self._dllObserverPolls,
		dllObserverSkipped = self._dllObserverSkipped,
		poolAcquired = acquired,
		poolReleased = released,
		poolCreated = created,
		poolAvailable = available,
		poolRejected = rejected,
		poolEnabled = not cfg or cfg.tablePoolEnabled ~= false,
		throttleAllowed = self._throttleStats.allowed,
		throttleBlocked = self._throttleStats.blocked,
		throttleEnabled = not cfg or cfg.sharedThrottleEnabled ~= false,
		cachedTimeEnabled = not cfg or cfg.cachedTimeEnabled ~= false,
		uiCacheActive = cacheActive,
		uiCacheEnabled = not cfg or cfg.uiCacheEnabled ~= false,
		uiCacheOwner = uiCacheOwner,
		uiCacheHooks = hooks,
		uiCacheWidgets = widgets,
		uiCacheSkipped = skipped,
		uiCachePassed = passed,
		uiCacheHitRate = cacheTotal > 0 and (skipped / cacheTotal * 100) or 0,
		uiCacheValueSkipped = not dllOwnsUICache and cacheStats and cacheStats.valueSkipped or 0,
		uiCacheRangeSkipped = not dllOwnsUICache and cacheStats and cacheStats.rangeSkipped or 0,
		uiCacheColorSkipped = not dllOwnsUICache and cacheStats and cacheStats.colorSkipped or 0,
		fps = self._frameStats.fps,
		frameMs = self._frameStats.averageMs,
		lastFrameMs = self._frameStats.lastMs,
		frameStatsUpdates = self._frameStats.updates,
		frameStatsReduced = max(0, self._frameStats.samples - self._frameStats.updates - 1),
		frameNumber = self._frameNumber,
		speedy = speedy,
	}
end

function Runtime:PrintDiagnostics()
	local d = self:GetDiagnostics()
	local yes, no = LText("Yes", "Yes"), LText("No", "No")
	local active, disabled = LText("Runtime_State_Active", "Active"), LText("Runtime_State_Disabled", "Disabled")
	local sarychFallback = LText("Runtime_State_SarychFallback", "handled by SarychUI")
	local uiCacheOwnerText = d.uiCacheOwner == "SarychUI fallback" and sarychFallback or d.uiCacheOwner
	local fastPathOwnerText = d.fastPathOwner == "SarychUI Runtime" and sarychFallback or d.fastPathOwner
	Chat(Prefix() .. " v" .. tostring(d.version))
	Chat(format("  %s: %s", LText("Runtime_Backend", "Backend"), tostring(d.backendLabel)))
	Chat(format("  %s: %s", LText("Runtime_DLLDetected", "DLL detected"), d.dllDetected and yes or no))
	Chat(format("  %s: %s", LText("Runtime_DLLVersion", "DLL version"), tostring(d.dllVersion or "—")))
	if d.dllState == self.WOW_OPTIMIZE_INCOMPATIBLE then
		local missing = d.dllMissing and #d.dllMissing > 0 and (" [" .. table.concat(d.dllMissing, ", ") .. "]") or ""
		Chat(format("  %s: %s%s", LText("Runtime_DLLStatus", "DLL status"), tostring(d.dllReason or "incompatible"), missing))
	end
	Chat(format("  %s: %s", LText("Runtime_GCOwner", "GC owner"), tostring(d.gcOwner)))
	Chat(format("  %s: %s", LText("Runtime_SarychGCStepping", "SarychUI GC stepping"), d.sarychGcStepping and active or disabled))
	Chat(format("  %s: %s", LText("Runtime_Allocator", "Allocator"), tostring(d.allocator or "WoW default")))
	Chat(format("  Lua: %.1f MB | GC: %s / %d KB | FPS: %.1f / %.2f ms", d.memoryMB, tostring(d.gcMode), d.frameStepKB, d.fps, d.frameMs))
	if d.gcOwner == "wow_optimize.dll" then
		Chat(format("  DLL GC: steps=%d full=%d delegated=%d | %.2f ms", d.steps, d.fullCollects, d.delegatedSteps, d.dllGcMs or 0))
	else
		Chat(format("  GC stats: steps=%d burst=%d emergency=%d full=%d freed=%.1f MB", d.steps, d.burstSteps, d.emergencyGC, d.fullCollects, d.freedMB))
	end
	if d.backend == "wow_optimize" then
		local fastPathState = d.dllFastPathActive and active or sarychFallback
		local dllCacheState = d.dllUICacheActive and active or sarychFallback
		Chat(format("  DLL fast paths: %s | hits=%d fallback=%d | DLL UI cache: %s",
			fastPathState, d.dllFastPathHits, d.dllFastPathFallbacks, dllCacheState))
		Chat(format("  %s: GC=%s | allocator=%s | fast paths=%s | UI cache=%s",
			LText("Runtime_CapabilityOwners", "Capability owners"), d.gcOwner,
			d.allocatorOwner, fastPathOwnerText, uiCacheOwnerText))
		if d.workingSetMB or d.commitMB then
			Chat(format("  DLL memory: working set=%.1f MB | commit=%.1f MB | largest free=%.1f MB",
				d.workingSetMB or 0, d.commitMB or 0, d.largestFreeMB or 0))
		end
	end
	Chat(format("  Table Pool: %s | Dispatcher: %s (%d) | Throttle: %s | Cached Time: %s",
		d.poolEnabled and active or disabled, active, d.updateCount,
		d.throttleEnabled and active or disabled, d.cachedTimeEnabled and active or disabled))
	Chat(format("  Dispatcher scheduler: %.1f%% frame scans avoided (%d skipped / %d wakeups)",
		d.dispatchSkipRate, d.dispatchSkippedFrames, d.dispatchWakeups))
	if d.gcOwner == "wow_optimize.dll" then
		Chat(format("  DLL observer: %d polls / %d per-frame checks avoided", d.dllObserverPolls, d.dllObserverSkipped))
	end
	Chat(format("  Live FPS sampler: %d aggregates / %d per-frame divisions avoided", d.frameStatsUpdates, d.frameStatsReduced))
	Chat(format("  Diagnostics: %s | SpeedyLoad: %s / %s", active, d.speedy.enabled and active or disabled, d.speedy.mode))
	Chat(format("  StatusBar cache: %s / %s / %d skipped (%.1f%% hit rate; value=%d range=%d color=%d)",
		uiCacheOwnerText, d.uiCacheActive and active or disabled, d.uiCacheSkipped, d.uiCacheHitRate,
		d.uiCacheValueSkipped, d.uiCacheRangeSkipped, d.uiCacheColorSkipped))
end

local function DLLValue(value)
	if value == nil then return "nil" end
	if type(value) == "string" then return '"' .. value .. '"' end
	return tostring(value)
end

local function DLLApiKind(name)
	local value = _G[name]
	if type(value) ~= "function" then return type(value) end
	if IsNativeFunction(value) then return "C" end
	return "Lua"
end

local function DLLPack(...)
	return { n = select("#", ...), ... }
end

local function DLLCallSummary(name)
	local fn = _G[name]
	if type(fn) ~= "function" then return "missing" end
	local result = DLLPack(pcall(fn))
	local ok = result[1]
	if not ok then return "ERROR: " .. tostring(result[2]) end
	local values = {}
	for i = 2, result.n do values[#values + 1] = DLLValue(result[i]) end
	if #values == 0 then values[1] = "<no values>" end
	return table.concat(values, ", ")
end

function Runtime:PrintDLLProbe()
	self:RefreshBackend(true)
	local info = self._dll or {}
	Chat(Prefix() .. " " .. LText("Runtime_DLLProbeHeader", "wow_optimize.dll raw probe"))
	Chat(format("  backend=%s | state=%s | reason=%s | version=%s",
		tostring(self:GetBackend()), tostring(info.state), tostring(info.reason), DLLValue(info.version)))
	Chat(format("  markers: LOADED=%s | GC_ACTIVE=%s | LUA_ALLOC=%s",
		DLLValue(_G.LUABOOST_DLL_LOADED), DLLValue(_G.LUABOOST_DLL_GC_ACTIVE), DLLValue(_G.LUABOOST_DLL_LUA_ALLOC)))
	Chat(format("  flags: FASTPATH=%s | UICACHE=%s | GC_MS=%s",
		DLLValue(_G.LUABOOST_DLL_FASTPATH_ACTIVE), DLLValue(_G.LUABOOST_DLL_UICACHE_ACTIVE), DLLValue(_G.LUABOOST_DLL_GC_MS)))

	local required = {}
	for i = 1, #DLL_GC_API do
		local name = DLL_GC_API[i]
		required[#required + 1] = name .. "=" .. DLLApiKind(name)
	end
	Chat("  GC API: " .. table.concat(required, " | "))
	Chat(format("  optional API: GetUIStats=%s | GetFastPathStats=%s | GetApiStats=%s",
		DLLApiKind("LuaBoostC_GetUIStats"), DLLApiKind("LuaBoostC_GetFastPathStats"), DLLApiKind("LuaBoostC_GetApiStats")))
	Chat("  GetStats -> " .. DLLCallSummary("LuaBoostC_GetStats"))
	Chat("  GCMemory -> " .. DLLCallSummary("LuaBoostC_GCMemory"))
	Chat("  GetUIStats -> " .. DLLCallSummary("LuaBoostC_GetUIStats"))
	Chat("  GetFastPathStats -> " .. DLLCallSummary("LuaBoostC_GetFastPathStats"))
	Chat("  GetApiStats -> " .. DLLCallSummary("LuaBoostC_GetApiStats"))
	Chat(format("  counters: FP_HITS=%s | FP_FALLBACKS=%s | UI_SKIPPED=%s | UI_PASSED=%s",
		DLLValue(_G.LUABOOST_DLL_FASTPATH_HITS), DLLValue(_G.LUABOOST_DLL_FASTPATH_FALLBACKS),
		DLLValue(_G.LUABOOST_DLL_UICACHE_SKIPPED), DLLValue(_G.LUABOOST_DLL_UICACHE_PASSED)))
	Chat("  " .. LText("Runtime_DLLProbeHint", "Copy this block after /reload and send it for adapter analysis."))
end

function Runtime:HandlePerfCommand(command)
	command = lower(command or "")
	if command == "fps" then self:StartFPSProfile(10); return true end
	if command == "events" then self:StartEventProfile(10); return true end
	if command == "memory" or command == "mem" then self:StartMemoryProfile(30); return true end
	if command == "onupdate" or command == "updates" then self:PrintOnUpdateList(30); return true end
	if command == "runtime" or command == "diag" then self:PrintDiagnostics(); return true end
	if command == "dll" or command == "backend" or command == "probe" then self:PrintDLLProbe(); return true end
	if command == "gc" then
		local ok, reason = self:ForceGC("manual", false)
		if not ok then Chat(Prefix() .. " " .. tostring(reason)) end
		return true
	end
	return false
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
	Runtime:Initialize()
	self:UnregisterEvent("PLAYER_LOGIN")
end)
