-- SarychUI Frames: combo points on the focus frame (WoW 3.3.5).

local module = SarychUI and SarychUI.GetModule and SarychUI:GetModule("frame")
if not module then return end

local MAX_POINTS = MAX_COMBO_POINTS or 5
local FADE_IN = 0.3
local HIGHLIGHT_FADE_IN = 0.4
local SHINE_FADE_IN = 0.3
local SHINE_FADE_OUT = 0.4

local focusComboFrame
local points = {}
local lastNumPoints = 0

local function FrameDB()
	local modules = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return modules and modules.frame
end

local function Enabled()
	local db = FrameDB()
	return db and db.enabled and (db.enableFocusComboPoints == 1 or db.enableFocusComboPoints == true)
end

local function ShineFadeOut(texture)
	if texture then
		UIFrameFadeOut(texture, SHINE_FADE_OUT)
	end
end

local function ShineFadeIn(texture)
	if not texture then return end
	local fadeInfo = {}
	fadeInfo.mode = "IN"
	fadeInfo.timeToFade = SHINE_FADE_IN
	fadeInfo.finishedFunc = ShineFadeOut
	fadeInfo.finishedArg1 = texture
	UIFrameFade(texture, fadeInfo)
end

local function CreatePoint(parent, index)
	local point = CreateFrame("Frame", nil, parent)
	if index == 5 then
		point:SetSize(15, 18)
	else
		point:SetSize(12, 12)
	end

	if index == 1 then
		point:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
	else
		local previous = points[index - 1].frame
		local x, y = 0, 1
		if index == 2 then
			x, y = 7, 4
		elseif index == 3 then
			x, y = 5, 2
		elseif index == 4 then
			x, y = 2, 1
		end
		point:SetPoint("TOP", previous, "BOTTOM", x, y)
	end

	local background = point:CreateTexture(nil, "BACKGROUND")
	background:SetSize(12, 16)
	background:SetPoint("TOPLEFT")
	background:SetTexture("Interface\\ComboFrame\\ComboPoint")
	background:SetTexCoord(0, 0.375, 0, 1)

	local highlight = point:CreateTexture(nil, "ARTWORK")
	highlight:SetSize(8, 16)
	highlight:SetPoint("TOPLEFT", 2, 0)
	highlight:SetTexture("Interface\\ComboFrame\\ComboPoint")
	highlight:SetTexCoord(0.375, 0.5625, 0, 1)
	highlight:SetAlpha(0)

	local shine = point:CreateTexture(nil, "OVERLAY")
	shine:SetSize(14, 16)
	shine:SetPoint("TOPLEFT", 0, 4)
	shine:SetTexture("Interface\\ComboFrame\\ComboPoint")
	shine:SetTexCoord(0.5625, 1, 0, 1)
	shine:SetBlendMode("ADD")
	shine:SetAlpha(0)

	return {
		frame = point,
		background = background,
		highlight = highlight,
		shine = shine,
	}
end

function module:CreateFocusComboPoints()
	if focusComboFrame or not FocusFrame then return focusComboFrame end

	focusComboFrame = CreateFrame("Frame", "SarychUIFocusComboFrame", UIParent)
	focusComboFrame:SetFrameStrata("MEDIUM")
	focusComboFrame:SetToplevel(true)
	focusComboFrame:SetSize(256, 32)
	focusComboFrame:SetPoint("TOPRIGHT", FocusFrame, "TOPRIGHT", -44, -9)
	focusComboFrame:SetAlpha(0)
	focusComboFrame:Hide()

	for i = 1, MAX_POINTS do
		points[i] = CreatePoint(focusComboFrame, i)
	end

	return focusComboFrame
end

function module:HideFocusComboPoints()
	lastNumPoints = 0
	if not focusComboFrame then return end
	if UIFrameFadeRemoveFrame then
		UIFrameFadeRemoveFrame(focusComboFrame)
	end
	focusComboFrame:SetAlpha(0)
	focusComboFrame:Hide()
	for i = 1, #points do
		points[i].highlight:SetAlpha(0)
		points[i].shine:SetAlpha(0)
	end
end

function module:UpdateFocusComboPoints()
	if not Enabled() or not FocusFrame or not UnitExists("focus") then
		self:HideFocusComboPoints()
		return
	end

	local frame = self:CreateFocusComboPoints()
	if not frame then return end

	local sourceUnit = (PlayerFrame and PlayerFrame.unit) or "player"
	local comboPoints = GetComboPoints(sourceUnit, "focus") or 0
	if comboPoints <= 0 then
		self:HideFocusComboPoints()
		return
	end

	if not frame:IsShown() then
		frame:Show()
		UIFrameFadeIn(frame, FADE_IN)
	end

	for i = 1, MAX_POINTS do
		local point = points[i]
		point.frame:Show()
		if i <= comboPoints then
			if i > lastNumPoints then
				local fadeInfo = {}
				fadeInfo.mode = "IN"
				fadeInfo.timeToFade = HIGHLIGHT_FADE_IN
				fadeInfo.finishedFunc = ShineFadeIn
				fadeInfo.finishedArg1 = point.shine
				UIFrameFade(point.highlight, fadeInfo)
			else
				point.highlight:SetAlpha(1)
			end
		else
			point.highlight:SetAlpha(0)
			point.shine:SetAlpha(0)
			if ENABLE_COLORBLIND_MODE == "1" then
				point.frame:Hide()
			end
		end
	end

	lastNumPoints = comboPoints
end

