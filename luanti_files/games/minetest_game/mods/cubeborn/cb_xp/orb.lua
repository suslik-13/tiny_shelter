-- Experience orbs: rewards drop as orbs that fly to the nearest living player
-- within 8 nodes; nearby orbs merge; an orb lives 5 minutes and is never
-- saved. Dying costs a quarter of the experience and drops all of it.
local X = cb_xp
X.ORB = "cb_xp:orb"
X.SIZES = { 1, 3, 7, 17, 37, 73, 149, 307, 617, 1237, 2477, }
local TICK, LIFE, PULL, MAX = 0.25, 300, 8, 20

-- Orb values summing to n, biggest first, at most MAX of them.
function X.split(n)
	local out = {}
	while n > 0 do
		if #out == MAX - 1 then
			out[#out + 1] = n
			break
		end
		local v = 1
		for _, s in ipairs(X.SIZES) do
			if s <= n then
				v = s
			end
		end
		out[#out + 1] = v
		n = n - v
	end
	return out
end

local function look(ent)
	local k = 1
	for i, s in ipairs(X.SIZES) do
		if ent._xp >= s then
			k = i
		end
	end
	local size = 0.25 + 0.04 * k
	ent.object:set_properties({ visual_size = { x = size, y = size, },
		textures = { "cb_xp_orb.png^[verticalframe:14:" .. math.min(13, k - 1), }, })
end

-- fn(name, points) -> points left for the player (Mending takes some).
X.registered_on_collect = {}
function X.register_on_collect(fn)
	table.insert(X.registered_on_collect, fn)
end

function X.collect(ent, name)
	if ent._xp > 0 then
		local points = ent._xp
		for _, fn in ipairs(X.registered_on_collect) do
			points = fn(name, points) or points
		end
		X.add(name, points)
		core.sound_play("cb_xp_pickup", { to_player = name, gain = 0.4, pitch = 0.9 + math.random() * 0.3, }, true)
	end
	ent._xp = 0
	ent.object:remove()
end

function X.merge(ent)
	local pos = ent.object:get_pos()
	for _, obj in ipairs(core.get_objects_inside_radius(pos, 1)) do
		local other = obj:get_luaentity()
		if other and other ~= ent and other.name == X.ORB and other._xp > 0 then
			ent._xp, other._xp = ent._xp + other._xp, 0
			obj:remove()
		end
	end
	look(ent)
end

local function nearest_player(pos)
	local best, bd
	for _, obj in ipairs(core.get_objects_inside_radius(pos, PULL)) do
		if obj:is_player() and obj:get_hp() > 0 then
			local d = vector.distance(pos, obj:get_pos())
			if not bd or d < bd then
				best, bd = obj, d
			end
		end
	end
	return best, bd
end

core.register_entity(X.ORB, {
	initial_properties = {
		physical = true, collide_with_objects = false, pointable = false, static_save = false,
		collisionbox = { -0.1, -0.1, -0.1, 0.1, 0.1, 0.1, }, visual = "sprite", visual_size = { x = 0.3, y = 0.3, },
		textures = { "cb_xp_orb.png^[verticalframe:14:0", }, glow = 10,
	},
	on_activate = function(self)
		self._xp, self._age, self._t = self._xp or 1, 0, 0
		self.object:set_acceleration({ x = 0, y = -9.81, z = 0, })
		look(self)
	end,
	on_step = function(self, dtime)
		self._age, self._t = self._age + dtime, self._t + dtime
		if self._age > LIFE or self._xp <= 0 then
			self.object:remove()
			return
		end
		if self._t < TICK then
			return
		end
		self._t = 0
		local pos = self.object:get_pos()
		local player, d = nearest_player(pos)
		if player and d <= 1 then
			X.collect(self, player:get_player_name())
		elseif player then
			local to = vector.subtract(vector.offset(player:get_pos(), 0, 0.8, 0), pos)
			self.object:set_acceleration(vector.zero())
			self.object:set_velocity(vector.multiply(vector.normalize(to), 6))
		else
			local v = self.object:get_velocity()
			self.object:set_acceleration({ x = 0, y = -9.81, z = 0, })
			self.object:set_velocity({ x = v.x * 0.5, y = v.y, z = v.z * 0.5, })
			X.merge(self)
		end
	end,
})

function X.drop(pos, n)
	for _, v in ipairs(X.split(n)) do
		local obj = core.add_entity(vector.offset(pos, math.random() * 0.4 - 0.2, 0.3, math.random() * 0.4 - 0.2), X.ORB)
		local ent = obj and obj:get_luaentity()
		if ent then
			ent._xp = v
			look(ent)
			obj:set_velocity({ x = math.random() * 2 - 1, y = 2 + math.random() * 2, z = math.random() * 2 - 1, })
		end
	end
end

function X.on_death(name, pos)
	if X.is_admin(name) then
		return 0
	end
	local loss = math.floor(X.get(name) / 4)
	if loss == 0 then
		return 0
	end
	X.add(name, -loss)
	X.drop(pos, loss)
	return loss
end

core.register_on_dieplayer(function(player)
	X.on_death(player:get_player_name(), player:get_pos())
end)

X.register_on_change(function(name, old, new)
	if new > old and X.level_of(new) > X.level_of(old) and core.get_player_by_name(name) then
		core.sound_play("cb_xp_level_up", { to_player = name, gain = 0.6, }, true)
	end
end)
