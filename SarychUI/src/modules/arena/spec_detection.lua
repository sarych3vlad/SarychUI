-- Arena-specific facade over the shared specialization framework.
local module = SarychUI and SarychUI.modules and SarychUI.modules.arena
local Spec = SarychUI and SarychUI.UnitSpecialization
if not module or not Spec then return end

function module:GetArenaSpecIcon(class, spec)
    return Spec:GetIcon(class, spec)
end

function module:GetTestArenaSpec(index)
    return Spec:GetTestArenaSpec(index)
end

function module:GetArenaSpec(unit)
    return Spec:Get(unit, true)
end

function module:StartArenaSpecDetection()
    if IsInInstance and select(2, IsInInstance()) == "arena" then
        Spec:StartEnemyDetection()
    end
end

function module:StopArenaSpecDetection()
    Spec:StopEnemyDetection()
end
