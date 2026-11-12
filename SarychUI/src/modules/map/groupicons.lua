-- SarychUI Maps: class-coloured party/raid icons on the world map.
-- Artwork and colour rules come from Mapster's GroupIcons module.

local Maps = SarychUI.Maps
local groupicons = Maps:RegisterComponent("groupicons", {})

local fmt = string.format
local sub = string.sub
local find = string.find

local path = Maps.MEDIA .. "group\\"
local grouptex = path .. "Group%d"

local RAID_CLASS_COLORS = RAID_CLASS_COLORS

local function updateUnitIcon(tex, unit)
	if not (tex and unit) then
		return
	end

	local _, fileName = UnitClass(unit)
	if not fileName then
		return
	end

	if find(unit, "raid", 1, true) then
		local _, _, subgroup = GetRaidRosterInfo(sub(unit, 5))
		if subgroup then
			tex:SetTexture(fmt(grouptex, subgroup))
		end
	end

	local t = RAID_CLASS_COLORS[fileName]
	if (GetTime() % 1) < 0.5 then
		if UnitAffectingCombat(unit) then
			tex:SetVertexColor(0.8, 0, 0)
		elseif UnitIsDeadOrGhost(unit) then
			tex:SetVertexColor(0.2, 0.2, 0.2)
		elseif PlayerIsPVPInactive and PlayerIsPVPInactive(unit) then
			tex:SetVertexColor(0.5, 0.2, 0.8)
		elseif t then
			tex:SetVertexColor(t.r, t.g, t.b)
		end
	elseif t then
		tex:SetVertexColor(t.r, t.g, t.b)
	else
		tex:SetVertexColor(0.8, 0.8, 0.8)
	end
end

local function onIconUpdate(self, elapsed)
	self.elapsed = (self.elapsed or 0.5) - elapsed
	if self.elapsed <= 0 then
		self.elapsed = 0.5
		updateUnitIcon(self.icon, self.unit)
	end
end

local function fixUnit(unit, state, isNormal)
	local frame = _G[unit]
	if not frame or not frame.icon then
		return
	end
	local icon = frame.icon
	if state then
		frame.elapsed = 0.5
		frame:SetScript("OnUpdate", onIconUpdate)
		if isNormal then
			icon:SetTexture(path .. "Normal")
		end
	else
		frame.elapsed = nil
		frame:SetScript("OnUpdate", nil)
		icon:SetVertexColor(1, 1, 1)
		icon:SetTexture("Interface\\WorldMap\\WorldMapPartyIcon")
	end
end

local function fixWorldMapUnits(state)
	for i = 1, 4 do
		fixUnit(fmt("WorldMapParty%d", i), state, true)
	end
	for i = 1, 40 do
		fixUnit(fmt("WorldMapRaid%d", i), state)
	end
end

function groupicons:UpdateUnit(frame, unit)
	if not frame or not frame.icon or not unit then
		return
	end
	updateUnitIcon(frame.icon, unit)
end

function groupicons:ResetUnit(frame)
	if not frame or not frame.icon then
		return
	end
	frame.icon:SetVertexColor(1, 1, 1)
	frame.icon:SetTexture("Interface\\WorldMap\\WorldMapPartyIcon")
end

function groupicons:Enable()
	if CUSTOM_CLASS_COLORS then
		RAID_CLASS_COLORS = CUSTOM_CLASS_COLORS
	end
	fixWorldMapUnits(true)
end

function groupicons:Disable()
	fixWorldMapUnits(false)
end

function groupicons:Refresh()
end

return groupicons
