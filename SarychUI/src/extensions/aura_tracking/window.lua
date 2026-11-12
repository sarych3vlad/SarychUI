local CreateFrame = SarychUI.OptionsPool and SarychUI.OptionsPool.CreateFrame or CreateFrame
-- Original settings hierarchy rendered by the same window and controls as SUI.
local SUI = SarychUI
local Core = { selection = {} }
SUI.AuraTrackingOptionsCore = Core
local refresh = CreateFrame("Frame", nil, nil, nil, "aura_tracking.window:1")

local function Append(path, key)
    local result = {unpack(path)}
    result[#result + 1] = key
    return result
end
local function Value(option, field, path)
    local value = option[field]
    if type(value) == "function" then
        local info = {unpack(path)}
        info.option, info.arg = option, option.arg
        return value(info)
    end
    return value
end
local function Groups(node, path)
    local groups = {}
    for key, option in pairs(node.args or {}) do
        local childPath = Append(path, key)
        if option.type == "group" and not (option.inline or option.guiInline or option.dialogInline)
            and not Value(option, "hidden", childPath) then
            groups[#groups + 1] = {key = key, opt = option,
                label = Value(option, "name", childPath) or tostring(key),
                order = Value(option, "order", childPath) or 100}
        end
    end
    table.sort(groups, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return tostring(a.label) < tostring(b.label)
    end)
    return groups
end
local function Body(node)
    local body = {}
    for key, value in pairs(node) do body[key] = value end
    body.args, body.childGroups = {}, nil
    for key, option in pairs(node.args or {}) do
        if option.type ~= "group" or option.inline or option.guiInline or option.dialogInline then
            body.args[key] = option
        end
    end
    return body
end
function Core:GetTabGroups() return {} end
function Core:IsOpen() return self.window and self.window:IsShown() or false end
function Core:Close()
    refresh:SetScript("OnUpdate", nil)
    if self.window then self.window:Hide() end
    if SUI._activeOptionsCore == self then
        SUI._activeOptionsCore, SUI._activeOptionsWindow, SUI._activeAceOptionsRoot = nil, nil, nil
    end
end
function Core:Choose(groups, key)
    for _, entry in ipairs(groups) do if entry.key == key then return entry end end
    return groups[1]
end
function Core:Render()
    if not self:IsOpen() then return end
    local window, R = self.window, SUI.OptionsRenderer
    SUI._activeOptionsCore, SUI._activeOptionsWindow, SUI._activeAceOptionsRoot = self, window, self.options
    window:ClearContent()
    local parent = window.contentChild
    local hosts = {}
    local function Measure()
        local height = 0
        for _, host in ipairs(hosts) do height = height + host:GetHeight() + 6 end
        parent:SetHeight(math.max(40, height))
        if window.contentScroll.UpdateScrollChildRect then window.contentScroll:UpdateScrollChildRect() end
        if window.UpdateContentScrollbar then window.UpdateContentScrollbar() end
    end
    local function Section(node, path, tree, general)
        local body = tree and node or Body(node)
        if not next(body.args or {}) then return end
        local host = CreateFrame("Frame", nil, parent, nil, "aura_tracking.window:2")
        local previous = hosts[#hosts]
        host:SetPoint("TOPLEFT", previous or parent, previous and "BOTTOMLEFT" or "TOPLEFT", 0, previous and -6 or 0)
        host:SetPoint("TOPRIGHT", previous or parent, previous and "BOTTOMRIGHT" or "TOPRIGHT", 0, previous and -6 or 0)
        host:SetWidth(parent:GetWidth())
        hosts[#hosts + 1] = host
        host._onContentHeightChanged = Measure
        host:SetScript("OnSizeChanged", Measure)
        if tree then R:RenderTwoPaneAddonList(host, body, path)
        elseif general then
            -- Render the inline group through the normal section layout, which
            -- owns its height and prevents the next panel from covering it.
            R:RenderSection(host, {type = "group", args = {general = node}}, path)
        else
            body.inline = true
            if not body.suiTwoCol and not body.suiThreeCol then body.suiThreeCol = true end
            local pad = SUI.OptionsTheme.sizes.contentPad or 4
            -- Inline groups own their internal padding; inset their host to
            -- match the shared general section rendered by RenderSection.
            host:ClearAllPoints()
            host:SetPoint("TOPLEFT", previous or parent, previous and "BOTTOMLEFT" or "TOPLEFT", pad, previous and -6 or -pad)
            host:SetPoint("TOPRIGHT", previous or parent, previous and "BOTTOMRIGHT" or "TOPRIGHT", -pad, previous and -6 or -pad)
            host:SetWidth(parent:GetWidth() - pad * 2)
            local y = 0
            if path[#path] == "lossOfControl" then
                local W = SUI.OptionsWidgets
                local test = body.args.test
                local testPath = Append(path, "test")
                local header = W:Header(host, Value(body, "name", path))
                local button = W:Button(header, Value(test, "name", testPath), function()
                    test.func()
                    self:OnSettingChanged()
                end, function() return Value(test, "desc", testPath) end)
                button:SetWidth(math.max(140, button.label:GetStringWidth() + 24))
                button:SetPoint("RIGHT", header, "RIGHT", 0, 0)
                button:SetDisabled(Value(test, "disabled", testPath))
                header:SetHeight(math.max(header:GetHeight(), button:GetHeight()))
                header.label:SetPoint("RIGHT", button, "LEFT", -10, 0)
                header.label:SetJustifyH("LEFT")
                y = R:LayoutChild(host, header, y)
                body.name, body.args.test = "", nil
            end
            local bottom = R:RenderControl(host, path[#path], body, path, y, pad)
            host:SetHeight(math.max(40, -bottom + pad))
        end
    end
    local tabs = Groups(self.options, {})
    local main = self:Choose(tabs, self.selectedTab)
    if not main then return end
    self.selectedTab = main.key
    local test = self.options.args.test
    local testButton = {type = "execute", name = "Режим настройки", func = function()
        local info = {"test", option = test, handler = test.handler}
        if type(test.func) == "string" then test.handler[test.func](test.handler, info)
        else test.func(info) end
        self:OnSettingChanged()
    end}
    window:SetTabs(tabs, main.key, function(key)
        self.selectedTab = key
        self:Render()
    end, testButton)
    local path = {main.key}
    local subtabs = Groups(main.opt, path)
    local sub = self:Choose(subtabs, self.selection[main.key])
    -- Render the shared general group directly. Wrapping the whole tab in an
    -- extra inline panel made its header and controls overlap other sections.
    if (not sub or sub.key ~= "lossOfControl") and main.opt.args.general then
        Section(main.opt.args.general, path, false, true)
    elseif not sub and main.key ~= "unitFrames" then
        Section(main.opt, path)
    end
    window:SetSubTabs(subtabs, sub and sub.key, function(key)
        self.selection[main.key] = key
        self:Render()
    end)
    if sub then
        self.selection[main.key] = sub.key
        local subPath = Append(path, sub.key)
        if #Groups(sub.opt, subPath) > 0 then
            -- Spell categories retain their spell list and detail pane.
            Section(sub.opt, subPath, true)
        else Section(sub.opt, subPath) end
    end
    Measure()
end
function Core:OnSettingChanged()
    if not self:IsOpen() then return end
    refresh:SetScript("OnUpdate", function()
        if not self:IsOpen() then
            refresh:SetScript("OnUpdate", nil)
            return
        end
        -- Live slider setters refresh BigDebuffs on every step. Rebuilding the
        -- window here destroys the dragged row (and focused numeric edit box).
        -- Coalesce those requests until the shared SUI interaction completes.
        if SUI.IsOptionsInteractBusy and SUI.IsOptionsInteractBusy() then return end
        local widgets = SUI.OptionsWidgets
        if widgets and widgets.IsDropdownOpen and widgets:IsDropdownOpen() then return end
        refresh:SetScript("OnUpdate", nil)
        local scroll = self.window.contentScroll
        local savedScroll = scroll and scroll:GetVerticalScroll() or 0
        self:Render()
        if scroll then
            scroll:SetVerticalScroll(math.max(0, math.min(savedScroll, scroll:GetVerticalScrollRange() or 0)))
        end
    end)
end
Core.ScheduleSmartRefresh = Core.OnSettingChanged
function Core:Open(options)
    if SUI.CloseOptions then SUI:CloseOptions() end
    self.options = options
    if not self.window then
        self.window = SUI.CreateOptionsWindowInstance({
            frameName = "SarychUIAuraTrackingOptions", title = "Отслеживание аур",
            positionKey = "auraTrackingOptions", getCore = function() return Core end,
        })
        local window = self.window
        -- This settings hierarchy uses top tabs, not the main SUI sidebar.
        function window:GetContentPixelWidth()
            return math.max(320, (self.root and self.root:GetWidth() or SUI.OptionsTheme.sizes.windowW) - 2)
        end
        window:CreateRoot()
        window:EnableContentScrollbar()
        window.nav:Hide()
        window.content:ClearAllPoints()
        window.content:SetPoint("TOPLEFT", window.root, "TOPLEFT", 1, -(SUI.OptionsTheme.sizes.headerH + 1))
        window.content:SetPoint("BOTTOMRIGHT", window.root, "BOTTOMRIGHT", -1, SUI.OptionsTheme.sizes.footerH + 1)
        window.root:HookScript("OnHide", function()
            refresh:SetScript("OnUpdate", nil)
            if SUI._activeOptionsCore == Core then
                SUI._activeOptionsCore, SUI._activeOptionsWindow, SUI._activeAceOptionsRoot = nil, nil, nil
            end
        end)
    end
    self.window:Show()
    self:Render()
end
