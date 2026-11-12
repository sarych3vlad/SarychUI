-- Options owned by the component; shared rendering lives in src/options.
local moduleName = "tools"

local module = SarychUI.modules.announcements

local function DB()
	if not SarychUI or not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules then
		return nil
	end
	return SarychUI.db.profile.modules[moduleName]
end

local function isOn(key)
	local db = DB(); if not db then return false end
	local v = db[key]
	return v == 1 or v == true
end

local function toggleGetter(info)
	local db = DB(); if not db then return false end
	local key = info[#info]
	local v = db[key]
	return v == 1 or v == true
end

local function Refresh()
	if SarychUI.NotifySarychUIOptionsChange then
		SarychUI:NotifySarychUIOptionsChange()
	elseif SarychUI.RefreshConfig then
		SarychUI:RefreshConfig()
	end
end

local ALT_ANNOUNCE_CHANNEL_VALUES = {
	adaptive = "ui.options_b36ea3e548",
	say = "ui.options_8c8b441c9c",
	party = "ui.options_3c9abba8b9",
	raid = "ui.options_00aa846cfd",
	battleground = "ui.options_0f91bef92c",
	guild = "ui.options_510188017f",
	yell = "ui.options_28a19844a0",
	__order = { "adaptive", "say", "party", "raid", "battleground", "guild", "yell" },
}

local function AltAnnounceAnyEnabled()
	if not SarychUI:IsAnnouncementsEnabled() then return false end
	return isOn("enableAltCD") or isOn("enableAltUnitBars")
		or isOn("enableAltAuras")
end

local function MakeAltAnnounceChannelSelect(dbKey, name, desc, order, defaultMode)
	return {
		type = "select",
		name = name,
		desc = desc,
		order = order,
		width = "full",
		suiInlineLabel = true,
		values = ALT_ANNOUNCE_CHANNEL_VALUES,
		get = function()
			local db = DB()
			local mode = db and db[dbKey]
			if mode and ALT_ANNOUNCE_CHANNEL_VALUES[mode] then
				return mode
			end
			return defaultMode
		end,
		set = function(_, value)
			local db = DB(); if not db then return end
			db[dbKey] = (value and ALT_ANNOUNCE_CHANNEL_VALUES[value]) and value or defaultMode
			Refresh()
		end,
		disabled = function()
			return not AltAnnounceAnyEnabled()
		end,
	}
end

function SarychUI.modules.announcements:GetAnnouncementOptions()
 return {
altAnnounceBox = {
						type = "group",
						name = "ui.announce_with_cffffd700alt_r_left_click_a4f79170",
						desc = "ui.quick_status_report_to_chat_hold_cffffd700alt_r__337ba482",
						order = 2,
						inline = true,
						suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
						args = {
							enableAltCD = {
								type = "toggle",
								name = "ui.announce_ability_status_bb5cdbb2",
								desc = "ui.with_cffffd700alt_r_left_click_on_an_ability_but_5a5029ba",
								order = 1,
								width = "full",
								suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableAltCD = val and 1 or 0
									if module and SarychUI.modules.announcements.ApplyAltCD then SarychUI.modules.announcements:ApplyAltCD() end
									Refresh()
								end,
							},
							enableAltUnitBars = {
								type = "toggle",
								name = "ui.announce_health_and_mana_a102e915",
								desc = "ui.with_cffffd700alt_r_left_click_on_player_target__8339c727",
								order = 2,
								width = "full",
								suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableAltUnitBars = val and 1 or 0
									if module and SarychUI.modules.announcements.ApplyAltUnitBars then SarychUI.modules.announcements:ApplyAltUnitBars() end
									Refresh()
								end,
							},
							enableAltAuras = {
								type = "toggle",
								name = "ui.announce_buffs_and_debuffs_89fe5ee8",
								desc = "ui.with_cffffd700alt_r_left_click_on_a_player_targe_b6d4a837",
								order = 3,
								width = "full",
								suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableAltAuras = val and 1 or 0
									if module and SarychUI.modules.announcements.ApplyAltAuras then SarychUI.modules.announcements:ApplyAltAuras() end
									Refresh()
								end,
							},
							altAnnounceChannelHeader = {
								type = "description",
								name = "ui.text_97cd3359",
								order = 5,
								fontSize = "medium",
							},
							altAnnounceChannelBG = MakeAltAnnounceChannelSelect(
								"altAnnounceChannelBG",
								SarychUI:T("ui.options_32433d14d5"),
								SarychUI:T("ui.options_0e569f0100"),
								6,
								"say"
							),
							altAnnounceChannelArena = MakeAltAnnounceChannelSelect(
								"altAnnounceChannelArena",
								SarychUI:T("ui.arena_cada76b8"),
								SarychUI:T("ui.options_d5dfa1dd70"),
								7,
								"adaptive"
							),
							altAnnounceChannelRaid = MakeAltAnnounceChannelSelect(
								"altAnnounceChannelRaid",
								SarychUI:T("ui.options_2a85ca1699"),
								SarychUI:T("ui.options_fb33e71885"),
								8,
								"adaptive"
							),
							altAnnounceChannelParty = MakeAltAnnounceChannelSelect(
								"altAnnounceChannelParty",
								SarychUI:T("ui.party_907efbd4"),
								SarychUI:T("ui.options_786596c841"),
								9,
								"adaptive"
							),
							altAnnounceChannelSolo = MakeAltAnnounceChannelSelect(
								"altAnnounceChannelSolo",
								SarychUI:T("ui.options_55faef024c"),
								SarychUI:T("ui.options_dd71c42ff5"),
								10,
								"adaptive"
							),
						},
					},
interruptAnnouncementBox = {
						type = "group",
						name = "ui.text_6bb9579d",
						order = 2,
						inline = true,
						args = {
							enableInterruptAnnouncement = {
								type = "toggle",
								name = "ui.enable_a54eaf37",
								desc = "ui.text_6b3ef2cc",
								order = 1,
								width = "full",
								get = toggleGetter,
								set = function(_, val)
									local db = DB(); if not db then return end
									db.enableInterruptAnnouncement = val and 1 or 0
									if module and SarychUI.modules.announcements.ApplyInterruptAnnouncement then
										SarychUI.modules.announcements:ApplyInterruptAnnouncement()
									end
									Refresh()
								end,
							},
							interruptAnnounceChannel = {
								type = "select",
								name = "ui.text_a9cd3794",
								desc = "ui.text_8fa321b6",
								order = 2,
								width = "full",
								suiInlineLabel = true,
								values = ALT_ANNOUNCE_CHANNEL_VALUES,
								get = function()
									local db = DB()
									local mode = db and db.interruptAnnounceChannel
									return (mode and ALT_ANNOUNCE_CHANNEL_VALUES[mode]) and mode or "adaptive"
								end,
								set = function(_, mode)
									local db = DB(); if not db then return end
									db.interruptAnnounceChannel = (mode and ALT_ANNOUNCE_CHANNEL_VALUES[mode]) and mode or "adaptive"
									Refresh()
								end,
								disabled = function() return not isOn("enableInterruptAnnouncement") end,
							},
						},
					},
 }
end
