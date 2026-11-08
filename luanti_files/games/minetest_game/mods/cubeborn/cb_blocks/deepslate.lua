-- Deepslate (ancient cities, plan 8e): the stone, its cut and cracked kinds
-- with Bedrock crafts, and reinforced deepslate, which nothing breaks.
-- Textures from Mineclonia's mcl_deepslate.
local S = cb_blocks.S
local node, tex = cb_blocks.node, cb_blocks.tex
local stone = default.node_sound_stone_defaults()

node("deepslate", {
	description = S("Deepslate"),
	tiles = { tex("deepslate_top"), tex("deepslate_top"), tex("deepslate"), },
	paramtype2 = "facedir",
	on_place = core.rotate_node,
	groups = { cracky = 2, stone = 1, },
	drop = "cb_blocks:cobbled_deepslate",
	sounds = stone,
}, { natural = true, })

local cut = {
	{ "cobbled_deepslate", S("Cobbled Deepslate"), S("Cobbled Deepslate Stairs"), S("Cobbled Deepslate Slab"),
		S("Cobbled Deepslate Wall"), },
	{ "polished_deepslate", S("Polished Deepslate"), S("Polished Deepslate Stairs"), S("Polished Deepslate Slab"),
		S("Polished Deepslate Wall"), },
	{ "deepslate_bricks", S("Deepslate Bricks"), S("Deepslate Brick Stairs"), S("Deepslate Brick Slab"),
		S("Deepslate Brick Wall"), },
	{ "deepslate_tiles", S("Deepslate Tiles"), S("Deepslate Tile Stairs"), S("Deepslate Tile Slab"),
		S("Deepslate Tile Wall"), },
}
for _, c in ipairs(cut) do
	node(c[1], {
		description = c[2],
		tiles = { tex(c[1]), },
		groups = { cracky = 2, stone = 1, },
		sounds = stone,
	}, { stairs = { c[3], c[4], }, wall = c[5], })
end

for _, c in ipairs({
	{ "cracked_deepslate_bricks", S("Cracked Deepslate Bricks"), },
	{ "cracked_deepslate_tiles", S("Cracked Deepslate Tiles"), },
	{ "chiseled_deepslate", S("Chiseled Deepslate"), },
}) do
	node(c[1], {
		description = c[2],
		tiles = { tex(c[1]), },
		groups = { cracky = 2, stone = 1, },
		sounds = stone,
	})
end

-- Like the pockets' barrier: not diggable, blast-proof, never moved.
node("reinforced_deepslate", {
	description = S("Reinforced Deepslate"),
	tiles = { tex("reinforced_deepslate_top"), tex("reinforced_deepslate_bottom"), tex("reinforced_deepslate"), },
	diggable = false,
	drop = "",
	groups = { unbreakable = 1, immortal = 1, },
	sounds = stone,
	on_blast = function()
	end,
})

local function square(output, input)
	core.register_craft({ output = "cb_blocks:" .. output .. " 4",
		recipe = { { "cb_blocks:" .. input, "cb_blocks:" .. input, }, { "cb_blocks:" .. input, "cb_blocks:" .. input, }, }, })
end
square("polished_deepslate", "cobbled_deepslate")
square("deepslate_bricks", "polished_deepslate")
square("deepslate_tiles", "deepslate_bricks")
local SLAB = "stairs:slab_cb_cobbled_deepslate"
core.register_craft({ output = "cb_blocks:chiseled_deepslate", recipe = { { SLAB, }, { SLAB, }, }, })
for output, input in pairs({ deepslate = "cobbled_deepslate", cracked_deepslate_bricks = "deepslate_bricks",
	cracked_deepslate_tiles = "deepslate_tiles", }) do
	core.register_craft({ type = "cooking", output = "cb_blocks:" .. output, recipe = "cb_blocks:" .. input, })
end
