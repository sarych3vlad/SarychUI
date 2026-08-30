-- SarychUI Tools Module
-- Ported from sarTools

local pairs, select, pcall = pairs, select, pcall
local floor, max, min = math.floor, math.max, math.min
local abs, sqrt, deg, atan2, ceil, cos, rad, sin, exp = math.abs, math.sqrt, math.deg, math.atan2, math.ceil, math.cos, math.rad, math.sin, math.exp
local format = string.format
local gsub, find, gmatch = string.gsub, string.find, string.gmatch
local tinsert = table.insert
local wipe = wipe or table.wipe
local GetTime = GetTime

local moduleName = "tools"
local module = {}
local S = {}  -- State table to stay under Lua's 200 locals limit

-- Timers UI lives under «Текст перезарядки» (cc); keep runtime in tools.
local TIMERS_MODULE = "cc"
local function TimersDB()
	local modules = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return modules and modules[TIMERS_MODULE]
end

-- Floating text filter settings live under floating_text; runtime stays in tools.
local FLOATING_TEXT_MODULE = "floating_text"
local function FloatingTextDB()
	local modules = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return modules and modules[FLOATING_TEXT_MODULE]
end

-- Dispel highlight UI lives under «Ауры» (auras); runtime stays in tools.
local AURAS_MODULE = "auras"
local function AurasDB()
	local modules = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return modules and modules[AURAS_MODULE]
end

-- Pet name shortening UI lives under «Фреймы» (frame); runtime stays in tools.
local FRAME_MODULE = "frame"
local function FrameDB()
	local modules = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return modules and modules[FRAME_MODULE]
end

-- Register module
SarychUI:RegisterModule(moduleName, module)

-- Convenience accessor for this module's db
local function DB()
    if not SarychUI or not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules then
        return nil
    end
    return SarychUI.db.profile.modules[moduleName]
end

-- Подключаем AceTimer для throttling OnUpdate скриптов (оптимизация производительности)
local AceTimer = LibStub("AceTimer-3.0", true)

-- Focuser functionality
local mouseButton = "1"
S.focuserButton, S.createFrameHook, S.scannerFrame = nil, nil, nil
S.updateTimers = {}

-- Helper function to get modifier key name from setting
local function GetFocuserModifier()
    local db = DB()
    if not db then return "ALT" end
    
    local key = db.focuserModifierKey or 2
    if key == 1 then
        return "SHIFT"
    elseif key == 2 then
        return "ALT"
    elseif key == 3 then
        return "CTRL"
    end
    return "ALT"  -- Default to ALT
end

-- EscToOK functionality
S.escToOkHooked, S.origOnKeyDown, S.origCancelOnClick = false, nil, nil

-- Loot reanchor functionality
S.lootFramesHooked, S.lootFrameHooks, S.lootDefaultPositions = false, {}, {}

-- Dispel highlight functionality
S.dispelEventFrame, S.dispelUpdateFrame = nil, nil
-- Backstop tick only: UNIT_AURA / PLAYER_TARGET_CHANGED / UNIT_FACTION drive the
-- actual refresh, so this does not need to run at frame rate.
local DISPEL_TICK = 0.1

-- Class-based dispel capabilities
local _, playerClass = UnitClass("player")
local CAN_REMOVE = {
    Magic  = (playerClass=="PRIEST" or playerClass=="SHAMAN" or playerClass=="PALADIN" or playerClass=="MAGE" or playerClass=="WARRIOR"),
    Enrage = (playerClass=="HUNTER" or playerClass=="DRUID" or playerClass=="ROGUE" or playerClass=="WARRIOR" or playerClass=="SHAMAN"),
}

-- Pet name shortening functionality
S.petNameShorteningHooked = false
local MAX_NAME_LENGTH = 26

-- Alt CD announcement functionality
S.altCdHooksInstalled, S.altCdEnabled = false, false
S.altCdUnitBarEventFrame = nil
S.altCdAuraUpdateHooked = false

-- Alt FPS functionality
S.altFpsFrame, S.altFpsShown, S.altFpsAltPressed = nil, false, false
S.altFpsOriginalFonts, S.altFpsReapplyScale = {}, false

-- SpeedyLoad functionality
S.speedyLoadFrame, S.speedyLoadInitialized, S.speedyLoadEnteredOnce = nil, false, false

-- Flight Times functionality
S.flightTimesEnabled, S.flightTimesFrame, S.flightCheckFrame = false, nil, nil
S.flightTimesTracker = { active = false, startTime = 0, duration = 0 }
S.startFlightTimesFunc, S.stopFlightTimesFunc, S.setFlightTimesTextFunc = nil, nil, nil
S.flightAcc, S.flightDataCache, S.flightIconPulsePhase = 0, nil, 0

-- Easy Item Destroy functionality
S.easyItemDestroyEnabled, S.easyDelFrame, S.easyItemDestroyInitFrame = false, nil, nil

-- Tooltip cursor functionality
S.tooltipCursorAnchored, S.tooltipCursorHooked, S.tooltipCursorEventFrame, S.tooltipCursorAltPressed = false, false, nil, false

-- Castbar timer functionality
S.castbarTimersHooked = false

-- Invite countdown functionality
S.inviteCountdownFrame, S.inviteCountdownEventFrame, S.inviteCountdownPopupTimerFrame = nil, nil, nil
S.inviteCountdownInitialized, S.inviteTrackers, S.pvpFirstTrigger, S.popupTimer = false, nil, 0, nil
S.startInviteTracker, S.stopInviteTracker, S.startInvitePopupTimer, S.stopInvitePopupTimer = nil, nil, nil, nil
S.updateInvitePopupTimer, S.anchorInviteUnder, S.setInviteSmartText, S.hookInvitePopupButtons = nil, nil, nil, nil

-- Arena countdown functionality
S.arenaCountdownFrame, S.arenaCountdownEventFrame, S.arenaCountdownInitialized, S.arenaTracker = nil, nil, false, nil

S.startArenaCountdownFunc, S.stopArenaCountdownFunc, S.setArenaSmartTextFunc = nil, nil, nil

-- Combat Text shifting functionality
S.combatTextHooked, S.combatTextHooks, S.combatTextFlag = false, {}, false
S.combatTextFrame, S.combatTextPlusAnchor, S.combatTextMinusAnchor, S.combatTextLessAnchor = nil, nil, nil, nil

-- Raid Boss Emote repositioning functionality
S.raidBossEmoteHooked, S.raidBossEmoteFrame, S.raidBossRepositioned = false, nil, false
S.originalRaidBossPosition, S.originalRaidBossWidth, S.lastAppliedOffset = nil, nil, nil

-- Error filter functionality
S.errorFilterInitialized = false
S.errorFilterFrames = {
    created = false,
    enabled = false,
    altOnly = false,
    lastMsg = nil,
    lastAt = 0,
    origHandler = nil,
    filtered = nil, -- FilteredErrorsFrame
    sys = nil, -- SysMsgInfoFrame
}

-- BlizzMove functionality
S.blizzMoveInitialized, S.blizzMoveFrame = false, nil
S.blizzMoveDefaults = {
    AchievementFrame = {save = true},
    CalendarFrame = {save = true},
    AuctionFrame = {save = true},
    GuildBankFrame = {save = true},
}

local function ShouldSkipPlayerFrameFocus()
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    return db and db.enabled and db.enableFocuser == 1 and db.enableAltUnitBars == 1
end

local function InstallFocuserPlayerMouseoverGuard(button)
    if not button or not button.HookScript or button.__SarychUIPlayerMouseoverGuard then
        return
    end

    button:HookScript("PreClick", function(self, clickedButton, down)
        if not down or clickedButton ~= "LeftButton" then
            return
        end
        if not ShouldSkipPlayerFrameFocus() then
            return
        end
        if not UnitExists("mouseover") or not UnitIsUnit("mouseover", "player") then
            return
        end
        self._sarychFocuserOldType1 = self:GetAttribute("type1")
        self._sarychFocuserOldMacro = self:GetAttribute("macrotext")
        self:SetAttribute("type1", nil)
        self:SetAttribute("macrotext", nil)
    end)
    button:HookScript("PostClick", function(self)
        if self._sarychFocuserOldType1 == nil and self._sarychFocuserOldMacro == nil then
            return
        end
        self:SetAttribute("type1", self._sarychFocuserOldType1 or "macro")
        self:SetAttribute("macrotext", self._sarychFocuserOldMacro or "/focus mouseover")
        self._sarychFocuserOldType1 = nil
        self._sarychFocuserOldMacro = nil
    end)
    button.__SarychUIPlayerMouseoverGuard = true
end

-- Set focus hotkey on unit frame
local function SetFocusHotkey(frame)
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not db.enabled then return end
    
    if not frame or not frame.SetAttribute then return end
    
    -- Всегда сначала очищаем все возможные модификаторы
    frame:SetAttribute("SHIFT-type"..mouseButton, nil)
    frame:SetAttribute("ALT-type"..mouseButton, nil)
    frame:SetAttribute("CTRL-type"..mouseButton, nil)
    
    -- Если Focuser включен, устанавливаем только выбранный модификатор
    if db.enableFocuser == 1 then
        if frame == PlayerFrame and ShouldSkipPlayerFrameFocus() then
            return
        end
        local modifier = GetFocuserModifier()
        frame:SetAttribute(modifier.."-type"..mouseButton, "focus")
    end
end

-- Badge Stack Buyer: Shift+LeftClick emblem at merchant → quantity split → buy.
-- Emblems use extendedCost on 3.3.5, so BuyMerchantItem(index, amount) is ignored;
-- we buy 1/item but spread purchases across frames to avoid client freeze / DC.
S.badgeBuyerFrame, S.badgeBuyerInitialized = nil, false
S.badgeBuyerHooksInstalled = false
S.badgeBuyQueue = S.badgeBuyQueue or { index = nil, remaining = 0 }
S.badgeBuyDriver = S.badgeBuyDriver or nil

local BADGE_ITEM_IDS = {
	[40752] = true, -- Emblem of Heroism
	[40753] = true, -- Emblem of Valor
	[45624] = true, -- Emblem of Conquest
	[47241] = true, -- Emblem of Triumph
	[49426] = true, -- Emblem of Frost
}

local BADGE_BUY_PER_FRAME = 1 -- keep at 1: safer against freeze / server kick

local function GetBadgeItemIDFromLink(link)
	if not link then return nil end
	return tonumber(link:match("item:(%d+)"))
end

local function StopBadgeBuyQueue()
	local q = S.badgeBuyQueue
	if q then
		q.index = nil
		q.remaining = 0
	end
	if S.badgeBuyDriver then
		S.badgeBuyDriver:Hide()
	end
end

local function EnsureBadgeBuyDriver()
	if S.badgeBuyDriver then return S.badgeBuyDriver end
	local f = CreateFrame("Frame")
	f:Hide()
	f:SetScript("OnUpdate", function(self)
		local q = S.badgeBuyQueue
		if not q or not q.index or (q.remaining or 0) <= 0 then
			StopBadgeBuyQueue()
			return
		end
		if not MerchantFrame or not MerchantFrame:IsShown() then
			StopBadgeBuyQueue()
			return
		end
		local batch = BADGE_BUY_PER_FRAME
		if batch > q.remaining then batch = q.remaining end
		for _ = 1, batch do
			BuyMerchantItem(q.index)
		end
		q.remaining = q.remaining - batch
		if q.remaining <= 0 then
			StopBadgeBuyQueue()
		end
	end)
	S.badgeBuyDriver = f
	return f
end

local function StartBadgeBuyQueue(index, amount)
	amount = tonumber(amount) or 0
	if not index or amount <= 0 then return end
	local q = S.badgeBuyQueue
	-- If a buy is already running for the same index, append; otherwise replace.
	if q.index == index and (q.remaining or 0) > 0 then
		q.remaining = q.remaining + amount
	else
		q.index = index
		q.remaining = amount
	end
	EnsureBadgeBuyDriver():Show()
end

local function EnsureStackSplitFrame()
	-- Create StackSplitFrame if missing (1:1 as in original XML)
	if _G.StackSplitFrame and _G.OpenStackSplitFrame then
		return
	end
	if not _G.StackSplitFrame then
		local f = CreateFrame("Frame", "StackSplitFrame", UIParent)
		f:SetFrameStrata("HIGH")
		f:SetToplevel(true)
		f:EnableMouse(true)
		f:EnableKeyboard(true)
		f:SetClampedToScreen(true)
		f:SetSize(172, 96)
		f:Hide()

		local bg = f:CreateTexture(nil, "BACKGROUND")
		bg:SetTexture("Interface\\MoneyFrame\\UI-MoneyFrame")
		bg:SetSize(256, 32)
		bg:SetTexCoord(0, 0.671875, 0, 0.75)
		bg:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

		local StackSplitText = f:CreateFontString("StackSplitText", "BACKGROUND", "GameFontHighlight")
		StackSplitText:SetJustifyH("RIGHT")
		StackSplitText:SetPoint("RIGHT", f, "RIGHT", -50, 18)

		local LeftBtn = CreateFrame("Button", "StackSplitLeftButton", f)
		LeftBtn:SetSize(16, 16)
		LeftBtn:SetPoint("RIGHT", f, "CENTER", -59, 18)
		LeftBtn:SetNormalTexture("Interface\\MoneyFrame\\Arrow-Left-Up")
		LeftBtn:SetPushedTexture("Interface\\MoneyFrame\\Arrow-Left-Down")
		LeftBtn:SetDisabledTexture("Interface\\MoneyFrame\\Arrow-Left-Disabled")

		local RightBtn = CreateFrame("Button", "StackSplitRightButton", f)
		RightBtn:SetSize(16, 16)
		RightBtn:SetPoint("LEFT", f, "CENTER", 64, 18)
		RightBtn:SetNormalTexture("Interface\\MoneyFrame\\Arrow-Right-Up")
		RightBtn:SetPushedTexture("Interface\\MoneyFrame\\Arrow-Right-Down")
		RightBtn:SetDisabledTexture("Interface\\MoneyFrame\\Arrow-Right-Disabled")

		local OkayBtn = CreateFrame("Button", "StackSplitOkayButton", f, "UIPanelButtonTemplate")
		OkayBtn:SetSize(64, 24); OkayBtn:SetText(OKAY)
		OkayBtn:SetPoint("RIGHT", f, "BOTTOM", -3, 32)
		local CancelBtn = CreateFrame("Button", "StackSplitCancelButton", f, "UIPanelButtonTemplate")
		CancelBtn:SetSize(64, 24); CancelBtn:SetText(CANCEL)
		CancelBtn:SetPoint("LEFT", f, "BOTTOM", 5, 32)

		f.split, f.maxStack, f.typing = 1, 0, 0
		f.down = {}
		local function Update()
			if f.maxStack < 2 then
				if f.owner then f.owner.hasStackSplit = 0 end
				f:Hide(); return
			end
			if f.split > f.maxStack then f.split = f.maxStack end
			StackSplitText:SetText(f.split)
			if f.split == f.maxStack then RightBtn:Disable() else RightBtn:Enable() end
			if f.split == 1 then LeftBtn:Disable() else LeftBtn:Enable() end
		end
		function _G.OpenStackSplitFrame(maxStack, parent, anchor, anchorTo)
			if f.owner then f.owner.hasStackSplit = 0 end
			f.maxStack = tonumber(maxStack) or 0
			if f.maxStack < 2 then f:Hide(); return end
			f.owner = parent; parent.hasStackSplit = 1
			f.split = 1; f.typing = 0
			StackSplitText:SetText(1)
			LeftBtn:Disable(); RightBtn:Enable()
			f:ClearAllPoints()
			f:SetPoint(anchor or "TOPLEFT", parent, anchorTo or "BOTTOMLEFT", 0, 0)
			f:Show()
		end
		function _G.StackSplitFrame_OnChar(self, text)
			if text < "0" or text > "9" then return end
			if self.typing == 0 then self.typing = 1; self.split = 0 end
			local v = (self.split * 10) + tonumber(text)
			if v == self.split then
				if self.split == 0 then self.split = 1 end
				return
			end
			if v <= self.maxStack then
				self.split = v; Update()
			elseif v == 0 then
				self.split = 1; Update()
			end
		end
		local function Left() if f.split > 1 then f.split = f.split - 1; Update() end end
		local function Right() if f.split < f.maxStack then f.split = f.split + 1; Update() end end
		local function Okay()
			f:Hide()
			-- Dot-call: SplitStack(owner, amount). Colon would pass owner twice.
			if f.owner and f.owner.SplitStack then
				f.owner.SplitStack(f.owner, f.split)
			end
		end
		local function Cancel() f:Hide() end
		function _G.StackSplitFrameLeft_Click() Left() end
		function _G.StackSplitFrameRight_Click() Right() end
		function _G.StackSplitFrameOkay_Click() Okay() end
		function _G.StackSplitFrameCancel_Click() Cancel() end
		function _G.StackSplitFrame_OnKeyDown(self, key)
			local numKey = gsub(key, "NUMPAD", "")
			if key == "BACKSPACE" or key == "DELETE" then
				if self.typing == 0 or self.split == 1 then return end
				self.split = floor(self.split / 10)
				if self.split < 1 then self.split = 1; self.typing = 0 end
				Update()
			elseif key == "ENTER" then
				Okay()
			elseif GetBindingFromClick(key) == "TOGGLEGAMEMENU" then
				Cancel()
			elseif key == "LEFT" or key == "DOWN" then
				Left()
			elseif key == "RIGHT" or key == "UP" then
				Right()
			else
				if not tonumber(numKey) then
					local act = GetBindingAction(key); if act then RunBinding(act) end
				end
			end
			self.down[key] = true
		end
		function _G.StackSplitFrame_OnKeyUp(self, key)
			local numKey = gsub(key, "NUMPAD", "")
			if not tonumber(numKey) then
				local act = GetBindingAction(key); if act then RunBinding(act, "up") end
			end
			self.down[key] = nil
		end
		function _G.StackSplitFrame_OnHide(self)
			for k in next, (self.down or {}) do
				local act = GetBindingAction(k); if act then RunBinding(act, "up") end
				self.down[k] = nil
			end
			if f.owner then f.owner.hasStackSplit = 0 end
		end
		f:SetScript("OnChar", _G.StackSplitFrame_OnChar)
		f:SetScript("OnKeyDown", _G.StackSplitFrame_OnKeyDown)
		f:SetScript("OnKeyUp", _G.StackSplitFrame_OnKeyUp)
		f:SetScript("OnHide", _G.StackSplitFrame_OnHide)
		LeftBtn:SetScript("OnClick", _G.StackSplitFrameLeft_Click)
		RightBtn:SetScript("OnClick", _G.StackSplitFrameRight_Click)
		OkayBtn:SetScript("OnClick", _G.StackSplitFrameOkay_Click)
		CancelBtn:SetScript("OnClick", _G.StackSplitFrameCancel_Click)
	end

	if not _G.OpenStackSplitFrame then
		function _G.OpenStackSplitFrame(maxStack, parent, anchor, anchorTo)
			local f = _G.StackSplitFrame
			if not f then return end
			if f.owner then f.owner.hasStackSplit = 0 end
			f.maxStack = tonumber(maxStack) or 0
			if f.maxStack < 2 then f:Hide(); return end
			f.owner = parent; parent.hasStackSplit = 1
			f.split = 1; f.typing = 0
			if _G.StackSplitText then StackSplitText:SetText(1) end
			if _G.StackSplitLeftButton then StackSplitLeftButton:Disable() end
			if _G.StackSplitRightButton then StackSplitRightButton:Enable() end
			f:ClearAllPoints()
			f:SetPoint(anchor or "TOPLEFT", parent, anchorTo or "BOTTOMLEFT", 0, 0)
			f:Show()
		end
	end
end

function module:ApplyBadgeStackBuyer()
	local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
	if not db or not db.enabled then return end

	if not (db.enableBadgeStackBuyer == 1 or db.enableBadgeStackBuyer == true) then
		self:DisableBadgeStackBuyer()
		return
	end

	EnsureStackSplitFrame()

	local function GetMerchantIndex(btn, slotOnPage)
		local id = btn:GetID()
		if id and id > 0 then return id end
		local page = MerchantFrame and MerchantFrame.page or 1
		return (page - 1) * MERCHANT_ITEMS_PER_PAGE + (slotOnPage or 0)
	end

	local function OpenSplitOnBadge(btn, slotOnPage)
		if MerchantFrame and MerchantFrame.selectedTab and MerchantFrame.selectedTab ~= 1 then
			return false
		end
		local index = GetMerchantIndex(btn, slotOnPage)
		if not index or index <= 0 then return true end

		local name, _, _, _, numAvailable, _, extendedCost = GetMerchantItemInfo(index)
		if not name then return false end

		local itemID = GetBadgeItemIDFromLink(GetMerchantItemLink(index))
		if not itemID or not BADGE_ITEM_IDS[itemID] then
			return false
		end

		local maxStack = (GetMerchantItemMaxStack and GetMerchantItemMaxStack(index)) or 0
		if not maxStack or maxStack <= 0 then maxStack = 999 end
		if numAvailable and numAvailable > 0 and numAvailable < maxStack then
			maxStack = numAvailable
		end
		if maxStack < 2 then maxStack = 20 end

		btn._badgeBuyIndex = index
		btn._badgeExtendedCost = extendedCost and true or false
		btn.SplitStack = function(owner, amount)
			amount = tonumber(amount) or 0
			if amount <= 0 then return end
			local buyIndex = owner._badgeBuyIndex
			if not buyIndex then return end
			if owner._badgeExtendedCost then
				-- One BuyMerchantItem per item, throttled across frames.
				StartBadgeBuyQueue(buyIndex, amount)
			else
				BuyMerchantItem(buyIndex, amount)
			end
		end
		OpenStackSplitFrame(maxStack, btn, "TOPLEFT", "BOTTOMLEFT")
		return true
	end

	local function HookMerchantButtons()
		if not MerchantFrame or not MerchantFrame:IsShown() then return end
		local db2 = DB() or {}
		local enabledFeature = (db2.enabled == true) and (db2.enableBadgeStackBuyer == 1 or db2.enableBadgeStackBuyer == true)
		if not enabledFeature then
			for slot = 1, MERCHANT_ITEMS_PER_PAGE do
				local btn = _G["MerchantItem" .. slot .. "ItemButton"]
				if btn and btn._badgeShiftHooked then
					btn._badgeShiftHooked = nil
					if btn._badgeOrigOnClick then
						btn:SetScript("OnClick", btn._badgeOrigOnClick)
					end
				end
			end
			return
		end
		for slot = 1, MERCHANT_ITEMS_PER_PAGE do
			local btn = _G["MerchantItem" .. slot .. "ItemButton"]
			if btn and not btn._badgeShiftHooked then
				btn._badgeShiftHooked = true
				local orig = btn:GetScript("OnClick")
				btn._badgeOrigOnClick = orig
				btn:SetScript("OnClick", function(self, mouseButton)
					local db3 = DB() or {}
					if db3.enabled == true and (db3.enableBadgeStackBuyer == 1 or db3.enableBadgeStackBuyer == true) then
						if mouseButton == "LeftButton" and IsShiftKeyDown() then
							if OpenSplitOnBadge(self, slot) then return end
						end
					end
					if orig then return orig(self, mouseButton) end
				end)
				btn:HookScript("OnHide", function(self)
					if StackSplitFrame and StackSplitFrame:IsShown() and StackSplitFrame.owner == self then
						StackSplitFrame:Hide()
					end
				end)
			end
		end
	end

	if not S.badgeBuyerFrame then
		S.badgeBuyerFrame = CreateFrame("Frame")
	end
	S.badgeBuyerFrame:UnregisterAllEvents()
	S.badgeBuyerFrame:RegisterEvent("MERCHANT_SHOW")
	S.badgeBuyerFrame:RegisterEvent("MERCHANT_CLOSED")
	S.badgeBuyerFrame:SetScript("OnEvent", function(_, event)
		if event == "MERCHANT_CLOSED" then
			StopBadgeBuyQueue()
			return
		end
		HookMerchantButtons()
	end)

	if not S.badgeBuyerHooksInstalled then
		S.badgeBuyerHooksInstalled = true
		local function DispatchMerchantHook()
			local fn = S._badgeHookMerchantButtons
			if fn then fn() end
		end
		hooksecurefunc("MerchantFrame_UpdateMerchantInfo", DispatchMerchantHook)
		hooksecurefunc("MerchantFrame_UpdateBuybackInfo", DispatchMerchantHook)
	end
	S._badgeHookMerchantButtons = HookMerchantButtons

	S.badgeBuyerInitialized = true
	if MerchantFrame and MerchantFrame:IsShown() then
		HookMerchantButtons()
	end
end

function module:DisableBadgeStackBuyer()
	StopBadgeBuyQueue()
	if not S.badgeBuyerInitialized then return end
	if S.badgeBuyerFrame then
		S.badgeBuyerFrame:UnregisterAllEvents()
		S.badgeBuyerFrame:SetScript("OnEvent", nil)
	end
	if MerchantFrame then
		for slot = 1, MERCHANT_ITEMS_PER_PAGE do
			local btn = _G["MerchantItem" .. slot .. "ItemButton"]
			if btn and btn._badgeShiftHooked then
				btn._badgeShiftHooked = nil
				if btn._badgeOrigOnClick then
					btn:SetScript("OnClick", btn._badgeOrigOnClick)
				end
			end
		end
	end
	S.badgeBuyerInitialized = false
end

-- Update Compact Party frames (CompactPartyFrameMember / CompactRaidFrame; absent on 3.3.5)
local COMPACT_PARTY_SLOTS = 8
local COMPACT_RAID_FRAMES = 5

local function IsSecureUnitFrame(frame)
	return type(frame) == "table" and type(frame.SetAttribute) == "function"
end

local function UpdateCompactParty()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not db.enabled then return end

    if InCombatLockdown and InCombatLockdown() then return end

    -- Skip on clients without compact raid/party frames (e.g. 3.3.5).
    if not _G.CompactPartyFrameMember1 and not _G.CompactRaidFrame1 then
        return
    end

    local partyLimit = tonumber(COMPACT_PARTY_SLOTS) or 4
    for partyIdx = 1, partyLimit do
        local pf = _G["CompactPartyFrameMember" .. partyIdx]
        if IsSecureUnitFrame(pf) then
            SetFocusHotkey(pf)
            local pet = _G["CompactPartyFrameMember" .. partyIdx .. "PetFrame"]
            if IsSecureUnitFrame(pet) then
                SetFocusHotkey(pet)
            end
        end
    end

    local raidLimit = tonumber(COMPACT_RAID_FRAMES) or 5
    for raidIdx = 1, raidLimit do
        local rf = _G["CompactRaidFrame" .. raidIdx]
        if IsSecureUnitFrame(rf) then
            SetFocusHotkey(rf)
        end
    end
end

-- Arena Right-Click Focus helpers (must be above EnableFocuser — Lua local scope)
S.arenaRightClickFocusInitialized, S.arenaRightClickFocusEventFrame = false, nil

local function SetArenaRightClickFocus(frame)
    if not frame or not frame.SetAttribute then return end
    if InCombatLockdown() then return end

    frame:SetAttribute("type2", "focus")
    frame:SetAttribute("unit", frame.unit or frame:GetAttribute("unit"))

    if frame.RegisterForClicks then
        frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end
end

local function ClearArenaRightClickFocus(frame)
    if not frame or not frame.SetAttribute then return end
    if InCombatLockdown() then return end

    frame:SetAttribute("type2", nil)
end

-- Apply focuser settings
function module:ApplyFocuser()
    local db = DB()
    if not db then return end
    
    if db.enableFocuser == 1 then
        self:EnableFocuser()
    else
        self:DisableFocuser()
    end
end

-- Enable focuser
function module:EnableFocuser()
    local db = DB()
    if not db then return end
    
    -- Hook CreateFrame for new unit frames
    if not S.createFrameHook then
        S.createFrameHook = hooksecurefunc("CreateFrame", function(ftype, name, parent, template)
            -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
            local checkDb = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
            if not checkDb or not checkDb.enabled then return end
            
            local tmpl = _G.type(template) == "string" and template or ""
            if tmpl:find("SecureUnitButtonTemplate", 1, true) or tmpl:find("CompactUnitFrameTemplate", 1, true) then
                if name and _G[name] then
                    SetFocusHotkey(_G[name])
                end
            end
        end)
    end
    
    -- Create override button for /focus mouseover
    if not S.focuserButton then
        S.focuserButton = CreateFrame("CheckButton", "SarychUIFocuserButton", UIParent, "SecureActionButtonTemplate")
        S.focuserButton:SetAttribute("type1","macro")
        S.focuserButton:SetAttribute("macrotext","/focus mouseover")
    end
    InstallFocuserPlayerMouseoverGuard(S.focuserButton)
    
    if S.focuserButton then
        -- Сначала очищаем все возможные биндинги
        ClearOverrideBindings(S.focuserButton)
        
        -- Затем устанавливаем только выбранный модификатор
        local modifier = GetFocuserModifier()
        SetOverrideBindingClick(S.focuserButton, true, modifier.."-BUTTON"..mouseButton, "SarychUIFocuserButton")
    end
    
    -- Set focus hotkey on existing unit frames
    local duf = {
        PlayerFrame, PetFrame,
        PartyMemberFrame1, PartyMemberFrame2, PartyMemberFrame3, PartyMemberFrame4,
        PartyMemberFrame1PetFrame, PartyMemberFrame2PetFrame, PartyMemberFrame3PetFrame, PartyMemberFrame4PetFrame,
        TargetFrame, TargetofTargetFrame,
        ArenaEnemyFrame1, ArenaEnemyFrame2, ArenaEnemyFrame3, ArenaEnemyFrame4, ArenaEnemyFrame5,
        ArenaEnemyFrame1PetFrame, ArenaEnemyFrame2PetFrame, ArenaEnemyFrame3PetFrame, ArenaEnemyFrame4PetFrame, ArenaEnemyFrame5PetFrame,
    }
    for _,frame in pairs(duf) do
        SetFocusHotkey(frame)
    end
    
    -- Также применяем правый клик на арена фреймах, если он включен
    if db.enableArenaRightClickFocus == 1 then
        for i = 1, 5 do
            local frame = _G["ArenaEnemyFrame"..i]
            if frame then SetArenaRightClickFocus(frame) end
            local pet = _G["ArenaEnemyFrame"..i.."PetFrame"]
            if pet then SetArenaRightClickFocus(pet) end
        end
    end
    
    -- Update compact frames
    UpdateCompactParty()
end

-- Disable focuser
function module:DisableFocuser()
    -- Clear override binding
    if S.focuserButton then
        ClearOverrideBindings(S.focuserButton)
    end
    
    -- Remove focus hotkey from existing unit frames
    local duf = {
        PlayerFrame, PetFrame,
        PartyMemberFrame1, PartyMemberFrame2, PartyMemberFrame3, PartyMemberFrame4,
        PartyMemberFrame1PetFrame, PartyMemberFrame2PetFrame, PartyMemberFrame3PetFrame, PartyMemberFrame4PetFrame,
        TargetFrame, TargetofTargetFrame,
        ArenaEnemyFrame1, ArenaEnemyFrame2, ArenaEnemyFrame3, ArenaEnemyFrame4, ArenaEnemyFrame5,
        ArenaEnemyFrame1PetFrame, ArenaEnemyFrame2PetFrame, ArenaEnemyFrame3PetFrame, ArenaEnemyFrame4PetFrame, ArenaEnemyFrame5PetFrame,
    }
    for _,frame in pairs(duf) do
        if frame and frame.SetAttribute then
            -- Clear all possible modifiers
            frame:SetAttribute("SHIFT-type"..mouseButton, nil)
            frame:SetAttribute("ALT-type"..mouseButton, nil)
            frame:SetAttribute("CTRL-type"..mouseButton, nil)
        end
    end
    
    -- Clear compact frames (scan and remove)
    local partyLimit = tonumber(COMPACT_PARTY_SLOTS) or 4
    for partyIdx = 1, partyLimit do
        local pf = _G["CompactPartyFrameMember" .. partyIdx]
        if IsSecureUnitFrame(pf) then
            -- Clear all possible modifiers
            pf:SetAttribute("SHIFT-type"..mouseButton, nil)
            pf:SetAttribute("ALT-type"..mouseButton, nil)
            pf:SetAttribute("CTRL-type"..mouseButton, nil)
        end
        local pet = _G["CompactPartyFrameMember" .. partyIdx .. "PetFrame"]
        if IsSecureUnitFrame(pet) then
            -- Clear all possible modifiers
            pet:SetAttribute("SHIFT-type"..mouseButton, nil)
            pet:SetAttribute("ALT-type"..mouseButton, nil)
            pet:SetAttribute("CTRL-type"..mouseButton, nil)
        end
    end
    
    -- Clear CompactRaidFrame1-5
    local raidLimit = tonumber(COMPACT_RAID_FRAMES) or 5
    for raidIdx = 1, raidLimit do
        local rf = _G["CompactRaidFrame" .. raidIdx]
        if IsSecureUnitFrame(rf) then
            -- Clear all possible modifiers
            rf:SetAttribute("SHIFT-type"..mouseButton, nil)
            rf:SetAttribute("ALT-type"..mouseButton, nil)
            rf:SetAttribute("CTRL-type"..mouseButton, nil)
        end
    end
    
end

-- ============================================
-- Arena Right-Click Focus functionality
-- Sets up right-click (without modifier) to focus arena enemy frames
-- ============================================

-- Apply right-click focus to all arena enemy frames
function module:ApplyArenaRightClickFocus()
    local db = DB()
    if not db or not db.enabled then return end
    
    if db.enableArenaRightClickFocus == 1 then
        self:EnableArenaRightClickFocus()
    else
        self:DisableArenaRightClickFocus()
    end
end

-- Enable right-click focus for arena frames
function module:EnableArenaRightClickFocus()
    local db = DB()
    if not db or not db.enabled then return end
    if InCombatLockdown() then
        -- Schedule for after combat
        C_Timer.After(0.5, function() self:EnableArenaRightClickFocus() end)
        return
    end
    
    -- Ensure Blizzard_ArenaUI is loaded
    if not IsAddOnLoaded("Blizzard_ArenaUI") then
        pcall(LoadAddOn, "Blizzard_ArenaUI")
    end
    
    -- Set up right-click focus on arena enemy frames
    local arenaFrames = {
        "ArenaEnemyFrame1", "ArenaEnemyFrame2", "ArenaEnemyFrame3", "ArenaEnemyFrame4", "ArenaEnemyFrame5",
        "ArenaEnemyFrame1PetFrame", "ArenaEnemyFrame2PetFrame", "ArenaEnemyFrame3PetFrame", "ArenaEnemyFrame4PetFrame", "ArenaEnemyFrame5PetFrame",
    }
    
    for _, frameName in ipairs(arenaFrames) do
        local frame = _G[frameName]
        if frame then
            SetArenaRightClickFocus(frame)
            -- Также применяем focuser (модификатор+ЛКМ), если он включен
            if db.enableFocuser == 1 then
                SetFocusHotkey(frame)
            end
        end
    end
    
    -- Create event frame to hook into arena frame creation/updates
    if not S.arenaRightClickFocusEventFrame then
        S.arenaRightClickFocusEventFrame = CreateFrame("Frame")
        S.arenaRightClickFocusEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        S.arenaRightClickFocusEventFrame:RegisterEvent("ARENA_OPPONENT_UPDATE")
        S.arenaRightClickFocusEventFrame:SetScript("OnEvent", function(self, event)
            if InCombatLockdown() then return end
            
            local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
            if not db or not db.enabled then return end
            
            -- Re-apply right-click focus if enabled
            if db.enableArenaRightClickFocus == 1 then
                for i = 1, 5 do
                    local frame = _G["ArenaEnemyFrame"..i]
                    if frame then SetArenaRightClickFocus(frame) end
                    local pet = _G["ArenaEnemyFrame"..i.."PetFrame"]
                    if pet then SetArenaRightClickFocus(pet) end
                end
            end
            
            -- Re-apply focuser if enabled (модификатор+ЛКМ)
            if db.enableFocuser == 1 then
                for i = 1, 5 do
                    local frame = _G["ArenaEnemyFrame"..i]
                    if frame then SetFocusHotkey(frame) end
                    local pet = _G["ArenaEnemyFrame"..i.."PetFrame"]
                    if pet then SetFocusHotkey(pet) end
                end
            end
        end)
    end
    
    S.arenaRightClickFocusInitialized = true
end

-- Disable right-click focus for arena frames
function module:DisableArenaRightClickFocus()
    if InCombatLockdown() then
        C_Timer.After(0.5, function() self:DisableArenaRightClickFocus() end)
        return
    end
    
    -- Remove right-click focus from arena enemy frames
    for i = 1, 5 do
        local frame = _G["ArenaEnemyFrame"..i]
        if frame then ClearArenaRightClickFocus(frame) end
        local pet = _G["ArenaEnemyFrame"..i.."PetFrame"]
        if pet then ClearArenaRightClickFocus(pet) end
    end
    
    -- Unregister events
    if S.arenaRightClickFocusEventFrame then
        S.arenaRightClickFocusEventFrame:UnregisterAllEvents()
        S.arenaRightClickFocusEventFrame:SetScript("OnEvent", nil)
        S.arenaRightClickFocusEventFrame = nil
    end
    
    S.arenaRightClickFocusInitialized = false
end

-- Apply EscToOK settings
function module:ApplyEscToOk()
    local db = DB()
    if not db then return end
    
    if db.enableEscToOk == 1 then
        self:EnableEscToOk()
    else
        self:DisableEscToOk()
    end
end

-- Enable EscToOK
function module:EnableEscToOk()
    local db = DB()
    if not db then return end
    
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    if not db.enabled then return end
    
    -- Wait for InterfaceOptionsFrame to be created
    if not InterfaceOptionsFrame then
        -- Try to initialize on next frame update
        local initFrame = CreateFrame("Frame")
        initFrame:SetScript("OnUpdate", function(self)
            if InterfaceOptionsFrame then
                self:SetScript("OnUpdate", nil)
                module:EnableEscToOk()
            end
        end)
        return
    end
    
    -- Save original OnKeyDown script before hooking (only once)
    if S.origOnKeyDown == nil then
        S.origOnKeyDown = InterfaceOptionsFrame:GetScript("OnKeyDown")
    end
    
    -- Enable keyboard for InterfaceOptionsFrame
    InterfaceOptionsFrame:EnableKeyboard(true)
    
    -- Hook OnKeyDown
    InterfaceOptionsFrame:SetScript("OnKeyDown", function(self, key)
        -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
        local checkDb = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
        if not checkDb or not checkDb.enabled or checkDb.enableEscToOk ~= 1 then
            if S.origOnKeyDown then
                return S.origOnKeyDown(self, key)
            else
                return
            end
        end
        
        if key == "ESCAPE" then
            if InterfaceOptionsFrameOkay then
                InterfaceOptionsFrameOkay:Click()
            else
                self:Hide()
            end
        else
            if S.origOnKeyDown then
                S.origOnKeyDown(self, key)
            end
        end
    end)
    
    -- Hook Cancel button
    if InterfaceOptionsFrameCancel then
        -- Save original Cancel OnClick script before hooking (only once)
        if S.origCancelOnClick == nil then
            S.origCancelOnClick = InterfaceOptionsFrameCancel:GetScript("OnClick")
        end
        
        InterfaceOptionsFrameCancel:SetScript("OnClick", function(self, button, ...)
            -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
            local checkDb = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
            if not checkDb or not checkDb.enabled or checkDb.enableEscToOk ~= 1 then
                if S.origCancelOnClick then
                    return S.origCancelOnClick(self, button, ...)
                else
                    return
                end
            end
            
            if InterfaceOptionsFrameOkay then
                InterfaceOptionsFrameOkay:Click()
            else
                InterfaceOptionsFrame:Hide()
            end
        end)
    end
    
    S.escToOkHooked = true
end

-- Disable EscToOK
function module:DisableEscToOk()
    if not InterfaceOptionsFrame then return end
    
    -- Always restore original OnKeyDown script (even if it was nil)
    if S.escToOkHooked then
        InterfaceOptionsFrame:SetScript("OnKeyDown", S.origOnKeyDown)
    end
    
    -- Always restore original Cancel OnClick script (even if it was nil)
    if InterfaceOptionsFrameCancel and S.escToOkHooked then
        InterfaceOptionsFrameCancel:SetScript("OnClick", S.origCancelOnClick)
    end
    
    -- Reset flag
    S.escToOkHooked = false
    -- Don't reset S.origOnKeyDown and S.origCancelOnClick - they may be needed if re-enabled
end

-- Reanchor GroupLoot frames
local function ReanchorGroupLoot()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not db.enabled or db.enableLootReanchor ~= 1 then return end
    
    local startX = db.lootStartX or 0
    local startY = db.lootStartY or 150
    local spacing = db.lootSpacing or 8
    local lastFrame
    local maxFrames = NUM_GROUP_LOOT_FRAMES or 4

    for i = 1, maxFrames do
        local frame = _G["GroupLootFrame"..i]
        if frame and frame:IsShown() then
            -- Save default position before first modification (only once)
            if not S.lootDefaultPositions[i] then
                local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
                if point then
                    S.lootDefaultPositions[i] = {point, relativeTo, relativePoint, xOfs, yOfs}
                end
            end
            
            frame:ClearAllPoints()
            if not lastFrame then
                frame:SetPoint("BOTTOM", UIParent, "BOTTOM", startX, startY)
            else
                frame:SetPoint("BOTTOM", lastFrame, "TOP", 0, spacing)
            end
            lastFrame = frame
        end
    end
end

-- Apply loot reanchor settings
function module:ApplyLootReanchor()
    local db = DB()
    if not db then return end
    
    if db.enableLootReanchor == 1 then
        self:EnableLootReanchor()
    else
        self:DisableLootReanchor()
    end
end

-- Enable loot reanchor
function module:EnableLootReanchor()
    local db = DB()
    if not db then return end
    
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    if not db.enabled then return end
    
    if not S.lootFramesHooked then
        local maxFrames = NUM_GROUP_LOOT_FRAMES or 4
        for i = 1, maxFrames do
            local f = _G["GroupLootFrame"..i]
            if f then
                -- Store original hooks if they exist (only once)
                if not S.lootFrameHooks[i] then
                    S.lootFrameHooks[i] = {
                        origOnShow = f:GetScript("OnShow"),
                        origOnHide = f:GetScript("OnHide")
                    }
                end
                
                -- Create wrapper functions that call original + our function
                local wrapperOnShow = function(self, ...)
                    if S.lootFrameHooks[i] and S.lootFrameHooks[i].origOnShow then
                        S.lootFrameHooks[i].origOnShow(self, ...)
                    end
                    ReanchorGroupLoot()
                end
                
                local wrapperOnHide = function(self, ...)
                    if S.lootFrameHooks[i] and S.lootFrameHooks[i].origOnHide then
                        S.lootFrameHooks[i].origOnHide(self, ...)
                    end
                    ReanchorGroupLoot()
                end
                
                -- Set our wrappers
                f:SetScript("OnShow", wrapperOnShow)
                f:SetScript("OnHide", wrapperOnHide)
            end
        end
        
        S.lootFramesHooked = true
        
        -- Apply immediately if frames are shown
        ReanchorGroupLoot()
    end
end

-- Disable loot reanchor
function module:DisableLootReanchor()
    if not S.lootFramesHooked then return end
    
    local maxFrames = NUM_GROUP_LOOT_FRAMES or 4
    for i = 1, maxFrames do
        local f = _G["GroupLootFrame"..i]
        if f and S.lootFrameHooks[i] then
            -- Restore original hooks - Blizzard will restore default positioning
            -- on next frame show automatically
            f:SetScript("OnShow", S.lootFrameHooks[i].origOnShow)
            f:SetScript("OnHide", S.lootFrameHooks[i].origOnHide)
            
            -- If frame is currently shown, hide and show it again to trigger
            -- original OnShow which will restore default Blizzard positioning
            if f:IsShown() then
                f:Hide()
                f:Show()
            end
        end
    end
    
    -- Don't clear S.lootDefaultPositions - keep them for potential re-enabling
    -- Clear hooks storage
    S.lootFrameHooks = {}
    S.lootFramesHooked = false
end

-- ============================================================================
-- Dispel Highlight Functionality
-- ============================================================================

-- Guard Blizzard TargetFrame aura layout against bad numeric args / re-entrant updates.
local targetFrameAuraUpdateLock = {}

local function InstallTargetFrameAuraGuard()
    if S.targetFrameAuraGuardInstalled then
        return
    end

    local function guardAuraPositions(funcName)
        local orig = _G[funcName]
        if type(orig) ~= "function" then
            return
        end
        _G[funcName] = function(self, auraName, numAuras, numOppositeAuras, largeAuraList, updateFunc, maxRowWidth, offsetX, ...)
            if self and type(self.auraRows) ~= "number" then
                self.auraRows = 0
            end
            numAuras = tonumber(numAuras) or 0
            numOppositeAuras = tonumber(numOppositeAuras) or 0
            if type(maxRowWidth) ~= "number" then
                maxRowWidth = tonumber(self and self.TOT_AURA_ROW_WIDTH) or tonumber(AURA_ROW_WIDTH) or 101
            end
            return orig(self, auraName, numAuras, numOppositeAuras, largeAuraList, updateFunc, maxRowWidth, offsetX, ...)
        end
    end

    local function guardUpdateAuras(funcName)
        local orig = _G[funcName]
        if type(orig) ~= "function" then
            return
        end
        _G[funcName] = function(self, ...)
            if not self then
                return orig(...)
            end
            if targetFrameAuraUpdateLock[self] then
                return
            end
            if type(self.auraRows) ~= "number" then
                self.auraRows = 0
            end
            targetFrameAuraUpdateLock[self] = true
            local ok, err = pcall(orig, self, ...)
            targetFrameAuraUpdateLock[self] = nil
            if not ok then
                error(err)
            end
        end
    end

    guardAuraPositions("TargetFrame_UpdateAuraPositions")
    guardUpdateAuras("TargetFrame_UpdateAuras")
    guardUpdateAuras("FocusFrame_UpdateAuras")

    S.targetFrameAuraGuardInstalled = true
end

local function ScheduleDispelMark(frame, unit)
    if not frame or not unit then
        return
    end

    local function runMark()
        if not UnitExists(unit) then
            return
        end
        MarkDispellablesOnFrame(frame, unit)
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, runMark)
    elseif AceTimer then
        AceTimer:ScheduleTimer(runMark, 0)
    else
        runMark()
    end
end

-- Check if dispel highlight is enabled
local function IsDispelHighlightEnabled()
    local db = AurasDB()
    if not db or not db.enabled then return false end
    return db.enableDispelHighlight == 1
end

-- Mark dispellable buffs on frame.
-- Runs on a repeating tick, so the per-index work is kept to a single UnitBuff call:
-- the dispel type comes from the same query that provides the name, and the frame
-- name and border lookups are resolved once instead of rebuilt per index.
local function MarkDispellablesOnFrame(frame, unit)
    if not IsDispelHighlightEnabled() then return end
    if not unit then return end
    if not frame then return end

    local buffFrames = frame.buffFrames
    local frameName = (not buffFrames) and frame.GetName and frame:GetName() or nil
    local hostile = UnitCanAttack("player", unit)

    for idx = 1, 32 do
        local name, _, _, _, dtype = UnitBuff(unit, idx)
        local button = buffFrames and buffFrames[idx] or (frameName and _G[frameName .. "Buff" .. idx])
        if not name or not button then break end

        local border = button.__sarStealable
        if border == nil then
            border = _G[button:GetName() .. "Stealable"] or button.Stealable or false
            button.__sarStealable = border
        end

        if border then
            border:Hide()  -- всегда гасим сначала
            if hostile and dtype and CAN_REMOVE[dtype] then
                border:Show()
            end
        end
    end
end

-- Clear dispellable marks (used when disabling)
local function ClearDispellableMarks(frame)
    if not frame then return end
    for idx = 1, 32 do
        local button = frame and frame.buffFrames and frame.buffFrames[idx]
                    or (frame and frame.GetName and _G[frame:GetName().."Buff"..idx])
        if not button then break end
        local border = _G[button:GetName().."Stealable"] or button.Stealable
        if border then border:Hide() end
    end
end

-- Apply dispel highlight settings
function module:ApplyDispelHighlight()
    local db = AurasDB()
    if not db or not db.enabled then
        ClearDispellableMarks(TargetFrame)
        ClearDispellableMarks(FocusFrame)
        if S.dispelEventFrame or S.dispelUpdateFrame then
            self:DisableDispelHighlight()
        end
        return
    end

    if not IsDispelHighlightEnabled() then
        ClearDispellableMarks(TargetFrame)
        ClearDispellableMarks(FocusFrame)
        if S.dispelEventFrame or S.dispelUpdateFrame then
            self:DisableDispelHighlight()
        end
    else
        if not S.dispelEventFrame and not S.dispelUpdateFrame then
            self:EnableDispelHighlight()
        else
            ScheduleDispelMark(TargetFrame, "target")
            ScheduleDispelMark(FocusFrame, "focus")
        end
    end
end

-- Enable dispel highlight
function module:EnableDispelHighlight()
    local db = AurasDB()
    if not db or not db.enabled then return end

    if S.dispelEventFrame then return end -- Already enabled

    -- Create event frame
    S.dispelEventFrame = CreateFrame("Frame")
    S.dispelEventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    S.dispelEventFrame:RegisterEvent("UNIT_AURA")
    S.dispelEventFrame:RegisterEvent("UNIT_FACTION")
    S.dispelEventFrame:SetScript("OnEvent", function(self, event, unit)
        if not IsDispelHighlightEnabled() then return end
        if (event == "UNIT_AURA" or event == "UNIT_FACTION") and unit ~= "target" and unit ~= "focus" then return end

        ScheduleDispelMark(TargetFrame, "target")
        ScheduleDispelMark(FocusFrame, "focus")
    end)

    -- Используем AceTimer вместо OnUpdate для снижения нагрузки (оптимизация производительности)
    if AceTimer then
        S.updateTimers.dispel = AceTimer:ScheduleRepeatingTimer(function()
            if not IsDispelHighlightEnabled() then return end
            if TargetFrame then MarkDispellablesOnFrame(TargetFrame, "target") end
            if FocusFrame then MarkDispellablesOnFrame(FocusFrame, "focus") end
        end, DISPEL_TICK)
    else
        -- Fallback на OnUpdate, если AceTimer недоступен
        S.dispelUpdateFrame = CreateFrame("Frame")
        local dispelUpdateAcc = 0
        S.dispelUpdateFrame:SetScript("OnUpdate", function(self, elapsed)
            dispelUpdateAcc = dispelUpdateAcc + elapsed
            if dispelUpdateAcc < DISPEL_TICK then return end
            dispelUpdateAcc = 0

            if not IsDispelHighlightEnabled() then return end
            if TargetFrame then MarkDispellablesOnFrame(TargetFrame, "target") end
            if FocusFrame then MarkDispellablesOnFrame(FocusFrame, "focus") end
        end)
    end

    -- Update marks on the next frame (avoid re-entering TargetFrame_Update during target clicks)
    ScheduleDispelMark(TargetFrame, "target")
    ScheduleDispelMark(FocusFrame, "focus")
end

-- Disable dispel highlight
function module:DisableDispelHighlight()
    -- Clear marks
    ClearDispellableMarks(TargetFrame)
    ClearDispellableMarks(FocusFrame)

    -- Unregister events and clear scripts
    if S.dispelEventFrame then
        S.dispelEventFrame:UnregisterAllEvents()
        S.dispelEventFrame:SetScript("OnEvent", nil)
        S.dispelEventFrame = nil
    end

    -- Отменяем таймер, если он активен (оптимизация производительности)
    if S.updateTimers.dispel and AceTimer then
        AceTimer:CancelTimer(S.updateTimers.dispel)
        S.updateTimers.dispel = nil
    end
    if S.dispelUpdateFrame then
        S.dispelUpdateFrame:SetScript("OnUpdate", nil)
        S.dispelUpdateFrame = nil
    end
end

-- ============================================================================
-- Pet Name Shortening Functionality
-- ============================================================================

-- Shorten pet name if it's too long
local function ShortenPetName(frame)
    local db = FrameDB()
    if not db or not db.enabled then return end

    if db.enablePetNameShortening ~= 1 then return end
    if not frame or not frame.name then return end

    local name = UnitName("pet")
    if name and strlenutf8(name) > MAX_NAME_LENGTH then
        name = strsub(name, 1, MAX_NAME_LENGTH) .. "…"
    end
    frame.name:SetText(name or "")
end

-- Apply pet name shortening settings
function module:ApplyPetNameShortening()
    local db = FrameDB()
    if not db or not db.enabled then
        if S.petNameShorteningHooked then
            self:DisablePetNameShortening()
        end
        return
    end

    if db.enablePetNameShortening == 1 then
        if not S.petNameShorteningHooked then
            self:EnablePetNameShortening()
        else
            if PetFrame and PetFrame.name then
                ShortenPetName(PetFrame)
            end
        end
    else
        if S.petNameShorteningHooked then
            self:DisablePetNameShortening()
        end
    end
end

-- Enable pet name shortening
function module:EnablePetNameShortening()
    local db = FrameDB()
    if not db or not db.enabled then return end

    if S.petNameShorteningHooked then return end -- Already enabled

    -- Hook PetFrame_Update
    hooksecurefunc("PetFrame_Update", function()
        ShortenPetName(PetFrame)
    end)

    S.petNameShorteningHooked = true

    -- Apply immediately if PetFrame exists
    if PetFrame and PetFrame.name then
        ShortenPetName(PetFrame)
    end
end

-- Disable pet name shortening
function module:DisablePetNameShortening()
    if not S.petNameShorteningHooked then return end

    -- We can't unhook hooksecurefunc, but we can restore original behavior
    -- by ensuring PetFrame_Update works normally (it will just skip our hook)
    -- The original PetFrame_Update will restore default name display

    -- Restore original name if PetFrame exists
    if PetFrame and PetFrame.name then
        local name = UnitName("pet")
        PetFrame.name:SetText(name or "")
    end

    S.petNameShorteningHooked = false
end

-- ============================================================================
-- Alt CD Announcement (Dota-style ability ping, text prefix ">")
-- Alt + LMB only via __SarychUIAltCDMouseClick; keybinds ignored.
-- ============================================================================

-- Single namespace for this feature: these were 76 chunk-level locals and this
-- file is at Lua's 200-local ceiling.
local AltCD = {}

AltCD.BUTTON_GROUPS = {
    { "ActionButton", 12 },
    { "MultiBarBottomLeftButton", 12 },
    { "MultiBarBottomRightButton", 12 },
    { "MultiBarRightButton", 12 },
    { "MultiBarLeftButton", 12 },
    { "BonusActionButton", 10 },
}

AltCD.ATTR_KEYS = {
    "type", "action", "spell", "macro", "macrotext", "item", "unit",
    "type1", "action1", "spell1", "macro1", "macrotext1", "item1", "unit1",
    "type2", "action2", "spell2", "macro2", "macrotext2", "item2", "unit2",
    "alt-type", "alt-type1", "alt-action", "alt-action1",
    "alt-spell", "alt-spell1", "alt-macro", "alt-macro1",
    "alt-macrotext", "alt-macrotext1", "alt-item", "alt-item1", "alt-unit", "alt-unit1",
    "*type", "*type1", "*action", "*action1",
    "*spell", "*spell1", "*macro", "*macro1", "*item", "*item1", "*unit", "*unit1",
}

function AltCD.IsActive()
    local db = DB()
    return db and db.enabled and db.enableAltCD == 1 and S.altCdEnabled
end

function AltCD.IsUnitBarActive()
    local db = DB()
    return db and db.enabled and db.enableAltUnitBars == 1
end

function AltCD.IsAuraActive()
    local db = DB()
    return db and db.enabled and db.enableAltAuras == 1
end

AltCD.PREFIX = "> "

function AltCD.GetChatChannel()
    if IsInRaid() then
        return "RAID"
    elseif IsInGroup() then
        return "PARTY"
    end
    return "SAY"
end


AltCD.DEBUG = false

function AltCD.DebugPrint(button, info, actionType, actionId, globalID)
    if not AltCD.DEBUG then
        return
    end
    local buttonName = button and button.GetName and button:GetName() or "?"
    local buttonAction = button and button.action
    local attrAction = button and button.GetAttribute and button:GetAttribute("action")
    local attrAction1 = button and button.GetAttribute and button:GetAttribute("action1")
    local slot = info and info.slot
    local spellID = info and info.spellID
    local spellName = info and info.spellName
    local spellLink = info and info.spellLink
    local cdStart, cdDuration = nil, nil
    if slot and GetActionCooldown then
        cdStart, cdDuration = GetActionCooldown(slot)
    end
    local infoName, infoRank = spellID and GetSpellInfo(spellID) or nil
    local rawLink = spellID and GetSpellLink and GetSpellLink(spellID) or nil
    print(format(
        "|cffffd200AltCD debug|r btn=%s | button.action=%s | attr.action=%s | attr.action1=%s | slot=%s | GetActionInfo=%s,%s,global=%s | GetSpellInfo=%s,%s | rawLink=%s | display=%s | GetActionCooldown=%s,%s",
        tostring(buttonName),
        tostring(buttonAction),
        tostring(attrAction),
        tostring(attrAction1),
        tostring(slot),
        tostring(actionType),
        tostring(actionId),
        tostring(globalID),
        tostring(spellID),
        tostring(spellName or infoName),
        tostring(rawLink),
        tostring(spellLink),
        tostring(cdStart),
        tostring(cdDuration)
    ))
end

function AltCD.ReadNumericAttribute(button, ...)
    if not button or not button.GetAttribute then
        return nil
    end
    for i = 1, select("#", ...) do
        local key = select(i, ...)
        local value = button:GetAttribute(key)
        if type(value) == "number" and value > 0 then
            return value
        end
        if type(value) == "string" then
            local num = tonumber(value)
            if num and num > 0 then
                return num
            end
        end
    end
    return nil
end

function AltCD.IsBlizzardActionButton(button)
    if not button or not button.GetName then
        return false
    end
    local name = button:GetName()
    if not name then
        return false
    end
    for i = 1, #AltCD.BUTTON_GROUPS do
        local prefix = AltCD.BUTTON_GROUPS[i][1]
        local maxId = AltCD.BUTTON_GROUPS[i][2]
        local id = name:match("^" .. prefix .. "(%d+)$")
        if id and tonumber(id) <= maxId then
            return true
        end
    end
    return false
end

function AltCD.GetActionSlot(button)
    if not button then
        return nil
    end

    if ActionButton_UpdateAction then
        pcall(ActionButton_UpdateAction, button)
    end

    local slot = button.action
    if type(slot) ~= "number" or slot <= 0 then
        slot = AltCD.ReadNumericAttribute(button, "action", "action1")
    end

    if not slot or slot <= 0 or not HasAction(slot) then
        return nil
    end
    return slot
end

function AltCD.Trim(text)
    if not text then
        return ""
    end
    if strtrim then
        return strtrim(text)
    end
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

function AltCD.SpellIDFromLinkOrName(text)
    if not text or text == "" then
        return nil
    end
    text = AltCD.Trim(text)
    if text == "" then
        return nil
    end

    local link = GetSpellLink and GetSpellLink(text)
    if link then
        local spellID = tonumber(link:match("spell:(%d+)"))
        if spellID and spellID > 0 then
            return spellID
        end
    end

    if GetSpellInfo and GetSpellLink then
        local name = GetSpellInfo(text)
        if name and name ~= "" then
            link = GetSpellLink(name)
            if link then
                local spellID = tonumber(link:match("spell:(%d+)"))
                if spellID and spellID > 0 then
                    return spellID
                end
            end
        end
    end

    return nil
end

function AltCD.StripCastModifiers(text)
    local result = AltCD.Trim(text)
    if result == "" then
        return result
    end

    while true do
        local cleaned, count = result:gsub("^%b[]%s*", "")
        if count == 0 then
            break
        end
        result = cleaned
    end

    local first = result:match("^([^;]+)")
    return AltCD.Trim(first or result)
end

function AltCD.GetSpellIDFromMacro(macroIndex)
    if GetMacroSpell then
        local spellID = GetMacroSpell(macroIndex)
        if type(spellID) == "number" and spellID > 0 then
            return spellID
        end
    end

    if not GetMacroBody then
        return nil
    end

    local body = GetMacroBody(macroIndex)
    if not body or body == "" then
        return nil
    end

    for line in body:gmatch("[^\r\n]+") do
        local trimmed = AltCD.Trim(line)
        local showName = trimmed:match("^#showtooltip%s+(.+)$")
        if showName then
            local spellID = AltCD.SpellIDFromLinkOrName(AltCD.StripCastModifiers(showName))
            if spellID then
                return spellID
            end
        end
    end

    for line in body:gmatch("[^\r\n]+") do
        local trimmed = AltCD.Trim(line)
        local castText = trimmed:match("^/cast%s+(.+)$") or trimmed:match("^/use%s+(.+)$")
        if castText then
            local spellID = AltCD.SpellIDFromLinkOrName(AltCD.StripCastModifiers(castText))
            if spellID then
                return spellID
            end
        end
    end

    return nil
end

function AltCD.SpellMatchesActionTexture(spellID, actionTexture)
    if not spellID or not actionTexture then
        return true
    end
    local _, _, spellTexture = GetSpellInfo(spellID)
    if not spellTexture then
        return false
    end
    return spellTexture == actionTexture
end

function AltCD.PickSpellID(actionId, globalID, actionTexture)
    local candidates = {}
    if type(globalID) == "number" and globalID > 0 then
        candidates[#candidates + 1] = globalID
    end
    if type(actionId) == "number" and actionId > 0 then
        local seen = false
        for i = 1, #candidates do
            if candidates[i] == actionId then
                seen = true
                break
            end
        end
        if not seen then
            candidates[#candidates + 1] = actionId
        end
    end

    if #candidates == 0 then
        return nil
    end
    if not actionTexture then
        return candidates[1]
    end

    for i = 1, #candidates do
        if AltCD.SpellMatchesActionTexture(candidates[i], actionTexture) then
            return candidates[i]
        end
    end

    return nil
end

function AltCD.GetSpellLink(spellID)
    if not spellID or spellID <= 0 then
        return nil
    end

    if not GetSpellInfo(spellID) then
        return nil
    end

    local link = GetSpellLink and GetSpellLink(spellID)
    if not link or not link:match("|Hspell:") or not link:match("%[.+%]") then
        return nil
    end

    return link
end

function AltCD.IsSpellLearned(spellID)
    if not spellID or spellID <= 0 then
        return false
    end

    local name = GetSpellInfo(spellID)
    if not name or name == "" then
        return false
    end

    if IsSpellKnown then
        return IsSpellKnown(spellID)
    end

    return true
end

function AltCD.IsPassiveSpell(spellID)
    if not spellID then
        return false
    end

    if IsPassiveSpell then
        return IsPassiveSpell(spellID)
    end

    local name, _, _, cost, _, powerType, castTime, minRange, maxRange = GetSpellInfo(spellID)
    if not name then
        return false
    end

    if (maxRange or 0) ~= 0 or (minRange or 0) ~= 0 or (castTime or 0) ~= 0 then
        return false
    end
    if (cost or 0) > 0 or (powerType or 0) ~= 0 then
        return false
    end

    local start, duration = GetSpellCooldown(spellID)
    if (start or 0) > 0 or (duration or 0) > 0 then
        return false
    end

    if IsUsableSpell then
        local usable, notEnoughPower = IsUsableSpell(spellID)
        if usable or notEnoughPower then
            return false
        end
        return true
    end

    return false
end

AltCD.POWER_NAMES_RU = {
    [0] = "маны",
    [1] = "ярости",
    [2] = "концентрации",
    [3] = "энергии",
    [4] = "счастья",
    [5] = "рун",
    [6] = "силы рун",
}

AltCD.POWER_DEPLETED_RU = {
    [0] = "мана",
    [1] = "ярость",
    [2] = "концентрация",
    [3] = "энергия",
    [4] = "счастье",
    [5] = "руны",
    [6] = "сила рун",
}

function AltCD.GetResourceLabel(powerType)
    if powerType == nil then
        return "ресурса"
    end
    return AltCD.POWER_NAMES_RU[powerType] or "ресурса"
end

AltCD.GCD_SPELL = 61304

AltCD.COST_PATTERNS = {
    { "(%d+)%s*маны", "маны", 0 },
    { "(%d+)%s*энергии", "энергии", 3 },
    { "(%d+)%s*ярости", "ярости", 1 },
    { "(%d+)%s*концентрации", "концентрации", 2 },
    { "(%d+)%s*силы%s*рун", "силы рун", 6 },
    { "требуется%s+(%d+)", nil, nil },
}

function AltCD.ToBool(value)
    return value == true or value == 1
end

function AltCD.GetTooltipScanner()
    if AltCD.tooltipScanner then
        return AltCD.tooltipScanner
    end
    AltCD.tooltipScanner = CreateFrame("GameTooltip", "SarychUIAltCDTooltipScanner", UIParent, "GameTooltipTemplate")
    AltCD.tooltipScanner:SetOwner(UIParent, "ANCHOR_NONE")
    return AltCD.tooltipScanner
end

function AltCD.ParseTooltipCost(slot)
    if not slot then
        return nil, nil, nil
    end

    local scanner = AltCD.GetTooltipScanner()
    if not scanner or not scanner.SetAction then
        return nil, nil, nil
    end

    scanner:ClearLines()
    scanner:SetAction(slot)

    local tooltipName = scanner:GetName()
    if not tooltipName then
        return nil, nil, nil
    end

    for i = 1, 20 do
        local line = _G[tooltipName .. "TextLeft" .. i]
        local text = line and line.GetText and line:GetText()
        if text and text ~= "" then
            local lower = string.lower(text)
            for j = 1, #AltCD.COST_PATTERNS do
                local pattern, label, powerType = AltCD.COST_PATTERNS[j][1], AltCD.COST_PATTERNS[j][2], AltCD.COST_PATTERNS[j][3]
                local cost = lower:match(pattern)
                if cost then
                    cost = tonumber(cost)
                    if cost and cost > 0 then
                        if powerType == nil and UnitPowerType then
                            powerType = UnitPowerType("player")
                        end
                        if not label and powerType ~= nil then
                            label = AltCD.GetResourceLabel(powerType)
                        end
                        return cost, label, powerType
                    end
                end
            end
        end
    end

    return nil, nil, nil
end

function AltCD.GetSpellPowerType(spellID)
    local _, _, _, _, _, powerType = GetSpellInfo(spellID)
    if powerType ~= nil then
        return powerType
    end
    if UnitPowerType then
        return UnitPowerType("player")
    end
    return 0
end

function AltCD.GetSpellCost(spellID, powerType)
    local _, _, _, cost = GetSpellInfo(spellID)
    if cost and cost > 0 then
        return cost
    end

    if GetSpellPowerCost then
        local name = GetSpellInfo(spellID)
        if name then
            local costTable = GetSpellPowerCost(name)
            if costTable then
                for _, entry in pairs(costTable) do
                    if type(entry) == "table" and entry.cost and entry.cost > 0 then
                        if powerType == nil or entry.type == powerType then
                            return entry.cost
                        end
                    end
                end
            end
        end
    end

    return nil
end

function AltCD.IsGCDOnly(start, duration)
    if not duration or duration <= 0 then
        return true
    end
    if not GetSpellCooldown then
        return false
    end
    local _, gcdDuration = GetSpellCooldown(AltCD.GCD_SPELL)
    gcdDuration = gcdDuration or 0
    if gcdDuration > 0 and duration <= gcdDuration + 0.1 then
        return true
    end
    return false
end

function AltCD.GetResourceState(slot, spellID, spellName)
    if not slot or not IsUsableAction then
        return nil
    end

    local actionUsable, actionNoMana = IsUsableAction(slot)
    local spellUsable, spellNoMana

    if spellName and IsUsableSpell then
        spellUsable, spellNoMana = IsUsableSpell(spellName)
    elseif spellID and IsUsableSpell then
        spellUsable, spellNoMana = IsUsableSpell(spellID)
    end

    if AltCD.DEBUG then
        print(
            "AltCD debug:",
            "slot", slot,
            "actionUsable", actionUsable,
            "actionNoMana", actionNoMana,
            "spellUsable", spellUsable,
            "spellNoMana", spellNoMana
        )
    end

    local lacksResource = AltCD.ToBool(actionNoMana) or AltCD.ToBool(spellNoMana)
    if not lacksResource then
        return nil
    end

    local powerType = UnitPowerType and UnitPowerType("player") or 0
    local label = AltCD.GetResourceLabel(powerType)
    local current = UnitPower and UnitPower("player", powerType) or 0

    local tooltipCost, tooltipLabel, tooltipPowerType = AltCD.ParseTooltipCost(slot)
    if tooltipCost then
        if tooltipPowerType ~= nil then
            powerType = tooltipPowerType
            current = UnitPower("player", powerType) or 0
        end
        if tooltipLabel then
            label = tooltipLabel
        end
        local missing = tooltipCost - current
        if missing > 0 then
            return label, missing
        end
        return label, nil
    end

    local cost = AltCD.GetSpellCost(spellID, powerType)
    if cost and cost > current then
        return label, cost - current
    end

    return label, nil
end

function AltCD.GetCooldownState(spellID, slot)
    local spellStart, spellDuration = 0, 0
    local slotStart, slotDuration = 0, 0

    if spellID and GetSpellCooldown then
        spellStart, spellDuration = GetSpellCooldown(spellID)
    end
    if slot and GetActionCooldown then
        slotStart, slotDuration = GetActionCooldown(slot)
    end

    spellStart = spellStart or 0
    spellDuration = spellDuration or 0
    slotStart = slotStart or 0
    slotDuration = slotDuration or 0

    local spellRemaining = 0
    if spellDuration > 0 and spellStart > 0 and not AltCD.IsGCDOnly(spellStart, spellDuration) then
        spellRemaining = ceil(spellStart + spellDuration - GetTime())
    end

    local slotRemaining = 0
    if slotDuration > 0 and slotStart > 0 and not AltCD.IsGCDOnly(slotStart, slotDuration) then
        slotRemaining = ceil(slotStart + slotDuration - GetTime())
    end

    local remaining = max(spellRemaining, slotRemaining)
    if remaining > 0 then
        return "timed", remaining
    end

    if spellDuration > 0 and spellStart <= 0 and not AltCD.IsGCDOnly(spellStart, spellDuration) then
        return "unknown"
    end
    if slotDuration > 0 and slotStart <= 0 and not AltCD.IsGCDOnly(slotStart, slotDuration) then
        return "unknown"
    end

    return "ready"
end

function AltCD.BuildMessage(spellLink, cdState, remainingCD, resourceLabel, resourceAmount, isPassive)
    if cdState == "timed" then
        return AltCD.PREFIX .. spellLink .. " перезаряжается: " .. remainingCD .. " сек."
    end
    if cdState == "unknown" then
        return AltCD.PREFIX .. spellLink .. " перезаряжается"
    end

    if resourceLabel then
        if resourceAmount and resourceAmount > 0 then
            return AltCD.PREFIX .. "На " .. spellLink .. " не хватает " .. resourceAmount .. " " .. resourceLabel
        end
        if resourceLabel ~= "ресурса" then
            return AltCD.PREFIX .. "На " .. spellLink .. " не хватает " .. resourceLabel
        end
        return AltCD.PREFIX .. "На " .. spellLink .. " не хватает ресурса"
    end

    if isPassive then
        return AltCD.PREFIX .. spellLink .. " изучена"
    end

    return AltCD.PREFIX .. spellLink .. " готова"
end

function AltCD.ResolveAction(button)
    local slot = AltCD.GetActionSlot(button)
    if not slot then
        return nil
    end

    local actionType, actionId, subType, globalID = GetActionInfo(slot)
    local actionTexture = GetActionTexture and GetActionTexture(slot)

    if actionType == "item" or actionType == "companion" then
        AltCD.DebugPrint(button, nil, actionType, actionId, globalID)
        return nil
    end

    local spellID
    if actionType == "spell" then
        spellID = AltCD.PickSpellID(actionId, globalID, actionTexture)
    elseif actionType == "macro" and actionId then
        spellID = AltCD.GetSpellIDFromMacro(actionId)
        if spellID and actionTexture and not AltCD.SpellMatchesActionTexture(spellID, actionTexture) then
            spellID = nil
        end
    else
        AltCD.DebugPrint(button, nil, actionType, actionId, globalID)
        return nil
    end

    if not spellID then
        AltCD.DebugPrint(button, nil, actionType, actionId, globalID)
        return nil
    end

    local spellName = GetSpellInfo(spellID)
    if not spellName or spellName == "" then
        AltCD.DebugPrint(button, nil, actionType, actionId, globalID)
        return nil
    end

    local spellLink = AltCD.GetSpellLink(spellID)
    if not spellLink then
        AltCD.DebugPrint(button, nil, actionType, actionId, globalID)
        return nil
    end

    if not AltCD.IsSpellLearned(spellID) then
        AltCD.DebugPrint(button, nil, actionType, actionId, globalID)
        return nil
    end

    local info = {
        slot = slot,
        spellID = spellID,
        spellName = spellName,
        spellLink = spellLink,
    }
    AltCD.DebugPrint(button, info, actionType, actionId, globalID)
    return info
end

function AltCD.AnnounceAction(info)
    if not info or not info.spellLink or not info.spellID then
        return
    end

    local spellLink = info.spellLink
    local cdState, remainingCD = AltCD.GetCooldownState(info.spellID, info.slot)
    local resourceLabel, resourceAmount = nil, nil
    local isPassive = false

    if cdState == "ready" then
        resourceLabel, resourceAmount = AltCD.GetResourceState(info.slot, info.spellID, info.spellName)
        if not resourceLabel then
            isPassive = AltCD.IsPassiveSpell(info.spellID)
        end
    end

    local message = AltCD.BuildMessage(spellLink, cdState, remainingCD, resourceLabel, resourceAmount, isPassive)
    if not message or message == "" then
        return
    end

    SendChatMessage(message, AltCD.GetChatChannel())
end

function AltCD.SaveButtonAttributes(button)
    if not button or not button.GetAttribute then
        return nil
    end

    local saved = {}
    for i = 1, #AltCD.ATTR_KEYS do
        local key = AltCD.ATTR_KEYS[i]
        local value = button:GetAttribute(key)
        if value ~= nil then
            saved[key] = value
        end
    end

    if not next(saved) then
        return nil
    end
    return saved
end

function AltCD.ClearButtonAttributes(button)
    if not button or not button.SetAttribute then
        return
    end

    for i = 1, #AltCD.ATTR_KEYS do
        button:SetAttribute(AltCD.ATTR_KEYS[i], nil)
    end
    button:SetAttribute("type", nil)
    button:SetAttribute("type1", nil)
end

function AltCD.RestoreButtonAttributes(button, saved)
    if not button or not saved or not button.SetAttribute then
        return
    end

    for key, value in pairs(saved) do
        button:SetAttribute(key, value)
    end
end

function AltCD.ClearMouseClickFlag(button)
    if not button then
        return
    end
    button.__SarychUIAltCDMouseClick = nil
    if button.__sarychAltCdFlagTimer and AceTimer then
        AceTimer:CancelTimer(button.__sarychAltCdFlagTimer)
        button.__sarychAltCdFlagTimer = nil
    end
end

function AltCD.OnMouseDown(button, mouseButton)
    if not AltCD.IsActive() then
        return
    end
    if not AltCD.IsBlizzardActionButton(button) then
        return
    end
    if mouseButton ~= "LeftButton" then
        return
    end
    if not IsAltKeyDown() then
        return
    end

    button.__SarychUIAltCDMouseClick = true

    if AceTimer then
        if button.__sarychAltCdFlagTimer then
            AceTimer:CancelTimer(button.__sarychAltCdFlagTimer)
        end
        button.__sarychAltCdFlagTimer = AceTimer:ScheduleTimer(function()
            if button then
                button.__SarychUIAltCDMouseClick = nil
                button.__sarychAltCdFlagTimer = nil
            end
        end, 1)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(1, function()
            if button then
                button.__SarychUIAltCDMouseClick = nil
            end
        end)
    end
end

function AltCD.OnMouseUp(button, mouseButton)
    if not AltCD.IsActive() then
        return
    end
    -- OnMouseUp fires before PreClick on LeftButtonUp buttons; defer clear so PreClick can consume the flag first.
    if AceTimer then
        AceTimer:ScheduleTimer(function()
            AltCD.ClearMouseClickFlag(button)
        end, 0)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            AltCD.ClearMouseClickFlag(button)
        end)
    end
end

function AltCD.OnPreClick(button, mouseButton, down)
    if not button.__SarychUIAltCDMouseClick then
        return
    end

    AltCD.ClearMouseClickFlag(button)

    if not AltCD.IsActive() then
        return
    end
    if not AltCD.IsBlizzardActionButton(button) then
        return
    end
    if mouseButton ~= "LeftButton" then
        return
    end
    if not IsAltKeyDown() then
        return
    end

    local actionInfo = AltCD.ResolveAction(button)
    if not actionInfo then
        return
    end

    local saved = AltCD.SaveButtonAttributes(button)
    if not saved and button.GetAttribute then
        local fallbackType = button:GetAttribute("type")
        if fallbackType ~= nil then
            saved = { type = fallbackType }
        end
    end
    if not saved then
        return
    end

    AltCD.AnnounceAction(actionInfo)
    AltCD.ClearButtonAttributes(button)
    button.__SarychUIAltCDRestore = saved
end

function AltCD.OnPostClick(button, mouseButton, down)
    AltCD.ClearMouseClickFlag(button)

    local saved = button and button.__SarychUIAltCDRestore
    if not saved then
        return
    end

    AltCD.RestoreButtonAttributes(button, saved)
    button.__SarychUIAltCDRestore = nil
end

function AltCD.HookButtonClickScripts(button)
    if not button or button.__SarychUIAltCDClickHooked then
        return
    end
    if not AltCD.IsBlizzardActionButton(button) then
        return
    end
    if not button.HookScript then
        return
    end

    button:HookScript("OnMouseDown", AltCD.OnMouseDown)
    button:HookScript("OnMouseUp", AltCD.OnMouseUp)
    button:HookScript("PreClick", AltCD.OnPreClick)
    button:HookScript("PostClick", AltCD.OnPostClick)
    button.__SarychUIAltCDClickHooked = true
end

function AltCD.HookAllActionButtons()
    for i = 1, #AltCD.BUTTON_GROUPS do
        local prefix = AltCD.BUTTON_GROUPS[i][1]
        local count = AltCD.BUTTON_GROUPS[i][2]
        for id = 1, count do
            AltCD.HookButtonClickScripts(_G[prefix .. id])
        end
    end
end

function AltCD.OnActionButtonLoad(button)
    AltCD.HookButtonClickScripts(button)
end

AltCD.UNIT_BAR_HOOKS = {
    { frameName = "PlayerFrameHealthBar", unit = "player", resourceType = "health" },
    { frameName = "PlayerFrameManaBar", unit = "player", resourceType = "mana" },
    { frameName = "TargetFrameHealthBar", unit = "target", resourceType = "health", fallbackName = "цели" },
    { frameName = "TargetFrameManaBar", unit = "target", resourceType = "mana", fallbackName = "цели" },
    { frameName = "FocusFrameHealthBar", unit = "focus", resourceType = "health", fallbackName = "фокуса" },
    { frameName = "FocusFrameManaBar", unit = "focus", resourceType = "mana", fallbackName = "фокуса" },
}

function AltCD.IsAltLeftMouseClick(button)
    return button == "LeftButton" and IsAltKeyDown()
end

function AltCD.GetUnitResourcePercent(unit, resourceType)
    if not unit or not UnitExists(unit) then
        return nil
    end

    local current, maximum
    if resourceType == "health" then
        current = UnitHealth(unit)
        maximum = UnitHealthMax(unit)
    elseif resourceType == "mana" then
        local powerType = UnitPowerType(unit)
        current = UnitPower(unit, powerType)
        maximum = UnitPowerMax(unit, powerType)
    else
        return nil
    end

    if not maximum or maximum <= 0 then
        return nil
    end

    return (current / maximum) * 100, current
end

function AltCD.BuildUnitResourceMessage(unit, resourceType, fallbackName, percent, current)
    local percentText = string.format("%.1f%%", percent)

    if unit == "player" then
        if resourceType == "health" then
            if percent < 30 then
                return "Мне нужна помощь, здоровья: " .. percentText
            end
            return "У меня здоровья: " .. percentText
        end
        if resourceType == "mana" then
            local powerType = UnitPowerType(unit)
            local powerName = AltCD.POWER_NAMES_RU[powerType] or "ресурса"
            local depletedName = AltCD.POWER_DEPLETED_RU[powerType] or "мана"
            if current <= 0 or percent <= 0 then
                return "У меня закончилась " .. depletedName
            end
            if percent < 20 then
                return "У меня почти нет " .. powerName .. ": " .. percentText
            end
            return "У меня " .. powerName .. ": " .. percentText
        end
        return nil
    end

    local unitName = UnitName(unit)
    local label = unitName or fallbackName
    if not label then
        return nil
    end

    if resourceType == "health" then
        return "У " .. label .. " здоровья: " .. percentText
    end
    if resourceType == "mana" then
        local powerType = UnitPowerType(unit)
        local powerName = AltCD.POWER_NAMES_RU[powerType] or "ресурса"
        return "У " .. label .. " " .. powerName .. ": " .. percentText
    end
    return nil
end

function AltCD.SendUnitResourcePing(unit, resourceType, fallbackName)
    local percent, current = AltCD.GetUnitResourcePercent(unit, resourceType)
    if not percent then
        return
    end

    local message = AltCD.BuildUnitResourceMessage(unit, resourceType, fallbackName, percent, current)
    if not message or message == "" then
        return
    end

    SendChatMessage(message, AltCD.GetChatChannel())
end

function AltCD.OnUnitBarMouseUp(frame, unit, resourceType, fallbackName, button)
    if not AltCD.IsUnitBarActive() then
        return
    end
    if not AltCD.IsAltLeftMouseClick(button) then
        return
    end
    AltCD.SendUnitResourcePing(unit, resourceType, fallbackName)
end

function AltCD.HookUnitBarPing(frameName, unit, resourceType, fallbackName)
    local frame = frameName and _G[frameName]
    if not frame or frame.__SarychUIAltCDUnitBarHooked then
        return false
    end

    if frame.EnableMouse then
        frame:EnableMouse(true)
    end

    frame:HookScript("OnMouseUp", function(_, button)
        AltCD.OnUnitBarMouseUp(frame, unit, resourceType, fallbackName, button)
    end)
    frame.__SarychUIAltCDUnitBarHooked = true
    return true
end

function AltCD.InitUnitBarPings()
    for i = 1, #AltCD.UNIT_BAR_HOOKS do
        local hook = AltCD.UNIT_BAR_HOOKS[i]
        AltCD.HookUnitBarPing(hook.frameName, hook.unit, hook.resourceType, hook.fallbackName)
    end
end

AltCD.AURA_STATIC_GROUPS = {
    { prefix = "BuffButton", count = 32, unit = "player", auraType = "buff" },
    { prefix = "DebuffButton", count = 16, unit = "player", auraType = "debuff" },
}

AltCD.AURA_FRAME_GROUPS = {
    { frameName = "TargetFrame", unit = "target", fallbackName = "цели", buffCount = 32, debuffCount = 16 },
    { frameName = "FocusFrame", unit = "focus", fallbackName = "фокусе", buffCount = 32, debuffCount = 16 },
}

function AltCD.FormatAuraTime(seconds)
    seconds = tonumber(seconds) or 0

    if seconds <= 0 then
        return "без времени"
    end

    seconds = math.floor(seconds + 0.5)

    if seconds < 60 then
        return seconds .. " сек."
    end

    local minutes = math.floor(seconds / 60)
    if minutes < 60 then
        return minutes .. " мин."
    end

    local hours = math.floor(minutes / 60)
    local restMinutes = minutes % 60

    if restMinutes > 0 then
        return hours .. " ч. " .. restMinutes .. " мин."
    end
    return hours .. " ч."
end

function AltCD.GetAuraInfo(unit, auraType, index)
    if not unit or not UnitExists(unit) then
        return nil
    end

    local name, rank, icon, count, debuffType, duration, expirationTime, caster
    local spellID

    if auraType == "buff" then
        name, rank, icon, count, debuffType, duration, expirationTime, caster, _, _, spellID = UnitBuff(unit, index)
    elseif auraType == "debuff" then
        name, rank, icon, count, debuffType, duration, expirationTime, caster, _, _, spellID = UnitDebuff(unit, index)
    else
        return nil
    end

    if not name or name == "" then
        return nil
    end

    local displayLink = name
    if type(spellID) == "number" and spellID > 0 and GetSpellLink then
        local link = GetSpellLink(spellID)
        if link and link ~= "" then
            displayLink = link
        end
    elseif GetSpellLink then
        local link = GetSpellLink(name)
        if link and link ~= "" then
            displayLink = link
        end
    end

    local remaining = 0
    if expirationTime and expirationTime > 0 then
        remaining = expirationTime - GetTime()
        if remaining < 0 then
            remaining = 0
        end
    end

    return {
        displayLink = displayLink,
        count = count,
        remaining = remaining,
    }
end

function AltCD.BuildAuraTimeSuffix(remaining)
    if remaining and remaining > 0 then
        return " — осталось " .. AltCD.FormatAuraTime(remaining)
    end
    return " — без времени"
end

function AltCD.BuildAuraStackSuffix(count)
    if type(count) == "number" and count >= 2 then
        return " x" .. count
    end
    return ""
end

function AltCD.BuildAuraMessage(unit, auraType, auraInfo, fallbackName)
    if not auraInfo or not auraInfo.displayLink or auraInfo.displayLink == "" then
        return nil
    end

    local spellPart = auraInfo.displayLink .. AltCD.BuildAuraStackSuffix(auraInfo.count)
    local timeSuffix = AltCD.BuildAuraTimeSuffix(auraInfo.remaining)
    local kind = (auraType == "buff") and "баф" or "дебаф"

    if unit == "player" then
        return "На мне " .. kind .. ": " .. spellPart .. timeSuffix
    end

    local unitName = UnitName(unit)
    local label = unitName or fallbackName
    if not label or label == "" then
        return nil
    end

    return "На " .. label .. " " .. kind .. ": " .. spellPart .. timeSuffix
end

function AltCD.SendAuraPing(unit, auraType, index, fallbackName)
    local auraInfo = AltCD.GetAuraInfo(unit, auraType, index)
    if not auraInfo then
        return
    end

    local message = AltCD.BuildAuraMessage(unit, auraType, auraInfo, fallbackName)
    if not message or message == "" then
        return
    end

    SendChatMessage(message, AltCD.GetChatChannel())
end

function AltCD.OnAuraButtonMouseUp(frame, unit, auraType, index, fallbackName, button)
    if not AltCD.IsAuraActive() then
        return
    end
    if not AltCD.IsAltLeftMouseClick(button) then
        return
    end

    local auraIndex = index
    if frame and frame.GetID then
        local id = frame:GetID()
        if type(id) == "number" and id > 0 then
            auraIndex = id
        end
    end

    AltCD.SendAuraPing(unit, auraType, auraIndex, fallbackName)
end

function AltCD.HookAuraButton(frameName, unit, auraType, index, fallbackName)
    local frame = frameName and _G[frameName]
    if not frame or frame.__SarychUIAltCDAuraHooked then
        return false
    end

    if frame.EnableMouse then
        frame:EnableMouse(true)
    end

    frame:HookScript("OnMouseUp", function(_, button)
        AltCD.OnAuraButtonMouseUp(frame, unit, auraType, index, fallbackName, button)
    end)
    frame.__SarychUIAltCDAuraHooked = true
    return true
end

function AltCD.HookAuraButtonRange(prefix, unit, auraType, count, fallbackName)
    if not prefix or not count then
        return
    end
    for i = 1, count do
        AltCD.HookAuraButton(prefix .. i, unit, auraType, i, fallbackName)
    end
end

function AltCD.HookFrameAuraButtons(parentFrame, unit, fallbackName, buffCount, debuffCount)
    if not parentFrame or not parentFrame.GetName then
        return
    end
    local baseName = parentFrame:GetName()
    if not baseName then
        return
    end
    AltCD.HookAuraButtonRange(baseName .. "Buff", unit, "buff", buffCount, fallbackName)
    AltCD.HookAuraButtonRange(baseName .. "Debuff", unit, "debuff", debuffCount, fallbackName)
end

function AltCD.InitAuraPings()
    for i = 1, #AltCD.AURA_STATIC_GROUPS do
        local group = AltCD.AURA_STATIC_GROUPS[i]
        AltCD.HookAuraButtonRange(group.prefix, group.unit, group.auraType, group.count, nil)
    end

    for i = 1, #AltCD.AURA_FRAME_GROUPS do
        local group = AltCD.AURA_FRAME_GROUPS[i]
        local parentFrame = group.frameName and _G[group.frameName]
        if parentFrame then
            AltCD.HookFrameAuraButtons(
                parentFrame,
                group.unit,
                group.fallbackName,
                group.buffCount,
                group.debuffCount
            )
        end
    end
end

function AltCD.InstallAuraUpdateHooks()
    if S.altCdAuraUpdateHooked or not hooksecurefunc then
        return
    end

    if type(TargetFrame_UpdateAuras) == "function" then
        hooksecurefunc("TargetFrame_UpdateAuras", function(self)
            local unit = (self and self.unit) or "target"
            local fallbackName = (unit == "focus") and "фокусе" or "цели"
            AltCD.HookFrameAuraButtons(self, unit, fallbackName, 32, 16)
        end)
    end

    if type(FocusFrame_UpdateAuras) == "function" then
        hooksecurefunc("FocusFrame_UpdateAuras", function(self)
            AltCD.HookFrameAuraButtons(self, "focus", "фокусе", 32, 16)
        end)
    end

    if type(BuffFrame_Update) == "function" then
        hooksecurefunc("BuffFrame_Update", function()
            AltCD.HookAuraButtonRange("BuffButton", "player", "buff", 32, nil)
            AltCD.HookAuraButtonRange("DebuffButton", "player", "debuff", 16, nil)
        end)
    end

    S.altCdAuraUpdateHooked = true
end

function AltCD.EnsureUnitBarPingEventFrame()
    if S.altCdUnitBarEventFrame then
        return
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function()
        AltCD.InitUnitBarPings()
        AltCD.InitAuraPings()
    end)
    S.altCdUnitBarEventFrame = frame
end

function AltCD.InstallAuraHooks()
    AltCD.EnsureUnitBarPingEventFrame()
    AltCD.InstallAuraUpdateHooks()
    AltCD.InitAuraPings()
end

function AltCD.InstallUnitBarHooks()
    AltCD.EnsureUnitBarPingEventFrame()
    AltCD.InitUnitBarPings()
end

function AltCD.InstallHooks()
    if S.altCdHooksInstalled then
        return
    end

    AltCD.HookAllActionButtons()

    if type(ActionButton_OnLoad) == "function" and hooksecurefunc then
        hooksecurefunc("ActionButton_OnLoad", AltCD.OnActionButtonLoad)
    end

    S.altCdHooksInstalled = true
end

function AltCD.RemoveHooks()
    S.altCdHooksInstalled = false
end

-- Apply alt CD announcement settings
function module:ApplyAltCD()
    local db = DB()
    if not db or not db.enabled then
        if S.altCdEnabled then
            self:DisableAltCD()
        end
        return
    end

    if db.enableAltCD == 1 then
        self:EnableAltCD()
    elseif S.altCdEnabled then
        self:DisableAltCD()
    end
end

-- Enable alt CD announcement
function module:EnableAltCD()
    local db = DB()
    if not db or not db.enabled then
        return
    end

    AltCD.InstallHooks()
    S.altCdEnabled = true
end

-- Disable alt CD announcement
function module:DisableAltCD()
    S.altCdEnabled = false
    -- Keep S.altCdHooksInstalled so ActionButton_OnLoad is not hooked again on re-enable.
end

function module:ApplyAltUnitBars()
    local db = DB()
    if not db or not db.enabled then
        return
    end
    if db.enableAltUnitBars ~= 1 then
        if db.enableFocuser == 1 then
            self:ApplyFocuser()
        end
        return
    end

    AltCD.InstallUnitBarHooks()
    if db.enableFocuser == 1 then
        self:ApplyFocuser()
    end
end

function module:ApplyAltAuras()
    local db = DB()
    if not db or not db.enabled then
        return
    end
    if db.enableAltAuras ~= 1 then
        return
    end

    AltCD.InstallAuraHooks()
end

-- ============================================================================
-- Alt FPS Functionality
-- ============================================================================

-- Get clamped FPS scale from profile (default 1.0)
local function GetFpsScale(db)
    local scale = db and db.fpsScale
    if type(scale) ~= "number" then
        scale = 1.0
    elseif scale < 0.5 then
        scale = 0.5
    elseif scale > 2.0 then
        scale = 2.0
    end
    return scale
end

local FPS_FONT_FALLBACK = {
    path = "Fonts\\FRIZQT__.TTF",
    size = 10,
    flags = "",
}

-- Cache original font for a Blizzard FPS FontString (once per key)
local function CacheOriginalFpsFont(fontString, cacheKey)
    if not fontString or not fontString.GetFont or not cacheKey then return end
    if S.altFpsOriginalFonts[cacheKey] then return end

    local fontPath, fontSize, fontFlags = fontString:GetFont()
    if fontPath and fontSize then
        S.altFpsOriginalFonts[cacheKey] = {
            path = fontPath,
            size = fontSize,
            flags = fontFlags or FPS_FONT_FALLBACK.flags,
        }
    end
end

local function ForEachFpsFontString(callback)
    if FramerateLabel then callback(FramerateLabel, "label") end
    if FramerateText then callback(FramerateText, "text") end
end

-- Restore Blizzard FPS fonts to original size (for /fps and when Alt FPS is off)
local function ResetFpsFonts()
    ForEachFpsFontString(function(fontString, cacheKey)
        local cached = S.altFpsOriginalFonts[cacheKey]
        if cached and fontString.SetFont then
            fontString:SetFont(cached.path, cached.size, cached.flags)
        end
    end)

    if FramerateFrame and FramerateFrame.SetScale then
        FramerateFrame:SetScale(1.0)
    end
end

-- Apply font scale to Blizzard FPS FontStrings (FramerateLabel + FramerateText)
local function ApplyFpsFontScale(fontString, cacheKey, scale)
    if not fontString or not fontString.SetFont then return end

    CacheOriginalFpsFont(fontString, cacheKey)
    local cached = S.altFpsOriginalFonts[cacheKey]
    local fontPath = cached and cached.path or FPS_FONT_FALLBACK.path
    local fontSize = (cached and cached.size or FPS_FONT_FALLBACK.size) * scale
    local fontFlags = cached and cached.flags or FPS_FONT_FALLBACK.flags

    fontString:SetFont(fontPath, fontSize, fontFlags)
end

-- Apply FPS scale (font size) when Alt FPS is enabled; reset when disabled
local function ApplyFpsScale(db)
    db = db or (SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName])

    if not FramerateLabel and not FramerateText then return end

    local altFpsActive = db and db.enabled and db.enableAltFPS == 1
    if not altFpsActive then
        ResetFpsFonts()
        return
    end

    local scale = GetFpsScale(db)
    ForEachFpsFontString(function(fontString, cacheKey)
        ApplyFpsFontScale(fontString, cacheKey, scale)
    end)
end

-- Set FPS position
local function SetFpsPosition()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not db.enabled then return end
    
    if not FramerateLabel then return end
    
    local offsetX = db.fpsOffsetX or 664
    local offsetY = db.fpsOffsetY or 130
    local extraX = tonumber(db.fpsExtraOffsetX) or 0
    local extraY = tonumber(db.fpsExtraOffsetY) or 0
    local _, class = UnitClass("player")
    if class == "PRIEST" or class == "WARLOCK" then
        offsetY = offsetY - 20
    end
    FramerateLabel:ClearAllPoints()
    FramerateLabel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -10 + offsetX + extraX, -10 + offsetY + extraY)
    ApplyFpsScale(db)
end

function module:SetFpsPosition()
    SetFpsPosition()
end

-- Toggle FPS visibility and re-apply position + scale (scale after ToggleFramerate)
local function ShowAltFps(db)
    ToggleFramerate()
    SetFpsPosition()
    ApplyFpsScale(db)
    S.altFpsReapplyScale = true
    S.EnsureAltFpsDriver()
end

local function HideAltFps()
    if S.altFpsShown then
        ToggleFramerate()
        S.altFpsShown = false
    end
    -- Ничего не переприменяем на скрытом счётчике: иначе флаг остался бы висеть
    -- и держал драйвер запущенным.
    S.altFpsReapplyScale = false
end

-- The FPS driver only has work to do while a post-ToggleFramerate scale re-apply is
-- pending, or when the Alt Mode system is missing and Alt must be polled directly.
-- Outside those cases the OnUpdate is removed instead of idling every frame.
-- Kept on S rather than as file locals: this chunk is at Lua's 200-local ceiling.
function S.AltFpsNeedsDriver()
    return S.altFpsReapplyScale == true or SarychUI.AltMode == nil
end

function S.AltFpsOnUpdate(self)
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local checkDb = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not checkDb or not checkDb.enabled then
        if S.altFpsShown then
            HideAltFps()
        end
        self:SetScript("OnUpdate", nil)
        return
    end

    -- Re-apply position and font scale next frame after ToggleFramerate (Blizzard may reset on show)
    if S.altFpsReapplyScale and S.altFpsShown then
        SetFpsPosition()
        ApplyFpsScale(checkDb)
        S.altFpsReapplyScale = false
    end

    -- Fallback to direct check if Alt Mode System not available
    if not SarychUI.AltMode then
        if checkDb.enableAltFPS == 1 and IsAltKeyDown() and not S.altFpsShown then
            ShowAltFps(checkDb)
            S.altFpsShown = true
        elseif (checkDb.enableAltFPS ~= 1 or not IsAltKeyDown()) and S.altFpsShown then
            HideAltFps()
        end
    end

    if not S.AltFpsNeedsDriver() then
        self:SetScript("OnUpdate", nil)
    end
end

function S.EnsureAltFpsDriver()
    if not S.altFpsFrame then return end
    if not S.AltFpsNeedsDriver() then return end
    if S.altFpsFrame:GetScript("OnUpdate") then return end
    S.altFpsFrame:SetScript("OnUpdate", S.AltFpsOnUpdate)
end

-- Apply alt FPS settings
function module:ApplyAltFPS()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not db.enabled then
        -- Disable if module is disabled
        if S.altFpsFrame then
            self:DisableAltFPS()
        end
        ApplyFpsScale(nil)
        return
    end
    
    if db.enableAltFPS == 1 then
        -- Enable if not already enabled
        if not S.altFpsFrame then
            self:EnableAltFPS()
        else
            -- Just update position if already enabled
            if FramerateLabel and FramerateLabel:IsShown() then
                SetFpsPosition()
            else
                ApplyFpsScale(db)
            end
        end
    else
        -- Disable if enabled
        if S.altFpsFrame then
            self:DisableAltFPS()
        end
        ApplyFpsScale(nil)
    end
end

-- Apply FPS scale setting (called from options)
function module:ApplyFpsScale()
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    ApplyFpsScale(db)
end

-- Alt FPS Alt state callback
local function AltFPSAltCallback(isAltPressed)
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not db.enabled then return end
    if db.enableAltFPS ~= 1 then
        if S.altFpsShown then
            HideAltFps()
        end
        return
    end
    
    S.altFpsAltPressed = isAltPressed
    
    if isAltPressed and not S.altFpsShown then
        ShowAltFps(db)
        S.altFpsShown = true
    elseif not isAltPressed and S.altFpsShown then
        HideAltFps()
    end
end

-- Enable alt FPS
function module:EnableAltFPS()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not db.enabled then return end
    
    if S.altFpsFrame then return end -- Already enabled

    -- Cache Blizzard default fonts before any scaling
    ForEachFpsFontString(function(fontString, cacheKey)
        CacheOriginalFpsFont(fontString, cacheKey)
    end)
    
    -- Register Alt mode callback
    if SarychUI.AltMode then
        SarychUI.AltMode:RegisterCallback("altFPS", AltFPSAltCallback)
        S.altFpsAltPressed = SarychUI.AltMode:IsAltPressed() or false
    end
    
    -- Create frame and register PLAYER_LOGIN event
    S.altFpsFrame = CreateFrame("Frame")
    S.altFpsShown = false
    
    S.altFpsFrame:RegisterEvent("PLAYER_LOGIN")
    S.altFpsFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_LOGIN" then
            -- Set initial position
            SetFpsPosition()
        end
    end)
    
    -- Set initial position and scale if FramerateLabel exists
    if FramerateLabel then
        SetFpsPosition()
    end
    
    S.EnsureAltFpsDriver()
end

-- Disable alt FPS
function module:DisableAltFPS()
    if not S.altFpsFrame then return end
    
    -- Unregister Alt mode callback
    if SarychUI.AltMode then
        SarychUI.AltMode:UnregisterCallback("altFPS")
    end
    
    -- Hide FPS if shown
    HideAltFps()

    -- Restore original Blizzard FPS fonts so /fps is unaffected
    ResetFpsFonts()
    
    -- Unregister events and clear scripts
    S.altFpsFrame:UnregisterAllEvents()
    S.altFpsFrame:SetScript("OnEvent", nil)
    S.altFpsFrame:SetScript("OnUpdate", nil)
    S.altFpsFrame = nil
    S.altFpsShown = false
    S.altFpsAltPressed = false
    S.altFpsReapplyScale = false
end

-- ============================================================================
-- SpeedyLoad Functionality
-- ============================================================================

-- Events to unregister during loading (safe set)
S.speedyLoadEventsSafe = {
    SPELLS_CHANGED = {},
    USE_GLYPH = {},
    PET_TALENT_UPDATE = {},
    PLAYER_TALENT_UPDATE = {},
    WORLD_MAP_UPDATE = {},
    UPDATE_WORLD_STATES = {},
    CRITERIA_UPDATE = {},
    RECEIVED_ACHIEVEMENT_LIST = {},
    ACTIONBAR_SLOT_CHANGED = {},
    SPELL_UPDATE_USABLE = {},
    UPDATE_FACTION = {}
}

-- Extra events for aggressive mode (restored without re-fire — args are required)
S.speedyLoadEventsAggressiveExtra = {
    ACTIONBAR_UPDATE_STATE = {},
    ACTIONBAR_UPDATE_USABLE = {},
    ACTIONBAR_UPDATE_COOLDOWN = {},
    SPELL_UPDATE_COOLDOWN = {},
    UNIT_AURA = {},
    UNIT_INVENTORY_CHANGED = {},
    BAG_UPDATE = {},
    QUEST_LOG_UPDATE = {},
    COMPANION_UPDATE = {},
    PET_BAR_UPDATE = {},
    TRADE_SKILL_UPDATE = {},
    MERCHANT_UPDATE = {},
}

-- Active event table (rebuilt when mode changes)
S.speedyLoadEvents = {}

local function SpeedyLoad_RebuildEventTable()
    local sys = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.system
    local mode = (sys and sys.speedyLoadMode) or "safe"
    wipe(S.speedyLoadEvents)
    for e in pairs(S.speedyLoadEventsSafe) do
        S.speedyLoadEvents[e] = {}
    end
    if mode == "aggressive" then
        for e in pairs(S.speedyLoadEventsAggressiveExtra) do
            S.speedyLoadEvents[e] = {}
        end
    end
end

SpeedyLoad_RebuildEventTable()

-- Events that are safe to re-fire with a known dummy arg after loading
local SPEEDY_REFIRE_SAFE = {
    ACTIONBAR_SLOT_CHANGED = true,
}

-- After /reload or loading screens, unit portraits may stay blank until refreshed.
-- Kept on S (not local) — tools/module.lua is near Lua 5.1's 200-local limit.
function S.SpeedyLoad_RefreshUnitPortraits()
    local update = UnitFramePortrait_Update
    if type(update) == "function" then
        local frames = {
            PlayerFrame, PetFrame, TargetFrame, FocusFrame,
            TargetFrameToT, FocusFrameToT,
            PartyMemberFrame1, PartyMemberFrame2, PartyMemberFrame3, PartyMemberFrame4,
        }
        for i = 1, #frames do
            local frame = frames[i]
            if frame then
                pcall(update, frame)
            end
        end
    end
    if type(SetPortraitTexture) == "function" then
        if PlayerPortrait then pcall(SetPortraitTexture, PlayerPortrait, "player") end
        if PetPortrait then pcall(SetPortraitTexture, PetPortrait, "pet") end
        if TargetFramePortrait and UnitExists("target") then
            pcall(SetPortraitTexture, TargetFramePortrait, "target")
        end
        if FocusFramePortrait and UnitExists("focus") then
            pcall(SetPortraitTexture, FocusFramePortrait, "focus")
        end
        if MicroButtonPortrait then
            pcall(SetPortraitTexture, MicroButtonPortrait, "player")
        end
    end
    if type(PlayerFrame_Update) == "function" then
        pcall(PlayerFrame_Update)
    end
    local frameMod = SarychUI and SarychUI.modules and SarychUI.modules.frame
    if frameMod and frameMod.Apply3DPortraits then
        pcall(function()
            frameMod:Apply3DPortraits()
        end)
    end
end

function S.SpeedyLoad_SchedulePortraitRefresh()
    local driver = S.speedyLoadPortraitDriver
    if not driver then
        driver = CreateFrame("Frame")
        S.speedyLoadPortraitDriver = driver
        driver:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = (self.elapsed or 0) + elapsed
            local step = self.step or 0
            if step == 0 then
                S.SpeedyLoad_RefreshUnitPortraits()
                self.step = 1
            elseif step == 1 and self.elapsed >= 0.15 then
                S.SpeedyLoad_RefreshUnitPortraits()
                self.step = 2
            elseif step == 2 and self.elapsed >= 0.5 then
                S.SpeedyLoad_RefreshUnitPortraits()
                self.step = 3
            elseif step == 3 and self.elapsed >= 1.0 then
                S.SpeedyLoad_RefreshUnitPortraits()
                self.step = 4
            elseif step == 4 and self.elapsed >= 2.0 then
                S.SpeedyLoad_RefreshUnitPortraits()
                self.step = 5
            elseif step == 5 and self.elapsed >= 3.0 then
                S.SpeedyLoad_RefreshUnitPortraits()
                self.step = 0
                self.elapsed = 0
                self:Hide()
            end
        end)
    end
    driver.elapsed = 0
    driver.step = 0
    driver:Show()
end

-- Needed locals for tracking
S.speedyLoadOccured, S.speedyLoadListenForUnreg, S.speedyLoadList = {}, false, nil
S.validUnregisterFuncs = nil

-- Check if unregister function is valid (security check)
local function SpeedyLoad_IsValidUnregisterFunc(tbl, func)
    if not func then return false end
    local valid = issecurevariable(tbl, "UnregisterEvent")
    if not S.validUnregisterFuncs[func] then
        S.validUnregisterFuncs[func] = not (not valid)
    end
    return valid
end

-- Unregister events for speedy loading with security checks
local function SpeedyLoad_Unregister(event, ...)
    for i = 1, select("#", ...) do
        local frame = select(i, ...)
        if frame then
            local UnregisterEvent = frame.UnregisterEvent
            if UnregisterEvent then
                -- Check if we can safely call UnregisterEvent
                if S.validUnregisterFuncs[UnregisterEvent] or SpeedyLoad_IsValidUnregisterFunc(frame, UnregisterEvent) then
                    UnregisterEvent(frame, event)
                    S.speedyLoadEvents[event][frame] = 1
                end
            end
        end
    end
end

-- SpeedyLoad event handler
local function SpeedyLoad_EventHandler(self, event, ...)
    local sys = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.system
    if not sys or (sys.enableSpeedyLoad ~= 1 and sys.enableSpeedyLoad ~= true) then
        return
    end
    
    if event == "ADDON_LOADED" then
        local name = ...
        -- Check if SarychUI is loaded (or core is loaded)
        if name and (name == "SarychUI" or name:lower() == "sarychui") then
            S.speedyLoadFrame:UnregisterEvent("ADDON_LOADED")

            -- Make sure our PLAYER_ENTERING_WORLD is always the first
            S.speedyLoadList = {GetFramesRegisteredForEvent("PLAYER_ENTERING_WORLD")}
            for i, frame in ipairs(S.speedyLoadList) do
                if frame and frame.UnregisterEvent then
                    frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
                end
            end

            -- After we register PLAYER_ENTERING_WORLD to our frame, we put back
            -- the event to all the frames it was removed from
            S.speedyLoadFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
            for i, frame in ipairs(S.speedyLoadList) do
                if frame and frame.RegisterEvent then
                    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
                end
            end
            wipe(S.speedyLoadList)
            S.speedyLoadList = nil

            -- WTF Blizzard, why registering this event?
            if PetStableFrame and PetStableFrame.UnregisterEvent then
                PetStableFrame:UnregisterEvent("SPELLS_CHANGED")
            end
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        if not S.speedyLoadEnteredOnce then
            S.speedyLoadFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
            
            -- Hook UnregisterEvent to track when frames unregister events
            if S.speedyLoadFrame and getmetatable(S.speedyLoadFrame) and getmetatable(S.speedyLoadFrame).__index then
                hooksecurefunc(getmetatable(S.speedyLoadFrame).__index, "UnregisterEvent", function(frame, event)
                    if S.speedyLoadListenForUnreg then
                        local frames = S.speedyLoadEvents[event]
                        if frames then
                            frames[frame] = nil
                        end
                    end
                end)
            end
            
            S.speedyLoadEnteredOnce = true
            -- /reload race: PLAYER_LEAVING_WORLD can fire before the first PEW and
            -- leave Blizzard frames without SPELLS_CHANGED / etc. Restore now.
            for e, frames in pairs(S.speedyLoadEvents) do
                for frame in pairs(frames) do
                    if frame and frame.RegisterEvent then
                        frame:RegisterEvent(e)
                    end
                    frames[frame] = nil
                end
            end
            wipe(S.speedyLoadOccured)
            S.speedyLoadListenForUnreg = false
            for e in pairs(S.speedyLoadEvents) do
                S.speedyLoadFrame:UnregisterEvent(e)
            end
            S.SpeedyLoad_SchedulePortraitRefresh()
        else
            S.speedyLoadListenForUnreg = false
            
            -- Re-register all events that were unregistered
            for e, frames in pairs(S.speedyLoadEvents) do
                for frame in pairs(frames) do
                    if frame and frame.RegisterEvent then
                        frame:RegisterEvent(e)
                        
                        -- Only re-fire events with known-safe dummy args.
                        -- Aggressive events (UNIT_AURA, BAG_UPDATE, …) need real
                        -- payloads; re-firing with nil crashes addons (e.g. Carbonite).
                        if S.speedyLoadOccured[e] and SPEEDY_REFIRE_SAFE[e] then
                            local OnEvent = frame:GetScript("OnEvent")
                            if OnEvent then
                                local arg1 = (e == "ACTIONBAR_SLOT_CHANGED") and 0 or nil
                                local success, err = pcall(OnEvent, frame, e, arg1)
                                if not success and geterrorhandler then
                                    geterrorhandler()(err, 1)
                                end
                            end
                        end
                    end
                    frames[frame] = nil
                end
            end
            wipe(S.speedyLoadOccured)
            
            -- Stop listening to these events on our frame until next leave
            for e in pairs(S.speedyLoadEvents) do
                S.speedyLoadFrame:UnregisterEvent(e)
            end
            S.SpeedyLoad_SchedulePortraitRefresh()
        end

    elseif event == "PLAYER_LEAVING_WORLD" then
        wipe(S.speedyLoadOccured)
        
        -- Unregister events for speedy loading
        for e in pairs(S.speedyLoadEvents) do
            SpeedyLoad_Unregister(e, GetFramesRegisteredForEvent(e))
            -- MUST REGISTER AFTER UNREGISTER
            S.speedyLoadFrame:RegisterEvent(e)
        end
        
        S.speedyLoadListenForUnreg = true

    else
        -- Track that this event occurred
        S.speedyLoadOccured[event] = 1
        -- Compress: do not propagate or simulate, just stop listening to duplicates
        S.speedyLoadFrame:UnregisterEvent(event)
    end
end

-- Apply speedy load settings
function module:ApplySpeedyLoad()
    local sys = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.system
    local enabled = sys and (sys.enableSpeedyLoad == 1 or sys.enableSpeedyLoad == true)
    SpeedyLoad_RebuildEventTable()
    if enabled then
        if S.speedyLoadInitialized then
            -- Mode change while active: rebuild tables for next leave/enter cycle.
            for e in pairs(S.speedyLoadEvents) do
                S.speedyLoadEvents[e] = S.speedyLoadEvents[e] or {}
            end
        else
            self:EnableSpeedyLoad()
        end
    else
        if S.speedyLoadInitialized then
            self:DisableSpeedyLoad()
        end
    end
end

-- Enable speedy load
function module:EnableSpeedyLoad()
    local sys = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.system
    if not sys or (sys.enableSpeedyLoad ~= 1 and sys.enableSpeedyLoad ~= true) then return end
    
    if S.speedyLoadInitialized then return end -- Already enabled
    
    -- Create frame
    S.speedyLoadFrame = CreateFrame("Frame")
    S.speedyLoadEnteredOnce = false
    
    -- Initialize valid unregister functions cache
    S.validUnregisterFuncs = {[S.speedyLoadFrame.UnregisterEvent] = true}
    
    -- Reset tracking variables
    S.speedyLoadOccured = {}
    S.speedyLoadListenForUnreg = false
    S.speedyLoadList = nil
    
    -- Reset events tables for current mode
    SpeedyLoad_RebuildEventTable()
    for e in pairs(S.speedyLoadEvents) do
        S.speedyLoadEvents[e] = {}
    end

    -- Register ADDON_LOADED to detect when SarychUI is loaded
    S.speedyLoadFrame:RegisterEvent("ADDON_LOADED")
    
    -- Check if SarychUI is already loaded
    if IsAddOnLoaded("SarychUI") then
        S.speedyLoadFrame:UnregisterEvent("ADDON_LOADED")
        S.speedyLoadFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        
        -- Make sure our PLAYER_ENTERING_WORLD is always the first
        S.speedyLoadList = {GetFramesRegisteredForEvent("PLAYER_ENTERING_WORLD")}
        for i, frame in ipairs(S.speedyLoadList) do
            if frame and frame.UnregisterEvent then
                frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
            end
        end
        
        -- After we register PLAYER_ENTERING_WORLD to our frame, we put back
        -- the event to all the frames it was removed from
        S.speedyLoadFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        for i, frame in ipairs(S.speedyLoadList) do
            if frame and frame.RegisterEvent then
                frame:RegisterEvent("PLAYER_ENTERING_WORLD")
            end
        end
        wipe(S.speedyLoadList)
        S.speedyLoadList = nil
        
        -- WTF Blizzard, why registering this event?
        if PetStableFrame and PetStableFrame.UnregisterEvent then
            PetStableFrame:UnregisterEvent("SPELLS_CHANGED")
        end
    end
    
    -- Set event handler
    S.speedyLoadFrame:SetScript("OnEvent", SpeedyLoad_EventHandler)
    
    S.speedyLoadInitialized = true
end

-- Disable speedy load
function module:DisableSpeedyLoad()
    if not S.speedyLoadInitialized then return end
    
    -- Re-register all events that were unregistered
    for e, frames in pairs(S.speedyLoadEvents) do
        for frame in pairs(frames) do
            if frame and frame.RegisterEvent then
                frame:RegisterEvent(e)
            end
            frames[frame] = nil
        end
    end
    
    -- Unregister all events and clear script
    if S.speedyLoadFrame then
        S.speedyLoadFrame:UnregisterAllEvents()
        S.speedyLoadFrame:SetScript("OnEvent", nil)
        S.speedyLoadFrame = nil
    end
    
    -- Reset state
    S.speedyLoadEnteredOnce = false
    
    -- Reset tracking variables
    S.speedyLoadOccured = {}
    S.speedyLoadListenForUnreg = false
    S.speedyLoadList = nil
    S.validUnregisterFuncs = nil
    
    -- Reset events tables
    for e in pairs(S.speedyLoadEvents) do
        S.speedyLoadEvents[e] = {}
    end
    
    S.speedyLoadInitialized = false
end

-- ============================================================================
-- Tooltip Cursor Functionality
-- ============================================================================

-- Rebuild tooltip with cursor or default anchor
local function RebuildTooltip(anchorMode)
    if not GameTooltip then return end
    
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not db.enabled then return end
    
    local mf = GetMouseFocus()
    GameTooltip:ClearAllPoints()
    if anchorMode == "cursor" then
        GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
        S.tooltipCursorAnchored = true
    else
        GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
        S.tooltipCursorAnchored = false
    end

    local rebuilt = false
    if mf and mf.GetScript then
        local onEnter = mf:GetScript("OnEnter")
        if onEnter then
            local ok = pcall(onEnter, mf)
            rebuilt = ok and (GameTooltip:NumLines() or 0) > 0
        end
    end
    if not rebuilt and UnitExists and UnitExists("mouseover") then
        local ok = pcall(GameTooltip.SetUnit, GameTooltip, "mouseover")
        rebuilt = ok and (GameTooltip:NumLines() or 0) > 0
    end
    if not rebuilt then
        GameTooltip:Show()
    end
end

-- ============================================================================
-- Easy Item Destroy Functionality
-- ============================================================================

-- Check if easy item destroy is enabled
local function IsEasyItemDestroyEnabled()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not db.enabled then return false end
    return db.enableEasyItemDestroy == 1
end

-- Apply easy item destroy settings
function module:ApplyEasyItemDestroy()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not db.enabled then
        -- Disable if module is disabled
        if S.easyItemDestroyEnabled then
            self:DisableEasyItemDestroy()
        end
        return
    end
    
    -- Check if function is enabled in settings
    if db.enableEasyItemDestroy == 1 then
        -- Check if StaticPopupDialogs is ready
        if StaticPopupDialogs and StaticPopupDialogs["DELETE_GOOD_ITEM"] then
            -- Enable if not already enabled
            if not S.easyItemDestroyEnabled then
                self:EnableEasyItemDestroy()
            end
        else
            -- StaticPopupDialogs not ready yet, try again on PLAYER_LOGIN
            if not S.easyItemDestroyInitFrame then
                S.easyItemDestroyInitFrame = CreateFrame("Frame")
                S.easyItemDestroyInitFrame:RegisterEvent("PLAYER_LOGIN")
                S.easyItemDestroyInitFrame:SetScript("OnEvent", function(self, event)
                    if event == "PLAYER_LOGIN" then
                        self:UnregisterEvent("PLAYER_LOGIN")
                        -- Re-check and enable if needed
                        module:ApplyEasyItemDestroy()
                    end
                end)
            end
        end
    else
        -- Disable if setting is off
        if S.easyItemDestroyEnabled then
            self:DisableEasyItemDestroy()
        end
        -- Clean up init frame if exists
        if S.easyItemDestroyInitFrame then
            S.easyItemDestroyInitFrame:UnregisterAllEvents()
            S.easyItemDestroyInitFrame:SetScript("OnEvent", nil)
            S.easyItemDestroyInitFrame = nil
        end
    end
end

-- Enable easy item destroy
function module:EnableEasyItemDestroy()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not db.enabled then return end
    
    -- Don't enable if already enabled
    if S.easyItemDestroyEnabled then return end
    
    -- Clean up old frame if exists (safety check)
    if S.easyDelFrame then
        S.easyDelFrame:UnregisterAllEvents()
        S.easyDelFrame:SetScript("OnEvent", nil)
        S.easyDelFrame:Hide()
        S.easyDelFrame = nil
    end
    
    -- Get the type "DELETE" into the field to confirm text
    local DELETE_GOOD_ITEM_TEXT = DELETE_GOOD_ITEM or "Are you sure you want to destroy %s?"
    TypeDeleteLine = gsub(DELETE_GOOD_ITEM_TEXT, "[\r\n]", "@")
    TypeDeleteLine = select(2, strsplit("@", TypeDeleteLine, 2))
    
    -- Add hyperlinks to regular item destroy popups (always re-assign to ensure they're set)
    -- StaticPopupDialogs should be available, but check just in case
    if not StaticPopupDialogs then
        return -- Cannot initialize without StaticPopupDialogs
    end
    
    if StaticPopupDialogs["DELETE_GOOD_ITEM"] then
        StaticPopupDialogs["DELETE_GOOD_ITEM"].OnHyperlinkEnter = function(self, link, text, region, boundsLeft, boundsBottom, boundsWidth, boundsHeight)
            GameTooltip:SetOwner(self, "ANCHOR_PRESERVE")
            GameTooltip:ClearAllPoints()
            local cursorClearance = 30
            GameTooltip:SetPoint("TOPLEFT", region, "BOTTOMLEFT", boundsLeft, boundsBottom - cursorClearance)
            GameTooltip:SetHyperlink(link)
        end
        
        StaticPopupDialogs["DELETE_GOOD_ITEM"].OnHyperlinkLeave = function(self)
            GameTooltip:Hide()
        end
    end
    
    if StaticPopupDialogs["DELETE_ITEM"] and StaticPopupDialogs["DELETE_GOOD_ITEM"] then
        StaticPopupDialogs["DELETE_ITEM"].OnHyperlinkEnter = StaticPopupDialogs["DELETE_GOOD_ITEM"].OnHyperlinkEnter
        StaticPopupDialogs["DELETE_ITEM"].OnHyperlinkLeave = StaticPopupDialogs["DELETE_GOOD_ITEM"].OnHyperlinkLeave
    end
    
    -- Hide editbox and set item link
    -- Clean up old frame if exists
    if S.easyDelFrame then
        S.easyDelFrame:UnregisterAllEvents()
        S.easyDelFrame:SetScript("OnEvent", nil)
        S.easyDelFrame:Hide()
        S.easyDelFrame = nil
    end
    
    -- Create new frame
    S.easyDelFrame = CreateFrame("Frame")
    
    S.easyDelFrame:RegisterEvent("DELETE_ITEM_CONFIRM")
    S.easyDelFrame:Show()
    S.easyDelFrame:SetScript("OnEvent", function()
        -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
        local checkDb = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
        if not checkDb or not checkDb.enabled then return end
        if not IsEasyItemDestroyEnabled() then return end
        
        -- Ensure TypeDeleteLine is set
        if not TypeDeleteLine then
            local DELETE_GOOD_ITEM_TEXT = DELETE_GOOD_ITEM or "Are you sure you want to destroy %s?"
            TypeDeleteLine = gsub(DELETE_GOOD_ITEM_TEXT, "[\r\n]", "@")
            TypeDeleteLine = select(2, strsplit("@", TypeDeleteLine, 2))
        end
        
        if StaticPopup1EditBox and StaticPopup1EditBox:IsShown() then
            -- Item requires player to type delete so hide editbox and show link
            StaticPopup1:SetHeight(StaticPopup1:GetHeight() - 10)
            StaticPopup1EditBox:Hide()
            if StaticPopup1Button1 then
                StaticPopup1Button1:Enable()
            end
            local link = select(3, GetCursorInfo())
            if link then
                local currentText = StaticPopup1Text:GetText() or ""
                local cleanText = gsub(currentText, gsub(TypeDeleteLine or "", "@", ""), "")
                StaticPopup1Text:SetText(cleanText .. "|n" .. link)
            end
        else
            -- Item does not require player to type delete so just show item link
            StaticPopup1:SetHeight(StaticPopup1:GetHeight() + 40)
            if StaticPopup1EditBox then
                StaticPopup1EditBox:Hide()
            end
            if StaticPopup1Button1 then
                StaticPopup1Button1:Enable()
            end
            local link = select(3, GetCursorInfo())
            if link then
                local currentText = StaticPopup1Text:GetText() or ""
                local cleanText = gsub(currentText, gsub(TypeDeleteLine or "", "@", ""), "")
                StaticPopup1Text:SetText(cleanText .. "|n|n" .. link)
            end
        end
    end)
    
    S.easyItemDestroyEnabled = true
end

-- Disable easy item destroy
function module:DisableEasyItemDestroy()
    if not S.easyItemDestroyEnabled then return end
    
    -- Unregister events
    if S.easyDelFrame then
        S.easyDelFrame:UnregisterAllEvents()
        S.easyDelFrame:SetScript("OnEvent", nil)
        S.easyDelFrame:Hide()
        S.easyDelFrame = nil
    end
    
    -- Clean up init frame
    if S.easyItemDestroyInitFrame then
        S.easyItemDestroyInitFrame:UnregisterAllEvents()
        S.easyItemDestroyInitFrame:SetScript("OnEvent", nil)
        S.easyItemDestroyInitFrame = nil
    end
    
    -- Clear StaticPopupDialogs handlers (optional - may not be needed, but safe to clear)
    -- Note: We don't remove them completely as other addons might use them
    -- The handlers will be re-assigned on next Enable
    
    -- Reset TypeDeleteLine
    TypeDeleteLine = nil
    
    S.easyItemDestroyEnabled = false
end

-- ============================================================================
-- Flight Times Functionality
-- ============================================================================

-- Apply flight times settings
function module:ApplyShowFlightTimes()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not db.enabled then
        -- Disable if module is disabled
        if S.flightTimesEnabled then
            self:DisableShowFlightTimes()
        end
        return
    end
    
    if db.enableShowFlightTimes == 1 then
        -- Enable if not already enabled
        if not S.flightTimesEnabled then
            self:EnableShowFlightTimes()
        end
    else
        -- Disable if enabled
        if S.flightTimesEnabled then
            self:DisableShowFlightTimes()
        end
    end
end

-- Check if flight times is enabled
local function IsFlightTimesEnabled()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not db.enabled then return false end
    return db.enableShowFlightTimes == 1
end

-- Enable flight times
function module:EnableShowFlightTimes()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not db.enabled then return end
    
    if S.flightTimesEnabled then return end -- Already enabled
    
    -- Create flight times countdown frame (similar to arena countdown)
    local FLIGHT_TIMER_FONT_SIZE = 18
    -- Same winged-boot glyph WDM uses for neutral flight nodes.
    local FLIGHT_TIMER_ICON_TEXTURE = "Interface\\AddOns\\SarychUI\\addons\\WDM\\textures\\objecticonsatlas"
    local FLIGHT_TIMER_ICON_COORDS = { 0.53418, 0.56543, 0.601562, 0.632812 }

    local function ApplyFlightTimerIcon(tex)
        if not tex then return end
        if type(WDM_GetTexturePath) == "function" then
            tex:SetTexture(WDM_GetTexturePath("objecticonsatlas"))
        else
            tex:SetTexture(FLIGHT_TIMER_ICON_TEXTURE)
        end
        tex:SetTexCoord(unpack(FLIGHT_TIMER_ICON_COORDS))
        tex:SetBlendMode("BLEND")
        tex:SetAlpha(1)
    end

    local function SyncFlightTimerChrome()
        local f = S.flightTimesFrame
        if not f or not f.text or not f.icon then return end
        local BASE_FONT, BASE_FLAGS = GameFontNormal:GetFont()
        f.text:SetFont(BASE_FONT, FLIGHT_TIMER_FONT_SIZE, BASE_FLAGS)
        local iconSz = floor(FLIGHT_TIMER_FONT_SIZE * 1.15 + 0.5)
        ApplyFlightTimerIcon(f.icon)
        f.icon:SetSize(iconSz, iconSz)
        f:SetHeight(max(iconSz + 6, 22))
        -- ширина: иконка + отступ + время (MM:SS)
        f:SetWidth(iconSz + 10 + FLIGHT_TIMER_FONT_SIZE * 4.5)
    end

    S.flightTimesFrame = CreateFrame("Frame", nil, UIParent)
    S.flightTimesFrame:SetFrameStrata("DIALOG")
    S.flightTimesFrame:SetFrameLevel(1000)
    S.flightTimesFrame:SetPoint("CENTER", 0, 240)

    local icon = S.flightTimesFrame:CreateTexture(nil, "OVERLAY")
    ApplyFlightTimerIcon(icon)
    icon:SetPoint("LEFT", S.flightTimesFrame, "LEFT", 2, 0)
    S.flightTimesFrame.icon = icon

    S.flightTimesFrame.text = S.flightTimesFrame:CreateFontString(nil, "OVERLAY")
    S.flightTimesFrame.text:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    S.flightTimesFrame.text:SetJustifyH("LEFT")
    S.flightTimesFrame.text:SetJustifyV("MIDDLE")
    S.flightTimesFrame.text:SetShadowColor(0, 0, 0, 1)
    S.flightTimesFrame.text:SetShadowOffset(1, -1)
    SyncFlightTimerChrome()
    S.flightTimesFrame:Hide()
    
    -- Flight tracker
    S.flightTimesTracker = {
        active = false,
        startTime = 0,
        duration = 0,
    }
    
    -- Set text function
    S.setFlightTimesTextFunc = function(sec)
        SyncFlightTimerChrome()
        if sec < 1 then
            S.flightTimesFrame:Hide()
            return
        end
        S.flightTimesFrame.text:SetTextColor(1, 1, 1)
        -- Format time as MM:SS
        local minutes = floor(sec / 60)
        local seconds = floor(sec % 60)
        S.flightTimesFrame.text:SetText(format(" %d:%02d ", minutes, seconds))
    end
    
    -- Stop flight times
    S.stopFlightTimesFunc = function()
        S.flightTimesTracker.active = false
        S.flightTimesTracker.startTime = 0
        S.flightTimesTracker.duration = 0
        S.flightAcc = 0  -- Reset accumulator
        S.flightIconPulsePhase = 0
        S.flightTimesFrame:Hide()
    end
    
    -- Start flight times
    S.startFlightTimesFunc = function(duration)
        if not IsFlightTimesEnabled() then return end
        if S.flightTimesTracker.active then S.stopFlightTimesFunc() end
        
        -- Reset accumulator
        S.flightAcc = 0
        S.flightIconPulsePhase = 0
        
        S.flightTimesTracker.active = true
        S.flightTimesTracker.startTime = GetTime()  -- Store start time
        S.flightTimesTracker.duration = duration or 300 -- Default 5 minutes if unknown
        
        -- Show frame and set initial text
        S.flightTimesFrame:Show()
        local minutes = floor(S.flightTimesTracker.duration / 60)
        local seconds = floor(S.flightTimesTracker.duration % 60)
        S.flightTimesFrame.text:SetTextColor(1, 1, 1)
        SyncFlightTimerChrome()
        S.flightTimesFrame.text:SetText(format(" %d:%02d ", minutes, seconds))
    end
    
    -- OnUpdate for flight times
    S.flightAcc = 0  -- Reset accumulator
    local FLIGHT_TICK = 0.02  -- Update interval (same as S.INVITE_TICK)
    local FLIGHT_ICON_PULSE_PERIOD = 2.35 -- секунды на один цикл «дыхания»
    local TWO_PI = 6.2831853071796
    S.flightTimesFrame:SetScript("OnUpdate", function(self, elapsed)
        -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
        local checkDb = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
        if not checkDb or not checkDb.enabled then 
            S.flightAcc = 0
            return 
        end
        if not S.flightTimesTracker.active then 
            S.flightAcc = 0
            return 
        end

        -- Плавная пульсация иконки распорядителя (каждый кадр, не привязано к FLIGHT_TICK)
        local ic = S.flightTimesFrame.icon
        if ic and ic:IsVisible() then
            S.flightIconPulsePhase = S.flightIconPulsePhase + elapsed
            local wave = 0.5 + 0.5 * sin(S.flightIconPulsePhase * TWO_PI / FLIGHT_ICON_PULSE_PERIOD)
            ic:SetAlpha(0.38 + wave * 0.62)
        end
        
        S.flightAcc = S.flightAcc + elapsed
        if S.flightAcc < FLIGHT_TICK then return end
        S.flightAcc = 0
        
        if not S.flightTimesTracker.active or not S.flightTimesTracker.startTime or not S.flightTimesTracker.duration then
            return
        end
        
        -- Calculate elapsed time and remaining time
        local currentTime = GetTime()
        local elapsedTime = currentTime - S.flightTimesTracker.startTime
        local remaining = S.flightTimesTracker.duration - elapsedTime
        
        -- Ensure remaining doesn't go negative
        if remaining < 0 then
            remaining = 0
        end
        
        -- Show remaining time (like Leatrix_Plus)
        -- Format as MM:SS
        local minutes = floor(remaining / 60)
        local seconds = floor(remaining % 60)
        
        -- Always update text (ensure it updates every tick)
        local timeText = format(" %d:%02d ", minutes, seconds)
        S.flightTimesFrame.text:SetTextColor(1, 1, 1)
        S.flightTimesFrame.text:SetText(timeText)
        
        -- Only stop if we're definitely not on taxi anymore (checked by S.flightCheckFrame)
    end)
    
    -- Load flight data from our own files
    local function LoadFlightDataIfNeeded()
        if S.flightDataCache then
            return S.flightDataCache
        end
        
        -- Load our own flight data. Only the player's faction is built: the other
        -- faction's routes are unreachable and cost ~500 KB of tables.
        if SarychUI and SarychUI.LoadFlightDataAlliance and SarychUI.LoadFlightDataHorde then
            if not SarychUI.FlightData then
                SarychUI.FlightData = {}
            end
            local factionGroup = UnitFactionGroup("player")
            if factionGroup == "Horde" then
                SarychUI.LoadFlightDataHorde()
            elseif factionGroup == "Alliance" then
                SarychUI.LoadFlightDataAlliance()
            else
                -- Faction unknown at this point: fall back to loading both.
                SarychUI.LoadFlightDataAlliance()
                SarychUI.LoadFlightDataHorde()
            end
            if SarychUI.FlightData then
                S.flightDataCache = SarychUI.FlightData
                return S.flightDataCache
            end
        end
        
        -- Data not available
        return nil
    end
    
    -- Helper function to get flight duration from flight data or calculate route
    local function GetFlightDuration(node)
        -- Load flight data
        local data = LoadFlightDataIfNeeded()
        
        if not data then
            return 300 -- Data not available, use default
        end
        
        if data then
            -- Get faction EXACTLY like Leatrix_Plus does (line 8015)
            local factionGroup = UnitFactionGroup("player")
            local faction = nil
            
            -- UnitFactionGroup can return "Alliance", "Horde", or nil
            -- In Wrath it usually returns the string directly
            if factionGroup == "Alliance" then
                faction = "Alliance"
            elseif factionGroup == "Horde" then
                faction = "Horde"
            else
                -- Fallback: check by race
                local _, race = UnitRace("player")
                local allianceRaces = {
                    Human = true, Dwarf = true, ["Night Elf"] = true, Gnome = true,
                    Draenei = true, Worgen = true, Pandaren = true
                }
                if allianceRaces[race] then
                    faction = "Alliance"
                else
                    faction = "Horde"
                end
            end
            
            -- Verify faction
            if not faction then
                return 300
            end
            
            local continent = GetCurrentMapContinent()
            
            -- Find current node
            for i = 1, NumTaxiNodes() do
                local nodeType = TaxiNodeGetType(i)
                if nodeType == "CURRENT" then
                    local startX, startY = TaxiNodePosition(i)
                    local currentNode = format("%0.2f", startX) .. ":" .. format("%0.2f", startY)
                    
                    -- Get destination
                    local endX, endY = TaxiNodePosition(node)
                    local destination = format("%0.2f", endX) .. ":" .. format("%0.2f", endY)
                    
                    -- Build route string EXACTLY like Leatrix_Plus does
                    local routeString = currentNode
                    local numEnterHops = GetNumRoutes(node)
                    
                    -- Add hops to route string (same order as Leatrix_Plus)
                    for hop = 1, numEnterHops do
                        local nextHopX = TaxiGetDestX(node, hop)
                        local nextHopY = TaxiGetDestY(node, hop)
                        local hopPos = format("%0.2f", nextHopX) .. ":" .. format("%0.2f", nextHopY)
                        routeString = routeString .. ":" .. hopPos
                    end
                    
                    -- Add destination if not in route (EXACTLY like Leatrix_Plus)
                    if not find(routeString, destination, 1, true) then
                        routeString = routeString .. ":" .. destination
                    end
                    
                    -- Try to get duration from data (check exact structure)
                    if data[faction] then
                        if data[faction][continent] then
                            if data[faction][continent][routeString] then
                                local duration = data[faction][continent][routeString]
                                if duration and type(duration) == "number" then
                                    return duration
                                end
                            end
                        end
                    end
                    
                    
                    break
                end
            end
        end
        
        -- Fallback: use default duration
        return 300 -- 5 minutes default
    end
    
    -- Hook TakeTaxiNode to detect flight start (like Leatrix_Plus)
    hooksecurefunc("TakeTaxiNode", function(node)
        if not IsFlightTimesEnabled() then 
            return 
        end
        
        -- Get flight duration IMMEDIATELY when TakeTaxiNode is called (like Leatrix_Plus does)
        local flightDuration = GetFlightDuration(node)
        
        -- Record the moment TakeTaxiNode was clicked
        local timeStart = GetTime()
        
        -- Use a ticker to detect when player actually takes off (UnitOnTaxi becomes true)
        local ticker
        local seenAirborne = false
        local timeSinceStart = 0
        local MAX_START_DELAY = 5 -- Give up start check after 5s
        
        ticker = CreateFrame("Frame")
        ticker:Hide()
        local tickerAcc = 0
        ticker:SetScript("OnUpdate", function(self, elapsed)
            if not IsFlightTimesEnabled() then
                self:Hide()
                return
            end
            
            tickerAcc = tickerAcc + elapsed
            if tickerAcc < 0.1 then return end
            tickerAcc = 0
            timeSinceStart = timeSinceStart + 0.1
            
            -- 1) If we never got airborne within MAX_START_DELAY → cancel watcher
            if not seenAirborne and timeSinceStart > MAX_START_DELAY then
                self:Hide()
                ticker = nil
                return
            end
            
            -- 2) Detect actual takeoff
            if UnitOnTaxi("player") then
                seenAirborne = true
                -- Flight started - start timer with the duration we got at TakeTaxiNode
                S.startFlightTimesFunc(flightDuration)
                self:Hide()
                ticker = nil
                return
            end
            
            -- 3) After having been airborne, first false → real landing
            if seenAirborne then
                self:Hide()
                S.stopFlightTimesFunc()
                ticker = nil
            end
        end)
        ticker:Show()
    end)
    
    -- Hook TaxiMap to detect when map is opened (cancel timer)
    hooksecurefunc("TaxiNodeOnButtonEnter", function()
        if not IsFlightTimesEnabled() then return end
        S.stopFlightTimesFunc()
    end)
    
    -- Periodic landing check (via Runtime dispatcher when available)
    local function FlightCheckTick()
        if not IsFlightTimesEnabled() then return end
        if not S.flightTimesTracker or not S.flightTimesTracker.active then return end
        if not UnitOnTaxi("player") then
            if S.stopFlightTimesFunc then
                S.stopFlightTimesFunc()
            end
        end
    end
    if SarychUI and SarychUI.Runtime and SarychUI.Runtime.RegisterUpdate then
        SarychUI.Runtime:RegisterUpdate("tools.flightCheck", 0.5, FlightCheckTick)
        S.flightCheckUsesRuntime = true
        S.flightCheckFrame = nil
    else
        S.flightCheckFrame = CreateFrame("Frame")
        S.flightCheckFrame:Hide()
        local flightCheckAcc = 0
        S.flightCheckFrame:SetScript("OnUpdate", function(self, elapsed)
            if not IsFlightTimesEnabled() then return end
            if not S.flightTimesTracker.active then return end
            flightCheckAcc = flightCheckAcc + elapsed
            if flightCheckAcc < 0.5 then return end
            flightCheckAcc = 0
            if not UnitOnTaxi("player") then
                S.stopFlightTimesFunc()
            end
        end)
        S.flightCheckFrame:Show()
        S.flightCheckUsesRuntime = false
    end
    
    S.flightTimesEnabled = true
end

-- Disable flight times
function module:DisableShowFlightTimes()
    if not S.flightTimesEnabled then return end
    
    -- Hide frame
    if S.flightTimesFrame then
        S.flightTimesFrame:Hide()
        S.flightTimesFrame:SetScript("OnUpdate", nil)
    end
    
    -- Hide check frame / unregister runtime callback
    if S.flightCheckUsesRuntime and SarychUI and SarychUI.Runtime and SarychUI.Runtime.UnregisterUpdate then
        SarychUI.Runtime:UnregisterUpdate("tools.flightCheck")
        S.flightCheckUsesRuntime = false
    end
    if S.flightCheckFrame then
        S.flightCheckFrame:Hide()
        S.flightCheckFrame:SetScript("OnUpdate", nil)
    end
    
    -- Reset tracker and functions
    S.flightTimesTracker = {
        active = false,
        startTime = 0,
        duration = 0,
    }
    S.startFlightTimesFunc = nil
    S.stopFlightTimesFunc = nil
    S.setFlightTimesTextFunc = nil
    
    S.flightTimesEnabled = false
end

-- Apply tooltip cursor settings
function module:ApplyTooltipCursor()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not db.enabled then
        -- Disable if module is disabled
        if S.tooltipCursorHooked then
            self:DisableTooltipCursor()
        end
        return
    end
    
    if db.enableTooltipCursor == 1 then
        -- Enable if not already enabled
        if not S.tooltipCursorHooked then
            self:EnableTooltipCursor()
        end
    else
        -- Disable if enabled
        if S.tooltipCursorHooked then
            self:DisableTooltipCursor()
        end
    end
end

-- Tooltip cursor Alt state callback
local function TooltipCursorAltCallback(isAltPressed)
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not db.enabled then return end
    if db.enableTooltipCursor ~= 1 then return end
    if db.tooltipCursorAltOnly ~= 1 then return end
    
    S.tooltipCursorAltPressed = isAltPressed
    
    if GameTooltip and GameTooltip:IsShown() then
        if isAltPressed then
            RebuildTooltip("cursor")
        else
            RebuildTooltip("default")
        end
    end
end

-- Enable tooltip cursor
function module:EnableTooltipCursor()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not db.enabled then return end
    
    if S.tooltipCursorHooked then return end -- Already enabled
    
    -- Register Alt mode callback
    if SarychUI.AltMode then
        SarychUI.AltMode:RegisterCallback("tooltipCursor", TooltipCursorAltCallback)
        S.tooltipCursorAltPressed = SarychUI.AltMode:IsAltPressed() or false
    end
    
    S.tooltipCursorAnchored = false
    
    -- Hook GameTooltip:FadeOut for instant hide
    hooksecurefunc(GameTooltip, "FadeOut", function(self)
        -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
        local checkDb = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
        if not checkDb or not checkDb.enabled then return end
        if checkDb.enableTooltipCursor ~= 1 then return end
        
        self:SetAlpha(1)
        self:Hide()
    end)
    
    -- Hook GameTooltip_SetDefaultAnchor for cursor anchoring
    hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tt, parent)
        -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
        local checkDb = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
        if not checkDb or not checkDb.enabled then return end
        if checkDb.enableTooltipCursor ~= 1 then return end
        if GetMouseFocus() ~= WorldFrame then return end
        
        if checkDb.tooltipCursorAltOnly == 1 and not S.tooltipCursorAltPressed then
            S.tooltipCursorAnchored = false
            return
        end
        
        tt:SetOwner(parent or UIParent, "ANCHOR_CURSOR")
        S.tooltipCursorAnchored = true
    end)
    
    -- Hook GameTooltip:OnHide to reset flag
    if GameTooltip and GameTooltip.HookScript then
        GameTooltip:HookScript("OnHide", function()
            S.tooltipCursorAnchored = false
        end)
    end
    
    S.tooltipCursorHooked = true
end

-- Disable tooltip cursor
function module:DisableTooltipCursor()
    if not S.tooltipCursorHooked then return end
    
    -- Unregister Alt mode callback
    if SarychUI.AltMode then
        SarychUI.AltMode:UnregisterCallback("tooltipCursor")
    end
    
    -- We can't unhook hooksecurefunc, but we can reset the flag
    S.tooltipCursorAnchored = false
    S.tooltipCursorAltPressed = false
    
    -- Unregister events and clear scripts (legacy, no longer needed but kept for cleanup)
    if S.tooltipCursorEventFrame then
        S.tooltipCursorEventFrame:UnregisterAllEvents()
        S.tooltipCursorEventFrame:SetScript("OnEvent", nil)
        S.tooltipCursorEventFrame = nil
    end
    
    S.tooltipCursorHooked = false
end

-- ============================================================================
-- Castbar Timer Functionality
-- ============================================================================

-- Create casting bar timer
local function CreateCastingBarTimer(parentFrame, offsetX, offsetY, fontSize)
    if not parentFrame then return nil end
    local timer = parentFrame:CreateFontString(nil, "OVERLAY")
    timer:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "")
    timer:SetShadowOffset(1, -1)
    timer:SetShadowColor(0, 0, 0, 1)
    timer:SetPoint("CENTER", parentFrame, "CENTER", offsetX, offsetY)
    timer:SetAlpha(1)
    return timer
end

-- Update casting bar timer
local function UpdateCastingBar(self, elapsed)
    if not self.timer then return end
    
    -- Settings live under «Текст перезарядки» (cc).
    local db = TimersDB()
    if not db or not db.enabled then
        self.timer:SetText("")
        return
    end
    
    -- Check if castbar timer is enabled for this bar
    local function IsCastbarEnabled(bar)
        if db.enableCastbarTimers ~= 1 then return false end
        if bar == CastingBarFrame then
            return db.enableCastbarPlayer == 1
        elseif bar == TargetFrameSpellBar then
            return db.enableCastbarTarget == 1
        elseif bar == FocusFrameSpellBar then
            return db.enableCastbarFocus == 1
        end
        return true
    end
    
    if not IsCastbarEnabled(self) then
        self.timer:SetText("")
        return
    end

    -- Update interval check
    if not self.updateInterval then
        self.updateInterval = 0.1
    end
    self.updateInterval = self.updateInterval - elapsed
    if self.updateInterval > 0 then return end
    self.updateInterval = 0.1

    -- Update timer text
    if self.casting then
        local timeLeft = max(self.maxValue - self.value, 0)
        if self == CastingBarFrame then
            self.timer:SetText(format(" %2.1f / %1.1f ", timeLeft, self.maxValue))
        else
            self.timer:SetText(format(" %.1f ", timeLeft))
        end
    elseif self.channeling then
        local timeLeft = max(self.value, 0)
        self.timer:SetText(format(" %.1f ", timeLeft))
    else
        self.timer:SetText("")
    end
end

-- Apply castbar timer settings
function module:ApplyCastbarTimers()
    local db = TimersDB()
    if not db or not db.enabled then
        -- Disable if module is disabled
        if S.castbarTimersHooked then
            self:DisableCastbarTimers()
        end
        return
    end
    
    if db.enableCastbarTimers == 1 then
        -- Enable if not already enabled
        if not S.castbarTimersHooked then
            self:EnableCastbarTimers()
        end
    else
        -- Disable if enabled
        if S.castbarTimersHooked then
            self:DisableCastbarTimers()
        end
    end
end

-- Enable castbar timers
function module:EnableCastbarTimers()
    local db = TimersDB()
    if not db or not db.enabled then return end
    
    -- Create timers for castbars if they don't exist
    if CastingBarFrame then
        if not CastingBarFrame.timer then
            CastingBarFrame.timer = CreateCastingBarTimer(CastingBarFrame, 0, -20, 13)
        else
            -- Show timer if it exists but is hidden
            CastingBarFrame.timer:Show()
        end
        if not CastingBarFrame.updateInterval then
            CastingBarFrame.updateInterval = 0.1
        end
        -- Hook OnUpdate if not already hooked
        if not S.castbarTimersHooked then
            CastingBarFrame:HookScript("OnUpdate", UpdateCastingBar)
        end
    end
    
    if TargetFrameSpellBar then
        if not TargetFrameSpellBar.timer then
            TargetFrameSpellBar.timer = CreateCastingBarTimer(TargetFrameSpellBar, 92, 0, 12)
        else
            -- Show timer if it exists but is hidden
            TargetFrameSpellBar.timer:Show()
        end
        if not TargetFrameSpellBar.updateInterval then
            TargetFrameSpellBar.updateInterval = 0.1
        end
        -- Hook OnUpdate if not already hooked
        if not S.castbarTimersHooked then
            TargetFrameSpellBar:HookScript("OnUpdate", UpdateCastingBar)
        end
    end
    
    if FocusFrameSpellBar then
        if not FocusFrameSpellBar.timer then
            FocusFrameSpellBar.timer = CreateCastingBarTimer(FocusFrameSpellBar, 92, 0, 12)
        else
            -- Show timer if it exists but is hidden
            FocusFrameSpellBar.timer:Show()
        end
        if not FocusFrameSpellBar.updateInterval then
            FocusFrameSpellBar.updateInterval = 0.1
        end
        -- Hook OnUpdate if not already hooked
        if not S.castbarTimersHooked then
            FocusFrameSpellBar:HookScript("OnUpdate", UpdateCastingBar)
        end
    end
    
    S.castbarTimersHooked = true
end

-- Disable castbar timers
function module:DisableCastbarTimers()
    if not S.castbarTimersHooked then return end
    
    -- We can't unhook HookScript, but we can hide timers and clear text
    if CastingBarFrame and CastingBarFrame.timer then
        CastingBarFrame.timer:SetText("")
        CastingBarFrame.timer:Hide()
    end
    if TargetFrameSpellBar and TargetFrameSpellBar.timer then
        TargetFrameSpellBar.timer:SetText("")
        TargetFrameSpellBar.timer:Hide()
    end
    if FocusFrameSpellBar and FocusFrameSpellBar.timer then
        FocusFrameSpellBar.timer:SetText("")
        FocusFrameSpellBar.timer:Hide()
    end
    
    S.castbarTimersHooked = false
end

-- ============================================================================
-- Invite Countdown Functionality
-- ============================================================================

-- Constants
S.INVITE_TICK, S.INVITE_FONT_SIZE = 0.02, 14
S.INVITE_DEFAULTS = {
    PVP   = 59.5,   -- БГ/Арена
    LFG   = 46.2,   -- ПП
    PARTY = 60.5,   -- Пати-инвайт
}

-- Helper functions
local function GetInviteFontSize(fs, size)
    local BASE_FONT, BASE_FLAGS = GameFontNormal:GetFont()
    fs:SetFont(BASE_FONT, size, BASE_FLAGS)
end

-- Check if invite countdown is enabled
local function IsInviteCountdownEnabled()
    local db = TimersDB()
    if not db or not db.enabled then return false end
    return db.enableInviteCountdown == 1
end

-- Get duration for invite type
local function GetInviteDuration(kind)
    return S.INVITE_DEFAULTS[kind] or 30
end

-- Get popup buttons
local function GetInvitePopupButtons(frame)
    if not frame then return nil, nil end
    local b1 = frame.button1 or frame.Button1 or frame.AcceptButton
    local b2 = frame.button2 or frame.Button2 or frame.CancelButton
    b1 = b1 or frame.enterButton or frame.EnterDungeonButton
    b2 = b2 or frame.leaveButton or frame.LeaveQueueButton
    local fname = frame.GetName and frame:GetName()
    if not b1 and fname then
        b1 = _G[fname.."EnterDungeonButton"] or _G[fname.."EnterButton"] or _G[fname.."AcceptButton"]
    end
    if not b2 and fname then
        b2 = _G[fname.."LeaveQueueButton"] or _G[fname.."LeaveButton"] or _G[fname.."CancelButton"]
    end
    b1 = b1 or _G["LFDDungeonReadyDialogEnterDungeonButton"]
    b2 = b2 or _G["LFDDungeonReadyDialogLeaveQueueButton"] or _G["LFDDungeonReadyDialogCancelButton"]
    return b1, b2
end

-- Helper functions for invite countdown
local function InviteLFGDialog()
    return _G["LFGDungeonReadyDialog"] or _G["LFDDungeonReadyDialog"] or _G["LFDDungeonReadyPopup"]
end

local function InvitePartyPopupShown()
    for i=1,4 do
        local p = _G["StaticPopup"..i]
        if p and p:IsShown() and p.which == "PARTY_INVITE" then return p end
    end
end

local function InvitePVPConfirmPopupShown()
    for i=1,4 do
        local p = _G["StaticPopup"..i]
        if p and p:IsShown() and (p.which == "CONFIRM_BATTLEFIELD_ENTRY" or p.which == "CONFIRM_ARENA_ENTRY") then
            return p
        end
    end
end

-- Apply invite countdown settings
function module:ApplyInviteCountdown()
    local db = TimersDB()
    if not db or not db.enabled then
        -- Disable if module is disabled
        if S.inviteCountdownInitialized then
            self:DisableInviteCountdown()
        end
        return
    end
    
    if db.enableInviteCountdown == 1 then
        -- Enable if not already enabled
        if not S.inviteCountdownInitialized then
            self:EnableInviteCountdown()
        end
        
        -- Если сейчас уже открыт подходящий попап/диалог — запустить таймеры сразу
        if S.inviteCountdownInitialized then
            local dlg = InviteLFGDialog()
            if dlg and S.popupTimer and not S.popupTimer.active then
                S.startInvitePopupTimer(dlg, GetInviteDuration("LFG") or 30)
            end
            
            local pp = InvitePartyPopupShown()
            if pp and S.inviteTrackers and S.inviteTrackers.PARTY and not S.inviteTrackers.PARTY.active then
                S.startInviteTracker(S.inviteTrackers.PARTY, pp)
            end
            
            local pvp = InvitePVPConfirmPopupShown()
            if pvp and S.popupTimer and not S.popupTimer.active then
                S.startInvitePopupTimer(pvp, 59.5)
            end
        end
    else
        -- Disable if enabled
        if S.inviteCountdownInitialized then
            self:DisableInviteCountdown()
        end
    end
end

-- Enable invite countdown
function module:EnableInviteCountdown()
    local db = TimersDB()
    if not db or not db.enabled then return end
    
    if S.inviteCountdownInitialized then return end -- Already enabled
    
    -- Create main countdown frame
    S.inviteCountdownFrame = CreateFrame("Frame", nil, UIParent)
    S.inviteCountdownFrame:SetSize(110, 24)
    S.inviteCountdownFrame:SetFrameStrata("DIALOG")
    S.inviteCountdownFrame:SetFrameLevel(1000)
    S.inviteCountdownFrame.text = S.inviteCountdownFrame:CreateFontString(nil, "OVERLAY")
    GetInviteFontSize(S.inviteCountdownFrame.text, S.INVITE_FONT_SIZE)
    S.inviteCountdownFrame.text:SetAllPoints()
    S.inviteCountdownFrame.text:SetShadowColor(0, 0, 0, 1)
    S.inviteCountdownFrame.text:SetShadowOffset(1, -1)
    S.inviteCountdownFrame:Hide()
    
    -- Trackers for different invite types
    S.inviteTrackers = {}
    local function NewTracker(kind)
        return {
            kind = kind,
            active = false,
            showAt = 0,
            deadline = 0,
            anchor = nil,
            userClicked = false,
        }
    end
    S.inviteTrackers.PVP = NewTracker("PVP")
    S.inviteTrackers.LFG = NewTracker("LFG")
    S.inviteTrackers.PARTY = NewTracker("PARTY")
    
    S.pvpFirstTrigger = 0
    
    -- Popup timer
    S.popupTimer = {
        active = false,
        popup = nil,
        deadline = 0,
        originalText1 = "",
        originalText2 = ""
    }
    
    -- Anchor function
    S.anchorInviteUnder = function(frame)
        local a = frame or UIParent
        S.inviteCountdownFrame:ClearAllPoints()
        S.inviteCountdownFrame:SetPoint("TOP", a, "BOTTOM", 0, -6)
    end
    
    -- Set text function
    S.setInviteSmartText = function(sec)
        GetInviteFontSize(S.inviteCountdownFrame.text, S.INVITE_FONT_SIZE)
        if sec < 1 then
            S.inviteCountdownFrame:Hide()
            return
        end
        S.inviteCountdownFrame.text:SetTextColor(1, 1, 1)
        S.inviteCountdownFrame.text:SetText(format(" %d ", floor(sec + 0.5)))
    end
    
    -- Start tracker
    S.startInviteTracker = function(tr, anchorFrame)
        if not IsInviteCountdownEnabled() then return end
        tr.active = true
        tr.userClicked = false
        tr.showAt = GetTime()
        tr.deadline = tr.showAt + (GetInviteDuration(tr.kind) or 30)
        tr.anchor = anchorFrame
        S.anchorInviteUnder(tr.anchor)
        S.inviteCountdownFrame:Show()
    end
    
    -- Stop tracker
    S.stopInviteTracker = function(tr)
        tr.active = false
        tr.showAt, tr.deadline, tr.anchor = 0, 0, nil
        if not (S.inviteTrackers.PVP.active or S.inviteTrackers.LFG.active or S.inviteTrackers.PARTY.active) then
            S.inviteCountdownFrame:Hide()
        end
    end
    
    -- Start popup timer
    S.startInvitePopupTimer = function(popup, duration)
        if not IsInviteCountdownEnabled() then return end
        if not popup then return end
        
        -- Если таймер уже активен для этого попапа, сначала останавливаем его
        if S.popupTimer.active and S.popupTimer.popup == popup then
            S.stopInvitePopupTimer()
        end
        
        local button1, button2 = GetInvitePopupButtons(popup)
        if button1 then
            -- Получаем текущий текст кнопки
            local currentText = button1:GetText() or ""
            
            -- Очищаем текст от предыдущего таймера (формат: "текст (число)")
            -- Удаляем паттерн " (число)" в конце строки
            local cleanText = currentText:gsub("%s*%(%d+%)%s*$", "")
            
            -- Сохраняем очищенный оригинальный текст
            S.popupTimer.active = true
            S.popupTimer.popup = popup
            S.popupTimer.deadline = GetTime() + duration
            S.popupTimer.originalText1 = cleanText
            S.popupTimer.originalText2 = button2 and (button2:GetText() or ""):gsub("%s*%(%d+%)%s*$", "") or ""
            
            -- Восстанавливаем очищенный текст на кнопке
            button1:SetText(cleanText)
            
            if S.inviteCountdownPopupTimerFrame then
                S.inviteCountdownPopupTimerFrame:Show()
            end
        end
    end
    
    -- Stop popup timer
    S.stopInvitePopupTimer = function()
        if S.popupTimer.active and S.popupTimer.popup then
            local button1 = GetInvitePopupButtons(S.popupTimer.popup)
            if button1 and S.popupTimer.originalText1 then
                button1:SetText(S.popupTimer.originalText1)
            end
        end
        S.popupTimer.active = false
        S.popupTimer.popup = nil
        S.popupTimer.deadline = 0
        S.popupTimer.originalText1 = ""
        S.popupTimer.originalText2 = ""
        if S.inviteCountdownPopupTimerFrame then
            S.inviteCountdownPopupTimerFrame:Hide()
        end
    end
    
    -- Update popup timer
    S.updateInvitePopupTimer = function()
        if not S.popupTimer.active or not S.popupTimer.popup then return end
        local left = S.popupTimer.deadline - GetTime()
        if left <= 0 then
            S.stopInvitePopupTimer()
            return
        end
        local seconds = floor(left + 0.5)
        local button1 = GetInvitePopupButtons(S.popupTimer.popup)
        if button1 and S.popupTimer.originalText1 then
            button1:SetText(S.popupTimer.originalText1 .. " (" .. seconds .. ")")
        end
    end
    
    -- Create popup timer frame
    S.inviteCountdownPopupTimerFrame = CreateFrame("Frame")
    S.inviteCountdownPopupTimerFrame:Hide()
    local pfAcc = 0
    S.inviteCountdownPopupTimerFrame:SetScript("OnUpdate", function(self, elapsed)
        -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
        if not IsInviteCountdownEnabled() then return end
        
        pfAcc = pfAcc + elapsed
        if pfAcc < S.INVITE_TICK then return end
        pfAcc = 0
        S.updateInvitePopupTimer()
    end)
    
    -- Hook popup buttons
    S.hookInvitePopupButtons = function(popup, tr)
        for i=1,3 do
            local btn = popup["button"..i]
            if btn and btn.HookScript and not btn.__ic_hooked then
                btn.__ic_hooked = true
                btn:HookScript("OnClick", function() tr.userClicked = true end)
            end
        end
    end
    
    -- Main OnUpdate
    local acc = 0
    S.inviteCountdownFrame:SetScript("OnUpdate", function(self, elapsed)
        -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
        if not IsInviteCountdownEnabled() then return end
        
        acc = acc + elapsed
        if acc < S.INVITE_TICK then return end
        acc = 0
        
        S.updateInvitePopupTimer()
        
        local order = {"LFG", "PVP", "PARTY"}
        local drawn = false
        
        for _,k in ipairs(order) do
            local tr = S.inviteTrackers[k]
            if tr.active then
                if tr.anchor and tr.anchor.IsShown and tr.anchor:IsShown() then
                    S.anchorInviteUnder(tr.anchor)
                end
                local left = tr.deadline - GetTime()
                if left <= 0 then
                    S.stopInviteTracker(tr)
                else
                    S.setInviteSmartText(left)
                    drawn = true
                    break
                end
            end
        end
        
        if not drawn and not (S.inviteTrackers.PVP.active or S.inviteTrackers.LFG.active or S.inviteTrackers.PARTY.active) then
            S.inviteCountdownFrame:Hide()
        end
    end)
    
    -- Hook StaticPopups function
    local function HookStaticPopups()
        for i=1,4 do
            local p = _G["StaticPopup"..i]
            if p and not p.__ic_hooked then
                p.__ic_hooked = true
                p:HookScript("OnShow", function(self)
                    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
                    if not IsInviteCountdownEnabled() then return end
                    
                    if self.which == "PARTY_INVITE" then
                        S.hookInvitePopupButtons(self, S.inviteTrackers.PARTY)
                        S.startInviteTracker(S.inviteTrackers.PARTY, self)
                    elseif self.which == "CONFIRM_BATTLEFIELD_ENTRY" or self.which == "CONFIRM_ARENA_ENTRY" then
                        S.hookInvitePopupButtons(self, S.inviteTrackers.PVP)
                        local currentTime = GetTime()
                        if S.pvpFirstTrigger == 0 then
                            S.pvpFirstTrigger = currentTime
                            S.startInvitePopupTimer(self, 59.5)
                        elseif currentTime - S.pvpFirstTrigger < 30 then
                            S.startInvitePopupTimer(self, 39.5)
                        else
                            S.pvpFirstTrigger = currentTime
                            S.startInvitePopupTimer(self, 59.5)
                        end
                    end
                end)
                p:HookScript("OnHide", function(self)
                    if not IsInviteCountdownEnabled() then return end
                    
                    if self.which == "PARTY_INVITE" then
                        S.stopInviteTracker(S.inviteTrackers.PARTY)
                    elseif self.which == "CONFIRM_BATTLEFIELD_ENTRY" or self.which == "CONFIRM_ARENA_ENTRY" then
                        S.stopInviteTracker(S.inviteTrackers.PVP)
                        S.stopInvitePopupTimer()
                    end
                end)
            end
        end
    end
    
    -- Hook popups immediately if already logged in
    HookStaticPopups()
    
    -- Event frame
    S.inviteCountdownEventFrame = CreateFrame("Frame")
    S.inviteCountdownEventFrame:RegisterEvent("PLAYER_LOGIN")
    S.inviteCountdownEventFrame:RegisterEvent("LFG_PROPOSAL_SHOW")
    S.inviteCountdownEventFrame:RegisterEvent("LFG_PROPOSAL_SUCCEEDED")
    S.inviteCountdownEventFrame:RegisterEvent("LFG_PROPOSAL_FAILED")
    S.inviteCountdownEventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    S.inviteCountdownEventFrame:RegisterEvent("PARTY_INVITE_REQUEST")
    S.inviteCountdownEventFrame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
    
    S.inviteCountdownEventFrame:SetScript("OnEvent", function(self, event)
        -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
        if not IsInviteCountdownEnabled() then return end
        
        if event == "PLAYER_LOGIN" then
            -- Hook popups when player logs in
            HookStaticPopups()
        elseif event == "LFG_PROPOSAL_SHOW" then
            local dlg = InviteLFGDialog()
            if dlg then
                if S.inviteTrackers.LFG.active then S.stopInviteTracker(S.inviteTrackers.LFG) end
                S.startInvitePopupTimer(dlg, GetInviteDuration("LFG") or 30)
            end
        elseif event == "LFG_PROPOSAL_SUCCEEDED" or event == "LFG_PROPOSAL_FAILED" then
            S.stopInvitePopupTimer()
        elseif event == "PARTY_INVITE_REQUEST" or event == "GROUP_ROSTER_UPDATE" then
            local p = InvitePartyPopupShown()
            if p then
                if S.inviteTrackers.PARTY.active then S.stopInviteTracker(S.inviteTrackers.PARTY) end
                S.startInviteTracker(S.inviteTrackers.PARTY, p)
            end
        end
    end)
    
    S.inviteCountdownInitialized = true
end

-- Disable invite countdown
function module:DisableInviteCountdown()
    if not S.inviteCountdownInitialized then return end
    
    -- Hide frame
    if S.inviteCountdownFrame then
        S.inviteCountdownFrame:Hide()
        S.inviteCountdownFrame:SetScript("OnUpdate", nil)
    end
    
    -- Stop popup timer
    if S.inviteCountdownPopupTimerFrame then
        S.inviteCountdownPopupTimerFrame:Hide()
        S.inviteCountdownPopupTimerFrame:SetScript("OnUpdate", nil)
    end
    
    -- Restore popup button texts
    if S.popupTimer and S.popupTimer.popup then
        local button1 = GetInvitePopupButtons(S.popupTimer.popup)
        if button1 and S.popupTimer.originalText1 then
            button1:SetText(S.popupTimer.originalText1)
        end
    end
    
    -- Unregister events
    if S.inviteCountdownEventFrame then
        S.inviteCountdownEventFrame:UnregisterAllEvents()
        S.inviteCountdownEventFrame:SetScript("OnEvent", nil)
    end
    
    -- Reset trackers and functions
    S.inviteTrackers = nil
    S.pvpFirstTrigger = 0
    S.popupTimer = nil
    S.startInviteTracker = nil
    S.stopInviteTracker = nil
    S.startInvitePopupTimer = nil
    S.stopInvitePopupTimer = nil
    S.updateInvitePopupTimer = nil
    S.anchorInviteUnder = nil
    S.setInviteSmartText = nil
    S.hookInvitePopupButtons = nil
    
    S.inviteCountdownInitialized = false
end

-- ============================================================================
-- Arena Countdown Functionality
-- ============================================================================

-- Check if arena countdown is enabled
local function IsArenaCountdownEnabled()
    local db = TimersDB()
    if not db or not db.enabled then return false end
    return db.enableArenaCountdown == 1
end

-- Apply arena countdown settings
function module:ApplyArenaCountdown()
    local db = TimersDB()
    if not db or not db.enabled then
        -- Disable if module is disabled
        if arenaCountdownInitialized then
            self:DisableArenaCountdown()
        end
        return
    end
    
    if db.enableArenaCountdown == 1 then
        -- Enable if not already enabled
        if not arenaCountdownInitialized then
            self:EnableArenaCountdown()
        end
    else
        -- Disable if enabled
        if arenaCountdownInitialized then
            self:DisableArenaCountdown()
        end
    end
end

-- Enable arena countdown
function module:EnableArenaCountdown()
    local db = TimersDB()
    if not db or not db.enabled then return end
    
    if arenaCountdownInitialized then return end -- Already enabled
    
    -- Create arena countdown frame
    S.arenaCountdownFrame = CreateFrame("Frame", nil, UIParent)
    S.arenaCountdownFrame:SetSize(110, 24)
    S.arenaCountdownFrame:SetFrameStrata("DIALOG")
    S.arenaCountdownFrame:SetFrameLevel(1000)
    S.arenaCountdownFrame:SetPoint("CENTER", 0, 240)
    S.arenaCountdownFrame.text = S.arenaCountdownFrame:CreateFontString(nil, "OVERLAY")
    GetInviteFontSize(S.arenaCountdownFrame.text, 18)
    S.arenaCountdownFrame.text:SetAllPoints()
    S.arenaCountdownFrame.text:SetShadowColor(0, 0, 0, 1)
    S.arenaCountdownFrame.text:SetShadowOffset(1, -1)
    S.arenaCountdownFrame:Hide()
    
    -- Arena tracker
    S.arenaTracker = {
        active = false,
        deadline = 0,
    }
    
    -- Set text function
    S.setArenaSmartTextFunc = function(sec)
        GetInviteFontSize(S.arenaCountdownFrame.text, 18)
        if sec < 1 then
            S.arenaCountdownFrame:Hide()
            return
        end
        S.arenaCountdownFrame.text:SetTextColor(1, 1, 1)
        S.arenaCountdownFrame.text:SetText(format(" %d ", floor(sec + 0.5)))
    end
    
    -- Stop arena countdown
    S.stopArenaCountdownFunc = function()
        S.arenaTracker.active = false
        S.arenaTracker.deadline = 0
        S.arenaCountdownFrame:Hide()
    end
    
    -- Start arena countdown
    S.startArenaCountdownFunc = function(duration)
        if not IsArenaCountdownEnabled() then return end
        if S.arenaTracker.active then S.stopArenaCountdownFunc() end
        S.arenaTracker.active = true
        -- Если duration не указан, используем 15 секунд (для арены)
        duration = duration or 14.9
        S.arenaTracker.deadline = GetTime() + duration
        S.arenaCountdownFrame:Show()
    end
    
    -- OnUpdate for arena
    local arenaAcc = 0
    S.arenaCountdownFrame:SetScript("OnUpdate", function(self, elapsed)
        -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
        if not IsArenaCountdownEnabled() then return end
        if not S.arenaTracker.active then return end
        
        arenaAcc = arenaAcc + elapsed
        if arenaAcc < S.INVITE_TICK then return end
        arenaAcc = 0
        
        local left = S.arenaTracker.deadline - GetTime()
        if left <= 0 then
            S.stopArenaCountdownFunc()
        else
            S.setArenaSmartTextFunc(left)
        end
    end)
    
    -- Event frame for arena / BG countdown (locale-aware message matching)
    local countdownPatternsByLocale = {
        enUS = {
            arena15 = "Fifteen seconds until the Arena battle begins!",
            battlePrefix = "The battle begins",
            minutes = "in (%d+) minute",
            seconds = "in (%d+) second",
            oneMinute = "in 1 minute",
            begun = {
                "The battle has begun",
                "The Arena battle has begun",
            },
        },
        ruRU = {
            arena15 = "Пятнадцать секунд до начала боя на арене!",
            battlePrefix = "Битва начнется",
            minutes = "через (%d+) минут",
            seconds = "через (%d+) секунд",
            oneMinute = "через минуту",
            begun = {
                "Битва началась!",
                "Битва началась",
            },
        },
    }
    local function GetCountdownPatterns()
        local locale = GetLocale and GetLocale() or "enUS"
        return countdownPatternsByLocale[locale] or countdownPatternsByLocale.enUS
    end

    S.arenaCountdownEventFrame = CreateFrame("Frame")
    S.arenaCountdownEventFrame:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
    S.arenaCountdownEventFrame:SetScript("OnEvent", function(self, event, message)
        -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
        if not IsArenaCountdownEnabled() then return end
        if event ~= "CHAT_MSG_BG_SYSTEM_NEUTRAL" or type(message) ~= "string" then return end

        local p = GetCountdownPatterns()

        if message:find(p.arena15, 1, true) then
            S.startArenaCountdownFunc(14.9)
            return
        end

        if message:find(p.battlePrefix, 1, true) then
            local minutes = message:match(p.minutes)
            local seconds = message:match(p.seconds)
            if minutes then
                local min = tonumber(minutes) or 1
                S.startArenaCountdownFunc(min * 60 - 0.1)
            elseif seconds then
                local sec = tonumber(seconds) or 30
                S.startArenaCountdownFunc(sec - 0.1)
            elseif message:find(p.oneMinute, 1, true) then
                S.startArenaCountdownFunc(59.9)
            end
            return
        end

        for _, begunPat in ipairs(p.begun) do
            if message:find(begunPat, 1, true) then
                S.stopArenaCountdownFunc()
                return
            end
        end
    end)
    
    arenaCountdownInitialized = true
end

-- Disable arena countdown
function module:DisableArenaCountdown()
    if not arenaCountdownInitialized then return end
    
    -- Hide frame
    if S.arenaCountdownFrame then
        S.arenaCountdownFrame:Hide()
        S.arenaCountdownFrame:SetScript("OnUpdate", nil)
    end
    
    -- Unregister events
    if S.arenaCountdownEventFrame then
        S.arenaCountdownEventFrame:UnregisterAllEvents()
        S.arenaCountdownEventFrame:SetScript("OnEvent", nil)
    end
    
    -- Reset tracker and functions
    S.arenaTracker = nil
    S.startArenaCountdownFunc = nil
    S.stopArenaCountdownFunc = nil
    S.setArenaSmartTextFunc = nil
    
    arenaCountdownInitialized = false
end

-- ============================================================================
-- Arena Pointer Functionality (Arena Points in Parentheses)
-- ============================================================================

-- Arena Pointer variables
S.arenaPointerInitialized, S.arenaPointerTeams, S.arenaPointerInspectTeams = false, {}, {}
S.arenaPointerMeasureFont, S.arenaPointerInspectMeasureFont = nil, nil
S.old_PVPTeam_Update, S.old_InspectPVPTeam_Update = nil, nil
S.originalLabelPositions, S.originalInspectLabelPositions = {}, {}

-- Get arena points calculation function
local function getArenaPoints(rating, teamsize)
    local ratios = {
        [2] = 0.76,
        [3] = 0.88,
        [5] = 1,
    }
    local points
    if rating > 1500 then 
        points = 1511.26 / (1 + 1639.28 * exp(-0.00412 * rating))
    else
        points = 0.22 * rating + 14
    end
    return floor(0.5 + points * ratios[teamsize])
end

-- Check if Arena Pointer is enabled
local function IsArenaPointerEnabled()
    local db = DB()
    if not db then return false end
    return db.enableArenaPointer == 1
end

-- Apply Arena Pointer settings
function module:ApplyArenaPointer()
    local db = DB()
    if not db then return end
    
    -- Check if module is enabled
    local moduleDb = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not moduleDb or not moduleDb.enabled then
        if S.arenaPointerInitialized then
            self:DisableArenaPointer()
        end
        return
    end
    
    if db.enableArenaPointer == 1 then
        -- Enable if not already enabled
        if not S.arenaPointerInitialized then
            self:EnableArenaPointer()
        end
    else
        -- Disable if enabled
        if S.arenaPointerInitialized then
            self:DisableArenaPointer()
        end
    end
end

-- Enable Arena Pointer
function module:EnableArenaPointer()
    if S.arenaPointerInitialized then return end -- Already enabled
    
    -- Check if enabled
    if not IsArenaPointerEnabled() then return end
    
    -- Save original label positions before modifying
    for i = 1, 3 do
        local ratingLabel = _G["PVPTeam"..i.."DataRatingLabel"]
        if ratingLabel then
            local point, relativeTo, relativePoint, xOfs, yOfs = ratingLabel:GetPoint()
            if point then
                S.originalLabelPositions[i] = {
                    point = point,
                    relativeTo = relativeTo,
                    relativePoint = relativePoint,
                    xOfs = xOfs or 0,
                    yOfs = yOfs or 0
                }
            end
        end
    end
    
    -- Save original inspect label positions
    if InspectPVPTeam1DataRatingLabel then
        for i = 1, 3 do
            local ratingLabel = _G["InspectPVPTeam"..i.."DataRatingLabel"]
            if ratingLabel then
                local point, relativeTo, relativePoint, xOfs, yOfs = ratingLabel:GetPoint()
                if point then
                    S.originalInspectLabelPositions[i] = {
                        point = point,
                        relativeTo = relativeTo,
                        relativePoint = relativePoint,
                        xOfs = xOfs or 0,
                        yOfs = yOfs or 0
                    }
                end
            end
        end
    end
    
    -- Create measure font for PVP teams
    if not S.arenaPointerMeasureFont then
        S.arenaPointerMeasureFont = UIParent:CreateFontString(nil, "ARTWORK")
        S.arenaPointerMeasureFont:Hide()
    end
    
    -- Hook PVPTeam_Update
    if not S.old_PVPTeam_Update then
        S.old_PVPTeam_Update = PVPTeam_Update
        PVPTeam_Update = function(...)
            S.old_PVPTeam_Update(...)
            
            -- Check if still enabled
            if not IsArenaPointerEnabled() then return end
            
            -- Collect team sizes
            for i = 1, 3 do
                local teamName, teamSize = GetArenaTeam(i)
                if teamName then
                    S.arenaPointerTeams[teamName] = tonumber(teamSize)
                end
            end
            
            -- Add points to rating
            for i = 1, 3 do
                local rating = tonumber(_G["PVPTeam"..i.."DataRating"]:GetText())
                if rating then
                    local teamname = _G["PVPTeam"..i.."DataName"]:GetText()
                    if not S.arenaPointerTeams[teamname] then
                        return
                    end
                    local points = getArenaPoints(rating, S.arenaPointerTeams[teamname])
                    local pointsText = (" (%d)"):format(points)
                    local fullText = rating..pointsText
                    _G["PVPTeam"..i.."DataRating"]:SetText(fullText)
                    
                    -- Calculate width and shift label
                    local ratingLabel = _G["PVPTeam"..i.."DataRatingLabel"]
                    local ratingValue = _G["PVPTeam"..i.."DataRating"]
                    if ratingLabel and ratingValue then
                        -- Get font for measurement
                        local font, fontSize, fontFlags
                        if ratingValue.GetFont then
                            font, fontSize, fontFlags = ratingValue:GetFont()
                        end
                        if not font then
                            local labelFont = ratingLabel:GetFontString()
                            if labelFont then
                                font, fontSize, fontFlags = labelFont:GetFont()
                            end
                        end
                        if font then
                            S.arenaPointerMeasureFont:SetFont(font, fontSize, fontFlags)
                        else
                            S.arenaPointerMeasureFont:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
                        end
                        
                        -- Measure full text width and set field width
                        S.arenaPointerMeasureFont:SetText(fullText)
                        local fullTextWidth = S.arenaPointerMeasureFont:GetStringWidth()
                        ratingValue:SetWidth(fullTextWidth + 10)
                        
                        -- Measure added text width for label shift
                        S.arenaPointerMeasureFont:SetText(pointsText)
                        local textWidth = S.arenaPointerMeasureFont:GetStringWidth()
                        
                        -- Shift label right by added text width
                        ratingLabel:ClearAllPoints()
                        ratingLabel:SetPoint("RIGHT", _G["PVPTeam"..i.."DataName"], "RIGHT", textWidth, 0)
                    end
                end
            end
        end
    end
    
    -- Hook InspectPVPTeam_Update if available
    if InspectPVPTeam_Update and not S.old_InspectPVPTeam_Update then
        S.old_InspectPVPTeam_Update = InspectPVPTeam_Update
        
        -- Create measure font for inspect teams
        if not S.arenaPointerInspectMeasureFont then
            S.arenaPointerInspectMeasureFont = UIParent:CreateFontString(nil, "ARTWORK")
            S.arenaPointerInspectMeasureFont:Hide()
        end
        
        InspectPVPTeam_Update = function(...)
            S.old_InspectPVPTeam_Update(...)
            
            -- Check if still enabled
            if not IsArenaPointerEnabled() then return end
            
            -- Clear inspect teams
            for k in pairs(S.arenaPointerInspectTeams) do
                S.arenaPointerInspectTeams[k] = nil
            end
            
            -- Collect team sizes
            for i = 1, 3 do
                local teamName, teamSize = GetInspectArenaTeamData(i)
                if teamName then
                    S.arenaPointerInspectTeams[teamName] = tonumber(teamSize)
                end
            end
            
            -- Add points to rating
            for i = 1, 3 do
                local rating = tonumber(_G["InspectPVPTeam"..i.."DataRating"]:GetText())
                if rating then
                    local teamname = _G["InspectPVPTeam"..i.."DataName"]:GetText()
                    if not S.arenaPointerInspectTeams[teamname] then
                        return
                    end
                    local points = getArenaPoints(rating, S.arenaPointerInspectTeams[teamname])
                    local pointsText = (" (%d)"):format(points)
                    local fullText = rating..pointsText
                    _G["InspectPVPTeam"..i.."DataRating"]:SetText(fullText)
                    
                    -- Calculate width and shift label
                    local ratingLabel = _G["InspectPVPTeam"..i.."DataRatingLabel"]
                    local ratingValue = _G["InspectPVPTeam"..i.."DataRating"]
                    if ratingLabel and ratingValue then
                        -- Get font for measurement
                        local font, fontSize, fontFlags
                        if ratingValue.GetFont then
                            font, fontSize, fontFlags = ratingValue:GetFont()
                        end
                        if not font then
                            local labelFont = ratingLabel:GetFontString()
                            if labelFont then
                                font, fontSize, fontFlags = labelFont:GetFont()
                            end
                        end
                        if font then
                            S.arenaPointerInspectMeasureFont:SetFont(font, fontSize, fontFlags)
                        else
                            S.arenaPointerInspectMeasureFont:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
                        end
                        
                        -- Measure full text width and set field width
                        S.arenaPointerInspectMeasureFont:SetText(fullText)
                        local fullTextWidth = S.arenaPointerInspectMeasureFont:GetStringWidth()
                        ratingValue:SetWidth(fullTextWidth + 10)
                        
                        -- Measure added text width for label shift
                        S.arenaPointerInspectMeasureFont:SetText(pointsText)
                        local textWidth = S.arenaPointerInspectMeasureFont:GetStringWidth()
                        
                        -- Shift label right by added text width
                        ratingLabel:ClearAllPoints()
                        ratingLabel:SetPoint("RIGHT", _G["InspectPVPTeam"..i.."DataName"], "RIGHT", textWidth, 0)
                    end
                end
            end
        end
    end
    
    S.arenaPointerInitialized = true
end

-- Disable Arena Pointer
function module:DisableArenaPointer()
    if not S.arenaPointerInitialized then return end
    
    -- Restore original functions first
    local restoredPVPTeam_Update = nil
    local restoredInspectPVPTeam_Update = nil
    
    if S.old_PVPTeam_Update then
        restoredPVPTeam_Update = S.old_PVPTeam_Update
        PVPTeam_Update = S.old_PVPTeam_Update
        S.old_PVPTeam_Update = nil
    end
    
    if S.old_InspectPVPTeam_Update then
        restoredInspectPVPTeam_Update = S.old_InspectPVPTeam_Update
        InspectPVPTeam_Update = S.old_InspectPVPTeam_Update
        S.old_InspectPVPTeam_Update = nil
    end
    
    -- Restore text, width, and label positions
    for i = 1, 3 do
        local ratingLabel = _G["PVPTeam"..i.."DataRatingLabel"]
        local ratingValue = _G["PVPTeam"..i.."DataRating"]
        if ratingLabel and ratingValue then
            -- Remove text in parentheses
            local currentText = ratingValue:GetText()
            if currentText then
                local ratingText = currentText:gsub("%s*%(%d+%)", ""):match("^%s*(%d+)%s*$")
                if ratingText then
                    local rating = tonumber(ratingText)
                    if rating then
                        ratingValue:SetText(tostring(rating))
                    end
                end
            end
            
            -- Restore original label position
            if S.originalLabelPositions[i] then
                local pos = S.originalLabelPositions[i]
                ratingLabel:ClearAllPoints()
                ratingLabel:SetPoint(pos.point, pos.relativeTo, pos.relativePoint, pos.xOfs, pos.yOfs)
            end
            
            -- Restore original width (90 pixels)
            ratingValue:SetWidth(90)
        end
    end
    
    -- Restore Inspect PVP teams text, width, and label positions
    if InspectPVPTeam1DataRating then
        for i = 1, 3 do
            local ratingLabel = _G["InspectPVPTeam"..i.."DataRatingLabel"]
            local ratingValue = _G["InspectPVPTeam"..i.."DataRating"]
            if ratingLabel and ratingValue then
                -- Remove text in parentheses
                local currentText = ratingValue:GetText()
                if currentText then
                    local ratingText = currentText:gsub("%s*%(%d+%)", ""):match("^%s*(%d+)%s*$")
                    if ratingText then
                        local rating = tonumber(ratingText)
                        if rating then
                            ratingValue:SetText(tostring(rating))
                        end
                    end
                end
                
                -- Restore original label position
                if S.originalInspectLabelPositions[i] then
                    local pos = S.originalInspectLabelPositions[i]
                    ratingLabel:ClearAllPoints()
                    ratingLabel:SetPoint(pos.point, pos.relativeTo, pos.relativePoint, pos.xOfs, pos.yOfs)
                end
                
                -- Restore original width (90 pixels)
                ratingValue:SetWidth(90)
            end
        end
    end
    
    -- Clean up measure fonts
    if S.arenaPointerMeasureFont then
        S.arenaPointerMeasureFont:Hide()
        S.arenaPointerMeasureFont = nil
    end
    
    if S.arenaPointerInspectMeasureFont then
        S.arenaPointerInspectMeasureFont:Hide()
        S.arenaPointerInspectMeasureFont = nil
    end
    
    -- Clear teams
    S.arenaPointerTeams = {}
    S.arenaPointerInspectTeams = {}
    
    -- Clear saved positions
    S.originalLabelPositions = {}
    S.originalInspectLabelPositions = {}
    
    -- Call original update functions to ensure everything is properly restored
    if restoredPVPTeam_Update then
        restoredPVPTeam_Update()
    end
    
    if restoredInspectPVPTeam_Update then
        restoredInspectPVPTeam_Update()
    end
    
    S.arenaPointerInitialized = false
end

-- ============================================================================
-- Combat Text Shifting Functionality
-- ============================================================================

-- Apply combat text adjust settings
function module:ApplyCombatTextAdjust()
    local db = FloatingTextDB()
    if not db or not db.enabled then
        -- Disable if module is disabled
        if S.combatTextHooked then
            self:DisableCombatTextAdjust()
        end
        return
    end
    
    if db.enableHealCombatTextAdjust == 1 then
        -- Enable if not already enabled
        if not S.combatTextHooked then
            self:EnableCombatTextAdjust()
        end
    else
        -- Disable if enabled
        if S.combatTextHooked then
            self:DisableCombatTextAdjust()
        end
    end
end

-- Enable combat text adjust
function module:EnableCombatTextAdjust()
    local db = FloatingTextDB()
    if not db or not db.enabled then return end
    
    if S.combatTextHooked then return end -- Already enabled
    
    -- Ensure Blizzard floating combat text CVars are enabled so text cannot disappear due to client settings
    pcall(function()
        if GetCVar and SetCVar then
            if GetCVar("floatingCombatTextCombatDamage") ~= "1" then SetCVar("floatingCombatTextCombatDamage", 1) end
            if GetCVar("floatingCombatTextCombatHealing") ~= "1" then SetCVar("floatingCombatTextCombatHealing", 1) end
        end
    end)

    -- Hook CombatText frames when Blizzard_CombatText is loaded
    S.combatTextFrame = CreateFrame("Frame")
    S.combatTextFrame:RegisterEvent("ADDON_LOADED")
    S.combatTextFrame:SetScript("OnEvent", function(self, event, addonName)
        -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
        local checkDb = FloatingTextDB()
        if not checkDb or not checkDb.enabled then return end
        if checkDb.enableHealCombatTextAdjust ~= 1 then return end
        
        if addonName ~= "Blizzard_CombatText" then return end
        
        -- Hook SetPoint for all CombatText frames
        for i = 1, 20 do
            local region = _G["CombatText" .. i]
            if region and not region._SarychUICombatTextHooked then
                region._SarychUICombatTextHooked = true
                hooksecurefunc(region, "SetPoint", function(s, a, b, c, d, e)
                    local perfStart = SarychUI_PerfDebug and SarychUI_PerfNow and SarychUI_PerfNow() or nil
                    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
                    local hookDb = FloatingTextDB()
                    if not hookDb or not hookDb.enabled then return end
                    if hookDb.enableHealCombatTextAdjust ~= 1 then return end
                    
                    -- Prevent infinite loop
                    if S.combatTextFlag then
                        S.combatTextFlag = false
                        return
                    end
                    
                    local text = s.GetText and s:GetText()
                    if text then
                        if SarychUI_PerfLog then
                            SarychUI_PerfLog("CombatText", "SetPoint", text)
                        end
                        S.combatTextFlag = true
                        local first = text:sub(1, 1)
                        
                        if first == '+' then
                            -- Shift "+" lines (incoming heal)
                            if hookDb.healShiftPlus == 1 then
                                local plusX = hookDb.healPlusX or -200
                                local plusY = hookDb.healPlusY or -70
                                s:SetPoint(a, b, c, d + plusX, e + plusY)
                            else
                                S.combatTextFlag = false
                            end
                        elseif first == '-' then
                            -- Shift "-" lines (incoming damage)
                            if hookDb.healShiftMinus == 1 then
                                local minusX = hookDb.healMinusX or 0
                                local minusY = hookDb.healMinusY or 0
                                s:SetPoint(a, b, c, d + minusX, e + minusY)
                            else
                                S.combatTextFlag = false
                            end
                        elseif first == '<' then
                            -- Handle "<" lines (procs / reactive text)
                            if hookDb.healHideLess == 1 then
                                -- Hide lines starting with "<"
                                s:SetText("")
                                S.combatTextFlag = false
                            elseif hookDb.healShiftLess == 1 then
                                -- Shift "<" lines
                                local lessX = hookDb.healLessX or -250
                                local lessY = hookDb.healLessY or -30
                                s:SetPoint(a, b, c, d + lessX, e + lessY)
                            else
                                S.combatTextFlag = false
                            end
                        else
                            S.combatTextFlag = false
                        end
                    end
                    if SarychUI_PerfSlow then
                        SarychUI_PerfSlow("CombatText", "SetPointSlow", perfStart, nil, 2)
                    end
                end)
            end
        end
        
        S.combatTextHooked = true
        S.combatTextFrame:UnregisterEvent("ADDON_LOADED")
    end)
    
    -- If Blizzard_CombatText is already loaded, hook immediately
    if IsAddOnLoaded("Blizzard_CombatText") then
        S.combatTextFrame:GetScript("OnEvent")(S.combatTextFrame, "ADDON_LOADED", "Blizzard_CombatText")
    end
end

-- Disable combat text adjust
function module:DisableCombatTextAdjust()
    if not S.combatTextHooked then return end
    
    -- Unregister events
    if S.combatTextFrame then
        S.combatTextFrame:UnregisterAllEvents()
        S.combatTextFrame:SetScript("OnEvent", nil)
        S.combatTextFrame = nil
    end
    
    -- We can't unhook hooksecurefunc; keep per-frame sentinel so we don't double-hook on re-enable
    S.combatTextFlag = false
    
    S.combatTextHooked = false
end

-- ============================================================================
-- Raid Boss Emote Frame Repositioning Functionality
-- ============================================================================

-- Apply raid boss emote reposition settings
function module:ApplyRaidBossEmoteReposition()
    local db = FloatingTextDB()
    if not db or not db.enabled then
        -- Disable if module is disabled
        if S.raidBossEmoteHooked then
            self:DisableRaidBossEmoteReposition()
        end
        return
    end
    
    if db.enableRaidBossEmoteReposition == 1 then
        -- Enable if not already enabled
        if not S.raidBossEmoteHooked then
            self:EnableRaidBossEmoteReposition()
        end
        -- Apply reposition immediately
        self:RepositionRaidBossEmoteFrame()
    else
        -- Disable if enabled
        if S.raidBossEmoteHooked then
            self:DisableRaidBossEmoteReposition()
        end
    end
end

-- Reposition raid boss emote frame
function module:RepositionRaidBossEmoteFrame()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = FloatingTextDB()
    if not db or not db.enabled then return end
    if db.enableRaidBossEmoteReposition ~= 1 then
        -- If disabled, restore original position and width
        if RaidBossEmoteFrame then
            if S.raidBossRepositioned and S.originalRaidBossPosition then
                RaidBossEmoteFrame:ClearAllPoints()
                RaidBossEmoteFrame:SetPoint(unpack(S.originalRaidBossPosition))
            end
            if RaidBossEmoteFrame.slot1 and RaidBossEmoteFrame.slot2 then
                if S.originalRaidBossWidth then
                    RaidBossEmoteFrame.slot1:SetWidth(S.originalRaidBossWidth)
                    RaidBossEmoteFrame.slot2:SetWidth(S.originalRaidBossWidth)
                end
                if RaidBossEmoteFrame.slot1.SetNonSpaceWrap then
                    RaidBossEmoteFrame.slot1:SetNonSpaceWrap(false)
                    RaidBossEmoteFrame.slot2:SetNonSpaceWrap(false)
                end
            end
        end
        S.raidBossRepositioned = false
        S.originalRaidBossPosition = nil
        S.originalRaidBossWidth = nil
        S.lastAppliedOffset = nil
        return
    end
    
    if RaidBossEmoteFrame then
        -- Set max width and wrapping for slot1 and slot2
        local maxWidth = db.raidBossEmoteMaxWidth or 600
        if RaidBossEmoteFrame.slot1 and RaidBossEmoteFrame.slot2 then
            -- Save original width on first application
            if not S.originalRaidBossWidth then
                S.originalRaidBossWidth = RaidBossEmoteFrame.slot1:GetWidth()
            end
            
            RaidBossEmoteFrame.slot1:SetWidth(maxWidth)
            RaidBossEmoteFrame.slot2:SetWidth(maxWidth)
            if RaidBossEmoteFrame.slot1.SetNonSpaceWrap then
                RaidBossEmoteFrame.slot1:SetNonSpaceWrap(true)
                RaidBossEmoteFrame.slot2:SetNonSpaceWrap(true)
            end
        end
        
        local currentOffset = db.raidBossEmoteOffsetY or -430
        
        -- If frame not repositioned yet or offset changed
        if not S.raidBossRepositioned or S.lastAppliedOffset ~= currentOffset then
            -- If we have original position, use it
            if S.originalRaidBossPosition then
                RaidBossEmoteFrame:ClearAllPoints()
                RaidBossEmoteFrame:SetPoint(S.originalRaidBossPosition[1], S.originalRaidBossPosition[2], S.originalRaidBossPosition[3], S.originalRaidBossPosition[4], S.originalRaidBossPosition[5] + currentOffset)
                S.raidBossRepositioned = true
                S.lastAppliedOffset = currentOffset
            else
                -- First time - get original position
                local p, rel, rp, x, y = RaidBossEmoteFrame:GetPoint()
                if p and rel and rp and x and y then
                    S.originalRaidBossPosition = {p, rel, rp, x, y}
                    RaidBossEmoteFrame:ClearAllPoints()
                    RaidBossEmoteFrame:SetPoint(p, rel, rp, x, y + currentOffset)
                    S.raidBossRepositioned = true
                    S.lastAppliedOffset = currentOffset
                end
            end
        end
    end
end

-- Enable raid boss emote reposition
function module:EnableRaidBossEmoteReposition()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = FloatingTextDB()
    if not db or not db.enabled then return end
    
    if S.raidBossEmoteHooked then return end -- Already enabled
    
    -- Hook ADDON_LOADED for Blizzard_RaidUI and Blizzard_CombatText
    S.raidBossEmoteFrame = CreateFrame("Frame")
    S.raidBossEmoteFrame:RegisterEvent("ADDON_LOADED")
    S.raidBossEmoteFrame:SetScript("OnEvent", function(self, event, addonName)
        -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
        local checkDb = FloatingTextDB()
        if not checkDb or not checkDb.enabled then return end
        if checkDb.enableRaidBossEmoteReposition ~= 1 then return end
        
        if addonName == "Blizzard_RaidUI" or addonName == "Blizzard_CombatText" then
            -- Small delay to ensure frame is created
            C_Timer.After(0.1, function()
                module:RepositionRaidBossEmoteFrame()
            end)
        end
    end)
    
    -- Periodic check and apply repositioning (every second)
    local raidBossTimer = 0
    S.raidBossEmoteFrame:SetScript("OnUpdate", function(self, elapsed)
        -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
        local checkDb = FloatingTextDB()
        if not checkDb or not checkDb.enabled then return end
        if checkDb.enableRaidBossEmoteReposition ~= 1 then return end
        
        raidBossTimer = raidBossTimer + elapsed
        if raidBossTimer >= 1.0 then  -- Check every second
            raidBossTimer = 0
            if RaidBossEmoteFrame then
                module:RepositionRaidBossEmoteFrame()
            end
        end
    end)
    
    -- If addons already loaded, apply immediately
    if IsAddOnLoaded("Blizzard_RaidUI") or IsAddOnLoaded("Blizzard_CombatText") then
        C_Timer.After(0.1, function()
            module:RepositionRaidBossEmoteFrame()
        end)
    end
    
    S.raidBossEmoteHooked = true
end

-- Disable raid boss emote reposition
function module:DisableRaidBossEmoteReposition()
    if not S.raidBossEmoteHooked then return end
    
    -- Restore original position
    if RaidBossEmoteFrame and S.raidBossRepositioned and S.originalRaidBossPosition then
        RaidBossEmoteFrame:ClearAllPoints()
        RaidBossEmoteFrame:SetPoint(unpack(S.originalRaidBossPosition))
    end
    
    -- Restore original width and disable wrapping
    if RaidBossEmoteFrame and RaidBossEmoteFrame.slot1 and RaidBossEmoteFrame.slot2 then
        if S.originalRaidBossWidth then
            RaidBossEmoteFrame.slot1:SetWidth(S.originalRaidBossWidth)
            RaidBossEmoteFrame.slot2:SetWidth(S.originalRaidBossWidth)
        end
        if RaidBossEmoteFrame.slot1.SetNonSpaceWrap then
            RaidBossEmoteFrame.slot1:SetNonSpaceWrap(false)
            RaidBossEmoteFrame.slot2:SetNonSpaceWrap(false)
        end
    end
    
    -- Unregister events
    if S.raidBossEmoteFrame then
        S.raidBossEmoteFrame:UnregisterAllEvents()
        S.raidBossEmoteFrame:SetScript("OnEvent", nil)
        S.raidBossEmoteFrame:SetScript("OnUpdate", nil)
        S.raidBossEmoteFrame = nil
    end
    
    -- Reset state
    S.raidBossRepositioned = false
    S.originalRaidBossPosition = nil
    S.originalRaidBossWidth = nil
    S.lastAppliedOffset = nil
    
    S.raidBossEmoteHooked = false
end

-- ============================================================================
-- Error Filter Functionality
-- ============================================================================

-- Split patterns string into table
local function SplitErrorPatterns(text)
    local patterns = {}
    if type(text) ~= "string" then return patterns end
    for token in gmatch(text, "[^;]+") do
        token = token:gsub("^%s+", ""):gsub("%s+$", "")
        if token ~= "" then tinsert(patterns, token) end
    end
    return patterns
end

-- Locale-aware default UI error filter patterns (enUS + ruRU; EN fallback)
local function GetDefaultErrorHidePatterns()
    local locale = GetLocale and GetLocale() or "enUS"
    if locale == "ruRU" then
        return "Способность пока недоступна."
    end
    return "Ability is not ready yet."
end

local function GetDefaultErrorExceptionPatterns()
    local locale = GetLocale and GetLocale() or "enUS"
    if locale == "ruRU" then
        return "Вы должны подождать;Нет места."
    end
    return "You must wait;Inventory is full."
end

-- Send message to all chat frames
local function SendToAllChatFrames(message, r, g, b)
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame"..i]
        if cf then cf:AddMessage(message, r, g, b) end
    end
end

-- Build error filter frames
local function BuildErrorFrames()
    if S.errorFilterFrames.created then return end
    S.errorFilterFrames.created = true
    
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = FloatingTextDB()
    if not db or not db.enabled then return end
    
    local timeVisible = db.errorTimeVisible or 1
    UIErrorsFrame:SetTimeVisible(timeVisible)
    UIErrorsFrame:SetAlpha(0)
    
    -- Create filtered errors frame
    local fef = CreateFrame("MessageFrame", nil, UIParent)
    fef:SetSize(UIErrorsFrame:GetWidth(), UIErrorsFrame:GetHeight())
    fef:SetInsertMode(UIErrorsFrame:GetInsertMode())
    fef:SetFontObject(UIErrorsFrame:GetFontObject())
    fef:SetTimeVisible(UIErrorsFrame:GetTimeVisible())
    fef:SetFadeDuration(UIErrorsFrame:GetFadeDuration())
    fef:SetJustifyH("CENTER")
    fef:SetFrameStrata(UIErrorsFrame:GetFrameStrata())
    fef:ClearAllPoints()
    local filteredOffsetY = db.errorFilteredOffsetY or -130
    fef:SetPoint("CENTER", UIParent, "CENTER", 0, filteredOffsetY)
    fef:SetAlpha(1)
    fef:Show()
    S.errorFilterFrames.filtered = fef
    
    -- Create system messages frame
    local sif = CreateFrame("MessageFrame", nil, UIParent)
    sif:SetSize(UIErrorsFrame:GetWidth(), UIErrorsFrame:GetHeight())
    sif:SetInsertMode(UIErrorsFrame:GetInsertMode())
    sif:SetFontObject(UIErrorsFrame:GetFontObject())
    sif:SetTimeVisible(UIErrorsFrame:GetTimeVisible())
    sif:SetFadeDuration(UIErrorsFrame:GetFadeDuration())
    sif:SetJustifyH("CENTER")
    sif:SetFrameStrata(UIErrorsFrame:GetFrameStrata())
    sif:ClearAllPoints()
    local sysOffsetY = db.errorSysMsgOffsetY or 0
    sif:SetPoint("BOTTOM", UIErrorsFrame, "TOP", 0, sysOffsetY)
    sif:SetAlpha(1)
    sif:Show()
    S.errorFilterFrames.sys = sif
    
    -- Unregister events from UIErrorsFrame and register on sys frame
    UIErrorsFrame:UnregisterEvent("SYSMSG")
    UIErrorsFrame:UnregisterEvent("UI_INFO_MESSAGE")
    sif:RegisterEvent("SYSMSG")
    sif:RegisterEvent("UI_INFO_MESSAGE")
    sif:SetScript("OnEvent", function(self, event, ...)
        -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
        local checkDb = FloatingTextDB()
        if not checkDb or not checkDb.enabled then return end
        
        local msg = ...
        if event == "SYSMSG" or event == "UI_INFO_MESSAGE" then
            self:AddMessage(msg, 1, 1, 0, 1)
        end
    end)
end

-- Update Alt visibility for original errors
local function UpdateErrorAltVisibility(isAltPressed)
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = FloatingTextDB()
    if not db or not db.enabled then return end
    if not S.errorFilterFrames.enabled then return end
    
    if S.errorFilterFrames.altOnly then
        UIErrorsFrame:SetAlpha(isAltPressed and 1 or 0)
    else
        UIErrorsFrame:SetAlpha(1)
    end
end

-- Install error handler
local function InstallErrorHandler()
    if S.errorFilterFrames.origHandler then return end
    
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = FloatingTextDB()
    if not db or not db.enabled then return end
    
    S.errorFilterFrames.origHandler = UIErrorsFrame:GetScript("OnEvent")
    UIErrorsFrame:SetScript("OnEvent", function(self, event, ...)
        -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
        local checkDb = FloatingTextDB()
        if not checkDb or not checkDb.enabled then
            if S.errorFilterFrames.origHandler then
                S.errorFilterFrames.origHandler(self, event, ...)
            end
            return
        end
        
        local msg = ...
        local now = GetTime()
        
        if event == "UI_ERROR_MESSAGE" and S.errorFilterFrames.enabled then
            local throttle = checkDb.errorThrottleWindow or 0.5
            if msg == S.errorFilterFrames.lastMsg and (now - (S.errorFilterFrames.lastAt or 0)) < throttle then
                return
            end
            
            -- Check hide patterns
            local hidePat = SplitErrorPatterns(checkDb.errorHidePatterns or GetDefaultErrorHidePatterns())
            for _, hidden in ipairs(hidePat) do
                if hidden ~= "" and msg:find(hidden) then
                    return
                end
            end
            
            S.errorFilterFrames.lastMsg, S.errorFilterFrames.lastAt = msg, now
            
            -- Check exception patterns (only if extra frame enabled)
            if checkDb.errorExtraEnabled == 1 then
                local excPat = SplitErrorPatterns(checkDb.errorExceptionPatterns or GetDefaultErrorExceptionPatterns())
                for _, exc in ipairs(excPat) do
                    if exc ~= "" and msg:find(exc) then
                        if S.errorFilterFrames.filtered then
                            S.errorFilterFrames.filtered:AddMessage(msg, 1, 0.1, 0.1, 1)
                        end
                        if checkDb.errorPlaySound == 1 then
                            PlaySound("TellMessage")
                        end
                        if checkDb.errorEchoToChat == 1 then
                            SendToAllChatFrames(msg, 1, 0.1, 0.1)
                        end
                        return
                    end
                end
            end
        end
        
        -- Call original handler
        if S.errorFilterFrames.origHandler then
            S.errorFilterFrames.origHandler(self, event, ...)
        end
    end)
end

-- Apply error filter settings
function module:ApplyErrorFilter()
    local db = FloatingTextDB()
    if not db or not db.enabled then
        -- Disable if module is disabled
        if S.errorFilterInitialized then
            self:DisableErrorFilter()
        end
        return
    end
    
    if db.enableErrorFilter == 1 then
        -- Enable if not already enabled
        if not S.errorFilterInitialized then
            self:EnableErrorFilter()
        end
        -- Apply settings
        self:UpdateErrorFilterSettings()
    else
        -- Disable if enabled
        if S.errorFilterInitialized then
            self:DisableErrorFilter()
        end
    end
end

-- Update error filter settings
function module:UpdateErrorFilterSettings()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = FloatingTextDB()
    if not db or not db.enabled then return end
    if db.enableErrorFilter ~= 1 then return end
    
    S.errorFilterFrames.enabled = true
    S.errorFilterFrames.altOnly = (db.errorShowOriginalOnAlt == 1)
    
    BuildErrorFrames()
    
    local timeVisible = db.errorTimeVisible or 1
    UIErrorsFrame:SetTimeVisible(timeVisible)
    UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
    
    if S.errorFilterFrames.filtered then
        S.errorFilterFrames.filtered:ClearAllPoints()
        local filteredOffsetY = db.errorFilteredOffsetY or -130
        S.errorFilterFrames.filtered:SetPoint("CENTER", UIParent, "CENTER", 0, filteredOffsetY)
        S.errorFilterFrames.filtered:SetTimeVisible(UIErrorsFrame:GetTimeVisible())
        local fadeDuration = db.errorFadeDuration or 1.5
        S.errorFilterFrames.filtered:SetFadeDuration(fadeDuration)
        S.errorFilterFrames.filtered:SetAlpha(1)
        S.errorFilterFrames.filtered:Show()
    end
    
    if S.errorFilterFrames.sys then
        S.errorFilterFrames.sys:ClearAllPoints()
        local sysOffsetY = db.errorSysMsgOffsetY or 0
        S.errorFilterFrames.sys:SetPoint("BOTTOM", UIErrorsFrame, "TOP", 0, sysOffsetY)
        S.errorFilterFrames.sys:SetTimeVisible(UIErrorsFrame:GetTimeVisible())
        local fadeDuration = db.errorFadeDuration or 1.5
        S.errorFilterFrames.sys:SetFadeDuration(fadeDuration)
        S.errorFilterFrames.sys:SetAlpha(1)
        S.errorFilterFrames.sys:Show()
    end
    
    local fadeDuration = db.errorFadeDuration or 1.5
    UIErrorsFrame:SetFadeDuration(fadeDuration)
    
    InstallErrorHandler()
    UpdateErrorAltVisibility(SarychUI.AltMode and SarychUI.AltMode:IsAltPressed() or false)
end

-- Enable error filter
function module:EnableErrorFilter()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = FloatingTextDB()
    if not db or not db.enabled then return end
    
    if S.errorFilterInitialized then return end -- Already enabled
    
    -- Register Alt mode callback
    if SarychUI.AltMode then
        SarychUI.AltMode:RegisterCallback("errorFilter", UpdateErrorAltVisibility)
    end
    
    -- Apply settings
    self:UpdateErrorFilterSettings()
    
    S.errorFilterInitialized = true
end

-- Disable error filter
function module:DisableErrorFilter()
    if not S.errorFilterInitialized then return end
    
    -- Restore original handler
    if S.errorFilterFrames.origHandler then
        UIErrorsFrame:SetScript("OnEvent", S.errorFilterFrames.origHandler)
        S.errorFilterFrames.origHandler = nil
    end
    
    -- Restore original events
    UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
    UIErrorsFrame:RegisterEvent("SYSMSG")
    UIErrorsFrame:RegisterEvent("UI_INFO_MESSAGE")
    UIErrorsFrame:SetAlpha(1)
    UIErrorsFrame:Show()
    
    -- Hide and destroy custom frames
    if S.errorFilterFrames.filtered then
        S.errorFilterFrames.filtered:Hide()
        S.errorFilterFrames.filtered:UnregisterAllEvents()
        S.errorFilterFrames.filtered:SetScript("OnEvent", nil)
        S.errorFilterFrames.filtered = nil
    end
    
    if S.errorFilterFrames.sys then
        S.errorFilterFrames.sys:Hide()
        S.errorFilterFrames.sys:UnregisterAllEvents()
        S.errorFilterFrames.sys:SetScript("OnEvent", nil)
        S.errorFilterFrames.sys = nil
    end
    
    -- Restore system events to UIErrorsFrame
    if UIErrorsFrame then
        UIErrorsFrame:RegisterEvent("SYSMSG")
        UIErrorsFrame:RegisterEvent("UI_INFO_MESSAGE")
    end
    
    -- Unregister Alt mode callback
    if SarychUI.AltMode then
        SarychUI.AltMode:UnregisterCallback("errorFilter")
    end
    
    -- Reset state
    S.errorFilterFrames.created = false
    S.errorFilterFrames.enabled = false
    S.errorFilterFrames.altOnly = false
    S.errorFilterFrames.lastMsg = nil
    S.errorFilterFrames.lastAt = 0
    
    S.errorFilterInitialized = false
end

-- ============================================================================
-- BlizzMove Functionality
-- ============================================================================

local SetMoveHandler
local BLIZZMOVE_CTRL_TOGGLE_DEBOUNCE_MS = 200
local BLIZZMOVE_CHARACTER_FRAME_NAME = "CharacterFrame"

local function GetCharacterFrameSavedScale(settings)
    if settings and settings.save and settings.scale then
        return settings.scale
    end
    return 1.0
end

local function ResetCharacterFrameModelDefaults()
    local model = _G.CharacterModelFrame
    if model and model.SetScale then
        model:SetScale(1.0)
    end
    local scene = _G.CharacterModelScene
    if scene and scene.SetScale and scene ~= model then
        scene:SetScale(1.0)
    end
end

local function EnsureCharacterFrameHideHook()
    local characterFrame = _G.CharacterFrame
    if not characterFrame or characterFrame._SarychUI_BlizzMoveHideHook then
        return
    end

    characterFrame._SarychUI_BlizzMoveHideHook = true
    characterFrame:HookScript("OnHide", function(self)
        local db = DB()
        if not db or not db.enabled or db.enableBlizzMove ~= 1 then return end

        local settings = self.settings
        if not settings then
            local frames = db.blizzMoveFrames or {}
            settings = frames[BLIZZMOVE_CHARACTER_FRAME_NAME]
        end

        local targetScale = GetCharacterFrameSavedScale(settings)
        local currentScale = self:GetScale() or 1
        if math.abs(currentScale - targetScale) < 0.001 then
            return
        end

        self:SetScale(targetScale)
        ResetCharacterFrameModelDefaults()
    end)
end

local function PrintBlizzMove(msg)
    if SarychUI and SarychUI.Printf then
        SarychUI:Printf("BlizzMove: %s", msg)
    else
        print("|cffffd200SarychUI:|r BlizzMove: " .. msg)
    end
end

local function DebugBlizzMoveClick(frameName, eventName, button, ctrlDown, oldSave, newSave, ignored, hookCount, elapsedMs)
    if not _G.SarychUI_DebugBlizzMoveClick then return end
    local prefix = (SarychUI and SarychUI.GetScopedChatPrefix and SarychUI:GetScopedChatPrefix("BlizzMove")) or "|cffffd200SarychUI BlizzMove:|r"
    print(string.format(
        "%s debug: %s event=%s btn=%s ctrl=%s oldSave=%s newSave=%s ignored=%s hookCount=%s elapsed=%.0fms",
        prefix,
        frameName or "?",
        eventName or "?",
        tostring(button),
        tostring(ctrlDown),
        tostring(oldSave),
        tostring(newSave),
        tostring(ignored),
        tostring(hookCount or 0),
        elapsedMs or 0
    ))
end

do
    -- handlers the frame OnShow event
    local function OnShow(self, ...)
        local db = DB()
        if not db or not db.enabled or db.enableBlizzMove ~= 1 then return end
        
        local frameName = self:GetName()
        if not frameName then return end
        
        local frames = db.blizzMoveFrames or {}
        local settings = frames[frameName]
        if settings and settings.point and settings.save then
            self:ClearAllPoints()
            local relativeTo = settings.relativeTo
            if type(relativeTo) == "string" then
                relativeTo = _G[relativeTo] or UIParent
            else
                relativeTo = UIParent
            end
            self:SetPoint(
                settings.point,
                relativeTo,
                settings.relativePoint,
                settings.xOfs,
                settings.yOfs
            )
            local scale = settings.scale
            if scale then
                self:SetScale(scale)
            else
                self:SetScale(1.0)
            end
        else
            self:SetScale(1.0)
        end
    end

    -- handles frames rescaling
    local function OnMouseWheel(self, ...)
        local db = DB()
        if not db or not db.enabled or db.enableBlizzMove ~= 1 then return end
        
        if IsControlKeyDown() then
            local frameToMove = self.frameToMove
            local scale = frameToMove:GetScale() or 1
            local arg1 = select(1, ...)
            if arg1 == 1 then
                scale = scale + .1
                if scale > 1.5 then
                    scale = 1.5
                end
            else
                scale = scale - .1
                if scale < 0.5 then
                    scale = 0.5
                end
            end

            frameToMove:SetScale(scale)
        end
    end

    -- handles frames OnDragStart event
    local function OnDragStart(self)
        local db = DB()
        if not db or not db.enabled or db.enableBlizzMove ~= 1 then return end
        
        local frameToMove = self.frameToMove
        if not frameToMove then return end
        frameToMove:StartMoving()
        frameToMove.isMoving = true
    end

    -- handles frames OnDragStop
    local function OnDragStop(self)
        local db = DB()
        if not db or not db.enabled or db.enableBlizzMove ~= 1 then return end
        
        local frameToMove = self.frameToMove
        local settings = frameToMove.settings
        frameToMove:StopMovingOrSizing()
        frameToMove.isMoving = false
        if not settings then
            return
        end
        settings.point, settings.relativeTo, settings.relativePoint, settings.xOfs, settings.yOfs =
            frameToMove:GetPoint(1)
        if settings.relativeTo then
            settings.relativeTo = settings.relativeTo:GetName()
        end
    end

    local function ToggleBlizzMoveSave(frameToMove, handler, eventName, button)
        if button ~= "RightButton" or not IsControlKeyDown() then
            return
        end
        if not frameToMove then return end

        local db = DB()
        if not db or not db.enabled or db.enableBlizzMove ~= 1 then return end

        local frameName = frameToMove:GetName() or "Frame"
        local settings = frameToMove.settings
        local oldSave = settings and settings.save
        local now = debugprofilestop()
        local lastToggle = frameToMove._SarychUI_LastCtrlRightClickToggle or 0
        local elapsed = now - lastToggle
        local hookCount = frameToMove._SarychUI_BlizzMoveHookCount or 0

        if elapsed < BLIZZMOVE_CTRL_TOGGLE_DEBOUNCE_MS then
            DebugBlizzMoveClick(frameName, eventName, button, true, oldSave, oldSave, true, hookCount, elapsed)
            return
        end

        frameToMove._SarychUI_LastCtrlRightClickToggle = now

        if settings then
            settings.save = not settings.save
            local newSave = settings.save
            if newSave then
                settings.scale = frameToMove:GetScale() or 1
                PrintBlizzMove(frameName .. " будет сохранен.")
            else
                PrintBlizzMove(frameName .. " не будет сохранен.")
            end
            DebugBlizzMoveClick(frameName, eventName, button, true, oldSave, newSave, false, hookCount, elapsed)
        else
            if frameToMove:GetName() then
                local frames = db.blizzMoveFrames or {}
                frames[frameName] = {}
                settings = frames[frameName]
                settings.save = true
                settings.point, settings.relativeTo, settings.relativePoint, settings.xOfs, settings.yOfs =
                    frameToMove:GetPoint(1)
                if settings.relativeTo then
                    settings.relativeTo = settings.relativeTo:GetName()
                end
                settings.scale = frameToMove:GetScale() or 1
                frameToMove.settings = settings
                PrintBlizzMove(frameName .. " будет сохранен.")
                DebugBlizzMoveClick(frameName, eventName, button, true, nil, true, false, hookCount, elapsed)
            end
        end
    end

    -- handles frames OnMouseUp (Ctrl+RightButton save toggle only here, not OnMouseDown)
    local function OnMouseUp(self, button, ...)
        local db = DB()
        if not db or not db.enabled or db.enableBlizzMove ~= 1 then return end

        local frameToMove = self.frameToMove
        if not frameToMove then return end

        if frameToMove.isMoving then
            OnDragStop(self)
        end

        ToggleBlizzMoveSave(frameToMove, self, "OnMouseUp", button)
    end

    -- sets frames move handlers.
    function SetMoveHandler(frameToMove, handler)
        local db = DB()
        if not db or not db.enabled or db.enableBlizzMove ~= 1 then return end
        if not frameToMove then return end
        
        handler = handler or frameToMove

        --fix for elvui AchievementFrame skin
        if (handler == AchievementFrameHeader) and (IsAddOnLoaded("ElvUI")) then
            handler = frameToMove
        end

        local frameName = frameToMove:GetName()
        if not frameName then return end

        if SarychUI and SarychUI.IsBlizzMoveFrameAllowed and not SarychUI:IsBlizzMoveFrameAllowed(frameName) then
            return
        end
        
        local frames = db.blizzMoveFrames or {}
        if not frames[frameName] then
            frames[frameName] = S.blizzMoveDefaults[frameName] or {}
        end
        
        local settings = frames[frameName]
        frameToMove.settings = settings
        handler.frameToMove = frameToMove

        if not frameToMove.EnableMouse then
            return
        end

        frameToMove:EnableMouse(true)
        frameToMove:SetMovable(true)
        handler:RegisterForDrag(db.blizzMoveMouseButton or "LeftButton")

        handler:SetScript("OnDragStart", OnDragStart)
        handler:SetScript("OnDragStop", OnDragStop)

        if not frameToMove._SarychUI_BlizzMoveOnShowHooked then
            frameToMove._SarychUI_BlizzMoveOnShowHooked = true
            frameToMove:HookScript("OnShow", OnShow)
        end

        if handler._SarychUI_BlizzMoveHooked then
            return
        end
        handler._SarychUI_BlizzMoveHooked = true
        frameToMove._SarychUI_BlizzMoveHookCount = (frameToMove._SarychUI_BlizzMoveHookCount or 0) + 1

        handler:HookScript("OnMouseUp", OnMouseUp)
        handler:EnableMouseWheel(true)
        handler:HookScript("OnMouseWheel", OnMouseWheel)
    end
end

-- Setup frames that are available immediately
local function SetupBlizzMoveFrames()
    local db = DB()
    if not db or not db.enabled or db.enableBlizzMove ~= 1 then return end
    
    -- Initialize database
    if type(db.blizzMoveFrames) ~= "table" or not next(db.blizzMoveFrames) then
        db.blizzMoveFrames = CopyTable(S.blizzMoveDefaults)
    end

    EnsureCharacterFrameHideHook()
    
    -- Setup frames that are available immediately
    SetMoveHandler(CharacterFrame, PaperDollFrame)
    SetMoveHandler(CharacterFrame, TokenFrame)
    SetMoveHandler(CharacterFrame, SkillFrame)
    SetMoveHandler(CharacterFrame, ReputationFrame)
    if PetPaperDollFrameCompanionFrame then
        SetMoveHandler(CharacterFrame, PetPaperDollFrameCompanionFrame)
    end
    SetMoveHandler(SpellBookFrame)
    SetMoveHandler(QuestLogFrame)
    SetMoveHandler(FriendsFrame)
    
    if PVPParentFrame then
        SetMoveHandler(PVPParentFrame, PVPFrame)
    elseif PVPFrame then
        SetMoveHandler(PVPFrame)
    end
    
    if LFGParentFrame then
        SetMoveHandler(LFGParentFrame)
    end
    SetMoveHandler(GameMenuFrame)
    SetMoveHandler(GossipFrame)
    SetMoveHandler(DressUpFrame)
    SetMoveHandler(QuestFrame)
    SetMoveHandler(MerchantFrame)
    SetMoveHandler(HelpFrame)
    if PlayerTalentFrame then
        SetMoveHandler(PlayerTalentFrame)
    end
    SetMoveHandler(ClassTrainerFrame)
    SetMoveHandler(MailFrame)
    SetMoveHandler(BankFrame)
    SetMoveHandler(VideoOptionsFrame)
    SetMoveHandler(InterfaceOptionsFrame)
    SetMoveHandler(LootFrame)
    if LFDParentFrame then
        SetMoveHandler(LFDParentFrame)
    end
    if LFRParentFrame then
        SetMoveHandler(LFRParentFrame)
    end
    SetMoveHandler(TradeFrame)
end

-- Apply BlizzMove settings
function module:ApplyBlizzMove()
    local db = DB()
    if not db or not db.enabled then
        if S.blizzMoveInitialized then
            self:DisableBlizzMove()
        end
        return
    end
    
    if db.enableBlizzMove == 1 then
        if not S.blizzMoveInitialized then
            self:EnableBlizzMove()
        else
            -- Re-apply handlers if mouse button changed or already initialized
            -- This ensures handlers are updated when settings change
            SetupBlizzMoveFrames()
        end
    else
        if S.blizzMoveInitialized then
            self:DisableBlizzMove()
        end
    end
end

-- Enable BlizzMove
function module:EnableBlizzMove()
    local db = DB()
    if not db or not db.enabled or db.enableBlizzMove ~= 1 then return end
    if S.blizzMoveInitialized then return end -- Already enabled
    
    -- Create event frame
    if not S.blizzMoveFrame then
        S.blizzMoveFrame = CreateFrame("Frame")
    end
    
    -- Setup frames immediately (if world is already loaded)
    SetupBlizzMoveFrames()
    
    -- Register PLAYER_ENTERING_WORLD to setup frames (if not already loaded)
    S.blizzMoveFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    S.blizzMoveFrame:SetScript("OnEvent", function(self, event, ...)
        local checkDb = DB()
        if not checkDb or not checkDb.enabled or checkDb.enableBlizzMove ~= 1 then return end
        
        if event == "PLAYER_ENTERING_WORLD" then
            SetupBlizzMoveFrames()
        elseif event == "ADDON_LOADED" then
            local name = ...
            if name == "Blizzard_InspectUI" and InspectFrame then
                SetMoveHandler(InspectFrame)
            elseif name == "Blizzard_GuildBankUI" and GuildBankFrame then
                SetMoveHandler(GuildBankFrame)
            elseif name == "Blizzard_TradeSkillUI" and TradeSkillFrame then
                SetMoveHandler(TradeSkillFrame)
            elseif name == "Blizzard_ItemSocketingUI" and ItemSocketingFrame then
                SetMoveHandler(ItemSocketingFrame)
            elseif name == "Blizzard_BarbershopUI" and BarberShopFrame then
                SetMoveHandler(BarberShopFrame)
            elseif name == "Blizzard_GlyphUI" and PlayerTalentFrame and GlyphFrame then
                SetMoveHandler(PlayerTalentFrame, GlyphFrame)
            elseif name == "Blizzard_MacroUI" and MacroFrame then
                SetMoveHandler(MacroFrame)
            elseif name == "Blizzard_AchievementUI" and AchievementFrame and AchievementFrameHeader then
                SetMoveHandler(AchievementFrame, AchievementFrameHeader)
            elseif name == "Blizzard_TalentUI" and PlayerTalentFrame then
                SetMoveHandler(PlayerTalentFrame)
            elseif name == "Blizzard_Calendar" and CalendarFrame then
                SetMoveHandler(CalendarFrame)
            elseif name == "Blizzard_TrainerUI" and ClassTrainerFrame then
                SetMoveHandler(ClassTrainerFrame)
            elseif name == "Blizzard_BindingUI" and KeyBindingFrame then
                SetMoveHandler(KeyBindingFrame)
            elseif name == "Blizzard_AuctionUI" and AuctionFrame then
                SetMoveHandler(AuctionFrame)
            end
        end
    end)
    
    -- Register ADDON_LOADED for delayed frames
    S.blizzMoveFrame:RegisterEvent("ADDON_LOADED")
    
    S.blizzMoveInitialized = true
end

-- Disable moving for all frames
local function DisableMoveForAllFrames()
    -- List of frames that might have been configured
    local framesToDisable = {
        {frame = CharacterFrame, handler = PaperDollFrame},
        {frame = CharacterFrame, handler = TokenFrame},
        {frame = CharacterFrame, handler = SkillFrame},
        {frame = CharacterFrame, handler = ReputationFrame},
        {frame = CharacterFrame, handler = PetPaperDollFrameCompanionFrame},
        {frame = SpellBookFrame},
        {frame = QuestLogFrame},
        {frame = FriendsFrame},
        {frame = PVPParentFrame, handler = PVPFrame},
        {frame = PVPFrame},
        {frame = LFGParentFrame},
        {frame = GameMenuFrame},
        {frame = GossipFrame},
        {frame = DressUpFrame},
        {frame = QuestFrame},
        {frame = MerchantFrame},
        {frame = HelpFrame},
        {frame = PlayerTalentFrame},
        {frame = ClassTrainerFrame},
        {frame = MailFrame},
        {frame = BankFrame},
        {frame = VideoOptionsFrame},
        {frame = InterfaceOptionsFrame},
        {frame = LootFrame},
        {frame = LFDParentFrame},
        {frame = LFRParentFrame},
        {frame = TradeFrame},
        {frame = InspectFrame},
        {frame = GuildBankFrame},
        {frame = TradeSkillFrame},
        {frame = ItemSocketingFrame},
        {frame = BarberShopFrame},
        {frame = MacroFrame},
        {frame = AchievementFrame, handler = AchievementFrameHeader},
        {frame = CalendarFrame},
        {frame = KeyBindingFrame},
        {frame = AuctionFrame},
    }
    
    for _, frameData in ipairs(framesToDisable) do
        local frame = frameData.frame
        local handler = frameData.handler or frame
        
        if frame and handler then
            -- Check if handler has frameToMove (was configured)
            if handler.frameToMove or handler._SarychUI_BlizzMoveHooked then
                -- Clear handlers
                handler:SetScript("OnDragStart", nil)
                handler:SetScript("OnDragStop", nil)
                handler:SetScript("OnMouseUp", nil)
                handler:SetScript("OnMouseWheel", nil)

                handler._SarychUI_BlizzMoveHooked = nil
                frame._SarychUI_BlizzMoveOnShowHooked = nil
                frame._SarychUI_LastCtrlRightClickToggle = nil
                frame._SarychUI_BlizzMoveHookCount = nil
                
                -- Disable moving
                if frame.SetMovable then
                    frame:SetMovable(false)
                end
                
                -- Clear frameToMove reference
                handler.frameToMove = nil
                if frame.frameToMove then
                    frame.frameToMove = nil
                end
            end
        end
    end
end

-- Disable BlizzMove
function module:DisableBlizzMove()
    if not S.blizzMoveInitialized then return end
    
    -- Disable moving for all frames
    DisableMoveForAllFrames()
    
    -- Unregister all events
    if S.blizzMoveFrame then
        S.blizzMoveFrame:UnregisterAllEvents()
        S.blizzMoveFrame:SetScript("OnEvent", nil)
    end
    
    S.blizzMoveInitialized = false
end

-- ============================================================================
-- DarkMode Functionality
-- ============================================================================

S.darkModeInitialized, S.darkModeFrame = false, nil
S.darkModeConfig = {
    color = {r = 0.37, g = 0.37, b = 0.37, a = 1}
}

S.darkModeFramesList = {
    -- UnitFrames
    "PlayerFrameTexture",
    "TargetFrameTextureFrameTexture",
    "PetFrameTexture",
    "PartyMemberFrame1Texture",
    "PartyMemberFrame2Texture",
    "PartyMemberFrame3Texture",
    "PartyMemberFrame4Texture",
    "PartyMemberFrame1PetFrameTexture",
    "PartyMemberFrame2PetFrameTexture",
    "PartyMemberFrame3PetFrameTexture",
    "PartyMemberFrame4PetFrameTexture",
    "FocusFrameTextureFrameTexture",
    "TargetFrameToTTextureFrameTexture",
    "FocusFrameToTTextureFrameTexture",
    "Boss1TargetFrameTextureFrameTexture",
    "Boss2TargetFrameTextureFrameTexture",
    "Boss3TargetFrameTextureFrameTexture",
    "Boss4TargetFrameTextureFrameTexture",
    "Boss5TargetFrameTextureFrameTexture",
    "Boss1TargetFrameSpellBarBorder",
    "Boss2TargetFrameSpellBarBorder",
    "Boss3TargetFrameSpellBarBorder",
    "Boss4TargetFrameSpellBarBorder",
    "Boss5TargetFrameSpellBarBorder",
    "RuneButtonIndividual1BorderTexture",
    "RuneButtonIndividual2BorderTexture",
    "RuneButtonIndividual3BorderTexture",
    "RuneButtonIndividual4BorderTexture",
    "RuneButtonIndividual5BorderTexture",
    "RuneButtonIndividual6BorderTexture",
    "CastingBarFrameBorder",
    "FocusFrameSpellBarBorder",
    "TargetFrameSpellBarBorder",
    -- MainMenuBar
    "SlidingActionBarTexture0",
    "SlidingActionBarTexture1",
    "BonusActionBarTexture0",
    "BonusActionBarTexture1",
    "BonusActionBarTexture",
    "MainMenuBarTexture0",
    "MainMenuBarTexture1",
    "MainMenuBarTexture2",
    "MainMenuBarTexture3",
    "MainMenuMaxLevelBar0",
    "MainMenuMaxLevelBar1",
    "MainMenuMaxLevelBar2",
    "MainMenuMaxLevelBar3",
    "MainMenuXPBarTextureLeftCap",
    "MainMenuXPBarTextureRightCap",
    "MainMenuXPBarTexture0",
    "MainMenuXPBarTexture1",
    "MainMenuXPBarTexture2",
    "MainMenuXPBarTexture3",
    "MainMenuXPBarTextureMid",
    "ReputationWatchBarTexture0",
    "ReputationWatchBarTexture1",
    "ReputationWatchBarTexture2",
    "ReputationWatchBarTexture3",
    "ReputationXPBarTexture0",
    "ReputationXPBarTexture1",
    "ReputationXPBarTexture2",
    "ReputationXPBarTexture3",
    "MainMenuBarLeftEndCap",
    "MainMenuBarRightEndCap",
    "StanceBarLeft",
    "StanceBarMiddle",
    "StanceBarRight",
    "ShapeshiftBarLeft",
    "ShapeshiftBarMiddle",
    "ShapeshiftBarRight",
    -- ArenaFrames
    "ArenaEnemyFrame1Texture",
    "ArenaEnemyFrame2Texture",
    "ArenaEnemyFrame3Texture",
    "ArenaEnemyFrame4Texture",
    "ArenaEnemyFrame5Texture",
    "ArenaEnemyFrame1SpecBorder",
    "ArenaEnemyFrame2SpecBorder",
    "ArenaEnemyFrame3SpecBorder",
    "ArenaEnemyFrame4SpecBorder",
    "ArenaEnemyFrame5SpecBorder",
    "ArenaEnemyFrame1PetFrameTexture",
    "ArenaEnemyFrame2PetFrameTexture",
    "ArenaEnemyFrame3PetFrameTexture",
    "ArenaEnemyFrame4PetFrameTexture",
    "ArenaEnemyFrame5PetFrameTexture",
    "ArenaPrepFrame1Texture",
    "ArenaPrepFrame2Texture",
    "ArenaPrepFrame3Texture",
    "ArenaPrepFrame4Texture",
    "ArenaPrepFrame5Texture",
    "ArenaPrepFrame1SpecBorder",
    "ArenaPrepFrame2SpecBorder",
    "ArenaPrepFrame3SpecBorder",
    "ArenaPrepFrame4SpecBorder",
    "ArenaPrepFrame5SpecBorder",
    -- PANES
    "CharacterFrameTitleBg",
    "CharacterFrameBg",
    -- MINIMAP
    "MinimapBorder",
    "MinimapBorderTop",
    "MiniMapTrackingButtonBorder",
    "TargetFrameSpellBarBorderShield",
    "FocusFrameSpellBarBorderShield",
}

S.originalColors = {}

-- Darken texture (simple function to apply color to texture)
local function Darken_Texture(texture)
    if not texture then return end
    -- Store original color if not already stored
    if not S.originalColors[texture] then
        local r, g, b, a = texture:GetVertexColor()
        S.originalColors[texture] = {r = r, g = g, b = b, a = a}
    end
    -- Apply dark color
    texture:SetVertexColor(S.darkModeConfig.color.r, S.darkModeConfig.color.g, S.darkModeConfig.color.b, S.darkModeConfig.color.a)
end

-- Restore original texture color
local function Restore_Texture(texture)
    if not texture then return end
    if S.originalColors[texture] then
        local orig = S.originalColors[texture]
        texture:SetVertexColor(orig.r, orig.g, orig.b, orig.a)
    else
        -- If no original color stored, restore to white (default Blizzard texture color)
        texture:SetVertexColor(1, 1, 1, 1)
    end
end

S.darkenedButtons = {}

-- Darken action button (excluding equipped border)
local function Darken_Button(name)
    local db = DB()
    if not db or not db.enabled or db.enableDarkMode ~= 1 then return end
    if not name or not _G[name] or S.darkenedButtons[name] then return end
    S.darkenedButtons[name] = true
    local btn = _G[name]

    -- Don't darken border - it's used for equipped items indication
    -- Border will keep its original behavior for showing equipped items

    -- Darken normal texture
    local t = _G[name .. "NormalTexture2"] or _G[name .. "NormalTexture"] or (btn.GetNormalTexture and btn:GetNormalTexture())
    if t then
        Darken_Texture(t)
    end
end

-- Restore action button
local function Restore_Button(name)
    if not name or not _G[name] or not S.darkenedButtons[name] then return end
    local btn = _G[name]

    -- Don't restore border - it wasn't darkened in the first place

    -- Restore normal texture
    local t = _G[name .. "NormalTexture2"] or _G[name .. "NormalTexture"] or (btn.GetNormalTexture and btn:GetNormalTexture())
    if t then
        Restore_Texture(t)
    end
    
    S.darkenedButtons[name] = nil
end

-- Darken bag button
local function Darken_BagButton(name)
    local db = DB()
    if not db or not db.enabled or db.enableDarkMode ~= 1 then return end
    if not name or not _G[name] or S.darkenedButtons[name] then return end
    S.darkenedButtons[name] = true
    local btn = _G[name]

    -- Darken normal texture
    local t = _G[name .. "NormalTexture"] or (btn.GetNormalTexture and btn:GetNormalTexture())
    if t then
        Darken_Texture(t)
    end
end

-- Restore bag button
local function Restore_BagButton(name)
    if not name or not _G[name] or not S.darkenedButtons[name] then return end
    local btn = _G[name]

    -- Restore normal texture
    local t = _G[name .. "NormalTexture"] or (btn.GetNormalTexture and btn:GetNormalTexture())
    if t then
        Restore_Texture(t)
    end
    
    S.darkenedButtons[name] = nil
end

-- Apply dark mode
local function ApplyDarkMode()
    local db = DB()
    if not db or not db.enabled or db.enableDarkMode ~= 1 then return end
    
    -- Update config color from database
    if db.darkModeColor then
        S.darkModeConfig.color.r = db.darkModeColor.r or 0.37
        S.darkModeConfig.color.g = db.darkModeColor.g or 0.37
        S.darkModeConfig.color.b = db.darkModeColor.b or 0.37
        S.darkModeConfig.color.a = db.darkModeColor.a or 1
    end
    
    -- Darken frames
    for _, frameName in pairs(S.darkModeFramesList) do
        Darken_Texture(_G[frameName])
    end
    
    -- Darken action buttons
    for i = 0, NUM_ACTIONBAR_BUTTONS do
        Darken_Button("ActionButton" .. i)
        Darken_Button("BonusActionButton" .. i)
        Darken_Button("MultiBarBottomLeftButton" .. i)
        Darken_Button("MultiBarBottomRightButton" .. i)
        Darken_Button("MultiBarRightButton" .. i)
        Darken_Button("MultiBarLeftButton" .. i)
        Darken_Button("ShapeshiftButton" .. i)
        Darken_Button("PetActionButton" .. i)

        if i <= 3 then
            Darken_BagButton("CharacterBag" .. i .. "Slot")
        end
    end
    Darken_BagButton("MainMenuBarBackpackButton")
end

-- Restore original colors
local function RestoreDarkMode()
    -- Restore all frames
    for _, frameName in pairs(S.darkModeFramesList) do
        Restore_Texture(_G[frameName])
    end
    
    -- Restore action buttons
    for i = 0, NUM_ACTIONBAR_BUTTONS do
        Restore_Button("ActionButton" .. i)
        Restore_Button("BonusActionButton" .. i)
        Restore_Button("MultiBarBottomLeftButton" .. i)
        Restore_Button("MultiBarBottomRightButton" .. i)
        Restore_Button("MultiBarRightButton" .. i)
        Restore_Button("MultiBarLeftButton" .. i)
        Restore_Button("ShapeshiftButton" .. i)
        Restore_Button("PetActionButton" .. i)

        if i <= 3 then
            Restore_BagButton("CharacterBag" .. i .. "Slot")
        end
    end
    Restore_BagButton("MainMenuBarBackpackButton")
    
    -- Clear stored colors
    wipe(S.originalColors)
    -- Clear darkened buttons
    wipe(S.darkenedButtons)
end

-- Apply DarkMode settings
function module:ApplyDarkMode()
    local db = DB()
    if not db or not db.enabled then
        if S.darkModeInitialized then
            self:DisableDarkMode()
        end
        return
    end
    
    if db.enableDarkMode == 1 then
        if not S.darkModeInitialized then
            self:EnableDarkMode()
        else
            -- Re-apply if already initialized
            ApplyDarkMode()
        end
    else
        -- Restore colors immediately when disabled
        RestoreDarkMode()
        if S.darkModeInitialized then
            self:DisableDarkMode()
        end
    end
end

-- Enable DarkMode
function module:EnableDarkMode()
    local db = DB()
    if not db or not db.enabled or db.enableDarkMode ~= 1 then return end
    if S.darkModeInitialized then return end -- Already enabled
    
    -- Create event frame
    if not S.darkModeFrame then
        S.darkModeFrame = CreateFrame("Frame")
    end
    
    -- Register PLAYER_ENTERING_WORLD to apply dark mode
    S.darkModeFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    S.darkModeFrame:SetScript("OnEvent", function(self, event)
        local checkDb = DB()
        if not checkDb or not checkDb.enabled or checkDb.enableDarkMode ~= 1 then return end
        
        if event == "PLAYER_ENTERING_WORLD" then
            ApplyDarkMode()
        end
    end)
    
    -- Apply immediately
    ApplyDarkMode()
    
    S.darkModeInitialized = true
end

-- Disable DarkMode
function module:DisableDarkMode()
    if not S.darkModeInitialized then return end
    
    -- Restore original colors
    RestoreDarkMode()
    
    -- Unregister all events
    if S.darkModeFrame then
        S.darkModeFrame:UnregisterAllEvents()
        S.darkModeFrame:SetScript("OnEvent", nil)
    end
    
    S.darkModeInitialized = false
end

function module:ApplyLootRollCounts()
    local db = DB()
    local lrc = _G.SarychUI_LootRollCounts
    if not lrc then return end
    local enabledFlag = db and db.enableLootRollCounts
    if not db or not db.enabled or enabledFlag == false or enabledFlag == 0 then
        lrc.Disable()
        return
    end
    lrc.Enable()
end

-- ============================================================================
-- Boss Frames desync fix (Blizzard BossNTargetFrame)
-- ============================================================================
-- Visibility: TargetFrame_Update hides when not UnitExists (engage / leave).
-- Dead overlay: TargetFrame_CheckDead shows when UnitHealth <= 0; hides when
-- health returns. Resurrecting bosses keep the unit token — only CheckDead
-- clears "Dead". Private servers often skip UNIT_HEALTH / engage → stuck UI.
-- (No new chunk-level locals — tools/module.lua is at Lua's 200-local limit.)

S.bossFramesFixFrame = nil
S.bossFramesFixEnabled = false

function module:SyncBossFrameDeadText(frame, unit)
	if not frame or not frame.deadText then
		return
	end
	-- Mirror Blizzard TargetFrame_CheckDead (3.3.5a).
	if UnitExists(unit) and UnitIsConnected(unit) and (UnitHealth(unit) or 0) <= 0 then
		frame.deadText:Show()
	else
		frame.deadText:Hide()
	end
end

function module:ResyncBossFrames()
	local db = DB()
	if not db or db.enabled ~= true then
		return
	end
	if db.fixBossFrames ~= 1 and db.fixBossFrames ~= true then
		return
	end
	for i = 1, 5 do
		local frame = _G["Boss" .. i .. "TargetFrame"]
		if frame then
			local unit = frame.unit or ("boss" .. i)
			if type(TargetFrame_Update) == "function" then
				pcall(TargetFrame_Update, frame)
			end
			if type(TargetFrame_UpdateRaidTargetIcon) == "function" then
				pcall(TargetFrame_UpdateRaidTargetIcon, frame)
			end
			-- Explicit dead-text sync after Update (hooks may skip CheckDead).
			self:SyncBossFrameDeadText(frame, unit)
			-- Safety if TargetFrame_Update was hooked and skipped Hide.
			if frame:IsShown() and not UnitExists(unit) then
				frame:Hide()
			end
		end
	end
	if type(UIParent_ManageFramePositions) == "function" then
		pcall(UIParent_ManageFramePositions)
	end
end

function module:EnableFixBossFrames()
	local db = DB()
	if S.bossFramesFixEnabled then
		return
	end
	if not db or db.enabled ~= true then
		return
	end
	if db.fixBossFrames ~= 1 and db.fixBossFrames ~= true then
		return
	end

	if not S.bossFramesFixFrame then
		S.bossFramesFixFrame = CreateFrame("Frame")
	end
	local f = S.bossFramesFixFrame
	f:UnregisterAllEvents()
	f:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
	f:RegisterEvent("PLAYER_REGEN_ENABLED")
	f:RegisterEvent("PLAYER_ENTERING_WORLD")
	f:RegisterEvent("PLAYER_LEAVING_WORLD")
	-- Blizzard BossTargetFrame uses UNIT_HEALTH → TargetFrame_CheckDead.
	f:RegisterEvent("UNIT_HEALTH")
	f:RegisterEvent("UNIT_MAXHEALTH")
	f._bossDeadWatch = 0
	f:SetScript("OnEvent", function(_, event, unit)
		if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
			if type(unit) ~= "string" or strsub(unit, 1, 4) ~= "boss" then
				return
			end
		end
		module:ResyncBossFrames()
	end)
	-- If UNIT_HEALTH never fires on resurrect, clear stuck "Dead" while shown.
	f:SetScript("OnUpdate", function(self, elapsed)
		self._bossDeadWatch = (self._bossDeadWatch or 0) + elapsed
		if self._bossDeadWatch < 0.3 then
			return
		end
		self._bossDeadWatch = 0
		local stuck = false
		for i = 1, 5 do
			local frame = _G["Boss" .. i .. "TargetFrame"]
			if frame and frame:IsShown() and frame.deadText and frame.deadText:IsShown() then
				local unit = frame.unit or ("boss" .. i)
				if UnitExists(unit) and (UnitHealth(unit) or 0) > 0 then
					stuck = true
					break
				end
			end
		end
		if stuck then
			module:ResyncBossFrames()
		end
	end)

	S.bossFramesFixEnabled = true
	self:ResyncBossFrames()
end

function module:DisableFixBossFrames()
	if S.bossFramesFixFrame then
		S.bossFramesFixFrame:UnregisterAllEvents()
		S.bossFramesFixFrame:SetScript("OnEvent", nil)
		S.bossFramesFixFrame:SetScript("OnUpdate", nil)
	end
	S.bossFramesFixEnabled = false
end

function module:ApplyFixBossFrames()
	local db = DB()
	local enabled = db and db.enabled == true and (db.fixBossFrames == 1 or db.fixBossFrames == true)
	if enabled then
		-- Re-enable so UNIT_HEALTH / OnUpdate watch are always installed after /reload or toggle.
		self:DisableFixBossFrames()
		self:EnableFixBossFrames()
	else
		self:DisableFixBossFrames()
	end
end

-- Apply all settings
function module:ApplyAllSettings()
    self:ApplyFocuser()
    self:ApplyArenaRightClickFocus()  -- Arena right-click focus
    self:ApplyEscToOk()
    self:ApplyLootReanchor()
    self:ApplyLootRollCounts()
    if self.ApplyQuestTrackerStyle then
        self:ApplyQuestTrackerStyle()
    end
    self:ApplyDispelHighlight()
    self:ApplyPetNameShortening()
    self:ApplyAltCD()
    self:ApplyAltUnitBars()
    self:ApplyAltAuras()
    self:ApplyAltFPS()
    self:ApplySpeedyLoad()
    self:ApplyTooltipCursor()
    self:ApplyCastbarTimers()
    self:ApplyInviteCountdown()
    self:ApplyArenaCountdown()
    self:ApplyArenaPointer()
    self:ApplyShowFlightTimes()
    self:ApplyEasyItemDestroy()
    self:ApplyBadgeStackBuyer()
    -- Combat text / error filter / boss emotes: floating_text module
    local floating = SarychUI and SarychUI.modules and SarychUI.modules.floating_text
    if floating and floating.ApplyAll then
        floating:ApplyAll()
    else
        self:ApplyCombatTextAdjust()
        self:ApplyRaidBossEmoteReposition()
        self:ApplyErrorFilter()
    end
    self:ApplyBlizzMove()
    self:ApplyDarkMode()
    self:ApplyFixBossFrames()
    self:ApplyTranslitAliases()
    self:ApplyClearChatSlash()
    self:ApplyVipCommands()
    self:ApplyPpMessageFix()
    self:ApplyWoWCircleSystemFilter()
end

function module:ApplyTranslitAliases()
    local db = DB()
    if not db or db.enabled ~= true then
        if _G.ApplyTranslitAliases then
            _G.ApplyTranslitAliases(false)
        elseif _G.DisableTranslitAliases then
            _G.DisableTranslitAliases()
        end
        return
    end
    local on = db.translitAliasesEnabled == 1 or db.translitAliasesEnabled == true
    if _G.EnableTranslitAliases then
        _G.EnableTranslitAliases(on)
    end
    if _G.ApplyTranslitAliases then
        _G.ApplyTranslitAliases(on)
    end
end

function module:ApplyClearChatSlash()
    local db = DB()
    if not db or db.enabled ~= true then
        if _G.ApplyClearChatSlashCommands then
            _G.ApplyClearChatSlashCommands(false)
        end
        return
    end
    local on = db.clearChatSlashEnabled == 1 or db.clearChatSlashEnabled == true
    if _G.ApplyClearChatSlashCommands then
        _G.ApplyClearChatSlashCommands(on)
    end
end

function module:ApplyVipCommands()
    local db = DB()
    if not db or db.enabled ~= true then
        self:DisableVipCommands()
        return
    end
    local on = db.enableCircleContextMenu == 1 or db.enableCircleContextMenu == true
    if on then
        if _G.EnableVipCommands then
            _G.EnableVipCommands(true)
        end
        if _G.ApplyVipCommands then
            _G.ApplyVipCommands()
        end
        if _G.InitializeChatMenuButton then
            _G.InitializeChatMenuButton()
        end
    else
        self:DisableVipCommands()
    end
end

function module:DisableVipCommands()
    if _G.DisableVipCommands then
        _G.DisableVipCommands()
    end
end

function module:ApplyPpMessageFix()
    local db = DB()
    if not db or db.enabled ~= true then
        if _G.DisablePpMessageFix then
            _G.DisablePpMessageFix()
        end
        -- Keep filter registration in sync via system filter apply
        self:ApplyWoWCircleSystemFilter()
        return
    end
    local on = db.ppMessageFixEnabled == 1 or db.ppMessageFixEnabled == true
    if on then
        if _G.EnablePpMessageFix then
            _G.EnablePpMessageFix(true)
        end
    else
        if _G.DisablePpMessageFix then
            _G.DisablePpMessageFix()
        end
    end
    self:ApplyWoWCircleSystemFilter()
end

function module:ApplyWoWCircleSystemFilter()
    local db = DB()
    local filter = _G.CHAT_MSG_SYSTEM_wowcircle_filter
    if not filter or not ChatFrame_AddMessageEventFilter then
        return
    end
    -- Always remove first to avoid duplicates
    if ChatFrame_RemoveMessageEventFilter then
        ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", filter)
    end
    if not db or db.enabled ~= true then
        return
    end
    local ppOn = db.ppMessageFixEnabled == 1 or db.ppMessageFixEnabled == true
    local combatOn = db.spamFilterCombatDifficulty == 1 or db.spamFilterCombatDifficulty == true
    if ppOn or combatOn then
        ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", filter)
    end
end

function module:DisableWoWCircleSystemFilter()
    local filter = _G.CHAT_MSG_SYSTEM_wowcircle_filter
    if filter and ChatFrame_RemoveMessageEventFilter then
        ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", filter)
    end
    if _G.DisablePpMessageFix then
        _G.DisablePpMessageFix()
    end
end

function module:DisableTranslitAliases()
    if _G.DisableTranslitAliases then
        _G.DisableTranslitAliases()
    end
    if _G.ApplyTranslitAliases then
        _G.ApplyTranslitAliases(false)
    end
end

function module:DisableClearChatSlash()
    if _G.ApplyClearChatSlashCommands then
        _G.ApplyClearChatSlashCommands(false)
    end
end

function module:Enable()
    local db = DB()
    if not db or db.enabled ~= true then return end

    InstallTargetFrameAuraGuard()

    -- Create scanner frame for group updates
    if not S.scannerFrame then
        S.scannerFrame = CreateFrame("Frame")
        S.scannerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        S.scannerFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
        S.scannerFrame:RegisterEvent("RAID_ROSTER_UPDATE")
        S.scannerFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
        S.scannerFrame:SetScript("OnEvent", function()
            -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
            local checkDb = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
            if not checkDb or not checkDb.enabled then return end
            
            pcall(UpdateCompactParty)
        end)
        
        -- Periodic scanning for raid groups (via SarychUI.Runtime dispatcher)
        local function ToolsScannerTick()
            local checkDb = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
            if not checkDb or not checkDb.enabled then return end
            pcall(UpdateCompactParty)
        end
        if SarychUI and SarychUI.Runtime and SarychUI.Runtime.RegisterUpdate then
            SarychUI.Runtime:RegisterUpdate("tools.scanner", 2.0, ToolsScannerTick)
            S.scannerUsesRuntime = true
        else
            local scanTimer = 0
            S.scannerFrame:SetScript("OnUpdate", function(self, elapsed)
                local checkDb = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
                if not checkDb or not checkDb.enabled then return end
                scanTimer = scanTimer + elapsed
                if scanTimer >= 2.0 then
                    scanTimer = 0
                    pcall(UpdateCompactParty)
                end
            end)
            S.scannerUsesRuntime = false
            if SarychUI and SarychUI.RegisterPerfOnUpdate then
                SarychUI:RegisterPerfOnUpdate("tools.scanner", S.scannerFrame)
            end
        end
    end
    
    -- Apply all settings
    self:ApplyAllSettings()
    
    -- Initial update
    UpdateCompactParty()
end

function module:Disable()
    -- Disable focuser
    self:DisableFocuser()
    
    -- Disable EscToOK
    self:DisableEscToOk()
    
    -- Disable loot reanchor
    self:DisableLootReanchor()

    -- Quest tracker: restore classic WatchFrame when tools disabled
    if self.RestoreQuestTrackerClassic then
        self:RestoreQuestTrackerClassic()
    elseif _G.SarychUI_QuestTracker and _G.SarychUI_QuestTracker.RestoreClassic then
        _G.SarychUI_QuestTracker.RestoreClassic()
    end
    
    -- Dispel highlight lives under «Ауры»; pet name shortening under «Фреймы».
    -- They stay active when tools is disabled.
    
    -- Disable alt CD announcement
    self:DisableAltCD()
    
    -- Disable alt FPS
    self:DisableAltFPS()
    
    -- SpeedyLoad is system-level; keep running when tools module is disabled.
    
    -- Disable tooltip cursor
    self:DisableTooltipCursor()
    
    -- Castbar / invite / arena countdown timers live under «Текст перезарядки» (cc)
    -- and stay active when tools is disabled.
    
    -- Disable arena pointer
    self:DisableArenaPointer()
    
    -- Disable flight times
    self:DisableShowFlightTimes()
    
    -- Disable easy item destroy
    self:DisableEasyItemDestroy()
    
    -- Disable badge stack buyer
    self:DisableBadgeStackBuyer()
    
    -- Combat text / error filter / boss emotes live under floating_text module.
    
    -- Disable BlizzMove
    self:DisableBlizzMove()
    
    -- Disable DarkMode
    self:DisableDarkMode()

    -- Disable boss frames desync fix
    self:DisableFixBossFrames()

    -- Chat extras / WoWCircle owned by tools
    self:DisableTranslitAliases()
    self:DisableClearChatSlash()
    self:DisableVipCommands()
    self:DisableWoWCircleSystemFilter()
    
    -- Unregister scanner events
    if S.scannerFrame then
        S.scannerFrame:UnregisterAllEvents()
        S.scannerFrame:SetScript("OnEvent", nil)
        S.scannerFrame:SetScript("OnUpdate", nil)
    end
    if S.scannerUsesRuntime and SarychUI and SarychUI.Runtime and SarychUI.Runtime.UnregisterUpdate then
        SarychUI.Runtime:UnregisterUpdate("tools.scanner")
        S.scannerUsesRuntime = false
    end
    
    -- Note: We keep the CreateFrame hook as it checks module status
    -- This prevents issues if the module is re-enabled later
end

-- Public: ensure drag frames for combat text are registered (used by options toggles)
function module:RegisterCombatTextDragFrames()
    local db = FloatingTextDB(); if not db then return end
    if not SarychUI or not SarychUI.DragMode then return end
    if not S.combatTextPlusAnchor then
        S.combatTextPlusAnchor = CreateFrame("Frame", "SarychUI_CombatTextPlusAnchor", UIParent)
        S.combatTextPlusAnchor:SetSize(220, 120)
    end
    if not S.combatTextMinusAnchor then
        S.combatTextMinusAnchor = CreateFrame("Frame", "SarychUI_CombatTextMinusAnchor", UIParent)
        S.combatTextMinusAnchor:SetSize(220, 120)
    end
    if not S.combatTextLessAnchor then
        S.combatTextLessAnchor = CreateFrame("Frame", "SarychUI_CombatTextLessDragAnchor", UIParent)
        S.combatTextLessAnchor:SetSize(220, 120)
    end
    local function CombatTextOnPositionChanged(frameId, xKey, yKey, xOfs, yOfs)
        local panel = SarychUI and SarychUI.CombatTextDragPanel
        if panel and panel.IsOpen and panel:IsOpen() and panel.OnDragPosition then
            if panel:OnDragPosition(frameId, xOfs, yOfs) then
                return
            end
        end
        -- Fallback when panel is not open: write immediately (legacy).
        local save = FloatingTextDB(); if not save then return end
        save[xKey] = xOfs
        save[yKey] = yOfs
        if module and module.ApplyCombatTextAdjust then module:ApplyCombatTextAdjust() end
    end

    SarychUI.DragMode:RegisterFrame("combatTextPlus", S.combatTextPlusAnchor, {
        dragText = "+ Текст боя",
        getPoint = function()
            local panel = SarychUI and SarychUI.CombatTextDragPanel
            if panel and panel.IsOpen and panel:IsOpen() and panel.GetFrameId and panel:GetFrameId() == "combatTextPlus" then
                local dx, dy = panel:GetDraft()
                if dx ~= nil then return {"CENTER", UIParent, "CENTER", dx, dy} end
            end
            local x = db and db.healPlusX or -200
            local y = db and db.healPlusY or -70
            return {"CENTER", UIParent, "CENTER", x, y}
        end,
        getScale = function() return 1.0 end,
        onPositionChanged = function(point, relativePoint, xOfs, yOfs)
            CombatTextOnPositionChanged("combatTextPlus", "healPlusX", "healPlusY", xOfs, yOfs)
        end,
    })
    SarychUI.DragMode:RegisterFrame("combatTextMinus", S.combatTextMinusAnchor, {
        dragText = "- Текст боя",
        getPoint = function()
            local panel = SarychUI and SarychUI.CombatTextDragPanel
            if panel and panel.IsOpen and panel:IsOpen() and panel.GetFrameId and panel:GetFrameId() == "combatTextMinus" then
                local dx, dy = panel:GetDraft()
                if dx ~= nil then return {"CENTER", UIParent, "CENTER", dx, dy} end
            end
            local x = db and db.healMinusX or 0
            local y = db and db.healMinusY or 0
            return {"CENTER", UIParent, "CENTER", x, y}
        end,
        getScale = function() return 1.0 end,
        onPositionChanged = function(point, relativePoint, xOfs, yOfs)
            CombatTextOnPositionChanged("combatTextMinus", "healMinusX", "healMinusY", xOfs, yOfs)
        end,
    })
    SarychUI.DragMode:RegisterFrame("combatTextLess", S.combatTextLessAnchor, {
        dragText = "< Текст боя",
        getPoint = function()
            local panel = SarychUI and SarychUI.CombatTextDragPanel
            if panel and panel.IsOpen and panel:IsOpen() and panel.GetFrameId and panel:GetFrameId() == "combatTextLess" then
                local dx, dy = panel:GetDraft()
                if dx ~= nil then return {"CENTER", UIParent, "CENTER", dx, dy} end
            end
            local x = db and db.healLessX or -250
            local y = db and db.healLessY or -30
            return {"CENTER", UIParent, "CENTER", x, y}
        end,
        getScale = function() return 1.0 end,
        onPositionChanged = function(point, relativePoint, xOfs, yOfs)
            CombatTextOnPositionChanged("combatTextLess", "healLessX", "healLessY", xOfs, yOfs)
        end,
    })

    -- Убедимся, что начальная позиция применена для всех якорей
    do
        local x = db and db.healPlusX or -200
        local y = db and db.healPlusY or -70
        SarychUI.DragMode:SetFramePosition("combatTextPlus", "CENTER", "CENTER", x, y)
    end
    do
        local x = db and db.healMinusX or 0
        local y = db and db.healMinusY or 0
        SarychUI.DragMode:SetFramePosition("combatTextMinus", "CENTER", "CENTER", x, y)
    end
    do
        local x = db and db.healLessX or -250
        local y = db and db.healLessY or -30
        SarychUI.DragMode:SetFramePosition("combatTextLess", "CENTER", "CENTER", x, y)
    end
end

-- Public: toggle drag mode for specific combat text anchor
function module:ToggleCombatTextDrag(frameId, enabled)
    if not SarychUI or not SarychUI.DragMode then return end
    -- Ensure frames are registered before toggling
    if frameId == "combatTextPlus" or frameId == "combatTextMinus" or frameId == "combatTextLess" then
        if not (SarychUI.DragMode:GetFrameData(frameId)) then
            self:RegisterCombatTextDragFrames()
        end
    end

    local panel = SarychUI.CombatTextDragPanel

    if enabled then
        -- Cancel other open combat-text panel session if switching type.
        if panel and panel.IsOpen and panel:IsOpen() and panel.GetFrameId and panel:GetFrameId() ~= frameId then
            panel:Close(false)
        end

        local db = FloatingTextDB() or {}
        if frameId == "combatTextPlus" then
            local x = db.healPlusX or -200
            local y = db.healPlusY or -70
            SarychUI.DragMode:SetFramePosition("combatTextPlus", "CENTER", "CENTER", x, y)
        elseif frameId == "combatTextMinus" then
            local x = db.healMinusX or 0
            local y = db.healMinusY or 0
            SarychUI.DragMode:SetFramePosition("combatTextMinus", "CENTER", "CENTER", x, y)
        elseif frameId == "combatTextLess" then
            local x = db.healLessX or -250
            local y = db.healLessY or -30
            SarychUI.DragMode:SetFramePosition("combatTextLess", "CENTER", "CENTER", x, y)
        end

        -- Open panel first so it can snapshot grid state before we force it on.
        if panel and panel.Open then
            panel:Open(frameId)
        else
            SarychUI.DragMode:ShowGrid(true)
        end
        SarychUI.DragMode:EnableEditMode(frameId, true, true, true)
    else
        -- Disable without Apply: cancel draft via panel if this session is open.
        if panel and panel.IsOpen and panel:IsOpen() and panel.GetFrameId and panel:GetFrameId() == frameId then
            panel:Close(false)
            return
        end
        SarychUI.DragMode:EnableEditMode(frameId, false, false, false)
        local data = SarychUI.DragMode:GetFrameData(frameId)
        if data and data.dragFrame then data.dragFrame:Hide() end
    end
end

-- Options are provided from options.lua
function module:GetOptions()
    return {}
end
