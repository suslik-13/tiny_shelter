-- Creating a pocket: first the box plus a margin is generated, so neighbouring
-- mapchunks generated later cannot carve caves into the shell; then every
-- mapblock of the box is rewritten (shell = barrier, interior = generator).
local S = cb_dimensions.S

local MARGIN = 32
local PIECE = 80
local emerging = {}
local buf = {}
-- Decoration runs in small pieces so that one job step stays near the time
-- budget: DECO_PIECE square columns cut into DECO_BAND high bands. Features may
-- reach DECO_MARGIN sideways and DECO_MARGIN_Y up or down out of their piece.
local DECO_PIECE, DECO_BAND = 16, 32
local DECO_MARGIN, DECO_MARGIN_Y = 8, 16

local function deco_grid(pocket)
	local ia, ib = cb_dimensions.inner(pocket)
	return ia, ib, math.ceil((ib.x - ia.x + 1) / DECO_PIECE), math.ceil((ib.y - ia.y + 1) / DECO_BAND),
		math.ceil((ib.z - ia.z + 1) / DECO_PIECE)
end

function cb_dimensions.decorate_count(pocket)
	local _, _, nx, ny, nz = deco_grid(pocket)
	return nx * ny * nz
end

-- Box of the i-th piece (0-based; x fastest, then z, then y): features root in
-- lo..hi and are written inside mlo..mhi.
function cb_dimensions.decorate_box(pocket, i)
	local ia, ib, nx, _, nz = deco_grid(pocket)
	local x0 = ia.x + (i % nx) * DECO_PIECE
	local z0 = ia.z + (math.floor(i / nx) % nz) * DECO_PIECE
	local y0 = ia.y + math.floor(i / (nx * nz)) * DECO_BAND
	local lo = vector.new(x0, y0, z0)
	local hi = vector.new(math.min(x0 + DECO_PIECE - 1, ib.x), math.min(y0 + DECO_BAND - 1, ib.y),
		math.min(z0 + DECO_PIECE - 1, ib.z))
	local margin = vector.new(DECO_MARGIN, DECO_MARGIN_Y, DECO_MARGIN)
	local mlo, mhi = cb_core.intersect(vector.subtract(lo, margin), vector.add(hi, margin), ia, ib)
	return lo, hi, mlo, mhi
end

function cb_dimensions.decorate_piece(pocket, def, i)
	local lo, hi, mlo, mhi = cb_dimensions.decorate_box(pocket, i)
	local vm = core.get_voxel_manip()
	local e1, e2 = vm:read_from_map(mlo, mhi)
	local data = vm:get_data(buf)
	def.decorate(data, VoxelArea(e1, e2), lo, hi, mlo, mhi, pocket)
	vm:set_data(data)
	vm:write_to_map()
end

local function emerge_box(st)
	local e0, e1 = core.get_mapgen_edges()
	return cb_core.intersect(vector.subtract(st.minp, MARGIN), vector.add(st.maxp, MARGIN), e0, e1)
end

local function piece_grid(st)
	local lo, hi = emerge_box(st)
	local n = vector.new(math.ceil((hi.x - lo.x + 1) / PIECE), math.ceil((hi.y - lo.y + 1) / PIECE),
		math.ceil((hi.z - lo.z + 1) / PIECE))
	return lo, hi, n
end

local function piece_at(lo, hi, n, i)
	local a = vector.add(lo, vector.new(i % n.x, math.floor(i / n.x) % n.y, math.floor(i / (n.x * n.y))) * PIECE)
	return a, vector.new(math.min(a.x + PIECE - 1, hi.x), math.min(a.y + PIECE - 1, hi.y), math.min(a.z + PIECE - 1, hi.z))
end

local function write_block(st, pocket, def, b)
	local bmin = vector.multiply(b, 16)
	local lo, hi = cb_core.intersect(bmin, vector.add(bmin, 15), st.minp, st.maxp)
	if not lo then
		return
	end
	local vm = core.get_voxel_manip()
	local e1, e2 = vm:read_from_map(lo, hi)
	local va = VoxelArea(e1, e2)
	local data = vm:get_data(buf)
	local c_barrier = core.get_content_id("cb_dimensions:barrier")
	local ia, ib = cb_dimensions.inner(pocket)
	for z = lo.z, hi.z do
		for y = lo.y, hi.y do
			local idx = va:index(lo.x, y, z)
			local row_inner = y >= ia.y and y <= ib.y and z >= ia.z and z <= ib.z
			for x = lo.x, hi.x do
				if not (row_inner and x >= ia.x and x <= ib.x) then
					data[idx] = c_barrier
				end
				idx = idx + 1
			end
		end
	end
	local glo, ghi = cb_core.intersect(lo, hi, ia, ib)
	if glo then
		def.generate(data, va, glo, ghi, pocket)
	end
	vm:set_data(data)
	vm:write_to_map()
end

-- Whether every shell node of mapblock b is barrier. A block written before an
-- unclean stop can be missing from the map (the map is saved on its own timer),
-- so the shell is checked again before the pocket is called ready.
local function shell_intact(st, pocket, b)
	local bmin = vector.multiply(b, 16)
	local lo, hi = cb_core.intersect(bmin, vector.add(bmin, 15), st.minp, st.maxp)
	local ia, ib = cb_dimensions.inner(pocket)
	if not lo or (cb_core.inside(lo, ia, ib) and cb_core.inside(hi, ia, ib)) then
		return true
	end
	local vm = core.get_voxel_manip()
	local e1, e2 = vm:read_from_map(lo, hi)
	local va = VoxelArea(e1, e2)
	local data = vm:get_data(buf)
	local c_barrier = core.get_content_id("cb_dimensions:barrier")
	for i in va:iterp(lo, hi) do
		if data[i] ~= c_barrier and not cb_core.inside(va:position(i), ia, ib) then
			return false
		end
	end
	return true
end

cb_core.jobs.register_type("cb_dimensions:fill", {
	label = S("Creating pocket"),
	step = function(st, job)
		local pocket = cb_dimensions.get(st.dim)
		if not pocket or pocket.state ~= "creating" then
			return "done"
		end
		if st.phase == "emerge" then
			if emerging[job.id] then
				return "wait"
			end
			local lo, hi, n = piece_grid(st)
			st.n = n.x * n.y * n.z
			if st.i >= st.n then
				st.phase, st.i = "write", 0
				return "more"
			end
			local a, b = piece_at(lo, hi, n, st.i)
			local id = job.id
			emerging[id] = true
			local failed = false
			core.emerge_area(a, b, function(_, action, remaining)
				if action == core.EMERGE_CANCELLED or action == core.EMERGE_ERRORED then
					failed = true
				end
				if remaining == 0 then
					-- A failed piece is requested again by the next step.
					emerging[id] = nil
					if not failed then
						st.i = st.i + 1
					end
				end
			end)
			return "wait"
		end
		local b0, b1 = cb_core.block_range(st.minp, st.maxp)
		st.n = cb_core.block_count(b0, b1)
		local def = cb_dimensions.get_dim(st.dim)
		if st.phase == "verify" then
			if st.i >= st.n then
				cb_dimensions.set_state(st.dim, "ready")
				return "done"
			end
			local b = cb_core.block_at(b0, b1, st.i)
			if not shell_intact(st, pocket, b) then
				core.log("action", "[cubeborn] pocket " .. st.dim .. ": rewriting block " .. core.pos_to_string(b))
				write_block(st, pocket, def, b)
			end
			st.i = st.i + 1
			return "more"
		end
		if st.phase == "decorate" then
			st.n = cb_dimensions.decorate_count(pocket)
			if st.i >= st.n then
				st.phase, st.i = "verify", 0
				return "more"
			end
			cb_dimensions.decorate_piece(pocket, def, st.i)
			st.i = st.i + 1
			return "more"
		end
		if st.i >= st.n then
			st.phase, st.i = def.decorate and "decorate" or "verify", 0
			return "more"
		end
		write_block(st, pocket, def, cb_core.block_at(b0, b1, st.i))
		st.i = st.i + 1
		return "more"
	end,
	progress = function(st)
		local part = st.n > 0 and st.i / st.n or 0
		if st.phase == "emerge" then
			return part * 0.4
		elseif st.phase == "write" then
			return 0.4 + part * 0.4
		elseif st.phase == "decorate" then
			return 0.8 + part * 0.1
		end
		return 0.9 + part * 0.1
	end,
	on_done = function(st, job)
		local pocket = cb_dimensions.get(st.dim)
		if pocket and pocket.state == "ready" then
			local def = cb_dimensions.get_dim(st.dim)
			if def and def.on_ready then
				def.on_ready(pocket)
			end
			core.log("action", "[cubeborn] pocket " .. st.dim .. " is ready")
			if job.owner then
				core.chat_send_player(job.owner, S("Pocket '@1' is ready.", st.dim))
			end
		end
	end,
})

function cb_dimensions.fill_job(dim)
	for _, job in ipairs(cb_core.jobs.list()) do
		if job.type == "cb_dimensions:fill" and job.state.dim == dim then
			return job
		end
	end
end

function cb_dimensions.start_create(dim, minp, owner)
	local def = assert(cb_dimensions.get_dim(dim), "unknown dimension: " .. dim)
	minp = vector.copy(minp)
	local maxp = vector.add(minp, vector.subtract(def.size, 1))
	cb_dimensions.add({ dim = dim, minp = minp, maxp = maxp, state = "creating", created_by = owner, time = os.time(), })
	return cb_core.jobs.start("cb_dimensions:fill",
		{ dim = dim, minp = minp, maxp = maxp, phase = "emerge", i = 0, n = 0, }, { owner = owner, })
end

-- A pocket still "creating" with no fill job (the job was dropped on an error
-- or lost) would stay unfinished for good: /cb_dim create and /cb_populate
-- see it as existing. After a restart its fill starts again from the top
-- (the write and verify phases overwrite what was already done). Runs after
-- cb_core has resumed the saved jobs.
core.register_on_mods_loaded(function()
	for dim, pocket in pairs(cb_dimensions.all()) do
		if pocket.state == "creating" and cb_dimensions.get_dim(dim) and not cb_dimensions.fill_job(dim) then
			core.log("action", "[cubeborn] pocket " .. dim .. " was left unfinished without a job, filling it again")
			cb_core.jobs.start("cb_dimensions:fill", { dim = dim, minp = vector.copy(pocket.minp),
				maxp = vector.copy(pocket.maxp), phase = "emerge", i = 0, n = 0, }, { owner = pocket.created_by, })
		end
	end
end)
