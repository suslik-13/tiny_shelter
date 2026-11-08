-- Fire in the Nether: netherrack burns forever (fire:permanent_flame from the
-- fire mod), soul sand and soul soil burn with soul fire. A flame goes out
-- when the block under it is removed.
local S = cb_blocks.S
local node, tex = cb_blocks.node, cb_blocks.tex

node("soul_fire", {
	description = S("Soul Fire"),
	drawtype = "firelike",
	tiles = { { name = tex("soul_fire_animated"), animation = { type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 1, }, }, },
	inventory_image = tex("soul_fire"),
	paramtype = "light",
	light_source = 10,
	walkable = false,
	buildable_to = true,
	sunlight_propagates = true,
	floodable = true,
	damage_per_second = 2,
	groups = { igniter = 2, dig_immediate = 3, not_in_creative_inventory = 1, },
	drop = "",
}, { natural = true, })

local function ignite_with(flame)
	return function(pos)
		local above = vector.offset(pos, 0, 1, 0)
		if core.get_node(above).name == "air" then
			core.set_node(above, { name = flame, })
		end
	end
end

local function remove_flame(flame)
	return function(pos)
		local above = vector.offset(pos, 0, 1, 0)
		if core.get_node(above).name == flame then
			core.remove_node(above)
		end
	end
end

if core.get_modpath("fire") and cb_blocks.registered["cb_blocks:netherrack"] then
	core.override_item("cb_blocks:netherrack", {
		on_ignite = ignite_with("fire:permanent_flame"),
		after_destruct = remove_flame("fire:permanent_flame"),
	})
	cb_core.register_natural("fire:permanent_flame", "pocket")
end

for _, name in ipairs({ "cb_blocks:soul_sand", "cb_blocks:soul_soil", }) do
	core.override_item(name, {
		on_ignite = ignite_with("cb_blocks:soul_fire"),
		after_destruct = remove_flame("cb_blocks:soul_fire"),
	})
end
