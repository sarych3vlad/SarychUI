
-------------------------------------------------------------------------------
--                        GearScoreLite: Reborn                              --
--                             Version 3x05                                  --
--               Mirrikat45 & Gnomezilla [Warmane-Icecrown(A)]               --
--              https://github.com/Arcitec/GearScoreLite_Reborn              --
-------------------------------------------------------------------------------

--Change Log 3x05
--See git commit history for full details.
--fix: larger GS font size for personal character's window
--feat: add support for "must target" mode
--fix: remove nonsensical check for combat state
--fix: initialize combat tracker state on startup
--fix: remove braindead enchant score algorithm
--feat: add support for ElvUI, Shadowed and VuhDo unit frames
--fix: don't calculate GearScore while inspect window open
--fix: properly apply default settings for "false" values

--Change Log 3x04
--Fixed an error with GS less over 6000.
--GS will now be reduced on un-enchanted items that are enchantable. 
--Remember that gems are always shown as empty by initial API calls so I cant determine if gems are missing or not.

------------------------------------------------------------------------------

-- Global enabled state
GearScoreLiteEnabled = GearScoreLiteEnabled or true;

-- Function to check if addon is enabled
local function IsEnabled()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.GearScoreLite then
		return SarychUI.db.profile.addons.GearScoreLite.enabled ~= false;
	end
	return GearScoreLiteEnabled;
end

local GS_PlayerIsInCombat = false

local DEBUG_PERF = false
local GS_SetInventoryItemPerf = { calls = 0, notify = 0, skippedInspect = 0, disabled = 0 }
local GS_INSPECT_GLOBAL_INTERVAL = 1.50
local GS_INSPECT_UNIT_INTERVAL = 10.00
local GS_LastInspectAt = 0
local GS_LastInspectByUnit = {}
local GS_TOOLTIP_DUPLICATE_WINDOW = 0.08
local GS_LastInventoryTooltipKey = nil
local GS_LastInventoryTooltipAt = 0
local GS_LastInventoryTooltipReturn1 = nil
local GS_LastInventoryTooltipReturn2 = nil
local GS_LastInventoryTooltipReturn3 = nil

local function GearScore_DebugPerf(startMs, reason, unit, slot)
	if not DEBUG_PERF then
		return
	end
	GS_SetInventoryItemPerf.calls = GS_SetInventoryItemPerf.calls + 1
	local elapsed = debugprofilestop and (debugprofilestop() - startMs) or 0
	print(string.format(
		"GearScoreLitePerf SetInventoryItem calls=%d notify=%d skippedInspect=%d disabled=%d reason=%s unit=%s slot=%s %.3fms",
		GS_SetInventoryItemPerf.calls,
		GS_SetInventoryItemPerf.notify,
		GS_SetInventoryItemPerf.skippedInspect,
		GS_SetInventoryItemPerf.disabled,
		tostring(reason or "?"),
		tostring(unit or "?"),
		tostring(slot or "?"),
		elapsed
	))
end

------------------------------------------------------------------------------

local function GearScore_ShouldNotifyInspect(unit)
	if not unit or not CanInspect(unit) then
		return false
	end

	local now = GetTime and GetTime() or 0
	local key = UnitGUID(unit) or UnitName(unit) or unit
	local lastUnit = GS_LastInspectByUnit[key] or 0

	if (now - GS_LastInspectAt) < GS_INSPECT_GLOBAL_INTERVAL then
		return false
	end
	if (now - lastUnit) < GS_INSPECT_UNIT_INTERVAL then
		return false
	end

	GS_LastInspectAt = now
	GS_LastInspectByUnit[key] = now
	return true
end

local function GearScore_NotifyInspectThrottled(unit)
	if GearScore_ShouldNotifyInspect(unit) then
		if SarychUI_PerfLog then
			SarychUI_PerfLog("GearScoreLite", "NotifyInspect", unit)
		end
		NotifyInspect(unit)
		return true
	end
	return false
end

function GearScore_OnEvent(GS_Nil, GS_EventName, GS_Prefix, GS_AddonMessage, GS_Whisper, GS_Sender)
	if not IsEnabled() then
		return;
	end
	if ( GS_EventName == "PLAYER_REGEN_ENABLED" ) then GS_PlayerIsInCombat = false; return; end
	if ( GS_EventName == "PLAYER_REGEN_DISABLED" ) then GS_PlayerIsInCombat = true; return; end
	if ( GS_EventName == "PLAYER_EQUIPMENT_CHANGED" ) then
	    local MyGearScore = GearScore_GetScore(UnitName("player"), "player");
		local Red, Blue, Green = GearScore_GetQuality(MyGearScore)
    	PersonalGearScore:SetText(MyGearScore); PersonalGearScore:SetTextColor(Red, Green, Blue, 1)
  	end
	if ( GS_EventName == "ADDON_LOADED" ) then
		if ( GS_Prefix == "GearScoreLite" ) then
      		if not ( GS_Settings ) then	GS_Settings = GS_DefaultSettings end
			if not ( GS_Data ) then GS_Data = {}; end; if not ( GS_Data[GetRealmName()] ) then GS_Data[GetRealmName()] = { ["Players"] = {} }; end
  			for i, v in pairs(GS_DefaultSettings) do if ( GS_Settings[i] == nil ) then GS_Settings[i] = GS_DefaultSettings[i]; end; end
        end
	end
end
-------------------------- Get Mouseover Score -----------------------------------
function GearScore_GetScore(Name, Target)
	if not IsEnabled() then
		return 0, 0;
	end
	if ( UnitIsPlayer(Target) ) then
	    local PlayerClass, PlayerEnglishClass = UnitClass(Target);
		local GearScore = 0; local PVPScore = 0; local ItemCount = 0; local LevelTotal = 0; local TitanGrip = 1; local TempEquip = {}; local TempPVPScore = 0

		if ( GetInventoryItemLink(Target, 16) ) and ( GetInventoryItemLink(Target, 17) ) then
      		local ItemName, ItemLink, ItemRarity, ItemLevel, ItemMinLevel, ItemType, ItemSubType, ItemStackCount, ItemEquipLoc, ItemTexture = GetItemInfo(GetInventoryItemLink(Target, 16))
            if ( ItemEquipLoc == "INVTYPE_2HWEAPON" ) then TitanGrip = 0.5; end
		end

		if ( GetInventoryItemLink(Target, 17) ) then
			local ItemName, ItemLink, ItemRarity, ItemLevel, ItemMinLevel, ItemType, ItemSubType, ItemStackCount, ItemEquipLoc, ItemTexture = GetItemInfo(GetInventoryItemLink(Target, 17))
			if ( ItemEquipLoc == "INVTYPE_2HWEAPON" ) then TitanGrip = 0.5; end
			TempScore, ItemLevel = GearScore_GetItemScore(GetInventoryItemLink(Target, 17));
			if ( PlayerEnglishClass == "HUNTER" ) then TempScore = TempScore * 0.3164; end
			GearScore = GearScore + TempScore * TitanGrip;	ItemCount = ItemCount + 1; LevelTotal = LevelTotal + ItemLevel
		end
		
		for i = 1, 18 do
			if ( i ~= 4 ) and ( i ~= 17 ) then
        		ItemLink = GetInventoryItemLink(Target, i)
        		GS_ItemLinkTable = {}
				if ( ItemLink ) then
        			local ItemName, ItemLink, ItemRarity, ItemLevel, ItemMinLevel, ItemType, ItemSubType, ItemStackCount, ItemEquipLoc, ItemTexture = GetItemInfo(ItemLink)
        			if ( GS_Settings["Detail"] == 1 ) then GS_ItemLinkTable[i] = ItemLink; end
     				TempScore = GearScore_GetItemScore(ItemLink);
					if ( i == 16 ) and ( PlayerEnglishClass == "HUNTER" ) then TempScore = TempScore * 0.3164; end
					if ( i == 18 ) and ( PlayerEnglishClass == "HUNTER" ) then TempScore = TempScore * 5.3224; end
					if ( i == 16 ) then TempScore = TempScore * TitanGrip; end
					GearScore = GearScore + TempScore;	ItemCount = ItemCount + 1; LevelTotal = LevelTotal + ItemLevel
				end
			end;
		end
		if ( GearScore <= 0 ) and ( Name ~= UnitName("player") ) then
			GearScore = 0; return 0,0;
		elseif ( Name == UnitName("player") ) and ( GearScore <= 0 ) then
		    GearScore = 0; end
	if ( ItemCount == 0 ) then LevelTotal = 0; end		    
	return floor(GearScore), floor(LevelTotal/ItemCount)
	end
end

-------------------------------------------------------------------------------

function GearScore_GetEnchantInfo(ItemLink, ItemEquipLoc)
	local found, _, ItemSubString = string.find(ItemLink, "^|c%x+|H(.+)|h%[.*%]");
	local ItemSubStringTable = {}

	for v in string.gmatch(ItemSubString, "[^:]+") do tinsert(ItemSubStringTable, v); end
	ItemSubString = ItemSubStringTable[2]..":"..ItemSubStringTable[3], ItemSubStringTable[2]
	local StringStart, StringEnd = string.find(ItemSubString, ":") 
	ItemSubString = string.sub(ItemSubString, StringStart + 1)
	if ( ItemSubString == "0" ) and ( GS_ItemTypes[ItemEquipLoc]["Enchantable"] ) then
		-- NOTE: The algorithm below is batshit insane and totally broken. It
		-- should be completely rewritten if anyone ever wants to enable it again.
		--table.insert(MissingEnchantTable, ItemEquipLoc)
		local percent = ( floor((-2 * ( GS_ItemTypes[ItemEquipLoc]["SlotMOD"] )) * 100) / 100 );
		return ( 1 + (percent / 100) );
	else
		return 1;
	end
end						


------------------------------ Get Item Score ---------------------------------
function GearScore_GetItemScore(ItemLink)
	local QualityScale = 1; local PVPScale = 1; local PVPScore = 0; local GearScore = 0
	if not ( ItemLink ) then return 0, 0; end
	local ItemName, ItemLink, ItemRarity, ItemLevel, ItemMinLevel, ItemType, ItemSubType, ItemStackCount, ItemEquipLoc, ItemTexture = GetItemInfo(ItemLink); local Table = {}; local Scale = 1.8618
 	if ( ItemRarity == 5 ) then QualityScale = 1.3; ItemRarity = 4;
	elseif ( ItemRarity == 1 ) then QualityScale = 0.005;  ItemRarity = 2
	elseif ( ItemRarity == 0 ) then QualityScale = 0.005;  ItemRarity = 2 end
    if ( ItemRarity == 7 ) then ItemRarity = 3; ItemLevel = 187.05; end
    if ( GS_ItemTypes[ItemEquipLoc] ) then
        if ( ItemLevel > 120 ) then Table = GS_Formula["A"]; else Table = GS_Formula["B"]; end
		if ( ItemRarity >= 2 ) and ( ItemRarity <= 4 )then
            local Red, Green, Blue = GearScore_GetQuality((floor(((ItemLevel - Table[ItemRarity].A) / Table[ItemRarity].B) * 1 * Scale)) * 11.25 )
            GearScore = floor(((ItemLevel - Table[ItemRarity].A) / Table[ItemRarity].B) * GS_ItemTypes[ItemEquipLoc].SlotMOD * Scale * QualityScale)
			if ( ItemLevel == 187.05 ) then ItemLevel = 0; end
			if ( GearScore < 0 ) then GearScore = 0;   Red, Green, Blue = GearScore_GetQuality(1); end
			if ( PVPScale == 0.75 ) then PVPScore = 1; GearScore = GearScore * 1; 
			else PVPScore = GearScore * 0; end
			local percent = 1
			if ( GS_Settings["IncludeEnchants"] ) then
				-- Reduce GearScore value if enchantable items are missing enchants.
				percent = (GearScore_GetEnchantInfo(ItemLink, ItemEquipLoc) or 1)
				GearScore = floor(GearScore * percent)
			end
			PVPScore = floor(PVPScore)
			return GearScore, ItemLevel, GS_ItemTypes[ItemEquipLoc].ItemSlot, Red, Green, Blue, PVPScore, ItemEquipLoc, percent
		end
  	end
  	return -1, ItemLevel, 50, 1, 1, 1, PVPScore, ItemEquipLoc, 1
end
-------------------------------------------------------------------------------

-------------------------------- Get Quality ----------------------------------

function GearScore_GetQuality(ItemScore)
	if ( ItemScore > 5999 ) then ItemScore = 5999; end
	local Red = 0.1; local Blue = 0.1; local Green = 0.1; local GS_QualityDescription = "Legendary"
   	if not ( ItemScore ) then return 0, 0, 0, "Trash"; end
	for i = 0,6 do
		if ( ItemScore > i * 1000 ) and ( ItemScore <= ( ( i + 1 ) * 1000 ) ) then
		    local Red = GS_Quality[( i + 1 ) * 1000].Red["A"] + (((ItemScore - GS_Quality[( i + 1 ) * 1000].Red["B"])*GS_Quality[( i + 1 ) * 1000].Red["C"])*GS_Quality[( i + 1 ) * 1000].Red["D"])
            local Blue = GS_Quality[( i + 1 ) * 1000].Green["A"] + (((ItemScore - GS_Quality[( i + 1 ) * 1000].Green["B"])*GS_Quality[( i + 1 ) * 1000].Green["C"])*GS_Quality[( i + 1 ) * 1000].Green["D"])
            local Green = GS_Quality[( i + 1 ) * 1000].Blue["A"] + (((ItemScore - GS_Quality[( i + 1 ) * 1000].Blue["B"])*GS_Quality[( i + 1 ) * 1000].Blue["C"])*GS_Quality[( i + 1 ) * 1000].Blue["D"])
			--if not ( Red ) or not ( Blue ) or not ( Green ) then return 0.1, 0.1, 0.1, nil; end
			return Red, Green, Blue, GS_Quality[( i + 1 ) * 1000].Description
		end
	end
return 0.1, 0.1, 0.1
end
-------------------------------------------------------------------------------

----------------------------- Hook Set Unit -----------------------------------
function GearScore_HookSetUnit(arg1, arg2)
	local perfStart = SarychUI_PerfDebug and SarychUI_PerfNow and SarychUI_PerfNow() or nil
	if not IsEnabled() then
		return;
	end
	if ( GS_PlayerIsInCombat ) then return; end
	if SarychUI_PerfLog then
		SarychUI_PerfLog("GearScoreLite", "OnTooltipSetUnit", GameTooltip and GameTooltip.GetUnit and GameTooltip:GetUnit() or nil)
	end

	-- We will refuse to trigger the unit inspect code while an inspection frame
	-- is open. Otherwise it would switch the current inspect window's talents.
	-- NOTE: `NotifyInspect()` is responsible for messing up the inspect frame.
	if ( InspectFrame and InspectFrame:IsShown() ) or ( Examiner and Examiner:IsShown() ) then
		return
	end

	-- Fetch the current tooltip's unit name.
	local Name = GameTooltip:GetUnit()
	local MouseOverGearScore, MouseOverAverage = 0, 0

	-- Attempt to inspect via Blizzard's unitframes.
	-- NOTE: This won't work for third party unitframe addons, since Blizzard's
	-- official "mouseover" API doesn't know what those other addon frames are.
	local UnitToInspect = "mouseover"

	-- Detect unit if player uses an alternative unitframe addon instead.
	-- NOTE: To detect other addons, we check for their main global variable,
	-- but we must also look for their correct `mf.` property below!
	if ( not CanInspect(UnitToInspect) ) and ( ElvUI or ShadowUF or VuhDo ) then
		-- Attempt to fetch custom unitframe, and its internal unit property.
		local mf = GetMouseFocus()
		if ( mf ) then
			UnitToInspect = mf.unit or mf.raidid or "mouseover"
		end
	end

	-- Perform the inspection and GearScore calculation.
	if ( ( not GS_Settings["MustTarget"] ) or ( UnitIsUnit("target", UnitToInspect) ) )
			and ( CanInspect(UnitToInspect) )
			and ( UnitName(UnitToInspect) == Name )
	then
		-- NOTE: The total lack of delay between "send inspect request" and
		-- "check unit's gear" is the reason why GearScoreLite sometimes has
		-- totally incorrect, partial scores, because it's basically inspecting
		-- while the gear hasn't been fully received yet. It's very tedious to
		-- fix that though. We'd have to rewrite the entire addon to use events
		-- and caching and some kind of dynamic, delayed tooltip updates, meh:
		-- https://wowwiki-archive.fandom.com/wiki/API_NotifyInspect
		GearScore_NotifyInspectThrottled(UnitToInspect)
		MouseOverGearScore, MouseOverAverage = GearScore_GetScore(Name, UnitToInspect)
	end

	-- If we've fetched a score, add it to the tooltip.
 	if ( MouseOverGearScore ) and ( MouseOverGearScore > 0 ) and ( GS_Settings["Player"] == 1 ) then
		local Red, Blue, Green = GearScore_GetQuality(MouseOverGearScore)
		if ( GS_Settings["Level"] == 1 ) then
			GameTooltip:AddDoubleLine("GearScore: "..MouseOverGearScore, "(iLevel: "..MouseOverAverage..")", Red, Green, Blue, Red, Green, Blue)
		else
			GameTooltip:AddLine("GearScore: "..MouseOverGearScore, Red, Green, Blue)
		end
		if ( GS_Settings["Compare"] == 1 ) then
			local MyGearScore = GearScore_GetScore(UnitName("player"), "player")
			local TheirGearScore = MouseOverGearScore
			if ( MyGearScore  > TheirGearScore ) then GameTooltip:AddDoubleLine("YourScore: "..MyGearScore  , "(+"..(MyGearScore - TheirGearScore  )..")", 0,1,0, 0,1,0); end
			if ( MyGearScore  < TheirGearScore ) then GameTooltip:AddDoubleLine("YourScore: "..MyGearScore, "(-"..(TheirGearScore - MyGearScore  )..")", 1,0,0, 1,0,0); end
			if ( MyGearScore == TheirGearScore ) then GameTooltip:AddDoubleLine("YourScore: "..MyGearScore  , "(+0)", 0,1,1,0,1,1); end
		end
		if ( GS_Settings["Special"] == 1 ) and ( GS_Special[Name] ) then
			GameTooltip:AddLine(GS_Special[GS_Special[Name].Type], 1, 0, 0 )
		end
	end
	if SarychUI_PerfSlow then
		SarychUI_PerfSlow("GearScoreLite", "OnTooltipSetUnitSlow", perfStart, Name, 2)
	end
end

function GearScore_SetDetails(tooltip, Name)
    if not ( UnitName("mouseover") ) or ( UnitName("mouseover") ~= Name )then return; end
  	for i = 1,18 do
  	    if not ( i == 4 ) then
    		local ItemName, ItemLink, ItemRarity, ItemLevel, ItemMinLevel, ItemType, ItemSubType, ItemStackCount, ItemEquipLoc, ItemTexture = GetItemInfo(GS_ItemLinkTable[i])
			if ( ItemLink ) then
				local GearScore, ItemLevel, ItemType, Red, Green, Blue = GearScore_GetItemScore(ItemLink)
				--local Red, Green, Blue = GearScore_GetQuality((floor(((ItemLevel - Table[ItemRarity].A) / Table[ItemRarity].B) * 1 * 1.8618)) * 11.25 )
				if ( GearScore ) and ( i ~= 4 ) then
    			   	local Add = ""
	        		if ( GS_Settings["Level"] == 1 ) then Add = " (iLevel "..tostring(ItemLevel)..")"; end
    	         	tooltip:AddDoubleLine("["..ItemName.."]", tostring(GearScore)..Add, GS_Rarity[ItemRarity].Red, GS_Rarity[ItemRarity].Green, GS_Rarity[ItemRarity].Blue, Red, Blue, Green)
        		end
			end
		end
	end
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function GearScore_HookSetItem() ItemName, ItemLink = GameTooltip:GetItem(); GearScore_HookItem(ItemName, ItemLink, GameTooltip); end
function GearScore_HookRefItem() ItemName, ItemLink = ItemRefTooltip:GetItem(); GearScore_HookItem(ItemName, ItemLink, ItemRefTooltip); end
function GearScore_HookCompareItem() ItemName, ItemLink = ShoppingTooltip1:GetItem(); GearScore_HookItem(ItemName, ItemLink, ShoppingTooltip1); end
function GearScore_HookCompareItem2() ItemName, ItemLink = ShoppingTooltip2:GetItem(); GearScore_HookItem(ItemName, ItemLink, ShoppingTooltip2); end
function GearScore_HookItem(ItemName, ItemLink, Tooltip)
	local perfStart = SarychUI_PerfDebug and SarychUI_PerfNow and SarychUI_PerfNow() or nil
	if not IsEnabled() then
		return;
	end
	if ( GS_PlayerIsInCombat ) then return; end
	if SarychUI_PerfLog then
		SarychUI_PerfLog("GearScoreLite", "OnTooltipSetItem", ItemLink)
	end
	local PlayerClass, PlayerEnglishClass = UnitClass("player");
	if not ( IsEquippableItem(ItemLink) ) then return; end
	local ItemScore, ItemLevel, EquipLoc, Red, Green, Blue, PVPScore, ItemEquipLoc, enchantPercent = GearScore_GetItemScore(ItemLink);
 	if ( ItemScore >= 0 ) then
		if ( GS_Settings["Item"] == 1 ) then
  			if ( ItemLevel ) and ( GS_Settings["Level"] == 1 ) then Tooltip:AddDoubleLine("GearScore: "..ItemScore, "(iLevel "..ItemLevel..")", Red, Blue, Green, Red, Blue, Green);
				if ( PlayerEnglishClass == "HUNTER" ) then
					if ( ItemEquipLoc == "INVTYPE_RANGEDRIGHT" ) or ( ItemEquipLoc == "INVTYPE_RANGED" ) then
						Tooltip:AddLine("HunterScore: "..floor(ItemScore * 5.3224), Red, Blue, Green)
					end
					if ( ItemEquipLoc == "INVTYPE_2HWEAPON" ) or ( ItemEquipLoc == "INVTYPE_WEAPONMAINHAND" ) or ( ItemEquipLoc == "INVTYPE_WEAPONOFFHAND" ) or ( ItemEquipLoc == "INVTYPE_WEAPON" ) or ( ItemEquipLoc == "INVTYPE_HOLDABLE" )  then
						Tooltip:AddLine("HunterScore: "..floor(ItemScore * 0.3164), Red, Blue, Green)
					end
				end
			else
				Tooltip:AddLine("GearScore: "..ItemScore, Red, Blue, Green)
				if ( PlayerEnglishClass == "HUNTER" ) then
					if ( ItemEquipLoc == "INVTYPE_RANGEDRIGHT" ) or ( ItemEquipLoc == "INVTYPE_RANGED" ) then
						Tooltip:AddLine("HunterScore: "..floor(ItemScore * 5.3224), Red, Blue, Green)
					end
					if ( ItemEquipLoc == "INVTYPE_2HWEAPON" ) or ( ItemEquipLoc == "INVTYPE_WEAPONMAINHAND" ) or ( ItemEquipLoc == "INVTYPE_WEAPONOFFHAND" ) or ( ItemEquipLoc == "INVTYPE_WEAPON" ) or ( ItemEquipLoc == "INVTYPE_HOLDABLE" )  then
						Tooltip:AddLine("HunterScore: "..floor(ItemScore * 0.3164), Red, Blue, Green)
					end
				end
    		end
--RebuildThis            if ( GS_Settings["ML"] == 1 ) then GearScore_EquipCompare(Tooltip, ItemScore, EquipLoc, ItemLink); end
  		end
	else
	    if ( GS_Settings["Level"] == 1 ) and ( ItemLevel ) then
	        Tooltip:AddLine("iLevel "..ItemLevel)
		end
    end
	if SarychUI_PerfSlow then
		SarychUI_PerfSlow("GearScoreLite", "OnTooltipSetItemSlow", perfStart, ItemLink, 2)
	end
end
function GearScore_OnEnter(Name, ItemSlot, Argument)
	local startMs = DEBUG_PERF and debugprofilestop and debugprofilestop() or 0
	local perfStart = SarychUI_PerfDebug and SarychUI_PerfNow and SarychUI_PerfNow() or nil
	local itemLink = nil
	if ItemSlot and Argument and GetInventoryItemLink then
		itemLink = GetInventoryItemLink(ItemSlot, Argument)
	end
	local itemID = nil
	if ItemSlot and Argument and GetInventoryItemID then
		itemID = GetInventoryItemID(ItemSlot, Argument)
	end
	local inventoryKey = tostring(ItemSlot) .. "/" .. tostring(Argument) .. "/" .. tostring(itemID or itemLink or "")
	local gearScoreEnabled = IsEnabled()
	local skipDuplicateWork = false
	if gearScoreEnabled and (itemID or itemLink) then
		local now = GetTime and GetTime() or 0
		if GS_LastInventoryTooltipKey == inventoryKey
				and (now - GS_LastInventoryTooltipAt) <= GS_TOOLTIP_DUPLICATE_WINDOW
		then
			if SarychUI_PerfLog then
				SarychUI_PerfLog("GearScoreLite", "SetInventoryItemDuplicateSkip", tostring(ItemSlot) .. "/" .. tostring(Argument) .. " item=" .. tostring(itemID or itemLink))
			end
			skipDuplicateWork = true
		end
	end
	if SarychUI_PerfLog then
		SarychUI_PerfLog("GearScoreLite", "SetInventoryItem", tostring(ItemSlot) .. "/" .. tostring(Argument))
	end
	local reason = "ok"
	if not gearScoreEnabled then
		GS_SetInventoryItemPerf.disabled = GS_SetInventoryItemPerf.disabled + 1
		local OriginalOnEnter = GearScore_Original_SetInventoryItem(Name, ItemSlot, Argument)
		GearScore_DebugPerf(startMs, "disabled", ItemSlot, Argument)
		return OriginalOnEnter
	end

	if skipDuplicateWork then
		reason = "duplicate-skip"
	else
		-- Item slot tooltips are rebuilt while InspectFrame/Examiner are open.
		-- Calling NotifyInspect from this path forces another inspect update and can
		-- repeatedly redraw the inspect paper doll while the mouse is still over a slot.
		if ( InspectFrame and InspectFrame:IsShown() ) or ( Examiner and Examiner:IsShown() ) then
			GS_SetInventoryItemPerf.skippedInspect = GS_SetInventoryItemPerf.skippedInspect + 1
			reason = "inspect-open"
		elseif UnitName("target") then
			if GearScore_NotifyInspectThrottled("target") then
				GS_LastNotified = UnitName("target")
				GS_SetInventoryItemPerf.notify = GS_SetInventoryItemPerf.notify + 1
				reason = "notify-target"
			else
				reason = "inspect-throttled"
			end
		else
			reason = "no-target"
		end
	end

	local OriginalOnEnter, OriginalOnEnter2, OriginalOnEnter3 = GearScore_Original_SetInventoryItem(Name, ItemSlot, Argument)
	if itemID or itemLink then
		GS_LastInventoryTooltipKey = inventoryKey
		GS_LastInventoryTooltipAt = GetTime and GetTime() or 0
		GS_LastInventoryTooltipReturn1 = OriginalOnEnter
		GS_LastInventoryTooltipReturn2 = OriginalOnEnter2
		GS_LastInventoryTooltipReturn3 = OriginalOnEnter3
	end
	GearScore_DebugPerf(startMs, reason, ItemSlot, Argument)
	if SarychUI_PerfSlow then
		SarychUI_PerfSlow("GearScoreLite", "SetInventoryItemSlow", perfStart, reason .. " " .. tostring(ItemSlot) .. "/" .. tostring(Argument), 2)
	end
	return OriginalOnEnter, OriginalOnEnter2, OriginalOnEnter3
end
function MyPaperDoll()
	if not IsEnabled() then
		return;
	end
	if ( GS_PlayerIsInCombat ) then return; end
	local MyGearScore = GearScore_GetScore(UnitName("player"), "player");
	local Red, Blue, Green = GearScore_GetQuality(MyGearScore)
    PersonalGearScore:SetText(MyGearScore); PersonalGearScore:SetTextColor(Red, Green, Blue, 1)
end
-------------------------------------------------------------------------------

----------------------------- Reports -----------------------------------------

---------------GS-SPAM Slasch Command--------------------------------------
function GS_MANSET(Command)
	if ( strlower(Command) == "" ) or ( strlower(Command) == "options" ) or ( strlower(Command) == "option" ) or ( strlower(Command) == "help" ) then for i,v in ipairs(GS_CommandList) do print(v); end; return end
	if ( strlower(Command) == "show" ) then GS_Settings["Player"] = GS_ShowSwitch[GS_Settings["Player"]]; if ( GS_Settings["Player"] == 1 ) or ( GS_Settings["Player"] == 2 ) then print("Player Scores: On"); else print("Player Scores: Off"); end; return; end
	if ( strlower(Command) == "player" ) then GS_Settings["Player"] = GS_ShowSwitch[GS_Settings["Player"]]; if ( GS_Settings["Player"] == 1 ) or ( GS_Settings["Player"] == 2 ) then print("Player Scores: On"); else print("Player Scores: Off"); end; return; end
    if ( strlower(Command) == "item" ) then GS_Settings["Item"] = GS_ItemSwitch[GS_Settings["Item"]]; if ( GS_Settings["Item"] == 1 ) or ( GS_Settings["Item"] == 3 ) then print("Item Scores: On"); else print("Item Scores: Off"); end; return; end
	if ( strlower(Command) == "level" ) then GS_Settings["Level"] = GS_Settings["Level"] * -1; if ( GS_Settings["Level"] == 1 ) then print ("Item Levels: On"); else print ("Item Levels: Off"); end; return; end
	if ( strlower(Command) == "compare" ) then GS_Settings["Compare"] = GS_Settings["Compare"] * -1; if ( GS_Settings["Compare"] == 1 ) then print ("Comparisons: On"); else print ("Comparisons: Off"); end; return; end
	print("GearScore: Unknown Command. Type '/gs' for a list of options")
end


------------------------ GUI PROGRAMS -------------------------------------------------------

local f = CreateFrame("Frame", "GearScore", UIParent);
f:SetScript("OnEvent", GearScore_OnEvent);
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
GameTooltip:HookScript("OnTooltipSetUnit", GearScore_HookSetUnit)
GameTooltip:HookScript("OnTooltipSetItem", GearScore_HookSetItem)
ShoppingTooltip1:HookScript("OnTooltipSetItem", GearScore_HookCompareItem)
ShoppingTooltip2:HookScript("OnTooltipSetItem", GearScore_HookCompareItem2)
ItemRefTooltip:HookScript("OnTooltipSetItem", GearScore_HookRefItem)
PaperDollFrame:HookScript("OnShow", MyPaperDoll)
PaperDollFrame:CreateFontString("PersonalGearScore")

local GS_FontSize = 12
PersonalGearScore:SetFont("Fonts\\FRIZQT__.TTF", GS_FontSize)
PersonalGearScore:SetText("GS: 0")
PersonalGearScore:SetPoint("BOTTOMLEFT",PaperDollFrame,"TOPLEFT",72,-253)
PersonalGearScore:Show()
PaperDollFrame:CreateFontString("GearScore2")
GearScore2:SetFont("Fonts\\FRIZQT__.TTF", GS_FontSize)
GearScore2:SetText("GearScore")
GearScore2:SetPoint("BOTTOMLEFT",PaperDollFrame,"TOPLEFT",72,-265)
GearScore2:Show()
GearScore_Original_SetInventoryItem = GameTooltip.SetInventoryItem
GameTooltip.SetInventoryItem = GearScore_OnEnter

SlashCmdList["MY2SCRIPT"] = GS_MANSET
SLASH_MY2SCRIPT1 = "/gset"
SLASH_MY2SCRIPT2 = "/gs"
SLASH_MY2SCRIPT3 = "/gearscore"

