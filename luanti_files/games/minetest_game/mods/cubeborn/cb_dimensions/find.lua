-- Validating a pocket box and searching free places for it.
local S = cb_dimensions.S

local GAP = 32
local MAX_CHECKS = 20

function cb_dimensions.validate_box(minp, maxp)
	local e0, e1 = core.get_mapgen_edges()
	if not (cb_core.inside(minp, e0, e1) and cb_core.inside(maxp, e0, e1)) then
		return false, S("The pocket must lie inside the map generation limits.")
	end
	if maxp.y > cb_dimensions.MAX_Y then
		return false, S("The pocket must lie below height @1.", cb_dimensions.MAX_Y)
	end
	for dim, p in pairs(cb_dimensions.all()) do
		if cb_core.intersect(vector.subtract(p.minp, GAP), vector.add(p.maxp, GAP), minp, maxp) then
			return false, S("The pocket would overlap pocket '@1'.", dim)
		end
	end
	return true
end

-- Grid of candidate boxes: highest layer first, then closest to the map centre.
-- Only the first `limit` are collected: a full grid on a big map (mapgen_limit
-- 9000) has millions of cells. Each layer is walked in square rings around the
-- cell nearest the centre, so the work is proportional to `limit`.
function cb_dimensions.candidates(dim, limit)
	limit = limit or MAX_CHECKS
	local size = cb_dimensions.get_dim(dim).size
	local e0, e1 = core.get_mapgen_edges()
	local top = math.min(cb_dimensions.MAX_Y, e1.y)
	local sx, sz = size.x + 16, size.z + 16
	local nx = math.floor((e1.x - size.x + 1 - e0.x) / sx) + 1
	local nz = math.floor((e1.z - size.z + 1 - e0.z) / sz) + 1
	local ci = math.min(math.max(math.floor((-size.x / 2 - e0.x) / sx + 0.5), 0), nx - 1)
	local cj = math.min(math.max(math.floor((-size.z / 2 - e0.z) / sz + 0.5), 0), nz - 1)
	local max_r = math.max(ci, nx - 1 - ci, cj, nz - 1 - cj)
	local list = {}
	for y = top - size.y + 1, e0.y, -size.y do
		local layer = {}
		local function try(i, j)
			if i < 0 or j < 0 or i >= nx or j >= nz then
				return
			end
			local minp = vector.new(e0.x + i * sx, y, e0.z + j * sz)
			local maxp = vector.add(minp, vector.subtract(size, 1))
			if cb_dimensions.validate_box(minp, maxp) then
				local cx, cz = minp.x + size.x / 2, minp.z + size.z / 2
				layer[#layer + 1] = { minp = minp, maxp = maxp, d = cx * cx + cz * cz, }
			end
		end
		for r = 0, max_r do
			if #list + #layer >= limit then
				break
			end
			if r == 0 then
				try(ci, cj)
			end
			for k = -r, r - 1 do
				try(ci + k, cj - r)
				try(ci + r, cj + k)
				try(ci - k, cj + r)
				try(ci - r, cj - k)
			end
		end
		table.sort(layer, function(a, b)
			return a.d < b.d
		end)
		for _, c in ipairs(layer) do
			if #list >= limit then
				return list
			end
			list[#list + 1] = c
		end
		if #list >= limit then
			return list
		end
	end
	return list
end

function cb_dimensions.find(dim, want, callback)
	local list = cb_dimensions.candidates(dim, MAX_CHECKS)
	local found, k = {}, 0
	local function nxt()
		k = k + 1
		if #found >= want or k > #list or k > MAX_CHECKS then
			return callback(found)
		end
		local c = list[k]
		cb_core.check_area(c.minp, c.maxp, function(res)
			if res.ok then
				found[#found + 1] = c
			end
			nxt()
		end)
	end
	nxt()
end
