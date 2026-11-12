-- SarychUI GearScore. Formula/slot weights from GearScoreLite Reborn 3x05
-- (Mirrikat45 & Gnomezilla); runtime and UI are owned by SarychUI.
local owner = SarychUI.addons.GearScoreLite
local weights = {
    INVTYPE_RELIC = .3164, INVTYPE_TRINKET = .5625, INVTYPE_2HWEAPON = 2,
    INVTYPE_WEAPONMAINHAND = 1, INVTYPE_WEAPONOFFHAND = 1, INVTYPE_WEAPON = 1,
    INVTYPE_RANGED = .3164, INVTYPE_THROWN = .3164, INVTYPE_RANGEDRIGHT = .3164,
    INVTYPE_SHIELD = 1, INVTYPE_HOLDABLE = 1, INVTYPE_HEAD = 1,
    INVTYPE_NECK = .5625, INVTYPE_SHOULDER = .75, INVTYPE_CHEST = 1,
    INVTYPE_ROBE = 1, INVTYPE_WAIST = .75, INVTYPE_LEGS = 1,
    INVTYPE_FEET = .75, INVTYPE_WRIST = .5625, INVTYPE_HAND = .75,
    INVTYPE_FINGER = .5625, INVTYPE_CLOAK = .5625, INVTYPE_BODY = 0,
}
local high = {[2] = {73, 1}, [3] = {81.375, .8125}, [4] = {91.45, .65}}
local low = {[2] = {8, 2}, [3] = {.75, 1.8}, [4] = {26, 1.2}}
local cache, cacheSize = {}, 0
local colors = {{.55,.55,.55}, {1,1,1}, {.12,1,0}, {0,.5,1}, {.69,.28,.97}, {.94,.47,0}, {1,0,0}}
local colorSteps = {{.45,.45,.45}, {-.88,0,-1}, {-.12,-.5,1}, {.69,-.22,-.03}, {.25,.19,-.96}, {.06,-.47,0}}

function owner:ItemScore(link)
    if not link then return end
    local cached = cache[link]
    if cached then return cached.score, cached.location, cached.quality, cached.colorScore end
    local name, _, quality, level, _, _, _, _, location = GetItemInfo(link)
    if not name or not quality or not level or not location then return end
    local weight = weights[location]
    if not weight then return end
    local rarity, scale = quality, 1
    if rarity == 5 then rarity, scale = 4, 1.3
    elseif rarity == 0 or rarity == 1 then rarity, scale = 2, .005
    elseif rarity == 7 then rarity, level = 3, 187.05 end
    local formula = (level > 120 and high or low)[rarity]
    if not formula then return end
    local base = (level - formula[1]) / formula[2]
    local raw = math.floor(base * weight * 1.8618 * scale)
    local score = math.max(0, raw)
    -- Original GS uses a slot-independent equivalent score for item color.
    -- Equal-level rings and weapons have different GS but the same tint.
    local colorScore = raw < 0 and 1 or math.floor(base * 1.8618) * 11.25
    if cacheSize >= 512 then cache, cacheSize = {}, 0 end
    cache[link] = {score = score, location = location, quality = quality, colorScore = colorScore}
    cacheSize = cacheSize + 1
    return score, location, quality, colorScore
end

-- Sum what the client currently knows. Empty/unloaded slots never block others.
-- Do not cache totals by unit token: target/mouseover can change at any moment.
function owner:UnitScore(unit)
    if not unit or not UnitIsPlayer(unit) then return 0, 0 end
    local _, class = UnitClass(unit)
    local mainLink, offLink = GetInventoryItemLink(unit, 16), GetInventoryItemLink(unit, 17)
    local _, mainType = self:ItemScore(mainLink)
    local _, offType = self:ItemScore(offLink)
    local grip = offLink and (offType == "INVTYPE_2HWEAPON"
        or (mainLink and mainType == "INVTYPE_2HWEAPON")) and .5 or 1
    local total, count = 0, 0
    for slot = 1, 18 do
        if slot ~= 4 then
            local link = slot == 16 and mainLink or slot == 17 and offLink
                or GetInventoryItemLink(unit, slot)
            local score = self:ItemScore(link)
            if score then
                if class == "HUNTER" then
                    if slot == 16 or slot == 17 then score = score * .3164
                    elseif slot == 18 then score = score * 5.3224 end
                end
                if slot == 16 or slot == 17 then score = score * grip end
                total, count = total + score, count + 1
            end
        end
    end
    return math.floor(total), count
end

function owner:ScoreColor(score)
    if score <= 0 then return .1, .1, .1 end
    local value = math.max(0, math.min(score, 5999)) / 1000
    local index = math.ceil(value)
    local a, step, t = colors[index], colorSteps[index], value - (index - 1)
    return a[1] + step[1]*t, a[2] + step[2]*t, a[3] + step[3]*t
end
