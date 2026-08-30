--[[
    Equipence
    Copyright (c) 2026 s0high. All rights reserved.

    Source-available proprietary software. See LICENSE for terms.
]]

--@class Engine<ns>
local AddOnName, Engine = ...;
AddOnName = AddOnName or "Equipence";
Engine = Engine or {};
_G.EquipenceEngine = Engine;

local function IsEquipenceRuntimeAllowed()
	if EquipenceEnabled == false then
		return false;
	end
	if SarychUI_IsStandaloneEquipenceEnabled and SarychUI_IsStandaloneEquipenceEnabled() then
		return false;
	end
	return true;
end

--@natives<lua,wow>
local format = string.format;
local print = print;
local tostring = tostring;
local select = select;
local CreateFrame = CreateFrame;

--@libs<ns>
local Aegis = LibStub("Aegis-2.0");
local Options = LibStub("Aegis-Settings-1.0");
Engine.Aegis = Aegis;
Engine.Options = Options;

--@metadata<engine>
local C_AddOns = Aegis:GetNamespace("C_AddOns");

Engine.Name    = AddOnName;
Engine.Title   = C_AddOns.GetAddOnMetadata(AddOnName, "Title") or "|cff00F0FFE|rquipence";
Engine.Author  = C_AddOns.GetAddOnMetadata(AddOnName, "Author") or "s0high";
Engine.Version = C_AddOns.GetAddOnMetadata(AddOnName, "Version") or "1.0";
Engine.Notes   = C_AddOns.GetAddOnMetadata(AddOnName, "Notes") or "Detailed gear overview when inspecting characters.";
Engine.Website = C_AddOns.GetAddOnMetadata(AddOnName, "X-Website") or "https://github.com/s0h2x/Equipence";

--@namespaces<engine>
Engine.Shared  = Engine.Shared or {};
Engine.Modules = Engine.Modules or {};

--@media
local MEDIA_ROOT = SarychUI_EquipencePath or ("Interface\\AddOns\\%s\\"):format(AddOnName);
local MEDIA_PREFIX = MEDIA_ROOT .. "Media\\";

Engine.Media = Engine.Media or {
	ITEM_BORDER = MEDIA_PREFIX .. "Textures\\WhiteIconFrame",
	ROUND_BORDER = MEDIA_PREFIX .. "Textures\\Icon-RoundBorder",
	ROUND_SOCKET_BACKDROP = MEDIA_PREFIX .. "Textures\\Icon-RoundBackdrop",
};

--@debug<engine>
local LOG_PREFIX = AddOnName .. " \194\187 ";

Engine.Debug = false; -- enable locally when debugging

function Engine:Log(msg, ...)
	if select("#", ...) > 0 then
		print(LOG_PREFIX .. format(msg, ...));
	else
		print(LOG_PREFIX .. tostring(msg));
	end
end

function Engine:DebugLog(msg, ...)
	if self.Debug then
		self:Log("|cff804a00[DEBUG]|r " .. msg, ...);
	end
end

Aegis:SetLogger({
	Log = function(level, msg, ...)
		local prefix = "|cff33ccff[Aegis:" .. level .. "]|r " .. msg;
		if level == "DEBUG" then
			Engine:DebugLog(prefix, ...);
		else
			Engine:Log(prefix, ...);
		end
	end
});

Aegis:SetDebugEnabled(Engine.Debug);

local function InitEquipenceDatabase()
	if Engine._suiDbInit then
		return true;
	end
	if not Engine.Localization or not Engine.Database then
		return false;
	end
	Engine.Localization:Init();
	Engine.Database:Init();
	Engine._suiDbInit = true;
	return true;
end

local function InitEquipenceControllers()
	if Engine._suiControllersInit then
		return true;
	end
	if not Engine.Controllers or not Engine.SettingsController or not Engine.SettingsDefinitions then
		return false;
	end
	Engine.Controllers:Init();
	Engine.SettingsController:Init(Engine.Controllers.CharacterController, Engine.SettingsDefinitions);
	Engine._suiControllersInit = true;
	return true;
end

function SarychUI_InitEmbeddedEquipence()
	if not IsEquipenceRuntimeAllowed() then
		return false, "disabled";
	end
	if not InitEquipenceDatabase() then
		return false, "no_database";
	end
	-- Controllers need PLAYER_LOGIN-level UI; allow after login or when already logged in.
	if not IsLoggedIn or not IsLoggedIn() then
		Engine._suiPendingControllers = true;
		return true, "db_only";
	end
	if not InitEquipenceControllers() then
		return false, "no_controllers";
	end
	return true, "loaded";
end

--@initializing<addon>
local EngineLoader = CreateFrame("Frame");
EngineLoader:SetScript("OnEvent", function(self, event, name)
	if event == "ADDON_LOADED" and (name == AddOnName or name == "SarychUI") then
		if IsEquipenceRuntimeAllowed() then
			InitEquipenceDatabase();
		end
	elseif event == "PLAYER_LOGIN" then
		if IsEquipenceRuntimeAllowed() or Engine._suiPendingControllers then
			if IsEquipenceRuntimeAllowed() then
				InitEquipenceDatabase();
				InitEquipenceControllers();
			end
		end
		Engine._suiPendingControllers = nil;
		self:UnregisterAllEvents();
		self:SetScript("OnEvent", nil);
	end
end);

EngineLoader:RegisterEvent("ADDON_LOADED");
EngineLoader:RegisterEvent("PLAYER_LOGIN");
