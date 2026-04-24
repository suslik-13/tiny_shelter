
-- Dungeon Master

mobs:spawn({
	name = "mobs_monster:dungeon_master",
	nodes = {"default:stone"},
	max_light = 5,
	chance = 9000,
	active_object_count = 1,
	max_height = -200,
})

-- Mese Monster

mobs:spawn({
	name = "mobs_monster:mese_monster",
	nodes = {"default:stone"},
	max_light = 7,
	chance = 5000,
	active_object_count = 1,
	max_height = -100,
})

-- Oerkki

mobs:spawn({
	name = "mobs_monster:oerkki",
	nodes = {"default:stone"},
	max_light = 7,
	chance = 7000,
	max_height = -100,
})

-- Dirt Monster

mobs:spawn({
	name = "mobs_monster:dirt_monster",
	nodes = {"default:dirt_with_grass"},
	min_light = 0,
	max_light = 7,
	chance = 6000,
	active_object_count = 2,
	min_height = 0,
	day_toggle = false,
})


-- Lava Flan

mobs:spawn({
	name = "mobs_monster:lava_flan",
	nodes = {"default:lava_source"},
	chance = 1500,
	active_object_count = 1,
	max_height = 0,
})

-- Sand Monster

mobs:spawn({
	name = "mobs_monster:sand_monster",
	nodes = {"default:desert_sand"},
	chance = 7000,
	active_object_count = 2,
	min_height = 0,
})

-- Spider (above ground)

mobs:spawn({
	name = "mobs_monster:spider",
	nodes = {
		"default:dirt_with_rainforest_litter", "default:snowblock",
		"default:snow", "ethereal:crystal_dirt", "ethereal:cold_dirt"
	},
	min_light = 0,
	max_light = 8,
	chance = 7000,
	active_object_count = 1,
	min_height = 25,
	max_height = 31000,
})

-- Spider (below ground)
mobs:spawn({
	name = "mobs_monster:spider",
	nodes = {"default:stone_with_mese", "default:mese", "default:stone"},
	min_light = 0,
	max_light = 7,
	chance = 7000,
	active_object_count = 1,
	min_height = -31000,
	max_height = -40,
})

-- Stone Monster

mobs:spawn({
	name = "mobs_monster:stone_monster",
	nodes = {"default:stone", "default:desert_stone", "default:sandstone"},
	max_light = 7,
	chance = 7000,
	max_height = 0,
})

-- Tree Monster

mobs:spawn({
	name = "mobs_monster:tree_monster",
	nodes = {"default:leaves", "default:jungleleaves"},
	max_light = 7,
	chance = 7000,
	min_height = 0,
	day_toggle = false,
})

