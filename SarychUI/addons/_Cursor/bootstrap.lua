-- _Cursor bootstrap for SarychUI embedding.
-- Note: this WoW client has no loadfile — core stays in TOC.
-- Valve is runtime: effects + Blizzard options only after AceDB says enabled.

_CursorEnabled = false

function SarychUI_IsStandaloneCursorEnabled()
	if not GetNumAddOns or not GetAddOnInfo then
		return false
	end
	for i = 1, GetNumAddOns() do
		local name, _, _, enabled, loadable, reason = GetAddOnInfo(i)
		if name == "_Cursor" and reason ~= "MISSING" and enabled and loadable then
			return true
		end
	end
	return false
end

function SarychUI_IsCursorCoreLoaded()
	return _G._Cursor ~= nil and type(_G._Cursor.Update) == "function"
end

function SarychUI_ApplyCursorRuntime(enable)
	_CursorEnabled = enable and true or false
	local frame = _G._Cursor
	if not frame then
		return
	end
	if not enable then
		frame:Hide()
		frame:SetScript("OnUpdate", nil)
		if frame.ModelDisable and frame.ModelsUsed then
			for model in pairs(frame.ModelsUsed) do
				frame.ModelDisable(model)
			end
		end
	elseif frame.OnUpdate then
		frame:SetScript("OnUpdate", frame.OnUpdate)
		if frame.Update then
			frame:Update()
		end
		if frame.BlockRemove then
			frame.BlockRemove("EmbeddedDisabled")
		end
		if not frame:IsShown() then
			frame:Show()
		end
	end
end

function SarychUI_RegisterCursorInterfaceOptions()
	local options = _G._Cursor and _G._Cursor.Options
	if not options then
		return false
	end
	if options.RegisterInterfaceOptions then
		options.RegisterInterfaceOptions()
		return true
	end
	if not options._suiRegistered and InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(options)
		options._suiRegistered = true
	end
	return options._suiRegistered and true or false
end

function SarychUI_InitEmbeddedCursor()
	if not SarychUI_IsCursorCoreLoaded() then
		return false, "not_loaded"
	end

	local frame = _G._Cursor
	if frame and frame.ADDON_LOADED then
		-- SV already applied; finish setup if event handler still pending.
		frame:ADDON_LOADED("ADDON_LOADED", "_Cursor")
	elseif frame then
		if frame.Update then
			frame:Update()
		end
		if frame.Options and frame.Options.Update then
			frame.Options.Update()
		end
	end

	SarychUI_RegisterCursorInterfaceOptions()
	_G._CursorEmbeddedInitialized = true
	return true, "loaded"
end
