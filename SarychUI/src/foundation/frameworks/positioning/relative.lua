-- Relative movers share the normal DragMode/editor lifecycle. Saved X/Y are
-- deltas from a live native anchor, not absolute screen coordinates.
SarychUI.RelativePosition = {}
local RelativePosition = SarychUI.RelativePosition

function RelativePosition:Register(frameId, frame, editor, getAnchor)
    local drag = SarychUI.DragMode
    local function Resolve(x, y)
        local anchor = getAnchor()
        return anchor[4] + x, anchor[5] + y
    end
    local function FromPosition(x, y)
        local anchor = getAnchor()
        return x - anchor[4], y - anchor[5]
    end
    local function GetPoint()
        local db = editor.getConfig()
        local anchor = getAnchor()
        anchor[4], anchor[5] = Resolve(db[editor.xKey] or 0, db[editor.yKey] or 0)
        return anchor
    end
    local anchor = getAnchor()
    editor.defaultA, editor.defaultR = anchor[1], anchor[3]
    editor.resolveFramePosition = Resolve
    editor.fromFramePosition = FromPosition
    drag:RegisterPositionEditor(frameId, frame, editor, {
        interceptSetPoint = false,
        getPoint = GetPoint,
        relativeTo = function() return getAnchor()[2] end,
        onPositionChanged = function(_, _, x, y)
            if not drag:IsPositionEditorOpen(frameId) then
                local db = editor.getConfig()
                db[editor.xKey], db[editor.yKey] = FromPosition(x, y)
                if editor.onApply then editor.onApply() end
                if SarychUI.SyncOpenOptionsValues then SarychUI:SyncOpenOptionsValues() end
            end
        end,
    })
end

function RelativePosition:Apply(frameId, frame, anchor, x, y)
    if not frame then return end
    local drag = SarychUI.DragMode
    local data = drag and drag:GetFrameData(frameId)
    if data and (data.isMoving or data.justDragged) then return end
    local setPoint = (data and data.originalSetPoint) or frame.SetPoint
    frame:ClearAllPoints()
    setPoint(frame, anchor[1], anchor[2], anchor[3], anchor[4] + x, anchor[5] + y)
end
