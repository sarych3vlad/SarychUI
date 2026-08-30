-- SarychUI Bags Module — стандартные / ElvUI / BaudBag



local moduleName = "bags"

local module = {}



SarychUI:RegisterModule(moduleName, module)



local DEBUG_ELVUI_BAGS = false



local function bagDebug(...)

	if not DEBUG_ELVUI_BAGS and not _G.SarychUI_DebugBagsPosition then return end

	local text = "Bags: " .. table.concat({ ... }, " ")

	if SarychUI and SarychUI.Print then

		SarychUI:Print(text)

	else

		print(text)

	end

end



local function DB()

	if not SarychUI or not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules then

		return nil

	end

	return SarychUI.db.profile.modules[moduleName]

end



function module:IsEnabled()

	local db = DB()

	return db and db.enabled == true

end



function module:GetMode()

	local db = DB()

	return (db and db.mode) or "default"

end



function module:IsDefaultMode()

	local mode = self:GetMode()

	return mode ~= "elvui" and mode ~= "baudbag"

end



function module:IsElvUIMode()

	return self:GetMode() == "elvui"

end



function module:IsBaudBagMode()

	return self:GetMode() == "baudbag"

end



function module:GetBaudBagWrapper()

	return _G.SarychUI_BaudBag or (SarychUI and SarychUI.addons and SarychUI.addons.BaudBag)

end



function module:StartBaudBagRuntime()

	local wrap = self:GetBaudBagWrapper()

	if wrap and wrap.SetRuntimeEnabled then

		wrap:SetRuntimeEnabled(true)

	end

end



function module:StopBaudBagRuntime()

	local wrap = self:GetBaudBagWrapper()

	if wrap and wrap.SetRuntimeEnabled then

		wrap:SetRuntimeEnabled(false)

	end

end



function module:GetElvUIEngine()

	return _G.SarychUI_Bags and _G.SarychUI_Bags[1]

end



function module:GetElvUIBagsWrapper()

	if SarychUI and SarychUI.GetAddOn then

		local wrapper = SarychUI:GetAddOn("SarychUI_Bags")

		if wrapper then return wrapper end

	end

	return nil

end



function module:IsElvUIBagsLoaded()

	return self:GetElvUIEngine() ~= nil

end



function module:GetElvUISettings()
	local db = DB()
	if not db then return nil end
	db.elvui = db.elvui or {}
	return db.elvui
end

function module:EnsureElvUIDefaultPosition()
	local elv = self:GetElvUISettings()
	if not elv then return nil end
	if type(elv.defaultPosition) ~= "table" then
		local defaults = SarychUI.defaults
			and SarychUI.defaults.profile.modules.bags
			and SarychUI.defaults.profile.modules.bags.elvui
			and SarychUI.defaults.profile.modules.bags.elvui.defaultPosition
		if type(defaults) == "table" then
			elv.defaultPosition = CopyTable(defaults)
		else
			elv.defaultPosition = {
				point = "BOTTOMRIGHT",
				relativePoint = "BOTTOMRIGHT",
				relativeTo = "UIParent",
				x = -20,
				y = 130,
			}
		end
	end
	return elv.defaultPosition
end

function module:EnsureElvUIDefaultBankPosition()
	local elv = self:GetElvUISettings()
	if not elv then return nil end
	if type(elv.defaultBankPosition) ~= "table" then
		local defaults = SarychUI.defaults
			and SarychUI.defaults.profile.modules.bags
			and SarychUI.defaults.profile.modules.bags.elvui
			and SarychUI.defaults.profile.modules.bags.elvui.defaultBankPosition
		if type(defaults) == "table" then
			elv.defaultBankPosition = CopyTable(defaults)
		else
			elv.defaultBankPosition = {
				point = "BOTTOMRIGHT",
				relativePoint = "BOTTOMLEFT",
				relativeTo = "ElvUI_ContainerFrame",
				x = -10,
				y = 0,
			}
		end
	end
	return elv.defaultBankPosition
end

function module:ApplyElvUIBagLayoutSettings()
	self:SyncElvUIEngineFromDB()
	local E = self:GetElvUIEngine()
	local B = E and E.GetModule and E:GetModule("Bags", true)
	if not (B and B.Layout) then return end
	-- Layout() already reapplies SarychUI chrome when embedded.
	if B.BagFrame then
		B:Layout()
	end
	if B.BankFrame then
		B:Layout(true)
	end
end

function module:ApplyElvUIBagScaleSettings()
	local E = self:GetElvUIEngine()
	local B = E and E.GetModule and E:GetModule("Bags", true)
	if not (B and B.ApplySarychUIBagFrameScale) then return end
	if B.BagFrame then
		B:ApplySarychUIBagFrameScale(B.BagFrame)
	end
	if B.BankFrame then
		B:ApplySarychUIBagFrameScale(B.BankFrame)
	end
end

function module:ApplyElvUIBagChromeSettings()
	local E = self:GetElvUIEngine()
	local B = E and E.GetModule and E:GetModule("Bags", true)
	if B and B.ApplySarychUIBagChrome then
		B:ApplySarychUIBagChrome()
	end
end

function module:ApplyElvUIBagFontSettings()
	self:SyncElvUIEngineFromDB()
	local E = self:GetElvUIEngine()
	local B = E and E.GetModule and E:GetModule("Bags", true)
	if B and B.ApplyBagFont then
		B:ApplyBagFont()
	end
	if B and B.ApplyCurrencyLayout then
		B:ApplyCurrencyLayout()
	end
	if B and B.UpdateGoldText then
		B:UpdateGoldText()
	end
end

-- Fast path for footer (money/currency) sliders while dragging.
function module:ApplyElvUIBagFooterSettings()
	local E = self:GetElvUIEngine()
	local B = E and E.GetModule and E:GetModule("Bags", true)
	if B and B.ApplyFooterSettings then
		B:ApplyFooterSettings()
	end
end

function module:ClearElvUIBagSavedWindowPosition()
	local elv = self:GetElvUISettings()
	if elv then
		elv.savedWindowPosition = nil
	end
	local E = self:GetElvUIEngine()
	local B = E and E.GetModule and E:GetModule("Bags", true)
	if B and B.ClearElvUIBagSavedWindowPosition then
		B:ClearElvUIBagSavedWindowPosition()
	end
	self:ApplyElvUIBagWindowPosition()
end

function module:ApplyElvUIBagWindowPosition()
	local E = self:GetElvUIEngine()
	local B = E and E.GetModule and E:GetModule("Bags", true)
	if B and B.ApplyElvUIBagWindowPosition and B.BagFrame then
		B:ApplyElvUIBagWindowPosition(B.BagFrame)
	end
end

function module:ApplyElvUIBagWindowPositionIfDefault()
	local elv = self:GetElvUISettings()
	if elv and elv.savedWindowPosition then return end
	self:ApplyElvUIBagWindowPosition()
end

function module:ClearElvUIBankSavedWindowPosition()
	local elv = self:GetElvUISettings()
	if elv then
		elv.savedBankWindowPosition = nil
	end
	local E = self:GetElvUIEngine()
	local B = E and E.GetModule and E:GetModule("Bags", true)
	if B and B.ClearElvUIBankSavedWindowPosition then
		B:ClearElvUIBankSavedWindowPosition()
	end
	self:ApplyElvUIBankWindowPosition()
end

function module:ApplyElvUIBankWindowPosition()
	local E = self:GetElvUIEngine()
	local B = E and E.GetModule and E:GetModule("Bags", true)
	if B and B.ApplyElvUIBankWindowPosition then
		if B.BankFrame then
			B:ApplyElvUIBankWindowPosition(B.BankFrame)
		end
		bagDebug("ApplyElvUIBankWindowPosition", B.BankFrame and "frame ok" or "frame pending")
	end
end

function module:ApplyElvUIBankWindowPositionIfDefault()
	local elv = self:GetElvUISettings()
	if elv and elv.savedBankWindowPosition then return end
	self:ApplyElvUIBankWindowPosition()
end



function module:SyncElvUIEngineFromDB()

	local E = self:GetElvUIEngine()

	if E and E.SyncBagsRuntimeFromSarychUI then

		E:SyncBagsRuntimeFromSarychUI()

	end

end



function module:StartElvUIBagsRuntime()

	bagDebug("mode =", self:GetMode())
	bagDebug("SarychUI Bags loaded")



	if not self:IsElvUIBagsLoaded() then

		bagDebug("SarychUI Bags engine NOT loaded (check SarychUI.toc embeds)")

		return false

	end



	local E = self:GetElvUIEngine()

	if E and E.CheckElvUIConflict and E:CheckElvUIConflict() then

		bagDebug("ElvUI full addon conflict — embedded bags disabled")

		return false

	end



	self:SyncElvUIEngineFromDB()



	local wrapper = self:GetElvUIBagsWrapper()

	if wrapper and wrapper.SetRuntimeEnabled then

		bagDebug("Enable via SarychUI_Bags wrapper")

		local ok = wrapper:SetRuntimeEnabled(true)
		if ok then
			self:ApplyElvUIBagWindowPosition()
		end
		return ok

	end



	if E and E.StartBagsRuntime then

		bagDebug("Enable via engine StartBagsRuntime (wrapper missing)")

		if not E.loginReady then

			E.loginReady = true

		end

		E:StartBagsRuntime()

		self:ApplyElvUIBagWindowPosition()

		return true

	end



	bagDebug("Failed to start ElvUI bags — no wrapper/engine API")

	return false

end



function module:StopElvUIBagsRuntime()

	bagDebug("Stop ElvUI bags runtime")



	local wrapper = self:GetElvUIBagsWrapper()

	if wrapper and wrapper.SetRuntimeEnabled then

		wrapper:SetRuntimeEnabled(false)

		return

	end



	local E = self:GetElvUIEngine()

	if E and E.ShutdownBagsRuntime then

		E:ShutdownBagsRuntime()

	end

end



function module:ApplyMode()

	local mode = self:GetMode()

	bagDebug("ApplyMode:", mode, "enabled =", tostring(self:IsEnabled()), "engine loaded =", tostring(self:IsElvUIBagsLoaded()))



	if not self:IsEnabled() then

		self:DisableDefaultHandlers()

		self:StopElvUIBagsRuntime()

		self:StopBaudBagRuntime()

		return

	end



	if self:IsElvUIMode() then

		self:StopBaudBagRuntime()

		self:DisableDefaultHandlers()

		local E = self:GetElvUIEngine()
		local B = E and E.GetModule and E:GetModule("Bags", true)
		if B and B.RestoreActionBarBagButtons then
			B:RestoreActionBarBagButtons()
		end

		self:StartElvUIBagsRuntime()

	elseif self:IsBaudBagMode() then

		self:StopElvUIBagsRuntime()

		self:StartBaudBagRuntime()

		-- Поиск и сортировка SarychUI работают и с BaudBag.
		self:EnableDefaultHandlers()

		bagDebug("BaudBag bags mode")

	else

		self:StopElvUIBagsRuntime()

		self:StopBaudBagRuntime()

		self:EnableDefaultHandlers()

		bagDebug("Fallback to Blizzard bags")

	end

end



function module:EnableDefaultHandlers()

	if SarychUI_BagSort_RegisterEvents then

		SarychUI_BagSort_RegisterEvents()

	end

	if self.ApplyBagSortSettings then

		self:ApplyBagSortSettings()

	end

end



function module:DisableDefaultHandlers()

	if SarychUI_BagSort_UnregisterEvents then

		SarychUI_BagSort_UnregisterEvents()

	end

	if self.DisableBagSortButton then

		self:DisableBagSortButton()

	end

end



function module:CanUseDefaultAutoSellGrey()

	if not self:IsEnabled() then

		return false

	end

	-- SarychUI Bags: своя автопродажа; классика и Baud Bag — модуль Автоматизация.
	if self:IsElvUIMode() then

		return false

	end

	local automation = SarychUI.db.profile.modules.automation

	return automation and automation.enableAutoSellGrey == 1

end



function module:GetBagSortPinnedItemIDs()

	if not SarychUIDB then

		SarychUIDB = {}

	end

	if type(SarychUIDB.bagSortPinnedItemIDs) ~= "table" then

		SarychUIDB.bagSortPinnedItemIDs = { 43231, 43233 }

	end

	return SarychUIDB.bagSortPinnedItemIDs

end



function module:AddBagSortPinnedItemID(itemID)

	itemID = tonumber(itemID)

	if not itemID or itemID <= 0 then

		return false, "invalid"

	end

	-- Hearthstone is always first slot in bag sort; never store it in the editable list.
	if itemID == 6948 then

		return false, "hearthstone"

	end

	local list = self:GetBagSortPinnedItemIDs()

	for i = 1, #list do

		if tonumber(list[i]) == itemID then

			return false, "duplicate"

		end

	end

	list[#list + 1] = itemID

	return true

end



function module:RemoveBagSortPinnedItemID(itemID)

	itemID = tonumber(itemID)

	if not itemID then return false end

	local list = self:GetBagSortPinnedItemIDs()

	for i = #list, 1, -1 do

		if tonumber(list[i]) == itemID then

			table.remove(list, i)

			return true

		end

	end

	return false

end



function module:Initialize()

	-- Runtime включается на PLAYER_LOGIN (Enable), не на ADDON_LOADED

end



function module:Enable()

	self:ApplyMode()

end



function module:Disable()

	self:DisableDefaultHandlers()

	self:StopElvUIBagsRuntime()

	self:StopBaudBagRuntime()

end



function module:RefreshConfig()

	self:ApplyMode()

end



-- Повторное применение после полной загрузки UI (на случай гонки с ElvUI engine)

local loginFrame = CreateFrame("Frame")

loginFrame:RegisterEvent("PLAYER_LOGIN")

loginFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

loginFrame:SetScript("OnEvent", function(_, event)

	if not module:IsEnabled() then return end



	local function deferredApply()

		if module.ApplyMode then

			module:ApplyMode()

		end

	end



	if C_Timer and C_Timer.After then

		C_Timer.After(event == "PLAYER_LOGIN" and 0.2 or 0.5, deferredApply)

	else

		deferredApply()

	end

end)


