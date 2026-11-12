function CompactPartyFrame_OnLoad(self)
    self.applyFunc = CompactRaidGroup_ApplyFunctionToAllFrames;

    local unitFrame = _G[self:GetName().."Member1"];
    CompactUnitFrame_SetUnit(unitFrame, "player");
    CompactUnitFrame_SetUpFrame(unitFrame, DefaultCompactUnitFrameSetup);
    CompactUnitFrame_SetUpdateAllEvent(unitFrame, "PARTY_MEMBERS_CHANGED");

    for i=1, MEMBERS_PER_RAID_GROUP do
        if ( i > 1 ) then	--Player has to be done separately.
            local unitFrame = _G[self:GetName().."Member"..i];
            CompactUnitFrame_SetUnit(unitFrame, "party"..(i-1));
            CompactUnitFrame_SetUpFrame(unitFrame, DefaultCompactUnitFrameSetup);
            CompactUnitFrame_SetUpdateAllEvent(unitFrame, "PARTY_MEMBERS_CHANGED");
        end
    end

    self.title:SetText(PARTY);
    self.title:Disable();
end

function CompactPartyFrame_Generate()
    local frame = CompactPartyFrame;
    local didCreate = false;
    if ( not frame ) then
        frame = CreateFrame("Frame", "CompactPartyFrame", UIParent, "CompactPartyFrameTemplate");
        CompactRaidGroup_UpdateBorder(frame);
        didCreate = true;
    end

    -- Reassign slots on every layout so hiding the player leaves no leading gap.
    local slot = 1;
    for i = 0, MAX_PARTY_MEMBERS do
        local unit = i == 0 and "player" or "party"..i;
        if SarychUI.modules.group_frames:ShouldDisplayUnit(unit) then
            CompactUnitFrame_SetUnit(_G[frame:GetName().."Member"..slot], unit);
            slot = slot + 1;
        end
    end
    for i = slot, MEMBERS_PER_RAID_GROUP do
        CompactUnitFrame_SetUnit(_G[frame:GetName().."Member"..i], nil);
    end
    return frame, didCreate;
end
