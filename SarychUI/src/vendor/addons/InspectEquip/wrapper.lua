-- One lifecycle owner; no AceAddon instance or separate Blizzard settings page.
local IE = {name = "InspectEquip", title = "InspectEquip", author = "emelio", version = "1.7.7", enabled = false}
SarychUI.InspectEquip = IE

local function StandaloneEnabled()
    if not GetAddOnInfo then return false end
    local _, _, _, enabled, loadable = GetAddOnInfo("InspectEquip")
    return enabled and loadable and true or false
end

function IE:IsRuntimeEnabled()
    return self.enabled
end

function IE:Initialize()
    -- Data tables, frames and hooks are created only on first enable.
    self.loaded = true
end

function IE:Enable()
    if StandaloneEnabled() then
        self:Disable()
        local config = SarychUI.db.profile.addons.InspectEquip
        if config then config.enabled = false end
        SarychUI:Print(SarychUI:T("ui.inspectequip.standalone"))
        return false
    end
    if self.enabled then return true end
    self:InitializeSources()
    self:GetItemNames()
    self.enabled = true
    self:Start()
    return true
end

function IE:Disable()
    self.enabled = false
    self:Stop()
    return true
end

function IE:GetOptions()
    return {type = "group", name = "InspectEquip", args = {
        enabled = {type = "toggle", name = "ui.enable_a54eaf37", order = 1,
            desc = "ui.addon_purpose.inspectequip",
            get = function() return IE:IsRuntimeEnabled() end,
            set = function(_, value)
                if value then SarychUI:EnableAddOn("InspectEquip")
                else SarychUI:DisableAddOn("InspectEquip") end
            end},
    }}
end

SarychUI:RegisterAddOn("InspectEquip", IE)
