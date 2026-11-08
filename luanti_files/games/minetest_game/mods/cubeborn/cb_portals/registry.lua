-- Lit Nether portals of both worlds, kept in mod storage so that linking never
-- scans the map. Entry: {pos = opening min corner, axis = "x"|"z", w, h, dim}.
local storage = core.get_mod_storage()
local list = {}
for _, p in ipairs(core.deserialize(storage:get_string("portals")) or {}) do
	p.pos = vector.copy(p.pos)
	list[#list + 1] = p
end

local function save()
	storage:set_string("portals", core.serialize(list))
end

function cb_portals.all()
	return list
end

function cb_portals.add(p)
	p.pos = vector.copy(p.pos)
	list[#list + 1] = p
	save()
	return p
end

function cb_portals.remove(p)
	for i, q in ipairs(list) do
		if q == p then
			table.remove(list, i)
			save()
			return
		end
	end
end

function cb_portals.interior(p)
	local w = p.w - 1
	return p.pos, vector.new(p.pos.x + (p.axis == "x" and w or 0), p.pos.y + p.h - 1, p.pos.z + (p.axis == "z" and w or 0))
end

function cb_portals.covering(pos)
	for _, p in ipairs(list) do
		local a, b = cb_portals.interior(p)
		if cb_core.inside(pos, a, b) then
			return p
		end
	end
end

function cb_portals.dim_at(pos)
	local pocket = cb_dimensions.get("nether")
	if pocket and cb_core.inside(pos, pocket.minp, pocket.maxp) then
		return "nether"
	end
	return "overworld"
end

-- Nearest working portal of `dim` within `radius` (horizontal). A candidate is
-- loaded and its frame checked; broken ones (TNT, WorldEdit, VoxelManip) are
-- dropped from the registry and the next one is tried.
function cb_portals.nearest(dim, pos, radius)
	while true do
		local best, best_d
		for _, p in ipairs(list) do
			if p.dim == dim then
				local dx, dz = p.pos.x - pos.x, p.pos.z - pos.z
				local dist = math.sqrt(dx * dx + dz * dz)
				if dist <= radius and (not best_d or dist < best_d) then
					best, best_d = p, dist
				end
			end
		end
		if not best then
			return nil
		end
		local a, b = cb_portals.interior(best)
		core.load_area(vector.offset(a, -1, -1, -1), vector.offset(b, 1, 1, 1))
		if core.get_node(best.pos).name == cb_portals.NODE and cb_portals.frame_intact(best) then
			return best
		end
		cb_portals.deactivate(best)
	end
end
