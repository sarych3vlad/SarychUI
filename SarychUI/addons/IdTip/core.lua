local hooksecurefunc, select, UnitBuff, UnitDebuff, UnitAura, UnitGUID, GetGlyphSocketInfo, tonumber, strfind, IsAltKeyDown, wipe, pairs, pcall, debugprofilestop =
      hooksecurefunc, select, UnitBuff, UnitDebuff, UnitAura, UnitGUID, GetGlyphSocketInfo, tonumber, strfind, IsAltKeyDown, wipe, pairs, pcall, debugprofilestop

-- Global enabled state
IdTipEnabled = IdTipEnabled or true;

-- Tooltip context cache (updated on every tooltip build)
SarychUI_IDTip_LastTooltip = SarychUI_IDTip_LastTooltip or {}

-- Function to check if addon is enabled
local function IsEnabled()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.IdTip then
		return SarychUI.db.profile.addons.IdTip.enabled ~= false;
	end
	return IdTipEnabled;
end

-- Глобальная переменная для включения Alt-режима (для обратной совместимости)
IdTipAltMode = true

-- Состояние Alt клавиши (будет обновляться через AltMode)
local isAltPressed = false
local isRefreshing = false

local types = {
	spell		= "SpellID:",
	item		= "ItemID:",
	unit		= "NPC ID:",
	quest		= "QuestID:",
	talent		= "TalentID:",
	achievement	= "AchievementID:",
	criteria	= "CriteriaID:",
	ability		= "AbilityID:",
}

local typeLabels = {}
for _, label in pairs(types) do
	typeLabels[label] = true
end

local function GetShowOnAlt()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.IdTip then
		return SarychUI.db.profile.addons.IdTip.showOnAlt ~= false
	end
	return true
end

local function ShouldShowID()
	if not GetShowOnAlt() then
		return true
	end
	return isAltPressed
end

-- Profiling (enable with _G.SarychUI_DebugIDTipPerf = true)
local function perfStart()
	if _G.SarychUI_DebugIDTipPerf then
		return debugprofilestop()
	end
end

local function perfLog(startMs, label, ctxType, lines)
	if startMs and _G.SarychUI_DebugIDTipPerf then
		local elapsed = debugprofilestop() - startMs
		if elapsed > 1 then
			print(string.format(
				"SarychUI IDTipPerf: %s took %.2f ms, type=%s, lines=%s",
				label, elapsed, tostring(ctxType or "?"), tostring(lines or "?")
			))
		end
	end
end

local function SaveContext(tooltip, ctxType, id, idLabel, refresh)
	local ctx = SarychUI_IDTip_LastTooltip
	ctx.tooltip = tooltip
	ctx.type = ctxType
	ctx.id = id
	ctx.idLabel = idLabel or (ctxType and types[ctxType])
	if refresh then
		ctx.refresh = refresh
	end
end

local function ClearContextIfTooltip(tooltip)
	local ctx = SarychUI_IDTip_LastTooltip
	if ctx.tooltip == tooltip then
		wipe(ctx)
	end
end

local function CaptureRefresh(tooltip, refreshFn)
	if not IsEnabled() then return end
	if isRefreshing then return end
	local ctx = SarychUI_IDTip_LastTooltip
	ctx.tooltip = tooltip
	ctx.refresh = refreshFn
end

local function removeIdLines(tooltip)
	if not tooltip or not tooltip.GetName then return 0 end
	local tipName = tooltip:GetName()
	if not tipName then return 0 end

	local removed = 0
	local numLines = tooltip:NumLines() or 0
	for i = numLines, 1, -1 do
		local left = _G[tipName .. "TextLeft" .. i]
		if left then
			local text = left:GetText()
			if text and typeLabels[text] then
				left:SetText(nil)
				left:Hide()
				local right = _G[tipName .. "TextRight" .. i]
				if right then
					right:SetText(nil)
					right:Hide()
				end
				removed = removed + 1
			end
		end
	end
	if removed > 0 then
		tooltip:Show()
	end
	return removed
end

local function addLine(tooltip, id, typeLabel, ctxType)
	local perfStart = SarychUI_PerfDebug and SarychUI_PerfNow and SarychUI_PerfNow() or nil
	if not IsEnabled() or not tooltip or not id or not typeLabel then
		return;
	end
	if SarychUI_PerfLog then
		SarychUI_PerfLog("IdTip", "AddLine", tostring(ctxType or typeLabel) .. ":" .. tostring(id))
	end

	local ctx = SarychUI_IDTip_LastTooltip
	if ctx.tooltip == tooltip then
		ctx.id = id
		ctx.idLabel = typeLabel
		if ctxType then
			ctx.type = ctxType
		end
	end

	if not ShouldShowID() then
		removeIdLines(tooltip)
		return
	end

	removeIdLines(tooltip)

	tooltip:AddDoubleLine(typeLabel, "|cffffffff" .. id)
	tooltip:Show()
	if SarychUI_PerfSlow then
		SarychUI_PerfSlow("IdTip", "AddLineSlow", perfStart, tostring(ctxType or typeLabel) .. ":" .. tostring(id), 2)
	end
end

local function tryCaptureContextFromMouseFocus()
	if not IsEnabled() then return end
	local ctx = SarychUI_IDTip_LastTooltip
	if ctx.refresh then return end

	local tooltip = ctx.tooltip
	if not tooltip or not tooltip:IsShown() then
		tooltip = GameTooltip
	end
	if not tooltip or not tooltip:IsShown() then return end

	local mf = GetMouseFocus()
	if mf and mf.GetScript then
		local onEnter = mf:GetScript("OnEnter")
		if onEnter then
			ctx.tooltip = tooltip
			ctx.refresh = function()
				pcall(onEnter, mf)
			end
		end
	end
end

function IdTip_RefreshCurrentTooltip()
	if not IsEnabled() or not GetShowOnAlt() then return end

	local t0 = perfStart()
	local ctx = SarychUI_IDTip_LastTooltip
	local tooltip = ctx.tooltip

	if not tooltip or not tooltip:IsShown() then
		if GameTooltip and GameTooltip:IsShown() then
			tooltip = GameTooltip
			ctx.tooltip = tooltip
		else
			perfLog(t0, "UpdateCurrentTooltipID", nil, 0)
			return
		end
	end

	if not ctx.refresh then
		tryCaptureContextFromMouseFocus()
	end

	local lines = tooltip:NumLines() or 0

	if ctx.refresh then
		local rt0 = perfStart()
		isRefreshing = true
		ctx.refresh()
		isRefreshing = false
		perfLog(rt0, "RefreshTooltipContext", ctx.type, tooltip:NumLines() or lines)
	else
		if ShouldShowID() and ctx.id and ctx.idLabel then
			addLine(tooltip, ctx.id, ctx.idLabel, ctx.type)
		else
			removeIdLines(tooltip)
		end
	end

	perfLog(t0, "UpdateCurrentTooltipID", ctx.type, tooltip:NumLines() or lines)
end

-- All types, primarily for detached tooltips
local function onSetHyperlink(self, link)
	if not IsEnabled() then return end
	local perfStart = SarychUI_PerfDebug and SarychUI_PerfNow and SarychUI_PerfNow() or nil
	if SarychUI_PerfLog then
		SarychUI_PerfLog("IdTip", "SetHyperlink", link)
	end
	if not link then return end
    local linkType, id = string.match(link, "^(%a+):(%d+)")
    if not linkType or not id then return end

    CaptureRefresh(self, function()
        self:SetHyperlink(link)
    end)

    if linkType == "spell" or linkType == "enchant" or linkType == "trade" then
        SaveContext(self, "spell", id, types.spell, function() self:SetHyperlink(link) end)
        addLine(self, id, types.spell, "spell")
    elseif linkType == "talent" then
        SaveContext(self, "talent", id, types.talent, function() self:SetHyperlink(link) end)
        addLine(self, id, types.talent, "talent")
    elseif linkType == "quest" then
        SaveContext(self, "quest", id, types.quest, function() self:SetHyperlink(link) end)
        addLine(self, id, types.quest, "quest")
    elseif linkType == "achievement" then
        SaveContext(self, "achievement", id, types.achievement, function() self:SetHyperlink(link) end)
        addLine(self, id, types.achievement, "achievement")
    elseif linkType == "item" then
        SaveContext(self, "item", id, types.item, function() self:SetHyperlink(link) end)
        addLine(self, id, types.item, "item")
    end
	if SarychUI_PerfSlow then
		SarychUI_PerfSlow("IdTip", "SetHyperlinkSlow", perfStart, link, 2)
	end
end

hooksecurefunc(ItemRefTooltip, "SetHyperlink", onSetHyperlink)
hooksecurefunc(GameTooltip, "SetHyperlink", onSetHyperlink)

-- Spell / action setters (capture refresh context before OnTooltipSetSpell)
local function SafeHookTooltip(method, handler)
	if type(GameTooltip[method]) == "function" then
		hooksecurefunc(GameTooltip, method, handler)
	end
end

SafeHookTooltip("SetAction", function(self, slot)
	CaptureRefresh(self, function()
		GameTooltip:SetAction(slot)
	end)
end)

-- WotLK 3.3.5: SetSpell(index, bookType); retail+: SetSpellBookItem
SafeHookTooltip("SetSpell", function(self, index, bookType)
	CaptureRefresh(self, function()
		GameTooltip:SetSpell(index, bookType)
	end)
end)

SafeHookTooltip("SetSpellBookItem", function(self, index, bookType)
	CaptureRefresh(self, function()
		GameTooltip:SetSpellBookItem(index, bookType)
	end)
end)

SafeHookTooltip("SetPetAction", function(self, slot)
	CaptureRefresh(self, function()
		GameTooltip:SetPetAction(slot)
	end)
end)

SafeHookTooltip("SetShapeshift", function(self, slot)
	CaptureRefresh(self, function()
		GameTooltip:SetShapeshift(slot)
	end)
end)

SafeHookTooltip("SetTalent", function(self, tabIndex, talentIndex)
	CaptureRefresh(self, function()
		GameTooltip:SetTalent(tabIndex, talentIndex)
	end)
end)

SafeHookTooltip("SetGlyph", function(self, index, talentGroup)
	CaptureRefresh(self, function()
		GameTooltip:SetGlyph(index, talentGroup)
	end)
end)

-- Auras
SafeHookTooltip("SetUnitBuff", function(self, unit, index, filter)
	if not IsEnabled() then return end
	CaptureRefresh(self, function()
		GameTooltip:SetUnitBuff(unit, index, filter)
	end)
    local id = select(11, UnitBuff(unit, index, filter))
    if id then
		SaveContext(self, "aura", id, types.spell, function()
			GameTooltip:SetUnitBuff(unit, index, filter)
		end)
		addLine(self, id, types.spell, "aura")
	end
end)

SafeHookTooltip("SetUnitDebuff", function(self, unit, index, filter)
	if not IsEnabled() then return end
	CaptureRefresh(self, function()
		GameTooltip:SetUnitDebuff(unit, index, filter)
	end)
    local id = select(11, UnitDebuff(unit, index, filter))
    if id then
		SaveContext(self, "aura", id, types.spell, function()
			GameTooltip:SetUnitDebuff(unit, index, filter)
		end)
		addLine(self, id, types.spell, "aura")
	end
end)

SafeHookTooltip("SetUnitAura", function(self, unit, index, filter)
	if not IsEnabled() then return end
	CaptureRefresh(self, function()
		GameTooltip:SetUnitAura(unit, index, filter)
	end)
    local id = select(11, UnitAura(unit, index, filter))
    if id then
		SaveContext(self, "aura", id, types.spell, function()
			GameTooltip:SetUnitAura(unit, index, filter)
		end)
		addLine(self, id, types.spell, "aura")
	end
end)

hooksecurefunc("SetItemRef", function(link, text, button, ...)
	if not IsEnabled() then return end
	local args = {link, text, button, ...}
    local id = tonumber(link:match("spell:(%d+)"))
    if id then
		SaveContext(ItemRefTooltip, "spell", id, types.spell, function()
			SetItemRef(unpack(args))
		end)
		addLine(ItemRefTooltip, id, types.spell, "spell")
	end
end)

GameTooltip:HookScript("OnTooltipSetSpell", function(self)
	if not IsEnabled() then return end
    local id = select(3, self:GetSpell())
    if id then
		local ctx = SarychUI_IDTip_LastTooltip
		if ctx.tooltip == self then
			ctx.id = id
			ctx.type = ctx.type or "spell"
			ctx.idLabel = types.spell
		else
			SaveContext(self, "spell", id, types.spell, nil)
		end
		addLine(self, id, types.spell, "spell")
	end
end)

-- NPCs
SafeHookTooltip("SetUnit", function(self, unit)
	CaptureRefresh(self, function()
		GameTooltip:SetUnit(unit)
	end)
end)

GameTooltip:HookScript("OnTooltipSetUnit", function(self)
  if not IsEnabled() then return end
  local perfStart = SarychUI_PerfDebug and SarychUI_PerfNow and SarychUI_PerfNow() or nil
  local unit = select(2, self:GetUnit())
  if SarychUI_PerfLog then
    SarychUI_PerfLog("IdTip", "OnTooltipSetUnit", unit)
  end
  if unit then
    local guid = UnitGUID(unit)
    if guid then
		local id = tonumber(guid:sub(-10, -7), 16)
		if id and id > 0 then
			SaveContext(self, "unit", id, types.unit, function()
				GameTooltip:SetUnit(unit)
			end)
			addLine(self, id, types.unit, "unit")
		end
	end
  end
  if SarychUI_PerfSlow then
    SarychUI_PerfSlow("IdTip", "OnTooltipSetUnitSlow", perfStart, unit, 2)
  end
end)

-- Items
local function attachItemTooltip(self)
  if not IsEnabled() then return end
  local perfStart = SarychUI_PerfDebug and SarychUI_PerfNow and SarychUI_PerfNow() or nil
  local link = select(2, self:GetItem())
  if SarychUI_PerfLog then
    SarychUI_PerfLog("IdTip", "OnTooltipSetItem", link)
  end
  if link then
    local id = string.match(link, "item:(%d*)")
    if (id == "" or id == "0") and TradeSkillFrame ~= nil and TradeSkillFrame:IsVisible() and GetMouseFocus() and GetMouseFocus().reagentIndex then
      local selectedRecipe = TradeSkillFrame.RecipeList and TradeSkillFrame.RecipeList:GetSelectedRecipeID()
      if selectedRecipe then
	      for i = 1, 8 do
	        if GetMouseFocus().reagentIndex == i then
	          id = C_TradeSkillUI.GetRecipeReagentItemLink(selectedRecipe, i):match("item:(%d+):") or nil
	          break
	        end
	      end
      end
    end
    if id and id ~= "" and id ~= "0" then
		local refresh = SarychUI_IDTip_LastTooltip.refresh
		SaveContext(self, "item", id, types.item, refresh)
		addLine(self, id, types.item, "item")
    end
  end
  if SarychUI_PerfSlow then
    SarychUI_PerfSlow("IdTip", "OnTooltipSetItemSlow", perfStart, link, 2)
  end
end

local function hookItemSetter(method)
	if type(GameTooltip[method]) == "function" then
		hooksecurefunc(GameTooltip, method, function(self, ...)
			if not IsEnabled() then return end
			if SarychUI_PerfLog then
				SarychUI_PerfLog("IdTip", method, "GameTooltip")
			end
			local args = {...}
			CaptureRefresh(self, function()
				GameTooltip[method](GameTooltip, unpack(args))
			end)
		end)
	end
end

hookItemSetter("SetBagItem")
hookItemSetter("SetInventoryItem")
hookItemSetter("SetMerchantItem")
hookItemSetter("SetLootItem")
hookItemSetter("SetQuestItem")
hookItemSetter("SetQuestLogItem")
hookItemSetter("SetTradeSkillItem")
hookItemSetter("SetAuctionItem")
hookItemSetter("SetGuildBankItem")
hookItemSetter("SetCraftItem")

GameTooltip:HookScript("OnTooltipSetItem", attachItemTooltip)
ItemRefTooltip:HookScript("OnTooltipSetItem", attachItemTooltip)
ItemRefShoppingTooltip1:HookScript("OnTooltipSetItem", attachItemTooltip)
ItemRefShoppingTooltip2:HookScript("OnTooltipSetItem", attachItemTooltip)
ShoppingTooltip1:HookScript("OnTooltipSetItem", attachItemTooltip)
ShoppingTooltip2:HookScript("OnTooltipSetItem", attachItemTooltip)

-- Clear cache when tooltips hide
GameTooltip:HookScript("OnHide", function(self)
	ClearContextIfTooltip(self)
end)

if ItemRefTooltip then
	ItemRefTooltip:HookScript("OnHide", function(self)
		ClearContextIfTooltip(self)
	end)
end

-- Achievement Frame Tooltips
local f = CreateFrame("frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, what)
	if what == "Blizzard_AchievementUI" then
		for i,button in ipairs(AchievementFrameAchievementsContainer.buttons) do
			button:HookScript("OnEnter", function()
			if not IsEnabled() then return end
			GameTooltip:SetOwner(button, "ANCHOR_NONE")
			GameTooltip:SetPoint("TOPLEFT", button, "TOPRIGHT", 0, 0)
			SaveContext(GameTooltip, "achievement", button.id, types.achievement, function()
				GameTooltip:SetOwner(button, "ANCHOR_NONE")
				GameTooltip:SetPoint("TOPLEFT", button, "TOPRIGHT", 0, 0)
			end)
			addLine(GameTooltip, button.id, types.achievement, "achievement")
			GameTooltip:Show()
		end)
			button:HookScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		
		      local hooked = {}
      hooksecurefunc("AchievementButton_GetCriteria", function(index, renderOffScreen)
        local frame = _G["AchievementFrameCriteria" .. (renderOffScreen and "OffScreen" or "") .. index]
        if frame and not hooked[frame] then
          frame:HookScript("OnEnter", function(self)
            if not IsEnabled() then return end
            local button = self:GetParent() and self:GetParent():GetParent()
            if not button or not button.id then return end
            local criteriaid = select(10, GetAchievementCriteriaInfo(button.id, index))
            if criteriaid then
              GameTooltip:SetOwner(button:GetParent(), "ANCHOR_NONE")
              GameTooltip:SetPoint("TOPLEFT", button, "TOPRIGHT", 0, 0)
              SaveContext(GameTooltip, "achievement", button.id, types.achievement, function()
              	GameTooltip:SetOwner(button:GetParent(), "ANCHOR_NONE")
              	GameTooltip:SetPoint("TOPLEFT", button, "TOPRIGHT", 0, 0)
              end)
              addLine(GameTooltip, button.id, types.achievement, "achievement")
              addLine(GameTooltip, criteriaid, types.criteria, "criteria")
              GameTooltip:Show()
            end
          end)
          frame:HookScript("OnLeave", function()
            GameTooltip:Hide()
          end)
          hooked[frame] = true
        end
      end)
    end
	end
end)

-- Quests
hooksecurefunc("SelectQuestLogEntry", function(self)
	if not IsEnabled() then return end
local index = GetQuestLogSelection()
	if QuestLogFrame:IsVisible() then
	if not index then return end
	local link = GetQuestLink(index)
	if not link then return end

	local id = tonumber(link:match(":(%d+):"))
	local f = CreateFrame("frame")
		GameTooltip:SetOwner(QuestLogScrollFrame, "ANCHOR_NONE");
		GameTooltip:SetPoint("TOPLEFT", QuestLogScrollFrame, "TOPRIGHT", 0, 0)
		SaveContext(GameTooltip, "quest", id, types.quest, function()
			GameTooltip:SetOwner(QuestLogScrollFrame, "ANCHOR_NONE")
			GameTooltip:SetPoint("TOPLEFT", QuestLogScrollFrame, "TOPRIGHT", 0, 0)
		end)
		addLine(GameTooltip, id, types.quest, "quest")
		GameTooltip:Show()
		f:HookScript("OnLeave", function()
			GameTooltip:Hide()
		end)
    end
end)

-- Используем систему AltMode из SarychUI
local function OnAltStateChanged(altPressed)
	if not IsEnabled() then return end
	local t0 = perfStart()

    local showOnAlt = GetShowOnAlt()
    
    if showOnAlt then
        isAltPressed = altPressed
		local activeTooltip = SarychUI_IDTip_LastTooltip.tooltip
		if (GameTooltip and GameTooltip:IsShown()) or (activeTooltip and activeTooltip:IsShown()) then
			if SarychUI and SarychUI.AltMode and SarychUI.AltMode.RequestTooltipRefresh then
				SarychUI.AltMode:RequestTooltipRefresh()
			else
				IdTip_RefreshCurrentTooltip()
			end
		end
    else
        isAltPressed = true
    end

	perfLog(t0, "MODIFIER_STATE_CHANGED handler", SarychUI_IDTip_LastTooltip.type, nil)
end

-- Глобальная функция для обновления состояния (вызывается из wrapper.lua)
function IdTip_UpdateAltState()
    if SarychUI and SarychUI.AltMode then
        local altPressed = SarychUI.AltMode:IsAltPressed()
        OnAltStateChanged(altPressed)
    end
end

-- Регистрируем колбэк в AltMode при инициализации
local function InitializeAltMode()
    if SarychUI and SarychUI.AltMode then
        SarychUI.AltMode:RegisterCallback("IdTip", OnAltStateChanged)
        
        if GetShowOnAlt() then
            isAltPressed = SarychUI.AltMode:IsAltPressed()
        else
            isAltPressed = true
        end
    else
        isAltPressed = IsAltKeyDown()
    end
end

-- Инициализируем AltMode при загрузке
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "SarychUI" then
        InitializeAltMode()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        InitializeAltMode()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

if SarychUI and SarychUI.AltMode then
    InitializeAltMode()
end
