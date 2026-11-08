-- Cave spider (spec cycle 2, 4.2): small, comes only from mineshaft
-- spawners; its bite poisons players (7 s on normal, 15 s on hard, none on
-- easy).
local S = cb_mobs_village.S
local V = cb_mobs_village
local NAME = "cb_mobs_village:cave_spider"
local POISON = { easy = 0, normal = 7, hard = 15, }

function V.poison_seconds()
	return POISON[cb_core.difficulty()]
end

mobs:register_mob(NAME, {
	type = "monster",
	passive = false,
	attack_type = "dogfight",
	reach = 2,
	damage = 2,
	hp_min = 12,
	hp_max = 12,
	armor = 100,
	collisionbox = { -0.35, 0, -0.35, 0.35, 0.47, 0.35, },
	visual = "mesh",
	mesh = "cb_mobs_village_spider.b3d",
	visual_size = { x = 0.55, y = 0.5, },
	textures = { { "cb_mobs_village_cave_spider.png^(cb_mobs_village_spider_eyes.png^[makealpha:0,0,0)", }, },
	makes_footstep_sound = false,
	walk_velocity = 1.2,
	run_velocity = 2.6,
	jump = true,
	stepheight = 1.1,
	view_range = 16,
	water_damage = 0,
	lava_damage = 8,
	light_damage = 0,
	drops = V.drops({ { "farming:string", 0, 2, }, }),
	sounds = { random = "cb_mobs_village_spider_random", damage = "cb_mobs_village_spider_hurt",
		death = "cb_mobs_village_spider_death", attack = "cb_mobs_village_spider_attack", distance = 16, },
	animation = { speed_normal = 40, stand_start = 20, stand_end = 40, walk_start = 0, walk_end = 20, run_start = 0,
		run_end = 20, punch_start = 0, punch_end = 20, },
	-- mobs_redo calls self:custom_attack(self, p); true = do the usual punch.
	custom_attack = function(self)
		local s = V.poison_seconds()
		if s > 0 and self.attack and self.attack.is_player and self.attack:is_player() then
			cb_core.effects.apply(self.attack, "poison", 1, s)
		end
		return true
	end,
})

mobs:register_egg(NAME, S("Cave Spider"), "default_obsidian.png", 1)
