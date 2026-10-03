-- Enhanced Raid Frames is a World of Warcraft® user interface addon.
-- Copyright (c) 2017-2023 Britt W. Yazel
-- This code is licensed under the MIT license (see LICENSE for details)

local L = LibStub("AceLocale-3.0"):NewLocale("EnhancedRaidFrames", "zhTW", false)

if not L then
	return
end

-------------------------------------------------------------------------
-------------------------------------------------------------------------

L["Aborting."] = "中止。"
L["Animations"] = "動畫效果"
L["Attached to Cursor"] = "跟隨滑鼠游標"
L["Aura Watch List"] = "光環列表"
L["auras_usage"] = "法術 ID 或法術名字都可以。"
L["Background Opacity"] = "背景透明度"
L["backgroundAlpha_desc"] = "團隊框架的背景透明度。"
L["Blizzard Default"] = "暴雪預設位置"
L["curseWildcard_desc"] = "任何詛咒減益"
L["customRange_desc"] = "預設超過 40 碼淡出框架，勾選此選項可以指定淡出距離。"
L["customRangeCheck_desc"] = "指定淡出距離。"
L["Data import Failed."] = "匯入失敗。"
L["Decoding failed."] = "解析失敗。"
L["Decompression failed."] = "解壓失敗。"
L["diseaseWildcard_desc"] = "任何疾病減益"
L["Experimental"] = "實驗性"
L["Experimental Options"] = "實驗性選項"
L["Experimental_Options_Warning"] = "警告：這是實驗性功能，可能有潛在危險。使用風險自負。"
L["Export"] = "匯出"
L["frameScale_desc"] = "基於原本的框架大小，額外調整縮放。"
L["Glow At Countdown Time"] = "高亮時間"
L["glowRemainingSecs_desc1"] = "設定當光環的持續時間剩餘 x 秒時，開始發亮。"
L["glowRemainingSecs_desc2"] = "0 代表總是高亮。"
L["Icon"] = "圖示"
L["Icon and Visuals"] = "圖示與外觀"
L["Icon Opacity"] = "圖示透明度"
L["Import"] = "匯入"
L["Import or Export the current profile:"] = "匯入或匯出目前設定檔："
L["ImportExport_Desc"] = [=[這是以文本形式儲存設定值的 Enhanced Raid Frame 設定檔。全選並複製下列字串即可匯出你目前的設定檔。若要匯入新的設定檔，請貼上新的字串，取代目前的內容，並按下接受。
]=]
L["ImportExport_WarningDesc"] = [=[複製貼上設定檔可能導致你的遊戲停頓數秒。警告：這將取代你目前的設定檔，丟失原設定檔的所有設定值。
]=]
L["ImportWarning"] = "你確定要匯入設定檔嗎？目前的設定檔會被取代。"
L["Indicator Color"] = "指示器顏色"
L["Indicator Font"] = "指示器字型"
L["Indicator Glow Effect"] = "指示器高亮動畫"
L["Indicator Size"] = "光環大小"
L["indicatorAlpha_desc"] = "指示器的圖示透明度。"
L["indicatorColor_desc1"] = "使指示器不顯示光環圖示，而是顯示指定顏色的純色色塊。"
L["indicatorColor_desc2"] = "除非額外指定，否則都將預設此顏色。"
L["indicatorFont_desc"] = "邊角指示器使用的字型。"
L["indicatorGlow_desc"] = "替指示器顯示一個發光動畫效果。"
L["indicatorOptions_desc"] = "請在右側的下拉選單選擇要調整哪個位置的邊角指示器"
L["indicatorSize_desc"] = "指示器顯示的光環大小，單位是像素。"
L["instructions_desc1"] = "請在右側填入你要在這個邊角指示器監視的光環。"
L["magicWildcard_desc"] = "任何魔法減益"
L["meOnly_desc"] = "只顯示我獲得的光環"
L["Mine Only"] = "只顯示我施放的"
L["mineOnly_desc"] = "只顯示由我施放的光環"
L["missingOnly_desc"] = "只在缺少該光環時顯示"
L["Out-of-Range"] = "距離過遠，超出範圍"
L["Out-of-Range Opacity"] = "距離過遠透明度"
L["Override Default Distance"] = "取代預設距離"
L["poisonWildcard_desc"] = "任何毒藥減益"
L["Position"] = "位置"
L["Profile"] = "設定檔"
L["rangeAlpha_desc"] = "距離過遠，超出範圍時，團隊框架的淡出透明度。"
L["Select a Custom Distance"] = "指定距離"
L["Show Countdown Swipe"] = "顯示轉圈動畫"
L["Show Icon"] = "顯示圖示"
L["Show On Me Only"] = "只顯示我的"
L["Show Only if Missing"] = "只顯示缺少"
L["Show Tooltip"] = "顯示滑鼠提示"
L["showCountdownSwipe_desc"] = "顯示按持續時間比例轉圈的動畫。"
L["showIcon_desc1"] = "獲得光環時，顯示光環圖示。"
L["showIcon_desc2"] = "如果取消，則顯示一個色塊。"
L["showTooltip_desc"] = "指向時顯示滑鼠提示。"
L["Text"] = "文字"
L["Text Color"] = "文字顏色"
L["textColor_desc1"] = "指示器上的文字顏色"
L["textColor_desc2"] = "除非額外指定，否則都將預設此顏色。"
L["Tooltip Location"] = "滑鼠提示位置"
L["tooltipLocation_desc"] = "指定滑鼠提示顯示的位置。"
L["Tooltips"] = "滑鼠提示"
L["Visibility and Behavior"] = "可見性"


