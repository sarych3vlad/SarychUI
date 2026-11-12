local select, tonumber, pairs = select, tonumber, pairs
local GetLootRollItemLink, GetLootRollItemInfo = GetLootRollItemLink, GetLootRollItemInfo
local ConfirmLootRoll, ConfirmLootSlot, GetLootMethod, IsInInstance = ConfirmLootRoll, ConfirmLootSlot, GetLootMethod, IsInInstance
SarychUI.LootRolls = SarychUI.LootRolls or {}
local private = SarychUI.LootRolls
local C = private.constants
local IsEnabled = private.IsEnabled

-- Keep automatic votes distinguishable from clicks, including in secure hooks.
local function RollOnLoot(rollID, choice)
  private.automaticRollID = rollID
  local ok, result = pcall(_G.RollOnLoot, rollID, choice)
  private.automaticRollID = nil
  if not ok then error(result) end
  return result
end

function private.frame:START_LOOT_ROLL(rollID)
	if not IsEnabled() then
		return;
	end
  private:coro_thread(function()
    private:coro_wait()
    private:HandleLootRoll(rollID)
  end)
end

function private.frame:CONFIRM_LOOT_ROLL(...)
  ConfirmLootRoll(...)
  StaticPopup_Hide('CONFIRM_LOOT_ROLL')
end

function private.frame:CONFIRM_DISENCHANT_ROLL(...)
  ConfirmLootRoll(...)
  StaticPopup_Hide('CONFIRM_LOOT_ROLL')
end

function private:HandleLootRoll(rollID)
	if not IsEnabled() then
		return;
	end
  if not LootClickerDB then
    LootClickerDB = private.defaultDB
  end
  
  -- Ensure loot_settings exists
  if not LootClickerDB.loot_settings then
    LootClickerDB.loot_settings = {}
  end
  
  -- Ensure exception_list exists
  if not LootClickerDB.exception_list then
    LootClickerDB.exception_list = {
      sort = {
        [1] = 'descending',
        [2] = 'name',
      },
      items = {}
    }
  end
  if not LootClickerDB.exception_list.items then
    LootClickerDB.exception_list.items = {}
  end
  
  local quality, bindOnPickUp, canNeed, canGreed, canDisenchant = select(4, GetLootRollItemInfo(rollID))
  if not quality then return end
  local link = GetLootRollItemLink(rollID)
  local itemID = (link):match('item:(%d+):')
  local exception = LootClickerDB.exception_list.items[tonumber(itemID)] or ''

  private.frame:debug('START_LOOT_ROLL:', link, ', quality:', quality, ', bindOnPickUp:', bindOnPickUp, ', canNeed:', canNeed, ', canGreed:', canGreed, ', canDisenchant:', canDisenchant)
  if exception == "pass" then
    private.frame:debug('EXCEPTION:PASS:', link)
    return RollOnLoot(rollID, C.LOOT_ROLL_TYPE_PASS)
  elseif exception == "need" and canNeed then
    private.frame:debug('EXCEPTION:NEED:', link)
    return RollOnLoot(rollID, C.LOOT_ROLL_TYPE_NEED)
  elseif exception == "greed" and canGreed then
    private.frame:debug('EXCEPTION:GREED:', link)
    return RollOnLoot(rollID, C.LOOT_ROLL_TYPE_GREED)
  elseif exception == "disenchant" and canDisenchant then
    private.frame:debug('EXCEPTION:DISENCHANT:', link)
    return RollOnLoot(rollID, C.LOOT_ROLL_TYPE_DISENCHANT)
  elseif exception == "ignore" then
    private.frame:debug('EXCEPTION:IGNORE:', link)
    return
  end

  -- Initialize quality settings if they don't exist
  if not LootClickerDB.loot_settings[quality] then
    -- Try to get from defaultDB first
    if private.defaultDB and private.defaultDB.loot_settings and private.defaultDB.loot_settings[quality] then
      LootClickerDB.loot_settings[quality] = {}
      for k, v in pairs(private.defaultDB.loot_settings[quality]) do
        if type(v) == "table" then
          LootClickerDB.loot_settings[quality][k] = {}
          for k2, v2 in pairs(v) do
            LootClickerDB.loot_settings[quality][k][k2] = v2
          end
        else
          LootClickerDB.loot_settings[quality][k] = v
        end
      end
    else
      -- Create a safe default structure
      LootClickerDB.loot_settings[quality] = {
        enabled = false,
        only_boe = true,
        need_looter = false,
        greed_looter = true,
        disenchant_looter = false,
        smart_disenchant = {
          without_dis = false,
          only_boe = false,
        },
      }
    end
  end
  
  -- Ensure smart_disenchant exists even if quality settings exist but smart_disenchant is missing
  if not LootClickerDB.loot_settings[quality].smart_disenchant then
    LootClickerDB.loot_settings[quality].smart_disenchant = {
      without_dis = false,
      only_boe = false,
    }
  end

  if quality > ITEM_QUALITY_EPIC or not LootClickerDB.loot_settings[quality].enabled or (LootClickerDB.loot_settings[quality].only_boe and bindOnPickUp) then return end

  if LootClickerDB.loot_settings[quality].disenchant_looter then
    if LootClickerDB.loot_settings[quality].smart_disenchant.without_dis and not LootClickerDB.loot_settings[quality].only_boe then
      if bindOnPickUp and canDisenchant then
        private.frame:debug('SMART_DISENCHANT[WITHOUT]:DISENCHANT:', link)
        return RollOnLoot(rollID, C.LOOT_ROLL_TYPE_DISENCHANT)
      elseif LootClickerDB.loot_settings[quality].need_looter and canNeed then
        private.frame:debug('SMART_DISENCHANT[WITHOUT]:NEED:', link)
        return RollOnLoot(rollID, C.LOOT_ROLL_TYPE_NEED)
      elseif LootClickerDB.loot_settings[quality].greed_looter and canGreed then
        private.frame:debug('SMART_DISENCHANT[WITHOUT]:GREED:', link)
        return RollOnLoot(rollID, C.LOOT_ROLL_TYPE_GREED)
      else
        private.frame:debug('SMART_DISENCHANT[WITHOUT]:PASS:', link)
        return RollOnLoot(rollID, C.LOOT_ROLL_TYPE_PASS)
      end
    elseif LootClickerDB.loot_settings[quality].smart_disenchant.only_boe and LootClickerDB.loot_settings[quality].only_boe then
      if LootClickerDB.loot_settings[quality].need_looter and canNeed then
        private.frame:debug('SMART_DISENCHANT[BOE]:NEED:', link)
        return RollOnLoot(rollID, C.LOOT_ROLL_TYPE_NEED)
      elseif canDisenchant then
        private.frame:debug('SMART_DISENCHANT[BOE]:DISENCHANT:', link)
        return RollOnLoot(rollID, C.LOOT_ROLL_TYPE_DISENCHANT)
      elseif LootClickerDB.loot_settings[quality].greed_looter and canGreed then
        private.frame:debug('SMART_DISENCHANT[BOE]:GREED:', link)
        return RollOnLoot(rollID, C.LOOT_ROLL_TYPE_GREED)
      else
        private.frame:debug('SMART_DISENCHANT[BOE]:PASS:', link)
        return RollOnLoot(rollID, C.LOOT_ROLL_TYPE_PASS)
      end
    else
      if canDisenchant then
        private.frame:debug('DISENCHANT:DISENCHANT:', link)
        return RollOnLoot(rollID, C.LOOT_ROLL_TYPE_DISENCHANT)
      elseif LootClickerDB.loot_settings[quality].need_looter and canNeed then
        private.frame:debug('DISENCHANT:NEED:', link)
        return RollOnLoot(rollID, C.LOOT_ROLL_TYPE_NEED)
      elseif LootClickerDB.loot_settings[quality].greed_looter and canGreed then
        private.frame:debug('DISENCHANT:GREED:', link)
        return RollOnLoot(rollID, C.LOOT_ROLL_TYPE_GREED)
      else
        private.frame:debug('DISENCHANT:PASS:', link)
        return RollOnLoot(rollID, C.LOOT_ROLL_TYPE_PASS)
      end
    end
  else
    if LootClickerDB.loot_settings[quality].need_looter and canNeed then
      private.frame:debug('NEED:', link)
      return RollOnLoot(rollID, C.LOOT_ROLL_TYPE_NEED)
    elseif LootClickerDB.loot_settings[quality].greed_looter and canGreed then
      private.frame:debug('GREED:', link)
      return RollOnLoot(rollID, C.LOOT_ROLL_TYPE_GREED)
    else
      private.frame:debug('PASS:', link)
      return RollOnLoot(rollID, C.LOOT_ROLL_TYPE_PASS)
    end
  end
end

-- LOOT_BIND_CONFIRM
hooksecurefunc('LootSlot', function(slot)
  if not IsEnabled() then return end
  ConfirmLootSlot(slot)
  StaticPopup_Hide('LOOT_BIND')
end)
