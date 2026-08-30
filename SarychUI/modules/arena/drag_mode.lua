-- Arena Module Drag Mode
-- Упрощенная система drag для arena фреймов с 1:1 движением без скакания

local ArenaDragMode = {}
local floor = math.floor

-- Хранилище данных для drag frame
local dragData = {
	dragFrame = nil,
	isMoving = false,
	justDragged = false,
	startPosition = nil,
	alignmentGrid = nil,
}

-- Создание drag frame
local function CreateDragFrame(frame, settings)
	-- Если drag frame уже создан, обновляем его позицию и возвращаем
	if dragData.dragFrame then
		dragData.dragFrame:ClearAllPoints()
		dragData.dragFrame:SetPoint(settings.dragPoint or "TOPRIGHT", frame, settings.dragPoint or "TOPRIGHT", settings.dragOffsetX or 0, settings.dragOffsetY or 2.5)
		return dragData.dragFrame
	end
	
	local dragframe = CreateFrame("FRAME", nil, nil)
	dragframe:SetPoint(settings.dragPoint or "TOPRIGHT", frame, settings.dragPoint or "TOPRIGHT", settings.dragOffsetX or 0, settings.dragOffsetY or 2.5)
	dragframe:SetBackdropColor(0.0, 0.5, 1.0)
	dragframe:SetBackdrop({ edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = false, tileSize = 0, edgeSize = 16, insets = { left = 0, right = 0, top = 0, bottom = 0 } })
	dragframe:SetFrameStrata("TOOLTIP")
	dragframe:SetFrameLevel(150)
	dragframe:SetToplevel(true)
	dragframe:Hide()
	dragframe:EnableMouse(true)
	
	-- Устанавливаем размер drag frame с учетом UI scale
	local gscale = 1
	if GetCVar("useuiscale") == "1" then
		gscale = tonumber(GetCVar("uiscale")) or 1
	end
	dragframe:SetWidth((settings.dragWidth or 280) * gscale)
	dragframe:SetHeight((settings.dragHeight or 225) * gscale)
	
	dragframe.t = dragframe:CreateTexture()
	dragframe.t:SetAllPoints()
	dragframe.t:SetTexture(0.0, 1.0, 0.0, 0.5)
	dragframe.t:SetAlpha(0.5)
	
	dragframe.f = dragframe:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
	dragframe.f:SetPoint('CENTER', 0, 0)
	dragframe.f:SetText(settings.dragText or "Арена")
	
	dragData.dragFrame = dragframe
	return dragframe
end

-- Создание сетки выравнивания
local function CreateAlignmentGrid()
	if dragData.alignmentGrid then return dragData.alignmentGrid end
	
	local grid = CreateFrame('FRAME')
	dragData.alignmentGrid = grid
	grid:Hide()
	grid:SetAllPoints(UIParent)
	grid:SetFrameStrata("BACKGROUND")
	grid:SetFrameLevel(0)
	grid:SetToplevel(false)
	grid:EnableMouse(false)
	
	local w, h = GetScreenWidth() * UIParent:GetEffectiveScale(), GetScreenHeight() * UIParent:GetEffectiveScale()
	local ratio = w / h
	local sqsize = w / 20
	local wline = floor(sqsize - (sqsize % 2))
	local hline = floor(sqsize / ratio - ((sqsize / ratio) % 2))
	
	-- Вертикальные линии
	for i = 0, wline do
		local t = grid:CreateTexture(nil, 'BACKGROUND')
		if i == wline / 2 then
			t:SetTexture(1, 0, 0, 0.5)
		else
			t:SetTexture(0, 0, 0, 0.5)
		end
		t:SetPoint('TOPLEFT', grid, 'TOPLEFT', i * w / wline - 1, 0)
		t:SetPoint('BOTTOMRIGHT', grid, 'BOTTOMLEFT', i * w / wline + 1, 0)
	end
	
	-- Горизонтальные линии
	for i = 0, hline do
		local t = grid:CreateTexture(nil, 'BACKGROUND')
		if i == hline / 2 then
			t:SetTexture(1, 0, 0, 0.5)
		else
			t:SetTexture(0, 0, 0, 0.5)
		end
		t:SetPoint('TOPLEFT', grid, 'TOPLEFT', 0, -i * h / hline + 1)
		t:SetPoint('BOTTOMRIGHT', grid, 'TOPRIGHT', 0, -i * h / hline - 1)
	end
	
	return grid
end

-- Включение режима редактирования
function ArenaDragMode:Enable(frame, settings, showDragFrame, showGrid, onPositionChanged)
	if not frame then 
		return 
	end
	
	settings = settings or {}
	
	-- Сохраняем callback
	dragData.onPositionChanged = onPositionChanged
	
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
	
	-- Создаем или обновляем drag frame
	local dragframe = CreateDragFrame(frame, settings)
	
	-- Обработка drag (устанавливаем скрипты только если еще не установлены)
	if not dragframe._scriptsSet then
		dragframe:SetScript("OnMouseDown", function(self, btn)
			if btn == "LeftButton" then
				dragData.isMoving = true
				
				-- Запоминаем СТАРТОВУЮ позицию фрейма перед drag
				-- Используем GetPoint для получения реальной позиции
				local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
				if point then
					dragData.startPosition = {
						point = point,
						relativeTo = relativeTo,
						relativePoint = relativePoint,
						xOfs = xOfs,
						yOfs = yOfs
					}
				end
				
				frame:StartMoving()
			end
		end)
		
		dragframe:SetScript("OnMouseUp", function()
			frame:StopMovingOrSizing()
			dragData.isMoving = false
			
			-- Получаем НОВУЮ позицию фрейма после drag
			-- Используем OnUpdate чтобы убедиться, что позиция обновилась
			local updateFrame = CreateFrame("Frame")
			local checkCount = 0
			updateFrame:SetScript("OnUpdate", function(self, elapsed)
				checkCount = checkCount + 1
				if checkCount >= 2 then -- Ждем 2 кадра
					self:SetScript("OnUpdate", nil)
					
					-- Получаем РЕАЛЬНУЮ позицию фрейма после drag
					local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
					
					if point and dragData.startPosition then
						-- Используем НОВУЮ позицию напрямую - это то, куда пользователь перетащил фрейм
						-- Устанавливаем флаг что только что был drag
						dragData.justDragged = true
						
						-- Вызываем callback с новой позицией
						if dragData.onPositionChanged then
							dragData.onPositionChanged(point, relativePoint, xOfs, yOfs)
						end
						
						-- Сбрасываем стартовую позицию
						dragData.startPosition = nil
						
						-- Сбрасываем флаг через задержку
						C_Timer.After(0.5, function()
							dragData.justDragged = false
						end)
					end
				end
			end)
		end)
		
		dragframe._scriptsSet = true
	end
	
	-- Показываем/скрываем drag frame в зависимости от showDragFrame
	if showDragFrame then
		-- Обновляем позицию drag frame перед показом
		dragframe:ClearAllPoints()
		dragframe:SetPoint(settings.dragPoint or "TOPRIGHT", frame, settings.dragPoint or "TOPRIGHT", settings.dragOffsetX or 0, settings.dragOffsetY or 2.5)
		dragframe:Show()
	else
		dragframe:Hide()
	end
	
	-- Показываем/скрываем сетку
	if showGrid then
		local grid = CreateAlignmentGrid()
		grid:Show()
	else
		if dragData.alignmentGrid then
			dragData.alignmentGrid:Hide()
		end
	end
end

-- Проверка, происходит ли сейчас drag или только что был drag
function ArenaDragMode:IsMoving()
	return dragData.isMoving == true
end

function ArenaDragMode:JustDragged()
	return dragData.justDragged == true
end

-- Отключение режима редактирования
function ArenaDragMode:Disable(frame)
	if not frame then return end
	
	dragData.isMoving = false
	dragData.justDragged = false
	
	-- Отключаем перемещение
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
	
	-- Скрываем drag frame
	if dragData.dragFrame then
		dragData.dragFrame:Hide()
	end
	
	-- Скрываем сетку
	if dragData.alignmentGrid then
		dragData.alignmentGrid:Hide()
	end
end


-- Показать/скрыть сетку
function ArenaDragMode:ShowGrid(show)
	if not dragData.alignmentGrid then
		CreateAlignmentGrid()
	end
	
	if show then
		dragData.alignmentGrid:Show()
	else
		dragData.alignmentGrid:Hide()
	end
end

-- Экспортируем модуль
-- Сохраняем в глобальную переменную для доступа из module.lua
SarychUI_ArenaDragMode = ArenaDragMode
return ArenaDragMode

