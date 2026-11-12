-- Portrait consumer of the same specialization service used by arena frames.
-- No private talent scanner, inspect queue, spec table or GUID cache here.
local Specs = {}
SarychUI.FrameSpecs = Specs
local watched = {"player", "target", "focus"}
local callbacks, displayed = {}, {}
local active = false
local driver = CreateFrame("Frame")
driver:Hide()

function Specs:Get(unit)
    local shared = SarychUI.UnitSpecialization
    if not shared or not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return nil end
    return shared:Get(unit)
end

function Specs:GetIcon(class, spec)
    local shared = SarychUI.UnitSpecialization
    return shared and shared:GetIcon(class, spec) or nil
end

function Specs:Request(unit)
    local shared = SarychUI.UnitSpecialization
    if active and shared and shared.RequestUnit then shared:RequestUnit(unit) end
end

function Specs:Register(fn)
    if type(fn) == "function" then callbacks[#callbacks + 1] = fn end
end

local function Refresh()
    for _, unit in ipairs(watched) do
        Specs:Request(unit)
        local guid = UnitGUID(unit)
        local spec, class = Specs:Get(unit)
        local icon = Specs:GetIcon(class, spec)
        local previous = displayed[unit]
        if not previous or previous.guid ~= guid or previous.spec ~= spec or previous.icon ~= icon then
            displayed[unit] = {guid = guid, spec = spec, icon = icon}
            if guid then for _, callback in ipairs(callbacks) do callback(guid) end end
        end
    end
end

function Specs:SetActive(value)
    value = not not value
    if active == value then return end
    active = value
    if active then
        driver:Show()
        Refresh()
    else
        driver:Hide()
        wipe(displayed)
    end
end

-- Refresh only visible spec styles; catches both asynchronous inspect results
-- and enemy spell clues without depending on the arena UI being enabled.
driver:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < 0.2 then return end
    self.elapsed = 0
    Refresh()
end)
