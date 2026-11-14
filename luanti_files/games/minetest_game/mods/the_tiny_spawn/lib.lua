-- Building toolkit used by the districts.
-- Coordinates: a "frame" m maps local (u, v) to world-relative (x, z).
-- h is the height above the spawn floor (h = 0 is the floor layer).
local MN = "the_tiny_spawn:"
local B = {}
B.__index = B

local floor, abs, sqrt, max, min = math.floor, math.abs, math.sqrt, math.max, math.min

function B.new(P, g)
	return setmetatable({P = P, g = g, gh = {}, region = {}}, B)
end

-- deterministic hash noise in [0, 1)
local bit = bit or bit32
function B.hash(x, z, seed)
	local n = bit.tobit(x * 374761393 + z * 668265263 + (seed or 0) * 1442695041)
	n = bit.bxor(n, bit.rshift(n, 13))
	n = bit.tobit((n % 65536) * 1274126177 + bit.rshift(n, 16) * 40503)
	n = bit.bxor(n, bit.rshift(n, 16))
	return (n % 100000) / 100000
end
local hash = B.hash

-- smooth value noise
function B.noise(x, z, scale, seed)
	local fx, fz = x / scale, z / scale
	local x0, z0 = floor(fx), floor(fz)
	local tx, tz = fx - x0, fz - z0
	tx, tz = tx * tx * (3 - 2 * tx), tz * tz * (3 - 2 * tz)
	local a, b = hash(x0, z0, seed), hash(x0 + 1, z0, seed)
	local c, d = hash(x0, z0 + 1, seed), hash(x0 + 1, z0 + 1, seed)
	return (a + (b - a) * tx) * (1 - tz) + (c + (d - c) * tx) * tz
end

-- node name if registered, else fallback
local avail = {}
function B.pick(name, fallback)
	local r = avail[name]
	if r == nil then
		r = minetest.registered_nodes[name] ~= nil
		avail[name] = r
	end
	if r then return name end
	return fallback
end

function B:xz(m, u, v) return m[1] * u + m[2] * v, m[3] * u + m[4] * v end
function B:put(m, u, h, v, name, p2)
	local x, z = self:xz(m, u, v)
	self.P.set(x, h, z, name, p2)
end
function B:get(m, u, h, v)
	local x, z = self:xz(m, u, v)
	return self.P.get(x, h, z)
end
function B:put_if_air(m, u, h, v, name, p2)
	if self:get(m, u, h, v) == "air" then self:put(m, u, h, v, name, p2) end
end
function B:fill(m, u1, u2, h1, h2, v1, v2, name, p2)
	for u = u1, u2 do for v = v1, v2 do for h = h1, h2 do
		self:put(m, u, h, v, name, p2)
	end end end
end

-- ground height tracking (top solid layer) in world-relative coords
function B:ground_xz(x, z) return self.gh[x * 4096 + z] or 0 end
function B:set_ground_xz(x, z, h) self.gh[x * 4096 + z] = h end
function B:ground(m, u, v) return self:ground_xz(self:xz(m, u, v)) end
function B:set_ground(m, u, v, h)
	local x, z = self:xz(m, u, v)
	self.gh[x * 4096 + z] = h
end

-- facedir from a world direction (where the "back" of the node points)
local function facedir_world(dx, dz)
	if abs(dz) >= abs(dx) then return dz > 0 and 0 or 2 end
	return dx > 0 and 1 or 3
end
local UPSIDE = {[0] = 20, [1] = 23, [2] = 22, [3] = 21}
function B:facedir(m, du, dv, upside)
	local dx, dz = self:xz(m, du, dv)
	local f = facedir_world(dx, dz)
	return upside and UPSIDE[f] or f
end
-- stair whose high back points to local direction (du, dv)
function B:stair(m, u, h, v, mat, du, dv, upside)
	self:put(m, u, h, v, "stairs:stair_" .. mat, self:facedir(m, du, dv, upside))
end
function B:slab(m, u, h, v, mat, top)
	self:put(m, u, h, v, "stairs:slab_" .. mat, top and 20 or 0)
end

------------------------------------------------------------------------------
-- textures / materials
------------------------------------------------------------------------------
-- clustered mix: list of {name, weight}
function B.mix(list, x, z, seed, scale)
	local t = B.noise(x, z, scale or 2.2, seed) * 0.75 + hash(x, z, seed + 7) * 0.25
	local acc = 0
	for _, e in ipairs(list) do
		acc = acc + e[2]
		if t < acc then return e[1] end
	end
	return list[#list][1]
end

B.PAVE = {{"default:stonebrick", 0.5}, {"default:stone_block", 0.18}, {"default:cobble", 0.2}, {"default:mossycobble", 1}}
B.PAVE_WARM = {{"default:silver_sandstone_brick", 0.45}, {"default:silver_sandstone_block", 0.25},
	{"default:sandstonebrick", 0.18}, {"default:stonebrick", 1}}
B.CLIFF = {{"default:stone", 0.45}, {"default:cobble", 0.2}, {"default:mossycobble", 0.2}, {"default:gravel", 1}}

function B:floor(m, u, v, list, seed)
	local x, z = self:xz(m, u, v)
	local name = type(list) == "string" and list or B.mix(list, x, z, seed or 5)
	self.P.set(x, 0, z, name)
end

------------------------------------------------------------------------------
-- region masks (set by the layout): returns distance to the edge of the
-- buildable region, <= 0 means outside
------------------------------------------------------------------------------
function B:room(m, u, v)
	local x, z = self:xz(m, u, v)
	return self.region_fn(x, z)
end

------------------------------------------------------------------------------
-- terrain
------------------------------------------------------------------------------
-- mound: rad, height; opts.cliff = {du, dv} side that becomes a cliff
function B:mound(m, cu, cv, rad, height, seed, opts)
	opts = opts or {}
	local hmap = {}
	local R = floor(rad * 1.4) + 2
	for du = -R, R do
		for dv = -R, R do
			local u, v = cu + du, cv + dv
			local d = sqrt(du * du + dv * dv)
			local n = B.noise(u, v, 3.5, seed) - 0.5
			local rr = rad * (1 + n * 0.45)
			local k
			if opts.cliff and (du * opts.cliff[1] + dv * opts.cliff[2]) > 0 then
				k = min(1, max(0, (rr - d) / 1.2))         -- steep side
			else
				k = min(1, max(0, (rr - d) / (rr * 0.75)))  -- gentle side
				k = k * k * (3 - 2 * k)
			end
			local room = self:room(m, u, v)
			k = k * min(1, max(0, (room - 1) / 3))
			local h = floor(height * k + (B.noise(u, v, 2, seed + 3) - 0.5) * 1.5 * k + 0.5)
			if h > 0 then hmap[du * 1000 + dv] = h end
		end
	end
	for key, h in pairs(hmap) do
		local du = floor((key + 500) / 1000)
		local dv = key - du * 1000
		local u, v = cu + du, cv + dv
		local lowest = h
		for _, o in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
			lowest = min(lowest, hmap[(du + o[1]) * 1000 + dv + o[2]] or 0)
		end
		local steep = h - lowest >= 2
		local x, z = self:xz(m, u, v)
		for hh = 0, h do
			local name
			if steep and hh > lowest then
				name = B.mix(B.CLIFF, x + hh * 7, z, seed + 11, 1.6)
			elseif hh == h then
				name = "default:dirt_with_grass"
			else
				name = "default:dirt"
			end
			self.P.set(x, hh, z, name)
		end
		if steep and hash(x, z, seed) < 0.5 then
			self.P.set(x, h, z, "default:dirt_with_grass")
		end
		self:set_ground_xz(x, z, h)
	end
	return hmap
end

-- irregular pond; returns set of water cells (local keys)
function B:pond(m, cu, cv, rad, seed, opts)
	opts = opts or {}
	local cells = {}
	local R = floor(rad * 1.4) + 2
	for du = -R, R do
		for dv = -R, R do
			local u, v = cu + du, cv + dv
			local d = sqrt(du * du + dv * dv)
			local rr = rad * (0.8 + B.noise(u, v, 3, seed) * 0.45)
			if d < rr and self:room(m, u, v) >= 2 then
				cells[du * 1000 + dv] = true
				local deep = d < rr - 1.5
				self:put(m, u, deep and -3 or -2, v, deep and "default:clay" or "default:sand")
				self:put(m, u, -1, v, "default:water_source")
				if deep then self:put(m, u, -2, v, "default:water_source") end
				self:put(m, u, 0, v, "default:water_source")
				self:set_ground(m, u, v, -1)
			end
		end
	end
	-- shore
	for key in pairs(cells) do
		local du = floor((key + 500) / 1000)
		local dv = key - du * 1000
		for _, o in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {-1, -1}, {1, -1}, {-1, 1}}) do
			local k2 = (du + o[1]) * 1000 + dv + o[2]
			if not cells[k2] then
				local u, v = cu + du + o[1], cv + dv + o[2]
				local x, z = self:xz(m, u, v)
				if self:get(m, u, 0, v) == "default:dirt_with_grass" then
					self.P.set(x, 0, z, B.mix({{"default:sand", 0.45}, {"default:gravel", 0.2},
						{"default:dirt_with_grass", 1}}, x, z, seed + 2, 1.5))
				end
			end
		end
	end
	return cells
end

------------------------------------------------------------------------------
-- vegetation
------------------------------------------------------------------------------
local function blob(self, m, cu, ch, cv, r, leaves, rng, glow, glow_share)
	local R = floor(r + 1)
	for du = -R, R do for dv = -R, R do for dh = -R, R do
		local d = sqrt(du * du + dv * dv + dh * dh * 1.8)
		if d <= r + (rng:next(0, 100) / 100 - 0.5) * 0.9 then
			local name = leaves
			if glow and rng:next(0, 100) < glow_share then name = glow end
			self:put_if_air(m, cu + du, ch + dh, cv + dv, name)
		end
	end end end
end

-- hanging vines under leaf blocks in a box
function B:vines(m, cu, cv, r, h1, h2, rng, chance, vine)
	vine = vine or MN .. "glow_vine"
	for du = -r, r do for dv = -r, r do
		for h = h2, h1, -1 do
			local n = self:get(m, cu + du, h, cv + dv)
			if n and n:find("leaves") and self:get(m, cu + du, h - 1, cv + dv) == "air"
					and rng:next(0, 100) < chance then
				local len = rng:next(1, 4)
				for k = 1, len do
					if self:get(m, cu + du, h - k, cv + dv) ~= "air" or h - k < 2 then break end
					self:put(m, cu + du, h - k, cv + dv, vine)
				end
				break
			end
		end
	end end
end

-- organic tree. kind: oak | sakura | aspen | pine | apple
function B:tree(m, u, v, kind, seed, scale)
	local rng = PcgRandom(seed)
	scale = scale or 1
	local h0 = self:ground(m, u, v)
	local trunk, leaves, glow, gshare = "default:tree", "default:leaves", nil, 0
	if kind == "sakura" then
		trunk, leaves, glow, gshare = "default:acacia_tree", MN .. "neon_leaves", "default:leaves", 0
	elseif kind == "aspen" then
		trunk, leaves = "default:aspen_tree", "default:aspen_leaves"
	elseif kind == "pine" then
		trunk, leaves = "default:pine_tree", "default:pine_needles"
	elseif kind == "jungle" then
		trunk, leaves, glow, gshare = "default:jungletree", "default:jungleleaves", MN .. "neon_leaves", 18
	end
	local H = floor((4 + rng:next(0, 2)) * scale + 0.5)
	if kind == "pine" then
		H = floor((7 + rng:next(0, 3)) * scale)
		for h = 1, H do self:put(m, u, h0 + h, v, trunk) end
		for h = 3, H + 1 do
			local r = max(0, (H + 1 - h) * 0.42) + (h % 2) * 0.6
			for du = -3, 3 do for dv = -3, 3 do
				if du * du + dv * dv <= r * r + 0.3 and not (du == 0 and dv == 0 and h <= H) then
					self:put_if_air(m, u + du, h0 + h, v + dv, leaves)
				end
			end end
		end
		self:put_if_air(m, u, h0 + H + 2, v, leaves)
		return
	end
	-- slightly leaning trunk
	local lu, lv = 0, 0
	local cu, cv = u, v
	for h = 1, H do
		if h > 2 and rng:next(0, 100) < 30 then
			if rng:next(0, 1) == 0 then lu = lu + (rng:next(0, 1) * 2 - 1) else lv = lv + (rng:next(0, 1) * 2 - 1) end
			lu, lv = max(-1, min(1, lu)), max(-1, min(1, lv))
			cu, cv = u + lu, v + lv
		end
		self:put(m, cu, h0 + h, cv, trunk)
	end
	local top = h0 + H
	local nb = rng:next(2, 4)
	local r0 = (kind == "aspen" and 1.6 or 2.3) * scale
	blob(self, m, cu, top + 1, cv, r0 + 0.4, leaves, rng, glow, gshare)
	for b = 1, nb do
		local a = rng:next(0, 359) * math.pi / 180
		local len = floor((2 + rng:next(0, 2)) * scale + 0.5)
		local bu, bv, bh = cu, cv, top - rng:next(0, 2)
		for k = 1, len do
			bu = cu + floor(math.cos(a) * k + 0.5)
			bv = cv + floor(math.sin(a) * k + 0.5)
			if k % 2 == 0 then bh = bh + 1 end
			self:put(m, bu, bh, bv, trunk)
		end
		blob(self, m, bu, bh + 1, bv, r0 * (0.8 + rng:next(0, 30) / 100), leaves, rng, glow, gshare)
	end
	if kind == "apple" then
		for du = -3, 3 do for dv = -3, 3 do for dh = 0, 3 do
			if self:get(m, cu + du, top + dh, cv + dv) == "default:leaves" and rng:next(0, 100) < 6 then
				self:put(m, cu + du, top + dh - 1, cv + dv, "default:apple")
			end
		end end end
	end
	if kind == "sakura" then
		-- petals on the ground below the crown
		for du = -4, 4 do for dv = -4, 4 do
			if rng:next(0, 100) < 35 and du * du + dv * dv <= 14 then
				local g = self:ground(m, cu + du, cv + dv)
				if self:get(m, cu + du, g, cv + dv) == "default:dirt_with_grass" then
					self:put_if_air(m, cu + du, g + 1, cv + dv, MN .. "petals")
				end
			end
		end end
	end
end

function B:bush(m, u, v, leaves, seed, r)
	local rng = PcgRandom(seed)
	local h0 = self:ground(m, u, v)
	r = r or 1.2
	for du = -2, 2 do for dv = -2, 2 do for dh = 1, 2 do
		local d = sqrt(du * du + dv * dv + (dh - 1) * (dh - 1) * 2.5)
		if d <= r + rng:next(0, 50) / 100 then
			self:put_if_air(m, u + du, h0 + dh, v + dv, leaves or "default:bush_leaves")
		end
	end end end
end

------------------------------------------------------------------------------
-- small props
------------------------------------------------------------------------------
function B:lantern_post(m, u, v, height, fence)
	local h0 = self:ground(m, u, v)
	height = height or 3
	for h = 1, height do self:put(m, u, h0 + h, v, fence or "default:fence_junglewood") end
	self:put(m, u, h0 + height + 1, v, MN .. "solar_lantern")
end

function B:bench(m, u, v, du, dv)  -- seat with its back toward (du, dv)
	self:stair(m, u, self:ground(m, u, v) + 1, v, "junglewood", du, dv)
end

function B:stone_lantern(m, u, v)
	local h0 = self:ground(m, u, v)
	self:put(m, u, h0 + 1, v, "default:stonebrick")
	self:put(m, u, h0 + 2, v, B.pick("walls:cobble", "default:fence_wood"))
	self:put(m, u, h0 + 3, v, MN .. "solar_lantern")
	self:put(m, u, h0 + 4, v, "stairs:slab_obsidianbrick")
end

function B:planter(m, u, h, v, plant)
	self:put(m, u, h, v, "default:dirt_with_grass")
	if plant then self:put_if_air(m, u, h + 1, v, plant) end
end

------------------------------------------------------------------------------
-- buildings
------------------------------------------------------------------------------
-- cottage: occupies u0..u0+w-1, v0..v0+d-1, ridge along u.
-- opts: wall, frame, roof (stair material), door = "-u"|"+u"|"-v"|"+v", base
function B:house(m, u0, v0, w, d, H, opts)
	opts = opts or {}
	local wall = opts.wall or "default:silver_sandstone_block"
	local frame = opts.frame or "default:junglewood"
	local post = opts.post or "default:tree"
	local roof = opts.roof or "obsidianbrick"
	local base = opts.base or "default:stonebrick"
	local u1, v1 = u0 + w - 1, v0 + d - 1
	for u = u0 - 1, u1 + 1 do for v = v0 - 1, v1 + 1 do
		local edge = u < u0 or u > u1 or v < v0 or v > v1
		self:put(m, u, 0, v, edge and B.mix(B.PAVE, u, v, 31) or "default:junglewood")
		for h = 1, H + 1 + floor(d / 2) + 1 do
			if not edge then self:put(m, u, h, v, "air") end
		end
	end end
	for u = u0, u1 do for v = v0, v1 do
		local eu, ev = (u == u0 or u == u1), (v == v0 or v == v1)
		if eu or ev then
			for h = 1, H do
				local name = wall
				if eu and ev then name = post
				elseif h == 1 then name = base
				elseif h == H then name = frame
				elseif h == 2 or h == 3 then
					local along = eu and (v - v0) or (u - u0)
					local len = eu and d or w
					if along % 2 == 0 and along > 0 and along < len - 1 then name = opts.glass or "default:glass" end
				end
				self:put(m, u, h, v, name, (name == post) and 0 or nil)
			end
		end
	end end
	-- floor-2 beams
	if H >= 7 then
		for u = u0 + 1, u1 - 1 do for v = v0 + 1, v1 - 1 do
			self:put(m, u, 4, v, "default:junglewood")
		end end
		self:put(m, u0 + 1, 4, v0 + 1, "air")
	end
	-- door
	local du, dv, cu, cv
	local door = opts.door or "-u"
	if door == "-u" then cu, cv, du, dv = u0, v0 + floor(d / 2), -1, 0
	elseif door == "+u" then cu, cv, du, dv = u1, v0 + floor(d / 2), 1, 0
	elseif door == "-v" then cu, cv, du, dv = u0 + floor(w / 2), v0, 0, -1
	else cu, cv, du, dv = u0 + floor(w / 2), v1, 0, 1 end
	self:put(m, cu, 1, cv, "air")
	self:put(m, cu, 2, cv, "air")
	-- lanterns either side of the door
	local su, sv = dv ~= 0 and 1 or 0, du ~= 0 and 1 or 0
	self:put(m, cu + du + su * 1, 1, cv + dv + sv * 1, "default:fence_junglewood")
	self:put(m, cu + du + su * 1, 2, cv + dv + sv * 1, MN .. "solar_lantern")
	self:put(m, cu + du - su * 1, 1, cv + dv - sv * 1, "default:bush_leaves")
	-- gable roof (ridge along u), 1 node overhang
	local k = 0
	while true do
		local va, vb = v0 - 1 + k, v1 + 1 - k
		local h = H + 1 + k
		if va > vb then break end
		for u = u0 - 1, u1 + 1 do
			if va == vb then
				self:slab(m, u, h, va, roof)
			else
				self:stair(m, u, h, va, roof, 0, 1)
				self:stair(m, u, h, vb, roof, 0, -1)
			end
		end
		-- gable walls
		for v = va + 1, vb - 1 do
			self:put(m, u0, h, v, (v - v0) % 3 == 1 and frame or wall)
			self:put(m, u1, h, v, (v - v0) % 3 == 1 and frame or wall)
		end
		k = k + 1
	end
	-- warm light inside
	self:put(m, u0 + floor(w / 2), H, v0 + floor(d / 2), "default:meselamp")
	-- flower boxes under side windows
	for u = u0 + 2, u1 - 2, 2 do
		self:put_if_air(m, u, 1, v0 - 1, "default:bush_leaves")
		self:put_if_air(m, u, 1, v1 + 1, "default:bush_leaves")
	end
	return cu + du, cv + dv
end

-- hemisphere dome, shell of glass with ribs
function B:dome(m, cu, cv, h0, r, glass, rib)
	local R = floor(r + 1)
	for du = -R, R do for dv = -R, R do for dh = 0, R do
		local d = sqrt(du * du + dv * dv + dh * dh)
		local u, v = cu + du, cv + dv
		if d < r + 0.5 then
			if d >= r - 0.5 then
				local isrib = du == 0 or dv == 0 or abs(du) == abs(dv) or dh == 0
				self:put(m, u, h0 + dh, v, isrib and rib or glass)
			else
				self:put(m, u, h0 + dh, v, "air")
			end
		end
	end end end
end

-- pixel text, 3x5 font, drawn along +side direction (su, sv) from (u, v)
local FONT = {
	T = {"###", ".#.", ".#.", ".#.", ".#."}, I = {"###", ".#.", ".#.", ".#.", "###"},
	N = {"##.", "#.#", "#.#", "#.#", "#.#"}, Y = {"#.#", "#.#", ".#.", ".#.", ".#."},
	S = {"###", "#..", "###", "..#", "###"}, H = {"#.#", "#.#", "###", "#.#", "#.#"},
	E = {"###", "#..", "##.", "#..", "###"}, L = {"#..", "#..", "#..", "#..", "###"},
	R = {"##.", "#.#", "##.", "#.#", "#.#"}, C = {"###", "#..", "#..", "#..", "###"},
	A = {".#.", "#.#", "###", "#.#", "#.#"}, F = {"###", "#..", "##.", "#..", "#.."},
}
B.FONT = FONT
-- big 5x7 font for the gate billboards
local FONT57 = {
	S = {".####", "#....", "#....", ".###.", "....#", "....#", "####."},
	P = {"####.", "#...#", "#...#", "####.", "#....", "#....", "#...."},
	A = {".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"},
	W = {"#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"},
	N = {"#...#", "##..#", "#.#.#", "#.#.#", "#..##", "#...#", "#...#"},
}
B.FONT57 = FONT57
local function font_dims(font)
	local any = next(font)
	local gl = font[any]
	return #gl[1], #gl
end
function B.text_width(str, font)
	local w = font_dims(font or FONT)
	return #str * (w + 1) - 1
end
function B:text(m, u, v, top_h, str, name, su, sv, font)
	font = font or FONT
	local w, h = font_dims(font)
	local x0 = 0
	for i = 1, #str do
		local gl = font[str:sub(i, i)]
		if gl then
			for row = 1, h do for c = 1, w do
				if gl[row]:sub(c, c) == "#" then
					local k = x0 + c - 1
					self:put(m, u + su * k, top_h - row + 1, v + sv * k, name)
				end
			end end
		end
		x0 = x0 + w + 1
	end
end

return B
