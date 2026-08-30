local E = unpack(_G.SarychUI_Bags)
local TT = E:GetModule("Tooltip")

local DEBUG_ELVUI_BAGS = false

local function bagDebug(...)
	if not DEBUG_ELVUI_BAGS then return end
	local prefix = (SarychUI and SarychUI.GetScopedChatPrefix and SarychUI:GetScopedChatPrefix("Bags")) or "|cffffd200SarychUI Bags:|r"
	print(prefix, ...)
end

-- Scoped stub: SarychUI_Bags does not override global GameTooltip anchoring.
function TT:GameTooltip_SetDefaultAnchor(tt, parent)
	if not tt then return end
	bagDebug("GameTooltip_SetDefaultAnchor noop", parent and parent.GetName and parent:GetName() or parent)
end
