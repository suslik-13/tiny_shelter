-- Dolphin (spec cycle 4, 8c): playful pods in warm seas. Players swimming
-- within 8 nodes get Dolphin's Grace (faster swimming). Fed raw fish, a
-- dolphin leads for 30 s towards the nearest structure within 256 nodes
-- (Minecraft's shipwrecks and buried treasure do not exist here). It
-- breathes air: under water it comes up when its 4 minutes run short. Hit,
-- the pod fights back.
local S = cb_mobs_water.S
local W = cb_mobs_water
W.DOLPHIN = "cb_mobs_water:dolphin"
local GRACE_RANGE, LEAD_RANGE, LEAD_TIME, AIR = 8, 256, 30, 240

-- Dolphin's Grace for the swimmers near it (or `players`); how many.
function W.dolphin_grace(self, players)
	local E = cb_core.effects
	local pos, n = self.object:get_pos(), 0
	if not (E and E.defs.dolphins_grace and pos) then
		return 0
	end
	for _, p in ipairs(players or core.get_connected_players()) do
		local at = p:get_pos()
		if at and vector.distance(pos, at) <= GRACE_RANGE and (players or W.in_water(vector.offset(at, 0, 0.5, 0))) then
			E.apply(p, "dolphins_grace", 1, 5)
			n = n + 1
		end
	end
	return n
end

-- The centre of the nearest ready structure within reach, or nil.
function W.dolphin_lead_target(pos)
	local CS = rawget(_G, "cb_structures")
	local best, bd
	for _, rec in pairs(CS and CS.registry.all() or {}) do
		if rec.state == "ready" and rec.minp and rec.maxp then
			local c = vector.round(vector.divide(vector.add(rec.minp, rec.maxp), 2))
			local d = vector.distance(pos, c)
			if d <= LEAD_RANGE and (not bd or d < bd) then
				best, bd = c, d
			end
		end
	end
	return best
end

function W.dolphin_feed(self, clicker)
	local stack = clicker:get_wielded_item()
	if core.get_item_group(stack:get_name(), "food_fish_raw") == 0 then
		return false
	end
	if not core.is_creative_enabled(clicker:get_player_name()) then
		stack:take_item()
		clicker:set_wielded_item(stack)
	end
	self._lead, self._lead_t = W.dolphin_lead_target(self.object:get_pos()), LEAD_TIME
	self:mob_sound(self.sounds.random)
	return true
end

local function swim_to(self, pos, speed)
	local at = self.object:get_pos()
	local d = vector.subtract(pos, at)
	local len = vector.length(d)
	if len > 0.5 then
		self:yaw_to_pos(pos)
		self.object:set_velocity(vector.multiply(d, speed / len))
	end
	return len
end

function W.dolphin_tick(self, dtime)
	local pos = self.object:get_pos()
	local under = W.in_water(vector.offset(pos, 0, 0.8, 0))
	self._air = under and (self._air or AIR) - dtime or AIR
	if self._air < 30 then
		local v = self.object:get_velocity() or vector.zero()
		self.object:set_velocity({ x = v.x, y = 3, z = v.z, })
		if self._air <= 0 then
			self._air = 0
			self._choke_t = (self._choke_t or 0) + dtime
			if self._choke_t >= 1 then
				self._choke_t = 0
				W.choke(self)
			end
		end
		return false
	end
	self._grace_t = (self._grace_t or 0) + dtime
	if self._grace_t >= 1 then
		self._grace_t = 0
		W.dolphin_grace(self)
	end
	if self._lead then
		self._lead_t = self._lead_t - dtime
		if self._lead_t <= 0 or swim_to(self, self._lead, 4) < 3 then
			self._lead, self._lead_t = nil, nil
		end
		return false
	end
	return true
end

mobs:register_mob(W.DOLPHIN, {
	type = "animal", passive = false, attack_players = false, group_attack = true, attack_type = "dogfight",
	damage = 3, reach = 1.5, hp_min = 10, hp_max = 10, armor = 100, rotate = 180,
	collisionbox = { -0.45, 0, -0.45, 0.45, 0.6, 0.45, },
	visual = "mesh", mesh = "cb_mobs_water_dolphin.b3d", visual_size = { x = 3, y = 3, },
	textures = { { "cb_mobs_water_dolphin.png", }, },
	fly = true, fly_in = W.WATER, walk_velocity = 2, run_velocity = 4, jump = false, view_range = 10,
	water_damage = 0, lava_damage = 5, light_damage = 0, fall_damage = false, makes_footstep_sound = false,
	drops = core.registered_items["ethereal:fish_cod"] and { { name = "ethereal:fish_cod", chance = 1, min = 0, max = 1, }, }
		or {},
	sounds = { random = "cb_mobs_water_dolphin_whistle", attack = "cb_mobs_water_dolphin_attack",
		damage = "cb_mobs_water_dolphin_hurt", death = "cb_mobs_water_dolphin_dying", distance = 16, },
	animation = { speed_normal = 20, stand_start = 0, stand_end = 15, walk_start = 0, walk_end = 15,
		run_start = 0, run_end = 15, fly_start = 0, fly_end = 15, punch_start = 0, punch_end = 15, },
	do_custom = function(self, dtime)
		return W.dolphin_tick(self, dtime)
	end,
	on_flop = W.choke,
	on_rightclick = function(self, clicker)
		if clicker and clicker:is_player() then
			W.dolphin_feed(self, clicker)
		end
	end,
})
mobs:register_egg(W.DOLPHIN, S("Dolphin"), "cb_mobs_water_dolphin.png", 1)
