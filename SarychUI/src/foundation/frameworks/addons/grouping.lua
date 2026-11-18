-- Shared addon catalog and identity for addon management, cooldowns and minimap buttons.
local Grouping = {}
SarychUI.AddonGrouping = Grouping

function Grouping.GetSortName(name)
    if not name then return "" end
    local partof = GetAddOnMetadata and (GetAddOnMetadata(name, "X-Part-Of")
        or GetAddOnMetadata(name, "X-Child-Of") or GetAddOnMetadata(name, "Globe-Main"))
    if partof and partof ~= "" and partof ~= name then return partof .. "_" .. name end
    name = name:gsub("^[+!_]", "")
    if name == "DBM-Core" then return "DBM" end
    if name:match("^DBM%-") then return name:gsub("DBM%-", "DBM_") end
    if name == "ShadowedUF_Options" then return "ShadowedUnitFrames_Options" end
    for _, family in ipairs({ "WeakAuras", "WCollections", "SarychUI" }) do
        if name:sub(1, #family) == family then
            local suffix = name:sub(#family + 1)
            if suffix ~= "" and suffix:sub(1, 1) ~= "_" then return family .. "_" .. suffix end
        end
    end
    return name
end

function Grouping.GetFamily(name)
    return Grouping.GetSortName(name):match("^[^_]+") or name
end

-- One installed-addon catalog for timer ownership and live minimap buttons.
-- Installation is fixed for the UI session; loading an addon later needs no rescan.
local installed, byFolder
function Grouping.GetInstalled()
    if installed then return installed end
    local list, folders = {}, {}
    if not GetNumAddOns or not GetAddOnInfo then return list end
    for i = 1, GetNumAddOns() do
        local name, title = GetAddOnInfo(i)
        if name and not name:match("^Blizzard_") then
            local entry = { name = name, title = title or name, family = Grouping.GetFamily(name) }
            list[#list + 1] = entry
            folders[name:lower()] = entry
        end
    end
    installed, byFolder = list, folders
    return list
end

function Grouping.FindByName(name)
    if type(name) ~= "string" then return end
    Grouping.GetInstalled()
    local lower, best, bestLength = name:lower(), nil, 0
    for prefix, entry in pairs(byFolder or {}) do
        local suffix = name:sub(#prefix + 1, #prefix + 1)
        if lower:sub(1, #prefix) == prefix and
            (suffix == "" or suffix:match("[%d_%-%s]") or suffix:match("%u")) then
            if #prefix > bestLength then best, bestLength = entry, #prefix end
        end
    end
    return best
end

function Grouping.FindInPath(path)
    if type(path) ~= "string" then return end
    Grouping.GetInstalled()
    for folder in path:gsub("\\", "/"):lower():gmatch("([^/]+)/") do
        if byFolder and byFolder[folder] then return byFolder[folder] end
    end
end
