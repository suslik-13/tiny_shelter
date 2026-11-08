-- Chains of small islets from the main island to the outer ring: the ring lies
-- beyond the server's view, so without them the End looks like one island until
-- the dragon's gateway opens. A chain ends at the nearest outer island in its
-- quarter; the gaps can be seen across and bridged. The islets are written over
-- air after the pocket is ready, so pockets made before this code get them too:
-- one islet a second, once (a flag in mod storage; rerunning changes nothing).
local the_end = cb_dimensions.the_end
if not the_end then
	return
end

the_end.ISLET_START = 120
the_end.ISLET_STEP = 34
the_end.ISLET_CHAINS = 4
local LIGHT_UP = 3
local storage = core.get_mod_storage()

function the_end.islets(g)
	local rng = PcgRandom(the_end.seed_of(11, 22, 33))
	local list = {}
	local cx, cy, cz = g.centre.x, g.centre.y, g.centre.z
	for k = 0, the_end.ISLET_CHAINS - 1 do
		local best
		for i = 0, 11 do
			local a = k * math.pi / 2 + i * math.pi / 24
			for r = g.outer_r, g.outer_r + 240, 8 do
				local x, z = cx + math.floor(r * math.cos(a)), cz + math.floor(r * math.sin(a))
				local _, top = the_end.outer_range(g, x, z)
				if top then
					if not best or r < best.r then
						best = { a = a, r = r, y = top, }
					end
					break
				end
			end
		end
		if best then
			local n = math.floor((best.r - the_end.ISLET_START) / the_end.ISLET_STEP)
			for j = 0, n do
				local d = the_end.ISLET_START + j * the_end.ISLET_STEP
				local t = (j + 1) / (n + 2)
				list[#list + 1] = {
					x = cx + math.floor(d * math.cos(best.a)) + rng:next(-4, 4),
					y = cy + math.floor(t * (best.y - cy)) + rng:next(-2, 2),
					z = cz + math.floor(d * math.sin(best.a)) + rng:next(-4, 4),
					r = rng:next(5, 8),
					chain = k,
				}
			end
		end
	end
	return list
end

-- A flat-topped lens of end stone with ambient lights, into air only.
function the_end.write_islet(it)
	local lo, hi = vector.new(it.x - it.r, it.y - 5, it.z - it.r), vector.new(it.x + it.r, it.y + LIGHT_UP, it.z + it.r)
	local vm = core.get_voxel_manip()
	local e1, e2 = vm:read_from_map(lo, hi)
	local va = VoxelArea(e1, e2)
	local data = vm:get_data()
	local stone, air = the_end.cids().stone, core.CONTENT_AIR
	local light = core.get_content_id("cb_dimensions:ambient_light")
	for dx = -it.r, it.r do
		for dz = -it.r, it.r do
			local f = 1 - (dx * dx + dz * dz) / (it.r * it.r)
			if f > 0 then
				for y = it.y - math.floor(1 + 4 * f), it.y do
					local i = va:index(it.x + dx, y, it.z + dz)
					if data[i] == air then
						data[i] = stone
					end
				end
				if dx % 5 == 0 and dz % 5 == 0 then
					local i = va:index(it.x + dx, it.y + LIGHT_UP, it.z + dz)
					if data[i] == air then
						data[i] = light
					end
				end
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map(true)
end

function the_end.build_islets(pocket, on_done)
	local list = the_end.islets(the_end.geometry(pocket))
	local k = 0
	local function nxt()
		k = k + 1
		local it = list[k]
		if not it then
			storage:set_int("end_islets", 1)
			core.log("action", "[cubeborn] End islets written: " .. #list)
			if on_done then
				on_done(list)
			end
			return
		end
		the_end.write_islet(it)
		core.after(1, nxt)
	end
	nxt()
end

table.insert(the_end.ready_hooks, function(pocket)
	the_end.build_islets(pocket)
end)

core.register_on_mods_loaded(function()
	core.after(20, function()
		local pocket = cb_dimensions.get("end")
		if pocket and pocket.state == "ready" and storage:get_int("end_islets") == 0 then
			the_end.build_islets(pocket)
		end
	end)
end)
