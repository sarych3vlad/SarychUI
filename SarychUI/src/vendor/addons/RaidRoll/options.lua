-- Native SarychUI settings. Keep the original saved variables and runtime handlers.
local controls = {
    {"RR_RollCheckBox_Unannounced_panel", "RR_Track_Unannounced_Rolls", "Catch_Unannounced_Rolls"},
    {"RR_RollCheckBox_AllRolls_panel", "RR_Accept_All_Rolls", "Allow_all_rolls"},
    {"RR_RollCheckBox_ExtraRolls_panel", "RR_AllowExtraRolls", "Allow_Extra_Rolls"},
    {"RR_RollCheckBox_GuildAnnounce", "RR_RollCheckBox_GuildAnnounce", "Announce_winner_to_guild"},
    {"RR_RollCheckBox_GuildAnnounce_Officer", "RR_RollCheckBox_GuildAnnounce_Officer", "Use_officer_channel"},
    {"RR_RollCheckBox_Auto_Announce", "RR_RollCheckBox_Auto_Announce", "Auto_Announce_Count"},
    {"RR_RollCheckBox_Auto_Close", "RR_RollCheckBox_Auto_Close", "Auto_Close_Window"},
    {"RR_RollCheckBox_No_countdown", "RR_RollCheckBox_No_countdown", "No_countdown"},
    {"RR_RollCheckBox_Multi_Rollers", "RR_RollCheckBox_Multi_Rollers", "Multi_Rollers"},
    {"RR_RollCheckBox_ShowRanks_panel", "RR_Show_Ranks", "Show_Rank_Beside_Name"},
    {"RR_RollCheckBox_ShowGroupNumber_panel", "RR_ShowGroupNumber", "Show_Group_Beside_Name"},
    {"RR_RollCheckBox_ShowClassColors_panel", "RR_ShowClassColors", "Show_Class_Colors"},
    {"RR_RollCheckBox_EPGPMode_panel", "RR_EPGP_Enabled", "Enable_EPGP_mode"},
    {"RR_RollCheckBox_EPGPThreshold_panel", "RR_EPGP_Priority", "Enable_threshold_levels"},
    {"RR_RollCheckBox_Enable_Alt_Mode", "RR_RollCheckBox_Enable_Alt_Mode", "Enable_Alt_Mode"},
    {"RR_RollCheckBox_Track_Bids", "RR_RollCheckBox_Track_Bids", "Track_Bids"},
    {"RR_RollCheckBox_Num_Not_Req", "RR_RollCheckBox_Num_Not_Req", "Number not required"},
    {"RR_RollCheckBox_Track_EPGPSays", "RR_RollCheckBox_Track_EPGPSays", "Track_EPGPSays"},
    {"RR_RollCheckBox_RankPrio_panel", "RR_RankPriority", "Give_Higher_Ranks_Priority"},
    {"RR_AutoOpenLootWindow", "RR_AutoOpenLootWindow", "Automatically_open_window_when_new_loot_is_found"},
    {"RR_ReceiveGuildMessages", "RR_ReceiveGuildMessages", "Receive_loot_messages_from_guild"},
    {"RR_Enable3Messages", "RR_Enable3Messages", "RR_Enable3Messages"},
    {"RR_Frame_WotLK_Dung_Only", "RR_Frame_WotLK_Dung_Only", "RR_WotLK_Dung_Only"},
}
local function DB()
    RaidRoll_DBPC = RaidRoll_DBPC or {}
    local player = UnitName("player")
    RaidRoll_DBPC[player] = RaidRoll_DBPC[player] or {}
    return RaidRoll_DBPC[player]
end
local function Label(key)
    return SarychUI.L["RaidRoll_" .. key] or key
end
local function Apply()
    -- The roll window also changes these options; always synchronize from storage first.
    for _, row in ipairs(controls) do
        local widget = _G[row[1]]
        if widget then widget:SetChecked(DB()[row[2]] == true) end
    end
    if RR_RollCheckBox_Unannounced_panel then RaidRoll_CheckButton_Update_Panel() end
end
local function Toggle(index, order)
    local row = controls[index]
    return {type="toggle", name=Label(row[3]), order=order, width="full",
        get=function() return DB()[row[2]] == true end,
        set=function(_, value) DB()[row[2]]=value and true or false; Apply() end}
end
local function Group(name, order, first, last)
    local group={type="group", name=name, order=order, inline=true, args={}}
    for i=first,last do group.args[controls[i][2]]=Toggle(i,i-first+1) end
    return group
end
function SarychUI_OpenRaidRollConfig()
    if not SarychUI then return end
    if not (SarychUI.IsSarychUIOptionsOpen and SarychUI:IsSarychUIOptionsOpen()) then SarychUI:OpenOptions() end
    local core=SarychUI.OptionsCore
    if core then core._addonListSelected="RaidRoll"; core:SelectSection("sui:addons") end
end
function SarychUI_GetRaidRollOptions()
    RaidRoll_DB=RaidRoll_DB or {}
    RaidRoll_DB["Rank Priority"]=RaidRoll_DB["Rank Priority"] or {}
    for i=1,12 do
        if RaidRoll_DB["Rank Priority"][i]==nil then RaidRoll_DB["Rank Priority"][i]=11-i end
    end
    if RR_GetEPGPGuildData then RR_GetEPGPGuildData() end
    local main={type="group", name=Label("Main"), order=10, args={
        general=Group(Label("General_Settings"),1,1,9),
        display=Group(Label("Raid_Roll_Display_Settings"),2,10,12),
        epgp=Group(Label("Raid_Roll_EPGP_Settings"),3,13,15),
        misc=Group(Label("Raid_Roll_Misc_Settings"),4,16,18),
    }}
    main.args.display.args.scale={type="range", name=Label("Set_Scale").." (%)", order=4, min=1,max=200,step=1,
        get=function() return RaidRoll_DB.Scale or 100 end,
        set=function(_,value)
            RaidRoll_DB.Scale=value
            if RaidRoll_Scale_Slider then RaidRoll_Scale_Slider:SetValue(value) end
        end}
    main.args.display.args.width={type="range", name=Label("Set_Extra_Rank_Width"), order=5,min=0,max=200,step=1,
        get=function() return DB().RR_ExtraWidth or 0 end,
        set=function(_,value) DB().RR_ExtraWidth=value; Apply() end}
    main.args.general.args.duration={type="range", name=Label("Set_Rolling_Time"),order=10,min=5,max=120,step=1,
        get=function() return (DB().Time_Offset or 0)+60 end,
        set=function(_,value) DB().Time_Offset=value-60 end}
    local ranks=Group(Label("Guild_Rank"),1,19,19)
    for i=1,11 do
        local rank=i
        ranks.args["rank"..rank]={type="range",order=rank+1,min=0,max=10,step=1,
            name=function() return rank==11 and Label("Not_in_Guild") or ("#"..rank..": "..(GuildControlGetRankName(rank) or "—")) end,
            get=function() return RaidRoll_DB["Rank Priority"][rank] end,
            set=function(_,value)
                RaidRoll_DB["Rank Priority"][rank]=value
                local button=_G["Raid_Roll_GuildPriority"..rank]
                if button then button:SetText(value) end
                rr_RollSort(rr_CurrentRollID)
                if RR_HasDisplayedAlready then RR_Display(rr_CurrentRollID) end
            end}
    end
    local messages={type="group",name=Label("Messages"),order=1,inline=true,args={}}
    for i=1,3 do
        local index=i
        local key="Raid_Roll_SetMsg"..index.."_EditBox"
        messages.args["message"..index]={type="input",name=Label("Set_Msg"..index),desc=Label("Use_Item_Brackets"),order=index,width="full",
            get=function() return DB()[key] or "" end,
            set=function(_,value)
                DB()[key]=value
                if _G[key] then _G[key]:SetText(value) end
            end}
    end
    return {
        main=main,
        priority={type="group",name=Label("Priorities"),order=20,args={ranks=ranks}},
        loot={type="group",name=Label("LootWindow"),order=30,args={messages=messages,general=Group(Label("General_Settings"),2,20,23)}},
    }
end
