SarychUI.Frameworks = SarychUI.Frameworks or {}

function SarychUI.Frameworks.TextureColor(color, fallback)
	local function Channel(value, default)
		return math.max(0, math.min(1, tonumber(value) or default))
	end
	return Channel(color and color.r, fallback), Channel(color and color.g, fallback),
		Channel(color and color.b, fallback), Channel(color and color.a, 1)
end

function SarychUI.Frameworks.ButtonBorderAlpha(enabled, value)
	return enabled and math.max(0, math.min(1, tonumber(value) or 0.4)) or 1
end

-- Shared by live artwork and previews; brightness affects RGB, never opacity.
function SarychUI.Frameworks.ModulateTextureColor(r, g, b, a, brightness, original)
	brightness = brightness or 1
	if original then
		r, g, b = r * (original[1] or 1), g * (original[2] or 1), b * (original[3] or 1)
		a = a * (original[4] or 1)
	end
	return r * brightness, g * brightness, b * brightness, a
end
