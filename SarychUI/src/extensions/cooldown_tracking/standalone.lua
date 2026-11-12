-- Cooldown views adapted from OmniBar (Jordon), Aesa (Kydori), and Afflicted (Shadow).
-- All views read the same GUID/spell timers; dragging belongs exclusively to SUI DragMode.
local SUI = SarychUI
local tracker = SUI.extensions.party_abilities
local V = { hosts = {}, widgets = {}, pool = {}, editing = false, testing = false }
tracker.Standalone = V
local names = { Aesa = "Aesa/Afflicted", OmniBar = "OmniBar" }
local trackedUnits = { "target", "focus", "arena1", "arena2", "arena3" }
local unitNames = { target = "Цель", focus = "Фокус", arena1 = "Арена 1", arena2 = "Арена 2", arena3 = "Арена 3" }
local function DefaultY(group)
    local offsets = { target = 0, focus = -180, arena1 = 240, arena2 = 80, arena3 = -80, separateInterrupts = -100 }
    return offsets[group] or 0
end
-- Display grouping only; cooldown durations and rank resolution come from the original database.
local interrupts = { [16979]=true, [49376]=true, [72]=true, [1766]=true, [2139]=true, [6552]=true, [15487]=true, [19647]=true, [34490]=true, [47476]=true, [47528]=true, [57994]=true }
local media = [[Interface\AddOns\SarychUI\media\cooldowns\]]
local textures = {
    Aesa = {Steel="Steel", Ruben2="Ruben2", Ruben="Ruben", LiteStepLite2="LiteStepLite2", LiteStepLite="LiteStepLite", Frost="Frost", Button="Button"},
}
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
local function TextureName(style, name)
    if textures[style][name] then return "SarychUI " .. style .. " - " .. name end
    return name
end
local function TexturePath(style, name)
    local bundled = textures[style][name] and name or "Steel"
    local fallback = media .. [[aesa\]] .. bundled
    local key = TextureName(style, name or "Steel")
    return LSM and LSM:Fetch("statusbar", key, true) or fallback
end
local function TextureChoices()
    local values = {}
    if LSM then
        for _, name in ipairs(LSM:List("statusbar") or {}) do values[name] = name end
    end
    return values
end
local Visible = SUI.WidgetAPI.SetShown
local function DB()
    local db = tracker:GetDB()
    db.enemyMode = db.enemyMode or "arena"
    db.enemyViews = db.enemyViews or {}
    -- Retire the separate style while preserving the active user's visual settings.
    if db.enemyStyle == "Afflicted" then
        db.enemyViews.Aesa = db.enemyViews.Afflicted or db.enemyViews.Aesa
        db.enemyStyle = "Aesa"
    end
    db.enemyViews.Afflicted = nil
    db.enemyStyle = names[db.enemyStyle] and db.enemyStyle or "OmniBar"
    for _, style in ipairs({"Aesa", "OmniBar", "Interrupts"}) do
        db.enemyViews[style] = db.enemyViews[style] or {}
        local v = db.enemyViews[style]
        if not v.size then v.size = style == "Interrupts" and 30 or style == "OmniBar" and 36 or style == "Aesa" and 16 or 20 end
        v.width, v.rows, v.spacing = v.width or (style == "Aesa" and 160 or 180), v.rows or (style == "OmniBar" and 32 or 12), v.spacing or (style == "Interrupts" and 0 or style == "OmniBar" and 2 or 3)
        v.perRow = v.perRow or (style == "Interrupts" and 6 or 8)
        v.positions = v.positions or {}
        if v.growUp == nil then v.growUp = style == "OmniBar" end
        v.alpha = v.alpha or 1
        v.color = v.color or {0.42, 0.69, 1}
        if style == "Aesa" then
            v.display = v.display == "icons" and "icons" or "bars"
            v.perColumn = math.max(1, math.min(40, math.floor(tonumber(v.perColumn) or 6)))
            v.columnDirection = v.columnDirection == "left" and "left" or "right"
            if v.texture and v.texture:find("SarychUI Afflicted", 1, true) then v.texture = nil end
            v.positions.interrupts, v.positions.cooldowns, v.interruptsEnabled = nil, nil, nil
        end

    end
    return db
end
function tracker:IsArenaDisplayEnabled() return DB().enemyMode == "arena" end
local function SeparateInterrupts(db)
    return db.enemyMode == "standalone" and db.separateInterrupts == true
end
local function SetBarLabel(bar, label, width)
    width = math.max(1, width)
    if bar.labelSource == label and bar.labelWidth == width then return end
    bar.labelSource, bar.labelWidth = label, width
    local measure = bar.labelMeasure
    measure:SetText(label)
    if (measure:GetStringWidth() or 0) <= width then
        bar.text:SetText(label)
        return
    end
    local characters = {}
    for character in label:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        characters[#characters + 1] = character
    end
    local low, high, fitted = 0, #characters, "…"
    while low <= high do
        local middle = math.floor((low + high) / 2)
        local candidate = table.concat(characters, "", 1, middle) .. "…"
        measure:SetText(candidate)
        if (measure:GetStringWidth() or 0) <= width then
            fitted, low = candidate, middle + 1
        else
            high = middle - 1
        end
    end
    bar.text:SetText(fitted)
end
-- Shared by arena timers so texture selection and UTF-8 ellipsis stay identical.
function V:GetBarTexture()
    return TexturePath("Aesa", DB().enemyViews.Aesa.texture)
end
function V:FitBarLabel(bar, label, width)
    SetBarLabel(bar, label, width)
end
local function UpdateWidget(w, now)
    local e = w.entry
    if not e or not w.time then return end
    local left = e.pending and e.duration or e.start + e.duration - now
    if left <= 0 then
        w:Hide()
        return
    end
    local cc = SUI.modules.cc
    if cc:UpdateTimerText(w.time, left, e.duration, w, true) and e.pending then w.time:SetText("…") end
    if not w.spark then return end
    local fraction = math.max(0, math.min(1, left / e.duration))
    w:SetMinMaxValues(0, e.duration)
    w:SetValue(left)
    if w.colorMode == "remaining" then w:SetStatusBarColor(1-fraction, 0.5*fraction, 0.5*fraction) end
    w.spark:ClearAllPoints()
    w.spark:SetPoint("CENTER", w, "LEFT", w:GetWidth() * fraction, 0)
end
local function Host(style, group)
    local key = style .. group
    if V.hosts[key] then return V.hosts[key] end
    local host = CreateFrame("Frame", "SarychUICooldowns" .. key, UIParent)
    host:SetFrameStrata("MEDIUM")
    host:SetSize(180, 40)
    host:SetClampedToScreen(true)
    local label = (style == "Interrupts" and "Прерывания" or names[style]) .. (unitNames[group] and " — " .. unitNames[group] or "")
    host.dragID = "cooldownTracking" .. key
    host.style, host.group = style, group
    local cfg = DB().enemyViews[style]
    local pos = cfg.positions[group] or {point="CENTER", relativePoint="CENTER", x=200, y=DefaultY(group)}
    cfg.positions[group] = pos
    host:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    SUI.DragMode:RegisterFrame(host.dragID, host, {
        dragText = label,
        preservePositionOnDisable = true,
        onPositionChanged = function(point, relativePoint, x, y)
            local position = DB().enemyViews[style].positions[group]
            position.point, position.relativePoint, position.x, position.y = point, relativePoint, x, y
            SUI.PositionDragPanel:OnDragPosition(host.dragID, x, y, point, relativePoint)
        end,
    })
    SUI.PositionDragPanel:RegisterFrame(host.dragID, {
        moduleKey = "party_abilities", subKey = "enemyViews." .. style .. ".positions." .. group,
        title = label, xKey = "x", yKey = "y", aKey = "point", rKey = "relativePoint",
        defaultX = pos.x, defaultY = pos.y, defaultA = "CENTER", defaultR = "CENTER",
        dragFlag = "moving",
        onClosed = function() V.editing = false; V.editHost = nil; V._layoutValid = false end,
    })
    V.hosts[key] = host
    return host
end
local function Bar(style, key, host)
    local bar = CreateFrame("StatusBar", nil, host)
    bar:SetStatusBarTexture(TexturePath(style, DB().enemyViews[style].texture))
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetTexture(0, 0, 0, 0.8)
    bar.texture = bar:CreateTexture(nil, "ARTWORK")
    bar.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("LEFT", bar, "LEFT", 3, 0)
    bar.text:SetJustifyH("LEFT")
    bar.labelMeasure = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.labelMeasure:Hide()
    bar.time = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.time:SetPoint("RIGHT", bar, "RIGHT", -2, 0)
    bar.spark = bar:CreateTexture(nil, "OVERLAY")
    bar.spark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
    bar.spark:SetBlendMode("ADD"); bar.spark:SetWidth(24)
    return bar
end
local function Widget(style, entry, host)
    local iconList = style == "Aesa" and DB().enemyViews.Aesa.display == "icons"
    local skin = style .. (iconList and "Icons" or "Bars")
    local key = skin .. host.group .. entry.key
    local w = V.widgets[key]
    if not w then
        V.pool[skin] = V.pool[skin] or {}
        w = table.remove(V.pool[skin])
        if w then w:SetParent(host) end
    end
    if not w then
        if style == "OmniBar" or style == "InterruptBar" then
            w = tracker:CreateStandaloneIcon()
            w:SetParent(host)
            w.name = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallOutline")
            w.name:SetFont(STANDARD_TEXT_FONT, 8, "OUTLINE")
            w.name:SetPoint("BOTTOM", w, "BOTTOM", 0, 2)
            w.focusBorder = w:CreateTexture(nil, "BACKGROUND")
            w.focusBorder:SetTexture(media .. [[omnibar\Bags]])
            w.focusBorder:SetBlendMode("ADD");w.focusBorder:SetPoint("CENTER")
        elseif iconList then
            w = CreateFrame("Frame", nil, host)
            w.texture = w:CreateTexture(nil, "ARTWORK")
            w.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            w.time = w:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        else w = Bar(style, key, host) end
    end
    w.__sary_partyAbility = true
    V.widgets[key] = w
    w.skin = skin
    w.entry, w.seen = entry, true
    return w
end
local function Samples()
    local now = GetTime()
    local result = {}
    local samples = {
        {45438, "test-target", "Цель"}, {48792, "test-focus", "Фокус"},
        {12043, "test-target", "Цель"}, {48707, "test-focus", "Фокус"},
        {12472, "test-target", "Цель"}, {49028, "test-focus", "Фокус"},
        {2139, "test-target", "Цель"}, {6552, "test-focus", "Фокус"},
        {1766, "test-target", "Цель"},
        {45438, "test-arena1", "Арена 1"}, {2139, "test-arena1", "Арена 1"},
        {48792, "test-arena2", "Арена 2"}, {47528, "test-arena2", "Арена 2"},
        {31224, "test-arena3", "Арена 3"}, {1766, "test-arena3", "Арена 3"},
    }
    for i, sample in ipairs(samples) do
        local id = sample[1]
        local record = SUI.Data.EnemyAbilities.Catalog[id]
        result[i] = {key="test"..i,guid=sample[2],id=id,
            name=sample[3],class=record.class,start=now-((now%20)+3),duration=record.base,
            texture=select(3,GetSpellInfo(id)),data={enabled=true}}
    end
    return result
end
function V:Refresh(entries)
    self._layoutValid = false
    local db = DB()
    if db.masterEnabled == false or db.enemyMode ~= "standalone" then
        self:SetEditing(false)
        for _, h in pairs(self.hosts) do h:Hide() end
        for _, w in pairs(self.widgets) do w:Hide() end
        self._inactive = true
        return
    end
    self._inactive = false
    if self.profile ~= db then
        self:SetEditing(false)
        for _,host in pairs(self.hosts) do
            local pos=db.enemyViews[host.style].positions[host.group] or {point="CENTER",relativePoint="CENTER",x=200,y=DefaultY(host.group)}
            db.enemyViews[host.style].positions[host.group] = pos
            host:ClearAllPoints();host:SetPoint(pos.point,UIParent,pos.relativePoint,pos.x,pos.y)
        end
        self.profile=db
    end
    local style, cfg = db.enemyStyle, db.enemyViews[db.enemyStyle]
    for _, w in pairs(self.widgets) do w.seen = false end
    for _, h in pairs(self.hosts) do h.activeView = false end
    entries = entries or (self.testing and Samples() or tracker:GetEnemyCooldownSnapshot(self._entries))
    self._entries = entries
    local groups = {}
    local unitGUIDs = {}
    for _, unit in ipairs(trackedUnits) do
        unitGUIDs[unit] = self.testing and "test-" .. unit or UnitGUID(unit)
        if style == "Aesa" and cfg[unit .. "Enabled"] ~= false then groups[#groups+1] = unit end
    end
    if style ~= "Aesa" then groups[1] = "all" end
    self._unitGUIDs = unitGUIDs
    local targetGUID, focusGUID = unitGUIDs.target, unitGUIDs.focus
    local separate = SeparateInterrupts(db)
    if separate then groups[#groups+1] = "separateInterrupts" end
    local mainStyle = style
    for _, group in ipairs(groups) do
        local extra = group == "separateInterrupts"
        local style = extra and (db.interruptAppearance == "original" and "InterruptBar" or mainStyle) or mainStyle
        -- The extra host owns only its position when using the selected skin.
        local cfg = db.enemyViews[extra and db.interruptAppearance == "original" and "Interrupts" or mainStyle]
        local iconsView = style == "OmniBar" or style == "InterruptBar"
        -- Keep expiry order consistent with the chosen growth direction.
        local growUp = cfg.growUp == true
        local iconList = style == "Aesa" and cfg.display == "icons"
        local host, list = Host(extra and "Interrupts" or mainStyle, group), {}
        host.activeView = true
        for _, e in ipairs(entries) do
            local matches = group == "all" or (unitGUIDs[group] and e.guid == unitGUIDs[group])
            if extra then matches = interrupts[e.id]
            elseif separate and interrupts[e.id] then matches = false end
            if matches then list[#list+1] = e end
        end
        table.sort(list, function(a,b)
            local av = iconsView and a.start or a.start+a.duration
            local bv = iconsView and b.start or b.start+b.duration
            if av == bv then return a.key < b.key end
            local descending = not iconsView and ((cfg.sort == "last") ~= growUp)
            if descending then return av > bv end
            return av < bv
        end)
        local newestStart=0
        for _,entry in ipairs(list) do newestStart=math.max(newestStart,entry.start or 0) end
        local count = math.min(#list, cfg.rows)
        local size, spacing = cfg.size, cfg.spacing
        if iconList then
            local columns = math.max(1, math.ceil(count / cfg.perColumn))
            local rows = math.max(1, math.min(count, cfg.perColumn))
            host:SetSize(columns * (size + 45) + (columns - 1) * spacing,
                rows * size + (rows - 1) * spacing)
        else
            host:SetSize(iconsView and math.max(80,math.min(count,cfg.perRow)*(size+spacing)) or cfg.width+size,
                math.max(size, iconsView and math.ceil(count/cfg.perRow)*(size+spacing) or count*(size+spacing)))
        end
        Visible(host, count>0 or self.editing)
        for index=1,count do
            local e=list[index];local w=Widget(style,e,host)
            local appearing=not w:IsShown()
            w.baseAlpha=cfg.alpha
            w:SetAlpha(cfg.alpha)
            w:ClearAllPoints()
            w.texture:SetTexture(e.texture)
            w.spellID,w.spellData=e.id,e.data
            if iconsView then
                w:SetSize(size,size)
                local column, row = (index-1)%cfg.perRow, math.floor((index-1)/cfg.perRow)
                local rowCount = math.min(cfg.perRow, count-row*cfg.perRow)
                local anchor = growUp and "BOTTOM" or "TOP"
                local x = column*(size+spacing)
                if cfg.align == "center" then
                    x = x - (rowCount*(size+spacing)-spacing)/2
                elseif cfg.align == "right" then
                    anchor = anchor .. "RIGHT"
                    x = -column*(size+spacing)-size
                else anchor = anchor .. "LEFT" end
                w:SetPoint(growUp and "BOTTOMLEFT" or "TOPLEFT",host,anchor,x,(growUp and 1 or -1)*row*(size+spacing))
                w.name:SetWidth(size);w.name:SetText(cfg.names and e.name or "")
                Visible(w.pendingText, e.pending)
                w.cooldown:SetReverse(style ~= "InterruptBar")
                w.cooldown:SetDrawEdge(false)
                tracker:SetIconTimer(w, not e.pending and e.start or nil, e.duration, style ~= "InterruptBar")
                Visible(w.cooldown, not e.pending)
                w.focusBorder:SetSize(size*39/36,size*39/36)
                local targeted,focused=e.guid==targetGUID,e.guid==focusGUID
                w.focusBorder:SetTexCoord(0.00390625,0.15625,targeted and 0.539062 or 0.699219,targeted and 0.691406 or 0.851562)
                Visible(w.focusBorder, style == "OmniBar" and (targeted or focused))
                if style == "InterruptBar" then w.texture:SetTexCoord(0.07,0.9,0.07,0.9) end
                if appearing and style == "OmniBar" then tracker:AnimateStandaloneIcon(w) end
            elseif iconList then
                w:SetSize(size+45,size)
                local column, row = math.floor((index-1)/cfg.perColumn), (index-1)%cfg.perColumn
                local left = cfg.columnDirection == "left"
                local anchor = (growUp and "BOTTOM" or "TOP") .. (left and "RIGHT" or "LEFT")
                w:SetPoint(anchor,host,anchor,(left and -1 or 1)*column*(size+45+spacing),
                    (growUp and 1 or -1)*row*(size+spacing))
                local right=cfg.iconSide=="right"
                w.texture:SetSize(size,size);w.texture:ClearAllPoints();w.texture:SetPoint(right and "RIGHT" or "LEFT",w,right and "RIGHT" or "LEFT",0,0)
                w.time:ClearAllPoints();w.time:SetPoint(right and "RIGHT" or "LEFT",w.texture,right and "LEFT" or "RIGHT",right and -2 or 2,0)
            else
                w:SetSize(cfg.width,size)
                local right=cfg.iconSide=="right"
                local anchor=growUp and "BOTTOMLEFT" or "TOPLEFT"
                w:SetPoint(anchor,host,anchor,right and 0 or size,(growUp and 1 or -1)*(index-1)*(size+spacing))
                w.texture:SetSize(size,size);w.texture:ClearAllPoints();w.texture:SetPoint(right and "LEFT" or "RIGHT",w,right and "RIGHT" or "LEFT",0,0)
                w:SetStatusBarTexture(TexturePath(style, cfg.texture))
                local labelWidth = math.max(1, cfg.width - 48)
                w.text:SetWidth(labelWidth)
                w.text:SetHeight(size)
                SetBarLabel(w, (GetSpellInfo(e.id) or tostring(e.id)), labelWidth)
                local c=RAID_CLASS_COLORS[e.class] or {r=0.42,g=0.69,b=1}
                w:SetStatusBarColor(0.42, 0.69, 1)
                w.spark:SetHeight(size+22);Visible(w.spark, style=="Aesa")
                w.viewStyle=style
                w.colorMode=cfg.colorMode or "original"
                if w.colorMode=="custom" then w:SetStatusBarColor(unpack(cfg.color))
                elseif w.colorMode=="class" then w:SetStatusBarColor(c.r,c.g,c.b) end
                if style=="Aesa" and w.colorMode=="original" and cfg.highlightNew~=false and e.start==newestStart then
                    if group=="focus" then w:SetStatusBarColor(1,0.8,0) else w:SetStatusBarColor(0,0.98,0.36) end
                end
            end
            w:Show()
            UpdateWidget(w, GetTime())
        end
    end
    if self.editHost and not self.editHost.activeView then self:SetEditing(false) end
    for _, host in pairs(self.hosts) do if not host.activeView then host:Hide() end end
    for key, w in pairs(self.widgets) do
        if not w.seen then
            w:Hide(); w.entry=nil
            self.widgets[key]=nil
            self.pool[w.skin]=self.pool[w.skin] or {}
            table.insert(self.pool[w.skin],w)
        end
    end
    self._layoutValid = true
    self._layoutStyle = db.enemyStyle
    self._layoutConfig = db.enemyViews[db.enemyStyle]
end

function V:Tick(now)
    local db = DB()
    if db.masterEnabled == false or db.enemyMode ~= "standalone" then
        if not self._inactive then self:Refresh() end
        return
    end
    if self.testing then self:Refresh(); return end
    local entries, changed = tracker:GetEnemyCooldownSnapshot(self._entries)
    self._entries = entries
    local rebuild = changed ~= false or not self._layoutValid or self.profile ~= db
        or self._layoutStyle ~= db.enemyStyle or self._layoutConfig ~= db.enemyViews[db.enemyStyle]
    for _, unit in ipairs(trackedUnits) do
        if not self._unitGUIDs or self._unitGUIDs[unit] ~= UnitGUID(unit) then rebuild = true end
    end
    if rebuild then self:Refresh(entries)
    else
        for _, widget in pairs(self.widgets) do UpdateWidget(widget, now) end
    end
end

function V:SetEditing(on, group)
    self._layoutValid = false
    local panel = SUI.PositionDragPanel
    if self.editHost then
        panel:Toggle(self.editHost.dragID, false)
        self.editHost = nil
    end
    self.editing = on and true or false
    if not self.editing then return end
    local db = DB()
    self.editHost = Host(group == "separateInterrupts" and "Interrupts" or db.enemyStyle, group or (db.enemyStyle == "Aesa" and "target" or "all"))
    self.editHost:Show()
    db.enemyViews[self.editHost.style].positions[self.editHost.group].moving = 1
    panel:Toggle(self.editHost.dragID, true)
end
function V:Apply()
    self:SetEditing(false)
    self:Refresh()
end
SUI.UpdateScheduler:RegisterUpdate("cooldownTrackingViews", 0.1, function(now)
    if not (SUI.db and SUI.db.profile.modules.party_abilities) then return end
    V:Tick(now)
end)
function tracker:AddEnemyDisplayOptions(group)
    local function Refresh()
        V:Apply()
        tracker:RefreshGroupFrames()
        if SUI.RefreshExtensionOptions then SUI:RefreshExtensionOptions() end
        SUI:NotifySarychUIOptionsChange()
        if SUI.OptionsCore and SUI.OptionsCore.ScheduleSmartRefresh then SUI.OptionsCore:ScheduleSmartRefresh(true) end
        local arena=SUI.modules.arena
        if arena and arena.ApplyFrameSpacing then arena:ApplyFrameSpacing() end
    end
    local function Section(name, order, args)
        return { type="group", name=name, inline=true, order=order, args=args or {} }
    end
    group.args.general.args = {
        display = Section("Отображение", 1, {
            mode={type="select",name="Размещение",order=1,
                values={arena="На рамках арены",standalone="Отдельно на экране",__order={"arena","standalone"}},
                get=function()return DB().enemyMode end,set=function(_,v)DB().enemyMode=v;Refresh()end},
            style={type="select",name="Внешний вид",order=2,
                hidden=function()return DB().enemyMode~="standalone" end,
                values={Aesa="Aesa/Afflicted",OmniBar="OmniBar",__order={"Aesa","OmniBar"}},
                get=function()return DB().enemyStyle end,set=function(_,v)DB().enemyStyle=v;Refresh()end},
        }),
        interrupts = Section("Отдельное отображение прерываний", 2, {
            enabled={type="toggle",name="Включить",order=1,
                get=function()return DB().separateInterrupts==true end,
                set=function(_,v)DB().separateInterrupts=v;Refresh()end},
            appearance={type="select",name="Внешний вид",order=2,
                hidden=function()return not DB().separateInterrupts end,
                values={current="Текущий стиль внешнего вида",original="Оригинальный InterruptBar",__order={"current","original"}},
                get=function()return DB().interruptAppearance or "current" end,
                set=function(_,v)DB().interruptAppearance=v;Refresh()end},
        }),
    }
    group.args.general.args.interrupts.hidden=function() return DB().enemyMode~="standalone" end
    for _,style in ipairs({"Aesa","OmniBar","Interrupts"}) do
        local current=style
        local extra=current=="Interrupts"
        local function C() return DB().enemyViews[current] end
        local function Changed() V:Apply(); SUI:NotifySarychUIOptionsChange() end
        local function Slider(key,label,min,max,order)
            return {type="range",name=label,min=min,max=max,step=1,order=order,width="full",suiFullRow=true,
                get=function()return C()[key]end,set=function(_,v)C()[key]=v;V:Refresh()end}
        end
        local function Select(key,label,values,default,order)
            return {type="select",name=label,values=values,order=order,width="full",suiFullRow=true,
                get=function()local v=C()[key];if v==nil then return default end;return v end,
                set=function(_,v)C()[key]=v;Changed()end}
        end
        local function Toggle(key,label,default,order)
            return {type="toggle",name=label,order=order,
                get=function()local v=C()[key];if v==nil then return default end;return v end,
                set=function(_,v)C()[key]=v;Changed()end}
        end
        local function Move(positionGroup, label, order)
            return {type="execute",name=function()
                return label .. (V.editHost and V.editHost.style==current and V.editHost.group==positionGroup and " |cff00ff00(вкл)|r" or "")
            end,order=order,width="full",
                disabled=function()return current=="Aesa" and C()[positionGroup.."Enabled"]==false end,
                func=function()
                    local on=not (V.editHost and V.editHost.style==current and V.editHost.group==positionGroup)
                    V:Refresh();V:SetEditing(on,positionGroup);V:Refresh();SUI:NotifySarychUIOptionsChange()
                end,
                suiResetDefaults=function()
                    local host=Host(current,positionGroup)
                    local pos=C().positions[positionGroup]
                    pos.point,pos.relativePoint,pos.x,pos.y="CENTER","CENTER",200,DefaultY(positionGroup)
                    host:ClearAllPoints();host:SetPoint(pos.point,UIParent,pos.relativePoint,pos.x,pos.y)
                    SUI.PositionDragPanel:SyncDraftIfOpen(host.dragID,pos.x,pos.y,pos.point,pos.relativePoint)
                    V:Refresh()
                end}
        end
        local args={}
        group.args[current]={type="group",name=extra and "Настройки прерываний" or "Настройки "..names[current],order=extra and 21 or 20,
            hidden=function()
                if extra then return not SeparateInterrupts(DB()) end
                return DB().enemyMode~="standalone" or DB().enemyStyle~=current
            end,args=args}
        if current=="Aesa" then
            args.units=Section("У кого показывать",1)
            args.units.suiThreeCol=true
            for index,unit in ipairs(trackedUnits) do
                args.units.args[unit]=Toggle(unit.."Enabled",unitNames[unit],true,index)
            end
        end
        args.appearance=Section("Внешний вид",current=="Aesa" and 3 or 1)
        local appearance=args.appearance.args
        if current=="Aesa" then
            appearance.display=Select("display","Отображение",{bars="Полоска",icons="Иконка",__order={"bars","icons"}},"bars",1)
        end
        appearance.size=Slider("size",function()
            return current=="Aesa" and C().display~="icons" and "Высота полоски" or "Размер иконки"
        end,12,64,2)
        appearance.rows=Slider("rows","Максимум таймеров",1,40,4)
        appearance.spacing=Slider("spacing","Отступ",0,20,5)
        if current=="Aesa" then
            local function Icons()return C().display=="icons" end
            appearance.width=Slider("width","Ширина полоски",80,400,3)
            appearance.width.hidden=Icons
            appearance.perColumn=Slider("perColumn","Иконок в столбце",1,40,3.1)
            appearance.perColumn.hidden=function()return not Icons()end
            appearance.columnDirection=Select("columnDirection","Направление столбцов",
                {right="Вправо",left="Влево",__order={"right","left"}},"right",3.2)
            appearance.columnDirection.hidden=function()return not Icons()end
            appearance.iconSide=Select("iconSide","Положение иконки",{left="Слева",right="Справа",__order={"left","right"}},"left",6)
            appearance.sort=Select("sort","Порядок перезарядок",{first="Истекающие сверху",last="Истекающие снизу",__order={"first","last"}},"first",7)
            args.bars=Section("Оформление полоски",4,{
                texture=Select("texture","Текстура",TextureChoices,"SarychUI Aesa - Steel",1),
                colorMode=Select("colorMode","Цвет полоски",{original="Стиль аддона",class="По классу",custom="Свой цвет",remaining="По оставшемуся времени",__order={"original","class","custom","remaining"}},"original",2),
                color={type="color",name="Свой цвет",order=3,
                    hidden=function()return C().colorMode~="custom" end,
                    get=function()return unpack(C().color)end,
                    set=function(_,r,g,b)C().color={r,g,b};V:Refresh()end},
                highlightNew=Toggle("highlightNew","Выделять новую перезарядку",true,4),
            })
            args.bars.hidden=Icons
            args.bars.args.highlightNew.hidden=function() return (C().colorMode or "original")~="original" end
        else
            appearance.perRow=Slider("perRow","Иконок в ряду",1,20,3)
        end
        if not extra then
            appearance.alpha=Slider("alpha","Прозрачность",0.1,1,8);appearance.alpha.step=0.05
            appearance.growUp=Toggle("growUp","Рост вверх",current=="OmniBar",9)
            if current=="OmniBar" then
                appearance.names=Toggle("names","Имена противников",false,6)
                appearance.align=Select("align","Рост иконок",{left="Слева направо",center="От центра",right="Справа налево",__order={"left","center","right"}},"left",7)
            end
        else
            args.appearance.hidden=function()return DB().interruptAppearance~="original" end
        end
        args.position=Section("Расположение",2)
        if current=="Aesa" then
            for index,unit in ipairs(trackedUnits) do
                args.position.args[unit]=Move(unit,"Свободное перемещение — "..unitNames[unit],index)
            end
        else
            args.position.args.move=Move(extra and "separateInterrupts" or "all",extra and "Свободное перемещение — Прерывания" or "Свободное перемещение",extra and 6 or 1)
        end
    end
    local testButton={type="execute",
        name=function()
            return SUI:T(V.testing and "ui.options_2aa205e3d3" or "ui.options_ec1868c5a7")
        end,
        hidden=function() return DB().enemyMode~="standalone" or DB().masterEnabled==false end,
        disabled=function() return DB().masterEnabled==false end,
        func=function()
            V.testing=not V.testing
            V:Refresh()
            SUI:NotifySarychUIOptionsChange()
        end}
    group.args.Aesa.suiTabBarExtra=testButton
    group.args.OmniBar.suiTabBarExtra=testButton
    local interruptOptions=group.args.Interrupts
    group.args.Interrupts=nil
    local interruptMove=interruptOptions.args.position.args.move
    interruptMove.hidden=function() return not SeparateInterrupts(DB()) end
    interruptOptions.args.position=nil
    interruptOptions.inline=true
    interruptOptions.hidden=function()
        return not SeparateInterrupts(DB()) or DB().interruptAppearance~="original"
    end
    for _,skin in ipairs({"Aesa","OmniBar"}) do
        group.args[skin].args.position.args.interrupts=interruptMove
        group.args[skin].args.interrupts=interruptOptions
    end
end
