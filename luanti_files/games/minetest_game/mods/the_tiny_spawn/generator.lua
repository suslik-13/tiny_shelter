-- Generation engine: emerge -> backup -> build (VoxelManip) -> beam -> finish.
local MN = "the_tiny_spawn"
local L = the_tiny_spawn.layout
local G = {}

local storage = minetest.get_mod_storage()
local DEPTH = 16          -- how deep below the floor holes/caves are filled
local BACKUP_DIR = minetest.get_worldpath() .. "/" .. MN .. "_backup"

local function log(msg) minetest.log("action", "[" .. MN .. "] " .. msg) end

------------------------------------------------------------------------------
-- railway detection: these nodes are never modified
------------------------------------------------------------------------------
local rail_cache = {}
local RAIL_PREFIXES = {"advtrains", "carts:", "linetrack", "ks:", "subways"}

local function is_rail_name(name)
	local def = minetest.registered_nodes[name]
	if not def then return false end
	if def.drawtype == "raillike" then return true end
	local gr = def.groups or {}
	if (gr.rail or 0) > 0 or (gr.advtrains_track or 0) > 0
			or (gr.save_in_at_nodedb or 0) > 0 or (gr.connect_to_raillike or 0) > 0 then
		return true
	end
	for _, p in ipairs(RAIL_PREFIXES) do
		if name:sub(1, #p) == p then return true end
	end
	return false
end

local function is_rail(cid)
	local r = rail_cache[cid]
	if r == nil then
		r = is_rail_name(minetest.get_name_from_content_id(cid))
		rail_cache[cid] = r
	end
	return r
end

-- nodes that may be replaced by the foundation fill below the floor
local fill_cache = {}
local function replaceable_below(cid)
	local r = fill_cache[cid]
	if r == nil then
		local name = minetest.get_name_from_content_id(cid)
		local def = minetest.registered_nodes[name]
		if not def then
			r = true
		else
			local gr = def.groups or {}
			r = not def.walkable or def.liquidtype ~= "none"
				or (gr.leaves or 0) > 0 or (gr.tree or 0) > 0
		end
		fill_cache[cid] = r
	end
	return r
end

------------------------------------------------------------------------------
-- helpers
------------------------------------------------------------------------------
local function bounds(center, R)
	local g = L.geometry(R)
	local y0 = center.y - 1
	local bh = tonumber(minetest.settings:get(MN .. "_beam_height")) or 160
	return g, y0,
		{x = center.x - R, y = y0 - DEPTH, z = center.z - R},
		{x = center.x + R, y = y0 + g.HCLEAR, z = center.z + R},
		{x = center.x - 3, y = y0 + g.HCLEAR + 1, z = center.z - 3},
		{x = center.x + 3, y = y0 + math.max(bh, g.HCLEAR + 1), z = center.z + 3}
end

local function emerge(minp, maxp, cb)
	minetest.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining == 0 then cb() end
	end)
end

local function stack_list_to_strings(list)
	local out = {}
	for i, it in ipairs(list) do
		out[i] = type(it) == "string" and it or it:to_string()
	end
	return out
end

local function collect_meta(minp, maxp)
	local res = {}
	for _, pos in ipairs(minetest.find_nodes_with_meta(minp, maxp)) do
		local t = minetest.get_meta(pos):to_table()
		if t then
			local inv = {}
			for lname, list in pairs(t.inventory or {}) do
				inv[lname] = stack_list_to_strings(list)
			end
			res[#res + 1] = {pos = pos, node = minetest.get_node(pos).name,
				fields = t.fields, inventory = inv}
		end
	end
	return res
end

------------------------------------------------------------------------------
-- scan: report railways in the area (no changes)
------------------------------------------------------------------------------
function G.scan(center, R, cb)
	local _, y0, minp, maxp = bounds(center, R)
	emerge(minp, maxp, function()
		local vm = minetest.get_voxel_manip()
		local emin, emax = vm:read_from_map(minp, maxp)
		local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
		local data = vm:get_data()
		local names, levels, dirs, total = {}, {}, {N = 0, S = 0, E = 0, W = 0, C = 0}, 0
		for z = minp.z, maxp.z do
			for y = minp.y, maxp.y do
				local i = area:index(minp.x, y, z)
				for x = minp.x, maxp.x do
					local cid = data[i]
					if is_rail(cid) then
						total = total + 1
						local n = minetest.get_name_from_content_id(cid)
						names[n] = (names[n] or 0) + 1
						local h = y - y0
						levels[h] = (levels[h] or 0) + 1
						local dx, dz = x - center.x, z - center.z
						if math.abs(dx) <= 3 and math.abs(dz) <= 3 then dirs.C = dirs.C + 1
						elseif math.abs(dz) >= math.abs(dx) then
							dirs[dz > 0 and "N" or "S"] = dirs[dz > 0 and "N" or "S"] + 1
						else
							dirs[dx > 0 and "E" or "W"] = dirs[dx > 0 and "E" or "W"] + 1
						end
					end
					i = i + 1
				end
			end
		end
		cb(total, names, levels, dirs)
	end)
end

------------------------------------------------------------------------------
-- build main area
------------------------------------------------------------------------------
local function build_main(center, R, g, y0, minp, maxp, meta_before)
	local vm = minetest.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
	local data = vm:get_data()
	local p2 = vm:get_param2_data()
	local cx, cz = center.x, center.z

	-- 1. remember railway nodes
	local rails = {}
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			local i = area:index(minp.x, y, z)
			for x = minp.x, maxp.x do
				if is_rail(data[i]) then
					rails[#rails + 1] = {i = i, x = x, y = y, z = z, cid = data[i], p2 = p2[i]}
				end
				i = i + 1
			end
		end
	end

	-- painter
	local cid_cache = {}
	local function cid(name)
		local c = cid_cache[name]
		if not c then
			if minetest.registered_nodes[name] or name == "air" then
				c = minetest.get_content_id(name)
			else
				log("WARNING: unknown node " .. tostring(name) .. ", using air")
				c = minetest.get_content_id("air")
			end
			cid_cache[name] = c
		end
		return c
	end
	local C_AIR = cid("air")
	local C_STONE = cid("default:stone")
	local C_DIRT = cid("default:dirt")
	local R2 = R

	local P = {}
	function P.set(x, h, z, name, param2)
		if x < -R2 or x > R2 or z < -R2 or z > R2 then return end
		local y = y0 + h
		if y < minp.y or y > maxp.y then return end
		local i = area:index(cx + x, y, cz + z)
		data[i] = cid(name)
		p2[i] = param2 or 0
	end
	function P.get(x, h, z)
		if x < -R2 or x > R2 or z < -R2 or z > R2 then return nil end
		local y = y0 + h
		if y < minp.y or y > maxp.y then return nil end
		return minetest.get_name_from_content_id(data[area:index(cx + x, y, cz + z)])
	end

	-- 2. terrain: floor, foundation down to the ground, clear the air above
	for z = -R, R do
		for x = -R, R do
			local name, soil = L.floor_at(g, x, z)
			local wx, wz = cx + x, cz + z
			data[area:index(wx, y0, wz)] = cid(name)
			p2[area:index(wx, y0, wz)] = 0
			for h = -1, -2, -1 do
				local i = area:index(wx, y0 + h, wz)
				data[i] = soil and C_DIRT or C_STONE
				p2[i] = 0
			end
			-- fill air/water/trees under the floor down to the real ground,
			-- so the spawn always stands on land (stops at the first solid node)
			for y = y0 - 3, minp.y, -1 do
				local i = area:index(wx, y, wz)
				if not replaceable_below(data[i]) or is_rail(data[i]) then break end
				data[i] = C_STONE
				p2[i] = 0
			end
			for y = y0 + 1, maxp.y do
				local i = area:index(wx, y, wz)
				data[i] = C_AIR
				p2[i] = 0
			end
		end
	end

	-- 3. structures
	L.build_structures(P, g)

	-- 4. railways: put them back untouched and keep the space around them free
	local is_rail_pos = {}
	for _, r in ipairs(rails) do is_rail_pos[r.i] = true end
	for _, r in ipairs(rails) do
		data[r.i] = r.cid
		p2[r.i] = r.p2
		-- support below
		local below = area:contains(r.x, r.y - 1, r.z) and area:index(r.x, r.y - 1, r.z)
		if below and not is_rail_pos[below] and data[below] == C_AIR then
			data[below] = cid(MN .. ":plate_light")
		end
		-- clearance: 1 node to each side, 4 nodes up (above the floor, or for
		-- fully underground tracks, e.g. subway tunnels, below the foundation)
		local underground = r.y + 4 < y0
		for dz = -1, 1 do
			for dx = -1, 1 do
				for dy = 0, 4 do
					local y = r.y + dy
					if (y > y0 or underground) and y <= maxp.y
							and math.abs(r.x + dx - cx) <= R and math.abs(r.z + dz - cz) <= R
							and area:contains(r.x + dx, y, r.z + dz) then
						local i = area:index(r.x + dx, y, r.z + dz)
						if not is_rail_pos[i] then
							data[i] = C_AIR
							p2[i] = 0
						end
					end
				end
			end
		end
	end

	vm:set_data(data)
	vm:set_param2_data(p2)
	vm:write_to_map(true)

	-- 5. drop stale metadata of replaced nodes (chests etc. that were removed)
	for _, m in ipairs(meta_before) do
		if minetest.get_node(m.pos).name ~= m.node then
			minetest.get_meta(m.pos):from_table(nil)
		end
	end
	return #rails
end

local function build_beam(center, y0, bminp, bmaxp, R)
	local vm = minetest.get_voxel_manip()
	local emin, emax = vm:read_from_map(bminp, bmaxp)
	local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
	local data = vm:get_data()
	local c_core = minetest.get_content_id(MN .. ":beam_core")
	local c_halo = minetest.get_content_id(MN .. ":beam_halo")
	for x = -3, 3 do
		for z = -3, 3 do
			local kind = L.beam_at(x, z)
			if kind then
				for y = bminp.y, bmaxp.y do
					local i = area:index(center.x + x, y, center.z + z)
					if not is_rail(data[i]) then
						data[i] = kind == "core" and c_core or c_halo
					end
				end
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map(true)
end

-- the beam inside the main area (below HCLEAR) is painted here, after rails
local function beam_lower(center, y0, g)
	local vm = minetest.get_voxel_manip()
	local p1 = {x = center.x - 3, y = y0 + 1, z = center.z - 3}
	local p2 = {x = center.x + 3, y = y0 + g.HCLEAR, z = center.z + 3}
	local emin, emax = vm:read_from_map(p1, p2)
	local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
	local data = vm:get_data()
	local c_air = minetest.get_content_id("air")
	local c_core = minetest.get_content_id(MN .. ":beam_core")
	local c_halo = minetest.get_content_id(MN .. ":beam_halo")
	for x = -3, 3 do
		for z = -3, 3 do
			local kind = L.beam_at(x, z)
			if kind then
				for y = p1.y, p2.y do
					local i = area:index(center.x + x, y, center.z + z)
					if data[i] == c_air then
						data[i] = kind == "core" and c_core or c_halo
					end
				end
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map(true)
end

------------------------------------------------------------------------------
-- public API
------------------------------------------------------------------------------
function G.status()
	local s = storage:get_string("done")
	if s == "" then return nil end
	return minetest.deserialize(s)
end

local busy = false

-- opts: {force = bool, owner = playername}; cb(ok, message)
function G.generate(center, R, opts, cb)
	opts = opts or {}
	center = vector.round(center)
	if busy then return cb(false, "generation already running") end
	local st = G.status()
	if st and not opts.force then
		return cb(false, ("spawn was already generated at %s (r=%d). Use 'force' to build again.")
			:format(minetest.pos_to_string(st.center), st.R))
	end
	busy = true
	local g, y0, minp, maxp, bminp, bmaxp = bounds(center, R)
	local t0 = minetest.get_us_time()
	log(("generating at %s r=%d"):format(minetest.pos_to_string(center), R))

	emerge(minp, maxp, function()
		emerge(bminp, bmaxp, function()
			local ok, err = pcall(function()
				local meta_before = collect_meta(minp, maxp)
				local backup_on = minetest.settings:get_bool(MN .. "_backup", true)
				-- keep the oldest backup when rebuilding with force: it holds the original world
				if backup_on and not (st and st.backup) then
					minetest.mkdir(BACKUP_DIR)
					assert(minetest.create_schematic(minp, maxp, nil, BACKUP_DIR .. "/main.mts"),
						"could not write backup schematic")
					assert(minetest.create_schematic(bminp, bmaxp, nil, BACKUP_DIR .. "/beam.mts"),
						"could not write backup schematic (beam)")
					minetest.safe_file_write(BACKUP_DIR .. "/meta.txt", minetest.serialize({
						minp = minp, maxp = maxp, bminp = bminp, bmaxp = bmaxp, meta = meta_before,
					}))
				end
				local nrails = build_main(center, R, g, y0, minp, maxp, meta_before)
				beam_lower(center, y0, g)
				build_beam(center, y0, bminp, bmaxp, R)

				-- protection
				local area_id
				if minetest.get_modpath("areas") and areas and areas.add
						and minetest.settings:get_bool(MN .. "_protect", true) then
					if st and st.area_id and areas.areas[st.area_id] then
						areas:remove(st.area_id)
					end
					area_id = areas:add(opts.owner or "server", "Tiny Spawn",
						{x = minp.x, y = y0 - 4, z = minp.z},
						{x = maxp.x, y = bmaxp.y, z = maxp.z})
					areas:save()
				end

				-- move players that stood in the area onto the floor
				for _, pl in ipairs(minetest.get_connected_players()) do
					local p = pl:get_pos()
					if math.abs(p.x - center.x) <= R and math.abs(p.z - center.z) <= R
							and p.y >= minp.y and p.y <= maxp.y then
						pl:set_pos({x = center.x, y = center.y + 0.5, z = center.z})
					end
				end

				storage:set_string("done", minetest.serialize({
					center = center, R = R, time = os.time(), area_id = area_id,
					backup = (st and st.backup) or backup_on,
				}))
				return nrails
			end)
			busy = false
			if not ok then
				log("ERROR: " .. tostring(err))
				return cb(false, "error: " .. tostring(err))
			end
			local ms = (minetest.get_us_time() - t0) / 1000
			log(("done in %.0f ms, %d railway nodes kept"):format(ms, err))
			cb(true, ("Spawn generated at %s (radius %d) in %.1f s. Railway nodes kept: %d.")
				:format(minetest.pos_to_string(center), R, ms / 1000, err))
		end)
	end)
end

function G.undo(cb)
	local st = G.status()
	if not st then return cb(false, "nothing to undo") end
	local s = minetest.safe_file_read and minetest.safe_file_read(BACKUP_DIR .. "/meta.txt")
	if not s then
		local f = io.open(BACKUP_DIR .. "/meta.txt", "r")
		if f then s = f:read("*a"); f:close() end
	end
	local info = s and minetest.deserialize(s)
	if not info then return cb(false, "no backup found in " .. BACKUP_DIR) end
	busy = true
	emerge(info.minp, info.maxp, function()
		emerge(info.bminp, info.bmaxp, function()
			local ok, err = pcall(function()
				minetest.place_schematic(info.minp, BACKUP_DIR .. "/main.mts", "0", nil, true)
				minetest.place_schematic(info.bminp, BACKUP_DIR .. "/beam.mts", "0", nil, true)
				for _, m in ipairs(info.meta) do
					local meta = minetest.get_meta(m.pos)
					meta:from_table({fields = m.fields, inventory = m.inventory})
				end
				if st.area_id and minetest.get_modpath("areas") and areas.areas[st.area_id] then
					areas:remove(st.area_id)
					areas:save()
				end
				storage:set_string("done", "")
			end)
			busy = false
			if not ok then return cb(false, "error: " .. tostring(err)) end
			log("undo done")
			cb(true, "Spawn area restored from backup.")
		end)
	end)
end

return G
