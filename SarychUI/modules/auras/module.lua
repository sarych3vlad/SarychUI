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
local focusAuraUpdateFrame = CreateFrame("Frame")
focusAuraUpdateFrame:Hide()

local function HideNamedAuras(prefix, hide)
	for i = 1, 32 do
		local buff = _G[prefix .. "Buff" .. i]
		if buff then
			if hide then
				buff:Hide()
				buff:SetAlpha(0)
				buff:SetScale(0.01)
			elseif buff.SetAlpha then
				buff:SetAlpha(1)
				buff:SetScale(1)
			end
		end
	end
	for i = 1, 16 do
		local debuff = _G[prefix .. "Debuff" .. i]
		if debuff then
			if hide then
				debuff:Hide()
				debuff:SetAlpha(0)
				debuff:SetScale(0.01)
			elseif debuff.SetAlpha then
				debuff:SetAlpha(1)
				debuff:SetScale(1)
			end
		end
	end
end

local function AuraHideOnUpdate()
	if GetSetting("hideFocusAuras", 0) == 1 then
		HideNamedAuras("FocusFrame", true)
	end
	if GetSetting("hideTargetAuras", 0) == 1 then
		HideNamedAuras("TargetFrame", true)
	end
end

local function SetAuraHideTicker(enabled)
	local runtime = SarychUI and SarychUI.Runtime
	if runtime and runtime.RegisterUpdate then
		focusAuraUpdateFrame:SetScript("OnUpdate", nil)
		if enabled then
			runtime:RegisterUpdate("auras.hide_named", 0.10, AuraHideOnUpdate)
		else
			runtime:UnregisterUpdate("auras.hide_named")
		end
		return
	end
	focusAuraUpdateFrame:SetScript("OnUpdate", enabled and AuraHideOnUpdate or nil)
end

function module:UpdateFocusAuras()
	local db = ModuleDB()
	if not db or not db.enabled then
		focusAuraUpdateFrame:Hide()
		SetAuraHideTicker(false)
		return
	end

	local hideFocus = GetSetting("hideFocusAuras", 0) == 1
	local hideTarget = GetSetting("hideTargetAuras", 0) == 1
	if hideFocus or hideTarget then
		focusAuraUpdateFrame:Show()
		SetAuraHideTicker(true)
	else
		focusAuraUpdateFrame:Hide()
		SetAuraHideTicker(false)
	end

	if hideFocus then
		HideNamedAuras("FocusFrame", true)
	else
		HideNamedAuras("FocusFrame", false)
	end
end

function module:UpdateTargetAuras()
	local db = ModuleDB()
	if not db or not db.enabled then
		return
	end
	self:UpdateFocusAuras()
	if GetSetting("hideTargetAuras", 0) == 1 then
		HideNamedAuras("TargetFrame", true)
	else
		HideNamedAuras("TargetFrame", false)
	end
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
	focusAuraUpdateFrame:Hide()
	SetAuraHideTicker(false)

	if TargetFrame then
		for i = 1, 32 do
			local buff = _G["TargetFrameBuff" .. i]
			if buff then
				buff:SetAlpha(1)
				buff:SetScale(1)
				buff.Show = nil
				buff:Show()
			end
		end
		for i = 1, 16 do
			local debuff = _G["TargetFrameDebuff" .. i]
			if debuff then
				debuff:SetAlpha(1)
				debuff:SetScale(1)
				debuff.Show = nil
				debuff:Show()
			end
		end
	end

	if FocusFrame then
		for i = 1, 32 do
			local buff = _G["FocusFrameBuff" .. i]
			if buff then
				buff:SetAlpha(1)
				buff:SetScale(1)
				buff.Show = nil
				buff:Show()
			end
		end
		for i = 1, 16 do
			local debuff = _G["FocusFrameDebuff" .. i]
			if debuff then
				debuff:SetAlpha(1)
				debuff:SetScale(1)
				debuff.Show = nil
				debuff:Show()
			end
		end
	end

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
		local name, _, icon, _, _, _, _, caster = UnitBuff(unit, i)
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
		local debuffName, _, icon, _, _, _, _, caster = UnitDebuff(unit, i)
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
	elseif frame.spellbar then
		AdjustTargetSpellbar(frame.spellbar)
	end
end

--------------------------------------------------------------------
-- Player buffs per row (RougeUI BuffsRow)
--------------------------------------------------------------------
function module:OnBuffFrameUpdateAllBuffAnchors()
	if not SettingOn("changePlayerBuffRow") or not BuffFrame then
		return
	end
	if AddonLoaded("SimpleAuraFilter") then
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

function module:OnDebuffButtonUpdateAnchors(buttonName, index)
	if not SettingOn("changePlayerBuffRow") or not BuffFrame then
		return
	end
	if AddonLoaded("SimpleAuraFilter") then
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
	-- TargetFrame_UpdateAuras is also used by protected boss frames.  Keep the
	-- secure hook, but never touch anything except the two frames owned here.
	if CustomFrameAuraLayout() and (frame == TargetFrame or frame == FocusFrame) then
		self:LayoutFrameAuras(frame)
	end
end

function module:UpdateLayoutHooks()
	-- Blizzard clears and rebuilds every aura anchor on each update. Reapply our
	-- layout immediately after that work so the icons cannot jump back below the
	-- target/focus frame while waiting for the throttled UNIT_AURA callback.
	if TargetFrame_UpdateAuras and not self:IsHooked("TargetFrame_UpdateAuras") then
		self:SecureHook("TargetFrame_UpdateAuras", "OnFrameAuraLayoutUpdated")
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
		if DebuffButton_UpdateAnchors and not self:IsHooked("DebuffButton_UpdateAnchors") then
			self:SecureHook("DebuffButton_UpdateAnchors", "OnDebuffButtonUpdateAnchors")
		end
	end
end

function module:RefreshAuraLayout()
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
	if BuffFrame_UpdateAllBuffAnchors then
		pcall(BuffFrame_UpdateAllBuffAnchors)
	end
end

--------------------------------------------------------------------
-- Player buff frame management (ConsolidatedBuffs / BuffFrame)
--------------------------------------------------------------------
local buffFrameBlizzardDefaultPosition = nil

function module:SaveDefaultBuffPosition()
	if ConsolidatedBuffs and not buffFrameBlizzardDefaultPosition then
		local point, relativeTo, relativePoint, xOfs, yOfs = ConsolidatedBuffs:GetPoint()
		if point then
			buffFrameBlizzardDefaultPosition = {
				point = point,
				relativeTo = relativeTo and relativeTo:GetName() or "UIParent",
				relativePoint = relativePoint,
				xOfs = xOfs,
				yOfs = yOfs,
			}
		end
	end

	if ConsolidatedBuffs and SarychUI.DragMode then
		if not SarychUI.DragMode:GetFrameData("buffFrame") then
			SarychUI.DragMode:RegisterFrame("buffFrame", ConsolidatedBuffs, {
				dragPoint = "TOPRIGHT",
				dragOffsetX = 0,
				dragOffsetY = 2.5,
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
					if ConsolidatedBuffs and C_Timer and C_Timer.After then
						C_Timer.After(0.1, function()
							if BuffFrame_UpdateAllBuffAnchors then
								BuffFrame_UpdateAllBuffAnchors()
							end
							if UpdateBuffAnchors then
								UpdateBuffAnchors()
							end
						end)
					end
				end,
			})
		end
	end
end

function module:ApplyBuffManagement()
	local db = ModuleDB()
	if not db or not db.enabled then return end
	if not SarychUI.DragMode then return end
	if not ConsolidatedBuffs or not BuffFrame then return end

	if not SarychUI.DragMode:GetFrameData("buffFrame") then
		self:SaveDefaultBuffPosition()
	end

	local manageBuffs = GetSetting("manageBuffs", 0) == 1
	local showDragFrame = GetSetting("showBuffDragFrame", 0) == 1
	local showGrid = GetSetting("showBuffGrid", 0) == 1

	SarychUI.DragMode:EnableEditMode("buffFrame", manageBuffs, showDragFrame, showGrid)

	if manageBuffs then
		SarychUI.DragMode:SetFramePosition("buffFrame",
			GetSetting("buffFrameA", "TOPRIGHT"),
			GetSetting("buffFrameR", "TOPRIGHT"),
			GetSetting("buffFrameX", -205),
			GetSetting("buffFrameY", -13))
		SarychUI.DragMode:SetFrameScale("buffFrame", GetSetting("buffFrameScale", 1.0))
	end

	SarychUI.DragMode:ShowGrid(showGrid and manageBuffs)
end

function module:ResetBuffManagement()
	if not ConsolidatedBuffs then return end

	if SarychUI.DragMode then
		local data = SarychUI.DragMode:GetFrameData("buffFrame")
		if data and data.originalSetPoint then
			ConsolidatedBuffs.SetPoint = data.originalSetPoint
		end
		SarychUI.DragMode:EnableEditMode("buffFrame", false, false, false)
		SarychUI.DragMode:ShowGrid(false)
	end

	pcall(function()
		if ConsolidatedBuffs:IsMovable() then
			ConsolidatedBuffs:SetMovable(false)
		end
	end)
	pcall(function()
		if ConsolidatedBuffs:IsUserPlaced() then
			ConsolidatedBuffs:SetUserPlaced(false)
		end
	end)
	pcall(function()
		ConsolidatedBuffs:SetDontSavePosition(false)
	end)

	ConsolidatedBuffs:ClearAllPoints()
	if buffFrameBlizzardDefaultPosition then
		local relativeTo = _G[buffFrameBlizzardDefaultPosition.relativeTo] or UIParent
		pcall(function()
			ConsolidatedBuffs:SetPoint(
				buffFrameBlizzardDefaultPosition.point,
				relativeTo,
				buffFrameBlizzardDefaultPosition.relativePoint,
				buffFrameBlizzardDefaultPosition.xOfs,
				buffFrameBlizzardDefaultPosition.yOfs
			)
		end)
	else
		pcall(function()
			ConsolidatedBuffs:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -205, -13)
		end)
	end

	if BuffFrame then
		BuffFrame:SetScale(1.0)
	end
	if ConsolidatedBuffs then
		ConsolidatedBuffs:SetScale(1.0)
	end
end

function module:ResetBuffManagementToDefaults()
	local db = ModuleDB()
	if not db then return end
	db.buffFrameA = "TOPRIGHT"
	db.buffFrameR = "TOPRIGHT"
	db.buffFrameX = -205
	db.buffFrameY = -13
	db.buffFrameScale = 1.0

	if SarychUI.DragMode then
		SarychUI.DragMode:SetFramePosition("buffFrame", "TOPRIGHT", "TOPRIGHT", -205, -13)
		SarychUI.DragMode:SetFrameScale("buffFrame", 1.0)
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
	if not self.db or not self.db.enabled then return end

	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("PLAYER_FOCUS_CHANGED", "OnEvent")
	self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnEvent")
	self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "OnEvent")
	self:RegisterEvent("UNIT_INVENTORY_CHANGED", "OnEvent")
	if self.auraUpdateBucket then
		self:UnregisterBucket(self.auraUpdateBucket)
	end
	self.auraUpdateBucket = self:RegisterBucketEvent("UNIT_AURA", 0.2, "OnAuraUpdate")

	if SarychUI.DragMode and ConsolidatedBuffs then
		self:SaveDefaultBuffPosition()
	end

	self:UpdateLayoutHooks()
	self:ApplyBuffManagement()
	self:RefreshAuraLayout()
	self:ForceUpdateAuras()
	if self.ApplyPoisonIcons then
		self:ApplyPoisonIcons()
	end

	local toolsModule = SarychUI:GetModule("tools", true)
	if toolsModule and toolsModule.ApplyDispelHighlight then
		toolsModule:ApplyDispelHighlight()
	end
end

function module:Disable()
	self:UnregisterAllEvents()
	if self.auraUpdateBucket then
		self:UnregisterBucket(self.auraUpdateBucket)
		self.auraUpdateBucket = nil
	end
	if self.UnhookAll then
		self:UnhookAll()
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
	if BuffFrame_UpdateAllBuffAnchors then
		pcall(BuffFrame_UpdateAllBuffAnchors)
	end

	local toolsModule = SarychUI:GetModule("tools", true)
	if toolsModule and toolsModule.DisableDispelHighlight then
		toolsModule:DisableDispelHighlight()
	end
end

function module:RefreshConfig()
	if SarychUI.InvalidateModuleProfileCaches then
		SarychUI:InvalidateModuleProfileCaches()
	end
	self:Disable()
	self:Enable()
end

function module:ApplySettings()
	local db = ModuleDB()
	if db and db.enabled then
		self:UpdateLayoutHooks()
		self:ApplyBuffManagement()
		self:RefreshAuraLayout()
		self:ForceUpdateAuras()
		if self.ApplyPoisonIcons then
			self:ApplyPoisonIcons()
		end
		local toolsModule = SarychUI:GetModule("tools", true)
		if toolsModule and toolsModule.ApplyDispelHighlight then
			toolsModule:ApplyDispelHighlight()
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
