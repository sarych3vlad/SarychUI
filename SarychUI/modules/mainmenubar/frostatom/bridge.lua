-- SarychUI glue for the FrostAtomUI action bars: enable/disable from the
-- mainmenubar module, refresh after option changes, DragMode movers.
local FA = SarychUI.FrostAtomBars
local InCombatLockdown = InCombatLockdown

local DRAG_PREFIX = "faBar_"
FA.DRAG_PREFIX = DRAG_PREFIX

function FA.ForEachStyledButton(fn)
	local ActionBar = FA.ActionBar
	if not ActionBar then
		return
	end
	-- Classic SarychUI text/color/combat effects target only the six action
	-- bars.  Pet and stance buttons keep their native Blizzard presentation.
	local buttons = ActionBar.actionButtons
	if buttons then
		for i = 1, #buttons do
			fn(buttons[i])
		end
	end
end

-- Text visibility applies to every Frost button which can display a binding,
-- including the reused Blizzard pet/stance buttons.  Keep this separate from
-- ForEachStyledButton: color and artwork settings intentionally target only
-- the regular action bars.
function FA.ForEachHotkeyButton(fn)
	local ActionBar = FA.ActionBar
	if not ActionBar then
		return
	end

	local function visit(buttons)
		if not buttons then return end
		for i = 1, #buttons do
			local button = buttons[i]
			if button and button.hotkey then
				fn(button)
			end
		end
	end

	visit(ActionBar.actionButtons)
	visit(ActionBar.petButtons)
	-- Stance hotkeys stay hidden (FrostAtomUI showShapeshiftHotkeys = false).
end

-- All movable things and their config keys (extra bars are added dynamically).
FA.MOVER_KEYS = {
	"bar1", "bar2", "bar3", "bar4", "bar5", "bar6",
	"bar7", "bar8", "bar9", "bar10",
	"stance", "pet", "totemBar", "vehicleExit", "experienceBar", "microMenu", "bagButton",
	"playerCastbar",
}

function FA.DragId(key)
	return DRAG_PREFIX .. key
end

-- Config table that stores point/x/y (+ drag flags) for a mover key.
function FA.MoverConfig(key)
	if key == "microMenu" or key == "bagButton" then
		local cfg = FA.config
		return cfg and cfg[key]
	end
	return FA.BarConfig(key)
end

local function dragPanel()
	return SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
end

local function MoverBaseOffset(base, key)
	if not base then
		return 0
	end
	local v = base[key]
	if type(v) == "function" then
		return tonumber(v()) or 0
	end
	return tonumber(v) or 0
end

--------------------------------------------------------------------
-- Movers (SarychUI DragMode)
--------------------------------------------------------------------
function FA.RegisterMover(key, frame, label, extra)
	local DragMode = SarychUI.DragMode
	if not DragMode or not frame then
		return
	end
	local frameId = FA.DragId(key)
	if DragMode:GetFrameData(frameId) then
		return
	end
	local settings = {
		dragText = label or key,
		getPoint = function()
			local t = FA.MoverConfig(key) or {}
			local base = FA.MOVER_BASE and FA.MOVER_BASE[key]
			local ox = MoverBaseOffset(base, "x")
			local oy = MoverBaseOffset(base, "y")
			local point = (base and base.point) or t.point or "CENTER"
			local relativePoint = (base and base.relativePoint) or t.relativePoint or point
			return { point, UIParent, relativePoint, (t.x or 0) + ox, (t.y or 0) + oy }
		end,
		onPositionChanged = function(point, relativePoint, xOfs, yOfs)
			local panel = dragPanel()
			if panel and panel.IsOpen and panel:IsOpen() and panel.OnDragPosition then
				if panel:OnDragPosition(frameId, xOfs, yOfs, point, relativePoint) then
					return
				end
			end
			local t = FA.MoverConfig(key)
			if not t then
				return
			end
			local base = FA.MOVER_BASE and FA.MOVER_BASE[key]
			local ox = MoverBaseOffset(base, "x")
			local oy = MoverBaseOffset(base, "y")
			if base and base.point then
				t.point = base.point
				t.relativePoint = base.relativePoint or base.point
			else
				t.point = point
				t.relativePoint = relativePoint
			end
			t.x = xOfs - ox
			t.y = yOfs - oy
			FA.Refresh(key)
		end,
	}
	if extra then
		for k, v in pairs(extra) do
			settings[k] = v
		end
	end
	DragMode:RegisterFrame(frameId, frame, settings)
	FA.UpdateDrag(key)
end

function FA.UnregisterMover(key)
	local DragMode = SarychUI.DragMode
	if not DragMode then
		return
	end
	local frameId = FA.DragId(key)
	local panel = dragPanel()
	if panel and panel.IsOpen and panel:IsOpen() and panel.GetFrameId and panel:GetFrameId() == frameId then
		panel:Close(false)
	end
	DragMode:UnregisterFrame(frameId)
end

-- Sync DragMode edit state with the stored drag flags of a mover.
function FA.UpdateDrag(key)
	local DragMode = SarychUI.DragMode
	if not DragMode then
		return
	end
	local frameId = FA.DragId(key)
	local data = DragMode:GetFrameData(frameId)
	if not data or not data.frame then
		return
	end
	local t = FA.MoverConfig(key)
	local showDrag = t ~= nil and t.showDragFrame == 1
	local base = FA.MOVER_BASE and FA.MOVER_BASE[key]
	local ox = MoverBaseOffset(base, "x")
	local oy = MoverBaseOffset(base, "y")
	local point = (base and base.point) or (t and t.point) or "CENTER"
	local relativePoint = (base and base.relativePoint) or (t and t.relativePoint) or point
	if showDrag then
		if InCombatLockdown() then
			return
		end
		DragMode:EnableEditMode(frameId, true, true, t.showGrid == 1)
		DragMode:SetFramePosition(frameId, point, relativePoint, (t.x or 0) + ox, (t.y or 0) + oy)
		return
	end
	-- Leaving edit mode: DragMode restores the position captured at
	-- registration, so re-apply the configured one afterwards.
	local inEdit = data.originalSetPoint ~= nil or (data.frame.IsMovable and data.frame:IsMovable())
	if inEdit and not InCombatLockdown() then
		DragMode:EnableEditMode(frameId, false, false, false)
		if key == "playerCastbar" then
			FA.ApplyPlayerCastbar()
		elseif t then
			FA.ApplyPoint(data.frame, t)
		end
	end
end

function FA.CloseDrag(key)
	local t = FA.MoverConfig(key)
	if t then
		t.showDragFrame = 0
		t.showGrid = 0
	end
	local panel = dragPanel()
	local frameId = FA.DragId(key)
	if panel and panel.IsOpen and panel:IsOpen() and panel.GetFrameId and panel:GetFrameId() == frameId then
		panel:Close(false)
	elseif SarychUI.DragMode then
		SarychUI.DragMode:EnableEditMode(frameId, false, false, false)
	end
end

function FA.ToggleDrag(key)
	local t = FA.MoverConfig(key)
	if not t then
		return
	end
	local val = not (t.showDragFrame == 1)
	t.showDragFrame = val and 1 or 0
	t.showGrid = val and 1 or 0
	local panel = dragPanel()
	if panel and panel.Toggle then
		panel:Toggle(FA.DragId(key), val)
	else
		FA.UpdateDrag(key)
	end
end

--------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------
local initialized = false
local hidden = false

local function restoreVisibility()
	local ActionBar = FA.ActionBar
	if not ActionBar then
		return
	end
	ActionBar:UnregisterEvent("PLAYER_REGEN_ENABLED", "HideAll")
	if ActionBar.ApplyStanceVisibility then
		ActionBar:ApplyStanceVisibility()
	end
	if ActionBar.ApplyPetVisibility then
		ActionBar:ApplyPetVisibility()
	end
	if ActionBar.ApplyVehicleExitVisibility then
		ActionBar:ApplyVehicleExitVisibility()
	end
	if FA.ExperienceBar then
		FA.ExperienceBar:SetSuspended(false)
	end
end

-- Refresh layout. key: bar key, "menus", "buttons" (style only) or nil (= everything).
function FA.Refresh(key)
	if not initialized then
		return
	end
	local ActionBar = FA.ActionBar
	if key == "menus" then
		FA.Blizzard:LayoutMenus()
		FA.UpdateDrag("microMenu")
		FA.UpdateDrag("bagButton")
		return
	end
	if key == "microMenuScale" then
		FA.Blizzard:ApplyMicroMenuScale(true)
		FA.UpdateDrag("microMenu")
		return
	end
	if key == "buttons" then
		ActionBar:StyleButtons()
		ActionBar:UpdateGrid()
		return
	end
	if key == "experienceBar" then
		FA.ExperienceBar:ApplyConfig()
		FA.UpdateDrag(key)
		return
	end
	if key == "playerCastbar" then
		if FA.ApplyPlayerCastbar then
			FA.ApplyPlayerCastbar()
		end
		FA.UpdateDrag(key)
		return
	end
	if key == "extraBars" then
		ActionBar:UpdateExtraBars()
		for page = ActionBar.FIRST_EXTRA_PAGE, ActionBar.LAST_EXTRA_PAGE do
			FA.UpdateDrag("bar" .. page)
		end
		return
	end
	if key == "microMenu" or key == "bagButton" then
		FA.Blizzard:LayoutMenus()
		FA.UpdateDrag(key)
		return
	end
	if key then
		ActionBar:Layout(key)
		FA.UpdateDrag(key)
		return
	end
	ActionBar:Layout()
	FA.ExperienceBar:ApplyConfig()
	FA.Blizzard:LayoutMenus()
	if FA.ApplyPlayerCastbar then
		FA.ApplyPlayerCastbar()
	end
	for _, k in ipairs(FA.MOVER_KEYS) do
		FA.UpdateDrag(k)
	end
end

function FA.Enable()
	if not FA.IsActive() then
		return
	end
	if InCombatLockdown() then
		-- Secure frames: wait for combat end.
		if not FA._pendingEnable then
			FA._pendingEnable = CreateFrame("Frame")
			FA._pendingEnable:RegisterEvent("PLAYER_REGEN_ENABLED")
			FA._pendingEnable:SetScript("OnEvent", function(self)
				self:UnregisterAllEvents()
				FA._pendingEnable = nil
				FA.Enable()
			end)
		end
		return
	end
	if not initialized then
		initialized = true
		-- Drag chrome never survives a reload.
		for _, k in ipairs(FA.MOVER_KEYS) do
			local t = FA.MoverConfig(k)
			if t then
				t.showDragFrame = nil
				t.showGrid = nil
			end
		end
		FA.Blizzard:Initialize()
		FA.ActionBar:Initialize()
		FA.ExperienceBar:Initialize()
		if FA.InitializePlayerCastbar then
			FA.InitializePlayerCastbar()
		end
	elseif hidden then
		hidden = false
		restoreVisibility()
	end
	FA.Refresh()
end

-- Module switched off at runtime: hide our bars. Blizzard bars come back
-- only after /reload (the options show a reload popup).
function FA.Disable()
	if not initialized or hidden then
		return
	end
	hidden = true
	for _, k in ipairs(FA.MOVER_KEYS) do
		local frameId = FA.DragId(k)
		if SarychUI.DragMode and SarychUI.DragMode:GetFrameData(frameId) then
			SarychUI.DragMode:EnableEditMode(frameId, false, false, false)
		end
	end
	FA.ActionBar:HideAll()
	if FA.ExperienceBar then
		FA.ExperienceBar:SetSuspended(true)
	end
	if FA.RestorePlayerCastbar then
		FA.RestorePlayerCastbar()
	end
end

function FA.IsInitialized()
	return initialized
end
