local _, Private = ...

local _G = _G
local Max = math.max
local Assert = assert
local GetTime = GetTime
local CreateFrame = CreateFrame
local GetMetaTable = getmetatable

local FrameRef = CreateFrame("Frame")
local ButtonRef = CreateFrame("Button")
local SliderRef = CreateFrame("Slider")
local CooldownRef = CreateFrame("Cooldown")
local StatusBarRef = CreateFrame("StatusBar")
local ScrollFrameRef = CreateFrame("ScrollFrame")
local CheckButtonRef = CreateFrame("CheckButton")
local PlayerModelRef = CreateFrame("PlayerModel")
local AnimationGroupRef = FrameRef:CreateAnimationGroup()

local Frame = GetMetaTable(FrameRef).__index
local Button = GetMetaTable(ButtonRef).__index
local Slider = GetMetaTable(SliderRef).__index
local Cooldown = GetMetaTable(CooldownRef).__index
local StatusBar = GetMetaTable(StatusBarRef).__index
local ScrollFrame = GetMetaTable(ScrollFrameRef).__index
local CheckButton = GetMetaTable(CheckButtonRef).__index
local PlayerModel = GetMetaTable(PlayerModelRef).__index
local FrameTexture = GetMetaTable(FrameRef:CreateTexture()).__index
local FrameFontString = GetMetaTable(FrameRef:CreateFontString()).__index
local AnimationAlpha = GetMetaTable(AnimationGroupRef:CreateAnimation("Alpha")).__index

local CONST_ATLAS_WIDTH			= 1
local CONST_ATLAS_HEIGHT		= 2
local CONST_ATLAS_LEFT			= 3
local CONST_ATLAS_RIGHT			= 4
local CONST_ATLAS_TOP			= 5
local CONST_ATLAS_BOTTOM		= 6
local CONST_ATLAS_TILESHORIZ	= 7
local CONST_ATLAS_TILESVERT		= 8
local CONST_ATLAS_TEXTUREPATH	= 9

local GRAY_FONT_COLOR = GRAY_FONT_COLOR
local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR

local function Hook_SetCooldown(Self, Start, Duration, Modrate)
	Self.___Start = Start > 0 and Start or nil
	Self.___Duration = Duration > 0 and Duration or nil
end

local function Method_GetCooldownTimes(Self)
	local Start = Self.___Start
	local Duration = Self.___Duration

	if ( Start and Duration and (GetTime() - (Start + Duration)) >= 0 ) then
		Start = nil
		Duration = nil
		Self.___Start = nil
		Self.___Duration = nil
	end

	return Start or 0, Duration or 0
end

local function Method_GetCooldownDuration(Self)
	local Duration = Self.___Duration

	if ( Duration ) then
		Duration = Duration - (GetTime() - Self.___Start)

		if ( Duration <= 0 ) then
			Duration = 0
			Self.___Start = nil
			Self.___Duration = nil
		end
	end

	return Duration or 0
end

local function Method_SetCooldownDuration(Self, Duration, Modrate)
	Self:SetCooldown(GetTime(), Duration, Modrate)
end

local function Method_SetSwipeColor(Self, R, G, B, A)
	if ( A ) then
		Self:SetAlpha(A)
	end
end

local function Method_SetShown(Self, Show)
	if ( Show ) then
		Self:Show()
	else
		Self:Hide()
	end
end

local function Method_SetEnabled(Self, Enabled)
	if ( Enabled ) then
		Self:Enable()
	else
		Self:Disable()
	end
end

local function Method_SetSubTexCoord(Self, Left, Right, Top, Bottom)
	local UL_X, UL_Y, LL_X, LL_Y, UR_X, UR_Y, LR_X, LR_Y = Self:GetTexCoord()

	local LeftEdge = UL_X
	local RightEdge = UR_X
	local TopEdge = UL_Y
	local BottomEdge = LL_Y

	local Width  = RightEdge - LeftEdge
	local Height = BottomEdge - TopEdge

	LeftEdge = UL_X + Width * Left
	TopEdge  = UL_Y  + Height * Top
	RightEdge = Max(RightEdge * Right, UL_X)
	BottomEdge = Max(BottomEdge * Bottom, UL_Y)

	UL_X = LeftEdge
	UL_Y = TopEdge
	LL_X = LeftEdge
	LL_Y = BottomEdge
	UR_X = RightEdge
	UR_Y = TopEdge
	LR_X = RightEdge
	LR_Y = BottomEdge

	Self:SetTexCoord(UL_X, UL_Y, LL_X, LL_Y, UR_X, UR_Y, LR_X, LR_Y)
end

local function Method_SetAtlas(Self, AtlasName, UseAtlasSize, FilterMode)
	Assert(Self, "SetAtlas: not found object")
	Assert(AtlasName, "SetAtlas: AtlasName must be specified")
	Assert(ATLAS_INFO_STORAGE[AtlasName], "SetAtlas: Atlas named "..AtlasName.." does not exist")

	local Atlas = ATLAS_INFO_STORAGE[AtlasName]

	Self:SetTexture(Atlas[CONST_ATLAS_TEXTUREPATH] or "", Atlas[CONST_ATLAS_TILESHORIZ], Atlas[CONST_ATLAS_TILESVERT])

	if ( UseAtlasSize ) then
		Self:SetWidth(Atlas[CONST_ATLAS_WIDTH])
		Self:SetHeight(Atlas[CONST_ATLAS_HEIGHT])
	end

	Self:SetTexCoord(Atlas[CONST_ATLAS_LEFT], Atlas[CONST_ATLAS_RIGHT], Atlas[CONST_ATLAS_TOP], Atlas[CONST_ATLAS_BOTTOM])

	Self:SetHorizTile(Atlas[CONST_ATLAS_TILESHORIZ])
	Self:SetVertTile(Atlas[CONST_ATLAS_TILESVERT])

	Self.___AtlasName = AtlasName
end

local function Method_GetAtlas(Self)
	return Self.___AtlasName
end

local function Method_SetDesaturated(Self, Toggle, Color)
	if ( Toggle ) then
		Self:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
	else
		if ( Color ) then
			Self:SetTextColor(Color.r, Color.g, Color.b)
		else
			Self:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
		end
	end
end

local function Method_ClearAndSetPoint(Self, ...)
	Self:ClearAllPoints()
	Self:SetPoint(...)
end

local function Method_CreateLine(Self, ...)
	-- Self is NineSlice
	local Line = Self:CreateTexture(...)
	Line.IsLine = true
	return Line
end

local function Method_IsForbidden(Self)
	return Self.___Forbidden
end

local function Method_SetForbidden(Self)
	Self.___Forbidden = true
end

local function Method_SetHideCountdownNumbers(Self, Hide)
	Self.noCooldownCount = (Hide) and true or nil -- OmniCC
end

local function Method_SetToAlpha(Self, normalizedAlpha)
	if ( Self.___FromAlpha ) then
		Self:SetChange(normalizedAlpha - Self.___FromAlpha)
		Self.___FromAlpha = nil
	else
		Self.___ToAlpha = normalizedAlpha
	end
end

local function Method_SetFromAlpha(Self, normalizedAlpha)
	if ( Self.___ToAlpha ) then
		self:SetChange(Self.___ToAlpha - normalizedAlpha)
		Self.___ToAlpha = nil
	else
		Self.___FromAlpha = normalizedAlpha
	end
end

-- FRAME
Frame.SetShown = Method_SetShown
Frame.ClearAndSetPoint = Method_ClearAndSetPoint
Frame.IsRectValid = Private.True
Frame.SetIgnoreParentScale = Private.Void
Frame.CreateMaskTexture = Private.Void
Frame.SetClipsChildren = Private.Void
Frame.SetPortraitZoom = Private.Void
Frame.SetForbidden = Method_SetForbidden
Frame.IsForbidden = Method_IsForbidden
	-- Line
		Frame.CreateLine = Method_CreateLine

	-- TEXTURE (FRAME)
		FrameTexture.SetShown = Method_SetShown
		FrameTexture.SetSubTexCoord = Method_SetSubTexCoord
		FrameTexture.SetAtlas = Method_SetAtlas
		FrameTexture.GetAtlas = Method_GetAtlas
		FrameTexture.ClearAndSetPoint = Method_ClearAndSetPoint
		FrameTexture.SetMask = Private.Void
		FrameTexture.GetNumMaskTextures = function(Self) return 0 end
		FrameTexture.SetSnapToPixelGrid = Private.Void
		FrameTexture.SetTexelSnappingBias = Private.Void
		FrameTexture.SetColorTexture = FrameTexture.SetTexture
			-- Line
				FrameTexture.SetThickness = Private.Void
				FrameTexture.SetStartPoint = Private.Void
				FrameTexture.SetEndPoint = Private.Void
				FrameTexture.SetIgnoreParentAlpha = Private.Void

	-- FONTSTRING (FRAME)
		FrameFontString.SetShown = Method_SetShown
		FrameFontString.SetDesaturated = Method_SetDesaturated
		FrameFontString.ClearAndSetPoint = Method_ClearAndSetPoint

-- BUTTON
Button.SetShown = Method_SetShown
Button.SetEnabled = Method_SetEnabled
Button.ClearAndSetPoint = Method_ClearAndSetPoint
Button.SetNormalAtlas = function(Self, ...) Method_SetAtlas(Self:GetNormalTexture(), ...)  end
Button.SetPushedAtlas = function(Self, ...) Method_SetAtlas(Self:GetPushedTexture(), ...)  end
Button.SetDisabledAtlas = function(Self, ...) Method_SetAtlas(Self:GetDisabledTexture(), ...)  end
Button.SetHighlightAtlas = function(Self, ...) Method_SetAtlas(Self:GetHighlightTexture(), ...)  end
Button.SetForbidden = Method_SetForbidden
Button.IsForbidden = Method_IsForbidden

-- SLIDER
Slider.SetShown = Method_SetShown
Slider.ClearAndSetPoint = Method_ClearAndSetPoint

-- STATUSBAR
StatusBar.SetShown = Method_SetShown
StatusBar.ClearAndSetPoint = Method_ClearAndSetPoint

-- SCROLLFRAME
ScrollFrame.SetShown = Method_SetShown
ScrollFrame.ClearAndSetPoint = Method_ClearAndSetPoint

-- CHECKBUTTON
CheckButton.SetShown = Method_SetShown
CheckButton.SetEnabled = Method_SetEnabled
CheckButton.ClearAndSetPoint = Method_ClearAndSetPoint

-- COOLDOWN
hooksecurefunc(Cooldown, "SetCooldown", Hook_SetCooldown) -- This will cause a tiny spike in CPU usage.
Cooldown.Clear = Cooldown.Hide
Cooldown.SetHideCountdownNumbers = Method_SetHideCountdownNumbers
Cooldown.SetDrawBling = Private.Void
Cooldown.SetDrawSwipe = Private.Void
Cooldown.IsPaused = Private.Void
Cooldown.Pause = Private.Void
Cooldown.Resume = Private.Void
Cooldown.SetSwipeTexture = Private.Void
Cooldown.SetSwipeColor = Method_SetSwipeColor
Cooldown.GetCooldownTimes = Method_GetCooldownTimes
Cooldown.GetCooldownDuration = Method_GetCooldownDuration
Cooldown.SetCooldownDuration = Method_SetCooldownDuration

-- PLAYERMODEL
PlayerModel.ClearTransform = Private.Void
PlayerModel.SetPortraitZoom = Private.Void -- TODO: Ref: zoom into parent (code: WA => calc)

-- ANIMATION
	-- ALPHA
	AnimationAlpha.SetFromAlpha = Method_SetFromAlpha
	AnimationAlpha.SetToAlpha = Method_SetToAlpha
