-- SarychUI profile architecture
-- Single source of truth: SarychUI.db.profile (AceDB active profile table)

local ADDON_NAME = "SarychUI"
local gsub = string.gsub

local function trimProfileName(name)
	if type(name) ~= "string" then
		return ""
	end
	return gsub(name, "^%s*(.-)%s*$", "%1")
end

local function cloneProfileTable(src)
	if type(src) ~= "table" then
		return src
	end
	local dest = {}
	for k, v in pairs(src) do
		if type(v) == "table" then
			dest[k] = cloneProfileTable(v)
		else
			dest[k] = v
		end
	end
	return dest
end

function SarychUI:GetActiveProfile()
	if self.db and self.db.profile then
		return self.db.profile
	end
	return nil
end

function SarychUI:GetModuleProfile(moduleName)
	local profile = self:GetActiveProfile()
	if not profile or not profile.modules then
		return nil
	end
	return profile.modules[moduleName]
end

function SarychUI:GetAddonProfile(addonName)
	local profile = self:GetActiveProfile()
	if not profile or not profile.addons then
		return nil
	end
	return profile.addons[addonName]
end

-- Legacy pointer only; never read settings from SarychUIDB.profile directly in runtime code.
function SarychUI:SyncLegacyProfileStorage()
	if type(SarychUIDB) ~= "table" or not self.db or not self.db.profile then
		return
	end
	SarychUIDB.profile = self.db.profile
end

function SarychUI:InvalidateModuleProfileCaches()
	local frameModule = self.modules and self.modules.frame
	if frameModule then
		frameModule.db = nil
	end
end

function SarychUI:NotifyProfileOptionsChanged()
	if self.IsPlayerInCombat and self:IsPlayerInCombat() then
		self._pendingOptionsRefresh = true
		return
	end
	-- Custom /sui window: refresh it directly. Do NOT NotifyChange Ace —
	-- that revalidates the whole options tree via AceConfigDialog and freezes.
	if self.OptionsCore and self.OptionsCore._open then
		if self.OptionsCore.Refresh then
			self.OptionsCore:Refresh()
		end
		return
	end
	local reg = LibStub and LibStub("AceConfigRegistry-3.0", true)
	if reg then
		reg:NotifyChange(ADDON_NAME)
	end
end

local function RefreshProfileUI()
	-- Prefer custom options refresh; NotifyProfileOptionsChanged already covers it.
	if SarychUI.OptionsCore and SarychUI.OptionsCore._open and SarychUI.OptionsCore.Refresh then
		SarychUI.OptionsCore:Refresh()
		return
	end
	SarychUI:NotifyProfileOptionsChanged()
end

function SarychUI:GetProfileReloadSignature(profile)
	if type(profile) ~= "table" then
		return ""
	end

	local parts = {}
	local modules = profile.modules or {}
	local bags = modules.bags
	if bags then
		parts[#parts + 1] = "bags:" .. tostring(bags.mode or "classic") .. ":" .. tostring(bags.enabled ~= false)
	end

	local healthIndicators = modules.health_indicators
	if healthIndicators and healthIndicators.nameplateMode then
		parts[#parts + 1] = "np:" .. tostring(healthIndicators.nameplateMode)
	end

	local mapModule = modules.map
	if mapModule and mapModule.mapType then
		parts[#parts + 1] = "map:" .. tostring(mapModule.mapType)
	end

	local addons = profile.addons or {}
	for addonName, addonDb in pairs(addons) do
		if type(addonDb) == "table" then
			parts[#parts + 1] = "addon:" .. tostring(addonName) .. ":" .. tostring(addonDb.enabled ~= false)
			if addonDb.loadMode then
				parts[#parts + 1] = "load:" .. tostring(addonName) .. ":" .. tostring(addonDb.loadMode)
			end
		end
	end

	table.sort(parts)
	return table.concat(parts, ";")
end

function SarychUI:SaveCurrentProfileAs(name)
	name = trimProfileName(name)
	if name == "" then
		return false, "empty"
	end
	if self:IsBuiltinProfile(name) then
		return false, "builtin"
	end

	local source = self:GetActiveProfile()
	if not source then
		return false, "no_db"
	end

	local currentKey = self.db.GetCurrentProfile and self.db:GetCurrentProfile() or nil
	if currentKey == name then
		self:SyncLegacyProfileStorage()
		self:NotifyProfileOptionsChanged()
		return true, "current"
	end

	local profiles = self.db.profiles
	if not profiles and type(SarychUIDB) == "table" then
		SarychUIDB.profiles = SarychUIDB.profiles or {}
		profiles = SarychUIDB.profiles
	end
	if not profiles then
		return false, "no_profiles"
	end

	profiles[name] = cloneProfileTable(source)
	self:SyncLegacyProfileStorage()

	-- Switch to the saved copy so the new profile is selected with current settings
	-- (AceDB SetProfile alone would create an empty/defaults profile instead).
	if self.db.SetProfile then
		self.db:SetProfile(name)
	end

	if self.MarkAddOnOptionsDirty then
		self:MarkAddOnOptionsDirty("profile saved")
	end
	self:NotifyProfileOptionsChanged()

	return true, "saved"
end

-- Inject bundled recommended profiles (e.g. "Sarych") into AceDB so they appear
-- in the profile select next to Default. Re-seeds when BuiltinProfileMeta.revision rises.
function SarychUI:EnsureBuiltinProfiles()
	if type(self.BuiltinProfiles) ~= "table" then
		return
	end
	if type(SarychUIDB) ~= "table" then
		return
	end

	SarychUIDB.profiles = SarychUIDB.profiles or {}
	SarychUIDB.global = SarychUIDB.global or {}
	SarychUIDB.global.builtinProfileRevisions = SarychUIDB.global.builtinProfileRevisions or {}

	local liveProfiles = self.db and self.db.profiles
	for name, data in pairs(self.BuiltinProfiles) do
		if type(name) == "string" and name ~= "" and type(data) == "table" then
			local meta = self.BuiltinProfileMeta and self.BuiltinProfileMeta[name]
			local rev = (type(meta) == "table" and type(meta.revision) == "number" and meta.revision) or 1
			local applied = SarychUIDB.global.builtinProfileRevisions[name]
			local missing = SarychUIDB.profiles[name] == nil
			local outdated = type(applied) ~= "number" or applied < rev
			if missing or outdated then
				local copy = cloneProfileTable(data)
				SarychUIDB.profiles[name] = copy
				if type(liveProfiles) == "table" then
					liveProfiles[name] = cloneProfileTable(data)
				end
				SarychUIDB.global.builtinProfileRevisions[name] = rev
			end
		end
	end
end

function SarychUI:GetBuiltinProfileDisplayName(name)
	if type(name) ~= "string" then
		return name
	end
	local meta = self.BuiltinProfileMeta and self.BuiltinProfileMeta[name]
	if type(meta) == "table" and type(meta.displayName) == "string" and meta.displayName ~= "" then
		return meta.displayName
	end
	return name
end

function SarychUI:IsBuiltinProfile(name)
	return type(name) == "string"
		and type(self.BuiltinProfiles) == "table"
		and type(self.BuiltinProfiles[name]) == "table"
end

function SarychUI:GetCharacterProfileName()
	local name = UnitName and UnitName("player") or nil
	if type(name) ~= "string" or name == "" or name == "Unknown" then
		return nil
	end
	local realm = GetRealmName and GetRealmName() or ""
	if type(realm) == "string" and realm ~= "" then
		return name .. " - " .. realm
	end
	return name
end

local function GetRawGeneral()
	if type(SarychUIDB) ~= "table" then
		return nil
	end
	SarychUIDB.global = SarychUIDB.global or {}
	SarychUIDB.global.general = SarychUIDB.global.general or {}
	return SarychUIDB.global.general
end

local function GetPersonalProfileKeys()
	if type(SarychUIDB) ~= "table" then
		return nil
	end
	SarychUIDB.global = SarychUIDB.global or {}
	SarychUIDB.global.personalProfileKeys = SarychUIDB.global.personalProfileKeys or {}
	return SarychUIDB.global.personalProfileKeys
end

local function GetLiveProfiles(self)
	local profiles = self and self.db and self.db.profiles
	if type(profiles) ~= "table" and type(SarychUIDB) == "table" then
		SarychUIDB.profiles = SarychUIDB.profiles or {}
		profiles = SarychUIDB.profiles
	end
	return profiles
end

function SarychUI:RememberPersonalProfileKey(charKey, profileName)
	if type(charKey) ~= "string" or charKey == "" or charKey == "*" then
		return
	end
	if type(profileName) ~= "string" or profileName == "" then
		return
	end
	local map = GetPersonalProfileKeys()
	if not map or map[charKey] then
		return
	end
	-- Never record the shared profile as this character's home profile.
	if self:GetAlwaysUseProfileEnabled() then
		local shared = self:GetAlwaysUseProfileName()
		if profileName == shared then
			map[charKey] = charKey
			return
		end
	end
	map[charKey] = profileName
end

function SarychUI:GetPersonalProfileKey(charKey)
	if type(charKey) ~= "string" or charKey == "" then
		return nil
	end
	local map = GetPersonalProfileKeys()
	local saved = map and map[charKey]
	if type(saved) == "string" and saved ~= "" then
		return saved
	end
	return charKey
end

-- Copy source settings into this character's profile and switch to it.
-- Used when always-use is off and settings would otherwise dirty a shared/template profile.
function SarychUI:ForkToCharacterProfile(sourceName)
	if not self.db then
		return false
	end
	local charName = self:GetCharacterProfileName()
	if not charName then
		return false
	end

	local current = self.db.GetCurrentProfile and self.db:GetCurrentProfile() or nil
	sourceName = sourceName or current
	if current == charName or sourceName == charName then
		return false
	end

	local profiles = GetLiveProfiles(self)
	if type(profiles) ~= "table" then
		return false
	end

	local source
	if sourceName and sourceName == current then
		source = self:GetActiveProfile()
	elseif sourceName then
		source = profiles[sourceName]
	end
	if type(source) ~= "table" then
		source = self:GetActiveProfile()
	end
	if type(source) ~= "table" then
		return false
	end

	profiles[charName] = cloneProfileTable(source)

	self._suppressAlwaysUseSync = true
	if self.db.SetProfile then
		self.db:SetProfile(charName)
	end
	self._suppressAlwaysUseSync = nil

	if type(SarychUIDB) == "table" then
		SarychUIDB.profileKeys = SarychUIDB.profileKeys or {}
		SarychUIDB.profileKeys[charName] = charName
	end
	local personal = GetPersonalProfileKeys()
	if personal then
		personal[charName] = charName
	end

	if self:IsBuiltinProfile(sourceName) then
		self:SetProfileBuiltinSource(charName, sourceName)
	else
		local inherited = self:GetProfileBuiltinSource(sourceName)
		if inherited then
			self:SetProfileBuiltinSource(charName, inherited)
		end
	end
	return true
end

-- Builtin profiles are read-only templates. Selecting one clones into the
-- character profile ("Name - Realm") so the recommended preset stays pristine.
function SarychUI:ActivateBuiltinProfile(builtinName)
	if not self:IsBuiltinProfile(builtinName) or not self.db then
		return false
	end

	local template = self.BuiltinProfiles[builtinName]
	local profiles = GetLiveProfiles(self)
	if type(profiles) ~= "table" then
		return false
	end

	-- Keep the template slot clean (revision seed / recover from accidental edits).
	profiles[builtinName] = cloneProfileTable(template)

	-- Shared mode: apply the template into the shared profile, not a new per-char clone.
	if self:GetAlwaysUseProfileEnabled() then
		local shared = self:GetAlwaysUseProfileName()
		if type(shared) == "string" and shared ~= "" and shared ~= builtinName and not self:IsBuiltinProfile(shared) then
			profiles[shared] = cloneProfileTable(template)
			self._suppressAlwaysUseSync = true
			if self.db.SetProfile then
				self.db:SetProfile(shared)
			end
			self._suppressAlwaysUseSync = nil
			self:SyncAlwaysUseProfileKey(shared)
			self:SetProfileBuiltinSource(shared, builtinName)
			return true
		end
	end

	local charName = self:GetCharacterProfileName()
	if not charName then
		-- Player name not ready yet — stay on template until login finishes.
		if self.db.SetProfile then
			self.db:SetProfile(builtinName)
		end
		return true
	end

	profiles[charName] = cloneProfileTable(template)
	self._suppressAlwaysUseSync = true
	if self.db.SetProfile then
		self.db:SetProfile(charName)
	end
	self._suppressAlwaysUseSync = nil
	self:SyncAlwaysUseProfileKey(charName)
	self:SetProfileBuiltinSource(charName, builtinName)
	return true
end

function SarychUI:SetProfileBuiltinSource(profileName, builtinName)
	if type(profileName) ~= "string" or profileName == "" then
		return
	end
	if type(SarychUIDB) ~= "table" then
		return
	end
	SarychUIDB.global = SarychUIDB.global or {}
	SarychUIDB.global.profileBuiltinSource = SarychUIDB.global.profileBuiltinSource or {}
	if builtinName then
		SarychUIDB.global.profileBuiltinSource[profileName] = builtinName
	else
		SarychUIDB.global.profileBuiltinSource[profileName] = nil
	end
end

function SarychUI:GetProfileBuiltinSource(profileName)
	if type(profileName) ~= "string" then
		return nil
	end
	if self:IsBuiltinProfile(profileName) then
		return profileName
	end
	local map = SarychUIDB and SarychUIDB.global and SarychUIDB.global.profileBuiltinSource
	if type(map) == "table" then
		return map[profileName]
	end
	return nil
end

-- True while the active profile is the Sarych (2K) template or a clone made from it.
function SarychUI:IsSarych2KProfileContext()
	local cur = self.db and self.db.GetCurrentProfile and self.db:GetCurrentProfile()
	return self:GetProfileBuiltinSource(cur) == "Sarych"
end

-- If somehow still sitting on a builtin profile, fork to the character profile
-- before the next write can dirty the template. When always-use is off, the first
-- edit on a non-personal profile also forks so characters can diverge.
function SarychUI:EnsureWritableProfile(onlyBuiltin)
	if not self.db or not self.db.GetCurrentProfile then
		return false
	end
	local cur = self.db:GetCurrentProfile()
	if self:IsBuiltinProfile(cur) then
		return self:ActivateBuiltinProfile(cur)
	end
	if onlyBuiltin or self:GetAlwaysUseProfileEnabled() then
		return false
	end
	local charName = self:GetCharacterProfileName()
	if not charName or cur == charName then
		return false
	end
	return self:ForkToCharacterProfile(cur)
end

-- Resolve which AceDB profile this character should use from SavedVariables.
-- Per-character by default; shared key "*" is used ONLY when alwaysUseProfile is on.
-- Also clears a stale "*" so it cannot leak across characters after the toggle is off.
function SarychUI_ResolveSavedProfileKey()
	if type(SarychUIDB) ~= "table" then
		return "Default"
	end

	local keys = SarychUIDB.profileKeys
	local alwaysOn = SarychUIDB.global
		and SarychUIDB.global.general
		and SarychUIDB.global.general.alwaysUseProfile == true

	if type(keys) == "table" and not alwaysOn then
		keys["*"] = nil
	end

	if alwaysOn then
		local shared = type(keys) == "table" and keys["*"] or nil
		if type(shared) ~= "string" or shared == "" then
			shared = SarychUIDB.global.general.alwaysUseProfileName
		end
		if type(shared) == "string" and shared ~= "" then
			return shared
		end
	end

	local name = UnitName and UnitName("player")
	local realm = GetRealmName and GetRealmName()
	if name and realm and name ~= "" and name ~= "Unknown" and realm ~= "" then
		local charKey = name .. " - " .. realm
		if type(keys) == "table" then
			local profileKey = keys[charKey]
			if type(profileKey) == "string" and profileKey ~= "" then
				return profileKey
			end
		end
		-- AceDB:New without a defaultProfile uses the character key as the profile name
		-- when profileKeys[char] is missing (not a shared "Default").
		return charKey
	end

	return "Default"
end

function SarychUI:GetAlwaysUseProfileEnabled()
	-- Prefer raw SavedVariables so every character sees the same account-wide flag.
	local raw = GetRawGeneral()
	if raw and raw.alwaysUseProfile == true then
		return true
	end
	if raw and raw.alwaysUseProfile == false then
		return false
	end
	local g = self.db and self.db.global and self.db.global.general
	return g and g.alwaysUseProfile == true
end

function SarychUI:GetAlwaysUseProfileName()
	local raw = GetRawGeneral()
	if raw and type(raw.alwaysUseProfileName) == "string" and raw.alwaysUseProfileName ~= "" then
		return raw.alwaysUseProfileName
	end
	local g = self.db and self.db.global and self.db.global.general
	if g and type(g.alwaysUseProfileName) == "string" and g.alwaysUseProfileName ~= "" then
		return g.alwaysUseProfileName
	end
	if type(SarychUIDB) == "table" and type(SarychUIDB.profileKeys) == "table" then
		local shared = SarychUIDB.profileKeys["*"]
		if type(shared) == "string" and shared ~= "" then
			return shared
		end
	end
	if self.db and self.db.GetCurrentProfile then
		return self.db:GetCurrentProfile()
	end
	return "Default"
end

local function WriteAlwaysUseFlag(self, enabled, profileName)
	local raw = GetRawGeneral()
	if raw then
		raw.alwaysUseProfile = enabled and true or false
		if enabled then
			raw.alwaysUseProfileName = profileName
		else
			raw.alwaysUseProfileName = nil
		end
	end
	if self.db then
		self.db.global = self.db.global or {}
		self.db.global.general = self.db.global.general or {}
		self.db.global.general.alwaysUseProfile = enabled and true or false
		if enabled then
			self.db.global.general.alwaysUseProfileName = profileName
		else
			self.db.global.general.alwaysUseProfileName = nil
		end
	end
	if type(SarychUIDB) == "table" then
		SarychUIDB.profileKeys = SarychUIDB.profileKeys or {}
		if enabled then
			SarychUIDB.profileKeys["*"] = profileName
		else
			SarychUIDB.profileKeys["*"] = nil
		end
	end
end

local function RestorePersonalKeysOnDisable(self, sharedName)
	local keys = type(SarychUIDB) == "table" and SarychUIDB.profileKeys
	if type(keys) ~= "table" then
		return
	end
	local profiles = GetLiveProfiles(self)
	local sharedData = (type(profiles) == "table" and sharedName and profiles[sharedName])
		or (self.GetActiveProfile and self:GetActiveProfile())
	local personal = GetPersonalProfileKeys()
	local charName = self:GetCharacterProfileName()

	for charKey, mapped in pairs(keys) do
		if charKey ~= "*" then
			local restore = personal and personal[charKey]
			local hasOwnProfile = type(restore) == "string"
				and restore ~= ""
				and restore ~= sharedName
				and type(profiles) == "table"
				and type(profiles[restore]) == "table"
			if hasOwnProfile then
				keys[charKey] = restore
			elseif charKey == sharedName then
				keys[charKey] = sharedName
			else
				if type(profiles) == "table" and type(sharedData) == "table" then
					profiles[charKey] = cloneProfileTable(sharedData)
				end
				keys[charKey] = charKey
			end
		end
	end

	if not charName then
		return
	end

	local restore = keys[charName] or charName
	local current = self.db and self.db.GetCurrentProfile and self.db:GetCurrentProfile()
	if current == sharedName and charName ~= sharedName then
		self:ForkToCharacterProfile(sharedName)
	elseif current and current ~= restore then
		if type(profiles) == "table" and type(profiles[restore]) ~= "table" and type(sharedData) == "table" then
			profiles[restore] = cloneProfileTable(sharedData)
		end
		self._suppressAlwaysUseSync = true
		if self.db and self.db.SetProfile then
			self.db:SetProfile(restore)
		end
		self._suppressAlwaysUseSync = nil
	end
	if personal then
		personal[charName] = self.db and self.db.GetCurrentProfile and self.db:GetCurrentProfile() or charName
	end
end

function SarychUI:SetAlwaysUseProfile(enabled, profileName)
	if not self.db then
		return
	end

	local name = profileName
	if type(name) ~= "string" or name == "" then
		name = self.db.GetCurrentProfile and self.db:GetCurrentProfile() or "Default"
	end

	local charName = self:GetCharacterProfileName()
	local current = self.db.GetCurrentProfile and self.db:GetCurrentProfile() or name

	if enabled then
		if self:IsBuiltinProfile(name) then
			self:ActivateBuiltinProfile(name)
			name = self.db.GetCurrentProfile and self.db:GetCurrentProfile() or name
			current = name
		end
		if charName then
			self:RememberPersonalProfileKey(charName, current)
		end
		WriteAlwaysUseFlag(self, true, name)
		if self.db.SetProfile and self.db:GetCurrentProfile() ~= name then
			self.db:SetProfile(name)
		end
	else
		local sharedName = self:GetAlwaysUseProfileName() or current
		-- Clear the global flag first so OnProfileChanged cannot re-arm shared mode.
		WriteAlwaysUseFlag(self, false, nil)
		RestorePersonalKeysOnDisable(self, sharedName)
	end

	self:NotifyProfileOptionsChanged()
end

function SarychUI:SyncAlwaysUseProfileKey(profileName)
	if self._suppressAlwaysUseSync then
		return
	end
	if not self:GetAlwaysUseProfileEnabled() then
		return
	end
	if type(profileName) ~= "string" or profileName == "" then
		return
	end
	if self:IsBuiltinProfile(profileName) then
		return
	end
	WriteAlwaysUseFlag(self, true, profileName)
end

-- Called after AceDB:New so every character either joins the shared profile
-- or stays on its own saved key. Safe to run on any character.
function SarychUI:ApplyAlwaysUseProfileOnLogin()
	if type(SarychUIDB) == "table" and type(SarychUIDB.profileKeys) == "table" and not self:GetAlwaysUseProfileEnabled() then
		SarychUIDB.profileKeys["*"] = nil
		return
	end
	if not self:GetAlwaysUseProfileEnabled() then
		return
	end

	local charName = self:GetCharacterProfileName()
	local current = self.db and self.db.GetCurrentProfile and self.db:GetCurrentProfile() or nil
	if charName and current then
		self:RememberPersonalProfileKey(charName, current)
	end

	local shared = self:GetAlwaysUseProfileName()
	if type(shared) ~= "string" or shared == "" then
		return
	end
	if self:IsBuiltinProfile(shared) then
		self:ActivateBuiltinProfile(shared)
		shared = self.db and self.db.GetCurrentProfile and self.db:GetCurrentProfile() or shared
		WriteAlwaysUseFlag(self, true, shared)
		return
	end
	if self.db and self.db.SetProfile and current ~= shared then
		self.db:SetProfile(shared)
	else
		self:SyncAlwaysUseProfileKey(shared)
	end
end

function SarychUI:CustomizeProfileOptions(profileOpts)
	if not profileOpts or not profileOpts.args then
		return profileOpts
	end

	profileOpts.name = "Профили"

	-- Clone shared AceDBOptions args so we don't mutate the library table.
	local src = profileOpts.args
	local args = {}
	for k, v in pairs(src) do
		if type(v) == "table" then
			local copy = {}
			for kk, vv in pairs(v) do
				copy[kk] = vv
			end
			args[k] = copy
		else
			args[k] = v
		end
	end
	profileOpts.args = args

	-- Details-like layout: current / select / always-use / create / copy / delete.
	-- Hide AceDBOptions verbose intro + reset block.
	if args.desc then
		args.desc.hidden = true
	end
	if args.descreset then
		args.descreset.hidden = true
	end
	if args.reset then
		args.reset.hidden = true
	end
	if args.choosedesc then
		args.choosedesc.hidden = true
	end
	if args.copydesc then
		args.copydesc.hidden = true
	end
	if args.deldesc then
		args.deldesc.hidden = true
	end

	-- 1) Текущий профиль (как в Details)
	if args.current then
		args.current.order = 10
		args.current.type = "description"
		args.current.width = "full"
		args.current.name = function(info)
			local cur
			if info and info.handler and info.handler.GetCurrentProfile then
				cur = info.handler:GetCurrentProfile()
			elseif SarychUI.db and SarychUI.db.GetCurrentProfile then
				cur = SarychUI.db:GetCurrentProfile()
			end
			local label = (SarychUI.T and SarychUI:T("Текущий профиль:")) or "Текущий профиль:"
			return "|cffffd200" .. label .. "|r  " .. tostring(cur or "?")
		end
	else
		args.current = {
			order = 10,
			type = "description",
			width = "full",
			name = function()
				local cur = SarychUI.db and SarychUI.db.GetCurrentProfile and SarychUI.db:GetCurrentProfile() or "?"
				local label = (SarychUI.T and SarychUI:T("Текущий профиль:")) or "Текущий профиль:"
				return "|cffffd200" .. label .. "|r  " .. tostring(cur)
			end,
		}
	end

	local function ListAllProfiles()
		local out = {}
		local function add(name)
			if type(name) == "string" and name ~= "" then
				out[name] = SarychUI:GetBuiltinProfileDisplayName(name) or name
			end
		end

		local db = SarychUI.db
		if db then
			-- AceDB API (may error if profiles metatable is mid-init).
			if type(db.GetProfiles) == "function" then
				local ok, names = pcall(db.GetProfiles, db)
				if ok and type(names) == "table" then
					for _, name in pairs(names) do
						add(name)
					end
				end
			end
			-- Direct keys from AceDB / SavedVariables.
			if type(db.profiles) == "table" then
				for name in pairs(db.profiles) do
					add(name)
				end
			end
			if type(db.GetCurrentProfile) == "function" then
				local ok, cur = pcall(db.GetCurrentProfile, db)
				if ok then
					add(cur)
				end
			end
		end

		if type(SarychUIDB) == "table" and type(SarychUIDB.profiles) == "table" then
			for name in pairs(SarychUIDB.profiles) do
				add(name)
			end
		end

		-- Always keep at least Default so the select is never blank.
		if not next(out) then
			add("Default")
		end
		return out
	end

	local function ListOtherProfiles()
		local out = ListAllProfiles()
		local cur
		if SarychUI.db and type(SarychUI.db.GetCurrentProfile) == "function" then
			local ok, name = pcall(SarychUI.db.GetCurrentProfile, SarychUI.db)
			if ok then
				cur = name
			end
		end
		if cur then
			out[cur] = nil
		end
		return out
	end

	local function HasNoOtherProfiles()
		return not next(ListOtherProfiles())
	end

	local pendingProfile
	local pendingProfileInfo

	-- 2) Выбрать профиль
	if args.choose then
		args.choose.order = 20
		args.choose.name = "Выбрать профиль"
		args.choose.desc = "Выберите профиль, затем нажмите «Применить», чтобы сделать его активным."
		args.choose.width = "normal"
		args.choose.suiCompact = true
		args.choose.suiPlaceholder = "Выберите профиль"
		args.choose.suiSkipWritableProfile = true
		args.choose.values = ListAllProfiles
		args.choose.get = function()
			return pendingProfile
				or (SarychUI.db and SarychUI.db.GetCurrentProfile and SarychUI.db:GetCurrentProfile())
				or nil
		end
		local oldSet = args.choose.set
		args.choose.set = function(info, value)
			pendingProfile = value
			pendingProfileInfo = info
		end

		local function ApplySelectedProfile(info, value)
			-- Applying from the profile selector must activate the exact selected key.
			-- Writable-profile protection still handles later edits independently.
			if SarychUI.db and SarychUI.db.SetProfile then
				SarychUI.db:SetProfile(value)
			elseif type(oldSet) == "string" and info.handler and info.handler[oldSet] then
				info.handler[oldSet](info.handler, info, value)
			elseif type(oldSet) == "function" then
				oldSet(info, value)
			elseif info.handler and info.handler.SetProfile then
				info.handler:SetProfile(info, value)
			end
			SarychUI:SyncAlwaysUseProfileKey(value)
		end

		args.applyProfile = {
			type = "execute",
			name = "Применить",
			desc = "Применить выбранный профиль.",
			order = 21,
			suiSkipWritableProfile = true,
			func = function(info)
				local value = pendingProfile
				if type(value) ~= "string" or value == "" then
					return
				end
				ApplySelectedProfile(pendingProfileInfo or info, value)
				pendingProfile = nil
				pendingProfileInfo = nil
				RefreshProfileUI()
			end,
		}
	end

	-- 3) Использовать на всех персонажах
	args.alwaysUse = {
		type = "toggle",
		name = "Использовать на всех персонажах",
		desc = "Один и тот же профиль будет автоматически применяться ко всем персонажам. Включить и выключить можно с любого персонажа.",
		order = 30,
		width = "full",
		suiSkipWritableProfile = true,
		get = function()
			return SarychUI:GetAlwaysUseProfileEnabled()
		end,
		set = function(_, value)
			local name = SarychUI.db and SarychUI.db.GetCurrentProfile and SarychUI.db:GetCurrentProfile()
			if value and SarychUI:IsBuiltinProfile(name) then
				SarychUI:ActivateBuiltinProfile(name)
				name = SarychUI.db and SarychUI.db.GetCurrentProfile and SarychUI.db:GetCurrentProfile()
			end
			SarychUI:SetAlwaysUseProfile(value, name)
			RefreshProfileUI()
		end,
	}

	-- 4) Сохранить текущие настройки как новый профиль + кнопка «Сохранить»
	if args.new then
		args.new.order = 40
		args.new.name = "Сохранить профиль как"
		args.new.desc = "Введите имя и нажмите «Сохранить»: текущие настройки скопируются в этот профиль, и он сразу станет активным."
		args.new.width = "normal"
		args.new.suiCompact = true
		args.new.suiSaveButton = "Сохранить"
		args.new.set = function(_, value)
			value = trimProfileName(value)
			if value == "" then
				return
			end
			local ok = SarychUI:SaveCurrentProfileAs(value)
			if not ok then
				return
			end
			SarychUI:SyncAlwaysUseProfileKey(value)
			RefreshProfileUI()
		end
	end

	-- 5) Скопировать профиль из
	if args.copyfrom then
		args.copyfrom.order = 50
		args.copyfrom.name = "Скопировать профиль из"
		args.copyfrom.desc = "Скопировать настройки выбранного профиля в текущий активный."
		args.copyfrom.width = "normal"
		args.copyfrom.suiCompact = true
		args.copyfrom.suiPlaceholder = "Выберите профиль"
		args.copyfrom.get = function() return nil end
		args.copyfrom.values = ListOtherProfiles
		args.copyfrom.disabled = HasNoOtherProfiles
		local oldCopy = args.copyfrom.set
		args.copyfrom.set = function(info, value)
			if type(oldCopy) == "string" and info.handler and info.handler[oldCopy] then
				info.handler[oldCopy](info.handler, info, value)
			elseif type(oldCopy) == "function" then
				oldCopy(info, value)
			elseif info.handler and info.handler.CopyProfile then
				info.handler:CopyProfile(info, value)
			elseif SarychUI.db and SarychUI.db.CopyProfile then
				SarychUI.db:CopyProfile(value)
			end
			RefreshProfileUI()
		end
	end

	local function ListDeletableProfiles()
		local out = ListOtherProfiles()
		for name in pairs(out) do
			if SarychUI:IsBuiltinProfile(name) then
				out[name] = nil
			end
		end
		return out
	end

	local function HasNoDeletableProfiles()
		return not next(ListDeletableProfiles())
	end

	-- 6) Удалить
	if args.delete then
		args.delete.order = 60
		args.delete.name = "Удалить"
		args.delete.desc = "Удалить неиспользуемый профиль. Рекомендуемые шаблоны (Sarych) удалить нельзя."
		args.delete.width = "normal"
		args.delete.suiCompact = true
		args.delete.suiPlaceholder = "Выберите профиль"
		args.delete.get = function() return nil end
		args.delete.values = ListDeletableProfiles
		args.delete.disabled = HasNoDeletableProfiles
		args.delete.confirm = true
		args.delete.confirmText = "Удалить выбранный профиль?"
		local oldDel = args.delete.set
		args.delete.set = function(info, value)
			if SarychUI:IsBuiltinProfile(value) then
				return
			end
			if type(oldDel) == "string" and info.handler and info.handler[oldDel] then
				info.handler[oldDel](info.handler, info, value)
			elseif type(oldDel) == "function" then
				oldDel(info, value)
			elseif info.handler and info.handler.DeleteProfile then
				info.handler:DeleteProfile(info, value)
			elseif SarychUI.db and SarychUI.db.DeleteProfile then
				SarychUI.db:DeleteProfile(value)
			end
			RefreshProfileUI()
		end
	end

	-- Wrap all profile controls in one inline block (same visual style as other sections).
	profileOpts.args = {
		profilesBox = {
			type = "group",
			name = "Профили",
			order = 1,
			inline = true,
			suiSelectWithButton = true,
			suiPanelDecorIcon = [[Interface\PVPFrame\Icons\PVP-Banner-Emblem-93]],
			args = args,
		},
	}

	return profileOpts
end

local function RefreshModuleFromProfile(self, name, module)
	if module.RefreshConfig then
		module:RefreshConfig()
		return
	end
	if module.ApplyAllSettings then
		module:ApplyAllSettings()
		return
	end
	if module.ApplySettings then
		module:ApplySettings()
		return
	end
	if module.ApplyMode then
		module:ApplyMode()
		return
	end

	local modDb = self:GetModuleProfile(name)
	if not modDb then
		return
	end
	if modDb.enabled and module.Enable then
		if module.Disable then
			module:Disable()
		end
		module:Enable()
	elseif module.Disable then
		module:Disable()
	end
end

function SarychUI:ApplyModuleProfileState()
	local profile = self:GetActiveProfile()
	if not profile or not self.modules then
		return
	end
	for name, module in pairs(self.modules) do
		RefreshModuleFromProfile(self, name, module)
	end
end

function SarychUI:ApplyCurrentProfile(opts)
	opts = opts or {}

	self:InvalidateModuleProfileCaches()
	self:SyncLegacyProfileStorage()

	if self.ApplyFeatureCoordination then
		self:ApplyFeatureCoordination({
			source = opts.source or "ApplyCurrentProfile",
			refreshPlates = opts.refreshPlates ~= false,
		})
	end

	if opts.fullProfileApply ~= false then
		self:ApplyModuleProfileState()
		if opts.applyAddons and self.ApplyAddOnProfileState then
			self:ApplyAddOnProfileState()
		end
	else
		for name, module in pairs(self.modules or {}) do
			if module.RefreshConfig then
				module:RefreshConfig()
			end
		end
	end

	if opts.fullProfileApply ~= false and self.MarkAddOnOptionsDirty then
		self:MarkAddOnOptionsDirty(opts.reason or "profile apply")
	end

	if self.IsPlayerInCombat and self:IsPlayerInCombat() then
		self._pendingOptionsRefresh = true
		if opts.fullProfileApply ~= false then
			self._pendingProfileRefresh = true
		end
		if self.DebugCombatOptions then
			self:DebugCombatOptions("ApplyCurrentProfile deferred", opts.reason or "combat")
		end
		return false
	end

	if opts.fullProfileApply ~= false then
		self:NotifyProfileOptionsChanged()
	end
	return true
end

function SarychUI:OnProfileShutdown(event, db)
	if db and db.profile then
		self._profileSwitchOldSignature = self:GetProfileReloadSignature(db.profile)
	end
end

function SarychUI:OnProfileChanged(event, db, newProfileKey)
	local oldSignature = self._profileSwitchOldSignature
	self._profileSwitchOldSignature = nil
	local newSignature = self:GetProfileReloadSignature(self:GetActiveProfile())

	if newProfileKey and not self._suppressAlwaysUseSync then
		self:SyncAlwaysUseProfileKey(newProfileKey)
	end

	local applied = self:ApplyCurrentProfile({
		source = "OnProfileChanged",
		refreshPlates = true,
		reason = "profile switch",
		fullProfileApply = true,
		applyAddons = true,
	})

	if applied and oldSignature ~= newSignature and self.ShowReloadPopup then
		self:ShowReloadPopup("Профиль переключён.\n\nДля полного применения части встроенных аддонов может потребоваться /reload.")
	end
end

function SarychUI:OnProfileCopied(event, db, sourceProfileKey)
	self:ApplyCurrentProfile({
		source = "OnProfileCopied",
		refreshPlates = true,
		reason = "profile copied",
		fullProfileApply = true,
		applyAddons = false,
	})
end

function SarychUI:OnProfileReset(event, db)
	self:ApplyCurrentProfile({
		source = "OnProfileReset",
		refreshPlates = true,
		reason = "profile reset",
		fullProfileApply = true,
		applyAddons = true,
	})
end

function SarychUI:RegisterProfileCallbacks()
	if self._profileCallbacksRegistered or not self.db or not self.db.RegisterCallback then
		return
	end

	local sui = self
	self.db.RegisterCallback(self, "OnProfileShutdown", function(event, db)
		sui:OnProfileShutdown(event, db)
	end)
	self.db.RegisterCallback(self, "OnProfileChanged", function(event, db, newProfileKey)
		sui:OnProfileChanged(event, db, newProfileKey)
	end)
	self.db.RegisterCallback(self, "OnProfileCopied", function(event, db, sourceProfileKey)
		sui:OnProfileCopied(event, db, sourceProfileKey)
	end)
	self.db.RegisterCallback(self, "OnProfileReset", function(event, db)
		sui:OnProfileReset(event, db)
	end)

	self._profileCallbacksRegistered = true
end
