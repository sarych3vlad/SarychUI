-- SarychUI Tools: Quest Tracker style (classic / Dragonflight)
-- Dragonflight = header + font size; optional DragonUI position (base + CONTAINER_OFFSET
-- + user X/Y), with SarychUI DragMode / PositionDragPanel free-move.

local CreateFrame = CreateFrame
local GetTime = GetTime
local ipairs, tonumber = ipairs, tonumber
local pcall = pcall
local IsAddOnLoaded = IsAddOnLoaded
local hooksecurefunc = hooksecurefunc

local HEADER_TEXTURE = [[Interface\AddOns\SarychUI\media\textures\questtracker\QuestTracker.BLP]]
local HEADER_TEX_W, HEADER_TEX_H = 1024, 512
local HEADER_LEFT, HEADER_RIGHT, HEADER_TOP, HEADER_BOTTOM = 11, 571, 247, 317

-- DragonUI base (TOPRIGHT of UIParent), before Blizzard side-bar offset.
local DF_BASE_X, DF_BASE_Y = 0, -260
-- Fixed height like DragonUI: do NOT stretch to CONTAINER_OFFSET_Y (pet/vehicle/
-- bottom bars change that and would jump the tracker when mounting).
local QUESTTRACKER_MAX_HEIGHT = 600
local FRAME_ID = "questTracker"

local QT = {
	initialized = false,
	applied = false,
	hooksInstalled = false,
	hooksInstallScheduled = false,
	positionApplying = false,
	dragRegistered = false,
	watchFrameSetPointHooked = false,
	watchFrameUpdateGuarded = false,
	anchor = nil,
}

local function DB()
	local modules = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return modules and modules.tools
end

local function IsToolsEnabled()
	local db = DB()
	return db and db.enabled == true
end

local function IsDragonflightStyle()
	if not IsToolsEnabled() then return false end
	local db = DB()
	return db and db.questTrackerStyle == "dragonflight"
end

local function IsDragonflightPositionEnabled()
	if not IsDragonflightStyle() then return false end
	local db = DB()
	return not db or db.questTrackerDragonflightPosition ~= false
end

local function ShowHeaderEnabled()
	local db = DB()
	return not db or db.questTrackerShowHeader ~= false
end

local function GetFontSize()
	local db = DB()
	return tonumber(db and db.questTrackerFontSize) or 11
end

local function GetBasePosition()
	local db = DB() or {}
	local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
	if panel and panel.IsOpen and panel:IsOpen()
		and panel.GetFrameId and panel:GetFrameId() == FRAME_ID
		and panel.GetDraft then
		local dx, dy = panel:GetDraft()
		if dx ~= nil and dy ~= nil then
			return dx, dy
		end
	end
	return tonumber(db.questTrackerX) or DF_BASE_X, tonumber(db.questTrackerY) or DF_BASE_Y
end

local function GetSideBarOffsetX()
	return tonumber(CONTAINER_OFFSET_X) or 0
end

-- Base (no bars) → on-screen TOPRIGHT offsets (X follows side bars only).
local function GetEffectivePosition()
	local baseX, baseY = GetBasePosition()
	return baseX - GetSideBarOffsetX(), baseY
end

local function ApplyQuestTrackerFonts()
	if not IsDragonflightStyle() then return end
	local targetSize = GetFontSize()
	local lineSets = { WATCHFRAME_QUESTLINES, WATCHFRAME_ACHIEVEMENTLINES }
	for _, lineSet in ipairs(lineSets) do
		if lineSet then
			for _, line in ipairs(lineSet) do
				if line then
					if line.text and line.text.GetFont then
						local fp, _, fl = line.text:GetFont()
						if fp then line.text:SetFont(fp, targetSize, fl) end
					end
					if line.dash and line.dash.GetFont then
						local fp, _, fl = line.dash:GetFont()
						if fp then line.dash:SetFont(fp, targetSize, fl) end
					end
				end
			end
		end
	end
end

local function SetQuestTrackerHeaderTexture(texture)
	if not texture or not texture.SetTexture then return false end
	texture:SetTexture(HEADER_TEXTURE)
	texture:SetTexCoord(
		HEADER_LEFT / HEADER_TEX_W,
		HEADER_RIGHT / HEADER_TEX_W,
		HEADER_TOP / HEADER_TEX_H,
		HEADER_BOTTOM / HEADER_TEX_H
	)
	texture:SetSize(HEADER_RIGHT - HEADER_LEFT, HEADER_BOTTOM - HEADER_TOP)
	return true
end

-- Frames cannot be destroyed in this client, so finished timers are pooled and
-- reused instead of leaking a new frame (plus a closure) per scheduled callback.
local timerPool = {}

local function TimerFrameOnUpdate(self, delta)
	self.elapsed = self.elapsed + delta
	if self.elapsed < self.delay then return end

	local func = self.func
	self.func = nil
	self:Hide()
	self:SetScript("OnUpdate", nil)
	timerPool[#timerPool + 1] = self

	if func then func() end
end

local function ScheduleTimer(delay, func)
	local timerFrame = timerPool[#timerPool]
	if timerFrame then
		timerPool[#timerPool] = nil
	else
		timerFrame = CreateFrame("Frame")
	end

	timerFrame.elapsed = 0
	timerFrame.delay = delay
	timerFrame.func = func
	timerFrame:SetScript("OnUpdate", TimerFrameOnUpdate)
	timerFrame:Show()
end

local function GetTrackedQuestsCount()
	local count = 0
	local success, numWatches = pcall(GetNumQuestWatches)
	if success and numWatches then
		for i = 1, numWatches do
			local questIndex = GetQuestIndexForWatch(i)
			if questIndex and IsQuestWatched(questIndex) then
				count = count + 1
			end
		end
	end
	return count
end

local function ReassertWatchFrameLines()
	if WatchFrameLines and WatchFrameHeader then
		WatchFrameLines:SetPoint("TOPLEFT", WatchFrameHeader, "BOTTOMLEFT", 0, -15)
	end
end

local function ApplyQuestTrackerStyling()
	if not IsDragonflightStyle() then return end
	local watchFrame = WatchFrame
	if not watchFrame or not watchFrame:IsShown() then return end
	if not WatchFrameCollapseExpandButton then return end

	local trackedQuestsCount = GetTrackedQuestsCount()
	watchFrame.background = watchFrame.background or watchFrame.suiQTBackground or watchFrame:CreateTexture(nil, "BACKGROUND")
	watchFrame.suiQTBackground = watchFrame.background
	local background = watchFrame.background
	if not SetQuestTrackerHeaderTexture(background) then
		return
	end

	local headerWidth = watchFrame:GetWidth() or 230
	local headerHeight = headerWidth / 8
	background:ClearAllPoints()
	background:SetPoint("RIGHT", WatchFrameCollapseExpandButton, "RIGHT", 0, 0)
	background:SetSize(headerWidth, headerHeight)
	background:SetAlpha(0.9)

	local questHelperLoaded = IsAddOnLoaded and IsAddOnLoaded("QuestHelper")
	if trackedQuestsCount > 0 and ShowHeaderEnabled() and not questHelperLoaded then
		background:Show()
	else
		background:Hide()
	end
end

local function EnsureAnchor()
	if QT.anchor then return QT.anchor end
	local frame = CreateFrame("Frame", "SarychUI_QuestTrackerAnchor", UIParent)
	frame:SetSize(230, 32)
	frame:SetFrameStrata("MEDIUM")
	frame:SetFrameLevel(50)
	frame:EnableMouse(false)
	frame:SetMovable(true)
	QT.anchor = frame
	return frame
end

local function SafeSetWatchFrameUserPlaced(placed)
	local watchFrame = WatchFrame
	if not watchFrame then return end
	-- 3.3.5: SetUserPlaced errors unless the frame is movable.
	pcall(function()
		if placed then
			if not watchFrame:IsMovable() then
				watchFrame:SetMovable(true)
			end
			-- The position is managed by SarychUI and must not leak into the
			-- character layout-cache between sessions.
			if watchFrame.SetDontSavePosition then
				watchFrame:SetDontSavePosition(true)
			end
			watchFrame:SetUserPlaced(true)
		else
			if watchFrame:IsMovable() then
				watchFrame:SetUserPlaced(false)
			end
			if watchFrame.SetDontSavePosition then
				watchFrame:SetDontSavePosition(false)
			end
		end
	end)
end

local function ReleaseWatchFrameToBlizzard()
	local watchFrame = WatchFrame
	if not watchFrame then return end
	SafeSetWatchFrameUserPlaced(false)
	if watchFrame:GetScale() ~= 1 then
		watchFrame:SetScale(1)
	end
	if UIParent_ManageFramePositions then
		pcall(UIParent_ManageFramePositions)
	end
end

local function IsQuestTrackerDragging()
	if not (SarychUI and SarychUI.DragMode and SarychUI.DragMode.GetFrameData) then
		return false
	end
	local data = SarychUI.DragMode:GetFrameData(FRAME_ID)
	return data and data.isMoving
end

-- WatchFrame's Blizzard OnSizeChanged handler immediately calls
-- WatchFrame_Update. Moving its anchor invalidates the dependent WatchFrame as
-- surely as clearing WatchFrame itself, so both changes must happen while that
-- handler is suspended. Later SetHeight calls it with valid coordinates.
local function PinWatchFrame(watchFrame, anchor, x, y)
	local onSizeChanged = watchFrame:GetScript("OnSizeChanged")
	if onSizeChanged then
		watchFrame:SetScript("OnSizeChanged", nil)
	end

	local success, message = pcall(function()
		anchor:Show()
		anchor:ClearAllPoints()
		anchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", x, y)

		watchFrame:ClearAllPoints()
		watchFrame:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, 0)
	end)

	if onSizeChanged then
		watchFrame:SetScript("OnSizeChanged", onSizeChanged)
	end
	if not success then
		error(message)
	end
end

-- Place anchor at effective TOPRIGHT; pin WatchFrame to it with fixed height.
-- SetUserPlaced(true) is required: UIParent_ManageFramePositions only queues
-- secure work, so a post-hook alone loses to Blizzard (pet bar / mount / vehicle).
local function ApplyDragonflightPosition(force)
	if QT.positionApplying then return end
	if not IsDragonflightPositionEnabled() then return end
	if not force and IsQuestTrackerDragging() then return end

	local watchFrame = WatchFrame
	if not watchFrame then return end

	local x, y = GetEffectivePosition()
	local anchor = EnsureAnchor()

	QT.positionApplying = true
	-- Establish a valid rectangle before SetUserPlaced can notify Blizzard's
	-- layout machinery about the frame.
	PinWatchFrame(watchFrame, anchor, x, y)
	SafeSetWatchFrameUserPlaced(true)
	watchFrame:SetHeight(QUESTTRACKER_MAX_HEIGHT)
	QT.positionApplying = false
end

-- Blizzard's WatchFrame_Update assumes GetTop() and GetBottom() are always
-- numbers.  Other layout work can still temporarily invalidate the rectangle,
-- so repair it before the original function reaches that subtraction.
local function InstallWatchFrameUpdateGuard()
	if QT.watchFrameUpdateGuarded or not WatchFrame_Update then return end
	QT.watchFrameUpdateGuarded = true

	local blizzardWatchFrameUpdate = WatchFrame_Update
	WatchFrame_Update = function(self)
		local watchFrame = self or WatchFrame
		if watchFrame and IsDragonflightPositionEnabled() then
			if watchFrame:GetTop() == nil or watchFrame:GetBottom() == nil then
				ApplyDragonflightPosition(true)
			end
			-- A transient layout update is safe to skip; the scheduled refresh
			-- will run after the anchor has a valid rectangle again.
			if watchFrame:GetTop() == nil or watchFrame:GetBottom() == nil then
				return
			end
		end
		return blizzardWatchFrameUpdate(self)
	end
end

InstallWatchFrameUpdateGuard()

local function SaveBasePosition(baseX, baseY)
	local db = DB()
	if not db then return end
	db.questTrackerX = baseX
	db.questTrackerY = baseY
	if SarychUI and SarychUI.SyncOpenOptionsValues then
		SarychUI:SyncOpenOptionsValues()
	end
end

local function RegisterQuestTrackerDrag()
	if QT.dragRegistered then return end
	if not (SarychUI and SarychUI.DragMode) then return end
	local anchor = EnsureAnchor()

	SarychUI.DragMode:RegisterFrame(FRAME_ID, anchor, {
		dragPoint = "TOPRIGHT",
		dragOffsetX = 0,
		dragOffsetY = 0,
		dragWidth = 230,
		dragHeight = 280,
		dragText = "Трекер заданий",
		interceptSetPoint = true,
		getPoint = function()
			local x, y = GetEffectivePosition()
			return { "TOPRIGHT", UIParent, "TOPRIGHT", x, y }
		end,
		onPositionChanged = function(point, relativePoint, xOfs, yOfs)
			-- DragMode reports effective on-screen offsets; store no-bars base.
			local barX = GetSideBarOffsetX()
			local baseX = (tonumber(xOfs) or 0) + barX
			local baseY = tonumber(yOfs) or 0

			local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
			if panel and panel.IsOpen and panel:IsOpen() and panel.OnDragPosition then
				if panel:OnDragPosition(FRAME_ID, baseX, baseY, point, relativePoint) then
					ApplyDragonflightPosition()
					return
				end
			end

			SaveBasePosition(baseX, baseY)
			ApplyDragonflightPosition()
		end,
	})
	QT.dragRegistered = true
end

local function ApplyQuestTrackerDragMode()
	if not (SarychUI and SarychUI.DragMode) then return end
	RegisterQuestTrackerDrag()

	local db = DB() or {}
	local posOn = IsDragonflightPositionEnabled()
	local showDrag = posOn and (db.questTrackerShowDragFrame == 1)
	local showGrid = posOn and (db.questTrackerShowGrid == 1)

	if posOn then
		SarychUI.DragMode:EnableEditMode(FRAME_ID, true, showDrag, showGrid)
		SarychUI.DragMode:ShowGrid(showGrid)
		-- Re-apply after EnableEditMode (may restore defaultPosition briefly).
		ApplyDragonflightPosition()
	else
		SarychUI.DragMode:EnableEditMode(FRAME_ID, false, false, false)
		SarychUI.DragMode:ShowGrid(false)
		if QT.anchor then
			QT.anchor:Hide()
		end
	end
end

local function SyncWatchFrameLayout()
	if not IsDragonflightStyle() then return end
	if IsDragonflightPositionEnabled() then
		if UIParent_ManageFramePositions then
			pcall(UIParent_ManageFramePositions)
		end
		ApplyDragonflightPosition()
		ApplyQuestTrackerDragMode()
	else
		local db = DB()
		if db then
			db.questTrackerShowDragFrame = 0
			db.questTrackerShowGrid = 0
		end
		local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
		if panel and panel.IsOpen and panel:IsOpen() and panel.GetFrameId and panel:GetFrameId() == FRAME_ID then
			panel:Close(false)
		end
		ApplyQuestTrackerDragMode()
		ReleaseWatchFrameToBlizzard()
	end
end

local updateInProgress = false
local lastUpdateTime = 0

local function ForceUpdateQuestTracker()
	if not IsDragonflightStyle() then return end
	if updateInProgress then return end

	local now = GetTime()
	if now - lastUpdateTime < 0.05 then return end
	lastUpdateTime = now
	updateInProgress = true

	if WatchFrame_Update then
		pcall(WatchFrame_Update, WatchFrame)
	end
	if WatchFrame and IsDragonflightPositionEnabled() then
		WatchFrame:SetHeight(QUESTTRACKER_MAX_HEIGHT)
	end
	ReassertWatchFrameLines()
	ApplyQuestTrackerFonts()
	if not QT.hooksInstalled then
		pcall(ApplyQuestTrackerStyling)
	end

	updateInProgress = false
end

local function InstallQuestTrackerHooks()
	if QT.hooksInstalled then return end
	if not WatchFrame then return end

	if WatchFrame_Collapse then
		hooksecurefunc("WatchFrame_Collapse", function(self)
			if not IsDragonflightStyle() then return end
			if self then
				self:SetWidth(WATCHFRAME_EXPANDEDWIDTH or 204)
			end
		end)
	end

	local watchFrameHookActive = false
	if WatchFrame_Update then
		hooksecurefunc("WatchFrame_Update", function()
			if not IsDragonflightStyle() then return end
			if watchFrameHookActive then return end
			if not QT.applied then return end
			if not WatchFrame or not WatchFrameLines then return end

			if IsDragonflightPositionEnabled() then
				WatchFrame:SetHeight(QUESTTRACKER_MAX_HEIGHT)
			end
			ReassertWatchFrameLines()

			watchFrameHookActive = true
			ApplyQuestTrackerFonts()
			pcall(ApplyQuestTrackerStyling)
			watchFrameHookActive = false
		end)
	end

	local function ScheduleRefresh()
		if not IsDragonflightStyle() then return end
		ScheduleTimer(0.05, ForceUpdateQuestTracker)
	end

	hooksecurefunc("AddQuestWatch", ScheduleRefresh)
	hooksecurefunc("RemoveQuestWatch", ScheduleRefresh)
	if AddTrackedAchievement then
		hooksecurefunc("AddTrackedAchievement", ScheduleRefresh)
	end
	if RemoveTrackedAchievement then
		hooksecurefunc("RemoveTrackedAchievement", ScheduleRefresh)
	end
	if AbandonQuest then
		hooksecurefunc("AbandonQuest", ScheduleRefresh)
	end
	if QuestLog_Update then
		hooksecurefunc("QuestLog_Update", ScheduleRefresh)
	end

	hooksecurefunc("SetCVar", function(name)
		if name ~= "watchFrameWidth" then return end
		if not IsDragonflightStyle() then return end
		ScheduleTimer(0.2, function()
			SyncWatchFrameLayout()
			ForceUpdateQuestTracker()
		end)
	end)

	if UIParent_ManageFramePositions then
		hooksecurefunc("UIParent_ManageFramePositions", function()
			if not IsDragonflightPositionEnabled() then return end
			if not QT.applied then return end
			-- Immediate + next-frame: secure FramePositionDelegate may run after this hook.
			ApplyDragonflightPosition()
			ScheduleTimer(0, ApplyDragonflightPosition)
			ScheduleTimer(0.05, ApplyDragonflightPosition)
		end)
	end

	-- If Blizzard still touches WatchFrame.SetPoint, snap back (UserPlaced should
	-- normally prevent ManageFramePositions from doing this).
	if WatchFrame and not QT.watchFrameSetPointHooked then
		QT.watchFrameSetPointHooked = true
		hooksecurefunc(WatchFrame, "SetPoint", function(_, _, relativeTo)
			if QT.positionApplying then return end
			if not IsDragonflightPositionEnabled() then return end
			if not QT.applied then return end
			if IsQuestTrackerDragging() then return end
			-- Ignore our own pin to the DF anchor.
			if QT.anchor and relativeTo == QT.anchor then return end
			ScheduleTimer(0, ApplyDragonflightPosition)
		end)
	end

	QT.hooksInstalled = true
end

local function RestoreClassicWatchFrame()
	if not QT.applied then
		return
	end
	local db = DB()
	if db then
		db.questTrackerShowDragFrame = 0
		db.questTrackerShowGrid = 0
	end
	local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
	if panel and panel.IsOpen and panel:IsOpen() and panel.GetFrameId and panel:GetFrameId() == FRAME_ID then
		panel:Close(false)
	end
	if SarychUI and SarychUI.DragMode and QT.dragRegistered then
		SarychUI.DragMode:EnableEditMode(FRAME_ID, false, false, false)
	end
	if QT.anchor then
		QT.anchor:Hide()
	end
	if WatchFrame then
		if WatchFrame.background then
			WatchFrame.background:Hide()
		end
		if WatchFrame.suiQTBackground and WatchFrame.suiQTBackground ~= WatchFrame.background then
			WatchFrame.suiQTBackground:Hide()
		end
	end
	ReleaseWatchFrameToBlizzard()
	QT.applied = false
end

local function ApplyDragonflight()
	QT.initialized = true
	QT.applied = true
	SyncWatchFrameLayout()
	ApplyQuestTrackerFonts()
	ForceUpdateQuestTracker()
	ScheduleTimer(0.05, ForceUpdateQuestTracker)

	if not QT.hooksInstalled and not QT.hooksInstallScheduled then
		QT.hooksInstallScheduled = true
		ScheduleTimer(1.0, function()
			QT.hooksInstallScheduled = false
			if not IsDragonflightStyle() then return end
			InstallQuestTrackerHooks()
			SyncWatchFrameLayout()
			ForceUpdateQuestTracker()
		end)
	elseif QT.hooksInstalled then
		ForceUpdateQuestTracker()
	end
end

local function OnPlayerEnteringWorld()
	if not IsDragonflightStyle() then return end
	QT.applied = true
	ApplyQuestTrackerFonts()
	ScheduleTimer(0.1, ApplyQuestTrackerFonts)
	ScheduleTimer(0.3, ApplyQuestTrackerFonts)
	ScheduleTimer(0.6, ApplyQuestTrackerFonts)
	ScheduleTimer(0.3, function()
		if IsDragonflightStyle() then
			SyncWatchFrameLayout()
			ForceUpdateQuestTracker()
		end
	end)

	if not QT.hooksInstalled and not QT.hooksInstallScheduled then
		QT.hooksInstallScheduled = true
		ScheduleTimer(1.0, function()
			QT.hooksInstallScheduled = false
			if not IsDragonflightStyle() then return end
			InstallQuestTrackerHooks()
			SyncWatchFrameLayout()
			ForceUpdateQuestTracker()
		end)
	end
end

local lastQuestUpdate, previousQuestCount = 0, 0
local function OnQuestLogUpdate()
	if not IsDragonflightStyle() then return end
	local now = GetTime()
	if now - lastQuestUpdate < 0.05 then return end
	lastQuestUpdate = now
	local currentQuestCount = GetTrackedQuestsCount()
	if currentQuestCount ~= previousQuestCount then
		previousQuestCount = currentQuestCount
		ScheduleTimer(0.05, ForceUpdateQuestTracker)
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_ENTERING_WORLD" then
		OnPlayerEnteringWorld()
	elseif event == "QUEST_LOG_UPDATE" then
		OnQuestLogUpdate()
	end
end)

local function ApplyQuestTrackerStyle()
	if IsDragonflightStyle() then
		ApplyDragonflight()
	elseif QT.applied then
		RestoreClassicWatchFrame()
	end
end

local function RefreshQuestTracker()
	if not IsDragonflightStyle() then
		if QT.applied then
			RestoreClassicWatchFrame()
		end
		return
	end
	QT.applied = true
	SyncWatchFrameLayout()
	ForceUpdateQuestTracker()
	ScheduleTimer(0.05, ForceUpdateQuestTracker)
end

local function AttachToToolsModule()
	local module = SarychUI and (SarychUI:GetModule("tools", true) or (SarychUI.modules and SarychUI.modules.tools))
	if not module then return end
	module.ApplyQuestTrackerStyle = ApplyQuestTrackerStyle
	module.RefreshQuestTracker = RefreshQuestTracker
	module.RestoreQuestTrackerClassic = RestoreClassicWatchFrame
	module.ApplyQuestTrackerDragMode = ApplyQuestTrackerDragMode
end

AttachToToolsModule()

_G.SarychUI_QuestTracker = {
	Apply = ApplyQuestTrackerStyle,
	Refresh = RefreshQuestTracker,
	RestoreClassic = RestoreClassicWatchFrame,
	ApplyDragMode = ApplyQuestTrackerDragMode,
	IsDragonflight = IsDragonflightStyle,
	GetEffectivePosition = GetEffectivePosition,
	GetBasePosition = GetBasePosition,
	DF_BASE_X = DF_BASE_X,
	DF_BASE_Y = DF_BASE_Y,
}
