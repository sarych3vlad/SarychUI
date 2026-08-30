--[[
    Aegis Framework
    Copyright (c) 2026 s0high. All rights reserved.

    Restricted proprietary library. See LICENSE for terms.
]]

local Aegis = LibStub("Aegis-2.0");

local CreateFrame = CreateFrame
local GetTime = GetTime
local xpcall = xpcall
local unpack = unpack
local tostring = tostring
local type = type
local pairs = pairs
local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME
local CallErrorHandler = CallErrorHandler
local geterrorhandler = geterrorhandler

local VERSION = 2
local CANCELED_SENTINEL = {}


local function ResolveErrorHandler()
	if type(geterrorhandler) == "function" then
		return geterrorhandler()
	end

	if type(CallErrorHandler) == "function" then
		return CallErrorHandler
	end

	return function(err)
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Aegis-2.0 error:|r " .. tostring(err))
		end
	end
end

local ERROR_HANDLER = ResolveErrorHandler()

local function SafeCall(callback, ...)
	local args = { ... }
	return xpcall(function()
		callback(unpack(args))
	end, ERROR_HANDLER)
end

local AsyncLoaderMixin = {}

function AsyncLoaderMixin:OnLoad()
	self.frame = self.frame or CreateFrame("Frame")
	self.channels = self.channels or {}
	self.eventChannels = self.eventChannels or {}
	self.totalPending = self.totalPending or 0
	self.pollElapsed = 0
	self.pollInterval = 0.20
	self.isPolling = false

	self.frame:SetScript("OnEvent", function(_, event, ...)
		self:OnEvent(event, ...)
	end)
end

function AsyncLoaderMixin:RegisterChannel(name, config)
	if type(name) ~= "string" or type(config) ~= "table" then
		error("Usage: AsyncLoader:RegisterChannel(name, config)", 2)
	end

	if type(config.isReady) ~= "function" then
		error("AsyncLoader channel requires config.isReady(key)", 2)
	end

	local channel = self.channels[name]
	if not channel then
		channel = {
			name = name,
			pending = {},
			pendingCount = 0,
		}
		self.channels[name] = channel
	end

	channel.isReady = config.isReady
	channel.kick = config.kick or function() end
	channel.normalizeKey = config.normalizeKey
	channel.eventFilter = config.eventFilter
	channel.timeout = config.timeout or 12.0
	channel.requeryInterval = config.requeryInterval or 1.0
	channel.events = config.events or {}
	channel.onExpire = config.onExpire

	for i = 1, #channel.events do
		local eventName = channel.events[i]
		local listeners = self.eventChannels[eventName]
		if not listeners then
			listeners = {}
			self.eventChannels[eventName] = listeners
			self.frame:RegisterEvent(eventName)
		end
		listeners[name] = true
	end

	return channel
end

function AsyncLoaderMixin:GetChannel(name)
	return self.channels[name]
end

function AsyncLoaderMixin:EnablePolling()
	if self.isPolling then
		return
	end

	self.isPolling = true
	self.pollElapsed = 0

	Aegis:Debug("AsyncLoader polling enabled");

	self.frame:SetScript("OnUpdate", function(_, elapsed)
		self:OnUpdate(elapsed)
	end)
end

function AsyncLoaderMixin:DisablePolling()
	if not self.isPolling then
		return
	end

	self.isPolling = false
	self.pollElapsed = 0

	Aegis:Debug("AsyncLoader polling disabled");

	self.frame:SetScript("OnUpdate", nil)
end

function AsyncLoaderMixin:NormalizeKey(channel, key)
	if channel.normalizeKey then
		key = channel.normalizeKey(key)
	end

	if key == nil then
		error("AsyncLoader received invalid key", 3)
	end

	return key
end

function AsyncLoaderMixin:GetOrCreateEntry(channel, key)
	local entry = channel.pending[key]
	if not entry then
		entry = {
			callbacks = {},
			startTime = GetTime(),
			lastQueryTime = 0,
		}
		channel.pending[key] = entry
		channel.pendingCount = channel.pendingCount + 1
		self.totalPending = self.totalPending + 1
		self:EnablePolling()
	end
	return entry
end

function AsyncLoaderMixin:ExpireEntry(channel, key)
	local entry = channel.pending[key]
	if not entry then
		return
	end

	if channel.onExpire then
		SafeCall(channel.onExpire, key)
	end

	channel.pending[key] = nil
	channel.pendingCount = channel.pendingCount - 1
	self.totalPending = self.totalPending - 1

	for i = 1, #entry.callbacks do
		entry.callbacks[i] = nil
	end

	if self.totalPending <= 0 then
		self.totalPending = 0
		self:DisablePolling()
	end
end

function AsyncLoaderMixin:FireCallbacks(channel, key)
	local entry = channel.pending[key]
	if not entry then
		return
	end

	local callbacks = entry.callbacks
	channel.pending[key] = nil
	channel.pendingCount = channel.pendingCount - 1
	self.totalPending = self.totalPending - 1

	for i = 1, #callbacks do
		local callback = callbacks[i]
		if callback ~= CANCELED_SENTINEL then
			SafeCall(callback)
		end
		callbacks[i] = nil
	end

	if self.totalPending <= 0 then
		self.totalPending = 0
		self:DisablePolling()
	end
end

function AsyncLoaderMixin:AddCallback(channelName, key, callback)
	if type(callback) ~= "function" then
		error("Usage: AsyncLoader:AddCallback(channelName, key, callback)", 2)
	end

	local channel = self.channels[channelName]
	if not channel then
		error("Unknown AsyncLoader channel: " .. tostring(channelName), 2)
	end

	key = self:NormalizeKey(channel, key)

	if channel.isReady(key) then
		SafeCall(callback)
		return
	end

	local entry = self:GetOrCreateEntry(channel, key)
	entry.callbacks[#entry.callbacks + 1] = callback

	if entry.lastQueryTime == 0 then
		channel.kick(key)
		entry.lastQueryTime = GetTime()
	end
end

function AsyncLoaderMixin:AddCancelableCallback(channelName, key, callback)
	if type(callback) ~= "function" then
		error("Usage: AsyncLoader:AddCancelableCallback(channelName, key, callback)", 2)
	end

	local channel = self.channels[channelName]
	if not channel then
		error("Unknown AsyncLoader channel: " .. tostring(channelName), 2)
	end

	key = self:NormalizeKey(channel, key)

	if channel.isReady(key) then
		SafeCall(callback)
		return function()
			return false
		end
	end

	local entry = self:GetOrCreateEntry(channel, key)
	local index = #entry.callbacks + 1
	entry.callbacks[index] = callback

	if entry.lastQueryTime == 0 then
		channel.kick(key)
		entry.lastQueryTime = GetTime()
	end

	return function()
		if entry.callbacks[index] and entry.callbacks[index] ~= CANCELED_SENTINEL then
			entry.callbacks[index] = CANCELED_SENTINEL
			return true
		end
		return false
	end
end

function AsyncLoaderMixin:ProcessChannel(channel, forceQuery)
	if channel.pendingCount == 0 then
		return
	end

	local now = GetTime()
	local ready = {}
	local expired = {}

	for key, entry in pairs(channel.pending) do
		local isReady = channel.isReady(key);
		if isReady then
			ready[#ready + 1] = key
		elseif (now - entry.startTime) >= channel.timeout then
			expired[#expired + 1] = key
		elseif forceQuery or (now - entry.lastQueryTime) >= channel.requeryInterval then
			channel.kick(key)
			entry.lastQueryTime = now
		end
	end

	for i = 1, #ready do
		self:FireCallbacks(channel, ready[i]);
	end

	for i = 1, #expired do
		self:ExpireEntry(channel, expired[i])
	end
end

function AsyncLoaderMixin:OnUpdate(elapsed)
	self.pollElapsed = self.pollElapsed + elapsed
	if self.pollElapsed < self.pollInterval then
		return
	end

	self.pollElapsed = 0

	for _, channel in pairs(self.channels) do
		if channel.pendingCount > 0 then
			self:ProcessChannel(channel, false)
		end
	end
end

function AsyncLoaderMixin:OnEvent(event, ...)
	local listeners = self.eventChannels[event]
	if not listeners or self.totalPending == 0 then
		return
	end

	for channelName in pairs(listeners) do
		local channel = self.channels[channelName]
		if channel and channel.pendingCount > 0 then
			if not channel.eventFilter or channel.eventFilter(event, ...) then
				self:ProcessChannel(channel, true)
			end
		end
	end
end

Aegis:RegisterService("AsyncLoader", VERSION, function(core, state, service)
	service = service or core:CreateFromMixins(AsyncLoaderMixin)
	service.frame = service.frame or state.frame
	service.channels = service.channels or state.channels
	service.eventChannels = service.eventChannels or state.eventChannels
	service.totalPending = service.totalPending or state.totalPending
	service.pollElapsed = service.pollElapsed or state.pollElapsed
	service.isPolling = service.isPolling or state.isPolling

	service:OnLoad()

	state.frame = service.frame
	state.channels = service.channels
	state.eventChannels = service.eventChannels
	state.totalPending = service.totalPending
	state.pollElapsed = service.pollElapsed
	state.isPolling = service.isPolling

	return service
end)