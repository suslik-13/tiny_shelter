-- Ancient city decor (plan 8e): lit candles, one to four in a block (no
-- craft: there is no beeswax on these servers), and the skeleton skull on
-- the floor or on a wall. Models and textures from Mineclonia.
local S = cb_blocks.S
local node, tex = cb_blocks.node, cb_blocks.tex

local CANDLE_BOXES = {
	{ -0.0625, -0.5, -0.0625, 0.0625, -0.125, 0.0625, },
	{ -0.1875, -0.5, -0.0625, 0.1875, -0.125, 0.125, },
	{ -0.1875, -0.5, -0.1875, 0.125, -0.125, 0.125, },
	{ -0.1875, -0.5, -0.125, 0.1875, -0.125, 0.1875, },
}

-- A candle set on a candle block adds one to it, up to four.
local function place_candle(itemstack, placer, pointed)
	if pointed.type ~= "node" then
		return itemstack
	end
	local under = core.get_node(pointed.under)
	local n = core.get_item_group(under.name, "cb_candles")
	local pname = placer and placer:is_player() and placer:get_player_name() or ""
	if n == 0 or (placer and placer:is_player() and placer:get_player_control().sneak) then
		return core.item_place(itemstack, placer, pointed)
	end
	if n < 4 and not core.is_protected(pointed.under, pname) then
		core.swap_node(pointed.under, { name = "cb_blocks:candle_" .. (n + 1), param2 = under.param2, })
		if not core.is_creative_enabled(pname) then
			itemstack:take_item()
		end
	end
	return itemstack
end

for i = 1, 4 do
	local box = { type = "fixed", fixed = CANDLE_BOXES[i], }
	node("candle_" .. i, {
		description = S("Candle"),
		drawtype = "mesh",
		mesh = "cb_blocks_candle_" .. i .. ".obj",
		tiles = { tex("candle"), { name = tex("candle_flames"), animation = { type = "vertical_frames",
			aspect_w = 16, aspect_h = 16, length = 1, }, }, },
		inventory_image = tex("candle_inv"),
		wield_image = tex("candle_inv"),
		use_texture_alpha = "clip",
		paramtype = "light",
		sunlight_propagates = true,
		walkable = false,
		light_source = 3 * i,
		selection_box = box,
		collision_box = box,
		drop = "cb_blocks:candle_1 " .. i,
		groups = { dig_immediate = 3, attached_node = 1, cb_candles = i, not_in_creative_inventory = i > 1 and 1 or nil, },
		sounds = default.node_sound_defaults(),
		node_placement_prediction = "",
		on_place = place_candle,
	})
end

-- Skeleton skull: the head mesh on the floor, a box with the skin's faces
-- on a wall (as the wither skeleton skull).
local HEAD = tex("skeleton_head")
local BOX = { type = "fixed", fixed = { -0.25, -0.5, -0.25, 0.25, 0, 0.25, }, }
local SKULL, WALL = "cb_blocks:skeleton_skull", "cb_blocks:skeleton_skull_wall"
local base = {
	description = S("Skeleton Skull"),
	inventory_image = tex("skeleton_skull"),
	wield_image = tex("skeleton_skull"),
	paramtype = "light",
	sunlight_propagates = true,
	groups = { oddly_breakable_by_hand = 2, },
	sounds = default.node_sound_stone_defaults(),
}

local floor = table.copy(base)
floor.drawtype, floor.mesh, floor.tiles = "mesh", "cb_blocks_head_floor.obj", { HEAD, }
floor.paramtype2 = "facedir"
floor.selection_box, floor.collision_box = BOX, BOX
floor.on_place = function(itemstack, placer, pointed)
	if pointed.type == "node" and pointed.under.y == pointed.above.y then
		local p2 = core.dir_to_wallmounted(vector.subtract(pointed.under, pointed.above))
		local left = core.item_place_node(ItemStack(WALL), placer, pointed, p2)
		if left:is_empty() and not core.is_creative_enabled(placer and placer:get_player_name() or "") then
			itemstack:take_item()
		end
		return itemstack
	end
	return core.item_place(itemstack, placer, pointed)
end
node("skeleton_skull", floor)

local wall = table.copy(base)
wall.drawtype, wall.paramtype2 = "nodebox", "wallmounted"
wall.node_box = { type = "wallmounted", wall_bottom = { -0.25, -0.5, -0.25, 0.25, 0, 0.25, },
	wall_top = { -0.25, 0, -0.25, 0.25, 0.5, 0.25, }, wall_side = { -0.5, -0.25, -0.25, 0, 0.25, 0.25, }, }
wall.tiles = {
	{ name = "[combine:16x16:-4,-4=" .. HEAD, align_style = "world", },
	{ name = "[combine:16x16:-20,-4=" .. HEAD, align_style = "world", },
	{ name = "[combine:16x16:-8,-4=" .. HEAD, align_style = "world", },
	{ name = "[combine:16x16:0,-4=" .. HEAD, align_style = "world", },
	{ name = "([combine:16x16:-4,0=" .. HEAD .. ")^[transformR180", align_style = "node", },
	{ name = "([combine:16x16:-12,0=" .. HEAD .. ")^[transformR180", align_style = "node", },
}
wall.drop = SKULL
wall.groups = { oddly_breakable_by_hand = 2, not_in_creative_inventory = 1, }
node("skeleton_skull_wall", wall)
