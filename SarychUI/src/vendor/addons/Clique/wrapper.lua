-- Embedded Clique lifecycle, storage and native SUI options.
local _, private = ...
local addon = private.Clique
local Compat = private.Compat
local wrapper = { title = "Clique", author = "Cladhaire, Tsoukie; интеграция SarychUI", version = "1.7", loaded = false }
local function config()
    local profiles = SarychUI.db.profile.addons
    profiles.Clique = profiles.Clique or { enabled = false }
    return profiles.Clique
end
local function external()
    return Compat.AddOns.GetEnableState(nil, "Clique") > 0
end
local function reload()
    SarychUI:ShowReloadPopup("Изменения Clique вступят в силу после перезагрузки интерфейса (/reload).")
end
local function fillDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then target[key] = type(value) == "table" and CopyTable(value) or value
        elseif type(value) == "table" then fillDefaults(target[key], value) end
    end
end
function addon:CreateDatabase()
    local data = config()
    local global = SarychUI.db.global
    -- One-time migration of the active legacy Clique profile; keep the old
    -- storage as a backup, but never seed subsequent SUI profiles from it.
    local charKey = UnitName("player") .. " - " .. GetRealmName()
    if type(global.cliqueProfileMigration) ~= "table" then global.cliqueProfileMigration = {} end
    if not global.cliqueProfileMigration[charKey] then
        local old = global.clique
        local settings = old and old.char and old.char[charKey]
        local key = old and old.profileKeys and old.profileKeys[charKey] or charKey
        if settings and settings.specswap then
            key = (GetActiveTalentGroup() == 2 and settings.sec_profileKey or settings.pri_profileKey) or key
        end
        local previous = old and old.profiles and old.profiles[key]
        if data.bindings == nil and previous and type(previous.bindings) == "table" then data.bindings = CopyTable(previous.bindings) end
        if data.settings == nil and settings then data.settings = CopyTable(settings) end
        global.cliqueProfileMigration[charKey] = true
    end
    data.settings = data.settings or {}
    fillDefaults(data.settings, self.defaults.settings)
    for _, key in ipairs({"blacklist", "fastooc", "stopcastingfix", "specswap", "pri_profileKey", "sec_profileKey"}) do data.settings[key] = nil end
    if data.bindings == nil then data.bindings = CopyTable(self.defaults.bindings) end
    -- A view of the SUI profile, not an independent AceDB database.
    return { profile = data, char = data.settings }
end
function wrapper:ProfileChanged()
    if not self.loaded then return end
    addon:Defer(function()
        -- Discard editor references to bindings from the previous SUI profile.
        SarychUICliqueConfig:Hide()
        SarychUICliqueDialog:Hide()
        local old = addon.settings.blizzframes
        local db = addon:CreateDatabase()
        local needsReload = not wrapper:IsRuntimeEnabled()
        for key, value in pairs(db.char.blizzframes) do if old[key] ~= value then needsReload = true end end
        addon.db, addon.settings, addon.bindings = db, db.char, db.profile.bindings
        addon:UpdateRegisteredClicks()
        addon:FireMessage("BINDINGS_CHANGED")
        if needsReload then reload() end
    end)
end
function addon:OpenSUIOptions()
    SarychUI:OpenOptionsPanel()
    local core = SarychUI.OptionsCore
    core._twoPaneSelected = core._twoPaneSelected or {}
    core._twoPaneSelected["addons/ported"] = "Clique"
    core._renderedId = nil
    core:SelectSection("sui:addons")
end
function wrapper:IsRuntimeEnabled() return config().enabled == true and not external() end
function wrapper:SetRuntimeEnabled(value)
    if value and external() then
        SarychUI:Print("Отключите отдельный Clique в списке модификаций, чтобы включить встроенный.")
        return false
    end
    config().enabled = not not value
    self.enabled = not not value
    reload()
    return true
end
function wrapper:Initialize()
    if self.initialized then return end
    self.initialized = true
    if SarychUI.db.RegisterCallback then
        for _, event in ipairs({"OnProfileChanged", "OnProfileCopied", "OnProfileReset"}) do
            SarychUI.db.RegisterCallback(self, event, "ProfileChanged")
        end
    end
    self.enabled = self:IsRuntimeEnabled()
    if not self.enabled then return end
    addon:Defer(function()
        addon:Initialize()
        addon:Enable()
        self.loaded = true
        Compat.Widgets.SetShown(SarychUICliqueSpellTab, true)
        SLASH_SARYCHUICLIQUE1 = "/clique"
        SlashCmdList.SARYCHUICLIQUE = function()
            if InCombatLockdown() then return end
            ShowUIPanel(SarychUICliqueConfig)
        end
        -- ADDON_LOADED normally precedes entering world; also support late initialization.
        if IsLoggedIn() then addon:PlayerEnteringWorld() end
    end)
end
function wrapper:Enable()
    if not self.initialized then self:Initialize()
    elseif not self.loaded and self:IsRuntimeEnabled() then reload() end
end
function wrapper:Disable() self:SetRuntimeEnabled(false) end
local function unavailable() return not wrapper.loaded or InCombatLockdown() end
function wrapper:GetOptions()
    local general = { type="group", name="Общее", order=2, disabled=unavailable, args={} }
    local args = general.args
    args.editor = { type="execute", name="Редактор привязок", order=1, func=function()
        if unavailable() then return end
        SarychUI:CloseCustomOptions()
        ShowUIPanel(SarychUICliqueConfig)
    end }
    local frames = { type="group", name="Рамки", order=3, disabled=unavailable, args={} }
    local labels = {{"PlayerFrame","Игрок"},{"PetFrame","Питомец"},{"TargetFrame","Цель"},{"TargetFrameToT","Цель цели"},{"FocusFrame","Фокус"},{"FocusFrameToT","Цель фокуса"},{"party","Группа (обычные рамки)"},{"compactraid","Рейдовые рамки SUI"},{"compactparty","Компактные рамки группы SUI"},{"arena","Противники на арене"},{"boss","Боссы"}}
    for i, entry in ipairs(labels) do
        local key=entry[1]
        frames.args[key]={type="toggle", name=entry[2], order=i,
            get=function() return addon.settings and addon.settings.blizzframes[key] end,
            set=function(_, value) if unavailable() then return end; addon.settings.blizzframes[key]=value; reload() end}
    end
    return {type="group", name="Clique", childGroups="tab", args={
        enabled={type="toggle", name="Включить (после /reload)", order=0, get=function() return config().enabled end, set=function(_, value) wrapper:SetRuntimeEnabled(value) end},
        general=general, frames=frames,
    }}
end
SarychUI:RegisterAddOn("Clique", wrapper)
