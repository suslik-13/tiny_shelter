-- Spawn rules of the overworld monsters (spec cycle 4, 2.1 and 8a).
local Z = cb_mobs_overworld
local GROUND = { "group:soil", "group:stone", "group:sand", "default:gravel", "default:snowblock", "default:dirt_with_snow", }
cb_spawning.register(Z.ZOMBIE, { dims = { "overworld", }, category = "monster", dark = true, on = GROUND,
	weight = 100, group = { 2, 4, }, })
cb_spawning.register(Z.HUSK, { dims = { "overworld", }, category = "monster", dark = true, on = GROUND,
	biomes = { "desert", }, weight = 400, group = { 2, 4, }, })
-- Drowned: Minecraft's 1 in 15 on top of the weight, no more than 3 around
-- (the water ABM hits seas everywhere: they came out of every shore at night).
cb_spawning.register(Z.DROWNED, { dims = { "overworld", }, category = "monster", dark = true,
	on = { "default:water_source", "default:river_water_source", }, kind = "water", y = { -64, 1, }, weight = 100,
	group = { 1, 1, }, chance = 1 / 15, cap = 3, })
local GROUND_ALL = { "group:soil", "group:stone", "group:sand", "default:gravel", "default:snowblock", "default:dirt_with_snow", }
cb_spawning.register(Z.CREEPER, { dims = { "overworld", }, category = "monster", dark = true, on = GROUND_ALL,
	weight = 100, group = { 1, 1, }, })
if core.registered_entities["mobs_monster:spider"] and core.registered_entities["mobs_skeletons:skeleton_archer"] then
	cb_spawning.register(Z.JOCKEY, { dims = { "overworld", }, category = "monster", dark = true, on = GROUND_ALL,
		weight = 1, group = { 1, 1, }, })
end
cb_spawning.register(Z.STRAY, { dims = { "overworld", }, category = "monster", dark = true, on = GROUND_ALL,
	biomes = { "snow", "ice", "tundra", }, weight = 400, group = { 1, 3, }, })
