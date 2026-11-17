local module = SarychUI.modules.health_indicators
local function DB() return SarychUI:GetModuleProfile("health_indicators") end

function module:GetPetOptions(mode, order)
    local choices = {}
    for index, kind in ipairs(module.NameplatePetOrder or {}) do
        local key, pet = kind, module.NameplatePets[kind]
        local function IsEnabled()
            local db=DB(); return not db or not db.petEnabled or db.petEnabled[key] ~= false
        end
        local enabled = {
            type="toggle", order=1,
            name=function()
                return string.format("|TInterface\\Icons\\%s:22:22:0:0|t %s",
                    pet.icon, SarychUI:T("ui.nameplates.pet." .. key))
            end,
            get=IsEnabled,
            set=function(_, value)
                local db=DB(); if not db then return end
                db.petEnabled = db.petEnabled or {}
                db.petEnabled[key] = value and true or false
                module:RefreshPetIcons()
            end,
        }
        choices[key] = {
            type="group", name="", inline=true, order=index, suiToggleSelect=true,
            args={
                enabled=enabled,
                fallback={
                    type="select", name="", order=2,
                    hidden=function() return module:GetPetDisplayMode() ~= "icons" or IsEnabled() end,
                    values={plates="ui.nameplates.pet_fallback_plates", hide="ui.nameplates.pet_fallback_hide", __order={"plates","hide"}},
                    get=function()
                        local db=DB()
                        return db and db.petFallback and db.petFallback[key] == "plates" and "plates" or "hide"
                    end,
                    set=function(_, value)
                        if value ~= "plates" and value ~= "hide" then return end
                        local db=DB(); if not db then return end
                        db.petFallback = db.petFallback or {}
                        db.petFallback[key] = value
                        module:RefreshPetIcons()
                    end,
                },
            },
        }
    end
    return {
        type="group", name="ui.nameplates.summoned_creatures", inline=true, order=order or 1,
        hidden=function() return mode and SarychUI:GetNameplateMode() ~= mode or false end,
        disabled=function() local db=DB(); return not db or db.enabled == false end,
        args={
            display={
                type="select", name="ui.nameplates.pet_display", order=1, width="full",
                values={plates="ui.nameplates.pet_plates", icons="ui.nameplates.totem_icons", __order={"plates","icons"}},
                get=function() return module:GetPetDisplayMode() end,
                set=function(_, value)
                    if value ~= "plates" and value ~= "icons" then return end
                    local db=DB(); if not db then return end
                    db.petDisplay=value
                    db.petIcons=value == "icons" -- Keep the existing profile flag in sync.
                    module:RefreshPetIcons()
                end,
            },
            selection={type="group", name="", inline=true, order=2, suiTwoCol=true, args=choices},
            castbars={
                type="toggle", name="ui.nameplates.pet_icon_castbars", order=3, width="full",
                hidden=function() return module:GetPetDisplayMode() ~= "icons" end,
                get=function() local db=DB(); return db and db.petIconCastBars == true or false end,
                set=function(_, value)
                    local db=DB(); if not db then return end
                    db.petIconCastBars=value and true or false
                    module:RefreshPetIcons()
                end,
            },
            targetPlate={
                type="toggle", name="ui.nameplates.pet_plate_on_target", order=4, width="full",
                hidden=function() return module:GetPetDisplayMode() ~= "icons" end,
                get=function() local db=DB(); return db and db.petPlateOnTarget == true or false end,
                set=function(_, value)
                    local db=DB(); if not db then return end
                    db.petPlateOnTarget=value and true or false
                    module:RefreshPetIcons()
                end,
            },
            lifetime={
                type="toggle", name="ui.nameplates.pet_icon_lifetime", desc="ui.nameplates.pet_icon_lifetime_desc", order=5, width="full",
                hidden=function() return module:GetPetDisplayMode() ~= "icons" end,
                get=function() local db=DB(); return db and db.petIconLifetime == true or false end,
                set=function(_, value)
                    local db=DB(); if not db then return end
                    db.petIconLifetime=value and true or false
                    module:RefreshPetIcons()
                end,
            },
        },
    }
end
