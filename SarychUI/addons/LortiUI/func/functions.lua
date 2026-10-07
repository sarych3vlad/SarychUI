-- Ported from Lorti UI func/functions.lua (rActionButtonStyler)
-- В режиме затемнения кнопки переключаются на media Lorti; при выключении — обратно.

local L = SarychUI_LortiUI
local cfg = L.cfg
local _G = _G
local nomoreplay = function() end

local classcolor = RAID_CLASS_COLORS[select(2, UnitClass("player"))]
if cfg.color.classcolored then
	cfg.color.normal = classcolor
end

local bgfile, edgefile = "", ""
if cfg.background.showshadow then
	edgefile = cfg.textures.outer_shadow
end
if cfg.background.useflatbackground and cfg.background.showbg then
	bgfile = cfg.textures.buttonbackflat
end

local backdrop = {
	bgFile = bgfile,
	edgeFile = edgefile,
	tile = false,
	tileSize = 32,
	edgeSize = cfg.background.inset,
	insets = {
		left = cfg.background.inset,
		right = cfg.background.inset,
		top = cfg.background.inset,
		bottom = cfg.background.inset,
	},
}

local function GetTexPath(tex)
	if tex and tex.GetTexture then
		return tex:GetTexture()
	end
end

local function CallWidget(obj, method, ...)
	if not obj then return end
	local fn = obj[method]
	obj[method] = nil
	local native = obj[method]
	if native then
		native(obj, ...)
	elseif fn then
		fn(obj, ...)
	end
	obj[method] = fn
end

local function applyBackground(bu, anchor)
	if not cfg.background.showbg and not cfg.background.showshadow then
		return
	end
	if bu.bg then
		bu.bg:Show()
		return
	end
	anchor = anchor or bu
	bu.bg = CreateFrame("Frame", nil, bu)
	bu.bg:SetPoint("TOPLEFT", anchor, "TOPLEFT", -4, 4)
	bu.bg:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 4, -4)
	local lvl = bu:GetFrameLevel() or 1
	if lvl < 1 then lvl = 1 end
	bu.bg:SetFrameLevel(lvl - 1)

	if cfg.background.classcolored then
		cfg.background.backgroundcolor = classcolor
		cfg.background.shadowcolor = classcolor
	end

	if cfg.background.showbg and not cfg.background.useflatbackground then
		local t = bu.bg:CreateTexture(nil, "BACKGROUND")
		t:SetTexture(cfg.textures.buttonback)
		t:SetAllPoints(anchor)
		t:SetVertexColor(cfg.background.backgroundcolor.r, cfg.background.backgroundcolor.g, cfg.background.backgroundcolor.b, cfg.background.backgroundcolor.a)
	end

	if bu.bg.SetBackdrop then
		bu.bg:SetBackdrop(backdrop)
		if cfg.background.useflatbackground then
			bu.bg:SetBackdropColor(cfg.background.backgroundcolor.r, cfg.background.backgroundcolor.g, cfg.background.backgroundcolor.b, cfg.background.backgroundcolor.a)
		end
		if cfg.background.showshadow then
			bu.bg:SetBackdropBorderColor(cfg.background.shadowcolor.r, cfg.background.shadowcolor.g, cfg.background.shadowcolor.b, cfg.background.shadowcolor.a)
		end
	end
end

L.ApplyButtonBackground = applyBackground

local function ntSetVertexColorFunc(nt, r, g, b)
	if not L.enabled or L._painting or not nt then
		return
	end
	local parent = nt.GetParent and nt:GetParent()
	local action = parent and parent.action
	L._painting = true
	if r == 1 and g == 1 and b == 1 and action and IsEquippedAction(action) then
		nt:SetVertexColor(cfg.color.equipped.r, cfg.color.equipped.g, cfg.color.equipped.b, 1)
	elseif r == 0.5 and g == 0.5 and b == 1 then
		nt:SetVertexColor(cfg.color.normal.r, cfg.color.normal.g, cfg.color.normal.b, 1)
	elseif r == 1 and g == 1 and b == 1 then
		nt:SetVertexColor(cfg.color.normal.r, cfg.color.normal.g, cfg.color.normal.b, 1)
	end
	L._painting = false
end

local function HookNormalTex(nt)
	if not nt or nt.suiLortiHooked then
		return
	end
	nt.suiLortiHooked = true
	hooksecurefunc(nt, "SetVertexColor", ntSetVertexColorFunc)
end

local function ColorActiveTex(ct)
	if not ct then
		return
	end
	local c = cfg.color.normal
	L._painting = true
	ct:SetVertexColor(c.r, c.g, c.b, c.a or 1)
	L._painting = false
end

local function ctSetVertexColorFunc(ct, r, g, b)
	if not L.enabled or L._painting or not ct or ct.suiLortiKeepBlizzardColor then
		return
	end
	if r == 1 and g == 1 and b == 1 then
		ColorActiveTex(ct)
	end
end

local function HookCheckedTex(ct)
	if not ct or ct.suiLortiCheckedHooked then
		return
	end
	ct.suiLortiCheckedHooked = true
	hooksecurefunc(ct, "SetVertexColor", ctSetVertexColorFunc)
end

local function SaveButton(bu, name)
	if bu.suiLortiSaved then
		return
	end
	local ic = _G[name .. "Icon"] or _G[name .. "IconTexture"]
	local fl = _G[name .. "Flash"]
	local nt = _G[name .. "NormalTexture2"] or _G[name .. "NormalTexture"] or (bu.GetNormalTexture and bu:GetNormalTexture())
	local ht = bu.GetHighlightTexture and bu:GetHighlightTexture()
	local pt = bu.GetPushedTexture and bu:GetPushedTexture()
	local ct = bu.GetCheckedTexture and bu:GetCheckedTexture()
	local saved = {
		normal = GetTexPath(nt) or [[Interface\Buttons\UI-Quickslot2]],
		highlight = GetTexPath(ht) or [[Interface\Buttons\ButtonHilight-Square]],
		pushed = GetTexPath(pt) or [[Interface\Buttons\UI-Quickslot-Depress]],
		checked = GetTexPath(ct) or [[Interface\Buttons\CheckButtonHilight]],
		flash = GetTexPath(fl) or [[Interface\Buttons\UI-QuickslotRed]],
		iconULx = 0, iconULy = 0, iconLLx = 0, iconLLy = 1, iconURx = 1, iconURy = 0, iconLRx = 1, iconLRy = 1,
	}
	if ic and ic.GetTexCoord then
		saved.iconULx, saved.iconULy, saved.iconLLx, saved.iconLLy, saved.iconURx, saved.iconURy, saved.iconLRx, saved.iconLRy = ic:GetTexCoord()
	end
	bu.suiLortiSaved = saved
end

local function SetRegionTexture(tex, path)
	if not tex or not path then
		return
	end
	local stub = tex.SetTexture
	tex.SetTexture = nil
	local native = tex.SetTexture
	if native then
		native(tex, path)
	elseif stub and stub ~= nomoreplay then
		stub(tex, path)
	end
	tex.SetTexture = stub
	if tex.SetTexCoord then
		tex:SetTexCoord(0, 1, 0, 1)
	end
end

local function PinOverlay(tex, path, blend, anchor)
	if not tex then
		return
	end
	if path then
		SetRegionTexture(tex, path)
	end
	anchor = anchor or (tex.GetParent and tex:GetParent())
	if anchor then
		tex:ClearAllPoints()
		tex:SetAllPoints(anchor)
	end
	if tex.SetBlendMode and blend then
		tex:SetBlendMode(blend)
	end
	tex:SetAlpha(1)
end

local function PaintActionOverlays(bu, fl, anchor, isItem)
	PinOverlay(bu.GetHighlightTexture and bu:GetHighlightTexture(), cfg.textures.hover, "ADD", anchor)
	local pushed = bu.GetPushedTexture and bu:GetPushedTexture()
	PinOverlay(pushed, cfg.textures.pushed, "BLEND", anchor)
	local ct = bu.GetCheckedTexture and bu:GetCheckedTexture()
	-- CheckedTexture is Blizzard's yellow queued/current-action indicator
	-- (for example Heroic Strike). Keep it intact for action buttons instead
	-- of replacing it with Lorti's black checked overlay.
	if isItem then
		PinOverlay(ct, cfg.textures.checked, "ADD", anchor)
		ColorActiveTex(ct)
		HookCheckedTex(ct)
	end
	PinOverlay(fl, cfg.textures.flash, "ADD", anchor)
end

local function ApplyLortiTextures(bu, name, isItem)
	local ic = _G[name .. "Icon"] or _G[name .. "IconTexture"]
	local fl = _G[name .. "Flash"]
	local nt = _G[name .. "NormalTexture2"] or _G[name .. "NormalTexture"] or (bu.GetNormalTexture and bu:GetNormalTexture())
	-- LargeItemButtonTemplate / QuestItemTemplate buttons include the item name
	-- in the button itself.  Their IconTexture is the square visual slot; using
	-- the whole button as the anchor stretches both the icon and Lorti artwork.
	local decorationAnchor = isItem and ic or bu
	if not isItem then
		local saved = bu.suiLortiSaved
		if saved and bu.SetCheckedTexture then
			bu:SetCheckedTexture(saved.checked)
			local checked = bu.GetCheckedTexture and bu:GetCheckedTexture()
			if checked then
				-- Keep Blizzard's CheckButtonHilight white-tinted, which preserves
				-- the native yellow queued/current-action indicator.
				checked.suiLortiKeepBlizzardColor = true
				L._painting = true
				checked:SetVertexColor(1, 1, 1, 1)
				L._painting = false
			end
		end
	end

	PaintActionOverlays(bu, fl, decorationAnchor, isItem)

	local normalTex = cfg.textures.normal
	local vr, vg, vb, va = cfg.color.normal.r, cfg.color.normal.g, cfg.color.normal.b, cfg.color.normal.a
	if (not isItem) and bu.action and IsEquippedAction(bu.action) then
		normalTex = cfg.textures.equipped
		vr, vg, vb, va = cfg.color.equipped.r, cfg.color.equipped.g, cfg.color.equipped.b, 1
	end
	CallWidget(bu, "SetNormalTexture", normalTex)
	nt = _G[name .. "NormalTexture2"] or _G[name .. "NormalTexture"] or (bu.GetNormalTexture and bu:GetNormalTexture())
	if nt then
		SetRegionTexture(nt, normalTex)
		nt:ClearAllPoints()
		nt:SetAllPoints(decorationAnchor or bu)
		L._painting = true
		nt:SetVertexColor(vr, vg, vb, va)
		L._painting = false
		HookNormalTex(nt)
	end

	if ic then
		ic:SetTexCoord(0.1, 0.9, 0.1, 0.9)
		if not isItem then
			ic:ClearAllPoints()
			ic:SetPoint("TOPLEFT", bu, "TOPLEFT", 2, -2)
			ic:SetPoint("BOTTOMRIGHT", bu, "BOTTOMRIGHT", -2, 2)
		end
	end
	return decorationAnchor
end

-- rActionButtonStyler_AB_style
function L.StyleActionButton(self)
	if not L.enabled or not self then
		return
	end
	local parent = self.GetParent and self:GetParent()
	local pname = parent and parent.GetName and parent:GetName()
	if pname == "MultiCastActionBarFrame" or pname == "MultiCastActionPage1"
		or pname == "MultiCastActionPage2" or pname == "MultiCastActionPage3" then
		return
	end
	local name = self.GetName and self:GetName()
	if not name then
		return
	end
	local bu = _G[name] or self
	local bo = _G[name .. "Border"]
	local cd = _G[name .. "Cooldown"]

	SaveButton(bu, name)
	if bo then
		bo:Hide()
	end
	ApplyLortiTextures(bu, name, false)
	if cd then
		cd:SetPoint("TOPLEFT", bu, "TOPLEFT", cfg.cooldown.spacing, -cfg.cooldown.spacing)
		cd:SetPoint("BOTTOMRIGHT", bu, "BOTTOMRIGHT", -cfg.cooldown.spacing, cfg.cooldown.spacing)
	end
	bu.suiLortiStyled = true
	if not bu.bg then
		applyBackground(bu)
	else
		bu.bg:Show()
	end
	L.paintedButtons[name] = true
end

-- rActionButtonStyler_AB_stylepet
function L.StylePetButtons()
	if not L.enabled then
		return
	end
	local i, slots
	slots = NUM_PET_ACTION_SLOTS or 10
	for i = 1, slots do
		local name = "PetActionButton" .. i
		local bu = _G[name]
		if bu then
			SaveButton(bu, name)
			ApplyLortiTextures(bu, name, false)
			bu.suiLortiStyled = true
			if not bu.bg then
				applyBackground(bu)
			else
				bu.bg:Show()
			end
			L.paintedButtons[name] = true
		end
	end
end

-- rActionButtonStyler_AB_styleshapeshift
function L.StyleShapeshiftButtons()
	if not L.enabled then
		return
	end
	local i, slots
	slots = NUM_SHAPESHIFT_SLOTS or 10
	for i = 1, slots do
		local name = "ShapeshiftButton" .. i
		local bu = _G[name]
		if bu then
			SaveButton(bu, name)
			ApplyLortiTextures(bu, name, false)
			bu.suiLortiStyled = true
			if not bu.bg then
				applyBackground(bu)
			else
				bu.bg:Show()
			end
			L.paintedButtons[name] = true
		end
	end
end

-- Only item-style buttons that live on the main menu bar panel are skinned.
-- Everything else (professions, talents/inspect, LFD rewards, loot, quests,
-- bags, bank, merchant, trade, mail...) must keep Blizzard's default look:
-- the gloss/vertex tint made those icons far too dark.
local function IsPanelItemButtonName(name)
	if type(name) ~= "string" then
		return false
	end
	if name == "MainMenuBarBackpackButton" then
		return true
	end
	return name:match("^CharacterBag%dSlot$") ~= nil
end

L.IsPanelItemButtonName = IsPanelItemButtonName

function L:PaintItemButton(button)
	if not self.enabled then
		return
	end
	if type(button) == "string" then
		button = _G[button]
	end
	if not button then
		return
	end
	local name = button.GetName and button:GetName()
	if not name or not IsPanelItemButtonName(name) then
		return
	end
	SaveButton(button, name)
	local decorationAnchor = ApplyLortiTextures(button, name, true)
	button.suiLortiStyled = true
	if not button.bg then
		applyBackground(button, decorationAnchor)
	else
		button.bg:Show()
	end
	self.paintedButtons[name] = true
end

function L:RestoreButton(bu)
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
	local saved = bu.suiLortiSaved
	local ic = _G[name .. "Icon"] or _G[name .. "IconTexture"]
	local fl = _G[name .. "Flash"]
	local nt = _G[name .. "NormalTexture2"] or _G[name .. "NormalTexture"] or (bu.GetNormalTexture and bu:GetNormalTexture())
	local bo = _G[name .. "Border"]

	bu.suiLortiStyled = nil
	if bo then
		bo.Show = nil
	end

	if saved then
		if bu.SetHighlightTexture then
			bu:SetHighlightTexture(saved.highlight)
		end
		if bu.SetPushedTexture then
			bu:SetPushedTexture(saved.pushed)
		end
		if bu.SetCheckedTexture then
			bu:SetCheckedTexture(saved.checked)
		end
		if fl then
			fl:SetTexture(saved.flash)
		end
		if bu.SetNormalTexture then
			bu:SetNormalTexture(saved.normal)
		end
		if ic then
			ic:SetTexCoord(saved.iconULx, saved.iconULy, saved.iconLLx, saved.iconLLy, saved.iconURx, saved.iconURy, saved.iconLRx, saved.iconLRy)
			ic:SetPoint("TOPLEFT", bu, "TOPLEFT", 2, -2)
			ic:SetPoint("BOTTOMRIGHT", bu, "BOTTOMRIGHT", -2, 2)
		end
	else
		if bu.SetNormalTexture then
			bu:SetNormalTexture([[Interface\Buttons\UI-Quickslot2]])
		end
		if ic then
			ic:SetTexCoord(0, 1, 0, 1)
		end
	end

	nt = _G[name .. "NormalTexture2"] or _G[name .. "NormalTexture"] or (bu.GetNormalTexture and bu:GetNormalTexture())
	if nt then
		self:RestoreTexture(nt)
	end
	if bo and bu.action and IsEquippedAction(bu.action) then
		bo:SetVertexColor(0, 1.0, 0, 0.35)
		bo:Show()
	elseif bo then
		bo:Hide()
	end
	if bu.bg then
		bu.bg:Hide()
	end
	bu.suiLortiStyled = nil
	self.paintedButtons[name] = nil
end

L.paperDollSlots = {
	"HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot",
	"ShirtSlot", "TabardSlot", "WristSlot", "HandsSlot", "WaistSlot",
	"LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot",
	"Trinket0Slot", "Trinket1Slot", "MainHandSlot", "SecondaryHandSlot",
	"RangedSlot", "AmmoSlot",
}

function L:PaintAllItemButtons()
	-- Panel-only: backpack + bag slots on the main menu bar.
	local i
	self:PaintItemButton("MainMenuBarBackpackButton")
	for i = 0, 3 do
		self:PaintItemButton("CharacterBag" .. i .. "Slot")
	end
end

function L:ApplyButtons()
	local i
	for i = 1, 12 do
		self.StyleActionButton(_G["ActionButton" .. i])
		self.StyleActionButton(_G["BonusActionButton" .. i])
		self.StyleActionButton(_G["MultiBarBottomLeftButton" .. i])
		self.StyleActionButton(_G["MultiBarBottomRightButton" .. i])
		self.StyleActionButton(_G["MultiBarRightButton" .. i])
		self.StyleActionButton(_G["MultiBarLeftButton" .. i])
	end
	self.StyleShapeshiftButtons()
	self.StylePetButtons()
	for i = 1, 2 do
		self.StyleActionButton(_G["PossessButton" .. i])
	end
	self:PaintAllItemButtons()
end

function L:RestoreButtons()
	local name, names, i
	names = {}
	for name in pairs(self.paintedButtons) do
		names[#names + 1] = name
	end
	for i = 1, #names do
		self:RestoreButton(names[i])
	end
end

function L:InstallButtonHooks()
	if self.buttonHooksInstalled then
		return
	end
	self.buttonHooksInstalled = true
	if not hooksecurefunc then
		return
	end

	if ActionButton_Update then
		hooksecurefunc("ActionButton_Update", L.StyleActionButton)
	end
	if ActionButton_ShowGrid then
		hooksecurefunc("ActionButton_ShowGrid", L.StyleActionButton)
	end
	if ActionButton_UpdateUsable then
		hooksecurefunc("ActionButton_UpdateUsable", L.StyleActionButton)
	end
	if ActionButton_UpdateState then
		hooksecurefunc("ActionButton_UpdateState", function(button)
			if not L.enabled or not button or not button.suiLortiStyled then
				return
			end
			local name = button.GetName and button:GetName()
			PaintActionOverlays(button, name and _G[name .. "Flash"])
		end)
	end
	if ShapeshiftBar_Update then
		hooksecurefunc("ShapeshiftBar_Update", L.StyleShapeshiftButtons)
	end
	if ShapeshiftBar_UpdateState then
		hooksecurefunc("ShapeshiftBar_UpdateState", L.StyleShapeshiftButtons)
	end
	if PetActionBar_Update then
		hooksecurefunc("PetActionBar_Update", L.StylePetButtons)
	end

	if SetItemButtonTexture then
		hooksecurefunc("SetItemButtonTexture", function(button)
			L:PaintItemButton(button)
		end)
	end
	if SetItemButtonNormalTextureVertexColor then
		hooksecurefunc("SetItemButtonNormalTextureVertexColor", function(button, r, g, b)
			if r == 1 and g == 1 and b == 1 then
				L:PaintItemButton(button)
			elseif r == 0.5 and g == 0.5 and b == 1 then
				L:PaintItemButton(button)
			end
		end)
	end
	-- ContainerFrame_Update / PaperDollItemSlotButton_Update hooks were removed:
	-- bag, character and inspect item slots keep their default Blizzard textures.
end
