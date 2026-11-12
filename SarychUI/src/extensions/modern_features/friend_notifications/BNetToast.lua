-- Global enabled state
BNetToastEnabled = BNetToastEnabled or true;

-- Function to check if addon is enabled
local function IsEnabled()
	if BNetToastEnabled == false then return false end
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.BNetToast then
		return SarychUI.db.profile.addons.BNetToast.enabled ~= false;
	end
	return BNetToastEnabled;
end

local gmatch = string.gmatch
local gsub = string.gsub
local CreateFrame = CreateFrame
local GetFriendInfo = GetFriendInfo
local PlaySound = PlaySound

local pattern1 = ERR_FRIEND_ONLINE_SS:gsub("%%s", "(%.+)"):gsub("%[", "%%["):gsub("%]","%%]");
local pattern2 = ERR_FRIEND_OFFLINE_S:gsub("%%s", "(%.+)"):gsub("%[", "%%["):gsub("%]","%%]");

function FriendsFrameBroadcastInput_OnEnterPressed(self)
	if not IsEnabled() then
		return;
	end
	local broadcastText = self:GetText();
	if(GetNumFriends() < 1) then return; end
	local numButtons = #FriendsFrameFriendsScrollFrame.buttons;
	for i = 1, numButtons do
		local friend = _G["FriendsFrameFriendsScrollFrameButton" .. i];
		if(friend.id and friend.buttonType == FRIENDS_BUTTON_TYPE_WOW) then
			local name, level, class, zone, connected, status, note = GetFriendInfo(friend.id);
			if(connected) then
				SendChatMessage(broadcastText, "WHISPER", nil, name);
			end
		end
	end
	FriendsFrameBroadcastInput_UpdateDisplay(self, broadcastText);
end

FriendsFrameBroadcastInput:SetScript("OnEnterPressed", FriendsFrameBroadcastInput_OnEnterPressed);
FriendsFrameBroadcastInput:Show()
FriendsFrameBroadcastInput.Hide = function() end

-- Private toast types keep character names out of the native presence-ID API.
local FRIEND_ONLINE = "SarychUI_FriendOnline"
local FRIEND_OFFLINE = "SarychUI_FriendOffline"
local nativeToastClick = BNToastFrameClickFrame:GetScript("OnClick")

hooksecurefunc("BNToastFrame_Show", function()
	local kind = BNToastFrame.toastType
	if kind ~= FRIEND_ONLINE and kind ~= FRIEND_OFFLINE then return end
	if not IsEnabled() then BNToastFrame:Hide(); return end
	BNToastFrame.tooltip = nil
	BNToastFrameIconTexture:SetTexCoord(0, 0.25, 0.5, 1)
	BNToastFrameTopLine:Show()
	BNToastFrameTopLine:SetText(BNToastFrame.toastData)
	BNToastFrameTopLine:SetTextColor(FRIENDS_BNET_NAME_COLOR.r, FRIENDS_BNET_NAME_COLOR.g, FRIENDS_BNET_NAME_COLOR.b)
	BNToastFrameBottomLine:Show()
	BNToastFrameBottomLine:SetText(kind == FRIEND_ONLINE and BN_TOAST_ONLINE or BN_TOAST_OFFLINE)
	BNToastFrameBottomLine:SetTextColor(FRIENDS_GRAY_COLOR.r, FRIENDS_GRAY_COLOR.g, FRIENDS_GRAY_COLOR.b)
	BNToastFrameDoubleLine:Hide()
end)

local function BNToastFrame_OnClick(self, btn, ...)
	local toastType = BNToastFrame.toastType
	if toastType ~= FRIEND_ONLINE and toastType ~= FRIEND_OFFLINE then
		if nativeToastClick then return nativeToastClick(self, btn, ...) end
		return
	end
	if not IsEnabled() then return end
	local name = BNToastFrame.toastData
	if btn == "LeftButton" and toastType == FRIEND_ONLINE then
		BNToastFrame:Hide()
		DropDownList1:Hide()
		ChatFrame_SendTell(name)
	elseif btn == "RightButton" then
		PlaySound("igMainMenuOptionCheckBoxOn")
		FriendsFrame_ShowDropdown(name, toastType == FRIEND_ONLINE and 1 or nil)
	end
end
BNToastFrameClickFrame:RegisterForClicks("AnyUp");
BNToastFrameClickFrame:SetScript("OnClick", BNToastFrame_OnClick);

local BNetFrame = CreateFrame("Frame");
SarychUI_BNetToastFrame = BNetFrame;
BNetFrame:SetScript("OnEvent", function(self, event, arg1, ...)
	if not IsEnabled() then
		return;
	end
	local name = arg1:gmatch(pattern1)();
	if(name) then
		BNToastFrame_AddToast(FRIEND_ONLINE, name);
		return;
	end
	name = arg1:gmatch(pattern2)();
	if(not name) then return; end
	BNToastFrame_AddToast(FRIEND_OFFLINE, name);
end);
BNetFrame:RegisterEvent("CHAT_MSG_SYSTEM");

local function filter(self, event, arg1, ...)
	if not IsEnabled() then
		return false;
	end
	local name = arg1:gmatch(pattern1)() or arg1:gmatch(pattern2)();
	if(name) then
		return true;
	end
end
ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", filter);
