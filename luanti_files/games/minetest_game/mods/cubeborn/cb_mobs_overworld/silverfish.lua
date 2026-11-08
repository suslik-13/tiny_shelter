-- Silverfish (spec cycle 4, 8a): small, fast; come out of infested blocks
-- and a spawner in strongholds; a hurt one wakes up to 4 more from infested
-- blocks within 5.
local S = cb_mobs_overworld.S
local Z = cb_mobs_overworld
Z.SILVERFISH = "cb_mobs_overworld:silverfish"

function Z.wake_silverfish(pos, n)
	local found = core.find_nodes_in_area(vector.subtract(pos, 5), vector.add(pos, 5), { "group:infested", })
	local woke = 0
	for _, p in ipairs(found) do
		if woke >= n then
			break
		end
		local base = cb_blocks.INFESTED[core.get_node(p).name]
		if base then
			core.set_node(p, { name = base, })
			core.add_entity(vector.offset(p, 0, 0.5, 0), Z.SILVERFISH)
			woke = woke + 1
		end
	end
	return woke
end

mobs:register_mob(Z.SILVERFISH, {
	type = "monster", passive = false, attack_type = "dogfight", reach = 1, damage = 1,
	hp_min = 8, hp_max = 8, armor = 100, collisionbox = { -0.2, 0, -0.2, 0.2, 0.3, 0.2, },
	visual = "mesh", mesh = "cb_mobs_overworld_silverfish.b3d", visual_size = { x = 3, y = 3, },
	textures = { { "cb_mobs_overworld_silverfish.png", }, },
	walk_velocity = 1.2, run_velocity = 2.4, jump = true, stepheight = 1.1, view_range = 12,
	water_damage = 0, lava_damage = 4, drops = {},
	sounds = { random = "cb_mobs_overworld_silverfish_idle", damage = "cb_mobs_overworld_silverfish_hurt",
		death = "cb_mobs_overworld_silverfish_death", attack = "mobs_punch", distance = 12, },
	animation = { speed_normal = 30, stand_start = 0, stand_end = 20, walk_start = 0, walk_end = 20, run_start = 0,
		run_end = 20, },
	do_punch = function(self)
		local now = core.get_gametime()
		if (self._called or 0) <= now then
			self._called = now + 5
			Z.wake_silverfish(self.object:get_pos(), 4)
		end
		return true
	end,
})
mobs:register_egg(Z.SILVERFISH, S("Silverfish"), "default_stone.png", 1)

table.insert(cb_blocks.infested_hooks, function(pos)
	core.add_entity(vector.offset(pos, 0, 0.5, 0), Z.SILVERFISH)
end)
