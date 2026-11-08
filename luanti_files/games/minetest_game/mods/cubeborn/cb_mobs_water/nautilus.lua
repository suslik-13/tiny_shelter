-- Nautilus (spec cycle 4, 8c): drifts in warm seas and charges whoever hurts
-- it. One killed by a player drops a nautilus shell 1 time in 20. Taming,
-- riding and nautilus armour (Minecraft 1.21.130) are not part of the spec.
local S = cb_mobs_water.S
local W = cb_mobs_water
W.NAUTILUS, W.SHELL = "cb_mobs_water:nautilus", "cb_mobs_water:nautilus_shell"

core.register_craftitem(W.SHELL, { description = S("Nautilus Shell"),
	inventory_image = "cb_mobs_water_nautilus_shell.png", })

function W.shell_drop(self, cause, roll)
	local by_player = cause and cause.puncher and cause.puncher:is_player()
	if by_player and (roll or math.random()) < 0.05 then
		core.add_item(self.object:get_pos(), W.SHELL)
		return true
	end
	return false
end

mobs:register_mob(W.NAUTILUS, {
	type = "animal", passive = false, attack_players = false, attack_type = "dogfight", damage = 3, reach = 1.5,
	hp_min = 15, hp_max = 15, armor = 100,
	collisionbox = { -0.4375, 0, -0.4375, 0.4375, 0.95, 0.4375, },
	visual = "mesh", mesh = "cb_mobs_water_nautilus.b3d", visual_size = { x = 1, y = 1, },
	textures = { { "cb_mobs_water_nautilus.png", }, },
	fly = true, fly_in = W.WATER, walk_velocity = 0.8, run_velocity = 2.5, jump = false, view_range = 8,
	water_damage = 0, lava_damage = 5, light_damage = 0, fall_damage = false, makes_footstep_sound = false,
	sounds = { random = "cb_mobs_water_nautilus_idle", damage = "cb_mobs_water_nautilus_hurt",
		death = "cb_mobs_water_nautilus_death", distance = 12, },
	animation = { speed_normal = 25, stand_start = 0, stand_end = 40, walk_start = 41, walk_end = 61,
		run_start = 41, run_end = 61, run_speed = 45, fly_start = 41, fly_end = 61, punch_start = 41, punch_end = 61, },
	on_flop = W.choke,
	on_die = function(self)
		W.shell_drop(self, self.cause_of_death)
	end,
})
mobs:register_egg(W.NAUTILUS, S("Nautilus"), "cb_mobs_water_nautilus_shell.png", 1)
