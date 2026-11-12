-- Native addon_management ownership; legacy storage keys remain stable.
local owner = SarychUI.modules.addon_management

local function EnsureDb()
	if not (SarychUI and SarychUI.db and SarychUI.db.profile) then
		return nil
	end
	local addons = SarychUI.db.profile.addons
	if not addons then
		return nil
	end
	if addons.ACP and addons.AddonList == nil then
		addons.AddonList = { enabled = addons.ACP.enabled ~= false }
	end
	if not addons.AddonList then
		addons.AddonList = { enabled = true }
	end
	return addons.AddonList
end

local function SetGameMenuButtonVisible(visible)
	local btn = _G.GameMenuButtonAddons
	local menu = _G.GameMenuFrame
	if not btn or not menu then
		return
	end
	local heightDelta = btn._sarychMenuHeight or (btn:GetHeight() + 16)
	if visible then
		if not btn:IsShown() then
			btn:Show()
			menu:SetHeight(menu:GetHeight() + heightDelta)
		end
	else
		if btn:IsShown() then
			btn:Hide()
			menu:SetHeight(math.max(menu:GetHeight() - heightDelta, 1))
		end
	end
end

function owner:IsAddonListEnabled()
    EnsureDb()
    local profile = SarychUI.db and SarychUI.db.profile
    local cfg = profile and profile.addons and profile.addons.AddonList
    return cfg and cfg.enabled ~= false or false
end

function owner:IsAddonListRunning()
    return self.AddonListRunning == true
end

function owner:SetAddonListEnabled(enable)
    local profile = SarychUI.db.profile
    profile.addons.AddonList = profile.addons.AddonList or {}
    profile.addons.AddonList.enabled = enable and true or false
    return self:ApplyAddonList()
end

function owner:ApplyAddonList(forceOff)
    local cfg = SarychUI.db.profile.modules.addon_management
    local enable = not forceOff and (not cfg or cfg.enabled ~= false) and self:IsAddonListEnabled()
    AddonListEnabled = enable and true or false
    local running = false
    local db = EnsureDb()
    SetGameMenuButtonVisible(enable)
    if not enable and _G.AddonList then HideUIPanel(_G.AddonList) end
    running = enable and _G.AddonList ~= nil
    self.AddonListRunning = running and true or false
    return self.AddonListRunning
end

function owner:GetAddonListOptions()
	return {
		type = "group",
		name = "AddonList",
		order = 3,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить Addon List (список модификаций в игровом меню)",
				order = 1,
				get = function()
					return owner:IsAddonListEnabled()
				end,
				set = function(_, value)
					owner:SetAddonListEnabled(value)
				end,
			},
		},
	}
end
