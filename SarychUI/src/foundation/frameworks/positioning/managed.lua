-- Adjust FrameXML's managed anchor without duplicating its layout algorithm.
SarychUI.ManagedPosition = {}
local Managed = SarychUI.ManagedPosition
local originals = setmetatable({}, { __mode = "k" })
local dependencies = {
    "bottomEither", "bottomLeft", "bottomRight", "justBottomRightAndShapeshift",
    "vehicleMenuBar", "pet", "reputation", "maxLevel", "tutorialAlert",
    "rightLeft", "rightRight",
}

function Managed:GetSettings(db, prefix)
    db = db or {}
    local offset = tonumber(db[prefix .. "OffsetY"]) or 0
    local enabled = db[prefix .. "PositionEnabled"]
    -- Profiles predating the enable switch retain their existing placement.
    if enabled == nil then
        enabled = offset ~= 0
        db[prefix .. "PositionEnabled"] = enabled
    end
    enabled = enabled == true or enabled == 1
    local ignore = db[prefix .. "IgnoreStandardOffset"]
    return enabled, enabled and offset or 0,
        enabled and offset ~= 0 and (ignore == true or ignore == 1)
end

function Managed:Apply(frameName, offsetY, ignoreStandard)
    local managed = UIPARENT_MANAGED_FRAME_POSITIONS and UIPARENT_MANAGED_FRAME_POSITIONS[frameName]
    if not managed then return false end
    local original = originals[managed]
    if not original then
        original = { yOffset = managed.yOffset }
        for _, key in ipairs(dependencies) do original[key] = managed[key] end
        originals[managed] = original
    end
    local y = offsetY ~= 0 and ((original.yOffset or 0) + offsetY) or original.yOffset
    local changed = managed.yOffset ~= y
    managed.yOffset = y
    for _, key in ipairs(dependencies) do
        local value = original[key]
        if ignoreStandard then value = nil end
        if managed[key] ~= value then changed = true end
        managed[key] = value
    end
    return changed
end
