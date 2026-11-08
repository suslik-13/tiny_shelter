-- Dimension definitions and the registry of created pockets. A pocket is a box
-- below MAX_Y whose outer SHELL nodes on every side are unbreakable barrier.
local S = cb_dimensions.S
local storage = core.get_mod_storage()

local SHELL = 3
cb_dimensions.SHELL = SHELL
cb_dimensions.MAX_Y = tonumber(cb_core.setting("cubeborn.pocket_max_y", "-1500")) or -1500

local dims = {}
local pockets = {}

for name, p in pairs(core.deserialize(storage:get_string("pockets")) or {}) do
	p.minp, p.maxp = vector.copy(p.minp), vector.copy(p.maxp)
	pockets[name] = p
end

local function save()
	storage:set_string("pockets", core.serialize(pockets))
end

local function air_generator(data, va, lo, hi)
	local c_air = core.CONTENT_AIR
	for i in va:iterp(lo, hi) do
		data[i] = c_air
	end
end

function cb_dimensions.register_dim(name, def)
	local min = 2 * SHELL + 8
	assert(def.size.x >= min and def.size.y >= min and def.size.z >= min, "pocket size too small: " .. name)
	dims[name] = { size = vector.copy(def.size), label = def.label or name, generate = def.generate or air_generator, }
end

function cb_dimensions.set_generator(name, fn)
	assert(dims[name], "unknown dimension: " .. name)
	dims[name].generate = fn
end

-- fn(data, va, lo, hi, mlo, mhi, pocket): place features rooted in lo..hi,
-- writing only inside mlo..mhi. Runs after the whole pocket is written.
function cb_dimensions.set_decorator(name, fn)
	assert(dims[name], "unknown dimension: " .. name)
	dims[name].decorate = fn
end

-- fn(pocket): called once when the fill job has made the pocket ready, for
-- things a VoxelManip cannot place (entities).
function cb_dimensions.set_on_ready(name, fn)
	assert(dims[name], "unknown dimension: " .. name)
	dims[name].on_ready = fn
end

function cb_dimensions.get_dim(name)
	return dims[name]
end

function cb_dimensions.dim_names()
	local names = {}
	for name in pairs(dims) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

function cb_dimensions.get(dim)
	return pockets[dim]
end

function cb_dimensions.all()
	return pockets
end

function cb_dimensions.add(pocket)
	pocket.minp, pocket.maxp = vector.copy(pocket.minp), vector.copy(pocket.maxp)
	pockets[pocket.dim] = pocket
	save()
end

function cb_dimensions.set_state(dim, state)
	if pockets[dim] then
		pockets[dim].state = state
		save()
	end
end

function cb_dimensions.remove(dim)
	pockets[dim] = nil
	save()
end

function cb_dimensions.inner(pocket)
	return vector.add(pocket.minp, SHELL), vector.subtract(pocket.maxp, SHELL)
end

function cb_core.natural_scope(minp, maxp)
	for _, p in pairs(pockets) do
		if cb_core.intersect(minp, maxp, p.minp, p.maxp) then
			return "pocket"
		end
	end
	return "world"
end

function cb_dimensions.is_shell(pos)
	for _, p in pairs(pockets) do
		if cb_core.inside(pos, p.minp, p.maxp) then
			local a, b = cb_dimensions.inner(p)
			return not cb_core.inside(pos, a, b), p
		end
	end
	return false
end

local own_nether = cb_core.profile.nether == "own"
if own_nether then
	cb_dimensions.register_dim("nether", {
		label = S("Nether"),
		size = cb_core.setting_vector("cubeborn.nether_size", vector.new(528, 136, 528)),
	})
end
if cb_core.profile.end_dim then
	cb_dimensions.register_dim("end", {
		label = S("The End"),
		size = cb_core.setting_vector("cubeborn.end_size",
			own_nether and vector.new(640, 256, 640) or vector.new(1200, 256, 1200)),
	})
end
