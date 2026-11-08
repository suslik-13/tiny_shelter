-- Splash and lingering potions (spec 4.4): a thrown bottle flies, breaks on
-- the first node or creature it meets and splashes everyone within RADIUS
-- (the closer, the stronger: 1 - d / RADIUS of the time or the instant
-- change); a lingering one leaves a cloud that hands out a quarter of the
-- time to whoever stands in it and shrinks away in CLOUD.TIME s. With PvP off
-- a player's potion reaches no other player, only the thrower. Lasting
-- effects reach players only; instant health and damage reach mobs too.
local CP = cb_potions
CP.SPLASH = { RADIUS = 4, SPEED = 10, GRAVITY = 8, LIFE = 15, }
CP.CLOUD = { TIME = 30, R = 3, EVERY = 0.5, SHARE = 0.25, }

local function is_player(obj)
	return obj.is_player and obj:is_player()
end

-- May this potion of thrower reach obj? Another player only with PvP on and
-- when no PvP mod (protector's areas, pvp_control's /peace) cancels a
-- harmless punch from the thrower.
local function reaches(obj, thrower_name, thrower)
	if not is_player(obj) or not thrower_name or obj:get_player_name() == thrower_name then
		return true
	end
	if not core.settings:get_bool("enable_pvp", true) then
		return false
	end
	thrower = thrower or core.get_player_by_name(thrower_name)
	if not thrower then
		return true
	end
	local caps = { full_punch_interval = 1, damage_groups = { fleshy = 0, }, }
	for _, fn in ipairs(core.registered_on_punchplayers) do
		local ok, cancel = pcall(fn, obj, thrower, 1, caps, vector.new(0, -1, 0), 0)
		if ok and cancel then
			return false
		end
	end
	return true
end

local function creature(obj)
	if is_player(obj) then
		return true
	end
	local e = obj.get_luaentity and obj:get_luaentity()
	return e ~= nil and e.health ~= nil
end

local function color(item)
	local kind = CP.parse(item)
	return kind and CP.KINDS[kind].color or "#ffffff"
end

local function particles(pos, item, r, time, amount)
	core.add_particlespawner({
		amount = amount, time = time,
		minpos = vector.offset(pos, -r, 0, -r), maxpos = vector.offset(pos, r, 0.5, r),
		minvel = vector.new(-0.3, 0.4, -0.3), maxvel = vector.new(0.3, 1, 0.3),
		minexptime = 0.6, maxexptime = 1.2, minsize = 1, maxsize = 2,
		texture = "cb_potions_effect_particle.png^[colorize:" .. color(item) .. ":200",
	})
end

-- objs: the creatures to consider (tests pass stand-ins); default: all near.
function CP.splash(pos, item, thrower, objs)
	local tname = thrower and is_player(thrower) and thrower:get_player_name() or nil
	objs = objs or core.get_objects_inside_radius(pos, CP.SPLASH.RADIUS)
	for _, obj in ipairs(objs) do
		local op = obj:get_pos()
		if op and creature(obj) and reaches(obj, tname, thrower) then
			local d = vector.distance(pos, op)
			local f = 1 - d / CP.SPLASH.RADIUS
			if f > 0 then
				CP.apply(obj, item, f)
			end
		end
	end
	particles(pos, item, 1.5, 0.3, 30)
	core.sound_play("cb_potions_splash", { pos = pos, max_hear_distance = 16, }, true)
end

core.register_entity("cb_potions:cloud", {
	initial_properties = { physical = false, collide_with_objects = false, pointable = false, visual = "sprite",
		textures = { "blank.png", }, static_save = true, },
	_item = "cb_potions:water", _left = 30, _t = 0, _thrower = nil,
	on_activate = function(self, staticdata)
		local d = core.deserialize(staticdata or "") or {}
		self._item, self._left, self._thrower = d.item or self._item, d.left or CP.CLOUD.TIME, d.thrower
		self._r0 = self._r0 or CP.CLOUD.R
	end,
	get_staticdata = function(self)
		return core.serialize({ item = self._item, left = self._left, thrower = self._thrower, })
	end,
	radius = function(self)
		return CP.CLOUD.R * math.max(0, self._left) / CP.CLOUD.TIME
	end,
	tick = function(self, dt, objs)
		self._left = self._left - dt
		if self._left <= 0 then
			self.object:remove()
			return
		end
		local pos, r = self.object:get_pos(), self:radius()
		objs = objs or core.get_objects_inside_radius(pos, r + 0.5)
		for _, obj in ipairs(objs) do
			local op = obj:get_pos()
			if op and creature(obj) and reaches(obj, self._thrower) and vector.distance(pos, op) <= r + 0.5 then
				-- instant health or damage once per creature, lasting effects kept up
				local key = is_player(obj) and obj:get_player_name() or tostring(obj)
				self._got = self._got or {}
				CP.apply(obj, self._item, CP.CLOUD.SHARE, self._got[key])
				self._got[key] = true
			end
		end
		particles(pos, self._item, r, CP.CLOUD.EVERY, math.max(2, math.floor(r * 6)))
	end,
	on_step = function(self, dtime)
		self._t = self._t + dtime
		if self._t >= CP.CLOUD.EVERY then
			local dt = self._t
			self._t = 0
			self:tick(dt)
		end
	end,
})

function CP.cloud(pos, item, thrower_name)
	return core.add_entity(pos, "cb_potions:cloud",
		core.serialize({ item = item, left = CP.CLOUD.TIME, thrower = thrower_name, }))
end

local function hit(self, pos)
	local thrower = self._thrower and core.get_player_by_name(self._thrower)
	local _, _, form = CP.parse(self._item)
	CP.splash(pos, self._item, thrower or (self._thrower and { is_player = function() return true end,
		get_player_name = function() return self._thrower end, }) or nil)
	if form == "lingering" then
		CP.cloud(pos, self._item, self._thrower)
	end
	self.object:remove()
end

core.register_entity("cb_potions:thrown", {
	initial_properties = { physical = false, collide_with_objects = false, pointable = false, visual = "wielditem",
		visual_size = { x = 0.25, y = 0.25, }, textures = { "cb_potions:water", }, static_save = true, },
	_item = "cb_potions:water", _age = 0,
	on_activate = function(self, staticdata)
		local d = core.deserialize(staticdata or "") or {}
		self._item, self._thrower, self._age = d.item or self._item, d.thrower, d.age or 0
		self.object:set_properties({ textures = { self._item, }, })
		self.object:set_acceleration(vector.new(0, -CP.SPLASH.GRAVITY, 0))
	end,
	get_staticdata = function(self)
		return core.serialize({ item = self._item, thrower = self._thrower, age = self._age, })
	end,
	on_step = function(self, dtime)
		self._age = self._age + dtime
		local pos = self.object:get_pos()
		if self._age > CP.SPLASH.LIFE then
			self.object:remove()
			return
		end
		local node = core.registered_nodes[core.get_node(pos).name]
		if not node or node.walkable or node.liquidtype ~= "none" then
			return hit(self, pos)
		end
		for _, obj in ipairs(core.get_objects_inside_radius(pos, 0.9)) do
			if obj ~= self.object and creature(obj) then
				local own = is_player(obj) and obj:get_player_name() == self._thrower
				if not (own and self._age < 0.4) then
					return hit(self, pos)
				end
			end
		end
	end,
})

-- The item's use: throw it where the player looks.
function CP.throw(itemstack, user)
	local props = user.get_properties and user:get_properties() or {}
	local pos = vector.offset(user:get_pos(), 0, props.eye_height or 1.47, 0)
	local dir = user:get_look_dir()
	local obj = core.add_entity(pos, "cb_potions:thrown",
		core.serialize({ item = itemstack:get_name(), thrower = user:get_player_name(), }))
	if not obj then
		return itemstack
	end
	obj:set_velocity(vector.add(vector.multiply(dir, CP.SPLASH.SPEED), vector.new(0, 2, 0)))
	core.sound_play("cb_items_throw", { pos = pos, max_hear_distance = 16, }, true)
	if not core.is_creative_enabled(user:get_player_name()) then
		itemstack:take_item()
	end
	return itemstack
end
