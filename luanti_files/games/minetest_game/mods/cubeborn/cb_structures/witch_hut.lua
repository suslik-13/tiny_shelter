-- Witch hut (spec cycle 2, 4.5): Mineclonia's hut on oak log stilts, its
-- floor one above the surface; the witch moves in at once and, while the
-- hut stands, a killed one is replaced after cubeborn.rare_respawn_hours.
local S = cb_structures.S
local A = cb_structures.piecegen
local gen = dofile(core.get_modpath("cb_structures") .. "/witch_hut_pieces.lua")
local WH = {}
cb_structures.witch_hut = WH

function WH.plan(origin, seed)
	local y, x1, z1 = cb_structures.surface.site(origin, gen.LENGTH, gen.LENGTH, gen.HEIGHT + 1,
		{ max_drop = 6, below = 6, })
	if not y then
		return nil, x1
	end
	return { x = x1, y = y, z = z1, }
end

function WH.layout(origin, seed, plan)
	local rng = A.rng(seed)
	local dir = A.random_orientation(rng)
	local bbox = A.make_rotated_bbox(0, 1, 0, dir, gen.WIDTH, gen.HEIGHT, gen.LENGTH)
	local piece = { bbox = bbox, dir = dir, place = gen.place, }
	local o = vector.new(plan.x, plan.y, plan.z + gen.LENGTH - 1)
	local a = vector.new(o.x + bbox[1], o.y - 6, o.z - bbox[6])
	local b = vector.new(o.x + bbox[4], o.y + bbox[5], o.z - bbox[3])
	local hut_a = vector.new(a.x, o.y + 1, a.z)
	return { minp = a, maxp = b, pieces = {
		{ minp = a, maxp = b, build = function(ctx)
			A.begin(ctx, o)
			A.level.preset.min_y = -6
			piece:place(A.level, nil, A.rng(seed + 1), -1000000, -1000000, 1000000, 1000000)
		end, },
		{ minp = hut_a, maxp = b, part = true, build = function() end, },
	}, }
end

cb_structures.register("witch_hut", {
	description = S("Witch Hut"),
	dims = { "overworld", },
	biome_words = { "swamp", "mangrove", },
	prepare = { radius = 48, below = 24, above = 40, },
	plan = WH.plan,
	layout = WH.layout,
	-- the witch is rare: a killed one is replaced only after a day (respawn.lua)
	inhabitants = { mobs = { { "cb_mobs_village:witch", 1, "w", }, }, volume = 1000000, max = 1, },
})
