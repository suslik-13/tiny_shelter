-- Ancient city (plan 8e-3): Secret Terra's layout (st_world/ancient_city.lua)
-- in world coordinates. A cavern (a rounded square, HALF 64 across from the
-- centre, sealed by a RIM of deepslate against caves and liquids) with
-- deepslate streets, sculk patches, sensors and shriekers; in the middle a
-- stepped platform with a reinforced deepslate gate and a hidden vault;
-- around it towers, ruins, camps, halls, ice stores, statues and basalt
-- pillars on a grid. The floor (first air layer) is at origin.y when that is
-- -20 or lower, else at -51. The box is cut into 32x32 columns, each a part.
-- Nobody lives there (as in Bedrock); the warden comes from the shriekers.
-- Chests: Bedrock's ancient_city and ancient_city_ice_box loot, as far as
-- the server has the items.
local S = cb_structures.S
local floor, abs, sqrt, max, min = math.floor, math.abs, math.sqrt, math.max, math.min
local AC = { HALF = 64, RIM = 3, CEILING_MAX = 31, DEEP_Y = -51, TOP_Y = -20, COLUMN = 32, }
cb_structures.ancient_city = AC

local function first(...)
	for _, n in ipairs({ ... }) do
		if core.registered_nodes[n] then
			return n
		end
	end
	return "default:stone"
end

-- Node names are looked up when a city is built (cb_mobs_deep loads later).
local N
local function nodes()
	if N then
		return N
	end
	N = {
		deepslate = "cb_blocks:deepslate", cobbled = "cb_blocks:cobbled_deepslate",
		polished = "cb_blocks:polished_deepslate", bricks = "cb_blocks:deepslate_bricks",
		bricks_cracked = "cb_blocks:cracked_deepslate_bricks", tiles = "cb_blocks:deepslate_tiles",
		tiles_cracked = "cb_blocks:cracked_deepslate_tiles", chiseled = "cb_blocks:chiseled_deepslate",
		reinforced = "cb_blocks:reinforced_deepslate", brick_stair = first("stairs:stair_cb_deepslate_bricks"),
		tile_slab = first("stairs:slab_cb_deepslate_tiles"),
		basalt = first("cb_blocks:polished_basalt", "nether:basalt_chiseled", "nether:basalt"),
		sculk = "cb_mobs_deep:sculk", vein = "cb_mobs_deep:sculk_vein", sensor = "cb_mobs_deep:sculk_sensor",
		shrieker = "cb_mobs_deep:sculk_shrieker", catalyst = "cb_mobs_deep:sculk_catalyst",
		lantern = "cb_blocks:soul_lantern", skull = "cb_blocks:skeleton_skull",
		wool = first("wool:grey"), carpet = first("cb_blocks:carpet_grey", "wool:grey"), ice = "default:ice",
		candles = { "cb_blocks:candle_1", "cb_blocks:candle_2", "cb_blocks:candle_3", "cb_blocks:candle_4", },
	}
	return N
end

-- st_world_lg.hash and vnoise: numbers in [0, 1) from a position and a seed.
local function hash(x, y, z, seed)
	local h = bit.tobit(seed + x * 374761 + y * 668265 + z * 1274126)
	h = bit.tobit(bit.bxor(h, bit.rshift(h, 13)) * 69069 + 1)
	h = bit.tobit(bit.bxor(h, bit.rshift(h, 16)) * 69069 + 7)
	h = bit.bxor(h, bit.rshift(h, 15))
	return bit.band(h, 0xffffff) / 0x1000000
end
AC.hash = hash

local function smooth(t)
	return t * t * (3 - 2 * t)
end
local function vnoise(x, z, cell, seed)
	local fx, fz = x / cell, z / cell
	local gx, gz = floor(fx), floor(fz)
	local tx, tz = smooth(fx - gx), smooth(fz - gz)
	local a, b = hash(gx, 0, gz, seed), hash(gx + 1, 0, gz, seed)
	local c, d = hash(gx, 0, gz + 1, seed), hash(gx + 1, 0, gz + 1, seed)
	local ab, cd = a + (b - a) * tx, c + (d - c) * tx
	return ab + (cd - ab) * tz
end

-- Between a square and a circle, so that the street grid's corners stay inside.
local function shape(dx, dz)
	local adx, adz = abs(dx), abs(dz)
	return max(adx, adz) * 0.75 + sqrt(adx * adx + adz * adz) * 0.25
end
local function edge_of(x, z, seed)
	return AC.HALF - 5 * vnoise(x, z, 12, seed + 11)
end
local function ceiling_y(fy, x, z, d, seed)
	local t = min(1, d / AC.HALF)
	return fy + floor(14 + 12 * (1 - t * t) + 5 * vnoise(x, z, 11, seed + 7))
end
local function on_road(dx, dz)
	return abs(dx) <= 2 or abs(dz) <= 2
end

local liquid = {}
local function is_liquid(name)
	local l = liquid[name]
	if l == nil then
		local def = core.registered_nodes[name]
		l = def ~= nil and (def.liquidtype or "none") ~= "none"
		liquid[name] = l
	end
	return l
end

-- One city being built: c.set/get/chest wrap the build context.
local function city(ctx, cx, fy, cz, seed)
	local c = { cx = cx, fy = fy, cz = cz, seed = seed, ctx = ctx, n = nodes(), }
	function c.set(x, y, z, name, p2)
		ctx.set(vector.new(x, y, z), name, p2)
	end
	function c.seal(x, y, z)
		local name = ctx.get(vector.new(x, y, z))
		if name == "air" or is_liquid(name) then
			c.set(x, y, z, c.n.deepslate)
		end
	end
	return c
end

------------------------------------------------------------------------
-- Cavern, streets and sculk (only the columns xa..xb, za..zb).
------------------------------------------------------------------------
local function road_block(c, x, z)
	local h = hash(x, 1, z, c.seed)
	return h < 0.15 and c.n.tiles_cracked or h < 0.3 and c.n.polished or c.n.tiles
end

local function floor_decoration(c, x, z)
	local h = hash(x, 2, z, c.seed)
	if h < 0.004 then
		c.set(x, c.fy, z, c.n.shrieker, 1)
	elseif h < 0.016 then
		c.set(x, c.fy, z, c.n.sensor)
	elseif h < 0.12 then
		c.set(x, c.fy, z, c.n.vein, 1)
	end
end

local function place_cavern(c, xa, xb, za, zb)
	local fy, n, seed = c.fy, c.n, c.seed
	for x = xa, xb do
		for z = za, zb do
			local dx, dz = x - c.cx, z - c.cz
			local d, edge = shape(dx, dz), edge_of(x, z, seed)
			if d <= edge then
				local top = ceiling_y(fy, x, z, d, seed)
				for y = fy - 4, fy - 2 do
					c.seal(x, y, z)
				end
				local sculk = vnoise(x, z, 7, seed + 3) > 0.55
				if on_road(dx, dz) then
					c.set(x, fy - 1, z, road_block(c, x, z))
				elseif sculk then
					c.set(x, fy - 1, z, n.sculk)
				else
					c.set(x, fy - 1, z, hash(x, 3, z, seed) < 0.2 and n.cobbled or n.deepslate)
				end
				for y = fy, top - 1 do
					c.set(x, y, z, "air")
				end
				-- thick enough to cover the steps between columns of different height
				for y = top, min(top + 4, fy + AC.CEILING_MAX + 2) do
					c.seal(x, y, z)
				end
				if sculk and not on_road(dx, dz) then
					floor_decoration(c, x, z)
				end
			elseif d <= edge + AC.RIM then
				for y = fy - 4, fy + AC.CEILING_MAX + 2 do
					c.seal(x, y, z)
				end
			end
		end
	end
end

------------------------------------------------------------------------
-- Centre: a stepped platform with a reinforced deepslate gate and a
-- hidden vault inside it.
------------------------------------------------------------------------
local GATE = {
	"RRR...................RRR",
	".RRR.................RRR.",
	"..RRRRRRRRRCRRRRRRRRRRR..",
	"..RRRRRRRRRRRRRRRRRRRRR..",
	"..RRR...............RRR..",
	"..RR.................RR..",
	"..RR.................RR..",
	"..RC.................CR..",
	"..RR.................RR..",
	"..RR.................RR..",
	"..RR.................RR..",
	"..RC.................CR..",
	"..RR.................RR..",
	".BRRB...............BRRB.",
	"BBRRBB.............BBRRBB",
	"BBRRBB.............BBRRBB",
}
-- MTG stair facedir climbing towards +x, -x, +z, -z.
local UP_PX, UP_NX, UP_PZ, UP_NZ = 1, 3, 0, 2

local function place_center(c, ctx)
	local cx, cz, fy, n, seed = c.cx, c.cz, c.fy, c.n, c.seed
	for k = 0, 2 do
		local y = fy + k
		local xa, xb, za, zb = -16 + k, 16 - k, -9 + k, 9 - k
		for dx = xa, xb do
			for dz = za, zb do
				local x, z = cx + dx, cz + dz
				local ex, ez = dx == xa or dx == xb, dz == za or dz == zb
				if ex and ez then
					c.set(x, y, z, n.bricks)
				elseif ex then
					c.set(x, y, z, n.brick_stair, dx == xa and UP_PX or UP_NX)
				elseif ez then
					c.set(x, y, z, n.brick_stair, dz == za and UP_PZ or UP_NZ)
				elseif k < 2 then
					c.set(x, y, z, n.bricks)
				else
					local h = hash(x, y, z, seed)
					c.set(x, y, z, h < 0.12 and n.sculk or h < 0.3 and n.tiles_cracked or n.tiles)
				end
			end
		end
	end
	local base, height = fy + 3, #GATE
	local mat = { R = n.reinforced, B = n.bricks, C = n.chiseled, }
	for row = 1, height do
		local line = GATE[row]
		for i = 1, #line do
			local name = mat[line:sub(i, i)]
			if name then
				for dz = -1, 1 do
					c.set(cx + i - 13, base + height - row, cz + dz, name)
				end
			end
		end
	end
	for _, sx in ipairs({ -13, 13, }) do
		for _, sz in ipairs({ -6, 6, }) do
			c.set(cx + sx, base, cz + sz, n.lantern)
		end
		c.set(cx + sx, base, cz, n.catalyst)
	end
	for dx = -9, 9, 3 do
		if hash(cx + dx, base, cz + 4, seed) < 0.6 then
			c.set(cx + dx, base, cz + 4, n.candles[1 + floor(hash(cx + dx, base, cz, seed) * 4)])
		end
	end
	-- the vault, reached by a tunnel under the back steps
	for dx = -5, 5 do
		for dz = -4, 4 do
			c.set(cx + dx, fy - 1, cz + dz, n.polished)
			c.set(cx + dx, fy, cz + dz, "air")
			c.set(cx + dx, fy + 1, cz + dz, "air")
		end
	end
	for dz = 5, 9 do
		c.set(cx, fy, cz + dz, "air")
		c.set(cx, fy + 1, cz + dz, "air")
	end
	c.set(cx - 4, fy, cz - 3, n.candles[3])
	c.set(cx + 4, fy, cz - 3, n.candles[2])
	ctx.chest(vector.new(cx, fy, cz - 4), "ancient_city", 0)
end

------------------------------------------------------------------------
-- Buildings on a grid around the centre, each in a 13x13 box turned one
-- of four ways; ly 0 is the first air layer.
------------------------------------------------------------------------
local function at(b, lx, ly, lz)
	local x, z
	if b.dir == 0 then
		x, z = lx, lz
	elseif b.dir == 1 then
		x, z = 12 - lz, lx
	elseif b.dir == 2 then
		x, z = 12 - lx, 12 - lz
	else
		x, z = lz, 12 - lx
	end
	return b.x + x, b.c.fy + ly, b.z + z
end
local function put(b, lx, ly, lz, name, p2)
	local x, y, z = at(b, lx, ly, lz)
	b.c.set(x, y, z, name, p2)
end
local function roll(b, lx, ly, lz, salt)
	return hash(b.x + lx, ly + salt * 97, b.z + lz, b.seed)
end
local function brick(b, lx, ly, lz)
	return roll(b, lx, ly, lz, 1) < 0.25 and b.c.n.bricks_cracked or b.c.n.bricks
end
local function tile(b, lx, ly, lz)
	return roll(b, lx, ly, lz, 2) < 0.25 and b.c.n.tiles_cracked or b.c.n.tiles
end
local function chest(b, lx, ly, lz, loot)
	local x, y, z = at(b, lx, ly, lz)
	b.c.ctx.chest(vector.new(x, y, z), loot or "ancient_city", 0)
end
local function candle(b, lx, ly, lz)
	put(b, lx, ly, lz, b.c.n.candles[1 + floor(roll(b, lx, ly, lz, 3) * 4)])
end
local function floor_area(b, a, z, pick)
	for lx = a, z do
		for lz = a, z do
			put(b, lx, -1, lz, pick(b, lx, -1, lz))
		end
	end
end

-- Tall ruined tower.
local function tower(b)
	local h = b.height
	floor_area(b, 3, 9, tile)
	for ly = 0, h - 1 do
		local band = ly % 4 == 3
		for lx = 3, 9 do
			for lz = 3, 9 do
				local ex, ez = lx == 3 or lx == 9, lz == 3 or lz == 9
				if ex or ez then
					local window = (ly % 4 == 1 or ly % 4 == 2) and ((lx == 6 and ez) or (lz == 6 and ex))
					local door = lx == 6 and lz == 3 and ly <= 1
					local decay = ly >= h - 4 and roll(b, lx, ly, lz, 4) < (ly - h + 5) * 0.18
					if not (window or door or decay) then
						put(b, lx, ly, lz, ((ex and ez) or band) and tile(b, lx, ly, lz) or brick(b, lx, ly, lz))
					end
				end
			end
		end
	end
	for lx = 3, 9, 2 do
		for _, lz in ipairs({ 3, 9, }) do
			if roll(b, lx, h, lz, 5) < 0.5 then
				put(b, lx, h, lz, brick(b, lx, h, lz))
			end
		end
	end
	put(b, 4, 0, 8, b.c.n.lantern)
	if roll(b, 0, 0, 0, 6) < 0.5 then
		chest(b, 8, 0, 8)
	end
end

-- Low broken walls.
local function ruin(b)
	for lx = 2, 10 do
		for lz = 2, 10 do
			put(b, lx, -1, lz, roll(b, lx, -1, lz, 7) < 0.25 and b.c.n.sculk or tile(b, lx, -1, lz))
			if lx == 2 or lx == 10 or lz == 2 or lz == 10 then
				local wall = floor(roll(b, lx, 0, lz, 8) * 5)
				for ly = 0, wall - 1 do
					put(b, lx, ly, lz, brick(b, lx, ly, lz))
				end
				if wall > 0 and roll(b, lx, wall, lz, 9) < 0.15 then
					candle(b, lx, wall, lz)
				end
			elseif roll(b, lx, 0, lz, 10) < 0.04 then
				put(b, lx, 0, lz, b.c.n.cobbled)
			end
		end
	end
	if roll(b, 0, 0, 0, 6) < 0.35 then
		chest(b, 4, 0, 4)
	end
end

-- Wool tent with a soul lantern where Minecraft has a soul campfire.
local function camp(b)
	local n = b.c.n
	for lx = 4, 8 do
		for lz = 4, 8 do
			put(b, lx, 0, lz, n.carpet)
		end
	end
	for lz = 3, 9 do
		for i = 0, 3 do
			put(b, 3 + i, i, lz, n.wool)
			put(b, 9 - i, i, lz, n.wool)
		end
	end
	put(b, 6, -1, 1, n.polished)
	put(b, 6, 0, 1, n.lantern)
	put(b, 4, 0, 1, n.skull)
	put(b, 8, 0, 1, n.skull)
	if roll(b, 0, 0, 0, 6) < 0.5 then
		chest(b, 6, 0, 8)
	end
end

-- Closed hall with basalt corners.
local function chamber(b)
	local n = b.c.n
	floor_area(b, 1, 11, function()
		return n.polished
	end)
	for lx = 1, 11 do
		for lz = 1, 11 do
			local ex, ez = lx == 1 or lx == 11, lz == 1 or lz == 11
			if ex and ez then
				for ly = 0, 5 do
					put(b, lx, ly, lz, n.basalt)
				end
			elseif ex or ez then
				for ly = 0, 4 do
					if not (lx == 6 and lz == 1 and ly <= 1) then
						put(b, lx, ly, lz, brick(b, lx, ly, lz))
					end
				end
			end
			if not (ex and ez) and roll(b, lx, 5, lz, 11) > 0.15 then
				put(b, lx, 5, lz, tile(b, lx, 5, lz))
			end
		end
	end
	chest(b, 3, 0, 9)
	if roll(b, 0, 0, 0, 6) < 0.6 then
		chest(b, 9, 0, 9)
	end
	candle(b, 6, 0, 9)
	put(b, 6, 0, 6, n.sensor)
	put(b, 9, 0, 3, n.lantern)
	put(b, 3, -1, 3, n.sculk)
	put(b, 3, 0, 3, n.shrieker, 1)
end

-- Ice store.
local function ice_box(b)
	local n = b.c.n
	floor_area(b, 3, 9, function()
		return n.polished
	end)
	for lx = 3, 9 do
		for lz = 3, 9 do
			local outer = lx == 3 or lx == 9 or lz == 3 or lz == 9
			local inner = not outer and (lx == 4 or lx == 8 or lz == 4 or lz == 8)
			for ly = 0, 3 do
				if lx == 6 and (lz == 3 or lz == 4) and ly <= 1 then
					put(b, lx, ly, lz, "air")
				elseif outer then
					put(b, lx, ly, lz, n.polished)
				elseif inner and ly <= 2 then
					put(b, lx, ly, lz, n.ice)
				end
			end
			put(b, lx, 4, lz, tile(b, lx, 4, lz))
			if not outer then
				put(b, lx, -1, lz, n.ice)
			end
		end
	end
	chest(b, 6, 0, 6, "ancient_city_ice_box")
end

-- Weathered statue of a sculk guardian.
local function statue(b)
	local n = b.c.n
	for lx = 4, 8 do
		for lz = 4, 8 do
			put(b, lx, 0, lz, n.tile_slab)
		end
	end
	for _, lx in ipairs({ 5, 7, }) do
		put(b, lx, 1, 6, tile(b, lx, 1, 6))
		put(b, lx, 2, 6, tile(b, lx, 2, 6))
	end
	for lx = 5, 7 do
		for ly = 3, 5 do
			put(b, lx, ly, 6, (lx == 6 and ly == 4) and n.chiseled or brick(b, lx, ly, 6))
		end
		put(b, lx, 6, 6, n.reinforced)
		put(b, lx, 7, 6, n.reinforced)
	end
	for _, lx in ipairs({ 4, 8, }) do
		put(b, lx, 4, 6, brick(b, lx, 4, 6))
		put(b, lx, 5, 6, brick(b, lx, 5, 6))
	end
	put(b, 5, 8, 6, n.sculk)
	put(b, 7, 8, 6, n.sculk)
	candle(b, 4, 1, 4)
	candle(b, 8, 1, 8)
end

-- Basalt columns holding up the roof.
local function pillars(b)
	local c, n = b.c, b.c.n
	for _, p in ipairs({ { 3, 3, }, { 3, 9, }, { 9, 3, }, { 9, 9, }, }) do
		local x, _, z = at(b, p[1], 0, p[2])
		local top = ceiling_y(c.fy, x, z, shape(x - c.cx, z - c.cz), c.seed) - c.fy
		for ly = 0, top + 1 do
			put(b, p[1], ly, p[2], n.basalt)
		end
		put(b, p[1] + (p[1] < 6 and 1 or -1), 0, p[2], n.tile_slab)
	end
	put(b, 6, -1, 6, n.chiseled)
	put(b, 6, 0, 6, n.lantern)
end

local BUILDINGS = { { tower, 3, }, { ruin, 4, }, { camp, 2, }, { chamber, 2, }, { ice_box, 1, }, { statue, 1, },
	{ pillars, 1, }, { false, 3, }, }
AC.KINDS = { [tower] = "tower", [ruin] = "ruin", [camp] = "camp", [chamber] = "chamber", [ice_box] = "ice_box",
	[statue] = "statue", [pillars] = "pillars", }
local WEIGHT = 0
for _, b in ipairs(BUILDINGS) do
	WEIGHT = WEIGHT + b[2]
end
local function pick(rng)
	local r = rng:next(0, WEIGHT - 1)
	for _, b in ipairs(BUILDINGS) do
		r = r - b[2]
		if r < 0 then
			return b[1]
		end
	end
end
local CELLS = { -46, -30, -14, 14, 30, 46, }

-- The floor (first air layer) of a city whose origin is `origin`.
function AC.floor_y(origin)
	return origin.y <= AC.TOP_Y and origin.y or AC.DEEP_Y
end

-- Buildings: {fn, x, z (box corner), dir, height, seed}.
function AC.plan(origin, seed)
	local rng = PcgRandom(seed)
	local cseed = rng:next(0, 0x3fffffff)
	local out = {}
	-- every city keeps at least one ice store, away from the gate
	local ice
	repeat
		ice = 1 + rng:next(0, #CELLS * #CELLS - 1)
	until ice ~= 15 and ice ~= 16 and ice ~= 21 and ice ~= 22
	local cell = 0
	for _, ox in ipairs(CELLS) do
		for _, oz in ipairs(CELLS) do
			cell = cell + 1
			local fn = pick(rng)
			if cell == ice then
				fn = ice_box
			end
			local b = { x = origin.x + ox - 6, z = origin.z + oz - 6, dir = rng:next(0, 3), height = 9 + rng:next(0, 3),
				seed = rng:next(0, 0x3fffffff), }
			if fn and not (abs(ox) == 14 and abs(oz) == 14) then
				b.fn = fn
				out[#out + 1] = b
			end
		end
	end
	return out, cseed
end

function AC.layout(origin, seed)
	local fy = AC.floor_y(origin)
	local cx, cz = origin.x, origin.z
	local buildings, cseed = AC.plan(origin, seed)
	local R = AC.HALF + AC.RIM
	local lo = vector.new(cx - R, fy - 4, cz - R)
	local hi = vector.new(cx + R, fy + AC.CEILING_MAX + 2, cz + R)
	local out = {}
	for x = lo.x, hi.x, AC.COLUMN do
		for z = lo.z, hi.z, AC.COLUMN do
			local cmin = vector.new(x, lo.y, z)
			local cmax = vector.new(min(x + AC.COLUMN - 1, hi.x), hi.y, min(z + AC.COLUMN - 1, hi.z))
			out[#out + 1] = { minp = cmin, maxp = cmax, part = true, kind = "city", build = function(ctx)
				local c = city(ctx, cx, fy, cz, cseed)
				place_cavern(c, cmin.x, cmax.x, cmin.z, cmax.z)
				if cmin.x <= cx + 16 and cmax.x >= cx - 16 and cmin.z <= cz + 9 and cmax.z >= cz - 9 then
					place_center(c, ctx)
				end
				for _, b in ipairs(buildings) do
					if cmin.x <= b.x + 12 and cmax.x >= b.x and cmin.z <= b.z + 12 and cmax.z >= b.z then
						b.c = c
						b.fn(b)
						b.c = nil
					end
				end
			end, }
		end
	end
	return { minp = lo, maxp = hi, pieces = out, }
end

cb_structures.register("ancient_city", {
	description = S("Ancient City"),
	dims = { "overworld", },
	underground = true,
	prepare = { radius = AC.HALF + AC.RIM, below = 4, above = AC.CEILING_MAX + 2, },
	-- /cb_scatter: deep under the ground there
	scatter_y = function(ground)
		return math.min(AC.DEEP_Y, ground - 50)
	end,
	layout = AC.layout,
	sample_exclude = { ["default:chest"] = true, ["default:chest_open"] = true, ["cb_blocks:soul_lantern"] = true,
		["cb_mobs_deep:sculk_vein"] = true, },
})

-- Bedrock's ancient_city and ancient_city_ice_box (Secret Terra's
-- st_world/loot.lua): no discs, compasses, amethyst, potions, glow berries
-- or trims here.
local loot = cb_structures.loot
local function e(items, w, a, b)
	return { items = items, w = w, n = a and { a, b, } or nil, }
end
-- enchanted like the table at a random power in [min, max] (cb_enchanting)
local function ench(entry, spec)
	entry.ench = spec
	return entry
end
loot.register("ancient_city", {
	{ rolls = { 5, 10, }, entries = {
		e({ "ethereal:golden_apple", }, 1, 1, 2), e({ "cb_mobs_deep:sculk_catalyst", }, 2, 1, 2), e({ "mobs:nametag", }, 2),
		ench(e({ "farming:hoe_diamond", }, 2), { 30, 50, true, }), e({ "leads:lead", }, 2), e({ "mobs:leather", }, 2, 1, 5),
		ench(e({ "3d_armor:leggings_diamond", }, 2), { 30, 50, false, }), e({ "default:book", }, 3), e({ "cb_mobs_deep:sculk", }, 3, 4, 10),
		e({ "cb_mobs_deep:sculk_sensor", }, 3, 1, 3), e({ "cb_blocks:candle_1", }, 3, 1, 4),
		ench(e({ "3d_armor:leggings_steel", }, 3), { 20, 39, false, }), e({ "cb_mobs_deep:echo_shard", }, 4, 1, 3),
		ench(e({ "cb_enchanting:book", "default:book", }, 5), { 30, 50, true, }),
		e({ "default:book", }, 5, 3, 10), e({ "bonemeal:bone", }, 5, 1, 15), e({ "default:torch", }, 5, 1, 15),
		e({ "default:coal_lump", }, 7, 6, 15), e({ "cb_items:trim_ward", }, 4), e({ "cb_items:trim_silence", }, 1), }, },
})
loot.register("ancient_city_ice_box", {
	{ rolls = { 4, 10, }, entries = {
		e({ "farming:carrot_gold", }, 1, 1, 10), e({ "farming:baked_potato", }, 1, 1, 10), e({ "default:ice", }, 2, 2, 6),
		e({ "default:snow", }, 4, 2, 6), }, },
})
