-- Villager (spec cycle 2, 3.3; cycle 5): by day goes out to its job site or
-- the bell, idlers go out and come back in turns; doors on the way are opened
-- and shut behind; sleeps in its own bed at night
-- (0.79-0.23) and stays home for a minute after the bell; flees from monsters
-- through mobs_redo's runaway. Professions and trading: professions.lua,
-- trading.lua, trade_ui.lua.
-- Cost: the behaviour runs in do_custom of active villagers only, every
-- 0.5 s; find_path at most every 10 s per villager, range 32.
local S = cb_mobs_village.S
local V = cb_mobs_village
V.HOME_RADIUS, V.BED_SEARCH, V.PATH_EVERY, V.PATH_RANGE, V.CALLED, V.CLAIM_EVERY = 16, 16, 10, 32, 60, 10
-- A route may drop less than fear_height: mobs_redo halts a villager at a deeper
-- drop for good (a stairwell's edge upstairs: it never came down).
V.PATH_DROP = 2
V.death_hooks, V.punch_hooks = {}, {}
V.BOX = { -0.25, 0, -0.25, 0.25, 1.9, 0.25, }
V.SLEEP_BOX = { -0.25, 0, -0.25, 0.25, 0.3, 0.25, }
local NAME, BED = "cb_mobs_village:villager", "beds:bed_bottom"
local SIDES = { { 1, 0, }, { -1, 0, }, { 0, 1, }, { 0, -1, }, }

function V.night()
	local t = core.get_timeofday()
	return t >= 0.79 or t < 0.23
end

function V.texture(kind, vtype)
	return "cb_mobs_village_" .. kind .. "_base.png^cb_mobs_village_" .. kind .. "_" .. (vtype or "plains") .. ".png"
end

-- A drop entry only for items this server has.
function V.drop(name, min, max)
	if core.registered_items[name] then
		return { name = name, chance = 1, min = min, max = max, }
	end
end

function V.drops(list)
	local out = {}
	for _, d in ipairs(list) do
		out[#out + 1] = V.drop(d[1], d[2], d[3])
	end
	return out
end

local function node_pos(p)
	return vector.new(math.floor(p.x + 0.5), math.floor(p.y + 0.5), math.floor(p.z + 0.5))
end

local function is_bed(p)
	return p ~= nil and core.get_node(p).name == BED
end

function V.bed_side(bed)
	for _, d in ipairs(SIDES) do
		local p = vector.offset(bed, d[1], 0, d[2])
		if core.get_node(p).name == "air" and core.get_node(vector.offset(p, 0, 1, 0)).name == "air" then
			return p
		end
	end
	return vector.offset(bed, 0, 1, 0)
end

-- Beds held for a while beyond the claim scan (breeding): node hash ->
-- { owner, untl = gametime }. Memory only.
V.reserved = {}

function V.reserve(bed, owner, secs)
	V.reserved[core.hash_node_position(bed)] = { owner = owner, untl = core.get_gametime() + secs, }
end

function V.release(bed, owner)
	local h = core.hash_node_position(bed)
	local r = V.reserved[h]
	if r and r.owner == owner then
		V.reserved[h] = nil
	end
end

function V.claimed(bed, self)
	local h = core.hash_node_position(bed)
	local r = V.reserved[h]
	if r then
		if r.untl <= core.get_gametime() then
			V.reserved[h] = nil
		elseif r.owner ~= self then
			return true
		end
	end
	for _, obj in ipairs(core.get_objects_inside_radius(bed, 32)) do
		local e = obj:get_luaentity()
		if e and e ~= self and e.name == NAME and ((e._bed and vector.equals(e._bed, bed))
				or (e._mate_bed and vector.equals(e._mate_bed, bed))) then
			return true
		end
	end
	return false
end

-- Keeps the villager's bed while it stands; else the nearest bed nobody
-- active has claimed within 16 nodes (4 up and down).
function V.claim(self)
	if is_bed(self._bed) then
		return self._bed
	end
	self._bed = nil
	local pos = self.object:get_pos()
	local r = V.BED_SEARCH
	local beds = core.find_nodes_in_area(vector.offset(pos, -r, -4, -r), vector.offset(pos, r, 4, r), { BED, })
	table.sort(beds, function(a, b)
		return vector.distance(a, pos) < vector.distance(b, pos)
	end)
	for _, b in ipairs(beds) do
		if not V.claimed(b, self) then
			self._bed = b
			return b
		end
	end
end

function V.sleep(self)
	local bed = self._bed
	local dir = core.facedir_to_dir(core.get_node(bed).param2)
	self.object:set_velocity(vector.zero())
	self.object:set_pos(vector.offset(vector.add(bed, vector.multiply(dir, 0.5)), 0, 0.1, 0))
	self.object:set_yaw(core.dir_to_yaw(dir))
	self.object:set_properties({ collisionbox = V.SLEEP_BOX, })
	self:set_animation("sleep", true)
	self._sleeping, self.state = true, "stand"
end

function V.wake(self)
	self._sleeping = false
	self.object:set_properties({ collisionbox = V.BOX, })
	if self._child then
		cb_mobs_village.breeding.child_props(self)
	end
	if self._bed then
		self.object:set_pos(V.bed_side(self._bed))
	end
	self:set_animation("stand", true)
end

-- Carried off (spec cycle 5, 4.5): on a lead (leads mod) or riding
-- something. Once let go more than FORGET_NEAR from its bed, a villager
-- forgets the bed and takes the nearest free one; more than FORGET_FAR away
-- it forgets it anyway. A job site farther than the profession radius from
-- the new bed is given up too.
V.FORGET_NEAR, V.FORGET_FAR = 16, 48
V.BED_REACH = 2.2

function V.carried(self)
	if self.object:get_attach() then
		return true
	end
	if not (rawget(_G, "leads") and leads.leads_by_connector and leads.leads_by_connector[self.object]) then
		return false
	end
	for _ in leads.find_connected_leads(self.object, false, true) do
		return true
	end
	return false
end

local function forget_bed(self)
	self._bed, self._goal, self._path, self._home = nil, nil, nil, nil
	V.claim(self)
	local P = cb_mobs_village.professions
	if self._job and P and (not self._bed or vector.distance(self._job, self._bed) > P.RADIUS) then
		P.lose_job(self)
	end
end

function V.released(self)
	local pos = self.object:get_pos()
	if pos and (not self._bed or vector.distance(pos, self._bed) > V.FORGET_NEAR) then
		forget_bed(self)
	end
end

local function monster_near(self)
	for _, obj in ipairs(core.get_objects_inside_radius(self.object:get_pos(), 8)) do
		local e = obj:get_luaentity()
		if e and e._cmi_is_mob and e.type == "monster" then
			return true
		end
	end
	return false
end

-- Turns towards pos. mobs_redo's yaw_to_pos faces the wrong way when pos has
-- exactly the same x (atan of an infinite slope), which walking a path along
-- z often gives.
function V.face(self, pos)
	local from = self.object:get_pos()
	local dx, dz = pos.x - from.x, pos.z - from.z
	if dx ~= 0 or dz ~= 0 then
		self.object:set_yaw(core.dir_to_yaw(vector.new(dx, 0, dz)) - (self.rotate or 0))
	end
end

-- Wooden doors a route may pass (spec cycle 5, 4.1): find_path sees every
-- door as a wall, so when there is no plain route, up to DOOR_TRIES doors
-- within DOOR_R of the villager or the goal are tried, nearest to the
-- straight line first: a path to the door's near side, the doorway, its far
-- side. One door per route; from the far side a new route is found.
V.DOOR_R, V.DOOR_TRIES = 8, 2

local function door_route(self, pos, goal)
	local D = cb_core.doors
	if not D then
		return nil
	end
	local seen, list = {}, {}
	for _, from in ipairs({ goal, pos, }) do
		for _, d in ipairs(D.near(from, V.DOOR_R)) do
			local h = core.hash_node_position(d)
			if not seen[h] then
				seen[h] = true
				list[#list + 1] = { p = d, cost = vector.distance(pos, d) + vector.distance(d, goal), }
			end
		end
	end
	table.sort(list, function(a, b) return a.cost < b.cost end)
	for i = 1, math.min(V.DOOR_TRIES, #list) do
		local d = list[i].p
		local a, b = D.sides(d)
		if vector.distance(b, pos) < vector.distance(a, pos) then
			a, b = b, a
		end
		local path = core.find_path(node_pos(pos), a, V.PATH_RANGE, 1, V.PATH_DROP, "A*_noprefetch")
		if path then
			path[#path + 1] = d
			path[#path + 1] = b
			return path, { p = d, a = a, b = b, t = core.get_gametime(), }
		end
	end
end

-- After a door: closes it when this villager opened it, has gone through
-- and nobody stands in the doorway.
local function door_behind(self, pos)
	local held = self._door
	if not held then
		return
	end
	-- through it without stepping on the far side's cell, or given up on it
	if not held.passed and (vector.distance(pos, held.b) + 0.5 < vector.distance(pos, held.a)
			or core.get_gametime() - held.t > 30) then
		held.passed = true
	end
	if held.passed and math.hypot(pos.x - held.p.x, pos.z - held.p.z) >= 1.4 then
		if held.opened and cb_core.doors.is_open(held.p) and not cb_core.doors.occupied(held.p, self.object) then
			cb_core.doors.close(held.p)
		end
		self._door = nil
	end
end
V.door_behind = door_behind

-- find_path cannot start in a doorway (a door is a wall to it): when pos is in one,
-- the side of the door with a route to the goal. Without this a villager whose route
-- ran out there pushed straight at the goal, and two met in the door for good.
local function door_exit(pos, goal)
	local D = cb_core.doors
	local here = node_pos(pos)
	if not (D and D.bottom(here) and D.wooden(here)) then
		return nil
	end
	local a, b = D.sides(here)
	if not D.is_open(here) then
		D.open(here)
	end
	if vector.distance(b, goal) < vector.distance(a, goal) then
		a, b = b, a
	end
	return core.find_path(a, goal, V.PATH_RANGE, 1, V.PATH_DROP, "A*_noprefetch") and a or b
end

-- Follows a find_path route (recomputed every PATH_EVERY s, and right after
-- a door) to the side of the bed; through a wooden door when it must; straight
-- on when there is no route at all (walls still stop it). True once the
-- route is walked.
local function walk_to(self, target, dt, exact)
	local pos = self.object:get_pos()
	door_behind(self, pos)
	self._path_t = (self._path_t or V.PATH_EVERY) + dt
	local going = self._door and not self._door.passed
	if not self._path or self._path_t >= V.PATH_EVERY * (going and 2 or 1) then
		if going then
			self._door.passed = true -- gave up on it: shut it once away
		end
		self._path_t = 0
		local goal = exact and target or V.bed_side(target)
		local side = door_exit(pos, goal)
		if side then
			self._path, self._wp, self._path_t = { side, }, 1, V.PATH_EVERY - 2 -- a real route from there
			if self._door then
				self._door.passed = true
			end
			V.face(self, side)
			self:set_velocity(self.walk_velocity)
			self:set_animation("walk")
			return
		end
		local path = core.find_path(node_pos(pos), goal, V.PATH_RANGE, 1, V.PATH_DROP, "A*_noprefetch")
		if not path then
			local door
			path, door = door_route(self, pos, goal)
			local held = self._door
			if door and held and vector.equals(held.p, door.p) then
				door.opened = held.opened -- the same door again: still ours to shut
			elseif held and not held.passed then
				held.passed = true -- another way now: shut it once away
			end
			if door then
				self._door = door
			end
		end
		self._path = path or { goal, }
		self._wp = 1
	end
	local held = self._door
	local wp = self._path[self._wp]
	while wp and math.abs(wp.x - pos.x) + math.abs(wp.z - pos.z) < 0.6 do
		if held and held.b and not held.rerouted and vector.equals(wp, held.b) then
			held.passed, held.rerouted = true, true
			self._path = nil -- a new route from this side
		end
		self._wp = self._wp + 1
		wp = self._path and self._path[self._wp]
	end
	if held and not held.passed and wp and vector.equals(wp, held.p) and not cb_core.doors.is_open(held.p) then
		held.opened = cb_core.doors.open(held.p)
	end
	if not wp then
		self:set_velocity(0)
		self:set_animation("stand")
		return true
	end
	V.face(self, wp)
	self:set_velocity(self.walk_velocity)
	self:set_animation("walk")
end
V.walk_to = walk_to

-- The day (spec cycle 5, 4.2): a goal at a time, {pos, kind, untl}. Workers
-- spend WORK_T at their job site and now and then a minute at the bell;
-- idlers (no job, nitwits, children) take turns outside (OUT_T, a spot in
-- daylight near the bell, else near the bed) and at home (IN_T). At the goal
-- mobs_redo's wandering takes over; more than GOAL_LEASH away, back to it.
V.WORK_T, V.OUT_T, V.IN_T, V.BELL_T, V.GOAL_LEASH = { 120, 300, }, { 90, 240, }, { 45, 120, }, 60, 6

local function span(t)
	return math.random(t[1], t[2])
end

function V.bell_near(pos)
	local r = 24
	return core.find_nodes_in_area(vector.offset(pos, -r, -6, -r), vector.offset(pos, r, 6, r), { "group:cb_bell", })[1]
end

local function stand_spot(x, z, y0)
	for y = y0 + 4, y0 - 4, -1 do
		local p = vector.new(x, y, z)
		local below = core.registered_nodes[core.get_node(vector.offset(p, 0, -1, 0)).name]
		local here = core.registered_nodes[core.get_node(p).name]
		local up = core.registered_nodes[core.get_node(vector.offset(p, 0, 1, 0)).name]
		if below and below.walkable and here and not here.walkable and (here.liquidtype or "none") == "none"
				and up and not up.walkable then
			return p
		end
	end
end

-- A spot under the open sky: 6-20 from the bell, else 6-12 from the bed.
function V.out_spot(self)
	local bell = V.bell_near(self._bed)
	local center, r1, r2 = bell or self._bed, 6, bell and 20 or 12
	for _ = 1, 6 do
		local a, d = math.random() * 2 * math.pi, r1 + math.random() * (r2 - r1)
		local p = stand_spot(math.floor(center.x + math.cos(a) * d + 0.5), math.floor(center.z + math.sin(a) * d + 0.5),
			center.y)
		if p and (core.get_natural_light(p, 0.5) or 0) >= 14 then
			return p
		end
	end
end

function V.day_goal(self)
	local now, prev = core.get_gametime(), self._goal and self._goal.kind
	if self._job ~= nil and not self._nitwit and not self._child then
		local bell = prev == "work" and math.random(4) == 1 and V.bell_near(self._bed)
		if bell then
			return { pos = bell, kind = "bell", untl = now + V.BELL_T, }
		end
		return { pos = self._job, kind = "work", untl = now + span(V.WORK_T), }
	end
	local spot = prev ~= "out" and V.out_spot(self)
	if spot then
		return { pos = spot, kind = "out", untl = now + span(V.OUT_T), }
	end
	return { pos = self._bed, kind = "home", untl = now + span(V.IN_T), }
end

local function working(self)
	return self._job ~= nil and not self._nitwit and not self._child
end

-- A walk to a neighbour too far off to meet by chance (BACKLOG 46): to hand
-- over food or to find a partner. It takes the place of the current goal for
-- SEEK_T s (1 node/s) and follows the neighbour (walk_to takes up the new spot
-- on its next route); the next try, reached or not, after SEEK_EVERY s, after
-- SEEK_RETRY s when there was nobody to go to.
V.SEEK_R, V.SEEK_T, V.SEEK_EVERY, V.SEEK_RETRY, V.SEEK_STAY = 32, 60, 120, 30, 15

function V.may_seek(self, now)
	return self._bed ~= nil and not V.night() and (self._called or 0) <= now and (self._seek_next or 0) <= now
end

-- Who each walks to: not in _goal, mobs_redo saves that with the entity.
local seek_to = setmetatable({}, { __mode = "k", })

function V.seek(self, target, what, now)
	seek_to[self] = target
	self._goal = { pos = node_pos(target:get_pos()), kind = working(self) and "bell" or "out", untl = now + V.SEEK_T,
		seek = what, }
	self._path, self._crop = nil, nil
	self._seek_next = now + V.SEEK_EVERY
end

-- Food handed over: stays a moment, the two may have a child now.
function V.seek_stay(self)
	local g = self._goal
	g.seek, g.pos, g.arrived, self._path = "stay", node_pos(self.object:get_pos()), true, nil
	g.untl = math.min(g.untl, core.get_gametime() + V.SEEK_STAY)
end

function V.seek_end(self)
	if self._goal and self._goal.seek then
		self._goal, self._path = nil, nil
	end
end

-- true: mobs_redo's own step (wandering at the goal).
local function day(self, dt)
	local g = self._goal
	if not g or core.get_gametime() >= g.untl or (working(self) ~= (g.kind == "work" or g.kind == "bell"))
			or (g.kind == "work" and not vector.equals(g.pos, self._job)) then
		g = V.day_goal(self)
		self._goal, self._path = g, nil
	end
	local target = (g.seek == "food" or g.seek == "mate") and seek_to[self]
	local at = target and target:get_pos()
	if at then
		g.pos = node_pos(at)
	end
	local dist = vector.distance(self.object:get_pos(), g.pos)
	if dist <= 2.5 or (g.arrived and dist <= V.GOAL_LEASH) then
		g.arrived, self._path = true, nil
		return true
	end
	g.arrived = nil
	walk_to(self, g.pos, dt, g.kind == "out")
	return false
end

-- do_custom: false = this step is ours (mobs_redo's own AI is skipped).
function V.step(self, dtime)
	self._tick = (self._tick or 0) + dtime
	if self._tick < 0.5 then
		return not (self._sleeping or self._carried or self._home or (self._goal and not self._goal.arrived)
			or self._trading or self._crop
			or cb_mobs_village.breeding.partner(self))
	end
	local dt = self._tick
	self._tick = 0
	local pos = self.object:get_pos()
	door_behind(self, pos)
	if V.carried(self) then
		-- goes where it is taken: no way home, no breeding, no trading
		self._carried = true
		if self._sleeping then
			V.wake(self)
		end
		self._home, self._goal, self._path = nil, nil, nil
		cb_mobs_village.breeding.cancel(self)
		if self._bed and vector.distance(pos, self._bed) > V.FORGET_FAR then
			self._bed = nil
		end
		local v = self.object:get_velocity()
		self:set_animation(math.hypot(v.x, v.z) > 0.3 and "walk" or "stand")
		return false
	elseif self._carried then
		self._carried = nil
		V.released(self)
	elseif self._bed and vector.distance(pos, self._bed) > V.FORGET_FAR then
		forget_bed(self)
	end
	if self._child then
		self.hornytimer = 0
		if not self._sleeping and cb_mobs_village.breeding.grown(self) then
			cb_mobs_village.breeding.grow(self)
		end
	end
	if self._trading then
		local s = cb_mobs_village.trade_ui and cb_mobs_village.trade_ui.sessions[self._trading]
		local player = s and s.ent == self and core.get_player_by_name(self._trading)
		if player then
			V.face(self, player:get_pos())
			self.object:set_velocity(vector.zero())
			self:set_animation("stand")
			return false
		end
		self._trading = nil
	end
	local home = V.night() or (self._called or 0) > core.get_gametime()
	if self._sleeping then
		if not home or not is_bed(self._bed) then
			local lost = not is_bed(self._bed)
			V.wake(self)
			if lost then
				self._bed = nil
			end
			return true
		end
		self.object:set_velocity(vector.zero())
		return false
	end
	if not self._child then
		cb_mobs_village.food.tick(self, dt)
	end
	if monster_near(self) then
		self._home, self._path = nil, nil
		cb_mobs_village.breeding.cancel(self)
		return true
	end
	if home then
		cb_mobs_village.breeding.cancel(self)
	end
	self._claim_t = (self._claim_t or V.CLAIM_EVERY) + dt
	if self._claim_t >= V.CLAIM_EVERY then
		self._claim_t = 0
		V.claim(self)
	end
	if not home and cb_mobs_village.professions and not self._child then
		cb_mobs_village.professions.tick(self, dt)
		-- restock at the job site by day
		if self._job and self._offers and vector.distance(self.object:get_pos(), self._job) <= 2 then
			cb_mobs_village.trading.restock(self, core.get_day_count())
		end
		if cb_mobs_village.breeding.tick(self, dt) then
			self:set_velocity(0)
			self:set_animation("stand")
			return false
		end
		if cb_mobs_village.farmer.tick(self, dt) then
			return false
		end
	end
	local bed = self._bed
	if not bed then
		self._home = nil
		return true
	end
	local d = vector.distance(self.object:get_pos(), bed)
	if not home then
		self._home, self._at_bed = nil, nil
		return day(self, dt)
	end
	self._home, self._goal = true, nil
	-- at the end of its route a villager stands up to 0.6 off the side spot:
	-- up to ~1.7 from the bed (BACKLOG 21)
	if d <= 1.6 or (self._at_bed and d <= V.BED_REACH) then
		if V.night() then
			V.sleep(self)
		else
			self:set_velocity(0)
			self:set_animation("stand")
		end
		return false
	end
	self._at_bed = walk_to(self, bed, dt)
	return false
end

local function retexture(self, kind)
	if not self._vtype then
		self._vtype = cb_core.biome_palette(self.object:get_pos())
	end
	local t = V.texture(kind, self._vtype)
	local prof = kind == "villager" and (self._nitwit and "nitwit" or self._prof)
	if prof == "banker" then
		t = t .. "^(cb_mobs_village_profession_librarian.png^[colorize:#2f6f3a:140)"
	elseif prof then
		t = t .. "^cb_mobs_village_profession_" .. prof .. ".png"
	end
	self.base_texture = { t, "blank.png", "blank.png", }
	self.object:set_properties({ textures = self.base_texture, })
end
V.retexture = retexture

mobs:register_mob(NAME, {
	type = "npc",
	passive = true,
	hp_min = 20,
	hp_max = 20,
	armor = 100,
	collisionbox = V.BOX,
	visual = "mesh",
	mesh = "cb_mobs_village_villager.b3d",
	textures = { { V.texture("villager", "plains"), }, },
	makes_footstep_sound = true,
	stepheight = 1.1,
	walk_velocity = 1,
	run_velocity = 2.5,
	walk_chance = 40,
	jump = true,
	view_range = 12,
	fear_height = 3,
	floats = 1,
	water_damage = 0,
	lava_damage = 8,
	drops = {},
	sounds = { random = "cb_mobs_village_villager", damage = "cb_mobs_village_villager_hurt",
		death = "cb_mobs_village_villager_death", distance = 10, },
	animation = { speed_normal = 35, stand_start = 0, stand_end = 0, walk_start = 0, walk_end = 40, run_start = 0,
		run_end = 40, sleep_start = 82, sleep_end = 82, sleep_speed = 0, },
	do_custom = function(self, dtime)
		return V.step(self, dtime)
	end,
	after_activate = function(self)
		self._trading = nil -- no window survives a reload
		self._mate_until, self._mate_bed = nil, nil
		self._crop = nil
		cb_mobs_village.trading.sanitize(self)
		if self._nitwit == nil and not self._child then
			self._nitwit = math.random() < cb_mobs_village.professions.NITWIT
		end
		retexture(self, "villager")
		if self._child then
			cb_mobs_village.breeding.child_props(self)
		end
		if self._sleeping then
			V.wake(self)
		end
		-- at once, so that the respawn engine sees whose villager it is
		V.claim(self)
	end,
	on_rightclick = function(self, clicker)
		-- riding: a click lets it out instead of trading
		if clicker and clicker:is_player() and V.transport and V.transport.click(self) then
			return
		end
		if clicker and clicker:is_player() and self._offers and not self._sleeping and not self._child
				and not V.carried(self)
				and not self._nitwit and cb_mobs_village.trade_ui then
			cb_mobs_village.trade_ui.open(self, clicker) -- refuses while someone else trades
		end
	end,
	on_die = function(self, pos)
		cb_mobs_village.professions.release(self)
		for _, fn in ipairs(V.death_hooks) do
			fn(self, pos)
		end
	end,
	do_punch = function(self, hitter)
		for _, fn in ipairs(V.punch_hooks) do
			fn(self, hitter)
		end
	end,
})

mobs:register_egg(NAME, S("Villager"), "default_wood.png", 1)

-- Villagers run from every mobs_redo monster.
core.register_on_mods_loaded(function()
	local list = {}
	for name, def in pairs(core.registered_entities) do
		if def._cmi_is_mob and def.type == "monster" then
			list[#list + 1] = name
		end
	end
	core.registered_entities[NAME].runaway_from = list
end)

if rawget(_G, "cb_blocks") and cb_blocks.bell_hooks then
	table.insert(cb_blocks.bell_hooks, function(pos)
		local until_t = core.get_gametime() + V.CALLED
		for _, obj in ipairs(core.get_objects_inside_radius(pos, 32)) do
			local e = obj:get_luaentity()
			if e and e.name == NAME then
				e._called = until_t
			end
		end
	end)
end
