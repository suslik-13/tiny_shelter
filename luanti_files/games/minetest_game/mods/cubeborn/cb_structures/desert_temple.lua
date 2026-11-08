-- Desert temple (spec cycle 2, 4.3): Mineclonia's pyramid with four loot
-- chests and the hidden plate over nine TNT. It stands on the surface found
-- by surface.site; its basement goes 14 below the floor.
local S = cb_structures.S
local A = cb_structures.piecegen
local gen = dofile(core.get_modpath("cb_structures") .. "/desert_temple_pieces.lua")
local DT = { BELOW = 20, }
cb_structures.desert_temple = DT

DT.HANDLERS = {
	["mcl_levelgen:desert_pyramid_loot"] = function(x, y, z)
		A.set_loot_table(x, y, z, nil, "desert_pyramid")
	end,
	["mcl_sus_nodes:suspicious_sand_structure_meta"] = function(x, y, z, data)
		A.set_suspicious(x, y, z, "sand", "desert_pyramid", data[4])
	end,
}

function DT.plan(origin, seed)
	local y, x1, z1 = cb_structures.surface.site(origin, gen.WIDTH, gen.LENGTH, gen.HEIGHT,
		{ max_drop = 8, below = DT.BELOW, })
	if not y then
		return nil, x1
	end
	return { x = x1, y = y, z = z1, }
end

-- Local (0, 0, 0) is the plan's corner at floor level; the piece turns
-- inside its own box.
function DT.layout(origin, seed, plan)
	local rng = A.rng(seed)
	local piece = gen.create_piece(rng, 0, 0, 0)
	local sink = -rng:next_within(3)
	local bb = piece.bbox
	bb[2], bb[5] = bb[2] + sink, bb[5] + sink
	local o = vector.new(plan.x, plan.y, plan.z + gen.LENGTH - 1)
	local a = vector.new(o.x + bb[1], o.y + bb[2] - DT.BELOW, o.z - bb[6])
	local b = vector.new(o.x + bb[4], o.y + bb[5], o.z - bb[3])
	return { minp = a, maxp = b, pieces = { { minp = a, maxp = b, build = function(ctx)
		A.begin(ctx, o)
		A.handlers = DT.HANDLERS
		A.level.preset.min_y = bb[2] - DT.BELOW
		piece:place(A.level, nil, A.rng(seed + 1), -1000000, -1000000, 1000000, 1000000)
	end, }, }, }
end

cb_structures.register("desert_temple", {
	description = S("Desert Temple"),
	dims = { "overworld", },
	biome_words = { "desert", },
	prepare = { radius = 48, below = 24, above = 40, },
	plan = DT.plan,
	layout = DT.layout,
})
