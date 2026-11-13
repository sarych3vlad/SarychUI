-- Adapted from ElvUI (WoW 3.3.5), Modules/DataTexts/Gold.lua.
local DT = _G.SarychUI_ChatDataTexts
local E, L = DT.Engine, DT.L

--Lua functions
local pairs = pairs
local format = string.format
local tinsert, wipe = tinsert, wipe
--WoW API / Variables
local GetBackpackCurrencyInfo = GetBackpackCurrencyInfo
local GetMoney = GetMoney
local IsLoggedIn = IsLoggedIn
local IsShiftKeyDown = IsShiftKeyDown
local CURRENCY = CURRENCY
local MAX_WATCHED_TOKENS = MAX_WATCHED_TOKENS
local RAID_CLASS_COLORS = RAID_CLASS_COLORS

local currencyString = "|T%s:14:14:0:0:64:64:4:60:4:60|t %s"
local resetCountersFormatter = string.join("", "|cffaaaaaa", L["Reset Counters: Hold Shift + Left Click"], "|r")
local resetDataFormatter = string.join("", "|cffaaaaaa", L["Reset Data: Hold Shift + Right Click"], "|r")

local dataTable = {}
local dataUpdated
local myDataID
local totalGold = 0
local altGold = 0
local profit = 0
local spent = 0

local function BuildDataTable()
	wipe(dataTable)
	altGold = 0

	for charName in pairs(DT.goldDB.gold[E.myrealm]) do
		if DT.goldDB.gold[E.myrealm][charName] then
			local class = DT.goldDB.class[E.myrealm][charName] or "PRIEST"
			local color = class and (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class] or RAID_CLASS_COLORS[class])

			tinsert(dataTable,
				{
					name = charName,
					amount = DT.goldDB.gold[E.myrealm][charName],
					amountText = E:FormatMoney(DT.goldDB.gold[E.myrealm][charName], E.db.datatexts.goldFormat or "BLIZZARD", not E.db.datatexts.goldCoins),
					r = color.r, g = color.g, b = color.b,
				}
			)

			if charName == E.myname then
				myDataID = #dataTable
			else
				altGold = altGold + DT.goldDB.gold[E.myrealm][charName]
			end
		end
	end
end

local function OnEvent(self, event)
	if not IsLoggedIn() then return end

	local curMoney = GetMoney()

	if not dataUpdated and (event == "PLAYER_ENTERING_WORLD" or event == "ELVUI_FORCE_RUN") then
		DT.goldDB.gold = DT.goldDB.gold or {}
		DT.goldDB.gold[E.myrealm] = DT.goldDB.gold[E.myrealm] or {}
		DT.goldDB.gold[E.myrealm][E.myname] = DT.goldDB.gold[E.myrealm][E.myname] or curMoney

		DT.goldDB.class = DT.goldDB.class or {}
		DT.goldDB.class[E.myrealm] = DT.goldDB.class[E.myrealm] or {}
		DT.goldDB.class[E.myrealm][E.myname] = E.myclass

		BuildDataTable()
		dataUpdated = true

		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	end

	local oldMoney = DT.goldDB.gold[E.myrealm][E.myname]

	if oldMoney > curMoney then
		spent = spent - (curMoney - oldMoney)
	else
		profit = profit + (curMoney - oldMoney)
	end

	DT.goldDB.gold[E.myrealm][E.myname] = curMoney
	totalGold = altGold + curMoney

	local formattedMoney = E:FormatMoney(curMoney, E.db.datatexts.goldFormat or "BLIZZARD", not E.db.datatexts.goldCoins)

	dataTable[myDataID].amount = curMoney
	dataTable[myDataID].amountText = formattedMoney

	self.text:SetText(formattedMoney)
end

local function OnEnter(self)
	if not DT:SetupTooltip(self) then return end

	local style = E.db.datatexts.goldFormat or "BLIZZARD"
	local textOnly = not E.db.datatexts.goldCoins

	DT.tooltip:AddLine(L["Session:"])
	DT.tooltip:AddDoubleLine(L["Earned:"], E:FormatMoney(profit, style, textOnly), 1, 1, 1, 1, 1, 1)
	DT.tooltip:AddDoubleLine(L["Spent:"], E:FormatMoney(spent, style, textOnly), 1, 1, 1, 1, 1, 1)

	if profit < spent then
		DT.tooltip:AddDoubleLine(L["Deficit:"], E:FormatMoney(profit - spent, style, textOnly), 1, 0, 0, 1, 1, 1)
	elseif (profit - spent) > 0 then
		DT.tooltip:AddDoubleLine(L["Profit:"], E:FormatMoney(profit - spent, style, textOnly), 0, 1, 0, 1, 1, 1)
	end

	DT.tooltip:AddLine(" ")
	DT.tooltip:AddLine(L["Character: "])

	for _, g in ipairs(dataTable) do
		DT.tooltip:AddDoubleLine(g.name == E.myname and g.name.." |TInterface\\FriendsFrame\\StatusIcon-Online:14|t" or g.name, g.amountText, g.r, g.g, g.b, 1, 1, 1)
	end

	DT.tooltip:AddLine(" ")
	DT.tooltip:AddLine(L["Server: "])
	DT.tooltip:AddDoubleLine(L["Total: "], E:FormatMoney(totalGold, style, textOnly), 1, 1, 1, 1, 1, 1)

	local name, count, currencyType, icon

	for i = 1, MAX_WATCHED_TOKENS do
		name, count, currencyType, icon = GetBackpackCurrencyInfo(i)

		if name and i == 1 then
			DT.tooltip:AddLine(" ")
			DT.tooltip:AddLine(CURRENCY..":")
		end

		if name and count then
			if currencyType == 1 then
				icon = "Interface\\PVPFrame\\PVP-ArenaPoints-Icon"
			elseif currencyType == 2 then
				icon = "Interface\\PVPFrame\\PVP-Currency-"..E.myfaction
			end

			DT.tooltip:AddDoubleLine(format(currencyString, icon, name), count, 1, 1, 1)
		end
	end

	DT.tooltip:AddLine(" ")
	DT.tooltip:AddLine(resetCountersFormatter)
	DT.tooltip:AddLine(resetDataFormatter)

	DT.tooltip:Show()
end

local function OnClick(self, btn)
	if btn == "RightButton" and IsShiftKeyDown() then
		DT.goldDB.gold = nil
		dataUpdated = nil
		OnEvent(self, "PLAYER_ENTERING_WORLD")
		OnEnter(self)
	elseif btn == "LeftButton" then
		if IsShiftKeyDown() then
			profit = 0
			spent = 0
			OnEnter(self)
		else
			OpenAllBags()
		end
	end
end

DT:RegisterDatatext("Gold", {"PLAYER_ENTERING_WORLD", "PLAYER_MONEY", "SEND_MAIL_MONEY_CHANGED", "SEND_MAIL_COD_CHANGED", "PLAYER_TRADE_MONEY", "TRADE_MONEY_CHANGED"}, OnEvent, nil, OnClick, OnEnter, nil, L["Gold"])