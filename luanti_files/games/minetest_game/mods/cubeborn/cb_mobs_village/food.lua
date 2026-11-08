-- Villager food (spec cycle 3, 3.1): counts per kind in _food (not an
-- inventory), picked up from dropped items within PICK_R every PICK_EVERY s.
-- Ready to breed at NEED points (bread 4, carrot/potato/beetroot 1). Farmers
-- also take wheat and seeds and bake 3 wheat into bread; a villager with
-- more than NEED points throws the surplus to a neighbour short of NEED.
local F = { NEED = 12, CAP = 64, PICK_EVERY = 2, PICK_R = 2, SHARE_EVERY = 30, SHARE_R = 8, HAND_R = 3, THROW_T = 0.85, OWN_ITEM = 3, }
cb_mobs_village.food = F
F.ITEM = { bread = "farming:bread", carrot = "farming:carrot", potato = "farming:potato",
	beetroot = "farming:beetroot", wheat = "farming:wheat", seeds = "farming:seed_wheat", }
F.ITEMS = {}
for kind, name in pairs(F.ITEM) do
	F.ITEMS[name] = kind
end
F.POINTS = { bread = 4, carrot = 1, potato = 1, beetroot = 1, }
local SPEND = { "bread", "carrot", "potato", "beetroot", }
local FARMER_ONLY = { wheat = true, seeds = true, }

function F.count(self, kind)
	return self._food and self._food[kind] or 0
end

function F.add(self, kind, n)
	self._food = self._food or {}
	local have = self._food[kind] or 0
	local put = math.max(0, math.min(n, F.CAP - have))
	if put > 0 then
		self._food[kind] = have + put
	end
	return put
end

function F.take(self, kind, n)
	local have = F.count(self, kind)
	if have < n then
		return false
	end
	self._food[kind] = have - n > 0 and have - n or nil
	return true
end

function F.points(self)
	local n = 0
	for kind, p in pairs(F.POINTS) do
		n = n + F.count(self, kind) * p
	end
	return n
end

function F.ready(self)
	return F.points(self) >= F.NEED
end

function F.consume(self)
	local need = F.NEED
	for _, kind in ipairs(SPEND) do
		while need > 0 and F.take(self, kind, 1) do
			need = need - F.POINTS[kind]
		end
	end
end

local function wants(self, kind)
	return kind ~= nil and core.registered_items[F.ITEM[kind]] ~= nil
		and (not FARMER_ONLY[kind] or self._prof == "farmer")
end

function F.pick(self)
	local now = core.get_gametime()
	for _, obj in ipairs(core.get_objects_inside_radius(self.object:get_pos(), F.PICK_R)) do
		local e = obj:get_luaentity()
		if e and e.name == "__builtin:item" and not (e._cb_thrower == self and now - (e._cb_thrown or 0) < F.OWN_ITEM) then
			local st = ItemStack(e.itemstring)
			local kind = F.ITEMS[st:get_name()]
			if wants(self, kind) then
				local put = F.add(self, kind, st:get_count())
				if put >= st:get_count() then
					obj:remove()
				elseif put > 0 then
					st:set_count(st:get_count() - put)
					e:set_item(st)
				end
			end
		end
	end
end

function F.bake(self)
	if self._prof == "farmer" and F.count(self, "wheat") >= 3 then
		local n = math.floor(F.count(self, "wheat") / 3)
		n = F.add(self, "bread", n)
		F.take(self, "wheat", n * 3)
	end
end

-- The adult within r that lacks most of NEED, and how much it lacks.
local function neediest(self, pos, r)
	local target, lacking = nil, 0
	for _, obj in ipairs(core.get_objects_inside_radius(pos, r)) do
		local e = obj:get_luaentity()
		if e and e ~= self and e.name == self.name and not e._child and F.NEED - F.points(e) > lacking then
			target, lacking = obj, F.NEED - F.points(e)
		end
	end
	return target, lacking
end

-- Nobody short of food in reach: walks to one further off, if a child could
-- come of it (a free bed).
local function seek(self, pos)
	local V, now = cb_mobs_village, core.get_gametime()
	if V.may_seek(self, now) then
		local target = neediest(self, pos, V.SEEK_R)
		if target and V.breeding.free_bed(self) then
			V.seek(self, target, "food", now)
		else
			self._seek_next = now + V.SEEK_RETRY
		end
	end
end

-- Throws what is above NEED (whole items, bread first) to the neighbour that
-- lacks most of it; no more than that neighbour lacks. Thrown to land at its
-- feet; one that walked over comes close first: a neighbour on the move misses
-- a long throw.
function F.share(self)
	local surplus = F.points(self) - F.NEED
	if surplus <= 0 then
		return
	end
	local pos = self.object:get_pos()
	local walking = self._goal and self._goal.seek == "food"
	local target, lacking = neediest(self, pos, walking and F.HAND_R or F.SHARE_R)
	if not target then
		if not walking then
			seek(self, pos)
		end
		return
	end
	if walking then
		cb_mobs_village.seek_stay(self)
	end
	local at = target:get_pos()
	local speed = math.min(vector.distance(pos, at) / F.THROW_T, F.SHARE_R / F.THROW_T)
	for _, kind in ipairs(SPEND) do
		local p = F.POINTS[kind]
		local n = math.min(F.count(self, kind), math.ceil(lacking / p), math.floor(surplus / p))
		if n > 0 and F.take(self, kind, n) then
			local item = core.add_item(vector.offset(pos, 0, 1, 0), ItemStack(F.ITEM[kind] .. " " .. n))
			if item then
				local ie = item:get_luaentity()
				ie._cb_thrower, ie._cb_thrown = self, core.get_gametime()
				local dir = vector.direction(pos, at)
				item:set_velocity(vector.new(dir.x * speed, 3, dir.z * speed))
			end
			surplus, lacking = surplus - n * p, lacking - n * p
		end
	end
end

-- From the villager's step (adults only).
function F.tick(self, dt)
	self._pick_t = (self._pick_t or 0) + dt
	if self._pick_t >= F.PICK_EVERY then
		self._pick_t = 0
		F.pick(self)
		F.bake(self)
		if self._goal and self._goal.seek == "food" then
			F.share(self) -- on the way: throw once in reach
		end
	end
	self._share_t = (self._share_t or 0) + dt
	if self._share_t >= F.SHARE_EVERY then
		self._share_t = 0
		F.share(self)
	end
end
