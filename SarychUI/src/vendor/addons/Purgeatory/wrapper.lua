-- SarychUI controls the embedded Purgeatory lifecycle.
local ADDON_NAME = "Purgeatory"

local wrapper = {
    name = ADDON_NAME,
    author = "Mayen",
    version = "3",
    enabled = false,
    loaded = false,
}

local function GetConfig()
    local profile = SarychUI and SarychUI.db and SarychUI.db.profile
    return profile and profile.addons and profile.addons[ADDON_NAME]
end

local function IsStandaloneEnabled()
    return SarychUI_IsStandalonePurgeatoryEnabled and SarychUI_IsStandalonePurgeatoryEnabled()
end

function wrapper:IsRuntimeEnabled()
    return self.enabled and _G.Purgeatory and _G.Purgeatory.enabled or false
end

function wrapper:SetRuntimeEnabled(enable)
    if enable and IsStandaloneEnabled() then
        if SarychUI and SarychUI.Print then
            SarychUI:Print("|cffff0000Purgeatory:|r отключите отдельную версию аддона перед включением встроенной.")
        end
        return false
    end
    if enable then
        return SarychUI:EnableAddOn(ADDON_NAME)
    end
    return SarychUI:DisableAddOn(ADDON_NAME)
end

function wrapper:Initialize()
    self.loaded = SarychUI_PurgeatoryEmbeddedAvailable and _G.Purgeatory ~= nil
    self.enabled = false
    if self.loaded then
        _G.Purgeatory:OnInitialize()
    end
end

function wrapper:Enable()
    if IsStandaloneEnabled() or not SarychUI_PurgeatoryEmbeddedAvailable or not _G.Purgeatory then
        self.enabled = false
        local config = GetConfig()
        if config then config.enabled = false end
        return false
    end
    _G.Purgeatory:Enable()
    self.enabled = _G.Purgeatory.enabled and true or false
    self.loaded = true
    return self.enabled
end

function wrapper:Disable()
    self.enabled = false
    if SarychUI_PurgeatoryEmbeddedAvailable and _G.Purgeatory then
        _G.Purgeatory:Disable()
        local dialog = LibStub and LibStub("AceConfigDialog-3.0", true)
        if dialog then dialog:Close("Purgeatory") end
    end
    return true
end

function wrapper:OpenConfig()
    if not self:IsRuntimeEnabled() then return false end
    return _G.Purgeatory:OpenConfig()
end

function wrapper:GetOptions()
    local result = {
        type = "group",
        name = "Purgeatory",
        args = {
            enabled = {
                type = "toggle",
                name = "Включить",
                desc = "Включить или выключить оповещения о прерываниях и рассеиваниях.",
                order = 1,
                get = function() return wrapper:IsRuntimeEnabled() end,
                set = function(_, value) wrapper:SetRuntimeEnabled(value) end,
                disabled = IsStandaloneEnabled,
            },

        },
    }
    if SarychUI_PurgeatoryEmbeddedAvailable and _G.Purgeatory then
        local settings = _G.Purgeatory:GetSUIOptions()
        result.childGroups = "tab"
        result.suiTabBarExtra = settings.suiTabBarExtra
        for key, group in pairs(settings.args) do
            group.hidden = function() return not wrapper:IsRuntimeEnabled() end
            result.args[key] = group
        end
    end
    return result
end

SarychUI:RegisterAddOn(ADDON_NAME, wrapper)
return wrapper
