-- Cracked and mossy stone bricks (strongholds); textures are made from
-- minetest_game's own stone brick and mossy cobble by tools/make_brick_textures.py.
local S = cb_blocks.S
local node, tex = cb_blocks.node, cb_blocks.tex
local stone = default.node_sound_stone_defaults()

cb_core.register_equiv("cracked_stone_bricks", { "cb_blocks:cracked_stone_bricks", })
cb_core.register_equiv("mossy_stone_bricks", { "cb_blocks:mossy_stone_bricks", })

node("cracked_stone_bricks", {
	description = S("Cracked Stone Bricks"),
	tiles = { tex("cracked_stone_bricks"), },
	groups = { cracky = 2, stone = 1, },
	sounds = stone,
}, { equiv = "cracked_stone_bricks", })

node("mossy_stone_bricks", {
	description = S("Mossy Stone Bricks"),
	tiles = { tex("mossy_stone_bricks"), },
	groups = { cracky = 2, stone = 1, },
	sounds = stone,
}, { equiv = "mossy_stone_bricks", stairs = { S("Mossy Stone Brick Stairs"), S("Mossy Stone Brick Slab"), },
	wall = S("Mossy Stone Brick Wall"), })

core.register_craft({ type = "cooking", output = "cb_blocks:cracked_stone_bricks", recipe = "default:stonebrick", })
