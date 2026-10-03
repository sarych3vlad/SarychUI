-- SarychUI Tools - double-tap / key-echo (RougeUI XYZ.lua KeyEcho).
-- Re-fires action-bar keybinds on key down and up so fast repeats work like AHK.

local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local wipe = wipe
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local GetBinding = GetBinding
local GetBindingKey = GetBindingKey
local GetBindingAction = GetBindingAction
local GetNumBindings = GetNumBindings
local ClearOverrideBindings = ClearOverrideBindings
local RegisterStateDriver = RegisterStateDriver
local UnregisterStateDriver = UnregisterStateDriver

local moduleName = "tools"
local module = SarychUI and SarychUI.modules and SarychUI.modules[moduleName]
if not module then return end

local wahkButtons = {}
local boundKeys = {}
local pendingUpdate
local binderFrame
local timerFrame
local updateTimer = 0
local eventsHooked = false

local SECURE_APPLY_BINDINGS = [[
	local state = self:GetAttribute("wahk_override_state") or "normal"
	local count = self:GetAttribute("wahk_count") or 0

	self:ClearBindings()

	for i = 1, count do
		local key = self:GetAttribute("wahk_key" .. i)
		local normal = self:GetAttribute("wahk_normal" .. i)
		local vehicle = self:GetAttribute("wahk_vehicle" .. i)
		local bonus = self:GetAttribute("wahk_bonus" .. i)

		if vehicle == "" then vehicle = nil end
		if bonus == "" then bonus = nil end

		local target = normal

		if state == "vehicle" and vehicle then
			target = vehicle
		elseif state == "bonus" and bonus then
			target = bonus
		end

		if key and target then
			self:SetBindingClick(true, key, target, "LeftButton")
		end
	end
]]

local SECURE_ONSTATE_OVERRIDEBUTTON = [[
	self:SetAttribute("wahk_override_state", newstate)
]] .. SECURE_APPLY_BINDINGS

local defaultButtons = {
	ACTIONBUTTON = "ActionButton",
	MULTIACTIONBAR1BUTTON = "MultiBarBottomLeftButton",
	MULTIACTIONBAR2BUTTON = "MultiBarBottomRightButton",
	MULTIACTIONBAR3BUTTON = "MultiBarRightButton",
	MULTIACTIONBAR4BUTTON = "MultiBarLeftButton",
}

local function DB()
	local root = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return root and root[moduleName]
end

local function KeyEchoOn()
	local db = DB()
	if not db or db.enabled ~= true then return false end
	return db.enableKeyEcho == 1 or db.enableKeyEcho == true
end

local function BindingAction(key)
	if not key or key == "" then return nil end
	local action = GetBindingAction(key, true)
	if not action or action == "" then
		action = GetBindingAction(key)
	end
	return action
end

local function BuildAllBindings()
	local result = {}
	local seenKeys = {}

	local function ScanKey(key)
		if key and key ~= "" then seenKeys[key] = true end
	end

	local function ScanCommand(command)
		local key1, key2 = GetBindingKey(command)
		ScanKey(key1)
		ScanKey(key2)
	end

	for i = 1, GetNumBindings() do
		local _, key1, key2 = GetBinding(i)
		ScanKey(key1)
		ScanKey(key2)
	end

	for i = 1, 120 do
		ScanCommand("CLICK BT4Button" .. i .. ":LeftButton")
		ScanCommand("CLICK DominosActionButton" .. i .. ":HOTKEY")
		ScanCommand("CLICK DominosActionButton" .. i .. ":LeftButton")
	end

	for key in pairs(seenKeys) do
		local action = BindingAction(key)
		if action and action ~= "" then
			local btnName
			if action:match("^CLICK ") then
				btnName = action:match("^CLICK ([^:]+)")
			else
				local base, id = action:match("^(.-)(%d+)$")
				if base and id then
					local blizzBtn = defaultButtons[base:upper()]
					if blizzBtn then
						btnName = blizzBtn .. id
					end
				end
			end
			if btnName then
				result[btnName] = result[btnName] or {}
				result[btnName][#result[btnName] + 1] = key
			end
		end
	end

	return result
end

local function addWAHK(buttonName, btn)
	local wahkBtn = wahkButtons[buttonName]
	if wahkBtn then return wahkBtn end

	wahkBtn = CreateFrame("Button", "SarychUIKE_" .. buttonName, nil, "SecureActionButtonTemplate")
	wahkBtn:RegisterForClicks("AnyUp", "AnyDown")
	wahkBtn:SetAttribute("type", "click")
	wahkBtn:SetAttribute("clickbutton", btn)

	wahkBtn:SetScript("OnMouseDown", function()
		if btn:IsVisible() then
			btn:SetButtonState("PUSHED")
		end
	end)
	wahkBtn:SetScript("OnMouseUp", function()
		if btn:IsVisible() then
			btn:SetButtonState("NORMAL")
		end
	end)
	wahkBtn:SetScript("PostClick", function()
		if btn:IsVisible() then
			btn:SetButtonState("NORMAL")
		end
	end)

	wahkButtons[buttonName] = wahkBtn
	return wahkBtn
end

local function EnsureBinder()
	if binderFrame then return binderFrame end
	local ok, frame = pcall(CreateFrame, "Frame", "SarychUIKeyEchoBinder", nil, "SecureHandlerStateTemplate")
	if not ok or not frame then
		return nil
	end
	binderFrame = frame
	return binderFrame
end

local function ClearBinds()
	local frame = EnsureBinder()
	if not frame then return end
	if InCombatLockdown() then
		frame:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end
	ClearOverrideBindings(frame)
	UnregisterStateDriver(frame, "overridebutton")
	frame:SetAttribute("_onstate-overridebutton", nil)
	frame:SetAttribute("wahk_override_state", "normal")
	frame:SetAttribute("wahk_count", 0)
end

local function updateBinds()
	if not KeyEchoOn() then
		ClearBinds()
		return
	end
	if InCombatLockdown() then
		local frame = EnsureBinder()
		if frame then
			frame:RegisterEvent("PLAYER_REGEN_ENABLED")
		end
		return
	end

	local frame = EnsureBinder()
	if not frame then return end

	ClearOverrideBindings(frame)
	UnregisterStateDriver(frame, "overridebutton")
	frame:SetAttribute("_onstate-overridebutton", nil)
	frame:SetAttribute("wahk_override_state", "normal")
	frame:SetAttribute("wahk_count", 0)
	wipe(boundKeys)

	local binds = BuildAllBindings()
	local bindingIndex = 0

	for btnName, keys in pairs(binds) do
		local btn = _G[btnName]
		if btn and keys and #keys > 0 then
			local normalWahk = addWAHK(btnName, btn)
			local vehicleWahkName = ""
			local bonusWahkName = ""
			local actionBtnNum = tonumber(btnName:match("^ActionButton(%d+)$"))
			if actionBtnNum then
				local vehicleBtn = _G["VehicleMenuBarActionButton" .. actionBtnNum]
				if vehicleBtn then
					vehicleWahkName = addWAHK(btnName .. "_vehicle", vehicleBtn):GetName()
				end
				local bonusBtn = _G["BonusActionButton" .. actionBtnNum]
				if bonusBtn then
					bonusWahkName = addWAHK(btnName .. "_bonus", bonusBtn):GetName()
				end
			end
			for _, key in ipairs(keys) do
				if not boundKeys[key] then
					bindingIndex = bindingIndex + 1
					frame:SetAttribute("wahk_key" .. bindingIndex, key)
					frame:SetAttribute("wahk_normal" .. bindingIndex, normalWahk:GetName())
					frame:SetAttribute("wahk_vehicle" .. bindingIndex, vehicleWahkName)
					frame:SetAttribute("wahk_bonus" .. bindingIndex, bonusWahkName)
					boundKeys[key] = true
				end
			end
		end
	end

	frame:SetAttribute("wahk_count", bindingIndex)
	if bindingIndex > 0 then
		frame:SetAttribute("_onstate-overridebutton", SECURE_ONSTATE_OVERRIDEBUTTON)
		RegisterStateDriver(frame, "overridebutton", "[vehicleui] vehicle; [bonusbar:1/2/3/4/5] bonus; normal")
		if frame.Execute then
			frame:Execute(SECURE_APPLY_BINDINGS)
		end
	end
end

local function scheduledUpdate()
	if pendingUpdate then return end
	pendingUpdate = true
	updateTimer = 0.5
	if not timerFrame then
		timerFrame = CreateFrame("Frame")
	end
	timerFrame:SetScript("OnUpdate", function(self, elapsed)
		updateTimer = updateTimer - elapsed
		if updateTimer <= 0 then
			self:SetScript("OnUpdate", nil)
			pendingUpdate = nil
			updateBinds()
		end
	end)
end

local function EnsureEvents()
	local frame = EnsureBinder()
	if not frame or eventsHooked then return end
	eventsHooked = true
	frame:SetScript("OnEvent", function(self, event)
		if event == "PLAYER_REGEN_ENABLED" then
			self:UnregisterEvent("PLAYER_REGEN_ENABLED")
			scheduledUpdate()
			return
		end
		if KeyEchoOn() then
			scheduledUpdate()
		end
	end)
end

function module:EnableKeyEcho()
	EnsureEvents()
	local frame = EnsureBinder()
	if frame then
		frame:RegisterEvent("UPDATE_BINDINGS")
	end
	scheduledUpdate()
end

function module:DisableKeyEcho()
	local frame = EnsureBinder()
	if frame then
		frame:UnregisterEvent("UPDATE_BINDINGS")
	end
	ClearBinds()
end

function module:ApplyKeyEcho()
	if KeyEchoOn() then
		self:EnableKeyEcho()
	else
		self:DisableKeyEcho()
	end
end
