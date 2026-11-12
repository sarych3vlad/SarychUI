local module = SarychUI.modules.focus_assignment
-- Runtime owned by interactions; legacy tools profile keys are preserved.
local moduleName = "tools"
local S = {}
local SuiTimer = select(2, ...).Compat.Timer

local pairs, select, pcall = pairs, select, pcall

local floor, max, min = math.floor, math.max, math.min

local abs, sqrt, deg, atan2, ceil, cos, rad, sin, exp = math.abs, math.sqrt, math.deg, math.atan2, math.ceil, math.cos, math.rad, math.sin, math.exp

local gsub, find, gmatch = string.gsub, string.find, string.gmatch

local GetTime = GetTime

local function DB()
    if not SarychUI or not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules then
        return nil
    end
    return SarychUI.db.profile.modules[moduleName]
end

local mouseButton = "1"

S.focuserButton, S.createFrameHook, S.scannerFrame = nil, nil, nil

S.focuserSteerActive, S.focuserSteerTurnHooked = false, false

S.focuserUsedMoveForward, S.focuserKeyMode, S.focuserSteerFrame = false, "focus", nil

local function GetFocuserModifier()
    local db = DB()
    if not db then return "ALT" end

    local key = tonumber(db.focuserModifierKey) or 2
    if key == 1 then
        return "SHIFT"
    elseif key == 2 then
        return "ALT"
    elseif key == 3 then
        return "CTRL"
    end
    return "ALT"  -- Default to ALT
end

local function FocuserActionAttributes()
    local modifier = GetFocuserModifier()
    if modifier == "ALT" then
        return "type1", "macrotext"
    end
    modifier = modifier:lower() .. "-"
    return modifier .. "type1", modifier .. "macrotext"
end


S.altCdHooksInstalled, S.altCdEnabled = false, false

S.altCdUnitBarEventFrame = nil

S.altCdAuraUpdateHooked = false

local FOCUSER_MACROTEXT = "/focus mouseover"

local function ConfigureFocuserButton(button)
    if not button or (InCombatLockdown and InCombatLockdown()) then return end
    button:SetAttribute("shift-type1", nil)
    button:SetAttribute("shift-macrotext", nil)
    button:SetAttribute("ctrl-type1", nil)
    button:SetAttribute("ctrl-macrotext", nil)
    local typeAttr, macroAttr = FocuserActionAttributes()
    button:SetAttribute(typeAttr, "macro")
    button:SetAttribute(macroAttr, FOCUSER_MACROTEXT)
end

local ANNOUNCE_UNIT_TEXTS = {
    "PlayerFrameHealthBarText", "PlayerFrameManaBarText",
    "TargetFrameTextureFrameHealthBarText", "TargetFrameTextureFrameManaBarText",
    "FocusFrameHealthBarText", "FocusFrameManaBarText",
    "PartyMemberFrame1HealthBarText", "PartyMemberFrame1ManaBarText",
    "PartyMemberFrame2HealthBarText", "PartyMemberFrame2ManaBarText",
    "PartyMemberFrame3HealthBarText", "PartyMemberFrame3ManaBarText",
    "PartyMemberFrame4HealthBarText", "PartyMemberFrame4ManaBarText",
}

local ANNOUNCE_UNIT_BARS = {
    "PlayerFrameHealthBar", "PlayerFrameManaBar",
    "TargetFrameHealthBar", "TargetFrameManaBar",
    "FocusFrameHealthBar", "FocusFrameManaBar",
    "PartyMemberFrame1HealthBar", "PartyMemberFrame1ManaBar",
    "PartyMemberFrame2HealthBar", "PartyMemberFrame2ManaBar",
    "PartyMemberFrame3HealthBar", "PartyMemberFrame3ManaBar",
    "PartyMemberFrame4HealthBar", "PartyMemberFrame4ManaBar",
}

local function ShouldSuppressFocusOnAnnounceBars()
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    return db and SarychUI:IsFocusAssignmentEnabled() and db.enableFocuser == 1 and SarychUI:IsAnnouncementsEnabled() and db.enableAltUnitBars == 1 and GetFocuserModifier() == "ALT"
end

local function IsCursorOverBox(frame)
    if not frame or not frame.IsShown or not frame:IsShown() then
        return false
    end
    if not GetCursorPosition or not frame.GetLeft or not frame.GetBottom then
        return false
    end
    local left, bottom = frame:GetLeft(), frame:GetBottom()
    local width, height = frame:GetWidth(), frame:GetHeight()
    if not left or not bottom or not width or not height or width <= 0 or height <= 0 then
        return false
    end
    local scale = frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
    if not scale or scale == 0 then
        scale = 1
    end
    local x, y = GetCursorPosition()
    x, y = x / scale, y / scale
    return x >= left and x <= (left + width) and y >= bottom and y <= (bottom + height)
end

local function IsCursorOverFrame(frame)
    if not frame or not frame.IsShown or not frame:IsShown() then
        return false
    end
    if frame.GetAlpha and frame:GetAlpha() <= 0 then
        return false
    end
    if not GetCursorPosition or not frame.GetCenter then
        return false
    end
    local cx, cy = frame:GetCenter()
    if not cx or not cy then
        return false
    end
    local scale = frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
    if not scale or scale == 0 then
        scale = 1
    end
    local x, y = GetCursorPosition()
    x, y = x / scale, y / scale
    local width = (frame.GetStringWidth and frame:GetStringWidth()) or 0
    local height = (frame.GetStringHeight and frame:GetStringHeight()) or 0
    if not width or width < 8 then
        width = frame.GetWidth and frame:GetWidth() or 0
    end
    if not height or height < 8 then
        height = frame.GetHeight and frame:GetHeight() or 0
    end
    if not width or width < 8 then
        width = 48
    end
    if not height or height < 8 then
        height = 14
    end
    return x >= (cx - width / 2 - 6) and x <= (cx + width / 2 + 6)
        and y >= (cy - height / 2 - 4) and y <= (cy + height / 2 + 4)
end

local function IsOverNamedFrame(name)
    return IsCursorOverFrame(name and _G[name])
end

local function IsOverCompactResourceText()
    local function over(frame)
        local text = frame and (frame.statusText or (frame.overlay and frame.overlay.statusText))
        return text and IsCursorOverFrame(text)
    end
    local i = 1
    while i <= 40 do
        local frame = _G["CompactRaidFrame" .. i]
        if not frame then
            break
        end
        if over(frame) then
            return true
        end
        i = i + 1
    end
    for n = 1, 5 do
        if over(_G["CompactPartyFrameMember" .. n]) then
            return true
        end
    end
    return false
end

local function IsOverAnnounceUnitBar()
    if S.suppressFocuserForAnnounceBar then
        return true
    end
    for i = 1, #ANNOUNCE_UNIT_TEXTS do
        if IsOverNamedFrame(ANNOUNCE_UNIT_TEXTS[i]) then
            return true
        end
    end
    if IsOverCompactResourceText() then
        return true
    end
    if S.resourceHits then
        for i = 1, #S.resourceHits do
            local hit = S.resourceHits[i]
            if hit and hit:IsShown() and IsCursorOverBox(hit) then
                return true
            end
        end
    end
    local focus = GetMouseFocus and GetMouseFocus()
    while focus and focus ~= UIParent and focus ~= WorldFrame do
        local name = focus.GetName and focus:GetName()
        if name then
            for i = 1, #ANNOUNCE_UNIT_TEXTS do
                if name == ANNOUNCE_UNIT_TEXTS[i] then
                    return true
                end
            end
        end
        if not focus.GetParent then
            break
        end
        focus = focus:GetParent()
    end
    return false
end

local function ShouldSuppressPlayerBarSecureClick()
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    return db and SarychUI:IsAnnouncementsEnabled() and db.enableAltUnitBars == 1
end

local function InstallPlayerBarFrameXMLClickGuard()
    local bars = {}
    for i = 1, #ANNOUNCE_UNIT_BARS do
        bars[i] = _G[ANNOUNCE_UNIT_BARS[i]]
    end
    for i = 1, #bars do
        local bar = bars[i]
        if not bar then
            -- skip
        else
            if bar.__SarychUIFrameXMLClickGuard and not bar.__SarychUIFrameXMLAltAttrGuard then
                -- Old build: tainted SetScript Click wrapper — strip it.
                bar:SetScript("OnMouseUp", nil)
                bar.__SarychUIAltCDUnitBarHooked = nil
            end
            S.barXMLGuard = S.barXMLGuard or setmetatable({}, { __mode = "k" })
            if not bar.__SarychUIFrameXMLAltAttrGuard and not S.barXMLGuard[bar] then
                bar:HookScript("OnMouseDown", function(self, button)
                    if not ShouldSuppressPlayerBarSecureClick() then
                        return
                    end
                    if button ~= "LeftButton" or not IsAltKeyDown or not IsAltKeyDown() then
                        return
                    end
                    if not IsOverAnnounceUnitBar() then
                        return
                    end
                    if InCombatLockdown and InCombatLockdown() then
                        return
                    end
                    local parent = self.GetParent and self:GetParent()
                    if not parent or not parent.SetAttribute then
                        return
                    end
                    S.barAttrGuard = S.barAttrGuard or setmetatable({}, { __mode = "k" })
                    if S.barAttrGuard[self] then
                        return
                    end
                    local modKey = GetFocuserModifier():lower() .. "-type" .. mouseButton
                    S.barAttrGuard[self] = { parent, modKey, parent:GetAttribute(modKey) }
                    parent:SetAttribute(modKey, nil)
                    S.suppressFocuserForAnnounceBar = true
                end)
                bar:HookScript("OnMouseUp", function(self)
                    local saved = S.barAttrGuard and S.barAttrGuard[self]
                    if not saved then
                        return
                    end
                    local parent, key, value = saved[1], saved[2], saved[3]
                    if parent and parent.SetAttribute and not (InCombatLockdown and InCombatLockdown()) then
                        parent:SetAttribute(key, value)
                    end
                    S.barAttrGuard[self] = nil
                end)
                S.barXMLGuard[bar] = true
            end
        end
    end
end

local function InstallFocuserAnnounceBarGuard(button)
    if not button or not button.HookScript or button.__SarychUIAnnounceBarGuard then
        return
    end

    button:HookScript("PreClick", function(self, clickedButton, down)
        if not down or clickedButton ~= "LeftButton" then
            return
        end
        if not ShouldSuppressFocusOnAnnounceBars() then
            return
        end
        if not IsOverAnnounceUnitBar() then
            return
        end
        local typeAttr, macroAttr = FocuserActionAttributes()
        if self._sarychFocuserOldType1 == nil and self._sarychFocuserOldMacro == nil then
            self._sarychFocuserTypeAttr = typeAttr
            self._sarychFocuserMacroAttr = macroAttr
            self._sarychFocuserOldType1 = self:GetAttribute(typeAttr)
            self._sarychFocuserOldMacro = self:GetAttribute(macroAttr)
        end
        self:SetAttribute(typeAttr, nil)
        self:SetAttribute(macroAttr, nil)
    end)
    button:HookScript("PostClick", function(self)
        S.suppressFocuserForAnnounceBar = nil
        if self._sarychFocuserOldType1 == nil and self._sarychFocuserOldMacro == nil then
            return
        end
        self:SetAttribute(self._sarychFocuserTypeAttr, self._sarychFocuserOldType1 or "macro")
        self:SetAttribute(self._sarychFocuserMacroAttr, self._sarychFocuserOldMacro or FOCUSER_MACROTEXT)
        self._sarychFocuserTypeAttr = nil
        self._sarychFocuserMacroAttr = nil
        self._sarychFocuserOldType1 = nil
        self._sarychFocuserOldMacro = nil
    end)
    button.__SarychUIAnnounceBarGuard = true
end

local function IsFocuserEnabled()
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    return db and SarychUI:IsFocusAssignmentEnabled() and db.enableFocuser == 1
end

local function IsFocuserModifierDown()
    local modifier = GetFocuserModifier()
    if modifier == "SHIFT" then
        return IsShiftKeyDown and IsShiftKeyDown()
    elseif modifier == "CTRL" then
        return IsControlKeyDown and IsControlKeyDown()
    end
    return IsAltKeyDown and IsAltKeyDown()
end

local function FocuserOverrideKey()
    return GetFocuserModifier() .. "-BUTTON" .. mouseButton
end

local function SetFocuserOverrideMode(mode)
    if not S.focuserButton then
        return false
    end
    if InCombatLockdown and InCombatLockdown() then
        return false
    end
    ClearOverrideBindings(S.focuserButton)
    if mode == "camera" then
        SetOverrideBinding(S.focuserButton, true, FocuserOverrideKey(), "CAMERAORSELECTORMOVE")
    elseif mode == "camera-release" then
        -- Alt released while LMB still down: keep Blizzard stop on plain LMB-up
        -- so mouselook/cursor is not stuck (ALT-BUTTON1 up was stolen by remap).
        SetOverrideBinding(S.focuserButton, true, "BUTTON" .. mouseButton, "CAMERAORSELECTORMOVE")
    else
        SetOverrideBindingClick(S.focuserButton, true, FocuserOverrideKey(), "SarychUIFocuserButton")
    end
    S.focuserKeyMode = mode
    return true
end

local function RestoreFocuserFromCamera()
    if IsMouseButtonDown and IsMouseButtonDown("LeftButton") then
        return SetFocuserOverrideMode("camera-release")
    end
    S.focuserSteerActive = false
    return SetFocuserOverrideMode("focus")
end

SarychUI = SarychUI or {}

function SarychUI:FocuserNotifySteer(active, reason)
    S.focuserSteerActive = active and true or false
    if active then
        SetFocuserOverrideMode("camera")
    else
        RestoreFocuserFromCamera()
    end
end

function SarychUI:FocuserBindingDown()
end

function SarychUI:FocuserBindingUp()
    RestoreFocuserFromCamera()
end

local function UpdateFocuserOverrideForState()
    if not IsFocuserEnabled() then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        return
    end

    -- Wait for LMB-up so Blizzard CameraOrSelectOrMoveStop can run.
    if S.focuserKeyMode == "camera-release" then
        if not (IsMouseButtonDown and IsMouseButtonDown("LeftButton")) then
            S.focuserSteerActive = false
            SetFocuserOverrideMode("focus")
        end
        return
    end

    if not IsFocuserModifierDown() then
        if S.focuserKeyMode == "camera" or S.focuserSteerActive then
            RestoreFocuserFromCamera()
        elseif S.focuserKeyMode ~= "focus" then
            SetFocuserOverrideMode("focus")
        end
        return
    end

    local rmb = IsMouseButtonDown and IsMouseButtonDown("RightButton")
    local want = rmb and "camera" or "focus"
    if want ~= S.focuserKeyMode then
        S.focuserSteerActive = want == "camera"
        SetFocuserOverrideMode(want)
    end
end

local function InstallFocuserBothButtonMove(button)
    if button and button.HookScript and not button.__SarychUIBothButtonMove then
        button:HookScript("PreClick", function(self, clickedButton, down)
            if not down or clickedButton ~= "LeftButton" then
                return
            end
            if not (IsMouseButtonDown and IsMouseButtonDown("RightButton")) then
                return
            end
            -- RMB held: never /focus on this click.
            if self._sarychFocuserOldType1 == nil and self._sarychFocuserOldMacro == nil then
                local typeAttr, macroAttr = FocuserActionAttributes()
                self._sarychFocuserTypeAttr = typeAttr
                self._sarychFocuserMacroAttr = macroAttr
                self._sarychFocuserOldType1 = self:GetAttribute(typeAttr)
                self._sarychFocuserOldMacro = self:GetAttribute(macroAttr)
                self:SetAttribute(typeAttr, nil)
                self:SetAttribute(macroAttr, nil)
            end
        end)
        button.__SarychUIBothButtonMove = true
    end

    if not S.focuserSteerFrame then
        S.focuserSteerFrame = CreateFrame("Frame")
        local acc = 0
        S.focuserSteerFrame:SetScript("OnUpdate", function(_, elapsed)
            -- Poll every frame while mouselook may be active / releasing.
            if S.focuserKeyMode == "camera" or S.focuserKeyMode == "camera-release" then
                UpdateFocuserOverrideForState()
                return
            end
            acc = acc + elapsed
            if acc < 0.05 then
                return
            end
            acc = 0
            UpdateFocuserOverrideForState()
        end)
    end
    S.focuserSteerFrame:Show()

    if S.focuserSteerTurnHooked or type(hooksecurefunc) ~= "function" then
        return
    end
    S.focuserSteerTurnHooked = true

    -- Immediate edge (same frame as RMB) — no movement API calls.
    if TurnOrActionStart then
        hooksecurefunc("TurnOrActionStart", function()
            if not IsFocuserEnabled() or not IsFocuserModifierDown() then
                return
            end
            S.focuserSteerActive = true
            SetFocuserOverrideMode("camera")
        end)
    end
    if TurnOrActionStop then
        hooksecurefunc("TurnOrActionStop", function()
            if S.focuserKeyMode == "camera" or S.focuserKeyMode == "camera-release" or S.focuserSteerActive then
                UpdateFocuserOverrideForState()
            end
        end)
    end
end

local function IsBlizzardArenaEnemyFrame(frame)
    local name = frame and frame.GetName and frame:GetName()
    return type(name) == "string" and name:match("^ArenaEnemyFrame%d+") ~= nil
end

S.focusAttrByFrame = S.focusAttrByFrame or setmetatable({}, { __mode = "k" })

local InstallCompactResourceAnnounce

local function SetFocusHotkey(frame)
    if not IsFocuserEnabled() then return end
    if not frame or not frame.SetAttribute or IsBlizzardArenaEnemyFrame(frame) then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    local attr = GetFocuserModifier():lower() .. "-type" .. mouseButton
    local prev = S.focusAttrByFrame[frame]
    if prev and prev ~= attr then
        frame:SetAttribute(prev, nil)
    end
    if frame:GetAttribute(attr) ~= "focus" then
        frame:SetAttribute(attr, "focus")
    end
    S.focusAttrByFrame[frame] = attr
    InstallCompactResourceAnnounce(frame)
end

S.badgeBuyerFrame, S.badgeBuyerInitialized = nil, false

S.badgeBuyerHooksInstalled = false

S.badgeBuyQueue = S.badgeBuyQueue or { index = nil, remaining = 0 }

S.badgeBuyDriver = S.badgeBuyDriver or nil

local COMPACT_PARTY_SLOTS = 8

local COMPACT_RAID_FRAMES = 40

local function IsSecureUnitFrame(frame)
	return type(frame) == "table" and type(frame.SetAttribute) == "function"
end

local function UpdateCompactParty()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not SarychUI:IsFocusAssignmentEnabled() then return end

    if InCombatLockdown and InCombatLockdown() then return end

    local duf = {
        PlayerFrame, PetFrame,
        PartyMemberFrame1, PartyMemberFrame2, PartyMemberFrame3, PartyMemberFrame4,
        PartyMemberFrame1PetFrame, PartyMemberFrame2PetFrame, PartyMemberFrame3PetFrame, PartyMemberFrame4PetFrame,
        TargetFrame, TargetofTargetFrame, FocusFrame,
    }
    for i = 1, #duf do
        if IsSecureUnitFrame(duf[i]) then
            SetFocusHotkey(duf[i])
        end
    end

    local bossIdx
    for bossIdx = 1, 5 do
        local boss = _G["Boss" .. bossIdx .. "TargetFrame"]
        if IsSecureUnitFrame(boss) then
            SetFocusHotkey(boss)
        end
    end

    if not _G.CompactPartyFrameMember1 and not _G.CompactRaidFrame1 then
        return
    end

    local partyLimit = tonumber(COMPACT_PARTY_SLOTS) or 4
    for partyIdx = 1, partyLimit do
        local pf = _G["CompactPartyFrameMember" .. partyIdx]
        if IsSecureUnitFrame(pf) then
            SetFocusHotkey(pf)
            local pet = _G["CompactPartyFrameMember" .. partyIdx .. "PetFrame"]
            if IsSecureUnitFrame(pet) then
                SetFocusHotkey(pet)
            end
        end
    end

    local raidLimit = tonumber(COMPACT_RAID_FRAMES) or 5
    for raidIdx = 1, raidLimit do
        local rf = _G["CompactRaidFrame" .. raidIdx]
        if IsSecureUnitFrame(rf) then
            SetFocusHotkey(rf)
        end
    end
end

S.arenaRightClickFocusInitialized, S.arenaRightClickFocusEventFrame = false, nil

local function SetArenaRightClickFocus(frame)
    if not frame or not frame.SetAttribute or IsBlizzardArenaEnemyFrame(frame) then return end
    if InCombatLockdown() then return end

    frame:SetAttribute("type2", "focus")
    frame:SetAttribute("unit", frame.unit or frame:GetAttribute("unit"))

    if frame.RegisterForClicks then
        frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end
end

local function ClearArenaRightClickFocus(frame)
    if not frame or not frame.SetAttribute or IsBlizzardArenaEnemyFrame(frame) then return end
    if InCombatLockdown() then return end

    frame:SetAttribute("type2", nil)
end

function SarychUI.modules.focus_assignment:ApplyFocuserModifier()
    if IsFocuserEnabled() then
        ConfigureFocuserButton(S.focuserButton)
        SetFocuserOverrideMode("focus")
    end
end

function SarychUI.modules.focus_assignment:ApplyFocuser()
    local db = DB()
    if not db then return end

    if SarychUI:IsFocusAssignmentEnabled() and db.enableFocuser == 1 then
        SarychUI.modules.focus_assignment:EnableFocuser()
    else
        SarychUI.modules.focus_assignment:DisableFocuser()
    end
end

function SarychUI.modules.focus_assignment:EnableFocuser()
    local db = DB()
    if not db then return end

    -- Do not hooksecurefunc("CreateFrame"). ArenaEnemyFrame_OnLoad builds its
    -- right-click handler (Blizzard_ArenaUI.lua:128 FocusUnit) immediately after
    -- the frame is created. On this client that post-hook taints the rest of
    -- OnLoad, so the handler is born tainted and combat FocusUnit is blocked.
    -- New party/raid/boss frames are picked up by UpdateCompactParty.

    -- Create override button for /focus mouseover
    if not S.focuserButton then
        S.focuserButton = CreateFrame("CheckButton", "SarychUIFocuserButton", UIParent, "SecureActionButtonTemplate")
        S.focuserButton:SetAttribute("type1", "macro")
        S.focuserButton:SetAttribute("macrotext", FOCUSER_MACROTEXT)
    else
        S.focuserButton:SetAttribute("type1", "macro")
        S.focuserButton:SetAttribute("macrotext", FOCUSER_MACROTEXT)
    end
    ConfigureFocuserButton(S.focuserButton)
    InstallFocuserAnnounceBarGuard(S.focuserButton)
    InstallPlayerBarFrameXMLClickGuard()
    InstallFocuserBothButtonMove(S.focuserButton)

    if S.focuserButton then
        -- Focus via SetOverrideBindingClick; RMB+mod remaps to CAMERAORSELECTORMOVE.
        SetFocuserOverrideMode("focus")
    end

    -- Set focus hotkey on existing unit frames
    local duf = {
        PlayerFrame, PetFrame,
        PartyMemberFrame1, PartyMemberFrame2, PartyMemberFrame3, PartyMemberFrame4,
        PartyMemberFrame1PetFrame, PartyMemberFrame2PetFrame, PartyMemberFrame3PetFrame, PartyMemberFrame4PetFrame,
        TargetFrame, TargetofTargetFrame,
    }
    for _,frame in pairs(duf) do
        SetFocusHotkey(frame)
    end

    -- Также применяем правый клик на арена фреймах, если он включен
    if db.enableArenaRightClickFocus == 1 then
        for i = 1, 5 do
            local frame = _G["ArenaEnemyFrame"..i]
            if frame then SetArenaRightClickFocus(frame) end
        end
    end

    -- Update compact frames
    UpdateCompactParty()
end

function SarychUI.modules.focus_assignment:DisableFocuser()
    S.focuserSteerActive = false
    S.focuserUsedMoveForward = false
    S.focuserKeyMode = "focus"
    if S.focuserSteerFrame then
        S.focuserSteerFrame:Hide()
    end

    -- Clear override binding
    if S.focuserButton then
        ClearOverrideBindings(S.focuserButton)
    end

    if not (InCombatLockdown and InCombatLockdown()) and S.focusAttrByFrame then
        for frame, attr in pairs(S.focusAttrByFrame) do
            if frame and frame.SetAttribute and attr then
                frame:SetAttribute(attr, nil)
            end
            S.focusAttrByFrame[frame] = nil
        end
    end
end

function SarychUI.modules.focus_assignment:ApplyArenaRightClickFocus()
    local db = DB()
    if not db or not SarychUI:IsFocusAssignmentEnabled() then return end

    if db.enableArenaRightClickFocus == 1 then
        SarychUI.modules.focus_assignment:EnableArenaRightClickFocus()
    else
        SarychUI.modules.focus_assignment:DisableArenaRightClickFocus()
    end
end

function SarychUI.modules.focus_assignment:EnableArenaRightClickFocus()
    local db = DB()
    if not db or not SarychUI:IsFocusAssignmentEnabled() then return end
    if InCombatLockdown() then
        -- Schedule for after combat
        SuiTimer.After(0.5, function() SarychUI.modules.focus_assignment:EnableArenaRightClickFocus() end)
        return
    end

    -- Do not LoadAddOn("Blizzard_ArenaUI").  Loading it from addon code runs
    -- ArenaEnemyFrame OnLoad tainted, and combat Show/Hide is then blocked.
    -- Frames are wired when the client has already loaded them.

    -- Set up right-click focus on arena enemy frames
    local arenaFrames = {
        "ArenaEnemyFrame1", "ArenaEnemyFrame2", "ArenaEnemyFrame3", "ArenaEnemyFrame4", "ArenaEnemyFrame5",
    }

    for _, frameName in ipairs(arenaFrames) do
        local frame = _G[frameName]
        if frame then
            SetArenaRightClickFocus(frame)
            -- Также применяем focuser (модификатор+ЛКМ), если он включен
            if SarychUI:IsFocusAssignmentEnabled() and db.enableFocuser == 1 then
                SetFocusHotkey(frame)
            end
        end
    end

    -- Create event frame to hook into arena frame creation/updates
    if not S.arenaRightClickFocusEventFrame then
        S.arenaRightClickFocusEventFrame = CreateFrame("Frame")
        S.arenaRightClickFocusEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        S.arenaRightClickFocusEventFrame:RegisterEvent("ARENA_OPPONENT_UPDATE")
        S.arenaRightClickFocusEventFrame:SetScript("OnEvent", function(self, event)
            if InCombatLockdown() then return end

            local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
            if not db or not SarychUI:IsFocusAssignmentEnabled() then return end

            -- Re-apply right-click focus if enabled
            if db.enableArenaRightClickFocus == 1 then
                for i = 1, 5 do
                    local frame = _G["ArenaEnemyFrame"..i]
                    if frame then SetArenaRightClickFocus(frame) end
                end
            end

            -- Re-apply focuser if enabled (модификатор+ЛКМ)
            if SarychUI:IsFocusAssignmentEnabled() and db.enableFocuser == 1 then
                for i = 1, 5 do
                    local frame = _G["ArenaEnemyFrame"..i]
                    if frame then SetFocusHotkey(frame) end
                end
            end
        end)
    end

    S.arenaRightClickFocusInitialized = true
end

function SarychUI.modules.focus_assignment:DisableArenaRightClickFocus()
    if InCombatLockdown() then
        SuiTimer.After(0.5, function() SarychUI.modules.focus_assignment:DisableArenaRightClickFocus() end)
        return
    end

    -- Remove right-click focus from arena enemy frames
    for i = 1, 5 do
        local frame = _G["ArenaEnemyFrame"..i]
        if frame then ClearArenaRightClickFocus(frame) end
    end

    -- Unregister events
    if S.arenaRightClickFocusEventFrame then
        S.arenaRightClickFocusEventFrame:UnregisterAllEvents()
        S.arenaRightClickFocusEventFrame:SetScript("OnEvent", nil)
        S.arenaRightClickFocusEventFrame = nil
    end

    S.arenaRightClickFocusInitialized = false
end

local AltCD = {}

AltCD.BUTTON_GROUPS = {
    { "ActionButton", 12 },
    { "MultiBarBottomLeftButton", 12 },
    { "MultiBarBottomRightButton", 12 },
    { "MultiBarRightButton", 12 },
    { "MultiBarLeftButton", 12 },
    { "BonusActionButton", 10 },
}

AltCD.overlays = setmetatable({}, { __mode = "k" })

AltCD.pendingOverlayButtons = setmetatable({}, { __mode = "k" })

AltCD.overlaysEnabled = false

function AltCD.IsActive()
    local db = DB()
    return db and SarychUI:IsAnnouncementsEnabled() and db.enableAltCD == 1 and S.altCdEnabled
end

function AltCD.IsUnitBarActive()
    local db = DB()
    return db and SarychUI:IsAnnouncementsEnabled() and db.enableAltUnitBars == 1
end

function AltCD.IsAuraActive()
    local db = DB()
    return db and SarychUI:IsAnnouncementsEnabled() and db.enableAltAuras == 1
end

AltCD.PREFIX = "> "

AltCD.CHANNEL_MODES = {
    adaptive = true,
    say = true,
    party = true,
    raid = true,
    battleground = true,
    guild = true,
    yell = true,
}

AltCD.CHANNEL_CONTEXTS = {
    { key = "bg",    dbKey = "altAnnounceChannelBG",    default = "say" },
    { key = "arena", dbKey = "altAnnounceChannelArena", default = "adaptive" },
    { key = "raid",  dbKey = "altAnnounceChannelRaid",  default = "adaptive" },
    { key = "party", dbKey = "altAnnounceChannelParty", default = "adaptive" },
    { key = "solo",  dbKey = "altAnnounceChannelSolo",  default = "adaptive" },
}

function AltCD.NormalizeChannelMode(mode, fallback)
    if mode and AltCD.CHANNEL_MODES[mode] then
        return mode
    end
    return fallback or "adaptive"
end

function AltCD.IsInBattleground()
    if UnitInBattleground and UnitInBattleground("player") then
        return true
    end
    local instanceType = IsInInstance and select(2, IsInInstance())
    return instanceType == "pvp"
end

function AltCD.GetChannelContextKey()
    if AltCD.IsInBattleground() then
        return "bg"
    end
    local instanceType = IsInInstance and select(2, IsInInstance())
    if instanceType == "arena" then
        return "arena"
    end
    if (GetNumRaidMembers and GetNumRaidMembers() or 0) > 0 or (SarychUI.Compat.IsInRaid and SarychUI.Compat.IsInRaid()) then
        return "raid"
    end
    if (GetNumPartyMembers and GetNumPartyMembers() or 0) > 0 or (SarychUI.Compat.IsInGroup and SarychUI.Compat.IsInGroup()) then
        return "party"
    end
    return "solo"
end

function AltCD.GetChannelMode()
    local db = DB()
    local context = AltCD.GetChannelContextKey()
    for i = 1, #AltCD.CHANNEL_CONTEXTS do
        local entry = AltCD.CHANNEL_CONTEXTS[i]
        if entry.key == context then
            local mode = db and db[entry.dbKey]
            return AltCD.NormalizeChannelMode(mode, entry.default)
        end
    end
    return "adaptive"
end

function AltCD.GetAdaptiveChatChannel()
    if (GetNumRaidMembers and GetNumRaidMembers() or 0) > 0 then
        return "RAID"
    end
    if SarychUI.Compat.IsInRaid and SarychUI.Compat.IsInRaid() then
        return "RAID"
    end
    if (GetNumPartyMembers and GetNumPartyMembers() or 0) > 0 then
        return "PARTY"
    end
    if SarychUI.Compat.IsInGroup and SarychUI.Compat.IsInGroup() then
        return "PARTY"
    end
    return "SAY"
end

function AltCD.ResolveChannelMode(mode)
    if mode == "say" then
        return "SAY"
    elseif mode == "party" then
        return "PARTY"
    elseif mode == "raid" then
        return "RAID"
    elseif mode == "battleground" then
        return "BATTLEGROUND"
    elseif mode == "guild" then
        return "GUILD"
    elseif mode == "yell" then
        return "YELL"
    end
    return AltCD.GetAdaptiveChatChannel()
end

function AltCD.GetChatChannel()
    return AltCD.ResolveChannelMode(AltCD.GetChannelMode())
end

function SarychUI.modules.announcements:ApplyInterruptAnnouncement()
    local db = DB()
    if db and SarychUI:IsAnnouncementsEnabled() and db.enableInterruptAnnouncement == 1 then
        SarychUI.modules.announcements:EnableInterruptAnnouncement()
    else
        SarychUI.modules.announcements:DisableInterruptAnnouncement()
    end
end

function SarychUI.modules.announcements:EnableInterruptAnnouncement()
    if not S.interruptAnnouncementFrame then
        S.interruptAnnouncementFrame = CreateFrame("Frame")
        S.interruptAnnouncementFrame:SetScript("OnEvent", function(_, event, timestamp, subevent,
            sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags,
            spellID, spellName, spellSchool, extraSpellID, extraSpellName)
            local db = DB()
            if event ~= "COMBAT_LOG_EVENT_UNFILTERED" or subevent ~= "SPELL_INTERRUPT"
                or not db or not SarychUI:IsAnnouncementsEnabled() or db.enableInterruptAnnouncement ~= 1
                or not sourceGUID or sourceGUID ~= UnitGUID("player") then
                return
            end

            local interruptedName = extraSpellName or (extraSpellID and GetSpellInfo(extraSpellID))
            local interruptName = spellName or (spellID and GetSpellInfo(spellID))
            if not interruptedName or interruptedName == "" or not interruptName or interruptName == "" then
                return
            end

            local interrupted = extraSpellID and GetSpellLink and GetSpellLink(extraSpellID)
                or "[" .. interruptedName .. "]"
            local interrupt = spellID and GetSpellLink and GetSpellLink(spellID)
                or "[" .. interruptName .. "]"
            local channel = AltCD.ResolveChannelMode(db.interruptAnnounceChannel)
            SendChatMessage("Прервал " .. interrupted .. " (" .. interrupt .. ")", channel)
        end)
    end
    S.interruptAnnouncementFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

function SarychUI.modules.announcements:DisableInterruptAnnouncement()
    if S.interruptAnnouncementFrame then
        S.interruptAnnouncementFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end
end

function AltCD.ReadNumericAttribute(button, ...)
    if not button or not button.GetAttribute then
        return nil
    end
    for i = 1, select("#", ...) do
        local key = select(i, ...)
        local value = button:GetAttribute(key)
        if type(value) == "number" and value > 0 then
            return value
        end
        if type(value) == "string" then
            local num = tonumber(value)
            if num and num > 0 then
                return num
            end
        end
    end
    return nil
end

function AltCD.IsBlizzardActionButton(button)
    if not button or not button.GetName then
        return false
    end
    local name = button:GetName()
    if not name then
        return false
    end
    for i = 1, #AltCD.BUTTON_GROUPS do
        local prefix = AltCD.BUTTON_GROUPS[i][1]
        local maxId = AltCD.BUTTON_GROUPS[i][2]
        local id = name:match("^" .. prefix .. "(%d+)$")
        if id and tonumber(id) <= maxId then
            return true
        end
    end
    return false
end

function AltCD.GetActionSlot(button)
    if not button then
        return nil
    end

    local slot = button.action
    if type(slot) ~= "number" or slot <= 0 then
        slot = AltCD.ReadNumericAttribute(button, "action", "action1")
    end

    if not slot or slot <= 0 or not HasAction(slot) then
        return nil
    end
    return slot
end

function AltCD.Trim(text)
    if not text then
        return ""
    end
    if strtrim then
        return strtrim(text)
    end
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

function AltCD.SpellIDFromLinkOrName(text)
    if not text or text == "" then
        return nil
    end
    text = AltCD.Trim(text)
    if text == "" then
        return nil
    end

    local link = GetSpellLink and GetSpellLink(text)
    if link then
        local spellID = tonumber(link:match("spell:(%d+)"))
        if spellID and spellID > 0 then
            return spellID
        end
    end

    if GetSpellInfo and GetSpellLink then
        local name = GetSpellInfo(text)
        if name and name ~= "" then
            link = GetSpellLink(name)
            if link then
                local spellID = tonumber(link:match("spell:(%d+)"))
                if spellID and spellID > 0 then
                    return spellID
                end
            end
        end
    end

    return nil
end

function AltCD.StripCastModifiers(text)
    local result = AltCD.Trim(text)
    if result == "" then
        return result
    end

    while true do
        local cleaned, count = result:gsub("^%b[]%s*", "")
        if count == 0 then
            break
        end
        result = cleaned
    end

    local first = result:match("^([^;]+)")
    return AltCD.Trim(first or result)
end

function AltCD.GetSpellIDFromMacro(macroIndex)
    if GetMacroSpell then
        local spellID = GetMacroSpell(macroIndex)
        if type(spellID) == "number" and spellID > 0 then
            return spellID
        end
    end

    if not GetMacroBody then
        return nil
    end

    local body = GetMacroBody(macroIndex)
    if not body or body == "" then
        return nil
    end

    for line in body:gmatch("[^\r\n]+") do
        local trimmed = AltCD.Trim(line)
        local showName = trimmed:match("^#showtooltip%s+(.+)$")
        if showName then
            local spellID = AltCD.SpellIDFromLinkOrName(AltCD.StripCastModifiers(showName))
            if spellID then
                return spellID
            end
        end
    end

    for line in body:gmatch("[^\r\n]+") do
        local trimmed = AltCD.Trim(line)
        local castText = trimmed:match("^/cast%s+(.+)$") or trimmed:match("^/use%s+(.+)$")
        if castText then
            local spellID = AltCD.SpellIDFromLinkOrName(AltCD.StripCastModifiers(castText))
            if spellID then
                return spellID
            end
        end
    end

    return nil
end

function AltCD.SpellMatchesActionTexture(spellID, actionTexture)
    if not spellID or not actionTexture then
        return true
    end
    local _, _, spellTexture = GetSpellInfo(spellID)
    if not spellTexture then
        return false
    end
    return spellTexture == actionTexture
end

function AltCD.PickSpellID(actionId, globalID, actionTexture)
    local candidates = {}
    if type(globalID) == "number" and globalID > 0 then
        candidates[#candidates + 1] = globalID
    end
    if type(actionId) == "number" and actionId > 0 then
        local seen = false
        for i = 1, #candidates do
            if candidates[i] == actionId then
                seen = true
                break
            end
        end
        if not seen then
            candidates[#candidates + 1] = actionId
        end
    end

    if #candidates == 0 then
        return nil
    end
    if not actionTexture then
        return candidates[1]
    end

    for i = 1, #candidates do
        if AltCD.SpellMatchesActionTexture(candidates[i], actionTexture) then
            return candidates[i]
        end
    end

    return nil
end

function AltCD.GetSpellLink(spellID)
    if not spellID or spellID <= 0 then
        return nil
    end

    if not GetSpellInfo(spellID) then
        return nil
    end

    local link = GetSpellLink and GetSpellLink(spellID)
    if not link or not link:match("|Hspell:") or not link:match("%[.+%]") then
        return nil
    end

    return link
end

function AltCD.IsSpellLearned(spellID)
    if not spellID or spellID <= 0 then
        return false
    end

    local name = GetSpellInfo(spellID)
    if not name or name == "" then
        return false
    end

    if IsSpellKnown then
        return IsSpellKnown(spellID)
    end

    return true
end

function AltCD.IsPassiveSpell(spellID)
    if not spellID then
        return false
    end

    if IsPassiveSpell then
        return IsPassiveSpell(spellID)
    end

    local name, _, _, cost, _, powerType, castTime, minRange, maxRange = GetSpellInfo(spellID)
    if not name then
        return false
    end

    if (maxRange or 0) ~= 0 or (minRange or 0) ~= 0 or (castTime or 0) ~= 0 then
        return false
    end
    if (cost or 0) > 0 or (powerType or 0) ~= 0 then
        return false
    end

    local start, duration = GetSpellCooldown(spellID)
    if (start or 0) > 0 or (duration or 0) > 0 then
        return false
    end

    if IsUsableSpell then
        local usable, notEnoughPower = IsUsableSpell(spellID)
        if usable or notEnoughPower then
            return false
        end
        return true
    end

    return false
end

AltCD.POWER_NAMES_RU = {
    [0] = "маны",
    [1] = "ярости",
    [2] = "концентрации",
    [3] = "энергии",
    [4] = "счастья",
    [5] = "рун",
    [6] = "силы рун",
}

AltCD.POWER_DEPLETED_RU = {
    [0] = "мана",
    [1] = "ярость",
    [2] = "концентрация",
    [3] = "энергия",
    [4] = "счастье",
    [5] = "руны",
    [6] = "сила рун",
}

function AltCD.GetResourceLabel(powerType)
    if powerType == nil then
        return "ресурса"
    end
    return AltCD.POWER_NAMES_RU[powerType] or "ресурса"
end

AltCD.GCD_SPELL = 61304

AltCD.COST_PATTERNS = {
    { "(%d+)%s*маны", "маны", 0 },
    { "(%d+)%s*энергии", "энергии", 3 },
    { "(%d+)%s*ярости", "ярости", 1 },
    { "(%d+)%s*концентрации", "концентрации", 2 },
    { "(%d+)%s*силы%s*рун", "силы рун", 6 },
    { "требуется%s+(%d+)", nil, nil },
}

function AltCD.ToBool(value)
    return value == true or value == 1
end

function AltCD.GetTooltipScanner()
    if AltCD.tooltipScanner then
        return AltCD.tooltipScanner
    end
    AltCD.tooltipScanner = CreateFrame("GameTooltip", "SarychUIAltCDTooltipScanner", UIParent, "GameTooltipTemplate")
    AltCD.tooltipScanner:SetOwner(UIParent, "ANCHOR_NONE")
    return AltCD.tooltipScanner
end

function AltCD.ParseTooltipCost(slot)
    if not slot then
        return nil, nil, nil
    end

    local scanner = AltCD.GetTooltipScanner()
    if not scanner or not scanner.SetAction then
        return nil, nil, nil
    end

    scanner:ClearLines()
    scanner:SetAction(slot)

    local tooltipName = scanner:GetName()
    if not tooltipName then
        return nil, nil, nil
    end

    for i = 1, 20 do
        local line = _G[tooltipName .. "TextLeft" .. i]
        local text = line and line.GetText and line:GetText()
        if text and text ~= "" then
            local lower = string.lower(text)
            for j = 1, #AltCD.COST_PATTERNS do
                local pattern, label, powerType = AltCD.COST_PATTERNS[j][1], AltCD.COST_PATTERNS[j][2], AltCD.COST_PATTERNS[j][3]
                local cost = lower:match(pattern)
                if cost then
                    cost = tonumber(cost)
                    if cost and cost > 0 then
                        if powerType == nil and UnitPowerType then
                            powerType = UnitPowerType("player")
                        end
                        if not label and powerType ~= nil then
                            label = AltCD.GetResourceLabel(powerType)
                        end
                        return cost, label, powerType
                    end
                end
            end
        end
    end

    return nil, nil, nil
end

function AltCD.GetSpellPowerType(spellID)
    local _, _, _, _, _, powerType = GetSpellInfo(spellID)
    if powerType ~= nil then
        return powerType
    end
    if UnitPowerType then
        return UnitPowerType("player")
    end
    return 0
end

function AltCD.GetSpellCost(spellID, powerType)
    local _, _, _, cost = GetSpellInfo(spellID)
    if cost and cost > 0 then
        return cost
    end

    if GetSpellPowerCost then
        local name = GetSpellInfo(spellID)
        if name then
            local costTable = GetSpellPowerCost(name)
            if costTable then
                for _, entry in pairs(costTable) do
                    if type(entry) == "table" and entry.cost and entry.cost > 0 then
                        if powerType == nil or entry.type == powerType then
                            return entry.cost
                        end
                    end
                end
            end
        end
    end

    return nil
end

function AltCD.IsGCDOnly(start, duration)
    if not duration or duration <= 0 then
        return true
    end
    if not GetSpellCooldown then
        return false
    end
    local _, gcdDuration = GetSpellCooldown(AltCD.GCD_SPELL)
    gcdDuration = gcdDuration or 0
    if gcdDuration > 0 and duration <= gcdDuration + 0.1 then
        return true
    end
    return false
end

function AltCD.GetResourceState(slot, spellID, spellName)
    if not slot or not IsUsableAction then
        return nil
    end

    local actionUsable, actionNoMana = IsUsableAction(slot)
    local spellUsable, spellNoMana

    if spellName and IsUsableSpell then
        spellUsable, spellNoMana = IsUsableSpell(spellName)
    elseif spellID and IsUsableSpell then
        spellUsable, spellNoMana = IsUsableSpell(spellID)
    end

    local lacksResource = AltCD.ToBool(actionNoMana) or AltCD.ToBool(spellNoMana)
    if not lacksResource then
        return nil
    end

    local powerType = UnitPowerType and UnitPowerType("player") or 0
    local label = AltCD.GetResourceLabel(powerType)
    local current = UnitPower and UnitPower("player", powerType) or 0

    local tooltipCost, tooltipLabel, tooltipPowerType = AltCD.ParseTooltipCost(slot)
    if tooltipCost then
        if tooltipPowerType ~= nil then
            powerType = tooltipPowerType
            current = UnitPower("player", powerType) or 0
        end
        if tooltipLabel then
            label = tooltipLabel
        end
        local missing = tooltipCost - current
        if missing > 0 then
            return label, missing
        end
        return label, nil
    end

    local cost = AltCD.GetSpellCost(spellID, powerType)
    if cost and cost > current then
        return label, cost - current
    end

    return label, nil
end

function AltCD.GetCooldownState(spellID, slot)
    local spellStart, spellDuration = 0, 0
    local slotStart, slotDuration = 0, 0

    if spellID and GetSpellCooldown then
        spellStart, spellDuration = GetSpellCooldown(spellID)
    end
    if slot and GetActionCooldown then
        slotStart, slotDuration = GetActionCooldown(slot)
    end

    spellStart = spellStart or 0
    spellDuration = spellDuration or 0
    slotStart = slotStart or 0
    slotDuration = slotDuration or 0

    local spellRemaining = 0
    if spellDuration > 0 and spellStart > 0 and not AltCD.IsGCDOnly(spellStart, spellDuration) then
        spellRemaining = ceil(spellStart + spellDuration - GetTime())
    end

    local slotRemaining = 0
    if slotDuration > 0 and slotStart > 0 and not AltCD.IsGCDOnly(slotStart, slotDuration) then
        slotRemaining = ceil(slotStart + slotDuration - GetTime())
    end

    local remaining = max(spellRemaining, slotRemaining)
    if remaining > 0 then
        return "timed", remaining
    end

    if spellDuration > 0 and spellStart <= 0 and not AltCD.IsGCDOnly(spellStart, spellDuration) then
        return "unknown"
    end
    if slotDuration > 0 and slotStart <= 0 and not AltCD.IsGCDOnly(slotStart, slotDuration) then
        return "unknown"
    end

    return "ready"
end

function AltCD.BuildMessage(spellLink, cdState, remainingCD, resourceLabel, resourceAmount, isPassive)
    if cdState == "timed" then
        return AltCD.PREFIX .. spellLink .. " перезаряжается: " .. remainingCD .. " сек."
    end
    if cdState == "unknown" then
        return AltCD.PREFIX .. spellLink .. " перезаряжается"
    end

    if resourceLabel then
        if resourceAmount and resourceAmount > 0 then
            return AltCD.PREFIX .. "На " .. spellLink .. " не хватает " .. resourceAmount .. " " .. resourceLabel
        end
        if resourceLabel ~= "ресурса" then
            return AltCD.PREFIX .. "На " .. spellLink .. " не хватает " .. resourceLabel
        end
        return AltCD.PREFIX .. "На " .. spellLink .. " не хватает ресурса"
    end

    if isPassive then
        return AltCD.PREFIX .. spellLink .. " изучена"
    end

    return AltCD.PREFIX .. spellLink .. " готова"
end

function AltCD.ResolveAction(button)
    local slot = AltCD.GetActionSlot(button)
    if not slot then
        return nil
    end

    local actionType, actionId, subType, globalID = GetActionInfo(slot)
    local actionTexture = GetActionTexture and GetActionTexture(slot)

    if actionType == "item" or actionType == "companion" then
        return nil
    end

    local spellID
    if actionType == "spell" then
        spellID = AltCD.PickSpellID(actionId, globalID, actionTexture)
    elseif actionType == "macro" and actionId then
        spellID = AltCD.GetSpellIDFromMacro(actionId)
        if spellID and actionTexture and not AltCD.SpellMatchesActionTexture(spellID, actionTexture) then
            spellID = nil
        end
    else
        return nil
    end

    if not spellID then
        return nil
    end

    local spellName = GetSpellInfo(spellID)
    if not spellName or spellName == "" then
        return nil
    end

    local spellLink = AltCD.GetSpellLink(spellID)
    if not spellLink then
        return nil
    end

    if not AltCD.IsSpellLearned(spellID) then
        return nil
    end

    local info = {
        slot = slot,
        spellID = spellID,
        spellName = spellName,
        spellLink = spellLink,
    }
    return info
end

function AltCD.AnnounceAction(info)
    if not info or not info.spellLink or not info.spellID then
        return
    end

    local spellLink = info.spellLink
    local cdState, remainingCD = AltCD.GetCooldownState(info.spellID, info.slot)
    local resourceLabel, resourceAmount = nil, nil
    local isPassive = false

    if cdState == "ready" then
        resourceLabel, resourceAmount = AltCD.GetResourceState(info.slot, info.spellID, info.spellName)
        if not resourceLabel then
            isPassive = AltCD.IsPassiveSpell(info.spellID)
        end
    end

    local message = AltCD.BuildMessage(spellLink, cdState, remainingCD, resourceLabel, resourceAmount, isPassive)
    if not message or message == "" then
        return
    end

    SendChatMessage(message, AltCD.GetChatChannel())
end

function AltCD.OnOverlayPostClick(sourceButton, mouseButton)
    if mouseButton ~= "LeftButton" or not AltCD.IsActive() or not IsAltKeyDown() then
        return
    end

    local actionInfo = AltCD.ResolveAction(sourceButton)
    if actionInfo then
        AltCD.AnnounceAction(actionInfo)
    end
end

function AltCD.EnsureOverlayCombatFrame()
    if S.altCdOverlayCombatFrame then
        return
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function()
        for button in pairs(AltCD.pendingOverlayButtons) do
            AltCD.pendingOverlayButtons[button] = nil
            AltCD.CreateActionOverlay(button)
        end
        AltCD.SetOverlaysEnabled(AltCD.overlaysEnabled)
    end)
    S.altCdOverlayCombatFrame = frame
end

function AltCD.CreateActionOverlay(button)
    if not button or AltCD.overlays[button] or not AltCD.IsBlizzardActionButton(button) then
        return AltCD.overlays[button]
    end

    if InCombatLockdown and InCombatLockdown() then
        AltCD.pendingOverlayButtons[button] = true
        AltCD.EnsureOverlayCombatFrame()
        return nil
    end

    local buttonName = button:GetName()
    -- Parent to UIParent. A child created here taints the action button, and
    -- CastSpellByName from its macro is then forbidden.
    local overlay = CreateFrame("Button", "SarychUIAltCDOverlay_" .. buttonName, UIParent, "SecureActionButtonTemplate")
    overlay:SetAllPoints(button)
    overlay:SetFrameStrata(button:GetFrameStrata())
    overlay:SetFrameLevel((button:GetFrameLevel() or 0) + 20)
    overlay:RegisterForClicks("LeftButtonUp")
    overlay:EnableMouse(true)
    overlay:SetScript("OnEnter", function()
        local onEnter = button.GetScript and button:GetScript("OnEnter")
        if onEnter then
            onEnter(button)
        end
    end)
    overlay:SetScript("OnLeave", function()
        local onLeave = button.GetScript and button:GetScript("OnLeave")
        if onLeave then
            onLeave(button)
        elseif GameTooltip then
            GameTooltip:Hide()
        end
    end)
    overlay:HookScript("PostClick", function(_, mouseButton)
        AltCD.OnOverlayPostClick(button, mouseButton)
    end)
    -- UIParent overlays cannot inherit later action-bar/cooldown layer changes.
    -- Guard the actual secure click as well, before it can execute the action.
    -- Communicate via our own frame; never write action attributes on the button.
    overlay:SetAttribute("altcd-enabled", AltCD.overlaysEnabled and true or false)
    overlay:SetScript("OnAttributeChanged", function(_, name, value)
        if name == "altcd-announce" and value then
            AltCD.OnOverlayPostClick(button, "LeftButton")
        end
    end)
    if SecureHandlerWrapScript then
        SecureHandlerWrapScript(button, "OnClick", overlay, [[
            if owner:GetAttribute("altcd-enabled") and button == "LeftButton"
                and IsAltKeyDown() and self:IsUnderMouse() then
                if down or not owner:GetAttribute("altcd-pressed") then
                    owner:SetAttribute("altcd-announce", nil)
                    owner:SetAttribute("altcd-announce", true)
                end
                owner:SetAttribute("altcd-pressed", down and true or nil)
                return false
            end
            owner:SetAttribute("altcd-pressed", nil)
        ]])
    end
    overlay:Hide()

    AltCD.overlays[button] = overlay
    if AltCD.overlaysEnabled and RegisterStateDriver then
        RegisterStateDriver(overlay, "visibility", "[mod:alt] show; hide")
    end
    return overlay
end

function AltCD.SetOverlaysEnabled(enabled)
    AltCD.overlaysEnabled = enabled and true or false
    if InCombatLockdown and InCombatLockdown() then
        AltCD.EnsureOverlayCombatFrame()
        return
    end

    for _, overlay in pairs(AltCD.overlays) do
        overlay:SetAttribute("altcd-enabled", AltCD.overlaysEnabled)
        overlay:SetAttribute("altcd-pressed", nil)
        if AltCD.overlaysEnabled and RegisterStateDriver then
            RegisterStateDriver(overlay, "visibility", "[mod:alt] show; hide")
        else
            if UnregisterStateDriver then
                UnregisterStateDriver(overlay, "visibility")
            end
            overlay:Hide()
        end
    end
end

function AltCD.HookButtonClickScripts(button)
    return AltCD.CreateActionOverlay(button)
end

function AltCD.HookAllActionButtons()
    for i = 1, #AltCD.BUTTON_GROUPS do
        local prefix = AltCD.BUTTON_GROUPS[i][1]
        local count = AltCD.BUTTON_GROUPS[i][2]
        for id = 1, count do
            AltCD.HookButtonClickScripts(_G[prefix .. id])
        end
    end
end

function AltCD.OnActionButtonLoad(button)
    AltCD.HookButtonClickScripts(button)
end

AltCD.UNIT_BAR_HOOKS = {
    { frameName = "PlayerFrameHealthBar", unit = "player", resourceType = "health" },
    { frameName = "PlayerFrameManaBar", unit = "player", resourceType = "mana" },
    { frameName = "TargetFrameHealthBar", unit = "target", resourceType = "health", fallbackName = "цели" },
    { frameName = "TargetFrameManaBar", unit = "target", resourceType = "mana", fallbackName = "цели" },
    { frameName = "FocusFrameHealthBar", unit = "focus", resourceType = "health", fallbackName = "фокуса" },
    { frameName = "FocusFrameManaBar", unit = "focus", resourceType = "mana", fallbackName = "фокуса" },
    { frameName = "PartyMemberFrame1HealthBar", unit = "party1", resourceType = "health" },
    { frameName = "PartyMemberFrame1ManaBar", unit = "party1", resourceType = "mana" },
    { frameName = "PartyMemberFrame2HealthBar", unit = "party2", resourceType = "health" },
    { frameName = "PartyMemberFrame2ManaBar", unit = "party2", resourceType = "mana" },
    { frameName = "PartyMemberFrame3HealthBar", unit = "party3", resourceType = "health" },
    { frameName = "PartyMemberFrame3ManaBar", unit = "party3", resourceType = "mana" },
    { frameName = "PartyMemberFrame4HealthBar", unit = "party4", resourceType = "health" },
    { frameName = "PartyMemberFrame4ManaBar", unit = "party4", resourceType = "mana" },
}

local function ResourceTextForBar(frame)
    if frame and frame.TextString then
        return frame.TextString
    end
    local name = frame and frame.GetName and frame:GetName()
    if type(name) ~= "string" then
        return nil
    end
    if name:find("^TargetFrame", 1) then
        return _G["TargetFrameTextureFrame" .. name:sub(#"TargetFrame" + 1) .. "Text"]
    end
    return _G[name .. "Text"]
end

local function SyncResourceHits()
    local show = AltCD.IsUnitBarActive() and IsAltKeyDown and IsAltKeyDown()
    local hits = S.resourceHits
    if not hits then
        return
    end
    for i = 1, #hits do
        local hit = hits[i]
        local text = hit and hit.text
        local owner = hit and hit.owner
        local ownerShown = owner and owner.IsVisible and owner:IsVisible()
        if not show or not ownerShown or not text then
            if hit and hit:IsShown() then
                hit:Hide()
            end
        else
            local width = text.GetStringWidth and text:GetStringWidth() or 0
            local height = text.GetStringHeight and text:GetStringHeight() or 0
            if not width or width < 8 then
                width = 40
            end
            if not height or height < 8 then
                height = 14
            end
            width, height = width + 18, height + 12
            if hit:GetWidth() ~= width or hit:GetHeight() ~= height then
                hit:SetSize(width, height)
            end
            if not hit:IsShown() then hit:Show() end
        end
    end
end

local function EnsureResourceHitWatcher()
    if S.resourceHitWatcher then
        return
    end
    local watcher = CreateFrame("Frame")
    watcher:SetScript("OnUpdate", SyncResourceHits)
    S.resourceHitWatcher = watcher
end

local function CreateResourceHit(owner, text, unit, resourceType, fallbackName, unitFrame)
    if not owner or not text then
        return nil
    end
    S.resourceHits = S.resourceHits or {}
    S.resourceHitByButton = S.resourceHitByButton or setmetatable({}, { __mode = "k" })
    if S.resourceHitByOwner then
        local existing = S.resourceHitByOwner[owner]
        if existing then
            return existing
        end
    else
        S.resourceHitByOwner = setmetatable({}, { __mode = "k" })
    end

    local hit = CreateFrame("Button", nil, UIParent)
    hit:SetFrameStrata("HIGH")
    hit:SetFrameLevel(100)
    hit:EnableMouse(true)
    hit:RegisterForClicks("LeftButtonUp")
    local plate = hit:CreateTexture(nil, "BACKGROUND")
    plate:SetAllPoints()
    plate:SetTexture("Interface\\Buttons\\WHITE8X8")
    plate:SetAlpha(0)
    hit.text = text
    hit.owner = owner
    hit.unit = unit
    hit.resourceType = resourceType or "health"
    hit.fallbackName = fallbackName
    hit.unitFrame = unitFrame
    hit:SetPoint("CENTER", text, "CENTER", 0, 0)
    hit:SetSize(48, 16)
    hit:Hide()
    hit:SetScript("OnMouseDown", function(_, button)
        if AltCD.IsAltLeftMouseClick(button) then
            S.suppressFocuserForAnnounceBar = true
        end
    end)
    hit:SetScript("OnMouseUp", function(self, button)
        S.suppressFocuserForAnnounceBar = nil
        if not AltCD.IsUnitBarActive() or not AltCD.IsAltLeftMouseClick(button) then
            return
        end
        local pingUnit = self.unit
        local source = self.unitFrame
        if source then
            pingUnit = source.unit or (source.GetAttribute and source:GetAttribute("unit")) or pingUnit
        end
        AltCD.SendUnitResourcePing(pingUnit, self.resourceType, self.fallbackName)
    end)
    S.resourceHitByOwner[owner] = hit
    S.resourceHitByButton[hit] = true
    S.resourceHits[#S.resourceHits + 1] = hit
    EnsureResourceHitWatcher()
    return hit
end

function AltCD.IsAltLeftMouseClick(button)
    return button == "LeftButton" and IsAltKeyDown()
end

function AltCD.GetUnitResourcePercent(unit, resourceType)
    if not unit or not UnitExists(unit) then
        return nil
    end

    local current, maximum
    if resourceType == "health" then
        current = UnitHealth(unit)
        maximum = UnitHealthMax(unit)
    elseif resourceType == "mana" then
        local powerType = UnitPowerType(unit)
        current = UnitPower(unit, powerType)
        maximum = UnitPowerMax(unit, powerType)
    else
        return nil
    end

    if not maximum or maximum <= 0 then
        return nil
    end

    return (current / maximum) * 100, current
end

function AltCD.BuildUnitResourceMessage(unit, resourceType, fallbackName, percent, current)
    local percentText = string.format("%.1f%%", percent)

    if unit == "player" then
        if resourceType == "health" then
            if percent < 30 then
                return "Мне нужна помощь, здоровья: " .. percentText
            end
            return "У меня здоровья: " .. percentText
        end
        if resourceType == "mana" then
            local powerType = UnitPowerType(unit)
            local powerName = AltCD.POWER_NAMES_RU[powerType] or "ресурса"
            local depletedName = AltCD.POWER_DEPLETED_RU[powerType] or "мана"
            if current <= 0 or percent <= 0 then
                return "У меня закончилась " .. depletedName
            end
            if percent < 20 then
                return "У меня почти нет " .. powerName .. ": " .. percentText
            end
            return "У меня " .. powerName .. ": " .. percentText
        end
        return nil
    end

    local unitName = UnitName(unit)
    local label = unitName or fallbackName
    if not label then
        return nil
    end

    if resourceType == "health" then
        return "У " .. label .. " здоровья: " .. percentText
    end
    if resourceType == "mana" then
        local powerType = UnitPowerType(unit)
        local powerName = AltCD.POWER_NAMES_RU[powerType] or "ресурса"
        return "У " .. label .. " " .. powerName .. ": " .. percentText
    end
    return nil
end

function AltCD.SendUnitResourcePing(unit, resourceType, fallbackName)
    local percent, current = AltCD.GetUnitResourcePercent(unit, resourceType)
    if not percent then
        return
    end

    local message = AltCD.BuildUnitResourceMessage(unit, resourceType, fallbackName, percent, current)
    if not message or message == "" then
        return
    end

    SendChatMessage(message, AltCD.GetChatChannel())
end

function AltCD.OnUnitBarMouseUp(frame, unit, resourceType, fallbackName, button)
    if not AltCD.IsUnitBarActive() then
        return
    end
    if not AltCD.IsAltLeftMouseClick(button) then
        return
    end
    local text = ResourceTextForBar(frame)
    if not text or not IsCursorOverFrame(text) then
        return
    end
    AltCD.SendUnitResourcePing(unit, resourceType, fallbackName)
end

function AltCD.HookUnitBarPing(frameName, unit, resourceType, fallbackName)
    local frame = frameName and _G[frameName]
    S.unitBarHooked = S.unitBarHooked or setmetatable({}, { __mode = "k" })
    if not frame or S.unitBarHooked[frame] then
        return false
    end

    -- Announce only when the cursor is on the resource number. The bar click itself focuses.
    frame:HookScript("OnMouseDown", function(self, button)
        if not AltCD.IsAltLeftMouseClick(button) then
            return
        end
        local text = ResourceTextForBar(self)
        if text and IsCursorOverFrame(text) then
            S.suppressFocuserForAnnounceBar = true
        end
    end)

    frame:HookScript("OnMouseUp", function(self, button)
        S.suppressFocuserForAnnounceBar = nil
        local text = ResourceTextForBar(self)
        local overText = text and IsCursorOverFrame(text)
        if overText then
            AltCD.OnUnitBarMouseUp(frame, unit, resourceType, fallbackName, button)
        end
        if overText and AltCD.IsUnitBarActive() and AltCD.IsAltLeftMouseClick(button) then
            return
        end
    end)
    S.unitBarHooked[frame] = true
    CreateResourceHit(frame, ResourceTextForBar(frame), unit, resourceType, fallbackName)
    return true
end

local function QueueCompactAttrRestore(frame, attr, value)
    S.compactRestore = S.compactRestore or setmetatable({}, { __mode = "k" })
    S.compactRestore[frame] = { attr, value }
    if not S.compactRestoreFrame then
        local watcher = CreateFrame("Frame")
        watcher:Hide()
        watcher:SetScript("OnUpdate", function(self)
            if IsMouseButtonDown and IsMouseButtonDown("LeftButton") then
                return
            end
            if InCombatLockdown and InCombatLockdown() then
                return
            end
            for unitFrame, saved in pairs(S.compactRestore) do
                if unitFrame and unitFrame.SetAttribute then
                    unitFrame:SetAttribute(saved[1], saved[2])
                end
                S.compactRestore[unitFrame] = nil
            end
            self:Hide()
        end)
        S.compactRestoreFrame = watcher
    end
    S.compactRestoreFrame:Show()
end

InstallCompactResourceAnnounce = function(frame)
    local name = frame and frame.GetName and frame:GetName()
    if type(name) ~= "string" then
        return
    end
    if name:match("^CompactRaidFrame%d+$") then
        return
    end
    if not name:match("^CompactPartyFrameMember%d+$") then
        return
    end
    S.compactAnnounce = S.compactAnnounce or setmetatable({}, { __mode = "k" })
    if S.compactAnnounce[frame] or not frame.HookScript then
        return
    end
    S.compactAnnounce[frame] = true
    local text = frame.statusText or (frame.overlay and frame.overlay.statusText)
    if text then
        CreateResourceHit(frame, text, frame.unit or (frame.GetAttribute and frame:GetAttribute("unit")), "health", nil, frame)
    end

    local function statusText(self)
        return self.statusText or (self.overlay and self.overlay.statusText)
    end

    frame:HookScript("OnMouseDown", function(self, button)
        if not AltCD.IsAltLeftMouseClick(button) then
            return
        end
        local text = statusText(self)
        if not text or not IsCursorOverFrame(text) then
            return
        end
        S.suppressFocuserForAnnounceBar = true
        if not ShouldSuppressFocusOnAnnounceBars() then
            return
        end
        if InCombatLockdown and InCombatLockdown() then
            return
        end
        local attr = GetFocuserModifier():lower() .. "-type" .. mouseButton
        QueueCompactAttrRestore(self, attr, self:GetAttribute(attr))
        self:SetAttribute(attr, nil)
    end)

    frame:HookScript("OnMouseUp", function(self, button)
        S.suppressFocuserForAnnounceBar = nil
        if not AltCD.IsUnitBarActive() or not AltCD.IsAltLeftMouseClick(button) then
            return
        end
        local text = statusText(self)
        if not text or not IsCursorOverFrame(text) then
            return
        end
        local unit = self.unit or (self.GetAttribute and self:GetAttribute("unit"))
        AltCD.SendUnitResourcePing(unit, "health", nil)
    end)
end

function AltCD.InitUnitBarPings()
    for i = 1, #AltCD.UNIT_BAR_HOOKS do
        local hook = AltCD.UNIT_BAR_HOOKS[i]
        AltCD.HookUnitBarPing(hook.frameName, hook.unit, hook.resourceType, hook.fallbackName)
    end
end

AltCD.AURA_STATIC_GROUPS = {
    { prefix = "BuffButton", count = 32, unit = "player", auraType = "buff" },
    { prefix = "DebuffButton", count = 16, unit = "player", auraType = "debuff" },
}

AltCD.AURA_FRAME_GROUPS = {
    { frameName = "TargetFrame", unit = "target", fallbackName = "цели", buffCount = 32, debuffCount = 16 },
    { frameName = "FocusFrame", unit = "focus", fallbackName = "фокусе", buffCount = 32, debuffCount = 16 },
}

function AltCD.FormatAuraTime(seconds)
    seconds = tonumber(seconds) or 0

    if seconds <= 0 then
        return "без времени"
    end

    seconds = math.floor(seconds + 0.5)

    if seconds < 60 then
        return seconds .. " сек."
    end

    local minutes = math.floor(seconds / 60)
    if minutes < 60 then
        return minutes .. " мин."
    end

    local hours = math.floor(minutes / 60)
    local restMinutes = minutes % 60

    if restMinutes > 0 then
        return hours .. " ч. " .. restMinutes .. " мин."
    end
    return hours .. " ч."
end

function AltCD.GetAuraInfo(unit, auraType, index)
    if not unit or not UnitExists(unit) then
        return nil
    end

    local name, rank, icon, count, debuffType, duration, expirationTime, caster
    local spellID

    if auraType == "buff" then
        name, rank, icon, count, debuffType, duration, expirationTime, caster, _, _, spellID = UnitBuff(unit, index)
    elseif auraType == "debuff" then
        name, rank, icon, count, debuffType, duration, expirationTime, caster, _, _, spellID = UnitDebuff(unit, index)
    else
        return nil
    end

    if not name or name == "" then
        return nil
    end

    local displayLink = name
    if type(spellID) == "number" and spellID > 0 and GetSpellLink then
        local link = GetSpellLink(spellID)
        if link and link ~= "" then
            displayLink = link
        end
    elseif GetSpellLink then
        local link = GetSpellLink(name)
        if link and link ~= "" then
            displayLink = link
        end
    end

    local remaining = 0
    if expirationTime and expirationTime > 0 then
        remaining = expirationTime - GetTime()
        if remaining < 0 then
            remaining = 0
        end
    end

    return {
        displayLink = displayLink,
        count = count,
        remaining = remaining,
    }
end

function AltCD.BuildAuraTimeSuffix(remaining)
    if remaining and remaining > 0 then
        return " - осталось " .. AltCD.FormatAuraTime(remaining)
    end
    return " - без времени"
end

function AltCD.BuildAuraStackSuffix(count)
    if type(count) == "number" and count >= 2 then
        return " x" .. count
    end
    return ""
end

function AltCD.BuildAuraMessage(unit, auraType, auraInfo, fallbackName)
    if not auraInfo or not auraInfo.displayLink or auraInfo.displayLink == "" then
        return nil
    end

    local spellPart = auraInfo.displayLink .. AltCD.BuildAuraStackSuffix(auraInfo.count)
    local timeSuffix = AltCD.BuildAuraTimeSuffix(auraInfo.remaining)
    local kind = (auraType == "buff") and "баф" or "дебаф"

    if unit == "player" then
        return "На мне " .. kind .. ": " .. spellPart .. timeSuffix
    end

    local unitName = UnitName(unit)
    local label = unitName or fallbackName
    if not label or label == "" then
        return nil
    end

    return "На " .. label .. " " .. kind .. ": " .. spellPart .. timeSuffix
end

function AltCD.SendAuraPing(unit, auraType, index, fallbackName)
    local auraInfo = AltCD.GetAuraInfo(unit, auraType, index)
    if not auraInfo then
        return
    end

    local message = AltCD.BuildAuraMessage(unit, auraType, auraInfo, fallbackName)
    if not message or message == "" then
        return
    end

    SendChatMessage(message, AltCD.GetChatChannel())
end

function AltCD.OnAuraButtonMouseUp(frame, unit, auraType, index, fallbackName, button)
    if not AltCD.IsAuraActive() then
        return
    end
    if not AltCD.IsAltLeftMouseClick(button) then
        return
    end

    local auraIndex = index
    if frame and frame.GetID then
        local id = frame:GetID()
        if type(id) == "number" and id > 0 then
            auraIndex = id
        end
    end

    AltCD.SendAuraPing(unit, auraType, auraIndex, fallbackName)
end

function AltCD.HookAuraButton(frameName, unit, auraType, index, fallbackName)
    local frame = frameName and _G[frameName]
    if not frame or frame.__SarychUIAltCDAuraHooked then
        return false
    end

    if frame.EnableMouse then
        frame:EnableMouse(true)
    end

    frame:HookScript("OnMouseUp", function(_, button)
        AltCD.OnAuraButtonMouseUp(frame, unit, auraType, index, fallbackName, button)
    end)
    frame.__SarychUIAltCDAuraHooked = true
    return true
end

function AltCD.HookAuraButtonRange(prefix, unit, auraType, count, fallbackName)
    if not prefix or not count then
        return
    end
    for i = 1, count do
        AltCD.HookAuraButton(prefix .. i, unit, auraType, i, fallbackName)
    end
end

function AltCD.HookFrameAuraButtons(parentFrame, unit, fallbackName, buffCount, debuffCount)
    if not parentFrame or not parentFrame.GetName then
        return
    end
    local baseName = parentFrame:GetName()
    if not baseName then
        return
    end
    AltCD.HookAuraButtonRange(baseName .. "Buff", unit, "buff", buffCount, fallbackName)
    AltCD.HookAuraButtonRange(baseName .. "Debuff", unit, "debuff", debuffCount, fallbackName)
end

function AltCD.InitAuraPings()
    for i = 1, #AltCD.AURA_STATIC_GROUPS do
        local group = AltCD.AURA_STATIC_GROUPS[i]
        AltCD.HookAuraButtonRange(group.prefix, group.unit, group.auraType, group.count, nil)
    end

    for i = 1, #AltCD.AURA_FRAME_GROUPS do
        local group = AltCD.AURA_FRAME_GROUPS[i]
        local parentFrame = group.frameName and _G[group.frameName]
        if parentFrame then
            AltCD.HookFrameAuraButtons(
                parentFrame,
                group.unit,
                group.fallbackName,
                group.buffCount,
                group.debuffCount
            )
        end
    end
end

function AltCD.InstallAuraUpdateHooks()
	if S.altCdAuraUpdateHooked or not hooksecurefunc then
		return
	end

	if type(FocusFrame_UpdateAuras) == "function" then
		hooksecurefunc("FocusFrame_UpdateAuras", function(self)
			AltCD.HookFrameAuraButtons(self, "focus", "фокусе", 32, 16)
        end)
    end

    if type(BuffFrame_Update) == "function" then
        hooksecurefunc("BuffFrame_Update", function()
            AltCD.HookAuraButtonRange("BuffButton", "player", "buff", 32, nil)
            AltCD.HookAuraButtonRange("DebuffButton", "player", "debuff", 16, nil)
        end)
    end

    S.altCdAuraUpdateHooked = true
end

function AltCD.EnsureUnitBarPingEventFrame()
    if S.altCdUnitBarEventFrame then
        return
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function()
        AltCD.InitUnitBarPings()
        AltCD.InitAuraPings()
    end)
    S.altCdUnitBarEventFrame = frame
end

function AltCD.InstallAuraHooks()
    AltCD.EnsureUnitBarPingEventFrame()
    AltCD.InstallAuraUpdateHooks()
    AltCD.InitAuraPings()
end

function AltCD.InstallUnitBarHooks()
    AltCD.EnsureUnitBarPingEventFrame()
    AltCD.InitUnitBarPings()
end

function AltCD.InstallHooks()
    if S.altCdHooksInstalled then
        return
    end

    AltCD.HookAllActionButtons()

    if type(ActionButton_OnLoad) == "function" and hooksecurefunc then
        hooksecurefunc("ActionButton_OnLoad", AltCD.OnActionButtonLoad)
    end

    S.altCdHooksInstalled = true
end

function AltCD.RemoveHooks()
    AltCD.SetOverlaysEnabled(false)
end

function SarychUI.modules.announcements:ApplyAltCD()
    local db = DB()
    if not db or not SarychUI:IsAnnouncementsEnabled() then
        if S.altCdEnabled then
            SarychUI.modules.announcements:DisableAltCD()
        end
        return
    end

    if db.enableAltCD == 1 then
        SarychUI.modules.announcements:EnableAltCD()
    elseif S.altCdEnabled then
        SarychUI.modules.announcements:DisableAltCD()
    end
end

function SarychUI.modules.announcements:EnableAltCD()
    local db = DB()
    if not db or not SarychUI:IsAnnouncementsEnabled() then
        return
    end

    AltCD.InstallHooks()
    S.altCdEnabled = true
    AltCD.SetOverlaysEnabled(true)
end

function SarychUI.modules.announcements:DisableAltCD()
    S.altCdEnabled = false
    AltCD.SetOverlaysEnabled(false)
    -- Keep S.altCdHooksInstalled so ActionButton_OnLoad is not hooked again on re-enable.
end

function SarychUI.modules.announcements:ApplyAltUnitBars()
    local db = DB()
    if not db or not SarychUI:IsAnnouncementsEnabled() then
        return
    end
    if db.enableAltUnitBars ~= 1 then
        if db.enableFocuser == 1 then
            SarychUI.modules.focus_assignment:ApplyFocuser()
        end
        return
    end

    -- FrameXML Click guard before announce hooks (SetScript, then HookScript).
    InstallPlayerBarFrameXMLClickGuard()
    AltCD.InstallUnitBarHooks()
    if db.enableFocuser == 1 then
        SarychUI.modules.focus_assignment:ApplyFocuser()
    end
end

function SarychUI.modules.announcements:ApplyAltAuras()
    local db = DB()
    if not db or not SarychUI:IsAnnouncementsEnabled() then
        return
    end
    if db.enableAltAuras ~= 1 then
        return
    end

    AltCD.InstallAuraHooks()
end

function SarychUI.modules.focus_assignment:StartFocusScanner()
    -- Create scanner frame for group updates
    if not S.scannerFrame then
        S.scannerFrame = CreateFrame("Frame")
        S.scannerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        S.scannerFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
        S.scannerFrame:RegisterEvent("RAID_ROSTER_UPDATE")
        S.scannerFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
        S.scannerFrame:SetScript("OnEvent", function()
            -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
            local checkDb = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
            if not checkDb or not SarychUI:IsFocusAssignmentEnabled() then return end

            pcall(UpdateCompactParty)
        end)

        -- Periodic scanning for raid groups (via SarychUI.UpdateScheduler dispatcher)
        local function ToolsScannerTick()
            local checkDb = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
            if not checkDb or not SarychUI:IsFocusAssignmentEnabled() then return end
            pcall(UpdateCompactParty)
        end
        if SarychUI and SarychUI.UpdateScheduler and SarychUI.UpdateScheduler.RegisterUpdate then
            SarychUI.UpdateScheduler:RegisterUpdate("tools.scanner", 2.0, ToolsScannerTick)
            S.scannerUsesScheduler = true
        else
            local scanTimer = 0
            S.scannerFrame:SetScript("OnUpdate", function(self, elapsed)
                local checkDb = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
                if not checkDb or not SarychUI:IsFocusAssignmentEnabled() then return end
                scanTimer = scanTimer + elapsed
                if scanTimer >= 2.0 then
                    scanTimer = 0
                    pcall(UpdateCompactParty)
                end
            end)
            S.scannerUsesScheduler = false

        end
    end

    UpdateCompactParty()
end

function SarychUI.modules.focus_assignment:StopFocusScanner()
    -- Unregister scanner events
    if S.scannerFrame then
        S.scannerFrame:UnregisterAllEvents()
        S.scannerFrame:SetScript("OnEvent", nil)
        S.scannerFrame:SetScript("OnUpdate", nil)
    end
    if S.scannerUsesScheduler and SarychUI and SarychUI.UpdateScheduler and SarychUI.UpdateScheduler.UnregisterUpdate then
        SarychUI.UpdateScheduler:UnregisterUpdate("tools.scanner")
        S.scannerUsesScheduler = false
    end

    S.scannerFrame = nil
end
