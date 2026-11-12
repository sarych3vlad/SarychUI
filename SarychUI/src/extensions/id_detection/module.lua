local module = {}
SarychUI:RegisterExtension("id_detection", module)

function module:Enable() self:ApplyIdTip() end
function module:Disable() self:ApplyIdTip(true) end
function module:RefreshConfig() self:ApplyIdTip() end
function module:GetOptions() local options = self:GetIdTipOptions(); options.name = "Определение ID"; return options end

function module:Initialize() self:ApplyIdTip(true) end
