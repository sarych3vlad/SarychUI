-- UI helpers for the integrated "Управление модификациями" extension.
-- Legacy AddonList names and saved profile keys remain unchanged.
local _, private = ...
local UI = {}
private.Compat.AddonManagement = UI
local Timer = private.Compat.Timer

function UI.ButtonOnLoad(self)
	local leftHandled = false
	local rightHandled = false

	-- Find out where this button is anchored and adjust positions/separators as necessary
	for i=1, self:GetNumPoints() do
		local point, relativeTo, relativePoint, offsetX, offsetY = self:GetPoint(i)

		if (relativeTo:GetObjectType() == "Button" and (point == "TOPLEFT" or point == "LEFT")) then

			if (offsetX == 0 and offsetY == 0) then
				self:SetPoint(point, relativeTo, relativePoint, 1, 0)
			end

			if (relativeTo.RightSeparator) then
				-- Modify separator to make it a Middle
				self.LeftSeparator = relativeTo.RightSeparator
			else
				-- Add a Middle separator
				self.LeftSeparator = self:CreateTexture(self:GetName().."_LeftSeparator", "BORDER")
				relativeTo.RightSeparator = self.LeftSeparator
			end

			self.LeftSeparator:SetTexture("Interface\\AddOns\\SarychUI\\media\\addon_management\\FrameGeneral\\UI-Frame")
			self.LeftSeparator:SetTexCoord("0.00781250", "0.10937500", "0.75781250", "0.95312500")
			self.LeftSeparator:SetWidth(13)
			self.LeftSeparator:SetHeight(25)
			self.LeftSeparator:SetPoint("TOPRIGHT", self, "TOPLEFT", 5, 1)

			leftHandled = true

		elseif (relativeTo:GetObjectType() == "Button" and (point == "TOPRIGHT" or point == "RIGHT")) then

			if (offsetX == 0 and offsetY == 0) then
				self:SetPoint(point, relativeTo, relativePoint, -1, 0)
			end

			if (relativeTo.LeftSeparator) then
				-- Modify separator to make it a Middle
				self.RightSeparator = relativeTo.LeftSeparator
			else
				-- Add a Middle separator
				self.RightSeparator = self:CreateTexture(self:GetName().."_RightSeparator", "BORDER")
				relativeTo.LeftSeparator = self.RightSeparator
			end

			self.RightSeparator:SetTexture("Interface\\AddOns\\SarychUI\\media\\addon_management\\FrameGeneral\\UI-Frame")
			self.RightSeparator:SetTexCoord("0.00781250", "0.10937500", "0.75781250", "0.95312500")
			self.RightSeparator:SetWidth(13)
			self.RightSeparator:SetHeight(25)
			self.RightSeparator:SetPoint("TOPLEFT", self, "TOPRIGHT", -5, 1)

			rightHandled = true

		elseif (point == "BOTTOMLEFT") then
			if (offsetX == 0 and offsetY == 0) then
				self:SetPoint(point, relativeTo, relativePoint, 4, 4)
			end
			leftHandled = true
		elseif (point == "BOTTOMRIGHT") then
			if (offsetX == 0 and offsetY == 0) then
				self:SetPoint(point, relativeTo, relativePoint, -6, 4)
			end
			rightHandled = true
		elseif (point == "BOTTOM") then
			if (offsetY == 0) then
				self:SetPoint(point, relativeTo, relativePoint, 0, 4)
			end
		end
	end

	-- If this button didn't have a left anchor, add the left border texture
	if (not leftHandled) then
		if (not self.LeftSeparator) then
			-- Add a Left border
			self.LeftSeparator = self:CreateTexture(self:GetName().."_LeftSeparator", "BORDER")
			self.LeftSeparator:SetTexture("Interface\\AddOns\\SarychUI\\media\\addon_management\\FrameGeneral\\UI-Frame")
			self.LeftSeparator:SetTexCoord("0.24218750", "0.32812500", "0.63281250", "0.82812500")
			self.LeftSeparator:SetWidth(11)
			self.LeftSeparator:SetHeight(25)
			self.LeftSeparator:SetPoint("TOPRIGHT", self, "TOPLEFT", 6, 1)
		end
	end

	-- If this button didn't have a right anchor, add the right border texture
	if (not rightHandled) then
		if (not self.RightSeparator) then
			-- Add a Right border
			self.RightSeparator = self:CreateTexture(self:GetName().."_RightSeparator", "BORDER")
			self.RightSeparator:SetTexture("Interface\\AddOns\\SarychUI\\media\\addon_management\\FrameGeneral\\UI-Frame")
			self.RightSeparator:SetTexCoord("0.90625000", "0.99218750", "0.00781250", "0.20312500")
			self.RightSeparator:SetWidth(11)
			self.RightSeparator:SetHeight(25)
			self.RightSeparator:SetPoint("TOPLEFT", self, "TOPRIGHT", -6, 1)
		end
	end
end


function UI.HidePortrait(frame)
    frame.portrait:Hide()
    frame.portraitFrame:Hide()
    frame.topLeftCorner:Show()
    frame.topBorderBar:SetPoint("TOPLEFT", frame.topLeftCorner, "TOPRIGHT", 0, 0)
    frame.leftBorderBar:SetPoint("TOPLEFT", frame.topLeftCorner, "BOTTOMLEFT", 0, 0)
end

function UI.GetCharacter(selector) return selector and selector.selectedValue end
function UI.SetCharacter(selector, character)
    selector.selectedValue = character
    _G[selector:GetName().."Text"]:SetText(character or "")
end
local function stopCountdown(selector)
    if selector.closeTimer then selector.closeTimer:Cancel();selector.closeTimer=nil end
end
function UI.CloseMenu(selector)
    stopCountdown(selector)
    if selector.menu then selector.menu:Hide() end
end
local function startCountdown(selector)
    stopCountdown(selector)
    selector.closeTimer = Timer.NewTimer(2, function()
        selector.closeTimer=nil
        UI.CloseMenu(selector)
    end)
end
local function makeMenu(selector)
    -- Two existing choices only: All is disabled; the current character is selectable.
    -- No shared DropDownList buttons, native dropdown state or protected frames.
    local menu = CreateFrame("Frame", "SarychUI"..selector:GetName().."Menu", selector)
    menu:Hide()
    menu:SetFrameStrata("DIALOG")
    menu:EnableMouse(true)
    menu:SetClampedToScreen(true)
    menu:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,
        insets={left=11,right=12,top=12,bottom=9}})
    menu:SetHeight(62)
    menu:SetPoint("TOPLEFT", _G[selector:GetName().."Left"], "BOTTOMLEFT", 8, 22)
    menu.rows={}
    for i=1,2 do
        local row=CreateFrame("Button",nil,menu)
        row:SetHeight(16)
        row:SetPoint("TOPLEFT",menu,"TOPLEFT",17,-15-(i-1)*16)
        row.text=row:CreateFontString(nil,"ARTWORK",i==1 and "GameFontDisableSmallLeft" or "GameFontHighlightSmallLeft")
        row.text:SetPoint("LEFT",row,"LEFT",20,0)
        if i==2 then
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            local highlight=row:GetHighlightTexture()
            highlight:SetBlendMode("ADD")
            row.check=row:CreateTexture(nil,"ARTWORK")
            row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            row.check:SetTexCoord(0,1,0,1)
            row.check:SetWidth(18);row.check:SetHeight(18)
            row.check:SetPoint("LEFT",row,"LEFT",0,0)
            row:LockHighlight()
            row:SetScript("OnClick",function() UI.CloseMenu(selector) end)
        end
        row:SetScript("OnEnter",function() stopCountdown(selector) end)
        row:SetScript("OnLeave",function() startCountdown(selector) end)
        menu.rows[i]=row
    end
    menu:SetScript("OnEnter",function() stopCountdown(selector) end)
    menu:SetScript("OnLeave",function() startCountdown(selector) end)
    menu:SetScript("OnEvent",function() UI.CloseMenu(selector) end)
    menu:SetScript("OnShow",function(self) self:RegisterEvent("PLAYER_REGEN_DISABLED") end)
    menu:SetScript("OnHide",function(self) stopCountdown(selector);self:UnregisterAllEvents() end)
    -- Escape can close this addon-owned popup without modifying Blizzard menus.
    tinsert(UISpecialFrames,menu:GetName())
    selector.menu=menu
    return menu
end
function UI.ToggleMenu(selector)
    if InCombatLockdown() then return end
    local menu=selector.menu
    if menu and menu:IsShown() then UI.CloseMenu(selector);return end
    menu=menu or makeMenu(selector)
    menu.rows[1].text:SetText(ALL)
    menu.rows[2].text:SetText(UnitName("player"))
    local width=math.max(menu.rows[1].text:GetStringWidth(),menu.rows[2].text:GetStringWidth())
    menu:SetWidth(width+65)
    for _,row in ipairs(menu.rows) do row:SetWidth(width+40) end
    menu:Show()
    startCountdown(selector)
end
function UI.CreateCharacterSelector(parent, name)
    return CreateFrame("Frame", name, parent, "SarychUIAM_CharacterSelectorTemplate")
end
