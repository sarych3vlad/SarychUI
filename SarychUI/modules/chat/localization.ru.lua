--[[
--	ChatBar Localization	 	
--	
--	German By: StarDust
--	Last Update : 09/05/2006
--
--]]

-- VIP Commands Localization
L["Enable_Chat_Circle_Menu"] = "[WoWCircle] |TInterface\\ChatFrame\\UI-ChatIcon-Chat-Up:14:14|t Дополнительные VIP команды при нажатии ПКМ"
L["Enable_Chat_Circle_Menu_Desc"] = "Включить VIP команды в контекстном меню чата"

if ( GetLocale() == "ruRU" ) then

CHATBAR_CHAR_LENGTH = 2;

CHATBAR_SAY_ABRV			= "С";
CHATBAR_YELL_ABRV			= "К";
CHATBAR_PARTY_ABRV			= "Г";
CHATBAR_RAID_ABRV			= "Р";
CHATBAR_RAID_WARNING_ABRV	= "В";
CHATBAR_BATTLEGROUND_ABRV	= "П";
CHATBAR_GUILD_ABRV			= "Г";
CHATBAR_OFFICER_ABRV		= "О";
CHATBAR_WHISPER_ABRV		= "Ш";
CHATBAR_EMOTE_ABRV			= "Э";

CHATBAR_MENU_WHISPER_REPLY		= "Ответить";
CHATBAR_MENU_WHISPER_RETELL		= "Пересказать";

CHATBAR_BLOCKED					= "Кнал \"%s\" , заблокирован."
CHATBAR_UNBLOCKED				= "Кнал \"%s\" , разблокирован."

-- Capital Cities
CHATBAR_SHATRATH		= "Шаттрат";
CHATBAR_EXODAR			= "Экзодар";
CHATBAR_SILVERMOON		= "Луносвет";
CHATBAR_DALARAN			= "Даларан";
CHATBAR_ORGRIMMAR		= "Оргриммар";
CHATBAR_STORMWIND		= "Штормград";
CHATBAR_IRONFORGE		= "Стальгорн";
CHATBAR_DARNASSUS		= "Дарнасс";
CHATBAR_UNDERCITY		= "Подгород";
CHATBAR_THUNDERBLUFF	= "Громовой утёс";

CHATBAR_GENERAL				= "Общий";
CHATBAR_TRADE				= "Торговля";
CHATBAR_LFG					= "Поиск спутников";
CHATBAR_LOCALDEFENSE		= "Оборона";
CHATBAR_WORLDDEFENSE		= "WorldDefense";
CHATBAR_GUILDRECRUITMENT	= "Набор в гильдии";



-- Bindings
BINDING_HEADER_CHATBAR_HEADER	= "Chat Bar";
BINDING_NAME_CHATBAR_SAY		= "Chat Say";
BINDING_NAME_CHATBAR_YELL		= "Chat Yell";
BINDING_NAME_CHATBAR_GUILD		= "Chat Guild";
BINDING_NAME_CHATBAR_OFFICER	= "Chat Officer";
BINDING_NAME_CHATBAR_PARTY		= "Chat Party";
BINDING_NAME_CHATBAR_RAID		= "Chat Raid";
BINDING_NAME_CHATBAR_EMOTE		= "Chat Emote";

BINDING_NAME_CHATBAR_CHANNEL_FORMAT = "Chat Channel %s";

CHATBAR_MENU_NONE = "Нету";

-- SarychUI Chat Module Localization
L = L or {}

L["Chat_Spam_Filter"] = "Фильтр сообщений"
L["Enable_Chat_Spam_Filter"] = "Включить фильтр"
L["Enable_Chat_Spam_Filter_Desc"] = "Включить фильтрацию сообщений в чате"
L["Add_Filter"] = "Добавить фильтр"
L["Add_Filter_Desc"] = "Введите текст для фильтрации"
L["Reset_Filters"] = "Сбросить фильтры"
L["Reset_Filters_Desc"] = "Восстановить фильтры по умолчанию"
L["Active_Filters"] = "Активные фильтры"
L["Enable"] = "Включить"
L["Delete"] = "Удалить"

end 