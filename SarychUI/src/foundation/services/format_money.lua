-- Text money formatting for chat messages (з/с/м, no coin icons)

local floor = math.floor
local format = string.format

function SarychUI:FormatMoneyText(amount)
	amount = tonumber(amount) or 0
	if amount < 0 then
		amount = -amount
	end

	local gold = floor(amount / 10000)
	local silver = floor((amount / 100) % 100)
	local copper = floor(amount % 100)
	local parts = {}

	if gold > 0 then
		parts[#parts + 1] = gold .. "з"
	end
	if silver > 0 then
		parts[#parts + 1] = silver .. "с"
	end
	if copper > 0 or amount == 0 then
		parts[#parts + 1] = copper .. "м"
	end

	return table.concat(parts, " ")
end

function SarychUI:PrintGrayItemsSold(amount)
	amount = tonumber(amount) or 0
	if amount <= 0 then
		return
	end
	self:Print(format("Продано серых предметов на: %s", self:FormatMoneyText(amount)))
end
