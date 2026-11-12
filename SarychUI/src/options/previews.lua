local CreateFrame = SarychUI.OptionsPool and SarychUI.OptionsPool.CreateFrame or CreateFrame
-- Preview construction belongs to the options infrastructure; models remain with their owners.
local SUI = SarychUI
local P = { factories = {}, legacy = {} }
SUI.OptionsPreviews = P

function P:Style(host)
    local theme = SUI.OptionsTheme
    theme:ApplyFlat(host, theme.colors.panelBg, theme.colors.borderSoft)
end

function P:CreateHost(parent, height)
    local host = SUI.OptionsWidgets:Panel(parent)
    host:SetHeight(height)
    host.spacer = host
    local stage = CreateFrame("Frame", nil, host, nil, "previews:1")
    local pad = host._contentPad
    stage:SetPoint("TOPLEFT", pad, -pad)
    stage:SetPoint("BOTTOMRIGHT", -pad, pad)
    return host, stage
end

function P:Register(id, factory)
    assert(type(id) == "string" and type(factory) == "function", "Invalid preview registration")
    assert(not self.factories[id], "Duplicate preview: " .. id)
    self.factories[id] = factory
end

function P:Resolve(option)
    if option.suiPreview then return option.suiPreview end
    for _, entry in ipairs(self.legacy) do
        if option[entry.flag] then return entry.id end
    end
end

function P:Create(parent, option)
    local id = self:Resolve(option)
    local factory = self.factories[id]
    local widget = factory and factory(parent, option)
    if widget then return widget end
    return SUI.OptionsWidgets:Description(parent, SUI:T("ui.preview_unavailable"))
end

P.legacy[#P.legacy + 1] = { flag = "suiLayoutPreview", id = "PlatesAurasLayoutPreview" }
P:Register("PlatesAurasLayoutPreview", function(parent, option)
    local model = SUI.PlatesAurasLayoutPreview
    if model and model.Create then return model:Create(parent, option.suiLayoutPreview, option.suiLayoutPreviewNotice) end
end)
P.legacy[#P.legacy + 1] = { flag = "suiDistancePreview", id = "NameplateDistancePreview" }
P:Register("NameplateDistancePreview", function(parent, option)
    local model = SUI.NameplateDistancePreview
    if model and model.Create then return model:Create(parent, option.suiDistancePreviewNotice) end
end)
P.legacy[#P.legacy + 1] = { flag = "suiLootRollPreview", id = "LootRollPreview" }
P:Register("LootRollPreview", function(parent, option)
    local model = SUI.LootRollPreview
    if model and model.Create then return model:Create(parent) end
end)
P.legacy[#P.legacy + 1] = { flag = "suiCooldownTextPreview", id = "CooldownTextPreview" }
P:Register("CooldownTextPreview", function(parent, option)
    local model = SUI.CooldownTextPreview
    if model and model.Create then return model:Create(parent) end
end)
P.legacy[#P.legacy + 1] = { flag = "suiGcdCooldownPreview", id = "GcdCooldownPreview" }
P:Register("GcdCooldownPreview", function(parent, option)
    local model = SUI.GcdCooldownPreview
    if model and model.Create then return model:Create(parent) end
end)
P.legacy[#P.legacy + 1] = { flag = "suiActionBarTextPreview", id = "ActionBarTextPreview" }
P:Register("ActionBarTextPreview", function(parent, option)
    local model = SUI.ActionBarTextPreview
    if model and model.Create then return model:Create(parent) end
end)
P.legacy[#P.legacy + 1] = { flag = "suiActionBarColorPreview", id = "ActionBarColorPreview" }
P:Register("ActionBarColorPreview", function(parent, option)
    local model = SUI.ActionBarColorPreview
    if model and model.Create then return model:Create(parent) end
end)
P.legacy[#P.legacy + 1] = { flag = "suiActionBarAppearancePreview", id = "ActionBarAppearancePreview" }
P:Register("ActionBarAppearancePreview", function(parent, option)
    local model = SUI.ActionBarAppearancePreview
    if model and model.Create then return model:Create(parent) end
end)
P.legacy[#P.legacy + 1] = { flag = "suiActionBarTransparencyPreview", id = "ActionBarTransparencyPreview" }
P:Register("ActionBarTransparencyPreview", function(parent, option)
    local model = SUI.ActionBarTransparencyPreview
    if model and model.Create then return model:Create(parent) end
end)
P.legacy[#P.legacy + 1] = { flag = "suiActionBarBarsPreview", id = "ActionBarBarsPreview" }
P:Register("ActionBarBarsPreview", function(parent, option)
    local model = SUI.ActionBarBarsPreview
    if model and model.Create then return model:Create(parent) end
end)
P.legacy[#P.legacy + 1] = { flag = "suiErrorFilterPreview", id = "ErrorFilterPreview" }
P:Register("ErrorFilterPreview", function(parent, option)
    local model = SUI.ErrorFilterPreview
    if model and model.Create then return model:Create(parent) end
end)
P.legacy[#P.legacy + 1] = { flag = "suiSysMsgPreview", id = "SysMsgPreview" }
P:Register("SysMsgPreview", function(parent, option)
    local model = SUI.SysMsgPreview
    if model and model.Create then return model:Create(parent) end
end)
P.legacy[#P.legacy + 1] = { flag = "suiBossEmotePreview", id = "BossEmotePreview" }
P:Register("BossEmotePreview", function(parent, option)
    local model = SUI.BossEmotePreview
    if model and model.Create then return model:Create(parent) end
end)
P.legacy[#P.legacy + 1] = { flag = "suiFrameHitPreview", id = "FrameHitPreview" }
P:Register("FrameHitPreview", function(parent, option)
    local model = SUI.FrameHitPreview
    if model and model.Create then return model:Create(parent) end
end)
P.legacy[#P.legacy + 1] = { flag = "suiArenaPreview", id = "ArenaPreview" }
P:Register("ArenaPreview", function(parent, option)
    local model = SUI.ArenaPreview
    if model and model.Create then return model:Create(parent) end
end)
P.legacy[#P.legacy + 1] = { flag = "suiArenaNumbersPreview", id = "ArenaNumbersPreview" }
P:Register("ArenaNumbersPreview", function(parent, option)
    local model = SUI.ArenaNumbersPreview
    if model and model.Create then return model:Create(parent) end
end)
P.legacy[#P.legacy + 1] = { flag = "suiArenaGroupTitlesPreview", id = "ArenaGroupTitlesPreview" }
P:Register("ArenaGroupTitlesPreview", function(parent, option)
    local model = SUI.ArenaGroupTitlesPreview
    if model and model.Create then return model:Create(parent) end
end)
P.legacy[#P.legacy + 1] = { flag = "suiPartyAbilitiesPreview", id = "PartyAbilitiesPreview" }
P:Register("PartyAbilitiesPreview", function(parent, option)
    local model = SUI.PartyAbilitiesPreview
    if model and model.Create then return model:Create(parent) end
end)
P.legacy[#P.legacy + 1] = { flag = "suiAurasPreview", id = "AurasPreview" }
P:Register("AurasPreview", function(parent, option)
    local model = SUI.AurasPreview
    if model and model.Create then return model:Create(parent) end
end)
P.legacy[#P.legacy + 1] = { flag = "suiMinimapPreview", id = "MinimapPreview" }
P:Register("MinimapPreview", function(parent, option)
    local model = SUI.MinimapPreview
    if model and model.Create then return model:Create(parent) end
end)
P.legacy[#P.legacy + 1] = { flag = "suiCombatIndicatorPreview", id = "CombatIndicatorPreview" }
P:Register("CombatIndicatorPreview", function(parent, option)
    local model = SUI.CombatIndicatorPreview
    if model and model.Create then return model:Create(parent) end
end)
P.legacy[#P.legacy + 1] = { flag = "suiFramePvpPreview", id = "FramePvpPreview" }
P:Register("FramePvpPreview", function(parent, option)
    local model = SUI.FramePvpPreview
    if model and model.Create then return model:Create(parent) end
end)
P.legacy[#P.legacy + 1] = { flag = "suiChatTooltipPreview", id = "ChatTooltipPreview" }
P:Register("ChatTooltipPreview", function(parent, option)
    local model = SUI.ChatTooltipPreview
    if model and model.Create then return model:Create(parent) end
end)
P.legacy[#P.legacy + 1] = { flag = "suiCombatTextPreview", id = "CombatTextPreview" }
P:Register("CombatTextPreview", function(parent, option)
    local model = SUI.CombatTextPreview
    if model and model.Create then return model:Create(parent) end
end)
P.legacy[#P.legacy + 1] = { flag = "suiPlayerResourcesPreview", id = "PlayerResourcesPreview" }
P:Register("PlayerResourcesPreview", function(parent, option)
    local model = SUI.PlayerResourcesPreview
    if model and model.Create then return model:Create(parent) end
end)
P.legacy[#P.legacy + 1] = { flag = "suiCastbarTimerPreview", id = "CastbarTimerPreview" }
P:Register("CastbarTimerPreview", function(parent, option)
    local model = SUI.CastbarTimerPreview
    if model and model.Create then return model:Create(parent) end
end)
P.legacy[#P.legacy + 1] = { flag = "suiCountdownTimerPreview", id = "CountdownTimerPreview" }
P:Register("CountdownTimerPreview", function(parent, option)
    local model = SUI.CountdownTimerPreview
    if model and model.Create then return model:Create(parent) end
end)
