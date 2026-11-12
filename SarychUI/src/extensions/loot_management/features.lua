local module = SarychUI.modules.loot_management
-- Runtime owned by loot_management; legacy tools profile keys are preserved.
local moduleName = "tools"
local S = {}
local function DB()
    if not SarychUI or not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules then
        return nil
    end
    return SarychUI.db.profile.modules[moduleName]
end

S.lootFramesHooked, S.lootFrameHooks, S.lootDefaultPositions = false, {}, {}

local function ReanchorGroupLoot()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or db.enableLootReanchor ~= 1 then return end

    local startX = db.lootStartX or 0
    local startY = db.lootStartY or 150
    local spacing = db.lootSpacing or 8
    local lastFrame
    local maxFrames = NUM_GROUP_LOOT_FRAMES or 4

    for i = 1, maxFrames do
        local frame = _G["GroupLootFrame"..i]
        if frame and frame:IsShown() then
            -- Save default position before first modification (only once)
            if not S.lootDefaultPositions[i] then
                local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
                if point then
                    S.lootDefaultPositions[i] = {point, relativeTo, relativePoint, xOfs, yOfs}
                end
            end

            frame:ClearAllPoints()
            if not lastFrame then
                frame:SetPoint("BOTTOM", UIParent, "BOTTOM", startX, startY)
            else
                frame:SetPoint("BOTTOM", lastFrame, "TOP", 0, spacing)
            end
            lastFrame = frame
        end
    end
end

function SarychUI.modules.loot_management:ApplyLootReanchor()
    local db = DB()
    if not db then return end

    if db.enableLootReanchor == 1 then
        SarychUI.modules.loot_management:EnableLootReanchor()
    else
        SarychUI.modules.loot_management:DisableLootReanchor()
    end
end

function SarychUI.modules.loot_management:EnableLootReanchor()
    local db = DB()
    if not db then return end

    if not S.lootFramesHooked then
        local maxFrames = NUM_GROUP_LOOT_FRAMES or 4
        for i = 1, maxFrames do
            local f = _G["GroupLootFrame"..i]
            if f then
                -- Store original hooks if they exist (only once)
                if not S.lootFrameHooks[i] then
                    S.lootFrameHooks[i] = {
                        origOnShow = f:GetScript("OnShow"),
                        origOnHide = f:GetScript("OnHide")
                    }
                end

                -- Create wrapper functions that call original + our function
                local wrapperOnShow = function(self, ...)
                    if S.lootFrameHooks[i] and S.lootFrameHooks[i].origOnShow then
                        S.lootFrameHooks[i].origOnShow(self, ...)
                    end
                    ReanchorGroupLoot()
                end

                local wrapperOnHide = function(self, ...)
                    if S.lootFrameHooks[i] and S.lootFrameHooks[i].origOnHide then
                        S.lootFrameHooks[i].origOnHide(self, ...)
                    end
                    ReanchorGroupLoot()
                end

                -- Set our wrappers
                f:SetScript("OnShow", wrapperOnShow)
                f:SetScript("OnHide", wrapperOnHide)
            end
        end

        S.lootFramesHooked = true

        -- Apply immediately if frames are shown
        ReanchorGroupLoot()
    end
end

function SarychUI.modules.loot_management:DisableLootReanchor()
    if not S.lootFramesHooked then return end

    local maxFrames = NUM_GROUP_LOOT_FRAMES or 4
    for i = 1, maxFrames do
        local f = _G["GroupLootFrame"..i]
        if f and S.lootFrameHooks[i] then
            -- Restore original hooks - Blizzard will restore default positioning
            -- on next frame show automatically
            f:SetScript("OnShow", S.lootFrameHooks[i].origOnShow)
            f:SetScript("OnHide", S.lootFrameHooks[i].origOnHide)

            -- If frame is currently shown, hide and show it again to trigger
            -- original OnShow which will restore default Blizzard positioning
            if f:IsShown() then
                f:Hide()
                f:Show()
            end
        end
    end

    -- Don't clear S.lootDefaultPositions - keep them for potential re-enabling
    -- Clear hooks storage
    S.lootFrameHooks = {}
    S.lootFramesHooked = false
end

function SarychUI.modules.loot_management:ApplyLootRollCounts()
    local db = DB()
    local lrc = _G.SarychUI_LootRollCounts
    if not lrc then return end
    local enabledFlag = db and db.enableLootRollCounts
    if not db or enabledFlag == false or enabledFlag == 0 then
        lrc.Disable()
        return
    end
    lrc.Enable()
end

-- Adaptive Blizzard loot window. Item actions and pagination remain Blizzard-owned.
local adaptiveLoot = { active = false, buttons = 0 }
local function RestoreAdaptiveLoot()
    local state = adaptiveLoot
    if not state.height then return end
    LOOTFRAME_NUMBUTTONS = state.count
    LootFrame:SetHeight(state.height)
    for i = state.count + 1, state.buttons do
        local button = _G["LootButton" .. i]
        if button then button:Hide() end
    end
    for _, entry in ipairs(state.regions) do
        if entry.shown then entry.region:Show() else entry.region:Hide() end
    end
    if state.title then
        state.title:ClearAllPoints()
        for _, point in ipairs(state.titlePoints) do state.title:SetPoint(unpack(point)) end
    end
    for _, texture in ipairs(state.textures) do texture:Hide() end
    LootFrame.page = 1
    if LootFrame:IsShown() then LootFrame_Update() end
end

local function ResizeLootWindow()
    local state = adaptiveLoot
    if not state.active or not LootFrame:IsShown() then return end
    local count = math.max(0, GetNumLootItems() or 0)
    local step = LootButton1:GetHeight() + 4
    local base = state.height - state.count * step
    local available = UIParent:GetHeight() * UIParent:GetEffectiveScale() / LootFrame:GetEffectiveScale() - 40
    local capacity = math.max(2, math.floor((available - base) / step))
    local db = SarychUI.db.profile.modules.loot_management
    local maxItems = math.max(2, math.min(20, math.floor(tonumber(db.lootMaxItems) or 12)))
    -- Blizzard reserves one row for navigation when there is another page.
    capacity = math.min(capacity, maxItems + (count > maxItems and 1 or 0))
    local rows = math.max(1, math.min(count, capacity))
    for i = 1, rows do
        local button = _G["LootButton" .. i]
        if not button then
            button = CreateFrame("Button", "LootButton" .. i, LootFrame, "LootButtonTemplate")
            button:SetID(i)
            button:SetPoint("TOP", _G["LootButton" .. (i - 1)], "BOTTOM", 0, -4)
        end
    end
    state.buttons = math.max(state.buttons, rows)
    for i = rows + 1, state.buttons do _G["LootButton" .. i]:Hide() end
    LOOTFRAME_NUMBUTTONS = rows
    LootFrame:SetHeight(base + rows * step)
    for _, entry in ipairs(state.regions) do entry.region:Hide() end
    for _, texture in ipairs(state.textures) do texture:Show() end
    if state.title then
        state.title:ClearAllPoints()
        state.title:SetPoint("TOP", LootFrame, "TOP", -12, -19.5)
    end
    LootFrame.page = 1
    LootFrame_Update()
end

function module:ApplyAdaptiveLootFrame(forceOff)
    local db = SarychUI.db.profile.modules.loot_management
    local enable = not forceOff and db and db.enabled ~= false and db.adaptiveLootFrame == true
    local state = adaptiveLoot
    if not enable then
        if state.active then state.active = false; RestoreAdaptiveLoot() end
        return
    end
    if not LootFrame or not LootButton1 then return end
    if not state.height then
        state.height, state.count = LootFrame:GetHeight(), LOOTFRAME_NUMBUTTONS
        state.buttons, state.regions, state.textures = state.count, {}, {}
        local path = "Interface\\LootFrame\\UI-LootPanel"
        for _, region in ipairs({ LootFrame:GetRegions() }) do
            if region.GetTexture and region:GetTexture() == path then
                state.regions[#state.regions + 1] = { region = region, shown = region:IsShown() }
            elseif region.GetText and region:GetText() == ITEMS then
                state.title, state.titlePoints = region, {}
                for i = 1, region:GetNumPoints() do
                    state.titlePoints[i] = { region:GetPoint(i) }
                end
            end
        end
        -- Slice the native artwork so borders keep their original dimensions.
        for i, crop in ipairs({ {0, 78 / 256}, {78 / 256, 238 / 256}, {238 / 256, 1} }) do
            local texture = LootFrame:CreateTexture(nil, "ARTWORK")
            texture:SetTexture(path)
            texture:SetTexCoord(0, 1, crop[1], crop[2])
            texture:SetWidth(LootFrame:GetWidth())
            state.textures[i] = texture
        end
        local top, middle, bottom = unpack(state.textures)
        top:SetHeight(78); top:SetPoint("TOP", LootFrame, "TOP")
        bottom:SetHeight(18); bottom:SetPoint("BOTTOM", LootFrame, "BOTTOM")
        middle:SetPoint("TOP", top, "BOTTOM"); middle:SetPoint("BOTTOM", bottom, "TOP")
        for _, texture in ipairs(state.textures) do texture:Hide() end
        hooksecurefunc("LootFrame_Show", ResizeLootWindow)
        LootFrame:HookScript("OnHide", function()
            if state.active then RestoreAdaptiveLoot() end
        end)
    end
    state.active = true
    ResizeLootWindow()
end
