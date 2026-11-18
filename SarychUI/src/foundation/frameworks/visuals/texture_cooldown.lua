-- Texture-only cooldowns for moving nameplates (WoW 3.3.5).
-- PlateBuffs' padded 30x30 atlas avoids the native Cooldown model's depth flicker.
SarychUI.TextureCooldown = {}
local Cooldown = SarychUI.TextureCooldown
local floor, min, max = math.floor, math.min, math.max
local ATLAS = "Interface\\AddOns\\SarychUI\\media\\cooldown\\square-swirl-edge"
local active = {}
local driver = CreateFrame("Frame")
driver:Hide()

local function EnsureLayer(region, layer)
    if region:GetDrawLayer() ~= layer then region:SetDrawLayer(layer) end
end

local function Suspend(frame)
    local state = frame.__suiTextureCooldown
    if state then
        state.darken:Hide()
        state.shade:Hide()
    end
    active[frame] = nil
    if not next(active) then driver:Hide() end
end

function Cooldown.Clear(frame)
    if not frame then return end
    Suspend(frame)
    local state = frame.__suiTextureCooldown
    if state then
        state.expirationTime = nil
        state.duration = nil
    end
end

local function Paint(frame, now)
    local state = frame.__suiTextureCooldown
    if not state.icon:IsShown() or now >= state.expirationTime then
        Cooldown.Clear(frame)
        return
    end
    if not frame:IsVisible() then
        Suspend(frame)
        return
    end
    -- Use distinct native layers, not texture sublevels within ARTWORK. The
    -- order must also hold on the base 3.3.5 client without AwesomeWotlk.
    -- Reconcile reused/reskinned icons even when their texture object is unchanged.
    EnsureLayer(state.icon, "BACKGROUND")
    EnsureLayer(state.darken, "BORDER")
    EnsureLayer(state.shade, "ARTWORK")
    local progress = min(1, max(0, 1 - (state.expirationTime - now) / state.duration))
    local index = floor(progress * 899)
    if index ~= state.index then
        local left = ((index % 30) * 34 + 1) / 1024
        local top = (floor(index / 30) * 34 + 1) / 1024
        state.shade:SetTexCoord(left, left + 32 / 1024, top, top + 32 / 1024)
        state.darken:SetTexCoord(left, left + 32 / 1024, top, top + 32 / 1024)
        state.index = index
    end
    if not state.darken:IsShown() then state.darken:Show() end
    if not state.shade:IsShown() then state.shade:Show() end
end

function Cooldown.Set(frame, icon, expirationTime, duration, enabled)
    if not icon or not enabled
        or not duration or duration <= 0 or not expirationTime or expirationTime <= GetTime() then
        Cooldown.Clear(frame)
        return
    end
    local state = frame.__suiTextureCooldown
    if not state then
        state = {
            darken = frame:CreateTexture(nil, "BORDER"),
            shade = frame:CreateTexture(nil, "ARTWORK"),
        }
        frame.__suiTextureCooldown = state
        -- The atlas shade is 50% opaque. A black underlay raises it to 60%
        -- while the original opaque sweep edge keeps its color.
        state.darken:SetTexture(ATLAS)
        state.darken:SetVertexColor(0, 0, 0, 0.4)
        state.darken:Hide()
        state.shade:SetTexture(ATLAS)
        state.shade:SetVertexColor(1, 1, 1, 1)
        frame:HookScript("OnHide", Suspend)
        frame:HookScript("OnShow", function(self)
            local saved = self.__suiTextureCooldown
            if saved.expirationTime then
                Cooldown.Set(self, saved.icon, saved.expirationTime, saved.duration, true)
            end
        end)
    end
    if state.icon ~= icon then
        -- All three regions share the icon's host, scale and depth. Timer/stack
        -- text and glow borders remain on OVERLAY above the cooldown.
        state.darken:ClearAllPoints()
        state.darken:Hide()
        state.shade:ClearAllPoints()
        state.index = nil
        state.darken:SetAllPoints(icon)
        state.shade:SetAllPoints(icon)
        state.icon = icon
    end
    state.expirationTime, state.duration = expirationTime, duration
    active[frame] = true
    driver:Show()
    Paint(frame, GetTime())
end

-- One animation driver, independent of the slower numeric countdown updates.
driver:SetScript("OnUpdate", function()
    local now = GetTime()
    for frame in pairs(active) do Paint(frame, now) end
end)
