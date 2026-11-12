local module = SarychUI.modules.health_indicators
function module:IsNamePlatesRunning()
    local E = _G.SarychUI_ElvUI_NamePlates and _G.SarychUI_ElvUI_NamePlates[1]
    local NP = E and E:GetModule("NamePlates", true)
    return E and E.initialized and NP and NP.Initialized and E:IsNamePlatesRuntimeEnabled() or false
end
function module:ApplyNamePlates(enable)
    local E = _G.SarychUI_ElvUI_NamePlates and _G.SarychUI_ElvUI_NamePlates[1]
    if not E then return false end
    if E.CheckStandaloneConflict and E:CheckStandaloneConflict() then enable = false end
    enable = enable and SarychUI:GetNameplateMode() == "elvui" or false
    E.loginReady = true
    E.myLocalizedClass, E.myclass = UnitClass("player")
    E.mylevel, E.myguid = UnitLevel("player"), UnitGUID("player")
    if enable and not E.initialized then E:TryInitialize() end
    local private = E.private or (E.privateVars and E.privateVars.profile)
    if private then private.nameplates = private.nameplates or {}; private.nameplates.enable = enable end
    if enable then E:StartNamePlatesRuntime() else E:ShutdownRuntime() end
    return self:IsNamePlatesRunning()
end
