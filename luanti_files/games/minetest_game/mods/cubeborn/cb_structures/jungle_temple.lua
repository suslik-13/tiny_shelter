-- Jungle temple (spec cycle 2, 4.4): Mineclonia's template; dispensers
-- become arrow traps, sticky pistons the hidden door, levers the puzzle;
-- redstone is left out. Two chests with jungle temple loot.
local S = cb_structures.S
local T = cb_structures.templates
local A = cb_structures.piecegen
local JT = {}
cb_structures.jungle_temple = JT

T.MAP["mcl_core:cobble"] = "default:cobble"
T.MAP["mcl_core:mossycobble"] = "default:mossycobble"
T.MAP["mcl_core:stonebrickcarved"] = "default:stone_block"
T.MAP["mcl_core:vine"] = A.first("ethereal:vine", "air")
T.MAP["mcl_dispensers:dispenser"] = "cb_structures:trap_dispenser"
T.MAP["mcl_lever:lever_off"] = "cb_structures:temple_lever"
T.MAP["mcl_pistons:piston_sticky_off"] = "cb_structures:temple_door"
T.MAP["mcl_pressureplates:pressure_plate_stone_off"] = "air"
T.MAP["mcl_stairs:stair_cobble"] = "stairs:stair_cobble"
T.MAP["mcl_stairs:stair_cobble_outer"] = A.first("stairs:stair_outer_cobble", "stairs:stair_cobble")
T.MAP["mcl_stairs:stair_cobble_inner"] = A.first("stairs:stair_inner_cobble", "stairs:stair_cobble")
T.MAP["mcl_stairs:stair_mossycobble"] = A.first("stairs:stair_mossycobble", "stairs:stair_cobble")
T.MAP["mcl_stairs:stair_mossycobble_outer"] = A.first("stairs:stair_outer_mossycobble", "stairs:stair_cobble")
T.MAP["mcl_stairs:stair_mossycobble_inner"] = A.first("stairs:stair_inner_mossycobble", "stairs:stair_cobble")
T.map_prefix("mcl_redstone:wire_", "air")
T.map_prefix("mcl_repeaters:", "air")

JT.TPL = T.load(core.get_modpath("cb_structures") .. "/templates/jungle_temple.dat")

function JT.plan(origin, seed)
	local rng = PcgRandom(seed)
	local k = rng:next(0, 3)
	local w, d = JT.TPL.w, JT.TPL.l
	if k % 2 == 1 then
		w, d = d, w
	end
	local y, x1, z1 = cb_structures.surface.site(origin, w, d, JT.TPL.h, { max_drop = 6, below = 4, })
	if not y then
		return nil, x1
	end
	return { x = x1, y = y, z = z1, k = k, }
end

-- The template turned by k inside the planned box, its floor one below the
-- surface (it is half sunk, as in Minecraft).
function JT.layout(origin, seed, plan)
	local bb = T.bbox(JT.TPL, 0, 0, 0, plan.k)
	local w, d = bb[4] - bb[1] + 1, bb[6] - bb[3] + 1
	local a = vector.new(plan.x, plan.y - 1, plan.z)
	local b = vector.new(plan.x + w - 1, plan.y - 1 + JT.TPL.h - 1, plan.z + d - 1)
	-- level -> world: world = anchor + (x, y, -z); put the turned box's corner at a
	local anchor = vector.new(a.x - bb[1], a.y, b.z + bb[3])
	return { minp = a, maxp = b, pieces = { { minp = a, maxp = b, build = function(ctx)
		T.place(ctx, JT.TPL, anchor, 0, 0, 0, plan.k, { loot = "jungle_temple", all_chests = true, })
	end, }, }, }
end

cb_structures.register("jungle_temple", {
	description = S("Jungle Temple"),
	dims = { "overworld", },
	biome_words = { "rainforest", "jungle", "bamboo", "mangrove", },
	prepare = { radius = 48, below = 24, above = 40, },
	plan = JT.plan,
	layout = JT.layout,
})
