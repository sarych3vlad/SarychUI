local Style = SarychUI_InterfaceStyle
local tinted = setmetatable({}, { __mode = "k" })
local castIcons = setmetatable({}, { __mode = "k" })

-- The original dark skin tinted Blizzard artwork in these groups.
local unitFrames = {
	"PlayerFrameTexture", "TargetFrameTextureFrameTexture", "PetFrameTexture",
	"FocusFrameTextureFrameTexture", "TargetFrameToTTextureFrameTexture",
	"FocusFrameToTTextureFrameTexture", "CastingBarFrameBorder",
	"TargetFrameSpellBarBorder", "FocusFrameSpellBarBorder",
	"TargetFrameSpellBarBorderShield", "FocusFrameSpellBarBorderShield",
	"RuneButtonIndividual1BorderTexture", "RuneButtonIndividual2BorderTexture",
	"RuneButtonIndividual3BorderTexture", "RuneButtonIndividual4BorderTexture",
	"RuneButtonIndividual5BorderTexture", "RuneButtonIndividual6BorderTexture",
	"MinimapBorder", "MinimapBorderTop", "MiniMapMailBorder",
	"MiniMapBattlefieldBorder", "MiniMapLFGFrameBorder",
	"MiniMapTrackingButtonBorder", "MiniMapWorldBorder",
	"MiniMapMeetingStoneBorder", "MiniMapRecordingBorder",
	"CharacterFrameTitleBg", "CharacterFrameBg",
}
for i = 1, 4 do
	unitFrames[#unitFrames + 1] = "PartyMemberFrame" .. i .. "Texture"
	unitFrames[#unitFrames + 1] = "PartyMemberFrame" .. i .. "PetFrameTexture"
end

local bars = {
	"BonusActionBarTexture0", "BonusActionBarTexture1", "BonusActionBarTexture",
	"MainMenuXPBarTextureLeftCap", "MainMenuXPBarTextureRightCap", "MainMenuXPBarTextureMid",
	"SlidingActionBarTexture0", "SlidingActionBarTexture1",
	"StanceBarLeft", "StanceBarMiddle", "StanceBarRight",
	"ShapeshiftBarLeft", "ShapeshiftBarMiddle", "ShapeshiftBarRight",
}
for _, prefix in ipairs({ "MainMenuBarTexture", "MainMenuMaxLevelBar", "MainMenuXPBarTexture",
	"ReputationWatchBarTexture", "ReputationXPBarTexture" }) do
	for i = 0, 3 do bars[#bars + 1] = prefix .. i end
end

local arena = {}
for i = 1, 5 do
	for _, suffix in ipairs({ "Texture", "SpecBorder", "PetFrameTexture" }) do
		arena[#arena + 1] = "ArenaEnemyFrame" .. i .. suffix
	end
	for _, suffix in ipairs({ "Texture", "SpecBorder" }) do
		arena[#arena + 1] = "ArenaPrepFrame" .. i .. suffix
	end
end

local pathTargets = {
	["interface\\characterframe\\totemborder"] = true,
	["interface\\minimap\\minimap-trackingborder"] = true,
}

local function TintList(list)
	for _, name in ipairs(list) do Style:TintTexture(_G[name]) end
end

local function TintFirstRegion(frame)
	if frame and frame.GetRegions then Style:TintTexture(frame:GetRegions()) end
end

local function TintPathRegions(frame, depth)
	if not frame or not frame.GetRegions then return end
	for _, region in ipairs({ frame:GetRegions() }) do
		if region and region.GetTexture and region.GetObjectType
			and region:GetObjectType() == "Texture" then
			local path = region:GetTexture()
			if type(path) == "string" then
				path = path:lower():gsub("/", "\\"):gsub("%.blp$", ""):gsub("%.tga$", "")
				if pathTargets[path] then Style:TintTexture(region) end
			end
		end
	end
	if depth < 2 and frame.GetChildren then
		for _, child in ipairs({ frame:GetChildren() }) do TintPathRegions(child, depth + 1) end
	end
end

function Style:TintTexture(region)
	if not self.enabled
		or not region or not region.SetVertexColor or not region.GetVertexColor then return end
	local state = tinted[region]
	if not state then
		local r, g, b, a = region:GetVertexColor()
		state = { setter = region.SetVertexColor, color = { r or 1, g or 1, b or 1, a or 1 } }
		tinted[region] = state
		region.SetVertexColor = function(tex, r2, g2, b2, a2)
			state.color = { r2 or 1, g2 or 1, b2 or 1, a2 or 1 }
			if Style.enabled then
				local r, g, b, a = Style.GetColor()
				return state.setter(tex, r, g, b, (a2 or 1) * a)
			end
			return state.setter(tex, r2, g2, b2, a2)
		end
	end
	local r, g, b, a = Style.GetColor()
	state.setter(region, r, g, b, state.color[4] * a)
end

function Style:ApplyFrames()
	if not self.enabled then return end
	TintList(unitFrames)
	TintList(bars)
	TintList(arena)
	TintList({ "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap" })
	TintFirstRegion(_G.TimeManagerClockButton)
	TintFirstRegion(_G.GameTimeFrame)
	for i = 1, 4 do TintPathRegions(_G["TotemFrameTotem" .. i], 0) end
	if _G.Minimap and Minimap.GetChildren then
		for _, child in ipairs({ Minimap:GetChildren() }) do TintPathRegions(child, 0) end
	end
	local lib = LibStub and LibStub("LibDBIcon-1.0", true)
	if lib and lib.objects then
		for _, button in pairs(lib.objects) do TintPathRegions(button, 0) end
		if not self.minimapHookInstalled and hooksecurefunc and lib.Register then
			self.minimapHookInstalled = true
			hooksecurefunc(lib, "Register", function()
				if Style.enabled then Style:ApplyFrames() end
			end)
		end
	end
	local menu = SarychUI.modules and SarychUI.modules.mainmenubar
	local artwork = menu and menu.BFAStyle and menu.BFAStyle.artwork
	if artwork then for _, region in pairs(artwork) do self:TintTexture(region) end end
	for _, name in ipairs({ "CastingBarFrameIcon", "TargetFrameSpellBarIcon",
		"FocusFrameSpellBarIcon", "PetCastingBarFrameIcon" }) do
		self:StyleCastBarIcon(_G[name])
	end
	if not self.frameEvents then
		self.frameEvents = CreateFrame("Frame")
		self.frameEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
		self.frameEvents:RegisterEvent("ADDON_LOADED")
		self.frameEvents:SetScript("OnEvent", function()
			if Style.enabled then
				Style:ApplyFrames()
				Style:ApplyCompactRaid()
				Style:ApplyAuras()
			end
		end)
		if hooksecurefunc then
			for _, name in ipairs({ "CastingBarFrame_OnEvent", "CastingBarFrame_OnShow" }) do
				if _G[name] then
					hooksecurefunc(name, function(bar)
						if not Style.enabled or not bar then return end
						local name2 = bar.GetName and bar:GetName()
						Style:StyleCastBarIcon(bar.Icon or (name2 and _G[name2 .. "Icon"]))
					end)
				end
			end
		end
	end
end

function Style:StyleCastBarIcon(icon)
	if not self.enabled or self:GetTextureMode() ~= "black" or not icon then return end
	local name = icon.GetName and icon:GetName()
	if name and name:match("^Boss%d+TargetFrame") then return end
	local parent = icon.GetParent and icon:GetParent()
	if not parent or not parent.CreateTexture then return end
	local state = castIcons[icon]
	if not state then
		state = { coords = icon.GetTexCoord and { icon:GetTexCoord() } }
		state.border = parent:CreateTexture(nil, "OVERLAY")
		castIcons[icon] = state
	end
	icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	local border = state.border
	border:SetTexture(self:GetTextureMode() == "black" and self.textures.normal
		or [[Interface\Buttons\UI-Quickslot2]])
	border:SetTexCoord(0, 1, 0, 1)
	border:ClearAllPoints()
	border:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2)
	border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
	local _, _, _, a = self.GetColor()
	local value = self:GetGlossBrightness()
	border:SetVertexColor(value, value, value, a)
	if icon.IsShown and not icon:IsShown() then border:Hide() else border:Show() end
end

local function TintFrameRegions(frame)
	if not frame or not frame.GetRegions then return end
	for _, region in ipairs({ frame:GetRegions() }) do
		if region and region.GetObjectType and region:GetObjectType() == "Texture" then
			Style:TintTexture(region)
		end
	end
end

function Style:ApplyCompactRaid()
	if not self.enabled or CompactRaidFrameEnabled == false then return end
	local addon = SarychUI.addons and SarychUI.addons.CompactRaidFrame
	if addon and addon.IsRuntimeEnabled and not addon:IsRuntimeEnabled() then return end
	TintFrameRegions(_G.CompactRaidFrameManager)
	TintFrameRegions(_G.CompactRaidFrameManagerDisplayFrame)
	TintFrameRegions(_G.CompactRaidFrameContainerBorderFrame)
	for _, name in ipairs({ "CompactRaidFrameManagerDisplayFrameHeaderDelineator",
		"CompactRaidFrameManagerDisplayFrameFooterDelineator" }) do
		self:TintTexture(_G[name])
	end
	local toggle = _G.CompactRaidFrameManagerToggleButton
	if toggle then
		for _, method in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture" }) do
			if toggle[method] then self:TintTexture(toggle[method](toggle)) end
		end
	end
	local function TintUnit(frame)
		if not frame then return end
		for _, field in ipairs({ "horizTopBorder", "horizBottomBorder", "vertLeftBorder",
			"vertRightBorder", "horizDivider", "background" }) do
			self:TintTexture(frame[field])
		end
		for _, field in ipairs({ "buffFrames", "debuffFrames" }) do
			if frame[field] then
				for _, button in ipairs(frame[field]) do self:StyleAuraButton(button) end
			end
		end
	end
	for i = 1, 8 do
		local group = _G["CompactRaidGroup" .. i]
		if group then TintFrameRegions(group.borderFrame) end
		for member = 1, 5 do TintUnit(_G["CompactRaidGroup" .. i .. "Member" .. member]) end
	end
	for i = 1, 80 do TintUnit(_G["CompactRaidFrame" .. i]) end
	for i = 1, 5 do TintUnit(_G["CompactPartyFrameMember" .. i]) end
	if not self.compactHooksInstalled and hooksecurefunc then
		self.compactHooksInstalled = true
		for _, name in ipairs({ "DefaultCompactUnitFrameSetup", "DefaultCompactMiniFrameSetup",
			"CompactRaidFrameContainer_OnLoad" }) do
			if _G[name] then hooksecurefunc(name, function() Style:ApplyCompactRaid() end) end
		end
	end
end

function Style:RestoreFrames()
	for icon, state in pairs(castIcons) do
		if state.coords then icon:SetTexCoord(unpack(state.coords)) end
		state.border:Hide()
		castIcons[icon] = nil
	end
	for region, state in pairs(tinted) do
		region.SetVertexColor = state.setter
		state.setter(region, unpack(state.color))
		tinted[region] = nil
	end
end

function Style:RefreshFrameGloss()
	if not self.enabled then return end
	for icon in pairs(castIcons) do self:StyleCastBarIcon(icon) end
end

function Style:RefreshFrames()
	if not self.enabled then return end
	local r, g, b, a = self.GetColor()
	for region, state in pairs(tinted) do
		state.setter(region, r, g, b, state.color[4] * a)
	end
end
