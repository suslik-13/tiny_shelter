-- Fox (spec cycle 4, 8b): sleeps by day (wakes when hit or when a player
-- comes closer than 3 nodes without sneaking), keeps away from players and
-- hunts chickens at night. It picks up one item lying within 2 nodes and
-- carries it in its mouth; the item drops when it dies. Berries breed it.
-- Snowy biomes have white foxes.
local S = cb_mobs_animals.S
local A = cb_mobs_animals
A.FOX = "cb_mobs_animals:fox"
local WAKE_RANGE, PICK_RANGE, AWAKE_TIME = 3, 2, 60

function A.fox_sleepy(tod)
	return tod > 0.25 and tod < 0.75
end

-- One item from the nearest dropped stack within reach goes in the mouth.
function A.fox_pickup(self)
	local pos = self.object:get_pos()
	if self._held or not pos then
		return false
	end
	local best, bd
	for _, obj in ipairs(core.get_objects_inside_radius(pos, PICK_RANGE)) do
		local e = obj:get_luaentity()
		if e and e.name == "__builtin:item" and e.itemstring ~= "" then
			local d = vector.distance(pos, obj:get_pos())
			if not bd or d < bd then
				best, bd = e, d
			end
		end
	end
	if not best then
		return false
	end
	local stack = ItemStack(best.itemstring)
	local one = stack:take_item(1)
	if stack:is_empty() then
		best.object:remove()
	else
		best:set_item(stack)
	end
	A.hold(self, one:to_string())
	return true
end

local function woken(self)
	local pos = self.object:get_pos()
	for _, obj in ipairs(core.get_objects_inside_radius(pos, WAKE_RANGE)) do
		if obj:is_player() and not obj:get_player_control().sneak then
			return true
		end
	end
	return false
end

local function sleep(self, on)
	self._sleep = on or nil
	if on then
		self.state, self.attack, self.following = "stand", nil, nil
		self:set_velocity(0)
		self:set_animation("sleep", true)
	else
		self:set_animation("stand", true)
	end
end

-- From do_custom: sleeping by day, picking things up.
function A.fox_tick(self, dtime)
	self._pick_t = (self._pick_t or 0) + dtime
	if self._pick_t >= 2 then
		self._pick_t = 0
		if not self._sleep then
			A.fox_pickup(self)
		end
		self._awake = self._awake and self._awake > 2 and self._awake - 2 or nil
		local sleepy = A.fox_sleepy(core.get_timeofday()) and not self._awake and self.state ~= "attack"
		if self._sleep and (not sleepy or woken(self)) then
			sleep(self, false)
			self._awake = sleepy and AWAKE_TIME or nil
		elseif sleepy and not self._sleep then
			sleep(self, true)
		end
	end
	if self._sleep then
		local v = self.object:get_velocity() or vector.zero()
		self.object:set_velocity({ x = 0, y = v.y, z = 0, })
		return false
	end
	return true
end

mobs:register_mob(A.FOX, {
	type = "animal", passive = false, attack_players = false, attack_animals = true,
	specific_attack = { "mobs_animal:chicken", }, runaway_from = { "player", }, attack_type = "dogfight",
	damage = 2, reach = 1.5, hp_min = 10, hp_max = 10, armor = 100,
	collisionbox = { -0.3, 0, -0.3, 0.3, 0.7, 0.3, },
	visual = "mesh", mesh = "cb_mobs_animals_fox.b3d", visual_size = { x = 1, y = 1, },
	textures = { { "cb_mobs_animals_fox.png", }, },
	makes_footstep_sound = true, walk_velocity = 1.5, run_velocity = 3, jump = true, view_range = 10,
	water_damage = 0, lava_damage = 5, light_damage = 0, fall_damage = true, floats = 1,
	sounds = { random = "cb_mobs_animals_fox_idle", damage = "cb_mobs_animals_fox_hurt",
		death = "cb_mobs_animals_fox_death", distance = 12, },
	animation = { speed_normal = 50, stand_start = 0, stand_end = 0, walk_start = 1, walk_end = 41,
		run_start = 1, run_end = 41, run_speed = 80, punch_start = 1, punch_end = 41, sit_start = 42, sit_end = 42,
		sleep_start = 43, sleep_end = 43, },
	follow = { "farming:blueberries", "default:blueberries", },
	do_custom = function(self, dtime)
		return A.fox_tick(self, dtime)
	end,
	do_punch = function(self)
		if self._sleep then
			sleep(self, false)
		end
		self._awake = AWAKE_TIME
	end,
	on_rightclick = function(self, clicker)
		if clicker and clicker:is_player() then
			mobs:feed_tame(self, clicker, 4, true, false)
		end
	end,
	on_breed = function(self, other)
		return A.on_breed(self, other, function(young)
			young._snow = (math.random(2) == 1 and self or other)._snow
			young.base_texture = { young._snow and "cb_mobs_animals_fox_snow.png" or "cb_mobs_animals_fox.png", }
			young.object:set_properties({ textures = young.base_texture, })
		end)
	end,
	on_die = function(self)
		A.drop_held(self)
	end,
	after_activate = function(self)
		if self._snow == nil then
			local pos = self.object:get_pos()
			local b = pos and cb_spawning.biome_at(pos) or ""
			self._snow = b:find("snow", 1, true) ~= nil or b:find("ice", 1, true) ~= nil or b:find("tundra", 1, true) ~= nil
		end
		self.base_texture = { self._snow and "cb_mobs_animals_fox_snow.png" or "cb_mobs_animals_fox.png", }
		self.object:set_properties({ textures = self.base_texture, })
		A.show_held(self)
		if self._sleep then
			self:set_animation("sleep", true)
		end
	end,
})
mobs:register_egg(A.FOX, S("Fox"), "cb_mobs_animals_fox.png", 1)
