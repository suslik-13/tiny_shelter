-- Roles of the village schematics -> nodes of this server. A palette entry
-- (or a fixed one) lists candidates: the first registered node wins. Palette
-- keys override the plains defaults; "top", "path", "foundation" are service
-- keys for the ground around buildings.
local VP = {}
cb_structures.village_palettes = VP

local function job(name)
	return function()
		return cb_core.equiv("village_" .. name)
	end
end

local FIXED = {
	air = { "air", }, dirt = { "default:dirt", }, gravel = { "default:gravel", }, glass = { "default:glass", },
	glass_pane = { "xpanes:pane_flat", "default:glass", }, bars = { "xpanes:bar_flat", "default:fence_wood", },
	ladder = { "default:ladder_wood", }, water = { "default:water_source", }, lava = { "default:lava_source", },
	torch = { "default:torch", }, torch_wall = { "default:torch_wall", }, lantern = { "default:torch", },
	lantern_ceiling = { "default:torch_ceiling", "air", }, door_top = { "doors:hidden", },
	trapdoor = { "doors:trapdoor_open", "air", }, brick = { "default:brick", }, wall_brick = { "walls:cobble", },
	slab_brick_top = { "stairs:slab_brick", }, smooth_stone = { "default:stone_block", "default:stone", },
	stair_smooth = { "stairs:stair_stone_block", "stairs:stair_stone", },
	stair_smooth_outer = { "stairs:stair_outer_stone_block", "stairs:stair_stone_block", },
	slab_stone = { "stairs:slab_stone", }, slab_stone_top = { "stairs:slab_stone", },
	bed_bottom = { "beds:bed_bottom", }, bed_top = { "beds:bed_top", }, bell = { "cb_blocks:bell", },
	chest = { "default:chest", }, furnace = { "default:furnace", }, crafting_table = { "xdecor:workbench", "default:wood", },
	bookshelf = { "default:bookshelf", }, anvil = { "anvil:anvil", "air", },
	armor_stand = { "3d_armor_stand:armor_stand", "air", }, carpet = { "air", }, flower_pot = { "air", },
	item_frame = { "air", }, pressure_plate = { "air", }, farmland = { "farming:soil_wet", "default:dirt", },
	crop_grain = { "farming:wheat_8", "air", }, crop_root = { "farming:carrot_8", "farming:potato_4", "air", },
	crop_gourd = { "farming:pumpkin_8", "farming:melon_8", "air", },
	crop_flower = { "flowers:tulip", "flowers:dandelion_yellow", "air", }, waterlily = { "flowers:waterlily", "air", },
	sea_lantern = { "default:meselamp", }, clay = { "bakedclay:natural", "default:clay", },
	barrel = job("barrel"), blast_furnace = job("blast_furnace"), brewing_stand = job("brewing_stand"),
	cartography_table = job("cartography_table"), cauldron = job("cauldron"), composter = job("composter"),
	fletching_table = job("fletching_table"), grindstone = job("grindstone"), lectern = job("lectern"),
	loom = job("loom"), smithing_table = job("smithing_table"), smoker = job("smoker"),
	stonecutter = job("stonecutter"), path_endpoint = { "air", }, no_paths = { "air", },
	-- pillager outposts
	mossycobble = { "default:mossycobble", }, stone = { "default:stone", }, vine = { "ethereal:vine", "air", },
	deepslate = { "default:stonebrick", }, wall_deepslate = { "walls:cobble", },
	stair_deepslate = { "stairs:stair_stonebrick", }, hay = { "farming:straw", "default:wood", },
	pumpkin = { "farming:jackolantern", "farming:pumpkin", "default:wood", },
	fence_light = { "default:fence_aspen_wood", "default:fence_wood", },
	slab_light_top = { "stairs:slab_aspen_wood", "stairs:slab_wood", },
	stair_cobble_inner = { "stairs:stair_inner_cobble", "stairs:stair_cobble", },
	stair_mossycobble = { "stairs:stair_mossycobble", "stairs:stair_cobble", }, wool_white = { "wool:white", "air", },
}
-- Woodland mansions: dark oak and birch have no match on minetest_game.
local function equiv(key)
	return function()
		return cb_core.equiv(key)
	end
end
for role, list in pairs({
	dark_wood = { "default:junglewood", }, dark_log = { "default:jungletree", },
	dark_leaves = { "default:jungleleaves", }, dark_sapling = { "default:junglesapling", },
	dark_fence = { "default:fence_junglewood", }, dark_stair = { "stairs:stair_junglewood", },
	dark_stair_outer = { "stairs:stair_outer_junglewood", "stairs:stair_junglewood", },
	dark_slab = { "stairs:slab_junglewood", }, dark_slab_top = { "stairs:slab_junglewood", },
	light_wood = { "default:aspen_wood", }, light_slab = { "stairs:slab_aspen_wood", },
	light_stair = { "stairs:stair_aspen_wood", },
	light_stair_inner = { "stairs:stair_inner_aspen_wood", "stairs:stair_aspen_wood", },
	iron_door = { "doors:door_steel_a", }, pine_log = { "default:pine_tree", }, pine_stair = { "stairs:stair_pine_wood", },
	stair_stone = { "stairs:stair_stone", }, slab_stonebrick = { "stairs:slab_stonebrick", },
	slab_stonebrick_top = { "stairs:slab_stonebrick", }, melon = { "farming:melon_8", "air", },
	pumpkin_plain = { "farming:pumpkin_8", "farming:pumpkin", "air", }, cobweb = equiv("cobweb"),
	obsidian = { "default:obsidian", }, diamond_block = { "default:diamondblock", },
	emerald_block = { "default:goldblock", }, iron_block = { "default:steelblock", },
	quartz_block = { "cb_blocks:quartz_block", "default:stone_block", }, tnt = { "tnt:tnt", "air", },
	rail = { "carts:rail", "air", }, spider_spawner = { "cb_structures:spider_spawner", },
	mark_vindicator = { "air", }, mark_evoker = { "air", },
}) do
	FIXED[role] = list
end
-- Mineclonia colour -> minetest_game colour (wool, carpets, baked clay).
local COLOURS = { white = "white", silver = "grey", grey = "dark_grey", black = "black", red = "red",
	yellow = "yellow", green = "dark_green", lime = "green", cyan = "cyan", light_blue = "cyan", blue = "blue",
	orange = "orange", pink = "pink", purple = "violet", magenta = "magenta", brown = "brown", }
for mcl, mt in pairs(COLOURS) do
	FIXED["wool_" .. mcl] = { "wool:" .. mt, "air", }
	FIXED["carpet_" .. mcl] = { "cb_blocks:carpet_" .. mt, "air", }
	FIXED["clay_" .. mcl] = { "bakedclay:" .. mt, "wool:" .. mt, }
end
-- Roles placed upside down (top slabs).
local FORCED_P2 = { slab_wood_top = 20, slab_cobble_top = 20, slab_stone_top = 20, slab_brick_top = 20,
	slab_light_top = 20, dark_slab_top = 20, slab_stonebrick_top = 20, }
-- Roles that are another role of the same palette.
local SAME = { grass = "top", chain = "fence", slab_wood_top = "slab_wood", slab_cobble_top = "slab_cobble",
	stair_log = "stair_wood", stair_log_outer = "stair_wood_outer", }

local PLAINS = {
	wood = { "default:wood", }, log = { "default:tree", }, fence = { "default:fence_wood", },
	fence_gate = { "doors:gate_wood_closed", }, door_a = { "doors:door_wood_a", }, door_b = { "doors:door_wood_b", },
	stair_wood = { "stairs:stair_wood", }, stair_wood_inner = { "stairs:stair_inner_wood", "stairs:stair_wood", },
	stair_wood_outer = { "stairs:stair_outer_wood", "stairs:stair_wood", }, slab_wood = { "stairs:slab_wood", },
	cobble = { "default:cobble", }, stair_cobble = { "stairs:stair_cobble", },
	stair_cobble_outer = { "stairs:stair_outer_cobble", "stairs:stair_cobble", }, slab_cobble = { "stairs:slab_cobble", },
	wall_cobble = { "walls:cobble", }, stonebrick = { "default:stonebrick", },
	stonebrick_carved = { "default:stone_block", }, stair_stonebrick = { "stairs:stair_stonebrick", },
	stair_stonebrick_outer = { "stairs:stair_outer_stonebrick", "stairs:stair_stonebrick", },
	wall_stonebrick = { "walls:cobble", }, top = { "default:dirt_with_grass", }, path = { "default:gravel", },
	foundation = { "default:cobble", },
}

local function pine(top)
	return {
		wood = { "default:pine_wood", }, log = { "default:pine_tree", }, fence = { "default:fence_pine_wood", },
		fence_gate = { "doors:gate_pine_wood_closed", }, stair_wood = { "stairs:stair_pine_wood", },
		stair_wood_inner = { "stairs:stair_inner_pine_wood", "stairs:stair_pine_wood", },
		stair_wood_outer = { "stairs:stair_outer_pine_wood", "stairs:stair_pine_wood", },
		slab_wood = { "stairs:slab_pine_wood", }, top = top,
	}
end

local PALETTES = {
	plains = {},
	desert = {
		wood = { "default:sandstone_block", }, log = { "default:desert_sandstone_brick", },
		fence = { "default:fence_acacia_wood", }, fence_gate = { "doors:gate_acacia_wood_closed", },
		stair_wood = { "stairs:stair_sandstone_block", },
		stair_wood_inner = { "stairs:stair_inner_sandstone_block", "stairs:stair_sandstone_block", },
		stair_wood_outer = { "stairs:stair_outer_sandstone_block", "stairs:stair_sandstone_block", },
		slab_wood = { "stairs:slab_sandstone_block", }, cobble = { "default:sandstone", },
		stair_cobble = { "stairs:stair_sandstone", },
		stair_cobble_outer = { "stairs:stair_outer_sandstone", "stairs:stair_sandstone", },
		slab_cobble = { "stairs:slab_sandstone", }, wall_cobble = { "walls:desertcobble", },
		stonebrick = { "default:desert_sandstone_brick", }, stonebrick_carved = { "default:desert_sandstone_block", },
		stair_stonebrick = { "stairs:stair_desert_sandstone_brick", },
		stair_stonebrick_outer = { "stairs:stair_outer_desert_sandstone_brick", "stairs:stair_desert_sandstone_brick", },
		wall_stonebrick = { "walls:desertcobble", }, top = { "default:desert_sand", },
		path = { "default:desert_sandstone", }, foundation = { "default:sandstone", },
	},
	savanna = {
		wood = { "default:acacia_wood", }, log = { "default:acacia_tree", }, fence = { "default:fence_acacia_wood", },
		fence_gate = { "doors:gate_acacia_wood_closed", }, stair_wood = { "stairs:stair_acacia_wood", },
		stair_wood_inner = { "stairs:stair_inner_acacia_wood", "stairs:stair_acacia_wood", },
		stair_wood_outer = { "stairs:stair_outer_acacia_wood", "stairs:stair_acacia_wood", },
		slab_wood = { "stairs:slab_acacia_wood", },
		top = { "default:dry_dirt_with_dry_grass", "default:dirt_with_dry_grass", "default:dirt_with_grass", },
	},
	taiga = pine({ "default:dirt_with_coniferous_litter", "default:dirt_with_grass", }),
	snowy = pine({ "default:dirt_with_snow", "default:dirt_with_grass", }),
}
PALETTES.snowy.roof_snow = { "default:snow", }
-- Dark wood for pillager outposts (no dark oak on minetest_game: jungle wood).
PALETTES.outpost = {
	wood = { "default:junglewood", }, log = { "default:jungletree", }, fence = { "default:fence_junglewood", },
	fence_gate = { "doors:gate_junglewood_closed", "doors:gate_wood_closed", },
	stair_wood = { "stairs:stair_junglewood", }, slab_wood = { "stairs:slab_junglewood", },
	stair_wood_inner = { "stairs:stair_inner_junglewood", "stairs:stair_junglewood", },
	stair_wood_outer = { "stairs:stair_outer_junglewood", "stairs:stair_junglewood", },
}

local cache = {}

local function first(list)
	if type(list) == "function" then
		return list()
	end
	for _, name in ipairs(list) do
		if name == "air" or core.registered_nodes[name] then
			return name
		end
	end
	return "air"
end

local function entry(palette, key)
	local p = assert(PALETTES[palette], "unknown palette " .. tostring(palette))
	return p[key] or PLAINS[key] or FIXED[key]
end

function VP.get(palette, key)
	local list = entry(palette, key)
	return list and first(list) or nil
end

function VP.resolve(palette, role)
	if role == "skip" then
		return nil
	end
	local c = cache[palette]
	if not c then
		c = {}
		cache[palette] = c
	end
	if c[role] == nil then
		local key = SAME[role] or role
		local list = entry(palette, key)
		c[role] = list and first(list) or false
	end
	return c[role] or nil, FORCED_P2[role]
end

function VP.roof_snow(palette)
	local list = PALETTES[palette].roof_snow
	return list and first(list) or nil
end
