-- Global enabled state
LootHistoryEnabled = LootHistoryEnabled or true;

-- Function to check if addon is enabled
local function IsEnabled()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.LootHistory then
		return SarychUI.db.profile.addons.LootHistory.enabled ~= false;
	end
	return LootHistoryEnabled;
end

function ToggleLootHistoryFrame()
	if not IsEnabled() then
		return;
	end
  if ( LootHistoryFrame:IsShown() ) then
    LootHistoryFrame:Hide();
  else
    LootHistoryFrame_ResetHighlights(LootHistoryFrame);
    LootHistoryFrame_FullUpdate(LootHistoryFrame);
    LootHistoryFrame:Show();
  end
end

function LootHistoryFrame_OnLoad(self)
  self.itemFrames = {};
  self.expandedRolls = {};
  self.usedPlayerFrames = {};
  self.unusedPlayerFrames = {};
  self.highlightedRolls = {};

  self:RegisterEvent("LOOT_HISTORY_FULL_UPDATE");
  self:RegisterEvent("LOOT_HISTORY_ROLL_COMPLETE");
  self:RegisterEvent("LOOT_HISTORY_ROLL_CHANGED");
  self:RegisterEvent("LOOT_HISTORY_AUTO_SHOW");

  LootHistoryFrame_FullUpdate(self);
end

function LootHistoryFrame_OnEvent(self, event, ...)
	if not IsEnabled() then
		return;
	end
  if ( event == "LOOT_HISTORY_FULL_UPDATE" ) then
    LootHistoryFrame_FullUpdate(self);
  elseif ( event == "LOOT_HISTORY_ROLL_COMPLETE" ) then
    LootHistoryFrame_FullUpdate(self);
  elseif ( event == "LOOT_HISTORY_ROLL_CHANGED" ) then
    local itemIdx, playerIdx = ...;
    LootHistoryFrame_UpdatePlayerRoll(self, itemIdx, playerIdx);
  elseif ( event == "LOOT_HISTORY_AUTO_SHOW" ) then
    local rollID, isMasterLoot = ...;
    if ( GetInterfaceOptionsVarBool("autoOpenLootHistory") or (isMasterLoot and IsMasterLooter()) ) then
      if ( not self:IsShown() ) then
        LootHistoryFrame_ResetHighlights(self);
        LootHistoryFrame_CollapseAll(self);
        self.ScrollFrame:SetVerticalScroll(0);
      end
      self.highlightedRolls[rollID] = true;
      LootHistoryFrame_SetRollExpanded(self, rollID, true);
      LootHistoryFrame:Show();
    end
  end
end

function LootHistoryFrame_OnHide(self)
  self.openedTo = nil;
end

function LootHistoryFrame_FullUpdate(self)
	if not IsEnabled() then
		return;
	end
  LootHistoryFrame_RecycleAllPlayers(self); --Recycle players? Sounds like soylent purplez.
  local numItems = C_LootHistory.GetNumItems();
  local previous = nil;
  for i=1, numItems do
    local frame = self.itemFrames[i];
    if ( not frame ) then
      frame = CreateFrame("BUTTON", "LootHistoryItem"..i, self.ScrollFrame.ScrollChild, "LootHistoryItemTemplate");
      self.itemFrames[i] = frame;
    end

    local rollID, itemLink, numPlayers, isDone, winnerIdx = C_LootHistory.GetItem(i);
    frame.rollID = rollID;
    frame.itemIdx = i;
    frame.itemLink = itemLink;
    LootHistoryFrame_UpdateItemFrame(self, frame);
    frame:Show();

    if ( previous ) then
      frame:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -5);
    else
      frame:SetPoint("TOPLEFT", 0, -2);
    end

    if ( self.expandedRolls[rollID] ) then
      local firstFrame, lastFrame = LootHistoryFrame_UpdatePlayerFrames(self, i);
      if ( firstFrame ) then
        firstFrame:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -2);
        previous = lastFrame;
      else
        previous = frame;
      end
    else
      previous = frame;
    end
  end
  for i=numItems + 1, #self.itemFrames do
    self.itemFrames[i]:Hide();
  end
end

function LootHistoryFrame_RecycleAllPlayers(self)
  for i=1, #self.usedPlayerFrames do
    local frame = self.usedPlayerFrames[i];
    frame.itemIdx = nil;
    frame.playerIdx = nil;
    frame:Hide();
    table.insert(self.unusedPlayerFrames, frame);
  end
  table.wipe(self.usedPlayerFrames);
end

local playerframes_counter = 0
function LootHistoryFrame_GetPlayerFrame(self)
  local frame = table.remove(self.unusedPlayerFrames);
  if ( not frame ) then
    playerframes_counter = playerframes_counter+1
    frame = CreateFrame("BUTTON", "LootHistoryPlayer"..playerframes_counter, self.ScrollFrame.ScrollChild, "LootHistoryPlayerTemplate");
  end
  table.insert(self.usedPlayerFrames, frame);
  return frame;
end

function LootHistoryFrame_UpdatePlayerFrames(self, itemIdx)
  local rollID, itemLink, numPlayers, isDone, winnerIdx, isMasterLoot = C_LootHistory.GetItem(itemIdx);

  local firstFrame, lastFrame;

  if ( not isDone or winnerIdx or isMasterLoot ) then
    for i=1, numPlayers do
      if ( LootHistoryFrameUtil_ShouldDisplayPlayer(itemIdx, i) ) then
        local frame = LootHistoryFrame_GetPlayerFrame(self);
        if ( lastFrame ) then
          frame:SetPoint("TOPLEFT", lastFrame, "BOTTOMLEFT", 0, -1);
        else
          frame:ClearAllPoints();
        end
        firstFrame = firstFrame or frame;
        lastFrame = frame;

        frame.itemIdx = itemIdx;
        frame.playerIdx = i;
        LootHistoryFrame_UpdatePlayerFrame(self, frame);
        frame:Show();
      end
    end
  else
    --Everyone passed
    local frame = LootHistoryFrame_GetPlayerFrame(self);
    if ( lastFrame ) then
      frame:SetPoint("TOPLEFT", lastFrame, "BOTTOMLEFT", 0, -1);
    else
      frame:ClearAllPoints();
    end
    firstFrame = firstFrame or frame;
    lastFrame = frame;

    frame.itemIdx = itemIdx;
    frame.playerIdx = nil;  --All passed
    LootHistoryFrame_UpdatePlayerFrame(self, frame);
    frame:Show();
  end
  return firstFrame, lastFrame;
end

function LootHistoryFrame_ToggleRollExpanded(self, rollID)
  LootHistoryFrame_SetRollExpanded(self, rollID, not self.expandedRolls[rollID]);
end

function LootHistoryFrame_SetRollExpanded(self, rollID, isExpanded)
  self.expandedRolls[rollID] = isExpanded;
  LootHistoryFrame_FullUpdate(self);
end

function LootHistoryFrame_CollapseAll(self)
  table.wipe(self.expandedRolls);
  LootHistoryFrame_FullUpdate(self);
end

function LootHistoryFrame_ResetHighlights(self)
  table.wipe(self.highlightedRolls);
end

function LootHistoryFrame_UpdateItemFrame(self, itemFrame)
  local rollID, itemLink, numPlayers, isDone, winnerIdx, isMasterLoot = C_LootHistory.GetItem(itemFrame.itemIdx);
  local expanded = self.expandedRolls[rollID];

  if ( expanded ) then
    itemFrame.ToggleButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-UP");
    itemFrame.ToggleButton:SetPushedTexture("Interface\\Buttons\\UI-MinusButton-Down");
    itemFrame.ToggleButton:SetDisabledTexture("Interface\\Buttons\\UI-MinusButton-Disabled");
  else
    itemFrame.ToggleButton:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-UP");
    itemFrame.ToggleButton:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-Down");
    itemFrame.ToggleButton:SetDisabledTexture("Interface\\Buttons\\UI-PlusButton-Disabled");
  end

  if ( not itemLink ) then  --We have to get this from the server, we'll get a FULL_UPDATE when it arrives
    itemFrame.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark");
    itemFrame.IconBorder:SetVertexColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
    itemFrame.ItemName:SetText(RETRIEVING_DATA);
    itemFrame.ItemName:SetVertexColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
  else
    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(itemLink);
    itemFrame.Icon:SetTexture(itemTexture);
    local colorInfo = ITEM_QUALITY_COLORS[itemRarity];
    itemFrame.IconBorder:SetVertexColor(colorInfo.r, colorInfo.g, colorInfo.b);
    itemFrame.ItemName:SetText(itemName);
    itemFrame.ItemName:SetVertexColor(colorInfo.r, colorInfo.g, colorInfo.b);
  end

  if ( self.highlightedRolls[rollID] ) then
    itemFrame.ActiveHighlight:Show();
  else
    itemFrame.ActiveHighlight:Hide();
  end

  if ( isDone and not expanded ) then
    itemFrame.ItemName:SetPoint("BOTTOMRIGHT", itemFrame.NameBorderRight, "RIGHT", -2, 0);
    if ( winnerIdx ) then
      local name, class, rollType, roll, isWinner = C_LootHistory.GetPlayerInfo(itemFrame.itemIdx, winnerIdx);

      if ( rollType == LOOT_ROLL_TYPE_NEED ) then
        itemFrame.WinnerRollType:SetTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Up");
      elseif ( rollType == LOOT_ROLL_TYPE_GREED ) then
        itemFrame.WinnerRollType:SetTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Up");
      elseif ( rollType == LOOT_ROLL_TYPE_DISENCHANT ) then
        itemFrame.WinnerRollType:SetTexture("Interface\\Buttons\\UI-GroupLoot-DE-Up");
      elseif ( rollType == LOOT_ROLL_TYPE_PASS ) then
        itemFrame.WinnerRollType:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up");
      else
        itemFrame.WinnerRollType:SetTexture(nil); --Should never happen for a winner
      end

      itemFrame.WinnerRollType:ClearAllPoints();
      if ( roll ) then
        itemFrame.WinnerRollType:SetPoint("RIGHT", itemFrame.WinnerRoll, "LEFT", 2, -1);
      else
        itemFrame.WinnerRollType:SetPoint("BOTTOMRIGHT", itemFrame.NameBorderRight, "BOTTOMRIGHT", -2, 1);
      end
      itemFrame.WinnerRoll:SetText(roll or "");

      if ( name ) then
        itemFrame.WinnerName:SetText(name);
        local classColor = RAID_CLASS_COLORS[class];
        itemFrame.WinnerName:SetVertexColor(classColor.r, classColor.g, classColor.b);
      else
        itemFrame.WinnerName:SetText(UNKNOWNOBJECT);
        itemFrame.WinnerName:SetVertexColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
      end
      itemFrame.WinnerRoll:Show();
      itemFrame.WinnerRollType:Show();
      itemFrame.WinnerName:Show();
    else
      --Everyone passed
      itemFrame.WinnerRoll:Hide();
      itemFrame.WinnerRollType:Show();
      itemFrame.WinnerRollType:ClearAllPoints();
      itemFrame.WinnerRollType:SetPoint("BOTTOMRIGHT", itemFrame.NameBorderRight, "BOTTOMRIGHT", -2, 1);
      if ( isMasterLoot ) then
        itemFrame.WinnerRollType:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready");
        itemFrame.WinnerName:Hide();
      else
        itemFrame.WinnerRollType:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up");
        itemFrame.WinnerName:SetText(LOOT_HISTORY_ALL_PASSED);
        itemFrame.WinnerName:SetVertexColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
        itemFrame.WinnerName:Show();
      end
    end
  else
    itemFrame.ItemName:SetPoint("BOTTOMRIGHT", itemFrame.NameBorderRight, "BOTTOMRIGHT", -2, 2);
    itemFrame.WinnerRoll:Hide();
    itemFrame.WinnerRollType:Hide();
    itemFrame.WinnerName:Hide();
  end
end

function LootHistoryFrame_UpdatePlayerFrame(self, playerFrame)
  if ( playerFrame.playerIdx ) then
    local name, class, rollType, roll, isWinner = C_LootHistory.GetPlayerInfo(playerFrame.itemIdx, playerFrame.playerIdx);
    if ( playerFrame.playerIdx % 2 == 1) then
      playerFrame.AlternatingBG:Show();
    else
      playerFrame.AlternatingBG:Hide();
    end

    if ( name ) then
      playerFrame.PlayerName:SetText(name);
      local classColor = RAID_CLASS_COLORS[class];
      playerFrame.PlayerName:SetVertexColor(classColor.r, classColor.g, classColor.b);
    else
      playerFrame.PlayerName:SetText(UNKNOWNOBJECT);
      playerFrame.PlayerName:SetVertexColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
    end

    if ( rollType == LOOT_ROLL_TYPE_NEED ) then
      playerFrame.RollIcon.Texture:SetTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Up");
      playerFrame.RollIcon.tooltip = NEED;
    elseif ( rollType == LOOT_ROLL_TYPE_GREED ) then
      playerFrame.RollIcon.Texture:SetTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Up");
      playerFrame.RollIcon.tooltip = GREED;
    elseif ( rollType == LOOT_ROLL_TYPE_DISENCHANT ) then
      playerFrame.RollIcon.Texture:SetTexture("Interface\\Buttons\\UI-GroupLoot-DE-Up");
      playerFrame.RollIcon.tooltip = ROLL_DISENCHANT;
    elseif ( rollType == LOOT_ROLL_TYPE_PASS ) then
      playerFrame.RollIcon.Texture:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up");
      playerFrame.RollIcon.tooltip = PASS;
    else
      playerFrame.RollIcon.Texture:SetTexture(nil); --TODO: Use unknown icon once created
      playerFrame.RollIcon.tooltip = nil;
    end

    if ( not rollType ) then
      playerFrame.RollText:SetText("... ");
    elseif ( not roll ) then
      playerFrame.RollText:SetText("");
      playerFrame.RollIcon:SetPoint("RIGHT", playerFrame, "RIGHT", -2, -1);
    else
      playerFrame.RollText:SetText(roll);
      playerFrame.RollIcon:SetPoint("RIGHT", playerFrame.RollText, "LEFT", 2, -1);
    end

    if ( isWinner ) then
      playerFrame.WinMark:Show();
    else
      playerFrame.WinMark:Hide();
    end
  else
    playerFrame.AlternatingBG:Show();
    playerFrame.PlayerName:SetText(LOOT_HISTORY_ALL_PASSED);
    playerFrame.PlayerName:SetVertexColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
    playerFrame.RollIcon.Texture:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up");
    playerFrame.RollIcon.tooltip = PASS;
    playerFrame.RollText:SetText("");
    playerFrame.RollIcon:SetPoint("RIGHT", playerFrame, "RIGHT", -2, -1);
    playerFrame.WinMark:Hide();
  end
end

function LootHistoryFrame_UpdatePlayerRoll(self, itemIdx, playerIdx)
  for i=1, #self.usedPlayerFrames do
    local frame = self.usedPlayerFrames[i];
    if ( frame.itemIdx == itemIdx and frame.playerIdx == playerIdx ) then
      LootHistoryFrame_UpdatePlayerFrame(self, frame);
      break; --Should be only 1 frame per (itemIdx, playerIdx) tuple
    end
  end
end

function LootHistoryFrame_ToggleWithRoll(self, requestedRollID, errorTarget)
  if ( not self:IsShown() or self.openedTo ~= requestedRollID ) then
    LootHistoryFrame_OpenToRoll(self, requestedRollID, errorTarget);
  else
    self:Hide();
  end
end

function LootHistoryFrame_OpenToRoll(self, requestedRollID, errorTarget)
  local numItems = C_LootHistory.GetNumItems();
  for i=1, numItems do
    local rollID, itemLink, numPlayers, isDone, winnerIdx = C_LootHistory.GetItem(i);
    if ( requestedRollID == rollID ) then
      self.openedTo = requestedRollID;

      --Collapse all other rolls
      table.wipe(self.expandedRolls);
      self.expandedRolls[rollID] = true;

      --Remove all other highlights
      LootHistoryFrame_ResetHighlights(self);
      self.highlightedRolls[rollID] = true;

      --Update the frame
      LootHistoryFrame_FullUpdate(self);

      --Show the frame
      self:Show();
      self.ScrollFrame:UpdateScrollChildRect();

      --Scroll to the correct item
      local offset = 2 + 41 * (i - 1);
      offset = min(offset, self.ScrollFrame:GetVerticalScrollRange());
      self.ScrollFrame:SetVerticalScroll(offset);
      return;
    end
  end

  --We didn't find this item
  if ( errorTarget ) then
    local info = ChatTypeInfo["SYSTEM"];
    errorTarget:AddMessage(ERR_LOOT_HISTORY_EXPIRED, info.r, info.g, info.b);
  end
  UIErrorsFrame:AddMessage(ERR_LOOT_HISTORY_EXPIRED, 1.0, 0.1, 0.1, 1.0);
end

function LootHistoryPlayerFrame_OnClick(self, button)
  if ( C_LootHistory.CanMasterLoot(self.itemIdx, self.playerIdx) ) then
    StaticPopup_Hide("CONFIRM_LOOT_DISTRIBUTION");
    MasterLooterFrame:Hide();
    LootHistoryDropDown.itemIdx = self.itemIdx;
    LootHistoryDropDown.playerIdx = self.playerIdx;
    ToggleDropDownMenu(1, nil, LootHistoryDropDown, "cursor", 0, 0);
  end
end

function LootHistoryDropDown_OnLoad(self)
  UIDropDownMenu_Initialize(self, nil, "MENU");
  self.initialize = LootHistoryDropDown_Initialize;
end

function LootHistoryDropDown_Initialize(self)
  local info = UIDropDownMenu_CreateInfo();
  info.isTitle = 1;
  info.text = MASTER_LOOTER;
  info.fontObject = GameFontNormalLeft;
  info.notCheckable = 1;
  UIDropDownMenu_AddButton(info);

  info = UIDropDownMenu_CreateInfo();
  info.notCheckable = 1;
  local name, class = C_LootHistory.GetPlayerInfo(self.itemIdx, self.playerIdx);
  local classColor = RAID_CLASS_COLORS[class];
  local colorCode = string.format("|cFF%02x%02x%02x",  classColor.r*255,  classColor.g*255,  classColor.b*255);
  info.text = string.format(MASTER_LOOTER_GIVE_TO, colorCode..name.."|r");
  info.func = LootHistoryDropDown_OnClick;
  UIDropDownMenu_AddButton(info);
end

function LootHistoryDropDown_OnClick()
  local _, itemLink = C_LootHistory.GetItem(LootHistoryDropDown.itemIdx);
  if ( itemLink ) then
    local itemName, itemLink, itemRarity = GetItemInfo(itemLink);
    if ( itemRarity >= MASTER_LOOT_THREHOLD ) then
      local playerName = C_LootHistory.GetPlayerInfo(LootHistoryDropDown.itemIdx, LootHistoryDropDown.playerIdx);
      StaticPopup_Show("CONFIRM_LOOT_DISTRIBUTION", ITEM_QUALITY_COLORS[itemRarity].hex..itemName..FONT_COLOR_CODE_CLOSE, playerName, "LootHistory");
    else
      LootHistoryDropDown_GiveMasterLoot();
    end
  end
end

function LootHistoryDropDown_GiveMasterLoot()
  C_LootHistory.GiveMasterLoot(LootHistoryDropDown.itemIdx, LootHistoryDropDown.playerIdx);
end

function LootHistoryFrameUtil_ShouldDisplayPlayer(itemIdx, playerIdx)
  local rollID, itemLink, numPlayers, isDone, winnerIdx, isMasterLoot = C_LootHistory.GetItem(itemIdx);
  local name, class, rollType, roll, isWinner, isMe = C_LootHistory.GetPlayerInfo(itemIdx, playerIdx);

  return isMe or roll or (not isDone) or isMasterLoot;
end

-- ========================================
-- КНОПКА НА ВКЛАДКЕ LOOT
-- ========================================

local LootTabButton = nil
local LootChatFrame = nil
local lootButtonAlphaSyncFrame = nil
local lootButtonLastSyncedAlpha = nil
local ACTIVE_FACTOR = 1.0
local INACTIVE_FACTOR = 0.25
local LOOT_BUTTON_NAME = "SarychUI_CombatTextLessAnchor"

local function GetExistingLootButton()
	if LootTabButton then return LootTabButton end
	if _G[LOOT_BUTTON_NAME] then return _G[LOOT_BUTTON_NAME] end
	if _G.LootHistoryLootTabButton then return _G.LootHistoryLootTabButton end
	return nil
end

local function GetLootChatTab()
	if not LootChatFrame then return nil end
	return _G[LootChatFrame:GetName() .. "Tab"]
end

local function IsChatFrameActive(chatFrame)
	if not chatFrame then return false end
	if SELECTED_CHAT_FRAME == chatFrame or SELECTED_DOCK_FRAME == chatFrame then
		return true
	elseif FCF_GetCurrentChatFrame and FCF_GetCurrentChatFrame() == chatFrame then
		return true
	end
	return false
end

-- В 3.3.5 FCF_FadeIn/Out меняет alpha текстур и вкладки, а не ChatFrame.
-- Следуем за alpha вкладки Loot — так же ведёт себя стандартный UI чата.
local function ComputeLootButtonAlphaFromTab(tab)
	if not tab then
		return ACTIVE_FACTOR
	end

	local tabAlpha = tab:GetAlpha() or 1
	local mouseOver = tab.mouseOverAlpha or CHAT_FRAME_TAB_SELECTED_MOUSEOVER_ALPHA or 1
	local noMouse = tab.noMouseAlpha or CHAT_FRAME_TAB_SELECTED_NOMOUSE_ALPHA or 0.4

	if mouseOver <= noMouse + 0.001 then
		if tabAlpha > noMouse + 0.08 then
			return ACTIVE_FACTOR
		end
		return INACTIVE_FACTOR
	end

	local t = (tabAlpha - noMouse) / (mouseOver - noMouse)
	if t < 0 then
		t = 0
	elseif t > 1 then
		t = 1
	end
	return INACTIVE_FACTOR + (ACTIVE_FACTOR - INACTIVE_FACTOR) * t
end

local function SyncLootButtonAlphaFromTab()
	local button = GetExistingLootButton()
	if not button or not button:IsShown() or not LootChatFrame or not IsChatFrameActive(LootChatFrame) then
		return
	end

	local tab = GetLootChatTab()
	if not tab then return end

	if button and UIFrameFadeRemoveFrame then
		UIFrameFadeRemoveFrame(button)
	end

	local alpha = ComputeLootButtonAlphaFromTab(tab)
	if lootButtonLastSyncedAlpha == alpha then
		return
	end
	lootButtonLastSyncedAlpha = alpha
	button:SetAlpha(alpha)
end

local function StartLootButtonAlphaSync()
	if not lootButtonAlphaSyncFrame then
		lootButtonAlphaSyncFrame = CreateFrame("Frame")
		lootButtonAlphaSyncFrame:SetScript("OnUpdate", SyncLootButtonAlphaFromTab)
	end
	lootButtonLastSyncedAlpha = nil
	lootButtonAlphaSyncFrame:Show()
	SyncLootButtonAlphaFromTab()
end

local function StopLootButtonAlphaSync()
	lootButtonLastSyncedAlpha = nil
	if lootButtonAlphaSyncFrame then
		lootButtonAlphaSyncFrame:Hide()
	end
end

local function AttachLootButtonToChatFrame(chatFrame, button)
	if button:GetParent() ~= chatFrame then
		button:SetParent(chatFrame)
	end
	button:ClearAllPoints()
	button:SetSize(24, 24)
	button:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", -5, -5)
	button:SetFrameStrata(chatFrame:GetFrameStrata())
	button:SetFrameLevel(chatFrame:GetFrameLevel() + 5)
end

-- Функция для получения настройки кнопки
local function IsLootTabButtonEnabled()
	if not IsEnabled() then
		return false
	end
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.LootHistory then
		return SarychUI.db.profile.addons.LootHistory.lootTabButtonEnabled == true
	end
	return false
end

-- Функция для поиска окна чата Loot
local function FindLootChatFrame()
	-- Ищем по имени вкладки среди всех окон
	for i = 1, NUM_CHAT_WINDOWS do
		local chatFrame = _G["ChatFrame"..i]
		if chatFrame then
			local name = GetChatWindowInfo(i)
			if name and (name == "Loot" or name:lower():find("loot") or name:lower():find("лут")) then
				return chatFrame
			end
		end
	end
	-- Если не нашли по имени, пробуем найти по сообщениям LOOT
	for i = 1, NUM_CHAT_WINDOWS do
		local chatFrame = _G["ChatFrame"..i]
		if chatFrame and chatFrame.messageTypeList then
			for _, msgType in pairs(chatFrame.messageTypeList) do
				if msgType == "LOOT" then
					return chatFrame
				end
			end
		end
	end
	return nil
end

-- Создаем кнопку сразу при загрузке (как в модуле chat)
local function CreateLootButton()
	-- Проверяем настройки
	if not IsLootTabButtonEnabled() then
		if LootTabButton then
			LootTabButton:Hide()
		end
		StopLootButtonAlphaSync()
		return
	end
	
	-- Ищем окно Loot
	local chatFrame = FindLootChatFrame()
	if not chatFrame then
		if LootTabButton then
			LootTabButton:Hide()
		end
		LootChatFrame = nil
		StopLootButtonAlphaSync()
		return
	end
	
	LootChatFrame = chatFrame
	
	local button = GetExistingLootButton()
	if button then
		LootTabButton = button
		AttachLootButtonToChatFrame(chatFrame, button)
		if IsChatFrameActive(chatFrame) then
			button:Show()
			StartLootButtonAlphaSync()
		else
			button:Hide()
			StopLootButtonAlphaSync()
		end
		return
	end

	local newButton = CreateFrame("Button", LOOT_BUTTON_NAME, chatFrame)
	newButton:SetSize(24, 24)
	newButton:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", -5, -5)
	newButton:SetFrameLevel(chatFrame:GetFrameLevel() + 5)
	
	newButton:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Up")
	newButton:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Down")
	newButton:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Highlight", "ADD")
	
	newButton:RegisterForClicks("LeftButtonUp")
	newButton:SetScript("OnClick", function(self)
		if IsEnabled() then
			ToggleLootHistoryFrame()
		end
	end)
	
	newButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Loot History", 1, 1, 1)
		GameTooltip:AddLine("Нажмите, чтобы открыть/закрыть историю лута", 0.8, 0.8, 0.8, 1)
		GameTooltip:Show()
	end)
	
	newButton:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
	end)
	
	LootTabButton = newButton
	
	if IsChatFrameActive(chatFrame) then
		newButton:Show()
		StartLootButtonAlphaSync()
	else
		newButton:Hide()
		StopLootButtonAlphaSync()
	end
end

-- Обновление видимости кнопки
local function UpdateButtonVisibility()
	if not IsLootTabButtonEnabled() or not IsEnabled() then
		if LootTabButton then
			LootTabButton:Hide()
		end
		StopLootButtonAlphaSync()
		return
	end
	
	if LootTabButton and LootChatFrame then
		if IsChatFrameActive(LootChatFrame) then
			AttachLootButtonToChatFrame(LootChatFrame, LootTabButton)
			LootTabButton:Show()
			StartLootButtonAlphaSync()
		else
			LootTabButton:Hide()
			StopLootButtonAlphaSync()
		end
	end
end

-- Регистрируем глобальные функции
_G.LootHistory_UpdateLootTabButton = CreateLootButton
_G.LootHistory_UpdateButtonVisibility = UpdateButtonVisibility

-- Инициализация (как в модуле chat - сразу при событиях)
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("UPDATE_CHAT_WINDOWS")
initFrame:RegisterEvent("CHAT_TAB_CHANGED")

initFrame:SetScript("OnEvent", function(self, event, addonName)
	if event == "ADDON_LOADED" and addonName == "LootHistory" then
		CreateLootButton()
	elseif event == "PLAYER_LOGIN" then
		CreateLootButton()
	elseif event == "UPDATE_CHAT_WINDOWS" or event == "CHAT_TAB_CHANGED" then
		CreateLootButton()
		UpdateButtonVisibility()
	end
end)

-- Хук на переключение вкладок
hooksecurefunc("FCF_Tab_OnClick", function(self, button)
	UpdateButtonVisibility()
end)

-- Периодическая проверка создания кнопки (если окно Loot появилось позже)
local checkFrame = CreateFrame("Frame")
local checkCount = 0
checkFrame:SetScript("OnUpdate", function(self, elapsed)
	checkCount = checkCount + elapsed
	if checkCount >= 0.5 then
		checkCount = 0
		if IsLootTabButtonEnabled() and IsEnabled() and not LootTabButton then
			CreateLootButton()
		elseif LootTabButton then
			UpdateButtonVisibility()
		end
		-- Отключаем проверку через 10 секунд
		if self.elapsed then
			self.elapsed = (self.elapsed or 0) + elapsed
			if self.elapsed >= 10 then
				self:SetScript("OnUpdate", nil)
			end
		else
			self.elapsed = 0
		end
	end
end)
