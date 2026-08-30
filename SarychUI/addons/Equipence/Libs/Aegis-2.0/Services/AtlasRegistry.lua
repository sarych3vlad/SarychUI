--[[
    Aegis Framework
    Copyright (c) 2026 s0high. All rights reserved.

    Restricted proprietary library. See LICENSE for terms.
]]

local Aegis = LibStub("Aegis-2.0");

local pairs = pairs
local type = type
local strbyte = string.byte

local VERSION = 3

local AtlasRegistryMixin = {}

function AtlasRegistryMixin:OnLoad()
	self.roots = self.roots or {}
	self.definitions = self.definitions or {}
	self.overrides = self.overrides or {}
	self.cache = self.cache or {}
	self.overrideCache = self.overrideCache or {}
end

function AtlasRegistryMixin:BuildAddonPrefix(addonName)
	local rootFolder = self.roots[addonName] or "Resources"
	return "Interface\\AddOns\\" .. addonName .. "\\" .. rootFolder .. "\\"
end

function AtlasRegistryMixin:InvalidateAtlasCache(atlasName)
	self.cache[atlasName] = nil
	self.overrideCache[atlasName] = nil
end

function AtlasRegistryMixin:InvalidateAtlasCacheByAddon(addonName)
	for atlasName, definition in pairs(self.definitions) do
		if definition.addon == addonName then
			self.cache[atlasName] = nil
		end
	end

	for atlasName, definition in pairs(self.overrides) do
		if definition.addon == addonName then
			self.overrideCache[atlasName] = nil
		end
	end
end

function AtlasRegistryMixin:RegisterAddonRoot(addonName, rootFolder)
	if type(addonName) ~= "string" then
		error("Usage: AtlasRegistry:RegisterAddonRoot(addonName, rootFolder)", 2)
	end
	if type(rootFolder) ~= "string" then
		error("Usage: AtlasRegistry:RegisterAddonRoot(addonName, rootFolder)", 2)
	end

	self.roots[addonName] = rootFolder
	self:InvalidateAtlasCacheByAddon(addonName)
end

function AtlasRegistryMixin:NormalizeAtlasDefinition(name, info, defaultAddon)
	if type(info) ~= "table" then
		error("Atlas definition must be a table", 3)
	end

	local atlas

	if info.width then
		atlas = {
			width = info.width,
			height = info.height,
			leftTexCoord = info.leftTexCoord,
			rightTexCoord = info.rightTexCoord,
			topTexCoord = info.topTexCoord,
			bottomTexCoord = info.bottomTexCoord,
			tilesHorizontally = info.tilesHorizontally or false,
			tilesVertically = info.tilesVertically or false,
			folder = info.folder,
			file = info.file,
			addon = info.addon or defaultAddon,
		}
	else
		local tilesHorizontally = info[7]
		local tilesVertically = info[8]

		if tilesHorizontally == nil and tilesVertically == nil then
			local firstByte = strbyte(name, 1)
			tilesHorizontally = (firstByte == 95) -- "_"
			tilesVertically = (firstByte == 33)   -- "!"
		end

		atlas = {
			width = info[1],
			height = info[2],
			leftTexCoord = info[3],
			rightTexCoord = info[4],
			topTexCoord = info[5],
			bottomTexCoord = info[6],
			tilesHorizontally = tilesHorizontally or false,
			tilesVertically = tilesVertically or false,
			folder = info[9],
			file = info[10],
			addon = info[11] or defaultAddon,
		}
	end

	if not atlas.folder or not atlas.file or not atlas.addon then
		error("Atlas definition must include folder, file, and addon", 3)
	end

	return atlas
end

function AtlasRegistryMixin:AreDefinitionsEqual(a, b)
	return a.width == b.width
		and a.height == b.height
		and a.leftTexCoord == b.leftTexCoord
		and a.rightTexCoord == b.rightTexCoord
		and a.topTexCoord == b.topTexCoord
		and a.bottomTexCoord == b.bottomTexCoord
		and a.tilesHorizontally == b.tilesHorizontally
		and a.tilesVertically == b.tilesVertically
		and a.folder == b.folder
		and a.file == b.file
		and a.addon == b.addon;
end

function AtlasRegistryMixin:RegisterAtlas(name, info, options, defaultAddon)
	if type(name) ~= "string" then
		error("Usage: AtlasRegistry:RegisterAtlas(name, info[, options])", 2)
	end

	if type(options) ~= "table" then
		options = options and { replaceExisting = true } or {}
	end

	local normalized = self:NormalizeAtlasDefinition(name, info, defaultAddon)
	local target = options.overrideNative and self.overrides or self.definitions
	local existing = target[name]

	if existing then
		if self:AreDefinitionsEqual(existing, normalized) then
			return true, false
		end

		if not options.replaceExisting then
			return false, "Atlas collision: " .. name
		end
	end

	target[name] = normalized
	self:InvalidateAtlasCache(name)
	return true, true
end

function AtlasRegistryMixin:RegisterAtlasTable(atlasTable, addonName, rootFolder, options)
	if type(atlasTable) ~= "table" then
		error("Usage: AtlasRegistry:RegisterAtlasTable(atlasTable, addonName[, rootFolder[, options]])", 2)
	end
	if type(addonName) ~= "string" then
		error("Usage: AtlasRegistry:RegisterAtlasTable(atlasTable, addonName[, rootFolder[, options]])", 2)
	end

	if rootFolder then
		self:RegisterAddonRoot(addonName, rootFolder)
	end

	for atlasName, info in pairs(atlasTable) do
		local ok, err = self:RegisterAtlas(atlasName, info, options, addonName)
		if not ok then
			return false, err
		end
	end

	return true
end

function AtlasRegistryMixin:BuildCachedAtlasInfo(definition)
	local prefix = self:BuildAddonPrefix(definition.addon)
	return {
		width = definition.width,
		height = definition.height,
		leftTexCoord = definition.leftTexCoord,
		rightTexCoord = definition.rightTexCoord,
		topTexCoord = definition.topTexCoord,
		bottomTexCoord = definition.bottomTexCoord,
		tilesHorizontally = definition.tilesHorizontally,
		tilesVertically = definition.tilesVertically,
		filename = prefix .. definition.folder .. "\\" .. definition.file,
	}
end

function AtlasRegistryMixin:GetOverrideAtlasInfo(name)
	local cached = self.overrideCache[name]
	if cached ~= nil then
		return cached or nil
	end

	local definition = self.overrides[name]
	if not definition then
		self.overrideCache[name] = false
		return nil
	end

	local atlasInfo = self:BuildCachedAtlasInfo(definition)
	self.overrideCache[name] = atlasInfo
	return atlasInfo
end

function AtlasRegistryMixin:GetCustomAtlasInfo(name)
	local cached = self.cache[name]
	if cached ~= nil then
		return cached or nil
	end

	local definition = self.definitions[name]
	if not definition then
		self.cache[name] = false
		return nil
	end

	local atlasInfo = self:BuildCachedAtlasInfo(definition)
	self.cache[name] = atlasInfo
	return atlasInfo
end

Aegis:RegisterService("AtlasRegistry", VERSION, function(core, _, service)
	service = service or core:CreateFromMixins(AtlasRegistryMixin)
	service:OnLoad()
	return service
end)