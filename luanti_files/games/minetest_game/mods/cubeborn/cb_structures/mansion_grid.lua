-- Woodland mansion grid, ported from Mineclonia's mcl_levelgen
-- woodland_mansion.lua (GPLv3): two storeys of 11 x 11 cells, corridors from
-- the foyer, rooms of 1, 2 or 4 cells facing a corridor, secret rooms in the
-- holes of the outline, all turned by rot. Cells name ported schematics
-- ("mansion_<name>") and a loot table or nil (empty chests).
local MG = {}
cb_structures.mansion_grid = MG
local ipairs = ipairs
local floor = math.floor
local lshift = bit.lshift
local rshift = bit.rshift
local band = bit.band
local bor = bit.bor
local mathmin = math.min
local mathmax = math.max
local mathabs = math.abs
local insert = table.insert

-- Create an unoriented mansion grid (comprising 7x7 cubes) from RNG.
-- Generate the first and second stories and reserve the two cubes at
-- the center and near the southern side for an entrance, and generate
-- a randomized network of corridors within the grid.

local BASE_WIDTH = 11
local BASE_LENGTH = 11

local function gindex (grid, x, z)
	return grid.width * z + x + 1
end

local function in_grid (grid, x, z)
	return x >= 0 and z >= 0 and x < grid.width and z < grid.length
end

-- Special module types.

local ENTRANCE = "E"
local CORRIDOR = "C"
local ALLOCATED = "."

local n_allocated = 0
local n_total = 0

local function value (grid, x, z)
	if not in_grid (grid, x, z) then
		return ALLOCATED
	end

	return grid.modules[gindex (grid, x, z)]
end

local function allocate (grid, x, z, type)
	if not in_grid (grid, x, z) then
		return ALLOCATED
	end

	local index = gindex (grid, x, z)
	local modules = grid.modules
	local old = modules[index]
	if not old then
		modules[index] = (type or ALLOCATED)
		n_allocated = n_allocated + 1
	end
	return old
end

local function restore (grid, old, x, z)
	if not in_grid (grid, x, z) then
		return
	end
	local index = gindex (grid, x, z)
	local modules = grid.modules

	if modules[index] and not old then
		n_allocated = n_allocated - 1
	end
	modules[index] = old
	return
end

local function dir_forward (dir)
	if dir == "south" then
		return 0, 1
	elseif dir == "east" then
		return 1, 0
	elseif dir == "north" then
		return 0, -1
	elseif dir == "west" then
		return -1, 0
	end
end

local function dir_left (dir)
	if dir == "south" then
		return 1, 0, "east"
	elseif dir == "east" then
		return 0, -1, "north"
	elseif dir == "north" then
		return -1, 0, "west"
	elseif dir == "west" then
		return 0, 1, "south"
	end
end

local function dir_right (dir)
	if dir == "south" then
		return -1, 0, "west"
	elseif dir == "east" then
		return 0, 1, "south"
	elseif dir == "north" then
		return 1, 0, "east"
	elseif dir == "west" then
		return 0, -1, "north"
	end
end

local iterations = 0

local function default_stop_cond ()
	iterations = iterations + 1
	return n_allocated >= n_total - 15
		or iterations > 150000
end

local function secondary_stop_cond ()
	iterations = iterations + 1
	return iterations > 150000
end

local function route_corridors_1 (rng, grid, x, z, dir, limit, stop_cond,
				  stop_on_failure)
	local lx, lz, left = dir_left (dir)
	local rx, rz, right = dir_right (dir)
	local dx, dz = dir_forward (dir)

	if limit < 0 then
		return true
	end

	if not in_grid (grid, x, z)
		or value (grid, x, z) ~= nil
		or value (grid, x + lx, z + lz) == CORRIDOR
		or value (grid, x + rx, z + rz) == CORRIDOR then
		-- Contacting corridor or out of range?
		return false
	else
		-- Decide where to turn.
		local turndir = rng:next_within (20)
		if turndir <= 17 then
			turndir = 0
		else
			turndir = turndir - 17
		end
		local old_here = allocate (grid, x, z, CORRIDOR)
		if stop_cond () then
			allocate (grid, x + lx, z + lz)
			allocate (grid, x + rx, z + rz)
			return true
		end
		for i = 0, 2 do
			local d = (turndir + i) % 3

			if d == 0 and in_grid (grid, x + dx, z + dz) then
				-- Attempt to allocate elements to the
				-- left and right and move forward.
				local old_left = allocate (grid, x + lx, z + lz)
				local old_right = allocate (grid, x + rx, z + rz)
				if stop_cond () then
					if not value (grid, x + dx, z + dz) then
						allocate (grid, x + dx, z + dz)
					end
					return true
				elseif route_corridors_1 (rng, grid, x + dx, z + dz, dir,
							  limit - 1, stop_cond, stop_on_failure) then
					return true
				elseif stop_on_failure then
					if not value (grid, x + dx, z + dz) then
						allocate (grid, x + dx, z + dz)
					end
					return false
				else
					restore (grid, old_left, x + lx, z + lz)
					restore (grid, old_right, x + rx, z + rz)
				end
			elseif d == 1 and in_grid (grid, x + lx, z + lz) then
				-- Allocate elements along a left turn.
				local old_right = allocate (grid, x + rx, z + rz)
				local old_right_corner = allocate (grid, x + rx + dx,
								   z + rz + dz)
				local old_forward = allocate (grid, x + dx, z + dz)
				if stop_cond () then
					if not value (grid, x + lx, z + lz) then
						allocate (grid, x + lx, z + lz)
					end
					return true
				elseif route_corridors_1 (rng, grid, x + lx, z + lz, left,
							  limit - 1, stop_cond, stop_on_failure) then
					return true
				elseif stop_on_failure then
					if not value (grid, x + lx, z + lz) then
						allocate (grid, x + lx, z + lz)
					end
					return false
				else
					restore (grid, old_right, x + rx, z + rz)
					restore (grid, old_right_corner, x + rx + dx,
						 z + rz + dz)
					restore (grid, old_forward, x + dx, z + dz)
				end
			elseif d == 2 and in_grid (grid, x + rx, z + rz) then
				-- Allocate elements along a right turn.
				local old_left = allocate (grid, x + lx, z + lz)
				local old_left_corner = allocate (grid, x + lx + dx,
								  z + lz + dz)
				local old_forward = allocate (grid, x + dx, z + dz)
				if stop_cond () then
					if not value (grid, x + rx, z + rx) then
						allocate (grid, x + rx, z + rz)
					end
					return true
				elseif route_corridors_1 (rng, grid, x + rx, z + rz, right,
							  limit - 1, stop_cond, stop_on_failure) then
					return true
				elseif stop_on_failure then
					if not value (grid, x + rx, z + rz) then
						allocate (grid, x + lx, z + lz)
					end
					return false
				else
					restore (grid, old_left, x + lx, z + lz)
					restore (grid, old_left_corner, x + lx + dx,
						 z + lz + dz)
					restore (grid, old_forward, x + dx, z + dz)
				end
			end
		end
		if stop_on_failure then
			if not value (grid, x + dx, z + dz) then
				allocate (grid, x + dx, z + dz)
			end
			return false
		end
		restore (grid, old_here, x, z)
		return false
	end
end

-- local debug_corridors = {
-- 	{0, 0,},
-- 	{0, 1,},
-- 	{0, 2,},
-- 	{0, 3,},
-- 	{0, 4,},
-- 	{1, 0,},
-- 	{2, 0,},
-- 	{3, 0,},
-- 	{4, 0,},
-- 	{5, 0,},
-- }

local function route_corridors (rng, grid, entrance_x, entrance_z,
				exit_x, exit_z)
	n_allocated = 4
	n_total = grid.width * grid.length

	allocate (grid, entrance_x, entrance_z + 1)
	allocate (grid, entrance_x, entrance_z, CORRIDOR)
	allocate (grid, exit_x, entrance_z + 1)
	allocate (grid, exit_x, exit_z, CORRIDOR)

	-- for _, pos in ipairs (debug_corridors) do
	-- 	allocate (grid, pos[1], pos[2], CORRIDOR)
	-- end

	while true do
		iterations = 0
		if route_corridors_1 (rng, grid, entrance_x - 1,
				      entrance_z, "west", 216,
				      default_stop_cond, false) then
			break
		end
	end

	iterations = 0
	route_corridors_1 (rng, grid, exit_x + 1, exit_z, "east",
			   216, secondary_stop_cond, true)
end

local LOOT = "woodland_mansion"

local function M (schematic_name, loot)
	return { "mansion_" .. schematic_name, loot, }
end

local modules_first_storey = {
	single = {
		M ("flower_room"), M ("office"), M ("checkerboard", LOOT), M ("white_tulip_sanctuary"),
		M ("birch_office"), M ("single_bedroom"), M ("small_dining_room"), M ("small_library"),
		M ("allium_room", "mansion_allium"),
	},
	double = {
		M ("wheat_farm"), M ("gray_banner", LOOT), M ("forge_room"), M ("pile_room"),
		M ("sapling_farm", "mansion_sapling"), M ("melon_farm"), M ("small_storage_room"),
		M ("arch_hallway", LOOT), M ("winding_staircase", LOOT), M ("illager_head"), M ("medium_library"),
		M ("master_bedroom"), M ("bedroom_with_loft", LOOT), M ("altar"), M ("clean_chest", LOOT),
		M ("ersatz_portal", "mansion_pearl"), M ("redstone_gaol"), M ("tree_chopping_room", "mansion_axe"),
	},
	quad = {
		M ("library"), M ("library"), M ("library"), M ("library"),
		M ("large_gaol"), M ("large_gaol"), M ("large_gaol"),
		M ("large_storage_room"), M ("large_storage_room"), M ("large_storage_room"), M ("large_storage_room"),
		M ("nature_room"), M ("nature_room"), M ("nature_room"), M ("nature_room"),
	},
}

local modules_second_storey = {
	single = modules_first_storey.single,
	double = {
		M ("wheat_farm"), M ("gray_banner", LOOT), M ("forge_room"), M ("pile_room"),
		M ("sapling_farm", "mansion_sapling"), M ("melon_farm"), M ("small_storage_room"),
		M ("arch_hallway", LOOT), M ("winding_staircase", LOOT), M ("illager_head"), M ("medium_library"),
		M ("master_bedroom"), M ("bedroom_with_loft", LOOT), M ("altar"),
		M ("ersatz_portal", "mansion_pearl"), M ("redstone_gaol"), M ("hidden_attic", LOOT),
		M ("tree_chopping_room", "mansion_axe"),
	},
	quad = {
		M ("situation_room"), M ("situation_room"), M ("situation_room"), M ("situation_room"),
		M ("situation_room"), M ("situation_room"), M ("situation_room"),
		M ("large_dining_room"), M ("large_dining_room"), M ("large_dining_room"), M ("large_dining_room"),
		M ("large_dining_room"), M ("large_dining_room"), M ("large_dining_room"), M ("large_dining_room"),
	},
}
local SINGLE = 0x1
local DOUBLE_0 = 0x2
local DOUBLE_90 = 0x4
local QUAD = 0x8

local function is_replaceable (grid, x, z)
	if in_grid (grid, x, z) then
		local value = value (grid, x, z)
		return value == nil or value == ALLOCATED
	end
	return false
end

local function is_corridor (grid, x, z)
	local value = value (grid, x, z)
	return value == CORRIDOR or (type (value) == "table"
				     and value.type == "corridor")
end

local function get_allocation (grid, x, z)
	local alloc = SINGLE
	local double_0_space_available = false
	local double_90_space_available = false

	if is_replaceable (grid, x, z + 1) then
		double_0_space_available = true
		-- Don't allocate an oblong module unless a corridor
		-- be present along one of its sides.
		if is_corridor (grid, x, z - 1)
			or is_corridor (grid, x, z + 2) then
			alloc = alloc + DOUBLE_0
		end
	end

	if is_replaceable (grid, x + 1, z) then
		double_90_space_available = true
		if is_corridor (grid, x - 1, z)
			or is_corridor (grid, x + 2, z) then
			alloc = alloc + DOUBLE_90
		end
	end

	if double_90_space_available
		and double_0_space_available
		and is_replaceable (grid, x + 1, z + 1) then
		alloc = alloc + QUAD
	end

	return alloc
end

local single_dirs = {
	{ "north", 0, -1, },
	{ "west", -1, 0, },
	{ "east", 1, 0, },
	{ "south", 0, 1, },
}

local function assign_single_module (grid, rng, module, x, z)
	-- What corridor to face?
	local corridors = {}

	for _, dir in ipairs (single_dirs) do
		local dx, dz = dir[2], dir[3]
		if is_corridor (grid, x + dx, z + dz) then
			insert (corridors, dir[1])
		end
	end

	if #corridors > 0 then
		local dir = corridors[1 + rng:next_within (#corridors)]
		return {
			module = module,
			facing = dir,
			type = "single",
		}
	else
		-- Otherwise, return a random orientation.
		local dir = single_dirs[1 + rng:next_within (4)][1]
		return {
			module = module,
			facing = dir,
			type = "single",
		}
	end
end

local function assign_double_module (grid, rng, module, x1, z1, x2, z2)
	local facing

	if x1 ~= x2 then
		assert (z1 == z2)
		-- DOUBLE_90

		local corridor_left
			= is_corridor (grid, x1 - 1, z1)
		local corridor_right
			= is_corridor (grid, x2 + 1, z1)

		if (corridor_left and not corridor_right)
			or (corridor_left and corridor_right
			    and rng:next_boolean ()) then
			facing = "west"
		else
			facing = "east"
		end
	else
		assert (x1 == x2 and z1 ~= z2)
		-- DOUBLE_0

		local corridor_forward
			= is_corridor (grid, x1, z1 + 1)
		local corridor_rear
			= is_corridor (grid, x1, z1 - 1)

		if (corridor_rear and not corridor_forward)
			or (corridor_rear and corridor_forward
			    and rng:next_boolean ()) then
			facing = "north"
		else
			facing = "south"
		end
	end

	return {
		module = module,
		facing = facing,
		type = "double",
		x = x1,
		z = z1,
	}
end

local quad_dirs = {
	{ "north", 0, -1, },
	{ "west", -1, 1, },
	{ "south", 1, 2, },
	{ "east", 2, 0, },
}

local function assign_quad_module (grid, rng, module, x, z)
	-- What corridor to face?
	local corridors = {}

	for _, dir in ipairs (quad_dirs) do
		local dx, dz = dir[2], dir[3]
		if is_corridor (grid, x + dx, z + dz) then
			insert (corridors, dir[1])
		end
	end

	if #corridors > 0 then
		local dir = corridors[1 + rng:next_within (#corridors)]
		return {
			module = module,
			facing = dir,
			type = "quad",
			x = x,
			z = z,
		}
	else
		-- Otherwise, return a random orientation.
		local dir = quad_dirs[1 + rng:next_within (4)][1]
		return {
			module = module,
			facing = dir,
			type = "quad",
			x = x,
			z = z,
		}
	end
end

local function classify_corridor (grid, x, z)
	local forward = is_corridor (grid, x, z + 1)
	local rear = is_corridor (grid, x, z - 1)
	local right = is_corridor (grid, x - 1, z)
	local left = is_corridor (grid, x + 1, z)

	if forward and rear and left and right then
		return "4way"
	elseif left and right and rear then
		return "3way_0"
	elseif left and forward and rear then
		return "3way_90"
	elseif left and right and forward then
		return "3way_180"
	elseif right and forward and rear then
		return "3way_270"
	elseif left and rear then
		return "left_0" -- Actually west.
	elseif left and forward then
		return "left_90"
	elseif right and rear then
		return "right_0" -- Actually east.
	elseif right and forward then
		return "right_270"
	elseif forward or rear then
		return "straight_0"
	else
		return "straight_90"
	end
end

local corridor_class_to_schematics = {
	["4way"] = { M ("corridor_4way"), "north", },
	["3way_0"] = { M ("corridor_3way"), "north", },
	["3way_90"] = { M ("corridor_3way"), "west", },
	["3way_180"] = { M ("corridor_3way"), "south", },
	["3way_270"] = { M ("corridor_3way"), "east", },
	["left_0"] = { M ("corridor_left"), "north", },
	["left_90"] = { M ("corridor_left"), "east", },
	["right_0"] = { M ("corridor_right"), "north", },
	["right_270"] = { M ("corridor_right"), "west", },
	["straight_0"] = { M ("corridor_straight"), "north", },
	["straight_90"] = { M ("corridor_straight"), "west", },
}

local function unpack2 (x)
	return x[1], x[2]
end

local foyer_module = M ("foyer")

local function assign_modules (rng, grid, module_list)
	local cnt_single = #module_list.single
	local cnt_double = #module_list.double
	local cnt_quad = #module_list.quad
	local modules = grid.modules

	for z = 0, grid.length - 1 do
		for x = 0, grid.width - 1 do
			local idx = gindex (grid, x, z)
			local current = modules[idx]
			if current == ALLOCATED then
				-- Measure the space available for
				-- this module.
				local allocation = get_allocation (grid, x, z)

				-- Select a module at random.
				local total = cnt_single
				local max_double = total
				local double_0 = band (allocation, DOUBLE_0) ~= 0
				local double_90 = band (allocation, DOUBLE_90) ~= 0
				local any_double = double_0 or double_90
				local any_quad
					= band (allocation, QUAD) ~= 0
				if any_double then
					total = total + cnt_double
					max_double = total
				end
				if any_quad then
					total = total + cnt_quad
				end

				local i = 1 + rng:next_within (total)
				if i <= cnt_single then
					local module = module_list.single[i]
					modules[idx] = assign_single_module (grid, rng, module, x, z)
				elseif i <= max_double then
					local x2, z2, idx_1
					i = i - cnt_single
					local module = module_list.double[i]
					if double_90 and double_0 then
						if rng:next_boolean () then
							idx_1 = gindex (grid, x + 1, z)
							x2, z2 = x + 1, z
						else
							idx_1 = gindex (grid, x, z + 1)
							x2, z2 = x, z + 1
						end
					elseif double_90 then
						idx_1 = gindex (grid, x + 1, z)
						x2, z2 = x + 1, z
					else
						idx_1 = gindex (grid, x, z + 1)
						x2, z2 = x, z + 1
					end
					modules[idx] = assign_double_module (grid, rng, module, x, z, x2, z2)
					modules[idx_1] = modules[idx]
				else
					i = i - max_double
					local module = module_list.quad[i]
					local idx1 = gindex (grid, x + 1, z)
					local idx2 = gindex (grid, x + 1, z + 1)
					local idx3 = gindex (grid, x, z + 1)
					modules[idx] = assign_quad_module (grid, rng, module, x, z)
					modules[idx1] = modules[idx]
					modules[idx2] = modules[idx]
					modules[idx3] = modules[idx]
				end
			elseif current == CORRIDOR then
				local class = classify_corridor (grid, x, z)
				local module, facing
					= unpack2 (corridor_class_to_schematics[class])
				modules[idx] = {
					type = "corridor",
					module = module,
					facing = facing,
				}
			elseif current == ENTRANCE then
				local idx_1 = gindex (grid, x + 1, z)
				local idx_2 = gindex (grid, x, z + 1)
				local idx_3 = gindex (grid, x + 1, z + 1)
				assert (modules[idx_1] == ENTRANCE
					and modules[idx_2] == ENTRANCE
					and modules[idx_3] == ENTRANCE)
				modules[idx] = {
					module = foyer_module,
					facing = "north",
					type = "entrance",
					x = x,
					z = z,
				}
				modules[idx_1] = modules[idx]
				modules[idx_2] = modules[idx]
				modules[idx_3] = modules[idx]
			end
		end
	end
end

local function is_broadly_quad (value)
	return value.type == "quad" or value.type == "entrance"
end

local function is_type_broadly_quad (type)
	return type == "quad" or type == "entrance"
end

local modules1
local modules2
local g_grid1
-- local g_grid2

local function is_allocated (x, z)
	if x < 0 or z < 0
		or z >= g_grid1.length or x >= g_grid1.width then
		return false
	end
	local idx = gindex (g_grid1, x, z)
	if modules1[idx] ~= nil or modules2[idx] ~= nil then
		return true
	end
	return false
end

local dir_flags = {
	north = 0x1,
	west = 0x2,
	south = 0x4,
	east = 0x8,
}

local function dir_opposite (dir)
	if dir == "west" then
		return 1, 0, "east"
	elseif dir == "north" then
		return 0, 1, "south"
	elseif dir == "east" then
		return -1, 0, "west"
	elseif dir == "south" then
		return 0, -1, "north"
	end
	assert (false)
end

local function dir_values (dir)
	if dir == "west" then
		return -1, 0, dir
	elseif dir == "north" then
		return 0, -1, dir
	elseif dir == "east" then
		return 1, 0, dir
	elseif dir == "south" then
		return 0, 1, dir
	end
	assert (false)
end

local CONCAVE = 0x4

local function outline_grids (grid1, grid2, x, z)
	local x_org, z_org = x, z
	local dx, dz, dir = -1, 0, "west"
	local sx, sz, side = 0, -1, "north"

	assert (grid1.length == grid2.length)
	assert (grid1.width == grid2.width)
	local width = grid1.width
	local outline = {}
	for i = 1, width * grid1.length do
		outline[i] = 0
	end

	modules1 = grid1.modules
	modules2 = grid2.modules
	g_grid1 = grid1
	-- g_grid2 = grid2
	repeat
		local x_next = x + dx
		local z_next = z + dz

		if is_allocated (x_next, z_next) then
			if not is_allocated (x_next + sx, z_next + sz) then
				local idx = width * z + x + 1
				x = x_next
				z = z_next
				outline[idx] = bor (outline[idx], dir_flags[side])
			else
				local idx = width * z + x + 1
				-- Concave corner.
				x = x_next + sx
				z = z_next + sz

				local new_sx, new_sz, new_side
					= dir_opposite (dir)
				dx, dz, dir = sx, sz, side
				outline[idx] = bor (outline[idx], dir_flags[side],
						    lshift (dir_flags[new_side], CONCAVE))

				local idx_1 = width * z + x + 1
				outline[idx_1]
					= bor (outline[idx_1], lshift (dir_flags[side],
								       CONCAVE))
				sx, sz, side = new_sx, new_sz, new_side
			end
		else
			-- Convex corner:
			--   ----> (~side)
			-- G G G ...
			-- G
			-- G
			-- G

			local idx = width * z + x + 1
			local dx_1, dz_1, dir_1 = dir_opposite (side)
			outline[idx] = bor (outline[idx], dir_flags[side],
					    dir_flags[dir])
			if is_allocated (x + dx_1, z + dz_1) then
				x = x + dx_1
				z = z + dz_1
				sx, sz, side = dx, dz, dir
				dx, dz, dir = dx_1, dz_1, dir_1
			else
				-- Return in reverse.
				dx, dz, dir = dir_opposite (dir)
				sx, sz, side = dx_1, dz_1, dir_1
			end
		end
	until (x == x_org and z == z_org)
	return outline
end

local outline_rotations_90 = {
	[0] = 0,
}
local outline_rotations_180 = {
	[0] = 0,
}

for i = 0x1, 0xf do
	local output_90 = 0
	local output_180 = 0

	if band (i, dir_flags.north) ~= 0 then
		output_90 = output_90 + dir_flags.east
		output_180 = output_180 + dir_flags.south
	end

	if band (i, dir_flags.east) ~= 0 then
		output_90 = output_90 + dir_flags.south
		output_180 = output_180 + dir_flags.west
	end

	if band (i, dir_flags.south) ~= 0 then
		output_90 = output_90 + dir_flags.west
		output_180 = output_180 + dir_flags.north
	end

	if band (i, dir_flags.west) ~= 0 then
		output_90 = output_90 + dir_flags.north
		output_180 = output_180 + dir_flags.east
	end
	outline_rotations_90[i] = output_90
	outline_rotations_180[i] = output_180
end

local EAST = dir_flags.east
local WEST = dir_flags.west

local NORTH = dir_flags.north
local SOUTH = dir_flags.south

local function dir_horizontal_p (dir)
	return dir == "east" or dir == "west"
end

local rotated = {}

local function rotate_module (value, arg, oldwidth, oldlength)
	-- If this is a module proper, reorient it accordingly.  A
	-- second pass will correct the origins of doubles and quads.

	if value and value.facing and not rotated[value] then
		rotated[value] = true
		if arg == "180" then
			local _, _, opposite = dir_opposite (value.facing)
			value.facing = opposite

			-- Calculate the rotated origin of this
			-- module.
			if value.type == "double" then
				if dir_horizontal_p (opposite) then
					local x = oldwidth - (value.x + 1) - 1
					local z = oldlength - value.z - 1
					value.x = x
					value.z = z
				else
					local x = oldwidth - value.x - 1
					local z = oldlength - (value.z + 1) - 1
					value.x = x
					value.z = z
				end
			elseif is_broadly_quad (value) then
				local x = oldwidth - (value.x + 1) - 1
				local z = oldlength - (value.z + 1) - 1
				value.x = x
				value.z = z
			end
		elseif arg == "90" then
			local facing = value.facing
			if facing == "north" then
				facing = "east"
			elseif facing == "east" then
				facing = "south"
			elseif facing == "south" then
				facing = "west"
			elseif facing == "west" then
				facing = "north"
			end

			if value.type == "double" then
				if dir_horizontal_p (value.facing) then
					local x = oldlength - value.z - 1
					local z = value.x
					value.x = x
					value.z = z
				else
					local x = oldlength - (value.z + 1) - 1
					local z = value.x
					value.x = x
					value.z = z
				end
			elseif is_broadly_quad (value) then
				local z = value.x
				local x = oldlength - (value.z + 1) - 1
				value.x = x
				value.z = z
			end
			value.facing = facing
		end
	end
	return value
end

local function rotate_outline (value, arg, _, _)
	if arg == "90" then
		local sides = band (value, 0xf)
		local concave = rshift (value, 4)
		return bor (outline_rotations_90[sides],
			    lshift (outline_rotations_90[concave],
				    CONCAVE))
	elseif arg == "180" then
		local sides = band (value, 0xf)
		local concave = rshift (value, 4)
		return bor (outline_rotations_180[sides],
			    lshift (outline_rotations_180[concave],
				    CONCAVE))
	else
		assert (false)
	end
end

local function rot90 (data, width, length, apply)
	local array = {}

	for dx = 0, length - 1 do
		for dz = 0, width - 1 do
			local dst_idx = dx * length + dz + 1
			local src_x = (width - dz - 1)
			local src_z = dx
			local src_idx = src_x * width + src_z + 1
			array[dst_idx] = apply (data[src_idx], "90", width, length)
		end
	end
	return array
end

local function rot180 (data, width, length, apply)
	local w_half = floor (width / 2)
	local l_half = floor (length / 2)
	local l_odd = (l_half * 2) ~= length

	-- Swap Z.
	for x = 0, width - 1 do
		for z = 0, l_half - 1 do
			local other = length - z - 1
			local idx_1 = z * width + x + 1
			local idx_2 = other * width + x + 1
			local a, b = apply (data[idx_2], "180", width, length),
				apply (data[idx_1], "180", width, length)
			data[idx_1], data[idx_2] = a, b
		end

		if l_odd then
			local idx = l_half * width + x + 1
			data[idx] = apply (data[idx], "180", width, length)
		end
	end

	-- Swap X.
	for z = 0, length - 1 do
		for x = 0, w_half - 1 do
			local other = width - x - 1
			local idx_1 = z * width + x + 1
			local idx_2 = z * width + other + 1
			data[idx_1], data[idx_2] = data[idx_2], data[idx_1]
		end
	end
end

local function rotate_1 (outline, width, length, rot, apply)
	if rot == "0" then
		return outline, width, length
	elseif rot == "90" then
		outline = rot90 (outline, width, length, apply)
		rotated = {}
		return outline, length, width
	elseif rot == "180" then
		rot180 (outline, width, length, apply)
		rotated = {}
		return outline, width, length
	elseif rot == "270" then
		rot180 (outline, width, length, apply)
		rotated = {}
		outline = rot90 (outline, width, length, apply)
		rotated = {}
		return outline, length, width
	end
	assert (false)
end

local function rotate_grids_and_outline (grid1, grid2, outline, rot)
	grid1.modules, grid1.width, grid1.length
		= rotate_1 (grid1.modules, grid1.width, grid1.length, rot,
			    rotate_module)
	grid2.modules, grid2.width, grid2.length
		= rotate_1 (grid2.modules, grid2.width, grid2.length, rot,
			    rotate_module)
	local outline, _, _
		= rotate_1 (outline, grid1.width, grid1.length, rot,
			    rotate_outline)
	return outline
end

-- Create additional secret rooms in spaces created by the outline.
local secret_rooms = {
	M ("spider"), M ("pumpkin_ring"), M ("x_room", LOOT), M ("obsidian_room"), M ("birch_pillar_room"),
}
local function alloc_secret_room (rng)
	local idx = 1 + rng:next_within (#secret_rooms)
	local dir = single_dirs[1 + rng:next_within (4)][1]
	return {
		module = secret_rooms[idx],
		facing = dir,
		type = "secret",
	}
end

local function fill_winding (rng, grid1, grid2, outline)
	local length = grid2.length
	local width = grid2.width
	local m1 = grid1.modules
	local m2 = grid2.modules

	for z = 0, length - 1 do
		local winding = false
		local base = z * width + 1

		for x = 0, length - 1 do
			local idx = base + x
			local value = outline[idx]

			if band (value, WEST) ~= 0 then
				winding = true
			end

			if winding and not m1[idx] then
				m1[idx] = alloc_secret_room (rng)
			end
			if winding and not m2[idx] then
				m2[idx] = alloc_secret_room (rng)
			end

			if band (value, EAST) ~= 0 then
				winding = false
			end
		end
	end
end

function MG.prepare (rng, rot)
	n_allocated, n_total, iterations, rotated = 0, 0, 0, {}
	local grids = {
		{
			width = BASE_WIDTH,
			length = BASE_LENGTH,
			modules = {},
		},
		{
			width = BASE_WIDTH,
			length = BASE_LENGTH,
			modules = {},
		},
	}

	local center = floor (BASE_WIDTH / 2)
	grids[1].modules[center + 1] = ENTRANCE
	grids[1].modules[center + 2] = ENTRANCE
	grids[1].modules[BASE_LENGTH + center + 1] = ENTRANCE
	grids[1].modules[BASE_LENGTH + center + 2] = ENTRANCE
	grids[2].modules[center + 1] = ENTRANCE
	grids[2].modules[center + 2] = ENTRANCE
	grids[2].modules[BASE_LENGTH + center + 1] = ENTRANCE
	grids[2].modules[BASE_LENGTH + center + 2] = ENTRANCE

	route_corridors (rng, grids[1], center - 1, 0, center + 2, 0)
	route_corridors (rng, grids[2], center - 1, 0, center + 2, 0)
	assign_modules (rng, grids[1], modules_first_storey)
	assign_modules (rng, grids[2], modules_second_storey)
	local outline = outline_grids (grids[1], grids[2], center, 0)
	fill_winding (rng, grids[1], grids[2], outline)
	outline = rotate_grids_and_outline (grids[1], grids[2], outline, rot)
	return grids, outline
end

MG.BASE_WIDTH = BASE_WIDTH
MG.value = value
