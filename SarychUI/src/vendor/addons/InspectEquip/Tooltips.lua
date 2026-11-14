local IE = SarychUI.InspectEquip
local L = LibStub("AceLocale-3.0"):GetLocale("SarychUI_InspectEquip")
local tips = {}
local names = {"GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "ShoppingTooltip3",
    "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2", "ItemRefShoppingTooltip3", "AtlasLootTooltip"}

function IE:AddToTooltip(tip, link)
    if not self.enabled or not link then return end
    local state = tips[tip]
    if not state or state.link == link then return end
    local sources = self:FindItem(link)
    if not sources then return end
    state.link = link
    for _, entry in ipairs(sources) do
        local text = entry[1]
        if entry[2] then text = text .. ": " .. entry[2] end
        if entry[3] then text = text .. " (" .. entry[3] .. ")" end
        if entry[4] then text = text .. ": " .. entry[4] end
        if entry[5] and entry[5] ~= 0 then text = text .. " (" .. entry[5] .. ")" end
        if entry[6] then text = text .. " (" .. entry[6] .. ")" end
        tip:AddDoubleLine(L["Source"] .. ":", text, 1, .75, 0, 1, .75, 0)
        local name, index = tip:GetName(), tip:NumLines()
        state[#state + 1] = {left = name and _G[name .. "TextLeft" .. index],
            right = name and _G[name .. "TextRight" .. index], text = text}
    end
    tip:Show()
end

local function OnItem(tip)
    if not IE.enabled then return end
    local _, link = tip:GetItem()
    IE:AddToTooltip(tip, link)
end

function IE:HookTooltips()
    for _, name in ipairs(names) do
        local tip = _G[name]
        if tip and not tips[tip] then
            tips[tip] = {}
            tip:HookScript("OnTooltipSetItem", OnItem)
            tip:HookScript("OnTooltipCleared", function(self)
                if not IE.enabled then return end
                local state = tips[self]
                for key in pairs(state) do state[key] = nil end
            end)
            if tip.SetHyperlinkCompareItem then hooksecurefunc(tip, "SetHyperlinkCompareItem", OnItem) end
        end
    end
end

function IE:RefreshTooltips()
    for tip in pairs(tips) do if tip:IsShown() then OnItem(tip) end end
end

function IE:ClearTooltips()
    for tip, state in pairs(tips) do
        local changed = false
        for _, line in ipairs(state) do
            if line.right and line.right:GetText() == line.text then
                line.right:SetText("")
                if line.left then line.left:SetText("") end
                changed = true
            end
        end
        if changed then tip:Hide() end
        tips[tip] = {}
    end
end
