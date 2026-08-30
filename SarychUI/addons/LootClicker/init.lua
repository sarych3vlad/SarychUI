-- Global enabled state (SarychUI wrapper sets true on enable)
LootClickerEnabled = false;

-- Function to check if addon is enabled
local function IsEnabled()
	if LootClickerEnabled == false then
		return false;
	end
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.LootClicker then
		return SarychUI.db.profile.addons.LootClicker.enabled == true;
	end
	return LootClickerEnabled == true;
end

local coro_create, coro_status, coro_yield, coro_resume = coroutine.create, coroutine.status, coroutine.yield, coroutine.resume
local assert, setmetatable, tostring, rawset, pairs, type = assert, setmetatable, tostring, rawset, pairs, type
local CreateFrame, GetAddOnMetadata, ReloadUI, GetLocale, IsSpellKnown = CreateFrame, GetAddOnMetadata, ReloadUI, GetLocale, IsSpellKnown
local locale = GetLocale()
local _, private = ...

-- Make IsEnabled available to other files through private
private.IsEnabled = IsEnabled
-- Set addon name explicitly since we're loaded through SarychUI.toc
local addon_name = "LootClicker"
local current_version = "9.7" -- GetAddOnMetadata won't work when loaded through SarychUI.toc

private.debug = false
private.hooks = {} -- table with original functions
private.L = setmetatable(private.locale[locale] or private.locale['enUS'], {
  __index = function(tab, key)
    local value = tostring(key)
    rawset(tab, key, value)
    return value
  end
})
private.defaultDB = {
  version = current_version,
  enabled = true,
  loot_settings = {
    [ITEM_QUALITY_UNCOMMON] = {
      enabled = true,
      only_boe = true,
      need_looter = false,
      greed_looter = true,
      disenchant_looter = false,
      smart_disenchant = {
        with_dis = false,
        without_dis = false,
        only_boe = false,
      },
    },
    [ITEM_QUALITY_RARE] = {
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
    },
    [ITEM_QUALITY_EPIC] = {
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
    },
  },
  exception_list = {
    sort = {
      [1] = 'descending',
      [2] = 'name',
    },
    items = {}
  },
  spam_filter = {
    enabled = false,
    clicked_btn = false,
    roll_result = false,
    won = false,
  },
}
private.constants = {
  LOOT_ROLL_TYPE_PASS = 0,
  LOOT_ROLL_TYPE_NEED = 1,
  LOOT_ROLL_TYPE_GREED = 2,
  LOOT_ROLL_TYPE_DISENCHANT = 3,
  EXCEPTION_COLORED = ('|cffff8ae4%s|r'):format(private.L["From the list of exceptions"]),
  NEED_COLORED = ('|cff3fc738%s|r'):format(NEED),
  GREED_COLORED = ('|cffe0c70d%s|r'):format(GREED),
  ROLL_DISENCHANT_COLORED = ('|cff4a9ae0%s|r'):format(ROLL_DISENCHANT),
  PASS_COLORED = ('|cffba1818%s|r'):format(PASS),
  loot_patterns = {
    clicked_btn = {
      LOOT_ROLL_DISENCHANT_SELF,
      LOOT_ROLL_GREED_SELF,
      LOOT_ROLL_NEED_SELF,
      LOOT_ROLL_PASSED_SELF,
      LOOT_ROLL_DISENCHANT,
      LOOT_ROLL_GREED,
      LOOT_ROLL_NEED,
      LOOT_ROLL_PASSED,
    },
    roll_result = {
      LOOT_ROLL_ROLLED_DE,
      LOOT_ROLL_ROLLED_GREED,
      LOOT_ROLL_ROLLED_NEED,
      LOOT_ROLL_ALL_PASSED,
    },
    won = {
      LOOT_ITEM_SELF,
      LOOT_ITEM_SELF_MULTIPLE,
      LOOT_ROLL_YOU_WON,
      LOOT_ROLL_YOU_WON_NO_SPAM_DE,
      LOOT_ROLL_YOU_WON_NO_SPAM_GREED,
      LOOT_ROLL_YOU_WON_NO_SPAM_NEED,
      LOOT_ROLL_WON,
      LOOT_ROLL_WON_NO_SPAM_DE,
      LOOT_ROLL_WON_NO_SPAM_GREED,
      LOOT_ROLL_WON_NO_SPAM_NEED,
    },
  },
}
private.threads = {}

function private:coro_thread(f)
  local thread = coro_create(f)
  local thread_id = tostring(thread)
  private.threads[thread_id] = thread
  assert(coro_resume(thread))
end

function private:coro_wait()
  LootClicker:Show() -- enable LootClicker:OnUpdate script
  coro_yield()
end

function private:CheckAllVariables(dest_table, src_table)
  for var_name, var_default_data in pairs(src_table) do
    if not dest_table[var_name] then
      dest_table[var_name] = var_default_data
    elseif type(var_default_data) == 'table' then
      self:CheckAllVariables(dest_table[var_name], var_default_data)
    end
  end
end

LootClicker = CreateFrame('Frame', addon_name)
LootClicker:Hide()
LootClicker:SetScript('OnUpdate', function(self)
  -- функция обработки всех потоков coroutine функций на каждом такте вызова LootClicker:OnUpdate скрипта (~0,01-0,03 сек.)
  for thread_id, thread in pairs(private.threads) do
    local status = coro_status(thread)
    if status == 'dead' then
      -- удаление потока coroutine функции, если было завершено ее выполнение
      private.threads[thread_id] = nil
      self:Hide() -- disable LootClicker:OnUpdate script
    elseif status == 'suspended' then
      -- возобновление coroutine функции, если было приостановлено ее выполнение
      assert(coro_resume(thread))
    end
  end
end)
LootClicker:SetScript('OnEvent', function(self, event, ...)
  if not self[event] then return end
  self[event](self, ...)
end)

LootClicker:RegisterEvent('VARIABLES_LOADED')
LootClicker:RegisterEvent('PLAYER_ENTERING_WORLD')

function LootClicker:OnInitilize()
  if not LootClickerDB then LootClickerDB = private.defaultDB end
  if not LootClickerDB.version or LootClickerDB.version ~= current_version then
    private:CheckAllVariables(LootClickerDB, private.defaultDB) -- check variables after update
    LootClickerDB.version = current_version
  end

  if LootClickerDB.enabled then
    self:OnEnable()
  else
    self:OnDisable()
  end
end

function LootClicker:OnEnable()
	if not IsEnabled() then
		return;
	end
  self:RegisterEvent('START_LOOT_ROLL')
  self:RegisterEvent('CONFIRM_LOOT_ROLL')
  self:RegisterEvent('CONFIRM_DISENCHANT_ROLL')
  self:RegisterEvent('ZONE_CHANGED_NEW_AREA')
  self:RegisterEvent('PARTY_LOOT_METHOD_CHANGED')

  private:UpdateMessageEventFilterState()
end

function LootClicker:OnDisable()
  self:UnregisterAllEvents()
end

function LootClicker:VARIABLES_LOADED()
  self:OnInitilize()
end

function LootClicker:PLAYER_ENTERING_WORLD()
  private.constants.HAS_DISENCHANT = IsSpellKnown(13262)
  -- load config when all API are available and work correctly.
  if private.LoadConfig then
    private:LoadConfig()
  end
end

function LootClicker:print(...)
  local prefix = '['..addon_name..']:'
  print(prefix, ...)
end

function LootClicker:debug(...)
  if not private.debug then return end
  local prefix = '['..addon_name..':DEBUG]:'
  print(prefix, ...)
end

StaticPopupDialogs["LOOT_CLICKER_HARD_RESET"] = {
  text = addon_name..'\n\n'..private.L["Are you sure you want to reset |cffff0000ALL|r the settings of the |cff00ff00current|r character and reload the user interface?"],
  button1 = YES,
  button2 = NO,
  OnAccept = function()
    LootClickerDB = nil
    ReloadUI()
  end,
  timeout = 0,
  showAlertGear = true,
  exclusive = true,
  whileDead = true,
  hideOnEscape = true,
  enterClicksFirstButton = true
}
