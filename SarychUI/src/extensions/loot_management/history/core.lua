-- Global enabled state
LootHistoryEnabled = LootHistoryEnabled or true;

-- Function to check if addon is enabled
local function IsEnabled()
	if LootHistoryEnabled == false then return false end
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.LootHistory then
		return SarychUI.db.profile.addons.LootHistory.enabled ~= false;
	end
	return LootHistoryEnabled;
end

local CreateFrame, PlaySound = CreateFrame, PlaySound

-- support slash commands
SlashCmdList["OPEN_LOOT_HISTORY"] = function(msg)
	if not IsEnabled() then
		return;
	end
  ToggleLootHistoryFrame()
end

-- add checkbox into InterfaceOptionsPanel (Control tab)
do
  local function Settings()
    LootHistoryDB = LootHistoryDB or {}
    -- Adopt manual-only auto-open once, including the old ineffective "0".
    -- Later explicit opt-outs must survive reloads.
    if not LootHistoryDB.manualAutoOpenDefaultApplied then
      LootHistoryDB.autoOpenLootHistory = "1"
      LootHistoryDB.manualAutoOpenDefaultApplied = true
    elseif LootHistoryDB.autoOpenLootHistory == nil then
      LootHistoryDB.autoOpenLootHistory = "1"
    end
    return LootHistoryDB
  end
  local f = CreateFrame('Frame')
  f:Hide()
  f:RegisterEvent("VARIABLES_LOADED")
  f:SetScript('OnEvent', function(self)
    local settings = Settings()
    local control = InterfaceOptionsControlsPanelAutoOpenLootHistory
    if control then control:SetValue(settings.autoOpenLootHistory) end
  end)

  ControlsPanelOptions.autoOpenLootHistory = { text = "AUTO_OPEN_LOOT_HISTORY_TEXT" }

  local button = CreateFrame('CheckButton', "$parentAutoOpenLootHistory", InterfaceOptionsControlsPanel, "InterfaceOptionsCheckButtonTemplate")
  button:SetPoint("TOPLEFT", "$parentAutoLootCorpse", "BOTTOMLEFT", 0, -70)
  button.type = CONTROLTYPE_CHECKBOX
  button.defaultValue = "1"
  button.label = "autoOpenLootHistory"
  button.GetValue = function(self)
    return Settings()[self.label]
  end
  button.SetValue = function(self, value)
    local settings = Settings()
    self.value = value
    settings[self.label] = value
    self:SetChecked(value == true or value == 1 or value == "1")
  end
  button:SetScript('OnClick', function(self)
    local value = self:GetChecked() and "1" or "0"
    if value == "1" then
      PlaySound("igMainMenuOptionCheckBoxOn")
    else
      PlaySound("igMainMenuOptionCheckBoxOff")
    end
    self:SetValue(value)
  end)
  BlizzardOptionsPanel_RegisterControl(button, button:GetParent())

  -- helpful function
  function GetInterfaceOptionsVarBool(control)
    if control == 'autoOpenLootHistory' then
      local value = InterfaceOptionsControlsPanelAutoOpenLootHistory:GetValue()
      return value == true or value == 1 or value == "1"
    end
  end
end
