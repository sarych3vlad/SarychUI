local SUI = SarychUI
local style = SUI.extensions.interface_style

local function RefreshDisabledBody()
	if SUI.OptionsCore and SUI.OptionsCore.ScheduleSmartRefresh then
		SUI.OptionsCore:ScheduleSmartRefresh(true)
	end
end

local function ReloadAfterChange(revert)
	SUI:NotifySarychUIOptionsChange()
	RefreshDisabledBody()
	if SUI.ShowReloadPopup then
		SUI:ShowReloadPopup(SarychUI:T("ui.options_842b8d48e3"), function()
			revert()
			SUI:NotifySarychUIOptionsChange()
			RefreshDisabledBody()
		end)
	end
end

local function RefreshStylePreviews()
	if SUI.ActionBarAppearancePreview then SUI.ActionBarAppearancePreview:RefreshAll() end
	if SUI.ActionBarColorPreview then SUI.ActionBarColorPreview:RefreshAll() end
	if SUI.ActionBarTransparencyPreview then SUI.ActionBarTransparencyPreview:RefreshAll() end
	if SUI.AurasPreview then SUI.AurasPreview:RefreshAll() end
end

function style:GetOptions()
	local menu = SUI.modules and SUI.modules.mainmenubar
	return {
		type = "group",
		name = "ui.text_afb43adf",
		suiBodyDisabled = function()
			local db = style:GetDB()
			return not (db and db.enabled)
		end,
		args = {
			borderBox = menu and menu.GetButtonBorderOptions and menu:GetButtonBorderOptions(4, function()
				local db = style:GetDB()
				return not (db and db.enabled)
			end),
			background = {
				type = "group", name = "ui.interface_style.background", order = 5, inline = true,
				args = {
					color = {
						type = "color", name = "ui.interface_style.background_color", order = 1,
						hasAlpha = false,
						get = function() return style:GetBackgroundColor() end,
						set = function(_, r, g, b)
							local db = style:GetDB()
							if not db then return end
							local _, _, _, a = style:GetBackgroundColor()
							db.backgroundColor = { r = r, g = g, b = b, a = a }
							style:RefreshBackgrounds()
							SUI:NotifySarychUIOptionsChange()
						end,
					},
					alpha = {
						type = "range", name = "ui.transparency_94a43d8b", order = 2,
						min = 0, max = 1, step = 0.05, width = "full",
						get = function() local _, _, _, a = style:GetBackgroundColor(); return a end,
						set = function(_, a)
							local db = style:GetDB()
							if not db then return end
							local r, g, b = style:GetBackgroundColor()
							db.backgroundColor = { r = r, g = g, b = b, a = a }
							style:RefreshBackgrounds()
							SUI:NotifySarychUIOptionsChange()
						end,
					},
				},
			},
			enabled = {
				type = "toggle", name = "ui.enable_a54eaf37", order = 1,
				get = function()
					local db = style:GetDB()
					return db and db.enabled == true or false
				end,
				set = function(_, value)
					local db = style:GetDB()
					if not db or db.enabled == (value == true) then return end
					local previous = db.enabled
					db.enabled = value == true
					ReloadAfterChange(function() db.enabled = previous end)
				end,
			},
			textures = {
				type = "select", name = "ui.text_0d7f9c9f", order = 2,
				width = "full",
				values = { black = "ui.options_d8a98a2cd2" },
				get = function() return style:GetTextureMode() end,
				set = function() end,
			},
			appearance = {
				type = "group", name = "", order = 3, inline = true,
				args = {
					styleColor = {
						type = "color", name = "ui.texture_color_26df450e", order = 1,
						hasAlpha = true,
						disabled = function()
							local db = style:GetDB()
							return not (db and db.enabled)
						end,
						get = function() return style.GetColor() end,
						set = function(_, r, g, b, a)
							local db = style:GetDB()
							if not db then return end
							db.styleColor = { r = r, g = g, b = b, a = a or 1 }
							style:RefreshColor()
							RefreshStylePreviews()
							SUI:NotifySarychUIOptionsChange()
						end,
					},
					glossBrightness = {
						type = "range", name = "ui.gloss_40047f21", order = 2,
						width = "full", min = 0, max = 1, step = 0.05,
						disabled = function()
							local db = style:GetDB()
							return not (db and db.enabled)
						end,
						get = function() return style:GetGlossBrightness() end,
						set = function(_, value)
							local db = style:GetDB()
							if not db then return end
							db.glossBrightness = math.max(0, math.min(1, tonumber(value) or 1))
							style:RefreshGloss()
							RefreshStylePreviews()
							SUI:NotifySarychUIOptionsChange()
						end,
					},
				},
			},
			icons = {
				type = "group", name = "ui.icons_f52d3f2f", order = 3.5, inline = true,
				args = {
					cropIcons = {
						type = "toggle", name = "ui.interface_style.crop_icons", order = 1,
						desc = "ui.interface_style.crop_icons_desc", width = "full",
						get = function() return style:GetCropIcons() end,
						set = function(_, value)
							local db = style:GetDB()
							if not db then return end
							db.cropIcons = value == true
							style:RefreshGloss()
							RefreshStylePreviews()
							SUI:NotifySarychUIOptionsChange()
						end,
					},
					debuffOriginalColor = {
						type = "toggle", name = "ui.text_5ce3cbc6", order = 2,
						disabled = function()
							local db = style:GetDB()
							return not (db and db.enabled)
						end,
						get = function() return style:GetDebuffOriginalColor() end,
						set = function(_, value)
							local db = style:GetDB()
							if not db then return end
							db.debuffOriginalColor = value == true
							if style.RefreshAuras then style:RefreshAuras() end
							RefreshStylePreviews()
							SUI:NotifySarychUIOptionsChange()
						end,
					},
				},
			},
		},
	}
end
