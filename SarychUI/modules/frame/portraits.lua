-- SarychUI Frame Module - "Изменение портретов" (players only)
--
-- modules.frame.portrait3D        - animated 3D portraits on EVERY unit frame (player, target,
--                                   focus, pet, party), mobs / NPCs included. Technique of the Adapt
--                                   addon: the model sits under the frame art and a ring mask hides
--                                   its square edges. Out-of-sight units fall back to the settings below.
-- modules.frame.classIconEnabled  - master toggle of the class / spec icons
-- modules.frame.classIconStyle    - what is shown:
--   Portrait styles (replace the portrait of the player / target / focus frame):
--     class - round class icon;
--     spec  - round spec icon (class icon until the spec is known);
--     badge - round class icon + small spec icon in the corner;
--   Level styles (portrait stays untouched, see classicon.lua):
--     separate - class icon beside the level badge;
--     replace  - class icon instead of the level number.
-- modules.frame.classIconPortraitsPlayer - portrait styles also on the player frame.
--
-- Same UnitIsPlayer gate as UnitFrameLayers HP class coloring (NPCs untouched).
-- Spec detection lives in specs.lua (SarychUI.FrameSpecs).

local moduleName = "frame"
local module = SarychUI and SarychUI.modules and SarychUI.modules[moduleName]
if not module then return end

local CLASS_CIRCLES = [[Interface\TargetingFrame\UI-Classes-Circles]]
-- Same ring as the class icon beside the level badge (MiniMapButtonTemplate).
local MINIMAP_RING = [[Interface\Minimap\MiniMap-TrackingBorder]]
-- 3D portrait back / ring mask (from Adapt).
local MODEL_BACK = [[Interface\AddOns\SarychUI\media\portraits\adapt_back]]
local MODEL_MASK = [[Interface\AddOns\SarychUI\media\portraits\adapt_mask]]

local SPEC_TRIM = 0.08
-- Same icon / ring size as the class icon beside the level badge.
local BADGE_SIZE = 20

local PORTRAIT_STYLES = { class = true, spec = true, badge = true }
local LEVEL_STYLES = { separate = true, replace = true }

-- Frames that get class / spec icons (and 3D portraits).
local PORTRAIT_SLOTS = {
	{ unit = "player", textureName = "PlayerPortrait", frameName = "PlayerFrame", levelName = "PlayerLevelText", badgePoint = "BOTTOMRIGHT" },
	{ unit = "target", textureName = "TargetFramePortrait", frameName = "TargetFrame", levelName = "TargetFrameTextureFrameLevelText", badgePoint = "BOTTOMLEFT" },
	{ unit = "focus", textureName = "FocusFramePortrait", frameName = "FocusFrame", levelName = "FocusFrameTextureFrameLevelText", badgePoint = "BOTTOMLEFT" },
}
-- Frames that only get 3D portraits (pet, party).
local MODEL_ONLY_SLOTS = {
	{ unit = "pet", textureName = "PetPortrait", frameName = "PetFrame" },
}
for i = 1, 4 do
	MODEL_ONLY_SLOTS[#MODEL_ONLY_SLOTS + 1] = {
		unit = "party" .. i,
		textureName = "PartyMemberFrame" .. i .. "Portrait",
		frameName = "PartyMemberFrame" .. i,
	}
end
local SLOT_BY_UNIT = {}
local ICON_UNITS = {}
for _, slot in ipairs(PORTRAIT_SLOTS) do
	SLOT_BY_UNIT[slot.unit] = slot
	ICON_UNITS[slot.unit] = true
end
for _, slot in ipairs(MODEL_ONLY_SLOTS) do
	SLOT_BY_UNIT[slot.unit] = slot
end

local STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
local STRATA_INDEX = {}
for i, name in ipairs(STRATA) do
	STRATA_INDEX[name] = i
end

-- Leftover names from old PlayerModel portraits (hide if somehow still around).
local LEGACY_MODEL = {
	player = "SarychUI_PlayerPortrait3D",
	target = "SarychUI_TargetPortrait3D",
	focus = "SarychUI_FocusPortrait3D",
}
local LEGACY_BG = {
	player = "SarychUI_PlayerPortrait3DBg",
	target = "SarychUI_TargetPortrait3DBg",
	focus = "SarychUI_FocusPortrait3DBg",
}

local portraitHookInstalled = false

--------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------
local function GetDb()
	return SarychUI.GetModuleProfile and SarychUI:GetModuleProfile(moduleName)
		or (SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName])
end

local function GetSetting(key, default)
	local db = GetDb()
	if db and db[key] ~= nil then
		return db[key]
	end
	return default
end

local function GetStyle()
	local style = GetSetting("classIconStyle", "class")
	if PORTRAIT_STYLES[style] or LEVEL_STYLES[style] then
		return style
	end
	return "class"
end

local function Is3DEnabled()
	local db = GetDb()
	if db and db.enabled == false then
		return false
	end
	return GetSetting("portrait3D", 0) == 1
end

local function IconsEnabled()
	local db = GetDb()
	if db and db.enabled == false then
		return false
	end
	return GetSetting("classIconEnabled", 0) == 1
end

local function IsClassIconPortraitsEnabled()
	return IconsEnabled() and PORTRAIT_STYLES[GetStyle()] == true
end

-- "separate" / "replace" while the level badge icon is on, nil otherwise (used by classicon.lua).
function module.GetLevelIconStyle()
	local style = GetStyle()
	if IconsEnabled() and LEVEL_STYLES[style] then
		return style
	end
	return nil
end

local function IsPlayerClassIconEnabled()
	return GetSetting("classIconPortraitsPlayer", 1) == 1
end

-- unit token "player" only (PlayerFrame). Target-of-self still uses target rules.
local function ShouldApplyClassIcon(unit)
	if not IsClassIconPortraitsEnabled() then
		return false
	end
	if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then
		return false
	end
	if unit == "player" and not IsPlayerClassIconEnabled() then
		return false
	end
	return true
end

local function HideLegacyModelUi(unit)
	local model = LEGACY_MODEL[unit] and _G[LEGACY_MODEL[unit]]
	if model then
		model:Hide()
		model._sarychGuid = nil
	end
	local bg = LEGACY_BG[unit] and _G[LEGACY_BG[unit]]
	if bg then
		bg:Hide()
	end
end

local function FrameSpecs()
	return SarychUI.FrameSpecs
end

-- Spec detection (inspects) is only worth it while the portrait actually shows a spec.
function module:IsSpecStyleNeeded()
	if not IsClassIconPortraitsEnabled() then
		return false
	end
	local style = GetStyle()
	return style == "spec" or style == "badge"
end

function module:UpdateSpecActivity()
	local specs = FrameSpecs()
	if specs then
		specs:SetActive(self:IsSpecStyleNeeded())
	end
end

--------------------------------------------------------------------
-- Icon helpers
--------------------------------------------------------------------
-- Square icon -> round, like Blizzard portraits (SetPortraitToTexture masks it).
local function SetRoundTexture(texture, path)
	if type(SetPortraitToTexture) == "function" then
		SetPortraitToTexture(texture, path)
		texture:SetTexCoord(0, 1, 0, 1)
	else
		texture:SetTexture(path)
		texture:SetTexCoord(SPEC_TRIM, 1 - SPEC_TRIM, SPEC_TRIM, 1 - SPEC_TRIM)
	end
end

-- Spec icon path of a unit, or nil while the spec is unknown (hostile / out of range / not inspected yet).
local function GetUnitSpecIcon(unit, class)
	local specs = FrameSpecs()
	if not specs or not class then
		return nil
	end
	return specs:GetIcon(class, specs:Get(unit))
end

--------------------------------------------------------------------
-- Spec badge (corner icon of the "badge" style)
--------------------------------------------------------------------
local function ApplyRingColor(ring)
	local L = SarychUI_LortiUI
	if L and L.IsSettingOn and L.IsSettingOn() and L.GetColor then
		local r, g, b, a = L.GetColor()
		ring:SetVertexColor(r, g, b, a or 1)
	else
		ring:SetVertexColor(1, 1, 1, 1)
	end
end

local function EnsureBadge(slot)
	if slot.badge then
		return slot.badge
	end
	local parent = _G[slot.frameName]
	if not parent then
		return nil
	end
	local badge = CreateFrame("Frame", nil, parent)
	badge:SetSize(BADGE_SIZE, BADGE_SIZE)
	badge.icon = badge:CreateTexture(nil, "ARTWORK")
	badge.icon:SetAllPoints()
	-- Same ring geometry as the class icon beside the level badge (icon 20 / ring 52).
	badge.ring = badge:CreateTexture(nil, "OVERLAY")
	badge.ring:SetTexture(MINIMAP_RING)
	badge.ring:SetSize(52, 52)
	badge.ring:SetPoint("TOPLEFT", badge.icon, "CENTER", -15, 16)
	badge:Hide()
	slot.badge = badge
	return badge
end

local function HideBadge(slot)
	if slot and slot.badge then
		slot.badge:Hide()
	end
end

local function ShowBadge(slot, specIcon)
	local badge = EnsureBadge(slot)
	if not badge then
		return
	end
	local portrait = _G[slot.textureName]
	local levelText = slot.levelName and _G[slot.levelName]
	local border = levelText and levelText:GetParent()
	local parent = _G[slot.frameName]
	-- Above the frame border art.
	local level = ((border or parent):GetFrameLevel() or 0) + 2
	badge:SetFrameLevel(level)
	badge:ClearAllPoints()
	badge:SetPoint(slot.badgePoint, portrait, slot.badgePoint, 0, 0)
	SetRoundTexture(badge.icon, specIcon)
	ApplyRingColor(badge.ring)
	badge:Show()
end

--------------------------------------------------------------------
-- 3D portrait (Adapt technique, strata fixed for overlays)
--
-- Everything of the model lives one strata BELOW the unit frame:
--   holder.back - dark circle behind the model;
--   model       - PlayerModel;
--   mask        - ring that hides the square edges of the model.
--
-- BigDebuffs, class / spec icons, the frame border and the level badge all stay on the
-- unit frame's own strata, so they always draw on top of the 3D portrait.
-- The 2D portrait texture is hidden while the model is shown.
--------------------------------------------------------------------
local function EnsureModel(slot)
	if slot.model then
		return slot.model
	end
	local parent = _G[slot.frameName]
	local tex = _G[slot.textureName]
	if not parent or not tex then
		return nil
	end
	-- Adapt: a BACKGROUND unit frame would draw under the model holder - bump it up.
	if parent:GetFrameStrata() == "BACKGROUND" then
		parent:SetFrameStrata("LOW")
	end
	local width, height = tex:GetWidth(), tex:GetHeight()
	if not width or width < 24 or not height or height < 24 then
		width, height = 64, 64
	end

	local index = STRATA_INDEX[parent:GetFrameStrata() or "MEDIUM"] or 3
	local holder = CreateFrame("Frame", nil, parent)
	holder:EnableMouse(false)
	holder:SetFrameStrata(STRATA[index > 1 and index - 1 or 1])
	holder:SetFrameLevel(0)
	holder:SetSize(width, height)
	holder:SetPoint("CENTER", tex, "CENTER", 0, -2)

	holder.back = holder:CreateTexture(nil, "BACKGROUND")
	holder.back:SetAllPoints()
	holder.back:SetTexture(MODEL_BACK)
	holder.back:SetVertexColor(0.1, 0.1, 0.1, 1)

	local model = CreateFrame("PlayerModel", nil, holder)
	model:EnableMouse(false)
	model:SetFrameLevel(1)
	model:SetSize(width * 0.75, height * 0.75)
	model:SetPoint("CENTER", holder, "CENTER", 0, 0)
	model:SetScript("OnShow", function(self)
		self:SetCamera(0)
	end)

	-- Mask sits above the model inside the holder (lower strata), not on the unit frame -
	-- otherwise it would cover BigDebuffs / class icons that sit on the portrait.
	local maskFrame = CreateFrame("Frame", nil, holder)
	maskFrame:EnableMouse(false)
	maskFrame:SetAllPoints(holder)
	maskFrame:SetFrameLevel(2)
	local mask = maskFrame:CreateTexture(nil, "ARTWORK")
	mask:SetSize(width - 2.5, height)
	mask:SetPoint("CENTER", maskFrame, "CENTER", -0.5, -1.5)
	mask:SetTexture(MODEL_MASK)
	mask:SetVertexColor(0, 0, 0, 1)

	slot.holder, slot.model, slot.mask = holder, model, mask
	holder:Hide()
	return model
end

local function HideModel(slot)
	if not slot.holder then
		return
	end
	slot.holder:Hide()
	slot.modelGuid = nil
	slot.modelActive = false
end

local function ShowModel(slot, unit)
	local model = EnsureModel(slot)
	if not model then
		return false
	end
	local guid = UnitGUID(unit)
	slot.holder:Show()
	if slot.modelGuid ~= guid then
		slot.modelGuid = guid
		model:SetUnit(unit)
	end
	model:SetCamera(0)
	local portrait = _G[slot.textureName]
	if portrait then
		-- Keep the texture "shown" for size / anchor queries (BigDebuffs), but invisible -
		-- the model underneath provides the picture.
		portrait:SetTexture(nil)
		portrait:SetAlpha(0)
		portrait:Show()
	end
	slot.modelActive = true
	return true
end

-- Releases the 3D portrait of a slot (if any) and brings the 2D portrait texture back.
local function ReleaseModel(slot, portrait)
	if slot and slot.modelActive then
		HideModel(slot)
		if portrait then
			portrait:SetAlpha(1)
			portrait:Show()
		end
	end
end

--------------------------------------------------------------------
-- Portrait painting
--------------------------------------------------------------------
local function ApplyClassIconToPortrait(portrait, unit)
	if not portrait or not ShouldApplyClassIcon(unit) then
		return false
	end
	local slot = SLOT_BY_UNIT[unit]
	local style = GetStyle()
	portrait:SetAlpha(1)
	portrait:Show()

	local _, class = UnitClass(unit)
	local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
	if not coords then
		HideBadge(slot)
		return false
	end
	local specIcon = (style == "spec" or style == "badge") and GetUnitSpecIcon(unit, class) or nil
	if style == "spec" and specIcon then
		SetRoundTexture(portrait, specIcon)
	else
		portrait:SetTexture(CLASS_CIRCLES)
		portrait:SetTexCoord(unpack(coords))
	end
	if style == "badge" and specIcon and slot then
		ShowBadge(slot, specIcon)
	else
		HideBadge(slot)
	end
	return true
end

local function RestoreDefaultPortrait(slot)
	local tex = _G[slot.textureName]
	HideModel(slot)
	if tex then
		tex:SetTexCoord(0, 1, 0, 1)
		tex:SetAlpha(1)
		tex:Show()
		if UnitExists(slot.unit) then
			SetPortraitTexture(tex, slot.unit)
		end
	end
	HideBadge(slot)
	HideLegacyModelUi(slot.unit)
end

-- Class / spec icons sit above the 3D portrait: when they apply to a unit, the model is put away.
local function TryApplyClassIcon(slot, portrait, unit)
	if not ICON_UNITS[unit] or not ShouldApplyClassIcon(unit) then
		return false
	end
	ReleaseModel(slot, portrait)
	if ApplyClassIconToPortrait(portrait, unit) then
		return true
	end
	-- Class data not ready yet after /reload - keep face portrait.
	portrait:SetTexCoord(0, 1, 0, 1)
	portrait:SetAlpha(1)
	if SetPortraitTexture then
		SetPortraitTexture(portrait, unit)
	end
	return true
end

local function RefreshUnitFramePortrait(frame)
	if frame and type(UnitFramePortrait_Update) == "function" then
		UnitFramePortrait_Update(frame)
	end
end

local function OnUnitFramePortraitUpdate(self)
	if not self or not self.portrait or not self.unit then
		return
	end
	-- UnitFramePortrait_Update is shared with protected BossNTargetFrame.
	-- SarychUI only owns portraits of player / target / focus / pet / party.
	local slot = SLOT_BY_UNIT[self.unit]
	if not slot or self ~= _G[slot.frameName] then
		return
	end

	-- Class / spec icons first: they must sit above (and replace) the 3D portrait.
	if TryApplyClassIcon(slot, self.portrait, self.unit) then
		return
	end

	-- 3D portraits for everyone else in sight, NPCs included.
	if Is3DEnabled() and UnitExists(self.unit) and UnitIsVisible(self.unit) and ShowModel(slot, self.unit) then
		HideBadge(slot)
		return
	end

	ReleaseModel(slot, self.portrait)
	HideBadge(slot)
	self.portrait:SetAlpha(1)
	self.portrait:Show()
	self.portrait:SetTexCoord(0, 1, 0, 1)
end

local function EnsurePortraitHook()
	if portraitHookInstalled then return end
	portraitHookInstalled = true
	if type(hooksecurefunc) == "function" and UnitFramePortrait_Update then
		hooksecurefunc("UnitFramePortrait_Update", OnUnitFramePortraitUpdate)
	end
end

local function ApplySlotPortrait(slot)
	HideLegacyModelUi(slot.unit)
	local frame = slot.frameName and _G[slot.frameName]
	local tex = _G[slot.textureName]
	RefreshUnitFramePortrait(frame)
	-- The hook above has already painted the slot (icon or 3D).
	if slot.modelActive or (tex and ShouldApplyClassIcon(slot.unit)) then
		return
	end
	if not Is3DEnabled() and not IsClassIconPortraitsEnabled() then
		RestoreDefaultPortrait(slot)
		RefreshUnitFramePortrait(frame)
	end
end

local function RefreshAllPortraits()
	module:UpdateSpecActivity()
	local use3D = Is3DEnabled()
	for _, slot in ipairs(PORTRAIT_SLOTS) do
		if use3D or IsClassIconPortraitsEnabled() then
			ApplySlotPortrait(slot)
		else
			RestoreDefaultPortrait(slot)
			RefreshUnitFramePortrait(_G[slot.frameName])
		end
	end
	-- Pet / party: only 3D portraits touch them; the update also puts the plain portrait back.
	for _, slot in ipairs(MODEL_ONLY_SLOTS) do
		local frame = _G[slot.frameName]
		if frame then
			if not use3D and slot.modelActive then
				RestoreDefaultPortrait(slot)
			end
			RefreshUnitFramePortrait(frame)
		end
	end
end

function module:UpdateClassIconPortraits(force, onlyUnit)
	EnsurePortraitHook()
	if onlyUnit then
		for _, slot in ipairs(PORTRAIT_SLOTS) do
			if slot.unit == onlyUnit then
				if force then
					-- UNIT_MODEL_CHANGED etc.: make the 3D portrait load the model again.
					slot.modelGuid = nil
				end
				if Is3DEnabled() or IsClassIconPortraitsEnabled() then
					ApplySlotPortrait(slot)
				else
					RestoreDefaultPortrait(slot)
					RefreshUnitFramePortrait(_G[slot.frameName])
				end
				return
			end
		end
		return
	end
	RefreshAllPortraits()
end

function module:ApplyClassIconPortraits()
	EnsurePortraitHook()
	RefreshAllPortraits()
end

-- Retry after /reload: SetPortraitTexture can no-op until the next ticks.
function module:SchedulePortraitRefresh()
	local driver = self._portraitRefreshDriver
	if not driver then
		driver = CreateFrame("Frame")
		self._portraitRefreshDriver = driver
		driver:SetScript("OnUpdate", function(frame, elapsed)
			frame.elapsed = (frame.elapsed or 0) + elapsed
			local step = frame.step or 0
			if step == 0 then
				RefreshAllPortraits()
				frame.step = 1
			elseif step == 1 and frame.elapsed >= 0.15 then
				RefreshAllPortraits()
				frame.step = 2
			elseif step == 2 and frame.elapsed >= 0.5 then
				RefreshAllPortraits()
				frame.step = 3
			elseif step == 3 and frame.elapsed >= 1.0 then
				RefreshAllPortraits()
				frame.step = 4
			elseif step == 4 and frame.elapsed >= 2.0 then
				RefreshAllPortraits()
				frame.step = 5
			elseif step == 5 and frame.elapsed >= 3.0 then
				RefreshAllPortraits()
				frame.step = 0
				frame.elapsed = 0
				frame:Hide()
			end
		end)
	end
	driver.elapsed = 0
	driver.step = 0
	driver:Show()
end

function module:Update3DPortraits(force, onlyUnit)
	self:UpdateClassIconPortraits(force, onlyUnit)
end

function module:Disable3DPortraits()
	if FrameSpecs() then
		FrameSpecs():SetActive(false)
	end
	for _, slot in ipairs(PORTRAIT_SLOTS) do
		RestoreDefaultPortrait(slot)
		RefreshUnitFramePortrait(_G[slot.frameName])
	end
	for _, slot in ipairs(MODEL_ONLY_SLOTS) do
		if slot.modelActive then
			RestoreDefaultPortrait(slot)
		end
	end
end

function module:Apply3DPortraits()
	self:ApplyClassIconPortraits()
end

function module:Enable3DPortraitEvents()
	self:ApplyClassIconPortraits()
end

function module:Disable3DPortraitEvents()
	self:Disable3DPortraits()
end

-- The unit changed its model (shapeshift, mount, ...): make the 3D portrait load it again.
local modelEvents = CreateFrame("Frame")
modelEvents:RegisterEvent("UNIT_MODEL_CHANGED")
modelEvents:RegisterEvent("UNIT_PORTRAIT_UPDATE")
modelEvents:SetScript("OnEvent", function(_, _, unit)
	local slot = unit and SLOT_BY_UNIT[unit]
	if slot and slot.modelActive then
		slot.modelGuid = nil
		RefreshUnitFramePortrait(_G[slot.frameName])
	end
end)

-- A spec became known (inspect finished / own talents changed): redraw the icons of that unit.
if FrameSpecs() then
	FrameSpecs():Register(function(guid)
		if not guid or not module:IsSpecStyleNeeded() then
			return
		end
		for _, slot in ipairs(PORTRAIT_SLOTS) do
			if UnitExists(slot.unit) and UnitGUID(slot.unit) == guid then
				module:UpdateClassIconPortraits(false, slot.unit)
			end
		end
	end)
end
