local module = SarychUI.modules.tooltip_control
local match = string.match

-- ========================================
-- ИКОНКИ В ТУЛТИПЕ (EXACT COPY FROM sarChat)
-- ========================================

-- Функция проверки включенности иконок (EXACT COPY)
local function IsChatTooltipIconsEnabled()
    return module:IsEnabled() and module:GetChatTooltipDB().itemRefIconsEnabled == 1
end

-- Инициализация иконок в тултипе
local tooltipIconsInitialized = false
local RefreshRefIcon

local function InitializeTooltipIcons()
    if not ItemRefTooltip then return end
    -- Guard against re-entry: this creates a frame and installs HookScripts, both
    -- of which leaked a fresh copy on every settings Apply.
    if tooltipIconsInitialized then return end
    tooltipIconsInitialized = true

    local iconBtn = ItemRefTooltip.icon
    if not iconBtn then
        iconBtn = CreateFrame('Button', '$parentIcon', ItemRefTooltip)
        iconBtn:SetSize(37, 37)
        iconBtn:SetPoint("TOPRIGHT", ItemRefTooltip, "TOPLEFT", 0.5, -1.5)
        iconBtn:Hide()
        iconBtn.border = iconBtn:CreateTexture(nil, 'OVERLAY')
        iconBtn.border:SetTexture([[Interface\AchievementFrame\UI-Achievement-IconFrame]])
        iconBtn.border:SetTexCoord(0, .5625, 0, .5625)
        iconBtn.border:SetPoint("CENTER")
        iconBtn.border:SetSize(iconBtn:GetWidth() + 7.5, iconBtn:GetHeight() + 7.5)
        iconBtn.border:Hide()
        ItemRefTooltip.icon = iconBtn
    end

    local function HideRefIcon(tip)
        if not tip or not tip.icon then return end
        tip.icon:Hide()
        if tip.icon.border then
            tip.icon.border:Hide()
        end
        if ItemRefTooltipTexture10 then
            ItemRefTooltipTexture10:Hide()
        end
    end

    local function ParseRefLink(link)
        if type(link) ~= "string" or link == "" then return nil, nil end
        local inner = match(link, "|H([^|]+)|h") or link
        local kind, id = match(inner, "^([%w]+):(%d+)")
        return kind, tonumber(id)
    end

    local function TextureForRef(kind, id, fallbackLink)
        if not kind and fallbackLink then
            kind, id = ParseRefLink(fallbackLink)
        end
        if not kind or not id then return nil, false end
        if kind == "item" then
            return GetItemIcon(id), false
        end
        if kind == "spell" or kind == "enchant" then
            return select(3, GetSpellInfo(id)), false
        end
        if kind == "achievement" and GetAchievementInfo then
            return select(10, GetAchievementInfo(id)), true
        end
        return nil, false
    end

    local function ShowRefIcon(tip, texture, showBorder)
        if not tip or not tip.icon then return end
        if not texture then
            HideRefIcon(tip)
            return
        end
        -- Texture10 is not present on WotLK ItemRefTooltip; never use it as the visible icon.
        if ItemRefTooltipTexture10 then
            ItemRefTooltipTexture10:Hide()
        end
        tip.icon:SetNormalTexture(texture)
        tip.icon:Show()
        if tip.icon.border then
            if showBorder then
                tip.icon.border:Show()
            else
                tip.icon.border:Hide()
            end
        end
    end

    local function ApplyRefIcon(tip, link)
        if not IsChatTooltipIconsEnabled() or not tip or not tip.icon then
            HideRefIcon(tip)
            return
        end
        if type(link) == "string" then
            tip._suiRefLink = link
        else
            link = tip._suiRefLink
        end

        local texture, showBorder
        -- Prefer live tooltip contents when they exist (GetItem can still be nil for uncached items).
        local itemLink = tip.GetItem and select(2, tip:GetItem())
        if itemLink then
            texture = GetItemIcon(itemLink)
            showBorder = false
        else
            local spellName, spellRank, spellID
            if tip.GetSpell then
                spellName, spellRank, spellID = tip:GetSpell()
            end
            if spellID then
                texture = select(3, GetSpellInfo(spellID))
                showBorder = false
            elseif spellName then
                texture = select(3, GetSpellInfo(spellName, spellRank))
                showBorder = false
            end
        end
        if not texture then
            local kind, id = ParseRefLink(link)
            texture, showBorder = TextureForRef(kind, id, link)
        end
        ShowRefIcon(tip, texture, showBorder)
    end

    RefreshRefIcon = function() ApplyRefIcon(ItemRefTooltip, ItemRefTooltip._suiRefLink) end

    ItemRefTooltip:HookScript('OnTooltipSetItem', function(self)
        ApplyRefIcon(self, self._suiRefLink)
    end)

    ItemRefTooltip:HookScript('OnTooltipSetSpell', function(self)
        ApplyRefIcon(self, self._suiRefLink)
    end)

    if ItemRefTooltip.HasScript and ItemRefTooltip:HasScript("OnTooltipSetAchievement") then
        ItemRefTooltip:HookScript("OnTooltipSetAchievement", function(self, ...)
            local passed = ...
            ApplyRefIcon(self, (type(passed) == "string" and passed) or self._suiRefLink)
        end)
    end

    ItemRefTooltip:HookScript('OnTooltipCleared', function(self)
        HideRefIcon(self)
    end)

    -- Store the link BEFORE SetHyperlink fills the tooltip, otherwise OnTooltipSetItem
    -- still sees the previous click when GetItem()/GetSpell() are nil (common on WotLK).
    if not ItemRefTooltip._suiHyperlinkHooked then
        ItemRefTooltip._suiHyperlinkHooked = true
        local origSetHyperlink = ItemRefTooltip.SetHyperlink
        ItemRefTooltip.SetHyperlink = function(self, link, ...)
            if type(link) == "string" then
                self._suiRefLink = link
            end
            local a, b, c = origSetHyperlink(self, link, ...)
            ApplyRefIcon(self, link)
            return a, b, c
        end
    end

    hooksecurefunc("SetItemRef", function(link)
        if not ItemRefTooltip then return end
        if type(link) == "string" then
            ItemRefTooltip._suiRefLink = link
        end
        if not IsChatTooltipIconsEnabled() then
            HideRefIcon(ItemRefTooltip)
            return
        end
        if not ItemRefTooltip:IsShown() then
            HideRefIcon(ItemRefTooltip)
            return
        end
        ApplyRefIcon(ItemRefTooltip, link)

        if ItemRefTooltip.icon and ItemRefTooltip.icon:IsShown()
            and ItemRefTooltipTextLeft1 and ItemRefCloseButton then
            local textRight = ItemRefTooltipTextLeft1:GetRight()
            local closeLeft = ItemRefCloseButton:GetLeft()
            if textRight and closeLeft and closeLeft <= textRight then
                ItemRefTooltip:SetWidth(ItemRefTooltip:GetWidth() + (textRight - closeLeft))
            end
        end
    end)
end

-- Функция включения иконок в тултипе
local function EnableTooltipIcons()
    InitializeTooltipIcons()
    if RefreshRefIcon and ItemRefTooltip:IsShown() then RefreshRefIcon() end
end

-- Функция отключения иконок в тултипе
local function DisableTooltipIcons()
    -- Скрываем иконку если она есть
    if ItemRefTooltip and ItemRefTooltip.icon then
        ItemRefTooltip.icon:Hide()
        if ItemRefTooltip.icon.border then
            ItemRefTooltip.icon.border:Hide()
        end
    end
    
    -- Скрываем текстуру ItemRefTooltipTexture10
    if ItemRefTooltipTexture10 then
        ItemRefTooltipTexture10:Hide()
    end
    
    -- Восстанавливаем оригинальные позиции текста
    if ItemRefTooltipTextLeft1 then
        ItemRefTooltipTextLeft1:ClearAllPoints()
        ItemRefTooltipTextLeft1:SetPoint("TOPLEFT", ItemRefTooltip, "TOPLEFT", 8, -10)
    end
    
    if ItemRefTooltipTextLeft2 then
        ItemRefTooltipTextLeft2:ClearAllPoints()
        ItemRefTooltipTextLeft2:SetPoint("TOPLEFT", ItemRefTooltipTextLeft1, "BOTTOMLEFT", 0, -2)
    end
    

end


-- ItemRefTooltip is separate from the default GameTooltip moved by position.lua.
local originalPoint
local positionHooksInstalled = false
local petBarTracker
local positionEvents = { "PET_BAR_SHOW", "PET_BAR_HIDE", "PET_BAR_UPDATE", "UNIT_PET",
    "PLAYER_ENTERING_WORLD", "PET_DISMISS_START", "PET_DISMISS_STOP" }

local function PositionEnabled()
    return module:IsEnabled() and module:GetChatTooltipDB().tooltipPositionEnabled == 1
end

local function RestorePosition()
    if originalPoint then
        ItemRefTooltip:ClearAllPoints()
        ItemRefTooltip:SetPoint(unpack(originalPoint))
        originalPoint = nil
    end
end

local function UpdatePosition()
    if not PositionEnabled() or not ItemRefTooltip:IsShown() then return end
    if not originalPoint then
        local p, r, rp, x, y = ItemRefTooltip:GetPoint(1)
        originalPoint = { p or "BOTTOMRIGHT", r or UIParent, rp or "BOTTOMRIGHT", x or 0, y or 0 }
    end
    local db = module:GetChatTooltipDB()
    local offset = PetActionBarFrame and PetActionBarFrame:IsVisible() and db.tooltipPetOffset or db.tooltipBaseOffset
    ItemRefTooltip:ClearAllPoints()
    ItemRefTooltip:SetPoint(originalPoint[1], originalPoint[2], originalPoint[3], originalPoint[4], originalPoint[5] + (tonumber(offset) or 0))
end

local function ApplyPosition()
    if not PositionEnabled() then
        RestorePosition()
        if petBarTracker then petBarTracker:UnregisterAllEvents(); petBarTracker:Hide() end
        return
    end
    if not positionHooksInstalled then
        positionHooksInstalled = true
        ItemRefTooltip:HookScript("OnShow", UpdatePosition)
        ItemRefTooltip:HookScript("OnHide", RestorePosition)
        petBarTracker = CreateFrame("Frame", nil, ItemRefTooltip)
        petBarTracker:SetScript("OnEvent", UpdatePosition)
        local elapsedTotal, lastPetState = 0, nil
        petBarTracker:SetScript("OnUpdate", function(_, elapsed)
            elapsedTotal = elapsedTotal + elapsed
            if elapsedTotal < 0.5 then return end
            elapsedTotal = 0
            local shown = PetActionBarFrame and PetActionBarFrame:IsVisible() or false
            if shown ~= lastPetState then lastPetState = shown; UpdatePosition() end
        end)
    end
    for _, event in ipairs(positionEvents) do petBarTracker:RegisterEvent(event) end
    petBarTracker:Show()
    UpdatePosition()
end

function module:ApplyChatTooltipSettings()
    if not ItemRefTooltip then return end
    ApplyPosition()
    if IsChatTooltipIconsEnabled() then EnableTooltipIcons() else DisableTooltipIcons() end
end
