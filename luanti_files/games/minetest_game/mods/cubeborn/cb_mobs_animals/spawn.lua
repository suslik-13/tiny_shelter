-- Spawn rules of the animals (spec cycle 4, 2.1 and 8b).
local A = cb_mobs_animals
local GRASS = { "default:dirt_with_grass", "default:dirt_with_rainforest_litter", "group:soil", }
cb_spawning.register(A.PIG, { dims = { "overworld", }, category = "animal", light = { 9, 15, }, sky = true,
	on = GRASS, weight = 100, group = { 2, 4, }, })
if core.registered_nodes["ethereal:mushroom_dirt"] then
	cb_spawning.register(A.MOOSHROOM, { dims = { "overworld", }, category = "animal", light = { 9, 15, }, sky = true,
		on = { "ethereal:mushroom_dirt", }, biomes = { "mushroom", }, weight = 100, group = { 2, 4, }, })
end
cb_spawning.register(A.DONKEY, { dims = { "overworld", }, category = "animal", light = { 9, 15, }, sky = true,
	on = { "group:soil", }, biomes = { "grassland", "savanna", }, weight = 20, group = { 1, 3, }, })
cb_spawning.register(A.SKELETON_HORSE, { dims = { "overworld", }, category = "monster", dark = true,
	on = { "group:soil", }, weight = 2, group = { 1, 1, }, })
cb_spawning.register(A.ZOMBIE_HORSE, { dims = { "overworld", }, category = "monster", dark = true,
	on = { "group:soil", }, weight = 1, group = { 1, 1, }, })
cb_spawning.register(A.ARMADILLO, { dims = { "overworld", }, category = "animal", light = { 9, 15, }, sky = true,
	on = { "group:soil", }, biomes = { "savanna", }, weight = 10, group = { 1, 3, }, })
cb_spawning.register(A.WOLF, { dims = { "overworld", }, category = "animal", light = { 9, 15, }, sky = true,
	on = { "group:soil", }, biomes = { "taiga", "coniferous", "snow", "savanna", "deciduous", "forest", },
	weight = 20, group = { 2, 4, }, })
cb_spawning.register(A.FOX, { dims = { "overworld", }, category = "animal", sky = true,
	on = { "group:soil", "default:dirt_with_snow", "default:dirt_with_coniferous_litter", },
	biomes = { "taiga", "coniferous", "snow", }, weight = 10, group = { 1, 2, }, })
cb_spawning.register(A.OCELOT, { dims = { "overworld", }, category = "animal", sky = true,
	on = { "group:soil", "default:dirt_with_rainforest_litter", }, biomes = { "rainforest", "jungle", },
	weight = 10, group = { 1, 2, }, })
cb_spawning.register(A.PARROT, { dims = { "overworld", }, category = "animal", sky = true,
	on = { "group:soil", "group:tree", "group:leaves", "default:dirt_with_rainforest_litter", },
	biomes = { "rainforest", "jungle", }, weight = 10, group = { 1, 2, }, })
cb_spawning.register(A.GOAT, { dims = { "overworld", }, category = "animal", light = { 7, 15, }, sky = true,
	y = { 60, 31000, }, on = { "default:dirt_with_snow", "default:snowblock", "default:stone", "default:gravel",
	"group:soil", }, weight = 5, group = { 1, 3, }, })
local WET = { "swamp", "marsh", "mangrove", "bayou", "rainforest", "jungle", "deciduous", }
cb_spawning.register(A.FROG, { dims = { "overworld", }, category = "animal", light = { 9, 15, }, sky = true,
	on = { "group:soil", "default:dirt", "default:clay", }, biomes = WET, weight = 10, group = { 2, 4, }, })
cb_spawning.register(A.TADPOLE, { dims = { "overworld", }, category = "water", sky = true, y = { -2, 30, },
	on = { "default:water_source", "default:river_water_source", }, biomes = WET, weight = 5, group = { 2, 4, }, })
cb_spawning.register(A.AXOLOTL, { dims = { "overworld", }, category = "water", sky = false, y = { -300, -1, },
	on = { "default:water_source", "default:river_water_source", }, weight = 10, group = { 1, 4, }, })
cb_spawning.register(A.POLAR_BEAR, { dims = { "overworld", }, category = "animal", light = { 7, 15, }, sky = true,
	on = { "default:snowblock", "default:ice", "default:dirt_with_snow", "default:permafrost_with_stones",
	"default:permafrost_with_moss", "default:permafrost", }, biomes = { "icesheet", "tundra", "snow", "ice", },
	weight = 5, group = { 1, 2, }, })
cb_spawning.register(A.CAMEL, { dims = { "overworld", }, category = "animal", light = { 9, 15, }, sky = true,
	on = { "default:desert_sand", "default:sand", }, biomes = { "desert", "sandstone", }, weight = 2,
	group = { 1, 1, }, })
cb_spawning.register(A.SNIFFER, { dims = { "overworld", }, category = "animal", light = { 9, 15, }, sky = true,
	on = { "group:soil", }, biomes = { "rainforest", "jungle", "savanna", "deciduous", }, weight = 1, group = { 1, 1, }, })
