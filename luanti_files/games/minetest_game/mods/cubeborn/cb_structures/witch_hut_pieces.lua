-- Witch hut piece, ported by tools/port_witch_hut.py from Mineclonia's
-- mcl_levelgen/swamp_hut.lua (GPLv3, Mineclonia contributors; based on
-- Minecraft's SwampHutGenerator); do not edit.
local A = cb_structures.piecegen
local WIDTH, LENGTH, HEIGHT = 7, 9, 7

------------------------------------------------------------------------
-- Swamp Hut.
-- https://maven.fabricmc.net/docs/yarn-1.20.4+build.1/net/minecraft/structure/SwampHutGenerator.html
------------------------------------------------------------------------

local ipos3 = A.ipos3
local reorientate_coords = A.reorientate_coords
local set_block = A.set_block

local mathmin = math.min
local mathmax = math.max


local cid_air = "air"
local cid_oak_fence = "default:fence_wood"
local cid_potted_red_mushroom
	= A.first ("flowers:mushroom_red", "air")
local cid_crafting_table
	= A.first ("xdecor:workbench", "default:wood")
local cid_cauldron
	= cb_core.equiv ("village_cauldron")
local cid_spruce_stairs
	= "stairs:stair_pine_wood"
local cid_spruce_stairs_outer
	= A.first ("stairs:stair_outer_pine_wood", "stairs:stair_pine_wood")
local cid_spruce_planks
	= "default:pine_wood"
local cid_oak_log
	= "default:tree"

local function fill_box_rotated (piece, x1, y1, z1, x2, y2, z2, cid, param2)
	local x1, y1, z1 = reorientate_coords (piece, x1, y1, z1)
	local x2, y2, z2 = reorientate_coords (piece, x2, y2, z2)

	for x, y, z in ipos3 (mathmin (x1, x2),
			      y1,
			      mathmin (z1, z2),
			      mathmax (x1, x2),
			      y2,
			      mathmax (z1, z2)) do
		set_block (x, y, z, cid, param2)
	end
end

local function set_block_reorientated (piece, x, y, z, cid, param2)
	local x, y, z = reorientate_coords (piece, x, y, z)
	set_block (x, y, z, cid, param2)
end

local corners = {
	1, 2,
	1, 7,
	5, 2,
	5, 7,
}

local is_water_air_or_lava = A.is_water_air_or_lava

local function build_foundation_column (level_min, x, y, z)
	while y > level_min + 1 do
		if not is_water_air_or_lava (x, y, z) then
			break
		end
		set_block (x, y, z, cid_oak_log, 0)
		y = y - 1
	end
end

local function fill_supports (self, level_min, dx, dy, dz)
	local x, y, z = reorientate_coords (self, dx, dy, dz)
	build_foundation_column (level_min, x, y, z)
end

local facedirs = {
	north = 0,
	east = 1,
	south = 2,
	west = 3,
}

local reverse_facedirs = {
	north = 2,
	east = 3,
	south = 0,
	west = 1,
}

local left_facedirs = {
	north = 3,
	south = 3,
	west = 0,
	east = 0,
}

local right_facedirs = {
	north = 1,
	south = 1,
	west = 2,
	east = 2,
}

local northwest_stair_dirs = {
	north = 1,
	west = 3,
	south = 2,
	east = 2,
}

local northeast_stair_dirs = {
	north = 0,
	west = 0,
	south = 3,
	east = 1,
}

local southwest_stair_dirs = {
	north = 2,
	west = 2,
	south = 1,
	east = 3,
}

local southeast_stair_dirs = {
	north = 3,
	west = 1,
	south = 0,
	east = 0,
}

local staticdata_witch = core.serialize ({
	_structure_generation_spawn = true,
	persistent = true,
})
local staticdata_black_cat = core.serialize ({
	_structure_generation_spawn = true,
	persistent = true,
	_default_texture = "mobs_mc_cat_all_black.png",
})

local create_entity = A.create_entity

local function swamp_hut_place (self, level, terrain, rng, x1, z1, x2, z2)
	fill_box_rotated (self, 1, 1, 1, 5, 1, 7, cid_spruce_planks, 0)
	fill_box_rotated (self, 1, 4, 2, 5, 4, 7, cid_spruce_planks, 0)
	fill_box_rotated (self, 2, 1, 0, 4, 1, 0, cid_spruce_planks, 0)
	fill_box_rotated (self, 2, 2, 2, 3, 3, 2, cid_spruce_planks, 0)
	fill_box_rotated (self, 1, 2, 3, 1, 3, 6, cid_spruce_planks, 0)
	fill_box_rotated (self, 5, 2, 3, 5, 3, 6, cid_spruce_planks, 0)
	fill_box_rotated (self, 2, 2, 7, 4, 3, 7, cid_spruce_planks, 0)
	fill_box_rotated (self, 1, 0, 2, 1, 3, 2, cid_oak_log, 0)
	fill_box_rotated (self, 5, 0, 2, 5, 3, 2, cid_oak_log, 0)
	fill_box_rotated (self, 1, 0, 7, 1, 3, 7, cid_oak_log, 0)
	fill_box_rotated (self, 5, 0, 7, 5, 3, 7, cid_oak_log, 0)
	set_block_reorientated (self, 2, 3, 2, cid_oak_fence, 0)
	set_block_reorientated (self, 3, 3, 7, cid_oak_fence, 0)
	set_block_reorientated (self, 1, 3, 4, cid_air, 0)
	set_block_reorientated (self, 5, 3, 4, cid_air, 0)
	set_block_reorientated (self, 5, 3, 5, cid_air, 0)
	set_block_reorientated (self, 1, 3, 5, cid_potted_red_mushroom, 0)
	set_block_reorientated (self, 3, 2, 6, cid_crafting_table, 0)
	set_block_reorientated (self, 4, 2, 6, cid_cauldron, 0)
	set_block_reorientated (self, 1, 2, 1, cid_oak_fence, 0)
	set_block_reorientated (self, 5, 2, 1, cid_oak_fence, 0)

	-- Eaves.
	local dir = self.dir
	fill_box_rotated (self, 0, 4, 1, 6, 4, 1, cid_spruce_stairs,
			  facedirs[dir])
	fill_box_rotated (self, 0, 4, 2, 0, 4, 7, cid_spruce_stairs,
			  right_facedirs[dir])
	fill_box_rotated (self, 6, 4, 2, 6, 4, 7, cid_spruce_stairs,
			  left_facedirs[dir])
	fill_box_rotated (self, 0, 4, 8, 6, 4, 8, cid_spruce_stairs,
			  reverse_facedirs[dir])
	set_block_reorientated (self, 0, 4, 1, cid_spruce_stairs_outer,
				northwest_stair_dirs[dir])
	set_block_reorientated (self, 6, 4, 1, cid_spruce_stairs_outer,
				northeast_stair_dirs[dir])
	set_block_reorientated (self, 6, 4, 8, cid_spruce_stairs_outer,
				southeast_stair_dirs[dir])
	set_block_reorientated (self, 0, 4, 8, cid_spruce_stairs_outer,
				southwest_stair_dirs[dir])

	local level_min = level.preset.min_y
	for i = 1, #corners, 2 do
		local dx = corners[i]
		local dz = corners[i + 1]

		fill_supports (self, level_min, dx, -1, dz)
	end

	local x, y, z = reorientate_coords (self, 2, 2, 5)
	create_entity (x, y, z, "cb_mobs_village:witch", staticdata_witch)
end

local random_orientation = A.random_orientation
local make_rotated_bbox = A.make_rotated_bbox


return {
	place = swamp_hut_place,
	WIDTH = WIDTH, LENGTH = LENGTH, HEIGHT = HEIGHT,
}
