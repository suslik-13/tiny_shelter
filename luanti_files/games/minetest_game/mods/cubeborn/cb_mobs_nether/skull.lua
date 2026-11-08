-- Wither skeleton skull (spec cycle 4, 8d): a block on the floor or on a
-- wall (head mesh and texture from Mineclonia). Four soul sand or soul soil
-- blocks in a T with three skulls on its arms summon the wither, in either
-- orientation and in any dimension, unless the server is peaceful or a
-- block of the T is protected from the player who set the last skull.
local S = cb_mobs_nether.S
local N = cb_mobs_nether
local WALL = N.WITHER_SKULL .. "_wall"
local TEX = "cb_mobs_nether_wither_skeleton_head.png"
local BOX = { type = "fixed", fixed = { -0.25, -0.5, -0.25, 0.25, 0, 0.25, }, }

local SOUL, SKULL = {}, { [N.WITHER_SKULL] = true, [WALL] = true, }
core.register_on_mods_loaded(function()
	for _, name in ipairs({ "cb_blocks:soul_sand", "cb_blocks:soul_soil", "nether:soul_sand", }) do
		SOUL[name] = core.registered_nodes[name] ~= nil or nil
	end
end)

local function name_at(p)
	return core.get_node(p).name
end

-- The T whose skull row holds pos: its middle skull and its 7 blocks.
function N.find_summon(pos)
	for _, ax in ipairs({ "x", "z", }) do
		for i = -1, 1 do
			local mid = vector.copy(pos)
			mid[ax] = mid[ax] + i
			local nodes, ok = {}, true
			for k = -1, 1 do
				local s = vector.copy(mid)
				s[ax] = s[ax] + k
				local b = vector.offset(s, 0, -1, 0)
				if not SKULL[name_at(s)] or not SOUL[name_at(b)] then
					ok = false
					break
				end
				nodes[#nodes + 1], nodes[#nodes + 2] = s, b
			end
			local stem = vector.offset(mid, 0, -2, 0)
			if ok and SOUL[name_at(stem)] then
				for k = -1, 1, 2 do
					local c = vector.copy(stem)
					c[ax] = c[ax] + k
					ok = ok and name_at(c) == "air"
				end
				if ok then
					nodes[#nodes + 1] = stem
					return mid, nodes
				end
			end
		end
	end
	return nil
end

-- Called after a skull is set at pos by player `name` ("" for none).
function N.try_summon(pos, name)
	name = name or ""
	if core.settings:get_bool("only_peaceful_mobs", false) or not N.spawn_wither then
		return nil
	end
	local mid, nodes = N.find_summon(pos)
	if not mid then
		return nil
	end
	for _, p in ipairs(nodes) do
		if core.is_protected(p, name) then
			return nil
		end
	end
	for _, p in ipairs(nodes) do
		core.remove_node(p)
	end
	return N.spawn_wither(vector.offset(mid, 0, -2, 0), name)
end

local function after_place(pos, placer)
	N.try_summon(pos, placer and placer:is_player() and placer:get_player_name() or "")
end

local base = {
	description = S("Wither Skeleton Skull"),
	inventory_image = "cb_mobs_nether_wither_skeleton_skull.png",
	wield_image = "cb_mobs_nether_wither_skeleton_skull.png",
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	groups = { oddly_breakable_by_hand = 2, },
	sounds = default.node_sound_stone_defaults(),
	after_place_node = after_place,
}

local floor = table.copy(base)
floor.drawtype, floor.mesh, floor.tiles = "mesh", "cb_mobs_nether_head_floor.obj", { TEX, }
floor.paramtype2 = "facedir"
floor.selection_box, floor.collision_box = BOX, BOX
-- Set against a wall it becomes the wall skull.
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
core.register_node(N.WITHER_SKULL, floor)

-- Wall skull: a box with the head's faces cut out of the skin (Mineclonia's way).
local wall = table.copy(base)
wall.drawtype, wall.paramtype2 = "nodebox", "wallmounted"
wall.node_box = { type = "wallmounted", wall_bottom = { -0.25, -0.5, -0.25, 0.25, 0, 0.25, },
	wall_top = { -0.25, 0, -0.25, 0.25, 0.5, 0.25, }, wall_side = { -0.5, -0.25, -0.25, 0, 0.25, 0.25, }, }
wall.tiles = {
	{ name = "[combine:16x16:-4,-4=" .. TEX, align_style = "world", },
	{ name = "[combine:16x16:-20,-4=" .. TEX, align_style = "world", },
	{ name = "[combine:16x16:-8,-4=" .. TEX, align_style = "world", },
	{ name = "[combine:16x16:0,-4=" .. TEX, align_style = "world", },
	{ name = "([combine:16x16:-4,0=" .. TEX .. ")^[transformR180", align_style = "node", },
	{ name = "([combine:16x16:-12,0=" .. TEX .. ")^[transformR180", align_style = "node", },
}
wall.drop = N.WITHER_SKULL
wall.groups = { oddly_breakable_by_hand = 2, not_in_creative_inventory = 1, }
core.register_node(WALL, wall)
