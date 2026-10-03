-- Optional diagnostics for protected functions tainted/blocked in combat.
-- Controlled by SUI -> System -> Overview or /slockdown on|off.

local PREFIX = "|cffff8800[SUI Lockdown]|r"
_G.SarychUI_DebugLockdown = false

local lastKey
local lastTime = 0
local lastCount = 0

local function GetSystemConfig(create)
	local profile = SarychUI and SarychUI.db and SarychUI.db.profile
	if type(profile) ~= "table" then
		return nil
	end
	if create and type(profile.system) ~= "table" then
		profile.system = {}
	end
	return profile.system
end

local function IsEnabled()
	local system = GetSystemConfig(false)
	if system and system.lockdownErrorSearch ~= nil then
		return system.lockdownErrorSearch == true or system.lockdownErrorSearch == 1
	end
	return _G.SarychUI_DebugLockdown == true
end

local function SetEnabled(enabled)
	enabled = enabled and true or false
	_G.SarychUI_DebugLockdown = enabled
	local system = GetSystemConfig(true)
	if system then
		system.lockdownErrorSearch = enabled
	end
	if not enabled then
		lastKey = nil
		lastTime = 0
		lastCount = 0
	end
	return enabled
end

function SarychUI:IsLockdownErrorSearchEnabled()
	return IsEnabled()
end

function SarychUI:SetLockdownErrorSearchEnabled(enabled)
	return SetEnabled(enabled)
end

local function Chat(msg)
	if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage(msg)
	elseif print then
		print(msg)
	end
end

local function PrintStack(skip)
	if not debugstack then
		return
	end
	local stack = debugstack(skip or 3, 10, 2)
	if type(stack) ~= "string" or stack == "" then
		return
	end
	Chat(PREFIX .. " стек:")
	local n = 0
	for line in string.gmatch(stack, "[^\n]+") do
		n = n + 1
		if n > 10 then
			break
		end
		Chat("|cffaaaaaa  " .. line .. "|r")
	end
end

local function PrintLockdown(source, addon, func, extra)
	if not IsEnabled() then
		return
	end

	local key = tostring(source) .. "|" .. tostring(addon) .. "|" .. tostring(func)
	local now = GetTime and GetTime() or 0
	if key == lastKey and (now - lastTime) < 0.75 then
		lastCount = lastCount + 1
		return
	end
	if lastCount > 0 and lastKey then
		Chat(string.format("%s повтор предыдущего: ещё %d раз", PREFIX, lastCount))
	end
	lastKey = key
	lastTime = now
	lastCount = 0

	Chat(string.format(
		"%s %s | аддон=|cffffffff%s|r | функция=|cffff3333%s|r | бой=%s lockdown=%s",
		PREFIX,
		tostring(source),
		tostring(addon or "?"),
		tostring(func or "?"),
		(UnitAffectingCombat and UnitAffectingCombat("player")) and "да" or "нет",
		(InCombatLockdown and InCombatLockdown()) and "да" or "нет"
	))
	if extra and extra ~= "" then
		Chat(PREFIX .. " " .. extra)
	end
	PrintStack(4)
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_ACTION_FORBIDDEN")
watcher:RegisterEvent("ADDON_ACTION_BLOCKED")
watcher:SetScript("OnEvent", function(_, event, addon, func)
	PrintLockdown(event, addon, func)
end)

if type(StaticPopup_Show) == "function" and hooksecurefunc then
	hooksecurefunc("StaticPopup_Show", function(which, text1, text2, data)
		if which == "ADDON_ACTION_FORBIDDEN" or which == "ADDON_ACTION_BLOCKED" then
			PrintLockdown("StaticPopup." .. tostring(which), text1, data or text2)
		end
	end)
end

local origErrorHandler = geterrorhandler and geterrorhandler()
if seterrorhandler then
	seterrorhandler(function(msg)
		if IsEnabled() and type(msg) == "string" then
			local lower = strlower(msg)
			if lower:find("protected", 1, true)
				or lower:find("forbidden", 1, true)
				or lower:find("заблокир", 1, true)
				or lower:find("защищен", 1, true)
				or lower:find("sarychui", 1, true) and lower:find("action", 1, true)
			then
				PrintLockdown("errorhandler", "SarychUI", msg)
			end
		end
		if origErrorHandler then
			return origErrorHandler(msg)
		end
	end)
end

SLASH_SARYCHUILOCKDOWN1 = "/slockdown"
SlashCmdList["SARYCHUILOCKDOWN"] = function(msg)
	msg = strlower(msg or "")
	if msg == "off" then
		SetEnabled(false)
		Chat(PREFIX .. " выключен")
	else
		SetEnabled(true)
		Chat(PREFIX .. " включен: в бою повтори действие. Выключить: /slockdown off")
	end
end
