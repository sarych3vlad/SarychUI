-- SarychUI options widgets: owner-scoped dropdown label sync only (no global visual changes).

local FALLBACK_SELECT_LABEL = "Не выбрано"

local function IsOwnedDropdownWidget(widget)
	if not widget or not widget.frame then
		return false
	end
	return SarychUI:IsSarychUIOwned(widget.frame)
end

local function NormalizeOptionKeys(key)
	if key == nil then
		return nil, nil
	end
	local keyType = type(key)
	if keyType == "number" then
		return key, tostring(key)
	end
	if keyType == "string" then
		local asNumber = tonumber(key)
		return key, asNumber
	end
	return key, key
end

local function FindOptionLabel(list, value)
	if not list or value == nil then
		return nil, nil
	end
	local primary, alternate = NormalizeOptionKeys(value)
	if primary ~= nil and list[primary] ~= nil then
		return list[primary], primary
	end
	if alternate ~= nil and list[alternate] ~= nil then
		return list[alternate], alternate
	end
	for optionKey, label in pairs(list) do
		if tostring(optionKey) == tostring(value) then
			return label, optionKey
		end
	end
	return nil, nil
end

local function GetFirstOptionLabel(list)
	if not list then
		return nil, nil
	end
	local keys = {}
	for key in pairs(list) do
		keys[#keys + 1] = key
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	if keys[1] == nil then
		return nil, nil
	end
	return list[keys[1]], keys[1]
end

function SarychUI:ResolveSelectOptionLabel(list, value, defaultValue)
	if not list or not next(list) then
		return FALLBACK_SELECT_LABEL, nil
	end

	local label, resolvedKey = FindOptionLabel(list, value)
	if label ~= nil then
		return label, resolvedKey
	end

	if defaultValue ~= nil then
		label, resolvedKey = FindOptionLabel(list, defaultValue)
		if label ~= nil then
			return label, resolvedKey
		end
	end

	label, resolvedKey = GetFirstOptionLabel(list)
	if label ~= nil then
		return label, resolvedKey
	end
	return FALLBACK_SELECT_LABEL, nil
end

function SarychUI:UpdateSelectDisplay(dropdown, value, list, defaultValue)
	if not dropdown or not dropdown.SetText then
		return
	end
	if not IsOwnedDropdownWidget(dropdown) then
		return
	end
	local label, resolvedKey = self:ResolveSelectOptionLabel(list, value, defaultValue)
	dropdown:SetText(label or FALLBACK_SELECT_LABEL)
	if resolvedKey ~= nil then
		dropdown.value = resolvedKey
	end
end

local function SyncDropdownDisplay(widget)
	if not IsOwnedDropdownWidget(widget) then
		return
	end
	SarychUI:UpdateSelectDisplay(widget, widget.value, widget.list, widget._sarychDefaultValue)
end

local function EnsureDropdownOnShowHook(widget)
	if not widget or not widget.frame or not widget.frame.HookScript then
		return
	end
	if widget.frame._sarychDropdownOnShowHooked then
		return
	end
	widget.frame._sarychDropdownOnShowHooked = true
	widget.frame:HookScript("OnShow", function()
		if IsOwnedDropdownWidget(widget) then
			SyncDropdownDisplay(widget)
		end
	end)
end

function SarychUI:PatchOwnedDropdownDisplay(widget)
	return self:InstallOwnedDropdownDisplayPatch(widget)
end

function SarychUI:InstallOwnedDropdownDisplayPatch(widget)
	if not widget or widget._sarychDropdownDisplayPatched then
		return
	end
	if not IsOwnedDropdownWidget(widget) then
		return
	end
	widget._sarychDropdownDisplayPatched = true

	local originalSetValue = widget.SetValue
	widget.SetValue = function(self, value, defaultValue)
		if not IsOwnedDropdownWidget(self) then
			if originalSetValue then
				return originalSetValue(self, value)
			end
			self.value = value
			return
		end
		if defaultValue ~= nil then
			self._sarychDefaultValue = defaultValue
		end
		if originalSetValue then
			originalSetValue(self, value)
		else
			self.value = value
		end
		EnsureDropdownOnShowHook(self)
		SyncDropdownDisplay(self)
	end

	local originalSetList = widget.SetList
	widget.SetList = function(self, list)
		if not IsOwnedDropdownWidget(self) then
			if originalSetList then
				return originalSetList(self, list)
			end
			self.list = list
			return
		end
		if originalSetList then
			originalSetList(self, list)
		else
			self.list = list
		end
		EnsureDropdownOnShowHook(self)
		SyncDropdownDisplay(self)
	end

	EnsureDropdownOnShowHook(widget)
	SyncDropdownDisplay(widget)
end

function SarychUI:InstallAceGUIOptionsWidgetPatches()
	-- Patches are applied lazily via options_skin.lua AddChild dispatch.
end
