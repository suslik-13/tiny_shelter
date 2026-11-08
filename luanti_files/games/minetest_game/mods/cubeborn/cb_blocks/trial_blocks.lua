-- Trial chamber blocks (plan 8f): tuff and its cut kinds, and copper in four
-- stages of oxidation (cut, chiseled, grates, lit bulbs; the plain block of
-- the first stage is the server's default:copperblock). Copper here does not
-- oxidize or get waxed: the stages come from the structures, the first one
-- from crafts. Bulbs are always lit (no redstone). Textures from Mineclonia's
-- mcl_deepslate and mcl_copper.
local S = cb_blocks.S
local node, tex = cb_blocks.node, cb_blocks.tex
local stone, metal = default.node_sound_stone_defaults(), default.node_sound_metal_defaults()
local glass = default.node_sound_glass_defaults()
local COPPER = "default:copperblock"

node("tuff", {
	description = S("Tuff"),
	tiles = { tex("tuff"), },
	groups = { cracky = 3, stone = 1, },
	sounds = stone,
}, { stairs = { S("Tuff Stairs"), S("Tuff Slab"), }, wall = S("Tuff Wall"), })
node("polished_tuff", {
	description = S("Polished Tuff"),
	tiles = { tex("polished_tuff"), },
	groups = { cracky = 3, stone = 1, },
	sounds = stone,
}, { stairs = { S("Polished Tuff Stairs"), S("Polished Tuff Slab"), }, wall = S("Polished Tuff Wall"), })
node("tuff_bricks", {
	description = S("Tuff Bricks"),
	tiles = { tex("tuff_bricks"), },
	groups = { cracky = 3, stone = 1, },
	sounds = stone,
}, { stairs = { S("Tuff Brick Stairs"), S("Tuff Brick Slab"), }, wall = S("Tuff Brick Wall"), })
node("chiseled_tuff", {
	description = S("Chiseled Tuff"),
	tiles = { tex("chiseled_tuff_top"), tex("chiseled_tuff_top"), tex("chiseled_tuff"), },
	groups = { cracky = 3, stone = 1, },
	sounds = stone,
})
node("chiseled_tuff_bricks", {
	description = S("Chiseled Tuff Bricks"),
	tiles = { tex("chiseled_tuff_bricks_top"), tex("chiseled_tuff_bricks_top"), tex("chiseled_tuff_bricks"), },
	groups = { cracky = 3, stone = 1, },
	sounds = stone,
})

local function square(output, input)
	core.register_craft({ output = output .. " 4", recipe = { { input, input, }, { input, input, }, }, })
end
local function stack2(output, input)
	core.register_craft({ output = output, recipe = { { input, }, { input, }, }, })
end
square("cb_blocks:polished_tuff", "cb_blocks:tuff")
square("cb_blocks:tuff_bricks", "cb_blocks:polished_tuff")
stack2("cb_blocks:chiseled_tuff", "stairs:slab_cb_tuff")
stack2("cb_blocks:chiseled_tuff_bricks", "stairs:slab_cb_tuff_bricks")

-- Copper: { prefix of the texture, name prefix, description of the stage }.
local STAGES = {
	{ "block", "", S("Cut Copper"), S("Chiseled Copper"), S("Copper Grate"), S("Copper Bulb"), core.LIGHT_MAX, },
	{ "exposed", "exposed_", S("Exposed Cut Copper"), S("Exposed Chiseled Copper"), S("Exposed Copper Grate"),
		S("Exposed Copper Bulb"), 12, S("Exposed Copper"), },
	{ "weathered", "weathered_", S("Weathered Cut Copper"), S("Weathered Chiseled Copper"),
		S("Weathered Copper Grate"), S("Weathered Copper Bulb"), 8, S("Weathered Copper"), },
	{ "oxidized", "oxidized_", S("Oxidized Cut Copper"), S("Oxidized Chiseled Copper"), S("Oxidized Copper Grate"),
		S("Oxidized Copper Bulb"), 4, S("Oxidized Copper"), },
}
local CUT_STAIRS = {
	[""] = { S("Cut Copper Stairs"), S("Cut Copper Slab"), },
	["oxidized_"] = { S("Oxidized Cut Copper Stairs"), S("Oxidized Cut Copper Slab"), },
}
local copper_groups = { cracky = 2, level = 1, }
for _, st in ipairs(STAGES) do
	local t, p = st[1], st[2]
	local base = t == "block" and "copper_block" or "copper_" .. t
	if st[8] then
		node(p .. "copper", {
			description = st[8],
			tiles = { tex(base), },
			groups = copper_groups,
			sounds = metal,
		})
	end
	node(p .. "cut_copper", {
		description = st[3],
		tiles = { tex(base .. "_cut"), },
		groups = copper_groups,
		sounds = metal,
	}, { stairs = CUT_STAIRS[p], })
	node(p .. "chiseled_copper", {
		description = st[4],
		tiles = { tex(base .. "_chiseled"), },
		groups = copper_groups,
		sounds = metal,
	})
	node(p .. "copper_grate", {
		description = st[5],
		drawtype = "glasslike",
		tiles = { tex(base .. "_grate"), },
		use_texture_alpha = "clip",
		paramtype = "light",
		sunlight_propagates = true,
		groups = copper_groups,
		sounds = glass,
	})
	node(p .. "copper_bulb", {
		description = st[6],
		tiles = { tex(base .. "_bulb_on"), },
		paramtype = "light",
		light_source = st[7],
		groups = copper_groups,
		sounds = metal,
	})
end
square("cb_blocks:cut_copper", COPPER)
-- four blocks in a ring (2x2 is cut copper)
core.register_craft({ output = "cb_blocks:copper_grate 4", recipe = { { "", COPPER, "", }, { COPPER, "", COPPER, },
	{ "", COPPER, "", }, }, })
stack2("cb_blocks:chiseled_copper", "stairs:slab_cb_cut_copper")
core.register_craft({ output = "cb_blocks:copper_bulb 4",
	recipe = { { "", COPPER, "", }, { COPPER, "cb_items:blaze_rod", COPPER, }, { "", "default:torch", "", }, }, })
