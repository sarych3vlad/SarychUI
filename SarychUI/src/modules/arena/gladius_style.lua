-- Gladius' first-run proportions on Blizzard's existing arena unit frames.
local module = SarychUI and SarychUI.modules and SarychUI.modules.arena
if not module then return end

local BAR = [[Interface\AddOns\SarychUI\media\arena\Minimalist]]
local CLASS_ATLAS = [[Interface\Glues\CharacterCreate\UI-CharacterCreate-Classes]]
local BACKDROP = [[Interface\Tooltips\UI-Tooltip-Background]]
local DEATH_ATLAS = [[Interface\AddOns\SarychUI\media\arena\TournamentOrganizer.blp]]
local POWER_COLORS = {
	[0] = { 0.18, 0.44, 0.75 }, -- mana
	[1] = { 1, 0, 0 },          -- rage
	[3] = { 1, 1, 0 },          -- energy
	[6] = { 0, 0.82, 1 },       -- runic power
}
local PET_HEIGHT = 15
local PET_GAP = 4

local function UpdateClassicProtectedIcon(bar, icon, visible)
	local saved = bar._suiProtectedIconLayout
	if visible then
		if not saved then
			saved = { width = icon:GetWidth(), height = icon:GetHeight(), points = {}, texCoord = { icon:GetTexCoord() } }
			for i = 1, icon:GetNumPoints() do saved.points[i] = { icon:GetPoint(i) } end
			bar._suiProtectedIconLayout = saved
		end
		-- Keep the protected spell icon aligned with Blizzard's compact shield,
		-- even when another layout changes ordinary cast icons or the test source.
		icon:ClearAllPoints()
		icon:SetSize(16, 16)
		icon:SetPoint("RIGHT", bar, "LEFT", -5, 0)
		icon:SetTexCoord(0, 1, 0, 1)
	elseif saved then
		icon:ClearAllPoints()
		icon:SetSize(saved.width, saved.height)
		for _, point in ipairs(saved.points) do icon:SetPoint(unpack(point)) end
		icon:SetTexCoord(unpack(saved.texCoord))
		bar._suiProtectedIconLayout = nil
	end
end

-- Gladdy's shield artwork surrounds the spell icon; its transparent padding
-- requires the same 3.2x icon size used by Gladdy.
function module:UpdateGladiusCastShield(bar, icon, protected, kind)
	if not bar or not icon then return end
	kind = kind or "gladius"
	local style = self:GetStyleSettings(kind) or {}
	local enabled = protected and style.showCastShield ~= false
	local visible = enabled and (kind ~= "gladius" or style.showCastShieldIcon ~= false)
	local silver = enabled and (kind ~= "gladius" or style.colorProtectedCast ~= false)
	UpdateClassicProtectedIcon(bar, icon, kind == "classic" and visible)
	if silver then
		bar:SetStatusBarColor(0.8, 0.8, 0.8, 1)
	elseif bar._suiGladiusProtectedColor then
		if kind == "classic" then
			bar:SetStatusBarColor(bar.channeling and 0 or 1, bar.channeling and 1 or 0.7, 0, 1)
		else
			bar:SetStatusBarColor(1, 1, 0, 1)
		end
	end
	bar._suiGladiusProtectedColor = silver and true or nil
	local shield = bar._suiGladiusCastShield
	if kind == "classic" then
		local name = bar.GetName and bar:GetName()
		local native = name and _G[name .. "BorderShield"]
		if native and shield ~= native then
			if shield then shield:Hide() end
			shield = native
			bar._suiGladiusCastShield = shield
		end
	end
	if visible and not shield then
		shield = bar:CreateTexture(nil, kind == "classic" and "ARTWORK" or "OVERLAY")
		bar._suiGladiusCastShield = shield
	end
	if shield then
		if visible then
			shield:ClearAllPoints()
			if kind == "classic" then
				-- Native compact shield from ArenaCastingBarFrameTemplate.
				shield:SetTexture([[Interface\CastingBar\UI-CastingBar-Arena-Shield]])
				shield:SetPoint("LEFT", bar, "LEFT", -25, 0)
				shield:SetSize(42, 42)
			else
				shield:SetTexture([[Interface\AddOns\SarychUI\media\arena\castbar-shield.blp]])
				shield:SetPoint("CENTER", icon, "CENTER", 0, -1.5)
				shield:SetSize(icon:GetWidth() * 3.2, icon:GetHeight() * 3.2)
			end
			shield:Show()
		else
			shield:Hide()
		end
	end
end

-- Classic bars use Blizzard shield geometry and share protected-cast color handling.
function module:UpdateClassicCastShields(forceHide)
    local modules = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
    local db = modules and modules.arena
    if not db or db.frameType == "gladius" then return end
    local active = db.enabled and not forceHide
    for i = 1, (MAX_ARENA_ENEMIES or 5) do
        local cast = _G["ArenaEnemyFrame" .. i .. "CastingBar"]
        local icon = _G["ArenaEnemyFrame" .. i .. "CastingBarIcon"]
        if cast and icon then
            local spell, _, _, _, _, _, _, _, protected = UnitCastingInfo("arena" .. i)
            if not spell then spell, _, _, _, _, _, _, protected = UnitChannelInfo("arena" .. i) end
            self:UpdateGladiusCastShield(cast, icon, active and spell and protected, "classic")
        end
        local sample = _G["SarychUIArenaTestCastingBar" .. i]
        if sample then
            self:UpdateGladiusCastShield(sample, sample._suiCastIcon,
                active and (db.testMode or 0) > 0 and i == 2, "classic")
        end
    end
end

local function BarText(bar, key, size, point, x, y)
	if not bar then return end
	local label = bar[key]
	if not label then
		label = bar:CreateFontString(nil, "OVERLAY")
		label:SetTextColor(1, 1, 1, 1)
		label:SetShadowColor(0, 0, 0, 1)
		label:SetShadowOffset(1, -1)
		label:SetPoint(point, bar, point, x, y)
		bar[key] = label
	end
	label:SetFont(STANDARD_TEXT_FONT, size)
	return label
end

local function ShortValue(value)
	value = tonumber(value) or 0
	if value > 9999 then return string.format("%.1fk", value / 1000) end
	return tostring(math.floor(value + 0.5))
end

local function HideArtwork(region)
	if region and region.SetAlpha then region:SetAlpha(0) end
end

local function SuppressTooltip(region)
	if region and region.HookScript and not region._suiGladiusTooltipHook then
		region:HookScript("OnEnter", function() if GameTooltip then GameTooltip:Hide() end end)
		region._suiGladiusTooltipHook = true
	end
end

local function StyleBar(bar, width, height, x, y, frame)
	if not bar then return end
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
	bar:SetSize(width, height)
	bar:SetStatusBarTexture(BAR)
	local bg = bar._suiGladiusBackground
	if not bg then
		-- The health loss bar is one frame level below the healthbar. Its
		-- background must live on the parent or it covers UFL's red animation.
		bg = (bar == frame.healthbar and frame or bar):CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(bar)
		bar._suiGladiusBackground = bg
	end
	bg:SetTexture([[Interface\Buttons\WHITE8X8]])
	if bar == frame.healthbar or bar == frame.manabar then
		bg:SetVertexColor(0, 0, 0, 1)
		bg:SetAlpha(0.4)
	else
		bg:SetVertexColor(0.6, 0.6, 0.6, 1)
		bg:SetAlpha(0.3)
	end
	bg:Show()
end

-- Blizzard recolors health and power bars independently of our style ticker.
-- Keep the visible tint separate while following the native fill geometry.
local function EnsureBarFill(bar, power)
	if not bar then return end
	local native = bar:GetStatusBarTexture()
	if not native then return end
	local fillKey = power and "_suiGladiusPowerFill" or "_suiGladiusHealthFill"
	local nativeKey = power and "_suiGladiusNativePowerFill" or "_suiGladiusNativeHealthFill"
	local fill = bar[fillKey]
	if not fill then
		fill = bar:CreateTexture(nil, "ARTWORK")
		fill:SetTexture(BAR)
		bar[fillKey] = fill
	end
	if bar[nativeKey] ~= native then
		fill:ClearAllPoints()
		fill:SetAllPoints(native)
		bar[nativeKey] = native
	end
	-- Power updates may restore the native fill's opacity. Remove its artwork
	-- as well; keep the texture object and its statusbar-driven geometry for
	-- the Gladius fill to follow, even between visual ticker updates.
	if power then native:SetTexture(nil) end
	native:SetAlpha(0)
	return fill
end

-- Blizzard changes the native spark during a cast. Keep a Gladius spark tied
-- to the current bar geometry and progress instead of resizing that texture.
function module:UpdateGladiusSpark(bar)
	local spark = bar and bar._suiGladiusSpark
	if not spark then return end
	local native = bar._suiGladiusNativeSpark
	if native then HideArtwork(native) end
	local height = bar:GetHeight()
	if not height or height <= 0 then return end
	local size = height * 2
	if spark:GetWidth() ~= size or spark:GetHeight() ~= size then
		spark:SetSize(size, size)
	end
	local minimum, maximum = bar:GetMinMaxValues()
	local value = bar:GetValue()
	local progress = maximum and minimum and maximum > minimum
		and math.max(0, math.min(1, ((value or minimum) - minimum) / (maximum - minimum))) or 0
	local x = bar:GetWidth() * progress
	if spark._suiGladiusX ~= x then
		spark:ClearAllPoints()
		spark:SetPoint("CENTER", bar, "LEFT", x, 0)
		spark._suiGladiusX = x
	end
end

local function EnsureCastSpark(bar, native)
	if not bar._suiGladiusSpark then
		local spark = bar:CreateTexture(nil, "OVERLAY")
		spark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
		spark:SetBlendMode("ADD")
		bar._suiGladiusSpark = spark
		bar._suiGladiusNativeSpark = native
		bar:HookScript("OnUpdate", function(self) module:UpdateGladiusSpark(self) end)
		bar:HookScript("OnSizeChanged", function(self) module:UpdateGladiusSpark(self) end)
	end
	module:UpdateGladiusSpark(bar)
end

local function SetVisualShown(visual, shown)
	if shown then
		if not visual:IsShown() then visual:Show() end
	elseif visual:IsShown() then visual:Hide() end
end

local function UpdateBorderGeometry(border, frame)
	-- Borders live under UIParent to keep their independent strata/alpha.
	-- Match the owner's effective scale, including inherited container scale.
	local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	if border:GetScale() ~= scale then border:SetScale(scale) end
	local width, height = frame:GetWidth() + 9, frame:GetHeight() + 5
	if border:GetWidth() ~= width or border:GetHeight() ~= height then border:SetSize(width, height) end
end

local function CreateBorder(frame, color, strata)
	local border = CreateFrame("Frame", nil, UIParent)
	UpdateBorderGeometry(border, frame)
	border:SetPoint("TOP", frame, "TOP", -1, 3)
	local function Edge(pointA, pointB, horizontal)
		local edge = border:CreateTexture(nil, "OVERLAY")
		edge:SetTexture([[Interface\Buttons\WHITE8X8]])
		edge:SetVertexColor(color[1], color[2], color[3], 1)
		edge:SetPoint(pointA, border, pointA)
		edge:SetPoint(pointB, border, pointB)
		if horizontal then edge:SetHeight(1) else edge:SetWidth(1) end
	end
	Edge("TOPLEFT", "TOPRIGHT", true)
	Edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
	Edge("TOPLEFT", "BOTTOMLEFT", false)
	Edge("TOPRIGHT", "BOTTOMRIGHT", false)
	border:SetFrameStrata(strata)
	border:EnableMouse(false)
	border:Hide()
	return border
end

local function EnsurePetBar(frame)
	if frame._suiGladiusPet then return frame._suiGladiusPet end
	local bar = CreateFrame("StatusBar", nil, frame)
	bar:SetStatusBarTexture(BAR)
	bar:SetStatusBarColor(0.20, 0.90, 0.20)
	bar:SetMinMaxValues(0, 100)
	bar:SetValue(100)
	bar:EnableMouse(false)
	local bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(bar)
	bg:SetTexture([[Interface\Buttons\WHITE8X8]])
	bg:SetVertexColor(0.6, 0.6, 0.6, 1)
	bg:SetAlpha(0.3)
	bar.nameText = bar:CreateFontString(nil, "OVERLAY")
	bar.nameText:SetFont(STANDARD_TEXT_FONT, 9)
	bar.nameText:SetPoint("LEFT", bar, "LEFT", 5, 0)
	bar.nameText:SetShadowColor(0, 0, 0, 1)
	bar.nameText:SetShadowOffset(1, -1)
	bar.healthText = bar:CreateFontString(nil, "OVERLAY")
	bar.healthText:SetFont(STANDARD_TEXT_FONT, 9)
	bar.healthText:SetPoint("RIGHT", bar, "RIGHT", -5, 0)
	bar.healthText:SetShadowColor(0, 0, 0, 1)
	bar.healthText:SetShadowOffset(1, -1)
	bar.target = CreateBorder(bar, { 1, 0.7, 0 }, "HIGH")
	bar.focus = CreateBorder(bar, { 1, 0, 0 }, "MEDIUM")
	frame._suiGladiusPet = bar
	return bar
end

local function EnsureVisuals()
	if not module._gladiusBackdrop then
		local backdrop = CreateFrame("Frame", nil, UIParent)
		backdrop:SetBackdrop({ bgFile = BACKDROP, tile = true, tileSize = 16 })
		backdrop:SetBackdropColor(0, 0, 0, 0.3)
		backdrop:SetFrameStrata("BACKGROUND")
		backdrop:EnableMouse(false)
		backdrop:Hide()
		module._gladiusBackdrop = backdrop
	end
	module._gladiusBorders = module._gladiusBorders or {}
	for i = 1, (MAX_ARENA_ENEMIES or 5) do
		local frame = _G["ArenaEnemyFrame" .. i]
		if frame and not module._gladiusBorders[i] then
			local target = CreateBorder(frame, { 1, 0.7, 0 }, "HIGH")
			local focus = CreateBorder(frame, { 1, 0, 0 }, "MEDIUM")
			local highlight
			if frame.healthbar then
				highlight = frame.healthbar:CreateTexture(nil, "OVERLAY")
				highlight:SetAllPoints(frame.healthbar)
				highlight:SetTexture([[Interface\QuestFrame\UI-QuestTitleHighlight]])
				highlight:SetBlendMode("ADD")
				highlight:SetAlpha(0.5)
				highlight:Hide()
			end
			module._gladiusBorders[i] = { target = target, focus = focus, highlight = highlight }
			-- Death marker remains fully visible while the arena frame fades.
			local death = CreateFrame("Frame", nil, UIParent)
			death:SetFrameStrata("HIGH")
			death:SetFrameLevel(frame:GetFrameLevel() + 5)
			death:SetSize(27, 30)
			death:SetPoint("CENTER", frame.healthbar, "CENTER", 0, -25 / 13)
			death:EnableMouse(false)
			local skull = death:CreateTexture(nil, "ARTWORK")
			skull:SetAllPoints()
			skull:SetTexture(DEATH_ATLAS)
			skull:SetTexCoord(0, 0.058, 0.295, 0.359)
			death:Hide()
			module._gladiusBorders[i].death = death
		end
	end
	if module._gladiusVisualTicker then return end
	local ticker = CreateFrame("Frame", nil, UIParent)
	ticker.elapsed = 0
	ticker:RegisterEvent("PLAYER_TARGET_CHANGED")
	ticker:RegisterEvent("PLAYER_FOCUS_CHANGED")
	ticker:SetScript("OnEvent", function()
		module:UpdateGladiusVisuals()
	end)
	ticker:SetScript("OnUpdate", function(self, elapsed)
		self.elapsed = self.elapsed + elapsed
		if self.elapsed < 0.1 then return end
		self.elapsed = 0
		module:UpdateGladiusVisuals()
	end)
	module._gladiusVisualTicker = ticker
end

function module:UpdateGladiusVisuals()
	local modules = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	local db = modules and modules.arena
	if not db or not db.enabled or db.frameType ~= "gladius" then return end
	local tr = db.Trinkets or {}
	local style = self:GetStyleSettings("gladius") or {}
	local primary = self:GetGladiusPrimaryContent()
	local racialEnabled = primary == "racial"
	local procCount = primary == "procTrinkets" and 2 or 0
	local configuredIconCount = (tr.enabled and 1 or 0) + (racialEnabled and 1 or 0) + procCount
	local iconCount = 0
	local petSpace = style.showPets ~= false and (PET_GAP + PET_HEIGHT) or 0
	local first, last
	local targetGUID, focusGUID = UnitGUID("target"), UnitGUID("focus")
	for i = 1, (MAX_ARENA_ENEMIES or 5) do
		local frame = _G["ArenaEnemyFrame" .. i]
		local visual = self._gladiusBorders and self._gladiusBorders[i]
		local shown = frame and frame:IsVisible()
		if shown then
			first, last = first or frame, frame
			local count = configuredIconCount
			if db.testMode and db.testMode > 0 then
				if i <= 2 then count = (tr.enabled and 1 or 0) + procCount end
			else
				local race = self.Trinkets._iconRace and self.Trinkets._iconRace[i]
				if race == "Human" then count = (tr.enabled and 1 or 0) + procCount end
			end
			iconCount = math.max(iconCount, count)
		end
		local dead = shown and self:IsArenaOpponentDead(i, db.testMode and db.testMode > 0)
		if visual then
			if shown then
				UpdateBorderGeometry(visual.target, frame)
				UpdateBorderGeometry(visual.focus, frame)
			end
			if visual.death then
				SetVisualShown(visual.death, dead)
			end
			local portrait = frame and (frame.classPortrait or _G[frame:GetName() .. "ClassPortrait"])
			if portrait and portrait:GetAlpha() ~= 1 then portrait:SetAlpha(1) end
			local testPlayer = shown and db.testMode and db.testMode > 0 and i == 1
			local guid = shown and UnitGUID(testPlayer and "player" or ("arena" .. i))
			local isTarget = testPlayer and UnitIsUnit("target", "player")
				or (guid and targetGUID and guid == targetGUID)
			local isFocus = testPlayer and UnitIsUnit("focus", "player")
				or (guid and focusGUID and guid == focusGUID)
			SetVisualShown(visual.target, isTarget)
			SetVisualShown(visual.focus, isFocus)
			if visual.highlight then
				SetVisualShown(visual.highlight, isTarget)
			end
		end
		if shown then
			local unit = (db.testMode and db.testMode > 0 and i == 1)
				and "player" or (frame.unit or ("arena" .. i))
			local health = frame.healthbar
			local power = frame.manabar
			local spec, class
			if db.testMode and db.testMode > 0 then
				spec, class = self:GetTestArenaSpec(i)
			else
				spec = self:GetArenaSpec("arena" .. i)
				local _, detectedClass = UnitClass("arena" .. i)
				class = detectedClass
			end
			if power and power._suiGladiusSpecIcon then
				local texture = style.showSpecText ~= false and spec
					and self:GetArenaSpecIcon(class, spec)
				if texture then
					if power._suiGladiusSpecIcon._suiTexture ~= texture then
						power._suiGladiusSpecIcon:SetTexture(texture)
						power._suiGladiusSpecIcon._suiTexture = texture
					end
					power._suiGladiusSpecIcon:Show()
				else
					power._suiGladiusSpecIcon:Hide()
				end
			end
			if unit == "player" and health then
				local maximum = math.max(1, UnitHealthMax(unit) or 1)
				health:SetMinMaxValues(0, maximum)
				health:SetValue(UnitHealth(unit) or maximum)
			end
			if health then
				local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
				local r, g, b = 0, 1, 0
				if color then r, g, b = color.r, color.g, color.b end
				SarychUI.UnitFrameLayers:SetBarColor(frame, health, r, g, b)
				local fill = EnsureBarFill(health)
				if fill then
					local factor = SarychUI.UnitFrameLayers:GetRangeColorFactor(frame)
					fill:SetVertexColor(r * factor, g * factor, b * factor, 1)
					-- Blizzard may refill the test status bar between ticks; hide its visible fill while dead.
					if dead then fill:Hide() else fill:Show() end
				end
			end
			if unit == "player" and power then
				local maximum = math.max(1, UnitManaMax(unit) or 1)
				power:SetMinMaxValues(0, maximum)
				power:SetValue(UnitMana(unit) or maximum)
			end
			if health and health._suiGladiusValueText then
				local maximum = UnitHealthMax(unit)
				if maximum and maximum > 0 then
					health._suiGladiusValueText:SetText(string.format("%d%%", math.floor(UnitHealth(unit) / maximum * 100 + 0.5)))
				elseif db.testMode and db.testMode > 0 then
					health._suiGladiusValueText:SetText(({ "82%", "61%", "44%", "77%", "93%" })[i] or "100%")
				else health._suiGladiusValueText:SetText("") end
			end
			if power and power._suiGladiusValueText then
				local powerType = UnitExists(unit) and UnitPowerType(unit)
				if not powerType and db.testMode and db.testMode > 0 then
					powerType = ({ 1, 0, 0, 3, 0 })[i]
				end
				local color = POWER_COLORS[powerType or 0] or POWER_COLORS[0]
				SarychUI.UnitFrameLayers:SetBarColor(frame, power, color[1], color[2], color[3])
				local fill = EnsureBarFill(power, true)
				if fill then
					SarychUI.UnitFrameLayers:SetRangeTextureColor(frame, fill, color[1], color[2], color[3], 1)
					if dead then fill:Hide() else fill:Show() end
				end
				local maximum = UnitManaMax(unit)
				if maximum and maximum > 0 then
					power._suiGladiusValueText:SetText(ShortValue(UnitMana(unit)) .. "/" .. ShortValue(maximum))
				elseif db.testMode and db.testMode > 0 then
					power._suiGladiusValueText:SetText("35/100")
				else power._suiGladiusValueText:SetText("") end
			end
			if power and power._suiGladiusSpecText then
				if style.showSpecText == false then power._suiGladiusSpecText:Hide()
				else power._suiGladiusSpecText:Show() end
				power._suiGladiusSpecText:SetText(style.showSpecText ~= false and (spec or "") or "")
			end
			if db.testMode and db.testMode > 0 and i == 5 then
				if health then
					health:SetValue(0)
					if health._suiGladiusValueText then health._suiGladiusValueText:SetText("") end
				end
				if power then
					power:SetValue(0)
					if power._suiGladiusValueText then power._suiGladiusValueText:SetText("") end
				end
			end
			local cast = _G[frame:GetName() .. "CastingBar"]
			local icon = _G[frame:GetName() .. "CastingBarIcon"]
			if cast and icon then
				local height = cast:GetHeight()
				if height and height > 0 and (icon:GetWidth() ~= height or icon:GetHeight() ~= height) then
					icon:SetSize(height, height)
				end
				self:UpdateGladiusSpark(cast)
				local spell, rank, _, texture, _, finish, _, _, protected = UnitCastingInfo(unit)
				if not spell then spell, rank, _, texture, _, finish, _, protected = UnitChannelInfo(unit) end
				self:UpdateGladiusCastShield(cast, icon, spell and protected)
				local sample = _G["SarychUIArenaTestCastingBar" .. i]
				if sample then
					self:UpdateGladiusCastShield(sample, sample._suiGladiusIcon, i == 2)
				end
				if cast._suiGladiusSpellText then
					cast._suiGladiusSpellText:SetText(spell and rank and rank ~= ""
						and (spell .. " (" .. rank .. ")") or (spell or ""))
					cast._suiGladiusTimeText:SetText(spell and finish and string.format("%.1f", math.max(0, finish / 1000 - GetTime())) or "")
					if spell and texture then icon:SetTexture(texture) end
				end
			end
			local pet = frame._suiGladiusPet
			if pet then
				UpdateBorderGeometry(pet.target, pet)
				UpdateBorderGeometry(pet.focus, pet)
				local petUnit = (db.testMode and db.testMode > 0 and i == 1)
					and "pet" or ("arenapet" .. i)
				local testing = db.testMode and db.testMode > 0
				local isTestPet = testing and i == 1
				local exists = UnitExists(petUnit)
				if style.showPets ~= false and (exists or isTestPet) then
					local maxHealth = exists and UnitHealthMax(petUnit) or 0
					local percent = maxHealth > 0 and math.floor(UnitHealth(petUnit) / maxHealth * 100 + 0.5) or 100
					pet:SetValue(percent)
					pet.nameText:SetText((exists and (UnitCreatureFamily(petUnit) or UnitName(petUnit))) or "Питомец")
					pet.healthText:SetText(percent .. "%")
					pet:Show()
					local petGUID = exists and UnitGUID(petUnit)
					if petGUID and petGUID == targetGUID then pet.target:Show() else pet.target:Hide() end
					if petGUID and petGUID == focusGUID then pet.focus:Show() else pet.focus:Hide() end
				else
					pet:Hide()
					pet.target:Hide()
					pet.focus:Hide()
				end
			end
		elseif frame and frame._suiGladiusPet then
			frame._suiGladiusPet:Hide()
			frame._suiGladiusPet.target:Hide()
			frame._suiGladiusPet.focus:Hide()
		end
	end
	local backdrop = self._gladiusBackdrop
	if backdrop then
		if first and last and style.showDarkBackground ~= false then
			if self._gladiusBackdropFirst ~= first or self._gladiusBackdropLast ~= last
				or self._gladiusBackdropIcons ~= iconCount or self._gladiusBackdropPets ~= petSpace
				or self._gladiusBackdropCastPos ~= style.castBarPos
				or self._gladiusBackdropBarWidth ~= style.barWidth then
				backdrop:ClearAllPoints()
				backdrop:SetPoint("TOPLEFT", first, "TOPLEFT", -7.5, 6)
				backdrop:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT", 7.5 + iconCount * 41
					+ (iconCount == 1 and 2 or 0),
					-5 - petSpace)
				self._gladiusBackdropFirst, self._gladiusBackdropLast, self._gladiusBackdropIcons = first, last, iconCount
				self._gladiusBackdropPets, self._gladiusBackdropCastPos, self._gladiusBackdropBarWidth = petSpace, style.castBarPos, style.barWidth
			end
			backdrop:Show()
		else
			backdrop:Hide()
			self._gladiusBackdropFirst, self._gladiusBackdropLast, self._gladiusBackdropIcons = nil, nil, nil
			self._gladiusBackdropPets, self._gladiusBackdropCastPos, self._gladiusBackdropBarWidth = nil, nil, nil
		end
	end
end

function module:ApplyGladiusStyle()
	local modules = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	local db = modules and modules.arena
	if not db or not db.enabled or db.frameType ~= "gladius" then return end
	if InCombatLockdown and InCombatLockdown() then return end
	local style = self:GetStyleSettings("gladius") or {}
	local barWidth = math.max(80, math.min(300, tonumber(style.barWidth) or 165))
	local castLeft = style.castBarPos == "LEFT"
	local castHeight = math.max(12, math.min(castLeft and 40 or 30, tonumber(style.castBarHeight) or 18))
	local castTextSize = math.max(1, math.min(20, tonumber(style.castTextSize) or 10))
	local castWidth = barWidth + 41 - castHeight
	local frameWidth = barWidth + 40
	local frameHeight = castLeft and 43 or math.max(56, 43 + castHeight + 1)
	for i = 1, (MAX_ARENA_ENEMIES or 5) do
		local frame = _G["ArenaEnemyFrame" .. i]
		if frame then
			local name = frame:GetName()
			-- Gladius layout: configurable bar width and cast height, 40px class icon.
			frame:SetSize(frameWidth, frameHeight)
			HideArtwork(_G[name .. "Texture"])
			HideArtwork(_G[name .. "SpecBorder"])
			HideArtwork(frame.texture)
			StyleBar(frame.healthbar, barWidth, 25, 40, 0, frame)
			EnsureBarFill(frame.healthbar)
			StyleBar(frame.manabar, barWidth, 15, 40, -26, frame)
			EnsureBarFill(frame.manabar, true)
			if frame.healthbar and frame.healthbar._suiBarUnderlay then
				frame.healthbar._suiBarUnderlay:Hide()
			end
			if frame.manabar and frame.manabar._suiBarUnderlay then
				frame.manabar._suiBarUnderlay:Hide()
			end
			if frame.manabar and not frame.manabar._suiGladiusSpecIcon then
				local icon = frame.manabar:CreateTexture(nil, "OVERLAY")
				icon:SetSize(13, 13)
				icon:SetPoint("LEFT", frame.manabar, "LEFT", 4, 0)
				icon:Hide()
				frame.manabar._suiGladiusSpecIcon = icon
			end
			BarText(frame.healthbar, "_suiGladiusValueText", 11, "RIGHT", -5, 0)
			BarText(frame.manabar, "_suiGladiusValueText", 10, "RIGHT", -5, 0)
			local specText = BarText(frame.manabar, "_suiGladiusSpecText", 10, "LEFT", 21, 0)
			if specText then
				if style.showSpecText == false then specText:Hide() else specText:Show() end
			end
			HideArtwork(frame.healthbar and frame.healthbar.TextString)
			HideArtwork(frame.manabar and frame.manabar.TextString)
			HideArtwork(_G[name .. "HealthBarText"])
			HideArtwork(_G[name .. "ManaBarText"])
			SuppressTooltip(frame.healthbar)
			SuppressTooltip(frame.manabar)
			if frame.name and frame.healthbar then
				frame.name:ClearAllPoints()
				frame.name:SetPoint("LEFT", frame.healthbar, "LEFT", 5, 0)
				frame.name:SetFont(STANDARD_TEXT_FONT, 11)
				SarychUI.UnitFrameLayers:SetTextColor(frame, frame.name, 1, 1, 1, 1)
				frame.name:SetShadowColor(0, 0, 0, 1)
				frame.name:SetShadowOffset(1, -1)
			end
			local portrait = frame.classPortrait or _G[name .. "ClassPortrait"]
			if portrait then
				portrait:ClearAllPoints()
				portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 0)
				portrait:SetSize(40, 41)
				local _, class = UnitClass(frame.unit or ("arena" .. i))
				if class and CLASS_BUTTONS and CLASS_BUTTONS[class] then
					portrait:SetTexture(CLASS_ATLAS)
					portrait:SetTexCoord(unpack(CLASS_BUTTONS[class]))
				end
			end
			-- Keep only the class portrait from Blizzard's original frame artwork.
			if frame.GetRegions then
				for _, region in ipairs({ frame:GetRegions() }) do
					if region and region.GetObjectType and region:GetObjectType() == "Texture"
						and region ~= portrait and region ~= frame._suiGladiusCastBackground
						and region ~= (frame.healthbar and frame.healthbar._suiGladiusBackground)
						and region ~= (frame.healthbar and frame.healthbar._suiBarUnderlay) then
						HideArtwork(region)
					end
				end
			end
			local pet = frame.petFrame or _G[name .. "PetFrame"]
			if pet then
				pet:SetAlpha(0)
				if pet.EnableMouse then pet:EnableMouse(false) end
			end
			HideArtwork(_G[name .. "PetFrameTexture"])
			local petBar = EnsurePetBar(frame)
			petBar:ClearAllPoints()
			petBar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -PET_GAP)
			petBar:SetSize(barWidth, PET_HEIGHT)
			petBar.target:SetSize(barWidth + 4, PET_HEIGHT + 4)
			petBar.focus:SetSize(barWidth + 4, PET_HEIGHT + 4)
			local cast = _G[name .. "CastingBar"]
			if cast then
				StyleBar(cast, castWidth, castHeight,
					castLeft and (-castWidth - 11) or (castHeight - 1), castLeft and 0 or -43, frame)
				cast:SetStatusBarColor(1, 1, 0)
				local idleBg = frame._suiGladiusCastBackground
				if not idleBg then
					idleBg = frame:CreateTexture(nil, "BACKGROUND")
					frame._suiGladiusCastBackground = idleBg
				end
				idleBg:SetTexture([[Interface\Buttons\WHITE8X8]])
				idleBg:SetVertexColor(0.6, 0.6, 0.6, 1)
				idleBg:ClearAllPoints()
				idleBg:SetPoint("RIGHT", cast, "RIGHT", 0, 0)
				idleBg:SetSize(castWidth + castHeight, castHeight)
				idleBg:SetAlpha(castLeft and 0 or 0.3)
				local bg = cast._suiGladiusBackground
				bg:ClearAllPoints()
				bg:SetPoint("RIGHT", cast, "RIGHT", 0, 0)
				bg:SetSize(castWidth + castHeight, castHeight)
				-- The left cast background belongs to the native cast bar, so it vanishes when casting ends.
				bg:SetAlpha(castLeft and 0.3 or 0)
				HideArtwork(_G[name .. "CastingBarBorder"])
				HideArtwork(_G[name .. "CastingBarFlash"])
				HideArtwork(_G[name .. "CastingBarText"])
				BarText(cast, "_suiGladiusSpellText", castTextSize, "LEFT", 5, 1)
				BarText(cast, "_suiGladiusTimeText", castTextSize, "RIGHT", -5, 1)
				SuppressTooltip(cast)
				local icon = _G[name .. "CastingBarIcon"]
				if icon then
					icon:ClearAllPoints()
					icon:SetPoint("RIGHT", cast, "LEFT", 0, 0)
					icon:SetSize(castHeight, castHeight)
					icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
				end
				local nativeSpark = _G[name .. "CastingBarSpark"]
				EnsureCastSpark(cast, nativeSpark)
				if cast.GetRegions then
					local fill = cast:GetStatusBarTexture()
					for _, region in ipairs({ cast:GetRegions() }) do
						if region and region.GetObjectType and region:GetObjectType() == "Texture"
							and region ~= fill and region ~= icon and region ~= bg
							and region ~= cast._suiGladiusSpark and region ~= cast._suiGladiusCastShield then
							HideArtwork(region)
						end
					end
				end
				local sample = _G["SarychUIArenaTestCastingBar" .. i]
				if sample and sample._suiGladiusBackground then
					sample._suiGladiusBackground:SetSize(castWidth + castHeight, castHeight)
				end
				if sample and sample._suiGladiusIcon then
					sample._suiGladiusIcon:SetSize(castHeight, castHeight)
				end
				if sample and sample._suiGladiusSpark then
					self:UpdateGladiusSpark(sample)
				end
				if sample and sample._suiGladiusSpellText then
					sample._suiGladiusSpellText:SetFont(STANDARD_TEXT_FONT, castTextSize)
					sample._suiGladiusTimeText:SetFont(STANDARD_TEXT_FONT, castTextSize)
				end
			end
			SuppressTooltip(frame)
			local visual = self._gladiusBorders and self._gladiusBorders[i]
			if visual then
				UpdateBorderGeometry(visual.target, frame)
				UpdateBorderGeometry(visual.focus, frame)
			end
		end
	end
	EnsureVisuals()
	self:ApplyFrameSpacing()
	self:UpdateGladiusVisuals()
end
