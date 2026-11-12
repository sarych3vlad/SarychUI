local SUI = SarychUI
local T = SUI.OptionsTheme
-- Details Cooltip Preset(2)-like floating tooltip (own frame, not GameTooltip).
-- Textures are vendored under SarychUI/media/cooltip so Details is not required.
local COOLTIP_BG_TEX = (T.textures and T.textures.cooltipBg) or "Interface\\AddOns\\SarychUI\\media\\cooltip\\background"
local COOLTIP_BG = T.colors.tooltipBg
local COOLTIP_BORDER = T.colors.border
local COOLTIP_ORANGE = T.colors.tooltipText
local COOLTIP_PAD = T.sizes.tooltipPadding
local COOLTIP_LINE_H = T.sizes.tooltipLineHeight

local cooltipFrame

local function FollowCursor(frame)
    local x, y = GetCursorPosition()
    local scale = frame:GetEffectiveScale()
    frame:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", x / scale, y / scale + 16)
end

local function GetCooltipFontPath()
	local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
	if LSM and LSM.Fetch then
		local path = LSM:Fetch("font", "Friz Quadrata TT", true)
		if path then
			return path
		end
	end
	return "Fonts\\FRIZQT__.TTF"
end

local function EnsureCooltip()
	if cooltipFrame then
		return cooltipFrame
	end
	local f = CreateFrame("Frame", "SarychUIOptionsCooltip", UIParent)
	f:SetFrameStrata("TOOLTIP")
	f:SetFrameLevel(500)
	f:SetClampedToScreen(false)
	f:EnableMouse(false)
	f:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
	f:Hide()
	T:ApplyFlat(f, COOLTIP_BG, COOLTIP_BORDER)
	f.lines = {}
	f.fontPath = GetCooltipFontPath()
	cooltipFrame = f
	return f
end

local function HideCooltip()
	if cooltipFrame then
		cooltipFrame:SetScript("OnUpdate", nil)
		cooltipFrame:Hide()
	end
end

local function ShowCooltip(anchor, lines)
	if not anchor or type(lines) ~= "table" or #lines == 0 then
		HideCooltip()
		return
	end
	local f = EnsureCooltip()
	for _, fs in pairs(f.lines) do
		fs:Hide()
	end
	local y = -COOLTIP_PAD
	local maxW = math.max(1, UIParent:GetWidth() - COOLTIP_PAD * 2)
	local contentWidth = 0
	local count = 0
	for i = 1, #lines do
		local line = lines[i]
		local text, r, g, b
		if type(line) == "table" then
			text = tostring(line[1] or "")
			r = line[2] or COOLTIP_ORANGE[1]
			g = line[3] or COOLTIP_ORANGE[2]
			b = line[4] or COOLTIP_ORANGE[3]
		else
			text = tostring(line)
			r, g, b = COOLTIP_ORANGE[1], COOLTIP_ORANGE[2], COOLTIP_ORANGE[3]
		end
		if text ~= "" then
			if SUI and SUI.T then
				text = SUI:T(text)
			end
			count = count + 1
			local fs = f.lines[count]
			if not fs then
				fs = f:CreateFontString(nil, "OVERLAY")
				fs:SetJustifyH("LEFT")
				fs:SetJustifyV("TOP")
				fs:SetWordWrap(true)
				fs:SetNonSpaceWrap(true)
				f.lines[count] = fs
			end
			fs:SetFont(f.fontPath or "Fonts\\FRIZQT__.TTF", 12, "")
			fs:SetTextColor(r, g, b, 1)
			fs:ClearAllPoints()
            fs:SetWidth(0)
            fs:SetHeight(0)
            fs:SetText(text)
            local width = math.min(maxW, math.ceil(fs:GetStringWidth()))
            contentWidth = math.max(contentWidth, width)
            fs:SetWidth(math.max(1, width))
			fs:ClearAllPoints()
			fs:SetPoint("TOPLEFT", f, "TOPLEFT", COOLTIP_PAD, y)
			fs:Show()
			local h = fs:GetStringHeight() or COOLTIP_LINE_H
			y = y - h - 4
		end
	end
	if count == 0 then
		HideCooltip()
		return
	end
	f:SetWidth(contentWidth + COOLTIP_PAD * 2)
	f:SetHeight(math.ceil(-y + COOLTIP_PAD - 4))
	f:ClearAllPoints()
	FollowCursor(f)
	f:SetScript("OnUpdate", FollowCursor)
	f:Show()
end

SUI.OptionsTooltip = { Show = ShowCooltip, Hide = HideCooltip }


-- A checkbox and its label share one cursor-following tooltip.
function SUI.OptionsTooltip.BindCheckbox(row)
    local function Enter()
        local text = row.label:GetText()
        if text and text ~= "" then
            ShowCooltip(row, {text})
            SUI.OptionsTooltip.owner = row
        end
    end
    local function Leave()
        if SUI.OptionsTooltip.owner == row then
            HideCooltip()
            SUI.OptionsTooltip.owner = nil
        end
    end
    row:HookScript("OnEnter", Enter)
    row:HookScript("OnLeave", Leave)
    row:HookScript("OnHide", Leave)
    row.box:HookScript("OnEnter", Enter)
    row.box:HookScript("OnLeave", Leave)
    if row.help then
        row.help:HookScript("OnEnter", Enter)
        row.help:HookScript("OnLeave", Leave)
    end
end
