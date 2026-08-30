local E, L, V, P, G = unpack(_G.SarychUI_Bags)
local AceDB = E.Libs.AceDB

local CreateFrame = CreateFrame
local UIParent = UIParent
local ReloadUI = ReloadUI
local StaticPopup_Show = StaticPopup_Show
local StaticPopupDialogs = StaticPopupDialogs

E.frames = {}
E.unitFrameElements = {}
E.texts = {}
E.snapBars = {}
E.TexCoords = { 0, 1, 0, 1 }
E.UIParent = UIParent
E.HiddenFrame = CreateFrame("Frame")
E.HiddenFrame:Hide()
E.noop = function() end
E.PopupDialogs = E.PopupDialogs or {}

E.PixelMode = true
E.mult = 1
E.Spacing = 0
E.Border = 1

E.LayoutMoverPositions = {
	ALL = {
		ElvUIBagMover = "BOTTOMRIGHT,RightChatPanel,BOTTOMRIGHT,0,22",
		ElvUIBankMover = "BOTTOMLEFT,LeftChatPanel,BOTTOMLEFT,0,22",
		BagsMover = "TOPRIGHT,RightChatPanel,TOPLEFT,-4,0",
	},
}

if not E.Libs.SimpleSticky then
	E.Libs.SimpleSticky = {
		StartMoving = function(frame)
			frame:StartMoving()
		end,
		StopMoving = function(frame)
			frame:StopMovingOrSizing()
		end,
	}
end

if not _G.ElvUIMoverNudgeWindow then
	local nudge = CreateFrame("Frame", "ElvUIMoverNudgeWindow", UIParent)
	nudge:Hide()
	_G.ElvUIMoverNudgeWindow = nudge
end

function E.AssignFrameToNudge() end
function E:NudgeMover() end
function E:UpdateNudgeFrame() end
function E:ToggleOptionsUI() end

function E:Scale(x)
	local m = E.mult
	return m * math.floor(x / m + 0.5)
end

function E:Print(...)
	if SarychUI and SarychUI.Print then
		SarychUI:Print(...)
	else
		print("|cffffd200SarychUI:|r", ...)
	end
end

function E:CopyTable(current, default)
	if type(current) ~= "table" then current = {} end
	if type(default) == "table" then
		for option, value in pairs(default) do
			if type(value) == "table" then
				current[option] = E:CopyTable(current[option], value)
			else
				current[option] = value
			end
		end
	end
	return current
end

function E:CheckClassColor()
	return false
end

function E:Delay(time, func)
	if C_Timer and C_Timer.After then
		C_Timer.After(time, func)
	else
		local f = CreateFrame("Frame")
		local elapsed = 0
		f:SetScript("OnUpdate", function(self, e)
			elapsed = elapsed + e
			if elapsed >= time then
				self:SetScript("OnUpdate", nil)
				func()
			end
		end)
	end
end

function E:AbbreviateString(str)
	return str
end

function E:Round(n)
	return math.floor(n + 0.5)
end

function E:StaticPopup_Show(name, ...)
	if name == "DELETE_GRAYS" then
		name = "SUIBAGS_DELETE_GRAYS"
	end
	return StaticPopup_Show(name, ...)
end

-- ElvUI/Core/StaticPopups.lua: DELETE_GRAYS stores Money here before StaticPopup_Show.
E.PopupDialogs.DELETE_GRAYS = {
	Money = 0,
}

StaticPopupDialogs.SUIBAGS_DELETE_GRAYS = {
	text = string.format("|cffff0000%s|r", L["Delete gray items?"] or "Delete gray items?"),
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		local B = E:GetModule("Bags", true)
		if B and B.VendorGrays then
			B:VendorGrays(true)
		end
	end,
	OnShow = function(self)
		if self.moneyFrame and E.PopupDialogs.DELETE_GRAYS then
			MoneyFrame_Update(self.moneyFrame, E.PopupDialogs.DELETE_GRAYS.Money)
		end
	end,
	timeout = 4,
	whileDead = 1,
	hideOnEscape = false,
	hasMoneyFrame = 1,
}

function E:RefreshConfig()
	self.db = self.data.profile
	self.global = self.data.global
	self.private = self.privateData.profile

	local B = self:GetModule("Bags", true)
	if B and B.Initialized and B.Layout then
		B.db = self.db.bags
		B:Layout()
	end
end

local function GetSarychUIBagsDB()
	if SarychUI and SarychUI.GetModuleProfile then
		return SarychUI:GetModuleProfile("bags")
	end
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules then
		return SarychUI.db.profile.modules.bags
	end
	return nil
end

function E:ApplySarychUIBagFonts()
	if not self.embeddedInSarychUI or not self.db then return end

	local bagsDb = GetSarychUIBagsDB()
	local fontName = "Arial Narrow"
	if bagsDb and bagsDb.elvui and type(bagsDb.elvui.bagFont) == "string" and bagsDb.elvui.bagFont ~= "" then
		fontName = bagsDb.elvui.bagFont
	end

	if self.db.bags then
		self.db.bags.countFont = fontName
		self.db.bags.itemLevelFont = fontName
		if bagsDb and bagsDb.elvui then
			if bagsDb.elvui.stackFontSize then
				self.db.bags.countFontSize = bagsDb.elvui.stackFontSize
			end
			if bagsDb.elvui.itemLevelFontSize then
				self.db.bags.itemLevelFontSize = bagsDb.elvui.itemLevelFontSize
			end
			local outline = bagsDb.elvui.bagFontOutline or "OUTLINE"
			if outline == "NONE" then outline = "" end
			self.db.bags.countFontOutline = outline
			self.db.bags.itemLevelFontOutline = outline
		end
	end

	if self.UpdateMedia then
		self:UpdateMedia()
	end

	local B = self:GetModule("Bags", true)
	if B and B.ApplyBagFont and (B.BagFrames or B.BagFrame) then
		B:ApplyBagFont()
	end
end

function E:SyncBagsRuntimeFromSarychUI()
	if not self.embeddedInSarychUI then return end
	local bagsDb = GetSarychUIBagsDB()
	if not bagsDb then return end
	local enabled = bagsDb.enabled and bagsDb.mode == "elvui"
	self.private = self.private or (self.privateData and self.privateData.profile) or select(3, unpack(_G.SarychUI_Bags))
	if self.private then

		self.private.bags = self.private.bags or {}
		self.private.bags.enable = enabled
		if self.private.bags then
			self.private.bags.bagBar = false
		end
		if bagsDb.elvui then
			if bagsDb.elvui.vendorGraysAuto ~= nil and self.db and self.db.bags then
				self.db.bags.vendorGrays = self.db.bags.vendorGrays or {}
				self.db.bags.vendorGrays.enable = bagsDb.elvui.vendorGraysAuto and true or false
			end
			if self.db and self.db.bags then
				self.db.bags.disableBagSort = false
				self.db.bags.itemLevel = bagsDb.elvui.showItemLevel == true
				local function clampColumns(v, fallback)
					v = tonumber(v) or fallback
					if v < 6 then v = 6 end
					if v > 14 then v = 14 end
					return math.floor(v + 0.5)
				end
				self.db.bags.bagColumns = clampColumns(bagsDb.elvui.bagColumns, 10)
				self.db.bags.bankColumns = clampColumns(bagsDb.elvui.bankColumns, 10)
				local splitMode = bagsDb.elvui.splitMode
				if splitMode ~= "adibags" then
					splitMode = "classic"
				end
				self.db.bags.splitMode = splitMode
				if bagsDb.elvui.adiBagsCategories == nil then
					self.db.bags.adiBagsCategories = true
				else
					self.db.bags.adiBagsCategories = bagsDb.elvui.adiBagsCategories ~= false
				end
				self.db.bags.consumableSplit = bagsDb.elvui.consumableSplit == true
				self.db.bags.ammoSplit = bagsDb.elvui.ammoSplit == true
				self.db.bags.questSplit = bagsDb.elvui.questSplit == true
			end
		end
	end

	self:ApplySarychUIBagFonts()
end

function E:IsBagsRuntimeEnabled()
	if self.disabledByConflict then return false end
	if not self.private or not self.private.bags then return false end
	return self.private.bags.enable == true
end

function E:TryInitialize()
	if not self.loginReady or self.disabledByConflict or self.initialized then return end
	if self:CheckElvUIConflict() then return end
	if not self:IsBagsRuntimeEnabled() then return end
	self:Initialize()
end

function E:Initialize()
	self.data = AceDB:New("SarychUIElvBagsDB", { profile = P, global = G })
	self.privateData = AceDB:New("SarychUIElvBagsPrivateDB", { profile = V })

	self.data.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
	self.data.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
	self.data.RegisterCallback(self, "OnProfileReset", "RefreshConfig")

	self.db = self.data.profile
	self.global = self.data.global
	self.private = self.privateData.profile

	if self.UpdateMedia then
		self:UpdateMedia()
	end

	if not E.ScanTooltip then
		E.ScanTooltip = CreateFrame("GameTooltip", "SUIBagsScanTooltip", UIParent, "GameTooltipTemplate")
		E.ScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
	end

	self:SyncBagsRuntimeFromSarychUI()
	self.initialized = true
	if self.UpdateCooldownSettings then
		self:UpdateCooldownSettings("all")
	end
	self:InitializeModules()
end

function E:StartBagsRuntime()
	if self.disabledByConflict then return end
	if not self.loginReady then
		self.loginReady = true
	end

	self:SyncBagsRuntimeFromSarychUI()

	self.private = self.private or (self.privateData and self.privateData.profile) or select(3, unpack(_G.SarychUI_Bags))
	if not self.private then return end
	self.private.bags = self.private.bags or {}
	self.private.bags.enable = true

	if not self.initialized then
		self:Initialize()
	end

	if self.ApplyToolkitAPI then
		self:ApplyToolkitAPI()
	end

	local B = self:GetModule("Bags", true)
	if B and B.RestoreActionBarBagButtons then
		B:RestoreActionBarBagButtons()
	end
	if B and B.Initialize then
		if B.Initialized and not B.BagFrame then
			B.Initialized = false
		end
		if not B.Initialized then
			B:Initialize()
		elseif B.BagFrame and B.Layout then
			B:Layout()
		end
		if B.ApplyBagFont then
			B:ApplyBagFont()
		elseif B.ApplyBagWindowFonts then
			B:ApplyBagWindowFonts()
		end
		if self.SetMoversPositions then
			self:SetMoversPositions()
		end
	end
end

function E:ShutdownBagsRuntime()
	local B = self:GetModule("Bags", true)
	if not B then return end
	if not B.Initialized and not B.BagFrame then return end

	if B.CloseBags then B:CloseBags() end
	if B.CloseBank then B:CloseBank() end
	if B.RestoreBlizzard then B:RestoreBlizzard() end
	if B.RestoreActionBarBagButtons then B:RestoreActionBarBagButtons() end
	if B.UnregisterAllEvents then B:UnregisterAllEvents() end
	if B.SortUpdateTimer and B.SortUpdateTimer.Hide then
		B.SortUpdateTimer:Hide()
	end
	if self.private and self.private.bags then
		self.private.bags.enable = false
	end
	B.Initialized = false
end

E.Shutdown = E.ShutdownBagsRuntime

local merchantAutoSell = CreateFrame("Frame")
merchantAutoSell:RegisterEvent("MERCHANT_SHOW")
merchantAutoSell:SetScript("OnEvent", function()
	if not E:IsBagsRuntimeEnabled() then return end
	if not E.db or not E.db.bags or not E.db.bags.vendorGrays or not E.db.bags.vendorGrays.enable then return end
	local B = E:GetModule("Bags", true)
	if B and B.VendorGrays then
		B:VendorGrays()
	end
end)

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
	E.myLocalizedClass, E.myclass = UnitClass("player")
	E.mylevel = UnitLevel("player")
	E.myguid = UnitGUID("player")
	E.loginReady = true
	E:SyncBagsRuntimeFromSarychUI()
end)
