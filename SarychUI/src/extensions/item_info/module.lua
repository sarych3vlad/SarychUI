-- One profile/lifecycle owner for equipment metrics and the source catalog.
local module = SarychUI:RegisterExtension("item_info", {})

function module:GetDB()
    local profile = SarychUI.db.profile
    profile.modules.item_info = profile.modules.item_info or {enabled = true}
    local cfg = profile.modules.item_info
    if not cfg.equipmentMigrated then
        local addons = profile.addons or {}
        local score, sources = addons.GearScoreLite, addons.InspectEquip
        local hadScore = cfg.score ~= nil
        if not cfg.score then
            cfg.score = {}
            for key, value in pairs(score and score.settings or {}) do cfg.score[key] = value end
            cfg.score.enabled = not score or score.enabled ~= false
            if cfg.enabled == false and not (score and score.ownerMigrated) then cfg.score.enabled = false end
        end
        cfg.sources = cfg.sources or {enabled = sources and sources.enabled == true or false}
        -- Legacy item_info was only a GS parent; it must not gate enabled sources.
        if not hadScore and (score or sources) then cfg.enabled = cfg.score.enabled or cfg.sources.enabled end
        addons.GearScoreLite, addons.InspectEquip = nil, nil
        cfg.equipmentMigrated = true
    end
    cfg.score = cfg.score or {enabled = true}
    cfg.sources = cfg.sources or {enabled = false}
    for _, key in ipairs({"Player", "Inspect", "Item"}) do
        if cfg.score[key] == nil then cfg.score[key] = 1 end
    end
    if cfg.score.Item == 2 then cfg.score.Item = 1 end
    if cfg.score.ThousandsSeparator == nil then cfg.score.ThousandsSeparator = true end
    if cfg.score.DisplayMode ~= "itemlevel" then cfg.score.DisplayMode = "gearscore" end
    return cfg
end

function module:ApplyEquipment(forceOff)
    local cfg = self:GetDB()
    self.settings = cfg.score
    self.enabled = not forceOff and cfg.enabled ~= false and cfg.enabled ~= 0
    self:ApplyNativeItemLevel()
    if self.Sources then
        if self.enabled and cfg.sources.enabled then self.Sources:Enable()
        else self.Sources:Disable() end
    end
    self:SetEquipmentRuntime(self.enabled and (cfg.score.enabled ~= false or cfg.sources.enabled))
end

function module:Enable() self:ApplyEquipment() end
function module:Disable() self:ApplyEquipment(true) end
function module:RefreshConfig() self:ApplyEquipment() end
function module:Initialize() self:ApplyEquipment(true) end

function module:GetOptions()
    local score = self:GetGearScoreOptions()
    score.order, score.inline = 2, true
    return {type = "group", name = SarychUI:T("ui.equipment.title"),
        suiBodyDisabled = function() return self:GetDB().enabled == false end,
        args = {
        enabled = {type = "toggle", name = SarychUI:T("ui.enable_a54eaf37"), order = 1,
            get = function() return self:GetDB().enabled ~= false end,
            set = function(_, value)
                if value then SarychUI:EnableModule("item_info") else SarychUI:DisableModule("item_info") end
                if SarychUI.OptionsCore and SarychUI.OptionsCore.ScheduleSmartRefresh then
                    SarychUI.OptionsCore:ScheduleSmartRefresh(true)
                end
            end},
        score = score,
        sources = {type = "group", name = "Inspect Equip", inline = true, order = 3, args = {
            enabled = {type = "toggle", name = SarychUI:T("ui.equipment.sources"), order = 1,
                desc = SarychUI:T("ui.addon_purpose.inspectequip"),
                disabled = function() return self:GetDB().enabled == false end,
                get = function() return self:GetDB().sources.enabled == true end,
                set = function(_, value) self:GetDB().sources.enabled = value and true or false; self:ApplyEquipment() end},
        }},
    }}
end
