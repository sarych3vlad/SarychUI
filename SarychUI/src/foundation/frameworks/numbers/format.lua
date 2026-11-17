SarychUI.Frameworks = SarychUI.Frameworks or {}

-- Group the integer part only; preserve the sign and any fractional suffix.
function SarychUI.Frameworks.FormatThousands(value)
    local text = tostring(value)
    local sign, digits, suffix = text:match("^([+-]?)(%d+)(.*)$")
    if not digits then return text end
    local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return sign .. grouped .. suffix
end
