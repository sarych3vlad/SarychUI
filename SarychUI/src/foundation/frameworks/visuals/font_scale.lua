SarychUI.Frameworks = SarychUI.Frameworks or {}

-- The caller owns the unscaled font snapshot. Native and additional regions
-- use the same baseline, so applying a scale repeatedly never compounds it.
function SarychUI.Frameworks.ApplyFontScale(region, font, scale)
    font = font or { region:GetFont() }
    if font[1] and font[2] then
        region:SetFont(font[1], font[2] * scale, font[3])
    end
    return font
end
