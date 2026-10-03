local E, L = select(2, ...):unpack()
local P = E.Party

local TM = CreateFrame("Frame")

local AddOnTestMode = {}
local config = {}

AddOnTestMode.VuhDo = function(isTestEnabled)
	if not VUHDO_CONFIG then
		return
	end
	if isTestEnabled then
		config.VuhDo = VUHDO_CONFIG["HIDE_PANELS_SOLO"]
		VUHDO_CONFIG["HIDE_PANELS_SOLO"] = false
	else
		VUHDO_CONFIG["HIDE_PANELS_SOLO"] = config.VuhDo
	end
	VUHDO_getAutoProfile()
end

AddOnTestMode.ElvUI = function(isTestEnabled)
	ElvUI[1]:GetModule("UnitFrames"):HeaderConfig(ElvUF_Party, isTestEnabled)
end

function TM:Test(zone)
	P.isInTestMode = not P.isInTestMode

	if P.isInTestMode then
		if P.inLockdown then
			P.isInTestMode = false
			return E.write(ERR_NOT_IN_COMBAT)
		end

		if self:ShouldShowBlizzardFrames() then
			self:ShowBlizzardFrames()
		end
		self:ToggleAddOnTestFrames(P.isInTestMode)

		P:Refresh()

		self:UpdateIndicator(zone)
		self:UselessBling()
		self:RegisterEvent("PLAYER_LEAVING_WORLD")
	else
		if self:ShouldShowBlizzardFrames() then
			self:HideBlizzardFrames()
		end
		self:ToggleAddOnTestFrames(P.isInTestMode)

		wipe(config)
		self.indicator:Hide()
		self:UnregisterEvent("PLAYER_LEAVING_WORLD")

		P:Refresh()
	end
end

function TM:ShouldShowBlizzardFrames()
	for _, db in pairs(E.db.extraBars) do
		if db and db.enabled and db.unitBar and (db.uf == "blizz" or db.uf == "auto")then
			return true
		end
	end
	return not E.db.position.detached and (E.db.position.uf == "blizz" or E.db.position.uf == "auto")
end

function TM:ShowBlizzardFrames()
	if E:IsBlizzardCUFLoaded() then
		-- Hacky (3.3.5a): We have to avoid RegisterUnitWatch...
		if not CompactRaidFrameManager:IsVisible() then
			CompactRaidFrameManager:Show()
			CompactRaidFrameContainer:Show()
			CompactRaidFrameManager.Hide = CompactRaidFrameManager.Show
			CompactRaidFrameContainer.Hide = CompactRaidFrameContainer.Show
		end
	else
		local Prefix = "PartyMemberFrame1"
		local Frame = _G[Prefix]
		if not Frame:IsVisible() then
			Frame.unit = "player"
			UnitFramePortrait_Update(Frame)
			_G[Prefix.."Disconnect"]:Hide()
			Frame:Show()
		end
	end
end

function TM:HideBlizzardFrames()
	if CompactRaidFrameContainer
		and CompactRaidFrameContainer:IsVisible()
		and (GetNumGroupMembers() == 0 or not P:CompactFrameIsActive()) then
		if P.inLockdown then
			self:EndTestOOC()
		else
			CompactRaidFrameManager.Hide = nil
			CompactRaidFrameContainer.Hide = nil
			CompactRaidFrameManager:Hide()
			CompactRaidFrameContainer:Hide()
		end
	else
		local Frame = _G["PartyMemberFrame1"]
		if Frame.unit == "player" then
			Frame.unit = "party1"
			Frame:Hide()
		end
	end
end

function TM:ToggleAddOnTestFrames(isInTestMode)
	if not E.customUF.enabledList then
		return
	end
	for _, data in pairs(E.customUF.enabledList) do
		local addonName = data.addonName
		if AddOnTestMode[addonName] then
			AddOnTestMode[addonName](isInTestMode)
		end
	end
end

local function GetIndicator()
	local indicator = CreateFrame("Frame", nil, UIParent, "OmniCDTemplate")
	indicator.anchor.background:SetColorTexture(0,0,0,1)
	indicator.anchor.background:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 0)
	indicator.anchor:SetHeight(15)
	indicator.anchor:EnableMouse(false)
	indicator:SetScript("OnHide", nil)
	indicator:SetScript("OnShow", nil)
	indicator.anchor.text:SetFontObject(E.AnchorFont)
	TM:SetScript("OnEvent", function(self, event, ...)
		self[event](self, ...)
	end)
	TM.indicator = indicator
	return indicator
end

function TM:UpdateIndicator(zone)
	local indicator = self.indicator or GetIndicator()
	indicator.anchor:ClearAllPoints()
	indicator.anchor:SetPoint("BOTTOMLEFT", P.userInfo.bar.anchor, "BOTTOMRIGHT")
	indicator.anchor:SetPoint("TOPLEFT", P.userInfo.bar.anchor, "TOPRIGHT")
	indicator.anchor.text:SetFormattedText("%s - %s", L["Test"], E.L_ALL_ZONE[zone])
	indicator.anchor:SetWidth(indicator.anchor.text:GetWidth() + 20)
	indicator:Show()
end

function TM:UselessBling()
	local bar = P.userInfo.bar
	for i = 1, bar.numIcons do
		local icon = bar.icons[i]
		if not icon.AnimFrame:IsVisible() then
			icon.AnimFrame:Show()
			icon.AnimFrame.animIn:Play()
		end
	end
end

function TM:EndTestOOC()
	E.write(L["Test frames will be hidden once player is out of combat"])
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function TM:PLAYER_REGEN_ENABLED()
	TM:HideBlizzardFrames()
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
end




function TM:PLAYER_LEAVING_WORLD()
	if P.isInTestMode then
		self:ToggleAddOnTestFrames(P.isInTestMode)
	end
end

function P:Test(zone)
	E.db = E:GetCurrentZoneSettings(zone or self.testZone)
	self.testZone = zone
	TM:Test(zone)
end

P.TestMode = TM
E.AddOnTestMode = AddOnTestMode
