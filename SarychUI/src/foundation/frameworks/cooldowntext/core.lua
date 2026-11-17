-- Shared countdown presentation for live cooldowns, native labels and previews.
local F = {}
SarychUI.CooldownText = F
local floor, ceil, min, max, format = math.floor, math.ceil, math.min, math.max, string.format
local ru = GetLocale and GetLocale() == "ruRU"
local day, hour, minute = ru and " д." or "d", ru and " ч." or "h", ru and "м" or "m"

function F.Color(seconds, settings, baseColor)
    local color = baseColor or settings.defaultColor or {1, 1, 1, 1}
    if settings.lastFiveSecondsRed and seconds > 0 and floor(seconds + .5) <= 5 then
        return {1, 0, 0, color[4] or 1}
    end
    return color
end

function F.Format(seconds, settings, appearance, context)
    local color = F.Color(seconds, settings, appearance and appearance.baseColor)
    local small, medium, large = settings.fontSizeSmall or 14, settings.fontSizeMedium or 12, settings.fontSizeLarge or 12
    context = (appearance and appearance.context) or context or "other"
    local locations = settings.tenthsLocations
    local threshold = max(1, min(10, tonumber(settings.tenthsThreshold) or 1))
    -- Existing compact aura/tick views keep their own precision while the
    -- global override is off. When enabled, its threshold and exclusions win.
    local tenths = settings.showTenths and (not locations or locations[context] ~= false)
    if not settings.showTenths and appearance and appearance.decimalThreshold then
        threshold = appearance.decimalThreshold
        tenths = true
    end
    if tenths and seconds <= threshold then
        -- Never report zero while the countdown is still running.
        return format(" %.1f ", seconds > 0 and max(.1, seconds) or 0), color, .05, small
    end
    if appearance and appearance.compactUnits then
        if seconds <= 60 then
            return format(" %d ", ceil(seconds)), color, .1, small
        elseif seconds <= 3600 then
            return format("%d%s", ceil(seconds / 60), appearance.minuteSuffix or minute), color, 1, medium
        end
        return format("%d%s", ceil(seconds / 3600), appearance.hourSuffix or hour), color, 60, large
    end
    if seconds >= 86400 then
        return format(" %d%s ", floor(seconds / 86400 + .5), day), color, 3600, large
    elseif seconds >= 3600 then
        return format(" %d%s ", floor(seconds / 3600 + .5), hour), color, 60, large
    elseif seconds >= 600 then
        return format(" %d%s ", floor(seconds / 60 + .5), minute), color, 10, large
    elseif seconds >= 60 then
        return format(" %d:%02d ", floor(seconds / 60), floor(seconds % 60)), color, 1, medium
    elseif seconds >= 10 then
        return format(" %02d ", floor(seconds + .5)), color, .1, small
    end
    return format(" %d ", seconds > 0 and max(1, floor(seconds + .5)) or 0), color, .1, small
end
