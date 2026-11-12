-- Private WoW 3.3.5 timer service. Loaded before libraries.
local _, private = ...
private.Compat = private.Compat or {}
local Timer = {}
private.Compat.Timer = Timer
local driver = CreateFrame("Frame")
driver:Hide()
local pending, count = {}, 0
local methods = {}
methods.__index = methods

local function idle()
    if count == 0 then
        driver:SetScript("OnUpdate", nil)
        driver:Hide()
    end
end

function methods:Cancel()
    local entry = self._entry
    if not entry then return end
    self._entry = nil
    if pending[entry] then
        pending[entry] = nil
        count = count - 1
    end
    entry.callback = nil
    idle()
end

function methods:IsCancelled()
    return self._entry == nil
end

local function update()
    local now = GetTime()
    local due
    -- Snapshot: callbacks may cancel siblings or schedule more timers.
    for entry in pairs(pending) do
        if now >= entry.deadline then
            due = due or {}
            due[#due + 1] = entry
        end
    end
    if not due then return end
    for i = 1, #due do
        local entry = due[i]
        if pending[entry] then
            local ok, err = pcall(entry.callback, entry.handle)
            if not ok then
                local handler = geterrorhandler and geterrorhandler()
                if handler then pcall(handler, err) end
            end
            if pending[entry] then
                if entry.remaining == 1 then
                    if entry.handle then
                        entry.handle:Cancel()
                    else
                        pending[entry] = nil
                        count = count - 1
                        entry.callback = nil
                    end
                else
                    if entry.remaining then entry.remaining = entry.remaining - 1 end
                    entry.deadline = GetTime() + entry.interval
                end
            end
        end
    end
    idle()
end

local function create(duration, callback, iterations, cancellable)
    assert(type(duration) == "number" and duration == duration
        and duration > -math.huge and duration < math.huge,
        "Timer duration must be a finite number")
    assert(type(callback) == "function", "Timer callback must be a function")
    assert(iterations == nil or (type(iterations) == "number" and iterations >= 1
        and iterations < math.huge and iterations == math.floor(iterations)),
        "Timer iterations must be a positive integer")
    duration = math.max(0.01, duration)
    local entry = { callback = callback, interval = duration,
        deadline = GetTime() + duration, remaining = iterations }
    if cancellable then
        entry.handle = setmetatable({ _entry = entry }, methods)
    end
    pending[entry] = true
    count = count + 1
    driver:SetScript("OnUpdate", update)
    driver:Show()
    return entry.handle
end

function Timer.After(duration, callback, extra)
    if type(duration) ~= "number" then duration, callback = callback, extra end
    create(duration, callback, 1, false)
end

function Timer.NewTimer(duration, callback, extra)
    if type(duration) ~= "number" then duration, callback = callback, extra end
    return create(duration, callback, 1, true)
end

function Timer.NewTicker(duration, callback, iterations, extra)
    if type(duration) ~= "number" then duration, callback, iterations = callback, iterations, extra end
    return create(duration, callback, iterations, true)
end
