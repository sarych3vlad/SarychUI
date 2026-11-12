-- SarychUI Maps: fog-of-war reveal.
--
-- Draws every sub-zone overlay for the current map, including tiles the player
-- has not discovered. Undiscovered tiles keep Mapster's grey tint. The overlay
-- geometry lives in data/overlays.lua; the render loop follows Leatrix Maps'
-- FogClear (itself adapted from Mapster), because GetNumMapOverlays must return
-- 0 while we paint or Blizzard would fight us for the same WorldMapOverlay frames.

local Maps = SarychUI.Maps
local fog = Maps:RegisterComponent("fog", {})

local strlen, strsub = string.len, string.sub
local strlower, strmatch, strfind = string.lower, string.match, string.find
local format = string.format
local mod, floor, ceil = math.fmod, math.floor, math.ceil
local tinsert = table.insert

local origGetNumMapOverlays
local origWorldMapFrame_Update
local hooksInstalled = false
local unexploredTextures = {}
local tintApplied = false

local geometry
local function overlayMap()
	if not geometry then
		geometry = Maps.OverlayGeometry or {}
		setmetatable(geometry, {
			__index = function(t, k)
				local v = {}
				rawset(t, k, v)
				return v
			end,
		})
	end
	return geometry
end

local FOG_STYLE = {
	standard = { 0.623, 0.623, 0.623 },
	leatrix = { 0.6, 0.6, 1 },
}

local function styleRGB(style)
	local c = FOG_STYLE[style] or FOG_STYLE.leatrix
	return c[1], c[2], c[3]
end

local function tintColor()
	local db = Maps:DB()
	if not db then
		return 0.6, 0.6, 1, 1
	end
	local r, g, b = styleRGB(db.fogStyle)
	return r, g, b, db.fogTintA or 1
end

local function revealOn()
	return Maps:IsActive() and Maps:Get("revealFog") ~= false
end

function fog:HasOverlayData()
	local mapFile = GetMapInfo and GetMapInfo()
	local data = mapFile and overlayMap()[mapFile]
	if data then
		for _ in pairs(data) do
			return true
		end
	end
	local count = origGetNumMapOverlays and origGetNumMapOverlays() or (GetNumMapOverlays and GetNumMapOverlays() or 0)
	return count > 0
end

function fog:ResetOverlayColors()
	for i = 1, NUM_WORLDMAP_OVERLAYS do
		local ov = _G["WorldMapOverlay" .. i]
		if ov then
			ov:SetVertexColor(1, 1, 1)
			ov:SetAlpha(1)
		end
	end
	wipe(unexploredTextures)
	tintApplied = false
end

local function getDiscoveredOverlays(pathPrefix)
	local discovered = {}
	if not origGetNumMapOverlays then
		return discovered
	end
	for i = 1, origGetNumMapOverlays() do
		local textureName, texWidth, texHeight, offsetX, offsetY = GetMapOverlayInfo(i)
		if textureName and textureName ~= "" and textureName ~= " " then
			local baseName = strmatch(textureName, "([^\\]+)$") or textureName
			local key = strlower(baseName)
			if not strfind(key, "pixelfix", 1, true) then
				discovered[key] = {
					width = texWidth,
					height = texHeight,
					offsetX = offsetX,
					offsetY = offsetY,
					path = strfind(textureName, "\\", 1, true) and textureName or (pathPrefix .. textureName),
				}
			end
		end
	end
	return discovered
end

local function updateOverlayTextures()
	if not WorldMapFrame or not WorldMapFrame:IsShown() then
		return
	end

	local mapFileName = GetMapInfo()
	if not mapFileName then
		return
	end

	wipe(unexploredTextures)

	local pathPrefix = "Interface\\WorldMap\\" .. mapFileName .. "\\"
	local discovered = getDiscoveredOverlays(pathPrefix)
	local data = overlayMap()[mapFileName]

	local renderList = {}
	local byGeometry = {}
	for texName, texID in pairs(data) do
		local key = strlower(texName)
		local entry = {
			path = pathPrefix .. texName,
			width = mod(texID, 2 ^ 10),
			height = mod(floor(texID / 2 ^ 10), 2 ^ 10),
			offsetX = mod(floor(texID / 2 ^ 20), 2 ^ 10),
			offsetY = floor(texID / 2 ^ 30),
			explored = discovered[key] and true or false,
		}
		tinsert(renderList, entry)
		byGeometry[entry.width .. ":" .. entry.height .. ":" .. entry.offsetX .. ":" .. entry.offsetY] = entry
		discovered[key] = nil
	end
	for _, info in pairs(discovered) do
		local match = byGeometry[info.width .. ":" .. info.height .. ":" .. info.offsetX .. ":" .. info.offsetY]
		if match then
			match.explored = true
		else
			tinsert(renderList, {
				path = info.path,
				width = info.width,
				height = info.height,
				offsetX = info.offsetX,
				offsetY = info.offsetY,
				explored = true,
			})
		end
	end

	if #renderList == 0 then
		for i = 1, NUM_WORLDMAP_OVERLAYS do
			local ov = _G["WorldMapOverlay" .. i]
			if ov then
				ov:Hide()
			end
		end
		wipe(unexploredTextures)
		tintApplied = false
		return
	end

	local tintR, tintG, tintB, tintA = tintColor()
	local textureCount = 0

	for i = 1, #renderList do
		local entry = renderList[i]
		local textureName = entry.path
		local textureWidth = entry.width
		local textureHeight = entry.height
		local offsetX = entry.offsetX
		local offsetY = entry.offsetY

		local numTexturesWide = ceil(textureWidth / 256)
		local numTexturesTall = ceil(textureHeight / 256)
		local neededTextures = textureCount + (numTexturesWide * numTexturesTall)

		if neededTextures > NUM_WORLDMAP_OVERLAYS then
			for j = NUM_WORLDMAP_OVERLAYS + 1, neededTextures do
				WorldMapDetailFrame:CreateTexture("WorldMapOverlay" .. j, "ARTWORK")
			end
			NUM_WORLDMAP_OVERLAYS = neededTextures
		end

		for j = 1, numTexturesTall do
			local tpH, tfH
			if j < numTexturesTall then
				tpH = 256
				tfH = 256
			else
				tpH = mod(textureHeight, 256)
				if tpH == 0 then tpH = 256 end
				tfH = 16
				while tfH < tpH do
					tfH = tfH * 2
				end
			end

			for k = 1, numTexturesWide do
				textureCount = textureCount + 1
				local texture = _G["WorldMapOverlay" .. textureCount]
				if texture then
					local tpW, tfW
					if k < numTexturesWide then
						tpW = 256
						tfW = 256
					else
						tpW = mod(textureWidth, 256)
						if tpW == 0 then tpW = 256 end
						tfW = 16
						while tfW < tpW do
							tfW = tfW * 2
						end
					end

					texture:SetWidth(tpW)
					texture:SetHeight(tpH)
					texture:SetTexCoord(0, tpW / tfW, 0, tpH / tfH)
					texture:ClearAllPoints()
					texture:SetPoint("TOPLEFT", WorldMapDetailFrame, "TOPLEFT",
						offsetX + (256 * (k - 1)),
						-(offsetY + (256 * (j - 1))))
					texture:SetTexture(format(textureName .. "%d", ((j - 1) * numTexturesWide) + k))
					if entry.explored then
						texture:SetVertexColor(1, 1, 1)
						texture:SetAlpha(1)
					else
						texture:SetVertexColor(tintR, tintG, tintB)
						texture:SetAlpha(tintA)
						tinsert(unexploredTextures, texture)
					end
					texture:SetDrawLayer("ARTWORK")
					texture:Show()
				end
			end
		end
	end

	for i = textureCount + 1, NUM_WORLDMAP_OVERLAYS do
		local ov = _G["WorldMapOverlay" .. i]
		if ov then
			ov:Hide()
		end
	end

	tintApplied = #unexploredTextures > 0
end

function fog:Enable()
	if hooksInstalled then
		return
	end
	hooksInstalled = true

	origGetNumMapOverlays = GetNumMapOverlays
	origWorldMapFrame_Update = WorldMapFrame_Update

	GetNumMapOverlays = function()
		if NUM_WORLDMAP_OVERLAYS == 0 then
			return origGetNumMapOverlays()
		end
		if revealOn() then
			return 0
		end
		return origGetNumMapOverlays()
	end

	WorldMapFrame_Update = function(...)
		origWorldMapFrame_Update(...)
		if revealOn() then
			updateOverlayTextures()
		elseif tintApplied then
			fog:ResetOverlayColors()
		end
	end
end

function fog:Disable()
	if origGetNumMapOverlays then
		GetNumMapOverlays = origGetNumMapOverlays
	end
	if origWorldMapFrame_Update then
		WorldMapFrame_Update = origWorldMapFrame_Update
	end
	self:ResetOverlayColors()
	hooksInstalled = false
end

function fog:Refresh()
	if WorldMapFrame and WorldMapFrame:IsShown() and WorldMapFrame_Update then
		WorldMapFrame_Update()
	end
end

return fog
