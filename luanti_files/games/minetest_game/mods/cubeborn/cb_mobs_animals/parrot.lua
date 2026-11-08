-- Parrot (spec cycle 4, 8b): a jungle bird in five colours, tamed with any
-- seeds (1 in 3); a cookie kills it. A tamed parrot whose owner comes within
-- 1.5 nodes sits on a free shoulder (two at most) and flies off when the
-- owner jumps, gets hurt, mounts something or leaves the game. Now and then
-- it mimics the voice of a monster within 20 nodes.
local S = cb_mobs_animals.S
local A = cb_mobs_animals
A.PARROT = "cb_mobs_animals:parrot"
local COOKIE = "farming:cookie"
-- feet on top of the shoulders (BACKLOG: they sat sunk into the body at 10.5)
local SHOULDERS = { { x = -3.75, y = 12.3, z = 0, }, { x = 3.75, y = 12.3, z = 0, }, }
local PERCH_RANGE, MIMIC_RANGE = 1.5, 20

local function take_one(clicker, stack)
	if not core.is_creative_enabled(clicker:get_player_name()) then
		stack:take_item()
		clicker:set_wielded_item(stack)
	end
end

local function used_shoulders(name)
	local used = {}
	local p = core.get_player_by_name(name)
	for _, child in ipairs(p and p:get_children() or {}) do
		local e = child:get_luaentity()
		if e and e.name == A.PARROT and e._shoulder then
			used[e._shoulder] = true
		end
	end
	return used
end

function A.perch(self, player)
	local name = player:get_player_name()
	if not (self.tamed and self.owner == name) or self._shoulder or player:get_attach() then
		return false
	end
	local used = used_shoulders(name)
	for i, at in ipairs(SHOULDERS) do
		if not used[i] then
			self._shoulder, self._perched_on, self._owner_hp = i, name, player:get_hp()
			self.object:set_velocity({ x = 0, y = 0, z = 0, })
			self.object:set_attach(player, "", at, { x = 0, y = 0, z = 0, }, true)
			self:set_animation("sit", true)
			return true
		end
	end
	return false
end

function A.unperch(self)
	local p = self._perched_on and core.get_player_by_name(self._perched_on)
	self._shoulder, self._perched_on, self._owner_hp = nil, nil, nil
	self._perch_cd = 3
	if self.object:get_attach() then
		self.object:set_detach()
	end
	if p then
		self.object:set_pos(vector.offset(p:get_pos(), 0, 2, 0))
	end
	self:set_animation("fly", true)
end

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	for _, e in pairs(core.luaentities) do
		if e.name == A.PARROT and e._perched_on == name then
			A.unperch(e)
		end
	end
end)

-- Plays the random sound of a monster nearby, higher; returns its name.
function A.parrot_mimic(self)
	local pos = self.object:get_pos()
	for _, obj in ipairs(core.get_objects_inside_radius(pos, MIMIC_RANGE)) do
		local e = obj:get_luaentity()
		local snd = e and e._cmi_is_mob and e.type == "monster" and e.sounds and e.sounds.random
		if snd then
			core.sound_play(snd, { pos = pos, gain = 0.8, pitch = 1.8, max_hear_distance = 16, }, true)
			return type(snd) == "table" and snd.name or snd
		end
	end
end

function A.cookie(self, clicker)
	local stack = clicker:get_wielded_item()
	if stack:get_name() ~= COOKIE then
		return false
	end
	take_one(clicker, stack)
	self.health = 0
	self:check_for_death({ type = "punch", puncher = clicker, })
	return true
end

local function seed_click(self, clicker)
	local stack = clicker:get_wielded_item()
	if core.get_item_group(stack:get_name(), "seed") == 0 then
		return false
	end
	if self.tamed then
		return mobs:feed_tame(self, clicker, 1, false, false)
	end
	take_one(clicker, stack)
	local pos = self.object:get_pos()
	if math.random(3) == 1 then
		self.tamed, self.owner, self.static_save = true, clicker:get_player_name(), true
		mobs:effect(vector.offset(pos, 0, 0.5, 0), 6, "mobs_heart_particle.png", 1, 2, 1, 0)
	else
		mobs:effect(vector.offset(pos, 0, 0.5, 0), 6, "mobs_tnt_smoke.png", 1, 2, 1, 0)
	end
	return true
end

-- From do_custom: on the shoulder (skip the AI) or looking for one.
function A.parrot_tick(self, dtime)
	self._mimic_t = (self._mimic_t or (20 + math.random() * 20)) - dtime
	if self._mimic_t <= 0 then
		self._mimic_t = 20 + math.random() * 20
		A.parrot_mimic(self)
	end
	self._look_t = (self._look_t or 0) + dtime
	if self._look_t < 0.5 then
		return not self._shoulder
	end
	self._look_t = 0
	self._perch_cd = self._perch_cd and self._perch_cd > 0.5 and self._perch_cd - 0.5 or nil
	if self._shoulder then
		local p = core.get_player_by_name(self._perched_on or "")
		if not p or self.object:get_attach() ~= p or p:get_player_control().jump or p:get_hp() < (self._owner_hp or 0)
			or p:get_attach() then
			A.unperch(self)
			return true
		end
		self._owner_hp = p:get_hp()
		return false
	end
	local p = self.tamed and not self._perch_cd and core.get_player_by_name(self.owner or "")
	if p and vector.distance(p:get_pos(), self.object:get_pos()) <= PERCH_RANGE then
		A.perch(self, p)
	end
	return not self._shoulder
end

mobs:register_mob(A.PARROT, {
	type = "animal", passive = true, hp_min = 6, hp_max = 6, armor = 100,
	collisionbox = { -0.25, 0, -0.25, 0.25, 0.9, 0.25, },
	visual = "mesh", mesh = "cb_mobs_animals_parrot.b3d", visual_size = { x = 3, y = 3, },
	textures = { { "cb_mobs_animals_parrot_blue.png", }, { "cb_mobs_animals_parrot_green.png", },
		{ "cb_mobs_animals_parrot_grey.png", }, { "cb_mobs_animals_parrot_red_blue.png", },
		{ "cb_mobs_animals_parrot_yellow_blue.png", }, },
	fly = true, fly_in = { "air", }, walk_velocity = 2, run_velocity = 3, jump = false, view_range = 8,
	water_damage = 0, lava_damage = 5, light_damage = 0, fall_damage = false, floats = 1,
	makes_footstep_sound = false,
	sounds = { random = "cb_mobs_animals_parrot_random", damage = "cb_mobs_animals_parrot_hurt",
		death = "cb_mobs_animals_parrot_death", distance = 16, },
	animation = { speed_normal = 50, stand_start = 0, stand_end = 0, walk_start = 130, walk_end = 150,
		run_start = 130, run_end = 150, fly_start = 130, fly_end = 150, sit_start = 160, sit_end = 160, },
	follow = { "group:seed", },
	do_custom = function(self, dtime)
		return A.parrot_tick(self, dtime)
	end,
	on_rightclick = function(self, clicker)
		if clicker and clicker:is_player() and not A.cookie(self, clicker) then
			seed_click(self, clicker)
		end
	end,
	after_activate = function(self)
		-- a parrot saved on a shoulder comes back loose
		if self._shoulder then
			self._shoulder, self._perched_on, self._owner_hp = nil, nil, nil
		end
	end,
})
mobs:register_egg(A.PARROT, S("Parrot"), "cb_mobs_animals_parrot_green.png", 1)
