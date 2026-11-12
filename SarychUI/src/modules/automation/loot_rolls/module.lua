local feature = SarychUI.LootRolls

function feature:GetDB()
    local profile = SarychUI.db.profile
    local db = profile.modules.automation
    if db.lootRollsEnabled == nil then
        local legacy = profile.addons and profile.addons.LootClicker
        db.lootRollsEnabled = legacy and legacy.enabled == true and (not LootClickerDB or LootClickerDB.enabled ~= false) or false
    end
    LootClickerDB = LootClickerDB or CopyTable(self.defaultDB)
    self:CheckAllVariables(LootClickerDB, self.defaultDB)
    LootClickerDB.spam_filter = nil
    for _, settings in pairs(LootClickerDB.loot_settings) do
        if settings.smart_disenchant then settings.smart_disenchant.with_dis = nil end
    end
    return db, LootClickerDB
end

function feature:Stop()
    self.active = false
    self.frame:OnDisable()
end

function feature:Apply()
    local db = self:GetDB()
    self:Stop()
    self.active = db.enabled == true and db.lootRollsEnabled == true
    if self.active then self.frame:OnEnable() end
end

function feature:SetEnabled(value)
    local db = self:GetDB()
    db.lootRollsEnabled = value == true
    self:Apply()
    if SarychUI.RefreshConfig then SarychUI:RefreshConfig() end
end
