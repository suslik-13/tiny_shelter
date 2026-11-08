-- Placed structures. Records live in memory and are saved one per mod_storage
-- key ("s<id>"), only when that record changes. A grid of 64-node cells maps
-- positions to parts, so a lookup near a player never scans the registry.
local storage = core.get_mod_storage()
local CELL = 64

local reg = {}
cb_structures.registry = reg

local records = {}
local grid = {}
local next_id = math.max(storage:get_int("next_id"), 1)

local function cell(v)
	return math.floor(v / CELL)
end

local function index(id, rec)
	for j, part in ipairs(rec.parts or {}) do
		for x = cell(part.minp.x), cell(part.maxp.x) do
			for y = cell(part.minp.y), cell(part.maxp.y) do
				for z = cell(part.minp.z), cell(part.maxp.z) do
					local k = x .. "," .. y .. "," .. z
					grid[k] = grid[k] or {}
					table.insert(grid[k], { id = id, j = j, })
				end
			end
		end
	end
end

local function rebuild()
	grid = {}
	for id, rec in pairs(records) do
		index(id, rec)
	end
end

function reg.save(id)
	local rec = records[id]
	storage:set_string("s" .. id, rec and core.serialize(rec) or "")
end

function reg.add(rec)
	local id = next_id
	next_id = next_id + 1
	storage:set_int("next_id", next_id)
	records[id] = rec
	reg.save(id)
	return id
end

function reg.get(id)
	return records[id]
end

function reg.all()
	return records
end

function reg.set_parts(id, parts)
	records[id].parts = parts
	index(id, records[id])
	reg.save(id)
end

function reg.remove(id)
	records[id] = nil
	reg.save(id)
	rebuild()
end

function reg.overlapping(minp, maxp)
	for id, rec in pairs(records) do
		if cb_core.intersect(minp, maxp, rec.minp, rec.maxp) then
			return id
		end
	end
end

local function box_distance(p, a, b)
	local dx = math.max(a.x - p.x, 0, p.x - b.x)
	local dy = math.max(a.y - p.y, 0, p.y - b.y)
	local dz = math.max(a.z - p.z, 0, p.z - b.z)
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Calls fn(id, j, rec, part) for every part whose box is within r of pos;
-- fn returning false stops the walk.
function reg.parts_near(pos, r, fn)
	local seen = {}
	for x = cell(pos.x - r), cell(pos.x + r) do
		for y = cell(pos.y - r), cell(pos.y + r) do
			for z = cell(pos.z - r), cell(pos.z + r) do
				for _, ref in ipairs(grid[x .. "," .. y .. "," .. z] or {}) do
					local key = ref.id * 4096 + ref.j
					if not seen[key] then
						seen[key] = true
						local rec = records[ref.id]
						local part = rec and rec.parts and rec.parts[ref.j]
						if part and box_distance(pos, part.minp, part.maxp) <= r
								and fn(ref.id, ref.j, rec, part) == false then
							return
						end
					end
				end
			end
		end
	end
end

for key, value in pairs(storage:to_table().fields) do
	local id = tonumber(key:match("^s(%d+)$"))
	if id and value ~= "" then
		records[id] = core.deserialize(value)
	end
end
rebuild()
