local feature = SarychUI.LootRolls
local quality = 2
local selectedItem
local function Refresh()
    if SarychUI.RefreshConfig then SarychUI:RefreshConfig() end
end
local function Settings()
    local _, db = feature:GetDB()
    return db
end
local function Quality() return Settings().loot_settings[quality] end
local function Toggle(name, order, get, set, disabled)
    return { type = "toggle", name = name, order = order, get = get,
        set = function(_, value) set(value); Refresh() end, disabled = disabled }
end

function feature:GetOptions()
    local general = {
        quality = { type = "select", name = "ui.text_93adcfb1", order = 1,
            values = { __order = { 2, 3, 4 },
                [2] = "|cff1eff00" .. SarychUI:T("ui.options_5e429287e7") .. "|r",
                [3] = "|cff0070dd" .. SarychUI:T("ui.options_359312f824") .. "|r",
                [4] = "|cffa335ee" .. SarychUI:T("ui.options_d128a802a7") .. "|r" },
            get = function() return quality end,
            set = function(_, value) quality = value; Refresh() end },
    }
    local fields = {
        { "enabled", SarychUI:T("ui.options_ce8bb52ac4") },
        { "only_boe", SarychUI:T("ui.options_6bd1bdda6e") },
        { "need_looter", SarychUI.L["Loot_Need"] }, { "greed_looter", SarychUI.L["Loot_Greed"] }, { "disenchant_looter", SarychUI.L["Loot_Disenchant"] },
    }
    for i, entry in ipairs(fields) do
        local key = entry[1]
        general[key] = Toggle(entry[2], i + 1, function() return Quality()[key] end,
            function(value)
                local db = Quality()
                db[key] = value
                if key == "only_boe" then
                    -- Drop an incompatible mode when the item scope is changed explicitly.
                    if value then db.smart_disenchant.without_dis = false
                    else db.smart_disenchant.only_boe = false end
                end
            end,
            function()
                if key == "enabled" then return false end
                return not Quality().enabled
            end)
    end
    general.qualityRules = { type = "group", name = "ui.text_58faff2e", inline = true,
        order = 2, args = {
            enabled = general.enabled,
            only_boe = general.only_boe,
        } }
    general.enabled = nil
    general.only_boe = nil
    local rollActions = {}
    for _, entry in ipairs({
        { "need_looter", "UI-GroupLoot-Dice-Up" },
        { "greed_looter", "UI-GroupLoot-Coin-Up" },
        { "disenchant_looter", "UI-GroupLoot-DE-Up" },
    }) do
        local key, texture = entry[1], entry[2]
        local option = general[key]
        option.name = "|TInterface\\Buttons\\" .. texture .. ":18:18:0:0|t " .. option.name
        rollActions[key] = option
        general[key] = nil
    end
    general.rollActions = { type = "group", name = "ui.text_f7556aae", inline = true,
        order = 5, args = rollActions }
    local smart = {}
    for i, entry in ipairs({
        { "without_dis", SarychUI:T("ui.options_8ba0377777") },
        { "only_boe", SarychUI:T("ui.options_befe4d1d0d") },
    }) do
        local key = entry[1]
        smart[key] = Toggle(entry[2], i, function() return Quality().smart_disenchant[key] end,
            function(value)
                local settings = Quality()
                local db = settings.smart_disenchant
                if value then
                    for k in pairs(db) do db[k] = false end
                    if key == "without_dis" then settings.only_boe = false
                    elseif key == "only_boe" then settings.only_boe = true end
                end
                db[key] = value
            end,
            function()
                local db = Quality()
                return not db.enabled or not db.disenchant_looter
            end)
    end
    general.smart = { type = "group", name = "ui.text_7991228e", inline = true, order = 10, args = smart }
    general.priority = { type = "description", name = "ui.text_a5c82c15", order = 11 }

    local actions = { ignore = SarychUI:T("ui.options_5ec7b0f52b"), need = SarychUI.L["Loot_Need"], greed = SarychUI.L["Loot_Greed"], disenchant = SarychUI.L["Loot_Disenchant"], pass = SarychUI.L["Loot_Pass"] }
    local exceptions = {
        add = { type = "input", name = "ui.id_4a4df58f", order = 1, width = "full",
            get = function() return "" end,
            set = function(_, value)
                local id = tonumber(value:match("item:(%d+)")) or tonumber(value)
                if id and id > 0 and id == math.floor(id) then
                    local items = Settings().exception_list.items
                    items[id] = items[id] or "ignore"
                    selectedItem = id
                    Refresh()
                end
            end },
        item = { type = "select", name = "ui.text_47703f98", order = 2, width = "full",
            values = function()
                local values = { __order = {} }
                for id in pairs(Settings().exception_list.items) do
                    values.__order[#values.__order + 1] = id
                    values[id] = (GetItemInfo(id) or tostring(id)) .. " (" .. id .. ")"
                end
                table.sort(values.__order)
                return values
            end,
            get = function() return selectedItem end,
            set = function(_, value) selectedItem = value; Refresh() end },
        action = { type = "select", name = "ui.text_6b53aafe", order = 3, values = actions,
            disabled = function() return not Settings().exception_list.items[selectedItem] end,
            get = function() return Settings().exception_list.items[selectedItem] end,
            set = function(_, value)
                if selectedItem then Settings().exception_list.items[selectedItem] = value; Refresh() end
            end },
        remove = { type = "execute", name = "ui.delete_be99b136", order = 4,
            disabled = function() return not Settings().exception_list.items[selectedItem] end,
            func = function()
                if selectedItem then Settings().exception_list.items[selectedItem] = nil end
                selectedItem = nil; Refresh()
            end },
    }
    local enabled = { type = "toggle", name = "ui.enable_a54eaf37", order = 1,
        get = function() return feature:GetDB().lootRollsEnabled end,
        set = function(_, value) feature:SetEnabled(value) end }
    local function Hidden() return not feature:GetDB().lootRollsEnabled end
    local function Tab(name, order, controls)
        return { type = "group", name = name, order = order, hidden = Hidden, args = controls }
    end
    return { type = "group", name = "ui.text_1e18147a", order = 8,
        childGroups = "tab", suiTopControlsAboveSubtabs = true,
        args = {
            title = { type = "header", name = "ui.text_b2f73031", order = 0 },
            enabled = enabled,
            general = Tab(SarychUI:T("ui.main_11355a29"), 2, general),
            exceptions = Tab(SarychUI:T("ui.options_ea65534c79"), 3, exceptions),
        } }
end
