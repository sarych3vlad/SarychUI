-- SarychUI Floating Text Filter module
local moduleName = "floating_text"
local module = {}
SarychUI:RegisterModule(moduleName, module)

local function Tools()
  return SarychUI and SarychUI.modules and SarychUI.modules.floating_text
end

function module:ApplyAll()
  local tools = Tools()
  if not tools then return end
  if SarychUI.modules.floating_text.ApplyErrorFilter then SarychUI.modules.floating_text:ApplyErrorFilter() end
  if SarychUI.modules.floating_text.ApplyCombatTextAdjust then SarychUI.modules.floating_text:ApplyCombatTextAdjust() end
  if SarychUI.modules.floating_text.ApplyRaidBossEmoteReposition then SarychUI.modules.floating_text:ApplyRaidBossEmoteReposition() end
  if SarychUI.modules.floating_text.RegisterCombatTextDragFrames then
    SarychUI.modules.floating_text:RegisterCombatTextDragFrames()
  end
  local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
  if db and SarychUI.modules.floating_text.ToggleCombatTextDrag then
    -- Only one combat-text drag session at a time.
    local active = nil
    if db.combatTextPlusDrag == 1 then active = "combatTextPlus"
    elseif db.combatTextMinusDrag == 1 then active = "combatTextMinus"
    elseif db.combatTextLessDrag == 1 then active = "combatTextLess"
    end
    if db.combatTextPlusDrag == 1 and active ~= "combatTextPlus" then db.combatTextPlusDrag = 0 end
    if db.combatTextMinusDrag == 1 and active ~= "combatTextMinus" then db.combatTextMinusDrag = 0 end
    if db.combatTextLessDrag == 1 and active ~= "combatTextLess" then db.combatTextLessDrag = 0 end
    if active then
      SarychUI.modules.floating_text:ToggleCombatTextDrag(active, true)
    end
  end
end

function module:Enable()
  self:ApplyAll()
end

function module:Disable()
  if self.StopTestMode then self:StopTestMode() end
  local panel = SarychUI and SarychUI.CombatTextDragPanel
  if panel and panel.IsOpen and panel:IsOpen() then
    panel:Close(false)
  end
  local tools = Tools()
  if not tools then return end
  if SarychUI.modules.floating_text.DisableErrorFilter then SarychUI.modules.floating_text:DisableErrorFilter() end
  if SarychUI.modules.floating_text.DisableCombatTextAdjust then SarychUI.modules.floating_text:DisableCombatTextAdjust() end
  if SarychUI.modules.floating_text.DisableRaidBossEmoteReposition then SarychUI.modules.floating_text:DisableRaidBossEmoteReposition() end
  if SarychUI and SarychUI.DragMode then
    SarychUI.DragMode:UnregisterFrame("combatTextPlus")
    SarychUI.DragMode:UnregisterFrame("combatTextMinus")
    SarychUI.DragMode:UnregisterFrame("combatTextLess")
  end
  local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
  if db then
    db.combatTextPlusDrag = 0
    db.combatTextMinusDrag = 0
    db.combatTextLessDrag = 0
  end
end

function module:RefreshConfig()
  local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
  if not db or db.enabled == false then
    self:Disable()
    return
  end
  self:Enable()
end
