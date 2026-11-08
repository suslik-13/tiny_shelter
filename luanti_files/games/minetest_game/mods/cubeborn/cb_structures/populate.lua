-- /cb_populate: one admin command fills the map the generator has already
-- made with every Cubeborn structure at about Minecraft's frequency:
-- 1. the End pocket and the own Nether pocket when missing (their cities,
--    fortresses and bastions come with them);
-- 2. strongholds in rings around 0,0 as in Minecraft;
-- 3. every Overworld type, rarest first, as one deterministic scatter pass;
-- 4. fortresses and bastions in the nether mod's Nether (servers with it).
-- Each scatter pass uses the world seed per cell, so a rerun adds nothing to
-- handled land and fills land generated since. The progress is stored; after
-- a restart /cb_populate continues where it stopped. The load governor
-- (populate_load.lua) keeps it gentle while players are online.
local S = cb_structures.S
local SC = cb_structures.scatter
local PL = cb_structures.populate_load
local storage = core.get_mod_storage()

local P = {}
cb_structures.populate = P
cb_structures.populate_state = nil

-- Attempts per 1000x1000 nodes (Minecraft structure set spacing, see the spec
-- docs/specs/2026-11-01-populate-design.md); the order is the run order.
P.DENSITY = {
	{ "mansion", 0.25, }, { "ancient_city", 0.5, }, { "trial_chambers", 3.4, }, { "ocean_monument", 3.8, },
	{ "village", 3.4, }, { "outpost", 0.76, }, { "desert_temple", 3.8, }, { "jungle_temple", 3.8, },
	{ "witch_hut", 3.8, }, { "igloo", 3.8, }, { "trail_ruins", 3.4, }, { "pale_grove", 0.5, },
	{ "desert_well", 1, }, { "ruined_portal", 2.4, }, { "shipwreck", 4.3, }, { "mineshaft", 15.6, },
	{ "ocean_ruin", 9.8, },
}
P.NETHER = { { "nether_fortress", 2.2, }, { "bastion", 3.2, }, }
P.VILLAGE_WORDS = { "plains", "grassland", "desert", "savanna", "taiga", "coniferous", "snowy", "tundra", }
-- Minecraft's stronghold rings: count, inner and outer radius.
P.RINGS = { { 3, 1280, 2816, }, { 6, 4352, 5888, }, { 10, 7424, 8960, }, }
P.RING_MARGIN = 150
P.STRONGHOLD_NEAR = 300

local world_seed = tonumber((core.get_mapgen_setting("seed") or "0"):sub(-9)) or 0

local function step_key(s)
	if s.kind == "pocket" then
		return "pocket:" .. s.dim
	end
	return s.kind .. ":" .. (s.name or "")
end

function P.steps()
	local list = {}
	local profile = cb_core.profile
	if cb_dimensions.get_dim("end") and not cb_dimensions.get("end") then
		list[#list + 1] = { kind = "pocket", dim = "end", }
	end
	if profile.nether == "own" and cb_dimensions.get_dim("nether") and not cb_dimensions.get("nether") then
		list[#list + 1] = { kind = "pocket", dim = "nether", }
	end
	if cb_structures.get_type("stronghold") then
		list[#list + 1] = { kind = "strongholds", }
	end
	for _, d in ipairs(P.DENSITY) do
		if cb_structures.get_type(d[1]) then
			list[#list + 1] = { kind = "type", name = d[1], per = d[2], }
		end
	end
	if profile.nether == "external" and rawget(_G, "nether") and nether.DEPTH_FLOOR then
		for _, d in ipairs(P.NETHER) do
			if cb_structures.get_type(d[1]) then
				list[#list + 1] = { kind = "nether", name = d[1], per = d[2], }
			end
		end
	end
	return list
end

-- Stronghold spots: each ring whose inner radius lies inside the map, its
-- strongholds evenly around it from a random angle, radii clamped to the map.
function P.ring_spots(seed, half)
	local pcg = PcgRandom(seed)
	local function frac()
		return pcg:next(0, 1073741823) / 1073741824
	end
	local limit = half - P.RING_MARGIN
	local list = {}
	for _, ring in ipairs(P.RINGS) do
		local n, r0, r1 = ring[1], ring[2], math.min(ring[3], limit)
		if r0 <= limit then
			local a0 = frac() * 2 * math.pi
			for i = 0, n - 1 do
				local a = a0 + i * 2 * math.pi / n
				local r = r0 + (r1 - r0) * frac()
				list[#list + 1] = { x = math.floor(r * math.cos(a) + 0.5), z = math.floor(r * math.sin(a) + 0.5), }
			end
		end
	end
	return list
end

local function map_half()
	local a, b = core.get_mapgen_edges()
	return math.min(-a.x, b.x, -a.z, b.z)
end

-- A spot on a cavern floor of the nether mod's Nether: the highest air node
-- with a walkable node under it and 8 air nodes over it. Ungenerated parts of
-- the column are skipped; a column with nothing generated is "ungenerated".
function P.nether_spot(name, x, z)
	local limit = tonumber(core.get_mapgen_setting("mapgen_limit")) or 31007
	local top = nether.DEPTH_CEILING - 8
	local bottom = math.max(nether.DEPTH_FLOOR, -limit) + 8
	local vm = VoxelManip()
	local e1, e2 = vm:read_from_map({ x = x, y = bottom, z = z, }, { x = x, y = top, z = z, })
	local va = VoxelArea(e1, e2)
	local data = vm:get_data()
	local ignore, air = core.CONTENT_IGNORE, core.get_content_id("air")
	local seen, run = false, 0
	for y = top, bottom, -1 do
		local cid = data[va:index(x, y, z)]
		if cid == ignore then
			run = 0
		else
			seen = true
			if cid == air then
				run = run + 1
			else
				local def = core.registered_nodes[core.get_name_from_content_id(cid)]
				if run >= 9 and def and def.walkable then
					local origin = vector.new(x, y + 1, z)
					local pr = cb_structures.get_type(name).prepare or { radius = 48, below = 24, above = 40, }
					if not SC.area_generated(vector.offset(origin, -pr.radius, -pr.below, -pr.radius),
							vector.offset(origin, pr.radius, pr.above, pr.radius)) then
						return nil, "ungenerated"
					end
					return origin
				end
				run = 0
			end
		end
	end
	return nil, seen and "ground" or "ungenerated"
end

local function biome_in(pos, words)
	local data = core.get_biome_data(pos)
	local b = data and core.get_biome_name(data.biome) or ""
	for _, w in ipairs(words) do
		if b:find(w, 1, true) then
			return true
		end
	end
	return false
end

-- The spot finder of a step: villages only in Minecraft's village biomes.
local function spot_for(s)
	if s.kind == "nether" then
		return P.nether_spot
	end
	if s.name == "village" then
		return function(name, x, z)
			local origin, why = SC.spot(name, x, z)
			if origin and not biome_in(origin, P.VILLAGE_WORDS) then
				return nil, "biome"
			end
			return origin, why
		end
	end
	return nil
end

local function load_progress()
	return core.deserialize(storage:get_string("populate")) or {}
end

local function save_progress(t)
	local st = cb_structures.populate_state
	t.owner = t.owner or (st and st.owner)
	storage:set_string("populate", core.serialize(t))
end

function P.progress()
	return load_progress()
end

local function say(st, msg)
	core.log("action", "[cubeborn] populate: " .. core.get_translated_string("en", msg))
	if st.owner and core.get_player_by_name(st.owner) then
		core.chat_send_player(st.owner, msg)
	end
end

local function alive(st)
	return cb_structures.populate_state == st
end

local run_step

local function next_step(st)
	if not alive(st) then
		return
	end
	st.i = st.i + 1
	st.start_cell = 1
	local s = st.steps[st.i]
	if not s then
		save_progress({ done = true, })
		cb_structures.populate_state = nil
		PL.stop()
		say(st, S("Populate finished: @1 structures placed.", st.placed))
		if st.on_done then
			st.on_done(st)
		end
		return
	end
	save_progress({ step = step_key(s), cell = 1, })
	run_step(st, s)
end

-- The pocket is filled by its own background job, side by side with the
-- rest of the run: the run moves on once the pocket is placed.
local function pocket_step(st, s)
	st.what = s.dim
	cb_dimensions.create_auto(s.dim, st.owner, function(ok, msg)
		if not alive(st) then
			return
		end
		if not ok then
			say(st, S("Populate: pocket '@1' skipped: @2", s.dim, msg))
		else
			say(st, S("Populate: pocket '@1' is being created in the background.", s.dim))
		end
		next_step(st)
	end)
end

local function stronghold_near(x, z)
	for _, rec in pairs(cb_structures.registry.all()) do
		if rec.type == "stronghold" and rec.minp and rec.maxp then
			local cx, cz = (rec.minp.x + rec.maxp.x) / 2, (rec.minp.z + rec.maxp.z) / 2
			if (cx - x) ^ 2 + (cz - z) ^ 2 <= P.STRONGHOLD_NEAR ^ 2 then
				return true
			end
		end
	end
	return false
end

local function strongholds_step(st)
	st.what = "stronghold"
	local spots = P.ring_spots(world_seed, map_half())
	local placed, missing, k = 0, 0, 0
	local function nxt()
		if not alive(st) then
			return
		end
		k = k + 1
		local sp = spots[k]
		if not sp then
			say(st, S("Populate: '@1' done: @2 placed, @3 missing.", "stronghold", placed, missing))
			return next_step(st)
		end
		if stronghold_near(sp.x, sp.z) then
			return core.after(0, nxt)
		end
		local wait = PL.spot_delay()
		if not wait then
			k = k - 1
			return core.after(1, nxt)
		end
		local origin = SC.spot("stronghold", sp.x, sp.z)
		if not origin then
			missing = missing + 1
			return core.after(wait, nxt)
		end
		cb_structures.place("stronghold", origin, st.owner, function(res)
			if not alive(st) then
				return
			end
			if res.ok then
				placed, st.placed = placed + 1, st.placed + 1
				say(st, S("'@1' #@2 at @3.", "stronghold", res.id, core.pos_to_string(origin)))
				return core.after(wait + PL.pause_after_build(), nxt)
			end
			missing = missing + 1
			core.after(wait, nxt)
		end)
	end
	nxt()
end

local function scatter_step(st, s)
	st.what = s.name
	local cell = st.opts.cell or SC.CELL
	local per_cell = s.per * (cell / 1000) ^ 2 * (st.opts.scale or 1)
	local key = step_key(s)
	SC.start(s.name, per_cell, st.owner, {
		minp = st.opts.minp, maxp = st.opts.maxp, cell = cell, seed = world_seed, biome_once = true,
		spot = spot_for(s), delay = PL.spot_delay, after_build = PL.pause_after_build, quiet = true,
		start_cell = st.start_cell, skip = st.skip_cells,
		on_cell = function(sc)
			if alive(st) then
				st.sc = sc
				save_progress({ step = key, cell = sc.ci, })
			end
		end,
		on_done = function(sc)
			if not alive(st) then
				return
			end
			st.placed = st.placed + sc.placed
			st.sc = nil
			say(st, S("Populate: '@1' done: @2 placed, @3 missing.", s.name, sc.placed, sc.missing))
			next_step(st)
		end,
	})
end

function run_step(st, s)
	if s.kind == "pocket" then
		pocket_step(st, s)
	elseif s.kind == "strongholds" then
		strongholds_step(st)
	else
		scatter_step(st, s)
	end
end

-- opts (tests): minp/maxp (x, z), cell, steps, scale (density factor), on_done.
function P.start(owner, opts)
	opts = opts or {}
	local steps = opts.steps or P.steps()
	local st = { owner = owner, opts = opts, steps = steps, i = 0, placed = 0, start_cell = 1, on_done = opts.on_done,
		skip_cells = {}, }
	cb_structures.populate_state = st
	PL.start()
	local prog = load_progress()
	prog.stopped = nil
	if not prog.done and prog.step then
		for i, s in ipairs(steps) do
			if step_key(s) == prog.step then
				st.i = i
				st.start_cell = prog.cell or 1
				save_progress(prog)
				run_step(st, s)
				return st
			end
		end
	end
	next_step(st)
	return st
end

function P.stop()
	local st = cb_structures.populate_state
	if st then
		local prog = load_progress()
		prog.stopped = true
		save_progress(prog)
	end
	cb_structures.populate_state = nil
	if st and cb_structures.scatter_state then
		SC.stop()
	end
	PL.stop()
	return st
end

local MODES = { gentle = S("gentle (players online)"), full = S("full speed"), lag = S("waiting: server lag"), }

function P.status()
	local st = cb_structures.populate_state
	if not st then
		return S("No populate run is going on.")
	end
	local sc = st.sc or cb_structures.scatter_state
	local pockets = {}
	for _, dim in ipairs({ "end", "nether", }) do
		local job = cb_dimensions.fill_job(dim)
		if job then
			pockets[#pockets + 1] = S("pocket '@1' @2%", dim, math.floor(cb_core.jobs.progress(job) * 100))
		end
	end
	local extra = #pockets > 0 and (" " .. table.concat(pockets, ", ")) or ""
	return S("Populate: step @1 of @2 (@3), cell @4 of @5, @6 placed, mode @7.", st.i, #st.steps, st.what or "-",
		sc and sc.ci or 0, sc and #sc.cells or 0, st.placed + (sc and sc.placed or 0), MODES[PL.mode()]) .. extra
end

-- A run cut short by a server restart (not by /cb_populate stop) goes on by
-- itself once the server is up.
P.RESUME_S = 10
core.register_on_mods_loaded(function()
	local prog = load_progress()
	if prog.step and not prog.done and not prog.stopped then
		core.after(P.RESUME_S, function()
			if not (cb_structures.populate_state or cb_structures.scatter_state) then
				core.log("action", "[cubeborn] populate: resuming the run at " .. prog.step)
				P.start(prog.owner)
			end
		end)
	end
end)

core.register_chatcommand("cb_populate", {
	params = "[status|stop]",
	description = S("Fill the already generated world with all structures (and the End and Nether pockets)"),
	privs = { cb_admin = true, },
	func = function(name, param)
		param = param:match("^%s*(%S*)%s*$")
		if param == "status" then
			return true, P.status()
		elseif param == "stop" then
			return true, P.stop() and S("Populate stopped; /cb_populate continues it.") or S("No populate run is going on.")
		elseif param ~= "" then
			return false, S("Usage: /cb_populate [status|stop]")
		end
		if cb_structures.populate_state then
			return false, S("A populate run is already going on (/cb_populate status).")
		end
		if cb_structures.nether_fill_state then
			return false, S("Another fill is going on; wait for it or stop it first.")
		end
		if cb_structures.scatter_state then
			return false, S("A scatter is already running (/cb_scatter stop).")
		end
		local prog = load_progress()
		P.start(name)
		if not prog.done and prog.step then
			return true, S("Populate continues at '@1'.", prog.step)
		end
		return true, S("Populate started: pockets, strongholds, then @1 structure types over the generated map.", #P.DENSITY)
	end,
})
