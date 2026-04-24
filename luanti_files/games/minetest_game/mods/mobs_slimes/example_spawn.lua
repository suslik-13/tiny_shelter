
	--== GREEN SLIMES ==--

	-- choose spawn medium depending on [game]

local nod_dirt = "default:dirt_with_rainforest_litter"
local nod_grass = "default:junglegrass"
local nod_mossy = "default:mossycobble"

if core.get_modpath("mcl_core") then
	nod_dirt = "mcl_core:dirt_with_grass"
	nod_grass = "mcl_flowers:tallgrass"
	nod_mossy = "mcl_core:mossycobble"
end

-- spawn in world

mobs:spawn({
	name = "mobs_slimes:greensmall",
	nodes = {nod_dirt},
	neighbors = {"air", nod_grass},
	min_light = 4,
	chance = 5000,
	min_height = 0,
	active_object_count = 8
})

mobs:spawn({
	name = "mobs_slimes:greenmedium",
	nodes = {nod_dirt},
	neighbors = {"air", nod_grass},
	min_light = 4,
	chance = 10000,
	min_height = 0,
	active_object_count = 8
})

mobs:spawn({
	name = "mobs_slimes:greenbig",
	nodes = {nod_dirt},
	neighbors = {"air", nod_grass},
	min_light = 4,
	chance = 15000,
	min_height = 0,
	active_object_count = 8
})

mobs:spawn({
	name = "mobs_slimes:greensmall",
	nodes = {nod_mossy},
	min_light = 4,
	chance = 10000,
	min_height = 0,
	active_object_count = 8
})

mobs:spawn({
	name = "mobs_slimes:greenmedium",
	nodes = {nod_mossy},
	min_light = 4,
	chance = 10000,
	min_height = 0,
	active_object_count = 8
})

--== LAVA SLIMES ==--


-- choose spawn medium depending on [game]

local nod_lava_source = "default:lava_source"
local nod_lava_flow = "default:lava_flowing"
local nod_fire = "fire:basic_flame"

if core.get_modpath("mcl_core") then
	nod_lava_source = "mcl_core:lava_source"
	nod_lava_flow = "mcl_core:lava_flowing"
	nod_fire = "mcl_fire:fire"
end

-- spawn in world

mobs:spawn({
	name = "mobs_slimes:lavasmall",
	nodes = {nod_lava_source},
	neighbors = {nod_lava_flow},
	min_light = 4,
	chance = 5000,
	max_height = -64,
	active_object_count = 8
})

mobs:spawn({
	name = "mobs_slimes:lavamedium",
	nodes = {nod_lava_source},
	neighbors = {nod_lava_flow},
	min_light = 4,
	chance = 10000,
	max_height = -64,
	active_object_count = 8
})

mobs:spawn({
	name = "mobs_slimes:lavabig",
	nodes = {nod_lava_source},
	neighbors = {nod_lava_flow},
	min_light = 4,
	chance = 15000,
	max_height = -64,
	active_object_count = 8
})
