-- Ravager (spec cycle 2, 6): comes with raids only, no riders. 100 HP, a
-- blow of 12 that throws the target back; it tramples leaves and crops in
-- front of it where nobody protects them.
local S = cb_mobs_illager.S
local I = cb_mobs_illager
local NAME = "cb_mobs_illager:ravager"
I.RAVAGER = NAME

-- Removes leaves and crops in the 3 x 3 x 3 box in front; returns how many.
function I.trample(self)
	local pos = self.object:get_pos()
	if not pos then
		return 0
	end
	local yaw = self.object:get_yaw()
	local front = vector.round(vector.offset(pos, -math.sin(yaw) * 2, 0, math.cos(yaw) * 2))
	local n = 0
	for _, p in ipairs(core.find_nodes_in_area(vector.offset(front, -1, 0, -1), vector.offset(front, 1, 2, 1),
			{ "group:leaves", "group:plant", })) do
		if not core.is_protected(p, "") then
			core.remove_node(p)
			n = n + 1
		end
	end
	return n
end

I.register(NAME, {
	mesh = "cb_mobs_illager_ravager.b3d",
	textures = { { "cb_mobs_illager_ravager.png", }, },
	hp_min = 100,
	hp_max = 100,
	collisionbox = { -0.975, 0, -0.975, 0.975, 2.2, 0.975, },
	visual_size = { x = 1, y = 1, },
	attack_type = "dogfight",
	reach = 3,
	damage = 12,
	knock_back = false,
	walk_velocity = 1.2,
	run_velocity = 2.4,
	view_range = 32,
	animation = { speed_normal = 20, stand_start = 0, stand_end = 0, walk_start = 20, walk_end = 40,
		run_start = 20, run_end = 40, punch_start = 20, punch_end = 40, },
	drops = I.drops({ { "mobs:saddle", 1, 1, }, }),
	sounds = { random = "cb_mobs_illager_ravager_roar", war_cry = "cb_mobs_illager_ravager_roar",
		attack = "cb_mobs_illager_ravager_bite", damage = "cb_mobs_illager_ravager_hurt",
		death = "cb_mobs_illager_ravager_death", distance = 24, },
	do_custom = function(self, dtime)
		self._trample_t = (self._trample_t or 0) + dtime
		if self._trample_t >= 0.5 then
			self._trample_t = 0
			if self.state == "walk" or self.state == "attack" then
				I.trample(self)
			end
		end
	end,
	-- mobs_redo calls self:custom_attack(self, target_pos); true = punch too
	custom_attack = function(self)
		local target = self.attack
		local tpos = target and target:get_pos()
		local pos = self.object:get_pos()
		if tpos and pos and target.add_velocity then
			local dir = vector.normalize(vector.subtract(tpos, pos))
			target:add_velocity(vector.new(dir.x * 8, 4, dir.z * 8))
		end
		return true
	end,
})

mobs:register_egg(NAME, S("Ravager"), "default_stone.png", 1)
