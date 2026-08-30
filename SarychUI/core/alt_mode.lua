-- SarychUI Alt Mode Utility
-- Tracks Alt for UI overlays. After /reload IsAltKeyDown() can spuriously
-- stay true — we force-clear on world enter, then re-sync.

local pairs = pairs

local AltMode = {}

local isAltPressed = false
local altCallbacks = {}
local notifyingCallbacks = false
local tooltipRefreshRequested = false
-- Ignore raw modifier reads briefly after load (Windows /reload Alt stick).
local ignoreUntil = 0
local lastModifierEvent = 0

local function TryRefreshContext(ctx)
	if not ctx or not ctx.tooltip or not ctx.tooltip:IsShown() or type(ctx.refresh) ~= "function" then
		return false
	end
	return pcall(ctx.refresh)
end

local function RefreshActiveTooltip()
	-- Both tooltip modules capture the original setter. One call is enough:
	-- rebuilding the tooltip runs both OnTooltip hooks with their new Alt state.
	if TryRefreshContext(_G.SarychUI_IDTip_LastTooltip) then return end
	if TryRefreshContext(_G.SarychUI_BagnonFT_LastTooltip) then return end

	local tooltip = GameTooltip
	if not tooltip or not tooltip:IsShown() then return end
	local focus = GetMouseFocus and GetMouseFocus()
	local onEnter = focus and focus.GetScript and focus:GetScript("OnEnter")
	if onEnter then
		pcall(onEnter, focus)
	end
end

local function FlushTooltipRefresh()
	if notifyingCallbacks or not tooltipRefreshRequested then return end
	tooltipRefreshRequested = false
	RefreshActiveTooltip()
end

local function NotifyCallbacks(pressed)
	notifyingCallbacks = true
	for _, callback in pairs(altCallbacks) do
		if type(callback) == "function" then
			callback(pressed)
		end
	end
	notifyingCallbacks = false
	FlushTooltipRefresh()
end

local function SetAltPressed(pressed, forceNotify)
	pressed = not not pressed
	if (not forceNotify) and pressed == isAltPressed then
		return
	end
	isAltPressed = pressed
	NotifyCallbacks(isAltPressed)
end

local function SyncFromApi(forceNotify)
	if GetTime and GetTime() < ignoreUntil then
		SetAltPressed(false, forceNotify)
		return
	end
	local down = false
	if type(IsAltKeyDown) == "function" then
		down = not not IsAltKeyDown()
	end
	SetAltPressed(down, forceNotify)
end

local function HandleModifierStateChanged(key, state)
	if key ~= "LALT" and key ~= "RALT" then
		return
	end
	lastModifierEvent = GetTime and GetTime() or 0
	-- End grace period on a real key event.
	ignoreUntil = 0
	-- Prefer API over single-key state (LALT/RALT can desync).
	SyncFromApi(false)
end

-- Backstop poll interval. MODIFIER_STATE_CHANGED handles normal presses instantly;
-- this only catches a desync after Alt+Tab, where the key-up event is never delivered.
local POLL_INTERVAL = 0.1

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "MODIFIER_STATE_CHANGED" then
		local key, state = ...
		HandleModifierStateChanged(key, state)
	elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGIN" then
		-- Force non-Alt UI after reload/login; IsAltKeyDown can be stuck true.
		ignoreUntil = (GetTime and GetTime() or 0) + 1.25
		SetAltPressed(false, true)
		-- After grace, sync real keyboard state (user may still hold Alt).
		local delayFrame = AltMode._syncDelayFrame
		if not delayFrame then
			delayFrame = CreateFrame("Frame")
			AltMode._syncDelayFrame = delayFrame
			delayFrame:SetScript("OnUpdate", function(self, elapsed)
				self.t = (self.t or 0) + elapsed
				if self.t < (self.wait or 1.3) then
					return
				end
				self:Hide()
				self.t = 0
				ignoreUntil = 0
				SyncFromApi(true)
				-- If still "down" with no recent MODIFIER event, treat as stuck.
				local now = GetTime and GetTime() or 0
				if isAltPressed and (now - lastModifierEvent) > 2 then
					SetAltPressed(false, true)
				end
			end)
		end
		delayFrame.t = 0
		delayFrame.wait = 1.3
		delayFrame:Show()
	end
end)

local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function(self, elapsed)
	local acc = (self.acc or 0) + elapsed
	if acc < POLL_INTERVAL then
		self.acc = acc
		return
	end
	self.acc = 0
	SyncFromApi(false)
end)

function AltMode:Initialize()
	updateFrame:Show()
	ignoreUntil = (GetTime and GetTime() or 0) + 1.25
	SetAltPressed(false, true)
end

function AltMode:Shutdown()
	updateFrame:Hide()
	wipe(altCallbacks)
end

function AltMode:RegisterCallback(moduleName, callback)
	if type(callback) == "function" then
		altCallbacks[moduleName] = callback
		-- Sync new subscriber to current state immediately.
		callback(isAltPressed)
	end
end

function AltMode:UnregisterCallback(moduleName)
	altCallbacks[moduleName] = nil
end

function AltMode:IsAltPressed()
	return isAltPressed
end

function AltMode:RequestTooltipRefresh()
	tooltipRefreshRequested = true
	FlushTooltipRefresh()
end

function AltMode:ResetAltState()
	SetAltPressed(false, true)
end

SarychUI.AltMode = AltMode
