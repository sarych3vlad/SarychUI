-- Lorti UI 1.6.4 (Lorti, 2011) — thenнение текстур Blizzard.
-- Подключается из Tools → Затемнение текстур интерфейса.

SarychUI_LortiUI = SarychUI_LortiUI or {}
local L = SarychUI_LortiUI

L.enabled = false
L.hooksInstalled = false
L.originalColors = {}
L.paintedButtons = {}

-- Lorti UI.lua cfg (media copied from Lorti UI/media)
local MEDIA = [[Interface\AddOns\SarychUI\addons\LortiUI\media\]]
L.cfg = L.cfg or {
	textures = {
		normal = MEDIA .. "gloss",
		flash = MEDIA .. "flash",
		hover = MEDIA .. "hover",
		pushed = MEDIA .. "pushed",
		checked = MEDIA .. "checked",
		equipped = MEDIA .. "gloss_grey",
		buttonback = MEDIA .. "button_background",
		buttonbackflat = MEDIA .. "button_background_flat",
		outer_shadow = MEDIA .. "outer_shadow",
	},
	background = {
		showbg = true,
		showshadow = true,
		useflatbackground = false,
		backgroundcolor = { r = 0.3, g = 0.3, b = 0.3, a = 0.7 },
		shadowcolor = { r = 0, g = 0, b = 0, a = 0.9 },
		classcolored = false,
		inset = 5,
	},
	color = {
		normal = { r = 0, g = 0, b = 0, a = 0.9 },
		equipped = { r = 0.3, g = 0.55, b = 0.1 },
		classcolored = false,
	},
	hotkeys = {
		show = true,
		fontsize = 12,
		pos1 = { a1 = "TOPRIGHT", x = 0, y = 0 },
		pos2 = { a1 = "TOPLEFT", x = 0, y = 0 },
	},
	macroname = {
		show = false,
		fontsize = 12,
		pos1 = { a1 = "BOTTOMLEFT", x = 0, y = 0 },
		pos2 = { a1 = "BOTTOMRIGHT", x = 0, y = 0 },
	},
	itemcount = {
		show = true,
		fontsize = 12,
		pos1 = { a1 = "BOTTOMRIGHT", x = 0, y = 0 },
	},
	cooldown = {
		spacing = 0,
	},
	font = [[Fonts\FRIZQT__.TTF]],
}

function L.GetColor()
	local mods = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	local db = mods and mods.tools
	local c = db and db.darkModeColor
	if c then
		return c.r or 0.37, c.g or 0.37, c.b or 0.37, c.a or 1
	end
	local n = L.cfg.color.normal
	return n.r, n.g, n.b, n.a
end

function L.SyncColor()
	local r, g, b, a = L.GetColor()
	local n = L.cfg.color.normal
	n.r, n.g, n.b, n.a = r, g, b, a
end

function L.IsSettingOn()
	local mods = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	local db = mods and mods.tools
	return db and db.enabled and (db.enableDarkMode == 1 or db.enableDarkMode == true)
end

function L:DarkenTexture(texture)
	if not texture or not texture.SetVertexColor then return end
	if not self.originalColors[texture] then
		local r, g, b, a = texture:GetVertexColor()
		self.originalColors[texture] = { r = r, g = g, b = b, a = a }
	end
	local cr, cg, cb, ca = self.GetColor()
	local prev = self._painting
	self._painting = true
	texture:SetVertexColor(cr, cg, cb, ca)
	self._painting = prev
end

function L:RestoreTexture(texture)
	if not texture or not texture.SetVertexColor then return end
	local orig = self.originalColors[texture]
	if orig then
		texture:SetVertexColor(orig.r, orig.g, orig.b, orig.a)
	else
		texture:SetVertexColor(1, 1, 1, 1)
	end
end

function L:DarkenNamed(name)
	if type(name) == "string" then
		self:DarkenTexture(_G[name])
	elseif name then
		self:DarkenTexture(name)
	end
end

function L:RestoreNamed(name)
	if type(name) == "string" then
		self:RestoreTexture(_G[name])
	elseif name then
		self:RestoreTexture(name)
	end
end

function L:DarkenFirstRegion(frame)
	if not frame or not frame.GetRegions then return end
	local region = frame:GetRegions()
	if region then
		self:DarkenTexture(region)
	end
end

function L:RestoreFirstRegion(frame)
	if not frame or not frame.GetRegions then return end
	local region = frame:GetRegions()
	if region then
		self:RestoreTexture(region)
	end
end

function L:InstallHooks()
	if self.hooksInstalled then return end
	self.hooksInstalled = true
	if self.InstallFrameHooks then
		self:InstallFrameHooks()
	end
	if self.InstallButtonHooks then
		self:InstallButtonHooks()
	end
	if self.InstallAuraHooks then
		self:InstallAuraHooks()
	end
	if self.InstallCompactRaidHooks then
		self:InstallCompactRaidHooks()
	end
end

function L:Apply()
	if not self.IsSettingOn() then
		self:Disable()
		return
	end
	self.enabled = true
	self.SyncColor()
	self:InstallHooks()
	if self.ApplyFrames then
		self:ApplyFrames()
	end
	if self.ApplyButtons then
		self:ApplyButtons()
	end
	if self.ApplyAuras then
		self:ApplyAuras()
	end
	if self.ApplyCompactRaid then
		self:ApplyCompactRaid()
	end
	local frameMod = SarychUI and SarychUI.modules and SarychUI.modules.frame
	if frameMod and frameMod.ApplyClassIcons then
		frameMod:ApplyClassIcons()
	end
	local prMod = SarychUI and SarychUI.modules and SarychUI.modules.player_resources
	if prMod and prMod.ApplyTotemsDarkMode then
		prMod:ApplyTotemsDarkMode()
	end
end

function L:Enable()
	self:Apply()
end

function L:Disable()
	self.enabled = false
	if self.RestoreButtons then
		self:RestoreButtons()
	end
	if self.RestoreAuras then
		self:RestoreAuras()
	end
	if self.RestoreCompactRaid then
		self:RestoreCompactRaid()
	end
	if self.RestoreFrames then
		self:RestoreFrames()
	end
	wipe(self.originalColors)
	wipe(self.paintedButtons)
	if self.paintedAuras then
		wipe(self.paintedAuras)
	end
	local frameMod = SarychUI and SarychUI.modules and SarychUI.modules.frame
	if frameMod and frameMod.ApplyClassIcons then
		frameMod:ApplyClassIcons()
	end
	local prMod = SarychUI and SarychUI.modules and SarychUI.modules.player_resources
	if prMod and prMod.ApplyTotemsDarkMode then
		prMod:ApplyTotemsDarkMode()
	end
end
