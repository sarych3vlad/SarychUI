local _, Private = ...

--[[ INTERNAL ]]

-- Texture Path
Private.TEXTURE_PATH = "Interface\\AddOns\\SarychUI\\addons\\!!!ClassicAPI\\Texture\\"

-- Scan Tooltip
local Tooltip = CreateFrame("GameTooltip", "__CAPIScanTooltip")
Tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
Tooltip:AddFontStrings(Tooltip:CreateFontString("$parentTextLeft1", nil, "GameTooltipText"), Tooltip:CreateFontString("$parentTextRight1", nil, "GameTooltipText"))
Private.Tooltip = Tooltip

-- General Event
Tooltip:SetScript("OnEvent",
	function(self, event)
		-- [Unit.lua:C_UnitInRange] Force client to cache Vial of the Sunwell
		if ( WOW_PROJECT_ID_RCE ~= WOW_PROJECT_CLASSIC ) then
			local _, RangeItemCached = GetItemInfo(34471)
			if ( not RangeItemCached ) then
				ItemEventListener:AddCallback(34471, Private.Void)
			end
		end

		ItemEventListener:Init()
		self:UnregisterEvent(event)
		self:SetScript("OnEvent", nil)
	end
)
Tooltip:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Errors
function Private.Error(Text)
	error(Text or "Error!", 2)
end

-- Common Functions
function Private.Void()
	-- Send it to the nether.
end

function Private.True()
	return true
end

function Private.False()
	return false
end

--[[function Private.Globalize(Namespace, Data)
	_G[Namespace] = Data
	for Name,Func in pairs(Data) do
		local Exist = _G[Name]
		if ( Exist ) then
			if ( Func ~= Exist ) then
				Name = "C_"..Name
			end
		else
			_G[Name] = Func
		end
	end
end]]

--[[ MISCELLANEOUS ]]

-- [LFD_ERROR_FIX] This is unrelated to ClassicAPI, but I'm a chill guy :)
local LFDQueueFrameRandomCooldownFrame_Update = LFDQueueFrameRandomCooldownFrame_Update
local Sub = string.sub

-- LFD Lua Error
LFDQueueFrameCooldownFrame:SetScript("OnEvent", function(Self, Event, Unit)
	if ( Event ~= "UNIT_AURA" or (Unit and (Unit == "player" or Sub(Unit, 1, 5) == "party")) ) then
		LFDQueueFrameRandomCooldownFrame_Update()
	end
end)