-- Loot roll counters + roll-choice tooltips on Blizzard GroupLootFrame (ElvUI Misc/LootRoll.lua)

local LootRollCounts = {}
_G.SarychUI_LootRollCounts = LootRollCounts

local pairs, ipairs, tonumber, find = pairs, ipairs, tonumber, string.find
local tinsert = table.insert
local wipe = wipe or function(t) for k in pairs(t) do t[k] = nil end end
local UnitName = UnitName
local UnitClass = UnitClass
local GetLocale = GetLocale
local CreateFrame = CreateFrame
local GetLootRollItemLink = GetLootRollItemLink

do
	if not string.cmatch then
		local assert, unpack = assert, unpack
		local sanitize_cache, capture_cache = {}, {}

		local function SanitizePattern(pattern)
			assert(pattern, "bad pattern")
			if not sanitize_cache[pattern] then
				local ret = pattern
				ret = ret:gsub("([%+%-%*%(%)%?%[%]%^])", "%%%1")
				ret = ret:gsub("%d%$", "")
				ret = ret:gsub("(%%%a)", "(%1+)")
				ret = ret:gsub("%%s%+", ".+")
				ret = ret:gsub("%(.%+%)%(%%d%+%)", "%(.-%)%(%%d%+%)")
				sanitize_cache[pattern] = ret
			end
			return sanitize_cache[pattern]
		end

		local function GetCaptures(pat)
			if not capture_cache[pat] then
				local result = {}
				for capture_index in pat:gmatch("%%(%d)%$") do
					tinsert(result, tonumber(capture_index))
				end
				capture_cache[pat] = #result > 0 and result
			end
			return capture_cache[pat]
		end

		function string.cmatch(str, pat)
			local capture_indexes = GetCaptures(pat)
			local sanitized_pat = SanitizePattern(pat)
			if not capture_indexes then
				return str:match(sanitized_pat)
			end
			local captures = { str:match(sanitized_pat) }
			if #captures == 0 then return end
			local result = {}
			for current_index, capture in pairs(captures) do
				result[capture_indexes[current_index]] = capture
			end
			return unpack(result)
		end
	end
end

local FALLBACK_FONT = "Fonts\\FRIZQT__.TTF"
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

-- RollOnLoot types (Blizzard / ElvUI LootRoll.lua): 0=pass, 1=need, 2=greed, 3=disenchant
local ROLL_TYPE_PASS = 0
local ROLL_TYPE_NEED = 1
local ROLL_TYPE_GREED = 2
local ROLL_TYPE_DISENCHANT = 3

local ROLL_BUTTON_LOOKUP = {
	[ROLL_TYPE_PASS] = {
		parentKeys = { "passButton", "PassButton" },
		globalSuffixes = { "PassButton" },
	},
	[ROLL_TYPE_NEED] = {
		parentKeys = { "needButton", "rollButton", "RollButton", "NeedButton" },
		globalSuffixes = { "RollButton", "NeedButton" },
	},
	[ROLL_TYPE_GREED] = {
		parentKeys = { "greedButton", "GreedButton" },
		globalSuffixes = { "GreedButton" },
	},
	[ROLL_TYPE_DISENCHANT] = {
		parentKeys = { "disenchantButton", "DisenchantButton" },
		globalSuffixes = { "DisenchantButton" },
	},
}

local ROLL_TOOLTIP_TITLE = {
	[ROLL_TYPE_PASS] = function() return PASS end,
	[ROLL_TYPE_NEED] = function() return NEED end,
	[ROLL_TYPE_GREED] = function() return GREED end,
	[ROLL_TYPE_DISENCHANT] = function()
		return _G.ROLL_DISENCHANT or "Disenchant"
	end,
}

local function GetNoPlayersLine()
	return "Пока никто не выбрал"
end

local activeRolls = {}
local eventFrame
local enabled = false

local function GetToolsDB()
	if not SarychUI or not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules then
		return nil
	end
	return SarychUI.db.profile.modules.tools
end

function LootRollCounts.GetStyle()
	local db = GetToolsDB()
	if not db then
		return { font = "Friz Quadrata TT", fontSize = 12, fontOutline = "OUTLINE" }
	end
	return {
		font = db.lootRollCountFont or "Friz Quadrata TT",
		fontSize = tonumber(db.lootRollCountFontSize) or 12,
		fontOutline = db.lootRollCountFontOutline or "OUTLINE",
	}
end

local function ResolveFontPath(fontName)
	if type(fontName) ~= "string" or fontName == "" then
		fontName = "Friz Quadrata TT"
	end
	if LSM and LSM:IsValid("font", fontName) then
		return LSM:Fetch("font", fontName)
	end
	if SarychUI and SarychUI.Media and SarychUI.Media.GetFont then
		local path = SarychUI.Media:GetFont(fontName)
		if path and path ~= "" then
			return path
		end
	end
	if fontName:find("\\") or fontName:find("/") then
		return fontName
	end
	return FALLBACK_FONT
end

local function ResolveOutline(outline)
	if SarychUI_FontOutlineValues and SarychUI_FontOutlineValues.Resolve then
		return SarychUI_FontOutlineValues.Resolve(outline)
	end
	if outline == "NONE" or outline == "" or outline == nil then
		return ""
	end
	return outline
end

function LootRollCounts.ApplyFontStringStyle(fs)
	if not fs then return end
	local style = LootRollCounts.GetStyle()
	local fontPath = ResolveFontPath(style.font)
	local fontSize = style.fontSize
	local outline = ResolveOutline(style.fontOutline)

	if fs.sarychFontPath == fontPath
		and fs.sarychFontSize == fontSize
		and fs.sarychFontOutline == outline then
		return
	end

	fs:SetFont(fontPath, fontSize, outline)
	local _, height = fs:GetFont()
	if not height or height <= 0 then
		fontPath = FALLBACK_FONT
		fs:SetFont(fontPath, fontSize, outline)
	end

	fs.sarychFontPath = fontPath
	fs.sarychFontSize = fontSize
	fs.sarychFontOutline = outline
end

function LootRollCounts.NumFrames()
	return NUM_GROUP_LOOT_FRAMES or 4
end

function LootRollCounts.GetFrame(index)
	return _G["GroupLootFrame" .. index]
end

-- Reused buffer so the child walk calls GetChildren() once instead of once per index.
local childBuffer = {}

local function FillChildBuffer(...)
	local n = select("#", ...)
	for i = 1, n do
		childBuffer[i] = select(i, ...)
	end
	for i = n + 1, #childBuffer do
		childBuffer[i] = nil
	end
	return n
end

local function GetRollButton(frame, rollType)
	if not frame or rollType == nil then return nil end

	local lookup = ROLL_BUTTON_LOOKUP[rollType]
	if lookup then
		for _, key in ipairs(lookup.parentKeys) do
			local btn = frame[key]
			if btn then return btn end
		end
		local frameName = frame.GetName and frame:GetName()
		if frameName and lookup.globalSuffixes then
			for _, suffix in ipairs(lookup.globalSuffixes) do
				local btn = _G[frameName .. suffix]
				if btn then return btn end
			end
		end
	end

	if frame.GetChildren then
		local numChildren = FillChildBuffer(frame:GetChildren())
		for i = 1, numChildren do
			local child = childBuffer[i]
			if child and child.GetObjectType and child:GetObjectType() == "Button" then
				local id = child.GetID and child:GetID()
				if id == rollType then
					return child
				end
			end
		end
	end

	return nil
end

local function GetRollData(frame)
	if not frame or not frame.rollID then return nil end
	return activeRolls[frame.rollID]
end

local function ResolvePlayerClass(playerName)
	local _, class = UnitClass(playerName)
	if class then return class end
	if playerName == UnitName("player") then
		_, class = UnitClass("player")
	end
	return class
end

-- ElvUI LootRoll.lua buttonOnEnter: list players from frame.rollResults by rollType
local function ShowRollButtonTooltip(button)
	local frame = button.sarychLootRollFrame
	local rollType = button.sarychRollType
	if not frame or rollType == nil then return end

	local titleFn = ROLL_TOOLTIP_TITLE[rollType]
	local title = titleFn and titleFn() or "?"

	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	GameTooltip:SetText(title, 1, 1, 1)

	if button.newbieText and SHOW_NEWBIE_TIPS == "1" then
		GameTooltip:AddLine(button.newbieText, 1, 0.82, 0, true)
	end

	if button:IsEnabled() == 0 and button.reason then
		GameTooltip:AddLine(button.reason, 1, 0.1, 0.1, true)
	end

	local rollData = GetRollData(frame)
	local results = rollData and rollData.results
	local foundAny = false

	if results then
		for playerName, entry in pairs(results) do
			local choice, class = entry[1], entry[2]
			if choice == rollType then
				foundAny = true
				if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
					local c = CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class] or RAID_CLASS_COLORS[class]
					GameTooltip:AddLine(playerName, c.r, c.g, c.b)
				else
					GameTooltip:AddLine(playerName, 1, 1, 1)
				end
			end
		end
	end

	if not foundAny then
		GameTooltip:AddLine(GetNoPlayersLine(), 0.7, 0.7, 0.7, true)
	end

	GameTooltip:Show()
end

local function HideRollButtonTooltip()
	GameTooltip:Hide()
end

local function InstallButtonTooltipHooks(button, frame, rollType)
	if not button or button.sarychRollTooltipHooked then return end
	button.sarychRollTooltipHooked = true
	button.sarychLootRollFrame = frame
	button.sarychRollType = rollType

	local origOnEnter = button:GetScript("OnEnter")
	local origOnLeave = button:GetScript("OnLeave")

	button:SetScript("OnEnter", function(self)
		if origOnEnter then
			origOnEnter(self)
		end
		ShowRollButtonTooltip(self)
	end)

	button:SetScript("OnLeave", function(self)
		HideRollButtonTooltip()
		if origOnLeave then
			origOnLeave(self)
		end
	end)
end

local function RefreshOpenTooltipForFrame(frame)
	if not frame or not GameTooltip.IsOwned then return end
	for rollType = 0, 3 do
		local btn = GetRollButton(frame, rollType)
		if btn and GameTooltip:IsOwned(btn) then
			ShowRollButtonTooltip(btn)
			return
		end
	end
end

local function SyncCountsFromResults(rollData)
	if not rollData or not rollData.results then return end
	rollData.counts[0] = 0
	rollData.counts[1] = 0
	rollData.counts[2] = 0
	rollData.counts[3] = 0
	for _, entry in pairs(rollData.results) do
		local choice = entry[1]
		if choice ~= nil then
			rollData.counts[choice] = (rollData.counts[choice] or 0) + 1
		end
	end
end

function LootRollCounts.ApplyStyleAll()
	for i = 1, LootRollCounts.NumFrames() do
		local frame = LootRollCounts.GetFrame(i)
		if frame then
			for rollType = 0, 3 do
				local btn = GetRollButton(frame, rollType)
				if btn and btn.sarychRollCount then
					LootRollCounts.ApplyFontStringStyle(btn.sarychRollCount)
				end
			end
		end
	end
	if SarychUI and SarychUI.LootRollPreview and SarychUI.LootRollPreview.RefreshAll then
		SarychUI.LootRollPreview:RefreshAll()
	end
end

local function FindFrameByRollID(rollID)
	for i = 1, LootRollCounts.NumFrames() do
		local frame = LootRollCounts.GetFrame(i)
		if frame and frame.rollID == rollID then
			return frame
		end
	end
end

local function NormalizeItemToken(token)
	if not token then return nil end
	local name = token:match("%[(.-)%]")
	if name then return name end
	name = token:match("|h%[(.-)%]|h")
	if name then return name end
	return token
end

local function ItemsMatch(rollLink, chatToken)
	if not rollLink or not chatToken then return false end
	if rollLink == chatToken then return true end
	local chatName = NormalizeItemToken(chatToken)
	if chatName and rollLink:find(chatName, 1, true) then return true end
	return false
end

local function FindFrameByItemToken(itemToken)
	if not itemToken then return end
	for i = 1, LootRollCounts.NumFrames() do
		local frame = LootRollCounts.GetFrame(i)
		if frame and frame.rollID and frame:IsShown() then
			if ItemsMatch(GetLootRollItemLink(frame.rollID), itemToken) then
				return frame
			end
		end
	end
end

local function EnsureCountFontString(button)
	if not button then return end
	if not button.sarychRollCount then
		local fs = button:CreateFontString(nil, "OVERLAY")
		fs:SetParent(button)
		fs:SetPoint("CENTER", button, "CENTER", 0, 0)
		if fs.SetDrawLayer then
			fs:SetDrawLayer("OVERLAY", 7)
		end
		fs:SetTextColor(1, 0.95, 0.4, 1)
		button.sarychRollCount = fs
	end
	LootRollCounts.ApplyFontStringStyle(button.sarychRollCount)
	return button.sarychRollCount
end

local function SetButtonCount(frame, rollType, count)
	local button = GetRollButton(frame, rollType)
	if not button then return end
	local fs = EnsureCountFontString(button)
	if not fs then return end
	if count and count > 0 then
		fs:SetText(tostring(count))
		fs:SetAlpha(1)
		fs:Show()
	else
		fs:SetText("")
	end
end

function LootRollCounts.ClearFrameCounts(frame)
	if not frame then return end
	for rollType = 0, 3 do
		SetButtonCount(frame, rollType, 0)
	end
end

local function RefreshFrameCounts(frame, rollData)
	if not frame or not rollData then return end
	SyncCountsFromResults(rollData)
	for rollType = 0, 3 do
		SetButtonCount(frame, rollType, rollData.counts[rollType] or 0)
	end
end

local function InstallFrameRollButtons(frame)
	if not frame then return end
	for rollType = 0, 3 do
		local btn = GetRollButton(frame, rollType)
		if btn then
			EnsureCountFontString(btn)
			InstallButtonTooltipHooks(btn, frame, rollType)
		end
	end
end

local function NewRollData(itemLink)
	return {
		itemLink = itemLink,
		results = {},
		counts = { [0] = 0, [1] = 0, [2] = 0, [3] = 0 },
	}
end

local function MatchChatPattern(msg, pat, selfOnly)
	if not msg or not pat or pat == "" then return end
	local useCmatch = pat:find("%%[sd]") or pat:find("%%%d%$")
	if useCmatch then
		if selfOnly then
			local itemToken = string.cmatch(msg, pat)
			if itemToken then
				return UnitName("player"), itemToken
			end
			return
		end
		local c1, c2 = string.cmatch(msg, pat)
		if c1 and c2 then return c1, c2 end
		return
	end
	if selfOnly then
		local itemToken = msg:match(pat)
		if itemToken then return UnitName("player"), itemToken end
		return
	end
	local c1, c2 = msg:match(pat)
	if c1 and c2 then return c1, c2 end
end

local function BuildBlizzardPatterns()
	local list = {}
	local function add(globalName, rollType, selfOnly)
		local pat = _G[globalName]
		if type(pat) == "string" and pat ~= "" then
			tinsert(list, { pat = pat, rollType = rollType, selfOnly = selfOnly })
		end
	end
	add("LOOT_ROLL_PASSED", ROLL_TYPE_PASS, false)
	add("LOOT_ROLL_PASSED_AUTO", ROLL_TYPE_PASS, false)
	add("LOOT_ROLL_NEED", ROLL_TYPE_NEED, false)
	add("LOOT_ROLL_GREED", ROLL_TYPE_GREED, false)
	add("LOOT_ROLL_DISENCHANT", ROLL_TYPE_DISENCHANT, false)
	add("LOOT_ROLL_NEED_SELF", ROLL_TYPE_NEED, true)
	add("LOOT_ROLL_GREED_SELF", ROLL_TYPE_GREED, true)
	add("LOOT_ROLL_DISENCHANT_SELF", ROLL_TYPE_DISENCHANT, true)
	add("LOOT_ROLL_PASSED_SELF", ROLL_TYPE_PASS, true)
	add("LOOT_ROLL_PASSED_SELF_AUTO", ROLL_TYPE_PASS, true)
	return list
end

local blizzardPatterns

local ruRollChoiceText

local function GetRuRollChoiceText()
	if ruRollChoiceText then return ruRollChoiceText end
	ruRollChoiceText = {
		["Мне это нужно"] = ROLL_TYPE_NEED,
		["Не откажусь"] = ROLL_TYPE_GREED,
		["Распылить"] = ROLL_TYPE_DISENCHANT,
		["Пас"] = ROLL_TYPE_PASS,
		["Отказаться"] = ROLL_TYPE_PASS,
	}
	if PASS and PASS ~= "" then
		ruRollChoiceText[PASS] = ROLL_TYPE_PASS
	end
	return ruRollChoiceText
end

-- Клиент добавляет точку/кавычки после выбора: "Не откажусь". и "Мне это нужно"."
local function TrimRollMsg(s)
	if not s then return s end
	return (s:gsub("^%s+", ""):gsub("%s+$", ""):gsub('[%.",]+$', ""))
end

local function ParseRuRollChoice(msg)
	if not msg or not msg:find("Разыгрывается", 1, true) then return end
	local itemToken, playerName, choice = msg:match('Разыгрывается: (.+)%. ([^:]+):%s*"(.+)"')
	if not itemToken or not playerName or not choice then return end
	playerName = TrimRollMsg(playerName)
	choice = TrimRollMsg(choice)
	local rollType = GetRuRollChoiceText()[choice]
	if not rollType then return end
	return playerName, itemToken, rollType
end

-- Пас: отдельное сообщение, не "Разыгрывается: …"
local function ParseRuPassDecline(msg)
	if not msg then return end

	local playerName, itemToken = msg:match("^(.*) отказывается от предмета (.+)")
	if playerName and itemToken then
		return TrimRollMsg(playerName), TrimRollMsg(itemToken), ROLL_TYPE_PASS
	end

	playerName, itemToken = msg:match("^(.*) автоматически передает предмет (.+)")
	if playerName and itemToken then
		return TrimRollMsg(playerName), TrimRollMsg(itemToken), ROLL_TYPE_PASS
	end

	playerName, itemToken = msg:match('^(.*) пропускает розыгрыш предмета "(.+)"')
	if playerName and itemToken then
		return TrimRollMsg(playerName), TrimRollMsg(itemToken), ROLL_TYPE_PASS
	end
end

local function BuildElvUIFallbackPatterns()
	local locale = GetLocale()
	local rollMessages = locale == "ruRU" and {
		["(.*) автоматически передает предмет (.+), поскольку не может его забрать"] = ROLL_TYPE_PASS,
		["(.*) пропускает розыгрыш предмета \"(.+)\", поскольку не может его забрать"] = ROLL_TYPE_PASS,
		["(.*) отказывается от предмета (.+)"] = ROLL_TYPE_PASS,
		['Разыгрывается: (.+)%. (.*): "Мне это нужно".*'] = ROLL_TYPE_NEED,
		['Разыгрывается: (.+)%. (.*): "Не откажусь".*'] = ROLL_TYPE_GREED,
		['Разыгрывается: (.+)%. (.*): "Распылить".*'] = ROLL_TYPE_DISENCHANT,
	} or {
		["^(.*) automatically passed on: (.+) because s?he cannot loot that item.$"] = ROLL_TYPE_PASS,
		["^(.*) passed on: (.+|r)$"] = ROLL_TYPE_PASS,
		["(.*) has selected Need for: (.+)"] = ROLL_TYPE_NEED,
		["(.*) has selected Greed for: (.+)"] = ROLL_TYPE_GREED,
		["(.*) has selected Disenchant for: (.+)"] = ROLL_TYPE_DISENCHANT,
	}
	local list = {}
	for regex, rollType in pairs(rollMessages) do
		tinsert(list, { regex = regex, rollType = rollType })
	end
	return list
end

local elvuiPatterns

local function ParseBlizzardMessage(msg)
	if not blizzardPatterns then blizzardPatterns = BuildBlizzardPatterns() end
	for _, entry in ipairs(blizzardPatterns) do
		local playerName, itemToken = MatchChatPattern(msg, entry.pat, entry.selfOnly)
		if playerName and itemToken and playerName ~= "Everyone" then
			return playerName, itemToken, entry.rollType
		end
	end
end

local function ParseElvUIMessage(msg)
	if not elvuiPatterns then elvuiPatterns = BuildElvUIFallbackPatterns() end
	local locale = GetLocale()
	for _, entry in ipairs(elvuiPatterns) do
		local _, _, playerName, itemLink = find(msg, entry.regex)
		if playerName and itemLink and playerName ~= "Everyone" then
			if locale == "ruRU" and entry.rollType ~= ROLL_TYPE_PASS then
				playerName, itemLink = itemLink, playerName
			end
			return playerName, itemLink, entry.rollType
		end
	end
end

local function ParseRollChoice(msg)
	-- Prefer Blizzard LOOT_ROLL_* globals (locale-correct on all clients)
	local playerName, itemToken, rollType = ParseBlizzardMessage(msg)
	if playerName and itemToken then
		return playerName, itemToken, rollType
	end

	playerName, itemToken, rollType = ParseElvUIMessage(msg)
	if playerName and itemToken then
		return playerName, itemToken, rollType
	end

	-- Russian private-server chat variants when Blizzard patterns miss
	if GetLocale() == "ruRU" then
		playerName, itemToken, rollType = ParseRuRollChoice(msg)
		if not playerName then
			playerName, itemToken, rollType = ParseRuPassDecline(msg)
		end
		if playerName and itemToken then
			return playerName, itemToken, rollType
		end
	end
end

local function RecordRoll(playerName, itemToken, rollType)
	if not playerName or not itemToken or rollType == nil then return end

	local rollData
	for _, data in pairs(activeRolls) do
		if ItemsMatch(data.itemLink, itemToken) then
			rollData = data
			break
		end
	end

	if not rollData then
		local frame = FindFrameByItemToken(itemToken)
		if frame and frame.rollID then
			rollData = activeRolls[frame.rollID]
		end
	end

	if not rollData or rollData.results[playerName] then return end

	local class = ResolvePlayerClass(playerName)
	rollData.results[playerName] = { rollType, class }
	rollData.counts[rollType] = (rollData.counts[rollType] or 0) + 1

	local frame = FindFrameByItemToken(itemToken)
	if frame then
		RefreshFrameCounts(frame, rollData)
		RefreshOpenTooltipForFrame(frame)
	end
end

local function OnStartLootRoll(_, rollID)
	if not rollID then return end
	local itemLink = GetLootRollItemLink(rollID)
	-- START_LOOT_ROLL приходит после GroupLootFrame_OnShow: не пересоздаём и не сбрасываем счётчики
	if not activeRolls[rollID] then
		activeRolls[rollID] = NewRollData(itemLink)
	else
		activeRolls[rollID].itemLink = itemLink
	end
end

local function OnCancelLootRoll(_, rollID)
	if not rollID then return end
	activeRolls[rollID] = nil
	local frame = FindFrameByRollID(rollID)
	if frame then
		LootRollCounts.ClearFrameCounts(frame)
	end
end

local function OnChatMsgLoot(_, msg)
	if not msg then return end
	local playerName, itemToken, rollType = ParseRollChoice(msg)
	if playerName and itemToken then
		RecordRoll(playerName, itemToken, rollType)
	end
end

local function OnGroupLootShow(frame)
	if not frame or not frame.rollID then return end

	local rollData = activeRolls[frame.rollID]
	if not rollData then
		rollData = NewRollData(GetLootRollItemLink(frame.rollID))
		activeRolls[frame.rollID] = rollData
	end

	InstallFrameRollButtons(frame)
	RefreshFrameCounts(frame, rollData)
end

local function HookGroupLootFrames()
	for i = 1, LootRollCounts.NumFrames() do
		local frame = LootRollCounts.GetFrame(i)
		if frame and not frame.sarychRollCountsHooked then
			frame.sarychRollCountsHooked = true
			local origOnShow = frame:GetScript("OnShow")
			frame:SetScript("OnShow", function(self, ...)
				if origOnShow then origOnShow(self, ...) end
				OnGroupLootShow(self)
			end)
			local origOnHide = frame:GetScript("OnHide")
			frame:SetScript("OnHide", function(self, ...)
				if origOnHide then origOnHide(self, ...) end
				HideRollButtonTooltip()
				if self.rollID then
					activeRolls[self.rollID] = nil
				end
				LootRollCounts.ClearFrameCounts(self)
			end)
		end
	end

	if not LootRollCounts.groupLootOnShowHooked and type(GroupLootFrame_OnShow) == "function" then
		hooksecurefunc("GroupLootFrame_OnShow", function(self)
			if enabled then
				OnGroupLootShow(self)
			end
		end)
		LootRollCounts.groupLootOnShowHooked = true
	end
end

function LootRollCounts.Enable()
	if enabled then
		LootRollCounts.ApplyStyleAll()
		return
	end
	enabled = true

	if not eventFrame then
		eventFrame = CreateFrame("Frame")
	end
	eventFrame:RegisterEvent("CHAT_MSG_LOOT")
	eventFrame:RegisterEvent("START_LOOT_ROLL")
	eventFrame:RegisterEvent("CANCEL_LOOT_ROLL")
	eventFrame:SetScript("OnEvent", function(_, event, ...)
		if event == "CHAT_MSG_LOOT" then
			OnChatMsgLoot(nil, ...)
		elseif event == "START_LOOT_ROLL" then
			OnStartLootRoll(nil, ...)
		elseif event == "CANCEL_LOOT_ROLL" then
			OnCancelLootRoll(nil, ...)
		end
	end)

	HookGroupLootFrames()
	LootRollCounts.ApplyStyleAll()

	for i = 1, LootRollCounts.NumFrames() do
		local frame = LootRollCounts.GetFrame(i)
		if frame and frame:IsShown() then
			OnGroupLootShow(frame)
		end
	end
end

function LootRollCounts.Disable()
	if not enabled then return end
	enabled = false
	HideRollButtonTooltip()
	if eventFrame then
		eventFrame:UnregisterAllEvents()
		eventFrame:SetScript("OnEvent", nil)
	end
	wipe(activeRolls)
	for i = 1, LootRollCounts.NumFrames() do
		LootRollCounts.ClearFrameCounts(LootRollCounts.GetFrame(i))
	end
end

function LootRollCounts.IsEnabled()
	return enabled
end

return LootRollCounts
