-- Trial chambers (plan 8f-1): Mineclonia's templates and pools
-- (mcl_levelgen/trial_chambers.lua) assembled by cb_structures.jigsaw like
-- the treasure bastion. Copper and tuff are cb_blocks' (one copper stage per
-- Mineclonia stage, no wax); decorated pots, beds, buttons and copper doors
-- are left out, dispensers stay wall. Trial spawners get the mob of their
-- template (the ranged pool also holds breezes, as in Secret Terra);
-- vaults are cb_mobs_trial's, ominous vaults are left out. Chests use
-- Bedrock's trial chamber loot with the servers' items. Underground: the
-- start corridor at the given height when that is -30 or lower, else at -40,
-- and nothing above -20. Nobody lives there: mobs come from the spawners.
local S = cb_structures.S
local T, J = cb_structures.templates, cb_structures.jigsaw
local DIR = core.get_modpath("cb_structures") .. "/templates/"
local TC = { RADIUS = 116, MAX_DEPTH = 20, MAX_PIECES = 400, TOP_Y = -20, DEEP_Y = -40, HIGHEST = -30, }
cb_structures.trial_chambers = TC
local SPAWNER, VAULT = "cb_mobs_trial:trial_spawner", "cb_mobs_trial:vault"

local function first(...)
	for _, n in ipairs({ ... }) do
		if core.registered_nodes[n] then
			return n
		end
	end
	return "air"
end

local M = T.MAP
local CB = "cb_blocks:"
for mcl, cb in pairs({
	tuff = "tuff", tuff_bricks = "tuff_bricks", tuff_chiseled = "chiseled_tuff",
	tuff_chiseled_bricks = "chiseled_tuff_bricks", tuff_polished = "polished_tuff",
}) do
	M["mcl_deepslate:" .. mcl] = CB .. cb
end
M["mcl_stairs:stair_tuff_bricks"] = "stairs:stair_cb_tuff_bricks"
M["mcl_stairs:slab_tuff_bricks_top"] = { "stairs:slab_cb_tuff_bricks", 20, }
M["mcl_copper:block_preserved"] = "default:copperblock"
for _, st in ipairs({ "exposed", "weathered", "oxidized", }) do
	M["mcl_copper:block_" .. st .. "_preserved"] = CB .. st .. "_copper"
	M["mcl_copper:block_" .. st .. "_cut_preserved"] = CB .. st .. "_cut_copper"
	M["mcl_copper:block_" .. st .. "_chiseled_preserved"] = CB .. st .. "_chiseled_copper"
	M["mcl_copper:block_" .. st .. "_chiseled"] = CB .. st .. "_chiseled_copper"
	M["mcl_copper:block_" .. st .. "_grate_preserved"] = CB .. st .. "_copper_grate"
	M["mcl_copper:bulb_" .. st .. "_on_preserved"] = CB .. st .. "_copper_bulb"
	M["mcl_lanterns:copper_chain_" .. st .. "_preserved"] = CB .. "chain"
end
M["mcl_copper:block_cut_preserved"] = CB .. "cut_copper"
M["mcl_copper:block_chiseled_preserved"] = CB .. "chiseled_copper"
M["mcl_copper:block_grate_preserved"] = CB .. "copper_grate"
M["mcl_copper:bulb_on_preserved"] = CB .. "copper_bulb"
M["mcl_lanterns:copper_chain_preserved"] = CB .. "chain"
for _, v in ipairs({ "", "oxidized_", }) do
	local slab = "stairs:slab_cb_" .. v .. "cut_copper"
	M["mcl_stairs:stair_copper_" .. v .. "cut_preserved"] = "stairs:stair_cb_" .. v .. "cut_copper"
	M["mcl_stairs:stair_copper_" .. v .. "cut_inner_preserved"] = "stairs:stair_inner_cb_" .. v .. "cut_copper"
	M["mcl_stairs:stair_copper_" .. v .. "cut_outer_preserved"] = "stairs:stair_outer_cb_" .. v .. "cut_copper"
	M["mcl_stairs:slab_copper_" .. v .. "cut_preserved"] = slab
	M["mcl_stairs:slab_copper_" .. v .. "cut_top_preserved"] = { slab, 20, }
	M["mcl_stairs:slab_copper_" .. v .. "cut_double_preserved"] = CB .. v .. "cut_copper"
end
M["mcl_stairs:slab_copper_exposed_cut_preserved"] = "stairs:slab_cb_cut_copper"
M["mcl_lanterns:copper_lantern_ceiling_preserved"] = CB .. "lantern_hanging"
M["mcl_lanterns:copper_lantern_exposed_ceiling_preserved"] = CB .. "lantern_hanging"
M["mcl_lanterns:copper_lantern_weathered_ceiling_preserved"] = CB .. "lantern_hanging"
M["mcl_lanterns:copper_lantern_oxidized_floor_preserved"] = CB .. "lantern"
M["mcl_copper:trapdoor_oxidized_open"] = first("doors:trapdoor_steel_open")
M["mcl_copper:trapdoor_oxidized_preserved_open"] = first("doors:trapdoor_steel_open")
M["mcl_doors:trapdoor_spruce_open"] = first("doors:trapdoor_open")
for _, n in ipairs({ "mcl_panes:copper_bar_oxidized", "mcl_panes:copper_bar_oxidized_flat_preserved",
	"mcl_panes:copper_bar_oxidized_preserved", "mcl_panes:copper_bar_preserved", "mcl_panes:copper_bar_weathered_preserved", }) do
	M[n] = first("xpanes:bar_flat")
end
M["mcl_lightning_rods:rod_oxidized_preserved"] = CB .. "chain"
M["mcl_lightning_rods:rod_weathered_preserved"] = CB .. "chain"
M["mcl_trial_spawners:trialspawner"] = SPAWNER
M["mcl_vaults:vault"] = VAULT
M["mcl_dispensers:dispenser"] = CB .. "tuff_bricks"
M["mcl_barrels:barrel_closed"] = "cb_blocks:barrel"
M["mcl_candles:candle_2"] = CB .. "candle_2"
M["mcl_candles:candle_4"] = CB .. "candle_4"
M["mcl_candles:candle_lit_3"] = CB .. "candle_3"
M["mcl_candles:candle_lit_4"] = CB .. "candle_4"
M["mcl_wool:purple_carpet"] = CB .. "carpet_violet"
M["mcl_nether:magma"] = CB .. "magma"
M["mcl_core:bone_block"] = first("bonemeal:bone_block", "default:silver_sandstone")
M["mcl_core:cobble"] = "default:cobble"
M["mcl_core:mossycobble"] = "default:mossycobble"
M["mcl_core:stone"] = "default:stone"
M["mcl_core:stonebrick"] = "default:stonebrick"
M["mcl_core:dirt"] = "default:dirt"
M["mcl_core:diamondblock"] = "default:diamondblock"
M["mcl_core:goldblock"] = "default:goldblock"
M["mcl_core:packed_ice"] = "default:ice"
M["mcl_core:sandstonecarved"] = "default:sandstone_block"
M["mcl_core:podzol"] = "default:dirt_with_coniferous_litter"
M["mcl_core:mycelium"] = first("ethereal:mushroom_dirt", "default:dirt_with_grass")
M["mcl_lush_caves:moss"] = "default:dirt_with_rainforest_litter"
M["mcl_core:water_source"] = "default:water_source"
M["mcl_core:water_flowing"] = "default:water_flowing"
M["mcl_trees:leaves_oak"] = "default:leaves"
M["mcl_trees:tree_oak"] = "default:tree"
M["mcl_flowers:allium"] = first("flowers:viola")
M["mcl_flowers:waterlily"] = first("flowers:waterlily")
M["mcl_mushrooms:mushroom_red"] = first("flowers:mushroom_red")
M["mcl_farming:pumpkin_face"] = first("farming:pumpkin", "farming:jackolantern")
for _, n in ipairs({ "mcl_vaults:ominous_vault", "mcl_pottery_sherds:pot", "mcl_buttons:button_oak_off",
	"mcl_flowerpots:flower_pot", "mcl_flowerpots:flower_pot_allium", "mcl_copper:door_oxidized_preserved_b_1",
	"mcl_copper:door_oxidized_preserved_t_1", "mcl_copper:door_weathered_preserved_b_1",
	"mcl_copper:door_weathered_preserved_t_1", }) do
	M[n] = "air"
end
for _, c in ipairs({ "blue", "brown", "green", "orange", "purple", }) do
	M["mcl_beds:bed_" .. c .. "_bottom"] = "air"
	M["mcl_beds:bed_" .. c .. "_top"] = "air"
end

-- Template name -> loaded template, and back.
local cache, names = {}, {}
local function L(name, weight)
	if not cache[name] then
		cache[name] = T.load(DIR .. name .. ".dat")
		names[cache[name]] = name
	end
	return { tpl = cache[name], weight = weight, }
end
TC.TEMPLATES, TC.NAMES = cache, names
local P = "mcl_levelgen:trial_chambers_"
local function pool(id, list)
	local el = {}
	for _, e in ipairs(list) do
		el[#el + 1] = L("trial_chambers_" .. e[1], e[2])
	end
	J.register_pool(P .. id, el)
end
pool("ends", { { "corridor_end_1", 1, }, })
pool("chambers", { { "corridor_chamber_1", 1, }, { "corridor_chamber_2", 1, }, })
pool("big_chambers", { { "corridor_chamber_1", 1, }, })
pool("hallway_1_entrances", { { "hallway_1_entrance_1", 1, }, })
pool("hallway_1_slices", { { "hallway_1_slice_1", 2, }, { "hallway_1_slice_2", 2, }, { "hallway_1_slice_3", 2, },
	{ "hallway_1_slice_4", 2, }, { "hallway_1_exit_1", 6, }, })
pool("intersections", { { "corridor_intersection_1", 1, }, })
pool("branches", { { "branch_1", 1, }, })
pool("branch_lefts", { { "branch_left_1", 1, }, { "branch_left_2", 1, }, { "branch_left_3", 1, }, { "branch_left_4", 1, }, })
pool("branch_rights", { { "branch_right_1", 1, }, { "branch_right_2", 1, }, { "branch_right_3", 1, },
	{ "branch_right_4", 1, }, })
pool("branch_upstair_addons", { { "branch_upstair_addon_1", 1, }, { "branch_upstair_addon_2", 2, }, })
pool("hallway_2_entrances", { { "hallway_2_entrance_1", 1, }, })
pool("hallway_2_slices", { { "hallway_2_slice_1", 2, }, { "hallway_2_slice_2", 2, }, { "hallway_2_slice_3", 2, },
	{ "hallway_2_slice_4", 2, }, { "hallway_2_exit_1", 3, }, })
pool("atriums", { { "corridor_atrium_1", 1, }, })
pool("entrances", { { "corridor_entrance_1", 1, }, })
pool("decor_bigs", { { "decor_big_oak_tree", 1, }, { "decor_big_fountain", 1, }, })
pool("decor_pots", { { "decor_pots_empty", 24, }, { "decor_pots_regular", 2, }, { "decor_barrel", 1, }, })
pool("decor_pots_2", { { "decor_pots_regular", 1, }, })
pool("melee_spawners", { { "spawner_zombie", 1, }, { "spawner_husk", 1, }, { "spawner_spider", 1, }, })
pool("small_melee_spawners", { { "spawner_slime", 1, }, { "spawner_silverfish", 1, }, { "spawner_baby_zombie", 1, },
	{ "spawner_cave_spider", 1, }, })
pool("ranged_spawners", { { "spawner_stray", 1, }, { "spawner_skeleton", 1, }, { "spawner_bogged", 1, },
	{ "spawner_breeze", 1, }, })

-- Spawner template -> mob, and the pool to fall back on when the server
-- lacks it.
TC.SPAWNER_MOBS = {
	zombie = { "cb_mobs_overworld:zombie", "melee", }, husk = { "cb_mobs_overworld:husk", "melee", },
	spider = { "mobs_monster:spider", "melee", }, slime = { "mobs_slimes:greensmall", "small_melee", },
	silverfish = { "cb_mobs_overworld:silverfish", "small_melee", },
	baby_zombie = { "cb_mobs_overworld:zombie:baby", "small_melee", },
	cave_spider = { "cb_mobs_village:cave_spider", "small_melee", }, stray = { "cb_mobs_overworld:stray", "ranged", },
	skeleton = { "mobs_skeletons:skeleton_archer", "ranged", }, bogged = { "cb_mobs_trial:bogged", "ranged", },
	breeze = { "cb_mobs_trial:breeze", "ranged", },
}

-- The mob a spawner of template `name` calls on this server, or nil.
function TC.spawner_mob(name)
	local kind = name and name:match("^trial_chambers_spawner_(.+)$")
	local m = kind and TC.SPAWNER_MOBS[kind]
	if not m then
		return nil
	end
	if core.registered_entities[(m[1]:gsub(":baby$", ""))] then
		return m[1]
	end
	local tr = rawget(_G, "cb_mobs_trial")
	return tr and tr.trial.pick(m[2])
end

TC.LOOT = {
	["mcl_levelgen:trial_chambers_chest_entrance_loot"] = "trial_chambers_entrance",
	["mcl_levelgen:trial_chambers_chest_intersection_loot"] = "trial_chambers_intersection",
	["mcl_levelgen:trial_chambers_chest_supply_loot"] = "trial_chambers_supply",
}

function TC.base(origin)
	return origin.y <= TC.HIGHEST and origin.y or TC.DEEP_Y
end

function TC.layout(origin, seed)
	local base = TC.base(origin)
	local R = TC.RADIUS
	local bounds = { -R, -60, -R, R, TC.TOP_Y - base, R, }
	local start = cache.trial_chambers_corridor_end_1
	local pieces = J.assemble(P .. "ends", PcgRandom(seed), -math.floor(start.w / 2), 0, -math.floor(start.l / 2),
		{ max_depth = TC.MAX_DEPTH, max_pieces = TC.MAX_PIECES, bounds = bounds, })
	local anchor = vector.new(origin.x, base, origin.z)
	local opts = { loot = function(what)
		return TC.LOOT[what]
	end, }
	local out, lo, hi = {}, nil, nil
	for _, p in ipairs(pieces) do
		local a = vector.new(anchor.x + p.bbox[1], anchor.y + p.bbox[2], anchor.z - p.bbox[6])
		local b = vector.new(anchor.x + p.bbox[4], anchor.y + p.bbox[5], anchor.z - p.bbox[3])
		local mob = TC.spawner_mob(names[p.tpl])
		out[#out + 1] = { minp = a, maxp = b, part = true, kind = "chambers", build = function(ctx)
			T.place(ctx, p.tpl, anchor, p.x, p.y, p.z, p.k, opts)
			if mob then
				ctx.after(function()
					for _, sp in ipairs(core.find_nodes_in_area(a, b, { SPAWNER, })) do
						core.get_meta(sp):set_string("mob", mob)
					end
				end)
			end
		end, }
		lo = lo and vector.new(math.min(lo.x, a.x), math.min(lo.y, a.y), math.min(lo.z, a.z)) or vector.copy(a)
		hi = hi and vector.new(math.max(hi.x, b.x), math.max(hi.y, b.y), math.max(hi.z, b.z)) or vector.copy(b)
	end
	return { minp = lo, maxp = hi, pieces = out, }
end

cb_structures.register("trial_chambers", {
	description = S("Trial Chambers"),
	dims = { "overworld", },
	underground = true,
	y_max = TC.TOP_Y,
	scatter_y = function(ground)
		return math.min(TC.HIGHEST, ground - 40)
	end,
	layout = TC.layout,
	sample_exclude = { ["default:chest"] = true, ["default:chest_open"] = true, [SPAWNER] = true,
		["cb_mobs_trial:trial_spawner_active"] = true, [VAULT] = true, ["cb_mobs_trial:vault_active"] = true,
		["default:water_source"] = true, ["default:water_flowing"] = true, },
})

-- Bedrock's trial chamber chest loot with what the servers have (no bows,
-- arrows, potions, amethyst, bamboo or glow berries).
local loot = cb_structures.loot
local function e(items, w, a, b)
	return { items = items, w = w, n = a and { a, b, } or nil, }
end
loot.register("trial_chambers_entrance", { { rolls = { 2, 3, }, entries = { e({ "default:axe_wood", }, 10),
	e({ "default:stick", }, 5, 2, 5), e({ "xdecor:honey", "bees:honey_comb", }, 10, 2, 8),
	e({ "cb_mobs_trial:trial_key", }, 1), }, }, })
loot.register("trial_chambers_intersection", { { rolls = { 1, 3, }, entries = { e({ "farming:cake", "default:apple", }, 20, 1, 4),
	e({ "default:steelblock", }, 20, 1, 2), e({ "default:diamond", }, 10, 1, 2), e({ "default:axe_diamond", }, 5),
	e({ "default:pick_diamond", }, 5), e({ "default:diamondblock", }, 1), }, }, })
loot.register("trial_chambers_supply", { { rolls = { 3, 5, }, entries = { e({ "farming:baked_potato", }, 2, 2, 4),
	e({ "default:pick_stone", }, 2), e({ "cb_blocks:tuff", }, 1, 5, 10), e({ "default:acacia_wood", }, 1, 3, 6),
	e({ "default:torch", }, 1, 3, 6), e({ "bonemeal:bonemeal", }, 1, 2, 5), e({ "bucket:bucket_empty", }, 1), }, }, })
