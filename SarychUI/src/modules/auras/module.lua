local SuiTimer = select(2, ...).Compat.Timer
-- SarychUI Auras Module
-- Focus/ToT aura hiding, frame aura sizing, player buff rows, dispel highlight, buff frame management.
-- Extracted from frame so enabling/disabling Frames no longer gates these features.

local pairs = pairs
local moduleName = "auras"
local module = {}

SarychUI:RegisterModule(moduleName, module)

local AceEvent = LibStub("AceEvent-3.0")
local AceBucket = LibStub("AceBucket-3.0")
local AceHook = LibStub("AceHook-3.0")
AceEvent:Embed(module)
AceBucket:Embed(module)
AceHook:Embed(module)

local L = SarychUI.L

local function GetSetting(key, default)
	local db = SarychUI.GetModuleProfile and SarychUI:GetModuleProfile(moduleName)
		or (SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName])
	if db and db[key] ~= nil then
		return db[key]
	end
	return default
end

local function ModuleDB()
	return SarychUI.GetModuleProfile and SarychUI:GetModuleProfile(moduleName)
		or (SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName])
end

--------------------------------------------------------------------
-- Focus / ToT / Target aura hiding
--------------------------------------------------------------------
-- Native aura updates can create/show buttons between bucket callbacks. Enforce
-- visibility in the same call stack, not on a periodic scheduler tick.
local auraVisibilityActive = true
local guardedAuras = {}
local hiddenAuraGroups = {}

local function ShouldHideNamedAuras(prefix)
	local db = ModuleDB()
	local key = prefix == "FocusFrame" and "hideFocusAuras" or "hideTargetAuras"
	return auraVisibilityActive and db and db.enabled and db[key] == 1
end

local function GuardAuraOnShow(button)
	local prefix = guardedAuras[button]
	if prefix and ShouldHideNamedAuras(prefix) then button:Hide() end
end

local function HideNamedAuras(prefix, hide)
	for _, kind in ipairs({"Buff", "Debuff"}) do
		local limit = kind == "Buff" and (MAX_TARGET_BUFFS or 32)
			or math.max(MAX_TARGET_DEBUFFS or 16, MAX_FOCUS_DEBUFFS or 0)
		for i = 1, limit do
			local button = _G[prefix .. kind .. i]
			if button then
				if hide then
					if not guardedAuras[button] then
						guardedAuras[button] = prefix
						button:HookScript("OnShow", GuardAuraOnShow)
					end
					button:Hide()
				end
			end
		end
	end
end

function module:ApplyFrameAuraVisibility(frame)
	local prefix
	if frame and frame == FocusFrame then prefix = "FocusFrame"
	elseif frame and frame == TargetFrame then prefix = "TargetFrame" end
	if prefix and ShouldHideNamedAuras(prefix) then HideNamedAuras(prefix, true) end
end

local function UpdateNamedAuraVisibility(prefix)
	local hide = ShouldHideNamedAuras(prefix)
	local wasHidden = hiddenAuraGroups[prefix]
	hiddenAuraGroups[prefix] = hide
	HideNamedAuras(prefix, hide)
	if wasHidden and not hide then
		-- Let the renderer show only occupied slots when hiding is switched off.
		local frame = _G[prefix]
		local update = prefix == "FocusFrame" and FocusFrame_UpdateAuras or TargetFrame_UpdateAuras
		if frame and update then update(frame) end
	end
end

function module:UpdateFocusAuras()
	auraVisibilityActive = true
	UpdateNamedAuraVisibility("FocusFrame")
end

function module:UpdateTargetAuras()
	self:UpdateFocusAuras()
	UpdateNamedAuraVisibility("TargetFrame")
end

function module:UpdateToTAuras()
	local db = ModuleDB()
	if not db or not db.enabled then
		return
	end

	if GetSetting("hideTargetOfTargetAuras", 0) == 1 then
		for _, v in pairs({ "TargetFrameToTDebuff", "FocusFrameToTDebuff" }) do
			for i = 1, 4 do
				local aura = _G[v .. i]
				if aura then
					aura:Hide()
					aura:SetScale(1e-4)
					aura:SetAlpha(0)
					aura.Show = function() end
				end
			end
		end
	else
		for _, v in pairs({ "TargetFrameToTDebuff", "FocusFrameToTDebuff" }) do
			for i = 1, 4 do
				local aura = _G[v .. i]
				if aura then
					aura:SetScale(1)
					aura:SetAlpha(1)
					aura.Show = nil
					aura:Show()
				end
			end
		end
	end
end

function module:ForceUpdateAuras()
	self:UpdateTargetAuras()
	self:UpdateToTAuras()
end

function module:RestoreAuras()
	auraVisibilityActive = false
	hiddenAuraGroups = {}

	for _, v in pairs({ "TargetFrameToTDebuff", "FocusFrameToTDebuff" }) do
		for i = 1, 4 do
			local aura = _G[v .. i]
			if aura then
				aura:SetScale(1)
				aura:SetAlpha(1)
				aura.Show = nil
				aura:Show()
			end
		end
	end
end

--------------------------------------------------------------------
-- Target / Focus aura size (RougeUI BuffSizer)
--------------------------------------------------------------------
local AURA_OFFSET_Y = 1
local AURA_START_X = 5
local mabs, mfloor, mceil = math.abs, math.floor, math.ceil
local auraCountFontName

local PLAYER_UNITS = {
	player = true,
	vehicle = true,
	pet = true,
}

local largeBuffList = {}
local largeDebuffList = {}

local function AddonLoaded(name)
	return IsAddOnLoaded and IsAddOnLoaded(name)
end

local function SettingOn(key)
	local v = GetSetting(key, 0)
	return v == 1 or v == true
end

local function UseCustomAuraSize()
	return SettingOn("changeFrameAuraSize")
end

local function AurasGrowUp()
	return SettingOn("frameAurasGrowUp")
end

local function GrowUpStartY()
	local y = tonumber(GetSetting("frameAurasGrowUpY", -17))
	if y == nil then return -17 end
	return y
end

local function CustomFrameAuraLayout()
	return UseCustomAuraSize() or AurasGrowUp()
end

local function GetFramePosition(frame)
	if not frame then
		return 0, 0
	end
	return frame:GetLeft() or 0, frame:GetBottom() or 0
end

local function ShouldAuraBeLarge(caster)
	if not caster then
		return false
	end
	if PLAYER_UNITS[caster] then
		return true
	end
	if UnitIsUnit then
		for token in pairs(PLAYER_UNITS) do
			if UnitIsUnit(caster, token) then
				return true
			end
		end
	end
	return false
end

local function ApplyAuraCountFont(frameName, size)
	local frameCount = _G[frameName .. "Count"]
	if not frameCount or not frameCount.SetFont then
		return
	end
	if not auraCountFontName then
		auraCountFontName = frameCount.GetFont and frameCount:GetFont()
	end
	if auraCountFontName then
		frameCount:SetFont(auraCountFontName, size / 1.75, "OUTLINE")
	end
end

local function UpdateBuffAnchor(frame, buffName, index, numDebuffs, anchorIndex, size, offsetX, offsetY)
	local growUp = AurasGrowUp()
	local point, relativePoint, startY = "TOP", "BOTTOM", 32
	if growUp then
		point, relativePoint, startY = "BOTTOM", "TOP", GrowUpStartY()
	end
	local stackY = growUp and offsetY or -offsetY
	local buff = _G[buffName .. index]
	if not buff then return end
	buff:ClearAllPoints()

	if index == 1 then
		if UnitIsFriend("player", frame.unit) or numDebuffs == 0 then
			buff:SetPoint(point .. "LEFT", frame, relativePoint .. "LEFT", AURA_START_X, startY)
		else
			local debuffs = frame.debuffs
			if debuffs then
				local _, a = debuffs:GetPoint()
				if a then
					local _, b = a:GetPoint()
					if b == frame.buffs then
						debuffs:ClearAllPoints()
						debuffs:SetPoint(point .. "LEFT", frame, point .. "LEFT", 0, 0)
						debuffs:SetPoint(relativePoint .. "LEFT", frame, relativePoint .. "LEFT", 0, growUp and AURA_OFFSET_Y or -AURA_OFFSET_Y)
					end
				end
				buff:SetPoint(point .. "LEFT", debuffs, relativePoint .. "LEFT", 0, stackY)
			else
				local firstDebuff = _G[(frame:GetName() or "") .. "Debuff1"]
				if firstDebuff then
					buff:SetPoint(point .. "LEFT", firstDebuff, relativePoint .. "LEFT", 0, stackY)
				else
					buff:SetPoint(point .. "LEFT", frame, relativePoint .. "LEFT", AURA_START_X, startY)
				end
			end
		end
		if frame.buffs then
			frame.buffs:ClearAllPoints()
			frame.buffs:SetPoint(point .. "LEFT", buff, point .. "LEFT", 0, 0)
			frame.buffs:SetPoint(relativePoint .. "LEFT", buff, relativePoint .. "LEFT", 0, growUp and AURA_OFFSET_Y or -AURA_OFFSET_Y)
		end
		if not growUp then
			frame.spellbarAnchor = buff
		end
	elseif anchorIndex ~= (index - 1) then
		buff:SetPoint(point .. "LEFT", _G[buffName .. anchorIndex], relativePoint .. "LEFT", 0, stackY)
		if frame.buffs then
			frame.buffs:SetPoint(relativePoint .. "LEFT", buff, relativePoint .. "LEFT", 0, growUp and AURA_OFFSET_Y or -AURA_OFFSET_Y)
		end
		if not growUp then
			frame.spellbarAnchor = buff
		end
	else
		buff:SetPoint(point .. "LEFT", _G[buffName .. anchorIndex], point .. "RIGHT", offsetX, 0)
	end

	buff:SetWidth(size)
	buff:SetHeight(size)
end

local function UpdateDebuffAnchor(frame, debuffName, index, numBuffs, anchorIndex, size, offsetX, offsetY)
	local buff = _G[debuffName .. index]
	if not buff then return end
	buff:ClearAllPoints()
	local isFriend = UnitIsFriend("player", frame.unit)
	local growUp = AurasGrowUp()
	local point, relativePoint, startY = "TOP", "BOTTOM", 32
	if growUp then
		point, relativePoint, startY = "BOTTOM", "TOP", GrowUpStartY()
	end
	local stackY = growUp and offsetY or -offsetY

	if index == 1 then
		if isFriend and numBuffs > 0 then
			local buffs = frame.buffs or _G[(frame:GetName() or "") .. "Buff1"]
			if buffs then
				buff:SetPoint(point .. "LEFT", buffs, relativePoint .. "LEFT", 0, stackY)
			else
				buff:SetPoint(point .. "LEFT", frame, relativePoint .. "LEFT", AURA_START_X, startY)
			end
		else
			buff:SetPoint(point .. "LEFT", frame, relativePoint .. "LEFT", AURA_START_X, startY)
		end
		if frame.debuffs then
			frame.debuffs:ClearAllPoints()
			frame.debuffs:SetPoint(point .. "LEFT", buff, point .. "LEFT", 0, 0)
			frame.debuffs:SetPoint(relativePoint .. "LEFT", buff, relativePoint .. "LEFT", 0, growUp and AURA_OFFSET_Y or -AURA_OFFSET_Y)
		end
		if isFriend or (not isFriend and numBuffs == 0) then
			if not growUp then
				frame.spellbarAnchor = buff
			end
		end
	elseif anchorIndex ~= (index - 1) then
		buff:SetPoint(point .. "LEFT", _G[debuffName .. anchorIndex], relativePoint .. "LEFT", 0, stackY)
		if frame.debuffs then
			frame.debuffs:SetPoint(relativePoint .. "LEFT", buff, relativePoint .. "LEFT", 0, growUp and AURA_OFFSET_Y or -AURA_OFFSET_Y)
		end
		if isFriend or (not isFriend and numBuffs == 0) then
			if not growUp then
				frame.spellbarAnchor = buff
			end
		end
	else
		buff:SetPoint(point .. "LEFT", _G[debuffName .. (index - 1)], point .. "RIGHT", offsetX, 0)
	end

	buff:SetWidth(size)
	buff:SetHeight(size)
	local debuffFrame = _G[debuffName .. index .. "Border"]
	if debuffFrame then
		debuffFrame:SetWidth(size + 2)
		debuffFrame:SetHeight(size + 2)
	end
end

local function TargetBuffSize(frame, auraName, numAuras, numOppositeAuras, largeAuraList, updateFunc, maxRowWidth, offsetX)
	local LARGE_AURA_SIZE = UseCustomAuraSize() and GetSetting("frameAuraSelfSize", 23) or 21
	local SMALL_AURA_SIZE = UseCustomAuraSize() and GetSetting("frameAuraOtherSize", 23) or 17
	local size, biggestAura
	local offsetY = AURA_OFFSET_Y
	local rowWidth = 0
	local firstBuffOnRow = 1
	local totFrame = frame.totFrame
	local growUp = AurasGrowUp()
	local haveTargetofTarget = (not growUp) and totFrame and totFrame.IsShown and totFrame:IsShown()
	local totFrameX, totFrameBottom = GetFramePosition(totFrame)
	local currentX, currentY

	if UseCustomAuraSize() then
		maxRowWidth = GetSetting("frameAuraRowWidth", 122)
	end

	for i = 1, numAuras do
		if largeAuraList[i] then
			size = LARGE_AURA_SIZE
			offsetY = AURA_OFFSET_Y + AURA_OFFSET_Y
		else
			size = SMALL_AURA_SIZE
		end

		if i == 1 then
			rowWidth = size
			frame.auraRows = (frame.auraRows or 0) + 1
			if frame.largestAura then
				offsetY = frame.largestAura
			end
		else
			rowWidth = rowWidth + size + offsetX
		end

		local verticalDistance = currentY and (currentY - totFrameBottom) or 0
		local horizontalDistance = rowWidth
		if currentX then
			horizontalDistance = mfloor(mabs((currentX + size + offsetX) - totFrameX)) + 5
		end

		if (haveTargetofTarget and horizontalDistance < size and verticalDistance > 0) or (rowWidth > maxRowWidth) then
			local anchorAura = _G[auraName .. firstBuffOnRow]
			local anchorW = anchorAura and (anchorAura.GetWidth and anchorAura:GetWidth() or 0) or 0
			if biggestAura and anchorAura then
				if biggestAura >= mfloor(anchorW + 0.5) then
					offsetY = (AURA_OFFSET_Y * 2) + (biggestAura - anchorW)
				end
			end
			updateFunc(frame, auraName, i, numOppositeAuras, firstBuffOnRow, size, offsetX, offsetY)
			rowWidth = size
			frame.auraRows = (frame.auraRows or 0) + 1
			firstBuffOnRow = i
			offsetY = AURA_OFFSET_Y
			biggestAura = nil
			frame.largestAura = nil
		else
			updateFunc(frame, auraName, i, numOppositeAuras, i - 1, size, offsetX, offsetY)
		end

		if not biggestAura or biggestAura < size then
			biggestAura = size
		end

		local firstAura = _G[auraName .. firstBuffOnRow]
		if firstAura then
			local firstW = firstAura.GetWidth and firstAura:GetWidth() or 0
			local calc = (AURA_OFFSET_Y * 2) + (biggestAura - firstW)
			if not frame.largestAura or frame.largestAura < calc then
				frame.largestAura = calc
			end
		end

		local aura = _G[auraName .. i]
		if aura then
			currentX, currentY = aura:GetLeft(), aura:GetTop()
		end
	end
end

local function AdjustTargetSpellbar(spellbar)
	if not spellbar then return end
	local parentFrame = spellbar.GetParent and spellbar:GetParent()
	if not parentFrame then return end

	if spellbar.boss then
		spellbar:SetPoint("TOPLEFT", parentFrame, "BOTTOMLEFT", 25, 10)
	elseif parentFrame.haveToT then
		if parentFrame.buffsOnTop or (parentFrame.auraRows or 0) <= 1 then
			spellbar:SetPoint("TOPLEFT", parentFrame, "BOTTOMLEFT", 25, -25)
		elseif parentFrame.spellbarAnchor then
			spellbar:SetPoint("TOPLEFT", parentFrame.spellbarAnchor, "BOTTOMLEFT", 20, -15)
		else
			spellbar:SetPoint("TOPLEFT", parentFrame, "BOTTOMLEFT", 25, -25)
		end
	elseif parentFrame.haveElite then
		if parentFrame.buffsOnTop or (parentFrame.auraRows or 0) <= 1 then
			spellbar:SetPoint("TOPLEFT", parentFrame, "BOTTOMLEFT", 25, -5)
		elseif parentFrame.spellbarAnchor then
			spellbar:SetPoint("TOPLEFT", parentFrame.spellbarAnchor, "BOTTOMLEFT", 20, -15)
		else
			spellbar:SetPoint("TOPLEFT", parentFrame, "BOTTOMLEFT", 25, -5)
		end
	else
		if (not parentFrame.buffsOnTop) and (parentFrame.auraRows or 0) > 0 and parentFrame.spellbarAnchor then
			spellbar:SetPoint("TOPLEFT", parentFrame.spellbarAnchor, "BOTTOMLEFT", 20, -15)
		else
			spellbar:SetPoint("TOPLEFT", parentFrame, "BOTTOMLEFT", 25, 7)
		end
	end
end

function module:LayoutFrameAuras(frame)
	if not frame or (frame ~= TargetFrame and frame ~= FocusFrame) then
		return
	end
	if not CustomFrameAuraLayout() then
		return
	end

	local unit = frame.unit
	if not unit then
		unit = (frame == FocusFrame) and "focus" or "target"
		frame.unit = unit
	end
	if not UnitExists or not UnitExists(unit) then
		return
	end

	local selfName = frame:GetName()
	if not selfName then return end

	local growUp = AurasGrowUp()

	frame.buffs = frame.buffs or _G[selfName .. "Buffs"]
	frame.debuffs = frame.debuffs or _G[selfName .. "Debuffs"]
	if not frame.totFrame then
		if frame == TargetFrame then
			frame.totFrame = TargetofTargetFrame
		elseif frame == FocusFrame then
			frame.totFrame = FocusFrameToT
		end
	end
	frame.spellbar = frame.spellbar or _G[selfName .. "SpellBar"]

	local isEnemy = UnitIsEnemy and UnitIsEnemy("player", unit)
	local customSize = UseCustomAuraSize()
	local numBuffs = 0
	local maxBuffs = frame.maxBuffs or 32

	for i = 1, maxBuffs do
		local name, _, icon, _, _, _, _, caster = self:ReadFrameAura(frame, i, "HELPFUL")
		if not name then break end
		if icon then
			local largeSize = ShouldAuraBeLarge(caster)
			local buffSize = largeSize and (customSize and GetSetting("frameAuraSelfSize", 23) or 21) or (customSize and GetSetting("frameAuraOtherSize", 23) or 17)
			local frameName = selfName .. "Buff" .. i
			if customSize then
				ApplyAuraCountFont(frameName, buffSize)
				local stealable = _G[frameName .. "Stealable"]
				if stealable then
					stealable:SetHeight(buffSize * 1.2)
					stealable:SetWidth(buffSize * 1.2)
				end
			end
			numBuffs = numBuffs + 1
			largeBuffList[numBuffs] = largeSize
		end
	end

	local numDebuffs = 0
	local maxDebuffs = frame.maxDebuffs or 16
	for i = 1, maxDebuffs do
		local debuffName, _, icon, _, _, _, _, caster = self:ReadFrameAura(frame, i, "HARMFUL")
		if not debuffName then break end
		if icon then
			local largeSize = ShouldAuraBeLarge(caster)
			local buffSize = largeSize and (customSize and GetSetting("frameAuraSelfSize", 23) or 21) or (customSize and GetSetting("frameAuraOtherSize", 23) or 17)
			if customSize then
				ApplyAuraCountFont(selfName .. "Debuff" .. i, buffSize)
			end
			numDebuffs = numDebuffs + 1
			largeDebuffList[numDebuffs] = largeSize
		end
	end

	frame.auraRows = 0
	frame.largestAura = 0
	frame.spellbarAnchor = nil

	local maxRowWidth = customSize and GetSetting("frameAuraRowWidth", 122) or 122
	local xOffset = 3

	if isEnemy then
		TargetBuffSize(frame, selfName .. "Debuff", numDebuffs, numBuffs, largeDebuffList, UpdateDebuffAnchor, maxRowWidth, xOffset)
		TargetBuffSize(frame, selfName .. "Buff", numBuffs, numDebuffs, largeBuffList, UpdateBuffAnchor, maxRowWidth, xOffset)
	else
		TargetBuffSize(frame, selfName .. "Buff", numBuffs, numDebuffs, largeBuffList, UpdateBuffAnchor, maxRowWidth, xOffset)
		TargetBuffSize(frame, selfName .. "Debuff", numDebuffs, numBuffs, largeDebuffList, UpdateDebuffAnchor, maxRowWidth, xOffset)
	end

	if growUp then
		frame.auraRows = 0
		-- Native aura updates already anchored the castbar to the last aura row.
		-- Moving that row above the frame moves the bar too; restore the same
		-- native position used on castbar OnShow, including its layout hooks.
		if frame.spellbar and Target_Spellbar_AdjustPosition then
			Target_Spellbar_AdjustPosition(frame.spellbar)
		end
	elseif frame.spellbar then
		AdjustTargetSpellbar(frame.spellbar)
	end
end

--------------------------------------------------------------------
-- Player buffs per row (RougeUI BuffsRow)
--------------------------------------------------------------------
local function SeparatePlayerAuraPositioning()
	return GetSetting("manageBuffs", 0) == 1
		and GetSetting("playerAuraPositionMode", "together") == "separate"
end

local function NormalizePlayerAuraGrowth(value)
	return value == "left_to_right" and "left_to_right" or "right_to_left"
end

local function PlayerBuffGrowthDirection()
	if GetSetting("manageBuffs", 0) ~= 1 then
		return "right_to_left"
	end
	if SeparatePlayerAuraPositioning() then
		return NormalizePlayerAuraGrowth(GetSetting("playerBuffGrowthDirection", "right_to_left"))
	end
	return NormalizePlayerAuraGrowth(GetSetting("playerAuraGrowthDirection", "right_to_left"))
end

local function PlayerDebuffGrowthDirection()
	if GetSetting("manageBuffs", 0) ~= 1 then
		return "right_to_left"
	end
	if SeparatePlayerAuraPositioning() then
		return NormalizePlayerAuraGrowth(GetSetting("playerDebuffGrowthDirection", "right_to_left"))
	end
	return NormalizePlayerAuraGrowth(GetSetting("playerAuraGrowthDirection", "right_to_left"))
end

local function FrameIsShown(frame)
	return frame and (not frame.IsShown or frame:IsShown())
end

local function PlayerAuraButtonsPerRow()
	if SettingOn("changePlayerBuffRow") then
		local count = tonumber(GetSetting("playerBuffsPerRow", 8)) or 8
		if count > 0 then
			return count
		end
	end
	return BUFFS_PER_ROW or 8
end

local function PlayerBuffGrowthOrigin()
	return ConsolidatedBuffs or TemporaryEnchantFrame or BuffFrame
end

local function ConsolidatedBuffsTakesSlot()
	if not FrameIsShown(ConsolidatedBuffs) then
		return false
	end
	if BuffFrame and type(BuffFrame.numConsolidated) == "number" then
		return BuffFrame.numConsolidated > 0
	end
	if ShouldShowConsolidatedBuffFrame then
		return not not ShouldShowConsolidatedBuffFrame()
	end
	return true
end

local function IsCollapsedPlayerBuff(buff)
	if not buff then
		return true
	end
	if buff.consolidated then
		return true
	end
	local parent = buff.GetParent and buff:GetParent()
	if not parent then
		return false
	end
	if ConsolidatedBuffsContainer and parent == ConsolidatedBuffsContainer then
		return true
	end
	if ConsolidatedBuffsTooltip and parent == ConsolidatedBuffsTooltip then
		return true
	end
	return false
end

local function CollectVisiblePlayerBuffs(includeEnchants)
	local frames = {}
	if includeEnchants then
		if FrameIsShown(TempEnchant1) then
			frames[#frames + 1] = TempEnchant1
		end
		if FrameIsShown(TempEnchant2) then
			frames[#frames + 1] = TempEnchant2
		end
	end
	local maxBuffs = BUFF_MAX_DISPLAY or 32
	for index = 1, maxBuffs do
		local buff = _G["BuffButton" .. index]
		if FrameIsShown(buff) and not IsCollapsedPlayerBuff(buff) then
			frames[#frames + 1] = buff
		end
	end
	return frames
end

local function CollectLeftToRightPlayerBuffs()
	local frames = {}
	if ConsolidatedBuffsTakesSlot() then
		frames[#frames + 1] = ConsolidatedBuffs
	end
	local visible = CollectVisiblePlayerBuffs(true)
	for index = 1, #visible do
		frames[#frames + 1] = visible[index]
	end
	return frames
end

local function VisiblePlayerBuffSlotCount(includeEnchants)
	return #CollectLeftToRightPlayerBuffs()
end

local function RestoreTemporaryEnchantGrowth()
	if TempEnchant1 and TemporaryEnchantFrame then
		TempEnchant1:ClearAllPoints()
		TempEnchant1:SetPoint("TOPRIGHT", TemporaryEnchantFrame, "TOPRIGHT", 0, 0)
	end
	if TempEnchant2 and TempEnchant1 then
		TempEnchant2:ClearAllPoints()
		TempEnchant2:SetPoint("RIGHT", TempEnchant1, "LEFT", -5, 0)
	end
end

local playerDebuffAnchor

local function EnsurePlayerDebuffAnchor()
	if playerDebuffAnchor then
		return playerDebuffAnchor
	end

	playerDebuffAnchor = CreateFrame("Frame", "SarychUIPlayerDebuffAnchor", UIParent)
	playerDebuffAnchor:SetWidth(50)
	playerDebuffAnchor:SetHeight(50)
	playerDebuffAnchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -205, -105)
	if BuffFrame and BuffFrame.GetFrameStrata then
		playerDebuffAnchor:SetFrameStrata(BuffFrame:GetFrameStrata())
	end
	return playerDebuffAnchor
end

local function PlayerDebuffsPerRow()
	return PlayerAuraButtonsPerRow()
end

function module:LayoutPlayerBuffsLeftToRight()
	if AddonLoaded("SimpleAuraFilter") or PlayerBuffGrowthDirection() ~= "left_to_right" then
		return
	end

	local origin = PlayerBuffGrowthOrigin()
	if not origin then return end
	local frames = CollectLeftToRightPlayerBuffs()
	local perRow = PlayerAuraButtonsPerRow()
	local rowSpacing = BUFF_ROW_SPACING or 15

	for index, frame in ipairs(frames) do
		-- The consolidate icon is also the mover; do not rip it off its saved point.
		if frame ~= origin then
			frame:ClearAllPoints()
			if index == 1 then
				frame:SetPoint("TOPLEFT", origin, "TOPLEFT", 0, 0)
			elseif ((index - 1) % perRow) == 0 then
				local above = frames[index - perRow]
				if above then
					frame:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -rowSpacing)
				end
			else
				frame:SetPoint("LEFT", frames[index - 1], "RIGHT", 5, 0)
			end
		end
	end
end

function module:LayoutCombinedPlayerDebuffsLeftToRight()
	if AddonLoaded("SimpleAuraFilter") or SeparatePlayerAuraPositioning()
		or PlayerDebuffGrowthDirection() ~= "left_to_right" then
		return
	end

	local origin = PlayerBuffGrowthOrigin()
	if not origin then return end
	local perRow = PlayerAuraButtonsPerRow()
	local rowSpacing = BUFF_ROW_SPACING or 15
	local buffCount = VisiblePlayerBuffSlotCount(true)
	local buffRows = math.max(1, mceil(buffCount / perRow))
	local startY = -buffRows * (30 + rowSpacing)
	local visibleDebuffs = {}
	local maxDebuffs = DEBUFF_MAX_DISPLAY or 16

	for index = 1, maxDebuffs do
		local debuff = _G["DebuffButton" .. index]
		if FrameIsShown(debuff) then
			visibleDebuffs[#visibleDebuffs + 1] = debuff
		end
	end

	for index, debuff in ipairs(visibleDebuffs) do
		debuff:ClearAllPoints()
		if index == 1 then
			debuff:SetPoint("TOPLEFT", origin, "TOPLEFT", 0, startY)
		elseif ((index - 1) % perRow) == 0 then
			local above = visibleDebuffs[index - perRow]
			debuff:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -rowSpacing)
		else
			debuff:SetPoint("LEFT", visibleDebuffs[index - 1], "RIGHT", 6, 0)
		end
	end
end

function module:LayoutSeparatePlayerDebuffs()
	if AddonLoaded("SimpleAuraFilter") or not SeparatePlayerAuraPositioning() or not BuffFrame then
		return
	end

	local anchor = EnsurePlayerDebuffAnchor()
	local perRow = PlayerDebuffsPerRow()
	local rowSpacing = BUFF_ROW_SPACING or 15
	local maxDebuffs = DEBUFF_MAX_DISPLAY or 16
	local leftToRight = PlayerDebuffGrowthDirection() == "left_to_right"

	for index = 1, maxDebuffs do
		local debuff = _G["DebuffButton" .. index]
		if debuff then
			if debuff:GetParent() ~= anchor then
				debuff:SetParent(anchor)
			end
			debuff:SetScale(1)
			debuff:ClearAllPoints()
			if index == 1 then
				if leftToRight then
					debuff:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
				else
					debuff:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, 0)
				end
			elseif (index % perRow) == 1 then
				local above = _G["DebuffButton" .. (index - perRow)]
				if above then
					if leftToRight then
						debuff:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -rowSpacing)
					else
						debuff:SetPoint("TOPRIGHT", above, "BOTTOMRIGHT", 0, -rowSpacing)
					end
				end
			else
				local previous = _G["DebuffButton" .. (index - 1)]
				if previous then
					if leftToRight then
						debuff:SetPoint("LEFT", previous, "RIGHT", 5, 0)
					else
						debuff:SetPoint("RIGHT", previous, "LEFT", -5, 0)
					end
				end
			end
		end
	end
end

function module:RestoreCombinedPlayerDebuffs(refresh)
	if not BuffFrame then return end
	local maxDebuffs = DEBUFF_MAX_DISPLAY or 16
	local restored = false

	for index = 1, maxDebuffs do
		local debuff = _G["DebuffButton" .. index]
		if debuff and playerDebuffAnchor and debuff:GetParent() == playerDebuffAnchor then
			debuff:SetParent(BuffFrame)
			debuff:SetScale(1)
			debuff:ClearAllPoints()
			restored = true
		end
	end

	if refresh and restored then
		if BuffFrame_Update then
			pcall(BuffFrame_Update)
		elseif DebuffButton_UpdateAnchors then
			for index = 1, maxDebuffs do
				if _G["DebuffButton" .. index] then
					pcall(DebuffButton_UpdateAnchors, "DebuffButton", index)
				end
			end
		end
	end
end

function module:OnBuffFrameUpdateAllBuffAnchors()
	if not BuffFrame then
		return
	end
	if AddonLoaded("SimpleAuraFilter") then
		return
	end
	if PlayerBuffGrowthDirection() == "left_to_right" then
		self:LayoutPlayerBuffsLeftToRight()
		return
	end
	if not SettingOn("changePlayerBuffRow") then
		return
	end

	local buff, previousBuff, aboveBuff
	local numBuffs = 0
	local BUFFS_PER_ROW = GetSetting("playerBuffsPerRow", 8)
	if BUFFS_PER_ROW < 1 then BUFFS_PER_ROW = 1 end
	local slack = BuffFrame.numEnchants or 0
	if BuffFrame.numConsolidated and BuffFrame.numConsolidated > 0 then
		slack = slack + 1
	end
	local rowSpacing = BUFF_ROW_SPACING or 15
	local actual = BUFF_ACTUAL_DISPLAY or 0

	for i = 1, actual do
		buff = _G["BuffButton" .. i]
		if buff and not buff.consolidated then
			numBuffs = numBuffs + 1
			local index = numBuffs + slack
			buff:ClearAllPoints()
			if index > 1 and (index % BUFFS_PER_ROW) == 1 then
				if index == BUFFS_PER_ROW + 1 and ConsolidatedBuffs then
					buff:SetPoint("TOPRIGHT", ConsolidatedBuffs, "BOTTOMRIGHT", 0, -rowSpacing - 3)
				elseif aboveBuff then
					buff:SetPoint("TOPRIGHT", aboveBuff, "BOTTOMRIGHT", 0, -rowSpacing)
				end
				aboveBuff = buff
			elseif index == 1 then
				buff:SetPoint("TOPRIGHT", BuffFrame, "TOPRIGHT", 0, 0)
				aboveBuff = buff
			else
				if numBuffs == 1 then
					if (BuffFrame.numEnchants or 0) > 0 and TemporaryEnchantFrame then
						buff:SetPoint("TOPRIGHT", TemporaryEnchantFrame, "TOPLEFT", -5, 0)
						aboveBuff = TemporaryEnchantFrame
					elseif ConsolidatedBuffs then
						buff:SetPoint("TOPRIGHT", ConsolidatedBuffs, "TOPLEFT", -5, 0)
					end
				elseif previousBuff then
					buff:SetPoint("RIGHT", previousBuff, "LEFT", -5, 0)
				end
			end
			previousBuff = buff
		end
	end
end

function module:OnBuffButtonUpdateAnchors()
	if PlayerBuffGrowthDirection() == "left_to_right" then
		self:LayoutPlayerBuffsLeftToRight()
	end
end

function module:OnBuffFrameEnchantUpdated()
	if self._playerBuffGrowthDirection ~= "left_to_right" then
		self._playerEnchantGrowthMask = nil
		return
	end
	local mask = (FrameIsShown(TempEnchant1) and 1 or 0) + (FrameIsShown(TempEnchant2) and 2 or 0)
	if self._playerEnchantGrowthMask == mask then return end
	self._playerEnchantGrowthMask = mask
	self:LayoutPlayerBuffsLeftToRight()
	if not self._playerAurasSeparate then
		self:LayoutCombinedPlayerDebuffsLeftToRight()
	end
end

function module:OnDebuffButtonUpdateAnchors(buttonName, index)
	if AddonLoaded("SimpleAuraFilter") then
		return
	end
	if SeparatePlayerAuraPositioning() then
		self:LayoutSeparatePlayerDebuffs()
		return
	end
	if PlayerDebuffGrowthDirection() == "left_to_right" then
		self:LayoutCombinedPlayerDebuffsLeftToRight()
		return
	end
	if not SettingOn("changePlayerBuffRow") or not BuffFrame then
		return
	end
	if not buttonName or not index then
		return
	end

	local numBuffs = (BUFF_ACTUAL_DISPLAY or 0) + (BuffFrame.numEnchants or 0)
	local BUFFS_PER_ROW = GetSetting("playerBuffsPerRow", 8)
	if BUFFS_PER_ROW < 1 then BUFFS_PER_ROW = 1 end
	if BuffFrame.numConsolidated and BuffFrame.numConsolidated > 0 then
		numBuffs = numBuffs - BuffFrame.numConsolidated + 1
	end

	local rows = mceil(numBuffs / BUFFS_PER_ROW)
	local buff = _G[buttonName .. index]
	if not buff then return end
	local rowSpacing = BUFF_ROW_SPACING or 15

	buff:ClearAllPoints()
	if index > 1 and (index % BUFFS_PER_ROW) == 1 then
		buff:SetPoint("TOP", _G[buttonName .. (index - BUFFS_PER_ROW)], "BOTTOM", 0, -rowSpacing)
	elseif index == 1 then
		local offsetY
		if rows < 2 then
			offsetY = (2 * rowSpacing) + 30
		else
			offsetY = rows * (rowSpacing + 30)
		end
		buff:SetPoint("TOPRIGHT", BuffFrame, "BOTTOMRIGHT", 0, -offsetY)
	else
		buff:SetPoint("RIGHT", _G[buttonName .. (index - 1)], "LEFT", -6, 0)
	end
end

function module:OnFrameAuraLayoutUpdated(frame)
	self:ApplyFrameAuraVisibility(frame)
	-- TargetFrame_UpdateAuras is also used by protected boss frames.  Keep the
	-- layout restricted to the two frames owned here.
	if CustomFrameAuraLayout() and (frame == TargetFrame or frame == FocusFrame) then
		self:LayoutFrameAuras(frame)
	end
end

-- Run the original FrameXML function with a private aura reader. Its private
-- consolidated list, tooltip and anchors remain owned by Blizzard; global
-- UnitAura and the user's CVar are never replaced.
function module:ApplyBlacklistVisibilitySettings()
    local db = ModuleDB()
    local cfg = db and db.blacklistVisibility
    local extension = SarychUI.extensions and SarychUI.extensions.visibility_control
    local bindings = SarychUI_ToggleBindings
    local key = bindings and bindings:NormalizeKey(cfg and cfg.key)
    local groups = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules.group_frames
    local enabled = ((db and db.enabled and (db.playerAuraBlacklistEnabled or db.frameAuraBlacklistEnabled))
        or (groups and groups.enabled ~= false and groups.auraBlacklistEnabled))
        and cfg and (cfg.enabled == true or cfg.enabled == 1)
        and (not extension or extension:IsEnabled()) and key ~= nil
    local wasShown = self._showBlacklistedAuras
    if not enabled then
        self._showBlacklistedAuras = nil
    elseif not self._blacklistVisibilityEnabled or self._blacklistVisibilityProfile ~= db then
        -- Match the other visibility controllers: start visible, first press hides.
        self._showBlacklistedAuras = true
    end
    local restore = (wasShown and true or false) ~= (self._showBlacklistedAuras and true or false)
    self._blacklistVisibilityProfile = db
    self._blacklistVisibilityEnabled = enabled and true or false
    if bindings then
        if enabled then
            bindings:SetAction("player_aura_blacklist_visibility", key, function()
                if not self._blacklistVisibilityEnabled then return end
                self._showBlacklistedAuras = not self._showBlacklistedAuras
                self._playerAuraSlots = nil
                if self.RefreshAuraLayout then self:RefreshAuraLayout() elseif BuffFrame_Update then BuffFrame_Update() end
                local groupModule = SarychUI.modules and SarychUI.modules.group_frames
                if groupModule and groupModule.RefreshBlacklistAuras then groupModule:RefreshBlacklistAuras() end
                return self._showBlacklistedAuras and "igMiniMapZoomIn" or "igMiniMapZoomOut"
            end)
        else
            bindings:RemoveAction("player_aura_blacklist_visibility")
        end
    end
    if restore then
        self._playerAuraSlots = nil
        if self.RefreshAuraLayout then self:RefreshAuraLayout() elseif BuffFrame_Update then BuffFrame_Update() end
        local groupModule = SarychUI.modules and SarychUI.modules.group_frames
        if groupModule and groupModule.RefreshBlacklistAuras then groupModule:RefreshBlacklistAuras() end
    end
end

function module:IsConsolidationException(id)
    if not id then return false end
    local db = ModuleDB()
    local entries = db and db.consolidationExceptions
    if not entries then return false end
    local tracking = SarychUI.AuraTracking
    if self._consolidationExceptionEntries ~= entries or not self._consolidationExceptionIndex then
        self._consolidationExceptionEntries = entries
        self._consolidationExceptionIndex = tracking:BuildSpellIndex(entries)
    end
    return tracking:ResolveSpell(entries, id, self._consolidationExceptionIndex) == true
end

function module:IsPlayerAuraBlocked(id, filter, onFrame)
    local db = ModuleDB()
    if not (db and db.enabled and (onFrame and db.frameAuraBlacklistEnabled or not onFrame and db.playerAuraBlacklistEnabled) and id) then return false end
    local key = onFrame and (filter == "HELPFUL" and "frameBuffBlacklist" or "frameDebuffBlacklist")
        or (filter == "HELPFUL" and "playerBuffBlacklist" or "playerDebuffBlacklist")
    local entries = db[key]
    if not entries then return false end
    self._playerAuraBlacklistIndexes = self._playerAuraBlacklistIndexes or {}
    local cached = self._playerAuraBlacklistIndexes[key]
    if not cached or cached.entries ~= entries then
        cached = { entries = entries, names = SarychUI.AuraTracking:BuildSpellIndex(entries) }
        self._playerAuraBlacklistIndexes[key] = cached
    end
    return SarychUI.AuraTracking:ResolveSpell(entries, id, cached.names) == true
end

function module:UpdateConsolidatedAura(buttonName, index, filter)
    local original = self.hooks.AuraButton_Update
    local db = ModuleDB()
    local playerButton = buttonName == "BuffButton" and filter == "HELPFUL"
        or buttonName == "DebuffButton" and filter == "HARMFUL"
    local consolidate = db and db.enabled and db.consolidateForeignBuffs
        and buttonName == "BuffButton" and filter == "HELPFUL" and CONSOLIDATE_BUFFS == "1"
    local blacklist = db and db.enabled and db.playerAuraBlacklistEnabled and not self._showBlacklistedAuras and playerButton
    if not consolidate and not blacklist then return original(buttonName, index, filter) end
    -- Secure hooks can replace the native Lua renderer with a C closure.
    -- Its environment cannot be changed; keep native rendering functional
    -- rather than aborting BuffFrame_Update (or replacing global UnitAura).
    if self._unfilterableAuraRenderer == original then
        return original(buttonName, index, filter)
    end
    local unit = PlayerFrame and PlayerFrame.unit or "player"
    local environment = getfenv(original)
    local readAura = environment.UnitAura
    local nativeIndex = index
    if blacklist then
        -- Blizzard lays out contiguous button slots. Keep the real aura index
        -- separately for tooltip updates and right-click cancellation.
        self._playerAuraSlots = self._playerAuraSlots or {}
        if index == 1 or not self._playerAuraSlots[filter] then
            local slots = {}
            for i = 1, (filter == "HELPFUL" and BUFF_MAX_DISPLAY or DEBUFF_MAX_DISPLAY) or 32 do
                local name, _, _, _, _, _, _, _, _, _, id = readAura(unit, i, filter)
                if not name then break end
                if not self:IsPlayerAuraBlocked(id, filter) then slots[#slots+1] = i end
            end
            self._playerAuraSlots[filter] = slots
        end
        nativeIndex = self._playerAuraSlots[filter][index]
    end
    local function FilterAura(auraUnit, auraIndex, auraFilter, ...)
        if auraUnit ~= unit or auraIndex ~= index or auraFilter ~= filter then
            return readAura(auraUnit, auraIndex, auraFilter, ...)
        end
        if not nativeIndex then return nil end
        local function Result(...)
            local values, count = {...}, select("#", ...)
            if consolidate and values[1] then
                local caster = values[8]
                local own = caster and (caster == "player" or caster == "pet" or caster == "vehicle"
                    or (UnitIsUnit and (UnitIsUnit(caster, "player") or UnitIsUnit(caster, "pet") or UnitIsUnit(caster, unit))))
                values[10] = self:IsConsolidationException(values[11]) or not own
                count = math.max(count, 10)
            end
            return unpack(values, 1, count)
        end
        return Result(readAura(auraUnit, nativeIndex, auraFilter, ...))
    end
    local private = setmetatable({UnitAura = FilterAura}, {__index = environment, __newindex = environment})
    local canFilter = pcall(setfenv, original, private)
    if not canFilter then
        self._unfilterableAuraRenderer = original
        self._playerAuraSlots = nil
        return original(buttonName, index, filter)
    end
    local ok, result = pcall(original, buttonName, index, filter)
    setfenv(original, environment)
    if not ok then error(result, 0) end
    local buff = _G[buttonName .. index]
    if buff then
        if result and nativeIndex then
            buff:SetID(nativeIndex)
            if GameTooltip and GameTooltip:IsOwned(buff) then GameTooltip:SetUnitAura(unit, nativeIndex, filter) end
        else
            -- timeLeft and its updater are one state. A recycled permanent
            -- aura skips Blizzard's timer cleanup when timeLeft is already nil.
            buff:SetScript("OnUpdate", nil)
            buff.consolidated, buff.timeLeft, buff.exitTime = nil, nil, nil
        end
        if consolidate and buff.consolidated then buff.exitTime = nil end
    end
    return result
end

function module:OnConsolidationCVarUpdate(event, name)
    name = type(name) == "string" and name:lower() or ""
    if name ~= "consolidatebuffs" and name ~= "consolidate_buffs_text" then return end
    CONSOLIDATE_BUFFS = GetCVar("consolidateBuffs")
    if CONSOLIDATE_BUFFS ~= "1" and self.consolidationExceptionsWindow and self.consolidationExceptionsWindow.listKey == "consolidationExceptions" then self.consolidationExceptionsWindow:Hide() end
    if BuffFrame_Update then BuffFrame_Update() end
    if SarychUI.NotifySarychUIOptionsChange then SarychUI:NotifySarychUIOptionsChange() end
    if SarychUI.OptionsCore and SarychUI.OptionsCore.ScheduleSmartRefresh then
        SarychUI.OptionsCore:ScheduleSmartRefresh(true)
    end
end

-- Filter the native readers before Blizzard fills contiguous display slots.
-- Actual aura indices remain on buttons for tooltips and cooldown readers.
function module:ReadFrameAura(frame, index, filter)
    local slots = self._frameAuraSlots and self._frameAuraSlots[frame]
    local indices = slots and slots[filter]
    if indices then
        index = indices[index]
        if not index then return nil end
    end
    local reader = filter == "HELPFUL" and UnitBuff or UnitDebuff
    return reader(frame.unit or (frame == FocusFrame and "focus" or "target"), index)
end

-- FrameXML rendering with module-owned Lua functions. Secure-hook wrappers
-- may be C functions, so their environments must never be changed.
do
-- These are file-local in Blizzard TargetFrame.lua, not exported globals.
local AURA_ROW_WIDTH, NUM_TOT_AURA_ROWS = 122, 2
local PLAYER_UNITS = {player = true, vehicle = true, pet = true}
local largeBuffList, largeDebuffList = {}, {}
local function RenderFilteredTargetAuras(self)
	local frame, frameName;
	local frameIcon, frameCount, frameCooldown;
	local name, rank, icon, count, debuffType, duration, expirationTime, caster, isStealable;
	local frameStealable;
	local numBuffs = 0;
	local playerIsTarget = UnitIsUnit(PlayerFrame.unit, self.unit);
	local selfName = self:GetName();

	for i = 1, MAX_TARGET_BUFFS do
		name, rank, icon, count, debuffType, duration, expirationTime, caster, isStealable = UnitBuff(self.unit, i);
		frameName = selfName.."Buff"..i;
		frame = _G[frameName];
		if ( not frame ) then
			if ( not icon ) then
				break;
			else
				frame = CreateFrame("Button", frameName, self, "TargetBuffFrameTemplate");
				frame.unit = self.unit;
			end
		end
		if ( icon and ( not self.maxBuffs or i <= self.maxBuffs ) ) then
			frame:SetID(i);

			-- set the icon
			frameIcon = _G[frameName.."Icon"];
			frameIcon:SetTexture(icon);

			-- set the count
			frameCount = _G[frameName.."Count"];
			if ( count > 1 and self.showAuraCount ) then
				frameCount:SetText(count);
				frameCount:Show();
			else
				frameCount:Hide();
			end
			
			-- Handle cooldowns
			frameCooldown = _G[frameName.."Cooldown"];
			if ( duration > 0 ) then
				frameCooldown:Show();
				CooldownFrame_SetTimer(frameCooldown, expirationTime - duration, duration, 1);
			else
				frameCooldown:Hide();
			end

			-- Show stealable frame if the target is not a player and the buff is stealable.
			frameStealable = _G[frameName.."Stealable"];
			if ( not playerIsTarget and isStealable ) then
				frameStealable:Show();
			else
				frameStealable:Hide();
			end

			-- set the buff to be big if the target is not the player and the buff is cast by the player or his pet
			largeBuffList[i] = (not playerIsTarget and PLAYER_UNITS[caster]);

			numBuffs = numBuffs + 1;

			frame:ClearAllPoints();
			frame:Show();
		else
			frame:Hide();
		end
	end

	local color;
	local frameBorder;
	local numDebuffs = 0;
	local isEnemy = UnitCanAttack("player", self.unit);
	for i = 1, MAX_TARGET_DEBUFFS do
		name, rank, icon, count, debuffType, duration, expirationTime, caster = UnitDebuff(self.unit, i);
		frameName = selfName.."Debuff"..i;
		frame = _G[frameName];
		if ( not frame ) then
			if ( not icon ) then
				break;
			else
				frame = CreateFrame("Button", frameName, self, "TargetDebuffFrameTemplate");
				frame.unit = self.unit;
			end
		end
		if ( icon and ( not self.maxDebuffs or i <= self.maxDebuffs ) and ( SHOW_CASTABLE_DEBUFFS == "0" or not isEnemy or caster == "player" or caster == "vehicle") ) then
			frame:SetID(i);

			-- set the icon
			frameIcon = _G[frameName.."Icon"];
			frameIcon:SetTexture(icon);

			-- set the count
			frameCount = _G[frameName.."Count"];
			if ( count > 1 and self.showAuraCount ) then
				frameCount:SetText(count);
				frameCount:Show();
			else
				frameCount:Hide();
			end

			-- Handle cooldowns
			frameCooldown = _G[frameName.."Cooldown"];
			if ( duration > 0 ) then
				frameCooldown:Show();
				CooldownFrame_SetTimer(frameCooldown, expirationTime - duration, duration, 1);
			else
				frameCooldown:Hide();
			end

			-- set debuff type color
			if ( debuffType ) then
				color = DebuffTypeColor[debuffType];
			else
				color = DebuffTypeColor["none"];
			end
			frameBorder = _G[frameName.."Border"];
			frameBorder:SetVertexColor(color.r, color.g, color.b);

			-- set the debuff to be big if the buff is cast by the player or his pet
			largeDebuffList[i] = (PLAYER_UNITS[caster]);

			numDebuffs = numDebuffs + 1;

			frame:ClearAllPoints();
			frame:Show();
		else
			frame:Hide();
		end
	end
	
	self.auraRows = 0;
	local haveTargetofTarget;
	if ( self.totFrame ) then
		haveTargetofTarget = self.totFrame:IsShown();
	end
	self.spellbarAnchor = nil;
	local maxRowWidth;
	-- update buff positions
	maxRowWidth = ( haveTargetofTarget and self.TOT_AURA_ROW_WIDTH ) or AURA_ROW_WIDTH;
	TargetFrame_UpdateAuraPositions(self, selfName.."Buff", numBuffs, numDebuffs, largeBuffList, TargetFrame_UpdateBuffAnchor, maxRowWidth, 3);
	-- update debuff positions
	maxRowWidth = ( haveTargetofTarget and self.auraRows < NUM_TOT_AURA_ROWS and self.TOT_AURA_ROW_WIDTH ) or AURA_ROW_WIDTH;
	TargetFrame_UpdateAuraPositions(self, selfName.."Debuff", numDebuffs, numBuffs, largeDebuffList, TargetFrame_UpdateDebuffAnchor, maxRowWidth, 4);
	-- update the spell bar position
	if ( self.spellbar ) then
		Target_Spellbar_AdjustPosition(self.spellbar);
	end
end

local function RenderFilteredDebuffs(frame, unit, numDebuffs, suffix, checkCVar)
	local frameName = frame:GetName();

	frame.hasDispellable = nil;

	numDebuffs = numDebuffs or MAX_PARTY_DEBUFFS;
	suffix = suffix or "Debuff";

	local unitStatus, statusColor;
	local debuffTotal = 0;
	local name, rank, icon, count, debuffType, duration, expirationTime, caster;
	local isEnemy = UnitCanAttack("player", unit);	
	for i=1, numDebuffs do
		if ( unit == "party"..i ) then
			unitStatus = _G[frameName.."Status"];
		end

		local filter;
		if ( checkCVar and GetCVarBool("showDispelDebuffs") ) then
			filter = "RAID";
		end
		name, rank, icon, count, debuffType, duration, expirationTime, caster = UnitDebuff(unit, i, filter);

		local debuffName = frameName..suffix..i;
		if ( icon and ( SHOW_CASTABLE_DEBUFFS == "0" or not isEnemy or caster == "player" ) ) then
			-- if we have an icon to show then proceed with setting up the aura

			-- set the icon
			local debuffIcon = _G[debuffName.."Icon"];
			debuffIcon:SetTexture(icon);

			-- setup the border
			local debuffBorder = _G[debuffName.."Border"];
			local debuffColor = DebuffTypeColor[debuffType] or DebuffTypeColor["none"];
			debuffBorder:SetVertexColor(debuffColor.r, debuffColor.g, debuffColor.b);

			-- record interesting data for the aura button
			statusColor = debuffColor;
			frame.hasDispellable = 1;
			debuffTotal = debuffTotal + 1;

			-- setup the cooldown
			local coolDown = _G[debuffName.."Cooldown"];
			if ( coolDown ) then
				CooldownFrame_SetTimer(coolDown, expirationTime - duration, duration, 1);
			end

			-- show the aura
			_G[debuffName]:Show();
		else
			-- no icon, hide the aura
			_G[debuffName]:Hide();
		end
	end

	frame.debuffTotal = debuffTotal;
	-- Reset unitStatus overlay graphic timer
	if ( frame.numDebuffs and debuffTotal >= frame.numDebuffs ) then
		frame.debuffCountdown = 30;
	end
	if ( unitStatus and statusColor ) then
		unitStatus:SetVertexColor(statusColor.r, statusColor.g, statusColor.b);
	end
end
module.frameAuraRenderers = {TargetFrame_UpdateAuras = RenderFilteredTargetAuras, RefreshDebuffs = RenderFilteredDebuffs}
end

function module:UpdateFilteredFrameAuras(hook, frame, unit, ...)
    local original = self.hooks[hook]
    local owned = frame and (frame == TargetFrame or frame == FocusFrame
        or frame == TargetFrameToT or frame == FocusFrameToT or frame == TargetofTargetFrame or frame == TargetofFocusFrame)
    if not owned then return original(frame, unit, ...) end
    unit = unit or frame.unit or (frame == FocusFrame and "focus" or "target")
    local db = ModuleDB()
    local enabled = db and db.enabled and db.frameAuraBlacklistEnabled and not self._showBlacklistedAuras
    self._frameAuraSlots = self._frameAuraSlots or {}
    local slots = enabled and {} or nil
    self._frameAuraSlots[frame] = slots
    -- Preserve the original update and every pre-existing secure hook.
    local result
    if hook == "RefreshDebuffs" then result = original(frame, unit, ...)
    else result = original(frame) end
    local renderer = self.frameAuraRenderers[hook]
    local environment = getfenv(renderer)
    local function Reader(reader, filter)
        return function(auraUnit, index, ...)
            if auraUnit ~= unit then return reader(auraUnit, index, ...) end
            if not slots[filter] then
                local indices = {}
                for i = 1, 40 do
                    local name, _, _, _, _, _, _, _, _, _, id = reader(auraUnit, i, ...)
                    if not name then break end
                    if not self:IsPlayerAuraBlocked(id, filter, true) then indices[#indices+1] = i end
                end
                slots[filter] = indices
            end
            local nativeIndex = slots[filter][index]
            if nativeIndex then return reader(auraUnit, nativeIndex, ...) end
        end
    end
    if enabled then
        setfenv(renderer, setmetatable({
            UnitBuff = Reader(environment.UnitBuff, "HELPFUL"),
            UnitDebuff = Reader(environment.UnitDebuff, "HARMFUL"),
        }, {__index = environment, __newindex = environment}))
    end
    if enabled then
        local ok, err
        if hook == "RefreshDebuffs" then ok, err = pcall(renderer, frame, unit, ...)
        else ok, err = pcall(renderer, frame) end
        setfenv(renderer, environment)
        if not ok then error(err, 0) end
    end
    local suffix = select(2, ...)
    for _, kind in ipairs({"Buff", "Debuff"}) do
        local filter = kind == "Buff" and "HELPFUL" or "HARMFUL"
        local indices = slots and slots[filter]
        for i = 1, 40 do
            local button = _G[frame:GetName() .. (hook == "RefreshDebuffs" and kind == "Debuff" and suffix or kind) .. i]
            if button then
                local nativeIndex = indices and indices[i] or i
                button:SetID(nativeIndex)
                local cooldown = _G[button:GetName() .. "Cooldown"]
                if cooldown and SarychUI_NotifyCooldown then
                    local reader = kind == "Buff" and UnitBuff or UnitDebuff
                    local _, _, _, _, _, duration, expiration = reader(unit, nativeIndex)
                    if button:IsShown() and duration and duration > 0 and expiration then
                        SarychUI_NotifyCooldown(cooldown, expiration - duration, duration, 1)
                    else
                        SarychUI_NotifyCooldown(cooldown, 0, 0, 0)
                    end
                end
                if button:IsShown() and GameTooltip and GameTooltip:IsOwned(button) then
                    if kind == "Buff" then GameTooltip:SetUnitBuff(unit, nativeIndex)
                    else GameTooltip:SetUnitDebuff(unit, nativeIndex) end
                end
            end
        end
    end
    if hook ~= "RefreshDebuffs" then self:OnFrameAuraLayoutUpdated(frame) end
    return result
end

function module:UpdateTargetFrameAuras(frame)
    return self:UpdateFilteredFrameAuras("TargetFrame_UpdateAuras", frame)
end

function module:UpdateFrameDebuffs(frame, unit, ...)
    local result = self:UpdateFilteredFrameAuras("RefreshDebuffs", frame, unit, ...)
    self:ApplyFrameAuraVisibility(frame)
    return result
end

function module:UpdateLayoutHooks()
	if AuraButton_Update and not self:IsHooked("AuraButton_Update") then
		self:RawHook("AuraButton_Update", "UpdateConsolidatedAura", true)
	end
	-- Blizzard clears and rebuilds every aura anchor on each update. Reapply our
	-- layout immediately after that work so the icons cannot jump back below the
	-- target/focus frame while waiting for the throttled UNIT_AURA callback.
	if TargetFrame_UpdateAuras and not self:IsHooked("TargetFrame_UpdateAuras") then
		self:RawHook("TargetFrame_UpdateAuras", "UpdateTargetFrameAuras", true)
	end
	if RefreshDebuffs and not self:IsHooked("RefreshDebuffs") then
		self:RawHook("RefreshDebuffs", "UpdateFrameDebuffs", true)
	end
	if FocusFrame_UpdateAuras and not self:IsHooked("FocusFrame_UpdateAuras") then
		self:SecureHook("FocusFrame_UpdateAuras", "OnFrameAuraLayoutUpdated")
	end

	if AddonLoaded("SimpleAuraFilter") then
		-- other addon owns player buff rows
	else
		if BuffFrame_UpdateAllBuffAnchors and not self:IsHooked("BuffFrame_UpdateAllBuffAnchors") then
			self:SecureHook("BuffFrame_UpdateAllBuffAnchors", "OnBuffFrameUpdateAllBuffAnchors")
		end
		if BuffButton_UpdateAnchors and not self:IsHooked("BuffButton_UpdateAnchors") then
			self:SecureHook("BuffButton_UpdateAnchors", "OnBuffButtonUpdateAnchors")
		end
		if DebuffButton_UpdateAnchors and not self:IsHooked("DebuffButton_UpdateAnchors") then
			self:SecureHook("DebuffButton_UpdateAnchors", "OnDebuffButtonUpdateAnchors")
		end
		if BuffFrame_Enchant_OnUpdate and not self:IsHooked("BuffFrame_Enchant_OnUpdate") then
			self:SecureHook("BuffFrame_Enchant_OnUpdate", "OnBuffFrameEnchantUpdated")
		end
	end
end

function module:RefreshAuraLayout()
    if RefreshDebuffs then
        local frames = {TargetFrameToT = "targettarget", FocusFrameToT = "focustarget",
            TargetofTargetFrame = "targettarget", TargetofFocusFrame = "focustarget"}
        for name, unit in pairs(frames) do
            local frame = _G[name]
            if frame and _G[name .. "Debuff1"] then pcall(RefreshDebuffs, frame, frame.unit or unit) end
        end
    end
	if TargetFrame and TargetFrame_UpdateAuras then
		pcall(TargetFrame_UpdateAuras, TargetFrame)
	end
	if CustomFrameAuraLayout() and TargetFrame then
		self:LayoutFrameAuras(TargetFrame)
	end
	if FocusFrame then
		if FocusFrame_UpdateAuras then
			pcall(FocusFrame_UpdateAuras, FocusFrame)
		elseif TargetFrame_UpdateAuras then
			pcall(TargetFrame_UpdateAuras, FocusFrame)
		end
		if CustomFrameAuraLayout() then
			self:LayoutFrameAuras(FocusFrame)
		end
	end
	if PlayerBuffGrowthDirection() == "right_to_left" then
		RestoreTemporaryEnchantGrowth()
	end
	if BuffFrame_Update then
		pcall(BuffFrame_Update)
	elseif BuffFrame_UpdateAllBuffAnchors then
		pcall(BuffFrame_UpdateAllBuffAnchors)
	end
	if PlayerBuffGrowthDirection() == "left_to_right" then
		self:LayoutPlayerBuffsLeftToRight()
	end
	if SeparatePlayerAuraPositioning() then
		self:LayoutSeparatePlayerDebuffs()
	elseif PlayerDebuffGrowthDirection() == "left_to_right" then
		self:LayoutCombinedPlayerDebuffsLeftToRight()
	end
end

--------------------------------------------------------------------
-- Player buff frame management (ConsolidatedBuffs / BuffFrame)
--------------------------------------------------------------------
local buffFrameBlizzardDefaultPosition = nil
local buffMoverFrame = nil

local function GetPlayerBuffMoverFrame()
	return ConsolidatedBuffs or TemporaryEnchantFrame or BuffFrame
end

local function RefreshPlayerBuffAnchors()
	if BuffFrame_Update then
		pcall(BuffFrame_Update)
	elseif BuffFrame_UpdateAllBuffAnchors then
		pcall(BuffFrame_UpdateAllBuffAnchors)
	end
end

local function SetPlayerBuffGroupScale(scale)
	scale = scale or 1
	if BuffFrame then
		BuffFrame:SetScale(scale)
	end
	if TemporaryEnchantFrame then
		TemporaryEnchantFrame:SetScale(scale)
	end
	if ConsolidatedBuffs then
		ConsolidatedBuffs:SetScale(scale)
	end
end

function module:SaveDefaultBuffPosition()
	local mover = GetPlayerBuffMoverFrame()
	if mover and not buffFrameBlizzardDefaultPosition then
		local point, relativeTo, relativePoint, xOfs, yOfs = mover:GetPoint()
		if point then
			buffFrameBlizzardDefaultPosition = {
				point = point,
				relativeTo = relativeTo and relativeTo.GetName and relativeTo:GetName() or "UIParent",
				relativePoint = relativePoint,
				xOfs = xOfs,
				yOfs = yOfs,
			}
		end
	end

	if mover and SarychUI.DragMode then
		if not SarychUI.DragMode:GetFrameData("buffFrame") then
			buffMoverFrame = mover
			SarychUI.DragMode:RegisterFrame("buffFrame", mover, {
				dragPoint = "TOPRIGHT",
				dragOffsetX = 0,
				dragOffsetY = 0,
				dragWidth = 280,
				dragHeight = 225,
				dragText = L and (L["Buffs"] or "Бафы") or "Бафы",
				scaleFrame = BuffFrame,
				interceptSetPoint = true,
				getPoint = function()
					return {
						GetSetting("buffFrameA", "TOPRIGHT"),
						UIParent,
						GetSetting("buffFrameR", "TOPRIGHT"),
						GetSetting("buffFrameX", -205),
						GetSetting("buffFrameY", -13),
					}
				end,
				getScale = function()
					return GetSetting("buffFrameScale", 1.0)
				end,
				onPositionChanged = function(point, relativePoint, xOfs, yOfs)
					local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
					if panel and panel.IsOpen and panel:IsOpen() and panel.OnDragPosition then
						if panel:OnDragPosition("buffFrame", xOfs, yOfs, point, relativePoint) then
							return
						end
					end
					local db = ModuleDB()
					if not db then return end
					db.buffFrameA = point
					db.buffFrameR = relativePoint
					db.buffFrameX = xOfs
					db.buffFrameY = yOfs
					if SuiTimer and SuiTimer.After then
						SuiTimer.After(0.1, function()
							RefreshPlayerBuffAnchors()
							if UpdateBuffAnchors then
								UpdateBuffAnchors()
							end
						end)
					end
				end,
			})
		end
	end

	local debuffAnchor = EnsurePlayerDebuffAnchor()
	if debuffAnchor and SarychUI.DragMode and not SarychUI.DragMode:GetFrameData("debuffFrame") then
		SarychUI.DragMode:RegisterFrame("debuffFrame", debuffAnchor, {
			dragPoint = "TOPRIGHT",
			dragOffsetX = 0,
			dragOffsetY = 0,
			dragWidth = 280,
			dragHeight = 100,
			dragText = "Дебафы",
			getPoint = function()
				return {
					GetSetting("debuffFrameA", "TOPRIGHT"),
					UIParent,
					GetSetting("debuffFrameR", "TOPRIGHT"),
					GetSetting("debuffFrameX", -205),
					GetSetting("debuffFrameY", -105),
				}
			end,
			getScale = function()
				return GetSetting("debuffFrameScale", 1.0)
			end,
			onPositionChanged = function(point, relativePoint, xOfs, yOfs)
				local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
				if panel and panel.IsOpen and panel:IsOpen() and panel.OnDragPosition then
					if panel:OnDragPosition("debuffFrame", xOfs, yOfs, point, relativePoint) then
						return
					end
				end
				local db = ModuleDB()
				if not db then return end
				db.debuffFrameA = point
				db.debuffFrameR = relativePoint
				db.debuffFrameX = xOfs
				db.debuffFrameY = yOfs
			end,
		})
	end
end

local function UpdatePlayerAuraDragDirection(frameId, growth)
	local dragMode = SarychUI.DragMode
	local data = dragMode:GetFrameData(frameId)
	if not data then return end
	-- The selection and the first icon share the growth corner. Keep the
	-- saved mover position intact when switching direction in the editor.
	data.settings.dragPoint = growth == "left_to_right" and "TOPLEFT" or "TOPRIGHT"
	dragMode:RefreshDragOverlay(frameId)
end

function module:ApplyBuffManagement()
	local db = ModuleDB()
	if not db or not db.enabled then return end
	if not SarychUI.DragMode then return end
	if not GetPlayerBuffMoverFrame() or not BuffFrame then return end

	if not SarychUI.DragMode:GetFrameData("buffFrame") then
		self:SaveDefaultBuffPosition()
	end
	if not SarychUI.DragMode:GetFrameData("debuffFrame") then
		self:SaveDefaultBuffPosition()
	end

	local manageBuffs = GetSetting("manageBuffs", 0) == 1
	local separate = manageBuffs and GetSetting("playerAuraPositionMode", "together") == "separate"
	local showDragFrame = GetSetting("showBuffDragFrame", 0) == 1
	local showGrid = GetSetting("showBuffGrid", 0) == 1
	local showDebuffDragFrame = separate and GetSetting("showDebuffDragFrame", 0) == 1
	local showDebuffGrid = separate and GetSetting("showDebuffGrid", 0) == 1

	UpdatePlayerAuraDragDirection("buffFrame", PlayerBuffGrowthDirection())
	UpdatePlayerAuraDragDirection("debuffFrame", PlayerDebuffGrowthDirection())
	SarychUI.DragMode:EnableEditMode("buffFrame", manageBuffs, showDragFrame, showGrid)

	if manageBuffs then
		SarychUI.DragMode:SetFramePosition("buffFrame",
			GetSetting("buffFrameA", "TOPRIGHT"),
			GetSetting("buffFrameR", "TOPRIGHT"),
			GetSetting("buffFrameX", -205),
			GetSetting("buffFrameY", -13))
		SarychUI.DragMode:SetFrameScale("buffFrame", GetSetting("buffFrameScale", 1.0))
		SetPlayerBuffGroupScale(GetSetting("buffFrameScale", 1.0))
	else
		SetPlayerBuffGroupScale(1.0)
	end

	if separate then
		SarychUI.DragMode:EnableEditMode("debuffFrame", true, showDebuffDragFrame, showDebuffGrid)
		SarychUI.DragMode:SetFramePosition("debuffFrame",
			GetSetting("debuffFrameA", "TOPRIGHT"),
			GetSetting("debuffFrameR", "TOPRIGHT"),
			GetSetting("debuffFrameX", -205),
			GetSetting("debuffFrameY", -105))
		SarychUI.DragMode:SetFrameScale("debuffFrame", GetSetting("debuffFrameScale", 1.0))
		self:LayoutSeparatePlayerDebuffs()
	else
		SarychUI.DragMode:EnableEditMode("debuffFrame", false, false, false)
		if playerDebuffAnchor then
			playerDebuffAnchor:SetScale(1.0)
		end
		self:RestoreCombinedPlayerDebuffs(true)
	end

	local buffGrowth = PlayerBuffGrowthDirection()
	local debuffGrowth = PlayerDebuffGrowthDirection()
	local growthChanged = self._playerBuffGrowthDirection ~= buffGrowth
		or self._playerDebuffGrowthDirection ~= debuffGrowth
	self._playerBuffGrowthDirection = buffGrowth
	self._playerDebuffGrowthDirection = debuffGrowth
	self._playerAurasSeparate = separate

	if buffGrowth == "right_to_left" then
		RestoreTemporaryEnchantGrowth()
	end
	if growthChanged then
		RefreshPlayerBuffAnchors()
	end
	if buffGrowth == "left_to_right" then
		self:LayoutPlayerBuffsLeftToRight()
	end
	if separate then
		self:LayoutSeparatePlayerDebuffs()
	elseif debuffGrowth == "left_to_right" then
		self:LayoutCombinedPlayerDebuffsLeftToRight()
	end

	SarychUI.DragMode:ShowGrid((showGrid and manageBuffs) or (showDebuffGrid and separate))
end

function module:ResetBuffManagement()
	local mover = buffMoverFrame or GetPlayerBuffMoverFrame()
	if not mover then return end

	if SarychUI.DragMode then
		local data = SarychUI.DragMode:GetFrameData("buffFrame")
		if data and data.originalSetPoint then
			mover.SetPoint = data.originalSetPoint
		end
		SarychUI.DragMode:EnableEditMode("buffFrame", false, false, false)
		SarychUI.DragMode:EnableEditMode("debuffFrame", false, false, false)
		SarychUI.DragMode:ShowGrid(false)
	end

	pcall(function()
		if mover:IsMovable() then
			mover:SetMovable(false)
		end
	end)
	pcall(function()
		if mover:IsUserPlaced() then
			mover:SetUserPlaced(false)
		end
	end)
	pcall(function()
		mover:SetDontSavePosition(false)
	end)

	mover:ClearAllPoints()
	if buffFrameBlizzardDefaultPosition then
		local relativeTo = _G[buffFrameBlizzardDefaultPosition.relativeTo] or UIParent
		pcall(function()
			mover:SetPoint(
				buffFrameBlizzardDefaultPosition.point,
				relativeTo,
				buffFrameBlizzardDefaultPosition.relativePoint,
				buffFrameBlizzardDefaultPosition.xOfs,
				buffFrameBlizzardDefaultPosition.yOfs
			)
		end)
	else
		pcall(function()
			mover:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -205, -13)
		end)
	end

	SetPlayerBuffGroupScale(1.0)
	RestoreTemporaryEnchantGrowth()
	self._playerBuffGrowthDirection = nil
	self._playerDebuffGrowthDirection = nil
	self._playerAurasSeparate = nil
	self._playerEnchantGrowthMask = nil
	if playerDebuffAnchor then
		playerDebuffAnchor:SetScale(1.0)
	end
	self:RestoreCombinedPlayerDebuffs(true)
	RefreshPlayerBuffAnchors()
end

function module:ResetBuffManagementToDefaults()
	local db = ModuleDB()
	if not db then return end
	db.playerAuraPositionMode = "together"
	db.playerAuraGrowthDirection = "right_to_left"
	db.playerBuffGrowthDirection = "right_to_left"
	db.playerDebuffGrowthDirection = "right_to_left"
	db.buffFrameA = "TOPRIGHT"
	db.buffFrameR = "TOPRIGHT"
	db.buffFrameX = -205
	db.buffFrameY = -13
	db.buffFrameScale = 1.0
	db.debuffFrameA = "TOPRIGHT"
	db.debuffFrameR = "TOPRIGHT"
	db.debuffFrameX = -205
	db.debuffFrameY = -105
	db.debuffFrameScale = 1.0
	db.showBuffDragFrame = 0
	db.showBuffGrid = 0
	db.showDebuffDragFrame = 0
	db.showDebuffGrid = 0

	if SarychUI.DragMode then
		SarychUI.DragMode:SetFramePosition("buffFrame", "TOPRIGHT", "TOPRIGHT", -205, -13)
		SarychUI.DragMode:SetFrameScale("buffFrame", 1.0)
		SarychUI.DragMode:SetFramePosition("debuffFrame", "TOPRIGHT", "TOPRIGHT", -205, -105)
		SarychUI.DragMode:SetFrameScale("debuffFrame", 1.0)
	end
	self:ApplyBuffManagement()
end

--------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------
function module:Initialize()
end

function module:Enable()
	self.db = ModuleDB()
    self:ApplyBlacklistVisibilitySettings()
	if not self.db or not self.db.enabled then return end

	self:RegisterEvent("CVAR_UPDATE", "OnConsolidationCVarUpdate")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("PLAYER_FOCUS_CHANGED", "OnEvent")
	self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnEvent")
	self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "OnEvent")
	self:RegisterEvent("UNIT_INVENTORY_CHANGED", "OnEvent")
	if self.auraUpdateBucket then
		self:UnregisterBucket(self.auraUpdateBucket)
	end
	self.auraUpdateBucket = self:RegisterBucketEvent("UNIT_AURA", 0.2, "OnAuraUpdate")

	if SarychUI.DragMode and GetPlayerBuffMoverFrame() then
		self:SaveDefaultBuffPosition()
	end

	self:UpdateLayoutHooks()
	self:ApplyBuffManagement()
	self:RefreshAuraLayout()
	self:ForceUpdateAuras()
	if self.ApplyPoisonIcons then
		self:ApplyPoisonIcons()
	end

	local toolsModule = SarychUI.modules
	if toolsModule and SarychUI.modules.auras.ApplyDispelHighlight then
		SarychUI.modules.auras:ApplyDispelHighlight()
	end
end

function module:Disable()
    -- RefreshDebuffs does not assign IDs itself; restore its template indices
    -- before removing our hooks so subsequent native tooltips stay correct.
    for frame in pairs(self._frameAuraSlots or {}) do
        for _, kind in ipairs({"Buff", "Debuff"}) do
            for i = 1, 40 do
                local button = _G[frame:GetName() .. kind .. i]
                if button then button:SetID(i) end
            end
        end
    end
    self._blacklistVisibilityEnabled, self._showBlacklistedAuras = false, nil
    self._blacklistVisibilityProfile, self._playerAuraSlots, self._frameAuraSlots = nil, nil, nil
    if SarychUI_ToggleBindings then SarychUI_ToggleBindings:RemoveAction("player_aura_blacklist_visibility") end
	if self.consolidationExceptionsWindow then self.consolidationExceptionsWindow:Hide() end
	self:UnregisterAllEvents()
	if self.auraUpdateBucket then
		self:UnregisterBucket(self.auraUpdateBucket)
		self.auraUpdateBucket = nil
	end
	if self.UnhookAll then
		self:UnhookAll()
	end
    if RefreshDebuffs then
        for name, unit in pairs({TargetFrameToT = "targettarget", FocusFrameToT = "focustarget",
            TargetofTargetFrame = "targettarget", TargetofFocusFrame = "focustarget"}) do
            local frame = _G[name]
            if frame and _G[name .. "Debuff1"] then pcall(RefreshDebuffs, frame, frame.unit or unit) end
        end
    end
	self:RestoreAuras()
	self:ResetBuffManagement()
	if self.ResetPoisonIcons then
		self:ResetPoisonIcons()
	end
	if TargetFrame_UpdateAuras and TargetFrame then
		pcall(TargetFrame_UpdateAuras, TargetFrame)
	end
	if FocusFrame then
		if FocusFrame_UpdateAuras then
			pcall(FocusFrame_UpdateAuras, FocusFrame)
		elseif TargetFrame_UpdateAuras then
			pcall(TargetFrame_UpdateAuras, FocusFrame)
		end
	end
	if BuffFrame_Update then
		pcall(BuffFrame_Update)
	elseif BuffFrame_UpdateAllBuffAnchors then
		pcall(BuffFrame_UpdateAllBuffAnchors)
	end

	local toolsModule = SarychUI.modules
	if toolsModule and SarychUI.modules.auras.DisableDispelHighlight then
		SarychUI.modules.auras:DisableDispelHighlight()
	end
    self:ApplyBlacklistVisibilitySettings()
end

function module:RefreshConfig()
	if SarychUI.InvalidateModuleProfileCaches then
		SarychUI:InvalidateModuleProfileCaches()
	end
	self:Disable()
	self:Enable()
end

function module:ApplySettings()
    self:ApplyBlacklistVisibilitySettings()
	local db = ModuleDB()
	if db and db.enabled then
		self:UpdateLayoutHooks()
		self:ApplyBuffManagement()
		self:RefreshAuraLayout()
		self:ForceUpdateAuras()
		if self.ApplyPoisonIcons then
			self:ApplyPoisonIcons()
		end
		local toolsModule = SarychUI.modules
		if toolsModule and SarychUI.modules.auras.ApplyDispelHighlight then
			SarychUI.modules.auras:ApplyDispelHighlight()
		end
	end
end

function module:OnEvent(event, ...)
	if event == "PLAYER_ENTERING_WORLD" then
		self:SaveDefaultBuffPosition()
		self:UpdateLayoutHooks()
		self:ApplyBuffManagement()
		self:RefreshAuraLayout()
		self:ForceUpdateAuras()
		if self.ApplyPoisonIcons then
			self:ApplyPoisonIcons()
		end
	elseif event == "PLAYER_FOCUS_CHANGED" then
		self:UpdateFocusAuras()
		if CustomFrameAuraLayout() and FocusFrame then
			self:LayoutFrameAuras(FocusFrame)
		end
	elseif event == "PLAYER_TARGET_CHANGED" then
		if CustomFrameAuraLayout() and TargetFrame then
			self:LayoutFrameAuras(TargetFrame)
		end
		self:UpdateTargetAuras()
	elseif event == "PLAYER_EQUIPMENT_CHANGED" then
		if self.ApplyPoisonIcons then
			self:ApplyPoisonIcons()
		end
	elseif event == "UNIT_INVENTORY_CHANGED" then
		local unit = ...
		if unit == "player" and self.ApplyPoisonIcons then
			self:ApplyPoisonIcons()
		end
	end
end

function module:OnAuraUpdate(units)
	if not units then return end
	for unit in pairs(units) do
		if unit == "focus" then
			self:UpdateFocusAuras()
			if CustomFrameAuraLayout() and FocusFrame then
				self:LayoutFrameAuras(FocusFrame)
			end
		elseif unit == "target" then
			if CustomFrameAuraLayout() and TargetFrame then
				self:LayoutFrameAuras(TargetFrame)
			end
			self:UpdateTargetAuras()
		end
	end
end
