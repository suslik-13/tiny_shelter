-- Parched and camel husk (plan 8f-3), after secret_terra's st_mobs ones
-- (their textures; the skeleton and camel models of cb_mobs_overworld and
-- cb_mobs_animals). The parched (16 HP) is the desert skeleton: its arrows
-- (mob projectiles only) hurt 2 and weaken players for 11 s, and it does not
-- burn by day. The camel husk (32 HP) comes at night in deserts carrying a
-- husk in front, who steers it at its target, and a parched behind. With its
-- riders gone it is a camel: a saddle lets its owner drive (dash with jump)
-- and a passenger sit behind; it cannot breed. Drops 2-3 rotten flesh.
local S = cb_mobs_trial.S
local T = cb_mobs_trial
T.PARCHED, T.WEAKNESS_ARROW = "cb_mobs_trial:parched", "cb_mobs_trial:weakness_arrow"
T.CAMEL_HUSK, T.CAMEL_HUSK_GROUP = "cb_mobs_trial:camel_husk", "cb_mobs_trial:camel_husk_group"
local HUSK = "cb_mobs_overworld:husk"
local FRONT, BACK = vector.new(0, 19.5, 4), vector.new(0, 19.5, -5)

-- An arrow (from) hits obj: 2 damage, players are weakened for 11 s.
function T.parched_hit(obj, from)
	obj:punch(from or obj, 1, { full_punch_interval = 1, damage_groups = { fleshy = 2, }, }, nil)
	if obj:is_player() then
		cb_core.effects.apply(obj, "weakness", 1, 11)
	end
end

mobs:register_arrow(T.WEAKNESS_ARROW, {
	visual = "sprite", visual_size = { x = 0.5, y = 0.5, },
	textures = { "cb_mobs_overworld_arrow.png^[colorize:#484d48:90", }, velocity = 18,
	hit_player = function(self, player)
		T.parched_hit(player, self.object)
	end,
	hit_mob = function(self, obj)
		T.parched_hit(obj, self.object)
	end,
	hit_node = function() end,
})

mobs:register_mob(T.PARCHED, {
	type = "monster", passive = false, attack_type = "shoot", arrow = T.WEAKNESS_ARROW,
	shoot_interval = 3.5, shoot_offset = 1.5, hp_min = 16, hp_max = 16, armor = 100,
	collisionbox = { -0.3, 0, -0.3, 0.3, 1.99, 0.3, },
	visual = "mesh", mesh = "cb_mobs_overworld_skeleton.b3d", visual_size = { x = 1, y = 1, },
	textures = { { "blank.png", "cb_mobs_trial_parched_overlay.png", "cb_mobs_trial_parched.png", }, },
	makes_footstep_sound = true, walk_velocity = 1, run_velocity = 1.6, jump = true, view_range = 16,
	light_damage = 0, water_damage = 0, lava_damage = 8,
	drops = core.registered_items["bonemeal:bone"] and { { name = "bonemeal:bone", chance = 1, min = 0, max = 2, }, } or {},
	sounds = { random = "cb_mobs_overworld_skeleton_random", damage = "cb_mobs_overworld_skeleton_hurt",
		death = "cb_mobs_overworld_skeleton_death", distance = 16, },
	animation = { speed_normal = 15, stand_start = 0, stand_end = 40, walk_start = 40, walk_end = 60, run_start = 40,
		run_end = 60, shoot_start = 40, shoot_end = 60, },
})
mobs:register_egg(T.PARCHED, S("Parched"), "cb_mobs_trial_parched.png", 1)

-- The husk riding in front, if any.
function T.husk_rider(self)
	for _, child in ipairs(self.object:get_children()) do
		local e = child:get_luaentity()
		if e and e.name == HUSK then
			return child, e
		end
	end
	return nil
end

local function riders_gone(self)
	for _, child in ipairs(self.object:get_children()) do
		local e = child:get_luaentity()
		if e and (e.name == HUSK or e.name == T.PARCHED) then
			return false
		end
	end
	return true
end

-- do_custom: the husk steers at its target; without mob riders, a camel.
function T.camel_husk_step(self, dtime)
	local _, husk = T.husk_rider(self)
	local A = rawget(_G, "cb_mobs_animals")
	if husk then
		local target = husk.attack
		local pos, tpos = self.object:get_pos(), target and target:get_pos()
		if tpos and vector.distance(pos, tpos) > 2 then
			local d = vector.direction(pos, tpos)
			self.object:set_yaw(core.dir_to_yaw(vector.new(d.x, 0, d.z)))
			local v = self.object:get_velocity()
			self.object:set_velocity(vector.new(d.x * self.run_velocity, v.y, d.z * self.run_velocity))
			self:set_animation("walk")
			return false
		end
		return true
	end
	if riders_gone(self) and A and A.camel_tick then
		return A.camel_tick(self, dtime)
	end
	return true
end

mobs:register_mob(T.CAMEL_HUSK, {
	type = "animal", passive = true, hp_min = 32, hp_max = 32, armor = 100,
	collisionbox = { -0.85, 0, -0.85, 0.85, 2.375, 0.85, },
	visual = "mesh", mesh = "cb_mobs_animals_camel.b3d", visual_size = { x = 1, y = 1, },
	textures = { { "cb_mobs_trial_camel_husk.png", }, },
	makes_footstep_sound = true, walk_velocity = 1, run_velocity = 2, jump = false, stepheight = 1.5,
	view_range = 8, water_damage = 0, lava_damage = 5, light_damage = 0, fall_damage = true,
	drops = { { name = "cb_items:rotten_flesh", chance = 1, min = 2, max = 3, }, },
	sounds = { random = "cb_mobs_animals_donkey_random", damage = "cb_mobs_animals_donkey_hurt",
		death = "cb_mobs_animals_donkey_death", distance = 12, },
	animation = { speed_normal = 25, stand_start = 0, stand_end = 0, walk_start = 1, walk_end = 41,
		run_start = 1, run_end = 41, run_speed = 40, sit_start = 42, sit_end = 42, dash_start = 43, dash_end = 63,
		dash_speed = 30, },
	do_custom = T.camel_husk_step,
	on_rightclick = function(self, clicker)
		local A = rawget(_G, "cb_mobs_animals")
		if not (clicker and clicker:is_player() and A and riders_gone(self)) then
			return
		end
		if self._passenger == clicker then
			A.camel_unseat(self)
		elseif not (A.saddle_click(self, clicker) or A.mount_click(self, clicker)) then
			A.camel_passenger(self, clicker)
		end
	end,
	on_die = function(self)
		local A = rawget(_G, "cb_mobs_animals")
		if A and A.camel_drop_riders then
			A.camel_drop_riders(self)
		end
	end,
	after_activate = function(self)
		local A = rawget(_G, "cb_mobs_animals")
		if A and A.setup then
			A.setup(self)
		end
	end,
})
mobs:register_egg(T.CAMEL_HUSK, S("Camel Husk"), "cb_mobs_trial_camel_husk.png", 1)
if rawget(_G, "cb_mobs_animals") and cb_mobs_animals.CFG then
	cb_mobs_animals.CFG[T.CAMEL_HUSK] = { _rider_at = FRONT, _rider_eye = { x = 0, y = 12, z = 4, }, _ride_speed = 4, }
end

-- A camel husk with its husk and parched riders at pos.
function T.spawn_camel_husk(pos)
	local camel = core.add_entity(pos, T.CAMEL_HUSK)
	if not camel then
		return nil
	end
	for _, r in ipairs({ { HUSK, FRONT, }, { T.PARCHED, BACK, }, }) do
		if core.registered_entities[r[1]] then
			local obj = core.add_entity(vector.offset(pos, 0, 2, 0), r[1])
			if obj then
				obj:set_attach(camel, "", r[2], vector.zero())
			end
		end
	end
	return camel
end

-- Spawning places this marker, which turns into the group.
core.register_entity(T.CAMEL_HUSK_GROUP, {
	initial_properties = { physical = false, pointable = false, static_save = false, visual = "sprite",
		textures = { "blank.png", }, },
	on_activate = function(self)
		local pos = self.object:get_pos()
		self.object:remove()
		T.spawn_camel_husk(pos)
	end,
})

if rawget(_G, "cb_spawning") then
	local SAND = { "group:sand", "default:desert_stone", }
	cb_spawning.register(T.PARCHED, { dims = { "overworld", }, category = "monster", dark = true, on = SAND,
		biomes = { "desert", }, weight = 50, group = { 1, 2, }, })
	cb_spawning.register(T.CAMEL_HUSK_GROUP, { dims = { "overworld", }, category = "monster", dark = true, on = SAND,
		biomes = { "desert", }, weight = 10, group = { 1, 1, }, })
end
