SarychUI.Compat.UIMenuButtonStretchMixin = {}

function SarychUI.Compat.UIMenuButtonStretchMixin:SetTextures(texture)
    self.TopLeft:SetTexture(texture);
    self.TopRight:SetTexture(texture);
    self.BottomLeft:SetTexture(texture);
    self.BottomRight:SetTexture(texture);
    self.TopMiddle:SetTexture(texture);
    self.MiddleLeft:SetTexture(texture);
    self.MiddleRight:SetTexture(texture);
    self.BottomMiddle:SetTexture(texture);
    self.MiddleMiddle:SetTexture(texture);
end

function SarychUI.Compat.UIMenuButtonStretchMixin:OnMouseDown(button)
    if ( SarychUI.Compat.Widgets.IsEnabled(self) ) then
        self:SetTextures("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\Buttons\\UI-Silver-Button-Down");
        if ( self.Icon ) then
            if ( not self.Icon.oldPoint ) then
                local point, relativeTo, relativePoint, x, y = self.Icon:GetPoint(1);
                self.Icon.oldPoint = point;
                self.Icon.oldX = x;
                self.Icon.oldY = y;
            end
            self.Icon:SetPoint(self.Icon.oldPoint, self.Icon.oldX + 1, self.Icon.oldY - 1);
        end
    end
end

function SarychUI.Compat.UIMenuButtonStretchMixin:OnMouseUp(button)
    if ( SarychUI.Compat.Widgets.IsEnabled(self) ) then
        self:SetTextures("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\Buttons\\UI-Silver-Button-Up");
        if ( self.Icon and self.Icon.oldPoint ) then
            self.Icon:SetPoint(self.Icon.oldPoint, self.Icon.oldX, self.Icon.oldY);
        end
    end
end

function SarychUI.Compat.UIMenuButtonStretchMixin:OnShow()
    -- we need to reset our textures just in case we were hidden before a mouse up fired
    self:SetTextures("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\Buttons\\UI-Silver-Button-Up");
end

function SarychUI.Compat.UIMenuButtonStretchMixin:OnEnable()
    self:SetTextures("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\Buttons\\UI-Silver-Button-Up");
end

function SarychUI.Compat.UIMenuButtonStretchMixin:OnEnter()
    if(self.tooltipText ~= nil) then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
        GameTooltip:SetText(self.tooltipText, 1, 1, 1);
        GameTooltip:Show();
    end
end

function SarychUI.Compat.UIMenuButtonStretchMixin:OnLeave()
    if(self.tooltipText ~= nil) then
        GameTooltip:Hide();
    end
end

-- Native 3.3.5 has inline button scripts, not retail UIPanelButton_On* functions.
function SarychUI.Compat.PanelButtonSetState(button, pressed)
    local texture
    if not SarychUI.Compat.Widgets.IsEnabled(button) then
        texture = "Interface\\Buttons\\UI-Panel-Button-Disabled"
    elseif pressed then
        texture = "Interface\\Buttons\\UI-Panel-Button-Down"
    else
        texture = "Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\Buttons\\UI-Panel-Button-Up"
    end
    button.Left:SetTexture(texture)
    button.Middle:SetTexture(texture)
    button.Right:SetTexture(texture)
end

function SarychUI.Compat.PanelButtonOnLoad(button)
    -- relativeKey is not available in stock 3.3.5 FrameXML.
    button.Middle:ClearAllPoints()
    button.Middle:SetPoint("TOPLEFT", button.Left, "TOPRIGHT", 0, 0)
    button.Middle:SetPoint("BOTTOMRIGHT", button.Right, "BOTTOMLEFT", 0, 0)
    SarychUI.Compat.PanelButtonSetState(button, false)
end
