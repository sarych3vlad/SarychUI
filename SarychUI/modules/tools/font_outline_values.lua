-- Font outline values (ElvUI NamePlates / autolos style)
SarychUI_FontOutlineValues = SarychUI_FontOutlineValues or {
	NONE = "NONE",
	OUTLINE = "OUTLINE",
	MONOCHROME = "MONOCHROME",
	MONOCHROMEOUTLINE = "MONOCHROMEOUTLINE",
	THICKOUTLINE = "THICKOUTLINE",
}

function SarychUI_FontOutlineValues.GetSelectValues(L)
	return {
		NONE = L and (L["None"] or "Без границы") or "Без границы",
		OUTLINE = "OUTLINE",
		MONOCHROME = "MONOCHROME",
		MONOCHROMEOUTLINE = "MONOCHROME OUTLINE",
		THICKOUTLINE = "THICK OUTLINE",
	}
end

function SarychUI_FontOutlineValues.Resolve(outline)
	if outline == "NONE" or outline == "" or outline == nil then
		return ""
	end
	return outline
end

return SarychUI_FontOutlineValues
