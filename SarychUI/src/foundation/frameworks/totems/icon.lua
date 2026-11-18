-- Identical tick presentation for the arena widget and both nameplate renderers.
local Icon = {}
SarychUI.TremorIcon = Icon
local options = {
    arena = { periodic = true, compactUnits = true, context = "arena", decimalThreshold = 3 },
    nameplate = { periodic = true, compactUnits = true, context = "unitAuras", decimalThreshold = 3 },
}

function Icon:Create(parent, texture)
    local host = CreateFrame("Frame", nil, parent)
    host:SetAllPoints(parent)
    host:SetFrameLevel(parent:GetFrameLevel() + 2)
    host:EnableMouse(false)
    local view = { host = host, parent = parent, icon = texture }
    view.shade = host:CreateTexture(nil, "ARTWORK")
    view.shade:SetTexture(0, 0, 0, 0.7)
    view.shade:SetPoint("TOPLEFT", texture, "TOPLEFT")
    view.edge = host:CreateTexture(nil, "OVERLAY")
    view.edge:SetTexture(1, 1, 1, 0.65)
    view.edge:SetPoint("TOPLEFT", view.shade, "BOTTOMLEFT")
    view.procBorder = host:CreateTexture(nil, "OVERLAY")
    view.procBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    view.procBorder:SetBlendMode("ADD")
    view.procBorder:SetPoint("CENTER", texture, "CENTER")
    view.procBorder:SetVertexColor(1, 0.82, 0.28)
    view.text = host:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    view.text:SetFontObject(GameFontHighlightSmall)
    view.text:SetJustifyH("CENTER")
    view.text:SetPoint("BOTTOM", texture, "TOP", 0, 3)
    host:Hide()
    return view
end

function Icon:Draw(view, origin, now, context)
    local duration = 3
    local start = origin + math.floor(math.max(0, now - origin) / duration) * duration
    local left = math.max(0, start + duration - now)
    local width, height = view.parent:GetWidth(), view.parent:GetHeight()
    view.host:SetFrameLevel(view.parent:GetFrameLevel() + 2)
    view.shade:SetSize(width, math.max(0.001, height * math.min(1, left / duration)))
    view.edge:SetSize(width, 1)
    view.procBorder:SetSize(width * 48 / 26, height * 48 / 26)
    view.procBorder:SetAlpha(0.65 + 0.35 * math.cos((now - start) / duration * 2 * math.pi))
    view.text:SetFontObject(GameFontHighlightSmall)
    local cc = SarychUI.modules.cc
    if cc and cc.UpdateTimerText then
        cc:UpdateTimerText(view.text, left, duration, view.parent, true, options[context] or options.nameplate)
    else view.text:Hide() end
    view.host:Show()
end

function Icon:Hide(view)
    if view then view.text:Hide(); view.host:Hide() end
end
