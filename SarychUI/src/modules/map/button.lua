-- SarychUI Maps: Mapster-style options button is intentionally not shown.
-- Map settings live in SarychUI -> Карта.

local Maps = SarychUI.Maps
local button = Maps:RegisterComponent("button", {})

local function hideLeftover()
	local leftover = _G.SarychUIMapOptionsButton
	if leftover then
		leftover:Hide()
	end
end

function button:UpdateMapSize()
end

function button:Enable()
	hideLeftover()
end

function button:Disable()
	hideLeftover()
end

function button:Refresh()
	hideLeftover()
end

return button
