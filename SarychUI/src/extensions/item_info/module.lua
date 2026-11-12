-- Embedded addon ownership; retain GearScoreLite's saved configuration key.
local module = {title = "Gear Score"}
SarychUI:RegisterAddOn("GearScoreLite", module)

function module:Enable() self.enabled = true; self:ApplyGearScoreLite() end
function module:Disable() self.enabled = false; self:ApplyGearScoreLite(true) end
function module:RefreshConfig() self:ApplyGearScoreLite() end
function module:GetOptions() return self:GetGearScoreLiteOptions() end

function module:Initialize()
    local profile = SarychUI.db.profile
    local config = profile.addons.GearScoreLite
    if not config.ownerMigrated then
        local old = profile.modules.item_info
        if old and old.enabled == false then config.enabled = false end
        config.ownerMigrated = true
    end
    self.loaded = true
    self:ApplyGearScoreLite(true)
end
