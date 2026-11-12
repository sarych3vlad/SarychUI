-- Global enabled state
CheeseEnabled = CheeseEnabled ~= false;

-- Function to check if addon is enabled
local function IsEnabled()
	if CheeseEnabled == false then return false end
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.Cheese then
		return SarychUI.db.profile.addons.Cheese.enabled ~= false;
	end
	return CheeseEnabled;
end

local band = bit.band;
local CreateFrame = CreateFrame;
local GetActionInfo = GetActionInfo;
local lshift = bit.lshift;
local next = next;
local OVERLAY_GLOW_SPELL_MAP = CHEESE_OVERLAY_GLOW_SPELL_MAP;
local OVERLAY_GLOW_SPELL_TABLE = CHEESE_OVERLAY_GLOW_SPELL_TABLE;
local OVERLAY_MAP = CHEESE_OVERLAY_MAP;
local OVERLAY_TABLE = CHEESE_OVERLAY_TABLE;
local OVERLAYS_UPPER_BOUND = CHEESE_OVERLAYS_UPPER_BOUND;
local pairs = pairs;
local PlayerFrame = PlayerFrame;
local rshift = bit.rshift;
local UnitBuff = UnitBuff;
local NUM_ACTION_BUTTONS = 12 * 12;
local actionButtons = {
	nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
	nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
	nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
	nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
	nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
	nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
	nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
	nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
	nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
	nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
	nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
	nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
};
local buffGlowSpells = {};
local buffs = {};
local spellsOverlayed = {};
local eventOverlayShowListeners = {};
local eventOverlayHideListeners = {};
local eventOverlayGlowShowListeners = {};
local eventOverlayGlowHideListeners = {};
local eventListeners = {
	["CHEESE_SPELL_ACTIVATION_OVERLAY_SHOW"] = eventOverlayShowListeners,
	["CHEESE_SPELL_ACTIVATION_OVERLAY_HIDE"] = eventOverlayHideListeners,
	["CHEESE_SPELL_ACTIVATION_OVERLAY_GLOW_SHOW"] = eventOverlayGlowShowListeners,
	["CHEESE_SPELL_ACTIVATION_OVERLAY_GLOW_HIDE"] = eventOverlayGlowHideListeners,
};
local eventFrame1 = CreateFrame("Frame");
local eventFrame2 = CreateFrame("Frame");

--------------------------------------------------
-- Macro action support
--------------------------------------------------

local macroSpellCache = {};
local spellNameCache = {};

local function Trim(text)
	if ( type(text) ~= "string" ) then
		return nil;
	end
	text = string.gsub(text, "^%s+", "");
	text = string.gsub(text, "%s+$", "");
	if ( text == "" ) then
		return nil;
	end
	return text;
end

local function SpellIDFromLink(link)
	if ( type(link) ~= "string" ) then
		return nil;
	end
	return tonumber(string.match(link, "spell:(%d+)"));
end

local function IsOverlaySpell(spellID)
	return spellID and OVERLAY_GLOW_SPELL_MAP()[spellID] and true or false;
end

local function FindOverlaySpellIDByName(name)
	name = Trim(name);
	if ( not name ) then
		return nil;
	end

	local cached = spellNameCache[name];
	if ( cached ~= nil ) then
		return cached or nil;
	end

	-- Links are the cheapest and most reliable way to turn a localized spell
	-- name into the global spell ID on clients that support name lookup here.
	if ( GetSpellLink ) then
		local spellID = SpellIDFromLink(GetSpellLink(name));
		if ( IsOverlaySpell(spellID) ) then
			spellNameCache[name] = spellID;
			return spellID;
		end
	end

	-- Fall back to the player's spellbook. Use its real bounds instead of a
	-- fixed 1..500 scan and keep the last matching rank (the default /cast rank).
	local found;
	local bookType = BOOKTYPE_SPELL or "spell";
	if ( GetNumSpellTabs and GetSpellTabInfo and GetSpellName ) then
		for tab = 1, (GetNumSpellTabs() or 0) do
			local _, _, offset, count = GetSpellTabInfo(tab);
			offset = offset or 0;
			count = count or 0;
			for slot = offset + 1, offset + count do
				local spellName = GetSpellName(slot, bookType);
				if ( spellName == name ) then
					local spellID = GetSpellLink and SpellIDFromLink(GetSpellLink(slot, bookType));
					if ( IsOverlaySpell(spellID) ) then
						found = spellID;
					end
				end
			end
		end
	end

	-- Some 3.3.5 clients expose an incomplete spellbook API. The Cheese data
	-- already contains every eligible action spell, so it is a safe final index.
	if ( not found and GetSpellInfo ) then
		for spellID in pairs(OVERLAY_GLOW_SPELL_MAP()) do
			if ( GetSpellInfo(spellID) == name ) then
				found = spellID;
				break;
			end
		end
	end

	spellNameCache[name] = found or false;
	return found;
end

local function ResolveMacroToken(text, isSequence)
	text = Trim(text);
	if ( not text ) then
		return nil;
	end

	if ( isSequence ) then
		text = string.gsub(text, "^reset=[^%s]+%s+", "");
	end

	-- Try every conditional branch. GetMacroSpell handles the active branch on
	-- clients that provide it; this fallback chooses the first Cheese spell.
	for branch in string.gmatch(text, "[^;]+") do
		local candidate = Trim(branch);
		while candidate and string.match(candidate, "^%b[]") do
			candidate = Trim(string.gsub(candidate, "^%b[]%s*", "", 1));
		end
		if ( candidate ) then
			candidate = string.gsub(candidate, "^!", "");
			if ( not isSequence ) then
				local spellID = FindOverlaySpellIDByName(candidate);
				if ( spellID ) then
					return spellID;
				end
			else
				for token in string.gmatch(candidate, "[^,]+") do
					local spellID = FindOverlaySpellIDByName(Trim(token));
					if ( spellID ) then
						return spellID;
					end
				end
			end
		end
	end
	return nil;
end

function Cheese_ResolveMacroSpellID(macroID)
	if ( not macroID ) then
		return nil;
	end

	-- Prefer the client resolver: unlike text parsing it understands the active
	-- conditional branch. Do not cache this result: target, stance or modifier
	-- changes can select a different branch without firing UPDATE_MACROS.
	-- Different backports return either an ID or a name.
	if ( GetMacroSpell ) then
		local ok, macroSpell = pcall(GetMacroSpell, macroID);
		if ( ok and type(macroSpell) == "number" and IsOverlaySpell(macroSpell) ) then
			return macroSpell;
		elseif ( ok and type(macroSpell) == "string" ) then
			local spellID = FindOverlaySpellIDByName(macroSpell);
			if ( spellID ) then
				return spellID;
			end
		end
	end

	local cached = macroSpellCache[macroID];
	if ( cached ~= nil ) then
		return cached or nil;
	end

	local body;
	if ( GetMacroInfo ) then
		local _, _, macroBody = GetMacroInfo(macroID);
		body = macroBody;
	end
	if ( body ) then
		-- An explicit tooltip describes the action the player expects to glow.
		for line in string.gmatch(body, "[^\r\n]+") do
			local tooltip = string.match(line, "^%s*#showtooltip%s+(.+)$");
			local spellID = tooltip and ResolveMacroToken(tooltip, false);
			if ( spellID ) then
				macroSpellCache[macroID] = spellID;
				return spellID;
			end
		end

		-- Prefer cast commands over /use so stance/item setup lines do not mask
		-- the proc-consuming spell later in the macro.
		for pass = 1, 2 do
			for line in string.gmatch(body, "[^\r\n]+") do
				local command, payload = string.match(line, "^%s*/([%a]+)%s+(.+)$");
				command = command and string.lower(command);
				local isSequence = command == "castsequence" or command == "castrandom";
				local wanted = pass == 1 and (command == "cast" or isSequence) or pass == 2 and command == "use";
				local spellID = wanted and ResolveMacroToken(payload, isSequence);
				if ( spellID ) then
					macroSpellCache[macroID] = spellID;
					return spellID;
				end
			end
		end
	end

	macroSpellCache[macroID] = false;
	return nil;
end

function Cheese_GetActionSpellID(action)
	local actionType, id, _, globalID = GetActionInfo(action);
	if ( actionType == "spell" ) then
		return globalID;
	elseif ( actionType == "macro" ) then
		return Cheese_ResolveMacroSpellID(id);
	end
	return nil;
end

local function ClearMacroSpellCaches(clearNames)
	wipe(macroSpellCache);
	if ( clearNames ) then
		wipe(spellNameCache);
	end
end

local function AddOverlayGlow(globalID)
	local overlayedCount = spellsOverlayed[globalID];
	if ( not overlayedCount ) then
		spellsOverlayed[globalID] = 1;
		for frame, func in pairs(eventOverlayGlowShowListeners) do
			func(frame, globalID);
		end
	else
		spellsOverlayed[globalID] = overlayedCount + 1;
	end
end

local function RemoveOverlayGlow(globalID)
	local overlayedCount = spellsOverlayed[globalID];
	if ( overlayedCount == 1 ) then
		spellsOverlayed[globalID] = nil;
		for frame, func in pairs(eventOverlayGlowHideListeners) do
			func(frame, globalID);
		end
	else
		spellsOverlayed[globalID] = overlayedCount - 1;
	end
end

local function SetAction(action, globalID)
	actionButtons[action] = globalID;
	if ( globalID ) then
		local glowSpellK = OVERLAY_GLOW_SPELL_MAP()[globalID];
		if ( glowSpellK ) then
			local overlayGlowSpellTable = OVERLAY_GLOW_SPELL_TABLE();
			local spellID = overlayGlowSpellTable[glowSpellK];
			repeat
				local glowSpells = buffGlowSpells[spellID];
				if ( not glowSpells ) then
					buffGlowSpells[spellID] = {
						[globalID] = 1;
					};
					if ( buffs[spellID] ) then
						AddOverlayGlow(globalID);
					end
				else
					local refCount = glowSpells[globalID];
					if ( not refCount ) then
						glowSpells[globalID] = 1;
						if ( buffs[spellID] ) then
							AddOverlayGlow(globalID);
						end
					else
						glowSpells[globalID] = refCount + 1;
					end
				end
				glowSpellK = glowSpellK + 1;
				spellID = overlayGlowSpellTable[glowSpellK];
			until not spellID
		end
	end
end

local function ChangeAction(action, newGlobalID)
	local globalID = actionButtons[action];
	if ( globalID ) then
		local glowSpellK = OVERLAY_GLOW_SPELL_MAP()[globalID];
		if ( glowSpellK ) then
			local overlayGlowSpellTable = OVERLAY_GLOW_SPELL_TABLE();
			local spellID = overlayGlowSpellTable[glowSpellK];
			repeat
				local glowSpells = buffGlowSpells[spellID];
				local refCount = glowSpells[globalID];
				if ( refCount == 1 ) then
					glowSpells[globalID] = nil;
					if ( next(glowSpells) == nil ) then
						glowSpells = nil;
						buffGlowSpells[spellID] = nil;
					end
					if ( buffs[spellID] ) then
						RemoveOverlayGlow(globalID);
					end
				else
					glowSpells[globalID] = refCount - 1;
				end
				glowSpellK = glowSpellK + 1;
				spellID = overlayGlowSpellTable[glowSpellK];
			until not spellID
		end
	end
	SetAction(action, newGlobalID);
end

local function ShowSpellOverlay(spellID, k, overlayTable)
	if ( k < OVERLAYS_UPPER_BOUND ) then
		local texture = "Interface\\AddOns\\SarychUI\\media\\components\\extensions\\modern_features\\spell_alerts\\Textures\\SpellActivationOverlays\\"..overlayTable[k + 1];
		local positions = overlayTable[k + 2];
		local scale = overlayTable[k + 3];
		local vertexColor = overlayTable[k + 4];
		local r = rshift(lshift(vertexColor, 8), 24);
		local g = rshift(lshift(vertexColor, 16), 24);
		local b = band(vertexColor, 0xff);
		for frame, func in pairs(eventOverlayShowListeners) do
			func(frame, spellID, texture, positions, scale, r, g, b);
		end
	end
end

local function BuffGained(spellID, k, overlayTable)
	if not IsEnabled() then
		return;
	end
	ShowSpellOverlay(spellID, k, overlayTable);
	local glowSpells = buffGlowSpells[spellID];
	if ( glowSpells ) then
		for globalID in pairs(glowSpells) do
			AddOverlayGlow(globalID);
		end
	end
end

local function BuffLost(spellID)
	if not IsEnabled() then
		return;
	end
	for frame, func in pairs(eventOverlayHideListeners) do
		func(frame, spellID);
	end
	local glowSpells = buffGlowSpells[spellID];
	if ( glowSpells ) then
		for globalID in pairs(glowSpells) do
			RemoveOverlayGlow(globalID);
		end
	end
end

local function eventFrame1_OnEventActionbarSlotChanged(self, event, action)
	local refreshButtons = event == "UPDATE_MACROS" or event == "SPELLS_CHANGED";
	if ( event == "UPDATE_MACROS" ) then
		ClearMacroSpellCaches(false);
		action = 0;
	elseif ( event == "SPELLS_CHANGED" ) then
		ClearMacroSpellCaches(true);
		action = 0;
	end
	if not IsEnabled() then
		return;
	end
	if ( not action or action == 0 ) then
		for action=1, NUM_ACTION_BUTTONS do
			local globalID = Cheese_GetActionSpellID(action);
			if ( actionButtons[action] ~= globalID ) then
				ChangeAction(action, globalID);
			end
		end
	else
		local globalID = Cheese_GetActionSpellID(action);
		if ( actionButtons[action] ~= globalID ) then
			ChangeAction(action, globalID);
		end
	end
	if ( refreshButtons and CheeseActionButton_RefreshAll ) then
		CheeseActionButton_RefreshAll();
	end
end

function Cheese_RefreshActionMappings()
	ClearMacroSpellCaches(false);
	eventFrame1_OnEventActionbarSlotChanged(eventFrame1, "UPDATE_MACROS", 0);
end

local function eventFrame2_OnEventUnitAura(self, event, unitID)
	if not IsEnabled() then
		return;
	end
	local unit = PlayerFrame.unit;
	if ( unitID == unit ) then
		do
			local name, _, _, count, _, _, _, _, _, _, spellID = UnitBuff(unit, 1);
			if ( name ) then
				local overlayMap = OVERLAY_MAP();
				local overlayTable;
				local j = 1;
				repeat
					local k = overlayMap[spellID];
					if ( k ) then
						if ( not overlayTable ) then
							overlayTable = OVERLAY_TABLE();
						end
						if ( not (count < overlayTable[k]) ) then
							local hasBuff = buffs[spellID];
							buffs[spellID] = false;
							if ( hasBuff == nil ) then
								BuffGained(spellID, k, overlayTable);
							end
						end
					end
					j=j+1;
					name, _, _, count, _, _, _, _, _, _, spellID = UnitBuff(unit, j);
				until not name
			end
		end
		for spellID, hasBuff in pairs(buffs) do
			if ( not hasBuff ) then
				buffs[spellID] = true;
			else
				buffs[spellID] = nil;
				BuffLost(spellID);
			end
		end
	end
end

local function eventFrame1_OnEventPlayerLogin(self)
	eventFrame1:UnregisterEvent("PLAYER_LOGIN");
	eventFrame1:SetScript("OnEvent", eventFrame1_OnEventActionbarSlotChanged);
	eventFrame1:RegisterEvent("ACTIONBAR_SLOT_CHANGED");
	eventFrame1:RegisterEvent("UPDATE_MACROS");
	eventFrame1:RegisterEvent("SPELLS_CHANGED");
	eventFrame2:SetScript("OnEvent", eventFrame2_OnEventUnitAura);
	eventFrame2:RegisterEvent("UNIT_AURA");
	if not IsEnabled() then
		return;
	end
	do
		for action=1, NUM_ACTION_BUTTONS do
			local globalID = Cheese_GetActionSpellID(action);
			if ( globalID ) then
				SetAction(action, globalID);
			end
		end
	end
	do
		local unit = PlayerFrame.unit;
		local name, _, _, count, _, _, _, _, _, _, spellID = UnitBuff(unit, 1);
		if ( name ) then
			local overlayMap = OVERLAY_MAP();
			local overlayTable;
			local j = 1;
			repeat
				local k = overlayMap[spellID];
				if ( k ) then
					if ( not overlayTable ) then
						overlayTable = OVERLAY_TABLE();
					end
					if ( not (count < overlayTable[k]) ) then
						buffs[spellID] = true;
						BuffGained(spellID, k, overlayTable);
					end
				end
				j=j+1;
				name, _, _, count, _, _, _, _, _, _, spellID = UnitBuff(unit, j);
			until not name
		end
	end
end

function Cheese_SetRuntimeEnabled(enable)
    eventFrame1:UnregisterAllEvents()
    eventFrame2:UnregisterAllEvents()
    if enable then eventFrame1_OnEventPlayerLogin(eventFrame1) end
end

function Cheese_RefreshAuras()
	if IsEnabled() and eventFrame2:IsEventRegistered("UNIT_AURA") then
		eventFrame2_OnEventUnitAura(eventFrame2, "UNIT_AURA", PlayerFrame.unit);
	end
end

function Cheese_RefreshSpellOverlays()
	if not IsEnabled() then return end
	local overlayMap = OVERLAY_MAP();
	local overlayTable = OVERLAY_TABLE();
	for spellID in pairs(buffs) do
		local k = overlayMap[spellID];
		if k then
			ShowSpellOverlay(spellID, k, overlayTable);
		end
	end
end

function Cheese_ClearRuntime()
	for spellID in pairs(buffs) do
		for frame, func in pairs(eventOverlayHideListeners) do
			func(frame, spellID);
		end
		buffs[spellID] = nil;
	end
	for globalID in pairs(spellsOverlayed) do
		for frame, func in pairs(eventOverlayGlowHideListeners) do
			func(frame, globalID);
		end
		spellsOverlayed[globalID] = nil;
	end
	wipe(buffGlowSpells);
	wipe(actionButtons);
end

function Cheese_IsSpellOverlayed(spellID)
	return spellsOverlayed[spellID] and true or false;
end

function Cheese_RegisterEvent(event, frame, func)
	local listeners = eventListeners[event];
	if ( listeners ) then
		listeners[frame] = func;
	end
end

function Cheese_UnregisterEvent(event, frame)
	local listeners = eventListeners[event];
	if ( listeners ) then
		listeners[frame] = nil;
	end
end

if ( GetCVarBool("scriptProfile") ) then
	function Cheese_GetAPISpellActivationOverlayFuncs()
		return eventFrame1_OnEventPlayerLogin, eventFrame1_OnEventActionbarSlotChanged, eventFrame2_OnEventUnitAura, BuffGained, BuffLost, SetAction, ChangeAction, AddOverlayGlow, RemoveOverlayGlow;
	end
end
