-- Village blocks: the bell (rings and calls the hooks of other mods: villagers
-- go home, raids light up) and the villagers' job sites; their working parts
-- live in composter.lua, barrel.lua, fast_furnace.lua, grindstone.lua,
-- stonecutter.lua, lectern.lua (cb_items: smithing.lua). Textures from
-- Mineclonia; the bell is a node box in gold.
local S = cb_blocks.S
local node, tex = cb_blocks.node, cb_blocks.tex

cb_blocks.bell_hooks = {}
-- fn(pos, placer) when a bell is placed; fn(pos) when it goes (dug, blown up)
cb_blocks.bell_place_hooks, cb_blocks.bell_remove_hooks = {}, {}

function cb_blocks.ring_bell(pos, player)
	core.sound_play("cb_blocks_bell", { pos = pos, gain = 1.0, max_hear_distance = 48, }, true)
	for _, fn in ipairs(cb_blocks.bell_hooks) do
		fn(vector.copy(pos), player)
	end
end

node("bell", {
	description = S("Bell"),
	drawtype = "nodebox",
	tiles = { "default_gold_block.png", },
	paramtype = "light",
	sunlight_propagates = true,
	node_box = { type = "fixed", fixed = {
		{ -1 / 16, 6 / 16, -1 / 16, 1 / 16, 8 / 16, 1 / 16, },
		{ -3 / 16, 1 / 16, -3 / 16, 3 / 16, 6 / 16, 3 / 16, },
		{ -4 / 16, -2 / 16, -4 / 16, 4 / 16, 1 / 16, 4 / 16, },
	}, },
	groups = { cracky = 2, cb_bell = 1, },
	sounds = default.node_sound_metal_defaults(),
	on_punch = function(pos, _, puncher)
		cb_blocks.ring_bell(pos, puncher)
	end,
	on_rightclick = function(pos, _, clicker, itemstack)
		cb_blocks.ring_bell(pos, clicker)
		return itemstack
	end,
	after_place_node = function(pos, placer)
		for _, fn in ipairs(cb_blocks.bell_place_hooks) do
			fn(vector.copy(pos), placer)
		end
	end,
	on_destruct = function(pos)
		for _, fn in ipairs(cb_blocks.bell_remove_hooks) do
			fn(vector.copy(pos))
		end
	end,
})

local WOOD = default.node_sound_wood_defaults()
local STONE = default.node_sound_stone_defaults()
-- name -> description, tiles (+Y, -Y, +X, -X, +Z, -Z: the front is -Z), sounds
local JOBS = {
	barrel = { S("Barrel"), { "barrel_top", "barrel_bottom", "barrel_side", }, WOOD, },
	blast_furnace = { S("Blast Furnace"), { "blast_furnace_top", "blast_furnace_top", "blast_furnace_side",
		"blast_furnace_side", "blast_furnace_side", "blast_furnace_front", }, STONE, },
	cartography_table = { S("Cartography Table"), { "cartography_table_top", "cartography_table_side3",
		"cartography_table_side3", "cartography_table_side1", "cartography_table_side2", "cartography_table_side1", },
		WOOD, },
	cauldron = { S("Cauldron"), { "cauldron_top", "cauldron_bottom", "cauldron_side", }, default.node_sound_metal_defaults(), },
	composter = { S("Composter"), { "composter_top", "composter_bottom", "composter_side", }, WOOD, },
	fletching_table = { S("Fletching Table"), { "fletching_table_top", "fletching_table_bottom", "fletching_table_side",
		"fletching_table_side", "fletching_table_front", "fletching_table_front", }, WOOD, },
	grindstone = { S("Grindstone"), { "grindstone_top", "grindstone_top", "grindstone_side", "grindstone_side",
		"grindstone_front", "grindstone_front", }, STONE, },
	loom = { S("Loom"), { "loom_top", "loom_bottom", "loom_side", "loom_side", "loom_side", "loom_front", }, WOOD, },
	smithing_table = { S("Smithing Table"), { "smithing_table_top", "smithing_table_bottom", "smithing_table_side",
		"smithing_table_side", "smithing_table_front", "smithing_table_front", }, WOOD, },
	smoker = { S("Smoker"), { "smoker_top", "smoker_bottom", "smoker_side", "smoker_side", "smoker_side",
		"smoker_front", }, STONE, },
	stonecutter = { S("Stonecutter"), { "stonecutter_top", "stonecutter_bottom", "stonecutter_side", }, STONE, },
}

for name, j in pairs(JOBS) do
	local key = "village_" .. name
	cb_core.register_equiv(key, name == "cauldron" and { "xdecor:cauldron_empty", "cb_blocks:cauldron", }
		or { "cb_blocks:" .. name, })
	local tiles = {}
	for i, t in ipairs(j[2]) do
		tiles[i] = tex(t)
	end
	node(name, {
		description = j[1],
		tiles = tiles,
		paramtype2 = "facedir",
		groups = { choppy = 2, oddly_breakable_by_hand = 1, cb_jobsite = 1, },
		sounds = j[3],
		on_place = core.rotate_node,
	}, { equiv = key, })
end

cb_core.register_equiv("village_lectern", { "cb_blocks:lectern", })
node("lectern", {
	description = S("Lectern"),
	drawtype = "mesh",
	mesh = "cb_blocks_lectern.obj",
	tiles = { tex("lectern"), },
	paramtype = "light",
	paramtype2 = "facedir",
	selection_box = { type = "fixed", fixed = { -0.5, -0.5, -0.5, 0.5, 0.375, 0.5, }, },
	collision_box = { type = "fixed", fixed = { -0.5, -0.5, -0.5, 0.5, 0.375, 0.5, }, },
	groups = { choppy = 2, oddly_breakable_by_hand = 1, cb_jobsite = 1, },
	sounds = WOOD,
}, { equiv = "village_lectern", })
-- Brewing stand: the cleric's job site, decoration until potions (cycle 5).
cb_core.register_equiv("village_brewing_stand", { "cb_blocks:brewing_stand", })
node("brewing_stand", {
	description = S("Brewing Stand"),
	drawtype = "mesh",
	mesh = "cb_blocks_brewing_stand.obj",
	tiles = { tex("brewing_stand"), tex("brewing_rack"), tex("brewing_rack"), tex("brewing_rack"), },
	use_texture_alpha = "clip",
	paramtype = "light",
	sunlight_propagates = true,
	selection_box = { type = "fixed", fixed = { -6 / 16, -8 / 16, -6 / 16, 6 / 16, 6 / 16, 6 / 16, }, },
	collision_box = { type = "fixed", fixed = { -6 / 16, -8 / 16, -6 / 16, 6 / 16, 6 / 16, 6 / 16, }, },
	groups = { cracky = 2, cb_jobsite = 1, },
	sounds = default.node_sound_metal_defaults(),
}, { equiv = "village_brewing_stand", })
core.register_craft({ output = "cb_blocks:brewing_stand", recipe = {
	{ "", "default:stick", "", },
	{ "default:cobble", "default:cobble", "default:cobble", },
}, })

-- Recipes after Minecraft, on the server's items.
local function craft(name, recipe)
	if cb_blocks.registered["cb_blocks:" .. name] then
		core.register_craft({ output = "cb_blocks:" .. name, recipe = recipe, })
	end
end
local W, SL, ST, I, T = "group:wood", "stairs:slab_wood", "default:stone", "default:steel_ingot", "group:tree"
craft("composter", { { SL, "", SL, }, { SL, "", SL, }, { SL, SL, SL, }, })
craft("barrel", { { W, SL, W, }, { W, "", W, }, { W, SL, W, }, })
craft("smoker", { { "", T, "", }, { T, "default:furnace", T, }, { "", T, "", }, })
craft("blast_furnace", { { I, I, I, }, { I, "default:furnace", I, }, { ST, ST, ST, }, })
craft("stonecutter", { { "", I, "", }, { ST, ST, ST, }, })
craft("grindstone", { { "default:stick", "stairs:slab_stone", "default:stick", }, { W, "", W, }, })
craft("smithing_table", { { I, I, }, { W, W, }, { W, W, }, })
craft("lectern", { { SL, SL, SL, }, { "", "default:bookshelf", "", }, { "", SL, "", }, })
craft("cartography_table", { { "default:paper", "default:paper", }, { W, W, }, { W, W, }, })
craft("fletching_table", { { "default:flint", "default:flint", }, { W, W, }, { W, W, }, })
