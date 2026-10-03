local E, L, C = select(2, ...):unpack()

local DB_VERSION = 4

local function OmniCD_OnEvent(self, event, ...)
	if event == "ADDON_LOADED" then
		local addon = ...
		if addon == E.AddOn or addon == "SarychUI" then
			self:OnInitialize()
			self:UnregisterEvent("ADDON_LOADED")
			self:RegisterEvent("PLAYER_LOGIN")
		end
	elseif event == "PLAYER_LOGIN" then
		E.userGUID = UnitGUID("player") -- 3.3.5: GUID isn't available instantly.
		if OmniCDEnabled ~= false then
			self:OnEnable()
		end
		self:UnregisterEvent("PLAYER_LOGIN")
		self:SetScript("OnEvent", nil)
	end
end

E:RegisterEvent("ADDON_LOADED")
E:SetScript("OnEvent", OmniCD_OnEvent)

function E.FixOldProfile(profile)
	if type(profile) ~= "table" or type(profile.Party) ~= "table" then
		return
	end

	for _, db in pairs(profile.Party) do
		if type(db) == "table" and type(db.extraBars) == "table" then
			for k in pairs(db.extraBars) do
				if not C.Party.arena.extraBars[k] then
					db.extraBars[k] = nil
				end
			end
		end
	end
end

function E:OnInitialize()
	if self._initialized then
		return
	end
	self._initialized = true

	if not OmniCDDB or not OmniCDDB.version or OmniCDDB.version < 2.51 then
		OmniCDDB = { version = DB_VERSION }
	elseif OmniCDDB.version < DB_VERSION then
		if OmniCDDB.cooldowns then
			for k, v in pairs(OmniCDDB.cooldowns) do
				if not v.custom then
					OmniCDDB.cooldowns[k] = nil
				end
			end
			OmniCDDB.cooldowns[6262] = nil
		end
		if OmniCDDB.profiles then
			for _, profile in pairs(OmniCDDB.profiles) do
				if profile.Party then
					profile.Party.customPriority = nil
					for _, zone in pairs(profile.Party) do
						if type(zone) == "table" then
							zone.extraBars = nil
						end
					end
				end
			end
		end
		OmniCDDB.version = DB_VERSION
	else
		if OmniCDDB.profiles then
			for _, profile in pairs(OmniCDDB.profiles) do
				self.FixOldProfile(profile)
			end
		end
	end
	OmniCDDB.cooldowns = OmniCDDB.cooldowns or {}

	self.DB = LibStub("AceDB-3.0"):New("OmniCDDB", self.defaults, true)
	self.DB.RegisterCallback(self, "OnProfileChanged", "Refresh")
	self.DB.RegisterCallback(self, "OnProfileCopied", "Refresh")
	self.DB.RegisterCallback(self, "OnProfileReset", "Refresh")

	self.global = self.DB.global
	self.profile = self.DB.profile

	self.db = E:GetCurrentZoneSettings(select(2, IsInInstance()))

	self:CreateFontObjects()
	self:UpdateSpellList(true)
	if not SarychUI then
		self:SetupBlizzardOptions()
		self:SetupOptions()
	end

end

function E:GetCurrentZoneSettings(instanceType)
	if instanceType == "none" then
		instanceType = self.profile.Party.noneZoneSetting
	elseif instanceType == "scenario" then
		instanceType = self.profile.Party.scenarioZoneSetting
	end
	return self.profile.Party[instanceType]
end

function E:CreateFontObjects()
	self.IconFont = CreateFont("IconFont-OmniCDC")
	self.IconFont:SetFontObject("GameFontHighlightSmallOutline")
	self.AnchorFont = CreateFont("AnchorFont-OmniCDC")
	self.AnchorFont:SetFontObject("GameFontNormal")
	self.StatusBarFont = CreateFont("StatusBarFont-OmniCDC")
	self.StatusBarFont:SetFontObject("GameFontHighlightLarge") -- GameFontHighlight
end

function E:UpdateFontObjects()
	self:SetFontProperties(self.AnchorFont, self.profile.General.fonts.anchor)
	self:SetFontProperties(self.IconFont, self.profile.General.fonts.icon)
	self:SetFontProperties(self.StatusBarFont, self.profile.General.fonts.statusBar)
end

function E:OnEnable()
	if self.isEnabled then
		return
	end
	self.isEnabled = true
	self:LoadAddOns()
	self:SetPixelMult()
	self:Refresh()

	if self.global.loginMessage then
		print(self.LoginMessage)
	end

	if self.global.notifyNew then
		self:EnableVersionCheck()
	end
end

function E:SetPixelMult()
	local pixelMult, uiUnitFactor = E.Libs.OmniCDC:GetPixelMult()
	self.PixelMult = pixelMult
	self.uiUnitFactor = uiUnitFactor
end

function E:Refresh(arg)
	if not self.isEnabled then
		return
	end

	self.profile = self.DB.profile

	self:UpdateFontObjects()

	for moduleName in pairs(self.moduleOptions) do
		local module = self[moduleName]

		local init = module.Initialize
		if init and type(init) == "function" then
			init(module)
			module.Initialize = nil
		end

		local enabled = self:GetModuleEnabled(moduleName)
		if enabled then
			if module.enabled then
				module:Refresh()
			else
				module:Enable()
			end
		else
			module:Disable()
		end
	end

	if arg == "OnProfileReset" then
		self.global.disableElvMsg = nil
	end
end

function E:GetModuleEnabled(moduleName)
	return self.profile.modules[moduleName]
end

function E:SetModuleEnabled(moduleName, isEnabled)
	self.profile.modules[moduleName] = isEnabled

	local module = self[moduleName]
	if isEnabled then
		module:Enable()
	else
		module:Disable()
	end
end

do
	local f
	local currentVersion
	local today
	local groupSize = 0
	local checkEnabled
	local checkTimer

	local function SendVersion()
		if checkEnabled then
			if IsInRaid() then
				C_ChatInfo.SendAddonMessage("OMNICD_VERSION", currentVersion, "RAID")
			elseif IsInGroup() then
				C_ChatInfo.SendAddonMessage("OMNICD_VERSION", currentVersion, "PARTY")
			elseif IsInGuild() then
				C_ChatInfo.SendAddonMessage("OMNICD_VERSION", currentVersion, "GUILD")
			end
		end
		checkTimer = nil
	end

	local function VersionCheck_OnEvent(self, event, prefix, version, _, sender)
		if event == "CHAT_MSG_ADDON" then
			if prefix ~= "OMNICD_VERSION" or sender == E.userNameWithRealm then
				return
			end

			version = tonumber(version)
			if version and version > currentVersion then
				local diff = version - currentVersion
				local text = diff > 10 and L["Major update"] or L["Minor update"]
				text = format(L["A new update is available. |cff99cdff(%s)"], text)
				if E.global.notifyNew then
					E.write(text)
				end
				E.global.updateVersion = version
				E.global.updateType = text
				E.global.updateCheckDate = today

				E:DisableVersionCheck()
			end
		elseif event == "GROUP_ROSTER_UPDATE" then
			local num = GetNumGroupMembers()
			if num and num > groupSize then
				if not checkTimer then
					checkTimer = true
					C_Timer.After(10, SendVersion)
				end
			end
			groupSize = num
		elseif event == "PLAYER_ENTERING_WORLD" then
			if not checkTimer then
				checkTimer = true
				C_Timer.After(10, SendVersion)
			end
		end
	end

	function E:EnableVersionCheck()
		currentVersion = E.Version:gsub("[^%d]", "")
		currentVersion = tonumber(currentVersion)
		today = tonumber(date("%y%m%d"))

		local updateVersion = self.global.updateVersion
		if updateVersion then
			if currentVersion >= updateVersion then
				self.global.updateType = nil
				self.global.updateVersion = nil
			end

			if today == self.global.updateCheckDate then
				return
			end

			if currentVersion < updateVersion then
				if self.global.notifyNew then
					self.write(self.global.updateType)
				end
				return
			end
		end

		checkEnabled = true -- C_ChatInfo.RegisterAddonMessagePrefix("OMNICD_VERSION")
		f = f or CreateFrame("Frame")
		f:RegisterEvent("CHAT_MSG_ADDON")
		f:RegisterEvent("GROUP_ROSTER_UPDATE")
		f:RegisterEvent("PLAYER_ENTERING_WORLD")
		f:SetScript("OnEvent", VersionCheck_OnEvent)
	end

	function E:DisableVersionCheck()
		f:UnregisterEvent("CHAT_MSG_ADDON")
		f:UnregisterEvent("GROUP_ROSTER_UPDATE")
		f:UnregisterEvent("PLAYER_ENTERING_WORLD")
		f:SetScript("OnEvent", nil)
		checkEnabled = nil
	end
end
