-- SarychUI Drag Mode Utility
-- Универсальная утилита для режима редактирования расположения фреймов
-- Предоставляет функциональность drag frame, сетку выравнивания и управление позицией

local DragMode = {}
local floor = math.floor

-- Хранилище зарегистрированных фреймов
local registeredFrames = {} -- [frameId] = {frame, settings, callbacks, ...}

-- Screen-space offsets as if SetPoint(point, UIParent, point, x, y).
-- Used ONLY to measure drag delta (start vs end). After StartMoving WoW often
-- re-anchors to BOTTOMLEFT, so raw GetPoint must not be used for non-CENTER.
local function FramePointOffsets(frame, point)
	if not frame then
		return 0, 0
	end
	point = point or "CENTER"
	local left, right = frame:GetLeft(), frame:GetRight()
	local top, bottom = frame:GetTop(), frame:GetBottom()
	local pl, pr = UIParent:GetLeft(), UIParent:GetRight()
	local pt, pb = UIParent:GetTop(), UIParent:GetBottom()
	if left and right and top and bottom and pl and pr and pt and pb then
		-- GetLeft/Top use the region's scale; normalize to UIParent units.
		local parentScale = UIParent:GetEffectiveScale()
		local frameScale = frame:GetEffectiveScale()
		if parentScale and parentScale > 0 and frameScale then
			local ratio = frameScale / parentScale
			left, right, top, bottom = left * ratio, right * ratio, top * ratio, bottom * ratio
		end
		if point == "TOPRIGHT" then
			return right - pr, top - pt
		elseif point == "TOPLEFT" then
			return left - pl, top - pt
		elseif point == "BOTTOMRIGHT" then
			return right - pr, bottom - pb
		elseif point == "BOTTOMLEFT" then
			return left - pl, bottom - pb
		elseif point == "TOP" then
			return ((left + right) / 2) - ((pl + pr) / 2), top - pt
		elseif point == "BOTTOM" then
			return ((left + right) / 2) - ((pl + pr) / 2), bottom - pb
		elseif point == "LEFT" then
			return left - pl, ((top + bottom) / 2) - ((pt + pb) / 2)
		elseif point == "RIGHT" then
			return right - pr, ((top + bottom) / 2) - ((pt + pb) / 2)
		end
		-- CENTER (default)
		return ((left + right) / 2) - ((pl + pr) / 2), ((top + bottom) / 2) - ((pt + pb) / 2)
	end
	local _, _, _, xOfs, yOfs = frame:GetPoint(1)
	return xOfs or 0, yOfs or 0
end

-- Back-compat alias used by older call sites / comments.
local function FrameCenterOffsets(frame)
	return FramePointOffsets(frame, "CENTER")
end

-- Screen measurements above use UIParent units, while SetPoint offsets are
-- expressed in the moved frame's own effective scale.
local function ToFrameOffsets(frame, x, y)
    local parentScale = UIParent:GetEffectiveScale()
    local frameScale = frame and frame:GetEffectiveScale()
    if parentScale and frameScale and frameScale > 0 then
        local ratio = parentScale / frameScale
        return x * ratio, y * ratio
    end
    return x, y
end

--------------------------------------------------------------------
-- Сетка выравнивания (портирована из FrostAtomUI Core/Movers.lua):
-- линии шагом gridSize от центра экрана, 1 физический пиксель толщиной,
-- центральные линии рисуются всегда, остальные - по настройке.
--------------------------------------------------------------------
local GRID_COLOR = { 1, 1, 1, 0.12 }
local GRID_CENTER_COLOR = { 1, 0.4, 0.4, 0.4 }
local DRAG_BORDER_COLOR = { 0.2, 1.0, 0.35, 0.95 }
local DRAG_LABEL_FONT = [[Interface\AddOns\SarychUI\media\fonts\Homespun.ttf]]
local GRID_SIZE_MIN, GRID_SIZE_MAX, GRID_SIZE_STEP, GRID_SIZE_DEFAULT = 8, 128, 4, 32

local alignmentGrid = nil
local gridVisible = false

local function GridDB()
    local p = SarychUI and SarychUI.db and SarychUI.db.profile
    return p and p.general
end

-- Толщина одного физического пикселя в координатах UIParent.
local function PixelSize()
    local _, physH = (GetCVar("gxResolution") or ""):match("^(%d+)x(%d+)")
    physH = tonumber(physH)
    local scale = UIParent:GetEffectiveScale()
    if not physH or physH <= 0 or not scale or scale <= 0 then
        return 1
    end
    return 768 / physH / scale
end

local function CreateAlignmentGrid()
    if alignmentGrid then return alignmentGrid end
    local grid = CreateFrame("Frame", nil, UIParent)
    alignmentGrid = grid
    grid:Hide()
    grid:SetAllPoints(UIParent)
    grid:SetFrameStrata("BACKGROUND")
    grid:SetFrameLevel(0)
    grid:SetToplevel(false)
    grid:EnableMouse(false)
    grid.lines = {}
    -- Перерисовать при смене масштаба / разрешения.
    grid:RegisterEvent("UI_SCALE_CHANGED")
    grid:RegisterEvent("DISPLAY_SIZE_CHANGED")
    grid:SetScript("OnEvent", function()
        if gridVisible then
            DragMode:UpdateGrid()
        end
    end)
    return grid
end

local function GridLine(index)
    local line = alignmentGrid.lines[index]
    if not line then
        line = alignmentGrid:CreateTexture(nil, "BACKGROUND")
        alignmentGrid.lines[index] = line
    end
    line:Show()
    return line
end

local function DrawGridLine(index, color, vertical, offset)
    local line = GridLine(index)
    line:SetTexture(unpack(color))
    line:ClearAllPoints()
    local px = PixelSize()
    if vertical then
        line:SetWidth(px)
        line:SetPoint("TOP", alignmentGrid, "TOP", offset, 0)
        line:SetPoint("BOTTOM", alignmentGrid, "BOTTOM", offset, 0)
    else
        line:SetHeight(px)
        line:SetPoint("LEFT", alignmentGrid, "LEFT", 0, offset)
        line:SetPoint("RIGHT", alignmentGrid, "RIGHT", 0, offset)
    end
end

-- Шаг сетки (общий для всех drag-режимов), хранится в profile.general.gridSize.
function DragMode:GetGridSize()
    local db = GridDB()
    local size = tonumber(db and db.gridSize) or GRID_SIZE_DEFAULT
    if size < GRID_SIZE_MIN then size = GRID_SIZE_MIN end
    if size > GRID_SIZE_MAX then size = GRID_SIZE_MAX end
    return size
end

function DragMode:GetGridSizeRange()
    return GRID_SIZE_MIN, GRID_SIZE_MAX, GRID_SIZE_STEP
end

function DragMode:SetGridSize(size)
    local previous = self:GetGridSize()
    size = tonumber(size) or GRID_SIZE_DEFAULT
    size = floor(size / GRID_SIZE_STEP + 0.5) * GRID_SIZE_STEP
    if size < GRID_SIZE_MIN then size = GRID_SIZE_MIN end
    if size > GRID_SIZE_MAX then size = GRID_SIZE_MAX end
    local db = GridDB()
    if db then
        db.gridSize = size
    end
    if gridVisible then
        self:UpdateGrid()
        if size ~= previous then self:SnapVisibleFramesToGrid() end
    end
    return size
end

-- Готовый Ace-контрол "Шаг сетки" для вкладок настроек, где есть переключатель сетки.
function DragMode:GridStepOption(order, hiddenFn)
    return {
        type = "range",
        name = "Шаг сетки",
        desc = "Расстояние между линиями сетки выравнивания (общее для всех режимов перемещения).",
        order = order or 99,
        width = "full",
        min = GRID_SIZE_MIN, max = GRID_SIZE_MAX, step = GRID_SIZE_STEP,
        hidden = hiddenFn,
        get = function() return DragMode:GetGridSize() end,
        set = function(_, v) DragMode:SetGridSize(v) end,
    }
end

-- Перерисовать линии под текущий шаг и размер экрана.
function DragMode:UpdateGrid()
    if not alignmentGrid then
        CreateAlignmentGrid()
    end
    local size = self:GetGridSize()
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    local centerX, centerY = width / 2, height / 2
    local index = 0

    for offset = -floor(centerX / size) * size, centerX, size do
        index = index + 1
        DrawGridLine(index, GRID_COLOR, true, offset)
    end
    for offset = -floor(centerY / size) * size, centerY, size do
        index = index + 1
        DrawGridLine(index, GRID_COLOR, false, offset)
    end

    DrawGridLine(index + 1, GRID_CENTER_COLOR, true, 0)
    DrawGridLine(index + 2, GRID_CENTER_COLOR, false, 0)
    index = index + 2

    for i = index + 1, #alignmentGrid.lines do
        alignmentGrid.lines[i]:Hide()
    end
end

-- Сохранение дефолтной позиции фрейма
local function SaveDefaultPosition(frameId, frame)
    local data = registeredFrames[frameId]
    if not data or data.defaultPosition then return end
    
    if frame then
        local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
        if point then
            data.defaultPosition = {
                point = point,
                relativeTo = relativeTo and relativeTo:GetName() or "UIParent",
                relativePoint = relativePoint,
                xOfs = xOfs,
                yOfs = yOfs
            }
        end
    end
end

-- Overlay can cover a different widget than the moved frame (minimap tiles
-- punch through UIParent overlays; the highlight must be a Minimap child).
local function OverlayCoverFrame(settings, frame)
    if settings and settings.overlayFrame then
        return settings.overlayFrame
    end
    return frame
end

local function OverlayParentFrame(settings, frame)
    if settings and settings.overlayParent then
        return settings.overlayParent
    end
    if settings and settings.overlayFrame then
        return settings.overlayFrame
    end
    return nil
end

local function SizeDragOverlay(data)
    local df = data and data.dragFrame
    local settings = data and data.settings
    if not df or not settings or settings.overlayFrame then return end
    -- Keep the measured group offset while StartMoving owns its anchor.
    if data.isMoving then return end
    if settings.getDragBounds and not data.isMoving then
        local left, bottom, right, top = settings.getDragBounds()
        local frame = data.frame
        local frameLeft, frameBottom = frame:GetLeft(), frame:GetBottom()
        local parentScale = UIParent:GetEffectiveScale()
        local frameScale = frame:GetEffectiveScale()
        if left and bottom and right and top and right > left and top > bottom
            and frameLeft and frameBottom and parentScale and parentScale > 0
            and frameScale and frameScale > 0 then
            local ratio = frameScale / parentScale
            data.dragBoundsOffsetX = left - frameLeft * ratio + (settings.dragOffsetX or 0)
            data.dragBoundsOffsetY = bottom - frameBottom * ratio + (settings.dragBoundsOffsetY or 0)
            df:SetScale(1)
            df:SetWidth(right - left)
            df:SetHeight(top - bottom)
            return
        end
    end
    data.dragBoundsOffsetX, data.dragBoundsOffsetY = nil, nil
    if not (settings.dragWidth or settings.dragHeight) then return end
    -- Explicit dimensions describe proxy groups (auras/arena/tracker) in UI
    -- units. UI scale is already applied by WoW; multiplying it here shrinks
    -- or enlarges the selection independently of the object.
    df:SetWidth(settings.dragWidth or data.frame:GetWidth())
    df:SetHeight(settings.dragHeight or data.frame:GetHeight())
end

local function AnchorDragOverlay(data)
    local df = data and data.dragFrame
    local settings = data and data.settings
    local frame = data and data.frame
    if not df or not frame then
        return
    end
    df:ClearAllPoints()
    local cover = OverlayCoverFrame(settings, frame)
    if settings and settings.overlayFrame and cover then
        df:SetAllPoints(cover)
        return
    end
    if data.dragBoundsOffsetX and data.dragBoundsOffsetY then
        df:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", data.dragBoundsOffsetX, data.dragBoundsOffsetY)
        return
    end
    if settings and (settings.dragInsetLeft or settings.dragInsetRight) then
        -- Insets describe the artwork in frame units, not overlay units.
        local ratio = frame:GetEffectiveScale() / df:GetEffectiveScale()
        df:SetPoint("TOPLEFT", frame, "TOPLEFT", (settings.dragInsetLeft or 0) * ratio, 0)
        df:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(settings.dragInsetRight or 0) * ratio, 0)
        return
    end
    if not (settings and (settings.dragWidth or settings.dragHeight or settings.dragOffsetX or settings.dragOffsetY)) then
        df:SetAllPoints(frame)
        return
    end
    local dragPoint = (settings and settings.dragPoint) or "CENTER"
    df:SetPoint(dragPoint, frame, dragPoint, (settings and settings.dragOffsetX) or 0, (settings and settings.dragOffsetY) or 0)
end

function DragMode:RefreshDragOverlay(frameId)
    local data = registeredFrames[frameId]
    if not data or not data.dragFrame or data.isMoving
        or (data._settleUpdater and data._settleUpdater:GetScript("OnUpdate")) then return end
    SizeDragOverlay(data)
    AnchorDragOverlay(data)
end

-- The one snap reference for every movable frame: the painted border's
-- OUTER BOTTOM-LEFT corner. It never depends on the frame's own anchor.
local function BorderCorner(data)
    local overlay = data and data.dragFrame
    if not overlay then return end
    local x, y = overlay:GetLeft(), overlay:GetBottom()
    local parentScale = UIParent:GetEffectiveScale()
    if not (x and y) then return end
    local ratio = parentScale and parentScale > 0
        and overlay:GetEffectiveScale() / parentScale or 1
    return x * ratio, y * ratio
end

-- Return a correction in UIParent units; convert it to the moved frame's
-- SetPoint units before applying it.
local function GridSnapOffsets(data)
    if not gridVisible or not alignmentGrid or not alignmentGrid:IsShown() then return 0, 0 end
    local x, y = BorderCorner(data)
    if not (x and y) then return 0, 0 end
    -- UpdateGrid draws these very same intersections from UIParent's centre.
    -- Texture coordinates can lag behind SetPoint for a frame, so calculate
    -- the node from the shared origin and step instead of reading the lines.
    local size = DragMode:GetGridSize()
    local centerX, centerY = UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
    local maxX, maxY = floor(centerX / size), floor(centerY / size)
    local ix = floor((x - centerX) / size + 0.5)
    local iy = floor((y - centerY) / size + 0.5)
    ix = math.max(-maxX, math.min(maxX, ix))
    iy = math.max(-maxY, math.min(maxY, iy))
    return centerX + ix * size - x, centerY + iy * size - y
end

-- Keep currently selected frames on a grid node when its step changes.
function DragMode:SnapVisibleFramesToGrid()
    if not gridVisible or (InCombatLockdown and InCombatLockdown()) then return end
    for _, data in pairs(registeredFrames) do
        local overlay = data.dragFrame
        local frame = data.frame
        if data.showDragFrame and overlay and overlay:IsShown() and frame
            and not data.isMoving
            and not (data._settleUpdater and data._settleUpdater:GetScript("OnUpdate")) then
            local dx, dy = GridSnapOffsets(data)
            if math.abs(dx) > 0.0001 or math.abs(dy) > 0.0001 then
                local saved = data.settings.getPoint and data.settings.getPoint()
                local point, relativePoint, x, y
                if saved then
                    point, relativePoint, x, y = saved[1], saved[3], saved[4], saved[5]
                else
                    local relativeTo
                    point, relativeTo, relativePoint, x, y = frame:GetPoint()
                end
                if point and x and y then
                    relativePoint = relativePoint or point
                    local offsetX, offsetY = ToFrameOffsets(frame, dx, dy)
                    x, y = x + offsetX, y + offsetY
                    data.justDragged = true
                    frame:ClearAllPoints()
                    local setPoint = data.originalSetPoint or frame.SetPoint
                    setPoint(frame, point, UIParent, relativePoint, x, y)
                    if data.onPositionChanged then
                        data.onPositionChanged(point, relativePoint, x, y)
                    end
                    data.justDragged = false
                    SizeDragOverlay(data)
                    AnchorDragOverlay(data)
                end
            end
        end
    end
end

-- Создание drag frame для фрейма
local function CreateDragFrame(frameId, frame, settings)
    local data = registeredFrames[frameId]
    if not data or data.dragFrame then return end
    
    -- Инициализируем флаг для предотвращения перезаписи позиции после drag
    data.justDragged = false
    
    local parent = OverlayParentFrame(settings, frame)
    local dragframe = CreateFrame("FRAME", nil, parent)
    local cover = OverlayCoverFrame(settings, frame)
    -- Keep Minimap children on the map's draw pass: do not raise strata/toplevel.
    if parent then
        local coverLevel = (cover and cover.GetFrameLevel and cover:GetFrameLevel()) or 0
        dragframe:SetFrameLevel(coverLevel + 50)
    else
        dragframe:SetFrameStrata("TOOLTIP")
        dragframe:SetFrameLevel(150)
        dragframe:SetToplevel(true)
    end
    dragframe:Hide()
    dragframe:EnableMouse(true)
    data.dragFrame = dragframe
    SizeDragOverlay(data)
    AnchorDragOverlay(data)
    
    local texLayer = parent and "OVERLAY" or "ARTWORK"
    dragframe.t = dragframe:CreateTexture(nil, texLayer)
    dragframe.t:SetAllPoints()
    dragframe.t:SetTexture("Interface\\Buttons\\WHITE8X8")
    dragframe.t:SetVertexColor(0.0, 1.0, 0.0, 1)
	data.fillAlpha = 0.16
	dragframe.t:SetAlpha(data.fillAlpha)

    -- Border textures stay inside the measured selection edges.
    local function BorderLine()
        local line = dragframe:CreateTexture(nil, "OVERLAY")
        line:SetDrawLayer("OVERLAY", 4)
        line:SetTexture("Interface\\Buttons\\WHITE8X8")
        line:SetVertexColor(unpack(DRAG_BORDER_COLOR))
        return line
    end
    data.borderLines = {
        BorderLine(), BorderLine(), BorderLine(), BorderLine(),
    }
    
    dragframe.f = dragframe:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    dragframe.f:SetFont(DRAG_LABEL_FONT, 12, "")
    dragframe.f:SetTextColor(unpack(DRAG_BORDER_COLOR))
    dragframe.f:SetJustifyH("LEFT")
    dragframe.f:SetPoint("BOTTOMLEFT", dragframe, "TOPLEFT", 0, 5)
    local label = settings.dragText or "Frame"
    dragframe.f:SetText(SarychUI.T and SarychUI:T(label) or label)

    -- Mark the exact corner used by GridSnapOffsets inside the selection.
    dragframe.cornerLabel = dragframe:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dragframe.cornerLabel:SetDrawLayer("OVERLAY", 3)
    dragframe.cornerLabel:SetFont(DRAG_LABEL_FONT, 7, "")
    dragframe.cornerLabel:SetTextColor(1, 1, 1, 1)
    dragframe.cornerLabel:SetJustifyH("LEFT")
    dragframe.cornerLabel:SetPoint("BOTTOMLEFT", dragframe, "BOTTOMLEFT", 3, 3)
    dragframe.cornerLabel:SetText("Угол крепления")

    dragframe.cornerLabelBackground = dragframe:CreateTexture(nil, "OVERLAY")
    dragframe.cornerLabelBackground:SetDrawLayer("OVERLAY", 2)
    dragframe.cornerLabelBackground:SetTexture("Interface\\Buttons\\WHITE8X8")
    dragframe.cornerLabelBackground:SetVertexColor(0, 0, 0, 0.78)
    dragframe.cornerLabelBackground:SetPoint("BOTTOMLEFT", dragframe.cornerLabel, "BOTTOMLEFT", -3, -2)
    dragframe.cornerLabelBackground:SetPoint("TOPRIGHT", dragframe.cornerLabel, "TOPRIGHT", 2, 1)
    
    data.isMoving = false
    data.startSliderPosition = nil  -- Позиция из слайдеров при начале перетаскивания
    data.startFramePosition = nil   -- Реальная позиция фрейма при начале перетаскивания

    local function CancelPendingUpdates()
        if data._followUpdater then
            data._followUpdater:SetScript("OnUpdate", nil)
        end
        if data._settleUpdater then
            data._settleUpdater:SetScript("OnUpdate", nil)
        end
    end
    data.CancelPendingUpdates = CancelPendingUpdates

    local function ForceStopMoving()
        CancelPendingUpdates()
        if data.isMoving or (frame.IsMoving and frame:IsMoving()) then
            pcall(function() frame:StopMovingOrSizing() end)
        end
        data.isMoving = false
        data.startFramePosition = nil
        data.startSliderPosition = nil
    end
    data.ForceStopMoving = ForceStopMoving
    
    dragframe:SetScript("OnMouseDown", function(self, btn)
        if btn == "LeftButton" then
            CancelPendingUpdates()
            data.isMoving = true
            
            -- Сохраняем текущее значение из БД (для вычисления нового значения слайдера)
            -- ЭТО БАЗОВЫЕ ЗНАЧЕНИЯ СЛАЙДЕРОВ - именно относительно них мы будем вычислять изменение
            local attachmentPoint = "CENTER"
            local attachmentRelativePoint = "CENTER"
            if settings.getPoint then
                local startPoint = settings.getPoint()
                attachmentPoint = startPoint[1]
                attachmentRelativePoint = startPoint[3]
                data.startSliderPosition = {
                    x = startPoint[4],
                    y = startPoint[5]
                }
            else
                -- Если getPoint недоступен, получаем текущую позицию фрейма
                local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
                attachmentPoint = point
                attachmentRelativePoint = relativePoint
                data.startSliderPosition = {
                    x = xOfs,
                    y = yOfs
                }
            end
            
            -- Сохраняем информацию о типе крепления
            data.attachmentPoint = attachmentPoint
            data.attachmentRelativePoint = attachmentRelativePoint
            
            -- Сохраняем РЕАЛЬНУЮ позицию фрейма в пространстве крепления (TOPRIGHT/CENTER/...).
            -- Нельзя брать raw GetPoint после StartMoving - WoW часто переякорит в BOTTOMLEFT.
            local startX, startY = FramePointOffsets(frame, attachmentPoint)
            
            -- ВАЖНО: Сохраняем позицию ПОСЛЕ всех вычислений
            -- Убеждаемся, что startX и startY не nil
            if startX and startY then
                data.startFramePosition = {
                    point = attachmentPoint,
                    relativePoint = attachmentRelativePoint,
                    x = startX,
                    y = startY
                }
            else
                -- Fallback: если не удалось вычислить, используем текущую позицию из GetPoint
                local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
                data.startFramePosition = {
                    point = point or attachmentPoint,
                    relativePoint = relativePoint or attachmentRelativePoint,
                    x = xOfs or 0,
                    y = yOfs or 0
                }
            end
            
            frame:StartMoving()
            
            -- Обновляем позицию drag frame во время перемещения
            -- Это гарантирует, что drag frame следует за фреймом
            local updateDragFrame = data._followUpdater or CreateFrame("Frame")
            data._followUpdater = updateDragFrame
            updateDragFrame:SetScript("OnUpdate", function(self)
                if not data.isMoving then
                    self:SetScript("OnUpdate", nil)
                    return
                end
                
                if data.dragFrame and frame then
                    AnchorDragOverlay(data)
                end
            end)
        end
    end)
    
    dragframe:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        data.isMoving = false
        CancelPendingUpdates()
        
        -- Сразу обновляем позицию drag frame после остановки перемещения
        -- Это предотвращает "залипание" drag frame на старом месте
        if data.dragFrame then
            AnchorDragOverlay(data)
            -- Скрываем drag frame, если он не должен быть видимым
            if not data.showDragFrame then
                data.dragFrame:Hide()
            end
        end
        
        -- Получаем новую реальную позицию фрейма сразу после StopMovingOrSizing
        -- Используем OnUpdate для получения актуальной позиции
        local updateFrame = data._settleUpdater or CreateFrame("Frame")
        data._settleUpdater = updateFrame
        local checkCount = 0
        updateFrame:SetScript("OnUpdate", function(self, elapsed)
            checkCount = checkCount + 1
            if checkCount >= 2 then -- Ждем 2 кадра чтобы позиция точно обновилась
                self:SetScript("OnUpdate", nil)
                
                -- Крепление и экранная метрика - как у фреймов (CENTER): delta в
                -- пространстве якоря, без raw GetPoint после StartMoving.
                local attachmentPoint = data.attachmentPoint or "CENTER"
                local attachmentRelativePoint = data.attachmentRelativePoint or attachmentPoint
                local currentX, currentY = FramePointOffsets(frame, attachmentPoint)
                
                -- newSlider = oldSlider + visual delta (keeps drop position, no jump).
                if data.startFramePosition and data.startSliderPosition then
                    local startX = data.startFramePosition.x
                    local startY = data.startFramePosition.y
                    local sliderX = data.startSliderPosition.x
                    local sliderY = data.startSliderPosition.y
                    
                    if startX and startY and sliderX and sliderY and currentX and currentY then
                        local snapX, snapY = GridSnapOffsets(data)
                        local offsetX, offsetY = ToFrameOffsets(
                            frame, (currentX - startX) + snapX, (currentY - startY) + snapY)
                        local rawX = sliderX + offsetX
                        local rawY = sliderY + offsetY
						-- Even a zero snap delta may require a fractional saved offset.
						-- Rounding it would move an aligned corner off the grid line.
                        local newSliderX = gridVisible and rawX or floor(rawX + 0.5)
                        local newSliderY = gridVisible and rawY or floor(rawY + 0.5)
                        
                        data.justDragged = true
                        
                        if data.originalSetPoint then
                            frame:ClearAllPoints()
                            data.originalSetPoint(frame, attachmentPoint, UIParent, attachmentRelativePoint, newSliderX, newSliderY)
                        else
                            frame:ClearAllPoints()
                            frame:SetPoint(attachmentPoint, UIParent, attachmentRelativePoint, newSliderX, newSliderY)
                        end
                        
                        if data.onPositionChanged then
                            data.onPositionChanged(attachmentPoint, attachmentRelativePoint, newSliderX, newSliderY)
                        end
                        
                        data.justDragged = false
                        
                        if data.dragFrame then
                            SizeDragOverlay(data)
                            AnchorDragOverlay(data)
                            if not data.showDragFrame then
                                data.dragFrame:Hide()
                            end
                        end
                        
                        data.startFramePosition = nil
                        data.startSliderPosition = nil
                    else
                        frame:ClearAllPoints()
                        frame:SetPoint(attachmentPoint, UIParent, attachmentRelativePoint, currentX or 0, currentY or 0)
                        
                        if data.onPositionChanged then
                            data.onPositionChanged(attachmentPoint, attachmentRelativePoint, currentX or 0, currentY or 0)
                        end
                        
                        data.startFramePosition = nil
                        data.startSliderPosition = nil
                    end
                else
                    frame:ClearAllPoints()
                    frame:SetPoint(attachmentPoint, UIParent, attachmentRelativePoint, currentX or 0, currentY or 0)
                    
                    if data.onPositionChanged then
                        data.onPositionChanged(attachmentPoint, attachmentRelativePoint, currentX or 0, currentY or 0)
                    end
                end
            end
        end)
    end)
    
    -- If mouse leaves while button is held / frame is hidden mid-drag, still stop move.
    dragframe:SetScript("OnHide", function()
        if data.isMoving then
            ForceStopMoving()
        end
    end)

    data.dragFrame = dragframe
end

-- API для других модулей

-- Регистрация фрейма для редактирования
-- frameId: уникальный идентификатор фрейма (string)
-- frame: фрейм для редактирования
-- settings: {dragPoint, dragOffsetX, dragOffsetY, dragWidth, dragHeight, dragText, overlayFrame, overlayParent, scaleFrame, onPositionChanged}
function DragMode:RegisterFrame(frameId, frame, settings)
    if not frameId or not frame then return end
    
    settings = settings or {}
    registeredFrames[frameId] = {
        frame = frame,
        settings = settings,
        onPositionChanged = settings.onPositionChanged,
        scaleFrame = settings.scaleFrame,
        defaultPosition = nil,
        originalSetPoint = nil,
        dragFrame = nil,
        isMoving = false,
        showDragFrame = false  -- Флаг видимости drag frame
    }
    
    -- Сохраняем дефолтную позицию
    SaveDefaultPosition(frameId, frame)
end

-- Отмена регистрации фрейма
function DragMode:UnregisterFrame(frameId)
    local data = registeredFrames[frameId]
    if not data then return end

    if data.ForceStopMoving then
        data.ForceStopMoving()
    elseif data.frame then
        pcall(function() data.frame:StopMovingOrSizing() end)
        data.isMoving = false
    end
    
    -- Удаляем drag frame
    if data.dragFrame then
        data.dragFrame:Hide()
        data.dragFrame = nil
    end
    
    -- Восстанавливаем оригинальную функцию SetPoint
    if data.frame and data.originalSetPoint then
        data.frame.SetPoint = data.originalSetPoint
        data.originalSetPoint = nil
    end
    
    registeredFrames[frameId] = nil
end

-- Включение режима редактирования для фрейма
function DragMode:EnableEditMode(frameId, enabled, showDragFrame, showGrid)
    local data = registeredFrames[frameId]
    if not data or not data.frame then return end
    if enabled and data.isMoving then return end
    
    local frame = data.frame
    local settings = data.settings
    
    if not enabled then
        -- CRITICAL: always end an in-progress StartMoving before disabling.
        -- Leaving a frame in "moving" state breaks mouse drag for other frames
        -- (including /sui) until reload.
        if data.ForceStopMoving then
            data.ForceStopMoving()
        else
            pcall(function() frame:StopMovingOrSizing() end)
            data.isMoving = false
            if data.CancelPendingUpdates then data.CancelPendingUpdates() end
        end

        -- Отключаем режим редактирования
        if frame:IsMovable() then
            frame:SetMovable(false)
        end
        pcall(function()
            if frame:IsUserPlaced() then
                frame:SetUserPlaced(false)
            end
        end)
        pcall(function()
            frame:SetDontSavePosition(false)
        end)
        
        -- Восстанавливаем оригинальную функцию SetPoint
        if data.originalSetPoint then
            frame.SetPoint = data.originalSetPoint
            data.originalSetPoint = nil
        end
        
        -- Восстанавливаем дефолтную позицию
        if data.defaultPosition and not settings.preservePositionOnDisable then
            frame:ClearAllPoints()
            local relativeTo = _G[data.defaultPosition.relativeTo] or UIParent
            pcall(function()
                frame:SetPoint(
                    data.defaultPosition.point,
                    relativeTo,
                    data.defaultPosition.relativePoint,
                    data.defaultPosition.xOfs,
                    data.defaultPosition.yOfs
                )
            end)
        end
        
        -- Сбрасываем масштаб только если drag mode сам управляет scale
        if settings.getScale then
            if settings.scaleFrame then
                settings.scaleFrame:SetScale(1.0)
            end
            frame:SetScale(1.0)
        end
        
        -- Скрываем drag frame и его текстуру
        if data.dragFrame then
            data.dragFrame:Hide()
            if data.dragFrame.t then
                data.dragFrame.t:Hide()
                data.dragFrame.t:SetAlpha(0)
            end
        end
        
        return
    end
    
    -- Включаем режим редактирования
    -- Сохраняем дефолтную позицию если еще не сохранена
    SaveDefaultPosition(frameId, frame)
    
    -- Сохраняем оригинальную функцию SetPoint
    if not data.originalSetPoint then
        data.originalSetPoint = frame.SetPoint
    end
    
    -- Настраиваем фрейм для перемещения
    if frame.SetMovable then
        frame:SetMovable(true)
        pcall(function()
            frame:SetUserPlaced(true)
        end)
        pcall(function()
            frame:SetDontSavePosition(true)
        end)
        pcall(function()
            -- Animated bar buttons must be allowed to follow their parent offscreen.
            frame:SetClampedToScreen(settings.clampToScreen ~= false)
        end)
    end
    
    -- НЕ применяем позицию автоматически при включении режима
    -- Фрейм уже может быть в правильной позиции после drag или слайдеров
    -- Позиция будет применена только при явном изменении слайдеров через ApplyFramePositions
    
    -- Перехватываем SetPoint если нужно (как в Leatrix_Plus)
    data.isMoving = false
    if settings.interceptSetPoint then
        -- Перехватываем SetPoint чтобы предотвратить автоматическое перемещение Blizzard
        frame.SetPoint = function(self, ...)
            -- StartMoving() continuously SetPoint's the frame. Blocking that
            -- freezes the minimap in place (the old "offset does nothing" bug).
            if data.isMoving then
                return data.originalSetPoint(self, ...)
            end
            
            -- Если не в процессе drag - применяем перехват
            -- Это предотвращает автоматическое перемещение от Blizzard, но разрешает обновления аур
            if not InCombatLockdown() and not data.justDragged then
                -- Получаем текущую позицию из настроек
                if settings.getPoint then
                    local currentPoint = settings.getPoint()
                    data.originalSetPoint(self, unpack(currentPoint))
                else
                    -- Если getPoint недоступен, просто игнорируем SetPoint
                    -- Это предотвращает автоматическое перемещение от Blizzard
                    return
                end
            elseif data.justDragged then
                -- Сразу после drag - разрешаем SetPoint для обновления аур
                -- Но применяем нашу позицию, чтобы предотвратить сброс позиции фрейма
                if settings.getPoint then
                    local currentPoint = settings.getPoint()
                    data.originalSetPoint(self, unpack(currentPoint))
                end
            end
        end
    end
    
    -- Создаем drag frame если нужно
    CreateDragFrame(frameId, frame, settings)
    
    -- Применяем масштаб только если drag mode сам управляет scale (getScale задан)
    if settings.getScale then
        local scale = settings.getScale() or 1.0
        if settings.scaleFrame then
            settings.scaleFrame:SetScale(scale)
        end
        frame:SetScale(scale)
        
        if data.dragFrame and (settings.dragWidth or settings.dragHeight) and not settings.overlayFrame then
            data.dragFrame:SetScale(scale)
        end
    end
    
    SizeDragOverlay(data)
    if data.dragFrame and data.dragFrame.f then
        local label = settings.dragText or "Frame"
        data.dragFrame.f:SetText(SarychUI.T and SarychUI:T(label) or label)
    end
    if data.borderLines then
        local effective = data.dragFrame:GetEffectiveScale()
        local parentScale = UIParent:GetEffectiveScale()
        local width = PixelSize()
        if effective and effective > 0 and parentScale then
            width = width * parentScale / effective
        end
        local top, bottom, left, right = unpack(data.borderLines)
        top:ClearAllPoints()
        top:SetPoint("TOPLEFT", data.dragFrame, "TOPLEFT", 0, 0)
        top:SetPoint("TOPRIGHT", data.dragFrame, "TOPRIGHT", 0, 0)
        top:SetHeight(width)
        bottom:ClearAllPoints()
        bottom:SetPoint("BOTTOMLEFT", data.dragFrame, "BOTTOMLEFT", 0, 0)
        bottom:SetPoint("BOTTOMRIGHT", data.dragFrame, "BOTTOMRIGHT", 0, 0)
        bottom:SetHeight(width)
        left:ClearAllPoints()
        left:SetPoint("TOPLEFT", data.dragFrame, "TOPLEFT", 0, 0)
        left:SetPoint("BOTTOMLEFT", data.dragFrame, "BOTTOMLEFT", 0, 0)
        left:SetWidth(width)
        right:ClearAllPoints()
        right:SetPoint("TOPRIGHT", data.dragFrame, "TOPRIGHT", 0, 0)
        right:SetPoint("BOTTOMRIGHT", data.dragFrame, "BOTTOMRIGHT", 0, 0)
        right:SetWidth(width)
    end
    
    -- Сохраняем флаг видимости drag frame
    data.showDragFrame = showDragFrame
    
    -- Показываем или скрываем drag frame
    if data.dragFrame then
        AnchorDragOverlay(data)
        
        if showDragFrame then
            if settings.overlayFrame then
                local cover = settings.overlayFrame
                data.dragFrame:SetParent(settings.overlayParent or cover)
                local coverLevel = (cover.GetFrameLevel and cover:GetFrameLevel()) or 0
                data.dragFrame:SetFrameLevel(coverLevel + 50)
            end
            data.dragFrame:Show()
            -- Показываем зелёную заливку и тонкую рамку
            if data.dragFrame.t then
                data.dragFrame.t:Show()
                data.dragFrame.t:SetAlpha(data.fillAlpha or 0.16)
            end
        else
            -- Скрываем drag frame и его текстуру
            data.dragFrame:Hide()
            if data.dragFrame.t then
                data.dragFrame.t:Hide()
                data.dragFrame.t:SetAlpha(0)
            end
        end
    end
end

-- Показать/скрыть сетку выравнивания
function DragMode:ShowGrid(show)
    -- A live position editor owns the grid. Unrelated module refreshes must
    -- not hide it (or re-enable it after the user turns it off in the editor).
    local panel = SarychUI and SarychUI.PositionDragPanel
    local preference = panel and panel.GetGridPreference and panel:GetGridPreference()
    if preference ~= nil then show = preference end
    if show then
        gridVisible = true
        self:UpdateGrid()
        alignmentGrid:Show()
    else
        gridVisible = false
        -- Не создаем сетку только ради скрытия.
        if alignmentGrid then
            alignmentGrid:Hide()
        end
    end
end

-- Получить состояние сетки
function DragMode:IsGridVisible()
    return gridVisible and alignmentGrid and alignmentGrid:IsShown() or false
end

-- Сброс позиции фрейма на дефолт
function DragMode:ResetFrameToDefault(frameId)
    local data = registeredFrames[frameId]
    if not data or not data.frame or not data.defaultPosition then return end
    
    local frame = data.frame
    frame:ClearAllPoints()
    local relativeTo = _G[data.defaultPosition.relativeTo] or UIParent
    frame:SetPoint(
        data.defaultPosition.point,
        relativeTo,
        data.defaultPosition.relativePoint,
        data.defaultPosition.xOfs,
        data.defaultPosition.yOfs
    )
end

-- Применить позицию к фрейму
function DragMode:SetFramePosition(frameId, point, relativePoint, xOfs, yOfs)
    local data = registeredFrames[frameId]
    if not data or not data.frame then return end
    
    local frame = data.frame
    frame:ClearAllPoints()
    -- Use the raw setter: the intercept wrapper ignores passed offsets and
    -- re-applies getPoint(), so sliders would appear to do nothing.
    local setPoint = data.originalSetPoint or frame.SetPoint
    setPoint(frame, point, UIParent, relativePoint, xOfs, yOfs)
end

-- Применить масштаб к фрейму
function DragMode:SetFrameScale(frameId, scale)
    local data = registeredFrames[frameId]
    if not data or not data.frame then return end
    
    local frame = data.frame
    local settings = data.settings
    
    if settings.scaleFrame then
        settings.scaleFrame:SetScale(scale)
    end
    frame:SetScale(scale)
    
    -- Обновляем масштаб drag frame
    if data.dragFrame then
        data.dragFrame:SetScale((settings.dragWidth or settings.dragHeight) and not settings.overlayFrame and scale or 1)
    end
end

-- Получить информацию о зарегистрированном фрейме
function DragMode:GetFrameData(frameId)
    return registeredFrames[frameId]
end

-- Получить все зарегистрированные фреймы
function DragMode:GetAllRegisteredFrames()
    return registeredFrames
end

-- Standard entry point for new integrations: mover + grid + position editor.
-- Register after the frame and its saved configuration are ready.
function DragMode:RegisterPositionEditor(frameId, frame, editor, settings)
    local panel = SarychUI.PositionDragPanel
    assert(panel and frame and editor and type(editor.getConfig)=="function",
        "RegisterPositionEditor requires a frame, getConfig and PositionDragPanel")
    local meta = {}
    for k,v in pairs(editor) do meta[k]=v end
    meta.xKey=meta.xKey or "x"; meta.yKey=meta.yKey or "y"
    meta.aKey=meta.aKey or "point"; meta.rKey=meta.rKey or "relativePoint"
    meta.dragFlag=meta.dragFlag or "moving"
    meta.defaultX=meta.defaultX or 0; meta.defaultY=meta.defaultY or 0
    meta.defaultA=meta.defaultA or "CENTER"; meta.defaultR=meta.defaultR or meta.defaultA
    local cfg=meta.getConfig()
    if cfg[meta.aKey]==nil then cfg[meta.aKey]=meta.defaultA end
    if cfg[meta.rKey]==nil then cfg[meta.rKey]=cfg[meta.aKey] end
    if cfg[meta.xKey]==nil then cfg[meta.xKey]=meta.defaultX end
    if cfg[meta.yKey]==nil then cfg[meta.yKey]=meta.defaultY end
    panel:RegisterFrame(frameId,meta)
    if not self:GetFrameData(frameId) then
        local opts={}
        for k,v in pairs(settings or {}) do opts[k]=v end
        opts.dragText=opts.dragText or meta.title or frameId
        opts.preservePositionOnDisable=true
        opts.getPoint=opts.getPoint or function()
            local db=meta.getConfig()
            return {db[meta.aKey],UIParent,db[meta.rKey],db[meta.xKey],db[meta.yKey]}
        end
        local callback=opts.onPositionChanged
        opts.onPositionChanged=function(point,relativePoint,x,y)
            panel:OnDragPosition(frameId,x,y,point,relativePoint)
            if meta.onApply then meta.onApply() end
            if callback then callback(point,relativePoint,x,y) end
        end
        self:RegisterFrame(frameId,frame,opts)
    end
    return frameId
end

function DragMode:IsPositionEditorOpen(frameId)
    local panel=SarychUI.PositionDragPanel
    return panel and panel:IsOpen() and panel:GetFrameId()==frameId or false
end

function DragMode:TogglePositionEditor(frameId, enabled)
    assert(self:GetFrameData(frameId), "RegisterPositionEditor must be called first")
    if enabled==nil then enabled=not self:IsPositionEditorOpen(frameId) end
    SarychUI.PositionDragPanel:Toggle(frameId,enabled)
end

-- Экспортируем утилиту в глобальное пространство
SarychUI.DragMode = DragMode

