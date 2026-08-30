--[[
    Equipence
    Copyright (c) 2026 s0high. All rights reserved.

    Source-available proprietary software. See LICENSE for terms.
]]

--@class Engine<ns>
local Engine = select(2, ...);

--@natives<lua,wow>
local CreateFrame = CreateFrame;
local tinsert = table.insert;
local tremove = table.remove;

---------------------------------------------------------------------------------------------------
-- ShineUtil renders a lightweight looping shine effect around a frame.
-- Active shines share a single updater.
---------------------------------------------------------------------------------------------------

local ShineUtil = {};
Engine.Modules.ShineUtil = ShineUtil;

local ACTIVE_SHINES = {};
local UPDATE_FRAME;

local SHINE_TEXTURE = "Interface\\Cooldown\\star4";
local DEFAULT_SHINE_SIZE = 10;
local DEFAULT_SHINE_EDGE_DURATION = 2.5;
local DEFAULT_SHINE_SPEED = 1.0;

local function RemoveActiveShine(shine)
	for index = 1, #ACTIVE_SHINES do
		if ACTIVE_SHINES[index] == shine then
			tremove(ACTIVE_SHINES, index);
			return;
		end
	end
end

local function SetSparkPosition(spark, point, relativeTo, relativePoint, offsetX, offsetY)
	spark:ClearAllPoints();
	spark:SetPoint(point, relativeTo, relativePoint, offsetX, offsetY);
end

local function UpdateShine(shine, elapsed)
	local edgeDuration = DEFAULT_SHINE_EDGE_DURATION / (shine.speed or DEFAULT_SHINE_SPEED);
	local duration = edgeDuration * 4;

	shine.timer = shine.timer + elapsed;
	if shine.timer > duration then
		shine.timer = shine.timer - duration;
	end

	local width = shine:GetWidth();
	local height = shine:GetHeight();
	local timer = shine.timer;

	local spark1 = shine.spark1;
	local spark2 = shine.spark2;
	local spark3 = shine.spark3;
	local spark4 = shine.spark4;

	if timer <= edgeDuration then
		local progress = timer / edgeDuration;

		SetSparkPosition(spark1, "CENTER", shine, "TOPLEFT", progress * width, 0);
		SetSparkPosition(spark2, "CENTER", shine, "TOPRIGHT", 0, -progress * height);
		SetSparkPosition(spark3, "CENTER", shine, "BOTTOMRIGHT", -progress * width, 0);
		SetSparkPosition(spark4, "CENTER", shine, "BOTTOMLEFT", 0, progress * height);

	elseif timer <= edgeDuration * 2 then
		local progress = (timer - edgeDuration) / edgeDuration;

		SetSparkPosition(spark1, "CENTER", shine, "TOPRIGHT", 0, -progress * height);
		SetSparkPosition(spark2, "CENTER", shine, "BOTTOMRIGHT", -progress * width, 0);
		SetSparkPosition(spark3, "CENTER", shine, "BOTTOMLEFT", 0, progress * height);
		SetSparkPosition(spark4, "CENTER", shine, "TOPLEFT", progress * width, 0);

	elseif timer <= edgeDuration * 3 then
		local progress = (timer - edgeDuration * 2) / edgeDuration;

		SetSparkPosition(spark1, "CENTER", shine, "BOTTOMRIGHT", -progress * width, 0);
		SetSparkPosition(spark2, "CENTER", shine, "BOTTOMLEFT", 0, progress * height);
		SetSparkPosition(spark3, "CENTER", shine, "TOPLEFT", progress * width, 0);
		SetSparkPosition(spark4, "CENTER", shine, "TOPRIGHT", 0, -progress * height);

	else
		local progress = (timer - edgeDuration * 3) / edgeDuration;

		SetSparkPosition(spark1, "CENTER", shine, "BOTTOMLEFT", 0, progress * height);
		SetSparkPosition(spark2, "CENTER", shine, "TOPLEFT", progress * width, 0);
		SetSparkPosition(spark3, "CENTER", shine, "TOPRIGHT", 0, -progress * height);
		SetSparkPosition(spark4, "CENTER", shine, "BOTTOMRIGHT", -progress * width, 0);
	end
end

local function EnsureUpdater()
	if UPDATE_FRAME then
		return;
	end

	UPDATE_FRAME = CreateFrame("Frame");
	UPDATE_FRAME:Hide();

	UPDATE_FRAME:SetScript("OnUpdate", function(_, elapsed)
		for index = 1, #ACTIVE_SHINES do
			UpdateShine(ACTIVE_SHINES[index], elapsed);
		end
	end);
end

local function CreateSpark(parent)
	local spark = parent:CreateTexture(nil, "OVERLAY");
	spark:SetTexture(SHINE_TEXTURE);
	spark:SetSize(DEFAULT_SHINE_SIZE, DEFAULT_SHINE_SIZE);
	spark:SetBlendMode("ADD");
	spark:SetAlpha(0.9);
	spark:Hide();

	return spark;
end

function ShineUtil:CreateGlow(parent)
	local shine = CreateFrame("Frame", nil, parent);
	shine:SetAllPoints(parent);
	shine:SetFrameLevel(parent:GetFrameLevel() + 6);
	shine:Hide();

	shine.timer = 0;
	shine.active = false;
	shine.speed = DEFAULT_SHINE_SPEED;
	shine.sparkSize = DEFAULT_SHINE_SIZE;

	shine.spark1 = CreateSpark(shine);
	shine.spark2 = CreateSpark(shine);
	shine.spark3 = CreateSpark(shine);
	shine.spark4 = CreateSpark(shine);

	return shine;
end

function ShineUtil:SetOptions(shine, sparkSize, speed)
	sparkSize = sparkSize or DEFAULT_SHINE_SIZE;
	speed = speed or DEFAULT_SHINE_SPEED;

	if sparkSize <= 0 then
		sparkSize = DEFAULT_SHINE_SIZE;
	end

	if speed <= 0 then
		speed = DEFAULT_SHINE_SPEED;
	end

	if shine.sparkSize ~= sparkSize then
		shine.sparkSize = sparkSize;
		shine.spark1:SetSize(sparkSize, sparkSize);
		shine.spark2:SetSize(sparkSize, sparkSize);
		shine.spark3:SetSize(sparkSize, sparkSize);
		shine.spark4:SetSize(sparkSize, sparkSize);
	end

	shine.speed = speed;
end

function ShineUtil:SetColor(shine, r, g, b)
	if not r then
		r, g, b = 1, 1, 1;
	end

	shine.spark1:SetVertexColor(r, g, b);
	shine.spark2:SetVertexColor(r, g, b);
	shine.spark3:SetVertexColor(r, g, b);
	shine.spark4:SetVertexColor(r, g, b);
end

function ShineUtil:StartAnim(shine, r, g, b, sparkSize, speed)
	self:SetOptions(shine, sparkSize, speed);

	if shine.active then
		self:SetColor(shine, r, g, b);
		return;
	end

	EnsureUpdater();

	shine.timer = 0;
	shine.active = true;

	self:SetColor(shine, r, g, b);

	shine:Show();
	shine.spark1:Show();
	shine.spark2:Show();
	shine.spark3:Show();
	shine.spark4:Show();

	tinsert(ACTIVE_SHINES, shine);
	UpdateShine(shine, 0);

	UPDATE_FRAME:Show();

	-- RepairGameTooltipMethods() -- sonations;
end

function ShineUtil:StopAnim(shine)
	if not shine.active then
		return;
	end

	shine.active = false;

	shine.spark1:Hide();
	shine.spark2:Hide();
	shine.spark3:Hide();
	shine.spark4:Hide();
	shine:Hide();

	RemoveActiveShine(shine);

	if #ACTIVE_SHINES == 0 and UPDATE_FRAME then
		UPDATE_FRAME:Hide();
	end
end