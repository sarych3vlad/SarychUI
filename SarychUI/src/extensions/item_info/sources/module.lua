-- A view/catalog component of equipment information, not an addon owner.
local owner = SarychUI.modules.item_info
local sources = {enabled = false}
owner.Sources = sources

function sources:Enable()
    if GetAddOnInfo then
        local _, _, _, enabled, loadable = GetAddOnInfo("InspectEquip")
        if enabled and loadable then
            self:Disable()
            owner:GetDB().sources.enabled = false
            SarychUI:Print(SarychUI:T("ui.inspectequip.standalone"))
            return
        end
    end
    if self.enabled then self:Refresh(); return end
    self:InitializeSources()
    self:GetItemNames()
    self.enabled = true
    self:Start()
end

function sources:Disable()
    self.enabled = false
    self:Stop()
end
