--[[ 
	Purgeatory 3, Mayen of US-Mal'Ganis PvP
]]

if not SarychUI_PurgeatoryEmbeddedAvailable then return end

Purgeatory = {}

local L = PurgeatoryLocals
local instanceType, arenaBracket
local summonedTotems = {}
local summonedObjects = {}

function Purgeatory:OnInitialize()
	if self.db then return end
	self.defaults = {
		profile = {
			showIcon = true,
			dispelSuccessMsg = L["Removed *spell (*target)"] or "Removed *spell (*target)",
			dispelFailMsg = L["FAILED *spell (*target)"] or "FAILED *spell (*target)",
			dispelColor = {r = 1, g = 1, b = 1},
			dispelLocation = "1",
			interruptMsg = L["Interrupted *spell (*target)"] or "Interrupted *spell (*target)",
			interruptColor = {r = 1, g = 1, b = 1},
			interruptLocation = "1",
			zones = {
				["none"] = {},
				["party"] = {},
				["raid"] = {},
				["arena"] = {
					enabled = true,
					dispelOffensive = true,
					interrupt = true,
				},
				["pvp"] = {
					enabled = true,
					dispelOffensive = true,
					interrupt = true,
				},
			},
		},
	}
			
	-- Initialize DB
	self.db = LibStub:GetLibrary("AceDB-3.0"):New("PurgeatoryDB", self.defaults, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "Reload")
	self.db.RegisterCallback(self, "OnProfileCopied", "Reload")
	self.db.RegisterCallback(self, "OnProfileReset", "Reload")
end

local COMBATLOG_OBJECT_REACTION_HOSTILE	= COMBATLOG_OBJECT_REACTION_HOSTILE
local COMBATLOG_OBJECT_AFFILIATION_MINE = COMBATLOG_OBJECT_AFFILIATION_MINE
local eventRegistered = {["SPELL_INTERRUPT"] = true, ["SPELL_STOLEN"] = true, ["SPELL_DISPEL_FAILED"] = true, ["SPELL_DISPEL"] = true}
function Purgeatory:COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, ...)
	if not self.enabled or not instanceType or not self.db then return end
	if( not eventRegistered[eventType] or bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= COMBATLOG_OBJECT_AFFILIATION_MINE ) then
		return
	end
	
	local isHostile = bit.band(destFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) == COMBATLOG_OBJECT_REACTION_HOSTILE

	-- We got interrupted, or we interrupted someone else
	if( eventType == "SPELL_INTERRUPT" and self.db.profile.zones[instanceType].interrupt ) then
		local spellID, spellName, spellSchool, extraSpellID, extraSpellName, extraSpellSchool = ...
		self:SendMessage(self.db.profile.interruptMsg, extraSpellID, extraSpellName, spellName, destName, self.db.profile.interruptLocation, self.db.profile.interruptColor)
		
	-- We tried to dispel a buff, and failed
	elseif( eventType == "SPELL_DISPEL_FAILED" and self.db.profile.zones[instanceType].dispelFail and ( ( isHostile and self.db.profile.zones[instanceType].dispelOffensive ) or ( not isHostile and self.db.profile.zones[instanceType].dispelDefensive ) ) ) then
		local spellID, spellName, spellSchool, extraSpellID, extraSpellName, extraSpellSchool, auraType = ...
		self:SendMessage(self.db.profile.dispelFailMsg, extraSpellID, extraSpellName, spellName, destName, self.db.profile.dispelLocation, self.db.profile.dispelColor)
			
	-- Managed to dispel or steal a buff
	elseif( ( eventType == "SPELL_DISPEL" or eventType == "SPELL_STOLEN" ) and ( ( isHostile and self.db.profile.zones[instanceType].dispelOffensive ) or ( not isHostile and self.db.profile.zones[instanceType].dispelDefensive ) ) ) then
		local spellID, spellName, spellSchool, extraSpellID, extraSpellName, extraSpellSchool, auraType = ...
		
		self:SendMessage(self.db.profile.dispelSuccessMsg, extraSpellID, extraSpellName, spellName, destName, self.db.profile.dispelLocation, self.db.profile.dispelColor)
	end
end

-- Enabling Purgeatory based on zone type
function Purgeatory:PLAYER_ENTERING_WORLD()
	self:ZONE_CHANGED_NEW_AREA()
end

function Purgeatory:ZONE_CHANGED_NEW_AREA()
	if not self.enabled or not self.db then return end
	local type = select(2, IsInInstance())
	local zones = self.db.profile.zones
	local zone = zones and zones[type]

	if( type ~= instanceType ) then
		if( zone and zone.enabled ) then
			self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		else
			self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		end
	end
	
	instanceType = type
end

function Purgeatory:Reload()
	instanceType = nil
	self:ZONE_CHANGED_NEW_AREA()
end

-- Strips server name
function Purgeatory:StripServer(text)
	local name, server = string.match(text, "(.-)%-(.*)$")
	if( not name and not server ) then
		return text
	end
	
	return name
end

-- Wrap the message with an icon if needed
function Purgeatory:WrapIcon(msg, spellID)
	if( not self.db.profile.showIcon or not spellID ) then
		return msg
	end
	
	local icon = select(3, GetSpellInfo(spellID))
	return icon and string.format("|T%s:0:0|t %s", icon, msg) or msg
end

function Purgeatory:FormatMessage(msg, spellName, usedSpellName, destName)
	-- Do special things to the message
	msg = string.gsub(msg, "*target", self:StripServer(destName or ""))
	msg = string.gsub(msg, "*spell", spellName or "")
	msg = string.gsub(msg, "*used", usedSpellName or "")
	
	-- Strip out any () leftover from no name being given
	msg = string.trim(string.gsub(msg, "%(%)", ""))
		
    return msg
end

local chatFrames = {}
local _G = getfenv(0)
function Purgeatory:SendMessage(msg, spellID, spellName, usedSpellName, destName, dest, color)
	-- We're undergrouped, so redirect it to our fake alert frame
	if( dest == "rw" and GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 ) then
		dest = "rwframe"
	-- We're grouped, in a raid and not leader or assist
	elseif( dest == "rw" and not IsRaidLeader() and not IsRaidOfficer() and GetNumRaidMembers() > 0 ) then
		dest = "party"
	end
	
    msg = self:FormatMessage(msg, spellName, usedSpellName, destName)

	-- Chat frame
	if( tonumber(dest) ) then
		chatFrames[dest] = chatFrames[dest] or _G["ChatFrame" .. dest] or DEFAULT_CHAT_FRAME
		chatFrames[dest]:AddMessage(string.format("|cff33ff99Purgeatory|r|cffffffff:|r %s", self:WrapIcon(msg, spellID)), color.r, color.g, color.b)
	-- Raid warning announcement to raid/party
	elseif( dest == "rw" ) then
		SendChatMessage(msg, "RAID_WARNING")
	-- Party chat
	elseif( dest == "party" ) then
		SendChatMessage(msg, "PARTY")
	-- Raid warning frame, will not send it out to the party
	elseif( dest == "rwframe" ) then
		if( not self.alertFrame ) then
			self.alertFrame = CreateFrame("MessageFrame", nil, UIParent)
			self.alertFrame:SetInsertMode("TOP")
			self.alertFrame:SetFrameStrata("HIGH")
			self.alertFrame:SetWidth(UIParent:GetWidth())
			self.alertFrame:SetHeight(60)
			self.alertFrame:SetFadeDuration(0.5)
			self.alertFrame:SetTimeVisible(2)
			self.alertFrame:SetFont((GameFontNormal:GetFont()), 20, "OUTLINE")
			self.alertFrame:SetPoint("CENTER", 0, 60)
		end
		
		self.alertFrame:AddMessage(self:WrapIcon(msg, spellID), color.r, color.g, color.b)
	-- Combat text
	elseif( dest == "ct" ) then
		msg = self:WrapIcon(msg)
		
		-- SCT
		if( IsAddOnLoaded("sct") ) then
			SCT:DisplayText(msg, color, nil, "event", 1)
		-- MSBT
		elseif( IsAddOnLoaded("MikScrollingBattleText") ) then
			MikSBT.DisplayMessage(msg, MikSBT.DISPLAYTYPE_NOTIFICATION, false, color.r * 255, color.g * 255, color.b * 255)		
		-- Blizzard Combat Text
		elseif( IsAddOnLoaded("Blizzard_CombatText") ) then
			-- Haven't cached the movement function yet
			if( not COMBAT_TEXT_SCROLL_FUNCTION ) then
				CombatText_UpdateDisplayedMessages()
			end
			
			CombatText_AddMessage(msg, COMBAT_TEXT_SCROLL_FUNCTION, color.r, color.g, color.b)
		end
	end
end

-- Local preview only: a test never sends announcements to party or raid.
function Purgeatory:ToggleTest()
    if not self.enabled then return end
    if self.testFrame and self.testFrame:IsShown() then self.testFrame:Hide(); return end
    if not self.testFrame then
        local preview = CreateFrame("Frame", nil, UIParent)
        preview:SetSize(700, 110)
        preview:SetPoint("TOP", UIParent, "TOP", 0, -180)
        preview:SetFrameStrata("DIALOG")
        preview.lines = {}
        for i = 1, 3 do
            local line = preview:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            line:SetPoint("TOP", 0, -(i - 1) * 32)
            line:SetWidth(700)
            preview.lines[i] = line
        end
        preview:SetScript("OnHide", function()
            if SarychUI.RefreshConfig then SarychUI:RefreshConfig() end
        end)
        self.testFrame = preview
    end
    local spell = GetSpellInfo(118) or "Превращение"
    local used = GetSpellInfo(2139) or "Антимагия"
    local target = UnitName("player") or "Игрок"
    local db = self.db.profile
    for i, entry in ipairs({ {db.dispelSuccessMsg, db.dispelColor},
        {db.dispelFailMsg, db.dispelColor}, {db.interruptMsg, db.interruptColor} }) do
        local line = self.testFrame.lines[i]
        line:SetText(self:WrapIcon(self:FormatMessage(entry[1], spell, used, target), 118))
        line:SetTextColor(entry[2].r, entry[2].g, entry[2].b)
    end
    self.testFrame:Show()
    if SarychUI.RefreshConfig then SarychUI:RefreshConfig() end
end

function Purgeatory:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Purgeatory|r: " .. msg)
end

-- Event handler. The SarychUI wrapper owns registration and removal.
local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(self, event, ...)
	if Purgeatory.enabled and Purgeatory[event] then
		Purgeatory[event](Purgeatory, event, ...)
	end
end)

function Purgeatory:Enable()
	if self.enabled then return end
	self:OnInitialize()
	self.enabled = true
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	if self.alertFrame then self.alertFrame:Show() end
	self:Reload()
end

function Purgeatory:Disable()
    if self.testFrame then self.testFrame:Hide() end
	self.enabled = false
	instanceType = nil
	frame:UnregisterAllEvents()
	if self.alertFrame then self.alertFrame:Hide() end
end

function Purgeatory:RegisterEvent(event)
	frame:RegisterEvent(event)
end

function Purgeatory:UnregisterEvent(event)
	frame:UnregisterEvent(event)
end


--[[
PurgeatoryLocals = setmetatable(PurgeatoryLocals, {
	__index = function(t, k)
		rawset(t, k, k)
		return k
	end,
})
]]
