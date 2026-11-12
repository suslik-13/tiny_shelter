-- Spawn rules of the Nether mobs (spec cycle 4, 2.1 and 8d).
local N = cb_mobs_nether
-- netherrack and stone are cracky; the sands are not
local FLOOR = { "group:cracky", "nether:sand", "cb_blocks:soul_sand", "cb_blocks:soul_soil", }
cb_spawning.register(N.MAGMA.big, { dims = { "nether", }, category = "monster", on = FLOOR, weight = 2,
	group = { 1, 1, }, })
cb_spawning.register(N.MAGMA.small, { dims = { "nether", }, category = "monster", on = FLOOR, weight = 4,
	group = { 1, 2, }, })
cb_spawning.register(N.GHAST, { dims = { "nether", }, category = "monster", on = FLOOR, weight = 3, group = { 1, 1, }, })
cb_spawning.register(N.ZOMBIFIED, { dims = { "nether", }, category = "monster", on = FLOOR, weight = 10, group = { 2, 4, }, })
cb_spawning.register(N.PIGLIN, { dims = { "nether", }, category = "monster", on = FLOOR, weight = 10, group = { 2, 4, }, })
cb_spawning.register(N.HOGLIN, { dims = { "nether", }, category = "monster", on = FLOOR, weight = 4, group = { 2, 4, }, })
cb_spawning.register(N.STRIDER, { dims = { "nether", }, category = "animal", kind = "ground",
	on = { "default:lava_source", "nether:lava_source", }, weight = 5, group = { 1, 2, }, })
