-- Shipwreck (spec cycle 7): Mineclonia's five wrecks (levelgen templates).
-- An ocean wreck lies on the sea floor (the footprint's average height - 1,
-- as in Mineclonia) and is full of water; a beached one sinks a quarter of
-- its height and up to two more into the ground. The hull is of one random
-- server wood and the trim of another (Mineclonia's spruce and dark oak).
-- Up to three chests: supply, map and treasure. Placed only by admins.
local S = cb_structures.S
local T = cb_structures.templates
local A = cb_structures.piecegen
-- HULL: the water a wreck needs, its hull's rows (the masts may stick out)
local SW = { HULL = 10, }
cb_structures.shipwreck = SW

local function wood(planks, log, stair, slab, fence)
	return { planks = A.first(planks, "default:wood"), log = A.first(log, "default:tree"),
		stair = A.first(stair, "stairs:stair_wood"), slab = A.first(slab, "stairs:slab_wood"),
		fence = A.first(fence, "default:fence_wood"), }
end
SW.WOODS = {
	wood("default:wood", "default:tree", "stairs:stair_wood", "stairs:slab_wood", "default:fence_wood"),
	wood("default:pine_wood", "default:pine_tree", "stairs:stair_pine_wood", "stairs:slab_pine_wood",
		"default:fence_pine_wood"),
	wood("default:aspen_wood", "default:aspen_tree", "stairs:stair_aspen_wood", "stairs:slab_aspen_wood",
		"default:fence_aspen_wood"),
	wood("default:acacia_wood", "default:acacia_tree", "stairs:stair_acacia_wood", "stairs:slab_acacia_wood",
		"default:fence_acacia_wood"),
	wood("default:junglewood", "default:jungletree", "stairs:stair_junglewood", "stairs:slab_junglewood",
		"default:fence_junglewood"),
}
-- The templates map to these two sets; the build swaps them for the plan's.
local HULL, TRIM = SW.WOODS[2], SW.WOODS[5]

T.MAP["mcl_trees:wood_spruce"] = HULL.planks
T.MAP["mcl_trees:stripped_spruce"] = HULL.log
T.MAP["mcl_trees:bark_stripped_spruce"] = HULL.log
T.MAP["mcl_stairs:stair_spruce"] = HULL.stair
T.MAP["mcl_stairs:slab_spruce"] = HULL.slab
T.MAP["mcl_stairs:slab_spruce_top"] = { HULL.slab, 20, }
T.MAP["mcl_fences:spruce_fence"] = HULL.fence
T.MAP["mcl_trees:wood_dark_oak"] = TRIM.planks
T.MAP["mcl_stairs:stair_dark_oak"] = TRIM.stair
T.MAP["mcl_stairs:slab_dark_oak"] = TRIM.slab
T.MAP["mcl_stairs:slab_dark_oak_top"] = { TRIM.slab, 20, }
T.MAP["mcl_fences:dark_oak_fence"] = TRIM.fence
T.MAP["mcl_doors:trapdoor_spruce"] = A.first("doors:trapdoor", "air")
T.MAP["mcl_doors:trapdoor_spruce_open"] = A.first("doors:trapdoor_open", "air")
T.MAP["mcl_doors:door_spruce_b_2"] = A.first("doors:door_wood_a", "air")
T.MAP["mcl_doors:door_spruce_t_2"] = A.first("doors:hidden", "air")
-- a stray block in Mineclonia's full_damaged wreck: hull planks
T.MAP["mcl_core:diamondblock"] = HULL.planks

local DIR = core.get_modpath("cb_structures") .. "/templates/shipwreck_"
SW.TPLS = {}
for i, f in ipairs({ "full_normal", "full_damaged", "full_back_damaged", "half_front", "half_back", }) do
	SW.TPLS[i] = T.load(DIR .. f .. ".dat")
end

local loot = cb_structures.loot
loot.register("shipwreck_map", {
	{ rolls = { 3, 3, }, entries = {
		{ items = { "default:paper", }, w = 20, n = { 1, 10, }, },
		{ items = { "mobs:chicken_feather", }, w = 10, n = { 1, 5, }, },
		{ items = { "default:book", }, w = 5, n = { 1, 5, }, },
		{ items = { "cb_items:clock", }, w = 1, },
		{ items = { "cb_items:compass", }, w = 1, },
	}, },
	{ rolls = { 1, 1, }, entries = { { w = 5, }, { items = { "cb_items:trim_coast", }, w = 1, n = { 2, 2, }, }, }, },
})
loot.register("shipwreck_treasure", {
	{ rolls = { 2, 6, }, entries = {
		{ items = { "default:steel_ingot", }, w = 90, n = { 1, 5, }, },
		{ items = { "cb_items:iron_nugget", }, w = 50, n = { 1, 10, }, },
		{ items = { "cb_items:emerald", }, w = 40, n = { 1, 5, }, },
		{ items = { "cb_items:lapis_lazuli", }, w = 20, n = { 1, 10, }, },
		{ items = { "default:gold_ingot", }, w = 10, n = { 1, 5, }, },
		{ items = { "cb_items:gold_nugget", }, w = 10, n = { 1, 10, }, },
		{ items = { "cb_xp:bottle", }, w = 5, },
		{ items = { "default:diamond", }, w = 5, },
	}, },
	{ rolls = { 1, 1, }, entries = { { w = 5, }, { items = { "cb_items:trim_coast", }, w = 1, n = { 2, 2, }, }, }, },
})
loot.register("shipwreck_supply", {
	{ rolls = { 3, 10, }, entries = {
		{ items = { "ethereal:mushroom_soup", }, w = 10, },
		{ items = { "default:paper", }, w = 8, n = { 1, 12, }, },
		{ items = { "farming:wheat", }, w = 7, n = { 8, 21, }, },
		{ items = { "farming:carrot", }, w = 7, n = { 4, 8, }, },
		{ items = { "farming:potato", }, w = 10, n = { 2, 6, }, },
		{ items = { "default:coal_lump", }, w = 6, n = { 2, 8, }, },
		{ items = { "cb_items:rotten_flesh", "mobs:rotten_flesh", }, w = 5, n = { 5, 24, }, },
		{ items = { "farming:potato", }, w = 3, n = { 1, 5, }, },
		{ items = { "3d_armor:helmet_leather", }, w = 3, ench = "uniform", },
		{ items = { "3d_armor:chestplate_leather", }, w = 3, ench = "uniform", },
		{ items = { "3d_armor:leggings_leather", }, w = 3, ench = "uniform", },
		{ items = { "3d_armor:boots_leather", }, w = 3, ench = "uniform", },
		{ items = { "ethereal:bamboo", }, w = 2, n = { 1, 3, }, },
		{ items = { "farming:pumpkin_8", "farming:pumpkin", }, w = 2, n = { 1, 3, }, },
		{ items = { "tnt:tnt", }, w = 1, n = { 1, 2, }, },
	}, },
	{ rolls = { 1, 1, }, entries = { { w = 5, }, { items = { "cb_items:trim_coast", }, w = 1, n = { 2, 2, }, }, }, },
})
local LOOT = { ["mcl_levelgen:shipwreck_supply"] = "shipwreck_supply", ["mcl_levelgen:shipwreck_map"] = "shipwreck_map",
	["mcl_levelgen:shipwreck_treasure"] = "shipwreck_treasure", }

local function is_water(name)
	return core.get_item_group(name, "water") > 0
end

-- Template air under the sea surface is water, whatever the map held there
-- (no air pockets; only ocean types call it, and they stand under the sea).
function SW.flood(name, pos)
	if name == "air" and pos.y <= 1 then
		return "default:water_source"
	end
	return name
end

-- The first walkable node at or below y in column x, z (nil within 48).
function SW.floor_at(x, y, z)
	for yy = y, y - 48, -1 do
		local def = core.registered_nodes[core.get_node(vector.new(x, yy, z)).name]
		if def and def.walkable then
			return yy
		end
	end
end

-- The shallowest water over a w x d footprint at x1, z1: the centre and
-- the four corners (0 where there is no floor within reach).
function SW.depth(x1, z1, w, d)
	local least = math.huge
	for _, c in ipairs({ { math.floor(w / 2), math.floor(d / 2), }, { 0, 0, }, { w - 1, 0, }, { 0, d - 1, }, { w - 1, d - 1, }, }) do
		local f = SW.floor_at(x1 + c[1], 1, z1 + c[2])
		least = math.min(least, f and 1 - f or 0)
	end
	return least
end

function SW.plan(origin, seed, variant)
	local rng = PcgRandom(seed)
	local t = rng:next(1, #SW.TPLS)
	local k = rng:next(0, 3)
	local hull, trim = rng:next(1, #SW.WOODS), rng:next(1, #SW.WOODS)
	local tpl = SW.TPLS[t]
	local bb = T.bbox(tpl, 0, 0, 0, k)
	local w, d = bb[4] - bb[1] + 1, bb[6] - bb[3] + 1
	local plan = { t = t, k = k, hull = hull, trim = trim, variant = variant, }
	if variant == "beached" then
		local y, x1, z1 = cb_structures.surface.site(origin, w, d, tpl.h, { max_drop = 4, below = 4, })
		if not y then
			return nil, x1
		end
		plan.x, plan.z = x1, z1
		plan.y = y - math.floor(tpl.h / 4) - rng:next(0, 2)
		return plan
	end
	plan.x, plan.z = origin.x - math.floor(w / 2), origin.z - math.floor(d / 2)
	if SW.depth(plan.x, plan.z, w, d) < SW.HULL then
		return nil, S("A shipwreck needs water at least @1 deep.", SW.HULL)
	end
	local sum, n = 0, 0
	for x = plan.x, plan.x + w - 1, 2 do
		for z = plan.z, plan.z + d - 1, 2 do
			local fy = SW.floor_at(x, 1, z)
			if fy then
				sum, n = sum + fy, n + 1
			end
		end
	end
	plan.y = math.floor(sum / math.max(1, n) + 0.5)
	return plan
end

function SW.layout(origin, seed, plan)
	local tpl = SW.TPLS[plan.t]
	local bb = T.bbox(tpl, 0, 0, 0, plan.k)
	local w, d = bb[4] - bb[1] + 1, bb[6] - bb[3] + 1
	local a = vector.new(plan.x, plan.y, plan.z)
	local b = vector.new(plan.x + w - 1, plan.y + tpl.h - 1, plan.z + d - 1)
	local anchor = vector.new(a.x - bb[1], a.y, b.z + bb[3])
	local swap = {}
	for key, n in pairs(HULL) do
		swap[n] = SW.WOODS[plan.hull][key]
	end
	for key, n in pairs(TRIM) do
		swap[n] = SW.WOODS[plan.trim][key]
	end
	local ocean = plan.variant ~= "beached"
	return { minp = a, maxp = b, pieces = { { minp = a, maxp = b, build = function(ctx)
		T.place(ctx, tpl, anchor, 0, 0, 0, plan.k, {
			loot = function(what)
				return LOOT[what]
			end,
			process = function(name, pos)
				name = swap[name] or name
				return ocean and SW.flood(name, pos) or name
			end,
		})
	end, }, }, }
end

cb_structures.register("shipwreck", {
	description = S("Shipwreck"),
	dims = { "overworld", },
	water = true,
	variants = { "ocean", "beached", },
	pick_variant = function(origin)
		local here, below = core.get_node(origin).name, core.get_node(vector.offset(origin, 0, -1, 0)).name
		return (is_water(here) or is_water(below)) and "ocean" or "beached"
	end,
	prepare = { radius = 24, below = 48, above = 24, },
	plan = SW.plan,
	layout = SW.layout,
})
