-- Zombie villager (spec cycle 2, 3.4): hostile, burns in daylight. A
-- villager killed by a zombie (V.ZOMBIES or any mob named *zombie*) turns
-- into one: never on easy, half on normal, always on hard.
local S = cb_mobs_village.S
local V = cb_mobs_village
local NAME = "cb_mobs_village:zombie_villager"
local CHANCE = { easy = 0, normal = 0.5, hard = 1, }

V.ZOMBIES = { [NAME] = true, }

function V.is_zombie(name)
	return V.ZOMBIES[name] == true or name:find("zombie", 1, true) ~= nil
end

function V.convert_chance()
	return CHANCE[cb_core.setting("cubeborn.difficulty", "normal")] or CHANCE.normal
end

mobs:register_mob(NAME, cb_core.fixed_head({
	type = "monster",
	passive = false,
	attack_type = "dogfight",
	reach = 2,
	damage = 3,
	hp_min = 20,
	hp_max = 20,
	armor = 100,
	collisionbox = { -0.3, 0, -0.3, 0.3, 1.95, 0.3, },
	visual = "mesh",
	mesh = "cb_mobs_village_zombie_villager.b3d",
	visual_size = { x = 2.75, y = 2.75, },
	textures = { { V.texture("zombie_villager", "plains"), "blank.png", "blank.png", }, },
	makes_footstep_sound = true,
	stepheight = 1.1,
	walk_velocity = 0.8,
	run_velocity = 1.6,
	jump = true,
	view_range = 16,
	light_damage = 2,
	water_damage = 0,
	lava_damage = 8,
	attack_npcs = true,
	attack_animals = false,
	drops = {},
	sounds = { random = "cb_mobs_village_zombie_villager_groan", damage = "cb_mobs_village_villager_hurt",
		death = "cb_mobs_village_zombie_villager_death", attack = "mobs_punch", distance = 16, },
	animation = { speed_normal = 20, stand_start = 20, stand_end = 40, walk_start = 0, walk_end = 20, run_start = 0,
		run_end = 20, punch_start = 0, punch_end = 20, },
	after_activate = function(self)
		V.retexture(self, "zombie_villager")
	end,
}, 0))

mobs:register_egg(NAME, S("Zombie Villager"), "default_dirt.png", 1)

table.insert(V.death_hooks, function(self, pos)
	local cause = self.cause_of_death
	local killer = cause and cause.puncher
	local ent = killer and killer.get_luaentity and killer:get_luaentity()
	if ent and type(ent.name) == "string" and V.is_zombie(ent.name) and math.random() < V.convert_chance() then
		core.add_entity(pos, NAME, core.serialize({ _vtype = self._vtype, }))
	end
end)
