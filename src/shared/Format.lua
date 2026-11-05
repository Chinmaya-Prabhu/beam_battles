-- Number formatting for money and counts: 824.13T, 1.2K, 950.
local Format = {}

local UNITS = { { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }

function Format.short(n)
	local sign = n < 0 and "-" or ""
	n = math.abs(n)
	for _, u in UNITS do
		if n >= u[1] then
			return sign .. string.format("%.2f", n / u[1]):gsub("%.?0+$", "") .. u[2]
		end
	end
	return sign .. tostring(math.floor(n))
end

function Format.cash(n)
	return "$" .. Format.short(n)
end

return Format
