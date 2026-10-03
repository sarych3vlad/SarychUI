-- SarychUI Maps: Questie-335 world-map compatibility.
--
-- Questie-335 places pins through HBD, then reparents them to WorldMapFrame in
-- QuestieMap.utils:SetDrawOrder. SarychUI zooms WorldMapDetailFrame instead, so
-- pins must live on WorldMapButton and use the same counter-scaled coordinate
-- model as SarychUI POIs. Questie's map button is kept outside the scroll child.

local Maps = SarychUI.Maps
local questie = Maps:RegisterComponent("questie", {})

local max = math.max
local provider
local loadFrame
local displayHooked = false
local pinState = setmetatable({}, { __mode = "k" })
local scheduleApply

local function getProvider()
	local compat = _G.QuestieCompat
	local pins = compat and compat.HBDPins
	if type(pins) ~= "table" or type(pins.worldmapPins) ~= "table" then
		return nil
	end
	return pins
end

local function getCanvasZoom()
	local value = WorldMapDetailFrame and WorldMapDetailFrame:GetScale() or 1
	if not value or value <= 0 then return 1 end
	return value
end

local function getTimers()
	return (C_Timer and C_Timer.After and C_Timer)
		or (_G.QuestieCompat and QuestieCompat.C_Timer)
end

local function rememberRawPosition(icon, relativeTo, x, y)
	if relativeTo ~= WorldMapButton then
		return pinState[icon]
	end

	local buttonScale = WorldMapButton:GetScale() or 1
	local sourceWidth = WorldMapButton:GetWidth() * buttonScale
	local sourceHeight = WorldMapButton:GetHeight() * buttonScale
	local targetWidth = WorldMapDetailFrame:GetWidth()
	local targetHeight = WorldMapDetailFrame:GetHeight()
	if sourceWidth <= 0 or sourceHeight <= 0 or targetWidth <= 0 or targetHeight <= 0 then
		return nil
	end

	local state = pinState[icon] or {}
	state.x = x / sourceWidth * targetWidth
	state.y = y / sourceHeight * targetHeight
	pinState[icon] = state
	return state
end

local syncGlowProxy

local function installGlowProxyHooks(icon)
	if icon._sarychGlowHooks then return end
	local glow = icon.glow
	local texture = icon.glowTexture
	if not glow or not texture then return end

	icon._sarychGlowHooks = true
	local function sync()
		if pinState[icon] then syncGlowProxy(icon) end
	end

	-- Questie changes glow visibility, size and colour independently of the
	-- world-map pin. Mirror those changes into our same-frame texture.
	for _, method in ipairs({ "Show", "Hide", "SetWidth", "SetHeight", "SetSize" }) do
		if type(glow[method]) == "function" then
			hooksecurefunc(glow, method, sync)
		end
	end
	for _, method in ipairs({ "SetTexture", "SetVertexColor", "SetAlpha" }) do
		if type(texture[method]) == "function" then
			hooksecurefunc(texture, method, sync)
		end
	end
end

syncGlowProxy = function(icon)
	local glow = icon and icon.glow
	local source = icon and icon.glowTexture
	if not glow or not source then return end

	local proxy = icon._sarychGlowTexture
	if not proxy then
		-- Both textures now belong to the same frame. BACKGROUND versus OVERLAY
		-- has deterministic ordering on the 3.3.5 renderer; frame-level ordering
		-- between Questie's icon button and its child glow button does not.
		proxy = icon:CreateTexture(nil, "BACKGROUND")
		proxy:SetPoint("CENTER", icon, "CENTER", 0, 0)
		icon._sarychGlowTexture = proxy
	end

	proxy:SetTexture(source:GetTexture())
	if source.GetBlendMode and proxy.SetBlendMode then
		proxy:SetBlendMode(source:GetBlendMode())
	end
	local r, g, b, a = source:GetVertexColor()
	proxy:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
	proxy:SetAlpha(source:GetAlpha() or 1)
	proxy:SetWidth(glow:GetWidth())
	proxy:SetHeight(glow:GetHeight())

	-- Leave the glow frame shown so Questie's own update logic keeps running,
	-- but render only the background proxy while this is a SarychUI map pin.
	source:Hide()
	if glow:IsShown() then proxy:Show() else proxy:Hide() end
	installGlowProxyHooks(icon)
end

local function restoreReleasedPin(icon)
	if not icon then return end
	pinState[icon] = nil
	if icon.SetScale then icon:SetScale(1) end
	if icon._sarychGlowTexture then icon._sarychGlowTexture:Hide() end
	if icon.glowTexture then icon.glowTexture:Show() end
end

local function restoreReleasedPins()
	if not provider then return end
	for icon in pairs(pinState) do
		if not provider.worldmapPins[icon] then
			restoreReleasedPin(icon)
		end
	end
end

local function rescalePin(icon, zoom)
	if not icon or not icon.SetScale then return end
	if icon.type == "line" then
		icon:SetScale(1)
		return
	end
	if icon.IsShown and not icon:IsShown() then return end

	local _, relativeTo, _, x, y = icon:GetPoint(1)
	if type(x) ~= "number" or type(y) ~= "number" then return end
	local state = rememberRawPosition(icon, relativeTo, x, y)
	if not state then return end

	-- QuestieMap.utils:SetDrawOrder moves the pin to WorldMapFrame. Put it on
	-- the zooming canvas before applying the SarychUI POI transform.
	if icon.GetParent and icon:GetParent() ~= WorldMapButton then
		icon:SetParent(WorldMapButton)
	end
	icon:SetScale(1 / zoom)
	icon:ClearAllPoints()
	icon:SetPoint("CENTER", WorldMapDetailFrame, "TOPLEFT", state.x * zoom, state.y * zoom)
	syncGlowProxy(icon)
end

function questie:PositionMapButton()
	local button = _G.Questie_WorldMapButton
	local viewport = Maps.scrollFrame
	if not button or not viewport then return false end

	-- The button belongs to the map chrome, not to its scrolling child. Keeping
	-- WorldMapFrame as parent preserves Questie's original visual size.
	if button:GetParent() ~= WorldMapFrame then
		button:SetParent(WorldMapFrame)
	end
	button:SetScale(1)
	button:ClearAllPoints()
	local filterButton = _G.SarychUIMapPOIFilterButton
	if filterButton then
		button:SetPoint("TOPRIGHT", filterButton, "BOTTOMRIGHT", 0, -4)
	else
		-- POI component may not have created its button yet. Reserve its
		-- 32-pixel slot so the Questie button never overlaps it during startup.
		button:SetPoint("TOPRIGHT", viewport, "TOPRIGHT", -4, -40)
	end
	button:SetFrameStrata(WorldMapFrame:GetFrameStrata())
	button:SetFrameLevel(max(button:GetFrameLevel() or 0, WorldMapFrame:GetFrameLevel() + 20))
	return true
end

function questie:ApplyRawPins()
	if not Maps:IsActive() or not provider then return end
	if not WorldMapFrame or not WorldMapFrame:IsVisible() then return end

	local zoom = getCanvasZoom()
	for icon in pairs(provider.worldmapPins) do
		rescalePin(icon, zoom)
	end
	self:PositionMapButton()
end

scheduleApply = function()
	if questie._applyQueued then return end
	local timers = getTimers()
	if not timers or not timers.After then
		questie:ApplyRawPins()
		return
	end

	questie._applyQueued = true
	timers.After(0, function()
		questie._applyQueued = false
		questie:ApplyRawPins()
	end)
end

local function rescaleAddedPin(_, _, icon)
	if not Maps:IsActive() then return end
	rescalePin(icon, getCanvasZoom())
	-- Questie calls SetDrawOrder immediately after this add method returns.
	scheduleApply()
end

local function restoreRemovedPin(_, _, icon)
	restoreReleasedPin(icon)
end

local function restoreRemovedPins()
	restoreReleasedPins()
end

function questie:Install()
	local pins = getProvider()
	if not pins then return false end
	if provider == pins and self._hooksInstalled then return true end

	provider = pins
	self._hooksInstalled = true

	if pins.updateFrame and not self._eventHooked then
		self._eventHooked = true
		pins.updateFrame:HookScript("OnEvent", function(_, event)
			if event == "WORLD_MAP_UPDATE"
				or event == "PLAYER_ENTERING_WORLD"
				or string.find(event, "ZONE_CHANGED") then
				questie:ApplyRawPins()
			end
		end)
	end

	if not self._addHooksInstalled then
		self._addHooksInstalled = true
		hooksecurefunc(pins, "AddWorldMapIconMap", rescaleAddedPin)
		hooksecurefunc(pins, "AddWorldMapIconWorld", rescaleAddedPin)
	end
	if not self._removeHooksInstalled then
		self._removeHooksInstalled = true
		hooksecurefunc(pins, "RemoveWorldMapIcon", restoreRemovedPin)
		hooksecurefunc(pins, "RemoveAllWorldMapIcons", restoreRemovedPins)
	end

	-- This is the exact Questie call which otherwise reparents map pins to
	-- WorldMapFrame after HBD has already positioned them.
	if not self._drawOrderHooked and _G.QuestieLoader and QuestieLoader.ImportModule then
		local questieMap = QuestieLoader:ImportModule("QuestieMap")
		local utils = questieMap and questieMap.utils
		if utils and type(utils.SetDrawOrder) == "function" then
			self._drawOrderHooked = true
			hooksecurefunc(utils, "SetDrawOrder", function(_, icon)
				if Maps:IsActive() and provider and provider.worldmapPins[icon] then
					rescalePin(icon, getCanvasZoom())
				end
			end)
		end
	end

	if not displayHooked then
		displayHooked = true
		hooksecurefunc("WorldMapFrame_DisplayQuests", function()
			scheduleApply()
		end)
	end

	if not self._mapShowHooked then
		self._mapShowHooked = true
		WorldMapFrame:HookScript("OnShow", function()
			if Maps:IsActive() then scheduleApply() end
		end)
	end

	return true
end

function questie:Rescale()
	if not Maps:IsActive() or not WorldMapFrame or not WorldMapFrame:IsShown() then return end
	if not self:Install() or self._refreshing then return end

	self._refreshing = true
	if provider.UpdateWorldMap then
		provider.UpdateWorldMap()
	end
	self:ApplyRawPins()
	self._refreshing = false
end

function questie:Enable()
	if not loadFrame then
		loadFrame = CreateFrame("Frame")
		loadFrame:SetScript("OnEvent", function(_, _, addonName)
			if addonName == "Questie-335" or addonName == "Questie"
				or (not provider and getProvider()) then
				if questie:Install() then
					questie:Rescale("AddonLoaded:" .. tostring(addonName))
				end
			end
		end)
	end
	loadFrame:RegisterEvent("ADDON_LOADED")
	self:Install()
	self:Rescale("Enable")
end

function questie:Disable()
	if loadFrame then loadFrame:UnregisterAllEvents() end
	if not provider then return end

	for icon in pairs(provider.worldmapPins) do
		if icon and icon.SetScale then
			restoreReleasedPin(icon)
			if icon.type ~= "line" and icon.SetParent then
				icon:SetParent(WorldMapFrame)
			end
		end
	end
	pinState = setmetatable({}, { __mode = "k" })
	if provider.UpdateWorldMap and WorldMapFrame and WorldMapFrame:IsShown() then
		provider.UpdateWorldMap()
	end
end

function questie:Refresh()
	self:Rescale("Refresh")
end

return questie
