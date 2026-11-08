-- Stray (spec cycle 4, 8a): the skeleton of snowy biomes; shoots arrows that
-- slow (mob projectiles only, nothing to pick up), burns in daylight.
local S = cb_mobs_overworld.S
local Z = cb_mobs_overworld
Z.STRAY = "cb_mobs_overworld:stray"

function Z.stray_hit(obj)
	obj:set_hp(obj:get_hp() - 3, { type = "set_hp", cause = "cb_stray_arrow", })
	if obj.is_player and obj:is_player() then
		cb_core.effects.apply(obj, "slowness", 1, 30)
	end
end

mobs:register_arrow("cb_mobs_overworld:stray_arrow", {
	visual = "sprite", visual_size = { x = 0.5, y = 0.5, }, textures = { "cb_mobs_overworld_arrow.png", },
	velocity = 18,
	hit_player = function(_, player)
		Z.stray_hit(player)
	end,
	hit_mob = function(_, obj)
		obj:punch(obj, 1, { full_punch_interval = 1, damage_groups = { fleshy = 3, }, }, nil)
	end,
	hit_node = function() end,
})

mobs:register_mob(Z.STRAY, {
	type = "monster", passive = false, attack_type = "shoot", arrow = "cb_mobs_overworld:stray_arrow",
	shoot_interval = 2, shoot_offset = 1.5, hp_min = 20, hp_max = 20, armor = 100,
	collisionbox = { -0.3, 0, -0.3, 0.3, 1.99, 0.3, },
	visual = "mesh", mesh = "cb_mobs_overworld_skeleton.b3d", visual_size = { x = 1, y = 1, },
	textures = { { "blank.png", "cb_mobs_overworld_stray_overlay.png", "cb_mobs_overworld_stray.png", }, },
	makes_footstep_sound = true, walk_velocity = 1, run_velocity = 1.6, jump = true, view_range = 16,
	light_damage = 2, water_damage = 0, lava_damage = 8,
	drops = core.registered_items["bonemeal:bone"] and { { name = "bonemeal:bone", chance = 1, min = 0, max = 2, }, } or {},
	sounds = { random = "cb_mobs_overworld_skeleton_random", damage = "cb_mobs_overworld_skeleton_hurt",
		death = "cb_mobs_overworld_skeleton_death", distance = 16, },
	animation = { speed_normal = 15, stand_start = 0, stand_end = 40, walk_start = 40, walk_end = 60, run_start = 40,
		run_end = 60, shoot_start = 40, shoot_end = 60, },
})
mobs:register_egg(Z.STRAY, S("Stray"), "default_snow.png", 1)
