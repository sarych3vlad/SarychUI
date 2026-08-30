local mod = LibStub("AceAddon-3.0"):GetAddon("InternalCooldowns"):NewModule("BlizzardActionBars", "AceEvent-3.0");
local lib = LibStub("LibInternalCooldowns-1.1");

-- Function to check if addon is enabled
local function IsEnabled()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.InternalCooldowns then
		return SarychUI.db.profile.addons.InternalCooldowns.enabled ~= false;
	end
	return InternalCooldownsEnabled ~= false;
end

local updateFrame = nil;
local actionButtons = {};
local updateInterval = 0.1; -- Обновляем каждые 100мс
local lastUpdate = 0;

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

function mod:OnEnable()
    if not IsEnabled() then
        return
    end
    
    -- Создаем фрейм для обновления кулдаунов с интервалом
    if not updateFrame then
        updateFrame = CreateFrame("Frame");
        updateFrame:SetScript("OnUpdate", function(self, elapsed)
            lastUpdate = lastUpdate + elapsed;
            if lastUpdate >= updateInterval then
                mod:UpdateActionButtonCooldowns();
                lastUpdate = 0;
            end
        end);
    end
    
    -- Находим все кнопки действий
    self:FindActionButtons();
    
    -- Регистрируем callback для обновления при событиях
    lib.RegisterCallback(self, "InternalCooldowns_Proc");
    
    -- Следим за событиями, которые могут изменить панели
    self:RegisterEvent("ACTIONBAR_SLOT_CHANGED");
    self:RegisterEvent("PLAYER_ENTERING_WORLD");
    self:RegisterEvent("ACTIONBAR_SHOWGRID");
    self:RegisterEvent("ACTIONBAR_HIDEGRID");
    self:RegisterEvent("UPDATE_BONUS_ACTIONBAR");
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORMS");
    self:RegisterEvent("PET_ATTACK_START");
    self:RegisterEvent("PET_ATTACK_STOP");
end;

function mod:OnDisable()
    if updateFrame then
        updateFrame:SetScript("OnUpdate", nil);
    end
    
    lib.UnregisterCallback(self, "InternalCooldowns_Proc");
    self:UnregisterEvent("ACTIONBAR_SLOT_CHANGED");
    self:UnregisterEvent("PLAYER_ENTERING_WORLD");
    self:UnregisterEvent("ACTIONBAR_SHOWGRID");
    self:UnregisterEvent("ACTIONBAR_HIDEGRID");
    self:UnregisterEvent("UPDATE_BONUS_ACTIONBAR");
    self:UnregisterEvent("UPDATE_SHAPESHIFT_FORMS");
    self:UnregisterEvent("PET_ATTACK_START");
    self:UnregisterEvent("PET_ATTACK_STOP");
end;

function mod:FindActionButtons()
    wipe(actionButtons);
    
    -- Ищем все кнопки действий
    for _, buttonName in ipairs(actionBarFrames) do
        local button = _G[buttonName];
        if button and button:IsVisible() then
            -- Проверяем, что кнопка имеет корректный слот действия
            local slot = button.action;
            if slot and slot > 0 then
                actionButtons[buttonName] = button;
            end
        end
    end
end;

function mod:ACTIONBAR_SLOT_CHANGED()
    -- Пересканируем кнопки при изменении слотов
    self:FindActionButtons();
end;

function mod:PLAYER_ENTERING_WORLD()
    -- Пересканируем кнопки при входе в мир
    self:FindActionButtons();
end;

function mod:ACTIONBAR_SHOWGRID()
    -- Пересканируем кнопки при показе панели действий
    self:FindActionButtons();
end;

function mod:ACTIONBAR_HIDEGRID()
    -- Пересканируем кнопки при скрытии панели действий
    self:FindActionButtons();
end;

function mod:UPDATE_BONUS_ACTIONBAR()
    -- Пересканируем кнопки при изменении дополнительной панели
    self:FindActionButtons();
end;

function mod:UPDATE_SHAPESHIFT_FORMS()
    -- Пересканируем кнопки при изменении форм
    self:FindActionButtons();
end;

function mod:PET_ATTACK_START()
    -- Пересканируем кнопки при начале атаки питомца
    self:FindActionButtons();
end;

function mod:PET_ATTACK_STOP()
    -- Пересканируем кнопки при остановке атаки питомца
    self:FindActionButtons();
end;

function mod:UpdateActionButtonCooldowns()
    -- Обновляем кулдауны для всех найденных кнопок
    for buttonName, button in pairs(actionButtons) do
        if button and button:IsVisible() then
            -- Проверяем, что кнопка имеет корректный слот действия
            local slot = button.action;
            if slot and slot > 0 then
                -- Проверяем, что слот содержит действие
                local actionType, id = GetActionInfo(slot);
                if actionType then
                    -- Обновляем кулдаун для кнопки
                    ActionButton_UpdateCooldown(button);
                end
            end
        end
    end
end;

function mod:InternalCooldowns_Proc(callback, itemID, spellID, start, duration, procSource)
    -- Принудительное обновление при событии InternalCooldowns
    self:UpdateActionButtonCooldowns();
    
    -- Если это восстановленный кулдаун, обновляем немедленно
    if procSource == "RESTORED" then
        self:UpdateActionButtonCooldowns();
    end
end;
