-- SarychUI nameplate scale for classic WoW plates (VirtualPlates-style).

local moduleName = "health_indicators"
local module = SarychUI:GetModule(moduleName)
if not module then return end

local SCALE_MIN = 0.5
local SCALE_MAX = 3
local SCALE_DEFAULT = 1
local FLASH = [[Interface\TargetingFrame\UI-TargetingFrame-Flash]]

local WorldFrameGetChildren = WorldFrame.GetChildren
local InCombat = false
local classicStarted = false
local restorePending = false
local driver = CreateFrame("Frame")
driver:Hide()
local events = CreateFrame("Frame")

local Plates = {}
local PlatesVisible = {}

local function GetDB()
	if SarychUI.GetModuleProfile then
		return SarychUI:GetModuleProfile(moduleName)
	end
	local profile = SarychUI.db and SarychUI.db.profile
	return profile and profile.modules and profile.modules[moduleName]
end

local function GetMode()
	if SarychUI.GetNameplateMode then
		return SarychUI:GetNameplateMode()
	end
	return "classic"
end

function module:GetNameplateScale()
	local db = GetDB()
	local scale = db and db.enabled ~= false and tonumber(db.scale) or SCALE_DEFAULT
	if scale < SCALE_MIN then
		scale = SCALE_MIN
	elseif scale > SCALE_MAX then
		scale = SCALE_MAX
	end
	return scale
end

function module:GetClassicPlateVisual(plate)
	return plate and plate._suiClassicVisual
end

local function AttachAutolosText(plate, visual)
	local fs = plate and plate.fontStringRange
	if not fs or not visual or not fs.SetParent then
		return
	end
	if fs.GetParent and fs:GetParent() == visual then
		return
	end
	fs:SetParent(visual)
end

local function ApplyClassicPlateScale(plate)
	local scale = module:GetNameplateScale()
	local visual = plate and Plates[plate]
	if not visual then
		return
	end
	visual:SetScale(scale)
	AttachAutolosText(plate, visual)
	if not InCombat then
		plate:SetSize(visual.BaseWidth * scale, visual.BaseHeight * scale)
	end
end

local function ApplyClassicScaleAll()
	for plate in pairs(Plates) do
		ApplyClassicPlateScale(plate)
	end
end

local function ResetPoint(plate, region, point, relFrame, ...)
	if relFrame == plate then
		region:SetPoint(point, Plates[plate], ...)
	end
end

local function PlateOnShow(plate)
	if not classicStarted then return end
	local visual = Plates[plate]
	if not visual then
		return
	end
	PlatesVisible[plate] = visual
	visual:Show()
	AttachAutolosText(plate, visual)
	ApplyClassicPlateScale(plate)
	for index = 1, #visual.regions do
		local region = visual.regions[index]
		if region and region.GetNumPoints then
			for point = 1, region:GetNumPoints() do
				ResetPoint(plate, region, region:GetPoint(point))
			end
		end
	end
end

local function PlateOnHide(plate)
	PlatesVisible[plate] = nil
	local visual = Plates[plate]
	if visual then
		visual:Hide()
	end
end

local function ShouldKeepOnPlate(child, visual)
	if not child or child == visual then
		return true
	end
	if child._suiPlateAura then
		return true
	end
	return false
end

local function ReparentChildren(plate, ...)
	local visual = Plates[plate]
	for index = 1, select("#", ...) do
		local child = select(index, ...)
		if not ShouldKeepOnPlate(child, visual) then
			visual.originalLevels[child] = child:GetFrameLevel()
			local levelOffset = child:GetFrameLevel() - plate:GetFrameLevel()
			child:SetParent(visual)
			child:SetFrameLevel(visual:GetFrameLevel() + levelOffset)
			visual.regions[#visual.regions + 1] = child
		end
	end
end

local function ReparentRegions(plate, ...)
	local visual = Plates[plate]
	for index = 1, select("#", ...) do
		local region = select(index, ...)
		region:SetParent(visual)
		visual.regions[#visual.regions + 1] = region
	end
end

local function PlateAdd(plate)
	if Plates[plate] or plate.UnitFrame then
		return
	end

	local visual = CreateFrame("Frame", nil, plate)
	Plates[plate] = visual
	visual.originalLevels = {}
	visual.regions = {}
	plate._suiClassicVisual = visual
	visual:Hide()
	visual:SetPoint("TOP")
	visual.BaseWidth, visual.BaseHeight = plate:GetWidth(), plate:GetHeight()
	if not visual.BaseWidth or visual.BaseWidth == 0 then
		visual.BaseWidth = 128
	end
	if not visual.BaseHeight or visual.BaseHeight == 0 then
		visual.BaseHeight = 32
	end
	visual:SetSize(visual.BaseWidth, visual.BaseHeight)

	ReparentChildren(plate, plate:GetChildren())
	ReparentRegions(plate, plate:GetRegions())
	visual:EnableDrawLayer("HIGHLIGHT")

	if plate:GetScript("OnShow") then
		plate:HookScript("OnShow", PlateOnShow)
	else
		plate:SetScript("OnShow", PlateOnShow)
	end
	if plate:GetScript("OnHide") then
		plate:HookScript("OnHide", PlateOnHide)
	else
		plate:SetScript("OnHide", PlateOnHide)
	end
	if plate:IsVisible() then
		PlateOnShow(plate)
	end
end

local function PlatesScan(...)
	for index = 1, select("#", ...) do
		local frame = select(index, ...)
		if not Plates[frame] and not frame.UnitFrame then
			local region = frame:GetRegions()
			if region and region.GetObjectType and region:GetObjectType() == "Texture" and region.GetTexture and region:GetTexture() == FLASH then
				PlateAdd(frame)
			end
		end
	end
end

local childCount = 0
local function WorldFrameOnUpdate()
	local self = WorldFrame
	if GetMode() ~= "classic" then
		return
	end
	local newChildCount = self:GetNumChildren()
	if childCount ~= newChildCount then
		childCount = newChildCount
		PlatesScan(WorldFrameGetChildren(self))
	end
end

local function StartClassicScale()
	if classicStarted then
		return
	end
	classicStarted = true
    restorePending = true
	driver:SetScript("OnUpdate", WorldFrameOnUpdate)
    driver:Show()
    for plate, visual in pairs(Plates) do
        plate._suiClassicVisual = visual
        for _, region in ipairs(visual.regions) do
            region:SetParent(visual)
            if visual.originalLevels[region] then
                region:SetFrameLevel(visual:GetFrameLevel() + visual.originalLevels[region] - plate:GetFrameLevel())
            end
        end
        if plate:IsVisible() then PlateOnShow(plate) end
    end
	PlatesScan(WorldFrameGetChildren(WorldFrame))
	childCount = WorldFrame:GetNumChildren()
end

local function RestoreClassicPlates()
    if not restorePending then return end
    restorePending = false
    for plate, visual in pairs(Plates) do
        for _, region in ipairs(visual.regions) do
            region:SetParent(plate)
            if visual.originalLevels[region] then region:SetFrameLevel(visual.originalLevels[region]) end
            for i = 1, region:GetNumPoints() do
                local point, relative, relativePoint, x, y = region:GetPoint(i)
                if relative == visual then region:SetPoint(point, plate, relativePoint, x, y) end
            end
        end
        plate:SetSize(visual.BaseWidth, visual.BaseHeight)
        plate._suiClassicVisual = nil
        visual:SetScale(1)
        visual:Hide()
        PlatesVisible[plate] = nil
    end
end

function module:StopNameplateScale()
    classicStarted = false
    driver:SetScript("OnUpdate", nil)
    driver:Hide()
    events:UnregisterAllEvents()
    if restorePending and InCombatLockdown() and next(Plates) then
        -- Only restoration waits for combat; scanning stops immediately.
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        RestoreClassicPlates()
    end
end

function module:ApplyNameplateScale()
    local db = GetDB()
    if not db or db.enabled == false or GetMode() ~= "classic" then
        self:StopNameplateScale()
        return
    end
    InCombat = InCombatLockdown()
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    if InCombat and not classicStarted then return end
    StartClassicScale()
    ApplyClassicScaleAll()
    if SarychUI.NameplateDistancePreview and SarychUI.NameplateDistancePreview.RefreshAll then
        SarychUI.NameplateDistancePreview:RefreshAll()
    end
end

events:SetScript("OnEvent", function(_, event)
    InCombat = event == "PLAYER_REGEN_DISABLED"
    if not InCombat then module:ApplyNameplateScale() end
end)

function module:InitializeNameplateScale()
    self:ApplyNameplateScale()
end
