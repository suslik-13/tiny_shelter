-- Magma cube (spec cycle 4, 8d): hops at its prey; a big one splits into
-- 2-4 small ones when it dies, a small one into 2-4 tiny ones. Fire and lava
-- do not hurt it. Small and tiny ones may drop magma cream.
local S = cb_mobs_nether.S
local N = cb_mobs_nether
N.MAGMA_CREAM = "cb_mobs_nether:magma_cream"
N.MAGMA = { big = "cb_mobs_nether:magma_cube_big", small = "cb_mobs_nether:magma_cube_small",
	tiny = "cb_mobs_nether:magma_cube_tiny", }

core.register_craftitem(N.MAGMA_CREAM, { description = S("Magma Cream"),
	inventory_image = "cb_mobs_nether_magma_cream.png", })

-- size, HP, damage, visual size, the next size down
local SIZES = {
	big = { 2.04, 16, 6, 12.5, "small", }, small = { 1.02, 4, 4, 6.25, "tiny", }, tiny = { 0.51, 1, 3, 3.125, nil, },
}

-- A dying cube's children: 2-4 of the next size around pos; returns them.
function N.magma_split(name, pos)
	local size
	for k, v in pairs(N.MAGMA) do
		size = v == name and k or size
	end
	local next = size and SIZES[size][5]
	local out = {}
	if not next then
		return out
	end
	for _ = 1, math.random(2, 4) do
		local p = vector.offset(pos, math.random() - 0.5, 0.5, math.random() - 0.5)
		local obj = core.add_entity(p, N.MAGMA[next])
		out[#out + 1] = obj and obj:get_luaentity()
	end
	return out
end

for size, v in pairs(SIZES) do
	local w = v[1] / 2
	mobs:register_mob(N.MAGMA[size], {
		type = "monster", passive = false, attack_type = "dogfight", damage = v[3], reach = v[1] + 0.5,
		hp_min = v[2], hp_max = v[2], armor = 100,
		collisionbox = { -w, 0, -w, w, v[1], w, },
		visual = "mesh", mesh = "cb_mobs_nether_magma_cube.b3d", visual_size = { x = v[4], y = v[4], },
		textures = { { "cb_mobs_nether_magma_cube.png", "cb_mobs_nether_magma_cube.png", }, },
		walk_velocity = 1.5, run_velocity = 2.5, jump = true, jump_height = 6, view_range = 16, stepheight = 1.1,
		water_damage = 2, lava_damage = 0, fire_damage = 0, light_damage = 0, fall_damage = false,
		makes_footstep_sound = false,
		drops = size ~= "big" and { { name = N.MAGMA_CREAM, chance = 4, min = 1, max = 1, }, } or {},
		sounds = { jump = size == "big" and "cb_mobs_nether_magma_cube_big" or "cb_mobs_nether_magma_cube_small",
			attack = "cb_mobs_nether_magma_cube_attack",
			damage = size == "big" and "cb_mobs_nether_magma_cube_big" or "cb_mobs_nether_magma_cube_small",
			death = size == "big" and "cb_mobs_nether_magma_cube_big" or "cb_mobs_nether_magma_cube_small",
			distance = 16, },
		animation = { speed_normal = 25, stand_start = 1, stand_end = 1, walk_start = 1, walk_end = 20,
			run_start = 1, run_end = 20, jump_start = 1, jump_end = 20, },
		on_die = function(self, pos)
			N.magma_split(self.name, pos)
		end,
	})
end
mobs:register_egg(N.MAGMA.big, S("Magma Cube"), "cb_mobs_nether_magma_cream.png", 1)
