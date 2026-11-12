-- SarychUI MainMenuBar: BFA-style artwork and layout for Blizzard action bars.
-- Adapted from the bundled CMainMenuBar reference addon.  The source addon is
-- intentionally not loaded or modified; SarychUI owns this independent copy.

local module = SarychUI.modules and SarychUI.modules.mainmenubar
if not module then return end

local MEDIA = "Interface\\AddOns\\SarychUI\\media\\mainmenubar\\bfa\\"
local PLAYER_BAR_WIDTH = 806
local PLAYER_BAR_X = 0
local VEHICLE_ANIMATION_DELAY = 0.60

local BFA = {
	active = false,
	initialized = false,
	hooksInstalled = false,
	layoutPending = false,
	layoutDelay = 0,
	artwork = {},
}
module.BFAStyle = BFA

local controller = CreateFrame("Frame", "SarychUI_BFAMainMenuBarController")
local NativeRegionSetPoint = MainMenuBarPageNumber and MainMenuBarPageNumber.SetPoint
controller:Hide()

local function GetDB()
	local modules = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return modules and modules.mainmenubar
end

local function SetPoint(frame, ...)
	if not frame then return end
	frame:ClearAllPoints()
	frame:SetPoint(...)
end

local function SetTexture(texture, file)
	if texture then
		texture:SetTexture(MEDIA .. file)
	end
end

local function SetShown(region, shown)
	if not region then return end
	if shown then region:Show() else region:Hide() end
end

local function IsPlayerInVehicle()
	return UnitHasVehicleUI and UnitHasVehicleUI("player")
end

local function CreateArtwork(width, height, texture, drawLayer)
	if not MainMenuBarArtFrame then return nil end
	local region = MainMenuBarArtFrame:CreateTexture(nil, drawLayer)
	region:SetWidth(width)
	region:SetHeight(height)
	region:SetTexture(MEDIA .. texture)
	region:Hide()
	return region
end

function BFA:CreateArtwork()
	if self.artwork.left then return end
	self.artwork.tray = CreateArtwork(512, 256, "right_tray.blp", "BACKGROUND")
	self.artwork.left = CreateArtwork(256, 256, "main_bar_left.blp", "ARTWORK")
	self.artwork.middle = CreateArtwork(256, 256, "main_bar_center.blp", "ARTWORK")
	self.artwork.right = CreateArtwork(256, 256, "main_bar_right.blp", "ARTWORK")
	self.artwork.endcap = CreateArtwork(256, 256, "main_bar_endcap.blp", "ARTWORK")
end

local function StyleHotkey(button)
	if not BFA.active or not button or not button.GetName then return end
	if InCombatLockdown() then
		BFA.layoutPending = true
		controller:Hide()
		return
	end

	local name = button:GetName()
	local hotkey = name and getglobal(name .. "HotKey")
	if hotkey then
		if string.sub(name, 1, 26) == "VehicleMenuBarActionButton" and NativeRegionSetPoint then
			hotkey:ClearAllPoints()
			NativeRegionSetPoint(hotkey, "TOPRIGHT", button, "TOPRIGHT", -4, -4)
			hotkey:SetDrawLayer("OVERLAY")
			hotkey:SetTextColor(1, 1, 1)
		else
			SetPoint(hotkey, "TOPRIGHT", button, "TOPRIGHT", -2, -3.6)
		end
	end

	if module.ApplyHotkeyAlpha then
		module:ApplyHotkeyAlpha(button, "BFA:StyleHotkey")
	end
end

local function RestoreButtonBorder(button)
	if not BFA.active then return end
	local style = _G.SarychUI_InterfaceStyle
	if style and style.enabled and style.UseStyleTextures() then return end
	local texture = button and button.GetNormalTexture and button:GetNormalTexture()
	if texture then
		texture:SetVertexColor(1, 1, 1, 1)
	end
	if module.ApplyButtonBorderAlpha then
		module:ApplyButtonBorderAlpha()
	end
end

local function RefreshVehicleHotkeys()
	if not BFA.active then return end
	if InCombatLockdown() then
		BFA.layoutPending = true
		controller:Hide()
		return
	end
	if not ActionButton_UpdateHotkeys then return end
	for index = 1, 6 do
		local button = getglobal("VehicleMenuBarActionButton" .. index)
		if button then
			ActionButton_UpdateHotkeys(button, button.buttonType)
		end
	end
end

local function StyleAllHotkeys()
	local prefixes = {
		"ActionButton", "BonusActionButton", "MultiBarBottomLeftButton",
		"MultiBarBottomRightButton", "MultiBarLeftButton", "MultiBarRightButton",
	}
	for _, prefix in ipairs(prefixes) do
		for index = 1, 12 do
			StyleHotkey(getglobal(prefix .. index))
		end
	end
	RefreshVehicleHotkeys()
end

local function PositionPlayerMicroMenu()
	if not CharacterMicroButton or not MainMenuBarBackpackButton then return false end
	if InCombatLockdown() and CharacterMicroButton.IsProtected and CharacterMicroButton:IsProtected() then
		return false
	end
	SetPoint(CharacterMicroButton, "BOTTOMLEFT", MainMenuBarBackpackButton, "CENTER", -233, -62.9)
	return true
end

local function GetRightTrayOffset()
	local width = GetScreenWidth and GetScreenWidth() or (UIParent and UIParent:GetWidth()) or 1024
	return (width / 2) - 6
end

local function StyleStatusBars()
	if ReputationWatchStatusBar then ReputationWatchStatusBar:SetWidth(804) end

	if MainMenuExpBar then
		MainMenuExpBar:SetWidth(804)
		MainMenuExpBar:SetHeight(9)
		MainMenuExpBar:SetFrameStrata("LOW")
		SetPoint(MainMenuExpBar, "CENTER", MainMenuBar, "CENTER", 0, 22)
	end

	if MainMenuBarMaxLevelBar then
		MainMenuBarMaxLevelBar:SetWidth(256)
		MainMenuBarMaxLevelBar:SetHeight(9)
		MainMenuBarMaxLevelBar:SetFrameStrata("BACKGROUND")
		SetPoint(MainMenuBarMaxLevelBar, "CENTER", MainMenuBar, "CENTER", 109, 11)
	end

	for index = 0, 3 do
		SetTexture(getglobal("MainMenuXPBarTexture" .. index), "experience_bar.blp")
		SetTexture(getglobal("ReputationXPBarTexture" .. index), "experience_bar.blp")
		SetTexture(getglobal("ReputationWatchBarTexture" .. index), "reputation_bar.blp")
	end

	-- Two 256 px atlas runs + 38 px cap.  First slice keeps FrameXML's
	-- BOTTOM/TOP anchor so the strip sits at CMainMenuBar height.
	local maxTextures = {
		MainMenuMaxLevelBar0, MainMenuMaxLevelBar1,
		MainMenuMaxLevelBar2, MainMenuMaxLevelBar3,
	}
	for index = 1, 3 do
		local texture = maxTextures[index]
		if texture then
			SetTexture(texture, "max_level_bar.blp")
			texture:SetWidth(256)
			texture:SetHeight(7)
			if index == 2 then
				texture:SetTexCoord(0, 1, 0.25, 0.46875)
			else
				texture:SetTexCoord(0, 1, 0, 0.21875)
			end
			if index == 1 then
				SetPoint(texture, "BOTTOM", MainMenuBarMaxLevelBar, "TOP", -384, 0)
			else
				SetPoint(texture, "LEFT", maxTextures[index - 1], "RIGHT", 0, 0)
			end
		end
	end
	if maxTextures[4] then
		local texture = maxTextures[4]
		SetTexture(texture, "max_level_bar_alt.blp")
		texture:SetWidth(38)
		texture:SetHeight(7)
		texture:SetTexCoord(0, 38 / 256, 0.5, 0.71875)
		SetPoint(texture, "LEFT", maxTextures[3] or MainMenuBarMaxLevelBar, "RIGHT", 0, 0)
	end

	local xpOffsets = { -256, 0, 256, 512 }
	for index = 0, 3 do
		local texture = getglobal("MainMenuXPBarTexture" .. index)
		if texture and MainMenuMaxLevelBar1 then
			SetPoint(texture, "CENTER", MainMenuMaxLevelBar1, "CENTER", xpOffsets[index + 1], index > 0 and 3 or 2)
		end
	end

	local reputationOffsets = { -275, -19, 237, 493 }
	for index = 0, 3 do
		local texture = getglobal("ReputationXPBarTexture" .. index)
		if texture and ReputationWatchStatusBar then
			SetPoint(texture, "CENTER", ReputationWatchStatusBar, "CENTER", reputationOffsets[index + 1], 1)
		end
	end

	local watchedFaction = GetWatchedFactionInfo and GetWatchedFactionInfo()
	if watchedFaction and ReputationWatchStatusBar and ReputationWatchBar then
		if UnitLevel("player") < MAX_PLAYER_LEVEL then
			ReputationWatchStatusBar:SetHeight(8)
			SetPoint(ReputationWatchBar, "BOTTOM", MainMenuBar, "TOP", -1, -3)
			if ReputationWatchStatusBarText and ReputationWatchBarOverlayFrame then
				SetPoint(ReputationWatchStatusBarText, "CENTER", ReputationWatchBarOverlayFrame, "CENTER", 0, 3)
			end

			local watchOffsets = { 494, 238, -18, -274 }
			for index = 0, 3 do
				local texture = getglobal("ReputationWatchBarTexture" .. index)
				if texture then
					SetPoint(texture, "CENTER", ReputationWatchStatusBar, "CENTER", watchOffsets[index + 1], 1)
				end
			end
		else
			ReputationWatchStatusBar:SetHeight(13)
			ReputationWatchStatusBar:SetFrameStrata("LOW")
			SetPoint(ReputationWatchBar, "TOP", MainMenuBar, "TOP", 0, 0)
			if ReputationWatchStatusBarText and ReputationWatchBarOverlayFrame then
				SetPoint(ReputationWatchStatusBarText, "CENTER", ReputationWatchBarOverlayFrame, "CENTER", 0, 1)
			end
		end
	end
end

function BFA:ApplyAppearance()
	if not self.active then return end
	local db = GetDB() or {}

	-- The custom regions live on MainMenuBarArtFrame, so keep the frame itself
	-- alive and control only its artwork.  This also preserves child buttons on
	-- clients where they are parented to the art frame.
	if MainMenuBarArtFrame then
		if MainMenuBarArtFrame.SetScript then MainMenuBarArtFrame:SetScript("OnShow", nil) end
		MainMenuBarArtFrame:Show()
	end

	for index = 0, 3 do
		local texture = getglobal("MainMenuBarTexture" .. index)
		if texture then
			texture:Hide()
			if texture.SetScript then
				texture:SetScript("OnShow", texture.Hide)
			end
		end
	end

	local showMainArtwork = not db.hideActionBarBackgrounds
	SetShown(self.artwork.left, showMainArtwork)
	SetShown(self.artwork.middle, showMainArtwork)
	SetShown(self.artwork.right, showMainArtwork)
	SetShown(self.artwork.endcap, showMainArtwork)
	SetShown(self.artwork.tray, not db.hideBagMicroMenuBackground)

	for _, texture in ipairs({ BonusActionBarTexture0, BonusActionBarTexture1 }) do
		if texture then
			SetTexture(texture, "bonus_action_bar.blp")
			if db.hideActionBarBackgrounds then texture:Hide() else texture:Show() end
		end
	end

	-- Keep dynamically-created BFA backgrounds in the same InterfaceStyle tint cycle
	-- as Blizzard's named action-bar textures.
	local style = _G.SarychUI_InterfaceStyle
	if style and style.ApplySarychUIMainMenuBarArtwork then
		style:ApplySarychUIMainMenuBarArtwork(not style.enabled)
	end
end

local function IsVehicleLayoutBlocked()
	if IsPlayerInVehicle() then return true end
	if MainMenuBar and (MainMenuBar.busy or MainMenuBar.animating) then return true end
	if VehicleMenuBar and VehicleMenuBar.animating then return true end
	return false
end

function BFA:ApplyPlayerLayout()
	if not self.active or not MainMenuBar or not MainMenuBarArtFrame then return false end
	if self._applyingLayout then return true end
	if InCombatLockdown() or IsVehicleLayoutBlocked() then
		self.layoutPending = true
		if IsVehicleLayoutBlocked() then
			self.layoutDelay = 0.10
			controller:Show()
		else
			controller:Hide()
		end
		return false
	end

	self._applyingLayout = true

	MainMenuBar:SetWidth(PLAYER_BAR_WIDTH)
	SetPoint(MainMenuBar, "BOTTOM", UIParent, "BOTTOM", PLAYER_BAR_X, 0)

	if MainMenuBarLeftEndCap then
		MainMenuBarLeftEndCap:SetWidth(115)
		MainMenuBarLeftEndCap:SetHeight(115)
		SetPoint(MainMenuBarLeftEndCap, "BOTTOM", MainMenuBarArtFrame, "BOTTOM", -431, 0)
	end
	if MainMenuBarRightEndCap then
		MainMenuBarRightEndCap:SetWidth(115)
		MainMenuBarRightEndCap:SetHeight(115)
		SetPoint(MainMenuBarRightEndCap, "BOTTOM", MainMenuBarArtFrame, "BOTTOM", 431, 0)
	end

	SetPoint(MultiBarBottomLeftButton1, "BOTTOMLEFT", MultiBarBottomLeft, "BOTTOMLEFT", 0, 1)
	SetPoint(MultiBarBottomRightButton1, "RIGHT", MultiBarBottomLeftButton12, "RIGHT", 80.8, 0)
	SetPoint(MultiBarBottomRightButton7, "RIGHT", ActionButton12, "RIGHT", 80.8, 0)
	SetPoint(ShapeshiftButton1, "CENTER", ShapeshiftBarFrame, "CENTER", -6, 2)

	if MainMenuBarPageNumber then
		SetPoint(MainMenuBarPageNumber, "CENTER", MainMenuBar, "TOPRIGHT", -266, -31)
		MainMenuBarPageNumber:SetText(GetActionBarPage())
	end
	SetPoint(ActionBarUpButton, "CENTER", MainMenuBar, "BOTTOMLEFT", 521.9, 31.2)
	SetPoint(ActionBarDownButton, "CENTER", MainMenuBar, "BOTTOMLEFT", 521.9, 12)

	SetPoint(MainMenuBarBackpackButton, "BOTTOMRIGHT", MainMenuBar, "BOTTOM", GetRightTrayOffset(), 46)
	SetPoint(CharacterBag0Slot, "BOTTOMLEFT", MainMenuBarBackpackButton, "CENTER", -55.7, -20)
	SetPoint(CharacterBag1Slot, "CENTER", CharacterBag0Slot, "CENTER", -33.5, 0)
	SetPoint(CharacterBag2Slot, "CENTER", CharacterBag0Slot, "CENTER", -67, 0)
	SetPoint(CharacterBag3Slot, "CENTER", CharacterBag0Slot, "CENTER", -101, 0)
	PositionPlayerMicroMenu()

	for _, bag in ipairs({ CharacterBag0Slot, CharacterBag1Slot, CharacterBag2Slot, CharacterBag3Slot }) do
		if bag then bag:SetScale(0.95) end
	end

	SetPoint(self.artwork.endcap, "BOTTOMRIGHT", MainMenuBarArtFrame, "BOTTOMRIGHT", 2, 0)
	SetPoint(self.artwork.left, "BOTTOM", MainMenuBarArtFrame, "BOTTOM", -275, 0)
	SetPoint(self.artwork.middle, "BOTTOM", MainMenuBarArtFrame, "BOTTOM", -19, 0)
	SetPoint(self.artwork.right, "BOTTOM", MainMenuBarArtFrame, "BOTTOM", 237, 0)
	SetPoint(self.artwork.tray, "CENTER", MainMenuBarBackpackButton, "CENTER", -125, -22)

	for _, bar in ipairs({ MainMenuBar, MultiBarBottomLeft, MultiBarBottomRight, MultiBarLeft, MultiBarRight }) do
		if bar then bar:SetScale(1) end
	end

	StyleStatusBars()
	StyleAllHotkeys()
	self:ApplyAppearance()
	if module.ApplyPageButtonsSettings then
		module:ApplyPageButtonsSettings()
	end

	self.layoutPending = false
	self.layoutDelay = 0
	controller:Hide()
	self._applyingLayout = false
	return true
end

function BFA:RequestLayout(delay)
	if not self.active then return end
	self.layoutPending = true
	delay = delay or 0
	if delay > self.layoutDelay then self.layoutDelay = delay end
	controller:Show()
end

function BFA:InstallHooks()
	if self.hooksInstalled or not hooksecurefunc then return end
	self.hooksInstalled = true

	if ActionButton_UpdateHotkeys then hooksecurefunc("ActionButton_UpdateHotkeys", StyleHotkey) end
	if ActionButton_ShowGrid then hooksecurefunc("ActionButton_ShowGrid", RestoreButtonBorder) end
	if VehicleMenuBar_UpdateActionBars then hooksecurefunc("VehicleMenuBar_UpdateActionBars", RefreshVehicleHotkeys) end
	if ReputationWatchBar_Update then
		hooksecurefunc("ReputationWatchBar_Update", function() BFA:RequestLayout() end)
	end
	if ShapeshiftBar_Update then
		hooksecurefunc("ShapeshiftBar_Update", function() BFA:RequestLayout() end)
	end
	if VehicleMenuBar_MoveMicroButtons then
		hooksecurefunc("VehicleMenuBar_MoveMicroButtons", function(skinName)
			if BFA.active and not skinName then
				PositionPlayerMicroMenu()
				BFA:RequestLayout(VEHICLE_ANIMATION_DELAY)
			end
		end)
	end
	if MainMenuBar_ToPlayerArt then
		hooksecurefunc("MainMenuBar_ToPlayerArt", function()
			BFA:RequestLayout(VEHICLE_ANIMATION_DELAY)
		end)
	end
end

function BFA:Enable()
	self.active = true
	if not self.initialized then
		self.initialized = true
		self:CreateArtwork()
		self:InstallHooks()
		controller:RegisterEvent("PLAYER_ENTERING_WORLD")
		controller:RegisterEvent("PLAYER_REGEN_ENABLED")
		controller:RegisterEvent("UNIT_ENTERING_VEHICLE")
		controller:RegisterEvent("UNIT_EXITED_VEHICLE")
		controller:RegisterEvent("DISPLAY_SIZE_CHANGED")
	end
	StyleStatusBars()
	RefreshVehicleHotkeys()
	self:ApplyAppearance()
	if not self:ApplyPlayerLayout() then
		self:RequestLayout(0)
	end
end

function BFA:Disable()
	self.active = false
	self.layoutPending = false
	self.layoutDelay = 0
	self._applyingLayout = false
	controller:Hide()
	for index = 0, 3 do
		local texture = getglobal("MainMenuBarTexture" .. index)
		if texture and texture.SetScript then
			texture:SetScript("OnShow", nil)
		end
	end
	for _, region in pairs(self.artwork) do
		if region then region:Hide() end
	end
end

controller:SetScript("OnEvent", function(self, event, unit)
	if not BFA.active then return end
	if event == "UNIT_ENTERING_VEHICLE" then
		if unit == "player" then
			BFA.layoutPending = false
			BFA.layoutDelay = 0
			self:Hide()
		end
	elseif event == "UNIT_EXITED_VEHICLE" then
		if unit == "player" then BFA:RequestLayout(VEHICLE_ANIMATION_DELAY) end
	elseif event == "PLAYER_ENTERING_WORLD" then
		if not BFA:ApplyPlayerLayout() then
			BFA:RequestLayout(0)
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		RefreshVehicleHotkeys()
		BFA:RequestLayout()
	elseif event == "DISPLAY_SIZE_CHANGED" then
		if not BFA:ApplyPlayerLayout() then
			BFA:RequestLayout(0)
		end
	end
end)

controller:SetScript("OnUpdate", function(self, elapsed)
	if not BFA.active or not BFA.layoutPending then return end
	if BFA.layoutDelay > 0 then
		BFA.layoutDelay = BFA.layoutDelay - elapsed
		return
	end
	BFA:ApplyPlayerLayout()
end)
