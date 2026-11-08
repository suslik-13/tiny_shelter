-- Shulker (spec 7): sits on a block face, opens towards players within
-- RANGE and shoots homing bullets that make them levitate; closed it takes a
-- fifth of the damage. When its block goes it clings to another face of the
-- same spot or teleports up to 8 nodes away. A plain entity (it never moves
-- or falls), positioned at its node's bottom like Mineclonia's; the face
-- turns the model's root bone.
local NAME, BULLET = "cb_mobs_dim:shulker", "cb_mobs_dim:shulker_bullet"
local Sh = {
	HP = 30, RANGE = 16, TICK = 0.5, SHOOT_MIN = 1, SHOOT_MAX = 5.5, ARMOR_CLOSED = 20, ARMOR_OPEN = 100,
	BULLET_SPEED = 4, BULLET_DAMAGE = 4, BULLET_LIFE = 10, LEVITATION = 10, TELEPORT_R = 8, PEEK = 1 / 40,
	hooks = {},
}
cb_mobs_dim.shulker = Sh
Sh.hooks.players = core.get_connected_players

local OPEN = {
	up = vector.new(0, 1, 0), down = vector.new(0, -1, 0), north = vector.new(0, 0, 1),
	south = vector.new(0, 0, -1), east = vector.new(1, 0, 0), west = vector.new(-1, 0, 0),
}
local FACES = { "up", "north", "west", "south", "east", "down", }
-- Root bone rotations per face, as Mineclonia's shulker_attachment_parameters.
local ROT = {
	north = vector.new(math.pi / 2, 0, math.pi), west = vector.new(0, 0, math.pi / 2),
	south = vector.new(math.pi / 2 * 3, 0, 0), east = vector.new(0, 0, math.pi / 2 * 3),
	up = vector.zero(), down = vector.new(0, 0, math.pi),
}

local function full(pos)
	local def = core.registered_nodes[core.get_node(pos).name]
	return def ~= nil and def.walkable ~= false and (def.drawtype or "normal") == "normal"
end

-- A shulker can sit in node_pos opening towards face.
function Sh.valid(face, node_pos)
	return core.get_node(node_pos).name == "air" and full(vector.subtract(node_pos, OPEN[face]))
end

-- A free spot within TELEPORT_R with a full block to cling to.
function Sh.find_spot(node_pos, rand)
	rand = rand or math.random
	for _ = 1, 8 do
		local p = vector.offset(node_pos, rand(-Sh.TELEPORT_R, Sh.TELEPORT_R), rand(-Sh.TELEPORT_R, Sh.TELEPORT_R),
			rand(-Sh.TELEPORT_R, Sh.TELEPORT_R))
		if core.get_node(p).name == "air" and not core.is_protected(p, "") then
			for _, face in ipairs(FACES) do
				if Sh.valid(face, p) then
					return p, face
				end
			end
		end
	end
	return nil
end

function Sh.drop(pos, roll)
	if (roll or math.random()) < 0.5 then
		core.add_item(pos, "cb_items:shulker_shell")
		return true
	end
	return false
end

local function node_of(obj)
	local p = obj:get_pos()
	return p and vector.round(vector.offset(p, 0, 0.5, 0))
end

local function attach(ent, face)
	ent._face = face
	ent.object:set_bone_override("root", { rotation = { vec = ROT[face], absolute = true, }, })
end

local function set_state(ent, state)
	if ent._state == state then
		return
	end
	local was = ent._state
	ent._state = state
	if was then
		core.sound_play(state == "open" and "cb_mobs_dim_shulker_open" or "cb_mobs_dim_shulker_close",
			{ object = ent.object, max_hear_distance = 16, }, true)
	end
	if state == "open" then
		ent.object:set_animation({ x = 45, y = 90, }, 24, 0.1, false)
		ent.object:set_armor_groups({ fleshy = Sh.ARMOR_OPEN, })
	else
		ent.object:set_animation({ x = 90, y = 145, }, 24, 0.1, false)
		ent.object:set_armor_groups({ fleshy = Sh.ARMOR_CLOSED, })
	end
end

local function nearest(players, pos)
	local best, bd
	for _, p in ipairs(players) do
		local pp = p:get_pos()
		if pp and p:get_hp() > 0 then
			local d = vector.distance(pp, pos)
			if d <= Sh.RANGE and (not bd or d < bd) then
				best, bd = p, d
			end
		end
	end
	return best
end

local function shoot(ent, target)
	local pos = vector.add(ent.object:get_pos(), vector.offset(OPEN[ent._face], 0, 0.5, 0))
	local b = core.add_entity(pos, BULLET)
	core.sound_play("cb_mobs_dim_shulker_shoot", { pos = pos, max_hear_distance = 16, }, true)
	if b then
		local be = b:get_luaentity()
		be._target = target
	end
end

local function cling(ent)
	local node = node_of(ent.object)
	if not node then
		return
	end
	if Sh.valid(ent._face, node) then
		return
	end
	for _, face in ipairs(FACES) do
		if Sh.valid(face, node) then
			attach(ent, face)
			return
		end
	end
	local p, face = Sh.find_spot(node)
	if p then
		ent.object:set_pos(vector.offset(p, 0, -0.5, 0))
		attach(ent, face)
		core.sound_play("cb_mobs_dim_enderman_teleport_dst", { pos = p, max_hear_distance = 16, }, true)
	end
end

core.register_entity(NAME, {
	initial_properties = {
		hp_max = Sh.HP,
		physical = true,
		collide_with_objects = true,
		collisionbox = { -0.5, 0, -0.5, 0.5, 1, 0.5, },
		visual = "mesh",
		mesh = "cb_mobs_dim_shulker.b3d",
		textures = { "cb_blocks_shulker_purple.png", },
		visual_size = { x = 3, y = 3, },
		static_save = true,
	},
	on_activate = function(self, staticdata)
		local data = core.deserialize(staticdata or "") or {}
		self._tick, self._shot = 0, Sh.SHOOT_MIN + math.random() * (Sh.SHOOT_MAX - Sh.SHOOT_MIN)
		self.object:set_acceleration(vector.zero())
		self.object:set_velocity(vector.zero())
		attach(self, OPEN[data.face] and data.face or "up")
		self._state = nil
		set_state(self, "closed")
	end,
	get_staticdata = function(self)
		return core.serialize({ face = self._face, })
	end,
	on_step = function(self, dtime)
		self._tick = self._tick + dtime
		if self._tick < Sh.TICK then
			return
		end
		local dt = self._tick
		self._tick = 0
		local pos = self.object:get_pos()
		if not pos then
			return
		end
		cling(self)
		local target = nearest(Sh.hooks.players(), pos)
		if target then
			set_state(self, "open")
			self._shot = self._shot - dt
			if self._shot <= 0 then
				self._shot = Sh.SHOOT_MIN + math.random() * (Sh.SHOOT_MAX - Sh.SHOOT_MIN)
				shoot(self, target)
			end
		else
			set_state(self, "closed")
			if math.random() < Sh.PEEK then
				self.object:set_animation({ x = 25, y = 45, }, 45, 0.1, false)
			end
		end
	end,
	on_punch = function(self)
		core.sound_play("cb_mobs_dim_shulker_hurt", { object = self.object, max_hear_distance = 16, }, true)
	end,
	on_death = function(self)
		local pos = self.object:get_pos()
		if pos then
			Sh.drop(pos)
		end
	end,
})

function Sh.spawn(node_pos, face)
	if not Sh.valid(face, node_pos) then
		return nil
	end
	local obj = core.add_entity(vector.offset(node_pos, 0, -0.5, 0), NAME, core.serialize({ face = face, }))
	return obj
end

-- The bullet steers along the axes towards its target, hits it for
-- BULLET_DAMAGE and LEVITATION seconds of levitation, and breaks when hit.
core.register_entity(BULLET, {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		collisionbox = { -0.16, -0.16, -0.16, 0.16, 0.16, 0.16, },
		visual = "mesh",
		mesh = "cb_mobs_dim_shulker_bullet.b3d",
		textures = { "cb_mobs_dim_shulker_bullet.png", "cb_mobs_dim_shulker_bullet.png^[opacity:50",
			"cb_mobs_dim_shulker_bullet.png^[opacity:50", },
		use_texture_alpha = true,
		visual_size = { x = 0.3125, y = 0.3125, },
		static_save = false,
		glow = 10,
	},
	_age = 0,
	_steer = 0,
	on_activate = function(self)
		self.object:set_animation({ x = 0, y = 120, }, 30)
	end,
	on_punch = function(self)
		self.object:remove()
		return true
	end,
	on_step = function(self, dtime)
		self._age = self._age + dtime
		self._steer = self._steer + dtime
		local pos = self.object:get_pos()
		local t = self._target
		local tp = t and t:get_pos()
		if not pos or self._age > Sh.BULLET_LIFE or not tp then
			self.object:remove()
			return
		end
		local aim = vector.offset(tp, 0, 1, 0)
		if vector.distance(pos, aim) < 1 then
			t:punch(self.object, 1, { full_punch_interval = 1, damage_groups = { fleshy = Sh.BULLET_DAMAGE, }, }, nil)
			if t:is_player() then
				cb_mobs_dim.levitate(t, Sh.LEVITATION)
			end
			self.object:remove()
			return
		end
		if self._steer >= 0.25 then
			self._steer = 0
			self.object:set_velocity(vector.multiply(vector.direction(pos, aim), Sh.BULLET_SPEED))
		end
		local node = core.registered_nodes[core.get_node(vector.round(pos)).name]
		if node and node.walkable ~= false and self._age > 0.5 then
			self.object:remove()
		end
	end,
})
