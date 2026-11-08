-- Armadillo, scutes and wolf armour (spec cycle 4, 8b): an armadillo rolls
-- up when a sprinting or riding player, its attacker or an undead mob comes
-- within 4 nodes, or when hit; rolled up it stays put and takes half damage
-- minus one, and unrolls after 3-6 quiet seconds. Adults shed a scute every
-- 5-10 minutes; six scutes make wolf armour. The servers have no spider
-- eye, Bedrock's armadillo food, so armadillos do not breed.
local S = cb_mobs_animals.S
local A = cb_mobs_animals
A.ARMADILLO = "cb_mobs_animals:armadillo"
A.SCUTE, A.WOLF_ARMOR, A.ARMOR_LIFE = "cb_mobs_animals:armadillo_scute", "cb_mobs_animals:wolf_armor", 64
local RANGE = 4
local UNDEAD = { "zombie", "skeleton", "husk", "drowned", "stray", "wither", }

local function shed_time()
	return 300 + math.random() * 300
end

core.register_craftitem(A.SCUTE, {
	description = S("Armadillo Scute"),
	inventory_image = "cb_mobs_animals_armadillo_scute.png",
})

core.register_tool(A.WOLF_ARMOR, {
	description = S("Wolf Armor"),
	inventory_image = "cb_mobs_animals_wolf_armor.png",
	groups = { not_repaired_by_anvil = 1, },
})
core.register_craft({ output = A.WOLF_ARMOR, recipe = {
	{ A.SCUTE, "", "", },
	{ A.SCUTE, A.SCUTE, A.SCUTE, },
	{ A.SCUTE, "", A.SCUTE, },
}, })

local function threat(self, obj)
	if obj:is_player() then
		if core.is_creative_enabled(obj:get_player_name()) then
			return false
		end
		local v = obj:get_velocity() or vector.zero()
		return obj:get_player_control().aux1 or obj:get_attach() ~= nil or v.x * v.x + v.z * v.z > 25
			or self._attacker == obj:get_player_name()
	end
	local e = obj:get_luaentity()
	if not (e and e._cmi_is_mob) then
		return false
	end
	for _, w in ipairs(UNDEAD) do
		if e.name:find(w, 1, true) then
			return true
		end
	end
	return false
end

function A.roll(self, on)
	self._rolled = on or nil
	self._quiet = 0
	if on then
		self.state, self.attack, self.following = "stand", nil, nil
		self:set_velocity(0)
		self:set_animation("roll", true)
		self:mob_sound("cb_mobs_animals_armadillo_roll")
	else
		self:set_animation("stand", true)
	end
end

-- From do_custom: the scute timer and the rolled-up state.
function A.armadillo_tick(self, dtime)
	if not self.child then
		self._scute_t = (self._scute_t or shed_time()) - dtime
		if self._scute_t <= 0 then
			self._scute_t = shed_time()
			local pos = self.object:get_pos()
			core.add_item(pos, A.SCUTE)
			core.sound_play("cb_mobs_animals_armadillo_roll", { pos = pos, gain = 0.4, pitch = 1.4, }, true)
		end
	end
	self._look = (self._look or 0) + dtime
	if self._look < 0.25 then
		return not self._rolled
	end
	self._look = 0
	local pos = self.object:get_pos()
	local near = false
	for _, obj in ipairs(core.get_objects_inside_radius(pos, RANGE)) do
		if obj ~= self.object and threat(self, obj) then
			near = true
			break
		end
	end
	if not self._rolled then
		if near then
			A.roll(self, true)
		end
		return not self._rolled
	end
	local v = self.object:get_velocity() or vector.zero()
	self.object:set_velocity({ x = 0, y = v.y, z = 0, })
	if near then
		self._quiet = 0
	else
		self._quiet = (self._quiet or 0) + 0.25
		if self._quiet >= (self._unroll_at or 4) then
			self._unroll_at = 3 + math.random() * 3
			A.roll(self, false)
			return true
		end
	end
	return false
end

mobs:register_mob(A.ARMADILLO, {
	type = "animal", passive = true, hp_min = 12, hp_max = 12, armor = 100,
	collisionbox = { -0.35, 0, -0.35, 0.35, 0.65, 0.35, },
	visual = "mesh", mesh = "cb_mobs_animals_armadillo.b3d", visual_size = { x = 1, y = 1, },
	textures = { { "cb_mobs_animals_armadillo.png", }, },
	makes_footstep_sound = true, walk_velocity = 0.7, run_velocity = 1.4, jump = true, view_range = 8,
	water_damage = 0, lava_damage = 5, light_damage = 0, fall_damage = true,
	sounds = { damage = "cb_mobs_animals_armadillo_hurt", death = "cb_mobs_animals_armadillo_death", distance = 12, },
	animation = { speed_normal = 40, stand_start = 0, stand_end = 0, walk_start = 1, walk_end = 21,
		run_start = 1, run_end = 21, run_speed = 70, roll_start = 22, roll_end = 22, },
	do_custom = function(self, dtime)
		return A.armadillo_tick(self, dtime)
	end,
	-- mobs_redo applies the damage after this; a rolled armadillo takes it here
	do_punch = function(self, hitter, _, _, _, damage)
		if hitter and hitter:is_player() then
			self._attacker = hitter:get_player_name()
		end
		if not self._rolled then
			A.roll(self, true)
			return
		end
		self.health = self.health - math.max(0, damage / 2 - 1)
		self:check_for_death({ type = "punch", puncher = hitter, })
		return false
	end,
	after_activate = function(self)
		if self._rolled then
			self:set_animation("roll", true)
		end
	end,
})
mobs:register_egg(A.ARMADILLO, S("Armadillo"), "cb_mobs_animals_armadillo_scute.png", 1)
