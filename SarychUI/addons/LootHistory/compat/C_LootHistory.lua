local _G, pairs, select = _G, pairs, select
local tinsert = table.insert
local UnitName, UnitClass = UnitName, UnitClass
local GetLootRollItemLink, GetLootRollItemInfo = GetLootRollItemLink, GetLootRollItemInfo
local GetNumPartyMembers, GetNumRaidMembers = GetNumPartyMembers, GetNumRaidMembers
local UnitInRaid, UnitInParty, UnitInBattleground = UnitInRaid, UnitInParty, UnitInBattleground

local items_data = {}
local players_data = {}
local patterns = {
  won_no_spam = {
    LOOT_ROLL_WON_NO_SPAM_NEED = LOOT_ROLL_TYPE_NEED,
    LOOT_ROLL_WON_NO_SPAM_GREED = LOOT_ROLL_TYPE_GREED,
    LOOT_ROLL_WON_NO_SPAM_DE = LOOT_ROLL_TYPE_DISENCHANT,
  },
  you_won_no_spam = {
    LOOT_ROLL_YOU_WON_NO_SPAM_NEED = LOOT_ROLL_TYPE_NEED,
    LOOT_ROLL_YOU_WON_NO_SPAM_GREED = LOOT_ROLL_TYPE_GREED,
    LOOT_ROLL_YOU_WON_NO_SPAM_DE = LOOT_ROLL_TYPE_DISENCHANT,
  },
  roll = {
    LOOT_ROLL_PASSED = LOOT_ROLL_TYPE_PASS,
    LOOT_ROLL_NEED = LOOT_ROLL_TYPE_NEED,
    LOOT_ROLL_GREED = LOOT_ROLL_TYPE_GREED,
    LOOT_ROLL_DISENCHANT = LOOT_ROLL_TYPE_DISENCHANT,
  },
  you_roll = {
    LOOT_ROLL_PASSED_SELF_AUTO = LOOT_ROLL_TYPE_PASS,
    LOOT_ROLL_PASSED_SELF = LOOT_ROLL_TYPE_PASS,
    LOOT_ROLL_NEED_SELF = LOOT_ROLL_TYPE_NEED,
    LOOT_ROLL_GREED_SELF = LOOT_ROLL_TYPE_GREED,
    LOOT_ROLL_DISENCHANT_SELF = LOOT_ROLL_TYPE_DISENCHANT,
  },
  roll_result = {
    LOOT_ROLL_ROLLED_NEED = LOOT_ROLL_TYPE_NEED,
    LOOT_ROLL_ROLLED_GREED = LOOT_ROLL_TYPE_GREED,
    LOOT_ROLL_ROLLED_DE = LOOT_ROLL_TYPE_DISENCHANT,
  },
}
local you_name = UnitName('player')
local _, you_class = UnitClass('player')

local function GetPlayerIndex(itemIdx, playerName)
  for playerIdx, playerData in pairs(items_data[itemIdx].players) do
    if playerData.name == playerName then
      return playerIdx
    end
  end
end
local function GetItemIndex(itemLink, playerName)
  for itemIdx, itemData in pairs(items_data) do
    if itemData.itemLink == itemLink and not itemData.isDone then
      if playerName then
        -- если передано имя игрока, то ищем предмет, который этот игрок еще не разыграл
        local playerIdx = GetPlayerIndex(itemIdx, playerName)
        if not itemData.players[playerIdx].rollType then
          return itemIdx
        end
      else
        return itemIdx
      end
    end
  end
end

local f = CreateFrame('Frame')
f:Hide()
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PARTY_MEMBERS_CHANGED")
f:RegisterEvent("RAID_ROSTER_UPDATE")
f:RegisterEvent("START_LOOT_ROLL")
f:RegisterEvent("CHAT_MSG_LOOT")
f:SetScript('OnEvent', function(self, event, ...)
  if event == "PLAYER_ENTERING_WORLD" then
    if UnitInRaid('player') then
      self:GetScript('OnEvent')(self, 'RAID_ROSTER_UPDATE', ...)
    elseif UnitInParty('player') then
      self:GetScript('OnEvent')(self, 'PARTY_MEMBERS_CHANGED', ...)
    end
  elseif event == "PARTY_MEMBERS_CHANGED" then
    if UnitInRaid('player') or UnitInBattleground('player') then return end
    table.wipe(players_data)
    players_data[you_name] = you_class
    for i=1, GetNumPartyMembers() do
      local name = UnitName('party'..i)
      local _, class = UnitClass('party'..i)
      if name and class then
        players_data[name] = class
      end
    end
  elseif event == "RAID_ROSTER_UPDATE" then
    if UnitInBattleground('player') then return end
    table.wipe(players_data)
    for i=1, GetNumRaidMembers() do
      local name = UnitName('raid'..i)
      local _, class = UnitClass('raid'..i)
      if name and class then
        players_data[name] = class
      end
    end
  elseif event == "START_LOOT_ROLL" then
    local rollID = ...
    local data_table = {
      rollID = rollID,
      itemLink = GetLootRollItemLink(rollID),
      isDone = false,
      isMasterLoot = false,
      players = {},
    }
    for name, class in pairs(players_data) do
      local player_data = {
        name = name,
        class = class,
        isWinner = false,
        isMe = name == you_name,
      }
      tinsert(data_table.players, player_data)
    end
    data_table.numPlayers = #data_table.players
    tinsert(items_data, 1, data_table)

    local bindOnPickUp = select(5, GetLootRollItemInfo(rollID))
    if bindOnPickUp then
      LootHistoryFrame_OnEvent(LootHistoryFrame, "LOOT_HISTORY_AUTO_SHOW", rollID)
    else
      LootHistoryFrame_OnEvent(LootHistoryFrame, "LOOT_HISTORY_FULL_UPDATE")
    end
  elseif event == "CHAT_MSG_LOOT" then
    local message = ...

    -- all passed
    local itemLink = message:cmatch(LOOT_ROLL_ALL_PASSED)
    if itemLink then
      local itemIdx = GetItemIndex(itemLink)
      if not itemIdx then return end
      local data_table = items_data[itemIdx]
      data_table.isDone = true
      return LootHistoryFrame_OnEvent(LootHistoryFrame, "LOOT_HISTORY_ROLL_COMPLETE")
    end
    -- you_won_no_spam
    for pattern, rollType in pairs(patterns.you_won_no_spam) do
      local roll, itemLink = message:cmatch(_G[pattern])
      if roll then
        local playerName = UnitName('player')
        local itemIdx = GetItemIndex(itemLink, playerName)
        if not itemIdx then return end
        local playerIdx = GetPlayerIndex(itemIdx, playerName)
        local data_table = items_data[itemIdx]
        data_table.players[playerIdx].rollType = rollType
        data_table.players[playerIdx].roll = roll
        data_table.players[playerIdx].isWinner = true
        data_table.winnerIdx = playerIdx
        data_table.isDone = true
        return LootHistoryFrame_OnEvent(LootHistoryFrame, "LOOT_HISTORY_ROLL_COMPLETE")
      end
    end
    -- won_no_spam
    for pattern, rollType in pairs(patterns.won_no_spam) do
      local playerName, roll, itemLink = message:cmatch(_G[pattern])
      if roll then
        local itemIdx = GetItemIndex(itemLink, playerName)
        if not itemIdx then return end
        local playerIdx = GetPlayerIndex(itemIdx, playerName)
        local data_table = items_data[itemIdx]
        data_table.players[playerIdx].rollType = rollType
        data_table.players[playerIdx].roll = roll
        data_table.players[playerIdx].isWinner = true
        data_table.winnerIdx = playerIdx
        data_table.isDone = true
        return LootHistoryFrame_OnEvent(LootHistoryFrame, "LOOT_HISTORY_ROLL_COMPLETE")
      end
    end
    -- you_roll
    for pattern, rollType in pairs(patterns.you_roll) do
      local itemLink = message:cmatch(_G[pattern])
      if itemLink then
        local itemIdx = GetItemIndex(itemLink, you_name)
        if not itemIdx then return end
        local playerIdx = GetPlayerIndex(itemIdx, you_name)
        local data_table = items_data[itemIdx]
        data_table.players[playerIdx].rollType = rollType
        return LootHistoryFrame_OnEvent(LootHistoryFrame, "LOOT_HISTORY_ROLL_CHANGED", itemIdx, playerIdx)
      end
    end
    -- roll
    for pattern, rollType in pairs(patterns.roll) do
      local playerName, itemLink = message:cmatch(_G[pattern])
      if playerName then
        local itemIdx = GetItemIndex(itemLink, playerName)
        if not itemIdx then return end
        local playerIdx = GetPlayerIndex(itemIdx, playerName)
        local data_table = items_data[itemIdx]
        data_table.players[playerIdx].rollType = rollType
        return LootHistoryFrame_OnEvent(LootHistoryFrame, "LOOT_HISTORY_ROLL_CHANGED", itemIdx, playerIdx)
      end
    end
    -- roll_result
    for pattern in pairs(patterns.roll_result) do
      local roll, itemLink, playerName = message:cmatch(_G[pattern])
      if roll then
        local itemIdx = GetItemIndex(itemLink)
        if not itemIdx then return end
        local playerIdx = GetPlayerIndex(itemIdx, playerName)
        local data_table = items_data[itemIdx]
        data_table.players[playerIdx].roll = tonumber(roll)
        return LootHistoryFrame_OnEvent(LootHistoryFrame, "LOOT_HISTORY_ROLL_CHANGED", itemIdx, playerIdx)
      end
    end
    -- you won
    local itemLink = message:cmatch(LOOT_ROLL_YOU_WON)
    if itemLink then
      local itemIdx = GetItemIndex(itemLink)
      if not itemIdx then return end
      local playerIdx = GetPlayerIndex(itemIdx, you_name)
      local data_table = items_data[itemIdx]
      data_table.players[playerIdx].isWinner = true
      data_table.winnerIdx = playerIdx
      data_table.isDone = true
      return LootHistoryFrame_OnEvent(LootHistoryFrame, "LOOT_HISTORY_ROLL_COMPLETE")
    end
    -- won
    local playerName, itemLink = message:cmatch(LOOT_ROLL_WON)
    if itemLink then
      local itemIdx = GetItemIndex(itemLink)
      if not itemIdx then return end
      local playerIdx = GetPlayerIndex(itemIdx, playerName)
      local data_table = items_data[itemIdx]
      data_table.players[playerIdx].isWinner = true
      data_table.winnerIdx = playerIdx
      data_table.isDone = true
      return LootHistoryFrame_OnEvent(LootHistoryFrame, "LOOT_HISTORY_ROLL_COMPLETE")
    end
  end
end)

-------------
---- API ----
-------------
C_LootHistory = {}
C_LootHistory.GetPlayerInfo = function(itemIdx, playerIdx)
  local info = items_data[itemIdx].players[playerIdx]
  return info.name, info.class, info.rollType, info.roll, info.isWinner, info.isMe
end

C_LootHistory.GetItem = function(itemIdx)
  local info = items_data[itemIdx]
  info.numPlayers = #items_data[itemIdx].players
  return info.rollID, info.itemLink, info.numPlayers, info.isDone, info.winnerIdx, info.isMasterLoot
end

C_LootHistory.GetNumItems = function()
  return #items_data
end
