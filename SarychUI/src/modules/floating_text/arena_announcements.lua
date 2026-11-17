local module = SarychUI.modules.floating_text
local active, installed = false, false
local events = {"CHAT_MSG_BG_SYSTEM_NEUTRAL", "CHAT_MSG_BG_SYSTEM_ALLIANCE",
    "CHAT_MSG_BG_SYSTEM_HORDE", "CHAT_MSG_SYSTEM", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_RAID_BOSS_EMOTE"}

function module:ShouldHideArenaAnnouncement(message)
    if not active then return false end
    local db = SarychUI:GetModuleProfile("floating_text")
    if not db or not db.enabled or not db.hideArenaStartAnnouncement then return false end
    local _, kind = IsInInstance()
    return kind == "arena" and SarychUI.ArenaAnnouncements:IsStart(message)
end

local function FilterChat(_, _, message)
    return module:ShouldHideArenaAnnouncement(message)
end

local function FilterWorldStates()
    if not active then return end
    for i = 1, NUM_ALWAYS_UP_UI_FRAMES or 0 do
        local frame, text = _G["AlwaysUpFrame"..i], _G["AlwaysUpFrame"..i.."Text"]
        if frame and text and module:ShouldHideArenaAnnouncement(text:GetText()) then frame:Hide() end
    end
end

local function Install()
    if installed then return end
    installed = true
    -- Filter delivery, not the underlying events used by timers and other modules.
    -- Install once; inactive wrappers pass through and preserve other hooks.
    if RaidNotice_AddMessage then
        local original = RaidNotice_AddMessage
        RaidNotice_AddMessage = function(frame, message, ...)
            if module:ShouldHideArenaAnnouncement(message) then return end
            return original(frame, message, ...)
        end
    end
    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        local original = UIErrorsFrame.AddMessage
        UIErrorsFrame.AddMessage = function(frame, message, ...)
            if module:ShouldHideArenaAnnouncement(message) then return end
            return original(frame, message, ...)
        end
    end
    if WorldStateAlwaysUpFrame_Update then
        hooksecurefunc("WorldStateAlwaysUpFrame_Update", FilterWorldStates)
    end
end

function module:DisableArenaAnnouncementFilter()
    if not active then return end
    active = false
    for _, event in ipairs(events) do ChatFrame_RemoveMessageEventFilter(event, FilterChat) end
    -- Rebuild native state instead of blindly showing recycled world-state rows.
    if WorldStateAlwaysUpFrame_Update then WorldStateAlwaysUpFrame_Update() end
end

function module:ApplyArenaAnnouncementFilter()
    local db = SarychUI:GetModuleProfile("floating_text")
    if not db or not db.enabled or db.hideArenaStartAnnouncement ~= true then
        self:DisableArenaAnnouncementFilter()
        return
    end
    Install()
    if not active then
        active = true
        for _, event in ipairs(events) do ChatFrame_AddMessageEventFilter(event, FilterChat) end
    end
    FilterWorldStates()
end
