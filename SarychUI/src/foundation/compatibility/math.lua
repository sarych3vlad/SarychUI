-- Pure helpers shared by SarychUI; no global math extensions.
local _, private = ...
local M = {}
private.Compat.Math = M
function M.Lerp(a, b, amount) return (1 - amount) * a + amount * b end
function M.Clamp(value, minimum, maximum)
    if value > maximum then return maximum end
    if value < minimum then return minimum end
    return value
end
function M.Round(value)
    if value < 0 then return math.ceil(value - 0.5) end
    return math.floor(value + 0.5)
end
function M.ClampedPercentageBetween(value, first, last)
    if first == last then return 0 end
    return M.Clamp((value - first) / (last - first), 0, 1)
end
function M.CalculateDistanceSq(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return dx * dx + dy * dy
end
function M.CalculateDistance(...) return math.sqrt(M.CalculateDistanceSq(...)) end
