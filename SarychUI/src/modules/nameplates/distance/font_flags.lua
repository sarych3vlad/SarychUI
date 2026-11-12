-- Font outline values aligned with ElvUI NamePlates options (Nameplates.lua C.Values.FontFlags)
AutolosFontFlags = AutolosFontFlags or {
	NONE = "NONE",
	OUTLINE = "OUTLINE",
	MONOCHROME = "MONOCHROME",
	MONOCHROMEOUTLINE = "MONOCHROMEOUTLINE",
	THICKOUTLINE = "THICKOUTLINE",
}

function AutolosFontFlags.GetValues(L)
	return {
		NONE = L and (L["None"] or "Без границы") or "Без границы",
		OUTLINE = "OUTLINE",
		MONOCHROME = "MONOCHROME",
		MONOCHROMEOUTLINE = "MONOCHROME OUTLINE",
		THICKOUTLINE = "THICK OUTLINE",
	}
end

return AutolosFontFlags
