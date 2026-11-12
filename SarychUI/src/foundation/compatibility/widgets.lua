-- Explicit helpers for native 3.3.5 widgets; never patch shared metatables.
local _, private = ...
local C = private.Compat
local API = {}
C.Widgets = API
SarychUI.WidgetAPI = API -- Existing internal callers share the same implementation.
C.AtlasInfo = C.AtlasInfo or {}
C.Texture = {}
function API.SetShown(region, shown)
    if shown then region:Show() else region:Hide() end
end
-- Wrath buttons return 1/0; some compatible clients return true/false or 1/nil.
function API.IsEnabled(button)
    local enabled = button:IsEnabled()
    return enabled == 1 or enabled == true
end
function API.SetEnabled(button, enabled)
    if enabled then button:Enable() else button:Disable() end
end
function C.Texture.GetAtlasInfo(name)
    local entry = C.AtlasInfo[name]
    if not entry then return nil end
    return {width=entry[1], height=entry[2], leftTexCoord=entry[3], rightTexCoord=entry[4],
        topTexCoord=entry[5], bottomTexCoord=entry[6], tilesHorizontally=entry[7],
        tilesVertically=entry[8], filename=entry[9]}
end
function API.SetAtlas(texture, name, useAtlasSize)
    local entry = C.AtlasInfo[name]
    if not entry then return false end
    texture:SetTexture(entry[9], entry[7], entry[8])
    texture:SetTexCoord(entry[3], entry[4], entry[5], entry[6])
    texture:SetHorizTile(entry[7]); texture:SetVertTile(entry[8])
    if useAtlasSize then texture:SetWidth(entry[1]); texture:SetHeight(entry[2]) end
    return true
end
function API.SetStatusBarAtlas(bar, name)
    local entry = C.AtlasInfo[name]
    if not entry then return false end
    bar:SetStatusBarTexture(entry[9])
    return API.SetAtlas(bar:GetStatusBarTexture(), name, false)
end
