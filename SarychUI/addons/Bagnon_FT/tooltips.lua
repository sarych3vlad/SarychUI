--[[
    Bagnon Tooltips
        Does ownership tooltips based on BagnonDB data
--]]

-- Global enabled state
BagnonFTEnabled = BagnonFTEnabled or true;

SarychUI_BagnonFT_LastTooltip = SarychUI_BagnonFT_LastTooltip or {}

-- Function to check if addon is enabled
local function IsEnabled()
	if SarychUI and SarychUI.IsCoordinatedAddOnAllowed then
		return SarychUI:IsCoordinatedAddOnAllowed("Bagnon_FT")
	end
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.Bagnon_FT then
		return SarychUI.db.profile.addons.Bagnon_FT.enabled ~= false;
	end
	return BagnonFTEnabled;
end

local function GetShowOnAlt()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.Bagnon_FT then
		return SarychUI.db.profile.addons.Bagnon_FT.showOnAlt == true
	end
	return false
end

local isAltPressed = false
local isRefreshing = false

local function ShouldShowOwners()
	if not GetShowOnAlt() then
		return true
	end
	return isAltPressed
end

local currentPlayer
local itemInfo = {}
local SILVER = '|cffc7c7cf%s|r'
local TEAL = '|cff00ff9a%s|r'

local function SaveContext(tooltip, itemLink, linesBefore)
	local ctx = SarychUI_BagnonFT_LastTooltip
	ctx.tooltip = tooltip
	ctx.itemLink = itemLink
	ctx.linesBefore = linesBefore
	ctx.ownerLabels = ctx.ownerLabels or {}
end

local function ClearContextIfTooltip(tooltip)
	local ctx = SarychUI_BagnonFT_LastTooltip
	if ctx.tooltip == tooltip then
		ctx.tooltip = nil
		ctx.itemLink = nil
		ctx.linesBefore = nil
		ctx.refresh = nil
		ctx.ownerLabels = nil
	end
end

local function CaptureRefresh(tooltip, refreshFn)
	if not IsEnabled() then return end
	if isRefreshing then return end
	local ctx = SarychUI_BagnonFT_LastTooltip
	ctx.tooltip = tooltip
	ctx.refresh = refreshFn
end

local function removeOwnerLines(tooltip)
	if not tooltip or not tooltip.GetName then return end
	local ctx = SarychUI_BagnonFT_LastTooltip
	if ctx.tooltip ~= tooltip or not ctx.ownerLabels then return end

	local tipName = tooltip:GetName()
	if not tipName then return end

	local numLines = tooltip:NumLines() or 0
	local removed = false
	for i = numLines, 1, -1 do
		local left = _G[tipName .. "TextLeft" .. i]
		local text = left and left:GetText()
		if text and ctx.ownerLabels[text] then
			left:SetText(nil)
			left:Hide()
			local right = _G[tipName .. "TextRight" .. i]
			if right then
				right:SetText(nil)
				right:Hide()
			end
			removed = true
		end
	end
	ctx.ownerLabels = {}

	if removed then
		tooltip:Show()
	end
end

-- Function to update current player
local function UpdateCurrentPlayer()
	currentPlayer = UnitName('player')
end

-- Чёрный список предметов по ID
local blacklist = {
    [6948] = true, -- пример: Hearthstone
    [12345] = true, -- добавьте другие ID, которые хотите скрыть
    -- [ID] = true,
}

local function CountsToInfoString(invCount, bankCount, equipCount)
    local info
    local total = invCount + bankCount + equipCount

    if invCount > 0 then
        info = BAGNON_NUM_BAGS:format(invCount)
    end

    if bankCount > 0 then
        local count = BAGNON_NUM_BANK:format(bankCount)
        if info then
            info = strjoin(', ', info, count)
        else
            info = count
        end
    end

    if equipCount > 0 then
        if info then
            info = strjoin(', ', info, BAGNON_EQUIPPED)
        else
            info = BAGNON_EQUIPPED
        end
    end

    if info then
        if total and not(total == invCount or total == bankCount or total == equipCount) then
            -- split into two steps for debugging purposes
            local totalStr = format(TEAL, total)
            return totalStr .. format(SILVER, format(' (%s)', info))
        end
        return format(TEAL, info)
    end
end

-- make up the self-populating table
local function InitializeItemInfo()
    if not IsEnabled() then
        return
    end
    
    -- Update current player
    UpdateCurrentPlayer()
    
    if not BagnonDB or not BagnonDB.GetPlayers then
        return
    end
    
    -- Clear old itemInfo
    itemInfo = {}
    
    for player in BagnonDB:GetPlayers() do
        if player ~= currentPlayer then
            itemInfo[player] = setmetatable({}, {__index = function(self, link)
                local invCount = BagnonDB:GetItemCount(link, KEYRING_CONTAINER, player)
                for bag = 0, NUM_BAG_SLOTS do
                    invCount = invCount + BagnonDB:GetItemCount(link, bag, player)
                end

                local bankCount = BagnonDB:GetItemCount(link, BANK_CONTAINER, player)
                for i = 1, NUM_BANKBAGSLOTS do
                    bankCount = bankCount + BagnonDB:GetItemCount(link, NUM_BAG_SLOTS + i, player)
                end

                local equipCount = BagnonDB:GetItemCount(link, 'e', player)

                self[link] = CountsToInfoString(invCount or 0, bankCount or 0, equipCount or 0) or ''
                return self[link]
            end})
        end
    end
end

local function AddOwners(frame, link)
    local perfStart = SarychUI_PerfDebug and SarychUI_PerfNow and SarychUI_PerfNow() or nil
    if not IsEnabled() then
        return
    end
    if SarychUI_PerfLog then
        SarychUI_PerfLog("Bagnon_FT", "AddOwners", link)
    end

    if not ShouldShowOwners() then
        removeOwnerLines(frame)
        return
    end
    
    -- Update current player
    UpdateCurrentPlayer()
    
    if not BagnonDB or not BagnonDB.GetPlayers then
        return
    end
    
    -- Извлечение ID предмета из ссылки
    local itemID = tonumber(link:match("item:(%d+)"))
    
    -- Проверка на наличие ID в чёрном списке
    if itemID and blacklist[itemID] then
        return -- если предмет в чёрном списке, не добавляем информацию
    end

    removeOwnerLines(frame)

    local linesBefore = frame:NumLines() or 0
    SaveContext(frame, link, linesBefore)

    local added = false
    for player in BagnonDB:GetPlayers() do
        local infoString
        if player == currentPlayer then
            local invCount = BagnonDB:GetItemCount(link, KEYRING_CONTAINER, player)
            for bag = 0, NUM_BAG_SLOTS do
                invCount = invCount + BagnonDB:GetItemCount(link, bag, player)
            end

            local bankCount = BagnonDB:GetItemCount(link, BANK_CONTAINER, player)
            for i = 1, NUM_BANKBAGSLOTS do
                bankCount = bankCount + BagnonDB:GetItemCount(link, NUM_BAG_SLOTS + i, player)
            end

            local equipCount = BagnonDB:GetItemCount(link, 'e', player)

            infoString = CountsToInfoString(invCount or 0, bankCount or 0, equipCount or 0)
        else
            infoString = itemInfo[player] and itemInfo[player][link] or nil
        end

        if infoString and infoString ~= '' then
			local ownerLabel = format(TEAL, player)
			SarychUI_BagnonFT_LastTooltip.ownerLabels[ownerLabel] = true
			frame:AddDoubleLine(ownerLabel, infoString)
            added = true
        end
    end
    if added then
        frame:Show()
    end
    if SarychUI_PerfSlow then
        SarychUI_PerfSlow("Bagnon_FT", "AddOwnersSlow", perfStart, link, 3)
    end
end

local function tryCaptureContextFromMouseFocus()
	if not IsEnabled() then return end
	local ctx = SarychUI_BagnonFT_LastTooltip
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

function BagnonFT_RefreshCurrentTooltip()
	if not IsEnabled() or not GetShowOnAlt() then return end

	local ctx = SarychUI_BagnonFT_LastTooltip
	local tooltip = ctx.tooltip

	if not tooltip or not tooltip:IsShown() then
		if GameTooltip and GameTooltip:IsShown() then
			tooltip = GameTooltip
			ctx.tooltip = tooltip
		else
			return
		end
	end

	if not ctx.refresh then
		tryCaptureContextFromMouseFocus()
	end

	if ctx.refresh then
		isRefreshing = true
		ctx.refresh()
		isRefreshing = false
	elseif ctx.itemLink then
		if ShouldShowOwners() then
			AddOwners(tooltip, ctx.itemLink)
		else
			removeOwnerLines(tooltip)
		end
	end
end

local function onTooltipSetItem(self, ...)
	local perfStart = SarychUI_PerfDebug and SarychUI_PerfNow and SarychUI_PerfNow() or nil
	if not IsEnabled() then
		return
	end

	local itemLink = select(2, self:GetItem())
	if not itemLink or not GetItemInfo(itemLink) then
		return
	end
	if SarychUI_PerfLog then
		SarychUI_PerfLog("Bagnon_FT", "OnTooltipSetItem", itemLink)
	end

	if ShouldShowOwners() then
		AddOwners(self, itemLink)
	else
		SaveContext(self, itemLink, self:NumLines() or 0)
		removeOwnerLines(self)
	end
	if SarychUI_PerfSlow then
		SarychUI_PerfSlow("Bagnon_FT", "OnTooltipSetItemSlow", perfStart, itemLink, 3)
	end
end

local function hookItemSetter(tooltip, method)
	if type(tooltip[method]) == "function" then
		hooksecurefunc(tooltip, method, function(tip, ...)
			if not IsEnabled() then return end
			if SarychUI_PerfLog then
				SarychUI_PerfLog("Bagnon_FT", method, tooltip.GetName and tooltip:GetName() or "tooltip")
			end
			local args = {...}
			CaptureRefresh(tip, function()
				tooltip[method](tooltip, unpack(args))
			end)
		end)
	end
end

local function HookItemSetters(tooltip)
	hookItemSetter(tooltip, "SetBagItem")
	hookItemSetter(tooltip, "SetInventoryItem")
	hookItemSetter(tooltip, "SetMerchantItem")
	hookItemSetter(tooltip, "SetLootItem")
	hookItemSetter(tooltip, "SetQuestItem")
	hookItemSetter(tooltip, "SetQuestLogItem")
	hookItemSetter(tooltip, "SetTradeSkillItem")
	hookItemSetter(tooltip, "SetAuctionItem")
	hookItemSetter(tooltip, "SetGuildBankItem")
	hookItemSetter(tooltip, "SetCraftItem")
	hookItemSetter(tooltip, "SetHyperlink")
end

local tooltipsHooked = {}

local function HookTip(tooltip)
	if not tooltip or tooltipsHooked[tooltip] then
		return
	end
	tooltipsHooked[tooltip] = true

    tooltip:HookScript('OnTooltipSetItem', onTooltipSetItem)
	tooltip:HookScript('OnHide', function(self)
		ClearContextIfTooltip(self)
	end)
	HookItemSetters(tooltip)
end

local function OnAltStateChanged(altPressed)
	if not IsEnabled() then return end
	local showOnAlt = GetShowOnAlt()

	if showOnAlt then
		isAltPressed = altPressed
		local activeTooltip = SarychUI_BagnonFT_LastTooltip.tooltip
		if (GameTooltip and GameTooltip:IsShown()) or (activeTooltip and activeTooltip:IsShown()) then
			if SarychUI and SarychUI.AltMode and SarychUI.AltMode.RequestTooltipRefresh then
				SarychUI.AltMode:RequestTooltipRefresh()
			else
				BagnonFT_RefreshCurrentTooltip()
			end
		end
	else
		isAltPressed = true
	end
end

function BagnonFT_UpdateAltState()
	if SarychUI and SarychUI.AltMode then
		local altPressed = SarychUI.AltMode:IsAltPressed()
		OnAltStateChanged(altPressed)
	end
end

local function InitializeAltMode()
	if SarychUI and SarychUI.AltMode then
		SarychUI.AltMode:RegisterCallback("Bagnon_FT", OnAltStateChanged)

		if GetShowOnAlt() then
			isAltPressed = SarychUI.AltMode:IsAltPressed()
		else
			isAltPressed = true
		end
	else
		isAltPressed = IsAltKeyDown()
	end
end

-- Initialize after BagnonDB is ready
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "SarychUI" then
        UpdateCurrentPlayer()
        HookTip(GameTooltip)
        HookTip(ItemRefTooltip)
		InitializeAltMode()
    elseif event == "PLAYER_LOGIN" then
        UpdateCurrentPlayer()
        InitializeItemInfo()
		InitializeAltMode()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

if SarychUI and SarychUI.AltMode then
	InitializeAltMode()
end
