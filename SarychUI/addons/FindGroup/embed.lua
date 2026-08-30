-- SarychUI embedding layer for FindGroup (loaded after FindGroup.xml)

local DEBUG_PERF = false
local REFRESH_DELAY = 0.20

local FRAME_NAMES = {
	"FindGroupFrame",
	"FindGroupOptionsFrame",
	"FindGroupShadow",
	"FindGroupChannel",
	"FindGroupShowText",
	"FindGroupTooltip",
	"FindGroupConfigFrameH",
	"FindGroupSavesFrame",
	"FindGroupInfoVesr",
}

function SarychUI_HideEmbeddedFindGroupUI()
	for i = 1, #FRAME_NAMES do
		local frame = _G[FRAME_NAMES[i]]
		if frame and frame.Hide then
			frame:Hide()
		end
	end
end

if FGL and FGL.db then
	FGL.db.includeaddon = FindGroupEnabled and 1 or 0
end

local refreshPending
local refreshElapsed = 0
local refreshFrame = CreateFrame("Frame")
refreshFrame:Hide()

local function FindGroupPerfLog(label, value)
	if DEBUG_PERF and DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("[FindGroup PERF] " .. label .. ": " .. value)
	end
end

local function DoFindGroupRefresh()
	refreshPending = nil
	refreshElapsed = 0
	refreshFrame:Hide()

	if type(FindGroup_AllReWrite) == "function" then
		FindGroup_AllReWrite()
	end
	if FindGroupFrame and FindGroupFrame:IsVisible() and type(FindGroup_SliderCheck) == "function" then
		FindGroup_SliderCheck()
	end
end

function SarychUI_FindGroupQueueRefresh(force)
	if force then
		DoFindGroupRefresh()
		return
	end
	if refreshPending then
		return
	end
	refreshPending = true
	refreshElapsed = 0
	refreshFrame:Show()
end

refreshFrame:SetScript("OnUpdate", function(self, elapsed)
	if not refreshPending then
		self:Hide()
		return
	end
	refreshElapsed = refreshElapsed + elapsed
	if refreshElapsed < REFRESH_DELAY then
		return
	end
	DoFindGroupRefresh()
end)

local CHAT_EVENTS = {
	CHAT_MSG_OFFICER = true,
	CHAT_MSG_CHANNEL = true,
	CHAT_MSG_GUILD = true,
	CHAT_MSG_YELL = true,
	CHAT_MSG_SYSTEM = true,
}

local CHAT_SIGNAL_WORDS = {
	"lf", "lfg", "lfm", "lfr", "need", "nedd", "tank", "heal", "healer", "dd", "dps", "raid", "party", "icc", "toc", "voa", "ony", "uldu", "ulduar", "naxx", "rs", "os",
	"лф", "лфг", "лфм", "лфр", "нуж", "ищ", "соб", "добор", "пати", "рейд", "танк", "хил", "дд", "рдд", "мдд", "цлк", "ик", "ивк", "оса", "оня", "ульд", "накс", "сарт", "рс", "рбк", "гс",
}

local lastPrefilterMsg
local lastPrefilterResult

local function TextHasPlain(text, token)
	return text and token and token ~= "" and text:find(token, 1, true)
end

local function CriteriaHasPlain(text, criteria)
	if type(criteria) == "string" then
		return TextHasPlain(text, criteria)
	elseif type(criteria) == "table" then
		for i = 1, #criteria do
			if CriteriaHasPlain(text, criteria[i]) then
				return true
			end
		end
	end
end

local function ShouldScanChatMessage(event, msg)
	if not CHAT_EVENTS[event] or not msg or msg == "" then
		return false
	end
	if msg == lastPrefilterMsg then
		return lastPrefilterResult
	end

	local lmsg = msg:lower()
	local result = false

	if event == "CHAT_MSG_SYSTEM" then
		result = TextHasPlain(lmsg, "анон")
	else
		for i = 1, #CHAT_SIGNAL_WORDS do
			if TextHasPlain(lmsg, CHAT_SIGNAL_WORDS[i]) then
				result = true
				break
			end
		end

		if not result and FGL and FGL.db and FGL.db.instances then
			for i = 1, #FGL.db.instances do
				local inst = FGL.db.instances[i]
				if inst and inst.search and inst.search.criteria then
					for j = 1, #inst.search.criteria do
						if CriteriaHasPlain(lmsg, inst.search.criteria[j]) then
							result = true
							break
						end
					end
				end
				if result then
					break
				end
			end
		end
	end

	lastPrefilterMsg = msg
	lastPrefilterResult = result
	return result
end

if type(FindGroup_GFIND) == "function" then
	local origFindGroupGFIND = FindGroup_GFIND
	FindGroup_GFIND = function(...)
		if not SarychUI_FindGroupIsActive() then
			return
		end
		local event, msg = select(2, ...), select(3, ...)
		if not ShouldScanChatMessage(event, msg) then
			return
		end
		local t0 = debugprofilestop and debugprofilestop()
		local result = origFindGroupGFIND(...)
		if t0 then
			local dt = debugprofilestop() - t0
			if dt > 2 then
				FindGroupPerfLog("chat handler", string.format("%.2f ms | %s", dt, tostring(event)))
			end
		end
		return result
	end
end

if not _G.__SarychUIFindGroupShowWindowHooked and type(FindGroup_ShowWindow) == "function" then
	_G.__SarychUIFindGroupShowWindowHooked = true
	local origFindGroupShowWindow = FindGroup_ShowWindow
	FindGroup_ShowWindow = function(...)
		local result = origFindGroupShowWindow(...)
		SarychUI_FindGroupQueueRefresh(true)
		return result
	end
end

function SarychUI_InitEmbeddedFindGroup()
	if _G.FindGroupEmbeddedInitialized then
		return true
	end
	_G.FindGroupEmbeddedInitialized = true

	if FGL and FGL.db and FGL.SPACE_NAME then
		local space = getglobal(FGL.SPACE_NAME)
		if space and space.GetCS then
			FGL.db.chsum = space.GetCS(FGL.db)
		end
	end
	if type(FindGroup_OnLoad) == "function" then
		FindGroup_OnLoad()
	end
	if type(FGC_OnLoad) == "function" then
		FGC_OnLoad()
	end
	if type(FindGroupSaves_OnLoad) == "function" then
		FindGroupSaves_OnLoad()
	end
	return true
end


local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(self, event, addonName)
	if addonName ~= "SarychUI" then
		return
	end
	self:UnregisterEvent("ADDON_LOADED")

	if SarychUI_IsStandaloneFindGroupEnabled and SarychUI_IsStandaloneFindGroupEnabled() then
		FindGroupEnabled = false
		if FGL and FGL.db then
			FGL.db.includeaddon = 0
		end
		SarychUI_HideEmbeddedFindGroupUI()
		return
	end

	if not FindGroupEnabled then
		if FGL and FGL.db then
			FGL.db.includeaddon = 0
		end
		SarychUI_HideEmbeddedFindGroupUI()
		if SlashCmdList then
			SlashCmdList["FindGroup"] = function() end
		end
		return
	end

	SarychUI_InitEmbeddedFindGroup()
end)

if not FindGroupEnabled then
	SarychUI_HideEmbeddedFindGroupUI()
end
