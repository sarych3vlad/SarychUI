local SUI = SarychUI
local module = SUI.modules.tooltip_control
local frameId = "defaultTooltip"
local preview
local editProfile

local function Panel() return SUI.PositionDragPanel or SUI.CombatTextDragPanel end
local function BasePosition()
    -- FrameXML/GameTooltip.lua: GameTooltip_SetDefaultAnchor.
    return -(CONTAINER_OFFSET_X or 0) - 13, CONTAINER_OFFSET_Y or 70
end

function module:IsTooltipPositionEnabled()
    local value = self:GetDB().positioningEnabled
    return self:IsEnabled() and not self:IsDefaultTooltipHidden() and (value == 1 or value == true)
end

function module:UpdateTooltipPositionAnchor()
    if not preview then return end
    local drag = SUI.DragMode and SUI.DragMode:GetFrameData(frameId)
    if drag and drag.isMoving then return end
    local db = self:GetDB()
    local x, y = BasePosition()
    preview:ClearAllPoints()
    preview:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", x + (db.offsetX or 0), y + (db.offsetY or 0))
end

function module:EnsureTooltipPositionAnchor()
    if preview then return preview end
    preview = CreateFrame("Frame", "SarychUIDefaultTooltipAnchor", UIParent)
    preview:SetSize(240, 100)
    preview:SetScale(GameTooltip:GetScale())
    preview:SetFrameStrata("TOOLTIP")
    preview:EnableMouse(false)
    preview:Hide()
    self:UpdateTooltipPositionAnchor()
    if SUI.DragMode then
        SUI.DragMode:RegisterFrame(frameId, preview, {
            dragText = SUI:T("ui.tooltip.position_title"),
            dragPoint = "CENTER", preservePositionOnDisable = true,
            getPoint = function()
                local db = module:GetDB()
                local x, y = BasePosition()
                return {"BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", x + (db.offsetX or 0), y + (db.offsetY or 0)}
            end,
            onPositionChanged = function(point, relativePoint, x, y)
                local panel = Panel()
                if panel and panel:OnDragPosition(frameId, x, y, point, relativePoint) then return end
                local bx, by = BasePosition()
                local db = module:GetDB()
                db.offsetX, db.offsetY = x - bx, y - by
                module:UpdateTooltipPositionAnchor()
            end,
        })
    end
    local panel = Panel()
    if panel then
        panel:RegisterFrame(frameId, {
            title = "ui.tooltip.position_title", moduleKey = "tooltip_control",
            getConfig = function() return editProfile or module:GetDB() end,
            xKey = "offsetX", yKey = "offsetY", dragFlag = "showDragFrame",
            defaultX = 0, defaultY = 0, min = -3000, max = 3000,
            point = "BOTTOMRIGHT", relativePoint = "BOTTOMRIGHT",
            resolveFramePosition = function(x, y) local bx, by = BasePosition(); return x + bx, y + by end,
            fromFramePosition = function(x, y) local bx, by = BasePosition(); return x - bx, y - by end,
            onApply = function() module:UpdateTooltipPositionAnchor(); module:RefreshDefaultTooltipPosition() end,
            onClosed = function()
                editProfile = nil
                preview:Hide()
                module:RefreshOptions()
            end,
        })
    end
    return preview
end

function module:ApplyDefaultTooltipPosition(tooltip)
    if not self:IsTooltipPositionEnabled() then return end
    local anchor = self:EnsureTooltipPositionAnchor()
    self:UpdateTooltipPositionAnchor()
    tooltip:ClearAllPoints()
    tooltip:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
end

function module:StopTooltipPositionDrag()
    local panel = Panel()
    if panel and panel:IsOpen() and panel:GetFrameId() == frameId then panel:Close(false) end
    if SUI.DragMode then SUI.DragMode:EnableEditMode(frameId, false, false, false) end
    if preview then preview:Hide() end
    editProfile = nil
    self:GetDB().showDragFrame = 0
end

function module:ApplyTooltipPosition()
    if editProfile and editProfile ~= self:GetDB() then self:StopTooltipPositionDrag() end
    local panel = Panel()
    if not panel or not panel:IsOpen() or panel:GetFrameId() ~= frameId then
        self:GetDB().showDragFrame = 0
    end
    if self:IsTooltipPositionEnabled() then
        self:EnsureTooltipHooks()
        if preview then self:UpdateTooltipPositionAnchor() end
    else
        self:StopTooltipPositionDrag()
    end
    self:RefreshDefaultTooltipPosition()
end

function module:ToggleTooltipPositionDrag()
    if not self:IsTooltipPositionEnabled() then return end
    local panel = Panel()
    if not panel or not SUI.DragMode then return end
    if panel:IsOpen() and panel:GetFrameId() == frameId then self:StopTooltipPositionDrag()
    else
        self:EnsureTooltipPositionAnchor()
        -- Close the previous editor before capturing this profile's live settings.
        if panel:IsOpen() then panel:Close(false) end
        editProfile = self:GetDB()
        editProfile.showDragFrame = 1
        preview:Show()
        panel:Toggle(frameId, true)
    end
    self:RefreshOptions()
end

function module:SetTooltipPositionOffset(key, value)
    self:GetDB()[key] = value
    local panel = Panel()
    local db = self:GetDB()
    if panel then panel:SyncDraftIfOpen(frameId, db.offsetX or 0, db.offsetY or 0) end
    self:ApplyTooltipPosition()
end
