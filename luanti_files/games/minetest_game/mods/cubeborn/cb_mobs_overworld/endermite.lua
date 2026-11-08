-- Endermite (spec cycle 4, 8a): 5 % of landing ender pearls bring one; it
-- lives two minutes.
local S = cb_mobs_overworld.S
local Z = cb_mobs_overworld
Z.ENDERMITE, Z.MITE_CHANCE, Z.MITE_LIFE = "cb_mobs_overworld:endermite", 0.05, 120

mobs:register_mob(Z.ENDERMITE, {
	type = "monster", passive = false, attack_type = "dogfight", reach = 1, damage = 2,
	hp_min = 8, hp_max = 8, armor = 100, collisionbox = { -0.2, 0, -0.2, 0.2, 0.29, 0.2, },
	visual = "mesh", mesh = "cb_mobs_overworld_endermite.b3d", visual_size = { x = 3, y = 3, },
	textures = { { "cb_mobs_overworld_endermite.png", }, },
	walk_velocity = 1.2, run_velocity = 2.2, jump = true, view_range = 12, water_damage = 0, lava_damage = 4,
	drops = {},
	sounds = { random = "cb_mobs_overworld_endermite_random", damage = "cb_mobs_overworld_endermite_hurt",
		death = "cb_mobs_overworld_endermite_death", distance = 12, },
	animation = { speed_normal = 55, stand_start = 0, stand_end = 0, walk_start = 0, walk_end = 20, run_start = 0,
		run_end = 20, },
	do_custom = function(self, dtime)
		self._life = (self._life or Z.MITE_LIFE) - dtime
		if self._life <= 0 then
			self.object:remove()
			return false
		end
		return true
	end,
})
mobs:register_egg(Z.ENDERMITE, S("Endermite"), "default_obsidian.png", 1)

if cb_items.pearl_hooks then
	table.insert(cb_items.pearl_hooks, function(pos)
		if math.random() < Z.MITE_CHANCE then
			core.add_entity(vector.offset(pos, 0, 0.5, 0), Z.ENDERMITE)
		end
	end)
end
