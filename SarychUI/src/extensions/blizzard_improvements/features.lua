local module = SarychUI.modules.blizzard_improvements
-- Runtime owned by blizzard_improvements; legacy tools profile keys are preserved.
local moduleName = "tools"
local S = {}
local pairs, select, pcall = pairs, select, pcall

local floor, max, min = math.floor, math.max, math.min

local abs, sqrt, deg, atan2, ceil, cos, rad, sin, exp = math.abs, math.sqrt, math.deg, math.atan2, math.ceil, math.cos, math.rad, math.sin, math.exp

local format = string.format

local gsub, find, gmatch = string.gsub, string.find, string.gmatch

local GetTime = GetTime

local function DB()
    if not SarychUI or not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules then
        return nil
    end
    return SarychUI.db.profile.modules[moduleName]
end

local mouseButton = "1"

S.escToOkHooked, S.origCancelOnClick = false, nil


S.flightTimesEnabled, S.flightTimesFrame, S.flightCheckFrame = false, nil, nil

S.flightTimesTracker = { active = false, startTime = 0, duration = 0 }

S.startFlightTimesFunc, S.stopFlightTimesFunc, S.setFlightTimesTextFunc = nil, nil, nil

S.flightAcc, S.flightDataCache, S.flightIconPulsePhase = 0, nil, 0

S.easyItemDestroyEnabled, S.easyDelFrame, S.easyItemDestroyInitFrame = false, nil, nil

S.tooltipCursorAnchored, S.tooltipCursorHooked, S.tooltipCursorEventFrame, S.tooltipCursorAltPressed = false, false, nil, false

S.blizzMoveInitialized, S.blizzMoveFrame = false, nil

S.blizzMovePendingFrames, S.blizzMoveRegenFrame = nil, nil

S.blizzMoveDefaults = {
    AchievementFrame = {save = true},
    CalendarFrame = {save = true},
    AuctionFrame = {save = true},
    GuildBankFrame = {save = true},
}

local BADGE_ITEM_IDS = {
	[40752] = true, -- Emblem of Heroism
	[40753] = true, -- Emblem of Valor
	[45624] = true, -- Emblem of Conquest
	[47241] = true, -- Emblem of Triumph
	[49426] = true, -- Emblem of Frost
}

local BADGE_BUY_PER_FRAME = 1

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
	if not q then
		q = { remaining = 0 }
		S.badgeBuyQueue = q
	end
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

function SarychUI.modules.blizzard_improvements:ApplyBadgeStackBuyer()
	local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
	if not db or not SarychUI:IsBlizzardImprovementsEnabled() then return end

	if not (db.enableBadgeStackBuyer == 1 or db.enableBadgeStackBuyer == true) then
		SarychUI.modules.blizzard_improvements:DisableBadgeStackBuyer()
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
		local enabledFeature = (SarychUI:IsBlizzardImprovementsEnabled()) and (db2.enableBadgeStackBuyer == 1 or db2.enableBadgeStackBuyer == true)
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
					if SarychUI:IsBlizzardImprovementsEnabled() and (db3.enableBadgeStackBuyer == 1 or db3.enableBadgeStackBuyer == true) then
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

function SarychUI.modules.blizzard_improvements:DisableBadgeStackBuyer()
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

function SarychUI.modules.blizzard_improvements:ApplyEscToOk()
    local db = DB()
    if not db then return end

    if db.enableEscToOk == 1 then
        SarychUI.modules.blizzard_improvements:EnableEscToOk()
    else
        SarychUI.modules.blizzard_improvements:DisableEscToOk()
    end
end

function SarychUI.modules.blizzard_improvements:EnableEscToOk()
    local db = DB()
    if not db then return end

    if not SarychUI:IsBlizzardImprovementsEnabled() or db.enableEscToOk ~= 1 then return end

    -- Wait for InterfaceOptionsFrame to be created
    if not InterfaceOptionsFrame then
        -- Try to initialize on next frame update
        local initFrame = CreateFrame("Frame")
        initFrame:SetScript("OnUpdate", function(self)
            if InterfaceOptionsFrame then
                self:SetScript("OnUpdate", nil)
                SarychUI.modules.blizzard_improvements:EnableEscToOk()
            end
        end)
        return
    end

    -- UIParent.lua:ToggleGameMenu already clicks InterfaceOptionsFrameCancel
    -- on Escape. Only redirect that button; EnableKeyboard(true) on the whole
    -- options frame consumes movement keys while the window is open.
    if S.escToOkHooked then
        return
    end

    local function CallOrig(fn, ...)
        if type(fn) == "function" then
            return fn(...)
        end
    end

    -- The stock Escape handler and a direct click both use this button.
    if InterfaceOptionsFrameCancel then
        -- Save original Cancel OnClick script before hooking (only once)
        if S.origCancelOnClick == nil then
            S.origCancelOnClick = InterfaceOptionsFrameCancel:GetScript("OnClick") or false
        end

        InterfaceOptionsFrameCancel:SetScript("OnClick", function(self, button, ...)
            -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
            local checkDb = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
            if not checkDb or not SarychUI:IsBlizzardImprovementsEnabled() or checkDb.enableEscToOk ~= 1 then
                return CallOrig(S.origCancelOnClick, self, button, ...)
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

function SarychUI.modules.blizzard_improvements:DisableEscToOk()
    if not InterfaceOptionsFrame then return end

    local function RestoreScript(frame, handler, orig)
        if not frame or not S.escToOkHooked then return end
        frame:SetScript(handler, type(orig) == "function" and orig or nil)
    end

    RestoreScript(InterfaceOptionsFrameCancel, "OnClick", S.origCancelOnClick)

    -- Reset flag
    S.escToOkHooked = false
    -- Keep the original click handler for a later re-enable.
end

local function RebuildTooltip(anchorMode)
    if not GameTooltip then return end

    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not SarychUI:IsBlizzardImprovementsEnabled() then return end

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

local function IsEasyItemDestroyEnabled()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not SarychUI:IsBlizzardImprovementsEnabled() then return false end
    return db.enableEasyItemDestroy == 1
end

function SarychUI.modules.blizzard_improvements:ApplyEasyItemDestroy()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not SarychUI:IsBlizzardImprovementsEnabled() then
        -- Disable if module is disabled
        if S.easyItemDestroyEnabled then
            SarychUI.modules.blizzard_improvements:DisableEasyItemDestroy()
        end
        return
    end

    -- Check if function is enabled in settings
    if db.enableEasyItemDestroy == 1 then
        -- Check if StaticPopupDialogs is ready
        if StaticPopupDialogs and StaticPopupDialogs["DELETE_GOOD_ITEM"] then
            -- Enable if not already enabled
            if not S.easyItemDestroyEnabled then
                SarychUI.modules.blizzard_improvements:EnableEasyItemDestroy()
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
                        SarychUI.modules.blizzard_improvements:ApplyEasyItemDestroy()
                    end
                end)
            end
        end
    else
        -- Disable if setting is off
        if S.easyItemDestroyEnabled then
            SarychUI.modules.blizzard_improvements:DisableEasyItemDestroy()
        end
        -- Clean up init frame if exists
        if S.easyItemDestroyInitFrame then
            S.easyItemDestroyInitFrame:UnregisterAllEvents()
            S.easyItemDestroyInitFrame:SetScript("OnEvent", nil)
            S.easyItemDestroyInitFrame = nil
        end
    end
end

function SarychUI.modules.blizzard_improvements:EnableEasyItemDestroy()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not SarychUI:IsBlizzardImprovementsEnabled() then return end

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

function SarychUI.modules.blizzard_improvements:DisableEasyItemDestroy()
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

function SarychUI.modules.blizzard_improvements:ApplyShowFlightTimes()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not SarychUI:IsBlizzardImprovementsEnabled() then
        -- Disable if module is disabled
        if S.flightTimesEnabled then
            SarychUI.modules.blizzard_improvements:DisableShowFlightTimes()
        end
        return
    end

    if db.enableShowFlightTimes == 1 then
        -- Enable if not already enabled
        if not S.flightTimesEnabled then
            SarychUI.modules.blizzard_improvements:EnableShowFlightTimes()
        end
    else
        -- Disable if enabled
        if S.flightTimesEnabled then
            SarychUI.modules.blizzard_improvements:DisableShowFlightTimes()
        end
    end
end

local function IsFlightTimesEnabled()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not SarychUI:IsBlizzardImprovementsEnabled() then return false end
    return db.enableShowFlightTimes == 1
end

function SarychUI.modules.blizzard_improvements:EnableShowFlightTimes()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not SarychUI:IsBlizzardImprovementsEnabled() then return end

    if S.flightTimesEnabled then return end -- Already enabled

    -- Create flight times countdown frame (similar to arena countdown)
    local FLIGHT_TIMER_FONT_SIZE = 18
    -- Same winged-boot glyph WDM uses for neutral flight nodes.
    local FLIGHT_TIMER_ICON_TEXTURE = "Interface\\AddOns\\SarychUI\\media\\maps\\objecticonsatlas"
    local FLIGHT_TIMER_ICON_COORDS = { 0.53418, 0.56543, 0.601562, 0.632812 }

    local function ApplyFlightTimerIcon(tex)
        if not tex then return end
        tex:SetTexture(FLIGHT_TIMER_ICON_TEXTURE)
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
        S.flightTimesTracker.routeKey = nil
        S.flightAcc = 0  -- Reset accumulator
        S.flightIconPulsePhase = 0
        S.flightTimesFrame:Hide()
    end

    -- Start flight times
    S.startFlightTimesFunc = function(duration, routeKey)
        if not IsFlightTimesEnabled() then return end
        if S.flightTimesTracker.active then S.stopFlightTimesFunc() end

        -- Reset accumulator
        S.flightAcc = 0
        S.flightIconPulsePhase = 0

        S.flightTimesTracker.active = true
        S.flightTimesTracker.startTime = GetTime()  -- Store start time
        S.flightTimesTracker.duration = duration or 300 -- Default 5 minutes if unknown
        S.flightTimesTracker.routeKey = routeKey

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
    local FinishFlight
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

        -- Hide the countdown on the first frame after leaving the taxi.
        if not UnitOnTaxi("player") then
            FinishFlight()
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
        local flightLib = LibStub and LibStub("LibFlightTime-1.0", true)
        local routeKey
        if flightLib then
            local duration
            duration, routeKey = flightLib:GetDuration(node)
            if duration then return duration, routeKey end
        end

        -- Older coordinate-based data covers custom or renamed taxi nodes.
        -- Load flight data
        local data = LoadFlightDataIfNeeded()

        if not data then
            return 300, routeKey -- Data not available, use default
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
                return 300, routeKey
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
                                    return duration, routeKey
                                end
                            end
                        end
                    end


                    break
                end
            end
        end

        -- Fallback: use default duration
        return 300, routeKey -- 5 minutes default
    end

    -- Hook TakeTaxiNode to detect flight start (like Leatrix_Plus)
    hooksecurefunc("TakeTaxiNode", function(node)
        if not IsFlightTimesEnabled() then
            return
        end

        -- Get flight duration IMMEDIATELY when TakeTaxiNode is called (like Leatrix_Plus does)
        local flightDuration, routeKey = GetFlightDuration(node)

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

            -- 1) If we never got airborne within MAX_START_DELAY -> cancel watcher
            if not seenAirborne and timeSinceStart > MAX_START_DELAY then
                self:Hide()
                ticker = nil
                return
            end

            -- 2) Detect actual takeoff
            if UnitOnTaxi("player") then
                seenAirborne = true
                -- Flight started - start timer with the duration we got at TakeTaxiNode
                S.startFlightTimesFunc(flightDuration, routeKey)
                self:Hide()
                ticker = nil
                return
            end

            -- 3) After having been airborne, first false -> real landing
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

    -- Keep the periodic check as a backup when the timer frame is not updating.
    FinishFlight = function()
        local tracker = S.flightTimesTracker
        if tracker and tracker.active and tracker.routeKey and tracker.startTime then
            local measured = GetTime() - tracker.startTime
            if measured >= tracker.duration * 0.85 then
                local flightLib = LibStub and LibStub("LibFlightTime-1.0", true)
                if flightLib then
                    flightLib:RecordDuration(tracker.routeKey, measured, tracker.duration)
                end
            end
        end
        S.stopFlightTimesFunc()
    end

    local function FlightCheckTick()
        if not IsFlightTimesEnabled() then return end
        if not S.flightTimesTracker or not S.flightTimesTracker.active then return end
        if not UnitOnTaxi("player") then
            FinishFlight()
        end
    end
    if SarychUI and SarychUI.UpdateScheduler and SarychUI.UpdateScheduler.RegisterUpdate then
        SarychUI.UpdateScheduler:RegisterUpdate("tools.flightCheck", 0.5, FlightCheckTick)
        S.flightCheckUsesScheduler = true
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
                FinishFlight()
            end
        end)
        S.flightCheckFrame:Show()
        S.flightCheckUsesScheduler = false
    end

    S.flightTimesEnabled = true
end

function SarychUI.modules.blizzard_improvements:DisableShowFlightTimes()
    if not S.flightTimesEnabled then return end

    -- Hide frame
    if S.flightTimesFrame then
        S.flightTimesFrame:Hide()
        S.flightTimesFrame:SetScript("OnUpdate", nil)
    end

    -- Hide check frame / unregister scheduled callback
    if S.flightCheckUsesScheduler and SarychUI and SarychUI.UpdateScheduler and SarychUI.UpdateScheduler.UnregisterUpdate then
        SarychUI.UpdateScheduler:UnregisterUpdate("tools.flightCheck")
        S.flightCheckUsesScheduler = false
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

-- Hooks are installed once; callbacks read the current profile and runtime state.
local function TooltipMode()
    local db = DB()
    if not S.tooltipCursorHooked or not db or not SarychUI:IsBlizzardImprovementsEnabled() then return nil end
    if db.enableTooltipCursor ~= 1 and db.enableTooltipCursor ~= true then return nil end
    return db.tooltipMode == "hidden" and "hidden" or "cursor"
end

-- FrameXML uses the same GameTooltip for both default and owner-anchored tips.
-- Keep our own flag: GameTooltip_OnHide clears tooltip.default, even when we hide it.
local function IsDefaultTooltip(tooltip)
    return tooltip == GameTooltip and (S.tooltipDefaultAnchor or S.tooltipCursorAnchored)
end
local function HideDisabledTooltip(tooltip)
    if TooltipMode() == "hidden" and IsDefaultTooltip(tooltip) then tooltip:Hide() end
end

local function TooltipCursorAltCallback(isAltPressed)
    S.tooltipCursorAltPressed = isAltPressed
    local db = DB()
    if TooltipMode() ~= "cursor" or not db or (db.tooltipCursorAltOnly ~= 1 and db.tooltipCursorAltOnly ~= true) then return end
    if GameTooltip and GameTooltip:IsShown() and IsDefaultTooltip(GameTooltip) then
        RebuildTooltip(isAltPressed and "cursor" or "default")
    end
end

function SarychUI.modules.blizzard_improvements:ApplyTooltipCursor()
    local db = DB()
    if not db or not SarychUI:IsBlizzardImprovementsEnabled()
        or (db.enableTooltipCursor ~= 1 and db.enableTooltipCursor ~= true) then
        self:DisableTooltipCursor()
        return
    end
    self:EnableTooltipCursor()
    -- Apply changes to an already visible tooltip immediately.
    if TooltipMode() == "hidden" then
        if GameTooltip then HideDisabledTooltip(GameTooltip) end
    elseif GameTooltip and GameTooltip:IsShown() and IsDefaultTooltip(GameTooltip) then
        local altOnly = db.tooltipCursorAltOnly == 1 or db.tooltipCursorAltOnly == true
        RebuildTooltip((GetMouseFocus() == WorldFrame and (not altOnly or S.tooltipCursorAltPressed)) and "cursor" or "default")
    end
end

function SarychUI.modules.blizzard_improvements:EnableTooltipCursor()
    if not SarychUI:IsBlizzardImprovementsEnabled() then return end
    if not S.tooltipCursorHooked and SarychUI.AltMode then
        SarychUI.AltMode:RegisterCallback("tooltipCursor", TooltipCursorAltCallback)
        S.tooltipCursorAltPressed = SarychUI.AltMode:IsAltPressed() or false
    end
    S.tooltipCursorHooked = true
    if S.tooltipCursorHooksInstalled then return end
    S.tooltipCursorHooksInstalled = true
    S.tooltipDefaultAnchor = GameTooltip.default == 1
    hooksecurefunc(GameTooltip, "SetOwner", function()
        S.tooltipDefaultAnchor = false
        S.tooltipCursorAnchored = false
    end)
    GameTooltip:HookScript("OnShow", HideDisabledTooltip)
    hooksecurefunc(GameTooltip, "Show", HideDisabledTooltip)
    hooksecurefunc(GameTooltip, "FadeOut", function(tooltip)
        if not TooltipMode() or not IsDefaultTooltip(tooltip) then return end
        tooltip:SetAlpha(1)
        tooltip:Hide()
    end)
    hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
        if tooltip ~= GameTooltip then return end
        S.tooltipDefaultAnchor = true
        if TooltipMode() == "hidden" then
            HideDisabledTooltip(tooltip)
            return
        end
        if TooltipMode() ~= "cursor" or GetMouseFocus() ~= WorldFrame then return end
        local db = DB()
        if (db.tooltipCursorAltOnly == 1 or db.tooltipCursorAltOnly == true) and not S.tooltipCursorAltPressed then
            S.tooltipCursorAnchored = false
            return
        end
        tooltip:SetOwner(parent or UIParent, "ANCHOR_CURSOR")
        S.tooltipCursorAnchored = true
    end)
    GameTooltip:HookScript("OnHide", function() S.tooltipCursorAnchored = false end)
end

function SarychUI.modules.blizzard_improvements:DisableTooltipCursor()
    local wasAnchored = S.tooltipCursorAnchored
    S.tooltipCursorHooked = false
    if SarychUI.AltMode then SarychUI.AltMode:UnregisterCallback("tooltipCursor") end
    S.tooltipCursorAnchored = false
    S.tooltipCursorAltPressed = false
    if wasAnchored and GameTooltip and GameTooltip:IsShown() then RebuildTooltip("default") end
end

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

S.QueueBlizzMoveLayout = function(frame)
    if not frame then
        return
    end
    S.blizzMovePendingFrames = S.blizzMovePendingFrames or {}
    S.blizzMovePendingFrames[frame] = true
    if S.blizzMoveRegenFrame then
        return
    end
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function()
        local pending = S.blizzMovePendingFrames
        S.blizzMovePendingFrames = nil
        if not pending then
            return
        end
        local apply = S.ApplyBlizzMoveLayout
        if type(apply) ~= "function" then
            return
        end
        for queued in pairs(pending) do
            if queued and queued.IsShown and queued:IsShown() then
                apply(queued)
            end
        end
    end)
    S.blizzMoveRegenFrame = f
end

local function EnsureCharacterFrameHideHook()
    local characterFrame = _G.CharacterFrame
    if not characterFrame or characterFrame._SarychUI_BlizzMoveHideHook then
        return
    end

    characterFrame._SarychUI_BlizzMoveHideHook = true
    characterFrame:HookScript("OnHide", function(self)
        local db = DB()
        if not db or not SarychUI:IsBlizzardImprovementsEnabled() or db.enableBlizzMove ~= 1 then return end
        if InCombatLockdown and InCombatLockdown() then
            return
        end

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
    S.ApplyBlizzMoveLayout = function(self)
        local db = DB()
        if not db or not SarychUI:IsBlizzardImprovementsEnabled() or db.enableBlizzMove ~= 1 then return end
        if not self then return end

        local frameName = self.GetName and self:GetName()
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

    -- handlers the frame OnShow event
    local function OnShow(self, ...)
        local db = DB()
        if not db or not SarychUI:IsBlizzardImprovementsEnabled() or db.enableBlizzMove ~= 1 then return end
        if InCombatLockdown and InCombatLockdown() then
            S.QueueBlizzMoveLayout(self)
            return
        end
        S.ApplyBlizzMoveLayout(self)
    end

    -- handles frames rescaling
    local function OnMouseWheel(self, ...)
        local db = DB()
        if not db or not SarychUI:IsBlizzardImprovementsEnabled() or db.enableBlizzMove ~= 1 then return end
        if InCombatLockdown and InCombatLockdown() then return end

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
        if not db or not SarychUI:IsBlizzardImprovementsEnabled() or db.enableBlizzMove ~= 1 then return end
        if InCombatLockdown and InCombatLockdown() then return end

        local frameToMove = self.frameToMove
        if not frameToMove then return end
        frameToMove:StartMoving()
        frameToMove.isMoving = true
    end

    -- handles frames OnDragStop
    local function OnDragStop(self)
        local db = DB()
        if not db or not SarychUI:IsBlizzardImprovementsEnabled() or db.enableBlizzMove ~= 1 then return end
        if InCombatLockdown and InCombatLockdown() then return end

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
        if not db or not SarychUI:IsBlizzardImprovementsEnabled() or db.enableBlizzMove ~= 1 then return end

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
        if not db or not SarychUI:IsBlizzardImprovementsEnabled() or db.enableBlizzMove ~= 1 then return end

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
        if not db or not SarychUI:IsBlizzardImprovementsEnabled() or db.enableBlizzMove ~= 1 then return end
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

local function SetupBlizzMoveFrames()
    local db = DB()
    if not db or not SarychUI:IsBlizzardImprovementsEnabled() or db.enableBlizzMove ~= 1 then return end

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

function SarychUI.modules.blizzard_improvements:ApplyBlizzMove()
    local db = DB()
    if not db or not SarychUI:IsBlizzardImprovementsEnabled() then
        if S.blizzMoveInitialized then
            SarychUI.modules.blizzard_improvements:DisableBlizzMove()
        end
        return
    end

    if db.enableBlizzMove == 1 then
        if not S.blizzMoveInitialized then
            SarychUI.modules.blizzard_improvements:EnableBlizzMove()
        else
            -- Re-apply handlers if mouse button changed or already initialized
            -- This ensures handlers are updated when settings change
            SetupBlizzMoveFrames()
        end
    else
        if S.blizzMoveInitialized then
            SarychUI.modules.blizzard_improvements:DisableBlizzMove()
        end
    end
end

function SarychUI.modules.blizzard_improvements:EnableBlizzMove()
    local db = DB()
    if not db or not SarychUI:IsBlizzardImprovementsEnabled() or db.enableBlizzMove ~= 1 then return end
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

function SarychUI.modules.blizzard_improvements:DisableBlizzMove()
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

function SarychUI.modules.blizzard_improvements:ApplyTranslitAliases()
    local db = DB()
    if not db or not SarychUI:IsBlizzardImprovementsEnabled() then
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

function SarychUI.modules.blizzard_improvements:ApplyClearChatSlash()
    local db = DB()
    if not db or not SarychUI:IsBlizzardImprovementsEnabled() then
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

function SarychUI.modules.blizzard_improvements:DisableTranslitAliases()
    if _G.DisableTranslitAliases then
        _G.DisableTranslitAliases()
    end
    if _G.ApplyTranslitAliases then
        _G.ApplyTranslitAliases(false)
    end
end

function SarychUI.modules.blizzard_improvements:DisableClearChatSlash()
    if _G.ApplyClearChatSlashCommands then
        _G.ApplyClearChatSlashCommands(false)
    end
end
