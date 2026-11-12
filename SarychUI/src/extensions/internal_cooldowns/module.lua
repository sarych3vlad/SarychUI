local module = {}
SarychUI:RegisterExtension("internal_cooldowns", module)

function module:Enable() self:ApplyInternalCooldowns() end
function module:Disable() self:ApplyInternalCooldowns(true) end
function module:RefreshConfig() self:ApplyInternalCooldowns() end
function module:GetOptions() local options = self:GetInternalCooldownsOptions(); options.name = "Внутренние таймеры предметов"; return options end

function module:Initialize() self:ApplyInternalCooldowns(true) end
