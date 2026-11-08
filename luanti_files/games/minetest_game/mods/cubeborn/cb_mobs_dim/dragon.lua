-- Ender dragon (spec 7): a plain entity with its own flight AI (not
-- mobs_redo). It circles the pillars healing from the nearest crystal, dives
-- at players, and perches on the exit portal breathing damage clouds;
-- projectiles do not hurt it while it perches. It is saved with the world
-- (out of active blocks it just waits) and carries a generation id: the
-- fight (cb_portals/end_fight.lua) sets D.hooks, and a copy whose generation
-- D.hooks.valid rejects removes itself.
local NAME = "cb_mobs_dim:ender_dragon"
local D = {
	HP = 200, TICK = 0.5,
	CIRCLE_R = 48, CIRCLE_UP = 24, CIRCLE_SPEED = 10, STRAFE_SPEED = 16, PERCH_SPEED = 8,
	HEAL_R = 48, BEAM_DAMAGE = 10, HIT = 10, HIT_R = 4, STRAFE_TIME = 8, DECIDE_EVERY = 5,
	PERCH_TIME = 10, PERCH_HURT = 40, BREATH_EVERY = 2, BREATH_TIME = 6, BREATH_R = 3, BREATH_DAMAGE = 2,
	hooks = {},
}
cb_mobs_dim.dragon = D
local BREATH_TEX = "cb_mobs_dim_dragon_breath.png^[colorize:#ff00ff:127"

-- luaentity -> true for every active dragon
local active = {}

function D.find(id)
	for ent in pairs(active) do
		if ent._id == id and ent.object:get_pos() then
			return ent.object
		end
	end
	return nil
end

function D.count()
	local n = 0
	for ent in pairs(active) do
		if ent.object:get_pos() then
			n = n + 1
		else
			active[ent] = nil
		end
	end
	return n
end

function D.waypoint(centre, k)
	local a = k * math.pi / 6
	return vector.new(centre.x + D.CIRCLE_R * math.cos(a), centre.y + D.CIRCLE_UP + 6 * math.sin(k),
		centre.z + D.CIRCLE_R * math.sin(a))
end

-- Next phase while circling: perching grows likelier as crystals are lost.
function D.decide(players, crystals, roll)
	if players == 0 then
		return "circle"
	end
	local perch = 1 / (2 + crystals)
	if roll < perch then
		return "perch"
	elseif roll < perch + 0.3 then
		return "strafe"
	end
	return "circle"
end

function D.heal_source(pos, crystals)
	local best, bd
	for _, c in ipairs(crystals) do
		local d = vector.distance(pos, c)
		if d <= D.HEAL_R and (not bd or d < bd) then
			best, bd = c, d
		end
	end
	return best
end

-- clouds: { {pos, left}, ... }; players inside one lose BREATH_DAMAGE (magic,
-- past armour). Returns the number of hits.
function D.breath_tick(clouds, players, dt)
	local hits = 0
	for i = #clouds, 1, -1 do
		local c = clouds[i]
		c.left = c.left - dt
		if c.left <= 0 then
			table.remove(clouds, i)
		else
			for _, p in ipairs(players) do
				local pp = p:get_pos()
				if pp and p:get_hp() > 0 and vector.distance(pp, c.pos) <= D.BREATH_R then
					p:set_hp(math.max(0, p:get_hp() - D.BREATH_DAMAGE), { type = "set_hp", cause = "cb_mobs_dim:dragon_breath", })
					hits = hits + 1
				end
			end
		end
	end
	return hits
end

local function report_hp(hp)
	if D.hooks.on_hp then
		D.hooks.on_hp(math.max(0, hp))
	end
end

local function nearest(players, pos)
	local best, bd
	for _, p in ipairs(players) do
		local pp = p:get_pos()
		if pp then
			local d = vector.distance(pp, pos)
			if not bd or d < bd then
				best, bd = p, d
			end
		end
	end
	return best
end

function D.set_phase(ent, phase)
	ent._phase, ent._t, ent._hurt, ent._breath, ent._decide = phase, 0, 0, 0, 0
	if phase ~= "circle" then
		ent._beam = nil
	end
end

local function heal(ent, pos)
	ent._beam = nil
	local hp = ent.object:get_hp()
	if hp >= D.HP or not D.hooks.crystals then
		return
	end
	local c = D.heal_source(pos, D.hooks.crystals())
	if not c then
		return
	end
	ent._beam = c
	ent.object:set_hp(hp + 1)
	report_hp(hp + 1)
	local from = vector.offset(c, 0, 1.5, 0)
	core.add_particlespawner({
		amount = 4, time = D.TICK, minpos = from, maxpos = from,
		minvel = vector.divide(vector.subtract(pos, from), 0.6), maxvel = vector.divide(vector.subtract(pos, from), 0.6),
		minexptime = 0.6, maxexptime = 0.6, minsize = 2, maxsize = 2, texture = "cb_mobs_dim_dragon_breath.png^[colorize:#ffffff:160",
		glow = 14,
	})
end

local function breathe(ent, at)
	ent._clouds[#ent._clouds + 1] = { pos = vector.copy(at), left = D.BREATH_TIME, }
	core.add_particlespawner({
		amount = 80, time = D.BREATH_TIME, minpos = vector.offset(at, -D.BREATH_R, 0, -D.BREATH_R),
		maxpos = vector.offset(at, D.BREATH_R, 1, D.BREATH_R), minvel = vector.new(-0.2, 0, -0.2),
		maxvel = vector.new(0.2, 0.3, 0.2), minexptime = 1, maxexptime = 2, minsize = 4, maxsize = 8,
		texture = BREATH_TEX, glow = 10,
	})
	core.sound_play("cb_mobs_dim_ender_dragon_shoot", { pos = at, max_hear_distance = 48, }, true)
end

local function step(ent, dtime)
	ent._tick = ent._tick + dtime
	if ent._tick < D.TICK then
		return
	end
	local dt = ent._tick
	ent._tick = 0
	local pos = ent.object:get_pos()
	if not pos or not ent._centre then
		return
	end
	local players = D.hooks.players and D.hooks.players() or {}
	D.breath_tick(ent._clouds, players, dt)
	ent._t = ent._t + dt
	local phase, target, speed = ent._phase, nil, D.CIRCLE_SPEED
	if phase == "circle" then
		target = D.waypoint(ent._centre, ent._k)
		if vector.distance(pos, target) < 4 then
			ent._k = ent._k + 1
			target = D.waypoint(ent._centre, ent._k)
		end
		heal(ent, pos)
		if math.random() < dt / 12 then
			core.sound_play("cb_mobs_dim_ender_dragon_growl", { object = ent.object, max_hear_distance = 96, }, true)
		end
		ent._decide = ent._decide + dt
		if ent._decide >= D.DECIDE_EVERY then
			local crystals = D.hooks.crystals and #D.hooks.crystals() or 0
			D.set_phase(ent, D.decide(#players, crystals, math.random()))
		end
	elseif phase == "strafe" then
		local p = nearest(players, pos)
		if not p or ent._t > D.STRAFE_TIME then
			D.set_phase(ent, "circle")
		else
			target = vector.offset(p:get_pos(), 0, 1, 0)
			speed = D.STRAFE_SPEED
			if vector.distance(pos, target) <= D.HIT_R then
				p:punch(ent.object, 1, { full_punch_interval = 1, damage_groups = { fleshy = D.HIT, }, },
					vector.direction(pos, target))
				p:add_velocity(vector.new(0, 8, 0))
				core.sound_play("cb_mobs_dim_ender_dragon_attack", { pos = pos, max_hear_distance = 48, }, true)
				D.set_phase(ent, "circle")
			end
		end
	elseif phase == "perch" then
		target, speed = ent._perch, D.PERCH_SPEED
		if vector.distance(pos, target) < 1.5 then
			ent.object:set_pos(target)
			D.set_phase(ent, "perched")
			target = nil
		end
	elseif phase == "perched" then
		ent._breath = ent._breath + dt
		if ent._breath >= D.BREATH_EVERY then
			ent._breath = 0
			local p = nearest(players, pos)
			if p then
				breathe(ent, p:get_pos())
			end
		end
		if ent._t > D.PERCH_TIME or ent._hurt >= D.PERCH_HURT then
			D.set_phase(ent, "circle")
		end
	end
	if target then
		local d = vector.distance(pos, target)
		local v = vector.multiply(vector.direction(pos, target), math.min(speed, d / dt))
		ent.object:set_velocity(v)
		if vector.length(v) > 0.1 then
			ent.object:set_yaw(core.dir_to_yaw(v))
		end
	else
		ent.object:set_velocity(vector.zero())
	end
end

core.register_entity(NAME, {
	initial_properties = {
		hp_max = D.HP,
		physical = false,
		collide_with_objects = false,
		collisionbox = { -2, 0, -2, 2, 2.5, 2, },
		selectionbox = { -3, 0, -3, 3, 3, 3, },
		visual = "mesh",
		mesh = "cb_mobs_dim_dragon.b3d",
		textures = { "cb_mobs_dim_dragon.png", },
		visual_size = { x = 3, y = 3, },
		static_save = true,
		glow = 4,
	},
	on_activate = function(self, staticdata)
		local data = core.deserialize(staticdata or "") or {}
		self._id = data.id
		self._centre = data.centre and vector.copy(data.centre)
		self._perch = data.perch and vector.copy(data.perch)
		if D.hooks.valid and not D.hooks.valid(self._id) then
			self.object:remove()
			return
		end
		self._phase, self._k, self._t, self._tick = "circle", 0, 0, 0
		self._decide, self._breath, self._hurt, self._clouds = 0, 0, 0, {}
		self.object:set_armor_groups({ fleshy = 100, })
		self.object:set_animation({ x = 0, y = 40, }, 30, 0, true)
		active[self] = true
	end,
	on_deactivate = function(self)
		active[self] = nil
	end,
	get_staticdata = function(self)
		return core.serialize({ id = self._id, centre = self._centre, perch = self._perch, })
	end,
	on_punch = function(self, puncher, _, _, _, damage)
		local by_player = puncher and puncher:is_player()
		if self._phase == "perched" and not by_player then
			return true
		end
		damage = damage or 0
		if self._phase == "perched" then
			self._hurt = self._hurt + damage
		end
		report_hp(self.object:get_hp() - damage)
	end,
	on_death = function(self)
		active[self] = nil
		core.sound_play("cb_mobs_dim_ender_dragon_death", { pos = self.object:get_pos(), gain = 1.5, max_hear_distance = 128, }, true)
		if D.hooks.on_death then
			D.hooks.on_death(self.object:get_pos())
		end
	end,
	on_step = step,
})

function D.spawn(pos, centre, perch, hp, id)
	local obj = core.add_entity(pos, NAME, core.serialize({ id = id, centre = centre, perch = perch, }))
	if not obj or not obj:get_pos() then
		return nil
	end
	obj:set_hp(math.max(1, math.min(D.HP, hp or D.HP)))
	return obj
end

-- A crystal the dragon heals from blows up: the dragon takes BEAM_DAMAGE.
local crystal_destroyed = cb_items.on_crystal_destroyed
cb_items.on_crystal_destroyed = function(pos)
	for ent in pairs(active) do
		if ent._beam and ent.object:get_pos() and vector.distance(ent._beam, pos) < 2 then
			ent._beam = nil
			local hp = ent.object:get_hp() - D.BEAM_DAMAGE
			report_hp(hp)
			ent.object:set_hp(math.max(hp, 0))
		end
	end
	if crystal_destroyed then
		crystal_destroyed(pos)
	end
end
