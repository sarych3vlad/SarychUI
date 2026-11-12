local ToggleBindings = {}
_G.SarychUI_ToggleBindings = ToggleBindings
SarychUI.ToggleBindings = ToggleBindings

local State = {
	actions = {},
	buttons = {},
	nextActionOrder = 0,
	nextButtonID = 0,
	owner = CreateFrame("Frame", "SarychUIToggleBindingOwner", UIParent),
	eventFrame = CreateFrame("Frame"),
}

-- The binding button runs this before its ordinary Lua click hook.  A real
-- secure Hide also removes mouse hit testing and cooldown overlays in combat.
local SECURE_VISIBILITY_CLICK = [[
if down then return end
for slot = 1, (self:GetAttribute("visibilitySlots") or 0) do
	local prefix = "visibility" .. self:GetAttribute("visibilityIndex" .. slot)
	local hidden = not self:GetAttribute(prefix .. "Hidden")
	self:SetAttribute(prefix .. "Hidden", hidden)
	for index = 1, (self:GetAttribute(prefix .. "Count") or 0) do
		local frame = self:GetFrameRef(prefix .. "Frame" .. index)
		if frame then
			if hidden then
				self:SetAttribute(prefix .. "Seen" .. index, frame:IsShown())
				frame:Hide()
			elseif self:GetAttribute(prefix .. "Seen" .. index) then
				frame:Show()
			end
		end
	end
end
]]

local function NormalizeKey(key)
	if type(key) ~= "string" then
		return nil
	end
	key = key:gsub("^%s+", ""):gsub("%s+$", "")
	if key == "" or key:upper() == "NONE" then
		return nil
	end
	return key:upper()
end

function ToggleBindings:NormalizeKey(key)
	return NormalizeKey(key)
end

local function ReportCallbackError(message)
	if geterrorhandler then
		local handler = geterrorhandler()
		if handler then
			handler(message)
		end
	end
end

function ToggleBindings:Dispatch(key, down)
	key = NormalizeKey(key)
	if not key then
		return
	end

	local matching = {}
	for _, action in pairs(State.actions) do
		if action.key == key and action.onKeyDown == (down and true or false) then
			matching[#matching + 1] = action
		end
	end
	table.sort(matching, function(left, right)
		return left.order < right.order
	end)

	local sounds = {}
	local soundOrder = {}
	for _, action in ipairs(matching) do
		local ok, sound = pcall(action.callback)
		if not ok then
			ReportCallbackError(sound)
		elseif type(sound) == "string" and sound ~= "" and not sounds[sound] then
			sounds[sound] = true
			soundOrder[#soundOrder + 1] = sound
		end
	end

	if PlaySound then
		for _, sound in ipairs(soundOrder) do
			PlaySound(sound)
		end
	end
end

local function GetButton(key)
	local button = State.buttons[key]
	if button then
		return button
	end

	State.nextButtonID = State.nextButtonID + 1
	local name = "SarychUIToggleBindingButton" .. State.nextButtonID
	button = CreateFrame("Button", name, State.owner, "SecureHandlerClickTemplate")
	-- This dispatcher owns both click phases and secure visibility snippets.
	button.sarychPreserveClickPhases = true
	button:SetSize(1, 1)
	button:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -20, -20)
	button:SetAlpha(0)
	button:RegisterForClicks("AnyUp")
	button:SetAttribute("_onclick", SECURE_VISIBILITY_CLICK)
	button:HookScript("OnClick", function(_, _, down)
		ToggleBindings:Dispatch(key, down)
	end)
	State.buttons[key] = button
	return button
end

local function ConfigureSecureVisibility(button, actions)
	local previous = button.visibilitySlots or {}
	local seenByAction = {}
	for slot, entry in ipairs(previous) do
		local prefix = "visibility" .. entry.action.order
		local wasHidden = button:GetAttribute(prefix .. "Hidden")
		local seen = {}
		for index, frame in ipairs(entry.frames) do
			seen[frame] = button:GetAttribute(prefix .. "Seen" .. index)
			local guardKey = prefix .. ":" .. tostring(frame)
			local guard = button.visibilityGuards and button.visibilityGuards[guardKey]
			if guard then button:SetAttribute(guard, nil) end
		end
		seenByAction[entry.action] = seen
		entry.action.secureSeenMap = seen
		button:SetAttribute(prefix .. "Hidden", false)
		if wasHidden then
			for _, frame in ipairs(entry.frames) do
				if seen[frame] then frame:Show() end
			end
		end
	end
	local slots = {}
	for _, action in ipairs(actions) do
		if action.secureFrames and #action.secureFrames > 0 then
			local slot = #slots + 1
			local prefix = "visibility" .. action.order
			button:SetAttribute("visibilityIndex" .. slot, action.order)
			local frames = action.secureFrames
			local oldSeen = seenByAction[action] or action.secureSeenMap or {}
			button:SetAttribute(prefix .. "Hidden", action.secureHidden and true or false)
			button:SetAttribute(prefix .. "Count", #frames)
			for index, frame in ipairs(frames) do
				button:SetFrameRef(prefix .. "Frame" .. index, frame)
				local seen = oldSeen[frame]
				if seen == nil then seen = frame:IsShown() end
				button:SetAttribute(prefix .. "Seen" .. index, seen and true or false)
				if not button.visibilityGuards then button.visibilityGuards = {} end
				local guardKey = prefix .. ":" .. tostring(frame)
				local guard = button.visibilityGuards[guardKey]
				if not guard and SecureHandlerWrapScript then
					button.nextVisibilityGuard = (button.nextVisibilityGuard or 0) + 1
					guard = "visibilityGuard" .. button.nextVisibilityGuard
					SecureHandlerWrapScript(frame, "OnShow", button,
						("local index = owner:GetAttribute(%q); if index and owner:GetAttribute(%q) then owner:SetAttribute(%q .. index, true); self:Hide() end")
						:format(guard, prefix .. "Hidden", prefix .. "Seen"))
					button.visibilityGuards[guardKey] = guard
				end
				if guard then button:SetAttribute(guard, index) end
				if action.secureHidden then frame:Hide() end
			end
			slots[slot] = { action = action, frames = frames }
		end
	end
	button.visibilitySlots = slots
	button:SetAttribute("visibilitySlots", #slots)
end

local function QueueRebuild()
	State.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function ToggleBindings:Rebuild()
	if InCombatLockdown and InCombatLockdown() then
		QueueRebuild()
		return false
	end

	State.eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
	ClearOverrideBindings(State.owner)
	for _, button in pairs(State.buttons) do
		ConfigureSecureVisibility(button, {})
	end

	local keys = {}
	for _, action in pairs(State.actions) do
		keys[action.key] = true
	end
	for key in pairs(keys) do
		local button = GetButton(key)
		local matching = {}
		local onKeyDown = false
		for _, action in pairs(State.actions) do
			if action.key == key then
				matching[#matching + 1] = action
				if action.onKeyDown then onKeyDown = true end
			end
		end
		if onKeyDown then
			button:RegisterForClicks("AnyDown", "AnyUp")
		else
			button:RegisterForClicks("AnyUp")
		end
		table.sort(matching, function(left, right) return left.order < right.order end)
		ConfigureSecureVisibility(button, matching)
		SetOverrideBindingClick(State.owner, true, key, button:GetName(), "LeftButton")
	end
	return true
end

function ToggleBindings:SetSecureFrames(id, frames, hidden)
	local action = State.actions[id]
	if not action then return false end
	action.secureFrames = frames
	action.secureHidden = hidden and true or false
	self:Rebuild()
	return true
end

function ToggleBindings:SyncSecureHidden(id, hidden)
	local action = State.actions[id]
	if action then action.secureHidden = hidden and true or false end
end

function ToggleBindings:SetAction(id, key, callback, onKeyDown)
	if type(id) ~= "string" or id == "" then
		return false
	end

	key = NormalizeKey(key)
	if not key or type(callback) ~= "function" then
		return self:RemoveAction(id)
	end

	local action = State.actions[id]
	if not action then
		State.nextActionOrder = State.nextActionOrder + 1
		action = { order = State.nextActionOrder }
		State.actions[id] = action
	end
	action.key = key
	action.callback = callback
	action.onKeyDown = onKeyDown and true or false
	self:Rebuild()
	return true
end

function ToggleBindings:RemoveAction(id)
	if State.actions[id] == nil then
		return false
	end
	State.actions[id] = nil
	self:Rebuild()
	return true
end

State.eventFrame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_ENABLED" then
		ToggleBindings:Rebuild()
	end
end)
