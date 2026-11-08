-- Inhabitants come back to intact parts of structures while a player is near.
-- Cost model: one globalstep pass every 5 s (skipped while the server lags);
-- parts are found through the registry grid; each part is checked at most once
-- a minute (one get_objects_in_area); a pass checks at most 20 parts and
-- makes at most 4 spawn attempts (one per structure): only an attempt reads
-- the part's node sample (cached for 5 minutes) and searches a spot (8
-- columns, 8 nodes each), so a pass reads at most ~1500 nodes. Never above
-- 12 structure mobs near a player. Timers and caches live in memory only,
-- except the timers of rare inhabitants.
-- Rare inhabitants (a mobs entry {name, weight, key}, or a role such as the
-- outpost captain): at most one per part, and once one is gone the part waits
-- RARE_HOURS of real time (cubeborn.rare_respawn_hours) before another, so they
-- cannot be farmed. The wait lives in part.rare[key] (an os.time()), saved with
-- the record: nil = never had one, 0 = has one, > 0 = none until then.
local respawn = {
	PERIOD = 5, RADIUS = 48, COOLDOWN = 60, CACHE = 300,
	MAX_CHECKS = 20, MAX_SPAWNS = 4, NEAR_CAP = 12, MIN_DIST = 8, INTACT = 0.75, SCAN = 8,
}
cb_structures.respawn = respawn

local state = {}
local all_names

function respawn.reset()
	state = {}
end

-- Inhabitants whose mods are loaded: list of {name, weight}, total, name set.
-- inh.fallback: mobs used when none of inh.mobs is loaded.
local function mobs_of(inh)
	if not inh._list then
		local list, total, set, rare = {}, 0, {}, {}
		local mobs = inh.mobs
		if inh.fallback then
			local any = false
			for _, m in ipairs(mobs) do
				any = any or core.registered_entities[m[1]] ~= nil
			end
			mobs = any and mobs or inh.fallback
		end
		for _, m in ipairs(mobs) do
			if core.registered_entities[m[1]] then
				list[#list + 1] = m
				total = total + (m[2] or 1)
				set[m[1]] = true
				rare[m[1]] = m[3]
			end
		end
		inh._list, inh._total, inh._set, inh._rare = list, total, set, next(rare) and rare or nil
	end
	return inh._list, inh._total, inh._set, inh._rare
end

function respawn.rare_wait()
	return (tonumber(cb_core.setting("cubeborn.rare_respawn_hours", "24")) or 24) * 3600
end

-- Whether part may get the rare inhabitant `key` now; alive: one is there.
-- Starts the wait (wait seconds, default rare_wait()) when the one it had is
-- gone.
function respawn.rare_ready(id, part, key, alive, wait)
	part.rare = part.rare or {}
	local t = part.rare[key]
	if alive then
		if t ~= 0 then
			part.rare[key] = 0
			cb_structures.registry.save(id)
		end
		return false
	end
	if t == nil then
		return true
	end
	if t == 0 then
		part.rare[key] = os.time() + (wait or respawn.rare_wait())
		cb_structures.registry.save(id)
		return false
	end
	return os.time() >= t
end

function respawn.rare_given(id, part, key)
	part.rare = part.rare or {}
	part.rare[key] = 0
	cb_structures.registry.save(id)
end

-- The inhabitants of a part: its kind's entry, or the whole table for types
-- without kinds.
-- when(rec, part): optional; false holds the refill of this part for now.
function respawn.kind(inh, part)
	if not inh then
		return nil
	end
	if inh.kinds then
		return part.kind and inh.kinds[part.kind] or part.k and inh.kinds[part.k] or nil
	end
	return inh
end

local function inhabitant_names()
	if not all_names then
		all_names = {}
		for _, name in ipairs(cb_structures.type_names()) do
			local inh = cb_structures.get_type(name).inhabitants
			for _, kinh in pairs(inh and (inh.kinds or { inh, }) or {}) do
				local _, _, set = mobs_of(kinh)
				for n in pairs(set) do
					all_names[n] = true
				end
			end
		end
	end
	return all_names
end

function respawn.norm(part, inh)
	local v = (part.maxp.x - part.minp.x + 1) * (part.maxp.y - part.minp.y + 1) * (part.maxp.z - part.minp.z + 1)
	return math.max(1, math.min(inh.max, math.floor(v / inh.volume)))
end

-- true/false (nil when some sampled node is not loaded) and the number of
-- anchors in place. Count mode: alive with at least one anchor; otherwise
-- every anchor is needed.
function respawn.intact(rec, part, count_mode)
	local samples = cb_structures.unpack(part.s)
	local ok = 0
	for _, e in ipairs(samples) do
		local name = core.get_node(cb_structures.at_offset(part.minp, part.maxp, e.o)).name
		if name == "ignore" then
			return nil
		end
		if name == rec.palette[e.p] then
			ok = ok + 1
		end
	end
	local anchors = cb_structures.unpack(part.a)
	local present = 0
	for _, e in ipairs(anchors) do
		local name = core.get_node(cb_structures.at_offset(part.minp, part.maxp, e.o)).name
		if name == "ignore" then
			return nil
		end
		present = present + (name == rec.palette[e.p] and 1 or 0)
	end
	if #samples > 0 and ok < respawn.INTACT * #samples then
		return false, present
	end
	if count_mode then
		return present > 0, present
	end
	return present == #anchors, present
end

-- How many mobs of set are there, and a name -> count table.
local function count(minp, maxp, set, kinh, part)
	local m = kinh and kinh.margin or 0
	local n, by = 0, {}
	for _, obj in ipairs(core.get_objects_in_area(vector.subtract(minp, m), vector.add(maxp, m))) do
		local ent = obj:get_luaentity()
		if ent and set[ent.name] and (not (kinh and kinh.owns) or kinh.owns(ent, part)) then
			n = n + 1
			by[ent.name] = (by[ent.name] or 0) + 1
		end
	end
	return n, by
end

local function walkable(pos)
	local def = core.registered_nodes[core.get_node(pos).name]
	return def ~= nil and def.walkable ~= false
end

local function free(pos)
	return core.get_node(pos).name == "air"
end

-- Air two nodes high on solid ground inside the part, MIN_DIST from players:
-- 8 random columns, each scanned down SCAN nodes from a random height.
local function spawn_spot(part, players)
	local bottom = part.minp.y + 1
	for _ = 1, 8 do
		local x, z = math.random(part.minp.x, part.maxp.x), math.random(part.minp.z, part.maxp.z)
		local top = math.random(bottom, math.max(bottom, part.maxp.y - 1))
		for y = top, math.max(bottom, top - respawn.SCAN + 1), -1 do
			local p = vector.new(x, y, z)
			if free(p) and free(vector.offset(p, 0, 1, 0)) and walkable(vector.offset(p, 0, -1, 0)) then
				local far = true
				for _, pp in ipairs(players) do
					if vector.distance(pp, p) < respawn.MIN_DIST then
						far = false
						break
					end
				end
				if far then
					return p
				end
				break
			end
		end
	end
end

-- skip: names that may not be picked now.
local function pick(list, total, skip)
	if skip then
		for _, m in ipairs(list) do
			total = total - (skip[m[1]] and (m[2] or 1) or 0)
		end
		if total <= 0 then
			return nil
		end
	end
	local r, last = math.random() * total, nil
	for _, m in ipairs(list) do
		if not (skip and skip[m[1]]) then
			r, last = r - (m[2] or 1), m[1]
			if r <= 0 then
				return m[1]
			end
		end
	end
	return last
end

function respawn.pass(players, now)
	local checks, attempts, spawned, busy = 0, 0, 0, {}
	local names = inhabitant_names()
	for _, ppos in ipairs(players) do
		if checks >= respawn.MAX_CHECKS or attempts >= respawn.MAX_SPAWNS then
			break
		end
		local near
		cb_structures.registry.parts_near(ppos, respawn.RADIUS, function(id, j, rec, part)
			if checks >= respawn.MAX_CHECKS or attempts >= respawn.MAX_SPAWNS then
				return false
			end
			local def = cb_structures.get_type(rec.type)
			local inh = def and def.inhabitants
			if not inh or part.dead or rec.state ~= "ready" or busy[id] then
				return
			end
			local key = id * 4096 + j
			local st = state[key]
			if not st then
				st = { next = 0, checked = -math.huge, }
				state[key] = st
			end
			if now < st.next then
				return
			end
			st.next = now + respawn.COOLDOWN
			checks = checks + 1
			-- things a part gets back besides mobs (the elytra of End ships)
			if def.restock then
				def.restock(rec, part, id)
			end
			local kinh = respawn.kind(inh, part)
			if not kinh then
				return
			end
			local list, total, set, rare = mobs_of(kinh)
			if total <= 0 then
				return
			end
			-- count mode: the norm is the anchors in place, so read them first
			local function refresh()
				local ok, present = respawn.intact(rec, part, kinh.count)
				if ok == nil then
					return nil
				end
				st.checked, st.anchors = now, present
				if not ok then
					part.dead, part.s, part.a = true, nil, nil
					cb_structures.registry.save(id)
				end
				return ok
			end
			if kinh.count and now - st.checked >= respawn.CACHE and not refresh() then
				return
			end
			local norm
			if kinh.count then
				norm = st.anchors or 0
			elseif kinh.norm then
				norm = kinh.norm(rec, part)
			else
				norm = respawn.norm(part, kinh)
			end
			local have, by = count(part.minp, part.maxp, set, kinh, part)
			local skip
			for name, rkey in pairs(rare or {}) do
				if not respawn.rare_ready(id, part, rkey, (by[name] or 0) > 0) then
					skip = skip or {}
					skip[name] = true
				end
			end
			if have >= norm then
				return
			end
			-- after the count-mode anchor check, so a held part still dies
			if kinh.when and not kinh.when(rec, part) then
				return
			end
			attempts, busy[id] = attempts + 1, true
			if not kinh.count and now - st.checked >= respawn.CACHE and not refresh() then
				return
			end
			near = near or count(vector.subtract(ppos, respawn.RADIUS), vector.add(ppos, respawn.RADIUS), names)
			if near >= respawn.NEAR_CAP then
				return
			end
			local p = spawn_spot(part, players)
			local name = p and pick(list, total, skip)
			local obj = name and core.add_entity(vector.offset(p, 0, 0.5, 0), name)
			if obj then
				spawned, near = spawned + 1, near + 1
				if rare and rare[name] then
					respawn.rare_given(id, part, rare[name])
				end
				if kinh.on_spawn and obj:get_luaentity() then
					kinh.on_spawn(obj:get_luaentity(), part, rec, id)
				end
			end
		end)
	end
	return spawned, checks
end

local timer = 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < respawn.PERIOD then
		return
	end
	timer = 0
	if dtime > 0.2 then
		return
	end
	local players = {}
	for _, player in ipairs(core.get_connected_players()) do
		players[#players + 1] = player:get_pos()
	end
	if #players > 0 then
		respawn.pass(players, core.get_us_time() / 1000000)
	end
end)
