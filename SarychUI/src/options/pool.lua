-- Private options objects only. Never replace the global CreateFrame or recycle
-- Blizzard / AceGUI frames. Each construction role has its own typed free list.
local SUI = SarychUI
local P = { free = {}, records = {}, children = {}, childOrder = {}, pending = {} }
SUI.OptionsPool = P
local createFrame = CreateFrame
local unpack, pairs, next, type = unpack, pairs, next, type

local function Call(object, method, ...)
    local fn = object[method]
    if fn then return fn(object, ...) end
end

local function ClearFields(record)
    local object = record.object
    for key in pairs(object) do
        if record.base[key] == nil then object[key] = nil end
    end
    for key, value in pairs(record.base) do object[key] = value end
end

-- Hooks on recycled objects are lease-local. Dispatch through SetScript rather
-- than installing permanent native HookScript callbacks on every acquisition.
local function InstallScripts(record)
    local object, native = record.object, record.nativeSetScript
    if not native then return end
    local function Update(event)
        if record.scripts[event] or record.hooks[event] then
            local dispatch = record.dispatch[event]
            if not dispatch then
                dispatch = function(self, ...)
                    local generation = record.generation
                    local script = record.scripts[event]
                    if script then script(self, ...) end
                    if generation ~= record.generation or not record.active then return end
                    local hooks = record.hooks[event]
                    if hooks then
                        for i = 1, #hooks do
                            hooks[i](self, ...)
                            if generation ~= record.generation or not record.active then return end
                        end
                    end
                end
                record.dispatch[event] = dispatch
            end
            native(object, event, dispatch)
        else
            native(object, event, nil)
        end
    end
    object.SetScript = function(_, event, fn)
        record.scripts[event] = fn
        Update(event)
    end
    object.GetScript = function(_, event) return record.scripts[event] end
    object.HookScript = function(_, event, fn)
        local hooks = record.hooks[event] or {}
        record.hooks[event] = hooks
        hooks[#hooks + 1] = fn
        Update(event)
    end
end

local Prepare, ResetParts, InstallParts
local function InputDefault(object, getter, fallback)
    if object[getter] then return not not object[getter](object) end
    return fallback
end

local function Record(object, kind)
    local record = { object = object, kind = kind, base = {}, parts = {}, cursors = {},
        scripts = {}, hooks = {}, dispatch = {}, generation = 0, active = true }
    for key, value in pairs(object) do record.base[key] = value end
    record.nativeSetScript = object.SetScript
    record.nativeTexture = object.CreateTexture
    record.nativeFont = object.CreateFontString
    record.nativeGroup = object.CreateAnimationGroup
    record.nativeAnimation = object.CreateAnimation
    -- Preserve the freshly created object's input defaults. Buttons and edit
    -- boxes rely on these even when their constructors only install scripts.
    record.mouseEnabled = InputDefault(object, 'IsMouseEnabled',
        kind == 'Button' or kind == 'CheckButton' or kind == 'Slider' or kind == 'EditBox')
    record.keyboardEnabled = InputDefault(object, 'IsKeyboardEnabled', kind == 'EditBox')
    record.wheelEnabled = InputDefault(object, 'IsMouseWheelEnabled', false)
    P.records[object] = record
    return record
end

local function ClearScripts(record)
    if record.nativeSetScript then
        for event in pairs(record.dispatch) do record.nativeSetScript(record.object, event, nil) end
    end
    record.scripts, record.hooks = {}, {}
end

local function ClearText(object)
    -- Fresh untemplated FontStrings/EditBoxes have no font yet. Their
    -- constructors assign it after acquisition; even SetText('') can fail
    -- before then. Reused text is cleared once a font has been assigned.
    if object.GetFont and object:GetFont() then object:SetText('') end
end

local function ResetVisual(record)
    local object, kind = record.object, record.kind
    Call(object, 'ClearAllPoints')
    Call(object, 'SetAlpha', 1)
    if kind == 'AnimationGroup' then
        Call(object, 'Stop')
        Call(object, 'SetLooping', 'NONE')
        return
    elseif kind == 'Animation' then
        Call(object, 'SetStartDelay', 0)
        Call(object, 'SetEndDelay', 0)
        return
    end
    Call(object, 'SetWidth', 0)
    Call(object, 'SetHeight', 0)
    if kind == 'Texture' then
        Call(object, 'SetTexture', nil)
        Call(object, 'SetVertexColor', 1, 1, 1, 1)
        Call(object, 'SetTexCoord', 0, 1, 0, 1)
        Call(object, 'SetBlendMode', 'BLEND')
        Call(object, 'SetDesaturated', false)
    elseif kind == 'FontString' then
        ClearText(object)
        Call(object, 'SetTextColor', 1, 1, 1, 1)
        Call(object, 'SetJustifyH', 'CENTER')
        Call(object, 'SetJustifyV', 'MIDDLE')
        Call(object, 'SetWordWrap', true)
        Call(object, 'SetNonSpaceWrap', false)
        Call(object, 'SetSpacing', 0)
        Call(object, 'SetShadowOffset', 0, 0)
    else
        Call(object, 'SetScale', 1)
        Call(object, 'SetBackdrop', nil)
        Call(object, 'EnableMouse', record.mouseEnabled)
        Call(object, 'EnableMouseWheel', record.wheelEnabled)
        Call(object, 'EnableKeyboard', record.keyboardEnabled)
        Call(object, 'SetClipsChildren', false)
        Call(object, 'SetHitRectInsets', 0, 0, 0, 0)
        if kind == 'Button' or kind == 'CheckButton' then
            Call(object, 'Enable')
            Call(object, 'SetButtonState', 'NORMAL')
            Call(object, 'RegisterForClicks', 'LeftButtonUp')
        elseif kind == 'EditBox' then
            ClearText(object)
            Call(object, 'SetAutoFocus', false)
            Call(object, 'SetTextInsets', 0, 0, 0, 0)
        elseif kind == 'ScrollFrame' then
            Call(object, 'SetScrollChild', nil)
            Call(object, 'SetVerticalScroll', 0)
            Call(object, 'SetHorizontalScroll', 0)
        elseif kind == 'Cooldown' then
            Call(object, 'SetCooldown', 0, 0)
        elseif kind == 'PlayerModel' then
            Call(object, 'ClearModel')
        end
    end
end

-- Regions and animations stay with their frame. Re-run constructors using the
-- same slots, so re-binding text, data and closures never allocates new regions.
InstallParts = function(record)
    local object = record.object
    local function Part(slot, native, kind, name, layer, template, sublevel)
        local index = (record.cursors[slot] or 0) + 1
        record.cursors[slot] = index
        local list = record.parts[slot] or {}
        record.parts[slot] = list
        local part = list[index]
        if not part then
            local child
            if kind == 'Animation' then child = native(object, name)
            elseif slot == 'group' then child = native(object)
            else child = native(object, name, layer, template, sublevel) end
            part = Record(child, kind)
            list[index] = part
        end
        Prepare(part)
        if layer then Call(part.object, 'SetDrawLayer', layer, sublevel or 0) end
        if kind == 'FontString' and template then Call(part.object, 'SetFontObject', template) end
        if kind == 'Texture' or kind == 'FontString' then part.object:Show() end
        return part.object
    end
    if record.nativeTexture then
        object.CreateTexture = function(_, name, layer, template, sublevel)
            return Part('texture', record.nativeTexture, 'Texture', name, layer or 'ARTWORK', template, sublevel)
        end
    end
    if record.nativeFont then
        object.CreateFontString = function(_, name, layer, template)
            return Part('font', record.nativeFont, 'FontString', name, layer or 'OVERLAY', template)
        end
    end
    if record.nativeGroup then
        object.CreateAnimationGroup = function() return Part('group', record.nativeGroup, 'AnimationGroup') end
    end
    if record.nativeAnimation then
        object.CreateAnimation = function(_, kind)
            return Part('animation:' .. kind, record.nativeAnimation, 'Animation', kind)
        end
    end
end

ResetParts = function(record)
    for _, list in pairs(record.parts) do
        for _, part in ipairs(list) do
            ClearScripts(part)
            ResetParts(part)
            Call(part.object, 'Stop')
            Call(part.object, 'Hide')
            part.active = false
            ClearFields(part)
        end
    end
    record.cursors = {}
end

Prepare = function(record)
    ClearScripts(record)
    ClearFields(record)
    record.generation = record.generation + 1
    record.active = true
    record.cursors = {}
    ResetVisual(record)
    InstallScripts(record)
    InstallParts(record)
end

function P:Own(owner, object)
    local record = self.records[object]
    if not record then return object end
    if record.owner and self.children[record.owner] then self.children[record.owner][object] = nil end
    local previous = record.owner and self.childOrder[record.owner]
    if previous then
        for i = #previous, 1, -1 do
            if previous[i] == object then table.remove(previous, i); break end
        end
    end
    record.owner = owner
    if owner then
        self.children[owner] = self.children[owner] or {}
        self.children[owner][object] = true
        self.childOrder[owner] = self.childOrder[owner] or {}
        table.insert(self.childOrder[owner], object)
    end
    return object
end

function P:OnRelease(object, callback)
    local record = self.records[object]
    if record then
        record.cleanup = record.cleanup or {}
        record.cleanup[#record.cleanup + 1] = callback
    end
end

-- Dot-call factory; the fifth argument is private, never passed to WoW.
function P.CreateFrame(kind, name, parent, template, role, owner)
    if name or not role then return createFrame(kind, name, parent, template) end
    local key = role .. ':' .. kind .. ':' .. (template or '')
    local list = P.free[key]
    local object = list and table.remove(list)
    local record
    if object then
        record = P.records[object]
    else
        object = createFrame(kind, nil, parent, template)
        record = Record(object, kind)
        record.key = key
    end
    -- Hide before clearing callbacks; this also prevents focus/OnShow during bind.
    object:Hide()
    Prepare(record)
    object:SetParent(parent)
    if parent then
        Call(object, 'SetFrameStrata', parent:GetFrameStrata())
        Call(object, 'SetFrameLevel', (parent:GetFrameLevel() or 0) + 1)
    end
    P:Own(owner or parent, object)
    object:Show()
    return object
end

function P:ReleaseChildren(owner)
    -- Reverse construction order pairs with LIFO acquisition: roles used by
    -- several differently sized rows get their previous region capacity back.
    local order = self.childOrder[owner]
    while order and #order > 0 do self:Release(order[#order]) end
    self.children[owner] = nil
    self.childOrder[owner] = nil
end

function P:Release(object)
    if not object then return end
    local record = self.records[object]
    if not record then return end -- never touch foreign objects
    if not record.active or record.releasing then return end
    record.releasing = true
    self.pending[object] = nil
    -- OnHide cleanup still sees the previous binding, including floating inputs.
    object:Hide()
    Call(object, 'ClearFocus')
    if record.cleanup then
        local callbacks = record.cleanup
        record.cleanup = nil
        for i = 1, #callbacks do callbacks[i](object) end
    end
    self:ReleaseChildren(object)
    ClearScripts(record)
    Call(object, 'UnregisterAllEvents')
    ResetParts(record)
    Call(object, 'StopAnimating')
    if record.kind == 'ScrollFrame' then Call(object, 'SetScrollChild', nil) end
    object:ClearAllPoints()
    object:SetParent(nil)
    self:Own(nil, object)
    record.active = false
    record.generation = record.generation + 1
    ClearFields(record) -- drop option trees, callbacks and widget-specific flags
    record.releasing = nil
    self.free[record.key] = self.free[record.key] or {}
    table.insert(self.free[record.key], object)
end

-- Preview registries must not retain an object after its lease was returned.
function P:TrackPreview(bucket, host)
    table.insert(bucket._instances, host)
    self:OnRelease(host, function()
        for i = #bucket._instances, 1, -1 do
            if bucket._instances[i] == host then table.remove(bucket._instances, i) end
        end
    end)
end

function P:ClearPreviews(bucket)
    local instances = bucket._instances
    bucket._instances = {}
    for i = #instances, 1, -1 do
        local host = instances[i]
        self:Release(host.spacer or host)
    end
end

-- One driver for cancellable delayed layout/selection work, not one frame/click.
function P:After(owner, key, frames, callback)
    local tasks = self.pending[owner] or {}
    self.pending[owner] = tasks
    tasks[key] = { frames = frames, callback = callback }
    if not self.driver then self.driver = createFrame('Frame') end
    self.driver:SetScript('OnUpdate', function(driver)
        local due = {}
        for taskOwner, list in pairs(P.pending) do
            for taskKey, task in pairs(list) do
                task.frames = task.frames - 1
                if task.frames <= 0 then
                    list[taskKey] = nil
                    local record = P.records[taskOwner]
                    due[#due + 1] = { callback = task.callback, record = record,
                        generation = record and record.generation }
                end
            end
            if not next(list) then P.pending[taskOwner] = nil end
        end
        for i = 1, #due do
            local task = due[i]
            if not task.record or (task.record.active and task.record.generation == task.generation) then
                task.callback()
            end
        end
        if not next(P.pending) then driver:SetScript('OnUpdate', nil); driver:Hide() end
    end)
    self.driver:Show()
end
