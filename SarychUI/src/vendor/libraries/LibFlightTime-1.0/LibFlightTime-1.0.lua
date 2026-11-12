local lib = LibStub:NewLibrary("LibFlightTime-1.0", 4)
if not lib then return end

-- The DBC names are client-localized. If a server uses different taxi names,
-- the caller can still use its older route table as a fallback.
local dbc = SarychUIFlightTimeData
local nodes = dbc and dbc.nodes or {}
local edges = dbc and dbc.edges or {}
SarychUIFlightTimeData = nil
local DISPLAY_ADJUSTMENT = 1

local idsByName = {}
for id, entry in pairs(nodes) do
    local name = entry[1]
    local ids = idsByName[name]
    if not ids then
        ids = {}
        idsByName[name] = ids
    end
    ids[#ids + 1] = id
end

local function positionKey(x, y)
    if not x or not y then return nil end
    return string.format("%.2f:%.2f", x, y)
end

local function candidatesAt(indices, factionMask)
    local candidates = {}
    for _, index in ipairs(indices) do
        local name = TaxiNodeName(index)
        local ids = idsByName[name]
        if ids then
            for _, id in ipairs(ids) do
                local mask = nodes[id][2]
                if mask == 0 or bit.band(mask, factionMask) ~= 0 then
                    candidates[id] = true
                end
            end
        end
    end
    return candidates
end

local function learnedRoutes()
    if type(SarychUIFlightTimeDB) ~= "table" then SarychUIFlightTimeDB = {} end
    if type(SarychUIFlightTimeDB.routes) ~= "table" then SarychUIFlightTimeDB.routes = {} end
    return SarychUIFlightTimeDB.routes
end

-- A completed flight measures the server's actual route and speed. Use a
-- capped running mean so a single lag spike does not permanently skew it.
function lib:RecordDuration(routeKey, measured, estimate)
    if not routeKey or type(measured) ~= "number" or measured < 10 or measured > 3600 then return end
    if estimate and math.abs(measured - estimate) > math.max(20, estimate * 0.25) then return end
    local routes = learnedRoutes()
    local previous = routes[routeKey]
    if previous then
        local count = math.min(previous.count or 1, 7)
        previous.seconds = (previous.seconds * count + measured) / (count + 1)
        previous.count = count + 1
    else
        routes[routeKey] = { seconds = measured, count = 1 }
    end
end

function lib:GetDuration(destinationIndex)
    if not destinationIndex or not NumTaxiNodes then return nil end
    local faction = UnitFactionGroup("player")
    local factionMask = faction == "Alliance" and 1 or faction == "Horde" and 2 or 3
    local positions = {}
    local currentKey
    for index = 1, NumTaxiNodes() do
        local key = positionKey(TaxiNodePosition(index))
        if key then
            local indices = positions[key]
            if not indices then
                indices = {}
                positions[key] = indices
            end
            indices[#indices + 1] = index
            if TaxiNodeGetType(index) == "CURRENT" then currentKey = key end
        end
    end
    local endKey = positionKey(TaxiNodePosition(destinationIndex))
    if not currentKey or not endKey then return nil end

    local route = { currentKey }
    for hop = 1, GetNumRoutes(destinationIndex) do
        local key = positionKey(TaxiGetDestX(destinationIndex, hop), TaxiGetDestY(destinationIndex, hop))
        if key and key ~= route[#route] then route[#route + 1] = key end
    end
    if endKey ~= route[#route] then route[#route + 1] = endKey end
    if #route < 2 then return nil end
    local continent = GetCurrentMapContinent and GetCurrentMapContinent() or 0
    local routeKey = (faction or "?") .. ":" .. tostring(continent) .. ":" .. table.concat(route, "|")
    local learned = learnedRoutes()[routeKey]
    if learned and type(learned.seconds) == "number" then
        return math.floor(learned.seconds + DISPLAY_ADJUSTMENT + 0.5), routeKey
    end

    local firstIndices = positions[route[1]]
    if not firstIndices then return nil, routeKey end
    local totals = {}
    for id in pairs(candidatesAt(firstIndices, factionMask)) do totals[id] = 0 end
    for step = 2, #route do
        local indices = positions[route[step]]
        if not indices then return nil, routeKey end
        local nextTotals = {}
        for target in pairs(candidatesAt(indices, factionMask)) do
            for source, total in pairs(totals) do
                local seconds = edges[source] and edges[source][target]
                if seconds then
                    local candidate = total + seconds
                    if not nextTotals[target] or candidate < nextTotals[target] then
                        nextTotals[target] = candidate
                    end
                end
            end
        end
        if not next(nextTotals) then return nil, routeKey end
        totals = nextTotals
    end
    local best
    for _, seconds in pairs(totals) do
        if not best or seconds < best then best = seconds end
    end
    return best and math.floor(best + DISPLAY_ADJUSTMENT + 0.5) or nil, routeKey
end
