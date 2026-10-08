-- Ported from Lorti UI.lua (Lorti, 2011)
-- Vertex-color thenнение фреймов / баров / арены.

local L = SarychUI_LortiUI

-- Unit frames + borders (Lorti UI.lua ADDON_LOADED list + extras already in SarychUI)
L.unitFrameNames = {
	"PlayerFrameTexture",
	"TargetFrameTextureFrameTexture",
	"PetFrameTexture",
	"PartyMemberFrame1Texture",
	"PartyMemberFrame2Texture",
	"PartyMemberFrame3Texture",
	"PartyMemberFrame4Texture",
	"PartyMemberFrame1PetFrameTexture",
	"PartyMemberFrame2PetFrameTexture",
	"PartyMemberFrame3PetFrameTexture",
	"PartyMemberFrame4PetFrameTexture",
	"FocusFrameTextureFrameTexture",
	"TargetFrameToTTextureFrameTexture",
	"FocusFrameToTTextureFrameTexture",
	"MinimapBorder",
	"MiniMapMailBorder",
	"MiniMapBattlefieldBorder",
	"MiniMapLFGFrameBorder",
	"CastingBarFrameBorder",
	"FocusFrameSpellBarBorder",
	"TargetFrameSpellBarBorder",
	"RuneButtonIndividual1BorderTexture",
	"RuneButtonIndividual2BorderTexture",
	"RuneButtonIndividual3BorderTexture",
	"RuneButtonIndividual4BorderTexture",
	"RuneButtonIndividual5BorderTexture",
	"RuneButtonIndividual6BorderTexture",
	"TargetFrameSpellBarBorderShield",
	"FocusFrameSpellBarBorderShield",
	"MinimapBorderTop",
	"MiniMapTrackingButtonBorder",
	"MiniMapWorldBorder",
	"MiniMapMeetingStoneBorder",
	"MiniMapRecordingBorder",
	"CharacterFrameTitleBg",
	"CharacterFrameBg",
}

-- Unnamed textures found by file path (lower-case, backslashes):
--  * Interface\CharacterFrame\TotemBorder   - ring around Blizzard TotemFrame buttons
--  * Interface\Minimap\MiniMap-TrackingBorder - ring on minimap addon buttons (LibDBIcon etc.)
L.pathTextureTargets = {
	["interface\\characterframe\\totemborder"] = true,
	["interface\\minimap\\minimap-trackingborder"] = true,
}
L.paintedPathTextures = L.paintedPathTextures or {}

local function NormalizeTexturePath(path)
	if type(path) ~= "string" then return nil end
	path = string.lower(path)
	path = string.gsub(path, "/", "\\")
	path = string.gsub(path, "%.blp$", "")
	path = string.gsub(path, "%.tga$", "")
	return path
end

local function PaintPathTexturesIn(frame, restore, depth)
	if not frame or not frame.GetRegions then return end
	depth = depth or 0
	local regions = { frame:GetRegions() }
	local i, region, path
	for i = 1, #regions do
		region = regions[i]
		if region and region.GetObjectType and region:GetObjectType() == "Texture" and region.GetTexture then
			path = NormalizeTexturePath(region:GetTexture())
			if path and L.pathTextureTargets[path] then
				if restore then
					L:RestoreTexture(region)
					L.paintedPathTextures[region] = nil
				else
					L:DarkenTexture(region)
					L.paintedPathTextures[region] = true
				end
			end
		end
	end
	if depth < 2 and frame.GetChildren then
		local children = { frame:GetChildren() }
		for i = 1, #children do
			PaintPathTexturesIn(children[i], restore, depth + 1)
		end
	end
end

local function ForEachMinimapButton(fn)
	if Minimap and Minimap.GetChildren then
		local children = { Minimap:GetChildren() }
		local i
		for i = 1, #children do
			fn(children[i])
		end
	end
	local lib = LibStub and LibStub("LibDBIcon-1.0", true)
	if lib and lib.objects then
		local _, button
		for _, button in pairs(lib.objects) do
			fn(button)
		end
	end
end

function L:ApplyTotemRings()
	local i
	for i = 1, 4 do
		PaintPathTexturesIn(_G["TotemFrameTotem" .. i], false)
	end
end

-- LibDBIcon may be loaded by another addon after LortiUI; try until it exists.
function L:InstallLibDBIconRingHook()
	if self.libDBIconRingHookInstalled or not hooksecurefunc then return end
	local lib = LibStub and LibStub("LibDBIcon-1.0", true)
	if not (lib and lib.Register) then return end
	self.libDBIconRingHookInstalled = true
	hooksecurefunc(lib, "Register", function()
		if L.enabled then
			L:ApplyMinimapButtonRings()
		end
	end)
end

function L:ApplyMinimapButtonRings()
	self:InstallLibDBIconRingHook()
	ForEachMinimapButton(function(button)
		PaintPathTexturesIn(button, false)
	end)
end

function L:RestorePathTextures()
	local region
	for region in pairs(self.paintedPathTextures) do
		self:RestoreTexture(region)
	end
	wipe(self.paintedPathTextures)
end

-- Action / XP / reputation bars (Lorti UI.lua)
L.barFrameNames = {
	"BonusActionBarTexture0",
	"BonusActionBarTexture1",
	"BonusActionBarTexture",
	"MainMenuBarTexture0",
	"MainMenuBarTexture1",
	"MainMenuBarTexture2",
	"MainMenuBarTexture3",
	"MainMenuMaxLevelBar0",
	"MainMenuMaxLevelBar1",
	"MainMenuMaxLevelBar2",
	"MainMenuMaxLevelBar3",
	"MainMenuXPBarTextureLeftCap",
	"MainMenuXPBarTextureRightCap",
	"MainMenuXPBarTextureMid",
	"MainMenuXPBarTexture0",
	"MainMenuXPBarTexture1",
	"MainMenuXPBarTexture2",
	"MainMenuXPBarTexture3",
	"ReputationWatchBarTexture0",
	"ReputationWatchBarTexture1",
	"ReputationWatchBarTexture2",
	"ReputationWatchBarTexture3",
	"ReputationXPBarTexture0",
	"ReputationXPBarTexture1",
	"ReputationXPBarTexture2",
	"ReputationXPBarTexture3",
	"SlidingActionBarTexture0",
	"SlidingActionBarTexture1",
	"StanceBarLeft",
	"StanceBarMiddle",
	"StanceBarRight",
	"ShapeshiftBarLeft",
	"ShapeshiftBarMiddle",
	"ShapeshiftBarRight",
}

-- Gryphons (Lorti UI.lua)
L.endCapNames = {
	"MainMenuBarLeftEndCap",
	"MainMenuBarRightEndCap",
}

-- Blizzard_ArenaUI (Lorti UI.lua)
L.arenaFrameNames = {
	"ArenaEnemyFrame1Texture",
	"ArenaEnemyFrame2Texture",
	"ArenaEnemyFrame3Texture",
	"ArenaEnemyFrame4Texture",
	"ArenaEnemyFrame5Texture",
	"ArenaEnemyFrame1SpecBorder",
	"ArenaEnemyFrame2SpecBorder",
	"ArenaEnemyFrame3SpecBorder",
	"ArenaEnemyFrame4SpecBorder",
	"ArenaEnemyFrame5SpecBorder",
	"ArenaEnemyFrame1PetFrameTexture",
	"ArenaEnemyFrame2PetFrameTexture",
	"ArenaEnemyFrame3PetFrameTexture",
	"ArenaEnemyFrame4PetFrameTexture",
	"ArenaEnemyFrame5PetFrameTexture",
	"ArenaPrepFrame1Texture",
	"ArenaPrepFrame2Texture",
	"ArenaPrepFrame3Texture",
	"ArenaPrepFrame4Texture",
	"ArenaPrepFrame5Texture",
	"ArenaPrepFrame1SpecBorder",
	"ArenaPrepFrame2SpecBorder",
	"ArenaPrepFrame3SpecBorder",
	"ArenaPrepFrame4SpecBorder",
	"ArenaPrepFrame5SpecBorder",
}

local function PaintList(list, restore)
	if not list then return end
	local i, name
	for i = 1, #list do
		name = list[i]
		if restore then
			L:RestoreNamed(name)
		else
			L:DarkenNamed(name)
		end
	end
end

function L:ApplyFrames()
	PaintList(self.unitFrameNames, false)
	PaintList(self.barFrameNames, false)
	PaintList(self.endCapNames, false)
	PaintList(self.arenaFrameNames, false)
	self:DarkenFirstRegion(TimeManagerClockButton)
	self:DarkenFirstRegion(GameTimeFrame)
	self:ApplyTotemRings()
	self:ApplyMinimapButtonRings()
	if self.ApplyCompactRaid then
		self:ApplyCompactRaid()
	end
	if self.ApplyCastBarIcons then
		self:ApplyCastBarIcons()
	end
end

function L:RestoreFrames()
	PaintList(self.unitFrameNames, true)
	PaintList(self.barFrameNames, true)
	PaintList(self.endCapNames, true)
	PaintList(self.arenaFrameNames, true)
	self:RestoreFirstRegion(TimeManagerClockButton)
	self:RestoreFirstRegion(GameTimeFrame)
	self:RestorePathTextures()
	if self.RestoreCompactRaid then
		self:RestoreCompactRaid()
	end
	if self.RestoreCastBarIcons then
		self:RestoreCastBarIcons()
	end
end

function L:InstallFrameHooks()
	if self.frameEventFrame then return end
	local f = CreateFrame("Frame")
	self.frameEventFrame = f
	f:RegisterEvent("ADDON_LOADED")
	f:RegisterEvent("PLAYER_ENTERING_WORLD")
	f:SetScript("OnEvent", function(_, event, addonName)
		if not L.enabled then return end
		if event == "PLAYER_ENTERING_WORLD" then
			L:ApplyFrames()
		elseif event == "ADDON_LOADED" then
			if addonName == "Blizzard_TimeManager" or addonName == "Blizzard_ArenaUI" then
				L:ApplyFrames()
			else
				-- Addon minimap buttons are usually created on load; tint their rings.
				L:ApplyMinimapButtonRings()
			end
		end
	end)

	-- Buttons registered through LibDBIcon after login (or re-scanned by the
	-- SarychUI minimap module) get their ring tinted as they appear.
	self:InstallLibDBIconRingHook()
	if not self.minimapRingHooksInstalled and hooksecurefunc then
		self.minimapRingHooksInstalled = true
		local mmMod = SarychUI and SarychUI.modules and SarychUI.modules.minimap
		if mmMod and mmMod.ScanAddonMinimapButtons then
			hooksecurefunc(mmMod, "ScanAddonMinimapButtons", function()
				if L.enabled then
					L:ApplyMinimapButtonRings()
				end
			end)
		end
	end

	if not self.castBarIconHooksInstalled and hooksecurefunc then
		self.castBarIconHooksInstalled = true
		if CastingBarFrame_OnEvent then
			hooksecurefunc("CastingBarFrame_OnEvent", function(bar)
				if L.enabled then
					L:StyleCastBarFromFrame(bar)
				end
			end)
		end
		if CastingBarFrame_OnShow then
			hooksecurefunc("CastingBarFrame_OnShow", function(bar)
				if L.enabled then
					L:StyleCastBarFromFrame(bar)
				end
			end)
		end
	end
end

-- Spell-icon gloss on Blizzard cast bars (player / target / focus / pet).
L.castBarIconNames = {
	"CastingBarFrameIcon",
	"TargetFrameSpellBarIcon",
	"FocusFrameSpellBarIcon",
	"PetCastingBarFrameIcon",
}

local function IsBossTargetRegion(region)
	local name = region and region.GetName and region:GetName()
	return type(name) == "string" and string.match(name, "^Boss%d+TargetFrame") ~= nil
end

function L:StyleCastBarIcon(icon)
	if not self.enabled or not icon then
		return
	end
	local parent = icon.GetParent and icon:GetParent()
	-- BossNTargetFrame is protected. Even cosmetic children must stay entirely
	-- Blizzard-owned or a later combat Show/Hide can inherit addon taint.
	if not parent or IsBossTargetRegion(icon) or IsBossTargetRegion(parent) then
		return
	end

	if not icon.suiLortiCastSaved then
		local saved = {}
		if icon.GetTexCoord then
			saved.uLx, saved.uLy, saved.lLx, saved.lLy, saved.uRx, saved.uRy, saved.lRx, saved.lRy = icon:GetTexCoord()
		end
		icon.suiLortiCastSaved = saved
	end

	if icon.SetTexCoord then
		icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	end

	local border = parent.suiLortiCastIconBorder
	if not border then
		border = parent:CreateTexture(nil, "OVERLAY")
		parent.suiLortiCastIconBorder = border
	end
	border:SetTexture(self.cfg.textures.normal)
	border:SetTexCoord(0, 1, 0, 1)
	border:ClearAllPoints()
	border:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2)
	border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
	local r, g, b, a = self.GetColor()
	border:SetVertexColor(r, g, b, a)
	if icon.IsShown and icon:IsShown() then
		border:Show()
	else
		border:Hide()
	end
end

function L:RestoreCastBarIcon(icon)
	if not icon then
		return
	end
	local saved = icon.suiLortiCastSaved
	if saved and icon.SetTexCoord and saved.uLx then
		icon:SetTexCoord(saved.uLx, saved.uLy, saved.lLx, saved.lLy, saved.uRx, saved.uRy, saved.lRx, saved.lRy)
	elseif icon.SetTexCoord then
		icon:SetTexCoord(0, 1, 0, 1)
	end
	local parent = icon.GetParent and icon:GetParent()
	local border = parent and parent.suiLortiCastIconBorder
	if border then
		border:Hide()
	end
end

function L:ApplyCastBarIcons()
	local i, name
	for i = 1, #self.castBarIconNames do
		name = self.castBarIconNames[i]
		self:StyleCastBarIcon(_G[name])
	end
end

function L:RestoreCastBarIcons()
	local i, name
	for i = 1, #self.castBarIconNames do
		name = self.castBarIconNames[i]
		self:RestoreCastBarIcon(_G[name])
	end
end

function L:StyleCastBarFromFrame(bar)
	if not bar then
		return
	end
	local icon = bar.Icon
	if not icon then
		local name = bar.GetName and bar:GetName()
		icon = name and _G[name .. "Icon"]
	end
	self:StyleCastBarIcon(icon)
end
