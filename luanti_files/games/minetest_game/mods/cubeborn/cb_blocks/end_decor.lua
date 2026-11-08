-- End city decoration: purple stained glass and the dragon head (floor and
-- wall), textures and meshes from Mineclonia.
local S = cb_blocks.S
local node, tex = cb_blocks.node, cb_blocks.tex

node("glass_purple", {
	description = S("Purple Stained Glass"),
	drawtype = "glasslike",
	tiles = { tex("glass_purple"), },
	use_texture_alpha = "blend",
	paramtype = "light",
	sunlight_propagates = true,
	groups = { cracky = 3, oddly_breakable_by_hand = 3, },
	sounds = default.node_sound_glass_defaults(),
})

local HEAD_BOX = { type = "fixed", fixed = { -0.25, -0.5, -0.25, 0.25, 0, 0.25, }, }

node("dragon_head", {
	description = S("Dragon Head"),
	drawtype = "mesh",
	mesh = "cb_blocks_dragon_head_floor.obj",
	tiles = { tex("dragon_head"), },
	paramtype = "light",
	paramtype2 = "facedir",
	selection_box = HEAD_BOX,
	collision_box = HEAD_BOX,
	groups = { oddly_breakable_by_hand = 2, },
	sounds = default.node_sound_stone_defaults(),
	on_place = function(itemstack, placer, pointed)
		if pointed.type == "node" and pointed.under.y == pointed.above.y then
			local p2 = core.dir_to_wallmounted(vector.subtract(pointed.under, pointed.above))
			local stack = ItemStack("cb_blocks:dragon_head_wall")
			local left = core.item_place_node(stack, placer, pointed, p2)
			if left:is_empty() and not core.is_creative_enabled(placer and placer:get_player_name() or "") then
				itemstack:take_item()
			end
			return itemstack
		end
		return core.item_place(itemstack, placer, pointed)
	end,
})

node("dragon_head_wall", {
	description = S("Dragon Head"),
	drawtype = "mesh",
	mesh = "cb_blocks_dragon_head_wall.obj",
	tiles = { tex("dragon_head"), },
	paramtype = "light",
	paramtype2 = "wallmounted",
	selection_box = { type = "wallmounted", },
	drop = "cb_blocks:dragon_head",
	groups = { oddly_breakable_by_hand = 2, not_in_creative_inventory = 1, },
	sounds = default.node_sound_stone_defaults(),
})
