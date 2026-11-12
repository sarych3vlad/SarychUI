local CompatMath = select(2, ...).Compat.Math
local Round = CompatMath.Round
local ClampedPercentageBetween = CompatMath.ClampedPercentageBetween
local Lerp = CompatMath.Lerp
SarychUI.Compat.PixelUtil = {};

function SarychUI.Compat.PixelUtil.GetPixelToUIUnitFactor()
    local physicalWidth, physicalHeight = string.match((({GetScreenResolutions()})[GetCurrentResolution()] or ""), "(%d+).-(%d+)");
    physicalWidth, physicalHeight  = tonumber(physicalWidth),tonumber(physicalHeight)
    -- Windowed mode may report resolution index zero. gxResolution is the
    -- configured pixel size; never divide by nil or zero.
    if not physicalHeight or physicalHeight <= 0 then
        physicalHeight = tonumber((GetCVar("gxResolution") or ""):match("%d+[xX](%d+)")) or 768
    end
    return 768.0 / math.max(1, physicalHeight);
end

function SarychUI.Compat.PixelUtil.GetNearestPixelSize(uiUnitSize, layoutScale, minPixels)
    if uiUnitSize == 0 and (not minPixels or minPixels == 0) then
        return 0;
    end

    local uiUnitFactor = SarychUI.Compat.PixelUtil.GetPixelToUIUnitFactor();
    local numPixels = Round((uiUnitSize * layoutScale) / uiUnitFactor);
    if minPixels then
        if uiUnitSize < 0.0 then
            if numPixels > -minPixels then
                numPixels = -minPixels;
            end
        else
            if numPixels < minPixels then
                numPixels = minPixels;
            end
        end
    end

    return numPixels * uiUnitFactor / layoutScale;
end

function SarychUI.Compat.PixelUtil.SetWidth(region, width, minPixels)
    region:SetWidth(SarychUI.Compat.PixelUtil.GetNearestPixelSize(width, region:GetEffectiveScale(), minPixels));
end

function SarychUI.Compat.PixelUtil.SetHeight(region, height, minPixels)
    region:SetHeight(SarychUI.Compat.PixelUtil.GetNearestPixelSize(height, region:GetEffectiveScale(), minPixels));
end

function SarychUI.Compat.PixelUtil.SetSize(region, width, height, minWidthPixels, minHeightPixels)
    SarychUI.Compat.PixelUtil.SetWidth(region, width, minWidthPixels);
    SarychUI.Compat.PixelUtil.SetHeight(region, height, minHeightPixels);
end

function SarychUI.Compat.PixelUtil.SetPoint(region, point, relativeTo, relativePoint, offsetX, offsetY, minOffsetXPixels, minOffsetYPixels)
    region:SetPoint(point, relativeTo, relativePoint,
        SarychUI.Compat.PixelUtil.GetNearestPixelSize(offsetX, region:GetEffectiveScale(), minOffsetXPixels),
        SarychUI.Compat.PixelUtil.GetNearestPixelSize(offsetY, region:GetEffectiveScale(), minOffsetYPixels)
    );
end

function SarychUI.Compat.PixelUtil.SetStatusBarValue(statusBar, value)
    local width = statusBar:GetWidth();
    if width and width > 0.0 then
        local min, max = statusBar:GetMinMaxValues();
        local percent = ClampedPercentageBetween(value, min, max);
        if percent == 0.0 or percent == 1.0 then
            statusBar:SetValue(value);
        else
            local numPixels = SarychUI.Compat.PixelUtil.GetNearestPixelSize(statusBar:GetWidth() * percent, statusBar:GetEffectiveScale());
            local roundedValue = Lerp(min, max, numPixels / width);
            statusBar:SetValue(roundedValue);
        end
    else
        statusBar:SetValue(value);
    end
end
