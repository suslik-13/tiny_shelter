-- Spawn rules of the water mobs (spec cycle 4, 2.1 and 8c).
local W = cb_mobs_water
local SEA = { "default:water_source", "default:river_water_source", }
cb_spawning.register(W.SQUID, { dims = { "overworld", }, category = "water", sky = true, y = { -40, 1, },
	on = SEA, weight = 10, group = { 2, 4, }, })
cb_spawning.register(W.GLOW_SQUID, { dims = { "overworld", }, category = "water", sky = false, y = { -300, -1, },
	on = SEA, weight = 10, group = { 2, 4, }, })
cb_spawning.register(W.COD, { dims = { "overworld", }, category = "water", sky = true, y = { -40, 1, },
	on = { "default:water_source", }, weight = 15, group = { 3, 6, }, })
cb_spawning.register(W.SALMON, { dims = { "overworld", }, category = "water", sky = true, y = { -40, 1, },
	on = SEA, biomes = { "taiga", "snow", "coniferous", "tundra", "ice", }, weight = 15, group = { 1, 5, }, })
cb_spawning.register(W.PUFFERFISH, { dims = { "overworld", }, category = "water", sky = true, y = { -40, 1, },
	on = { "default:water_source", }, biomes = { "rainforest", "jungle", "savanna", "desert", "beach", "ocean", },
	weight = 5, group = { 1, 3, }, })
cb_spawning.register(W.DOLPHIN, { dims = { "overworld", }, category = "water", sky = true, y = { -30, 1, },
	on = { "default:water_source", }, biomes = { "rainforest", "jungle", "savanna", "desert", "beach", "ocean", },
	weight = 2, group = { 2, 4, }, })
cb_spawning.register(W.NAUTILUS, { dims = { "overworld", }, category = "water", sky = true, y = { -60, -8, },
	on = { "default:water_source", }, biomes = { "rainforest", "jungle", "savanna", "desert", "beach", "ocean", },
	weight = 2, group = { 1, 2, }, })
