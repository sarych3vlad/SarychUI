--[[
    Aegis Framework
    Copyright (c) 2026 s0high. All rights reserved.

    Restricted proprietary library. See LICENSE for terms.
]]

local MAJOR, MINOR = "Aegis-2.0", 2;
local Aegis = LibStub:NewLibrary(MAJOR, MINOR);
if not Aegis then
	return;
end

--@natives<lua>
local _G = _G;
local pairs = pairs;
local select = select;
local type = type;
local tostring = tostring;
local format = string.format;
local print = print;

Aegis.entries = Aegis.entries or {};
Aegis.data = Aegis.data or {};

-- -------------------- Debug / Logging --------------------

Aegis.debugEnabled = Aegis.debugEnabled or false;
Aegis.logger = Aegis.logger or nil;

function Aegis:SetDebugEnabled(enabled)
	self.debugEnabled = enabled and true or false;
end

function Aegis:IsDebugEnabled()
	return self.debugEnabled;
end

function Aegis:SetLogger(logger)
	-- Expected logger shape:
	-- {
	--   Log = function(level, msg, ...) end
	-- }
	self.logger = logger;
end

function Aegis:WriteLog(level, msg, ...)
	if level == "DEBUG" and not self.debugEnabled then
		return
	end

	if self.logger and type(self.logger.Log) == "function" then
		return self.logger.Log(level, msg, ...);
	end

	-- Fallback logger if host logger is not configured
	if select("#", ...) > 0 then
		print(format("[Aegis:%s] ", level) .. format(msg, ...));
	else
		print(format("[Aegis:%s] %s", level, tostring(msg)));
	end
end

function Aegis:Debug(msg, ...)
	self:WriteLog("DEBUG", msg, ...);
end

function Aegis:Warn(msg, ...)
	self:WriteLog("WARN", msg, ...);
end

function Aegis:Error(msg, ...)
	self:WriteLog("ERROR", msg, ...);
end

-- -------------------- Debug End --------------------

--- where ​... are the mixins to mixin
function Aegis:Mixin(object, ...)
	for i = 1, select("#", ...) do
		local mixin = select(i, ...);
		if mixin then
			for key, value in pairs(mixin) do
				object[key] = value;
			end
		end
	end
	return object;
end

function Aegis:CreateFromMixins(...)
	return self:Mixin({}, ...);
end

local function MakeEntryKey(kind, name)
	return kind .. ":" .. name;
end

function Aegis:RegisterEntry(kind, name, version, constructor, options)
	if type(kind) ~= "string" or type(name) ~= "string" or type(version) ~= "number" or type(constructor) ~= "function" then
		error("Usage: Aegis:RegisterEntry(kind, name, version, constructor[, options])", 2);
	end

	local key = MakeEntryKey(kind, name);
	local current = self.entries[key];

	if current and current.version > version then
		return;
	end

	local state = current and current.state or {};
	local instance = current and current.instance or nil;
	local mergedOptions = current and current.options or {};

	if options then
		for k, v in pairs(options) do
			mergedOptions[k] = v;
		end
	end

	self.entries[key] = {
		kind = kind,
		name = name,
		version = version,
		constructor = constructor,
		state = state,
		instance = instance,
		options = mergedOptions,
	};

	if instance then
		local upgraded = constructor(self, state, instance);
		if upgraded ~= nil then
			self.entries[key].instance = upgraded;
		end
	end
end

function Aegis:GetEntry(kind, name)
	local entry = self.entries[MakeEntryKey(kind, name)];
	if not entry then
		return nil;
	end

--[[
	{
		trustNative = true,   -- try to use trusted native namespace
		wrapNative = false,   -- if true, constructor is called even if native is present
		globalName = nil,     -- if the global name differs from `name`
	}
]]
	if not entry.instance then
		local native;

		if kind == "namespace" and entry.options and entry.options.trustNative then
			native = self:ResolveTrustedNativeNamespace(name, entry.options.globalName);

			if native and not entry.options.wrapNative then
				entry.instance = native;
				return entry.instance;
			end
		end

		entry.instance = entry.constructor(self, entry.state, nil, native);
	end

	return entry.instance;
end

function Aegis:RegisterNamespace(name, version, constructor, options)
	self:RegisterEntry("namespace", name, version, constructor, options);
end

function Aegis:GetNamespace(name)
	return self:GetEntry("namespace", name);
end

function Aegis:RegisterService(name, version, constructor, options)
	self:RegisterEntry("service", name, version, constructor, options);
end

function Aegis:GetService(name)
	return self:GetEntry("service", name);
end

function Aegis:ResolveTrustedNativeNamespace(name, globalName)
	local Environment = self:GetService("Environment");
	if not Environment then
		return nil;
	end

	return Environment:ResolveNative(name, globalName);
end

--[[ global exposure; optional
function Aegis:ExposeNamespace(name, targetTable)
	local namespace = self:GetNamespace(name);
	if not namespace then
		return nil;
	end

	(targetTable or _G)[name] = namespace;
	return namespace;
end
]]