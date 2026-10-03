-- Enhanced Raid Frames is a World of Warcraft® user interface addon.
-- Copyright (c) 2017-2023 Britt W. Yazel
-- This code is licensed under the MIT license (see LICENSE for details)

local L = LibStub("AceLocale-3.0"):NewLocale("EnhancedRaidFrames", "zhCN", false)

if not L then
	return
end

-------------------------------------------------------------------------
-------------------------------------------------------------------------

L["Aborting."] = "中止。"
L["Animations"] = "动画效果"
L["Attached to Cursor"] = "跟随鼠标游标"
L["Aura Watch List"] = "光环监视列表"
L["auras_desc"] = "在这里显示监视的增益、减益法术和“通配符”列表"
L["auras_usage"] = "法术 ID 或法术名字都可以，只要 ID 有效或名字拼写正确。"
L["Background Opacity"] = "背景透明度"
L["backgroundAlpha_desc"] = "团队框体的背景透明度。"
L["Blizzard Default"] = "暴雪默认位置"
L["curseWildcard_desc"] = "任何诅咒类型的减益"
L["customRange_desc"] = "取代默认的 40 码淡出距离。"
L["customRangeCheck_desc"] = "默认设置下，超过 40 码淡出框架，勾选此选项可以指定淡出距离。"
L["Data import Failed."] = "导入失败"
L["Decoding failed."] = "解析失败。"
L["Decompression failed."] = "解压失败。"
L["diseaseWildcard_desc"] = "任何疾病类型的减益"
L["Experimental"] = "实验性"
L["Experimental Options"] = "实验性选项"
L["Experimental_Options_Warning"] = [=[警告：这是实验性功能，可能有潜在危险。使用风险自负。
]=]
L["Export"] = "导出"
L["frameScale_desc"] = "团队框架相对于原始尺寸的比例，在原生设置的基础上额外调整缩放。"
L["Glow At Countdown Time"] = "高亮时间"
L["glowRemainingSecs_desc1"] = "设置当光环的持续时间剩馀 x 秒时，开始发亮。"
L["glowRemainingSecs_desc2"] = "0 代表总是高亮。"
L["Icon"] = "图标"
L["Icon and Visuals"] = "图标和外观"
L["Icon Opacity"] = "图标透明度"
L["Import"] = "导入"
L["Import or Export the current profile:"] = "导入或导出当前设置："
L["ImportExport_Desc"] = [=[这是以文本形式储存配置的 Enhanced Raid Frame 配置文件。全选并复制下列字符串即可导出你目前的配置档。若要导入新的配置档，请贴上新的字串，取代目前的内容，并按下接受。
]=]
L["ImportExport_WarningDesc"] = [=[复制贴上配置字符串可能导致你的游戏停顿数秒。警告：这将取代你目前的配置，丢失原配置的所有设置。
]=]
L["ImportWarning"] = "确定要导入配置吗？目前的配置会被取代。"
L["Indicator Color"] = "指示器颜色"
L["Indicator Font"] = "指示器字体"
L["Indicator Glow Effect"] = "指示器高亮动画"
L["Indicator Size"] = "指示器大小"
L["indicatorAlpha_desc"] = "指示器的图标透明度。"
L["indicatorColor_desc1"] = "使指示器不显示光环图标，而是显示指定颜色的纯色色块。"
L["indicatorColor_desc2"] = "除非额外指定，否则都将默认此颜色。"
L["indicatorFont_desc"] = "边角指示器使用的字体。"
L["indicatorGlow_desc"] = "替指示器显示一个发光动画效果。"
L["indicatorOptions_desc"] = "请在右侧的下拉菜单选择要调整哪个位置的边角指示器"
L["indicatorSize_desc"] = "指示器的光环图标大小，单位是像素。"
L["instructions_desc1"] = "请在右侧填入你要在这个边角指示器监视的光环。"
L["magicWildcard_desc"] = "任何魔法类型的减益"
L["meOnly_desc"] = "只在我自己的框体上显示这个指示器的光环"
L["Mine Only"] = "只显示我施放的"
L["mineOnly_desc"] = "只显示由我施放的光环。"
L["missingOnly_desc"] = "只在缺少该光环时显示。"
L["Out-of-Range"] = "距离过远，超出范围"
L["Out-of-Range Opacity"] = "距离过远淡出"
L["Override Default Distance"] = "取代默认距离"
L["poisonWildcard_desc"] = "任何毒药类型的减益"
L["Position"] = "位置"
L["Profile"] = "配置"
L["rangeAlpha_desc"] = "距离过远，超出范围时，团队框架的透明度。"
L["Select a Custom Distance"] = "指定距离"
L["Show Countdown Swipe"] = "显示转圈动画"
L["Show Icon"] = "显示图标"
L["Show On Me Only"] = "只显示我的"
L["Show Only if Missing"] = "只显示缺少"
L["Show Tooltip"] = "显示鼠标提示"
L["showCountdownSwipe_desc"] = "显示一个按持续时间比例转圈的动画。"
L["showIcon_desc1"] = "获得光环时，显示光环图标。"
L["showIcon_desc2"] = "如果取消，则显示一个色块。"
L["showTooltip_desc"] = "指向时显示鼠标提示。"
L["Text"] = "文字"
L["Text Color"] = "文字颜色"
L["textColor_desc1"] = "指示器上的文字颜色"
L["textColor_desc2"] = "除非额外指定，否则都将默认此颜色"
L["Tooltip Location"] = "鼠标提示位置"
L["tooltipLocation_desc"] = "指定鼠标提示显示的位置"
L["Tooltips"] = "鼠标提示"
L["Visibility and Behavior"] = "可见性"


