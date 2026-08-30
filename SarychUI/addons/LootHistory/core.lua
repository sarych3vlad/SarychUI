-- Global enabled state
LootHistoryEnabled = LootHistoryEnabled or true;

-- Function to check if addon is enabled
local function IsEnabled()
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
  local f = CreateFrame('Frame')
  f:Hide()
  f:RegisterEvent("VARIABLES_LOADED")
  f:SetScript('OnEvent', function(self)
    if not LootHistoryDB then
      LootHistoryDB = {
        autoOpenLootHistory = "0"
      }
    end
  end)

  ControlsPanelOptions.autoOpenLootHistory = { text = "AUTO_OPEN_LOOT_HISTORY_TEXT" }

  local button = CreateFrame('CheckButton', "$parentAutoOpenLootHistory", InterfaceOptionsControlsPanel, "InterfaceOptionsCheckButtonTemplate")
  button:SetPoint("TOPLEFT", "$parentAutoLootCorpse", "BOTTOMLEFT", 0, -70)
  button.type = CONTROLTYPE_CHECKBOX
  button.defaultValue = "0"
  button.label = "autoOpenLootHistory"
  button.GetValue = function(self)
    if not LootHistoryDB then
      LootHistoryDB = {
        autoOpenLootHistory = "0"
      }
    end
    return self.value or LootHistoryDB[self.label]
  end
  button.SetValue = function(self, value)
    if not LootHistoryDB then
      LootHistoryDB = {
        autoOpenLootHistory = "0"
      }
    end
    self.value = value
    LootHistoryDB[self.label] = value
    self:SetChecked(value)
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
      return InterfaceOptionsControlsPanelAutoOpenLootHistory:GetValue() and true or false
    end
  end
end
