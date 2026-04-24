local liquid_sound = default.node_sound_water_defaults()

local dye_colours = {
	white="#ffffff",
	grey= "#999999",
	dark_grey="#505050",
	black="#000000",
	violet="purple#",
	blue= "blue#",
	cyan= "cyan#",
	dark_green="green#",
	green="lime#",
	yellow="yellow#",
	brown="chocolate#",
	orange="orange#",
	red=  "red#",
	magenta="magenta#",
	pink= "pink#",
}

for _, row in ipairs(dye.dyes) do
	local name = row[1]
	local description = row[2]
	local groups = {}
	groups["color_" .. name] = 1



	minetest.register_craft({
		output = "dye:" .. name .. " 4",
		recipe = {
			{"group:flower,color_" .. name}
		},
	})
	--dyed wootah

	minetest.register_node("dyed_water:"..name.."_water", {
		description = description.." Water",
		drawtype = "liquid",
		waving = 3,
		tiles = {
			{
				name = "dyed_water_white_source_animated.png^[multiply:"..dye_colours[name],
				backface_culling = false,
				animation = {
					type = "vertical_frames",
					aspect_w = 16,
					aspect_h = 16,
					length = 2.0,
				},
			},
			{
				name = "dyed_water_white_source_animated.png^[multiply:"..dye_colours[name],
				backface_culling = true,
				animation = {
					type = "vertical_frames",
					aspect_w = 16,
					aspect_h = 16,
					length = 2.0,
				},
			},
		},
		use_texture_alpha = "blend",
		paramtype = "light",
		walkable = false,
		pointable = false,
		diggable = false,
		buildable_to = true,
		is_ground_content = false,
		drop = "",
		drowning = 1,
		liquidtype = "source",
		liquid_alternative_flowing = "dyed_water:"..name.."_water_flowing",
		liquid_alternative_source = "dyed_water:"..name.."_water",
		liquid_viscosity = 1,
		post_effect_color = dye_colours[name].."40",
		groups = {water = 3, liquid = 3, cools_lava = 1},
		sounds = liquid_sound,
	})

	minetest.register_node("dyed_water:"..name.."_water_flowing", {
		description = "AAa",
		drawtype = "flowingliquid",
		waving = 3,
		tiles = {"dyed_water_white.png^[colorize:"..dye_colours[name]..":128"},
		special_tiles = {
			{
				name = "dyed_water_white_flowing_animated.png^[multiply:"..dye_colours[name],
				backface_culling = false,
				animation = {
					type = "vertical_frames",
					aspect_w = 16,
					aspect_h = 16,
					length = 0.5,
				},
			},
			{
				name = "dyed_water_white_flowing_animated.png^[multiply:"..dye_colours[name],
				backface_culling = true,
				animation = {
					type = "vertical_frames",
					aspect_w = 16,
					aspect_h = 16,
					length = 0.5,
				},
			},
		},
		use_texture_alpha = "blend",
		paramtype = "light",
		paramtype2 = "flowingliquid",
		walkable = false,
		pointable = false,
		diggable = false,
		buildable_to = true,
		is_ground_content = false,
		drop = "",
		drowning = 1,
		liquidtype = "flowing",
		liquid_alternative_flowing = "dyed_water:"..name.."_water_flowing",
		liquid_alternative_source = "dyed_water:"..name.."_water",
		liquid_viscosity = 1,
		post_effect_color = dye_colours[name].."40",
		groups = {water = 3, liquid = 3, not_in_creative_inventory = 1,
			cools_lava = 1},
		sounds = liquid_sound,
	})
	-- make the bucket
	local bucket_id = "dyed_water:"..name.."_bucket"
	bucket.register_liquid(
		"dyed_water:"..name.."_water",
		"dyed_water:"..name.."_water_flowing",
		bucket_id,
		"dyed_water_bucket.png^[multiply:"..dye_colours[name].."^dyed_water_bucket_overlay.png",
		description.." Water Bucket"--, groups, force_renew
	)
	--make the crafting for the bucket bucket:bucket_river_water
	minetest.register_craft({
		type = "shapeless",
		output = bucket_id.." 1",
		recipe = {"bucket:bucket_water",
			"dye:"..name
		}
	})
	minetest.register_craft({
		type = "shapeless",
		output = bucket_id.." 1",
		recipe = {"bucket:bucket_river_water",
			"dye:"..name
		}
	})
end
