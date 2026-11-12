local module = SarychUI.modules.arena
local timers = { frames = {}, totems = {}, eyes = {}, pickups = {} }
module.ArenaTimers = timers
local NATIVE_BAR_HEIGHT, NATIVE_ICON_SIZE, NATIVE_BAR_GAP = 14, 16, 4
local NATIVE_ICON_GAP = 5 -- ArenaCastingBarFrameTemplate
local tickTextOptions = { periodic = true, compactUnits = true, decimalThreshold = 3 }
local definitions = {
    tremor = { title = "ui.arena.timer_tremor", x = 320, y = -156, scale = 1.1, icon = "Spell_Nature_TremorTotem" },
    eyes = { title = "ui.arena.timer_eyes", x = 416, y = -174, scale = 1, icon = "Spell_Shadow_EvilEye" },
}
local function DB()
    local db = SarychUI.db.profile.modules.arena
    db.timers = db.timers or {}
    for key, def in pairs(definitions) do
        local cfg = db.timers[key] or {}
        db.timers[key] = cfg
        if cfg.enabled == nil then cfg.enabled = true end
        cfg.scale = cfg.scale or def.scale
        if key == "eyes" then
            if cfg.display ~= "bars" and cfg.display ~= "icons" then cfg.display = "bars" end
            cfg.barHeight = math.max(12, math.min(64, tonumber(cfg.barHeight) or 24))
            cfg.barWidth = math.max(80, math.min(400, tonumber(cfg.barWidth) or 139))
            cfg.barSpacing = math.max(0, math.min(20, tonumber(cfg.barSpacing) or 4))
        end
        cfg.point = cfg.point or "LEFT"
        cfg.relativePoint = cfg.relativePoint or "CENTER"
        cfg.x = cfg.x or def.x
        cfg.y = cfg.y or def.y
    end
    return db.timers, db
end
local function InArena()
    local _, kind = IsInInstance()
    return kind == "arena"
end
local function FrameID(key) return "arenaTimer_" .. key end
local function CloseMover(key)
    local drag = SarychUI.DragMode
    if drag and drag:IsPositionEditorOpen(FrameID(key)) then
        SarychUI.PositionDragPanel:Close(false)
    end
end
function timers:ClearMatch()
    self.totems, self.eyes, self.pickups = {}, {}, {}
    self.eyeDurations = {}
    self.started = nil
end
function timers:StartMatch()
    if not InArena() or self.started then return end
    self.started = true
    self.eyes = { GetTime() + 91, GetTime() + 91 }
    self.eyeDurations = {91, 91}
end
function timers:CombatEvent(event, source, sourceName, flags, dest, spell)
    if not InArena() then return end
    local now = GetTime()
    -- A replacement earth totem or Totemic Recall removes the old Tremor
    -- even on servers which do not emit UNIT_DESTROYED for replacements.
    local replacesEarth = false
    if event == "SPELL_SUMMON" and spell and GetSpellInfo then
        local name = GetSpellInfo(spell)
        for _, base in ipairs({2484, 5730, 8071, 8075}) do
            if name and name == GetSpellInfo(base) then replacesEarth = true; break end
        end
    end
    if replacesEarth or (event == "SPELL_CAST_SUCCESS" and spell == 36936) then
        for guid, totem in pairs(self.totems) do
            if totem.owner == source then self.totems[guid] = nil end
        end
    end
    if event == "SPELL_SUMMON" and spell == 8143 and dest
        and flags and bit.band(flags, COMBATLOG_OBJECT_REACTION_HOSTILE or 64) ~= 0 then
        for guid, totem in pairs(self.totems) do
            if totem.owner == source then self.totems[guid] = nil end
        end
        self.totems[dest] = { owner = source, name = sourceName, start = now, expires = now + 300 }
    elseif event == "UNIT_DIED" or event == "UNIT_DESTROYED" then
        if dest then self.totems[dest] = nil end
        for guid, totem in pairs(self.totems) do
            if totem.owner == dest then self.totems[guid] = nil end
        end
    elseif event == "SPELL_AURA_APPLIED" and spell == 34709 and dest then
        -- Each pickup restarts one of the two crystals. Ignore duplicate delivery.
        if self.pickups[dest] and now - self.pickups[dest] < 2 then return end
        self.pickups[dest] = now
        local index = (self.eyes[1] or 0) <= (self.eyes[2] or 0) and 1 or 2
        self.eyes[index] = now + 120
        self.eyeDurations = self.eyeDurations or {}
        self.eyeDurations[index] = 120
    end
end
local starts = {
    "The Arena battle has begun!", "Бой начался!", "¡La batalla en arena ha comenzado!",
    "Der Arenakampf hat begonnen!", "Le combat d'arène commence",
    "A batalha na Arena começou!", "竞技场的战斗开始了", "競技場戰鬥開始了", "투기장 전투가 시작되었습니다",
}
function timers:Event(event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        self:ClearMatch()
        if InArena() then
            self.testing = false
            -- Closing a position editor may invoke onApply/Refresh. Do the
            -- transition once, then refresh after both editors are closed.
            self.stopping = true
            for key in pairs(definitions) do CloseMover(key) end
            self.stopping = nil
        end
        self:Refresh()
    elseif event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" or event == "CHAT_MSG_RAID_BOSS_EMOTE" then
        local text = ...
        if InArena() and type(text) == "string" then
            for _, start in ipairs(starts) do
                if text:find(start, 1, true) then self:StartMatch(); break end
            end
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        -- Wrath 3.3.5 combat-log argument layout.
        local _, subevent, source, name, flags, dest, _, _, spell = ...
        self:CombatEvent(subevent, source, name, flags, dest, spell)
    end
    self:Update()
end
local function EnsureIcon(frame, key, index)
    local row = frame.icons[index]
    if row then return row end
    local tremor = key == "tremor"
    local size = tremor and 36 or 24
    row = CreateFrame("Frame", nil, frame)
    row:SetSize(tremor and 36 or 80, tremor and 36 or 24)
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", tremor and (index - 1) * 40 or 0,
        tremor and 0 or -(index - 1) * 28)
    row.icon = row:CreateTexture(nil, "BACKGROUND")
    row.icon:SetSize(size, size)
    row.icon:SetPoint("TOPLEFT")
    row.icon:SetTexture("Interface\\Icons\\" .. definitions[key].icon)
    row.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    row.__sary_partyAbility = true -- same tracked-ability text policy as Aesa/OmniBar
    if tremor then
        row.shade = row:CreateTexture(nil, "ARTWORK")
        row.shade:SetTexture(0, 0, 0, 0.7)
        row.shade:SetPoint("TOPLEFT", row.icon, "TOPLEFT")
        row.edge = row:CreateTexture(nil, "OVERLAY")
        row.edge:SetTexture(1, 1, 1, 0.65)
        row.edge:SetSize(36, 1)
        row.edge:SetPoint("TOPLEFT", row.shade, "BOTTOMLEFT")
    else
        row.cooldown = CreateFrame("Cooldown", nil, row, "CooldownFrameTemplate")
        row.cooldown:SetAllPoints(row.icon)
        row.cooldown:SetReverse(false)
        row.cooldown:SetDrawEdge(true)
        row.cooldown.noCooldownCount = true
        row.cooldown.noOCC = true
    end
    row.overlay = CreateFrame("Frame", nil, row)
    row.overlay:SetAllPoints(row)
    row.overlay:SetFrameLevel((row.cooldown or row):GetFrameLevel() + 2)
    -- Native arena castbar text style, shared with the Shadow Sight bars.
    row.text = row.overlay:CreateFontString(nil, "OVERLAY", tremor and "GameFontHighlightSmall" or "GameFontHighlight")
    row.text:SetJustifyH(tremor and "CENTER" or "RIGHT")
    if tremor then
        row.procBorder = row.overlay:CreateTexture(nil, "OVERLAY")
        row.procBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        row.procBorder:SetBlendMode("ADD")
        row.procBorder:SetPoint("CENTER", row.icon, "CENTER")
        row.procBorder:SetSize(36 * 48 / 26, 36 * 48 / 26)
        row.procBorder:SetVertexColor(1, 0.82, 0.28)
    end
    if not tremor then
        row.bar = CreateFrame("StatusBar", nil, row)
        row.bar:SetSize(200, 24)
        row.bar:SetPoint("LEFT", row.icon, "RIGHT", 0, 0)
        row.bar:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
        -- CastingBarFrameTemplate / CastingBarFrame.lua defaults.
        row.bar:SetStatusBarColor(1, 0.7, 0)
        row.barBackground = row.bar:CreateTexture(nil, "BACKGROUND")
        row.barBackground:SetAllPoints(row.bar)
        row.barBackground:SetTexture(0, 0, 0, 0.5)
        row.bar:SetFrameLevel(row:GetFrameLevel() + 1)
        row.overlay:SetFrameLevel(row.bar:GetFrameLevel() + 2)
        row.bar:Hide()
        row.label = row.overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.label:SetPoint("LEFT", row.bar, "LEFT", 3, 0)
        row.label:SetWidth(138)
        row.label:SetJustifyH("LEFT")
        row.label:SetWordWrap(false)
        row.label:SetText(GetSpellInfo(34709) or SarychUI:T("ui.arena.timer_eyes"))
        row.label:SetHeight(24)
        row.labelMeasure = row.overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.labelMeasure:Hide()
        row.labelFit = { text = row.label, labelMeasure = row.labelMeasure }
        row.label:Hide()
        row.spark = row.bar:CreateTexture(nil, "OVERLAY")
        row.spark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
        row.spark:SetBlendMode("ADD")
        row.spark:SetSize(24, 46)
    end
    frame.icons[index] = row
    return row
end
local function DrawIcon(frame, key, index, start, duration, now)
    local row = EnsureIcon(frame, key, index)
    local left = math.max(0, start + duration - now)
    local cfg = DB().eyes
    local bars = key == "eyes" and cfg.display == "bars"
    local size = key == "tremor" and 36 or (bars and NATIVE_BAR_HEIGHT or 24)
    local iconSize = bars and NATIVE_ICON_SIZE or size
    row.icon:SetSize(iconSize, iconSize)
    row:SetHeight(iconSize)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", key == "tremor" and (index - 1) * 40 or 0,
        key == "tremor" and 0 or -(index - 1) * (iconSize + (bars and NATIVE_BAR_GAP or 4)))
    row.text:ClearAllPoints()
    if bars then
        row:SetWidth(cfg.barWidth + iconSize + NATIVE_ICON_GAP)
        row.bar:ClearAllPoints()
        row.bar:SetPoint("LEFT", row.icon, "RIGHT", NATIVE_ICON_GAP, 0)
        row.icon:SetTexCoord(0, 1, 0, 1)
        row.label:ClearAllPoints()
        row.label:SetPoint("TOPLEFT", row.bar, "TOPLEFT", 3, 2)
        row.label:SetJustifyH("LEFT")
        row.bar:SetSize(cfg.barWidth, size)
        row.spark:SetSize(32, 32)
        row.text:SetPoint("TOPRIGHT", row.bar, "TOPRIGHT", -2, 2)
        row.text:SetHeight(16)
        row.bar:SetMinMaxValues(0, duration)
        row.bar:SetValue(left)
        row.spark:ClearAllPoints()
        row.spark:SetPoint("CENTER", row.bar, "LEFT", cfg.barWidth * math.min(1, left / duration), 0)
        if left > 0 then row.spark:Show() else row.spark:Hide() end
        row.bar:Show()
        row.label:Show()
    else
        row:SetWidth(key == "tremor" and 36 or 80)
        row.text:SetPoint(key == "tremor" and "BOTTOM" or "LEFT", row.icon,
            key == "tremor" and "TOP" or "RIGHT", 0, key == "tremor" and 3 or 0)
        row.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        row.text:SetHeight(0)
        if row.bar then row.bar:Hide(); row.label:Hide() end
    end
    if key == "tremor" then
        -- Reveal the icon from bottom to top during each three-second tick.
        row.shade:SetSize(size, math.max(0.001, size * math.min(1, left / duration)))
        -- Same glow/range as arena proc trinkets, but one pulse per tick.
        -- At the wrap both sides meet at alpha=1: no independent pulse clock.
        row.procBorder:SetAlpha(0.65 + 0.35 * math.cos((now - start) / duration * 2 * math.pi))
    elseif row.start ~= start or row.duration ~= duration then
        CooldownFrame_SetTimer(row.cooldown, start, duration, 1)
        row.start, row.duration = start, duration
    end
    if row.cooldown and left <= 0 then row.cooldown:Hide() end
    local cc = SarychUI.modules.cc
    row.text:SetFontObject((key == "tremor" or bars) and GameFontHighlightSmall or GameFontHighlight)
    if cc and cc.UpdateTimerText then
        cc:UpdateTimerText(row.text, left, duration, row, true, key == "tremor" and tickTextOptions or nil)
    else row.text:Hide() end
    if bars then
        -- Measure after CC has formatted/hidden this frame's current value.
        -- Reserve only the actual timer width plus a small gap and edge insets.
        local timerWidth = row.text:IsShown() and row.text:GetStringWidth() or 0
        local labelWidth = math.max(1, cfg.barWidth - 3 - 2 - timerWidth - (timerWidth > 0 and 4 or 0))
        row.label:SetWidth(labelWidth)
        row.label:SetHeight(16)
        local tracker = SarychUI.extensions and SarychUI.extensions.party_abilities
        local views = tracker and tracker.Standalone
        if views then
            views:FitBarLabel(row.labelFit, GetSpellInfo(34709) or SarychUI:T("ui.arena.timer_eyes"), labelWidth)
        end
    end
    row:Show()
end
function timers:Update()
    local cfg, db = DB()
    local now = GetTime()
    for key, frame in pairs(self.frames) do
        local count = 0
        local moving = SarychUI.DragMode and SarychUI.DragMode:IsPositionEditorOpen(FrameID(key))
        if db.enabled and cfg[key].enabled then
            if (self.testing or moving) and not InArena() then
                if key == "tremor" then
                    DrawIcon(frame, key, 1, now - now % 3, 3, now)
                    count = 1
                else
                    DrawIcon(frame, key, 1, now - now % 30, 30, now)
                    DrawIcon(frame, key, 2, now - now % 45, 45, now)
                    count = 2
                end
            elseif InArena() then
                if key == "tremor" then
                    local guids = {}
                    for guid, totem in pairs(self.totems) do
                        if now >= totem.expires then self.totems[guid] = nil
                        else guids[#guids + 1] = guid end
                    end
                    table.sort(guids)
                    for _, guid in ipairs(guids) do
                        local totem = self.totems[guid]
                        count = count + 1
                        local start = totem.start + math.floor((now - totem.start) / 3) * 3
                        DrawIcon(frame, key, count, start, 3, now)
                    end
                elseif self.eyes[1] or self.eyes[2] then
                    for i = 1, 2 do
                        local finish = self.eyes[i] or now
                        local duration = self.eyeDurations and self.eyeDurations[i] or 91
                        DrawIcon(frame, key, i, finish - duration, duration, now)
                    end
                    count = 2
                end
            end
        end
        for i, row in ipairs(frame.icons) do if i > count then row:Hide() end end
        if count > 0 then
            frame:SetSize(key == "tremor" and count * 40 - 4 or (cfg.eyes.display == "bars" and cfg.eyes.barWidth + NATIVE_ICON_SIZE + NATIVE_ICON_GAP or 80),
                key == "tremor" and 36 or (cfg.eyes.display == "bars" and 2 * NATIVE_ICON_SIZE + NATIVE_BAR_GAP or 52))
            frame:Show()
        else frame:Hide() end
    end
end
function timers:EnsureFrame(key)
    local frame = self.frames[key]
    if frame then return frame end
    frame = CreateFrame("Frame", "SarychUIArenaTimer_" .. key, UIParent)
    frame:SetSize(key == "tremor" and 36 or 80, key == "tremor" and 36 or 52)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame.icons = {}
    self.frames[key] = frame
    return frame
end
function timers:Refresh()
    if self.stopping then return end
    local cfg, db = DB()
    if not db.enabled then self:Disable(); return end
    local active = cfg.tremor.enabled or cfg.eyes.enabled
    if not active then self.testing = false end
    for key, def in pairs(definitions) do
        if cfg[key].enabled then
            local frame = self:EnsureFrame(key)
            local scale = key == "eyes" and cfg[key].display == "bars" and 1 or cfg[key].scale
            frame:SetScale(scale)
            local drag = SarychUI.DragMode
            if drag and SarychUI.PositionDragPanel then
                drag:RegisterPositionEditor(FrameID(key), frame, {
                    title = def.title, getConfig = function() return DB()[key] end,
                    defaultX = def.x, defaultY = def.y, defaultA = "LEFT", defaultR = "CENTER",
                    onApply = function() timers:Refresh() end,
                }, { dragPoint = "LEFT" })
                drag:SetFrameScale(FrameID(key), scale)
            end
            if not drag or not drag:IsPositionEditorOpen(FrameID(key)) then
                frame:ClearAllPoints()
                frame:SetPoint(cfg[key].point, UIParent, cfg[key].relativePoint, cfg[key].x, cfg[key].y)
            end
        else
            CloseMover(key)
            if self.frames[key] then self.frames[key]:Hide() end
            if SarychUI.DragMode then SarychUI.DragMode:UnregisterFrame(FrameID(key)) end
        end
    end
    if not self.watcher then
        self.watcher = CreateFrame("Frame")
        self.watcher:SetScript("OnEvent", function(_, event, ...) timers:Event(event, ...) end)
        local elapsedTotal = 0
        self.watcher:SetScript("OnUpdate", function(_, elapsed)
            elapsedTotal = elapsedTotal + elapsed
            if elapsedTotal >= 0.05 then elapsedTotal = 0; timers:Update() end
        end)
    end
    self.watcher:UnregisterAllEvents()
    if active then
        for _, event in ipairs({"PLAYER_ENTERING_WORLD", "COMBAT_LOG_EVENT_UNFILTERED",
            "CHAT_MSG_BG_SYSTEM_NEUTRAL", "CHAT_MSG_RAID_BOSS_EMOTE"}) do self.watcher:RegisterEvent(event) end
        self.watcher:Show()
    else self.watcher:Hide(); self:ClearMatch() end
    self:Update()
end
function timers:Disable()
    self.stopping = true
    self.testing = false
    if self.watcher then self.watcher:UnregisterAllEvents(); self.watcher:Hide() end
    for key, frame in pairs(self.frames) do
        CloseMover(key)
        if SarychUI.DragMode then SarychUI.DragMode:UnregisterFrame(FrameID(key)) end
        frame:Hide()
    end
    self:ClearMatch()
    self.stopping = nil
end
function timers:SetCoordinate(key, axis, value)
    local cfg = DB()[key]
    cfg[axis] = value
    local panel = SarychUI.PositionDragPanel
    if panel and panel:SyncDraftIfOpen(FrameID(key), cfg.x, cfg.y, cfg.point, cfg.relativePoint) then return end
    self:Refresh()
end
function timers:GetOptions()
    local function Notify()
        timers:Refresh()
        SarychUI:NotifySarychUIOptionsChange()
    end
    local test = { type = "execute",
        name = function() return SarychUI:T(timers.testing and "ui.options_2aa205e3d3" or "ui.options_ec1868c5a7") end,
        disabled = function() local cfg = DB(); return InArena() or (not cfg.tremor.enabled and not cfg.eyes.enabled) end,
        func = function() if InArena() then return end; timers.testing = not timers.testing; Notify() end }
    local args = {}
    for index, key in ipairs({"tremor", "eyes"}) do
        local def = definitions[key]
        args[key] = { type = "group", name = def.title, inline = true, order = index, args = {
            enabled = { type = "toggle", name = "ui.enable_a54eaf37", order = 1,
                get = function() return DB()[key].enabled end,
                set = function(_, value) DB()[key].enabled = value; Notify() end },
                    display = key == "eyes" and { type = "select", name = "ui.display_205c4b9e",
                        order = 1.5, width = "full", suiFullRow = true,
                        hidden = function() return not DB().eyes.enabled end,
                        values = { icons = "ui.arena.timer_icons", bars = "ui.arena.timer_bars", __order = {"icons", "bars"} },
                        get = function() return DB().eyes.display end,
                        set = function(_, value)
                            if value ~= "icons" and value ~= "bars" then return end
                            DB().eyes.display = value
                            Notify()
                        end } or nil,
            position = { type = "group", name = "", inline = true, order = 2, suiTwoCol = true,
                hidden = function() return not DB()[key].enabled end, args = {
                    x = { type = "range", name = "ui.x_offset_0b923c73", order = 1,
                        min = -2000, max = 2000, step = 1,
                        get = function() return DB()[key].x end,
                        set = function(_, value) timers:SetCoordinate(key, "x", value) end },
                    y = { type = "range", name = "ui.y_offset_f7f3fdd7", order = 2,
                        min = -2000, max = 2000, step = 1,
                        get = function() return DB()[key].y end,
                        set = function(_, value) timers:SetCoordinate(key, "y", value) end },
                    move = { type = "execute", order = 3, width = "full", suiFullRow = true,
                        disabled = InArena,
                        name = function()
                            return SarychUI:T(SarychUI.DragMode:IsPositionEditorOpen(FrameID(key))
                                and "ui.options_76e4992833" or "ui.options_0510004a87")
                        end,
                        func = function()
                            if InArena() then return end
                            timers:Refresh()
                            SarychUI.DragMode:TogglePositionEditor(FrameID(key))
                            timers:Update()
                            SarychUI:NotifySarychUIOptionsChange()
                        end,
                        suiResetDefaults = function()
                            CloseMover(key)
                            local cfg = DB()[key]
                            cfg.point, cfg.relativePoint, cfg.x, cfg.y = "LEFT", "CENTER", def.x, def.y
                            SarychUI.DragMode:SetFramePosition(FrameID(key), cfg.point, cfg.relativePoint, cfg.x, cfg.y)
                            Notify()
                        end },
                    scale = { type = "range", name = "ui.frame_scale_6bfd4954", order = 4, width = "full", suiFullRow = true,
                        hidden = function() return key == "eyes" and DB().eyes.display == "bars" end,
                        min = 0.5, max = 3, step = 0.05,
                        get = function() return DB()[key].scale end,
                        set = function(_, value) DB()[key].scale = value; timers:Refresh() end },
                } },
        } }
        if key == "eyes" then
            local fields = {
                {"barWidth", "ui.arena.timer_bar_width", 80, 400},
            }
            for i, field in ipairs(fields) do
                local setting = field[1]
                args[key].args.position.args[setting] = {
                    type = "range", name = field[2], order = 3.5 + i / 10,
                    min = field[3], max = field[4], step = 1,
                    width = "full", suiFullRow = true,
                    hidden = function() return DB().eyes.display ~= "bars" end,
                    get = function() return DB().eyes[setting] end,
                    set = function(_, value) DB().eyes[setting] = value; timers:Refresh() end,
                }
            end
        end
    end
    return { type = "group", name = "ui.arena.timers", inline = true, order = 1.5, suiHeaderAction = test, suiHeaderActionAdjacent = true, args = args }
end
