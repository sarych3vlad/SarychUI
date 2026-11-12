local module = SarychUI.WoWCircle
local function DB() return module:GetDB() end
function module:ApplyVipCommands()
    local db = DB()
    if not db or db.enabled ~= true then
        self:DisableVipCommands()
        return
    end
    local on = db.enableCircleContextMenu == 1 or db.enableCircleContextMenu == true
    if on then
        if _G.EnableVipCommands then
            _G.EnableVipCommands(true)
        end
        if _G.ApplyVipCommands then
            _G.ApplyVipCommands()
        end
        if _G.InitializeChatMenuButton then
            _G.InitializeChatMenuButton()
        end
    else
        self:DisableVipCommands()
    end
end

function module:DisableVipCommands()
    if _G.DisableVipCommands then
        _G.DisableVipCommands()
    end
end

function module:ApplyPpMessageFix()
    local db = DB()
    if not db or db.enabled ~= true then
        if _G.DisablePpMessageFix then
            _G.DisablePpMessageFix()
        end
        -- Keep filter registration in sync via system filter apply
        self:ApplyWoWCircleSystemFilter()
        return
    end
    local on = db.ppMessageFixEnabled == 1 or db.ppMessageFixEnabled == true
    if on then
        if _G.EnablePpMessageFix then
            _G.EnablePpMessageFix(true)
        end
    else
        if _G.DisablePpMessageFix then
            _G.DisablePpMessageFix()
        end
    end
    self:ApplyWoWCircleSystemFilter()
end

function module:ApplyWoWCircleSystemFilter()
    local db = DB()
    local filter = _G.CHAT_MSG_SYSTEM_wowcircle_filter
    if not filter or not ChatFrame_AddMessageEventFilter then
        return
    end
    -- Always remove first to avoid duplicates
    if ChatFrame_RemoveMessageEventFilter then
        ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", filter)
    end
    if not db or db.enabled ~= true then
        return
    end
    local ppOn = db.ppMessageFixEnabled == 1 or db.ppMessageFixEnabled == true
    local combatOn = db.spamFilterCombatDifficulty == 1 or db.spamFilterCombatDifficulty == true
    if ppOn or combatOn then
        ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", filter)
    end
end

function module:DisableWoWCircleSystemFilter()
    local filter = _G.CHAT_MSG_SYSTEM_wowcircle_filter
    if filter and ChatFrame_RemoveMessageEventFilter then
        ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", filter)
    end
    if _G.DisablePpMessageFix then
        _G.DisablePpMessageFix()
    end
end


function module:Enable()
 self:ApplyVipCommands()
 self:ApplyPpMessageFix()
 self:ApplyWoWCircleSystemFilter()
end
function module:Disable()
 self:DisableVipCommands()
 self:DisableWoWCircleSystemFilter()
end
