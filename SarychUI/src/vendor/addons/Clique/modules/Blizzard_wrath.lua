-- Native 3.3.5 frames plus SarychUI's embedded compact frame engine.
local _, private = ...
local addon = private.Clique
function addon:IntegrateBlizzardFrames()
    -- Snapshot options: registration choices apply consistently after reload.
    local enabled = CopyTable(self.settings.blizzframes)
    local function register(name)
        if _G[name] then self:RegisterBlizzardFrame(_G[name]) end
    end
    for _, name in ipairs({"PlayerFrame", "PetFrame", "TargetFrame", "TargetFrameToT", "FocusFrame", "FocusFrameToT"}) do
        if enabled[name] then register(name) end
    end
    if enabled.party then
        for i=1,4 do register("PartyMemberFrame"..i); register("PartyMemberFrame"..i.."PetFrame") end
    end
    if enabled.boss then for i=1,4 do register("Boss"..i.."TargetFrame") end end
    local function arena()
        if enabled.arena then for i=1,5 do register("ArenaEnemyFrame"..i); register("ArenaEnemyFrame"..i.."PetFrame") end end
    end
    arena()
    local function compact(frame)
        local name = frame and frame.GetName and frame:GetName() or ""
        local party = name:match("^CompactPartyFrameMember%d+$")
        local raid = name:match("^CompactRaidFrame%d+$") or name:match("^CompactRaidGroup%d+Member%d+$")
        if (party and enabled.compactparty) or (raid and enabled.compactraid) then self:RegisterBlizzardFrame(frame) end
    end
    local hooked = false
    local function compactEngine()
        if hooked or type(CompactUnitFrame_SetUpFrame) ~= "function" then return end
        hooked = true
        hooksecurefunc("CompactUnitFrame_SetUpFrame", compact)
        -- Frames can exist before the addon registry initializes Clique.
        for name, frame in pairs(_G) do
            if type(name)=="string" and name:match("^Compact") and type(frame)=="table" and frame.GetName then compact(frame) end
        end
    end
    compactEngine()
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function() arena(); compactEngine() end)
end
