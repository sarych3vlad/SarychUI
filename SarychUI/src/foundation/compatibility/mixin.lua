-- Shallow composition. Named mixins are resolved only when explicitly supplied.
local _, private = ...
local C = private.Compat
function C.Mixin(object, ...)
    assert(type(object) == "table", "Mixin target must be a table")
    for i = 1, select("#", ...) do
        local mixin = select(i, ...)
        if type(mixin) == "string" then
            local name = mixin
            mixin = _G[name]
            assert(type(mixin) == "table", "Unknown mixin: " .. name)
        end
        if mixin ~= nil then
            assert(type(mixin) == "table", "Mixin source must be a table")
            for key, value in pairs(mixin) do object[key] = value end
        end
    end
    return object
end
function C.CreateFromMixins(...) return C.Mixin({}, ...) end
function C.CreateAndInitFromMixin(mixin, ...)
    local object = C.CreateFromMixins(mixin)
    object:Init(...)
    return object
end
