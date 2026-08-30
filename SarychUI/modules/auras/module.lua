-- SarychUI Auras Module
-- Focus/ToT aura hiding, dispel highlight settings, player buff frame management.
-- Extracted from frame so enabling/disabling Frames no longer gates these features.

local pairs = pairs
local moduleName = "auras"
local module = {}

SarychUI:RegisterModule(moduleName, module)

local AceEvent = LibStub("AceEvent-3.0")
local AceBucket = LibStub("AceBucket-3.0")
AceEvent:Embed(module)
AceBucket:Embed(module)

local L = SarychUI.L

local function GetSetting(key, default)
	local db = SarychUI.GetModuleProfile and SarychUI:GetModuleProfile(moduleName)
		or (SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName])
	if db and db[key] ~= nil then
		return db[key]
	end
	return default
end

local function ModuleDB()
	return SarychUI.GetModuleProfile and SarychUI:GetModuleProfile(moduleName)
		or (SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName])
end

--------------------------------------------------------------------
-- Focus / ToT aura hiding
--------------------------------------------------------------------
local focusAuraUpdateFrame = CreateFrame("Frame")
focusAuraUpdateFrame:Hide()

local function FocusAuraOnUpdate()
	if GetSetting("hideFocusAuras", 0) ~= 1 or not FocusFrame then
		return
	end
	for i = 1, 32 do
		local buff = _G["FocusFrameBuff" .. i]
		if buff and buff:IsShown() then
			buff:Hide()
			buff:SetAlpha(0)
			buff:SetScale(0.01)
		end
	end
	for i = 1, 16 do
		local debuff = _G["FocusFrameDebuff" .. i]
		if debuff and debuff:IsShown() then
			debuff:Hide()
			debuff:SetAlpha(0)
			debuff:SetScale(0.01)
		end
	end
end

focusAuraUpdateFrame:SetScript("OnUpdate", FocusAuraOnUpdate)

function module:UpdateFocusAuras()
	local db = ModuleDB()
	if not db or not db.enabled then
		focusAuraUpdateFrame:Hide()
		return
	end

	if GetSetting("hideFocusAuras", 0) == 1 then
		focusAuraUpdateFrame:Show()
		if FocusFrame then
			for i = 1, 32 do
				local buff = _G["FocusFrameBuff" .. i]
				if buff then
					buff:Hide()
					buff:SetAlpha(0)
					buff:SetScale(0.01)
				end
			end
			for i = 1, 16 do
				local debuff = _G["FocusFrameDebuff" .. i]
				if debuff then
					debuff:Hide()
					debuff:SetAlpha(0)
					debuff:SetScale(0.01)
				end
			end
		end
	else
		focusAuraUpdateFrame:Hide()
		if FocusFrame then
			for i = 1, 32 do
				local buff = _G["FocusFrameBuff" .. i]
				if buff then
					buff:SetAlpha(1)
					buff:SetScale(1)
				end
			end
			for i = 1, 16 do
				local debuff = _G["FocusFrameDebuff" .. i]
				if debuff then
					debuff:SetAlpha(1)
					debuff:SetScale(1)
				end
			end
		end
	end
end

function module:UpdateToTAuras()
	local db = ModuleDB()
	if not db or not db.enabled then
		return
	end

	if GetSetting("hideTargetOfTargetAuras", 0) == 1 then
		for _, v in pairs({ "TargetFrameToTDebuff", "FocusFrameToTDebuff" }) do
			for i = 1, 4 do
				local aura = _G[v .. i]
				if aura then
					aura:Hide()
					aura:SetScale(1e-4)
					aura:SetAlpha(0)
					aura.Show = function() end
				end
			end
		end
	else
		for _, v in pairs({ "TargetFrameToTDebuff", "FocusFrameToTDebuff" }) do
			for i = 1, 4 do
				local aura = _G[v .. i]
				if aura then
					aura:SetScale(1)
					aura:SetAlpha(1)
					aura.Show = nil
					aura:Show()
				end
			end
		end
	end
end

function module:ForceUpdateAuras()
	self:UpdateFocusAuras()
	self:UpdateToTAuras()
end

function module:RestoreAuras()
	focusAuraUpdateFrame:Hide()

	if FocusFrame then
		for i = 1, 32 do
			local buff = _G["FocusFrameBuff" .. i]
			if buff then
				buff:SetAlpha(1)
				buff:SetScale(1)
				buff.Show = nil
				buff:Show()
			end
		end
		for i = 1, 16 do
			local debuff = _G["FocusFrameDebuff" .. i]
			if debuff then
				debuff:SetAlpha(1)
				debuff:SetScale(1)
				debuff.Show = nil
				debuff:Show()
			end
		end
	end

	for _, v in pairs({ "TargetFrameToTDebuff", "FocusFrameToTDebuff" }) do
		for i = 1, 4 do
			local aura = _G[v .. i]
			if aura then
				aura:SetScale(1)
				aura:SetAlpha(1)
				aura.Show = nil
				aura:Show()
			end
		end
	end
end

--------------------------------------------------------------------
-- Player buff frame management (ConsolidatedBuffs / BuffFrame)
--------------------------------------------------------------------
local buffFrameBlizzardDefaultPosition = nil

function module:SaveDefaultBuffPosition()
	if ConsolidatedBuffs and not buffFrameBlizzardDefaultPosition then
		local point, relativeTo, relativePoint, xOfs, yOfs = ConsolidatedBuffs:GetPoint()
		if point then
			buffFrameBlizzardDefaultPosition = {
				point = point,
				relativeTo = relativeTo and relativeTo:GetName() or "UIParent",
				relativePoint = relativePoint,
				xOfs = xOfs,
				yOfs = yOfs,
			}
		end
	end

	if ConsolidatedBuffs and SarychUI.DragMode then
		if not SarychUI.DragMode:GetFrameData("buffFrame") then
			SarychUI.DragMode:RegisterFrame("buffFrame", ConsolidatedBuffs, {
				dragPoint = "TOPRIGHT",
				dragOffsetX = 0,
				dragOffsetY = 2.5,
				dragWidth = 280,
				dragHeight = 225,
				dragText = L and (L["Buffs"] or "Бафы") or "Бафы",
				scaleFrame = BuffFrame,
				interceptSetPoint = true,
				getPoint = function()
					return {
						GetSetting("buffFrameA", "TOPRIGHT"),
						UIParent,
						GetSetting("buffFrameR", "TOPRIGHT"),
						GetSetting("buffFrameX", -205),
						GetSetting("buffFrameY", -13),
					}
				end,
				getScale = function()
					return GetSetting("buffFrameScale", 1.0)
				end,
				onPositionChanged = function(point, relativePoint, xOfs, yOfs)
					local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
					if panel and panel.IsOpen and panel:IsOpen() and panel.OnDragPosition then
						if panel:OnDragPosition("buffFrame", xOfs, yOfs, point, relativePoint) then
							return
						end
					end
					local db = ModuleDB()
					if not db then return end
					db.buffFrameA = point
					db.buffFrameR = relativePoint
					db.buffFrameX = xOfs
					db.buffFrameY = yOfs
					if ConsolidatedBuffs and C_Timer and C_Timer.After then
						C_Timer.After(0.1, function()
							if BuffFrame_UpdateAllBuffAnchors then
								BuffFrame_UpdateAllBuffAnchors()
							end
							if UpdateBuffAnchors then
								UpdateBuffAnchors()
							end
						end)
					end
				end,
			})
		end
	end
end

function module:ApplyBuffManagement()
	local db = ModuleDB()
	if not db or not db.enabled then return end
	if not SarychUI.DragMode then return end
	if not ConsolidatedBuffs or not BuffFrame then return end

	if not SarychUI.DragMode:GetFrameData("buffFrame") then
		self:SaveDefaultBuffPosition()
	end

	local manageBuffs = GetSetting("manageBuffs", 0) == 1
	local showDragFrame = GetSetting("showBuffDragFrame", 0) == 1
	local showGrid = GetSetting("showBuffGrid", 0) == 1

	SarychUI.DragMode:EnableEditMode("buffFrame", manageBuffs, showDragFrame, showGrid)

	if manageBuffs then
		SarychUI.DragMode:SetFramePosition("buffFrame",
			GetSetting("buffFrameA", "TOPRIGHT"),
			GetSetting("buffFrameR", "TOPRIGHT"),
			GetSetting("buffFrameX", -205),
			GetSetting("buffFrameY", -13))
		SarychUI.DragMode:SetFrameScale("buffFrame", GetSetting("buffFrameScale", 1.0))
	end

	SarychUI.DragMode:ShowGrid(showGrid and manageBuffs)
end

function module:ResetBuffManagement()
	if not ConsolidatedBuffs then return end

	if SarychUI.DragMode then
		local data = SarychUI.DragMode:GetFrameData("buffFrame")
		if data and data.originalSetPoint then
			ConsolidatedBuffs.SetPoint = data.originalSetPoint
		end
		SarychUI.DragMode:EnableEditMode("buffFrame", false, false, false)
		SarychUI.DragMode:ShowGrid(false)
	end

	pcall(function()
		if ConsolidatedBuffs:IsMovable() then
			ConsolidatedBuffs:SetMovable(false)
		end
	end)
	pcall(function()
		if ConsolidatedBuffs:IsUserPlaced() then
			ConsolidatedBuffs:SetUserPlaced(false)
		end
	end)
	pcall(function()
		ConsolidatedBuffs:SetDontSavePosition(false)
	end)

	ConsolidatedBuffs:ClearAllPoints()
	if buffFrameBlizzardDefaultPosition then
		local relativeTo = _G[buffFrameBlizzardDefaultPosition.relativeTo] or UIParent
		pcall(function()
			ConsolidatedBuffs:SetPoint(
				buffFrameBlizzardDefaultPosition.point,
				relativeTo,
				buffFrameBlizzardDefaultPosition.relativePoint,
				buffFrameBlizzardDefaultPosition.xOfs,
				buffFrameBlizzardDefaultPosition.yOfs
			)
		end)
	else
		pcall(function()
			ConsolidatedBuffs:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -205, -13)
		end)
	end

	if BuffFrame then
		BuffFrame:SetScale(1.0)
	end
	if ConsolidatedBuffs then
		ConsolidatedBuffs:SetScale(1.0)
	end
end

function module:ResetBuffManagementToDefaults()
	local db = ModuleDB()
	if not db then return end
	db.buffFrameA = "TOPRIGHT"
	db.buffFrameR = "TOPRIGHT"
	db.buffFrameX = -205
	db.buffFrameY = -13
	db.buffFrameScale = 1.0

	if SarychUI.DragMode then
		SarychUI.DragMode:SetFramePosition("buffFrame", "TOPRIGHT", "TOPRIGHT", -205, -13)
		SarychUI.DragMode:SetFrameScale("buffFrame", 1.0)
	end
	self:ApplyBuffManagement()
end

--------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------
function module:Initialize()
end

function module:Enable()
	self.db = ModuleDB()
	if not self.db or not self.db.enabled then return end

	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("PLAYER_FOCUS_CHANGED", "OnEvent")
	self:RegisterBucketEvent("UNIT_AURA", 0.2, "OnAuraUpdate")

	if SarychUI.DragMode and ConsolidatedBuffs then
		self:SaveDefaultBuffPosition()
	end

	self:ApplyBuffManagement()
	self:ForceUpdateAuras()

	local toolsModule = SarychUI:GetModule("tools", true)
	if toolsModule and toolsModule.ApplyDispelHighlight then
		toolsModule:ApplyDispelHighlight()
	end
end

function module:Disable()
	self:UnregisterAllEvents()
	self:RestoreAuras()
	self:ResetBuffManagement()

	local toolsModule = SarychUI:GetModule("tools", true)
	if toolsModule and toolsModule.DisableDispelHighlight then
		toolsModule:DisableDispelHighlight()
	end
end

function module:RefreshConfig()
	if SarychUI.InvalidateModuleProfileCaches then
		SarychUI:InvalidateModuleProfileCaches()
	end
	self:Disable()
	self:Enable()
end

function module:ApplySettings()
	local db = ModuleDB()
	if db and db.enabled then
		self:ApplyBuffManagement()
		self:ForceUpdateAuras()
		local toolsModule = SarychUI:GetModule("tools", true)
		if toolsModule and toolsModule.ApplyDispelHighlight then
			toolsModule:ApplyDispelHighlight()
		end
	end
end

function module:OnEvent(event)
	if event == "PLAYER_ENTERING_WORLD" then
		self:SaveDefaultBuffPosition()
		self:ApplyBuffManagement()
		self:ForceUpdateAuras()
	elseif event == "PLAYER_FOCUS_CHANGED" then
		self:UpdateFocusAuras()
	end
end

function module:OnAuraUpdate(units)
	if not units then return end
	for unit in pairs(units) do
		if unit == "focus" then
			self:UpdateFocusAuras()
		end
	end
end
