--- copyright; Blizzard Entertainment // BlizzardInterfaceCode /
-- /@ loss of control; // s0h2x, pretty_wow @/

-- Global enabled state
pw_lossofcontrolEnabled = pw_lossofcontrolEnabled or true;

-- Function to check if addon is enabled
local function IsEnabled()
	if pw_lossofcontrolEnabled == false then return false end
	local extension = SarychUI and SarychUI.extensions and SarychUI.extensions.aura_tracking
	if extension and not extension:IsEnabled() then return false end
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.pw_lossofcontrol then
		return SarychUI.db.profile.addons.pw_lossofcontrol.enabled ~= false;
	end
	return pw_lossofcontrolEnabled;
end

local select = select;
local unpack = unpack;
local next = next;
local pairs = pairs;
local tInsert = table.insert;
local tWipe = table.wipe;
local tSort = table.sort;
local max = math.max;

local private = select(2,...);
local Timer = private.Timer;
local RegisterCMD = private.SetSlashCMD;
local PlaySound = PlaySound;
local GetTime = GetTime;
local UnitAura = SarychUI.AuraTracking.UnitAura;
local UnitAffectingCombat = UnitAffectingCombat;
local GetSchoolString = GetSchoolString;
local GetSpellInfo = GetSpellInfo;

local MECHANIC_CHARM			= 1;
local MECHANIC_DISORIENTED      = 2;
local MECHANIC_DISARM           = 3;
local MECHANIC_DISTRACT         = 4;
local MECHANIC_FEAR             = 5;
local MECHANIC_GRIP             = 6;
local MECHANIC_ROOT             = 7;
local MECHANIC_SLOW_ATTACK      = 8;
local MECHANIC_SILENCE          = 9;
local MECHANIC_SLEEP            = 10;
local MECHANIC_SNARE            = 11;
local MECHANIC_STUN             = 12;
local MECHANIC_FREEZE           = 13;
local MECHANIC_KNOCKOUT         = 14;
local MECHANIC_BLEED            = 15;
local MECHANIC_BANDAGE          = 16;
local MECHANIC_POLYMORPH        = 17;
local MECHANIC_BANISH           = 18;
local MECHANIC_SHIELD           = 19;
local MECHANIC_SHACKLE          = 20;
local MECHANIC_MOUNT            = 21;
local MECHANIC_INFECTED         = 22;
local MECHANIC_TURN             = 23;
local MECHANIC_HORROR           = 24;
local MECHANIC_INVULNERABILITY  = 25;
local MECHANIC_INTERRUPT        = 26;
local MECHANIC_DAZE             = 27;
local MECHANIC_DISCOVERY        = 28;
local MECHANIC_IMMUNE_SHIELD    = 29;
local MECHANIC_SAPPED           = 30;
local MECHANIC_ENRAGED          = 31;

local TEXT_OVERRIDE = {
	[33786] = LOSS_OF_CONTROL_DISPLAY_CYCLONE
};
local LOSS_OF_CONTROL_TIME_OFFSET = 0;
local SINGLE_ICON_X = -62;
local SINGLE_TEXT_LEFT = SINGLE_ICON_X + 24 + 8;
local NAME_LEFT_NUDGE = -4;
local DISPLAY_TYPE_FULL = 2;
local DISPLAY_TYPE_ALERT = 1;
local DISPLAY_TYPE_NONE = 0;
local ACTIVE_INDEX = 1;
local LOC_DATA = private.LOSS_OF_CONTROL_SPELL_DATA;
local C_MSG = "|cff00b5ff[LoC]:|r "..MSG_CHAT_RESET;
local MULTI_ICON_SIZE = 42;
local MULTI_ICON_GAP = 6;
local THIN_LINE_HALF_WIDTH = 118;
local DEFAULT_SCALE = 0.95;
local DEFAULT_NAME_FONT_SIZE = 20;
local DEFAULT_TIMER_FONT_SIZE = 20;
local MIN_FONT_SIZE = 8;
local MAX_FONT_SIZE = 40;
local nameFontPath, nameFontFlags;
local timerFontPath, timerFontFlags;

local MECHANIC_OPTION = {
	[MECHANIC_STUN] = "showStuns",
	[MECHANIC_SILENCE] = "showSilences",
	[MECHANIC_DISARM] = "showDisarms",
	[MECHANIC_ROOT] = "showRoots",
	[MECHANIC_CHARM] = "showOtherControl",
	[MECHANIC_DISORIENTED] = "showOtherControl",
	[MECHANIC_FEAR] = "showOtherControl",
	[MECHANIC_SLEEP] = "showOtherControl",
	[MECHANIC_FREEZE] = "showOtherControl",
	[MECHANIC_KNOCKOUT] = "showOtherControl",
	[MECHANIC_POLYMORPH] = "showOtherControl",
	[MECHANIC_BANISH] = "showOtherControl",
	[MECHANIC_SHACKLE] = "showOtherControl",
	[MECHANIC_TURN] = "showOtherControl",
	[MECHANIC_HORROR] = "showOtherControl",
	[MECHANIC_SAPPED] = "showOtherControl",
};

local function GetOptionsDB()
	local addons = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons;
	return addons and addons.pw_lossofcontrol;
end

local function IsMechanicEnabled(mechanic)
	local db = GetOptionsDB();
	local option = MECHANIC_OPTION[mechanic];
	if not option then return false; end
	return not db or db[option] ~= false;
end

local function GetLineStyle()
	local db = GetOptionsDB();
	return db and db.lineStyle or "thin";
end

local function ClampFontSize(value, fallback)
	value = tonumber(value) or fallback;
	if value < MIN_FONT_SIZE then return MIN_FONT_SIZE; end
	if value > MAX_FONT_SIZE then return MAX_FONT_SIZE; end
	return value;
end

local function GetNameFontSize()
	local db = GetOptionsDB();
	return ClampFontSize(db and db.nameFontSize, DEFAULT_NAME_FONT_SIZE);
end

local function GetTimerFontSize()
	local db = GetOptionsDB();
	return ClampFontSize(db and db.timerFontSize, DEFAULT_TIMER_FONT_SIZE);
end

function LossOfControlFrame_GetNameFontSize()
	return GetNameFontSize();
end

function LossOfControlFrame_GetTimerFontSize()
	return GetTimerFontSize();
end

local function CaptureTextStyle(fs)
	if not fs or fs.locColor then return; end
	local r, g, b, a = fs:GetTextColor();
	local sr, sg, sb, sa = fs:GetShadowColor();
	local sx, sy = fs:GetShadowOffset();
	fs.locColor = { r or 1, g or 1, b or 1, a or 1 };
	fs.locShadowColor = { sr or 0, sg or 0, sb or 0, sa or 1 };
	fs.locShadowOffset = { sx or 0, sy or 0 };
end

local function RestoreTextStyle(fs)
	if not fs or not fs.locColor then return; end
	fs:SetTextColor(unpack(fs.locColor));
	fs:SetShadowColor(unpack(fs.locShadowColor));
	fs:SetShadowOffset(fs.locShadowOffset[1], fs.locShadowOffset[2]);
end

local function CaptureFontDefaults(self)
	local path, size, flags = self.AbilityName:GetFont();
	nameFontPath = path or "Fonts\\FRIZQT__.TTF";
	nameFontFlags = flags or "";
	if size and size > 0 then
		DEFAULT_NAME_FONT_SIZE = size;
	end
	path, size, flags = self.TimeLeft.NumberText:GetFont();
	timerFontPath = path or nameFontPath;
	timerFontFlags = flags or "";
	if size and size > 0 then
		DEFAULT_TIMER_FONT_SIZE = size;
	end
	CaptureTextStyle(self.AbilityName);
	CaptureTextStyle(self.TimeLeft.NumberText);
	CaptureTextStyle(self.TimeLeft.SecondsText);
end

local function SetFontExact(fs, path, size, flags)
	if not fs then return; end
	path = path or "Fonts\\FRIZQT__.TTF";
	flags = type(flags) == "string" and flags or "";
	size = tonumber(size) or 12;
	CaptureTextStyle(fs);
	-- XML font objects (MovieSubtitleFont / GameFontNormalHuge) keep their own
	-- size and put it back when the test frame is shown. Detach first.
	if fs.SetFontObject then
		pcall(fs.SetFontObject, fs, "GameFontHighlight");
	end
	if not fs:SetFont(path, size, flags) then
		fs:SetFont("Fonts\\FRIZQT__.TTF", size, "");
	end
	local _, applied = fs:GetFont();
	if not applied or math.abs(applied - size) > 0.5 then
		fs:SetFont("Fonts\\FRIZQT__.TTF", size, "");
	end
	RestoreTextStyle(fs);
end

local function ApplyTextSizes()
	local self = LossOfControlFrame;
	if not self or not self.AbilityName or not nameFontPath then return; end
	local nameSize = GetNameFontSize();
	local timerSize = GetTimerFontSize();
	self.locNameFontSize = nameSize;
	self.locTimerFontSize = timerSize;
	SetFontExact(self.AbilityName, nameFontPath, nameSize, nameFontFlags);
	self.AbilityName:SetHeight(math.max(nameSize, 20));

	local timeLeft = self.TimeLeft;
	if not timeLeft or not timerFontPath then return; end
	SetFontExact(timeLeft.NumberText, timerFontPath, timerSize, timerFontFlags);
	SetFontExact(timeLeft.SecondsText, timerFontPath, timerSize, timerFontFlags);
	timeLeft.NumberText:SetHeight(math.max(timerSize, 20));
	timeLeft.SecondsText:SetHeight(math.max(timerSize, 20));
	timeLeft:SetHeight(math.max(timerSize, 20));
	timeLeft.NumberText:ClearAllPoints();
	timeLeft.NumberText:SetPoint("LEFT", timeLeft, "LEFT", 0, 0);
	timeLeft.SecondsText:ClearAllPoints();
	timeLeft.SecondsText:SetPoint("LEFT", timeLeft.NumberText, "RIGHT", LOSS_OF_CONTROL_TIME_OFFSET, 0);
	local previousNumber = timeLeft.NumberText:GetText();
	timeLeft.NumberText:SetText(" ");
	timeLeft.spaceWidth = timeLeft.NumberText:GetStringWidth() or 0;
	timeLeft.NumberText:SetText(previousNumber or "");
	timeLeft.secondsWidth = timeLeft.SecondsText:GetStringWidth();
	timeLeft.baseNumberWidth = timeLeft.NumberText:GetStringWidth() + LOSS_OF_CONTROL_TIME_OFFSET;
end

local function LayoutSingleTexts(self)
	local nameSize = self.locNameFontSize or DEFAULT_NAME_FONT_SIZE;
	local timerSize = self.locTimerFontSize or DEFAULT_TIMER_FONT_SIZE;
	local nameY = nameSize * 0.45 + 2;
	local timerY = -(timerSize * 0.45 + 2);
	local spaceWidth = self.TimeLeft and self.TimeLeft.spaceWidth or 0;
	self.Icon:ClearAllPoints();
	self.Icon:SetPoint("CENTER", self, "CENTER", SINGLE_ICON_X, 0);
	self.AbilityName:ClearAllPoints();
	self.AbilityName:SetJustifyH("LEFT");
	self.AbilityName:SetPoint("LEFT", self, "CENTER", SINGLE_TEXT_LEFT + NAME_LEFT_NUDGE, nameY);
	self.TimeLeft:ClearAllPoints();
	self.TimeLeft:SetPoint("LEFT", self, "CENTER", SINGLE_TEXT_LEFT - spaceWidth, timerY);
end

local function GetDisplayMode()
	local db = GetOptionsDB();
	return db and db.displayMode or "multiple";
end

local function GetConfiguredScale()
	local db = GetOptionsDB();
	local scale = db and tonumber(db.scale);
	if not scale then return DEFAULT_SCALE; end
	return max(0.5, math.min(2, scale));
end

local function SaveConfiguredScale(scale)
	local db = GetOptionsDB();
	if db then db.scale = scale; end
	LosOfControl = LosOfControl or {};
	LosOfControl.scale = scale;
end

local function ApplyConfiguredScale()
	if LossOfControlFrame then
		LossOfControlFrame:SetScale(GetConfiguredScale());
	end
end

local function SaveConfiguredPosition(x, y)
	local db = GetOptionsDB();
	if db then
		db.positionX = x;
		db.positionY = y;
	end
end

local function ApplyConfiguredPosition()
	local self = LossOfControlFrame;
	local db = GetOptionsDB();
	if not self or not db or (db.positionX == nil and db.positionY == nil) then return; end
	local _, _, _, currentX, currentY = self:GetPoint();
	local x = tonumber(db.positionX);
	local y = tonumber(db.positionY);
	if x == nil then x = currentX or 0; end
	if y == nil then y = currentY or -16; end
	self:ClearAllPoints();
	self:SetPoint("CENTER", UIParent, "CENTER", x, y);
	LosOfControl = LosOfControl or {};
	LosOfControl.position = { "CENTER", "CENTER", x, y };
end

function LossOfControlFrame_GetPositionOffset(axis)
	local db = GetOptionsDB();
	if axis == "x" and db and db.positionX ~= nil then return db.positionX; end
	if axis == "y" and db and db.positionY ~= nil then return db.positionY; end
	if LossOfControlFrame then
		local _, _, _, x, y = LossOfControlFrame:GetPoint();
		return axis == "x" and (x or 0) or (y or 20);
	end
	return axis == "x" and 0 or -16;
end

local multiIcons = {};

local function HideThinLines(self)
	if not self.ThinLines then return; end
	for i = 1, #self.ThinLines do
		self.ThinLines[i]:Hide();
	end
end

local function SetThinLineWidth(self, width)
	if not self.ThinLines then return; end
	for i = 1, #self.ThinLines do
		self.ThinLines[i]:SetWidth(width);
	end
end

local function CreateThinLine(self, point, relativePoint, fromAlpha, toAlpha)
	local line = self:CreateTexture(nil, "BACKGROUND");
	line:SetTexture("Interface\\Buttons\\WHITE8X8");
	line:SetGradientAlpha("HORIZONTAL", 1, 0.1, 0.1, fromAlpha, 1, 0.1, 0.1, toAlpha);
	line:SetSize(THIN_LINE_HALF_WIDTH, 2);
	line:SetPoint(point, self, relativePoint, 0, 0);
	tInsert(self.ThinLines, line);
end

local function CreateThinLines(self)
	if self.ThinLines then return; end
	self.ThinLines = {};
	CreateThinLine(self, "BOTTOMRIGHT", "TOP", 0, 1);
	CreateThinLine(self, "BOTTOMLEFT", "TOP", 1, 0);
	CreateThinLine(self, "TOPRIGHT", "BOTTOM", 0, 1);
	CreateThinLine(self, "TOPLEFT", "BOTTOM", 1, 0);
	HideThinLines(self);
end

function LossOfControlFrame_ApplyLineStyle()
	local self = LossOfControlFrame;
	if not self or not self.RedLineTop or not self.RedLineBottom then return; end
	CreateThinLines(self);
	self.thinLineAnim = nil;
	SetThinLineWidth(self, THIN_LINE_HALF_WIDTH);
	self.RedLineTop:Hide();
	self.RedLineBottom:Hide();
	HideThinLines(self);
	local style = GetLineStyle();
	if self.blackBg then
		if style == "none" then
			self.blackBg:Hide();
		else
			self.blackBg:Show();
		end
	end
	if style == "default" then
		self.RedLineTop:Show();
		self.RedLineBottom:Show();
	elseif style == "thin" then
		for i = 1, #self.ThinLines do
			self.ThinLines[i]:Show();
		end
	end
end

local function HideMultiIcons()
	for i = 1, #multiIcons do
		if multiIcons[i].Anim then multiIcons[i].Anim:Stop(); end
		multiIcons[i]:Hide();
	end
end

local function GetMultiIcon(index)
	local holder = multiIcons[index];
	if holder then return holder; end
	holder = CreateFrame("Frame", nil, LossOfControlFrame);
	holder:SetSize(MULTI_ICON_SIZE, MULTI_ICON_SIZE);
	holder.Icon = holder:CreateTexture(nil, "ARTWORK");
	holder.Icon:SetAllPoints();
	-- Keep the complete spell texture: unlike action-button icons, the main
	-- LossOfControl icon is not cropped, so its built-in dark rim stays visible.
	holder.Icon:SetTexCoord(0, 1, 0, 1);
	holder.Cooldown = CreateFrame("Cooldown", nil, holder, "SUI_LossOfControlMultiCooldownTemplate");
	holder.Cooldown:SetAllPoints();
	holder.Cooldown.noCooldownCount = true;
	if holder.Cooldown.SetReverse then holder.Cooldown:SetReverse(true); end

	-- Same 1.33 -> 1.0 pop used by the main LossOfControl icon.
	holder.Anim = holder:CreateAnimationGroup();
	local grow = holder.Anim:CreateAnimation("Scale");
	grow:SetScale(1.33, 1.33);
	grow:SetDuration(0.1);
	grow:SetOrder(1);
	local settle = holder.Anim:CreateAnimation("Scale");
	settle:SetScale(0.75, 0.75);
	settle:SetDuration(0.1);
	settle:SetOrder(2);
	multiIcons[index] = holder;
	return holder;
end

local function SetSingleDisplayVisible(self, shown)
	if shown then
		self.multiMode = nil;
		self.Icon:Show();
		self.AbilityName:Show();
		LossOfControlFrame_ApplyLineStyle();
	else
		self.multiMode = true;
		self.Icon:Hide();
		self.AbilityName:Hide();
		self.TimeLeft:Hide();
		self.Cooldown:Hide();
		LossOfControlFrame_ApplyLineStyle();
	end
end

local function ShowMultipleEffects(self, effects, animate)
	SetSingleDisplayVisible(self, false);
	HideMultiIcons();
	local count = #effects;
	local totalWidth = count * MULTI_ICON_SIZE + (count - 1) * MULTI_ICON_GAP;
	for i = 1, count do
		local effect = effects[i];
		local holder = GetMultiIcon(i);
		holder:ClearAllPoints();
		holder:SetPoint("LEFT", self, "CENTER", -totalWidth / 2 + (i - 1) * (MULTI_ICON_SIZE + MULTI_ICON_GAP), 0);
		holder.Icon:SetTexture(effect.iconTexture);
		if effect.duration and effect.duration > 0 then
			CooldownFrame_SetTimer(holder.Cooldown, effect.startTime, effect.duration, 1);
			if SarychUI_NotifyCooldown then SarychUI_NotifyCooldown(holder.Cooldown, effect.startTime, effect.duration, 1) end
			holder.Cooldown:Show();
		else
			holder.Cooldown:Hide();
		end
		holder:Show();
		if animate and holder.Anim then holder.Anim:Play(); end
	end
	if animate then
		local style = GetLineStyle();
		if style == "default" then
			self.RedLineTop.Anim:Play();
			self.RedLineBottom.Anim:Play();
		elseif style == "thin" then
			self.thinLineAnim = 0;
			SetThinLineWidth(self, THIN_LINE_HALF_WIDTH * 0.1);
		end
	end
	self:Show();
end

-- animation
local function LossOfControlFrame_AnimPlay(self)
	if GetLineStyle() == "default" then
		self.RedLineTop.Anim:Play();
		self.RedLineBottom.Anim:Play();
	elseif GetLineStyle() == "thin" then
		self.thinLineAnim = 0;
		SetThinLineWidth(self, THIN_LINE_HALF_WIDTH * 0.1);
	end
	self.Icon.Anim:Play();
end

local function LossOfControlFrame_AnimStop(self)
	if self.RedLineTop.Anim then self.RedLineTop.Anim:Stop(); end
	if self.RedLineBottom.Anim then self.RedLineBottom.Anim:Stop(); end
	if self.Icon.Anim then self.Icon.Anim:Stop(); end
	self.thinLineAnim = nil;
	SetThinLineWidth(self, THIN_LINE_HALF_WIDTH);
end

local function LossOfControlFrame_AnimIsPlaying(self)
	local isPlaying = false;
	if self.RedLineTop.Anim and self.RedLineTop.Anim:IsPlaying() then
		isPlaying = true;
	end
	if self.RedLineBottom.Anim and self.RedLineBottom.Anim:IsPlaying() then
		isPlaying = true;
	end
	if self.Icon.Anim and self.Icon.Anim:IsPlaying() then
		isPlaying = true;
	end
	return isPlaying;
end

local LOCMechanicData = {
    [MECHANIC_CHARM]            = {LOCALE_SPELL_MECHANIC_CHARM, 8},
    [MECHANIC_DISORIENTED]      = {LOCALE_SPELL_MECHANIC_DISORIENTED, 5},
    [MECHANIC_DISARM]           = {LOCALE_SPELL_MECHANIC_DISARM, 2},
    [MECHANIC_DISTRACT]         = {LOCALE_SPELL_MECHANIC_DISTRACT, 0},
    [MECHANIC_FEAR]             = {LOCALE_SPELL_MECHANIC_FEAR, 6},
    [MECHANIC_GRIP]             = {LOCALE_SPELL_MECHANIC_GRIP, 0},
    [MECHANIC_ROOT]             = {LOCALE_SPELL_MECHANIC_ROOT, 1},
    [MECHANIC_SLOW_ATTACK]      = {LOCALE_SPELL_MECHANIC_SLOW_ATTACK, 0},
    [MECHANIC_SILENCE]          = {LOCALE_SPELL_MECHANIC_SILENCE, 4},
    [MECHANIC_SLEEP]            = {LOCALE_SPELL_MECHANIC_SLEEP, 4},
    [MECHANIC_SNARE]            = {LOCALE_SPELL_MECHANIC_SNARE, 0},
    [MECHANIC_STUN]             = {LOCALE_SPELL_MECHANIC_STUN, 7},
    [MECHANIC_FREEZE]           = {LOCALE_SPELL_MECHANIC_FREEZE, 7},
    [MECHANIC_KNOCKOUT]         = {LOCALE_SPELL_MECHANIC_KNOCKOUT, 7},
    [MECHANIC_BLEED]            = {LOCALE_SPELL_MECHANIC_BLEED, 0},
    [MECHANIC_BANDAGE]          = {LOCALE_SPELL_MECHANIC_BANDAGE, 0},
    [MECHANIC_POLYMORPH]        = {LOCALE_SPELL_MECHANIC_POLYMORPH, 5},
    [MECHANIC_BANISH]           = {LOCALE_SPELL_MECHANIC_BANISH, 1},
    [MECHANIC_SHIELD]           = {LOCALE_SPELL_MECHANIC_SHIELD, 0},
    [MECHANIC_SHACKLE]          = {LOCALE_SPELL_MECHANIC_SHACKLE, 1},
    [MECHANIC_MOUNT]            = {LOCALE_SPELL_MECHANIC_MOUNT, 0},
    [MECHANIC_INFECTED]         = {LOCALE_SPELL_MECHANIC_INFECTED, 0},
    [MECHANIC_TURN]             = {LOCALE_SPELL_MECHANIC_TURN, 6},
    [MECHANIC_HORROR]           = {LOCALE_SPELL_MECHANIC_HORROR, 6},
    [MECHANIC_INVULNERABILITY]  = {LOCALE_SPELL_MECHANIC_INVULNERABILITY, 0},
    [MECHANIC_INTERRUPT]        = {LOCALE_SPELL_MECHANIC_INTERRUPT, 0},
    [MECHANIC_DAZE]             = {LOCALE_SPELL_MECHANIC_DAZE, 0},
    [MECHANIC_DISCOVERY]        = {LOCALE_SPELL_MECHANIC_DISCOVERY, 0},
    [MECHANIC_IMMUNE_SHIELD]    = {LOCALE_SPELL_MECHANIC_IMMUNE_SHIELD, 0},
    [MECHANIC_SAPPED]           = {LOCALE_SPELL_MECHANIC_SAPPED, 7},
    [MECHANIC_ENRAGED]          = {LOCALE_SPELL_MECHANIC_ENRAGED, 0},
};

local lossOfControlData = {};
local tempLossOfControlData = {};
local testMode = false;
local testExpires = nil;

local TEST_EFFECTS = {
	{ spellID = 853, mechanic = MECHANIC_STUN, text = "Оглушение", icon = "Interface\\Icons\\Spell_Holy_SealOfMight" },
	{ spellID = 15487, mechanic = MECHANIC_SILENCE, text = "Немота", icon = "Interface\\Icons\\Spell_Shadow_ImpPhaseShift" },
	{ spellID = 676, mechanic = MECHANIC_DISARM, text = "Обезоруживание", icon = "Interface\\Icons\\Ability_Warrior_Disarm" },
	{ spellID = 122, mechanic = MECHANIC_ROOT, text = "Обездвиживание", icon = "Interface\\Icons\\Spell_Frost_FrostNova" },
	{ spellID = 5782, mechanic = MECHANIC_FEAR, text = "Остальной контроль", icon = "Interface\\Icons\\Spell_Shadow_Possession" },
};

local function AddTestEffects(target, filterCategories)
	local now = GetTime();
	local duration = 10;
	testExpires = now + duration;
	for i = 1, #TEST_EFFECTS do
		local spec = TEST_EFFECTS[i];
		if not filterCategories or IsMechanicEnabled(spec.mechanic) then
			local name, icon;
			if GetSpellInfo then
				name, _, icon = GetSpellInfo(spec.spellID);
			end
			local mechanicData = LOCMechanicData[spec.mechanic];
			tInsert(target, {
				locType = spec.mechanic,
				spellID = spec.spellID,
				text = spec.text or (mechanicData and mechanicData[1]) or name,
				name = name or spec.text,
				iconTexture = icon or spec.icon or "Interface\\Icons\\INV_Misc_QuestionMark",
				startTime = now,
				duration = duration,
				priority = mechanicData and mechanicData[2] or 0,
				expirationTime = now + duration,
				displayType = DISPLAY_TYPE_FULL,
			});
		end
	end
end

function LossOfControlFrame_OnLoad(self)

	self:RegisterEvent("VARIABLES_LOADED");

	self.AnimPlay = LossOfControlFrame_AnimPlay;
	self.AnimStop = LossOfControlFrame_AnimStop;
	self.AnimIsPlaying = LossOfControlFrame_AnimIsPlaying;

	CaptureFontDefaults(self);
	ApplyTextSizes();
	CreateThinLines(self);
	LossOfControlFrame_ApplyLineStyle();
	ApplyConfiguredScale();
	ApplyConfiguredPosition();

	LossOfControlFrame_OnEvent(self, "UNIT_AURA", "player");
end

local function LossOfControlFrame_UpdateData(animate)
	lossOfControlData = {};
	local multipleMode = GetDisplayMode() == "multiple";

	local unlockData = tempLossOfControlData["UNLOCK"];
	if unlockData then
		tInsert(lossOfControlData, unlockData);
	elseif testMode then
		AddTestEffects(lossOfControlData, multipleMode);
	else
		for _, spellData in pairs(tempLossOfControlData) do
			if spellData and (not multipleMode or IsMechanicEnabled(spellData.locType)) then
				tInsert(lossOfControlData, spellData);
			end
		end
	end

	tSort(lossOfControlData, function(a, b)
		local aPriority = a.priority or 0;
		local bPriority = b.priority or 0;
		if aPriority ~= bPriority then return aPriority > bPriority; end
		return (a.expirationTime or 0) > (b.expirationTime or 0);
	end);

	local self = LossOfControlFrame;
	local eventCount = #lossOfControlData;
	if multipleMode and eventCount > 1 then
		self.fadeTime = nil;
		ShowMultipleEffects(self, lossOfControlData, animate ~= false);
		return;
	end

	HideMultiIcons();
	SetSingleDisplayVisible(self, true);
	if eventCount >= ACTIVE_INDEX then
		self.fadeTime = nil;
		local locType, spellID, text, iconTexture, startTime, timeRemaining, duration, lockoutSchool, priority, displayType = LossOfControlGetEventInfo(ACTIVE_INDEX);
		LossOfControlFrame_SetUpDisplay(self, animate ~= false, locType, spellID, text, iconTexture, startTime, timeRemaining, duration, lockoutSchool, priority, displayType);
	else
		self:Hide();
	end
end

function LossOfControlFrame_RefreshOptions()
	if not IsEnabled() then
		SarychUI.AuraTracking:Unsubscribe("lossOfControl");
		HideMultiIcons();
		if LossOfControlFrame then
			LossOfControlFrame:Hide();
		end
		return;
	end
	SarychUI.AuraTracking:Subscribe("lossOfControl", function(unit)
		if unit == "player" and IsEnabled() then LossOfControlFrame_OnEvent(LossOfControlFrame, "UNIT_AURA", unit); end
	end);
	LossOfControlFrame_OnEvent(LossOfControlFrame, "UNIT_AURA", "player");
	ApplyConfiguredScale();
	ApplyConfiguredPosition();
	ApplyTextSizes();
	LossOfControlFrame_ApplyLineStyle();
	LossOfControlFrame_UpdateData(testMode);
end

function LossOfControlFrame_IsTestActive()
	return testMode;
end

function LossOfControlFrame_SetTestMode(enabled)
	testMode = enabled and true or false;
	testExpires = nil;
	if LossOfControlFrame then
		if testMode then
			LossOfControlFrame.normalFrameStrata = LossOfControlFrame.normalFrameStrata or LossOfControlFrame:GetFrameStrata();
			LossOfControlFrame.normalFrameLevel = LossOfControlFrame.normalFrameLevel or LossOfControlFrame:GetFrameLevel();
			LossOfControlFrame:SetFrameStrata("TOOLTIP");
			LossOfControlFrame:SetFrameLevel(100);
		else
			LossOfControlFrame:SetFrameStrata(LossOfControlFrame.normalFrameStrata or "MEDIUM");
			LossOfControlFrame:SetFrameLevel(LossOfControlFrame.normalFrameLevel or 0);
		end
	end
	if IsEnabled() then
		-- Use the same animated display path as /loc; this is the most reliable
		-- way to wake a frame which was hidden before the test started.
		ApplyTextSizes();
		LossOfControlFrame_UpdateData(testMode);
	elseif LossOfControlFrame then
		LossOfControlFrame:Hide();
	end
end

function LossOfControlFrame_ToggleTestMode()
	LossOfControlFrame_SetTestMode(not testMode);
end

function LossOfControlGetEventInfo(index)
	if not index then
		return nil;
	end
	
	local data = lossOfControlData[index];
	if not data then
		return nil;
	end

	local locType 		= data.locType;
	local spellID 		= data.spellID;
	local text 			= data.text;
	local iconTexture 	= data.iconTexture;
	local startTime 	= data.startTime;
	local timeRemaining = data.expirationTime ~= 0 and data.expirationTime - GetTime() or nil;
	local duration 		= data.duration;
	local lockoutSchool = "lockoutSchool";
	local priority 		= data.priority;
	local displayType 	= data.displayType;

	return locType, spellID, text, iconTexture, startTime, timeRemaining, duration, lockoutSchool, priority, displayType;
end

local function LossOfControlAddOrUpdateDebuff(spellID, name, icon, duration, expirationTime)
	if not IsEnabled() then
		return;
	end
	-- Names are not unique: unrelated debuffs can share a control spell's name.
	-- The catalog includes ranks explicitly; only exact IDs qualify here.
	local LOCSpellMechanic = LOC_DATA[spellID];
	if LOCSpellMechanic and MECHANIC_OPTION[LOCSpellMechanic] then
		local startTime = expirationTime and duration and expirationTime > 0 and (expirationTime - duration) or GetTime();
		local priority = LOCMechanicData[LOCSpellMechanic][2] or 0;
		local text = LOCMechanicData[LOCSpellMechanic][1] or name;

		tempLossOfControlData[spellID] = {
			locType 		= LOCSpellMechanic,
			spellID 		= spellID,
			text 			= text,
			name 			= name,
			iconTexture 	= icon,
			startTime 		= startTime,
			duration 		= duration,
			priority 		= priority,
			expirationTime  = expirationTime,
			displayType 	= DISPLAY_TYPE_FULL
		};
		LossOfControlFrame_UpdateData();
	end
end

local function LossOfControlRemoveDebuff(spellID)
	if not IsEnabled() then
		return;
	end
	tempLossOfControlData[spellID] = nil;
	LossOfControlFrame_UpdateData();
end

local auraTrackerStorage = {};
function LossOfControlFrame_OnEvent(self, event, unit)
	if not IsEnabled() then
		return;
	end
	if event == "UNIT_AURA" and unit == "player" then
		for i=1, 40 do
			local name, _, icon, _, _, duration, expirationTime, _, _, _, spellID = UnitAura("player", i, "HARMFUL");
			if name and spellID then
				local hasAura = auraTrackerStorage[spellID] and auraTrackerStorage[spellID][1];
				if hasAura == nil then
					LossOfControlAddOrUpdateDebuff(spellID, name, icon, duration, expirationTime);
				else
					local saveDuration = auraTrackerStorage[spellID][2] - GetTime();
					local newBuffDuation = expirationTime - GetTime();

					if newBuffDuation > saveDuration then
						LossOfControlAddOrUpdateDebuff(spellID, name, icon, duration, expirationTime);
					end
				end
				auraTrackerStorage[spellID] = {false, expirationTime};
			end
		end

		for spellID, auraData in pairs(auraTrackerStorage) do
			if not auraData[1] then
				auraTrackerStorage[spellID][1] = true;
			else
				LossOfControlRemoveDebuff(spellID);
				auraTrackerStorage[spellID] = nil;
			end
		end
	end
	
	if event == "VARIABLES_LOADED" then
		if not LosOfControl then
			LosOfControl = {};
		end
		
		local db = GetOptionsDB();
		if db and (db.positionX ~= nil or db.positionY ~= nil) then
			ApplyConfiguredPosition();
		elseif LosOfControl.position ~= nil then
			local point, relativePoint, offsetx, offsety = unpack(LosOfControl.position);
			self:ClearAllPoints();
			self:SetPoint(point, "UIParent", relativePoint, offsetx, offsety);
		end
		
		if LosOfControl.scale ~= nil then
			self:SetScale(GetConfiguredScale());
		end
	end
end

function LossOfControlFrame_OnUpdate(self, elapsed)
	if not IsEnabled() then
		return;
	end
	if self.unlocked and UnitAffectingCombat("player") then
		LossOfControlFrame_Lock(self);
		return;
	end
	if self.thinLineAnim then
		self.thinLineAnim = self.thinLineAnim + elapsed;
		local t = self.thinLineAnim;
		local factor;
		if t < 0.1 then
			factor = 0.1 + 1.3 * (t / 0.1);
		elseif t < 0.2 then
			factor = 1.4 - 0.4 * ((t - 0.1) / 0.1);
		else
			factor = 1;
			self.thinLineAnim = nil;
		end
		SetThinLineWidth(self, THIN_LINE_HALF_WIDTH * factor);
	end
	if testMode and testExpires and GetTime() >= testExpires then
		LossOfControlFrame_UpdateData(false);
	end
	
	-- handle alert type
	if self.fadeTime then
		self.fadeTime = self.fadeTime - elapsed
		self:SetAlpha(max(self.fadeTime*2, 0.0))
		if (self.fadeTime < 0) then
			self:Hide();
		else
			-- no need to do any other work
			return;
		end
	else
		self:SetAlpha(1.0);
	end
	LossOfControlFrame_UpdateDisplay(self);
end

function LossOfControlFrame_OnHide(self)
	self.fadeTime = nil;
	self.priority = nil;
end

function LossOfControlFrame_SetUpDisplay(self, animate, locType, spellID, text, iconTexture, startTime, timeRemaining, duration, lockoutSchool, priority, displayType)
	if not locType then
		locType, spellID, text, iconTexture, startTime, timeRemaining, duration, lockoutSchool, priority, displayType = LossOfControlGetEventInfo(ACTIVE_INDEX);
	end
	if (text and displayType ~= DISPLAY_TYPE_NONE) then
		HideMultiIcons();
		SetSingleDisplayVisible(self, true);
		text = TEXT_OVERRIDE[spellID] or text;
		if (locType == "SCHOOL_INTERRUPT") then
			-- replace text with school-specific lockout text
			if (lockoutSchool and lockoutSchool ~= 0) then
				text = string.format(LOSS_OF_CONTROL_DISPLAY_INTERRUPT_SCHOOL, GetSchoolString(lockoutSchool));
			end
		end
		ApplyTextSizes();
		self.AbilityName:SetText(text);
		self.Icon:SetTexture(iconTexture);
		
		local timeLeftFrame = self.TimeLeft;
		if (displayType == DISPLAY_TYPE_ALERT) then
			timeRemaining = duration;
		elseif startTime then
			CooldownFrame_SetTimer(self.Cooldown, startTime, duration, 1);
			if SarychUI_NotifyCooldown then SarychUI_NotifyCooldown(self.Cooldown, startTime, duration, 1) end
		end
		LossOfControlSetTimeLeft(timeLeftFrame, timeRemaining);
		LayoutSingleTexts(self);

		if (animate) then
			if (displayType == DISPLAY_TYPE_ALERT) then
				self.fadeTime = 1.5;
			end
			self:AnimStop();
			self.AbilityName.scrollTime = 0;
			self.TimeLeft.NumberText.scrollTime = 0;
			self.TimeLeft.SecondsText.scrollTime = 0;
			self.Cooldown:Hide();
			self:AnimPlay();
			PlaySound(34468);
		end
		self.priority = priority;
		self.spellID = spellID;
		self.startTime = startTime;
		self:Show();
		-- Show() can restore the inherited font size. Put the saved sizes back.
		ApplyTextSizes();
		LossOfControlSetTimeLeft(timeLeftFrame, timeRemaining);
		LayoutSingleTexts(self);
	end
end

function LossOfControlFrame_UpdateDisplay(self)
	-- if displaying an alert, wait for it to go away on its own
	if self.fadeTime then return; end
	if self.multiMode then return; end

	local locType, spellID, text, iconTexture, startTime, timeRemaining, duration, lockoutSchool, priority, displayType = LossOfControlGetEventInfo(ACTIVE_INDEX);
	if (text and displayType == DISPLAY_TYPE_FULL) then
		if (spellID ~= self.spellID or startTime ~= self.startTime) then
			LossOfControlFrame_SetUpDisplay(self, false, locType, spellID, text, iconTexture, startTime, timeRemaining, duration, lockoutSchool, priority, displayType);
		end
		if (not self:AnimIsPlaying() and startTime) then
			CooldownFrame_SetTimer(self.Cooldown, startTime, duration, 1);
			if SarychUI_NotifyCooldown then SarychUI_NotifyCooldown(self.Cooldown, startTime, duration, 1) end
		end
		LossOfControlSetTimeLeft(self.TimeLeft, timeRemaining);
	else
		self:Hide();
	end
end

function LossOfControlSetTimeLeft(self, timeRemaining)
	if timeRemaining then
		local extension = SarychUI.extensions and SarychUI.extensions.aura_tracking;
		if extension and extension.GetTimerColor then
			CaptureTextStyle(self.NumberText);
			CaptureTextStyle(self.SecondsText);
			self.NumberText:SetTextColor(unpack(extension:GetTimerColor(timeRemaining, self.NumberText.locColor)));
			self.SecondsText:SetTextColor(unpack(extension:GetTimerColor(timeRemaining, self.SecondsText.locColor)));
		end
		if (timeRemaining >= 10) then
			self.NumberText:SetFormattedText(" %d ", timeRemaining);
		elseif (timeRemaining < 9.95) then
			self.NumberText:SetFormattedText(" %.1F ", timeRemaining);
		end
		if (timeRemaining > 0) then
			self:Show();
		else
			self:Hide();
		end
		
		self.timeRemaining = timeRemaining;
		self.numberWidth = self.NumberText:GetStringWidth() + LOSS_OF_CONTROL_TIME_OFFSET;
		local secondsWidth = self.SecondsText:GetStringWidth();
		self.secondsWidth = secondsWidth;
		self:SetWidth(math.max(1, self.numberWidth + secondsWidth));
	else
		self:Hide();
		self.numberWidth = 0;
	end
end

local function LossOfControlFrame_Unlock(self)
	self:EnableMouse(true);
	self:EnableMouseWheel(true);
	self:RegisterForDrag("LeftButton");
	self.unlocked = true;

	local timer = Timer.NewTimer(10, function()
		LossOfControlFrame_Lock(self);
	end)

	tempLossOfControlData["UNLOCK"] = {
		locType 		= LOCALE_SPELL_MECHANIC_DAZE,
		spellID 		= 692,
		text			= DRAG_TO_MOVE_SCROLL_TO_SIZE,
		name 			= "UNLOCK",
		iconTexture		= "Interface\\ICONS\\Spell_Frost_Stun",
		startTime 		= GetTime(),
		duration		= 10,
		priority 		= 100,
		expirationTime 	= GetTime() + 10,
		displayType		= DISPLAY_TYPE_FULL,
		timer 			= timer
	};

	self:SetScript("OnDragStart", function(self)
		self:StartMoving();
		self:SetUserPlaced(false);
		local data = tempLossOfControlData["UNLOCK"];

		if data.timer then
			data.timer:Cancel();
			data.timer = nil;
		end

		data.duration = 0;
		data.startTime = 0;
		data.expirationTime = 0;

		LossOfControlFrame_UpdateDisplay(self);
	end);

	self:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing();
		local data = tempLossOfControlData["UNLOCK"];

		if data.timer then
			data.timer:Cancel();
			data.timer = nil;
		end

		local timer = Timer.NewTimer(10, function()
			LossOfControlFrame_Lock(self);
		end);

		data.timer = timer;

		data.duration = 10;
		data.startTime = GetTime();
		data.expirationTime = GetTime() + data.duration;
		
		LossOfControlFrame_UpdateDisplay(self);
	end);

	self:SetScript("OnMouseWheel", function(self, value)
		if value ~= 0 then
			local scale = self:GetScale();
			if value > 0 then
				self:SetScale(math.min(2, scale + 0.05));
			elseif value < 0 then
				self:SetScale(max(0.5, scale - 0.05));
			end

			local data = tempLossOfControlData["UNLOCK"];

			if data.timer then
				data.timer:Cancel();
				data.timer = nil;
			end

			local timer = Timer.NewTimer(10, function()
				LossOfControlFrame_Lock(self);
			end);

			data.timer = timer;

			data.duration = 10;
			data.startTime = GetTime();
			data.expirationTime = GetTime() + data.duration;

			LossOfControlFrame_UpdateDisplay(self);
		end
	end);

	local data = tempLossOfControlData["UNLOCK"];
	LossOfControlAddOrUpdateDebuff(data.spellID, data.name, data.iconTexture, data.duration, data.expirationTime);
	LossOfControlFrame_UpdateDisplay(self);
end

function LossOfControlFrame_Lock(self)
	self:EnableMouse(false);
	self:EnableMouseWheel(false);
	self:RegisterForDrag();
	self.unlocked = nil;

	if tempLossOfControlData["UNLOCK"] then
		local data = tempLossOfControlData["UNLOCK"];
		if data.timer then
			data.timer:Cancel();
			data.timer = nil;
		end
	end
	SaveConfiguredScale(self:GetScale());

	tempLossOfControlData["UNLOCK"] = nil;
	if self.spellID == 692 then
		self.spellID = nil;
	end
	LossOfControlRemoveDebuff(692);
	
	local point, _, relativePoint, offsetX, offsetY = self:GetPoint();
	SaveConfiguredPosition(offsetX or 0, offsetY or 20);
	LosOfControl = {
		position = { point, relativePoint, offsetX, offsetY };
		scale = self:GetScale();
	};
	
	self:SetScript("OnDragStart", nil);
	self:SetScript("OnDragStop", nil);
	self:SetScript("OnMouseWheel", nil);
end

local function ResetPositionAndSize(self)
	self:ClearAllPoints();
	self:SetPoint("CENTER", UIParent, "CENTER", 0, -16);
	self:SetScale(DEFAULT_SCALE);

	tWipe(LosOfControl);
	SaveConfiguredScale(DEFAULT_SCALE);
	SaveConfiguredPosition(0, -16);
	LosOfControl.position = { "CENTER", "CENTER", 0, -16 };
end

RegisterCMD("LOC", function() LossOfControlFrame_Unlock(LossOfControlFrame); end, "loc");
RegisterCMD("LOC1", function() ResetPositionAndSize(LossOfControlFrame); print(C_MSG); end, "locreset");
RegisterCMD("LOCTEST", function()
	local ok, errorMessage = pcall(LossOfControlFrame_ToggleTestMode);
	if not ok then
		print("|cffff3333[SUI LoC test]:|r " .. tostring(errorMessage));
	end
end, "loctest");


function LossOfControlFrame_SetRuntimeEnabled(enable)
    SarychUI.AuraTracking:Unsubscribe("lossOfControl")
    if enable then
        SarychUI.AuraTracking:Subscribe("lossOfControl", function(unit)
            if unit == "player" and IsEnabled() then LossOfControlFrame_OnEvent(LossOfControlFrame, "UNIT_AURA", unit) end
        end)
    end
end
