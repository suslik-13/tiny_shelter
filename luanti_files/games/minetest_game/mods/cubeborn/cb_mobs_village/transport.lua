-- Villagers ride boats and carts (spec cycle 5, 4.5). The boats and carts
-- mods' entities are wrapped, not edited: a moving boat or cart without a
-- passenger takes the first villager (adult or child, awake, not trading)
-- within REACH. A boat seats two: the villager at the back, the driver moves
-- to the front while it has one; a cart seats one, so a player cannot get
-- into a cart with a villager in it. The passenger gets out when the vehicle
-- is broken, removed or unloaded, or when a player right-clicks it. The
-- passenger lives in memory only (self._cb_passenger): a reloaded villager
-- is never attached, and is let go of where it ends up (V.released).
local V = cb_mobs_village
local TP = { EVERY = 0.5, REACH = 1.5, SPEED = 0.3, }
V.transport = TP
local NAME = "cb_mobs_village:villager"
local BOAT, CART = "boats:boat", "carts:cart"

-- Attachment offsets (1/10 node) of the passenger, and the boat driver's
-- seat while a villager rides along (the boats mod puts it at z = -3).
local SEAT = {
	[BOAT] = { pos = vector.new(0, 1, -4), driver = vector.new(0.5, 1, 3), driver_alone = vector.new(0.5, 1, -3), },
	[CART] = { pos = vector.new(0, -4.5, 0), },
}

local function passenger(self)
	local p = self._cb_passenger
	if p and p:get_pos() and p:get_attach() == self.object then
		return p
	end
	self._cb_passenger = nil
end
TP.passenger = passenger

local function driver_obj(self)
	return self.driver and core.get_player_by_name(self.driver)
end

local function seat_driver(self, alone)
	local d, seat = driver_obj(self), SEAT[self.name]
	if d and seat.driver and d:get_attach() == self.object then
		d:set_attach(self.object, "", alone and seat.driver_alone or seat.driver, vector.zero())
	end
end

function TP.seat(vehicle, villager)
	local self, e = vehicle:get_luaentity(), villager:get_luaentity()
	local seat = self and SEAT[self.name]
	if not seat or not e or e.name ~= NAME or passenger(self) or villager:get_attach()
			or (self.name == CART and self.driver) then
		return false
	end
	if e._sleeping then
		return false
	end
	villager:set_velocity(vector.zero())
	villager:set_attach(vehicle, "", seat.pos, vector.zero())
	e:set_animation("stand")
	self._cb_passenger = villager
	seat_driver(self, false)
	return true
end

-- The passenger stands next to the vehicle again.
function TP.unseat(self)
	local p = self._cb_passenger
	self._cb_passenger = nil
	if not (p and p:get_pos()) then
		return
	end
	if p:get_attach() == self.object then
		p:set_detach()
	end
	local at = self.object:get_pos() or p:get_pos()
	for _, d in ipairs({ vector.new(1, 0, 0), vector.new(-1, 0, 0), vector.new(0, 0, 1), vector.new(0, 0, -1), }) do
		local spot = vector.round(vector.add(at, d))
		local here, up = core.registered_nodes[core.get_node(spot).name], core.registered_nodes[core.get_node(
			vector.offset(spot, 0, 1, 0)).name]
		if here and not here.walkable and up and not up.walkable then
			at = spot
			break
		end
	end
	p:set_pos(vector.offset(at, 0, 0.5, 0))
	seat_driver(self, true)
end

local function rider_ok(e)
	return e and e.name == NAME and not e._sleeping and not e._trading and not e.object:get_attach()
end

local function pick_up(self, dtime)
	self._cb_seat_t = (self._cb_seat_t or 0) + dtime
	if self._cb_seat_t < TP.EVERY then
		return
	end
	self._cb_seat_t = 0
	if passenger(self) or (self.name == CART and self.driver) then
		return
	end
	local v = self.object:get_velocity()
	if not v or math.hypot(v.x, v.z) <= TP.SPEED then
		return
	end
	for _, obj in ipairs(core.get_objects_inside_radius(self.object:get_pos(), TP.REACH)) do
		if rider_ok(obj:get_luaentity()) and TP.seat(self.object, obj) then
			return
		end
	end
end

local function wrap(name)
	local def = core.registered_entities[name]
	if not def then
		return
	end
	local on_step, on_deactivate, on_rightclick = def.on_step, def.on_deactivate, def.on_rightclick
	def.on_step = function(self, dtime, ...)
		if on_step then
			on_step(self, dtime, ...)
		end
		if self.object:get_pos() then
			pick_up(self, dtime)
		end
	end
	def.on_deactivate = function(self, removal)
		if self._cb_passenger then
			TP.unseat(self)
		end
		if on_deactivate then
			on_deactivate(self, removal)
		end
	end
	def.on_rightclick = function(self, clicker, ...)
		-- one seat in a cart: taken by the villager
		if name == CART and passenger(self) then
			return
		end
		local r = on_rightclick and on_rightclick(self, clicker, ...)
		if name == BOAT and passenger(self) then
			seat_driver(self, false)
		end
		return r
	end
end

-- A right-click on a riding villager lets it out.
function TP.click(villager_ent)
	local parent = villager_ent.object:get_attach()
	local self = parent and parent:get_luaentity()
	if self and SEAT[self.name] and self._cb_passenger == villager_ent.object then
		TP.unseat(self)
		return true
	end
	return false
end

core.register_on_mods_loaded(function()
	wrap(BOAT)
	wrap(CART)
end)
