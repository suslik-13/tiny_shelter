-- Nodes used by the generated spawn.
local MN = "the_tiny_spawn"
local S = minetest.get_translator(MN)
local sounds_stone = default.node_sound_stone_defaults()
local sounds_glass = default.node_sound_glass_defaults()
local sounds_metal = default.node_sound_metal_defaults and default.node_sound_metal_defaults() or sounds_stone

local function tex(n) return MN .. "_" .. n .. ".png" end

local function anim_tile(name, frames, length)
	return {
		name = tex(name),
		backface_culling = false,
		animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = length or 1.6},
	}
end

-- solid building blocks ----------------------------------------------------
local solids = {
	plate       = {S("Cyber Floor Plate"), "plate", 0},
	plate_light = {S("Cyber Floor Tile"), "plate_light", 0},
	road        = {S("Cyber Asphalt"), "road", 0},
	road_line   = {S("Cyber Asphalt (Neon Line)"), "road_line", 6},
	panel       = {S("Cyber Wall Panel"), "panel", 0},
	emitter     = {S("Beam Emitter"), "emitter", 14},
}
for name, d in pairs(solids) do
	minetest.register_node(MN .. ":" .. name, {
		description = d[1],
		tiles = {tex(d[2])},
		paramtype = d[3] > 0 and "light" or "none",
		light_source = d[3],
		is_ground_content = false,
		groups = {cracky = 2},
		sounds = sounds_metal,
	})
end

-- neon blocks --------------------------------------------------------------
for _, col in ipairs({"cyan", "magenta", "purple", "yellow"}) do
	minetest.register_node(MN .. ":neon_" .. col, {
		description = S("Neon Block (@1)", col),
		tiles = {tex("neon_" .. col)},
		paramtype = "light",
		light_source = 12,
		is_ground_content = false,
		groups = {cracky = 3},
		sounds = sounds_glass,
	})
end

minetest.register_node(MN .. ":glass_cyan", {
	description = S("Neon Glass"),
	drawtype = "glasslike",
	tiles = {tex("glass_cyan")},
	use_texture_alpha = "blend",
	paramtype = "light",
	sunlight_propagates = true,
	light_source = 7,
	is_ground_content = false,
	groups = {cracky = 3, oddly_breakable_by_hand = 3},
	sounds = sounds_glass,
})

-- light beam: translucent, no collision, no damage, cannot be dug ----------
local beam_common = {
	drawtype = "glasslike",
	use_texture_alpha = "blend",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = false,
	floodable = false,
	damage_per_second = 0,
	drop = "",
	is_ground_content = false,
	groups = {not_in_creative_inventory = 1, immortal = 1},
	on_blast = function() end,
}
local core_def = table.copy(beam_common)
core_def.description = S("Light Beam (core)")
core_def.tiles = {anim_tile("beam_core", 8, 1.2)}
core_def.light_source = 14
core_def.post_effect_color = {a = 60, r = 140, g = 240, b = 255}
minetest.register_node(MN .. ":beam_core", core_def)

local halo_def = table.copy(beam_common)
halo_def.description = S("Light Beam (halo)")
halo_def.tiles = {anim_tile("beam_halo", 8, 1.6)}
halo_def.light_source = 10
halo_def.post_effect_color = {a = 30, r = 60, g = 160, b = 255}
minetest.register_node(MN .. ":beam_halo", halo_def)

-- holograms ----------------------------------------------------------------
minetest.register_node(MN .. ":holo_pool", {
	description = S("Holo Pool"),
	drawtype = "nodebox",
	node_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, 0.25, 0.5}},
	tiles = {anim_tile("holo_pool", 8, 2.0)},
	use_texture_alpha = "blend",
	paramtype = "light",
	light_source = 11,
	is_ground_content = false,
	groups = {cracky = 3},
	sounds = sounds_glass,
})

minetest.register_node(MN .. ":holo_column", {
	description = S("Holo Column"),
	drawtype = "glasslike",
	tiles = {anim_tile("holo_column", 8, 1.0)},
	use_texture_alpha = "blend",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	light_source = 11,
	is_ground_content = false,
	groups = {cracky = 3},
	sounds = sounds_glass,
})

minetest.register_node(MN .. ":holo_screen", {
	description = S("Holo Screen"),
	tiles = {anim_tile("holo_screen", 8, 1.6)},
	paramtype = "light",
	light_source = 9,
	is_ground_content = false,
	groups = {cracky = 3},
	sounds = sounds_glass,
})

minetest.register_node(MN .. ":beacon_red", {
	description = S("Antenna Beacon"),
	tiles = {anim_tile("beacon_red", 4, 1.2)},
	paramtype = "light",
	light_source = 10,
	is_ground_content = false,
	groups = {cracky = 3},
	sounds = sounds_glass,
})

minetest.register_node(MN .. ":light_pillar", {
	description = S("Neon Light Pillar"),
	drawtype = "nodebox",
	node_box = {type = "fixed", fixed = {-3/16, -0.5, -3/16, 3/16, 0.5, 3/16}},
	tiles = {tex("neon_cyan")},
	paramtype = "light",
	sunlight_propagates = true,
	light_source = 12,
	is_ground_content = false,
	groups = {cracky = 3},
	sounds = sounds_glass,
})

-- neon tree ----------------------------------------------------------------
minetest.register_node(MN .. ":neon_trunk", {
	description = S("Neon Tree Trunk"),
	tiles = {tex("neon_trunk_top"), tex("neon_trunk_top"), tex("neon_trunk")},
	paramtype = "light",
	light_source = 4,
	is_ground_content = false,
	groups = {choppy = 2, oddly_breakable_by_hand = 1, tree = 1},
	sounds = default.node_sound_wood_defaults(),
})

minetest.register_node(MN .. ":neon_leaves", {
	description = S("Neon Leaves"),
	drawtype = "allfaces_optional",
	waving = 1,
	tiles = {tex("neon_leaves")},
	use_texture_alpha = "clip",
	paramtype = "light",
	light_source = 7,
	is_ground_content = false,
	groups = {snappy = 3, leaves = 1},
	sounds = default.node_sound_leaves_defaults(),
})

-- lamp post ------------------------------------------------------------------
minetest.register_node(MN .. ":lamp_pole", {
	description = S("Cyber Lamp Pole"),
	drawtype = "nodebox",
	node_box = {type = "fixed", fixed = {-2/16, -0.5, -2/16, 2/16, 0.5, 2/16}},
	tiles = {tex("lamp_pole")},
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	groups = {cracky = 2},
	sounds = sounds_metal,
})

minetest.register_node(MN .. ":lamp_head", {
	description = S("Cyber Lamp"),
	drawtype = "nodebox",
	node_box = {type = "fixed", fixed = {
		{-4/16, -0.5, -4/16, 4/16, 3/16, 4/16},
		{-6/16, 3/16, -6/16, 6/16, 5/16, 6/16},
	}},
	tiles = {tex("lamp_head")},
	paramtype = "light",
	sunlight_propagates = true,
	light_source = 14,
	is_ground_content = false,
	groups = {cracky = 3},
	sounds = sounds_glass,
})

-- solarpunk additions ---------------------------------------------------------
minetest.register_node(MN .. ":solar_lantern", {
	description = S("Solar Lantern"),
	drawtype = "nodebox",
	node_box = {type = "fixed", fixed = {
		{-4/16, -0.5, -4/16, 4/16, 4/16, 4/16},
		{-5/16, 4/16, -5/16, 5/16, 6/16, 5/16},
		{-2/16, 6/16, -2/16, 2/16, 0.5, 2/16},
	}},
	tiles = {tex("solar_lantern")},
	paramtype = "light",
	sunlight_propagates = true,
	light_source = 13,
	is_ground_content = false,
	groups = {cracky = 3, oddly_breakable_by_hand = 2},
	sounds = sounds_glass,
})

minetest.register_node(MN .. ":solar_panel", {
	description = S("Solar Panel"),
	drawtype = "nodebox",
	node_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, -5/16, 0.5}},
	tiles = {tex("solar_panel"), tex("solar_side"), tex("solar_side")},
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	groups = {cracky = 2},
	sounds = sounds_metal,
})

minetest.register_node(MN .. ":glow_vine", {
	description = S("Glow Vine"),
	drawtype = "plantlike",
	tiles = {tex("glow_vine")},
	inventory_image = tex("glow_vine"),
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	climbable = true,
	light_source = 5,
	is_ground_content = false,
	selection_box = {type = "fixed", fixed = {-0.3, -0.5, -0.3, 0.3, 0.5, 0.3}},
	groups = {snappy = 3, flammable = 2},
	sounds = default.node_sound_leaves_defaults(),
})

for _, col in ipairs({"cyan", "magenta"}) do
	minetest.register_node(MN .. ":crystal_" .. col, {
		description = S("Glow Crystal (@1)", col),
		drawtype = "plantlike",
		visual_scale = 1.3,
		tiles = {tex("crystal_" .. col)},
		inventory_image = tex("crystal_" .. col),
		paramtype = "light",
		sunlight_propagates = true,
		walkable = false,
		light_source = 10,
		is_ground_content = false,
		selection_box = {type = "fixed", fixed = {-0.4, -0.5, -0.4, 0.4, 0.4, 0.4}},
		groups = {cracky = 3},
		sounds = sounds_glass,
	})
end

minetest.register_node(MN .. ":petals", {
	description = S("Sakura Petals"),
	drawtype = "nodebox",
	node_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, -7/16, 0.5}},
	tiles = {tex("petals")},
	use_texture_alpha = "clip",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	buildable_to = true,
	floodable = true,
	is_ground_content = false,
	groups = {snappy = 3, attached_node = 1},
	sounds = default.node_sound_leaves_defaults(),
})
