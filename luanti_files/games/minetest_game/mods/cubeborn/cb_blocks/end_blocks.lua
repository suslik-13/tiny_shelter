-- End blocks: end stone and bricks, purpur, end rod, the End's bedrock, the
-- End portal frame, the dragon egg and chorus (plant, flower, fruit).
local S = cb_blocks.S
local node, item, tex = cb_blocks.node, cb_blocks.item, cb_blocks.tex
local stone = default.node_sound_stone_defaults()

-- The node a player's feet are in: vector.round rounds .5 away from zero,
-- which picks the node below at negative y.
function cb_blocks.node_at(pos)
	return vector.new(math.floor(pos.x + 0.5), math.floor(pos.y + 0.5), math.floor(pos.z + 0.5))
end

local function solid(pos)
	local def = core.registered_nodes[core.get_node(pos).name]
	return def ~= nil and def.walkable ~= false and (def.liquidtype or "none") == "none"
end

node("end_stone", {
	description = S("End Stone"),
	tiles = { tex("end_stone"), },
	groups = { cracky = 2, },
	sounds = stone,
}, { natural = true, })
local es = "cb_blocks:end_stone"

node("end_stone_bricks", {
	description = S("End Stone Bricks"),
	tiles = { tex("end_stone_bricks"), },
	groups = { cracky = 2, stone = 1, },
	sounds = stone,
}, { stairs = { S("End Stone Brick Stairs"), S("End Stone Brick Slab"), }, wall = S("End Stone Brick Wall"), })
core.register_craft({ output = "cb_blocks:end_stone_bricks 4", recipe = { { es, es, }, { es, es, }, }, })

node("purpur_block", {
	description = S("Purpur Block"),
	tiles = { tex("purpur_block"), },
	groups = { cracky = 2, stone = 1, },
	sounds = stone,
}, { stairs = { S("Purpur Stairs"), S("Purpur Slab"), }, })

node("purpur_pillar", {
	description = S("Purpur Pillar"),
	tiles = { tex("purpur_pillar_top"), tex("purpur_pillar_top"), tex("purpur_pillar_side"), },
	paramtype2 = "facedir",
	on_place = core.rotate_node,
	groups = { cracky = 2, stone = 1, },
	sounds = stone,
})
local ps = "stairs:slab_cb_purpur_block"
core.register_craft({ output = "cb_blocks:purpur_pillar", recipe = { { ps, }, { ps, }, }, })

node("end_rod", {
	description = S("End Rod"),
	drawtype = "nodebox",
	tiles = { tex("end_rod_top"), tex("end_rod_bottom"), tex("end_rod_side"), },
	node_box = {
		type = "fixed",
		fixed = { { -1 / 16, -0.5, -1 / 16, 1 / 16, 0.5, 1 / 16, }, { -2 / 16, -0.5, -2 / 16, 2 / 16, -7 / 16, 2 / 16, }, },
	},
	paramtype = "light",
	paramtype2 = "facedir",
	on_place = core.rotate_node,
	sunlight_propagates = true,
	light_source = core.LIGHT_MAX,
	groups = { cracky = 3, oddly_breakable_by_hand = 3, },
	sounds = default.node_sound_glass_defaults(),
})

node("end_bedrock", {
	description = S("Bedrock"),
	tiles = { tex("end_bedrock"), },
	diggable = false,
	drop = "",
	groups = { unbreakable = 1, immortal = 1, not_in_creative_inventory = 1, },
	sounds = stone,
	on_blast = function()
	end,
}, { natural = true, })

local function frame(name, desc, top, box)
	node(name, {
		description = desc,
		drawtype = "nodebox",
		tiles = { tex(top), tex("end_portal_frame_bottom"), tex("end_portal_frame_side"), },
		node_box = { type = "fixed", fixed = box, },
		paramtype = "light",
		paramtype2 = "facedir",
		diggable = false,
		drop = "",
		groups = { unbreakable = 1, end_portal_frame = 1, not_in_creative_inventory = 1, },
		sounds = stone,
		on_blast = function()
		end,
	})
end
frame("end_portal_frame", S("End Portal Frame") .. "\n" .. core.colorize("#a8a8a8",
	S("Found only in the portal room of a stronghold; cannot be crafted or broken.")), "end_portal_frame_top", { -0.5, -0.5, -0.5, 0.5, 5 / 16, 0.5, })
frame("end_portal_frame_eye", S("End Portal Frame with Eye of Ender"), "end_portal_frame_eye",
	{ { -0.5, -0.5, -0.5, 0.5, 5 / 16, 0.5, }, { -4 / 16, 5 / 16, -4 / 16, 4 / 16, 0.5, 4 / 16, }, })

-- A punched dragon egg jumps to a free spot within 15 nodes: a random column,
-- then the highest resting place in it within 7 nodes up or down.
function cb_blocks.dragon_egg_teleport(pos)
	for _ = 1, 32 do
		local dx, dz = math.random(-15, 15), math.random(-15, 15)
		for dy = 7, -7, -1 do
			local p = vector.offset(pos, dx, dy, dz)
			if (dx ~= 0 or dz ~= 0 or dy ~= 0) and core.get_node(p).name == "air"
					and solid(vector.offset(p, 0, -1, 0)) and not core.is_protected(p, "") then
				core.remove_node(pos)
				core.set_node(p, { name = "cb_blocks:dragon_egg", })
				return p
			end
		end
	end
end

node("dragon_egg", {
	description = S("Dragon Egg"),
	drawtype = "nodebox",
	tiles = { tex("dragon_egg"), },
	node_box = {
		type = "fixed",
		fixed = {
			{ -6 / 16, -0.5, -6 / 16, 6 / 16, 1 / 16, 6 / 16, },
			{ -5 / 16, 1 / 16, -5 / 16, 5 / 16, 4 / 16, 5 / 16, },
			{ -3 / 16, 4 / 16, -3 / 16, 3 / 16, 7 / 16, 3 / 16, },
		},
	},
	paramtype = "light",
	light_source = 1,
	groups = { falling_node = 1, not_in_creative_inventory = 1, },
	sounds = stone,
	on_punch = function(pos, _, puncher)
		local name = puncher and puncher:get_player_name() or ""
		if name ~= "" and core.is_protected(pos, name) then
			core.record_protection_violation(pos, name)
			return
		end
		cb_blocks.dragon_egg_teleport(pos)
	end,
	on_blast = function()
	end,
})

node("chorus_plant", {
	description = S("Chorus Plant"),
	drawtype = "nodebox",
	tiles = { tex("chorus_plant"), },
	node_box = {
		type = "connected",
		fixed = { -0.25, -0.25, -0.25, 0.25, 0.25, 0.25, },
		connect_top = { -0.25, 0.25, -0.25, 0.25, 0.5, 0.25, },
		connect_bottom = { -0.25, -0.5, -0.25, 0.25, -0.25, 0.25, },
		connect_front = { -0.25, -0.25, -0.5, 0.25, 0.25, -0.25, },
		connect_back = { -0.25, -0.25, 0.25, 0.25, 0.25, 0.5, },
		connect_left = { -0.5, -0.25, -0.25, -0.25, 0.25, 0.25, },
		connect_right = { 0.25, -0.25, -0.25, 0.5, 0.25, 0.25, },
	},
	connects_to = { "cb_blocks:chorus_plant", "cb_blocks:chorus_flower", "cb_blocks:end_stone", },
	paramtype = "light",
	groups = { choppy = 3, oddly_breakable_by_hand = 3, },
	sounds = default.node_sound_wood_defaults(),
	drop = { max_items = 1, items = { { items = { "cb_blocks:chorus_fruit", }, rarity = 2, }, }, },
}, { natural = true, })

node("chorus_flower", {
	description = S("Chorus Flower"),
	tiles = { tex("chorus_flower"), },
	groups = { choppy = 3, oddly_breakable_by_hand = 3, },
	sounds = default.node_sound_wood_defaults(),
}, { natural = true, })

-- Rules other mods add for teleports through walls (cb_dimensions: never
-- across a pocket shell); each is function(name, from, to) -> bool.
cb_blocks.teleport_rules = {}

function cb_blocks.teleport_allowed(name, from, to)
	if core.is_protected(to, name) then
		return false
	end
	for _, rule in ipairs(cb_blocks.teleport_rules) do
		if not rule(name, from, to) then
			return false
		end
	end
	return true
end

-- Eating a chorus fruit moves the player to a random safe spot up to 8 nodes
-- away on each axis: a random column, then the highest standing place in it.
function cb_blocks.chorus_teleport(player)
	local pos = cb_blocks.node_at(player:get_pos())
	local name = player.get_player_name and player:get_player_name() or ""
	for _ = 1, 16 do
		local dx, dz = math.random(-8, 8), math.random(-8, 8)
		for dy = 8, -8, -1 do
			local p = vector.offset(pos, dx, dy, dz)
			if core.get_node(p).name == "air" and core.get_node(vector.offset(p, 0, 1, 0)).name == "air"
					and solid(vector.offset(p, 0, -1, 0)) and cb_blocks.teleport_allowed(name, pos, p) then
				player:set_pos(vector.offset(p, 0, -0.5, 0))
				return p
			end
		end
	end
end

item("chorus_fruit", {
	description = S("Chorus Fruit"),
	inventory_image = tex("chorus_fruit"),
	on_use = function(itemstack, user, pointed)
		local rest = core.item_eat(4)(itemstack, user, pointed)
		if user and user:is_player() then
			cb_blocks.chorus_teleport(user)
		end
		return rest
	end,
})
item("popped_chorus_fruit", { description = S("Popped Chorus Fruit"), inventory_image = tex("popped_chorus_fruit"), })
core.register_craft({ type = "cooking", output = "cb_blocks:popped_chorus_fruit", recipe = "cb_blocks:chorus_fruit", })
local pc = "cb_blocks:popped_chorus_fruit"
core.register_craft({ output = "cb_blocks:purpur_block 4", recipe = { { pc, pc, }, { pc, pc, }, }, })
