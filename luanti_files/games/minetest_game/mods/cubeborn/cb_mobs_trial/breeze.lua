-- Breeze (plan 8f-1), Bedrock behaviour after secret_terra's st_mobs breeze
-- (its model, texture and sounds): a trial chamber mob with 30 HP that keeps
-- 4-8 nodes from its target, leaps around it in high arcs and fires wind
-- charges (0.75 s wind-up): 1 damage and a burst that throws creatures back
-- and opens or shuts doors and trapdoors (not protected ones); no block
-- breaks. Projectiles of other mobs do not hurt it, falls neither. Killed by
-- a player it drops 1-2 breeze rods and 10 experience. Wind charges are its
-- own: players never get them.
local S = cb_mobs_trial.S
local T = cb_mobs_trial
T.BREEZE, T.WIND_CHARGE, T.BREEZE_ROD = "cb_mobs_trial:breeze", "cb_mobs_trial:wind_charge", "cb_mobs_trial:breeze_rod"
local B = {
	SHOOT_RANGE = 16, PRE_SHOOT = 0.75, SHOT_COOLDOWN = 0.7, JUMP_PREP = 0.5, JUMP_COOLDOWN = 0.5,
	GRAVITY = 10, MAX_JUMP = 16, CHARGE_SPEED = 14, NEAR = 4, FAR = 8, LOSE = 24, BURST = 3,
}
T.breeze = B
local JUMP_ANGLES = { 40, 55, 60, 75, 80, }

core.register_craftitem(T.BREEZE_ROD, { description = S("Breeze Rod"), inventory_image = "cb_mobs_trial_breeze_rod.png", })

local function is_breeze(obj)
	local e = obj and obj:get_luaentity()
	return e and e.name == T.BREEZE
end

-- The burst at pos: creatures within BURST are thrown away from it, doors
-- and trapdoors next to it swing (not in protected areas).
function T.burst(pos)
	local n = 0
	for _, obj in ipairs(core.get_objects_inside_radius(pos, B.BURST)) do
		local e = obj:get_luaentity()
		if obj:is_player() or (e and e._cmi_is_mob) then
			local at = obj:get_pos()
			local d = vector.subtract(at, pos)
			d.y = 0
			local dir = vector.length(d) > 0.01 and vector.normalize(d) or vector.new(0, 0, 0)
			obj:add_velocity(vector.new(dir.x * 8, 6, dir.z * 8))
			n = n + 1
		end
	end
	if rawget(_G, "doors") then
		for _, p in ipairs(core.find_nodes_in_area(vector.offset(pos, -1, -1, -1), vector.offset(pos, 1, 1, 1),
				{ "group:door", "group:trapdoor", })) do
			local door = doors.get(p)
			if door and not core.is_protected(p, "") then
				door:toggle(nil)
			end
		end
	end
	core.add_particlespawner({
		amount = 12, time = 0.2, minpos = vector.offset(pos, -0.6, 0.2, -0.6), maxpos = vector.offset(pos, 0.6, 0.6, 0.6),
		minvel = vector.new(-2, 0, -2), maxvel = vector.new(2, 2, 2), minexptime = 0.3, maxexptime = 0.6,
		minsize = 4, maxsize = 8, texture = "cb_mobs_trial_wind_burst.png",
	})
	core.sound_play("cb_mobs_trial_breeze_burst", { pos = pos, gain = 0.7, max_hear_distance = 24, }, true)
	return n
end

-- A charge hits obj: 1 damage, then the burst.
function T.charge_hit(charge, obj)
	local from = charge._shooter and charge._shooter:get_pos() and charge._shooter or charge.object
	obj:punch(from, 1, { full_punch_interval = 1, damage_groups = { fleshy = 1, }, }, nil)
	return T.burst(charge.object:get_pos())
end

core.register_entity(T.WIND_CHARGE, {
	initial_properties = {
		visual = "mesh", mesh = "cb_mobs_trial_wind_charge.obj", visual_size = { x = 1.4, y = 1, },
		textures = { "cb_mobs_trial_wind_charge_entity.png", }, physical = false, pointable = false,
		collisionbox = { -0.15, -0.15, -0.15, 0.15, 0.15, 0.15, }, static_save = false,
	},
	_life = 0,
	on_step = function(self, dtime)
		self._life = self._life + dtime
		local pos = self.object:get_pos()
		if self._life > 10 then
			self.object:remove()
			return
		end
		local node = core.get_node(vector.round(pos))
		local def = core.registered_nodes[node.name]
		if node.name ~= "air" and def and (def.walkable or (def.liquidtype or "none") ~= "none") then
			T.burst(pos)
			self.object:remove()
			return
		end
		for _, obj in ipairs(core.get_objects_inside_radius(pos, 1)) do
			local e = obj:get_luaentity()
			if obj ~= self._shooter and not is_breeze(obj) and (obj:is_player() or (e and e._cmi_is_mob)) then
				T.charge_hit(self, obj)
				self.object:remove()
				return
			end
		end
	end,
})

-- A wind charge from the breeze's head towards target_pos (feet + 0.5).
function T.shoot_charge(self, target_pos)
	local pos = vector.offset(self.object:get_pos(), 0, 1.6, 0)
	local dir = vector.direction(pos, vector.offset(target_pos, 0, 0.5, 0))
	dir = vector.rotate_around_axis(dir, vector.new(0, 1, 0), (math.random() * 2 - 1) * math.rad(1.5))
	local obj = core.add_entity(vector.add(pos, vector.multiply(dir, 0.6)), T.WIND_CHARGE)
	if obj then
		obj:get_luaentity()._shooter = self.object
		obj:set_velocity(vector.multiply(dir, B.CHARGE_SPEED))
	end
	core.sound_play("cb_mobs_trial_breeze_shoot", { object = self.object, gain = 0.8, max_hear_distance = 24, }, true)
	return obj
end

-- A ballistic leap to a spot 4-8 nodes from the target, or nil.
function T.pick_jump(from, target_pos)
	for _ = 1, 6 do
		local a, d = math.random() * 2 * math.pi, B.NEAR + math.random() * (B.FAR - B.NEAR)
		local land = vector.offset(target_pos, math.cos(a) * d, 0, math.sin(a) * d)
		local ground
		for dy = 4, -10, -1 do
			local p = vector.round(vector.offset(land, 0, dy, 0))
			local below = core.registered_nodes[core.get_node(vector.offset(p, 0, -1, 0)).name]
			local here = core.registered_nodes[core.get_node(p).name]
			if below and below.walkable and here and not here.walkable then
				ground = vector.offset(p, 0, -0.5, 0)
				break
			end
		end
		if ground then
			local dx, dz, dy = ground.x - from.x, ground.z - from.z, ground.y - from.y
			local h = math.max(math.sqrt(dx * dx + dz * dz), 0.01)
			for _, deg in ipairs(JUMP_ANGLES) do
				local th = math.rad(deg)
				local denom = 2 * math.cos(th) ^ 2 * (h * math.tan(th) - dy)
				if denom > 0 then
					local v = math.sqrt(B.GRAVITY * h * h / denom)
					if v <= B.MAX_JUMP then
						local hv = v * math.cos(th)
						return vector.new(dx / h * hv, v * math.sin(th), dz / h * hv)
					end
				end
			end
		end
	end
	return nil
end

local function face(self, pos)
	local from = self.object:get_pos()
	local dx, dz = pos.x - from.x, pos.z - from.z
	if dx ~= 0 or dz ~= 0 then
		self.object:set_yaw(core.dir_to_yaw(vector.new(dx, 0, dz)) - (self.rotate or 0))
	end
end

-- do_custom while it hunts: shooting, leaping and keeping its distance;
-- false keeps mobs_redo's own attack out.
function T.breeze_step(self, dtime, moveresult)
	self._shot_t = math.max(0, (self._shot_t or 1) - dtime)
	self._jump_t = math.max(0, (self._jump_t or 0) - dtime)
	local target = self.attack
	local pos, tpos = self.object:get_pos(), target and target:get_pos()
	if self.state ~= "attack" or not tpos then
		self._charging, self._jump_prep, self._airborne = nil, nil, nil
		return true
	end
	local dist = vector.distance(pos, tpos)
	if dist > B.LOSE then
		self:stop_attack()
		return true
	end
	local ground = moveresult and moveresult.touching_ground or self.object:get_velocity().y == 0
	face(self, tpos)
	if self._jump_prep then
		self._jump_prep = self._jump_prep - dtime
		if self._jump_prep <= 0 then
			self._jump_prep = nil
			local v = T.pick_jump(pos, tpos)
			if v then
				self.object:set_velocity(v)
				core.sound_play("cb_mobs_trial_breeze_jump", { object = self.object, gain = 0.8, max_hear_distance = 24, }, true)
				self._airborne = true
			end
			self._jump_t = B.JUMP_COOLDOWN
			self:set_animation("stand")
		end
		return false
	end
	if self._airborne then
		if ground and self.object:get_velocity().y <= 0 then
			self._airborne = nil
		end
		return false
	end
	local sight = self:line_of_sight(vector.offset(pos, 0, 1.5, 0), vector.offset(tpos, 0, 1, 0))
	if self._charging then
		self._charging = self._charging - dtime
		if self._charging <= 0 then
			self._charging = nil
			if sight and dist <= B.SHOOT_RANGE then
				T.shoot_charge(self, tpos)
				self._shots = (self._shots or 0) + 1
			end
			self._shot_t = B.SHOT_COOLDOWN
			self:set_animation("stand")
		end
		return false
	end
	if sight and dist <= B.SHOOT_RANGE and self._shot_t <= 0 then
		self:set_velocity(0)
		self._charging = B.PRE_SHOOT
		self:set_animation("shoot")
		return false
	end
	if ground and self._jump_t <= 0 and dist <= 20
			and ((self._shots or 0) >= 2 or dist < B.NEAR + 0.5 or not sight or math.random(8) == 1) then
		self._shots = 0
		self:set_velocity(0)
		self._jump_prep = B.JUMP_PREP
		self:set_animation("jump")
		return false
	end
	-- keep 4-8 nodes away
	if dist < B.NEAR then
		self.object:set_yaw(self.object:get_yaw() + math.pi)
		self:set_velocity(self.run_velocity)
		self:set_animation("walk")
	elseif dist > B.FAR then
		self:set_velocity(self.run_velocity)
		self:set_animation("walk")
	else
		self:set_velocity(0)
		self:set_animation("stand")
	end
	return false
end

mobs:register_mob(T.BREEZE, {
	type = "monster", passive = false, attack_type = "dogfight", attack_npcs = true, damage = 0, reach = 0,
	specific_attack = { "player", "cb_mobs_village:iron_golem", },
	hp_min = 30, hp_max = 30, armor = 100,
	collisionbox = { -0.3, 0, -0.3, 0.3, 1.77, 0.3, },
	visual = "mesh", mesh = "cb_mobs_trial_breeze.b3d", visual_size = { x = 1, y = 1, },
	textures = { { "cb_mobs_trial_breeze.png", }, },
	walk_velocity = 1.5, run_velocity = 3, jump_height = 1, stepheight = 1.1, view_range = 24, fall_speed = -10,
	water_damage = 0, lava_damage = 4, light_damage = 0, fall_damage = false, makes_footstep_sound = false,
	glow = 4, drops = {},
	sounds = { random = "cb_mobs_trial_breeze_idle", damage = "cb_mobs_trial_breeze_hurt",
		death = "cb_mobs_trial_breeze_death", distance = 16, },
	animation = { speed_normal = 30, stand_start = 0, stand_end = 40, walk_start = 0, walk_end = 40, walk_speed = 45,
		run_start = 0, run_end = 40, run_speed = 60, shoot_start = 41, shoot_end = 61, jump_start = 62, jump_end = 77, },
	do_custom = T.breeze_step,
	-- arrows and other mob projectiles bounce off
	do_punch = function(_, hitter)
		local e = hitter and hitter:get_luaentity()
		-- mobs_redo arrows carry hit_* callbacks
		if e and (e._is_arrow or e.hit_player or e.hit_mob) then
			return false
		end
	end,
	on_die = function(self, pos)
		local c = self.cause_of_death
		local killer = c and c.puncher
		if killer and killer.is_player and killer:is_player() then
			core.add_item(pos, T.BREEZE_ROD .. " " .. math.random(1, 2))
		end
	end,
})
mobs:register_egg(T.BREEZE, S("Breeze"), "cb_mobs_trial_breeze_rod.png", 1)

if rawget(_G, "cb_xp") then
	cb_xp.MOB_XP[T.BREEZE] = 10
end
