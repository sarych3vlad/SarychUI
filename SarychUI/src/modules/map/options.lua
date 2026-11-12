-- SarychUI world map options
local moduleName = "map"
local L = SarychUI.L
local module = SarychUI:GetModule(moduleName)
if not module then return end

local function DB() return SarychUI:GetModuleProfile(moduleName) end
local function IsModuleEnabled()
    local db = DB()
    return db and db.enabled ~= false
end
local function RefreshMapOptions()
    if SarychUI.NotifySarychUIOptionsChange then SarychUI:NotifySarychUIOptionsChange() end
end
local function ShowReloadPopup(onCancel, text)
    if SarychUI.ShowReloadPopup then SarychUI:ShowReloadPopup(text, onCancel) end
end
local function RefreshNativeMap()
    if SarychUI.Maps and SarychUI.Maps.Refresh then SarychUI.Maps:Refresh()
    elseif module.Refresh then module:Refresh() end
end

function module:GetOptions()
    return {
        type = "group",
        name = "ui.options_eb6028a6dc",
        desc = "ui.options_775b5d4be3",
        suiPageBackground = "Interface\\LFGFrame\\UI-LFG-BACKGROUND-VaultOfArchavon.blp",
        args = {
            enabled = {
                suiModuleEnable = true,
                type = "toggle",
                name = "ui.enable_module_b623b573",
                desc = "ui.options_6db96fb7bf",
                order = 1,
                get = function() return IsModuleEnabled() end,
                set = function(_, value)
                    local db = DB()
                    if not db then return end
                    value = value and true or false
                    if (db.enabled ~= false) == value then return end
                    db.enabled = value
                    if value then
                        SarychUI:SetMapType("sarychui")
                        SarychUI:EnableModule(moduleName)
                    else
                        SarychUI:SetMapType("classic")
                        SarychUI:DisableModule(moduleName)
                    end
                    RefreshMapOptions()
                    ShowReloadPopup(function()
                        db.enabled = not value
                        SarychUI:SetMapType(db.enabled and "sarychui" or "classic")
                        if db.enabled then SarychUI:EnableModule(moduleName)
                        else SarychUI:DisableModule(moduleName) end
                        RefreshMapOptions()
                    end, SarychUI:T(value and "ui.options_77b98a3cb5" or "ui.options_fce8cf3dcf"))
                end,
            },
			navigation = {
				type = "group", name = "ui.map_navigation", order = 10, inline = true,
				args = {
					panButton = {
						type = "select",
						name = L and (L["Map Pan Button"] or SarychUI:T("ui.options_4daa5590fd")) or SarychUI:T("ui.options_4daa5590fd"),
						desc = L and (L["Map Pan Button Desc"] or SarychUI:T("ui.options_faac33f4f8")) or SarychUI:T("ui.options_faac33f4f8"),
						order = 1,
						width = "double",
						values = {
							left = L and (L["Left Mouse Button"] or SarychUI:T("ui.options_ec888e59e5")) or SarychUI:T("ui.options_ec888e59e5"),
							middle = L and (L["Middle Mouse Button"] or SarychUI:T("ui.options_446d8547a9")) or SarychUI:T("ui.options_446d8547a9"),
							right = L and (L["Right Mouse Button"] or SarychUI:T("ui.options_d822ebb002")) or SarychUI:T("ui.options_d822ebb002"),
						},
						get = function()
							local db = DB()
							return (db and db.panButton) or "middle"
						end,
						set = function(_, value)
							local db = DB()
							if not db then return end
							db.panButton = value
							RefreshNativeMap()
						end,
					},
					panSpeed = {
						type = "range",
						name = L and (L["Map Pan Speed"] or SarychUI:T("ui.options_e377fcaf6a")) or SarychUI:T("ui.options_e377fcaf6a"),
						desc = L and (L["Map Pan Speed Desc"] or SarychUI:T("ui.options_eec29846ea")) or SarychUI:T("ui.options_eec29846ea"),
						order = 2,
						width = "full",
						min = 0.15,
						max = 1.5,
						step = 0.05,
						get = function()
							local db = DB()
							return (db and db.panSpeed) or 0.9
						end,
						set = function(_, value)
							local db = DB()
							if not db then return end
							db.panSpeed = value
						end,
					},
					zoneInfo = {
						type = "toggle",
						name = L and (L["Map Zone Info"] or SarychUI:T("ui.options_3de165fe79")) or SarychUI:T("ui.options_3de165fe79"),
						desc = L and (L["Map Zone Info Desc"] or SarychUI:T("ui.options_47bebc6a4b")) or SarychUI:T("ui.options_47bebc6a4b"),
						order = 3,
						width = "full",
						get = function()
							local db = DB()
							return not db or db.zoneInfo ~= false
						end,
						set = function(_, value)
							local db = DB()
							if not db then return end
							db.zoneInfo = value and true or false
							RefreshNativeMap()
						end,
					},
				},
			},
			appearance = {
				type = "group", name = "ui.appearance_c407960b", order = 20, inline = true,
				args = {
					fadeOnMove = {
						type = "toggle",
						name = L and (L["Map Fade On Move"] or SarychUI:T("ui.options_d31b47b013")) or SarychUI:T("ui.options_d31b47b013"),
						desc = L and (L["Map Fade On Move Desc"] or SarychUI:T("ui.options_b2ee02ec00")) or SarychUI:T("ui.options_b2ee02ec00"),
						order = 5,
						width = "full",
						get = function()
							local db = DB()
							return not db or db.fadeOnMove ~= false
						end,
						set = function(_, value)
							local db = DB()
							if not db then return end
							db.fadeOnMove = value and true or false
							RefreshNativeMap()
						end,
					},
					resetLayout = {
						type = "toggle",
						name = L and (L["Map Reset Layout"] or SarychUI:T("ui.options_d9038beb12")) or SarychUI:T("ui.options_d9038beb12"),
						desc = L and (L["Map Reset Layout Desc"] or SarychUI:T("ui.options_637bff6447")) or SarychUI:T("ui.options_637bff6447"),
						order = 4,
						width = "full",
						get = function()
							local db = DB()
							return db and db.resetLayout == true
						end,
						set = function(_, value)
							local db = DB()
							if not db then return end
							db.resetLayout = value and true or false
							if SarychUI.Maps and SarychUI.Maps.worldmap then
								SarychUI.Maps.worldmap:SetScale()
								SarychUI.Maps.worldmap:SetPosition()
							end
							RefreshNativeMap()
						end,
					},
				},
			},
			fog = {
				type = "group", name = "ui.map_fog", order = 30, inline = true,
				args = {
					fogStyle = {
						type = "select",
						name = L and (L["Map Fog Style"] or SarychUI:T("ui.options_59329d5603")) or SarychUI:T("ui.options_59329d5603"),
						desc = L and (L["Map Fog Style Desc"] or SarychUI:T("ui.options_d062e6fcc6")) or SarychUI:T("ui.options_d062e6fcc6"),
						order = 6,
						width = "double",
						values = {
							standard = L and (L["Map Fog Style Standard"] or SarychUI:T("ui.options_c341df4f15")) or SarychUI:T("ui.options_c341df4f15"),
							leatrix = L and (L["Map Fog Style Leatrix"] or SarychUI:T("ui.options_834371619b")) or SarychUI:T("ui.options_834371619b"),
						},
						get = function()
							local db = DB()
							return (db and db.fogStyle) or "leatrix"
						end,
						set = function(_, value)
							local db = DB()
							if not db then return end
							if value ~= "standard" then
								value = "leatrix"
							end
							db.fogStyle = value
							if value == "standard" then
								db.fogTintR, db.fogTintG, db.fogTintB = 0.623, 0.623, 0.623
							else
								db.fogTintR, db.fogTintG, db.fogTintB = 0.6, 0.6, 1
							end
							RefreshNativeMap()
						end,
					},
					fogTransparency = {
						type = "range",
						name = L and (L["Map Fog Transparency"] or SarychUI:T("ui.options_3fe63ebe80")) or SarychUI:T("ui.options_3fe63ebe80"),
						desc = L and (L["Map Fog Transparency Desc"] or SarychUI:T("ui.options_4a98252efe")) or SarychUI:T("ui.options_4a98252efe"),
						order = 7,
						width = "full",
						min = 0,
						max = 1,
						step = 0.05,
						isPercent = true,
						get = function()
							local db = DB()
							local alpha = (db and db.fogTintA) or 1
							return 1 - alpha
						end,
						set = function(_, value)
							local db = DB()
							if not db then return end
							db.fogTintA = 1 - (value or 0)
							RefreshNativeMap()
						end,
					},
				},
			},
        },
    }
end
