local module = SarychUI.WoWCircle
local tinsert, tremove = table.insert, table.remove
local gsub, format = string.gsub, string.format
local floor, max, min = math.floor, math.max, math.min
local After = _G.After
local function ToolsSetting(key, default)
 local value = module:GetDB()[key]
 if value ~= nil then return value end
 return default
end
local function IsToolsModuleEnabled() return module:GetDB().enabled ~= false end
-- ========================================
-- MENU BUTTON CLICK HANDLER (EXACT COPY FROM sarChat)
-- ========================================

-- Функции для работы с меню чата (EXACT COPY FROM sarChat)
local function HideChatMenu()
    local chatMenu = _G["ChatMenu"]
    if chatMenu and chatMenu:IsShown() then
        chatMenu:Hide()
    end
end

local function HideCustomChatMenu()
    if _G["SarychUI_CustomChatMenu"] and _G["SarychUI_CustomChatMenu"]:IsShown() then
        _G["SarychUI_CustomChatMenu"]:Hide()
    end
end

local function ToggleChatMenu()
    local chatMenu = _G["ChatMenu"]
    if not chatMenu then return end
    if chatMenu:IsShown() then
        chatMenu:Hide()
    else
        HideCustomChatMenu()
        chatMenu:Show()
        -- Воспроизводим звук как в оригинальном Blizzard
        PlaySound("igChatEmoteButton")
    end
end

local function ToggleCustomChatMenu(self, button)
    if button == "RightButton" then
        if not IsToolsModuleEnabled() then return end
        if (tonumber(ToolsSetting("enableCircleContextMenu", 1)) or 0) ~= 1 then return end
        if not _G["SarychUI_CustomChatMenu"] then return end
        
        if not _G["SarychUI_CustomChatMenu"]:IsShown() then
            HideChatMenu()
            _G["SarychUI_CustomChatMenu"]:ClearAllPoints()
            _G["SarychUI_CustomChatMenu"]:SetPoint("BOTTOMLEFT", self, "TOPRIGHT", 0, 0)
        end
        if _G["SarychUI_CustomChatMenu"]:IsShown() then
            _G["SarychUI_CustomChatMenu"]:Hide()
        else
            _G["SarychUI_CustomChatMenu"]:Show()
        end
    end
end

-- Функция обработки клика по кнопке меню чата (EXACT COPY FROM sarChat)
local function OnMenuButtonClick(self, button)
    if button == "LeftButton" then
        ToggleChatMenu()
    elseif button == "RightButton" then
        -- VIP / WoWCircle menu is owned by the WoWCircle companion
        local enabled = IsToolsModuleEnabled() and (tonumber(ToolsSetting("enableCircleContextMenu", 1)) or 0) == 1
        if enabled then
            ToggleCustomChatMenu(self, button)
        end
        -- Если VIP команды отключены, ПКМ ничего не делает
    end
end

-- ========================================
-- PP MESSAGE FIX FUNCTIONS (EXACT COPY FROM sarChat)
-- ========================================

-- Глобальная переменная для контроля исправления сообщений ПП
_G.SarychUI_PpMessageFixEnabled = false

-- Функция включения/отключения исправления сообщений ПП
local function EnablePpMessageFix(enabled)
    if not enabled then 
        _G.SarychUI_PpMessageFixEnabled = false
        return 
    end
    
    _G.SarychUI_PpMessageFixEnabled = true
end

-- Функция отключения исправления сообщений ПП
local function DisablePpMessageFix()
    -- Отключаем глобальный флаг
    _G.SarychUI_PpMessageFixEnabled = false
end

-- ========================================
-- VIP COMMANDS FUNCTIONS (EXACT COPY FROM sarChat)
-- ========================================

-- Глобальная переменная для контроля VIP команд
_G.SarychUI_VipCommandsEnabled = false

-- Функция отправки команд (EXACT COPY FROM sarChat)
local function SendChatCommand(command, isVip)
    -- VIP commands are owned by the WoWCircle companion
    if not IsToolsModuleEnabled() then
        return
    end
    if (tonumber(ToolsSetting("enableCircleContextMenu", 1)) or 0) ~= 1 then
        return
    end
    
    if command == "/leavevehicle" then
        if CanExitVehicle() then
            if SecureCmdOptionParse("[overridebar] [possessbar] [shapeshift] [vehicleui]") then
                VehicleExit()
            else
                print("|cffff0000Ошибка: Вы не можете покинуть транспорт сейчас.|r")
            end
        else
            print("|cffff0000Ошибка: Вы не находитесь в транспорте.|r")
        end
    else
        local chatCommand = isVip and ".vip " .. command or command
        SendChatMessage(chatCommand, "SAY")
    end
end

-- Функция для динамического изменения ширины кнопки (EXACT COPY FROM sarChat)
local function AdjustButtonWidth(button)
    local buttonText = button:GetFontString()
    if not buttonText then return end
    local textWidth = buttonText:GetStringWidth() or 0
    local buttonWidth = textWidth + 40
    button:SetWidth(buttonWidth)
end

-- Таблица для хранения таймеров скрытия подменю
local hideTimers = {}

local function AddAlignedButton(menu, textLeft, textRight, command, isVip, subMenu)
    -- Кэшируем глобальную функцию для надежности
    local UIMenu_AddButton = UIMenu_AddButton
    if not UIMenu_AddButton then
        return
    end

    local buttonText = format("%s", textLeft)
    local buttonRightText = format("|cffffffff%s|r", textRight)

    UIMenu_AddButton(menu, buttonText, nil, function()
        SendChatCommand(command, isVip)
        if menu:GetName() == "SarychUI_TestSubMenu" then
            if _G["SarychUI_CustomChatMenu"] then
                _G["SarychUI_CustomChatMenu"]:Hide()
            end
        end
    end, nil, nil, "GameFontNormal", subMenu)

    local button = _G[menu:GetName().."Button"..menu.numButtons]
    if button then
        AdjustButtonWidth(button)
        local rightText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rightText:SetPoint("RIGHT", button, "RIGHT", -10, 0)
        rightText:SetText(buttonRightText)

        if subMenu and _G[subMenu] then
            local submenuFrame = _G[subMenu]
            button:HookScript("OnEnter", function()
                if hideTimers[submenuFrame] then
                    hideTimers[submenuFrame] = nil
                end
                submenuFrame:ClearAllPoints()
                submenuFrame:SetPoint("TOPLEFT", button, "TOPRIGHT", 10, 12)
                submenuFrame:Show()
            end)
            button:HookScript("OnLeave", function()
                hideTimers[submenuFrame] = true
                After(0.3, function()
                    if not submenuFrame:IsMouseOver() and not button:IsMouseOver() then
                        submenuFrame:Hide()
                    end
                    hideTimers[submenuFrame] = nil
                end)
            end)
        end
    end
end

local function AddEmptyLine(menu)
    UIMenu_AddButton(menu, "", nil, nil, nil, nil, "GameFontNormal")
end

local function AddHeader(menu, text)
    UIMenu_AddButton(menu, "|cffffffff"..text.."|r", nil, nil, nil, nil, "GameFontNormalLarge")
end

-- Функция создания VIP меню (EXACT COPY FROM sarChat)
local function CreateVipMenu()
    if _G["SarychUI_CustomChatMenu"] then
        return _G["SarychUI_CustomChatMenu"]
    end
    
    local CustomChatMenu = CreateFrame("Frame", "SarychUI_CustomChatMenu", UIParent, "UIMenuTemplate")
    SarychUI_CustomChatMenu_OnLoad(CustomChatMenu)
    
    -- The main menu OnLoad creates and initializes the submenu.
    
    tinsert(UISpecialFrames, "SarychUI_CustomChatMenu")
    tinsert(UISpecialFrames, "SarychUI_TestSubMenu")
    
    return CustomChatMenu
end

function SarychUI_CustomChatMenu_OnLoad(self)
    UIMenu_Initialize(self)
    self:SetWidth(300)

    if not _G["SarychUI_TestSubMenu"] then
        local TestSubMenu = CreateFrame("Frame", "SarychUI_TestSubMenu", UIParent, "UIMenuTemplate")
        SarychUI_TestSubMenu_OnLoad(TestSubMenu)
        TestSubMenu:Hide()
    end
    AddAlignedButton(self, "Все команды", "...", "", false, "SarychUI_TestSubMenu")
    AddEmptyLine(self)
    AddHeader(self, "VIP-команды")

    AddAlignedButton(self, "Почта", "", "mail", true)
    AddAlignedButton(self, "Банк", "", "bank", true)
    AddAlignedButton(self, "Изучить способности", "", "class", true)
    AddAlignedButton(self, "Камень возвращения", "", "home", true)

    AddEmptyLine(self)
    AddHeader(self, "Команды аккаунта")

    AddAlignedButton(self, "Сохранить", "", ".save", false)
    AddAlignedButton(self, "Застревание", "", ".start", false)
    AddAlignedButton(self, "Слезть с транспорта", "", "/leavevehicle", false)

    AddEmptyLine(self)
    AddAlignedButton(self, "Server Info", "", ".server info", false)
    AddAlignedButton(self, "Меню", ".menu", ".menu", false)

    UIMenu_AutoSize(self)

    self:HookScript("OnHide", function()
        _G["SarychUI_TestSubMenu"]:Hide()
    end)
end

function SarychUI_TestSubMenu_OnLoad(self)
    UIMenu_Initialize(self)
    self.parentMenu = "SarychUI_CustomChatMenu"

    AddAlignedButton(self, "Item Level", "", ".gs", false)
    AddAlignedButton(self, "Почему в бою?", "", ".whycombat", false)
    AddAlignedButton(self, "Помощь", "", ".help", false)
    AddEmptyLine(self)
    AddAlignedButton(self, "SoloQ статус", "", ".soloq stats", false)
    AddAlignedButton(self, "РБГ вход", "", ".rbg join", false)

    UIMenu_AutoSize(self)
end

-- Функции для работы с меню чата (EXACT COPY FROM sarChat)
local function HideChatMenu()
    local chatMenu = _G["ChatMenu"]
    if chatMenu and chatMenu:IsShown() then
        chatMenu:Hide()
    end
end

local function HideCustomChatMenu()
    if _G["SarychUI_CustomChatMenu"] and _G["SarychUI_CustomChatMenu"]:IsShown() then
        _G["SarychUI_CustomChatMenu"]:Hide()
    end
end

local function ToggleCustomChatMenu(self, button)
    -- VIP / WoWCircle menu is owned by the WoWCircle companion
    if not IsToolsModuleEnabled() then
        return
    end
    if (tonumber(ToolsSetting("enableCircleContextMenu", 1)) or 0) ~= 1 then
        return
    end
    
    if button == "RightButton" then
        if not _G["SarychUI_CustomChatMenu"] then return end
        if not _G["SarychUI_CustomChatMenu"]:IsShown() then
            HideChatMenu()
            _G["SarychUI_CustomChatMenu"]:ClearAllPoints()
            _G["SarychUI_CustomChatMenu"]:SetPoint("BOTTOMLEFT", self, "TOPRIGHT", 0, 0)
        end
        if _G["SarychUI_CustomChatMenu"]:IsShown() then
            _G["SarychUI_CustomChatMenu"]:Hide()
        else
            _G["SarychUI_CustomChatMenu"]:Show()
        end
    end
end


-- Объявлены ниже, но используются из EnableVipCommands
local DisableVipCommands, ApplyVipCommands

-- Функция включения/отключения VIP команд
local function EnableVipCommands(enabled)
    if not enabled then 
        _G.SarychUI_VipCommandsEnabled = false
        -- При отключении вызываем DisableVipCommands для правильного восстановления
        DisableVipCommands()
        return 
    end
    
    _G.SarychUI_VipCommandsEnabled = true
    -- При включении вызываем ApplyVipCommands
    ApplyVipCommands()
end

-- Функция отключения VIP команд
function DisableVipCommands()
    -- Отключаем глобальный флаг
    _G.SarychUI_VipCommandsEnabled = false
    
    -- Восстанавливаем оригинальные обработчики кнопки меню
    local menuButton = _G["ChatFrameMenuButton"]
    if menuButton then
        if menuButton._sarychUIOriginalRegisterForClicks then
            menuButton:_sarychUIOriginalRegisterForClicks("AnyUp")
        end
        if menuButton._sarychUIOriginalOnClick then
            menuButton:SetScript("OnClick", menuButton._sarychUIOriginalOnClick)
        else
            menuButton:SetScript("OnClick", nil)
        end
    end
    
    -- Скрываем меню
    if _G["SarychUI_CustomChatMenu"] and _G["SarychUI_CustomChatMenu"]:IsShown() then
        _G["SarychUI_CustomChatMenu"]:Hide()
    end
end


-- Функция инициализации кнопки меню чата (ADAPTED FOR SarychUI)
local function InitializeChatMenuButton()
    -- Просто вызываем ApplyVipCommands для правильной инициализации
    ApplyVipCommands()
end

-- Функция применения VIP команд (owned by the WoWCircle companion)
function ApplyVipCommands()
    if not IsToolsModuleEnabled() then
        return
    end
    
    local vipCommandsEnabled = (tonumber(ToolsSetting("enableCircleContextMenu", 1)) or 0) == 1
    
    if vipCommandsEnabled then
        -- Создаем меню если его нет
        CreateVipMenu()
        
        -- Устанавливаем наш обработчик для VIP команд
        local menuButton = _G["ChatFrameMenuButton"]
        if menuButton then
            -- Сохраняем оригинальные обработчики только один раз
            if not menuButton._sarychUIOriginalRegisterForClicks then
                menuButton._sarychUIOriginalRegisterForClicks = menuButton.RegisterForClicks
            end
            if not menuButton._sarychUIOriginalOnClick then
                menuButton._sarychUIOriginalOnClick = menuButton:GetScript("OnClick")
            end
            
            -- Устанавливаем наш обработчик
            menuButton:RegisterForClicks("AnyUp")
            menuButton:SetScript("OnClick", OnMenuButtonClick)
        end
    end
end

-- Функции для работы с меню чата (EXACT COPY FROM sarChat)
local function HideChatMenu()
    local chatMenu = _G["ChatMenu"]
    if chatMenu and chatMenu:IsShown() then
        chatMenu:Hide()
    end
end

local function HideCustomChatMenu()
    if _G["SarychUI_CustomChatMenu"] and _G["SarychUI_CustomChatMenu"]:IsShown() then
        _G["SarychUI_CustomChatMenu"]:Hide()
    end
end

local function ToggleCustomChatMenu(self, button)
    -- VIP / WoWCircle menu is owned by the WoWCircle companion
    if not IsToolsModuleEnabled() then
        return
    end
    if (tonumber(ToolsSetting("enableCircleContextMenu", 1)) or 0) ~= 1 then
        return
    end
    
    if button == "RightButton" then
        if not _G["SarychUI_CustomChatMenu"] then return end
        if not _G["SarychUI_CustomChatMenu"]:IsShown() then
            HideChatMenu()
            _G["SarychUI_CustomChatMenu"]:ClearAllPoints()
            _G["SarychUI_CustomChatMenu"]:SetPoint("BOTTOMLEFT", self, "TOPRIGHT", 0, 0)
        end
        if _G["SarychUI_CustomChatMenu"]:IsShown() then
            _G["SarychUI_CustomChatMenu"]:Hide()
        else
            _G["SarychUI_CustomChatMenu"]:Show()
        end
    end
end


_G.EnableVipCommands = EnableVipCommands
_G.DisableVipCommands = DisableVipCommands
_G.ApplyVipCommands = ApplyVipCommands
_G.InitializeChatMenuButton = InitializeChatMenuButton
_G.EnablePpMessageFix = EnablePpMessageFix
_G.DisablePpMessageFix = DisablePpMessageFix
