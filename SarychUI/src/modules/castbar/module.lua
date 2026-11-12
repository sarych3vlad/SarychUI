-- SarychUI Castbar
-- Classic Blizzard bars or Dragonflight artwork; timers live on this module.

local moduleName = "castbar"
local module = {}
SarychUI:RegisterModule(moduleName, module)

local classicManagedY
local deferredPositionFrame

local function ManageCastbarPosition()
	if not UIParent_ManageFramePositions then return end
	if InCombatLockdown and InCombatLockdown() then
		if not deferredPositionFrame then
			deferredPositionFrame = CreateFrame("Frame")
			deferredPositionFrame:SetScript("OnEvent", function(self)
				self:UnregisterEvent("PLAYER_REGEN_ENABLED")
				ManageCastbarPosition()
			end)
		end
		deferredPositionFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	else
		UIParent_ManageFramePositions()
	end
end

function module:ApplyClassicCastbarOffset(reset)
	local positions = UIPARENT_MANAGED_FRAME_POSITIONS
	local managed = positions and positions.CastingBarFrame
	if not managed then return end
	if classicManagedY == nil then classicManagedY = managed.yOffset or 0 end
	local db = self:DB()
	local offset = not reset and self:IsEnabled() and self:GetBarStyle() == "classic"
		and (db and tonumber(db.classicCastbarOffsetY) or 0) or 0
	local y = classicManagedY + offset
	if managed.yOffset ~= y then
		managed.yOffset = y
		ManageCastbarPosition()
	end
end

function module:DB()
	return SarychUI.GetModuleProfile and SarychUI:GetModuleProfile(moduleName)
		or (SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName])
end

function module:IsEnabled()
	local db = self:DB()
	return db and db.enabled ~= false
end

function module:GetBarStyle()
	-- Style is locked for the session; swapping artwork safely needs /reload.
	if self._bootBarStyle then
		return self._bootBarStyle
	end
	local db = self:DB()
	return (db and db.barStyle) or "classic"
end

function module:IsDragonflight()
	return self:IsEnabled() and self:GetBarStyle() == "dragonflight"
end

function module:GetStyleFrame(unitType)
	if self:IsDragonflight() and self.DF and self.DF.GetFrame then
		return self.DF:GetFrame(unitType)
	end
	if unitType == "player" then
		return CastingBarFrame
	elseif unitType == "target" then
		return TargetFrameSpellBar
	elseif unitType == "focus" then
		return FocusFrameSpellBar
	end
	return nil
end

local function ApplyTimers()
	local tools = SarychUI and SarychUI.modules and SarychUI.modules
	if tools and SarychUI.modules.castbar.ApplyCastbarTimers then
		SarychUI.modules.castbar:ApplyCastbarTimers()
	end
end

function module:Enable()
	local db = self:DB()
	if not db or not db.enabled then
		return
	end
	self._bootBarStyle = self._bootBarStyle or (db.barStyle or "classic")
	if self._bootBarStyle == "dragonflight" and self.DF then
		self.DF:Enable()
	elseif self.DF then
		self.DF:Disable()
	end
	self:ApplyClassicCastbarOffset()
	self:ApplyChannelTicks()
	ApplyTimers()
end

function module:Disable()
	self:ApplyClassicCastbarOffset(true)
	if self.Ticks then
		self.Ticks:Disable()
	end
	if self.DF then
		self.DF:Disable()
	end
	local tools = SarychUI and SarychUI.modules and SarychUI.modules
	if tools and SarychUI.modules.castbar.DisableCastbarTimers then
		SarychUI.modules.castbar:DisableCastbarTimers()
	end
end

function module:ApplyChannelTicks()
	if not self.Ticks then
		return
	end
	local db = self:DB()
	local ticksOn = db and (db.enableCastbarTicks == nil or db.enableCastbarTicks == 1 or db.enableCastbarTicks == true)
	if self:IsEnabled() and ticksOn then
		self.Ticks:Enable()
	else
		self.Ticks:Disable()
	end
end

function module:ApplyScale()
	if self.DF and self.DF.ApplyScale then
		self.DF:ApplyScale()
	end
end

function module:ApplyDragonflightCastbarOffset()
	if self.DF and self.DF.ApplyPlayerOffset then
		self.DF:ApplyPlayerOffset()
	end
end

function module:ApplyPlayerIcon()
	if self.DF and self.DF.ApplyPlayerIcon then
		self.DF:ApplyPlayerIcon()
	end
end

function module:ApplyPlayerIconBorderAlpha()
	if self.DF and self.DF.ApplyPlayerIconBorderAlpha then
		self.DF:ApplyPlayerIconBorderAlpha()
	end
end

function module:ApplyPlayerIconCooldown()
	if self.DF and self.DF.ApplyPlayerIconCooldown then
		self.DF:ApplyPlayerIconCooldown()
	end
end

function module:ApplyPlayerTimerOffset()
	local tools = SarychUI and SarychUI.modules and SarychUI.modules
	if tools and SarychUI.modules.castbar.ApplyPlayerCastbarTimerOffset then
		SarychUI.modules.castbar:ApplyPlayerCastbarTimerOffset()
	end
end

function module:RefreshConfig()
	if self:IsEnabled() then
		self:Enable()
	else
		self:Disable()
	end
end
