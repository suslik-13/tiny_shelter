-- Housing units, hoglin stable and bridge bastions: Secret Terra's layouts
-- (st_world/bastion.lua) as lists of primitives (fills, rooms, crenels,
-- foundations, ramp steps, chests, mobs) in local coordinates around the
-- origin, mirrored per bastion; ly 0 is the first air layer. The layout cuts
-- the whole box into 32x32 columns; each column runs the primitives that
-- reach it and is a part. Chests use Bedrock's bastion_other, bastion_bridge
-- and bastion_hoglin_stable loot (as far as the server has the items).
local B = cb_structures.bastion
local A = cb_structures.piecegen
local COLUMN, FOUNDATION_DEPTH = 32, 32
local max, min = math.max, math.min

local BRICKS, CRACKED = "cb_blocks:polished_blackstone_bricks", "cb_blocks:cracked_polished_blackstone_bricks"
local BLACKSTONE, GILDED = "cb_blocks:blackstone", "cb_blocks:gilded_blackstone"
local POLISHED, CHISELED = "cb_blocks:polished_blackstone", "cb_blocks:chiseled_polished_blackstone"
local SLAB, BASALT, GOLD = "stairs:slab_cb_polished_blackstone_bricks", "cb_blocks:polished_basalt", "default:goldblock"
local MAGMA, NYLIUM = "cb_blocks:magma", "cb_blocks:crimson_nylium"
local SOUL_SAND = A.first("nether:soul_sand", "cb_blocks:soul_sand")
local THROUGH = { air = true, ["default:lava_source"] = true, ["default:lava_flowing"] = true, }

-- Materials: function(x, y, z, seed) -> node name.
local hash = B.hash
local function mat_bricks(x, y, z, seed)
	local h = hash(x, y, z, seed)
	return h < 0.25 and CRACKED or h < 0.29 and BLACKSTONE or h < 0.295 and GILDED or BRICKS
end
local function mat_blackstone(x, y, z, seed)
	return hash(x, y, z, seed + 1) < 0.03 and GILDED or BLACKSTONE
end
local function mat_stable_floor(x, y, z, seed)
	local h = hash(x, y, z, seed + 2)
	return h < 0.25 and SOUL_SAND or h < 0.4 and (core.registered_nodes[NYLIUM] and NYLIUM or BLACKSTONE)
		or h < 0.45 and MAGMA or BLACKSTONE
end
local function const(name)
	return function()
		return name
	end
end
local mat_air, mat_polished, mat_basalt = const("air"), const(POLISHED), const(BASALT)
local mat_gold, mat_chiseled = const(GOLD), const(CHISELED)

-- Primitives: place(op, ctx, xa, xb, za, zb) with x/z already clipped to
-- the column; b = op.bbox in world coordinates {x1, y1, z1, x2, y2, z2}.
local function place_fill(op, ctx, xa, xb, za, zb)
	local b, mat, seed = op.bbox, op.mat, op.seed
	for x = xa, xb do
		for z = za, zb do
			for y = b[2], b[5] do
				ctx.set(vector.new(x, y, z), mat(x, y, z, seed))
			end
		end
	end
end

-- Walls of thickness t around the box, an optional floor and roof.
local function place_room(op, ctx, xa, xb, za, zb)
	local b, mat, seed, t = op.bbox, op.mat, op.seed, op.t or 1
	for x = xa, xb do
		for z = za, zb do
			local wall = x < b[1] + t or x > b[4] - t or z < b[3] + t or z > b[6] - t
			for y = b[2], b[5] do
				if wall or (op.floor and y == b[2]) or (op.roof and y == b[5]) then
					ctx.set(vector.new(x, y, z), mat(x, y, z, seed))
				else
					ctx.set(vector.new(x, y, z), "air")
				end
			end
		end
	end
end

-- Every other block along the rim of the box (one layer).
local function place_crenels(op, ctx, xa, xb, za, zb)
	local b, seed, y = op.bbox, op.seed, op.bbox[2]
	for x = xa, xb do
		for z = za, zb do
			if (x == b[1] or x == b[4] or z == b[3] or z == b[6]) and (x + z) % 2 == 0 then
				ctx.set(vector.new(x, y, z), mat_bricks(x, y, z, seed))
			end
		end
	end
end

-- Blackstone columns from the top of the box down through air and lava
-- until they reach the ground.
local function place_foundation(op, ctx, xa, xb, za, zb)
	local b, seed = op.bbox, op.seed
	for x = xa, xb do
		for z = za, zb do
			for y = b[5], b[2], -1 do
				local p = vector.new(x, y, z)
				if not THROUGH[ctx.get(p)] then
					break
				end
				ctx.set(p, mat_blackstone(x, y, z, seed))
			end
		end
	end
end

-- A column of bricks with a bottom slab on top when op.half: a ramp step.
local function place_step(op, ctx, xa, xb, za, zb)
	local b, seed = op.bbox, op.seed
	for x = xa, xb do
		for z = za, zb do
			for y = b[2], b[5] - 1 do
				ctx.set(vector.new(x, y, z), mat_bricks(x, y, z, seed))
			end
			ctx.set(vector.new(x, b[5], z), op.half and SLAB or mat_bricks(x, b[5], z, seed))
		end
	end
end

local function place_chest(op, ctx)
	local b = op.bbox
	ctx.chest(vector.new(b[1], b[2], b[3]), op.loot, 0)
end

local function place_mob(op, ctx)
	local b, mob = op.bbox, op.mob
	ctx.after(function()
		if core.registered_entities[mob] then
			core.add_entity(vector.new(b[1], b[2] + 0.5, b[3]), mob)
		end
	end)
end

-- Mobs (as in Mineclonia's treasure bastions).
local PIGLINS = { { B.BRUTE, 1, }, { B.PIGLIN, 6, }, }
local BRUTES = { { B.BRUTE, 6, }, { B.PIGLIN, 1, }, }
local HOGLINS = { { B.HOGLIN, 1, }, }

local function new_builder(rng, gx, gy, gz)
	local function float()
		return rng:next(0, 16777215) / 16777216
	end
	local bld = { ops = {}, seed = rng:next(0, 0x3fffffff), sx = rng:next(0, 1) == 1 and 1 or -1,
		sz = rng:next(0, 1) == 1 and 1 or -1, rng = rng, float = float, }

	local function bbox(lx1, ly1, lz1, lx2, ly2, lz2)
		local xa, xb = gx + bld.sx * lx1, gx + bld.sx * lx2
		local za, zb = gz + bld.sz * lz1, gz + bld.sz * lz2
		return { min(xa, xb), gy + min(ly1, ly2), min(za, zb), max(xa, xb), gy + max(ly1, ly2), max(za, zb), }
	end

	function bld.add(place, lx1, ly1, lz1, lx2, ly2, lz2, fields)
		local op = fields or {}
		op.bbox, op.place, op.seed = bbox(lx1, ly1, lz1, lx2, ly2, lz2), place, bld.seed
		bld.ops[#bld.ops + 1] = op
		return op
	end
	function bld.fill(mat, lx1, ly1, lz1, lx2, ly2, lz2)
		return bld.add(place_fill, lx1, ly1, lz1, lx2, ly2, lz2, { mat = mat, })
	end
	function bld.carve(lx1, ly1, lz1, lx2, ly2, lz2)
		return bld.fill(mat_air, lx1, ly1, lz1, lx2, ly2, lz2)
	end
	function bld.room(lx1, ly1, lz1, lx2, ly2, lz2, fields)
		fields = fields or {}
		fields.mat = fields.mat or mat_bricks
		return bld.add(place_room, lx1, ly1, lz1, lx2, ly2, lz2, fields)
	end
	function bld.crenels(lx1, ly, lz1, lx2, lz2)
		return bld.add(place_crenels, lx1, ly, lz1, lx2, ly, lz2)
	end
	-- Foundation under a footprint whose lowest block is at ly.
	function bld.foundation(lx1, lz1, lx2, lz2, ly)
		return bld.add(place_foundation, lx1, ly - FOUNDATION_DEPTH, lz1, lx2, ly, lz2)
	end
	-- Ramp step whose walking surface is `halves' half blocks up.
	function bld.step(lx1, lz1, lx2, lz2, ly, halves)
		local top = ly + math.floor((halves - 1) / 2)
		return bld.add(place_step, lx1, ly, lz1, lx2, top, lz2, { half = halves % 2 == 1, })
	end
	function bld.chest(lx, ly, lz, loot)
		return bld.add(place_chest, lx, ly, lz, lx, ly, lz, { loot = loot, })
	end
	function bld.mob(list, lx, ly, lz, chance)
		if float() < (chance or 1) then
			local mob = B.roll(list, float())
			bld.add(place_mob, lx, ly, lz, lx, ly, lz, { mob = mob, })
		end
	end
	return bld
end

local LOOT_OTHER, LOOT_BRIDGE, LOOT_STABLE = "bastion_other", "bastion_bridge", "bastion_hoglin_stable"

-- Housing units: a walled block of two-storey rooms around a courtyard,
-- with ramparts and corner towers.
local UNIT_CENTERS = { -11, 0, 11, }

local function build_units(bld)
	local float = bld.float
	bld.foundation(-20, -20, 20, 20, -2)
	bld.fill(mat_bricks, -20, -1, -20, 20, -1, 20)
	bld.carve(-19, 0, -19, 19, 12, 19)
	bld.room(-20, 0, -20, 20, 12, 20)
	-- Rampart walk over the ring corridor.
	bld.fill(mat_polished, -19, 12, -19, 19, 12, -17)
	bld.fill(mat_polished, -19, 12, 17, 19, 12, 19)
	bld.fill(mat_polished, -19, 12, -16, -17, 12, 16)
	bld.fill(mat_polished, 17, 12, -16, 19, 12, 16)
	bld.crenels(-20, 13, -20, 20, 20)
	-- Gate.
	bld.carve(-1, 0, -20, 1, 3, -20)

	-- Units; the middle one is an open courtyard.
	local upper = {}
	for _, ux in ipairs(UNIT_CENTERS) do
		for _, uz in ipairs(UNIT_CENTERS) do
			local courtyard = ux == 0 and uz == 0
			bld.room(ux - 5, 0, uz - 5, ux + 5, 6, uz + 5, { roof = not courtyard, })
			if not courtyard and float() < 0.6 then
				bld.room(ux - 5, 6, uz - 5, ux + 5, 12, uz + 5, { roof = true, })
				bld.crenels(ux - 5, 13, uz - 5, ux + 5, uz + 5)
				upper[#upper + 1] = { ux, uz, }
			end
		end
	end
	-- Doorways through every unit wall, both storeys.
	for _, ux in ipairs(UNIT_CENTERS) do
		for _, uz in ipairs(UNIT_CENTERS) do
			bld.carve(ux + 4, 0, uz - 1, ux + 6, 2, uz + 1)
			bld.carve(ux - 6, 0, uz - 1, ux - 4, 2, uz + 1)
			bld.carve(ux - 1, 0, uz + 4, ux + 1, 2, uz + 6)
			bld.carve(ux - 1, 0, uz - 6, ux + 1, 2, uz - 4)
		end
	end
	for _, u in ipairs(upper) do
		local ux, uz = u[1], u[2]
		bld.carve(ux + 4, 7, uz - 1, ux + 6, 9, uz + 1)
		bld.carve(ux - 6, 7, uz - 1, ux - 4, 9, uz + 1)
		bld.carve(ux - 1, 7, uz + 4, ux + 1, 9, uz + 6)
		bld.carve(ux - 1, 7, uz - 6, ux + 1, 9, uz - 4)
	end
	-- Courtyard: steps up to the unit roofs and a gilded pillar.
	for i = 1, 6 do
		bld.step(-4 + i, 3, -4 + i, 4, 0, i * 2)
	end
	bld.fill(mat_basalt, 0, 0, -2, 0, 4, -2)
	bld.fill(mat_gold, 0, 5, -2, 0, 5, -2)

	-- Corner towers reached from the ramparts.
	for _, cx in ipairs({ -20, 20, }) do
		for _, cz in ipairs({ -20, 20, }) do
			bld.room(cx - 3, 0, cz - 3, cx + 3, 18, cz + 3, { roof = true, })
			bld.fill(mat_polished, cx - 2, 12, cz - 2, cx + 2, 12, cz + 2)
			bld.crenels(cx - 3, 19, cz - 3, cx + 3, cz + 3)
			local ix, iz = cx < 0 and 1 or -1, cz < 0 and 1 or -1
			bld.carve(cx + 3 * ix, 13, cz + iz, cx + 3 * ix, 14, cz + iz)
			bld.carve(cx + ix, 13, cz + 3 * iz, cx + ix, 14, cz + 3 * iz)
			bld.carve(cx + 3 * ix, 0, cz + iz, cx + 3 * ix, 2, cz + iz)
			bld.mob(BRUTES, cx, 13, cz, 0.7)
		end
	end

	-- Chests and residents.
	local chests = 0
	for _, ux in ipairs(UNIT_CENTERS) do
		for _, uz in ipairs(UNIT_CENTERS) do
			if not (ux == 0 and uz == 0) then
				if float() < 0.45 then
					bld.chest(ux + 3, 0, uz + 3, LOOT_OTHER)
					chests = chests + 1
				end
				bld.mob(PIGLINS, ux - 2, 0, uz - 2, 0.6)
			end
		end
	end
	for _, u in ipairs(upper) do
		if float() < 0.4 then
			bld.chest(u[1] - 3, 7, u[2] + 3, LOOT_OTHER)
			chests = chests + 1
		end
		bld.mob(PIGLINS, u[1], 7, u[2], 0.5)
	end
	if chests == 0 then
		bld.chest(14, 0, 14, LOOT_OTHER)
	end
	bld.mob(PIGLINS, 18, 0, 0, 1)
	bld.mob(PIGLINS, -18, 0, 0, 1)
end

-- Hoglin stable: a tall open hall with a ramp along one wall up to a
-- gallery on the other three; hoglins on the ground.
local function build_stable(bld)
	bld.foundation(-22, -22, 22, 22, -2)
	bld.fill(mat_stable_floor, -21, -1, -21, 21, -1, 21)
	bld.fill(mat_bricks, -22, -1, -22, 22, -1, -22)
	bld.room(-22, 0, -22, 22, 22, 22, { t = 2, })
	bld.crenels(-22, 23, -22, 22, 22)
	-- Gate.
	bld.carve(-2, 0, 21, 2, 4, 22)

	-- Ramp along the south wall: half a block per block, 0 to 17.5.
	for i = 0, 34 do
		local x = -17 + i
		bld.step(x, -20, x, -18, 0, i + 1)
	end
	-- Gallery on the other three walls (walking surface 18).
	bld.fill(mat_bricks, 18, 17, -20, 20, 17, 20)
	bld.fill(mat_bricks, -20, 17, 18, 17, 17, 20)
	bld.fill(mat_bricks, -20, 17, -17, -18, 17, 17)
	for i = -17, 17, 2 do
		bld.fill(mat_bricks, 17, 18, i, 17, 18, i)
		bld.fill(mat_bricks, i, 18, 17, i, 18, 17)
		bld.fill(mat_bricks, -17, 18, i, -17, 18, i)
	end
	-- Basalt columns and gold under the gallery.
	for _, px in ipairs({ -14, 14, }) do
		for _, pz in ipairs({ -12, 14, }) do
			bld.fill(mat_basalt, px - 1, 0, pz - 1, px + 1, 22, pz + 1)
		end
	end
	bld.fill(mat_gold, 19, 18, 19, 19, 18, 19)
	bld.fill(mat_gold, -19, 18, 19, -19, 18, 19)

	bld.chest(19, 18, 17, LOOT_STABLE)
	bld.chest(-19, 18, 17, LOOT_STABLE)
	bld.chest(19, 0, 8, LOOT_OTHER)
	bld.chest(-19, 0, -8, LOOT_OTHER)

	for i = 1, 3 + bld.rng:next(0, 2) do
		bld.mob(HOGLINS, -8 + i * 4, 0, 2 - i, 1)
	end
	bld.mob(PIGLINS, 19, 18, 0, 0.8)
	bld.mob(PIGLINS, 0, 18, 19, 0.8)
	bld.mob(PIGLINS, -19, 18, 0, 0.8)
	bld.mob(PIGLINS, 0, 10, -19, 0.6)
	bld.mob(BRUTES, 19, 18, -18, 0.7)
	bld.mob(PIGLINS, -10, 0, 10, 0.6)
end

-- Bridge: a gate tower and a three-storey keep joined by a crenellated
-- bridge on two piers.
local function build_bridge(bld)
	-- Keep.
	bld.foundation(10, -10, 30, 10, -2)
	bld.fill(mat_bricks, 10, -1, -10, 30, -1, 10)
	bld.room(10, 0, -10, 30, 24, 10, { t = 2, })
	bld.crenels(10, 25, -10, 30, 10)
	bld.fill(mat_polished, 12, 9, -8, 28, 9, 8)
	bld.fill(mat_polished, 12, 18, -8, 28, 18, 8)
	-- Stairs: ground to the first floor, first to the second.
	bld.carve(12, 9, -8, 21, 9, -7)
	for i = 1, 10 do
		bld.step(11 + i, -8, 11 + i, -7, 0, i * 2)
	end
	bld.carve(13, 18, 7, 21, 18, 8)
	for i = 1, 9 do
		bld.step(22 - i, 7, 22 - i, 8, 10, i * 2)
	end
	bld.carve(10, 0, -1, 11, 2, 1)
	bld.carve(10, 10, -2, 11, 12, 2)
	bld.fill(mat_gold, 20, 19, -1, 21, 19, 0)
	bld.fill(mat_chiseled, 20, 19, 1, 21, 19, 1)
	bld.chest(26, 19, -6, LOOT_BRIDGE)
	bld.chest(26, 19, 6, LOOT_BRIDGE)
	bld.chest(27, 10, 0, LOOT_OTHER)

	-- Gate tower.
	bld.foundation(-34, -5, -22, 5, -2)
	bld.fill(mat_bricks, -34, -1, -5, -22, -1, 5)
	bld.room(-34, 0, -5, -22, 18, 5, { roof = true, })
	bld.crenels(-34, 19, -5, -22, 5)
	bld.fill(mat_polished, -33, 9, -4, -23, 9, 4)
	bld.carve(-33, 9, -4, -25, 9, -3)
	for i = 1, 10 do
		bld.step(-34 + i, -4, -34 + i, -3, 0, i * 2)
	end
	bld.carve(-34, 0, -1, -34, 2, 1)
	bld.carve(-22, 10, -2, -22, 12, 2)
	bld.chest(-24, 10, 3, LOOT_BRIDGE)

	-- Bridge deck, clearance, railings and piers.
	bld.carve(-21, 10, -3, 9, 14, 3)
	bld.fill(mat_bricks, -21, 8, -2, 9, 9, 2)
	for x = -21, 9 do
		if x % 2 == 0 then
			bld.fill(mat_bricks, x, 10, -3, x, 10, -3)
			bld.fill(mat_bricks, x, 10, 3, x, 10, 3)
		end
	end
	for _, px in ipairs({ -11, -1, }) do
		bld.foundation(px - 1, -1, px + 1, 1, 7)
	end

	bld.mob(PIGLINS, -15, 10, 0, 1)
	bld.mob(PIGLINS, -5, 10, 0, 0.8)
	bld.mob(PIGLINS, 4, 10, 0, 0.8)
	bld.mob(PIGLINS, 20, 10, 4, 0.8)
	bld.mob(PIGLINS, 15, 0, 5, 0.8)
	bld.mob(PIGLINS, -28, 0, 0, 0.7)
	bld.mob(BRUTES, 24, 19, 0, 1)
	bld.mob(BRUTES, 16, 19, -4, 0.7)
	if bld.float() < 0.5 then
		bld.chest(14, 0, 8, LOOT_OTHER)
	end
end

B.BUILDERS = { units = build_units, stable = build_stable, bridge = build_bridge, }

function B.build_layout(origin, seed, kind, here)
	local base, ia, ib = B.base(origin, B.BUILD_Y, here)
	local bld = new_builder(PcgRandom(seed), origin.x, base, origin.z)
	B.BUILDERS[kind](bld)
	local lo, hi
	for _, op in ipairs(bld.ops) do
		local b = op.bbox
		if ia then
			-- foundations stop at the pocket floor
			b[2], b[5] = max(b[2], ia.y), min(b[5], ib.y)
		end
		lo = lo and vector.new(min(lo.x, b[1]), min(lo.y, b[2]), min(lo.z, b[3])) or vector.new(b[1], b[2], b[3])
		hi = hi and vector.new(max(hi.x, b[4]), max(hi.y, b[5]), max(hi.z, b[6])) or vector.new(b[4], b[5], b[6])
	end
	local out = {}
	for x = lo.x, hi.x, COLUMN do
		for z = lo.z, hi.z, COLUMN do
			local cmin = vector.new(x, lo.y, z)
			local cmax = vector.new(min(x + COLUMN - 1, hi.x), hi.y, min(z + COLUMN - 1, hi.z))
			out[#out + 1] = { minp = cmin, maxp = cmax, part = true, kind = kind, build = function(ctx)
				for _, op in ipairs(bld.ops) do
					local b = op.bbox
					local xa, xb = max(b[1], cmin.x), min(b[4], cmax.x)
					local za, zb = max(b[3], cmin.z), min(b[6], cmax.z)
					if xa <= xb and za <= zb then
						op.place(op, ctx, xa, xb, za, zb)
					end
				end
			end, }
		end
	end
	return { minp = lo, maxp = hi, pieces = out, }
end

-- Bedrock's bastion_other, bastion_bridge and bastion_hoglin_stable (Secret
-- Terra's st_world/loot.lua) with what minetest_game servers have.
local loot = cb_structures.loot
local function e(items, w, a, b)
	return { items = items, w = w, n = a and { a, b, } or nil, }
end
local DPICK, DSHOVEL, SWORD = { "default:pick_diamond", }, { "default:shovel_diamond", }, { "default:sword_steel", }
local DEBRIS, SCRAP = { "cb_blocks:ancient_debris", }, { "cb_blocks:netherite_scrap", }
local GCARROT, GOLDB, IRONB = { "farming:carrot_gold", }, { "default:goldblock", }, { "default:steelblock", }
local GINGOT, IINGOT, CRYING = { "default:gold_ingot", }, { "default:steel_ingot", }, { "cb_blocks:crying_obsidian", }
local GILD, CHAIN, CREAM = { GILDED, }, { "cb_blocks:chain", }, { "cb_mobs_nether:magma_cream", }
local STRING, LEATHER = { "farming:string", }, { "mobs:leather", }
local GBOOTS, GCHEST = { "3d_armor:boots_gold", }, { "3d_armor:chestplate_gold", }
local GHELM, GLEGS = { "3d_armor:helmet_gold", }, { "3d_armor:leggings_gold", }
loot.register(LOOT_OTHER, {
	{ rolls = { 1, 1, }, entries = { e(DPICK, 6), e(DSHOVEL, 6), e(DEBRIS, 12), e(SCRAP, 4), e(GCARROT, 12, 6, 17), }, },
	{ rolls = { 2, 2, }, entries = { e(GBOOTS, 1), e(GOLDB, 1), e(IRONB, 1), e(SWORD, 6), e(GINGOT, 1, 1, 6),
		e(IINGOT, 1, 1, 6), e(GCHEST, 1), e(GHELM, 1), e(GLEGS, 1), e(GBOOTS, 1), e(CRYING, 1, 1, 5), }, },
	{ rolls = { 3, 5, }, entries = { e(GILD, 2, 1, 5), e(CHAIN, 1, 2, 10), e(CREAM, 2, 2, 6), e({ "default:obsidian", }, 1, 4, 6),
		e(STRING, 1, 4, 6), e({ "mobs:pork_cooked", }, 1), }, },
})
loot.register(LOOT_BRIDGE, {
	{ rolls = { 1, 2, }, entries = { e(GILD, 1, 8, 12), e(CRYING, 1, 3, 8), e(GOLDB, 1), e(GINGOT, 1, 4, 9),
		e(IINGOT, 1, 4, 9), e(GCHEST, 1), e(GHELM, 1), e(GLEGS, 1), e(GBOOTS, 1), }, },
	{ rolls = { 2, 4, }, entries = { e(STRING, 1, 1, 6), e(LEATHER, 1, 1, 3), }, },
})
loot.register(LOOT_STABLE, {
	{ rolls = { 1, 1, }, entries = { e(DSHOVEL, 15), e(SCRAP, 8), e(DEBRIS, 5), e({ "mobs:saddle", }, 12), e(GOLDB, 16, 2, 4),
		e(DPICK, 12), e(GCARROT, 10, 8, 17), }, },
	{ rolls = { 3, 4, }, entries = { e({ "nether:glowstone", "cb_blocks:glowstone", }, 1, 3, 6), e(GILD, 1, 2, 5),
		e({ "nether:soul_sand", "cb_blocks:soul_sand", }, 1, 2, 7), e({ NYLIUM, }, 1, 2, 7), e(LEATHER, 1, 1, 3),
		e(STRING, 1, 3, 8), e({ "mobs:pork_raw", }, 1, 2, 5), e({ "mobs:pork_cooked", }, 1, 2, 5),
		e({ "cb_blocks:crimson_fungus", }, 1, 2, 7), e({ "cb_blocks:crimson_roots", }, 1, 2, 7), e(CRYING, 1, 1, 5), }, },
})
