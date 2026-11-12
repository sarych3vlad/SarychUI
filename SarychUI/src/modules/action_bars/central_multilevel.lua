-- DragonUI mainbars layout adapted for SarychUI.  Geometry and status-bar
-- construction come from DragonUI 2.5 (src/modules/mainbars.lua, database.lua).
-- Only DragonUI XP/reputation textures are bundled; ordinary art stays Blizzard.
local module = SarychUI.modules and SarychUI.modules.mainmenubar
if not module then return end

local MEDIA = "Interface\\AddOns\\SarychUI\\media\\mainmenubar\\central_multilevel\\"
local SIZE = 36
local BAR_WIDTH, BAR_HEIGHT, DUAL_OFFSET = 466, 14, 16
local VEHICLE_ANIMATION_DELAY = 0.60
local STOCK_ART = { "MainMenuBarTexture0", "MainMenuBarTexture1", "MainMenuBarTexture2",
    "MainMenuBarTexture3", "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap",
    "MainMenuBarArtFrameTexture0", "MainMenuBarArtFrameTexture1",
    "MainMenuBarArtFrameTexture2", "MainMenuBarArtFrameTexture3",
    "MainMenuBarMaxLevelBar", "MainMenuBarPerformanceBar",
    "ReputationXPBarTexture0", "ReputationXPBarTexture1", "ReputationXPBarTexture2", "ReputationXPBarTexture3",
    "ReputationWatchBarTexture0", "ReputationWatchBarTexture1", "ReputationWatchBarTexture2", "ReputationWatchBarTexture3",
    "MainMenuXPBarTexture0", "MainMenuXPBarTexture1", "MainMenuXPBarTexture2", "MainMenuXPBarTexture3",
    "SlidingActionBarTexture0", "SlidingActionBarTexture1",
    "BonusActionBarTexture0", "BonusActionBarTexture1",
    "ShapeshiftBarLeft", "ShapeshiftBarMiddle", "ShapeshiftBarRight",
    "PossessBackground1", "PossessBackground2" }
local style = { active = false, original = {}, methods = {} }
module.DragonStyle = style
local MANAGED_BARS = { "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight",
    "ShapeshiftBarFrame" }
local STANCE_ART = { "ShapeshiftBarLeft", "ShapeshiftBarMiddle", "ShapeshiftBarRight" }

local function DB()
    return SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules.mainmenubar
end

local function GetSpacing()
    local db = DB()
    local value = tonumber(db and db.dragonSpacing) or 6
    return math.max(0, math.min(20, math.floor(value + 0.5)))
end

local function Save(frame)
    if frame == style.holder or frame == style.xp or frame == style.rep
        or frame == style.petHolder or frame == style.stanceHolder
        or frame == style.vehicleExit then return end
    if not frame or style.original[frame] then return end
    -- Texture and FontString regions in WoW 3.3.5 do not expose every Frame
    -- method (notably GetScale/SetScale).  Save only supported properties.
    local state = {
        parent = frame.GetParent and frame:GetParent(),
        scale = frame.GetScale and frame:GetScale(),
        width = frame.GetWidth and frame:GetWidth(),
        height = frame.GetHeight and frame:GetHeight(),
        alpha = frame.GetAlpha and frame:GetAlpha(),
        shown = frame.IsShown and frame:IsShown(),
        points = {},
    }
    if frame.IsMouseEnabled then state.mouseEnabled = frame:IsMouseEnabled() end
    if frame.GetNumPoints and frame.GetPoint then
        for i = 1, frame:GetNumPoints() do
            state.points[i] = { frame:GetPoint(i) }
        end
    end
    style.original[frame] = state
end

local function Place(frame, point, relative, relativePoint, x, y)
    if not frame then return end
    Save(frame)
    frame:ClearAllPoints()
    frame:SetPoint(point, relative, relativePoint, x, y)
end

local function Restore()
    if InCombatLockdown() then return end
    for frame, state in pairs(style.original) do
        if state.parent and frame.SetParent then frame:SetParent(state.parent) end
        if state.scale and frame.SetScale then frame:SetScale(state.scale) end
        if state.width and state.height and frame.SetSize then
            frame:SetSize(state.width, state.height)
        end
        if state.alpha and frame.SetAlpha then frame:SetAlpha(state.alpha) end
        if state.mouseEnabled ~= nil and frame.EnableMouse then
            frame:EnableMouse(state.mouseEnabled)
        end
        if frame.ClearAllPoints and frame.SetPoint then
            frame:ClearAllPoints()
            for _, point in ipairs(state.points) do
                frame:SetPoint(point[1], point[2], point[3], point[4], point[5])
            end
        end
        if state.shown ~= nil then
            if state.shown then frame:Show() else frame:Hide() end
        end
    end
    wipe(style.original)
end

local function XpAvailable()
    local maximum = UnitXPMax("player") or 0
    return maximum > 0 and (UnitXP("player") or 0) < maximum
        and (not IsXPUserDisabled or not IsXPUserDisabled())
end

local function RepAvailable()
    return GetWatchedFactionInfo() ~= nil
end

local function DualOffset()
    local xpSpace = module.IsExperienceBarOccupyingSpace and module:IsExperienceBarOccupyingSpace()
    local repSpace = module.IsReputationBarOccupyingSpace and module:IsReputationBarOccupyingSpace()
    return xpSpace and repSpace and DUAL_OFFSET or 0
end

local function VehicleLayoutBlocked()
    if UnitHasVehicleUI and UnitHasVehicleUI("player") then return true end
    if MainMenuBar and (MainMenuBar.busy or MainMenuBar.animating) then return true end
    if VehicleMenuBar and VehicleMenuBar.animating then return true end
    return false
end

function style:RequestLayout(delay)
    if not self.active then return end
    self.layoutPending = true
    self.layoutDelay = math.max(self.layoutDelay or 0, delay or 0)
    if self.controller and not InCombatLockdown()
        and not (UnitHasVehicleUI and UnitHasVehicleUI("player")) then
        self.controller:Show()
    end
end

function style:RefreshVehicleHotkeys()
    if not self.active or InCombatLockdown() or not ActionButton_UpdateHotkeys then return end
    local nativeSetPoint = MainMenuBarPageNumber and MainMenuBarPageNumber.SetPoint
    for index = 1, 6 do
        local button = _G["VehicleMenuBarActionButton" .. index]
        if button then
            ActionButton_UpdateHotkeys(button, button.buttonType)
            local hotkey = _G["VehicleMenuBarActionButton" .. index .. "HotKey"]
            if hotkey and nativeSetPoint then
                hotkey:ClearAllPoints()
                nativeSetPoint(hotkey, "TOPRIGHT", button, "TOPRIGHT", -4, -4)
                hotkey:SetDrawLayer("OVERLAY")
                hotkey:SetTextColor(1, 1, 1)
            end
        end
    end
end

function style:UpdatePetAndStance()
    if InCombatLockdown() then return end
    if self.petHolder and not self.petDriverRegistered then
        local hasPet = UnitExists("pet") and UnitIsVisible("pet")
        local inVehicle = UnitInVehicle and UnitInVehicle("player")
        local hasVehicleBar = SarychUI.Compat.HasVehicleActionBar()
        if hasPet or (inVehicle and hasVehicleBar) then self.petHolder:Show()
        else self.petHolder:Hide() end
    end
    if self.stanceHolder then
        if (GetNumShapeshiftForms and GetNumShapeshiftForms() or 0) > 0 then
            self.stanceHolder:Show()
        else self.stanceHolder:Hide() end
    end
end

local function MakeBar(name, fill, rested)
    local frame = CreateFrame("Frame", name, MainMenuBar or UIParent)
    frame:SetSize(BAR_WIDTH, BAR_HEIGHT)
    frame:SetFrameStrata("MEDIUM")
    frame.Background = frame:CreateTexture(nil, "BACKGROUND")
    frame.Background:SetAllPoints()
    frame.Background:SetTexture(MEDIA .. "xp\\Background")
    frame.Background:SetTexCoord(0, BAR_WIDTH / 842, 0, 1)
    if rested then
        frame.Rested = CreateFrame("StatusBar", nil, frame)
        frame.Rested:SetAllPoints()
        frame.Rested:SetStatusBarTexture(MEDIA .. "xp\\RestedBackground")
        frame.Rested:SetAlpha(0.69)
        frame.Rested:SetFrameLevel(frame:GetFrameLevel() + 1)
        frame.Mark = frame:CreateTexture(nil, "OVERLAY")
        frame.Mark:SetSize(14, BAR_HEIGHT + 6)
        frame.Mark:SetTexture(MEDIA .. "uiexperiencebar")
        frame.Mark:SetTexCoord(1170/2048, 1192/2048, 201/256, 231/256)
    end
    frame.Bar = CreateFrame("StatusBar", nil, frame)
    frame.Bar:SetAllPoints()
    frame.Bar:SetStatusBarTexture(MEDIA .. fill)
    frame.Bar:SetFrameLevel(frame:GetFrameLevel() + 2)
    frame.Bar:EnableMouse(true)
    frame.Border = frame.Bar:CreateTexture(nil, "OVERLAY")
    frame.Border:SetTexture(MEDIA .. "xp\\Overlay")
    frame.Border:SetTexCoord(0, BAR_WIDTH / 842, 0, 1)
    frame.Border:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 1)
    frame.Border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, -1)
    frame.Text = frame.Bar:CreateFontString(nil, "HIGHLIGHT", "SystemFont_Outline_Small")
    frame.Text:SetPoint("CENTER", frame, "CENTER", 0, 1)
    return frame
end

function style:CreateBars()
    if self.xp then return end
    self.xp = MakeBar("SarychUI_DragonXPBar", "xp\\Main", true)
    self.rep = MakeBar("SarychUI_DragonRepBar", "reputation\\Rep", false)
    self.xp:Hide()
    self.rep:Hide()
    self.xp.Bar:SetScript("OnEnter", function(bar)
        GameTooltip:SetOwner(bar, "ANCHOR_RIGHT")
        GameTooltip:AddLine(XPBAR_LABEL or "Experience", 1, 1, 1)
        GameTooltip:AddDoubleLine("XP", (UnitXP("player") or 0) .. " / " .. (UnitXPMax("player") or 0))
        GameTooltip:Show()
    end)
    self.rep.Bar:SetScript("OnEnter", function(bar)
        local name, standing, low, high, value = GetWatchedFactionInfo()
        if not name then return end
        GameTooltip:SetOwner(bar, "ANCHOR_RIGHT")
        GameTooltip:AddLine(name, 1, 1, 1)
        GameTooltip:AddDoubleLine(_G["FACTION_STANDING_LABEL" .. standing] or "", (value-low) .. " / " .. (high-low))
        GameTooltip:Show()
    end)
    self.xp.Bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.rep.Bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.rep.Bar:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and not InCombatLockdown() then ToggleCharacter("ReputationFrame") end
    end)
    self.xp.Bar:SetScript("OnMouseDown", function(_, button)
        if button == "RightButton" and MainMenuExpBar then
            local handler = MainMenuExpBar:GetScript("OnMouseDown")
            if handler then handler(MainMenuExpBar, button) end
        end
    end)
end

function style:CreateVehicleExit()
    if self.vehicleExit then return end
    local button = CreateFrame("CheckButton", "SarychUI_DragonVehicleExit", UIParent,
        "SecureHandlerClickTemplate,SecureHandlerStateTemplate")
    button:SetSize(31, 31)
    button:SetNormalTexture("Interface\\Vehicles\\UI-Vehicles-Button-Exit-Up")
    button:GetNormalTexture():SetTexCoord(0.140625, 0.859375, 0.140625, 0.859375)
    button:SetPushedTexture("Interface\\Vehicles\\UI-Vehicles-Button-Exit-Down")
    button:GetPushedTexture():SetTexCoord(0.140625, 0.859375, 0.140625, 0.859375)
    button:SetHighlightTexture("Interface\\Vehicles\\UI-Vehicles-Button-Highlight")
    button:GetHighlightTexture():SetTexCoord(0.130625, 0.879375, 0.130625, 0.879375)
    button:RegisterForClicks("AnyUp")
    button:SetScript("OnClick", function() VehicleExit() end)
    button:Hide()
    self.vehicleExit = button
end

function style:UpdateBars()
    if not self.active then return end
    if XpAvailable() then
        local value, maximum = UnitXP("player") or 0, UnitXPMax("player") or 1
        local rested = GetXPExhaustion() or 0
        self.xp.Bar:SetStatusBarTexture(MEDIA .. ((GetRestState() == 1) and "xp\\Rested" or "xp\\Main"))
        self.xp.Bar:SetMinMaxValues(0, maximum)
        self.xp.Bar:SetValue(value)
        self.xp.Text:SetText(value .. " / " .. maximum)
        self.xp.Rested:SetMinMaxValues(0, maximum)
        self.xp.Rested:SetValue(math.min(maximum, value + rested))
        if rested > 0 then self.xp.Rested:Show() else self.xp.Rested:Hide() end
        if rested > 0 and value + rested < maximum then
            self.xp.Mark:ClearAllPoints()
            self.xp.Mark:SetPoint("CENTER", self.xp, "LEFT", (value+rested)/maximum*BAR_WIDTH, 0)
            self.xp.Mark:Show()
        else self.xp.Mark:Hide() end
        self.xp:Show()
    else self.xp:Hide() end
    local name, standing, low, high, value = GetWatchedFactionInfo()
    if name then
        local texture = (standing <= 2 and "RepRed") or (standing == 3 and "RepOrange")
            or (standing == 4 and "RepYellow") or "RepGreen"
        self.rep.Bar:SetStatusBarTexture(MEDIA .. "reputation\\" .. texture)
        self.rep.Bar:SetMinMaxValues(0, math.max(1, high-low))
        self.rep.Bar:SetValue(value-low)
        self.rep.Text:SetText(name .. " " .. (value-low) .. " / " .. (high-low))
        self.rep:Show()
    else self.rep:Hide() end
    local db = DB()
    local alt = SarychUI.AltMode and SarychUI.AltMode:IsAltPressed()
    local xpAlpha = self.xpAlpha
    if xpAlpha == nil then xpAlpha = (db and db.hideExperienceBar and not (alt and db.showExperienceBarOnAlt)) and 0 or 1 end
    local repAlpha = self.repAlpha
    if repAlpha == nil then repAlpha = (db and db.hideReputationBar and not (alt and db.showReputationBarOnAlt)) and 0 or 1 end
    self.xp:SetAlpha(xpAlpha)
    self.rep:SetAlpha(repAlpha)
end

-- DragonUI default widgets: main (0,22), lower rows (0,64)/(0,102),
-- right (-5,-70), left (-45,-70), XP (1,7), reputation (1,23).
-- The two XP/rep bars raise the center stack by 14+2 pixels.
function style:Layout()
    if not self.active then return end
    if self.layoutPending and (self.layoutDelay or 0) > 0 then return end
    if InCombatLockdown() or VehicleLayoutBlocked() then
        self.layoutPending = true
        if self.controller then
            if InCombatLockdown() or (UnitHasVehicleUI and UnitHasVehicleUI("player")) then
                self.controller:Hide()
            else
                self.layoutDelay = 0.10
                self.controller:Show()
            end
        end
        return
    end
    local spacing = GetSpacing()
    local rowStep = SIZE + spacing
    local shift = DualOffset()
    local holder = self.holder
    holder:SetSize(12 * SIZE + 11 * spacing + 4, 42)
    Place(holder, "BOTTOM", MainMenuBar or UIParent, "BOTTOM", 0, 22 + shift)
    for i = 1, 12 do
        local x = 2 + (i-1)*rowStep
        local button = _G["ActionButton" .. i]
        if button then
            Save(button)
            button:SetParent(holder)
            Place(button, "BOTTOMLEFT", holder, "BOTTOMLEFT", x, 2)
        end
    end
    -- DragonUI reparents Blizzard's bonus frame, then anchors its buttons to
    -- the main holder.  The frame still controls their visibility and clicks.
    if BonusActionBarFrame then
        Save(BonusActionBarFrame)
        BonusActionBarFrame:SetParent(holder)
        Place(BonusActionBarFrame, "TOPLEFT", holder, "BOTTOMLEFT", 4, 43)
        for i = 1, 12 do
            Place(_G["BonusActionButton" .. i], "BOTTOMLEFT", holder, "BOTTOMLEFT",
                2 + (i-1)*rowStep, 2)
        end
    end
    local bottom = {
        { MultiBarBottomLeft, "MultiBarBottomLeftButton", 24 + rowStep },
        { MultiBarBottomRight, "MultiBarBottomRightButton", 24 + rowStep * 2 },
    }
    for _, data in ipairs(bottom) do
        local bar, prefix, y = unpack(data)
        if bar then
            -- These rows are part of the central stack.  MainMenuBar is the
            -- frame Blizzard slides for vehicle transitions, including combat.
            if MainMenuBar and bar:GetParent() ~= MainMenuBar then
                Save(bar)
                bar:SetParent(MainMenuBar)
            end
            Place(bar, "BOTTOM", MainMenuBar or UIParent, "BOTTOM", 0, y + shift)
            bar:SetScale(1)
            bar:SetSize(12 * SIZE + 11 * spacing, SIZE)
            if bar == MultiBarBottomRight then bar:EnableMouse(false) end
            for i = 1, 12 do
                Place(_G[prefix .. i], "BOTTOMLEFT", bar, "BOTTOMLEFT", (i-1)*rowStep, 0)
            end
        end
    end
    for _, data in ipairs({
        { MultiBarRight, "MultiBarRightButton", -5 },
        { MultiBarLeft, "MultiBarLeftButton", -5 - SIZE - spacing },
    }) do
        local bar, prefix, x = unpack(data)
        if bar then
            Place(bar, "RIGHT", UIParent, "RIGHT", x, -70)
            bar:SetScale(1)
            bar:SetSize(SIZE, 12 * SIZE + 11 * spacing)
            for i = 1, 12 do
                Place(_G[prefix .. i], "TOPLEFT", bar, "TOPLEFT", 0, -(i-1)*rowStep)
            end
        end
    end
    -- The shared spacing controls both buttons and the gap above the top row.
    self.petHolder = self.petHolder or CreateFrame("Frame", "SarychUI_DragonPetBar", UIParent, "SecureHandlerStateTemplate")
    self.petHolder:SetSize(10 * 30 + 9 * spacing, 30)
    local forms = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
    local alignPetRight = forms > 0
    if MultiBarBottomRight then
        if alignPetRight then
            Place(self.petHolder, "BOTTOMRIGHT", MultiBarBottomRight, "TOPRIGHT", 0, spacing)
        else
            Place(self.petHolder, "BOTTOM", MultiBarBottomRight, "TOP", 1, spacing)
        end
    else
        local y = 24 + rowStep * 2 + SIZE + spacing + shift
        if alignPetRight then
            Place(self.petHolder, "BOTTOMRIGHT", UIParent, "BOTTOM",
                (12 * SIZE + 11 * spacing) / 2, y)
        else
            Place(self.petHolder, "BOTTOM", UIParent, "BOTTOM", 1, y)
        end
    end
    for i = 1, 10 do
        local button = _G["PetActionButton" .. i]
        if button then
            Save(button)
            button:SetParent(self.petHolder)
            Place(button, "BOTTOMLEFT", self.petHolder, "BOTTOMLEFT", (i-1)*(30 + spacing), 0)
            button:Show()
            self.petHolder:SetAttribute("addchild", button)
        end
    end
    if PetActionBarFrame then PetActionBarFrame.showgrid = 1 end
    -- DragonUI's stance position with Blizzard's native 30px button size.
    self.stanceHolder = self.stanceHolder or CreateFrame("Frame", "SarychUI_DragonStanceBar",
        MainMenuBar or UIParent, "SecureHandlerStateTemplate")
    self.stanceHolder:SetSize(math.max(1, forms)*30 + math.max(0, forms-1)*spacing, 30)
    if MultiBarBottomRight then
        Place(self.stanceHolder, "BOTTOMLEFT", MultiBarBottomRight, "TOPLEFT", 0, spacing)
    else
        Place(self.stanceHolder, "BOTTOMLEFT", MainMenuBar or UIParent, "BOTTOM",
            -(12 * SIZE + 11 * spacing) / 2,
            24 + rowStep * 2 + SIZE + spacing + shift)
    end
    -- FrameXML anchors the first button back to this frame when there is one
    -- form.  Match its (+12,+3) anchor to our button's (0,0) position.
    if ShapeshiftBarFrame then
        Place(ShapeshiftBarFrame, "BOTTOMLEFT", self.stanceHolder, "BOTTOMLEFT", -12, -3)
    end
    for i = 1, (NUM_SHAPESHIFT_SLOTS or 10) do
        local button = _G["ShapeshiftButton" .. i]
        if button then
            Save(button)
            button:SetParent(self.stanceHolder)
            Place(button, "BOTTOMLEFT", self.stanceHolder, "BOTTOMLEFT", (i-1)*(30 + spacing), 0)
        end
    end
    self:LayoutBagsAndMicroMenu()
    if self.vehicleExit then
        if MultiBarBottomRight then
            Place(self.vehicleExit, "BOTTOM", MultiBarBottomRight, "TOPLEFT", 3, spacing)
        else
            Place(self.vehicleExit, "BOTTOM", UIParent, "BOTTOM", -251,
                24 + rowStep * 2 + SIZE + spacing + shift)
        end
    end
    Place(self.xp, "BOTTOM", MainMenuBar or UIParent, "BOTTOM", 1, 7)
    Place(self.rep, "BOTTOM", MainMenuBar or UIParent, "BOTTOM", 1, XpAvailable() and 23 or 7)
    if ActionBarUpButton then Place(ActionBarUpButton, "TOPLEFT", holder, "TOPLEFT", -30, 8) end
    if ActionBarDownButton then Place(ActionBarDownButton, "TOPLEFT", holder, "TOPLEFT", -30, -14) end
    if MainMenuBarPageNumber and ActionBarDownButton then
        Place(MainMenuBarPageNumber, "CENTER", ActionBarDownButton, "CENTER", -1, 12)
    end
    for _, region in ipairs({ ActionBarUpButton, ActionBarDownButton, MainMenuBarPageNumber }) do
        if region then Save(region); region:SetParent(holder) end
    end
    self:ApplyArt()
    self:UpdateBars()
    self:UpdatePetAndStance()
    if RegisterStateDriver and self.petHolder and not self.petDriverRegistered then
        RegisterStateDriver(self.petHolder, "visibility", "[pet,novehicleui,nobonusbar:5] show; hide")
        self.petDriverRegistered = true
    end
    self.layoutPending = false
    self.layoutDelay = 0
    if self.controller then self.controller:Hide() end
end

function style:LayoutBagsAndMicroMenu()
    -- BFA bag and micro-menu anchors, with the Blizzard button chain intact.
    -- BFA's right-tray art is deliberately omitted; this style uses stock art.
    if MainMenuBarBackpackButton then
        local width = GetScreenWidth and GetScreenWidth()
            or (UIParent and UIParent:GetWidth()) or 1024
        Place(MainMenuBarBackpackButton, "BOTTOMRIGHT", MainMenuBar or UIParent,
            "BOTTOM", width/2 - 6, 46)
    end
    if CharacterBag0Slot and MainMenuBarBackpackButton then
        Place(CharacterBag0Slot, "BOTTOMLEFT", MainMenuBarBackpackButton, "CENTER", -55.7, -20)
    end
    for index, x in ipairs({ -33.5, -67, -101 }) do
        local bag = _G["CharacterBag" .. index .. "Slot"]
        if bag and CharacterBag0Slot then
            Place(bag, "CENTER", CharacterBag0Slot, "CENTER", x, 0)
        end
    end
    for index = 0, 3 do
        local bag = _G["CharacterBag" .. index .. "Slot"]
        if bag then
            Save(bag)
            bag:SetScale(0.95)
        end
    end
    if CharacterMicroButton and MainMenuBarBackpackButton then
        Save(CharacterMicroButton)
        self:PositionPlayerMicroMenu()
    end
end

-- FrameXML moves the micro buttons back to MainMenuBarArtFrame when vehicle
-- art closes.  Restore this anchor immediately, as the BFA layout does; a
-- full protected-bar layout may have to wait until combat ends.
function style:PositionPlayerMicroMenu()
    if not CharacterMicroButton or not MainMenuBarBackpackButton then return false end
    if InCombatLockdown() and CharacterMicroButton.IsProtected
        and CharacterMicroButton:IsProtected() then return false end
    CharacterMicroButton:ClearAllPoints()
    CharacterMicroButton:SetPoint("BOTTOMLEFT", MainMenuBarBackpackButton,
        "CENTER", -233, -62.9)
    return true
end

function style:ApplyArt()
    if not self.active then return end
    -- Bag and micro buttons are children of this frame in FrameXML.  Keep it
    -- visible and suppress only the decorative textures below.
    if MainMenuBarArtFrame then
        if MainMenuBarArtFrame.SetScript then MainMenuBarArtFrame:SetScript("OnShow", nil) end
        MainMenuBarArtFrame:SetAlpha(1)
        MainMenuBarArtFrame:Show()
    end
    for _, name in ipairs(STOCK_ART) do
        local region = _G[name]
        if region then region:SetAlpha(0) end
    end
    -- ShapeshiftBar_Update() explicitly shows the middle piece again.  Clear
    -- the stock art itself so its BORDER layer cannot flash under our moved
    -- stance buttons during vehicle transitions.
    for _, name in ipairs(STANCE_ART) do
        local texture = _G[name]
        if texture then texture:SetTexture(nil) end
    end
    -- The stance buttons were moved out of this stock frame.  FrameXML may
    -- show its empty decorative frame again while switching vehicle art.
    if ShapeshiftBarFrame then ShapeshiftBarFrame:SetAlpha(0) end
    if MainMenuBarMaxLevelBar then MainMenuBarMaxLevelBar:EnableMouse(false) end
    if MainMenuExpBar then MainMenuExpBar:SetAlpha(0) end
    if ReputationWatchBar then ReputationWatchBar:SetAlpha(0) end
    for _, name in ipairs({ "ExhaustionTick", "ExhaustionLevelFillBar", "MainMenuBarPerformanceBar",
        "MainMenuBarExpText", "ReputationWatchBarText" }) do
        local frame = _G[name]
        if frame then frame:Hide() end
    end
end

function style:InstallMethods()
    if self.methodsInstalled then return end
    self.methodsInstalled = true
    for _, name in ipairs({"SetExpBarAlpha", "SetRepBarAlpha", "UpdateBarsLayout", "ApplyAppearanceSettings",
        "UpdateExhaustionTick",
        "ShowElementsOnAlt", "HideElementsOnAltRelease", "ShowReputationBar", "HideReputationBar"}) do
        self.methods[name] = module[name]
    end
    module.SetExpBarAlpha = function(m, alpha)
        style.methods.SetExpBarAlpha(m, alpha)
        if style.active then style.xpAlpha = alpha; style.xp:SetAlpha(alpha); MainMenuExpBar:SetAlpha(0) end
    end
    module.SetRepBarAlpha = function(m, alpha)
        style.methods.SetRepBarAlpha(m, alpha)
        if style.active then style.repAlpha = alpha; style.rep:SetAlpha(alpha); ReputationWatchBar:SetAlpha(0) end
    end
    module.UpdateBarsLayout = function(m, reason)
        if style.active then
            if reason == "UpdateExperienceBar" then style.xpAlpha = nil end
            if reason == "UpdateReputationBar" then style.repAlpha = nil end
            style:Layout()
        else style.methods.UpdateBarsLayout(m, reason) end
    end
    module.ApplyAppearanceSettings = function(m, ...)
        style.methods.ApplyAppearanceSettings(m, ...)
        if style.active then style:ApplyArt(); style:UpdateBars() end
    end
    module.UpdateExhaustionTick = function(m, ...)
        style.methods.UpdateExhaustionTick(m, ...)
        if style.active then style:ApplyArt(); style:UpdateBars() end
    end
    module.ShowElementsOnAlt = function(m, ...)
        style.methods.ShowElementsOnAlt(m, ...)
        if style.active then
            local db = DB()
            if db and db.showExperienceBarOnAlt then style.xpAlpha = 1 end
            if db and db.showReputationBarOnAlt then style.repAlpha = 1 end
            style:UpdateBars()
            style:ApplyArt()
        end
    end
    module.HideElementsOnAltRelease = function(m, ...)
        style.methods.HideElementsOnAltRelease(m, ...)
        if style.active then
            style.xpAlpha, style.repAlpha = nil, nil
            style:UpdateBars()
            style:ApplyArt()
        end
    end
    module.ShowReputationBar = function(m, ...)
        style.methods.ShowReputationBar(m, ...)
        if style.active then
            style.repAlpha = ReputationWatchBar and ReputationWatchBar:GetAlpha() or nil
            style:UpdateBars()
            style:ApplyArt()
        end
    end
    module.HideReputationBar = function(m, ...)
        style.methods.HideReputationBar(m, ...)
        if style.active then
            style.repAlpha = nil
            style:UpdateBars()
            style:ApplyArt()
        end
    end
end

function style:Enable()
    if self.active or InCombatLockdown() then return end
    -- DragonUI's noop.lua removes these bars from Blizzard's frame-position
    -- manager.  Otherwise a pet-bar visibility change moves BottomLeft.
    if UIPARENT_MANAGED_FRAME_POSITIONS then
        self.managedPositions = self.managedPositions or {}
        for _, name in ipairs(MANAGED_BARS) do
            self.managedPositions[name] = UIPARENT_MANAGED_FRAME_POSITIONS[name]
            UIPARENT_MANAGED_FRAME_POSITIONS[name] = nil
        end
    end
    self:CreateBars()
    self:CreateVehicleExit()
    self.holder = self.holder or CreateFrame("Frame", "SarychUI_DragonMainBar",
        MainMenuBar or UIParent, "SecureHandlerStateTemplate")
    self.holder:SetSize(513, 42)
    self.holder:SetScale(1)
    self.holder:SetFrameLevel(50)
    self.holder:EnableMouse(false)
    self.holder:Show()
    if self.stanceHolder then self.stanceHolder:Show() end
    self.artFrameOnShow = MainMenuBarArtFrame and MainMenuBarArtFrame.GetScript
        and MainMenuBarArtFrame:GetScript("OnShow") or nil
    self:InstallMethods()
    self.active = true
    if RegisterStateDriver and self.vehicleExit then
        RegisterStateDriver(self.vehicleExit, "visibility",
            "[vehicleui] hide; [target=vehicle,exists] show; hide")
    end
    self.stanceArtTextures = {}
    for _, name in ipairs(STANCE_ART) do
        local texture = _G[name]
        if texture then self.stanceArtTextures[name] = texture:GetTexture() end
    end
    for _, name in ipairs(STOCK_ART) do Save(_G[name]) end
    for _, name in ipairs({ "MainMenuBarArtFrame", "MainMenuExpBar", "ReputationWatchBar",
        "ShapeshiftBarFrame",
        "ExhaustionTick", "ExhaustionLevelFillBar", "MainMenuBarExpText",
        "ReputationWatchBarText" }) do Save(_G[name]) end
    self.petOriginalShowgrid = PetActionBarFrame and PetActionBarFrame.showgrid
    self:Layout()
    if not self.hooksInstalled and hooksecurefunc then
        self.hooksInstalled = true
        for _, functionName in ipairs({ "UIParent_ManageFramePositions", "MultiActionBar_Update" }) do
            if type(_G[functionName]) == "function" then
                hooksecurefunc(functionName, function()
                    if style.active then style:Layout() end
                end)
            end
        end
        if type(MainMenuBar_ToPlayerArt) == "function" then
            hooksecurefunc("MainMenuBar_ToPlayerArt", function()
                style:RequestLayout(VEHICLE_ANIMATION_DELAY)
            end)
        end
        if type(VehicleMenuBar_UpdateActionBars) == "function" then
            hooksecurefunc("VehicleMenuBar_UpdateActionBars", function()
                style:RefreshVehicleHotkeys()
            end)
        end
        if type(VehicleMenuBar_MoveMicroButtons) == "function" then
            hooksecurefunc("VehicleMenuBar_MoveMicroButtons", function(skinName)
                if style.active and not skinName then
                    style:PositionPlayerMicroMenu()
                    style:RequestLayout(VEHICLE_ANIMATION_DELAY)
                end
            end)
        end
    end
    self.controller = self.controller or CreateFrame("Frame")
    for _, event in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION",
        "UPDATE_FACTION", "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED", "ACTIONBAR_PAGE_CHANGED",
         "PET_BAR_UPDATE", "UNIT_PET", "UNIT_ENTERING_VEHICLE", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE",
        "UPDATE_SHAPESHIFT_FORMS", "DISPLAY_SIZE_CHANGED"}) do
        self.controller:RegisterEvent(event)
    end
    self.controller:SetScript("OnEvent", function(_, event, unit)
        if not style.active then return end
        if event == "UNIT_ENTERING_VEHICLE" and unit == "player" then
            style.layoutPending = true
            style.layoutDelay = 0
            style.controller:Hide()
            return
        end
        if event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
            if unit ~= "player" then return end
            if event == "UNIT_EXITED_VEHICLE" then
                style:RequestLayout(VEHICLE_ANIMATION_DELAY)
            end
        elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" or
            event == "PLAYER_LEVEL_UP" or event == "UPDATE_FACTION"
            or event == "DISPLAY_SIZE_CHANGED" or event == "UNIT_PET"
            or event == "PET_BAR_UPDATE" or event == "UPDATE_SHAPESHIFT_FORMS"
            then
            style:Layout()
        end
        if event == "ACTIONBAR_PAGE_CHANGED" and MainMenuBarPageNumber then
            MainMenuBarPageNumber:SetText(GetActionBarPage())
        end
        style:UpdateBars()
        style:UpdatePetAndStance()
        if event == "PLAYER_REGEN_ENABLED" then
            style:RefreshVehicleHotkeys()
            style:RequestLayout()
        end
    end)
    self.controller:SetScript("OnUpdate", function(_, elapsed)
        if not style.active or not style.layoutPending then return end
        if (style.layoutDelay or 0) > 0 then
            style.layoutDelay = style.layoutDelay - elapsed
            return
        end
        style:Layout()
    end)
    self:RefreshVehicleHotkeys()
    -- Keep stock Blizzard bars available to SarychUI's visibility controller,
    -- while the visible DragonUI bars follow the same alpha transitions.
    if MainMenuExpBar then MainMenuExpBar:SetAlpha(0) end
    if ReputationWatchBar then ReputationWatchBar:SetAlpha(0) end
    if MainMenuBarMaxLevelBar then MainMenuBarMaxLevelBar:SetAlpha(0) end
    if MainMenuBarLeftEndCap then MainMenuBarLeftEndCap:SetAlpha(0) end
    if MainMenuBarRightEndCap then MainMenuBarRightEndCap:SetAlpha(0) end
end

function style:Disable()
    if not self.active then return end
    if InCombatLockdown() then return end
    self.active = false
    if self.controller then self.controller:UnregisterAllEvents(); self.controller:SetScript("OnEvent", nil) end
    if self.controller then self.controller:SetScript("OnUpdate", nil); self.controller:Hide() end
    self.layoutPending, self.layoutDelay = false, 0
    if self.holder then self.holder:Hide() end
    if self.petDriverRegistered and UnregisterStateDriver then
        UnregisterStateDriver(self.petHolder, "visibility")
        self.petDriverRegistered = false
    end
    if self.petHolder then self.petHolder:Hide() end
    if PetActionBarFrame then PetActionBarFrame.showgrid = self.petOriginalShowgrid end
    if self.stanceHolder then self.stanceHolder:Hide() end
    if self.vehicleExit then
        if UnregisterStateDriver then UnregisterStateDriver(self.vehicleExit, "visibility") end
        self.vehicleExit:Hide()
    end
    if self.xp then self.xp:Hide() end
    if self.rep then self.rep:Hide() end
    Restore()
    if self.stanceArtTextures then
        for _, name in ipairs(STANCE_ART) do
            local texture = _G[name]
            if texture then texture:SetTexture(self.stanceArtTextures[name]) end
        end
        self.stanceArtTextures = nil
    end
    if UIPARENT_MANAGED_FRAME_POSITIONS and self.managedPositions then
        for _, name in ipairs(MANAGED_BARS) do
            UIPARENT_MANAGED_FRAME_POSITIONS[name] = self.managedPositions[name]
        end
        self.managedPositions = nil
    end
    if MainMenuBarArtFrame and MainMenuBarArtFrame.SetScript then
        MainMenuBarArtFrame:SetScript("OnShow", self.artFrameOnShow)
    end
    for name, method in pairs(self.methods) do module[name] = method end
    self.methodsInstalled = false
    self.xpAlpha, self.repAlpha = nil, nil
end
