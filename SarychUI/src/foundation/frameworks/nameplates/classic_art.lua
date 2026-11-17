-- Stable native artwork roles, independent of its current rendering parents.
local Art = {}
SarychUI.ClassicNameplateArt = Art
local viewMethods = {}
function viewMethods:GetChildren() return unpack(self.children) end
function viewMethods:GetRegions() return unpack(self.regions) end
local viewMeta = {__index=viewMethods}

function Art:Capture(root)
    if not root._suiClassicArt then
        root._suiClassicArt = setmetatable({children={root:GetChildren()}, regions={root:GetRegions()}}, viewMeta)
    end
    return root._suiClassicArt
end

-- Move only suppressed artwork into an alpha-zero parent. Native Show/alpha
-- writes on its children cannot reveal HP between Lua update callbacks.
-- The cast bar, its anchors, and external aura/distance overlays stay untouched.
function Art:ApplyMask(root, state)
    local host = state.host
    local mask = state.maskHost
    if not mask then
        mask = CreateFrame("Frame", nil, host)
        mask._suiClassicRoot = root
        mask:EnableMouse(false)
        mask:SetAlpha(0)
        mask:SetAllPoints(host)
        state.maskHost = mask
    end
    if mask:GetParent() ~= host then mask:SetParent(host); mask:SetAllPoints(host) end
    if mask:GetFrameLevel() ~= host:GetFrameLevel() then mask:SetFrameLevel(host:GetFrameLevel()) end
    state.masked = state.masked or {}
    for _, region in ipairs(host.regions or {}) do
        if not (host.castParts and host.castParts[region]) and not region._suiPlateAura then
            if not state.masked[region] then
                state.masked[region] = {alpha=region:GetAlpha(), parent=region:GetParent(),
                    level=region.GetFrameLevel and region:GetFrameLevel()}
            end
            if region:GetParent() ~= mask then
                region:SetParent(mask)
                local level = state.masked[region].level
                if level then region:SetFrameLevel(level) end
            end
            if region:GetAlpha() ~= 0 then region:SetAlpha(0) end
        end
    end
    if host:GetAlpha() ~= state.alpha then host:SetAlpha(state.alpha) end
end

function Art:RestoreMask(state)
    if not state.masked then return end
    for region, saved in pairs(state.masked) do
        if region:GetParent() == state.maskHost then
            region:SetParent(saved.parent)
            if saved.level then region:SetFrameLevel(saved.level) end
        end
        region:SetAlpha(saved.alpha)
    end
    state.masked = nil
end

local function XFraction(point)
    if point:find("LEFT", 1, true) then return -.5 end
    if point:find("RIGHT", 1, true) then return .5 end
    return 0
end

local function EffectiveScale(region)
    -- Texture/FontString anchors inherit their parent Frame's scale and do
    -- not expose GetEffectiveScale in the legacy client.
    for i = 1, 8 do
        if not region then return end
        if region.GetEffectiveScale then return region:GetEffectiveScale() end
        region = region.GetParent and region:GetParent()
    end
end

local function RelativeX(frame, root, depth)
    if frame == root then return 0 end
    if not frame or depth == 0 or not frame.GetPoint or not frame.GetWidth then return end
    local point, relative, relativePoint, x = frame:GetPoint(1)
    if not point then return end
    relative = relative or frame:GetParent()
    if not relative or not relative.GetWidth then return end
    local base = RelativeX(relative, root, depth - 1)
    if base == nil then return end
    local scale, relativeScale = EffectiveScale(frame), EffectiveScale(relative)
    if not scale or not relativeScale then return end
    return base + XFraction(relativePoint or point) * relative:GetWidth() * relativeScale
        + ((x or 0) - XFraction(point) * frame:GetWidth()) * scale
end

function Art:HorizontalOffset(frame, root)
    -- Solve the anchor chain in local space, not two asynchronously updated
    -- screen centers. Movement of the whole nameplate must not shift its icon.
    return RelativeX(frame, root, 8)
end
