local mod = LibStub("AceAddon-3.0"):GetAddon("InternalCooldowns"):NewModule("PaperDollFrame", "AceEvent-3.0");
local lib = LibStub("LibInternalCooldowns-1.1");

-- Function to check if addon is enabled
local function IsEnabled()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.InternalCooldowns then
		return SarychUI.db.profile.addons.InternalCooldowns.enabled ~= false;
	end
	return InternalCooldownsEnabled ~= false;
end

local GetInventorySlotInfo = GetInventorySlotInfo;
local SLOT_NAME_BY_ID = {}
-- Строим таблицу имён слотов по реальным ID клиента
local function BuildSlotNameMap()
    local map = {
        [select(1, GetInventorySlotInfo("AmmoSlot"))] = "CharacterAmmoSlot",
        [select(1, GetInventorySlotInfo("HeadSlot"))] = "CharacterHeadSlot",
        [select(1, GetInventorySlotInfo("NeckSlot"))] = "CharacterNeckSlot",
        [select(1, GetInventorySlotInfo("ShoulderSlot"))] = "CharacterShoulderSlot",
        [select(1, GetInventorySlotInfo("ShirtSlot"))] = "CharacterShirtSlot",
        [select(1, GetInventorySlotInfo("ChestSlot"))] = "CharacterChestSlot",
        [select(1, GetInventorySlotInfo("WaistSlot"))] = "CharacterWaistSlot",
        [select(1, GetInventorySlotInfo("LegsSlot"))] = "CharacterLegsSlot",
        [select(1, GetInventorySlotInfo("FeetSlot"))] = "CharacterFeetSlot",
        [select(1, GetInventorySlotInfo("WristSlot"))] = "CharacterWristSlot",
        [select(1, GetInventorySlotInfo("HandsSlot"))] = "CharacterHandsSlot",
        [select(1, GetInventorySlotInfo("Finger0Slot"))] = "CharacterFinger0Slot",
        [select(1, GetInventorySlotInfo("Finger1Slot"))] = "CharacterFinger1Slot",
        [select(1, GetInventorySlotInfo("Trinket0Slot"))] = "CharacterTrinket0Slot",
        [select(1, GetInventorySlotInfo("Trinket1Slot"))] = "CharacterTrinket1Slot",
        [select(1, GetInventorySlotInfo("BackSlot"))] = "CharacterBackSlot",
        [select(1, GetInventorySlotInfo("MainHandSlot"))] = "CharacterMainHandSlot",
        [select(1, GetInventorySlotInfo("SecondaryHandSlot"))] = "CharacterSecondaryHandSlot",
        [select(1, GetInventorySlotInfo("RangedSlot"))] = "CharacterRangedSlot",
        [select(1, GetInventorySlotInfo("TabardSlot"))] = "CharacterTabardSlot",
    }
    SLOT_NAME_BY_ID = map
end
BuildSlotNameMap()

local equippedItems = {};

function mod:OnEnable()
    if not IsEnabled() then
        return
    end
    
    self:RegisterEvent("UNIT_INVENTORY_CHANGED")
    self:UNIT_INVENTORY_CHANGED("player")
    lib.RegisterCallback(mod, "InternalCooldowns_Proc")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
end;

function mod:OnDisable()
    self:UnregisterEvent("UNIT_INVENTORY_CHANGED")
    lib.UnregisterCallback(mod, "InternalCooldowns_Proc")
    self:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
end;

function mod:UNIT_INVENTORY_CHANGED(unit)
    if unit == "player" then
        wipe(equippedItems)
    for i = 1, 19 do
            local link = GetInventoryItemLink(unit, i)
            if link then
                equippedItems[tonumber(link:match("item:(%d+)") or 0)] = i
            end
        end
    end
end;

function mod:InternalCooldowns_Proc(callback, itemID, spellID, start, duration, procSource)
    local slot = equippedItems[itemID]
    if not slot then return end
    -- Обновляем только тринкеты (13/14), чтобы не рисовать круг на других слотах
    if slot == 13 or slot == 14 then
        self:SetPaperDollSlotCooldown(slot, start, duration, 1)
    end
end;

function mod:PLAYER_EQUIPMENT_CHANGED(event, slotId)
    -- Обновляем кэш предметов и пробуем подтянуть текущий КД из клиента/библиотеки
    self:UNIT_INVENTORY_CHANGED("player")
    -- Интересуют только тринкеты
    -- Определяем реальные ID тринкетов
    local tr0 = select(1, GetInventorySlotInfo("Trinket0Slot")) or 13
    local tr1 = select(1, GetInventorySlotInfo("Trinket1Slot")) or 14
    if slotId ~= tr0 and slotId ~= tr1 then return end
    local start, duration, enable = GetInventoryItemCooldown("player", slotId)
    if start and duration and enable then
        self:SetPaperDollSlotCooldown(slotId, start, duration, enable)
    end
end;

function mod:SetPaperDollSlotCooldown(slotId, start, duration, enable)
    local slotName = SLOT_NAME_BY_ID[slotId]
    if not slotName then return end
    local button = _G[slotName]
    if not button then return end
    local cooldown = _G[slotName.."Cooldown"] or button.Cooldown
    if not cooldown then return end
    -- Включаем спираль
    if start and duration and duration > 0 and enable and enable ~= 0 then
        CooldownFrame_Set(cooldown, start, duration, 1)
    else
        CooldownFrame_Set(cooldown, 0, 0, 0)
    end
end;