local mod = LibStub("AceAddon-3.0"):GetAddon("InternalCooldowns"):NewModule("ProcOverlay", "AceEvent-3.0");
local lib = LibStub("LibInternalCooldowns-1.1");

-- Function to check if addon is enabled
local function IsEnabled()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.InternalCooldowns then
		return SarychUI.db.profile.addons.InternalCooldowns.enabled ~= false;
	end
	return InternalCooldownsEnabled ~= false;
end

local procOverlays = {}; -- Храним информацию о проках
local updateFrame = nil;
local updateInterval = 0.1; -- Обновляем каждые 100мс
local lastUpdate = 0;

function mod:OnEnable()
    if not IsEnabled() then
        return
    end
    
    -- Создаем фрейм для обновления прока
    if not updateFrame then
        updateFrame = CreateFrame("Frame");
        updateFrame:SetScript("OnUpdate", function(self, elapsed)
            lastUpdate = lastUpdate + elapsed;
            if lastUpdate >= updateInterval then
                mod:UpdateProcOverlays();
                lastUpdate = 0;
            end
        end);
    end
    
    -- Регистрируем callback для отслеживания прока
    lib.RegisterCallback(self, "InternalCooldowns_Proc");

	-- Восстанавливаем активные проки после /reload
	self:RestoreProcs();

	-- Сохраняем на выход
	self:RegisterEvent("PLAYER_LOGOUT");
end;

function mod:OnDisable()
    if updateFrame then
        updateFrame:SetScript("OnUpdate", nil);
    end
    
    lib.UnregisterCallback(self, "InternalCooldowns_Proc");
	self:UnregisterEvent("PLAYER_LOGOUT");
    
    -- Очищаем все проки
    for itemID, overlay in pairs(procOverlays) do
        self:RemoveProcOverlay(itemID);
    end
end;

function mod:InternalCooldowns_Proc(callback, itemID, spellID, start, duration, procSource)
    -- Пропускаем ГКД тринкетов и восстановленные кулдауны
    if procSource == "TRINKET_GCD" or procSource == "RESTORED" then
        return;
    end
    
    -- Получаем правильную длительность прока из баффа
    local procDuration = self:GetProcDurationFromBuff(spellID);
    if procDuration and procDuration > 0 then
		self:CreateProcOverlay(itemID, spellID, start, procDuration);
    else
		self:CreateProcOverlay(itemID, spellID, start, duration);
    end
end;

function mod:CreateProcOverlay(itemID, spellID, start, duration)
    -- Удаляем старый оверлей если есть
    self:RemoveProcOverlay(itemID);
    
    -- Получаем информацию о предмете
    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(itemID);
    if not itemTexture then
        return;
    end
    
    -- Получаем информацию о заклинании
    local spellName, spellTexture;
    if spellID then
        spellName, _, spellTexture = GetSpellInfo(spellID);
    end
    
    -- Создаем фрейм оверлея
    local overlay = CreateFrame("Frame", "ProcOverlay_" .. itemID, UIParent);
    overlay:SetSize(36, 36); -- Размер как у кнопки действия
    overlay:SetFrameStrata("TOOLTIP");
    overlay:SetFrameLevel(1000);
    
    -- Создаем текстуру предмета
    local itemTextureFrame = overlay:CreateTexture(nil, "BACKGROUND");
    itemTextureFrame:SetAllPoints();
    itemTextureFrame:SetTexture(itemTexture);
    
    -- Создаем текстуру прока
    local procTextureFrame = overlay:CreateTexture(nil, "ARTWORK");
    procTextureFrame:SetAllPoints();
    if spellTexture then
        procTextureFrame:SetTexture(spellTexture);
    else
        procTextureFrame:SetTexture("Interface\\Icons\\Spell_Shadow_ShadowBolt");
    end
    
    -- Создаем кулдаун фрейм в стиле edge как у бафов
    local cooldownFrame = CreateFrame("Cooldown", nil, overlay, "CooldownFrameTemplate");
    cooldownFrame:SetAllPoints();
    cooldownFrame:SetReverse(false); -- Edge стиль идет по краю
    cooldownFrame:SetFrameLevel(overlay:GetFrameLevel() + 1);
    cooldownFrame:SetDrawEdge(true); -- Включаем edge стиль
    
    -- Создаем золотую окантовку как дочерний элемент ауры
    local borderTexture = overlay:CreateTexture(nil, "OVERLAY");
    borderTexture:SetSize(60, 60);
    borderTexture:SetPoint("CENTER", overlay, "CENTER", 0, 0);
    borderTexture:SetTexture("Interface\\Buttons\\UI-ActionButton-Border");
    borderTexture:SetBlendMode("ADD");
    borderTexture:SetAlpha(0.8);
    borderTexture:SetDrawLayer("OVERLAY", 1);
    borderTexture:SetVertexColor(1, 0.8, 0); -- Золотой цвет как в WoW
    
    -- Создаем пульсирующую анимацию для окантовки через отдельный фрейм
    local pulseFrame = CreateFrame("Frame", nil, overlay);
    pulseFrame:SetAllPoints(overlay);
    pulseFrame:SetFrameLevel(overlay:GetFrameLevel() + 3);
    
    local pulseAlpha = 0.5;
    local pulseDirection = 1;
    local pulseSpeed = 1.3;
    
    local function UpdatePulse(self, elapsed)
        -- Обновляем прозрачность
        pulseAlpha = pulseAlpha + (pulseDirection * pulseSpeed * elapsed);
        
        -- Проверяем границы и меняем направление
        if pulseAlpha >= 1.0 then
            pulseAlpha = 1.0;
            pulseDirection = -1;  -- Начинаем уменьшение
        elseif pulseAlpha <= 0.3 then
            pulseAlpha = 0.3;
            pulseDirection = 1;   -- Начинаем увеличение
        end
        
        -- Применяем прозрачность к окантовке
        borderTexture:SetAlpha(pulseAlpha);
    end
    
    -- Запускаем пульсацию
    pulseFrame:SetScript("OnUpdate", UpdatePulse);
    
    
    
    -- Сохраняем информацию о прока
    procOverlays[itemID] = {
        frame = overlay,
        cooldown = cooldownFrame,
        border = borderTexture,
        startTime = start,
        duration = duration,
        itemID = itemID,
        spellID = spellID
    };
    
    -- Устанавливаем кулдаун в стиле edge как у бафов
    local currentTime = GetTime();
    CooldownFrame_Set(cooldownFrame, currentTime, duration, 1, true); -- true для drawEdge
    
    -- Позиционируем оверлей
    self:PositionProcOverlay(itemID);
    
    -- Показываем оверлей
    overlay:Show();

	-- Сохраняем активный прок в SavedVariables с абсолютным временем окончания
	self:SaveActiveProc(itemID, spellID, start, duration);
end;

function mod:PositionProcOverlay(itemID)
    local overlay = procOverlays[itemID];
    if not overlay or not overlay.frame then return; end
    
    -- Ищем кнопку действия с этим предметом
    local actionButton = self:FindActionButtonWithItem(itemID);
    if actionButton then
        -- Позиционируем оверлей поверх кнопки действия
        overlay.frame:SetPoint("CENTER", actionButton, "CENTER", 0, 0);
        overlay.frame:SetSize(36, 36); -- Размер как у кнопки действия
        return
    end

    -- Если кнопка не найдена, пробуем привязаться к слоту экипировки на портрете
    local slot = self:FindEquippedItemSlot(itemID);
    if slot then
        local slotFrame = _G["Character" .. slot .. "Slot"];
        if slotFrame and slotFrame:IsShown() then
            overlay.frame:ClearAllPoints();
            overlay.frame:SetPoint("CENTER", slotFrame, "CENTER", 0, 0);
            overlay.frame:SetSize(36, 36);
            return
        end
    end
    
    -- Ни кнопки, ни видимого слота — не показываем оверлей, чтобы не рисовать по центру
    overlay.frame:Hide();
end;

function mod:UpdateProcOverlays()
    local currentTime = GetTime();
    
    for itemID, overlay in pairs(procOverlays) do
        if overlay and overlay.frame and overlay.startTime and overlay.duration then
            local remainingTime = overlay.startTime + overlay.duration - currentTime;
            
            if remainingTime > 0 then
                -- Кулдаун уже установлен при создании, не нужно его обновлять
            else
                -- Прок закончился, удаляем оверлей и показываем кулдаун
                self:RemoveProcOverlay(itemID);
                self:ShowItemCooldown(itemID, overlay.startTime, overlay.duration);
            end
        end
    end
end;

function mod:FindActionButtonWithItem(itemID)
    -- Список всех стандартных панелей Blizzard
    local actionBarFrames = {
        -- Основные панели
        "ActionButton1", "ActionButton2", "ActionButton3", "ActionButton4", "ActionButton5", "ActionButton6",
        "ActionButton7", "ActionButton8", "ActionButton9", "ActionButton10", "ActionButton11", "ActionButton12",
        
        -- Нижние панели
        "MultiBarBottomLeftButton1", "MultiBarBottomLeftButton2", "MultiBarBottomLeftButton3", "MultiBarBottomLeftButton4",
        "MultiBarBottomLeftButton5", "MultiBarBottomLeftButton6", "MultiBarBottomLeftButton7", "MultiBarBottomLeftButton8",
        "MultiBarBottomLeftButton9", "MultiBarBottomLeftButton10", "MultiBarBottomLeftButton11", "MultiBarBottomLeftButton12",
        
        "MultiBarBottomRightButton1", "MultiBarBottomRightButton2", "MultiBarBottomRightButton3", "MultiBarBottomRightButton4",
        "MultiBarBottomRightButton5", "MultiBarBottomRightButton6", "MultiBarBottomRightButton7", "MultiBarBottomRightButton8",
        "MultiBarBottomRightButton9", "MultiBarBottomRightButton10", "MultiBarBottomRightButton11", "MultiBarBottomRightButton12",
        
        -- Боковые панели
        "MultiBarLeftButton1", "MultiBarLeftButton2", "MultiBarLeftButton3", "MultiBarLeftButton4",
        "MultiBarLeftButton5", "MultiBarLeftButton6", "MultiBarLeftButton7", "MultiBarLeftButton8",
        "MultiBarLeftButton9", "MultiBarLeftButton10", "MultiBarLeftButton11", "MultiBarLeftButton12",
        
        "MultiBarRightButton1", "MultiBarRightButton2", "MultiBarRightButton3", "MultiBarRightButton4",
        "MultiBarRightButton5", "MultiBarRightButton6", "MultiBarRightButton7", "MultiBarRightButton8",
        "MultiBarRightButton9", "MultiBarRightButton10", "MultiBarRightButton11", "MultiBarRightButton12",
        
        -- Дополнительные панели
        "BonusActionButton1", "BonusActionButton2", "BonusActionButton3", "BonusActionButton4",
        "BonusActionButton5", "BonusActionButton6", "BonusActionButton7", "BonusActionButton8",
        "BonusActionButton9", "BonusActionButton10", "BonusActionButton11", "BonusActionButton12",
        
        -- Pet панель
        "PetActionButton1", "PetActionButton2", "PetActionButton3", "PetActionButton4",
        "PetActionButton5", "PetActionButton6", "PetActionButton7", "PetActionButton8", "PetActionButton9", "PetActionButton10",
        
        -- Shapeshift панель
        "ShapeshiftButton1", "ShapeshiftButton2", "ShapeshiftButton3", "ShapeshiftButton4",
        "ShapeshiftButton5", "ShapeshiftButton6", "ShapeshiftButton7", "ShapeshiftButton8", "ShapeshiftButton9", "ShapeshiftButton10"
    };
    
    -- Ищем кнопку действия с этим предметом
    for _, buttonName in ipairs(actionBarFrames) do
        local button = _G[buttonName];
        if button and button:IsVisible() then
            local slot = button.action;
            if slot and slot > 0 then
                local actionType, id = GetActionInfo(slot);
                if actionType == "item" and id == itemID then
                    return button;
                end
            end
        end
    end
    
    return nil;
end;

function mod:ShowItemCooldown(itemID, startTime, duration)
    -- Показываем кулдаун на кнопке действия
    local actionButton = self:FindActionButtonWithItem(itemID);
    if actionButton and actionButton.cooldown then
        CooldownFrame_Set(actionButton.cooldown, startTime, duration, 1);
    end
    
    -- Показываем кулдаун на экипированном предмете
    local slot = self:FindEquippedItemSlot(itemID);
    if slot then
        local slotFrame = _G["Character" .. slot .. "Slot"];
        if slotFrame and slotFrame.cooldown then
            CooldownFrame_Set(slotFrame.cooldown, startTime, duration, 1);
        end
    end
end;

function mod:FindEquippedItemSlot(itemID)
    -- Список слотов экипировки
    local slots = {
        [0] = "AmmoSlot",
        [1] = "HeadSlot",
        [2] = "NeckSlot",
        [3] = "ShoulderSlot",
        [4] = "ShirtSlot",
        [5] = "ChestSlot",
        [6] = "WaistSlot",
        [7] = "LegsSlot",
        [8] = "FeetSlot",
        [9] = "WristSlot",
        [10] = "HandsSlot",
        [11] = "Finger0Slot",
        [12] = "Finger1Slot",
        [13] = "Trinket0Slot",
        [14] = "Trinket1Slot",
        [15] = "BackSlot",
        [16] = "MainHandSlot",
        [17] = "SecondaryHandSlot",
        [18] = "RangedSlot",
        [19] = "TabardSlot"
    };
    
    -- Ищем слот с этим предметом
    for i = 1, 19 do
        local link = GetInventoryItemLink("player", i);
        if link then
            local id = tonumber(link:match("item:(%d+)") or 0);
            if id == itemID then
                return slots[i];
            end
        end
    end
    
    return nil;
end;

function mod:GetProcDurationFromBuff(spellID)
    if not spellID then return nil; end
    
    -- Ищем активный бафф на игроке по ID (как делает WeakAuras)
    for i = 1, 40 do
        local name, rank, icon, stacks, debuffClass, duration, expirationTime, unitCaster, isStealable, _, spellId = UnitAura("player", i, "HELPFUL");
        if not name then break; end
        
        -- Проверяем по spellId (приводим к числу)
        if tonumber(spellId) == spellID then
            -- Если есть время истечения, рассчитываем оставшееся время
            if expirationTime and tonumber(expirationTime) and tonumber(expirationTime) > 0 then
                local currentTime = GetTime();
                local remainingTime = tonumber(expirationTime) - currentTime;
                return remainingTime;
            elseif duration and tonumber(duration) and tonumber(duration) > 0 then
                return tonumber(duration);
            end
        end
    end
    
    -- Если не нашли активный бафф, пробуем получить базовую информацию
    local spellName, spellTexture, _, _, _, _, _, _, _, spellDuration = GetSpellInfo(spellID);
    if spellName then
        if spellDuration and tonumber(spellDuration) and tonumber(spellDuration) > 0 then
            return tonumber(spellDuration);
        end
    end
    
    -- Пробуем получить базовый кулдаун
    local baseCooldown = GetSpellBaseCooldown(spellID);
    if baseCooldown and baseCooldown > 0 then
        return baseCooldown / 1000; -- Конвертируем из миллисекунд в секунды
    end
    
    return nil;
end;

function mod:CheckPlayerBuffs()
    for i = 1, 40 do
        local name, rank, icon, stacks, debuffClass, duration, expirationTime, unitCaster, isStealable, _, spellId = UnitAura("player", i, "HELPFUL");
        if not name then break; end
        
        local currentTime = GetTime();
        local remainingTime = expirationTime - currentTime;
        
        print("ProcOverlay: Бафф", i, ":", name, "длительность:", duration, "оставшееся время:", remainingTime, "spellId:", spellId);
    end
end;

function mod:RemoveProcOverlay(itemID)
    local overlay = procOverlays[itemID];
    if overlay and overlay.frame then
        overlay.frame:Hide();
        overlay.frame:SetParent(nil);
        overlay.frame = nil;
        procOverlays[itemID] = nil;
    end

	-- Удаляем сохранённый прок
	if InternalCooldownsDB and InternalCooldownsDB.activeProcs then
		InternalCooldownsDB.activeProcs[itemID] = nil;
	end
end;

-- ====== Persistence for procs across reloads ======
function mod:EnsureDB()
	if not InternalCooldownsDB then
		InternalCooldownsDB = { activeCooldowns = {}, persistCooldowns = true };
	end
	if not InternalCooldownsDB.activeProcs then
		InternalCooldownsDB.activeProcs = {};
	end
end

function mod:SaveActiveProc(itemID, spellID, start, duration)
	self:EnsureDB();
	local now = GetTime();
	local nowEpoch = (GetServerTime and GetServerTime()) or time();
	local remaining = (start + duration) - now;
	if remaining <= 0 then return end
	InternalCooldownsDB.activeProcs[itemID] = {
		spellID = spellID,
		expireAt = nowEpoch + remaining,
		duration = duration
	};
end

function mod:RestoreProcs()
	self:EnsureDB();
	local saved = InternalCooldownsDB.activeProcs;
	if not saved then return end
	local nowEpoch = (GetServerTime and GetServerTime()) or time();
	local now = GetTime();
	for itemID, data in pairs(saved) do
		local expireAt = data and data.expireAt;
		local duration = data and data.duration;
		local spellID = data and data.spellID;
		if expireAt and duration then
			local remaining = expireAt - nowEpoch;
			if remaining and remaining > 0 and remaining <= (duration + 3600) then
				-- Восстанавливаем оверлей на оставшееся время
				self:CreateProcOverlay(itemID, spellID, now, remaining);
			else
				-- Удаляем мусор
				saved[itemID] = nil;
			end
		end
	end
end

function mod:PLAYER_LOGOUT()
	-- Очистка просроченных перед выходом
	self:PruneExpiredProcs();
end

function mod:PruneExpiredProcs()
	if not InternalCooldownsDB or not InternalCooldownsDB.activeProcs then return end
	local nowEpoch = (GetServerTime and GetServerTime()) or time();
	for itemID, data in pairs(InternalCooldownsDB.activeProcs) do
		if not data.expireAt or data.expireAt <= nowEpoch then
			InternalCooldownsDB.activeProcs[itemID] = nil;
		end
	end
end
