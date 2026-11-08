-- Woodland mansion (spec cycle 2, 5.2). mansion_grid.lua plans the cells;
-- this file ports Mineclonia's storey, wall and facade pieces (GPLv3) as
-- operations in Mineclonia's level coordinates (level (x, y, z) -> map
-- (ax + x, ay + y, az - z), as in piecegen), cuts the box into 16-node
-- columns (one build piece each, operations clipped to it) and makes every
-- room a part: vindicators come back, evokers too in rooms of 600 nodes and
-- more (halls).
local S = cb_structures.S
local VS, VP, VL, SU = cb_structures.village_schem, cb_structures.village_palettes, cb_structures.village,
	cb_structures.surface
local A, MG = cb_structures.piecegen, cb_structures.mansion_grid
local MS = { UNIT = 8, H1 = 8, H2 = 11, COLUMN = 16, HALL = 600, SITE_RADIUS = 24,
	FOUNDATION = 20, LEVEL = { wet = 0.15, cut = 10, fill = 16, }, }
cb_structures.mansion = MS
local UNIT, H1, H2 = MS.UNIT, MS.H1, MS.H2
local BASE = MG.BASE_WIDTH
local band = bit.band
local NORTH, WEST, SOUTH, EAST = 0x1, 0x2, 0x4, 0x8
local ROT_K = { ["0"] = 0, ["90"] = 1, ["180"] = 2, ["270"] = 3, }
local ROTATIONS = { "0", "90", "180", "270", }
local FACING_ROT = { north = "180", south = "0", west = "90", east = "270", }
local PALETTE = "plains"
local VN, EV = "cb_mobs_illager:vindicator", "cb_mobs_illager:evoker"
local IL = "cb_mobs_illager:illusioner"

local function node(role)
	return (VP.resolve(PALETTE, role))
end

-- Operations: fill boxes, schematics, ground (foundation and clearing, run
-- before everything else). W.lo/W.hi: the map box of all of them.
local function recorder(ax, ay, az)
	local W, ground, rest = {}, {}, {}
	local function grow(a, b)
		W.lo = W.lo and vector.new(math.min(W.lo.x, a.x), math.min(W.lo.y, a.y), math.min(W.lo.z, a.z)) or vector.copy(a)
		W.hi = W.hi and vector.new(math.max(W.hi.x, b.x), math.max(W.hi.y, b.y), math.max(W.hi.z, b.z)) or vector.copy(b)
	end
	function W.box(x1, y1, z1, x2, y2, z2)
		return vector.new(ax + math.min(x1, x2), ay + math.min(y1, y2), az - math.max(z1, z2)),
			vector.new(ax + math.max(x1, x2), ay + math.max(y1, y2), az - math.min(z1, z2))
	end
	-- Mineclonia's fill_area: x and z in any order, nothing when y1 > y2.
	function W.fill(x1, y1, z1, x2, y2, z2, name, p2)
		if y1 > y2 then
			return
		end
		local a, b = W.box(x1, y1, z1, x2, y2, z2)
		rest[#rest + 1] = { t = "fill", a = a, b = b, node = name, p2 = p2 or 0, }
		grow(a, b)
	end
	function W.set(x, y, z, name, p2)
		W.fill(x, y, z, x, y, z, name, p2)
	end
	-- Mineclonia's place_schematic: the turned schematic's level box starts
	-- at (x, y, z). Returns its turned size.
	function W.schem(x, y, z, name, rot, loot)
		local s = VS.get(name)
		local k = ROT_K[rot]
		local w, d = VS.footprint(s, k)
		local a = vector.new(ax + x, ay + y, az - (z + d - 1))
		local b = vector.offset(a, w - 1, s.y - 1, d - 1)
		rest[#rest + 1] = { t = "schem", a = a, b = b, s = name, k = k, loot = loot, }
		grow(a, b)
		return w, s.y, d
	end
	-- Foundation under (x1, z1)-(x2, z2) down to FOUNDATION below the floor,
	-- natural clutter and ground above the floor cleared up to top.
	function W.ground(x1, z1, x2, z2, top)
		local a, b = W.box(x1, -MS.FOUNDATION, z1, x2, top, z2)
		ground[#ground + 1] = { t = "ground", a = a, b = b, floor = ay, }
		grow(a, b)
	end
	function W.all()
		local all = table.copy(ground)
		for _, op in ipairs(rest) do
			all[#all + 1] = op
		end
		return all
	end
	return W
end

local function corridor_test(ax, az, bx, bz, mod_a, mod_b)
	if mod_a.type ~= "corridor" or not mod_b.facing or mod_b.type == "secret" then
		return false
	end
	local f = mod_b.facing
	if mod_b.type == "quad" then
		local origin = f == "north" and bx == mod_b.x and bz == mod_b.z
			or f == "east" and bx == mod_b.x + 1 and bz == mod_b.z
			or f == "south" and bx == mod_b.x + 1 and bz == mod_b.z + 1
			or f == "west" and bx == mod_b.x and bz == mod_b.z + 1
		if not origin then
			return false
		end
	end
	local dx = f == "west" and -1 or f == "east" and 1 or 0
	local dz = f == "north" and -1 or f == "south" and 1 or 0
	return bx + dx == ax and bz + dz == az
end

-- Mineclonia's place_walls: what separates cell (mx, mz) from its west
-- (lengthwise) or north neighbour.
local function walls_between(W, y, ytop, modules, mx, mz, lengthwise, rot)
	local idx_a = mz * BASE + mx + 1
	local ma = modules[idx_a]
	local mb, bx, bz, check_entrance
	if lengthwise then
		mb, bx, bz = modules[idx_a - 1], mx - 1, mz
		check_entrance = rot == "0" or rot == "180"
	else
		mb, bx, bz = modules[idx_a - BASE], mx, mz - 1
		check_entrance = rot == "90" or rot == "270"
	end
	if ma == mb then
		return
	end
	local turned = lengthwise and "90" or "0"
	local schem, r
	if check_entrance and ma and mb and (ma.type == "corridor" and mb.type == "entrance"
			or mb.type == "corridor" and ma.type == "entrance") then
		schem, r = "mansion_carpet_strip", turned
	elseif ma and mb and ma.type == "corridor" and mb.type == "corridor" then
		schem, r = "mansion_corridor_separator", turned
	elseif ma and mb and (corridor_test(mx, mz, bx, bz, ma, mb) or corridor_test(bx, bz, mx, mz, mb, ma)) then
		schem, r = "mansion_door", lengthwise and "270" or "180"
	else
		schem, r = "mansion_wall", turned
	end
	local x1, z1 = mx * UNIT, mz * UNIT
	W.schem(x1, y, z1, schem, r)
	if ytop >= y + H1 then
		if lengthwise then
			W.fill(x1, y + H1, z1, x1, ytop, z1 + UNIT - 1, node("dark_wood"))
		else
			W.fill(x1, y + H1, z1, x1 + UNIT - 1, ytop, z1, node("dark_wood"))
		end
	end
end

local function place_module(W, mod, gx, gz, y, ytop, rooms)
	local x, z = (mod.x or gx) * UNIT + 1, (mod.z or gz) * UNIT + 1
	local sx, sy, sz = W.schem(x, y, z, mod.module[1], FACING_ROT[mod.facing], mod.module[2])
	if y + sy <= ytop then
		W.fill(x, y + sy, z, x + sx - 1, ytop, z + sz - 1, "air")
	end
	if mod.type ~= "corridor" and mod.type ~= "secret" then
		local a, b = W.box(x, y, z, x + sx - 1, math.max(ytop, y + sy - 1), z + sz - 1)
		rooms[#rooms + 1] = { minp = a, maxp = b, }
	end
end

local function storey(W, m, grid, y, ytop, ignore_foyer, rooms)
	local modules, placed = grid.modules, {}
	for gz = m.zmin, m.zmax do
		for gx = m.xmin, m.xmax do
			local mod = modules[gz * BASE + gx + 1]
			if type(mod) == "table" then
				if not placed[mod] and not (ignore_foyer and mod.type == "entrance") then
					placed[mod] = true
					place_module(W, mod, gx, gz, y, ytop, rooms)
				end
				if gx > 0 then
					walls_between(W, y, ytop, modules, gx, gz, true, m.rot)
				end
				if gz > 0 then
					walls_between(W, y, ytop, modules, gx, gz, false, m.rot)
				end
			end
		end
	end
end

-- Mineclonia's mansion_wall_place: outer walls, ceiling, foundation, eaves.
local function exterior(W, m)
	local ymax = H1 + H2 - 1
	local dark, stair, outer = node("dark_wood"), node("dark_stair"), node("dark_stair_outer")
	local m1, m2 = m.grids[1].modules, m.grids[2].modules
	for gz = m.zmin, m.zmax do
		for gx = m.xmin, m.xmax do
			local idx = gz * BASE + gx + 1
			local value = m.outline[idx] or 0
			local ix1, iz1 = gx * UNIT, gz * UNIT
			local ix2, iz2 = ix1 + UNIT, iz1 + UNIT
			local north, south = band(value, NORTH) ~= 0, band(value, SOUTH) ~= 0
			local west, east = band(value, WEST) ~= 0, band(value, EAST) ~= 0
			local a = m1[idx]
			local foyer = a and a.type == "entrance" and a.facing
			if north and foyer ~= "north" then
				W.schem(ix1, 0, iz1 - 1, "mansion_exterior_wall_flipped", "0")
			end
			if south and foyer ~= "south" then
				W.schem(ix1, 0, iz2, "mansion_exterior_wall", "0")
			end
			if west and foyer ~= "west" then
				W.schem(ix1 - 1, 0, iz1, "mansion_exterior_wall", "90")
			end
			if east and foyer ~= "east" then
				W.schem(ix2, 0, iz1, "mansion_exterior_wall_flipped", "90")
			end
			if a or m2[idx] then
				W.fill(ix1, ymax + 1, iz1, ix2, ymax + 3, iz2, dark)
				W.ground(ix1 - 1, iz1 - 1, ix2 + 1, iz2 + 1, ymax + 5)
			end
			for d = 0, 2 do
				local y = ymax + 3 - d
				if north then
					local x1, x2, z = ix1 - d + (west and 1 or 0), ix1 + UNIT + d, iz1 - d
					W.fill(x1, y, z, x2, y, z, stair, 2)
					if east then
						W.set(x2, y, z, outer, 3)
					end
				end
				if east then
					local z1, z2, x = iz1 - d + (north and 1 or 0), iz1 + UNIT + d, ix1 + UNIT + d
					W.fill(x, y, z1, x, y, z2, stair, 3)
					if south then
						W.set(x, y, z2, outer, 0)
					end
				end
				if south then
					local x1, x2, z = ix2 - UNIT - d, ix2 + d - (east and 1 or 0), iz1 + UNIT + d
					W.fill(x1, y, z, x2, y, z, stair, 0)
					if west then
						W.set(x1, y, z, outer, 1)
					end
				end
				if west then
					local z1, z2, x = iz2 - UNIT - d, iz2 + d - (south and 1 or 0), ix1 - d
					W.fill(x, y, z1, x, y, z2, stair, 1)
					if north then
						W.set(x, y, z1, outer, 2)
					end
				end
			end
		end
	end
end

-- Mineclonia's prepare_mansion_foyer_wall: the facade before the foyer.
local function facade(W, grid, rot)
	local fx, fz
	for dx = 0, grid.width - 1 do
		for dz = 0, grid.length - 1 do
			local v = MG.value(grid, dx, dz)
			if not fx and type(v) == "table" and v.type == "entrance" then
				fx, fz = dx, dz
			end
		end
	end
	local x, z, name
	if rot == "0" then
		x, z, name = fx * UNIT, fz * UNIT - 5, "mansion_entrance_facade_flipped"
	elseif rot == "90" then
		x, z, name = (fx + 1) * UNIT + UNIT, fz * UNIT, "mansion_entrance_facade_flipped"
	elseif rot == "270" then
		x, z, name = fx * UNIT - 5, fz * UNIT, "mansion_entrance_facade"
	else
		x, z, name = fx * UNIT, (fz + 1) * UNIT + UNIT, "mansion_entrance_facade"
	end
	local w, h, d = W.schem(x, 0, z, name, (rot == "0" or rot == "180") and "0" or "90")
	-- the steps get a foundation like the walls (none in Mineclonia, where
	-- the terrain is flattened for the mansion first)
	W.ground(x, z, x + w - 1, z + d - 1, h - 1)
end

-- The grid of seed: rotation, grids, outline and the cells in use. The last
-- one is kept: plan, layout and the build job of one placement share it
-- (operations only read it).
local last
local function mansion(seed)
	if last and last.seed == seed then
		return last
	end
	local rot = ROTATIONS[1 + A.rng(seed):next_within(4)]
	local grids, outline = MG.prepare(A.rng(seed + 1), rot)
	local m = { seed = seed, rot = rot, grids = grids, outline = outline, xmin = BASE, zmin = BASE, xmax = -1, zmax = -1, }
	for gz = 0, BASE - 1 do
		for gx = 0, BASE - 1 do
			local idx = gz * BASE + gx + 1
			if (outline[idx] or 0) ~= 0 or grids[1].modules[idx] or grids[2].modules[idx] then
				m.xmin, m.xmax = math.min(m.xmin, gx), math.max(m.xmax, gx)
				m.zmin, m.zmax = math.min(m.zmin, gz), math.max(m.zmax, gz)
			end
		end
	end
	last = m
	return m
end

-- Operations of the mansion of seed with level (0, 0, 0) at map (ax, ay, az),
-- ay = the floor; rooms: map boxes of the rooms and halls.
function MS.ops(seed, ax, ay, az)
	local m = mansion(seed)
	local W, rooms = recorder(ax, ay, az), {}
	storey(W, m, m.grids[1], 0, H1 - 1, false, rooms)
	storey(W, m, m.grids[2], H1, H1 + H2 - 1, true, rooms)
	exterior(W, m)
	facade(W, m.grids[1], m.rot)
	return W, rooms
end

function MS.plan(origin, seed)
	local W = MS.ops(seed, 0, 0, 0)
	local w, d = W.hi.x - W.lo.x + 1, W.hi.z - W.lo.z + 1
	local y, x1, z1 = SU.site(origin, w, d, W.hi.y, { level = MS.LEVEL, below = MS.FOUNDATION,
		radius = MS.SITE_RADIUS, })
	if not y then
		return nil, x1
	end
	return { v = "mansion", x = x1 - W.lo.x, y = y, z = z1 - W.lo.z, }
end

local function run(ctx, ops, lo, hi)
	local spawns = {}
	for _, op in ipairs(ops) do
		if op.t == "fill" then
			ctx.fill(op.a, op.b, op.node, op.p2)
		elseif op.t == "ground" then
			local a, b = cb_core.intersect(op.a, op.b, lo, hi)
			VL.ground_piece(ctx, a, b, op.floor, PALETTE, true)
		else
			local s = VS.get(op.s)
			VS.place(ctx, s, op.a, op.k, PALETTE, op.loot)
			for kind, mob in pairs({ mark_vindicator = VN, mark_evoker = EV, }) do
				for _, p in ipairs(VS.world_marks(s, op.k, op.a, kind)) do
					if cb_core.inside(p, lo, hi) then
						spawns[#spawns + 1] = { p, mob, }
					end
				end
			end
		end
	end
	if #spawns > 0 then
		ctx.after(function()
			for _, sp in ipairs(spawns) do
				if core.registered_entities[sp[2]] then
					core.add_entity(sp[1], sp[2])
				end
			end
		end)
	end
end

function MS.layout(origin, seed, plan)
	local W, rooms = MS.ops(seed, plan.x, plan.y, plan.z)
	local ops, pieces, C = W.all(), {}, MS.COLUMN
	-- columns on mapblock borders: each one reads and writes whole mapblocks
	local x0, z0 = math.floor(W.lo.x / C) * C, math.floor(W.lo.z / C) * C
	for x = x0, W.hi.x, C do
		for z = z0, W.hi.z, C do
			local lo = vector.new(math.max(x, W.lo.x), W.lo.y, math.max(z, W.lo.z))
			local hi = vector.new(math.min(x + C - 1, W.hi.x), W.hi.y, math.min(z + C - 1, W.hi.z))
			local mine = {}
			for _, op in ipairs(ops) do
				if cb_core.intersect(op.a, op.b, lo, hi) then
					mine[#mine + 1] = op
				end
			end
			if #mine > 0 then
				pieces[#pieces + 1] = { minp = lo, maxp = hi, build = function(ctx)
					run(ctx, mine, lo, hi)
				end, }
			end
		end
	end
	for _, r in ipairs(rooms) do
		local v = (r.maxp.x - r.minp.x + 1) * (r.maxp.y - r.minp.y + 1) * (r.maxp.z - r.minp.z + 1)
		pieces[#pieces + 1] = { minp = r.minp, maxp = r.maxp, part = true, kind = v >= MS.HALL and "hall" or "room", }
	end
	return { minp = W.lo, maxp = W.hi, pieces = pieces, plan = plan, }
end

local function norm(_, part)
	local v = (part.maxp.x - part.minp.x + 1) * (part.maxp.y - part.minp.y + 1) * (part.maxp.z - part.minp.z + 1)
	return math.max(0, math.min(2, math.floor(v / 300)))
end

cb_structures.register("mansion", {
	description = S("Woodland Mansion"),
	dims = { "overworld", },
	biome_words = { "forest", "taiga", "coniferous", "rainforest", "jungle", "birch", "grove", },
	prepare = { radius = 112, below = 24, above = 48, },
	plan = MS.plan,
	layout = MS.layout,
	self_checked = true,
	inhabitants = { kinds = {
		room = { mobs = { { VN, 1, }, }, norm = norm, },
		hall = { mobs = { { VN, 3, }, { EV, 1, "e", }, { IL, 1, "i", }, }, norm = norm, }, -- one evoker and one illusioner per hall, rare
	}, },
})
