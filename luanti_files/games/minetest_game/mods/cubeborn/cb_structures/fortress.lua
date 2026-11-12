-- Nether fortress (spec 6.2): pieces from fortress_pieces.lua (Mineclonia),
-- clipped to the pocket, at most MAX_PIECES rooms; each room is a part whose
-- inhabitants are lava slimes, blazes come from the spawners.
local S = cb_structures.S
local A = cb_structures.piecegen

cb_structures.fortress_nodes = {
	nether_brick = cb_core.equiv("nether_brick"),
	nether_brick_fence = cb_core.equiv("nether_brick_fence"),
	nether_brick_stairs = A.first("stairs:stair_nether_brick", "stairs:stair_cb_nether_bricks"),
	soul_sand = A.first("nether:soul_sand", "cb_blocks:soul_sand"),
	nether_wart = "cb_blocks:nether_wart_0",
}
local gen = dofile(core.get_modpath("cb_structures") .. "/fortress_pieces.lua")

local F = {
	MAX_PIECES = tonumber(cb_core.setting("cubeborn.fortress_pieces", "40")) or 40,
	DEPTH = 48, MARGIN = 2, RADIUS = 112,
}
cb_structures.fortress = F

-- Local y as in Minecraft: the fortress stands at 48..70 above the floor.
local BASE = 48

local function pocket_at(pos)
	for _, p in pairs(cb_dimensions.all()) do
		local a, b = cb_dimensions.inner(p)
		if cb_core.inside(pos, a, b) then
			return a, b
		end
	end
end

-- origin: in a pocket, x/z of the start and the pocket floor decides y;
-- elsewhere, or `here` (/cb_spawn), the lowest room floor is at origin.y
-- (the supports end at the pocket floor).
function F.layout(origin, seed, _, here)
	local ia, ib = pocket_at(origin)
	local floor_y = (ia and not here) and ia.y or (origin.y - BASE)
	-- Local coordinates: start at (0, BASE, 0); world = (ox + x, floor_y + y, oz - z).
	local ox, oz = origin.x, origin.z
	if ia then
		A.bounds = { ia.x + F.MARGIN - ox, oz - (ib.z - F.MARGIN), ib.x - F.MARGIN - ox, oz - (ia.z + F.MARGIN), }
	else
		A.bounds = nil
	end
	local rng = A.rng(seed)
	local pieces = gen.create_pieces(rng, 0, 0, F.MAX_PIECES)
	A.bounds = nil
	local min_y = (ia and not here) and 0 or (BASE - F.DEPTH)
	if ia and here then
		min_y = math.max(min_y, ia.y - floor_y)
	end
	local o = vector.new(ox, floor_y, oz)
	local out = {}
	local lo, hi
	local function grow(a, b)
		lo = lo and vector.new(math.min(lo.x, a.x), math.min(lo.y, a.y), math.min(lo.z, a.z)) or vector.copy(a)
		hi = hi and vector.new(math.max(hi.x, b.x), math.max(hi.y, b.y), math.max(hi.z, b.z)) or vector.copy(b)
	end
	for i, piece in ipairs(pieces) do
		local bb = piece.bbox
		local a = vector.new(ox + bb[1], floor_y + bb[2], oz - bb[6])
		local b = vector.new(ox + bb[4], floor_y + bb[5], oz - bb[3])
		local function build(ctx)
			A.begin(ctx, o)
			A.level.preset.min_y = min_y
			piece:place(A.level, nil, A.rng(seed + i))
		end
		out[#out + 1] = { minp = a, maxp = b, part = piece.place ~= nil and piece.type ~= nil, build = build, }
		grow(a, b)
		if bb[2] > min_y then
			local fa = vector.new(a.x, floor_y + min_y, a.z)
			local fb = vector.new(b.x, a.y - 1, b.z)
			out[#out + 1] = { minp = fa, maxp = fb, build = build, }
			grow(fa, fb)
		end
	end
	return { minp = lo, maxp = hi, pieces = out, }
end

cb_structures.register("nether_fortress", {
	description = S("Nether Fortress"),
	dims = { "nether", },
	layout = F.layout,
	-- wither skeletons and lava slimes; lava flans where neither is loaded
	inhabitants = { mobs = { { "cb_mobs_nether:wither_skeleton", 2, }, { "mobs_slimes:lavasmall", 1, }, },
		fallback = { { "mobs_monster:lava_flan", 1, }, },
		volume = 600, max = 2, },
	sample_exclude = {
		["default:lava_source"] = true, ["default:lava_flowing"] = true, ["default:chest"] = true,
		["default:chest_open"] = true, ["cb_structures:blaze_spawner"] = true,
		["cb_blocks:nether_wart_0"] = true, ["cb_blocks:nether_wart_1"] = true, ["cb_blocks:nether_wart_2"] = true,
		["cb_blocks:nether_wart_3"] = true,
	},
})

-- tiny: two fortresses when the own Nether pocket becomes ready, in the
-- centres of two opposite quarters.
function F.auto(pocket)
	local ia, ib = cb_dimensions.inner(pocket)
	local w, d = ib.x - ia.x, ib.z - ia.z
	for _, q in ipairs({ { 0.25, 0.25, }, { 0.75, 0.75, }, }) do
		local origin = vector.new(ia.x + math.floor(w * q[1]), ia.y, ia.z + math.floor(d * q[2]))
		cb_structures.place("nether_fortress", origin, pocket.created_by, function(res)
			if not res.ok then
				core.log("action", "[cubeborn] fortress at " .. core.pos_to_string(origin) .. " skipped: "
					.. core.get_translated_string("en", res.msg))
			end
		end)
	end
end

if cb_core.profile.nether == "own" and cb_dimensions.get_dim("nether") then
	cb_dimensions.set_on_ready("nether", F.auto)
end
