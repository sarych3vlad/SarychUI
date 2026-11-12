-- Dragonflight castbars adapted from DragonUI (NeticSoul) for SarychUI.

local module = SarychUI and SarychUI.modules and SarychUI.modules.castbar
if not module then return end

local DF = {
	frames = {},
	blizzardHidden = {},
	active = false,
}
module.DF = DF

for _, unitType in ipairs({ "player", "target", "focus" }) do
	DF.frames[unitType] = {}
end

local min, max, abs, floor = math.min, math.max, math.abs, math.floor
local format = string.format
local GetTime = GetTime

local function IsUnitUnavailable(unitType)
	return unitType ~= "player" and
		(not UnitExists(unitType) or UnitIsDeadOrGhost(unitType))
end

local TEXTURE_PATH = "Interface\\AddOns\\SarychUI\\media\\castbar\\"
local TEXTURES = {
	atlas = TEXTURE_PATH .. "uicastingbar2x",
	atlasSmall = TEXTURE_PATH .. "uicastingbar",
	standard = TEXTURE_PATH .. "CastingBarStandard2",
	channel = TEXTURE_PATH .. "CastingBarChannel",
	interrupted = TEXTURE_PATH .. "CastingBarInterrupted2",
	spark = TEXTURE_PATH .. "CastingBarSpark",
}

local UV_COORDS = {
	background = { 0.0009765625, 0.4130859375, 0.3671875, 0.41796875 },
	border = { 0.412109375, 0.828125, 0.001953125, 0.060546875 },
	flash = { 0.0009765625, 0.4169921875, 0.2421875, 0.30078125 },
	borderShield = { 0.000976562, 0.0742188, 0.796875, 0.970703 },
	textBorder = { 0.001953125, 0.412109375, 0.00390625, 0.11328125 },
}

local DEFAULTS = {
	player = { sizeX = 256, sizeY = 16, showIcon = false, sizeIcon = 27, holdTime = 0.3, holdTimeInterrupt = 0.8 },
	target = { sizeX = 150, sizeY = 10, showIcon = true, sizeIcon = 20, holdTime = 0.3, holdTimeInterrupt = 0.8 },
	focus = { sizeX = 150, sizeY = 10, showIcon = true, sizeIcon = 20, holdTime = 0.3, holdTimeInterrupt = 0.8 },
}

local function HideChannelTicks(castbar)
	if module.Ticks then
		module.Ticks:Hide(castbar)
	end
end

local function ShowChannelTicks(castbar, spellName, unitType)
	if module.Ticks then
		module.Ticks:Update(castbar, spellName, unitType)
	end
end

local function GetCfg(unitType)
	local cfg = DEFAULTS[unitType]
	if unitType == "player" then
		local db = module.DB and module:DB()
		cfg.showIcon = db and (db.showPlayerIcon == true or db.showPlayerIcon == 1) or false
	end
	return cfg
end

local function GetUnitFrame(unitType)
	if unitType == "player" then return PlayerFrame end
	if unitType == "target" then return TargetFrame end
	if unitType == "focus" then return FocusFrame end
end

local function GetScale(unitType)
	local db = module.DB and module:DB()
	-- The Castbar settings slider belongs to the player's standalone bar.
	-- Target/focus bars follow only their respective unit frame scales.
	local scale = unitType == "player" and db and tonumber(db.scale) or 1
	if scale < 0.5 then
		scale = 0.5
	elseif scale > 2 then
		scale = 2
	end
	-- Anchoring to a unit frame does not inherit its scale: DF containers live
	-- under UIParent. Convert the owner's effective scale to parent coordinates.
	local owner = GetUnitFrame(unitType)
	local frames = DF.frames[unitType]
	local parent = frames and frames.container and frames.container:GetParent() or UIParent
	if owner and parent then
		local parentScale = parent:GetEffectiveScale()
		if parentScale and parentScale > 0 then
			scale = scale * owner:GetEffectiveScale() / parentScale
		end
	end
	return scale
end

local scaleHooked = {}
local function HookOwnerScale(unitType)
	local owner = GetUnitFrame(unitType)
	if not owner or scaleHooked[owner] then return end
	scaleHooked[owner] = true
	hooksecurefunc(owner, "SetScale", function()
		local frames = DF.frames[unitType]
		if DF.active and frames and frames.container then
			frames.container:SetScale(GetScale(unitType))
		end
	end)
end

local function GetBlizzardBar(unitType)
	if unitType == "player" then
		return CastingBarFrame
	elseif unitType == "target" then
		return TargetFrameSpellBar
	elseif unitType == "focus" then
		return FocusFrameSpellBar
	end
	return nil
end

function DF:GetFrame(unitType)
	local frames = self.frames[unitType]
	return frames and frames.castbar
end

local function HideBlizzardCastbar(unitType)
	if DF.blizzardHidden[unitType] then
		return
	end
	local frame = GetBlizzardBar(unitType)
	if not frame then
		return
	end
	-- Keep Blizzard parents/anchors so the DF bar can follow the same spot.
	frame:Hide()
	frame:SetAlpha(0)
	if not frame._suiDFCastHooked then
		frame:HookScript("OnShow", function(self)
			if DF.active and DF.blizzardHidden[unitType] then
				self:Hide()
			end
		end)
		frame._suiDFCastHooked = true
	end
	DF.blizzardHidden[unitType] = true
end

local function ShowBlizzardCastbar(unitType)
	DF.blizzardHidden[unitType] = false
	local frame = GetBlizzardBar(unitType)
	if not frame then
		return
	end
	frame:SetAlpha(1)
	if UnitCastingInfo(unitType) or UnitChannelInfo(unitType) then
		frame:Show()
	end
end

local function ForceStatusBarLayer(statusBar)
	local texture = statusBar and statusBar:GetStatusBarTexture()
	if texture and texture.SetDrawLayer then
		texture:SetDrawLayer("BORDER", 0)
	end
end

local function CreateTextureClipping(statusBar)
	local cachedTexture
	local lastProgress = -1
	local lastChanneling
	statusBar.UpdateTextureClipping = function(self, progress, isChanneling)
		if not cachedTexture then
			cachedTexture = self:GetStatusBarTexture()
		end
		if not cachedTexture then
			return
		end
		if abs(progress - lastProgress) < 0.001 and isChanneling == lastChanneling then
			return
		end
		lastProgress = progress
		lastChanneling = isChanneling
		local clamped = max(0.01, min(0.99, progress))
		cachedTexture:SetTexCoord(0, clamped, 0, 1)
	end
	statusBar.InvalidateTextureCache = function()
		cachedTexture = nil
		lastProgress = -1
		lastChanneling = nil
	end
end

local function RestoreVisibility(unitType)
	local frames = DF.frames[unitType]
	if not frames or not frames.container then
		return
	end
	if UIFrameFadeRemoveFrame then
		UIFrameFadeRemoveFrame(frames.container)
	end
	frames.container:SetAlpha(1)
	frames.container.fadeOutEx = false
	frames.container:Show()
	if frames.castbar then
		if UIFrameFadeRemoveFrame then
			UIFrameFadeRemoveFrame(frames.castbar)
		end
		frames.castbar:SetAlpha(1)
		frames.castbar.fadeOutEx = false
	end
end

local function FadeOutCastbar(unitType, duration)
	local frames = DF.frames[unitType]
	if IsUnitUnavailable(unitType) then
		DF:HideCastbar(unitType)
		return
	end
	-- UIFrameFadeOut calls Show internally; never resurrect a hidden bar.
	if not frames or not frames.container or not frames.container:IsShown() or frames.container.fadeOutEx then
		return
	end
	local container = frames.container
	container.fadeOutEx = true
	if UIFrameFadeOut then
		UIFrameFadeOut(container, duration or 1, 1, 0)
		container.fadeInfo = container.fadeInfo or {}
		local fadeInfo = container.fadeInfo
		local finished = fadeInfo.finishedFunc
		fadeInfo.finishedFunc = function(...)
			container:Hide()
			container.fadeOutEx = false
			if type(finished) == "function" then
				finished(...)
			end
		end
	else
		container:SetAlpha(0)
		container:Hide()
		container.fadeOutEx = false
	end
end

local flashTimers = {}

local function ShowSuccessFlash(unitType)
	local frames = DF.frames[unitType]
	if not frames then
		return
	end
	local cfg = GetCfg(unitType)
	local holdDuration = (cfg and cfg.holdTime) or 0.3
	if frames.flashTimer then
		frames.flashTimer:SetScript("OnUpdate", nil)
		frames.flashTimer = nil
	end
	if frames.flash then
		frames.flash:SetAlpha(1)
		frames.flash:Show()
		if not flashTimers[unitType] then
			flashTimers[unitType] = CreateFrame("Frame")
		end
		local flashFrame = flashTimers[unitType]
		flashFrame.elapsed = 0
		flashFrame:SetScript("OnUpdate", function(self, elapsed)
			self.elapsed = self.elapsed + elapsed
			if self.elapsed < holdDuration then
				return
			end
			self:SetScript("OnUpdate", nil)
			local f = DF.frames[unitType]
			if not f then
				return
			end
			if f.flash then
				f.flash:Hide()
			end
			f.flashTimer = nil
			if f.castbar and not (f.castbar.castingEx or f.castbar.channelingEx) then
				FadeOutCastbar(unitType, 0.5)
			end
		end)
		frames.flashTimer = flashFrame
	else
		FadeOutCastbar(unitType, holdDuration)
	end
end

local function CreateShield(container, castbar, icon, frameName, iconSize)
	local shield = CreateFrame("Frame", frameName .. "Shield", container)
	shield:SetFrameLevel(max(0, castbar:GetFrameLevel() - 1))
	shield:SetSize(iconSize * 1.8, iconSize * 2.0)
	local texture = shield:CreateTexture(nil, "ARTWORK", nil, 3)
	texture:SetAllPoints(shield)
	texture:SetTexture(TEXTURES.atlas)
	texture:SetTexCoord(unpack(UV_COORDS.borderShield))
	shield:SetPoint("CENTER", icon, "CENTER", 0, -2)
	shield:Hide()
	return shield
end

local function AnchorShieldedIcon(frames, cfg)
	if not frames.icon or not frames.castbar then
		return
	end
	local iconScale = ((cfg and cfg.sizeIcon) or 20) / 16
	local gap = (frames.shield and frames.shield:IsShown()) and 7 or 4
	frames.icon:ClearAllPoints()
	frames.icon:SetPoint("RIGHT", frames.castbar, "LEFT", -gap * iconScale, -4)
end

local function GetActionButtonBorderAlpha()
	local style = _G.SarychUI_InterfaceStyle
	if style and style.enabled and style.UseStyleTextures and style.UseStyleTextures() then return 1 end
	local profile = SarychUI and SarychUI.db and SarychUI.db.profile
	local db = profile and profile.modules and profile.modules.mainmenubar
	if db and (db.buttonBorderAlphaEnabled == true or db.buttonBorderAlphaEnabled == 1) then
		return tonumber(db.buttonBorderAlpha) or 0.4
	end
	return 1
end

local function UsesPlayerIconCooldown()
	local db = module.DB and module:DB()
	return not db or db.showPlayerIconCooldown ~= false
end

local function SetIconBordersShown(frames, shown)
	if frames.iconButton then
		if shown then
			local normal = frames.iconButton:GetNormalTexture()
			if normal then
				normal:SetAlpha(GetActionButtonBorderAlpha())
			end
			frames.iconButton:SetChecked(true)
			frames.iconButton:Show()
		else
			frames.iconButton:SetChecked(false)
			frames.iconButton:Hide()
		end
		return
	end
	if frames.icon and frames.icon.Border then
		if shown then
			frames.icon.Border:SetAlpha(GetActionButtonBorderAlpha())
			frames.icon.Border:Show()
		else
			frames.icon.Border:Hide()
		end
	end
end

local function GetSpellIcon(spellName, texture)
	if texture and texture ~= "" then
		return texture
	end
	if spellName then
		local _, _, icon = GetSpellInfo(spellName)
		if icon then
			return icon
		end
	end
	return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function ParseCastTimes(startTime, endTime)
	local start = (startTime or 0) / 1000
	local finish = (endTime or 0) / 1000
	local duration = finish - start
	if duration > 3600 or duration < 0 then
		duration = 3
	end
	return start, finish, duration
end

local function SetCastText(unitType, text)
	local frames = DF.frames[unitType]
	if frames and frames.castTextCentered then
		frames.castTextCentered:SetText(text or "")
		frames.castTextCentered:Show()
	end
end

local function CreateCastbar(unitType)
	if DF.frames[unitType].castbar then
		return
	end
	local frameName = "SarychUI" .. unitType:sub(1, 1):upper() .. unitType:sub(2) .. "Castbar"
	local frames = DF.frames[unitType]
	local cfg = GetCfg(unitType)

	frames.container = CreateFrame("Frame", frameName .. "Container", UIParent)
	frames.container:SetFrameStrata("MEDIUM")
	frames.container:SetFrameLevel(10)
	frames.container:SetSize(cfg.sizeX, cfg.sizeY)
	frames.container:Hide()

	frames.castbar = CreateFrame("StatusBar", frameName, frames.container)
	frames.castbar:SetFrameLevel(2)
	frames.castbar:SetAllPoints(frames.container)
	frames.castbar:SetMinMaxValues(0, 1)
	frames.castbar:SetValue(0)
	frames.castbar.castingEx = false
	frames.castbar.channelingEx = false
	frames.castbar.fadeOutEx = false
	frames.castbar.selfInterrupt = false

	local bg = frames.castbar:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture(TEXTURES.atlas)
	bg:SetTexCoord(unpack(UV_COORDS.background))
	bg:SetPoint("TOPLEFT", frames.castbar, "TOPLEFT", -2, 0)
	bg:SetPoint("BOTTOMRIGHT", frames.castbar, "BOTTOMRIGHT", 2, 0)

	frames.castbar:SetStatusBarTexture(TEXTURES.standard)
	local texture = frames.castbar:GetStatusBarTexture()
	if texture then
		texture:SetVertexColor(1, 1, 1, 1)
	end
	frames.castbar:SetStatusBarColor(1, 0.7, 0, 1)

	local border = frames.castbar:CreateTexture(nil, "ARTWORK", nil, 0)
	border:SetTexture(TEXTURES.atlas)
	border:SetTexCoord(unpack(UV_COORDS.border))
	border:SetPoint("TOPLEFT", frames.castbar, "TOPLEFT", -2, 2)
	border:SetPoint("BOTTOMRIGHT", frames.castbar, "BOTTOMRIGHT", 2, -2)

	frames.flash = frames.castbar:CreateTexture(nil, "OVERLAY")
	frames.flash:SetTexture(TEXTURES.atlas)
	frames.flash:SetTexCoord(unpack(UV_COORDS.flash))
	frames.flash:SetBlendMode("ADD")
	frames.flash:SetAllPoints()
	frames.flash:Hide()

	frames.textBackground = CreateFrame("Frame", frameName .. "TextBG", frames.container)
	frames.textBackground:SetFrameLevel(1)
	local textBg = frames.textBackground:CreateTexture(nil, "BACKGROUND")
	if unitType == "player" then
		textBg:SetTexture(TEXTURES.atlas)
		textBg:SetTexCoord(0.001953125, 0.410109375, 0.00390625, 0.11328125)
	else
		textBg:SetTexture(TEXTURES.atlasSmall)
		textBg:SetTexCoord(unpack(UV_COORDS.textBorder))
	end
	textBg:SetAllPoints()

	local fontTemplate = unitType == "player" and "GameFontHighlight" or "GameFontHighlightSmall"
	frames.castTextCentered = frames.textBackground:CreateFontString(nil, "OVERLAY", fontTemplate)
	frames.castTextCentered:SetPoint("BOTTOM", frames.textBackground, "BOTTOM", 0, 2)
	frames.castTextCentered:SetPoint("LEFT", frames.textBackground, "LEFT", 8, 0)
	frames.castTextCentered:SetPoint("RIGHT", frames.textBackground, "RIGHT", -8, 0)
	frames.castTextCentered:SetJustifyH("CENTER")

	frames.spark = CreateFrame("Frame", frameName .. "Spark", frames.container)
	frames.spark:SetFrameLevel(5)
	frames.spark:SetSize(16, 16)
	frames.spark:Hide()
	local sparkTexture = frames.spark:CreateTexture(nil, "OVERLAY")
	sparkTexture:SetTexture(TEXTURES.spark)
	sparkTexture:SetAllPoints()
	sparkTexture:SetBlendMode("ADD")

	if unitType == "player" then
		local buttonName = frameName .. "IconButton"
		frames.iconButton = CreateFrame("CheckButton", buttonName, frames.castbar, "ActionButtonTemplate")
		frames.iconButton:SetFrameLevel(frames.castbar:GetFrameLevel() + 4)
		frames.iconButton:EnableMouse(false)
		frames.iconButton:Hide()
		frames.icon = _G[buttonName .. "Icon"]
		frames.iconFlash = _G[buttonName .. "Flash"]
		frames.iconBorder = _G[buttonName .. "Border"]
		frames.iconCooldown = _G[buttonName .. "Cooldown"]
		if frames.icon then
			frames.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			frames.icon:SetAllPoints(frames.iconButton)
		end
	else
		frames.icon = frames.castbar:CreateTexture(frameName .. "Icon", "ARTWORK")
		frames.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		frames.icon:Hide()

		local iconBorder = frames.castbar:CreateTexture(nil, "ARTWORK")
		iconBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")
		iconBorder:SetTexCoord(0.05, 0.95, 0.05, 0.95)
		iconBorder:SetVertexColor(0.8, 0.8, 0.8, 1)
		iconBorder:Hide()
		frames.icon.Border = iconBorder
	end

	if unitType ~= "player" then
		frames.shield = CreateShield(frames.container, frames.castbar, frames.icon, frameName, 20)
	end

	CreateTextureClipping(frames.castbar)
	frames.castbar:SetScript("OnUpdate", function(self, elapsed)
		DF:OnUpdate(unitType, self, elapsed)
	end)
end

local function LayoutCastbar(unitType)
	local frames = DF.frames[unitType]
	if not frames or not frames.container then
		return
	end
	local cfg = GetCfg(unitType)
	local blizz = GetBlizzardBar(unitType)
	local playerOffsetY = 0
	if unitType == "player" then
		local db = module.DB and module:DB()
		playerOffsetY = db and tonumber(db.dragonflightCastbarOffsetY) or 0
	end
	frames.container:ClearAllPoints()
	if blizz then
		frames.container:SetPoint("CENTER", blizz, "CENTER", 0, playerOffsetY)
	elseif unitType == "player" then
		frames.container:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 55 + playerOffsetY)
	elseif unitType == "target" and TargetFrame then
		frames.container:SetPoint("TOPLEFT", TargetFrame, "BOTTOMLEFT", 25, 7)
	elseif unitType == "focus" and FocusFrame then
		frames.container:SetPoint("TOPLEFT", FocusFrame, "BOTTOMLEFT", 25, 7)
	else
		frames.container:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
	end
	frames.container:SetSize(cfg.sizeX, cfg.sizeY)
	frames.container:SetScale(GetScale(unitType))

	if frames.textBackground then
		frames.textBackground:ClearAllPoints()
		frames.textBackground:SetPoint("TOP", frames.castbar, "BOTTOM", 0, unitType == "player" and 6 or 8)
		frames.textBackground:SetSize(cfg.sizeX, unitType == "player" and 22 or 20)
	end

	if frames.icon then
		local iconSize = cfg.sizeIcon
		if unitType == "player" and frames.iconButton then
			frames.iconButton:ClearAllPoints()
			frames.iconButton:SetSize(iconSize, iconSize)
			frames.iconButton:SetPoint("TOPLEFT", frames.castbar, "TOPLEFT", -(iconSize + 6), -1)
			frames.icon:ClearAllPoints()
			frames.icon:SetAllPoints(frames.iconButton)

			local normal = frames.iconButton:GetNormalTexture()
			if normal then
				normal:ClearAllPoints()
				normal:SetPoint("CENTER", frames.iconButton, "CENTER", 0, -iconSize / 36)
				normal:SetSize(iconSize * 66 / 36, iconSize * 66 / 36)
			end
			for _, texture in pairs({
				frames.iconButton:GetPushedTexture(),
				frames.iconButton:GetHighlightTexture(),
				frames.iconButton:GetCheckedTexture(),
				frames.iconFlash,
			}) do
				if texture then
					texture:ClearAllPoints()
					texture:SetAllPoints(frames.iconButton)
				end
			end
			if frames.iconBorder then
				frames.iconBorder:ClearAllPoints()
				frames.iconBorder:SetPoint("CENTER", frames.iconButton, "CENTER", 0, 0)
				frames.iconBorder:SetSize(iconSize * 62 / 36, iconSize * 62 / 36)
			end
			if frames.iconCooldown then
				frames.iconCooldown:ClearAllPoints()
				frames.iconCooldown:SetAllPoints(frames.iconButton)
			end
		else
			frames.icon:SetSize(iconSize, iconSize)
			AnchorShieldedIcon(frames, cfg)
		end
		if frames.icon.Border then
			frames.icon.Border:ClearAllPoints()
			frames.icon.Border:SetPoint("CENTER", frames.icon, "CENTER", 0, 0)
			frames.icon.Border:SetSize(iconSize * 1.7, iconSize * 1.7)
		end
		if frames.shield then
			frames.shield:SetSize(iconSize * 1.8, iconSize * 2.0)
		end
	end

	if frames.spark then
		frames.spark:SetSize(cfg.sizeY, cfg.sizeY * 2)
	end
end

function DF:HideCastbar(unitType)
	local frames = self.frames[unitType]
	if frames.flashTimer then
		frames.flashTimer:SetScript("OnUpdate", nil)
		frames.flashTimer = nil
	end
	if frames.flash then frames.flash:Hide() end
	if frames.spark then frames.spark:Hide() end
	if frames.container then
		if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(frames.container) end
		frames.container.fadeOutEx = false
		frames.container:Hide()
	end
	local castbar = frames.castbar
	if castbar then
		if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(castbar) end
		HideChannelTicks(castbar)
		castbar.castingEx = false
		castbar.channelingEx = false
		castbar.fadeOutEx = false
		castbar.selfInterrupt = false
		castbar.notInterruptible = false
		castbar.startTime = 0
		castbar.endTime = 0
		castbar.spellName = nil
		castbar.castID = nil
		castbar.duration = nil
		castbar.unit = nil
	end
	if frames.shield then
		frames.shield:Hide()
	end
	if frames.iconButton then
		frames.iconButton:SetChecked(false)
		frames.iconButton:Hide()
	end
	if frames.iconCooldown and CooldownFrame_SetTimer then
		CooldownFrame_SetTimer(frames.iconCooldown, 0, 0, 0)
		if SarychUI_NotifyCooldown then SarychUI_NotifyCooldown(frames.iconCooldown, 0, 0, 0) end
	end
end

function DF:ApplyScale()
	if not self.active then
		return
	end
	for _, unitType in ipairs({ "player", "target", "focus" }) do
		local frames = self.frames[unitType]
		if frames and frames.container then
			frames.container:SetScale(GetScale(unitType))
		end
	end
end

function DF:ApplyPlayerOffset()
	if self.active then LayoutCastbar("player") end
end

function DF:ApplyPlayerIcon()
	local frames = self.frames.player
	local cfg = GetCfg("player")
	if not frames or not frames.icon then
		return
	end

	local castbar = frames.castbar
	if self.active and cfg.showIcon and castbar and castbar.spellName and frames.container and frames.container:IsShown() then
		local spell, icon
		if castbar.channelingEx then
			spell, _, _, icon = UnitChannelInfo("player")
		elseif castbar.castingEx then
			spell, _, _, icon = UnitCastingInfo("player")
		end
		frames.icon:SetTexture(GetSpellIcon(spell or castbar.spellName, icon))
		frames.icon:Show()
		SetIconBordersShown(frames, true)
	else
		frames.icon:Hide()
		SetIconBordersShown(frames, false)
	end
end

function DF:ApplyPlayerIconBorderAlpha()
	local frames = self.frames.player
	local normal = frames and frames.iconButton and frames.iconButton:GetNormalTexture()
	if normal then
		normal:SetAlpha(GetActionButtonBorderAlpha())
	end
end

function DF:ApplyPlayerIconCooldown()
	local frames = self.frames.player
	local cooldown = frames and frames.iconCooldown
	local castbar = frames and frames.castbar
	if not cooldown or not CooldownFrame_SetTimer then
		return
	end
	if UsesPlayerIconCooldown() and castbar and (castbar.castingEx or castbar.channelingEx) then
		local start = castbar.startTime or 0
		local duration = (castbar.endTime or start) - start
		CooldownFrame_SetTimer(cooldown, start, duration, 1)
		if SarychUI_NotifyCooldown then SarychUI_NotifyCooldown(cooldown, start, duration, 1) end
	else
		CooldownFrame_SetTimer(cooldown, 0, 0, 0)
		if SarychUI_NotifyCooldown then SarychUI_NotifyCooldown(cooldown, 0, 0, 0) end
	end
end

function DF:RefreshCastbar(unitType)
	if not self.active then
		self:HideCastbar(unitType)
		return
	end
	HideBlizzardCastbar(unitType)
	if not self.frames[unitType].castbar then
		CreateCastbar(unitType)
	end
	HookOwnerScale(unitType)
	LayoutCastbar(unitType)
end

function DF:HandleCastStart(unitType, unit, isChanneling)
	if not self.active or IsUnitUnavailable(unitType) then
		self:HideCastbar(unitType)
		return
	end
	local spell, icon, startTime, endTime, notInterruptible, castID
	if isChanneling then
		spell, _, _, icon, startTime, endTime, _, notInterruptible = UnitChannelInfo(unit)
	else
		spell, _, _, icon, startTime, endTime, _, castID, notInterruptible = UnitCastingInfo(unit)
	end
	if not spell then
		return
	end

	self:RefreshCastbar(unitType)
	local frames = self.frames[unitType]
	local castbar = frames.castbar
	if not castbar then
		return
	end

	if unitType == "target" or unitType == "focus" then
		castbar.unit = UnitGUID(unit)
	end

	local start, finish = ParseCastTimes(startTime, endTime)
	castbar.startTime = start
	castbar.endTime = finish
	castbar.duration = max(finish - start, 0.001)
	castbar.spellName = spell
	castbar.castID = castID
	castbar.fadeOutEx = false
	if frames.container then
		frames.container.fadeOutEx = false
	end
	if frames.flashTimer then
		frames.flashTimer:SetScript("OnUpdate", nil)
		frames.flashTimer = nil
	end

	castbar:SetMinMaxValues(0, 1)
	if isChanneling then
		castbar:SetValue(1)
		castbar.channelingEx = true
		castbar.castingEx = false
		if castbar.UpdateTextureClipping then
			castbar:UpdateTextureClipping(1, true)
		end
	else
		castbar:SetValue(0)
		castbar.castingEx = true
		castbar.channelingEx = false
		if castbar.UpdateTextureClipping then
			castbar:UpdateTextureClipping(0, false)
		end
	end

	HideChannelTicks(castbar)
	if castbar.InvalidateTextureCache then
		castbar:InvalidateTextureCache()
	end
	if isChanneling then
		castbar:SetStatusBarTexture(TEXTURES.channel)
		castbar:SetStatusBarColor(unitType == "player" and 0 or 1, 1, 1, 1)
		ShowChannelTicks(castbar, spell, unitType)
	else
		castbar:SetStatusBarTexture(TEXTURES.standard)
		castbar:SetStatusBarColor(1, 0.7, 0, 1)
	end
	local texture = castbar:GetStatusBarTexture()
	if texture then
		texture:SetVertexColor(1, 1, 1, 1)
	end
	ForceStatusBarLayer(castbar)
	RestoreVisibility(unitType)
	if unitType == "player" and frames.iconCooldown and CooldownFrame_SetTimer then
		if UsesPlayerIconCooldown() then
			CooldownFrame_SetTimer(frames.iconCooldown, start, finish - start, 1)
			if SarychUI_NotifyCooldown then SarychUI_NotifyCooldown(frames.iconCooldown, start, finish - start, 1) end
		else
			CooldownFrame_SetTimer(frames.iconCooldown, 0, 0, 0)
			if SarychUI_NotifyCooldown then SarychUI_NotifyCooldown(frames.iconCooldown, 0, 0, 0) end
		if SarychUI_NotifyCooldown then SarychUI_NotifyCooldown(frames.iconCooldown, 0, 0, 0) end
		end
	end

	if frames.spark then
		frames.spark:Show()
	end
	if frames.flash then
		frames.flash:Hide()
	end
	SetCastText(unitType, spell)

	local cfg = GetCfg(unitType)
	if unitType ~= "player" then
		castbar.notInterruptible = notInterruptible and true or false
		local sbTexture = castbar:GetStatusBarTexture()
		if sbTexture and sbTexture.SetDesaturated then
			sbTexture:SetDesaturated(castbar.notInterruptible)
		end
		if frames.shield then
			if castbar.notInterruptible then
				frames.shield:Show()
			else
				frames.shield:Hide()
			end
		end
	else
		castbar.notInterruptible = false
	end

	if frames.icon and cfg.showIcon then
		frames.icon:SetTexture(GetSpellIcon(spell, icon))
		frames.icon:Show()
		SetIconBordersShown(frames, true)
	else
		if frames.icon then
			frames.icon:Hide()
		end
		SetIconBordersShown(frames, false)
		if frames.shield then
			frames.shield:Hide()
		end
	end
	if frames.shield then
		AnchorShieldedIcon(frames, cfg)
	end
	if frames.textBackground then
		frames.textBackground:Show()
	end
end

function DF:HandleCastStop(unitType, wasInterrupted, isChannelStop, overrideText)
	if IsUnitUnavailable(unitType) then
		self:HideCastbar(unitType)
		return
	end
	local frames = self.frames[unitType]
	local castbar = frames and frames.castbar
	if not castbar then
		return
	end
	if unitType == "target" and castbar.unit ~= UnitGUID("target") then
		return
	end
	if unitType == "focus" and castbar.unit ~= UnitGUID("focus") then
		return
	end
	if not (castbar.castingEx or castbar.channelingEx) then
		return
	end

	if not wasInterrupted then
		local unit = unitType
		if UnitCastingInfo(unit) or UnitChannelInfo(unit) then
			return
		end
	end

	castbar.castingEx = false
	castbar.channelingEx = false
	castbar.selfInterrupt = false
	if frames.iconButton then
		frames.iconButton:SetChecked(false)
	end
	if frames.iconCooldown and CooldownFrame_SetTimer then
		CooldownFrame_SetTimer(frames.iconCooldown, 0, 0, 0)
		if SarychUI_NotifyCooldown then SarychUI_NotifyCooldown(frames.iconCooldown, 0, 0, 0) end
	end
	if not wasInterrupted and not isChannelStop and unitType ~= "player" then
		if not (UnitIsUnit and UnitIsUnit(unitType, "player")) then
			if GetTime() < (castbar.endTime or 0) - 0.4 then
				castbar.selfInterrupt = true
			end
		end
	end

	local cfg = GetCfg(unitType)
	if wasInterrupted or castbar.selfInterrupt then
		if frames.spark then frames.spark:Hide() end
		if frames.flash then frames.flash:Hide() end
		HideChannelTicks(castbar)
		if castbar.InvalidateTextureCache then
			castbar:InvalidateTextureCache()
		end
		castbar:SetStatusBarTexture(TEXTURES.interrupted)
		castbar:SetStatusBarColor(1, 0, 0, 1)
		castbar:SetValue(1)
		local texture = castbar:GetStatusBarTexture()
		if texture then
			texture:SetTexCoord(0, 1, 0, 1)
			texture:SetVertexColor(1, 1, 1, 1)
		end
		local displayText = overrideText
		if not displayText then
			displayText = castbar.selfInterrupt and FAILED or INTERRUPTED
		end
		SetCastText(unitType, displayText)
		FadeOutCastbar(unitType, (cfg and cfg.holdTimeInterrupt) or 0.8)
	else
		if frames.spark then frames.spark:Hide() end
		HideChannelTicks(castbar)
		castbar:SetValue(1)
		if castbar.InvalidateTextureCache then
			castbar:InvalidateTextureCache()
		end
		local texture = castbar:GetStatusBarTexture()
		if texture then
			texture:SetTexCoord(0, 1, 0, 1)
			texture:SetVertexColor(1, 1, 1, 1)
		end
		ShowSuccessFlash(unitType)
	end
end

function DF:HandleCastFailed(unitType, eventSpell, _, eventCastID)
	local castbar = self.frames[unitType] and self.frames[unitType].castbar
	if not castbar or not (castbar.castingEx or castbar.channelingEx) then
		return
	end
	if castbar.channelingEx then
		local active = UnitChannelInfo(unitType)
		if active and castbar.spellName and active == castbar.spellName then
			return
		end
	end
	if castbar.castID then
		if eventCastID ~= castbar.castID then
			return
		end
	elseif eventSpell and castbar.spellName and eventSpell ~= castbar.spellName then
		return
	end
	self:HandleCastStop(unitType, true, nil, FAILED)
end

function DF:HandleCastInterrupted(unitType, eventSpell, _, eventCastID)
	local castbar = self.frames[unitType] and self.frames[unitType].castbar
	if not castbar or not (castbar.castingEx or castbar.channelingEx) then
		return
	end
	if castbar.castID then
		if eventCastID ~= castbar.castID then
			return
		end
	elseif eventSpell and castbar.spellName and eventSpell ~= castbar.spellName then
		return
	end
	self:HandleCastStop(unitType, true)
end

function DF:HandleCastDelayed(unitType, unit)
	local castbar = self.frames[unitType] and self.frames[unitType].castbar
	if not castbar or not (castbar.castingEx or castbar.channelingEx) then
		return
	end
	local spell, startTime, endTime
	if castbar.castingEx then
		spell, _, _, _, startTime, endTime = UnitCastingInfo(unit)
	else
		spell, _, _, _, startTime, endTime = UnitChannelInfo(unit)
	end
	if not spell then
		self:HideCastbar(unitType)
		return
	end
	-- Gnosis keeps the initial duration: pushback moves the end, not the scale.
	local duration = castbar.duration or max(castbar.endTime - castbar.startTime, 0.001)
	castbar.duration = duration
	castbar.endTime = endTime / 1000
	castbar.startTime = castbar.endTime - duration
	if castbar.channelingEx then
		ShowChannelTicks(castbar, spell, unitType)
	end
	if unitType == "player" then
		self:ApplyPlayerIconCooldown()
	end
end

function DF:HandleInterruptibleChanged(unitType, isNotInterruptible)
	if unitType == "player" then
		return
	end
	local frames = self.frames[unitType]
	local castbar = frames and frames.castbar
	if not castbar or not (castbar.castingEx or castbar.channelingEx) then
		return
	end
	castbar.notInterruptible = isNotInterruptible
	local sbTexture = castbar:GetStatusBarTexture()
	if sbTexture and sbTexture.SetDesaturated then
		sbTexture:SetDesaturated(isNotInterruptible and true or false)
	end
	if frames.shield then
		if isNotInterruptible and frames.icon and frames.icon:IsShown() then
			frames.shield:Show()
		else
			frames.shield:Hide()
		end
		AnchorShieldedIcon(frames, GetCfg(unitType))
	end
end

function DF:OnUpdate(unitType, castbar, elapsed)
	if IsUnitUnavailable(unitType) then
		self:HideCastbar(unitType)
		return
	end
	if not castbar.castingEx and not castbar.channelingEx then
		return
	end
	local frames = self.frames[unitType]
	if not frames then
		return
	end
	local currentTime = GetTime()
	local value = 0
	local duration = castbar.duration or max(castbar.endTime - castbar.startTime, 0.001)
	if castbar.castingEx then
		value = 1 - (castbar.endTime - currentTime) / duration
	else
		local remaining = castbar.endTime - currentTime
		value = remaining / duration
	end
	value = max(0, min(1, value))
	castbar:SetValue(value)
	if castbar.UpdateTextureClipping then
		castbar:UpdateTextureClipping(value, castbar.channelingEx)
	end
	if currentTime > castbar.endTime then
		if not UnitCastingInfo(unitType) and not UnitChannelInfo(unitType) then
			castbar.castingEx = false
			castbar.channelingEx = false
			if frames.spark then frames.spark:Hide() end
			HideChannelTicks(castbar)
			ShowSuccessFlash(unitType)
		end
		return
	end
	if frames.spark and frames.spark:IsShown() then
		frames.spark:ClearAllPoints()
		frames.spark:SetPoint("CENTER", castbar, "LEFT", value * castbar:GetWidth(), 0)
	end
end

function DF:HandleCastingEvent(event, unit, ...)
	local unitType
	if unit == "player" or unit == "target" or unit == "focus" then
		unitType = unit
	else
		return
	end
	if not self.active then
		return
	end
	if IsUnitUnavailable(unitType) then
		self:HideCastbar(unitType)
		return
	end
	HideBlizzardCastbar(unitType)
	local frames = self.frames[unitType]
	if unitType ~= "player" then
		if not frames.castbar then
			return
		end
		if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
			frames.castbar.unit = UnitGUID(unit)
		elseif frames.castbar.unit ~= UnitGUID(unit) then
			return
		end
	end
	if event == "UNIT_SPELLCAST_START" then
		self:HandleCastStart(unitType, unit, false)
	elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
		self:HandleCastStart(unitType, unit, true)
	elseif event == "UNIT_SPELLCAST_STOP" then
		self:HandleCastStop(unitType, false)
	elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		self:HandleCastStop(unitType, false, true)
	elseif event == "UNIT_SPELLCAST_FAILED" then
		self:HandleCastFailed(unitType, ...)
	elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
		self:HandleCastInterrupted(unitType, ...)
	elseif event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
		self:HandleCastDelayed(unitType, unit)
	elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
		self:HandleInterruptibleChanged(unitType, true)
	elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
		self:HandleInterruptibleChanged(unitType, false)
	end
end

function DF:HandleUnitChanged(unitType)
	local frames = self.frames[unitType]
	local statusBar = frames and frames.castbar
	if not statusBar then
		self:RefreshCastbar(unitType)
		statusBar = self.frames[unitType].castbar
	end
	if statusBar then
		if UnitExists(unitType) and statusBar.unit == UnitGUID(unitType) then
			if GetTime() > (statusBar.endTime or 0) then
				self:HideCastbar(unitType)
			end
		else
			self:HideCastbar(unitType)
		end
	end
	self:RefreshCastbar(unitType)
	if UnitExists(unitType) then
		if UnitCastingInfo(unitType) then
			self:HandleCastingEvent("UNIT_SPELLCAST_START", unitType)
		elseif UnitChannelInfo(unitType) then
			self:HandleCastingEvent("UNIT_SPELLCAST_CHANNEL_START", unitType)
		end
	end
end

local function OnEvent(_, event, unit, ...)
	if not DF.active then
		return
	end
	if event == "PLAYER_TARGET_CHANGED" then
		DF:HandleUnitChanged("target")
	elseif event == "PLAYER_FOCUS_CHANGED" then
		DF:HandleUnitChanged("focus")
	elseif event == "UNIT_HEALTH" or event == "UNIT_FLAGS" then
		if (unit == "target" or unit == "focus") and IsUnitUnavailable(unit) then
			DF:HideCastbar(unit)
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		if module.Ticks then
			module.Ticks:RebuildSpellMap()
		end
		DF:RefreshCastbar("player")
		DF:RefreshCastbar("target")
		DF:RefreshCastbar("focus")
	else
		DF:HandleCastingEvent(event, unit, ...)
	end
end

local eventFrame = CreateFrame("Frame", "SarychUICastbarEventHandler")
local EVENTS = {
	"UNIT_HEALTH",
	"UNIT_FLAGS",
	"PLAYER_ENTERING_WORLD",
	"UNIT_SPELLCAST_START",
	"UNIT_SPELLCAST_DELAYED",
	"UNIT_SPELLCAST_STOP",
	"UNIT_SPELLCAST_FAILED",
	"UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_CHANNEL_START",
	"UNIT_SPELLCAST_CHANNEL_STOP",
	"UNIT_SPELLCAST_CHANNEL_UPDATE",
	"UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
	"UNIT_SPELLCAST_INTERRUPTIBLE",
	"PLAYER_TARGET_CHANGED",
	"PLAYER_FOCUS_CHANGED",
}

function DF:Enable()
	if self.active then
		self:RefreshCastbar("player")
		self:RefreshCastbar("target")
		self:RefreshCastbar("focus")
		return
	end
	if module.Ticks then
		module.Ticks:RebuildSpellMap()
	end
	self.active = true
	if not self.eventsRegistered then
		for i = 1, #EVENTS do
			pcall(eventFrame.RegisterEvent, eventFrame, EVENTS[i])
		end
		eventFrame:SetScript("OnEvent", OnEvent)
		if type(Target_Spellbar_AdjustPosition) == "function" and not self.layoutHooked then
			hooksecurefunc("Target_Spellbar_AdjustPosition", function(spellbar)
				if not DF.active then
					return
				end
				if spellbar == TargetFrameSpellBar then
					LayoutCastbar("target")
				elseif spellbar == FocusFrameSpellBar then
					LayoutCastbar("focus")
				end
			end)
			self.layoutHooked = true
		end
		self.eventsRegistered = true
	end
	self:RefreshCastbar("player")
	self:RefreshCastbar("target")
	self:RefreshCastbar("focus")
	if UnitCastingInfo("player") then
		self:HandleCastingEvent("UNIT_SPELLCAST_START", "player")
	elseif UnitChannelInfo("player") then
		self:HandleCastingEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
	end
end

function DF:Disable()
	self.active = false
	for _, unitType in ipairs({ "player", "target", "focus" }) do
		self:HideCastbar(unitType)
		ShowBlizzardCastbar(unitType)
	end
end
