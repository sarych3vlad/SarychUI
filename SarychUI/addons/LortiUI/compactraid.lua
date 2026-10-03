-- Darken CompactRaidFrame chrome only when the embedded addon is enabled.

local L = SarychUI_LortiUI

function L:IsCompactRaidEnabled()
	if CompactRaidFrameEnabled == false then
		return false
	end
	local addon = SarychUI and SarychUI.addons and SarychUI.addons.CompactRaidFrame
	if addon and addon.IsRuntimeEnabled then
		return addon:IsRuntimeEnabled() and true or false
	end
	local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons
	if db and db.CompactRaidFrame then
		return db.CompactRaidFrame.enabled == true
	end
	return false
end

local function PaintTexture(tex, restore)
	if not tex then
		return
	end
	if restore then
		if L.originalColors[tex] then
			L:RestoreTexture(tex)
		end
	else
		L:DarkenTexture(tex)
	end
end

local function PaintRegions(frame, restore)
	if not frame or not frame.GetRegions then
		return
	end
	local i, region
	local n = frame:GetNumRegions() or 0
	for i = 1, n do
		region = select(i, frame:GetRegions())
		if region and region.GetObjectType and region:GetObjectType() == "Texture" then
			PaintTexture(region, restore)
		end
	end
end

local function PaintNamed(name, restore)
	PaintTexture(_G[name], restore)
end

function L:PaintCompactUnitFrame(frame, restore)
	if not frame then
		return
	end
	PaintTexture(frame.horizTopBorder, restore)
	PaintTexture(frame.horizBottomBorder, restore)
	PaintTexture(frame.vertLeftBorder, restore)
	PaintTexture(frame.vertRightBorder, restore)
	PaintTexture(frame.horizDivider, restore)
	PaintTexture(frame.background, restore)
	if restore then
		return
	end
	if not self.enabled then
		return
	end
	local i
	if frame.buffFrames then
		for i = 1, #frame.buffFrames do
			self:StyleAuraButton(frame.buffFrames[i], true)
		end
	end
	if frame.debuffFrames then
		for i = 1, #frame.debuffFrames do
			self:StyleAuraButton(frame.debuffFrames[i], true)
		end
	end
end

local function PaintChrome(restore)
	PaintRegions(CompactRaidFrameManager, restore)
	if CompactRaidFrameManagerDisplayFrame then
		PaintRegions(CompactRaidFrameManagerDisplayFrame, restore)
		PaintTexture(CompactRaidFrameManagerDisplayFrameHeaderDelineator, restore)
		PaintTexture(CompactRaidFrameManagerDisplayFrameFooterDelineator, restore)
	end
	if CompactRaidFrameManagerToggleButton then
		PaintTexture(CompactRaidFrameManagerToggleButton:GetNormalTexture(), restore)
		PaintTexture(CompactRaidFrameManagerToggleButton:GetPushedTexture(), restore)
		PaintTexture(CompactRaidFrameManagerToggleButton:GetHighlightTexture(), restore)
	end
	if CompactRaidFrameContainer then
		PaintRegions(CompactRaidFrameContainer.borderFrame or CompactRaidFrameContainerBorderFrame, restore)
	end
	PaintRegions(_G.CompactRaidFrameContainerBorderFrame, restore)

	local i, m, group
	for i = 1, 8 do
		group = _G["CompactRaidGroup" .. i]
		if group then
			PaintRegions(group.borderFrame, restore)
		end
		for m = 1, 5 do
			L:PaintCompactUnitFrame(_G["CompactRaidGroup" .. i .. "Member" .. m], restore)
		end
	end
	for i = 1, 5 do
		L:PaintCompactUnitFrame(_G["CompactPartyFrameMember" .. i], restore)
	end
	for i = 1, 80 do
		L:PaintCompactUnitFrame(_G["CompactRaidFrame" .. i], restore)
	end
end

function L:ApplyCompactRaid()
	if not self.enabled or not self:IsCompactRaidEnabled() then
		return
	end
	PaintChrome(false)
end

function L:RestoreCompactRaid()
	PaintChrome(true)
end

function L:InstallCompactRaidHooks()
	if self.compactRaidHooksInstalled then
		return
	end
	self.compactRaidHooksInstalled = true
	if not hooksecurefunc then
		return
	end
	if DefaultCompactUnitFrameSetup then
		hooksecurefunc("DefaultCompactUnitFrameSetup", function(frame)
			if L.enabled and L:IsCompactRaidEnabled() then
				L:PaintCompactUnitFrame(frame, false)
			end
		end)
	end
	if DefaultCompactMiniFrameSetup then
		hooksecurefunc("DefaultCompactMiniFrameSetup", function(frame)
			if L.enabled and L:IsCompactRaidEnabled() then
				L:PaintCompactUnitFrame(frame, false)
			end
		end)
	end
	if CompactUnitFrame_UpdateAuras then
		hooksecurefunc("CompactUnitFrame_UpdateAuras", function(frame)
			if L.enabled and L:IsCompactRaidEnabled() then
				L:PaintCompactUnitFrame(frame, false)
			end
		end)
	end
	if CompactRaidFrameContainer_OnLoad then
		hooksecurefunc("CompactRaidFrameContainer_OnLoad", function()
			if L.enabled then
				L:ApplyCompactRaid()
			end
		end)
	end
end
