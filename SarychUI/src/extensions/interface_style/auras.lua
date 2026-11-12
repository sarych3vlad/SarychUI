local Style = SarychUI_InterfaceStyle
local auras = setmetatable({}, { __mode = "k" })

local function SaveRegion(region)
	if not region then return end
	local saved = { texture = region.GetTexture and region:GetTexture(),
		coords = region.GetTexCoord and { region:GetTexCoord() },
		color = region.GetVertexColor and { region:GetVertexColor() },
		alpha = region.GetAlpha and region:GetAlpha(),
		shown = region.IsShown and region:IsShown(), points = {} }
	if region.GetNumPoints then
		for i = 1, region:GetNumPoints() do saved.points[i] = { region:GetPoint(i) } end
	end
	return saved
end

local function RestoreRegion(region, saved)
	if not region or not saved then return end
	if saved.texture and region.SetTexture then region:SetTexture(saved.texture) end
	if saved.coords and region.SetTexCoord then region:SetTexCoord(unpack(saved.coords)) end
	if saved.color and region.SetVertexColor then region:SetVertexColor(unpack(saved.color)) end
	if saved.alpha and region.SetAlpha then region:SetAlpha(saved.alpha) end
	if saved.shown ~= nil then
		if saved.shown then region:Show() else region:Hide() end
	end
	if region.ClearAllPoints then
		region:ClearAllPoints()
		for _, point in ipairs(saved.points) do region:SetPoint(unpack(point)) end
	end
end

local function DebuffColor(region, state)
	local r, g, b, a = Style.GetColor()
	local black = Style:GetTextureMode() == "black"
	local value = black and Style:GetGlossBrightness() or 1
	local color = state.originalColor
	local alpha = black and a or (color[4] or 1)
	if Style:GetDebuffOriginalColor() then
		state.vertexSetter(region, color[1] or 1,
			color[2] or 1, color[3] or 1, alpha)
	else
		if black then
			state.vertexSetter(region, value, value, value, alpha)
		else
			state.vertexSetter(region, r, g, b, alpha)
		end
	end
end

local function BorderTexture(state)
	if state.isDebuff and Style:GetDebuffOriginalColor() then
		return Style.textures.debuffOriginal
	end
	return Style.textures.normal
end

function Style:StyleAuraButton(button)
	if not self.enabled or not button then return end
	local name = button.GetName and button:GetName()
	if not name or name:match("^Boss%d+TargetFrame") then return end
	local black = self:GetTextureMode() == "black"
	local icon = _G[name .. "Icon"]
	local isDebuff = name:find("Debuff", 1, true) ~= nil
		or name:find("TempEnchant", 1, true) ~= nil
	local border = _G[name .. "Border"]
	if not black and not border then return end
	local state = auras[button]
	if not state then
		state = { icon = icon, iconSaved = SaveRegion(icon),
			border = border, borderSaved = SaveRegion(border), created = not border,
			isDebuff = isDebuff, black = black }
		auras[button] = state
	end
	if black and icon then
		icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
		icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
	end
	if not border then
		border = state.border or button:CreateTexture(nil, "OVERLAY")
		state.border = border
	end
	if not state.vertexSetter then
		state.vertexSetter = border.SetVertexColor
		state.originalColor = { border:GetVertexColor() }
		if black then
			state.textureSetter = border.SetTexture
			border.SetTexture = function(region, path, ...)
				if path ~= Style.textures.normal and path ~= Style.textures.debuffOriginal then
					state.originalTexture = path
				end
				if Style.enabled and Style:GetTextureMode() == "black" then
					return state.textureSetter(region, BorderTexture(state), ...)
				end
				return state.textureSetter(region, path, ...)
			end
		end
		border.SetVertexColor = function(region, r, g, b, a)
			if Style.enabled then
				state.originalColor = { r, g, b, a or 1 }
				if state.isDebuff then
					return DebuffColor(region, state)
				end
				local sr, sg, sb, sa = Style.GetColor()
				if Style:GetTextureMode() == "black" then
					local value = Style:GetGlossBrightness()
					return state.vertexSetter(region, value, value, value, sa)
				end
				return state.vertexSetter(region, sr, sg, sb, sa)
			end
			return state.vertexSetter(region, r, g, b, a)
		end
	end
	if black then
		state.textureSetter(border, BorderTexture(state))
		border:SetTexCoord(0, 1, 0, 1)
		border:ClearAllPoints()
		border:SetAllPoints(button)
	end
	if isDebuff then
		DebuffColor(border, state)
	else
		local r, g, b, a = self.GetColor()
		if black then
			local value = self:GetGlossBrightness()
			state.vertexSetter(border, value, value, value, a)
		else
			state.vertexSetter(border, r, g, b, state.originalColor[4] or 1)
		end
	end
	if black then border:Show() end
end

function Style:ApplyAuras()
	if not self.enabled then return end
	local groups = {
		{ "BuffButton", 40 }, { "DebuffButton", 16 }, { "TempEnchant", 3 },
		{ "TargetFrameBuff", 32 }, { "TargetFrameDebuff", 16 },
		{ "FocusFrameBuff", 32 }, { "FocusFrameDebuff", 16 },
		{ "TargetFrameToTDebuff", 4 }, { "FocusFrameToTDebuff", 4 },
		{ "PetFrameDebuff", 4 },
	}
	for _, group in ipairs(groups) do
		for i = 1, group[2] do self:StyleAuraButton(_G[group[1] .. i]) end
	end
	for party = 1, 4 do
		for i = 1, 4 do self:StyleAuraButton(_G["PartyMemberFrame" .. party .. "Debuff" .. i]) end
	end
	if not self.auraHooksInstalled and hooksecurefunc then
		self.auraHooksInstalled = true
		if AuraButton_Update then
			hooksecurefunc("AuraButton_Update", function(prefix, index)
				if Style.enabled and prefix and index then
					Style:StyleAuraButton(_G[prefix .. index])
				end
			end)
		end
		if TargetFrame_UpdateAuras then
			hooksecurefunc("TargetFrame_UpdateAuras", function(frame)
				local name = frame and frame.GetName and frame:GetName()
				if Style.enabled and name and not name:match("^Boss%d+TargetFrame") then
					if name == "TargetFrame" or name == "FocusFrame" then
						for i = 1, 32 do Style:StyleAuraButton(_G[name .. "Buff" .. i]) end
						for i = 1, 16 do Style:StyleAuraButton(_G[name .. "Debuff" .. i]) end
					end
				end
			end)
		end
		if TargetofTarget_Update then
			hooksecurefunc("TargetofTarget_Update", function()
				if not Style.enabled then return end
				for _, prefix in ipairs({ "TargetFrameToTDebuff", "FocusFrameToTDebuff" }) do
					for i = 1, 4 do Style:StyleAuraButton(_G[prefix .. i]) end
				end
			end)
		end
		if RefreshDebuffs then
			hooksecurefunc("RefreshDebuffs", function(frame)
				local name = frame and frame.GetName and frame:GetName()
				if Style.enabled and name and not name:match("^Boss%d+TargetFrame") then
					for i = 1, 8 do Style:StyleAuraButton(_G[name .. "Debuff" .. i]) end
				end
			end)
		end
		if CompactUnitFrame_UpdateAuras then
			hooksecurefunc("CompactUnitFrame_UpdateAuras", function(frame)
				if not Style.enabled or not frame then return end
				for _, field in ipairs({ "buffFrames", "debuffFrames" }) do
					local buttons = frame[field]
					if buttons then
						for _, button in ipairs(buttons) do Style:StyleAuraButton(button) end
					end
				end
			end)
		end
	end
end

function Style:RefreshAuras()
	if not self.enabled then return end
	for button in pairs(auras) do self:StyleAuraButton(button) end
end

function Style:RestoreAuras()
	for button, state in pairs(auras) do
		local border = state.border
		if border and state.vertexSetter then
			if state.textureSetter then border.SetTexture = state.textureSetter end
			border.SetVertexColor = state.vertexSetter
		end
		if not state.black then
			if border and state.originalColor then
				border:SetVertexColor(unpack(state.originalColor))
			end
		elseif state.created then
			RestoreRegion(state.icon, state.iconSaved)
			if border then border:Hide() end
		elseif border then
			RestoreRegion(state.icon, state.iconSaved)
			RestoreRegion(border, state.borderSaved)
			if state.originalTexture then border:SetTexture(state.originalTexture) end
			if state.originalColor then border:SetVertexColor(unpack(state.originalColor)) end
		end
		auras[button] = nil
	end
end
