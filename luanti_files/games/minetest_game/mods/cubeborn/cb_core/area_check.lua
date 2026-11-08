-- Asynchronous "is this box free" check. Reads stored mapblocks only and never
-- triggers map generation: ungenerated blocks read as ignore, which is free.
-- Mass is_protected calls are avoided (protector scans a cube per call):
-- areas are queried directly and protector nodes are found by the same scan.
local PROTECTOR_NODES = { "protector:protect", "protector:protect2", "protector:protect_hidden", }
local CHECKER = "cubeborn"
local buf = {}

local function protector_radius()
	if not core.get_modpath("protector") then
		return 0
	end
	return math.min(tonumber(core.settings:get("protector_radius")) or 5, 30)
end

local function protector_cids()
	local set = {}
	for _, name in ipairs(PROTECTOR_NODES) do
		if core.registered_nodes[name] then
			set[core.get_content_id(name)] = true
		end
	end
	return set
end

-- Cheap checks first: areas and a few probes for other protection mods.
local function quick_protection(minp, maxp)
	if core.get_modpath("areas") and areas.getAreasIntersectingArea then
		local _, area = next(areas:getAreasIntersectingArea(minp, maxp))
		if area then
			return vector.copy(area.pos1)
		end
	end
	local probes = { vector.round(vector.divide(vector.add(minp, maxp), 2)), }
	for _, x in ipairs({ minp.x, maxp.x, }) do
		for _, y in ipairs({ minp.y, maxp.y, }) do
			for _, z in ipairs({ minp.z, maxp.z, }) do
				probes[#probes + 1] = vector.new(x, y, z)
			end
		end
	end
	for _, p in ipairs(probes) do
		if core.is_protected(p, CHECKER) then
			return p
		end
	end
end

-- Scans lo..hi (inside one VoxelManip read) for protector nodes and, inside
-- minp..maxp, for nodes that are not natural. Returns a failed result or nil.
local function scan(lo, hi, minp, maxp, natural, prot)
	local vm = core.get_voxel_manip()
	local e1, e2 = vm:read_from_map(lo, hi)
	local va = VoxelArea(e1, e2)
	local data = vm:get_data(buf)
	for z = lo.z, hi.z do
		for y = lo.y, hi.y do
			local idx = va:index(lo.x, y, z)
			for x = lo.x, hi.x do
				local cid = data[idx]
				if not natural[cid] then
					local p = vector.new(x, y, z)
					if prot[cid] then
						return { ok = false, reason = "protected", pos = p, }
					elseif cb_core.inside(p, minp, maxp) then
						return { ok = false, reason = "occupied", pos = p, }
					end
				end
				idx = idx + 1
			end
		end
	end
end

cb_core.jobs.register_type("cb_core:area_check", {
	step = function(st)
		if st.i >= st.n then
			st.result = { ok = true, }
			return "done"
		end
		local b = cb_core.block_at(st.b0, st.b1, st.i)
		st.i = st.i + 1
		local bmin = vector.multiply(b, 16)
		local lo, hi = cb_core.intersect(bmin, vector.add(bmin, 15), st.smin, st.smax)
		if not lo then
			return "more"
		end
		local res = scan(lo, hi, st.minp, st.maxp, cb_core.natural_cids(st.scope), st.prot)
		if res then
			st.result = res
			return "done"
		end
		return "more"
	end,
})

function cb_core.check_area(minp, maxp, callback)
	minp, maxp = vector.sort(minp, maxp)
	local p = quick_protection(minp, maxp)
	if p then
		core.after(0, callback, { ok = false, reason = "protected", pos = p, })
		return
	end
	local r = protector_radius()
	local smin, smax = vector.subtract(minp, r), vector.add(maxp, r)
	local b0, b1 = cb_core.block_range(smin, smax)
	cb_core.jobs.start("cb_core:area_check", {
		minp = minp, maxp = maxp, smin = smin, smax = smax, b0 = b0, b1 = b1,
		i = 0, n = cb_core.block_count(b0, b1), prot = protector_cids(), scope = cb_core.natural_scope(minp, maxp),
	}, {
		persist = false,
		on_done = function(st)
			callback(st.result)
		end,
	})
end

-- The same check done at once, for small boxes (a few mapblocks): no job,
-- no waiting behind other jobs. Returns {ok, reason, pos}.
function cb_core.check_area_now(minp, maxp)
	minp, maxp = vector.sort(minp, maxp)
	local p = quick_protection(minp, maxp)
	if p then
		return { ok = false, reason = "protected", pos = p, }
	end
	local r = protector_radius()
	return scan(vector.subtract(minp, r), vector.add(maxp, r), minp, maxp,
		cb_core.natural_cids(cb_core.natural_scope(minp, maxp)), protector_cids()) or { ok = true, }
end
