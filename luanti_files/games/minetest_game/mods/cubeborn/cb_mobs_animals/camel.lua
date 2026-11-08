-- Camel (spec cycle 4, 8b): a tall desert mount that needs no taming. A
-- saddle makes whoever puts it on the owner and driver; anyone may then sit
-- behind as a passenger (right-click again to get off). It steps up 1.5
-- nodes and cannot jump: the driver's jump key is a dash (three times the
-- speed for 0.7 s, then 2.75 s to recover). Left alone it now and then sits
-- down to rest for 30-60 s. Cactus heals and breeds it.
local S = cb_mobs_animals.S
local A = cb_mobs_animals
A.CAMEL = "cb_mobs_animals:camel"
local SPEED, DASH_TIME, DASH_COOLDOWN = 4, 0.7, 2.75
local SEAT_BACK, SEAT_EYE = { x = 0, y = 19.5, z = -5, }, { x = 0, y = 12, z = -5, }
local PA = rawget(_G, "player_api")

local function seat(player, on)
	local name = player:get_player_name()
	if PA then
		PA.player_attached[name] = on or nil
		PA.set_animation(player, on and "sit" or "stand", 30)
	end
	player:set_eye_offset(on and SEAT_EYE or { x = 0, y = 0, z = 0, }, { x = 0, y = 0, z = 0, })
end

-- A second player sits behind the driver; their click again gets them off.
function A.camel_passenger(self, clicker)
	if self._passenger == clicker then
		A.camel_unseat(self)
		return true
	end
	if self._passenger or self.child or not self._saddle or self.driver == clicker or clicker:get_attach() then
		return false
	end
	self._passenger = clicker
	clicker:set_attach(self.object, "", SEAT_BACK, { x = 0, y = 0, z = 0, })
	seat(clicker, true)
	return true
end

function A.camel_unseat(self)
	local p = self._passenger
	self._passenger = nil
	if p and p:get_pos() then
		p:set_detach()
		seat(p, false)
		local pos = self.object:get_pos()
		if pos then
			p:set_pos(vector.offset(pos, 1, 0.5, -1))
		end
	end
end

function A.camel_drop_riders(self)
	A.camel_unseat(self)
	A.drop_saddle(self)
end

core.register_on_leaveplayer(function(player)
	for _, e in pairs(core.luaentities) do
		if e.name == A.CAMEL and e._passenger == player then
			A.camel_unseat(e)
		end
	end
end)

function A.camel_dash(self)
	if (self._dash_cd or 0) > 0 then
		return false
	end
	self._dash_t, self._dash_cd = DASH_TIME, DASH_COOLDOWN
	self:set_animation("dash", true)
	return true
end

local function sit(self, on)
	self._sitting = on or nil
	self._sit_t = on and 30 + math.random() * 30 or 120 + math.random() * 180
	self:set_animation(on and "sit" or "stand", true)
end

function A.camel_tick(self, dtime)
	if self._dash_cd then
		self._dash_cd = self._dash_cd > dtime and self._dash_cd - dtime or nil
	end
	if self._dash_t then
		self._dash_t = self._dash_t - dtime
		if self._dash_t <= 0 then
			self._dash_t = nil
		end
	end
	if self.driver then
		if self._sitting then
			sit(self, false)
		end
		local ctrl = self.driver:get_player_control()
		if ctrl.jump then
			A.camel_dash(self)
		end
		self.max_speed_forward = self._dash_t and SPEED * 3 or SPEED
		return not A.ride_step(self, dtime)
	end
	if self._passenger then
		return true
	end
	self._sit_t = (self._sit_t or 120 + math.random() * 180) - dtime
	if self._sit_t <= 0 then
		sit(self, not self._sitting)
	end
	if self._sitting then
		local v = self.object:get_velocity() or vector.zero()
		self.object:set_velocity({ x = 0, y = v.y, z = 0, })
		return false
	end
	return true
end

mobs:register_mob(A.CAMEL, {
	type = "animal", passive = true, hp_min = 32, hp_max = 32, armor = 100,
	collisionbox = { -0.85, 0, -0.85, 0.85, 2.375, 0.85, },
	visual = "mesh", mesh = "cb_mobs_animals_camel.b3d", visual_size = { x = 1, y = 1, },
	textures = { { "cb_mobs_animals_camel.png", }, },
	makes_footstep_sound = true, walk_velocity = 1, run_velocity = 2, jump = false, stepheight = 1.5,
	view_range = 8, water_damage = 0, lava_damage = 5, light_damage = 0, fall_damage = true,
	sounds = { random = "cb_mobs_animals_donkey_random", damage = "cb_mobs_animals_donkey_hurt",
		death = "cb_mobs_animals_donkey_death", distance = 12, },
	animation = { speed_normal = 25, stand_start = 0, stand_end = 0, walk_start = 1, walk_end = 41,
		run_start = 1, run_end = 41, run_speed = 40, sit_start = 42, sit_end = 42, dash_start = 43, dash_end = 63,
		dash_speed = 30, },
	follow = { "default:cactus", },
	do_custom = function(self, dtime)
		return A.camel_tick(self, dtime)
	end,
	on_rightclick = function(self, clicker)
		if not (clicker and clicker:is_player()) then
			return
		end
		if self._passenger == clicker then
			A.camel_unseat(self)
		elseif not (A.feed(self, clicker) or A.saddle_click(self, clicker) or A.mount_click(self, clicker)) then
			A.camel_passenger(self, clicker)
		end
	end,
	on_breed = function(self, other)
		return A.on_breed(self, other)
	end,
	on_die = function(self)
		A.camel_drop_riders(self)
	end,
	after_activate = function(self)
		A.setup(self)
		-- camels need no taming, and are kept like tamed animals
		self.tamed = true
		if self._sitting then
			self:set_animation("sit", true)
		end
	end,
})
A.CFG[A.CAMEL] = { _rider_at = { x = 0, y = 19.5, z = 4, }, _rider_eye = { x = 0, y = 12, z = 4, },
	_ride_speed = SPEED, _feed_count = 1, }
mobs:register_egg(A.CAMEL, S("Camel"), "cb_mobs_animals_camel.png", 1)
