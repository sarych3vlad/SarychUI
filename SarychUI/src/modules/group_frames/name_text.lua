-- Only the name FontString is styled here. Header castbars keep native metrics.
local module = SarychUI.modules.group_frames
local frames = setmetatable({}, {__mode = "k"})
local measure

function module:GetNameFontSize()
    local db = SarychUI.db and SarychUI.db.profile.modules.group_frames
    if not db or not db.nameFontSizeEnabled then return 10 end
    return math.max(6, math.min(24, tonumber(db and db.nameFontSize) or 10))
end

local function FitText(text, width, font, size, flags)
    if width <= 0 then return "" end
    if not measure then
        measure = UIParent:CreateFontString(nil, "OVERLAY")
        measure:Hide()
        measure:SetWordWrap(false)
        measure:SetWidth(0)
        measure:SetHeight(0)
    end
    measure:SetFont(font, size, flags)
    measure:SetText(text)
    if measure:GetStringWidth() <= width then return text end
    local suffix = "..."
    measure:SetText(suffix)
    if measure:GetStringWidth() > width then
        -- At minimum frame width even the ellipsis may need fewer dots.
        repeat
            suffix = suffix:sub(2)
            measure:SetText(suffix)
        until suffix == "" or measure:GetStringWidth() <= width
        return suffix
    end
    -- Search by UTF-8 character boundaries; byte slicing alone breaks Cyrillic.
    local ends, offset = {0}, 0
    for character in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        offset = offset + #character
        ends[#ends + 1] = offset
    end
    local low, high = 1, #ends
    while low < high do
        local middle = math.floor((low + high + 1) / 2)
        measure:SetText(text:sub(1, ends[middle]) .. suffix)
        if measure:GetStringWidth() <= width then low = middle else high = middle - 1 end
    end
    return text:sub(1, ends[low]) .. suffix
end

function module:SetNameText(frame, text)
    local name = frame.name or (frame.overlay and frame.overlay.name)
    if not name then return end
    local state = frames[frame]
    if not state then
        state = {}
        frames[frame] = state
        frame:HookScript("OnSizeChanged", function(self)
            module:SetNameText(self)
        end)
        frame:HookScript("OnShow", function(self)
            module:SetNameText(self)
        end)
    end
    text = text or state.fullText or name:GetText() or ""
    state.fullText = text
    local frameWidth = frame:GetWidth()
    if not frameWidth or frameWidth <= 0 then
        -- Layout has not run yet. Keep the source until OnShow/OnSizeChanged;
        -- never cache an empty fitted name just because geometry is unavailable.
        name:SetText(text)
        state.text = nil
        return
    end
    local font, oldSize, flags = name:GetFont()
    if not font then return end
    -- Keep even the tallest name inside a short frame without scaling the frame.
    local size = math.min(self:GetNameFontSize(), math.max(6, frame:GetHeight() - 6))
    if oldSize ~= size then name:SetFont(font, size, flags) end
    name:SetWordWrap(false)
    if name.SetNonSpaceWrap then name:SetNonSpaceWrap(false) end
    name:SetHeight(size + 2)
    -- A FontString's GetWidth can describe its current text, including zero for
    -- a new/cleared string. Allocate from the frame, not from the text being fit.
    -- Insets match CompactUnitFrame's health-bar border and name/role anchors.
    local available
    name:ClearAllPoints()
    if frame._suiMiniName then
        available = frameWidth - 10
        name:SetPoint("LEFT", frame, "LEFT", 6, 1)
    else
        local roleWidth = frame.roleIcon and frame.roleIcon:GetWidth() or 12
        available = frameWidth - roleWidth - 8
        name:SetPoint("TOPLEFT", frame, "TOPLEFT", roleWidth + 4, -4)
    end
    name:SetWidth(math.max(1, available))
    local width = math.max(0, available - 1)
    if state.text ~= text or state.width ~= width or state.size ~= size
        or state.font ~= font or state.flags ~= flags then
        state.fitted = FitText(text, width, font, size, flags)
        state.text, state.width, state.size, state.font, state.flags = text, width, size, font, flags
    end
    if name:GetText() ~= state.fitted then name:SetText(state.fitted) end
end

function module:RefreshNameTexts()
    for frame in pairs(frames) do self:SetNameText(frame) end
end
