-- SarychUI Floating Text Filter module
local moduleName = "floating_text"
local module = {}
SarychUI:RegisterModule(moduleName, module)

local function Tools()
  return SarychUI and SarychUI.modules and SarychUI.modules.tools
end

function module:ApplyAll()
  local tools = Tools()
  if not tools then return end
  if tools.ApplyErrorFilter then tools:ApplyErrorFilter() end
  if tools.ApplyCombatTextAdjust then tools:ApplyCombatTextAdjust() end
  if tools.ApplyRaidBossEmoteReposition then tools:ApplyRaidBossEmoteReposition() end
  if tools.RegisterCombatTextDragFrames then
    tools:RegisterCombatTextDragFrames()
  end
  local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
  if db and tools.ToggleCombatTextDrag then
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
      tools:ToggleCombatTextDrag(active, true)
    end
  end
end

function module:Enable()
  self:ApplyAll()
end

function module:Disable()
  local panel = SarychUI and SarychUI.CombatTextDragPanel
  if panel and panel.IsOpen and panel:IsOpen() then
    panel:Close(false)
  end
  local tools = Tools()
  if not tools then return end
  if tools.DisableErrorFilter then tools:DisableErrorFilter() end
  if tools.DisableCombatTextAdjust then tools:DisableCombatTextAdjust() end
  if tools.DisableRaidBossEmoteReposition then tools:DisableRaidBossEmoteReposition() end
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
