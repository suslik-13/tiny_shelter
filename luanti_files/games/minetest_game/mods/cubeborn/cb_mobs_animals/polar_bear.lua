-- Polar bear (spec cycle 4, 8b): lives on ice and snow. Neutral: it fights
-- whoever hits it, and the bears around join in; a grown bear with a cub
-- within 8 nodes attacks players who come within 6 (not in creative). One
-- bear in ten spawns as a cub. Drops raw fish; bears cannot be bred.
local S = cb_mobs_animals.S
local A = cb_mobs_animals
A.POLAR_BEAR = "cb_mobs_animals:polar_bear"
local CUB_RANGE, GUARD_RANGE = 8, 6

local function cub_near(self, pos)
	for _, obj in ipairs(core.get_objects_inside_radius(pos, CUB_RANGE)) do
		local e = obj:get_luaentity()
		if e and e.name == A.POLAR_BEAR and e.child and e ~= self then
			return true
		end
	end
	return false
end

-- The player a grown bear with a cub nearby goes for, if any.
function A.bear_guard(self, players)
	local pos = self.object:get_pos()
	if self.child or not pos or not cub_near(self, pos) then
		return nil
	end
	for _, p in ipairs(players or core.get_connected_players()) do
		local at = p:get_pos()
		if at and vector.distance(pos, at) <= GUARD_RANGE and not core.is_creative_enabled(p:get_player_name()) then
			return p
		end
	end
	return nil
end

local drops = {}
for _, d in ipairs({ { "ethereal:fish_cod", 2, }, { "ethereal:fish_salmon", 4, }, }) do
	if core.registered_items[d[1]] then
		drops[#drops + 1] = { name = d[1], chance = d[2], min = 0, max = 2, }
	end
end

mobs:register_mob(A.POLAR_BEAR, {
	type = "animal", passive = false, attack_players = false, group_attack = true, attack_type = "dogfight",
	damage = 6, reach = 2, hp_min = 30, hp_max = 30, armor = 100,
	collisionbox = { -0.7, 0, -0.7, 0.7, 1.4, 0.7, },
	visual = "mesh", mesh = "cb_mobs_animals_polar_bear.b3d", visual_size = { x = 3, y = 3, },
	textures = { { "cb_mobs_animals_polar_bear.png", }, },
	makes_footstep_sound = true, walk_velocity = 1, run_velocity = 2.5, jump = true, view_range = 12,
	water_damage = 0, lava_damage = 5, light_damage = 0, fall_damage = true, floats = 1,
	drops = drops,
	sounds = { random = "cb_mobs_animals_bear_random", attack = "cb_mobs_animals_bear_attack",
		damage = "cb_mobs_animals_bear_hurt", death = "cb_mobs_animals_bear_death",
		war_cry = "cb_mobs_animals_bear_growl", distance = 16, },
	animation = { speed_normal = 40, stand_start = 0, stand_end = 0, walk_start = 0, walk_end = 40,
		run_start = 0, run_end = 40, punch_start = 0, punch_end = 40, },
	do_custom = function(self, dtime)
		self._guard_t = (self._guard_t or 0) + dtime
		if self._guard_t >= 1 and self.state ~= "attack" then
			self._guard_t = 0
			local target = A.bear_guard(self)
			if target then
				self:do_attack(target)
			end
		end
	end,
	after_activate = function(self)
		if self._born == nil then
			self._born = true
			-- one in ten comes as a cub
			if math.random(10) == 1 then
				self.child, self.hornytimer = true, 0
				self.object:set_properties({
					visual_size = { x = self.base_size.x * 0.5, y = self.base_size.y * 0.5, },
					collisionbox = A.half(self.base_colbox), selectionbox = A.half(self.base_selbox),
				})
			end
		end
	end,
})
mobs:register_egg(A.POLAR_BEAR, S("Polar Bear"), "cb_mobs_animals_polar_bear.png", 1)
