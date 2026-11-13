local DT = _G.SarychUI_ChatDataTexts
local L = DT.L

function DT:HasKind(name)
    for _, slot in ipairs(self.slots) do
        if slot.kind == name then return true end
    end
    return false
end

local function PerformanceTooltip(self)
    if not DT:SetupTooltip(self) then return end
    local tip = DT.tooltip
    if self.data.name == "FPS" then
        tip:AddLine(FRAMERATE_LABEL or "FPS")
        tip:AddDoubleLine("FPS", string.format("%.1f", GetFramerate()), 1, 1, 1, 1, 1, 1)
    elseif self.data.name == "MS" then
        local down, up, latency = GetNetStats()
        tip:AddLine(L["Latency"])
        tip:AddDoubleLine("MS", tostring(latency or 0), 1, 1, 1, 1, 1, 1)
        tip:AddDoubleLine(L["Download"], string.format("%.2f KB/s", down or 0), 1, 1, 1, 1, 1, 1)
        tip:AddDoubleLine(L["Upload"], string.format("%.2f KB/s", up or 0), 1, 1, 1, 1, 1, 1)
    else
        local total = DT.RefreshMemory and DT.RefreshMemory() or 0
        tip:AddDoubleLine(L["Memory"], string.format("%.1f MB", total))
        local addons = {}
        for i = 1, GetNumAddOns() do
            local usage = GetAddOnMemoryUsage(i) or 0
            if usage > 0 then
                local name, title = GetAddOnInfo(i)
                addons[#addons + 1] = {title or name, usage}
            end
        end
        table.sort(addons, function(a, b) return a[2] > b[2] end)
        for i = 1, math.min(30, #addons) do
            local addon = addons[i]
            local amount = addon[2] >= 1024 and string.format("%.2f MB", addon[2] / 1024)
                or string.format("%.0f KB", addon[2])
            tip:AddDoubleLine(addon[1], amount, 1, 1, 1, 1, 1, 1)
        end
        if #addons > 30 then tip:AddLine(string.format(L["More addons: %d"], #addons - 30), 0.7, 0.7, 0.7) end
    end
    tip:Show()
end
for _, name in ipairs({"FPS", "MS", "Memory"}) do
    DT:RegisterDatatext(name, nil, nil, nil, nil, PerformanceTooltip, nil, L[name])
end

-- ElvUI's configuration shortcut is adapted to the host addon's own options.
DT:RegisterDatatext("SarychUI Config", nil, function(self) self.text:SetText("SarychUI") end,
    nil, function(_, button)
        if button == "RightButton" and IsShiftKeyDown() then ReloadUI()
        else SarychUI:ToggleCustomOptions() end
    end, function(self)
        if not DT:SetupTooltip(self) then return end
        DT.tooltip:AddLine("SarychUI")
        DT.tooltip:AddDoubleLine(L["Left Click:"], L["Toggle Configuration"], 1, 1, 1)
        DT.tooltip:AddDoubleLine(L["Hold Shift + Right Click:"], L["Reload UI"], 1, 1, 1)
        DT.tooltip:Show()
    end, nil, L["SarychUI Config"])
