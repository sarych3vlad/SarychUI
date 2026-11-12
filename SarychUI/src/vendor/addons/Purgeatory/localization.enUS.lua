if not SarychUI_PurgeatoryEmbeddedAvailable then return end

PurgeatoryLocals = {
	["Alert defensive dispels"] = "Alert defensive dispels",
	["Alert failed dispels"] = "Alert failed dispels",
	["Alert interrupts"] = "Alert interrupts",
	["Alert offensive dispels"] = "Alert offensive dispels",
	["Alerts when a defensive dispel is successful"] = "Alerts when a defensive dispel is successful",
	["Alerts when a spell is successfully interrupted. Sometimes a spell will be announced as interrupted but it will not actually be due to server timing."] = "Alerts when a spell is successfully interrupted. Sometimes a spell will be announced as interrupted but it will not actually be due to server timing.",
	["Alerts when an offensive dispel is successful. Spell stealing is considered an offensive dispel."] = "Alerts when an offensive dispel is successful. Spell stealing is considered an offensive dispel.",
	["Allows you to disable the mod entirely while inside this zone type."] = "Allows you to disable the mod entirely while inside this zone type.",
	["Announcement location for dispels."] = "Announcement location for dispels.",
	["Announcement location for interrupts."] = "Announcement location for interrupts.",
	["Chat frame #%d"] = "Chat frame #%d",
	["Color"] = "Color",
	["Color to use for dispel announcements, only used if the output is local."] = "Color to use for dispel announcements, only used if the output is local.",
	["Color to use for interrupt announcements, only used if the output is local."] = "Color to use for interrupt announcements, only used if the output is local.",
	["Combat text"] = "Combat text",
	["Dispels"] = "Dispels",
	["Enable mod"] = "Enable mod",
	["Failed message"] = "Failed message",
	["General"] = "General",
	["Global"] = "Global",
	["Help"] = "Help",
	["Interrupts"] = "Interrupts",
	["Location"] = "Location",
	["Message"] = "Message",
	["Message to show when a dispel fails to remove anything."] = "Message to show when a dispel fails to remove anything.",
	["Message to show when a dispel is successful."] = "Message to show when a dispel is successful.",
	["Message to show when a spell is interrupted"] = "Message to show when a spell is interrupted",
	["Middle of screen"] = "Middle of screen",
	["Party"] = "Party",
	["Raid"] = "Raid",
	["Raid warning"] = "Raid warning",
	["Show icons in announcements"] = "Show icons in announcements",
	["Successful message"] = "Successful message",
	["The spell icon will be shown at the start of the announcement, only used if the output is local."] = "The spell icon will be shown at the start of the announcement, only used if the output is local.",
	["This only alerts for failed dispels if the parent type is enabled, it won't show defensive dispel failures if defensive dispels are disabled."] = "This only alerts for failed dispels if the parent type is enabled, it won't show defensive dispel failures if defensive dispels are disabled.",
	["You can set what kind of dispels and interrupts to monitor in the zone category to the left. Spell steals are considered offensive dispels.\n\nFor announcement messages you have access to a few variables:\n*target - Name of the person the announcement is targeted on\n*spell - The spell that was removed or interrupted\n*used - The spell that was used to either remove or interrupt"] = "You can set what kind of dispels and interrupts to monitor in the zone category to the left. Spell steals are considered offensive dispels.\n\nFor announcement messages you have access to a few variables:\n*target - Name of the person the announcement is targeted on\n*spell - The spell that was removed or interrupted\n*used - The spell that was used to either remove or interrupt",
	["Zones"] = "Zones",

	["zones"] = {
		["arena"] = "Arenas",
		["none"] = "Everywhere else",
		["party"] = "Party instances",
		["pvp"] = "Battlegrounds",
		["raid"] = "Raid instances",
	},
}

if GetLocale() == "ruRU" then
    PurgeatoryLocals["Alert defensive dispels"] = "Рассеивания с союзников"
    PurgeatoryLocals["Alert failed dispels"] = "Неудачные рассеивания"
    PurgeatoryLocals["Alert interrupts"] = "Прерывания заклинаний"
    PurgeatoryLocals["Alert offensive dispels"] = "Рассеивания с противников"
    PurgeatoryLocals["Chat frame #%d"] = "Окно чата №%d"
    PurgeatoryLocals["Color"] = "Цвет"
    PurgeatoryLocals["Combat text"] = "Боевой текст"
    PurgeatoryLocals["Dispels"] = "Рассеивания"
    PurgeatoryLocals["Enable mod"] = "Включить в этой зоне"
    PurgeatoryLocals["Failed message"] = "Сообщение при неудаче"
    PurgeatoryLocals["General"] = "Основное"
    PurgeatoryLocals["Global"] = "Все зоны"
    PurgeatoryLocals["Help"] = "Помощь"
    PurgeatoryLocals["Interrupts"] = "Прерывания"
    PurgeatoryLocals["Location"] = "Куда выводить"
    PurgeatoryLocals["Message"] = "Сообщение"
    PurgeatoryLocals["Middle of screen"] = "По центру экрана"
    PurgeatoryLocals["Party"] = "Группа"
    PurgeatoryLocals["Raid"] = "Рейд"
    PurgeatoryLocals["Raid warning"] = "Объявление рейду"
    PurgeatoryLocals["Show icons in announcements"] = "Показывать иконки заклинаний"
    PurgeatoryLocals["Successful message"] = "Сообщение об успехе"
    PurgeatoryLocals["Zones"] = "Зоны"
    PurgeatoryLocals["Message to show when a dispel fails to remove anything."] = "Сообщение при неудачном рассеивании."
    PurgeatoryLocals["Message to show when a dispel is successful."] = "Сообщение об успешном рассеивании."
    PurgeatoryLocals["Message to show when a spell is interrupted"] = "Сообщение при прерывании заклинания."
    PurgeatoryLocals["Color to use for dispel announcements, only used if the output is local."] = "Цвет локальных уведомлений о рассеивании."
    PurgeatoryLocals["Color to use for interrupt announcements, only used if the output is local."] = "Цвет локальных уведомлений о прерывании."
    PurgeatoryLocals["Announcement location for dispels."] = "Куда выводить сообщения о рассеиваниях."
    PurgeatoryLocals["Announcement location for interrupts."] = "Куда выводить сообщения о прерываниях."
    PurgeatoryLocals["The spell icon will be shown at the start of the announcement, only used if the output is local."] = "Иконка в начале сообщения. Только для локальных уведомлений."
    PurgeatoryLocals["Allows you to disable the mod entirely while inside this zone type."] = "Включить уведомления в зонах этого типа."
    PurgeatoryLocals["Alerts when a defensive dispel is successful"] = "Уведомлять об успешном рассеивании с союзника."
    PurgeatoryLocals["Alerts when an offensive dispel is successful. Spell stealing is considered an offensive dispel."] = "Уведомлять о рассеивании или похищении эффекта у противника."
    PurgeatoryLocals["This only alerts for failed dispels if the parent type is enabled, it won't show defensive dispel failures if defensive dispels are disabled."] = "Неудачи показываются только для включённых типов рассеивания."
    PurgeatoryLocals["Alerts when a spell is successfully interrupted. Sometimes a spell will be announced as interrupted but it will not actually be due to server timing."] = "Уведомлять об успешном прерывании по данным журнала боя."
    PurgeatoryLocals["Removed *spell (*target)"] = "Рассеяно: *spell (*target)"
    PurgeatoryLocals["FAILED *spell (*target)"] = "Не удалось рассеять: *spell (*target)"
    PurgeatoryLocals["Interrupted *spell (*target)"] = "Прервано: *spell (*target)"
    PurgeatoryLocals.zones = { arena = "Арены", none = "Открытый мир", party = "Подземелья", pvp = "Поля боя", raid = "Рейдовые подземелья" }
end
