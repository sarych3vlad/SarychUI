local SuiTimer = select(2, ...).Compat.Timer
-- SarychUI Automation Module

local select = select

local moduleName = "automation"
local module = {}

SarychUI:RegisterModule(moduleName, module)

local function DB()
    if not SarychUI or not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules then
        return nil
    end
    return SarychUI.db.profile.modules[moduleName]
end

local function IsModuleEnabled()
    local db = DB(); return db and db.enabled == true
end

local function IsAutoSellGreyEnabled()
    local bags = SarychUI.modules and SarychUI.modules.bags
    if bags and bags.IsEnabled and bags:IsEnabled()
        and bags.IsElvUIMode and bags:IsElvUIMode() then
        return false -- SarychUI Bags owns merchant junk sales in this mode.
    end
    local db = DB(); return db and db.enableAutoSellGrey == 1
end

local function IsAutoReleasePvPEnabled()
    local db = DB(); return db and db.enableAutoReleasePvP == 1
end

local function GetAutoReleaseDelay()
    local db = DB(); return (db and db.autoReleaseDelay) or 200
end

-- Подключаем AceTimer для throttling OnUpdate скриптов (оптимизация производительности)
local AceTimer = LibStub("AceTimer-3.0", true)

-- Хранилище таймеров для возможности отмены
local updateTimers = {}

local function IsAutoRepairGearEnabled()
    local db = DB(); return db and db.enableAutoRepairGear == 1
end

-- Auto-sell grey items frame
local autoSellFrame

-- Auto-release PvP frame
local autoReleasePvPFrame

-- Auto-repair gear frame
local autoRepairFrame

-- Quest automation functionality
local questAutomationFrame = nil
local questAutomationHooked = false

-- Auto train all skills functionality
local autoTrainAllFrame = nil
local autoTrainAllHooked = false
local autoTrainAllUsesScheduler = false
local autoTrainAllProcessed = false -- Flag to prevent multiple training calls

-- Auto screenshot functionality
local autoScreenshotFrame = nil
local autoScreenshotHooked = false

-- Helper function to check if modifier key is down for auto-sell grey
local function IsAutoSellGreyModifierKeyDown()
    local db = DB()
    if not db or not IsAutoSellGreyEnabled() then return false end
    
    local key = db.autoSellGreyKey or 1
    if key == 1 then
        return IsShiftKeyDown()
    elseif key == 2 then
        return IsAltKeyDown()
    elseif key == 3 then
        return IsControlKeyDown()
    end
    return false
end

-- Helper function to check if auto-sell grey should be allowed
local function CanAutoSellGrey()
    if not IsAutoSellGreyEnabled() then return false end

    local bagsModule = SarychUI and SarychUI.modules and SarychUI.modules.bags
    if bagsModule then
        if bagsModule.IsEnabled and not bagsModule:IsEnabled() then
            return false
        end
        -- ElvUI-сумки имеют свою автопродажу; классика и Baud Bag - через Автоматизацию.
        if bagsModule.IsElvUIMode and bagsModule:IsElvUIMode() then
            return false
        end
    end

    local db = DB()
    local requireKey = db.enableAutoSellGreyRequireKey == 1
    local keyDown = IsAutoSellGreyModifierKeyDown()

    -- If require key is ON and key is NOT down -> disable automation
    -- If require key is OFF and key IS down -> disable automation
    if (requireKey and not keyDown) or (not requireKey and keyDown) then
        return false
    end

    return true
end

-- Helper function to check if modifier key is down for auto-repair gear
local function IsAutoRepairGearModifierKeyDown()
    local db = DB()
    if not db then return false end
    
    local key = db.autoRepairGearKey or 1
    if key == 1 then
        return IsShiftKeyDown()
    elseif key == 2 then
        return IsAltKeyDown()
    elseif key == 3 then
        return IsControlKeyDown()
    end
    return false
end

-- Helper function to check if auto-repair gear should be allowed
local function CanAutoRepairGear()
    if not IsAutoRepairGearEnabled() then 
        return false 
    end
    
    local db = DB()
    if not db then 
        return false 
    end
    
    -- Get settings
    local requireKey = (db.autoRepairGearRequireKey == 1)
    local keyDown = IsAutoRepairGearModifierKeyDown()
    
    -- Logic:
    -- If requireKey is true: only repair when key is pressed
    -- If requireKey is false: repair automatically, but block if key is pressed
    if requireKey then
        -- Require key mode: only repair when key is down
        return keyDown
    else
        -- Auto mode: repair automatically, but block if key is down
        return not keyDown
    end
end

local merchantStackBuyerHooked = false

local function InstallMerchantStackBuyer()
    if merchantStackBuyerHooked then return end
    local original = _G.MerchantItemButton_OnModifiedClick
    if type(original) ~= "function" then return end

    _G.MerchantItemButton_OnModifiedClick = function(button, mouseButton, ...)
        local db = DB()
        local key = db and db.merchantStackBuyKey or "ALT"
        local altDown
        if SarychUI and SarychUI.AltMode and SarychUI.AltMode.IsAltPressed then
            altDown = SarychUI.AltMode:IsAltPressed()
        else
            altDown = IsAltKeyDown()
        end
        local keyDown = (key == "CTRL" and IsControlKeyDown())
            or (key ~= "CTRL" and altDown)
        if not (IsModuleEnabled() and db.enableMerchantStackBuy == 1 and keyDown)
            or IsShiftKeyDown() or not button or not button.GetID
            or (mouseButton ~= "LeftButton" and mouseButton ~= "RightButton")
            or not MerchantFrame or MerchantFrame.selectedTab ~= 1 then
            return original(button, mouseButton, ...)
        end

        local index = button:GetID()
        local link = index and GetMerchantItemLink(index)
        if not link then return original(button, mouseButton, ...) end

        local _, _, price, merchantQuantity, available, _, extendedCost = GetMerchantItemInfo(index)
        merchantQuantity = tonumber(merchantQuantity) or 1
        if merchantQuantity < 1 or available == 0 then
            return original(button, mouseButton, ...)
        end

        local maxStack = GetItemInfo and select(8, GetItemInfo(link))
        local count
        if type(maxStack) == "number" then
            count = math.floor(maxStack / merchantQuantity)
        elseif GetMerchantItemMaxStack then
            count = GetMerchantItemMaxStack(index)
        end
        count = math.floor(tonumber(count) or 0)
        if available and available > 0 then count = math.min(count, available) end
        if count < 1 then return original(button, mouseButton, ...) end

        if extendedCost or button.extendedCost then
            if MerchantFrame_ConfirmExtendedItemCost then
                MerchantFrame_ConfirmExtendedItemCost(button, count)
            end
        elseif price and MERCHANT_HIGH_PRICE_COST and price * count >= MERCHANT_HIGH_PRICE_COST
            and MerchantFrame_ConfirmHighCostItem then
            MerchantFrame_ConfirmHighCostItem(button, count)
        else
            BuyMerchantItem(index, count)
        end
        -- The selected modified click has been handled; do not buy again or open Split Stack.
    end
    merchantStackBuyerHooked = true
end

function module:Enable()
    if not IsModuleEnabled() then return end

    if SarychUI.LootRolls then SarychUI.LootRolls:Apply() end
    InstallMerchantStackBuyer()

    -- Create auto-sell frame
    if not autoSellFrame then
        autoSellFrame = CreateFrame("Frame")
    end

    -- Register auto-sell and auto-repair events (check setting inside handler)
    autoSellFrame:RegisterEvent("MERCHANT_SHOW")
    autoSellFrame:SetScript("OnEvent", function(self, event)
        if event == "MERCHANT_SHOW" then
            if not IsModuleEnabled() then return end
			InstallMerchantStackBuyer()
            
            -- Auto-sell grey items
            if CanAutoSellGrey() then
                local greyTotal = 0
                for bag = 0, NUM_BAG_SLOTS do
                    for slot = 1, GetContainerNumSlots(bag) do
                        local link = GetContainerItemLink(bag, slot)
                        if link then
                            local _, _, quality, _, _, _, _, _, _, _, sellPrice = GetItemInfo(link)
                            if quality == 0 then
                                local _, itemCount = GetContainerItemInfo(bag, slot)
                                greyTotal = greyTotal + ((sellPrice or 0) * (itemCount or 1))
                                UseContainerItem(bag, slot)
                            end
                        end
                    end
                end
                if greyTotal > 0 and SarychUI and SarychUI.PrintGrayItemsSold then
                    SarychUI:PrintGrayItemsSold(greyTotal)
                end
            end
            
            -- Auto-repair gear
            if CanAutoRepairGear() then
                if CanMerchantRepair() then
                    -- If merchant is capable of repair
                    local RepairCost, CanRepair = GetRepairAllCost()
                    if CanRepair then
                        -- If merchant is offering repair, repair all items
                        RepairAllItems()
                    end
                end
            end
        end
    end)

    -- Create auto-release PvP frame
    if not autoReleasePvPFrame then
        autoReleasePvPFrame = CreateFrame("Frame")
    end

    -- Hook StaticPopup_Show to catch DEATH popup in PvP zones (hook always, check setting inside)
    -- This ensures the hook is always active, even if setting is changed later
    if not autoReleasePvPFrame.hooked then
        hooksecurefunc("StaticPopup_Show", function(sType)
            -- Check module and setting inside hook (like Leatrix_Plus does)
            if not IsModuleEnabled() or not IsAutoReleasePvPEnabled() then return end
            
            if sType and sType == "DEATH" then
                -- Check if player has soulstone (self-resurrection ability)
                -- Call HasSoulstone() directly like Leatrix_Plus does (without checking if function exists)
                if HasSoulstone and HasSoulstone() then
                    return
                end
                
                -- Check if in PvP instance
                local InstStat, InstType = IsInInstance()
                if InstStat and InstType == "pvp" then
                    -- Release automatically after delay
                    local delay = GetAutoReleaseDelay() / 1000
                    
                    -- Use OnUpdate timer (like Leatrix_Plus uses LibCompat.After which uses OnUpdate)
                    if not autoReleasePvPFrame.releaseTimerFrame then
                        autoReleasePvPFrame.releaseTimerFrame = CreateFrame("Frame")
                        autoReleasePvPFrame.releaseTimerFrame:Hide()
                    end
                    autoReleasePvPFrame.releaseTimerFrame.releaseTimer = 0
                    autoReleasePvPFrame.releaseTimerFrame:SetScript("OnUpdate", function(self, elapsed)
                        self.releaseTimer = self.releaseTimer + elapsed
                        if self.releaseTimer >= delay then
                            self:Hide()
                            self.releaseTimer = 0
                            local dialog = StaticPopup_Visible("DEATH")
                            if dialog then
                                -- Allow cancellation with Shift key
                                if IsShiftKeyDown() then
                                    return
                                else
                                    StaticPopup_OnClick(_G[dialog], 1)
                                end
                            end
                        end
                    end)
                    autoReleasePvPFrame.releaseTimerFrame:Show()
                end
            end
        end)
        autoReleasePvPFrame.hooked = true
    end

    -- Quest automation
    module:ApplyQuestAutomation()
    
    -- Auto train all
    module:ApplyAutoTrainAll()
    
    -- Auto screenshot
    module:ApplyAutoScreenshot()

end

-- ============================================================================
-- Quest Automation Functionality
-- ============================================================================

local function IsQuestAutomationEnabled()
    local db = DB(); return db and db.enableQuestAutomation == 1
end

-- Helper function to check if override key is down
local function IsQuestOverrideKeyDown()
    local db = DB()
    if not db or not IsQuestAutomationEnabled() then return false end
    if not db.autoQuestRequireKey or db.autoQuestRequireKey ~= 1 then return false end
    
    local key = db.autoQuestKey or 1
    if key == 1 then
        return IsShiftKeyDown()
    elseif key == 2 then
        return IsAltKeyDown()
    elseif key == 3 then
        return IsControlKeyDown()
    end
    return false
end

-- Helper function to check if automation is allowed
local function CanAutomateQuest()
    if not IsModuleEnabled() or not IsQuestAutomationEnabled() then return false end
    
    local db = DB()
    local requireKey = db.autoQuestRequireKey == 1
    local keyDown = IsQuestOverrideKeyDown()
    
    -- If require key is ON and key is NOT down -> disable automation
    -- If require key is OFF and key IS down -> disable automation
    if (requireKey and not keyDown) or (not requireKey and keyDown) then
        return false
    end
    
    return true
end

-- Helper function to strip text (remove colors, brackets, etc.)
local function StripQuestText(text)
    if not text then return end
    text = text:gsub('|c%x%x%x%x%x%x%x%x(.-)|r', '%1')
    text = text:gsub('%[.*%]%s*', '')
    text = text:gsub('(.+) %(.+%)', '%1')
    -- Trim whitespace (since :trim() may not be available)
    text = text:match("^%s*(.-)%s*$") or text
    return text
end

-- Apply quest automation settings
function module:ApplyQuestAutomation()
    if not IsModuleEnabled() then
        if questAutomationHooked then
            self:DisableQuestAutomation()
        end
        return
    end
    
    if IsQuestAutomationEnabled() then
        if not questAutomationHooked then
            self:EnableQuestAutomation()
        end
    else
        if questAutomationHooked then
            self:DisableQuestAutomation()
        end
    end
end

-- Enable quest automation
function module:EnableQuestAutomation()
    if not IsModuleEnabled() or not IsQuestAutomationEnabled() then return end
    if questAutomationHooked then return end -- Already enabled
    
    -- Create frame if not exists
    if not questAutomationFrame then
        questAutomationFrame = CreateFrame("Frame")
        questAutomationFrame.completedQuests = {}
        questAutomationFrame.uncompletedQuests = {}
    end
    
    -- Event handlers
    local function OnEvent(self, event, ...)
        if not IsModuleEnabled() or not IsQuestAutomationEnabled() then return end
        
        if event == "QUEST_PROGRESS" then
            if CanAutomateQuest() and IsQuestCompletable() then
                CompleteQuest()
            end
        elseif event == "QUEST_LOG_UPDATE" then
            if CanAutomateQuest() then
                local startEntry = GetQuestLogSelection()
                local numEntries = GetNumQuestLogEntries()
                
                questAutomationFrame.completedQuests = {}
                questAutomationFrame.uncompletedQuests = {}
                
                if numEntries > 0 then
                    for i = 1, numEntries do
                        SelectQuestLogEntry(i)
                        local title, _, _, _, _, _, isComplete = GetQuestLogTitle(i)
                        local noObjectives = GetNumQuestLeaderBoards(i) == 0
                        if title and (isComplete or noObjectives) then
                            questAutomationFrame.completedQuests[title] = true
                        else
                            questAutomationFrame.uncompletedQuests[title] = true
                        end
                    end
                end
                SelectQuestLogEntry(startEntry)
            end
        elseif event == "GOSSIP_SHOW" then
            if CanAutomateQuest() then
                local db = DB()
                local button, text
                for i = 1, 32 do
                    button = _G['GossipTitleButton' .. i]
                    if button and button:IsVisible() then
                        text = StripQuestText(button:GetText())
                        if button.type == 'Available' and db.autoQuestAvailable == 1 then
                            button:Click()
                        elseif button.type == 'Active' and db.autoQuestCompleted == 1 and questAutomationFrame.completedQuests[text] then
                            button:Click()
                        end
                    end
                end
            end
        elseif event == "QUEST_GREETING" then
            if CanAutomateQuest() then
                local db = DB()
                local button, text
                for i = 1, 32 do
                    button = _G['QuestTitleButton' .. i]
                    if button and button:IsVisible() then
                        text = StripQuestText(button:GetText())
                        if db.autoQuestCompleted == 1 and questAutomationFrame.completedQuests[text] then
                            button:Click()
                        elseif db.autoQuestAvailable == 1 and not questAutomationFrame.uncompletedQuests[text] then
                            button:Click()
                        end
                    end
                end
            end
        elseif event == "QUEST_DETAIL" then
            if CanAutomateQuest() then
                local db = DB()
                if db.autoQuestAvailable == 1 then
                    AcceptQuest()
                end
            end
        elseif event == "QUEST_COMPLETE" then
            if CanAutomateQuest() then
                local db = DB()
                if db.autoQuestCompleted == 1 and GetNumQuestChoices() <= 1 then
                    GetQuestReward(QuestFrameRewardPanel.itemChoice)
                end
            end
        end
    end
    
    -- Register events
    questAutomationFrame:RegisterEvent("GOSSIP_SHOW")
    questAutomationFrame:RegisterEvent("QUEST_COMPLETE")
    questAutomationFrame:RegisterEvent("QUEST_DETAIL")
    questAutomationFrame:RegisterEvent("QUEST_FINISHED")
    questAutomationFrame:RegisterEvent("QUEST_GREETING")
    questAutomationFrame:RegisterEvent("QUEST_LOG_UPDATE")
    questAutomationFrame:RegisterEvent("QUEST_PROGRESS")
    
    questAutomationFrame:SetScript("OnEvent", OnEvent)
    
    questAutomationHooked = true
end

-- Disable quest automation
function module:DisableQuestAutomation()
    if not questAutomationHooked then return end
    
    -- Unregister all events
    if questAutomationFrame then
        questAutomationFrame:UnregisterAllEvents()
        questAutomationFrame:SetScript("OnEvent", nil)
    end
    
    -- Clear quest lists
    if questAutomationFrame then
        questAutomationFrame.completedQuests = {}
        questAutomationFrame.uncompletedQuests = {}
    end
    
    questAutomationHooked = false
end

-- ============================================================================
-- Auto Train All Skills Functionality
-- ============================================================================

local function IsAutoTrainAllEnabled()
    local db = DB(); return db and db.enableAutoTrainAll == 1
end

local function IsAutoScreenshotEnabled()
    local db = DB(); return db and db.enableAutoScreenshot == 1
end

-- Helper function to check if modifier key is down for auto train all
local function IsAutoTrainAllModifierKeyDown()
    local db = DB()
    if not db or not IsAutoTrainAllEnabled() then return false end
    
    local key = db.autoTrainAllKey or 1
    if key == 1 or key == "SHIFT" then
        return IsShiftKeyDown()
    elseif key == 2 or key == "ALT" then
        return IsAltKeyDown()
    elseif key == 3 or key == "CONTROL" or key == "CTRL" then
        return IsControlKeyDown()
    end
    return false
end

local function BuyAllAvailableTrainerServices()
    if not ClassTrainerFrame or not ClassTrainerFrame:IsShown() then return 0 end

    local trained, lastName = 0, nil
    for i = 1, GetNumTrainerServices() do
        local name, second, third = GetTrainerServiceInfo(i)
        local serviceType = third
        if serviceType ~= "available" and serviceType ~= "used" and serviceType ~= "unavailable" and serviceType ~= "header" then
            serviceType = second
        end
        if serviceType == "available" then
            local ok = pcall(BuyTrainerService, i)
            if ok then
                trained = trained + 1
                lastName = name
            end
        end
    end
    return trained, lastName
end

-- Public batch operation used by Quick Start without requiring a modifier key.
function module:TrainAllAvailableSkillsNow()
    return BuyAllAvailableTrainerServices()
end

-- Function to train all available skills
local function TrainAllAvailableSkills()
    if not IsModuleEnabled() or not IsAutoTrainAllEnabled() then return end

    -- Check if trainer frame is open
    if not ClassTrainerFrame or not ClassTrainerFrame:IsShown() then return end

    -- Check if modifier key is down
    if not IsAutoTrainAllModifierKeyDown() then
        autoTrainAllProcessed = false
        return
    end

    -- Prevent multiple training calls (wait for TRAINER_UPDATE to reset)
    if autoTrainAllProcessed then return end

    local trained = BuyAllAvailableTrainerServices()
    if trained > 0 then
        autoTrainAllProcessed = true
    end
end

-- Apply auto train all settings
function module:ApplyAutoTrainAll()
    if not IsModuleEnabled() then
        if autoTrainAllHooked then
            self:DisableAutoTrainAll()
        end
        return
    end
    
    if IsAutoTrainAllEnabled() then
        if not autoTrainAllHooked then
            self:EnableAutoTrainAll()
        end
    else
        if autoTrainAllHooked then
            self:DisableAutoTrainAll()
        end
    end
end

-- Enable auto train all
function module:EnableAutoTrainAll()
    if not IsModuleEnabled() or not IsAutoTrainAllEnabled() then return end
    if autoTrainAllHooked then return end -- Already enabled
    
    -- Create frame if not exists
    if not autoTrainAllFrame then
        autoTrainAllFrame = CreateFrame("Frame")
    end
    
    -- Register events
    autoTrainAllFrame:RegisterEvent("TRAINER_SHOW")
    autoTrainAllFrame:RegisterEvent("TRAINER_CLOSED")
    autoTrainAllFrame:RegisterEvent("TRAINER_UPDATE")
    
    -- Event handler
    autoTrainAllFrame:SetScript("OnEvent", function(self, event, ...)
        if not IsModuleEnabled() or not IsAutoTrainAllEnabled() then return end
        
        if event == "TRAINER_SHOW" then
            -- Reset processed flag when window opens
            autoTrainAllProcessed = false
            -- Check if modifier key is down and train all if needed
            if IsAutoTrainAllModifierKeyDown() then
                -- Small delay to ensure frame is fully loaded
                if SuiTimer then
                    SuiTimer.After(0.1, TrainAllAvailableSkills)
                else
                    -- Fallback for older clients
                    autoTrainAllFrame.trainCheckTimer = 0.1
                end
            end
        elseif event == "TRAINER_UPDATE" then
            -- Reset processed flag when trainer updates (new skills available)
            autoTrainAllProcessed = false
            -- Check if modifier key is down and train all if needed
            if IsAutoTrainAllModifierKeyDown() then
                TrainAllAvailableSkills()
            end
        elseif event == "TRAINER_CLOSED" then
            -- Reset processed flag when window closes
            autoTrainAllProcessed = false
        end
    end)
    
    -- Prefer SarychUI.UpdateScheduler dispatcher; AceTimer / OnUpdate as fallbacks.
    local function AutoTrainAllTick()
        if not IsModuleEnabled() or not IsAutoTrainAllEnabled() then return end
        if ClassTrainerFrame and ClassTrainerFrame:IsShown() then
            if IsAutoTrainAllModifierKeyDown() then
                TrainAllAvailableSkills()
            else
                autoTrainAllProcessed = false
            end
        end
        if autoTrainAllFrame and autoTrainAllFrame.trainCheckTimer then
            autoTrainAllFrame.trainCheckTimer = autoTrainAllFrame.trainCheckTimer - 0.1
            if autoTrainAllFrame.trainCheckTimer <= 0 then
                TrainAllAvailableSkills()
                autoTrainAllFrame.trainCheckTimer = nil
            end
        end
    end

    if SarychUI and SarychUI.UpdateScheduler and SarychUI.UpdateScheduler.RegisterUpdate then
        SarychUI.UpdateScheduler:RegisterUpdate("automation.autoTrainAll", 0.1, AutoTrainAllTick)
        autoTrainAllUsesScheduler = true
    elseif AceTimer then
        updateTimers.autoTrainAll = AceTimer:ScheduleRepeatingTimer(AutoTrainAllTick, 0.1)
        autoTrainAllUsesScheduler = false
    else
        local lastCheck = 0
        autoTrainAllFrame:SetScript("OnUpdate", function(self, elapsed)
            if not IsModuleEnabled() or not IsAutoTrainAllEnabled() then return end
            lastCheck = lastCheck + elapsed
            if lastCheck >= 0.1 then
                lastCheck = 0
                AutoTrainAllTick()
            end
        end)
        autoTrainAllUsesScheduler = false
    end

    autoTrainAllHooked = true
end

-- Disable auto train all
function module:DisableAutoTrainAll()
    if not autoTrainAllHooked then return end
    
    -- Отменяем таймер, если он активен (оптимизация производительности)
    if autoTrainAllUsesScheduler and SarychUI and SarychUI.UpdateScheduler and SarychUI.UpdateScheduler.UnregisterUpdate then
        SarychUI.UpdateScheduler:UnregisterUpdate("automation.autoTrainAll")
        autoTrainAllUsesScheduler = false
    end
    if updateTimers.autoTrainAll and AceTimer then
        AceTimer:CancelTimer(updateTimers.autoTrainAll)
        updateTimers.autoTrainAll = nil
    end
    
    -- Unregister all events and clear scripts
    if autoTrainAllFrame then
        autoTrainAllFrame:UnregisterAllEvents()
        autoTrainAllFrame:SetScript("OnEvent", nil)
        autoTrainAllFrame:SetScript("OnUpdate", nil)
        autoTrainAllFrame.trainCheckTimer = nil
    end
    
    -- Reset processed flag
    autoTrainAllProcessed = false
    
    autoTrainAllHooked = false
end

-- ============================================================================
-- Auto Screenshot Functionality
-- ============================================================================

-- Apply auto screenshot settings
function module:ApplyAutoScreenshot()
    if not IsModuleEnabled() then
        if autoScreenshotHooked then
            self:DisableAutoScreenshot()
        end
        return
    end
    
    if IsAutoScreenshotEnabled() then
        if not autoScreenshotHooked then
            self:EnableAutoScreenshot()
        end
    else
        if autoScreenshotHooked then
            self:DisableAutoScreenshot()
        end
    end
end

-- Enable auto screenshot (как в KPack - просто и надежно)
function module:EnableAutoScreenshot()
    if not IsModuleEnabled() or not IsAutoScreenshotEnabled() then return end
    if autoScreenshotHooked then return end -- Already enabled
    
    -- Helper function for delayed call (используем OnUpdate, т.к. SuiTimer.After не работает)
    local function After(duration, callback)
        -- Используем OnUpdate вместо SuiTimer.After
        local timerFrame = CreateFrame("Frame")
        local elapsed = 0
        timerFrame:SetScript("OnUpdate", function(self, delta)
            elapsed = elapsed + delta
            if elapsed >= duration then
                callback()
                self:SetScript("OnUpdate", nil)
            end
        end)
    end
    
    -- Создаем фрейм для события (как в других частях модуля)
    if not autoScreenshotFrame then
        autoScreenshotFrame = CreateFrame("Frame")
    end
    
    -- Регистрируем событие (как в KPack)
    autoScreenshotFrame:RegisterEvent("ACHIEVEMENT_EARNED")
    
    -- Event handler (максимально просто, как в KPack)
    autoScreenshotFrame:SetScript("OnEvent", function(self, event)
        -- Проверяем настройки при каждом событии (как в KPack)
        if IsModuleEnabled() and IsAutoScreenshotEnabled() then
            After(1, function() 
                -- Пробуем разные функции скриншота (как в KPack - просто Screenshot())
                if Screenshot then
                    Screenshot()
                elseif TakeScreenshot then
                    TakeScreenshot()
                end
            end)
        end
    end)
    
    autoScreenshotHooked = true
end

-- Disable auto screenshot
function module:DisableAutoScreenshot()
    if not autoScreenshotHooked then return end
    
    -- Unregister event
    if autoScreenshotFrame then
        autoScreenshotFrame:UnregisterEvent("ACHIEVEMENT_EARNED")
        autoScreenshotFrame:SetScript("OnEvent", nil)
    end
    
    autoScreenshotHooked = false
end

function module:RefreshConfig()
	if not IsModuleEnabled() then
		self:Disable()
		return
	end
	self:Disable()
	self:Enable()
end

function module:Disable()
    if SarychUI.LootRolls then SarychUI.LootRolls:Stop() end
    -- Disable auto-sell
    if autoSellFrame then
        autoSellFrame:UnregisterAllEvents()
        autoSellFrame:SetScript("OnEvent", nil)
    end

    -- Disable auto-release PvP
    if autoReleasePvPFrame then
        if autoReleasePvPFrame.releaseTimerFrame then
            autoReleasePvPFrame.releaseTimerFrame:Hide()
            autoReleasePvPFrame.releaseTimerFrame:SetScript("OnUpdate", nil)
        end
    end

    -- Disable quest automation
    self:DisableQuestAutomation()
    
    -- Disable auto train all
    self:DisableAutoTrainAll()
    
    -- Disable auto screenshot
    self:DisableAutoScreenshot()

    if self.DisableBagSortButton then
        self:DisableBagSortButton()
    end
end

function module:GetOptions()
    return {}
end



