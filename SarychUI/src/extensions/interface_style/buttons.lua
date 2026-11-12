local Style = SarychUI_InterfaceStyle
local states = setmetatable({}, { __mode = "k" })
local backgrounds = setmetatable({}, { __mode = "k" })

local original = {
	normal = {
		[[interface\buttons\ui-quickslot]],
		[[interface\buttons\ui-quickslot2]],
	},
	actionBorder = { [[interface\buttons\ui-actionbutton-border]] },
	hover = { [[interface\buttons\buttonhilight-square]] },
	pushed = { [[interface\buttons\ui-quickslot-depress]] },
	flash = { [[interface\buttons\ui-quickslotred]] },
}

local function IsOriginal(path, kind)
	if type(path) ~= "string" then return false end
	path = path:gsub("/", "\\"):lower()
	for _, expected in ipairs(original[kind]) do
		if path == expected then return true end
	end
	return false
end

local function SaveRegion(state, region)
	if not region or state.regions[region] then return end
	local points = {}
	for i = 1, region:GetNumPoints() do
		points[i] = { region:GetPoint(i) }
	end
	state.regions[region] = {
		texture = region:GetTexture(),
		alpha = region:GetAlpha(),
		color = { region:GetVertexColor() },
		coords = { region:GetTexCoord() },
		width = region:GetWidth(),
		height = region:GetHeight(),
		points = points,
	}
end

local function HoldNormalColor(state, region, preserveOriginal)
	if state.colorSetters[region] then return end
	local setter = region.SetVertexColor
	state.colorSetters[region] = setter
	state.lastNormalColors[region] = { region:GetVertexColor() }
	region.SetVertexColor = function(self, r, g, b, a)
		if Style.enabled then
			state.lastNormalColors[self] = { r, g, b, a or 1 }
			local sr, sg, sb, sa = Style.GetColor()
			local black = Style:GetTextureMode() == "black"
			local alpha = black and sa or (a or 1)
			if black then
				local value = Style:GetGlossBrightness()
				if preserveOriginal or state.preserveColor then
					return setter(self, r * value, g * value, b * value, alpha)
				end
				return setter(self, value, value, value, alpha)
			end
			if preserveOriginal or state.preserveColor then
				return setter(self, r * sr, g * sg, b * sb, alpha)
			end
			return setter(self, sr, sg, sb, alpha)
		end
		return setter(self, r, g, b, a)
	end
end

local function ApplyActionBorder(button, state)
	if Style:GetTextureMode() ~= "classic" then return end
	local name = button.GetName and button:GetName()
	local border = name and _G[name .. "Border"]
	if not border or not IsOriginal(border:GetTexture(), "actionBorder") then return end
	SaveRegion(state, border)
	HoldNormalColor(state, border, true)
	border:SetVertexColor(unpack(state.lastNormalColors[border]))
end

local function HoldNormalAlpha(state, region)
	if state.alphaSetters[region] then return end
	local setter = region.SetAlpha
	state.alphaSetters[region] = setter
	state.lastNormalAlphas[region] = region:GetAlpha()
	region.SetAlpha = function(self, alpha)
		if Style.enabled then
			state.lastNormalAlphas[self] = alpha
			return setter(self, 1)
		end
		return setter(self, alpha)
	end
end

local function ApplyNormal(button, state)
	local name = button.GetName and button:GetName()
	local normal = button:GetNormalTexture()
	local named = name and _G[name .. "NormalTexture"]
	local second = name and _G[name .. "NormalTexture2"]
	local black = Style:GetTextureMode() == "black"
	local styled = false
	local function Paint(region, namedRegion)
		if region and ((not black and namedRegion) or IsOriginal(region:GetTexture(), "normal")
			or region:GetTexture() == Style.textures.normal) then
			if not state.originalNormal and IsOriginal(region:GetTexture(), "normal") then
				state.originalNormal = region:GetTexture()
			end
			SaveRegion(state, region)
			state.normalRegions[region] = true
			HoldNormalColor(state, region)
			if black then
				HoldNormalAlpha(state, region)
				region:SetTexture(Style.textures.normal)
				region:ClearAllPoints()
				region:SetAllPoints(button)
			end
			-- Keep Blizzard's item-state hue on equipment slots.
			local sr, sg, sb, sa = Style.GetColor()
			local color = state.lastNormalColors[region]
			local alpha = black and sa or (color[4] or 1)
			if black and state.preserveColor then
				local value = Style:GetGlossBrightness()
				state.colorSetters[region](region,
					(color[1] or 1) * value,
					(color[2] or 1) * value,
					(color[3] or 1) * value,
					alpha)
			elseif black then
				local value = Style:GetGlossBrightness()
				state.colorSetters[region](region, value, value, value, alpha)
			elseif state.preserveColor then
				state.colorSetters[region](region,
					(color[1] or 1) * sr,
					(color[2] or 1) * sg,
					(color[3] or 1) * sb,
					alpha)
			else
				state.colorSetters[region](region, sr, sg, sb, alpha)
			end
			if black then state.alphaSetters[region](region, 1) end
			styled = true
		end
	end
	Paint(normal, normal == named or normal == second)
	if named ~= normal then Paint(named, true) end
	if second ~= normal and second ~= named then Paint(second, true) end
	return styled
end

local parts = {
	{ "hover", "GetHighlightTexture", "SetHighlightTexture" },
	{ "pushed", "GetPushedTexture", "SetPushedTexture" },
}

local function ApplyParts(button, state)
	for _, part in ipairs(parts) do
		local kind, getter = part[1], part[2]
		local region = button[getter] and button[getter](button)
		if region and (IsOriginal(region:GetTexture(), kind) or region:GetTexture() == Style.textures[kind]) then
			SaveRegion(state, region)
			region:SetTexture(Style.textures[kind])
		end
	end
	local name = button.GetName and button:GetName()
	local flash = name and _G[name .. "Flash"]
	if flash and (IsOriginal(flash:GetTexture(), "flash") or flash:GetTexture() == Style.textures.flash) then
		SaveRegion(state, flash)
		flash:SetTexture(Style.textures.flash)
	end
end

local function ApplyIcon(button, state)
	local name = button.GetName and button:GetName()
	local icon = name and (_G[name .. "Icon"] or _G[name .. "IconTexture"])
	if not icon then return end
	SaveRegion(state, icon)
	state.iconRegions[icon] = true
	icon:ClearAllPoints()
	icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
	icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
	icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
end

local function ShowBackground(button)
	local back = backgrounds[button]
	if not back then
		back = CreateFrame("Frame", nil, button)
		back:ClearAllPoints()
		back:SetPoint("TOPLEFT", button, "TOPLEFT", -4, 4)
		back:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 4, -4)
		back.fill = back:CreateTexture(nil, "BACKGROUND")
		back.fill:SetTexture(Style.textures.background)
		back.fill:SetAllPoints(button)
		back:SetBackdrop({
			bgFile = "", edgeFile = Style.textures.shadow,
			tile = false, tileSize = 32, edgeSize = 5,
			insets = { left = 5, right = 5, top = 5, bottom = 5 },
		})
		backgrounds[button] = back
	end
	local r, g, b, a = Style.GetColor()
	back.fill:SetVertexColor(r, g, b, a * 0.7)
	back:SetBackdropBorderColor(0, 0, 0, a * 0.9)
	back:SetFrameLevel(math.max(0, button:GetFrameLevel() - 1))
	back:Show()
end

local function InstallSetters(button, state)
	if state.setters then return end
	state.setters = {}
	local normalSetter = button.SetNormalTexture
	state.setters.SetNormalTexture = normalSetter
	button.SetNormalTexture = function(self, path, ...)
		if Style.enabled and IsOriginal(path, "normal") then
			state.originalNormal = path
			local result = normalSetter(self,
				Style:GetTextureMode() == "black" and Style.textures.normal or path, ...)
			ApplyNormal(self, state)
			return result
		end
		return normalSetter(self, path, ...)
	end
	for _, part in ipairs(parts) do
		local kind, setterName = part[1], part[3]
		local setter = button[setterName]
		if setter then
			state.setters[setterName] = setter
			button[setterName] = function(self, path, ...)
				if Style.enabled and Style:GetTextureMode() == "black" and IsOriginal(path, kind) then
					local result = setter(self, Style.textures[kind], ...)
					ApplyParts(self, state)
					return result
				end
				return setter(self, path, ...)
			end
		end
	end
end

local function StyleButton(button, isItem)
	if not Style.enabled or not button or not button.GetNormalTexture then return end
	-- LargeItemButtonTemplate includes both an icon and a text label. Its full
	-- rectangle is not an icon slot and must not receive square-slot artwork.
	if isItem and button:GetWidth() > button:GetHeight() + 1 then return end
	local state = states[button]
	if not state then
		state = {
			regions = {}, normalRegions = {}, iconRegions = {},
			colorSetters = {}, lastNormalColors = {},
			alphaSetters = {}, lastNormalAlphas = {}, preserveColor = isItem,
			mode = Style:GetTextureMode(),
		}
		states[button] = state
	end
	local styled = ApplyNormal(button, state)
	ApplyActionBorder(button, state)
	if styled then
		InstallSetters(button, state)
		if state.mode == "black" then
			ApplyIcon(button, state)
			ShowBackground(button)
			ApplyParts(button, state)
		end
	elseif backgrounds[button] then
		backgrounds[button]:Hide()
	end
end

function Style.StyleActionButton(button)
	StyleButton(button, false)
end

function Style.StyleItemButton(button)
	StyleButton(button, true)
end

local itemSlots = {
	"Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard",
	"Wrist", "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1",
	"Trinket0", "Trinket1", "MainHand", "SecondaryHand", "Ranged", "Ammo",
}

function Style:ApplyItemButtons()
	self.StyleItemButton(_G.MainMenuBarBackpackButton)
	self.StyleItemButton(_G.KeyRingButton)
	for i = 0, 3 do self.StyleItemButton(_G["CharacterBag" .. i .. "Slot"]) end
	for _, slot in ipairs(itemSlots) do self.StyleItemButton(_G["Character" .. slot .. "Slot"]) end
	for frame = 1, (NUM_CONTAINER_FRAMES or 13) do
		for slot = 1, 36 do
			self.StyleItemButton(_G["ContainerFrame" .. frame .. "Item" .. slot])
		end
	end
	for i = 1, 28 do self.StyleItemButton(_G["BankFrameItem" .. i]) end
	for i = 1, 7 do self.StyleItemButton(_G["BankFrameBag" .. i]) end
	for i = 1, 12 do self.StyleItemButton(_G["MerchantItem" .. i .. "ItemButton"]) end
end

function Style:ApplyButtons()
	if not self.enabled then return end
	local prefixes = {
		"ActionButton", "BonusActionButton", "MultiBarBottomLeftButton",
		"MultiBarBottomRightButton", "MultiBarRightButton", "MultiBarLeftButton",
	}
	for i = 1, 12 do
		for _, prefix in ipairs(prefixes) do self.StyleActionButton(_G[prefix .. i]) end
	end
	for i = 1, (NUM_PET_ACTION_SLOTS or 10) do self.StyleActionButton(_G["PetActionButton" .. i]) end
	for i = 1, (NUM_SHAPESHIFT_SLOTS or 10) do self.StyleActionButton(_G["ShapeshiftButton" .. i]) end
	for i = 1, (POSSESS_SLOTS or 2) do self.StyleActionButton(_G["PossessButton" .. i]) end
	local bars = SarychUI and SarychUI.FrostAtomBars
	if bars and bars.IsActive and bars.IsActive() and bars.ForEachStyledButton then
		bars.ForEachStyledButton(self.StyleActionButton)
	end
	for i = 1, 120 do self.StyleActionButton(_G["SarychUIActionButton" .. i]) end
end

function Style:RefreshButtonAppearance()
	self:ApplyButtons()
end

function Style:RefreshGloss()
	if not self.enabled then return end
	for button, state in pairs(states) do
		-- Use the same eligibility checks as the initial application. Merely
		-- seeing an item button does not mean its artwork belongs to this skin.
		StyleButton(button, state.preserveColor)
	end
	if self.RefreshAuras then self:RefreshAuras() end
	if self.RefreshFrameGloss then self:RefreshFrameGloss() end
end

function Style:RestoreButtons()
	for button, state in pairs(states) do
		if state.setters then
			for method, setter in pairs(state.setters) do button[method] = setter end
		end
		for region, setter in pairs(state.colorSetters) do region.SetVertexColor = setter end
		for region, setter in pairs(state.alphaSetters) do region.SetAlpha = setter end
		local normal = button:GetNormalTexture()
		if normal and normal:GetTexture() == self.textures.normal and state.originalNormal then
			button:SetNormalTexture(state.originalNormal)
		end
		for region, saved in pairs(state.regions) do
			if state.normalRegions[region] then
				if region:GetTexture() == self.textures.normal then
					region:SetTexture(state.originalNormal or saved.texture)
				end
			elseif not state.iconRegions[region] then
				region:SetTexture(saved.texture)
			end
			if not state.iconRegions[region] then
				region:SetVertexColor(unpack(state.lastNormalColors[region] or saved.color))
			end
			if state.mode == "black" and not state.iconRegions[region] then
				region:SetAlpha(state.lastNormalAlphas[region] or saved.alpha)
			end
			if state.mode == "black" then
				region:SetTexCoord(unpack(saved.coords))
				region:ClearAllPoints()
				for _, point in ipairs(saved.points) do region:SetPoint(unpack(point)) end
				region:SetSize(saved.width, saved.height)
			end
		end
		if backgrounds[button] then backgrounds[button]:Hide() end
		states[button] = nil
	end
end

function Style:InstallButtonHooks()
	if self.buttonHooksInstalled or not hooksecurefunc then return end
	self.buttonHooksInstalled = true
	if ActionButton_Update then hooksecurefunc("ActionButton_Update", self.StyleActionButton) end
	if PetActionBar_Update then
		hooksecurefunc("PetActionBar_Update", function()
			if Style.enabled then Style:ApplyButtons() end
		end)
	end
	if ShapeshiftBar_Update then
		hooksecurefunc("ShapeshiftBar_Update", function()
			if Style.enabled then Style:ApplyButtons() end
		end)
	end
	if SetItemButtonTexture then
		hooksecurefunc("SetItemButtonTexture", function(button)
			if Style.enabled then Style.StyleItemButton(button) end
		end)
	end
	if SetItemButtonNormalTextureVertexColor then
		hooksecurefunc("SetItemButtonNormalTextureVertexColor", function(button)
			if Style.enabled then Style.StyleItemButton(button) end
		end)
	end
	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_ENTERING_WORLD")
	events:RegisterEvent("ADDON_LOADED")
	events:SetScript("OnEvent", function()
		if Style.enabled then
			Style:ApplyButtons()
			Style:ApplyItemButtons()
		end
	end)
end
