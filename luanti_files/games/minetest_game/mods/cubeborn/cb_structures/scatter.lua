-- /cb_scatter: admins spread a structure type over the map that already
-- exists. The map is cut into cells (1000x1000 nodes); every cell should end
-- up with `per_cell` structures of that type, those already there counting.
-- New ones go where the map is already generated: candidate spots whose
-- column or building area holds an ungenerated mapblock are skipped, so
-- nothing new is generated. A cell is split into as many slots as it needs
-- and each slot tries a few random spots, which keeps them spread out.
-- One spot is examined at a time (a column read and a few mapblock loads),
-- then cb_structures.place does its usual checks (protection, other
-- structures) and builds through the job queue. The run lives in memory:
-- after a restart run it again; what was placed counts as existing.
local S = cb_structures.S
local SC = { CELL = 1000, TRIES = 6, STEP = 0.2, }
cb_structures.scatter_state = nil

-- Underground types (y range or flagged) go 30 nodes below the ground.
local function underground(def)
	return def.y_max ~= nil or def.underground == true
end

-- Generated means the mapblock exists on disk: a VoxelManip read loads it,
-- or gives "ignore" without generating anything.
local function generated(pos)
	local vm = VoxelManip()
	vm:read_from_map(pos, pos)
	return vm:get_node_at(pos).name ~= "ignore"
end
SC.generated = generated

-- Every mapchunk (80 nodes) the box touches is generated (one node each).
function SC.area_generated(minp, maxp)
	for x = minp.x, maxp.x + 79, 80 do
		for y = minp.y, maxp.y + 79, 80 do
			for z = minp.z, maxp.z + 79, 80 do
				if not generated({ x = math.min(x, maxp.x), y = math.min(y, maxp.y), z = math.min(z, maxp.z), }) then
					return false
				end
			end
		end
	end
	return true
end

-- The ground at x, z: the highest solid node, not under water, between y0
-- and y1. nil when it is wet or not generated (ungenerated chunks above the
-- ground are skipped).
function SC.ground(x, z, y0, y1)
	local vm = VoxelManip()
	local e1, e2 = vm:read_from_map({ x = x, y = y0, z = z, }, { x = x, y = y1, z = z, })
	local va = VoxelArea(e1, e2)
	local data = vm:get_data()
	local ignore = core.CONTENT_IGNORE
	local seen = false
	for y = y1, y0, -1 do
		local cid = data[va:index(x, y, z)]
		if cid == ignore then
			-- ungenerated sky above is fine; a gap below what we saw is not
			if seen then
				return nil
			end
		else
			seen = true
		end
		local def = cid ~= ignore and core.registered_nodes[core.get_name_from_content_id(cid)]
		if def and (def.liquidtype or "none") ~= "none" then
			return nil
		end
		if def and def.walkable and core.get_item_group(def.name, "leaves") == 0
			and core.get_item_group(def.name, "tree") == 0 then
			return y
		end
	end
	return nil
end

local function biome_fits(def, pos)
	if not def.biome_words then
		return true
	end
	local data = core.get_biome_data(pos)
	local b = data and core.get_biome_name(data.biome) or ""
	for _, w in ipairs(def.biome_words) do
		if b:find(w, 1, true) then
			return true
		end
	end
	return false
end

-- Water structures (def.water): open sea at x, z, the origin at the surface;
-- the type's plan() judges the depth.
function SC.water_spot(def, x, z)
	local vm = VoxelManip()
	local p = { x = x, y = 0, z = z, }
	vm:read_from_map(p, vector.offset(p, 0, 2, 0))
	if core.get_item_group(vm:get_node_at(p).name, "water") == 0 or vm:get_node_at(vector.offset(p, 0, 2, 0)).name ~= "air" then
		return nil, "ground"
	end
	local origin = vector.new(x, 1, z)
	local pr = def.prepare
	if not SC.area_generated(vector.offset(origin, -pr.radius, -pr.below, -pr.radius),
			vector.offset(origin, pr.radius, pr.above, pr.radius)) then
		return nil, "ungenerated"
	end
	return origin
end

-- The origin for a structure at column x, z, or nil (and why).
function SC.spot(name, x, z)
	local def = cb_structures.get_type(name)
	if def.water then
		return SC.water_spot(def, x, z)
	end
	local g = SC.ground(x, z, -32, 240)
	if not g then
		return nil, "ground"
	end
	local origin = vector.new(x, g + 1, z)
	if def.scatter_y then
		origin.y = def.scatter_y(g)
	elseif underground(def) then
		origin.y = math.max(def.y_min or -31000, math.min(def.y_max or 31000, g - 30))
	elseif not biome_fits(def, origin) then
		return nil, "biome"
	end
	local pr = def.prepare or { radius = 48, below = 24, above = 40, }
	if not SC.area_generated(vector.offset(origin, -pr.radius, -pr.below, -pr.radius),
			vector.offset(origin, pr.radius, pr.above, pr.radius)) then
		return nil, "ungenerated"
	end
	return origin
end

local function count_in(name, minp, maxp)
	local n = 0
	for _, rec in pairs(cb_structures.registry.all()) do
		if rec.type == name and rec.minp and rec.maxp then
			local c = vector.divide(vector.add(rec.minp, rec.maxp), 2)
			n = n + ((c.x >= minp.x and c.x <= maxp.x and c.z >= minp.z and c.z <= maxp.z) and 1 or 0)
		end
	end
	return n
end

-- The cells (x/z boxes) of the map, or of opts.minp..opts.maxp.
local function cells(opts)
	local e0, e1
	if opts.minp then
		e0, e1 = opts.minp, opts.maxp
	else
		local a, b = core.get_mapgen_edges()
		e0, e1 = a, b
	end
	local size = opts.cell or SC.CELL
	local list = {}
	for x = e0.x, e1.x, size do
		for z = e0.z, e1.z, size do
			list[#list + 1] = { minp = { x = x, z = z, }, maxp = { x = math.min(x + size - 1, e1.x), z = math.min(z + size - 1, e1.z), }, }
		end
	end
	return list
end

-- Slots of a cell for `need` structures: a g x g grid, one random spot per
-- slot and try.
local function slots(cell, need, rand)
	local g = math.ceil(math.sqrt(need))
	local w, h = (cell.maxp.x - cell.minp.x + 1) / g, (cell.maxp.z - cell.minp.z + 1) / g
	local list = {}
	for i = 0, g - 1 do
		for j = 0, g - 1 do
			list[#list + 1] = { x0 = cell.minp.x + i * w, z0 = cell.minp.z + j * h, w = w, h = h, }
		end
	end
	for i = #list, 2, -1 do
		local j = rand(i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- A deterministic 31-bit seed for one structure type in one cell.
function SC.cell_seed(seed, name, minp)
	local str = tostring(seed) .. "|" .. name .. "|" .. minp.x .. "|" .. minp.z
	local h = 5381
	for i = 1, #str do
		h = (h * 33 + str:byte(i)) % 2147483647
	end
	return h
end

-- rand(n): integer 1..n; rand(): float 0..1.
local function make_rand(st, cell)
	if not st.seed then
		return function(n)
			return n and math.random(n) or math.random()
		end
	end
	local pcg = PcgRandom(SC.cell_seed(st.seed, st.name, cell.minp))
	return function(n)
		if n then
			return pcg:next(1, n)
		end
		return pcg:next(0, 1073741823) / 1073741824
	end
end

-- A slot already holding a structure of the type is left alone.
local function slot_taken(name, slot)
	for _, rec in pairs(cb_structures.registry.all()) do
		if rec.type == name and rec.minp and rec.maxp then
			local cx, cz = (rec.minp.x + rec.maxp.x) / 2, (rec.minp.z + rec.maxp.z) / 2
			if cx >= slot.x0 and cx < slot.x0 + slot.w and cz >= slot.z0 and cz < slot.z0 + slot.h then
				return true
			end
		end
	end
	return false
end

-- Nothing of the cell generated: its corners and centre at two heights.
local function cell_ungenerated(cell)
	local xs = { cell.minp.x, cell.maxp.x, math.floor((cell.minp.x + cell.maxp.x) / 2), }
	local zs = { cell.minp.z, cell.maxp.z, math.floor((cell.minp.z + cell.maxp.z) / 2), }
	for _, y in ipairs({ 0, 64, }) do
		for i, x in ipairs(xs) do
			for j, z in ipairs(zs) do
				if (i == 3) == (j == 3) and generated({ x = x, y = y, z = z, }) then
					return false
				end
			end
		end
	end
	return true
end

local function say(st, msg)
	core.log("action", "[cubeborn] scatter " .. st.name .. ": " .. core.get_translated_string("en", msg))
	if st.owner and core.get_player_by_name(st.owner) then
		core.chat_send_player(st.owner, msg)
	end
end

local step

local function next_cell(st, skipped)
	st.ci = st.ci + 1
	local cell = st.cells[st.ci]
	if not cell then
		cb_structures.scatter_state = nil
		if not st.quiet then
			say(st, S("Scatter of '@1' done: @2 placed, @3 cells already had enough, @4 missing (no free generated spot).",
				st.name, st.placed, st.full, st.missing))
		end
		if st.on_done then
			st.on_done(st)
		end
		return
	end
	if st.on_cell then
		st.on_cell(st)
	end
	local key = cell.minp.x .. "," .. cell.minp.z
	if st.seed and ((st.skip and st.skip[key]) or cell_ungenerated(cell)) then
		-- up to 64 empty cells a server step; remembered for the next types
		if st.skip then
			st.skip[key] = true
		end
		st.ungenerated = st.ungenerated + 1
		skipped = (skipped or 0) + 1
		if skipped < 64 then
			return next_cell(st, skipped)
		end
		st.slots, st.si, st.try, st.need = {}, 1, 0, 0
		return core.after(0, step, st)
	end
	st.rand = make_rand(st, cell)
	local have = count_in(st.name, { x = cell.minp.x, z = cell.minp.z, }, { x = cell.maxp.x, z = cell.maxp.z, })
	-- cells cut by the map edge get their share by area
	local size = st.cell_size
	local share = (cell.maxp.x - cell.minp.x + 1) * (cell.maxp.z - cell.minp.z + 1) / (size * size)
	local quota
	if st.seed then
		local q = st.per_cell * share
		quota = math.floor(q) + (st.rand() < q - math.floor(q) and 1 or 0)
	else
		quota = math.floor(st.per_cell * share + 0.5)
	end
	st.need = math.max(0, quota - have)
	if st.need == 0 then
		st.full = st.full + 1
	end
	-- the slot grid follows the quota, so a rerun sees the same slots
	st.slots, st.si, st.try = st.need > 0 and slots(cell, st.seed and quota or st.need, st.rand) or {}, 1, 0
	core.after(0, step, st)
end

function step(st)
	if cb_structures.scatter_state ~= st then
		return
	end
	local slot = st.slots[st.si]
	if st.need <= 0 or not slot then
		st.missing = st.missing + math.max(0, st.need)
		return next_cell(st)
	end
	if st.seed and st.try == 0 and slot_taken(st.name, slot) then
		st.si = st.si + 1
		return core.after(0, step, st)
	end
	local wait = st.delay and st.delay() or SC.STEP
	if not wait then
		-- the server lags: ask again in a second
		return core.after(1, step, st)
	end
	st.try = st.try + 1
	if st.try > SC.TRIES then
		st.si, st.try = st.si + 1, 0
		return core.after(0, step, st)
	end
	local x = math.floor(slot.x0 + slot.w * (0.15 + 0.7 * st.rand()))
	local z = math.floor(slot.z0 + slot.h * (0.15 + 0.7 * st.rand()))
	local origin, why = (st.spot or SC.spot)(st.name, x, z)
	if not origin then
		if why == "biome" and st.biome_once then
			-- as in Minecraft: the attempt is spent, no structure here
			st.biome_miss, st.need = st.biome_miss + 1, st.need - 1
			st.si, st.try = st.si + 1, 0
		end
		return core.after(wait, step, st)
	end
	cb_structures.place(st.name, origin, st.owner, function(res)
		if cb_structures.scatter_state ~= st then
			return
		end
		if res.ok then
			st.placed, st.need = st.placed + 1, st.need - 1
			st.si, st.try = st.si + 1, 0
			say(st, S("'@1' #@2 at @3.", st.name, res.id, core.pos_to_string(origin)))
			return core.after(SC.STEP + (st.after_build and st.after_build() or 0), step, st)
		end
		core.after(SC.STEP, step, st)
	end, nil, { variant = st.variant, })
end

-- Starts a scatter run; opts: minp/maxp (x, z), cell, variant, on_done, and
-- for /cb_populate: seed (deterministic cells: same quota, slots and spots on
-- every run; slots holding the type are skipped; fractional per_cell rolls
-- the fraction; cells with nothing generated are skipped at once),
-- biome_once (a spot in a wrong biome spends its slot), spot(name, x, z),
-- delay() (seconds before the next spot, nil = wait), after_build()
-- (extra seconds after a placed structure), on_cell(st), start_cell, quiet,
-- skip (a table shared by runs: cells found empty, keyed "x,z").
function SC.start(name, per_cell, owner, opts)
	opts = opts or {}
	local st = { name = name, per_cell = per_cell, owner = owner, variant = opts.variant, on_done = opts.on_done,
		cells = cells(opts), cell_size = opts.cell or SC.CELL, ci = (opts.start_cell or 1) - 1, placed = 0, full = 0,
		missing = 0, seed = opts.seed, biome_once = opts.biome_once, spot = opts.spot, delay = opts.delay,
		after_build = opts.after_build, on_cell = opts.on_cell, quiet = opts.quiet, skip = opts.skip, biome_miss = 0, ungenerated = 0,
		rand = make_rand({}, nil), }
	cb_structures.scatter_state = st
	next_cell(st)
	return st
end

function SC.stop()
	local st = cb_structures.scatter_state
	cb_structures.scatter_state = nil
	return st
end

cb_structures.scatter = SC

local USAGE = S("Usage: /cb_scatter <structure> <count per 1000x1000> | status | stop")

core.register_chatcommand("cb_scatter", {
	params = "<structure> <count per 1000x1000> | status | stop",
	description = S("Spread a structure over the already generated map"),
	privs = { cb_admin = true, },
	func = function(name, param)
		local what, n = param:match("^%s*(%S+)%s*(%d*)%s*$")
		if what == "stop" then
			return true, SC.stop() and S("Scatter stopped.") or S("No scatter is running.")
		elseif what == "status" then
			local st = cb_structures.scatter_state
			if not st then
				return true, S("No scatter is running.")
			end
			return true, S("Scatter of '@1': cell @2 of @3, @4 placed.", st.name, st.ci, #st.cells, st.placed)
		end
		local count = tonumber(n)
		if not what or not count or count < 1 or count > 50 then
			return false, USAGE
		end
		local variant
		what, variant = cb_structures.split_type(what)
		local def = cb_structures.get_type(what)
		if not def then
			return false, S("Unknown structure '@1'.", what)
		end
		if table.indexof(def.dims or {}, "overworld") < 0 then
			return false, S("'@1' belongs to another dimension.", what)
		end
		if cb_structures.auto then
			cb_structures.auto.stop()
		end
		if cb_structures.populate_state then
			return false, S("A populate run is going on (/cb_populate stop).")
		end
		if cb_structures.nether_fill_state then
			return false, S("Another fill is going on; wait for it or stop it first.")
		end
		if cb_structures.scatter_state then
			return false, S("A scatter is already running (/cb_scatter stop).")
		end
		local st = SC.start(what, count, name, { variant = variant, })
		return true, S("Scattering '@1': @2 per 1000x1000 over @3 cells of the generated map.", what, count, #st.cells)
	end,
})
