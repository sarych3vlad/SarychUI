-- SarychUI Maps: cursor and player coordinates on the world map.
-- Layout numbers match Mapster so the labels sit where they did before.

local Maps = SarychUI.Maps
local Api = Maps.Api
local L = SarychUI.L

local coords = Maps:RegisterComponent("coords", {})

local display, cursorText, playerText
local textFormat = "%%s: %%.%df, %%.%df"
local text

local function accuracy()
	return tonumber(Maps:Get("coordAccuracy")) or 1
end

local function rebuildFormat()
	local acc = accuracy()
	if acc < 0 then acc = 0 end
	if acc > 2 then acc = 2 end
	text = textFormat:format(acc, acc)
end

function coords:UpdateMapSize(windowed)
	if not cursorText then
		return
	end
	if windowed then
		cursorText:SetPoint("BOTTOMLEFT", WorldMapPositioningGuide, "BOTTOM", 15, -2)
		playerText:SetPoint("BOTTOMRIGHT", WorldMapPositioningGuide, "BOTTOM", -30, -2)
	else
		cursorText:SetPoint("BOTTOMLEFT", WorldMapPositioningGuide, "BOTTOM", 50, 10)
		playerText:SetPoint("BOTTOMRIGHT", WorldMapPositioningGuide, "BOTTOM", -50, 10)
	end
end

local function onUpdate()
	if not Maps:IsActive() or Maps:Get("showCoords") == false then
		if cursorText then cursorText:SetText("") end
		if playerText then playerText:SetText("") end
		return
	end

	local cursor = L and L["Map Cursor"] or "Курсор"
	local player = L and L["Map Player"] or "Игрок"

	local cx, cy = Api:GetCursorPosition()
	if cx and cx >= 0 and cx <= 1 and cy and cy >= 0 and cy <= 1 then
		cursorText:SetFormattedText(text, cursor, 100 * cx, 100 * cy)
	else
		cursorText:SetText("")
	end

	local px, py = Api:GetPlayerPosition()
	if not px then
		playerText:SetText("")
	else
		playerText:SetFormattedText(text, player, 100 * px, 100 * py)
	end
end

local function setCoordsRunning(running)
	if not display then
		return
	end
	if running then
		display:SetScript("OnUpdate", onUpdate)
		display:Show()
	else
		display:SetScript("OnUpdate", nil)
		display:Hide()
		if cursorText then cursorText:SetText("") end
		if playerText then playerText:SetText("") end
	end
end

function coords:BorderVisibilityChanged(visible)
	setCoordsRunning(visible and Maps:Get("showCoords") ~= false)
end

function coords:Enable()
	if not display then
		display = CreateFrame("Frame", nil, WorldMapFrame)
		cursorText = display:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		playerText = display:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		self:UpdateMapSize(Maps.windowed)
	end
	rebuildFormat()
	setCoordsRunning(Maps.bordersVisible ~= false and Maps:Get("showCoords") ~= false)
end

function coords:Disable()
	setCoordsRunning(false)
end

function coords:Refresh()
	rebuildFormat()
	self:UpdateMapSize(Maps.windowed)
	setCoordsRunning(Maps:Get("showCoords") ~= false and Maps.bordersVisible ~= false)
end

return coords
