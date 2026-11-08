-- End decorations (fill job decorate phase): chorus plants on the outer
-- islands, and ambient light over every island surface, since pockets lie
-- deep underground without sunlight. When the pocket is ready, a crystal is
-- set on every pillar.
local the_end = cb_dimensions.the_end
if not the_end then
	return
end

local LIGHT_GRID, LIGHT_UP = 6, 3

core.register_node("cb_dimensions:ambient_light", {
	description = cb_dimensions.S("Ambient Light"),
	drawtype = "airlike",
	paramtype = "light",
	light_source = 11,
	sunlight_propagates = true,
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = true,
	floodable = true,
	drop = "",
	groups = { not_in_creative_inventory = 1, },
})
cb_core.register_natural("cb_dimensions:ambient_light", "pocket")

local DIRS = { { 1, 0, }, { -1, 0, }, { 0, 1, }, { 0, -1, }, }

-- A chorus plant rooted at (x, y, z): a stem of 2-5, up to 3 branches with
-- flowers, a flower on top. put(x, y, z, id) writes into air only.
function the_end.chorus(put, x, y, z, rng, plant, flower)
	local h = rng:next(2, 5)
	for k = 0, h - 1 do
		if not put(x, y + k, z, plant) then
			return
		end
	end
	local top = y + h
	for _ = 1, rng:next(0, 3) do
		local d = DIRS[rng:next(1, 4)]
		local bx, bz = x + d[1], z + d[2]
		if put(bx, top - 1, bz, plant) then
			local up = rng:next(1, 3)
			for k = 1, up do
				put(bx, top - 1 + k, bz, plant)
			end
			put(bx, top + up, bz, flower)
		end
	end
	put(x, top, z, flower)
end

function the_end.decorate(data, va, lo, hi, mlo, mhi, pocket)
	local ids = the_end.cids()
	local g = the_end.geometry(pocket)
	local AIR = core.CONTENT_AIR
	local light = core.get_content_id("cb_dimensions:ambient_light")
	local plant, flower = core.get_content_id("cb_blocks:chorus_plant"), core.get_content_id("cb_blocks:chorus_flower")
	local function put(x, y, z, id)
		if x < mlo.x or x > mhi.x or y < mlo.y or y > mhi.y or z < mlo.z or z > mhi.z then
			return false
		end
		local i = va:index(x, y, z)
		if data[i] ~= AIR then
			return false
		end
		data[i] = id
		return true
	end
	local y1 = math.max(lo.y, mlo.y + 1)
	for z = lo.z, hi.z do
		for x = lo.x, hi.x do
			local grid = (x - g.ia.x) % LIGHT_GRID == 0 and (z - g.ia.z) % LIGHT_GRID == 0
			local outer = the_end.outer_range(g, x, z) ~= nil
			if grid or outer then
				local vi = va:index(x, y1 - 1, z)
				for y = y1, hi.y do
					local below = data[vi]
					vi = vi + va.ystride
					if below == ids.stone and data[vi] == AIR then
						if grid then
							put(x, y + LIGHT_UP, z, light)
						end
						if outer then
							local rng = PcgRandom(the_end.seed_of(x, y, z))
							if rng:next(1, 60) == 1 then
								the_end.chorus(put, x, y, z, rng, plant, flower)
							end
						end
					end
				end
			end
		end
	end
end

-- Nodes the crystals stand on: the bedrock tops of the pillars (small test
-- pockets cut the pillars off; no crystals outside the pocket).
function the_end.crystal_spots(pocket)
	local g = the_end.geometry(pocket)
	local spots = {}
	for _, p in ipairs(g.pillars) do
		local top = vector.new(p.x, g.centre.y + p.h + 1, p.z)
		if cb_core.inside(vector.offset(top, 0, 3, 0), g.ia, g.ib) then
			spots[#spots + 1] = top
		end
	end
	return spots
end

local function crystal_on(spot)
	for _, obj in ipairs(core.get_objects_inside_radius(vector.offset(spot, 0, 0.5, 0), 1)) do
		local e = obj:get_luaentity()
		if e and e.name == "cb_items:end_crystal" then
			return obj
		end
	end
end
the_end.crystal_on = crystal_on

function the_end.place_crystals(pocket)
	for _, top in ipairs(the_end.crystal_spots(pocket)) do
		core.load_area(vector.offset(top, -1, -1, -1), vector.offset(top, 1, 3, 1))
		if not crystal_on(top) then
			cb_items.spawn_crystal(top)
		end
	end
end

-- The dragon's respawn rebuilds the pillars as generated; blocks around
-- them stay.
function the_end.rebuild_pillars(pocket)
	local ids = the_end.cids()
	local g = the_end.geometry(pocket)
	local cy = g.centre.y
	for _, p in ipairs(g.pillars) do
		local lo, hi = cb_core.intersect(vector.new(p.x - 4, cy - 10, p.z - 4), vector.new(p.x + 4, cy + p.h + 4, p.z + 4),
			g.ia, g.ib)
		if lo then
			local vm = core.get_voxel_manip()
			local e1, e2 = vm:read_from_map(lo, hi)
			local va, data = VoxelArea(e1, e2), vm:get_data()
			for z = lo.z, hi.z do
				for y = lo.y, hi.y do
					for x = lo.x, hi.x do
						local id = the_end.pillar_node(p, x - p.x, z - p.z, y, cy, ids)
						if id then
							data[va:index(x, y, z)] = id
						end
					end
				end
			end
			vm:set_data(data)
			vm:write_to_map(true)
		end
	end
end

the_end.ready_hooks = {}

function the_end.on_ready(pocket)
	the_end.place_crystals(pocket)
	for _, fn in ipairs(the_end.ready_hooks) do
		fn(pocket)
	end
end

cb_dimensions.set_decorator("end", the_end.decorate)
cb_dimensions.set_on_ready("end", the_end.on_ready)
