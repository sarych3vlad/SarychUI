-- Native automation runtime; LootClickerDB is retained for saved-setting compatibility.
local function IsEnabled()
  local feature = SarychUI.LootRolls
  return feature and feature.active == true
end

local coro_create, coro_status, coro_yield, coro_resume = coroutine.create, coroutine.status, coroutine.yield, coroutine.resume
local assert, setmetatable, tostring, rawset, pairs, type = assert, setmetatable, tostring, rawset, pairs, type
local CreateFrame, GetAddOnMetadata, ReloadUI, GetLocale, IsSpellKnown = CreateFrame, GetAddOnMetadata, ReloadUI, GetLocale, IsSpellKnown
local locale = GetLocale()
local private = SarychUI.LootRolls

-- Make IsEnabled available to other files through private
private.IsEnabled = IsEnabled
-- Set addon name explicitly since we're loaded through SarychUI.toc
local addon_name = "SarychUILootRolls"
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

}
private.threads = {}

function private:coro_thread(f)
  local thread = coro_create(f)
  local thread_id = tostring(thread)
  private.threads[thread_id] = thread
  assert(coro_resume(thread))
end

function private:coro_wait()
  private.frame:Show() -- enable private.frame:OnUpdate script
  coro_yield()
end

function private:CheckAllVariables(dest_table, src_table)
  for var_name, var_default_data in pairs(src_table) do
    if dest_table[var_name] == nil then
      dest_table[var_name] = type(var_default_data) == 'table' and CopyTable(var_default_data) or var_default_data
    elseif type(var_default_data) == 'table' then
      self:CheckAllVariables(dest_table[var_name], var_default_data)
    end
  end
end

private.frame = CreateFrame('Frame', addon_name)
private.frame:Hide()
private.frame:SetScript('OnUpdate', function(self)
  -- функция обработки всех потоков coroutine функций на каждом такте вызова private.frame:OnUpdate скрипта (~0,01-0,03 сек.)
  for thread_id, thread in pairs(private.threads) do
    local status = coro_status(thread)
    if status == 'dead' then
      -- удаление потока coroutine функции, если было завершено ее выполнение
      private.threads[thread_id] = nil
    elseif status == 'suspended' then
      -- возобновление coroutine функции, если было приостановлено ее выполнение
      assert(coro_resume(thread))
    end
  end
  if not next(private.threads) then self:Hide() end
end)
private.frame:SetScript('OnEvent', function(self, event, ...)
  if not self[event] then return end
  self[event](self, ...)
end)



function private.frame:OnEnable()
	if not IsEnabled() then
		return;
	end
  self:RegisterEvent('START_LOOT_ROLL')
  self:RegisterEvent('CONFIRM_LOOT_ROLL')
  self:RegisterEvent('CONFIRM_DISENCHANT_ROLL')

end

function private.frame:OnDisable()
  self:UnregisterAllEvents()
  self:Hide()
  private.threads = {}
end


function private.frame:print(...)
  local prefix = '['..addon_name..']:'
  print(prefix, ...)
end

function private.frame:debug(...)
  if not private.debug then return end
  local prefix = '['..addon_name..':DEBUG]:'
  print(prefix, ...)
end

