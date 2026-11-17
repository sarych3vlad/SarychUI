local module = SarychUI:GetModule("frame")
local positions = SarychUI.RelativePosition

module.secondaryPositionFrames = {
    { id = "targetTargetFrame", frame = "TargetFrameToT", parent = "TargetFrame",
      title = "ui.unit_frames.target_target", dragFlag = "showTargetTargetDragFrame" },
    { id = "focusTargetFrame", frame = "FocusFrameToT", parent = "FocusFrame",
      title = "ui.unit_frames.focus_target", dragFlag = "showFocusTargetDragFrame" },
}

local function DB()
    return SarychUI:GetModuleProfile("frame")
end

local function NativeAnchor(def)
    -- TargetofTargetFrameTemplate and FocusFrame_SetSmallSize in FrameXML.
    local small = def.parent == "FocusFrame" and FocusFrame and FocusFrame.smallSize
    return { "BOTTOMRIGHT", _G[def.parent], "BOTTOMRIGHT", small and -13 or -35, small and -17 or -10 }
end

function module:ApplySecondaryFramePositions(reset)
    if InCombatLockdown() then
        self._pendingSecondaryPositions = true
        return
    end
    self._pendingSecondaryPositions = nil
    local db = DB()
    local enabled = not reset and self._secondaryPositionsActive and db.enabled and db.changePositions == 1
    for _, def in ipairs(self.secondaryPositionFrames) do
        positions:Apply(def.id, _G[def.frame], NativeAnchor(def),
            enabled and (db[def.id .. "X"] or 0) or 0,
            enabled and (db[def.id .. "Y"] or 0) or 0)
    end
end

function module:SetSecondaryFramePosition(frameId, x, y)
    for _, def in ipairs(self.secondaryPositionFrames) do
        if def.id == frameId then
            positions:Apply(def.id, _G[def.frame], NativeAnchor(def), x, y)
            return true
        end
    end
    return false
end

function module:RegisterSecondaryPositionFrames()
    self._secondaryPositionsActive = true
    for _, def in ipairs(self.secondaryPositionFrames) do
        local frame = _G[def.frame]
        if frame then
            positions:Register(def.id, frame, {
                title = def.title, moduleKey = "frame", getConfig = DB,
                xKey = def.id .. "X", yKey = def.id .. "Y",
                aKey = def.id .. "Point", rKey = def.id .. "RelativePoint",
                dragFlag = def.dragFlag, min = -2000, max = 2000,
                onApply = function() module:ApplySecondaryFramePositions() end,
            }, function() return NativeAnchor(def) end)
        end
    end
    if not self._secondaryPositionHooked then
        self._secondaryPositionHooked = true
        hooksecurefunc("FocusFrame_SetSmallSize", function()
            if module._secondaryPositionsActive and DB().enabled then module:ApplySecondaryFramePositions() end
        end)
    end
end

function module:ApplySecondaryPositionDragMode(disable)
    local db = DB()
    if disable then self._secondaryPositionsActive = false end
    if InCombatLockdown() then
        self._pendingSecondaryDrag = true
        return false
    end
    self._pendingSecondaryDrag = nil
    local enabled = not disable and self._secondaryPositionsActive and db.enabled and db.changePositions == 1
    local showGrid = false
    for _, def in ipairs(self.secondaryPositionFrames) do
        local show = enabled and (db[def.dragFlag] == 1 or db.showPositionDragFrame == 1)
        SarychUI.DragMode:EnableEditMode(def.id, enabled, show, show)
        showGrid = showGrid or show
    end
    self:ApplySecondaryFramePositions(disable)
    return showGrid
end
