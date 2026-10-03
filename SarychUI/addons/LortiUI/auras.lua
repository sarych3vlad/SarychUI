-- Lorti gloss on player / unit-frame aura borders.
-- Buffs get a created gloss overlay; debuffs reuse $parentBorder (keep type color).

local L = SarychUI_LortiUI
local cfg = L.cfg
local _G = _G

L.paintedAuras = L.paintedAuras or {}

local DEBUFF_OVERLAY = [[Interface\Buttons\UI-Debuff-Overlays]]
local DEBUFF_L, DEBUFF_R, DEBUFF_T, DEBUFF_B = 0.296875, 0.5703125, 0, 0.515625

local function IsDebuffName(name)
	return name:find("Debuff", 1, true) or name:find("TempEnchant", 1, true)
end

local function IsBossTargetName(name)
	return type(name) == "string" and string.match(name, "^Boss%d+TargetFrame") ~= nil
end

function L:StyleAuraButton(bu, skipBackground)
	if not self.enabled or not bu then
		return
	end
	local name = bu.GetName and bu:GetName()
	if not name then
		return
	end
	local icon = _G[name .. "Icon"]
	local border = _G[name .. "Border"]
	local isDebuff = IsDebuffName(name)

	if not bu.suiLortiAuraSaved then
		local saved = {}
		if icon and icon.GetTexCoord then
			saved.iconULx, saved.iconULy, saved.iconLLx, saved.iconLLy, saved.iconURx, saved.iconURy, saved.iconLRx, saved.iconLRy = icon:GetTexCoord()
		end
		if border then
			saved.hasBlizzBorder = true
			saved.borderTex = border.GetTexture and border:GetTexture()
			if border.GetTexCoord then
				saved.bULx, saved.bULy, saved.bLLx, saved.bLLy, saved.bURx, saved.bURy, saved.bLRx, saved.bLRy = border:GetTexCoord()
			end
		end
		bu.suiLortiAuraSaved = saved
	end

	if icon then
		icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", bu, "TOPLEFT", 1, -1)
		icon:SetPoint("BOTTOMRIGHT", bu, "BOTTOMRIGHT", -1, 1)
	end

	if isDebuff then
		if not border then
			border = bu:CreateTexture(nil, "OVERLAY")
			bu.suiLortiAuraBorder = border
		end
		border:SetTexture(cfg.textures.normal)
		border:SetTexCoord(0, 1, 0, 1)
		border:ClearAllPoints()
		border:SetAllPoints(bu)
		border:Show()
	else
		border = bu.suiLortiAuraBorder
		if not border then
			border = bu:CreateTexture(nil, "OVERLAY")
			bu.suiLortiAuraBorder = border
		end
		border:SetTexture(cfg.textures.normal)
		border:SetTexCoord(0, 1, 0, 1)
		border:ClearAllPoints()
		border:SetAllPoints(bu)
		local r, g, b, a = self.GetColor()
		border:SetVertexColor(r, g, b, a)
		border:Show()
	end

	if (not skipBackground) and self.ApplyButtonBackground then
		self.ApplyButtonBackground(bu)
	end
	self.paintedAuras[name] = true
end

function L:RestoreAuraButton(bu)
	if type(bu) == "string" then
		bu = _G[bu]
	end
	if not bu then
		return
	end
	local name = bu.GetName and bu:GetName()
	if not name then
		return
	end
	local saved = bu.suiLortiAuraSaved
	local icon = _G[name .. "Icon"]
	local border = _G[name .. "Border"]
	local extra = bu.suiLortiAuraBorder

	if icon then
		if saved and saved.iconULx then
			icon:SetTexCoord(saved.iconULx, saved.iconULy, saved.iconLLx, saved.iconLLy, saved.iconURx, saved.iconURy, saved.iconLRx, saved.iconLRy)
		else
			icon:SetTexCoord(0, 1, 0, 1)
		end
		icon:ClearAllPoints()
		icon:SetAllPoints(bu)
	end

	if extra then
		extra:Hide()
	end

	if border then
		local tex = (saved and saved.borderTex) or DEBUFF_OVERLAY
		border:SetTexture(tex)
		if saved and saved.bULx then
			border:SetTexCoord(saved.bULx, saved.bULy, saved.bLLx, saved.bLLy, saved.bURx, saved.bURy, saved.bLRx, saved.bLRy)
		else
			border:SetTexCoord(DEBUFF_L, DEBUFF_R, DEBUFF_T, DEBUFF_B)
		end
		border:ClearAllPoints()
		border:SetPoint("TOPLEFT", bu, "TOPLEFT", -1, 1)
		border:SetPoint("BOTTOMRIGHT", bu, "BOTTOMRIGHT", 1, -1)
	end

	if bu.bg then
		bu.bg:Hide()
	end
	self.paintedAuras[name] = nil
end

local function SkinNamed(prefix, count)
	local i
	for i = 1, count do
		L:StyleAuraButton(_G[prefix .. i])
	end
end

function L:ApplyAuras()
	SkinNamed("BuffButton", 40)
	SkinNamed("DebuffButton", 16)
	SkinNamed("TempEnchant", 3)
	SkinNamed("TargetFrameBuff", 32)
	SkinNamed("TargetFrameDebuff", 16)
	SkinNamed("FocusFrameBuff", 32)
	SkinNamed("FocusFrameDebuff", 16)
	SkinNamed("TargetFrameToTDebuff", 4)
	SkinNamed("FocusFrameToTDebuff", 4)
	SkinNamed("PetFrameDebuff", 4)
	local p, i
	for p = 1, 4 do
		for i = 1, 4 do
			self:StyleAuraButton(_G["PartyMemberFrame" .. p .. "Debuff" .. i])
		end
	end
end

function L:RestoreAuras()
	local name, names, i
	names = {}
	for name in pairs(self.paintedAuras) do
		names[#names + 1] = name
	end
	for i = 1, #names do
		self:RestoreAuraButton(names[i])
	end
end

function L:InstallAuraHooks()
	if self.auraHooksInstalled then
		return
	end
	self.auraHooksInstalled = true
	if not hooksecurefunc then
		return
	end
	if AuraButton_Update then
		hooksecurefunc("AuraButton_Update", function(buttonName, index)
			if not L.enabled or not buttonName or not index or IsBossTargetName(buttonName) then
				return
			end
			L:StyleAuraButton(_G[buttonName .. index])
		end)
	end
	-- Do not hook TargetFrame_UpdateAuras: the same Blizzard function also
	-- updates protected BossNTargetFrame instances. Target/focus aura buttons
	-- are already styled by ApplyAuras and their own aura events.
	if TargetofTarget_Update then
		hooksecurefunc("TargetofTarget_Update", function()
			if not L.enabled then
				return
			end
			SkinNamed("TargetFrameToTDebuff", 4)
			SkinNamed("FocusFrameToTDebuff", 4)
		end)
	end
	if RefreshDebuffs then
		hooksecurefunc("RefreshDebuffs", function(frame)
			if not L.enabled or not frame then
				return
			end
			local fname = frame.GetName and frame:GetName()
			if not fname or IsBossTargetName(fname) then
				return
			end
			local i
			for i = 1, 8 do
				L:StyleAuraButton(_G[fname .. "Debuff" .. i])
			end
		end)
	end
end
