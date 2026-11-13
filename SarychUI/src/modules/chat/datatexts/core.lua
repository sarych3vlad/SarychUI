-- Standalone host for the Wrath ElvUI datatexts adapted in this directory.
-- One provider per kind: choosing the same kind twice must not count events twice.
local DT = {registered = {}, providers = {}, slots = {}}
_G.SarychUI_ChatDataTexts = DT
local E = {valueColorUpdateFuncs = {}, UIParent = UIParent, noop = function() end}
DT.Engine = E
DT.L = setmetatable({}, {__index = function(_, key)
    local value = SarychUI.L and SarychUI.L["ChatData_" .. key]
    return value or key
end})
E.db = {datatexts = {timeFormat = "%H:%M", dateFormat = "", realmTime = true,
    goldCoins = true, friends = {hideAFK = false, hideDND = false}}}

function E:RefreshPlayer()
    self.myname, self.myrealm = UnitName("player"), GetRealmName()
    self.myclass = select(2, UnitClass("player"))
    self.myrace = select(2, UnitRace("player"))
    self.mylevel = UnitLevel("player")
    self.myfaction = UnitFactionGroup("player")
    local spec, most = 0, 0
    for i = 1, 3 do
        local _, _, points = GetTalentTabInfo(i)
        if (points or 0) > most then spec, most = i, points end
    end
    local class = self.myclass
    self.Role = (class == "MAGE" or class == "PRIEST" or class == "WARLOCK"
        or class == "PALADIN" and spec == 1
        or class == "SHAMAN" and (spec == 1 or spec == 3)
        or class == "DRUID" and (spec == 1 or spec == 3)) and "Caster" or "Melee"
end

function E:ColorGradient(value)
    value = math.max(0, math.min(1, value))
    return math.min(1, 2 - value * 2), math.min(1, value * 2), 0
end

function E:FormatMoney(amount)
    return (amount < 0 and "-" or "") .. GetMoneyString(math.abs(amount))
end

function E:UnlocalizedClassName(name)
    for token, localized in pairs(LOCALIZED_CLASS_NAMES_MALE) do
        if localized == name then return token end
    end
    for token, localized in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
        if localized == name then return token end
    end
end

function DT:RegisterDatatext(name, events, event, update, click, enter, leave, label)
    self.registered[name] = {name = name, events = events, event = event,
        update = update, click = click, enter = enter, leave = leave, label = label or name}
end

function DT:GetValues()
    local values = {NONE = DT.L["None"], FPS = "FPS", MS = "MS", Memory = DT.L["Memory"]}
    for name, data in pairs(self.registered) do
        values[name] = SarychUI.L and SarychUI.L["ChatData_" .. name] or data.label
    end
    return values
end

function DT:SetSlotText(slot, text)
    if slot.textEnabled == false and type(text) == "string" then
        -- Imported values use "label: |cAARRGGBBvalue". Strip only that label;
        -- clock separators, coordinates, coin textures and status text stay intact.
        text = text:match("^.-:%s+(|c%x%x%x%x%x%x%x%x.*)$") or text
    end
    slot.text:SetText(text)
end

function DT:IsHovered(provider)
    return self.hoveredSlot and self.hoveredSlot.provider == provider
        and self.hoveredSlot.tooltipEnabled and self.hoveredSlot:IsShown()
end

function DT:SetupTooltip(provider)
    if not self:IsHovered(provider) then return false end
    if not self.tooltip then
        self.tooltip = CreateFrame("GameTooltip", "SarychUIChatDataTooltip", UIParent, "GameTooltipTemplate")
        self.tooltip:SetFrameStrata("TOOLTIP")
    end
    self.tooltip:Hide()
    self.tooltip:SetOwner(self.hoveredSlot, "ANCHOR_TOPLEFT")
    self.tooltip:ClearLines()
    return true
end

function DT:Leave(slot)
    if slot and self.hoveredSlot ~= slot then return end
    local hovered = self.hoveredSlot
    self.hoveredSlot = nil
    if hovered and hovered.provider and hovered.provider.data.leave then
        hovered.provider.data.leave(hovered.provider)
    end
    if self.tooltip then self.tooltip:Hide() end
end

function DT:Enter(slot)
    self:Leave()
    if not slot.tooltipEnabled or slot.kind == "NONE" then return end
    self.hoveredSlot = slot
    local provider = slot.provider
    if provider and provider.data.enter then
        provider.data.enter(provider)
    elseif self:SetupTooltip(provider) then
        self.tooltip:AddLine(self:GetValues()[slot.kind] or slot.kind)
        self.tooltip:AddLine(provider and provider.value or slot.text:GetText() or "", 1, 1, 1)
        self.tooltip:Show()
    end
end

function DT:Stop()
    self:Leave()
    for _, provider in pairs(self.providers) do
        provider:UnregisterAllEvents()
        provider:SetScript("OnUpdate", nil)
        provider:Hide()
        provider.slots = {}
        provider.active = false
    end
end

-- Switching Alt only rebinds the visible regions. Both configured providers
-- keep their state (for example combat time and session gold) until deselected.
function DT:SetAltState(pressed)
    local changed = false
    for _, slot in ipairs(self.slots) do
        local name = pressed and slot.altEnabled and slot.altKind or slot.baseKind
        if slot.kind ~= name then changed = true; break end
    end
    if not changed then return false end
    self:Leave()
    for _, provider in pairs(self.providers) do wipe(provider.slots) end
    for _, slot in ipairs(self.slots) do
        slot.kind = pressed and slot.altEnabled and slot.altKind or slot.baseKind
        slot.provider = self.providers[slot.kind]
        slot.text:SetTextColor(1, 1, 1, 0.8)
        slot:EnableMouse(slot.kind ~= "NONE")
        if slot.provider then
            table.insert(slot.provider.slots, slot)
            self:SetSlotText(slot, slot.provider.value or "")
        else
            slot.text:SetText("")
        end
    end
    return true
end

function DT:Apply(frame, db)
    local previous = {}
    for name, provider in pairs(self.providers) do
        if provider.active then previous[name] = {update = provider:GetScript("OnUpdate")} end
    end
    self:Stop()
    self.slots = frame.slots
    self.altConfigured = false
    E:RefreshPlayer()
    local global = SarychUI.db.global
    global.chatDataTexts = global.chatDataTexts or {}
    self.goldDB = global.chatDataTexts
    if not self.colorsReady then
        for callback in pairs(E.valueColorUpdateFuncs) do callback("|cffffffff") end
        self.colorsReady = true
    end
    local defaults = {left = "Memory", middle = "MS", right = "FPS"}
    local wanted = {}
    for _, slot in ipairs(self.slots) do
        local key = "dataBar" .. slot.position:gsub("^%l", string.upper)
        local name = db[key] or defaults[slot.position]
        if name ~= "NONE" and not self.registered[name] then name = defaults[slot.position] end
        slot.baseKind = name
        slot.altEnabled = db[key .. "AltEnabled"] == true or db[key .. "AltEnabled"] == 1
        local altName = db[key .. "Alt"]
        if altName ~= "NONE" and not self.registered[altName] then altName = name end
        slot.altKind = altName
        if slot.altEnabled then self.altConfigured = true; wanted[altName] = true end
        wanted[name] = true
        slot.tooltipEnabled = db[key .. "Tooltip"] ~= false
            and db[key .. "Tooltip"] ~= 0
        slot.textEnabled = db[key .. "Text"] ~= false
            and db[key .. "Text"] ~= 0
        slot.kind, slot.provider = nil, nil
        slot:SetScript("OnEnter", function(s) DT:Enter(s) end)
        slot:SetScript("OnLeave", function(s) DT:Leave(s) end)
        slot:SetScript("OnHide", function(s) DT:Leave(s) end)
        slot:SetScript("OnClick", function(s, button)
            local p = s.provider
            if p and p.data.click and not InCombatLockdown() then p.data.click(p, button) end
        end)
    end
    for name in pairs(wanted) do
        local data = self.registered[name]
        if data and not self.providers[name] then
            local provider = CreateFrame("Frame", nil, frame)
            provider.data, provider.slots = data, {}
            -- A text sink broadcasts each computed value to all visible regions.
            provider.text = {SetText = function(_, text)
                provider.value = text
                for _, target in ipairs(provider.slots) do DT:SetSlotText(target, text) end
            end}
            provider.text.SetFormattedText = function(text, fmt, ...)
                text:SetText(string.format(fmt, ...))
            end
            provider:SetScript("OnEnter", function(p, ...)
                if DT:IsHovered(p) and p.data.enter then p.data.enter(p, ...) end
            end)
            self.providers[name] = provider
        end
    end
    local alt = SarychUI.AltMode
    self:SetAltState(alt and alt:IsAltPressed())
    for name, provider in pairs(self.providers) do
        if wanted[name] then
            local data = provider.data
            for _, event in ipairs(data.events or {}) do provider:RegisterEvent(event) end
            provider:RegisterEvent("PLAYER_LEVEL_UP")
            provider:RegisterEvent("PLAYER_TALENT_UPDATE")
            provider:SetScript("OnEvent", function(p, event, ...)
                if event == "PLAYER_LEVEL_UP" or event == "PLAYER_TALENT_UPDATE"
                    or event == "ACTIVE_TALENT_GROUP_CHANGED" then E:RefreshPlayer() end
                if data.event then
                    if event == "PLAYER_LEVEL_UP" or event == "PLAYER_TALENT_UPDATE" then
                        data.event(p, "ELVUI_FORCE_RUN")
                    else data.event(p, event, ...) end
                end
            end)
            provider:Show()
            provider.active = true
            if previous[data.name] then
                provider:SetScript("OnUpdate", previous[data.name].update)
                provider.text:SetText(provider.value)
            else
                provider:SetScript("OnUpdate", data.update)
                if data.event then data.event(provider, "ELVUI_FORCE_RUN") end
                if data.update then data.update(provider, 20000) end
            end
        end
    end
end
