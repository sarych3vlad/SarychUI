-- Keep the embedded copy from replacing a separately installed Purgeatory.
function SarychUI_IsStandalonePurgeatoryEnabled()
    if not GetAddOnInfo then return false end
    local _, _, _, enabled, loadable = GetAddOnInfo("Purgeatory")
    return enabled and loadable and true or false
end

SarychUI_PurgeatoryEmbeddedAvailable = not SarychUI_IsStandalonePurgeatoryEnabled()
