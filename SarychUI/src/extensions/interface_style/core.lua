-- Tint Blizzard artwork, optionally replacing icon borders with Gloss textures.
SarychUI_InterfaceStyle = {}
local Style = SarychUI_InterfaceStyle

Style.enabled = false
local media = [[Interface\AddOns\SarychUI\media\components\extensions\interface_style\media\]]
Style.textures = {
	normal = media .. "gloss",
	debuffOriginal = media .. "gloss_grey",
	hover = media .. "hover",
	pushed = media .. "pushed",
	flash = media .. "flash",
	background = media .. "button_background_flat",
	shadow = media .. "outer_shadow",
}
Style.normalTexture = Style.textures.normal

function Style:GetDB()
	local profile = SarychUI and SarychUI.db and SarychUI.db.profile
	return profile and profile.modules and profile.modules.interface_style
end

function Style:GetGlossBrightness()
	local db = self:GetDB()
	local value = tonumber(db and db.glossBrightness) or 1
	return math.max(0, math.min(1, value))
end

function Style:GetCropIcons()
	local db = self:GetDB()
	return not db or db.cropIcons ~= false
end

function Style.GetColor()
	local db = Style:GetDB()
	return SarychUI.Frameworks.TextureColor(db and db.styleColor, 0.37)
end

function Style:GetBackgroundColor()
	local db = self:GetDB()
	return SarychUI.Frameworks.TextureColor(db and db.backgroundColor, 0)
end

function Style:GetButtonBorderAlpha()
	local modules = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	local db = modules and modules.mainmenubar
	return SarychUI.Frameworks.ButtonBorderAlpha(db and db.buttonBorderAlphaEnabled,
		db and db.buttonBorderAlpha)
end

-- Kept for artwork consumers; the extension now has one texture style.
function Style:GetTextureMode()
	return "black"
end

function Style:GetBorderColor(original)
	local r, g, b, a = self.GetColor()
	local brightness = self:GetGlossBrightness()
	return SarychUI.Frameworks.ModulateTextureColor(r, g, b, a, brightness, original)
end

function Style:GetDebuffOriginalColor()
	local db = self:GetDB()
	return db and db.debuffOriginalColor == true or false
end

function Style.IsSettingOn()
	return Style.enabled
end

function Style:RefreshOtherArtwork()
	local frame = SarychUI.modules and SarychUI.modules.frame
	if frame and frame.ApplyClassIcons then frame:ApplyClassIcons() end
	local resources = SarychUI.modules and SarychUI.modules.player_resources
	if resources and resources.ApplyTotemsInterfaceStyle then
		resources:ApplyTotemsInterfaceStyle()
	end
	local arena = SarychUI.modules and SarychUI.modules.arena
	if arena and arena.RefreshTrinketBorders then arena:RefreshTrinketBorders() end
end

function Style.UseStyleTextures()
	return Style.enabled
end

function Style:RefreshColor()
	if not self.enabled then return end
	self:RefreshGloss()
	if self.RefreshFrames then self:RefreshFrames() end
	self:RefreshOtherArtwork()
end

function Style:Apply()
	local db = self:GetDB()
	if not (db and db.enabled) then
		self:Disable()
		return
	end
	-- Retire the removed original-dark selection without losing appearance settings.
	db.textureMode = nil
	self.enabled = true
	self:InstallButtonHooks()
	self:ApplyButtons()
	self:ApplyItemButtons()
	if self.ApplyFrames then self:ApplyFrames() end
	if self.ApplyAuras then self:ApplyAuras() end
	if self.ApplyCompactRaid then self:ApplyCompactRaid() end
	self:RefreshOtherArtwork()
end

function Style:Enable()
	self:Apply()
end

function Style:Disable()
	if not self.enabled then return end
	self.enabled = false
	self:RestoreButtons()
	if self.RestoreAuras then self:RestoreAuras() end
	if self.RestoreCompactRaid then self:RestoreCompactRaid() end
	if self.RestoreFrames then self:RestoreFrames() end
	local menu = SarychUI.modules and SarychUI.modules.mainmenubar
	local modules = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	if menu and menu.ApplyButtonBorderAlpha and modules and modules.mainmenubar
		and modules.mainmenubar.enabled then menu:ApplyButtonBorderAlpha() end
	self:RefreshOtherArtwork()
end

SarychUI:RegisterExtension("interface_style", Style)
