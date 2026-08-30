-- Тест мод для sarPlatesAuras
-- Отображает рандомные иконки в фреймах для тестирования

local TestMod = {}

local function Setting(name, default)
	local value = _G[name]
	if value == nil then
		return default
	end
	return value
end

local function GetLayoutSettings()
	return {
		PLAYER_ALT_RIGHT = Setting("PLAYER_ALT_RIGHT", false) and true or false,
		ICON_SIZE_CONTROL = Setting("ICON_SIZE_CONTROL", 46),
		ICON_SIZE_CAST = Setting("ICON_SIZE_CAST", 46),
		ICON_SIZE_MOBILITY = Setting("ICON_SIZE_MOBILITY", 30),
		ICON_SIZE_OTHER = Setting("ICON_SIZE_OTHER", 30),
		ICON_SIZE_PLAYER = Setting("ICON_SIZE_PLAYER", 28),
		ICON_SIZE_PLAYER_WIDTH = Setting("ICON_SIZE_PLAYER_WIDTH", 30),
		ICON_SIZE_PLAYER_HEIGHT = Setting("ICON_SIZE_PLAYER_HEIGHT", 20),
		MAX_PLAYER_AURAS = Setting("MAX_PLAYER_AURAS", 6),
		CentrY = Setting("CentrY", 47),
		RightX = Setting("RightX", 5),
		RightY = Setting("RightY", -10),
		PlayerOffsetY = Setting("PlayerOffsetY", -7),
		PLAYER_ICON_SPACING = Setting("PLAYER_ICON_SPACING", 2),
	}
end

local function GetDisplayAlphaScale()
	local mod = SarychUI and SarychUI:GetModule("plates_auras", true)
	local profile = mod and mod.GetActiveDisplayProfile and mod:GetActiveDisplayProfile()
	local alpha = (profile and profile.display and profile.display.alpha) or 1
	local scale = (profile and profile.display and profile.display.scale) or 1
	return alpha, scale
end

local function ApplyNamePlateLayout(namePlate, layout)
	if not namePlate or not layout then return end

	local alpha, scale = GetDisplayAlphaScale()

	if namePlate.centerContainer then
		namePlate.centerContainer:SetSize(layout.ICON_SIZE_CONTROL + layout.ICON_SIZE_CAST + 4, layout.ICON_SIZE_CONTROL)
		namePlate.centerContainer:SetAlpha(alpha)
		-- Scale applied below via UpdatePlateResponsiveScale (ElvUI) or fallback SetScale.
	end

	if namePlate.controlFrame then
		namePlate.controlFrame:SetSize(layout.ICON_SIZE_CONTROL, layout.ICON_SIZE_CONTROL)
		if namePlate.controlFrame.auraIcon then
			namePlate.controlFrame.auraIcon:SetSize(layout.ICON_SIZE_CONTROL, layout.ICON_SIZE_CONTROL)
		end
	end

	if namePlate.castFrame then
		namePlate.castFrame:SetSize(layout.ICON_SIZE_CAST, layout.ICON_SIZE_CAST)
		if namePlate.castFrame.auraIcon then
			namePlate.castFrame.auraIcon:SetSize(layout.ICON_SIZE_CAST, layout.ICON_SIZE_CAST)
		end
	end

	if namePlate.mobilityContainer then
		namePlate.mobilityContainer:SetSize(layout.ICON_SIZE_MOBILITY + layout.ICON_SIZE_OTHER + 4, layout.ICON_SIZE_MOBILITY)
		namePlate.mobilityContainer:SetAlpha(alpha)
		namePlate.mobilityContainer:SetScale(scale)
	end

	if namePlate.mobilityFrame then
		namePlate.mobilityFrame:SetSize(layout.ICON_SIZE_MOBILITY, layout.ICON_SIZE_MOBILITY)
		if namePlate.mobilityFrame.auraIcon then
			namePlate.mobilityFrame.auraIcon:SetSize(layout.ICON_SIZE_MOBILITY, layout.ICON_SIZE_MOBILITY)
		end
	end

	if namePlate.otherFrame then
		namePlate.otherFrame:SetSize(layout.ICON_SIZE_OTHER, layout.ICON_SIZE_OTHER)
		if namePlate.otherFrame.auraIcon then
			namePlate.otherFrame.auraIcon:SetSize(layout.ICON_SIZE_OTHER, layout.ICON_SIZE_OTHER)
		end
	end

	if namePlate.playerFrame then
		if layout.PLAYER_ALT_RIGHT then
			namePlate.playerFrame:SetSize(2 * layout.ICON_SIZE_PLAYER + (layout.PLAYER_ICON_SPACING or 2), layout.ICON_SIZE_PLAYER)
		else
			namePlate.playerFrame:SetSize(layout.ICON_SIZE_PLAYER * layout.MAX_PLAYER_AURAS, layout.ICON_SIZE_PLAYER * 0.67)
		end
		namePlate.playerFrame:SetAlpha(alpha)
		-- Do not raw SetScale here: ElvUI responsive scale owns player/center scale.

		if namePlate.playerFrame.auraIcons then
			for _, auraFrame in ipairs(namePlate.playerFrame.auraIcons) do
				if auraFrame then
					if layout.PLAYER_ALT_RIGHT then
						-- Whole square icons, like the mob/other slots.
						auraFrame:SetSize(layout.ICON_SIZE_PLAYER, layout.ICON_SIZE_PLAYER)
						if auraFrame.icon then
							auraFrame.icon:SetSize(layout.ICON_SIZE_PLAYER, layout.ICON_SIZE_PLAYER)
							auraFrame.icon:SetTexCoord(0, 1, 0, 1)
						end
					else
						auraFrame:SetSize(layout.ICON_SIZE_PLAYER, layout.ICON_SIZE_PLAYER * 0.67)
						if auraFrame.icon then
							auraFrame.icon:SetSize(layout.ICON_SIZE_PLAYER_WIDTH, layout.ICON_SIZE_PLAYER_HEIGHT)
						end
					end
					if auraFrame.UpdateBorderSize then auraFrame.UpdateBorderSize() end
				end
			end
		end
	end

	local layoutMod = SarychUI and SarychUI.PlatesAurasElvUI
	if layoutMod and layoutMod.IsActive and layoutMod.IsActive() and layoutMod.UpdatePlateResponsiveScale then
		layoutMod.UpdatePlateResponsiveScale(namePlate, { baseScale = scale, source = "test-layout" })
	else
		if namePlate.centerContainer then
			namePlate.centerContainer:SetScale(scale)
		end
		if namePlate.playerFrame then
			namePlate.playerFrame:SetScale(scale)
		end
	end
end

-- Список тестовых иконок (ID заклинаний)
local TEST_ICONS = {
    -- Контроль
    { spellId = 118, name = "Polymorph", icon = "Interface\\Icons\\Spell_Nature_Polymorph" },
    { spellId = 20066, name = "Repentance", icon = "Interface\\Icons\\Spell_Holy_PrayerOfHealing" },
    { spellId = 33786, name = "Cyclone", icon = "Interface\\Icons\\Spell_Nature_Cyclone" },
    
    -- Иммунитеты
    { spellId = 642, name = "Divine Shield", icon = "Interface\\Icons\\Spell_Holy_DivineProtection" },
    { spellId = 45438, name = "Ice Block", icon = "Interface\\Icons\\Spell_Frost_Frost" },
    { spellId = 48707, name = "Anti-Magic Shell", icon = "Interface\\Icons\\Spell_Shadow_AntiMagicShell" },
    
    -- Тишина
    { spellId = 15487, name = "Silence", icon = "Interface\\Icons\\Spell_Shadow_ImpPhaseShift" },
    { spellId = 18469, name = "Improved Counterspell", icon = "Interface\\Icons\\Spell_Frost_IceShock" },
    
    -- Прерывания
    { spellId = 2139, name = "Counterspell", icon = "Interface\\Icons\\Spell_Frost_IceShock" },
    { spellId = 1766, name = "Kick", icon = "Interface\\Icons\\Ability_Kick" },
    
    -- Корни
    { spellId = 339, name = "Entangling Roots", icon = "Interface\\Icons\\Spell_Nature_StrangleVines" },
    { spellId = 122, name = "Frost Nova", icon = "Interface\\Icons\\Spell_Frost_FrostNova" },
    
    -- Замедления
    { spellId = 1715, name = "Hamstring", icon = "Interface\\Icons\\Ability_ShockWave" },
    { spellId = 8056, name = "Frost Shock", icon = "Interface\\Icons\\Spell_Frost_FrostShock" },
    
    -- Бафы мобильности
    { spellId = 1044, name = "Hand of Freedom", icon = "Interface\\Icons\\Spell_Holy_SealOfValor" },
    { spellId = 11305, name = "Sprint", icon = "Interface\\Icons\\Ability_Rogue_Sprint" },
    { spellId = 33357, name = "Dash", icon = "Interface\\Icons\\Ability_Druid_Dash" },
    
    -- Дизарм
    { spellId = 676, name = "Disarm", icon = "Interface\\Icons\\Ability_Warrior_Disarm" },
    
    -- Защитные бафы
    { spellId = 498, name = "Divine Protection", icon = "Interface\\Icons\\Spell_Holy_Restoration" },
    { spellId = 22812, name = "Barkskin", icon = "Interface\\Icons\\Spell_Nature_StoneClawTotem" },
    
    -- Атакующие бафы
    { spellId = 1719, name = "Recklessness", icon = "Interface\\Icons\\Ability_CriticalStrike" },
    { spellId = 19506, name = "Trueshot Aura", icon = "Interface\\Icons\\Ability_TrueShot" },
}

-- Функция для получения рандомной иконки
local function GetRandomIcon()
    return TEST_ICONS[math.random(1, #TEST_ICONS)]
end

-- Функция для создания тестовой ауры
local function CreateTestAura(iconData, duration, priority)
    local stackCount = math.random(1, 5) -- Рандомные стаки от 1 до 5
    return {
        spellId = iconData.spellId,
        name = iconData.name,
        icon = iconData.icon,
        duration = duration,
        expirationTime = GetTime() + duration,
        priority = priority or 1,
        stackCount = stackCount,
        isTestAura = true
    }
end

-- Упрощенная функция для создания иконки ауры (для тестирования)
local function CreateAuraIcon(frame, size, width, height, noBorder)
    local icon = frame:CreateTexture(nil, "OVERLAY")
    if width and height then
        -- Для прямоугольных иконок сохраняем пропорции через обрезку
        icon:SetSize(width, height)
        -- Увеличиваем изображение на 17% (показываем меньшую центральную часть)
        local imageScale = 1.17
        local cropAmount = (imageScale - 1) / (2 * imageScale)  -- (1.17-1)/(2*1.17) = 0.073
        
        -- Простая обрезка: от 30x30 к 30x20 = отрезаем по 5px сверху и снизу
        local cropTop = (size - height) / (2 * size)  -- 5/60 = 0.083
        local cropBottom = 1 - cropTop  -- 0.917
        
        -- Применяем увеличение изображения
        local finalCropTop = cropTop + cropAmount
        local finalCropBottom = cropBottom - cropAmount
        local finalCropLeft = cropAmount
        local finalCropRight = 1 - cropAmount
        
        icon:SetTexCoord(finalCropLeft, finalCropRight, finalCropTop, finalCropBottom)
    else
        icon:SetSize(size, size)
        icon:SetTexCoord(0, 1, 0, 1) -- Полная иконка для квадратных
    end
    icon:SetPoint("CENTER", frame, "CENTER")

    if not frame.cooldownText then
        local cooldownText = frame:CreateFontString(nil, "OVERLAY")
        cooldownText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
        cooldownText:SetPoint("CENTER", frame, "CENTER")
        cooldownText:SetTextColor(1, 1, 1, 1)
        frame.cooldownText = cooldownText
    end

    if not frame.stackText then
        local stackText = frame:CreateFontString(nil, "OVERLAY")
        stackText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        stackText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -4)
        stackText:SetTextColor(1, 1, 0, 1) -- Жёлтый цвет для стаков
        frame.stackText = stackText
    end

    frame.auraIcon = icon
    frame.HideGlowEffect = frame.HideGlowEffect or function() end
    frame.HideBorderEffect = frame.HideBorderEffect or function() end
    frame.ShowBorderEffect = frame.ShowBorderEffect or function() end
    return icon
end

-- Функция для обновления текста кулдауна (упрощенная версия)
local function UpdateTestCooldownText(frame, expirationTime, duration, stackCount)
    if not frame.cooldownText then return end
    
    -- Обновляем стаки
    if frame.stackText then
        if stackCount and stackCount > 1 then
            frame.stackText:SetText(tostring(stackCount))
        else
            frame.stackText:SetText("")
        end
    end
    
    if not expirationTime or expirationTime == 0 or duration == 0 then
        frame.cooldownText:SetText("")
        frame:SetScript("OnUpdate", nil)
        return
    end
    
    local function OnUpdate(self, elapsed)
        if not frame.auraIcon or not frame.auraIcon:IsShown() then
            frame.cooldownText:SetText("")
            frame:SetScript("OnUpdate", nil)
            return
        end
        
        local remaining = expirationTime - GetTime()
        if remaining <= 0 then
            frame.cooldownText:SetText("")
            frame:SetScript("OnUpdate", nil)
            return
        end
        
        if remaining < 60 then
            frame.cooldownText:SetText(string.format("%.1f", remaining))
        else
            frame.cooldownText:SetText(string.format("%.0f", remaining))
        end
    end
    
    frame:SetScript("OnUpdate", OnUpdate)
end

-- Функция для обновления позиций центральных фреймов
function TestMod.UpdateCenterFramesPosition(namePlate)
    if not namePlate then return end

    local layout = GetLayoutSettings()
    ApplyNamePlateLayout(namePlate, layout)
    
    local hasControlAura = namePlate.controlFrame and namePlate.controlFrame.auraIcon and namePlate.controlFrame.auraIcon:IsShown()
    local hasCastAura = namePlate.castFrame and namePlate.castFrame.auraIcon and namePlate.castFrame.auraIcon:IsShown()
    
    local activeCenterFrames = 0
    if hasControlAura then activeCenterFrames = activeCenterFrames + 1 end
    if hasCastAura then activeCenterFrames = activeCenterFrames + 1 end
    
    local hasVisibleIcons = false
    if not layout.PLAYER_ALT_RIGHT and namePlate.playerFrame and namePlate.playerFrame.auraIcons then
        for _, auraFrame in ipairs(namePlate.playerFrame.auraIcons) do
            if auraFrame.icon and auraFrame.icon:IsShown() then
                hasVisibleIcons = true
                break
            end
        end
    end

    local yOffset = hasVisibleIcons and layout.CentrY or (layout.CentrY - 30)
    
    -- Позиционируем контейнер
    if namePlate.centerContainer then
        namePlate.centerContainer:ClearAllPoints()
        local layoutMod = SarychUI and SarychUI.PlatesAurasElvUI
        if layoutMod and layoutMod.IsActive and layoutMod.IsActive() and namePlate.UnitFrame and layoutMod.UpdateElvUIAuraAnchor then
            layoutMod.UpdateElvUIAuraAnchor(namePlate, {
                hasVisiblePlayerIcons = hasVisibleIcons,
            })
        else
            namePlate.centerContainer:SetPoint("CENTER", namePlate, "TOP", 0, yOffset)
        end
    end
    
    -- Позиционируем фреймы внутри контейнера - центрируем как раньше
    if activeCenterFrames == 0 then
        -- Нет активных фреймов - оба в центре контейнера
        if namePlate.controlFrame then
            namePlate.controlFrame:ClearAllPoints()
            namePlate.controlFrame:SetPoint("CENTER", namePlate.centerContainer, "CENTER", 0, 0)
        end
        if namePlate.castFrame then
            namePlate.castFrame:ClearAllPoints()
            namePlate.castFrame:SetPoint("CENTER", namePlate.centerContainer, "CENTER", 0, 0)
        end
    elseif activeCenterFrames == 1 then
        -- Один активный фрейм - по центру контейнера
        if hasControlAura then
            namePlate.controlFrame:ClearAllPoints()
            namePlate.controlFrame:SetPoint("CENTER", namePlate.centerContainer, "CENTER", 0, 0)
        end
        if hasCastAura then
            namePlate.castFrame:ClearAllPoints()
            namePlate.castFrame:SetPoint("CENTER", namePlate.centerContainer, "CENTER", 0, 0)
        end
    else
        -- Два активных фрейма - по краям контейнера
        if namePlate.controlFrame then
            namePlate.controlFrame:ClearAllPoints()
            namePlate.controlFrame:SetPoint("LEFT", namePlate.centerContainer, "LEFT", 0, 0)
        end
        if namePlate.castFrame then
            namePlate.castFrame:ClearAllPoints()
            namePlate.castFrame:SetPoint("RIGHT", namePlate.centerContainer, "RIGHT", 0, 0)
        end
    end
    
    -- Обновляем позиции mobility фреймов
    TestMod.UpdateMobilityFramesPosition(namePlate)
end

-- Функция для обновления позиций mobility фреймов
function TestMod.UpdateMobilityFramesPosition(namePlate)
    if not namePlate then return end

    local layout = GetLayoutSettings()
    
    local hasMobilityAura = namePlate.mobilityFrame and namePlate.mobilityFrame.auraIcon and namePlate.mobilityFrame.auraIcon:IsShown()
    local hasOtherAura = namePlate.otherFrame and namePlate.otherFrame.auraIcon and namePlate.otherFrame.auraIcon:IsShown()
    
    local activeMobilityFrames = 0
    if hasMobilityAura then activeMobilityFrames = activeMobilityFrames + 1 end
    if hasOtherAura then activeMobilityFrames = activeMobilityFrames + 1 end
    
    -- Позиционируем контейнер
    if namePlate.mobilityContainer then
        namePlate.mobilityContainer:ClearAllPoints()
        local layoutMod = SarychUI and SarychUI.PlatesAurasElvUI
        if layoutMod and layoutMod.IsActive and layoutMod.IsActive() and namePlate.UnitFrame and layoutMod.ApplySlotAnchor then
            layoutMod.ApplySlotAnchor(namePlate.mobilityContainer, namePlate, "right")
        else
            namePlate.mobilityContainer:SetPoint("LEFT", namePlate, "RIGHT", layout.RightX, layout.RightY)
        end
    end
    
    -- Позиционируем фреймы внутри контейнера - всегда от левого края вправо
    if activeMobilityFrames == 0 then
        -- Нет активных фреймов - оба скрыты
        if namePlate.mobilityFrame then
            namePlate.mobilityFrame:ClearAllPoints()
            namePlate.mobilityFrame:SetPoint("LEFT", namePlate.mobilityContainer, "LEFT", 0, 0)
        end
        if namePlate.otherFrame then
            namePlate.otherFrame:ClearAllPoints()
            namePlate.otherFrame:SetPoint("LEFT", namePlate.mobilityContainer, "LEFT", 0, 0)
        end
    elseif activeMobilityFrames == 1 then
        -- Один активный фрейм - слева
        if hasMobilityAura then
            namePlate.mobilityFrame:ClearAllPoints()
            namePlate.mobilityFrame:SetPoint("LEFT", namePlate.mobilityContainer, "LEFT", 0, 0)
        end
        if hasOtherAura then
            namePlate.otherFrame:ClearAllPoints()
            namePlate.otherFrame:SetPoint("LEFT", namePlate.mobilityContainer, "LEFT", 0, 0)
        end
    else
        -- Два активных фрейма - слева направо
        if namePlate.mobilityFrame then
            namePlate.mobilityFrame:ClearAllPoints()
            namePlate.mobilityFrame:SetPoint("LEFT", namePlate.mobilityContainer, "LEFT", 0, 0)
        end
        if namePlate.otherFrame then
            namePlate.otherFrame:ClearAllPoints()
            namePlate.otherFrame:SetPoint("LEFT", namePlate.mobilityFrame, "RIGHT", 4, 0)
        end
    end
end

-- Функция для обновления тестовых аур
function TestMod.UpdateTestAuras(namePlate)
    if not namePlate then return end

    local layout = GetLayoutSettings()

    if not namePlate.centerContainer then
        namePlate.centerContainer = CreateFrame("Frame", nil, namePlate)
    end

    if not namePlate.mobilityContainer then
        namePlate.mobilityContainer = CreateFrame("Frame", nil, namePlate)
    end

    ApplyNamePlateLayout(namePlate, layout)
    
    -- Очищаем существующие тестовые ауры
    TestMod.ClearTestAuras(namePlate)
    
    -- Генерируем рандомные ауры для каждого фрейма
    local testAuras = {
        control = nil,   -- ControlFrame - контроль (cc)
        cast = nil,      -- CastFrame - тишина и прерывания (silence, interrupts)
        mobility = nil,  -- MobilityFrame - замедления и корни (snare, roots)
        other = nil,     -- OtherFrame - иммунитеты, бафы, разоружение (immunities, buffs_defensive, buffs_offensive, buffs_other, disarm)
        player = {}      -- PlayerFrame - прочие ауры (other)
    }
    
    -- ControlFrame - контроль (cc)
    if math.random(1, 3) == 1 then -- 33% шанс
        local iconData = GetRandomIcon()
        testAuras.control = CreateTestAura(iconData, math.random(5, 15), 70)
    end
    
    -- CastFrame - тишина и прерывания (silence, interrupts)
    if math.random(1, 3) == 1 then -- 33% шанс
        local iconData = GetRandomIcon()
        testAuras.cast = CreateTestAura(iconData, math.random(3, 8), 60)
    end
    
    -- MobilityFrame - замедления и корни (snare, roots)
    if math.random(1, 3) == 1 then -- 33% шанс
        local iconData = GetRandomIcon()
        testAuras.mobility = CreateTestAura(iconData, math.random(3, 10), 25)
    end
    
    -- OtherFrame - иммунитеты, бафы, разоружение (immunities, buffs_defensive, buffs_offensive, buffs_other, disarm)
    if math.random(1, 3) == 1 then -- 33% шанс
        local iconData = GetRandomIcon()
        testAuras.other = CreateTestAura(iconData, math.random(5, 12), 40)
    end
    
    -- PlayerFrame - прочие ауры (other) (от 1 до 6)
    local playerAuraCount = math.random(1, 6)
    for i = 1, playerAuraCount do
        local iconData = GetRandomIcon()
        local aura = CreateTestAura(iconData, math.random(8, 20), 30)
        table.insert(testAuras.player, aura)
    end
    
    -- Сохраняем тестовые ауры
    namePlate.testAuras = testAuras
    
    -- Обновляем отображение
    TestMod.DisplayTestAuras(namePlate)
    
    -- Обновляем позиции центральных фреймов
    TestMod.UpdateCenterFramesPosition(namePlate)
end

-- Функция для отображения тестовых аур
function TestMod.DisplayTestAuras(namePlate)
    if not namePlate.testAuras then return end

    local layout = GetLayoutSettings()
    local auras = namePlate.testAuras
    
    -- Создаем controlFrame если его нет
    if not namePlate.controlFrame then
        namePlate.controlFrame = CreateFrame("Frame", nil, namePlate.centerContainer)
        namePlate.controlFrame:SetSize(layout.ICON_SIZE_CONTROL, layout.ICON_SIZE_CONTROL)
        namePlate.controlFrame.auraIcon = CreateAuraIcon(namePlate.controlFrame, layout.ICON_SIZE_CONTROL)
    end
    
    -- Создаем castFrame если его нет
    if not namePlate.castFrame then
        namePlate.castFrame = CreateFrame("Frame", nil, namePlate.centerContainer)
        namePlate.castFrame:SetSize(layout.ICON_SIZE_CAST, layout.ICON_SIZE_CAST)
        namePlate.castFrame.auraIcon = CreateAuraIcon(namePlate.castFrame, layout.ICON_SIZE_CAST)
    end
    
    -- ControlFrame
    if namePlate.controlFrame and namePlate.controlFrame.auraIcon and auras.control then
        local aura = auras.control
        local icon = namePlate.controlFrame.auraIcon
        
        icon:SetTexture(aura.icon)
        icon:Show()
        
        -- Показываем текст кулдауна
        if aura.duration and aura.duration > 0 then
            UpdateTestCooldownText(namePlate.controlFrame, aura.expirationTime, aura.duration, aura.stackCount)
        end
    elseif namePlate.controlFrame and namePlate.controlFrame.auraIcon then
        namePlate.controlFrame.auraIcon:Hide()
    end
    
    -- CastFrame
    if namePlate.castFrame and namePlate.castFrame.auraIcon and auras.cast then
        local aura = auras.cast
        local icon = namePlate.castFrame.auraIcon
        
        icon:SetTexture(aura.icon)
        icon:Show()
        
        -- Показываем текст кулдауна
        if aura.duration and aura.duration > 0 then
            UpdateTestCooldownText(namePlate.castFrame, aura.expirationTime, aura.duration, aura.stackCount)
        end
    elseif namePlate.castFrame and namePlate.castFrame.auraIcon then
        namePlate.castFrame.auraIcon:Hide()
    end
    
    -- Создаем mobilityFrame если его нет
    if not namePlate.mobilityFrame then
        namePlate.mobilityFrame = CreateFrame("Frame", nil, namePlate.mobilityContainer)
        namePlate.mobilityFrame:SetSize(layout.ICON_SIZE_MOBILITY, layout.ICON_SIZE_MOBILITY)
        namePlate.mobilityFrame:SetPoint("LEFT", namePlate.mobilityContainer, "LEFT", 0, 0)
        namePlate.mobilityFrame.auraIcon = CreateAuraIcon(namePlate.mobilityFrame, layout.ICON_SIZE_MOBILITY)
    end
    
    -- Создаем otherFrame если его нет
    if not namePlate.otherFrame then
        namePlate.otherFrame = CreateFrame("Frame", nil, namePlate.mobilityContainer)
        namePlate.otherFrame:SetSize(layout.ICON_SIZE_OTHER, layout.ICON_SIZE_OTHER)
        namePlate.otherFrame:SetPoint("RIGHT", namePlate.mobilityContainer, "RIGHT", 0, 0)
        namePlate.otherFrame.auraIcon = CreateAuraIcon(namePlate.otherFrame, layout.ICON_SIZE_OTHER)
    end
    
    -- MobilityFrame
    if namePlate.mobilityFrame and namePlate.mobilityFrame.auraIcon and auras.mobility then
        local aura = auras.mobility
        local icon = namePlate.mobilityFrame.auraIcon
        
        icon:SetTexture(aura.icon)
        icon:Show()
        
        -- Показываем текст кулдауна
        if aura.duration and aura.duration > 0 then
            UpdateTestCooldownText(namePlate.mobilityFrame, aura.expirationTime, aura.duration, aura.stackCount)
        end
    elseif namePlate.mobilityFrame and namePlate.mobilityFrame.auraIcon then
        namePlate.mobilityFrame.auraIcon:Hide()
    end
    
    -- OtherFrame
    if namePlate.otherFrame and namePlate.otherFrame.auraIcon and auras.other then
        local aura = auras.other
        local icon = namePlate.otherFrame.auraIcon
        
        icon:SetTexture(aura.icon)
        icon:Show()
        
        -- Показываем текст кулдауна
        if aura.duration and aura.duration > 0 then
            UpdateTestCooldownText(namePlate.otherFrame, aura.expirationTime, aura.duration, aura.stackCount)
        end
    elseif namePlate.otherFrame and namePlate.otherFrame.auraIcon then
        namePlate.otherFrame.auraIcon:Hide()
    end
    
    -- Создаем playerFrame если его нет
    if not namePlate.playerFrame then
        namePlate.playerFrame = CreateFrame("Frame", nil, namePlate)
        namePlate.playerFrame.auraIcons = {}
        
        for i = 1, layout.MAX_PLAYER_AURAS do
            local auraFrame = CreateFrame("Frame", nil, namePlate.playerFrame)
            local frameWidth = layout.ICON_SIZE_PLAYER
            local frameHeight = layout.ICON_SIZE_PLAYER * 0.67
            auraFrame:SetSize(frameWidth, frameHeight)

            local icon = CreateAuraIcon(auraFrame, layout.ICON_SIZE_PLAYER, layout.ICON_SIZE_PLAYER_WIDTH, layout.ICON_SIZE_PLAYER_HEIGHT, false)
            auraFrame.icon = icon

            table.insert(namePlate.playerFrame.auraIcons, auraFrame)
        end
    end
    
    -- PlayerFrame - центрируем иконки как в оригинальном коде
    if namePlate.playerFrame and namePlate.playerFrame.auraIcons then
        local playerAuras = auras.player or {}
        local activeAuraCount = #playerAuras
        
        -- ElvUI owns parenting/scale; classic keeps TOP→center BOTTOM.
        namePlate.playerFrame:ClearAllPoints()
        local layoutMod = SarychUI and SarychUI.PlatesAurasElvUI
        if layout.PLAYER_ALT_RIGHT and namePlate.mobilityContainer then
            local hasRightIcon = (namePlate.mobilityFrame and namePlate.mobilityFrame.auraIcon and namePlate.mobilityFrame.auraIcon:IsShown())
                or (namePlate.otherFrame and namePlate.otherFrame.auraIcon and namePlate.otherFrame.auraIcon:IsShown())
            if hasRightIcon then
                namePlate.playerFrame:SetPoint("BOTTOMLEFT", namePlate.mobilityContainer, "TOPLEFT", 0, layout.PLAYER_ICON_SPACING or 2)
            else
                namePlate.playerFrame:SetPoint("BOTTOMLEFT", namePlate.mobilityContainer, "BOTTOMLEFT", 0, 0)
            end
        elseif layoutMod and layoutMod.IsActive and layoutMod.IsActive() and layoutMod.ApplySlotAnchor then
            layoutMod.ApplySlotAnchor(namePlate.playerFrame, namePlate, "player")
        else
            namePlate.playerFrame:SetPoint("TOP", namePlate.centerContainer, "BOTTOM", 0, layout.PlayerOffsetY)
        end
        
        -- Скрываем все иконки сначала
        for i = 1, layout.MAX_PLAYER_AURAS do
            local auraFrame = namePlate.playerFrame.auraIcons[i]
            if auraFrame and auraFrame.icon then
                auraFrame.icon:Hide()
                if auraFrame.cooldownText then
                    auraFrame.cooldownText:SetText("")
                end
                if auraFrame.stackText then
                    auraFrame.stackText:SetText("")
                end
                auraFrame:SetScript("OnUpdate", nil)
            end
        end
        
        if activeAuraCount > 0 then
            local playerSpacing = layout.PLAYER_ICON_SPACING or 2
            local totalWidth = (activeAuraCount - 1) * (layout.ICON_SIZE_PLAYER + playerSpacing)
            local startX = -totalWidth / 2
            
            for i = 1, activeAuraCount do
                local aura = playerAuras[i]
                local auraFrame = namePlate.playerFrame.auraIcons[i]
                
                if auraFrame and auraFrame.icon and aura then
                    auraFrame:ClearAllPoints()
                    if layout.PLAYER_ALT_RIGHT then
                        local column = (i - 1) % 2
                        local row = math.floor((i - 1) / 2)
                        auraFrame:SetPoint("BOTTOMLEFT", namePlate.playerFrame, "BOTTOMLEFT",
                            column * (layout.ICON_SIZE_PLAYER + playerSpacing),
                            row * (layout.ICON_SIZE_PLAYER + playerSpacing))
                    else
                        auraFrame:SetPoint("CENTER", namePlate.playerFrame, "CENTER",
                            startX + (i - 1) * (layout.ICON_SIZE_PLAYER + playerSpacing), 0)
                    end
                    
                    auraFrame.icon:SetTexture(aura.icon)
                    auraFrame.icon:Show()
                    
                    -- Показываем текст кулдауна
                    if aura.duration and aura.duration > 0 then
                        UpdateTestCooldownText(auraFrame, aura.expirationTime, aura.duration, aura.stackCount)
                    end
                end
            end
        end
    end
    
    -- ОБЯЗАТЕЛЬНО обновляем позиции после отображения аур!
    TestMod.UpdateCenterFramesPosition(namePlate)
end

-- Функция для очистки тестовых аур
function TestMod.ClearTestAuras(namePlate)
    if not namePlate then return end
    
    -- Очищаем ControlFrame
    if namePlate.controlFrame and namePlate.controlFrame.auraIcon then
        local icon = namePlate.controlFrame.auraIcon
        icon:Hide()
        if namePlate.controlFrame.cooldownText then
            namePlate.controlFrame.cooldownText:SetText("")
        end
        if namePlate.controlFrame.stackText then
            namePlate.controlFrame.stackText:SetText("")
        end
        namePlate.controlFrame:SetScript("OnUpdate", nil)
    end
    
    -- Очищаем CastFrame
    if namePlate.castFrame and namePlate.castFrame.auraIcon then
        local icon = namePlate.castFrame.auraIcon
        icon:Hide()
        if namePlate.castFrame.cooldownText then
            namePlate.castFrame.cooldownText:SetText("")
        end
        if namePlate.castFrame.stackText then
            namePlate.castFrame.stackText:SetText("")
        end
        namePlate.castFrame:SetScript("OnUpdate", nil)
    end
    
    -- Очищаем MobilityFrame
    if namePlate.mobilityFrame and namePlate.mobilityFrame.auraIcon then
        local icon = namePlate.mobilityFrame.auraIcon
        icon:Hide()
        if namePlate.mobilityFrame.cooldownText then
            namePlate.mobilityFrame.cooldownText:SetText("")
        end
        if namePlate.mobilityFrame.stackText then
            namePlate.mobilityFrame.stackText:SetText("")
        end
        namePlate.mobilityFrame:SetScript("OnUpdate", nil)
    end
    
    -- Очищаем OtherFrame
    if namePlate.otherFrame and namePlate.otherFrame.auraIcon then
        local icon = namePlate.otherFrame.auraIcon
        icon:Hide()
        if namePlate.otherFrame.cooldownText then
            namePlate.otherFrame.cooldownText:SetText("")
        end
        if namePlate.otherFrame.stackText then
            namePlate.otherFrame.stackText:SetText("")
        end
        namePlate.otherFrame:SetScript("OnUpdate", nil)
    end
    
    -- Очищаем PlayerFrame
    if namePlate.playerFrame and namePlate.playerFrame.auraIcons then
        for _, auraFrame in ipairs(namePlate.playerFrame.auraIcons) do
            if auraFrame.icon then
                auraFrame.icon:Hide()
            end
            if auraFrame.cooldownText then
                auraFrame.cooldownText:SetText("")
            end
            if auraFrame.stackText then
                auraFrame.stackText:SetText("")
            end
            auraFrame:SetScript("OnUpdate", nil)
        end
    end
    
    namePlate.testAuras = nil
    
    -- Обновляем позиции центральных фреймов после очистки
    TestMod.UpdateCenterFramesPosition(namePlate)
end

-- Helper function to get all nameplates (works with or without C_NamePlate)
local function GetAllNamePlates()
    -- Use C_NamePlate if available
    if C_NamePlate and C_NamePlate.GetNamePlates then
        return C_NamePlate.GetNamePlates()
    end
    
    -- Alternative: scan WorldFrame for nameplates
    local plates = {}
    local children = {WorldFrame:GetChildren()}
    for i = 1, #children do
        local frame = children[i]
        if frame:IsShown() and not frame:GetName() and frame:GetID() == 0 then
            table.insert(plates, frame)
        end
    end
    return plates
end

function TestMod.RefreshAllPlates()
    local allPlates = GetAllNamePlates()
    for _, namePlate in ipairs(allPlates) do
        if namePlate.testAuras then
            ApplyNamePlateLayout(namePlate, GetLayoutSettings())
            TestMod.DisplayTestAuras(namePlate)
            TestMod.UpdateCenterFramesPosition(namePlate)
        else
            TestMod.UpdateTestAuras(namePlate)
        end
    end
end

-- Функция для запуска теста
function TestMod.StartTest()
    print("|cff00ff00[sarPlatesAuras Test]|r Запуск тестового режима...")

    local mod = SarychUI and SarychUI:GetModule("plates_auras", true)
    if mod and mod.ApplySettings then
        mod:ApplySettings()
    end
    
    -- Обновляем все неймплейты
    local allPlates = GetAllNamePlates()
    for _, namePlate in ipairs(allPlates) do
        TestMod.UpdateTestAuras(namePlate)
    end
    
    -- Запускаем таймер для обновления
    if TestMod.testTimer then
        TestMod.testTimer:Cancel()
    end
    
    TestMod.testTimer = C_Timer.NewTicker(2, function()
        local allPlates = GetAllNamePlates()
        for _, namePlate in ipairs(allPlates) do
            TestMod.UpdateTestAuras(namePlate)
        end
    end)
end

-- Функция для остановки теста
function TestMod.StopTest()
    -- Проверяем, активен ли тестовый режим
    if not TestMod.testTimer then
        return -- Тестовый режим не активен, ничего не делаем
    end
    
    print("|cffff0000[sarPlatesAuras Test]|r Остановка тестового режима...")
    
    if TestMod.testTimer then
        TestMod.testTimer:Cancel()
        TestMod.testTimer = nil
    end
    
    -- Очищаем все неймплейты и обновляем реальные ауры
    local allPlates = GetAllNamePlates()
    for _, namePlate in ipairs(allPlates) do
        TestMod.ClearTestAuras(namePlate)
        -- Запускаем обновление реальных аур после очистки тестовых
        local unitId = namePlate and namePlate.namePlateUnitToken or nil
        if unitId and _G.UpdateAuras then
            _G.UpdateAuras(namePlate, unitId)
        end
    end
end

-- Создаем команды для тестирования
SLASH_SARPLATESTEST1 = "/sartest"
SLASH_SARPLATESTEST2 = "/sarplatestest"

SlashCmdList["SARPLATESTEST"] = function(msg)
    local command = string.lower(msg or "")
    
    if command == "start" or command == "" then
        TestMod.StartTest()
    elseif command == "stop" then
        TestMod.StopTest()
    elseif command == "help" then
        print("|cff00ff00[sarPlatesAuras Test]|r Команды:")
        print("|cffffffff/sartest start|r - Запустить тестовый режим")
        print("|cffffffff/sartest stop|r - Остановить тестовый режим")
        print("|cffffffff/sartest help|r - Показать эту справку")
    else
        print("|cffff0000[sarPlatesAuras Test]|r Неизвестная команда. Используйте |cffffffff/sartest help|r")
    end
end

-- Экспортируем модуль
_G.SarPlatesAurasTest = TestMod

