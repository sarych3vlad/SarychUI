-- ElvUI-aware dynamic layout for SarychUI plates_auras (elvui profile only)

local Layout = {}
SarychUI = SarychUI or {}
SarychUI.PlatesAurasElvUI = Layout

local hooksInstalled = false
local pendingRefresh = {}
local npModule = nil

local ANCHOR_RESOLVERS = {
	health = function(unitFrame)
		return unitFrame and unitFrame.Health
	end,
	plate = function(unitFrame, rootPlate)
		return unitFrame
	end,
	castbar = function(unitFrame)
		if unitFrame and unitFrame.CastBar and unitFrame.CastBar:IsShown() then
			return unitFrame.CastBar
		end
		return unitFrame and unitFrame.Health
	end,
	name = function(unitFrame)
		return unitFrame and unitFrame.Name
	end,
	root = function(unitFrame, rootPlate)
		return rootPlate
	end,
}

local function GetModule()
	return SarychUI and SarychUI:GetModule("plates_auras", true)
end

local function GetNPModule()
	if npModule then
		return npModule
	end
	local engine = _G.SarychUI_ElvUI_NamePlates and _G.SarychUI_ElvUI_NamePlates[1]
	if engine and engine.GetModule then
		npModule = engine:GetModule("NamePlates", true)
	end
	return npModule
end

local CASTBAR_ICON_GAP = 4
local CASTBAR_ICON_RIGHT_EXTRA_Y = -6

-- Center only (keep in sync with options.lua / defaults). Player strip does not grow with plate.
local RESPONSIVE_SCALE_DEFAULTS = {
	center = { enabled = true, factor = 0.55, maxBonus = 0.20 },
}

function Layout.IsActive()
	if not SarychUI or not SarychUI.GetNameplateMode then
		return false
	end
	if SarychUI:GetNameplateMode() ~= "elvui" then
		return false
	end
	local wrapper = SarychUI.GetAddOn and SarychUI:GetAddOn("ElvUI_NamePlates")
	if wrapper and wrapper.IsRuntimeEnabled and not wrapper:IsRuntimeEnabled() then
		return false
	end
	return true
end

function Layout.GetElvUIUnitFrame(namePlate)
	if not namePlate then return nil end
	return namePlate.UnitFrame
end

function Layout.GetRootPlate(namePlate, unitFrame)
	if namePlate then return namePlate end
	if unitFrame then
		return unitFrame:GetParent()
	end
	return nil
end

function Layout.GetActiveLayoutProfile()
	local mod = GetModule()
	if mod and mod.GetActiveDisplayProfile then
		return mod:GetActiveDisplayProfile()
	end
	return nil
end

function Layout.ResolveAnchorFrame(namePlate, anchorKey)
	local unitFrame = Layout.GetElvUIUnitFrame(namePlate)
	if not unitFrame then
		return namePlate, nil
	end

	local resolver = ANCHOR_RESOLVERS[anchorKey or "health"] or ANCHOR_RESOLVERS.health
	local anchor = resolver(unitFrame, namePlate)
	if not anchor then
		anchor = unitFrame.Health or unitFrame
	end

	local parent = unitFrame
	return parent, anchor
end

function Layout.GetPlateScale(unitFrame)
	if not unitFrame then
		return 1
	end

	-- Prefer live health width: tracks ElvUI's tween and avoids stale currentScale
	-- mid-SetFrameScale (currentScale is assigned after Configure_HealthBarScale).
	if unitFrame.Health and npModule and npModule.db and unitFrame.UnitType then
		local db = npModule.db.units[unitFrame.UnitType]
		local baseWidth = db and db.health and db.health.width
		if baseWidth and baseWidth > 0 then
			local width = unitFrame.Health:GetWidth() or 0
			if width > 0 then
				return width / baseWidth
			end
		end
	end

	if unitFrame.currentScale and unitFrame.currentScale > 0 then
		return unitFrame.currentScale
	end

	if unitFrame.GetScale then
		local frameScale = unitFrame:GetScale()
		if frameScale and frameScale > 0 then
			return frameScale
		end
	end

	return 1
end

function Layout.GetResponsiveScaleConfig(slotName)
	-- Only center supports plate-growth; ignore leftover player DB keys.
	local defaults = RESPONSIVE_SCALE_DEFAULTS[slotName]
	if not defaults then
		return nil
	end
	local profile = Layout.GetActiveLayoutProfile()
	local cfg = profile and profile.plateResponsiveScale and profile.plateResponsiveScale[slotName]
	if not cfg then
		return defaults
	end
	local enabled = cfg.enabled
	if enabled == nil then enabled = defaults.enabled end
	local factor = cfg.factor
	if factor == nil then factor = defaults.factor end
	local maxBonus = cfg.maxBonus
	if maxBonus == nil then maxBonus = defaults.maxBonus end
	return {
		enabled = enabled,
		factor = factor,
		maxBonus = maxBonus,
	}
end

function Layout.CalculateResponsiveScaleBonus(plateScale, config)
	if not config or config.enabled == false then
		return 0
	end

	local factor = config.factor
	if factor == nil then factor = 0 end
	local maxBonus = config.maxBonus
	if maxBonus == nil then maxBonus = 0 end
	-- Grow with the plate: factor 1.0 ≈ same relative growth as the indicator.
	local delta = math.max(0, (plateScale or 1) - 1)
	return math.min(maxBonus, delta * factor)
end

function Layout.SetContainerScale(container, targetScale)
	if not container then
		return
	end

	targetScale = targetScale or 1
	container:SetScale(targetScale)
	container.sarVisualScale = targetScale
end

function Layout.GetSlotEffectiveScale(slotName, baseScale, unitFrame)
	baseScale = baseScale or 1
	local config = Layout.GetResponsiveScaleConfig(slotName)
	if not config or config.enabled == false then
		return baseScale, 0
	end
	local bonus = Layout.CalculateResponsiveScaleBonus(Layout.GetPlateScale(unitFrame), config)
	return baseScale * (1 + bonus), bonus
end

function Layout.GetSlotSizeMultiplier(slotName, unitFrame)
	-- Only center grows with the plate; other slots always stay at base size.
	if slotName ~= "center" then
		return 1, 0
	end
	local config = Layout.GetResponsiveScaleConfig(slotName)
	if not config or config.enabled == false then
		return 1, 0
	end
	local bonus = Layout.CalculateResponsiveScaleBonus(Layout.GetPlateScale(unitFrame), config)
	return 1 + bonus, bonus
end

-- Center growth via SetSize (plate scale bonus). display.scale stays on SetScale.
local function ApplyCenterIconSizes(namePlate, mult)
	mult = mult or 1
	local szControl = (_G.ICON_SIZE_CONTROL or 46) * mult
	local szCast = (_G.ICON_SIZE_CAST or 46) * mult

	if namePlate.centerContainer then
		namePlate.centerContainer:SetSize(szControl + szCast + 4, math.max(szControl, szCast))
		namePlate.centerContainer.sarSizeMult = mult
	end
	if namePlate.controlFrame then
		namePlate.controlFrame:SetSize(szControl, szControl)
		if namePlate.controlFrame.auraIcon then
			namePlate.controlFrame.auraIcon:SetSize(szControl, szControl)
		end
		if namePlate.controlFrame.UpdateBorderSize then
			namePlate.controlFrame.UpdateBorderSize()
		end
	end
	if namePlate.castFrame then
		namePlate.castFrame:SetSize(szCast, szCast)
		if namePlate.castFrame.auraIcon then
			namePlate.castFrame.auraIcon:SetSize(szCast, szCast)
		end
		if namePlate.castFrame.UpdateBorderSize then
			namePlate.castFrame.UpdateBorderSize()
		end
	end
end

function Layout.ApplyContainerResponsiveScale(namePlate, container, slotName, baseScale, unitFrame)
	if not Layout.IsActive() or not container or not namePlate then
		if container and baseScale then
			container:SetScale(baseScale)
		end
		return
	end

	if slotName == "center" or slotName == "player" then
		Layout.UpdatePlateResponsiveScale(namePlate, {
			unitFrame = unitFrame,
			baseScale = baseScale,
			source = "apply-" .. tostring(slotName),
		})
		return
	end

	baseScale = baseScale or container.sarBaseScale or 1
	container.sarBaseScale = baseScale
	Layout.SetContainerScale(container, baseScale)
end

function Layout.UpdatePlateResponsiveScale(namePlate, options)
	if not Layout.IsActive() or not namePlate then
		return
	end

	options = options or {}
	local unitFrame = options.unitFrame or Layout.GetElvUIUnitFrame(namePlate)

	local profile = Layout.GetActiveLayoutProfile()
	local profileBaseScale = (profile and profile.display and profile.display.scale) or 1
	if options.baseScale then
		profileBaseScale = options.baseScale
	end

	local centerMult = Layout.GetSlotSizeMultiplier("center", unitFrame)

	if namePlate.centerContainer then
		namePlate.centerContainer.sarBaseScale = profileBaseScale
		Layout.SetContainerScale(namePlate.centerContainer, profileBaseScale)
		ApplyCenterIconSizes(namePlate, centerMult)
	end

	-- Player strip: fixed icon sizes + display.scale only (no plate-growth).
	if namePlate.playerFrame then
		namePlate.playerFrame.sarBaseScale = profileBaseScale
		Layout.SetContainerScale(namePlate.playerFrame, profileBaseScale)
	end
end

local function AsElvUIUnitFrame(frame)
	if frame and type(frame.GetParent) == "function" and frame.Health then
		return frame
	end
	return nil
end

local function InstallHealthSizeSync(unitFrame)
	unitFrame = AsElvUIUnitFrame(unitFrame)
	if not unitFrame then return end

	local health = unitFrame.Health
	if not health or health.sarAuraScaleSyncInstalled then
		return
	end
	health.sarAuraScaleSyncInstalled = true

	local rootPlate = unitFrame:GetParent()
	local originalOnSizeChanged = health:GetScript("OnSizeChanged")

	health:SetScript("OnSizeChanged", function(self, width, height)
		if originalOnSizeChanged then
			originalOnSizeChanged(self, width, height)
		end
		if Layout.IsActive() and rootPlate then
			-- Keep anchors (proportional) and icon scale in sync while ElvUI tweens health size.
			Layout.UpdateElvUIAuraAnchor(rootPlate, {
				unitFrame = unitFrame,
				source = "elvui-health-size-changed",
			})
		end
	end)
end

-- Full layout refresh on plate visual scale/size: responsive icon scale AND proportional offsets.
local function SyncAuraLayoutFromUnitFrame(unitFrame)
	unitFrame = AsElvUIUnitFrame(unitFrame)
	if not unitFrame then return end
	local rootPlate = unitFrame:GetParent()
	if not rootPlate then return end
	InstallHealthSizeSync(unitFrame)
	Layout.UpdateElvUIAuraAnchor(rootPlate, {
		unitFrame = unitFrame,
		source = "elvui-frame-scale-hook",
	})
end

function Layout.OnElvUIPlateVisualScaleChanged(rootPlate, unitFrame)
	if not Layout.IsActive() or not rootPlate then
		return
	end

	Layout.UpdateElvUIAuraAnchor(rootPlate, {
		unitFrame = unitFrame,
		source = "elvui-frame-scale-update",
	})
end

function Layout.GetSlotConfig(profile, slotName)
	profile = profile or Layout.GetActiveLayoutProfile()
	if not profile then return {} end

	local layout = profile.layout or {}
	local slotTemplate = layout[slotName] or {}
	local positions = profile.positions or {}

	-- Build fresh config: anchor/point settings from layout, offsets always from positions tab
	local slot = {}
	for key, value in pairs(slotTemplate) do
		if key ~= "offsetX" and key ~= "offsetY" then
			slot[key] = value
		end
	end

	if slotName == "center" then
		slot.offsetX = slotTemplate.offsetX or 0
		slot.offsetY = positions.CentrY or 0
		slot.noPlayerLift = slotTemplate.noPlayerLift ~= nil and slotTemplate.noPlayerLift or 30
	elseif slotName == "right" then
		slot.offsetX = positions.RightX or 0
		slot.offsetY = positions.RightY or 0
	elseif slotName == "player" then
		slot.offsetX = slotTemplate.offsetX or 0
		slot.offsetY = positions.PlayerOffsetY or 0
	end

	return slot
end

local function GetCastBarRightIconContext(unitFrame)
	if not unitFrame then
		return
	end

	local castBar = unitFrame.CastBar
	local castIcon = castBar and castBar.Icon
	if not (castBar and castBar:IsShown() and castIcon and castIcon:IsShown()) then
		return
	end

	local NP = GetNPModule()
	local castDb = NP and NP.db and unitFrame.UnitType
		and NP.db.units[unitFrame.UnitType]
		and NP.db.units[unitFrame.UnitType].castbar

	if castDb and castDb.showIcon == false then
		return
	end

	if castDb and castDb.iconPosition == "LEFT" then
		return
	end

	return castBar, castIcon, castDb
end

function Layout.GetCastBarIconOffsetX(unitFrame)
	local castBar, castIcon, castDb = GetCastBarRightIconContext(unitFrame)
	if not castBar then
		return 0
	end

	local iconWidth = castIcon:GetWidth() or 0
	if iconWidth <= 0 and castDb and castDb.iconSize then
		iconWidth = castDb.iconSize * (unitFrame.currentScale or 1)
	end

	local iconOffsetX = (castDb and castDb.iconOffsetX) or 0
	return iconWidth + CASTBAR_ICON_GAP + iconOffsetX
end

function Layout.GetCastBarIconOffsetY(unitFrame)
	if not GetCastBarRightIconContext(unitFrame) then
		return 0
	end
	return CASTBAR_ICON_RIGHT_EXTRA_Y
end

function Layout.CalculateOffset(anchor, slot, namePlate, slotName)
	local x = slot.offsetX or 0
	local y = slot.offsetY or 0

	if slot.offsetMode == "proportional" and anchor then
		local width = anchor:GetWidth() or 0
		local height = anchor:GetHeight() or 0
		-- Player strip anchors to centerContainer (icon row), which does not track plate
		-- scale — use the health bar size so proportional factors follow the indicator.
		if slotName == "player" and namePlate then
			local unitFrame = Layout.GetElvUIUnitFrame(namePlate)
			local health = unitFrame and unitFrame.Health
			if health then
				local hw = health:GetWidth() or 0
				local hh = health:GetHeight() or 0
				if hw > 0 then width = hw end
				if hh > 0 then height = hh end
			end
		end
		if width > 0 then
			x = x + width * (slot.widthFactor or 0)
		end
		if height > 0 then
			y = y + height * (slot.heightFactor or 0)
		end
	end

	if slotName == "right" and namePlate then
		local unitFrame = Layout.GetElvUIUnitFrame(namePlate)
		x = x + Layout.GetCastBarIconOffsetX(unitFrame)
		y = y + Layout.GetCastBarIconOffsetY(unitFrame)
	end

	return x, y
end

function Layout.EnsureContainerParent(container, parent)
	if not container or not parent then return end
	if container:GetParent() ~= parent then
		container:SetParent(parent)
	end
end

function Layout.ApplySlotAnchor(container, namePlate, slotName, slotOverride)
	if not container or not namePlate then return false end

	local profile = Layout.GetActiveLayoutProfile()
	local slot = slotOverride or Layout.GetSlotConfig(profile, slotName)
	local anchorKey = slot.anchorFrame or "health"

	if slotName == "player" and slot.anchorFrame == "centerContainer" then
		local anchor = namePlate.centerContainer
		if not anchor then return false end
		-- Sibling of center under unitFrame (NOT child of center) so SetScale is absolute
		-- like centerContainer. Still SetPoint-anchored to center's BOTTOM for position.
		local unitFrame = Layout.GetElvUIUnitFrame(namePlate)
		Layout.EnsureContainerParent(container, unitFrame or namePlate)
		local x, y = Layout.CalculateOffset(anchor, slot, namePlate, slotName)
		container:ClearAllPoints()
		container:SetPoint(slot.point or "TOP", anchor, slot.relativePoint or "BOTTOM", x, y)
		return true
	end

	local parent, anchor = Layout.ResolveAnchorFrame(namePlate, anchorKey)
	if not anchor then return false end

	local width = anchor:GetWidth() or 0
	local height = anchor:GetHeight() or 0
	if width <= 0 or height <= 0 then
		return false
	end

	Layout.EnsureContainerParent(container, parent)
	local x, y = Layout.CalculateOffset(anchor, slot, namePlate, slotName)
	container:ClearAllPoints()
	container:SetPoint(slot.point or "BOTTOM", anchor, slot.relativePoint or "TOP", x, y)
	return true
end

function Layout.UpdateRightIconsAnchor(namePlate)
	if not Layout.IsActive() or not namePlate or not namePlate.mobilityContainer then
		return
	end
	Layout.ApplySlotAnchor(namePlate.mobilityContainer, namePlate, "right")
end

function Layout.HasVisiblePlayerIcons(namePlate)
	-- Alt-right sits on the right block, so ElvUI must not lift CC/cast for it.
	if _G.sarPlatesAuras_IsPlayerAltRight and _G.sarPlatesAuras_IsPlayerAltRight() then
		return false
	end
	if _G.sarPlatesAuras_HasVisiblePlayerIcons then
		return _G.sarPlatesAuras_HasVisiblePlayerIcons(namePlate)
	end

	if not namePlate or not namePlate.playerFrame or not namePlate.playerFrame.auraIcons then
		return false
	end

	for _, auraFrame in ipairs(namePlate.playerFrame.auraIcons) do
		if auraFrame and auraFrame.icon and auraFrame.icon:IsShown() then
			return true
		end
	end

	return false
end

function Layout.ResolveLayoutOptions(namePlate, options)
	options = options or {}

	if options.hasVisiblePlayerIcons == nil then
		options.hasVisiblePlayerIcons = Layout.HasVisiblePlayerIcons(namePlate)
	end

	return options
end

function Layout.UpdateElvUIAuraAnchor(namePlate, options)
	if not Layout.IsActive() or not namePlate then return end

	options = Layout.ResolveLayoutOptions(namePlate, options)
	local profile = Layout.GetActiveLayoutProfile()
	if not profile then return end

	local unitFrame = Layout.GetElvUIUnitFrame(namePlate)
	if not unitFrame then return end

	local centerSlot = Layout.GetSlotConfig(profile, "center")
	if options.hasVisiblePlayerIcons == false and centerSlot.noPlayerLift then
		centerSlot = {}
		for k, v in pairs(Layout.GetSlotConfig(profile, "center")) do
			centerSlot[k] = v
		end
		centerSlot.offsetY = (centerSlot.offsetY or 0) - centerSlot.noPlayerLift
	end

	if namePlate.centerContainer then
		if not Layout.ApplySlotAnchor(namePlate.centerContainer, namePlate, "center", centerSlot) then
			Layout.ScheduleRefresh(namePlate)
		end
	end

	if namePlate.mobilityContainer then
		if not Layout.ApplySlotAnchor(namePlate.mobilityContainer, namePlate, "right") then
			Layout.ScheduleRefresh(namePlate)
		end
	end

	-- Alt placement owns the player block: it hangs off the right container (anchored
	-- just above), so the center-relative slot anchor must not run.
	if namePlate.playerFrame then
		local isAltRight = _G.sarPlatesAuras_IsPlayerAltRight
		if isAltRight and isAltRight() then
			if _G.sarPlatesAuras_AnchorPlayerFrame then
				_G.sarPlatesAuras_AnchorPlayerFrame(namePlate)
			end
		elseif namePlate.centerContainer then
			Layout.ApplySlotAnchor(namePlate.playerFrame, namePlate, "player")
		end
	end

	Layout.UpdatePlateResponsiveScale(namePlate, options)
end

function Layout.ScheduleRefresh(namePlate)
	if not namePlate or pendingRefresh[namePlate] then return end
	pendingRefresh[namePlate] = true

	local function refresh()
		pendingRefresh[namePlate] = nil
		if not Layout.IsActive() then return end
		if _G.sarPlatesAuras_UpdatePlateLayout then
			_G.sarPlatesAuras_UpdatePlateLayout(namePlate)
		else
			Layout.UpdateElvUIAuraAnchor(namePlate)
		end
	end

	local delay = 0
	if SarychUI and SarychUI.Compatibility then
		delay = SarychUI.Compatibility:GetInterval("platesAuraRefreshDelay", 0, 0.10)
	end

	if delay > 0 and C_Timer and C_Timer.After then
		C_Timer.After(delay, refresh)
	elseif C_Timer and C_Timer.After then
		C_Timer.After(0, refresh)
	else
		refresh()
	end
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

local function RefreshFromUnitFrame(...)
	local rootPlate = NormalizeNameplateRoot(...)
	if rootPlate then
		Layout.ScheduleRefresh(rootPlate)
	end
end

local function RefreshRightIconsFromUnitFrame(...)
	local rootPlate = NormalizeNameplateRoot(...)
	if rootPlate then
		Layout.UpdateRightIconsAnchor(rootPlate)
	end
end

local function RefreshAllAuraPlates()
	if not Layout.IsActive() then return end
	if _G.sarPlatesAuras_GetAllNamePlates then
		local plates = _G.sarPlatesAuras_GetAllNamePlates()
		for _, namePlate in ipairs(plates) do
			if namePlate and (namePlate.centerContainer or namePlate.mobilityContainer) then
				Layout.ScheduleRefresh(namePlate)
			end
		end
	end
end

function Layout.InstallHooks()
	if hooksInstalled then return true end

	local engine = _G.SarychUI_ElvUI_NamePlates and _G.SarychUI_ElvUI_NamePlates[1]
	if not engine or not engine.GetModule then return false end

	local NP = engine:GetModule("NamePlates", true)
	if not NP then return false end

	npModule = NP

	hooksecurefunc(NP, "SetSize", function(...)
		if not Layout.IsActive() then return end
		local rootPlate = NormalizeNameplateRoot(...)
		if rootPlate then
			Layout.ScheduleRefresh(rootPlate)
		end
	end)

	hooksecurefunc(NP, "Configure_HealthBarScale", function(_, unitFrame)
		if not Layout.IsActive() then return end
		SyncAuraLayoutFromUnitFrame(unitFrame)
	end)

	hooksecurefunc(NP, "SetFrameScale", function(_, unitFrame)
		if not Layout.IsActive() then return end
		SyncAuraLayoutFromUnitFrame(unitFrame)
	end)

	hooksecurefunc(NP, "UpdateElement_All", function(...)
		if not Layout.IsActive() then return end
		-- Layout/position only. Aura paint is PlateBuffs bridge (LibNameplates FoundGUID).
		RefreshFromUnitFrame(...)
	end)

	hooksecurefunc(NP, "ConfigureAll", function()
		if not Layout.IsActive() then return end
		local delay = 0
		if SarychUI and SarychUI.Compatibility then
			delay = SarychUI.Compatibility:GetInterval("platesAuraConfigureDelay", 0, 0.15)
		end
		if C_Timer and C_Timer.After then
			C_Timer.After(delay, RefreshAllAuraPlates)
		else
			RefreshAllAuraPlates()
		end
	end)

	hooksecurefunc(NP, "Configure_HealthBar", function(...)
		if not Layout.IsActive() then return end
		RefreshFromUnitFrame(...)
	end)

	hooksecurefunc(NP, "Configure_CastBar", function(...)
		if not Layout.IsActive() then return end
		RefreshRightIconsFromUnitFrame(...)
	end)

	hooksecurefunc(NP, "StartCastBarFromDefault", function(_, unitFrame)
		if not Layout.IsActive() then return end
		RefreshRightIconsFromUnitFrame(unitFrame)
	end)

	hooksecurefunc(NP, "StopCastBarFromDefault", function(_, unitFrame)
		if not Layout.IsActive() then return end
		RefreshRightIconsFromUnitFrame(unitFrame)
	end)

	hooksecurefunc(NP, "Update_CastBar", function(_, frame)
		if not Layout.IsActive() then return end
		RefreshRightIconsFromUnitFrame(frame)
	end)

	hooksecurefunc(NP, "Configure_CastBarScale", function(_, unitFrame)
		if not Layout.IsActive() then return end
		RefreshRightIconsFromUnitFrame(unitFrame)
	end)

	hooksInstalled = true
	return true
end

function Layout.TryInstallHooks()
	if hooksInstalled then return true end
	if Layout.InstallHooks() then return true end

	local frame = CreateFrame("Frame")
	frame:RegisterEvent("PLAYER_LOGIN")
	frame:SetScript("OnEvent", function(self, event)
		if Layout.InstallHooks() then
			self:UnregisterAllEvents()
		end
	end)
	return false
end

Layout.TryInstallHooks()

return Layout
