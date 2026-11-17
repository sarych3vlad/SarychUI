local module = SarychUI.modules.frame
-- Pet name display: keep the legacy setting (0: full, 1: shorten, 2: hide).
local S = {}
local FRAME_MODULE = "frame"

local function FrameDB()
	local modules = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return modules and modules[FRAME_MODULE]
end

S.petNameShorteningHooked = false
S.petNameShorteningEnabled = false

local MAX_NAME_LENGTH = 26

local function ShortenPetName(frame)
    local db = FrameDB()
    if not db or not db.enabled then return end

    if not S.petNameShorteningEnabled then return end
    local mode = db.enablePetNameShortening
    if mode ~= 1 and mode ~= 2 then return end
    if not frame or not frame.name then return end

    if mode == 2 then
        frame.name:SetText("")
        return
    end

    local name = UnitName("pet")
    if name and strlenutf8(name) > MAX_NAME_LENGTH then
        name = strsub(name, 1, MAX_NAME_LENGTH) .. "..."
    end
    frame.name:SetText(name or "")
end

function SarychUI.modules.frame:ApplyPetNameShortening()
    local db = FrameDB()
    if not db or not db.enabled then
        if S.petNameShorteningEnabled then
            SarychUI.modules.frame:DisablePetNameShortening()
        end
        return
    end

    if db.enablePetNameShortening == 1 or db.enablePetNameShortening == 2 then
        if not S.petNameShorteningEnabled then
            SarychUI.modules.frame:EnablePetNameShortening()
        else
            if PetFrame and PetFrame.name then
                ShortenPetName(PetFrame)
            end
        end
    else
        if S.petNameShorteningEnabled then
            SarychUI.modules.frame:DisablePetNameShortening()
        end
    end
end

function SarychUI.modules.frame:EnablePetNameShortening()
    local db = FrameDB()
    if not db or not db.enabled then return end

    S.petNameShorteningEnabled = true
    if not S.petNameShorteningHooked then
        hooksecurefunc("PetFrame_Update", function()
            ShortenPetName(PetFrame)
        end)
        -- Generic frame refreshes and renames also write the pet's name.
        hooksecurefunc("UnitFrame_Update", function(frame)
            if frame == PetFrame then ShortenPetName(frame) end
        end)
        hooksecurefunc("UnitFrame_OnEvent", function(frame, event)
            if frame == PetFrame and event == "UNIT_NAME_UPDATE" then
                ShortenPetName(frame)
            end
        end)
        S.petNameShorteningHooked = true
    end

    -- Apply immediately if PetFrame exists
    if PetFrame and PetFrame.name then
        ShortenPetName(PetFrame)
    end
end

function SarychUI.modules.frame:DisablePetNameShortening()
    if not S.petNameShorteningEnabled then return end
    S.petNameShorteningEnabled = false

    -- Secure hooks stay installed; the enabled flag makes them inert.

    -- Restore original name if PetFrame exists
    if PetFrame and PetFrame.name then
        local name = UnitName("pet")
        PetFrame.name:SetText(name or "")
    end
end
