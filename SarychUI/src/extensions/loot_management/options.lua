local SUI = SarychUI
local extension = SUI:RegisterExtension("loot_management", {})
local addonKeys = { "pretty_lootalert", "LootHistory" }
local toolKeys = { "enableLootReanchor", "enableLootRollCounts" }

local function DB()
    local modules = SUI.db.profile.modules
    modules.loot_management = modules.loot_management or { enabled = true }
    return modules.loot_management
end

function extension:Enable()
    if DB().enabled == false then self:Disable(); return end
    self:Applypretty_lootalert()
    self:ApplyLootHistory()
    self:ApplyAdaptiveLootFrame()
    local tools = SUI.modules
    SarychUI.modules.loot_management:ApplyLootReanchor()
    SarychUI.modules.loot_management:ApplyLootRollCounts()
end

function extension:GetOptions()
    local function Refresh()
        if SUI.OptionsCore then SUI.OptionsCore:ScheduleSmartRefresh(true) end
    end
    local args = {
        enabled = {
            type = "toggle", name = "ui.enable_a54eaf37", order = 0,
            get = function() return DB().enabled ~= false end,
            set = function(_, value)
                local db = DB()
                if value == (db.enabled ~= false) then return end
                db.enabled = value and true or false
                if value then extension:Enable() else extension:Disable() end
                db.savedEnabled = db.savedEnabled or {}
                local toolsDB = SUI.db.profile.modules.tools
                for _, key in ipairs(toolKeys) do
                    if value then
                        toolsDB[key] = db.savedEnabled[key]
                    else
                        db.savedEnabled[key] = toolsDB[key]
                        toolsDB[key] = 0
                    end
                end
                extension:Enable()
                if LootHistory_UpdateButtonVisibility then LootHistory_UpdateButtonVisibility() end
                Refresh()
            end,
        },
    }
    for order, key in ipairs(addonKeys) do
        local available = extension["Apply" .. key]
        if available then
            local group = extension["Get" .. key .. "Options"](extension)
            group.name = key == "LootHistory" and SarychUI:T("ui.options_2ecf4bfaf0") or SarychUI:T("ui.options_c3f46b6a25")
            group.order, group.inline = order, true
            local originalSet = group.args.enabled.set
            group.args.enabled.set = function(info, value)
                originalSet(info, value)
                Refresh()
            end
            if key == "pretty_lootalert" then
                local offset = group.args.castbarOffsetEnabled
                offset.name = SarychUI:T("ui.options_464421ba3a")
                local offsetSet = offset.set
                offset.set = function(info, value) offsetSet(info, value); Refresh() end
                local position = group.args.castbarOffsetY
                position.name = SarychUI:T("ui.options_09d695be7c")
                position.suiFullRow = true
                position.hidden = function() return not offset.get() end
                local horizontal = group.args.castbarOffsetX
                horizontal.suiFullRow = true
                horizontal.hidden = position.hidden
            end
            args[key] = group
        end
    end
    args.loot = SarychUI.modules.loot_management:GetLootOptions()
    args.loot.order = 3
    args.adaptiveLoot = {
        type = "group", name = "ui.loot_window", order = 4, inline = true,
        args = {
            enabled = {
                type = "toggle", name = "ui.loot_adaptive_height", width = "full", order = 1,
                get = function() return DB().adaptiveLootFrame == true end,
                set = function(_, value)
                    DB().adaptiveLootFrame = value and true or false
                    extension:ApplyAdaptiveLootFrame()
                end,
            },
            maxItems = {
                type = "range", name = "ui.loot_max_items", order = 2,
                min = 2, max = 20, step = 1, width = "full",
                hidden = function() return DB().adaptiveLootFrame ~= true end,
                get = function() return DB().lootMaxItems or 12 end,
                set = function(_, value)
                    DB().lootMaxItems = value
                    extension:ApplyAdaptiveLootFrame()
                end,
            },
        },
    }
    return { type = "group", name = "ui.text_ed7b24eb", args = args,
        suiBodyDisabled = function() return DB().enabled == false end }
end

function extension:RefreshConfig() self:Enable() end
function extension:Disable()
    self:Applypretty_lootalert(true)
    self:ApplyLootHistory(true)
    self:ApplyAdaptiveLootFrame(true)
    SarychUI.modules.loot_management:DisableLootReanchor()
    local counts = _G.SarychUI_LootRollCounts
    if counts then counts.Disable() end
end

function extension:Initialize()
    local parent = SUI.db.profile.modules.loot_management
    if parent and parent.enabled == false and parent.savedEnabled then
        for _, child in ipairs({"pretty_lootalert","LootHistory"}) do
            if parent.savedEnabled[child] ~= nil then
                SUI.db.profile.addons[child].enabled = parent.savedEnabled[child]
                parent.savedEnabled[child] = nil
            end
        end
    end

    self:Applypretty_lootalert(true)
    self:ApplyLootHistory(true)
end
