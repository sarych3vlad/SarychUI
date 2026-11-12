-- Death Knight rune bars (FrostAtomUI Runes).

local moduleName = "player_resources"
local module = SarychUI and SarychUI.modules and SarychUI.modules[moduleName]
if not module then return end

if module.PLAYER_CLASS ~= "DEATHKNIGHT" then
	function module:RefreshRunes() end
	function module:DisableRunes() end
	return
end

local NUM_RUNES = 6
local DEATH_RUNE = 4
local BAR_TEX = [[Interface\TargetingFrame\UI-StatusBar]]
local BLANK = [[Interface\Buttons\WHITE8X8]]
local SPARK = [[Interface\CastingBar\UI-CastingBar-Spark]]
local ICONS = {
	[[Interface\PlayerFrame\UI-PlayerFrame-Deathknight-Blood]],
	[[Interface\PlayerFrame\UI-PlayerFrame-Deathknight-Unholy]],
	[[Interface\PlayerFrame\UI-PlayerFrame-Deathknight-Frost]],
	[[Interface\PlayerFrame\UI-PlayerFrame-Deathknight-Death]],
}
local COLOR_KEYS = { "bloodColor", "unholyColor", "frostColor", "deathColor" }

local holder, runes

local function ApplyVisibility(shown, alpha)
	if not holder then
		return
	end
	if not module:Flag("runes", "enabled", false) then
		holder:Hide()
		return
	end
	-- Free-move / drag keeps runes visible regardless of plate mode.
	if module:Flag("runes", "showDragFrame", false) then
		holder:SetAlpha(1)
		holder:Show()
		return
	end
	if shown then
		holder:Show()
		holder:SetAlpha(alpha or 1)
	else
		holder:SetAlpha(1)
		holder:Hide()
	end
end

-- Follows «Панель игрока → Отображение» (always / only on value change) + fade.
function module:SyncRunesToPlateVisibility(shown, alpha)
	ApplyVisibility(shown, alpha)
end

local function Flash(rune)
	if not module:Flag("runes", "readyFlash", true) then return end
	local f = rune.flash
	f:SetAlpha(0.8)
	f:Show()
	f.elapsed = 0
	f:SetScript("OnUpdate", function(self, elapsed)
		self.elapsed = self.elapsed + elapsed
		local a = 0.8 * (1 - self.elapsed / 0.4)
		if a <= 0 then
			self:Hide()
			self:SetScript("OnUpdate", nil)
		else
			self:SetAlpha(a)
		end
	end)
end

local function UpdateColors(rune)
	local r, g, b = rune.color[1], rune.color[2], rune.color[3]
	local shade = rune.ready and 1 or 0.4
	rune:SetStatusBarColor(r * shade, g * shade, b * shade)
	rune.bg:SetVertexColor(r * 0.12, g * 0.12, b * 0.12, 0.9)
	if rune.ready then
		rune.gloss:Show()
		rune.spark:Hide()
		rune.timer:SetText(nil)
		rune.icon:SetDesaturated(false)
		rune.icon:SetVertexColor(1, 1, 1)
	else
		rune.gloss:Hide()
		rune.spark:Show()
		rune.icon:SetDesaturated(true)
		rune.icon:SetVertexColor(0.5, 0.5, 0.5)
	end
end

local function UpdateType(rune)
	local runeType = GetRuneType(rune:GetID())
	if runeType == DEATH_RUNE and rune.runeType and rune.runeType ~= DEATH_RUNE then
		Flash(rune)
	end
	rune.runeType = runeType
	local key = COLOR_KEYS[runeType] or "emptyColor"
	local er, eg, eb = module:Color("runes", key, { 0.2, 0.2, 0.2 })
	rune.color = { er, eg, eb }
	rune.icon:SetTexture(ICONS[runeType] or ICONS[1])
	UpdateColors(rune)
end

local function OnUpdate(rune)
	local start, duration, ready = GetRuneCooldown(rune:GetID())
	if not start then return end
	ready = ready or duration == 0
	if ready ~= rune.ready then
		if ready and rune.ready == false then
			Flash(rune)
		end
		rune.ready = ready
		UpdateColors(rune)
	end
	if ready then
		rune:SetValue(1)
		rune:SetScript("OnUpdate", nil)
		return
	end
	local now = GetTime()
	local progress = math.min(math.max((now - start) / duration, 0), 1)
	rune:SetValue(progress)
	rune.spark:SetPoint("CENTER", rune, "LEFT", rune:GetWidth() * progress, 0)
	if module:Flag("runes", "showTimer", true) then
		rune.timer:SetFormattedText("%d", math.ceil(start + duration - now))
	else
		rune.timer:SetText(nil)
	end
end

local function CreateRune(id)
	local rune = CreateFrame("StatusBar", nil, holder)
	rune:SetID(id)
	rune:SetStatusBarTexture(BAR_TEX)
	rune:SetMinMaxValues(0, 1)
	rune.bg = rune:CreateTexture(nil, "BACKGROUND")
	rune.bg:SetTexture(BLANK)
	rune.bg:SetAllPoints()
	rune.border = rune:CreateTexture(nil, "BACKGROUND", nil, -1)
	rune.border:SetTexture(0, 0, 0, 1)
	rune.gloss = rune:CreateTexture(nil, "OVERLAY")
	rune.gloss:SetTexture(BLANK)
	rune.gloss:SetBlendMode("ADD")
	rune.gloss:SetGradientAlpha("VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.3)
	rune.gloss:SetAllPoints()
	rune.spark = rune:CreateTexture(nil, "OVERLAY")
	rune.spark:SetTexture(SPARK)
	rune.spark:SetBlendMode("ADD")
	local flash = CreateFrame("Frame", nil, rune)
	flash:SetAllPoints()
	flash:Hide()
	local ft = flash:CreateTexture(nil, "OVERLAY")
	ft:SetAllPoints()
	ft:SetTexture(BLANK)
	ft:SetBlendMode("ADD")
	ft:SetVertexColor(1, 1, 1, 0.8)
	rune.flash = flash
	local overlay = CreateFrame("Frame", nil, rune)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(rune:GetFrameLevel() + 2)
	rune.icon = overlay:CreateTexture(nil, "ARTWORK")
	rune.icon:SetPoint("CENTER")
	rune.timer = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	rune.timer:SetPoint("CENTER")
	runes[id] = rune
	return rune
end

local function Ensure()
	if holder then return end
	holder = CreateFrame("Frame", "SarychUIRunes", UIParent)
	runes = {}
	for i = 1, NUM_RUNES do
		CreateRune(i)
	end
	module:RegisterDrag("playerRunes", holder, "runes", "Руны")
	local ev = CreateFrame("Frame")
	ev:RegisterEvent("RUNE_TYPE_UPDATE")
	ev:RegisterEvent("RUNE_POWER_UPDATE")
	ev:RegisterEvent("PLAYER_ENTERING_WORLD")
	ev:SetScript("OnEvent", function(_, event, runeIndex)
		if event == "PLAYER_ENTERING_WORLD" then
			for i = 1, NUM_RUNES do
				local r = runes[i]
				r.ready, r.runeType = nil, nil
				UpdateType(r)
				r:SetScript("OnUpdate", OnUpdate)
				OnUpdate(r)
			end
			return
		end
		local r = runeIndex and runes[runeIndex]
		if not r then return end
		if event == "RUNE_TYPE_UPDATE" then
			UpdateType(r)
		else
			r:SetScript("OnUpdate", OnUpdate)
			OnUpdate(r)
		end
	end)
	module._runeEvents = ev
end

function module:RefreshRunes()
	if not module:Flag("runes", "enabled", false) then
		self:DisableRunes()
		return
	end
	Ensure()
	local width = module:Num("runes", "width", 48)
	local height = module:Num("runes", "height", 16)
	local gap = module:Num("runes", "gap", 4)
	local showIcons = module:Flag("runes", "showIcons", true)
	local showTimer = module:Flag("runes", "showTimer", true)
	local fontSize = module:Num("runes", "timerFontSize", 14)
	local iconSize = math.min(height + 10, width)
	holder:SetSize(NUM_RUNES * (width + gap) - gap, height)
	local slot = width + gap
	for i = 1, NUM_RUNES do
		local rune = runes[i]
		rune:SetSize(width, height)
		rune:ClearAllPoints()
		rune:SetPoint("CENTER", holder, "CENTER", (3.5 - i) * slot, 0)
		rune.border:ClearAllPoints()
		rune.border:SetPoint("TOPLEFT", -1, 1)
		rune.border:SetPoint("BOTTOMRIGHT", 1, -1)
		rune.spark:SetSize(10, height * 2.2)
		rune.icon:SetSize(iconSize, iconSize)
		if showIcons then rune.icon:Show() else rune.icon:Hide() end
		module:SetFont(rune.timer, fontSize)
		if showTimer then rune.timer:Show() else rune.timer:Hide() end
		rune.ready, rune.runeType = nil, nil
		UpdateType(rune)
		rune:SetScript("OnUpdate", OnUpdate)
		OnUpdate(rune)
	end
	module:ApplyPoint(holder, "runes")
	module:UpdateDrag("playerRunes", "runes")
	if module.IsPlayerPanelWanted then
		ApplyVisibility(module:IsPlayerPanelWanted(), 1)
	else
		ApplyVisibility(true, 1)
	end
end

function module:DisableRunes()
	module:StopDrag("playerRunes")
	if holder then
		holder:Hide()
	end
end
