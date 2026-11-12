-- SarychUI Maps: zone information on the world map.
-- Recommended level, fishing skill, instances and faction colour - the
-- functionality Cromulent provided, driven by LibTourist-3.0 already loaded
-- with SarychUI. A single profile toggle (zoneInfo) turns the whole block off.

local Maps = SarychUI.Maps
local L = SarychUI.L
local zoneinfo = Maps:RegisterComponent("zoneinfo", {})

local T = LibStub and LibStub("LibTourist-3.0", true)

local string_format = string.format
local string_gsub = string.gsub
local table_concat = table.concat
local table_insert = table.insert
local table_wipe = table.wipe

local frame
local lastZone
local t = {}
local fishingSpell
local hooked = false

local function enabled()
	return Maps:IsActive() and Maps:Get("zoneInfo") ~= false and T ~= nil
end

local function localeText(key, fallback)
	if L and L[key] then
		return L[key]
	end
	return fallback
end

function zoneinfo:Clear()
	if frame and frame.text then
		frame.text:SetText("")
	end
	if WorldMapFrameAreaLabel then
		WorldMapFrameAreaLabel:SetTextColor(1, 1, 1)
	end
	lastZone = nil
end

local function onUpdate()
	if not enabled() then
		if frame then
			frame.text:SetText("")
		end
		return
	end
	if not frame then
		return
	end
	if not WorldMapDetailFrame:IsShown() or not WorldMapFrameAreaLabel:IsShown() then
		frame.text:SetText("")
		lastZone = nil
		return
	end

	local underAttack = false
	local zone = WorldMapFrameAreaLabel:GetText()
	if zone then
		zone = string_gsub(zone, " |cff.+$", "")
		if WorldMapFrameAreaDescription:GetText() then
			underAttack = true
			zone = string_gsub(WorldMapFrameAreaDescription:GetText(), " |cff.+$", "")
		end
	end

	if GetCurrentMapContinent() == 0 then
		local c1, c2 = GetMapContinents()
		if zone == c1 or zone == c2 then
			WorldMapFrameAreaLabel:SetTextColor(1, 1, 1)
			frame.text:SetText("")
			return
		end
	end

	if not zone or not T:IsZoneOrInstance(zone) then
		zone = WorldMapFrame.areaName
	end
	WorldMapFrameAreaLabel:SetTextColor(1, 1, 1)

	if zone and (T:IsZoneOrInstance(zone) or T:DoesZoneHaveInstances(zone)) then
		if not underAttack then
			WorldMapFrameAreaLabel:SetTextColor(T:GetFactionColor(zone))
			WorldMapFrameAreaDescription:SetTextColor(1, 1, 1)
		else
			WorldMapFrameAreaLabel:SetTextColor(1, 1, 1)
			WorldMapFrameAreaDescription:SetTextColor(T:GetFactionColor(zone))
		end

		local low, high = T:GetLevel(zone)
		local minFish = T:GetFishingLevel(zone)
		local fishingSkillText
		if minFish and fishingSpell then
			for i = 1, GetNumSkillLines() do
				local skillName, _, _, skillRank = GetSkillLineInfo(i)
				if skillName == fishingSpell then
					local r1, g1, b1 = 1, 0, 0
					if minFish < skillRank then
						r1, g1, b1 = 0, 1, 0
					end
					fishingSkillText = string_format("|cffffff00%s|r |cff%02x%02x%02x[%d]|r",
						fishingSpell, r1 * 255, g1 * 255, b1 * 255, minFish)
					break
				end
			end
		end

		if low > 0 and high > 0 then
			local r, g, b = T:GetLevelColor(zone)
			local levelText
			if low == high then
				levelText = string_format(" |cff%02x%02x%02x[%d]|r", r * 255, g * 255, b * 255, high)
			else
				levelText = string_format(" |cff%02x%02x%02x[%d-%d]|r", r * 255, g * 255, b * 255, low, high)
			end
			local groupSize = T:GetInstanceGroupSize(zone)
			local sizeText = ""
			if groupSize > 0 then
				sizeText = " " .. string_format(localeText("%d-man", "%d-чел."), groupSize)
			end
			if not underAttack then
				local label = WorldMapFrameAreaLabel:GetText() or ""
				WorldMapFrameAreaLabel:SetText(string_gsub(label, " |cff.+$", "") .. levelText .. sizeText)
			else
				local desc = WorldMapFrameAreaDescription:GetText() or ""
				WorldMapFrameAreaDescription:SetText(string_gsub(desc, " |cff.+$", "") .. levelText .. sizeText)
			end
		end

		if T:DoesZoneHaveInstances(zone) then
			if lastZone ~= zone then
				lastZone = zone
				table_insert(t, string_format("|cffffff00%s:|r", localeText("Instances", "Подземелья")))
				for instance in T:IterateZoneInstances(zone) do
					local complex = T:GetComplex(instance)
					local ilow, ihigh = T:GetLevel(instance)
					local r1, g1, b1 = T:GetFactionColor(instance)
					local r2, g2, b2 = T:GetLevelColor(instance)
					local groupSize = T:GetInstanceGroupSize(instance)
					local name = instance
					if complex then
						name = complex .. " - " .. instance
					end
					if ilow == ihigh then
						if groupSize > 0 then
							table_insert(t, string_format("|cff%02x%02x%02x%s|r |cff%02x%02x%02x[%d]|r " .. localeText("%d-man", "%d-чел."),
								r1 * 255, g1 * 255, b1 * 255, name, r2 * 255, g2 * 255, b2 * 255, ihigh, groupSize))
						else
							table_insert(t, string_format("|cff%02x%02x%02x%s|r |cff%02x%02x%02x[%d]|r",
								r1 * 255, g1 * 255, b1 * 255, name, r2 * 255, g2 * 255, b2 * 255, ihigh))
						end
					else
						if groupSize > 0 then
							table_insert(t, string_format("|cff%02x%02x%02x%s|r |cff%02x%02x%02x[%d-%d]|r " .. localeText("%d-man", "%d-чел."),
								r1 * 255, g1 * 255, b1 * 255, name, r2 * 255, g2 * 255, b2 * 255, ilow, ihigh, groupSize))
						else
							table_insert(t, string_format("|cff%02x%02x%02x%s|r |cff%02x%02x%02x[%d-%d]|r",
								r1 * 255, g1 * 255, b1 * 255, name, r2 * 255, g2 * 255, b2 * 255, ilow, ihigh))
						end
					end
				end
				if minFish and fishingSkillText then
					table_insert(t, fishingSkillText)
				end
				frame.text:SetText(table_concat(t, "\n"))
				table_wipe(t)
			end
		else
			if fishingSkillText then
				frame.text:SetText(fishingSkillText)
			else
				frame.text:SetText("")
			end
			lastZone = nil
		end
	elseif not zone then
		lastZone = nil
		frame.text:SetText("")
	end
end

function zoneinfo:Enable()
	if not T then
		return
	end
	if not frame then
		frame = CreateFrame("Frame", nil, WorldMapFrame)
		frame.text = WorldMapFrameAreaFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
		local font, size = GameFontHighlightLarge:GetFont()
		frame.text:SetFont(font, size, "OUTLINE")
		frame.text:SetPoint("TOP", WorldMapFrameAreaDescription, "BOTTOM", 0, -5)
		frame.text:SetWidth(1024)
	end
	fishingSpell = GetSpellInfo(7620)
	frame:Show()

	if not hooked then
		hooked = true
		WorldMapButton:HookScript("OnUpdate", onUpdate)
	end
end

function zoneinfo:Disable()
	self:Clear()
	if frame then
		frame:Hide()
	end
end

function zoneinfo:Refresh()
	lastZone = nil
	if Maps:Get("zoneInfo") == false then
		self:Clear()
	end
end

return zoneinfo
