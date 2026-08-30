--[[
    Aegis Framework
    Copyright (c) 2026 s0high. All rights reserved.

    Restricted proprietary library. See LICENSE for terms.
]]

local Aegis = LibStub("Aegis-2.0");

local _G = _G;
local type = type;
local tonumber = tonumber;
local rawget = rawget;

local VERSION = 3;

local TrustRules = Aegis.data and Aegis.data.NamespaceTrustRules or {};
local EnvironmentProbes = Aegis.data and Aegis.data.EnvironmentProbes or {};

local function SafeGetBuildInfo()
	if type(_G.GetBuildInfo) ~= "function" then
		return nil, nil, nil, 0
	end

	local versionString, buildString, buildDate, tocVersion = _G.GetBuildInfo()
	return versionString, buildString, buildDate, tonumber(tocVersion) or 0
end

local function HasRequiredMethods(namespace, requiredMethods)
	if type(namespace) ~= "table" then
		return false
	end

	for i = 1, #requiredMethods do
		local methodName = requiredMethods[i]
		if type(namespace[methodName]) ~= "function" then
			return false
		end
	end

	return true
end

local function InRange(value, minValue, maxValue)
	return value >= minValue and value <= maxValue
end

local function IsRuleArray(rule)
	return type(rule) == "table" and rule[1] ~= nil
end

local function IsTrustedByRule(name, namespace)
	local rule = TrustRules[name]
	if not rule then
		return false
	end

	if type(rule) == "function" then
		return rule(namespace)
	end

	if IsRuleArray(rule) then
		return HasRequiredMethods(namespace, rule)
	end

	if type(rule) == "table" and rule.requiredMethods then
		return HasRequiredMethods(namespace, rule.requiredMethods)
	end

	return false
end

local function CountMatchingProbes(probes)
	local matched = 0

	for i = 1, #probes do
		local probe = probes[i]
		local namespace = _G[probe.globalName or probe.name]

		if HasRequiredMethods(namespace, probe.requiredMethods) then
			matched = matched + 1
		end
	end

	return matched
end

local function IsClassicEraTOC(tocVersion)
	-- Official Blizzard Vanilla / Era line
	return InRange(tocVersion, 11300, 19999);
end

local function IsClassicProgressionTOC(tocVersion)
	-- Official Blizzard progression line:
	-- TBC Classic, Wrath Classic, Cata Classic, MoP Classic, etc.
	-- return tocVersion >= 20500 and tocVersion < 100000
	return
		InRange(tocVersion, 11300, 19999) or
		InRange(tocVersion, 20500, 29999) or
		InRange(tocVersion, 30400, 39999) or
		InRange(tocVersion, 40400, 49999) or
		InRange(tocVersion, 50500, 59999);
end

local function IsMainlineTOC(tocVersion)
	return tocVersion >= 100000;
end

local function DetectEnvironment()
	local versionString, buildString, buildDate, tocVersion = SafeGetBuildInfo();

	local info = {
		versionString = versionString,
		buildString = buildString,
		buildDate = buildDate,
		tocVersion = tocVersion,

		-- diagnostic only, not trusted for policy
		projectID = rawget(_G, "WOW_PROJECT_ID"),

		isLegacyClient = false,
		isModernClient = false,

		isMainline = false,
		isClassicClient = false,
		isClassicEra = false,
		isClassicProgression = false,

		isUnknown = false,
		isSuspicious = false,

		branch = "unknown",
		probeScore = 0,
	};

	-- Strict legacy support target
	if tocVersion == 30300 then
		info.isLegacyClient = true;
		info.branch = "legacy-wrath";
		return info;
	end

	-- Official Blizzard modern branches
	if IsClassicEraTOC(tocVersion) then
		info.isModernClient = true;
		info.isClassicClient = true;
		info.isClassicEra = true;
		info.branch = "classic-era";
		return info;
	end

	if IsClassicProgressionTOC(tocVersion) then
		info.isModernClient = true;
		info.isClassicClient = true;
		info.isClassicProgression = true;
		info.branch = "classic-progression";
		return info;
	end

	if IsMainlineTOC(tocVersion) then
		info.isModernClient = true;
		info.isMainline = true;
		info.branch = "mainline";
		return info;
	end

	-- Unknown / suspicious environment fallback
	local modernProbes = EnvironmentProbes.modern or {};
	local modernThreshold = EnvironmentProbes.modernThreshold or 1;
	local modernScore = CountMatchingProbes(modernProbes);

	info.probeScore = modernScore;
	info.isUnknown = true;
	info.isSuspicious = true;

	if modernScore >= modernThreshold then
		info.isModernClient = true;
		info.branch = "mainline-unknown";
	else
		info.isLegacyClient = true;
		info.branch = "legacy-unknown";
	end

	return info;
end

local EnvironmentMixin = {};

function EnvironmentMixin:OnLoad()
	self.info = self.info or DetectEnvironment()
	self.warnedNamespaces = self.warnedNamespaces or {}
	self.debugWarnings = self.debugWarnings or false
end

function EnvironmentMixin:GetInfo()
	return self.info
end

function EnvironmentMixin:GetBranch()
	return self.info.branch
end

function EnvironmentMixin:IsLegacyClient()
	return self.info.isLegacyClient
end

function EnvironmentMixin:IsModernClient()
	return self.info.isModernClient
end

function EnvironmentMixin:IsMainline()
	return self.info.isMainline
end

function EnvironmentMixin:IsClassicClient()
	return self.info.isClassicClient
end

function EnvironmentMixin:IsClassicEra()
	return self.info.isClassicEra
end

function EnvironmentMixin:IsClassicProgression()
	return self.info.isClassicProgression
end

function EnvironmentMixin:IsUnknown()
	return self.info.isUnknown
end

function EnvironmentMixin:IsSuspicious()
	return self.info.isSuspicious
end

function EnvironmentMixin:SetDebugWarningsEnabled(enabled)
	self.debugWarnings = enabled and true or false
end

function EnvironmentMixin:ShouldUseNativeNamespace(name, namespace)
	-- Hard rule:
	-- strict legacy clients never trust global C_* / object API namespaces.
	if self.info.isLegacyClient then
		return false
	end

	if not self.info.isModernClient then
		return false
	end

	return IsTrustedByRule(name, namespace)
end

function EnvironmentMixin:GetTrustedNativeNamespace(name, namespace)
	if namespace and not self:ShouldUseNativeNamespace(name, namespace) then
		self:WarnSuspiciousGlobalNamespace(name, namespace)
		return nil
	end

	if self:ShouldUseNativeNamespace(name, namespace) then
		return namespace
	end

	return nil
end

function EnvironmentMixin:ResolveNative(name, globalName)
	return self:GetTrustedNativeNamespace(name, _G[globalName or name])
end

function EnvironmentMixin:WarnSuspiciousGlobalNamespace(name, namespace)
	if not self.debugWarnings then
		return
	end

	if not namespace then
		return
	end

	if self.warnedNamespaces[name] then
		return
	end
	self.warnedNamespaces[name] = true

	Aegis:Warn("Ignored unexpected global namespace in %s mode: %s", self.info.branch, name)
end

Aegis:RegisterService("Environment", VERSION, function(core, _, service)
	service = service or core:CreateFromMixins(EnvironmentMixin)
	service:OnLoad()
	return service
end)