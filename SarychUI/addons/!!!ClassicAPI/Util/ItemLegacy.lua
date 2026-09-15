--[[
	ClassicAPI 1.27 keeps these under C_Item only. Addons bundled with SarychUI
	(InternalCooldowns, SarychUI bag sorting) still call the plain globals.
]]

local C_Item = C_Item

_G.GetItemInfoInstant = C_Item.GetItemInfoInstant
_G.GetItemSubClassInfo = C_Item.GetItemSubClassInfo
_G.GetItemInventorySlotInfo = C_Item.GetItemInventorySlotInfo
