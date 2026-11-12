local module = {}
SarychUI:RegisterExtension("addon_management", module)

function module:Enable() self:ApplyAddonList() end
function module:Disable() self:ApplyAddonList(true) end
function module:RefreshConfig() self:ApplyAddonList() end
function module:GetOptions() local options = self:GetAddonListOptions(); options.name = "Управление модификациями"; return options end
function module:Initialize() self:ApplyAddonList() end
