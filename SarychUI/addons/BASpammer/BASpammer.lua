if _G.SarychUI_ShouldLoadBASpammerEmbedded and not SarychUI_ShouldLoadBASpammerEmbedded() then
	-- Frames already exist from BASpammer.xml (loaded before this file).
	if SarychUI_NeuterBASpammerFrames then
		SarychUI_NeuterBASpammerFrames()
	end
	return
end

BASpammerEnabled = BASpammerEnabled -- set by SarychUI bootstrap/wrapper

BASpammerTooltip = CreateFrame("GameTooltip", "BASpammerTooltip", nil, "GameTooltipTemplate")

BASpammerDB = {
    posx , posy, posx1, posy1,
    Tumbler = false,
    Flag = false,
    Pattern = {},
    CheckedPattern = 1,
    Channel = 1,
    Interval = 10,
    LastTimeSpam = 0,
}

local BASpammerRaidIconList = {
[1] = { text = RAID_TARGET_1, color = {r = 1.0, g = 0.92, b = 0}, icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcons", tCoordLeft = 0, tCoordRight = 0.25, tCoordTop = 0, tCoordBottom = 0.25 };
[2] = { text = RAID_TARGET_2, color = {r = 0.98, g = 0.57, b = 0}, icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcons", tCoordLeft = 0.25, tCoordRight = 0.5, tCoordTop = 0, tCoordBottom = 0.25 };
[3] = { text = RAID_TARGET_3, color = {r = 0.83, g = 0.22, b = 0.9}, icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcons", tCoordLeft = 0.5, tCoordRight = 0.75, tCoordTop = 0, tCoordBottom = 0.25 };
[4] = { text = RAID_TARGET_4, color = {r = 0.04, g = 0.95, b = 0}, icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcons", tCoordLeft = 0.75, tCoordRight = 1, tCoordTop = 0, tCoordBottom = 0.25 };
[5] = { text = RAID_TARGET_5, color = {r = 0.7, g = 0.82, b = 0.875}, icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcons", tCoordLeft = 0, tCoordRight = 0.25, tCoordTop = 0.25, tCoordBottom = 0.5 };
[6] = { text = RAID_TARGET_6, color = {r = 0, g = 0.71, b = 1}, icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcons", tCoordLeft = 0.25, tCoordRight = 0.5, tCoordTop = 0.25, tCoordBottom = 0.5 };
[7] = { text = RAID_TARGET_7, color = {r = 1.0, g = 0.24, b = 0.168}, icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcons", tCoordLeft = 0.5, tCoordRight = 0.75, tCoordTop = 0.25, tCoordBottom = 0.5 };
[8] = { text = RAID_TARGET_8, color = {r = 0.98, g = 0.98, b = 0.98}, icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcons", tCoordLeft = 0.75, tCoordRight = 1, tCoordTop = 0.25, tCoordBottom = 0.5 };
}

function BASpammer_FillTable()
    for i=1,10 do
        BASpammerDB.Pattern[i] = "Пусто"
    end
    BASpammerDB.CheckedPattern = 1
    BASpammerDB.Channel = 1
    BASpammerDB.Interval = 10
    BASpammerDB.Tumbler = false
    BASpammerDB.Flag = true
    BASpammerDB.LastTimeSpam = 0
end

function BASpammer_SetText()
    if BASpammerDB.Tumbler == false then
        BASpammerText:SetText("BASpammer |cffff0000Off|r")
    else
        BASpammerText:SetText("BASpammer |cff00ff00On|r")
    end
end

function BASpammer:OnMouseDown(self, arg1)
    if BASpammerDB.Flag == false then
        BASpammer_FillTable()
    end
    BASpammerSettingTextPatternEditBox:SetText("Шаблон " .. tostring(BASpammerDB.CheckedPattern))
    BASpammerSettingTextBox:SetText(BASpammerDB.Pattern[BASpammerDB.CheckedPattern])
    BASpammerSettingIntervalEditBox:SetText(tostring(BASpammerDB.Interval))
    BASpammerSettingChanelEditBox:SetText("Канал " .. BASpammerDB.Channel)
    if ( arg1 == "RightButton" ) then
        if BASpammerSetting:IsShown() then
            BASpammerSetting:Hide()
        else
            BASpammerSetting:Show()
        end
    end
end

local function BASpammer_GetCursorScaledPosition()
    local scale, x, y = UIParent:GetScale(), GetCursorPosition()
    return x / scale, y / scale
end

function BASpammerSettingTextBox_OnMouseDown(self,arg1)
    if ( arg1 == "RightButton" ) then
        local x,y = BASpammer_GetCursorScaledPosition()
        ToggleDropDownMenu(1, nil, BASpammerMarkersDropdown, "UIParent", x, y)
    end
end

function BASpammerSettingChanelButton_OnClick()
    ToggleDropDownMenu(1, nil, BASpammerChannelsDropdown, "BASpammerSettingChanelButton", 0, 0)
end

function BASpammerSettingTextPatternButton_OnClick()
    ToggleDropDownMenu(1, nil, TextPatternDropdown, "BASpammerSettingTextPatternButton", 0, 0)
end

local IntervalRandom

local BA_prevMaxFPSBk

local function BA_EnsureBackgroundFPS()
    local v = tonumber(GetCVar("maxFPSBk")) or 0
    BA_prevMaxFPSBk = v
    if v <= 30 then
        SetCVar("maxFPSBk", "30")
    end
end

local function BA_RestoreBackgroundFPS()
    if BA_prevMaxFPSBk ~= nil then
        SetCVar("maxFPSBk", tostring(BA_prevMaxFPSBk))
        BA_prevMaxFPSBk = nil
    end
end

function BASpammer:OnUpdate() -- собственно сам спам!
    if BASpammerEnabled == false then return end
    if not BASpammerDB.Tumbler then return end

    local now = GetTime()
    local last = BASpammerDB.LastTimeSpam or 0
    local base = tonumber(BASpammerDB.Interval) or 10
    local interval = tonumber(IntervalRandom) or base

    if (now - last) >= interval then
        local msg = BASpammerDB.Pattern[BASpammerDB.CheckedPattern] or ""
        if msg ~= "" then
            SendChatMessage(msg, "CHANNEL", nil, BASpammerDB.Channel)
        end
        BASpammerDB.LastTimeSpam = now
        if math.random(2) == 1 then
            IntervalRandom = base + math.random(2)
        else
            IntervalRandom = base - math.random(2)
        end
        interval = IntervalRandom
    end

    local remain = math.max(0, interval - (now - (BASpammerDB.LastTimeSpam or now)))
    BASpammerSettingTaximeterText:SetText(tostring(math.floor(remain + 0.5)))
end


function BASpammer:SavePosition(argpos)
    if argpos == 1 then
        local Left = BASpammer:GetLeft()
        local Top = BASpammer:GetTop()
        if Left and Top then
            BASpammerDB.posx = Left
            BASpammerDB.posy = Top
        end
    end
    if argpos == 2 then
        local Left = BASpammerSetting:GetLeft()
        local Top = BASpammerSetting:GetTop()
        if Left and Top then
            BASpammerDB.posx1 = Left
            BASpammerDB.posy1 = Top
        end
    end
end

local info = {}

function TextPattern_OnClick(arg1)
    BASpammerSettingTextPatternEditBox:SetText("Шаблон " .. tostring(arg1))
    BASpammerSettingTextBox:SetText(BASpammerDB.Pattern[arg1])
    BASpammerDB.CheckedPattern = arg1
end

function BASpammerChannelsDropdown_OnClick(arg1)
    BASpammerSettingChanelEditBox:SetText("Канал " .. arg1)
    BASpammerDB.Channel = arg1
end

local BASpammerChannelsDropdown = CreateFrame("Frame", "BASpammerChannelsDropdown");
BASpammerChannelsDropdown.displayMode = "MENU"
BASpammerChannelsDropdown.point = "TOPRIGHT"
BASpammerChannelsDropdown.relativePoint = "BOTTOMRIGHT"
BASpammerChannelsDropdown.relativeTo = "BASpammerSettingChanelButton"
BASpammerChannelsDropdown.initialize = function(self, level)
    if not level then return end
    wipe(info)
    local channels = { GetChannelList() }
    local chan = {}
    local j = 0
    for key,name in ipairs(channels) do
        if key % 2 ~= 0 then
            j = j + 1
            chan[j] = name
        else
            chan[j] = chan[j] .. ". " .. name
        end
    end
    for key, name in ipairs(chan) do
        info.text = name
        info.arg1 = string.sub(name, 1, 1)
        info.func = function(self, arg1, arg2, checked)
            CloseDropDownMenus()
            BASpammerChannelsDropdown_OnClick(arg1)
        end;
        UIDropDownMenu_AddButton(info);
    end
    info.text = CLOSE
    info.func = function() CloseDropDownMenus() end
    UIDropDownMenu_AddButton(info)
end

local TextPatternDropdown = CreateFrame("Frame", "TextPatternDropdown");
TextPatternDropdown.displayMode = "MENU"
TextPatternDropdown.point = "TOPRIGHT"
TextPatternDropdown.relativePoint = "BOTTOMRIGHT"
TextPatternDropdown.relativeTo = "BASpammerSettingTextPatternButton"
TextPatternDropdown.initialize = function(self, level)
    if not level then return end
    wipe(info)
    for i =1,10 do
        info.text = "Шаблон" .. i
        info.arg1 = i
        info.func = function(self, arg1, arg2, checked)
            CloseDropDownMenus()
            TextPattern_OnClick(arg1)
        end
        info.tooltipTitle = tostring("Шаблон " .. i)
        info.tooltipText = BASpammerDB.Pattern[i]
        UIDropDownMenu_AddButton(info);
    end
    info.text = CLOSE
    info.func = function() CloseDropDownMenus() end
    UIDropDownMenu_AddButton(info)
end

function BASpammerMarkersDropdown_OnClick(arg1)
    BASpammerSettingTextBox:Insert("{rt"..arg1.."}")
end

local BASpammerMarkersDropdown = CreateFrame("Frame", "BASpammerMarkersDropdown");
BASpammerMarkersDropdown.displayMode = "MENU"
BASpammerMarkersDropdown.initialize = function(self, level)
    if not level then return end
    local color
    wipe(info)
    for i = 1,8 do
        info = UIDropDownMenu_CreateInfo()
        info.text = BASpammerRaidIconList[i].text
        color = BASpammerRaidIconList[i].color
        info.colorCode = string.format("|cFF%02x%02x%02x", color.r*255, color.g*255, color.b*255)
        info.icon = BASpammerRaidIconList[i].icon
        info.tCoordLeft = BASpammerRaidIconList[i].tCoordLeft
        info.tCoordRight = BASpammerRaidIconList[i].tCoordRight
        info.tCoordTop = BASpammerRaidIconList[i].tCoordTop
        info.tCoordBottom = BASpammerRaidIconList[i].tCoordBottom
        info.arg1 = i
        info.func = function(self, arg1, arg2, checked)
            CloseDropDownMenus()
            BASpammerMarkersDropdown_OnClick(arg1)
        end
        UIDropDownMenu_AddButton(info)
    end
    info = UIDropDownMenu_CreateInfo()
    info.text = CLOSE
    info.func = function() CloseDropDownMenus() end
    UIDropDownMenu_AddButton(info)
end

function BASpammer:SetupFrames()
    if BASpammerDB.posx ~= nil and BASpammerDB.posy ~= nil then
        BASpammer:ClearAllPoints()
        BASpammer:SetPoint("TOPLEFT","UIParent", "BOTTOMLEFT", BASpammerDB.posx, BASpammerDB.posy)
    end
    if BASpammerDB.posx1 ~= nil and BASpammerDB.posy1 ~= nil then
        BASpammerSetting:ClearAllPoints()
        BASpammerSetting:SetPoint("TOPLEFT","UIParent", "BOTTOMLEFT", BASpammerDB.posx1, BASpammerDB.posy1)
    end
    BASpammerSettingTaximeter:Hide()
    BASpammerSettingStoptButton:Disable()
end

function BASpammerSettingTextBox_OnTextChanged()
    BASpammerDB.Pattern[BASpammerDB.CheckedPattern] = BASpammerSettingTextBox:GetText()
    if strlen(BASpammerDB.Pattern[BASpammerDB.CheckedPattern]) > 255 then
        BASpammerSettingTextBox:SetText(string.sub(BASpammerDB.Pattern[BASpammerDB.CheckedPattern],1,255))
    end
    
end

function BASpammerSettingTextBox_OnEnterPressed()
    BASpammerSettingTextBox:Insert(" ")
end

function BASpammerSettingTextBox_OnTabPressed()
    BASpammerSettingTextBox:Insert("    ")
end

function BASpammer_OnEvent(BASpammer_self, BASpammer_event, BASpammer_arg1, ...)
    if( BASpammer_event == "ADDON_LOADED" and (BASpammer_arg1 == "BASpammer" or BASpammer_arg1 == "SarychUI")) then
        if BASpammerEnabled == false then
            BASpammer:Hide()
            if BASpammerSetting then BASpammerSetting:Hide() end
            return
        end
        print("Аддон BASpammer загружен.");
        BASpammer:SetupFrames()
        if BASpammerSettingTextSymbols then
            BASpammerSettingTextSymbols:ClearAllPoints()
            BASpammerSettingTextSymbols:SetPoint("BOTTOMLEFT", BASpammer_InsertAchievementBtn, "TOPLEFT", 124, -19)
            BASpammerSettingTextSymbols:SetJustifyH("LEFT")
        end
    end
    if ( BASpammer_event == "VARIABLES_LOADED" ) then
        if BASpammerDB == nil then
            BASpammerDB.Flag = false
        end
        BASpammerDB.Tumbler = false
        BASpammerDB.LastTimeSpam = 0
        BASpammer_SetText()
    end
end

BASpammer:SetScript("OnEvent", BASpammer_OnEvent);
BASpammer:RegisterEvent("ADDON_LOADED");
BASpammer:RegisterEvent("VARIABLES_LOADED");

function BASpammerSettingIntervalEditBox_OnChar(self,txt)
    local  indexByte = string.byte(txt)
    local  indexByteCheck = false
    for i = 48,57 do
        if indexByte == i then
            indexByteCheck = true
            break
        end
    end
    if indexByteCheck == false then
        local txt1 = BASpammerSettingIntervalEditBox:GetText()
        local length = string.len(txt1)
        local j = 0
        for i = 1,length do
            indexByte = string.byte(txt1, i)
            for i = 48,57 do
                if indexByte == i then
                    j=j+1
                end
            end
        end
        if j < 4 then
            if length == 1 then BASpammerSettingIntervalEditBox:SetText("")
            else
                local txt2 = string.sub(txt1, 1 , length-1)
                BASpammerSettingIntervalEditBox:SetText(txt2)
            end
        end
    end
end

function BASpammerSettingIntervalEditBox_OnTextChanged()
    BASpammerDB.Interval = BASpammerSettingIntervalEditBox:GetNumber()
    IntervalRandom = BASpammerDB.Interval
end

function BASpammerSettingStartButton_OnClick()
    if BASpammerDB.Interval < 10 then
        BASpammerDB.Interval = 10
        BASpammerSettingIntervalEditBox:SetText("10")
    end
    BASpammerDB.Tumbler = true
    BASpammer_SetText()
    BASpammerSettingStartButton:Disable()
    BASpammerSettingChanelButton:Disable()
    BASpammerSettingTextPatternButton:Disable()
    BASpammerSettingText:Hide()
    BASpammerSettingInterval:Hide()
    BASpammerSettingTaximeter:Show()
	
	if not IntervalRandom then IntervalRandom = BASpammerDB.Interval end
	BA_EnsureBackgroundFPS()

    BASpammerSettingStoptButton:Enable()
end

function BASpammerSettingStopButton_OnClick()
    BASpammerDB.Tumbler = false
    BASpammer_SetText()
    BASpammerSettingStartButton:Enable()
    BASpammerSettingChanelButton:Enable()
    BASpammerSettingTextPatternButton:Enable()
    BASpammerSettingTaximeter:Hide()
    BASpammerSettingText:Show()
    BASpammerSettingInterval:Show()
    BASpammerSettingStoptButton:Disable()
	BA_RestoreBackgroundFPS()

end


function BASpammerGetLink(lnk)
    if BASpammerEnabled == false then
        return ChatEdit_InsertLink_Default(lnk)
    end
    if BASpammerSetting and BASpammerSetting:IsShown() then
        BASpammerSettingTextBox:SetFocus()
        BASpammerSettingTextBox:Insert(lnk)
        
        if BASpammerDB and BASpammerDB.CheckedPattern then
            BASpammerDB.Pattern[BASpammerDB.CheckedPattern] = BASpammerSettingTextBox:GetText()
        end
        if type(BASpammerSettingTextBox_OnTextChanged) == "function" then
            BASpammerSettingTextBox_OnTextChanged()
        end
    else
        ChatEdit_InsertLink_Default(lnk)
    end
end

ChatEdit_InsertLink_Default=ChatEdit_InsertLink
ChatEdit_InsertLink=BASpammerGetLink

function BASpammer:OnEnter()
    if BASpammerDB.Tumbler then
        GameTooltip_SetDefaultAnchor(BASpammerTooltip,BASpammer)
        BASpammerTooltip:ClearLines()
        BASpammerTooltip:SetHyperlink("|cff9d9d9d|Hitem::0:0:0:0:0:0:0:0|h[]|h|r")
        BASpammerTooltip:AddLine("Идет спам!",0.77, 0.12, 0.23)
        BASpammerTooltip:AddLine("Канал: " .. "|cffffffff" .. tostring(BASpammerDB.Channel) .."|r")
        BASpammerTooltip:AddLine("Интервал: " .. "|cffffffff" .. tostring(BASpammerDB.Interval) .." сек|r")
        BASpammerTooltip:AddLine("Текст:")
        BASpammerTooltip:AddLine(BASpammerDB.Pattern[BASpammerDB.CheckedPattern], 1, 1, 1, "true")
        BASpammerTooltip:Show()
    end
end

function BASpammer:OnLeave()
    BASpammerTooltip:Hide()
end

-- Общая вставка ссылки
local function BASpammer_InsertLink(link)
    if BASpammerEnabled == false then return end
    if not link then return end
    if BASpammerSettingTextBox and BASpammerSettingTextBox:IsShown() then
        BASpammerSettingTextBox:SetFocus()
        BASpammerSettingTextBox:Insert(link)
        if BASpammerDB and BASpammerDB.CheckedPattern then
            BASpammerDB.Pattern = BASpammerDB.Pattern or {}
            BASpammerDB.Pattern[BASpammerDB.CheckedPattern] = BASpammerSettingTextBox:GetText()
        end
        if type(BASpammerSettingTextBox_OnTextChanged) == "function" then
            BASpammerSettingTextBox_OnTextChanged()
        end
    else
        ChatEdit_InsertLink(link)
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[BA] Поле \"Текст:\" не найдено — вставлено в чат.|r")
    end
end

-- Квесты
local function BASpammer_FetchQuestInfo(id, callback)
    local tipName = "BASpammerQuestTooltip"
    local tooltip = _G[tipName] or CreateFrame("GameTooltip", tipName, nil, "GameTooltipTemplate")
    local function tryFetch()
        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
        tooltip:ClearLines()
        tooltip:SetHyperlink("quest:" .. tostring(id))
        local title = _G[tipName .. "TextLeft1"] and _G[tipName .. "TextLeft1"]:GetText()
        local level = 80
        for i = 2, tooltip:NumLines() or 0 do
            local line = _G[tipName .. "TextLeft"..i] and _G[tipName .. "TextLeft"..i]:GetText()
            local lvl = line and tonumber(line:match("(%d+)"))
            if lvl then level = lvl break end
        end
        tooltip:Hide()
        if title and title ~= "" then
            callback(title, level)
            return true
        end
    end
    if tryFetch() then return end
    local elapsed, f = 0, CreateFrame("Frame")
    f:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if tryFetch() or elapsed >= 2 then
            self:SetScript("OnUpdate", nil)
            self:Hide()
            if elapsed >= 2 then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[BA] Не удалось получить данные квеста ID " .. tostring(id) .. ".|r")
            end
        end
    end)
end

local function BASpammer_InsertQuestByID(id)
    if not tonumber(id) then return end
    BASpammer_FetchQuestInfo(id, function(name, level)
        BASpammer_InsertLink(string.format("|cffffff00|Hquest:%d:%d|h[%s]|h|r", id, level or 80, name or "Название неизвестно"))
    end)
end

-- Ачивки
local function BASpammer_FetchAchievementInfo(id, callback)
    local name = GetAchievementInfo(id)
    if name then
        callback(name)
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[BA] Не удалось получить данные ачивки ID " .. tostring(id) .. ".|r")
    end
end

local function BASpammer_InsertAchievementByID(id)
    if not id then return end
    BASpammer_FetchAchievementInfo(id, function()
        BASpammer_InsertLink(GetAchievementLink(id) or ("[Achievement "..id.."]"))
    end)
end

-- Общий обработчик Add*/Remove*
local function BA_HandleClick(getLinkFunc, index)
    if BASpammerEnabled == false then return end
    if BASpammerSetting and BASpammerSetting:IsShown() then
        local link = getLinkFunc(index)
        if link then
            BASpammer_InsertLink(link)
            return true
        end
    end
end

local function BA_HookFunctionPair(addName, removeName, getLinkFunc)
    local origAdd, origRemove = _G[addName], _G[removeName]
    _G[addName] = function(i, ...) if BA_HandleClick(getLinkFunc, i) then return end return origAdd(i, ...) end
    _G[removeName] = function(i, ...) if BA_HandleClick(getLinkFunc, i) then return end return origRemove(i, ...) end
end

BA_HookFunctionPair("AddQuestWatch", "RemoveQuestWatch", GetQuestLink)
BA_HookFunctionPair("AddTrackedAchievement", "RemoveTrackedAchievement", GetAchievementLink)

-- Shift+клик по выполненным ачивкам
local function BA_ShouldIntercept() return BASpammerEnabled ~= false and BASpammerSetting and BASpammerSetting:IsShown() and IsShiftKeyDown() end
local function BA_InsertFromID(id, linkFunc) if not id then return true end local link = linkFunc(id) if not link then return true end BASpammer_InsertLink(link) return true end

local function BA_HookAchievementUI()
    if AchievementButton_OnClick and not _G._BA_Orig_AchievementButton_OnClick then
        _G._BA_Orig_AchievementButton_OnClick = AchievementButton_OnClick
        AchievementButton_OnClick = function(self, button, down)
            if BA_ShouldIntercept() then if BA_InsertFromID(self.id or self.achievementID or (self.GetID and self:GetID()), GetAchievementLink) then return end end
            return _G._BA_Orig_AchievementButton_OnClick(self, button, down)
        end
    end
    if AchievementButton_ToggleTracking and not _G._BA_Orig_AchievementButton_ToggleTracking then
        _G._BA_Orig_AchievementButton_ToggleTracking = AchievementButton_ToggleTracking
        AchievementButton_ToggleTracking = function(id)
            if BA_ShouldIntercept() then if BA_InsertFromID(id, GetAchievementLink) then return end end
            return _G._BA_Orig_AchievementButton_ToggleTracking(id)
        end
    end
    if AchievementFrameSummaryAchievement_OnClick and not _G._BA_Orig_AchievementFrameSummaryAchievement_OnClick then
        _G._BA_Orig_AchievementFrameSummaryAchievement_OnClick = AchievementFrameSummaryAchievement_OnClick
        AchievementFrameSummaryAchievement_OnClick = function(self)
            if BA_ShouldIntercept() then if BA_InsertFromID(self.id or self.achievementID or (self.GetID and self:GetID()), GetAchievementLink) then return end end
            return _G._BA_Orig_AchievementFrameSummaryAchievement_OnClick(self)
        end
    end
end

local BA_HookFrame = CreateFrame("Frame")
BA_HookFrame:RegisterEvent("PLAYER_LOGIN")
BA_HookFrame:RegisterEvent("ADDON_LOADED")
BA_HookFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" and IsAddOnLoaded("Blizzard_AchievementUI") then BA_HookAchievementUI()
    elseif event == "ADDON_LOADED" and arg1 == "Blizzard_AchievementUI" then BA_HookAchievementUI() end
end)

-- Кнопки
local function BASpammer_CreateInsertButton(name, parent, text, onClick)
    local btn = CreateFrame("Button", name, parent or UIParent, "UIPanelButtonTemplate")
    btn:SetSize(110, 22)
    btn:SetText(text)
    btn:SetScript("OnClick", onClick)
    return btn
end

local questBtn = BASpammer_CreateInsertButton("BASpammer_InsertQuestBtn", BASpammerSetting, "Вставить квест", function()
    StaticPopupDialogs["BASPAMMER_QUESTID_INPUT"] = {
        text = "Введите ID квеста", button1 = "Ок", button2 = "Отмена", hasEditBox = true, maxLetters = 6,
        OnAccept = function(self) local id = tonumber(self.editBox:GetText()) if id then BASpammer_InsertQuestByID(id) end end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }
    StaticPopup_Show("BASPAMMER_QUESTID_INPUT")
end)
questBtn:SetPoint("TOPRIGHT", BASpammerSettingTextBox, "BOTTOMRIGHT", 0, -8)

local achBtn = BASpammer_CreateInsertButton("BASpammer_InsertAchievementBtn", BASpammerSetting, "Вставить ачивку", function()
    StaticPopupDialogs["BASPAMMER_ACHIEVEMENTID_INPUT"] = {
        text = "Введите ID ачивки", button1 = "Ок", button2 = "Отмена", hasEditBox = true, maxLetters = 6,
        OnAccept = function(self) local id = tonumber(self.editBox:GetText()) if id then BASpammer_InsertAchievementByID(id) end end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }
    StaticPopup_Show("BASPAMMER_ACHIEVEMENTID_INPUT")
end)
achBtn:SetPoint("TOPLEFT", BASpammerSettingTextBox, "BOTTOMLEFT", 0, -8)

-- Динамическое размещение "Символы: ..."
local symbolText = BASpammerSymbolText or BASpammerSetting:CreateFontString(nil, "OVERLAY", "GameFontNormal")
symbolText:ClearAllPoints()
symbolText:SetPoint("LEFT", achBtn, "RIGHT", 5, 0)
symbolText:SetPoint("RIGHT", questBtn, "LEFT", -5, 0)
symbolText:SetJustifyH("CENTER")

-- Функция обновления текста
local function BASpammer_UpdateSymbolText()
    if BASpammerSettingTextBox then
        local rawText = BASpammerDB.Pattern[BASpammerDB.CheckedPattern] or ""
        local textLen = strlen(rawText)
        symbolText:SetText(string.format("Символы: %d/255", textLen))
    end
end


-- Вешаем обновление на изменение текста
if BASpammerSettingTextBox then
    BASpammerSettingTextBox:HookScript("OnTextChanged", BASpammer_UpdateSymbolText)
end

-- Первичное обновление при загрузке
BASpammer_UpdateSymbolText()

if BASpammerEnabled == false then
    BASpammer:Hide()
    if BASpammerSetting then BASpammerSetting:Hide() end
end





-- Версия 1.01
--- Добавлено рандомное значение интервала; удалена лишняя папка Image
-- Версия 1.02
--- Исправлено: кол-во символов в поле ввода соответветствует выводимому в чате
--- Добавлена обработка нажатия в поле ввода Enter и Tab
-- Версия 1.03
--- Минимальный интервал снижен до 10 с
-- Версия 1.04
--- добавлен линк квестов/ачив через ID и SHIFT + клик. Фикс несрабатывания аддона при ALT+TAB