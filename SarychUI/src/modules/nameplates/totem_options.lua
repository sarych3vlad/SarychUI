local module = SarychUI.modules.health_indicators
local Totems = SarychUI.NameplateTotems
local function DB() return SarychUI:GetModuleProfile("health_indicators") end
local function Refresh()
    module:RefreshTotems()
    local auras = SarychUI:GetModuleProfile("plates_auras")
    if auras and auras.enabled ~= false and _G.sarPlatesAuras_Rerender then
        _G.sarPlatesAuras_Rerender()
    end
end

function module:GetTotemOptions(mode, order)
    local choices = {}
    for index, entry in ipairs(Totems.Entries) do
        if entry.school ~= "other" then
            local key, spell, label = entry.key, entry.spell, entry.name
            local function IsEnabled()
                local db=DB(); return not db or not db.totemEnabled or db.totemEnabled[key] ~= false
            end
            local enabled = {
                type="toggle", order=1,
                name=function()
                    local name, _, icon = GetSpellInfo(spell)
                    return string.format("|T%s:22:22:0:0|t %s", icon or "Interface\\Icons\\INV_Misc_QuestionMark", label or name or tostring(spell))
                end,
                get=IsEnabled,
                set=function(_, value)
                    local db=DB(); if not db then return end
                    db.totemEnabled = db.totemEnabled or {}
                    db.totemEnabled[key] = value and true or false
                    Refresh()
                end,
            }
            choices[key] = {
                type="group", name="", inline=true, order=index, suiToggleSelect=true,
                args={
                    enabled=enabled,
                    fallback={
                        type="select", name="", order=2,
                        hidden=function() return Totems:GetMode() ~= "icons" or IsEnabled() end,
                        values={plates="ui.nameplates.pet_fallback_plates", hide="ui.nameplates.pet_fallback_hide", __order={"plates","hide"}},
                        get=function()
                            local db=DB()
                            return db and db.totemFallback and db.totemFallback[key] == "plates" and "plates" or "hide"
                        end,
                        set=function(_, value)
                            if value ~= "plates" and value ~= "hide" then return end
                            local db=DB(); if not db then return end
                            db.totemFallback = db.totemFallback or {}
                            db.totemFallback[key] = value
                            Refresh()
                        end,
                    },
                },
            }
        end
    end
    return {
        type="group", name="ui.nameplates.totems", inline=true, order=order,
        hidden=function() return SarychUI:GetNameplateMode() ~= mode end,
        disabled=function() local db=DB(); return not db or db.enabled == false end,
        args={
            display={
                type="select", name="ui.nameplates.totem_display", order=1, width="full",
                values={plates="ui.nameplates.totem_plates", icons="ui.nameplates.totem_icons", __order={"plates","icons"}},
                get=function() return Totems:GetMode() end,
                set=function(_, value)
                    if value ~= "plates" and value ~= "icons" then return end
                    local db=DB(); if not db then return end
                    db.totemDisplay=value
                    Refresh()
                end,
            },
            selection={type="group", name="", inline=true, order=2, suiTwoCol=true, args=choices},
        },
    }
end
