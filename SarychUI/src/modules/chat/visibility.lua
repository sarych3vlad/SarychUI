local ChatVisibility = {}
_G.SarychUI_ChatVisibility = ChatVisibility

local State = {
	enabled = false,
	hidden = false,
	snapshot = nil,
	guardedFrames = setmetatable({}, { __mode = "k" }),
}

local function IsEnabledValue(value)
	return value == true or value == 1
end

local function GetChatDB()
	local profile = SarychUI and SarychUI.db and SarychUI.db.profile
	local modules = profile and profile.modules
	return modules and modules.chat or nil
end

local function IsVisibilityEnabled()
	local chat = GetChatDB()
	local visibility = chat and chat.chatVisibility
	return chat and IsEnabledValue(chat.enabled)
		and visibility and IsEnabledValue(visibility.enabled)
end

local function GuardFrame(frame)
	if not frame or State.guardedFrames[frame] then
		return
	end
	State.guardedFrames[frame] = true
	frame:HookScript("OnShow", function(self)
		if State.hidden then
			self:Hide()
		end
	end)
end

local function AddManagedFrame(frames, seen, frame)
	if not frame or seen[frame] then
		return
	end
	seen[frame] = true
	GuardFrame(frame)
	frames[#frames + 1] = frame
end

local function CollectManagedFrames()
	local frames = {}
	local seen = {}
	local count = tonumber(_G.NUM_CHAT_WINDOWS) or 10

	for i = 1, count do
		local chatFrame = _G["ChatFrame" .. i]
		AddManagedFrame(frames, seen, chatFrame)
		AddManagedFrame(frames, seen, _G["ChatFrame" .. i .. "Tab"])
		AddManagedFrame(frames, seen, _G["ChatFrame" .. i .. "Minimized"])
		AddManagedFrame(frames, seen, _G["ChatFrame" .. i .. "EditBox"])
		if chatFrame then
			AddManagedFrame(frames, seen, chatFrame.editBox)
		end
	end

	AddManagedFrame(frames, seen, _G.ChatFrameEditBox)
	AddManagedFrame(frames, seen, _G.ChatFrameMenuButton)
	AddManagedFrame(frames, seen, _G.CombatLogButtons)
	AddManagedFrame(frames, seen, _G.GeneralDockManager)
	AddManagedFrame(frames, seen, _G.ChatBarFrame)
	AddManagedFrame(frames, seen, _G.SarychUIChatLagBar)

	return frames
end

local function HideTransientChatFrames()
	if _G.ChatMenu then
		_G.ChatMenu:Hide()
	end
	if _G.SarychUI_CustomChatMenu then
		_G.SarychUI_CustomChatMenu:Hide()
	end
end

local function RefreshManagedControls()
	local chatModule = SarychUI and SarychUI.modules and SarychUI.modules.chat
	if not chatModule then
		return
	end
	if chatModule.ApplyChatBarSettings then
		chatModule:ApplyChatBarSettings()
	end
	if chatModule.ApplyChatFrameButtonSettings then
		chatModule:ApplyChatFrameButtonSettings()
	end
	if _G.SarychUI_UpdateChatLagBar then
		_G.SarychUI_UpdateChatLagBar()
	end
end

function ChatVisibility.Hide()
	if State.hidden then
		return
	end

	local frames = CollectManagedFrames()
	local snapshot = {}
	for _, frame in ipairs(frames) do
		snapshot[frame] = frame:IsShown() and true or false
	end

	State.snapshot = snapshot
	State.hidden = true
	for _, frame in ipairs(frames) do
		frame:Hide()
	end
	HideTransientChatFrames()
end

function ChatVisibility.Show()
	if not State.hidden then
		return
	end

	local snapshot = State.snapshot or {}
	State.hidden = false
	State.snapshot = nil

	-- Restore visible frames first, then explicitly keep previously hidden frames hidden.
	-- The second pass prevents one frame's OnShow handler from reviving another frame.
	for frame, wasShown in pairs(snapshot) do
		if wasShown then
			frame:Show()
		end
	end
	for frame, wasShown in pairs(snapshot) do
		if not wasShown then
			frame:Hide()
		end
	end

	RefreshManagedControls()
end

function ChatVisibility.Toggle(silent)
	if not State.enabled then
		return
	end
	local sound
	if State.hidden then
		sound = "igMiniMapZoomIn"
		if not silent and PlaySound then PlaySound(sound) end
		ChatVisibility.Show()
	else
		sound = "igMiniMapZoomOut"
		if not silent and PlaySound then PlaySound(sound) end
		ChatVisibility.Hide()
	end
	return sound
end

function ChatVisibility.IsHidden()
	return State.hidden
end

function ChatVisibility.ApplySettings()
	local chat = GetChatDB()
	local visibility = chat and chat.chatVisibility
	local bindings = _G.SarychUI_ToggleBindings
	local key = bindings and bindings:NormalizeKey(visibility and visibility.key) or nil
	local extension = SarychUI.extensions and SarychUI.extensions.visibility_control

	-- Without a key there would be no way to bring a hidden chat back.
	State.enabled = (not extension or extension:IsEnabled()) and IsVisibilityEnabled() and key ~= nil
	if not State.enabled and State.hidden then
		ChatVisibility.Show()
	end
	if bindings then
		if State.enabled then
			bindings:SetAction("chat_visibility", key, function()
				return ChatVisibility.Toggle(true)
			end)
		else
			bindings:RemoveAction("chat_visibility")
		end
	end
end

function ChatVisibility.Disable()
	State.enabled = false
	if State.hidden then
		ChatVisibility.Show()
	end
	local bindings = _G.SarychUI_ToggleBindings
	if bindings then
		bindings:RemoveAction("chat_visibility")
	end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self, event, addon)
	if event == "ADDON_LOADED" and addon == "SarychUI" then
		self:SetScript("OnUpdate", function(frame)
			frame:SetScript("OnUpdate", nil)
			ChatVisibility.ApplySettings()
		end)
	elseif event == "PLAYER_LOGIN" then
		ChatVisibility.ApplySettings()
	end
end)
