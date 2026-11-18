SarychUI.Frameworks = SarychUI.Frameworks or {}

-- Legacy Texture/FontString regions inherit their parent's scale but do not
-- expose GetEffectiveScale themselves. Keep unknown geometry unknown.
function SarychUI.Frameworks.RegionEffectiveScale(region)
    for _ = 1, 8 do
        if not region then return end
        if region.GetEffectiveScale then return region:GetEffectiveScale() end
        region = region.GetParent and region:GetParent()
    end
end
