-- Style Blizzard artwork with the bundled Gloss black textures.
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
	background = media .. "button_background",
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

function Style.GetColor()
	local db = Style:GetDB()
	local color = db and db.styleColor or nil
	local function Channel(value)
		return math.max(0, math.min(1, tonumber(value) or 0.37))
	end
	local alpha = tonumber(color and color.a)
	if alpha == nil then alpha = 1 end
	return Channel(color and color.r), Channel(color and color.g),
		Channel(color and color.b), math.max(0, math.min(1, alpha))
end

function Style:GetTextureMode()
	return "black"
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
	self:RefreshOtherArtwork()
end

SarychUI:RegisterExtension("interface_style", Style)
