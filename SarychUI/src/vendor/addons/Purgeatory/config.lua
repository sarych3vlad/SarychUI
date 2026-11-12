if not SarychUI_PurgeatoryEmbeddedAvailable then return end

local Config = {}
local L = PurgeatoryLocals
local options

local announceDest = {["ct"] = L["Combat text"], ["party"] = L["Party"], ["raid"] = L["Raid"], ["rw"] = L["Raid warning"], ["rwframe"] = L["Middle of screen"], ["1"] = string.format(L["Chat frame #%d"], 1), ["2"] = string.format(L["Chat frame #%d"], 2), ["3"] = string.format(L["Chat frame #%d"], 3), ["4"] = string.format(L["Chat frame #%d"], 4), ["5"] = string.format(L["Chat frame #%d"], 5), ["6"] = string.format(L["Chat frame #%d"], 6), ["7"] = string.format(L["Chat frame #%d"], 7)}
local localDest = {["ct"] = true, ["rwframe"] = true, ["1"] = true, ["2"] = true, ["3"] = true, ["4"] = true, ["5"] = true, ["6"] = true, ["7"] = true}

-- General option
local function loadOptions()
	options = {
		type = "group",
		name = "Purgeatory",
		args = {},
	}
	
	
	options.args.general = {
		order = 0,
		type = "group",
		name = L["General"],
		set = function(info, ...)
			local config = Purgeatory.db.profile[info[#(info)]]
			if( type(config) == "table" ) then
				local r, g, b = select(1, ...)
				config.r = r
				config.g = g
				config.b = b
				return
			end
			
			Purgeatory.db.profile[info[#(info)]] = select(1, ...)
		end,
		get = function(info)
			local config = Purgeatory.db.profile[info[#(info)]]
			if( type(config) == "table" ) then
				return config.r, config.g, config.b
			end
		
			return config
		end,
		args = {
			general = {
				order = 2,
				type = "group",
				inline = true,
				name = L["General"],
				args = {
					showIcon = {
						order = 1,
						type = "toggle",
						name = L["Show icons in announcements"],
						desc = L["The spell icon will be shown at the start of the announcement, only used if the output is local."],
						width = "double",
					},
				},
			},
			dispel = {
				order = 3,
				type = "group",
				inline = true,
				name = L["Dispels"],
				args = {
					dispelSuccessMsg = {
						order = 3,
						type = "input",
						name = L["Successful message"],
						desc = L["Message to show when a dispel is successful."],
						width = "full",
					},
					dispelFailMsg = {
						order = 4,
						type = "input",
						name = L["Failed message"],
						desc = L["Message to show when a dispel fails to remove anything."],
						width = "full",
					},
					dispelColor = {
						order = 5,
						type = "color",
						name = L["Color"],
						desc = L["Color to use for dispel announcements, only used if the output is local."],
					},
					dispelLocation = {
						order = 6,
						type = "select",
						name = L["Location"],
						desc = L["Announcement location for dispels."],
						values = announceDest,
					},
				},
			},
			interrupt = {
				order = 4,
				type = "group",
				inline = true,
				name = L["Interrupts"],
				args = {
					interruptMsg = {
						order = 8,
						type = "input",
						name = L["Message"],
						desc = L["Message to show when a spell is interrupted"],
						width = "full",
					},
					interruptColor = {
						order = 9,
						type = "color",
						name = L["Color"],
						desc = L["Color to use for interrupt announcements, only used if the output is local."],
					},
					interruptLocation = {
						order = 10,
						type = "select",
						name = L["Location"],
						desc = L["Announcement location for interrupts."],
						values = announceDest,
					},
				},
			},
		},
	}

	
	local globalSettings = {}
	local zoneList = {"none", "party", "pvp", "raid", "arena"}
	local function loadZoneSettings(zoneType)
		local zoneGroup = {
			order = ({global=0, none=1, party=2, raid=3, pvp=4, arena=5})[zoneType],
			type = "group",
			name = L.zones[zoneType] or L["Global"],
			set = function(info, value)
				local zone = zoneType
				local key = info[#(info)]
				if( zone == "global" ) then
					globalSettings[key] = value
					
					for _, zoneType in pairs(zoneList) do
						Purgeatory.db.profile.zones[zoneType][key] = value
					end
				else
					Purgeatory.db.profile.zones[zone][key] = value
				end
				
				-- Might need to be enabled
				Purgeatory:Reload()
                if key == "enabled" and SarychUI and SarychUI.RefreshConfig then SarychUI:RefreshConfig() end
			end,
			get = function(info)
				local zone = zoneType
				local key = info[#(info)]
				if( zone == "global" ) then
					for _, zoneType in ipairs(zoneList) do
                        if not Purgeatory.db.profile.zones[zoneType][key] then return false end
                    end
                    return true
				end
				
				return Purgeatory.db.profile.zones[zone][key]
			end,
			args = {
				enabled = {
					order = 1,
					type = "toggle",
					name = L["Enable mod"],
					desc = L["Allows you to disable the mod entirely while inside this zone type."],
				},
				dispel = {
					order = 2,
					type = "header",
					name = L["Dispels"],
				},
				dispelFail = {
					order = 3,
					type = "toggle",
					name = L["Alert failed dispels"],
					desc = L["This only alerts for failed dispels if the parent type is enabled, it won't show defensive dispel failures if defensive dispels are disabled."],
				},
				sep = {
					order = 3.5,
					type = "description",
					name = "",
				},
				dispelOffensive = {
					order = 4,
					type = "toggle",
					name = L["Alert offensive dispels"],
					desc = L["Alerts when an offensive dispel is successful. Spell stealing is considered an offensive dispel."],
				},
				dispelDefensive = {
					order = 5,
					type = "toggle",
					name = L["Alert defensive dispels"],
					desc = L["Alerts when a defensive dispel is successful"],
				},
				interruptHeader = {
					order = 6,
					type = "header",
					name = L["Interrupts"],
				},
				interrupt = {
					order = 7,
					type = "toggle",
					name = L["Alert interrupts"],
					desc = L["Alerts when a spell is successfully interrupted. Sometimes a spell will be announced as interrupted but it will not actually be due to server timing."],
				},
			},
		}
        local controls = zoneGroup.args
        local function ZoneDisabled()
            if zoneType == "global" then
                for _, name in ipairs(zoneList) do
                    if not Purgeatory.db.profile.zones[name].enabled then return true end
                end
                return false
            end
            return not Purgeatory.db.profile.zones[zoneType].enabled
        end
        for key, control in pairs(controls) do
            if key ~= "enabled" then control.hidden = ZoneDisabled end
        end
        zoneGroup.args = {
            settings = { type = "group", name = "", inline = true,
                order = 1, args = controls },
        }
        return zoneGroup
	end
	
	options.args.zones = {
		order = 2,
		type = "group",
		name = L["Zones"],
        childGroups = "tab",
        suiAlign = "flush",
		args = {
			global = loadZoneSettings("global"),
			none = loadZoneSettings("none"),
			arena = loadZoneSettings("arena"),
			pvp = loadZoneSettings("pvp"),
			party = loadZoneSettings("party"),
			raid = loadZoneSettings("raid"),
		},
	}
	
    for _, block in ipairs({options.args.general.args.dispel, options.args.general.args.interrupt}) do
        for _, option in pairs(block.args) do
            if option.type == "input" then
                option.desc = (option.desc or "") .. "\n*target — " .. (GetLocale() == "ruRU" and "цель; *spell — заклинание; *used — использованная способность." or "target; *spell — spell; *used — ability used.")
            end
        end
    end
end

function Purgeatory:GetSUIOptions()
    self:OnInitialize()
    loadOptions()
    options.childGroups = "tab"
    options.suiTabBarExtra = {
        type = "execute", name = function()
            return self.testFrame and self.testFrame:IsShown() and "Тест |cff00ff00(вкл)|r" or "Тест"
        end,
        func = function() self:ToggleTest() end,
        disabled = function() return not self.enabled end,
    }
    return options
end

function Purgeatory:OpenConfig()
    if not self.enabled or not self.db then return false end
    if not (SarychUI.IsSarychUIOptionsOpen and SarychUI:IsSarychUIOptionsOpen()) then
        SarychUI:OpenOptions()
    end
    local core = SarychUI.OptionsCore
    if not core then return false end
    core._addonListSelected = "Purgeatory"
    core:SelectSection("sui:addons")
    return true
end

SLASH_PURGEATORY1 = "/purgeatory"
SlashCmdList["PURGEATORY"] = function()
	Purgeatory:OpenConfig()
end
