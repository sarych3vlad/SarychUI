-- ElvUI-aware distance text positioning and alpha sync for autolos

local Layout = {}
SarychUI = SarychUI or {}
SarychUI.AutolosElvUI = Layout

local hooksInstalled = false
local pendingLayout = {}
local pendingAlpha = {}
local needsFullLayout = false
local layoutFlushScheduled = false
local alphaFlushScheduled = false

local function GetAutolos()
	return _G.Autolos
end

function Layout.IsActive()
	if not SarychUI or not SarychUI.GetNameplateMode then
		return false
	end
	if SarychUI:GetNameplateMode() ~= "elvui" then
		return false
	end
	local autolos = GetAutolos()
	if not autolos or not autolos.IsEnabled or not autolos.IsEnabled() then
		return false
	end
	local wrapper = SarychUI.GetAddOn and SarychUI:GetAddOn("ElvUI_NamePlates")
	if wrapper and wrapper.IsRuntimeEnabled and not wrapper:IsRuntimeEnabled() then
		return false
	end
	return true
end

local function IsElvUIUnitFrame(frame)
	return frame and type(frame.GetParent) == "function" and frame.Health
end

local function IsBlizzardNameplate(frame)
	return frame and type(frame.GetParent) == "function" and frame.UnitFrame
end

local function NormalizeNameplateRoot(...)
	for i = 1, select("#", ...) do
		local arg = select(i, ...)
		if IsBlizzardNameplate(arg) then
			return arg
		end
		if IsElvUIUnitFrame(arg) then
			local rootPlate = arg:GetParent()
			if rootPlate then
				return rootPlate
			end
		end
	end
	return nil
end

local function ClearPending(pending)
	for key in pairs(pending) do
		pending[key] = nil
	end
end

local function FlushAlphaRefresh()
	alphaFlushScheduled = false
	if not Layout.IsActive() then
		ClearPending(pendingAlpha)
		return
	end

	local autolos = GetAutolos()
	if not autolos or not autolos.UpdateElvUIAlpha then
		ClearPending(pendingAlpha)
		return
	end

	for nameplate in pairs(pendingAlpha) do
		pendingAlpha[nameplate] = nil
		if nameplate and nameplate.fontStringRange then
			autolos.UpdateElvUIAlpha(nameplate)
		end
	end
end

local function FlushLayoutRefresh()
	layoutFlushScheduled = false
	if not Layout.IsActive() then
		ClearPending(pendingLayout)
		needsFullLayout = false
		return
	end

	local autolos = GetAutolos()
	if not autolos then
		ClearPending(pendingLayout)
		needsFullLayout = false
		return
	end

	if needsFullLayout and autolos.ApplyLayoutsAll then
		autolos.ApplyLayoutsAll()
		needsFullLayout = false
		ClearPending(pendingLayout)
		return
	end

	if not autolos.ApplyLayout then
		ClearPending(pendingLayout)
		return
	end

	local profile = autolos.GetActiveProfile and autolos.GetActiveProfile()
	for nameplate in pairs(pendingLayout) do
		pendingLayout[nameplate] = nil
		if nameplate and nameplate.fontStringRange then
			autolos.ApplyLayout(nameplate, nameplate.fontStringRange, profile)
		end
	end
end

function Layout.ScheduleAlphaRefresh(nameplate)
	if not Layout.IsActive() or not nameplate then return end
	pendingAlpha[nameplate] = true

	if alphaFlushScheduled then
		return
	end

	alphaFlushScheduled = true
	if C_Timer and C_Timer.After then
		C_Timer.After(0, FlushAlphaRefresh)
	else
		FlushAlphaRefresh()
	end
end

function Layout.ScheduleLayoutRefresh(nameplate)
	if not Layout.IsActive() or not nameplate then return end
	pendingLayout[nameplate] = true

	if layoutFlushScheduled then
		return
	end

	layoutFlushScheduled = true
	if C_Timer and C_Timer.After then
		C_Timer.After(0, FlushLayoutRefresh)
	else
		FlushLayoutRefresh()
	end
end

local function RefreshAlphaFromUnitFrame(...)
	local rootPlate = NormalizeNameplateRoot(...)
	if rootPlate then
		Layout.ScheduleAlphaRefresh(rootPlate)
	end
end

local function RefreshFromUnitFrame(...)
	local rootPlate = NormalizeNameplateRoot(...)
	if rootPlate then
		Layout.ScheduleLayoutRefresh(rootPlate)
		Layout.ScheduleAlphaRefresh(rootPlate)
	end
end

local function ScheduleAllLayoutRefresh()
	if not Layout.IsActive() then return end
	needsFullLayout = true
	if layoutFlushScheduled then
		return
	end
	layoutFlushScheduled = true
	if C_Timer and C_Timer.After then
		C_Timer.After(0, FlushLayoutRefresh)
	else
		FlushLayoutRefresh()
	end
end

local function ScheduleAllAlphaRefresh()
	if not Layout.IsActive() then return end
	local autolos = GetAutolos()
	if autolos and autolos.ApplyAlphasAll then
		if alphaFlushScheduled then
			return
		end
		alphaFlushScheduled = true
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				alphaFlushScheduled = false
				if Layout.IsActive() then
					autolos.ApplyAlphasAll()
				end
			end)
		else
			alphaFlushScheduled = false
			autolos.ApplyAlphasAll()
		end
	end
end

local function InstallHealthSizeSync(unitFrame)
	if not unitFrame or not unitFrame.Health then return end
	local health = unitFrame.Health
	if health.autolosSizeSyncInstalled then return end
	health.autolosSizeSyncInstalled = true

	local rootPlate = unitFrame:GetParent()
	local originalOnSizeChanged = health:GetScript("OnSizeChanged")

	health:SetScript("OnSizeChanged", function(self, width, height)
		if originalOnSizeChanged then
			originalOnSizeChanged(self, width, height)
		end
		if Layout.IsActive() and rootPlate then
			Layout.ScheduleLayoutRefresh(rootPlate)
		end
	end)
end

local function SyncFromUnitFrame(unitFrame)
	if not Layout.IsActive() or not unitFrame then return end
	InstallHealthSizeSync(unitFrame)
	local rootPlate = unitFrame:GetParent()
	if rootPlate then
		Layout.ScheduleLayoutRefresh(rootPlate)
		Layout.ScheduleAlphaRefresh(rootPlate)
	end
end

function Layout.InstallHooks()
	if hooksInstalled then return true end

	local engine = _G.SarychUI_ElvUI_NamePlates and _G.SarychUI_ElvUI_NamePlates[1]
	if not engine or not engine.GetModule then return false end

	local NP = engine:GetModule("NamePlates", true)
	if not NP then return false end

	hooksecurefunc(NP, "SetSize", function(...)
		if not Layout.IsActive() then return end
		local rootPlate = NormalizeNameplateRoot(...)
		if rootPlate then
			Layout.ScheduleLayoutRefresh(rootPlate)
		end
	end)

	hooksecurefunc(NP, "SetFrameScale", function(_, unitFrame)
		if not Layout.IsActive() then return end
		SyncFromUnitFrame(unitFrame)
	end)

	hooksecurefunc(NP, "Configure_HealthBarScale", function(_, unitFrame)
		if not Layout.IsActive() then return end
		SyncFromUnitFrame(unitFrame)
	end)

	hooksecurefunc(NP, "UpdateElement_All", function(...)
		if not Layout.IsActive() then return end
		RefreshFromUnitFrame(...)
	end)

	hooksecurefunc(NP, "ConfigureAll", function()
		if not Layout.IsActive() then return end
		ScheduleAllLayoutRefresh()
		ScheduleAllAlphaRefresh()
	end)

	hooksecurefunc(NP, "Configure_HealthBar", function(...)
		if not Layout.IsActive() then return end
		RefreshFromUnitFrame(...)
	end)

	-- Totem / unique "Icon Only": IconFrame shown, Health hidden — re-anchor distance text.
	hooksecurefunc(NP, "Update_IconFrame", function(_, unitFrame)
		if not Layout.IsActive() then return end
		RefreshFromUnitFrame(unitFrame)
	end)

	hooksecurefunc(NP, "Configure_IconFrame", function(_, unitFrame)
		if not Layout.IsActive() then return end
		RefreshFromUnitFrame(unitFrame)
	end)

	hooksecurefunc(NP, "Configure_Name", function(_, ...)
		if not Layout.IsActive() then return end
		RefreshAlphaFromUnitFrame(...)
	end)

	hooksecurefunc(NP, "Update_Name", function(_, ...)
		if not Layout.IsActive() then return end
		RefreshAlphaFromUnitFrame(...)
	end)

	hooksecurefunc(NP, "PlateFade", function(_, ...)
		if not Layout.IsActive() then return end
		RefreshAlphaFromUnitFrame(...)
	end)

	hooksecurefunc(NP, "SetTargetFrame", function(_, ...)
		if not Layout.IsActive() then return end
		RefreshAlphaFromUnitFrame(...)
	end)

	if engine.UIFrameFade then
		hooksecurefunc(engine, "UIFrameFade", function(_, frame)
			if not Layout.IsActive() then return end
			RefreshAlphaFromUnitFrame(frame)
		end)
	end

	hooksInstalled = true
	return true
end

function Layout.TryInstallHooks()
	if hooksInstalled then return true end
	if Layout.InstallHooks() then return true end

	local frame = CreateFrame("Frame")
	frame:RegisterEvent("PLAYER_LOGIN")
	frame:SetScript("OnEvent", function(self)
		if Layout.InstallHooks() then
			self:UnregisterAllEvents()
		end
	end)
	return false
end

function Layout.ScheduleRefresh(nameplate)
	Layout.ScheduleLayoutRefresh(nameplate)
end

Layout.TryInstallHooks()

return Layout
