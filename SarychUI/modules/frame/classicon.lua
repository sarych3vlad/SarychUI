-- Class icon on player / target / focus.
-- classIconEnabled, classIconMode (replace|separate), classIconMaxLevelOnly

local moduleName = "frame"
local module = SarychUI and SarychUI.modules and SarychUI.modules[moduleName]
if not module then return end

local CLASS_CIRCLES = [[Interface\TargetingFrame\UI-Classes-Circles]]
-- Same ring as addon buttons on the minimap (MiniMapButtonTemplate).
local MINIMAP_RING = [[Interface\Minimap\MiniMap-TrackingBorder]]

local SLOTS = {
	{ unit = "player", level = "PlayerLevelText", high = nil, side = -22 },
	{ unit = "target", level = "TargetFrameTextureFrameLevelText", high = "TargetFrameTextureFrameHighLevelTexture", side = 22 },
	{ unit = "focus", level = "FocusFrameTextureFrameLevelText", high = "FocusFrameTextureFrameHighLevelTexture", side = 22 },
}

local function GetSetting(key, default)
	local db = SarychUI.GetModuleProfile and SarychUI:GetModuleProfile(moduleName)
		or (SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName])
	if db and db[key] ~= nil then
		return db[key]
	end
	return default
end

local function SettingOn(key, default)
	local v = GetSetting(key, default)
	return v == 1 or v == true
end

local function MaxPlayerLevel()
	if type(GetMaxPlayerLevel) == "function" then
		return GetMaxPlayerLevel()
	end
	return MAX_PLAYER_LEVEL or 80
end

local function EnsureIcon(levelText)
	if not levelText then
		return nil
	end
	local parent = levelText:GetParent()
	if not parent then
		return nil
	end
	if parent.suiClassIcon then
		return parent.suiClassIcon
	end
	local ring = parent:CreateTexture(nil, "OVERLAY")
	ring:SetTexture(MINIMAP_RING)
	ring:SetSize(52, 52)
	ring:Hide()
	local icon = parent:CreateTexture(nil, "ARTWORK")
	icon:SetSize(20, 20)
	icon:Hide()
	parent.suiClassRing = ring
	parent.suiClassIcon = icon
	return icon
end

local function HideIcon(levelText)
	local parent = levelText and levelText:GetParent()
	if not parent then
		return
	end
	if parent.suiClassIcon then
		parent.suiClassIcon:Hide()
	end
	if parent.suiClassRing then
		parent.suiClassRing:Hide()
	end
end

local function ShowClassIcon(levelText, unit, x, y, withRing)
	local icon = EnsureIcon(levelText)
	if not icon then
		return false
	end
	local parent = levelText:GetParent()
	local ring = parent and parent.suiClassRing
	local _, class = UnitClass(unit)
	local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
	if not coords then
		HideIcon(levelText)
		return false
	end
	icon:SetTexture(CLASS_CIRCLES)
	icon:SetTexCoord(unpack(coords))
	icon:ClearAllPoints()
	icon:SetPoint("CENTER", levelText, "CENTER", x or 0, y or 0)
	icon:Show()
	if ring then
		if withRing then
			ring:ClearAllPoints()
			ring:SetPoint("TOPLEFT", icon, "CENTER", -15, 16)
			local L = SarychUI_LortiUI
			if L and L.IsSettingOn and L.IsSettingOn() and L.GetColor then
				local r, g, b, a = L.GetColor()
				ring:SetVertexColor(r, g, b, a or 1)
			else
				ring:SetVertexColor(1, 1, 1, 1)
			end
			ring:Show()
		else
			ring:Hide()
		end
	end
	return true
end

function module:ApplyClassIcons()
	local db = SarychUI.GetModuleProfile and SarychUI:GetModuleProfile(moduleName)
		or (SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName])
	local enabled = db and db.enabled ~= false and SettingOn("classIconEnabled", 0)
	local mode = GetSetting("classIconMode", "replace")
	local replace = mode ~= "separate"
	local onlyMax = replace and SettingOn("classIconMaxLevelOnly", 0)
	local applyPlayer = SettingOn("classIconPlayer", 1)
	local hideFrameLevel = SettingOn("hideFrameLevel", 0)
	local maxLevel = MaxPlayerLevel()
	local ox = tonumber(GetSetting("classIconX", -73)) or -73
	local oy = tonumber(GetSetting("classIconY", 43)) or 43

	for i = 1, #SLOTS do
		local slot = SLOTS[i]
		local levelText = _G[slot.level]
		local unit = slot.unit
		local show = false
		if enabled and levelText and UnitExists(unit) and UnitIsPlayer(unit) and (unit ~= "player" or applyPlayer) then
			local level = UnitLevel(unit) or 0
			if replace then
				if not onlyMax or level >= maxLevel then
					show = ShowClassIcon(levelText, unit, 0, 0, false)
				end
			else
				show = ShowClassIcon(levelText, unit, (slot.side or 0) + ox, oy, true)
			end
		end
		local high = slot.high and _G[slot.high]
		if show and replace and levelText and not hideFrameLevel then
			levelText:SetAlpha(0)
			if high then
				high:SetAlpha(0)
			end
		elseif not hideFrameLevel then
			if levelText then
				levelText:SetAlpha(1)
			end
			if high then
				high:SetAlpha(1)
			end
			if not show then
				HideIcon(levelText)
			end
		elseif not show then
			HideIcon(levelText)
		end
	end
end
