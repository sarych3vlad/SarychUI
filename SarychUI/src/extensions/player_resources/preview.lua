local CreateFrame = SarychUI.OptionsPool and SarychUI.OptionsPool.CreateFrame or CreateFrame
-- Preview of the player plate using the same bars and profile as the live module.
local module = SarychUI and SarychUI.modules and SarychUI.modules.player_resources
if not module then return end

local preview = { instances = setmetatable({}, { __mode = "k" }) }
SarychUI.PlayerResourcesPreview = preview

local function Profile()
	local db = module:DB()
	return db and db.plate
end

local function IsOn(value)
	return value == 1 or value == true
end

function preview:RefreshAll()
	for host in pairs(self.instances) do
		if host.Refresh then host:Refresh() end
	end
end

function preview:Create(parent)
	local host = CreateFrame("Frame", nil, parent, nil, "player_resources.preview:1")
	host:SetHeight(108)
	host.spacer = host
	host:SetBackdrop({
		bgFile = [[Interface\Buttons\WHITE8X8]],
		edgeFile = [[Interface\Buttons\WHITE8X8]],
		edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 },
	})
	host:SetBackdropColor(0.08, 0.08, 0.08, 0.85)
	host:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

	local plate = CreateFrame("Frame", nil, host, nil, "player_resources.preview:2")
	plate:SetPoint("CENTER", host, "CENTER", 0, 0)
	plate:SetBackdrop({
		bgFile = [[Interface\Buttons\WHITE8X8]],
		edgeFile = [[Interface\Buttons\WHITE8X8]],
		edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 },
	})
	plate:SetBackdropColor(0, 0, 0, 0.55)
	plate:SetBackdropBorderColor(0, 0, 0, 1)

	local health = module:MakeBar(plate)
	local power = module:MakeBar(plate)
	local mana = module:MakeBar(plate)
	mana.text:Hide()

	-- The live health background belongs to the plate so that prediction layers
	-- can sit behind the fill. Use that same layering here.
	health:SetFrameLevel(plate:GetFrameLevel() + 2)
	local healthBg = plate:CreateTexture(nil, "BACKGROUND")
	healthBg:SetTexture([[Interface\Buttons\WHITE8X8]])
	healthBg:SetAllPoints(health)
	health.bg:Hide()
	health.bg = healthBg

	function host:Refresh()
		local cfg = Profile()
		if not cfg then return end
		local width = tonumber(cfg.width) or 150
		local healthHeight = tonumber(cfg.healthHeight) or 14
		local powerHeight = tonumber(cfg.powerHeight) or 6
		local gap = tonumber(cfg.gap) or 0
		local showPower = IsOn(cfg.showPower)
		local _, class = UnitClass("player")
		local showMana = class == "DRUID" and IsOn(cfg.druidMana) and UnitPowerType("player") ~= 0
		local manaHeight = math.max(math.floor(powerHeight * 0.5), 2)
		plate:SetSize(width + 4, healthHeight + 4
			+ (showPower and gap + powerHeight or 0)
			+ (showMana and gap + manaHeight or 0))

		health:SetSize(width, healthHeight)
		health:ClearAllPoints()
		health:SetPoint("TOP", plate, "TOP", 0, -2)
		health:SetMinMaxValues(0, 100)
		health:SetValue(65)
		power:SetSize(width, powerHeight)
		power:ClearAllPoints()
		power:SetPoint("TOP", health, "BOTTOM", 0, -gap)
		power:SetMinMaxValues(0, 100)
		power:SetValue(70)
		if showPower then power:Show() else power:Hide() end
		mana:SetSize(width, manaHeight)
		mana:ClearAllPoints()
		mana:SetPoint("TOP", showPower and power or health, "BOTTOM", 0, -gap)
		mana:SetMinMaxValues(0, 100)
		mana:SetValue(40)
		if showMana then mana:Show() else mana:Hide() end

		local mode = cfg.healthColorMode or "class"
		local r, g, b
		if mode == "health" then
			r, g, b = 0.7, 1, 0 -- sample health is 65%
		elseif mode == "custom" then
			local color = cfg.healthColor or { 0, 0.8, 0 }
			r, g, b = color[1] or 0, color[2] or 0.8, color[3] or 0
		else
			r, g, b = module:ClassRGB()
		end
		module:SetBarColor(health, r, g, b)
		module:SetBarColor(power, module:PowerRGB(UnitPowerType("player")))
		module:SetBarColor(mana, module:PowerRGB(0))

		local align = cfg.textAlign or "right"
		local point = align == "left" and "LEFT" or align == "center" and "CENTER" or "RIGHT"
		local x = point == "LEFT" and 2 or point == "RIGHT" and -2 or 0
		for _, bar in ipairs({ health, power }) do
			bar.text:ClearAllPoints()
			bar.text:SetPoint(point, bar, point, x, 0)
			bar.text:SetJustifyH(string.upper(align))
			module:SetFont(bar.text, tonumber(cfg.fontSize) or 10)
			if IsOn(cfg.showText) then bar.text:Show() else bar.text:Hide() end
		end
		health.text:SetText(cfg.healthText == "value" and "6500" or "65%")
		power.text:SetText("70")
	end

	host:SetScript("OnShow", function(self) self:Refresh() end)
	self.instances[host] = true
	if SarychUI.OptionsPool then
		SarychUI.OptionsPool:OnRelease(host, function() self.instances[host] = nil end)
	end
	host:Refresh()
	return host
end
