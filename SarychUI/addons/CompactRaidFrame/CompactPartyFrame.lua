function CompactPartyFrame_OnLoad(self)
    self.applyFunc = CompactRaidGroup_ApplyFunctionToAllFrames;
    
    -- Регистрируем события для обновления юнитов
    self:RegisterEvent("PARTY_MEMBERS_CHANGED");
    self:RegisterEvent("PLAYER_ENTERING_WORLD");
    
    -- Помечаем как party фрейм
    self.isPartyFrame = true;

    -- Инициализируем все фреймы
    for i=1, MEMBERS_PER_RAID_GROUP do
        local unitFrame = _G[self:GetName().."Member"..i];
        if ( unitFrame ) then
            CompactUnitFrame_SetUpFrame(unitFrame, DefaultCompactUnitFrameSetup);
            CompactUnitFrame_SetUpdateAllEvent(unitFrame, "PARTY_MEMBERS_CHANGED");
        end
    end

    self.title:SetText(PARTY);
    self.title:Disable();
    
    -- Обновляем юниты после загрузки
    CompactPartyFrame_UpdateUnits(self);
end

function CompactPartyFrame_OnEvent(self, event, ...)
    if InCombatLockdown() then
        return self:RegisterEvent("PLAYER_REGEN_ENABLED");
    end

    if ( event == "PARTY_MEMBERS_CHANGED" or event == "PLAYER_ENTERING_WORLD" ) then
        CompactPartyFrame_UpdateUnits(self);
    elseif ( event == "PLAYER_REGEN_ENABLED" ) then
        CompactPartyFrame_UpdateUnits(self);
        self:UnregisterEvent("PLAYER_REGEN_ENABLED");
    end
end

function CompactPartyFrame_UpdateUnits(self)
    -- Устанавливаем player в первый слот
    local unitFrame = _G[self:GetName().."Member1"];
    if ( unitFrame ) then
        CompactUnitFrame_SetUnit(unitFrame, "player");
    end
    
    -- Устанавливаем party юниты
    for i=1, GetNumSubgroupMembers() do
        local unitFrame = _G[self:GetName().."Member"..(i+1)];
        if ( unitFrame ) then
            CompactUnitFrame_SetUnit(unitFrame, "party"..i);
        end
    end
    
    -- Очищаем оставшиеся фреймы
    for i=GetNumSubgroupMembers()+2, MEMBERS_PER_RAID_GROUP do
        local unitFrame = _G[self:GetName().."Member"..i];
        if ( unitFrame ) then
            CompactUnitFrame_SetUnit(unitFrame, nil);
        end
    end
end

function CompactPartyFrame_Generate()
    local frame = CompactPartyFrame;
    local didCreate = false;
    if ( not frame ) then
        frame = CreateFrame("Frame", "CompactPartyFrame", UIParent, "CompactPartyFrameTemplate");
        CompactRaidGroup_UpdateBorder(frame);
        didCreate = true;
    end

    return frame, didCreate;
end
