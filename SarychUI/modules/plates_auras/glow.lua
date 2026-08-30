-- SarychUI plates-auras glow (WeakAuras-style, no WeakAuras dependency).
-- Pixel / Autocast use LibCustomGlow logic; action-button glow uses copied IconAlert textures.

local MEDIA = [[Interface\AddOns\SarychUI\media\glow\]]
local TEX_WHITE = [[Interface\Buttons\WHITE8X8]]
local TEX_SHINE = MEDIA .. "artifacts"
local TEX_ICON_ALERT = MEDIA .. "IconAlert"
local TEX_ICON_ANTS = MEDIA .. "IconAlertAnts"

local Glow = {}
SarychUI.PlatesAurasGlow = Glow

Glow.defaults = {
	glowType = "border",
	useGlowColor = false,
	glowLines = 8,
	glowFrequency = 0.25,
	glowLength = 10,
	glowThickness = 1,
	glowScale = 1,
	glowBorder = false,
	glowXOffset = 0,
	glowYOffset = 0,
}

local DEFAULT_HIGHLIGHT = { 0, 0.2, 0.5, 1 }
local DEFAULT_LCG = { 0.95, 0.95, 0.32, 1 }
local NAMED_COLORS = {
	blue = { 0, 0.2, 0.5, 1 },
	gold = { 0.8, 0.6, 0.2, 1 },
	purple = { 0.6, 0, 1.0, 1 },
	green = { 0.1, 0.6, 0.1, 1 },
}

local pairs, ipairs = pairs, ipairs
local ceil, floor, min = math.ceil, math.floor, math.min
local tinsert, tremove = table.insert, table.remove
local mod = _G.mod or function(a, b) return a % b end

local function FrameSize(frame)
	if not frame then
		return 0, 0
	end
	local w, h
	if frame.GetSize then
		w, h = frame:GetSize()
	end
	if not w or w == 0 then
		w = frame:GetWidth()
		h = frame:GetHeight()
	end
	return w or 0, h or 0
end

local function SetWH(region, w, h)
	if not region then
		return
	end
	if region.SetSize then
		region:SetSize(w, h)
	else
		region:SetWidth(w)
		region:SetHeight(h)
	end
end

local function SetTexColor(tex, color)
	if not tex then
		return
	end
	if not color then
		tex:SetVertexColor(1, 1, 1)
		tex:SetAlpha(1)
		return
	end
	tex:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1)
	if tex.SetAlpha then
		tex:SetAlpha(color[4] or 1)
	end
end

function Glow.ResolveRGBA(value)
	local r, g, b, a = DEFAULT_HIGHLIGHT[1], DEFAULT_HIGHLIGHT[2], DEFAULT_HIGHLIGHT[3], DEFAULT_HIGHLIGHT[4]
	if type(value) == "table" then
		if type(value[1]) == "number" then
			r, g, b = value[1], value[2] or g, value[3] or b
			if type(value[4]) == "number" then
				a = value[4]
			end
		elseif type(value.r) == "number" then
			r, g, b = value.r, value.g or g, value.b or b
			if type(value.a) == "number" then
				a = value.a
			end
		end
	elseif type(value) == "string" and NAMED_COLORS[value] then
		local c = NAMED_COLORS[value]
		r, g, b, a = c[1], c[2], c[3], c[4]
	end
	return r, g, b, a
end

local function Field(data, key)
	if data and data[key] ~= nil then
		return data[key]
	end
	return Glow.defaults[key]
end

local function IsSideAuraHost(frame)
	local plate = frame and frame._sarPlate
	if plate and plate._suiSidePlate then
		return true
	end
	local parent = frame
	for _ = 1, 8 do
		if not parent then
			break
		end
		if parent._suiSidePlate or parent._suiSideButton then
			return true
		end
		parent = parent.GetParent and parent:GetParent()
	end
	return false
end

local VALID_FRAME_STRATA = {
	BACKGROUND = true,
	LOW = true,
	MEDIUM = true,
	HIGH = true,
	DIALOG = true,
	FULLSCREEN = true,
	FULLSCREEN_DIALOG = true,
	TOOLTIP = true,
}

local function GlowFrameStrata(frame)
	if IsSideAuraHost(frame) then
		return "HIGH"
	end
	local strata = frame and frame.GetFrameStrata and frame:GetFrameStrata()
	return VALID_FRAME_STRATA[strata] and strata or "MEDIUM"
end

function Glow.GetConfig(spellData)
	local cfg = {}
	for key, value in pairs(Glow.defaults) do
		cfg[key] = (spellData and spellData[key] ~= nil) and spellData[key] or value
	end
	return cfg
end

local GlowParent = UIParent

local function TexResetter(_, tex)
	tex:Hide()
	tex:ClearAllPoints()
end

local GlowTexPool
if CreateTexturePool then
	GlowTexPool = CreateTexturePool(GlowParent, "ARTWORK", nil, nil, TexResetter)
end

local function AcquireTex(parent)
	local tex
	if GlowTexPool then
		tex = GlowTexPool:Acquire()
	else
		tex = GlowParent:CreateTexture(nil, "ARTWORK")
	end
	tex:SetParent(parent)
	tex:Show()
	return tex
end

local function ReleaseTex(tex)
	if not tex then
		return
	end
	if GlowTexPool then
		GlowTexPool:Release(tex)
	else
		tex:Hide()
		tex:ClearAllPoints()
		tex:SetParent(GlowParent)
	end
end

local function FrameResetter(_, frame)
	frame:SetScript("OnSizeChanged", nil)
	frame:SetScript("OnUpdate", nil)
	frame:SetScript("OnHide", nil)
	local parent = frame:GetParent()
	if parent and frame.name and parent[frame.name] then
		parent[frame.name] = nil
	end
	if frame.textures then
		for i = 1, #frame.textures do
			ReleaseTex(frame.textures[i])
		end
	end
	if frame.borderTex then
		for i = 1, #frame.borderTex do
			frame.borderTex[i]:Hide()
		end
	end
	frame.textures = {}
	frame.info = {}
	frame.name = nil
	frame.timer = nil
	frame:Hide()
	frame:ClearAllPoints()
end

local GlowFramePool
if CreateFramePool then
	GlowFramePool = CreateFramePool("Frame", GlowParent, nil, FrameResetter)
end

local function AcquireFrame()
	if GlowFramePool then
		return GlowFramePool:Acquire()
	end
	return CreateFrame("Frame", nil, GlowParent)
end

local function ReleaseFrame(frame)
	if not frame then
		return
	end
	if GlowFramePool then
		GlowFramePool:Release(frame)
	else
		FrameResetter(nil, frame)
	end
end

local function addFrameAndTex(r, color, name, key, N, xOffset, yOffset, texture, texCoord, _desaturated, frameLevel)
	key = key or ""
	frameLevel = frameLevel or 8
	local slot = name .. key
	if not r[slot] then
		r[slot] = AcquireFrame()
		r[slot]:SetParent(r)
		r[slot].name = slot
	end

	local f = r[slot]
	if f.SetFrameStrata then
		-- Side rows overlap vertically. Their next aura host has exactly the same
		-- frame level as this animated child at the default +8 offset, so it paints
		-- over most of the glow. A separate strata keeps the overlay intact while
		-- its points and scale still come exclusively from the aura icon host.
		f:SetFrameStrata(GlowFrameStrata(r))
	end
	f:SetFrameLevel((r:GetFrameLevel() or 0) + frameLevel)
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", r, "TOPLEFT", -(xOffset or 0), yOffset or 0)
	f:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", xOffset or 0, -(yOffset or 0))
	f:Hide()

	f.textures = f.textures or {}
	for i = 1, N do
		if not f.textures[i] then
			f.textures[i] = AcquireTex(f)
		else
			f.textures[i]:SetParent(f)
		end
		f.textures[i]:SetTexture(texture)
		if texCoord then
			f.textures[i]:SetTexCoord(texCoord[1], texCoord[2], texCoord[3], texCoord[4])
		else
			f.textures[i]:SetTexCoord(0, 1, 0, 1)
		end
		SetTexColor(f.textures[i], color)
		f.textures[i]:Show()
	end
	while #f.textures > N do
		ReleaseTex(f.textures[#f.textures])
		tremove(f.textures)
	end
	return f
end

local pPoint = {
	BOTTOMLEFT = "BOTTOMRIGHT",
	BOTTOMRIGHT = "TOPRIGHT",
	TOPRIGHT = "TOPLEFT",
	TOPLEFT = "BOTTOMLEFT",
}

local function pWidth(position, width, length, thickness, line1, line2, point)
	line1:ClearAllPoints()
	line1:SetPoint(pPoint[point], point == "BOTTOMLEFT" and -position or position, 0)
	position = width - position
	if position > length then
		SetWH(line1, length, thickness)
		line2:Hide()
	else
		line2:ClearAllPoints()
		line2:SetPoint(point)
		line2:Show()
		SetWH(line1, position, thickness)
		SetWH(line2, thickness, length - position)
	end
end

local function pHeight(position, height, length, thickness, line1, line2, point)
	line1:ClearAllPoints()
	line1:SetPoint(pPoint[point], 0, point == "BOTTOMRIGHT" and -position or position)
	position = height - position
	if position > length then
		SetWH(line1, thickness, length)
		line2:Hide()
	else
		line2:ClearAllPoints()
		line2:SetPoint(point)
		line2:Show()
		SetWH(line1, thickness, position)
		SetWH(line2, length - position, thickness)
	end
end

local function pSizeChanged(self, width, height)
	local info = self and self.info
	if not info then
		return
	end
	if not width or not height or (width == 0 and height == 0) then
		width, height = FrameSize(self)
	end
	if width ~= info.width or height ~= info.height then
		info.width = width
		info.height = height
		info.perimeter = 2 * (width + height)
		info.bottomlim = height * 2 + width
		info.rightlim = height + width
		local n = info.N or 0
		info.space = n > 0 and (info.perimeter / n) or 0
	end
end

local function pUpdate(self, elapsed)
	self.timer = self.timer + elapsed / self.info.period
	if self.timer > 1 or self.timer < -1 then
		self.timer = self.timer % 1
	end
	pSizeChanged(self)
	local info = self.info
	if not info.perimeter or info.perimeter <= 0 then
		return
	end
	for i = 1, info.N do
		local position = (info.space * i + info.perimeter * self.timer) % info.perimeter
		if position > info.bottomlim then
			pWidth(position - info.bottomlim, info.width, info.length, info.th, self.textures[i], self.textures[info.N + i], "BOTTOMLEFT")
		elseif position > info.rightlim then
			pHeight(position - info.rightlim, info.height, info.length, info.th, self.textures[i], self.textures[info.N + i], "BOTTOMRIGHT")
		elseif position > info.height then
			pWidth(position - info.height, info.width, info.length, info.th, self.textures[i], self.textures[info.N + i], "TOPRIGHT")
		else
			pHeight(position, info.height, info.length, info.th, self.textures[i], self.textures[info.N + i], "TOPLEFT")
		end
	end
end

local function LayoutPixelBorder(f, enabled, th, color)
	if not enabled then
		if f.borderTex then
			for i = 1, #f.borderTex do
				f.borderTex[i]:Hide()
			end
		end
		return
	end
	if not f.borderTex then
		f.borderTex = {}
		for i = 1, 4 do
			local t = f:CreateTexture(nil, "BACKGROUND")
			t:SetTexture(TEX_WHITE)
			f.borderTex[i] = t
		end
	end
	th = th or 1
	local top, bottom, left, right = f.borderTex[1], f.borderTex[2], f.borderTex[3], f.borderTex[4]
	top:ClearAllPoints()
	top:SetPoint("TOPLEFT", f, "TOPLEFT", -th, th)
	top:SetPoint("TOPRIGHT", f, "TOPRIGHT", th, th)
	top:SetHeight(th)
	bottom:ClearAllPoints()
	bottom:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", -th, -th)
	bottom:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", th, -th)
	bottom:SetHeight(th)
	left:ClearAllPoints()
	left:SetPoint("TOPLEFT", f, "TOPLEFT", -th, th)
	left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", -th, -th)
	left:SetWidth(th)
	right:ClearAllPoints()
	right:SetPoint("TOPRIGHT", f, "TOPRIGHT", th, th)
	right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", th, -th)
	right:SetWidth(th)
	for i = 1, 4 do
		SetTexColor(f.borderTex[i], color)
		f.borderTex[i]:Show()
	end
end

function Glow.PixelGlow_Start(r, color, N, frequency, length, th, xOffset, yOffset, border, key, frameLevel)
	if not r then
		return
	end
	if not N or N <= 0 then
		N = 8
	end
	local width, height = FrameSize(r)
	if width < 1 or height < 1 then
		width = (r.GetWidth and r:GetWidth()) or 0
		height = (r.GetHeight and r:GetHeight()) or 0
	end
	if width < 1 then
		width = _G.ICON_SIZE_CONTROL or 46
	end
	if height < 1 then
		height = width
	end
	length = length or floor((width + height) * (2 / N - 0.1))
	length = min(length, min(width, height))
	key = key or ""
	color = color or DEFAULT_LCG

	local f = addFrameAndTex(r, color, "_PixelGlow", key, N * 2, xOffset or 0, yOffset or 0, TEX_WHITE, { 0, 1, 0, 1 }, nil, frameLevel)
	f.timer = f.timer or 0
	f.info = f.info or {}
	f.info.N = N
	f.info.period = (not frequency or frequency == 0) and 4 or (1 / frequency)
	f.info.th = th or 1
	f.info.border = border and true or false
	f.info.color = color
	if f.info.length ~= length then
		f.info.width = nil
		f.info.length = length
	end
	LayoutPixelBorder(f, f.info.border, f.info.th, f.info.color)
	pSizeChanged(f)
	f:SetScript("OnSizeChanged", pSizeChanged)
	f:SetScript("OnUpdate", pUpdate)
	f:Show()
end

function Glow.PixelGlow_Stop(r, key)
	if not r then
		return
	end
	key = key or ""
	if r["_PixelGlow" .. key] then
		ReleaseFrame(r["_PixelGlow" .. key])
		r["_PixelGlow" .. key] = nil
	end
end

local acSizes = { 7, 6, 5, 4 }

local function acSizeChanged(self, width, height)
	if not self or not self.info then
		return
	end
	if not (width or height) then
		width, height = FrameSize(self)
	end
	if width ~= self.info.width or height ~= self.info.height then
		self.info.width = width
		self.info.height = height
		self.info.perimeter = 2 * (width + height)
		self.info.bottomlim = height * 2 + width
		self.info.rightlim = height + width
		local n = self.info.N or 0
		self.info.space = n > 0 and (self.info.perimeter / n) or 0
	end
end

local function acUpdate(self, elapsed)
	local texIndex, info = 0, self.info
	acSizeChanged(self)
	if not info.perimeter or info.perimeter <= 0 then
		return
	end
	for k = 1, 4 do
		self.timer[k] = self.timer[k] + elapsed / (info.period * k)
		if self.timer[k] > 1 or self.timer[k] < -1 then
			self.timer[k] = self.timer[k] % 1
		end
		for i = 1, info.N do
			texIndex = texIndex + 1
			local position = (info.space * i + info.perimeter * self.timer[k]) % info.perimeter
			if position > info.bottomlim then
				self.textures[texIndex]:SetPoint("CENTER", self, "BOTTOMRIGHT", -position + info.bottomlim, 0)
			elseif position > info.rightlim then
				self.textures[texIndex]:SetPoint("CENTER", self, "TOPRIGHT", 0, -position + info.rightlim)
			elseif position > info.height then
				self.textures[texIndex]:SetPoint("CENTER", self, "TOPLEFT", position - info.height, 0)
			else
				self.textures[texIndex]:SetPoint("CENTER", self, "BOTTOMLEFT", 0, position)
			end
		end
	end
end

function Glow.AutoCastGlow_Start(r, color, N, frequency, scale, xOffset, yOffset, key, frameLevel)
	if not r then
		return
	end
	if not (N and N > 0) then
		N = 4
	end
	local width, height = FrameSize(r)
	if width < 1 or height < 1 then
		Glow.AutoCastGlow_Stop(r, key)
		return
	end
	scale = scale or 1
	xOffset = xOffset or 0
	yOffset = yOffset or 0
	key = key or ""
	color = color or DEFAULT_LCG

	local f = addFrameAndTex(r, color, "_AutoCastGlow", key, N * 4, xOffset, yOffset, TEX_SHINE, { 0.8115234375, 0.9169921875, 0.8798828125, 0.9853515625 }, true, frameLevel)
	for k, size in ipairs(acSizes) do
		for i = 1, N do
			local tex = f.textures[i + N * (k - 1)]
			if tex then
				SetWH(tex, size * scale, size * scale)
				tex:ClearAllPoints()
			end
		end
	end
	f.timer = f.timer or { 0, 0, 0, 0 }
	f.info = f.info or {}
	f.info.N = N
	f.info.period = (not frequency or frequency == 0) and 4 or (1 / frequency)
	acSizeChanged(f)
	f:SetScript("OnSizeChanged", acSizeChanged)
	f:SetScript("OnUpdate", acUpdate)
	f:Show()
end

function Glow.AutoCastGlow_Stop(r, key)
	if not r then
		return
	end
	key = key or ""
	if r["_AutoCastGlow" .. key] then
		ReleaseFrame(r["_AutoCastGlow" .. key])
		r["_AutoCastGlow" .. key] = nil
	end
end

local function AnimateTexCoords(texture, textureWidth, textureHeight, frameWidth, frameHeight, numFrames, elapsed, throttle)
	if not texture.frame then
		texture.frame = 1
		texture.throttle = throttle
		texture.numColumns = floor(textureWidth / frameWidth)
		texture.numRows = floor(textureHeight / frameHeight)
		texture.columnWidth = frameWidth / textureWidth
		texture.rowHeight = frameHeight / textureHeight
	end
	if not texture.throttle or texture.throttle > throttle then
		local frame = texture.frame
		local framesToAdvance = floor((texture.throttle or 0) / throttle)
		while frame + framesToAdvance > numFrames do
			frame = frame - numFrames
		end
		frame = frame + framesToAdvance
		texture.throttle = 0
		local left = mod(frame - 1, texture.numColumns) * texture.columnWidth
		local right = left + texture.columnWidth
		local bottom = ceil(frame / texture.numColumns) * texture.rowHeight
		local top = bottom - texture.rowHeight
		texture:SetTexCoord(left, right, top, bottom)
		texture.frame = frame
	else
		texture.throttle = texture.throttle + elapsed
	end
end

local ButtonGlowTextures = { "spark", "innerGlow", "innerGlowOver", "outerGlow", "outerGlowOver", "ants" }

local function ButtonGlowResetter(_, frame)
	local parent = frame:GetParent()
	if parent and parent._SarychButtonGlow == frame then
		parent._SarychButtonGlow = nil
	end
	frame:SetScript("OnUpdate", nil)
	frame:Hide()
	frame:ClearAllPoints()
end

local ButtonGlowPool
if CreateFramePool then
	ButtonGlowPool = CreateFramePool("Frame", GlowParent, nil, ButtonGlowResetter)
end

local function ConfigureButtonGlow(f)
	f.spark = f:CreateTexture(nil, "BACKGROUND")
	f.spark:SetPoint("CENTER")
	f.spark:SetAlpha(0)
	f.spark:SetTexture(TEX_ICON_ALERT)
	f.spark:SetTexCoord(0.00781250, 0.61718750, 0.00390625, 0.26953125)
	f.spark:SetBlendMode("ADD")

	f.innerGlow = f:CreateTexture(nil, "ARTWORK")
	f.innerGlow:SetPoint("CENTER")
	f.innerGlow:SetTexture(TEX_ICON_ALERT)
	f.innerGlow:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
	f.innerGlow:SetBlendMode("ADD")

	f.innerGlowOver = f:CreateTexture(nil, "ARTWORK")
	f.innerGlowOver:SetPoint("TOPLEFT", f.innerGlow, "TOPLEFT")
	f.innerGlowOver:SetPoint("BOTTOMRIGHT", f.innerGlow, "BOTTOMRIGHT")
	f.innerGlowOver:SetTexture(TEX_ICON_ALERT)
	f.innerGlowOver:SetTexCoord(0.00781250, 0.50781250, 0.53515625, 0.78515625)
	f.innerGlowOver:SetBlendMode("ADD")
	f.innerGlowOver:SetAlpha(0)

	f.outerGlow = f:CreateTexture(nil, "ARTWORK")
	f.outerGlow:SetPoint("CENTER")
	f.outerGlow:SetTexture(TEX_ICON_ALERT)
	f.outerGlow:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
	f.outerGlow:SetBlendMode("ADD")

	f.outerGlowOver = f:CreateTexture(nil, "ARTWORK")
	f.outerGlowOver:SetPoint("TOPLEFT", f.outerGlow, "TOPLEFT")
	f.outerGlowOver:SetPoint("BOTTOMRIGHT", f.outerGlow, "BOTTOMRIGHT")
	f.outerGlowOver:SetTexture(TEX_ICON_ALERT)
	f.outerGlowOver:SetTexCoord(0.00781250, 0.50781250, 0.53515625, 0.78515625)
	f.outerGlowOver:SetBlendMode("ADD")
	f.outerGlowOver:SetAlpha(0)

	f.ants = f:CreateTexture(nil, "OVERLAY")
	f.ants:SetPoint("CENTER")
	f.ants:SetTexture(TEX_ICON_ANTS)
	f.ants:SetBlendMode("ADD")

	f._configured = true
end

local function ButtonGlow_OnUpdate(self, elapsed)
	if self.ants then
		AnimateTexCoords(self.ants, 256, 256, 48, 48, 22, elapsed, self.throttle or 0.01)
	end
end

function Glow.FitButton(r, f)
	f = f or (r and r._SarychButtonGlow)
	if not r or not f then
		return
	end
	local width, height = FrameSize(r)
	if width < 1 or height < 1 then
		return
	end
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", r, "TOPLEFT", -width * 0.2, height * 0.2)
	f:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", width * 0.2, -height * 0.2)
	SetWH(f.innerGlow, width, height)
	SetWH(f.outerGlow, width, height)
	SetWH(f.ants, width * 1.4 * 0.85, height * 1.4 * 0.85)
	SetWH(f.spark, width, height)
end

function Glow.Fit(frame)
	if not frame then
		return
	end
	local width, height = FrameSize(frame)
	if width < 1 or height < 1 then
		return
	end
	if frame.UpdateBorderSize then
		frame.UpdateBorderSize()
	end
	if frame._SarychButtonGlow then
		Glow.FitButton(frame, frame._SarychButtonGlow)
	end
	local pixel = frame._PixelGlow
	if pixel and pixel.info and pixel.info.N then
		LayoutPixelBorder(pixel, pixel.info.border, pixel.info.th, pixel.info.color)
		pixel.info.width = nil
		pSizeChanged(pixel)
	end
	local auto = frame._AutoCastGlow
	if auto and acSizeChanged then
		acSizeChanged(auto)
	end
end

function Glow.ButtonGlow_Start(r, color, frequency, frameLevel)
	if not r then
		return
	end
	frameLevel = frameLevel or 8
	local throttle = frequency and frequency > 0 and (0.25 / frequency * 0.01) or 0.01
	local width, height = FrameSize(r)
	if width < 1 or height < 1 then
		width = (r.GetWidth and r:GetWidth()) or 0
		height = (r.GetHeight and r:GetHeight()) or 0
	end
	if width < 1 then
		width = _G.ICON_SIZE_CONTROL or 46
	end
	if height < 1 then
		height = width
	end

	local f = r._SarychButtonGlow
	if not f then
		if ButtonGlowPool then
			f = ButtonGlowPool:Acquire()
		else
			f = CreateFrame("Frame", nil, r)
		end
		if not f._configured then
			ConfigureButtonGlow(f)
		end
		r._SarychButtonGlow = f
	end

	f:SetParent(r)
	if f.SetFrameStrata then
		f:SetFrameStrata(GlowFrameStrata(r))
	end
	f:SetFrameLevel((r:GetFrameLevel() or 0) + frameLevel)
	Glow.FitButton(r, f)
	f.spark:SetAlpha(0)
	f.innerGlowOver:SetAlpha(0)
	f.outerGlowOver:SetAlpha(0)

	local apply = color or { 1, 1, 1, 1 }
	for i = 1, #ButtonGlowTextures do
		SetTexColor(f[ButtonGlowTextures[i]], apply)
	end
	f.innerGlow:SetAlpha(apply[4] or 1)
	f.outerGlow:SetAlpha(apply[4] or 1)
	f.ants:SetAlpha(apply[4] or 1)
	f.throttle = throttle
	f.ants.frame = nil
	f:SetScript("OnUpdate", ButtonGlow_OnUpdate)
	f:Show()
end

function Glow.ButtonGlow_Stop(r)
	if not r or not r._SarychButtonGlow then
		return
	end
	local f = r._SarychButtonGlow
	r._SarychButtonGlow = nil
	if ButtonGlowPool then
		ButtonGlowPool:Release(f)
	else
		ButtonGlowResetter(nil, f)
	end
end

local function HideBorder(frame)
	if frame.border then
		frame.border:SetAlpha(0)
		frame.border:Hide()
	end
end

local function ShowBorder(frame, color)
	if not frame.border then
		return
	end
	frame.border:Show()
	frame.border:SetVertexColor(color[1], color[2], color[3])
	frame.border:SetAlpha(color[4] or 1)
end

function Glow.Stop(frame)
	if not frame then
		return
	end
	Glow.PixelGlow_Stop(frame)
	Glow.AutoCastGlow_Stop(frame)
	Glow.ButtonGlow_Stop(frame)
	HideBorder(frame)
	frame._sarychGlowType = nil
end

function Glow.Start(frame, spellData)
	if not frame then
		return
	end
	Glow.Stop(frame)
	if not spellData then
		return
	end
	local highlight = spellData.highlight
	if highlight == nil or highlight == false or highlight == 0 then
		return
	end

	local glowType = spellData.glowType or Glow.defaults.glowType
	local useGlowColor = spellData.useGlowColor
	if useGlowColor == nil then
		useGlowColor = (glowType == "border")
	end

	local r, g, b, a = Glow.ResolveRGBA(spellData.highlightColor)
	local custom = { r, g, b, a }
	local lcgColor = useGlowColor and custom or nil

	frame._sarychGlowType = glowType
	if glowType == "Pixel" then
		Glow.PixelGlow_Start(
			frame,
			lcgColor,
			tonumber(Field(spellData, "glowLines")) or 8,
			tonumber(Field(spellData, "glowFrequency")) or 0.25,
			tonumber(Field(spellData, "glowLength")) or 10,
			tonumber(Field(spellData, "glowThickness")) or 1,
			tonumber(Field(spellData, "glowXOffset")) or 0,
			tonumber(Field(spellData, "glowYOffset")) or 0,
			Field(spellData, "glowBorder") and true or false
		)
	elseif glowType == "ACShine" then
		Glow.AutoCastGlow_Start(
			frame,
			lcgColor,
			tonumber(Field(spellData, "glowLines")) or 8,
			tonumber(Field(spellData, "glowFrequency")) or 0.25,
			tonumber(Field(spellData, "glowScale")) or 1,
			tonumber(Field(spellData, "glowXOffset")) or 0,
			tonumber(Field(spellData, "glowYOffset")) or 0
		)
	elseif glowType == "buttonOverlay" then
		Glow.ButtonGlow_Start(frame, lcgColor, tonumber(Field(spellData, "glowFrequency")) or 0.25)
	else
		ShowBorder(frame, custom)
	end
end

function Glow.IsEnabled(spellData)
	if not spellData then
		return false
	end
	local highlight = spellData.highlight
	return highlight ~= nil and highlight ~= false and highlight ~= 0
end

function Glow.Install(frame)
	if not frame or frame._sarychGlowInstalled then
		return
	end
	frame._sarychGlowInstalled = true
	frame.ShowGlowEffect = function(spellId)
		local data = spellId and _G.SPELL_DATA and _G.SPELL_DATA[spellId]
		Glow.Start(frame, data)
	end
	frame.HideGlowEffect = function()
		Glow.Stop(frame)
	end
	frame.ShowBorderEffect = frame.ShowGlowEffect
	frame.HideBorderEffect = frame.HideGlowEffect
	if not frame._sarychGlowSizeHooked then
		frame._sarychGlowSizeHooked = true
		local prev = frame.GetScript and frame:GetScript("OnSizeChanged")
		frame:SetScript("OnSizeChanged", function(self, width, height)
			if prev then
				prev(self, width, height)
			end
			Glow.Fit(self)
		end)
	end
end
