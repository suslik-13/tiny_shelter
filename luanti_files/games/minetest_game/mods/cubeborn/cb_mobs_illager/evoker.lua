-- Evoker (spec cycle 2, 5): keeps its distance (a spell-less "shoot"),
-- summons 3 vexes every 17 s (at most 8 within 16) and calls fangs: a circle
-- around itself for close targets, a line of 16 towards far ones; fangs bite
-- (6) whatever is not an illager. Vexes fly through blocks and wither away
-- after 30-119 s.
local S = cb_mobs_illager.S
local I = cb_mobs_illager
I.VEX_CAP, I.VEX_EVERY, I.FANGS_EVERY = 8, 17, 5

core.register_entity("cb_mobs_illager:fangs", {
	initial_properties = { visual = "mesh", mesh = "cb_mobs_illager_evoker_fangs.b3d",
		textures = { "cb_mobs_illager_evoker_fangs.png", }, visual_size = { x = 1, y = 1, }, physical = false,
		pointable = false, static_save = false, collisionbox = { 0, 0, 0, 0, 0, 0, }, },
	on_activate = function(self)
		self.t = 0
	end,
	on_step = function(self, dtime)
		self.t = self.t + dtime
		if not self.bit and self.t >= 0.4 then
			self.bit = true
			for _, obj in ipairs(core.get_objects_inside_radius(self.object:get_pos(), 0.9)) do
				local e = obj:get_luaentity()
				if obj:is_player() or (e and e._cmi_is_mob and not I.ILLAGERS[e.name]) then
					obj:punch(self.object, 1, { full_punch_interval = 1, damage_groups = { fleshy = 6, }, }, nil)
				end
			end
		end
		if self.t >= 1.2 then
			self.object:remove()
		end
	end,
})

local function fang_at(x, y, z)
	local p = vector.new(x, y, z)
	for dy = 1, -2, -1 do
		local q = vector.offset(p, 0, dy, 0)
		local below = core.registered_nodes[core.get_node(vector.offset(q, 0, -1, 0)).name]
		if core.get_node(q).name == "air" and below and below.walkable ~= false then
			return core.add_entity(q, "cb_mobs_illager:fangs") and 1 or 0
		end
	end
	return 0
end

local function cast_sound(ev)
	core.sound_play("cb_mobs_illager_evoker_cast", { object = ev.object, max_hear_distance = 24, }, true)
end

function I.cast_fangs(ev, target)
	local pos = vector.round(ev.object:get_pos())
	local n = 0
	cast_sound(ev)
	if vector.distance(pos, target) < 3 then
		for i = 0, 4 do
			local a = i * 2 * math.pi / 5
			n = n + fang_at(pos.x + math.floor(1.5 * math.cos(a) + 0.5), pos.y, pos.z + math.floor(1.5 * math.sin(a) + 0.5))
		end
		for i = 0, 7 do
			local a = i * 2 * math.pi / 8 + 0.4
			n = n + fang_at(pos.x + math.floor(2.5 * math.cos(a) + 0.5), pos.y, pos.z + math.floor(2.5 * math.sin(a) + 0.5))
		end
	else
		local dir = vector.normalize(vector.subtract(target, pos))
		for i = 1, 16 do
			local q = vector.add(pos, vector.multiply(dir, i * 1.25))
			n = n + fang_at(math.floor(q.x + 0.5), pos.y, math.floor(q.z + 0.5))
		end
	end
	return n
end

function I.summon_vexes(ev)
	local pos = ev.object:get_pos()
	local have = 0
	for _, obj in ipairs(core.get_objects_inside_radius(pos, 16)) do
		local e = obj:get_luaentity()
		have = have + ((e and e.name == "cb_mobs_illager:vex") and 1 or 0)
	end
	local n = 0
	if have < I.VEX_CAP then
		cast_sound(ev)
	end
	for _ = 1, math.min(3, I.VEX_CAP - have) do
		if core.add_entity(vector.offset(pos, math.random(-2, 2), 1, math.random(-2, 2)), "cb_mobs_illager:vex") then
			n = n + 1
		end
	end
	return n
end

mobs:register_arrow("cb_mobs_illager:spell", {
	visual = "sprite", visual_size = { x = 0.01, y = 0.01, }, textures = { "blank.png", }, velocity = 1,
	hit_player = function() end, hit_mob = function() end, hit_node = function() end,
	on_step = function(self)
		self.object:remove()
	end,
})

I.register("cb_mobs_illager:evoker", cb_core.fixed_head({
	-- Mineclonia's vindicator/evoker meshes are modelled at full size, unlike the pillager's
	visual_size = { x = 1, y = 1, },
	mesh = "cb_mobs_illager_evoker.b3d",
	textures = { { "cb_mobs_illager_evoker.png", }, },
	attack_type = "shoot",
	arrow = "cb_mobs_illager:spell",
	shoot_interval = 3,
	drops = I.drops({ { "cb_items:totem", 1, 1, }, { "cb_items:emerald", 0, 1, }, }),
	do_custom = function(self, dtime)
		self._vt = (self._vt or 0) + dtime
		self._ft = (self._ft or 0) + dtime
		local t = self.attack and self.attack.get_pos and self.attack:get_pos()
		if t then
			if self._vt >= I.VEX_EVERY then
				self._vt = 0
				I.summon_vexes(self)
			end
			if self._ft >= I.FANGS_EVERY then
				self._ft = 0
				I.cast_fangs(self, t)
			end
		end
		return true
	end,
}, 6.61948))

I.register("cb_mobs_illager:vex", {
	hp_min = 14,
	hp_max = 14,
	collisionbox = { -0.2, 0, -0.2, 0.2, 0.8, 0.2, },
	mesh = "cb_mobs_illager_vex.b3d",
	textures = { { "cb_mobs_illager_vex.png", }, },
	visual_size = { x = 1, y = 1.25, },
	fly = true,
	fly_in = { "air", },
	attack_type = "dogfight",
	reach = 2,
	damage = 9,
	walk_velocity = 2,
	run_velocity = 3.5,
	fall_damage = false,
	drops = {},
	sounds = { damage = "cb_mobs_illager_vex_hurt", death = "cb_mobs_illager_vex_death", war_cry = "cb_mobs_illager_vex_charge",
		attack = "cb_mobs_illager_vex_charge", distance = 16, },
	after_activate = function(self)
		self.object:set_properties({ physical = false, collide_with_objects = false, })
		self._life = self._life or math.random(30, 119)
	end,
	do_custom = function(self, dtime)
		self._life = self._life - dtime
		if self._life <= 0 then
			self._wt = (self._wt or 0) + dtime
			if self._wt >= 1 then
				self._wt = 0
				self.health = self.health - 1
				self:check_for_death({ type = "unknown", })
			end
		end
		return true
	end,
})

mobs:register_egg("cb_mobs_illager:evoker", S("Evoker"), "default_stone.png", 1)
mobs:register_egg("cb_mobs_illager:vex", S("Vex"), "default_stone.png", 1)
