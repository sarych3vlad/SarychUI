-- SarychUI.Runtime — internal Lua runtime helpers for WoW 3.3.5a (build 12340).
-- Inspired by useful parts of LuaBoost; kept inside the SarychUI namespace.
-- No hard dependency on !LuaBoost or wow_optimize.dll.

local pairs, ipairs, type, tostring, next = pairs, ipairs, type, tostring, next
local floor, min = math.floor, math.min
local format = string.format
local wipe = wipe
local GetTime = GetTime
local CreateFrame = CreateFrame
local pcall = pcall
local geterrorhandler = geterrorhandler
local getmetatable = getmetatable
local setmetatable = setmetatable
local collectgarbage = collectgarbage
local debugprofilestart = debugprofilestart
local debugprofilestop = debugprofilestop
local UnitAffectingCombat = UnitAffectingCombat

local Runtime = {
	VERSION = "2.0.0",
	_enabled = false,
	_initialized = false,
	_coreFrame = nil,
	_eventFrame = nil,
	_dllConfirmed = false,
	_dllPollDone = false,
	_gcOwnsLua = false,
	_inCombat = false,
	_isIdle = false,
	_isLoading = false,
	_lastActivity = 0,
	_cachedTime = 0,
	_frameNumber = 0,
	_updateCallbacks = {},
	_updateCount = 0,
	_throttles = {},
	_pool = {},
	_poolCount = 0,
	_poolMax = 200,
	_poolStats = { acquired = 0, released = 0, created = 0 },
	_gcStats = { stepsLua = 0, fullCollects = 0, emergencyGC = 0 },
	_burstSteps = 0,
	_adaptiveThresholdMB = nil,
	_gcReStopCounter = 0,
	_gcMemCheckCounter = 0,
	_thrashInstallAt = nil,
	_handlers = {},
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

local DLL_MARKERS = {
	"LUABOOST_DLL_LOADED",
	"LUABOOST_DLL_GC_ACTIVE",
	"LUABOOST_DLL_LUA_ALLOC",
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

-- Events that commonly leave a short-lived allocation spike behind.  A single
-- incremental step is enough; doing a full collect here would create stutter.
local BURST_EVENTS = {
	"LFG_PROPOSAL_SHOW",
	"LFG_PROPOSAL_SUCCEEDED",
	"LFG_COMPLETION_REWARD",
	"ACHIEVEMENT_EARNED",
	"CHAT_MSG_LOOT",
}

-- StatusBar thrash guard, adapted from LuaBoost 1.9.7.  Only StatusBar methods
-- are wrapped; FontString/secure-frame APIs are intentionally left untouched.
local thrashCache = setmetatable({}, { __mode = "k" })
local thrashOriginals = {}
local thrashWrappers = {}
local thrashMeta
local thrashReady = false
local thrashStats = { skipped = 0, passed = 0, hooked = 0, active = false }

local K_VALUE, K_MIN, K_MAX = 1, 2, 3
local K_R, K_G, K_B, K_A = 4, 5, 6, 7
local K_VALUE_SET, K_RANGE_SET, K_COLOR_SET = 8, 9, 10

local function DB()
	local db = SarychUI and SarychUI.db and SarychUI.db.profile
	local sys = db and db.system
	return sys and sys.runtime
end

local function DebugPrint(msg)
	local cfg = DB()
	if not cfg or not cfg.debug then return end
	if SarychUI.GetScopedChatPrefix then
		print(SarychUI:GetScopedChatPrefix("Runtime") .. " " .. tostring(msg))
	else
		print("|cffffd200SarychUI Runtime:|r " .. tostring(msg))
	end
end

local function IsRealDllFunction(fn)
	-- Reject LuaBoost-style stubs that always return true / zeros.
	-- Real DLL exports are C closures; we only trust marker globals + non-stub C API.
	return type(fn) == "function"
end

function Runtime:DetectDll()
	if self._dllConfirmed then
		return true
	end
	for i = 1, #DLL_MARKERS do
		if _G[DLL_MARKERS[i]] ~= nil then
			self._dllConfirmed = true
			self:InvalidateEnvCache()
			return true
		end
	end
	-- Prefer Compatibility layer if it already confirmed the DLL.
	local compat = SarychUI and SarychUI.Compatibility
	if compat and compat.DetectWowOptimizeDll and compat:DetectWowOptimizeDll() then
		self._dllConfirmed = true
		self:InvalidateEnvCache()
		return true
	end
	-- Do NOT treat LuaBoostC_* alone as proof: !LuaBoost installs Lua stubs
	-- that return true even when the DLL is absent.
	return false
end

function Runtime:IsDllGcActive()
	if not self:DetectDll() then
		return false
	end
	-- Marker means DLL owns GC stepping.
	if _G.LUABOOST_DLL_GC_ACTIVE ~= nil then
		return true
	end
	if _G.LUABOOST_DLL_LOADED ~= nil then
		return true
	end
	return self:DetectDll()
end

-- True when standalone !LuaBoost / LuaBoost addon is present (conflict with our GC).
-- Result is cached: the addon list cannot change after login, and this is queried
-- from OnUpdate where an uncached IsAddOnLoaded would cost 4-6 calls per frame.
function Runtime:IsLuaBoostAddonPresent()
	local cached = self._envLuaBoost
	if cached ~= nil then
		return cached
	end

	local present = false
	if _G.LUABOOST_LOADED then
		present = true
	elseif IsAddOnLoaded and (IsAddOnLoaded("!LuaBoost") == true or IsAddOnLoaded("LuaBoost") == true) then
		present = true
	else
		local compat = SarychUI and SarychUI.Compatibility
		if compat and compat.IsLuaBoostLoaded and compat:IsLuaBoostLoaded() then
			present = true
		end
	end

	self._envLuaBoost = present
	return present
end

-- Drops cached environment flags. Called when DLL detection flips state.
function Runtime:InvalidateEnvCache()
	self._envLuaBoost = nil
	self._envExternalGc = nil
end

function Runtime:IsBlockedByLuaBoost()
	return self:IsLuaBoostAddonPresent()
end

-- True when another manager already owns collectgarbage stepping.
-- Cached for the same reason as IsLuaBoostAddonPresent; invalidated on DLL detection.
function Runtime:IsExternalGcManager()
	local cached = self._envExternalGc
	if cached ~= nil then
		return cached
	end
	local external = self:IsDllGcActive() or self:IsLuaBoostAddonPresent()
	self._envExternalGc = external
	return external
end

function Runtime:GetDb()
	return DB()
end

function Runtime:IsGcEnabled()
	local cfg = DB()
	if not cfg or cfg.enabled ~= true then
		return false
	end
	-- !LuaBoost owns GC — never step in parallel.
	if self:IsBlockedByLuaBoost() then
		return false
	end
	return true
end

function Runtime:GetGcController()
	if self:IsDllGcActive() then
		return "DLL"
	end
	if self:IsLuaBoostAddonPresent() then
		return "LuaBoost"
	end
	if self:IsGcEnabled() and self._enabled then
		return "SarychUI"
	end
	return "Blizzard"
end

function Runtime:GetGcMode()
	if self._isLoading then return "loading" end
	if self._inCombat then return "combat" end
	if self._isIdle then return "idle" end
	return "normal"
end

function Runtime:GetMemoryMB()
	return collectgarbage("count") / 1024
end

function Runtime:GetTimeCached()
	if self._cachedTime > 0 then
		return self._cachedTime
	end
	return GetTime()
end

function Runtime:GetFrameNumber()
	return self._frameNumber
end

function Runtime:Throttle(id, interval)
	if type(id) ~= "string" then return false end
	interval = interval or 0
	local now = self:GetTimeCached()
	local last = self._throttles[id]
	if not last or (now - last) >= interval then
		self._throttles[id] = now
		return true
	end
	return false
end

function Runtime:AcquireTable()
	local stats = self._poolStats
	stats.acquired = stats.acquired + 1
	if self._poolCount > 0 then
		local t = self._pool[self._poolCount]
		self._pool[self._poolCount] = nil
		self._poolCount = self._poolCount - 1
		return t
	end
	stats.created = stats.created + 1
	return {}
end

function Runtime:ReleaseTable(t)
	if type(t) ~= "table" then return end
	if self._poolCount >= self._poolMax then return end
	if getmetatable(t) then return end
	self._poolStats.released = self._poolStats.released + 1
	local k = next(t)
	while k ~= nil do
		t[k] = nil
		k = next(t)
	end
	self._poolCount = self._poolCount + 1
	self._pool[self._poolCount] = t
end

function Runtime:GetPoolStats()
	local s = self._poolStats
	return s.acquired, s.released, s.created, self._poolCount
end

function Runtime:GetThrashGuardStats()
	local widgets = 0
	for _ in pairs(thrashCache) do
		widgets = widgets + 1
	end
	return thrashStats.skipped, thrashStats.passed, thrashStats.hooked,
		thrashStats.active, widgets
end

function Runtime:InvalidateWidget(widget)
	local cached = widget and thrashCache[widget]
	if not cached then return end
	thrashCache[widget] = nil
	self:ReleaseTable(cached)
end

function Runtime:InstallThrashGuard()
	if thrashStats.active or self:IsDllGcActive() then return false end
	local cfg = DB()
	if not cfg or cfg.enabled ~= true or cfg.uiCacheEnabled == false then
		return false
	end

	local probe = CreateFrame("StatusBar")
	local mt = getmetatable(probe)
	probe:Hide()
	if not mt or not mt.__index then
		DebugPrint("StatusBar cache unavailable: metatable not found")
		return false
	end

	thrashMeta = mt.__index
	local hooked = 0

	if type(thrashMeta.SetValue) == "function" then
		local original = thrashMeta.SetValue
		thrashOriginals.SetValue = original
		local wrapper = function(widget, value)
			if not thrashReady or type(value) ~= "number" then
				return original(widget, value)
			end
			local cached = thrashCache[widget]
			if cached and cached[K_VALUE_SET] and cached[K_VALUE] == value then
				thrashStats.skipped = thrashStats.skipped + 1
				return
			end
			if not cached then
				cached = Runtime:AcquireTable()
				thrashCache[widget] = cached
			end
			cached[K_VALUE] = value
			cached[K_VALUE_SET] = true
			thrashStats.passed = thrashStats.passed + 1
			return original(widget, value)
		end
		local ok = pcall(function() thrashMeta.SetValue = wrapper end)
		if ok then
			thrashWrappers.SetValue = wrapper
			hooked = hooked + 1
		end
	end

	if type(thrashMeta.SetMinMaxValues) == "function" then
		local original = thrashMeta.SetMinMaxValues
		thrashOriginals.SetMinMaxValues = original
		local wrapper = function(widget, low, high)
			if not thrashReady then
				return original(widget, low, high)
			end
			local cached = thrashCache[widget]
			if cached and cached[K_RANGE_SET]
				and cached[K_MIN] == low and cached[K_MAX] == high then
				thrashStats.skipped = thrashStats.skipped + 1
				return
			end
			if not cached then
				cached = Runtime:AcquireTable()
				thrashCache[widget] = cached
			end
			cached[K_MIN], cached[K_MAX] = low, high
			cached[K_RANGE_SET] = true
			cached[K_VALUE_SET] = nil
			thrashStats.passed = thrashStats.passed + 1
			return original(widget, low, high)
		end
		local ok = pcall(function() thrashMeta.SetMinMaxValues = wrapper end)
		if ok then
			thrashWrappers.SetMinMaxValues = wrapper
			hooked = hooked + 1
		end
	end

	if type(thrashMeta.SetStatusBarColor) == "function" then
		local original = thrashMeta.SetStatusBarColor
		thrashOriginals.SetStatusBarColor = original
		local wrapper = function(widget, r, g, b, a)
			if not thrashReady then
				return original(widget, r, g, b, a)
			end
			local cached = thrashCache[widget]
			if cached and cached[K_COLOR_SET]
				and cached[K_R] == r and cached[K_G] == g
				and cached[K_B] == b and cached[K_A] == a then
				thrashStats.skipped = thrashStats.skipped + 1
				return
			end
			if not cached then
				cached = Runtime:AcquireTable()
				thrashCache[widget] = cached
			end
			cached[K_R], cached[K_G], cached[K_B], cached[K_A] = r, g, b, a
			cached[K_COLOR_SET] = true
			thrashStats.passed = thrashStats.passed + 1
			return original(widget, r, g, b, a)
		end
		local ok = pcall(function() thrashMeta.SetStatusBarColor = wrapper end)
		if ok then
			thrashWrappers.SetStatusBarColor = wrapper
			hooked = hooked + 1
		end
	end

	thrashStats.hooked = hooked
	thrashStats.active = hooked > 0
	thrashReady = hooked > 0
	DebugPrint(format("StatusBar cache installed (%d/3 hooks)", hooked))
	return hooked > 0
end

function Runtime:UninstallThrashGuard()
	thrashReady = false
	if thrashMeta then
		for method, wrapper in pairs(thrashWrappers) do
			-- Do not overwrite a hook installed by another addon after ours.
			if thrashMeta[method] == wrapper then
				thrashMeta[method] = thrashOriginals[method]
			end
		end
	end
	for widget, cached in pairs(thrashCache) do
		thrashCache[widget] = nil
		self:ReleaseTable(cached)
	end
	wipe(thrashOriginals)
	wipe(thrashWrappers)
	thrashMeta = nil
	thrashStats.hooked = 0
	thrashStats.active = false
end

function Runtime:ScheduleThrashGuard()
	local cfg = DB()
	if not cfg or cfg.enabled ~= true or cfg.uiCacheEnabled == false
		or self:IsLuaBoostAddonPresent() then
		self._thrashInstallAt = nil
		self:UninstallThrashGuard()
		return
	end
	if self:IsDllGcActive() then
		self._thrashInstallAt = nil
		self:UninstallThrashGuard()
		return
	end
	if not thrashStats.active then
		-- DLL globals can arrive late after /reload.  Delay the Lua hook so the
		-- C-level implementation gets first ownership when present.
		self._thrashInstallAt = GetTime() + 8
	end
end

function Runtime:GetUpdateCount()
	return self._updateCount
end

function Runtime:RegisterUpdate(id, interval, callback)
	if type(id) ~= "string" or type(callback) ~= "function" then
		return false
	end
	interval = interval or 0
	if self._updateCallbacks[id] then
		self._updateCallbacks[id].interval = interval
		self._updateCallbacks[id].fn = callback
		return true
	end
	self._updateCallbacks[id] = {
		interval = interval,
		last = 0,
		fn = callback,
	}
	self._updateCount = self._updateCount + 1
	self:EnsureCoreFrame()
	return true
end

function Runtime:UnregisterUpdate(id)
	if self._updateCallbacks[id] then
		self._updateCallbacks[id] = nil
		self._updateCount = self._updateCount - 1
		return true
	end
	return false
end

function Runtime:NormalizeConfig()
	local cfg = DB()
	if not cfg then return end
	local aliases = { weak = "light", mid = "standard", strong = "heavy" }
	if aliases[cfg.preset] then
		cfg.preset = aliases[cfg.preset]
	end
	if not PRESETS[cfg.preset] then
		cfg.preset = "standard"
		for k, v in pairs(PRESETS.standard) do
			cfg[k] = v
		end
	end
	if cfg.uiCacheEnabled == nil then
		cfg.uiCacheEnabled = true
	end
end

function Runtime:ApplyPreset(name)
	local cfg = DB()
	local preset = PRESETS[name]
	if not cfg or not preset then return false end
	for k, v in pairs(preset) do
		cfg[k] = v
	end
	cfg.preset = name
	self._adaptiveThresholdMB = nil
	self:SyncStepsToDll()
	return true
end

function Runtime:SyncStepsToDll()
	local cfg = DB()
	if not cfg then return end
	-- Public addon→DLL channel used by wow_optimize / LuaBoost.
	_G.LUABOOST_ADDON_STEP_NORMAL = cfg.frameStepKB
	_G.LUABOOST_ADDON_STEP_COMBAT = cfg.combatStepKB
	_G.LUABOOST_ADDON_STEP_IDLE = cfg.idleStepKB
	_G.LUABOOST_ADDON_STEP_LOADING = cfg.loadingStepKB
end

function Runtime:WriteStateGlobals()
	_G.LUABOOST_ADDON_COMBAT = self._inCombat and true or false
	_G.LUABOOST_ADDON_IDLE = self._isIdle and true or false
	_G.LUABOOST_ADDON_LOADING = self._isLoading and true or false
end

function Runtime:NotifyDllCombat(inCombat)
	if not self:DetectDll() then return end
	local fn = _G.LuaBoostC_SetCombat
	if IsRealDllFunction(fn) then
		pcall(fn, inCombat and true or false)
	end
end

function Runtime:NotifyDllGcStep(kb)
	if not self:DetectDll() then return end
	local fn = _G.LuaBoostC_GCStep
	if IsRealDllFunction(fn) then
		pcall(fn, kb)
	end
end

function Runtime:NotifyDllGcCollect()
	if not self:DetectDll() then return end
	local fn = _G.LuaBoostC_GCCollect
	if IsRealDllFunction(fn) then
		pcall(fn)
	end
end

function Runtime:GetCurrentStepKB()
	local cfg = DB()
	if not cfg then return 0 end
	if self._isLoading then return cfg.loadingStepKB or 0 end
	if self._inCombat then return cfg.combatStepKB or 0 end
	if self._isIdle then return cfg.idleStepKB or 0 end
	return cfg.frameStepKB or 0
end

function Runtime:MarkActivity()
	self._lastActivity = self:GetTimeCached()
	if self._isIdle then
		self._isIdle = false
		self:WriteStateGlobals()
		DebugPrint("idle → normal")
	end
end

function Runtime:ForceFullCollect(reason)
	if self._inCombat or UnitAffectingCombat("player") then
		return false, "combat"
	end
	local before = collectgarbage("count")
	if debugprofilestart then debugprofilestart() end
	if self:IsDllGcActive() then
		self:NotifyDllGcCollect()
	else
		collectgarbage("collect")
		collectgarbage("collect")
	end
	local dt = debugprofilestop and debugprofilestop() or 0
	local after = collectgarbage("count")
	self._gcStats.fullCollects = self._gcStats.fullCollects + 1
	if self:IsGcEnabled() and not self:IsDllGcActive() then
		collectgarbage("stop")
	end
	DebugPrint(format("full GC (%s): freed %.1f MB in %.1f ms", tostring(reason or "manual"), (before - after) / 1024, dt))
	return true, (before - after) / 1024, dt
end

local function RegisterHandler(self, event, handler)
	if not self._handlers[event] then
		self._handlers[event] = {}
		if self._eventFrame then
			local ok = pcall(self._eventFrame.RegisterEvent, self._eventFrame, event)
			if not ok then
				self._handlers[event] = nil
				return false
			end
		end
	end
	local list = self._handlers[event]
	list[#list + 1] = handler
	return true
end

function Runtime:EnsureEventFrame()
	if self._eventFrame then return end
	local frame = CreateFrame("Frame")
	self._eventFrame = frame
	frame:SetScript("OnEvent", function(_, event, ...)
		local list = Runtime._handlers[event]
		if not list then return end
		for i = 1, #list do
			local ok, err = pcall(list[i], event, ...)
			if not ok and geterrorhandler then
				geterrorhandler()(err)
			end
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
end

function Runtime:OnUpdate(elapsed)
	self._frameNumber = self._frameNumber + 1
	self._cachedTime = GetTime()

	if self._updateCount > 0 then
		local now = self._cachedTime
		-- Snapshot IDs because a callback may register/unregister another callback.
		-- Reusing a pooled table keeps this mutation-safe without per-frame garbage.
		local ids = self:AcquireTable()
		local count = 0
		for id in pairs(self._updateCallbacks) do
			count = count + 1
			ids[count] = id
		end
		for i = 1, count do
			local data = self._updateCallbacks[ids[i]]
			if data and (data.interval <= 0 or (now - data.last) >= data.interval) then
				data.last = now
				local ok, err = pcall(data.fn, now, elapsed)
				if not ok and geterrorhandler then
					geterrorhandler()(err)
				end
			end
		end
		self:ReleaseTable(ids)
	end

	if self._thrashInstallAt and self._cachedTime >= self._thrashInstallAt then
		self._thrashInstallAt = nil
		if not self:IsDllGcActive() then
			self:InstallThrashGuard()
		end
	end

	if not self._enabled then return end

	-- Single DB() walk per frame; IsGcEnabled would repeat it.
	local cfg = DB()
	if not cfg or cfg.enabled ~= true then return end
	if self:IsBlockedByLuaBoost() then return end

	-- Idle detection
	if not self._isIdle and not self._inCombat and not self._isLoading then
		local timeout = cfg.idleTimeout or 15
		if (self._cachedTime - self._lastActivity) > timeout then
			self._isIdle = true
			self:WriteStateGlobals()
			DebugPrint("idle mode")
		end
	end

	local externalGc = self:IsExternalGcManager()

	-- Keep auto-GC stopped while we own stepping (Lua path only).
	self._gcReStopCounter = self._gcReStopCounter + 1
	if self._gcReStopCounter >= 300 then
		self._gcReStopCounter = 0
		if not externalGc then
			collectgarbage("stop")
		end
	end

	-- DLL / !LuaBoost owns GC: only keep state globals fresh; no Lua step/collect.
	if externalGc then
		self._gcOwnsLua = false
		return
	end
	self._gcOwnsLua = true

	-- Emergency full GC (outside combat/loading), checked every ~60 frames.
	self._gcMemCheckCounter = self._gcMemCheckCounter + 1
	local memKB
	if self._gcMemCheckCounter >= 60 then
		self._gcMemCheckCounter = 0
		memKB = collectgarbage("count")
	end
	local thresholdMB = self._adaptiveThresholdMB or cfg.fullCollectThresholdMB or 300
	if memKB and memKB > (thresholdMB * 1024)
		and not self._inCombat
		and not self._isLoading
		and elapsed < 0.033 then
		if debugprofilestart then debugprofilestart() end
		collectgarbage("collect")
		collectgarbage("collect")
		local dt = debugprofilestop and debugprofilestop() or 0
		local afterKB = collectgarbage("count")
		self._gcStats.emergencyGC = self._gcStats.emergencyGC + 1
		if dt > 50 and thresholdMB < 1000 then
			self._adaptiveThresholdMB = min(1000, thresholdMB + 20)
		end
		collectgarbage("stop")
		DebugPrint(format("emergency GC: freed %.1f MB in %.1f ms (next threshold %d MB)",
			(memKB - afterKB) / 1024, dt, self._adaptiveThresholdMB or thresholdMB))
		return
	end

	-- Inlined GetCurrentStepKB to reuse the cfg already fetched above.
	local stepKB
	if self._isLoading then
		stepKB = cfg.loadingStepKB
	elseif self._inCombat then
		stepKB = cfg.combatStepKB
	elseif self._isIdle then
		stepKB = cfg.idleStepKB
	else
		stepKB = cfg.frameStepKB
	end

	local step = floor(stepKB or 0)
	if step > 0 then
		collectgarbage("step", step)
		self._gcStats.stepsLua = self._gcStats.stepsLua + 1
	end
end

function Runtime:OnCombatEvent(event)
	if event == "PLAYER_REGEN_DISABLED" then
		self:MarkActivity()
		self._inCombat = true
		self:WriteStateGlobals()
		self:NotifyDllCombat(true)
	elseif event == "PLAYER_REGEN_ENABLED" then
		self:MarkActivity()
		self._inCombat = false
		self:WriteStateGlobals()
		self:NotifyDllCombat(false)
		if self:IsGcEnabled() then
			if self:IsDllGcActive() then
				self:NotifyDllGcStep(256)
			else
				collectgarbage("step", 50)
				self._gcStats.stepsLua = self._gcStats.stepsLua + 1
			end
			self._burstSteps = self._burstSteps + 1
		end
	end
end

function Runtime:OnBurstEvent(event)
	if not self:IsGcEnabled() or self._inCombat then return end
	local stepKB = 128
	if self:IsDllGcActive() then
		self:NotifyDllGcStep(stepKB)
	else
		collectgarbage("step", stepKB)
		self._gcStats.stepsLua = self._gcStats.stepsLua + 1
	end
	self._burstSteps = self._burstSteps + 1
	if event ~= "CHAT_MSG_LOOT" then
		DebugPrint(format("burst GC: %s (%d KB)", tostring(event), stepKB))
	end
end

function Runtime:OnLoadingEvent(event)
	if event == "PLAYER_LEAVING_WORLD" or event == "LOADING_SCREEN_ENABLED" then
		if not self._isLoading then
			self._isLoading = true
			self:WriteStateGlobals()
		end
	elseif event == "PLAYER_ENTERING_WORLD" or event == "LOADING_SCREEN_DISABLED" then
		if self._isLoading then
			self._isLoading = false
			self:WriteStateGlobals()
			self:MarkActivity()
			if self:IsGcEnabled() and not self._inCombat then
				-- Light post-load cleanup; DLL path notifies DLL instead of full Lua collect.
				if self:IsDllGcActive() then
					self:NotifyDllGcCollect()
				else
					collectgarbage("step", self:GetCurrentStepKB() > 0 and self:GetCurrentStepKB() or 100)
				end
			end
		end
	end
end

function Runtime:BindEvents()
	if self._eventsBound then return end
	self:EnsureEventFrame()
	RegisterHandler(self, "PLAYER_REGEN_DISABLED", function(e) Runtime:OnCombatEvent(e) end)
	RegisterHandler(self, "PLAYER_REGEN_ENABLED", function(e) Runtime:OnCombatEvent(e) end)
	RegisterHandler(self, "PLAYER_LEAVING_WORLD", function(e) Runtime:OnLoadingEvent(e) end)
	RegisterHandler(self, "PLAYER_ENTERING_WORLD", function(e) Runtime:OnLoadingEvent(e) end)
	RegisterHandler(self, "LOADING_SCREEN_ENABLED", function(e) Runtime:OnLoadingEvent(e) end)
	RegisterHandler(self, "LOADING_SCREEN_DISABLED", function(e) Runtime:OnLoadingEvent(e) end)
	for i = 1, #ACTIVITY_EVENTS do
		RegisterHandler(self, ACTIVITY_EVENTS[i], function() Runtime:MarkActivity() end)
	end
	for i = 1, #BURST_EVENTS do
		RegisterHandler(self, BURST_EVENTS[i], function(e) Runtime:OnBurstEvent(e) end)
	end
	self._eventsBound = true
end

function Runtime:UnbindEvents()
	if self._eventFrame then
		self._eventFrame:UnregisterAllEvents()
		self._eventFrame:SetScript("OnEvent", nil)
		self._eventFrame = nil
	end
	wipe(self._handlers)
	self._eventsBound = false
end

function Runtime:StartDllPoll()
	if self._dllConfirmed or self._dllPollDone then return end
	local poll = CreateFrame("Frame")
	local elapsed = 0
	local timer = 0
	poll:SetScript("OnUpdate", function(self, dt)
		elapsed = elapsed + (dt or 0)
		timer = timer + (dt or 0)
		if timer >= 0.5 then
			timer = 0
			if Runtime:DetectDll() then
				Runtime:SyncStepsToDll()
				Runtime:WriteStateGlobals()
				Runtime._thrashInstallAt = nil
				Runtime:UninstallThrashGuard()
				DebugPrint("wow_optimize.dll detected")
				self:SetScript("OnUpdate", nil)
				Runtime._dllPollDone = true
				return
			end
		end
		if elapsed >= 5 then
			Runtime._dllPollDone = true
			self:SetScript("OnUpdate", nil)
		end
	end)
end

function Runtime:ApplyGcOwnership()
	local cfg = DB()
	if not cfg or not cfg.enabled then
		if self._gcOwnsLua then
			collectgarbage("restart")
			self._gcOwnsLua = false
		end
		return
	end
	if self:IsExternalGcManager() then
		-- DLL or !LuaBoost manages GC; do not stop/restart from Lua.
		self._gcOwnsLua = false
		self:SyncStepsToDll()
		return
	end
	collectgarbage("stop")
	self._gcOwnsLua = true
end

function Runtime:Enable()
	-- !LuaBoost present: keep dispatcher, never take GC ownership.
	if self:IsBlockedByLuaBoost() then
		self:Disable()
		self:EnsureCoreFrame()
		self:BindEvents()
		self:StartDllPoll()
		DebugPrint("GC blocked — !LuaBoost detected")
		return
	end
	if self._enabled then
		self:ApplyGcOwnership()
		self:ScheduleThrashGuard()
		return
	end
	self._enabled = true
	self._lastActivity = GetTime()
	self._cachedTime = self._lastActivity
	self._inCombat = UnitAffectingCombat("player") and true or false
	self:EnsureCoreFrame()
	self:BindEvents()
	self:WriteStateGlobals()
	self:SyncStepsToDll()
	self:ApplyGcOwnership()
	self:StartDllPoll()
	self:ScheduleThrashGuard()
	DebugPrint("enabled (GC controller: " .. self:GetGcController() .. ")")
end

function Runtime:Disable()
	if not self._enabled and not self._coreFrame then
		return
	end
	self._enabled = false
	self._thrashInstallAt = nil
	self:UninstallThrashGuard()

	-- Keep dispatcher + state events alive; only release Lua GC ownership.
	if self._gcOwnsLua then
		collectgarbage("restart")
		self._gcOwnsLua = false
	end

	self._isIdle = false
	-- Keep loading/combat flags accurate for diagnostics and DLL sync.
	self:WriteStateGlobals()
	DebugPrint("GC manager disabled")
end

function Runtime:Refresh()
	-- Re-evaluate the environment on explicit refresh (addon list / DLL may now be known).
	self:InvalidateEnvCache()
	self:NormalizeConfig()

	-- Always force off when !LuaBoost is loaded (do not change saved preference).
	if self:IsBlockedByLuaBoost() then
		self:Disable()
		self:EnsureCoreFrame()
		if not self._eventFrame then
			self:BindEvents()
		end
		return
	end

	local cfg = DB()
	if cfg and cfg.enabled then
		self:Enable()
		self:ApplyGcOwnership()
		self:SyncStepsToDll()
	else
		self:Disable()
		-- Dispatcher-only mode: still serve RegisterUpdate callers + DLL state sync.
		self:EnsureCoreFrame()
		if not self._eventFrame then
			self:BindEvents()
		end
		if self:DetectDll() then
			self:SyncStepsToDll()
		end
	end
end

function Runtime:Initialize()
	if self._initialized then return end
	self._initialized = true
	self:NormalizeConfig()
	-- Always provide dispatcher/pool APIs; GC follows settings.
	self:EnsureCoreFrame()
	self:BindEvents()
	self._lastActivity = GetTime()
	self._cachedTime = self._lastActivity
	self:WriteStateGlobals()
	local cfg = DB()
	if cfg and cfg.enabled then
		self:Enable()
	end
	self:StartDllPoll()
end

function Runtime:Shutdown()
	-- Full teardown used when SarychUI disables.
	for id in pairs(self._updateCallbacks) do
		self._updateCallbacks[id] = nil
	end
	self._updateCount = 0
	wipe(self._throttles)
	self:Disable()
	if self._coreFrame then
		self._coreFrame:SetScript("OnUpdate", nil)
		self._coreFrame = nil
	end
	self._poolCount = 0
	wipe(self._pool)
end

function Runtime:GetDiagnostics()
	local cfg = DB()
	local acq, rel, cre, avail = self:GetPoolStats()
	local skipped, passed, hooked, thrashActive, widgets = self:GetThrashGuardStats()
	return {
		version = self.VERSION,
		memoryMB = self:GetMemoryMB(),
		gcEnabled = self:IsGcEnabled(),
		gcController = self:GetGcController(),
		gcMode = self:GetGcMode(),
		dllActive = self:DetectDll(),
		dllGcActive = self:IsDllGcActive(),
		updateCount = self._updateCount,
		poolAcquired = acq,
		poolReleased = rel,
		poolCreated = cre,
		poolAvailable = avail,
		stepsLua = self._gcStats.stepsLua,
		emergencyGC = self._gcStats.emergencyGC,
		fullCollects = self._gcStats.fullCollects,
		burstSteps = self._burstSteps,
		preset = cfg and cfg.preset or "standard",
		frameStepKB = self:GetCurrentStepKB(),
		emergencyThresholdMB = self._adaptiveThresholdMB or (cfg and cfg.fullCollectThresholdMB) or 300,
		uiCacheActive = thrashActive,
		uiCacheEnabled = not cfg or cfg.uiCacheEnabled ~= false,
		uiCacheHooks = hooked,
		uiCacheWidgets = widgets,
		uiCacheSkipped = skipped,
		uiCachePassed = passed,
	}
end

function Runtime:PrintDiagnostics()
	local d = self:GetDiagnostics()
	local prefix = SarychUI.GetScopedChatPrefix and SarychUI:GetScopedChatPrefix("Runtime") or "|cffffd200SarychUI Runtime:|r"
	print(prefix .. " v" .. tostring(d.version) .. " diagnostics")
	print(format("  Lua memory: |cffffff00%.1f MB|r", d.memoryMB))
	print(format("  GC manager: %s", d.gcEnabled and "|cff00ff00ON|r" or "|cffaaaaaaOFF|r"))
	print(format("  GC controller: |cffffff00%s|r", d.gcController))
	print(format("  GC mode: |cffffff00%s|r (%d KB/f)", d.gcMode, d.frameStepKB or 0))
	print(format("  wow_optimize.dll: %s", d.dllActive and "|cff00ff00detected|r" or "|cffaaaaaanot detected|r"))
	print(format("  Dispatcher callbacks: |cffffff00%d|r", d.updateCount))
	print(format("  Table pool: acq=%d rel=%d created=%d avail=%d", d.poolAcquired, d.poolReleased, d.poolCreated, d.poolAvailable))
	print(format("  StatusBar cache: %s (%d/3 hooks, %d widgets, %d redundant calls skipped)",
		d.uiCacheActive and "ON" or "OFF", d.uiCacheHooks, d.uiCacheWidgets, d.uiCacheSkipped))
	print(format("  Stats: steps=%d burst=%d emergency=%d full=%d", d.stepsLua, d.burstSteps, d.emergencyGC, d.fullCollects))
	if d.dllGcActive or d.gcController == "DLL" or d.gcController == "LuaBoost" then
		print("  |cff88aaffLua GC steps skipped — external manager owns garbage collection.|r")
	end
end

-- Early init after defaults/db are ready (called from SarychUI OnInitialize/OnEnable).
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
	if SarychUI and SarychUI.Runtime then
		SarychUI.Runtime:Initialize()
	end
	self:UnregisterEvent("PLAYER_LOGIN")
end)
