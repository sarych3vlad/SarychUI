local module = SarychUI.modules.frame
-- Runtime owned by frame; legacy tools profile keys are preserved.
local S = {}
local FRAME_MODULE = "frame"

local function FrameDB()
	local modules = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return modules and modules[FRAME_MODULE]
end

S.petNameShorteningHooked = false

local MAX_NAME_LENGTH = 26

local function ShortenPetName(frame)
    local db = FrameDB()
    if not db or not db.enabled then return end

    if db.enablePetNameShortening ~= 1 then return end
    if not frame or not frame.name then return end

    local name = UnitName("pet")
    if name and strlenutf8(name) > MAX_NAME_LENGTH then
        name = strsub(name, 1, MAX_NAME_LENGTH) .. "..."
    end
    frame.name:SetText(name or "")
end

function SarychUI.modules.frame:ApplyPetNameShortening()
    local db = FrameDB()
    if not db or not db.enabled then
        if S.petNameShorteningHooked then
            SarychUI.modules.frame:DisablePetNameShortening()
        end
        return
    end

    if db.enablePetNameShortening == 1 then
        if not S.petNameShorteningHooked then
            SarychUI.modules.frame:EnablePetNameShortening()
        else
            if PetFrame and PetFrame.name then
                ShortenPetName(PetFrame)
            end
        end
    else
        if S.petNameShorteningHooked then
            SarychUI.modules.frame:DisablePetNameShortening()
        end
    end
end

function SarychUI.modules.frame:EnablePetNameShortening()
    local db = FrameDB()
    if not db or not db.enabled then return end

    if S.petNameShorteningHooked then return end -- Already enabled

    -- Hook PetFrame_Update
    hooksecurefunc("PetFrame_Update", function()
        ShortenPetName(PetFrame)
    end)

    S.petNameShorteningHooked = true

    -- Apply immediately if PetFrame exists
    if PetFrame and PetFrame.name then
        ShortenPetName(PetFrame)
    end
end

function SarychUI.modules.frame:DisablePetNameShortening()
    if not S.petNameShorteningHooked then return end

    -- We can't unhook hooksecurefunc, but we can restore original behavior
    -- by ensuring PetFrame_Update works normally (it will just skip our hook)
    -- The original PetFrame_Update will restore default name display

    -- Restore original name if PetFrame exists
    if PetFrame and PetFrame.name then
        local name = UnitName("pet")
        PetFrame.name:SetText(name or "")
    end

    S.petNameShorteningHooked = false
end
