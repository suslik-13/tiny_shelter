-- Emerald and netherite blocks (beacon bases); 9 <-> 1 like the other
-- mineral blocks. Named in cb_blocks, where the other Cubeborn blocks are.
local S = cb_beacon.S

local function block(name, desc, item, extra)
	local node = "cb_blocks:" .. name .. "_block"
	core.register_node(":" .. node, {
		description = desc,
		tiles = { "cb_beacon_" .. name .. "_block.png", },
		is_ground_content = false,
		groups = extra or { cracky = 1, level = 2, },
		sounds = default.node_sound_metal_defaults(),
	})
	core.register_craft({ output = node, recipe = { { item, item, item, }, { item, item, item, }, { item, item, item, }, }, })
	core.register_craft({ type = "shapeless", output = item .. " 9", recipe = { node, }, })
	return node
end

cb_beacon.EMERALD_BLOCK = block("emerald", S("Block of Emerald"), "cb_items:emerald")
cb_beacon.NETHERITE_BLOCK = block("netherite", S("Block of Netherite"), "cb_blocks:netherite_ingot",
	{ cracky = 1, level = 3, })
