local module = SarychUI.WoWCircle
local L = SarychUI.L
local function DB() return module:GetDB() end
local function toggleGetter(info)
 local value = DB()[info[#info]]
 return value == 1 or value == true
end
local function Refresh() SarychUI:NotifySarychUIOptionsChange() end
function module:GetOptions()
 local body = {
						type = "group",
						name = "Функции WoWCircle",
						order = 1,
						inline = true,
						args = {
							enableCircleContextMenu = {
								type = "toggle",
								name = L and (L["Enable_Chat_Circle_Menu"] or "[WoWCircle] |TInterface\\ChatFrame\\UI-ChatIcon-Chat-Up:14:14|t Дополнительные VIP команды при нажатии ПКМ") or "[WoWCircle] |TInterface\\ChatFrame\\UI-ChatIcon-Chat-Up:14:14|t Дополнительные VIP команды при нажатии ПКМ",
								desc = L and (L["Enable_Chat_Circle_Menu_Desc"] or "Включить дополнительные VIP команды при нажатии правой кнопки мыши") or "Включить дополнительные VIP команды при нажатии правой кнопки мыши",
								order = 1,
								width = "full",
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableCircleContextMenu = val and 1 or 0
									if module and module.ApplyVipCommands then
										module:ApplyVipCommands()
									end
									Refresh()
								end,
							},
							ppMessageFixEnabled = {
								type = "toggle",
								name = L and (L["Enable_PP_Message_Fix"] or "[WoWCircle] Фикс \"|cFFFFD700Обмениваться личными сообщениями можно только с союзниками.|r\" для ПП") or "[WoWCircle] Фикс \"|cFFFFD700Обмениваться личными сообщениями можно только с союзниками.|r\" для ПП",
								desc = L and (L["Enable_PP_Message_Fix_Desc"] or "Включить исправление сообщения \"Обмениваться личными сообщениями можно только с союзниками.\" для ПП") or "Включить исправление сообщения \"Обмениваться личными сообщениями можно только с союзниками.\" для ПП",
								order = 2,
								width = "full",
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.ppMessageFixEnabled = val and 1 or 0
									if module and module.ApplyPpMessageFix then
										module:ApplyPpMessageFix()
									end
									Refresh()
								end,
							},
							spamFilterCombatDifficulty = {
								type = "toggle",
								name = "[WoWCircle] Скрыть сообщения информации после боя",
								desc = "Скрывать сообщения о сложности боя, времени боя, iLvl и PvE очках после битвы с боссами",
								order = 3,
								width = "full",
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.spamFilterCombatDifficulty = val and 1 or 0
									if module and module.ApplyWoWCircleSystemFilter then
										module:ApplyWoWCircleSystemFilter()
									end
									Refresh()
								end,
							},
						},
					}
 body.order = 1
 body.suiTwoCol = true
 return { type="group", name="WoWCircle", args={
  enabled={type="toggle",name="Включить",order=0,
   get=function() return DB().enabled ~= false end,
   set=function(_,value)
    DB().enabled=value and true or false
    if value then module:Enable() else module:Disable() end
    if SarychUI.OptionsCore then SarychUI.OptionsCore:ScheduleSmartRefresh(true) end
   end},
  settings=body,
 }, suiBodyDisabled=function() return DB().enabled == false end }
end
