-- Player CastingBarFrame position for free panels (barMode = "frostatom").
-- XML fallback is BOTTOM/UIParent x=0 y=55, but UIParent_ManageFramePositions
-- uses menuBarTop (55, or 75 on widescreen) + yOffset 40. Sliders store extras
-- relative to that live default. Do not TOC-load CastingBarFrame.lua/xml.
local FA = SarychUI.FrostAtomBars
if not FA then return end

FA.PLAYER_CASTBAR_DEFAULT_X = 0
FA.PLAYER_CASTBAR_WIDTH = 195
FA.PLAYER_CASTBAR_HEIGHT = 13

-- 3.3.5 UIParent.lua: menuBarTop + CastingBarFrame.yOffset (40).
function FA.GetPlayerCastbarDefault()
	local menuBarTop = 55
	local w, h = GetScreenWidth(), GetScreenHeight()
	if w and h and h > 0 and (w / h) > (4 / 3) then
		menuBarTop = 75
	end
	return FA.PLAYER_CASTBAR_DEFAULT_X, menuBarTop + 40
end

FA.PLAYER_CASTBAR_DEFAULT_Y = select(2, FA.GetPlayerCastbarDefault())

FA.MOVER_BASE = FA.MOVER_BASE or {}
FA.MOVER_BASE.playerCastbar = {
	x = FA.PLAYER_CASTBAR_DEFAULT_X,
	y = function()
		local _, y = FA.GetPlayerCastbarDefault()
		return y
	end,
	point = "BOTTOM",
	relativePoint = "BOTTOM",
}

local holder
local hooked
local applying

local function EnsureConfig()
	local db = FA.DB()
	if not db then
		return nil
	end
	local t = db.playerCastbar
	if type(t) ~= "table" then
		t = {
			point = "BOTTOM",
			relativePoint = "BOTTOM",
			x = 0,
			y = 0,
		}
		db.playerCastbar = t
	end
	return t
end

local function EnsureHolder()
	if holder then
		return holder
	end
	holder = CreateFrame("Frame", "SarychUIPlayerCastbarAnchor", UIParent)
	holder:SetSize(FA.PLAYER_CASTBAR_WIDTH, FA.PLAYER_CASTBAR_HEIGHT)
	holder:SetFrameStrata("BACKGROUND")
	holder:SetFrameLevel(1)
	holder:EnableMouse(false)
	holder:Show()
	FA._playerCastbarHolder = holder
	return holder
end

local function AbsoluteOffsets()
	local t = EnsureConfig() or {}
	local dx, dy = FA.GetPlayerCastbarDefault()
	return (tonumber(t.x) or 0) + dx, (tonumber(t.y) or 0) + dy
end

local function DetachFromManager(bar)
	if UIPARENT_MANAGED_FRAME_POSITIONS then
		UIPARENT_MANAGED_FRAME_POSITIONS.CastingBarFrame = nil
	end
	if not bar then
		return
	end
	bar.ignoreFramePositionManager = true
	pcall(function()
		bar:SetMovable(true)
		bar:SetUserPlaced(true)
		if bar.SetDontSavePosition then
			bar:SetDontSavePosition(true)
		end
		bar:SetMovable(false)
	end)
end

function FA.ApplyPlayerCastbar()
	if applying or not FA.IsActive() then
		return
	end
	applying = true
	local h = EnsureHolder()
	local absX, absY = AbsoluteOffsets()
	h:ClearAllPoints()
	h:SetPoint("BOTTOM", UIParent, "BOTTOM", absX, absY)
	h:SetSize(FA.PLAYER_CASTBAR_WIDTH, FA.PLAYER_CASTBAR_HEIGHT)
	h:Show()

	local bar = _G.CastingBarFrame
	DetachFromManager(bar)
	if bar then
		bar._suiCastbarIgnore = true
		bar:ClearAllPoints()
		bar:SetPoint("BOTTOM", UIParent, "BOTTOM", absX, absY)
		bar._suiCastbarIgnore = false
	end
	applying = false
end

function FA.RestorePlayerCastbar()
	if holder then
		holder:Hide()
	end
	local bar = _G.CastingBarFrame
	if not bar then
		return
	end
	bar.ignoreFramePositionManager = nil
	local dx, dy = FA.GetPlayerCastbarDefault()
	bar._suiCastbarIgnore = true
	bar:ClearAllPoints()
	bar:SetPoint("BOTTOM", UIParent, "BOTTOM", dx, dy)
	bar._suiCastbarIgnore = false
end

local function HookBlizzard()
	if hooked then
		return
	end
	hooked = true
	if hooksecurefunc then
		hooksecurefunc("UIParent_ManageFramePositions", function()
			if FA.IsActive and FA.IsActive() then
				FA.ApplyPlayerCastbar()
			end
		end)
	end
	local bar = _G.CastingBarFrame
	if bar then
		hooksecurefunc(bar, "SetPoint", function(self)
			if self._suiCastbarIgnore then
				return
			end
			if FA.IsActive and FA.IsActive() then
				FA.ApplyPlayerCastbar()
			end
		end)
	end
end

function FA.InitializePlayerCastbar()
	EnsureConfig()
	EnsureHolder()
	HookBlizzard()
	FA.RegisterMover("playerCastbar", holder, FA.Label("playerCastbar"), {
		dragWidth = 220,
		dragHeight = 40,
		dragPoint = "CENTER",
	})
	FA.ApplyPlayerCastbar()
end
