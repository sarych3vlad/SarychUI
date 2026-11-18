-- Overlay visibility follows display policy, never the alpha of a hidden
-- health bar: icon-only and name-only plates still have visible overlays.
local Visibility = {}
SarychUI.NameplateVisibility = Visibility

function Visibility:IsHidden(root)
    if not root then return true end
    if root.IsShown and not root:IsShown() then return true end
    if root._suiPetHidden or root._suiTotemHidden then return true end
    local frame = root.UnitFrame
    return frame and (frame.VisibilityChanged or frame._suiPetAction == "hide"
        or frame._suiTotemAction == "hide" or (frame.IsShown and not frame:IsShown())) or false
end

function Visibility:SetHidden(root, kind, hidden)
    local key = kind == "totem" and "_suiTotemHidden" or "_suiPetHidden"
    hidden = hidden and true or nil
    if root[key] == hidden then return end
    root[key] = hidden
    if hidden and _G.sarPlatesAuras_HidePlateAuras then
        _G.sarPlatesAuras_HidePlateAuras(root)
    end
    if _G.Autolos and _G.Autolos.RefreshNameplate then
        _G.Autolos.RefreshNameplate(root, {layoutOnly=true})
    end
end
