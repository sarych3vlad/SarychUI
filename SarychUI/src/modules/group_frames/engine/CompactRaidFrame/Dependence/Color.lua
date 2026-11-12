local Compat = select(2, ...).Compat
local CreateFromMixins = Compat.CreateFromMixins
SarychUI.Compat.ColorMixin = {};
function SarychUI.Compat.CreateColor(r, g, b, a)
    local color = CreateFromMixins(SarychUI.Compat.ColorMixin);
    color:OnLoad(r, g, b, a);
    return color;
end

function SarychUI.Compat.ColorMixin:OnLoad(r, g, b, a)
    self:SetRGBA(r, g, b, a);
end

function SarychUI.Compat.ColorMixin:IsEqualTo(otherColor)
    return self.r == otherColor.r
        and self.g == otherColor.g
        and self.b == otherColor.b
        and self.a == otherColor.a;
end

function SarychUI.Compat.ColorMixin:GetRGB()
    return self.r, self.g, self.b;
end

function SarychUI.Compat.ColorMixin:GetRGBAsBytes()
    return self.r * 255, self.g * 255, self.b * 255;
end

function SarychUI.Compat.ColorMixin:GetRGBA()
    return self.r, self.g, self.b, self.a;
end

function SarychUI.Compat.ColorMixin:GetRGBAAsBytes()
    return self.r * 255, self.g * 255, self.b * 255, (self.a or 1) * 255;
end

function SarychUI.Compat.ColorMixin:SetRGBA(r, g, b, a)
    self.r = r;
    self.g = g;
    self.b = b;
    self.a = a;
end

function SarychUI.Compat.ColorMixin:SetRGB(r, g, b)
    self:SetRGBA(r, g, b, nil);
end

function SarychUI.Compat.ColorMixin:GenerateHexColor()
    return ("ff%.2x%.2x%.2x"):format(self:GetRGBAsBytes());
end

function SarychUI.Compat.ColorMixin:GenerateHexColorMarkup()
    return "|c"..self:GenerateHexColor();
end

function SarychUI.Compat.ColorMixin:WrapTextInColorCode(text)
    return SarychUI.Compat.WrapTextInColorCode(text, self:GenerateHexColor());
end

function SarychUI.Compat.WrapTextInColorCode(text, colorHexString)
    return ("|c%s%s|r"):format(colorHexString, text);
end
