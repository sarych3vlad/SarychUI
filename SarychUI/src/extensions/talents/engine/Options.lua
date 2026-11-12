local Talented = _G.Talented
local L = LibStub("AceLocale-3.0"):GetLocale("Talented")

Talented.max_talent_points = 71

Talented.BUILTIN_TEMPLATES = {
	["Bonjourepta"] = "Atp2n0aZAZ0wDEcDbA3aDbra",
}

Talented.defaults = {
	profile = {
		level_cap = true,
		show_level_req = true,
		offset = 42,
		scale = 1.05,
		add_bottom_offset = true,
		framepos = {},
		glyph_on_talent_swap = "active",
	},
	global = {
		templates = {},
	},
	char = {targets = {}}
}

for name, code in pairs(Talented.BUILTIN_TEMPLATES) do
	Talented.defaults.global.templates[name] = code
end

function Talented:SetOption(info, value)
	local name = info[#info]
	self.db.profile[name] = value
	local arg = info.arg
	if arg then
		self[arg](self)
	end
end

function Talented:GetOption(info)
	local name = info[#info]
	return self.db.profile[name]
end

Talented.options = {
	desc = L["Talented - Talent Editor"],
	type = "group",
	childGroups = "tab",
	handler = Talented,
	get = "GetOption",
	set = "SetOption",
	args = {
		options = {
			name = L["Options"],
			desc = L["General Options for Talented."],
			type = "group",
			order = 1,
			args = {}
		},
		apply = {
			name = "Apply",
			desc = "Apply the specified template",
			type = "input",
			dialogHidden = true,
			order = 99,
			set = function(_, name)
				local template = Talented.db.global.templates[name]
				if not template then
					Talented:Print(L['Can not apply, unknown template "%s"'], name)
					return
				end
				Talented:SetTemplate(template)
				Talented:SetMode "apply"
			end
		}
	}
}

function Talented:ReLayout()
	self:ViewsReLayout(true)
end

function Talented:UpgradeOptions()
	local p = self.db.profile
	if p.point or p.offsetx or p.offsety then
		local opts = {
			anchor = p.point or "CENTER",
			anchorTo = p.point or "CENTER",
			x = p.offsetx or 0,
			y = p.offsety or 0
		}
		p.framepos.TalentedFrame = opts
		p.point, p.offsetx, p.offsety = nil, nil, nil
	end
	local c = self.db.char
	if c.target then
		c.targets[1] = c.target
		c.target = nil
	end
	-- One-shot: migrate previous Talented scale default (1) to 1.05.
	if p._scaleDefaultsRev ~= 1 then
		if p.scale == nil or p.scale == 1 then
			p.scale = 1.05
		end
		p._scaleDefaultsRev = 1
	end
	self.UpgradeOptions = nil
end

function Talented:SaveFramePosition(frame)
	local db = self.db.profile.framepos
	local name = frame:GetName()

	local data, _ = db[name]
	if not data then
		data = {}
		db[name] = data
	end
	data.anchor, _, data.anchorTo, data.x, data.y = frame:GetPoint(1)
end

function Talented:LoadFramePosition(frame)
	if not self.db then
		self:OnInitialize()
	end
	local data = self.db.profile.framepos[frame:GetName()]
	if data and data.anchor then
		frame:ClearAllPoints()
		frame:SetPoint(data.anchor, UIParent, data.anchorTo, data.x, data.y)
	else
		frame:SetPoint "CENTER"
		self:SaveFramePosition(frame)
	end
end

local function BaseFrame_OnMouseDown(self)
	if self.OnMouseDown then
		self:OnMouseDown()
	end
	self:StartMoving()
end

local function BaseFrame_OnMouseUp(self)
	self:StopMovingOrSizing()
	Talented:SaveFramePosition(self)
	if self.OnMouseUp then
		self:OnMouseUp()
	end
end

function Talented:SetFrameLock(frame, locked)
	local db = self.db.profile.framepos
	local name = frame:GetName()
	local data = db[name]
	if not data then
		data = {}
		db[name] = data
	end
	if locked == nil then
		locked = data.locked
	elseif locked == false then
		locked = nil
	end
	data.locked = locked
	if locked then
		frame:SetMovable(false)
		frame:SetScript("OnMouseDown", nil)
		frame:SetScript("OnMouseUp", nil)
	else
		frame:SetMovable(true)
		frame:SetScript("OnMouseDown", BaseFrame_OnMouseDown)
		frame:SetScript("OnMouseUp", BaseFrame_OnMouseUp)
	end
	frame:SetClampedToScreen(true)
end

function Talented:GetFrameLock(frame)
	local data = self.db.profile.framepos[frame:GetName()]
	return data and data.locked
end
