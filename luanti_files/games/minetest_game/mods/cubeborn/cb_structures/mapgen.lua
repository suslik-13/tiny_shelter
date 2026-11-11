-- Structures with the world (cubeborn.structures_on_mapgen, off by default):
-- for a server started on a new map, no /cb_populate needed. Every mapchunk
-- the generator makes marks its 1000x1000 cell (the cells of /cb_populate);
-- a cell that got no new chunk for A.SETTLE seconds is filled with the
-- /cb_populate steps run over that cell only: the strongholds of the ring
-- inside it, every Overworld type, and the nether mod's Nether types. The
-- cells use the world seed, so a cell filled again (more of it generated
-- since) only gets the slots that were missing, and /cb_populate later adds
-- nothing twice. The End and own Nether pockets are created once at start.
-- Structures need their building area generated, so they come a moment
-- after the land, near where players explore. Admin fills (/cb_populate,
-- /cb_scatter, /cb_nether_fill) go first: a cell being filled is put back.
local SC = cb_structures.scatter
local P = cb_structures.populate
local PL = cb_structures.populate_load
local storage = core.get_mod_storage()

local A = {
	ENABLED = core.settings:get_bool("cubeborn.structures_on_mapgen", false),
	SETTLE = 15, -- seconds without new chunks before a cell is filled
	TICK = 2,
	START_S = 10, -- pockets are created this long after the start
}
cb_structures.auto = A
cb_structures.auto_state = nil

-- Cells waiting: key "x,z" (cell minp) -> time of the first new chunk.
-- (Clock of this server run; cells kept from the last run settle at once.)
local dirty = core.deserialize(storage:get_string("auto_dirty")) or {}
for key in pairs(dirty) do
	dirty[key] = -A.SETTLE
end
local changed = false
local clock = 0

function A.now()
	return clock
end

local function save()
	if changed then
		storage:set_string("auto_dirty", core.serialize(dirty))
		changed = false
	end
end

-- The cell (x/z box) holding x, z, aligned as /cb_populate's cells.
function A.cell_at(x, z)
	local e0, e1 = core.get_mapgen_edges()
	local size = SC.CELL
	local cx = e0.x + math.floor((x - e0.x) / size) * size
	local cz = e0.z + math.floor((z - e0.z) / size) * size
	return { x = cx, z = cz, }, { x = math.min(cx + size - 1, e1.x), z = math.min(cz + size - 1, e1.z), }
end

-- Heights where structures stand: the Overworld ground (SC.spot looks
-- between -32 and 240, underground types down to their depth) and the nether
-- mod's Nether. Chunks elsewhere (pockets, sky) mark nothing.
local function y_counts(y0, y1)
	if y1 >= -160 and y0 <= 240 then
		return true
	end
	local N = rawget(_G, "nether")
	return cb_core.profile.nether == "external" and N and N.DEPTH_FLOOR ~= nil
		and y1 >= N.DEPTH_FLOOR and y0 <= N.DEPTH_CEILING
end

function A.mark(minp, maxp)
	if not y_counts(minp.y, maxp.y) then
		return
	end
	for _, x in ipairs({ minp.x, maxp.x, }) do
		for _, z in ipairs({ minp.z, maxp.z, }) do
			local c = A.cell_at(x, z)
			local key = c.x .. "," .. c.z
			if not dirty[key] then
				dirty[key] = clock
				changed = true
			end
		end
	end
end

function A.pending()
	return dirty
end

local function key_of(c)
	return c.x .. "," .. c.z
end

local function finish(st, requeue)
	if cb_structures.auto_state ~= st then
		return
	end
	cb_structures.auto_state = nil
	if requeue and not dirty[st.key] then
		dirty[st.key] = clock - A.SETTLE
		changed = true
	end
	if cb_structures.scatter_state and cb_structures.scatter_state == st.sc then
		SC.stop()
	end
	if not cb_structures.populate_state then
		PL.stop()
	end
	if st.placed > 0 then
		core.log("action", ("[cubeborn] structures with the world: %d placed in the cell at %s"):format(st.placed, st.key))
	end
	if st.on_done then
		st.on_done(st)
	end
end

-- Stops the cell being filled (it is filled again later); admin fills call
-- it before they start.
function A.stop()
	local st = cb_structures.auto_state
	if st then
		finish(st, true)
	end
	return st
end

local function busy()
	return cb_structures.populate_state or cb_structures.scatter_state or cb_structures.nether_fill_state
end

local function alive(st)
	return cb_structures.auto_state == st
end

local function next_step(st)
	if not alive(st) then
		return
	end
	st.i = st.i + 1
	local s = st.steps[st.i]
	if not s then
		return finish(st, false)
	end
	if s.kind == "strongholds" then
		return st.run_strongholds(st)
	end
	local cell = SC.CELL
	st.sc = SC.start(s.name, s.per * (cell / 1000) ^ 2, nil, {
		minp = st.minp, maxp = st.maxp, cell = cell, seed = P.world_seed, biome_once = true,
		spot = P.spot_for(s), delay = PL.spot_delay, after_build = PL.pause_after_build, quiet = true,
		on_done = function(sc)
			if alive(st) then
				st.placed, st.sc = st.placed + sc.placed, nil
				next_step(st)
			end
		end,
	})
end

-- The ring's strongholds inside the cell whose area is generated.
local function run_strongholds(st)
	local spots = {}
	for _, sp in ipairs(P.ring_spots(P.world_seed, P.map_half())) do
		if sp.x >= st.minp.x and sp.x <= st.maxp.x and sp.z >= st.minp.z and sp.z <= st.maxp.z then
			spots[#spots + 1] = sp
		end
	end
	local k = 0
	local function nxt()
		if not alive(st) then
			return
		end
		k = k + 1
		local sp = spots[k]
		if not sp then
			return next_step(st)
		end
		if P.stronghold_near(sp.x, sp.z) then
			return nxt()
		end
		local origin = SC.spot("stronghold", sp.x, sp.z)
		if not origin then
			return nxt()
		end
		cb_structures.place("stronghold", origin, nil, function(res)
			if alive(st) then
				st.placed = st.placed + (res.ok and 1 or 0)
				core.after(0, nxt)
			end
		end)
	end
	nxt()
end

-- The steps of a cell: /cb_populate's without the pockets.
function A.steps()
	local list = {}
	for _, s in ipairs(P.steps()) do
		if s.kind ~= "pocket" then
			list[#list + 1] = s
		end
	end
	return list
end

-- Fills one cell (minp: its corner, x/z); opts (tests): steps, on_done.
function A.fill(minp, opts)
	opts = opts or {}
	local c0, c1 = A.cell_at(minp.x, minp.z)
	local st = { key = key_of(c0), minp = c0, maxp = c1, steps = opts.steps or A.steps(), i = 0, placed = 0,
		on_done = opts.on_done, run_strongholds = run_strongholds, }
	cb_structures.auto_state = st
	PL.start()
	next_step(st)
	return st
end

-- The oldest settled cell, or nil.
local function settled()
	local best, bt
	for key, t in pairs(dirty) do
		if clock - t >= A.SETTLE and (not bt or t < bt) then
			best, bt = key, t
		end
	end
	return best
end

local timer = 0
local function tick(dtime)
	clock = clock + dtime
	timer = timer + dtime
	if timer < A.TICK then
		return
	end
	timer = 0
	local st = cb_structures.auto_state
	-- a scatter of ours stopped from outside (/cb_scatter stop): put it back
	if st and st.sc and cb_structures.scatter_state ~= st.sc then
		finish(st, true)
	end
	if not cb_structures.auto_state and not busy() then
		local key = settled()
		if key then
			dirty[key] = nil
			changed = true
			local x, z = key:match("^(-?%d+),(-?%d+)$")
			A.fill({ x = tonumber(x), z = tonumber(z), })
		end
	end
	save()
end

-- The End and own Nether pockets, created once when they are missing.
function A.create_pockets(done)
	local dims = {}
	for _, s in ipairs(P.steps()) do
		if s.kind == "pocket" then
			dims[#dims + 1] = s.dim
		end
	end
	local i = 0
	local function nxt()
		i = i + 1
		local dim = dims[i]
		if not dim then
			return done and done(dims)
		end
		cb_dimensions.create_auto(dim, nil, function(ok, msg)
			core.log("action", "[cubeborn] structures with the world: pocket '" .. dim .. "' "
				.. (ok and "is being created" or ("skipped: " .. core.get_translated_string("en", msg or ""))))
			nxt()
		end)
	end
	nxt()
end

if A.ENABLED then
	core.log("action", "[cubeborn] structures are placed with the world (cubeborn.structures_on_mapgen)")
	core.register_on_generated(function(minp, maxp)
		A.mark(minp, maxp)
	end)
	core.register_globalstep(tick)
	core.register_on_shutdown(function()
		-- a cell cut short is filled again after the restart
		local st = cb_structures.auto_state
		if st and not dirty[st.key] then
			dirty[st.key] = -A.SETTLE
			changed = true
		end
		save()
	end)
	core.register_on_mods_loaded(function()
		core.after(A.START_S, A.create_pockets)
	end)
end
