-- SarychUI Player Resources
-- Compact player plate, DK runes, shaman totems, warrior shield icon.
-- Adapted from FrostAtomUI (Player resources tab).

local moduleName = "player_resources"
local module = {}
SarychUI:RegisterModule(moduleName, module)

local _, PLAYER_CLASS = UnitClass("player")
module.PLAYER_CLASS = PLAYER_CLASS

local BAR_TEX = [[Interface\TargetingFrame\UI-StatusBar]]
local BLANK = [[Interface\Buttons\WHITE8X8]]

function module:DB()
	return SarychUI.GetModuleProfile and SarychUI:GetModuleProfile(moduleName)
		or (SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName])
end

function module:Sub(key)
	local db = self:DB()
	return db and db[key]
end

function module:Flag(sub, key, default)
	local t = self:Sub(sub)
	if not t or t[key] == nil then
		return default == true or default == 1
	end
	return t[key] == 1 or t[key] == true
end

function module:Num(sub, key, default)
	local t = self:Sub(sub)
	local v = t and t[key]
	if v == nil then
		return default
	end
	return tonumber(v) or default
end

function module:Color(sub, key, default)
	local t = self:Sub(sub)
	local c = t and t[key]
	if type(c) == "table" then
		return c[1] or 1, c[2] or 1, c[3] or 1, c[4]
	end
	if default then
		return default[1], default[2], default[3], default[4]
	end
	return 1, 1, 1
end

function module:ApplyPoint(frame, sub)
	local t = self:Sub(sub)
	if not frame or not t then
		return
	end
	frame:ClearAllPoints()
	frame:SetPoint(t.point or "CENTER", UIParent, t.relativePoint or "CENTER", t.x or 0, t.y or 0)
end

function module:RegisterDrag(frameId, frame, sub, label)
	if not SarychUI.DragMode or not frame then
		return
	end
	if SarychUI.DragMode.GetFrameData and SarychUI.DragMode:GetFrameData(frameId) then
		return
	end
	SarychUI.DragMode:RegisterFrame(frameId, frame, {
		dragText = label,
		interceptSetPoint = true,
		getPoint = function()
			local t = module:Sub(sub) or {}
			return { t.point or "CENTER", UIParent, t.relativePoint or "CENTER", t.x or 0, t.y or 0 }
		end,
		onPositionChanged = function(point, relativePoint, xOfs, yOfs)
			local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
			if panel and panel.IsOpen and panel:IsOpen() and panel.OnDragPosition then
				if panel:OnDragPosition(frameId, xOfs, yOfs, point, relativePoint) then
					return
				end
			end
			local t = module:Sub(sub)
			if not t then
				return
			end
			t.point = point
			t.relativePoint = relativePoint
			t.x = xOfs
			t.y = yOfs
			module:ApplyPoint(frame, sub)
		end,
	})
end

function module:UpdateDrag(frameId, sub)
	if not SarychUI.DragMode then
		return
	end
	local t = self:Sub(sub)
	if not t then
		return
	end
	-- Панель игрока всегда активна вместе с модулем; остальные — по своему enabled.
	local featureOn = (sub == "plate") or (t.enabled == 1)
	-- Панель / щит / руны / тотемы: расположение всегда доступно без отдельного «Включить».
	local posOn = featureOn and (sub == "plate" or sub == "shield" or sub == "runes" or sub == "totems" or t.positioningEnabled == 1)
	local showDrag = t.showDragFrame == 1
	local showGrid = t.showGrid == 1
	SarychUI.DragMode:EnableEditMode(frameId, posOn or showDrag, showDrag, showGrid)
	if posOn or showDrag then
		SarychUI.DragMode:SetFramePosition(
			frameId,
			t.point or "CENTER",
			t.relativePoint or "CENTER",
			t.x or 0,
			t.y or 0
		)
	end
	SarychUI.DragMode:ShowGrid(showGrid and (posOn or showDrag))
end

function module:StopDrag(frameId)
	if SarychUI.DragMode then
		SarychUI.DragMode:EnableEditMode(frameId, false, false, false)
	end
end

function module:MakeBar(parent)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetStatusBarTexture(BAR_TEX)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(1)
	local bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture(BLANK)
	bg:SetAllPoints()
	bg:SetVertexColor(0.1, 0.1, 0.1, 0.85)
	bar.bg = bg
	local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("RIGHT", -2, 0)
	bar.text = text
	return bar
end

function module:SetBarColor(bar, r, g, b)
	bar:SetStatusBarColor(r, g, b)
	if bar.bg then
		bar.bg:SetVertexColor(r * 0.25, g * 0.25, b * 0.25, 0.9)
	end
end

function module:PowerRGB(powerType)
	local c = PowerBarColor and PowerBarColor[powerType]
	if c then
		return c.r, c.g, c.b
	end
	return 0, 0, 1
end

function module:ClassRGB()
	local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[PLAYER_CLASS]
	if c then
		return c.r, c.g, c.b
	end
	return 0, 0.8, 0
end

function module:FormatValue(v)
	v = tonumber(v) or 0
	if v >= 10000 then
		return string.format("%.1fk", v / 1000)
	end
	return tostring(math.floor(v + 0.5))
end

function module:SetFont(fs, size)
	if not fs then
		return
	end
	local path = GameFontNormal:GetFont()
	fs:SetFont(path, size or 10, "OUTLINE")
end

function module:Refresh()
	local db = self:DB()
	if not db or db.enabled == false then
		self:Disable()
		return
	end
	-- Панель игрока всегда включена вместе с модулем (отдельного флага нет).
	if db.plate then
		db.plate.enabled = 1
	end
	if self.RefreshPlate then
		self:RefreshPlate()
	end
	if self.RefreshShield then
		self:RefreshShield()
	end
	if self.RefreshRunes then
		self:RefreshRunes()
	end
	if self.RefreshTotems then
		self:RefreshTotems()
	end
end

function module:Enable()
	local db = self:DB()
	if not db or not db.enabled then
		return
	end
	self:Refresh()
end

function module:Disable()
	if self.DisablePlate then
		self:DisablePlate()
	end
	if self.DisableShield then
		self:DisableShield()
	end
	if self.DisableRunes then
		self:DisableRunes()
	end
	if self.DisableTotems then
		self:DisableTotems()
	end
end

function module:RefreshConfig()
	self:Refresh()
end
