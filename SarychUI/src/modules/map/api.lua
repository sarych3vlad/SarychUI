local SuiTimer = select(2, ...).Compat.Timer
-- SarychUI Maps: map API abstraction.
--
-- Everything the map components need to know about areas, coordinates and
-- scheduling goes through here. Lookups use the 3.3.5a client API and our private timer service. This replaces the Astrolabe library the old WDM code linked
-- against: the only Astrolabe entry points anything in SarychUI used were
-- "where is the player" and "which area is this", both of which the client
-- answers directly once the area-ID lookup below exists.

local Maps = SarychUI.Maps
local Api = {}
Maps.Api = Api

local floor = math.floor

----------------------------------------------------------------------
-- Area identity
----------------------------------------------------------------------

-- GetCurrentMapAreaID is read-only, while C_Map.GetBestMapForUnit calls
-- SetMapZoom internally and would fight our own map state, so the native call
-- wins here.
function Api:GetCurrentAreaID()
	if not GetCurrentMapAreaID then return nil end
	local areaID = GetCurrentMapAreaID()
	if areaID and areaID > 0 then
		return areaID
	end
	return nil
end

-- areaID -> { continentIndex, zoneIndex } and continentIndex -> areaID.
-- Built with a single sweep while the map is closed; C_Map builds the same
-- mapping internally but never exposes the zone index we need for SetMapZoom.
local areaToZone, continentToArea, areaToName

local function buildAreaLookup()
	if areaToZone then return end
	if not (SetMapZoom and GetCurrentMapAreaID and GetMapContinents and GetMapZones) then
		areaToZone, continentToArea, areaToName = {}, {}, {}
		return
	end

	areaToZone, continentToArea, areaToName = {}, {}, {}

	local savedContinent = GetCurrentMapContinent and GetCurrentMapContinent() or 0
	local savedZone = GetCurrentMapZone and GetCurrentMapZone() or 0

	local continents = { GetMapContinents() }
	for continentIndex = 1, #continents do
		SetMapZoom(continentIndex, 0)
		local areaID = GetCurrentMapAreaID()
		if areaID and areaID > 0 then
			continentToArea[continentIndex] = areaID
			areaToName[areaID] = continents[continentIndex]
		end

		local zones = { GetMapZones(continentIndex) }
		for zoneIndex = 1, #zones do
			SetMapZoom(continentIndex, zoneIndex)
			areaID = GetCurrentMapAreaID()
			if areaID and areaID > 0 then
				areaToZone[areaID] = { continentIndex, zoneIndex }
				areaToName[areaID] = zones[zoneIndex]
			end
		end
	end

	if savedContinent and savedContinent > 0 then
		SetMapZoom(savedContinent, savedZone)
	elseif SetMapToCurrentZone then
		SetMapToCurrentZone()
	end
end

-- Called from module Enable, while the world map is still closed.
function Api:PrimeAreaLookup()
	buildAreaLookup()
end

function Api:GetAreaName(areaID)
	if not areaID then return nil end
	buildAreaLookup()
	return areaToName[areaID]
end

function Api:GetContinentAreaID(continentIndex)
	buildAreaLookup()
	return continentToArea[continentIndex]
end

-- Switches the world map to an area ID (used by the zone-crossing pins).
function Api:NavigateToAreaID(areaID)
	if not areaID or not SetMapZoom then return false end
	buildAreaLookup()

	local zone = areaToZone[areaID]
	if zone then
		SetMapZoom(zone[1], zone[2])
		return true
	end

	for continentIndex, continentAreaID in pairs(continentToArea) do
		if continentAreaID == areaID then
			SetMapZoom(continentIndex, 0)
			return true
		end
	end

	-- Instance and battleground maps are not in the continent/zone lists.
	if SetMapByID then
		SetMapByID(areaID)
		return true
	end
	return false
end

----------------------------------------------------------------------
-- Coordinates
----------------------------------------------------------------------

function Api:GetPlayerPosition()
	if not GetPlayerMapPosition then return nil, nil end
	local x, y = GetPlayerMapPosition("player")
	if not x or (x == 0 and y == 0) then
		return nil, nil
	end
	return x, y
end

-- Cursor position normalised over WorldMapDetailFrame (0-1, origin top-left).
-- Reading the frame's own geometry keeps this correct at any zoom or pan offset
-- because the detail frame is the thing being scaled and scrolled.
function Api:GetCursorPosition()
	if not WorldMapDetailFrame then return nil, nil end

	local scale = WorldMapDetailFrame:GetEffectiveScale()
	if not scale or scale == 0 then return nil, nil end

	local width, height = WorldMapDetailFrame:GetWidth(), WorldMapDetailFrame:GetHeight()
	if not width or width == 0 or not height or height == 0 then return nil, nil end

	local left, top = WorldMapDetailFrame:GetLeft(), WorldMapDetailFrame:GetTop()
	if not left or not top then return nil, nil end

	local cx, cy = GetCursorPosition()
	local x = (cx / scale - left) / width
	local y = (top - cy / scale) / height
	return x, y
end

function Api:Round(value, digits)
	local factor = 10 ^ (digits or 1)
	return floor(value * factor + 0.5) / factor
end

-- Stock 3.3.5 textures sometimes expose SetRotation (Blizzard vehicles use it);
-- Fall back to SetTexCoord when SetRotation is unavailable so the player arrow
-- and zone-crossing pins still face the right way.
function Api:SetTextureRotation(texture, radians)
	if not texture then
		return
	end
	radians = radians or 0
	if texture.SetRotation then
		texture:SetRotation(radians)
		return
	end
	local cos, sin = math.cos(radians), math.sin(radians)
	local function rot(x, y)
		x, y = x - 0.5, y - 0.5
		return 0.5 + x * cos - y * sin, 0.5 + x * sin + y * cos
	end
	local ulx, uly = rot(0, 0)
	local llx, lly = rot(0, 1)
	local urx, ury = rot(1, 0)
	local lrx, lry = rot(1, 1)
	texture:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
end

----------------------------------------------------------------------
-- Scheduling
----------------------------------------------------------------------

-- The private timer service supplies SuiTimer; the OnUpdate fallback keeps the
-- module working if it is ever unavailable.
function Api:After(delay, callback)
	SuiTimer.After(delay, callback)
end

return Api
