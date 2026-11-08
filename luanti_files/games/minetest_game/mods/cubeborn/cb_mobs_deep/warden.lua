-- Warden (plan 8e-2), Bedrock behaviour after secret_terra's st_mobs warden
-- (model, texture and sounds: tools/boxmodel/mobs/warden.py, tools/sounds/warden_sfx.py). A shrieker at warning
-- level 4 calls it: it climbs out of the ground (7 s, nothing hurts it) and
-- digs back down after 60 s without anything disturbing it. It is blind and
-- hunts by anger (0-150) kept per suspect: +35 for each step it hears
-- (players walking without sneaking, mobs moving, within 16), +35 when it
-- sniffs someone out (every 5-10 s, the nearest within 24, if within 6
-- across), +100 when hit; -1 a second. At 80 it roars (4.2 s) and hunts the
-- angriest one; a weaker disturbance only makes it walk to the spot. Who it
-- cannot reach in melee gets the sonic boom: 1.7 s charge, 10 damage past
-- any armour, range 15 (20 up or down), 2 s cooldown. Every 6 s players
-- within 20 get darkness; its heartbeat quickens with anger. 500 HP, 30 a
-- hit, no fire, lava or knockback. Drops a catalyst (and, as a monster, 5
-- experience). Like any mobs_redo monster it is not saved with the world.
local S = cb_mobs_deep.S
local D = cb_mobs_deep
local W = {
	NAME = "cb_mobs_deep:warden",
	MAX_ANGER = 150, ANGRY = 80, HEAR_ANGER = 35, SNIFF_ANGER = 35, HURT_ANGER = 100,
	HEAR_RANGE = 16, HEAR_EVERY = 1, HEAR_COOLDOWN = 2, MOVE = 0.3,
	EMERGE = 7, DIG = 5.5, IDLE = 60, ROAR = 4.2, SNIFF = 4.16, SNIFF_RANGE = 24, SNIFF_NEAR = 6,
	SONIC_CHARGE = 1.7, SONIC_TOTAL = 3, SONIC_COOLDOWN = 2, SONIC_H = 15, SONIC_V = 20, SONIC_DAMAGE = 10,
	STUCK = 1.5, DARKNESS_RANGE = 20, DARKNESS_EVERY = 6, DARKNESS_TIME = 13, NEAR = 48, INVESTIGATE = 10,
}
D.warden = W

local function sound(self, name, gain, dist)
	core.sound_play(name, { object = self.object, gain = gain, max_hear_distance = dist, }, true)
end

-- Anger and what it heard live outside the entity: mobs_redo saves every
-- field and cannot serialize objects.
local live = setmetatable({}, { __mode = "k", })
local function mind(self)
	local m = live[self]
	if not m then
		m = { anger = {}, seen = {}, heard = {}, }
		live[self] = m
	end
	return m
end

-- Players are kept by name, anything else by object.
local function key(obj)
	return obj:is_player() and obj:get_player_name() or obj
end

local function suspect(obj)
	if not (obj and obj:get_pos()) then
		return false
	end
	if obj:is_player() then
		return obj:get_hp() > 0 and not core.is_creative_enabled(obj:get_player_name())
	end
	local e = obj:get_luaentity()
	return e and e._cmi_is_mob and e.name ~= W.NAME and (e.health or 0) > 0 or false
end

local function across(a, b)
	return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

function W.anger(self, obj)
	local a = mind(self).anger[key(obj)]
	return a and a.level or 0
end

function W.add_anger(self, obj, n)
	if not suspect(obj) then
		return false
	end
	local anger, k = mind(self).anger, key(obj)
	local a = anger[k] or { level = 0, }
	local before = a.level
	a.level, a.obj = math.min(W.MAX_ANGER, a.level + n), obj
	anger[k], self._idle = a, 0
	if a.level > before then
		sound(self, a.level >= 40 and "cb_mobs_deep_warden_angry" or "cb_mobs_deep_warden_listening", 1, 32)
	end
	return true
end

function W.angriest(self)
	local best, level = nil, 0
	for k, a in pairs(mind(self).anger) do
		local obj = type(k) == "string" and core.get_player_by_name(k) or a.obj
		a.obj = obj
		if suspect(obj) and a.level > level then
			best, level = obj, a.level
		end
	end
	return best, level
end

-- Steps it hears: suspects within HEAR_RANGE that moved since the last
-- check (players only when not sneaking), each at most once per cooldown.
function W.hear(self, now)
	local pos = self.object:get_pos()
	local m, n = mind(self), 0
	for _, obj in ipairs(core.get_objects_inside_radius(pos, W.HEAR_RANGE)) do
		if obj ~= self.object and suspect(obj) then
			local k, at = key(obj), obj:get_pos()
			local prev = m.seen[k]
			m.seen[k] = at
			local quiet = obj:is_player() and obj:get_player_control().sneak
			if prev and not quiet and vector.distance(prev, at) >= W.MOVE
					and now - (m.heard[k] or -100) >= W.HEAR_COOLDOWN then
				m.heard[k] = now
				W.add_anger(self, obj, W.HEAR_ANGER)
				if not self._target then
					self._suspicious = vector.copy(at)
				end
				n = n + 1
			end
		end
	end
	return n
end

-- The end of a sniff: the nearest suspect within SNIFF_RANGE.
function W.sniff(self)
	local pos = self.object:get_pos()
	local best, bd
	for _, obj in ipairs(core.get_objects_inside_radius(pos, W.SNIFF_RANGE)) do
		if obj ~= self.object and suspect(obj) then
			local d = vector.distance(obj:get_pos(), pos)
			if not bd or d < bd then
				best, bd = obj, d
			end
		end
	end
	if not best then
		return nil
	end
	local bp = best:get_pos()
	if across(bp, pos) <= W.SNIFF_NEAR and math.abs(bp.y - pos.y) <= W.SONIC_V then
		W.add_anger(self, best, W.SNIFF_ANGER)
	else
		self._suspicious = vector.copy(bp)
	end
	return best
end

-- 10 damage past armour (players lose hp directly) and a strong push.
function W.sonic_boom(self, target)
	local from = vector.offset(self.object:get_pos(), 0, 1.6, 0)
	local to = vector.offset(target:get_pos(), 0, 1, 0)
	local dir = vector.direction(from, to)
	for i = 1, math.floor(vector.distance(from, to)) do
		core.add_particle({ pos = vector.add(from, vector.multiply(dir, i)), expirationtime = 0.5, size = 6,
			texture = "[fill:4x4:#2fd8e8", glow = 14, })
	end
	core.sound_play("cb_mobs_deep_warden_sonic_boom", { pos = from, gain = 2, max_hear_distance = 48, }, true)
	if target:is_player() then
		target:set_hp(math.max(0, target:get_hp() - W.SONIC_DAMAGE), { type = "set_hp", cause = "cb_warden_sonic", })
	else
		target:punch(self.object, 1, { full_punch_interval = 1, damage_groups = { fleshy = W.SONIC_DAMAGE, }, }, dir)
	end
	target:add_velocity(vector.new(dir.x * 20, 5, dir.z * 20))
end

local function face(self, pos)
	local from = self.object:get_pos()
	local dx, dz = pos.x - from.x, pos.z - from.z
	if dx ~= 0 or dz ~= 0 then
		self.object:set_yaw(core.dir_to_yaw(vector.new(dx, 0, dz)) - (self.rotate or 0))
	end
end

local function halt(self, anim)
	self:set_velocity(0)
	self.object:set_velocity(vector.new(0, self.object:get_velocity().y, 0))
	if anim then
		self:set_animation(anim)
	end
end

local function start(self, what, anim, sname, t)
	self[what] = t
	halt(self, anim)
	if sname then
		sound(self, sname, 1.2, 32)
	end
end

-- do_custom: false keeps mobs_redo out while it emerges, digs, roars, sniffs
-- or charges a sonic boom.
function W.step(self, dtime)
	local pos = self.object:get_pos()
	self._sonic_cd = math.max(0, (self._sonic_cd or 0) - dtime)
	if self._emerging then
		self._emerging = self._emerging - dtime
		halt(self, "emerge")
		if self._emerging <= 0 then
			self._emerging = nil
			self.object:set_properties({ pointable = true, })
			self:set_animation("stand", true)
		end
		return false
	end
	if self._digging then
		self._digging = self._digging - dtime
		halt(self, "dig")
		if self._digging <= 0 then
			self.object:remove()
		end
		return false
	end
	self._t = (self._t or 0) + dtime
	if self._t >= W.HEAR_EVERY then
		self._t = 0
		local m = mind(self)
		for k, a in pairs(m.anger) do
			a.level = a.level - 1
			if a.level <= 0 or type(k) ~= "string" and not suspect(a.obj) then
				m.anger[k], m.seen[k], m.heard[k] = nil, nil, nil
			end
		end
		W.hear(self, core.get_gametime())
	end
	self._dark = (self._dark or 0) - dtime
	if self._dark <= 0 then
		self._dark = W.DARKNESS_EVERY
		for _, p in ipairs(core.get_connected_players()) do
			if vector.distance(p:get_pos(), pos) <= W.DARKNESS_RANGE and not core.is_creative_enabled(p:get_player_name()) then
				cb_core.effects.apply(p, "darkness", 1, W.DARKNESS_TIME)
			end
		end
	end
	local target, level = W.angriest(self)
	self._beat = (self._beat or 0) - dtime
	if self._beat <= 0 then
		self._beat = 2 - math.min(1.5, level / W.ANGRY * 1.5)
		sound(self, "cb_mobs_deep_warden_heartbeat", 0.8, 24)
	end

	if self._roaring then
		self._roaring = self._roaring - dtime
		halt(self)
		if self._roaring <= 0 then
			self._roaring = nil
			if self._target and suspect(self._target) then
				self:do_attack(self._target)
			end
		end
		return false
	end
	if self._sonic then
		self._sonic = self._sonic + dtime
		halt(self)
		local t = self._sonic_target
		if t and t:get_pos() then
			face(self, t:get_pos())
		end
		if not self._sonic_fired and self._sonic >= W.SONIC_CHARGE then
			self._sonic_fired = true
			if suspect(t) then
				W.sonic_boom(self, t)
			end
		end
		if self._sonic >= W.SONIC_TOTAL then
			self._sonic, self._sonic_fired, self._sonic_target = nil, nil, nil
			self._sonic_cd = W.SONIC_COOLDOWN
		end
		return false
	end
	if self._sniffing then
		self._sniffing = self._sniffing - dtime
		halt(self)
		if self._sniffing <= 0 then
			self._sniffing = nil
			W.sniff(self)
		end
		return false
	end

	if target and level >= W.ANGRY then
		if self._target ~= target then
			self._target, self._suspicious, self._stuck = target, nil, 0
			start(self, "_roaring", "roar", "cb_mobs_deep_warden_roar", W.ROAR)
			return false
		end
		if self.attack ~= target then
			self:do_attack(target)
		end
	elseif self._target or self.state == "attack" then
		-- also whoever mobs_redo went for without making it angry
		self._target = nil
		self:stop_attack()
	end

	if self._target then
		self._idle = 0
		local tpos = self._target:get_pos()
		local dist = vector.distance(pos, tpos)
		if dist <= (self.reach or 3) + 0.5 then
			self._stuck, self._last_dist = 0, dist
			return true
		end
		-- not getting closer, or far: it cannot reach them
		if dist >= (self._last_dist or dist) - 0.05 or dist > 4 then
			self._stuck = (self._stuck or 0) + dtime
		else
			self._stuck = math.max(0, (self._stuck or 0) - dtime)
		end
		self._last_dist = dist
		if self._sonic_cd <= 0 and self._stuck >= W.STUCK and across(pos, tpos) <= W.SONIC_H
				and math.abs(tpos.y - pos.y) <= W.SONIC_V then
			self._sonic_target = target
			start(self, "_sonic", "sonic", "cb_mobs_deep_warden_sonic_charge", 0)
			return false
		end
		return true
	end

	if self._suspicious then
		self._looking = (self._looking or 0) + dtime
		if vector.distance(pos, self._suspicious) < 2 or self._looking > W.INVESTIGATE then
			self._suspicious, self._looking = nil, nil
		else
			face(self, self._suspicious)
			self:set_velocity(self.walk_velocity)
			self:set_animation("walk")
			return false
		end
	end

	self._sniff_cd = (self._sniff_cd or 5) - dtime
	if self._sniff_cd <= 0 then
		self._sniff_cd = 5 + math.random() * 5
		start(self, "_sniffing", "sniff", "cb_mobs_deep_warden_sniff", W.SNIFF)
		return false
	end
	self._idle = (self._idle or 0) + dtime
	if self._idle >= W.IDLE and (self.nametag or "") == "" then
		self.object:set_properties({ pointable = false, })
		start(self, "_digging", "dig", "cb_mobs_deep_warden_dig", W.DIG)
		return false
	end
	return true
end

mobs:register_mob(W.NAME, {
	type = "monster", passive = false, attack_type = "dogfight", attack_animals = true, attack_npcs = true,
	damage = 30, reach = 3, hp_min = 500, hp_max = 500, armor = 100, knock_back = false,
	collisionbox = { -0.45, 0, -0.45, 0.45, 2.9, 0.45, },
	visual = "mesh", mesh = "cb_mobs_deep_warden.b3d", visual_size = { x = 1, y = 1, },
	textures = { { "cb_mobs_deep_warden.png", }, },
	-- it hears: invisibility does not hide a player from it
	ignore_invisibility = true,
	walk_velocity = 1.5, run_velocity = 3, jump_height = 1.1, stepheight = 1.1, view_range = 24,
	water_damage = 0, lava_damage = 0, fire_damage = 0, light_damage = 0, fall_damage = false,
	suffocation = 0, makes_footstep_sound = false, pathfinding = 1,
	drops = { { name = D.CATALYST, chance = 1, min = 1, max = 1, }, },
	sounds = { random = "cb_mobs_deep_warden_ambient", attack = "cb_mobs_deep_warden_attack",
		damage = "cb_mobs_deep_warden_hurt", death = "cb_mobs_deep_warden_death", distance = 32, },
	animation = {
		speed_normal = 30, stand_start = 0, stand_end = 40, stand_speed = 20,
		walk_start = 41, walk_end = 65, walk_speed = 25, run_start = 41, run_end = 65, run_speed = 35,
		punch_start = 66, punch_end = 81, roar_start = 82, roar_end = 207, sniff_start = 208, sniff_end = 332,
		sonic_start = 333, sonic_end = 384, emerge_start = 385, emerge_end = 595, emerge_loop = false,
		dig_start = 596, dig_end = 761, dig_loop = false,
	},
	do_custom = function(self, dtime)
		local r = W.step(self, dtime)
		if r ~= false and self.object:get_pos() then
			self._step_t = (self._step_t or 0) + dtime
			local v = self.object:get_velocity()
			if self._step_t >= 0.6 and v.x * v.x + v.z * v.z > 0.5 then
				self._step_t = 0
				sound(self, "cb_mobs_deep_warden_step", 0.8, 16)
			end
		end
		return r
	end,
	do_punch = function(self, hitter)
		if self._emerging or self._digging then
			return false
		end
		W.add_anger(self, hitter, W.HURT_ANGER)
		-- mobs_redo would go for the hitter at once; the warden roars first
		return true
	end,
	after_activate = function(self)
		-- blind: targets come only from anger (W.step)
		self.general_attack = function() end
		if self._emerging then
			self.object:set_properties({ pointable = false, })
			self:set_animation("emerge", true)
		end
	end,
})
mobs:register_egg(W.NAME, S("Warden"), "cb_mobs_deep_sculk.png", 1)

-- A warden within NEAR of pos (shriekers then do not call another one).
function D.warden_near(pos)
	for _, obj in ipairs(core.get_objects_inside_radius(pos, W.NEAR)) do
		local e = obj:get_luaentity()
		if e and e.name == W.NAME then
			return true
		end
	end
	return false
end

-- Where it climbs out: a spot within 5 of pos with ground under it and
-- three nodes of air above, else pos itself.
function W.spot(pos)
	pos = vector.round(pos)
	local spots = {}
	for x = -5, 5 do
		for z = -5, 5 do
			for y = -3, 3 do
				local p = vector.offset(pos, x, y, z)
				local under = core.registered_nodes[core.get_node(vector.offset(p, 0, -1, 0)).name]
				if under and under.walkable and core.get_node(p).name == "air"
						and core.get_node(vector.offset(p, 0, 1, 0)).name == "air"
						and core.get_node(vector.offset(p, 0, 2, 0)).name == "air" then
					spots[#spots + 1] = p
				end
			end
		end
	end
	return #spots > 0 and spots[math.random(#spots)] or vector.offset(pos, 0, 1, 0)
end

-- The shriekers' hook: a warden emerges near pos, already angry at the
-- player who woke it.
function D.summon_warden(pos, name)
	local at = W.spot(pos)
	local obj = core.add_entity(vector.offset(at, 0, -0.5, 0), W.NAME)
	local self = obj and obj:get_luaentity()
	if not self then
		return nil
	end
	self._emerging = W.EMERGE
	obj:set_properties({ pointable = false, })
	self:set_animation("emerge", true)
	sound(self, "cb_mobs_deep_warden_dig", 1.2, 32)
	local p = name and core.get_player_by_name(name)
	if p then
		W.add_anger(self, p, W.HEAR_ANGER)
	end
	return obj
end
