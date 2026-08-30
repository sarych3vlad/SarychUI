-- Управление включением ChatBar через модуль SarychUI
local gmatch, lower, len, sub = string.gmatch, string.lower, string.len, string.sub
local abs = math.abs

local function ChatBar_IsEnabled()
	-- Проверяем модуль SarychUI в первую очередь
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat then
		local chatModule = SarychUI.db.profile.modules.chat
		-- Отладочная информация удалена
		
		-- Модуль должен быть включен (проверяем и boolean true и number 1)
		if chatModule.enabled == true or chatModule.enabled == 1 then
			-- Если chatBarEnabled не установлен, считаем что включен по умолчанию
			if chatModule.chatBarEnabled == nil then
				return true
			end
			-- Иначе проверяем настройку (проверяем и boolean true и number 1)
			return (chatModule.chatBarEnabled == true or chatModule.chatBarEnabled == 1)
		end
		return false
	end
	
	-- Fallback на старые настройки только если SarychUI недоступен
	if _G.sarChatCharDB and _G.sarChatCharDB.chatBarEnabled ~= nil then
		return _G.sarChatCharDB.chatBarEnabled == 1
	end
	if _G.sarChatDB and _G.sarChatDB.chatBarEnabled ~= nil then
		return _G.sarChatDB.chatBarEnabled == 1
	end
	return false -- по умолчанию выключен, если модуль недоступен
end

-- Флаг жизненного цикла ChatBar: активируется после VARIABLES_LOADED, если разрешён настройкой
local ChatBar_Active = false
local ChatBar_AltModeEnabled = true
--[[
ChatBar

Author: AnduinLothar - karlkfi@yahoo.com
Graphics: Vynn, Zseton

-Button Bar for openning chat messages of each type.

Change Log:
v3.1 (yarko)
-Added larger buttons option to options menu
-Added channel blocking capability to channel buttons right-click menu
-"/w" is now removed if the user first clicks the whisper button then another button without entering a whisper
-toc to 30300
v3.0
-Added a fix for parsing the first character of a chinese channel (3 chars)
-Fixed battleground chat button not showing up (thanks 狂飙)
-Fixed Show Channel ID on Buttons not working
v2.9
-Fixed a channel bug
v2.8
-Added Chat Type Bindings
-Added Channel Bindings by Number
-Channel Bindings can be overridden to save by name
-Updated a lot of old code
-toc to 30200
v2.7
-Added Simplified Chinese Localization (thanks IceChen)
-Added new Squares skin (thanks Chianti/Кьянти)
-Added new skin dropdown (Solid, Glass, Squares)
v2.6
-Added Traditional Chinese Localization
-Fixed a bug with Russian Localization
v2.5
-toc to 30000
-Fixed Sea dep
v2.4
-Removed SeaPrint usage
-Made Chronos optional: Reorder Channels is disabled w/o Chronos installed.
-Added english TBC/WotLK capitol cities to the reorder management
(Best results if in a capitol city and in the LFG queue)
v2.3
-Added Russian Localization (thanks Старостин Алексей)
v2.2
-Added Alternate Artwork (thanks Zseton)
v2.1
-Added Spanish Localization (thanks NeKRoMaNT)
v2.0
-Added an option to Hide All Buttons
-Fixed menu not showing a list of hidden buttons
v1.9
-Fixed chat type openning for new editbox:SetAttribute syntax
v1.8
-Prepared for Lua 5.1
-Added embedded SeaPrint for printing (was already used, just not included)
v1.7
-Added Raid Warning (A) and Battleground (B) chat
v1.6
-Channel Reorder no longer requires Sky
-toc to 11200
v1.5
-Fixed saved variables issue with 1.11 not saving nils
-Fixed a nill bug with the right-click menu
v1.4
-Fixed a nil loading error
v1.3
-Fixed nil SetText errors
-Fixed channel 10 nil errors
-Added Channel Reorder (from ChannelManager) if you have Sky installed (uses many library functions)
v1.2
-VisibilityOptions AutoHide is now smarter and shows whenever ChatBar is sliding or being dragged or the cursor is over its menu
-Fixed Eclipse onload error
-Fixed Whisper abreviation
v1.1
-Addon Channels Hidden added GuildMap
-Text has been made Localizable
-Officer chat shows up if you CanEditOfficerNote()
-Buttons now correctly update when raid, party, and guild changes
-Hide Text now correctly says Show Text
-Fixed button for channel 8 to diplay and tooltip correctly
-Added Reset Position Option
-Added Options to hide the each button by chat type or channel name (hide from button menu, show from main sub menu)
-Added option to use Channel Numbers as text overlay
-Added VisibilityOptions, however autohide is a bit finicky atm.
v1.0
-Initial Release

]]--

--------------------------------------------------
-- Globals
--------------------------------------------------

-- Основные константы
CHAT_BAR_MAX_BUTTONS = 20; -- Максимальное количество кнопок
CHAT_BAR_UPDATE_DELAY = 30; -- Задержка обновления

-- Фиксированные настройки, ранее настраиваемые пользователем
local VERTICAL_DISPLAY = false; -- Горизонтальное расположение кнопок
local ALTERNATE_ORIENTATION = false; -- Обычная ориентация кнопок
local BUTTON_SCALE = 1; -- Обычный размер кнопок
local TEXT_CHANNEL_NUMBERS = false; -- Показывать названия каналов, а не номера

-- Необходимые глобальные переменные
ChatBar_VerticalDisplay = VERTICAL_DISPLAY; 
ChatBar_AlternateOrientation = ALTERNATE_ORIENTATION;
ChatBar_TextOnButtonDisplay = true; -- Всегда true для текстовых кнопок
ChatBar_ButtonText = true; -- Всегда true для текстовых кнопок
ChatBar_TextChannelNumbers = TEXT_CHANNEL_NUMBERS;
ChatBar_StoredStickies = { }; -- Для сохранения состояния sticky-чатов
ChatBar_HiddenButtons = { }; -- Для скрытия кнопок
ChatBar_ChannelBindings = {}; -- Для привязки клавиш
ChatBar_ButtonScale = BUTTON_SCALE; -- Размер кнопок

-- Служебные переменные
ChatBar_VerticalDisplay_Sliding = false;
ChatBar_AlternateDisplay_Sliding = false;
ChatBar_LargeButtons_Sliding = false;
ChatBar_LastTell = nil;
ChatBar_IsShown = false; -- Для отслеживания состояния видимости
-- Локальные переменные для анимации затухания
local FADE_OUT_START_DELAY = 7; -- Время в секундах перед исчезновением панели (после запуска)
local FADE_OUT_DURATION = 0.5; -- Длительность анимации затухания в секундах

-- Служебные переменные для анимации
ChatBar_FadeStart = 0; -- Время начала анимации
ChatBar_DoFadeOut = false; -- Флаг, указывающий что нужно выполнить затухание

--------------------------------------------------
-- Retell Hook
--------------------------------------------------

local ChatBar_RetellHookInstalled = false
local function ChatBar_InstallRetellHook()
	if ChatBar_RetellHookInstalled then return end
	hooksecurefunc("SendChatMessage", function(text, chatType, language, target)
		if chatType == "WHISPER" then
			ChatBar_LastTell = target;
		end
	end)
	ChatBar_RetellHookInstalled = true
end

--------------------------------------------------
-- Button Functions
--------------------------------------------------

function ChatBar_UseChatType(chatType, target)
	-- Убедимся, что мы используем именно активное окно чата
	local chatFrame = SELECTED_DOCK_FRAME;
	if not chatFrame then
		-- Если нет активного окна чата, используем DEFAULT_CHAT_FRAME
		chatFrame = DEFAULT_CHAT_FRAME;
	end
	
	local chatTypeMatch, channelIndex = gmatch(chatType, "([^%d]*)([%d]*)$")();
	
	-- Убедимся, что активное окно чата выбрано и видимо
	if FCF_GetCurrentChatFrame() ~= chatFrame then
		-- Активируем нужное окно чата
		FCF_SelectDockFrame(chatFrame);
	end
	
	-- Сначала закрываем любое существующее окно ввода, чтобы избежать проблем
	if chatFrame.editBox and chatFrame.editBox:IsVisible() then
		chatFrame.editBox:Hide();
	end
	
	-- Открываем чат с пустой строкой, чтобы гарантировать правильное состояние
	ChatFrame_OpenChat("", chatFrame);
	
	-- Убедимся, что окно редактирования доступно
	local editBox = chatFrame.editBox;
	if not editBox then 
		return; 
	end
	
	if chatTypeMatch == "WHISPER" then
		-- Обработка шепота
		if target then
			ChatFrame_OpenChat("/w " .. target .. " ", chatFrame);
		else
			ChatFrame_OpenChat("/w ", chatFrame);
		end
	elseif chatTypeMatch == "CHANNEL" then
		-- Обработка каналов
		local channelNum;
		
		if target then
			if type(target) == "string" then
				channelNum = GetChannelName(target);
			else
				channelNum = target;
			end
		elseif channelIndex then
			channelNum = tonumber(channelIndex);
		else
			return;
		end
		
		-- Используем прямую команду для канала
		if channelNum and channelNum > 0 then
			local channelCommand = "/"..(channelNum).." ";
			ChatFrame_OpenChat(channelCommand, chatFrame);
		else
			-- Если не удалось определить номер канала, просто открываем чат
			ChatFrame_OpenChat("", chatFrame);
		end
	elseif chatTypeMatch then
		-- Другие типы чата (say, yell, raid и т.д.)
		local prefix = _G["SLASH_" .. chatTypeMatch .. "1"];
		if prefix then
			ChatFrame_OpenChat(prefix .. " ", chatFrame);
		else
			-- Если не найден префикс, используем тип напрямую
			ChatFrame_OpenChat("/" .. lower(chatTypeMatch) .. " ", chatFrame);
		end
	end
end

function ChatBar_StandardButtonClick(self, button, target)
	-- Убрано меню по правой кнопке мыши
	local chatType = ChatBar_ChatTypes[self.ChatID].type;
	ChatBar_UseChatType(chatType, target);
end

function ChatBar_ChannelShortText(index)
	local channelNum, channelName = GetChannelName(index);
	if channelNum ~= 0 then
		if ChatBar_TextChannelNumbers then
			return channelNum;
		else
			return sub(channelName,1,CHATBAR_CHAR_LENGTH);
		end
	end
end

function ChatBar_ChannelText(index)
	local channelNum, channelName = GetChannelName(index);
	if channelNum ~= 0 then
		return channelNum..") "..channelName;
	end
	return "";
end

function ChatBar_ChannelShow(index)
	local channelNum, channelName = GetChannelName(index);
	if channelNum ~= 0 then
		if ChatBar_HideSpecialChannels then
			--Special Hidden Whisper Ignores
			if IsAddOnLoaded("Sky") then
				if len(channelName) >= 3 and sub(channelName,1,3) == "Sky" then
					--Hide Sky channels
					return;
				end
				for i, bogusName in ipairs(BOGUS_CHANNELS) do
					if channelName == bogusName then
						--Hide reorder channels
						return;
					end
				end
			elseif IsAddOnLoaded("CallToArms") and channelName == CTA_DEFAULT_RAID_CHANNEL then
				--Hide CallToArms channel
				return;
			elseif IsAddOnLoaded("CT_RaidAssist") and channelName == CT_RA_Channel then
				--Hide CT_RaidAssist channel
				return;
			elseif IsAddOnLoaded("GuildMap") and GuildMapConfig and channelName == GuildMapConfig.channel then
				--Hide GuildMap channel
				return;
			elseif channelName == "GlobalComm" then
				--Hide standard GlobalComm channel (Telepathy, AceComm)
				return;
			end
		end
		return not ChatBar_HiddenButtons[ChatBar_GetFirstWord(channelName)];
	end
end

--------------------------------------------------
-- Button Info
--------------------------------------------------

ChatBar_ChatTypes = {
	{
		type = "SAY",
		shortText = function() return CHATBAR_SAY_ABRV; end,
		text = function() return CHAT_MSG_SAY; end,
		click = ChatBar_StandardButtonClick,
		blockable = true,
		show = function()
			return (not ChatBar_HiddenButtons[CHAT_MSG_SAY]);
		end
	},
	{
		type = "YELL",
		shortText = function() return CHATBAR_YELL_ABRV; end,
		text = function() return CHAT_MSG_YELL; end,
		click = ChatBar_StandardButtonClick,
		blockable = true,
		show = function()
			return (not ChatBar_HiddenButtons[CHAT_MSG_YELL]);
		end
	},
	{
		type = "PARTY",
		shortText = function() return CHATBAR_PARTY_ABRV; end,
		text = function() return CHAT_MSG_PARTY; end,
		click = ChatBar_StandardButtonClick,
		blockable = true,
		blockExtra = {"PARTY_LEADER"};
		show = function()
			return UnitExists("party1") and (not ChatBar_HiddenButtons[CHAT_MSG_PARTY]);
		end
	},
	{
		type = "RAID",
		shortText = function() return CHATBAR_RAID_ABRV; end,
		text = function() return CHAT_MSG_RAID; end,
		click = ChatBar_StandardButtonClick,
		blockable = true,
		blockExtra = {"RAID_LEADER"};
		show = function()
			return (GetNumRaidMembers() > 0) and (not ChatBar_HiddenButtons[CHAT_MSG_RAID]);
		end
	},
	{
		type = "RAID_WARNING",
		shortText = function() return CHATBAR_RAID_WARNING_ABRV; end,
		text = function() return CHAT_MSG_RAID_WARNING; end,
		click = ChatBar_StandardButtonClick,
		show = function()
			return (GetNumRaidMembers() > 0) and (IsRaidLeader() or IsRaidOfficer()) and (not ChatBar_HiddenButtons[CHAT_MSG_RAID_WARNING]);
		end
	},
	{
		type = "BATTLEGROUND",
		shortText = function() return CHATBAR_BATTLEGROUND_ABRV; end,
		text = function() return CHAT_MSG_BATTLEGROUND; end,
		click = ChatBar_StandardButtonClick,
		blockable = true,
		blockExtra = {"BATTLEGROUND_LEADER"};
		show = function()
			return (select(2, IsInInstance()) == "pvp") and (not ChatBar_HiddenButtons[CHAT_MSG_BATTLEGROUND]);
		end
	},
	{
		type = "GUILD",
		shortText = function() return CHATBAR_GUILD_ABRV; end,
		text = function() return CHAT_MSG_GUILD; end,
		click = ChatBar_StandardButtonClick,
		blockable = true,
		blockExtra = {"GUILD_ACHIEVEMENT"};
		show = function()
			return IsInGuild() and (not ChatBar_HiddenButtons[CHAT_MSG_GUILD]);
		end
	},
	{
		type = "OFFICER",
		shortText = function() return CHATBAR_OFFICER_ABRV; end,
		text = function() return CHAT_MSG_OFFICER; end,
		click = ChatBar_StandardButtonClick,
		blockable = true,
		chatGroup = "GUILD_OFFICER",
		show = function()
			return CanEditOfficerNote() and (not ChatBar_HiddenButtons[CHAT_MSG_OFFICER]);
		end
	},
	{
		type = "WHISPER",
		shortText = function() return CHATBAR_WHISPER_ABRV; end,
		text = function() return CHAT_MSG_WHISPER_INFORM; end,
		click = ChatBar_StandardButtonClick,
		show = function()
			return (not ChatBar_HiddenButtons[CHAT_MSG_WHISPER_INFORM]);
		end
	},
	{
		type = "EMOTE",
		shortText = function() return CHATBAR_EMOTE_ABRV; end,
		text = function() return CHAT_MSG_EMOTE; end,
		click = ChatBar_StandardButtonClick,
		blockable = true,
		show = function()
			return (not ChatBar_HiddenButtons[CHAT_MSG_EMOTE]);
		end
	},
	{
		type = "CHANNEL1",
		shortText = function() return ChatBar_ChannelShortText(1); end,
		text = function() return ChatBar_ChannelText(1); end,
		click = function(self, button) ChatBar_StandardButtonClick(self, button, 1); end,
		show = function() return ChatBar_ChannelShow(1); end
	},
	{
		type = "CHANNEL2",
		shortText = function() return ChatBar_ChannelShortText(2); end,
		text = function() return ChatBar_ChannelText(2); end,
		click = function(self, button) ChatBar_StandardButtonClick(self, button, 2); end,
		show = function() return ChatBar_ChannelShow(2); end
	},
	{
		type = "CHANNEL3",
		shortText = function() return ChatBar_ChannelShortText(3); end,
		text = function() return ChatBar_ChannelText(3); end,
		click = function(self, button) ChatBar_StandardButtonClick(self, button, 3); end,
		show = function() return ChatBar_ChannelShow(3); end
	},
	{
		type = "CHANNEL4",
		shortText = function() return ChatBar_ChannelShortText(4); end,
		text = function() return ChatBar_ChannelText(4); end,
		click = function(self, button) ChatBar_StandardButtonClick(self, button, 4); end,
		show = function() return ChatBar_ChannelShow(4); end
	},
	{
		type = "CHANNEL5",
		shortText = function() return ChatBar_ChannelShortText(5); end,
		text = function() return ChatBar_ChannelText(5); end,
		click = function(self, button) ChatBar_StandardButtonClick(self, button, 5); end,
		show = function() return ChatBar_ChannelShow(5); end
	},
	{
		type = "CHANNEL6",
		shortText = function() return ChatBar_ChannelShortText(6); end,
		text = function() return ChatBar_ChannelText(6); end,
		click = function(self, button) ChatBar_StandardButtonClick(self, button, 6); end,
		show = function() return ChatBar_ChannelShow(6); end
	},
	{
		type = "CHANNEL7",
		shortText = function() return ChatBar_ChannelShortText(7); end,
		text = function() return ChatBar_ChannelText(7); end,
		click = function(self, button) ChatBar_StandardButtonClick(self, button, 7); end,
		show = function() return ChatBar_ChannelShow(7); end
	},
	{
		type = "CHANNEL8",
		shortText = function() return ChatBar_ChannelShortText(8); end,
		text = function() return ChatBar_ChannelText(8); end,
		click = function(self, button) ChatBar_StandardButtonClick(self, button, 8); end,
		show = function() return ChatBar_ChannelShow(8); end
	},
	{
		type = "CHANNEL9",
		shortText = function() return ChatBar_ChannelShortText(9); end,
		text = function() return ChatBar_ChannelText(9); end,
		click = function(self, button) ChatBar_StandardButtonClick(self, button, 9); end,
		show = function() return ChatBar_ChannelShow(9); end
	},
	{
		type = "CHANNEL10",
		shortText = function() return ChatBar_ChannelShortText(10); end,
		text = function() return ChatBar_ChannelText(10); end,
		click = function(self, button) ChatBar_StandardButtonClick(self, button, 10); end,
		show = function() return ChatBar_ChannelShow(10); end
	}
	
};

ChatBar_BarTypes = {};

--------------------------------------------------
-- Frame Scripts
--------------------------------------------------

function ChatBar_OnLoad(self)
	-- Сначала только VARIABLES_LOADED, чтобы решить об активации
	self:RegisterEvent("VARIABLES_LOADED");
	self:RegisterForDrag("LeftButton");
	self.velocity = 0;
	
	-- До решения об активации — скрыто
	self:Hide();
	ChatBar_IsShown = false;
	
	if (Eclipse) then
		--Register with VisibilityOptions
		Eclipse.registerForVisibility( {
			name = "ChatBarFrame";	--The name of the config, in this case also the name of the frame
			uiname = "ChatBar";	--This is the base name of this reg to display in the description and ui
			slashcom = { "chatbar", "cb" };	--These are the slash commands
			reqs = { var=ChatBar_ShowIf, val=true, show=true };
		}	);
	end
end

function ChatBar_ShowIf()
	return ChatBarFrame.isSliding or ChatBarFrame.isMoving or (type(ChatBarFrame.count)=="number") or ((UIDROPDOWNMENU_OPEN_MENU=="ChatBar_DropDown" and (MouseIsOver(DropDownList1) or (UIDROPDOWNMENU_MENU_LEVEL==2 and MouseIsOver(DropDownList2))))==1);
end

function ChatBar_OnEvent(self, event, ...)
	local target = select(8, ...)
	if event == "VARIABLES_LOADED" then
		-- решаем, активируемся ли
		local enabled = ChatBar_IsEnabled()
		if not enabled then
			-- отписываем все события, скрываем фрейм и остаёмся пассивными
			self:UnregisterAllEvents()
			self:Hide()
			ChatBar_IsShown = false
			return
		end
		-- активируем полноценную работу и регистрируем остальные события
		ChatBar_Active = true
		-- Alt режим теперь управляется через SarychUI модуль chat
		ChatBar_AltModeEnabled = true
		if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat then
			local chatModule = SarychUI.db.profile.modules.chat
			ChatBar_AltModeEnabled = (chatModule.chatBarOnAlt == 1)
		elseif _G.sarChatCharDB and _G.sarChatCharDB.chatBarAltModeEnabled ~= nil then
			ChatBar_AltModeEnabled = (_G.sarChatCharDB.chatBarAltModeEnabled == 1)
		elseif _G.sarChatDB and _G.sarChatDB.chatBarAltModeEnabled ~= nil then
			ChatBar_AltModeEnabled = (_G.sarChatCharDB.chatBarAltModeEnabled == 1)
		end
		self:RegisterEvent("UPDATE_CHAT_COLOR")
		self:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
		self:RegisterEvent("PARTY_MEMBERS_CHANGED")
		self:RegisterEvent("RAID_ROSTER_UPDATE")
		self:RegisterEvent("PLAYER_GUILD_UPDATE")
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("CHAT_TAB_CHANGED")
		self:RegisterEvent("UPDATE_CHAT_WINDOWS")
		self:RegisterForDrag("LeftButton")
		self.velocity = 0

		-- Инициализация
		ChatBar_InstallRetellHook()
		ChatBar_UpdateButtonOrientation();
		ChatBar_UpdateButtonSizes();
		ChatBar_UpdateButtonFlashing();
		ChatBar_UpdateBarBorder();
		ChatBar_UpdateButtonText();
		ChatBar_UpdateChannelBindings();
		for chatType, enabledSticky in pairs(ChatBar_StoredStickies) do
			if enabledSticky then
				ChatTypeInfo[chatType].sticky = enabledSticky;
			end
		end
		self:Show();
		ChatBar_IsShown = true;
		-- Таймер запускается позже в OnUpdate
		self.hideTimer = 0;
		self.shouldHideAfterLoad = true;

		-- Регистрация с VisibilityOptions (если доступно)
		if (Eclipse) then
			Eclipse.registerForVisibility( {
				name = "ChatBarFrame";
				uiname = "ChatBar";
				slashcom = { "chatbar", "cb" };
				reqs = { var=ChatBar_ShowIf, val=true, show=true };
			} );
		end
	elseif event == "UPDATE_CHAT_COLOR" then
		self.count = 0;
	elseif event == "CHAT_MSG_CHANNEL_NOTICE" then
		self.count = 0;
	elseif event == "PARTY_MEMBERS_CHANGED" then
		-- Немедленное обновление для группы
		ChatBar_UpdateButtons();
		self.count = 0;
	elseif event == "RAID_ROSTER_UPDATE" then
		-- Немедленное обновление для рейда
		ChatBar_UpdateButtons();
		self.count = 0;
	elseif event == "PLAYER_GUILD_UPDATE" then
		-- Немедленное обновление для гильдии
		ChatBar_UpdateButtons();
		self.count = 0;
	elseif event == "CHAT_MSG_CHANNEL" and type(target) == "number" then
		-- Удалено мигание кнопки, так как текстуры больше нет
	elseif event == "PLAYER_ENTERING_WORLD" then
		-- Обновляем кнопки при входе в мир
		ChatBar_UpdateButtons();
		self:Show();
		ChatBar_IsShown = true;
	elseif event == "CHAT_TAB_CHANGED" or event == "UPDATE_CHAT_WINDOWS" then
		-- Обновляем положение при изменении вкладки чата или настроек окон чата
		if not ChatBarFrame:IsUserPlaced() then
			ChatBar_UpdateOrientationPoint(true);
			-- Обновляем кнопки для нового активного окна чата
			ChatBarFrame.count = 0; -- Это запустит обновление кнопок в OnUpdate
		end
	else
		-- Удалено мигание кнопок, так как текстуры больше нет
	end
end

--ConstantInitialVelocity = 10;
ConstantVelocityModifier = 1.25;
ConstantJerk = 3*ConstantVelocityModifier;
ConstantSnapLimit = 2;

-- Функция для переключения видимости ChatBar
function ChatBar_ToggleVisibility()
    if ChatBar_IsShown then
        ChatBarFrame:Hide();
        ChatBar_IsShown = false;
    else
        ChatBarFrame:Show();
        ChatBar_IsShown = true;
    end
end

-- Alt Mode система теперь управляется через SarychUI.AltMode
-- Старая система отслеживания Alt удалена

function ChatBar_OnUpdate(self, elapsed)
    -- Дополнительная проверка модуля SarychUI
    if not ChatBar_IsEnabled() then
        -- при выключенном модуле вообще не выполняем логику
        if self:IsShown() then self:Hide() end
        ChatBar_Active = false
        return
    end
    
    -- Если модуль включен, но ChatBar неактивен - активируем
    if not ChatBar_Active then
        ChatBar_Active = true
        -- Регистрируем события заново
        self:RegisterEvent("UPDATE_CHAT_COLOR")
        self:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
        self:RegisterEvent("PARTY_MEMBERS_CHANGED")
        self:RegisterEvent("RAID_ROSTER_UPDATE")
        self:RegisterEvent("PLAYER_GUILD_UPDATE")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("CHAT_TAB_CHANGED")
        self:RegisterEvent("UPDATE_CHAT_WINDOWS")
        -- Обновляем настройки Alt режима
        ChatBar_AltModeEnabled = true
        if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat then
            local chatModule = SarychUI.db.profile.modules.chat
            ChatBar_AltModeEnabled = (chatModule.chatBarOnAlt == 1)
        elseif _G.sarChatCharDB and _G.sarChatCharDB.chatBarAltModeEnabled ~= nil then
            ChatBar_AltModeEnabled = (_G.sarChatCharDB.chatBarAltModeEnabled == 1)
        elseif _G.sarChatDB and _G.sarChatDB.chatBarAltModeEnabled ~= nil then
            ChatBar_AltModeEnabled = (_G.sarChatCharDB.chatBarAltModeEnabled == 1)
        end
        
        -- Инициализируем ChatBar
        ChatBar_InstallRetellHook()
        ChatBar_UpdateButtonOrientation()
        ChatBar_UpdateButtonSizes()
        ChatBar_UpdateButtonFlashing()
        ChatBar_UpdateBarBorder()
        ChatBar_UpdateButtonText()
        ChatBar_UpdateChannelBindings()
        for chatType, enabledSticky in pairs(ChatBar_StoredStickies) do
            if enabledSticky then
                ChatTypeInfo[chatType].sticky = enabledSticky
            end
        end
        self:Show()
        ChatBar_IsShown = true
        self.hideTimer = 0
        self.shouldHideAfterLoad = true
    end
    
    -- Проверяем состояние Alt через новую систему SarychUI.AltMode
    local altPressed = false
    if SarychUI and SarychUI.AltMode then
        altPressed = SarychUI.AltMode:IsAltPressed()
    end

    -- Управление таймером начального отображения (ПРИОРИТЕТ 1)
    if ChatBar_AltModeEnabled and self.shouldHideAfterLoad then
        self.hideTimer = (self.hideTimer or 0) + elapsed;
        if self.hideTimer >= FADE_OUT_START_DELAY then
            self.shouldHideAfterLoad = false;
            self.hideTimer = 0;
            -- Запускаем анимацию затухания
            ChatBar_DoFadeOut = true;
            ChatBar_FadeStart = GetTime();
            self:SetAlpha(1.0);
        end
    end
    
    -- Обработка анимации затухания (ПРИОРИТЕТ 2)
    if ChatBar_AltModeEnabled and ChatBar_DoFadeOut then
        local currentTime = GetTime();
        local elapsedTime = currentTime - ChatBar_FadeStart;
        
        if elapsedTime < FADE_OUT_DURATION then
            -- Рассчитываем и устанавливаем новую альфу
            local progress = elapsedTime / FADE_OUT_DURATION;
            local alpha = 1.0 - progress;
            
            -- Применяем новую альфу
            self:SetAlpha(alpha);
            ChatBar_IsShown = true; -- Панель все еще видна, но прозрачна
        else
            -- Анимация завершена, скрываем панель
            ChatBar_DoFadeOut = false;
            self:Hide();
            self:SetAlpha(1.0); -- Сбрасываем альфу для будущих показов
            ChatBar_IsShown = false;
        end
        return; -- Выходим, пока идет анимация
    end
    
    -- Alt режим управляется через модуль chat
    -- Вызываем UpdateChatBarVisibility для управления видимостью
    if SarychUI and SarychUI.modules and SarychUI.modules.chat then
        SarychUI.modules.chat:UpdateChatBarVisibility()
    end
	
	if (self.slidingEnabled) and (self.isSliding) and (self.velocity) and (self.endsize) then
		local currSize = ChatBar_GetSize();
		if (abs(currSize - self.endsize) < ConstantSnapLimit) then
			ChatBar_SetSize(self.endsize);
			ChatBarFrame.isSliding = nil;
			self.velocity = 0;
			if (ChatBar_VerticalDisplay_Sliding or ChatBar_AlternateDisplay_Sliding 
					or ChatBar_LargeButtons_Sliding) and (self:GetWidth() <= 17) and (self:GetHeight() <= 17) then
				if (ChatBar_VerticalDisplay_Sliding) then
					ChatBar_VerticalDisplay_Sliding = nil;
					ChatBar_Toggle_VerticalButtonOrientation();
				elseif (ChatBar_AlternateDisplay_Sliding) then
					ChatBar_AlternateDisplay_Sliding = nil;
					ChatBar_Toggle_AlternateButtonOrientation();
				elseif (ChatBar_LargeButtons_Sliding) then
					ChatBar_LargeButtons_Sliding = nil;
					ChatBar_Toggle_LargeButtons();
				end
				ChatBar_UpdateOrientationPoint();
			else
				ChatBar_UpdateOrientationPoint(true);
			end
		else
			local desiredVelocity = ConstantVelocityModifier * (self.endsize - currSize);
			local acceleration = ConstantJerk * (desiredVelocity - self.velocity);
			self.velocity = self.velocity + acceleration * elapsed;
			ChatBar_SetSize(currSize + self.velocity * elapsed);
		end
		local frame, init, final, step;
		for i=1, CHAT_BAR_MAX_BUTTONS do
			frame = _G["ChatBarFrameButton".. i];
			if (currSize >= i*(16*ChatBar_ButtonScale)+18) then
				frame:Show();
			else
				frame:Hide();
			end
		end
	elseif (self.count) then
		if (self.count > CHAT_BAR_UPDATE_DELAY) then
			self.count = nil;
			ChatBarFrame.slidingEnabled = true;
			ChatBar_UpdateButtons();
		else
			self.count = self.count+1;
		end
	end
end

function ChatBar_GetSize()
	if (ChatBar_VerticalDisplay) then
		return ChatBarFrame:GetHeight();
	else
		return ChatBarFrame:GetWidth();
	end
end

function ChatBar_SetSize(size)
	if (ChatBar_VerticalDisplay) then
		ChatBarFrame:SetHeight(size);
	else
		ChatBarFrame:SetWidth(size);
	end
end

function ChatBar_Button_OnLoad(self)
	-- Всегда подхватываем ссылки, чтобы другие функции не падали
	self.Text = _G["ChatBarFrameButton".. self:GetID().."Text"];
	self.ChatID = self:GetID();
	
	self:SetFrameLevel(self:GetFrameLevel()+1);
	self:RegisterForClicks("LeftButtonDown", "RightButtonDown");
	if not ChatBar_IsEnabled() or not ChatBar_Active then
		self:Hide()
	end
end

function ChatBar_Button_OnClick(self, button)
    if not ChatBar_IsEnabled() or not ChatBar_Active then return end
	ChatBar_ChatTypes[self.ChatID].click(self, button);
end

function ChatBar_Button_OnEnter(self)
    if not ChatBar_IsEnabled() or not ChatBar_Active then return end
	--local id = self:GetID();
	if (self.ChatID) then
		ChatBarFrameTooltip:SetOwner(self, "ANCHOR_TOPLEFT");
		ChatBarFrameTooltip:SetText(ChatBar_ChatTypes[self.ChatID].text());
	end
end

function ChatBar_Button_OnLeave(self)
    if not ChatBar_IsEnabled() or not ChatBar_Active then return end
	if (ChatBarFrameTooltip:IsOwned(self)) then
		ChatBarFrameTooltip:Hide();
	end
end

function ChatBar_OnMouseDown(self, button)
    if not ChatBar_IsEnabled() or not ChatBar_Active then return end
	if (button == "RightButton") then
		ToggleDropDownMenu(1, "ChatBarMenu", ChatBar_DropDown, "cursor");
	else
		local x, y = GetCursorPosition();
		self.xOffset = x - self:GetLeft();
		self.yOffset = y - self:GetBottom();
	end
end

function ChatBar_OnDragStart(self)
    if not ChatBar_IsEnabled() or not ChatBar_Active then return end
	if (not self.isSliding) then
		local x, y = GetCursorPosition();
		self:ClearAllPoints();
		self:SetPoint("BOTTOMLEFT", "UIParent", "BOTTOMLEFT", x-self.xOffset, y-self.yOffset);
		self:StartMoving();
		self.isMoving = true;
	end
end

function ChatBar_OnDragStop(self)
    if not ChatBar_IsEnabled() or not ChatBar_Active then return end
	self:StopMovingOrSizing();
	self.isMoving = false;
	ChatBar_UpdateOrientationPoint(true);
end

--------------------------------------------------
-- DropDown Menu
--------------------------------------------------

-- Функции меню настроек удалены

function ChatBar_CreateFrameMenu()
	-- Функция меню удалена
	
	--Text On Buttons
	local info = {};
	info.text = CHATBAR_MENU_MAIN_TEXTONBUTTONS;
	info.func = ChatBar_Toggle_TextOrientation;
	info.keepShownOnClick = 1;
	if (ChatBar_TextOnButtonDisplay) then
		info.checked = 1;
	end
	UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
	
	--Show Button Text
	local info = {};
	info.text = CHATBAR_MENU_MAIN_SHOWTEXT;
	info.func = ChatBar_Toggle_ButtonText;
	info.keepShownOnClick = 1;
	if (ChatBar_ButtonText) then
		info.checked = 1;
	end
	UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
	
	--Use Channel ID on Buttons
	local info = {};
	info.text = CHATBAR_MENU_MAIN_CHANNELID;
	info.func = ChatBar_Toggle_TextChannelNumbers;
	info.keepShownOnClick = 1;
	if (ChatBar_TextChannelNumbers) then
		info.checked = 1;
	end
	UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
	
	--Button Flashing
	local info = {};
	info.text = CHATBAR_MENU_MAIN_BUTTONFLASHING;
	info.func = ChatBar_Toggle_ButtonFlashing;
	info.keepShownOnClick = 1;
	if (ChatBar_ButtonFlashing) then
		info.checked = 1;
	end
	UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

	--Bar Border
	local info = {};
	info.text = CHATBAR_MENU_MAIN_BARBORDER;
	info.func = ChatBar_Toggle_BarBorder;
	info.keepShownOnClick = 1;
	if (ChatBar_BarBorder) then
		info.checked = 1;
	end
	UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
	
	--Hide Special
	local info = {};
	info.text = CHATBAR_MENU_MAIN_ADDONCHANNELS;
	info.func = ChatBar_Toggle_HideSpecialChannels;
	if (ChatBar_HideSpecialChannels) then
		info.checked = 1;
	end
	UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
	
	--Hide All
	local info = {};
	info.text = CHATBAR_MENU_MAIN_HIDEALL;
	info.func = ChatBar_Toggle_HideAllButtons;
	if (ChatBar_HideAllButtons) then
		info.checked = 1;
	end
	UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
	
	local size = 0;
	for _, v in pairs(ChatBar_HiddenButtons) do
		if (v) then
			size = size+1
		end
	end
	if (size > 0) then
		--Show Hidden Buttons
		local info = {};
		info.text = CHATBAR_MENU_MAIN_HIDDENBUTTONS;
		info.hasArrow = 1;
		info.func = nil;
		info.value = "HiddenButtonsMenu";
		UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
	end
	
	--Reset Position
	local info = {};
	info.text = CHATBAR_MENU_MAIN_RESET;
	info.func = ChatBar_Reset;
	if (not ChatBarFrame:IsUserPlaced()) then
		info.checked = 1;
	end
	UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
	
	--Reorder Channels
	local info = {};
	info.text = CHATBAR_MENU_MAIN_REORDER;
	if (not Chronos) then
		info.text = info.text..CHATBAR_MENU_MAIN_REQCHRONOS
		info.disabled = 1;
	end
	info.func = ChatBar_ReorderChannels;
	UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
end

function ChatBar_CreateHiddenButtonsMenu()
	for k,v in pairs(ChatBar_HiddenButtons) do
		--Show Button
		local info = {};
		info.text = format(CHATBAR_MENU_SHOW_BUTTON, k);
		local ctype = k;
		info.func = function() ChatBar_HiddenButtons[ctype]=nil ChatBarFrame.count = 0; end;
		info.notCheckable = 1;
		UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
	end
end

-- Функция CreateAltArtMenu удалена

function ChatBar_CreateButtonMenu()
	local buttonHeader = ChatBar_ChatTypes[UIDROPDOWNMENU_MENU_VALUE].type;
	
	--Title
	local info = {};
	info.text = ChatBar_ChatTypes[UIDROPDOWNMENU_MENU_VALUE].text();
	info.notClickable = 1;
	info.isTitle = 1;
	UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
	
	local chatType, channelIndex = gmatch(buttonHeader, "([^%d]*)([%d]+)$")();
	
	if channelIndex then
		local channelNum, channelName = GetChannelName(tonumber(channelIndex));
		local channelShortName = ChatBar_GetFirstWord(channelName);
		
		--Block
		local info = {};
		info.text = format(CHATBAR_MENU_CHANNEL_BLOCK, channelShortName);
		info.arg1 = channelShortName;
		info.func = function(self, channel, arg2, checked) ChatBar_ToggleChatChannel(checked, channel) end;
		info.checked = not ChatBar_IsListeningForChannel(channelShortName);
		UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
		
		--Leave
		local info = {};
		info.text = CHATBAR_MENU_CHANNEL_LEAVE;
		info.func = function() LeaveChannelByName(channelNum) end;
		UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

		--Channel User List
		local info = {};
		info.text = CHATBAR_MENU_CHANNEL_LIST;
		info.func = function() ListChannelByName(channelNum) end;
		UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
		
		--Hide Button
		local info = {};
		info.text = format(CHATBAR_MENU_HIDE_BUTTON, channelShortName);
		info.func = function() ChatBar_HiddenButtons[channelShortName]=true; ChatBarFrame.count = 0; end;
		UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
	else
		local localizedChatType = ChatBar_ChatTypes[UIDROPDOWNMENU_MENU_VALUE].text()

		--Block
		if ChatBar_ChatTypes[UIDROPDOWNMENU_MENU_VALUE].blockable then
			local info = {};
			info.text = format(CHATBAR_MENU_CHANNEL_BLOCK, localizedChatType);
			info.arg1 = UIDROPDOWNMENU_MENU_VALUE;
			info.func = function(self, chatTypeIndex, arg2, checked) ChatBar_ToggleChatMessageGroup(checked, chatTypeIndex) end;
			info.checked = not ChatBar_IsListeningForChatType(ChatBar_ChatTypes[UIDROPDOWNMENU_MENU_VALUE].chatGroup or buttonHeader);
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
		end
		
		--Hide Button
		local info = {};
		info.text = format(CHATBAR_MENU_HIDE_BUTTON, localizedChatType);
		info.func = function() ChatBar_HiddenButtons[localizedChatType]=true; ChatBarFrame.count = 0; end;
		UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
	end
	
	if buttonHeader == "WHISPER" then
		local chatFrame = SELECTED_DOCK_FRAME
		if not chatFrame then
			chatFrame = DEFAULT_CHAT_FRAME;
		end
		
		--Reply
		local info = {};
		info.text = CHATBAR_MENU_WHISPER_REPLY;
		info.func = function()
			ChatFrame_ReplyTell(chatFrame)
		end;
		if (not chatFrame.editBox) or (not ChatEdit_GetLastTellTarget) or ChatEdit_GetLastTellTarget() == "" then
			info.disabled = 1;
		end
		UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
		
		--Retell
		local info = {};
		info.text = CHATBAR_MENU_WHISPER_RETELL;
		info.func = function()
			ChatFrame_SendTell(ChatBar_LastTell, chatFrame)
		end;
		if not ChatBar_LastTell then
			info.disabled = 1;
		end
		UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
	end
	
	if channelIndex then
		local info = {};
		info.text = CHATBAR_MENU_BINDING;
		info.hasArrow = 1;
		info.value = buttonHeader;
		UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
	end
	
	--Sticky
	local info = {};
	if chatType then
		info.text = CHATBAR_MENU_CHANNEL_STICKY;
	else
		info.text = CHATBAR_MENU_STICKY;
		chatType = buttonHeader;
	end
	info.func = function()
		if ChatTypeInfo[chatType].sticky == 1 then
			ChatTypeInfo[chatType].sticky = 0;
			ChatBar_StoredStickies[chatType] = 0;
		else
			ChatTypeInfo[chatType].sticky = 1;
			ChatBar_StoredStickies[chatType] = 1;
		end
	end;
	if ChatTypeInfo[chatType].sticky == 1 then
		info.checked = 1;
	end
	if not ChatTypeInfo[chatType] then
		info.disabled = 1;
	end
	UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

end

function ChatBar_ReplaceChannelBinding(index, newTarget)
	if newTarget then
		for i=1, 10 do
			if ChatBar_ChannelBindings[i] == newTarget then
				ChatBar_ChannelBindings[i] = nil;
				_G["BINDING_NAME_CHATBAR_CHANNEL"..i] = format(BINDING_NAME_CHATBAR_CHANNEL_FORMAT, i)
			end
		end
	end
	if index then
		ChatBar_ChannelBindings[index] = newTarget;
		_G["BINDING_NAME_CHATBAR_CHANNEL"..index] = format(BINDING_NAME_CHATBAR_CHANNEL_FORMAT, newTarget)
	end
end

function ChatBar_CreateChannelBindingMenu()
	local buttonHeader = UIDROPDOWNMENU_MENU_VALUE;
	local chatType, channelIndex = gmatch(buttonHeader, "([^%d]*)([%d]+)$")();
	local channelNum, channelName = GetChannelName(tonumber(channelIndex));
	local channelShortName = ChatBar_GetFirstWord(channelName);
	
	--Title
	local info = {};
	info.text = CHATBAR_MENU_BINDING_TITLE;
	info.notClickable = 1;
	info.isTitle = 1;
	UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
	
	--None
	local info = {};
	info.text = CHATBAR_MENU_NONE;
	info.func = function() ChatBar_ReplaceChannelBinding(nil, channelShortName) end;
	info.checked = 1;
	for i=1, 10 do
		if ChatBar_ChannelBindings[i] == channelShortName then
			info.checked = nil;
			break;
		end
	end
	UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

	for i=1, 10 do
		local info = {};
		info.text = _G["BINDING_NAME_CHATBAR_CHANNEL"..i];
		local channelIndex = i;
		info.func = function() ChatBar_ReplaceChannelBinding(channelIndex, channelShortName) end;
		if ChatBar_ChannelBindings[i] == channelShortName then
			info.checked = 1;
		end
		UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
	end
end

--------------------------------------------------
-- Blocking Functions
--------------------------------------------------

function ChatBar_IsListeningForChatType(chatType)
	local frame = SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME
	local messageTypeList = frame.messageTypeList;
	if ( messageTypeList ) then
		for index, value in pairs(messageTypeList) do
			if ( value == chatType ) then
				return true;
			end
		end
		
		local blockExtra = ChatBar_ChatTypes[UIDROPDOWNMENU_MENU_VALUE].blockExtra;
		if (blockExtra) then
			for i, v in ipairs(blockExtra) do
				for index, value in pairs(messageTypeList) do
					if ( value == v ) then
						return true;
					end
				end
			end
		end
	end
	return false;
end

function ChatBar_IsListeningForChannel(channel)
	local frame = SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME
	local channelList = frame.channelList;
	local zoneChannelList = frame.zoneChannelList;
	if ( channelList ) then
		for index, value in pairs(channelList) do
			if ( value == channel ) then
				return true;
			end
		end
	end
	if ( zoneChannelList ) then
		for index, value in pairs(zoneChannelList) do
			if ( value == channel ) then
				return true;
			end
		end
	end
	return false;
end

function ChatBar_ToggleChatMessageGroup(checked, chatTypeIndex)
	local frame = SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME
	local chatType = (ChatBar_ChatTypes[chatTypeIndex].chatGroup or ChatBar_ChatTypes[chatTypeIndex].type);
	local channelName = ChatBar_ChatTypes[chatTypeIndex].text();
	if ( checked ) then
		ChatFrame_AddMessageGroup(frame, chatType);
	else
		ChatFrame_RemoveMessageGroup(frame, chatType);
	end
		
	local blockExtra = ChatBar_ChatTypes[chatTypeIndex].blockExtra;
	if (blockExtra) then
		for i, v in ipairs(blockExtra) do
			if ( checked ) then
				ChatFrame_AddMessageGroup(frame, v);
			else
				ChatFrame_RemoveMessageGroup(frame, v);
			end
		end
	end
end

function ChatBar_ToggleChatChannel(checked, channel)
	local frame = SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME
	if ( checked ) then
		ChatFrame_AddChannel(frame, channel);
	else
		ChatFrame_RemoveChannel(frame, channel);
	end
end

--------------------------------------------------
-- Update Functions
--------------------------------------------------

function ChatBar_UpdateButtons()
	-- Проверяем модуль перед обновлением
	if not ChatBar_IsEnabled() then
		-- Скрываем все кнопки если модуль выключен
		for i = 1, CHAT_BAR_MAX_BUTTONS do
			_G["ChatBarFrameButton"..i]:Hide();
		end
		return
	end
	
	ChatBar_BarTypes = {};
	local i = 1;
	local buttonIndex = 1;
	if not ChatBar_HideAllButtons then
		while ChatBar_ChatTypes[i] and buttonIndex <= CHAT_BAR_MAX_BUTTONS do
			if ChatBar_ChatTypes[i].show() then
				local info = ChatTypeInfo[ChatBar_ChatTypes[i].type];
				ChatBar_BarTypes[ChatBar_ChatTypes[i].type] = buttonIndex;
				-- Удалена установка цвета текстуры Flash
				_G["ChatBarFrameButton".. buttonIndex.."Text"]:SetText(ChatBar_ChatTypes[i].shortText());
				_G["ChatBarFrameButton".. buttonIndex.."Text"]:SetTextColor(info.r, info.g, info.b);
				_G["ChatBarFrameButton".. buttonIndex].ChatID = i;
				buttonIndex = buttonIndex+1;
			end
			i = i+1;
		end
	end
	local size = (buttonIndex-1)*(16*ChatBar_ButtonScale)+20;
	if ChatBar_VerticalDisplay then
		ChatBarFrame:SetWidth(16);
		if ChatBarFrame:GetTop() then
			ChatBar_StartSlidingTo(size);
		else
			ChatBarFrame:SetHeight(size);
		end
	else
		ChatBarFrame:SetHeight(16);
		if ChatBarFrame:GetRight() then
			ChatBar_StartSlidingTo(size);
		else
			ChatBarFrame:SetWidth(size);
		end
		--/z ChatBarFrame.startpoint = ChatBarFrame:GetRight();ChatBarFrame.endsize = ChatBarFrame:GetLeft() + 260;
		--/z ChatBarFrame.centerpoint = ChatBarFrame.startpoint + (ChatBarFrame.endsize - ChatBarFrame.startpoint)/2;ChatBarFrame.velocity = 0;ChatBarFrame.isSliding = true;
		--/z ChatBarFrame.isSliding = nil; ChatBarFrame:SetWidth(180)
		--/z ChatBar_StartSlidingTo(300)
	end
	while buttonIndex <= CHAT_BAR_MAX_BUTTONS do
		--_G["ChatBarFrameButton".. buttonIndex]:Hide();
		_G["ChatBarFrameButton".. buttonIndex].ChatID = nil;
		buttonIndex = buttonIndex+1;
	end

end

function ChatBar_StartSlidingTo(size)
	ChatBarFrame.endsize = size;
	ChatBarFrame.isSliding = true;
end

function ChatBar_UpdateButtonSizes()
	for i = 1, CHAT_BAR_MAX_BUTTONS do
		_G["ChatBarFrameButton"..i]:SetScale(ChatBar_ButtonScale);
	end
end

function ChatBar_UpdateButtonOrientation()
	local button = ChatBarFrameButton1;
	button:ClearAllPoints();
	if button.Text then button.Text:ClearAllPoints() end
	if ChatBar_VerticalDisplay then
		if ChatBar_AlternateOrientation then
			button:SetPoint("TOP", "ChatBarFrame", "TOP", 0, (-10/ChatBar_ButtonScale));
		else
			button:SetPoint("BOTTOM", "ChatBarFrame", "BOTTOM", 0, (10/ChatBar_ButtonScale));
		end
		if button.Text then button.Text:SetPoint("CENTER", button) end
	else
		if ChatBar_AlternateOrientation then
			button:SetPoint("RIGHT", "ChatBarFrame", "RIGHT", (-10/ChatBar_ButtonScale), 0);
		else
			button:SetPoint("LEFT", "ChatBarFrame", "LEFT", (10/ChatBar_ButtonScale), 0);
		end
		if button.Text then button.Text:SetPoint("CENTER", button) end
	end
	for i=2, CHAT_BAR_MAX_BUTTONS do
		button = _G["ChatBarFrameButton"..i];
		button:ClearAllPoints();
		if button.Text then button.Text:ClearAllPoints() end
		if ChatBar_VerticalDisplay then
			if ChatBar_AlternateOrientation then
				button:SetPoint("TOP", "ChatBarFrameButton"..(i-1), "BOTTOM");
			else
				button:SetPoint("BOTTOM", "ChatBarFrameButton"..(i-1), "TOP");
			end
			if button.Text then button.Text:SetPoint("CENTER", button) end
		else
			if ChatBar_AlternateOrientation then
				button:SetPoint("RIGHT", "ChatBarFrameButton"..(i-1), "LEFT");
			else
				button:SetPoint("LEFT", "ChatBarFrameButton"..(i-1), "RIGHT");
			end
			if button.Text then button.Text:SetPoint("CENTER", button) end
		end
	end
end

function ChatBar_UpdateButtonFlashing()
	-- Функция оставлена для обратной совместимости,
	-- но больше не нужна, так как текстуры Flash были удалены
end

function ChatBar_UpdateBarBorder()
	-- No border for text-based buttons
end

function ChatBar_Reset()
	ChatBarFrame:ClearAllPoints();
	ChatBarFrame:SetPoint("BOTTOMLEFT", SELECTED_DOCK_FRAME or DEFAULT_CHAT_FRAME, "TOPLEFT", 0, 30);
	ChatBarFrame:SetUserPlaced(0);
end

-- Функция UpdateArt удалена - больше не нужна для текстового интерфейса

--------------------------------------------------
-- Configuration Functions
--------------------------------------------------

function ChatBar_Toggle_LargeButtonsSlide()
	if not ChatBarFrame.isMoving then
		ChatBar_LargeButtons_Sliding = true;
		ChatBar_StartSlidingTo(16);
	end
end

function ChatBar_Toggle_VerticalButtonOrientationSlide()
	if not ChatBarFrame.isMoving then
		ChatBar_VerticalDisplay_Sliding = true;
		ChatBar_StartSlidingTo(16);
	end
end

function ChatBar_Toggle_AlternateButtonOrientationSlide()
	if not ChatBarFrame.isMoving then
		ChatBar_AlternateDisplay_Sliding = true;
		ChatBar_StartSlidingTo(16);
	end
end

function ChatBar_Toggle_LargeButtons()
	ChatBar_ButtonScale = (ChatBar_ButtonScale == 1 and CHAT_BAR_LARGEBUTTONSCALE) or 1;
	ChatBar_UpdateButtonSizes();
	ChatBar_UpdateButtonOrientation();
	ChatBar_UpdateButtons();
end

function ChatBar_Toggle_VerticalButtonOrientation()
	ChatBar_VerticalDisplay = not ChatBar_VerticalDisplay;
	--ChatBar_UpdateOrientationPoint();
	ChatBar_UpdateButtonOrientation();
	ChatBar_UpdateButtons();
end

function ChatBar_UpdateOrientationPoint(expanded)
	local x, y;
	local chatFrame = SELECTED_DOCK_FRAME or DEFAULT_CHAT_FRAME;
	
	if ChatBarFrame:IsUserPlaced() then
		if expanded then
			if ChatBar_AlternateOrientation then
				x = ChatBarFrame:GetRight();
				y = ChatBarFrame:GetTop();
				ChatBarFrame:ClearAllPoints();
				ChatBarFrame:SetPoint("TOPRIGHT", "UIParent", "BOTTOMLEFT", x, y);
			else
				x = ChatBarFrame:GetLeft();
				y = ChatBarFrame:GetBottom();
				ChatBarFrame:ClearAllPoints();
				ChatBarFrame:SetPoint("BOTTOMLEFT", "UIParent", "BOTTOMLEFT", x, y);
			end
		else
			if ChatBar_AlternateOrientation then
				x = ChatBarFrame:GetLeft()+16;
				y = ChatBarFrame:GetBottom()+16;
				ChatBarFrame:ClearAllPoints();
				ChatBarFrame:SetPoint("TOPRIGHT", "UIParent", "BOTTOMLEFT", x, y);
			else
				x = ChatBarFrame:GetRight()-16;
				y = ChatBarFrame:GetTop()-16;
				ChatBarFrame:ClearAllPoints();
				ChatBarFrame:SetPoint("BOTTOMLEFT", "UIParent", "BOTTOMLEFT", x, y);
			end
		end
	else
		if ChatBar_AlternateOrientation then
			ChatBarFrame:ClearAllPoints();
			ChatBarFrame:SetPoint("TOPRIGHT", chatFrame, "TOPLEFT", 16, 46);
		else
			ChatBarFrame:ClearAllPoints();
			ChatBarFrame:SetPoint("BOTTOMLEFT", chatFrame, "TOPLEFT", 0, 30);
		end
	end
end

function ChatBar_Toggle_AlternateButtonOrientation()
	ChatBar_AlternateOrientation = not ChatBar_AlternateOrientation;
	--ChatBar_UpdateOrientationPoint();
	ChatBar_UpdateButtonOrientation();
	ChatBar_UpdateButtons();
end

function ChatBar_Toggle_TextOrientation()
	ChatBar_TextOnButtonDisplay = true; -- Always display text on buttons
	ChatBar_UpdateButtonOrientation();
end

function ChatBar_Toggle_ButtonFlashing()
	ChatBar_ButtonFlashing = not ChatBar_ButtonFlashing;
	ChatBar_UpdateButtonFlashing();
end

function ChatBar_Toggle_BarBorder()
	ChatBar_BarBorder = not ChatBar_BarBorder;
	ChatBar_UpdateBarBorder();
end

function ChatBar_Toggle_HideSpecialChannels()
	ChatBar_HideSpecialChannels = not ChatBar_HideSpecialChannels;
	ChatBar_UpdateButtons();
end

function ChatBar_Toggle_HideAllButtons()
	ChatBar_HideAllButtons = not ChatBar_HideAllButtons
	ChatBar_UpdateButtons();
end

function ChatBar_UpdateButtonText()
	for i=1, CHAT_BAR_MAX_BUTTONS do
		local button = _G["ChatBarFrameButton"..i];
		button.Text:Show();
	end
end

function ChatBar_Toggle_ButtonText()
	ChatBar_ButtonText = true; -- Always true for text-based buttons
	ChatBar_UpdateButtonText();
end

function ChatBar_Toggle_TextChannelNumbers()
	ChatBar_TextChannelNumbers = not ChatBar_TextChannelNumbers;
	ChatBar_UpdateButtons();
end

function ChatBar_UpdateChannelBindings()
	if ChatBar_ChannelBindings then
		for i=1, 10 do
			_G["BINDING_NAME_CHATBAR_CHANNEL"..i] = format(BINDING_NAME_CHATBAR_CHANNEL_FORMAT, ChatBar_ChannelBindings[i] or i);
		end
	else 
		ChatBar_ChannelBindings = {}
	end
end

--------------------------------------------------
-- Helper Functions
--------------------------------------------------

function ChatBar_GetFirstWord(s)
	local firstWord, count = gsub(s, "%s.*", "")
	return firstWord;
end


--------------------------------------------------
-- Reorder Channels
--------------------------------------------------

-- Standard Channel Order
STANDARD_CHANNEL_ORDER = {
	[CHATBAR_GENERAL] = 1,
	[CHATBAR_TRADE] = 2,
	[CHATBAR_LFG] = 3,
	[CHATBAR_LOCALDEFENSE] = 4,
	[CHATBAR_WORLDDEFENSE] = 5,
	[CHATBAR_GUILDRECRUITMENT] = 6,
};

BOGUS_CHANNELS = {
	"morneusgbyfyh",
	"akufbhfeuinjke",
	"lkushawdewui",
	"auwdbadwwho",
	"uawhbliuernb",
	"nvcuoiisnejfk",
	"cmewhumimr",
	"cliuchbwubine",
	"omepwucbawy",
	"yuiwbefmopou"
};

CHATBAR_CAPITAL_CITIES = {
	[CHATBAR_ORGRIMMAR] = 1,
	[CHATBAR_STORMWIND] = 1,
	[CHATBAR_IRONFORGE] = 1,
	[CHATBAR_DARNASSUS] = 1,
	[CHATBAR_UNDERCITY] = 1,
	[CHATBAR_THUNDERBLUFF] = 1,
	[CHATBAR_SHATRATH] = 1,
	[CHATBAR_EXODAR] = 1,
	[CHATBAR_SILVERMOON] = 1,
	[CHATBAR_DALARAN] = 1,
};

--
--	reorderChannels()
--		Stores current channels, Leaves all channels and then rejoins them in a standard ordering.
--		
--
function ChatBar_ReorderChannels()
	if UnitOnTaxi("player") then
		-- For some reason channels do not register join/leave in a reasonable amount of time while in transit.
		return;
	end
	
	local newChannelOrder = {};
	local openChannelIndex = 1;
	local currIdentifier, simpleName, inGlobalComm, _;
	
	--Get Channel List
	local list = {GetChannelList()};
	local currChannelList = {};
	for i=1, #list, 2 do
		tinsert(currChannelList, tonumber(list[i]), list[i+1]);
	end
	
	-- Find current standard channels: store and leave
	for index, chanName in pairs(currChannelList) do
		if type(chanName) == "string" then
			_, _, simpleName = strfind(chanName, "(%w+).*");
			if STANDARD_CHANNEL_ORDER[simpleName] then
				if ( simpleName == "GlobalComm" ) then 
					inGlobalComm = true;
				else
					newChannelOrder[STANDARD_CHANNEL_ORDER[simpleName]] = simpleName;
				end
				LeaveChannelByName(chanName);
				currChannelList[index] = nil;
			end
		end
	end
	
	-- Find current non-standard channels: store and leave
	for index, chanName in pairs(currChannelList) do
		if type(chanName) == "string" then
			while newChannelOrder[openChannelIndex] do
				openChannelIndex = openChannelIndex + 1;
			end
			newChannelOrder[openChannelIndex] = chanName;
			LeaveChannelByName(chanName);
			openChannelIndex = openChannelIndex + 1;
		end
	end
	
	if inGlobalComm then
		while newChannelOrder[openChannelIndex] do
			openChannelIndex = openChannelIndex + 1;
		end
		newChannelOrder[openChannelIndex] = "GlobalComm";
	end
	
	Chronos.schedule(.6, ChatBar_joinChannelsInOrder, newChannelOrder);
	Chronos.schedule(1.2, function() end );
	Chronos.schedule(2, ListChannels );
end

function ChatBar_joinChannelsInOrder(newChannelOrder)
	
	local inACity = CHATBAR_CAPITAL_CITIES[GetRealZoneText()];
	
	-- Join channels in new order
	for i=1, 10 do
		if newChannelOrder[i] then
			if ChannelManager_CustomChannelPasswords and ChannelManager_CustomChannelPasswords[newChannelOrder[i]] then
				JoinChannelByName(newChannelOrder[i], ChannelManager_CustomChannelPasswords[newChannelOrder[i]]);
			else
				JoinChannelByName(newChannelOrder[i]);
			end
		else
			-- Allow for hidden trade channel (Unfortunetly if you're not in a city and aren't in trade then numbers will be slightly off)
			if inACity or STANDARD_CHANNEL_ORDER[CHATBAR_TRADE] ~= i then
				JoinChannelByName(BOGUS_CHANNELS[i]);
			end
		end
	end
	Chronos.schedule(.6, ChatBar_leaveExtraChannels, newChannelOrder );
end

function ChatBar_leaveExtraChannels(newChannelOrder)
	
	for i, bogusName in ipairs(BOGUS_CHANNELS) do
		local channelNum, channelName = GetChannelName(bogusName);
		if channelName then
			LeaveChannelByName(channelNum);
		end
	end

end


