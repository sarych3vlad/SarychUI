-- Позиция
_G["CentrY"] = 47
_G["CastX"] = 50 -- справа от controlFrame
_G["CastY"] = 0
_G["RightX"] = 5
_G["RightY"] = -10
_G["OtherX"] = 35 -- справа от mobilityFrame
_G["OtherY"] = 0
_G["PlayerOffsetY"] = -7 -- расстояние между CONTROL/CAST и PLAYER фреймами

-- Размеры
_G["ICON_SIZE_CONTROL"] = 46 -- controlFrame по центру
_G["ICON_SIZE_CAST"] = 46 -- castFrame справа от controlFrame
_G["ICON_SIZE_MOBILITY"] = 30 -- mobilityFrame справа
_G["ICON_SIZE_OTHER"] = 30 -- otherFrame рядом с mobilityFrame
_G["PLAYER_ICON_SPACING"] = 2 -- расстояние между иконками способностей игрока
_G["PLAYER_ALT_RIGHT"] = false -- способности игрока справа над «прочие»/«рывки», по 2 в ряд
_G["ICON_SIZE_PLAYER"] = 28 -- playerFrame под основным
_G["ICON_SIZE_PLAYER_WIDTH"] = 30 -- ширина иконок playerFrame
_G["ICON_SIZE_PLAYER_HEIGHT"] = 20 -- высота иконок playerFrame

-- Количество отображаемых аур
_G["MAX_PLAYER_AURAS"] = 6
_G["MAX_AURAS"] = 1

-- 3 желтый
-- 4 фиолетовый
-- 5 синий
_G["SPELL_DATA"] = SarychUI.Data.AuraTracking:CreateView("nameplates")