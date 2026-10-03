-- SarychUI Maps: corner scale handle for the detached world map window.
-- Behaviour and artwork match Mapster's Scale module.

local Maps = SarychUI.Maps
local LibWindow = LibStub("LibWindow-1.1")

local scalehandle = Maps:RegisterComponent("scalehandle", {})

local scaler, mousetracker
local SOS = {
	dist = 0,
	x = 0,
	y = 0,
	left = 0,
	top = 0,
	scale = 1,
}

local function getScaleDistance()
	local x, y = GetCursorPosition()
	local scale = SOS.EFscale or 1
	x = x / scale - SOS.left
	y = SOS.top - y / scale
	return sqrt(x * x + y * y)
end

local function onUpdate()
	local scale = getScaleDistance() / SOS.dist * SOS.scale
	if scale < 0.2 then
		scale = 0.2
	elseif scale > 1.5 then
		scale = 1.5
	end
	WorldMapFrame:SetScale(scale)

	local s = SOS.scale / WorldMapFrame:GetScale()
	WorldMapFrame:ClearAllPoints()
	WorldMapFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", SOS.x * s, SOS.y * s)
end

function scalehandle:UpdateMapSize(windowed)
	if not scaler then
		return
	end
	scaler:ClearAllPoints()
	if windowed then
		if Maps.bordersVisible ~= false then
			scaler:SetPoint("BOTTOMRIGHT", -23, -12)
		else
			scaler:SetPoint("BOTTOMRIGHT", -26, 16)
		end
	else
		if Maps.bordersVisible ~= false then
			scaler:SetPoint("BOTTOMRIGHT", -4, 4)
		else
			scaler:SetPoint("BOTTOMRIGHT", -7, 32)
		end
	end
end

function scalehandle:BorderVisibilityChanged()
	self:UpdateMapSize(Maps.windowed)
end

function scalehandle:Enable()
	if not scaler then
		scaler = WorldMapPositioningGuide:CreateTexture(nil, "OVERLAY")
		scaler:SetWidth(20)
		scaler:SetHeight(20)
		scaler:SetTexture([[Interface\BUTTONS\UI-AutoCastableOverlay]])
		scaler:SetTexCoord(0.619, 0.760, 0.612, 0.762)
		scaler:SetDesaturated(true)

		mousetracker = CreateFrame("Frame", nil, WorldMapPositioningGuide)
		mousetracker:SetFrameStrata("TOOLTIP")
		mousetracker:SetAllPoints(scaler)
		mousetracker:EnableMouse(true)
		mousetracker:SetScript("OnEnter", function()
			scaler:SetDesaturated(false)
		end)
		mousetracker:SetScript("OnLeave", function()
			scaler:SetDesaturated(true)
		end)
		mousetracker:SetScript("OnMouseUp", function(self)
			if not Maps:Get("resetLayout") then
				LibWindow.SavePosition(WorldMapFrame)
			end
			self:SetScript("OnUpdate", nil)
			self:SetAllPoints(scaler)
			if Maps.worldmap and Maps.worldmap.ShowBlobs then
				Maps.worldmap:ShowBlobs()
			end
		end)
		mousetracker:SetScript("OnMouseDown", function(self)
			if Maps.worldmap and Maps.worldmap.HideBlobs then
				Maps.worldmap:HideBlobs()
			end
			SOS.left, SOS.top = WorldMapFrame:GetLeft(), WorldMapFrame:GetTop()
			SOS.scale = WorldMapFrame:GetScale()
			SOS.x, SOS.y = SOS.left, SOS.top - (UIParent:GetHeight() / SOS.scale)
			SOS.EFscale = WorldMapFrame:GetEffectiveScale()
			SOS.dist = getScaleDistance()
			if SOS.dist == 0 then
				SOS.dist = 1
			end
			self:SetScript("OnUpdate", onUpdate)
			self:SetAllPoints(UIParent)
		end)

		tinsert(Maps.worldmap.elementsToHide, scaler)
	end

	self:UpdateMapSize(Maps.windowed)
	scaler:Show()
	mousetracker:Show()
end

function scalehandle:Disable()
	if scaler then
		scaler:Hide()
	end
	if mousetracker then
		mousetracker:Hide()
	end
end

function scalehandle:Refresh()
	self:UpdateMapSize(Maps.windowed)
end

return scalehandle
