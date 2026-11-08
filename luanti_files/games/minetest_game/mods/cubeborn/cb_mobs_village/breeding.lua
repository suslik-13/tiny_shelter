-- Breeding (spec cycle 3, 3.2-3.3). A child is the villager entity with
-- _child and _born (game time); mobs_redo's child flag gives the half size
-- on activation, its own hornytimer growth is held off by the step.
local BR = { GROW = 1200, CHILD_SPEED = 1.5, }
cb_mobs_village.breeding = BR
local NAME = "cb_mobs_village:villager"

function BR.child_props(self)
	local box = cb_mobs_village.BOX
	local half = {}
	for i = 1, 6 do
		half[i] = box[i] * 0.5
	end
	local size = self.base_size or { x = 1, y = 1, }
	self.object:set_properties({ visual_size = { x = size.x * 0.5, y = size.y * 0.5, }, collisionbox = half,
		selectionbox = half, })
	self.walk_velocity = BR.CHILD_SPEED
end

function BR.spawn_child(pos, bed)
	local obj = core.add_entity(pos, NAME)
	local ent = obj and obj:get_luaentity()
	if not ent then
		return nil
	end
	ent._child, ent.child, ent._born, ent._bed = true, true, core.get_gametime(), bed
	ent._nitwit = false
	BR.child_props(ent)
	cb_mobs_village.reserve(bed, ent, BR.CHILD_HOLD)
	return ent
end

function BR.grown(self)
	return self._child and core.get_gametime() - (self._born or 0) >= BR.GROW
end

function BR.grow(self)
	self._child, self._born, self.child, self.hornytimer = nil, nil, false, 0
	self.walk_velocity = nil -- back to the class value
	self.object:set_properties({ visual_size = self.base_size, collisionbox = self.base_colbox,
		selectionbox = self.base_selbox, })
	self._nitwit = math.random() < cb_mobs_village.professions.NITWIT
	cb_mobs_village.retexture(self, "villager")
end

BR.EVERY, BR.R, BR.WAIT, BR.PAUSE = 5, 8, 5, 300
-- no free bed: wait NO_BED s; a newborn holds its bed CHILD_HOLD s (it walks home)
BR.NO_BED, BR.CHILD_HOLD = 60, 120

-- The village box (cb_structures sets this), else nil.
cb_mobs_village.village_at = cb_mobs_village.village_at or function() return nil end

local function free(bed)
	return core.get_node(bed).name == "beds:bed_bottom" and not cb_mobs_village.claimed(bed, nil)
		and core.get_node(vector.offset(bed, 0, 1, 0)).name == "air"
		and core.get_node(vector.offset(bed, 0, 2, 0)).name == "air"
end

-- A bed of the village nobody holds; no village, no bed: villagers breed
-- only in a village with a bell (spec cycle 5, 2.9).
function BR.free_bed(self)
	local pos = self.object:get_pos()
	local village = cb_mobs_village.village_at(pos)
	if not village then
		return nil
	end
	local beds = table.copy(village.beds)
	table.sort(beds, function(x, y) return vector.distance(x, pos) < vector.distance(y, pos) end)
	for _, bed in ipairs(beds) do
		if free(bed) then
			return bed
		end
	end
end

local mate = setmetatable({}, { __mode = "k", })

function BR.partner(self)
	return mate[self]
end

local function willing(e, now)
	return e and e.name == NAME and not e._child and not e._sleeping and not e._trading and not mate[e]
		and (e._pause or 0) <= now and cb_mobs_village.food.ready(e) and e.object:get_pos() ~= nil
end

local function hearts(e)
	core.add_particlespawner({ amount = 6, time = BR.WAIT, attached = e.object,
		minpos = vector.new(-0.3, 1.8, -0.3), maxpos = vector.new(0.3, 2.2, 0.3),
		minvel = vector.new(0, 0.5, 0), maxvel = vector.new(0, 1, 0), minexptime = 1, maxexptime = 1.5,
		texture = "mobs_heart_particle.png", glow = 4, })
end

local function stop(e)
	if e then
		if e._mate_bed then
			cb_mobs_village.release(e._mate_bed, e)
		end
		mate[e], e._mate_until, e._mate_bed = nil, nil, nil
	end
end

-- Ends any courting (night, the bell, a monster).
function BR.cancel(self)
	local p = mate[self]
	if p then
		stop(self)
		stop(p)
	end
end

-- Daytime adults (the caller checks). true while courting: stand still.
function BR.tick(self, dt)
	local now = core.get_gametime()
	local p = mate[self]
	if p then
		local pp = p.object and p.object:get_pos()
		if not pp or mate[p] ~= self or p._sleeping or now > (self._mate_until or 0) + 2
				or vector.distance(pp, self.object:get_pos()) > BR.R + 2 then
			stop(self)
			stop(p)
			return false
		end
		if self._mate_bed and now >= self._mate_until then
			-- the initiator finishes
			local bed = self._mate_bed
			cb_mobs_village.release(bed, self)
			self._mate_bed = nil
			if free(bed) and cb_mobs_village.food.ready(self) and cb_mobs_village.food.ready(p) then
				local mid = vector.divide(vector.add(self.object:get_pos(), p.object:get_pos()), 2)
				if BR.spawn_child(vector.offset(mid, 0, 0.3, 0), bed) then
					cb_mobs_village.food.consume(self)
					cb_mobs_village.food.consume(p)
					self._pause, p._pause = now + BR.PAUSE, now + BR.PAUSE
				end
			end
			stop(self)
			stop(p)
			return false
		end
		cb_mobs_village.face(self, p.object:get_pos())
		return true
	end
	self._breed_t = (self._breed_t or 0) + dt
	if self._breed_t < BR.EVERY then
		return false
	end
	self._breed_t = 0
	if not willing(self, now) then
		return false
	end
	for _, obj in ipairs(core.get_objects_inside_radius(self.object:get_pos(), BR.R)) do
		local e = obj:get_luaentity()
		if e ~= self and willing(e, now) then
			local bed = BR.free_bed(self)
			if not bed then
				self._breed_t = -BR.NO_BED
				return false
			end
			mate[self], self._mate_until, self._mate_bed = e, now + BR.WAIT, bed
			cb_mobs_village.reserve(bed, self, BR.WAIT + 2)
			mate[e], e._mate_until = self, now + BR.WAIT
			cb_mobs_village.seek_end(self)
			cb_mobs_village.seek_end(e)
			hearts(self)
			hearts(e)
			return true
		end
	end
	BR.seek(self, now)
	return false
end

-- No partner in reach: walks to the nearest ready one further off, if there is
-- a free bed.
function BR.seek(self, now)
	local V = cb_mobs_village
	if not V.may_seek(self, now) then
		return
	end
	local pos, best, bd = self.object:get_pos(), nil, nil
	for _, obj in ipairs(core.get_objects_inside_radius(pos, V.SEEK_R)) do
		local e = obj:get_luaentity()
		if e ~= self and willing(e, now) then
			local d = vector.distance(pos, obj:get_pos())
			if not bd or d < bd then
				best, bd = obj, d
			end
		end
	end
	if best and BR.free_bed(self) then
		V.seek(self, best, "mate", now)
	else
		self._seek_next = now + V.SEEK_RETRY
	end
end
