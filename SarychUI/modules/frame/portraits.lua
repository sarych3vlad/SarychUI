-- SarychUI Frame Module — class icon portraits (players only)
-- Toggles: modules.frame.classIconPortraits, modules.frame.classIconPortraitsPlayer
-- Same UnitIsPlayer gate as UnitFrameLayers HP class coloring (NPCs untouched).

local moduleName = "frame"
local module = SarychUI and SarychUI.modules and SarychUI.modules[moduleName]
if not module then return end

local CLASS_CIRCLES = [[Interface\TargetingFrame\UI-Classes-Circles]]

local PORTRAIT_SLOTS = {
	{ unit = "player", textureName = "PlayerPortrait", frameName = "PlayerFrame" },
	{ unit = "target", textureName = "TargetFramePortrait", frameName = "TargetFrame" },
	{ unit = "focus", textureName = "FocusFramePortrait", frameName = "FocusFrame" },
}

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

local function GetSetting(key, default)
	local db = SarychUI.GetModuleProfile and SarychUI:GetModuleProfile(moduleName)
		or (SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName])
	if db and db[key] ~= nil then
		return db[key]
	end
	return default
end

local function IsClassIconPortraitsEnabled()
	if GetSetting("classIconPortraits", 0) ~= 1 then
		return false
	end
	local db = SarychUI.GetModuleProfile and SarychUI:GetModuleProfile(moduleName)
		or (SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName])
	if db and db.enabled == false then
		return false
	end
	return true
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

local function ApplyClassIconToPortrait(portrait, unit)
	if not portrait or not ShouldApplyClassIcon(unit) then
		return false
	end
	local _, class = UnitClass(unit)
	local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
	if not coords then
		return false
	end
	portrait:SetTexture(CLASS_CIRCLES)
	portrait:SetTexCoord(unpack(coords))
	return true
end

local function RestoreDefaultPortrait(slot)
	local tex = _G[slot.textureName]
	if tex then
		tex:SetTexCoord(0, 1, 0, 1)
		tex:SetAlpha(1)
		tex:Show()
		if UnitExists(slot.unit) then
			SetPortraitTexture(tex, slot.unit)
		end
	end
	HideLegacyModelUi(slot.unit)
end

local function RefreshUnitFramePortrait(frame)
	if frame and type(UnitFramePortrait_Update) == "function" then
		UnitFramePortrait_Update(frame)
	end
end

local function OnUnitFramePortraitUpdate(self)
	if not IsClassIconPortraitsEnabled() then
		return
	end
	if not self or not self.portrait or not self.unit then
		return
	end
	if ShouldApplyClassIcon(self.unit) then
		if not ApplyClassIconToPortrait(self.portrait, self.unit) then
			-- Class data not ready yet after /reload — keep face portrait.
			self.portrait:SetTexCoord(0, 1, 0, 1)
			if SetPortraitTexture then
				SetPortraitTexture(self.portrait, self.unit)
			end
		end
	else
		-- NPC / mob, or player with class-icon-on-player off: keep Blizzard portrait.
		self.portrait:SetTexCoord(0, 1, 0, 1)
	end
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
	if ShouldApplyClassIcon(slot.unit) then
		if tex then
			ApplyClassIconToPortrait(tex, slot.unit)
		end
	else
		RestoreDefaultPortrait(slot)
		RefreshUnitFramePortrait(frame)
	end
end

local function RefreshAllPortraits()
	for _, slot in ipairs(PORTRAIT_SLOTS) do
		if IsClassIconPortraitsEnabled() then
			ApplySlotPortrait(slot)
		else
			RestoreDefaultPortrait(slot)
			RefreshUnitFramePortrait(_G[slot.frameName])
		end
	end
	if type(UnitFramePortrait_Update) == "function" then
		for i = 1, 4 do
			local pf = _G["PartyMemberFrame" .. i]
			if pf then
				UnitFramePortrait_Update(pf)
			end
		end
	end
end

function module:UpdateClassIconPortraits(force, onlyUnit)
	EnsurePortraitHook()
	if onlyUnit then
		for _, slot in ipairs(PORTRAIT_SLOTS) do
			if slot.unit == onlyUnit then
				if IsClassIconPortraitsEnabled() then
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
	for _, slot in ipairs(PORTRAIT_SLOTS) do
		RestoreDefaultPortrait(slot)
		RefreshUnitFramePortrait(_G[slot.frameName])
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
