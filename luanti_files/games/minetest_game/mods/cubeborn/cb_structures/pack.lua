-- Compact strings for node samples: "offset.palette" pairs in base 36, comma
-- separated. An offset indexes a box (x fastest, then y, then z); a palette
-- index points into a list of node names kept once per structure.
local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"

local function b36(n)
	if n == 0 then
		return "0"
	end
	local s = ""
	while n > 0 do
		local d = n % 36
		s = DIGITS:sub(d + 1, d + 1) .. s
		n = math.floor(n / 36)
	end
	return s
end

function cb_structures.offset(minp, maxp, pos)
	local sx, sy = maxp.x - minp.x + 1, maxp.y - minp.y + 1
	return (pos.x - minp.x) + (pos.y - minp.y) * sx + (pos.z - minp.z) * sx * sy
end

function cb_structures.at_offset(minp, maxp, o)
	local sx, sy = maxp.x - minp.x + 1, maxp.y - minp.y + 1
	return vector.new(minp.x + o % sx, minp.y + math.floor(o / sx) % sy, minp.z + math.floor(o / (sx * sy)))
end

function cb_structures.pack(list)
	local out = {}
	for i, e in ipairs(list) do
		out[i] = b36(e.o) .. "." .. b36(e.p)
	end
	return table.concat(out, ",")
end

function cb_structures.unpack(s)
	local list = {}
	for o, p in (s or ""):gmatch("(%w+)%.(%w+)") do
		list[#list + 1] = { o = tonumber(o, 36), p = tonumber(p, 36), }
	end
	return list
end
