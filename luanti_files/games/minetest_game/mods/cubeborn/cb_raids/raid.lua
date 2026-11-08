-- Raids (spec cycle 2, 6): a player with Bad Omen who enters a village
-- starts one; waves of Bedrock's table come 24-40 nodes from the bell and
-- head for it. Won: Hero of the Village. Lost: no villager left (seen only
-- when the bell area is active), or 48 minutes without players within 64.
-- One globalstep every second; raids keep ~100 bytes each in mod_storage and
-- go on from their wave after a restart (raiders are the entities with
-- _raid = village id). mobs_redo does not save monsters (static_save off)
-- and drops them with lifetimer < 20000; raiders are kept while their raid
-- lasts.
local S = cb_raids.S
local E = cb_core.effects
local storage = core.get_mod_storage()
local R = { KEEP = 20001, LIFETIME = 180, NEAR = 64, LOST = 48 * 60, COOLDOWN = 15, HERO_TIME = 40 * 60, TRACK = 112, MIN_D = 24, MAX_D = 40,
	SAVE_EVERY = 30, WAVES = { easy = 3, normal = 5, hard = 7, }, }
cb_raids.raid = R
R.raids = {}

local P, V, RV, W, EV = "cb_mobs_illager:pillager", "cb_mobs_illager:vindicator", "cb_mobs_illager:ravager",
	"cb_mobs_village:witch", "cb_mobs_illager:evoker"
local VILLAGER = "cb_mobs_village:villager"

local function keep(e, on)
	e.lifetimer = on and R.KEEP or R.LIFETIME
	e.object:set_properties({ static_save = on, })
end
local VICTIMS = { "player", VILLAGER, "cb_mobs_village:iron_golem", }
-- Bedrock, waves 1-7; a ravager with a rider = a ravager and that mob on foot.
R.TABLE = {
	{ { P, 4, }, },
	{ { P, 3, }, { V, 2, }, },
	{ { P, 3, }, { RV, 1, }, },
	{ { P, 3, }, { W, 3, }, },
	{ { P, 1, }, { V, 4, }, { RV, 2, }, { EV, 1, }, },
	{ { P, 5, }, { V, 2, }, { EV, 1, }, },
	{ { P, 1, }, { V, 6, }, { W, 1, }, { EV, 3, }, { RV, 2, }, },
}

function R.save()
	storage:set_string("raids", next(R.raids) and core.serialize(R.raids) or "")
end

function R.load()
	local raw = storage:get_string("raids")
	R.raids = raw ~= "" and core.deserialize(raw) or {}
end

function R.max()
	return tonumber(cb_core.setting("cubeborn.raid_max", "3")) or 3
end

local function count()
	local n = 0
	for _ in pairs(R.raids) do
		n = n + 1
	end
	return n
end

-- The village at pos (with the players' houses next to it), id and record.
function R.village_at(pos)
	return cb_structures.village.find(pos)
end

local function bell_of(rec)
	local b = cb_structures.village.bell(rec)
	if b then
		return b
	end
	return vector.new(math.floor((rec.minp.x + rec.maxp.x) / 2), math.floor((rec.minp.y + rec.maxp.y) / 2),
		math.floor((rec.minp.z + rec.maxp.z) / 2))
end

function R.start(id, level, now)
	if R.raids[id] then
		return nil, "busy"
	end
	if count() >= R.max() then
		return nil, "limit"
	end
	-- a village with nobody to defend is no raid (and keeps the omen)
	local rec = cb_structures.registry.get(id)
	if core.registered_entities[VILLAGER] and not R.has_villager(rec) then
		return nil, "empty"
	end
	local ordinary = R.WAVES[cb_core.difficulty()]
	local raid = { v = id, level = level, ordinary = ordinary, waves = ordinary + (level > 1 and 1 or 0), wave = 0,
		alive = 0, center = bell_of(rec), seen = now, next = now, t0 = now, }
	R.raids[id] = raid
	R.save()
	core.log("action", "[cb_raids] raid on village #" .. id .. ", Bad Omen " .. level)
	return raid
end

function R.composition(raid, w)
	local list = {}
	for _, e in ipairs(R.TABLE[math.min(w, raid.ordinary)]) do
		if core.registered_entities[e[1]] then
			for _ = 1, e[2] do
				list[#list + 1] = e[1]
			end
		end
	end
	return list
end

local function def_of(pos)
	local name = core.get_node(pos).name
	return name ~= "ignore" and core.registered_nodes[name] or nil
end

local function free(d)
	return d and not d.walkable and (d.liquidtype or "none") == "none" and (d.damage_per_second or 0) <= 0
end

-- Solid ground (not leaves) under pos, open sky (no caves, no basements),
-- 3 x 2 x 3 free, harmless, dry nodes from pos up: room for a ravager.
function R.stands(pos)
	local below = def_of(vector.offset(pos, 0, -1, 0))
	if not (below and below.walkable and not (below.groups and below.groups.leaves)) then
		return false
	end
	for dx = -1, 1 do
		for dy = 0, 1 do
			for dz = -1, 1 do
				if not free(def_of(vector.offset(pos, dx, dy, dz))) then
					return false
				end
			end
		end
	end
	return core.get_node_light(pos, 0.5) == 15
end

function R.spot(center, rng)
	for _ = 1, 24 do
		local a = rng:next(0, 359) * math.pi / 180
		local d = rng:next(R.MIN_D, R.MAX_D)
		local x, z = math.floor(center.x + d * math.cos(a) + 0.5), math.floor(center.z + d * math.sin(a) + 0.5)
		if core.compare_block_status(vector.new(x, center.y, z), "active") then
			for y = center.y + 16, center.y - 16, -1 do
				local p = vector.new(x, y, z)
				if R.stands(p) then
					return p
				end
			end
		end
	end
end

function R.spawn_wave(raid)
	local w = raid.wave + 1
	-- a failed search tries other places next time
	local spot = R.spot(raid.center, PcgRandom(raid.v * 7919 + w * 104729 + (raid.tries or 0) * 15485863
		+ math.floor(raid.t0)))
	if not spot then
		raid.tries = (raid.tries or 0) + 1
		return false
	end
	raid.tries = nil
	raid.wave = w
	raid.last = { vector.round(spot), }
	core.sound_play("cb_raids_horn", { pos = spot, gain = 2, max_hear_distance = 128, }, true)
	local captain = false
	for _, name in ipairs(R.composition(raid, w)) do
		local obj = core.add_entity(spot, name)
		local e = obj and obj:get_luaentity()
		if e then
			e._raid, e._raid_wave = raid.v, w
			keep(e, true)
			if name == W then
				e.specific_attack, e.attack_npcs = table.copy(VICTIMS), true
			end
			if name == P and not captain then
				captain = true
				cb_mobs_illager.make_captain(e)
			end
		end
	end
	R.save()
	return true
end

function R.raiders(raid)
	local list = {}
	for _, obj in ipairs(core.get_objects_inside_radius(raid.center, R.TRACK)) do
		local e = obj:get_luaentity()
		if e and e._raid == raid.v and (e.health or 1) > 0 then
			list[#list + 1] = e
		end
	end
	return list
end

-- Where the raiders were last seen, one position per mapblock.
function R.remember(raid, alive)
	local last, seen = {}, {}
	for _, e in ipairs(alive) do
		local pos = e.object:get_pos()
		if pos then
			local p = vector.round(pos)
			local key = core.hash_node_position(vector.floor(vector.divide(p, 16)))
			if not seen[key] then
				seen[key] = true
				last[#last + 1] = p
			end
		end
	end
	raid.last = last
end

function R.last_seen_active(raid)
	if not raid.last then
		-- a raid saved before positions were kept: the whole area
		local reach = R.MAX_D + 8
		return R.active(vector.offset(raid.center, -reach, -16, -reach), vector.offset(raid.center, reach, 16, reach))
	end
	for _, p in ipairs(raid.last) do
		if not core.compare_block_status(p, "active") then
			return false
		end
	end
	return true
end

function R.steer(e, center)
	if e.attack or e.state == "attack" then
		return
	end
	local pos = e.object:get_pos()
	if not pos or vector.distance(pos, center) < 6 then
		return
	end
	e:yaw_to_pos(center)
	e:set_velocity(e.walk_velocity)
	e.state = "walk"
	e:set_animation("walk")
end

-- Every mapblock of minp..maxp active (step 16, the far edges included).
function R.active(minp, maxp)
	local function axis(a, b)
		local list = {}
		for v = a, b, 16 do
			list[#list + 1] = v
		end
		list[#list + 1] = b
		return list
	end
	for _, x in ipairs(axis(minp.x, maxp.x)) do
		for _, y in ipairs(axis(minp.y, maxp.y)) do
			for _, z in ipairs(axis(minp.z, maxp.z)) do
				if not core.compare_block_status(vector.new(x, y, z), "active") then
					return false
				end
			end
		end
	end
	return true
end

-- No villager in the village box, and the whole box active, so that absent
-- means dead rather than unloaded.
function R.has_villager(rec)
	for _, obj in ipairs(core.get_objects_in_area(vector.subtract(rec.minp, 8), vector.add(rec.maxp, 8))) do
		local e = obj:get_luaentity()
		if e and e.name == VILLAGER then
			return true
		end
	end
	return false
end

function R.villagers_gone(rec)
	if not core.registered_entities[VILLAGER] or R.has_villager(rec) then
		return false
	end
	return R.active(vector.subtract(rec.minp, 8), vector.add(rec.maxp, 8))
end

function R.finish(raid, outcome, near, now)
	for _, e in ipairs(R.raiders(raid)) do
		e._raid, e._raid_wave = nil, nil
		keep(e, false)
	end
	if outcome == "victory" then
		for _, p in ipairs(near) do
			E.apply(p, "hero", raid.level or 1, R.HERO_TIME)
		end
	end
	if cb_raids.hud then
		cb_raids.hud.finish(raid, near, outcome, now)
	end
	R.raids[raid.v] = nil
	R.save()
	core.log("action", "[cb_raids] raid on village #" .. raid.v .. ": " .. outcome)
end

function R.step(raid, players, now)
	local rec = cb_structures.registry.get(raid.v)
	if not rec then
		return R.finish(raid, "gone", {}, now)
	end
	local near = {}
	for _, p in ipairs(players) do
		if vector.distance(p:get_pos(), raid.center) <= R.NEAR then
			near[#near + 1] = p
		end
	end
	if #near == 0 then
		if now - raid.seen > R.LOST then
			R.finish(raid, "lost", near, now)
		end
		return
	end
	raid.seen = now
	local alive = R.raiders(raid)
	if R.villagers_gone(rec) then
		return R.finish(raid, "defeat", near, now)
	end
	local changed = false
	-- no raider seen: a beaten wave only if the blocks where raiders were
	-- last seen are active (unloaded raiders are invisible). Before the
	-- first wave there is nobody to miss.
	if #alive > 0 then
		raid.next = nil
		R.remember(raid, alive)
	elseif raid.wave > 0 and not R.last_seen_active(raid) then
		alive = nil
	end
	if alive and #alive == 0 then
		if raid.wave >= raid.waves then
			return R.finish(raid, "victory", near, now)
		end
		if not raid.next then
			raid.next, changed = now + R.COOLDOWN, true
		end
		if now >= raid.next and R.spawn_wave(raid) then
			raid.next = nil
			alive = R.raiders(raid)
		end
	end
	if alive then
		raid.alive = #alive
	end
	for _, e in ipairs(alive or {}) do
		R.steer(e, raid.center)
	end
	if cb_raids.hud then
		cb_raids.hud.show(raid, near, now)
	end
	if changed or now - (raid.saved or 0) >= R.SAVE_EVERY then
		raid.saved = now
		R.save()
	end
end

local told = {}

function R.tick(players, now)
	for _, p in ipairs(players) do
		local level = E.get(p, "bad_omen")
		if level then
			local id = R.village_at(p:get_pos())
			local raid, why = nil, nil
			if id then
				raid, why = R.start(id, level, now)
			end
			local name = p:get_player_name()
			if raid then
				E.clear(p, "bad_omen")
				told[name] = nil
				for _, q in ipairs(players) do
					local qp = q:get_pos()
					if qp and vector.distance(qp, raid.center) <= R.NEAR then
						core.chat_send_player(q:get_player_name(), core.colorize("#ff5555",
							S("A raid on this village has begun: @1 waves. Defend the villagers!", raid.waves)))
					end
				end
			elseif (why == "empty" or why == "limit") and told[name] ~= id .. why then
				-- once per village and reason while the omen lasts
				told[name] = id .. why
				core.chat_send_player(name, why == "empty"
					and S("This village has no villagers: there is nobody to raid.")
					or S("Too many raids are going on; yours waits until one ends."))
			end
		end
	end
	for _, raid in pairs(R.raids) do
		R.step(raid, players, now)
	end
end

if rawget(_G, "cb_blocks") and cb_blocks.bell_hooks then
	table.insert(cb_blocks.bell_hooks, function(pos)
		local id = R.village_at(pos)
		local raid = id and R.raids[id]
		if not raid then
			return
		end
		local t = core.get_gametime()
		for _, obj in ipairs(core.get_objects_inside_radius(pos, 32)) do
			local e = obj:get_luaentity()
			if e and e._raid == raid.v then
				e._glow = t + 3
				core.add_particlespawner({ amount = 24, time = 3, attached = obj,
					minpos = { x = -0.3, y = 2.3, z = -0.3, }, maxpos = { x = 0.3, y = 2.7, z = 0.3, },
					minvel = { x = 0, y = 0.2, z = 0, }, maxvel = { x = 0, y = 0.5, z = 0, },
					minexptime = 0.5, maxexptime = 1, minsize = 2, maxsize = 3, glow = 14,
					texture = "default_mese_crystal_fragment.png", })
			end
		end
	end)
end

R.load()

-- Raiders open doors while in a raid. Raiders of a raid that ended while
-- they were unloaded become ordinary mobs when they come back.
core.register_on_mods_loaded(function()
	local names = {}
	for _, wave in ipairs(R.TABLE) do
		for _, e in ipairs(wave) do
			names[e[1]] = true
		end
	end
	for name in pairs(names) do
		local def = core.registered_entities[name]
		-- raiders open wooden doors as they go (spec cycle 5, 4.1); ravagers do not
		if def and name ~= RV and cb_core.doors then
			local do_custom = def.do_custom
			def.do_custom = function(self, dtime, moveresult)
				if self._raid then
					self._door_t = (self._door_t or 0) + dtime
					if self._door_t >= 0.5 then
						cb_core.doors.bump(self, self._door_t)
						self._door_t = 0
					end
				end
				if do_custom then
					return do_custom(self, dtime, moveresult)
				end
				return true
			end
		end
		local on_activate = def and def.on_activate
		if on_activate then
			def.on_activate = function(self, staticdata, dtime)
				local r = on_activate(self, staticdata, dtime)
				if self._raid and self.object:get_pos() then
					if R.raids[self._raid] then
						keep(self, true)
					else
						self._raid, self._raid_wave = nil, nil
						keep(self, false)
					end
				end
				return r
			end
		end
	end
end)

local timer = 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < 1 then
		return
	end
	timer = 0
	local players = core.get_connected_players()
	local now = core.get_gametime()
	R.tick(players, now)
	if cb_raids.hud then
		cb_raids.hud.sweep(players, now)
	end
end)
