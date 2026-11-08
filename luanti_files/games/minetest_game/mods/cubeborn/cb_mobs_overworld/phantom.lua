-- Phantom (spec cycle 4, 8a): comes for players who have not slept for 3
-- game days (counted while in the overworld, reset in a bed or by death):
-- at night under the open sky, 1-3 at a time, at most 5 within 64. It
-- circles 12-16 above its target and swoops every 8-15 s; burns by day.
-- Cost: one pass over the players every 30 s.
local S = cb_mobs_overworld.S
local Z = cb_mobs_overworld
Z.PHANTOM, Z.INSOMNIA_DAYS, Z.PHANTOM_CAP = "cb_mobs_overworld:phantom", 3, 5
local KEY = "cb_awake"

function Z.awake(player)
	return tonumber(player:get_meta():get_string(KEY)) or 0
end

local function set_awake(player, t)
	player:get_meta():set_string(KEY, tostring(t))
end

local function day_seconds()
	local speed = tonumber(core.settings:get("time_speed")) or 72
	return speed > 0 and 86400 / speed or math.huge
end

function Z.insomnia_tick(player, dt)
	local beds_ = rawget(_G, "beds")
	if beds_ and beds_.player and beds_.player[player:get_player_name()] then
		set_awake(player, 0)
	else
		set_awake(player, Z.awake(player) + dt)
	end
end

core.register_on_dieplayer(function(player)
	set_awake(player, 0)
end)

-- Lying down resets it at once: when everyone sleeps the night is skipped
-- and beds throw players out within 2 s, before the 30 s pass sees them.
local beds_ = rawget(_G, "beds")
if beds_ and beds_.on_rightclick then
	Z.bed_orig = beds_.on_rightclick
	beds_.on_rightclick = function(pos, player, ...)
		local r = Z.bed_orig(pos, player, ...)
		if player and beds_.player and beds_.player[player:get_player_name()] then
			set_awake(player, 0)
		end
		return r
	end
end

local function count_near(pos)
	local n = 0
	for _, obj in ipairs(core.get_objects_inside_radius(pos, 64)) do
		local e = obj:get_luaentity()
		n = n + ((e and e.name == Z.PHANTOM) and 1 or 0)
	end
	return n
end

-- force: skip the insomnia roll (tests). Returns how many it placed.
function Z.phantoms_for(player, night, sky, force)
	local pos = player:get_pos()
	if not (night and sky) or cb_spawning.dim_at(pos) ~= "overworld" then
		return 0
	end
	if not force then
		local need = Z.INSOMNIA_DAYS * day_seconds()
		local awake = Z.awake(player)
		if awake < need or math.random() * awake < need then
			return 0
		end
	end
	if count_near(pos) >= Z.PHANTOM_CAP then
		return 0
	end
	local base = vector.offset(vector.round(pos), math.random(-10, 10), 20 + math.random(0, 14), math.random(-10, 10))
	local placed = 0
	for _ = 1, math.random(1, 3) do
		local p = vector.offset(base, math.random(-1, 1), 0, math.random(-1, 1))
		if core.get_node(p).name == "air" then
			local obj = core.add_entity(p, Z.PHANTOM)
			local e = obj and obj:get_luaentity()
			if e then
				e._target = player:get_player_name()
				placed = placed + 1
			end
		end
	end
	return placed
end

local function night()
	local t = core.get_timeofday()
	return t < 0.2 or t > 0.8
end

local timer = 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < 30 then
		return
	end
	local dt = timer
	timer = 0
	for _, player in ipairs(core.get_connected_players()) do
		local pos = player:get_pos()
		if pos and cb_spawning.dim_at(pos) == "overworld" then
			Z.insomnia_tick(player, dt)
			if math.random() < 0.5 then
				local head = vector.round(vector.offset(pos, 0, 1.6, 0))
				Z.phantoms_for(player, night(), (core.get_natural_light(head, 0.5) or 0) >= 15)
			end
		end
	end
end)

-- Flight: circle above the target, swoop at it now and then.
local function step(self, dtime)
	local target = self._target and core.get_player_by_name(self._target)
	local pos = self.object:get_pos()
	if not (target and pos) then
		return true -- plain mobs_redo flying AI
	end
	local tp = target:get_pos()
	self._t = (self._t or 0) + dtime
	self._flap = (self._flap or 0) - dtime
	if self._flap <= 0 then
		self._flap = 2.5 + math.random() * 1.5
		core.sound_play("cb_mobs_overworld_phantom_flap", { object = self.object, max_hear_distance = 16, gain = 0.5, },
			true)
	end
	self._swoop_at = self._swoop_at or (8 + math.random() * 7)
	local goal
	if self._t >= self._swoop_at then
		goal = vector.offset(tp, 0, 1, 0)
		if vector.distance(pos, goal) < 1.5 then
			target:punch(self.object, 1, { full_punch_interval = 1, damage_groups = { fleshy = self.damage, }, }, nil)
			self._t, self._swoop_at = 0, 8 + math.random() * 7
		end
	else
		local a = self._t * 0.6
		goal = vector.offset(tp, math.cos(a) * 10, 12 + (self._h or 2), math.sin(a) * 10)
	end
	local dir = vector.direction(pos, goal)
	local speed = self._t >= self._swoop_at and 9 or 5
	self.object:set_velocity(vector.multiply(dir, speed))
	self.object:set_yaw(core.dir_to_yaw(dir))
	return false
end

mobs:register_mob(Z.PHANTOM, {
	type = "monster", passive = false, attack_type = "dogfight", reach = 2, damage = 6,
	hp_min = 20, hp_max = 20, armor = 100, collisionbox = { -0.45, 0, -0.45, 0.45, 0.5, 0.45, },
	visual = "mesh", mesh = "cb_mobs_overworld_phantom.b3d", visual_size = { x = 1, y = 1, },
	textures = { { "cb_mobs_overworld_phantom.png", }, },
	fly = true, fly_in = { "air", }, fall_damage = false, walk_velocity = 3, run_velocity = 6, view_range = 64,
	light_damage = 4, water_damage = 0, lava_damage = 8,
	drops = { { name = "cb_items:phantom_membrane", chance = 1, min = 0, max = 1, }, },
	sounds = { random = "cb_mobs_overworld_phantom_idle", damage = "cb_mobs_overworld_phantom_hurt",
		death = "cb_mobs_overworld_phantom_death", attack = "cb_mobs_overworld_phantom_swoop", distance = 32, },
	animation = { speed_normal = 20, stand_start = 0, stand_end = 20, walk_start = 0, walk_end = 20, run_start = 21,
		run_end = 31, fly_start = 0, fly_end = 20, },
	do_custom = step,
	after_activate = function(self)
		self._h = self._h or math.random(0, 4)
	end,
})
mobs:register_egg(Z.PHANTOM, S("Phantom"), "default_obsidian_glass.png", 1)
