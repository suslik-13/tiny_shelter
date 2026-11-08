-- Goat (spec cycle 4, 8b): lives high in the mountains. Every 30-300 s (a
-- screaming goat, 2 in 100: every 5-15 s) it rams the nearest player not in
-- creative or mob other than a goat within 8 nodes: a straight charge that
-- hurts and throws the target back. A charge ending against stone, a tree
-- or ice knocks off a horn (two per goat); a goat horn plays its call far
-- and wide (7 s cooldown). An empty bucket milks a goat; wheat breeds it.
local S = cb_mobs_animals.S
local A = cb_mobs_animals
A.GOAT = "cb_mobs_animals:goat"
local RAM_RANGE, CHARGE_SPEED, CHARGE_TIME, KNOCK = 8, 6, 1.5, 6
local HORN_COOLDOWN = 7
local HORNS_PLAIN, HORNS_SCREAMER = { "ponder", "sing", "seek", "feel", }, { "admire", "call", "yearn", "dream", }
local HORN_SOUNDS = { ponder = "cb_mobs_animals_goat_horn_ponder", sing = "cb_mobs_animals_goat_horn_sing",
	seek = "cb_mobs_animals_goat_horn_seek", feel = "cb_mobs_animals_goat_horn_feel",
	admire = "cb_mobs_animals_goat_horn_admire", call = "cb_mobs_animals_goat_horn_call",
	yearn = "cb_mobs_animals_goat_horn_yearn", dream = "cb_mobs_animals_goat_horn_dream", }
local HORN_NAMES = { ponder = S("Ponder"), sing = S("Sing"), seek = S("Seek"), feel = S("Feel"),
	admire = S("Admire"), call = S("Call"), yearn = S("Yearn"), dream = S("Dream"), }

A.HORNS = {}
local last_call = {}

function A.horn_play(stack, user)
	local name = user:get_player_name()
	local now = core.get_us_time() / 1e6
	if now - (last_call[name] or -HORN_COOLDOWN) < HORN_COOLDOWN then
		return false
	end
	last_call[name] = now
	local variant = stack:get_name():match("goat_horn_(%a+)$")
	core.sound_play(HORN_SOUNDS[variant], { pos = user:get_pos(), max_hear_distance = 256, }, true)
	return true
end

core.register_on_leaveplayer(function(player)
	last_call[player:get_player_name()] = nil
end)

for _, v in ipairs({ "ponder", "sing", "seek", "feel", "admire", "call", "yearn", "dream", }) do
	local item = "cb_mobs_animals:goat_horn_" .. v
	A.HORNS[#A.HORNS + 1] = item
	local function play(stack, user)
		if user and user:is_player() then
			A.horn_play(stack, user)
		end
		return stack
	end
	core.register_craftitem(item, {
		description = S("Goat Horn") .. "\n" .. core.colorize("#a8a8a8", HORN_NAMES[v]),
		inventory_image = "cb_mobs_animals_goat_horn.png",
		stack_max = 1,
		groups = { goat_horn = 1, },
		on_secondary_use = play,
		on_place = play,
	})
end

local function new_cd(self)
	return self._screamer and 5 + math.random() * 10 or 30 + math.random() * 270
end

function A.goat_can_ram(self, obj)
	if obj == self.object then
		return false
	end
	if obj:is_player() then
		return not core.is_creative_enabled(obj:get_player_name())
	end
	local e = obj:get_luaentity()
	return e ~= nil and e._cmi_is_mob == true and e.name ~= A.GOAT and (e.health or 0) > 0
end

function A.goat_ram_target(self)
	local pos = self.object:get_pos()
	local best, bd
	for _, obj in ipairs(core.get_objects_inside_radius(pos, RAM_RANGE)) do
		if A.goat_can_ram(self, obj) then
			local d = vector.distance(pos, obj:get_pos())
			if d >= 2 and (not bd or d < bd) then
				best, bd = obj, d
			end
		end
	end
	return best
end

local function horn_breaker(name)
	local g = (core.registered_nodes[name] or {}).groups or {}
	return (g.stone or 0) > 0 or (g.tree or 0) > 0 or name == "default:ice" or name:find("_with_", 1, true) ~= nil
end

local function drop_horn(self)
	if (self._horns or 2) <= 0 then
		return
	end
	self._horns = (self._horns or 2) - 1
	local list = self._screamer and HORNS_SCREAMER or HORNS_PLAIN
	local pos = self.object:get_pos()
	core.add_item(vector.offset(pos, 0, 1, 0), "cb_mobs_animals:goat_horn_" .. list[math.random(#list)])
	core.sound_play("default_dig_cracky", { pos = pos, gain = 0.8, }, true)
end

-- The end of a charge: into `target` (hurt and thrown back) and/or against
-- the node `blocked` (a horn may come off). True when something was hit.
function A.goat_ram_hit(self, target, blocked)
	self._charge = nil
	self._ram_cd = new_cd(self)
	self:set_velocity(0)
	self:set_animation("stand", true)
	if target and target:get_pos() then
		local dir = vector.direction(self.object:get_pos(), target:get_pos())
		target:punch(self.object, 1, { full_punch_interval = 1, damage_groups = { fleshy = self.damage or 2, }, }, dir)
		target:add_velocity({ x = dir.x * KNOCK, y = 3, z = dir.z * KNOCK, })
		core.sound_play("cb_mobs_animals_goat_ram", { pos = self.object:get_pos(), }, true)
		return true
	end
	if blocked and horn_breaker(blocked) then
		drop_horn(self)
		return true
	end
	return false
end

-- From do_custom: the ram cooldown and the charge itself.
function A.goat_tick(self, dtime)
	if self.child then
		return true
	end
	local c = self._charge
	if not c then
		self._ram_cd = (self._ram_cd or new_cd(self)) - dtime
		if self._ram_cd > 0 or self.state == "runaway" then
			return true
		end
		local target = A.goat_ram_target(self)
		if not target then
			self._ram_cd = 2
			return true
		end
		local pos = self.object:get_pos()
		local dir = vector.direction(pos, target:get_pos())
		dir.y = 0
		dir = vector.normalize(dir)
		self._charge = { dir = dir, t = 0, }
		self._target = target
		self.object:set_yaw(math.atan2(-dir.x, dir.z) - (self.rotate or 0))
		self:set_animation("ram", true)
		self:mob_sound(self.sounds.random)
		return false
	end
	c.t = c.t + dtime
	local pos = self.object:get_pos()
	local v = self.object:get_velocity() or vector.zero()
	self.object:set_velocity({ x = c.dir.x * CHARGE_SPEED, y = v.y, z = c.dir.z * CHARGE_SPEED, })
	local target = self._target
	if target and target:get_pos() and vector.distance(pos, target:get_pos()) <= 1.6 then
		self._target = nil
		A.goat_ram_hit(self, target)
		return false
	end
	local ahead = core.get_node(vector.round(vector.offset(pos, c.dir.x * 0.8, 0.5, c.dir.z * 0.8))).name
	local def = core.registered_nodes[ahead]
	if def and def.walkable then
		self._target = nil
		A.goat_ram_hit(self, nil, c.t > 0.3 and ahead or nil)
		return false
	end
	if c.t >= CHARGE_TIME then
		self._target = nil
		A.goat_ram_hit(self)
	end
	return false
end

function A.goat_milk(self, clicker)
	local stack = clicker:get_wielded_item()
	if self.child or stack:get_name() ~= "bucket:bucket_empty" or not core.registered_items["mobs:bucket_milk"] then
		return false
	end
	local inv = clicker:get_inventory()
	if not core.is_creative_enabled(clicker:get_player_name()) then
		stack:take_item()
		clicker:set_wielded_item(stack)
	end
	local milk = ItemStack("mobs:bucket_milk")
	if inv and inv:room_for_item("main", milk) then
		inv:add_item("main", milk)
	else
		core.add_item(self.object:get_pos(), milk)
	end
	core.sound_play("cb_mobs_animals_goat", { pos = self.object:get_pos(), pitch = self._screamer and 1.4 or 1, }, true)
	return true
end

mobs:register_mob(A.GOAT, {
	type = "animal", passive = true, hp_min = 10, hp_max = 10, armor = 100, damage = 2,
	collisionbox = { -0.45, 0, -0.45, 0.45, 1.3, 0.45, },
	visual = "mesh", mesh = "cb_mobs_animals_goat.b3d", visual_size = { x = 1, y = 1, },
	textures = { { "cb_mobs_animals_goat.png", }, },
	makes_footstep_sound = true, walk_velocity = 1, run_velocity = 2, jump = true, jump_height = 6,
	stepheight = 1.1, view_range = 8, water_damage = 0, lava_damage = 5, light_damage = 0, fall_damage = false,
	sounds = { random = "cb_mobs_animals_goat", damage = "cb_mobs_animals_goat_hurt",
		death = "cb_mobs_animals_goat_death", distance = 12, },
	animation = { speed_normal = 40, stand_start = 0, stand_end = 0, walk_start = 1, walk_end = 41,
		run_start = 1, run_end = 41, run_speed = 70, ram_start = 42, ram_end = 82, ram_speed = 90, },
	follow = { "farming:wheat", },
	do_custom = function(self, dtime)
		return A.goat_tick(self, dtime)
	end,
	on_rightclick = function(self, clicker)
		if clicker and clicker:is_player() and not A.feed(self, clicker) then
			A.goat_milk(self, clicker)
		end
	end,
	on_breed = function(self, other)
		return A.on_breed(self, other, function(young)
			-- a parent's gene, mutating 2 times in 100
			local scream = (math.random(2) == 1 and self or other)._screamer
			if math.random(100) <= 2 then
				scream = not scream
			end
			young._screamer, young._horns = scream, 2
		end)
	end,
	after_activate = function(self)
		if self._screamer == nil then
			self._screamer, self._horns = math.random(100) <= 2, 2
		end
		self._feed_count = 1
	end,
})
mobs:register_egg(A.GOAT, S("Goat"), "cb_mobs_animals_goat_horn.png", 1)
