local _G, pairs, select, tonumber, table_sort, floor, abs = _G, pairs, select, tonumber, table.sort, math.floor, math.abs
local CreateFrame, GetAddOnMetadata, IsModifiedClick, hooksecurefunc = CreateFrame, GetAddOnMetadata, IsModifiedClick, hooksecurefunc
local CursorHasItem, GetItemInfo, GetCursorInfo, ClearCursor, PlaySound, PlaySoundFile, IsSpellKnown = CursorHasItem, GetItemInfo, GetCursorInfo, ClearCursor, PlaySound, PlaySoundFile, IsSpellKnown
local _, private = ...
-- Set addon name explicitly since we're loaded through SarychUI.toc
local addon_name = "LootClicker"
local L = private.L
local C = private.constants

local function CreateTab(parent, text)
  local tabNumber = #parent.tabs + 1
  local tab = CreateFrame('Button', '$parentTab'..tabNumber, parent, 'OptionsFrameTabButtonTemplate', tabNumber)
  if tabNumber == 1 then
    tab:SetPoint('BOTTOMLEFT', parent, 'TOPLEFT', 6, -2)
  else
    tab:SetPoint('LEFT', parent.tabs[(tabNumber-1)], 'RIGHT', -10, 0)
  end
  tab:SetText(text)
  tab:SetScript('OnClick', function(self)
    parent:Tab_OnClick(self)
  end)

  PanelTemplates_SetNumTabs(parent, tabNumber)
  parent.tabs[tabNumber] = tab
  return tab
end
local function CreateTabFrame(parent, tab_text)
  local tab = CreateTab(parent, tab_text)
  local frameNumber = #parent.frames + 1
  local frame = CreateFrame('Frame', '$parentFrame'..frameNumber, parent)
  frame:SetAllPoints()
  frame:Hide()

  parent.frames[frameNumber] = frame
  return frame, tab
end
local function CreateButton_Helper(button)
  button.text = _G[button:GetName()..'Text']
  button:SetFontString(button.text) -- O_o need use for correct work 'GetTextWidth' method (equivalent a XML tag 'ButtonText')

  if button:GetObjectType() == 'CheckButton' then
    button.text:SetFontObject('GameFontWhite')
    hooksecurefunc(button.text, 'SetText', function(self, text)
      local text_width = button:GetTextWidth()
      if text_width < 100 then text_width = 100 end
      button:SetHitRectInsets(0, -text_width, 0, 0) -- make a clickable area of all text
    end)
    hooksecurefunc(button, 'Enable', function(self)
      self.text:SetFontObject('GameFontWhite')
    end)
    hooksecurefunc(button, 'Disable', function(self)
      self.text:SetFontObject('GameFontDisable')
    end)
    button:SetScript('OnClick', function(self)
      local state = self:GetChecked()
      if state then
        PlaySound('igMainMenuOptionCheckBoxOn')
      else
        PlaySound('igMainMenuOptionCheckBoxOff')
      end
      if self.setFunc then
        self.setFunc(state)
      end
    end)
  end
  button:SetScript('OnEnter', function(self)
    if not self.tooltipText then return end
    GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
    GameTooltip:SetText(self.tooltipText, nil, nil, nil, nil, 1)
  end)
  button:SetScript('OnLeave', function(self)
    GameTooltip:Hide()
  end)
end
local function CreateButton(name, parent, width, height, text, tooltip)
  local button = CreateFrame('Button', name, parent, 'UIPanelButtonTemplate')
  CreateButton_Helper(button)
  button:SetSize(width, height)
  button.text:SetFontObject('GameFontNormal')
  button.text:SetText(text)
  button.tooltipText = tooltip
  return button
end
local function CreateCheckButton(name, parent, text, tooltip)
  local checkButton = CreateFrame('CheckButton', name, parent, 'UICheckButtonTemplate')
  CreateButton_Helper(checkButton)
  checkButton:SetSize(26, 26)
  checkButton.text:SetText(text)
  checkButton.tooltipText = tooltip
  return checkButton
end
local function CreateRadioButton(name, parent, text, tooltip)
  local radioButton = CreateFrame('CheckButton', name, parent, 'UIRadioButtonTemplate')
  radioButton:SetDisabledCheckedTexture([[Interface\Buttons\UI-RadioButton]])
  local disabledCheckedTexture = radioButton:GetDisabledCheckedTexture()
  disabledCheckedTexture:SetTexCoord(0.25, 0.5, 0, 1)
  disabledCheckedTexture:SetDesaturated(true)
  CreateButton_Helper(radioButton)
  radioButton.text:SetText(text)
  radioButton.tooltipText = tooltip
  return radioButton
end
local function GetBoolean(value)
  if not value or value == false or value == 0 or value == '0' then
    return false
  else
    return true
  end
end

local function SetAboutInfo(field_name, field_data, has_editbox)
  local about = private.config.about
  local i = #about.field + 1
  about.field[i] = about:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  if #about.field == 1 then
    about.field[i]:SetPoint("TOPLEFT", 20, -30)
  else
    about.field[i]:SetPoint("TOPLEFT", about.field[i-1], "BOTTOMLEFT", 0, -10)
  end
  about.field[i]:SetWidth(100)
  about.field[i]:SetJustifyH("RIGHT")
  about.field[i]:SetJustifyV("TOP")
  about.field[i]:SetText(field_name..":")

  about.data[i] = about:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  about.data[i]:SetPoint("TOPLEFT", about.field[i], "TOPRIGHT", 4, 0)
  about.data[i]:SetPoint("RIGHT", about, -16, 0)
  about.data[i]:SetJustifyH("LEFT")
  about.data[i]:SetJustifyV("TOP")
  about.data[i]:SetText(field_data)

  if has_editbox then
    about.data[i]:SetTextColor(0.14, 0.73, 0.97)
    local button = CreateFrame("Button", nil, about)
    button:SetAllPoints(about.data[i])
    button:SetScript("OnClick", function(self)
      about.editbox:Hide() -- hide already opened editbox for update old_text field
      about.editbox:SetParent(self)
      about.editbox:SetAllPoints(self)
      about.editbox:SetText(field_data)
      about.editbox:Show()
    end)
    button:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
      GameTooltip:SetText(L["Click and press Ctrl-C to copy"])
    end)
    button:SetScript("OnLeave", function(self)
      GameTooltip:Hide()
    end)
  end
end


local config = CreateFrame('Frame', addon_name..'Config')
private.config = config
config:Hide()

config.title = config:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
config.title:SetPoint('TOPLEFT', 16, -16)
config.title:SetPoint('TOPRIGHT', -16 - 140, -16)
config.title:SetJustifyH("LEFT")
config.title:SetText(addon_name..' '..(GetAddOnMetadata(addon_name, 'Version') or '9.7'))

config.desc = config:CreateFontString(nil, 'ARTWORK', 'GameFontWhite')
config.desc:SetPoint('TOPLEFT', 16, -42)
config.desc:SetPoint('TOPRIGHT', -16, -42)
config.desc:SetJustifyH("LEFT")
config.desc:SetText(GetAddOnMetadata(addon_name, 'Notes') or GetAddOnMetadata(addon_name, 'Notes-ruRU') or "Автоматически нажимает кнопки при розыгрыше добычи.")

config.about = CreateFrame('Frame', '$parentAboutFrame', config)
config.about.field, config.about.data = {}, {}
config.about:Hide()
config.about:SetPoint('TOPLEFT', InterfaceOptionsFramePanelContainer, "TOPLEFT", 0, -60)
config.about:SetPoint('BOTTOMRIGHT', InterfaceOptionsFramePanelContainer, "BOTTOMRIGHT", 0, 0)

config.about.editbox = CreateFrame("EditBox", nil, nil, "InputBoxTemplate")
config.about.editbox:Hide()
config.about.editbox:SetFontObject("GameFontWhite")
config.about.editbox.old_text = ""

config.about.editbox:SetScript("OnShow", function(self) self.old_text = self:GetText() end)
config.about.editbox:SetScript("OnHide", function(self) self.old_text = "" end)
config.about.editbox:SetScript("OnEscapePressed", config.about.editbox.Hide)
config.about.editbox:SetScript("OnEnterPressed", config.about.editbox.Hide)
config.about.editbox:SetScript("OnChar", function(self)
  self:SetText(self.old_text)
  self:HighlightText()
end)

SetAboutInfo(L["Version"],  GetAddOnMetadata(addon_name, "Version") or "9.7")
local author = GetAddOnMetadata(addon_name, "Author") or "Artur91425"
local server = GetAddOnMetadata(addon_name, "X-Author-Server") or "WoW Circle 3.3.5 x5"
SetAboutInfo(L["Author"],   L["%s on the %s realm"]:format(author, server))
SetAboutInfo(L["Category"], GetAddOnMetadata(addon_name, "X-Category") or "Miscellaneous")
SetAboutInfo(L["License"],  GetAddOnMetadata(addon_name, "X-License") or "MIT License")
SetAboutInfo(L["Credits"],  GetAddOnMetadata(addon_name, "X-Credits") or "Сарыч")
SetAboutInfo(L["Email"],    GetAddOnMetadata(addon_name, "X-Email") or "Artur91425@gmail.com", true)
SetAboutInfo(L["Website"],  GetAddOnMetadata(addon_name, "X-Website") or "https://vk.com/id65515748", true)
local localizations = GetAddOnMetadata(addon_name, "X-Localizations") or "enUS, ruRU"
local translations = localizations:gsub("enUS", ENUS):gsub("deDE", DEDE):gsub("frFR", FRFR):gsub("koKR", KOKR):gsub("ruRU", RURU):gsub("zhCN", ZHCN):gsub("zhTW", ZHTW):gsub("esES", ESES):gsub("esMX", ESMX)
SetAboutInfo(L["Localizations"], translations)

config.enabled = CreateCheckButton('$parentEnableCheckbox', config, L["Enable addon"])
config.enabled:SetPoint('LEFT', config.title, 'RIGHT', 10, 0)

local container = CreateFrame('Frame', '$parentContainer', config)
config.container = container
container:SetPoint('TOPLEFT', InterfaceOptionsFramePanelContainer, 'TOPLEFT', 10, -84)
container:SetPoint('BOTTOMRIGHT', InterfaceOptionsFramePanelContainer, 'BOTTOMRIGHT', -10, 10)

container.TopLeft = container:CreateTexture(nil, 'BORDER')
container.TopLeft:SetTexture([[Interface\Tooltips\UI-Tooltip-Border]])
container.TopLeft:SetWidth(16)
container.TopLeft:SetHeight(16)
container.TopLeft:SetPoint('TOPLEFT')
container.TopLeft:SetTexCoord(.5, .625, 0, 1)
container.BottomLeft = container:CreateTexture(nil, 'BORDER')
container.BottomLeft:SetTexture([[Interface\Tooltips\UI-Tooltip-Border]])
container.BottomLeft:SetWidth(16)
container.BottomLeft:SetHeight(16)
container.BottomLeft:SetPoint('BOTTOMLEFT')
container.BottomLeft:SetTexCoord(.75, .875, 0, 1)
container.BottomRight = container:CreateTexture(nil, 'BORDER')
container.BottomRight:SetTexture([[Interface\Tooltips\UI-Tooltip-Border]])
container.BottomRight:SetWidth(16)
container.BottomRight:SetHeight(16)
container.BottomRight:SetPoint('BOTTOMRIGHT')
container.BottomRight:SetTexCoord(.875, 1, 0, 1)
container.TopRight = container:CreateTexture(nil, 'BORDER')
container.TopRight:SetTexture([[Interface\Tooltips\UI-Tooltip-Border]])
container.TopRight:SetWidth(16)
container.TopRight:SetHeight(16)
container.TopRight:SetPoint('TOPRIGHT')
container.TopRight:SetTexCoord(.625, .75, 0, 1)
container.Left = container:CreateTexture(nil, 'BORDER')
container.Left:SetTexture([[Interface\Tooltips\UI-Tooltip-Border]])
container.Left:SetPoint('TOPLEFT', container.TopLeft, 'BOTTOMLEFT')
container.Left:SetPoint('BOTTOMRIGHT', container.BottomLeft, 'TOPRIGHT')
container.Left:SetTexCoord(0, .125, 0, 1)
container.Right = container:CreateTexture(nil, 'BORDER')
container.Right:SetTexture([[Interface\Tooltips\UI-Tooltip-Border]])
container.Right:SetPoint('TOPLEFT', container.TopRight, 'BOTTOMLEFT')
container.Right:SetPoint('BOTTOMRIGHT', container.BottomRight, 'TOPRIGHT')
container.Right:SetTexCoord(.125, .25, 0, 1)
container.Bottom = container:CreateTexture(nil, 'BORDER')
container.Bottom:SetTexture([[Interface\Tooltips\UI-Tooltip-Border]])
container.Bottom:SetPoint('BOTTOMLEFT', container.BottomLeft, 'BOTTOMRIGHT')
container.Bottom:SetPoint('BOTTOMRIGHT', container.BottomRight, 'BOTTOMLEFT')
container.Bottom:SetTexCoord(.8, .95, 0, 1)
container.SpacerLeft = container:CreateTexture(nil, 'BORDER')
container.SpacerLeft:SetTexture([[Interface\OptionsFrame\UI-OptionsFrame-Spacer]])
container.SpacerLeft:SetPoint('LEFT', container.TopLeft, 'RIGHT', 0, 7)
container.SpacerRight = container:CreateTexture(nil, 'BORDER')
container.SpacerRight:SetTexture([[Interface\OptionsFrame\UI-OptionsFrame-Spacer]])
container.SpacerRight:SetPoint('RIGHT', container.TopRight, 'LEFT', 0, 7)

container.tabs = {}
container.frames = {}

-- General tab
---------------------------------------------------
local general_frame, general_tab = CreateTabFrame(container, L["General"])

general_frame.CACHE_GENERAL_SETTINGS = {loot_settings = {}}
general_frame.item_quality_label = general_frame:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
general_frame.item_quality_label:SetText(L["Item settings for quality"])
general_frame.item_quality_label:SetPoint('TOPLEFT', 10, -20)
general_frame.item_quality = CreateFrame('Frame', '$parentItemQualityDropdown', general_frame, 'UIDropDownMenuTemplate')
general_frame.item_quality:SetPoint('LEFT', general_frame.item_quality_label, 'RIGHT', 0, -2)

UIDropDownMenu_Initialize(general_frame.item_quality, function()
  for i = ITEM_QUALITY_UNCOMMON, ITEM_QUALITY_EPIC do
    local info = UIDropDownMenu_CreateInfo()
    info.text = _G['ITEM_QUALITY'..i..'_DESC']
    info.colorCode = ITEM_QUALITY_COLORS[i].hex
    info.value = i
    info.func = function(self)
      general_frame:UpdateConfig(general_frame.CACHE_GENERAL_SETTINGS, self.value)
    end
    UIDropDownMenu_AddButton(info)
  end
end)
UIDropDownMenu_SetWidth(general_frame.item_quality, 100)
UIDropDownMenu_JustifyText(general_frame.item_quality, 'LEFT')

general_frame.item_quality_enable = CreateCheckButton('$parentItemQualityEnableCheckbox', general_frame, L["Enable this quality"], L["Enable addon for items of this quality."])
general_frame.item_quality_enable:SetPoint('TOPLEFT', general_frame.item_quality_label, 'BOTTOMLEFT', 8, -10)

general_frame.only_boe = CreateCheckButton('$parentOnlyBOECheckbox', general_frame, L["Only BOE"], L["Enable only for BOE items."])
general_frame.only_boe:SetPoint('LEFT', general_frame.item_quality_enable, 'RIGHT', 180, 0)

general_frame.need_looter = CreateCheckButton('$parentNeedLooterCheckbox', general_frame, L["Mode '%s'"]:format(NEED), L["If available, click on '%s' for all items."]:format(NEED))
general_frame.need_looter:SetPoint('TOPLEFT', general_frame.item_quality_enable, 'BOTTOMLEFT', 0, -20)

general_frame.greed_looter = CreateCheckButton('$parentGreedLooterCheckbox', general_frame, L["Mode '%s'"]:format(GREED), L["If available, click on '%s' for all items."]:format(GREED))
general_frame.greed_looter:SetPoint('TOPLEFT', general_frame.need_looter, 'BOTTOMLEFT', 0, -4)

general_frame.disenchant_looter = CreateCheckButton('$parentDisenchantLooterCheckbox', general_frame, L["Mode '%s'"]:format(ROLL_DISENCHANT), L["If available, click on '%s' for all items."]:format(ROLL_DISENCHANT))
general_frame.disenchant_looter:SetPoint('TOPLEFT', general_frame.greed_looter, 'BOTTOMLEFT', 0, -4)

general_frame.smart_disenchant = {}
general_frame.smart_disenchant.only_boe = CreateRadioButton('$parentSmartDisenchantOnlyBOECheckbox', general_frame, L["Enable 'smart' disenchant (only BOE)"], L["SMART_DISENCHANT_ONLY_BOE"])
general_frame.smart_disenchant.only_boe:SetPoint('TOPLEFT', general_frame.disenchant_looter, 'BOTTOMLEFT', 14, -2)

general_frame.smart_disenchant.with_dis = CreateRadioButton('$parentSmartDisenchantWithCheckbox', general_frame, L["Enable 'smart' disenchant (with enchant)"], L["SMART_DISENCHANT_WITH_DESC"])
general_frame.smart_disenchant.with_dis:SetPoint('TOP', general_frame.smart_disenchant.only_boe, 'BOTTOM', 0, -4)

general_frame.smart_disenchant.without_dis = CreateRadioButton('$parentSmartDisenchantWithoutCheckbox', general_frame, L["Enable 'smart' disenchant (without enchant)"], L["SMART_DISENCHANT_WITHOUT_DESC"])
general_frame.smart_disenchant.without_dis:SetPoint('TOP', general_frame.smart_disenchant.only_boe, 'BOTTOM', 0, -4)



general_frame.example = CreateFrame('Frame', '$parentExample', general_frame)
general_frame.example:SetPoint('TOPLEFT', general_frame, 'BOTTOMLEFT', 0, 75)
general_frame.example:SetPoint('BOTTOMRIGHT', 0, 0)
general_frame.example.label = general_frame.example:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
general_frame.example.label:SetPoint('TOPLEFT', 10, 0)
general_frame.example.label:SetPoint('BOTTOMRIGHT', general_frame.example, 'TOPRIGHT', -10, -30)
general_frame.example.label:SetJustifyH('LEFT')
general_frame.example.label:SetJustifyV('BOTTOM')
general_frame.example.text = general_frame.example:CreateFontString(nil, 'ARTWORK', 'GameFontWhite')
general_frame.example.text:SetWidth(general_frame.example:GetWidth() - 5*2)
general_frame.example.text:SetPoint('TOPLEFT', 20, -35)
general_frame.example.text:SetPoint('BOTTOMRIGHT', general_frame.example, 'TOPRIGHT', -20, -75)
general_frame.example.text:SetJustifyH('LEFT')
general_frame.example.text:SetJustifyV('TOP')

-- ExceptionList tab
---------------------------------------------------
local exception_frame = CreateTabFrame(container, L["Exception list"])

exception_frame.sub_btns = {
  size = 18,
  offset = 2,
  [1] = {
    key = 'remove',
    text = DELETE,
    normal = [[Interface\GLUES\LOGIN\Glues-CheckBox-Check]],
    highlight = [[Interface\GLUES\LOGIN\Glues-CheckBox-Check]],
    offset = 6,
    func = true,
  },
  [2] = {
    key = 'pass',
    text = PASS,
    normal = [[Interface\Buttons\UI-GroupLoot-Pass-Up]],
    highlight = [[Interface\Buttons\UI-GroupLoot-Pass-Up]],
    offset = 0,
  },
  [3] = {
    key = 'disenchant',
    text = ROLL_DISENCHANT,
    normal = [[Interface\Buttons\UI-GroupLoot-DE-Up]],
    highlight = [[Interface\Buttons\UI-GroupLoot-DE-Highlight]],
    offset = 0,
  },
  [4] = {
    key = 'greed',
    text = GREED,
    normal = [[Interface\Buttons\UI-GroupLoot-Coin-Up]],
    highlight = [[Interface\Buttons\UI-GroupLoot-Coin-Highlight]],
    offset = 0,
  },
  [5] = {
    key = 'need',
    text = NEED,
    normal = [[Interface\Buttons\UI-GroupLoot-Dice-Up]],
    highlight = [[Interface\Buttons\UI-GroupLoot-Dice-Highlight]],
    offset = 0,
  },
  [6] = {
    key = 'ignore',
    text = L["Ignore"],
    normal = [[Interface\Glues\CharacterSelect\Glues-AddOn-Icons]],
    highlight = [[Interface\Glues\CharacterSelect\Glues-AddOn-Icons]],
    texcoord = {minX = 0.75, maxX = 1, minY = 0, maxY = 1},
    offset = 0,
  },
}

local sort_types = {
  [1] = {
    ['ascending']  = L["Ascending"],
    ['descending'] = L["Descending"],
  },
  [2] = {
    ['id']     = 'ID',
    ['name']   = L["Name"],
    ['rarity'] = L["Rarity"],
    ['level']  = L["Level"],
    ['price']  = L["Price"],
  }
}
exception_frame.sorting = {}
exception_frame.sorting.label = exception_frame:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
exception_frame.sorting.label:SetText(L["Sorting"]..':')
exception_frame.sorting.label:SetPoint('TOPLEFT', 10, -20)
for i = 1, #sort_types do
  exception_frame.sorting[i] = CreateFrame('Frame', '$parentSortingDropdown'..i, exception_frame, 'UIDropDownMenuTemplate')
  if i == 1 then
    exception_frame.sorting[i]:SetPoint('LEFT', exception_frame.sorting.label, 'RIGHT', 6, -2)
  else
    exception_frame.sorting[i]:SetPoint('LEFT', exception_frame.sorting[(i-1)], 'RIGHT', 100, 0)
  end
  UIDropDownMenu_Initialize(exception_frame.sorting[i], function()
    for k, v in pairs(sort_types[i]) do
      local info = UIDropDownMenu_CreateInfo()
      info.arg1 = i
      info.text = v
      info.value = k
      info.func = function(self, sort_type)
        UIDropDownMenu_SetSelectedValue(exception_frame.sorting[sort_type], self.value)
        exception_frame:ExceptionList_Update('update_sort')
      end
      UIDropDownMenu_AddButton(info)
    end
  end)
  _G[exception_frame.sorting[i]:GetName()..'Button']:HookScript('OnClick', function()
    if exception_frame.edit:HasFocus() then exception_frame.edit:ClearFocus() end
  end)
end

exception_frame.edit = CreateFrame('EditBox', '$parentInput', exception_frame, 'InputBoxTemplate')
exception_frame.edit:SetPoint('TOPLEFT', exception_frame, 14, -50)
exception_frame.edit:SetPoint('TOPRIGHT', exception_frame, -10, -50)
exception_frame.edit:SetHeight(8)
exception_frame.edit:SetText(L["Add an item"])
exception_frame.edit:SetFontObject('GameFontDisable')
exception_frame.edit:SetAutoFocus(false)
exception_frame.edit:SetScript('OnEnter', function(self)
  GameTooltip:SetOwner(self, 'ANCHOR_TOPLEFT')
  GameTooltip:SetText(L["Drag the item, insert the link to the item, or enter the item ID to add it to the list."], nil, nil, nil, nil, 1)
end)
exception_frame.edit:SetScript('OnLeave', function(self)
  GameTooltip:Hide()
end)
exception_frame.edit:SetScript('OnEditFocusGained', function(self)
  if CursorHasItem() then
    self:GetScript('OnReceiveDrag')(self)
    self:ClearFocus()
  else
    self:SetFontObject('GameFontWhite')
    self:SetText('')
  end
end)
exception_frame.edit:SetScript('OnEditFocusLost', function(self)
  self:SetFontObject('GameFontDisable')
  self:SetText(L["Add an item"])
end)
exception_frame.edit:SetScript('OnEnterPressed', function(self)
  local text = self:GetText()
  self:ClearFocus()
  if not text or text == '' then return end
  local id = text:match('item:(%d+)') or (select(2, GetItemInfo(text)) or ''):match('item:(%d+)') or text
  id = tonumber(id)
  if not id or exception_frame.exception_list[id] then return end
  exception_frame:AddExceptionItem(id, 'need', true)
end)
exception_frame.edit:SetScript('OnReceiveDrag', function(self)
  local type, id = GetCursorInfo()
  if type ~= 'item' or exception_frame.exception_list[id] then return end
  ClearCursor()
  exception_frame:AddExceptionItem(id, 'need', true)
end)

exception_frame.btns = {}
local btns = exception_frame.btns
local EXCEPTIONLIST_BTN_HEIGHT = 16

function exception_frame:CalculateExceptionButtonsToDisplay(frame_height)
  local visible_texture_offset = 14
  frame_height = frame_height or self:GetHeight()
  local free_height = frame_height - abs(select(5, self.edit:GetPoint())) - self.edit:GetHeight() - visible_texture_offset

  return floor(free_height/EXCEPTIONLIST_BTN_HEIGHT)
end

function exception_frame:CreateExceptionListButton(i)
  local btns = self.btns or {}
  if not btns[i] then
    btns[i] = CreateFrame('Button', '$parentButton'..i, self, nil, i)
    btns[i]:Hide()
    btns[i]:SetHeight(EXCEPTIONLIST_BTN_HEIGHT)
    btns[i]:SetHighlightTexture([[Interface\QuestFrame\UI-QuestTitleHighlight]], 'ADD')
    if i == 1 then
      btns[i]:SetPoint('TOPLEFT', self.edit, 'BOTTOMLEFT', -6, -10)
      btns[i]:SetPoint('TOPRIGHT', self.edit, 'BOTTOMRIGHT', 0, -10)
    else
      btns[i]:SetPoint('TOPLEFT', btns[(i-1)], 'BOTTOMLEFT', 0, 0)
      btns[i]:SetPoint('TOPRIGHT', btns[(i-1)], 'BOTTOMRIGHT', 0, 0)
    end
    btns[i]:SetScript('OnEnter', function(self)
      GameTooltip:SetOwner(self, 'ANCHOR_TOPLEFT')
      if not self.link then
        GameTooltip:SetText(L["To try to request data from the server, click on this item."], nil, nil, nil, nil, 1)
      else
        GameTooltip:SetHyperlink(self.link)
      end
    end)
    btns[i]:SetScript('OnLeave', function(self)
      GameTooltip:Hide()
    end)
    btns[i]:SetScript('OnClick', function(self)
      if IsModifiedClick() and self.link then
        HandleModifiedItemClick(self.link)
      elseif not self.link then
        exception_frame:UpdateExceptionButton(self, true)
      end
    end)

    btns[i].sub_buttons = CreateFrame('Button', '$parent_SubFrame', btns[i])
    btns[i].sub_buttons:SetPoint("TOPRIGHT", 0, 0)
    btns[i].sub_buttons:SetPoint("BOTTOMRIGHT", 0, 0)
    btns[i].sub_buttons:SetWidth(0) -- dynamic width dependings of sub buttons count
    btns[i].sub_buttons:SetScript('OnEnter', function(self)
      GameTooltip:Hide()
      btns[i]:LockHighlight()
    end)
    btns[i].sub_buttons:SetScript('OnLeave', function(self)
      btns[i]:UnlockHighlight()
    end)

    for j = 1, #self.sub_btns do
      local v = self.sub_btns[j]
      btns[i].sub_buttons[v.key] = CreateFrame('Button', '$parent_'..v.key, btns[i].sub_buttons, nil, j)
      btns[i].sub_buttons[v.key].alpha = 1
      btns[i].sub_buttons[v.key].desaturated = false
      btns[i].sub_buttons[v.key]:SetSize(self.sub_btns.size, self.sub_btns.size)
      if j == 1 then
        btns[i].sub_buttons[v.key]:SetPoint('RIGHT', 0, 0)
      else
        btns[i].sub_buttons[v.key]:SetPoint('RIGHT', btns[i].sub_buttons[self.sub_btns[(j-1)].key], 'LEFT', -self.sub_btns[(j-1)].offset, 0)
      end
      btns[i].sub_buttons[v.key]:SetNormalTexture(v.normal)
      btns[i].sub_buttons[v.key]:SetHighlightTexture(v.highlight, 'ADD')
      btns[i].sub_buttons[v.key].normal_texture = btns[i].sub_buttons[v.key]:GetNormalTexture()
      btns[i].sub_buttons[v.key].highlight_texture = btns[i].sub_buttons[v.key]:GetHighlightTexture()
      if v.texcoord then
        btns[i].sub_buttons[v.key].normal_texture:SetTexCoord(v.texcoord.minX, v.texcoord.maxX, v.texcoord.minY, v.texcoord.maxY)
        btns[i].sub_buttons[v.key].highlight_texture:SetTexCoord(v.texcoord.minX, v.texcoord.maxX, v.texcoord.minY, v.texcoord.maxY)
      end
      btns[i].sub_buttons[v.key]:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_TOPLEFT')
        GameTooltip:SetText(v.text)
        self:SetAlpha(1)
        self.normal_texture:SetDesaturated(false)
        btns[i]:LockHighlight()
      end)
      btns[i].sub_buttons[v.key]:SetScript('OnLeave', function(self)
        GameTooltip:Hide()
        self:SetAlpha(self.alpha)
        self.normal_texture:SetDesaturated(self.desaturated)
        btns[i]:UnlockHighlight()
      end)
      if not self.sub_btns[j].func then
        btns[i].sub_buttons[v.key]:SetScript('OnClick', function(self)
          exception_frame.exception_list[btns[i].itemID] = exception_frame.sub_btns[self:GetID()].key
          exception_frame:UpdateRollButtons(btns[i])
        end)
      end

      -- recalculate sub_buttons width
      btns[i].sub_buttons:SetWidth(btns[i].sub_buttons:GetWidth() + self.sub_btns.size + self.sub_btns[j].offset)
    end

    btns[i].sub_buttons.remove:SetScript('OnClick', function(self)
      PlaySoundFile([[Sound\Item\FoleySounds\PlateFoley02.wav]])
      exception_frame:RemoveExceptionItem(btns[i].itemID)
    end)

    btns[i].text = btns[i]:CreateFontString('$parentText', 'BORDER', 'GameFontNormal')
    btns[i].text:SetPoint('LEFT', 0, 0)
    btns[i].text:SetPoint('RIGHT', btns[i].sub_buttons, "LEFT", 0, 0)
    btns[i].text:SetHeight(EXCEPTIONLIST_BTN_HEIGHT)
    btns[i].text:SetJustifyH('LEFT')
    btns[i].text:SetJustifyV('MIDDLE')
  end
  return btns[i]
end

local EXCEPTIONLIST_TO_DISPLAY = exception_frame:CalculateExceptionButtonsToDisplay()
for i = 1, EXCEPTIONLIST_TO_DISPLAY do
  exception_frame:CreateExceptionListButton(i)
end

exception_frame.scroll = CreateFrame('ScrollFrame', '$parentScrollFrame', exception_frame, 'FauxScrollFrameTemplate')
exception_frame.scroll:SetPoint('TOPLEFT', btns[1], 0, 0)
exception_frame.scroll:SetPoint('BOTTOMRIGHT', btns[EXCEPTIONLIST_TO_DISPLAY], -2, 0)
exception_frame.scroll:SetScript('OnShow', function(self)
  btns[1]:SetPoint('TOPRIGHT', exception_frame.edit, 'BOTTOMRIGHT', -16, -12)
end)
exception_frame.scroll:SetScript('OnHide', function(self)
  btns[1]:SetPoint('TOPRIGHT', exception_frame.edit, 'BOTTOMRIGHT', 0, -12)
end)
exception_frame.scroll:SetScript('OnVerticalScroll', function(self, offset)
  FauxScrollFrame_OnVerticalScroll(self, offset, EXCEPTIONLIST_BTN_HEIGHT, exception_frame.ExceptionList_Update)
end)

exception_frame:SetScript("OnSizeChanged", function(self, width, height)
  EXCEPTIONLIST_TO_DISPLAY = self:CalculateExceptionButtonsToDisplay(height)
  local num_btns = #self.btns
  if EXCEPTIONLIST_TO_DISPLAY > num_btns then
    for i=num_btns+1, EXCEPTIONLIST_TO_DISPLAY do
      self:CreateExceptionListButton(i)
    end
  else
    for i=EXCEPTIONLIST_TO_DISPLAY+1, num_btns do
      self:ClearExceptionButton(i)
    end
  end
  self.scroll:SetPoint('BOTTOMRIGHT', self.btns[EXCEPTIONLIST_TO_DISPLAY], -2, 0)
  self:ExceptionList_Update()
end)

-- Modules tab
---------------------------------------------------
local modules_frame = CreateTabFrame(container, L["Modules"])

modules_frame.spam_filter = {}
modules_frame.spam_filter.enabled = CreateCheckButton('$parentSpamFilterEnabledCheckbox', modules_frame, L["Enable loot message filter"], L["ATTENTION! If you use any addons that analyze the messages listed below, then when this option is enabled, these addons will not work!"])
modules_frame.spam_filter.enabled:SetPoint('TOPLEFT', 20, -20)

modules_frame.spam_filter.clicked_btn = CreateCheckButton('$parentClickedButtonsCheckbox', modules_frame, L["Disable button click messages"], L["Disables the printing of messages who clicked which button for each item."])
modules_frame.spam_filter.clicked_btn:SetPoint('TOPLEFT', modules_frame.spam_filter.enabled, 'BOTTOMLEFT', 14, -2)

modules_frame.spam_filter.roll_result = CreateCheckButton('$parentRollResultsCheckbox', modules_frame, L["Disable roll result messages"], L["Disables printing roll result messages."])
modules_frame.spam_filter.roll_result:SetPoint('TOP', modules_frame.spam_filter.clicked_btn, 'BOTTOM', 0, -4)

modules_frame.spam_filter.won = CreateCheckButton('$parentWonCheckbox', modules_frame, L["Disable win messages"], L["Disables printing of messages who won the item."])
modules_frame.spam_filter.won:SetPoint('TOP', modules_frame.spam_filter.roll_result, 'BOTTOM', 0, -4)

-- functions
---------------------------------------------------
local function AddItemToGameCache(self, id)
  GameTooltip:SetOwner(self, 'ANCHOR_NONE')
  GameTooltip:SetHyperlink('item:'..id) -- try adding an item to the cache so that GetItemInfo does not return nil!
  GameTooltip:Hide()
end

local function sort_ascending(a, b, sort_type) return (a[sort_type] and b[sort_type]) and a[sort_type] < b[sort_type] end
local function sort_descending (a, b, sort_type) return (a[sort_type] and b[sort_type]) and a[sort_type] > b[sort_type] end
local function SortExceptionTable(t)
  local sort_type1, sort_type2 = UIDropDownMenu_GetSelectedValue(exception_frame.sorting[1]), UIDropDownMenu_GetSelectedValue(exception_frame.sorting[2])
  local sort_func = sort_type1 == 'ascending' and sort_ascending or sort_descending
  table_sort(t, function(a, b) return sort_func(a, b, sort_type2) end)
  return t
end

local function PrepareExceptionList()
  local n_t = {}
  for id in pairs(exception_frame.exception_list) do
    local itemName, _, itemRarity, itemLevel, _, _, _, _, _, _, itemSellPrice = GetItemInfo(id)
    n_t[#n_t+1] = {
      id = id,
      name = itemName,
      rarity = itemRarity,
      level = itemLevel,
      price = itemSellPrice
    }
  end
  return n_t
end

function general_frame:UpdateExampleText()
  local text = C.EXCEPTION_COLORED
  local separator = ' -> '
  local suffix = self.only_boe:GetChecked() and ' ('..L["Only BOE"]..')' or ''
  local NEED = C.NEED_COLORED
  local GREED = C.GREED_COLORED
  local ROLL_DISENCHANT = C.ROLL_DISENCHANT_COLORED
  local PASS = C.PASS_COLORED

  if self.item_quality_enable:GetChecked() then
    if self.disenchant_looter:GetChecked() then
      if self.smart_disenchant.with_dis:GetChecked() and C.HAS_DISENCHANT then
        if self.need_looter:GetChecked() then
          text = text..separator..NEED..suffix
        end
        text = text..separator..ROLL_DISENCHANT..suffix
      elseif self.smart_disenchant.without_dis:GetChecked() and not self.only_boe:GetChecked() then
        text = text..separator..ROLL_DISENCHANT..' ('..L["Only BOP"]..')'
        if self.need_looter:GetChecked() then
          text = text..separator..NEED..suffix
        end
        if self.greed_looter:GetChecked() then
          text = text..separator..GREED..suffix
        else
          text = text..separator..PASS..suffix
        end
      elseif self.smart_disenchant.only_boe:GetChecked() and self.only_boe:GetChecked() then
        if self.need_looter:GetChecked() then
          text = text..separator..NEED..suffix
        end
        text = text..separator..ROLL_DISENCHANT..suffix
        if self.greed_looter:GetChecked() then
          text = text..separator..GREED..suffix
        else
          text = text..separator..PASS..suffix
        end
      else
        text = text..separator..ROLL_DISENCHANT..suffix
        if self.need_looter:GetChecked() then
          text = text..separator..NEED..suffix
        end
        if self.greed_looter:GetChecked() then
          text = text..separator..GREED..suffix
        else
          text = text..separator..PASS..suffix
        end
      end
    else
      if self.need_looter:GetChecked() then
        text = text..separator..NEED..suffix
      end
      if self.greed_looter:GetChecked() then
        text = text..separator..GREED..suffix
      else
        text = text..separator..PASS..suffix
      end
    end
  end
  self.example.text:SetText(text)
end

function general_frame:UpdateCacheSettings(state, field1, field2)
  local cur_quality = UIDropDownMenu_GetSelectedValue(self.item_quality)
  
  -- Use default quality if none is selected
  if not cur_quality then
    -- ITEM_QUALITY_UNCOMMON = 2 in WoW API
    cur_quality = (ITEM_QUALITY_UNCOMMON and ITEM_QUALITY_UNCOMMON) or 2  -- Default to Uncommon (green) quality
  end
  
  -- Ensure cur_quality is a valid number
  if type(cur_quality) ~= "number" then
    cur_quality = 2  -- Fallback to Uncommon quality
  end
  
  -- Ensure loot_settings table exists
  if not self.CACHE_GENERAL_SETTINGS.loot_settings then
    self.CACHE_GENERAL_SETTINGS.loot_settings = {}
  end
  
  -- Initialize quality_settings if it doesn't exist
  if not self.CACHE_GENERAL_SETTINGS.loot_settings[cur_quality] then
    -- Try to get from defaultDB first
    if private.defaultDB and private.defaultDB.loot_settings and private.defaultDB.loot_settings[cur_quality] then
      self.CACHE_GENERAL_SETTINGS.loot_settings[cur_quality] = CopyTable(private.defaultDB.loot_settings[cur_quality])
    else
      -- Create a safe default structure if even defaultDB doesn't have it
      self.CACHE_GENERAL_SETTINGS.loot_settings[cur_quality] = {
        enabled = false,
        only_boe = true,
        need_looter = false,
        greed_looter = true,
        disenchant_looter = false,
        smart_disenchant = {
          with_dis = false,
          without_dis = false,
          only_boe = false,
        },
      }
    end
  end
  
  -- Ensure nested structure exists for field2 case
  if field2 then
    if not self.CACHE_GENERAL_SETTINGS.loot_settings[cur_quality][field1] then
      self.CACHE_GENERAL_SETTINGS.loot_settings[cur_quality][field1] = {}
    end
    self.CACHE_GENERAL_SETTINGS.loot_settings[cur_quality][field1][field2] = GetBoolean(state)
  else
    self.CACHE_GENERAL_SETTINGS.loot_settings[cur_quality][field1] = GetBoolean(state)
  end
end

function general_frame.item_quality_enable.setFunc(state)
  state = GetBoolean(state)
  general_frame.only_boe:SetEnabled(state)
  general_frame.need_looter:SetEnabled(state)
  general_frame.disenchant_looter:SetEnabled(state)
  if state then
    if general_frame.disenchant_looter:GetChecked() then
      general_frame.greed_looter:SetEnabled(GetBoolean(not general_frame.smart_disenchant.with_dis:GetChecked()))
      general_frame.smart_disenchant.with_dis:SetEnabled(C.HAS_DISENCHANT)
      general_frame.smart_disenchant.without_dis:SetEnabled(GetBoolean(not general_frame.only_boe:GetChecked()))
      general_frame.smart_disenchant.only_boe:SetEnabled(GetBoolean(general_frame.only_boe:GetChecked()))
    else
      general_frame.greed_looter:SetEnabled(true)
      general_frame.smart_disenchant.with_dis:SetEnabled(false)
      general_frame.smart_disenchant.without_dis:SetEnabled(false)
      general_frame.smart_disenchant.only_boe:SetEnabled(false)
    end
  else
    general_frame.greed_looter:SetEnabled(false)
    general_frame.smart_disenchant.with_dis:SetEnabled(false)
    general_frame.smart_disenchant.without_dis:SetEnabled(false)
    general_frame.smart_disenchant.only_boe:SetEnabled(false)
  end
  general_frame:UpdateCacheSettings(state, 'enabled')
  general_frame:UpdateExampleText()
end

function general_frame.only_boe.setFunc(state)
  state = GetBoolean(state)
  general_frame.smart_disenchant.with_dis:SetEnabled(general_frame.disenchant_looter:GetChecked() and C.HAS_DISENCHANT)
  general_frame.smart_disenchant.without_dis:SetEnabled(general_frame.disenchant_looter:GetChecked() and not state)
  general_frame.smart_disenchant.only_boe:SetEnabled(general_frame.disenchant_looter:GetChecked() and state)
  general_frame:UpdateCacheSettings(state, 'only_boe')
  general_frame:UpdateExampleText()
end

function general_frame.need_looter.setFunc(state)
  state = GetBoolean(state)
  general_frame:UpdateCacheSettings(state, 'need_looter')
  general_frame:UpdateExampleText()
end

function general_frame.greed_looter.setFunc(state)
  state = GetBoolean(state)
  general_frame:UpdateCacheSettings(state, 'greed_looter')
  general_frame:UpdateExampleText()
end

function general_frame.disenchant_looter.setFunc(state)
  state = GetBoolean(state)
  general_frame.greed_looter:SetEnabled(not state or state and not general_frame.smart_disenchant.with_dis:GetChecked())
  general_frame.smart_disenchant.with_dis:SetEnabled(state and C.HAS_DISENCHANT)
  general_frame.smart_disenchant.without_dis:SetEnabled(state and not general_frame.only_boe:GetChecked())
  general_frame.smart_disenchant.only_boe:SetEnabled(state and general_frame.only_boe:GetChecked())
  general_frame:UpdateCacheSettings(state, 'disenchant_looter')
  general_frame:UpdateExampleText()
end

function general_frame.smart_disenchant.with_dis.setFunc(state)
  state = GetBoolean(state)
  if state then
    general_frame.smart_disenchant.without_dis:SetChecked(false)
    general_frame.smart_disenchant.only_boe:SetChecked(false)

    general_frame.greed_looter:SetEnabled(false)

    general_frame:UpdateCacheSettings(false, 'smart_disenchant', 'without_dis')
    general_frame:UpdateCacheSettings(false, 'smart_disenchant', 'only_boe')
  else
    general_frame.greed_looter:SetEnabled(true)
  end
  general_frame:UpdateCacheSettings(state, 'smart_disenchant', 'with_dis')
  general_frame:UpdateExampleText()
end

function general_frame.smart_disenchant.without_dis.setFunc(state)
  state = GetBoolean(state)
  if state then
    general_frame.smart_disenchant.with_dis:SetChecked(false)
    general_frame.smart_disenchant.only_boe:SetChecked(false)

    general_frame.greed_looter:SetEnabled(true)

    general_frame:UpdateCacheSettings(false, 'smart_disenchant', 'with_dis')
    general_frame:UpdateCacheSettings(false, 'smart_disenchant', 'only_boe')
  end
  general_frame:UpdateCacheSettings(state, 'smart_disenchant', 'without_dis')
  general_frame:UpdateExampleText()
end

function general_frame.smart_disenchant.only_boe.setFunc(state)
  state = GetBoolean(state)
  if state then
    general_frame.smart_disenchant.with_dis:SetChecked(false)
    general_frame.smart_disenchant.without_dis:SetChecked(false)

    general_frame.greed_looter:SetEnabled(true)

    general_frame:UpdateCacheSettings(false, 'smart_disenchant', 'with_dis')
    general_frame:UpdateCacheSettings(false, 'smart_disenchant', 'without_dis')
  end
  general_frame:UpdateCacheSettings(state, 'smart_disenchant', 'only_boe')
  general_frame:UpdateExampleText()
end

function general_frame:UpdateConfig(db, cur_quality)
  cur_quality = cur_quality or UIDropDownMenu_GetSelectedValue(self.item_quality) or ITEM_QUALITY_UNCOMMON
  UIDropDownMenu_SetSelectedValue(self.item_quality, cur_quality)
  UIDropDownMenu_SetText(self.item_quality, ITEM_QUALITY_COLORS[cur_quality].hex.._G['ITEM_QUALITY'..cur_quality..'_DESC']..'|r')

  local quality_settings = db.loot_settings[cur_quality]
  -- Initialize quality_settings if it doesn't exist
  if not quality_settings then
    -- Try to get from defaultDB first
    if private.defaultDB.loot_settings[cur_quality] then
      quality_settings = CopyTable(private.defaultDB.loot_settings[cur_quality])
      db.loot_settings[cur_quality] = quality_settings
    else
      -- Create a safe default structure if even defaultDB doesn't have it
      quality_settings = {
        enabled = false,
        only_boe = true,
        need_looter = false,
        greed_looter = true,
        disenchant_looter = false,
        smart_disenchant = {
          with_dis = false,
          without_dis = false,
          only_boe = false,
        },
      }
      db.loot_settings[cur_quality] = quality_settings
    end
  end
  self.item_quality_enable:SetChecked(quality_settings.enabled)
  self.only_boe:SetChecked(quality_settings.only_boe)
  self.need_looter:SetChecked(quality_settings.need_looter)
  self.greed_looter:SetChecked(quality_settings.greed_looter)
  self.disenchant_looter:SetChecked(quality_settings.disenchant_looter)
  self.smart_disenchant.with_dis:SetChecked(quality_settings.smart_disenchant.with_dis)
  self.smart_disenchant.without_dis:SetChecked(quality_settings.smart_disenchant.without_dis)
  self.smart_disenchant.only_boe:SetChecked(quality_settings.smart_disenchant.only_boe)

  -- update example label
  self.example.label:SetFormattedText(L["Button priority for %s quality"].." (|cffFFFFFF"..L["if available"]..'|r):', UIDropDownMenu_GetText(self.item_quality))
  -- update enabled state for all checkboxes
  self.item_quality_enable.setFunc(quality_settings.enabled)
end

function general_frame:SaveChanges()
  self:Release_CacheSettingsTable()
end

function general_frame:Release_CacheSettingsTable()
  if not LootClickerDB then
    LootClickerDB = private.defaultDB
  end
  LootClickerDB.loot_settings = CopyTable(self.CACHE_GENERAL_SETTINGS.loot_settings)
end

function general_frame:Acquire_CacheSettingsTable(db)
  if not LootClickerDB then
    LootClickerDB = private.defaultDB
  end
  db = db or LootClickerDB.loot_settings
  self.CACHE_GENERAL_SETTINGS.loot_settings = CopyTable(db)
end

function exception_frame:AddExceptionItem(itemID, state, update_list)
  self.exception_list[itemID] = state or 'ignore'
  if update_list then
    self:ExceptionList_Update('update_items')
  end
end

function exception_frame:RemoveExceptionItem(itemID)
  self.exception_list[itemID] = nil
  self:ExceptionList_Update('update_items')
end

function exception_frame:UpdateExceptionButton(btn, update_tooltip)
  btn.link = select(2, GetItemInfo(btn.itemID)) or AddItemToGameCache(btn, btn.itemID)
  btn.text:SetText(btn.link or btn.itemID..' |cffB22222('..L["NO ITEM DATA"]..')|r')
  if update_tooltip and btn.link then
    GameTooltip:SetHyperlink(btn.link)
  end
end

function exception_frame:UpdateRollButtons(exception_btn)
  local exception = self.exception_list[exception_btn.itemID]
  for j = 1, #self.sub_btns do
    local v = self.sub_btns[j]
    exception_btn.sub_buttons[v.key].alpha = exception == v.key and 1 or .5
    exception_btn.sub_buttons[v.key].desaturated = exception ~= v.key

    exception_btn.sub_buttons[v.key]:SetAlpha(exception_btn.sub_buttons[v.key].alpha)
    exception_btn.sub_buttons[v.key].normal_texture:SetDesaturated(exception_btn.sub_buttons[v.key].desaturated)
  end
end

function exception_frame:ClearExceptionButton(i)
  -- clear old data and hide unused buttons
  self.btns[i]:Hide()
  self.btns[i].text:SetText("")
  self.btns[i].link = nil
  self.btns[i].index = nil
  self.btns[i].itemID = nil
end

function exception_frame:ExceptionList_Update(update_type)
  if update_type == 'update_items' then
    local exception_list = PrepareExceptionList()
    exception_frame.sorted_exception_list = SortExceptionTable(exception_list)
  elseif update_type == 'update_sort' and exception_frame.sorted_exception_list then
    exception_frame.sorted_exception_list = SortExceptionTable(exception_frame.sorted_exception_list)
  end
  if not exception_frame.sorted_exception_list then return end

  local offset = FauxScrollFrame_GetOffset(exception_frame.scroll)
  local num_items = #exception_frame.sorted_exception_list

  for i=1, EXCEPTIONLIST_TO_DISPLAY do
    local index = i + offset
    if index > num_items then
      exception_frame:ClearExceptionButton(i)
    else
      btns[i].index = index
      btns[i].itemID = exception_frame.sorted_exception_list[index].id

      exception_frame:UpdateExceptionButton(btns[i])
      exception_frame:UpdateRollButtons(btns[i])

      btns[i]:Show()
    end
  end

  FauxScrollFrame_Update(exception_frame.scroll, num_items, EXCEPTIONLIST_TO_DISPLAY, EXCEPTIONLIST_BTN_HEIGHT)
end

function exception_frame:PopulateExceptionList(itemsTable, status)
  for _,itemID in pairs(itemsTable) do
    if not exception_frame.exception_list[itemID] then
      exception_frame:AddExceptionItem(itemID, status)
    end
  end
  if not config:IsShown() then
    exception_frame:SaveChanges()
  end
  self:ExceptionList_Update('update_items')
end

function exception_frame:ClearExceptionList()
  self.exception_list = {}
  self:ExceptionList_Update('update_items')
end

function exception_frame:UpdateConfig(db)
  if self.edit:HasFocus() then self.edit:ClearFocus() end
  UIDropDownMenu_SetSelectedValue(self.sorting[1], db.exception_list.sort[1])
  UIDropDownMenu_SetText(self.sorting[1], sort_types[1][db.exception_list.sort[1]])
  UIDropDownMenu_SetSelectedValue(self.sorting[2], db.exception_list.sort[2])
  UIDropDownMenu_SetText(self.sorting[2], sort_types[2][db.exception_list.sort[2]])
  self.exception_list = CopyTable(db.exception_list.items)
  self:ExceptionList_Update('update_items')
end

function exception_frame:SaveChanges()
  if self.edit:HasFocus() then self.edit:ClearFocus() end
  if not LootClickerDB then
    LootClickerDB = private.defaultDB
  end
  LootClickerDB.exception_list.sort[1] = UIDropDownMenu_GetSelectedValue(self.sorting[1])
  LootClickerDB.exception_list.sort[2] = UIDropDownMenu_GetSelectedValue(self.sorting[2])
  LootClickerDB.exception_list.items = CopyTable(self.exception_list)
end

function modules_frame.spam_filter.enabled.setFunc(state)
  state = GetBoolean(state)
  modules_frame.spam_filter.clicked_btn:SetEnabled(state)
  modules_frame.spam_filter.roll_result:SetEnabled(state)
  modules_frame.spam_filter.won:SetEnabled(state)
end

function modules_frame:UpdateConfig(db)
  self.spam_filter.enabled:SetChecked(db.spam_filter.enabled)
  self.spam_filter.clicked_btn:SetChecked(db.spam_filter.clicked_btn)
  self.spam_filter.roll_result:SetChecked(db.spam_filter.roll_result)
  self.spam_filter.won:SetChecked(db.spam_filter.won)
  self.spam_filter.enabled.setFunc(db.spam_filter.enabled)
end

function modules_frame:SaveChanges()
  if not LootClickerDB then
    LootClickerDB = private.defaultDB
  end
  LootClickerDB.spam_filter.enabled = GetBoolean(self.spam_filter.enabled:GetChecked())
  LootClickerDB.spam_filter.clicked_btn = GetBoolean(self.spam_filter.clicked_btn:GetChecked())
  LootClickerDB.spam_filter.roll_result = GetBoolean(self.spam_filter.roll_result:GetChecked())
  LootClickerDB.spam_filter.won = GetBoolean(self.spam_filter.won:GetChecked())
  private:UpdateMessageEventFilterState()
end

function container:Tab_OnClick(tab)
  local prev_tab = PanelTemplates_GetSelectedTab(self)
  if prev_tab then
    self.frames[prev_tab]:Hide()
  end

  PanelTemplates_Tab_OnClick(tab, self) -- update selectedTab
  local cur_tab = PanelTemplates_GetSelectedTab(self)
  self.frames[cur_tab]:Show()

  self.SpacerLeft:SetPoint('RIGHT', self.tabs[cur_tab], 'BOTTOMLEFT', 11, 1)
  self.SpacerRight:SetPoint('LEFT', self.tabs[cur_tab], 'BOTTOMRIGHT', -11, 1)

  PlaySound('igCharacterInfoTab')
end

function config.enabled.setFunc(state)
  state = GetBoolean(state)
  config.container:SetShown(state)
  config.about:SetShown(not state)
end

function config:UpdateConfig(db)
  if not LootClickerDB then
    LootClickerDB = private.defaultDB
  end
  db = db or LootClickerDB
  self.enabled:SetChecked(db.enabled)
  self.enabled.setFunc(db.enabled)

  general_frame:UpdateConfig(db)
  exception_frame:UpdateConfig(db)
  modules_frame:UpdateConfig(db)
end

function config:SetDefaultSettings()
  general_frame:Acquire_CacheSettingsTable(private.defaultDB.loot_settings)
  self:UpdateConfig(private.defaultDB)
end

function config:SaveChanges()
  if not LootClickerDB then
    LootClickerDB = private.defaultDB
  end
  LootClickerDB.enabled = GetBoolean(self.enabled:GetChecked())

  general_frame:SaveChanges()
  exception_frame:SaveChanges()
  modules_frame:SaveChanges()

  -- it should be at the very end since the control passes to OnEnable or OnDisable and does not go back
  if LootClickerDB.enabled then
    LootClicker:OnEnable()
  else
    LootClicker:OnDisable()
  end
end

function config:CancelChanges()
  general_frame:Acquire_CacheSettingsTable()
  self:UpdateConfig()
end

function private:LoadConfig()
  general_frame.smart_disenchant.with_dis:SetShown(C.HAS_DISENCHANT)
  general_frame.smart_disenchant.without_dis:SetShown(not C.HAS_DISENCHANT)
  general_frame:Acquire_CacheSettingsTable()
  container:Tab_OnClick(general_tab)
  config:UpdateConfig()
end

SLASH_LOOTCLICKER1, SLASH_LOOTCLICKER2 = '/lcl', '/lootclicker'
function SlashCmdList.LOOTCLICKER(cmd)
  if cmd == 'extest' then
    local GetContainerNumSlots, GetContainerItemID = GetContainerNumSlots, GetContainerItemID
    for bag = 0, 4 do
      local slots = GetContainerNumSlots(bag)
      for slot = 1, slots do
        local id = GetContainerItemID(bag, slot)
        if id and not exception_frame.exception_list[id] then
          exception_frame:AddExceptionItem(id)
        end
      end
    end
    exception_frame:ExceptionList_Update('update_items')
  elseif cmd == 'exclear' then
    exception_frame:ClearExceptionList()
  elseif cmd == 'hard reset' then
    StaticPopup_Show("LOOT_CLICKER_HARD_RESET")
  elseif cmd == 'debug' then
    private.debug = not private.debug
    LootClicker:print('debug state is', private.debug)
  else
    InterfaceOptionsFrame_OpenToCategory(addon_name)
  end
end

-- add the ability to embed links into editbox
private.hooks.ChatEdit_InsertLink = ChatEdit_InsertLink
function ChatEdit_InsertLink(text)
  if exception_frame.edit:HasFocus() then
    exception_frame.edit:SetText(text)
    return true
  else
    return private.hooks.ChatEdit_InsertLink(text)
  end
end

config.name = addon_name
config.default = config.SetDefaultSettings
config.okay = config.SaveChanges
config.cancel = config.CancelChanges

-- SarychUI: defer Blizzard category until the embedded addon is enabled.
function LootClicker_RegisterInterfaceOptions()
	if config._suiBlizRegistered then
		return
	end
	if LootClickerEnabled == false then
		return
	end
	InterfaceOptions_AddCategory(config)
	config._suiBlizRegistered = true
end

if LootClickerEnabled then
	LootClicker_RegisterInterfaceOptions()
end
