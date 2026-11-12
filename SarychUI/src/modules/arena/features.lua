local module = SarychUI.modules.arena
-- Runtime owned by arena; legacy tools profile keys are preserved.
local moduleName = "tools"
local S = {}
local pairs, select, pcall = pairs, select, pcall

local floor, max, min = math.floor, math.max, math.min

local abs, sqrt, deg, atan2, ceil, cos, rad, sin, exp = math.abs, math.sqrt, math.deg, math.atan2, math.ceil, math.cos, math.rad, math.sin, math.exp

local format = string.format

local gsub, find, gmatch = string.gsub, string.find, string.gmatch

local function DB()
    if not SarychUI or not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules then
        return nil
    end
    return SarychUI.db.profile.modules[moduleName]
end


S.arenaPointerInitialized, S.arenaPointerTeams, S.arenaPointerInspectTeams = false, {}, {}

S.arenaPointerMeasureFont, S.arenaPointerInspectMeasureFont = nil, nil

S.old_PVPTeam_Update, S.old_InspectPVPTeam_Update = nil, nil

S.originalLabelPositions, S.originalInspectLabelPositions = {}, {}

local function getArenaPoints(rating, teamsize)
    local ratios = {
        [2] = 0.76,
        [3] = 0.88,
        [5] = 1,
    }
    local points
    if rating > 1500 then
        points = 1511.26 / (1 + 1639.28 * exp(-0.00412 * rating))
    else
        points = 0.22 * rating + 14
    end
    return floor(0.5 + points * ratios[teamsize])
end

local function IsArenaPointerEnabled()
    local db = DB()
    if not db then return false end
    return db.enableArenaPointer == 1
end

function SarychUI.modules.arena:ApplyArenaPointer()
    local ownerDB = SarychUI.db.profile.modules.arena
    if ownerDB and ownerDB.enabled == false then self:DisableArenaPointer(); return end
    local db = DB()
    if not db then return end

    -- Check if module is enabled
    local moduleDb = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not moduleDb or not moduleDb.enabled then
        if S.arenaPointerInitialized then
            SarychUI.modules.arena:DisableArenaPointer()
        end
        return
    end

    if db.enableArenaPointer == 1 then
        -- Enable if not already enabled
        if not S.arenaPointerInitialized then
            SarychUI.modules.arena:EnableArenaPointer()
        end
    else
        -- Disable if enabled
        if S.arenaPointerInitialized then
            SarychUI.modules.arena:DisableArenaPointer()
        end
    end
end

function SarychUI.modules.arena:EnableArenaPointer()
    if S.arenaPointerInitialized then return end -- Already enabled

    -- Check if enabled
    if not IsArenaPointerEnabled() then return end

    -- Save original label positions before modifying
    for i = 1, 3 do
        local ratingLabel = _G["PVPTeam"..i.."DataRatingLabel"]
        if ratingLabel then
            local point, relativeTo, relativePoint, xOfs, yOfs = ratingLabel:GetPoint()
            if point then
                S.originalLabelPositions[i] = {
                    point = point,
                    relativeTo = relativeTo,
                    relativePoint = relativePoint,
                    xOfs = xOfs or 0,
                    yOfs = yOfs or 0
                }
            end
        end
    end

    -- Save original inspect label positions
    if InspectPVPTeam1DataRatingLabel then
        for i = 1, 3 do
            local ratingLabel = _G["InspectPVPTeam"..i.."DataRatingLabel"]
            if ratingLabel then
                local point, relativeTo, relativePoint, xOfs, yOfs = ratingLabel:GetPoint()
                if point then
                    S.originalInspectLabelPositions[i] = {
                        point = point,
                        relativeTo = relativeTo,
                        relativePoint = relativePoint,
                        xOfs = xOfs or 0,
                        yOfs = yOfs or 0
                    }
                end
            end
        end
    end

    -- Create measure font for PVP teams
    if not S.arenaPointerMeasureFont then
        S.arenaPointerMeasureFont = UIParent:CreateFontString(nil, "ARTWORK")
        S.arenaPointerMeasureFont:Hide()
    end

    -- Hook PVPTeam_Update
    if not S.old_PVPTeam_Update then
        S.old_PVPTeam_Update = PVPTeam_Update
        PVPTeam_Update = function(...)
            S.old_PVPTeam_Update(...)

            -- Check if still enabled
            if not IsArenaPointerEnabled() then return end

            -- Collect team sizes
            for i = 1, 3 do
                local teamName, teamSize = GetArenaTeam(i)
                if teamName then
                    S.arenaPointerTeams[teamName] = tonumber(teamSize)
                end
            end

            -- Add points to rating
            for i = 1, 3 do
                local rating = tonumber(_G["PVPTeam"..i.."DataRating"]:GetText())
                if rating then
                    local teamname = _G["PVPTeam"..i.."DataName"]:GetText()
                    if not S.arenaPointerTeams[teamname] then
                        return
                    end
                    local points = getArenaPoints(rating, S.arenaPointerTeams[teamname])
                    local pointsText = (" (%d)"):format(points)
                    local fullText = rating..pointsText
                    _G["PVPTeam"..i.."DataRating"]:SetText(fullText)

                    -- Calculate width and shift label
                    local ratingLabel = _G["PVPTeam"..i.."DataRatingLabel"]
                    local ratingValue = _G["PVPTeam"..i.."DataRating"]
                    if ratingLabel and ratingValue then
                        -- Get font for measurement
                        local font, fontSize, fontFlags
                        if ratingValue.GetFont then
                            font, fontSize, fontFlags = ratingValue:GetFont()
                        end
                        if not font then
                            local labelFont = ratingLabel:GetFontString()
                            if labelFont then
                                font, fontSize, fontFlags = labelFont:GetFont()
                            end
                        end
                        if font then
                            S.arenaPointerMeasureFont:SetFont(font, fontSize, fontFlags)
                        else
                            S.arenaPointerMeasureFont:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
                        end

                        -- Measure full text width and set field width
                        S.arenaPointerMeasureFont:SetText(fullText)
                        local fullTextWidth = S.arenaPointerMeasureFont:GetStringWidth()
                        ratingValue:SetWidth(fullTextWidth + 10)

                        -- Measure added text width for label shift
                        S.arenaPointerMeasureFont:SetText(pointsText)
                        local textWidth = S.arenaPointerMeasureFont:GetStringWidth()

                        -- Shift label right by added text width
                        ratingLabel:ClearAllPoints()
                        ratingLabel:SetPoint("RIGHT", _G["PVPTeam"..i.."DataName"], "RIGHT", textWidth, 0)
                    end
                end
            end
        end
    end

    -- Hook InspectPVPTeam_Update if available
    if InspectPVPTeam_Update and not S.old_InspectPVPTeam_Update then
        S.old_InspectPVPTeam_Update = InspectPVPTeam_Update

        -- Create measure font for inspect teams
        if not S.arenaPointerInspectMeasureFont then
            S.arenaPointerInspectMeasureFont = UIParent:CreateFontString(nil, "ARTWORK")
            S.arenaPointerInspectMeasureFont:Hide()
        end

        InspectPVPTeam_Update = function(...)
            S.old_InspectPVPTeam_Update(...)

            -- Check if still enabled
            if not IsArenaPointerEnabled() then return end

            -- Clear inspect teams
            for k in pairs(S.arenaPointerInspectTeams) do
                S.arenaPointerInspectTeams[k] = nil
            end

            -- Collect team sizes
            for i = 1, 3 do
                local teamName, teamSize = GetInspectArenaTeamData(i)
                if teamName then
                    S.arenaPointerInspectTeams[teamName] = tonumber(teamSize)
                end
            end

            -- Add points to rating
            for i = 1, 3 do
                local rating = tonumber(_G["InspectPVPTeam"..i.."DataRating"]:GetText())
                if rating then
                    local teamname = _G["InspectPVPTeam"..i.."DataName"]:GetText()
                    if not S.arenaPointerInspectTeams[teamname] then
                        return
                    end
                    local points = getArenaPoints(rating, S.arenaPointerInspectTeams[teamname])
                    local pointsText = (" (%d)"):format(points)
                    local fullText = rating..pointsText
                    _G["InspectPVPTeam"..i.."DataRating"]:SetText(fullText)

                    -- Calculate width and shift label
                    local ratingLabel = _G["InspectPVPTeam"..i.."DataRatingLabel"]
                    local ratingValue = _G["InspectPVPTeam"..i.."DataRating"]
                    if ratingLabel and ratingValue then
                        -- Get font for measurement
                        local font, fontSize, fontFlags
                        if ratingValue.GetFont then
                            font, fontSize, fontFlags = ratingValue:GetFont()
                        end
                        if not font then
                            local labelFont = ratingLabel:GetFontString()
                            if labelFont then
                                font, fontSize, fontFlags = labelFont:GetFont()
                            end
                        end
                        if font then
                            S.arenaPointerInspectMeasureFont:SetFont(font, fontSize, fontFlags)
                        else
                            S.arenaPointerInspectMeasureFont:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
                        end

                        -- Measure full text width and set field width
                        S.arenaPointerInspectMeasureFont:SetText(fullText)
                        local fullTextWidth = S.arenaPointerInspectMeasureFont:GetStringWidth()
                        ratingValue:SetWidth(fullTextWidth + 10)

                        -- Measure added text width for label shift
                        S.arenaPointerInspectMeasureFont:SetText(pointsText)
                        local textWidth = S.arenaPointerInspectMeasureFont:GetStringWidth()

                        -- Shift label right by added text width
                        ratingLabel:ClearAllPoints()
                        ratingLabel:SetPoint("RIGHT", _G["InspectPVPTeam"..i.."DataName"], "RIGHT", textWidth, 0)
                    end
                end
            end
        end
    end

    S.arenaPointerInitialized = true
end

function SarychUI.modules.arena:DisableArenaPointer()
    if not S.arenaPointerInitialized then return end

    -- Restore original functions first
    local restoredPVPTeam_Update = nil
    local restoredInspectPVPTeam_Update = nil

    if S.old_PVPTeam_Update then
        restoredPVPTeam_Update = S.old_PVPTeam_Update
        PVPTeam_Update = S.old_PVPTeam_Update
        S.old_PVPTeam_Update = nil
    end

    if S.old_InspectPVPTeam_Update then
        restoredInspectPVPTeam_Update = S.old_InspectPVPTeam_Update
        InspectPVPTeam_Update = S.old_InspectPVPTeam_Update
        S.old_InspectPVPTeam_Update = nil
    end

    -- Restore text, width, and label positions
    for i = 1, 3 do
        local ratingLabel = _G["PVPTeam"..i.."DataRatingLabel"]
        local ratingValue = _G["PVPTeam"..i.."DataRating"]
        if ratingLabel and ratingValue then
            -- Remove text in parentheses
            local currentText = ratingValue:GetText()
            if currentText then
                local ratingText = currentText:gsub("%s*%(%d+%)", ""):match("^%s*(%d+)%s*$")
                if ratingText then
                    local rating = tonumber(ratingText)
                    if rating then
                        ratingValue:SetText(tostring(rating))
                    end
                end
            end

            -- Restore original label position
            if S.originalLabelPositions[i] then
                local pos = S.originalLabelPositions[i]
                ratingLabel:ClearAllPoints()
                ratingLabel:SetPoint(pos.point, pos.relativeTo, pos.relativePoint, pos.xOfs, pos.yOfs)
            end

            -- Restore original width (90 pixels)
            ratingValue:SetWidth(90)
        end
    end

    -- Restore Inspect PVP teams text, width, and label positions
    if InspectPVPTeam1DataRating then
        for i = 1, 3 do
            local ratingLabel = _G["InspectPVPTeam"..i.."DataRatingLabel"]
            local ratingValue = _G["InspectPVPTeam"..i.."DataRating"]
            if ratingLabel and ratingValue then
                -- Remove text in parentheses
                local currentText = ratingValue:GetText()
                if currentText then
                    local ratingText = currentText:gsub("%s*%(%d+%)", ""):match("^%s*(%d+)%s*$")
                    if ratingText then
                        local rating = tonumber(ratingText)
                        if rating then
                            ratingValue:SetText(tostring(rating))
                        end
                    end
                end

                -- Restore original label position
                if S.originalInspectLabelPositions[i] then
                    local pos = S.originalInspectLabelPositions[i]
                    ratingLabel:ClearAllPoints()
                    ratingLabel:SetPoint(pos.point, pos.relativeTo, pos.relativePoint, pos.xOfs, pos.yOfs)
                end

                -- Restore original width (90 pixels)
                ratingValue:SetWidth(90)
            end
        end
    end

    -- Clean up measure fonts
    if S.arenaPointerMeasureFont then
        S.arenaPointerMeasureFont:Hide()
        S.arenaPointerMeasureFont = nil
    end

    if S.arenaPointerInspectMeasureFont then
        S.arenaPointerInspectMeasureFont:Hide()
        S.arenaPointerInspectMeasureFont = nil
    end

    -- Clear teams
    S.arenaPointerTeams = {}
    S.arenaPointerInspectTeams = {}

    -- Clear saved positions
    S.originalLabelPositions = {}
    S.originalInspectLabelPositions = {}

    -- Call original update functions to ensure everything is properly restored
    if restoredPVPTeam_Update then
        restoredPVPTeam_Update()
    end

    if restoredInspectPVPTeam_Update then
        restoredInspectPVPTeam_Update()
    end

    S.arenaPointerInitialized = false
end

local scoreboardHooked = false

local function ScoreboardClassNamesOn()
	local db = DB()
	if not db or db.enabled ~= true then return false end
	return db.enablePvpScoreboardClassNames == 1 or db.enablePvpScoreboardClassNames == true
end

local function ColorScoreBoard()
	if not ScoreboardClassNamesOn() then return end
	local _, instanceType = IsInInstance()
	if instanceType ~= "pvp" and instanceType ~= "arena" then
		return
	end
	-- Buttons are a fixed window (MAX_WORLDSTATE_SCORE_BUTTONS); scroll offset
	-- maps button i -> GetBattlefieldScore(offset + i). Using raw i re-paints
	-- page-1 names onto scrolled rows (icons/stats stay on the real players).
	local maxButtons = MAX_WORLDSTATE_SCORE_BUTTONS or 20
	local offset = 0
	if FauxScrollFrame_GetOffset and WorldStateScoreScrollFrame then
		offset = FauxScrollFrame_GetOffset(WorldStateScoreScrollFrame) or 0
	end
	local numScores = GetNumBattlefieldScores and GetNumBattlefieldScores() or 0
	local playerName = UnitName("player")
	local isArena = instanceType == "arena"
	for i = 1, maxButtons do
		local fs = _G["WorldStateScoreButton" .. i .. "NameText"]
		if fs then
			local index = offset + i
			if index <= numScores then
				local name, _, _, _, _, _, _, _, _, classToken = GetBattlefieldScore(index)
				if name then
					-- Embedded |cff colors need a white vertex; Blizzard faction tint
					-- would otherwise multiply over class colors.
					if fs.SetVertexColor then
						fs:SetVertexColor(1, 1, 1)
					end
					-- Default WorldStateFrame: own name on BG is gold (1.0, 0.82, 0).
					if (not isArena) and playerName and name == playerName then
						fs:SetText(format("|cffffd100%s|r", name))
					elseif classToken then
						local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
						if c then
							fs:SetText(format("|cff%02x%02x%02x%s|r", c.r * 255 + 0.5, c.g * 255 + 0.5, c.b * 255 + 0.5, name))
						end
					end
				end
			end
		end
	end
end

function SarychUI.modules.arena:ApplyPvpScoreboardClassNames()
	if not scoreboardHooked and WorldStateScoreFrame_Update then
		scoreboardHooked = true
		hooksecurefunc("WorldStateScoreFrame_Update", ColorScoreBoard)
	end
	-- Do not force WorldStateScoreFrame_Update at login: Blizzard Resize
	-- calls SetWidth(nil) when the scoreboard has no live column layout.
	if ScoreboardClassNamesOn()
		and WorldStateScoreFrame
		and WorldStateScoreFrame.IsShown
		and WorldStateScoreFrame:IsShown() then
		ColorScoreBoard()
	end
end
