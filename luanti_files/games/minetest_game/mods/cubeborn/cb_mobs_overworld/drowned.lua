-- Drowned (spec cycle 4, 8a): a zombie of rivers and oceans; 15 % carry a
-- trident and throw it (a mob projectile, never an item), the rest fight
-- hand to hand. They do not burn and swim after their target.
local S = cb_mobs_overworld.S
local Z = cb_mobs_overworld
Z.DROWNED, Z.TRIDENT_CHANCE = "cb_mobs_overworld:drowned", 0.15

mobs:register_arrow("cb_mobs_overworld:trident", {
	visual = "sprite", visual_size = { x = 0.6, y = 0.6, }, textures = { "cb_mobs_overworld_trident.png", },
	velocity = 14,
	hit_player = function(self, player)
		player:punch(self.object, 1, { full_punch_interval = 1, damage_groups = { fleshy = 8, }, }, nil)
	end,
	hit_mob = function(self, obj)
		obj:punch(self.object, 1, { full_punch_interval = 1, damage_groups = { fleshy = 8, }, }, nil)
	end,
	hit_node = function() end,
})

function Z.arm_drowned(ent, trident)
	ent._trident = trident
	if trident then
		ent.attack_type, ent.arrow, ent.shoot_interval, ent.shoot_offset = "dogshoot", "cb_mobs_overworld:trident", 3, 1.5
		ent.dogshoot_switch, ent.dogshoot_count_max, ent.dogshoot_count2_max = 1, 4, 3
	else
		ent.attack_type = "dogfight"
	end
end

Z.register_zombie(Z.DROWNED, {
	mesh = "cb_mobs_overworld_drowned.b3d", visual_size = { x = 1, y = 1, },
	textures = { { "cb_mobs_overworld_drowned.png", "cb_mobs_overworld_drowned_overlay.png", "blank.png", "blank.png", }, },
	light_damage = 0, floats = 0, fly_in = { "default:water_source", "default:river_water_source", "default:water_flowing",
		"default:river_water_flowing", },
	sounds = { random = "cb_mobs_overworld_drowned_groan", damage = "cb_mobs_overworld_drowned_hurt",
		death = "cb_mobs_overworld_drowned_death", attack = "mobs_punch", distance = 16, },
	animation = { speed_normal = 15, stand_start = 0, stand_end = 60, walk_start = 80, walk_end = 140, run_start = 80,
		run_end = 140, punch_start = 80, punch_end = 140, shoot_start = 80, shoot_end = 140, },
	after_activate = function(self)
		if self._trident == nil then
			self._trident = math.random() < Z.TRIDENT_CHANCE
		end
		Z.arm_drowned(self, self._trident)
	end,
}, false)
mobs:register_egg(Z.DROWNED, S("Drowned"), "default_water.png", 1)
