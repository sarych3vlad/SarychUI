local E, L, V, P, G = unpack(_G.SarychUI_Bags) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB

--Lua functions
local next, ipairs, pairs = next, ipairs, pairs
local floor, tinsert = math.floor, table.insert
--WoW API / Variables
local GetTime = GetTime
local CreateFrame = CreateFrame
local hooksecurefunc = hooksecurefunc

local ICON_SIZE = 36 --the normal size for an icon (don't change this)
local FONT_SIZE = 20 --the base font size to use at a scale of 1
local MIN_SCALE = 0.5 --the minimum scale we want to show cooldown counts at, anything below this will be hidden
local MIN_DURATION = 1.5 --the minimum duration to show cooldown text for

function E:Cooldown_TextThreshold(cd, now)
	if cd.parent and cd.parent.textThreshold and cd.endTime then
		return (cd.endTime - now) >= cd.parent.textThreshold
	end
end

function E:Cooldown_BelowScale(cd)
	if cd.parent then
		if cd.parent.hideText then return true end
		if cd.parent.skipScale then return end
	end

	return cd.fontScale and (cd.fontScale < MIN_SCALE)
end

function E:Cooldown_OnUpdate(elapsed)
	if self.nextUpdate > 0 then
		self.nextUpdate = self.nextUpdate - elapsed
		return
	end

	if not E:Cooldown_IsEnabled(self) then
		E:Cooldown_StopTimer(self)
	else
		local now = GetTime()
		if self.endCooldown and now >= self.endCooldown then
			E:Cooldown_StopTimer(self)
		else
			if E:Cooldown_BelowScale(self) then
				self.text:SetText("")
				self.nextUpdate = 500
			elseif E:Cooldown_TextThreshold(self, now) then
				self.text:SetText("")
				self.nextUpdate = 1
			elseif self.endTime then
				local value, id, nextUpdate, remainder = E:GetTimeInfo(self.endTime - now, self.threshold, self.hhmmThreshold, self.mmssThreshold)
				self.nextUpdate = nextUpdate

				local style = E.TimeFormats[id]
				if style then
					local which = (self.textColors and 2 or 1) + (self.showSeconds and 0 or 2)
					if self.textColors then
						self.text:SetFormattedText(style[which], value, self.textColors[id], remainder)
					else
						self.text:SetFormattedText(style[which], value, remainder)
					end
				end

				local color = self.timeColors[id]
				if color then
					self.text:SetTextColor(color.r, color.g, color.b)
				end
			end
		end
	end
end

function E:Cooldown_OnSizeChanged(cd, width, force)
	local scale = width and (floor(width + 0.5) / ICON_SIZE)

	-- dont bother updating when the fontScale is the same, unless we are passing the force arg
	if scale and (scale == cd.fontScale) and (force ~= true) then return end
	cd.fontScale = scale

	-- this is needed because of skipScale variable, we wont allow a font size under the minscale
	if cd.fontScale and (cd.fontScale < MIN_SCALE) then
		scale = MIN_SCALE
	end

	if cd.customFont then -- override font
		cd.text:FontTemplate(cd.customFont, (scale * cd.customFontSize), cd.customFontOutline)
	elseif scale then -- default, no override
		cd.text:FontTemplate(nil, (scale * FONT_SIZE), "OUTLINE")
	else -- this should never happen but just incase
		cd.text:FontTemplate()
	end

	if E:Cooldown_BelowScale(cd) then
		cd:Hide()
	elseif cd.enabled then
		self:Cooldown_ForceUpdate(cd)
	end
end

function E:Cooldown_IsEnabled(cd)
	if cd.forceEnabled then
		return true
	elseif cd.forceDisabled then
		return false
	elseif cd.reverseToggle ~= nil then
		return cd.reverseToggle
	else
		return E.db and E.db.cooldown and E.db.cooldown.enable
	end
end

function E:Cooldown_ForceUpdate(cd)
	cd.nextUpdate = -1
	cd:Show()
end

function E:Cooldown_StopTimer(cd)
	cd.enabled = nil
	cd:Hide()
end

function E:Cooldown_Options(timer, db, parent)
	local globalCD = (E.db and E.db.cooldown) or {}
	local threshold, colors, icolors, hhmm, mmss, fonts
	if parent and db and db.override then
		threshold = db.threshold
		icolors = db.useIndicatorColor and E.TimeIndicatorColors[parent.CooldownOverride]
		colors = E.TimeColors[parent.CooldownOverride]
	end

	if db and db.checkSeconds then
		hhmm, mmss = db.hhmmThreshold, db.mmssThreshold
	end

	timer.timeColors = colors or E.TimeColors
	timer.threshold = threshold or globalCD.threshold or E.TimeThreshold
	timer.textColors = icolors or (globalCD.useIndicatorColor and E.TimeIndicatorColors)
	timer.hhmmThreshold = hhmm or (globalCD.checkSeconds and globalCD.hhmmThreshold)
	timer.mmssThreshold = mmss or (globalCD.checkSeconds and globalCD.mmssThreshold)

	if db and db.reverse ~= nil then
		timer.reverseToggle = (globalCD.enable and not db.reverse) or (db.reverse and not globalCD.enable)
	else
		timer.reverseToggle = nil
	end

	if timer.CooldownOverride ~= "auras" then
		if db and (db ~= globalCD) and db.fonts and db.fonts.enable then
			fonts = db.fonts -- custom fonts override default fonts
		elseif globalCD.fonts and globalCD.fonts.enable then
			fonts = globalCD.fonts -- default global font override
		end

		if fonts and fonts.enable then
			timer.customFont = E.Libs.LSM:Fetch("font", fonts.font)
			timer.customFontSize = fonts.fontSize
			timer.customFontOutline = fonts.fontOutline
		else
			timer.customFont = nil
			timer.customFontSize = nil
			timer.customFontOutline = nil
		end
	end
end

function E:CreateCooldownTimer(parent)
	local timer = CreateFrame("Frame", parent:GetName() and "$parentTimer" or nil, parent)
	timer:SetFrameLevel(parent:GetFrameLevel() + 1)
	timer:Hide()
	timer:SetAllPoints()
	timer.parent = parent
	parent.timer = timer

	local text = timer:CreateFontString(nil, "OVERLAY")
	text:Point("CENTER", 1, 1)
	text:SetJustifyH("CENTER")
	timer.text = text

	-- can be used to modify elements created from this function
	if parent.CooldownPreHook then
		parent.CooldownPreHook(parent)
	end

	-- cooldown override settings
	local db = (parent.CooldownOverride and E.db[parent.CooldownOverride]) or E.db
	if db and db.cooldown then
		E:Cooldown_Options(timer, db.cooldown, parent)
	end

	-- keep an eye on the size so we can rescale the font if needed
	self:Cooldown_OnSizeChanged(timer, parent:GetWidth())
	parent:SetScript("OnSizeChanged", function(_, width)
		self:Cooldown_OnSizeChanged(timer, width)
	end)

	-- keep this after Cooldown_OnSizeChanged
	timer:SetScript("OnUpdate", E.Cooldown_OnUpdate)

	return timer
end

E.RegisteredCooldowns = {}
function E:OnSetCooldown(start, duration)
	if (not self.forceDisabled) and (start and duration) and (duration > MIN_DURATION) then
		local timer = self.timer or E:CreateCooldownTimer(self)
		timer.start = start
		timer.duration = duration
		timer.endTime = start + duration
		timer.endCooldown = timer.endTime - 0.05
		timer.nextUpdate = -1
		timer:Show()
	elseif self.timer then
		E:Cooldown_StopTimer(self.timer)
	end
end

function E:RegisterCooldown(cooldown)
	if not cooldown.isHooked then
		hooksecurefunc(cooldown, "SetCooldown", E.OnSetCooldown)
		cooldown.isHooked = true
	end

	if not cooldown.isRegisteredCooldown then
		local module = (cooldown.CooldownOverride or "global")
		if not E.RegisteredCooldowns[module] then E.RegisteredCooldowns[module] = {} end

		tinsert(E.RegisteredCooldowns[module], cooldown)
		cooldown.isRegisteredCooldown = true
	end
end

function E:GetCooldownColors(db)
	local defaults = (E.db and E.db.cooldown) or P.cooldown or {}
	db = db or defaults

	local function indicatorColor(field)
		local c = db[field] or defaults[field]
		if not c then return "|cffeeeeee" end
		return E:RGBToHex(c.r, c.g, c.b)
	end

	local function textColor(field, fallback)
		return db[field] or defaults[field] or fallback
	end

	local c13 = indicatorColor("hhmmColorIndicator")
	local c12 = indicatorColor("mmssColorIndicator")
	local c11 = indicatorColor("expireIndicator")
	local c10 = indicatorColor("secondsIndicator")
	local c9 = indicatorColor("minutesIndicator")
	local c8 = indicatorColor("hoursIndicator")
	local c7 = indicatorColor("daysIndicator")
	local c6 = textColor("hhmmColor", "|cff707070")
	local c5 = textColor("mmssColor", "|cff909090")
	local c4 = textColor("expiringColor", "|cfffe0000")
	local c3 = textColor("secondsColor", "|cffeeeeee")
	local c2 = textColor("minutesColor", "|cffeeeeee")
	local c1 = textColor("hoursColor", "|cffeeeeee")
	local c0 = textColor("daysColor", "|cffeeeeee")
	return c0, c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13
end

function E:UpdateCooldownOverride(module)
	local cooldowns = (module and E.RegisteredCooldowns[module])
	if (not cooldowns) or not next(cooldowns) then return end

	for _, parent in ipairs(cooldowns) do
		local db = (parent.CooldownOverride and E.db[parent.CooldownOverride]) or self.db
		if db and db.cooldown then
			local timer = parent.isHooked and parent.isRegisteredCooldown and parent.timer
			local cd = timer or parent

			-- cooldown override settings
			E:Cooldown_Options(cd, db.cooldown, parent)

			-- update font on cooldowns
			if timer and cd then -- has a parent, these are timers from RegisterCooldown
				self:Cooldown_OnSizeChanged(cd, parent:GetWidth(), true)

			elseif cd.text then
				if cd.customFont then
					cd.text:FontTemplate(cd.customFont, cd.customFontSize, cd.customFontOutline)
				elseif parent.CooldownOverride == "auras" then
					-- parent.auraType defined in `A:UpdateHeader` and `A:CreateIcon`
					local font = E.Libs.LSM:Fetch("font", db.font)
					if font and parent.auraType then
						local fontSize = db[parent.auraType] and db[parent.auraType].durationFontSize
						if fontSize then
							cd.text:FontTemplate(font, fontSize, db.fontOutline)
						end
					end
				end

				-- force update top aura cooldowns
				if parent.CooldownOverride == "auras" then
					parent.nextUpdate = -1
				end
			end
		end
	end
end

function E:UpdateCooldownSettings(module)
	if not E.db or not E.db.cooldown then return end

	local db, timeColors, textColors = E.db.cooldown, E.TimeColors, E.TimeIndicatorColors

	-- update the module timecolors if the config called it but ignore "global" and "all":
	-- global is the main call from config, all is the core file calls
	local isModule = module and (module ~= "global" and module ~= "all") and self.db[module] and self.db[module].cooldown
	if isModule then
		if not E.TimeColors[module] then E.TimeColors[module] = {} end
		if not E.TimeIndicatorColors[module] then E.TimeIndicatorColors[module] = {} end
		db, timeColors, textColors = self.db[module].cooldown, E.TimeColors[module], E.TimeIndicatorColors[module]
	end

	timeColors[0], timeColors[1], timeColors[2], timeColors[3], timeColors[4], timeColors[5], timeColors[6], textColors[0], textColors[1], textColors[2], textColors[3], textColors[4], textColors[5], textColors[6] = self:GetCooldownColors(db)

	if isModule then
		E:UpdateCooldownOverride(module)
	elseif module == "global" then -- this is only a call from the config change
		for key in pairs(E.RegisteredCooldowns) do
			E:UpdateCooldownOverride(key)
		end
	end

	-- okay update the other override settings if it was one of the core file calls
	if module and (module == "all") then
		if self.db.bags and self.db.bags.cooldown then
			E:UpdateCooldownSettings("bags")
		end
	end
end