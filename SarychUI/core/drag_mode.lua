-- SarychUI Drag Mode Utility
-- Универсальная утилита для режима редактирования расположения фреймов
-- Предоставляет функциональность drag frame, сетку выравнивания и управление позицией

local DragMode = {}

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

-- Глобальная сетка для выравнивания (создается один раз)
local alignmentGrid = nil
-- Кэш текстур сетки для быстрого доступа (избегаем GetNumRegions/GetRegions)
local alignmentGridTextures = {}

-- Создание сетки выравнивания (создается один раз для всех фреймов)
local function CreateAlignmentGrid()
    if alignmentGrid then return alignmentGrid end
    
    local grid = CreateFrame('FRAME')
    alignmentGrid = grid
    grid:Hide()
    grid:SetAllPoints(UIParent)
    grid:SetFrameStrata("BACKGROUND")
    grid:SetFrameLevel(0)
    grid:SetToplevel(false)
    -- Отключаем интерактивность сетки - она только для визуального выравнивания
    grid:EnableMouse(false)
    
    local w, h = GetScreenWidth() * UIParent:GetEffectiveScale(), GetScreenHeight() * UIParent:GetEffectiveScale()
    local ratio = w / h
    local sqsize = w / 20
    local wline = floor(sqsize - (sqsize % 2))
    local hline = floor(sqsize / ratio - ((sqsize / ratio) % 2))
    
    -- Очищаем кэш текстур
    wipe(alignmentGridTextures)
    
    -- Вертикальные линии
    for i = 0, wline do
        local t = grid:CreateTexture(nil, 'BACKGROUND')
        if i == wline / 2 then
            t:SetTexture(1, 0, 0, 0.5)  -- Красная центральная линия
        else
            t:SetTexture(0, 0, 0, 0.5)  -- Черные линии
        end
        t:SetPoint('TOPLEFT', grid, 'TOPLEFT', i * w / wline - 1, 0)
        t:SetPoint('BOTTOMRIGHT', grid, 'BOTTOMLEFT', i * w / wline + 1, 0)
        -- Сохраняем текстуру в кэш для быстрого доступа
        alignmentGridTextures[#alignmentGridTextures + 1] = t
    end
    
    -- Горизонтальные линии
    for i = 0, hline do
        local t = grid:CreateTexture(nil, 'BACKGROUND')
        if i == hline / 2 then
            t:SetTexture(1, 0, 0, 0.5)  -- Красная центральная линия
        else
            t:SetTexture(0, 0, 0, 0.5)  -- Черные линии
        end
        t:SetPoint('TOPLEFT', grid, 'TOPLEFT', 0, -i * h / hline + 1)
        t:SetPoint('BOTTOMRIGHT', grid, 'TOPRIGHT', 0, -i * h / hline - 1)
        -- Сохраняем текстуру в кэш для быстрого доступа
        alignmentGridTextures[#alignmentGridTextures + 1] = t
    end
    
    return grid
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
    if not df or (settings and settings.overlayFrame) then
        return
    end
    local gscale = 1
    if GetCVar("useuiscale") == "1" then
        gscale = tonumber(GetCVar("uiscale")) or 1
    end
    df:SetWidth((settings.dragWidth or 280) * gscale)
    df:SetHeight((settings.dragHeight or 225) * gscale)
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
    local dragPoint = (settings and settings.dragPoint) or "CENTER"
    df:SetPoint(dragPoint, frame, dragPoint, (settings and settings.dragOffsetX) or 0, (settings and settings.dragOffsetY) or 2.5)
end

-- Создание drag frame для фрейма
local function CreateDragFrame(frameId, frame, settings)
    local data = registeredFrames[frameId]
    if not data or data.dragFrame then return end
    
    -- Инициализируем флаг для предотвращения перезаписи позиции после drag
    data.justDragged = false
    
    local parent = OverlayParentFrame(settings, frame)
    local dragframe = CreateFrame("FRAME", nil, parent)
    dragframe:SetBackdropColor(0.0, 0.5, 1.0)
    dragframe:SetBackdrop({ edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = false, tileSize = 0, edgeSize = 16, insets = { left = 0, right = 0, top = 0, bottom = 0 } })
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
    if parent then
        -- Solid-color SetTexture is drawn under minimap tiles; WHITE8X8 is not.
        dragframe.t:SetTexture("Interface\\Buttons\\WHITE8X8")
        dragframe.t:SetVertexColor(0.0, 1.0, 0.0, 0.45)
        dragframe.t:SetAlpha(0.45)
    else
        dragframe.t:SetTexture(0.0, 1.0, 0.0, 0.5)
        dragframe.t:SetAlpha(0.5)
    end
    
    dragframe.f = dragframe:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    dragframe.f:SetPoint('CENTER', 0, 0)
    dragframe.f:SetText(settings.dragText or "Frame")
    
    data.isMoving = false
    data.startSliderPosition = nil  -- Позиция из слайдеров при начале перетаскивания
    data.startFramePosition = nil   -- Реальная позиция фрейма при начале перетаскивания

    local function CancelPendingUpdates()
        if data._followUpdater then
            data._followUpdater:SetScript("OnUpdate", nil)
            data._followUpdater = nil
        end
        if data._settleUpdater then
            data._settleUpdater:SetScript("OnUpdate", nil)
            data._settleUpdater = nil
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
            
            -- Сохраняем РЕАЛЬНУЮ позицию фрейма в пространстве крепления (TOPRIGHT/CENTER/…).
            -- Нельзя брать raw GetPoint после StartMoving — WoW часто переякорит в BOTTOMLEFT.
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
            local updateDragFrame = CreateFrame("Frame")
            data._followUpdater = updateDragFrame
            updateDragFrame:SetScript("OnUpdate", function(self)
                if not data.isMoving then
                    self:SetScript("OnUpdate", nil)
                    if data._followUpdater == self then
                        data._followUpdater = nil
                    end
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
        local updateFrame = CreateFrame("Frame")
        data._settleUpdater = updateFrame
        local checkCount = 0
        updateFrame:SetScript("OnUpdate", function(self, elapsed)
            checkCount = checkCount + 1
            if checkCount >= 2 then -- Ждем 2 кадра чтобы позиция точно обновилась
                self:SetScript("OnUpdate", nil)
                if data._settleUpdater == self then
                    data._settleUpdater = nil
                end
                
                -- Крепление и экранная метрика — как у фреймов (CENTER): delta в
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
                        local newSliderX = floor((sliderX + (currentX - startX)) + 0.5)
                        local newSliderY = floor((sliderY + (currentY - startY)) + 0.5)
                        
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
        if data.defaultPosition then
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
            frame:SetClampedToScreen(true)
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
        
        if data.dragFrame and not settings.overlayFrame then
            data.dragFrame:SetScale(scale)
        end
    end
    
    SizeDragOverlay(data)
    
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
            -- Показываем текстуру и устанавливаем alpha
            if data.dragFrame.t then
                data.dragFrame.t:Show()
                data.dragFrame.t:SetAlpha(settings.overlayFrame and 0.45 or 0.5)
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
    if show then
        -- При показе создаем сетку, если еще не создана
        if not alignmentGrid then
            CreateAlignmentGrid()
        end
        
        alignmentGrid:Show()
        -- Показываем все текстуры сетки из кэша и восстанавливаем alpha
        for i = 1, #alignmentGridTextures do
            local texture = alignmentGridTextures[i]
            if texture then
                texture:Show()
                texture:SetAlpha(0.5)
            end
        end
    else
        -- При скрытии не создаем сетку, если она еще не создана (оптимизация для загрузки)
        if alignmentGrid then
            alignmentGrid:Hide()
            -- Скрываем все текстуры сетки из кэша
            for i = 1, #alignmentGridTextures do
                local texture = alignmentGridTextures[i]
                if texture then
                    texture:Hide()
                    texture:SetAlpha(0)
                end
            end
        end
    end
end

-- Получить состояние сетки
function DragMode:IsGridVisible()
    return alignmentGrid and alignmentGrid:IsVisible() or false
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
        data.dragFrame:SetScale(scale)
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

-- Экспортируем утилиту в глобальное пространство
SarychUI.DragMode = DragMode

