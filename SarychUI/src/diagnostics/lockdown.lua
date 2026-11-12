-- Optional diagnostics for protected functions tainted/blocked in combat.
-- Controlled by SUI -> System or /slockdown on|off.

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

local RefreshRuntime
local function IsEnabled()
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
	if RefreshRuntime then RefreshRuntime(enabled) end
	return enabled
end

function SarychUI:IsLockdownErrorSearchEnabled()
	return IsEnabled()
end

function SarychUI:SetLockdownErrorSearchEnabled(enabled)
	return SetEnabled(enabled)
end

-- Saved opt-in is applied only after AceDB selects the active profile.
function SarychUI:ApplyLockdownErrorSearchSettings()
	local profile = self.db and self.db.profile
	if type(profile) ~= "table" then return end
	local system = GetSystemConfig(false)
	SetEnabled(system and (system.lockdownErrorSearch == true or system.lockdownErrorSearch == 1) or false)
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

-- The forbidden-action stack shows where protected execution stopped, not
-- where its taint first entered. Inspect the globals and the clicked action
-- button separately so the next report can identify which path is dirty.
local function PrintSecuritySnapshot()
	if type(issecurevariable) ~= "function" then return end

	local function Check(object, field, label)
		if not object then return false end
		local ok, secure, source = pcall(issecurevariable, object, field)
		if ok and secure == false then
			Chat(PREFIX .. " taint " .. label .. " = " .. tostring(source or "?"))
			return true
		end
		return false
	end

	local dirty = false
	for _, name in ipairs({
		"CreateFrame", "UseAction", "CastSpellByName", "ActionButton_CalculateAction",
		"ChatEdit_SendText", "ChatEdit_ParseText", "SecureCmdOptionParse",
		"GetItemInfo", "GetMacroInfo", "MacroFrame_SaveMacro",
		"GetActionInfo", "MacroEditBox", "SecureCmdList",
	}) do
		if Check(_G, name, name) then dirty = true end
	end
	if Check(_G.SecureCmdList, "CASTSEQUENCE", "SecureCmdList.CASTSEQUENCE") then dirty = true end
	if Check(_G.SecureCmdList, "CAST", "SecureCmdList.CAST") then dirty = true end
	local macroEditBox = _G.MacroEditBox
	if macroEditBox then
		for _, field in ipairs({ "SetText", "GetText", "SetAttribute", "GetAttribute" }) do
			if Check(macroEditBox, field, "MacroEditBox." .. field) then dirty = true end
		end
	end

	local focus = GetMouseFocus and GetMouseFocus()
	if focus then
		local name = focus.GetName and focus:GetName() or "<без имени>"
		Chat(PREFIX .. " под курсором: " .. tostring(name))
	end

	local prefixes = {
		"ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
		"MultiBarLeftButton", "MultiBarRightButton", "BonusActionButton",
	}
	local shown = 0
	for _, prefix in ipairs(prefixes) do
		for i = 1, 12 do
			local name = prefix .. i
			local button = _G[name]
			if button then
				for _, field in ipairs({
					"action", "buttonType", "isBonus", "alwaysBonus",
					"SetNormalTexture", "eventsRegistered", "rangeTimer",
					"feedback_action", "UpdateTooltip",
				}) do
					local ok, secure, source = pcall(issecurevariable, button, field)
					if ok and secure == false then
						dirty = true
						if shown < 12 then
							Chat(PREFIX .. " taint " .. name .. "." .. field .. " = " .. tostring(source or "?"))
							shown = shown + 1
						end
					end
				end
			end
		end
	end
	if shown == 12 then Chat(PREFIX .. " показаны первые 12 заражённых полей кнопок") end
	if not dirty then Chat(PREFIX .. " проверенные глобальные функции и поля кнопок чисты") end
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
	if source == "ADDON_ACTION_FORBIDDEN" and func == "CastSpellByName()" then
		PrintSecuritySnapshot()
	end
end

local watcher, popupHooked, originalErrorHandler, diagnosticErrorHandler
RefreshRuntime = function(enabled)
    if not enabled then
        if watcher then watcher:UnregisterAllEvents() end
        if diagnosticErrorHandler and geterrorhandler and seterrorhandler
            and geterrorhandler() == diagnosticErrorHandler then
            seterrorhandler(originalErrorHandler)
            diagnosticErrorHandler, originalErrorHandler = nil, nil
        end
        return
    end
    if not watcher then
        watcher = CreateFrame("Frame")
        watcher:SetScript("OnEvent", function(_, event, addon, func)
            PrintLockdown(event, addon, func)
        end)
    end
    watcher:RegisterEvent("ADDON_ACTION_FORBIDDEN")
    watcher:RegisterEvent("ADDON_ACTION_BLOCKED")
    if not popupHooked and type(StaticPopup_Show) == "function" and hooksecurefunc then
        popupHooked = true
        hooksecurefunc("StaticPopup_Show", function(which, text1, text2, data)
            if IsEnabled() and (which == "ADDON_ACTION_FORBIDDEN" or which == "ADDON_ACTION_BLOCKED") then
                PrintLockdown("StaticPopup." .. tostring(which), text1, data or text2)
            end
        end)
    end
    if not diagnosticErrorHandler and geterrorhandler and seterrorhandler then
        originalErrorHandler = geterrorhandler()
        diagnosticErrorHandler = function(msg)
            if IsEnabled() and type(msg) == "string" then
                local lower = strlower(msg)
                if lower:find("protected", 1, true) or lower:find("forbidden", 1, true)
                    or lower:find("заблокир", 1, true) or lower:find("защищен", 1, true)
                    or (lower:find("sarychui", 1, true) and lower:find("action", 1, true)) then
                    PrintLockdown("errorhandler", "SarychUI", msg)
                end
            end
            if originalErrorHandler then return originalErrorHandler(msg) end
        end
        seterrorhandler(diagnosticErrorHandler)
    end
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
