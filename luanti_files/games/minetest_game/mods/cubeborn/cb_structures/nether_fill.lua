-- /cb_nether_fill <radius> [y]: admins add fortresses and bastions to the nether
-- mod's Nether, around one height, so that players at that height meet them.
-- The map is cut into world-aligned 432x432 cells (Minecraft's spacing of Nether
-- structures), one structure per cell at most, 2 fortresses to 3 bastions. Only
-- what a site needs is generated: a column to find the cavern floor, then the
-- structure's own box. One site at a time, under the populate load governor.
-- A cell already holding such a structure near this height is skipped, so a
-- rerun (also after a restart: the run lives in memory) only adds what is missing.
if not (cb_core.profile.nether == "external" and rawget(_G, "nether") and nether.DEPTH_FLOOR) then
	return
end
local S = cb_structures.S
local SC = cb_structures.scatter
local PL = cb_structures.populate_load

local NF = { CELL = 432, TRIES = 4, RANGE = 64, HEADROOM = 9, SAME_LEVEL = 150, MAX_RADIUS = 2000, Y_MARGIN = 100, }
cb_structures.nether_fill = NF
cb_structures.nether_fill_state = nil

local world_seed = tonumber((core.get_mapgen_setting("seed") or "0"):sub(-9)) or 0

function NF.y_ok(y)
	return y >= nether.DEPTH_FLOOR + NF.Y_MARGIN and y <= nether.DEPTH_CEILING - NF.Y_MARGIN
end

-- World-aligned cells touching the square around centre, nearest first.
function NF.cells(centre, radius)
	local list = {}
	local size = NF.CELL
	for cx = math.floor((centre.x - radius) / size), math.floor((centre.x + radius) / size) do
		for cz = math.floor((centre.z - radius) / size), math.floor((centre.z + radius) / size) do
			list[#list + 1] = { x = cx * size, z = cz * size,
				d = (cx * size + size / 2 - centre.x) ^ 2 + (cz * size + size / 2 - centre.z) ^ 2, }
		end
	end
	table.sort(list, function(a, b)
		return a.d < b.d
	end)
	return list
end

-- The cavern floor in column x, z closest to height y (within RANGE) from an
-- already loaded column, or nil.
function NF.floor_near(x, z, y)
	local vm = VoxelManip()
	local lo, hi = vector.new(x, y - NF.RANGE, z), vector.new(x, y + NF.RANGE, z)
	local e1, e2 = vm:read_from_map(lo, hi)
	local va = VoxelArea(e1, e2)
	local data = vm:get_data()
	local best, run = nil, 0
	for yy = hi.y, lo.y, -1 do
		local cid = data[va:index(x, yy, z)]
		local def = cid ~= core.CONTENT_IGNORE and core.registered_nodes[core.get_name_from_content_id(cid)]
		if not def or def.walkable or (def.liquidtype or "none") ~= "none" then
			if def and def.walkable and run >= NF.HEADROOM and (not best or math.abs(yy + 1 - y) < math.abs(best - y)) then
				best = yy + 1
			end
			run = 0
		else
			run = run + 1
		end
	end
	return best and vector.new(x, best, z) or nil
end

local function level_taken(cell, y)
	for _, rec in pairs(cb_structures.registry.all()) do
		if (rec.type == "nether_fortress" or rec.type == "bastion") and rec.minp and rec.maxp then
			local cx, cz = (rec.minp.x + rec.maxp.x) / 2, (rec.minp.z + rec.maxp.z) / 2
			if cx >= cell.x and cx < cell.x + NF.CELL and cz >= cell.z and cz < cell.z + NF.CELL
					and math.abs((rec.minp.y + rec.maxp.y) / 2 - y) <= NF.SAME_LEVEL then
				return true
			end
		end
	end
	return false
end

local function say(st, msg)
	core.log("action", "[cubeborn] nether fill: " .. core.get_translated_string("en", msg))
	if st.owner and core.get_player_by_name(st.owner) then
		core.chat_send_player(st.owner, msg)
	end
end

local function alive(st)
	return cb_structures.nether_fill_state == st
end

local next_cell

local function try_spot(st)
	if not alive(st) then
		return
	end
	local wait = PL.spot_delay()
	if not wait then
		return core.after(1, try_spot, st)
	end
	st.try = st.try + 1
	if st.try > NF.TRIES then
		st.missing = st.missing + 1
		return next_cell(st)
	end
	local cell = st.cells[st.ci]
	local x = cell.x + math.floor(NF.CELL * (0.15 + 0.7 * st.rng:next(0, 1000) / 1000))
	local z = cell.z + math.floor(NF.CELL * (0.15 + 0.7 * st.rng:next(0, 1000) / 1000))
	core.emerge_area(vector.new(x, st.y - NF.RANGE, z), vector.new(x, st.y + NF.RANGE, z), function(_, _, remaining)
		if remaining > 0 or not alive(st) then
			return
		end
		local origin = NF.floor_near(x, z, st.y)
		if not origin then
			return core.after(wait, try_spot, st)
		end
		cb_structures.place(st.kind, origin, st.owner, function(res)
			if not alive(st) then
				return
			end
			if not res.ok then
				return core.after(wait, try_spot, st)
			end
			st.placed = st.placed + 1
			say(st, S("'@1' #@2 at @3.", st.kind, res.id, core.pos_to_string(origin)))
			core.after(SC.STEP + PL.pause_after_build(), next_cell, st)
		end)
	end)
end

function next_cell(st)
	if not alive(st) then
		return
	end
	st.ci = st.ci + 1
	local cell = st.cells[st.ci]
	if not cell then
		cb_structures.nether_fill_state = nil
		PL.stop()
		say(st, S("Nether fill finished: @1 placed, @2 cells already had one, @3 without a free spot.",
			st.placed, st.full, st.missing))
		if st.on_done then
			st.on_done(st)
		end
		return
	end
	if level_taken(cell, st.y) then
		st.full = st.full + 1
		return core.after(0, next_cell, st)
	end
	st.rng = PcgRandom(SC.cell_seed(world_seed, "nether_fill|" .. st.y, cell))
	st.kind = st.rng:next(1, 5) <= 2 and "nether_fortress" or "bastion"
	st.try = 0
	try_spot(st)
end

-- opts (tests): on_done(st).
function NF.start(owner, centre, radius, y, opts)
	local st = { owner = owner, y = y, cells = NF.cells(centre, radius), ci = 0, placed = 0, full = 0, missing = 0,
		on_done = opts and opts.on_done, }
	cb_structures.nether_fill_state = st
	PL.start()
	next_cell(st)
	return st
end

function NF.stop()
	local st = cb_structures.nether_fill_state
	cb_structures.nether_fill_state = nil
	if st then
		PL.stop()
	end
	return st
end

local USAGE = S("Usage: /cb_nether_fill <radius> [y] | status | stop")

core.register_chatcommand("cb_nether_fill", {
	params = "<radius> [y] | status | stop",
	description = S("Add fortresses and bastions to the Nether around you, at one height (radius up to 2000; y: your height by default)"),
	privs = { cb_admin = true, },
	func = function(name, param)
		local word = param:match("^%s*(%S*)%s*$")
		local st = cb_structures.nether_fill_state
		if word == "status" then
			if not st then
				return true, S("No Nether fill is going on.")
			end
			return true, S("Nether fill at height @1: cell @2 of @3, @4 placed.", st.y, st.ci, #st.cells, st.placed)
		elseif word == "stop" then
			return true, NF.stop() and S("Nether fill stopped; run the command again to go on.")
				or S("No Nether fill is going on.")
		end
		local radius, ys = param:match("^%s*(%d+)%s*(-?%d*)%s*$")
		radius = tonumber(radius)
		if not radius or radius < 1 or radius > NF.MAX_RADIUS then
			return false, USAGE
		end
		if cb_structures.auto then
			cb_structures.auto.stop()
		end
		if st or cb_structures.populate_state or cb_structures.scatter_state then
			return false, S("Another fill is going on; wait for it or stop it first.")
		end
		-- the player's place when in the Nether, else the middle of the map
		local player = core.get_player_by_name(name)
		local pos = player and player:get_pos()
		local here = pos and cb_structures.dim_at(pos) == "nether"
		local centre = here and vector.round(pos) or vector.new(0, 0, 0)
		local y = tonumber(ys) or (here and centre.y or nil)
		if not y then
			return false, S("Give a height when you are not in the Nether.")
		end
		if not NF.y_ok(y) then
			return false, S("The height must lie between @1 and @2.", nether.DEPTH_FLOOR + NF.Y_MARGIN,
				nether.DEPTH_CEILING - NF.Y_MARGIN)
		end
		local run = NF.start(name, centre, radius, y)
		return true, S("Nether fill started: @1 cells around @2, @3 at height @4; this generates new map.", #run.cells,
			centre.x, centre.z, y)
	end,
})
